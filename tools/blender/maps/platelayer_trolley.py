"""Subway's platelayers' trolleys (SM4, model 9): a small four-wheel push trolley left on the track with its tools,
from the owner's photos (art/references/maps/subway/09-platelayer-trolley, the red works trolleys): a channel-steel
frame on four flanged wheels, a timber deck of five boards, a tall steel screen at one end with its tubular rail over
it (photos 3 and 4), a low push rail along the other end, and the tools lying on the deck: a shovel, a pick, a long
bar and a bucket. Works yellow, worn and rusty (the photos' red is the Beta team's hue once weathered); no lettering.

Its three blocks (data/maps/subway.json) are three sizes, so three models, each built at its block's size:
`platelayer_trolley` 1.5 x 1.3 m, `platelayer_trolley_short` 1.5 x 1.0 m and `platelayer_trolley_long` 2 x 1.3 m, all
1.2 m high. The trolleys stand off the main rails, so each stands on a length of works track (works_kit.py).

Writes assets/models/props/platelayer_trolley*.glb, each one vertex-coloured mesh filling x -L/2..L/2 (along the
track), y -W/2..W/2, z 0..1.2 exactly (Godot: x along, y up, z across).

Usage: python3 -I tools/blender/maps/platelayer_trolley.py [--render <sheet.jpg>]
"""

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
WHEEL_R = 0.17


def build(name: str, length: float, width: float) -> object:
    hl, hw = length * 0.5, width * 0.5
    k = wk.Kit(name)
    rail_top = k.works_track(-hl, hl, sleeper_len=min(1.4, width), pitch=0.7)
    k.mark("track")
    zc = rail_top + WHEEL_R
    ax = hl - 0.3
    for x in (-ax, ax):
        k.wheelset(x, 0.45 - 0.035, zc, WHEEL_R, 0.06, seg=8)
    fy = min(hw, 0.6)            # the frame's half width: as wide as the box, or the deck's 1.2 m
    f0, f1 = zc + 0.04, zc + 0.16
    for s in (-1.0, 1.0):  # channel side frames with the axle bearings under them
        y0, y1 = sorted((s * fy, s * (fy - 0.05)))
        k.blk((-hl + 0.04, y0, f0), (hl - 0.04, y1, f1), "trolley_yellow")
        for x in (-ax, ax):
            yb0, yb1 = sorted((s * 0.5, s * (fy - 0.05)))
            k.blk((x - 0.07, min(yb0, yb1), zc - 0.05), (x + 0.07, max(yb0, yb1), f0), "trolley_yellow")
    for x in (-hl + 0.04, hl - 0.04):  # end frames
        k.blk((x - 0.04, -fy, f0), (x + 0.04, fy, f1), "trolley_yellow")
    k.mark("frame")
    # The deck: five boards across the frame, a gap between each.
    n = 5
    bw = (2 * fy - 0.04 * (n - 1)) / n
    for i in range(n):
        y = -fy + i * (bw + 0.04)
        k.blk((-hl + 0.02, y, f1), (hl - 0.02, y + bw, f1 + 0.04), "timber")
    deck = f1 + 0.04
    # The screen at the +x end: a steel sheet on its frame, and the tube rail over it to the box's top.
    sx0, sx1 = hl - 0.07, hl - 0.04
    k.blk((sx0, -fy, deck), (sx1, fy, HIGH - 0.24), "trolley_yellow")
    for y in (-fy + 0.03, fy - 0.03):
        k.blk((sx0 - 0.03, y - 0.03, f1), (sx1, y + 0.03, HIGH - 0.03), "trolley_yellow")
        k.bar((sx0 + 0.015, y, HIGH - 0.24), (sx0 + 0.015, y, HIGH - 0.025), 0.022, "trolley_yellow", seg=6)
    k.bar((sx0 + 0.015, -fy + 0.03, HIGH - 0.022), (sx0 + 0.015, fy - 0.03, HIGH - 0.022), 0.022, "trolley_yellow",
          seg=6)
    for y in (-fy * 0.33, fy * 0.33):
        k.bar((sx0 + 0.015, y, HIGH - 0.24), (sx0 + 0.015, y, HIGH - 0.025), 0.016, "trolley_yellow", seg=6)
    # The push rail at the -x end: two uprights and the bar across, at waist height.
    for y in (-fy + 0.05, fy - 0.05):
        k.bar((-hl + 0.06, y, f1), (-hl + 0.06, y, 0.95), 0.02, "trolley_yellow", seg=6)
    k.bar((-hl + 0.06, -fy + 0.05, 0.95), (-hl + 0.06, fy - 0.05, 0.95), 0.02, "trolley_yellow", seg=6)
    k.mark("deck+rails")
    # The tools: a shovel and a pick lying across the boards, a long bar along them, a bucket by the screen.
    lx = length - 0.4
    k.bar((-hl + 0.2, -fy + 0.15, deck + 0.02), (-hl + 0.2 + lx * 0.8, -fy + 0.35, deck + 0.02), 0.016, "timber",
          seg=5)  # the shovel's shaft
    x1 = -hl + 0.2 + lx * 0.8
    k.prism([(-0.12, 0.0), (0.12, 0.0), (0.1, 0.26), (-0.1, 0.26)], "z", deck + 0.005, deck + 0.02, "steel_bare",
            offset=(x1 + 0.0, -fy + 0.37, 0.0))
    k.bar((-hl + 0.3, fy - 0.2, deck + 0.025), (-hl + 0.3 + lx * 0.7, fy - 0.35, deck + 0.025), 0.02, "timber",
          seg=5)  # the pick's helve, its head across the end
    px = -hl + 0.3 + lx * 0.7
    k.sqbar((px, fy - 0.6, deck + 0.03), (px + 0.02, fy - 0.1, deck + 0.03), 0.03, "steel_bare")
    k.bar((-hl + 0.12, 0.0, deck + 0.018), (hl - 0.2, -0.05, deck + 0.018), 0.016, "steel_bare", seg=5)  # the bar
    k.lathe([(0.0, 0.11), (0.28, 0.14), (0.28, 0.13), (0.03, 0.1)], "skip_grey", segments=10,
            centre=(hl - 0.25, fy * 0.45, deck), axis="z", cap=False)  # the bucket
    k.cyl((hl - 0.25, fy * 0.45, deck), 0.11, 0.03, "skip_grey", seg=10)
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
