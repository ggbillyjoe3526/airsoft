"""Woodland's fern clump (WG2, model 10): assets/models/props/fern.glb, drawn for each of the map's 92 ferns (in 8
beds; 2 m across, 1.2 m tall) by BushView.

From the owner's photos (references/maps/woodland/10-fern-clump): a shuttlecock of fronds rising out of a crown and
arching over, each frond a midrib with leaflets either side, widest a third of the way out, its tip drooping; fresh
green on top, darker underneath and in the clump's heart, the leaflets in turn a shade lighter.

Stylised to the art direction (solid leaf shapes, not see-through cards): every frond is a midrib with eight pairs of
pointed leaflets swept forward over each other, drawn on both sides where you see it from below (the props' material
culls back faces); a few young fronds standing up and arching over, the flanks at a crouch's height and old fronds
spread low to the edge, so the clump is wide at its foot and you can't read through a bed to someone crouched in it (ferns hide a
crouched player; BBs pass straight through, Foliage, and the model has no
collider). Fills the foliage's ellipsoid's box: 2 m across, 1.2 m tall, its ground line at y = 0; the game stretches
it to each fern. Budget 400 triangles (/mnt/project-files/art/woodland-model-list.md). Plain vertex colours.

    python -I tools/blender/maps/fern.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402
import woodkit as wk  # noqa: E402
import hardsurface as hs  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET = 400
RADIUS, HEIGHT = 1.0, 1.2
SEGS = 8            # leaflet pairs along a frond
RINGS = (
    # (fronds, rise °, droop °, length m, leaflet width m, both sides drawn)
    (4, (62.0, 70.0), (125.0, 150.0), (1.3, 1.45), (0.26, 0.3), True),   # young fronds standing up and arching over
    (5, (42.0, 52.0), (95.0, 115.0), (1.2, 1.35), (0.28, 0.32), True),  # the clump's flanks, at a crouch's height
    (7, (14.0, 20.0), (45.0, 60.0), (1.0, 1.15), (0.28, 0.32), False),  # old fronds spread low to the bed's edge
)


def build() -> object:
    hs.reset()
    wk.paint_all()
    r = wk.rng(1000)
    b = hs.Builder("Fern", [])
    # sixteen fronds out of a crown at the ground (photos: a shuttlecock of twenty or more), each a midrib with eight
    # pairs of leaflets swept forward: a few young ones standing up and arching over, the flanks at a crouched body's
    # height, the old ones spread low out to the bed's edge, so the clump is wide at its foot and solid at a crouch, as
    # the game rules (a bed hides you); the low ones are seen from above, so drawn on top only
    n = 0
    for count, rise, droop, length, width, both in RINGS:
        for k in range(count):
            heading = 2.0 * math.pi * (k + 0.5 * (n % 2)) / count + n * 0.45 + r.uniform(-0.2, 0.2)
            wk.pinna_frond(b, Vector((math.cos(heading) * 0.05, math.sin(heading) * 0.05, 0.06)), heading,
                           math.radians(r.uniform(*rise)), r.uniform(*length), r.uniform(*width), SEGS,
                           math.radians(r.uniform(*droop)), r, ("Fern", "FernLight", "FernLight"), both)
        n += 1
    ob = b.build()
    wk.finish(ob, 25.0)
    wk.fit_box(ob, (-RADIUS, -RADIUS, -0.02), (RADIUS, RADIUS, HEIGHT))
    return ob


def main() -> None:
    ob = build()
    mk.report(ob, "fern", BUDGET)
    print("  wrote", mk.export_prop(ob, "fern"))


if __name__ == "__main__":
    main()
