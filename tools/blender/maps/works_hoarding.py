"""Subway's works hoardings (SM4, model 28): a small works compound walled in site hoarding on the platforms (the
"works" chicanes), from the owner's photos (art/references/maps/subway/28-works-hoarding, the painted panel hoardings in
photos 1 to 3): painted plywood sheets with chamfered cover battens standing well proud over their joints, screwed
on in rows (the fixings show as dots along the battens and across the sheets on the rails behind), a sloped capping
rail over the top overhanging both faces, a dark kick board with a bevelled top along the foot, L-shaped corner trims
up each corner, and in one long side a padlocked pair of ledged gates: each leaf framed in battens, its two strap
hinges on pintles at the post, a hasp and padlock where they meet, a drop bolt into the floor, a shadow gap round
and under them. Behind the sheets, timber studs and rails and raking braces down to sole plates weighed with
concrete blocks; inside on the platform a pallet of cement bags and a stack of boards (seen from the stairs).
Off-white paint, scuffed and grimy, no signs or names.

SQ1 (owner, 2026-11-21: finer detail): the cover strips were 12 mm decals that hardly read; now every batten, the
capping, the kick board and the corner trims stand 20 to 30 mm out of the sheets with chamfered edges, so each casts a
shadow line down the wall, and the gate is a real pair of leaves with its ironmongery.

Its six blocks (data/maps/subway.json) are three sizes, so three models, each built at its block's size, all 2.4 m
high: `works_hoarding` 3 x 1.9 m, `works_hoarding_short` 2 x 1.9 m and `works_hoarding_deep` 2 x 2.4 m.

Writes assets/models/props/works_hoarding*.glb, each one vertex-coloured mesh filling x -L/2..L/2, y -D/2..D/2,
z 0..2.4 exactly (Godot: x along, y up, z across).

Usage: python3 -I tools/blender/maps/works_hoarding.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET = 2700
HIGH = 2.4
SIZES = {"works_hoarding": (3.0, 1.9), "works_hoarding_short": (2.0, 1.9), "works_hoarding_deep": (2.0, 2.4)}
T = 0.02             # a sheet's thickness
STRIP = 0.075        # a cover batten's width
PROUD = 0.022        # how far a batten stands off the sheet
PANEL = 1.22         # a sheet's widest (the photos' hoardings: 1.22 m plywood sheets, a cover batten on each joint)
CAP = 0.07           # the capping rail's height
KICK = 0.15          # the kick board's height
OUT = 0.03           # how far the capping stands out of a wall's face (the back and end walls stand in by it)
TRIM = 0.1           # a corner trim's leg
GATE = 1.2           # the gate's opening
FLOOR_TOP = 0.013    # the compound floor's top: 3 mm over the platform's edge strips, which are drawn 1 cm over the
#                      floor (StationLook.strip_lift) and run under the compound: a 1 cm sheet's top lay in them

# This script's own paints (sRGB), greys and browns off the teams' hues; names pick the shader's kind
# (surface_kinds.by_name): the screws' and the gate's ironmongery steel, the dark shadow behind the gate's gaps.
wk.PAINT.update({
    "screw_steel": 0x5e5c5a,
    "hinge_steel": 0x4e4c4a,
    "gap_dark": 0x2a2826,
})
JITTER = {"stud": 0.08, "timber": 0.08, "concrete": 0.05, "hoard_strip": 0.03}


class Wall:
    """One side of the compound from a0 to a1 along `along` ("x" or "y"), its outer face at `at` looking `out` (+1 or
    -1): every piece is placed by (along, d, z), d the depth into the compound from the outer face (out of it < 0)."""

    def __init__(self, k: wk.Kit, a0: float, a1: float, along: str, at: float, out: float):
        self.k, self.a0, self.a1, self.along, self.at, self.out = k, a0, a1, along, at, out

    def p(self, a: float, d: float) -> float:
        return self.at - self.out * d

    def xy(self, a: float, d: float) -> tuple:
        return (a, self.p(a, d)) if self.along == "x" else (self.p(a, d), a)

    def box(self, b0: float, b1: float, d0: float, d1: float, z0: float, z1: float, mat: str,
            step: float = 0.0) -> None:
        p0, p1 = sorted((self.p(b0, d0), self.p(b0, d1)))
        lo = (b0, p0, z0) if self.along == "x" else (p0, b0, z0)
        hi = (b1, p1, z1) if self.along == "x" else (p1, b1, z1)
        if step > 0.0:
            self.k.panel(lo, hi, mat, step=step, skip=("-z",))
        else:
            self.k.blk(lo, hi, mat)

    def run(self, b0: float, b1: float, prof: list, mat: str) -> None:
        """A rail along the wall from b0 to b1, its section `prof` as (d, z)."""
        poly = [(self.p(0.0, d), z) for d, z in prof]
        self.k.prism(poly, self.along, b0, b1, mat)

    def upright(self, b0: float, b1: float, d0: float, d1: float, z0: float, z1: float, ch: float, mat: str) -> None:
        """An upright batten from z0 to z1, its section b0..b1 by d0..d1 (d1 its face), its face's edges chamfered."""
        sec = [(b0, d0), (b1, d0), (b1, d1 + ch), (b1 - ch, d1), (b0 + ch, d1), (b0, d1 + ch)]
        self.k.prism([self.xy(b, d) for b, d in sec], "z", z0, z1, mat)

    def dots(self, pts: list, d: float, r: float, mat: str = "screw_steel") -> None:
        """Screw heads drawn as small squares on a face at depth d (its outside), at (along, z) points."""
        for a, z in pts:
            q = [self.xy(a - r, d) + (z - r,), self.xy(a + r, d) + (z - r,), self.xy(a + r, d) + (z + r,),
                 self.xy(a - r, d) + (z + r,)]
            n = Vector(q[1]) - Vector(q[0])
            m = Vector(q[3]) - Vector(q[0])
            want = Vector((0.0, self.out, 0.0)) if self.along == "x" else Vector((self.out, 0.0, 0.0))
            self.k.quad(q if n.cross(m).dot(want) > 0 else list(reversed(q)), mat)


