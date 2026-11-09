"""Woodland's birch (Dev 3, WT1): assets/models/props/birch.glb, the ~50 of the Birch stand and Fern hollow (blocks of
kind tree whose `dress` is birch).

No photos for it (the owner's list, 09), so from general knowledge in the pines' style: a slim, slightly leaning
white stem with dark lenticel dashes and dark, rougher bark at its foot; thin branches climbing steeply from its
upper two thirds, their tips arching out; a light, open, tall-oval crown of small pads in a fresh green, the sky
showing through it, unlike the pines' dark clouds.

Fills its block's box exactly at the trunk (`FOOT_R` to the box's half-width, the top to the box's top,
PropDressConfig.Lay.TREE); the crown spreads past the box over head height, look only. Budget 2,000 triangles
(docs/ASSETS.md). Plain vertex colours, no texture.

    python -I tools/blender/maps/birch.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import treekit as tk  # noqa: E402  first: it sets up bpy
from mathutils import Vector  # noqa: E402

P = tk.PALETTE
UP = Vector((0.0, 1.0, 0.0))

HEIGHT = 12.0
FOOT_R = 0.17
BUDGET = 2000
CLEAR = 5.7    # 2.6 m over the ground at the smallest birch the map stands (5.5 m of 12): its crown starts half way up

WHITE = tk.srgb(P["cream"], 0.96)
DASH = tk.srgb(P["rubber"], 1.1)
FOOT = tk.srgb(P["rubber"], 1.35)
TWIG = tk.mix(tk.srgb(P["umber"]), tk.srgb(P["rubber"]), 0.4)
LEAF_TOP = tk.mix(tk.srgb(P["canopy"]), tk.srgb(P["butter"]), 0.3)
LEAF_UNDER = tk.srgb(P["green"], 0.7)


def bark_paint(rng):
    """White with dark dashes (a band of them every so often), dark and rough at the foot."""
    bands = [rng.uniform(0.08, 0.95) for _ in range(9)]

    def paint(t: float, a: float) -> tuple:
        if t < 0.07:
            return tk.mix(FOOT, WHITE, max(0.0, (t - 0.04) / 0.03))
        for b in bands:
            if abs(t - b) < 0.012 and rng.random() < 0.6:
                return DASH
        return WHITE if rng.random() > 0.08 else tk.mix(WHITE, DASH, 0.5)
    return paint


def main() -> None:
    tree = tk.Tree("birch", 9909)
    rng = tree.rng
    path = tk.curve(Vector((0.0, -tk.SINK, 0.0)), Vector((0.16, HEIGHT - 0.4, 0.06)), Vector((0.05, 0.0, 0.02)), 11)
    # a ring at the ground, the stem's full width, so its round collision hugs it there (not only under the ground)
    path.insert(1, Vector((0.0, 0.0, 0.0)))
    radii = [FOOT_R * (1.0 - 0.88 * max(0.0, p.y) / HEIGHT) for p in path]
    first = len(tree.verts)
    tree.limb(path, radii, 12, bark_paint(rng), ridges=0.02, cap=True, reach=FOOT_R)
    tree.mark_stem(first)
    centre = Vector((0.1, HEIGHT * 0.74, 0.04))
    spin = rng.uniform(0.0, math.tau)
    n = 13
    for k in range(n):
        t = k / (n - 1)
        y = HEIGHT * (0.5 + 0.42 * t)
        a = spin + k * 2.4
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        at = tk.along(path, (y + tk.SINK) / (HEIGHT - 0.4 + tk.SINK))
        ln = (2.3 - 1.4 * t) * rng.uniform(0.85, 1.15)
        end = at + out * ln + UP * ln * rng.uniform(0.7, 1.0)
        bp = tk.curve(at, end, out * 0.25 - UP * 0.15, 2)
        tree.limb(bp, [0.04, 0.03, 0.018], 3, lambda tt, aa: TWIG, cap=False)
        # small leafy tufts along it and at its arching tip
        size = 0.75 + 0.35 * (1.0 - t)
        tree.tuft(tk.along(bp, 0.62) + out * 0.1, size * 0.85, out, 2, LEAF_TOP, LEAF_UNDER, centre, flat=0.8,
                  lean=0.55)
        tree.tuft(bp[-1] + out * 0.1, size, out, 3, LEAF_TOP, LEAF_UNDER, centre, flat=0.8, lean=0.55)
    # tufts hanging round the stem through the crown, and the top's
    for k in range(10):
        t = k / 9
        y = HEIGHT * (0.55 + 0.36 * t)
        a = rng.uniform(0.0, math.tau)
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        at = tk.along(path, (y + tk.SINK) / (HEIGHT - 0.4 + tk.SINK)) + out * rng.uniform(0.5, 1.2) * (1.0 - 0.5 * t)
        tree.tuft(at, rng.uniform(0.7, 0.95), out, 1, LEAF_TOP, LEAF_UNDER, centre, flat=0.8, lean=0.55)
    tree.tuft(path[-1] + UP * -0.2, 0.8, Vector((1.0, 0.0, 0.0)), 2, LEAF_TOP, LEAF_UNDER, centre, flat=1.0,
              lean=0.55, spread=0.5)
    tree.export(BUDGET, FOOT_R, CLEAR, crown=True)


if __name__ == "__main__":
    main()
