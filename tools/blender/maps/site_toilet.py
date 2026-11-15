"""The range's portable site toilet (RM1): a moulded plastic cabin on skids, a dark green-grey door in its frame with
three hinges and a latch, grey walls moulded with sweeping ribs, a white domed roof and a vent pipe (William's photos,
art/references/maps/william-2026-11-09/portable_site_toilet: the grey-doored and green-doored cabins; no blue, which
is Alpha's colour, and no logos). RM2: the side and back panels moulded with sweeping scoops pressed into them, each a
crescent deepest under its upper edge and running out to points well short of the corner posts, the door's raised
panel with two the same; the roof a firm moulding, a square-edged lip all round and a dome over it.

Writes assets/models/props/site_toilet.glb, one vertex-coloured mesh filling x -0.6..0.6, y -0.6..0.6, z 0..2.4
exactly (its block in range.json; Godot: x across, y up, z deep), its door towards -y (Godot's +z, the front
PropLayout turns towards the field).

Usage: python3 tools/blender/maps/site_toilet.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import range_kit as rk  # noqa: E402
from range_kit import hs  # noqa: E402

OUT = os.path.join(rk.PROPS, "site_toilet.glb")
BUDGET = 5000  # docs/CC0_ASSETS.md › Size limits: a prop (RM2: the ribs moulded round)
HW = 0.6
HIGH = 2.4
WALL = 0.565  # the walls' half width (the roof and skids reach the box)
FRONT = 0.54  # the front wall's distance from the middle: the door's handle and hinges stand proud of it to the box
EAVE = 2.12
SKID = 0.1
INSET = 0.025  # the cabin's shell stands this far inside its moulded side and back panels (RM2)
PANEL_COLS = 18  # a moulded panel's columns along it (RM2)
TIP = 0.86  # a scoop's tips, a share of the panel's half width from its middle
SCOOP_V = (0.2, 0.45, 0.68, 0.82, 0.92)  # the points across a scoop's band between its edges
BAY = 0.49  # the side and back panels' half width: between the corner posts, their edges under the posts

rk.check_colours(["loo_door", "loo_wall", "loo_frame", "loo_roof", "loo_vent", "stand_black", "zinc"], shade=0.05)


def _scoop(u: float, v: float, depth: float) -> float:
    """A moulded scoop's depth at `v` across its band (0 its lower edge, 1 its upper), `u` along it (-1..1, its tips
    at +-TIP): a long easy slope down from the lower edge to its deepest just under the upper edge, then a short steep
    wall back up, which throws the shadow line along its top (photo 1); its depth eased out to its tips."""
    env = _ease((TIP - abs(u)) / 0.35)
    if v <= 0.0 or v >= 1.0:
        return 0.0
    d = (v / 0.82) ** 1.4 if v < 0.82 else (1.0 - v) / 0.18
    return depth * env * d


def _band(u: float, zc: float, rise: float, half: float, tilt: float) -> tuple:
    """The scoop's band at `u` (-1..1): its lower and upper edge, a crescent `half` m either side of its middle line at
    its fullest, thinning to points at its tips, the line rising `rise` m along it in a sweep (photo 1's swooshes)."""
    t = (u + 1.0) * 0.5
    mid = zc + rise * (0.5 - 0.5 * math.cos(math.pi * t))
    w = half * max(0.0, 1.0 - (abs(u - tilt) / (TIP + abs(tilt))) ** 2) ** 0.7 if abs(u) < TIP else 0.0
    return mid - w, mid + w


def _panel(k: rk.Kit, axis: str, at: float, out: float, u0: float, u1: float, bands: list, mat: str,
           cols: int = PANEL_COLS) -> None:
    """A wall's face from u0 to u1 along it and up through `bands`, moulded into it: each band (z0, z1, scoop) is
    plain, or carries a scoop (zc, rise, half, tilt, depth, flip) pressed into the wall (RM2: the photos' swooshes are
    hollows in the moulding, not strips on it). `out` is the face's outward side along `axis` (+1 or -1); z1 may be a
    function of the point along the face (the door's arch). Every band shares the columns, so the face is one sheet."""
    import bmesh
    from mathutils import Vector
    us = [u0 + (u1 - u0) * i / cols for i in range(cols + 1)]
    rows = []
    for z0, z1, sc in bands:
        col_pts = []
        for u in us:
            top = z1(u) if callable(z1) else z1
            if sc is None:
                col_pts.append([(z0, 0.0), (top, 0.0)])
                continue
            zc, rise, half, tilt, depth, flip = sc
            uu = (2.0 * (u - u0) / (u1 - u0) - 1.0) * flip
            lo, hi = _band(uu, zc, rise, half, tilt)
            lo, hi = max(lo, z0 + 0.002), min(hi, top - 0.002)
            pts = [(z0, 0.0), (lo, 0.0)]
            for v in SCOOP_V:
                pts.append((lo + (hi - lo) * v, _scoop(uu, v, depth)))
            pts += [(hi, 0.0), (top, 0.0)]
            col_pts.append(pts)
        rows.append(col_pts)
    faces = []
    for col_pts in rows:
        n = len(col_pts[0])
        grid = []
        for u, pts in zip(us, col_pts):
            line = []
            for z, d in pts:
                w = at - out * d
                line.append(k.bm.verts.new(Vector((w, u, z) if axis == "x" else (u, w, z))))
            grid.append(line)
        for a, b in zip(grid, grid[1:]):
            for j in range(n - 1):
                faces.append(k.bm.faces.new((a[j], b[j], b[j + 1], a[j + 1])))
    k._faces(faces, mat)
    facing = Vector((out, 0.0, 0.0) if axis == "x" else (0.0, out, 0.0))
    probe = faces[0]
    probe.normal_update()
    if probe.normal.dot(facing) < 0.0:
        bmesh.ops.reverse_faces(k.bm, faces=faces)


def _bands(zcs: tuple, rise: float, flip: float) -> list:
    """A side or back panel's bands from the skirt to the eaves: plain, then a scoop strip for each scoop at `zcs`."""
    out = []
    z = SKID + 0.08
    for zc in zcs:
        out += [(z, zc - 0.11, None), (zc - 0.11, zc + 0.27, (zc, rise, 0.085, 0.25, 0.03, flip))]
        z = zc + 0.27
    return out + [(z, EAVE, None)]


def _face_out(k: rk.Kit, faces: list, centre: tuple) -> None:
    """Turns `faces` (a band round an outline) to face away from `centre` if they were wound the other way."""
    import bmesh
    from mathutils import Vector
    f = faces[0]
    f.normal_update()
    if f.normal.dot(f.calc_center_median() - Vector(centre)) < 0.0:
        bmesh.ops.reverse_faces(k.bm, faces=faces)


def _ease(x: float) -> float:
    x = min(max(x, 0.0), 1.0)
    return x * x * (3.0 - 2.0 * x)


def _arch(x: float) -> float:
    """The door's arched top over its square shoulders (photos 1 to 4), m above EAVE - 0.2 at x across."""
    return 0.13 * math.cos(0.5 * math.pi * x / 0.39)


def build() -> object:
    k = rk.Kit("SiteToilet")
    # Skids: two runners front to back and the base tub over them.
    for sx in (-1.0, 1.0):
        k.blk((sx * 0.52 - 0.07, -HW, 0.0), (sx * 0.52 + 0.07, HW, SKID * 0.6), "loo_frame")
        for sy in (-1.0, 1.0):
            k.blk((sx * 0.52 - 0.08, sy * 0.5 - 0.09, 0.0), (sx * 0.52 + 0.08, sy * 0.5 + 0.09, SKID * 0.8),
                  "loo_frame")
    k.prism(hs.rounded_rect(0.585, 0.585, 0.06, 4), "z", SKID * 0.6, SKID + 0.08, "loo_frame")
    # The cabin's shell: grey walls with rounded corners.
    # (RM2: its sides and back INSET inside the moulded panels laid over them below.)
    back = WALL - INSET
    k.prism([(x, y + (back - FRONT) * 0.5) for x, y in hs.rounded_rect(back, (back + FRONT) * 0.5, 0.07, 6)], "z",
            SKID + 0.08, EAVE, "loo_wall")
    # Corner posts standing proud the full height (darker), as the moulded uprights in the photos.
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            c = (sx * (WALL - 0.035), sy * (WALL - 0.035) if sy > 0 else -FRONT + 0.035)
            k.prism([(c[0] + x, c[1] + y) for x, y in hs.rounded_rect(0.045, 0.045, 0.02, 4)], "z", SKID + 0.08,
                    EAVE, "loo_frame")
    # The side and back panels between the posts, moulded with sweeping scoops (photo 1): three a side, two on the
    # back, each a crescent pressed into the wall, deepest under its upper edge, running out to points well short of
    # the posts.
    for sx in (-1.0, 1.0):
        _panel(k, "x", sx * WALL, sx, -BAY, BAY, _bands((0.36, 0.96, 1.52), 0.16, sx), "loo_wall")
    _panel(k, "y", WALL, 1.0, -BAY, BAY, _bands((0.66, 1.4), 0.13, -1.0), "loo_wall")
    # The front: the door frame (posts up to the header, never overlapping it, and the header, proud of the wall),
    # the door a little back in it, its two moulded swoops, three hinges on the left, the latch with its round
    # indicator and a pull handle on the right.
    fy = -FRONT
    k.blk((-WALL - 0.01, fy - 0.03, SKID + 0.08), (-0.39, fy, EAVE - 0.2), "loo_frame")
    k.blk((0.39, fy - 0.03, SKID + 0.08), (WALL + 0.01, fy, EAVE - 0.2), "loo_frame")
    # The header over the door, its underside following the door's arch: its ends, and a strip over each step.
    hz = EAVE - 0.2
    xs = [-0.39 + 0.78 * i / 12 for i in range(13)]
    for x0, x1 in ((-WALL - 0.01, -0.39), (0.39, WALL + 0.01)):
        k.blk((x0, fy - 0.03, hz), (x1, fy, EAVE), "loo_frame")
    for x0, x1 in zip(xs, xs[1:]):
        k.prism([(x0, hz + _arch(x0)), (x1, hz + _arch(x1)), (x1, EAVE), (x0, EAVE)], "y", fy - 0.03, fy, "loo_frame")
    k.prism([(-0.39, SKID + 0.1), (0.39, SKID + 0.1)] + [(x, hz + _arch(x)) for x in reversed(xs)], "y", fy - 0.012,
            fy, "loo_door")
    # The door's raised panel, arched like the door, its two swoops pressed into it (photo 1): its edge all round,
    # and its face moulded.
    px = [-0.36 + 0.72 * i / 12 for i in range(13)]
    door = [(-0.36, SKID + 0.14), (0.36, SKID + 0.14)] + [(x, hz - 0.06 + _arch(x) * 0.9) for x in reversed(px)]
    edge = k.loft([[(x, fy - 0.012, z) for x, z in door], [(x, fy - 0.022, z) for x, z in door]], "loo_door",
                  cap0=False, cap1=False)
    _face_out(k, edge, (0.0, fy, 1.1))
    _panel(k, "y", fy - 0.022, -1.0, -0.36, 0.36,
           [(SKID + 0.14, 0.45, None), (0.45, 0.72, (0.52, 0.1, 0.04, 0.2, 0.009, 1.0)), (0.72, 1.52, None),
            (1.52, 1.76, (1.6, 0.08, 0.035, 0.2, 0.009, -1.0)), (1.76, lambda x: hz - 0.06 + _arch(x) * 0.9, None)],
           "loo_door", cols=12)
    for z in (0.35, 1.1, 1.8):
        k.blk((-0.41, fy - 0.045, z - 0.06), (-0.355, fy - 0.022, z + 0.06), "stand_black")
        k.cyl((-0.383, fy - 0.045, z - 0.075), 0.009, 0.15, "stand_black", seg=6)
    k.cyl((0.3, fy - 0.037, 1.12), 0.035, 0.015, "stand_black", seg=16, axis="y")
    k.cyl((0.3, fy - 0.043, 1.12), 0.022, 0.006, "loo_vent", seg=16, axis="y")
    k.blk((0.27, fy - 0.06, 0.88), (0.33, fy - 0.022, 0.92), "stand_black")
    k.blk((0.31, fy - 0.06, 0.88), (0.33, fy - 0.022, 1.02), "stand_black")
    # Vents high on the sides.
    for sx in (-1.0, 1.0):
        k.prism(hs.rounded_rect(0.12, 0.04, 0.03, 2), "x", sx * WALL - 0.004, sx * WALL + 0.004, "loo_vent",
                offset=(0.0, 0.0, 1.98))
    # The roof: a white dome over the eaves (it overhangs to the box), and the vent pipe at the back right (its cap
    # the top of the box).
    rings = []
    # (RM2: moulded firm: a square-edged lip 8 cm deep all round over the walls, a crisp shoulder, then a dome
    # rising as a quarter ellipse to a small flat crown, its corners rounded in 7 steps.)
    for z, s, r in ((EAVE - 0.06, HW - 0.03, 0.06), (EAVE - 0.06, HW, 0.08), (EAVE + 0.02, HW, 0.08),
                    (EAVE + 0.032, HW - 0.014, 0.085), (EAVE + 0.06, 0.562, 0.09)) + tuple(
            (EAVE + 0.06 + 0.15 * math.sin(math.radians(a)), 0.562 * math.cos(math.radians(a)),
             min(0.1, 0.562 * math.cos(math.radians(a)) * 0.6)) for a in (25.0, 45.0, 62.0, 76.0)):
        rings.append([(x, y, z) for x, y in hs.rounded_rect(s, s, r, 6)])
    k.loft(rings, "loo_roof")
    k.cyl((0.32, 0.32, EAVE + 0.1), 0.035, HIGH - 0.02 - EAVE - 0.1, "loo_vent", seg=16)
    k.lathe([(0.0, 0.0), (0.0, 0.05), (0.012, 0.05), (0.02, 0.04), (0.02, 0.0)], "loo_vent", segments=16,
            centre=(0.32, 0.32, HIGH - 0.02), axis="z")
    ob = k.build()
    rk.finish(ob, angle=math.radians(45.0))
    rk.bake(ob, jitter={}, seed=3)
    rk.occlude(ob, strength=0.5, distance=0.12)
    rk.fit_box(ob, (-HW, -HW, 0.0), (HW, HW, HIGH))
    return ob


def main() -> None:
    rk.reset()
    ob = build()
    n = rk.report([ob])
    if n > BUDGET:
        raise SystemExit("over budget")
    rk.export(OUT, [ob])
    print("wrote", os.path.relpath(OUT, rk.ROOT))
    if "--render" in sys.argv:
        import range_render as rr
        rr.render_sheet([
            ("Front quarter (door)", (-2.2, -3.4, 1.8), (0.0, 0.0, 1.15), 35),
            ("Rear quarter (vent pipe, moulded swooshes)", (2.6, 3.2, 2.2), (0.0, 0.0, 1.15), 35),
            ("Door: hinges, latch, handle", (0.9, -1.9, 1.3), (0.0, -0.6, 1.1), 40),
            ("Side", (4.0, 0.0, 1.3), (0.0, 0.0, 1.2), 35),
            ("Roof and vent", (-1.4, -1.8, 3.4), (0.0, 0.0, 2.2), 35),
            ("From 10 m", (-3.0, -9.5, 1.6), (0.0, 0.0, 1.2), 40),
        ], sys.argv[sys.argv.index("--render") + 1],
            "Site toilet (Range map prop, RM2 rebuild): swooshes pressed into the panels, a firm roof with a lip")


if __name__ == "__main__":
    main()
