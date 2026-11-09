"""Woodland's lanterns (WG4, model 21), from the owner's photos (art/references/maps/woodland/21-lantern): a hurricane
lantern, its fount a squat drum, a glass globe in a wire guard between two air tubes, a vented cap and a wire bail, its
paint a worn dark green with rust at the edges; no brand. Look only: each lantern is one of the map's lights
(MapData.lights, kind "lantern"), and LightFixtures hangs this model at the light, with no collider. Three models:

- `lantern.glb`: the lantern, its origin the middle of the globe (where the light hangs), its bail's top `BAIL` m over
  it. Surfaces: `Prop` (vertex-coloured), `Glow` (the globe: pale glass by day, lit by night) and `Flame` (the wick's
  flame, drawn only at night, added to the light);
- `lantern_post.glb`: a rough pole with a forged hook arm, for a lantern with nothing over it to hang from; its origin
  its foot on the ground, the hook's tip `HOOK` m out along +x and `HOOK_H` m up (LightFixtures stretches it up or
  down so the tip meets the bail);
- `lantern_chain.glb`: a metre of chain, its top at its origin (LightFixtures stretches it to hang a lantern under a roof
  or a beam).

Paint, steel, wood are dull colours, off the teams' hues (the glow and the flame are their own surfaces).

    python3 -I tools/blender/maps/lantern.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402
import weathering as wt  # noqa: E402
from mathutils import Vector  # noqa: E402

hs = mk.hs

SEG = 9
BAIL = 0.2          # the bail's top over the globe's middle
HOOK, HOOK_H = 0.42, 2.42

PAINT = 0x3F5A44    # worn dark green
PAINT_WORN = 0x5E6A58
RUST = 0x5E5146     # dull brown rust
STEEL = 0x55534F
GLASS = 0xD9D6C8    # the globe by day: pale, smoky
FLAME_FOOT = 0xFFE7A0
FLAME_TIP = 0xFF9A3C
POLE = 0x6E655A     # a weathered pole, dull
POLE_DARK = 0x4A443D
IRON = 0x3A3836


def _bar(b: hs.Builder, pts: list, r: float, mat: str, sides: int = 3) -> None:
    """A thin round bar along the points `pts`, `sides` sided."""
    rings = []
    for i, p in enumerate(pts):
        a = Vector(pts[max(0, i - 1)])
        c = Vector(pts[min(len(pts) - 1, i + 1)])
        axis = (c - a).normalized()
        side = axis.orthogonal().normalized()
        other = axis.cross(side)
        rings.append([tuple(Vector(p) + (side * math.cos(2 * math.pi * k / sides) + other * math.sin(2 * math.pi * k /
                                                                                                      sides)) * r)
                      for k in range(sides)])
    b.loft(rings, mat, cap0=False, cap1=False)


def lantern() -> None:
    hs.reset()
    mk.paints({"paint": PAINT, "steel": STEEL, "Glow": GLASS, "Flame": FLAME_FOOT})
    b = hs.Builder("lantern", ["paint", "steel", "Glow", "Flame"])
    g = -0.105   # the fount's top, under the globe
    # the fount: a squat drum with a rolled foot and a shoulder
    fount = [(g - 0.075, 0.0), (g - 0.075, 0.088), (g - 0.068, 0.094), (g - 0.03, 0.094), (g - 0.005, 0.07),
             (g, 0.045)]
    b.lathe(fount, "paint", segments=SEG, axis="z")
    # the globe: glass, fat in the middle
    globe = [(g, 0.045), (g + 0.03, 0.062), (0.0, 0.068), (0.05, 0.06), (0.095, 0.042)]
    b.lathe(globe, "Glow", segments=SEG, axis="z", cap=False)
    # the cap: a ring over the globe, a vented cone, a chimney top
    top = [(0.095, 0.05), (0.11, 0.068), (0.125, 0.064), (0.15, 0.04), (0.165, 0.022), (0.175, 0.0)]
    b.lathe(top, "paint", segments=SEG, axis="z")
    # the air tubes either side, from the fount up past the globe and in to the cap
    for s in (-1, 1):
        pts = [(s * 0.088, 0.0, g - 0.02), (s * 0.088, 0.0, 0.07), (s * 0.08, 0.0, 0.11), (s * 0.062, 0.0, 0.13)]
        _bar(b, pts, 0.009, "paint", sides=4)
    # the wire guard: two loops crossing over the globe
    for a in (0.6, -0.6):
        pts = []
        for k in range(5):
            t = -math.pi / 2 + math.pi * k / 4
            r = 0.074 - 0.012 * abs(math.sin(t))
            pts.append((math.cos(a) * r * math.cos(t), math.sin(a) * r * math.cos(t) * 0.25 + 0.0,
                        0.05 * math.sin(t) - 0.005))
        _bar(b, pts, 0.0028, "steel")
    # the bail: a wire hoop from the cap's sides over the top
    pts = []
    for k in range(7):
        t = math.pi * k / 6
        pts.append((0.075 * math.cos(t), 0.0, 0.13 + (BAIL - 0.13) * math.sin(t)))
    _bar(b, pts, 0.004, "steel")
    # the flame: two crossed cards on the wick
    for a in (0.0, math.pi / 2):
        d = Vector((math.cos(a), math.sin(a), 0.0))
        pts = [(-0.012, g + 0.005), (0.012, g + 0.005), (0.006, g + 0.04), (0.0, g + 0.075), (-0.006, g + 0.04)]
        vs = [b.bm.verts.new(d * x + Vector((0, 0, z))) for x, z in pts]
        f = b.bm.faces.new(vs)
        f.material_index = b.mat("Flame")
    ob = b.build()
    mk.clean(ob)
    mk.bake_vertex_colours(ob, keep=("Glow", "Flame"))
    paint, worn, rust, steel, glass, foot, tip = (mk.linear(c) for c in (PAINT, PAINT_WORN, RUST, STEEL, GLASS,
                                                                        FLAME_FOOT, FLAME_TIP))
    names = [m.name for m in ob.data.materials]

    def colour(p: Vector, n: Vector, c: tuple, slot: int) -> tuple:
        if names[slot] == "Flame":
            t = (p.z - g) / 0.075
            return wt.scale(wt.mix(foot, tip, t), 1.0 - wt.smooth(0.4, 1.0, t))
        if names[slot] == "Glow":
            # soot toward the top of the globe
            return wt.mix(glass, steel, wt.smooth(0.02, 0.09, p.z) * 0.55)
        if abs(c[0] - steel[0]) < 1e-3:
            return wt.mix(steel, rust, wt.fbm(p, 0.03, 3))
        col = wt.mix(paint, worn, 0.5 * wt.fbm(p, 0.04, 5))
        # rust where the paint wears through: the fount's foot and rim, the cap's edge
        edge = max(1.0 - wt.smooth(0.0, 0.02, p.z - (g - 0.075)), wt.smooth(0.6, 0.85, wt.fbm(p, 0.025, 7)))
        return wt.mix(col, rust, edge * 0.8)

    wt.weather(ob, colour)
    mk.report(ob, "lantern", 400)
    wt.export(ob, "lantern")


def post() -> None:
    hs.reset()
    mk.paints({"pole": POLE, "iron": IRON})
    b = hs.Builder("lantern_post", ["pole", "iron"])
    top = HOOK_H + 0.14
    # the pole: a rough round pole, a little bent, its foot sunk 0.3 m
    rings = []
    for z, dx in ((-0.3, 0.0), (0.0, 0.0), (1.0, 0.012), (2.0, -0.006), (top, 0.0)):
        r = 0.055 - 0.008 * max(0.0, z) / top
        rings.append([(dx + r * math.cos(2 * math.pi * k / 6), r * math.sin(2 * math.pi * k / 6), z) for k in range(6)])
    b.loft(rings, "pole", cap0=False, cap1=True)
    # the forged arm: out from near the top, its end curled down into the hook
    pts = [(0.03, 0.0, top - 0.06), (0.15, 0.0, top - 0.04), (0.3, 0.0, top - 0.03), (HOOK - 0.03, 0.0, top - 0.05),
           (HOOK, 0.0, top - 0.09), (HOOK - 0.005, 0.0, HOOK_H + 0.01), (HOOK - 0.03, 0.0, HOOK_H - 0.004)]
    _bar(b, pts, 0.008, "iron", sides=4)
    # its strap round the pole
    strap = [(0.056 * math.cos(2 * math.pi * k / 6), 0.056 * math.sin(2 * math.pi * k / 6), top - 0.07) for k in
             range(7)]
    _bar(b, strap, 0.006, "iron", sides=3)
    ob = b.build()
    mk.clean(ob)
    mk.bake_vertex_colours(ob)
    pole, dark, iron, rust = (mk.linear(c) for c in (POLE, POLE_DARK, IRON, RUST))

    def colour(p: Vector, n: Vector, c: tuple, slot: int) -> tuple:
        if abs(c[0] - iron[0]) < 1e-3:
            return wt.mix(iron, rust, 0.6 * wt.fbm(p, 0.05, 11))
        col = wt.mix(pole, dark, wt.fbm(Vector((p.x * 3, p.y * 3, p.z * 0.3)), 0.05, 13))
        return wt.mix(col, dark, 1.0 - wt.smooth(0.0, 0.35, p.z))

    wt.weather(ob, colour)
    mk.report(ob, "lantern_post", 160)
    wt.export(ob, "lantern_post")


def chain() -> None:
    hs.reset()
    mk.paints({"iron": IRON})
    b = hs.Builder("lantern_chain", ["iron"])
    # a thin square bar: at the lengths it hangs, the links read as its dark and pale shading
    _bar(b, [(0.0, 0.0, 0.0), (0.0, 0.0, -1.0)], 0.007, "iron", sides=4)
    ob = b.build()
    mk.clean(ob)
    mk.bake_vertex_colours(ob)
    mk.report(ob, "lantern_chain", 8)
    wt.export(ob, "lantern_chain")


lantern()
post()
chain()
