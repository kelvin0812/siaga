"""
Storage seam. `Repository` is the interface every other module codes
against; `InMemoryRepository` backs the test suite and also serves as the
booth demo's offline fallback (Section 2: the system must degrade visibly
rather than crash when something is unplugged — that includes a dropped
connection to Supabase). `AsyncpgRepository` (db_postgres.py) is the
production implementation.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Protocol


@dataclass(frozen=True, slots=True)
class NodeRecord:
    id: int
    name: str
    lat: float
    lon: float
    datum_mm: int = 3000
    critical_height_m: float | None = None


@dataclass(frozen=True, slots=True)
class ReadingRecord:
    node_id: int
    gateway_id: str
    received_at: datetime
    seq: int
    level_mm: int
    height_m: float
    tilt_x: int
    tilt_y: int
    soil_pct: int
    rain_tips: int
    temp_c: int
    rh_pct: int
    vbat_cv: int
    flags: int
    rssi: float | None = None
    snr: float | None = None


@dataclass(frozen=True, slots=True)
class HazardRecord:
    id: int
    state: str
    cells: tuple[str, ...]
    issued_at: datetime
    message_en: str
    message_ms: str
    active: bool = True


class Repository(Protocol):
    async def upsert_node(
        self,
        node_id: int,
        name: str,
        lat: float,
        lon: float,
        datum_mm: int = 3000,
        critical_height_m: float | None = None,
    ) -> None: ...
    async def list_nodes(self) -> list[NodeRecord]: ...
    async def get_node(self, node_id: int) -> NodeRecord | None: ...

    async def insert_reading(self, reading: ReadingRecord) -> None: ...
    async def get_last_reading(self, node_id: int) -> ReadingRecord | None: ...
    async def get_readings_since(self, node_id: int, since: datetime) -> list[ReadingRecord]: ...
    async def get_readings_window(
        self, node_id: int, since: datetime, limit: int
    ) -> list[ReadingRecord]: ...

    async def get_node_state(self, node_id: int) -> str: ...
    async def append_transition(
        self, node_id: int, from_state: str, to_state: str, occurred_at: datetime, reason: dict
    ) -> None: ...

    async def create_hazard(
        self, state: str, cells: list[str], message_en: str, message_ms: str
    ) -> HazardRecord: ...
    async def list_active_hazards(self) -> list[HazardRecord]: ...

    async def insert_report(
        self, cell_id: str, category: str, note: str | None, photo_url: str | None
    ) -> int: ...

    async def bump_subscription(self, cell_id: str, delta: int) -> None: ...
    async def get_density(self, min_count: int) -> dict[str, int]: ...


class InMemoryRepository:
    """Reference implementation used by tests and the offline demo path."""

    def __init__(self) -> None:
        self._nodes: dict[int, NodeRecord] = {}
        self._readings: dict[int, list[ReadingRecord]] = {}
        self._states: dict[int, str] = {}
        self._transitions: list[dict] = []
        self._hazards: list[HazardRecord] = []
        self._next_hazard_id = 1
        self._reports: list[dict] = []
        self._next_report_id = 1
        self._subscriptions: dict[str, int] = {}

    async def upsert_node(
        self,
        node_id: int,
        name: str,
        lat: float,
        lon: float,
        datum_mm: int = 3000,
        critical_height_m: float | None = None,
    ) -> None:
        self._nodes[node_id] = NodeRecord(
            id=node_id,
            name=name,
            lat=lat,
            lon=lon,
            datum_mm=datum_mm,
            critical_height_m=critical_height_m,
        )

    async def list_nodes(self) -> list[NodeRecord]:
        return sorted(self._nodes.values(), key=lambda n: n.id)

    async def get_node(self, node_id: int) -> NodeRecord | None:
        return self._nodes.get(node_id)

    async def insert_reading(self, reading: ReadingRecord) -> None:
        self._readings.setdefault(reading.node_id, []).append(reading)

    async def get_last_reading(self, node_id: int) -> ReadingRecord | None:
        readings = self._readings.get(node_id) or []
        return readings[-1] if readings else None

    async def get_readings_since(self, node_id: int, since: datetime) -> list[ReadingRecord]:
        readings = self._readings.get(node_id) or []
        return [r for r in readings if r.received_at >= since]

    async def get_readings_window(
        self, node_id: int, since: datetime, limit: int
    ) -> list[ReadingRecord]:
        readings = await self.get_readings_since(node_id, since)
        if len(readings) <= limit:
            return readings
        step = len(readings) / limit
        return [readings[int(i * step)] for i in range(limit)]

    async def get_node_state(self, node_id: int) -> str:
        return self._states.get(node_id, "NORMAL")

    async def append_transition(
        self, node_id: int, from_state: str, to_state: str, occurred_at: datetime, reason: dict
    ) -> None:
        self._states[node_id] = to_state
        self._transitions.append(
            {
                "node_id": node_id,
                "from_state": from_state,
                "to_state": to_state,
                "occurred_at": occurred_at,
                "reason": reason,
            }
        )

    async def create_hazard(
        self, state: str, cells: list[str], message_en: str, message_ms: str
    ) -> HazardRecord:
        hazard = HazardRecord(
            id=self._next_hazard_id,
            state=state,
            cells=tuple(cells),
            issued_at=datetime.now(timezone.utc),
            message_en=message_en,
            message_ms=message_ms,
        )
        self._next_hazard_id += 1
        self._hazards.append(hazard)
        return hazard

    async def list_active_hazards(self) -> list[HazardRecord]:
        return [h for h in self._hazards if h.active]

    async def insert_report(
        self, cell_id: str, category: str, note: str | None, photo_url: str | None
    ) -> int:
        report_id = self._next_report_id
        self._next_report_id += 1
        self._reports.append(
            {
                "id": report_id,
                "cell_id": cell_id,
                "category": category,
                "note": note,
                "photo_url": photo_url,
            }
        )
        return report_id

    async def bump_subscription(self, cell_id: str, delta: int) -> None:
        self._subscriptions[cell_id] = max(0, self._subscriptions.get(cell_id, 0) + delta)

    async def get_density(self, min_count: int) -> dict[str, int]:
        return {cell: count for cell, count in self._subscriptions.items() if count >= min_count}
