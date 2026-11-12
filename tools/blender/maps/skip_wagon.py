"""Subway's spoil skips (SM4, model 6): a side-tipping skip wagon from the owner's photos
(art/references/maps/subway/06-skip-flat-wagon): a deep steel tub flaring from a rounded bottom to a rolled rim, its
ends sloped as well as its sides, stiffened by a rail round its middle and riveted, hung on trunnions in an A-frame
cradle at each end of a low channel-steel frame on four small flanged wheels; a tipping catch and its chain at one
end, dumb buffer blocks on the headstocks; full of spoil heaped over the rim (clay with broken concrete in it). Dark
grey with rust coming through; no lettering.

Its block (three on the south track, 2 x 2.2 m and 2.7 m high, data/maps/subway.json) is deeper across the track than
along it, so the tub's rim is as wide as the box and the frame and wheels sit inside it, on a length of works track
(works_kit.py).

Writes assets/models/props/skip_wagon.glb, one vertex-coloured mesh filling x -1..1 (along the track), y -1.1..1.1,
z 0..2.7 exactly (Godot: x along, y up, z across).

Usage: python3 -I tools/blender/maps/skip_wagon.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
from mathutils import Vector  # noqa: E402

NAME = "skip_wagon"
BUDGET = 2500
LUMPS = 10           # the big lumps lying in the spoil
HL, HD, HIGH = 1.0, 1.1, 2.7   # the box: half its length, half its depth, its height

WHEEL_R = 0.3
AXLE_X = 0.5
FRAME_Y = 0.52                 # the frame's half width (outside its channels)
PIVOT_Z = 1.62                 # the trunnions
RIM_Z = 2.26                   # the tub's rim
RIM_R = 0.032                  # the rolled rim's radius
CRADLE_X = 0.78                # the cradles' inner face
SEG = 10
# The tub by height: (z, half length, half width) from its rounded bottom to the rim's underside.
TUB = [(1.0, 0.6, 0.14), (1.03, 0.61, 0.38), (1.1, 0.62, 0.52), (1.22, 0.64, 0.63), (1.42, 0.68, 0.74),
       (1.8, 0.77, 0.89), (RIM_Z - RIM_R, 0.94, HD - RIM_R)]
CORNER = 0.08                  # the tub's corners, rounded in plan


def ring(z: float, hx: float, hy: float, r: float) -> list:
    """A rounded rectangle in plan at height z, two steps round each corner."""
    r = min(r, hx * 0.5, hy * 0.5)
    pts = []
    for cx, cy, a0 in ((hx - r, hy - r, 0.0), (-hx + r, hy - r, 90.0), (-hx + r, -hy + r, 180.0),
                       (hx - r, -hy + r, 270.0)):
        for i in range(3):
            a = math.radians(a0 + 45.0 * i)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a), z))
    return pts


def tub_at(z: float) -> tuple:
    """The tub's half length and half width at height z (between TUB's levels)."""
    for (z0, x0, y0), (z1, x1, y1) in zip(TUB, TUB[1:]):
        if z0 <= z <= z1:
            t = (z - z0) / (z1 - z0)
            return x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
    return TUB[-1][1], TUB[-1][2]


def build() -> object:
    k = wk.Kit(NAME)
    rail_top = k.works_track(-HL, HL, sleeper_len=1.4, pitch=0.62)
    k.mark("track")
    zc = rail_top + WHEEL_R
    for x in (-AXLE_X, AXLE_X):
        k.wheelset(x, 0.45 - 0.035, zc, WHEEL_R, 0.07, seg=SEG)
        for s in (-1.0, 1.0):
            k.axle_box(x, s * (FRAME_Y - 0.03), zc, 0.15, 0.15, 0.06, "frame_black")
    k.mark("wheels")
    # The frame: two channel solebars, headstocks at the ends, cross members, dumb buffers and a coupling bar.
    f0, f1 = zc + 0.06, zc + 0.24
    for s in (-1.0, 1.0):
        y0, y1 = sorted((s * FRAME_Y, s * (FRAME_Y - 0.07)))
        k.blk((-0.92, y0, f0), (0.92, y1, f1), "frame_black")
        ys = s * (FRAME_Y - 0.07)
        for z in (f0, f1 - 0.015):
            k.blk((-0.92, min(ys, ys - s * 0.05), z), (0.92, max(ys, ys - s * 0.05), z + 0.015), "frame_black")
        k.bolts([(x, s * FRAME_Y, (f0 + f1) * 0.5) for x in (-0.82, -0.68, 0.68, 0.82)], 0.012, 0.01,
                "y" if s > 0 else "-y", "frame_black")
    for x in (-0.92, 0.92):
        sx = 1.0 if x > 0 else -1.0
        k.blk((x - 0.05, -FRAME_Y - 0.05, f0 - 0.02), (x + 0.05, FRAME_Y + 0.05, f1 + 0.02), "frame_black")
        for y in (-0.36, 0.36):  # dumb buffers: timber blocks bolted to the headstock
            xa, xb = sorted((x + sx * 0.05, sx * HL))
            k.blk((xa, y - 0.08, f0 + 0.01), (xb, y + 0.08, f1 + 0.01), "timber")
        xa, xb = sorted((x + sx * 0.05, sx * 0.99))
        k.blk((xa, -0.05, f0 + 0.05), (xb, 0.05, f0 + 0.13), "rust")
    for x in (-AXLE_X - 0.2, AXLE_X + 0.2, 0.0):
        k.blk((x - 0.04, -FRAME_Y + 0.07, f1 - 0.1), (x + 0.04, FRAME_Y - 0.07, f1), "frame_black")
    k.mark("frame")
    # The cradles: an A-frame plate at each end from the solebars up to the trunnion's bearing, a foot plate, and
    # the trunnion: a boss on the tub's end in a bearing on the cradle.
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * CRADLE_X, sx * (CRADLE_X + 0.06)))
        k.prism([(-FRAME_Y, f1), (FRAME_Y, f1), (0.14, PIVOT_Z - 0.04), (0.1, PIVOT_Z + 0.1),
                 (-0.1, PIVOT_Z + 0.1), (-0.14, PIVOT_Z - 0.04)], "x", x0, x1, "skip_grey")
        k.blk((x0 - 0.03, -FRAME_Y - 0.02, f1), (x1 + 0.03, FRAME_Y + 0.02, f1 + 0.03), "skip_grey")
        hx, _ = tub_at(PIVOT_Z)
        k.cyl((sx * (hx - 0.02), 0.0, PIVOT_Z), 0.1, sx * (CRADLE_X + 0.08 - hx + 0.02), "frame_black", seg=10,
              axis="x")
        k.cyl((sx * (CRADLE_X + 0.08), 0.0, PIVOT_Z), 0.05, -sx * 0.015, "rust", seg=8, axis="x")
    k.mark("cradles")
    # The tub: an outer skin lofted up its levels and an inner one, joined over the top.
    outer = [ring(z, hx, hy, CORNER + 0.06 * (1.0 - i / (len(TUB) - 1))) for i, (z, hx, hy) in enumerate(TUB)]
    inner = [ring(z + 0.03, hx - 0.03, hy - 0.03, CORNER) for z, hx, hy in TUB[2:]]
    k.loft(outer, "skip_grey", cap0=True, cap1=False)
    k.loft(inner, "skip_grey", cap0=True, cap1=False)
    k.loft([outer[-1], [(x, y, RIM_Z + RIM_R) for x, y, _ in outer[-1]], inner[-1]], "skip_grey", cap0=False,
           cap1=False)
    # the rolled rim round the top and the stiffening rail round the middle, each a bar round the tub's corners
    for z, r in ((RIM_Z, RIM_R), (1.84, 0.024)):
        hx, hy = tub_at(min(z, RIM_Z - RIM_R))
        pts = ring(z, hx + r * 0.5, hy + r * 0.5, CORNER)
        for a, b in zip(pts, pts[1:] + pts[:1]):
            k.sqbar(a, b, r * 1.6, "skip_grey", h=r * 1.6)
    k.mark("tub")
    # Rivets along the long sides; a handle each side of the middle.
    for s in (-1.0, 1.0):
        for z in (1.25, 1.55):
            hx, hy = tub_at(z)
            k.bolts([(x, s * hy, z) for x in (-hx * 0.55, 0.0, hx * 0.55)], 0.013, 0.012, "y" if s > 0 else "-y",
                    "skip_grey")
        for x in (-0.42, 0.42):
            z = 2.06
            hx, hy = tub_at(z)
            yy = s * (hy + 0.012)
            for a, c in (((x - 0.17, yy, z - 0.02), (x - 0.17, yy + s * 0.05, z)),
                         ((x + 0.17, yy, z - 0.02), (x + 0.17, yy + s * 0.05, z)),
                         ((x - 0.18, yy + s * 0.05, z), (x + 0.18, yy + s * 0.05, z))):
                k.sqbar(a, c, 0.024, "steel_bare")
    k.mark("rivets")
    # The tipping catch at the +x end: a latch bar across under the rim, its chain hanging from it.
    hx, _ = tub_at(2.0)
    k.sqbar((hx + 0.03, -0.3, 2.0), (hx + 0.03, 0.3, 2.0), 0.035, "steel_bare")
    for i in range(4):
        z = 1.95 - i * 0.07
        hx, _ = tub_at(z)
        k.bar((hx + 0.03, 0.32, z), (hx + 0.03, 0.32, z - 0.06), 0.008, "rust", seg=4)
    k.mark("catch")
    # The spoil, heaped over the rim to the box's top; broken concrete and clay lumps in it.
    k.rubble(-TUB[-1][1] + 0.05, TUB[-1][1] - 0.05, -HD + 0.07, HD - 0.07, RIM_Z - 0.04, HIGH,
             ["spoil", "spoil", "spoil_dark", "spoil_dark", "concrete_dark"], 13, 15, 0.12, 6)
    import random
    rng = random.Random(61)
    for i in range(LUMPS):  # broken concrete, clay and rusty scrap lying in the heap, half sunk, every way up
        x = rng.uniform(-TUB[-1][1] + 0.2, TUB[-1][1] - 0.2)
        y = rng.uniform(-HD + 0.2, HD - 0.2)
        r = rng.uniform(0.08, 0.17)
        h = 1.0 - max(abs(x / TUB[-1][1]) ** 2.2, abs(y / HD) ** 2.2)
        z = RIM_Z - 0.04 + (HIGH - RIM_Z + 0.04) * h
        k.stone((x, y, min(z, HIGH - r * 0.5)), r, ("concrete_dark", "spoil_dark", "rust_dark")[i % 3],
                60 + i, squash=rng.uniform(0.4, 0.8), tilt=True)
    k.mark("spoil")
    return k.build()


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint in ("skip_grey", "frame_black"):
        col = wk.rusty(p, n, c, seed=3, amount=0.6)
        if p.z > RIM_Z - 0.05:  # the rim knocked bright
            col = wt.mix(col, wk.lin("steel_bare"), 0.4 * wt.fbm(p, 0.08, 5))
        if p.z > 1.0 and abs(n.z) < 0.8:  # spoil smeared down the tub from the rim
            smear = wt.smooth(0.5, 0.75, wt.fbm(Vector((p.x * 5, p.y * 5, p.z * 0.6)), 0.3, 9))
            col = wt.mix(col, wk.lin("spoil_dark"), 0.5 * smear * wt.smooth(1.4, RIM_Z, p.z))
        return wk.grime(p, n, col, seed=1)
    if paint == "spoil":
        col = wt.mix(c, wk.lin("spoil_dark"), 0.7 * wt.fbm(p, 0.15, 21))
        return wt.mix(col, wk.lin("concrete_dark"), 0.35 * wt.smooth(0.6, 0.8, wt.fbm(p, 0.08, 23)))
    if paint in ("rail", "wheel", "rust"):
        return wk.grime(p, n, wk.rusty(p, n, c, seed=7, amount=0.4, streaks=False), seed=2)
    return wk.grime(p, n, c, seed=4)


def main() -> None:
    wk.reset()
    wk.check_colours(list(wk.PAINT))
    ob = build()
    wk.finish(ob, (-HL, -HD, 0.0), (HL, HD, HIGH))
    wk.bake(ob, weather, jitter={"sleeper": 0.08, "timber": 0.06, "concrete_dark": 0.08, "spoil_dark": 0.08})
    wk.write(ob, NAME, BUDGET)
    if "--render" in sys.argv:
        wk.render(wk.quarter_views(2 * HL, 2 * HD, HIGH), sys.argv[sys.argv.index("--render") + 1],
                  "SM4 skip wagon (Subway map prop, 2 x 2.2 x 2.7 m)")


if __name__ == "__main__":
    main()
