"""Subway's engineering wagon (SM4, model 7): a works flat wagon left loaded on the north track, from the owner's
photos (art/references/maps/subway/07-engineering-wagon: the long sleeper-carrying flat wagons and the low-sided works
wagon) and the model list's default for its 2.6 m box (thread "Subway models", 2026-11-11: a loaded flat wagon that
fills it): a steel deck with timber cross-bearers on a channel underframe with works-yellow solebars, short stanchions
down both sides, loaded with two stacks of concrete sleepers on timber dunnage and, over them, a load of kit under a
lashed tarpaulin, its straps ratcheted to the solebars. No lettering, no livery.

Its block (4 x 2.2 m and 2.6 m high, data/maps/subway.json) stands off the main rails, so the wagon stands on a length
of works track (works_kit.py).

Writes assets/models/props/engineering_wagon.glb, one vertex-coloured mesh filling x -2..2 (along the track),
y -1.1..1.1, z 0..2.6 exactly (Godot: x along, y up, z across).

Usage: python3 -I tools/blender/maps/engineering_wagon.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
from mathutils import Vector  # noqa: E402

NAME = "engineering_wagon"
BUDGET = 3000
HL, HD, HIGH = 2.0, 1.1, 2.6

DECK_X = 1.86          # the deck's half length
DECK_Y = 1.04          # the deck's half width (the stanchions stand outside it, to the box's side)
SLEEPER = (0.26, 2.0, 0.2)   # a concrete sleeper: wide (x), long (across), tall
STACK_X = (-1.78, 0.12)      # each stack's -x end
PER_LAYER = 6
LAYERS = 3
TARP_X, TARP_Y = 1.74, 0.98  # the tarpaulin's half length and half width over the stacks


def tarp_h(x: float, y: float, z0: float) -> float:
    """The tarpaulin's height over (x, y): draped over a boxy load, lower at its ends, a sag between two crates."""
    u, v = x / TARP_X, y / TARP_Y
    body = 1.0 - max(abs(u) ** 6.0, abs(v) ** 4.0)
    sag = 0.12 * math.exp(-((u - 0.1) / 0.18) ** 2) * (1.0 - abs(v) ** 2)  # a dip between the two crates under it
    lump = 0.05 * wt.fbm(Vector((x, y, 0.0)), 0.6, 41)
    return z0 + (HIGH - z0) * max(0.0, body - sag) * (0.94 + lump)


