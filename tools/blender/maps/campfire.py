"""Woodland's campfire (WG4, model 20), from the owner's photos (art/references/maps/woodland/20-campfire): a ring of
rounded field stones round a bed of ash, split logs leant together over it, their ends charred black, a few sticks
across. Look only: the fire is one of the map's lights (MapData.lights, kind "fire"), and LightFixtures stands this
model on the ground under it, with no collider.

`campfire.glb` is one mesh in three surfaces, by material:

- `Prop`: the stones, the logs and the ash, vertex-coloured like every prop;
- `Ember`: the glowing coals in the bed and on the logs' burnt ends; drawn dark by day, glowing by night;
- `Flame`: three crossed flame cards over the logs, white-yellow at the foot fading to black at the tips, drawn only at
  night, added to the light (so black is clear) and flickering (LightFixtures' flame shader).

The model's origin is the middle of the fire on the ground; about 1.1 m across, the flames 0.75 m high. Stones and
wood are dull colours, off the teams' hues (the embers and flames, which are fire, are their own surfaces).

    python3 -I tools/blender/maps/campfire.py <repo root>
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402
import weathering as wt  # noqa: E402
from mathutils import Vector  # noqa: E402

hs = mk.hs

RING_R = 0.48          # the stones' ring, to their middles
STONES = 9
LOGS = 5
FLAME_H = 0.75

STONE = 0x8A877F       # grey field stone, dull
STONE_DARK = 0x5C5A55  # soot on the stones' inner faces
LICHEN = 0x8E9473
ASH = 0x77736C         # pale grey ash
CHAR = 0x2C2A28        # charcoal, the burnt ends
WOOD = 0x8F8370        # split wood, weathered, dull
BARK = 0x4E4842
EMBER = 0xFF8A3A       # the coals' glow (its own surface: fire, not a prop colour)
EMBER_DARK = 0x3A2620
FLAME_FOOT = 0xFFB347
FLAME_MID = 0xE0561C


def _rock(b: hs.Builder, at: Vector, size: Vector, turn: float, rng: random.Random, mat: str) -> None:
    """A rounded field stone: a squashed, jittered ball (7 round by 5 up), its foot sunk into the ground."""
    rows, cols = 5, 7
    rings = []
    for i in range(1, rows):
        a = math.pi * i / rows - math.pi / 2
        ring = []
        for j in range(cols):
            t = 2 * math.pi * j / cols
            k = 1.0 + rng.uniform(-0.12, 0.12)
            lx, ly = math.cos(a) * math.cos(t) * size.x * k, math.cos(a) * math.sin(t) * size.y * k
            ring.append(Vector((lx * math.cos(turn) - ly * math.sin(turn), lx * math.sin(turn) + ly * math.cos(turn),
                                math.sin(a) * size.z * k)) + at)
        rings.append(ring)
    bm = b.bm
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    bottom = bm.verts.new(at + Vector((0, 0, -size.z)))
    top = bm.verts.new(at + Vector((0, 0, size.z * rng.uniform(0.85, 1.0))))
    faces = []
    for a, c in zip(vr, vr[1:]):
        for j in range(cols):
            faces.append(bm.faces.new((a[j], a[(j + 1) % cols], c[(j + 1) % cols], c[j])))
    for j in range(cols):
        faces.append(bm.faces.new((vr[-1][j], vr[-1][(j + 1) % cols], top)))
        faces.append(bm.faces.new((vr[0][(j + 1) % cols], vr[0][j], bottom)))
    import bmesh
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    m = b.mat(mat)
    for f in faces:
        f.material_index = m


def _log(b: hs.Builder, foot: Vector, head: Vector, r: float, sides: int, mats: tuple) -> None:
    """A split log from `foot` to `head`, `sides` sided, its bark faces and split faces alternating, its head charred."""
    axis = (head - foot).normalized()
    side = axis.cross(Vector((0, 0, 1)))
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side.normalize()
    up = side.cross(axis).normalized()
    rings = []
    for t in (0.0, 0.55, 1.0):
        c = foot + (head - foot) * t
        ring = []
        for j in range(sides):
            a = 2 * math.pi * j / sides
            ring.append(c + (side * math.cos(a) + up * math.sin(a)) * r * (0.92 if j % 2 else 1.0))
        rings.append(ring)
    faces = b.loft(rings, mats[0], cap0=True, cap1=True)
    # the head's third and its cap charred (the burnt end in the fire)
    for f in faces:
        c = f.calc_center_median()
        if (c - foot).dot(axis) > 0.55 * (head - foot).length - 1e-4:
            f.material_index = b.mat(mats[1])


def build() -> None:
    hs.reset()
    mk.paints({"stone": STONE, "ash": ASH, "wood": WOOD, "char": CHAR, "Ember": EMBER, "Flame": FLAME_FOOT})
    rng = random.Random(20)
    b = hs.Builder("campfire", ["stone", "ash", "wood", "char", "Ember", "Flame"])
    # the ring
    for i in range(STONES):
        t = 2 * math.pi * i / STONES + rng.uniform(-0.12, 0.12)
        r = RING_R + rng.uniform(-0.03, 0.04)
        size = Vector((rng.uniform(0.11, 0.15), rng.uniform(0.09, 0.12), rng.uniform(0.07, 0.1)))
        at = Vector((math.cos(t) * r, math.sin(t) * r, size.z * 0.55))
        # the stone's long side round the ring
        _rock(b, at, size, t + math.pi / 2 + rng.uniform(-0.3, 0.3), rng, "stone")
    # the bed of ash: a low mound, its middle the coals
    bed = [(0.0, 0.07), (0.16, 0.06), (0.3, 0.03), (0.4, 0.0)]
    b.lathe([(z, r) for r, z in bed], "ash", segments=10, axis="z")
    coals = [(0.0, 0.075), (0.13, 0.066)]
    b.lathe([(z + 0.002, r) for r, z in coals], "Ember", segments=10, axis="z")
    # the logs leant together over the middle, a tepee
    for i in range(LOGS):
        t = 2 * math.pi * i / LOGS + rng.uniform(-0.2, 0.2)
        foot = Vector((math.cos(t) * 0.36, math.sin(t) * 0.36, 0.05))
        head = Vector((math.cos(t + 0.5) * 0.05, math.sin(t + 0.5) * 0.05, rng.uniform(0.38, 0.48)))
        _log(b, foot, head, rng.uniform(0.04, 0.055), 5, ("wood", "char"))
    # two sticks across the ring
    _log(b, Vector((-0.42, -0.1, 0.13)), Vector((0.2, 0.18, 0.06)), 0.025, 4, ("wood", "char"))
    _log(b, Vector((0.35, -0.3, 0.1)), Vector((-0.1, 0.25, 0.2)), 0.022, 4, ("wood", "char"))
    # the flames: five crossed cards of tongues, the middle ones tallest, tapering to their tips
    for i in range(5):
        a = math.pi * i / 5 + 0.2
        d = Vector((math.cos(a), math.sin(a), 0.0))
        w = 0.24 if i % 2 == 0 else 0.17
        h = FLAME_H * (1.0 if i % 2 == 0 else 0.72) * rng.uniform(0.9, 1.1)
        off = Vector((rng.uniform(-0.04, 0.04), rng.uniform(-0.04, 0.04), 0.0))
        pts = [(-w, 0.05), (w, 0.05), (w * 0.8, h * 0.4), (w * 0.3, h * 0.73), (w * 0.05, h), (-w * 0.35, h * 0.66),
               (-w * 0.8, h * 0.37)]
        bm = b.bm
        vs = [bm.verts.new(d * x + off + Vector((0, 0, z))) for x, z in pts]
        f = bm.faces.new(vs)
        f.material_index = b.mat("Flame")
    ob = b.build()
    mk.clean(ob)
    mk.bake_vertex_colours(ob, keep=("Ember", "Flame"))
    stone, dark, lichen, ash, char, wood, bark = (mk.linear(c) for c in (STONE, STONE_DARK, LICHEN, ASH, CHAR, WOOD,
                                                                          BARK))
    ember, ember_dark, foot, mid = (mk.linear(c) for c in (EMBER, EMBER_DARK, FLAME_FOOT, FLAME_MID))
    names = [m.name for m in ob.data.materials]

    def paint(p: Vector, n: Vector, c: tuple, slot: int) -> tuple:
        r = math.hypot(p.x, p.y)
        if names[slot] == "Flame":
            t = p.z / FLAME_H
            col = wt.mix(foot, mid, wt.smooth(0.05, 0.45, t))
            return wt.scale(col, 1.0 - wt.smooth(0.35, 1.0, t))
        if names[slot] == "Ember":
            return wt.mix(ember, ember_dark, wt.smooth(0.03, 0.13, r) * 0.6 + 0.4 * wt.fbm(p, 0.05, 5))
        if r > RING_R - 0.2 and p.z < 0.25 and abs(c[0] - ash[0]) > 1e-3 and abs(c[0] - char[0]) > 1e-3 \
                and abs(c[0] - wood[0]) > 1e-3:
            # a stone: soot on the faces toward the fire, lichen on the outer tops
            inward = -(p.x * n.x + p.y * n.y) / max(r, 1e-4)
            col = wt.mix(stone, dark, max(0.0, inward) * 0.45)
            col = wt.mix(col, lichen, max(0.0, n.z) * wt.smooth(0.55, 0.8, wt.fbm(p, 0.08, 7)) * 0.7)
            return wt.mix(col, dark, 0.15 * wt.fbm(p, 0.05, 9))
        if abs(c[0] - ash[0]) < 1e-3:
            return wt.mix(ash, char, (1.0 - wt.smooth(0.08, 0.32, r)) * 0.7 + 0.2 * wt.fbm(p, 0.06, 11))
        if abs(c[0] - wood[0]) < 1e-3:
            # brown split wood and bark; only the heads in the fire are charred (their own colour)
            return wt.mix(wood, bark, wt.smooth(0.4, 0.6, wt.fbm(p, 0.05, 13)))
        return c

    wt.weather(ob, paint)
    mk.report(ob, "campfire", 800)
    wt.export(ob, "campfire")


build()
