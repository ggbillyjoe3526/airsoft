"""The wood beyond Woodland's fence (Dev 3, WT1): assets/models/props/forest_tree.glb, the cheap tree WoodsView stands
~1,800 times outside the field (WoodsConfig.forest_model), in place of the plain six-sided cone; and
assets/models/skyline/treeline.glb, a 20 m band of the dark spruces standing just past the fence (the skyline's
treelines, SkylineModels), in place of its rows of cones.

From the owner's photos (references/maps/woodland/22-far-tree-card-and-treeline): a far conifer wood reads as a
saw-toothed band of dark spires. So the far tree is a spruce's silhouette in three stacked, turned four-sided tiers
(each tier's skirt wider than the spire above it, so the outline steps like the photos' treetops) rather than a flat
card: solid from every side, no see-through, no back faces to light black. 12 triangles. Unit-sized like the cone it
replaces (radius 1 at its foot, 1 tall, its foot at its origin): the game scales each to its seeded size and paints
it in its instance colour (the forest's greens, faded toward the horizon), the vertex colours only its light, darker
low in each tier.

The treeline band: two staggered rows of spruces 2.4 m apart (the cones' spacing), seeded heights from 0.7 of the
band's to all of it, each five drooping tiers to the ground and a spire, so the band's top is the photos' saw-tooth
line and its foot a solid wall of branches. 20 m long, 5 m deep, 16 m tall (a treeline's height in the map file; the
game stretches it to each piece), painted as the skyline paints its models: every vertex the piece's colour times its
shade (vertex_paint.BODY). Budget 2,000 triangles.

    python -I tools/blender/maps/far_tree.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import treekit as tk  # noqa: E402  first: it sets up bpy
from mathutils import Vector  # noqa: E402

BUDGET = 12
# Each tier: its skirt's height (of the whole), its radius, the tip's height, its turn (degrees).
TIERS = ((0.0, 1.0, 0.62, 0.0), (0.3, 0.72, 0.86, 45.0), (0.55, 0.45, 1.0, 20.0))
# The forest's material reads its colours as sRGB (WoodsView), so these are written as sRGB values whose linear form is
# the multiplier wanted on the instance colour: 1 lit, 0.7 low in a tier.
LIGHT = (1.0, 1.0, 1.0)
SHADOW = (0.854, 0.854, 0.854)


def main() -> None:
    tree = tk.Tree("forest_tree", 2222)
    for foot, r, tip, turn in TIERS:
        top = Vector((0.0, tip, 0.0))
        top_id = tree.vert(top, LIGHT, Vector((0.0, 1.0, 0.0)))
        ids = []
        for k in range(4):
            a = math.radians(turn) + math.pi * 0.5 * k
            p = Vector((math.cos(a) * r, foot, math.sin(a) * r))
            ids.append(tree.vert(p, SHADOW, Vector((math.cos(a), 0.55, math.sin(a)))))
        inside = Vector((0.0, foot + (tip - foot) * 0.3, 0.0))
        for k in range(4):
            tree.face_out(inside, ids[k], ids[(k + 1) % 4], top_id)
    tree.export(BUDGET, 1.0)


BAND = (20.0, 5.0, 16.0)       # length, depth, height (m)
BAND_BUDGET = 2000
BAND_SPACING = 2.4
BAND_LOW = 0.7
BAND_WIDTH = 0.27              # a tree's radius, of its height (SkylineConfig.treeline_width)
BAND_LIT = (0.95, 0.95, 0.95)  # shades of the piece's colour (sRGB)
BAND_SHADE = (0.55, 0.55, 0.55)


def treeline() -> None:
    tree = tk.Tree("treeline", 1616)
    tree.alpha = 0.0
    rng = tree.rng
    length, depth, height = BAND
    n = round(length / BAND_SPACING)
    for row in (0, 1):
        z = depth * (0.25 if row == 0 else -0.25)
        for k in range(n):
            x = -length * 0.5 + (k + 0.25 + 0.5 * row) * length / n + rng.uniform(-0.3, 0.3)
            h = height * rng.uniform(BAND_LOW, 1.0)
            r = h * BAND_WIDTH
            centre = Vector((x, h * 0.45, z))
            tiers = 5
            for t in range(tiers):
                f = t / tiers
                foot = 0.4 + (h - 2.2) * f
                tr = r * (1.0 - f) ** 0.85
                at = len(tree.verts)
                tree.cone_tier(foot, tr, h * 0.28, 0.5 * (1.0 - f) + 0.15, 6 if t < tiers - 1 else 4, BAND_LIT,
                               BAND_SHADE, centre - Vector((x, 0, z)), yaw=rng.uniform(0.0, math.tau), lean=0.5,
                               notch=0.62)
                for i in range(at, len(tree.verts)):
                    tree.verts[i] += Vector((x, 0.0, z))
            at = len(tree.verts)
            tree.cone_tier(h - 1.6, r * 0.12, 1.6, 0.1, 3, BAND_LIT, BAND_SHADE, centre - Vector((x, 0, z)), yaw=0.4,
                           lean=0.4)
            for i in range(at, len(tree.verts)):
                tree.verts[i] += Vector((x, 0.0, z))
    # the band's own top at exactly its height (the tallest spire), so the game's stretch keeps the map's height
    top = max(v.y for v in tree.verts)
    for v in tree.verts:
        if v.y > 0.0:
            v.y *= height / top
    tree.export(BAND_BUDGET, 1.0, folder=os.path.join(tk.mk.ROOT, "assets", "models", "skyline"))


if __name__ == "__main__":
    main()
    treeline()
