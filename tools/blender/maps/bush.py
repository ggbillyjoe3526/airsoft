"""Woodland's bush (WG2, model 11): assets/models/props/bush.glb, drawn for each of the map's 7 bushes (2.4 to 2.6 m
across, 1.7 m tall) by BushView.

From the owner's photos (references/maps/woodland/11-bush): a hazel-like woodland shrub, many stems from the ground
fanning out into a dome of leaf clumps, its outline lumpy and uneven, darker inside and underneath, lighter where the
sun catches its top; the young spruce and scrub in the other photos the same dense, rounded mass.

Stylised to the art direction (solid leaf clumps, Valorant-led with BOTW light, not see-through leaf cards): eleven
sprays of small ragged leaf clumps fanning out of a dark heart on a few bare stems, their tips drooping, the outline
broken between them, so a standing player hidden in one is hidden
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
STEMS = 5
# the sprays of shoots the bush is made of (photos: a hazel's leafy sprays fanning out of the stems, gaps between
# them): direction from the heart, clumps along it
SPRAYS = [Vector(v).normalized() for v in (
    (1.0, 0.15, 0.35), (0.45, 0.9, 0.5), (-0.55, 0.8, 0.3), (-1.0, -0.1, 0.55), (-0.4, -0.95, 0.25),
    (0.55, -0.8, 0.6), (0.2, 0.25, 1.0), (0.8, -0.3, 0.05), (-0.75, 0.3, 0.0), (0.1, 0.85, -0.05),
    (-0.3, -0.5, 1.0))]
ALONG = 4           # clumps along a spray
TUFT = 7            # leaves standing out of each of a spray's two outer clumps
CORE = 8            # dark clumps filling the heart, so nobody is seen through it


def leaf(b: hs.Builder, root: Vector, out: Vector, length: float, r, mat: str) -> None:
    """One leaf rooted at `root` (inside a clump) reaching `length` out along `out`, drooping at its tip, its face
    turned up to the light: a pointed diamond."""
    side = out.cross(Vector((0.0, 0.0, 1.0)))
    side = side.normalized() if side.length > 1e-6 else Vector((1.0, 0.0, 0.0))
    side = (side + out * r.uniform(-0.2, 0.2)).normalized()
    tip = root + out * length - Vector((0.0, 0.0, length * 0.25))
    mid = root.lerp(tip, 0.45)
    w = length * 0.22
    normal = side.cross(tip - root).normalized()
    if normal.z < 0.0:
        normal = -normal
    wk.face(b, wk.verts(b, [root, mid + side * w, tip, mid - side * w]), mat, normal)


def surface(d: Vector) -> Vector:
    """The bush's outline in direction `d` from its heart: a dome a little wider than tall, its middle 0.62 up."""
    bump = 1.0 + 0.12 * wk.lump(d * 1.3, 0.45, 5.0)
    return Vector((d.x * 0.95, d.y * 0.95, 0.62 + d.z * 0.95)) * bump


def shade(heart: float):
    """A clump's face colours: sunlit on top, darker down its sides and under, darkest in the bush's heart (`heart`
    0 at the outline, 1 in the middle)."""
    def pick(c: Vector, n: Vector) -> str:
        v = 0.5 * n.z + 0.2 - 0.7 * heart + 0.25 * wk.lump(c, 0.25, 3.0)
        return "LeafSun" if v > 0.72 else ("LeafLight" if v > 0.3 else ("Leaf" if v > 0.0 else "LeafDark"))
    return pick


def build() -> object:
    hs.reset()
    wk.paint_all()
    r = wk.rng(1100)
    b = hs.Builder("Bush", [])
    heart = Vector((0.0, 0.0, 0.62))
    # the heart: big dark clumps, the shade inside the bush that shows between the sprays
    for k in range(CORE):
        a = 2.0 * math.pi * k / CORE + r.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), r.uniform(-0.3, 0.5))).normalized()
        at = heart + (surface(d) - heart) * 0.4
        wk.blob(b, at, Vector((0.38, 0.38, 0.32)) * r.uniform(0.9, 1.1), 1, r, shade(0.9), 0.3, k * 3.1,
                flat_base=0.02)
    # the sprays: clumps from the heart out past the outline, smaller and lighter towards their tips, which droop
    for j, d in enumerate(SPRAYS):
        side, up = wk.frame(d)
        for i in range(ALONG):
            t = 0.45 + 0.62 * i / (ALONG - 1)
            dd = (d + side * r.uniform(-0.15, 0.15) + up * r.uniform(-0.12, 0.12)
                  - Vector((0.0, 0.0, 0.25 * max(0.0, t - 0.8)))).normalized()
            at = heart + (surface(dd) - heart) * t
            at.z = max(at.z, 0.12)
            size = Vector((0.29, 0.29, 0.22)) * (1.15 - 0.45 * (t - 0.45)) * r.uniform(0.85, 1.15)
            wk.blob(b, at, size, 1, r, shade(max(0.0, 0.9 - t)), 0.5, j * 5.7 + i, flat_base=0.02)
            if i < ALONG - 2:
                continue
            # a tuft of leaves standing out of the clump's sunny side, each rooted in it, so its outline is leaves
            # rather than a faceted lump
            for q in range(TUFT):
                n = (dd + Vector((0.0, 0.0, 0.7)) + side * r.uniform(-1.0, 1.0) + up * r.uniform(-0.7, 0.7)).normalized()
                root = at + Vector((n.x * size.x, n.y * size.y, n.z * size.z)) * 0.75
                v = n.z + r.uniform(-0.25, 0.25)
                leaf(b, root, n, r.uniform(0.2, 0.26), r,
                     "LeafSun" if v > 0.8 else ("LeafLight" if v > 0.4 else "Leaf"))
    # the stems, fanning out of the ground into the sprays, seen low down between them
    for k in range(STEMS):
        a = 2.0 * math.pi * k / STEMS + r.uniform(-0.2, 0.2)
        lean = r.uniform(0.3, 0.5)
        base = Vector((math.cos(a) * 0.08, math.sin(a) * 0.08, -0.02))
        top = base + Vector((math.cos(a) * lean, math.sin(a) * lean, 0.55))
        wk.branch(b, [tuple(base), tuple(base.lerp(top, 0.5) + Vector((0, 0, 0.03))), tuple(top)], 0.04, 0.02, 5,
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
