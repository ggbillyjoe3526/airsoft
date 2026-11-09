"""Shared helpers for Woodland's wood and plants (WG2): bark-covered logs with sawn, broken or rotten ends, split
cordwood, leaf clumps and fern fronds, all in plain faces painted from a palette (mapkit's vertex-colour bake).

Every helper draws into a hardsurface Builder in Blender's axes (+Z up, a log's length along X) and winds its faces
itself, outward, so nothing is left to a normals pass that can turn an open sheet or a round part inside out. Shapes
are seeded (random.Random) so a rebuild writes the same model.

Wood colours are dull (saturation under 0.3) or yellow enough to sit 20 degrees off Beta's orange; greens are well off
both teams (tests/unit/test_props.gd, test_bushes.gd).
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402  first: it sets up bpy and the replica helpers
import hardsurface as hs  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

# Woodland's wood and plant colours (sRGB): bark in two shades so its furrows read, the sawn face (pale), its heart
# (a ring darker), a split face, weathered grey wood, moss, earth, roots and the greens.
COLOURS = {
    "Bark": 0x5E5548, "BarkDark": 0x463F37, "BarkFurrow": 0x4F483E, "BarkGrey": 0x7A735C, "BarkLight": 0x7A7062,
    "Cut": 0xDCC07A, "Heart": 0xD0B46C, "Ring": 0xB4A062, "Split": 0xD6BA72, "Weathered": 0x9C9484,
    "Rot": 0x686152, "Moss": 0x71864A, "MossDeep": 0x5F7A3C, "Fungus": 0x8E866E, "FungusRim": 0xA89C80,
    "Earth": 0x4C443A, "EarthDark": 0x36302A, "Root": 0x6A6254, "RootLight": 0x8E826C, "Stone": 0x8C8478,
    "Litter": 0x7C7A58, "Sawdust": 0xDCCBA0, "Soil": 0x8A8070, "SoilDark": 0x6E665A,
    "Fern": 0x6A9A48, "FernDark": 0x4A7438, "FernLight": 0x84B054, "FernStem": 0x5E7A3A,
    "Leaf": 0x467E3A, "LeafDark": 0x2F5A2E, "LeafLight": 0x5E9442, "LeafSun": 0x7BA84E, "Twig": 0x5A554A,
    "Needle": 0x3E5E36, "NeedleDark": 0x2C452A,
}


# The teams' colours (Standard and High contrast, data/accessibility.md; sRGB) whose hues a saturated colour keeps 20
# degrees off.
TEAMS = (0x3B87F5, 0xFA8C29, 0x8CCFFF, 0xB8460C, 0xE0601A)
HUE_MARGIN = 20.0
DULL = 0.3


def hue_sat(colour: int) -> tuple:
    """sRGB `colour`'s hue (degrees) and HSL saturation, both of its linear value, as the tests measure them
    (tests/support/field_checks.gd)."""
    lin = [mk.srgb_to_linear(((colour >> s) & 255) / 255.0) for s in (16, 8, 0)]
    hi, lo = max(lin), min(lin)
    d = hi - lo
    if d <= 0.0:
        return 0.0, 0.0
    r_, g_, b_ = lin
    if hi == r_:
        hue = 60.0 * (((g_ - b_) / d) % 6.0)
    elif hi == g_:
        hue = 60.0 * ((b_ - r_) / d + 2.0)
    else:
        hue = 60.0 * ((r_ - g_) / d + 4.0)
    return hue, d / (1.0 - abs(hi + lo - 1.0))


def off_team(colour: int) -> bool:
    """Whether sRGB `colour` is dull (under DULL) or more than HUE_MARGIN off every team's hue."""
    hue, sat = hue_sat(colour)
    if sat < DULL - 0.02:  # a margin for the export's rounding
        return True
    return all(min(abs(hue - t), 360.0 - abs(hue - t)) > HUE_MARGIN + 0.5 for t in (hue_sat(c)[0] for c in TEAMS))


