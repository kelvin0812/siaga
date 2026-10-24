# SIAGA

**An early-warning system for flash floods and landslides in the small drains, streams and cut slopes that national river telemetry doesn't cover.**

Built by Team 0100 0011 for Project Nexus 2026 (Track 3, Global Impact), IEEE MMU Student Branch.

In Malaysia, a monsoon drain or a cut slope can go from fine to dangerous in minutes, and the warnings people get are often for a whole district, not their street. SIAGA puts low-cost sensor nodes at those spots, works out how dangerous the situation is from four sensors, and sends an alert only to the people inside the affected area.

- Live app: https://siaga-web-omega.vercel.app
- Live API: https://siaga-nine.vercel.app/api/v1/health

## How it works

```
Sensors ──> Pico ──> ESP32 node ──LoRa──> Hub (ESP32) ──Wi-Fi──> Database ──> Backend ──push topic──> App
                                                                                 │
                                       phase model + rule engine → guardrail → state machine → geofence
```

A bench rig measures four things: water level (ultrasonic), soil moisture, water flow, and tilt and vibration (MPU-6050). The phase of the situation is one of four: **Normal, Watch, Warning, Evacuate**.

**1. The phase model (machine learning).** Two small LightGBM models are trained on the rig's own recordings. One looks only at the water level (its height above normal and how fast it is rising). The other looks at flow, soil and tilt. They are blended with the water level weighted most, because it is the most reliable sensor, and the phase shown is the most common answer of the last 10 readings so one noisy reading cannot flip it.

**2. The rule engine (no machine learning).** Plain engineering rules over the same four sensors: a water-level countdown, inflow, saturated soil, and a sustained tilt for slope movement. Two independent sensors must agree before a warning, and a breach must hold for 5 seconds, so a hand under the sensor or a bump on the table cannot raise an alarm.

**3. The guardrail and state machine.** The model never raises an alert on its own. Escalation needs at least two sensors to agree and a dwell time: quick to warn, slow to stand down.

**Privacy is built into the design, not bolted on.** The phone works out its own H3 grid cell (resolution 8) locally and subscribes to a push topic named after that cell. The backend resolves a hazard to a set of cells and publishes to those topics. No endpoint accepts latitude/longitude from a handset, so the server knows which areas to warn but never who is where. Density figures for the authority view come from anonymous topic counts, and any cell with fewer than 10 subscribers is hidden.

## What's in this repo

| Path | What it is |
|---|---|
| `ml/rig/` | Training for the phase model: feature building and blocked-block evaluation (`python -m ml.rig.train`). |
| `ml/data/rig/` | The rig's raw recording the model is trained on (2,220 readings). |
| `backend/models/phase_model/` | The trained phase model, its calibration and its evaluation, saved together. |
| `backend/app/phase_model.py` | Live phase prediction, one reading at a time. A test checks it matches the training features. |
| `ml/rig/export_app.py`, `app/assets/phase_model.json` | Exports the trained model so the phone can run it. Writes a test fixture of real rig rows with the Python answers. |
| `app/lib/core/phase_model.dart`, `rig_controller.dart` | The phase model running inside the app, and the controller that feeds it the rig's live readings from the database. |
| `backend/app/rules.py`, `backend/rig_check.py` | The rule engine, and a script that replays recorded rig data through it. |
| `backend/` | FastAPI service: ingest, features, guardrail, state machine, geofence, FCM dispatch, heartbeat monitoring, REST API. |
| `shared/` | The 12-byte LoRa frame codec and the synthetic flood simulator used for the demo mode. |
| `app/` | Flutter app (Android, iOS, web): live map, my-risk screen, evacuation routes, community reports, English and Bahasa Malaysia, offline cache, demo mode. |
| `api/`, `vercel.json` | The REST API as deployed on Vercel. |
| `ml/` (other files), `backend/models/tier2_lightgbm/` | An earlier river-flood experiment, kept for reference. See the note under Results. |
| `tests/`, `app/test/` | 142 backend tests and 29 app tests. The frame codec, state machine, geofence, rule engine and phase features get the heaviest coverage, and the app's model is checked against the Python one on real rig rows. |

