import pytest

from shared.frame import FLAG_LOW_BATTERY, FLAG_TIER1_ANOMALY
from shared.simulator import HydrographConfig, HydrographGenerator


def fast_config(**overrides) -> HydrographConfig:
    defaults = dict(
        rise_start_s=0.0,
        time_to_peak_s=600.0,
        recession_tau_s=900.0,
        total_duration_s=3600.0,
        sample_interval_s=60.0,
    )
    defaults.update(overrides)
    return HydrographConfig(**defaults)


def test_depth_rises_monotonically_to_peak_then_recedes():
    cfg = fast_config()
    gen = HydrographGenerator(node_id=1, config=cfg)
    readings = list(gen.readings())

    depths = [r.depth_mm for r in readings]
    peak_index = depths.index(max(depths))

    # Rise limb: non-decreasing up to the peak.
    for a, b in zip(depths[:peak_index], depths[1 : peak_index + 1]):
        assert b >= a - 1e-9

    # Recession limb: non-increasing after the peak.
    for a, b in zip(depths[peak_index:], depths[peak_index + 1 :]):
        assert b <= a + 1e-9

    assert depths[peak_index] == pytest.approx(cfg.peak_depth_mm, rel=0.05)
    assert depths[0] == pytest.approx(cfg.baseline_depth_mm, abs=1.0)


def test_level_mm_is_inverse_of_depth_and_stays_in_range():
    cfg = fast_config()
    gen = HydrographGenerator(node_id=1, config=cfg)
    for reading in gen.readings():
        assert 0 <= reading.frame.level_mm <= 65535
        expected_level = cfg.datum_mm - reading.depth_mm
        assert reading.frame.level_mm == pytest.approx(expected_level, abs=1.0)
    # deepest water -> smallest level_mm, confirming the inversion held end to end
    readings = list(gen.readings())
    deepest = max(readings, key=lambda r: r.depth_mm)
    shallowest = min(readings, key=lambda r: r.depth_mm)
    assert deepest.frame.level_mm < shallowest.frame.level_mm


def test_tier1_anomaly_flag_set_during_rapid_rise_only():
    cfg = fast_config(anomaly_rate_mm_per_min=1.0)  # low bar, easy to trip on the rise
    gen = HydrographGenerator(node_id=1, config=cfg)
    readings = list(gen.readings())
    depths = [r.depth_mm for r in readings]
    peak_index = depths.index(max(depths))

    rising_flags = [r.frame.tier1_anomaly for r in readings[1:peak_index]]
    assert any(rising_flags), "expected at least one anomaly flag during the rise"

    # Every anomaly-flagged frame must fall on the read where depth actually
    # increased — never during the flat pre-rise baseline.
    for i, r in enumerate(readings):
        if r.frame.flags & FLAG_TIER1_ANOMALY:
            assert i > 0
            assert readings[i].depth_mm > readings[i - 1].depth_mm


def test_soil_pct_and_rain_tips_stay_in_valid_ranges():
    gen = HydrographGenerator(node_id=1, config=fast_config())
    for reading in gen.readings():
        assert 0 <= reading.frame.soil_pct <= 100
        assert 0 <= reading.frame.rain_tips <= 255


def test_low_battery_flag_trips_below_threshold():
    cfg = fast_config(
        total_duration_s=3600.0 * 200,  # long enough to discharge past threshold
        start_vbat_cv=25,
        discharge_cv_per_h=1.0,
        low_battery_cv=20,
    )
    gen = HydrographGenerator(node_id=7, config=cfg)
    readings = list(gen.readings())
    assert not readings[0].frame.low_battery
    assert any(r.frame.low_battery for r in readings)
    for r in readings:
        if r.frame.low_battery:
            assert (r.frame.flags & FLAG_LOW_BATTERY) != 0


def test_seq_increments_and_wraps_at_256():
    cfg = fast_config(total_duration_s=60.0 * 300, sample_interval_s=60.0)
    gen = HydrographGenerator(node_id=3, config=cfg)
    readings = list(gen.readings())
    assert len(readings) > 256
    seqs = [r.frame.seq for r in readings]
    assert seqs[0] == 0
    assert seqs[255] == 255
    assert seqs[256] == 0


def test_node_id_is_stable_across_all_frames():
    gen = HydrographGenerator(node_id=42, config=fast_config())
    for reading in gen.readings():
        assert reading.frame.node_id == 42


def test_replay_realtime_rejects_nonpositive_speed():
    gen = HydrographGenerator(node_id=1, config=fast_config())
    with pytest.raises(ValueError):
        next(gen.replay_realtime(speed=0))
