"""The station bench (Subway #25, SM3; finer detail SQ1): the metro bench of the owner's photos 4 to 6
(art/references/maps/subway/25-bench/): moulded perforated steel bucket seats in a row, each its own pan curling up
into its back with a rolled front lip, a narrow gap between them, close rows of perforations in pan and back; black
loop divider arms between them and yellow arms at the ends (photos 4 to 6; the photos' yellow, a safety colour, no
network's), a bright cap on each arm's front foot; all on a black box-section rail, a bracket under each seat,
on two pairs of square legs braced across, each leg on a foot plate with two bolt heads. Their perch-seat cousins
(photos 1 to 3) need a wall the map's benches don't all have. SQ1 parted the seats, rounded the arms'
bends, made the perforations denser, and gave the materials their finish: the seats a satin powder coat, the frame and
arms gloss, the caps on the arms' feet and the bolts stainless.

Two models, each filling its block: `station_bench`, three seats on 2.0 x 0.8 x 0.6 m (the platforms'), and
`station_bench_long`, four on 3.0 m (the concourse's), their bounds as before SQ1. Budget 2,000 triangles each (SQ1,
from 1,000).

Usage: python3 tools/blender/maps/station_bench.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402
import hallkit as sk  # noqa: E402
import hardsurface as hs  # noqa: E402
import surface_kinds as kinds  # noqa: E402

H, D = 0.8, 0.6
SHEET = "grey*0.66"         # the photos' grey steel
HOLES = "slab*0.31"  # not darker: near-black tints round to a team hue on import (test_props)
FRAME = "slab*0.3"
ARM = "yellow*0.92"
CAP = "concrete*0.85"
FOOT_PLATE = "slab*0.4"
GAP = 0.003                 # half the gap between two seats' pans
# What they are made of (SQ1): the seats a satin powder coat, the frame and arms gloss paint, the caps and bolts steel.
prop.KINDS.update({SHEET: kinds.SATIN, FRAME: kinds.GLOSS, ARM: kinds.GLOSS, CAP: kinds.STEEL,
                   FOOT_PLATE: kinds.SATIN})
# The seat's section (y, z), front lip to the back's top curl, and its thickness.
SECTION = [(-0.272, 0.405), (-0.267, 0.43), (-0.237, 0.447), (-0.08, 0.442), (0.07, 0.432), (0.145, 0.448),
           (0.19, 0.52), (0.232, 0.65), (0.265, 0.762), (0.282, 0.782)]
T = 0.008
ARM_PATH = [(-0.276, 0.42), (-0.271, 0.57), (-0.23, 0.625), (0.13, 0.625), (0.215, 0.68), (0.276, 0.788)]


def sheet_outline() -> list:
    """The seat's section as a closed outline: its top line, then the same offset down and back by T."""
    under = []
    for i, (y, z) in enumerate(SECTION):
        a = SECTION[max(0, i - 1)]
        b = SECTION[min(len(SECTION) - 1, i + 1)]
        ty, tz = b[0] - a[0], b[1] - a[1]
        n = math.hypot(ty, tz)
        under.append((y + tz / n * T, z - ty / n * T))
    return SECTION + under[::-1]


def on_segment(i: int, s: float) -> tuple:
    """A point s of the way along the section's segment i, and the segment's direction (y, z)."""
    (y0, z0), (y1, z1) = SECTION[i], SECTION[i + 1]
    n = math.hypot(y1 - y0, z1 - z0)
    return (y0 + (y1 - y0) * s, z0 + (z1 - z0) * s), ((y1 - y0) / n, (z1 - z0) / n)


