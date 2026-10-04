"""
Bridges the ESP32/Pico bench rig's readings (Supabase `sensor_table`, a
different sensor set from the real node firmware)
into the *actual trained* Tier 2 pipeline, so a resident on the bench can
see what the real model says about real sensor data, live -- not a second,
hand-rolled evaluation, and not a retrain (there's nowhere near enough
labelled data on the bench rig to train anything on; Section 7 is explicit
that only historical public records + synthetic hydrographs do that).

Every value below either comes from a real sensor on the rig, or is an
explicit, user-controlled override for a signal the rig genuinely doesn't
have (chiefly rainfall -- there's no rain gauge on this bench setup).
Nothing here is a silent default standing in for missing data; see each
conversion's comment for exactly what it represents and why.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import math

import httpx

from backend.app.repository import ReadingRecord
from shared.constants import TIP_RESOLUTION_MM

# Same Supabase project/anon key used throughout this bench-rig work (app/
# lib/core/bench_sensor_service.dart, photo_upload_service.dart). Public/
# publishable by design, scoped by sensor_table's RLS to insert+select.
_SUPABASE_URL = "https://oqsdoubmzzkfgcvvsbfb.supabase.co"
_SUPABASE_ANON_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9xc2RvdWJtenprZmdjdnZzYmZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY2MzQxNTksImV4cCI6MjEwMjIxMDE1OX0.QizwV00qxMexZNUKVQ7V7LOCBBBNe3CfdzvBVohjOb8"
)


class BenchEvalError(Exception):
    pass


async def fetch_latest_bench_reading() -> dict | None:
    """Latest row from sensor_table, or None if the rig hasn't posted anything yet."""
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(
            f"{_SUPABASE_URL}/rest/v1/sensor_table",
            params={"select": "*", "order": "created_at.desc", "limit": "1"},
            headers={
                "apikey": _SUPABASE_ANON_KEY,
                "Authorization": f"Bearer {_SUPABASE_ANON_KEY}",
            },
        )
    if resp.status_code != 200:
        raise BenchEvalError(f"Supabase sensor_table read failed: {resp.status_code}")
    rows = resp.json()
    return rows[0] if rows else None


@dataclass(frozen=True, slots=True)
class BenchOverrides:
    """User-adjustable inputs from the app's Settings panel. Every field
    here corresponds to a signal the bench rig cannot sense itself."""

    rain_mm_1h: float = 0.0
    """Simulated sustained rainfall over the last hour. The rig has no rain
    gauge at all -- this is the one genuinely missing input to the model.
    Applied identically to the 1h/3h/6h/24h windows (a single snapshot
    reading has no real time series to window differently), so this reads
    as "it's been raining at this rate for a while," not a real storm
    profile -- an intentional simplification for a live spot-check, not
    something to read as historically accurate."""

    height_m_override: float | None = None
    """The rig's ultrasonic sensor measures distance to whatever's in
    front of it on the bench, not a river -- there is no physically
    meaningful water level to derive from it. When None, falls back to a
    calm-baseline default (1.2m, the same "quiet river" figure used
    elsewhere in this project's scenario simulations) rather than treating
    the raw distance reading as if it meant something it doesn't."""

    soil_pct_override: float | None = None
    """When None, uses the rig's raw `soil` reading directly, clamped to
    [0, 100] -- this IS a real sensor, but its calibration against this
    specific probe/soil is unverified, so an override is offered for
    deliberate what-if testing."""


def bench_reading_to_record(row: dict, overrides: BenchOverrides, node_id: int = 999) -> ReadingRecord:
    """
    Converts one sensor_table row + explicit overrides into a ReadingRecord
    that the real feature builder / guardrail / state machine can consume
    unmodified. See BenchOverrides' field docs for what's real vs
    simulated; see inline comments below for the sensor conversions.
    """
    height_m = overrides.height_m_override if overrides.height_m_override is not None else 1.2

    raw_soil = row.get("soil")
    soil_pct = overrides.soil_pct_override if overrides.soil_pct_override is not None else float(raw_soil or 0)
    soil_pct = max(0.0, min(100.0, soil_pct))

    # Rough lean angle from the accelerometer, in the frame's 0.1 deg/LSB
    # units -- NOT the brief's actual tilt semantics (Section 6.1: a delta
    # against a rolling 24h baseline, specifically to avoid absolute-angle
    # drift). There's no 24h baseline for a bench rig that's moved between
    # test sessions, so this is frankly an approximation of "how tilted is
    # it right now," clamped to what an int8 can hold (+/-12.8 degrees).
    ax, ay, az = (row.get("accel_x") or 0.0), (row.get("accel_y") or 0.0), (row.get("accel_z") or 0.0)
    try:
        roll_deg = math.degrees(math.atan2(ay, az)) if (ay, az) != (0, 0) else 0.0
        pitch_deg = math.degrees(math.atan2(-ax, math.hypot(ay, az))) if (ax, ay, az) != (0, 0, 0) else 0.0
    except (ValueError, ZeroDivisionError):
        roll_deg, pitch_deg = 0.0, 0.0
    tilt_x = max(-128, min(127, round(pitch_deg * 10)))
    tilt_y = max(-128, min(127, round(roll_deg * 10)))

    rain_tips = round(overrides.rain_mm_1h / TIP_RESOLUTION_MM) if overrides.rain_mm_1h > 0 else 0

    # Deliberately NOT the row's own (possibly hours/days-stale, since the
    # rig doesn't post continuously) `created_at` -- build_features windows
    # rain/rate features by how recent a reading is relative to `now`, so
    # a stale timestamp here would silently zero out rain_cum_*h_mm no
    # matter what rain_mm_1h was set to (caught by testing: a 40mm/1h
    # override produced 0mm of cumulative rain once the reading was a day
    # old). This function answers "what would the model say about this
    # sensor snapshot IF it happened right now," not "what did it say back
    # when the rig actually posted it" -- the endpoint reports the real
    # original timestamp separately via bench_reading_at for staleness.
    return ReadingRecord(
        node_id=node_id,
        gateway_id="bench-rig",
        received_at=datetime.now(timezone.utc),
        seq=0,
        level_mm=round((3.0 - height_m) * 1000),
        height_m=height_m,
        tilt_x=tilt_x,
        tilt_y=tilt_y,
        soil_pct=round(soil_pct),
        rain_tips=rain_tips,
        # Not model inputs at all (see features.py's FEATURE_NAMES) --
        # temp/humidity/battery feed no engineered feature Tier 2 uses, so
        # these are inert placeholders, not simulated data standing in for
        # something that matters.
        temp_c=28,
        rh_pct=75,
        vbat_cv=80,
        flags=0,
    )
