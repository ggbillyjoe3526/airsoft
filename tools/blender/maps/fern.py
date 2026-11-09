"""Woodland's fern clump (WG2, model 10): assets/models/props/fern.glb, drawn for each of the map's 92 ferns (in 8
beds; 2 m across, 1.2 m tall) by BushView.

From the owner's photos (references/maps/woodland/10-fern-clump): a shuttlecock of fronds rising out of a crown and
arching over, each frond a midrib with leaflets either side, widest a third of the way out, its tip drooping; fresh
green on top, darker underneath and in the clump's heart, the leaflets in turn a shade lighter.

Stylised to the art direction (solid leaf shapes, not see-through cards): every frond is a comb of leaflet triangles,
their rising part drawn on both sides (the props' material culls back faces), a low rosette of arching fronds with a few
young ones standing up out of it, so you can't read through a bed to someone crouched in it (ferns hide a
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
FRONDS = 11
SEGS = 9            # steps along a frond's blade


def build() -> object:
    hs.reset()
    wk.paint_all()
    r = wk.rng(1000)
    b = hs.Builder("Fern", [])
    # eleven fronds out of the crown at the ground (photos: a clump of twenty or more), each a solid toothed blade:
    # the inner ones standing tall and arching over, the outer ones older, spreading low between them to the bed's
    # edge, overlapping so the clump is solid at a crouched body's height, as the game rules (a bed hides you)
    for k in range(FRONDS):
        ring = k % 3  # 0 inner, 1 middle, 2 outer
        heading = 2.0 * math.pi * k / FRONDS * 3.0 + ring * 0.7 + r.uniform(-0.15, 0.15)
        rise, droop = ((r.uniform(74.0, 82.0), r.uniform(170.0, 200.0)), (r.uniform(58.0, 66.0), r.uniform(130.0, 150.0)),
                       (r.uniform(38.0, 46.0), r.uniform(90.0, 110.0)))[ring]
        wk.blade_frond(b, Vector((math.cos(heading) * 0.05, math.sin(heading) * 0.05, 0.0)), heading,
                       math.radians(rise), r.uniform(1.25, 1.45), r.uniform(0.17, 0.2), SEGS, math.radians(droop), r,
                       ("Fern", "FernDark", "FernLight"))
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
