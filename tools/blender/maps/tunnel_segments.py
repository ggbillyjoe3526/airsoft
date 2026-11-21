"""Subway's stack of tunnel lining segments (SM4, model 12): precast concrete segments waiting to be fitted, from the
owner's photos (art/references/maps/subway/12-tunnel-segments): curved slabs stacked concave side up, two stacks side
by side, each on two concrete bearer blocks with timber packers between the layers; each segment's black gasket
band round its side faces and recessed bolt pockets in its side and end faces. Pale concrete, dusty; no markings.

SQ1 (owner, 2026-11-21: every Subway model in finer detail): each segment is its real cross-section swept round the
arc, its inner face's broad chamfered arrises, the gasket a black band down each side face. Attempt 2 made the arc the
photos' (a 1.34 m bore, the arc's rise a fifth of its chord, so it reads at 10 m) and sank real pockets into it: one
6 cm deep in each side face near each end, two 8 cm deep in each radial end face, each with walls and a dark floor.

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
import bmesh  # noqa: E402
from mathutils import Vector, geometry  # noqa: E402

NAME = "tunnel_segments"
BUDGET = 3000
HL, HD, HIGH = 1.0, 0.95, 1.3

RADIUS = 1.34         # the segments' inner radius (a small bore's: the arc reads at 10 m, as the photos' does)
THICK = 0.16
RING_W = 0.86         # a segment's width (a ring's length along the tunnel)
GAP = 0.18            # between the two stacks
LAYERS = 4
PACKER = 0.065        # the timber packers' height between layers (at the arc's middle)
N = 9                 # steps round each segment's arc
CHAMFER = 0.03        # the inner face's chamfered edges (the photos' broad arrises)
GASKET_BAND = (0.66, 0.8)   # the black gasket band down each side face, as parts of the thickness from the inner face
POCKET_D = 0.06       # the side faces' bolt pockets' depth into the segment
END_POCKET_D = 0.08   # the end faces' bolt pockets' depth
HALF = math.asin(HL / (RADIUS + THICK))   # the arc's half angle: the outer corners reach x = +-HL
STEP = THICK + PACKER
# the bearers' height: the top segment's inner end corners reach the box's top exactly
BEARER = HIGH - (LAYERS - 1) * STEP - THICK - RADIUS * (1.0 - math.cos(HALF))

wk.PAINT["gasket_rubber"] = 0x262626    # the black gasket band round each segment
wk.PAINT["pocket_dark"] = 0x5a5852      # the floor of a bolt pocket


def profile(y0: float, y1: float) -> list:
    """A segment's cross-section, (y, radius) round it: the inner face with its chamfers, the y1 side face (its
    pocket strip, the gasket band, the rest), the outer face, the y0 side face."""
    r0, r1, c = RADIUS, RADIUS + THICK, CHAMFER
    g0, g1 = RADIUS + THICK * GASKET_BAND[0], RADIUS + THICK * GASKET_BAND[1]
    return [(y0 + c, r0), (y1 - c, r0), (y1, r0 + c), (y1, g0), (y1, g1), (y1, r1), (y0, r1), (y0, g1), (y0, g0),
            (y0, r0 + c)]


GASKET = (3, 7)       # the profile's edges on the gasket band, painted black
POCKET_STRIP = {1.0: 2, -1.0: 8}   # each side's edge holding its bolt pockets (between the chamfer and the band)


def put(k: wk.Kit, vs: list, want: Vector, mat: str) -> object:
    """A face through the verts `vs`, turned to face `want`."""
    f = k.bm.faces.new(vs)
    f.normal_update()
    if f.normal.dot(want) < 0.0:
        f.normal_flip()
    k._faces([f], mat)
    return f


def recess(k: wk.Kit, rim: list, hole: list, inward: Vector, depth: float, face_mat: str) -> None:
    """A rectangular pocket `depth` deep along `inward` in a flat quad face: the face (its corners `rim`) as a frame
    of four quads round the hole (its corners `hole`, in the same order), the pocket's four walls and its dark floor."""
    bm = k.bm
    out = -inward
    vr = [bm.verts.new(Vector(p)) for p in rim]
    vh = [bm.verts.new(Vector(p)) for p in hole]
    vf = [bm.verts.new(Vector(p) + inward * depth) for p in hole]
    mid = sum((Vector(p) for p in hole), Vector()) / 4.0
    for j in range(4):
        jj = (j + 1) % 4
        put(k, [vr[j], vr[jj], vh[jj], vh[j]], out, face_mat)
        edge = (Vector(hole[j]) + Vector(hole[jj])) * 0.5
        put(k, [vh[j], vh[jj], vf[jj], vf[j]], mid - edge, "concrete_dark")
    put(k, vf, out, "pocket_dark")


