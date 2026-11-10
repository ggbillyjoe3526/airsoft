"""The range's generator (RM1): an open-frame site generator in a yellow tube frame (William's photos,
art/references/maps/william-2026-11-09/generator: the tube cage with its rounded corners, the dark fuel tank on top,
the engine with its round recoil starter on one side, the control panel with sockets on the other, the muffler box,
two wheels and a handle; no brand or writing), its engine filling the frame as in his photos, standing in a steel
drip tray with two jerry cans beside it.

Its block in range.json is a 1.2 m cube, larger than a portable generator, so the generator stands on a steel drip
tray that fills the block's footprint (common under site generators), the frame's lifting bar reaching the block's
top, and the tray's spare depth holds two fuel cans: the model fills the box without stretching anything.

Writes assets/models/props/generator.glb, one vertex-coloured mesh filling x -0.6..0.6, y -0.6..0.6, z 0..1.2
exactly (Godot: x across, y up, z deep), its control panel towards -y (Godot's +z, the front PropLayout turns towards
the field).

Usage: python3 tools/blender/maps/generator.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import range_kit as rk  # noqa: E402
from range_kit import hs  # noqa: E402

OUT = os.path.join(rk.PROPS, "generator.glb")
BUDGET = 3000  # the plan said 2,500; round bends and a full engine need more, and the map has one (RM1 record)
HW = 0.6
HIGH = 1.2
TRAY = 0.1
GX = 0.56  # the frame's half length
G0, G1 = -0.6, 0.26  # the frame's front and back (y): 1.3 to 1 in plan, as the photos
TUBE = 0.024

SEG = 12  # every round part
TUBE_SEG = 10  # the frame's tubes: round at any distance, inside the budget

rk.check_colours(["gen_yellow", "gen_ink", "gen_panel", "steel", "steel_light", "rubber", "socket_yellow",
                  "socket_grey", "stand_black", "zinc", "can_green"], shade=0.05)


def _loop(k: rk.Kit, pts: list, mat: str) -> None:
    for a, b in zip(pts, pts[1:] + pts[:1]):
        k.bar(a, b, TUBE, mat, seg=TUBE_SEG, cap=False)


def _fins(k: rk.Kit, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, n: int, mat: str) -> None:
    """A finned block (an engine's cylinder or an alternator's vents): a core and n thin fins along z."""
    k.blk((x0 + 0.02, y0 + 0.02, z0), (x1 - 0.02, y1 - 0.02, z1), mat)
    for i in range(n):
        z = z0 + (z1 - z0) * (i + 0.5) / n
        k.blk((x0, y0, z - 0.006), (x1, y1, z + 0.006), mat)


def build() -> object:
    k = rk.Kit("Generator")
    # The drip tray: a shallow steel tray over the whole footprint, its rim turned in.
    k.blk((-HW, -HW, 0.0), (HW, HW, 0.012), "steel")
    for a, b in (((-HW, -HW), (HW, -HW + 0.02)), ((-HW, HW - 0.02), (HW, HW)), ((-HW, -HW), (-HW + 0.02, HW)),
                 ((HW - 0.02, -HW), (HW, HW))):
        k.blk((a[0], a[1], 0.0), (b[0], b[1], TRAY), "steel")
    # The frame: two rounded tube loops (left and right ends), joined front and back low and high, with the lifting
    # bar across the top reaching the block's top.
    z0, z1 = TRAY + TUBE + 0.04, HIGH - 0.13
    for sx in (-1.0, 1.0):
        x = sx * (GX - TUBE)
        r = 0.11
        loop = []
        for (cy, cz, a0) in ((G1 - TUBE - r, z1 - r, 0.0), (G0 + TUBE + r, z1 - r, 90.0),
                             (G0 + TUBE + r, z0 + r, 180.0), (G1 - TUBE - r, z0 + r, 270.0)):
            for i in range(5):  # each bend in four steps, round as the photos' big bends
                a = math.radians(a0 + 22.5 * i)
                loop.append((x, cy + r * math.cos(a), cz + r * math.sin(a)))
        _loop(k, loop, "gen_yellow")
        k.blk((x - 0.03, G1 - 0.1, TRAY), (x + 0.03, G1 - 0.02, z0), "stand_black")  # rubber foot
    for y, z in ((G0 + TUBE + 0.02, z0), (G1 - TUBE - 0.02, z0), (G0 + TUBE + 0.02, z1), (G1 - TUBE - 0.02, z1)):
        k.bar((-(GX - TUBE), y, z), ((GX - TUBE), y, z), TUBE, "gen_yellow", seg=TUBE_SEG, cap=False)
    cy = (G0 + G1) * 0.5
    for sx in (-1.0, 1.0):
        k.bar((sx * 0.22, cy, z1), (sx * 0.22, cy, HIGH - TUBE), TUBE, "gen_yellow", seg=TUBE_SEG)
    k.bar((-0.24, cy, HIGH - TUBE), (0.24, cy, HIGH - TUBE), TUBE, "gen_yellow", seg=TUBE_SEG)
    # Wheels at the left end, the handle at the right, its black grip.
    for sy in (G0 + 0.12, G1 - 0.12):
        k.cyl((-GX + 0.06, sy, TRAY + 0.1), 0.1, 0.07, "rubber", seg=16, axis="x")
        k.cyl((-GX + 0.055, sy, TRAY + 0.1), 0.05, 0.08, "steel_light", seg=SEG, axis="x")
    k.bar((GX - TUBE, G0 + 0.12, z0 + 0.05), (GX - TUBE, G1 - 0.12, z0 + 0.05), TUBE * 1.6, "stand_black", seg=SEG)
    # The engine fills the frame's middle (photos 1 and 3): a crankcase on the frame's rails, its finned cylinder
    # leaning up behind, the big yellow recoil starter cover on the right end with its pull handle, the black air
    # filter box on the front.
    tz0, tz1 = z1 - 0.26, z1 + TUBE * 0.5  # the fuel tank's bottom and top
    k.prism(hs.rounded_rect(0.22, 0.17, 0.05, 2), "x", -0.2, 0.24, "steel", offset=(0.0, cy, z0 + 0.2))
    _fins(k, -0.1, 0.14, cy - 0.13, cy + 0.13, z0 + 0.34, tz0 - 0.005, 7, "steel_light")  # up to the tank
    k.cyl((0.24, cy, z0 + 0.24), 0.2, 0.06, "gen_yellow", seg=16, axis="x")
    k.cyl((0.3, cy, z0 + 0.24), 0.17, 0.012, "gen_ink", seg=16, axis="x")
    for i in range(6):  # the cover's ribs across its grille
        a = math.radians(30.0 * i)
        u, v = 0.15 * math.sin(a), 0.15 * math.cos(a)
        k.bar((0.312, cy - u, z0 + 0.24 - v), (0.312, cy + u, z0 + 0.24 + v), 0.008, "gen_yellow", seg=4)
    k.cyl((0.31, cy, z0 + 0.24), 0.05, 0.03, "steel_light", seg=SEG, axis="x")
    k.blk((0.33, cy - 0.02, z0 + 0.4), (0.38, cy + 0.02, z0 + 0.45), "stand_black")
    k.blk((0.0, G0 + 0.06, z0 + 0.2), (0.22, G0 + 0.2, z0 + 0.46), "gen_ink")
    k.blk((0.02, G0 + 0.05, z0 + 0.38), (0.2, G0 + 0.07, z0 + 0.44), "steel_light")
    # The alternator drum at the left, vented, its end bell to the wheels; the muffler box behind with its heat guard
    # and tail pipe.
    k.cyl((-0.48, cy, z0 + 0.24), 0.19, 0.3, "gen_panel", seg=16, axis="x")
    k.cyl((-0.5, cy, z0 + 0.24), 0.15, 0.02, "steel", seg=SEG, axis="x")
    my0, my1 = cy + 0.19, cy + 0.38
    k.blk((-0.2, my0, z0 + 0.24), (0.12, my1, z0 + 0.52), "steel_light")
    for i in range(6):
        x = -0.18 + i * 0.05
        k.blk((x, my1, z0 + 0.26), (x + 0.025, my1 + 0.007, z0 + 0.5), "steel")
    k.bar((0.12, my0 + 0.08, z0 + 0.3), (0.22, my0 + 0.08, z0 + 0.3), 0.022, "stand_black", seg=SEG)
    # The fuel tank over it all, filling the frame's top on brackets from the top rails: dark, its edges rounded, a
    # filler cap and a gauge.
    for sx in (-1.0, 1.0):
        k.blk((sx * 0.4 - 0.025, G0 + TUBE, tz0 + 0.02), (sx * 0.4 + 0.025, G1 - TUBE, tz0 + 0.035), "stand_black")
    rings = []
    for z, s, r in ((tz0, 0.0, 0.06), (tz0 + 0.03, 0.03, 0.09), (tz1 - 0.04, 0.03, 0.09), (tz1, -0.03, 0.07)):
        rings.append([(x, y + cy, z) for x, y in hs.rounded_rect(0.46 + s, 0.36 + s, r, 2)])
    k.loft(rings, "gen_ink")
    k.cyl((0.28, cy + 0.08, tz1), 0.06, 0.03, "steel_light", seg=SEG)
    k.cyl((0.28, cy + 0.08, tz1 + 0.03), 0.045, 0.012, "steel_light", seg=SEG)
    k.cyl((-0.26, cy + 0.1, tz1), 0.035, 0.008, "steel_light", seg=SEG)
    # The control panel on the front, angled back a little: an ink panel with two socket housings (a yellow one and
    # a grey), the run switch, two breakers and the hour meter.
    py = G0 + 0.07
    k.blk((-0.46, py - 0.02, z0 + 0.12), (-0.02, py + 0.06, z0 + 0.56), "gen_ink")
    k.blk((-0.47, py - 0.025, z0 + 0.11), (-0.01, py - 0.015, z0 + 0.57), "gen_panel")
    for x, mat in ((-0.35, "socket_yellow"), (-0.17, "socket_grey")):
        k.cyl((x, py - 0.06, z0 + 0.36), 0.062, 0.04, "stand_black", seg=24, axis="y")
        k.cyl((x, py - 0.075, z0 + 0.36), 0.056, 0.016, mat, seg=24, axis="y")
        k.blk((x - 0.06, py - 0.085, z0 + 0.422), (x + 0.06, py - 0.02, z0 + 0.44), mat)  # its hinged lid
    k.blk((-0.07, py - 0.04, z0 + 0.38), (-0.04, py - 0.02, z0 + 0.46), "socket_grey")
    for x in (-0.42, -0.36):
        k.blk((x, py - 0.035, z0 + 0.17), (x + 0.04, py - 0.02, z0 + 0.23), "stand_black")
    k.cyl((-0.14, py - 0.03, z0 + 0.2), 0.035, 0.008, "steel_light", seg=SEG, axis="y")
    # Two jerry cans in the tray's spare depth behind the generator, lying along it: a pressed X on the side facing
    # out, three grips along the top, a spout cap.
    cw, cl, ch = 0.165, 0.35, 0.47  # a jerry can's width, length and height
    yc = (G1 + HW) * 0.5 + 0.01
    for xc in (-0.23, 0.23):
        x0, x1 = xc - cl * 0.5, xc + cl * 0.5
        k.blk((x0, yc - cw * 0.5, TRAY * 0.2), (x1, yc + cw * 0.5, ch), "can_green")
        ys = yc + cw * 0.5 + 0.002
        k.sqbar((x0 + 0.04, ys, 0.06), (x1 - 0.04, ys, ch - 0.06), 0.012, "can_green", h=0.006)
        k.sqbar((x0 + 0.04, ys, ch - 0.06), (x1 - 0.04, ys, 0.06), 0.012, "can_green", h=0.006)
        for i in range(3):
            x = x0 + 0.05 + i * 0.06
            k.blk((x, yc - 0.06, ch), (x + 0.014, yc + 0.06, ch + 0.04), "can_green")
        k.blk((x0 + 0.04, yc - 0.06, ch + 0.03), (x0 + 0.2, yc + 0.06, ch + 0.045), "can_green")
        k.cyl((x1 - 0.05, yc, ch - 0.01), 0.026, 0.05, "stand_black", seg=SEG)
    ob = k.build()
    rk.finish(ob, angle=math.radians(45.0))
    rk.clamp_to(ob, (-HW, -HW, 0.0), (HW, HW, HIGH))
    rk.bake(ob, seed=9)
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
            ("Front quarter (control panel)", (-2.0, -2.8, 1.6), (0.0, -0.2, 0.55), 35),
            ("Right end (recoil starter, handle)", (2.6, -1.6, 1.3), (0.0, -0.2, 0.55), 35),
            ("Rear quarter (muffler, fuel cans)", (2.0, 2.8, 1.7), (0.0, 0.1, 0.5), 35),
            ("Control panel close-up", (-0.4, -1.5, 0.8), (-0.2, -0.55, 0.5), 40),
            ("Top: tank, lifting bar", (-1.2, -1.6, 2.6), (0.0, -0.1, 0.9), 35),
            ("From 10 m", (-3.0, -9.5, 1.6), (0.0, 0.0, 0.6), 40),
        ], sys.argv[sys.argv.index("--render") + 1], "RM1 generator (map prop): from William's generator photos")


if __name__ == "__main__":
    main()
