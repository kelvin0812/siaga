"""
Exports the trained phase model for the Flutter app, which runs it on the phone (no server needed).

LightGBM's own text model is large and awkward to parse, so every decision tree is flattened into plain arrays
in app/assets/phase_model.json. The app walks the trees itself. Because a second implementation could drift, this
also writes app/test/fixtures/phase_fixture.json: real rig rows with the answers the Python predictor gives, which
the app's tests must reproduce exactly.

    python -m ml.rig.export_app
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
MODEL_DIR = ROOT / "backend" / "models" / "phase_model"
CSV = ROOT / "ml" / "data" / "rig" / "sensor_table_rows.csv"
APP_MODEL = ROOT / "app" / "assets" / "phase_model.json"
APP_FIXTURE = ROOT / "app" / "test" / "fixtures" / "phase_fixture.json"
SEGMENTS = [(480, 1060), (1700, 1850)]      # contiguous stretches that cross the Phase 1 to 2 and 3 to 4 boundaries


def flatten_tree(info: dict) -> dict:
    """Turn LightGBM's nested tree into arrays. A negative child means a leaf: leaf index = ~child."""
    feats: list[int] = []
    thr: list[float] = []
    left: list[int] = []
    right: list[int] = []
    leaves: list[float] = []

    def walk(node: dict) -> int:
        if "leaf_value" in node:
            leaves.append(float(node["leaf_value"]))
            return ~(len(leaves) - 1)
        idx = len(feats)
        feats.append(int(node["split_feature"]))
        thr.append(float(node["threshold"]))
        left.append(0)
        right.append(0)
        if node.get("decision_type", "<=") != "<=":
            raise ValueError("only numerical <= splits are supported")
        left[idx] = walk(node["left_child"])
        right[idx] = walk(node["right_child"])
        return idx

    walk(info["tree_structure"])
    return {"f": feats, "t": thr, "l": left, "r": right, "v": leaves}


def export_booster(path: Path) -> dict:
    import lightgbm as lgb

    dump = lgb.Booster(model_file=str(path)).dump_model()
    return {"num_class": int(dump["num_class"]), "trees": [flatten_tree(t) for t in dump["tree_info"]]}


def eval_exported(model: dict, x: list[float]) -> list[float]:
    """Walk the exported trees the way the app does and return class probabilities."""
    k = model["num_class"]
    raw = [0.0] * k
    for i, tree in enumerate(model["trees"]):
        if not tree["f"]:
            raw[i % k] += tree["v"][0]
            continue
        n = 0
        while True:
            nxt = tree["l"][n] if x[tree["f"][n]] <= tree["t"][n] else tree["r"][n]
            if nxt < 0:
                raw[i % k] += tree["v"][~nxt]
                break
            n = nxt
    m = max(raw)
    e = [math.exp(r - m) for r in raw]
    s = sum(e)
    return [v / s for v in e]


def main() -> None:
    from backend.app.phase_model import PhasePredictor

    meta = json.loads((MODEL_DIR / "phase_model.json").read_text(encoding="utf-8"))
    app_model = {
        "level_features": meta["level_features"], "other_features": meta["other_features"],
        "level_weight": meta["level_weight"], "smoothing_readings": meta["smoothing_readings"],
        "calibration": meta["calibration"], "band_edges_height_cm": meta["band_edges_height_cm"],
        "level": export_booster(MODEL_DIR / "level_model.txt"),
        "others": export_booster(MODEL_DIR / "others_model.txt"),
    }
    APP_MODEL.parent.mkdir(parents=True, exist_ok=True)
    APP_MODEL.write_text(json.dumps(app_model, separators=(",", ":")), encoding="utf-8")
    print(f"wrote {APP_MODEL} ({APP_MODEL.stat().st_size // 1024} KB)")

    df = pd.read_csv(CSV)
    df["t"] = pd.to_datetime(df["created_at"], utc=True)
    df = df.sort_values("t").reset_index(drop=True)
    cases = []
    for a, b in SEGMENTS:
        predictor = PhasePredictor(MODEL_DIR)
        rows, expected = [], []
        t0 = df["t"].iloc[a]
        for _, r in df.iloc[a:b].iterrows():
            t_s = (r["t"] - t0).total_seconds()
            row = {"t": t_s, "dist": float(r["dist"]), "flow": float(r["flow"]), "soil": float(r["soil"]),
                   "accel": [float(r["accel_x"]), float(r["accel_y"]), float(r["accel_z"])],
                   "gyro": [float(r["gyro_x"]), float(r["gyro_y"]), float(r["gyro_z"])]}
            res = predictor.update(t_s, row["dist"], row["flow"], row["soil"], tuple(row["accel"]), tuple(row["gyro"]))
            rows.append(row)
            expected.append(None if res is None else {"phase": res.phase, "raw": res.raw_phase,
                                                       "probs": list(res.probabilities), "features": res.features})
        cases.append({"rows": rows, "expected": expected})
    APP_FIXTURE.parent.mkdir(parents=True, exist_ok=True)
    APP_FIXTURE.write_text(json.dumps({"cases": cases}, separators=(",", ":")), encoding="utf-8")
    print(f"wrote {APP_FIXTURE} ({APP_FIXTURE.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
