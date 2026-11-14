"""The range's water tote (RM1): an IBC, a milky plastic tank in a galvanised tube cage on a black plastic pallet, a
screw cap on top, a ball valve at the front foot and a blank label plate on the cage (William's photos,
art/references/maps/william-2026-11-09/water_tote; no brand or writing).

Writes assets/models/props/water_tote.glb, one vertex-coloured mesh filling x -0.6..0.6, y -0.6..0.6, z 0..1.2
exactly (its block in range.json; Godot: x across, y up, z deep), the valve towards -y (Godot's +z, the front
PropLayout turns towards the field).

Usage: python3 tools/blender/maps/water_tote.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import range_kit as rk  # noqa: E402
from range_kit import hs  # noqa: E402

OUT = os.path.join(rk.PROPS, "water_tote.glb")
BUDGET = 2000
HW = 0.6
HIGH = 1.2
PALLET = 0.15
CAGE = 0.585  # the cage's tubes' outer faces
TUBE = 0.011
TANK = 0.55

rk.check_colours(["tank", "tank_shade", "cage", "pallet_black", "cap", "valve", "lever", "label"], shade=0.05)


def build() -> object:
    k = rk.Kit("WaterTote")
    # The pallet: a deck on three runners with a foot block at each corner and middle (black plastic).
    k.blk((-HW, -HW, PALLET - 0.035), (HW, HW, PALLET), "pallet_black")
    for x in (-HW + 0.07, 0.0, HW - 0.07):
        for y in (-HW + 0.07, 0.0, HW - 0.07):
            k.blk((x - 0.07, y - 0.07, 0.0), (x + 0.07, y + 0.07, PALLET - 0.035), "pallet_black")
    for y in (-HW + 0.07, HW - 0.07):
        k.blk((-HW, y - 0.07, 0.0), (HW, y + 0.07, 0.025), "pallet_black")
    # The tank: a rounded box, moulded with a shallow lid well, its lower corners a shade darker where the cage's
    # base holds it.
    top = HIGH - 0.06
    rings = []
    for z, s, r in ((PALLET, TANK - 0.03, 0.07), (PALLET + 0.04, TANK, 0.09), (top - 0.05, TANK, 0.09),
                    (top, TANK - 0.04, 0.07)):
        rings.append([(x, y, z) for x, y in hs.rounded_rect(s, s, r, 2)])
    k.loft(rings, "tank")
    def span(sv: float) -> tuple:
        return (TANK - 0.12, TANK + 0.004) if sv > 0 else (-TANK - 0.004, -TANK + 0.12)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            (x0, x1), (y0, y1) = span(sx), span(sy)
            k.blk((x0, y0, PALLET), (x1, y1, PALLET + 0.12), "pallet_black")
    # The screw cap on the lid, and the ball valve at the front foot with its yellow lever.
    k.cyl((0.0, 0.05, top), 0.075, 0.035, "cap", seg=12)
    k.cyl((0.0, 0.05, top + 0.035), 0.06, 0.012, "cap", seg=12)
    # The ball valve: a stub out of the tank's foot, the valve's round body across it, its outlet with a screw cap
    # to the front, and the yellow lever on top.
    # The valve's middle: in the clear bay between the cage's two middle verticals (x +-0.082) and under its lowest
    # horizontal (z 0.259), inside the cage's front (y -0.6 .. -0.55).
    vx, vz, vy = 0.0, PALLET + 0.06, -0.578
    k.cyl((vx, vy, vz), 0.036, -TANK - vy, "valve", seg=12, axis="y")  # the stub into the tank
    k.cyl((vx - 0.06, vy, vz), 0.026, 0.12, "valve", seg=12, axis="x")  # the valve's body, 0.12 m across
    for x in (vx - 0.062, vx + 0.042):  # its union nuts
        k.cyl((x, vy, vz), 0.032, 0.02, "valve", seg=6, axis="x")
    k.cyl((vx, -HW + 0.004, vz), 0.03, vy + HW - 0.004, "valve", seg=12, axis="y")  # the outlet
    k.cyl((vx, -HW, vz), 0.036, 0.008, "cap", seg=12, axis="y")  # its cap
    k.blk((vx - 0.012, vy - 0.007, vz + 0.03), (vx + 0.07, vy + 0.007, vz + 0.044), "lever")  # inside the bay
    # The cage: a frame at the top, posts at the corners, verticals between, five rows of horizontals (the photos'
    # grid), two bars over the top.
    c = CAGE - TUBE
    z0, z1 = PALLET, HIGH - TUBE
    n = 7
    xs = [-c + 2 * c * i / n for i in range(n + 1)]
    for side in range(4):
        def at(u: float, z: float, inset: float = 0.0) -> tuple:
            w = c - inset
            return [(u, -w, z), (w, u, z), (-u, w, z), (-w, -u, z)][side]
        for u in xs[1:-1]:
            k.bar(at(u, z0), at(u, z1), TUBE, "cage", seg=5, cap=False)
        k.bar(at(-c, z0), at(-c, z1), TUBE * 1.3, "cage", seg=6)
        for row in range(5):
            z = z0 + 0.12 + row * (z1 - z0 - 0.12) / 4.5
            k.bar(at(-c, z), at(c, z), TUBE, "cage", seg=5, cap=False)
        k.bar(at(-c, z1), at(c, z1), TUBE * 1.3, "cage", seg=6)
        k.bar(at(-c, z0 + 0.01), at(c, z0 + 0.01), TUBE * 1.3, "cage", seg=6)
    for y in (-0.22, 0.32):
        k.bar((-c, y, z1), (c, y, z1), TUBE, "cage", seg=5)
    # A blank dark label plate on the front (the photos' notice plate, no writing).
    # Fixed on the cage over its bars, with a clip at each corner.
    k.blk((-0.42, -CAGE - 0.008, 0.42), (-0.02, -CAGE - 0.002, 0.82), "label")
    for x in (-0.4, -0.04):
        for z in (0.44, 0.8):
            k.blk((x - 0.012, -CAGE - 0.011, z - 0.012), (x + 0.012, -CAGE - 0.008, z + 0.012), "cage")
    ob = k.build()
    rk.finish(ob, angle=math.radians(50.0))
    rk.clamp_to(ob, (-HW, -HW, 0.0), (HW, HW, HIGH))
    rk.bake(ob, seed=5)
    rk.fit_box(ob, (-HW, -HW, 0.0), (HW, HW, HIGH))
    return ob


def main() -> None:
    rk.reset()
    ob = build()
    n = rk.report([ob])
    if n > BUDGET:
        raise SystemExit("over budget")
    rk.export(OUT, [ob])
    print("wrote", os.path.relpath(OUT, rk.ROOT))
    if "--render" in sys.argv:
        import range_render as rr
        rr.render_sheet([
            ("Front quarter (valve, label plate)", (-2.0, -2.8, 1.7), (0.0, 0.0, 0.6), 35),
            ("Rear quarter", (2.3, 2.6, 1.9), (0.0, 0.0, 0.6), 35),
            ("Valve and pallet: close-up", (0.6, -1.4, 0.5), (0.08, -0.6, 0.25), 40),
            ("Top: cap and cage bars", (-1.0, -1.4, 2.6), (0.0, 0.0, 1.1), 35),
            ("Side", (3.0, 0.0, 0.9), (0.0, 0.0, 0.6), 35),
            ("From 10 m", (-3.0, -9.5, 1.6), (0.0, 0.0, 0.6), 40),
        ], sys.argv[sys.argv.index("--render") + 1], "RM1 water tote / IBC (map prop): from William's IBC photos")


if __name__ == "__main__":
    main()