## Try it

```bash
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -e ".[dev]"
pip install -r ml/requirements.txt
pytest                                              # 142 tests
python -m ml.rig.train                              # retrain the phase model from the rig recording
python -m ml.rig.export_app                         # re-export it for the app (and refresh the app's test fixture)
python -m backend.rig_check --csv ml/data/rig/sensor_table_rows.csv --mount-cm 31 --alert-cm 4 \n    --soil-dry 450 --soil-wet 630 --flow-active 250   # replay the rig data through the rule engine (example calibration)
python -m backend.demo --speed 600                  # replay a simulated flood, printing every state change
```

**App**

```bash
cd app
flutter pub get
flutter run -d chrome        # or an Android device
```

Open Settings and switch on **demo mode** to step through Normal, Watch, Warning and Evacuate without any data. Switch on **Live Rig (Phase Model)** to run the whole app from the bench rig: the app reads the rig's latest readings from the database, the phase model runs on the phone, and the risk screen, map and evacuation alert follow it. If the rig goes quiet for more than 30 seconds, no alert is raised and the screen says the data is old.

```bash
flutter test     # 29 tests, including the model check against real rig rows
```

## Results

The four phases were run one after another on the rig (Phase 1 to 4), and the phase labels come from that order. Each phase is cut into five blocks. One block per phase is held out, and the 30 readings on each side of it are removed from training, so a test reading never sits next to a training reading. Numbers are from the held-out blocks only.

| Method | Accuracy |
|---|---|
| Fixed distance cut-offs, no machine learning | 86.7% |
| Water level model only | 86.0% |
| Flow, soil and tilt only | 73.2% |
| All four sensors in one model | 81.1% |
| **Blend, water level weight 60%, smoothed over 10 readings** | **86.7%** |

- **The water level carries the decision.** Inside the blend, the water level accounts for 98.8% of the result, and flow, soil and tilt for 0.0%, 0.2% and 1.0%. Water-level weights of 60% and above gave about 86%, against 76 to 78% at 40 to 50%.
- **The model does not beat the simple rule.** Plain distance cut-offs score the same as the blend on this data. The three other sensors can recognise the phase on their own (73%), but only because of the order the phases were run in, and the water level already explains the same thing.
- **Mistakes are mostly between Phase 3 and Phase 4,** where the distance reading flickers by about 1.5 cm, the same size as the gap between those levels.
- **This tests the rig's own recording,** not another day. Water level is measured relative to the baseline, so a changed mounting height only needs a new baseline distance.

**An earlier experiment, and why its numbers should not be quoted.** The first model in this repo (`backend/models/tier2_lightgbm`) was trained on public river records plus synthetic floods and reported a precision-recall AUC of 0.958. That figure is inflated: its label counted a row as positive when the water was already above the alert level (about 94% of the real positives), and about two thirds of the positive rows were synthetic. Corrected, there are only a few hundred real "about to cross the alert level" rows, too few to learn from. It is kept for reference only.

## What is and isn't finished

We'd rather be upfront about this than have you find out at the booth.

**Working**
- The rig sends readings to the database through the hub, and the phase model and rule engine run on them.
- The app runs the phase model on the phone from the rig's live readings (Settings, Live Rig).
- The backend pipeline end to end, in simulation, with tests.
- The Flutter app (web and Android build), including demo mode.
- On-device H3 cell computation, with no coordinates sent to the backend.

**Not finished or not measured**
- **Hardware code isn't in this repo.** The node, hub and Pico code is kept separately.
- **The rule engine isn't shown in the app.** The app shows the phase model's result; the rule engine runs from the command line.
- **Push notifications.** The FCM dispatch code and tests are in, but no Firebase project is connected, so alerts are logged rather than delivered. The in-app EVACUATE screen works.
- **One recording, one day.** The phase model has not been tested on a second day, a different mounting height or a different order of events.
- **The hosted API uses a heuristic stand-in** for the older river model, because LightGBM cannot load on Vercel's runtime.
- **Hardware targets** (72-hour packet delivery, 30-second alert latency, 7-day battery life, bill of materials) haven't been measured yet.
