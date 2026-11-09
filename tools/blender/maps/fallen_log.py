"""Woodland's fallen logs (WG2, model 14): assets/models/props/fallen_log_5.glb, _6 and _8, for the map's ten lying
logs (5 to 8 m long, 0.7 to 0.8 m across, 0.6 m over the ground).

From the owner's photos (references/maps/woodland/14-fallen-log): a long trunk lying on the leaf litter, a little
bent and tapering, its bark in dark ridged furrows, weathered grey where it has peeled; one end sawn (pale wood, a
darker heart), the other snapped off in splinters round a rotten hollow; moss in patches along its top, a couple of
bracket fungi on its side and the snapped stubs of its branches.

Fills its block's box: its length the box's long side, its girth the box's width, its top 0.6 m over the ground line
(the model's y = 0), sunk a little under it. The game stands it on the ground in its box's middle and fills the rest of
the box under it, where the ground falls away, with an earth bank (PropDressConfig.Lay.GROUND). Budget 1,500
triangles each (/mnt/project-files/art/woodland-model-list.md). Plain vertex colours, no texture.

    python -I tools/blender/maps/fallen_log.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402
import woodkit as wk  # noqa: E402
import hardsurface as hs  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET = 1500
LENGTHS = (5, 6, 8)
TOP = 0.6           # the log's top over the ground line (m), as the map's log blocks
BUTT_R = 0.34       # the sawn butt's radius; the box's 0.7 m width
TIP_R = 0.26        # the snapped end's
SINK = 0.08         # how far its underside sits in the litter
SIDES = 20
RINGS = 24          # rings along it, whatever its length: a long log is seen from further off
WIDTH = 0.72        # across (m): the boxes are 0.7 and 0.8 wide


def build(length: int) -> object:
    hs.reset()
    wk.paint_all()
    r = wk.rng(1400 + length)
    b = hs.Builder("FallenLog%d" % length, [])
    n = RINGS
    path, radii = [], []
    half = length * 0.5 - 0.22  # the splinters reach out to the box's end
    for k in range(n + 1):
        t = k / n
        x = -half + 2.0 * half * t
        rad = BUTT_R + (TIP_R - BUTT_R) * t ** 0.8
        # the butt flares a little where the roots were cut off
        rad *= 1.0 + 0.12 * max(0.0, 1.0 - t * 6.0)
        # a gentle sag and sideways bend, its top held at TOP over the ground at its thickest
        bend_y = 0.08 * math.sin(t * math.pi * 1.3 + 0.4) + 0.02 * math.sin(t * 17.0)
        z = TOP - BUTT_R - 0.02 * math.sin(t * math.pi)
        path.append((x, bend_y, z + (BUTT_R - rad) * -0.6))
        radii.append(rad)
    info = wk.log(b, path, radii, SIDES, r, bark=("Bark", "BarkFurrow"), rough=0.07, furrows=1, ends=("cut", "broken"),
                  moss=0.45, seed=length * 1.7)
    # branch stubs along the top and sides
    for k, (at, ang, ln) in enumerate(((0.35, 0.5, 0.2), (0.55, 2.7, 0.16), (0.72, 0.35, 0.24), (0.86, 2.8, 0.14))):
        i = min(n - 1, int(at * n))
        p, side, up = info["frames"][i]
        d = side * math.cos(ang) + up * math.sin(ang)
        wk.stub(b, p + d * radii[i] * 0.85, d + Vector((0.4 if k % 2 else -0.3, 0, 0)), ln, 0.05 + 0.02 * (k % 2), r)
    # two bracket fungi low on one side, one on the other (photo 1)
    for at, s, w in ((0.42, 1.0, 0.13), (0.47, 1.0, 0.1), (0.62, -1.0, 0.11)):
        i = int(at * n)
        p, side, up = info["frames"][i]
        d = side * s
        wk.bracket(b, p + d * radii[i] * 0.97 + up * 0.04, d, w, r)
    ob = b.build()
    wk.finish(ob)
    wk.fit_box(ob, (-length * 0.5, -WIDTH * 0.5, -SINK), (length * 0.5, WIDTH * 0.5, TOP))
    return ob


def main() -> None:
    for length in LENGTHS:
        ob = build(length)
        name = "fallen_log_%d" % length
        mk.report(ob, name, BUDGET)
        print("  wrote", mk.export_prop(ob, name))


if __name__ == "__main__":
    main()