def paint_all() -> None:
    """Makes every colour above a material (mapkit.paints), each checked off the teams' hues first."""
    for name, colour in COLOURS.items():
        assert off_team(colour), "%s #%06x reads as a team" % (name, colour)
    mk.paints(dict(COLOURS))


def finish(ob: object, sharp_deg: float = 55.0) -> None:
    """Welds, smooths and keeps a hard edge only where faces meet sharper than `sharp_deg` (a log's round reads
    round; its sawn end stays crisp)."""
    import bmesh
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-7, edges=bm.edges)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(sharp_deg))


def rng(seed: int) -> random.Random:
    return random.Random(seed)


def lump(p: Vector, scale: float, seed: float = 0.0) -> float:
    """Smooth noise in -1..1 at `p` (m), features about `scale` m across."""
    return noise.noise(Vector((p.x / scale + seed, p.y / scale - seed * 0.7, p.z / scale + seed * 1.3)))


# ------------------------------------------------------------------------------------------------ faces, wound outward

def face(b: hs.Builder, verts: list, mat: str, outward: Vector = None) -> object:
    """One face through bmesh verts `verts`, turned to face `outward` when given (else as wound, right-hand rule)."""
    if outward is not None and len(verts) >= 3:
        n = (verts[1].co - verts[0].co).cross(verts[2].co - verts[0].co)
        if n.length > 1e-12 and n.dot(outward) < 0.0:
            verts = list(reversed(verts))
    f = b.bm.faces.new(verts)
    f.material_index = b.mat(mat)
    return f


def ring_band(b: hs.Builder, r0: list, r1: list, mats, centre0: Vector, centre1: Vector) -> list:
    """Quads between two closed rings of bmesh verts (same count), each facing away from the line centre0-centre1;
    `mats` a material name or a function of the side's index."""
    out = []
    n = len(r0)
    for i in range(n):
        j = (i + 1) % n
        mid = (r0[i].co + r0[j].co + r1[i].co + r1[j].co) * 0.25
        axis = centre1 - centre0
        t = 0.0 if axis.length < 1e-9 else max(0.0, min(1.0, (mid - centre0).dot(axis) / axis.length_squared))
        away = mid - (centre0 + axis * t)
        out.append(face(b, [r0[i], r0[j], r1[j], r1[i]], mats(i) if callable(mats) else mats, away))
    return out


def fan(b: hs.Builder, ring: list, tip: Vector, mats, outward: Vector) -> list:
    """Triangles from a closed ring of verts to one new vert at `tip`, facing `outward`."""
    c = b.bm.verts.new(tip)
    n = len(ring)
    return [face(b, [ring[i], ring[(i + 1) % n], c], mats(i) if callable(mats) else mats, outward) for i in range(n)]


def verts(b: hs.Builder, points: list) -> list:
    return [b.bm.verts.new(Vector(p)) for p in points]


def frame(axis: Vector) -> tuple:
    """Two unit vectors square to `axis` and each other, the first as level as it can be."""
    a = axis.normalized()
    side = a.cross(Vector((0.0, 0.0, 1.0)))
    if side.length < 1e-6:
        side = a.orthogonal()
    side.normalize()
    return side, side.cross(a).normalized()


# ----------------------------------------------------------------------------------------------------------- logs

