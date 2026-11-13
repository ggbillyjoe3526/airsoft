"""The bare hands' skin (HA1, the owner: "for the first person arms with no gloves I want you to improve the quality
and detail of the hand model and its textures", with a photo and a sculpt of the back of a hand): the hand's own
surface as a mesh of its own, `Skin_<side>`, unwrapped once (cut along the hand's and the fingers' sides, so the back
and the palm are each one piece) and painted at 2K: colour, a normal map and a roughness map, and the fingernails'
tile beside them, which the nails' own mesh takes.

Nothing is copied from the references: every mark is placed from the hand's own joints (glove.Frame) and drawn in
the hand's space, then written to each texel from where that texel lies on the hand. On the back: the rings of
wrinkles over each middle knuckle, the creases across each last one, the knuckles' rise and dimples, the tendons to
them, the veins between, and fine hair. On the palm's side: the creases across each finger joint and its root, the
palm's three lines and the wrist's. Everywhere: the skin's fine net of lines, pores, and a mottled, redder or paler
tone (knuckles and fingertips pinker, the palm paler, a vein cooler).

The right hand is the left mirrored and takes the same maps (pose.skin_object reverses its faces: `mirror_uv`)."""

import math
import os

import bpy
import bmesh
import numpy as np

import glove

SIZE = 2048
# The atlas keeps this share along its bottom and right edges clear of the hand, for the nail's tile.
STRIP = 0.07
# The nail's tile in the atlas (u, v of its corner; width, height): every nail takes the same one.
NAIL_TILE = (0.012, 0.008, 0.050, 0.054)
PACK_MARGIN = 0.004
# The packings tried (`pack`): the share of the atlas's width the hand's islands are kept to.
PACKS = (1.0, 0.88, 0.8, 0.72)
# The atlas's grid when a clear square is looked for (`clear_square`).
GRID = 64
# How much the kit's square counts beside the hand's own share when packings are compared (`pack`).
KIT_WEIGHT = 0.5
# How far each map is spread past its islands' edges (texels), so a seam never samples the empty atlas.
SPREAD = 12
# Two faces' texels this far apart on the hand (m) at one place in the atlas lie over one another (`raster` says so).
OVERLAP = 0.003
# The mesh attribute `unwrap` leaves on the skin: how much of each vertex is the thumb's.
THUMB_SHARE = "thumb_share"
IMAGES = {"colour": "ArmsSkin", "normal": "ArmsSkinNormal", "rough": "ArmsSkinRough"}

# Tones (sRGB 0..1): the back of the hand, the palm, a knuckle's flush, a fingertip's, a vein's cast, a crease's
# shade, a hair.
TONE = {"back": (0.730, 0.520, 0.420), "palm": (0.810, 0.585, 0.520), "flush": (0.660, 0.340, 0.300),
        "tip": (0.800, 0.490, 0.450), "vein": (0.420, 0.500, 0.560), "crease": (0.480, 0.270, 0.230),
        "hair": (0.330, 0.240, 0.180), "pad": (0.790, 0.480, 0.440)}
# How strongly a crease shades the skin: on the back, on the palm's side.
CREASE_SHADE = (0.60, 0.45)
# How strongly the skin's tone varies (the game's light and its muted colours flatten a faint map): its mottling, its
# blotches' green and blue, a knuckle's flush, a vein's cast, and the fine net's and the pores' shade.
MOTTLE_SHADE = 0.16
BLOTCH_SHADE = (0.08, 0.11)
FLUSH_SHADE = 0.60
VEIN_SHADE = 0.30
FINE_SHADE = (0.12, 0.08)
# The hand's forms drawn into the colour as well as the normal map (the critic, HA1: in the game's even light the
# knuckles, tendons and veins of the normal map alone left the back of the hand one flat tone): each rise a little
# lighter on its crown and darker in a ring round its foot. How strongly (share of the tone), how much of the crown's
# gain the ring takes back, and how many times wider than the rise the ring is.
FORM_SHADE = 0.40
FORM_RING = 0.60
FORM_WIDE = 1.8
# A tendon is a long form: it takes this share of a knuckle's shade (the owner, 2026-11-13, of the first bare hands
# with the forms in the colour: "make the tendons more subtle"; it was a half, and the ridge 0.7 mm).
TENDON_FORM = 0.22
# The wrinkles over a middle knuckle: how far apart (m), and the fine ones along the back of each finger.
WRINKLE_GAP = 0.00115
FINGER_LINES = (0.0016, 0.00006)
# The nail (sRGB): its bed and the moon at its root; and its roughness. The nails are cut short, with no white free
# edge, and the moon is a faint paler patch (MOON, its share of the bed's tone): the owner, 2026-11-13, of a white
# edge and a white moon, "Remove the white finger nail tips".
NAIL_TONE = {"bed": (0.850, 0.640, 0.610), "moon": (0.900, 0.740, 0.710)}
MOON = 0.30
NAIL_ROUGH = 0.40
# Heights (m) of the forms the normal map carries.
KNUCKLE_RISE = 0.00100
KNUCKLE_DIMPLE = 0.00012
JOINT_RISE = 0.00050
JOINT_RINGS = 0.00045
LAST_CREASE = 0.00016
PALM_CREASE = 0.00026
PALM_LINE = 0.00030
TENDON = 0.00040
VEIN = 0.00050
# Half the width of a tendon's ridge and of a vein (m).
TENDON_HALF = 0.0022
# The thumb's tendon is drawn on the skin within the first of these of its bones, fading to nothing by the second (m).
THUMB_NEAR = (0.014, 0.022)
VEIN_HALF = 0.0020
NET = 0.000070
PORE = 0.000030
# The fine net's cell (m), and the mottling's two sizes.
NET_CELL = 0.00085
MOTTLE = (0.012, 0.004)
ROUGH = {"back": 0.60, "palm": 0.64, "net": 0.10, "crease": 0.16, "flush": -0.05}
# Hairs: how many, their length (m, from, to), and how strongly they draw.
HAIRS = 3600
HAIR_LENGTH = (0.0022, 0.0055)
HAIR_DRAW = 0.42
# Veins and the palm's lines as (u, v) across the hand: u from the index finger's knuckle (0) to the little finger's
# (1), v from the wrist (0) to the knuckles (1); below 0, up the forearm.
VEINS = (
    ((0.30, -0.60), (0.33, -0.10), (0.28, 0.25), (0.38, 0.55), (0.36, 0.82)),
    ((0.66, -0.60), (0.62, -0.05), (0.66, 0.30), (0.60, 0.58), (0.64, 0.85)),
    ((0.38, 0.55), (0.50, 0.45), (0.60, 0.58)),
    ((0.60, 0.58), (0.80, 0.50), (0.92, 0.25), (0.88, -0.20)),
    ((0.28, 0.25), (0.10, 0.15), (0.02, -0.10), (0.06, -0.40), (0.02, -0.65)),
)
PALM_LINES = (
    ((1.08, 0.80), (0.75, 0.80), (0.45, 0.86), (0.22, 0.98), (0.12, 1.10)),
    ((-0.14, 0.74), (0.20, 0.70), (0.55, 0.60), (0.95, 0.50)),
    ((-0.14, 0.74), (0.12, 0.62), (0.28, 0.40), (0.34, 0.15), (0.36, -0.05)),
)
WRIST_HALF = 0.025
FOREARM_SPAN = 0.08


