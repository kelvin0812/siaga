import h3
import pytest

from backend.app.geofence import H3_RESOLUTION, cell_for_point, resolve_hazard_cells

# A square around a point in Taiping, Perak, sized well above a resolution-8
# cell's ~461 m edge so polygon_to_cells' center-containment reliably finds
# cells inside it (a tighter square can legitimately resolve to zero cells).
CENTER = (4.8500, 100.7400)
SQUARE = [
    (4.8400, 100.7300),
    (4.8400, 100.7500),
    (4.8600, 100.7500),
    (4.8600, 100.7300),
]


def test_resolve_hazard_cells_covers_the_polygon_interior():
    cells = resolve_hazard_cells(SQUARE, buffer_rings=0)
    assert len(cells) > 0
    center_cell = cell_for_point(*CENTER)
    assert center_cell in cells


def test_all_returned_cells_are_resolution_8():
    cells = resolve_hazard_cells(SQUARE, buffer_rings=0)
    for cell in cells:
        assert h3.get_resolution(cell) == H3_RESOLUTION


def test_buffer_ring_strictly_grows_the_cell_set():
    base = resolve_hazard_cells(SQUARE, buffer_rings=0)
    buffered = resolve_hazard_cells(SQUARE, buffer_rings=1)
    assert buffered.issuperset(base)
    assert len(buffered) > len(base)


def test_larger_buffer_ring_grows_monotonically():
    ring0 = resolve_hazard_cells(SQUARE, buffer_rings=0)
    ring1 = resolve_hazard_cells(SQUARE, buffer_rings=1)
    ring2 = resolve_hazard_cells(SQUARE, buffer_rings=2)
    assert len(ring0) <= len(ring1) <= len(ring2)
    assert ring1.issubset(ring2)


def test_buffered_cells_are_adjacent_to_the_footprint_not_arbitrary():
    base = resolve_hazard_cells(SQUARE, buffer_rings=0)
    buffered = resolve_hazard_cells(SQUARE, buffer_rings=1)
    new_cells = buffered - base
    for cell in new_cells:
        # every added cell must be within 1 grid step of some base cell
        assert any(h3.grid_distance(cell, b) <= 1 for b in base)


def test_rejects_degenerate_polygon():
    with pytest.raises(ValueError):
        resolve_hazard_cells([(4.85, 100.74), (4.86, 100.75)], buffer_rings=0)


def test_rejects_negative_buffer_rings():
    with pytest.raises(ValueError):
        resolve_hazard_cells(SQUARE, buffer_rings=-1)


def test_cell_for_point_matches_h3_directly():
    lat, lon = CENTER
    assert cell_for_point(lat, lon) == h3.latlng_to_cell(lat, lon, H3_RESOLUTION)


def test_disjoint_polygons_far_apart_produce_disjoint_cells():
    far_square = [
        (5.4000, 100.3000),
        (5.4000, 100.3040),
        (5.4040, 100.3040),
        (5.4040, 100.3000),
    ]
    near = resolve_hazard_cells(SQUARE, buffer_rings=0)
    far = resolve_hazard_cells(far_square, buffer_rings=0)
    assert near.isdisjoint(far)
