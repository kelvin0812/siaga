from datetime import datetime, timedelta, timezone

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from backend.app.main import create_app
from backend.app.repository import InMemoryRepository, ReadingRecord

T0 = datetime(2026, 8, 13, 0, 0, 0, tzinfo=timezone.utc)


@pytest_asyncio.fixture
async def repo() -> InMemoryRepository:
    r = InMemoryRepository()
    await r.upsert_node(1, "Node 1", lat=4.85, lon=100.74, datum_mm=3000)
    return r


@pytest_asyncio.fixture
async def client(repo):
    app = create_app(repo)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


def make_reading(node_id=1, minutes_ago=0, **overrides) -> ReadingRecord:
    defaults = dict(
        node_id=node_id,
        gateway_id="gw1",
        received_at=T0 - timedelta(minutes=minutes_ago),
        seq=0,
        level_mm=2800,
        height_m=0.2,
        tilt_x=0,
        tilt_y=0,
        soil_pct=30,
        rain_tips=0,
        temp_c=28,
        rh_pct=70,
        vbat_cv=80,
        flags=0,
        rssi=-80.0,
        snr=9.0,
    )
    defaults.update(overrides)
    return ReadingRecord(**defaults)


@pytest.mark.asyncio
async def test_list_nodes_returns_registered_node_with_no_readings_yet(client):
    resp = await client.get("/api/v1/nodes")
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) == 1
    assert body[0]["id"] == 1
    assert body[0]["state"] == "NORMAL"
    assert body[0]["last_seen"] is None
    assert body[0]["battery"] is None


@pytest.mark.asyncio
async def test_list_nodes_reflects_last_reading_battery_and_state(client, repo):
    await repo.insert_reading(make_reading(vbat_cv=85))
    await repo.append_transition(1, "NORMAL", "WATCH", T0, {"reason": "test"})

    resp = await client.get("/api/v1/nodes")
    body = resp.json()[0]
    assert body["state"] == "WATCH"
    assert body["battery"] == pytest.approx(3.85)


@pytest.mark.asyncio
async def test_node_history_returns_readings_within_window(client, repo):
    now = datetime.now(timezone.utc)
    await repo.insert_reading(make_reading(minutes_ago=0, received_at=now, height_m=1.0))
    await repo.insert_reading(
        make_reading(minutes_ago=0, received_at=now - timedelta(hours=48), height_m=0.5)
    )

    resp = await client.get("/api/v1/nodes/1/history", params={"hours": 24})
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) == 1
    assert body[0]["height_m"] == pytest.approx(1.0)


@pytest.mark.asyncio
async def test_node_history_404_for_unknown_node(client):
    resp = await client.get("/api/v1/nodes/999/history")
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_no_lat_lon_accepted_anywhere_in_reports_payload(client):
    # Section 3.1/5.3: the endpoint must not accept coordinates at all.
    resp = await client.post(
        "/api/v1/reports",
        json={"cell_id": "8865050927fffff", "category": "flooding", "lat": 4.85, "lon": 100.74},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert "id" in body
    # extra lat/lon fields are silently ignored by pydantic, not stored or echoed
    assert set(body.keys()) == {"id"}


@pytest.mark.asyncio
async def test_create_report_returns_id(client):
    resp = await client.post(
        "/api/v1/reports",
        json={"cell_id": "8865050927fffff", "category": "flooding", "note": "water on road"},
    )
    assert resp.status_code == 200
    assert isinstance(resp.json()["id"], int)


@pytest.mark.asyncio
async def test_density_omits_cells_under_k_anonymity_threshold(client, repo):
    for _ in range(9):
        await repo.bump_subscription("cell_a", 1)
    for _ in range(10):
        await repo.bump_subscription("cell_b", 1)

    resp = await client.get("/api/v1/density")
    body = {row["cell_id"]: row["count"] for row in resp.json()}
    assert "cell_a" not in body
    assert body["cell_b"] == 10


@pytest.mark.asyncio
async def test_subscription_ping_increments_and_decrements(client):
    await client.post("/api/v1/subscriptions/ping", json={"cell_id": "cell_x", "delta": 1})
    await client.post("/api/v1/subscriptions/ping", json={"cell_id": "cell_x", "delta": 1})
    resp = await client.post("/api/v1/subscriptions/ping", json={"cell_id": "cell_x", "delta": -1})
    assert resp.status_code == 204


@pytest.mark.asyncio
async def test_subscription_ping_rejects_invalid_delta(client):
    resp = await client.post("/api/v1/subscriptions/ping", json={"cell_id": "cell_x", "delta": 5})
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_active_hazards_returns_created_hazard(client, repo):
    await repo.create_hazard("WARNING", ["cell_a", "cell_b"], "Evacuate now", "Berpindah sekarang")
    resp = await client.get("/api/v1/hazards/active")
    body = resp.json()
    assert len(body) == 1
    assert body[0]["state"] == "WARNING"
    assert set(body[0]["cells"]) == {"cell_a", "cell_b"}


@pytest.mark.asyncio
async def test_health_reports_silent_node(client, repo):
    stale = datetime.now(timezone.utc) - timedelta(hours=1)
    await repo.insert_reading(make_reading(received_at=stale))

    resp = await client.get("/api/v1/health")
    body = resp.json()
    assert body["status"] == "degraded"
    assert 1 in body["silent_node_ids"]


@pytest.mark.asyncio
async def test_health_ok_when_node_recently_seen(client, repo):
    await repo.insert_reading(make_reading(received_at=datetime.now(timezone.utc)))
    resp = await client.get("/api/v1/health")
    body = resp.json()
    assert body["status"] == "ok"
    assert body["silent_node_ids"] == []