def _a(v) -> np.ndarray:
    return np.array(tuple(v), dtype=np.float32)


def _unit(v: np.ndarray) -> np.ndarray:
    return v / max(float(np.linalg.norm(v)), 1e-12)


def _smooth(a: float, b: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _hash(ix: np.ndarray, iy: np.ndarray, iz: np.ndarray, seed: int) -> np.ndarray:
    """A steady pseudo-random number in 0..1 for each whole-number point."""
    h = (ix.astype(np.uint32) * np.uint32(73856093)) ^ (iy.astype(np.uint32) * np.uint32(19349663)) \
        ^ (iz.astype(np.uint32) * np.uint32(83492791)) ^ np.uint32((seed * 2654435761) & 0xFFFFFFFF)
    h ^= h >> np.uint32(13)
    h *= np.uint32(0x5BD1E995)
    h ^= h >> np.uint32(15)
    return (h & np.uint32(0xFFFFFF)).astype(np.float32) / np.float32(1 << 24)


def noise(p: np.ndarray, cell: float, seed: int) -> np.ndarray:
    """Smooth noise in 0..1 over the points `p` (n, 3), one lump every `cell` metres."""
    q = p / cell
    base = np.floor(q)
    f = q - base
    f = f * f * (3.0 - 2.0 * f)
    i = base.astype(np.int64)
    out = np.zeros(len(p), dtype=np.float32)
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1.0 - f[:, 0]) * (f[:, 1] if dy else 1.0 - f[:, 1]) \
                    * (f[:, 2] if dz else 1.0 - f[:, 2])
                out += w * _hash(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out


# Each octave of `cloud` is turned from the last, so the lumps never line up along the axes.
_TURN = np.array([[0.36, 0.48, -0.80], [-0.80, 0.60, 0.00], [0.48, 0.64, 0.60]], dtype=np.float32)


def cloud(p: np.ndarray, cell: float, seed: int, octaves: int = 4) -> np.ndarray:
    """Soft cloudy noise in 0..1: `octaves` of `noise`, each half the size and half the strength of the last."""
    out = np.zeros(len(p), dtype=np.float32)
    q, share, total = p, 1.0, 0.0
    for k in range(octaves):
        out += share * noise(q, cell / (2 ** k), seed + 17 * k)
        total += share
        share *= 0.5
        q = q @ _TURN.T
    return out / total


def cells(p: np.ndarray, cell: float, seed: int) -> tuple:
    """For each point of `p`, how far (in cells) the nearest and the next scattered point lie: the skin's net of fine
    lines runs where the two are near equal, a pore sits at each point."""
    q = p / cell
    base = np.floor(q).astype(np.int64)
    f1 = np.full(len(p), 9.0, dtype=np.float32)
    f2 = np.full(len(p), 9.0, dtype=np.float32)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                cx, cy, cz = base[:, 0] + dx, base[:, 1] + dy, base[:, 2] + dz
                d = np.sqrt((q[:, 0] - cx - _hash(cx, cy, cz, seed)) ** 2
                            + (q[:, 1] - cy - _hash(cx, cy, cz, seed + 1)) ** 2
                            + (q[:, 2] - cz - _hash(cx, cy, cz, seed + 2)) ** 2)
                f2 = np.minimum(f2, np.maximum(f1, d))
                f1 = np.minimum(f1, d)
    return f1, f2


def to_segment(p: np.ndarray, a: np.ndarray, b: np.ndarray) -> tuple:
    """Each point's distance to the segment a-b and its share along it."""
    ab = b - a
    t = np.clip(((p - a) @ ab) / max(float(ab @ ab), 1e-12), 0.0, 1.0)
    return np.linalg.norm(p - (a + t[:, None] * ab), axis=1), t


def curve(pts: list, steps: int = 8) -> list:
    """`pts` joined by a smooth curve through them (Catmull-Rom), `steps` points to each span."""
    if len(pts) < 3:
        return list(pts)
    ends = [pts[0] * 2.0 - pts[1]] + list(pts) + [pts[-1] * 2.0 - pts[-2]]
    out = []
    for a, b, c, d in zip(ends, ends[1:], ends[2:], ends[3:]):
        for k in range(steps):
            t = k / steps
            out.append(0.5 * (2.0 * b + (c - a) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t
                              + (3.0 * b - a - 3.0 * c + d) * t ** 3))
    return out + [pts[-1]]


def to_line(p: np.ndarray, pts: list) -> np.ndarray:
    """Each point's distance to the smooth line through `pts`."""
    pts = curve(pts)
    out = np.full(len(p), 9.0, dtype=np.float32)
    for a, b in zip(pts, pts[1:]):
        out = np.minimum(out, to_segment(p, a, b)[0])
    return out


# ------------------------------------------------------------------------------------------------------- unwrap

def unwrap(ob: bpy.types.Object, fr: glove.Frame) -> None:
    """UVs for the left hand's skin: cut where the back meets the palm's side (each face by which way it faces; a
    thumb's by its own back), unwrapped by angle and packed into the atlas clear of the nail's strip."""
    me = ob.data
    thumb_up = _thumb_up(fr)
    groups = {g.index: g.name for g in ob.vertex_groups}
    # How much of each vertex is the thumb's: the way "the back" faces turns from the hand's to the thumb's own with
    # it, so the cut runs on from the hand's side down the thumb's in one line (a sharp change of it at the thumb's
    # root left small islands there, and thumb faces lying over a finger's in the atlas).
    thumb = [sum(g.weight for g in v.groups if groups[g.group].startswith(("Thumb", "Heel"))) for v in me.vertices]
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    dorsal = np.array(tuple(fr.dorsal))
    side = {}
    for f in bm.faces:
        share = sum(thumb[v.index] for v in f.verts) / len(f.verts)
        up = dorsal + (thumb_up - dorsal) * share
        side[f.index] = float(np.array(tuple(f.normal)) @ up) >= 0.0
    # A face alone among the other side's is taken with them: no speckle of small islands along the cut.
    for _ in range(4):
        new = {}
        for f in bm.faces:
            near = [side[e_f.index] for e in f.edges for e_f in e.link_faces if e_f is not f]
            new[f.index] = (sum(near) * 2 > len(near)) if near and sum(near) * 2 != len(near) else side[f.index]
        side = new
    for e in bm.edges:
        fs = e.link_faces
        e.seam = len(fs) == 2 and side[fs[0].index] != side[fs[1].index]
    bm.to_mesh(me)
    bm.free()
    bpy.context.view_layer.update()
    for o in bpy.context.scene.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.unwrap(method="ANGLE_BASED", margin=PACK_MARGIN)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    bpy.ops.object.mode_set(mode="OBJECT")
    # The thumb's share of each vertex, kept for the painting (`raster`).
    share = me.attributes.new(THUMB_SHARE, "FLOAT", "POINT")
    share.data.foreach_set("value", thumb)
    pack(ob)


def pack(ob: bpy.types.Object) -> None:
    """Pack the skin's unwrapped islands into the atlas, clear of the nail's strip. The glove's kit lives in the
    largest square the hand leaves clear (glove_paint.kit_uv), and Blender's packer, left the whole atlas, lays the
    same islands out quite differently for a small change of the mesh (a longer little finger took a third off the
    kit's square). So each of PACKS is tried, the hand kept to a share of the atlas's width, and the one kept is the
    one that gives the hand and the kit the most texels between them (`pack_score`)."""
    me = ob.data
    # The UV layer's data is read afresh after each change of mode: Blender moves it.
    flat = np.zeros(len(me.loops) * 2, dtype=np.float32)
    me.uv_layers.active.data.foreach_get("uv", flat)
    parts = islands(me)
    best = None
    for width in PACKS:
        uv = flat.reshape(-1, 2).copy()
        size = boxed(uv, parts, width)
        me.uv_layers.active.data.foreach_set("uv", uv.ravel())
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.uv.select_all(action="SELECT")
        # Turned any way and fitted by their outlines: the back and the palm lie fingers between fingers.
        bpy.ops.uv.pack_islands(udim_source="ORIGINAL_AABB", rotate=True, rotate_method="ANY",
                                shape_method="CONCAVE", margin=PACK_MARGIN)
        bpy.ops.object.mode_set(mode="OBJECT")
        uv = np.zeros(len(me.loops) * 2, dtype=np.float32)
        me.uv_layers.active.data.foreach_get("uv", uv)
        uv = uv.reshape(-1, 2) / size * (1.0 - STRIP)
        uv[:, 1] += STRIP
        hand, kit = pack_score(me, uv)
        score = hand * kit ** KIT_WEIGHT
        if os.environ.get("BL_DEBUG"):
            print("  pack into %.2f of the width: hand %.3f, kit's square %.3f, score %.4f, within (%.2f..%.2f, "
                  "%.2f..%.2f)" % (width, hand, kit, score, uv[:, 0].min(), uv[:, 0].max(), uv[:, 1].min(),
                                   uv[:, 1].max()))
        if best is None or score > best[0] + 1e-6:
            best = (score, uv)
    me.uv_layers.active.data.foreach_set("uv", best[1].ravel())


def islands(me: bpy.types.Mesh) -> list:
    """The mesh's UV islands, each the indices of its loops: faces joined across every edge that is not a seam."""
    group = list(range(len(me.polygons)))

    def root(k: int) -> int:
        while group[k] != k:
            group[k] = group[group[k]]
            k = group[k]
        return k

    first = {}
    for poly in me.polygons:
        for li in poly.loop_indices:
            edge = me.loops[li].edge_index
            if me.edges[edge].use_seam:
                continue
            if edge in first:
                group[root(poly.index)] = root(first[edge])
            else:
                first[edge] = poly.index
    out = {}
    for poly in me.polygons:
        out.setdefault(root(poly.index), []).extend(poly.loop_indices)
    return [np.array(v) for v in out.values()]


def boxed(uv: np.ndarray, parts: list, width: float) -> float:
    """Move the islands `parts` of `uv` (in place, none turned or scaled) so that together they span a box `width`
    times as wide as it is high, its corner at the origin: the two largest in opposite corners, the rest at the
    origin. The packer then keeps to that box (ORIGINAL_AABB). Returns the box's height."""
    big = sorted(parts, key=lambda p: -float(np.prod(np.ptp(uv[p], axis=0))))
    spans = [np.ptp(uv[p], axis=0) for p in big[:2]]
    size = max((spans[0][0] + spans[1][0]) / width, spans[0][1] + spans[1][1])
    for p in big:
        uv[p] -= uv[p].min(axis=0)
    uv[big[1]] += np.array((width * size, size), dtype=np.float32) - uv[big[1]].max(axis=0)
    return float(size)


def pack_score(me: bpy.types.Mesh, uv: np.ndarray) -> tuple:
    """How a packing (`uv`, a pair a loop) serves the two that share the atlas: the side of the atlas's share the
    hand's faces cover were they one square, and the side of the largest square left clear for the glove's kit."""
    used = np.zeros((GRID, GRID), dtype=bool)
    area = 0.0
    for poly in me.polygons:
        pts = uv[poly.loop_start:poly.loop_start + poly.loop_total]
        x, y = pts[:, 0], pts[:, 1]
        area += abs(float(np.dot(x, np.roll(y, 1)) - np.dot(y, np.roll(x, 1)))) * 0.5
        lo = np.clip((pts.min(axis=0) * GRID).astype(int), 0, GRID - 1)
        hi = np.clip((pts.max(axis=0) * GRID).astype(int), 0, GRID - 1)
        used[lo[1]:hi[1] + 1, lo[0]:hi[0] + 1] = True
    return math.sqrt(area), clear_square(used)[2]


def clear_square(used: np.ndarray) -> tuple:
    """The largest square of the atlas clear of the cells `used` marks (GRID a side), of the nails' tile and of the
    cells beside either: its corner (u, v) and its side, as shares of the atlas."""
    used = used.copy()
    u0, v0, w, h = NAIL_TILE
    used[int(v0 * GRID):int((v0 + h) * GRID) + 1, int(u0 * GRID):int((u0 + w) * GRID) + 1] = True
    near = used.copy()
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)):
        near |= np.roll(used, (dy, dx), axis=(0, 1))
    side = np.zeros((GRID + 1, GRID + 1), dtype=np.int32)
    best = (0, 0, 0)
    for y in range(GRID):
        for x in range(GRID):
            if not near[y, x]:
                side[y + 1, x + 1] = 1 + min(side[y, x], side[y, x + 1], side[y + 1, x])
                if side[y + 1, x + 1] > best[0]:
                    best = (int(side[y + 1, x + 1]), x + 1 - int(side[y + 1, x + 1]), y + 1 - int(side[y + 1, x + 1]))
    return best[1] / GRID, best[2] / GRID, best[0] / GRID


