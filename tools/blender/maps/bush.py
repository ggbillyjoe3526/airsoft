"""Woodland's bush (WG2, model 11): assets/models/props/bush.glb, drawn for each of the map's 7 bushes (2.4 to 2.6 m
across, 1.7 m tall) by BushView.

From the owner's photos (references/maps/woodland/11-bush): a hazel-like woodland shrub, many stems from the ground
fanning out into a dome of leaf clumps, its outline lumpy and uneven, darker inside and underneath, lighter where the
sun catches its top; the young spruce and scrub in the other photos the same dense, rounded mass.

Stylised to the art direction (solid leaf clumps, Valorant-led with BOTW light, not see-through leaf cards): a dark
leafy mass covered in small jagged leaf clusters on a few bare stems, so a standing player hidden in one is hidden
(BBs pass straight through, Foliage, and the model has no collider). Fills the foliage's ellipsoid's box: 2 m across,
1.7 m tall, its ground line at y = 0; the game stretches it to each bush. Budget 1,500 triangles
(/mnt/project-files/art/woodland-model-list.md). Plain vertex colours, no texture.

    python -I tools/blender/maps/bush.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402
import woodkit as wk  # noqa: E402
import hardsurface as hs  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET = 1500
RADIUS, HEIGHT = 1.0, 1.7
CLUSTERS = 36
SKIRT = 11
STEMS = 4
LEAVES = 6          # leaf points round a spray
# the clumps: middle (x, y, z) and half size (m), in the 2 m wide, 1.7 m tall box
CLUMPS = (
    ((0.0, 0.0, 1.0), (0.66, 0.62, 0.6)),
    ((0.45, 0.25, 0.62), (0.52, 0.5, 0.5)),
    ((-0.48, 0.2, 0.5), (0.5, 0.52, 0.5)),
    ((0.15, -0.48, 0.58), (0.52, 0.48, 0.5)),
    ((-0.25, -0.35, 1.12), (0.45, 0.45, 0.44)),
    ((0.3, 0.45, 1.22), (0.4, 0.4, 0.38)),
)


def leaf_plate(b: hs.Builder, centre: Vector, normal: Vector, size: float, r, top_mat: str) -> None:
    """A spray of leaves: a flat star of LEAVES points round `centre`, facing `normal`, cupped a little (its middle
    raised, its tips drooping), lit on top and dark under."""
    side, up = wk.frame(normal)
    spin = r.uniform(0.0, 2.0 * math.pi)
    ring = []
    for i in range(LEAVES * 2):
        a = spin + math.pi * i / LEAVES
        reach = size * (r.uniform(0.9, 1.1) if i % 2 == 0 else r.uniform(0.55, 0.7))
        tip = centre + (side * math.cos(a) + up * math.sin(a)) * reach
        ring.append(tip - normal * (0.12 * size if i % 2 == 0 else 0.0))
    rim = wk.verts(b, ring)
    wk.fan(b, rim, centre + normal * size * 0.22, top_mat, normal)
    wk.fan(b, rim, centre - normal * size * 0.05, "LeafDark", -normal)


def build() -> object:
    hs.reset()
    wk.paint_all()
    r = wk.rng(1100)
    b = hs.Builder("Bush", [])
    # the dark mass inside, flat and dull: only glimpsed between the sprays
    for k, (at, size) in enumerate(CLUMPS[:3]):
        wk.blob(b, Vector(at), Vector(size) * 0.72, 2, r, lambda c, n: "NeedleDark", rough=0.6, seed=k * 3.1)
    # sprays of leaves over a dome, narrower toward its ragged top, each facing out and up to the light
    for placed in range(CLUSTERS):
        # spread evenly over the dome (a golden-angle spiral), jittered, so no side is bare
        zt = 1.0 - 1.45 * (placed + 0.5) / CLUSTERS
        a = placed * 2.39996 + r.uniform(-0.3, 0.3)
        ring = math.sqrt(max(0.0, 1.0 - zt * zt))
        d = Vector((math.cos(a) * ring, math.sin(a) * ring, zt + r.uniform(-0.08, 0.08))).normalized()
        taper = 1.0 - 0.3 * max(0.0, d.z)
        centre = Vector((d.x * 0.8 * taper, d.y * 0.8 * taper, 0.8 + d.z * 0.78)) * r.uniform(0.86, 1.04)
        centre.z = max(centre.z, 0.35)
        normal = (d + Vector((0.0, 0.0, 0.7))).normalized()
        v = normal.z + 0.35 * wk.lump(centre, 0.35, 3.0)
        mat = "LeafSun" if v > 0.9 else ("LeafLight" if v > 0.6 else "Leaf")
        leaf_plate(b, centre, normal, r.uniform(0.25, 0.33), r, mat)
    # the skirt: sprays low round the foot, so the leaves come down to the ground as in the photos
    for k in range(SKIRT):
        a = 2.0 * math.pi * k / SKIRT + r.uniform(-0.25, 0.25)
        reach = r.uniform(0.6, 0.78)
        d = Vector((math.cos(a), math.sin(a), 0.0))
        leaf_plate(b, Vector((d.x * reach, d.y * reach, r.uniform(0.15, 0.3))), (d + Vector((0, 0, 0.5))).normalized(),
                   r.uniform(0.26, 0.32), r, "Leaf" if k % 2 else "LeafDark")
    # the stems, fanning out of the ground into the leaves, seen only between the skirt's sprays
    for k in range(STEMS):
        a = 2.0 * math.pi * k / STEMS + r.uniform(-0.2, 0.2)
        lean = r.uniform(0.25, 0.45)
        base = Vector((math.cos(a) * 0.08, math.sin(a) * 0.08, -0.02))
        top = base + Vector((math.cos(a) * lean, math.sin(a) * lean, 0.5))
        wk.branch(b, [tuple(base), tuple(base.lerp(top, 0.5) + Vector((0, 0, 0.03))), tuple(top)], 0.035, 0.018, 5,
                  "Twig", "Twig")
    ob = b.build()
    wk.finish(ob, 8.0)  # faceted, as the look's other leaves: no smooth, glossy ball
    wk.fit_box(ob, (-RADIUS, -RADIUS, -0.02), (RADIUS, RADIUS, HEIGHT))
    return ob


def main() -> None:
    ob = build()
    mk.report(ob, "bush", BUDGET)
    print("  wrote", mk.export_prop(ob, "bush"))


if __name__ == "__main__":
    main()
