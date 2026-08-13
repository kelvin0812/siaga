"""
Risk state machine (build brief Section 5.4). An explicit class rather than
scattered if-statements, so every transition is reconstructable from its
logged reason.

Escalation and de-escalation are evaluated independently and asymmetrically:
escalation commits as soon as a state's entry condition has held
continuously for that state's required dwell; de-escalation requires the
condition to have dropped below the current state for a *longer* dwell,
and steps down exactly one level per satisfied dwell period rather than
jumping straight to the newly-desired state. That's a deliberate choice —
an EVACUATE that quietly senses one calm reading should not silently
reopen a road; each step down re-arms its own dwell timer. The brief
gives an exact escalation dwell only for WARNING (10 min); the
de-escalation dwell (30 min, DEESCALATION_DWELL_S below) and per-step
behavior are this implementation's judgment call, not a spec value —
flagged in docs/nexus-log.md for the team to confirm.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import IntEnum


class RiskState(IntEnum):
    NORMAL = 0
    WATCH = 1
    WARNING = 2
    EVACUATE = 3


# Seconds the entry condition must hold continuously before escalating INTO
# that state. Section 5.4: WARNING is explicit at 10 min; WATCH and
# EVACUATE are immediate per the brief's "quick to warn" framing.
ESCALATION_DWELL_S: dict[RiskState, float] = {
    RiskState.WATCH: 0.0,
    RiskState.WARNING: 600.0,
    RiskState.EVACUATE: 0.0,
}

# Seconds the entry condition must have been absent before stepping DOWN
# one level. Must exceed the largest escalation dwell (600s) per Section
# 5.4's "slow to stand down." Not spec-given — see module docstring.
DEESCALATION_DWELL_S: float = 1800.0

MIN_CORROBORATING_CHANNELS = 2


@dataclass(frozen=True, slots=True)
class GuardrailInputs:
    tier1_anomaly: bool
    tier2_p: float
    corroborating_channels: int
    physical_breach: bool


@dataclass(frozen=True, slots=True)
class Transition:
    node_id: int
    from_state: RiskState
    to_state: RiskState
    occurred_at: datetime
    reason: dict


@dataclass
class _Pending:
    target: RiskState
    direction: str  # "up" | "down"
    since: datetime


def desired_state(inputs: GuardrailInputs) -> RiskState:
    """The state whose entry condition is satisfied right now, independent
    of dwell — the target the dwell timers below are racing toward."""
    corroborated = inputs.corroborating_channels >= MIN_CORROBORATING_CHANNELS
    if inputs.physical_breach or (inputs.tier2_p >= 0.85 and corroborated):
        return RiskState.EVACUATE
    if corroborated or inputs.tier2_p >= 0.60:
        return RiskState.WARNING
    if inputs.tier1_anomaly or inputs.tier2_p >= 0.30:
        return RiskState.WATCH
    return RiskState.NORMAL


class StateMachine:
    def __init__(self) -> None:
        self._current: dict[int, RiskState] = {}
        self._pending: dict[int, _Pending] = {}

    def get_state(self, node_id: int) -> RiskState:
        return self._current.get(node_id, RiskState.NORMAL)

    def evaluate(
        self, node_id: int, now: datetime, inputs: GuardrailInputs
    ) -> Transition | None:
        current = self.get_state(node_id)
        desired = desired_state(inputs)

        if desired == current:
            self._pending.pop(node_id, None)
            return None

        direction = "up" if desired > current else "down"
        pending = self._pending.get(node_id)
        if pending is None or pending.target != desired or pending.direction != direction:
            pending = _Pending(target=desired, direction=direction, since=now)
            self._pending[node_id] = pending

        elapsed_s = (now - pending.since).total_seconds()

        if direction == "up":
            required_dwell_s = ESCALATION_DWELL_S.get(desired, 0.0)
            if elapsed_s < required_dwell_s:
                return None
            new_state = desired
        else:
            if elapsed_s < DEESCALATION_DWELL_S:
                return None
            new_state = RiskState(current - 1)

        del self._pending[node_id]
        self._current[node_id] = new_state
        reason = {
            "tier1_anomaly": inputs.tier1_anomaly,
            "tier2_p": inputs.tier2_p,
            "corroborating_channels": inputs.corroborating_channels,
            "physical_breach": inputs.physical_breach,
            "desired_state": desired.name,
            "dwell_elapsed_s": elapsed_s,
        }
        return Transition(
            node_id=node_id,
            from_state=current,
            to_state=new_state,
            occurred_at=now,
            reason=reason,
        )