def log(b: hs.Builder, path: list, radii: list, sides: int, r: random.Random, bark=("Bark", "BarkDark"),
        rough: float = 0.06, furrows: int = 0, ends=("cut", "cut"), moss: float = 0.0, seed: float = 0.0) -> dict:
    """A bark-covered log along `path` (points), `radii` at each point, `sides` round, its radius roughened by up to
    `rough` of itself (furrows: every other side pressed in when `furrows` > 0, so the bark reads as ridged). Each end
    is "cut" (a sawn face: bark rim, pale wood, darker heart), "sawn" (the same, plainer), "broken" (splinters
    standing out of a rotten hollow),
    "rot" (a soft hollow end) or "none" (open, buried or hidden). Faces facing up get moss where `moss` > 0 (a share
    of them, in noise patches). Returns the rings' verts and each ring's frame."""
    rings, frames = [], []
    n = len(path)
    for k in range(n):
        p = Vector(path[k])
        ahead = Vector(path[min(k + 1, n - 1)]) - Vector(path[max(k - 1, 0)])
        side, up = frame(ahead)
        ring = []
        for i in range(sides):
            t = 2.0 * math.pi * i / sides + k * 0.035  # the furrows spiral a little, as bark does
            d = side * math.cos(t) + up * math.sin(t)
            rr = radii[k] * (1.0 + rough * lump(p + d * radii[k], 0.35, seed))
            if furrows and i % 2:
                rr *= 1.0 - 0.09 * furrows
            ring.append(p + d * rr)
        rings.append(verts(b, ring))
        frames.append((p, side, up))

    def side_mat(k: int):
        def pick(i: int) -> str:
            mid = (rings[k][i].co + rings[k][(i + 1) % sides].co + rings[k + 1][i].co) / 3.0
            centre = (Vector(path[k]) + Vector(path[k + 1])) * 0.5
            facing = (mid - centre).normalized()
            # moss in a few broad soft patches along the top, one green, its edge following the noise; the bark in
            # furrows, each broken now and then along its length so they stagger rather than run as pinstripes (no
            # small patches of other shades: those read as a camouflage print)
            if moss > 0.0 and facing.z > 0.5 and lump(mid, 0.9, seed + 3.0) + 0.5 * facing.z > 1.45 - 2.0 * moss:
                return "MossDeep"
            return bark[1] if i % 2 and furrows and (k + 5 * i) % 7 < 5 else bark[0]
        return pick

    for k in range(n - 1):
        ring_band(b, rings[k], rings[k + 1], side_mat(k), Vector(path[k]), Vector(path[k + 1]))
    for which, k, step in ((ends[0], 0, -1), (ends[1], n - 1, 1)):
        p = Vector(path[k])
        out = (p - Vector(path[k - step])).normalized() if 0 <= k - step < n else Vector((step, 0, 0))
        end(b, rings[k], p, out, radii[k], which, r)
    return {"rings": rings, "frames": frames}


def end(b: hs.Builder, ring: list, centre: Vector, out: Vector, radius: float, kind: str, r: random.Random) -> None:
    """Closes a log's ring of verts (see `log`)."""
    if kind == "none":
        return
    if kind == "cut":
        rim = verts(b, [centre + (v.co - centre) * 0.88 + out * 0.004 for v in ring])
        ring_band_flat(b, ring, rim, "BarkDark", out)
        # growth rings: pale sapwood, a darker ring, pale again, then the heart round its pith
        prev = rim
        for share, mat in ((0.7, "Cut"), (0.6, "Ring"), (0.36, "Cut"), (0.28, "Ring")):
            nxt = verts(b, [centre + (v.co - centre) * share + out * 0.006 for v in ring])
            ring_band_flat(b, prev, nxt, mat, out)
            prev = nxt
        fan(b, prev, centre + out * 0.006, "Heart", out)
        return
    if kind == "sawn":  # a cheap sawn face: bark rim and pale wood, for small rounds
        rim = verts(b, [centre + (v.co - centre) * 0.84 + out * 0.003 for v in ring])
        ring_band_flat(b, ring, rim, "BarkDark", out)
        fan(b, rim, centre + out * 0.003, lambda i: "Cut" if i % 4 else "Heart", out)
        return
    if kind == "rot":
        rim = verts(b, [centre + (v.co - centre) * 0.8 + out * 0.01 for v in ring])
        ring_band_flat(b, ring, rim, "Weathered", out)
        fan(b, rim, centre - out * radius * 0.6, "Rot", out)
        return
    # broken: the rim's splinters stand out by different lengths, round a hollow of rotten wood
    tips = []
    for i, v in enumerate(ring):
        reach = radius * (0.2 + 1.4 * r.random() ** 2) if i % 2 == 0 else radius * 0.15 * r.random()
        tips.append(v.co + out * reach - (v.co - centre) * 0.25)
    tv = verts(b, tips)
    ring_band(b, ring, tv, lambda i: "Weathered" if i % 2 else "BarkGrey", centre - out, centre + out * radius * 2)
    inner = verts(b, [centre + (t - centre) * 0.45 for t in tips])
    ring_band_flat(b, tv, inner, "Split", out)
    fan(b, inner, centre - out * radius * 0.3, "Rot", out)


