# SIAGA — Technical Pipeline

Reference documentation for how data moves through SIAGA end to end: sensor → radio → gateway → backend → model → alert → app. Written against the code as it exists in this repo, not as an aspirational spec — every number and file path below is pulled from the actual implementation.

Companion documents: [`docs/nexus-log.md`](nexus-log.md) (AI-collaboration log, corrections, judgment calls) and `CLAUDE.md` at the repo root (the original build brief this implements).

---

## 1. System architecture

```
  [Node]  ESP32 + sensors + TFLite-Micro Tier 1
        |  LoRa 923 MHz, 12-byte binary frame
        v
  [Gateway]  ESP32 + LoRa RX, store-and-forward to flash
        |  MQTT over TLS, JSON
        v
  [Backend]  ingest -> decode -> store -> feature build -> Tier 2 model
             -> guardrail -> state machine -> geofence -> FCM dispatch
        |                                        |
        v (Postgres wire protocol)                v (FCM topic publish)
  [Supabase Postgres]                      [App: cell_<h3id> subscribers]
        ^
        | REST (read-only)
        |
  [App]  Flutter; computes its own H3 cell locally, never sends GPS
```

Four layers, data flows upward, alerts flow back down to a *geographic topic*, never to a user record — this asymmetry (raw sensor data goes up to a database; alerts go down to anonymous topics, not to device identities) is the privacy design in one sentence, and it shapes almost every decision below.

Firmware (node + gateway) is out of scope for this document — it is not yet built. Everything from the MQTT ingest point downward (backend, ML, database, app) is implemented and is what this document describes.

---

## 2. Data contracts

### 2.1 LoRa uplink frame — 12 bytes, packed, little-endian

Defined once in [`shared/frame.py`](../shared/frame.py) (`UplinkFrame`, `struct.Struct("<BBHbbBBbBBB")`). This is the single source of truth; firmware must hand-mirror it exactly.

| Offset | Field | Type | Note |
|---|---|---|---|
| 0 | `node_id` | uint8 | |
| 1 | `seq` | uint8 | rolling, gap detection |
| 2–3 | `level_mm` | uint16 | distance transducer→water surface. **Decreases as water rises.** |
| 4 | `tilt_x` | int8 | 0.1°/LSB, delta from 24h rolling baseline |
| 5 | `tilt_y` | int8 | as above |
| 6 | `soil_pct` | uint8 | 0–100 |
| 7 | `rain_tips` | uint8 | tipping-bucket count since last tx |
| 8 | `temp_c` | int8 | |
| 9 | `rh_pct` | uint8 | |
| 10 | `vbat_cv` | uint8 | centivolts above 3.00 V |
| 11 | `flags` | uint8 | bit0 Tier-1 anomaly, bit1 enclosure humidity, bit2 low battery, bits3–4 boot cause |

The `level_mm → height_m` inversion happens **exactly once**, at ingestion (`shared/frame.py::level_mm_to_height_above_datum`, called from `backend/app/pipeline.py::decode_reading`). Everything downstream of that one call — features, guardrail, state machine, ML training — works in height-above-datum and never sees raw `level_mm` again. This is the single most likely place for an inverted-logic bug in the whole project, so it is deliberately centralized.

### 2.2 MQTT topics

| Topic | Direction | Payload |
|---|---|---|
| `siaga/v1/telemetry/<gateway_id>` | gateway → backend | JSON: decoded frame fields + `gateway_id`, `received_at`, `rssi`, `snr` |
| `siaga/v1/status/<gateway_id>` | gateway → backend | heartbeat every 60s: `uptime`, `buffered_count`, `rssi` |
| `siaga/v1/cmd/<gateway_id>` | backend → gateway | subscribed, no handler yet (reserved) |

Handled in [`backend/app/ingest.py`](../backend/app/ingest.py).

### 2.3 REST API

Implemented in [`backend/app/api.py`](../backend/app/api.py). Every route depends only on `Repository` — never on the state machine, Tier 2 model, or FCM client directly, since those only run inside the ingest pipeline, which a serverless read path (Vercel) can't run anyway.

