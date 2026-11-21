"""Woodland's fern clump (WG2, model 10): assets/models/props/fern.glb, drawn for each of the map's 92 ferns (in 8
beds; 2 m across, 1.2 m tall) by BushView.

From the owner's photos (references/maps/woodland/10-fern-clump): a shuttlecock of fronds rising out of a crown and
arching over, each frond a midrib with leaflets either side, widest a third of the way out, its tip drooping; fresh
green on top, darker underneath and in the clump's heart, the leaflets in turn a shade lighter.

Each frond is a frond of the leaf sheet (WQ1: a stalk, then pinnae in pairs cut into pinnules, cut out of the card;
look_foliage.gdshader draws both sides) on a creased strip arching out of the crown: a few young fronds standing up
and arching over, the flanks at a crouch's height and old fronds spread low to the edge, so the clump is wide at its
foot and you can't read through a bed to someone crouched in it (ferns hide a crouched player; BBs pass straight
through, Foliage, and the model has no collider; tools/bush_opacity.gd measures its leaves against
BallisticsConfig.leaf_fern_shares; WQ1 widened and raised the fronds until it matched the old clump's). Fills the
foliage's ellipsoid's box: 2 m across, 1.2 m tall, its ground line at y = 0; the game stretches it to each fern.
Budget 400 triangles (/mnt/project-files/art/woodland-model-list.md).

    python -I tools/blender/maps/fern.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import treekit as tk  # noqa: E402  first: it sets up bpy
from mathutils import Vector  # noqa: E402

BUDGET = 400
RADIUS, HEIGHT = 1.0, 1.2
SEGS = 5            # a frond's strip, base to tip
RINGS = (
    # (fronds, rise °, droop °, length m, width m)
    (4, (62.0, 70.0), (125.0, 150.0), (1.3, 1.45), (0.8, 0.9)),   # young fronds standing up and arching over
    (8, (48.0, 58.0), (95.0, 115.0), (1.2, 1.35), (0.86, 0.96)),  # the clump's flanks, at a crouch's height
    (8, (20.0, 28.0), (45.0, 60.0), (1.0, 1.15), (0.86, 0.96)),   # old fronds spread low to the bed's edge
)
CREASE = 0.12       # how far a frond's sides fall from its rib (a share of its width): a shallow V, not a flat card
COLOURS = {"fern": tk.srgb(0x6A9A48), "light": tk.srgb(0x84B054), "dark": tk.srgb(0x4A7438)}


def frond(tree: tk.Tree, base: Vector, heading: float, rise: float, length: float, width: float, droop: float,
          centre: Vector, cell: str) -> None:
    """A frond from `base` along `heading` (radians about up), rising at `rise` and drooping `droop` toward its tip:
    a strip of SEGS sections, its rib along the middle of the sheet's frond and its sides fallen CREASE, the stalk's
    end dark in the crown and the tip lit."""
    h = Vector((math.cos(heading), 0.0, math.sin(heading)))
    side = h.cross(Vector((0.0, 1.0, 0.0))).normalized()
    p = Vector(base)
    angle = rise
    rows = []
    for k in range(SEGS + 1):
        t = k / SEGS
        d = h * math.cos(angle) + Vector((0.0, math.sin(angle), 0.0))
        up = side.cross(d).normalized()
        if up.y < 0.0:
            up = -up
        col = tk.mix(tk.mix(COLOURS["dark"], COLOURS["fern"], min(1.0, t * 2.5)), COLOURS["light"], max(0.0, t - 0.5))
        row = []
        for u, s in ((0.0, -1.0), (0.5, 0.0), (1.0, 1.0)):
            q = p + side * s * width * 0.5 - up * abs(s) * width * CREASE
            row.append(tree.vert(q, tk.mix(col, COLOURS["dark"], 0.15 * abs(s)),
                                 tk.crown_normal(q, up, centre, 0.35), tk.cell_uv(cell, u, 1.0 - t)))
        rows.append(row)
        p = p + d * (length / SEGS)
        angle -= droop / SEGS
    for k in range(SEGS):
        a, b = rows[k], rows[k + 1]
        tree.faces.append((a[0], a[1], b[1], b[0]))
        tree.faces.append((a[1], a[2], b[2], b[1]))


def build() -> tk.Tree:
    tree = tk.Tree("fern", 1000)
    tree.leafy = tk.Leafy(["fern_a", "fern_b"], "leaf_mass")
    r = tree.rng
    centre = Vector((0.0, 0.35, 0.0))
    # eighteen fronds out of a crown at the ground (photos: a shuttlecock of twenty or more): a few young ones
    # standing up and arching over, the flanks at a crouched body's height, the old ones spread low out to the bed's
    # edge, so the clump is wide at its foot and solid at a crouch, as the game rules (a bed hides you)
    n = 0
    for count, rise, droop, length, width in RINGS:
        for k in range(count):
            heading = 2.0 * math.pi * (k + 0.5 * (n % 2)) / count + n * 0.45 + r.uniform(-0.2, 0.2)
            frond(tree, Vector((math.cos(heading) * 0.05, 0.06, math.sin(heading) * 0.05)), heading,
                  math.radians(r.uniform(*rise)), r.uniform(*length), r.uniform(*width),
                  math.radians(r.uniform(*droop)), centre, ("fern_a", "fern_b")[(k + n) % 2])
        n += 1
    fit(tree)
    return tree


def fit(tree: tk.Tree) -> None:
    """Stretches the clump to the foliage's box: -RADIUS to RADIUS each way across, its ground line at -0.02 and its top
    HEIGHT (as woodkit.fit_box did)."""
    lo = [min(v[i] for v in tree.verts) for i in range(3)]
    hi = [max(v[i] for v in tree.verts) for i in range(3)]
    want = ((-RADIUS, RADIUS), (-0.02, HEIGHT), (-RADIUS, RADIUS))
    for v in tree.verts:
        for i in range(3):
            v[i] = want[i][0] + (v[i] - lo[i]) * (want[i][1] - want[i][0]) / (hi[i] - lo[i])


def main() -> None:
    tree = build()
    tree.export(BUDGET, RADIUS)


if __name__ == "__main__":
    main()
