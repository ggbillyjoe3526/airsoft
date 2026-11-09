"""Woodland's hut roofs (WG3, Dev 3): assets/models/props/hut_roof.glb (5.6 x 4.6 m: the two Hut row huts) and
hut_roof_long.glb (6.6 x 4.85 m: the Cabin and the Box), for the four huts' roof blocks (data/maps/woodland.json,
`dress` hut_roof and hut_roof_long; PropDressConfig fits each to its block).

From the owner's photos (references/maps/woodland/08-hut-roof): split cedar shakes in staggered courses, weathered
silver (photo 1); a gable with plain bargeboards and a capped ridge (photos 3, 4 and 5); rafters and boarded sarking
seen from inside (photo 2), their tails under the eaves. The block is 0.15 m thick, so the gable rises inside it: a
pitch so low it reads as a near-flat shingled roof from the field, with every course's butt casting its line and
the ridge, bargeboards and fascia giving it an edge. A little moss where the shade keeps it damp. No brands.

Fills its block's box exactly (FIT). Budget 1,500 triangles a roof (/mnt/project-files/art/woodland-model-list.md).

    python -I tools/blender/maps/hut_roof.py <repo root>
"""

import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402  first: it sets up bpy and the replica helpers
import hardsurface as hs  # noqa: E402
import woodkit as wk  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET = 1500
# each roof's size and its shakes' widths (m, at random): ~95 % of the budget each
SIZES = {"hut_roof": (5.6, 4.6, (0.16, 0.29)), "hut_roof_long": (6.6, 4.85, (0.19, 0.35))}
THICK = 0.15
RAFTER = (0.05, 0.06)
RAFTER_STEP = 0.6
SARKING = 0.02          # boards over the rafters
EAVE_SHAKE = 0.012      # a shake's butt
EXPOSURE = 0.2          # each course's share of the slope
CAP = (0.13, 0.025)     # the ridge's cap boards (w, t)
BARGE = (0.03, 0.1)     # bargeboards and fascia (t, d)


