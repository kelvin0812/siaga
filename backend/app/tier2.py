"""
Tier 2 inference interface (build brief Section 6.3 / 7). The real model
is LightGBM, trained on historical public rainfall/water-level records
plus synthetic hydrographs (Section 7) — that training pipeline is
separate future work and out of scope for wiring the backend together.

`HeuristicTier2Stub` exists only so the guardrail and state machine have
something to run against before that model exists. It is NOT calibrated
against real flood data and must not be used to evaluate acceptance
criterion O3 (recall >= 0.90 @ FPR <= 0.10) — that requires the trained
model described in Section 7.1.
"""
from __future__ import annotations

from typing import Protocol


class Tier2Model(Protocol):
    def predict(self, features: dict[str, float]) -> float: ...


class HeuristicTier2Stub:
    """
    Placeholder probability from rate-of-rise and antecedent soil
    moisture only, monotonically increasing and bounded to [0, 1].
    Deliberately simple — it exists to exercise the guardrail and state
    machine end to end (Section 3.5), not to approximate real flood risk.
    """

    def __init__(self, rate_scale_m_per_min: float = 0.05, soil_weight: float = 0.3) -> None:
        self._rate_scale = rate_scale_m_per_min
        self._soil_weight = soil_weight

    def predict(self, features: dict[str, float]) -> float:
        rate = max(0.0, features.get("level_d1_m_per_min", 0.0))
        soil = features.get("antecedent_soil_moisture_pct", 0.0) / 100.0
        rate_component = 1.0 - pow(2.718281828, -rate / self._rate_scale)
        p = (1.0 - self._soil_weight) * rate_component + self._soil_weight * soil * rate_component
        return max(0.0, min(1.0, p))


class LightGBMTier2Model:
    """
    Loads the persisted model + feature list + metrics that Section 7.1
    requires be kept together. Not implemented yet — no trained model
    exists until the Section 7 ML step runs. Constructing this before
    then is a programming error, not a runtime fallback path.
    """

    def __init__(self, model_path: str) -> None:
        raise NotImplementedError(
            "no trained Tier 2 model yet — see build brief Section 7; "
            "use HeuristicTier2Stub until docs/ has a persisted model + metrics"
        )

    def predict(self, features: dict[str, float]) -> float:
        raise NotImplementedError
