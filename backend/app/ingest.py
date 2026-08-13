"""
MQTT ingest (build brief Section 5.2 / 6.3). Subscribes to the gateway
topics and feeds decoded readings through pipeline.process_reading.

siaga/v1/cmd/<gateway_id> is reserved for future config push (Section
5.2): the subscription exists so the topic is live end to end, but there
is deliberately no handler yet — implementing config push isn't asked
for by any subsystem requirement in Section 6.
"""
from __future__ import annotations

import json
import logging
import ssl
from datetime import datetime

import aiomqtt

from backend.app.config import Settings
from backend.app.fcm import FCMClient
from backend.app.pipeline import decode_reading, process_reading
from backend.app.repository import Repository
from backend.app.state_machine import StateMachine
from backend.app.tier2 import Tier2Model

logger = logging.getLogger("siaga.ingest")

TELEMETRY_PREFIX = "siaga/v1/telemetry/"
STATUS_PREFIX = "siaga/v1/status/"
CMD_WILDCARD = "siaga/v1/cmd/#"


async def _handle_telemetry(
    payload: dict,
    repo: Repository,
    state_machine: StateMachine,
    tier2_model: Tier2Model,
    fcm_client: FCMClient,
) -> None:
    node_id = payload["node_id"]
    node = await repo.get_node(node_id)
    if node is None:
        logger.warning("telemetry for unknown node_id=%s dropped", node_id)
        return

    received_at = datetime.fromisoformat(payload["received_at"])
    reading = decode_reading(
        node=node,
        gateway_id=payload["gateway_id"],
        received_at=received_at,
        frame_fields=payload,
        rssi=payload.get("rssi"),
        snr=payload.get("snr"),
    )
    await process_reading(repo, state_machine, tier2_model, fcm_client, node, reading)


async def _handle_status(payload: dict) -> None:
    # Heartbeat carries uptime/buffered_count/rssi (Section 5.2) — used to
    # tell "gateway silent" apart from "nodes silent"; no per-node state
    # here, so just log it. Node-level silence is evaluated separately
    # against each node's last reading (see heartbeat.is_node_silent),
    # driven by the /api/v1/health endpoint rather than this stream.
    logger.info("gateway %s heartbeat: %s", payload.get("gateway_id"), payload)


async def run_ingest_loop(
    settings: Settings,
    repo: Repository,
    state_machine: StateMachine,
    tier2_model: Tier2Model,
    fcm_client: FCMClient,
) -> None:
    tls_params = aiomqtt.TLSParameters(tls_version=ssl.PROTOCOL_TLS_CLIENT) if settings.mqtt_tls else None
    async with aiomqtt.Client(
        hostname=settings.mqtt_host,
        port=settings.mqtt_port,
        username=settings.mqtt_username or None,
        password=settings.mqtt_password or None,
        tls_params=tls_params,
    ) as client:
        await client.subscribe(f"{TELEMETRY_PREFIX}+")
        await client.subscribe(f"{STATUS_PREFIX}+")
        await client.subscribe(CMD_WILDCARD)
        logger.info("subscribed to telemetry/status/cmd topics on %s", settings.mqtt_host)

        async for message in client.messages:
            topic = str(message.topic)
            try:
                payload = json.loads(message.payload)
            except (json.JSONDecodeError, TypeError):
                logger.warning("dropping non-JSON payload on %s", topic)
                continue

            if topic.startswith(TELEMETRY_PREFIX):
                await _handle_telemetry(payload, repo, state_machine, tier2_model, fcm_client)
            elif topic.startswith(STATUS_PREFIX):
                await _handle_status(payload)
            elif topic.startswith("siaga/v1/cmd/"):
                pass  # reserved, no handler yet (Section 5.2)
