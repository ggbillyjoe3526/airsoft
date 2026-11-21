"""Subway's buffer stops (SM4, model 10): the stop at the dead west end of both tracks, from the owner's photos
(art/references/maps/subway/10-buffer-stop, the bolted steel stops, the yellow one in photo 5): a heavy box-section
beam across the track, flanged top and bottom and bolted down, on two trapezoid pedestals with flanged side plates and
stiffening ribs, standing on chamfered base plates held down by bolts on square washers, clamp shoes either side; a
channel tie between the pedestals' feet with a K-brace up to each; end cheeks bolted through; lifting eyes on top; a
lamp on top (photo 4, unlit: a dark body, a bright bezel round its lens, a hood, its conduit down the back); two sprung
buffers towards the track: a square flange bolted to the beam, a round housing with a collar, the bright plunger, a
square head plate with its corners cut and a black rubber pad on it; hazard chevrons on the beam's face. Works yellow,
scuffed, sooty and rusty, black pads; no maker's name or plate (the pedestals' plates are blank).

SQ1 (2026-11-21) rebuilt it finer: the flanges, ribs, washers, clamp shoes, tie and braces, the square rubber pads
and the lamp's bezel and hood, so it reads as a bolted steel stop instead of a yellow board on two legs.

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
BUDGET = 3000
HW, HD, HIGH = 1.15, 0.25, 1.2

BUFFER_Z = 0.86          # the buffers' height over the track bed (a car's buffers over its rails)
BUFFER_X = 0.88          # their middles from the stop's middle
PEDESTAL_X = 0.78        # the pedestals' middles, over the running rails (gauge 1.5 m)
BEAM = (0.0, 0.22, BUFFER_Z - 0.26, BUFFER_Z + 0.22)   # the beam's front and back (y), bottom and top (z)


def octagon(cx: float, cz: float, half: float, cut: float) -> list:
    """A square `half` either side of (cx, cz) in plan, its corners cut back by `cut`: a plate's outline."""
    h, c = half, cut
    return [(cx - h + c, cz - h), (cx + h - c, cz - h), (cx + h, cz - h + c), (cx + h, cz + h - c),
            (cx + h - c, cz + h), (cx - h + c, cz + h), (cx - h, cz + h - c), (cx - h, cz - h + c)]


