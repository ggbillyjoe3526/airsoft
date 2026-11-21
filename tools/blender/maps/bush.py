"""Woodland's bush (WG2, model 11): assets/models/props/bush.glb, drawn for each of the map's 7 bushes (2.4 to 2.6 m
across, 1.7 m tall) by BushView.

From the owner's photos (references/maps/woodland/11-bush): a hazel-like woodland shrub, many stems from the ground
fanning out into a dome of leaf clumps, its outline lumpy and uneven, darker inside and underneath, lighter where the
sun catches its top; the young spruce and scrub in the other photos the same dense, rounded mass.

Eleven sprays of leaf clumps fanning out of a dark heart on a few bare stems, their tips drooping, the outline broken
between them; each clump a dark core of the leaf sheet's leaf mass under sprays of hazel leaves cut out of the sheet
(WQ1), so a standing player hidden in one is hidden
(BBs pass straight through, Foliage, and the model has no collider). Fills the foliage's ellipsoid's box: 2 m across,
1.7 m tall, its ground line at y = 0; the game stretches it to each bush. Budget 1,500 triangles
(/mnt/project-files/art/woodland-model-list.md); tools/bush_opacity.gd measures its leaves against
BallisticsConfig.leaf_bush_shares.

    python -I tools/blender/maps/bush.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import treekit as tk  # noqa: E402  first: it sets up bpy
from mathutils import Vector  # noqa: E402

BUDGET = 1500
RADIUS, HEIGHT = 1.0, 1.7
STEMS = 5
# the sprays of shoots the bush is made of (photos: a hazel's leafy sprays fanning out of the stems, gaps between
# them): direction from the heart (game axes, y up), clumps along it
SPRAYS = [Vector(v).normalized() for v in (
    (1.0, 0.35, 0.15), (0.45, 0.5, 0.9), (-0.55, 0.3, 0.8), (-1.0, 0.55, -0.1), (-0.4, 0.25, -0.95),
    (0.55, 0.6, -0.8), (0.2, 1.0, 0.25), (0.8, 0.05, -0.3), (-0.75, 0.0, 0.3), (0.1, -0.05, 0.85),
    (-0.3, 1.0, -0.5))]
ALONG = 4           # clumps along a spray
CORE = 7            # dark clumps filling the heart, so nobody is seen through it
HEART = Vector((0.0, 0.62, 0.0))
LEAF_SUN = tk.srgb(0x7BA84E)
LEAF = tk.srgb(0x467E3A)
LEAF_DARK = tk.srgb(0x2F5A2E)
TWIG = tk.srgb(0x5A554A)


def surface(d: Vector) -> Vector:
    """The bush's outline in direction `d` from its heart: a dome a little wider than tall, its middle 0.62 up."""
    bump = 1.0 + 0.12 * math.sin(d.x * 4.1 + d.z * 3.3 + d.y * 2.2)
    return HEART + Vector((d.x * 0.95, d.y * 0.95, d.z * 0.95)) * bump


def build() -> tk.Tree:
    tree = tk.Tree("bush", 1100)
    tree.leafy = tk.Leafy(["hazel"], "leaf_mass", card=1.4, card_min=0.3, card_max=0.5, per_m2=5.0, least=2,
                          most=4, core=0.92, core_dark=0.4, tilt=(0.3, 0.8))
    tree.bark_tile = 0.5
    r = tree.rng
    # the heart: big dark clumps, the shade inside the bush that shows between the sprays
    for k in range(CORE):
        a = 2.0 * math.pi * k / CORE + r.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), r.uniform(-0.3, 0.5), math.sin(a))).normalized()
        at = HEART + (surface(d) - HEART) * 0.4
        tree.blob(at, Vector((0.44, 0.37, 0.44)) * r.uniform(0.9, 1.1), tk.mix(LEAF, LEAF_DARK, 0.5), LEAF_DARK,
                  HEART, level=1, lean=0.6, rough=0.2, flat_under=0.8)
    # the sprays: clumps from the heart out past the outline, smaller and lighter towards their tips, which droop
    for d in SPRAYS:
        side = d.cross(Vector((0.0, 1.0, 0.0)))
        side = side.normalized() if side.length > 1e-6 else Vector((1.0, 0.0, 0.0))
        up = side.cross(d).normalized()
        for i in range(ALONG):
            t = 0.45 + 0.62 * i / (ALONG - 1)
            dd = (d + side * r.uniform(-0.15, 0.15) + up * r.uniform(-0.12, 0.12)
                  - Vector((0.0, 0.25 * max(0.0, t - 0.8), 0.0))).normalized()
            at = HEART + (surface(dd) - HEART) * t
            at.y = max(at.y, 0.12)
            size = Vector((0.29, 0.22, 0.29)) * (1.15 - 0.45 * (t - 0.45)) * r.uniform(0.85, 1.15)
            top = tk.mix(LEAF, LEAF_SUN, max(0.0, min(1.0, 0.5 + dd.y)))
            tree.blob(at, size, top, tk.mix(LEAF_DARK, LEAF, t * 0.6), HEART, level=1, lean=0.6, rough=0.25,
                      flat_under=0.8)
    # the stems, fanning out of the ground into the sprays, seen low down between them
    for k in range(STEMS):
        a = 2.0 * math.pi * k / STEMS + r.uniform(-0.2, 0.2)
        lean = r.uniform(0.3, 0.5)
        base = Vector((math.cos(a) * 0.08, -0.02, math.sin(a) * 0.08))
        top = base + Vector((math.cos(a) * lean, 0.55, math.sin(a) * lean))
        tree.limb([base, base.lerp(top, 0.5) + Vector((0.0, 0.03, 0.0)), top], [0.04, 0.03, 0.02], 4,
                  lambda t, aa: TWIG, cap=False)
    fit(tree)
    return tree


def fit(tree: tk.Tree) -> None:
    """Stretches the bush to the foliage's box: -RADIUS to RADIUS each way across, its ground line at -0.02 and its
    top HEIGHT (as woodkit.fit_box did)."""
    lo = [min(v[i] for v in tree.verts) for i in range(3)]
    hi = [max(v[i] for v in tree.verts) for i in range(3)]
    want = ((-RADIUS, RADIUS), (-0.02, HEIGHT), (-RADIUS, RADIUS))
    for v in tree.verts:
        for i in range(3):
            v[i] = want[i][0] + (v[i] - lo[i]) * (want[i][1] - want[i][0]) / (hi[i] - lo[i])


def main() -> None:
    build().export(BUDGET, RADIUS)


if __name__ == "__main__":
    main()
