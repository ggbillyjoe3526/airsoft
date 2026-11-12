"""Subway's cable drums (SM4, model 11): a big wooden reel of black cable standing on its rims, from the owner's photos
(art/references/maps/subway/11-cable-drum): two flanges of sawn boards with a steel band round each rim, square steel
washers on the through-bolts and a steel plate round the spindle hole, the cable wound turn on turn between them with
its loose end trailing to the floor (photo 3), timber chocks under the rims. Weathered grey timber, black cable.

Its blocks (data/maps/subway.json) are two sizes, so two models, each built at its block's size: `cable_drum` 2 m
along, 1.4 m across and 1.8 m high (the west passage's two; the chocks reach out along it), and `cable_drum_small`
1.4 m each way (the north tunnel's).

Writes assets/models/props/cable_drum*.glb, each one vertex-coloured mesh filling x -L/2..L/2, y -W/2..W/2 (the
drum's axle across), z 0..H exactly (Godot: x along, y up, z across).

Usage: python3 -I tools/blender/maps/cable_drum.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET = 1000
SIZES = {"cable_drum": (2.0, 1.4, 1.8), "cable_drum_small": (1.4, 1.4, 1.4)}
SEG = 16


def build(name: str, length: float, width: float, high: float) -> object:
    k = wk.Kit(name)
    r = high * 0.5
    zc = r
    hw = width * 0.5
    t = 0.07                          # a flange's thickness
    coil_r = r * 0.88                 # the cable's outside
    # The flanges: each a disc of boards (its face lines are the board joints), a steel band round its rim.
    for s in (-1.0, 1.0):
        y0 = s * hw
        k.lathe([(0.0, r), (-s * t, r)], "steel_bare", segments=SEG, centre=(0.0, y0, zc), axis="y", cap=False)
        ring = [(r * math.cos(2 * math.pi * i / SEG), y0, zc + r * math.sin(2 * math.pi * i / SEG)) for i in range(SEG)]
        k.fan(ring, (0.0, s, 0.0), "drum_wood")
        k.lathe([(-s * t, r), (-s * t, coil_r)], "drum_wood", segments=SEG, centre=(0.0, y0, zc), axis="y", cap=False)
        face = y0 + s * 0.002
        for i in range(-3, 4):  # board joints: thin dark lines down the face
            x = i * r * 0.27
            h = math.sqrt(max(0.0, (r - 0.02) ** 2 - x * x))
            pts = [(x - 0.006, face, zc - h), (x + 0.006, face, zc - h), (x + 0.006, face, zc + h),
                   (x - 0.006, face, zc + h)]
            k.quad(pts if s < 0 else list(reversed(pts)), "drum_wood_dark")
        # the spindle plate and hole, the through-bolts' square washers in a ring
        k.cyl((0.0, y0, zc), 0.16, s * 0.012, "rust", seg=8, axis="y")
        k.cyl((0.0, y0 + s * 0.012, zc), 0.07, -s * 0.004, "cable", seg=8, axis="y")
        for i in range(8):
            a = 2 * math.pi * (i + 0.5) / 8
            px, pz = r * 0.55 * math.cos(a), zc + r * 0.55 * math.sin(a)
            pts = [(px - 0.035, face, pz - 0.035), (px + 0.035, face, pz - 0.035), (px + 0.035, face, pz + 0.035),
                   (px - 0.035, face, pz + 0.035)]
            k.quad(pts if s < 0 else list(reversed(pts)), "steel_bare")
    # The cable: turn on turn, a ripple round each turn, between the flanges.
    turns = int((width - 2 * t) / 0.16)
    inner = hw - t
    prof = []
    for i in range(turns * 2 + 1):
        y = -inner + (2 * inner) * i / (turns * 2)
        prof.append((y, coil_r - (0.0 if i % 2 else 0.032)))
    k.lathe(prof, "cable", segments=SEG, centre=(0.0, 0.0, zc), axis="y", cap=False)
    # its loose end: off the coil's front, down to the floor and along it
    end = [(coil_r * 0.95 * math.cos(math.radians(a)), inner * 0.6, zc + coil_r * 0.95 * math.sin(math.radians(a)))
           for a in (-20.0, -50.0, -80.0)]
    end += [(length * 0.5 - 0.2 - 0.25 * (1 if length > high else 0), inner * 0.55, 0.05)]
    for a, b in zip(end, end[1:]):
        k.bar(a, b, 0.035, "cable", seg=6)
    # Chocks: a timber wedge each side under the rims, reaching to the box's ends.
    for sx in (-1.0, 1.0):
        x_out = sx * length * 0.5
        x_in = sx * (r * 0.55)
        for y in (-hw + t * 0.5, hw - t * 0.5):
            k.prism([(x_in, 0.0), (x_out, 0.0), (x_out, 0.06), (x_in + sx * 0.05, 0.22)], "y", y - 0.07, y + 0.07,
                    "timber")
    return k.build()


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint in ("drum_wood", "drum_wood_dark", "timber"):
        col = wt.mix(c, wk.lin(wk.GRIME), 0.3 * wt.fbm(p, 0.2, 61))  # weathered grey timber, damp at the foot
        return wk.grime(p, n, col, seed=10)
    if paint == "cable":
        return wt.mix(c, wk.lin(wk.DUST), max(0.0, n.z) * 0.3 * wt.fbm(p, 0.3, 63))
    return wk.grime(p, n, wk.rusty(p, n, c, seed=7, amount=0.5, streaks=False), seed=2)


def main() -> None:
    wk.check_colours(list(wk.PAINT))
    for name, (length, width, high) in SIZES.items():
        wk.reset()
        ob = build(name, length, width, high)
        wk.finish(ob, (-length * 0.5, -width * 0.5, 0.0), (length * 0.5, width * 0.5, high))
        wk.bake(ob, weather, jitter={"timber": 0.08})
        wk.write(ob, name, BUDGET)
        if "--render" in sys.argv:
            out = sys.argv[sys.argv.index("--render") + 1].replace(".jpg", "_%s.jpg" % name)
            wk.render(wk.quarter_views(length, width, high), out,
                      "SM4 %s (Subway map prop, %g x %g x %g m)" % (name.replace("_", " "), length, width, high))


if __name__ == "__main__":
    main()