def batten(w: Wall, a: float, z0: float, z1: float, width: float = STRIP, proud: float = PROUD) -> None:
    """A cover batten centred at `a` from z0 to z1, screwed on every 0.4 m."""
    w.upright(a - width * 0.5, a + width * 0.5, 0.001, -proud, z0, z1, 0.006, "hoard_strip")
    n = max(2, int((z1 - z0) / 0.4))
    w.dots([(a, z0 + 0.12 + (z1 - z0 - 0.24) * i / (n - 1)) for i in range(n)], -proud - 0.0008, 0.006)


def wall(w: Wall, gate: bool, trim0: float, trim1: float) -> None:
    """A wall's sheets, kick board, capping, battens and fixings; the studs, rails and gate (when `gate`) behind and
    in it. trim0 and trim1: where the corner trims' legs end along it."""
    k = w.k
    top = HIGH - CAP
    g0 = g1 = m = 0.0
    if gate:
        m = (w.a0 + w.a1) * 0.5
        g0, g1 = m - GATE * 0.5, m + GATE * 0.5
        w.box(w.a0, g0, 0.0, T, 0.0, top, "hoard_paint", step=0.4)
        w.box(g1, w.a1, 0.0, T, 0.0, top, "hoard_paint", step=0.4)
    else:
        w.box(w.a0, w.a1, 0.0, T, 0.0, top, "hoard_paint", step=0.4)
    # the capping: sloped to shed outwards, overhanging both faces; the kick board, its top bevelled
    reach = OUT if w.along == "x" else -OUT  # the long walls' capping runs to the box's ends, the ends' between
    w.run(w.a0 - reach, w.a1 + reach,
          [(-OUT, top), (T + OUT, top), (T + OUT, HIGH - 0.006), (T + 0.01, HIGH), (-0.012, HIGH - 0.004),
           (-OUT, HIGH - 0.02)], "hoard_strip")
    kick = [(0.001, 0.0), (-0.02, 0.0), (-0.02, KICK - 0.02), (0.001, KICK)]
    spans = [(trim0, g0), (g1, trim1)] if gate else [(trim0, trim1)]
    for b0, b1 in spans:
        w.run(b0, b1, kick, "plinth")
    # battens over the sheets' joints (none across the gate), each sheet screwed to the rails behind
    n = max(1, math.ceil((w.a1 - w.a0 - 0.01) / PANEL))
    joints = [w.a0 + (w.a1 - w.a0) * i / n for i in range(1, n)]
    if gate:
        joints = [a for a in joints if a < g0 - 0.3 or a > g1 + 0.3]
    for a in joints:
        batten(w, a, KICK, top)
    edges = [trim0] + joints + ([g0, g1] if gate else []) + [trim1]
    edges.sort()
    for b0, b1 in zip(edges, edges[1:]):
        if gate and b0 >= g0 - 0.01 and b1 <= g1 + 0.01:
            continue
        span = b1 - b0 - 0.16
        if span < 0.2:
            continue
        cnt = max(2, int(span / 0.3) + 1)
        w.dots([(b0 + 0.08 + span * i / (cnt - 1), z) for i in range(cnt) for z in (0.3, 1.2, 2.1)], -0.0008, 0.005)
    # behind: studs at the joints and ends, rails across at three heights
    studs = [w.a0 + T + 0.035] + joints + [w.a1 - T - 0.035] + ([g0 - 0.04, g1 + 0.04] if gate else [])
    for a in studs:
        w.box(a - 0.035, a + 0.035, T, T + 0.07, 0.0, top, "stud")
    for z in (0.27, 1.17, 2.07):
        rails = [(w.a0 + T + 0.07, g0 - 0.075), (g1 + 0.075, w.a1 - T - 0.07)] if gate else \
            [(w.a0 + T + 0.07, w.a1 - T - 0.07)]
        for b0, b1 in rails:
            w.box(b0, b1, T + 0.07, T + 0.115, z, z + 0.07, "stud")
    if gate:
        gates(w, g0, g1, m)