def segment(k: wk.Kit, y0: float, y1: float, z_low: float) -> None:
    """One segment from y0 to y1, its inner face's lowest point at z_low, its outer corners at the box's ends: the
    profile swept round the arc (flat facets, one a step); the gasket band black; a bolt pocket sunk into each side
    face near each end, and two into each radial end face."""
    zc = z_low + RADIUS                         # the arc's middle
    prof = profile(y0, y1)
    n = len(prof)

    def at(a: float, y: float, rho: float) -> Vector:
        return Vector((rho * math.sin(a), y, zc - rho * math.cos(a)))

    angles = [-HALF + 2 * HALF * i / N for i in range(N + 1)]
    faces = k.loft([[tuple(at(a, y, rho)) for y, rho in prof] for a in angles], "concrete", cap0=False, cap1=False)
    for i in range(N):  # the loft's faces run a ring's edges in order, one ring step at a time
        for e in GASKET:
            k._faces([faces[i * n + e]], "gasket_rubber")
    # the side faces' pockets: in the step next to each end, between the chamfer and the gasket band
    cut = []
    for sgn, e in POCKET_STRIP.items():
        ys = y1 if sgn > 0 else y0
        ra, rb = sorted((prof[e][1], prof[e + 1][1]))
        for i in (1, N - 2):
            cut.append(faces[i * n + e])

            def on(u: float, rho: float, i: int = i, ys: float = ys) -> tuple:
                return tuple(at(angles[i], ys, rho).lerp(at(angles[i + 1], ys, rho), u))
            m = 0.012
            rim = [on(0.0, ra), on(1.0, ra), on(1.0, rb), on(0.0, rb)]
            hole = [on(0.18, ra + m), on(0.82, ra + m), on(0.82, rb - m), on(0.18, rb - m)]
            recess(k, rim, hole, Vector((0.0, -sgn, 0.0)), POCKET_D, "concrete")
    bmesh.ops.delete(k.bm, geom=cut, context="FACES_ONLY")
    # the radial end faces: the profile with two pockets sunk into it, along the arc
    r0, r1 = RADIUS, RADIUS + THICK
    for a in (-HALF, HALF):
        out = Vector((math.cos(a), 0.0, math.sin(a))) * (1.0 if a > 0 else -1.0)
        holes = []
        for yf in (0.27, 0.73):
            ym, w = y0 + (y1 - y0) * yf, 0.08
            holes.append([(ym - w, r0 + 0.035), (ym + w, r0 + 0.035), (ym + w, r1 - 0.035), (ym - w, r1 - 0.035)])
        loops = [prof] + holes
        flat = [p for loop in loops for p in loop]
        tris = geometry.tessellate_polygon([[Vector((y, rho, 0.0)) for y, rho in loop] for loop in loops])
        vs = [k.bm.verts.new(at(a, y, rho)) for y, rho in flat]
        for t in tris:
            put(k, [vs[t[0]], vs[t[1]], vs[t[2]]], out, "concrete")
        for hole in holes:
            pts = [at(a, y, rho) for y, rho in hole]
            vh = [k.bm.verts.new(p) for p in pts]
            vf = [k.bm.verts.new(p - out * END_POCKET_D) for p in pts]
            mid = sum(pts, Vector()) / 4.0
            for j in range(4):
                jj = (j + 1) % 4
                put(k, [vh[j], vh[jj], vf[jj], vf[j]], mid - (pts[j] + pts[jj]) * 0.5, "concrete_dark")
            put(k, vf, out, "pocket_dark")


def build() -> object:
    k = wk.Kit(NAME)
    for sy in (-1.0, 1.0):
        y0, y1 = sorted((sy * GAP * 0.5, sy * (GAP * 0.5 + RING_W)))
        # two bearer blocks under the stack, across it, under the segment's ends' lower thirds, their top edges
        # chamfered
        for x in (-0.55, 0.55):
            k.prism([(x - 0.12, 0.0), (x + 0.12, 0.0), (x + 0.12, BEARER - 0.02), (x + 0.1, BEARER),
                     (x - 0.1, BEARER), (x - 0.12, BEARER - 0.02)], "y", y0, y1, "concrete_dark")
        for layer in range(LAYERS):
            z_out = BEARER + layer * STEP       # the outer face's lowest point

            def outer_at(x: float, zo: float = z_out) -> float:
                return zo + (RADIUS + THICK) - math.sqrt((RADIUS + THICK) ** 2 - x * x)
            # timber packers under this one's outer face, on the segment below (or the bearers), across the stack
            for x in (-0.55, 0.55):
                if layer > 0:
                    zb = BEARER + (layer - 1) * STEP + THICK + RADIUS - math.sqrt(RADIUS ** 2 - x * x)
                else:
                    zb = BEARER
                k.blk((x - 0.06, y0 + 0.05, zb), (x + 0.06, y1 - 0.05, outer_at(x)), "timber")
            segment(k, y0, y1, z_out + THICK)
        k.mark("stack")
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