def mirror_uv(left: bpy.types.Object, right: bpy.types.Object, faces: range = None) -> None:
    """The right hand's UVs from the left's (all its faces, or `faces` alone): the same faces, each wound the other
    way (pose.skin_object)."""
    src, dst = left.data, right.data
    if dst.uv_layers.active is None:
        dst.uv_layers.new(name=src.uv_layers.active.name)
    s, d = src.uv_layers.active.data, dst.uv_layers.active.data
    for k in (faces if faces is not None else range(len(src.polygons))):
        ps, pd = src.polygons[k], dst.polygons[k]
        n = ps.loop_total
        for k in range(n):
            ls, ld = ps.loop_start + n - 1 - k, pd.loop_start + k
            if src.loops[ls].vertex_index != dst.loops[ld].vertex_index:
                raise ValueError("%s: its faces are not %s's mirrored" % (right.name, left.name))
            d[ld].uv = s[ls].uv


def nail_uv(nails: list, verts: list, fr: glove.Frame) -> None:
    """UVs for the nails' meshes `nails` (both sides', each vertex for vertex the left's at rest, `verts`): every nail
    onto the nail's tile, across it round the finger and up it toward the tip (as glove.nails lays them)."""
    j = fr.j
    co = np.array([tuple(v) for v in verts], dtype=np.float32)
    at = np.zeros((len(co), 2), dtype=np.float32)
    best = np.full(len(co), 9.0, dtype=np.float32)
    for f in glove.FINGER_NAMES:
        a, b = _a(j["finger-%d-3" % f]), _a(j["finger-%d-4" % f])
        d = _unit(b - a)
        up = _a(fr.dorsal) if f != 1 else _thumb_up(fr)
        up = _unit(up - d * float(up @ d))
        across = np.cross(d, up)
        dist, _ = to_segment(co, a, b)
        rel = co - a
        share = (rel @ d) / float(np.linalg.norm(b - a))
        span, wrap = (glove.THUMB_NAIL_SPAN, glove.THUMB_NAIL_WRAP) if f == 1 else (glove.NAIL_SPAN, glove.NAIL_WRAP)
        v = (share - span[0]) / (span[1] - span[0])
        u = np.arctan2(rel @ across, np.maximum(rel @ up, 1e-6)) / math.radians(wrap) * 0.5 + 0.5
        near = dist < best
        best[near] = dist[near]
        at[near, 0] = np.clip(u[near], 0.0, 1.0)
        at[near, 1] = np.clip(v[near], 0.0, 1.0)
    u0, v0, w, h = NAIL_TILE
    for ob in nails:
        me = ob.data
        if me.uv_layers.active is None:
            me.uv_layers.new(name="UVMap")
        data = me.uv_layers.active.data
        for loop in me.loops:
            u, v = at[loop.vertex_index]
            data[loop.index].uv = (u0 + u * w, v0 + v * h)


