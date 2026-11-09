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
LEAVES = 540        # small leaves over the outline
# the clumps: middle (x, y, z) and half size (m), in the 2 m wide, 1.7 m tall box
CLUMPS = (
    ((0.0, 0.0, 1.0), (0.66, 0.62, 0.6)),
    ((0.45, 0.25, 0.62), (0.52, 0.5, 0.5)),
    ((-0.48, 0.2, 0.5), (0.5, 0.52, 0.5)),
    ((0.15, -0.48, 0.58), (0.52, 0.48, 0.5)),
    ((-0.25, -0.35, 1.12), (0.45, 0.45, 0.44)),
    ((0.3, 0.45, 1.22), (0.4, 0.4, 0.38)),
)


def leaf(b: hs.Builder, centre: Vector, normal: Vector, size: float, r, mat: str) -> None:
    """One small leaf: a pointed diamond at `centre` facing `normal`, turned its own way and tipped down a little."""
    side, up = wk.frame(normal)
    a = r.uniform(0.0, 2.0 * math.pi)
    along = side * math.cos(a) + up * math.sin(a)
    across = normal.cross(along).normalized()
    pts = [centre - along * size * 0.5, centre + across * size * 0.22 + normal * size * 0.08,
           centre + along * size * 0.5 - normal * size * 0.1, centre - across * size * 0.22 + normal * size * 0.08]
    wk.face(b, wk.verts(b, pts), mat, normal)


def surface(d: Vector) -> Vector:
    """The bush's outline in direction `d` from its heart: a dome wider than tall, lumpy (clumps of shoots) and
    ragged at the top."""
    bump = 1.0 + 0.22 * wk.lump(d * 1.3, 0.45, 5.0) + 0.1 * wk.lump(d * 3.0, 0.45, 9.0)
    return Vector((d.x * 0.92, d.y * 0.92, 0.62 + d.z * 0.95)) * bump


def build() -> object:
    hs.reset()
    wk.paint_all()
    r = wk.rng(1100)
    b = hs.Builder("Bush", [])
    # the leafy mass under the leaves, the outline's own shape a little inside it, dark and faceted: what shows
    # between the leaves is the shade inside the bush, not a ball
    import bmesh
    tmp = bmesh.new()
    bmesh.ops.create_icosphere(tmp, subdivisions=3, radius=1.0)
    vmap = {v: b.bm.verts.new(surface(v.co.normalized()) * 0.9) for v in tmp.verts}
    for f in tmp.faces:
        vs = [vmap[v] for v in f.verts]
        c = sum((v.co for v in vs), Vector()) / 3.0
        wk.face(b, vs, "LeafDark" if c.z > 0.5 else "NeedleDark", c - Vector((0.0, 0.0, 0.62)))
    tmp.free()
    # small leaves all over the outline (a golden-angle spiral, jittered so it never reads as rows), each facing out,
    # sunlit on top and darker down the sides and under
    for k in range(LEAVES):
        zt = 1.0 - 1.5 * (k + 0.5) / LEAVES
        a = k * 2.39996 + r.uniform(-0.2, 0.2)
        ring = math.sqrt(max(0.0, 1.0 - zt * zt))
        d = Vector((math.cos(a) * ring, math.sin(a) * ring, zt)).normalized()
        at = surface(d) * r.uniform(0.95, 1.03)
        if at.z < 0.04:
            at.z = r.uniform(0.04, 0.2)
        normal = (d + Vector((0.0, 0.0, 0.5))).normalized()
        v = normal.z + 0.3 * wk.lump(at, 0.3, 3.0) + r.uniform(-0.15, 0.15)
        mat = "LeafSun" if v > 0.85 else ("LeafLight" if v > 0.6 else ("Leaf" if v > 0.3 else "LeafDark"))
        leaf(b, at, normal, r.uniform(0.13, 0.17), r, mat)
    # the stems, fanning out of the ground into the leaves, seen only low down between them
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
