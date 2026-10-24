"""
Rule-based risk engine for the four sensors the prototype actually has:
ultrasonic distance (water level), soil moisture, flow, and an MPU-6050
(accelerometer + gyroscope).

This is not machine learning and nothing here is trained. Each rule encodes
a physical expectation:
  - water rising toward the alert line is flood risk, and the rate gives a
    time to reach it;
  - inflow (flow sensor) and saturated soil make a flood or slope failure
    more likely, so they corroborate;
  - a sustained change in the board's tilt from its resting position means
    the slope or mounting is moving, which is the landslide signal.

Like the main guardrail, anything short of a physical-limit breach needs two
independent channels to agree before it escalates, so one noisy sensor can't
raise an alarm. The thresholds in RuleConfig are bench-scale starting values,
not field-calibrated ones. A real deployment would set them per site, and
the dwell times here (seconds) stand in for the node's 10 and 30 minutes.
"""
from __future__ import annotations

import math
from collections import deque
from dataclasses import dataclass

from backend.app.state_machine import RiskState


@dataclass(frozen=True)
class RuleConfig:
    # Geometry of the water-level measurement
    mount_cm: float = 40.0          # sensor face to the empty tank floor
    alert_cm: float = 30.0          # marked alert line, height above the floor
    median_n: int = 5               # a single raw distance never drives a decision
    # Water level
    rate_window_s: float = 20.0
    min_rise_cm_per_s: float = 0.05  # below this the level counts as steady
    tta_warn_s: float = 120.0        # time-to-alert that counts as urgent
    # Flow (inflow)
    flow_window_s: float = 10.0
    flow_active: float = 1.0         # mean flow reading that counts as water arriving
    # Soil
    soil_saturated_pct: float = 70.0
    # Slope movement (MPU-6050), degrees away from the resting tilt
    baseline_samples: int = 10
    tilt_watch_deg: float = 2.0
    tilt_warn_deg: float = 5.0
    tilt_evac_deg: float = 10.0
    # A physical breach or a tilt must hold this long before it counts. A hand under the sensor
    # or a bump on the table lasts a few seconds; a real event does not go away.
    sustain_s: float = 5.0
    # Hysteresis: quick to warn, slow to stand down
    warning_dwell_s: float = 5.0
    stand_down_s: float = 20.0


@dataclass(frozen=True, slots=True)
class RigSample:
    t: float                         # seconds
    soil: float                      # percent, 0 to 100
    dist_cm: float
    flow: float
    accel: tuple[float, float, float]
    gyro: tuple[float, float, float]


@dataclass(frozen=True, slots=True)
class Assessment:
    t: float
    state: RiskState
    flood: RiskState
    landslide: RiskState
    height_cm: float
    rise_cm_per_min: float
    time_to_alert_s: float | None
    soil_pct: float
    flow_avg: float
    tilt_deg: float | None
    reasons: tuple[str, ...]


def _median(xs: list[float]) -> float:
    s = sorted(xs)
    n = len(s)
    return s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2


def _slope(points: list[tuple[float, float]]) -> float:
    """Theil-Sen slope (units per second): the median of all pairwise slopes. Unlike a
    least-squares fit, a few outlier readings (a hand under the sensor, a glitch) barely move it."""
    slopes = [
        (h2 - h1) / (t2 - t1)
        for i, (t1, h1) in enumerate(points)
        for t2, h2 in points[i + 1:]
        if t2 > t1
    ]
    return _median(slopes) if slopes else 0.0


def _angle_deg(a: tuple[float, float, float], b: tuple[float, float, float]) -> float:
    na, nb = math.hypot(*a), math.hypot(*b)
    if na == 0 or nb == 0:
        return 0.0
    c = max(-1.0, min(1.0, sum(x * y for x, y in zip(a, b)) / (na * nb)))
    return math.degrees(math.acos(c))


