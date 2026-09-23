"""
Builds the labeled training dataset for Tier 2 (build brief Section 7):
real JPS station telemetry + synthetic hydrographs, run through the
EXACT SAME feature builder (backend/app/features.py) and frame-decode
path (backend/app/pipeline.py) the production backend uses at inference
time. This is deliberate and important — a training pipeline that
reimplements feature engineering separately from the serving code is how
train/serve skew happens silently. There is exactly one implementation
of "what a feature vector looks like" in this whole project.

Label definition: for each reading, label=1 if the station's real (or a
synthetic run's configured) water level crosses its "alert" threshold at
any point in the next 60 minutes — operationalizing tier2.py's own
docstring ("per-node probability of threshold exceedance within 60
minutes"). Rows too close to the end of a series to see a full 60-minute
future window are excluded rather than assumed negative.
"""
from __future__ import annotations

import json
import random
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path

import pandas as pd

from backend.app.features import FEATURE_NAMES, build_features
from backend.app.pipeline import FEATURE_HISTORY_WINDOW, decode_reading, frame_to_fields
from backend.app.repository import NodeRecord, ReadingRecord
from shared.constants import TIP_RESOLUTION_MM
from shared.simulator import HydrographConfig, HydrographGenerator

RAW_DIR = Path(__file__).parent / "data" / "raw"
PROCESSED_DIR = Path(__file__).parent / "data" / "processed"
LABEL_HORIZON = timedelta(minutes=60)

# Fraction (by count, chronologically) of each individual series — one
# real station's history, or one synthetic run — kept for training,
# before the held-out temporal tail. Applied per-series, not globally:
# Section 7.1's "never random-shuffle, temporally ordered splits" concern
# is about a row seeing its own future, which a global timestamp sort
# across unrelated stations/synthetic runs wouldn't actually protect
# against or need to (they're independent series, not one timeline) —
# per-series chronological split is what actually satisfies that concern.
TRAIN_FRACTION = 0.75

REAL_DATUM_MM = 0  # real JPS water level is already "height", no datum inversion needed


def _parse_dt(s: str) -> datetime:
    return datetime.strptime(s, "%d/%m/%Y %H:%M")


def _numeric_or_none(v) -> float | None:
    if v is None:
        return None
    if isinstance(v, str):
        if v in ("-9999", ""):
            return None
        try:
            return float(v)
        except ValueError:
            return None
    if isinstance(v, (int, float)):
        if v == -9999:
            return None
        return float(v)
    return None


@dataclass(frozen=True)
class RealStationSeries:
    station_id: str
    name: str
    alert_m: float
    readings: list[ReadingRecord]


def load_real_station(station_dir: Path, station_id: str, name: str, alert_m: float, node_id: int) -> RealStationSeries:
    level_by_dt: dict[datetime, float] = {}
    for f in sorted(station_dir.glob("water_level_*.json")):
        data = json.loads(f.read_text(encoding="utf-8"))
        for v in data.get("values", []):
            val = _numeric_or_none(v.get("clean"))
            if val is None:
                continue
            level_by_dt[_parse_dt(v["dt"])] = val

    rain_by_dt: dict[datetime, float] = {}
    for f in sorted(station_dir.glob("rainfall_*.json")):
        data = json.loads(f.read_text(encoding="utf-8"))
        for v in data.get("values", []):
            val = _numeric_or_none(v.get("clean"))
            rain_by_dt[_parse_dt(v["dt"])] = val if val is not None and val >= 0 else 0.0

    readings: list[ReadingRecord] = []
    for i, dt in enumerate(sorted(level_by_dt)):
        height_m = level_by_dt[dt]
        interval_rain_mm = rain_by_dt.get(dt, 0.0)
        rain_tips = min(255, round(interval_rain_mm / TIP_RESOLUTION_MM))
        readings.append(
            ReadingRecord(
                node_id=node_id,
                gateway_id="jps-public-infobanjir",
                received_at=dt,
                seq=i % 256,
                level_mm=round(height_m * 1000),
                height_m=height_m,
                # No real IMU/soil-moisture sensors at JPS stations — these
                # are placeholders (soil_pct at the simulator's own
                # baseline default, tilt at zero movement), not measured.
                tilt_x=0,
                tilt_y=0,
                soil_pct=35,
                rain_tips=rain_tips,
                temp_c=27,
                rh_pct=75,
                vbat_cv=80,
                flags=0,
            )
        )
    return RealStationSeries(station_id, name, alert_m, readings)


def label_series(readings: list[ReadingRecord], alert_m: float) -> list[int | None]:
    """
    None means excluded: either not enough future coverage to reach the
    60-minute horizon at all, or the horizon window itself is a data
    gap with zero actual readings in it. A "0" label has to be backed by
    at least one real observation showing the level stayed below alert —
    a window with no readings at all says nothing about what happened,
    and silently treating it as negative would manufacture confident
    labels out of missing data.
    """
    n = len(readings)
    labels: list[int | None] = [None] * n
    last_ts = readings[-1].received_at if readings else None
    for i in range(n):
        horizon_end = readings[i].received_at + LABEL_HORIZON
        if last_ts is None or last_ts < horizon_end:
            continue  # ran out of future data before the horizon closes
        exceeded = False
        observed_any = False
        k = i
        while k < n and readings[k].received_at <= horizon_end:
            if readings[k].received_at > readings[i].received_at:
                observed_any = True
                if readings[k].height_m >= alert_m:
                    exceeded = True
            k += 1
        if not observed_any:
            continue  # pure gap in the horizon window — no basis for a label
        labels[i] = 1 if exceeded else 0
    return labels


