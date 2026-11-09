"""Depot's steel pillar (Dev 3, the hall shell): assets/models/props/pillar.glb, for the hall's four pillar blocks
(0.6 x 8 x 0.6 m).

From the owner's photos (references/maps/william-2026-11-09/steel_pillar): a round steel tube painted safety yellow,
welded to a square base plate held down by four anchor bolts (washer, hex nut, the stud's end proud of it), with a
wrap of black hazard stripes near the foot, where a body or a trolley meets it. Here the post runs the hall's
full height to the roof, so it ends in a head plate welded under the roof steel. No brands.

Fills its block's box exactly: the plates are the box's 0.6 m square, the post 0.4 m across, 8 m tall. Budget 1,200
triangles (docs/ASSETS.md; /mnt/project-files/art/depot-range-model-list.md). Plain vertex colours, no texture.

    python -I tools/blender/maps/steel_pillar.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402  first: it sets up bpy and the replica helpers
import hardsurface as hs  # noqa: E402

BUDGET = 1200
HALF = 0.3          # the box's half width (m): the plates fill it
HEIGHT = 8.0
PLATE = 0.022       # base and head plate thickness
POST_R = 0.2
SIDES = 64          # round enough at a metre: the post is what you stand beside
WELD = 0.012        # the fillet weld's leg at the post's foot and head
BOLT_AT = 0.235     # the anchor bolts' distance from the middle along x and y
TAPE = (0.95, 1.3)  # the hazard tape's foot and top (m)
TAPE_STRIPES = 6
TAPE_WIDE = 0.075   # a stripe's width across the post
TAPE_PROUD = 0.004


def plate(b: hs.Builder, z0: float, z1: float) -> None:
    """A square plate the box's width, its top edges chamfered 3 mm."""
    c = 0.003
    b.prism([(-HALF, -HALF), (HALF, -HALF), (HALF, HALF), (-HALF, HALF)], "z", z0, z1 - c, "Paint")
    inner = HALF - c
    b.loft([[(-HALF, -HALF, z1 - c), (HALF, -HALF, z1 - c), (HALF, HALF, z1 - c), (-HALF, HALF, z1 - c)],
            [(-inner, -inner, z1), (inner, -inner, z1), (inner, inner, z1), (-inner, inner, z1)]],
           "Paint", cap0=False, cap1=True)


def bolt(b: hs.Builder, x: float, y: float, z: float) -> None:
    """An anchor bolt's washer, hex nut and stud end standing on a plate face at height z."""
    b.lathe([(0.0, 0.032), (0.004, 0.032), (0.004, 0.0)], "Steel", segments=12, centre=(x, y, z), axis="z")
    nut = [(0.021 * math.cos(math.pi / 3 * i + math.pi / 6), 0.021 * math.sin(math.pi / 3 * i + math.pi / 6))
           for i in range(6)]
    b.prism(nut, "z", z + 0.004, z + 0.02, "Steel", offset=(x, y, 0.0))
    b.lathe([(0.0, 0.011), (0.014, 0.0)], "Bolt", segments=6, centre=(x, y, z + 0.02), axis="z")


def build() -> object:
    mk.paints({"Paint": mk.PALETTE["yellow"], "Weld": (mk.PALETTE["yellow"], 0.93), "Steel": mk.PALETTE["steel"],
               "Bolt": mk.PALETTE["grey"], "Tape": mk.PALETTE["rubber"]})
    b = hs.Builder("Pillar", [])
    plate(b, 0.0, PLATE)
    # the head plate, mirrored: its chamfer faces down into the hall
    top = hs.Builder("Head", [])
    plate(top, 0.0, PLATE)
    head = top.build()
    head.data.transform(hs.Matrix.Translation((0.0, 0.0, HEIGHT)) @ hs.Matrix.Scale(-1.0, 4, (0.0, 0.0, 1.0)))
    head.data.flip_normals()
    # the post with a fillet weld at each end
    y0, y1 = PLATE, HEIGHT - PLATE
    b.lathe([(y0, POST_R + WELD), (y0 + WELD, POST_R)], "Weld",
            segments=SIDES, axis="z", cap=False)
    b.lathe([(y0 + WELD, POST_R), (y1 - WELD, POST_R)], "Paint",
            segments=SIDES, axis="z", cap=False)
    b.lathe([(y1 - WELD, POST_R), (y1, POST_R + WELD)], "Weld",
            segments=SIDES, axis="z", cap=False)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            bolt(b, sx * BOLT_AT, sy * BOLT_AT, PLATE)
    tape(b)
    ob = b.build()
    ob = hs.join("Pillar", [ob, head])
    mk.clean(ob)
    return ob


def tape(b: hs.Builder) -> None:
    """The hazard tape: black stripes wound round the post at 45 degrees over its yellow, `TAPE_STRIPES` of them, each
    a ribbon `TAPE_WIDE` m across laid just proud of the paint in short quads, so it follows the round."""
    r = POST_R + TAPE_PROUD
    rows = 16
    turn = (TAPE[1] - TAPE[0]) / r  # 45 degrees: as far round as it rises
    half = TAPE_WIDE * 0.5 / r
    bm = b.bm
    dark = b.mat("Tape")
    for s in range(TAPE_STRIPES):
        a0 = 2.0 * math.pi * s / TAPE_STRIPES
        rings = []
        for k in range(rows + 1):
            t = k / rows
            a = a0 + turn * t
            z = TAPE[0] + (TAPE[1] - TAPE[0]) * t
            rings.append([bm.verts.new((r * math.cos(a + d), r * math.sin(a + d), z)) for d in (-half, 0.0, half)])
        for k in range(rows):
            for i in range(2):
                f = bm.faces.new((rings[k][i], rings[k][i + 1], rings[k + 1][i + 1], rings[k + 1][i]))
                f.material_index = dark


def main() -> None:
    hs.reset()
    ob = build()
    mk.report(ob, "pillar", BUDGET)
    mk.export_prop(ob, "pillar")


if __name__ == "__main__":
    main()