def gates(w: Wall, g0: float, g1: float, m: float) -> None:
    """The pair of ledged gates from g0 to g1 meeting at m: posts, leaves framed in battens, strap hinges on pintles,
    hasp and padlock, a drop bolt; a dark shadow behind their gaps."""
    k = w.k
    top = HIGH - CAP
    lo, hi = 0.03, top - 0.02                     # a gap under them and under the capping
    gap = 0.008
    for a, s in ((g0, -1.0), (g1, 1.0)):          # the posts: a wide batten on the wall's end, standing out more
        w.upright(*sorted((a, a + s * 0.1)), 0.001, -0.03, 0.0, top, 0.008, "hoard_strip")
    w.box(g0 - 0.002, g1 + 0.002, T + 0.004, T + 0.008, 0.0, top, "gap_dark")  # the dark behind the gaps
    for b0, b1, hinge in ((g0 + gap, m - gap * 0.5, g0), (m + gap * 0.5, g1 - gap, g1)):
        s = -1.0 if hinge == g0 else 1.0
        w.box(b0, b1, 0.0, T, lo, hi, "hoard_paint", step=0.4)
        for a in (b0 + 0.035, b1 - 0.035):         # the leaf's frame: stiles, ledges top, middle and foot
            w.upright(a - 0.035, a + 0.035, 0.001, -PROUD, lo, hi, 0.005, "hoard_strip")
        for z0, z1 in ((lo, lo + 0.12), (1.06, 1.16), (hi - 0.1, hi)):
            w.run(b0 + 0.07, b1 - 0.07, [(0.001, z0), (-PROUD + 0.005, z0), (-PROUD, z0 + 0.005),
                                        (-PROUD, z1 - 0.005), (-PROUD + 0.005, z1), (0.001, z1)], "hoard_strip")
        w.box(b0 + 0.07, b1 - 0.07, T, T + 0.03, 0.4, 0.5, "stud")  # ledges inside
        w.box(b0 + 0.07, b1 - 0.07, T, T + 0.03, 1.8, 1.9, "stud")
        # strap hinges: a tapered strap across the leaf from its pintle on the post
        for z in (0.45, hi - 0.25):
            far = hinge - s * 0.42
            pts = [(hinge - s * 0.005, z - 0.022), (far, z - 0.012), (far, z + 0.012), (hinge - s * 0.005, z + 0.022)]
            k.prism(pts, "y" if w.along == "x" else "x", *sorted((w.p(0.0, -PROUD - 0.006), w.p(0.0, -PROUD))),
                    "hinge_steel")
            x, y = w.xy(hinge, -0.03)
            k.cyl((x, y, z - 0.04), 0.012, 0.08, "hinge_steel", seg=6)
            w.dots([(hinge - s * dd, z) for dd in (0.1, 0.22, 0.34)], -PROUD - 0.0068, 0.006, "steel_bare")
    # the hasp across the meeting stiles, its staple and padlock; a drop bolt on the left leaf into the floor
    w.box(m - 0.1, m + 0.1, -PROUD - 0.006, -PROUD, 1.08, 1.14, "hinge_steel")
    w.box(m - 0.022, m + 0.022, -0.05, -PROUD - 0.006, 1.0, 1.06, "rust")
    x, y = w.xy(m, -0.04)
    k.bar((x - 0.012, y, 1.06), (x - 0.012, y, 1.09), 0.004, "steel_bare", seg=4)
    k.bar((x + 0.012, y, 1.06), (x + 0.012, y, 1.09), 0.004, "steel_bare", seg=4)
    x, y = w.xy(m - 0.12, -PROUD - 0.012)
    k.bar((x, y, 0.0), (x, y, 0.42), 0.008, "steel_bare", seg=6)
    for z in (0.18, 0.36):
        w.box(m - 0.14, m - 0.1, -PROUD - 0.02, -PROUD + 0.002, z, z + 0.03, "hinge_steel")