def build(name: str, length: float, width: float, shake: tuple) -> object:
    f = wk.Frame(Vector((-length / 2, 0.0, -width / 2)), Vector((length / 2, THICK, width / 2)))
    rng = random.Random(len(name))
    b = hs.Builder("Roof", [])
    x0, x1 = -length / 2, length / 2
    half = width / 2
    rw, rd = RAFTER
    deck0 = rd + SARKING                   # the sarking's top at the eaves
    ridge_deck = THICK - CAP[1] - EAVE_SHAKE

    def deck(z: float) -> float:
        """The sarking's top at z: rising from the eaves to the ridge."""
        return deck0 + (ridge_deck - deck0) * (1.0 - abs(z) / half)

    # rafters, eave to eave under each slope (their tails show under the eaves), the sarking's underside between
    n = round((length - 0.2) / RAFTER_STEP)
    for k in range(n + 1):
        x = x0 + 0.1 + (length - 0.2) * k / n
        for s in (-1, 1):
            z_out = s * (half - BARGE[0])
            wk.quad(b, f, [(x - rw / 2, 0.0, 0.0), (x + rw / 2, 0.0, 0.0), (x + rw / 2, 0.0, z_out),
                           (x - rw / 2, 0.0, z_out)], "WoodShade", (0.0, -1.0, 0.0))
            for xs in (x - rw / 2, x + rw / 2):
                wk.quad(b, f, [(xs, 0.0, 0.0), (xs, 0.0, z_out), (xs, rd, z_out), (xs, rd, 0.0)], "WoodDark",
                        (xs - x, 0.0, 0.0))
    boards = round(width / 0.15)
    for k in range(boards):
        za = -half + width * k / boards
        zb = -half + width * (k + 1) / boards
        wk.quad(b, f, [(x0, rd, za), (x1, rd, za), (x1, rd, zb), (x0, rd, zb)],
                ["WoodDark", "WoodDarkA", "WoodDark"][k % 3], (0.0, -1.0, 0.0))
    # the shakes: courses from each eave up to the ridge, staggered, each shake its own shade
    courses = int(half / EXPOSURE)
    shades = ["Shake", "ShakeA", "ShakeB", "ShakeC", "Shake"]
    for s in (-1, 1):
        for c in range(courses):
            za = s * (half - c * half / courses)
            zb = s * (half - (c + 1) * half / courses)
            ya = deck(za) + (EAVE_SHAKE if c == 0 else EAVE_SHAKE * 0.4)
            yb = deck(zb) + EAVE_SHAKE * 0.4
            # the course's butt, a dark line across the roof
            lower = deck(za) if c == 0 else deck(za) + EAVE_SHAKE * 0.4 - EAVE_SHAKE * 0.6
            wk.quad(b, f, [(x0, lower, za), (x1, lower, za), (x1, ya, za), (x0, ya, za)], "ShakeEnd", (0.0, 0.0, s))
            x = x0
            while x < x1 - 1e-6:
                w = rng.uniform(*shake)
                xe = min(x1, x + w)
                if x1 - xe < shake[0] * 0.5:
                    xe = x1
                damp = c < 2 and rng.random() < 0.08
                m = "Moss" if damp else shades[rng.randrange(len(shades))]
                lift = rng.uniform(-0.002, 0.003)
                wk.quad(b, f, [(x, ya + lift, za), (xe, ya + lift, za), (xe, yb, zb), (x, yb, zb)], m, (0.0, 1.0, 0.0))
                x = xe
    # the ridge: two cap boards meeting over it
    for s in (-1, 1):
        wk.quad(b, f, [(x0, THICK, 0.0), (x1, THICK, 0.0), (x1, THICK - CAP[1] * 0.6, s * CAP[0]),
                       (x0, THICK - CAP[1] * 0.6, s * CAP[0])], "WoodLight", (0.0, 1.0, 0.0))
        wk.quad(b, f, [(x0, THICK - CAP[1] * 0.6, s * CAP[0]), (x1, THICK - CAP[1] * 0.6, s * CAP[0]),
                       (x1, deck(s * CAP[0]) + EAVE_SHAKE * 0.4, s * CAP[0]),
                       (x0, deck(s * CAP[0]) + EAVE_SHAKE * 0.4, s * CAP[0])], "WoodDark", (0.0, 0.0, s))
    # bargeboards up each gable's slopes, the fascia along each eave
    bt, bd = BARGE
    for xe, sx in ((x0, -1.0), (x1, 1.0)):
        xin = xe - sx * bt
        for s in (-1, 1):
            pts_out = [(xe, 0.0, s * half), (xe, 0.0, 0.0), (xe, THICK, 0.0), (xe, deck(s * half) + EAVE_SHAKE, s * half)]
            wk.quad(b, f, pts_out, "WoodDark", (sx, 0.0, 0.0))
            wk.quad(b, f, [(xe, THICK, 0.0), (xin, THICK, 0.0), (xin, deck(s * half) + EAVE_SHAKE, s * half),
                           (xe, deck(s * half) + EAVE_SHAKE, s * half)], "Wood", (0.0, 1.0, 0.0))
            wk.quad(b, f, [(xin, 0.0, s * half), (xin, 0.0, 0.0), (xin, rd, 0.0), (xin, rd, s * half)], "WoodShade",
                    (-sx, 0.0, 0.0))
    for s in (-1, 1):
        zf = s * half
        wk.quad(b, f, [(x0, 0.0, zf), (x1, 0.0, zf), (x1, deck0, zf), (x0, deck0, zf)], "WoodDark", (0.0, 0.0, s))
        wk.quad(b, f, [(x0, 0.0, zf - s * bt), (x1, 0.0, zf - s * bt), (x1, 0.0, zf), (x0, 0.0, zf)], "WoodShade",
                (0.0, -1.0, 0.0))
    return b.build()


def main() -> None:
    for name, (length, width, shake) in SIZES.items():
        hs.reset()
        wk.paints({"Shake": 0xa2916c, "ShakeA": (0xa2916c, 1.05), "ShakeB": (0xa2916c, 0.94), "ShakeC": 0x9d9070,
                   "ShakeEnd": 0x4f4a42, "WoodDarkA": (0x7d735f, 1.06)})
        ob = build(name, length, width, shake)
        wk.export(ob, name, BUDGET)


if __name__ == "__main__":
    main()
