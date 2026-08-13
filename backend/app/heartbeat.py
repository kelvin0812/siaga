"""
Node heartbeat monitoring (build brief Section 6.3): flag a silent node
within two expected intervals. The expected interval isn't constant — the
node itself escalates from 60 s to 30 s sampling once its local anomaly
flag is set (Section 6.1), so "silent" has to be judged against whatever
cadence the node should currently be on, not a fixed number.
"""
from __future__ import annotations

from datetime import datetime

from backend.app.state_machine import RiskState

NORMAL_SAMPLE_INTERVAL_S = 60.0
ESCALATED_SAMPLE_INTERVAL_S = 30.0
SILENCE_INTERVAL_MULTIPLE = 2


def expected_interval_s(state: RiskState) -> float:
    return NORMAL_SAMPLE_INTERVAL_S if state == RiskState.NORMAL else ESCALATED_SAMPLE_INTERVAL_S


def is_node_silent(last_seen: datetime, now: datetime, state: RiskState) -> bool:
    if now < last_seen:
        return False
    elapsed_s = (now - last_seen).total_seconds()
    return elapsed_s > SILENCE_INTERVAL_MULTIPLE * expected_interval_s(state)
