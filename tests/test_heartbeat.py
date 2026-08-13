from datetime import datetime, timedelta, timezone

import pytest

from backend.app.heartbeat import (
    ESCALATED_SAMPLE_INTERVAL_S,
    NORMAL_SAMPLE_INTERVAL_S,
    expected_interval_s,
    is_node_silent,
)
from backend.app.state_machine import RiskState

T0 = datetime(2026, 8, 13, 0, 0, 0, tzinfo=timezone.utc)


def test_expected_interval_is_60s_when_normal():
    assert expected_interval_s(RiskState.NORMAL) == NORMAL_SAMPLE_INTERVAL_S


@pytest.mark.parametrize("state", [RiskState.WATCH, RiskState.WARNING, RiskState.EVACUATE])
def test_expected_interval_is_30s_when_escalated(state):
    assert expected_interval_s(state) == ESCALATED_SAMPLE_INTERVAL_S


def test_not_silent_within_two_intervals_normal():
    last_seen = T0
    now = T0 + timedelta(seconds=2 * NORMAL_SAMPLE_INTERVAL_S - 1)
    assert is_node_silent(last_seen, now, RiskState.NORMAL) is False


def test_silent_past_two_intervals_normal():
    last_seen = T0
    now = T0 + timedelta(seconds=2 * NORMAL_SAMPLE_INTERVAL_S + 1)
    assert is_node_silent(last_seen, now, RiskState.NORMAL) is True


def test_silence_threshold_tightens_when_escalated():
    last_seen = T0
    now = T0 + timedelta(seconds=2 * ESCALATED_SAMPLE_INTERVAL_S + 1)
    # Would NOT be silent under the normal-state threshold...
    assert is_node_silent(last_seen, now, RiskState.NORMAL) is False
    # ...but IS silent once the node is expected to be sampling faster.
    assert is_node_silent(last_seen, now, RiskState.WATCH) is True


def test_future_last_seen_is_never_silent():
    assert is_node_silent(T0 + timedelta(seconds=100), T0, RiskState.NORMAL) is False
