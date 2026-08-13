from datetime import datetime, timedelta, timezone

import pytest

from backend.app.fcm import NullFCMClient
from backend.app.pipeline import decode_reading, frame_to_fields, process_reading
from backend.app.repository import InMemoryRepository
from backend.app.state_machine import RiskState, StateMachine
from backend.app.tier2 import HeuristicTier2Stub
from shared.simulator import HydrographConfig, HydrographGenerator

T0 = datetime(2026, 8, 13, 0, 0, 0, tzinfo=timezone.utc)


class RecordingFCMClient:
    def __init__(self) -> None:
        self.published: list[tuple[str, RiskState, str, str]] = []

    async def publish_to_cell(self, cell_id, state, message_en, message_ms) -> None:
        self.published.append((cell_id, state, message_en, message_ms))


@pytest.mark.asyncio
async def test_quiet_reading_stores_data_but_causes_no_transition():
    repo = InMemoryRepository()
    await repo.upsert_node(1, "Node 1", lat=4.85, lon=100.74, datum_mm=3000)
    node = await repo.get_node(1)
    sm = StateMachine()
    fcm = RecordingFCMClient()

    reading = decode_reading(
        node, "gw1", T0, {"seq": 0, "level_mm": 2800, "tilt_x": 0, "tilt_y": 0, "soil_pct": 30,
                          "rain_tips": 0, "temp_c": 28, "rh_pct": 70, "vbat_cv": 80, "flags": 0},
        rssi=-80.0, snr=9.0,
    )
    await process_reading(repo, sm, HeuristicTier2Stub(), fcm, node, reading)

    assert sm.get_state(1) == RiskState.NORMAL
    assert fcm.published == []
    stored = await repo.get_last_reading(1)
    assert stored.height_m == pytest.approx(0.2)  # datum 3000mm - level 2800mm


@pytest.mark.asyncio
async def test_physical_breach_triggers_immediate_evacuate_and_dispatches_alert():
    repo = InMemoryRepository()
    await repo.upsert_node(1, "Node 1", lat=4.85, lon=100.74, datum_mm=3000, critical_height_m=2.5)
    node = await repo.get_node(1)
    sm = StateMachine()
    fcm = RecordingFCMClient()

    # level_mm=400 -> height = (3000-400)/1000 = 2.6m, over the 2.5m critical threshold
    reading = decode_reading(
        node, "gw1", T0, {"seq": 0, "level_mm": 400, "tilt_x": 0, "tilt_y": 0, "soil_pct": 30,
                          "rain_tips": 0, "temp_c": 28, "rh_pct": 70, "vbat_cv": 80, "flags": 0},
        rssi=-80.0, snr=9.0,
    )
    await process_reading(repo, sm, HeuristicTier2Stub(), fcm, node, reading)

    assert sm.get_state(1) == RiskState.EVACUATE
    assert len(fcm.published) > 0
    cell_id, state, message_en, message_ms = fcm.published[0]
    assert state == RiskState.EVACUATE
    assert "NADMA" in message_en

    hazards = await repo.list_active_hazards()
    assert len(hazards) == 1
    assert hazards[0].state == "EVACUATE"


@pytest.mark.asyncio
async def test_full_synthetic_hydrograph_drives_pipeline_to_alertable_state():
    """
    End-to-end exercise of Section 3.5's promise: the synthetic generator
    alone, with no hardware, must be able to drive the alerting path.
    """
    repo = InMemoryRepository()
    await repo.upsert_node(7, "Node 7", lat=4.85, lon=100.74, datum_mm=3000)
    node = await repo.get_node(7)
    sm = StateMachine()
    fcm = RecordingFCMClient()
    tier2 = HeuristicTier2Stub()

    cfg = HydrographConfig(
        baseline_depth_mm=200,
        peak_depth_mm=2600,
        time_to_peak_s=1800.0,
        recession_tau_s=3600.0,
        total_duration_s=3 * 3600.0,
        sample_interval_s=60.0,
        anomaly_rate_mm_per_min=20.0,
    )
    gen = HydrographGenerator(node_id=7, config=cfg)

    reached_alertable = False
    for sim_reading in gen.readings():
        received_at = T0 + timedelta(seconds=sim_reading.t_s)
        reading = decode_reading(
            node, "gw1", received_at, frame_to_fields(sim_reading.frame), rssi=-80.0, snr=9.0
        )
        await process_reading(repo, sm, tier2, fcm, node, reading)
        if sm.get_state(7) in (RiskState.WARNING, RiskState.EVACUATE):
            reached_alertable = True
            break

    assert reached_alertable, "synthetic rising hydrograph never escalated the state machine"
    assert len(fcm.published) > 0

    transitions_logged = repo._transitions  # white-box: confirm the log exists and is populated
    assert len(transitions_logged) > 0
    assert all("tier2_p" in t["reason"] for t in transitions_logged)
