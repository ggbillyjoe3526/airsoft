"""Subway's buffer stops (SM4, model 10): the stop at the dead west end of both tracks, from the owner's photos
(art/references/maps/subway/10-buffer-stop, the bolted steel stops, the yellow one in photo 5): a heavy box-section
beam across the track on two triangular side cheeks braced back to the tunnel's end wall, a lamp on top (photo 4,
unlit), two sprung buffers with black rubber-faced heads towards the track, a base frame bolted down to the track bed, hazard chevrons on the beam's
face. Works yellow, scuffed and rusty, black heads; no maker's name or plate.

Its two blocks (data/maps/subway.json) are 2.3 m across the track, 0.5 m along it and 1.2 m high, set against the end
wall, so the stop is a wall-anchored one: short cheeks instead of the photos' long sliding frames.

Writes assets/models/props/buffer_stop.glb, one vertex-coloured mesh filling x -1.15..1.15 (across the track),
y -0.25..0.25 (its buffers' faces at -y, its front, towards the track), z 0..1.2 exactly (Godot: x across, y up, z
along; the block's facing turns the front to the track).

Usage: python3 -I tools/blender/maps/buffer_stop.py [--render <sheet.jpg>]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
from mathutils import Vector  # noqa: E402

NAME = "buffer_stop"
BUDGET = 1500
HW, HD, HIGH = 1.15, 0.25, 1.2

BUFFER_Z = 0.86          # the buffers' height over the track bed (a car's buffers over its rails)
BUFFER_X = 0.88          # their middles from the stop's middle
BEAM = (0.0, 0.22, BUFFER_Z - 0.26, BUFFER_Z + 0.22)   # the beam's front and back (y), bottom and top (z)


def build() -> object:
    k = wk.Kit(NAME)
    # The base: a frame of two rolled-steel channels along the track bed and cross pieces, bolted down.
    for x in (-HW + 0.1, -0.35, 0.35, HW - 0.1):
        k.blk((x - 0.06, -0.1, 0.0), (x + 0.06, HD, 0.1), "works_yellow")
    k.blk((-HW + 0.04, -0.1, 0.0), (HW - 0.04, -0.02, 0.12), "works_yellow")
    k.blk((-HW + 0.04, HD - 0.08, 0.0), (HW - 0.04, HD, 0.12), "works_yellow")
    k.bolts([(x, y, 0.1) for x in (-HW + 0.1, -0.35, 0.35, HW - 0.1) for y in (-0.05, HD - 0.05)], 0.02, 0.025, "z",
            "rust", seg=8)
    k.mark("base")
    # The cheeks: a triangular plate at each end, its top edge sloping from the beam back to the wall, with a
    # stiffening flange round its edge.
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * (HW - 0.02), sx * (HW - 0.06)))
        k.prism([(BEAM[0], 0.1), (HD, 0.1), (HD, BEAM[3] + 0.08), (BEAM[1], BEAM[3]), (BEAM[0], BEAM[3])], "x", x0,
                x1, "works_yellow")
        xf0, xf1 = sorted((sx * HW, sx * (HW - 0.12)))
        k.blk((xf0, HD - 0.03, 0.1), (xf1, HD, BEAM[3] + 0.08), "works_yellow")  # the flange against the wall
        k.bolts([(sx * (HW - 0.06), HD - 0.03, z) for z in (0.3, 0.6, 0.9)], 0.018, 0.02, "-y", "rust", seg=6)
        # the second, inner cheek under each buffer
        xi0, xi1 = sorted((sx * (BUFFER_X - 0.14), sx * (BUFFER_X - 0.18)))
        k.prism([(BEAM[0], 0.1), (HD - 0.03, 0.1), (HD - 0.03, BEAM[2]), (BEAM[1], BEAM[2])], "x", xi0, xi1,
                "works_yellow")
    k.mark("cheeks")
    # The beam: a box section across the cheeks, its face plate, lifting eyes on top; the hazard chevrons painted on
    # its face between the buffers.
    k.panel((-HW + 0.02, BEAM[0], BEAM[2]), (HW - 0.02, BEAM[1], BEAM[3]), "works_yellow", step=0.3)
    k.blk((-HW + 0.02, BEAM[0] - 0.015, BEAM[2] - 0.02), (HW - 0.02, BEAM[0], BEAM[3] + 0.02), "works_yellow")
    for x in (-0.55, 0.55):
        k.prism([(-0.06, 0.0), (0.06, 0.0), (0.03, 0.08), (-0.03, 0.08)], "y", 0.06, 0.09, "works_yellow",
                offset=(x, 0.0, BEAM[3] + 0.02))
    k.bolts([(x, BEAM[0] - 0.015, z) for x in (-0.62, -0.31, 0.0, 0.31, 0.62) for z in (BEAM[2] + 0.04, BEAM[3] - 0.04)
             if abs(x) > 0.5 or abs(x) < 0.01], 0.016, 0.016, "-y", "rust", seg=6)
    w = 0.12
    for i in range(-4, 5):  # chevrons: black bands leaning across the face
        x = i * 0.13
        if abs(x) > BUFFER_X - 0.25:
            continue
        k.quad([(x - w * 0.5 - 0.06, BEAM[0] - 0.0165, BEAM[2]), (x + w * 0.5 - 0.06, BEAM[0] - 0.0165, BEAM[2]),
                (x + w * 0.5 + 0.06, BEAM[0] - 0.0165, BEAM[3]), (x - w * 0.5 + 0.06, BEAM[0] - 0.0165, BEAM[3])],
               "hazard_black")
    k.mark("beam")
    # The buffers: a square flange on the beam, the housing, the plunger and the round head with its black rubber
    # face (photos 1 and 2).
    for sx in (-1.0, 1.0):
        x = sx * BUFFER_X
        y0 = BEAM[0] - 0.015
        k.blk((x - 0.13, y0 - 0.03, BUFFER_Z - 0.13), (x + 0.13, y0, BUFFER_Z + 0.13), "works_yellow")
        k.lathe([(0.0, 0.1), (0.09, 0.085)], "works_yellow", segments=20, centre=(x, y0 - 0.03, BUFFER_Z), axis="y",
                cap=False)
        k.lathe([(0.0, 0.1), (-0.09, 0.085)], "works_yellow", segments=20, centre=(x, y0 - 0.03, BUFFER_Z),
                axis="y", cap=False)
        k.cyl((x, y0 - 0.12, BUFFER_Z), 0.05, -0.05, "steel_bare", seg=14, axis="y")
        k.cyl((x, -HD + 0.07, BUFFER_Z), 0.17, -0.03, "works_yellow", seg=24, axis="y")
        k.bolts([(x + dx, y0 - 0.03, BUFFER_Z + dz) for dx in (-0.1, 0.1) for dz in (-0.1, 0.1)], 0.016, 0.018, "-y",
                "rust", seg=6)
        k.blk((x - 0.17, -HD, BUFFER_Z - 0.17), (x + 0.17, -HD + 0.04, BUFFER_Z + 0.17), "hazard_black")
    # Braces from the beam's back down to the base, and a lamp on the beam's middle (its lens dark: unlit).
    for x in (-0.45, 0.45):
        k.sqbar((x, BEAM[1] - 0.04, BEAM[2]), (x, HD - 0.06, 0.12), 0.07, "works_yellow")
    k.blk((-0.09, 0.03, BEAM[3] + 0.02), (0.09, 0.19, BEAM[3] + 0.06), "works_yellow")
    k.cyl((0.0, 0.11, BEAM[3] + 0.06), 0.075, HIGH - BEAM[3] - 0.06, "hazard_black", seg=10)
    k.cyl((0.0, 0.035, BEAM[3] + 0.135), 0.055, -0.01, "glass", seg=10, axis="y")
    k.mark("buffers")
    return k.build()


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint == "works_yellow":
        col = wk.rusty(p, n, c, seed=19, amount=0.5)
        col = wt.mix(col, wk.lin(wk.SOOT), 0.3 * wt.fbm(p, 0.3, 21))  # tunnel soot
        return wk.grime(p, n, col, seed=8)
    if paint == "hazard_black":
        return wt.mix(c, wk.lin("steel_bare"), 0.25 * wt.fbm(p, 0.05, 23))  # rubbed by a train's buffers
    return wk.grime(p, n, wk.rusty(p, n, c, seed=7, amount=0.4, streaks=False), seed=2)


def main() -> None:
    wk.reset()
    wk.check_colours(list(wk.PAINT))
    ob = build()
    wk.finish(ob, (-HW, -HD, 0.0), (HW, HD, HIGH))
    wk.bake(ob, weather)
    wk.write(ob, NAME, BUDGET)
    if "--render" in sys.argv:
        wk.render(wk.quarter_views(2 * HW, 2 * HD, HIGH), sys.argv[sys.argv.index("--render") + 1],
                  "SM4 buffer stop (Subway map prop, 2.3 x 0.5 x 1.2 m)")


if __name__ == "__main__":
    main()
