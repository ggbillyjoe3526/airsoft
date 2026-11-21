"""Subway's spoil skips (SM4, model 6): a side-tipping skip wagon from the owner's photos
(art/references/maps/subway/06-skip-flat-wagon): a deep steel tub flaring from a rounded bottom to a rolled rim, its
ends sloped as well as its sides, stiffened by a rail round its middle and flat-bar ribs down its sides, riveted along
its corner seams, a lifting lug with a bail at each top corner, a grab handle each side; hung on trunnions in an A-frame
cradle at each end (flanged plates, a capped bearing cup, gussets at the feet) of a low channel-steel frame on four
small flanged wheels. Under the frame: axle boxes in horn guides under short leaf springs, brake blocks on the treads
and a hand lever down one side; a cast central buffer with its coupling pin and link at each end. A tipping catch and
its chain at one end. Full of spoil heaped over the rim: clay in small facets with broken concrete, brick ends, stones
and a bent bar of rusty rebar in it. Dark grey with rust coming through; no lettering.

SQ1 (2026-11-21) rebuilt it finer: the raised frame shows the springs and the wheels, the tub's corners are rounder,
and the spoil is many small dark facets and varied lumps instead of a few big pale ones (it read as a lump in game).

Its blocks (three on the south track, 2 x 2 m and 2.7 m high, data/maps/subway.json) are centred on the track, so
its wheels stand on the station's running rails (works_kit.running_rails); the tub's rim is as wide as the box, the
frame outside the wheels.

Writes assets/models/props/skip_wagon.glb, one vertex-coloured mesh filling x -1..1 (along the track), y -1..1,
z 0..2.7 exactly (Godot: x along, y up, z across).

Usage: python3 -I tools/blender/maps/skip_wagon.py [--render <sheet.jpg>]
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

NAME = "skip_wagon"
BUDGET = 5000
HL, HD, HIGH = 1.0, 1.0, 2.7   # the box: half its length, half its depth, its height

# The spoil's own paints (sRGB, low saturation: off the teams' hues): a dull brick, a pale stone
wk.PAINT["brick_dull"] = 0x6a5452
wk.PAINT["stone_pale"] = 0x8a8680

WHEEL_R = 0.3
AXLE_X = 0.5
FRAME_Y = 0.88                 # the frame's half width (outside its channels), outside the wheels
FRAME_LO, FRAME_HI = 0.16, 0.36   # the solebars' foot and top over the axles (room for the springs)
PIVOT_Z = 1.62                 # the trunnions
RIM_Z = 2.26                   # the tub's rim
RIM_R = 0.032                  # the rolled rim's radius
CRADLE_X = 0.78                # the cradles' inner face
SEG = 12
# The tub by height: (z, half length, half width) from its rounded bottom to the rim's underside.
TUB = [(1.0, 0.6, 0.14), (1.015, 0.605, 0.3), (1.045, 0.61, 0.42), (1.1, 0.62, 0.52), (1.17, 0.63, 0.6),
       (1.26, 0.645, 0.67), (1.42, 0.68, 0.74), (1.8, 0.77, 0.89), (RIM_Z - RIM_R, 0.94, HD - RIM_R)]
CORNER = 0.08                  # the tub's corners, rounded in plan
RIBS = (-0.36, 0.36)           # the side ribs' x (the handles sit between them and the ends)
LUMPS = 20                     # broken concrete, brick, stones in the spoil


def ring(z: float, hx: float, hy: float, r: float, steps: int = 4) -> list:
    """A rounded rectangle in plan at height z, `steps` points round each corner."""
    r = min(r, hx * 0.5, hy * 0.5)
    pts = []
    for cx, cy, a0 in ((hx - r, hy - r, 0.0), (-hx + r, hy - r, 90.0), (-hx + r, -hy + r, 180.0),
                       (hx - r, -hy + r, 270.0)):
        for i in range(steps):
            a = math.radians(a0 + 90.0 * i / (steps - 1))
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a), z))
    return pts


def tub_at(z: float) -> tuple:
    """The tub's half length and half width at height z (between TUB's levels)."""
    for (z0, x0, y0), (z1, x1, y1) in zip(TUB, TUB[1:]):
        if z0 <= z <= z1:
            t = (z - z0) / (z1 - z0)
            return x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
    return TUB[-1][1], TUB[-1][2]


def chunk(k: wk.Kit, centre: tuple, size: tuple, mat: str, rng: random.Random) -> None:
    """A broken block (concrete, a brick end): a box with its corners knocked about, turned any way."""
    bm = k.bm
    vs = []
    for z in (-1.0, 1.0):
        for y in (-1.0, 1.0):
            for x in (-1.0, 1.0):
                vs.append(bm.verts.new(Vector((x * size[0] * 0.5 * rng.uniform(0.72, 1.1),
                                               y * size[1] * 0.5 * rng.uniform(0.72, 1.1),
                                               z * size[2] * 0.5 * rng.uniform(0.72, 1.1)))))
    faces = [bm.faces.new([vs[i] for i in q]) for q in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3),
                                                         (0, 4, 6, 2), (1, 3, 7, 5))]
    turn = Euler((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), rng.uniform(0.0, math.tau))).to_matrix().to_4x4()
    k.transform(faces, Matrix.Translation(Vector(centre)) @ turn)
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    k._faces(faces, mat)


def pebble(k: wk.Kit, centre: tuple, r: float, mat: str, rng: random.Random, squash: float = 0.7) -> None:
    """A rounded stone: an icosahedron, its corners pushed in and out, flattened by `squash`, turned any way."""
    bm = k.bm
    made = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)["verts"]
    for v in made:
        v.co = Vector((v.co.x * rng.uniform(0.8, 1.15), v.co.y * rng.uniform(0.8, 1.15),
                       v.co.z * squash * rng.uniform(0.85, 1.1)))
    faces = list({f for v in made for f in v.link_faces})
    turn = Euler((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), rng.uniform(0.0, math.tau))).to_matrix().to_4x4()
    k.transform(faces, Matrix.Translation(Vector(centre)) @ turn)
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    k._faces(faces, mat)


def leaf_spring(k: wk.Kit, x: float, y: float, z_mid: float, z_end: float, half: float, mat: str) -> None:
    """A short leaf spring seen side on (along x, `half` either side of x): three leaves stepping shorter downwards,
    cambered from its buckle at z_mid up to its eyes at z_end, a buckle round its middle."""
    for i, frac in enumerate((1.0, 0.6)):
        h = half * frac
        t = 0.014
        top = [(x + h * u, z_mid - i * t + (z_end - z_mid) * u * u + t) for u in (-1.0, 0.0, 1.0)]
        bot = [(px, pz - t) for px, pz in reversed(top)]
        k.prism(top + bot, "y", y - 0.03, y + 0.03, mat)
    k.blk((x - 0.03, y - 0.036, z_mid - 0.05), (x + 0.03, y + 0.036, z_mid + 0.02), mat)  # the buckle


def build() -> object:
    k = wk.Kit(NAME)
    rng = random.Random(61)
    rail_top = k.running_rails(-HL, HL)
    k.mark("track")
    zc = rail_top + WHEEL_R
    f0, f1 = zc + FRAME_LO, zc + FRAME_HI
    for x in (-AXLE_X, AXLE_X):
        k.wheelset(x, wk.WHEEL_IN, zc, WHEEL_R, 0.07, seg=SEG)
        for s in (-1.0, 1.0):
            y = s * (FRAME_Y - 0.045)
            k.axle_box(x, y, zc, 0.15, 0.16, 0.07, "frame_black")
            k.cyl((x, y + s * 0.035, zc - 0.01), 0.045, s * 0.015, "steel_bare", seg=6, axis="y")  # its lid
            for dx in (-1.0, 1.0):  # the horn guides either side of the box, up to the solebar
                k.blk((x + dx * 0.075 - 0.015, y - 0.025, zc - 0.1), (x + dx * 0.075 + 0.015, y + 0.025, f0),
                      "frame_black")
            leaf_spring(k, x, y, zc + 0.095, f0 - 0.03, 0.2, "frame_black")
            for dx in (-0.2, 0.2):  # the spring's hangers from the solebar's foot
                k.blk((x + dx - 0.018, y - 0.03, f0 - 0.05), (x + dx + 0.018, y + 0.03, f0 + 0.01), "frame_black")
    k.mark("wheels")
    # The frame: two channel solebars riveted, headstocks at the ends, cross members, a cast central buffer with
    # its coupling pin and link at each end.
    for s in (-1.0, 1.0):
        y0, y1 = sorted((s * FRAME_Y, s * (FRAME_Y - 0.012)))
        k.blk((-0.92, y0, f0), (0.92, y1, f1), "frame_black")
        yf0, yf1 = sorted((s * (FRAME_Y - 0.012), s * (FRAME_Y - 0.07)))
        for z in (f0, f1 - 0.016):  # the channel's flanges turned in
            k.blk((-0.92, yf0, z), (0.92, yf1, z + 0.016), "frame_black")
        k.bolts([(x, s * FRAME_Y, (f0 + f1) * 0.5 + dz) for x in (-0.86, -0.2, 0.2, 0.86)
                 for dz in (0.0,)], 0.011, 0.009, "y" if s > 0 else "-y", "frame_black")
    for sx in (-1.0, 1.0):
        x = sx * 0.92
        k.blk((x - 0.05, -FRAME_Y - 0.03, f0 - 0.02), (x + 0.05, FRAME_Y + 0.03, f1 + 0.02), "frame_black")
        k.bolts([(x + sx * 0.05, y, z) for y in (-0.78, -0.3, 0.3, 0.78) for z in ((f0 + f1) * 0.5,)], 0.012,
                0.01, "x" if sx > 0 else "-x", "frame_black")
        # the central buffer: a cast block tapering out from the headstock, a slot for the link, its pin on top
        xa, xb = x + sx * 0.05, sx * HL
        zm = (f0 + f1) * 0.5
        k.prism([(-0.13, zm - 0.1), (0.13, zm - 0.1), (0.13, zm + 0.1), (-0.13, zm + 0.1)], "x",
                min(xa, xa + sx * 0.02), max(xa, xa + sx * 0.02), "frame_black")  # its flange on the headstock
        k.blk((min(xa, xb), -0.1, zm - 0.075), (max(xa, xb), 0.1, zm + 0.075), "frame_black")
        k.blk((min(xb - sx * 0.004, xb), -0.035, zm - 0.03), (max(xb - sx * 0.004, xb), 0.035, zm + 0.03),
              "hazard_black")  # the slot's mouth
        k.cyl((xb - sx * 0.04, 0.0, zm + 0.075), 0.018, 0.05, "steel_bare", seg=6)  # the pin
        k.bar((xb - sx * 0.04, 0.0, zm + 0.125), (xb - sx * 0.04, 0.035, zm + 0.14), 0.008, "steel_bare", seg=4)
        for dy in (-0.022, 0.022):  # the link hanging from the slot
            k.bar((xb - sx * 0.01, dy, zm - 0.02), (xb - sx * 0.01, dy, zm - 0.16), 0.01, "rust", seg=4)
        k.bar((xb - sx * 0.01, -0.03, zm - 0.165), (xb - sx * 0.01, 0.03, zm - 0.165), 0.01, "rust", seg=4)
        # the step irons at the corners
        for y in (-FRAME_Y + 0.08, FRAME_Y - 0.08):
            k.sqbar((x + sx * 0.05, y, f0), (x + sx * 0.07, y, f0 - 0.16), 0.03, "frame_black", h=0.012)
    for x in (-AXLE_X - 0.2, AXLE_X + 0.2, 0.0):
        k.blk((x - 0.04, -FRAME_Y + 0.07, f1 - 0.1), (x + 0.04, FRAME_Y - 0.07, f1), "frame_black")
    k.mark("frame")
    # The brakes: a block on each wheel's inner tread, hung from the solebar, a beam across, and the hand lever down
    # the -y side from its shaft to a pin rack by the end.
    for x in (-AXLE_X, AXLE_X):
        xb = x - (WHEEL_R + 0.02) * (1.0 if x > 0 else -1.0) * 0.86
        for s in (-1.0, 1.0):
            y = s * (wk.WHEEL_IN + 0.035)
            k.blk((xb - 0.025, y - 0.035, zc - 0.08), (xb + 0.025, y + 0.035, zc + 0.08), "steel_bare")
            k.sqbar((xb, y, zc + 0.06), (xb * 0.94, y, f0 + 0.01), 0.025, "frame_black")
        k.blk((xb - 0.014, -wk.WHEEL_IN, zc - 0.014), (xb + 0.014, wk.WHEEL_IN, zc + 0.014), "frame_black")
    y = -FRAME_Y - 0.02
    k.bar((-0.12, -FRAME_Y + 0.05, f0 + 0.04), (-0.12, y - 0.01, f0 + 0.04), 0.022, "frame_black", seg=6)
    k.sqbar((-0.12, y, f0 + 0.04), (-0.8, y, zc - 0.12), 0.032, "works_yellow", h=0.022)
    k.blk((-0.86, y - 0.01, zc - 0.24), (-0.74, y + 0.01, zc + 0.02), "frame_black")  # the pin rack
    k.bolts([(-0.8, y - 0.01, zc - 0.05 - 0.05 * i) for i in range(3)], 0.012, 0.01, "-y", "steel_bare")
    k.mark("brakes")
    # The cradles: an A-frame plate at each end from the solebars up to the trunnion's bearing, flanges down its
    # slopes, gussets at its feet, a foot plate bolted to the solebars, and the bearing: a cup on the cradle's top,
    # capped and bolted, the tub's trunnion boss turning in it.
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * CRADLE_X, sx * (CRADLE_X + 0.05)))
        k.prism([(-FRAME_Y + 0.02, f1), (FRAME_Y - 0.02, f1), (0.15, PIVOT_Z - 0.08), (0.12, PIVOT_Z + 0.02),
                 (-0.12, PIVOT_Z + 0.02), (-0.15, PIVOT_Z - 0.08)], "x", x0, x1, "skip_grey")
        for s in (-1.0, 1.0):  # the flanges down each slope, standing out from the plate
            a = (s * (FRAME_Y - 0.03), f1 + 0.03)
            b = (s * 0.14, PIVOT_Z - 0.07)
            fx0, fx1 = sorted((sx * (CRADLE_X + 0.05), sx * (CRADLE_X + 0.1)))
            k.sqbar((sx * (CRADLE_X + 0.075), a[0], a[1]), (sx * (CRADLE_X + 0.075), b[0], b[1]), 0.05, "skip_grey",
                    h=0.03)
            for fy in (s * 0.62,):  # a gusset at the feet
                k.prism([(fy - 0.015, f1), (fy + 0.015, f1), (fy + 0.015, f1 + 0.1), (fy - 0.015, f1 + 0.02)], "x",
                        min(fx0, fx1), max(fx0, fx1) + 0.0, "skip_grey")
        k.blk((x0 - 0.05, -FRAME_Y - 0.02, f1), (x1 + 0.05, FRAME_Y + 0.02, f1 + 0.03), "skip_grey")
        k.bolts([(sx * (CRADLE_X + 0.025) + dx, y, f1 + 0.03) for dx in (0.0,) for y in (-0.8, -0.4, 0.4, 0.8)],
                0.014, 0.012, "z", "frame_black")
        # the bearing cup over the trunnion, its cap strap and two bolts each side
        k.cyl((sx * (CRADLE_X - 0.01), 0.0, PIVOT_Z), 0.13, sx * 0.09, "skip_grey", seg=12, axis="x")
        k.blk((min(x0 - 0.01, x1 + 0.03), -0.16, PIVOT_Z + 0.08), (max(x0 - 0.01, x1 + 0.03), 0.16, PIVOT_Z + 0.115),
              "frame_black")
        k.bolts([(sx * (CRADLE_X + 0.035), y, PIVOT_Z + 0.115) for y in (-0.13, 0.13)], 0.016, 0.02, "z", "steel_bare")
        hx, _ = tub_at(PIVOT_Z)
        k.cyl((sx * (hx - 0.02), 0.0, PIVOT_Z), 0.09, sx * (CRADLE_X - 0.01 - hx + 0.02), "frame_black", seg=12,
              axis="x")
        k.cyl((sx * (CRADLE_X + 0.08), 0.0, PIVOT_Z), 0.055, sx * 0.02, "steel_bare", seg=10, axis="x")
        k.cyl((sx * (CRADLE_X + 0.1), 0.0, PIVOT_Z), 0.022, sx * 0.012, "rust", seg=6, axis="x")
    k.mark("cradles")
    # The tub: an outer skin lofted up its levels and an inner one, joined over the top.
    outer = [ring(z, hx, hy, CORNER + 0.06 * (1.0 - i / (len(TUB) - 1))) for i, (z, hx, hy) in enumerate(TUB)]
    inner = [ring(z + 0.03, hx - 0.03, hy - 0.03, CORNER) for z, hx, hy in TUB[3:]]
    k.loft(outer, "skip_grey", cap0=True, cap1=False)
    k.loft(inner, "skip_grey", cap0=True, cap1=False)
    k.loft([outer[-1], [(x, y, RIM_Z + RIM_R) for x, y, _ in outer[-1]], inner[-1]], "skip_grey", cap0=False,
           cap1=False)
    # the rolled rim round the top and the stiffening rail round the middle, each a bar round the tub's corners
    for z, r in ((RIM_Z, RIM_R), (1.84, 0.024)):
        hx, hy = tub_at(min(z, RIM_Z - RIM_R))
        w = r * 0.8
        k.loft([ring(z + dz, hx - 0.01 + dw, hy - 0.01 + dw, CORNER) for dz, dw in ((-w, 0.0), (-w, r * 1.3),
                (w, r * 1.3), (w, 0.0), (-w, 0.0))], "skip_grey", cap0=False, cap1=False)
    k.mark("tub")
    # The ribs: flat bars down each long side from the bottom's turn to the rim, their foot cut back.
    for s in (-1.0, 1.0):
        for x in RIBS:
            pts = []
            for z in (1.12, 1.26, 1.42, 1.6, 1.8, 2.0, RIM_Z - 0.04):
                hx, hy = tub_at(z)
                pts.append((x * hx / 0.7, s * (hy + 0.012), z))
            k.loft([[(px - 0.03, py - s * 0.012, pz), (px + 0.03, py - s * 0.012, pz), (px + 0.03, py + s * 0.01, pz),
                     (px - 0.03, py + s * 0.01, pz)] for px, py, pz in pts], "skip_grey")
    # Rivets down the four corner seams (on the ends, beside each corner) and along the sides' foot seam.
    seams = []
    for z in [1.22 + 0.24 * i for i in range(5)]:
        hx, hy = tub_at(z)
        for sx in (-1.0, 1.0):
            for s in (-1.0, 1.0):
                seams.append(((sx * (hx + 0.004), s * (hy - 0.075), z), "x" if sx > 0 else "-x"))
    for s in (-1.0, 1.0):
        hx, hy = tub_at(1.3)
        for x in (-0.48, -0.24, 0.0, 0.24, 0.48):
            if all(abs(x - r) > 0.06 for r in RIBS):
                seams.append(((x, s * (hy + 0.004), 1.3), "y" if s > 0 else "-y"))
    for p, ax in seams:
        k.bolts([p], 0.014, 0.012, ax, "skip_grey", seg=3)
    k.mark("ribs")
    # Grab handles each side; the lifting lugs: a plate at each top corner of the ends, an eye in it and a bail.
    for s in (-1.0, 1.0):
        for x in (-0.6, 0.6):
            z = 2.06
            hx, hy = tub_at(z)
            yy = s * (hy + 0.012)
            for a, c in (((x - 0.13, yy, z - 0.02), (x - 0.13, yy + s * 0.05, z)),
                         ((x + 0.13, yy, z - 0.02), (x + 0.13, yy + s * 0.05, z)),
                         ((x - 0.14, yy + s * 0.05, z), (x + 0.14, yy + s * 0.05, z))):
                k.sqbar(a, c, 0.024, "steel_bare")
    for sx in (-1.0, 1.0):
        hx, hy = tub_at(RIM_Z - 0.1)
        for s in (-1.0, 1.0):
            y = s * (hy - 0.16)
            xs = sx * (hx + 0.01)
            k.prism([(y - 0.06, RIM_Z - 0.2), (y + 0.06, RIM_Z - 0.2), (y + 0.045, RIM_Z + 0.06),
                     (y - 0.045, RIM_Z + 0.06)], "x", min(xs, xs + sx * 0.025), max(xs, xs + sx * 0.025),
                    "frame_black")  # the lug plate up past the rim
            # the bail: a round bar hooked through the eye, its loop standing up over the rim
            top = RIM_Z + 0.24
            xe = xs + sx * 0.04
            for a, c in (((xe, y - 0.04, RIM_Z + 0.03), (xe, y - 0.04, top - 0.05)),
                         ((xe, y - 0.04, top - 0.05), (xe, y + 0.04, top - 0.05)),
                         ((xe, y + 0.04, top - 0.05), (xe, y + 0.04, RIM_Z + 0.1))):
                k.bar(a, c, 0.012, "steel_bare", seg=4, cap=False)
    k.mark("lugs")
    # The tipping catch at the +x end: a latch bar across under the rim in two keepers, its chain hanging from it.
    hx, _ = tub_at(2.0)
    k.sqbar((hx + 0.03, -0.3, 2.0), (hx + 0.03, 0.3, 2.0), 0.035, "steel_bare")
    for y in (-0.26, 0.26):
        hk, _ = tub_at(1.98)
        k.blk((hk - 0.01, y - 0.025, 1.96), (hk + 0.06, y + 0.025, 2.04), "frame_black")
    for i in range(3):
        z = 1.95 - i * 0.065
        hx, _ = tub_at(z)
        k.bar((hx + 0.03, 0.32, z), (hx + 0.03, 0.32, z - 0.055), 0.008, "rust", seg=4)
    k.mark("catch")
    spoil(k, rng)
    k.mark("spoil")
    return k.build()


def heap(u: float, v: float) -> float:
    """The spoil heap's height (0..1) over the tub, u along and v across in -1..1: a rounded tip, two humps on it."""
    base = 1.0 - max(abs(u) ** 3.0, abs(v) ** 3.0)
    hump = 0.18 * math.exp(-((u + 0.35) ** 2 + (v - 0.2) ** 2) / 0.12) + 0.12 * math.exp(-((u - 0.4) ** 2 + (v + 0.25)
                                                                                            ** 2) / 0.1)
    return min(1.0, max(0.0, base * 0.88 + hump))