def holes(p: prop.Prop, x0: float, x1: float, seg: tuple, rows: int, cols: int) -> None:
    """Rows of perforations on the sheet's top over section segments seg[0]..seg[1] (straight enough)."""
    (ya, za), _ = on_segment(seg[0], 0.15)
    (yb, zb), _ = on_segment(seg[1], 0.85)
    dy, dz = yb - ya, zb - za
    n = math.hypot(dy, dz)
    v = (0.0, dy / n, dz / n)
    up = (0.0, -dz / n, dy / n)
    hw = (x1 - x0) / cols * 0.3
    for r in range(rows):
        t = (r + 0.5) / rows * n
        for c in range(cols):
            x = x0 + (c + 0.5) / cols * (x1 - x0)
            o = (x, ya + v[1] * t + up[1] * 0.0012, za + v[2] * t + up[2] * 0.0012)
            sk.plane_poly(p, o, (1.0, 0.0, 0.0), v, [(-hw, -0.006), (hw, -0.006), (hw, 0.006), (-hw, 0.006)], HOLES)


def build(length: float, seats: int, name: str, cols: int, rows: tuple) -> prop.Prop:
    p = prop.Prop(name)
    hl = length / 2
    edge = hl - 0.022          # the end arms' line: the outer seats' pans run out under them
    sw = 2 * edge / seats
    pans = p
    for i in range(seats):
        x0 = -edge + i * sw
        x1 = x0 + sw
        pans.prism(sheet_outline(), "x", x0 + (GAP if i > 0 else 0.0), x1 - (GAP if i < seats - 1 else 0.0), SHEET)
        holes(p, x0 + 0.05, x1 - 0.05, (2, 2), rows[0], cols)
        holes(p, x0 + 0.05, x1 - 0.05, (3, 3), rows[0], cols)
        holes(p, x0 + 0.05, x1 - 0.05, (6, 7), rows[1], cols)
    # the arms: yellow ones at the ends on the pans' edges, black loops between the seats, each standing on them,
    # their bends rounded; a bright cap on each arm's front end
    path = hs.smooth(ARM_PATH, 1)
    for i in range(seats + 1):
        x = -edge + i * sw
        end = i in (0, seats)
        r = 0.022 if end else 0.016
        paint = ARM if end else FRAME
        sk.tube(p, [(x, y, z) for y, z in path], r, paint, 6 if end else 4)
        # the arm's feet: a block where it meets the seat's front and its back, so it reads welded on
        for y, z in (ARM_PATH[0], ARM_PATH[-1]):
            p.box((x - r, y - 0.012, z - 0.02), (x + r, y + 0.012, z + 0.006), paint)
        y, z = ARM_PATH[0]
        p.lathe([(0.001, r * 0.8), (-0.004, r * 0.7), (-0.006, 0.0)], CAP, 8, (x, y - 0.012, z - 0.007),
                "y")
    # the box-section rail under the seats, a bracket under each seat, two pairs of square legs braced across, each
    # on a foot plate with two bolt heads
    p.piece(0.005, 1).box((-hl + 0.08, -0.02, 0.33), (hl - 0.08, 0.04, 0.38), FRAME)
    for i in range(seats):
        xm = -edge + i * sw + sw / 2
        p.box((xm - 0.02, -0.2, 0.38), (xm + 0.02, 0.12, 0.425), FRAME)
        p.box((xm - 0.006, -0.1, 0.33), (xm + 0.006, 0.0, 0.38), FRAME)
    for sx in (-1.0, 1.0):
        x = sx * (hl - 0.32)
        for y0, y1 in ((-0.2, -0.16), (0.12, 0.16)):
            p.box((x - 0.02, y0, 0.012), (x + 0.02, y1, 0.33), FRAME)
            p.box((x - 0.045, y0 - 0.025, 0.0), (x + 0.045, y1 + 0.025, 0.012), FOOT_PLATE)
            for bx in (-0.032, 0.032):
                sk.disc(p, "+z", 0.0128, x + bx, (y0 + y1) / 2, 0.008, CAP, 6)
        p.box((x - 0.016, -0.16, 0.17), (x + 0.016, 0.12, 0.2), FRAME)
    return p


if __name__ == "__main__":
    build(2.0, 3, "station_bench", 12, (2, 5)).export("station_bench.glb", budget=2000)
    build(3.0, 4, "station_bench_long", 7, (2, 4)).export("station_bench_long.glb", budget=2000)