def ring_band_flat(b: hs.Builder, outer: list, inner: list, mat: str, out: Vector) -> None:
    """Quads between a ring and one inside it, all facing `out` (an end face in steps)."""
    n = len(outer)
    for i in range(n):
        j = (i + 1) % n
        face(b, [outer[i], outer[j], inner[j], inner[i]], mat, out)


def stub(b: hs.Builder, base: Vector, direction: Vector, length: float, radius: float, r: random.Random,
         sides: int = 5, mat: str = "Bark") -> None:
    """A snapped branch: a short tapering stick from `base` with a broken, splintered tip."""
    d = direction.normalized()
    side, up = frame(d)
    a = [base + (side * math.cos(2 * math.pi * i / sides) + up * math.sin(2 * math.pi * i / sides)) * radius
         for i in range(sides)]
    tipc = base + d * length
    c = [tipc + (side * math.cos(2 * math.pi * i / sides) + up * math.sin(2 * math.pi * i / sides)) * radius * 0.6
         + d * (r.random() - 0.5) * radius for i in range(sides)]
    va, vc = verts(b, a), verts(b, c)
    ring_band(b, va, vc, mat, base, tipc)
    fan(b, vc, tipc + d * radius * 0.5, "Weathered", d)


def branch(b: hs.Builder, points: list, r0: float, r1: float, sides: int = 5, mat: str = "BarkGrey",
           tip: str = "Weathered") -> None:
    """A thin bent branch through `points`, tapering from r0 to r1, its tip closed in a point."""
    n = len(points)
    rings = []
    for k, p in enumerate(points):
        p = Vector(p)
        ahead = Vector(points[min(k + 1, n - 1)]) - Vector(points[max(k - 1, 0)])
        side, up = frame(ahead)
        rad = r0 + (r1 - r0) * k / max(n - 1, 1)
        rings.append(verts(b, [p + (side * math.cos(2 * math.pi * i / sides) + up * math.sin(2 * math.pi * i / sides))
                               * rad for i in range(sides)]))
    for k in range(n - 1):
        ring_band(b, rings[k], rings[k + 1], mat, Vector(points[k]), Vector(points[k + 1]))
    last = Vector(points[-1])
    out = (last - Vector(points[-2])).normalized()
    fan(b, rings[-1], last + out * r1 * 2.0, tip, out)


def bracket(b: hs.Builder, at: Vector, out: Vector, width: float, r: random.Random) -> None:
    """A bracket fungus: a flat half disc standing out of a log's side at `at`, facing `out` (level)."""
    o = Vector((out.x, out.y, 0.0)).normalized()
    side = Vector((-o.y, o.x, 0.0))
    seg = 5
    top, bot, rim = [], [], []
    for i in range(seg + 1):
        t = math.pi * i / seg
        reach = width * (0.55 + 0.1 * r.random())
        p = at + side * math.cos(t) * width + o * math.sin(t) * reach
        top.append(p + Vector((0, 0, 0.03)))
        bot.append(p - Vector((0, 0, 0.01)))
    vt, vb = verts(b, top), verts(b, bot)
    root_t = b.bm.verts.new(at + Vector((0, 0, 0.045)))
    root_b = b.bm.verts.new(at - Vector((0, 0, 0.02)))
    for i in range(seg):
        face(b, [root_t, vt[i], vt[i + 1]], "Fungus", Vector((0, 0, 1)))
        face(b, [root_b, vb[i + 1], vb[i]], "FungusRim", Vector((0, 0, -1)))
        mid = (vt[i].co + vt[i + 1].co) * 0.5 - at
        face(b, [vt[i], vb[i], vb[i + 1], vt[i + 1]], "FungusRim", mid)


