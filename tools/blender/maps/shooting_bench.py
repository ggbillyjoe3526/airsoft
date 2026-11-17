"""The range's shooting benches (RQ1, 0.1 Beta 2): an outdoor range's timber bench at the firing line, the kind an
airsoft site knocks up from treated posts and decking boards, weathered grey-brown: four square legs, an apron under a
top of five boards with shadow gaps, stretchers and a slatted shelf low down, and on the top what a player leaves
there between strings: a hessian rest bag at the front, an olive steel ammo can for the magazines and a bottle of BBs.
No brand or writing.

Writes assets/models/props/shooting_bench.glb, one vertex-coloured mesh filling x -0.9..0.9, y -0.4..0.4, z 0..0.9
exactly (its block in range.json, 1.8 x 0.9 x 0.8 m; Godot: x across, y up, z deep), its front (the rest bag) towards
-y (Godot's +z, the front PropLayout turns towards the field's middle: downrange).

Usage: python3 -I tools/blender/maps/shooting_bench.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import range_kit as rk  # noqa: E402
from range_kit import hs  # noqa: E402

OUT = os.path.join(rk.PROPS, "shooting_bench.glb")
BUDGET = 4200  # docs/CC0_ASSETS.md › Size limits: a prop (four stand at the firing line)
HX, HY, HIGH = 0.9, 0.4, 0.9
LEG = 0.07
LEG_X, LEG_Y = 0.78, 0.31  # the legs' middles
TOP = 0.74  # the top boards' underside
BOARD_T = 0.036
BOARD_W = (2 * HY - 4 * 0.008) / 5  # five boards and their gaps fill the depth
GAP = 0.008
APRON = 0.095
SHELF = 0.2  # the low shelf's slats' underside

rk.PAINT.update({
    # weathered treated timber: grey-brown, its end grain darker; the shelf a shade lighter (less sun-bleached)
    "bench_timber": 0xa59a84,
    "bench_dark": 0x857b68,
    "bench_light": 0xb5ab95,
    # the ammo can's olive drab and its worn edges, the BB bottle and its cap
    "can_olive": 0x58613f,
    "can_edge": 0x777a66,
    "bottle": 0xe4e2da,
    "bottle_cap": 0x2c2c2e,
    "bb_white": 0xf0eee8,
})
rk.check_colours(["bench_timber", "bench_dark", "bench_light", "can_olive", "can_edge", "bottle", "bottle_cap",
                  "hessian", "hessian_dark", "tie"], shade=0.08)


def _rest_bag(k: rk.Kit, cx: float, cy: float, z0: float, hx: float, hy: float, hz: float) -> None:
    """A hessian rest bag lying on the top along x, the kind a shooter beds a forend into: a pillow full in its belly,
    `hx` either side, `hy` deep and `hz` high there, its foot flat on the boards. Each end is a sewn seam, flat and
    still wide, its corners standing out as ears; along its middle a groove pressed in where the forend lies. A dark
    stitched band across each seam and the tied neck's cord at the +x end."""
    rings = []
    steps = 12
    for i in range(steps + 1):
        t = -1.0 + 2.0 * i / steps
        swell = math.cos(t * math.pi * 0.5) ** 0.5
        sy = hy * (0.66 + 0.34 * swell)  # the ends stay wide: the seam's ears
        sz = hz * (0.14 + 0.86 * swell)  # and flat
        n = 2.6 + 3.0 * (1.0 - swell)  # squarer towards the seam, so its corners read as ears
        ring = []
        for x2, z2 in hs.superellipse(sy, sz, sz * 0.55, n, 16):
            if z2 > 0.0:  # the groove along the top, deepest mid-length
                z2 -= 0.3 * hz * swell * max(0.0, 1.0 - (x2 / (sy * 0.7)) ** 2)
            ring.append((cx + t * hx, cy + x2, z0 + sz * 0.55 + max(z2, -sz * 0.55)))
        rings.append(ring)
    k.loft(rings, "hessian", cap0=True, cap1=True)
    for sx in (-1.0, 1.0):  # the stitched seams
        x = cx + sx * hx * 0.97
        k.blk((x - 0.006, cy - hy * 0.68, z0), (x + 0.006, cy + hy * 0.68, z0 + hz * 0.2), "hessian_dark")
    # the neck's cord, wound round the +x end's seam
    k.cyl((cx + hx * 0.9, cy, z0 + hz * 0.3), 0.016, 0.026, "tie", seg=10, axis="x")


def _ammo_can(k: rk.Kit, cx: float, cy: float, z0: float, h: float = 0.1) -> None:
    """A steel ammo can, long side along x: its body, the lid lipped over the top with its seal ridge, the hinge along
    the back, the cam latch on the -x end and the folded carry handle on the lid."""
    lx, ly = 0.14, 0.075
    k.blk((cx - lx, cy - ly, z0), (cx + lx, cy + ly, z0 + h), "can_olive")
    k.blk((cx - lx + 0.004, cy - ly + 0.004, z0 + h), (cx + lx - 0.004, cy + ly - 0.004, z0 + h + 0.004), "can_edge")
    k.blk((cx - lx - 0.004, cy - ly - 0.004, z0 + h - 0.018), (cx + lx + 0.004, cy + ly + 0.004, z0 + h - 0.006),
          "can_olive")
    # ribs pressed into the long sides
    for x in (cx - 0.07, cx, cx + 0.07):
        for sy in (-1.0, 1.0):
            k.blk((x - 0.012, cy + sy * ly - 0.003, z0 + 0.02), (x + 0.012, cy + sy * ly + 0.003, z0 + 0.065),
                  "can_olive")
    k.cyl((cx - lx, cy + ly + 0.006, z0 + h - 0.012), 0.006, 2 * lx, "can_edge", seg=6, axis="x")  # hinge
    k.blk((cx - lx - 0.012, cy - 0.03, z0 + h - 0.05), (cx - lx, cy + 0.03, z0 + h + 0.002), "can_edge")  # latch
    # the handle folded flat on the lid
    k.blk((cx - 0.05, cy - 0.012, z0 + h + 0.004), (cx + 0.05, cy + 0.012, z0 + h + 0.012), "bottle_cap")
    for x in (cx - 0.055, cx + 0.055):
        k.blk((x - 0.008, cy - 0.016, z0 + h + 0.002), (x + 0.008, cy + 0.016, z0 + h + 0.008), "can_edge")


