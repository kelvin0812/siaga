from datetime import datetime, timedelta, timezone

import pytest

from backend.app.repository import ReadingRecord
from ml.build_dataset import label_series

T0 = datetime(2026, 1, 1, 0, 0, tzinfo=timezone.utc)


def reading(minutes: float, height_m: float) -> ReadingRecord:
    return ReadingRecord(
        node_id=1,
        gateway_id="test",
        received_at=T0 + timedelta(minutes=minutes),
        seq=0,
        level_mm=0,
        height_m=height_m,
        tilt_x=0,
        tilt_y=0,
        soil_pct=0,
        rain_tips=0,
        temp_c=0,
        rh_pct=0,
        vbat_cv=0,
        flags=0,
    )


class TestLabelSeries:
    def test_label_1_when_alert_crossed_within_horizon(self):
        readings = [
            reading(0, 1.0),
            reading(30, 1.2),
            reading(59, 2.5),  # crosses alert=2.0 within the 60-min horizon
            reading(90, 2.6),
        ]
        labels = label_series(readings, alert_m=2.0)
        assert labels[0] == 1

    def test_label_0_when_never_crossed_within_horizon(self):
        readings = [
            reading(0, 1.0),
            reading(30, 1.1),
            reading(59, 1.2),
            reading(120, 5.0),  # crosses alert eventually, but outside the 60-min horizon
        ]
        labels = label_series(readings, alert_m=2.0)
        assert labels[0] == 0

    def test_excluded_when_series_ends_before_horizon_closes(self):
        readings = [reading(0, 1.0), reading(30, 1.1)]  # series ends at t=30, horizon needs t=60
        labels = label_series(readings, alert_m=2.0)
        assert labels[0] is None
        assert labels[1] is None

    def test_excluded_when_horizon_window_is_a_pure_gap(self):
        # readings exist well before and well after the horizon window,
        # but nothing at all inside (0, 60] minutes after t=0.
        readings = [reading(0, 1.0), reading(200, 1.0), reading(260, 1.0)]
        labels = label_series(readings, alert_m=2.0)
        assert labels[0] is None

    def test_exact_threshold_value_counts_as_exceedance(self):
        readings = [reading(0, 1.0), reading(30, 2.0), reading(90, 2.0)]
        labels = label_series(readings, alert_m=2.0)
        assert labels[0] == 1

    def test_does_not_look_at_its_own_reading_only_future_ones(self):
        # the row itself is already at/above alert, but nothing AFTER it
        # within the horizon confirms that — must not count itself.
        readings = [reading(0, 5.0), reading(30, 1.0), reading(59, 1.0), reading(60, 1.0)]
        labels = label_series(readings, alert_m=2.0)
        assert labels[0] == 0

    def test_empty_series_returns_empty_list(self):
        assert label_series([], alert_m=2.0) == []

    def test_last_row_always_excluded_no_future_at_all(self):
        readings = [reading(0, 1.0), reading(30, 1.0), reading(65, 1.0)]
        labels = label_series(readings, alert_m=2.0)
        assert labels[-1] is None