# ------------------------------------------------------------------------------------------------ cordwood pieces

def wedge_end(b: hs.Builder, outline: list, depth: float, out: Vector, mats: tuple, bark_edges: set) -> None:
    """A split piece's end standing `depth` proud of a stack's face: its end face (`outline`, points on the face plane,
    wound any way) in mats[0], and its short sides back to the face, the bark ones (`bark_edges`, edge indices) in
    mats[1], the split ones in mats[2]."""
    n = len(outline)
    front = verts(b, [Vector(p) + out * depth for p in outline])
    back = verts(b, [Vector(p) for p in outline])
    face(b, front, mats[0], out)
    c = sum((Vector(p) for p in outline), Vector()) / n
    for i in range(n):
        j = (i + 1) % n
        mid = (Vector(outline[i]) + Vector(outline[j])) * 0.5
        face(b, [back[i], back[j], front[j], front[i]], mats[1] if i in bark_edges else mats[2], mid - c)


def split_end(b: hs.Builder, outline: list, depth: float, out: Vector, end_mat: str, bark_edge: int,
              sides: bool) -> None:
    """A split piece's end standing `depth` proud of a stack's face (outline: points on the face plane): its sawn face
    in `end_mat` with a band of bark along edge `bark_edge` (a wedge's round side), and, with `sides`, its short sides
    back to the face (else the dark core behind reads as the shadow between pieces)."""
    n = len(outline)
    pts = [Vector(p) + out * depth for p in outline]
    c = sum(pts, Vector()) / n
    a, z = bark_edge, (bark_edge + 1) % n
    ia, iz = pts[a].lerp(c, 0.22), pts[z].lerp(c, 0.22)
    band = verts(b, [pts[a], pts[z], iz, ia])
    face(b, band, "BarkDark", out)
    inner = [iz if i == z else ia if i == a else pts[i] for i in range(n)]
    # the end face starts at the edge after the bark so its vertex order stays round the piece
    order = [(z + k) % n for k in range(n)]
    face(b, verts(b, [inner[i] for i in order]), end_mat, out)
    if sides:
        back = [Vector(p) for p in outline]
        for i in range(n):
            j = (i + 1) % n
            mid = (back[i] + back[j]) * 0.5
            face(b, verts(b, [back[i], back[j], pts[j], pts[i]]), "Bark" if i == a else "Split", mid - c + out * 0.0)


def ridge(b: hs.Builder, x: float, w: float, z: float, h: float, half_depth: float, mat: str) -> None:
    """A split piece lying across a stack's top: a low three-sided ridge `w` either side of `x`, `h` over `z`, running
    the stack's depth (its ends hidden in the pieces on the faces)."""
    a = verts(b, [(x - w, -half_depth, z), (x, -half_depth, z + h), (x + w, -half_depth, z)])
    c = verts(b, [(x - w, half_depth, z), (x, half_depth, z + h), (x + w, half_depth, z)])
    face(b, [a[0], a[1], c[1], c[0]], mat, Vector((-h, 0, w)))
    face(b, [a[1], a[2], c[2], c[1]], mat, Vector((h, 0, w)))


# ---------------------------------------------------------------------------------------------------------- leaves

