import logging

import pytest

from backend.app.fcm import NullFCMClient
from backend.app.ingest import _handle_status, _handle_telemetry
from backend.app.repository import InMemoryRepository
from backend.app.state_machine import StateMachine
from backend.app.tier2 import HeuristicTier2Stub


def telemetry_payload(**overrides) -> dict:
    defaults = dict(
        gateway_id="gw1",
        node_id=1,
        received_at="2026-08-13T00:00:00+00:00",
        rssi=-82.0,
        snr=8.5,
        seq=0,
        level_mm=2800,
        tilt_x=0,
        tilt_y=0,
        soil_pct=30,
        rain_tips=0,
        temp_c=28,
        rh_pct=70,
        vbat_cv=80,
        flags=0,
    )
    defaults.update(overrides)
    return defaults


@pytest.mark.asyncio
async def test_handle_telemetry_stores_reading_for_known_node():
    repo = InMemoryRepository()
    await repo.upsert_node(1, "Node 1", lat=4.85, lon=100.74)
    sm = StateMachine()

    await _handle_telemetry(telemetry_payload(), repo, sm, HeuristicTier2Stub(), NullFCMClient())

    stored = await repo.get_last_reading(1)
    assert stored is not None
    assert stored.gateway_id == "gw1"


@pytest.mark.asyncio
async def test_handle_telemetry_drops_unknown_node_without_raising(caplog):
    repo = InMemoryRepository()  # no node registered
    sm = StateMachine()

    with caplog.at_level(logging.WARNING, logger="siaga.ingest"):
        await _handle_telemetry(
            telemetry_payload(node_id=99), repo, sm, HeuristicTier2Stub(), NullFCMClient()
        )

    assert await repo.get_last_reading(99) is None
    assert any("unknown node_id" in r.message for r in caplog.records)


@pytest.mark.asyncio
async def test_handle_status_does_not_raise():
    await _handle_status({"gateway_id": "gw1", "uptime": 100, "buffered_count": 0, "rssi": -70})
