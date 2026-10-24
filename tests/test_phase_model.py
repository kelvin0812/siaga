from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from backend.app.phase_model import FeatureStream
from ml.rig.features import build_features

MODEL_DIR = Path(__file__).resolve().parents[1] / "backend" / "models" / "phase_model"
CAL = {"baseline_dist_cm": 31.0, "rest_accel": [9.78, -0.5, 0.8], "gyro_bias": [0.13, -0.06, 0.01]}


def synthetic_rig(n=200, seed=3):
    rng = np.random.default_rng(seed)
    t = pd.Timestamp("2026-10-23 12:00:00", tz="UTC") + pd.to_timedelta(np.cumsum(rng.uniform(2.5, 3.6, n)), unit="s")
    dist = 31 - np.clip(np.arange(n) - 60, 0, 90) * 0.04 + rng.normal(0, 0.2, n)
    dist[[30, 77]] = 0.0                                   # two dropouts, which both paths must skip
    return pd.DataFrame({
        "created_at": t.astype(str), "dist": dist, "flow": 180 + rng.normal(0, 20, n) + (np.arange(n) > 100) * 90,
        "soil": 450 + rng.normal(0, 6, n), "accel_x": 9.78 + rng.normal(0, 0.05, n), "accel_y": -0.5 + rng.normal(0, 0.3, n),
        "accel_z": 0.8 + rng.normal(0, 0.3, n), "gyro_x": 0.13 + rng.normal(0, 0.03, n),
        "gyro_y": -0.06 + rng.normal(0, 0.03, n), "gyro_z": 0.01 + rng.normal(0, 0.05, n),
    })


def test_live_features_match_training_features():
    df = synthetic_rig()
    df = df[df["dist"] > 0].reset_index(drop=True)
    batch = build_features(df, CAL)
    secs = (pd.to_datetime(df["created_at"], utc=True) - pd.to_datetime(df["created_at"], utc=True).iloc[0]).dt.total_seconds()
    stream = FeatureStream(CAL["baseline_dist_cm"], CAL["rest_accel"], CAL["gyro_bias"])
    matched = 0
    for i, row in df.iterrows():
        live = stream.update(secs[i], row["dist"], row["flow"], row["soil"],
                             (row["accel_x"], row["accel_y"], row["accel_z"]), (row["gyro_x"], row["gyro_y"], row["gyro_z"]))
        trained = batch.loc[i]
        if trained.isna().any():
            assert live is None
            continue
        assert live is not None
        for name in batch.columns:
            assert live[name] == pytest.approx(trained[name], rel=1e-6, abs=1e-9), (i, name)
        matched += 1
    assert matched > 100


def test_dropout_rows_are_skipped():
    stream = FeatureStream(31.0, CAL["rest_accel"], CAL["gyro_bias"])
    assert stream.update(0.0, 0.0, 190, 450, (9.78, -0.5, 0.8), (0.13, -0.06, 0.01)) is None


def test_trained_model_recognises_the_two_ends_of_the_ladder():
    pytest.importorskip("lightgbm")
    from backend.app.phase_model import PhasePredictor

    predictor = PhasePredictor(MODEL_DIR)
    rest = (9.78, -0.535, 0.84)
    gyro = (0.13, -0.06, 0.01)
    quiet = [predictor.update(i * 3.0, 30.9, 190, 454, rest, gyro) for i in range(60)]
    assert quiet[-1] is not None and quiet[-1].phase == 1
    high = [predictor.update(180 + i * 3.0, 26.4, 232, 517, rest, gyro) for i in range(60)]
    assert high[-1] is not None and high[-1].phase == 4 and high[-1].name == "Evacuate"


def test_a_changed_mounting_height_only_needs_a_new_baseline():
    pytest.importorskip("lightgbm")
    from backend.app.phase_model import PhasePredictor

    predictor = PhasePredictor(MODEL_DIR, baseline_dist_cm=40.0)      # sensor mounted 9 cm higher
    rest, gyro = (9.78, -0.535, 0.84), (0.13, -0.06, 0.01)
    out = [predictor.update(i * 3.0, 40.0, 190, 454, rest, gyro) for i in range(60)]
    assert out[-1].phase == 1