def blob(b: hs.Builder, centre: Vector, size: Vector, subdiv: int, r: random.Random, mats, rough: float = 0.25,
         seed: float = 0.0, flat_base: float = None, square: float = 1.0) -> None:
    """A lumpy leaf clump: an icosphere `subdiv` times split, stretched to `size` (half extents), its surface pushed
    in and out by noise (up to `rough` of its size) so it reads as tufts of leaves, not a ball; `mats(face centre,
    face normal)` names each face's colour. With `flat_base`, nothing goes under that height; `square` under 1 pushes
    it towards a box (a root plate's slab)."""
    import bmesh
    tmp = bmesh.new()
    bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=1.0)
    for v in tmp.verts:
        d = v.co.normalized()
        if square != 1.0:
            d = Vector([math.copysign(abs(c) ** square, c) for c in d])
        bump = 1.0 + rough * (0.65 * lump(d * 1.0, 0.45, seed) + 0.35 * lump(d * 3.0, 0.45, seed + 7.0))
        v.co = Vector((d.x * size.x, d.y * size.y, d.z * size.z)) * bump + centre
        if flat_base is not None and v.co.z < flat_base:
            v.co.z = flat_base + (v.co.z - flat_base) * 0.1
    vmap = {v: b.bm.verts.new(v.co) for v in tmp.verts}
    for f in tmp.faces:
        vs = [vmap[v] for v in f.verts]
        c = sum((v.co for v in vs), Vector()) / len(vs)
        out = c - centre
        nf = face(b, vs, "Leaf", out)
        n = (vs[1].co - vs[0].co).cross(vs[2].co - vs[0].co)
        if n.dot(out) < 0:
            n = -n
        nf.material_index = b.mat(mats(c, n.normalized() if n.length > 0 else out.normalized()))
    tmp.free()


# How far in the frond's edge comes between two leaflets' tips (a share of the blade's width there).
NOTCH = 0.4


def frond(b: hs.Builder, base: Vector, heading: float, rise: float, length: float, width: float, segs: int,
          droop: float, r: random.Random, mats: tuple, twist: float = 0.0, under: float = 0.5) -> None:
    """A fern frond from `base`: its midrib arches out along `heading` (radians about up), rising at `rise` (radians)
    and drooping `droop` towards its tip; its blade a strip either side of the rib, widest a third of the way out,
    its edge toothed where the leaflets' tips stand out. Its top faces up; its under side is drawn too (the props'
    material culls back
    faces) for the first `under` share of it, the rising part you can see from outside the clump. mats = (top, under,
    the top's lighter leaflets)."""
    pts, ups, sides = [], [], []
    p = Vector(base)
    angle = rise
    h = Vector((math.cos(heading), math.sin(heading), 0.0))
    step = length / segs
    for k in range(segs + 1):
        pts.append(p.copy())
        d = h * math.cos(angle) + Vector((0, 0, math.sin(angle)))
        side = h.cross(Vector((0, 0, 1))).normalized()
        up = side.cross(d).normalized()
        roll = twist * k / segs
        side = (side * math.cos(roll) + up * math.sin(roll)).normalized()
        up = side.cross(d).normalized()
        if up.z < 0.0:
            up = -up
        ups.append(up)
        sides.append(side)
        p = p + d * step
        angle -= droop / segs
    lift = 0.004
    # the blade's edge each side: out to the leaflets' tips on even points, in between them on odd ones, so its
    # outline is toothed; drooping a little either side of the rib
    edges = []
    for k in range(segs + 1):
        t = k / segs
        w = width * math.sin(math.pi * min(1.0, 0.1 + t * 0.92)) * (1.0 if k % 2 == 0 else NOTCH)
        if k == segs:
            w = 0.0
        ahead = (pts[min(k + 1, segs)] - pts[max(k - 1, 0)]).normalized()
        edges.append([pts[k] + sides[k] * s * w + ahead * w * 0.35 - ups[k] * w * 0.28 for s in (1.0, -1.0)])
    for k in range(segs):
        t = (k + 0.5) / segs
        u = ups[k]
        # the leaflets in turn a shade lighter and darker, so the blade reads as rows of them
        top_mat = mats[2] if k % 2 == 0 else mats[0]
        for e in (0, 1):
            quad = [pts[k], edges[k][e], edges[k + 1][e], pts[k + 1]]
            face(b, verts(b, [q + u * lift for q in quad]), top_mat, u)
            if t < under:
                face(b, verts(b, [q - u * lift for q in quad]), mats[1], -u)

