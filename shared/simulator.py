"""
Synthetic telemetry generator (build brief Section 3.5 / 6.3): drives a
realistic rising-water hydrograph through the frame codec so the alerting
path can be exercised end to end before any hardware exists.

This is a *demo/testing* fixture, not the Tier 2 training data source —
Section 7 is explicit that only historical public records and dedicated
synthetic hydrographs train the model. This generator's job is to produce
plausible, internally-consistent UplinkFrame sequences (a monotonic-until-
recession water rise, correlated rainfall/soil/tilt) for driving the
backend pipeline and the app's demo mode.
"""
from __future__ import annotations

import math
import time
from dataclasses import dataclass
from typing import Iterator, NamedTuple

from shared.constants import TIP_RESOLUTION_MM as _TIP_RESOLUTION_MM
from shared.frame import FLAG_LOW_BATTERY, FLAG_TIER1_ANOMALY, UplinkFrame


@dataclass(frozen=True, slots=True)
class HydrographConfig:
    datum_mm: int = 3000
    """Transducer height above the channel bed; level_mm = datum_mm - depth_mm."""

    baseline_depth_mm: int = 200
    """Water depth above bed in normal conditions."""

    peak_depth_mm: int = 2600
    """Water depth above bed at the flood peak."""

    rain_peak_mm_per_h: float = 45.0
    """Peak rainfall intensity driving the rise, roughly a heavy tropical downpour."""

    rise_start_s: float = 0.0
    time_to_peak_s: float = 3600.0
    """Time from rise onset to peak — 1 hour models a rapid-onset flash flood."""

    recession_tau_s: float = 5400.0
    """Exponential decay time constant for the falling limb."""

    total_duration_s: float = 3 * 3600.0
    sample_interval_s: float = 60.0
    """Matches the node's normal 60 s sampling cycle (Section 6.1)."""

    anomaly_rate_mm_per_min: float = 30.0
    """
    Rate-of-rise that would trip the node's Tier 1 flag. This stands in for
    the real EWMA/z-score/autoencoder logic (Section 6.1) — good enough to
    drive the state machine realistically without reimplementing firmware
    logic in the simulator.
    """

    start_vbat_cv: int = 80
    discharge_cv_per_h: float = 0.4
    low_battery_cv: int = 20

    ambient_temp_c: float = 27.0
    ambient_rh_pct: float = 75.0

    soil_baseline_pct: float = 35.0
    soil_saturation_gain_pct_per_mm: float = 0.08


class SimulatedReading(NamedTuple):
    t_s: float
    depth_mm: float
    """Ground-truth water depth above the channel bed — not on the wire; for
    test assertions and demo dashboards that want to plot against reality."""
    frame: UplinkFrame


def _smoothstep(x: float) -> float:
    x = min(1.0, max(0.0, x))
    return x * x * (3.0 - 2.0 * x)


def _depth_shape(t: float, cfg: HydrographConfig) -> float:
    """0..1 envelope: smoothstep rise to the peak, exponential recession after."""
    t_peak = cfg.rise_start_s + cfg.time_to_peak_s
    if t <= cfg.rise_start_s:
        return 0.0
    if t <= t_peak:
        return _smoothstep((t - cfg.rise_start_s) / cfg.time_to_peak_s)
    return math.exp(-(t - t_peak) / cfg.recession_tau_s)


def _rain_intensity_mm_per_h(t: float, cfg: HydrographConfig) -> float:
    """Rainfall leads the water peak — it's the cause, not the effect."""
    lead_s = cfg.time_to_peak_s * 0.3
    shifted_cfg = HydrographConfig(
        rise_start_s=cfg.rise_start_s,
        time_to_peak_s=max(cfg.time_to_peak_s - lead_s, 1.0),
        recession_tau_s=cfg.recession_tau_s * 0.6,
    )
    return cfg.rain_peak_mm_per_h * _depth_shape(t + lead_s, shifted_cfg)