def _thumb_up(fr: glove.Frame) -> np.ndarray:
    """The way the back of the thumb faces: away from the palm (as glove.nails has it)."""
    j = fr.j
    a = _a(j["finger-1-3"])
    return _unit(a - (_a(fr.palm_centre) + _a(fr.palmar) * 0.02))


# -------------------------------------------------------------------------------------------------------- raster

def raster(ob: bpy.types.Object, faces=None, tags: dict = None, lapping: bool = False) -> tuple:
    """Where each texel of the atlas lies on `ob` at rest (all its faces, or `faces` alone): its place and normal
    (SIZE x SIZE x 3; row 0 the atlas's bottom), how much of it is the thumb's, and whether the mesh covers it. With
    `tags` (a number for each face), the thumb's share gives way to the tag of the face each texel lies on. Texels
    two places claim are told of, unless `lapping` says pieces are meant to lie over one another."""
    me = ob.data
    uv = np.zeros(len(me.loops) * 2, dtype=np.float64)
    me.uv_layers.active.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2) * SIZE
    co = np.zeros(len(me.vertices) * 3, dtype=np.float64)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    no = np.array([tuple(v.normal) for v in me.vertices], dtype=np.float64)
    share = np.zeros(len(me.vertices), dtype=np.float64)
    if THUMB_SHARE in me.attributes:
        me.attributes[THUMB_SHARE].data.foreach_get("value", share)
    thumb = np.zeros((SIZE, SIZE), dtype=np.float32)
    pos = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
    nrm = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
    mask = np.zeros((SIZE, SIZE), dtype=bool)
    lapped = 0
    for poly in (me.polygons if faces is None else (me.polygons[k] for k in faces)):
        loops = list(poly.loop_indices)
        vs = list(poly.vertices)
        for k in range(1, len(loops) - 1):
            tri = (0, k, k + 1)
            (ax, ay), (bx, by), (cx, cy) = (uv[loops[t]] for t in tri)
            den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(den) < 1e-9:
                continue
            x0, x1 = max(int(min(ax, bx, cx)) - 1, 0), min(int(max(ax, bx, cx)) + 1, SIZE - 1)
            y0, y1 = max(int(min(ay, by, cy)) - 1, 0), min(int(max(ay, by, cy)) + 1, SIZE - 1)
            xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            w0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
            w1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
            w2 = 1.0 - w0 - w1
            # A texel's width past its edges too: neighbouring faces overlap there and agree, and no texel between
            # two of them is left out.
            inside = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
            if not inside.any():
                continue
            pa, pb, pc = (co[vs[t]] for t in tri)
            na, nb, nc = (no[vs[t]] for t in tri)
            w = np.stack([w0[inside], w1[inside], w2[inside]], axis=1)
            at = w @ np.stack([pa, pb, pc])
            # A texel two far-apart places both claim: islands lying over one another.
            was, had = pos[y0:y1 + 1, x0:x1 + 1][inside], mask[y0:y1 + 1, x0:x1 + 1][inside]
            lapped += int((had & (np.linalg.norm(was - at, axis=1) > OVERLAP)).sum())
            pos[y0:y1 + 1, x0:x1 + 1][inside] = at
            nrm[y0:y1 + 1, x0:x1 + 1][inside] = w @ np.stack([na, nb, nc])
            thumb[y0:y1 + 1, x0:x1 + 1][inside] = (w @ np.array([share[vs[t]] for t in tri]) if tags is None
                                                   else tags[poly.index])
            mask[y0:y1 + 1, x0:x1 + 1][inside] = True
    length = np.linalg.norm(nrm, axis=2, keepdims=True)
    nrm /= np.maximum(length, 1e-9)
    if lapped and not lapping:
        print("  ! %s: %d texels of the atlas are claimed by two places on it" % (ob.name, lapped))
    return pos, nrm, thumb, mask


def spread(img: np.ndarray, mask: np.ndarray, rounds: int = SPREAD) -> np.ndarray:
    """`img` with its covered texels' values carried `rounds` texels out over the uncovered ones."""
    out = img.copy()
    have = mask.copy()
    for _ in range(rounds):
        total = np.zeros_like(out)
        count = np.zeros(have.shape, dtype=np.float32)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            total += np.roll(np.where(have[..., None] if out.ndim == 3 else have, out, 0.0), (dy, dx), axis=(0, 1))
            count += np.roll(have, (dy, dx), axis=(0, 1))
        fill = (~have) & (count > 0)
        if out.ndim == 3:
            out[fill] = total[fill] / count[fill][:, None]
        else:
            out[fill] = total[fill] / count[fill]
        have |= fill
    return out