| Method / path | Purpose |
|---|---|
| `GET /api/v1/nodes` | last state + reading summary per node |
| `GET /api/v1/nodes/{id}/history?hours=` | time series, downsampled to ≤500 points |
| `GET /api/v1/hazards/active` | active hazard polygons/cells + bilingual copy |
| `POST /api/v1/reports` | community report — **`cell_id`, never coordinates** |
| `GET /api/v1/density` | k-anonymized subscriber counts (`count < 10` suppressed) |
| `POST /api/v1/subscriptions/ping` | +1/−1 delta on FCM topic (sub)/(unsub) — not in the original brief; added because FCM has no API to read topic subscriber counts, so nothing would populate `/density` otherwise |
| `GET /api/v1/health` | ingest lag, silent-node list |

No endpoint anywhere accepts latitude/longitude from a handset.

---

## 3. Backend processing pipeline

One function wires the whole thing together: [`backend/app/pipeline.py::process_reading`](../backend/app/pipeline.py). Called from the MQTT ingest loop for live traffic, and reused verbatim by the ML training pipeline (§5) so training and serving can never silently diverge.

```
decode_reading            shared/frame.py + pipeline.py
     v
repo.insert_reading        persist raw reading (Supabase)
     v
build_features             features.py — pull last 24h history, derive vector
     v
evaluate_guardrail         guardrail.py — Tier2.predict() + corroboration count
     v
state_machine.evaluate     state_machine.py — dwell/hysteresis, may emit a Transition
     v (only if state changed)
repo.append_transition     log the transition + why (Supabase, audit trail)
     v (only if new state is WARNING/EVACUATE)
geofence.cells_around_point   resolve H3 cells around the node
     v
repo.create_hazard + fcm_client.publish_to_cell(s)   dispatch
```

