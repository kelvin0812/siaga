"""
REST API (build brief Section 5.3). Depends only on Repository — never on
the state machine, Tier 2 model, or FCM client directly, since those only
run inside the ingest pipeline (pipeline.py), which this router doesn't
need and which can't run on a serverless deployment anyway (see
deploy/README.md for the Vercel/persistent-process split).

POST /api/v1/subscriptions/ping is NOT in Section 5.3's table. It exists
because Firebase Cloud Messaging has no API to read topic subscriber
counts, so nothing would ever populate /api/v1/density otherwise — see
docs/nexus-log.md for the full reasoning. Flagging it here too since
Section 5.3 calls its table "fixed interfaces."
"""
from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from backend.app.config import settings
from backend.app.heartbeat import is_node_silent
from backend.app.repository import Repository
from backend.app.state_machine import RiskState
from shared.frame import vbat_cv_to_volts

router = APIRouter(prefix="/api/v1")


async def _repo(request: Request) -> Repository:
    """
    Lazily builds and caches the repository on first use. Needed because
    on Vercel a repo can't be constructed (async pool connect) at module
    import time, and ASGI lifespan startup isn't reliably invoked there —
    see main.create_app's repo_factory parameter.
    """
    state = request.app.state
    if state.repo is not None:
        return state.repo
    if not hasattr(state, "_repo_lock"):
        state._repo_lock = asyncio.Lock()
    async with state._repo_lock:
        if state.repo is None:
            state.repo = await state.repo_factory()
    return state.repo


class NodeOut(BaseModel):
    id: int
    name: str
    lat: float
    lon: float
    state: str
    last_seen: datetime | None
    battery: float | None


class ReadingOut(BaseModel):
    received_at: datetime
    height_m: float
    level_mm: int
    tilt_x: int
    tilt_y: int
    soil_pct: int
    rain_tips: int
    temp_c: int
    rh_pct: int
    battery: float
    flags: int
    rssi: float | None
    snr: float | None


class HazardOut(BaseModel):
    id: int
    state: str
    cells: list[str]
    issued_at: datetime
    message_en: str
    message_ms: str


class ReportIn(BaseModel):
    cell_id: str
    category: str
    note: str | None = None
    photo_url: str | None = None
    """
    Set by the client after it uploads the photo directly to object
    storage — this API never receives photo bytes, only the resulting
    URL, so it stays a small JSON endpoint (Section 5.3: cell_id, not
    coordinates, so a report can't become a location backdoor).
    """


class ReportOut(BaseModel):
    id: int


class DensityEntry(BaseModel):
    cell_id: str
    count: int


class SubscriptionPingIn(BaseModel):
    cell_id: str
    delta: int = Field(..., description="+1 on subscribe, -1 on unsubscribe")


class HealthOut(BaseModel):
    status: str
    ingest_lag_s: float | None
    last_model_run: datetime | None
    silent_node_ids: list[int]
    total_nodes: int


@router.get("/nodes", response_model=list[NodeOut])
async def list_nodes(request: Request):
    repo = await _repo(request)
    nodes = await repo.list_nodes()
    out = []
    for node in nodes:
        state = await repo.get_node_state(node.id)
        last_reading = await repo.get_last_reading(node.id)
        out.append(
            NodeOut(
                id=node.id,
                name=node.name,
                lat=node.lat,
                lon=node.lon,
                state=state,
                last_seen=last_reading.received_at if last_reading else None,
                battery=vbat_cv_to_volts(last_reading.vbat_cv) if last_reading else None,
            )
        )
    return out


@router.get("/nodes/{node_id}/history", response_model=list[ReadingOut])
async def node_history(node_id: int, request: Request, hours: int = 24):
    repo = await _repo(request)
    node = await repo.get_node(node_id)
    if node is None:
        raise HTTPException(status_code=404, detail="node not found")
    since = datetime.now(timezone.utc) - timedelta(hours=hours)
    readings = await repo.get_readings_window(node_id, since, limit=500)
    return [
        ReadingOut(
            received_at=r.received_at,
            height_m=r.height_m,
            level_mm=r.level_mm,
            tilt_x=r.tilt_x,
            tilt_y=r.tilt_y,
            soil_pct=r.soil_pct,
            rain_tips=r.rain_tips,
            temp_c=r.temp_c,
            rh_pct=r.rh_pct,
            battery=vbat_cv_to_volts(r.vbat_cv),
            flags=r.flags,
            rssi=r.rssi,
            snr=r.snr,
        )
        for r in readings
    ]


@router.get("/hazards/active", response_model=list[HazardOut])
async def active_hazards(request: Request):
    repo = await _repo(request)
    hazards = await repo.list_active_hazards()
    return [
        HazardOut(
            id=h.id,
            state=h.state,
            cells=list(h.cells),
            issued_at=h.issued_at,
            message_en=h.message_en,
            message_ms=h.message_ms,
        )
        for h in hazards
    ]


@router.post("/reports", response_model=ReportOut)
async def create_report(body: ReportIn, request: Request):
    repo = await _repo(request)
    report_id = await repo.insert_report(body.cell_id, body.category, body.note, body.photo_url)
    return ReportOut(id=report_id)


@router.get("/density", response_model=list[DensityEntry])
async def density(request: Request):
    repo = await _repo(request)
    counts = await repo.get_density(settings.density_min_subscribers)
    return [DensityEntry(cell_id=cell_id, count=count) for cell_id, count in counts.items()]


@router.post("/subscriptions/ping", status_code=204)
async def subscription_ping(body: SubscriptionPingIn, request: Request):
    if body.delta not in (-1, 1):
        raise HTTPException(status_code=400, detail="delta must be +1 or -1")
    repo = await _repo(request)
    await repo.bump_subscription(body.cell_id, body.delta)


@router.get("/health", response_model=HealthOut)
async def health(request: Request):
    repo = await _repo(request)
    nodes = await repo.list_nodes()
    now = datetime.now(timezone.utc)

    silent_ids: list[int] = []
    lags: list[float] = []
    for node in nodes:
        last_reading = await repo.get_last_reading(node.id)
        if last_reading is None:
            silent_ids.append(node.id)
            continue
        state_name = await repo.get_node_state(node.id)
        state = RiskState[state_name]
        if is_node_silent(last_reading.received_at, now, state):
            silent_ids.append(node.id)
        lags.append((now - last_reading.received_at).total_seconds())

    return HealthOut(
        status="ok" if not silent_ids else "degraded",
        ingest_lag_s=min(lags) if lags else None,
        # No trained Tier 2 model exists yet (Section 7 is separate future
        # work) — null here is accurate, not a bug, until that ships.
        last_model_run=None,
        silent_node_ids=silent_ids,
        total_nodes=len(nodes),
    )
