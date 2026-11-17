"""The range's chrono table (RQ1, 0.1 Beta 2): where an airsoft site checks every replica's power before play. A
folding trestle table (a grey moulded plastic top with its rolled edge, grey steel tube legs folding to crossed feet)
and on it: the chronograph, a black tube on a timber block with its display, a clipboard with the day's sheet, a bottle
of BBs, a weighing tray of loose BBs and a spare magazine lying flat. No brand or writing (the sign over it is the
wall's, range_extras.py).

Writes assets/models/props/chrono_table.glb, one vertex-coloured mesh filling x -0.9..0.9, y -0.375..0.375, z 0..0.95
exactly (its block in range.json; Godot: x across, y up, z deep), the chronograph's muzzle end towards -x.

Usage: python3 -I tools/blender/maps/chrono_table.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import range_kit as rk  # noqa: E402
from range_kit import hs  # noqa: E402

OUT = os.path.join(rk.PROPS, "chrono_table.glb")
BUDGET = 3700  # docs/CC0_ASSETS.md › Size limits: a prop (about 95 % used)
HX, HY, HIGH = 0.9, 0.375, 0.95
TOP = 0.7  # the top's underside
TOP_T = 0.04
LEG_R = 0.0125

rk.PAINT.update({
    "table_top": 0xd4d2cc,
    "table_edge": 0xbcbab4,
    "leg_grey": 0x7a7a7e,
    "foot_black": 0x2a2a2c,
    "chrono_black": 0x262628,
    "screen": 0x6e7a6a,  # the unlit display's grey-green
    "block_timber": 0x9a9078,
    "paper": 0xeeece4,
    "clip": 0x8a8a8e,
    "board_brown": 0x6e665a,
    "mag_black": 0x303034,
    "tray": 0x9a9a9e,
    "bottle": 0xe4e2da,
    "bottle_cap": 0x2c2c2e,
    "bb_white": 0xf0eee8,
})
rk.check_colours(["table_top", "table_edge", "leg_grey", "foot_black", "chrono_black", "screen", "block_timber",
                  "paper", "clip", "board_brown", "mag_black", "tray", "bottle", "bottle_cap", "bb_white"], shade=0.08)


def _legs(k: rk.Kit, sx: float) -> None:
    """One end's folding legs: two tubes down from a hinge bar under the top, splayed out to a foot bar, with a brace
    back to the top's middle rail."""
    x_top = sx * (HX - 0.18)
    x_foot = sx * (HX - 0.06)
    for sy in (-1.0, 1.0):
        y = sy * (HY - 0.08)
        k.bar((x_top, y, TOP), (x_foot, y, 0.03), LEG_R, "leg_grey", seg=8)
    k.bar((x_foot, -(HY - 0.06), 0.03), (x_foot, HY - 0.06, 0.03), LEG_R * 1.1, "leg_grey", seg=8)
    for sy in (-1.0, 1.0):  # the rubber feet
        k.blk((x_foot - 0.02, sy * (HY - 0.06) - 0.025, 0.0), (x_foot + 0.02, sy * (HY - 0.06) + 0.025, 0.02),
              "foot_black")
    k.bar((x_top, -(HY - 0.08), TOP - 0.02), (x_top, HY - 0.08, TOP - 0.02), LEG_R, "leg_grey", seg=8)
    k.bar((sx * (HX - 0.4), 0.0, TOP - 0.025), (sx * (HX - 0.12), 0.0, 0.32), LEG_R * 0.8, "leg_grey", seg=6)
    k.bar((sx * (HX - 0.12), -(HY - 0.08), 0.32), (sx * (HX - 0.12), HY - 0.08, 0.32), LEG_R * 0.8, "leg_grey",
          seg=6)


def _chrono(k: rk.Kit, cx: float, cy: float, z0: float) -> None:
    """The chronograph on its timber block: a black tube along x, the muzzle's flared mouth at -x, the two sensor gates
    clamped round it (a collar each with its sensor housing on top, 0.12 m apart), the display box between them with
    its grey screen and two buttons, and a stand of two feet under the tube."""
    k.blk((cx - 0.13, cy - 0.06, z0), (cx + 0.13, cy + 0.06, z0 + 0.05), "block_timber")
    zc = z0 + 0.05 + 0.034
    for x in (cx - 0.08, cx + 0.08):  # the stand's feet, the tube's saddles
        k.blk((x - 0.012, cy - 0.035, z0 + 0.05), (x + 0.012, cy + 0.035, zc - 0.018), "foot_black")
    k.lathe([(0.0, 0.026), (0.02, 0.022), (0.22, 0.022), (0.23, 0.019)], "chrono_black", segments=16,
            centre=(cx - 0.11, cy, zc), axis="x")
    k.lathe([(-0.014, 0.034), (-0.014, 0.03), (0.0, 0.026)], "foot_black", segments=16, centre=(cx - 0.11, cy, zc),
            axis="x")
    for x in (cx - 0.06, cx + 0.06):  # the gates: a collar and its sensor housing
        k.lathe([(0.0, 0.025), (0.0, 0.03), (0.022, 0.03), (0.022, 0.025)], "clip", segments=16,
                centre=(x - 0.011, cy, zc), axis="x")
        k.blk((x - 0.014, cy - 0.018, zc + 0.026), (x + 0.014, cy + 0.018, zc + 0.05), "chrono_black")
        k.blk((x - 0.006, cy - 0.019, zc + 0.034), (x + 0.006, cy + 0.019, zc + 0.04), "screen")  # the sensor's eye
    k.blk((cx - 0.04, cy - 0.032, zc + 0.022), (cx + 0.04, cy + 0.032, zc + 0.056), "chrono_black")
    k.blk((cx - 0.032, cy - 0.026, zc + 0.056), (cx + 0.018, cy + 0.026, zc + 0.058), "screen")
    for y in (cy - 0.012, cy + 0.012):
        k.cyl((cx + 0.029, y, zc + 0.056), 0.006, 0.004, "foot_black", seg=8)


