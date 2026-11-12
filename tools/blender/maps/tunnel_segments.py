"""Subway's stack of tunnel lining segments (SM4, model 12): precast concrete segments waiting to be fitted, from the
owner's photos (art/references/maps/subway/12-tunnel-segments): curved slabs stacked concave side up, two stacks side
by side, each on two concrete bearer blocks with timber packers between the layers; each segment's black gasket
groove round its edges, a recessed bolt pocket at each end and two grout holes. Pale concrete, dusty; no markings.

Its block (the platform's east end, 2 x 1.9 m and 1.3 m high, data/maps/subway.json) holds two stacks of four.

Writes assets/models/props/tunnel_segments.glb, one vertex-coloured mesh filling x -1..1 (the segments' arc),
y -0.95..0.95, z 0..1.3 exactly (Godot: x along, y up, z across).

Usage: python3 -I tools/blender/maps/tunnel_segments.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
from mathutils import Vector  # noqa: E402

NAME = "tunnel_segments"
BUDGET = 1500
HL, HD, HIGH = 1.0, 0.95, 1.3

RADIUS = 2.6          # the segments' inner radius (a running tunnel's)
THICK = 0.19
RING_W = 0.86         # a segment's width (a ring's length along the tunnel)
GAP = 0.18            # between the two stacks
LAYERS = 4
BEARER = 0.14
PACKER = 0.075
N = 11                # steps round each segment's arc


def segment(k: wk.Kit, y0: float, y1: float, z_low: float) -> None:
    """One segment from y0 to y1, its inner face's lowest point at z_low, its ends up to the box's ends."""
    half = math.asin(HL / (RADIUS + THICK))   # the arc's half angle: its outer corners reach x = +-HL
    zc = z_low + RADIUS                         # the arc's middle
    inner, outer = [], []
    for i in range(N + 1):
        a = -half + 2 * half * i / N
        inner.append((RADIUS * math.sin(a), zc - RADIUS * math.cos(a)))
        outer.append(((RADIUS + THICK) * math.sin(a), zc - (RADIUS + THICK) * math.cos(a)))
    bm = k.bm
    vi0 = [bm.verts.new(Vector((x, y0, z))) for x, z in inner]
    vi1 = [bm.verts.new(Vector((x, y1, z))) for x, z in inner]
    vo0 = [bm.verts.new(Vector((x, y0, z))) for x, z in outer]
    vo1 = [bm.verts.new(Vector((x, y1, z))) for x, z in outer]
    faces = []
    for i in range(N):
        faces.append(bm.faces.new((vi0[i], vi0[i + 1], vi1[i + 1], vi1[i])))    # the inner (top) face
        faces.append(bm.faces.new((vo1[i], vo1[i + 1], vo0[i + 1], vo0[i])))    # the outer (bottom) face
        faces.append(bm.faces.new((vo0[i], vo0[i + 1], vi0[i + 1], vi0[i])))    # the side at y0
        faces.append(bm.faces.new((vi1[i], vi1[i + 1], vo1[i + 1], vo1[i])))    # the side at y1
    faces.append(bm.faces.new((vi0[0], vi1[0], vo1[0], vo0[0])))
    faces.append(bm.faces.new((vo0[N], vo1[N], vi1[N], vi0[N])))
    import bmesh
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    k._faces(faces, "concrete")
    # the gasket groove: a dark band along each side face near the outer edge
    for y, sgn in ((y0, -1.0), (y1, 1.0)):
        yy = y + sgn * 0.002
        for i in range(N):
            a0, a1 = -half + 2 * half * i / N, -half + 2 * half * (i + 1) / N
            r0, r1 = RADIUS + THICK * 0.62, RADIUS + THICK * 0.78
            pts = [(r0 * math.sin(a0), yy, zc - r0 * math.cos(a0)), (r0 * math.sin(a1), yy, zc - r0 * math.cos(a1)),
                   (r1 * math.sin(a1), yy, zc - r1 * math.cos(a1)), (r1 * math.sin(a0), yy, zc - r1 * math.cos(a0))]
            k.quad(pts if sgn > 0 else list(reversed(pts)), "hazard_black")
    # bolt pockets near each end of the inner face, two grout holes in the middle
    for sx in (-1.0, 1.0):
        a = sx * (half - 0.09)
        rr = RADIUS - 0.002
        xm, zm = rr * math.sin(a), zc - rr * math.cos(a)
        tx, tz = math.cos(a), math.sin(a)
        for ym in (y0 + (y1 - y0) * 0.3, y0 + (y1 - y0) * 0.7):
            pts = [(xm - tx * 0.06, ym - 0.04, zm - tz * 0.06), (xm + tx * 0.06, ym - 0.04, zm + tz * 0.06),
                   (xm + tx * 0.06, ym + 0.04, zm + tz * 0.06), (xm - tx * 0.06, ym + 0.04, zm - tz * 0.06)]
            k.quad(pts, "concrete_dark")
    for ym in (y0 + (y1 - y0) * 0.35, y0 + (y1 - y0) * 0.65):
        pts = [(-0.035, ym - 0.035, z_low + 0.002), (0.035, ym - 0.035, z_low + 0.002),
               (0.035, ym + 0.035, z_low + 0.002), (-0.035, ym + 0.035, z_low + 0.002)]
        k.quad(pts, "concrete_dark")


def build() -> object:
    k = wk.Kit(NAME)
    step = THICK + PACKER
    for sy in (-1.0, 1.0):
        y0, y1 = sorted((sy * GAP * 0.5, sy * (GAP * 0.5 + RING_W)))
        # two bearer blocks under the stack, across it, under the segment's ends' lower thirds
        for x in (-0.55, 0.55):
            k.blk((x - 0.12, y0 - 0.0, 0.0), (x + 0.12, y1, BEARER), "concrete_dark")
        for layer in range(LAYERS):
            z_out = BEARER + layer * step       # the outer face's lowest point

            def outer_at(x: float, zo: float = z_out) -> float:
                return zo + (RADIUS + THICK) - math.sqrt((RADIUS + THICK) ** 2 - x * x)
            if layer > 0:  # packers on the segment below, under this one's outer face
                for x in (-0.55, 0.55):
                    z_top_below = BEARER + (layer - 1) * step + THICK + RADIUS - math.sqrt(RADIUS ** 2 - x * x)
                    k.blk((x - 0.06, y0 + 0.08, z_top_below), (x + 0.06, y1 - 0.08, outer_at(x)), "timber")
            else:
                for x in (-0.55, 0.55):
                    k.blk((x - 0.06, y0 + 0.08, BEARER), (x + 0.06, y1 - 0.08, outer_at(x)), "timber")
            segment(k, y0, y1, z_out + THICK)
    return k.build()


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint in ("concrete", "concrete_dark"):
        col = wt.mix(c, wk.lin("concrete_dark"), 0.35 * wt.fbm(p, 0.25, 71))
        return wk.grime(p, n, col, seed=12, amount=0.8)
    return wk.grime(p, n, c, seed=4)


def main() -> None:
    wk.reset()
    wk.check_colours(list(wk.PAINT))
    ob = build()
    wk.finish(ob, (-HL, -HD, 0.0), (HL, HD, HIGH))
    wk.bake(ob, weather, jitter={"concrete": 0.04, "timber": 0.08})
    wk.write(ob, NAME, BUDGET)
    if "--render" in sys.argv:
        wk.render(wk.quarter_views(2 * HL, 2 * HD, HIGH), sys.argv[sys.argv.index("--render") + 1],
                  "SM4 tunnel segments (Subway map prop, 2 x 1.9 x 1.3 m)")


if __name__ == "__main__":
    main()
