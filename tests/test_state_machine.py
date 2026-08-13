from datetime import datetime, timedelta, timezone

import pytest

from backend.app.state_machine import (
    DEESCALATION_DWELL_S,
    ESCALATION_DWELL_S,
    GuardrailInputs,
    RiskState,
    StateMachine,
    desired_state,
)

T0 = datetime(2026, 8, 13, 0, 0, 0, tzinfo=timezone.utc)


def calm() -> GuardrailInputs:
    return GuardrailInputs(
        tier1_anomaly=False, tier2_p=0.0, corroborating_channels=0, physical_breach=False
    )


def one_channel_anomaly() -> GuardrailInputs:
    return GuardrailInputs(
        tier1_anomaly=True, tier2_p=0.0, corroborating_channels=1, physical_breach=False
    )


def two_channel_corroboration() -> GuardrailInputs:
    return GuardrailInputs(
        tier1_anomaly=True, tier2_p=0.0, corroborating_channels=2, physical_breach=False
    )


def high_confidence_corroborated() -> GuardrailInputs:
    return GuardrailInputs(
        tier1_anomaly=True, tier2_p=0.90, corroborating_channels=2, physical_breach=False
    )


def physical_breach_only() -> GuardrailInputs:
    return GuardrailInputs(
        tier1_anomaly=False, tier2_p=0.0, corroborating_channels=0, physical_breach=True
    )


class TestDesiredState:
    def test_normal_when_nothing_anomalous(self):
        assert desired_state(calm()) == RiskState.NORMAL

    def test_watch_on_single_channel_tier1_anomaly(self):
        assert desired_state(one_channel_anomaly()) == RiskState.WATCH

    def test_watch_on_tier2_probability_threshold(self):
        inputs = GuardrailInputs(
            tier1_anomaly=False, tier2_p=0.30, corroborating_channels=0, physical_breach=False
        )
        assert desired_state(inputs) == RiskState.WATCH

    def test_warning_on_two_channel_corroboration(self):
        assert desired_state(two_channel_corroboration()) == RiskState.WARNING

    def test_warning_on_tier2_probability_threshold_alone(self):
        inputs = GuardrailInputs(
            tier1_anomaly=False, tier2_p=0.60, corroborating_channels=0, physical_breach=False
        )
        assert desired_state(inputs) == RiskState.WARNING

    def test_evacuate_requires_both_high_probability_and_corroboration(self):
        under_corroborated = GuardrailInputs(
            tier1_anomaly=True, tier2_p=0.90, corroborating_channels=1, physical_breach=False
        )
        assert desired_state(under_corroborated) == RiskState.WARNING
        assert desired_state(high_confidence_corroborated()) == RiskState.EVACUATE

    def test_evacuate_on_physical_breach_alone_no_corroboration_needed(self):
        assert desired_state(physical_breach_only()) == RiskState.EVACUATE


