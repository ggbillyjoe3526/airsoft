"""Subway's two kinds of grey cabinet (SM4): the trackside signal cabinet (model 13) at the tunnel mouth and the
electrical switch cabinets (model 30) in the plant room and the lower hall, each shut (the model list's default: the
station is abandoned), from the owner's photos (art/references/maps/subway/13-signal-cabinet and 30-switch-cabinet).

`signal_cabinet`: a lineside equipment case on a chamfered concrete plinth (photos 2 to 4): a galvanised lid ridged
across its middle and overhanging the body all round, its skirt the drip edge, two lifting eyes on its ridge; a pair
of doors set into a dark rebate, each a folded plate standing proud with a shadow gap round it, two strap hinges on
each outer edge, a T-handle with its padlock in the middle and a lock on the other leaf, two columns of pressed
louvres low on each leaf, a warning triangle, a blank label plate; a kick panel under the doors, a conduit into the
ground at the back. Its block is 0.9 x 0.8 m and 2.2 m high.

`switch_cabinet`: a two-bay floor-standing electrical enclosure (photo 3, shut): a door to each bay hung on its outer
edge (three hinge knuckles) with a swing handle in a moulded housing by the middle, a filter-fan grille low on each
(its fins set back in a frame), a warning triangle and a blank rating plate on each; a roof plate with its front lip
and an eye bolt at each corner, an exhaust grille high on each side, side bolts, all on a black plinth with grey
corner pieces. Its blocks are 2 m wide, 0.8 m deep and 2 m high.

SQ1 (owner, 2026-11-21: finer detail): the doors were flat quads drawn on a box; now every leaf, hinge, handle,
louvre and grille stands out of the body or sits back in it, so they cast their own shadows, and the lid is
galvanised against the powder-coated body.

Both light grey powder coat, scuffed and dusty, no writing. Each faces -y (its front, its doors).

Writes assets/models/props/signal_cabinet.glb and switch_cabinet.glb, each one vertex-coloured mesh filling its box
exactly (x its width, y its depth, z up; Godot: x across, y up, z deep).

Usage: python3 -I tools/blender/maps/cabinets.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET = 1600

# This script's own paints (sRGB), all greys off the teams' hues; their names pick the shader's kind
# (surface_kinds.by_name): the rebates' dark, steel hinges and locks, moulded plastic housings, a blank label.
wk.PAINT.update({
    "rebate_dark": 0x2a2a2c,
    "hinge_steel": 0x8a8a88,
    "lock_chrome": 0xb0b0ae,
    "cab_vent": 0x5c5e5c,
    "label_plate": 0xc8c6bc,
    "lid_galv": 0xbabdbc,
})


def front_quad(k: wk.Kit, x0: float, x1: float, z0: float, z1: float, y: float, mat: str) -> None:
    """A rectangle on a face looking towards -y, at depth y."""
    k.quad([(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], mat)


def leaf(k: wk.Kit, x0: float, x1: float, z0: float, z1: float, yb: float, yf: float, edge: float, mat: str) -> None:
    """A plate facing -y from its back at yb (inside what it stands on) to its face at yf, its front edges folded
    back by `edge` (a door's or a panel's rounded fold, catching the light)."""
    def ring(y: float, i: float) -> list:
        return [(x0 + i, y, z0 + i), (x1 - i, y, z0 + i), (x1 - i, y, z1 - i), (x0 + i, y, z1 - i)]
    k.loft([ring(yb, 0.0), ring(yf + edge, 0.0), ring(yf, edge)], mat)


def warning(k: wk.Kit, x: float, z: float, y: float, size: float) -> None:
    """A yellow warning triangle with a black border and a black flash (no words), stuck on a face looking -y."""
    h = size * 0.87
    k.quad([(x - size * 0.5, y, z), (x + size * 0.5, y, z), (x, y, z + h)], "hazard_black")
    s = size * 0.74
    zb = z + (size - s) * 0.29
    k.quad([(x - s * 0.5, y - 0.0006, zb), (x + s * 0.5, y - 0.0006, zb), (x, y - 0.0006, zb + s * 0.87)],
           "label_yellow")
    u, yb = size * 0.1, y - 0.0012  # the flash: two slanted wedges
    k.quad([(x + 0.3 * u, yb, zb + 4.4 * u), (x - 0.9 * u, yb, zb + 1.9 * u), (x + 0.4 * u, yb, zb + 2.2 * u)],
           "hazard_black")
    k.quad([(x - 0.4 * u, yb, zb + 2.5 * u), (x + 0.9 * u, yb, zb + 2.2 * u), (x - 0.4 * u, yb, zb + 0.5 * u)],
           "hazard_black")


def hole(k: wk.Kit, centre: tuple, r: float, axis: str, mat: str = "rebate_dark", seg: int = 8) -> None:
    """A dark round hole drawn on a face looking along `axis` ("x", "-x", "y", "-y")."""
    cx, cy, cz = centre
    pts = []
    for i in range(seg):
        a, b = r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg)
        pts.append((cx, cy + a, cz + b) if axis.endswith("x") else (cx + a, cy, cz + b))
    d = -1.0 if axis.startswith("-") else 1.0
    k.fan(pts, (d, 0.0, 0.0) if axis.endswith("x") else (0.0, d, 0.0), mat)


def signal_cabinet() -> tuple:
    hw, hd, high = 0.45, 0.4, 2.2
    k = wk.Kit("signal_cabinet")
    # the plinth: a cast slab, its top edges chamfered
    k.loft([[(-hw, -hd, z), (hw, -hd, z), (hw, hd, z), (-hw, hd, z)] for z in (0.0, 0.1)] +
           [[(-hw + 0.02, -hd + 0.02, 0.12), (hw - 0.02, -hd + 0.02, 0.12), (hw - 0.02, hd - 0.02, 0.12),
             (-hw + 0.02, hd - 0.02, 0.12)]], "concrete_dark", cap0=False)
    k.bolts([(x, y, 0.12) for x in (-0.3, 0.3) for y in (-hd + 0.05, hd - 0.05)], 0.014, 0.012, "z", "rust", seg=6)
    bx, f, b, top = 0.405, -0.33, 0.36, 2.02
    k.panel((-bx, f, 0.12), (bx, b, top), "cab_grey", step=0.25, skip=("-z",))
    k.mark("plinth, body")
    # the lid: a galvanised skirt round the body's top (its drip edge), a ridged top over it, eyes on the ridge
    zs, zt = 2.0, 2.08
    k.blk((-hw, -hd, zs), (hw, -hd + 0.012, zt), "lid_galv")
    k.blk((-hw, hd - 0.012, zs), (hw, hd, zt), "lid_galv")
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * hw, sx * (hw - 0.012)))
        k.blk((x0, -hd + 0.012, zs), (x1, hd - 0.012, zt), "lid_galv")
    ridge = 0.05
    k.prism([(-hd, zt), (hd, zt), (hd, 2.12), (ridge, 2.155), (-hd, 2.1)], "x", -hw, hw, "lid_galv")
    # its top again as a fine sheet a hair over it, so the bake has corners for the galvanising's spangle
    rows = [(-hd + (ridge + hd) * i / 4, 2.1 + 0.055 * i / 4) for i in range(5)] + \
        [(ridge + (hd - ridge) * i / 3, 2.155 - 0.035 * i / 3) for i in range(1, 4)]
    k.loft([[(-hw + 2 * hw * j / 6, y, z + 0.0015) for j in range(7)] for y, z in rows], "lid_galv", cap0=False,
           cap1=False, closed=False)
    for x in (-0.3, 0.3):
        prof = [(-0.05, 2.13), (0.05, 2.13), (0.05, 2.165), (0.03, 2.192), (0.0, 2.2), (-0.03, 2.192),
                (-0.05, 2.165)]
        k.prism(prof, "x", x - 0.005, x + 0.005, "steel_bare", offset=(0.0, ridge, 0.0))
        for s in (-1.0, 1.0):
            hole(k, (x + s * 0.0056, ridge, 2.173), 0.012, "x" if s > 0 else "-x")
        k.bolts([(x + 0.005, ridge + dy, 2.162) for dy in (-0.032, 0.032)], 0.007, 0.004, "x", "steel_bare", seg=4)
    k.mark("lid")
    # the doors: two folded leaves proud of a dark rebate, a kick panel under them
    front_quad(k, -bx + 0.02, bx - 0.02, 0.13, 1.975, f - 0.0008, "rebate_dark")
    d = f - 0.016                              # the leaves' faces
    for x0, x1 in ((-0.383, -0.004), (0.004, 0.383)):
        leaf(k, x0, x1, 0.31, 1.962, f + 0.002, d, 0.006, "cab_grey")
    leaf(k, -0.383, 0.383, 0.14, 0.295, f + 0.002, f - 0.009, 0.004, "cab_grey")
    k.bolts([(x, f - 0.009, 0.217) for x in (-0.34, 0.34)], 0.007, 0.004, "-y", "steel_bare", seg=4)
    # strap hinges on the outer edges: a knuckle on the frame, a strap across the leaf with two bolts
    for sx in (-1.0, 1.0):
        for z in (0.46, 1.74):
            k.cyl((sx * 0.391, d + 0.004, z), 0.009, 0.1, "hinge_steel", seg=8)
            xa, xb = sorted((sx * 0.383, sx * 0.25))
            k.blk((xa, d - 0.004, z + 0.03), (xb, d + 0.001, z + 0.07), "hinge_steel")
            k.bolts([(sx * xx, d - 0.004, z + 0.05) for xx in (0.3, 0.36)], 0.007, 0.004, "-y", "steel_bare", seg=4)
    # the T-handle on the right leaf, its padlock through the hasp at the gap; a lock on the left leaf
    leaf(k, 0.03, 0.075, 1.0, 1.24, d + 0.002, d - 0.006, 0.002, "hinge_steel")
    k.sqbar((0.052, d - 0.006, 1.12), (0.052, d - 0.035, 1.12), 0.018, "lock_chrome")
    k.sqbar((0.03, d - 0.044, 1.12), (0.16, d - 0.044, 1.12), 0.018, "lock_chrome", h=0.022)
    k.blk((-0.026, d - 0.016, 1.045), (0.026, d + 0.001, 1.07), "hinge_steel")  # the hasp and staple
    k.blk((-0.022, -hd, 0.975), (0.022, d - 0.012, 1.03), "steel_bare")  # the padlock, its shackle
    k.loft([[(-0.013, d - 0.02 + dy, z), (0.013, d - 0.02 + dy, z), (0.013, d - 0.02 + dy, z + 0.03),
             (-0.013, d - 0.02 + dy, z + 0.03)] for dy, z in ((0.004, 1.03), (0.0, 1.03))], "lock_chrome",
           cap0=False, cap1=False)
    k.bar((0.0, d - 0.02, 1.03), (0.0, d - 0.02, 1.062), 0.005, "lock_chrome", seg=4)
    k.cyl((-0.06, d, 1.12), 0.014, -0.008, "lock_chrome", seg=8, axis="y")
    hole(k, (-0.06, d - 0.0085, 1.12), 0.005, "-y")
    # pressed louvres low on each leaf, two columns: a hood over a dark slot
    for cx in (-0.19, 0.19):
        for col in (-0.055, 0.055):
            x0, x1 = cx + col - 0.045, cx + col + 0.045
            for i in range(8):
                z = 0.42 + i * 0.046
                k.prism([(d + 0.001, z), (d - 0.012, z), (d + 0.001, z + 0.03)], "x", x0, x1, "cab_grey")
                k.quad([(x0, d + 0.001, z - 0.0006), (x1, d + 0.001, z - 0.0006), (x1, d - 0.012, z - 0.0006),
                        (x0, d - 0.012, z - 0.0006)], "rebate_dark")
    k.mark("doors")
    warning(k, -0.19, 1.47, d - 0.001, 0.13)
    leaf(k, 0.1, 0.28, 1.8, 1.86, d + 0.001, d - 0.003, 0.001, "label_plate")
    k.bolts([(x, d - 0.003, 1.83) for x in (0.112, 0.268)], 0.005, 0.002, "-y", "steel_bare", seg=4)
    # the conduit at the back, from the plinth up into the body, clipped on
    k.bar((0.0, b + 0.012, 0.12), (0.0, b + 0.012, 0.75), 0.026, "plinth", seg=8)
    k.bar((0.0, b + 0.012, 0.12), (0.0, b - 0.01, 0.0), 0.026, "plinth", seg=8)
    for z in (0.3, 0.6):
        k.blk((-0.04, b, z), (0.04, b + 0.04, z + 0.025), "hinge_steel")
    # the sides: an earth boss low down, a row of rivets under the lid
    for sx in (-1.0, 1.0):
        k.bolts([(sx * bx, y, 1.96) for y in (-0.25, 0.0, 0.25)], 0.007, 0.004, "x" if sx > 0 else "-x",
                "steel_bare", seg=4)
    k.cyl((bx, 0.2, 0.3), 0.016, 0.03, "hinge_steel", seg=6, axis="x")
    k.mark("fittings")
    return k.build(), (-hw, -hd, 0.0), (hw, hd, high)


def grille(k: wk.Kit, x0: float, x1: float, z0: float, z1: float, y: float, fins: int, deep: float) -> None:
    """A moulded grille on a face looking -y at y: its frame `deep` proud, a dark inside and slanted fins set back
    in it, each shedding down and out."""
    w = 0.022
    leaf(k, x0, x1, z0, z0 + w, y + 0.002, y - deep, 0.004, "cab_vent")
    leaf(k, x0, x1, z1 - w, z1, y + 0.002, y - deep, 0.004, "cab_vent")
    leaf(k, x0, x0 + w, z0 + w, z1 - w, y + 0.002, y - deep, 0.004, "cab_vent")
    leaf(k, x1 - w, x1, z0 + w, z1 - w, y + 0.002, y - deep, 0.004, "cab_vent")
    front_quad(k, x0 + w, x1 - w, z0 + w, z1 - w, y - 0.0008, "rebate_dark")
    step = (z1 - z0 - 2 * w) / fins
    for i in range(fins):
        z = z0 + w + i * step
        k.prism([(y - 0.002, z + step * 0.15), (y - deep + 0.006, z), (y - deep + 0.006, z + step * 0.25),
                 (y - 0.002, z + step * 0.85)], "x", x0 + w, x1 - w, "cab_vent")


def switch_cabinet() -> tuple:
    hw, hd, high = 1.0, 0.4, 2.0
    k = wk.Kit("switch_cabinet")
    # the plinth: black panels between grey corner pieces, one under the bays' join
    k.blk((-hw + 0.03, -hd + 0.045, 0.0), (hw - 0.03, hd - 0.03, 0.1), "plinth")
    for x in (-hw + 0.06, 0.0, hw - 0.06):
        for y0, y1 in ((-hd + 0.035, -hd + 0.13), (hd - 0.12, hd - 0.02)):
            k.blk((x - 0.06, y0, 0.0), (x + 0.06, y1, 0.1), "cab_dark")
    bx, f, top = 0.985, -0.36, 1.96
    k.panel((-bx, f, 0.1), (bx, hd, top), "cab_grey", step=0.4, skip=("-z", "+z"))
    # the roof: a plate overhanging a hair, its lip down at the front, an eye bolt at each corner
    k.blk((-hw, -0.385, top), (hw, hd, 1.975), "cab_grey")
    k.blk((-hw, -0.392, 1.94), (hw, -0.378, 1.975), "cab_grey")
    for x in (-hw + 0.08, hw - 0.08):
        for y in (-0.3, hd - 0.08):
            k.cyl((x, y, 1.975), 0.016, 0.006, "hinge_steel", seg=6)
            k.prism([(0.022 * math.cos(2 * math.pi * i / 8 + 0.39), 1.987 + 0.0135 * math.sin(
                2 * math.pi * i / 8 + 0.39)) for i in range(8)], "y", y - 0.004, y + 0.004, "hinge_steel",
                offset=(x, 0.0, 0.0))
            for s in (-1.0, 1.0):
                k.fan([(x + 0.011 * math.cos(2 * math.pi * i / 8), y + s * 0.0045,
                        1.9875 + 0.006 * math.sin(2 * math.pi * i / 8)) for i in range(8)], (0.0, s, 0.0),
                      "rebate_dark")
    k.mark("plinth, body, roof")
    # the doors: a folded leaf to each bay, proud of a dark rebate, hung on its outer edge
    front_quad(k, -bx + 0.005, bx - 0.005, 0.11, 1.938, f - 0.0008, "rebate_dark")
    d = f - 0.02
    for cx in (-0.5, 0.5):
        s = 1.0 if cx > 0 else -1.0
        x0, x1 = sorted((s * 0.016, s * 0.975))
        leaf(k, x0, x1, 0.12, 1.928, f + 0.002, d, 0.008, "cab_grey")
        for z in (0.32, 1.03, 1.74):  # hinge knuckles at the outer edge
            k.cyl((s * 0.979, d + 0.008, z), 0.008, 0.08, "hinge_steel", seg=6)
        # the swing handle: a moulded housing, its lever folded down in it, the lock over it
        hx = s * 0.09
        leaf(k, hx - 0.03, hx + 0.03, 0.96, 1.22, d + 0.002, d - 0.01, 0.003, "cab_vent")
        leaf(k, hx - 0.014, hx + 0.014, 0.99, 1.16, d - 0.008, d - 0.0198, 0.004, "lock_chrome")
        k.cyl((hx, d - 0.01, 1.19), 0.011, -0.005, "lock_chrome", seg=8, axis="y")
        hole(k, (hx, d - 0.0155, 1.19), 0.004, "-y")
        # the filter fan low down, the rating plate and the warning triangle over it
        grille(k, cx - 0.14, cx + 0.14, 0.26, 0.54, d, 6, 0.018)
        warning(k, cx - s * 0.1, 1.42, d - 0.001, 0.15)
        leaf(k, cx - s * 0.1 - 0.075, cx - s * 0.1 + 0.075, 1.78, 1.84, d + 0.001, d - 0.003, 0.001, "label_plate")
        # the leaf's stiffening folds: a pressed line across under the vents and over the plate
        for z in (0.2, 1.87):
            leaf(k, cx - 0.42, cx + 0.42, z, z + 0.012, d + 0.001, d - 0.003, 0.0015, "cab_grey")
    k.mark("doors")
    # the sides: an exhaust grille high up, a row of bolts front and back
    for sx in (-1.0, 1.0):
        y0, y1 = -0.13, 0.15
        x0, x1 = sorted((sx * bx, sx * hw))
        k.blk((x0, y0, 1.56), (x1, y1, 1.58), "cab_vent")
        k.blk((x0, y0, 1.8), (x1, y1, 1.82), "cab_vent")
        k.blk((x0, y0, 1.58), (x1, y0 + 0.02, 1.8), "cab_vent")
        k.blk((x0, y1 - 0.02, 1.58), (x1, y1, 1.8), "cab_vent")
        xs = sx * (bx + 0.0008)
        k.quad([(xs, y0 + 0.02, 1.58), (xs, y1 - 0.02, 1.58), (xs, y1 - 0.02, 1.8), (xs, y0 + 0.02, 1.8)][::int(sx)],
               "rebate_dark")
        for i in range(5):
            z = 1.585 + i * 0.043
            k.prism([(sx * (bx + 0.001), z + 0.032), (sx * (hw - 0.002), z), (sx * (hw - 0.002), z + 0.008),
                     (sx * (bx + 0.001), z + 0.04)], "y", y0 + 0.02, y1 - 0.02, "cab_vent")
        k.bolts([(sx * bx, yy, z) for yy in (-0.32, hd - 0.05) for z in (0.3, 1.2)], 0.01, 0.006,
                "x" if sx > 0 else "-x", "steel_bare", seg=4)
    k.mark("sides")
    return k.build(), (-hw, -hd, 0.0), (hw, hd, high)


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint in ("cab_grey", "cab_dark"):
        col = wk.rusty(p, n, c, seed=23, amount=0.25)
        col = wt.mix(col, wk.lin(wk.GRIME), 0.25 * wt.smooth(0.55, 0.8, wt.fbm(p, 0.15, 25)))  # handprints, scuffs
        return wk.grime(p, n, col, seed=14)
    if paint == "lid_galv":  # the lid's spangle: blotches lighter and darker, dust on top
        col = wt.scale(c, 0.8 + 0.4 * wt.fbm(p, 0.035, 27))
        return wk.grime(p, n, col, seed=12, amount=0.8)
    if paint in ("rebate_dark", "label_yellow", "hazard_black"):
        return wt.mix(c, wk.lin(wk.GRIME), 0.15 * wt.fbm(p, 0.2, 29))
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
