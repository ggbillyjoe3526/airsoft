"""Subway's buffer stops (SM4, model 10): the stop at the dead west end of both tracks, from the owner's photos
(art/references/maps/subway/10-buffer-stop, the bolted steel stops, the yellow one in photo 5): a heavy box-section
beam across the track on two triangular side cheeks braced back to the tunnel's end wall, a lamp on top (photo 4,
unlit), two sprung buffers with black rubber-faced heads towards the track, a base frame bolted down to the track
bed, hazard chevrons on the beam's face. Works yellow, scuffed and rusty, black heads; no maker's name or plate.

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
PEDESTAL_X = 0.78        # the pedestals' middles, over the running rails (gauge 1.5 m)
BEAM = (0.0, 0.22, BUFFER_Z - 0.26, BUFFER_Z + 0.22)   # the beam's front and back (y), bottom and top (z)


def build() -> object:
    k = wk.Kit(NAME)
    # The pedestals (photo 1): a closed trapezoid box under each buffer, standing on its rail on a base plate bolted
    # through to the rail, its back wider than its top; an end plate at each side closing the beam.
    for sx in (-1.0, 1.0):
        x = sx * PEDESTAL_X
        k.blk((x - 0.2, -0.16, 0.0), (x + 0.2, HD, 0.04), "works_yellow")  # the base plate
        k.bolts([(x + dx, y, 0.04) for dx in (-0.15, 0.15) for y in (-0.11, 0.05, 0.2)], 0.022, 0.022, "z", "rust",
                seg=6)
        k.prism([(-0.13, 0.04), (HD - 0.02, 0.04), (0.2, BEAM[2]), (0.02, BEAM[2])], "x", x - 0.13, x + 0.13,
                "works_yellow")  # the pedestal's sloping front, its back up to the beam
        for dx in (-0.13, 0.13):  # its side plates' edges standing proud, a flange down each slope
            k.prism([(-0.15, 0.04), (-0.12, 0.04), (0.035, BEAM[2]), (0.005, BEAM[2])], "x", x + dx - 0.012,
                    x + dx + 0.012, "works_yellow")
        k.bolts([(x + dx, y, 0.32) for dx in (-0.143, 0.143) for y in (-0.04, 0.12)], 0.016, 0.012,
                "x" if sx * dx > 0 else "-x", "rust", seg=4)
        xe0, xe1 = sorted((sx * HW, sx * (HW - 0.05)))  # the end plate, a short cheek to the beam's end
        k.prism([(BEAM[0], BEAM[2] - 0.22), (BEAM[1] + 0.02, BEAM[2] - 0.22), (BEAM[1] + 0.02, BEAM[3] + 0.04),
                 (BEAM[0], BEAM[3] + 0.04)], "x", xe0, xe1, "works_yellow")
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
        k.lathe([(0.0, 0.115), (-0.02, 0.115), (-0.025, 0.1), (-0.12, 0.1), (-0.125, 0.09)], "works_yellow",
                segments=20, centre=(x, y0 - 0.03, BUFFER_Z), axis="y", cap=False)  # the round body
        k.cyl((x, -HD + 0.07, BUFFER_Z), 0.15, -0.03, "works_yellow", seg=20, axis="y")
        k.bolts([(x + dx, y0 - 0.03, BUFFER_Z + dz) for dx in (-0.1, 0.1) for dz in (-0.1, 0.1)], 0.016, 0.018, "-y",
                "rust", seg=6)
        k.blk((x - 0.17, -HD, BUFFER_Z - 0.17), (x + 0.17, -HD + 0.04, BUFFER_Z + 0.17), "hazard_black")
    # A lamp on the beam's middle (its lens dark: unlit).
    k.blk((-0.09, 0.03, BEAM[3] + 0.02), (0.09, 0.19, BEAM[3] + 0.06), "works_yellow")
    k.cyl((0.0, 0.11, BEAM[3] + 0.06), 0.075, HIGH - BEAM[3] - 0.06, "hazard_black", seg=10)
    lamp = HIGH - BEAM[3] - 0.06
    k.cyl((0.0, 0.035, BEAM[3] + 0.06 + lamp * 0.5), min(0.055, lamp * 0.42), -0.01, "glass", seg=10, axis="y")
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
