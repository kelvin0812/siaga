# SIAGA

**An early-warning system for flash floods and landslides in the small drains, streams and cut slopes that national river telemetry doesn't cover.**

Built by Team 0100 0011 for Project Nexus 2026 (Track 3, Global Impact), IEEE MMU Student Branch.

In Malaysia, a monsoon drain or a cut slope can go from fine to dangerous in minutes, and the warnings people get are often for a whole district, not their street. SIAGA puts low-cost sensor nodes at those spots, scores the risk with a machine-learning model, and sends an evacuation alert only to the people inside the affected area.

- Live app: https://siaga-web-omega.vercel.app
- Live API: https://siaga-nine.vercel.app/api/v1/health

## How it works

```
Node (ESP32 + sensors) ──LoRa, 12-byte frame──> Gateway ──MQTT──> Backend ──FCM topic──> App
                                                                     │
                                          features → Tier 2 model → guardrail → state machine → geofence
```

A node measures water level, rainfall, soil moisture and slope tilt. The backend turns each reading into features (rate of rise, cumulative rain, soil saturation), and a LightGBM model estimates the chance of a flood in the next 60 minutes.

The model never raises an alert on its own. Its output goes through a **guardrail** that needs at least two independent sensors to agree, then a **state machine** (Normal → Watch → Warning → Evacuate) with dwell times: quick to escalate, slow to stand down. A single drifting sensor or an overconfident model can't send anyone running.

**Privacy is built into the design, not bolted on.** The phone works out its own H3 grid cell (resolution 8) locally and subscribes to a push topic named after that cell. The backend resolves a hazard to a set of cells and publishes to those topics. No endpoint accepts latitude/longitude from a handset, so the server knows which areas to warn but never who is where. Density figures for the authority view come from anonymous topic counts, and any cell with fewer than 10 subscribers is hidden.

## What's in this repo

| Path | What it is |
|---|---|
| `shared/` | The 12-byte LoRa frame codec and the synthetic flood simulator. The codec is the single source of truth that firmware must match. |
| `backend/` | FastAPI service: ingest, feature builder, Tier 2 inference, guardrail, state machine, geofence, FCM dispatch, heartbeat monitoring, REST API. |
| `ml/` | Data fetching (JPS public telemetry), dataset building with synthetic flash-flood augmentation, and LightGBM training. |
| `backend/models/` | The trained model with its feature list, metrics and precision-recall curve, saved together so results are reproducible. |
| `app/` | Flutter app (Android, iOS, web): live map, my-risk screen, evacuation routes, community reports, English and Bahasa Malaysia, offline cache, demo mode. |
| `api/`, `vercel.json` | The read/write REST API as deployed on Vercel. |
| `tests/` | 123 backend tests. The frame codec, state machine and geofence get the heaviest coverage. |

## Try it

You don't need a flood. Everything can be driven by a simulated rising hydrograph.

**Backend and simulator**

```bash
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -e ".[dev]"
pytest                                              # 123 tests
python -m backend.demo --speed 600                  # replay a 3-hour flood in ~18 s, printing every state transition
```

With no `DATABASE_URL` set, the backend uses an in-memory store. Copy `.env.example` to `.env` to point it at Postgres.

**App**

```bash
cd app
flutter pub get
flutter run -d chrome        # or an Android device
```

Open Settings and switch on demo mode to step through Normal, Watch, Warning and Evacuate without any data.

**Retraining the model** (optional; the trained model is already committed)

```bash
pip install -r ml/requirements.txt
python -m ml.fetch_data && python -m ml.build_dataset && python -m ml.train
```

## Results

Tier 2 is a LightGBM model validated on a temporally ordered split (never shuffled, so no future data leaks into training). On the held-out set of 107,487 rows (4.7% positive):

| Metric | Value |
|---|---|
| Precision-recall AUC | 0.958 |
| Recall at the chosen threshold | 0.90 |
| False-positive rate at that threshold | 0.005 |
| Precision at that threshold | 0.90 |

The full PR curve is in [`backend/models/tier2_lightgbm/`](backend/models/tier2_lightgbm/).

## What is and isn't finished

We'd rather be upfront about this than have you find out at the booth.

**Working**
- The backend pipeline end to end, in simulation, with tests.
- The trained Tier 2 model and its evaluation.
- The Flutter app (web and Android build), including demo mode.
- On-device H3 cell computation, with no coordinates sent to the backend.

**Not finished or not measured**
- **Hardware code isn't in this repo.** This repo covers the software side (ML, backend, app). The microcontroller firmware for the sensor node and gateway is kept separately, and the LoRa node's on-device Tier 1 detection isn't finished.
- **Push notifications.** The FCM dispatch code and tests are in, but no Firebase project is connected, so alerts are logged rather than delivered. The in-app EVACUATE screen works.
- **The model is trained mostly on synthetic floods** layered over real river-station data, because no labelled flash-flood events exist at this scale. The numbers above show the pipeline works; they don't prove it will perform the same on a real event.
- **The hosted API uses a heuristic stand-in for Tier 2.** LightGBM can't load on Vercel's runtime, so the live API falls back to a simple rule-based scorer and says so in its responses. The real model runs locally and in the Docker image.
- **Hardware targets** (72-hour packet delivery, 30-second alert latency, 7-day battery life, bill of materials) haven't been measured yet.
