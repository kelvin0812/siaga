"""
Trains the bench rig phase model on the rig's own recordings (sensor_table export).

The four phases were run one after another (1, 2, 3, 4), so the labels come from the order of the rows: by
default the four contiguous stretches that best fit the distance readings are found automatically, or you can
pass the last row of each phase with --bounds.

Two models are trained and blended. One sees only the water level, the other sees flow, soil and tilt. The
water level gets the larger share (--level-weight, default 0.6) because it is the most reliable sensor, and the
other three are still considered.

Evaluation never trains on a row next to a test row. Each phase is cut into contiguous blocks, one block per
phase is held out in turn, and PURGE rows on each side of it are dropped from training. All numbers come from
the held-out blocks. This still tests the same recording, so it measures how well the rig's own phases are
recognised, not performance on a different day.

    python -m ml.rig.train
    python -m ml.rig.train --csv path/to/export.csv --bounds 547 1019 1775 2217
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

import lightgbm as lgb
import numpy as np
import pandas as pd
from sklearn.metrics import f1_score

from ml.rig.features import LEVEL_FEATURES, OTHER_FEATURES, build_features, calibration

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CSV = ROOT / "ml" / "data" / "rig" / "sensor_table_rows.csv"
DEFAULT_OUT = ROOT / "backend" / "models" / "phase_model"
PURGE, FOLDS, SMOOTH = 30, 5, 10
PARAMS = dict(objective="multiclass", num_class=4, num_leaves=7, learning_rate=0.05, min_data_in_leaf=15, verbosity=-1, seed=7)
ROUNDS = 150
GROUPS = {"water_level": LEVEL_FEATURES, "flow": ["flow_med"], "soil": ["soil_med"], "tilt": ["tilt_deg", "gyro_peak"]}


def load(csv: Path) -> pd.DataFrame:
    df = pd.read_csv(csv)
    df["t"] = pd.to_datetime(df["created_at"], utc=True)
    df = df.sort_values("t").reset_index(drop=True)
    return df[df["dist"] > 0].reset_index(drop=True)      # a distance of 0 means the sensor heard no echo


def segment(values: np.ndarray, k: int = 4) -> list[int]:
    """Row index where each of the k contiguous stretches ends, minimising the squared error around each mean."""
    n = len(values)
    cs, cs2 = np.r_[0, np.cumsum(values)], np.r_[0, np.cumsum(values ** 2)]
    D = np.full((k + 1, n + 1), np.inf)
    P = np.zeros((k + 1, n + 1), dtype=int)
    D[0, 0] = 0
    for kk in range(1, k + 1):
        for j in range(kk, n + 1):
            i = np.arange(kk - 1, j)
            c = D[kk - 1, i] + (cs2[j] - cs2[i]) - (cs[j] - cs[i]) ** 2 / (j - i)
            a = c.argmin()
            D[kk, j], P[kk, j] = c[a], i[a]
    ends, j = [], n
    for kk in range(k, 0, -1):
        ends.append(j)
        j = P[kk, j]
    return ends[::-1]


def fit(X: pd.DataFrame, y: np.ndarray) -> lgb.Booster:
    return lgb.train(PARAMS, lgb.Dataset(X, label=y), ROUNDS)


def blend(pl: np.ndarray, po: np.ndarray, w: float) -> np.ndarray:
    return w * pl + (1 - w) * po


def smooth(pred: np.ndarray) -> np.ndarray:
    """Live behaviour: the phase shown is the most common answer of the last SMOOTH readings."""
    return pd.Series(pred).rolling(SMOOTH, min_periods=1).apply(lambda s: np.bincount(s.astype(int), minlength=4).argmax()).to_numpy().astype(int)


def score(pred: np.ndarray, y: np.ndarray) -> dict:
    return {"accuracy": round(float((pred == y).mean()), 4), "macro_f1": round(float(f1_score(y, pred, average="macro")), 4),
            "within_one_phase": round(float((np.abs(pred - y) <= 1).mean()), 4)}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", type=Path, default=DEFAULT_CSV)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--level-weight", type=float, default=0.6)
    ap.add_argument("--bounds", type=int, nargs=4, help="last row of each of the four phases (default: found automatically)")
    args = ap.parse_args()

    df = load(args.csv)
    ends = list(args.bounds) if args.bounds else segment(df["dist"].rolling(15, center=True, min_periods=5).median().to_numpy())
    ends = [int(e) for e in ends]
    starts = [0] + ends[:-1]
    y_all = np.zeros(len(df), dtype=int)
    for p, (a, b) in enumerate(zip(starts, ends)):
        y_all[a:b] = p
    cal = calibration(df)
    feats = build_features(df, cal)
    keep = feats.dropna().index
    d, y = feats.loc[keep].reset_index(drop=True), y_all[keep]
    print(f"{len(df)} readings, phase ends at rows {ends}, {len(d)} usable rows, per phase {np.bincount(y).tolist()}")

    by_phase = [np.where(y == p)[0] for p in range(4)]
    oof = {k: np.zeros((len(d), 4)) for k in ("level", "others", "all")}
    drops = {g: [] for g in GROUPS}
    rng = np.random.default_rng(0)
    for k in range(FOLDS):
        test = np.concatenate([np.array_split(ix, FOLDS)[k] for ix in by_phase])
        near = np.zeros(len(d), dtype=bool)
        for i in test:
            near[max(0, i - PURGE): i + PURGE + 1] = True
        train = np.where(~near)[0]
        m_l, m_o = fit(d.loc[train, LEVEL_FEATURES], y[train]), fit(d.loc[train, OTHER_FEATURES], y[train])
        m_a = fit(d.loc[train, LEVEL_FEATURES + OTHER_FEATURES], y[train])
        pl, po = m_l.predict(d.loc[test, LEVEL_FEATURES]), m_o.predict(d.loc[test, OTHER_FEATURES])
        oof["level"][test], oof["others"][test] = pl, po
        oof["all"][test] = m_a.predict(d.loc[test, LEVEL_FEATURES + OTHER_FEATURES])
        base = (blend(pl, po, args.level_weight).argmax(1) == y[test]).mean()
        for name, cols in GROUPS.items():       # accuracy lost when one sensor's readings are scrambled
            lost = []
            for _ in range(5):
                X = d.loc[test, LEVEL_FEATURES + OTHER_FEATURES].copy()
                X[cols] = X[cols].sample(frac=1.0, random_state=int(rng.integers(1e9))).to_numpy()
                acc = (blend(m_l.predict(X[LEVEL_FEATURES]), m_o.predict(X[OTHER_FEATURES]), args.level_weight).argmax(1) == y[test]).mean()
                lost.append(base - acc)
            drops[name].append(float(np.mean(lost)))

    # fixed distance cut-offs halfway between the phase medians: the simple rule the model has to beat
    med = [float(np.median(df["dist"].to_numpy()[a:b])) for a, b in zip(starts, ends)]
    cuts = [(med[i] + med[i + 1]) / 2 for i in range(3)]                 # in cm of distance, falling
    height_cuts = [cal["baseline_dist_cm"] - c for c in cuts]            # in cm of height above normal, rising
    band = np.digitize(d["height_cm"], height_cuts)
    results = {
        "distance_bands_only (no machine learning)": score(band, y),
        "water level model only": score(oof["level"].argmax(1), y),
        "flow + soil + tilt only": score(oof["others"].argmax(1), y),
        "all sensors, one model": score(oof["all"].argmax(1), y),
    }
    for w in (0.4, 0.5, 0.6, 0.7, 0.8, 0.9):
        results[f"blend, water level weight {int(w * 100)}%"] = score(blend(oof["level"], oof["others"], w).argmax(1), y)
    chosen = smooth(blend(oof["level"], oof["others"], args.level_weight).argmax(1))
    results[f"CHOSEN: blend {int(args.level_weight * 100)}% + smoothed over {SMOOTH} readings"] = score(chosen, y)
    total = sum(max(np.mean(v), 0) for v in drops.values()) or 1.0
    contribution = {g: round(float(max(np.mean(v), 0) / total * 100), 1) for g, v in drops.items()}
    for name, r in results.items():
        print(f"{name:55s} accuracy {r['accuracy']:.3f}  macro-F1 {r['macro_f1']:.3f}  within one phase {r['within_one_phase']:.3f}")
    print("sensor contribution inside the blend (%):", contribution)

    args.out.mkdir(parents=True, exist_ok=True)
    fit(d[LEVEL_FEATURES], y).save_model(str(args.out / "level_model.txt"))
    fit(d[OTHER_FEATURES], y).save_model(str(args.out / "others_model.txt"))
    meta = {
        "trained_at": datetime.now(timezone.utc).isoformat(), "source": str(args.csv.name), "rows": int(len(df)),
        "phase_end_rows": ends, "level_features": LEVEL_FEATURES, "other_features": OTHER_FEATURES,
        "level_weight": args.level_weight, "smoothing_readings": SMOOTH, "calibration": cal,
        "band_edges_height_cm": [round(c, 3) for c in height_cuts],
        "evaluation": {"method": f"{FOLDS} contiguous blocks per phase, {PURGE} rows purged around each test block", "results": results,
                       "sensor_contribution_pct": contribution},
        "caveat": "Tested on blocks of the same recording. It shows the rig's phases are recognised, not that it generalises to another day.",
    }
    (args.out / "phase_model.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print("saved to", args.out)


if __name__ == "__main__":
    main()