class HydrographGenerator:
    """Deterministic per-node hydrograph -> UplinkFrame sequence."""

    def __init__(self, node_id: int, config: HydrographConfig | None = None):
        self.node_id = node_id
        self.cfg = config or HydrographConfig()

    def readings(self) -> Iterator[SimulatedReading]:
        cfg = self.cfg
        seq = 0
        cumulative_rain_mm = 0.0
        tip_residual_mm = 0.0
        prev_depth_mm: float | None = None
        t = 0.0
        while t <= cfg.total_duration_s:
            depth_mm = cfg.baseline_depth_mm + (
                cfg.peak_depth_mm - cfg.baseline_depth_mm
            ) * _depth_shape(t, cfg)

            rain_intensity = _rain_intensity_mm_per_h(t, cfg)
            interval_rain_mm = rain_intensity * (cfg.sample_interval_s / 3600.0)
            cumulative_rain_mm += interval_rain_mm
            tip_residual_mm += interval_rain_mm
            rain_tips = int(tip_residual_mm // _TIP_RESOLUTION_MM)
            tip_residual_mm -= rain_tips * _TIP_RESOLUTION_MM
            rain_tips = min(rain_tips, 255)

            soil_pct = min(
                100.0,
                cfg.soil_baseline_pct
                + cfg.soil_saturation_gain_pct_per_mm * cumulative_rain_mm,
            )

            tilt_drift = (soil_pct - cfg.soil_baseline_pct) * 0.08
            tilt_x = int(max(-128, min(127, round(tilt_drift))))
            tilt_y = int(max(-128, min(127, round(tilt_drift * 0.4))))

            diurnal = (t / 3600.0) % 24.0
            temp_c = cfg.ambient_temp_c - 3.0 * math.sin(diurnal / 24.0 * 2 * math.pi)
            rh_pct = cfg.ambient_rh_pct + min(20.0, rain_intensity * 0.3)
            rh_pct = max(0.0, min(100.0, rh_pct))

            vbat_cv = max(
                0, round(cfg.start_vbat_cv - cfg.discharge_cv_per_h * (t / 3600.0))
            )

            rate_mm_per_min = 0.0
            if prev_depth_mm is not None and cfg.sample_interval_s > 0:
                rate_mm_per_min = (
                    (depth_mm - prev_depth_mm) / cfg.sample_interval_s * 60.0
                )
            prev_depth_mm = depth_mm

            flags = 0
            if rate_mm_per_min >= cfg.anomaly_rate_mm_per_min:
                flags |= FLAG_TIER1_ANOMALY
            if vbat_cv < cfg.low_battery_cv:
                flags |= FLAG_LOW_BATTERY

            level_mm = int(max(0, min(65535, round(cfg.datum_mm - depth_mm))))

            frame = UplinkFrame(
                node_id=self.node_id,
                seq=seq % 256,
                level_mm=level_mm,
                tilt_x=tilt_x,
                tilt_y=tilt_y,
                soil_pct=int(round(max(0.0, min(100.0, soil_pct)))),
                rain_tips=rain_tips,
                temp_c=int(max(-128, min(127, round(temp_c)))),
                rh_pct=int(round(rh_pct)),
                vbat_cv=vbat_cv,
                flags=flags,
            )
            yield SimulatedReading(t_s=t, depth_mm=depth_mm, frame=frame)

            seq += 1
            t += cfg.sample_interval_s

    def replay_realtime(self, speed: float = 1.0) -> Iterator[SimulatedReading]:
        """
        Yield readings paced to wall-clock time, compressed by `speed`
        (speed=60 plays a 3-hour hydrograph in 3 minutes). For booth demos
        and for feeding a live MQTT publisher once the backend exists.
        """
        if speed <= 0:
            raise ValueError("speed must be > 0")
        last_t = 0.0
        for reading in self.readings():
            wait_s = (reading.t_s - last_t) / speed
            if wait_s > 0:
                time.sleep(wait_s)
            last_t = reading.t_s
            yield reading
