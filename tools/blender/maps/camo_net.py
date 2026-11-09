"""Depot's camouflage net wall (Dev 3, the hall shell): assets/models/props/camo_net.glb, one 2 m section of the hall's
five net walls (2.8 m tall, 0.3 m deep), laid side by side along each net block (PropDressConfig.grid_cells).

From the owner's photos (references/maps/william-2026-11-09/camo_net_wall): woodland camouflage netting hung from a
rail and left to drape, scalloped between its ties along the top, folded as it hangs and bunched where its hem meets
the ground, a busy blotched pattern of dark greens, olive and brown, its cut leaves standing proud of the mesh. Here it
hangs on both sides of a scaffold frame (a tube upright in the middle of each section on a base plate, a top rail at
2.75 m with right-angle couplers), so a net wall reads the same from either side. In the game the net stops sight and
BBs, so it is modelled dense: you can't see through it.

The folds, ties and pattern repeat every 2 m, so sections side by side meet without a seam. Budget 1,500 triangles.
Plain vertex colours, no texture.

    python -I tools/blender/maps/camo_net.py <repo root>
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402  first: it sets up bpy and the replica helpers
import hardsurface as hs  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET = 1500
HALF = 1.0          # half the section's length
HEIGHT = 2.8
DEPTH = 0.15        # half the box's depth
COLS = 12           # the net's mesh grid along (one period of every fold and blotch; it backs the slits)
ROWS = 4
TEETH = 14          # leaf-cut teeth along a row (14 cm each)
TOOTH_ROWS = 20     # rows of them up the net, 13 cm apart (as fine as the budget allows)
CUT = 0.028         # the zigzag slit's height
TOOTH_PITCH = (2.69 - 0.06 - CUT - 0.01) / TOOTH_ROWS
BACK = 0.015        # how far the dark mesh hangs behind the leaves, so the coarse sheet never shows through them
SHEET = 0.105       # each net's mean distance from the middle
FOLD = 0.034        # how far a fold swings in or out
TIE_SAG = 0.06      # the sag between ties along the top
TIES = 4            # ties a section
RAIL_Z = 2.74
TUBE_R = 0.024
SEED = 31


def period(x: float, k: int) -> float:
    return 2.0 * math.pi * k * (x + HALF) / (2.0 * HALF)


def fold(x: float, z: float, side: float) -> float:
    """The net's swing in and out at (x, z): folds hanging from the ties, wider towards the hem; periodic in x."""
    t = 1.0 - z / HEIGHT
    a = math.sin(period(x, 6) + side * 0.9) * (0.45 + 0.55 * t)
    b = math.sin(period(x, 3) + 1.7 * z + side * 2.1) * 0.5 * t
    c = math.sin(period(x, 11) + 3.3 * z) * 0.18
    return FOLD * (a + b + c) / 1.4


def top_of(x: float) -> float:
    """The net's top edge: hanging from the rail on its ties, sagging between them."""
    u = (x + HALF) / (2.0 * HALF) * TIES
    f = u - math.floor(u)
    return RAIL_Z - 0.05 - TIE_SAG * math.sin(math.pi * f)


def blotch(x: float, z: float, side: float) -> str:
    """The pattern's colour at (x, z): layered waves, periodic in x, banded into four tones."""
    n = (math.sin(period(x, 2) + 2.3 * z + side) * 0.5 + math.sin(period(x, 5) - 3.1 * z + 0.7 * side) * 0.35
         + math.sin(period(x, 9) + 5.7 * z + 1.3) * 0.2 + math.sin(period(x, 1) + 0.8 * z + 2.0 * side) * 0.3)
    if n < -0.45:
        return "NetDark"
    if n < 0.05:
        return "NetGreen"
    if n < 0.5:
        return "NetOlive"
    return "NetBrown"


