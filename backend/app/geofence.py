"""
Geofence service (build brief Section 6.3): resolve a hazard polygon to a
set of H3 cells at the handset's fixed resolution 8 (Section 3.1), plus a
configurable buffer ring so people approaching the area are alerted too.

The server only ever deals in cell IDs from this point on — it never
receives or needs a handset's coordinates (Section 3.1).
"""
from __future__ import annotations

import h3

H3_RESOLUTION = 8

LatLon = tuple[float, float]


def resolve_hazard_cells(
    polygon: list[LatLon], buffer_rings: int = 0
) -> frozenset[str]:
    """
    polygon: exterior ring vertices as (lat, lon), at least 3 points.
    buffer_rings: 0 = exactly the hazard footprint; N = also include every
    cell within N grid steps of any footprint cell, so people approaching
    the area (not yet inside it) still get the advisory.
    """
    if len(polygon) < 3:
        raise ValueError("polygon needs at least 3 vertices")
    if buffer_rings < 0:
        raise ValueError("buffer_rings must be >= 0")

    shape = h3.LatLngPoly(polygon)
    base_cells = h3.polygon_to_cells(shape, res=H3_RESOLUTION)

    if buffer_rings == 0:
        return frozenset(base_cells)

    buffered: set[str] = set()
    for cell in base_cells:
        buffered.update(h3.grid_disk(cell, buffer_rings))
    return frozenset(buffered)


def cell_for_point(lat: float, lon: float) -> str:
    """What the handset itself computes locally (Section 3.1) — exposed
    here only for tests and for seeding node fixtures, never called with
    data that reached the backend from a user's device."""
    return h3.latlng_to_cell(lat, lon, H3_RESOLUTION)


def cells_around_point(lat: float, lon: float, buffer_rings: int) -> frozenset[str]:
    """
    Alert footprint for a node-triggered escalation before any authority
    has drawn a hazard polygon: a disk of cells around the node's fixed
    install location. A drawn polygon (resolve_hazard_cells) should
    supersede this once the dashboard supports authoring one.
    """
    center = cell_for_point(lat, lon)
    if buffer_rings <= 0:
        return frozenset({center})
    return frozenset(h3.grid_disk(center, buffer_rings))
