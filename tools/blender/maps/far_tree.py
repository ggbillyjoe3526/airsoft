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

The treeline band: a 20 m section the game lays end to end along each treeline piece (SkylineModels), two staggered
rows of spruces 2.4 m apart (the cones' spacing), seeded heights from 0.7 of the band's to all of it, each the far
tree's three stepped tiers, so the band's top is the photos' saw-tooth line. 5 m deep, 16 m tall (a treeline's height
in the map file; the game stretches it to each piece), painted as the skyline paints its models: every vertex the
piece's colour times its shade (vertex_paint.BODY), each tree its own shade. Budget 2,000 triangles a band (the model
list: Woodland's four bands, up to 188 m), so 200 a section.

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


BAND = (20.0, 5.0, 16.0)       # length, depth, height (m) of one section
BAND_BUDGET = 200              # a section's: 2,000 a band (the model list), the game tiles sections along it
BAND_SPACING = 2.4
BAND_LOW = 0.7
BAND_WIDTH = 0.27              # a tree's radius, of its height (SkylineConfig.treeline_width)
BAND_SHADE = 0.95              # a tier's skirt, of its tip's light (FT1: High's screen-space light darkens the far
#                                side already; at 0.58 the faces seen from the fence read black)
# Each tree's tiers as the far tree's (skirt height and radius of the tree's, the tip's height), stretched a little
# each tree so no two spires match.
BAND_TIERS = ((0.0, 1.0, 0.5), (0.3, 0.74, 0.78), (0.56, 0.46, 1.0))


def treeline() -> None:
    """A section of the band: two staggered rows of spruces, each three stacked, turned four-sided tiers (the far
    tree's saw-tooth outline), every vertex the piece's colour times its shade (BODY), each tree its own shade so the
    band reads as trees, not a wall."""
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
            lit = rng.uniform(0.78, 1.0)
            for t, (foot, tr, tip) in enumerate(BAND_TIERS):
                foot *= h * rng.uniform(0.95, 1.05)
                tip *= h if t == len(BAND_TIERS) - 1 else h * rng.uniform(0.95, 1.05)
                rad = r * tr * rng.uniform(0.9, 1.1)
                top = Vector((x, tip, z))
                top_id = tree.vert(top, (lit, lit, lit), Vector((0.0, 1.0, 0.0)))
                turn = rng.uniform(0.0, math.pi * 0.5)
                ids = []
                for c in range(4):
                    a = turn + math.pi * 0.5 * c
                    p = Vector((x + math.cos(a) * rad, foot, z + math.sin(a) * rad))
                    dark = lit * BAND_SHADE
                    ids.append(tree.vert(p, (dark, dark, dark), Vector((math.cos(a), 0.55, math.sin(a)))))
                inside = Vector((x, foot + (tip - foot) * 0.3, z))
                for c in range(4):
                    tree.face_out(inside, ids[c], ids[(c + 1) % 4], top_id)
    # the section's own top at exactly its height (the tallest spire), so the game's stretch keeps the map's height
    top = max(v.y for v in tree.verts)
    for v in tree.verts:
        if v.y > 0.0:
            v.y *= height / top
    tree.export(BAND_BUDGET, 1.0, folder=os.path.join(tk.mk.ROOT, "assets", "models", "skyline"))


if __name__ == "__main__":
    main()
    treeline()
