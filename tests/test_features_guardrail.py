from datetime import datetime, timedelta, timezone

import pytest

from backend.app.features import build_features
from backend.app.guardrail import (
    GuardrailThresholds,
    count_corroborating_channels,
    evaluate_guardrail,
)
from backend.app.repository import ReadingRecord
from backend.app.tier2 import HeuristicTier2Stub, LightGBMTier2Model
from shared.frame import FLAG_TIER1_ANOMALY

T0 = datetime(2026, 8, 13, 12, 0, 0, tzinfo=timezone.utc)


def reading(
    minutes_ago: float,
    height_m: float,
    *,
    soil_pct: int = 40,
    rain_tips: int = 0,
    tilt_x: int = 0,
    tilt_y: int = 0,
    flags: int = 0,
) -> ReadingRecord:
    return ReadingRecord(
        node_id=1,
        gateway_id="gw1",
        received_at=T0 - timedelta(minutes=minutes_ago),
        seq=0,
        level_mm=0,
        height_m=height_m,
        tilt_x=tilt_x,
        tilt_y=tilt_y,
        soil_pct=soil_pct,
        rain_tips=rain_tips,
        temp_c=28,
        rh_pct=70,
        vbat_cv=80,
        flags=flags,
    )


class TestBuildFeatures:
    def test_requires_at_least_one_reading(self):
        with pytest.raises(ValueError):
            build_features(T0, [])

    def test_lag_features_fall_back_to_current_height_with_no_history(self):
        readings = [reading(0, height_m=1.5)]
        features = build_features(T0, readings)
        assert features["level_lag_5m"] == pytest.approx(1.5)
        assert features["level_lag_60m"] == pytest.approx(1.5)

    def test_lag_features_pick_nearest_reading_at_or_before_target(self):
        readings = [
            reading(20, height_m=1.0),
            reading(10, height_m=1.5),
            reading(0, height_m=2.0),
        ]
        features = build_features(T0, readings)
        # 15 min ago: nearest at-or-before is the 20-min-ago reading (1.0)
        assert features["level_lag_15m"] == pytest.approx(1.0)
        # 5 min ago: nearest at-or-before is the 10-min-ago reading (1.5)
        assert features["level_lag_5m"] == pytest.approx(1.5)

    def test_first_derivative_positive_when_rising(self):
        readings = [reading(2, height_m=1.0), reading(0, height_m=1.2)]
        features = build_features(T0, readings)
        assert features["level_d1_m_per_min"] == pytest.approx(0.1)

    def test_first_derivative_zero_with_single_reading(self):
        features = build_features(T0, [reading(0, height_m=1.0)])
        assert features["level_d1_m_per_min"] == 0.0
        assert features["level_d2_m_per_min2"] == 0.0

    def test_second_derivative_reflects_accelerating_rise(self):
        readings = [
            reading(4, height_m=1.0),
            reading(2, height_m=1.1),  # d1 = 0.05 m/min
            reading(0, height_m=1.4),  # d1 = 0.15 m/min -> accelerating
        ]
        features = build_features(T0, readings)
        assert features["level_d2_m_per_min2"] > 0

    def test_cumulative_rain_sums_tips_within_window_only(self):
        readings = [
            reading(90, height_m=1.0, rain_tips=10),  # outside the 1h window
            reading(30, height_m=1.0, rain_tips=5),
            reading(0, height_m=1.0, rain_tips=3),
        ]
        features = build_features(T0, readings)
        assert features["rain_cum_1h_mm"] == pytest.approx((5 + 3) * 0.2)
        assert features["rain_cum_3h_mm"] == pytest.approx((10 + 5 + 3) * 0.2)

    def test_tilt_magnitude_is_euclidean_norm(self):
        features = build_features(T0, [reading(0, height_m=1.0, tilt_x=3, tilt_y=4)])
        assert features["tilt_magnitude_lsb"] == pytest.approx(5.0)

    def test_cyclical_encodings_bounded_and_consistent(self):
        features = build_features(T0, [reading(0, height_m=1.0)])
        for key in ("time_of_day_sin", "time_of_day_cos", "season_sin", "season_cos"):
            assert -1.0 <= features[key] <= 1.0
        assert features["time_of_day_sin"] ** 2 + features["time_of_day_cos"] ** 2 == pytest.approx(1.0)

    def test_noon_time_of_day_encoding_matches_expected_phase(self):
        noon = datetime(2026, 8, 13, 12, 0, 0, tzinfo=timezone.utc)
        features = build_features(noon, [reading(0, height_m=1.0)])
        assert features["time_of_day_sin"] == pytest.approx(0.0, abs=1e-9)
        assert features["time_of_day_cos"] == pytest.approx(-1.0, abs=1e-9)