def _bb_bottle(k: rk.Kit, cx: float, cy: float, z0: float) -> None:
    """A squat bottle of BBs: its shouldered body, the BBs seen white through its lower half, a dark screw cap."""
    k.lathe([(0.0, 0.0), (0.0, 0.034), (0.004, 0.036), (0.05, 0.036)], "bb_white", segments=14,
            centre=(cx, cy, z0), axis="z")
    k.lathe([(0.05, 0.036), (0.078, 0.036), (0.088, 0.03), (0.094, 0.016), (0.096, 0.0)], "bottle", segments=14,
            centre=(cx, cy, z0), axis="z")
    k.cyl((cx, cy, z0 + 0.092), 0.019, 0.016, "bottle_cap", seg=12)


def build() -> object:
    k = rk.Kit("ShootingBench")
    # the legs, their tops chamfered under the apron
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            x, y = sx * LEG_X, sy * LEG_Y
            k.blk((x - LEG / 2, y - LEG / 2, 0.0), (x + LEG / 2, y + LEG / 2, TOP), "bench_timber")
    # the apron: front and back rails along x outside the legs, end rails along y between them
    for sy in (-1.0, 1.0):
        y = sy * (LEG_Y + LEG / 2 + 0.0175)
        k.blk((-LEG_X - LEG / 2 - 0.02, y - 0.0175, TOP - APRON), (LEG_X + LEG / 2 + 0.02, y + 0.0175, TOP),
              "bench_timber")
    for sx in (-1.0, 1.0):
        x = sx * LEG_X
        k.blk((x - 0.0175, -LEG_Y + LEG / 2, TOP - APRON), (x + 0.0175, LEG_Y - LEG / 2, TOP), "bench_dark")
    # the stretchers low down, and the shelf's slats across them
    for sy in (-1.0, 1.0):
        y = sy * (LEG_Y - LEG / 2 - 0.0175)
        k.blk((-LEG_X + LEG / 2, y - 0.0175, SHELF - 0.07), (LEG_X - LEG / 2, y + 0.0175, SHELF), "bench_timber")
    for sx in (-1.0, 1.0):
        x = sx * LEG_X
        k.blk((x - 0.0175, -LEG_Y + LEG / 2, SHELF - 0.07), (x + 0.0175, LEG_Y - LEG / 2, SHELF), "bench_dark")
    for i in range(5):
        x = -0.6 + i * 0.3
        k.blk((x - 0.055, -LEG_Y + 0.02, SHELF), (x + 0.055, LEG_Y - 0.02, SHELF + 0.022), "bench_light")
    # a second can stowed on the shelf
    _ammo_can(k, 0.36, 0.0, SHELF + 0.022)
    # the top: five boards along x with shadow gaps, overhanging the apron
    total = 5 * BOARD_W + 4 * GAP
    y0 = -total / 2
    for i in range(5):
        a = y0 + i * (BOARD_W + GAP)
        k.blk((-HX, a, TOP), (HX, a + BOARD_W, TOP + BOARD_T), "bench_timber")
        # the board's two screws over each leg's rail, flush and dark
        for x in (-LEG_X, LEG_X):
            for dy in (0.035, BOARD_W - 0.035):
                k.blk((x - 0.006, a + dy - 0.006, TOP + BOARD_T), (x + 0.006, a + dy + 0.006, TOP + BOARD_T + 0.0015),
                      "bottle_cap")
    top = TOP + BOARD_T
    # what stands on the top: the rest bag at the front, the ammo can and the BBs behind
    _rest_bag(k, -0.18, -0.22, top, 0.2, 0.085, 0.055)
    _ammo_can(k, 0.5, 0.12, top, HIGH - top - 0.012)  # its handle the bench's highest point
    _bb_bottle(k, 0.14, 0.22, top)
    ob = k.build()
    rk.finish(ob, bevel=0.003, angle=math.radians(50.0))
    rk.clamp_to(ob, (-HX, -HY, 0.0), (HX, HY, HIGH))
    rk.bake(ob, jitter={"bench_timber": 0.07, "bench_light": 0.05, "bench_dark": 0.05}, seed=11)
    rk.occlude(ob, strength=0.5, distance=0.12)
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
            ("Shooter's side quarter", (-1.6, 2.2, 1.6), (0.0, 0.0, 0.6), 38),
            ("Downrange side", (0.0, -2.8, 1.1), (0.0, 0.0, 0.5), 38),
            ("Top: rest bag, ammo can, BBs", (0.2, 0.9, 2.0), (0.1, 0.0, 0.8), 40),
            ("Shelf and legs", (1.6, -1.4, 0.5), (0.0, 0.0, 0.3), 40),
        ], sys.argv[sys.argv.index("--render") + 1], "Shooting bench (Range firing line, RQ1)")


if __name__ == "__main__":
    main()
