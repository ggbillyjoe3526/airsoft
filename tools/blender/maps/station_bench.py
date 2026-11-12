"""The station bench (Subway #25, SM3): the metro bench of the owner's photos 4 to 6
(art/references/maps/subway/25-bench/): moulded perforated steel bucket seats in a row, each a seat pan curling up
into its back, black divider arms between them, yellow arms at the ends (photos 4 to 6; the photos' yellow, a
safety colour, no network's), all on a black rail on two pairs of square legs. Their perch-seat cousins (photos 1 to
3) need a wall the map's benches don't all have.

Two models, each filling its block: `station_bench`, three seats on 2.0 x 0.8 x 0.6 m (the platforms'), and
`station_bench_long`, four on 3.0 m (the concourse's). Budget 1,000 triangles each.

Usage: python3 tools/blender/maps/station_bench.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402
import hallkit as sk  # noqa: E402

H, D = 0.8, 0.6
SHEET = "slab*0.46"         # the photos' dark grey steel
HOLES = "slab*0.2"
FRAME = sk.BLACK
ARM = "yellow*0.92"
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
    for r in range(rows):
        t = (r + 0.5) / rows * n
        for c in range(cols):
            x = x0 + (c + 0.5) / cols * (x1 - x0)
            o = (x, ya + v[1] * t + up[1] * 0.0012, za + v[2] * t + up[2] * 0.0012)
            sk.plane_poly(p, o, (1.0, 0.0, 0.0), v, [(-0.016, -0.005), (0.016, -0.005), (0.016, 0.005),
                                                     (-0.016, 0.005)], HOLES)


def build(length: float, seats: int, name: str, cols: int) -> prop.Prop:
    p = prop.Prop(name)
    hl = length / 2
    edge = hl - 0.022          # the end arms' line: the moulded sheet runs out under them, one piece end to end
    sw = 2 * edge / seats
    p.prism(sheet_outline(), "x", -edge, edge, SHEET)
    for i in range(seats):
        x0 = -edge + i * sw
        x1 = x0 + sw
        holes(p, x0 + 0.06, x1 - 0.06, (2, 3), 3, cols)
        holes(p, x0 + 0.06, x1 - 0.06, (6, 7), 4, cols)
    # the arms: yellow ones at the ends on the sheet's edges, black dividers between the seats, each standing on it
    for i in range(seats + 1):
        x = -edge + i * sw
        end = i in (0, seats)
        sk.tube(p, [(x, y, z) for y, z in ARM_PATH], 0.022 if end else 0.016, ARM if end else FRAME, 6 if end else 4)
        # the arm's feet: a block where it meets the seat's front and its back, so it reads welded on
        r = 0.022 if end else 0.016
        for y, z in (ARM_PATH[0], ARM_PATH[-1]):
            p.box((x - r, y - 0.012, z - 0.02), (x + r, y + 0.012, z + 0.006), ARM if end else FRAME)
    # the rail under the seats, its supports, two pairs of square legs with their feet
    p.box((-hl + 0.08, -0.02, 0.33), (hl - 0.08, 0.04, 0.38), FRAME)
    for i in range(seats):
        xm = -edge + i * sw + sw / 2
        p.box((xm - 0.02, -0.2, 0.38), (xm + 0.02, 0.12, 0.425), FRAME)
    for sx in (-1.0, 1.0):
        x = sx * (hl - 0.32)
        for y0, y1 in ((-0.2, -0.16), (0.12, 0.16)):
            p.box((x - 0.02, y0, 0.012), (x + 0.02, y1, 0.33), FRAME)
            p.box((x - 0.045, y0 - 0.025, 0.0), (x + 0.045, y1 + 0.025, 0.012), "slab*0.4")
        p.box((x - 0.02, -0.16, 0.18), (x + 0.02, 0.12, 0.21), FRAME)
    return p


if __name__ == "__main__":
    build(2.0, 3, "station_bench", 7).export("station_bench.glb", budget=1000)
    build(3.0, 4, "station_bench_long", 4).export("station_bench_long.glb", budget=1000)