class TestTier2Stub:
    def test_output_bounded_zero_to_one(self):
        stub = HeuristicTier2Stub()
        for rate in (0.0, 0.01, 0.05, 0.5, 5.0):
            p = stub.predict({"level_d1_m_per_min": rate, "antecedent_soil_moisture_pct": 50.0})
            assert 0.0 <= p <= 1.0

    def test_output_monotonic_in_rate_of_rise(self):
        stub = HeuristicTier2Stub()
        p_low = stub.predict({"level_d1_m_per_min": 0.01, "antecedent_soil_moisture_pct": 50.0})
        p_high = stub.predict({"level_d1_m_per_min": 1.0, "antecedent_soil_moisture_pct": 50.0})
        assert p_high > p_low

    def test_falling_water_gives_zero_rate_component(self):
        stub = HeuristicTier2Stub()
        p = stub.predict({"level_d1_m_per_min": -0.5, "antecedent_soil_moisture_pct": 90.0})
        assert p == pytest.approx(0.0)

    def test_lightgbm_model_not_yet_implemented(self):
        with pytest.raises(NotImplementedError):
            LightGBMTier2Model("nonexistent/path.txt")


class TestGuardrail:
    def test_no_channels_corroborate_a_quiet_reading(self):
        r = reading(0, height_m=1.0, soil_pct=30, rain_tips=0, tilt_x=0, tilt_y=0, flags=0)
        features = build_features(T0, [r])
        assert count_corroborating_channels(r, features) == 0

    def test_each_channel_counts_independently(self):
        r = reading(
            0,
            height_m=1.0,
            soil_pct=90,  # over default 85% threshold
            rain_tips=200,  # forces rain_cum_1h over 20mm threshold
            tilt_x=25,
            tilt_y=25,  # magnitude ~35.4 > 30 threshold
            flags=FLAG_TIER1_ANOMALY,
        )
        features = build_features(T0, [r])
        assert count_corroborating_channels(r, features) == 4

    def test_custom_thresholds_are_respected(self):
        r = reading(0, height_m=1.0, soil_pct=50)
        features = build_features(T0, [r])
        loose = GuardrailThresholds(soil_saturation_pct=40.0)
        assert count_corroborating_channels(r, features, loose) >= 1

    def test_physical_breach_true_when_height_meets_critical_threshold(self):
        r = reading(0, height_m=2.5)
        features = build_features(T0, [r])
        inputs = evaluate_guardrail(r, features, HeuristicTier2Stub(), critical_height_m=2.0)
        assert inputs.physical_breach is True

    def test_no_physical_breach_when_no_critical_height_configured(self):
        r = reading(0, height_m=100.0)  # absurdly high, but no threshold set
        features = build_features(T0, [r])
        inputs = evaluate_guardrail(r, features, HeuristicTier2Stub(), critical_height_m=None)
        assert inputs.physical_breach is False

    def test_guardrail_inputs_carry_tier2_probability_through(self):
        r = reading(2, height_m=1.0)
        r2 = reading(0, height_m=1.5)
        features = build_features(T0, [r, r2])
        inputs = evaluate_guardrail(r2, features, HeuristicTier2Stub())
        assert 0.0 <= inputs.tier2_p <= 1.0