def _clipboard(k: rk.Kit, cx: float, cy: float, z0: float, turn: float) -> None:
    """A clipboard turned `turn` (rad) on the table: the board, the day's sheet on it and the clip at its head."""
    faces = []
    faces += k.blk((-0.115, -0.16, 0.0), (0.115, 0.16, 0.004), "board_brown")
    faces += k.blk((-0.105, -0.15, 0.004), (0.105, 0.13, 0.0055), "paper")
    for row in range(7):  # the sheet's ruled rows of names and readings
        y = -0.12 + row * 0.033
        faces += k.blk((-0.09, y, 0.0055), (0.09, y + 0.003, 0.006), "clip")
    faces += k.blk((-0.05, 0.12, 0.004), (0.05, 0.155, 0.016), "clip")
    from mathutils import Matrix
    k.transform(faces, Matrix.Translation((cx, cy, z0)) @ Matrix.Rotation(turn, 4, "Z"))


def _magazine(k: rk.Kit, cx: float, cy: float, z0: float) -> None:
    """A spare rifle magazine lying on its side, curved, along x: its body and base plate."""
    rings = []
    for i in range(7):
        t = i / 6
        x = cx - 0.09 + t * 0.18
        bow = 0.02 * math.sin(t * math.pi)
        w = 0.033 - 0.004 * t
        ring = [(x, cy - bow + y, z0 + 0.0125 + z) for y, z in hs.rounded_rect(w, 0.0125, 0.004, 1)]
        rings.append(ring)
    k.loft(rings, "mag_black")
    k.blk((cx + 0.088, cy - 0.04, z0), (cx + 0.1, cy + 0.032, z0 + 0.027), "foot_black")


def build() -> object:
    k = rk.Kit("ChronoTable")
    # the top: a moulded slab with its rolled edge proud below the surface, and a frame rail under each long side
    k.blk((-HX + 0.02, -HY + 0.02, TOP + 0.012), (HX - 0.02, HY - 0.02, TOP + TOP_T), "table_top")
    rim = [(x, y, 0.0) for x, y in hs.rounded_rect(HX, HY, 0.03, 3)]
    rings = [[(x, y, TOP + 0.0) for x, y, _ in rim], [(x, y, TOP + TOP_T) for x, y, _ in rim]]
    k.loft(rings, "table_edge", cap0=True, cap1=False)
    for sy in (-1.0, 1.0):
        k.blk((-HX + 0.1, sy * (HY - 0.07) - 0.012, TOP - 0.03), (HX - 0.1, sy * (HY - 0.07) + 0.012, TOP),
              "leg_grey")
    _legs(k, -1.0)
    _legs(k, 1.0)
    top = TOP + TOP_T
    _chrono(k, -0.42, -0.05, top)
    _clipboard(k, 0.12, 0.05, top, 0.18)
    # the BB bottle, and a shallow tray of loose BBs beside the chrono
    k.lathe([(0.0, 0.0), (0.0, 0.034), (0.004, 0.036), (0.05, 0.036)], "bb_white", segments=14,
            centre=(0.45, 0.17, top), axis="z")
    k.lathe([(0.05, 0.036), (0.078, 0.036), (0.088, 0.03), (0.094, 0.016), (0.096, 0.0)], "bottle", segments=14,
            centre=(0.45, 0.17, top), axis="z")
    k.cyl((0.45, 0.17, top + 0.092), 0.019, 0.016, "bottle_cap", seg=12)
    k.blk((-0.12, 0.12, top), (0.0, 0.22, top + 0.006), "tray")
    k.blk((-0.11, 0.13, top + 0.006), (-0.01, 0.21, top + 0.009), "bb_white")
    _magazine(k, 0.55, -0.15, top)
    # the tallest point: a pen stood in a mug (the table's height in the block)
    mug_h = HIGH - top - 0.1
    k.lathe([(0.0, 0.0), (0.0, 0.04), (mug_h, 0.042)], "table_edge", segments=14, centre=(0.72, 0.15, top), axis="z")
    k.bar((0.72, 0.15, top + mug_h - 0.04), (0.735, 0.16, HIGH), 0.005, "foot_black", seg=6)
    ob = k.build()
    rk.finish(ob, bevel=0.002, angle=math.radians(50.0))
    rk.clamp_to(ob, (-HX, -HY, 0.0), (HX, HY, HIGH))
    rk.bake(ob, seed=7)
    rk.occlude(ob, strength=0.45, distance=0.1)
    rk.fit_box(ob, (-HX, -HY, 0.0), (HX, HY, HIGH))
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
            ("Front quarter", (-1.8, -2.0, 1.6), (0.0, 0.0, 0.6), 38),
            ("Top: chronograph, clipboard, BBs, magazine", (0.0, -0.9, 2.0), (0.0, 0.0, 0.75), 42),
            ("Chronograph close-up", (-0.75, -0.55, 1.05), (-0.42, -0.05, 0.82), 40),
            ("Legs", (2.2, -1.2, 0.5), (0.0, 0.0, 0.35), 40),
        ], sys.argv[sys.argv.index("--render") + 1], "Chrono table (Range back wall, RQ1)")


if __name__ == "__main__":
    main()