# --------------------------------------------------------------------------------------------------------- paint

class Hand:
    """The left hand's own directions and joints as arrays, and places across it by (u, v) (see VEINS)."""

    def __init__(self, fr: glove.Frame):
        j = fr.j
        self.wrist = _a(fr.wrist)
        self.fdir = _a(fr.fdir)
        self.dorsal = _a(fr.dorsal)
        self.fingers = _a(fr.fingers)
        self.knuckles = [_a(k) for k in fr.knuckles]
        across = self.knuckles[3] - self.knuckles[0]
        self.across = _unit(across - self.fingers * float(across @ self.fingers))
        self.thumb_up = _thumb_up(fr)
        self.palm_centre = _a(fr.palm_centre)
        self.palmar = _a(fr.palmar)
        self.joint = {(f, k): _a(j["finger-%d-%d" % (f, k)]) for f in glove.FINGER_NAMES for k in (1, 2, 3, 4)}

    def at(self, u: float, v: float) -> np.ndarray:
        low = self.wrist + self.across * ((u - 0.5) * 2.0 * WRIST_HALF)
        if v < 0.0:
            return low + self.fdir * (v * FOREARM_SPAN)
        high = self.knuckles[0] + (self.knuckles[3] - self.knuckles[0]) * u
        return low + (high - low) * v

    def flat(self, p: np.ndarray) -> np.ndarray:
        """`p` laid on the plane of the back of the hand (a line drawn across the hand is then as near a texel on
        the palm's side as on the back: each mark asks which side it is for)."""
        return p - np.outer(p @ self.dorsal, self.dorsal) if p.ndim == 2 else p - self.dorsal * float(p @ self.dorsal)

    def line(self, marks: tuple) -> list:
        return [self.flat(self.at(u, v)) for u, v in marks]

    def finger_frame(self, f: int, k: int) -> tuple:
        """Joint `k` of finger `f`: its centre, the finger's line through it, the way its back faces, and across."""
        at = self.joint[(f, k)]
        d = _unit(self.joint[(f, k + 1)] - self.joint[(f, k - 1)])
        up = self.dorsal if f != 1 else self.thumb_up
        up = _unit(up - d * float(up @ d))
        return at, d, up, np.cross(d, up)


