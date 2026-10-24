from backend.app.rules import RigSample, RuleConfig, evaluate_series
from backend.app.state_machine import RiskState

CFG = RuleConfig(mount_cm=40.0, alert_cm=30.0)
REST = (0.0, 0.0, 9.8)


def sample(t, dist=30.0, soil=10.0, flow=0.0, accel=REST, gyro=(0.0, 0.0, 0.0)):
    return RigSample(t=float(t), soil=soil, dist_cm=dist, flow=flow, accel=accel, gyro=gyro)


def tilted(deg):
    import math

    r = math.radians(deg)
    return (9.8 * math.sin(r), 0.0, 9.8 * math.cos(r))


def states(samples, cfg=CFG):
    return [a.state for a in evaluate_series(samples, cfg)]


def test_calm_rig_stays_normal():
    out = states([sample(t) for t in range(60)])
    assert set(out) == {RiskState.NORMAL}


def test_single_distance_spike_is_ignored():
    # One 39.6 cm reading among 30 cm ones, like the rig's real noise: the median filter removes it.
    samples = [sample(t, dist=39.6 if t == 20 else 30.0) for t in range(40)]
    assert set(states(samples)) == {RiskState.NORMAL}


def test_water_rising_to_alert_line_ends_in_evacuate_with_countdown():
    # Distance shrinks 0.2 cm/s: water rises from 10 cm to the 30 cm line.
    samples = [sample(t, dist=30.0 - 0.2 * t, flow=3.0) for t in range(110)]
    out = evaluate_series(samples, CFG)
    assert out[-1].state == RiskState.EVACUATE
    counting = [a for a in out if a.time_to_alert_s is not None]
    assert counting and counting[0].time_to_alert_s > counting[-1].time_to_alert_s


def test_water_rising_alone_is_only_watch_until_the_line():
    samples = [sample(t, dist=30.0 - 0.1 * t) for t in range(80)]  # rising, no flow, dry soil
    out = evaluate_series(samples, CFG)
    assert max(a.state for a in out) == RiskState.WATCH


def test_two_channels_needed_for_warning():
    # Saturated soil alone: WATCH. Add inflow and it becomes WARNING after the dwell.
    wet = [sample(t, soil=85.0) for t in range(30)]
    assert max(states(wet)) == RiskState.WATCH
    wet_and_flow = [sample(t, soil=85.0, flow=4.0) for t in range(30)]
    assert max(states(wet_and_flow)) == RiskState.WARNING


def test_warning_waits_for_dwell():
    samples = [sample(t, soil=85.0, flow=4.0) for t in range(30)]
    out = evaluate_series(samples, CFG)
    first_warning = next(a.t for a in out if a.state == RiskState.WARNING)
    first_watch = next(a.t for a in out if a.state == RiskState.WATCH)
    assert first_warning - first_watch >= CFG.warning_dwell_s - 1


def test_large_tilt_is_evacuate_for_landslide():
    samples = [sample(t) for t in range(15)] + [sample(t, accel=tilted(12.0)) for t in range(15, 30)]
    out = evaluate_series(samples, CFG)
    assert out[-1].landslide == RiskState.EVACUATE and out[-1].state == RiskState.EVACUATE


def test_moderate_tilt_alone_is_watch_but_with_wet_soil_is_warning():
    tilt = [sample(t) for t in range(15)] + [sample(t, accel=tilted(6.0)) for t in range(15, 40)]
    assert max(states(tilt)) == RiskState.WATCH
    tilt_wet = [sample(t, soil=90.0) for t in range(15)] + [sample(t, soil=90.0, accel=tilted(6.0)) for t in range(15, 40)]
    assert max(states(tilt_wet)) == RiskState.WARNING


def test_gyro_bump_alone_does_not_raise_state():
    samples = [sample(t, gyro=(80.0, 0.0, 0.0) if 20 <= t < 23 else (0.0, 0.0, 0.0)) for t in range(40)]
    assert set(states(samples)) == {RiskState.NORMAL}


def test_stands_down_slower_than_it_escalated():
    raised = [sample(t, soil=85.0, flow=4.0) for t in range(20)]
    calm = [sample(t) for t in range(20, 80)]
    out = evaluate_series(raised + calm, CFG)
    # Conditions clear at t=20 (the flow average takes a few more seconds to fall). The state must
    # still hold WARNING well into the stand-down period instead of dropping at once.
    at_t = {a.t: a.state for a in out}
    assert at_t[20 + CFG.stand_down_s - 5] == RiskState.WARNING
    assert at_t[79] < RiskState.WARNING


def test_hand_under_sensor_for_a_few_seconds_is_not_a_breach():
    # Distance reads as if the water were far above the line for 3 seconds. It must not evacuate.
    samples = [sample(t, dist=2.0 if 20 <= t < 23 else 30.0) for t in range(60)]
    assert max(states(samples)) < RiskState.EVACUATE


def test_short_table_bump_does_not_register_as_tilt():
    jolt = tilted(8.0)
    samples = [sample(t, accel=jolt if 20 <= t < 22 else REST) for t in range(15)] + [
        sample(t, accel=jolt if 20 <= t < 22 else REST) for t in range(15, 50)
    ]
    assert set(states(samples)) == {RiskState.NORMAL}


def test_near_miss_never_reaches_evacuate():
    # Water rises quickly with inflow, then stops well short of the 30 cm line and holds.
    samples = [sample(t, dist=30.0 - min(0.3 * t, 12.0), flow=3.0 if t < 40 else 0.0) for t in range(100)]
    assert max(states(samples)) < RiskState.EVACUATE
