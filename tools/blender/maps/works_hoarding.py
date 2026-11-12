"""Subway's works hoardings (SM4, model 28): a small works compound walled in site hoarding on the platforms (the
"works" chicanes), from the owner's photos (art/references/maps/subway/28-works-hoarding, the painted panel hoardings in
photos 2 and 3): painted plywood panels 1.22 m wide with cover strips over their joints, a capping rail along the
top, a dark kick strip along the foot, a padlocked pair of gates in one long side; behind the panels, timber studs
and raking braces, and inside on the platform a pallet of cement bags and a stack of boards (seen from the stairs).
Off-white paint, scuffed and grimy, no signs or names.

Its six blocks (data/maps/subway.json) are three sizes, so three models, each built at its block's size, all 2.4 m
high: `works_hoarding` 3 x 1.9 m, `works_hoarding_short` 2 x 1.9 m and `works_hoarding_deep` 2 x 2.4 m.

Writes assets/models/props/works_hoarding*.glb, each one vertex-coloured mesh filling x -L/2..L/2, y -D/2..D/2,
z 0..2.4 exactly (Godot: x along, y up, z across).

Usage: python3 -I tools/blender/maps/works_hoarding.py [--render <sheet.jpg>]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET = 1500
HIGH = 2.4
SIZES = {"works_hoarding": (3.0, 1.9), "works_hoarding_short": (2.0, 1.9), "works_hoarding_deep": (2.0, 2.4)}
T = 0.02             # a panel's thickness
STRIP = 0.09         # a cover strip's width
CAP = 0.07           # the capping rail's height
POST = 0.1           # a corner post's side


def wall(k: wk.Kit, a0: float, a1: float, along: str, at: float, out: float, gate: bool) -> None:
    """One side of the compound from a0 to a1 along `along` ("x" or "y"), its outer face at `at` facing `out`."""
    def box(b0: float, b1: float, d0: float, d1: float, z0: float, z1: float, mat: str, step: float = 0.0) -> None:
        p0, p1 = sorted((at - out * d0, at - out * d1))
        lo = (b0, p0, z0) if along == "x" else (p0, b0, z0)
        hi = (b1, p1, z1) if along == "x" else (p1, b1, z1)
        if step > 0.0:
            k.panel(lo, hi, mat, step=step, skip=("-z",))
        else:
            k.blk(lo, hi, mat)

    box(a0, a1, 0.0, T, 0.0, HIGH - CAP, "hoard_paint", step=0.4)
    box(a0, a1, -0.004, T, 0.0, 0.14, "plinth")                     # the kick strip
    box(a0, a1, -0.01, T + 0.05, HIGH - CAP, HIGH, "hoard_strip")    # the capping rail
    n = max(1, round((a1 - a0) / 1.22))
    for i in range(1, n):  # cover strips over the joints
        a = a0 + (a1 - a0) * i / n
        box(a - STRIP * 0.5, a + STRIP * 0.5, -0.012, 0.0, 0.14, HIGH - CAP, "hoard_strip")
    for i in range(n + 1):  # studs behind, and a raking brace from every other one to the ground inside
        a = min(max(a0 + (a1 - a0) * i / n, a0 + 0.05), a1 - 0.05)
        box(a - 0.035, a + 0.035, T, T + 0.07, 0.0, HIGH - CAP, "stud")
    if gate:
        g0, g1 = (a0 + a1) * 0.5 - 0.6, (a0 + a1) * 0.5 + 0.6
        box(g0 - 0.03, g0 + 0.03, -0.006, 0.0, 0.14, HIGH - CAP, "hoard_strip")  # the gates' edge strips, the gap
        box(g1 - 0.03, g1 + 0.03, -0.006, 0.0, 0.14, HIGH - CAP, "hoard_strip")
        box((g0 + g1) * 0.5 - 0.003, (g0 + g1) * 0.5 + 0.003, -0.003, 0.0, 0.14, HIGH - CAP, "plinth")
        for g in (g0, g1):  # hinges: straps on the gates' outer edges
            for z in (0.5, 1.9):
                box(g + (0.02 if g == g0 else -0.32), g + (0.32 if g == g0 else -0.02), -0.01, 0.0, z, z + 0.04,
                    "steel_bare")
        m = (g0 + g1) * 0.5
        box(m - 0.12, m + 0.12, -0.02, 0.0, 1.05, 1.11, "steel_bare")  # the hasp and its padlock
        box(m - 0.03, m + 0.03, -0.05, -0.02, 0.98, 1.06, "rust")


def build(name: str, length: float, depth: float) -> object:
    hl, hd = length * 0.5, depth * 0.5
    k = wk.Kit(name)
    # Walls stop at the corner posts so no two faces lie on top of each other (coplanar faces render black).
    wall(k, -hl + POST, hl - POST, "x", -hd, -1.0, True)
    wall(k, -hl + POST, hl - POST, "x", hd, 1.0, False)
    wall(k, -hd + POST, hd - POST, "y", -hl, -1.0, False)
    wall(k, -hd + POST, hd - POST, "y", hl, 1.0, False)
    for sx in (-1.0, 1.0):  # the corners: a post closing the end walls onto the long ones
        for sy in (-1.0, 1.0):
            x0, x1 = sorted((sx * hl, sx * (hl - POST)))
            y0, y1 = sorted((sy * hd, sy * (hd - POST)))
            k.blk((x0, y0, 0.0), (x1, y1, HIGH - 0.02), "hoard_strip")
            k.blk((x0 + 0.01, y0 + 0.01, HIGH - 0.02), (x1 - 0.01, y1 - 0.01, HIGH), "hoard_strip")  # its cap
    k.mark("walls")
    # Braces inside, from the studs' tops down to sole plates on the platform.
    for sy in (-1.0, 1.0):
        y_in = sy * (hd - T - 0.06)
        for x in (-hl * 0.6, hl * 0.6):
            k.sqbar((x, y_in, HIGH - 0.4), (x, y_in - sy * 0.6, 0.05), 0.06, "stud", h=0.04)
            k.blk((x - 0.15, y_in - sy * 0.75 - 0.05, 0.0), (x + 0.15, y_in - sy * 0.55 + 0.05, 0.05), "stud")
    # The compound's floor and what's left in it: a pallet of cement bags, a stack of boards against the wall.
    k.blk((-hl + 0.1, -hd + 0.1, 0.0), (hl - 0.1, hd - 0.1, 0.01), "concrete_dark")
    px = -hl * 0.35
    k.blk((px - 0.5, -0.4, 0.0), (px + 0.5, 0.4, 0.14), "timber")
    for i, (bx, by, bz) in enumerate([(-0.25, -0.18, 0.14), (0.25, -0.18, 0.14), (-0.25, 0.18, 0.14),
                                      (0.25, 0.18, 0.14), (0.0, 0.0, 0.26)]):
        k.prism([(-0.22, 0.0), (0.22, 0.0), (0.24, 0.06), (0.2, 0.12), (-0.2, 0.12), (-0.24, 0.06)], "y", -0.17, 0.17,
                "concrete", offset=(px + bx, by, bz))  # a bag
    for i in range(4):
        z = 0.02 + i * 0.03
        k.blk((hl * 0.25 - 0.6, hd - 0.45 + i * 0.01, z), (hl * 0.25 + 0.6, hd - 0.18 + i * 0.01, z + 0.025), "timber")
    k.mark("inside")
    return k.build()


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint in ("hoard_paint", "hoard_strip"):
        col = wt.mix(c, wk.lin(wk.GRIME), 0.1 + 0.3 * wt.smooth(0.45, 0.85, wt.fbm(p, 0.25, 91)))
        low = 1.0 - wt.smooth(0.3, 1.2, p.z)
        scuff = wt.smooth(0.7, 0.9, wt.fbm(Vector((p.x * 3, p.y * 3, p.z * 8)), 0.2, 93)) * low
        col = wt.mix(col, wk.lin(wk.GRIME), 0.6 * scuff)  # boot scuffs and trolley knocks low down
        return wk.grime(p, n, col, seed=18)
    return wk.grime(p, n, c, seed=4, amount=0.7)


def main() -> None:
    wk.check_colours(list(wk.PAINT))
    for name, (length, depth) in SIZES.items():
        wk.reset()
        ob = build(name, length, depth)
        wk.finish(ob, (-length * 0.5, -depth * 0.5, 0.0), (length * 0.5, depth * 0.5, HIGH))
        wk.bake(ob, weather, jitter={"stud": 0.08, "timber": 0.08, "concrete": 0.05})
        wk.write(ob, name, BUDGET)
        if "--render" in sys.argv:
            out = sys.argv[sys.argv.index("--render") + 1].replace(".jpg", "_%s.jpg" % name)
            wk.render(wk.quarter_views(length, depth, HIGH), out,
                      "SM4 %s (Subway map prop, %g x %g x 2.4 m)" % (name.replace("_", " "), length, depth))


if __name__ == "__main__":
    main()
