-- SIAGA backend schema — run once in the Supabase SQL editor.
--
-- Section 4.1 of the build brief specifies SQLite for the prototype and
-- says explicitly "do not introduce Postgres for a 3-node demo." This
-- schema is a deliberate, logged override to Postgres/Supabase (see
-- docs/nexus-log.md, 2026-08-13) — kept schema-portable in the sense that
-- it uses no Supabase-specific features (no RLS policies, no auth.uid()),
-- so it could still be moved to a bare Postgres host later.

create table if not exists nodes (
    id smallint primary key,
    name text not null,
    lat double precision not null,
    lon double precision not null,
    -- Transducer height above the channel bed at this specific install
    -- (Section 5.1: level_mm -> height_m needs a per-node datum).
    datum_mm integer not null default 3000,
    -- Absolute physical threshold for guardrail EVACUATE (Section 5.4).
    -- Null means "not configured" — the guardrail then never fires on
    -- physical breach for this node, only on corroborated Tier 2 probability.
    critical_height_m double precision,
    created_at timestamptz not null default now()
);

-- One row per decoded uplink frame, after the level_mm -> height_m
-- inversion has been applied once at ingestion (build brief Section 5.1).
create table if not exists readings (
    id bigserial primary key,
    node_id smallint not null references nodes(id),
    gateway_id text not null,
    received_at timestamptz not null,
    seq smallint not null,
    level_mm integer not null,
    height_m double precision not null,
    tilt_x smallint not null,
    tilt_y smallint not null,
    soil_pct smallint not null,
    rain_tips smallint not null,
    temp_c smallint not null,
    rh_pct smallint not null,
    vbat_cv smallint not null,
    flags smallint not null,
    rssi real,
    snr real
);
create index if not exists readings_node_time_idx on readings (node_id, received_at desc);

-- Current risk state per node — a cache over state_transitions, kept in
-- sync by the backend whenever it appends a transition.
create table if not exists node_state (
    node_id smallint primary key references nodes(id),
    state text not null,
    updated_at timestamptz not null default now(),
    -- Tier 2 guardrail's raw probability (0.0-1.0) as of the last
    -- processed reading. Updated on every reading, unlike `state` itself,
    -- which only moves on a state-machine transition -- so this is the
    -- one place a "live percentage" actually exists to show in the app.
    risk_probability double precision
);

-- Every state change, with the inputs that caused it, so any alert can be
-- traced back to the reading that triggered it (Section 10 correlation
-- requirement) and every transition is reconstructable after the fact
-- (Section 5.4).
create table if not exists state_transitions (
    id bigserial primary key,
    node_id smallint not null references nodes(id),
    from_state text not null,
    to_state text not null,
    occurred_at timestamptz not null default now(),
    reason jsonb not null
);
create index if not exists state_transitions_node_time_idx on state_transitions (node_id, occurred_at desc);

create table if not exists hazards (
    id bigserial primary key,
    state text not null,
    cells text[] not null,
    issued_at timestamptz not null default now(),
    message_en text not null,
    message_ms text not null,
    active boolean not null default true
);
create index if not exists hazards_active_idx on hazards (active);

-- Community hazard reports. cell_id only — never a lat/lon (Section 3.1 /
-- 5.3: the reports endpoint exists specifically so a photo report can't
-- become a backdoor location channel).
create table if not exists reports (
    id bigserial primary key,
    cell_id text not null,
    category text not null,
    note text,
    photo_url text,
    created_at timestamptz not null default now()
);

-- Anonymous per-cell FCM topic subscription counter. This table exists
-- because Firebase Cloud Messaging has no API to query topic subscriber
-- counts — Section 3.1/5.3 assume that data exists, but nothing in the
-- brief specifies how it gets populated. The app pings a subscribe/
-- unsubscribe delta (cell_id only, no device identifier) and this counter
-- is incremented/decremented accordingly. Flagged in docs/nexus-log.md as
-- an addition beyond Section 5.3's fixed endpoint table.
create table if not exists cell_subscriptions (
    cell_id text primary key,
    count integer not null default 0,
    updated_at timestamptz not null default now()
);

-- Bench-test ingestion table for a WiFi ESP32 + Pico rig that posts
-- straight to Supabase's PostgREST API (yoooo.ino), bypassing the LoRa/
-- gateway/MQTT pipeline entirely -- kept separate from `readings` on
-- purpose, so opening it to a direct anon insert doesn't touch that
-- table's deny-all RLS policy below. Flagged in docs/nexus-log.md:
-- anything landing here never reaches Tier 1/Tier 2/the guardrail, so
-- it's bench data, not a real node until backfilled into `readings`.
create table if not exists sensor_table (
    id bigserial primary key,
    node_id smallint,
    seq smallint,
    level_mm integer,
    tilt_x smallint,
    tilt_y smallint,
    soil_pct smallint,
    rain_tips smallint,
    temp_c smallint,
    rh_pct smallint,
    vbat_cv smallint,
    flags smallint,
    created_at timestamptz not null default now()
);
create index if not exists sensor_table_created_idx on sensor_table (created_at desc);
alter table sensor_table enable row level security;
-- Anon may insert (the ESP32's own anon-key POST) and read back (so the
-- rig's data is visible without a Table Editor login) -- no update/delete.
-- Postgres has no "create policy if not exists", so drop first for an
-- idempotent re-run of this script.
drop policy if exists "sensor_table anon insert" on sensor_table;
create policy "sensor_table anon insert" on sensor_table for insert to anon with check (true);
drop policy if exists "sensor_table anon read" on sensor_table;
create policy "sensor_table anon read" on sensor_table for select to anon using (true);

-- RLS with zero policies = deny-all for the anon/authenticated roles
-- PostgREST uses. Correct for this architecture: the backend talks to
-- Postgres with its own connection string (table owner, bypasses RLS
-- regardless), and nothing else — the Flutter app talks to the FastAPI
-- REST API (Section 5.3), never to Supabase directly. Without this,
-- every table here is world-readable/writable via the project's anon key.
alter table nodes enable row level security;
alter table readings enable row level security;
alter table node_state enable row level security;
alter table state_transitions enable row level security;
alter table hazards enable row level security;
alter table reports enable row level security;
alter table cell_subscriptions enable row level security;