def spoil(k: wk.Kit, rng: random.Random) -> None:
    """The spoil heaped over the rim to the box's top: small facets of clay, darker and lighter, and broken
    concrete, brick ends, stones and a bar of rebar lying in it half sunk."""
    hx, hy = TUB[-1][1] - 0.04, HD - 0.07
    z0 = RIM_Z - 0.04
    k.rubble(-hx, hx, -hy, hy, z0, HIGH, ["spoil", "spoil", "spoil_dark", "spoil_dark", "spoil", "rust_dark"], 15,
             15, 0.05, 6, shape=heap)

    def top(x: float, y: float) -> float:
        return z0 + (HIGH - z0) * heap(x / hx, y / hy)
    for i in range(LUMPS):
        x = rng.uniform(-hx + 0.12, hx - 0.12)
        y = rng.uniform(-hy + 0.12, hy - 0.12)
        kind = i % 8
        if kind in (0, 1, 2):  # broken concrete
            s = rng.uniform(0.09, 0.2)
            size = (s, s * rng.uniform(0.6, 1.0), s * rng.uniform(0.35, 0.6))
            chunk(k, (x, y, min(top(x, y), HIGH - size[2] * 0.4)), size,
                  ("concrete_dark", "concrete", "stone_pale")[kind], rng)
        elif kind in (3, 4):  # brick ends
            size = (0.11 * rng.uniform(0.8, 1.6), 0.1, 0.065)
            chunk(k, (x, y, min(top(x, y) + 0.01, HIGH - 0.03)), size, "brick_dull", rng)
        else:  # stones and clay clods
            r = rng.uniform(0.04, 0.09)
            pebble(k, (x, y, min(top(x, y), HIGH - r * 0.4)), r, ("ballast_dark", "spoil_dark", "stone_pale")[kind - 5],
                   rng, squash=rng.uniform(0.5, 0.8))
    # a bent length of rebar poking out of the heap
    pts = [(-0.3, -0.25, top(-0.3, -0.25) - 0.04), (0.0, -0.1, top(0.0, -0.1) + 0.03), (0.2, 0.05, top(0.2, 0.05)
                                                                                         + 0.12)]
    for a, b in zip(pts, pts[1:]):
        k.bar(a, (b[0], b[1], min(b[2], HIGH - 0.02)), 0.011, "rust", seg=5)


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint in ("skip_grey", "frame_black"):
        col = wk.rusty(p, n, c, seed=3, amount=0.6)
        if p.z > RIM_Z - 0.05 and paint == "skip_grey":  # the rim knocked bright
            col = wt.mix(col, wk.lin("steel_bare"), 0.4 * wt.fbm(p, 0.08, 5))
        if p.z > 1.0 and abs(n.z) < 0.8:  # spoil smeared down the tub from the rim
            smear = wt.smooth(0.5, 0.75, wt.fbm(Vector((p.x * 5, p.y * 5, p.z * 0.6)), 0.3, 9))
            col = wt.mix(col, wk.lin("spoil_dark"), 0.5 * smear * wt.smooth(1.4, RIM_Z, p.z))
        if abs(n.z) < 0.5 and p.z < RIM_Z:  # edges and ribs rubbed paler
            col = wt.mix(col, wk.lin("steel_bare"), 0.12 * wt.smooth(0.6, 0.8, wt.fbm(p, 0.04, 8)))
        return wk.grime(p, n, col, seed=1)
    if paint in ("spoil", "spoil_dark"):  # clay: wet and dark in the hollows, a little dry crust on the tops
        col = wt.mix(c, wk.lin("spoil_dark"), 0.55 * wt.fbm(p, 0.1, 21))
        col = wt.mix(col, wk.lin(wk.DUST), max(0.0, n.z) * 0.15 * wt.smooth(0.55, 0.8, wt.fbm(p, 0.06, 22)))
        return wt.scale(col, 0.8 + 0.35 * wt.fbm(p * 6.0, 0.05, 24))
    if paint in ("concrete", "concrete_dark", "stone_pale", "brick_dull", "ballast_dark"):  # lumps: clay on them
        col = wt.mix(c, wk.lin("spoil_dark"), 0.35 * wt.smooth(0.4, 0.75, wt.fbm(p, 0.05, 25)))
        return wt.scale(col, 0.85 + 0.2 * wt.fbm(p, 0.03, 26))
    if paint in ("wheel", "rust", "rust_dark"):
        return wk.grime(p, n, wk.rusty(p, n, c, seed=7, amount=0.4, streaks=False), seed=2)
    return wk.grime(p, n, c, seed=4)


def main() -> None:
    wk.reset()
    wk.check_colours(list(wk.PAINT))
    ob = build()
    wk.finish(ob, (-HL, -HD, 0.0), (HL, HD, HIGH))
    wk.bake(ob, weather, jitter={"timber": 0.06, "concrete_dark": 0.1, "concrete": 0.08, "spoil_dark": 0.08,
                                 "brick_dull": 0.1, "stone_pale": 0.12, "ballast_dark": 0.12})
    wk.write(ob, NAME, BUDGET)
    if "--render" in sys.argv:
        wk.render(wk.quarter_views(2 * HL, 2 * HD, HIGH), sys.argv[sys.argv.index("--render") + 1],
                  "SM4 skip wagon (Subway map prop, 2 x 2 x 2.7 m)")


if __name__ == "__main__":
    main()
