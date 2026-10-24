"""
Runs the rule-based engine (backend/app/rules.py) over the bench rig's
recorded readings and prints every state change with the reasons. Nothing
is trained, and the rig's data is only read, so this doubles as a check of
how the rules behave on real sensor output.

    python -m backend.rig_check --supabase --mount-cm 40 --alert-cm 30
    python -m backend.rig_check --csv sensor_table.csv --mount-cm 40 --alert-cm 30

If the rig reports raw soil and flow numbers, map them or the rules will misread them: --soil-dry and
--soil-wet turn raw soil into a percentage, and --flow-active sets the flow level that means water arriving.

Readings more than --gap seconds apart are treated as separate runs and
each starts from a fresh engine. Soil is taken as a 0 to 100 percentage.
"""
from __future__ import annotations

import argparse
import csv
from datetime import datetime

import httpx

from backend.app.bench_eval import _SUPABASE_ANON_KEY, _SUPABASE_URL
from backend.app.rules import Assessment, RigSample, RuleConfig, evaluate_series


def _ts(v: str) -> float:
    return datetime.fromisoformat(v.replace("Z", "+00:00")).timestamp()


def _sample(row: dict, soil_dry: float | None, soil_wet: float | None) -> RigSample:
    f = lambda k: float(row.get(k) or 0.0)  # noqa: E731
    soil = f("soil")
    if soil_dry is not None and soil_wet is not None:
        soil = 100.0 * (soil - soil_dry) / (soil_wet - soil_dry)     # raw reading -> 0 to 100 percent
    return RigSample(
        t=_ts(row["created_at"]), soil=soil, dist_cm=f("dist"), flow=f("flow"),
        accel=(f("accel_x"), f("accel_y"), f("accel_z")), gyro=(f("gyro_x"), f("gyro_y"), f("gyro_z")),
    )


def load_csv(path: str) -> list[dict]:
    with open(path, newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def load_supabase() -> list[dict]:
    rows: list[dict] = []
    headers = {"apikey": _SUPABASE_ANON_KEY, "Authorization": f"Bearer {_SUPABASE_ANON_KEY}"}
    with httpx.Client(timeout=20.0) as client:
        while True:
            r = client.get(
                f"{_SUPABASE_URL}/rest/v1/sensor_table",
                params={"select": "*", "order": "created_at.asc", "limit": 1000, "offset": len(rows)},
                headers=headers,
            )
            r.raise_for_status()
            page = r.json()
            rows.extend(page)
            if len(page) < 1000:
                return rows


def split_runs(samples: list[RigSample], gap_s: float) -> list[list[RigSample]]:
    runs: list[list[RigSample]] = []
    for s in samples:
        if runs and s.t - runs[-1][-1].t <= gap_s:
            runs[-1].append(s)
        else:
            runs.append([s])
    return runs


def main() -> None:
    ap = argparse.ArgumentParser()
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--csv")
    src.add_argument("--supabase", action="store_true")
    ap.add_argument("--mount-cm", type=float, default=RuleConfig.mount_cm)
    ap.add_argument("--alert-cm", type=float, default=RuleConfig.alert_cm)
    ap.add_argument("--gap", type=float, default=120.0, help="seconds of silence that start a new run")
    ap.add_argument("--soil-dry", type=float, help="raw soil reading when dry (0 percent); needed if soil is not already 0 to 100")
    ap.add_argument("--soil-wet", type=float, help="raw soil reading when saturated (100 percent)")
    ap.add_argument("--flow-active", type=float, default=RuleConfig.flow_active,
                    help="flow reading that counts as water arriving; set it above the pump's normal level")
    args = ap.parse_args()

    rows = load_supabase() if args.supabase else load_csv(args.csv)
    # a distance of 0 means the sensor heard no echo, so that reading is skipped
    samples = sorted((_sample(r, args.soil_dry, args.soil_wet) for r in rows if float(r.get("dist") or 0) > 0), key=lambda s: s.t)
    cfg = RuleConfig(mount_cm=args.mount_cm, alert_cm=args.alert_cm, flow_active=args.flow_active)
    runs = split_runs(samples, args.gap)
    print(f"{len(samples)} readings in {len(runs)} run(s)")

    for i, run in enumerate(runs, 1):
        out: list[Assessment] = evaluate_series(run, cfg)
        t0 = run[0].t
        peak = max(o.state for o in out)
        print(f"\nrun {i}: {len(run)} readings over {run[-1].t - t0:.0f} s, peak state {peak.name}")
        prev = None
        for o in out:
            if o.state != prev:
                why = "; ".join(o.reasons) or "all channels normal"
                print(f"  +{o.t - t0:6.0f} s  {o.state.name:<8} (flood {o.flood.name}, landslide {o.landslide.name})  {why}")
                prev = o.state
        print(f"  height {min(o.height_cm for o in out):.1f} to {max(o.height_cm for o in out):.1f} cm, "
              f"soil {min(o.soil_pct for o in out):.0f} to {max(o.soil_pct for o in out):.0f}%, "
              f"max tilt {max((o.tilt_deg or 0) for o in out):.1f} deg")


if __name__ == "__main__":
    main()