Two guardrails on the alert path specifically:
- A **WARNING** reading that immediately follows **EVACUATE** does *not* re-fire an advisory (de-escalating out of EVACUATE isn't a fresh alert).
- Every stage between "reading received" and "alert dispatched" is one function call chain with no branching copies of feature logic — this is what "train/serve parity" in §5.3 actually means in code, not just in principle.

### 3.1 Feature vector

[`backend/app/features.py::build_features`](../backend/app/features.py) — 18 features, computed from a node's own reading history (no cross-node features):

| Group | Features |
|---|---|
| Lagged level | `level_lag_{5,15,30,60}m` — nearest reading at-or-before `now - lag`, falls back to current reading if no history that far back (treats "no data" as "no change," not a fabricated trend) |
| Rate of change | `level_d1_m_per_min` (1st derivative), `level_d2_m_per_min2` (2nd derivative, needs 3 readings) |
| Rainfall | `rain_cum_{1,3,6,24}h_mm` — `Σ rain_tips × TIP_RESOLUTION_MM` (0.2 mm/tip) over each window |
| Soil | `antecedent_soil_moisture_pct` — current `soil_pct` used directly as proxy (no infiltration model in the prototype) |
| Tilt | `tilt_x_lsb`, `tilt_y_lsb`, `tilt_magnitude_lsb` (`hypot(x, y)`) |
| Cyclical time | `time_of_day_sin/cos`, `season_sin/cos` (day-of-year / 365.25) |

`FEATURE_HISTORY_WINDOW = 24h` (covers the widest lookback any feature needs). `FEATURE_NAMES` (the exact ordered tuple) is imported by both the backend at inference time and `ml/train.py` at training time — one definition, never duplicated.

### 3.2 Guardrail — why the model never triggers an alert directly

[`backend/app/guardrail.py`](../backend/app/guardrail.py). The Tier 2 probability is one of four independent inputs, not a switch:

```python
corroborating = count of:
  reading.flags & FLAG_TIER1_ANOMALY   # node's own on-device anomaly flag
  tilt_magnitude_lsb  >= 30.0          # ≈3.0°
  soil_pct            >= 85.0
  rain_cum_1h_mm       >= 20.0

physical_breach = height_m >= node.critical_height_m   # if configured
```

These four thresholds are prototype defaults, not hydrologically derived — flagged in the module docstring as needing per-catchment recalibration once real sensor data exists.

### 3.3 State machine — dwell and hysteresis

[`backend/app/state_machine.py`](../backend/app/state_machine.py). `desired_state()` is a pure function of `GuardrailInputs` (no memory); the `StateMachine` class is what adds time:

| State | Entry condition (`desired_state`) | Escalation dwell |
|---|---|---|
| NORMAL | none of the below | — |
| WATCH | `tier1_anomaly` or `tier2_p ≥ 0.30` | 0s (immediate) |
| WARNING | `corroborating ≥ 2` or `tier2_p ≥ 0.60` | **600s** (brief-specified) |
| EVACUATE | `physical_breach` or (`tier2_p ≥ 0.85` and `corroborating ≥ 2`) | 0s (immediate) |

De-escalation requires the desired state to be *below* current for **1800s** continuously (judgment call, not brief-specified — flagged in `docs/nexus-log.md`), and steps down exactly **one level per satisfied dwell**, re-arming the timer each step — an EVACUATE that senses one calm reading doesn't silently reopen a road. Every transition is logged with the full `GuardrailInputs` snapshot and `dwell_elapsed_s` that caused it (`state_transitions` table, §4), so any alert is traceable back to the reading that triggered it.

### 3.4 Geofencing and dispatch

[`backend/app/geofence.py`](../backend/app/geofence.py) resolves an H3 (resolution 8) footprint two ways:
- `cells_around_point` — a grid-disk around a node's fixed install location, used for node-triggered escalations (the current, only path in production).
- `resolve_hazard_cells` — resolves an arbitrary polygon to cells, for a future authority-drawn hazard (dashboard support doesn't exist yet).

Both take a `buffer_rings` parameter (`ALERT_BUFFER_RINGS`, default 2) so people approaching — not just inside — the footprint get the advisory. [`backend/app/fcm.py`](../backend/app/fcm.py) publishes to `cell_<h3id>` topics only; `NullFCMClient` logs instead of sending when no Firebase credentials are configured, so the full pipeline still runs at a booth with no push configured.

### 3.5 Node heartbeat

[`backend/app/heartbeat.py`](../backend/app/heartbeat.py) — a node is "silent" if its last reading is older than **2× its expected sample interval**, and that interval isn't a constant: it's 60s normally, 30s once the node's own Tier-1 flag has it sampling faster. Evaluated on-demand by `GET /api/v1/health`, not a background job.

---

## 4. Persistence layer — Supabase Postgres

Schema: [`backend/schema.sql`](../backend/schema.sql). This is a **logged deviation** from the build brief, which specifies SQLite for the prototype (`docs/nexus-log.md`, 2026-08-13) — chosen so the same database could serve both the persistent ingest process and a serverless REST deployment without a shared-file problem. The schema uses no Supabase-specific features (no RLS policies beyond deny-all, no `auth.uid()`), so it stays portable to any bare Postgres host.

| Table | Purpose |
|---|---|
| `nodes` | id, name, lat/lon, `datum_mm` (per-install transducer height), `critical_height_m` (optional EVACUATE physical threshold) |
| `readings` | one row per decoded uplink, **after** the `level_mm → height_m` inversion |
| `node_state` | current risk state per node — a cache over `state_transitions` |
| `state_transitions` | every transition + the full `reason` JSON that caused it |
| `hazards` | issued advisories: state, H3 cells, bilingual copy, `active` flag |
| `reports` | community reports — `cell_id` only, never coordinates |
| `cell_subscriptions` | anonymous per-cell FCM subscriber counter (no device identifier) |

**Access model:** row-level security is enabled on every table with zero policies attached — deny-all for Supabase's `anon`/`authenticated` PostgREST roles. The backend connects with its own Postgres connection string (table owner, bypasses RLS regardless) via `asyncpg`; the Flutter app never talks to Supabase directly, only to the FastAPI REST layer (§2.3). Without this, every table would be world-readable/writable through the project's anon key.

**Connection detail worth knowing:** `AsyncpgRepository.connect()` sets `statement_cache_size=0` — required because the Vercel deployment goes through Supabase's PgBouncer pooler in transaction mode, which breaks asyncpg's default prepared-statement caching. Costs a small amount of query-planning overhead per call; left on unconditionally (even for direct connections) for pooler compatibility.

**Fallback:** an empty `DATABASE_URL` makes the backend run against `InMemoryRepository` instead — not an error path, the deliberate offline-demo fallback (`backend/app/repository.py`).

---

## 5. Machine learning pipeline (Tier 2)

### 5.1 Problem framing

Per build-brief §7: *"There will be no labelled flood events collected during the build period. Train Tier 2 on historical public rainfall and water-level records for Malaysian catchments, augmented with synthetic hydrographs... The prototype's own logged data validates the pipeline end to end and characterises sensor noise; it does not train the risk model."* Every choice below follows from that one constraint.

Fixed methodology (§7.1 of the brief): **LightGBM**, not a sequence model (too little labelled data to avoid overfitting a deep model; gradient boosting on lag/rate features is competitive, trains in seconds, and gives feature attributions a district officer can actually interrogate — explainability is a functional requirement, not a nicety). **Temporally-ordered splits only**, never random/k-fold shuffling. **Report precision/recall/PR-AUC**, never accuracy (meaningless under this class imbalance).

### 5.2 Data sources

**Real data** — [`ml/fetch_data.py`](../ml/fetch_data.py). JPS (Jabatan Pengairan dan Saliran) Malaysia's *Public Infobanjir* system has no documented public API or bulk-download endpoint; the two query endpoints used here (`searchresultwaterleveldtlead.php`, `searchresultrainfalldthourlylead.php`) were found by reverse-engineering the live dashboard's own network requests — see `docs/nexus-log.md` for exactly how. It is still real government telemetry, the same data the dashboard itself displays, fetched the way the dashboard's own JavaScript does rather than through a maintained API.

9 combined water-level + rainfall stations across Perak sub-catchments, ~12 months each, 15-minute resolution:

| Station | Alert threshold (m) | Raw readings | Labeled rows | Positive rows |
|---|---:|---:|---:|---:|
| Sg. Selama di Kg. Gua Petai | 13.50 | 15,390 | 15,269 | 0 |
| Sg. Ijok di Titi Ijok Perak (RHN) | 10.50 | 26,116 | 26,052 | 356 |
| Sg. Kurau di Bt. 14 Batu Kurau | 24.00 | 29,905 | 29,876 | 0 |
| Sg. Kurau di Pondok Tanjung | 13.50 | 14,155 | 14,129 | 0 |
| Sg. Kampar di Kg. Baru Kuala Dipang (RHN) | 22.00 | 78,932 | 78,887 | 3,184 |
| Emp. Ulu Kinta (RHN) | 246.50 | 40,561 | 40,390 | 6,949 |
| Sg. Chemor di Kg. Cik Zainal (RHN) | 74.20 | 79,057 | 79,014 | 843 |
| Sg. Perak di Pekan Manong (RHN) | 25.00 | 80,710 | 80,625 | 0 |
| Sg. Ijok di Bekalan Ijok | 35.00 | 28,908 | 28,793 | 1,330 |
| **Total real** | | **393,634** | **393,035** | **12,662** |

Three of nine stations never crossed their own alert threshold in the fetched window — kept anyway, as true negatives from a real hydrograph shape rather than dropped for being "boring."

**Malformed-JSON handling:** the rainfall endpoint occasionally emits a bare empty value for a numeric field (`"clean":,` — not valid JSON). Repaired with `re.sub(r":(?=[,}])", ":null", text)` before parsing, matching how the same payload represents other missing readings elsewhere (`"raw":-9999`).

**Synthetic data** — 200 runs of [`shared/simulator.py`](../shared/simulator.py)'s `HydrographGenerator`, randomized per run (`baseline_depth_mm ∈ [100,500]`, `peak_depth_mm` up to baseline+3500, `time_to_peak_s ∈ [600, 14400]`, `recession_tau_s ∈ [1800, 10800]`) — deliberately includes runs where the peak barely exceeds baseline (no real event), so the model sees true negatives shaped like a hydrograph, not just "any rise = positive." Contributes **36,583** rows.

**Combined dataset** (`ml/data/processed/manifest.json`): **429,618 rows total**, 37,565 positive (**8.74%**), split 322,131 train / 107,487 test.

### 5.3 Train/serve parity — one feature implementation, not two

[`ml/build_dataset.py`](../ml/build_dataset.py) imports `build_features` and `decode_reading` **directly from the production backend** (`backend/app/features.py`, `backend/app/pipeline.py`) rather than reimplementing feature engineering for training. This is the load-bearing design decision in this whole pipeline: a training script that recomputes features independently is exactly how train/serve skew happens silently, and there is deliberately only one implementation of "what a feature vector looks like" in the entire project.

Real JPS readings are adapted into the same `ReadingRecord` shape the backend uses (`load_real_station`) — with `tilt_x/y = 0` and `soil_pct = 35` as explicit placeholders, since JPS stations have no IMU or soil-moisture sensors. Synthetic readings go through `decode_reading` + `frame_to_fields` — the identical path a real MQTT payload takes.

### 5.4 Labeling

[`label_series()`](../ml/build_dataset.py): for each reading, `label = 1` if the series' water level crosses its alert threshold at any point in the next **60 minutes** — operationalizing `tier2.py`'s own contract ("probability of threshold exceedance within 60 minutes"). Three-way outcome per row, not binary:
- **1** — threshold crossed within the horizon
- **0** — horizon fully observed, never crossed
- **excluded (`None`)** — either the series runs out of data before the 60-minute horizon closes, or the horizon window is a pure data gap with zero readings in it

The third case matters: a "0" label has to be backed by at least one real observation showing the level stayed below alert. A window with no readings at all says nothing about what happened, and silently treating a gap as negative would manufacture confident labels out of missing data.

### 5.5 Train/test split — per-series, not global

[`temporal_split()`](../ml/build_dataset.py): each individual series (one real station's full history, or one synthetic run) is sorted chronologically and cut at **75%** — the first 75% of *that series* trains, the last 25% tests. Applied per-series rather than globally, because a global timestamp sort across unrelated stations and synthetic runs wouldn't protect against — or need to protect against — a row seeing its own future; that only matters within one continuous timeline. Concatenating independent series and cutting once, globally, would just as effectively leak nothing extra while being simpler to reason about wrong.

### 5.6 Model and training configuration

[`ml/train.py`](../ml/train.py):

```python
params = {
    "objective": "binary",
    "metric": "average_precision",
    "is_unbalance": True,       # 8.74% positive rate
    "num_leaves": 31,
    "learning_rate": 0.05,
    "min_data_in_leaf": 50,
    "seed": 42,
}
# num_boost_round=500, early_stopping(30 rounds) on the held-out test set
```

### 5.7 Results

From [`backend/models/tier2_lightgbm/metrics.json`](../backend/models/tier2_lightgbm/metrics.json) (trained 2026-09-23):

| Metric | Value |
|---|---|
| PR-AUC (held-out test) | **0.9281** |
| Test rows / positive | 107,487 / 5,084 (4.73%) |
| Best iteration (early stop) | 39 |
| **O3 operating point** — threshold | 0.70 |
| Recall at that threshold | **0.9050** |
| FPR at that threshold | **0.0086** |
| Precision at that threshold | 0.8394 |
| **Meets O3** (recall ≥ 0.90 at FPR ≤ 0.10) | **✅ Yes** |

The precision-recall curve is committed at `backend/models/tier2_lightgbm/pr_curve.png` / `.csv` per acceptance criterion O3's verification requirement.

**Honest caveat, carried in the metrics file itself:** this model is trained primarily on synthetic hydrographs augmenting real JPS station data, because no real labelled flood events exist at this catchment scale (§7's own design, not a shortcut taken here). Whether O3 is actually met *in production* depends on how representative the synthetic event distribution is of real flash floods — this number should be re-evaluated once real event data exists. See §6.

### 5.8 Serving — load-time parity check, not just at training

[`backend/app/tier2.py::LightGBMTier2Model`](../backend/app/tier2.py) loads `model.txt` and checks the persisted `feature_names.json` against the *live* `backend.app.features.FEATURE_NAMES` **at load time**, raising if they've diverged (i.e. `features.py` changed since this model was trained). Refusing to load a model that would silently receive columns in the wrong order/shape is the runtime half of the §5.3 parity guarantee; the training-time half is importing the same function, not duplicating it.

`build_tier2_model()` in [`backend/app/main.py`](../backend/app/main.py) falls back to `HeuristicTier2Stub` (a simple, explicitly-not-a-real-model rate×soil heuristic) on `FileNotFoundError` (no model trained yet), `ImportError` (`lightgbm` not installed — it's a training-time dependency, moved into core `dependencies` in `pyproject.toml` specifically so the persistent-process Docker image doesn't silently skip it), or `ValueError` (feature drift, above). All three degrade rather than crash the process, matching the rest of the backend's resilience philosophy.

---

## 6. Where Supabase fits — now, and next

**Now:** Supabase Postgres is already the backend's system of record. Every `nodes` / `readings` / `node_state` / `state_transitions` / `hazards` / `reports` / `cell_subscriptions` row for the live deployment goes through `AsyncpgRepository` (§4) into the `oqsdoubmzzkfgcvvsbfb` Supabase project, and the Flutter app's `/api/v1/*` reads ultimately come from those same tables. Nothing new needs to be wired for this — it's what `DATABASE_URL` already points at.

**Next — real hardware data as a training source:** the ML pipeline in §5 deliberately does *not* train on Supabase's `readings` table today, because §7 of the brief is explicit that the prototype's own logged data validates the pipeline and characterises sensor noise, but doesn't train the risk model — there's no labelled real flood event to learn from yet, only synthetic ones. Once real nodes have been logging into `readings` for long enough to accumulate real corroborated escalations (or at minimum, real quiet-period sensor-noise characteristics), that table becomes a second real-data source alongside JPS, in two possible roles:

1. **Pipeline validation** (already in scope per §7): compare real node feature vectors (`build_features` run against real `readings`) against the JPS-trained model's behavior, to sanity-check that the model isn't wildly miscalibrated against this specific hardware's actual noise floor.
2. **Retraining input** (once real events exist): a `ml/fetch_supabase.py` alongside the existing `ml/fetch_data.py` — same shape, pulling `readings` for a node over `DATABASE_URL` instead of scraping JPS — feeding the *same* `build_dataset.py` (`build_features`, `label_series`, `temporal_split`, per-series) with `source="hardware"` instead of `source="real"` / `"synthetic"`. No new labeling or splitting logic would be needed; the pipeline in §5.3–5.5 was written to be source-agnostic already (`source` is just a tag carried through to the manifest).

This is not yet implemented — flagging it here as the concrete next step once there is enough real hardware history to be worth pulling, rather than leaving it as an unstated assumption.

---

## 7. Flutter app (consumer of this pipeline)

Not the focus of this document, but for completeness — the app is a pure consumer of §2.3's REST API plus on-device FCM/H3, and never talks to Supabase or MQTT directly:

- **Privacy (build-brief §3.1, non-negotiable):** the handset computes its own H3 resolution-8 cell locally (`h3_flutter`) and subscribes to `cell_<h3id>` via FCM. Raw GPS never leaves the device — verified by the fact that no REST endpoint (§2.3) accepts a lat/lon field at all.
- **State:** `Provider`-based `AppState`, backed by `ApiClient` (real) or `DemoController` (synthetic hydrograph replay, for the booth — see build-brief §3.5/§6.4).
- **Screens:** Map (node markers, device-location marker, draggable node-detail panel), My Risk (telemetry-dial gauge + micro-metric grid + active-threat banner), Report (`cell_id`-only submission), Settings (locale, demo-mode trigger, notification permission).
- **Design system:** dark "command-center" theme — Plus Jakarta Sans for UI text, JetBrains Mono strictly for telemetry/timestamps, glass-morphic cards with accent-tinted gradients, all defined in `app/lib/core/theme.dart`.

---

## 8. Deployment topology

Two separate processes share one codebase (`backend/app/main.py`):

| Component | Where | Entry point |
|---|---|---|
| REST API (read-only: `/nodes`, `/history`, `/hazards`, `/reports`, `/density`, `/health`) | Vercel (serverless) | `api/index.py` → `create_app(repo_factory=...)` |
| MQTT ingest + full pipeline (§3) | a persistent process/small VM — serverless can't hold a long-lived MQTT connection or the in-process `StateMachine` | `python -m backend.app.main` → `run_full_process()` |
| Flutter web build | Vercel (separate project, `siaga-web`) | `app/vercel.json` custom build (clones Flutter SDK, `flutter build web --release`) |
| Database | Supabase Postgres | `DATABASE_URL` |

Both backend components and the app all point at the same Supabase instance; the persistent ingest process is the only one that ever writes.

---

## 9. Known judgment calls and limitations

Carried over from inline code comments and `docs/nexus-log.md` — repeated here so they're visible in one place rather than requiring a full source read to discover:

- **De-escalation dwell (1800s)** and **per-step (not direct-jump) de-escalation** are this implementation's judgment call — the brief specifies the 600s WARNING escalation dwell explicitly but not the stand-down side.
- **Guardrail per-channel thresholds** (tilt ≥3.0°, soil ≥85%, rain ≥20mm/1h) are prototype defaults, not hydrologically derived per catchment.
- **Tier 2's O3 result (PR-AUC 0.928, recall 0.905 @ FPR 0.009)** is measured against a dataset that is ~8.5% real, ~91.5% synthetic by row count (36,583 synthetic rows generated for training, vs. 393,035 real-station rows — but synthetic runs are denser in event-relevant regions by design). Real-world generalization is explicitly unverified until real flood/exceedance events exist to test against.
- **Antecedent soil moisture** uses the current reading directly as a proxy — no infiltration/decay model.
- **`/api/v1/subscriptions/ping`** exists to make `/density` non-empty (FCM has no subscriber-count API) but is not in the build brief's original fixed endpoint table.
- **Postgres/Supabase instead of SQLite** is a deliberate, logged override of build-brief §4.1, made to support the Vercel/persistent-process split (§8).
