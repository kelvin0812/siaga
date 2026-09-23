"""
Downloads real historical water-level and rainfall telemetry from JPS
(Jabatan Pengairan dan Saliran) Malaysia's Public Infobanjir system, for
training the Tier 2 model (build brief Section 7: "Train Tier 2 on
historical public rainfall and water-level records for Malaysian
catchments").

There is no documented public API or bulk-download endpoint for this data
(Public Infobanjir at https://publicinfobanjir.water.gov.my is a live
monitoring dashboard, not an open-data portal). The query endpoints used
here were found by reverse-engineering the dashboard's own network
requests when driving its date-range/"Show Options" panel — see
docs/nexus-log.md for exactly how they were found and verified. This is
still real government telemetry (the same data the dashboard itself
displays), just accessed the same way the dashboard's own JavaScript
does, rather than through a maintained/versioned API.

Stations were selected as combined water-level + rainfall gauges (the
station ID is identical for both readings at these locations) across
different sub-catchments in Perak, favouring RHN ("Rangkaian Hidrologi
Negara" / national hydrological network) stations where available since
they appeared more consistently populated during manual spot checks.
"""
from __future__ import annotations

import json
import re
import time
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path

import requests

RAW_DIR = Path(__file__).parent / "data" / "raw"

WATER_LEVEL_URL = (
    "https://publicinfobanjir.water.gov.my/wp-content/themes/enlighten/"
    "query/searchresultwaterleveldtlead.php"
)
RAINFALL_URL = (
    "https://publicinfobanjir.water.gov.my/wp-content/themes/enlighten/"
    "query/searchresultrainfalldthourlylead.php"
)

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) SIAGA-training-data-fetch/1.0",
}


@dataclass(frozen=True)
class Station:
    station_id: str
    name: str
    normal: float
    alert: float
    warning: float
    danger: float


# Combined water-level + rainfall gauges (same station_id reports both) —
# found via backend/app's own site.gov.my dashboard, one per sub-basin,
# spanning several districts in Perak for catchment diversity.
STATIONS = [
    Station("5207403_", "Sg. Selama di Kg. Gua Petai", 12.30, 13.50, 14.00, 14.50),
    Station("25789", "Sg. Ijok di Titi Ijok Perak (RHN)", 9.80, 10.50, 11.70, 12.70),
    Station("4907020_", "Sg. Kurau di Bt. 14 Batu Kurau", 23.50, 24.00, 24.70, 25.40),
    Station("5007020_", "Sg. Kurau di Pondok Tanjung", 11.20, 13.50, 13.80, 14.20),
    Station("25969", "Sg. Kampar di Kg. Baru Kuala Dipang (RHN)", 21.41, 22.00, 22.20, 23.40),
    Station("27181", "Emp. Ulu Kinta (RHN)", 243.50, 246.50, 248.00, 249.50),
    Station("25968", "Sg. Chemor di Kg. Cik Zainal (RHN)", 73.65, 74.20, 74.80, 75.50),
    Station("25786", "Sg. Perak di Pekan Manong (RHN)", 24.42, 25.00, 25.60, 26.85),
    Station("5108005_", "Sg. Ijok di Bekalan Ijok", 29.00, 35.00, 35.30, 35.50),
]


def _fetch_month(url: str, station_id: str, year: int, month: int) -> dict:
    start = datetime(year, month, 1)
    end = (start.replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(minutes=5)
    params = {
        "station": station_id,
        "from": start.strftime("%d/%m/%Y %H:%M"),
        "to": end.strftime("%d/%m/%Y %H:%M"),
        "datafreq": "15",
    }
    resp = requests.get(url, params=params, headers=HEADERS, timeout=30)
    resp.raise_for_status()
    # The rainfall endpoint (at least) occasionally emits a bare empty
    # value for a numeric field — e.g. `"clean":,` — instead of a number,
    # null, or omitting the field. Not valid JSON; a real artifact of
    # this government API, not something introduced here. `:null` is the
    # closest honest repair (matches how other missing readings in the
    # same payload are represented, e.g. "raw":-9999 vs an omitted key).
    repaired = re.sub(r":(?=[,}])", ":null", resp.text)
    return json.loads(repaired)


def fetch_station_history(station: Station, months: list[tuple[int, int]]) -> None:
    station_dir = RAW_DIR / station.station_id.rstrip("_")
    station_dir.mkdir(parents=True, exist_ok=True)

    for kind, url in (("water_level", WATER_LEVEL_URL), ("rainfall", RAINFALL_URL)):
        for year, month in months:
            out_path = station_dir / f"{kind}_{year:04d}-{month:02d}.json"
            if out_path.exists():
                continue  # resumable: skip months already downloaded
            try:
                data = _fetch_month(url, station.station_id, year, month)
            except Exception as e:  # noqa: BLE001 — log and keep going, one bad month shouldn't abort the run
                print(f"  FAILED {kind} {station.name} {year}-{month:02d}: {e}")
                continue
            out_path.write_text(json.dumps(data), encoding="utf-8")
            valid = sum(
                1
                for v in data.get("values", [])
                if v.get("clean") not in ("-9999", -9999)
            )
            print(f"  {kind} {station.name} {year}-{month:02d}: {valid} valid readings")
            time.sleep(0.3)  # be a polite scraper — this is a live government dashboard


def last_n_months(n: int, from_date: datetime | None = None) -> list[tuple[int, int]]:
    from_date = from_date or datetime.now()
    months = []
    y, m = from_date.year, from_date.month
    for _ in range(n):
        months.append((y, m))
        m -= 1
        if m == 0:
            m = 12
            y -= 1
    return list(reversed(months))


def main() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    months = last_n_months(12)
    print(f"Fetching {len(STATIONS)} stations x {len(months)} months x 2 (level + rainfall)...")
    for station in STATIONS:
        print(f"Station {station.station_id} — {station.name}")
        fetch_station_history(station, months)


if __name__ == "__main__":
    main()
