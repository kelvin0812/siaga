"""AsyncpgRepository: production Repository implementation against Supabase Postgres."""
from __future__ import annotations

import json
from datetime import datetime

import asyncpg

from backend.app.repository import HazardRecord, NodeRecord, ReadingRecord


class AsyncpgRepository:
    def __init__(self, pool: asyncpg.Pool) -> None:
        self._pool = pool

    @classmethod
    async def connect(cls, dsn: str) -> "AsyncpgRepository":
        # statement_cache_size=0: required when dsn points at Supabase's
        # PgBouncer connection pooler (the Vercel deployment must use it —
        # serverless can spin up many concurrent instances, and Postgres
        # has a hard connection limit a pool of direct connections would
        # blow through). PgBouncer in transaction mode breaks asyncpg's
        # default prepared-statement caching ("prepared statement already
        # exists" errors); disabling it costs a small amount of query
        # planning overhead per call and buys pooler compatibility
        # unconditionally, so it's left on even for direct connections.
        pool = await asyncpg.create_pool(
            dsn=dsn, min_size=1, max_size=10, statement_cache_size=0
        )
        return cls(pool)

    async def close(self) -> None:
        await self._pool.close()

    async def upsert_node(
        self,
        node_id: int,
        name: str,
        lat: float,
        lon: float,
        datum_mm: int = 3000,
        critical_height_m: float | None = None,
    ) -> None:
        async with self._pool.acquire() as conn:
            await conn.execute(
                """
                insert into nodes (id, name, lat, lon, datum_mm, critical_height_m)
                values ($1, $2, $3, $4, $5, $6)
                on conflict (id) do update set
                    name = excluded.name, lat = excluded.lat, lon = excluded.lon,
                    datum_mm = excluded.datum_mm, critical_height_m = excluded.critical_height_m
                """,
                node_id,
                name,
                lat,
                lon,
                datum_mm,
                critical_height_m,
            )

    @staticmethod
    def _row_to_node(r: asyncpg.Record) -> NodeRecord:
        return NodeRecord(
            id=r["id"],
            name=r["name"],
            lat=r["lat"],
            lon=r["lon"],
            datum_mm=r["datum_mm"],
            critical_height_m=r["critical_height_m"],
        )

    async def list_nodes(self) -> list[NodeRecord]:
        async with self._pool.acquire() as conn:
            rows = await conn.fetch(
                "select id, name, lat, lon, datum_mm, critical_height_m from nodes order by id"
            )
        return [self._row_to_node(r) for r in rows]

    async def get_node(self, node_id: int) -> NodeRecord | None:
        async with self._pool.acquire() as conn:
            row = await conn.fetchrow(
                "select id, name, lat, lon, datum_mm, critical_height_m from nodes where id = $1",
                node_id,
            )
        return self._row_to_node(row) if row else None

    async def insert_reading(self, reading: ReadingRecord) -> None:
        async with self._pool.acquire() as conn:
            await conn.execute(
                """
                insert into readings (
                    node_id, gateway_id, received_at, seq, level_mm, height_m,
                    tilt_x, tilt_y, soil_pct, rain_tips, temp_c, rh_pct, vbat_cv,
                    flags, rssi, snr
                ) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
                """,
                reading.node_id,
                reading.gateway_id,
                reading.received_at,
                reading.seq,
                reading.level_mm,
                reading.height_m,
                reading.tilt_x,
                reading.tilt_y,
                reading.soil_pct,
                reading.rain_tips,
                reading.temp_c,
                reading.rh_pct,
                reading.vbat_cv,
                reading.flags,
                reading.rssi,
                reading.snr,
            )

    @staticmethod
    def _row_to_reading(r: asyncpg.Record) -> ReadingRecord:
        return ReadingRecord(
            node_id=r["node_id"],
            gateway_id=r["gateway_id"],
            received_at=r["received_at"],
            seq=r["seq"],
            level_mm=r["level_mm"],
            height_m=r["height_m"],
            tilt_x=r["tilt_x"],
            tilt_y=r["tilt_y"],
            soil_pct=r["soil_pct"],
            rain_tips=r["rain_tips"],
            temp_c=r["temp_c"],
            rh_pct=r["rh_pct"],
            vbat_cv=r["vbat_cv"],
            flags=r["flags"],
            rssi=r["rssi"],
            snr=r["snr"],
        )

    async def get_last_reading(self, node_id: int) -> ReadingRecord | None:
        async with self._pool.acquire() as conn:
            row = await conn.fetchrow(
                "select * from readings where node_id = $1 order by received_at desc limit 1",
                node_id,
            )
        return self._row_to_reading(row) if row else None

    async def get_readings_since(self, node_id: int, since: datetime) -> list[ReadingRecord]:
        async with self._pool.acquire() as conn:
            rows = await conn.fetch(
                "select * from readings where node_id = $1 and received_at >= $2 order by received_at",
                node_id,
                since,
            )
        return [self._row_to_reading(r) for r in rows]

    async def get_readings_window(
        self, node_id: int, since: datetime, limit: int
    ) -> list[ReadingRecord]:
        readings = await self.get_readings_since(node_id, since)
        if len(readings) <= limit:
            return readings
        step = len(readings) / limit
        return [readings[int(i * step)] for i in range(limit)]

    async def get_node_state(self, node_id: int) -> str:
        async with self._pool.acquire() as conn:
            row = await conn.fetchrow(
                "select state from node_state where node_id = $1", node_id
            )
        return row["state"] if row else "NORMAL"

    async def append_transition(
        self, node_id: int, from_state: str, to_state: str, occurred_at: datetime, reason: dict
    ) -> None:
        async with self._pool.acquire() as conn:
            async with conn.transaction():
                await conn.execute(
                    """
                    insert into state_transitions (node_id, from_state, to_state, occurred_at, reason)
                    values ($1, $2, $3, $4, $5)
                    """,
                    node_id,
                    from_state,
                    to_state,
                    occurred_at,
                    json.dumps(reason),
                )
                await conn.execute(
                    """
                    insert into node_state (node_id, state, updated_at) values ($1, $2, $3)
                    on conflict (node_id) do update set state = excluded.state, updated_at = excluded.updated_at
                    """,
                    node_id,
                    to_state,
                    occurred_at,
                )

    async def create_hazard(
        self, state: str, cells: list[str], message_en: str, message_ms: str
    ) -> HazardRecord:
        async with self._pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                insert into hazards (state, cells, message_en, message_ms)
                values ($1, $2, $3, $4)
                returning id, state, cells, issued_at, message_en, message_ms, active
                """,
                state,
                cells,
                message_en,
                message_ms,
            )
        return HazardRecord(
            id=row["id"],
            state=row["state"],
            cells=tuple(row["cells"]),
            issued_at=row["issued_at"],
            message_en=row["message_en"],
            message_ms=row["message_ms"],
            active=row["active"],
        )

    async def list_active_hazards(self) -> list[HazardRecord]:
        async with self._pool.acquire() as conn:
            rows = await conn.fetch("select * from hazards where active order by issued_at desc")
        return [
            HazardRecord(
                id=r["id"],
                state=r["state"],
                cells=tuple(r["cells"]),
                issued_at=r["issued_at"],
                message_en=r["message_en"],
                message_ms=r["message_ms"],
                active=r["active"],
            )
            for r in rows
        ]

    async def insert_report(
        self, cell_id: str, category: str, note: str | None, photo_url: str | None
    ) -> int:
        async with self._pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                insert into reports (cell_id, category, note, photo_url)
                values ($1, $2, $3, $4) returning id
                """,
                cell_id,
                category,
                note,
                photo_url,
            )
        return row["id"]

    async def bump_subscription(self, cell_id: str, delta: int) -> None:
        async with self._pool.acquire() as conn:
            await conn.execute(
                """
                insert into cell_subscriptions (cell_id, count, updated_at)
                values ($1, greatest(0, $2), now())
                on conflict (cell_id) do update
                    set count = greatest(0, cell_subscriptions.count + $2), updated_at = now()
                """,
                cell_id,
                delta,
            )

    async def get_density(self, min_count: int) -> dict[str, int]:
        async with self._pool.acquire() as conn:
            rows = await conn.fetch(
                "select cell_id, count from cell_subscriptions where count >= $1", min_count
            )
        return {r["cell_id"]: r["count"] for r in rows}
