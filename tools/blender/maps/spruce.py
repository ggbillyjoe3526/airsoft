"""Woodland's thicket spruce (Dev 3, WT1): assets/models/props/spruce.glb, the ~2,200 of the spruce thickets, one a
1.5 m cell (PropDressConfig.Lay.GRID, the cells the Kenney pine filled).

From the owner's photos (references/maps/woodland/03-spruce): a Norway / blue spruce. A narrow, dense cone with
branches all the way to the ground, each tier a ragged skirt whose tips droop under it, the tiers overlapping so no
light comes through, a thin spire at the top; dark blue-green, lighter on the tips that catch the sun.

A thicket stops BBs and sight, so the spruce is solid: every tier closed underneath, its cone overlapping the next
(and the thicket's dark core box still stands behind them, PropDressConfig.model_cores). Fills its cell exactly: the
lowest tier's tips are its width, its spire its top. Budget 500 triangles (docs/ASSETS.md): there are about 2,200.
Plain vertex colours, no texture.

    python -I tools/blender/maps/spruce.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import treekit as tk  # noqa: E402  first: it sets up bpy
from mathutils import Vector  # noqa: E402

P = tk.PALETTE

HEIGHT = 5.0
RADIUS = 0.75
BUDGET = 500
TIERS = 17

TOP = tk.mix(tk.srgb(P["spruce"], 1.12), tk.srgb(P["sage"]), 0.18)
UNDER = tk.srgb(P["forest"], 0.55)
STEM = tk.srgb(P["umber"], 0.7)


def main() -> None:
    tree = tk.Tree("spruce", 3131)
    rng = tree.rng
    tree.limb([Vector((0.0, -tk.SINK, 0.0)), Vector((0.0, 0.5, 0.0))], [0.07, 0.06], 5, lambda t, a: STEM,
              cap=False)
    centre = Vector((0.0, HEIGHT * 0.4, 0.0))
    spire = HEIGHT - 0.35
    for k in range(TIERS):
        t = k / (TIERS - 1)
        foot = 0.22 + (spire - 0.9) * t ** 0.95
        r = RADIUS * (1.0 - t) ** 0.7 * (1.0 + 0.04 * math.sin(t * 9.0))  # full to the thicket's core
        r = max(r, 0.16)
        height = 0.95 - 0.35 * t
        droop = 0.24 * (1.0 - t) + 0.05
        points = 7 if k < TIERS - 3 else 5
        tree.cone_tier(foot, r, height, droop, points, TOP, UNDER, centre, yaw=rng.uniform(0.0, math.tau),
                       lean=0.55, notch=0.6 + 0.1 * t)
    # the spire
    tree.cone_tier(HEIGHT - 0.6, 0.1, 0.6, 0.05, 3, TOP, UNDER, centre, yaw=0.3, lean=0.4, notch=0.7)
    fit(tree)
    tree.export(BUDGET, RADIUS)


def fit(tree: tk.Tree) -> None:
    """Stretches the spruce so its widest tips are RADIUS across each way and its spire HEIGHT high (its cell)."""
    hx = max(abs(v.x) for v in tree.verts)
    hz = max(abs(v.z) for v in tree.verts)
    hy = max(v.y for v in tree.verts)
    for v in tree.verts:
        v.x *= RADIUS / hx
        v.z *= RADIUS / hz
        if v.y > 0.0:
            v.y *= HEIGHT / hy


if __name__ == "__main__":
    main()