def paint(p: np.ndarray, n: np.ndarray, thumb: np.ndarray, hand: Hand) -> tuple:
    """The skin at the points `p` (n, 3) with normals `n`, `thumb` of each the thumb's: its height over the hand's
    surface (m), its colour (sRGB) and its roughness, and how much hair each may carry."""
    count = len(p)
    # The back faces the hand's way on the hand and the thumb's own on the thumb, as the atlas was cut (`unwrap`).
    facing = n @ hand.dorsal + thumb * (n @ (hand.thumb_up - hand.dorsal))
    back = _smooth(0.15, 0.75, facing)
    front = _smooth(0.15, 0.75, -facing)
    along = (p - hand.wrist) @ hand.fdir
    flat = hand.flat(p)
    # Which finger each point is on: the nearest one's line, within a finger's thickness.
    finger = np.zeros(count, dtype=np.int8)
    nearest = np.full(count, 9.0, dtype=np.float32)
    for f in glove.FINGER_NAMES:
        first = 2 if f == 1 else 1
        for k in range(first, 4):
            a, b = hand.joint[(f, k)], hand.joint[(f, k + 1)]
            # Past the knuckle only: the knuckle itself is the hand's.
            if k == first:
                a = a + (b - a) * 0.25
            dist, _ = to_segment(p, a, b)
            near = dist < nearest
            nearest[near] = dist[near]
            finger[near] = f
    finger[nearest > 0.016] = 0
    on_hand = (finger == 0) & (along > -0.004)
    wobble = noise(p, 0.0015, 11) * 2.0 - 1.0

    height = np.zeros(count, dtype=np.float32)
    flush = np.zeros(count, dtype=np.float32)
    crease = np.zeros(count, dtype=np.float32)
    tip = np.zeros(count, dtype=np.float32)
    form = np.zeros(count, dtype=np.float32)

    for f in glove.FINGER_NAMES:
        own = finger == f
        if not own.any():
            continue
        q, qn = p[own], n[own]
        w = wobble[own]
        h = np.zeros(len(q), dtype=np.float32)
        red = np.zeros(len(q), dtype=np.float32)
        cut = np.zeros(len(q), dtype=np.float32)
        lit = np.zeros(len(q), dtype=np.float32)
        # The big knuckle (a finger's middle joint, the thumb's last) and the small one past it (none on the thumb,
        # whose first knuckle wrinkles a little instead).
        big, small = (3, 2) if f == 1 else (2, 3)
        for k, kind in ((big, "big"), (small, "small")):
            at, d, up, across = hand.finger_frame(f, k)
            rel = q - at
            s, side = rel @ d, rel @ across
            facing = qn @ up
            on_back, on_front = _smooth(0.15, 0.7, facing), _smooth(0.15, 0.7, -facing)
            if kind == "big":
                # Wrinkles across the knuckle, each bowed round its middle (the outer ones the most) and broken here
                # and there: folds of loose skin, never rings.
                r = np.sqrt((s / 0.0065) ** 2 + (side / 0.0075) ** 2)
                bowed = s * (1.0 + 1.1 * (side / 0.0075) ** 2) + 0.00025 * w
                folds = np.clip(np.cos(2.0 * math.pi * bowed / WRINKLE_GAP), 0.0, 1.0) ** 3
                broken = 0.55 + 0.45 * _smooth(0.3, 0.6, noise(q, 0.0022, 31 + f))
                fade = np.exp(-1.2 * (r / 0.85) ** 2)
                h += on_back * (JOINT_RISE * np.exp(-(r / 0.7) ** 2) - JOINT_RINGS * folds * broken * fade)
                lit += on_back * (np.exp(-(r / 0.7) ** 2) - FORM_RING * np.exp(-(r / (0.7 * FORM_WIDE)) ** 2))
                cut += on_back * folds * broken * fade * 0.8
                red += on_back * np.exp(-(r / 0.9) ** 2)
            else:
                bowed = s + 0.0009 * (side / 0.007) ** 2
                lines = sum(np.exp(-((bowed - c) / 0.00028) ** 2) for c in (-0.0022, -0.0008, 0.0008))
                fade = np.exp(-(side / 0.0065) ** 2) * np.exp(-(s / 0.004) ** 2) * (0.5 if f == 1 else 1.0)
                h -= on_back * LAST_CREASE * lines * fade
                cut += on_back * lines * fade * 0.7
                red += on_back * 0.45 * np.exp(-(s / 0.005) ** 2)
            # Across the palm's side of the joint: two creases.
            lines = np.exp(-((s + 0.0003 * w) / 0.00042) ** 2) \
                + 0.5 * np.exp(-((s - 0.0013 + 0.0004 * w) / 0.00035) ** 2)
            fade = np.exp(-(s / 0.004) ** 2) * (0.7 + 0.3 * noise(q, 0.003, 41))
            h -= on_front * PALM_CREASE * lines * fade
            cut += on_front * lines * fade * 0.8
        # Where the finger leaves the palm: a crease across its root (two on a finger, one on the thumb).
        first = 2 if f == 1 else 1
        a, b = hand.joint[(f, first)], hand.joint[(f, first + 1)]
        d = _unit(b - a)
        root = a + (b - a) * (0.25 if f == 1 else 0.42)
        s = (q - root) @ d
        up = hand.dorsal if f != 1 else hand.thumb_up
        on_front = _smooth(0.15, 0.7, -(qn @ up))
        lines = np.exp(-((s + 0.0003 * w) / 0.00042) ** 2)
        if f != 1:
            lines = lines + 0.6 * np.exp(-((s + 0.0015 + 0.0004 * w) / 0.00035) ** 2)
        h -= on_front * PALM_CREASE * lines
        cut += on_front * lines * 0.8
        # Fine lines across the back of the finger between its joints.
        up_back = _smooth(0.15, 0.7, qn @ up)
        along_f = (q - a) @ d
        fine_lines = np.clip(np.cos(2.0 * math.pi * (along_f + 0.0005 * w) / FINGER_LINES[0]), 0.0, 1.0) ** 2 \
            * _smooth(0.35, 0.65, noise(q, 0.0018, 51))
        h -= up_back * FINGER_LINES[1] * fine_lines
        # The fingertip's pad and sides, pinker.
        a, b = hand.joint[(f, 3)], hand.joint[(f, 4)]
        share = ((q - a) @ (b - a)) / float((b - a) @ (b - a))
        tip[own] = _smooth(0.25, 0.9, share)
        height[own] += h
        flush[own] += red
        crease[own] += cut
        form[own] += lit

    # The knuckles: each a rounded rise with a faint ring of dimples, flushed.
    for f in (2, 3, 4, 5):
        rel = flat - hand.flat(hand.joint[(f, 1)])
        r = np.linalg.norm(rel, axis=1) / 0.009
        # A few faint folds across it, as the skin slackens over a straightened knuckle.
        s = rel @ hand.fingers
        folds = np.clip(np.cos(2.0 * math.pi * (s + 0.0004 * wobble) / (WRINKLE_GAP * 1.5)), 0.0, 1.0) ** 3 \
            * _smooth(0.35, 0.6, noise(p, 0.0026, 61 + f))
        height += back * (KNUCKLE_RISE * np.exp(-1.5 * r * r) - KNUCKLE_DIMPLE * folds * np.exp(-r * r))
        crease += back * folds * np.exp(-r * r) * 0.35
        flush += back * 0.75 * np.exp(-r * r)
        form += back * (np.exp(-1.5 * r * r) - FORM_RING * np.exp(-1.5 * (r / FORM_WIDE) ** 2))
    # The tendons, from the wrist's middle out to each knuckle, standing a little off the back of the hand.
    ridge = np.zeros(count, dtype=np.float32)
    foot = np.zeros(count, dtype=np.float32)
    for i, f in enumerate((2, 3, 4, 5)):
        a = hand.flat(hand.wrist + hand.across * ((i - 1.5) * 0.007))
        b = hand.flat(hand.joint[(f, 1)])
        dist, t = to_segment(flat, a, b)
        span = _smooth(0.08, 0.35, t) * (1.0 - _smooth(0.78, 0.98, t))
        ridge = np.maximum(ridge, np.exp(-(dist / TENDON_HALF) ** 2) * span)
        foot = np.maximum(foot, np.exp(-(dist / (TENDON_HALF * FORM_WIDE)) ** 2) * span)
    ridge *= back * on_hand
    height += TENDON * ridge
    form += TENDON_FORM * (ridge - FORM_RING * foot * back * on_hand)
    # The thumb's own tendon: a ridge along the back of its first two bones, which the eye looks down on in a hold.
    thumb_up = hand.finger_frame(1, 2)[2]
    for k in (1, 2):
        a, b = hand.joint[(1, k)], hand.joint[(1, k + 1)]
        d = _unit(b - a)
        near, t = to_segment(p, a, b)
        aside = (p - a) @ np.cross(d, thumb_up)
        span = _smooth(0.10, 0.40, t) if k == 1 else 1.0 - _smooth(0.55, 0.95, t)
        # Only where the atlas counts the skin as the back (`back` is nothing at the cut between back and palm: a
        # ridge run over that cut drew a hard line along it), and faded out, never cut, away from the thumb's bones.
        on = span * back * _smooth(0.2, 0.8, n @ thumb_up) * (1.0 - _smooth(THUMB_NEAR[0], THUMB_NEAR[1], near))
        crown = np.exp(-(aside / TENDON_HALF) ** 2) * on
        height += TENDON * crown
        form += TENDON_FORM * (crown - FORM_RING * np.exp(-(aside / (TENDON_HALF * FORM_WIDE)) ** 2) * on)
    # The veins between them, wandering a little.
    vein = np.zeros(count, dtype=np.float32)
    meander = np.stack([noise(p, 0.007, 71), noise(p, 0.007, 72), noise(p, 0.007, 73)], axis=1) - 0.5
    wandered = hand.flat(p + 0.0045 * meander)
    for marks in VEINS:
        vein = np.maximum(vein, np.exp(-(to_line(wandered, hand.line(marks)) / VEIN_HALF) ** 2))
    vein *= back * (finger == 0) * (0.55 + 0.45 * noise(p, 0.012, 74))
    height += VEIN * vein
    # The palm's lines and the wrist's creases.
    lines = np.zeros(count, dtype=np.float32)
    for marks in PALM_LINES:
        lines = np.maximum(lines, np.exp(-((to_line(flat, hand.line(marks)) + 0.0004 * wobble) / 0.0007) ** 2))
    lines *= on_hand
    for c, strength in ((-0.003, 0.8), (-0.010, 0.55)):
        lines = np.maximum(lines, strength * np.exp(-((along - c + 0.0007 * wobble) / 0.0006) ** 2) * (finger == 0))
    lines *= front * (0.6 + 0.4 * noise(p, 0.004, 81))
    height -= PALM_LINE * lines
    crease += lines

    # The fine net of lines and the pores, finer and fainter on the palm's side.
    f1, f2 = cells(p, NET_CELL, 3)
    net = 1.0 - _smooth(0.0, 0.14, f2 - f1)
    pore = np.exp(-(f1 / 0.16) ** 2)
    fine = 0.45 + 0.55 * back
    height -= fine * (NET * net + PORE * pore)

    # Colour.
    def tone(name: str) -> np.ndarray:
        return np.array(TONE[name], dtype=np.float32)

    def mix(colour: np.ndarray, to: np.ndarray, share: np.ndarray) -> np.ndarray:
        return colour + (to - colour) * np.clip(share, 0.0, 1.0)[:, None]

    colour = mix(np.tile(tone("back"), (count, 1)), tone("palm"), front)
    mottle = noise(p, MOTTLE[0], 5) * 0.6 + noise(p, MOTTLE[1], 6) * 0.4 - 0.5
    blotch = noise(p, MOTTLE[0] * 0.7, 7) - 0.5
    colour *= (1.0 + MOTTLE_SHADE * mottle)[:, None]
    colour[:, 1] *= 1.0 - BLOTCH_SHADE[0] * blotch
    colour[:, 2] *= 1.0 - BLOTCH_SHADE[1] * blotch
    colour = mix(colour, tone("flush"), FLUSH_SHADE * np.clip(flush, 0.0, 1.0))
    colour = mix(colour, tone("tip"), 0.40 * tip * (0.4 + 0.6 * front))
    colour = mix(colour, tone("vein"), VEIN_SHADE * vein)
    # The palm's pads (the heel of the thumb, the little finger's side, under the fingers) a little redder.
    pads = front * on_hand * _smooth(0.42, 0.62, noise(p, 0.016, 91))
    colour = mix(colour, tone("pad"), 0.35 * pads)
    colour *= (1.0 + FORM_SHADE * np.clip(form, -1.0, 1.0))[:, None]
    crease = np.clip(crease, 0.0, 1.0)
    colour = mix(colour, tone("crease"), (CREASE_SHADE[0] + (CREASE_SHADE[1] - CREASE_SHADE[0]) * front) * crease)
    colour *= (1.0 - fine * (FINE_SHADE[0] * net + FINE_SHADE[1] * pore))[:, None]
    # A few freckles on the back.
    spot, _ = cells(p, 0.0045, 21)
    freckle = np.exp(-(spot / 0.07) ** 2) * (noise(p, 0.0045, 22) > 0.62) * back
    colour = mix(colour, tone("crease"), 0.30 * freckle)

    rough = ROUGH["back"] + (ROUGH["palm"] - ROUGH["back"]) * front + ROUGH["net"] * net * fine \
        + ROUGH["crease"] * crease + ROUGH["flush"] * np.clip(flush, 0.0, 1.0)
    # Hair: the forearm's back and the hand's, thinner over the fingers' first bones, none past them.
    first_bone = np.zeros(count, dtype=np.float32)
    for f in (2, 3, 4, 5):
        dist, t = to_segment(p, hand.joint[(f, 1)], hand.joint[(f, 2)])
        first_bone = np.maximum(first_bone, (finger == f) * (dist < 0.014) * (t > 0.3) * (t < 0.8))
    # Fuller toward the little finger's side of the hand, as the photo's.
    outer = _smooth(-0.02, 0.02, (flat - hand.flat(hand.wrist)) @ hand.across)
    hairy = back * np.where(finger == 0, np.where(along < 0.0, 1.0, 0.6 + 0.4 * outer), 0.4 * first_bone)
    return height, np.clip(colour, 0.0, 1.0), np.clip(rough, 0.25, 0.9), hairy


