"""Woodland's tractor tyres (WG4, model 19), from the owner's photos (art/references/maps/woodland/19-tractor-tyre-stack):
big lugged tractor tyres without rims, lying flat in stacks. Two models, each a stack of the same tyre:

- `tractor_tyre.glb`: two tyres, 0.85 m high (a "tyre" block, 1.7 m across);
- `tractor_tyre_stack.glb`: four tyres, 1.7 m high (a "tyre_stack" block, 1.8 m across).

Each tyre is 1.7 m across, 0.425 m wide, with a row of thick slanted lugs either side of the tread meeting in a chevron, and
is turned and nudged a little on the one below, so a stack never reads as one solid. The model stands on the ground at
its origin (PropDressConfig.grounded): below it, a short skirt of the bottom tyre (`SKIRT`) runs into the ground, so a
stack on a slope never shows a gap under its low side. Rubber is near-black with faded, dusty tops and mud low down,
all dull colours, off the teams' hues.

    python3 -I tools/blender/maps/tyre.py <repo root>
"""

import math
import random
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402  (brings bpy, hardsurface)
import weathering as wt  # noqa: E402
from mathutils import Vector  # noqa: E402

hs = mk.hs

WIDTH = 0.425       # each tyre's height lying flat (m)
TREAD_R = 0.79      # the carcass's outer radius at the tread
LUG = 0.05          # how far the lugs stand off the tread
BEAD_R = 0.47       # the hole's radius
SEGMENTS = 10       # round the carcass
LUGS = 20           # a side
SKIRT = 0.25        # how far the bottom tyre runs on below the ground
NUDGE = 0.02        # how far a tyre may sit off the one below (m)

RUBBER = 0x2F2E30
WORN = 0x4B4949     # a faded, sun-dried sidewall
DUST = 0x77746F     # dust settled on top faces
MUD = 0x5E574D      # dried mud, dull


def _profile(w: float) -> list:
    """The carcass's section (radius, height), round from the hole's bottom edge: sidewalls bulging a little, the
    shoulders rounded."""
    return [(BEAD_R + 0.02, 0.035), (0.66, 0.0), (TREAD_R, 0.075), (TREAD_R, w - 0.075), (0.66, w),
            (BEAD_R + 0.02, w - 0.035)]


def _ring(prof: list, z0: float, turn: float, off: Vector) -> list:
    rings = []
    for k in range(SEGMENTS):
        a = turn + 2.0 * math.pi * k / SEGMENTS
        ca, sa = math.cos(a), math.sin(a)
        rings.append([(off.x + r * ca, off.y + r * sa, z0 + z) for r, z in prof])
    return rings


def _carcass(b: hs.Builder, z0: float, turn: float, off: Vector, skirt: bool) -> None:
    """The tyre's body: its section lofted round, closed into a ring."""
    prof = _profile(WIDTH)
    if skirt:
        # the bottom tyre's tread carries on straight down into the ground; its sidewall underneath is never seen
        prof = [(TREAD_R - 0.01, -SKIRT)] + prof[2:] + [(BEAD_R + 0.02, -SKIRT * 0.5)]
    rings = _ring(prof, z0, turn, off)
    bm = b.bm
    verts = [[bm.verts.new(Vector(p)) for p in ring] for ring in rings]
    n = len(prof)
    faces = []
    for k in range(SEGMENTS):
        a, c = verts[k], verts[(k + 1) % SEGMENTS]
        for i in range(n if not skirt else n - 1):
            j = (i + 1) % n
            faces.append(bm.faces.new((a[i], a[j], c[j], c[i])))
    import bmesh
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    i = b.mat("rubber")
    for f in faces:
        f.material_index = i


def _lugs(b: hs.Builder, z0: float, turn: float, off: Vector) -> None:
    """The lugs: thick bars from each shoulder slanting in to the middle of the tread, the two rows meeting there in a
    chevron (a V round the tread, as on the photos' tractor tyres); each a ridge LUG high, wide at its foot, its outer
    end down on the shoulder, so a stack's edges read toothed."""
    import bmesh
    w = WIDTH
    pitch = 2.0 * math.pi / LUGS
    wide = 0.13 / TREAD_R        # the lug's width round the tread at its foot (radians)
    sweep = 0.16 / TREAD_R       # how far round it runs from its outer end to the middle
    r_base, r_top = TREAD_R - 0.006, TREAD_R + LUG
    for side in (-1, 1):
        for k in range(LUGS):
            a_mid = turn + k * pitch
            z_out = (w - 0.03) if side > 0 else 0.03
            z_in = w * 0.5 - side * 0.012
            ends = []
            for (a, z, lift) in ((a_mid + sweep, z_out, 0.02), (a_mid, z_in, 0.0)):
                rb = r_base - lift
                ring = [(rb, a - wide * 0.5), (r_top, a), (rb, a + wide * 0.5)]
                ends.append([b.bm.verts.new(Vector((off.x + r * math.cos(t), off.y + r * math.sin(t), z0 + z)))
                             for r, t in ring])
            v0, v1 = ends
            faces = [b.bm.faces.new((v0[i], v0[i + 1], v1[i + 1], v1[i])) for i in range(2)]
            faces += [b.bm.faces.new(v0), b.bm.faces.new(list(reversed(v1)))]
            bmesh.ops.recalc_face_normals(b.bm, faces=faces)
            i = b.mat("rubber")
            for f in faces:
                f.material_index = i


def build(count: int, name: str, seed: int) -> None:
    hs.reset()
    mk.paints({"rubber": RUBBER})
    rng = random.Random(seed)
    b = hs.Builder(name, ["rubber"])
    shades = []
    for t in range(count):
        z0 = t * WIDTH
        turn = rng.uniform(0.0, 2.0 * math.pi)
        off = Vector((rng.uniform(-NUDGE, NUDGE), rng.uniform(-NUDGE, NUDGE), 0.0)) if t else Vector()
        _carcass(b, z0, turn, off, skirt=(t == 0))
        _lugs(b, z0, turn, off)
        shades.append((z0, rng.uniform(0.0, 1.0)))
    ob = b.build()
    mk.clean(ob)
    mk.bake_vertex_colours(ob)

    rubber, worn, dust, mud = (mk.linear(c) for c in (RUBBER, WORN, DUST, MUD))
    top = count * WIDTH

    def paint(p: Vector, n: Vector, c: tuple, slot: int) -> tuple:
        layer = min(count - 1, max(0, int(p.z / WIDTH)))
        fade = shades[layer][1]
        col = wt.mix(rubber, worn, 0.15 + 0.5 * fade * wt.fbm(p, 0.6, seed + layer))
        # dust where a face looks up: the top tyre's sidewall, the lugs' tops
        col = wt.mix(col, dust, max(0.0, n.z) ** 2 * (0.55 if p.z > top - 0.05 else 0.25) * wt.fbm(p, 0.35, seed + 7))
        # mud splashed up the bottom tyres, in blotches
        low = 1.0 - wt.smooth(0.0, 0.7, p.z)
        col = wt.mix(col, mud, low * wt.smooth(0.35, 0.65, wt.fbm(p, 0.25, seed + 3, 2)))
        # darker in the grooves: corners nearer the carcass than the lug tops
        r = math.hypot(p.x, p.y)
        if TREAD_R - 0.01 < r < TREAD_R + 0.01 and abs(n.z) < 0.5:
            col = wt.scale(col, 0.8)
        return col

    wt.weather(ob, paint)
    mk.report(ob, name, 750 * count // 2)
    wt.export(ob, name)


build(2, "tractor_tyre", 19)
build(4, "tractor_tyre_stack", 1904)
