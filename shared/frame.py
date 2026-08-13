"""
SIAGA LoRa uplink frame codec — single source of truth for the 12-byte packed
binary layout (build brief Section 5.1). The gateway firmware's C++ struct
must be hand-mirrored to match this exactly; if you change a field here,
update firmware/gateway/src/frame.h and recompute airtime (Section 3.4).
"""
from __future__ import annotations

import struct
from dataclasses import dataclass

FRAME_SIZE = 12

# little-endian: uint8 node_id, uint8 seq, uint16 level_mm, int8 tilt_x,
# int8 tilt_y, uint8 soil_pct, uint8 rain_tips, int8 temp_c, uint8 rh_pct,
# uint8 vbat_cv, uint8 flags
_STRUCT = struct.Struct("<BBHbbBBbBBB")

FLAG_TIER1_ANOMALY = 1 << 0
FLAG_ENCLOSURE_HUMIDITY = 1 << 1
FLAG_LOW_BATTERY = 1 << 2
# bits 3-4: boot cause (0-3), bits 5-7: reserved
_BOOT_CAUSE_SHIFT = 3
_BOOT_CAUSE_MASK = 0b11


@dataclass(frozen=True, slots=True)
class UplinkFrame:
    node_id: int
    seq: int
    level_mm: int
    tilt_x: int
    tilt_y: int
    soil_pct: int
    rain_tips: int
    temp_c: int
    rh_pct: int
    vbat_cv: int
    flags: int

    @property
    def tier1_anomaly(self) -> bool:
        return bool(self.flags & FLAG_TIER1_ANOMALY)

    @property
    def enclosure_humidity_alarm(self) -> bool:
        return bool(self.flags & FLAG_ENCLOSURE_HUMIDITY)

    @property
    def low_battery(self) -> bool:
        return bool(self.flags & FLAG_LOW_BATTERY)

    @property
    def boot_cause(self) -> int:
        return (self.flags >> _BOOT_CAUSE_SHIFT) & _BOOT_CAUSE_MASK

    @property
    def vbat_volts(self) -> float:
        return 3.00 + self.vbat_cv / 100.0

    def to_bytes(self) -> bytes:
        return _STRUCT.pack(
            self.node_id,
            self.seq,
            self.level_mm,
            self.tilt_x,
            self.tilt_y,
            self.soil_pct,
            self.rain_tips,
            self.temp_c,
            self.rh_pct,
            self.vbat_cv,
            self.flags,
        )

    @classmethod
    def from_bytes(cls, raw: bytes) -> "UplinkFrame":
        if len(raw) != FRAME_SIZE:
            raise ValueError(f"expected {FRAME_SIZE} bytes, got {len(raw)}")
        fields = _STRUCT.unpack(raw)
        return cls(*fields)


def level_mm_to_height_above_datum(level_mm: int, datum_mm: int) -> float:
    """
    Convert the raw down-looking ultrasonic distance to a water height above
    a fixed datum. level_mm is distance from transducer DOWN to the water
    surface, so it DECREASES as water rises — this is the one and only place
    that inversion should be handled; everything above this call must work
    in height, never in raw level_mm, per build brief Section 5.1.
    """
    return (datum_mm - level_mm) / 1000.0