def build() -> object:
    k = wk.Kit(NAME)
    # The pedestals (photo 1): a closed trapezoid box under each buffer on a base plate with chamfered edges, bolted
    # down, clamp shoes either side; its side plates' edges standing proud as flanges, a stiffening rib across each
    # side; an end plate at each side closing the beam, bolted.
    for sx in (-1.0, 1.0):
        x = sx * PEDESTAL_X
        k.prism([(-0.17, 0.0), (HD, 0.0), (HD, 0.03), (HD - 0.012, 0.042), (-0.158, 0.042), (-0.17, 0.03)], "x",
                x - 0.21, x + 0.21, "works_yellow")  # the base plate
        for dx in (-0.16, 0.16):  # the holding-down bolts, each on a square washer
            for y in (-0.12, 0.05, 0.2):
                k.blk((x + dx - 0.032, y - 0.032, 0.042), (x + dx + 0.032, y + 0.032, 0.05), "frame_black")
                k.bolts([(x + dx, y, 0.05)], 0.024, 0.026, "z", "rust", seg=6)
        for dx in (-1.0, 1.0):  # clamp shoes along the base's sides, a bolt through each
            xa, xb = sorted((x + dx * 0.21, x + dx * 0.25))
            k.prism([(-0.12, 0.0), (0.2, 0.0), (0.2, 0.06), (-0.1, 0.08), (-0.12, 0.06)], "x", xa, xb, "frame_black")
            k.bolts([(x + dx * 0.23, y, 0.07) for y in (-0.05, 0.12)], 0.018, 0.02, "z", "rust", seg=6)
        k.prism([(-0.13, 0.04), (HD - 0.02, 0.04), (0.2, BEAM[2]), (0.02, BEAM[2])], "x", x - 0.13, x + 0.13,
                "works_yellow")  # the pedestal's sloping front, its back up to the beam
        for dx in (-0.13, 0.13):  # its side plates' edges standing proud, a flange down each slope
            k.prism([(-0.15, 0.04), (-0.12, 0.04), (0.035, BEAM[2]), (0.005, BEAM[2])], "x", x + dx - 0.012,
                    x + dx + 0.012, "works_yellow")
            xs0, xs1 = sorted((x + dx, x + dx + (0.012 if dx > 0 else -0.012)))
            k.prism([(-0.075, 0.3), (HD - 0.04, 0.3), (HD - 0.04, 0.34), (-0.088, 0.34)], "x", xs0, xs1,
                    "works_yellow")  # the stiffening rib across the side
        k.bolts([(x + dx, y, 0.32) for dx in (-0.155, 0.155) for y in (-0.03, 0.12)], 0.017, 0.012,
                "x" if sx * dx > 0 else "-x", "rust", seg=6)
        xe0, xe1 = sorted((sx * HW, sx * (HW - 0.05)))  # the end plate, a short cheek to the beam's end
        k.prism([(BEAM[0], BEAM[2] - 0.22), (BEAM[1] + 0.02, BEAM[2] - 0.22), (BEAM[1] + 0.02, BEAM[3] + 0.04),
                 (BEAM[0] + 0.03, BEAM[3] + 0.04), (BEAM[0], BEAM[3] + 0.01)], "x", xe0, xe1, "works_yellow")
        k.bolts([(sx * (HW - 0.05), y, z) for y in (0.04, 0.18) for z in (BEAM[2] - 0.17, BEAM[2] - 0.07)],
                0.016, 0.012, "-x" if sx > 0 else "x", "rust", seg=6)  # through the cheek, on its inner face
        # a blank inspection plate on the pedestal's sloping front
        a, b = Vector((-0.13, 0.04)), Vector((0.02, BEAM[2]))
        d = (b - a).normalized()
        n = Vector((-d.y, d.x)) * 0.008
        p0, p1 = a + (b - a) * 0.38, a + (b - a) * 0.7
        k.prism([tuple(p0), tuple(p1), tuple(p1 + n), tuple(p0 + n)], "x", x - 0.075, x + 0.075, "works_yellow")
    # The tie between the pedestals' feet at the back, a channel on edge, and a K-brace from each pedestal to it.
    k.prism([(0.08, 0.0), (0.22, 0.0), (0.22, 0.016), (0.1, 0.016), (0.1, 0.12), (0.22, 0.12), (0.22, 0.136),
             (0.08, 0.136)], "x", -PEDESTAL_X + 0.13, PEDESTAL_X - 0.13, "works_yellow")
    for sx in (-1.0, 1.0):
        k.sqbar((sx * (PEDESTAL_X - 0.13), 0.15, BEAM[2] - 0.12), (sx * 0.06, 0.15, 0.13), 0.07, "works_yellow",
                h=0.014)
    k.prism(octagon(0.0, 0.2, 0.08, 0.02), "y", 0.066, 0.08, "works_yellow")  # the brace's gusset
    k.mark("cheeks")
    # The beam: a box section across the cheeks with flanges top and bottom, its bolted face plate, lifting eyes on
    # top; the hazard chevrons painted on its face between the buffers.
    k.panel((-HW + 0.05, BEAM[0], BEAM[2]), (HW - 0.05, BEAM[1], BEAM[3]), "works_yellow", step=0.2)
    for z0, z1 in ((BEAM[2] - 0.018, BEAM[2]), (BEAM[3], BEAM[3] + 0.018)):
        k.prism([(BEAM[0] - 0.035, z0), (BEAM[1] + 0.02, z0), (BEAM[1] + 0.02, z1), (BEAM[0] - 0.03, z1)], "x",
                -HW + 0.05, HW - 0.05, "works_yellow")
    k.blk((-HW + 0.06, BEAM[0] - 0.015, BEAM[2] + 0.01), (HW - 0.06, BEAM[0], BEAM[3] - 0.01), "works_yellow")
    for x in (-0.5, 0.5):  # lifting eyes: an arched plate, its hole, a doubler at its foot
        k.prism([(x - 0.07, BEAM[3] + 0.018), (x + 0.07, BEAM[3] + 0.018), (x + 0.045, BEAM[3] + 0.08),
                 (x + 0.02, BEAM[3] + 0.1), (x - 0.02, BEAM[3] + 0.1), (x - 0.045, BEAM[3] + 0.08)], "y", 0.095, 0.125,
                "works_yellow")
        k.cyl((x, 0.09, BEAM[3] + 0.065), 0.02, 0.04, "hazard_black", seg=8, axis="y")
    k.bolts([(x, BEAM[0] - 0.015, z) for x in (-0.66, -0.33, 0.0, 0.33, 0.66) for z in (BEAM[2] + 0.04,
             BEAM[3] - 0.04) if abs(x) > 0.5 or abs(x) < 0.01], 0.017, 0.016, "-y", "rust", seg=6)
    k.bolts([(x, BEAM[1] - 0.04, BEAM[3] + 0.018) for x in (-0.95, -0.76, -0.25, 0.25, 0.76, 0.95)], 0.016, 0.014,
            "z", "rust", seg=6)  # the top flange bolted down to the cheeks and the pedestals
    w = 0.12
    yq = BEAM[0] - 0.0165
    for i in range(-4, 5):  # chevrons: black bands leaning across the face
        x = i * 0.13
        if abs(x) > BUFFER_X - 0.25:
            continue
        k.quad([(x - w * 0.5 - 0.06, yq, BEAM[2] + 0.012), (x + w * 0.5 - 0.06, yq, BEAM[2] + 0.012),
                (x + w * 0.5 + 0.06, yq, BEAM[3] - 0.012), (x - w * 0.5 + 0.06, yq, BEAM[3] - 0.012)], "hazard_black")
    k.mark("beam")
    # The buffers (photos 1, 2 and 5): a square flange bolted to the beam, the round housing with a collar at its
    # mouth, the bright plunger, a square head plate with its corners cut and on it the black rubber pad, bolted.
    for sx in (-1.0, 1.0):
        x = sx * BUFFER_X
        y0 = BEAM[0] - 0.015
        k.prism(octagon(x, BUFFER_Z, 0.135, 0.03), "y", y0 - 0.03, y0, "works_yellow")
        k.bolts([(x + dx, y0 - 0.03, BUFFER_Z + dz) for dx in (-0.1, 0.1) for dz in (-0.1, 0.1)], 0.017, 0.018, "-y",
                "rust", seg=6)
        k.lathe([(0.0, 0.115), (-0.02, 0.115), (-0.025, 0.1), (-0.085, 0.1), (-0.09, 0.112), (-0.105, 0.112),
                 (-0.11, 0.09)], "works_yellow", segments=20, centre=(x, y0 - 0.03, BUFFER_Z), axis="y", cap=False)
        k.cyl((x, y0 - 0.14, BUFFER_Z), 0.068, -(BEAM[0] - 0.015 - 0.14 - (-HD + 0.065)), "steel_bare", seg=14,
              axis="y")  # the plunger
        k.prism(octagon(x, BUFFER_Z, 0.17, 0.035), "y", -HD + 0.04, -HD + 0.065, "works_yellow")  # the head plate
        k.prism(octagon(x, BUFFER_Z, 0.155, 0.025), "y", -HD + 0.004, -HD + 0.04, "rubber")  # the pad
        k.prism(octagon(x, BUFFER_Z, 0.145, 0.02), "y", -HD, -HD + 0.004, "rubber")  # its face, a step in
    k.mark("buffers")
    # A lamp on the beam's middle (photo 4, unlit): a bracket, the round body with a hood over its dark lens and a
    # bright bezel, its cable in a conduit down the beam's back.
    k.blk((-0.1, 0.03, BEAM[3] + 0.018), (0.1, 0.19, BEAM[3] + 0.045), "works_yellow")
    k.cyl((0.0, 0.11, BEAM[3] + 0.045), 0.072, HIGH - 0.012 - BEAM[3] - 0.045, "hazard_black", seg=12)
    k.cyl((0.0, 0.11, HIGH - 0.012), 0.08, 0.012, "hazard_black", seg=12)  # its top cap
    zl = (BEAM[3] + 0.045 + HIGH - 0.012) * 0.5
    k.cyl((0.0, 0.042, zl), 0.03, -0.012, "steel_bare", seg=10, axis="y")  # the bezel
    k.cyl((0.0, 0.031, zl), 0.024, -0.005, "glass", seg=10, axis="y")
    k.blk((-0.045, 0.012, zl + 0.03), (0.045, 0.045, zl + 0.038), "hazard_black")  # the hood
    k.bar((0.12, 0.2, BEAM[3] + 0.08), (0.12, 0.235, BEAM[2] + 0.1), 0.014, "frame_black", seg=6)
    k.bar((0.06, 0.16, BEAM[3] + 0.08), (0.12, 0.2, BEAM[3] + 0.08), 0.014, "frame_black", seg=6)
    k.mark("lamp")
    return k.build()


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint == "works_yellow":
        col = wk.rusty(p, n, c, seed=19, amount=0.5)
        col = wt.mix(col, wk.lin(wk.SOOT), 0.3 * wt.fbm(p, 0.3, 21))  # tunnel soot
        return wk.grime(p, n, col, seed=8)
    if paint == "hazard_black":
        return wt.mix(c, wk.lin("steel_bare"), 0.25 * wt.fbm(p, 0.05, 23))  # rubbed by a train's buffers
    if paint == "rubber":  # the pads: scuffed grey where a train's buffers met them, sooty round the edge
        return wt.mix(c, wk.lin(wk.DUST), 0.2 * wt.fbm(p, 0.04, 24) * (1.0 if n.y < -0.5 else 0.4))
    if paint == "glass":
        return wt.mix(c, wk.lin(wk.SOOT), 0.3 * wt.fbm(p, 0.02, 25))
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
