"""
Guardrail (build brief Section 3.2 / 6.3): the Tier 2 probability alone
never reaches the state machine. It's combined with independent-channel
corroboration and an optional site-specific absolute threshold, producing
the GuardrailInputs the state machine actually evaluates — this is what
stops a single drifting sensor or an overconfident model from triggering
an evacuation on its own.

Per-channel thresholds below (tilt, soil, rain) are prototype defaults,
not hydrologically derived — same caveat as the node firmware's own
rate-of-rise threshold in Section 6.1. They should be recalibrated per
catchment once real sensor data exists.
"""
from __future__ import annotations

from dataclasses import dataclass

from backend.app.repository import ReadingRecord
from backend.app.state_machine import GuardrailInputs
from backend.app.tier2 import Tier2Model
from shared.frame import FLAG_TIER1_ANOMALY


@dataclass(frozen=True, slots=True)
class GuardrailThresholds:
    tilt_magnitude_lsb: float = 30.0  # 0.1 deg/LSB -> 3.0 degrees
    soil_saturation_pct: float = 85.0
    rain_intensity_1h_mm: float = 20.0


DEFAULT_THRESHOLDS = GuardrailThresholds()


def count_corroborating_channels(
    reading: ReadingRecord,
    features: dict[str, float],
    thresholds: GuardrailThresholds = DEFAULT_THRESHOLDS,
) -> int:
    """
    Independent channels: the node's own Tier 1 water-level anomaly flag,
    tilt (slope movement precursor), soil saturation, and rainfall
    intensity. Kept separate from re-deriving a level-rate channel here,
    since that would just be re-testing the same signal the node's Tier 1
    flag already summarizes under a different name.
    """
    count = 0
    if reading.flags & FLAG_TIER1_ANOMALY:
        count += 1
    if features["tilt_magnitude_lsb"] >= thresholds.tilt_magnitude_lsb:
        count += 1
    if reading.soil_pct >= thresholds.soil_saturation_pct:
        count += 1
    if features["rain_cum_1h_mm"] >= thresholds.rain_intensity_1h_mm:
        count += 1
    return count


def evaluate_guardrail(
    reading: ReadingRecord,
    features: dict[str, float],
    tier2_model: Tier2Model,
    critical_height_m: float | None = None,
    thresholds: GuardrailThresholds = DEFAULT_THRESHOLDS,
) -> GuardrailInputs:
    tier2_p = tier2_model.predict(features)
    corroborating = count_corroborating_channels(reading, features, thresholds)
    physical_breach = critical_height_m is not None and reading.height_m >= critical_height_m
    return GuardrailInputs(
        tier1_anomaly=bool(reading.flags & FLAG_TIER1_ANOMALY),
        tier2_p=tier2_p,
        corroborating_channels=corroborating,
        physical_breach=physical_breach,
    )
