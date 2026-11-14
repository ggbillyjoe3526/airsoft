"""The range's portable site toilet (RM1): a moulded plastic cabin on skids, a dark green-grey door in its frame with
three hinges and a latch, grey walls moulded with sweeping ribs, a white domed roof and a vent pipe (William's photos,
art/references/maps/william-2026-11-09/portable_site_toilet: the grey-doored and green-doored cabins; no blue, which
is Alpha's colour, and no logos).

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
BUDGET = 2500
HW = 0.6
HIGH = 2.4
WALL = 0.565  # the walls' half width (the roof and skids reach the box)
FRONT = 0.54  # the front wall's distance from the middle: the door's handle and hinges stand proud of it to the box
EAVE = 2.12
SKID = 0.1

rk.check_colours(["loo_door", "loo_wall", "loo_frame", "loo_roof", "loo_vent", "stand_black", "zinc"], shade=0.05)


def _wave(k: rk.Kit, axis: str, at: float, out: float, u0: float, u1: float, z0: float, amp: float, mat: str,
          width: float = 0.05) -> None:
    """A moulded rib `width` tall sweeping from u0 to u1 on a wall facing along `axis` (x or y) at `at`, swelling
    `out` proud with sloped flanks (moulded into the wall, not a strip on it), rising `amp` along it in an S."""
    import bmesh
    from mathutils import Vector
    n = 10
    rings = []
    for i in range(n + 1):
        t = i / n
        u = u0 + (u1 - u0) * t
        z = z0 + amp * (0.5 - 0.5 * math.cos(math.pi * t))
        ring = []
        for d, dz in ((0.0, 0.0), (out * 0.55, width * 0.06), (out, width * 0.2), (out, width * 0.8),
                      (out * 0.55, width * 0.94), (0.0, width)):
            ring.append((at + d, u, z + dz) if axis == "x" else (u, at + d, z + dz))
        rings.append(ring)
    faces = k.loft(rings, mat, closed=False)
    # Its faces look out of the wall, whichever way the loft wound them.
    facing = Vector((1.0, 0.0, 0.0) if axis == "x" else (0.0, 1.0, 0.0)) * math.copysign(1.0, out)
    mid = faces[len(faces) // 2]
    mid.normal_update()
    if mid.normal.dot(facing) < 0.0:
        bmesh.ops.reverse_faces(k.bm, faces=faces)


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
    k.prism(hs.rounded_rect(0.585, 0.585, 0.06, 2), "z", SKID * 0.6, SKID + 0.08, "loo_frame")
    # The cabin's shell: grey walls with rounded corners.
    mid = (WALL - FRONT) * 0.5
    k.prism([(x, y + mid) for x, y in hs.rounded_rect(WALL, (WALL + FRONT) * 0.5, 0.07, 3)], "z", SKID + 0.08, EAVE,
            "loo_wall")
    # Corner posts standing proud the full height (darker), as the moulded uprights in the photos.
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            c = (sx * (WALL - 0.035), sy * (WALL - 0.035) if sy > 0 else -FRONT + 0.035)
            k.prism([(c[0] + x, c[1] + y) for x, y in hs.rounded_rect(0.045, 0.045, 0.02, 2)], "z", SKID + 0.08,
                    EAVE, "loo_frame")
    # The sides' sweeping ribs (photos 1 and 2), three a side, and two on the back.
    for sx in (-1.0, 1.0):
        at = sx * WALL
        for i, z0 in enumerate((0.45, 1.05, 1.6)):
            _wave(k, "x", at, sx * 0.035, -0.42 * sx, 0.42 * sx, z0, 0.2, "loo_wall", 0.1)
        # A round moulded boss low on each side (photo 2's circles).
        k.cyl((at if sx > 0 else at - 0.012, 0.2, 0.62), 0.16, 0.012, "loo_wall", seg=20, axis="x")
    for z0 in (0.7, 1.45):
        _wave(k, "y", WALL, 0.035, -0.42, 0.42, z0, 0.16, "loo_wall", 0.1)
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
    # The door's raised panel, arched like the door.
    px = [-0.36 + 0.72 * i / 12 for i in range(13)]
    door = [(-0.36, SKID + 0.14), (0.36, SKID + 0.14)] + [(x, hz - 0.06 + _arch(x) * 0.9) for x in reversed(px)]
    k.prism(door, "y", fy - 0.022, fy - 0.012, "loo_door")
    _wave(k, "y", fy - 0.022, -0.01, -0.3, 0.3, 0.55, 0.12, "loo_frame", 0.035)
    _wave(k, "y", fy - 0.022, -0.01, 0.3, -0.3, 1.6, 0.1, "loo_frame", 0.035)
    for z in (0.35, 1.1, 1.8):
        k.blk((-0.41, fy - 0.045, z - 0.06), (-0.355, fy - 0.022, z + 0.06), "stand_black")
        k.cyl((-0.383, fy - 0.045, z - 0.075), 0.009, 0.15, "stand_black", seg=6)
    k.cyl((0.3, fy - 0.037, 1.12), 0.035, 0.015, "stand_black", seg=10, axis="y")
    k.cyl((0.3, fy - 0.043, 1.12), 0.022, 0.006, "loo_vent", seg=10, axis="y")
    k.blk((0.27, fy - 0.06, 0.88), (0.33, fy - 0.022, 0.92), "stand_black")
    k.blk((0.31, fy - 0.06, 0.88), (0.33, fy - 0.022, 1.02), "stand_black")
    # Vents high on the sides.
    for sx in (-1.0, 1.0):
        k.prism(hs.rounded_rect(0.12, 0.04, 0.03, 2), "x", sx * WALL - 0.004, sx * WALL + 0.004, "loo_vent",
                offset=(0.0, 0.0, 1.98))
    # The roof: a white dome over the eaves (it overhangs to the box), and the vent pipe at the back right (its cap
    # the top of the box).
    rings = []
    for z, s, r in ((EAVE - 0.04, HW, 0.08), (EAVE + 0.04, HW, 0.08), (EAVE + 0.12, 0.56, 0.12),
                    (EAVE + 0.18, 0.47, 0.16), (EAVE + 0.21, 0.32, 0.18)):
        rings.append([(x, y, z) for x, y in hs.rounded_rect(s, s, r, 3)])
    k.loft(rings, "loo_roof")
    k.cyl((0.32, 0.32, EAVE + 0.1), 0.035, HIGH - 0.02 - EAVE - 0.1, "loo_vent", seg=10)
    k.cyl((0.32, 0.32, HIGH - 0.02), 0.05, 0.02, "loo_vent", seg=10)
    ob = k.build()
    rk.finish(ob, angle=math.radians(45.0))
    rk.bake(ob, jitter={}, seed=3)
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
            ("Rear quarter (vent pipe, ribs)", (2.6, 3.2, 2.2), (0.0, 0.0, 1.15), 35),
            ("Door: hinges, latch, handle", (0.9, -1.9, 1.3), (0.0, -0.6, 1.1), 40),
            ("Side", (4.0, 0.0, 1.3), (0.0, 0.0, 1.2), 35),
            ("Roof and vent", (-1.4, -1.8, 3.4), (0.0, 0.0, 2.2), 35),
            ("From 10 m", (-3.0, -9.5, 1.6), (0.0, 0.0, 1.2), 40),
        ], sys.argv[sys.argv.index("--render") + 1],
            "RM1 site toilet (map prop): from William's portable toilet photos")


if __name__ == "__main__":
    main()
