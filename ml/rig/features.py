"""
Features for the bench rig phase model. Everything uses trailing windows only (a reading never looks at
the future), so the same features can be computed live. backend/app/phase_model.py is the pure-Python live
twin of this file, and a test checks the two give the same numbers.

The water level is expressed as a height above the rig's normal level (baseline distance minus current
distance), so a changed mounting height only needs a new baseline, not a new model.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

LEVEL_FEATURES = ["height_cm", "rate_cm_min"]
OTHER_FEATURES = ["flow_med", "soil_med", "tilt_deg", "gyro_peak"]
CALIBRATION_ROWS = 100       # the first readings of a session, taken while the rig is at rest


def calibration(df: pd.DataFrame, n: int = CALIBRATION_ROWS) -> dict:
    """Resting values measured from the first n valid readings."""
    head = df.head(n)
    return {
        "baseline_dist_cm": float(head["dist"].median()),
        "rest_accel": [float(v) for v in head[["accel_x", "accel_y", "accel_z"]].median()],
        "gyro_bias": [float(v) for v in head[["gyro_x", "gyro_y", "gyro_z"]].median()],
    }


def build_features(df: pd.DataFrame, cal: dict) -> pd.DataFrame:
    """df: rows in time order with created_at, dist, flow, soil, accel_*, gyro_* (dropouts already removed)."""
    t = pd.to_datetime(df["created_at"], utc=True)
    seconds = (t - t.iloc[0]).dt.total_seconds()
    lvl = df["dist"].rolling(10, min_periods=5).median()
    minutes = (seconds - seconds.shift(20)) / 60.0

    out = pd.DataFrame(index=df.index)
    out["height_cm"] = cal["baseline_dist_cm"] - lvl
    out["rate_cm_min"] = -(lvl - lvl.shift(20)) / minutes            # positive = water rising
    out["flow_med"] = df["flow"].rolling(10, min_periods=5).median()
    out["soil_med"] = df["soil"].rolling(10, min_periods=5).median()

    acc = df[["accel_x", "accel_y", "accel_z"]].to_numpy(dtype=float)
    rest = np.asarray(cal["rest_accel"], dtype=float)
    cos = (acc @ rest) / (np.linalg.norm(acc, axis=1) * np.linalg.norm(rest))
    tilt = pd.Series(np.degrees(np.arccos(np.clip(cos, -1, 1))), index=df.index)
    out["tilt_deg"] = tilt.rolling(5, min_periods=3).median()

    gy = df[["gyro_x", "gyro_y", "gyro_z"]].to_numpy(dtype=float) - np.asarray(cal["gyro_bias"], dtype=float)
    out["gyro_peak"] = pd.Series(np.linalg.norm(gy, axis=1), index=df.index).rolling(10, min_periods=3).max()
    return out
