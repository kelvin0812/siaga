import pytest

from shared.frame import (
    FLAG_ENCLOSURE_HUMIDITY,
    FLAG_LOW_BATTERY,
    FLAG_TIER1_ANOMALY,
    FRAME_SIZE,
    UplinkFrame,
    level_mm_to_height_above_datum,
)


def make_frame(**overrides) -> UplinkFrame:
    defaults = dict(
        node_id=1,
        seq=0,
        level_mm=1200,
        tilt_x=0,
        tilt_y=0,
        soil_pct=40,
        rain_tips=0,
        temp_c=28,
        rh_pct=70,
        vbat_cv=10,
        flags=0,
    )
    defaults.update(overrides)
    return UplinkFrame(**defaults)


def test_frame_is_exactly_12_bytes():
    assert len(make_frame().to_bytes()) == FRAME_SIZE


def test_round_trip_preserves_all_fields():
    original = make_frame(
        node_id=42,
        seq=255,
        level_mm=4321,
        tilt_x=-12,
        tilt_y=127,
        soil_pct=88,
        rain_tips=5,
        temp_c=-3,
        rh_pct=99,
        vbat_cv=60,
        flags=0b10100101,
    )
    decoded = UplinkFrame.from_bytes(original.to_bytes())
    assert decoded == original


@pytest.mark.parametrize(
    "field,value",
    [
        ("node_id", 0),
        ("node_id", 255),
        ("seq", 0),
        ("seq", 255),
        ("level_mm", 0),
        ("level_mm", 65535),
        ("tilt_x", -128),
        ("tilt_x", 127),
        ("tilt_y", -128),
        ("tilt_y", 127),
        ("temp_c", -128),
        ("temp_c", 127),
    ],
)
def test_field_boundary_values_round_trip(field, value):
    original = make_frame(**{field: value})
    decoded = UplinkFrame.from_bytes(original.to_bytes())
    assert getattr(decoded, field) == value


def test_from_bytes_rejects_wrong_length():
    with pytest.raises(ValueError):
        UplinkFrame.from_bytes(b"\x00" * 11)
    with pytest.raises(ValueError):
        UplinkFrame.from_bytes(b"\x00" * 13)


def test_flag_bit_helpers_are_independent():
    frame = make_frame(flags=FLAG_TIER1_ANOMALY | FLAG_LOW_BATTERY)
    assert frame.tier1_anomaly is True
    assert frame.low_battery is True
    assert frame.enclosure_humidity_alarm is False


@pytest.mark.parametrize("boot_cause", [0, 1, 2, 3])
def test_boot_cause_bits_3_4_decode_independent_of_other_flags(boot_cause):
    flags = (boot_cause << 3) | FLAG_TIER1_ANOMALY | FLAG_ENCLOSURE_HUMIDITY
    frame = make_frame(flags=flags)
    assert frame.boot_cause == boot_cause
    assert frame.tier1_anomaly is True
    assert frame.enclosure_humidity_alarm is True


def test_vbat_volts_offset_from_3v():
    assert make_frame(vbat_cv=0).vbat_volts == pytest.approx(3.00)
    assert make_frame(vbat_cv=85).vbat_volts == pytest.approx(3.85)


def test_level_mm_inversion_rising_water_increases_height():
    """
    level_mm is a DOWN distance to the water surface, so it shrinks as
    water rises. This test pins the exact inversion point called out in
    Section 5.1 as the most likely source of a sign-flip bug.
    """
    datum_mm = 2000
    height_when_low = level_mm_to_height_above_datum(1800, datum_mm)
    height_when_high = level_mm_to_height_above_datum(600, datum_mm)
    assert height_when_high > height_when_low
    assert height_when_low == pytest.approx(0.2)
    assert height_when_high == pytest.approx(1.4)


def test_level_mm_at_datum_is_zero_height():
    assert level_mm_to_height_above_datum(2000, 2000) == pytest.approx(0.0)
