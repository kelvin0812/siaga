"""
Ingest-to-alert orchestration. This is the one place that wires together
everything upstream of the REST API: decode -> store -> feature build ->
guardrail -> state machine -> (on escalation into WARNING/EVACUATE only,
per Section 5.4) geofence -> hazard record -> FCM dispatch.

Kept as plain functions over the Repository/StateMachine/Tier2Model/
FCMClient interfaces rather than a class hierarchy — there's exactly one
pipeline, so an abstraction for swapping it out would be speculative.
"""
from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

from backend.app.config import settings
from backend.app.fcm import FCMClient, build_alert_copy
from backend.app.features import build_features
from backend.app.geofence import cells_around_point
from backend.app.guardrail import evaluate_guardrail
from backend.app.repository import NodeRecord, ReadingRecord, Repository
from backend.app.state_machine import RiskState, StateMachine
from backend.app.tier2 import Tier2Model
from shared.frame import UplinkFrame, level_mm_to_height_above_datum

logger = logging.getLogger("siaga.pipeline")

# Covers the widest window any feature needs (rain_cum_24h); lag windows
# top out at 60 min.
FEATURE_HISTORY_WINDOW = timedelta(hours=24)

ALERTABLE_STATES = frozenset({RiskState.WARNING, RiskState.EVACUATE})


def decode_reading(
    node: NodeRecord,
    gateway_id: str,
    received_at: datetime,
    frame_fields: dict,
    rssi: float | None,
    snr: float | None,
) -> ReadingRecord:
    """
    frame_fields carries the JSON-decoded uplink fields as published on
    siaga/v1/telemetry/<gateway_id> (Section 5.2) — the gateway already
    decoded the 12-byte frame; the backend only applies the level_mm ->
    height_m inversion, once, here.
    """
    height_m = level_mm_to_height_above_datum(frame_fields["level_mm"], node.datum_mm)
    return ReadingRecord(
        node_id=node.id,
        gateway_id=gateway_id,
        received_at=received_at,
        seq=frame_fields["seq"],
        level_mm=frame_fields["level_mm"],
        height_m=height_m,
        tilt_x=frame_fields["tilt_x"],
        tilt_y=frame_fields["tilt_y"],
        soil_pct=frame_fields["soil_pct"],
        rain_tips=frame_fields["rain_tips"],
        temp_c=frame_fields["temp_c"],
        rh_pct=frame_fields["rh_pct"],
        vbat_cv=frame_fields["vbat_cv"],
        flags=frame_fields["flags"],
        rssi=rssi,
        snr=snr,
    )


async def process_reading(
    repo: Repository,
    state_machine: StateMachine,
    tier2_model: Tier2Model,
    fcm_client: FCMClient,
    node: NodeRecord,
    reading: ReadingRecord,
) -> None:
    await repo.insert_reading(reading)

    history = await repo.get_readings_since(node.id, reading.received_at - FEATURE_HISTORY_WINDOW)
    if not history:
        history = [reading]
    features = build_features(reading.received_at, history)

    guardrail_inputs = evaluate_guardrail(
        reading, features, tier2_model, critical_height_m=node.critical_height_m
    )

    transition = state_machine.evaluate(node.id, reading.received_at, guardrail_inputs)
    if transition is None:
        return

    await repo.append_transition(
        node_id=transition.node_id,
        from_state=transition.from_state.name,
        to_state=transition.to_state.name,
        occurred_at=transition.occurred_at,
        reason=transition.reason,
    )
    logger.info(
        "node %s: %s -> %s (reason=%s)",
        node.id,
        transition.from_state.name,
        transition.to_state.name,
        transition.reason,
    )

    if transition.to_state not in ALERTABLE_STATES:
        return
    if transition.to_state is RiskState.WARNING and transition.from_state is RiskState.EVACUATE:
        return  # de-escalating out of EVACUATE isn't a fresh advisory

    cells = cells_around_point(node.lat, node.lon, settings.alert_buffer_rings)
    message_en, message_ms = build_alert_copy(transition.to_state)
    await repo.create_hazard(
        state=transition.to_state.name,
        cells=list(cells),
        message_en=message_en,
        message_ms=message_ms,
    )
    for cell_id in cells:
        await fcm_client.publish_to_cell(cell_id, transition.to_state, message_en, message_ms)


def frame_to_fields(frame: UplinkFrame) -> dict:
    """Adapter for feeding a decoded UplinkFrame (e.g. from the synthetic
    generator) through the same JSON-shaped path real MQTT messages take."""
    return {
        "seq": frame.seq,
        "level_mm": frame.level_mm,
        "tilt_x": frame.tilt_x,
        "tilt_y": frame.tilt_y,
        "soil_pct": frame.soil_pct,
        "rain_tips": frame.rain_tips,
        "temp_c": frame.temp_c,
        "rh_pct": frame.rh_pct,
        "vbat_cv": frame.vbat_cv,
        "flags": frame.flags,
    }
