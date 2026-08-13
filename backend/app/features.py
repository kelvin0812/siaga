"""
Feature builder (build brief Section 6.3): lagged level, first/second
derivatives, cumulative rainfall over multiple windows, an antecedent
soil-moisture index, tilt delta, and cyclical time encodings — the input
vector for Tier 2 inference (tier2.py).

Nothing here trains the model; Section 7 is explicit that only historical
public records and dedicated synthetic hydrographs do that. This module
only has to produce the same feature vector shape at inference time that
the (future) training pipeline produces.
"""
from __future__ import annotations

import math
from datetime import datetime, timedelta

from backend.app.repository import ReadingRecord
from shared.constants import TIP_RESOLUTION_MM

LAG_MINUTES = (5, 15, 30, 60)
RAIN_WINDOWS_HOURS = (1, 3, 6, 24)


def _nearest_at_or_before(readings: list[ReadingRecord], target: datetime) -> ReadingRecord | None:
    candidates = [r for r in readings if r.received_at <= target]
    return candidates[-1] if candidates else None


def build_features(now: datetime, readings: list[ReadingRecord]) -> dict[str, float]:
    """
    readings: a node's history up to and including the current reading,
    ascending by received_at. Must contain at least one reading.
    """
    if not readings:
        raise ValueError("build_features requires at least one reading")
    readings = sorted(readings, key=lambda r: r.received_at)
    current = readings[-1]

    features: dict[str, float] = {}

    for lag_min in LAG_MINUTES:
        target = now - timedelta(minutes=lag_min)
        lagged = _nearest_at_or_before(readings, target)
        # No history that far back yet: fall back to the current height —
        # treats "no data" as "no change" rather than fabricating a trend.
        features[f"level_lag_{lag_min}m"] = (lagged or current).height_m

    if len(readings) >= 2:
        prev = readings[-2]
        dt_min = max((current.received_at - prev.received_at).total_seconds() / 60.0, 1e-6)
        d1 = (current.height_m - prev.height_m) / dt_min
    else:
        d1 = 0.0
    features["level_d1_m_per_min"] = d1

    if len(readings) >= 3:
        prev, prev2 = readings[-2], readings[-3]
        dt_min_prev = max((prev.received_at - prev2.received_at).total_seconds() / 60.0, 1e-6)
        d1_prev = (prev.height_m - prev2.height_m) / dt_min_prev
        dt_min_cur = max((current.received_at - prev.received_at).total_seconds() / 60.0, 1e-6)
        d2 = (d1 - d1_prev) / dt_min_cur
    else:
        d2 = 0.0
    features["level_d2_m_per_min2"] = d2

    for hours in RAIN_WINDOWS_HOURS:
        since = now - timedelta(hours=hours)
        tips = sum(r.rain_tips for r in readings if r.received_at >= since)
        features[f"rain_cum_{hours}h_mm"] = tips * TIP_RESOLUTION_MM

    # Antecedent soil-moisture index: the prototype has no infiltration
    # model, so the most recent sensor reading is used directly as the
    # proxy — the node already reports a saturation percentage.
    features["antecedent_soil_moisture_pct"] = float(current.soil_pct)

    features["tilt_x_lsb"] = float(current.tilt_x)
    features["tilt_y_lsb"] = float(current.tilt_y)
    features["tilt_magnitude_lsb"] = math.hypot(current.tilt_x, current.tilt_y)

    hour_frac = now.hour + now.minute / 60.0
    features["time_of_day_sin"] = math.sin(2 * math.pi * hour_frac / 24.0)
    features["time_of_day_cos"] = math.cos(2 * math.pi * hour_frac / 24.0)

    day_of_year = now.timetuple().tm_yday
    features["season_sin"] = math.sin(2 * math.pi * day_of_year / 365.25)
    features["season_cos"] = math.cos(2 * math.pi * day_of_year / 365.25)

    return features


FEATURE_NAMES = tuple(
    [f"level_lag_{m}m" for m in LAG_MINUTES]
    + ["level_d1_m_per_min", "level_d2_m_per_min2"]
    + [f"rain_cum_{h}h_mm" for h in RAIN_WINDOWS_HOURS]
    + [
        "antecedent_soil_moisture_pct",
        "tilt_x_lsb",
        "tilt_y_lsb",
        "tilt_magnitude_lsb",
        "time_of_day_sin",
        "time_of_day_cos",
        "season_sin",
        "season_cos",
    ]
)