def comb_frond(b: hs.Builder, base: Vector, heading: float, rise: float, length: float, width: float, pairs: int,
               droop: float, r: random.Random, mats: tuple, under: float = 0.3, bare: int = 0) -> None:
    """A fern frond drawn as a comb: its midrib arches out from `base` along `heading` (radians about up), rising at
    `rise` and bending over more and more towards its tip, `droop` (radians) in all, with `pairs` leaflets either
    side, each a narrow triangle
    from the rib out and forward, widest a third of the way along and tapering to the tip, the notches between them
    reaching the rib, so the frond reads as rows of leaflets. Its top faces up; its under side is drawn too (the props'
    material culls back faces) for the first `under` share, the rising part you see from outside the clump. Its first
    `bare` steps are the stalk, a thin strip with no leaflets, so the clump springs from a small crown. mats = (top,
    under, the lighter leaflets in turn)."""
    pts, ups, sides = [], [], []
    p = Vector(base)
    angle = rise
    h = Vector((math.cos(heading), math.sin(heading), 0.0))
    step = length / pairs
    for k in range(pairs + 1):
        pts.append(p.copy())
        d = h * math.cos(angle) + Vector((0, 0, math.sin(angle)))
        side = h.cross(Vector((0, 0, 1))).normalized()
        up = side.cross(d).normalized()
        if up.z < 0.0:
            up = -up
        ups.append(up)
        sides.append(side)
        p = p + d * step
        angle = rise - droop * ((k + 1) / pairs) ** 1.8
    lift = 0.004
    for k in range(bare):
        a, c = pts[k], pts[k + 1]
        u = (ups[k] + ups[k + 1]).normalized()
        q = [a - sides[k] * 0.012, a + sides[k] * 0.012, c + sides[k] * 0.012, c - sides[k] * 0.012]
        face(b, verts(b, q), mats[1], u)
        face(b, verts(b, q), mats[1], -u)
    for k in range(bare, pairs):
        t = (k - bare + 0.5) / (pairs - bare)
        w = width * math.sin(math.pi * min(1.0, 0.3 + t * 0.74)) * r.uniform(0.9, 1.1)
        a, c = pts[k], pts[k + 1]
        ahead = (c - a).normalized()
        u = (ups[k] + ups[k + 1]).normalized()
        top_mat = mats[2] if k % 2 == 0 else mats[0]
        for s in (1.0, -1.0):
            # a leaflet joined to the rib along its whole step, its tip out to the side and a little forward
            tip = (a + c) * 0.5 + sides[k] * s * w + ahead * w * 0.2
            tri = [a, tip, c]
            face(b, verts(b, [q + u * lift for q in tri]), top_mat, u)
            if t < under:
                face(b, verts(b, [q - u * lift for q in tri]), mats[1], -u)


def fit_box(ob: object, lo: tuple, hi: tuple) -> None:
    """Stretches `ob`'s mesh (Blender axes) so its bounds are exactly lo..hi: a model fills its block's box, splinters,
    stubs and all, so nothing stands past what stops a BB."""
    vs = ob.data.vertices
    a = [min(v.co[i] for v in vs) for i in range(3)]
    z = [max(v.co[i] for v in vs) for i in range(3)]
    for v in vs:
        for i in range(3):
            v.co[i] = lo[i] + (v.co[i] - a[i]) * (hi[i] - lo[i]) / max(z[i] - a[i], 1e-9)
    ob.data.update()
