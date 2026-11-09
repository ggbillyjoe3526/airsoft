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
FRONDS = 9
PAIRS = 11
BARE = 2            # steps of bare stalk at a frond's foot
YOUNG = 2


def build() -> object:
    hs.reset()
    wk.paint_all()
    r = wk.rng(1000)
    b = hs.Builder("Fern", [])
    # the fronds, a shuttlecock out of a small crown: each a bare stalk rising steeply, then a strip of paired leaflets
    # arching out and over towards the ground (photos, middle): high enough that someone crouched in a bed is hidden,
    # as the game rules. Both sides drawn, in the same greens, so the clump has no dark cone at its foot.
    for k in range(FRONDS):
        heading = 2.0 * math.pi * k / FRONDS + r.uniform(-0.2, 0.2)
        wk.comb_frond(b, Vector((math.cos(heading) * 0.05, math.sin(heading) * 0.05, 0.0)), heading,
                      math.radians(r.uniform(60.0, 68.0)), r.uniform(1.3, 1.45), r.uniform(0.22, 0.26), PAIRS,
                      math.radians(r.uniform(130.0, 150.0)), r, ("Fern", "Fern", "FernLight"), under=1.0, bare=BARE)
    # young fronds standing up out of the middle, paler and narrow, their tips just curling over
    for k in range(YOUNG):
        heading = math.pi * k + 0.4 + r.uniform(-0.3, 0.3)
        wk.comb_frond(b, Vector((math.cos(heading) * 0.03, math.sin(heading) * 0.03, 0.0)), heading,
                      math.radians(r.uniform(84.0, 87.0)), r.uniform(1.0, 1.1), 0.11, 6, math.radians(60.0), r,
                      ("FernLight", "Fern", "FernLight"), under=0.0)
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
