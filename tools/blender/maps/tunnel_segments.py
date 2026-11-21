"""Subway's stack of tunnel lining segments (SM4, model 12): precast concrete segments waiting to be fitted, from the
owner's photos (art/references/maps/subway/12-tunnel-segments): curved slabs stacked concave side up, two stacks side
by side, each on two concrete bearer blocks with timber packers between the layers; each segment's black gasket
groove round its edges, a recessed bolt pocket at each end and two grout holes. Pale concrete, dusty; no markings.

SQ1 (owner, 2026-11-21: every Subway model in finer detail) gave it the photos' shapes at about twice the
triangles: each segment is now its real cross-section swept round the arc, its inner face's broad chamfered arrises
and the outer face's smaller ones, a V groove up each side face with the black gasket in it; a bolt pocket in each
side face near each end (a dark mouth over a lighter floor, so it reads as a recess), two grout holes and a lifting
socket with its steel anchor ring on the inner face; the bearers' top edges chamfered under the timber packers.

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
BUDGET = 3000
HL, HD, HIGH = 1.0, 0.95, 1.3

RADIUS = 2.6          # the segments' inner radius (a running tunnel's)
THICK = 0.19
RING_W = 0.86         # a segment's width (a ring's length along the tunnel)
GAP = 0.18            # between the two stacks
LAYERS = 4
BEARER = 0.14
PACKER = 0.075
N = 9                 # steps round each segment's arc
CHAMFER = 0.022       # the inner face's chamfered edges (the photos' broad arrises)
CHAMFER_OUT = 0.012   # the outer face's
GROOVE = (0.58, 0.8)  # the gasket groove up each side face, as parts of the thickness from the inner face
GROOVE_D = 0.014      # its depth into the side face

wk.PAINT["gasket_rubber"] = 0x262626    # the black gasket in its groove round each segment
wk.PAINT["pocket_dark"] = 0x5a5852      # the shadow inside a bolt pocket or a grout hole


def profile(y0: float, y1: float) -> list:
    """A segment's cross-section, (y, radius) round it: the inner face with its chamfers, a side face with the
    gasket's V groove, the outer face, the other side face. Ends with the groove's corners' indices, for the paint."""
    r0, r1, c, c2 = RADIUS, RADIUS + THICK, CHAMFER, CHAMFER_OUT
    g0, g1 = RADIUS + THICK * GROOVE[0], RADIUS + THICK * GROOVE[1]
    gm = (g0 + g1) * 0.5
    return [(y0 + c, r0), (y1 - c, r0), (y1, r0 + c), (y1, g0), (y1 - GROOVE_D, gm), (y1, g1), (y1, r1 - c2),
            (y1 - c2, r1), (y0 + c2, r1), (y0, r1 - c2), (y0, g1), (y0 + GROOVE_D, gm), (y0, g0), (y0, r0 + c)]


GASKET = ((3, 4), (4, 5), (10, 11), (11, 12))   # the profile's edges in the grooves, painted black