def build_rows_for_series(readings: list[ReadingRecord], labels: list[int | None], series_id: str, source: str) -> list[dict]:
    rows = []
    start_ptr = 0
    for i, reading in enumerate(readings):
        if labels[i] is None:
            continue
        while readings[start_ptr].received_at < reading.received_at - FEATURE_HISTORY_WINDOW:
            start_ptr += 1
        history = readings[start_ptr : i + 1]
        features = build_features(reading.received_at, history)
        row = {name: features[name] for name in FEATURE_NAMES}
        row["label"] = labels[i]
        row["source"] = source
        row["series_id"] = series_id
        row["received_at"] = reading.received_at.isoformat()
        rows.append(row)
    return rows


def generate_synthetic_runs(n_runs: int, seed: int = 42) -> list[tuple[str, list[ReadingRecord], list[int | None]]]:
    rng = random.Random(seed)
    node = NodeRecord(id=9001, name="synthetic", lat=4.85, lon=100.74, datum_mm=3000)
    out = []
    for run_idx in range(n_runs):
        baseline_mm = rng.uniform(100, 500)
        # Includes runs where peak barely exceeds baseline (no real event)
        # through runs with a large rise — the model needs true negatives
        # shaped like a hydrograph, not just "any rise = positive".
        peak_mm = baseline_mm + rng.uniform(0, 3500)
        cfg = HydrographConfig(
            datum_mm=3000,
            baseline_depth_mm=baseline_mm,
            peak_depth_mm=peak_mm,
            time_to_peak_s=rng.uniform(600, 4 * 3600),
            recession_tau_s=rng.uniform(1800, 3 * 3600),
            total_duration_s=rng.uniform(2, 6) * 3600,
            sample_interval_s=60,
        )
        alert_ratio = 0.55
        alert_m = (cfg.baseline_depth_mm + alert_ratio * (cfg.peak_depth_mm - cfg.baseline_depth_mm)) / 1000.0

        gen = HydrographGenerator(node_id=9001, config=cfg)
        base_time = datetime(2026, 1, 1) + timedelta(days=run_idx)
        readings = [
            decode_reading(
                node=node,
                gateway_id="synthetic",
                received_at=base_time + timedelta(seconds=sr.t_s),
                frame_fields=frame_to_fields(sr.frame),
                rssi=None,
                snr=None,
            )
            for sr in gen.readings()
        ]
        labels = label_series(readings, alert_m)
        out.append((f"synthetic-{run_idx:04d}", readings, labels))
    return out


def temporal_split(rows: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    train_parts, test_parts = [], []
    for _, group in rows.groupby("series_id"):
        group = group.sort_values("received_at")
        cut = int(len(group) * TRAIN_FRACTION)
        train_parts.append(group.iloc[:cut])
        test_parts.append(group.iloc[cut:])
    return pd.concat(train_parts, ignore_index=True), pd.concat(test_parts, ignore_index=True)


def main() -> None:
    from ml.fetch_data import STATIONS

    all_rows: list[dict] = []
    manifest: dict = {"real_stations": [], "synthetic_runs": 0}

    for idx, station in enumerate(STATIONS):
        station_dir = RAW_DIR / station.station_id.rstrip("_")
        if not station_dir.exists():
            continue
        series = load_real_station(station_dir, station.station_id, station.name, station.alert, node_id=1000 + idx)
        if not series.readings:
            continue
        labels = label_series(series.readings, series.alert_m)
        rows = build_rows_for_series(series.readings, labels, series_id=f"real-{station.station_id}", source="real")
        all_rows.extend(rows)
        n_positive = sum(1 for r in rows if r["label"] == 1)
        manifest["real_stations"].append(
            {
                "station_id": station.station_id,
                "name": station.name,
                "alert_m": series.alert_m,
                "raw_readings": len(series.readings),
                "labeled_rows": len(rows),
                "positive_rows": n_positive,
                "date_range": [series.readings[0].received_at.isoformat(), series.readings[-1].received_at.isoformat()],
            }
        )
        print(f"real {station.station_id} ({station.name}): {len(rows)} labeled rows, {n_positive} positive")

    n_synthetic_runs = 200
    for series_id, readings, labels in generate_synthetic_runs(n_synthetic_runs):
        rows = build_rows_for_series(readings, labels, series_id=series_id, source="synthetic")
        all_rows.extend(rows)
    manifest["synthetic_runs"] = n_synthetic_runs

    df = pd.DataFrame(all_rows)
    manifest["total_rows"] = len(df)
    manifest["positive_rows"] = int(df["label"].sum())
    manifest["positive_rate"] = float(df["label"].mean())
    print(f"\nTotal: {len(df)} rows, {manifest['positive_rows']} positive ({manifest['positive_rate']:.3%})")

    train_df, test_df = temporal_split(df)
    manifest["train_rows"] = len(train_df)
    manifest["test_rows"] = len(test_df)
    manifest["train_positive_rate"] = float(train_df["label"].mean())
    manifest["test_positive_rate"] = float(test_df["label"].mean())

    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    train_df.to_csv(PROCESSED_DIR / "train.csv", index=False)
    test_df.to_csv(PROCESSED_DIR / "test.csv", index=False)
    (PROCESSED_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"Wrote {len(train_df)} train / {len(test_df)} test rows to {PROCESSED_DIR}")


if __name__ == "__main__":
    main()
