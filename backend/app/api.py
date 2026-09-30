"""
REST API (build brief Section 5.3). Depends only on Repository for every
endpoint in Section 5.3's own table — never on the state machine, Tier 2
model, or FCM client directly, since those normally only run inside the
ingest pipeline (pipeline.py), which this router doesn't need and which
can't run on a serverless deployment anyway (see deploy/README.md for the
Vercel/persistent-process split).

Two endpoints below are deliberate, documented exceptions to Section
5.3's fixed table, both flagged in docs/nexus-log.md:

- POST /api/v1/subscriptions/ping exists because Firebase Cloud Messaging
  has no API to read topic subscriber counts, so nothing would ever
  populate /api/v1/density otherwise.
- POST /api/v1/bench/evaluate is the one endpoint that does touch the
  Tier 2 model directly (via _tier2() below) -- it lets the bench-rig
  live panel in the app run a real reading through the real trained
  model + guardrail + state machine, without a second ingest pipeline.
"""
from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from backend.app.bench_eval import BenchEvalError, BenchOverrides, bench_reading_to_record, fetch_latest_bench_reading
from backend.app.config import settings
from backend.app.features import build_features
from backend.app.guardrail import evaluate_guardrail
from backend.app.heartbeat import is_node_silent
from backend.app.repository import Repository
from backend.app.state_machine import RiskState, desired_state
from backend.app.tier2 import Tier2Model
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


def _tier2(request: Request) -> Tier2Model:
    """
    Lazily builds and caches the Tier 2 model on app.state, the same
    pattern _repo() uses and for the same reason (no heavy work at module
    import time on a serverless cold start). This is a deliberate,
    documented exception to this module's usual "REST API never touches
    Tier 2" rule (see the module docstring) -- /bench/evaluate is the one
    endpoint that legitimately needs it, to let a resident see what the
    real trained model says about real bench-rig sensor data.
    """
    state = request.app.state
    if not hasattr(state, "tier2_model") or state.tier2_model is None:
        from backend.app.main import build_tier2_model

        state.tier2_model = build_tier2_model()
    return state.tier2_model


class NodeOut(BaseModel):
    id: int
    name: str
    lat: float
    lon: float
    state: str
    last_seen: datetime | None
    battery: float | None
    # Tier 2 guardrail's raw probability as of the last processed reading
    # (Section 7's "per-node probability of threshold exceedance within 60
    # minutes"). Null until at least one reading has gone through the
    # pipeline for this node -- never fabricated to avoid a blank field.
    risk_probability: float | None


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
        risk_probability = await repo.get_risk_probability(node.id)
        out.append(
            NodeOut(
                id=node.id,
                name=node.name,
                lat=node.lat,
                lon=node.lon,
                state=state,
                last_seen=last_reading.received_at if last_reading else None,
                battery=vbat_cv_to_volts(last_reading.vbat_cv) if last_reading else None,
                risk_probability=risk_probability,
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


class BenchEvaluateIn(BaseModel):
    """See bench_eval.BenchOverrides for what each field represents and
    why it's the resident's choice rather than a computed value."""

    rain_mm_1h: float = Field(0.0, ge=0, le=200)
    height_m_override: float | None = Field(None, ge=0, le=20)
    soil_pct_override: float | None = Field(None, ge=0, le=100)


class BenchEvaluateOut(BaseModel):
    tier2_probability: float
    corroborating_channels: int
    physical_breach: bool
    state: str
    reading_used: dict
    """The exact ReadingRecord fields fed to the model, so the app can
    show its work rather than presenting a bare percentage — Section 7's
    explainability requirement applies here just as much as to training."""
    bench_reading_at: datetime | None
    """When the underlying sensor_table row was captured -- null if no
    bench reading exists yet and the frame fell back to defaults."""
    model_type: str
    """Which Tier2Model implementation actually produced tier2_probability
    -- "LightGBMTier2Model" (the real trained model) or "HeuristicTier2Stub"
    (a placeholder — see tier2.py). Reported explicitly so a stub answer
    is never presented as if it were the real model's, e.g. on a runtime
    where the trained model can't load (docs/nexus-log.md, 2026-09-30)."""


@router.post("/bench/evaluate", response_model=BenchEvaluateOut)
async def bench_evaluate(body: BenchEvaluateIn, request: Request):
    """
    Runs the LATEST bench-rig reading (Supabase sensor_table) plus the
    resident's explicit overrides through the real, already-trained Tier 2
    model, guardrail, and state machine -- see bench_eval.py's module
    docstring for why this is a live evaluation against real code, not a
    retrain and not a second hand-rolled scoring path.
    """
    try:
        row = await fetch_latest_bench_reading()
    except BenchEvalError as e:
        raise HTTPException(status_code=502, detail=str(e)) from e

    overrides = BenchOverrides(
        rain_mm_1h=body.rain_mm_1h,
        height_m_override=body.height_m_override,
        soil_pct_override=body.soil_pct_override,
    )
    # No bench reading yet: still evaluate against the overrides alone (a
    # row of defaults, honestly labelled via bench_reading_at=None) rather
    # than 502ing the whole endpoint -- lets someone try the sliders before
    # any hardware has posted anything.
    reading = bench_reading_to_record(row or {}, overrides)

    features = build_features(datetime.now(timezone.utc), [reading])
    tier2_model = _tier2(request)
    inputs = evaluate_guardrail(reading, features, tier2_model, critical_height_m=None)
    state = desired_state(inputs)

    return BenchEvaluateOut(
        tier2_probability=inputs.tier2_p,
        corroborating_channels=inputs.corroborating_channels,
        physical_breach=inputs.physical_breach,
        state=state.name,
        reading_used={
            "height_m": reading.height_m,
            "tilt_x": reading.tilt_x,
            "tilt_y": reading.tilt_y,
            "soil_pct": reading.soil_pct,
            "rain_tips": reading.rain_tips,
        },
        bench_reading_at=row.get("created_at") if row else None,
        model_type=type(tier2_model).__name__,
    )
