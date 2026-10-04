"""
Tier 2 inference interface (build brief Section 6.3 / 7). The real model
is LightGBM, trained on historical public rainfall/water-level records
plus synthetic hydrographs (Section 7) — see ml/train.py for the training pipeline.

`HeuristicTier2Stub` exists only so the guardrail and state machine have
something to run against without a trained model present (e.g. a fresh
clone before `ml/train.py` has been run) — same resilience philosophy as
the rest of the backend (Section 2: degrade visibly, don't crash).
"""
from __future__ import annotations

import json
from pathlib import Path
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
    Loads the persisted model + feature list that Section 7.1 requires be
    kept together (ml/train.py writes model.txt + feature_names.json +
    metrics.json into the same directory). The feature list is checked
    against backend.app.features.FEATURE_NAMES at load time — if they've
    drifted apart, that's a train/serve skew bug, and failing loudly here
    beats silently feeding the model columns in the wrong order.
    """

    def __init__(self, model_dir: str) -> None:
        import lightgbm as lgb

        from backend.app.features import FEATURE_NAMES

        model_path = Path(model_dir)
        feature_names_path = model_path / "feature_names.json"
        model_file = model_path / "model.txt"

        if not model_file.exists():
            raise FileNotFoundError(
                f"no trained Tier 2 model at {model_file} — run `python -m ml.train` "
                "first, or use HeuristicTier2Stub until then"
            )

        persisted_features = json.loads(feature_names_path.read_text(encoding="utf-8"))
        if persisted_features != list(FEATURE_NAMES):
            raise ValueError(
                "persisted Tier 2 model's feature list does not match "
                "backend.app.features.FEATURE_NAMES — the model needs "
                "retraining (features.py changed after this model was "
                "trained). Refusing to load a model that would silently "
                "receive features in the wrong order/shape."
            )

        self._feature_names = persisted_features
        self._booster = lgb.Booster(model_file=str(model_file))

    def predict(self, features: dict[str, float]) -> float:
        row = [[features[name] for name in self._feature_names]]
        prob = self._booster.predict(row)[0]
        return max(0.0, min(1.0, float(prob)))