def hairs(colour: np.ndarray, pos: np.ndarray, mask: np.ndarray, hairy: np.ndarray, hand: Hand) -> None:
    """Fine hairs drawn into `colour` (SIZE x SIZE x 3): each a short tapering stroke from a texel `hairy` allows,
    lying toward the little finger's side and the fingers, bowed a little."""
    rng = np.random.default_rng(7)
    ys, xs = np.nonzero(mask & (hairy > 0.05))
    if len(ys) == 0:
        return
    weight = hairy[ys, xs].astype(np.float64)
    pick = rng.choice(len(ys), size=HAIRS, p=weight / weight.sum())
    strength = np.zeros(mask.shape, dtype=np.float32)
    lay = hand.across * 0.8 + hand.fingers * 0.6
    for y, x in zip(ys[pick], xs[pick]):
        if not (2 <= x < SIZE - 2 and 2 <= y < SIZE - 2 and mask[y, x - 1] and mask[y, x + 1]
                and mask[y - 1, x] and mask[y + 1, x]):
            continue
        # The stroke's direction in texels: the lay's, through how the atlas maps the surface here.
        du = (pos[y, x + 1] - pos[y, x - 1]) * 0.5
        dv = (pos[y + 1, x] - pos[y - 1, x]) * 0.5
        way = _unit(lay + rng.normal(0.0, 0.35, 3).astype(np.float32))
        length = rng.uniform(*HAIR_LENGTH)
        e, f, g = float(du @ du), float(du @ dv), float(dv @ dv)
        det = e * g - f * f
        if det < 1e-16:
            continue
        ru, rv = float(way @ du) * length, float(way @ dv) * length
        a, b = (g * ru - f * rv) / det, (e * rv - f * ru) / det
        steps = int(max(abs(a), abs(b))) + 2
        s = np.linspace(0.0, 1.0, steps, dtype=np.float32)
        bow = rng.uniform(-0.25, 0.25)
        px = x + a * s - b * bow * s * (1.0 - s)
        py = y + b * s + a * bow * s * (1.0 - s)
        ix, iy = np.clip(np.rint(px).astype(int), 0, SIZE - 1), np.clip(np.rint(py).astype(int), 0, SIZE - 1)
        np.maximum.at(strength, (iy, ix), (1.0 - 0.75 * s) * rng.uniform(0.55, 1.0))
    # A hair is thinner than a texel: softened into its neighbours.
    soft = strength * 0.6
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        soft += np.roll(strength, (dy, dx), axis=(0, 1)) * 0.1
    soft = np.clip(soft, 0.0, 1.0)[..., None] * HAIR_DRAW
    colour += (np.array(TONE["hair"], dtype=np.float32) - colour) * soft


