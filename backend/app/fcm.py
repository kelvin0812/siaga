"""
FCM dispatch (build brief Section 6.3): publish to `cell_<h3id>` topics
only — never to a device token mapped to a location (Section 3.1/4.1).

Alert copy carries explicit source attribution and points recipients to
official channels, since this is decision support, not a statutory
warning (Section 6.3). Full multilingual selection/override is an app
concern (Section 6.4); the backend just ships both strings.

NullFCMClient is the default when no Firebase credentials are configured
— it logs what would have been sent instead of raising, so a booth demo
with no internet still runs the full pipeline end to end (Section 2).
"""
from __future__ import annotations

import logging
from typing import Protocol

from backend.app.state_machine import RiskState

logger = logging.getLogger("siaga.fcm")

_SOURCE_ATTRIBUTION_EN = "SIAGA advisory (decision support only) — confirm with NADMA / MetMalaysia / JPS."
_SOURCE_ATTRIBUTION_MS = "Nasihat SIAGA (sokongan keputusan sahaja) — sahkan dengan NADMA / MetMalaysia / JPS."

_TEMPLATES: dict[RiskState, tuple[str, str]] = {
    RiskState.WATCH: (
        "Elevated readings detected near your area. No action needed yet.",
        "Bacaan meningkat dikesan berhampiran kawasan anda. Tiada tindakan diperlukan buat masa ini.",
    ),
    RiskState.WARNING: (
        "Flood/landslide risk rising in your area. Prepare to evacuate and review your route.",
        "Risiko banjir/tanah runtuh meningkat di kawasan anda. Bersedia untuk berpindah dan semak laluan anda.",
    ),
    RiskState.EVACUATE: (
        "EVACUATE NOW. Leave the area immediately and follow official guidance.",
        "BERPINDAH SEKARANG. Tinggalkan kawasan ini dengan segera dan ikut arahan rasmi.",
    ),
}


def build_alert_copy(state: RiskState) -> tuple[str, str]:
    """Returns (message_en, message_ms), each with source attribution appended."""
    if state not in _TEMPLATES:
        raise ValueError(f"no alert template for state {state.name}")
    body_en, body_ms = _TEMPLATES[state]
    return f"{body_en} {_SOURCE_ATTRIBUTION_EN}", f"{body_ms} {_SOURCE_ATTRIBUTION_MS}"


class FCMClient(Protocol):
    async def publish_to_cell(
        self, cell_id: str, state: RiskState, message_en: str, message_ms: str
    ) -> None: ...


class NullFCMClient:
    async def publish_to_cell(
        self, cell_id: str, state: RiskState, message_en: str, message_ms: str
    ) -> None:
        logger.warning(
            "FCM not configured — would publish to cell_%s [%s]: %s",
            cell_id,
            state.name,
            message_en,
        )


class FirebaseFCMClient:
    def __init__(self, credentials_path: str) -> None:
        import firebase_admin
        from firebase_admin import credentials

        cred = credentials.Certificate(credentials_path)
        self._app = firebase_admin.initialize_app(cred)

    async def publish_to_cell(
        self, cell_id: str, state: RiskState, message_en: str, message_ms: str
    ) -> None:
        from firebase_admin import messaging

        message = messaging.Message(
            topic=f"cell_{cell_id}",
            data={
                "state": state.name,
                "message_en": message_en,
                "message_ms": message_ms,
            },
            android=messaging.AndroidConfig(
                priority="high" if state == RiskState.EVACUATE else "normal"
            ),
        )
        messaging.send(message, app=self._app)