def net(b: hs.Builder, side: float, rng: random.Random) -> None:
    """One net, on the side `side` (-1 the model's front, +1 its back), facing out: the dark mesh draped in its folds,
    and over it the leaf-cut layer as in the photos: rows of zigzag cuts 13 cm apart (the photos' 8 cm would take twice the budget), each tooth a leaf hanging
    point down just off the mesh (its point a little further out, curling), coloured by the pattern, so the mesh shows
    between the rows and the teeth as the dark zigzag slits of a leaf-cut net. Odd rows are offset half a tooth, cut
    at the section's ends so sections side by side meet without a seam."""
    bm = b.bm
    grid = []
    for r in range(ROWS + 1):
        row = []
        for c in range(COLS + 1):
            x = -HALF + 2.0 * HALF * c / COLS
            z = top_of(x) * r / ROWS
            y = side * (SHEET + fold(x, z, side) - BACK + (0.02 if r == 0 else 0.0))  # the hem bunches on the ground
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    mesh = b.mat("NetMesh")
    for r in range(ROWS):
        for c in range(COLS):
            quad = [grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]]
            if side > 0.0:
                quad.reverse()
            bm.faces.new(quad).material_index = mesh
    w = 2.0 * HALF / TEETH
    tri = []    # (points, tone)

    def at(x: float, z: float, out: float) -> tuple:
        return (x, side * (SHEET + fold(x, z, side) + out), z)

    for r in range(TOOTH_ROWS):
        # the row's top: its down teeth hang from it, its up teeth stand between them `CUT` lower, so the mesh shows
        # through a zigzag slit between the two (and the next row's down teeth meet this row's up teeth's feet)
        zt = top_of(0.0) - 0.06 - r * TOOTH_PITCH
        h = TOOTH_PITCH - CUT
        zb = zt - h
        for c in range(TEETH):
            x0 = -HALF + c * w
            xm = x0 + 0.5 * w
            lift = 0.008 + rng.uniform(0.0, 0.005)
            curl = 0.006 + rng.uniform(0.0, 0.012)
            tone = blotch(xm, zt, side)
            if rng.random() < 0.08:
                tone = "NetLeaf"
            tri.append(([at(x0, zt, lift), at(xm, zb, lift + curl), at(x0 + w, zt, lift)], tone))
            # the up tooth to its right (its halves at the section's ends, so sections meet without a seam)
            xu = x0 + w
            a, l, rr = at(xu, zt - CUT, lift + curl), at(xu - 0.5 * w, zb - CUT, lift), at(xu + 0.5 * w, zb - CUT, lift)
            if c == TEETH - 1:
                tri.append(([at(HALF, zt - CUT, lift + curl), l, at(HALF, zb - CUT, lift)], tone))
                tri.append(([at(-HALF, zt - CUT, lift + curl), at(-HALF, zb - CUT, lift),
                             at(-HALF + 0.5 * w, zb - CUT, lift)], blotch(-HALF, zt, side)))
            else:
                tri.append(([a, l, rr], tone))
    for pts, tone in tri:
        # wind each to face out: counter-clockwise seen from its side
        (x1, _, z1), (x2, _, z2), (x3, _, z3) = pts
        ccw = (x2 - x1) * (z3 - z1) - (z2 - z1) * (x3 - x1) > 0.0
        if ccw != (side < 0.0):
            pts = pts[::-1]
        bm.faces.new([bm.verts.new(p) for p in pts]).material_index = b.mat(tone)


def scaffold(b: hs.Builder) -> None:
    """The scaffold: the upright in the middle on its base plate, the top rail along, a right-angle coupler where they
    meet."""
    mk.cylinder(b, (0.0, 0.0, 0.006), (0.0, 0.0, HEIGHT), TUBE_R, "Tube", sides=8, caps=False)
    b.box((-0.075, -0.075, 0.0), (0.075, 0.075, 0.006), "Tube")
    mk.cylinder(b, (-HALF, 0.0, RAIL_Z), (HALF, 0.0, RAIL_Z), TUBE_R, "Tube", sides=8, caps=False)
    b.box((-0.05, -0.04, RAIL_Z - 0.07), (0.05, 0.04, RAIL_Z + 0.05), "Coupler")
    # the ties: a short cord from the rail down to the net's top at each tie, both sides
    for k in range(TIES):
        x = -HALF + 2.0 * HALF * k / TIES + 0.009
        for side in (-1.0, 1.0):
            y = side * (SHEET + fold(x, top_of(x), side))
            pts = [(x - 0.008, side * TUBE_R, RAIL_Z), (x + 0.008, side * TUBE_R, RAIL_Z), (x + 0.008, y, top_of(x)),
                   (x - 0.008, y, top_of(x))]
            mk.quad(b, pts if side < 0.0 else pts[::-1], "Cord")
    # a cap on the upright, at the box's top
    mk.cylinder(b, (0.0, 0.0, HEIGHT - 0.03), (0.0, 0.0, HEIGHT), TUBE_R + 0.004, "Coupler", sides=8, caps=True)

COLOURS = {
    "NetMesh": (mk.PALETTE["forest"], 0.45), "NetDark": (mk.PALETTE["forest"], 0.9),
    "NetGreen": (mk.PALETTE["pine"], 0.78), "NetOlive": (mk.PALETTE["olive"], 0.62),
    "NetBrown": (mk.PALETTE["umber"], 0.85), "NetLeaf": (mk.PALETTE["litter"], 0.75), "Tube": mk.PALETTE["grey"],
    "Coupler": mk.PALETTE["steel"], "Cord": mk.PALETTE["umber"],
}


def main() -> None:
    hs.reset()
    mk.paints(COLOURS)
    rng = random.Random(SEED)
    b = hs.Builder("CamoNet", [])
    scaffold(b)
    for side in (-1.0, 1.0):
        net(b, side, rng)
    ob = b.build()
    # the nets' outermost folds and leaves reach the box's faces exactly
    out = max(v.co.y for v in ob.data.vertices)
    back = -min(v.co.y for v in ob.data.vertices)
    for v in ob.data.vertices:
        v.co.y *= DEPTH / (out if v.co.y > 0.0 else back)
    mk.clean(ob)
    mk.report(ob, "camo_net", BUDGET)
    mk.export_prop(ob, "camo_net")


if __name__ == "__main__":
    main()