def normals(height: np.ndarray, pos: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """The tangent-space normal map (SIZE x SIZE x 3, 0..1) of `height` (m over the surface): its slope across the
    surface at each texel, through how the atlas maps the surface there, so a stretched island bends the light no
    more and no less than a true one."""
    h = spread(height, mask, 4)
    p = spread(pos, mask, 4)
    hx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
    hy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5
    du = (np.roll(p, -1, axis=1) - np.roll(p, 1, axis=1)) * 0.5
    dv = (np.roll(p, -1, axis=0) - np.roll(p, 1, axis=0)) * 0.5
    e, f, g = (du * du).sum(2), (du * dv).sum(2), (dv * dv).sum(2)
    det = np.maximum(e * g - f * f, 1e-20)
    # The slope as a vector on the surface, a * du + b * dv, then along the unit tangent and bitangent.
    a, b = (g * hx - f * hy) / det, (e * hy - f * hx) / det
    lu, lv = np.sqrt(np.maximum(e, 1e-20)), np.sqrt(np.maximum(g, 1e-20))
    sx = (a * e + b * f) / lu
    sy = (a * f + b * g) / lv
    ok = mask & (e > 1e-12) & (g > 1e-12) & (e * g - f * f > 1e-3 * e * g)
    sx, sy = np.where(ok, sx, 0.0), np.where(ok, sy, 0.0)
    out = np.stack([-sx, -sy, np.ones_like(sx)], axis=-1)
    out /= np.linalg.norm(out, axis=-1, keepdims=True)
    return out * 0.5 + 0.5


def nail_tile(colour: np.ndarray, normal: np.ndarray, rough: np.ndarray) -> None:
    """The nail's tile painted into the maps: the pink bed, a faint moon at its root, its sides a little darker; flat
    and glossy."""
    u0, v0, w, h = NAIL_TILE
    pad = SPREAD
    x0, x1 = int(u0 * SIZE) - pad, int((u0 + w) * SIZE) + pad
    y0, y1 = int(v0 * SIZE) - pad, int((v0 + h) * SIZE) + pad
    x0, y0 = max(x0, 0), max(y0, 0)
    xs, ys = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
    u = np.clip((xs / SIZE - u0) / w, 0.0, 1.0)
    v = np.clip((ys / SIZE - v0) / h, 0.0, 1.0)
    bed, moon = (np.array(NAIL_TONE[k], dtype=np.float32) for k in ("bed", "moon"))
    side = np.abs(u * 2.0 - 1.0)
    tile = np.broadcast_to(bed, u.shape + (3,)).copy()
    tile *= (1.0 - 0.10 * side ** 3 + 0.03 * np.cos(u * 2.0 * math.pi * 9.0) * (1.0 - side))[..., None]
    in_moon = 1.0 - _smooth(0.5, 1.1, np.sqrt(((u - 0.5) / 0.32) ** 2 + (v / 0.18) ** 2))
    tile += (moon - tile) * (MOON * in_moon)[..., None]
    colour[y0:y1, x0:x1] = tile
    normal[y0:y1, x0:x1] = (0.5, 0.5, 1.0)
    rough[y0:y1, x0:x1] = NAIL_ROUGH


def _image(name: str, pixels: np.ndarray, data: bool) -> bpy.types.Image:
    """A packed image `name` of `pixels` (SIZE x SIZE x 3, 0..1, row 0 the bottom)."""
    img = bpy.data.images.get(name) or bpy.data.images.new(name, SIZE, SIZE, alpha=False)
    if data:
        img.colorspace_settings.name = "Non-Color"
    rgba = np.concatenate([pixels, np.ones(pixels.shape[:2] + (1,), dtype=np.float32)], axis=-1)
    img.pixels.foreach_set(rgba.astype(np.float32).ravel())
    img.file_format = "PNG"
    img.pack()
    return img


def dress(left: bpy.types.Object, right: bpy.types.Object, nails: list, nail_verts: list, fr: glove.Frame,
          material: str) -> tuple:
    """Unwraps the skin (`left`, and `right` as its mirror) and the nails (both sides' objects; `nail_verts` the
    left's vertices at rest), paints the maps from the left hand at rest and gives them to `material`. Returns where
    each texel lies on the hand (`raster`'s place, normal, thumb's share and cover) and the hand, for the glove's
    painting over the same atlas (glove_paint.py)."""
    unwrap(left, fr)
    mirror_uv(left, right)
    nail_uv(nails, nail_verts, fr)
    pos, nrm, thumb, mask = raster(left)
    hand = Hand(fr)
    height, colour, rough, hairy = (np.zeros(mask.shape + s, dtype=np.float32) for s in ((), (3,), (), ()))
    height[mask], colour[mask], rough[mask], hairy[mask] = paint(pos[mask], nrm[mask], thumb[mask], hand)
    hairs(colour, pos, mask, hairy, hand)
    colour, normal, rough = finish(height, colour, rough, pos, mask, (TONE["back"], ROUGH["back"]))
    nail_tile(colour, normal, rough)
    print("  skin: %d of %d texels on the hand (%.0f%%), about %.2f mm a texel" % (
        mask.sum(), mask.size, 100.0 * mask.sum() / mask.size,
        1000.0 * math.sqrt(sum(p.area for p in left.data.polygons) / max(int(mask.sum()), 1))))
    images = wire(material, IMAGES, colour, normal, rough, os.environ.get("BL_SKIN_OUT"))
    del images
    return pos, nrm, thumb, mask, hand


def wire(materials, names: dict, colour: np.ndarray, normal: np.ndarray, rough: np.ndarray,
         out: str = None) -> dict:
    """The painted maps as packed images named by `names` (colour, normal, rough), given to the material named
    `materials` (or each of several); saved to the folder `out` too, when given."""
    # glTF's roughness is the green channel, its metalness the blue (none here), occlusion the red (none: white).
    orm = np.stack([np.ones_like(rough), rough, np.zeros_like(rough)], axis=-1)
    images = {"colour": _image(names["colour"], colour, False), "normal": _image(names["normal"], normal, True),
              "rough": _image(names["rough"], orm, True)}
    if out:
        os.makedirs(out, exist_ok=True)
        for key, img in images.items():
            img.save(filepath=os.path.join(out, "%s.png" % names[key]))
    for material in ((materials,) if isinstance(materials, str) else materials):
        nt = bpy.data.materials[material].node_tree
        bsdf = nt.nodes["Principled BSDF"]

        def tex(img: bpy.types.Image, nt=nt) -> bpy.types.Node:
            node = nt.nodes.new("ShaderNodeTexImage")
            node.image = img
            return node

        nt.links.new(tex(images["colour"]).outputs["Color"], bsdf.inputs["Base Color"])
        bump = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(tex(images["normal"]).outputs["Color"], bump.inputs["Color"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
        split = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(tex(images["rough"]).outputs["Color"], split.inputs["Color"])
        nt.links.new(split.outputs["Green"], bsdf.inputs["Roughness"])
        nt.links.new(split.outputs["Blue"], bsdf.inputs["Metallic"])
    return images


def finish(height: np.ndarray, colour: np.ndarray, rough: np.ndarray, pos: np.ndarray, mask: np.ndarray,
           empty: tuple) -> tuple:
    """Painted maps made ready: the normal map of `height`, and each map spread past its islands' edges, the atlas's
    unused texels left `empty` (a colour and a roughness). Returns colour, normal, rough."""
    normal = normals(height, pos, mask)
    colour, rough, normal = spread(colour, mask), spread(rough, mask), spread(normal, mask)
    filled = spread(mask.astype(np.float32), mask) > 0.0
    colour[~filled] = empty[0]
    rough[~filled] = empty[1]
    normal[~filled] = (0.5, 0.5, 1.0)
    return colour, normal, rough
