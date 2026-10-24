"""
Live phase recognition for the bench rig: the pure-Python twin of ml/rig/features.py plus the trained models.

Feed it one reading at a time, in time order. It returns the phase (1 Normal to 4 Evacuate) once it has seen
enough readings to fill its windows, and None before that or when the ultrasonic dropped out.

How the phase is decided:
  - one model looks only at the water level (height above the rig's normal level, and how fast it is rising);
  - one model looks at flow, soil and tilt;
  - the two are blended with the water level weighted most (level_weight in phase_model.json), because the
    water level is the most reliable of the four sensors;
  - the phase shown is the most common answer of the last few readings, so one noisy reading cannot flip it.

If the sensor is mounted at a different height on the day, pass baseline_dist_cm (the distance read at the
normal level) and the model still works, since the water level is measured relative to it.
"""
from __future__ import annotations

import json
import math
from dataclasses import dataclass
from pathlib import Path
from statistics import median

PHASE_NAMES = ("Normal", "Watch", "Warning", "Evacuate")


@dataclass(frozen=True, slots=True)
class PhaseResult:
    phase: int                       # 1 to 4, smoothed
    raw_phase: int                   # 1 to 4, this reading alone
    probabilities: tuple[float, ...]
    features: dict[str, float]

    @property
    def name(self) -> str:
        return PHASE_NAMES[self.phase - 1]


class FeatureStream:
    """The same trailing-window features as ml/rig/features.py, computed one reading at a time."""

    def __init__(self, baseline_dist_cm: float, rest_accel: list[float], gyro_bias: list[float]) -> None:
        self.baseline = baseline_dist_cm
        self.rest = rest_accel
        self.bias = gyro_bias
        self._dists: list[float] = []
        self._flows: list[float] = []
        self._soils: list[float] = []
        self._levels: list[float | None] = []
        self._times: list[float] = []
        self._tilts: list[float] = []
        self._gyros: list[float] = []

    def update(self, t_s: float, dist_cm: float, flow: float, soil: float,
               accel: tuple[float, float, float], gyro: tuple[float, float, float]) -> dict[str, float] | None:
        if dist_cm <= 0:                       # no echo: skipped, exactly as in training
            return None
        self._times.append(t_s)
        self._dists.append(dist_cm)
        self._flows.append(flow)
        self._soils.append(soil)
        level = median(self._dists[-10:]) if len(self._dists) >= 5 else None
        self._levels.append(level)

        rest_norm = math.sqrt(sum(v * v for v in self.rest))
        a_norm = math.sqrt(sum(v * v for v in accel))
        cos = sum(a * r for a, r in zip(accel, self.rest)) / (a_norm * rest_norm)
        self._tilts.append(math.degrees(math.acos(max(-1.0, min(1.0, cos)))))
        self._gyros.append(math.sqrt(sum((g - b) ** 2 for g, b in zip(gyro, self.bias))))

        rate = None
        if level is not None and len(self._levels) > 20 and self._levels[-21] is not None:
            minutes = (t_s - self._times[-21]) / 60.0
            rate = -(level - self._levels[-21]) / minutes
        feats = {
            "height_cm": None if level is None else self.baseline - level,
            "rate_cm_min": rate,
            "flow_med": median(self._flows[-10:]) if len(self._flows) >= 5 else None,
            "soil_med": median(self._soils[-10:]) if len(self._soils) >= 5 else None,
            "tilt_deg": median(self._tilts[-5:]) if len(self._tilts) >= 3 else None,
            "gyro_peak": max(self._gyros[-10:]) if len(self._gyros) >= 3 else None,
        }
        self._trim()
        if any(v is None for v in feats.values()):
            return None
        return feats  # type: ignore[return-value]

    def _trim(self, keep: int = 40) -> None:
        """Only the last ~21 readings are ever looked at, so a long-running stream does not grow forever."""
        for series in (self._dists, self._flows, self._soils, self._levels, self._times, self._tilts, self._gyros):
            if len(series) > keep:
                del series[: len(series) - keep]


class PhasePredictor:
    def __init__(self, model_dir: str | Path, baseline_dist_cm: float | None = None) -> None:
        import lightgbm as lgb

        model_dir = Path(model_dir)
        meta = json.loads((model_dir / "phase_model.json").read_text(encoding="utf-8"))
        cal = meta["calibration"]
        self._level_features = meta["level_features"]
        self._other_features = meta["other_features"]
        self._weight = float(meta["level_weight"])
        self._smooth = int(meta["smoothing_readings"])
        self._level = lgb.Booster(model_file=str(model_dir / "level_model.txt"))
        self._others = lgb.Booster(model_file=str(model_dir / "others_model.txt"))
        self._stream = FeatureStream(baseline_dist_cm if baseline_dist_cm is not None else cal["baseline_dist_cm"],
                                     cal["rest_accel"], cal["gyro_bias"])
        self._recent: list[int] = []

    def update(self, t_s: float, dist_cm: float, flow: float, soil: float,
               accel: tuple[float, float, float], gyro: tuple[float, float, float]) -> PhaseResult | None:
        feats = self._stream.update(t_s, dist_cm, flow, soil, accel, gyro)
        if feats is None:
            return None
        pl = self._level.predict([[feats[f] for f in self._level_features]])[0]
        po = self._others.predict([[feats[f] for f in self._other_features]])[0]
        prob = [self._weight * a + (1 - self._weight) * b for a, b in zip(pl, po)]
        raw = max(range(4), key=lambda i: prob[i])
        self._recent.append(raw)
        window = self._recent[-self._smooth:]
        phase = max(range(4), key=lambda i: (window.count(i), -i))     # most common; ties go to the lower phase
        return PhaseResult(phase=phase + 1, raw_phase=raw + 1, probabilities=tuple(float(p) for p in prob), features=feats)
