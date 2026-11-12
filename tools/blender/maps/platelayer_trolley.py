"""Subway's platelayers' trolleys (SM4, model 9): a small four-wheel push trolley left on the track with its tools,
from the owner's photos (art/references/maps/subway/09-platelayer-trolley, the red works trolleys): a channel-steel
frame on four flanged wheels, a timber deck of four boards, a tall steel screen at one end with its tubular rail over
it (photos 3 and 4), a low push rail along the other end, and the tools lying on the deck: a shovel, a pick, a long
bar. Works yellow, worn and rusty (the photos' red is the Beta team's hue once weathered); no lettering.

Its three blocks (data/maps/subway.json) are three sizes, so three models, each built at its block's size:
`platelayer_trolley` 1.5 x 1.3 m, `platelayer_trolley_short` 1.5 x 1.0 m and `platelayer_trolley_long` 2 x 1.3 m, all
1.2 m high. The trolleys stand off the main rails, so each stands on a length of works track (works_kit.py).

Writes assets/models/props/platelayer_trolley*.glb, each one vertex-coloured mesh filling x -L/2..L/2 (along the
track), y -W/2..W/2, z 0..1.2 exactly (Godot: x along, y up, z across).

Usage: python3 -I tools/blender/maps/platelayer_trolley.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET = 1200
HIGH = 1.2
SIZES = {"platelayer_trolley": (1.5, 1.3), "platelayer_trolley_short": (1.5, 1.0),
         "platelayer_trolley_long": (2.0, 1.3)}
WHEEL_R = 0.26
SPOKES = 5


def spoked_wheel(k: wk.Kit, x: float, y: float, z: float, outward: float) -> None:
    """A cast spoked wheel turning about y at (x, y, z), its flange inside: a flanged rim, five spokes and the hub,
    open between the spokes (the photos' trolleys run on big spoked wheels, all of them in sight)."""
    w = 0.055
    s = outward
    a0, a1 = y - s * w * 0.5, y + s * w * 0.5  # the flange's side, the outer side
    lo, hi = sorted((a0, a1))
    flange_out = [(a0, WHEEL_R + 0.022), (a1, WHEEL_R)]  # the tread coned out to the flange
    inner = [(a0, WHEEL_R - 0.035), (a1, WHEEL_R - 0.035)]
    if s < 0:  # the tube runs low to high along y
        flange_out = [(a1, WHEEL_R), (a0, WHEEL_R + 0.022)]
        inner = [(a1, WHEEL_R - 0.035), (a0, WHEEL_R - 0.035)]
    k.tube([(a, r) for a, r in flange_out], inner, "wheel", segments=16, centre=(x, 0.0, z), axis="y")
    k.cyl((x, lo, z), 0.065, hi - lo, "wheel", seg=6, axis="y")  # the hub
    for i in range(SPOKES):
        a = 2.0 * math.pi * (i + 0.25) / SPOKES
        c, sn = math.cos(a), math.sin(a)
        r0, r1 = 0.055, WHEEL_R - 0.03  # a spoke: a three-sided bar from the hub to the rim, its ends inside them
        ring = [(-0.022, -0.0125), (0.022, -0.0125), (0.0, 0.0145)]
        k.loft([[(x + r * c - u * sn, y + v, z + r * sn + u * c) for u, v in ring] for r in (r0, r1)], "wheel",
               cap0=False, cap1=False)


def build(name: str, length: float, width: float) -> object:
    hl, hw = length * 0.5, width * 0.5
    k = wk.Kit(name)
    rail_top = k.works_track(-hl, hl, sleeper_len=min(1.3, width - 0.1), pitch=0.8)
    k.mark("track")
    zc = rail_top + WHEEL_R
    ax = hl - 0.34
    gy = 0.45 + 0.0275           # the wheels' middles: their flanges' faces on the 900 mm gauge
    for x in (-ax, ax):
        for sy in (-1.0, 1.0):
            spoked_wheel(k, x, sy * gy, zc, sy)
        k.bar((x, -gy, zc), (x, gy, zc), 0.03, "wheel", seg=6, cap=False)  # the axle
    fy = 0.36                    # the side frames inside the wheels, the axles' bearings in them
    f0, f1 = zc - 0.05, zc + 0.07
    for sy in (-1.0, 1.0):
        y0, y1 = sorted((sy * fy, sy * (fy - 0.05)))
        k.blk((-hl + 0.04, y0, f0), (hl - 0.04, y1, f1), "trolley_yellow")
    dz = zc + WHEEL_R + 0.035    # the deck clears the wheels' tops
    for x in (-ax, ax, -hl + 0.05, hl - 0.05):  # bearers across, from the side frames up to the deck
        k.blk((x - 0.035, -hw + 0.01, dz - 0.06), (x + 0.035, hw - 0.01, dz), "trolley_yellow")
    for x in (-ax, ax):
        for sy in (-1.0, 1.0):
            y0, y1 = sorted((sy * fy, sy * (fy - 0.05)))
            k.blk((x - 0.03, y0, f1), (x + 0.03, y1, dz - 0.06), "trolley_yellow")
    k.mark("wheels+frame")
    # The deck: four boards along the trolley over the wheels, a gap between each.
    fy = hw
    n = 4
    bw = (2 * fy - 0.03 * (n - 1)) / n
    for i in range(n):
        y = -fy + i * (bw + 0.03)
        k.blk((-hl + 0.02, y, dz), (hl - 0.02, y + bw, dz + 0.04), "timber")
    f1 = dz
    deck = dz + 0.04
    # The screen at the +x end: a steel sheet on its frame, and the tube rail over it to the box's top.
    sx0, sx1 = hl - 0.07, hl - 0.04
    k.blk((sx0, -fy, deck), (sx1, fy, HIGH - 0.24), "trolley_yellow")
    for y in (-fy + 0.03, fy - 0.03):
        k.blk((sx0 - 0.03, y - 0.03, f1), (sx1, y + 0.03, HIGH - 0.03), "trolley_yellow")
        k.bar((sx0 + 0.015, y, HIGH - 0.24), (sx0 + 0.015, y, HIGH - 0.025), 0.022, "trolley_yellow", seg=5,
              cap=False)
    k.bar((sx0 + 0.015, -fy + 0.03, HIGH - 0.022), (sx0 + 0.015, fy - 0.03, HIGH - 0.022), 0.022, "trolley_yellow",
          seg=5)
    for y in (-fy * 0.33, fy * 0.33):
        k.bar((sx0 + 0.015, y, HIGH - 0.24), (sx0 + 0.015, y, HIGH - 0.025), 0.016, "trolley_yellow", seg=5,
              cap=False)
    # The push rail at the -x end: two uprights and the bar across, at waist height.
    for y in (-fy + 0.05, fy - 0.05):
        k.bar((-hl + 0.06, y, f1), (-hl + 0.06, y, 0.95), 0.02, "trolley_yellow", seg=5, cap=False)
    k.bar((-hl + 0.06, -fy + 0.05, 0.95), (-hl + 0.06, fy - 0.05, 0.95), 0.02, "trolley_yellow", seg=5)
    k.mark("deck+rails")
    # The tools: a shovel lying across the boards and a long bar along them.
    lx = length - 0.4
    k.bar((-hl + 0.2, -fy + 0.15, deck + 0.02), (-hl + 0.2 + lx * 0.8, -fy + 0.35, deck + 0.02), 0.016, "timber",
          seg=5)  # the shovel's shaft
    x1 = -hl + 0.2 + lx * 0.8
    k.prism([(-0.12, 0.0), (0.12, 0.0), (0.1, 0.26), (-0.1, 0.26)], "z", deck + 0.005, deck + 0.02, "steel_bare",
            offset=(x1 + 0.0, -fy + 0.37, 0.0))
    k.bar((-hl + 0.12, 0.0, deck + 0.018), (hl - 0.2, -0.05, deck + 0.018), 0.016, "steel_bare", seg=5)  # the bar
    k.mark("tools")
    return k.build()


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint == "trolley_yellow":
        col = wk.rusty(p, n, c, seed=13, amount=0.6)
        if p.z > HIGH - 0.06:  # the rail worn bare where it's pushed
            col = wt.mix(col, wk.lin("steel_bare"), 0.45 * wt.fbm(p, 0.06, 15))
        return wk.grime(p, n, col, seed=6)
    if paint in ("rail", "wheel", "rust", "skip_grey"):
        return wk.grime(p, n, wk.rusty(p, n, c, seed=7, amount=0.4, streaks=False), seed=2)
    return wk.grime(p, n, c, seed=4)


def main() -> None:
    wk.check_colours(list(wk.PAINT))
    for name, (length, width) in SIZES.items():
        wk.reset()
        ob = build(name, length, width)
        wk.finish(ob, (-length * 0.5, -width * 0.5, 0.0), (length * 0.5, width * 0.5, HIGH))
        wk.bake(ob, weather, jitter={"sleeper": 0.08, "timber": 0.08})
        wk.write(ob, name, BUDGET)
        if "--render" in sys.argv:
            out = sys.argv[sys.argv.index("--render") + 1].replace(".jpg", "_%s.jpg" % name)
            wk.render(wk.quarter_views(length, width, HIGH), out,
                      "SM4 %s (Subway map prop, %g x %g x 1.2 m)" % (name.replace("_", " "), length, width))


if __name__ == "__main__":
    main()
