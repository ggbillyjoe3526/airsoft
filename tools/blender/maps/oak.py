"""Woodland's oak (Dev 3, WT1): assets/models/props/oak.glb, the map's ~20 hand-placed hero trees (the Clearing's
two among them; blocks of kind tree whose `dress` is oak).

From the owner's photos (references/maps/woodland/02-oak): a field oak. A short, thick bole flaring into buttress
roots at the ground, splitting low into a few heavy, crooked limbs that reach out more than up, forking into
branches; over them a broad, lumpy dome of foliage, wider than it is tall, its underside fairly flat and its edge
built of rounded clumps (the photos' cauliflower outline), with gaps where the limbs show through.

Fills its block's box exactly at the trunk: the buttresses' widest reach (`FOOT_R`) is the box's half-width and its
top the box's top (PropDressConfig.Lay.TREE). The crown spreads past the box over head height, look only, its
underside kept over `CROWN_FLOOR` m so a standing player never walks into leaves. Budget 8,000 triangles
(docs/ASSETS.md). Plain vertex colours, no texture.

    python -I tools/blender/maps/oak.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import treekit as tk  # noqa: E402  first: it sets up bpy
from mathutils import Vector  # noqa: E402

P = tk.PALETTE
UP = Vector((0.0, 1.0, 0.0))

HEIGHT = 14.0
FOOT_R = 0.85            # the buttresses' widest reach: the box's half-width
BOLE_R = 0.55            # the bole's radius over the buttresses (they flare to 1.5 times it)
SPLIT = 3.45             # where the bole splits into its limbs (m)
CROWN = Vector((0.0, 8.6, 0.0))
CROWN_R = Vector((9.6, 5.8, 9.6))   # half again as wide as the tree is tall, as in the photos
CROWN_FLOOR = 3.7
CLEAR = 3.1              # 2.6 m over the ground at the smallest oak the map stands (12 m of 14)
BUDGET = 8000

BARK = tk.srgb(P["bark"])
BARK_DARK = tk.srgb(P["bark"], 0.62)
BARK_LIGHT = tk.mix(tk.srgb(P["bark"]), tk.srgb(P["stone"]), 0.6)
LEAF_TOP = tk.mix(tk.srgb(P["canopy"]), tk.srgb(P["butter"]), 0.12)
LEAF_MID = tk.srgb(P["green"])
LEAF_UNDER = tk.srgb(P["pine"], 0.62)


def bark_paint(rng):
    def paint(t: float, a: float) -> tuple:
        furrow = rng.random()
        base = tk.mix(BARK, BARK_LIGHT, 0.35 + 0.3 * math.sin(a * 3.0 + t * 7.0))
        return tk.mix(base, BARK_DARK, 0.7) if furrow < 0.35 else base
    return paint


def main() -> None:
    tree = tk.Tree("oak", 4404)
    rng = tree.rng
    bark = bark_paint(rng)
    # the bole: buttress roots at the foot, a slight twist, swelling where it splits
    bole = tk.curve(Vector((0.0, -tk.SINK, 0.0)), Vector((0.25, SPLIT + 0.4, -0.1)), Vector((0.08, 0.0, 0.05)), 7)
    radii = []
    for p in bole:
        h = max(0.0, p.y)
        r = BOLE_R * (1.0 - 0.1 * h / SPLIT)
        if h > SPLIT - 0.8:
            r *= 1.0 + 0.18 * (h - SPLIT + 0.8) / 1.2
        radii.append(r)
    first = len(tree.verts)
    tree.limb(bole, radii, 16, bark, ridges=0.03, lobes=4, lobe_depth=FOOT_R / BOLE_R - 1.0,
              lobe_until=0.32, cap=False, twist=0.5, reach=FOOT_R)
    tree.mark_stem(first)
    top = bole[-1]
    tips = []
    limbs = 5
    spin = rng.uniform(0.0, math.tau)
    for k in range(limbs):
        a = spin + math.tau * k / limbs + rng.uniform(-0.35, 0.35)
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        start = top + out * 0.18 + UP * rng.uniform(-0.3, 0.1)
        reach = rng.uniform(6.0, 7.2)
        rise = rng.uniform(2.8, 3.8)
        end = start + out * reach + UP * rise
        bend = out * 0.6 - UP * 0.7 + out.cross(UP) * rng.uniform(-0.6, 0.6)  # crooked: out first, then up
        path = tk.curve(start, end, bend, 5)
        tree.limb(path, [0.34 * (1.0 - 0.62 * i / 5) for i in range(6)], 9, bark, ridges=0.04, cap=False)
        # forks off its outer half, out toward the crown's edge
        forks = 3 if k % 2 == 0 else 2
        for f in range(forks):
            s = tk.along(path, 0.5 + 0.22 * f)
            side = out.cross(UP).normalized() * rng.choice((-1.0, 1.0))
            d = (out * rng.uniform(0.9, 1.3) + side * rng.uniform(0.3, 0.8) + UP * rng.uniform(0.25, 0.7))
            d.normalize()
            ln = rng.uniform(3.0, 4.4)
            e = s + d * ln
            fp = tk.curve(s, e, UP * 0.25, 3)
            tree.limb(fp, [0.13, 0.1, 0.07, 0.045], 6, bark, cap=True)
            tips.append(e)
        tips.append(end)
    # the crown: a clump at every branch's end, then the dome's surface filled out with clumps, then a few big inner
    # ones so the middle reads solid
    for e in tips:
        put(tree, e, rng.uniform(2.0, 2.6), rng)
    n_surface = 59
    golden = math.pi * (3.0 - math.sqrt(5.0))
    laid = 0
    i = 0
    while laid < n_surface:
        y = 1.0 - (i + 0.5) / (n_surface * 1.3) * 2.25     # the dome, down to its rim over head height
        i += 1
        rr = math.sqrt(max(0.0, 1.0 - y * y))
        a = golden * i
        d = Vector((math.cos(a) * rr, y, math.sin(a) * rr))
        p = CROWN + Vector((d.x * CROWN_R.x, d.y * CROWN_R.y, d.z * CROWN_R.z)) * rng.uniform(0.82, 0.95)
        put(tree, p, rng.uniform(2.1, 2.7) * (1.1 if y > 0.6 else 1.0), rng)
        laid += 1
    for c in (Vector((0.0, 9.6, 0.0)), Vector((2.6, 8.6, 1.2)), Vector((-2.4, 8.8, -1.6)), Vector((0.8, 8.4, -2.8)),
              Vector((-1.2, 8.3, 2.7)), Vector((3.0, 9.8, -1.8)), Vector((-3.1, 9.9, 1.0))):
        put(tree, Vector((c.x * 1.5, c.y * 1.2 - 2.0, c.z * 1.5)), 3.6, rng)
    tree.export(BUDGET, FOOT_R, CLEAR, crown=True)


def put(tree: tk.Tree, at: Vector, size: float, rng) -> None:
    """A rounded foliage clump `size` m across at `at`, its underside kept over CROWN_FLOOR."""
    # uneven across and flatter than tall, knobbly with a few bulges: leafy masses, not balls (owner, 2026-11-09)
    r = Vector((size * rng.uniform(0.9, 1.15), size * rng.uniform(0.62, 0.75), size * rng.uniform(0.9, 1.15))) * 0.62
    at = at.copy()
    at.y = max(at.y, CROWN_FLOOR + r.y * 0.6)
    top = at.y > CROWN.y + CROWN_R.y * 0.25
    tree.blob(at, r, LEAF_TOP if top else tk.mix(LEAF_TOP, LEAF_MID, 0.5), LEAF_UNDER, CROWN, level=2, lean=0.72,
              rough=0.22, flat_top=0.85, lumps=3, lump=0.45)


if __name__ == "__main__":
    main()
