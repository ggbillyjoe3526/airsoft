"""Shared helpers for Woodland's structures (WG3, Dev 3): the timber palette and the parts every structure is made of
(round logs with bark, sawn boards and beams), and the blocks of data/maps/woodland.json a structure's model fills.

A structure (the watch tower, the North bridge, the Sawmill's shed) is one model laid over every block that names it
(MapData.Block.dress, PropDressConfig's SET lay): the model fills the box round all of them, and each part of it fills
its own block, so what you see is what stops a BB and a body. The scripts read the blocks from the map file, so run
them again after tools/woodland/build_map.py moves one (tests/unit/test_wg3_woodland_models.gd fails a stale model).
Coordinates: `G(x, y, z)` turns the map's (x, y up, z) into Blender's (x, -z, y), less the model's origin (the middle
of the bottom of the box round its blocks), which the glTF export turns back.

Thin open timbers (knee braces, a stair's handrail, the posts holding the tower's roof) stand in the air between a
structure's blocks, inside the box round them and over head height or open: they hide nothing and stop nothing a
player would expect them to (docs/records/WG3.md).
"""

import json
import math
import os
import random

import mapkit as mk  # noqa: F401  first: it sets up bpy and the replica helpers
import hardsurface as hs  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

MAP = os.path.join(mk.ROOT, "data", "maps", "woodland.json")

# Woodland's timber (sRGB), all off the teams' hues: yellow-leaning or dull (tests/unit/test_props.gd). Weathered
# softwood goes silver-grey; sawn faces and fresh cuts are pale straw; bark a dull grey-brown.
TIMBER = {
    "Wood": 0x908468,       # weathered sawn softwood, a grey-brown
    "WoodLight": 0xa39878,
    "WoodDark": 0x7d735f,
    "WoodShade": 0x5d554a,  # timber in its own shade: the deck's underside, joists, grooves
    "Bark": 0x857a62,       # a peeled log, weathered
    "BarkLight": 0x998d70,
    "BarkDark": 0x6d6553,
    "Cut": 0xcdbb8f,        # fresh-cut ends and axe facets: pale straw
    "Damp": 0x524a40,       # wood wet from the ground
    "Steel": mk.PALETTE["steel"],
    "Galv": 0x9c9ca4,       # galvanised sheet, shoes and straps
    "Bolt": mk.PALETTE["grey"],
    "Concrete": mk.PALETTE["stone"],
    "Moss": 0x7f8650,
    # boards a shade either side of Wood: courses and planks that are told apart without reading as patches
    "WoodA": (0x908468, 1.05),
    "WoodB": (0x908468, 0.95),
}


def paints(extra: dict = None) -> None:
    names = dict(TIMBER)
    names.update(extra or {})
    mk.paints(names)


def blocks(dress: str) -> list:
    """The map's blocks that name `dress`, each as (kind, lo, hi, rise): lo and hi its corners in the map's axes."""
    with open(MAP) as f:
        data = json.load(f)
    out = []
    for b in data["blocks"]:
        if b.get("dress") != dress:
            continue
        c, s = b["center"], b["size"]
        lo = Vector((c["x"] - s["x"] / 2, c["y"] - s["y"] / 2, c["z"] - s["z"] / 2))
        hi = Vector((c["x"] + s["x"] / 2, c["y"] + s["y"] / 2, c["z"] + s["z"] / 2))
        out.append((b["kind"], lo, hi, b.get("rise", "")))
    assert out, "no block of %s's in %s" % (dress, MAP)
    return out


def bounds(parts: list) -> tuple:
    lo = Vector((min(p[1].x for p in parts), min(p[1].y for p in parts), min(p[1].z for p in parts)))
    hi = Vector((max(p[2].x for p in parts), max(p[2].y for p in parts), max(p[2].z for p in parts)))
    return lo, hi


class Frame:
    """The map's axes relative to a model's origin: `G` turns a map point into Blender's."""

    def __init__(self, lo: Vector, hi: Vector):
        self.lo, self.hi = lo, hi
        self.origin = Vector(((lo.x + hi.x) / 2, lo.y, (lo.z + hi.z) / 2))

    def G(self, x: float, y: float, z: float) -> tuple:
        return (x - self.origin.x, -(z - self.origin.z), y - self.origin.y)