def corner(k: wk.Kit, x: float, y: float, sx: float, sy: float) -> None:
    """An L-shaped trim up the corner whose outer faces meet at (x, y), the compound towards -sx, -sy."""
    t = 0.025
    pts = [(t, t), (-TRIM, t), (-TRIM, 0.0), (0.0, 0.0), (0.0, -TRIM), (t, -TRIM)]
    poly = [(x + sx * u, y + sy * v) for u, v in pts]
    k.prism(poly, "z", 0.0, HIGH - CAP, "hoard_strip")


def build(name: str, length: float, depth: float) -> object:
    hl, hd = length * 0.5, depth * 0.5
    k = wk.Kit(name)
    # The long walls' sheets run the full length, the ends' between them; the walls' outer faces stand inside the
    # box by what stands out of them (the capping; the gate's padlock at the front).
    yf, yb, xe = -(hd - 0.05), hd - OUT, hl - OUT
    wall(Wall(k, -xe, xe, "x", yf, -1.0), True, -xe + TRIM, xe - TRIM)
    wall(Wall(k, -xe, xe, "x", yb, 1.0), False, -xe + TRIM, xe - TRIM)
    for sx in (-1.0, 1.0):
        w = Wall(k, yf + T, yb - T, "y", sx * xe, sx)
        wall(w, False, yf + TRIM, yb - TRIM)
    for sx in (-1.0, 1.0):
        for y, sy in ((yf, -1.0), (yb, 1.0)):
            corner(k, sx * xe, y, sx, sy)
    k.mark("walls")
    # Braces inside, from the rails down to sole plates on the platform, each weighed with a concrete block.
    for sy, y_face in ((-1.0, yf), (1.0, yb)):
        y_in = y_face - sy * (T + 0.07)
        for x in (-hl * 0.55, hl * 0.55):
            k.sqbar((x, y_in, HIGH - 0.45), (x, y_in - sy * 0.62, 0.05), 0.06, "stud", h=0.04)
            y0, y1 = sorted((y_in - sy * 0.8, y_in - sy * 0.02))
            k.blk((x - 0.05, y0, 0.0), (x + 0.05, y1, 0.05), "stud")
            yc = y_in - sy * 0.62
            k.blk((x + 0.06, yc - 0.12, 0.0), (x + 0.3, yc + 0.12, 0.16), "concrete")
    # The compound's floor and what's left in it: a pallet of cement bags, a stack of boards against the wall.
    k.blk((-xe + T, yf + T, 0.0), (xe - T, yb - T, FLOOR_TOP), "concrete_dark")
    px = -hl * 0.35
    k.blk((px - 0.5, -0.4, 0.06), (px + 0.5, 0.4, 0.14), "timber")
    for x in (-0.45, 0.0, 0.45):
        k.blk((px + x - 0.05, -0.4, FLOOR_TOP), (px + x + 0.05, 0.4, 0.06), "timber")
    for bx, by, bz in [(-0.25, -0.18, 0.14), (0.25, -0.18, 0.14), (-0.25, 0.18, 0.14), (0.25, 0.18, 0.14),
                       (0.0, 0.0, 0.26)]:
        k.prism([(-0.22, 0.0), (0.22, 0.0), (0.24, 0.06), (0.2, 0.12), (-0.2, 0.12), (-0.24, 0.06)], "y", -0.17, 0.17,
                "concrete", offset=(px + bx, by, bz))  # a bag
    for i in range(4):
        z = 0.02 + i * 0.03
        k.blk((hl * 0.25 - 0.6, yb - 0.5 + i * 0.01, z), (hl * 0.25 + 0.6, yb - 0.23 + i * 0.01, z + 0.025),
              "timber")
    k.mark("inside")
    return k.build()


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint in ("hoard_paint", "hoard_strip"):
        col = wt.mix(c, wk.lin(wk.GRIME), 0.1 + 0.3 * wt.smooth(0.45, 0.85, wt.fbm(p, 0.25, 91)))
        low = 1.0 - wt.smooth(0.3, 1.2, p.z)
        scuff = wt.smooth(0.7, 0.9, wt.fbm(Vector((p.x * 3, p.y * 3, p.z * 8)), 0.2, 93)) * low
        col = wt.mix(col, wk.lin(wk.GRIME), 0.6 * scuff)  # boot scuffs and trolley knocks low down
        return wk.grime(p, n, col, seed=18)
    if paint in ("hinge_steel", "screw_steel"):
        return wk.rusty(p, n, wk.grime(p, n, c, seed=4, amount=0.5), seed=31, amount=0.4)
    return wk.grime(p, n, c, seed=4, amount=0.7)


def main() -> None:
    wk.check_colours(list(wk.PAINT))
    for name, (length, depth) in SIZES.items():
        wk.reset()
        ob = build(name, length, depth)
        wk.finish(ob, (-length * 0.5, -depth * 0.5, 0.0), (length * 0.5, depth * 0.5, HIGH))
        wk.bake(ob, weather, jitter=JITTER)
        wk.write(ob, name, BUDGET)
        if "--render" in sys.argv:
            out = sys.argv[sys.argv.index("--render") + 1].replace(".jpg", "_%s.jpg" % name)
            wk.render(wk.quarter_views(length, depth, HIGH), out,
                      "SM4 %s (Subway map prop, %g x %g x 2.4 m)" % (name.replace("_", " "), length, depth))


if __name__ == "__main__":
    main()