class TestEscalation:
    def test_watch_escalates_immediately_no_dwell(self):
        sm = StateMachine()
        t = sm.evaluate(1, T0, one_channel_anomaly())
        assert t is not None
        assert t.from_state == RiskState.NORMAL
        assert t.to_state == RiskState.WATCH
        assert sm.get_state(1) == RiskState.WATCH

    def test_warning_does_not_escalate_before_dwell_elapses(self):
        sm = StateMachine()
        sm.evaluate(1, T0, two_channel_corroboration())  # NORMAL -> WATCH? no: desired is WARNING directly
        just_before = T0 + timedelta(seconds=ESCALATION_DWELL_S[RiskState.WARNING] - 1)
        t = sm.evaluate(1, just_before, two_channel_corroboration())
        assert t is None
        assert sm.get_state(1) == RiskState.NORMAL

    def test_warning_escalates_once_dwell_elapses(self):
        sm = StateMachine()
        sm.evaluate(1, T0, two_channel_corroboration())
        after = T0 + timedelta(seconds=ESCALATION_DWELL_S[RiskState.WARNING])
        t = sm.evaluate(1, after, two_channel_corroboration())
        assert t is not None
        assert t.to_state == RiskState.WARNING
        assert sm.get_state(1) == RiskState.WARNING

    def test_evacuate_via_physical_breach_is_immediate_even_from_normal(self):
        sm = StateMachine()
        t = sm.evaluate(1, T0, physical_breach_only())
        assert t is not None
        assert t.from_state == RiskState.NORMAL
        assert t.to_state == RiskState.EVACUATE

    def test_flapping_condition_resets_the_dwell_timer(self):
        sm = StateMachine()
        sm.evaluate(1, T0, two_channel_corroboration())
        # condition drops away before dwell completes
        sm.evaluate(1, T0 + timedelta(seconds=300), calm())
        # condition returns — dwell must restart from here, not from T0
        sm.evaluate(1, T0 + timedelta(seconds=310), two_channel_corroboration())
        almost_full_dwell_from_original_start = T0 + timedelta(seconds=610)
        t = sm.evaluate(1, almost_full_dwell_from_original_start, two_channel_corroboration())
        assert t is None, "dwell should have restarted at t=310s, not accumulated from T0"

    def test_transition_reason_captures_causal_inputs(self):
        sm = StateMachine()
        t = sm.evaluate(1, T0, one_channel_anomaly())
        assert t.reason["tier1_anomaly"] is True
        assert t.reason["corroborating_channels"] == 1
        assert t.reason["desired_state"] == "WATCH"


class TestDeescalation:
    def _escalate_to_warning(self, sm: StateMachine, node_id: int = 1) -> datetime:
        sm.evaluate(node_id, T0, two_channel_corroboration())
        t_escalated = T0 + timedelta(seconds=ESCALATION_DWELL_S[RiskState.WARNING])
        transition = sm.evaluate(node_id, t_escalated, two_channel_corroboration())
        assert transition.to_state == RiskState.WARNING
        return t_escalated

    def test_does_not_deescalate_before_its_longer_dwell_elapses(self):
        sm = StateMachine()
        t_warning = self._escalate_to_warning(sm)
        just_before = t_warning + timedelta(seconds=DEESCALATION_DWELL_S - 1)
        t = sm.evaluate(1, just_before, calm())
        assert t is None
        assert sm.get_state(1) == RiskState.WARNING

    def test_deescalates_one_level_after_its_dwell_elapses(self):
        sm = StateMachine()
        t_warning = self._escalate_to_warning(sm)
        sm.evaluate(1, t_warning, calm())  # arms the de-escalation dwell timer
        after = t_warning + timedelta(seconds=DEESCALATION_DWELL_S)
        t = sm.evaluate(1, after, calm())
        assert t is not None
        assert t.from_state == RiskState.WARNING
        assert t.to_state == RiskState.WATCH  # one level, not straight to NORMAL

    def test_deescalation_dwell_exceeds_every_escalation_dwell(self):
        assert DEESCALATION_DWELL_S > max(ESCALATION_DWELL_S.values())

    def test_full_stand_down_requires_dwell_at_each_step(self):
        sm = StateMachine()
        t_warning = self._escalate_to_warning(sm)
        sm.evaluate(1, t_warning, calm())  # arms the de-escalation dwell timer

        t1 = t_warning + timedelta(seconds=DEESCALATION_DWELL_S)
        transition1 = sm.evaluate(1, t1, calm())
        assert transition1.to_state == RiskState.WATCH

        # immediately after stepping down, another step must NOT happen yet
        transition_too_soon = sm.evaluate(1, t1 + timedelta(seconds=1), calm())
        assert transition_too_soon is None
        assert sm.get_state(1) == RiskState.WATCH

        # arm the second dwell timer, then let it elapse
        sm.evaluate(1, t1 + timedelta(seconds=1), calm())
        t2 = t1 + timedelta(seconds=1 + DEESCALATION_DWELL_S)
        transition2 = sm.evaluate(1, t2, calm())
        assert transition2.to_state == RiskState.NORMAL


class TestMultiNodeIsolation:
    def test_nodes_track_independent_state(self):
        sm = StateMachine()
        sm.evaluate(1, T0, one_channel_anomaly())
        assert sm.get_state(1) == RiskState.WATCH
        assert sm.get_state(2) == RiskState.NORMAL