def log(b: hs.Builder, f: Frame, a: tuple, c: tuple, r: float, mats: list, sides: int = 8, rings: int = 3,
        wobble: float = 0.06, rng: random.Random = None, caps: tuple = (True, True), cut: str = "Cut",
        taper: float = 0.0) -> None:
    """A round log from map point `a` to `c`, `r` in radius (less `taper` of it at `c`), its bark streaked a column
    at a time from `mats`, its middle rings nudged off round by `wobble` of r (no two logs alike) and its ends cut
    (`cut`, pale) where `caps` says."""
    rng = rng or random.Random(1)
    A, C = Vector(f.G(*a)), Vector(f.G(*c))
    axis = (C - A).normalized()
    side = axis.orthogonal().normalized()
    other = axis.cross(side)
    turn = rng.uniform(0.0, 2.0 * math.pi)
    ring_pts = []
    for k in range(rings + 1):
        t = k / rings
        rr = r * (1.0 - taper * t)
        mid = 0 < k < rings
        ring = []
        for i in range(sides):
            ang = turn + 2.0 * math.pi * i / sides
            rk = rr * (1.0 + (rng.uniform(-wobble, wobble) if mid else 0.0))
            ring.append(tuple(A.lerp(C, t) + (side * math.cos(ang) + other * math.sin(ang)) * rk))
        ring_pts.append(ring)
    bm = b.bm
    vr = [[bm.verts.new(Vector(p)) for p in ring] for ring in ring_pts]
    cols = [mats[rng.randrange(len(mats))] for _ in range(sides)]
    faces = []
    for k in range(rings):
        for i in range(sides):
            j = (i + 1) % sides
            fc = bm.faces.new((vr[k][i], vr[k][j], vr[k + 1][j], vr[k + 1][i]))
            fc.material_index = b.mat(cols[i])
            faces.append(fc)
    for end, keep in ((0, caps[0]), (rings, caps[1])):
        if keep:
            fc = bm.faces.new(vr[end] if end else list(reversed(vr[end])))
            fc.material_index = b.mat(cut)
            faces.append(fc)
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def board(b: hs.Builder, f: Frame, lo: tuple, hi: tuple, mat: str, faces: str = "xyzXYZ") -> list:
    """A sawn board or beam filling the map box `lo`..`hi` (map axes), only the faces named in `faces` drawn: x X its
    low and high x ends, y Y its bottom and top, z Z its low and high z sides (a board against another hides one)."""
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    P = {}
    for ix, x in enumerate((x0, x1)):
        for iy, y in enumerate((y0, y1)):
            for iz, z in enumerate((z0, z1)):
                P[(ix, iy, iz)] = f.G(x, y, z)
    quads = {
        "x": [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)],
        "X": [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)],
        "y": [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)],
        "Y": [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)],
        "z": [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)],
        "Z": [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)],
    }
    out = []
    bm = b.bm
    for key in faces:
        # G turns the map's axes without mirroring them, so each face keeps its winding (its front out)
        fc = bm.faces.new([bm.verts.new(Vector(P[k])) for k in quads[key]])
        fc.material_index = b.mat(mat)
        out.append(fc)
    return out


def beam(b: hs.Builder, f: Frame, a: tuple, c: tuple, w: float, d: float, mat: str, up: tuple = (0.0, 1.0, 0.0),
         caps: bool = True, chamfer: float = 0.0) -> list:
    """A sawn timber `w` wide and `d` deep (towards `up`, map axes) from map point `a` to `c`, its long edges
    chamfered `chamfer` m when given."""
    u = Vector(f.G(*up)) - Vector(f.G(0.0, 0.0, 0.0))
    if chamfer <= 0.0:
        return mk.beam(b, f.G(*a), f.G(*c), w, d, mat, up=tuple(u), caps=caps)
    A, C = Vector(f.G(*a)), Vector(f.G(*c))
    axis = (C - A).normalized()
    side = axis.cross(u)
    if side.length < 1e-6:
        side = axis.orthogonal()
    side.normalize()
    upv = side.cross(axis).normalized()
    hw, hd, k = w / 2, d / 2, chamfer
    ring = [(hw - k, -hd), (hw, -hd + k), (hw, hd - k), (hw - k, hd), (-hw + k, hd), (-hw, hd - k), (-hw, -hd + k),
            (-hw + k, -hd)]
    rings = [[tuple(end + side * x + upv * y) for x, y in ring] for end in (A, C)]
    return b.loft(rings, mat, cap0=caps, cap1=caps)


def quad(b: hs.Builder, f: Frame, pts: list, mat: str, facing: tuple = None) -> list:
    """A face through map points `pts`, its front by the right-hand rule in the map's axes, or turned to face
    `facing` (a map direction) when given."""
    bm = b.bm
    vs = [Vector(f.G(*p)) for p in pts]
    if facing is not None:
        n = (vs[1] - vs[0]).cross(vs[2] - vs[0])
        if n.length < 1e-12 and len(vs) > 3:
            n = (vs[2] - vs[0]).cross(vs[3] - vs[0])
        if n.dot(Vector(f.G(*facing)) - Vector(f.G(0.0, 0.0, 0.0))) < 0.0:
            vs.reverse()
    fc = bm.faces.new([bm.verts.new(v) for v in vs])
    fc.material_index = b.mat(mat)
    return [fc]


def export(ob, name: str, budget: int) -> None:
    mk.clean(ob)
    mk.report(ob, name, budget)
    mk.export_prop(ob, name)