def build() -> object:
    k = wk.Kit(NAME)
    rail_top = k.works_track(-HL, HL, sleeper_len=1.6, pitch=0.62)
    k.mark("track")
    top = wk.underframe(k, HL, 0.82, 1.15, 0.3, rail_top, "frame_black", buffer_y=0.55)
    for s in (-1.0, 1.0):  # the solebars' outer faces in works yellow
        y0, y1 = sorted((s * 0.82, s * 0.835))
        k.blk((-HL + 0.12, y0, top - 0.26), (HL - 0.12, y1, top), "works_yellow")
    k.mark("underframe")
    deck = top + 0.04
    k.blk((-DECK_X, -DECK_Y, top), (DECK_X, DECK_Y, deck), "frame_black")
    for i in range(7):  # cross-bearers, the sleepers' dunnage on the deck
        x = -DECK_X + 0.12 + i * (2 * DECK_X - 0.24) / 6
        k.blk((x - 0.05, -DECK_Y + 0.04, deck), (x + 0.05, DECK_Y - 0.04, deck + 0.07), "timber")
    # Stanchions: short steel posts in pockets down both sides, standing out to the box's side.
    for s in (-1.0, 1.0):
        y0, y1 = sorted((s * DECK_Y, s * HD))
        for x in (-1.6, -0.8, 0.0, 0.8, 1.6):
            k.blk((x - 0.04, y0, top - 0.12), (x + 0.04, y1, deck + 0.55), "works_yellow")
            k.blk((x - 0.06, y0, top - 0.14), (x + 0.06, y1, top - 0.04), "frame_black")
    k.mark("deck")
    # Two stacks of concrete sleepers across the wagon, three layers on timber dunnage.
    sw, sl, sh = SLEEPER
    z = deck + 0.07
    for layer in range(LAYERS):
        for x0 in STACK_X:
            for i in range(PER_LAYER):
                x = x0 + i * (sw + 0.03)
                # its ends chamfered, its top a little narrower: the sleeper's trapezoid section
                k.prism([(x, z), (x + sw, z), (x + sw - 0.025, z + sh), (x + 0.025, z + sh)], "y", -sl * 0.5,
                        sl * 0.5, "concrete")
        z += sh
        if layer < LAYERS - 1:
            for x0 in STACK_X:
                for y in (-0.6, 0.6):
                    k.blk((x0, y - 0.05, z), (x0 + PER_LAYER * (sw + 0.03) - 0.03, y + 0.05, z + 0.05), "timber")
            z += 0.05
    k.mark("sleepers")
    # The tarpaulin over a load of kit on the top layer, lashed down by four straps.
    z0 = z
    bm = k.bm
    nx, ny = 18, 10
    grid = []
    for j in range(ny + 1):
        y = -TARP_Y + 2 * TARP_Y * j / ny
        grid.append([bm.verts.new(Vector((-TARP_X + 2 * TARP_X * i / nx, y,
                                          tarp_h(-TARP_X + 2 * TARP_X * i / nx, y, z0)))) for i in range(nx + 1)])
    faces = [bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])) for j in range(ny)
             for i in range(nx)]
    # the tarp's skirt hanging down over the top layer's sides and ends
    edge = [grid[0][i] for i in range(nx + 1)] + [grid[j][nx] for j in range(1, ny + 1)] + \
        [grid[ny][i] for i in range(nx - 1, -1, -1)] + [grid[j][0] for j in range(ny - 1, 0, -1)]
    low = [bm.verts.new(Vector((v.co.x * 1.012, v.co.y * 1.02, z0 - 0.16))) for v in edge]
    for a in range(len(edge)):
        b = (a + 1) % len(edge)
        faces.append(bm.faces.new((edge[a], edge[b], low[b], low[a])))
    for f in faces:
        f.normal_update()
    import bmesh
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    k._faces(faces, "tarp")
    k.mark("tarp")
    for x in (-1.25, -0.42, 0.42, 1.25):  # straps over the tarp to the solebars
        pts = []
        for j in range(ny + 1):
            y = -TARP_Y + 2 * TARP_Y * j / ny
            pts.append((x, y * 1.01, tarp_h(x, y, z0) + 0.012))
        pts = [(x, -HD + 0.01, top - 0.05), (x, -TARP_Y * 1.02, z0 - 0.16)] + pts + \
            [(x, TARP_Y * 1.02, z0 - 0.16), (x, HD - 0.01, top - 0.05)]
        k.loft([[(px - 0.025, py, pz), (px + 0.025, py, pz)] for px, py, pz in pts], "strap", cap0=False, cap1=False,
               closed=False)  # a flat strap, one face up and out
        k.blk((x - 0.04, -HD, top - 0.25), (x + 0.04, -HD + 0.04, top - 0.12), "steel_bare")  # its ratchet
    k.mark("straps")
    return k.build()


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint in ("frame_black", "works_yellow"):
        col = wk.rusty(p, n, c, seed=9, amount=0.55)
        return wk.grime(p, n, col, seed=3)
    if paint == "concrete":
        col = wt.mix(c, wk.lin("concrete_dark"), 0.5 * wt.fbm(p, 0.2, 51))
        return wk.grime(p, n, col, seed=5, amount=0.6)
    if paint == "tarp":
        col = wt.mix(c, wk.lin(wk.GRIME), 0.3 * wt.fbm(p, 0.3, 53))  # stains in the folds
        return wt.mix(col, wk.lin(wk.DUST), max(0.0, n.z) * 0.25 * wt.fbm(p, 0.5, 55))
    if paint in ("rail", "wheel", "rust"):
        return wk.grime(p, n, wk.rusty(p, n, c, seed=7, amount=0.4, streaks=False), seed=2)
    return wk.grime(p, n, c, seed=4)


def main() -> None:
    wk.reset()
    wk.check_colours(list(wk.PAINT))
    ob = build()
    wk.finish(ob, (-HL, -HD, 0.0), (HL, HD, HIGH))
    wk.bake(ob, weather, jitter={"sleeper": 0.08, "timber": 0.07, "concrete": 0.05})
    wk.write(ob, NAME, BUDGET)
    if "--render" in sys.argv:
        wk.render(wk.quarter_views(2 * HL, 2 * HD, HIGH), sys.argv[sys.argv.index("--render") + 1],
                  "SM4 engineering wagon (Subway map prop, 4 x 2.2 x 2.6 m)")


if __name__ == "__main__":
    main()