class RuleEngine:
    def __init__(self, config: RuleConfig | None = None):
        self.cfg = config or RuleConfig()
        self._raw: deque[RigSample] = deque(maxlen=max(self.cfg.median_n, 3))
        self._heights: deque[tuple[float, float]] = deque()
        self._flow: deque[tuple[float, float]] = deque()
        self._baseline: list[tuple[float, float, float]] = []
        self._baseline_vec: tuple[float, float, float] | None = None
        self._recent_accel: deque[tuple[float, float, float]] = deque(maxlen=3)
        self._holds: dict[str, float] = {}
        self._state = RiskState.NORMAL
        self._since_desired: tuple[RiskState, float] | None = None
        self._calm_since: float | None = None

    def update(self, s: RigSample) -> Assessment:
        c = self.cfg
        reasons: list[str] = []

        # Water level: median of the last few distances, then height above the floor.
        self._raw.append(s)
        dist = _median([r.dist_cm for r in list(self._raw)[-c.median_n:]])
        height = max(0.0, c.mount_cm - dist)
        self._heights.append((s.t, height))
        while self._heights and s.t - self._heights[0][0] > c.rate_window_s:
            self._heights.popleft()
        pts = list(self._heights)
        slope = _slope(pts) if len(pts) >= 5 and pts[-1][0] - pts[0][0] >= c.rate_window_s / 2 else 0.0
        rising = slope >= c.min_rise_cm_per_s
        tta = (c.alert_cm - height) / slope if rising and height < c.alert_cm else None
        if height >= c.alert_cm:
            reasons.append(f"water at {height:.1f} cm, at or above the {c.alert_cm:.0f} cm alert line")
        elif rising:
            reasons.append(f"water rising {slope * 60:.1f} cm/min, about {tta:.0f} s to the alert line")

        # Flow (inflow)
        self._flow.append((s.t, s.flow))
        while self._flow and s.t - self._flow[0][0] > c.flow_window_s:
            self._flow.popleft()
        flow_avg = sum(v for _, v in self._flow) / len(self._flow)
        flow_on = flow_avg >= c.flow_active
        if flow_on:
            reasons.append(f"inflow detected (average flow {flow_avg:.1f})")

        # Soil
        soil = max(0.0, min(100.0, s.soil))
        soil_sat = soil >= c.soil_saturated_pct
        if soil_sat:
            reasons.append(f"soil saturated ({soil:.0f}%)")

        # Slope movement: angle from the resting tilt measured at the start.
        tilt: float | None = None
        self._recent_accel.append(s.accel)
        if self._baseline_vec is None:
            self._baseline.append(s.accel)
            if len(self._baseline) >= c.baseline_samples:
                n = len(self._baseline)
                self._baseline_vec = tuple(sum(a[i] for a in self._baseline) / n for i in range(3))  # type: ignore[assignment]
        else:
            n = len(self._recent_accel)
            cur = tuple(sum(a[i] for a in self._recent_accel) / n for i in range(3))
            tilt = _angle_deg(cur, self._baseline_vec)  # type: ignore[arg-type]
        tilt_on = self._sustained("tilt", tilt is not None and tilt >= c.tilt_watch_deg, s.t)
        tilt_evac = self._sustained("tilt_evac", tilt is not None and tilt >= c.tilt_evac_deg, s.t)
        breach = self._sustained("breach", height >= c.alert_cm, s.t)
        if tilt_on:
            reasons.append(f"slope tilted {tilt:.1f} degrees from rest")

        # Per-hazard assessment. Flood and landslide share the soil channel.
        flood_n = int(rising) + int(flow_on) + int(soil_sat)
        slide_n = int(tilt_on) + int(soil_sat)

        flood = self._grade(flood_n)
        if breach:
            flood = RiskState.EVACUATE
        slide = self._grade(slide_n)
        if tilt_evac:
            slide = RiskState.EVACUATE
        elif tilt_on and tilt is not None and tilt >= c.tilt_warn_deg and slide_n >= 2:
            slide = max(slide, RiskState.WARNING)

        desired = max(flood, slide)
        state = self._apply_dwell(desired, s.t)
        return Assessment(
            t=s.t, state=state, flood=flood, landslide=slide, height_cm=height,
            rise_cm_per_min=slope * 60, time_to_alert_s=tta, soil_pct=soil, flow_avg=flow_avg,
            tilt_deg=tilt, reasons=tuple(reasons),
        )

    def _sustained(self, key: str, condition: bool, t: float) -> bool:
        """True once `condition` has held continuously for sustain_s."""
        if not condition:
            self._holds.pop(key, None)
            return False
        since = self._holds.setdefault(key, t)
        return t - since >= self.cfg.sustain_s

    @staticmethod
    def _grade(n_channels: int) -> RiskState:
        # Two independent channels are required for WARNING.
        return RiskState.NORMAL if n_channels == 0 else RiskState.WATCH if n_channels == 1 else RiskState.WARNING

    def _apply_dwell(self, desired: RiskState, t: float) -> RiskState:
        c = self.cfg
        if desired > self._state:
            # WARNING must hold for the dwell; WATCH and a physical EVACUATE are immediate.
            need = c.warning_dwell_s if desired == RiskState.WARNING else 0.0
            if self._since_desired is None or self._since_desired[0] != desired:
                self._since_desired = (desired, t)
            if t - self._since_desired[1] >= need:
                self._state = desired
                self._since_desired = None
            else:
                # Still inside the dwell: show WATCH meanwhile, since a channel is already active.
                self._state = max(self._state, RiskState.WATCH)
            self._calm_since = None
        else:
            self._since_desired = None
            if desired < self._state:
                # Stepping down needs a longer calm period than stepping up.
                if self._calm_since is None:
                    self._calm_since = t
                if t - self._calm_since >= c.stand_down_s:
                    self._state = RiskState(self._state - 1)
                    self._calm_since = t
            else:
                self._calm_since = None
        return self._state


def evaluate_series(samples: list[RigSample], config: RuleConfig | None = None) -> list[Assessment]:
    engine = RuleEngine(config)
    return [engine.update(s) for s in samples]
