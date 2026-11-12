"""Subway's two kinds of grey cabinet (SM4): the trackside signal cabinet (model 13) at the tunnel mouth and the
electrical switch cabinets (model 30) in the plant room and the lower hall, each shut (the model list's default: the
station is abandoned), from the owner's photos (art/references/maps/subway/13-signal-cabinet and 30-switch-cabinet).

`signal_cabinet`: a lineside equipment case on a concrete plinth (photos 2 and 3): a sloping rain lid overhanging the
body with two lifting eyes, a pair of doors with a padlocked handle and three hinges a side, louvred vents in their
foot, a plain warning plate, a conduit into the ground at the back. Its block is 0.9 x 0.8 m and 2.2 m high.

`switch_cabinet`: a two-bay floor-standing electrical enclosure (photo 3, shut): a door to each bay with a swing
handle, a vent grille low on each, a warning plate on each, a flat roof with its rim, on a black plinth. Its blocks are
2 m wide, 0.8 m deep and 2 m high.

Both light grey powder coat, scuffed and dusty, no writing. Each faces -y (its front, its doors).

Writes assets/models/props/signal_cabinet.glb and switch_cabinet.glb, each one vertex-coloured mesh filling its box
exactly (x its width, y its depth, z up; Godot: x across, y up, z deep).

Usage: python3 -I tools/blender/maps/cabinets.py [--render <sheet.jpg>]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET = 800


def front_quad(k: wk.Kit, x0: float, x1: float, z0: float, z1: float, y: float, mat: str) -> None:
    """A rectangle on a face looking towards -y, at depth y."""
    k.quad([(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], mat)


def warning(k: wk.Kit, x: float, z: float, y: float, size: float) -> None:
    """A plain yellow warning triangle with a black border (no symbol, no words)."""
    h = size * 0.87
    k.quad([(x - size * 0.5, y, z), (x + size * 0.5, y, z), (x, y, z + h)], "hazard_black")
    s = size * 0.72
    k.quad([(x - s * 0.5, y - 0.001, z + (size - s) * 0.3), (x + s * 0.5, y - 0.001, z + (size - s) * 0.3),
            (x, y - 0.001, z + (size - s) * 0.3 + s * 0.87)], "label_yellow")


def signal_cabinet() -> tuple:
    hw, hd, high = 0.45, 0.4, 2.2
    k = wk.Kit("signal_cabinet")
    k.blk((-hw, -hd, 0.0), (hw, hd, 0.12), "concrete_dark")  # the plinth
    bx, by0, by1, top = hw - 0.04, -hd + 0.09, hd - 0.03, 2.02  # the padlock standing out to the box
    k.panel((-bx, by0, 0.12), (bx, by1, top), "cab_grey", step=0.3, skip=("-z",))
    # the rain lid: sloping down to the front, overhanging all round to the box
    k.prism([(-hd, top), (hd, top), (hd, high), (-hd, high - 0.08)], "x", -hw, hw, "cab_grey")
    k.blk((-hw, -hd, top), (hw, -hd + 0.015, top + 0.06), "cab_grey")  # its drip edge
    for x in (-0.24, 0.24):  # lifting eyes
        k.prism([(-0.04, 0.0), (0.04, 0.0), (0.03, 0.07), (-0.03, 0.07)], "y", -0.006, 0.006, "steel_bare",
                offset=(x, 0.0, high - 0.07))
    # the doors: gaps round each leaf and between them, the handle with its padlock, hinges, louvres
    y = by0 - 0.002
    front_quad(k, -0.006, 0.006, 0.2, 1.96, y, "hazard_black")
    for x0, x1 in ((-bx + 0.03, -bx + 0.04), (bx - 0.04, bx - 0.03)):
        front_quad(k, x0, x1, 0.2, 1.96, y, "hazard_black")
    for z0, z1 in ((0.19, 0.2), (1.96, 1.97)):
        front_quad(k, -bx + 0.03, bx - 0.03, z0, z1, y, "hazard_black")
    k.blk((0.03, by0 - 0.03, 1.02), (0.06, by0, 1.24), "steel_bare")
    k.blk((0.02, by0 - 0.06, 1.09), (0.08, by0 - 0.03, 1.15), "steel_bare")
    k.blk((0.035, by0 - 0.085, 1.0), (0.075, by0 - 0.06, 1.06), "rust")  # the padlock
    k.bar((0.045, by0 - 0.07, 1.06), (0.065, by0 - 0.07, 1.1), 0.006, "steel_bare", seg=4)
    for sx in (-1.0, 1.0):
        for z in (0.4, 1.1, 1.8):
            k.cyl((sx * (bx - 0.005), by0 - 0.012, z - 0.05), 0.012, 0.1, "steel_bare", seg=8)
        for i in range(8):
            z = 0.28 + i * 0.05
            xa, xb = sorted((sx * 0.08, sx * (bx - 0.09)))
            k.prism([(by0, z), (by0 - 0.018, z - 0.01), (by0 - 0.018, z + 0.022), (by0, z + 0.03)], "x", xa, xb,
                    "cab_dark")
    warning(k, -0.22, 1.5, by0 - 0.002, 0.12)
    k.bolts([(x, -hd + 0.06, 0.12) for x in (-0.36, -0.12, 0.12, 0.36)] +
            [(x, hd - 0.06, 0.12) for x in (-0.36, -0.12, 0.12, 0.36)], 0.014, 0.012, "z", "rust", seg=6)
    k.bar((0.0, by1 + 0.01, 0.12), (0.0, hd - 0.04, 0.0), 0.03, "plinth", seg=6)  # the conduit behind
    k.bar((0.0, by1 + 0.01, 0.5), (0.0, by1 + 0.01, 0.12), 0.03, "plinth", seg=6)
    return k.build(), (-hw, -hd, 0.0), (hw, hd, high)


def switch_cabinet() -> tuple:
    hw, hd, high = 1.0, 0.4, 2.0
    k = wk.Kit("switch_cabinet")
    k.blk((-hw + 0.02, -hd + 0.03, 0.0), (hw - 0.02, hd - 0.02, 0.1), "plinth")
    k.panel((-hw, -hd + 0.04, 0.1), (hw, hd, high - 0.03), "cab_grey", step=0.33, skip=("-z",))
    k.blk((-hw, -hd + 0.03, high - 0.04), (hw, hd, high), "cab_grey")  # the roof with its rim
    k.blk((-hw, -hd, high - 0.05), (hw, -hd + 0.04, high), "cab_grey")
    y = -hd + 0.038
    front_quad(k, -0.008, 0.008, 0.12, high - 0.07, y, "hazard_black")  # the gap between the bays' doors
    for x0, x1 in ((-hw + 0.02, -hw + 0.03), (hw - 0.03, hw - 0.02)):
        front_quad(k, x0, x1, 0.12, high - 0.07, y, "hazard_black")
    for z0, z1 in ((0.11, 0.12), (high - 0.07, high - 0.06)):
        front_quad(k, -hw + 0.02, hw - 0.02, z0, z1, y, "hazard_black")
    for cx in (-0.5, 0.5):
        # the door's recessed panel edge, its swing handle, the vent grille low down, the warning plate
        hx = cx + 0.4
        k.blk((hx - 0.025, y - 0.02, 0.95), (hx + 0.025, y, 1.15), "plinth")
        k.blk((hx - 0.02, y - 0.038, 1.05), (hx + 0.02, y - 0.02, 1.25), "plinth")
        front_quad(k, cx - 0.2, cx + 0.2, 0.25, 0.45, y - 0.001, "grille")
        for i in range(7):
            z = 0.262 + i * 0.026
            k.prism([(y - 0.001, z), (y - 0.012, z - 0.003), (y - 0.012, z + 0.01), (y - 0.001, z + 0.013)], "x",
                    cx - 0.19, cx + 0.19, "cab_grey")
        warning(k, cx - 0.2, 1.55, y - 0.001, 0.14)
        for z in (0.35, high - 0.35):  # hinges at the outer edges
            xh = cx - 0.47 if cx < 0 else cx + 0.47
            k.cyl((xh, y - 0.01, z - 0.05), 0.012, 0.1, "steel_bare", seg=8)
    for x in (-hw + 0.08, hw - 0.08):  # lifting eyes on the roof's corners
        for yy in (-hd + 0.1, hd - 0.08):
            k.lathe([(0.0, 0.02), (0.0, 0.0)], "steel_bare", segments=8, centre=(x, yy, high), axis="z", cap=False)
    for sx in (-1.0, 1.0):  # the side panels' bolts
        k.bolts([(sx * hw, yy, z) for yy in (-hd + 0.1, hd - 0.06) for z in (0.3, 1.0, 1.7)], 0.01, 0.006,
                "x" if sx > 0 else "-x", "steel_bare", seg=4)
    return k.build(), (-hw, -hd, 0.0), (hw, hd, high)


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint in ("cab_grey", "cab_dark"):
        col = wk.rusty(p, n, c, seed=23, amount=0.25)
        col = wt.mix(col, wk.lin(wk.GRIME), 0.25 * wt.smooth(0.55, 0.8, wt.fbm(p, 0.15, 25)))  # handprints, scuffs
        return wk.grime(p, n, col, seed=14)
    return wk.grime(p, n, c, seed=4, amount=0.6)


def main() -> None:
    wk.check_colours(list(wk.PAINT))
    for make, title in ((signal_cabinet, "signal cabinet (0.9 x 0.8 x 2.2 m)"),
                        (switch_cabinet, "switch cabinet (2 x 0.8 x 2 m)")):
        wk.reset()
        ob, lo, hi = make()
        wk.finish(ob, lo, hi)
        wk.bake(ob, weather)
        wk.write(ob, ob.name, BUDGET)
        if "--render" in sys.argv:
            out = sys.argv[sys.argv.index("--render") + 1].replace(".jpg", "_%s.jpg" % ob.name)
            wk.render(wk.quarter_views(hi[0] - lo[0], hi[1] - lo[1], hi[2]), out, "SM4 %s, Subway map prop" % title)


if __name__ == "__main__":
    main()
