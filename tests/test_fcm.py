import asyncio

import pytest

from backend.app.fcm import NullFCMClient, build_alert_copy
from backend.app.state_machine import RiskState


@pytest.mark.parametrize("state", [RiskState.WATCH, RiskState.WARNING, RiskState.EVACUATE])
def test_every_alertable_state_has_a_template(state):
    en, ms = build_alert_copy(state)
    assert en and ms


def test_normal_state_has_no_template_since_it_never_alerts():
    with pytest.raises(ValueError):
        build_alert_copy(RiskState.NORMAL)


def test_source_attribution_present_in_both_languages():
    en, ms = build_alert_copy(RiskState.EVACUATE)
    assert "NADMA" in en
    assert "NADMA" in ms


def test_evacuate_copy_is_distinct_from_warning_copy():
    warning_en, _ = build_alert_copy(RiskState.WARNING)
    evacuate_en, _ = build_alert_copy(RiskState.EVACUATE)
    assert warning_en != evacuate_en


def test_null_fcm_client_does_not_raise():
    client = NullFCMClient()
    asyncio.run(client.publish_to_cell("8865050927fffff", RiskState.WARNING, "en", "ms"))
