"""Subway's ballast wagons (SM4, model 8): a low-sided open wagon heaped with ballast, from the owner's photos
(art/references/maps/subway/08-ballast-wagon, the planked engineers' wagons in grey): three-plank sides and ends with
an outside steel stanchion at each plank joint and diagonal strapping, a drop door in the middle of each side on its
hinges, corner plates, on a short channel underframe with W-irons and leaf springs, buffers, coupling and a brake
lever (works_kit.underframe); full of grey ballast heaped over the sides. Grey paint, rust at the joints; no lettering.

Its two blocks (the north running tunnel, 4 x 1.8 m and 2.2 m high, data/maps/subway.json) are centred on the track,
so the wagon's wheels stand on the station's running rails (works_kit.running_rails).

Writes assets/models/props/ballast_wagon.glb, one vertex-coloured mesh filling x -2..2 (along the track), y -0.9..0.9,
z 0..2.2 exactly (Godot: x along, y up, z across).

Usage: python3 -I tools/blender/maps/ballast_wagon.py [--render <sheet.jpg>]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
from mathutils import Vector  # noqa: E402

NAME = "ballast_wagon"
BUDGET = 2500
HL, HD, HIGH = 2.0, 0.9, 2.2

BODY_X = 1.78        # the body's half length (its ends' outside)
SIDE_Y = 0.87        # the sides' outside (planks); stanchions stand proud to the box's side
SIDE_TOP = 1.86
PLANKS = 3


def build() -> object:
    k = wk.Kit(NAME)
    rail_top = k.running_rails(-HL, HL)
    k.mark("track")
    deck = wk.underframe(k, HL, 0.86, 1.1, 0.3, rail_top, "frame_black")
    k.mark("underframe")
    floor = deck + 0.08
    k.blk((-BODY_X, -SIDE_Y, deck), (BODY_X, SIDE_Y, floor), "skip_grey")  # the floor's planks, edge on
    # Sides and ends: planks with dark joints between, each a panel cut fine enough to weather.
    ph = (SIDE_TOP - floor) / PLANKS
    for i in range(PLANKS):
        z0, z1 = floor + i * ph + 0.006, floor + (i + 1) * ph - 0.006
        # (their faces inside the body, under the ballast, and their butted ends are left off)
        for s in (-1.0, 1.0):
            y0, y1 = sorted((s * SIDE_Y, s * (SIDE_Y - 0.05)))
            k.panel((-BODY_X, y0, z0), (BODY_X, y1, z1), "skip_grey", step=0.9,
                    skip=("-x", "+x", "-y" if s > 0 else "+y") + (() if i == PLANKS - 1 else ("+z",)))
        for sx in (-1.0, 1.0):
            x0, x1 = sorted((sx * BODY_X, sx * (BODY_X - 0.05)))
            k.panel((x0, -SIDE_Y + 0.05, z0), (x1, SIDE_Y - 0.05, z1), "skip_grey", step=0.9,
                    skip=("-y", "+y", "-x" if sx > 0 else "+x") + (() if i == PLANKS - 1 else ("+z",)))
    for s in (-1.0, 1.0):
        y0, y1 = sorted((s * (SIDE_Y - 0.01), s * (SIDE_Y - 0.04)))
        k.blk((-BODY_X, y0, floor), (BODY_X, y1, SIDE_TOP), "frame_black")  # the joints' shadow behind the planks
    k.mark("planks")
    # Outside stanchions (flat bars) at each end and either side of the door, the strapping, the top rail, the door's
    # hinges and its catches, the corner plates.
    for s in (-1.0, 1.0):
        y0, y1 = sorted((s * SIDE_Y, s * HD))
        for x in (-BODY_X + 0.03, -0.62, 0.62, BODY_X - 0.03):
            k.blk((x - 0.035, y0, deck - 0.05), (x + 0.035, y1, SIDE_TOP + 0.02), "skip_grey")
        for xa, xb in ((-BODY_X + 0.07, -0.66), (0.66, BODY_X - 0.07)):  # diagonal straps
            k.sqbar((xa, (y0 + y1) * 0.5, floor + 0.05), (xb, (y0 + y1) * 0.5, SIDE_TOP - 0.05), 0.04, "skip_grey",
                    h=0.012)
        k.blk((-BODY_X, y0, SIDE_TOP - 0.05), (BODY_X, y1, SIDE_TOP), "skip_grey")  # the top rail
        for x in (-0.4, 0.4):  # the drop door's hinges along its foot and its catches at the top
            k.cyl((x - 0.08, s * (SIDE_Y + 0.012), floor + 0.03), 0.018, 0.16, "steel_bare", seg=6, axis="x")
            k.blk((x - 0.03, y0, SIDE_TOP - 0.2), (x + 0.03, y1, SIDE_TOP - 0.08), "steel_bare")
        k.blk((-0.6, y0 if s < 0 else y0, floor + ph - 0.004), (0.6, y1, floor + ph + 0.004), "frame_black")
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * BODY_X, sx * (BODY_X + 0.02)))
        for y in (-0.45, 0.0, 0.45):
            k.blk((x0, y - 0.035, floor), (x1, y + 0.035, SIDE_TOP + 0.02), "skip_grey")
        k.blk((x0, -SIDE_Y, SIDE_TOP - 0.05), (x1, SIDE_Y, SIDE_TOP), "skip_grey")
    k.mark("ironwork")
    # The ballast, heaped over the sides to the box's top.
    k.rubble(-BODY_X + 0.05, BODY_X - 0.05, -SIDE_Y + 0.05, SIDE_Y - 0.05, SIDE_TOP - 0.08, HIGH,
             ["ballast_dark", "ballast_dark", "ballast"], 24, 12, 0.1, 8, shape=heap)
    import random
    rng = random.Random(8)
    for i in range(24):  # bigger stones lying loose on top, every way up
        x, y = rng.uniform(-BODY_X + 0.3, BODY_X - 0.3), rng.uniform(-SIDE_Y + 0.3, SIDE_Y - 0.3)
        z = SIDE_TOP - 0.08 + (HIGH - SIDE_TOP + 0.08) * heap(x / BODY_X, y / SIDE_Y)
        r = rng.uniform(0.05, 0.09)
        k.stone((x, y, min(z, HIGH - r * 0.5)), r, ("ballast_dark", "ballast")[i % 2], 100 + i,
                squash=rng.uniform(0.5, 0.85), tilt=True)
    k.mark("ballast")
    return k.build()


def heap(u: float, v: float) -> float:
    """The ballast heap's height (0..1) over the wagon, u along and v across in -1..1: flat on top, falling away."""
    return 1.0 - max(abs(u) ** 5.0 * 0.9, abs(v) ** 1.8)


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint in ("skip_grey", "frame_black"):
        col = wk.rusty(p, n, c, seed=5, amount=0.5)
        if p.z > SIDE_TOP - 0.1:
            col = wt.mix(col, wk.lin("ballast"), 0.35 * wt.fbm(p, 0.1, 6))  # stone dust on the top rail
        return wk.grime(p, n, col, seed=2)
    if paint in ("ballast", "ballast_dark"):
        col = wt.mix(c, wk.lin("ballast_dark"), 0.5 * wt.fbm(p, 0.06, 31))
        return wt.scale(col, 0.75 + 0.5 * wt.fbm(p * 7.0, 0.05, 33))  # a speckle: stone by stone, light and dark
    if paint in ("wheel", "rust"):
        return wk.grime(p, n, wk.rusty(p, n, c, seed=7, amount=0.4, streaks=False), seed=2)
    return wk.grime(p, n, c, seed=4)


def main() -> None:
    wk.reset()
    wk.check_colours(list(wk.PAINT))
    ob = build()
    wk.finish(ob, (-HL, -HD, 0.0), (HL, HD, HIGH))
    wk.bake(ob, weather, jitter={"timber": 0.06, "ballast_dark": 0.1, "skip_grey": 0.03})
    wk.write(ob, NAME, BUDGET)
    if "--render" in sys.argv:
        wk.render(wk.quarter_views(2 * HL, 2 * HD, HIGH), sys.argv[sys.argv.index("--render") + 1],
                  "SM4 ballast wagon (Subway map prop, 4 x 1.8 x 2.2 m)")


if __name__ == "__main__":
    main()