def segment(k: wk.Kit, y0: float, y1: float, z_low: float) -> None:
    """One segment from y0 to y1, its inner face's lowest point at z_low, its ends up to the box's ends: the profile
    swept round the arc (flat facets, one a step), its radial ends flat; the gasket black in its grooves, a bolt
    pocket in each side face near each end, two grout holes and a lifting socket with its steel anchor in the middle
    of the inner face."""
    half = math.asin(HL / (RADIUS + THICK))   # the arc's half angle: its outer corners reach x = +-HL
    zc = z_low + RADIUS                         # the arc's middle
    prof = profile(y0, y1)

    def at(a: float, y: float, rho: float) -> tuple:
        return (rho * math.sin(a), y, zc - rho * math.cos(a))

    angles = [-half + 2 * half * i / N for i in range(N + 1)]
    faces = k.loft([[at(a, y, rho) for y, rho in prof] for a in angles], "concrete")
    n = len(prof)
    for i in range(N):  # the loft's faces run a ring's edges in order, one ring step at a time
        for e0, _e1 in GASKET:
            k._faces([faces[i * n + e0]], "gasket_rubber")

    def on_facet(i: int, u: float, y: float, rho: float) -> tuple:
        """A point on step i's flat facet, u (0..1) along it, at (y, rho): on the chord, not the arc."""
        p0, p1 = Vector(at(angles[i], y, rho)), Vector(at(angles[i + 1], y, rho))
        return tuple(p0.lerp(p1, u))

    # bolt pockets: on each side face, in the step next to each end, between the inner face and the groove; a dark
    # mouth and a lighter floor set to one side, so the pocket reads as a recess
    for y, sgn in ((y0, -1.0), (y1, 1.0)):
        yy = y + sgn * 0.0015
        for i in (1, N - 2):
            for (u0, u1, ra, rb, paint, dy) in ((0.15, 0.85, 0.025, 0.1, "pocket_dark", 0.0),
                                                (0.24, 0.85, 0.042, 0.1, "concrete_dark", 0.0005)):
                pts = [on_facet(i, u0, yy + sgn * dy, RADIUS + ra), on_facet(i, u1, yy + sgn * dy, RADIUS + ra),
                       on_facet(i, u1, yy + sgn * dy, RADIUS + rb), on_facet(i, u0, yy + sgn * dy, RADIUS + rb)]
                k.quad(pts if sgn > 0 else list(reversed(pts)), paint)
    # grout holes and the lifting socket on the inner face's middle step, a hair proud of it
    mid = N // 2
    rr = RADIUS - 0.0015
    for ym, r, paint in ((y0 + (y1 - y0) * 0.22, 0.028, "pocket_dark"), (y0 + (y1 - y0) * 0.78, 0.028, "pocket_dark"),
                         ((y0 + y1) * 0.5, 0.04, "pocket_dark")):
        c = Vector(on_facet(mid, 0.5, ym, rr))
        t = (Vector(on_facet(mid, 1.0, ym, rr)) - Vector(on_facet(mid, 0.0, ym, rr))).normalized()
        ring = [tuple(c + t * r * math.cos(2 * math.pi * j / 6) + Vector((0.0, r * math.sin(2 * math.pi * j / 6), 0.0)))
                for j in range(6)]
        k.fan(ring, (0.0, 0.0, 1.0), paint)
        if r > 0.03:  # the socket's steel anchor ring round its mouth
            outer = [tuple(c + t * (r + 0.018) * math.cos(2 * math.pi * j / 6) +
                           Vector((0.0, (r + 0.018) * math.sin(2 * math.pi * j / 6), 0.0))) for j in range(6)]
            bm = k.bm
            vi = [bm.verts.new(Vector(p)) for p in ring]
            vo = [bm.verts.new(Vector(p) + Vector((0.0, 0.0, 0.0005))) for p in outer]
            ann = [bm.faces.new((vi[j], vi[(j + 1) % 6], vo[(j + 1) % 6], vo[j])) for j in range(6)]
            for f in ann:
                f.normal_update()
                if f.normal.z < 0.0:
                    f.normal_flip()
            k._faces(ann, "steel_bare")


def build() -> object:
    k = wk.Kit(NAME)
    step = THICK + PACKER
    for sy in (-1.0, 1.0):
        y0, y1 = sorted((sy * GAP * 0.5, sy * (GAP * 0.5 + RING_W - 0.0025)))  # the pockets' decals inside the box
        # two bearer blocks under the stack, across it, under the segment's ends' lower thirds, their top edges
        # chamfered
        for x in (-0.55, 0.55):
            k.prism([(x - 0.12, 0.0), (x + 0.12, 0.0), (x + 0.12, BEARER - 0.02), (x + 0.1, BEARER),
                     (x - 0.1, BEARER), (x - 0.12, BEARER - 0.02)], "y", y0, y1, "concrete_dark")
        for layer in range(LAYERS):
            z_out = BEARER + layer * step       # the outer face's lowest point

            def outer_at(x: float, zo: float = z_out) -> float:
                return zo + (RADIUS + THICK) - math.sqrt((RADIUS + THICK) ** 2 - x * x)
            # timber packers under this one's outer face, on the segment below (or the bearers), across the stack
            for x in (-0.55, 0.55):
                if layer > 0:
                    zb = BEARER + (layer - 1) * step + THICK + RADIUS - math.sqrt(RADIUS ** 2 - x * x)
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
