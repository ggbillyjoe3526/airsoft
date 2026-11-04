"""The first-person arms (BL1, 2026-11-04): hard-knuckle tactical gloves and the sleeves of a combat shirt over a real
human arm and hand.

The anatomy is the MakeHuman base mesh's left arm (CC0 1.0; `source/makehuman_arm.obj`, cut from it by
`source/extract_arm.py`, its joint centres beside it), so the hand has a real palm, knuckles, finger pads and thumb.
Over it the build fits a glove (the hand's skin pushed out a glove's thickness, with hard knuckle and finger plates,
a palm patch and a wrist strap as raised shells) and a sleeve (a loose shell over the forearm and upper arm with folds
and a hemmed cuff). Shells sit outside the skin they follow and share its weights, so nothing passes through
anything in any pose. The right arm is the left mirrored.

Both arms hang from one armature, `Arms`, whose bones are named as the figures' skeleton names them (Shoulder_R,
UpperArm_R, Forearm_R, Hand_R, Thumb1_R..Pinky3_R, Grip_R, and the same _L), so the first-person step can share
poses with the figures. One clip, `Rifle_Hold`, holds the AEG Rifle at the `ReplicaHold` empty's place (the game's
hip hold): the shoulders bladed as a shooter stands, elbows bent and down, the right hand round the grip with its
trigger finger on the trigger, the left hand under the handguard. The fingers are closed onto the rifle by a contact
solver (each joint curls until that part of the finger meets the rifle's surface), and the build checks the posed
arms against the rifle and stops if they pass into it.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3), after the AEG:

    python -I tools/blender/arms/arms.py <repo root>

It writes assets/models/arms/arms.glb.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "replicas"))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402
from mathutils.kdtree import KDTree  # noqa: E402

import hardsurface as hs  # noqa: E402

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
OUT = os.environ.get("BL_OUT") or os.path.join(ROOT, "assets/models/arms/arms.glb")
SOURCE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "source", "makehuman_arm.obj")
RIFLE_FILE = os.environ.get("BL_RIFLE") or os.path.join(ROOT, "assets/models/replicas/aeg.glb")
FPS = 60

MATERIALS = {
    "Glove": (0x2a2c30, 0.80, 0.0), "GloveArmour": (0x3a3d43, 0.42, 0.0), "Sleeve": (0x5b6846, 0.90, 0.0),
    "SleeveTrim": (0x48523a, 0.85, 0.0),
}

# The source arm is a 1.69 m figure's: scaled to a 1.80 m adult's.
SCALE = 1.065
# The AEG Rifle's origin at the game's hip hold (ViewModelConfig.hip "aeg", Godot (0.12, -0.19, -0.26)) in the eye's
# space: +X right, +Y forward, +Z up.
RIFLE_AT = Vector((0.12, 0.26, -0.19))
# The shoulders, bladed as a right-handed shooter stands: the left one forward, the right one back.
SHOULDER = {"L": Vector((-0.140, 0.090, -0.225)), "R": Vector((0.180, -0.150, -0.200))}
# Where each elbow points (eye space): down and out.
POLE = {"L": Vector((-0.55, -0.15, -1.0)), "R": Vector((1.0, -0.10, -0.6))}

# Glove and sleeve, along the forearm from the wrist joint (m; negative up the arm).
GLOVE_THICK = 0.0010
GLOVE_TOP = -0.050
SLEEVE_END = -0.014
SLEEVE_OFF = 0.0085
SLEEVE_HEM = 0.0018
STRAP = (-0.009, 0.013)
PLATE_THICK = 0.0026
# A finger stops this far short of the rifle's surface (m): touching, never through.
CONTACT = 0.0008
FINGER_NAMES = {1: "Thumb", 2: "Index", 3: "Middle", 4: "Ring", 5: "Pinky"}
# How much of each finger's splay from the middle finger the hold takes out.
ADDUCT = {2: 0.8, 4: 0.8, 5: 0.85}


# ------------------------------------------------------------------------------------------------------ source

def load_source() -> tuple:
    """The left arm's vertices, quads and joints, turned to face +Y (the eye's forward), scaled, and moved so its
    shoulder joint sits at the left shoulder."""
    verts, faces, joints = [], [], {}
    turn = Matrix.Rotation(math.pi, 3, "Z")
    for line in open(SOURCE):
        if line.startswith("# joint"):
            _, _, name, x, y, z = line.split()
            joints[name] = turn @ Vector((float(x), float(y), float(z))) * SCALE
        elif line.startswith("v "):
            verts.append(turn @ Vector(tuple(map(float, line.split()[1:4]))) * SCALE)
        elif line.startswith("f "):
            faces.append([int(t) - 1 for t in line.split()[1:]])
    shift = SHOULDER["L"] - joints["shoulder"]
    return [v + shift for v in verts], faces, {k: v + shift for k, v in joints.items()}


def bone_points(j: dict) -> dict:
    """Head and tail of each bone of the left arm, from the joint centres."""
    pts = {
        "Shoulder": (Vector((j["shoulder"].x * 0.25, j["shoulder"].y, j["shoulder"].z + 0.02)), j["shoulder"]),
        "UpperArm": (j["shoulder"], j["elbow"]),
        "Forearm": (j["elbow"], j["hand"]),
        "Hand": (j["hand"], j["finger-3-1"]),
    }
    for f, name in FINGER_NAMES.items():
        for k in range(1, 4):
            pts["%s%d" % (name, k)] = (j["finger-%d-%d" % (f, k)], j["finger-%d-%d" % (f, k + 1)])
    return pts


PARENT = {"Shoulder": "Root", "UpperArm": "Shoulder", "Forearm": "UpperArm", "Hand": "Forearm", "Grip": "Hand"}
for _n in FINGER_NAMES.values():
    PARENT[_n + "1"] = "Hand"
    PARENT[_n + "2"] = _n + "1"
    PARENT[_n + "3"] = _n + "2"
DEFORM = ["UpperArm", "Forearm", "Hand"] + ["%s%d" % (n, k) for n in FINGER_NAMES.values() for k in (1, 2, 3)]


class Frame:
    """The left arm's reference directions at rest: the forearm's line, the back of the hand, the palm's centre."""

    def __init__(self, j: dict):
        self.wrist = j["hand"]
        self.fdir = (j["hand"] - j["elbow"]).normalized()
        knuck = [j["finger-%d-1" % f] for f in (2, 3, 4, 5)]
        n = (knuck[0] - self.wrist).cross(knuck[3] - self.wrist).normalized()
        pc = (self.wrist + sum(knuck, Vector()) / 4.0) * 0.5
        # The thumb lies on the palm's side.
        self.palmar = n if (j["finger-1-2"] - pc).dot(n) > 0.0 else -n
        self.dorsal = -self.palmar
        self.palm_centre = pc
        self.fingers = (j["finger-3-1"] - self.wrist).normalized()

    def along(self, v: Vector) -> float:
        return (v - self.wrist).dot(self.fdir)


# ------------------------------------------------------------------------------------------------------ weights

def seg_dist(p: Vector, a: Vector, b: Vector) -> float:
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(1e-12, ab.dot(ab))))
    return (p - (a + ab * t)).length


def weights(verts: list, j: dict, pts: dict) -> list:
    """Per vertex {bone: weight}: the nearest bone and its chain neighbours, by inverse distance to the fourth."""
    hand_segs = [(j["hand"], j["finger-%d-1" % f]) for f in (1, 2, 3, 4, 5)]
    children = {}
    for b in DEFORM:
        children.setdefault(PARENT[b], []).append(b)
    out = []
    for v in verts:
        d = {}
        for b in DEFORM:
            if b == "Hand":
                d[b] = min(seg_dist(v, a, c) for a, c in hand_segs)
            else:
                d[b] = seg_dist(v, *pts[b])
        best = min(d, key=d.get)
        cand = {best} | ({PARENT[best]} & set(DEFORM)) | set(children.get(best, []))
        w = {b: 1.0 / (d[b] ** 2 + 1e-7) ** 2 for b in cand}
        tot = sum(w.values())
        w = {b: x / tot for b, x in w.items() if x / tot > 0.01}
        tot = sum(w.values())
        out.append({b: x / tot for b, x in w.items()})
    return out


# ------------------------------------------------------------------------------------------------------ mesh

def subdivide(verts: list, faces: list, cuts: list) -> tuple:
    """One Catmull-Clark level of the source quads (the hand and sleeve read smooth, not faceted), then cut
    through by each plane in `cuts` ((point, normal)) so an edge made there is straight."""
    me = bpy.data.meshes.new("src")
    me.from_pydata([tuple(v) for v in verts], [], faces)
    ob = bpy.data.objects.new("src", me)
    bpy.context.scene.collection.objects.link(ob)
    m = ob.modifiers.new("sub", "SUBSURF")
    m.levels = 1
    m.render_levels = 1
    hs.apply_modifiers(ob)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    for co, no in cuts:
        geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, dist=1e-5)
    bm.verts.index_update()
    vs = [v.co.copy() for v in bm.verts]
    fs = [[v.index for v in f.verts] for f in bm.faces]
    bm.free()
    bpy.data.meshes.remove(ob.data)
    return vs, fs


def vertex_normals(verts: list, faces: list) -> list:
    n = [Vector() for _ in verts]
    for f in faces:
        p = [verts[i] for i in f]
        fn = Vector()
        for k in range(len(p)):
            fn += p[k].cross(p[(k + 1) % len(p)])
        for i in f:
            n[i] += fn
    return [x.normalized() if x.length > 0 else Vector((0, 0, 1)) for x in n]


def centre(verts: list, f: list) -> Vector:
    return sum((verts[i] for i in f), Vector()) / len(f)


class Mesh:
    """Vertices, faces, materials and per-vertex weights, appended to piece by piece."""

    def __init__(self):
        self.v, self.f, self.m, self.w = [], [], [], []

    def add(self, verts: list, faces: list, mat, wts: list) -> int:
        base = len(self.v)
        self.v += verts
        self.w += wts
        for k, f in enumerate(faces):
            self.f.append([base + i for i in f])
            self.m.append(mat[k] if isinstance(mat, list) else mat)
        return base


def open_edges(faces: list) -> list:
    """The edges used by one face only, in that face's winding."""
    count = {}
    for f in faces:
        for k in range(len(f)):
            e = (f[k], f[(k + 1) % len(f)])
            count.setdefault(tuple(sorted(e)), []).append(e)
    return [es[0] for es in count.values() if len(es) == 1]


class Surface:
    """The glove's outer surface at rest, for laying hard parts onto it: each part's vertices sit on the surface
    (found by casting onto it) and take the weights of the glove beneath them, so they move with it."""

    def __init__(self, verts: list, faces: list, wts: list):
        self.verts, self.wts = verts, wts
        self.tree = BVHTree.FromPolygons(verts, faces)
        self.kd = KDTree(len(verts))
        for i, v in enumerate(verts):
            self.kd.insert(v, i)
        self.kd.balance()

    def onto(self, p: Vector, normal: Vector) -> tuple:
        hit = self.tree.ray_cast(p + normal * 0.03, -normal, 0.08)
        if hit[0] is None:
            hit = self.tree.find_nearest(p)
        return hit[0], hit[1]

    def weight(self, p: Vector) -> dict:
        found = self.kd.find_n(p, 3)
        tot, out = 0.0, {}
        for co, i, d in found:
            k = 1.0 / (d + 1e-4)
            tot += k
            for b, w in self.wts[i].items():
                out[b] = out.get(b, 0.0) + w * k
        return {b: w / tot for b, w in out.items()}

    def solid(self, rings: list, normals: list, thick: float, mat: str, closed: bool) -> tuple:
        """A raised part from rows of surface points: a top `thick` out (its edge row half as high and drawn in, a
        soft bevel), an underside on the surface, and walls round the edge."""
        rows, cols = len(rings), len(rings[0])
        top, bottom, wts = [], [], []
        for r in range(rows):
            for c in range(cols):
                p, n = rings[r][c], normals[r][c]
                edge = r in (0, rows - 1) or (not closed and c in (0, cols - 1))
                top.append(p + n * (0.0002 + thick * (0.55 if edge else 1.0)))
                bottom.append(p + n * 0.0002)
                wts.append(self.weight(p))
        n = rows * cols
        faces = []
        cspan = cols if closed else cols - 1
        for r in range(rows - 1):
            for c in range(cspan):
                a, b = r * cols + c, r * cols + (c + 1) % cols
                faces.append([a, b, b + cols, a + cols])
                faces.append([n + a + cols, n + b + cols, n + b, n + a])
        edges = []
        for c in range(cspan):
            edges.append(((0, (c + 1) % cols), (0, c)))
            edges.append(((rows - 1, c), (rows - 1, (c + 1) % cols)))
        if not closed:
            for r in range(rows - 1):
                edges.append(((r, 0), (r + 1, 0)))
                edges.append(((r + 1, cols - 1), (r, cols - 1)))
        for (r0, c0), (r1, c1) in edges:
            a, b = r0 * cols + c0, r1 * cols + c1
            faces.append([a, b, n + b, n + a])
        return top + bottom, faces, mat, wts + wts

    def plate(self, centre: Vector, u: Vector, v: Vector, hu: float, hv: float, normal: Vector, thick: float,
              mat: str, steps: tuple = (9, 7)) -> tuple:
        """A rounded plate `2hu` by `2hv`, centred on `centre`, laid along the surface facing `normal`."""
        rings, normals = [], []
        nu, nv = steps
        for j in range(nv):
            y = -1.0 + 2.0 * j / (nv - 1)
            row, nrow = [], []
            for i in range(nu):
                x = -1.0 + 2.0 * i / (nu - 1)
                # Square to rounded square: part way to the disc mapping.
                dx, dy = x * math.sqrt(1.0 - y * y / 2.0), y * math.sqrt(1.0 - x * x / 2.0)
                px, py = x + (dx - x) * 0.45, y + (dy - y) * 0.45
                p, nn = self.onto(centre + u * (px * hu) + v * (py * hv), normal)
                row.append(p)
                nrow.append(nn)
            rings.append(row)
            normals.append(nrow)
        return self.solid(rings, normals, thick, mat, False)

    def band(self, fr: "Frame", span: tuple, thick: float, mat: str, count: int = 40) -> tuple:
        """A strap round the wrist between `span` (m along the forearm from the wrist joint), its edges straight."""
        side = fr.dorsal.cross(fr.fdir)
        rings, normals = [], []
        for t in (span[0], (span[0] + span[1]) * 0.5, span[1]):
            c = fr.wrist + fr.fdir * t
            row, nrow = [], []
            for i in range(count):
                a = 2.0 * math.pi * i / count
                d = fr.dorsal * math.cos(a) + side * math.sin(a)
                hit = self.tree.ray_cast(c + d * 0.08, -d, 0.1)
                p, nn = (hit[0], hit[1]) if hit[0] is not None else self.tree.find_nearest(c + d * 0.03)[:2]
                row.append(p)
                nrow.append((nn - fr.fdir * nn.dot(fr.fdir)).normalized())
            rings.append(row)
            normals.append(nrow)
        return self.solid(rings, normals, thick, mat, True)


def build_left() -> tuple:
    """The left arm: glove, plates, strap and sleeve, with weights; and its joints."""
    src_v, src_f, j = load_source()
    fr = Frame(j)
    verts, faces = subdivide(src_v, src_f, [(fr.wrist + fr.fdir * t, fr.fdir) for t in (SLEEVE_END, GLOVE_TOP)])
    pts = bone_points(j)
    wts = weights(verts, j, pts)
    nrm = vertex_normals(verts, faces)
    mesh = Mesh()

    # The gloved hand: the skin from a little up the forearm (hidden in the sleeve) to the fingertips.
    hand_f = [f for f in faces if fr.along(centre(verts, f)) > GLOVE_TOP]
    used = sorted({i for f in hand_f for i in f})
    idx = {o: k for k, o in enumerate(used)}
    knuck = [j["finger-%d-1" % f] for f in (2, 3, 4, 5)]

    def face_normal(f: list) -> Vector:
        return sum((nrm[i] for i in f), Vector()).normalized()

    mats = "Glove"
    mesh.add([verts[o] + nrm[o] * GLOVE_THICK for o in used], [[idx[i] for i in f] for f in hand_f], mats,
             [wts[o] for o in used])

    # Hard parts, laid onto the glove: a knuckle guard, a plate on each finger's first bone, a wrist strap.
    surf = Surface([verts[o] + nrm[o] * GLOVE_THICK for o in used], [[idx[i] for i in f] for f in hand_f],
                   [wts[o] for o in used])
    ka, kb = knuck[0], knuck[3]
    across = (kb - ka).normalized()
    mesh.add(*surf.plate((ka + kb) * 0.5 - fr.fingers * 0.004, across, fr.fingers, (kb - ka).length * 0.5 + 0.009,
                         0.0115, fr.dorsal, PLATE_THICK, "GloveArmour"))
    for f in (2, 3, 4, 5):
        a, b = j["finger-%d-1" % f], j["finger-%d-2" % f]
        d = (b - a).normalized()
        up = (fr.dorsal - d * fr.dorsal.dot(d)).normalized()
        mesh.add(*surf.plate(a.lerp(b, 0.58), d.cross(up), d, 0.0068, (b - a).length * 0.26, up,
                             PLATE_THICK * 0.7, "GloveArmour"))
    mesh.add(*surf.band(fr, STRAP, 0.0020, "GloveArmour"))
    # The palm's leather patch, and grip pads on the thumb's, index's and middle finger's tips.
    mesh.add(*surf.plate(fr.palm_centre + fr.fingers * 0.012 + fr.palmar * 0.01, across, fr.fingers, 0.024, 0.020,
                         fr.palmar, 0.0016, "GloveArmour", (11, 9)))
    for f in (1, 2, 3):
        a, b = j["finger-%d-3" % f], j["finger-%d-4" % f]
        d = (b - a).normalized()
        down = (fr.palmar - d * fr.palmar.dot(d)).normalized()
        mesh.add(*surf.plate(a.lerp(b, 0.45), d.cross(down), d, 0.0060, (b - a).length * 0.36, down, 0.0011,
                             "GloveArmour", (7, 6)))

    # The sleeve: a loose shell over the forearm and upper arm, folded, its cuff hemmed and banded.
    sleeve_f = [f for f in faces if fr.along(centre(verts, f)) < SLEEVE_END]
    sv = list(verts)
    cuff_edges = [e for e in open_edges(sleeve_f) if all(abs(fr.along(sv[i]) - SLEEVE_END) < 0.001 for i in e)]
    snrm = vertex_normals(sv, sleeve_f)
    elbow_t = fr.along(j["elbow"])
    side_ref = fr.dorsal.cross(fr.fdir)

    def folds(p: Vector) -> float:
        t = fr.along(p)
        radial = p - fr.wrist - fr.fdir * t
        ang = math.atan2(radial.dot(fr.dorsal), radial.dot(side_ref))
        bunch = math.exp(-((t - SLEEVE_END + 0.03) / 0.035) ** 2) + 0.8 * math.exp(-((t - elbow_t) / 0.06) ** 2)
        wave = math.sin(t / 0.019 * 2.0 * math.pi + 1.7 * math.sin(2.0 * ang) + 0.6 * math.sin(3.0 * ang + 1.0))
        slack = 0.0022 * (1.0 + 0.6 * math.sin(ang * 2.0 + t * 40.0))
        return slack + 0.0024 * (0.35 + bunch) * wave

    used = sorted({i for f in sleeve_f for i in f})
    idx = {o: k for k, o in enumerate(used)}
    smats = ["SleeveTrim" if fr.along(centre(sv, f)) > SLEEVE_END - 0.032 else "Sleeve" for f in sleeve_f]
    outer = [sv[o] + snrm[o] * (SLEEVE_OFF + folds(sv[o])) for o in used]
    base = mesh.add(outer, [[idx[i] for i in f] for f in sleeve_f], smats, [wts[o] for o in used])
    # The hem: the cuff's open edge turned in towards the glove.
    hem = {}
    for a, b in cuff_edges:
        for i in (a, b):
            if i not in hem:
                p = sv[i] + snrm[i] * (SLEEVE_OFF + folds(sv[i]) - SLEEVE_HEM) - fr.fdir * 0.0012
                hem[i] = mesh.add([p], [], "SleeveTrim", [wts[i]])
        mesh.f.append([base + idx[b], base + idx[a], hem[a], hem[b]])
        mesh.m.append("SleeveTrim")
    return mesh, j, fr, pts


# ------------------------------------------------------------------------------------------------------ rig

def mirror_x(v: Vector) -> Vector:
    return Vector((-v.x, v.y, v.z))


def to_side(side: str):
    """Maps the left arm's points to `side`'s: the right arm is the left mirrored and moved to its own shoulder."""
    if side == "L":
        return lambda v: v
    off = SHOULDER["R"] - mirror_x(SHOULDER["L"])
    return lambda v: mirror_x(v) + off


def dir_side(side: str):
    return (lambda v: v) if side == "L" else mirror_x


def armature(pts: dict, fr: Frame) -> bpy.types.Object:
    data = bpy.data.armatures.new("Arms")
    arm = bpy.data.objects.new("Arms", data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    root = data.edit_bones.new("Root")
    root.head, root.tail = (0.0, 0.0, 0.0), (0.0, 0.05, 0.0)
    for side in ("L", "R"):
        sx, dx = to_side(side), dir_side(side)
        dors = dx(fr.dorsal)
        for name, (h, t) in pts.items():
            eb = data.edit_bones.new("%s_%s" % (name, side))
            eb.head, eb.tail = sx(h), sx(t)
            eb.align_roll(dors if name not in ("Shoulder", "UpperArm", "Forearm") else Vector((0.0, 0.0, 1.0)))
        for name in pts:
            eb = data.edit_bones["%s_%s" % (name, side)]
            eb.parent = data.edit_bones[PARENT[name] + ("_" + side if PARENT[name] != "Root" else "")]
        g = data.edit_bones.new("Grip_" + side)
        pc = sx(fr.palm_centre + fr.palmar * 0.02)
        g.head, g.tail = pc, pc + dx(fr.fingers) * 0.03
        g.align_roll(dors)
        g.parent = data.edit_bones["Hand_" + side]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def skin_object(name: str, mesh: Mesh, arm: bpy.types.Object, side: str) -> bpy.types.Object:
    sx = to_side(side)
    verts = [sx(v) for v in mesh.v]
    faces = mesh.f if side == "L" else [list(reversed(f)) for f in mesh.f]
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    names = list(MATERIALS)
    for n in names:
        me.materials.append(bpy.data.materials[n])
    for p, m in zip(me.polygons, mesh.m):
        p.material_index = names.index(m)
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    groups = {}
    for i, w in enumerate(mesh.w):
        for b, x in w.items():
            gname = "%s_%s" % (b, side)
            if gname not in groups:
                groups[gname] = ob.vertex_groups.new(name=gname)
            groups[gname].add([i], x, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Arms", "ARMATURE")
    mod.object = arm
    return ob


# ------------------------------------------------------------------------------------------------------ pose

def rot_between(a: Vector, b: Vector) -> Matrix:
    return a.normalized().rotation_difference(b.normalized()).to_matrix()


def basis(f: Vector, n: Vector) -> Matrix:
    """A rotation whose columns are the fingers' direction, the palm's normal and their cross."""
    f = f.normalized()
    n = (n - f * n.dot(f)).normalized()
    return Matrix((f, n, f.cross(n))).transposed()


class Rig:
    """Rest matrices and the pose being built, in the armature's (eye) space."""

    def __init__(self, arm: bpy.types.Object):
        self.arm = arm
        self.rest = {b.name: b.matrix_local.copy() for b in arm.data.bones}
        self.length = {b.name: b.length for b in arm.data.bones}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
        self.children = {b.name: [c.name for c in b.children] for b in arm.data.bones}
        self.pose = dict(self.rest)
        self.local = {}

    def fk(self, name: str, local_rot: Matrix = None) -> Matrix:
        """Poses a bone from its parent's pose, turned by `local_rot` in its own frame."""
        p = self.parent[name]
        self.local[name] = local_rot.copy() if local_rot is not None else Matrix.Identity(3)
        m = self.pose[p] @ self.rest[p].inverted() @ self.rest[name] @ self.local[name].to_4x4()
        self.pose[name] = m
        return m

    def refresh(self, name: str) -> None:
        """Re-poses everything below `name` with the turns it already has."""
        for c in self.children[name]:
            self.fk(c, self.local.get(c))
            self.refresh(c)

    def write(self) -> None:
        for pb in self.arm.pose.bones:
            pb.matrix_basis = self.basis_of(pb.name)
        bpy.context.view_layer.update()

    def basis_of(self, name: str) -> Matrix:
        p = self.parent[name]
        if p is None:
            return self.rest[name].inverted() @ self.pose[name]
        rel = self.rest[p].inverted() @ self.rest[name]
        return rel.inverted() @ self.pose[p].inverted() @ self.pose[name]


class Collider:
    def __init__(self, objects: list):
        verts, polys = [], []
        for ob in objects:
            base = len(verts)
            mw = ob.matrix_world
            verts += [mw @ v.co for v in ob.data.vertices]
            polys += [[base + i for i in p.vertices] for p in ob.data.polygons]
        self.tree = BVHTree.FromPolygons(verts, polys)

    def dist(self, p: Vector) -> float:
        """Distance to the rifle's surface; negative inside it."""
        hit = self.tree.find_nearest(p)
        if hit[0] is None:
            return 9.0
        return hit[3] if (p - hit[0]).dot(hit[1]) >= 0.0 else -hit[3]


class Hand:
    """One side's hand at rest: palm points in the hand bone's rest space, finger capsules and bend axes."""

    def __init__(self, side: str, rig: Rig, mesh: Mesh, fr: Frame, j: dict):
        self.side = side
        sx, dx = to_side(side), dir_side(side)
        self.rig = rig
        self.palmar = dx(fr.palmar)
        self.fingers = dx(fr.fingers)
        self.palm_centre = sx(fr.palm_centre)
        hand_rest = rig.rest["Hand_" + side]
        self.palm = [hand_rest.inverted() @ sx(v) for v, w in zip(mesh.v, mesh.w) if w.get("Hand", 0.0) > 0.6]
        self.palm = [p for k, p in enumerate(self.palm) if k % max(1, len(self.palm) // 800) == 0]
        self.radius, self.axis, self.adduct, self.points = {}, {}, {}, {}
        mid = (sx(j["finger-3-2"]) - sx(j["finger-3-1"])).normalized()
        for f, name in FINGER_NAMES.items():
            for k in (1, 2, 3):
                b = "%s%d_%s" % (name, k, side)
                h, t = sx(j["finger-%d-%d" % (f, k)]), sx(j["finger-%d-%d" % (f, k + 1)])
                ds = sorted(seg_dist(sx(v), h, t) for v, w in zip(mesh.v, mesh.w)
                            if w.get("%s%d" % (name, k), 0.0) > 0.7)
                self.radius[b] = (ds[int(len(ds) * 0.85)] if ds else 0.008) + 0.0004
                inv = rig.rest[b].inverted()
                pts = [inv @ sx(v) for v, w in zip(mesh.v, mesh.w) if w.get("%s%d" % (name, k), 0.0) > 0.45]
                self.points[b] = [q for i, q in enumerate(pts) if i % max(1, len(pts) // 90) == 0]
                toward = self.palmar if f != 1 else ((self.palm_centre + self.palmar * 0.02) - h).normalized()
                ax = (t - h).normalized().cross(toward).normalized()
                self.axis[b] = rig.rest[b].to_3x3().inverted() @ ax
                if k == 1 and f in ADDUCT:
                    # The rest hand is splayed: each first bone turns part way toward the middle finger's line.
                    d = (t - h).normalized()
                    add = d.cross(mid)
                    angle = math.asin(min(1.0, add.length)) * ADDUCT[f]
                    self.adduct[b] = Matrix.Rotation(angle, 3, rig.rest[b].to_3x3().inverted() @ add.normalized())

    def place(self, at: Vector, fingers: Vector, palm_normal: Vector, forward: float = 0.0,
              depth: float = 0.0) -> Matrix:
        """The hand bone's pose with the point `forward` m toward the knuckles and `depth` m out of the palm from the
        palm's centre at `at`, the fingers toward `fingers` and the palm facing `palm_normal`. A grip held in the
        hand has its axis there: across the palm near the knuckles, a grip's half-depth out from the palm."""
        r = basis(fingers, palm_normal) @ basis(self.fingers, self.palmar).transposed()
        ref = self.palm_centre + self.fingers * forward + self.palmar * depth
        m = Matrix.Translation(at) @ r.to_4x4() @ Matrix.Translation(-ref)
        return m @ self.rig.rest["Hand_" + self.side]

    def gap(self, hand_m: Matrix, col: Collider) -> float:
        return min(col.dist(hand_m @ p) for p in self.palm)

    def seat(self, hand_m: Matrix, toward: Vector, col: Collider) -> Matrix:
        """Slides the hand along `toward` until the palm rests on the rifle without passing into it."""
        d = toward.normalized()
        for _ in range(100):
            if self.gap(hand_m, col) >= 0.0002:
                break
            hand_m = Matrix.Translation(-d * 0.0004) @ hand_m
        for _ in range(100):
            g = self.gap(hand_m, col)
            if g < 0.0008:
                break
            hand_m = Matrix.Translation(d * min(0.0004, g * 0.5)) @ hand_m
        return hand_m

    def clearance(self, b: str, col: Collider) -> float:
        """How far the bone's own glove surface is from the rifle (negative: inside it)."""
        m = self.rig.pose[b]
        return min(col.dist(m @ q) for q in self.points[b])

    def touches(self, b: str, col: Collider) -> bool:
        return self.clearance(b, col) < CONTACT

    def thumb(self, col: Collider, ratio: tuple, limit: tuple) -> list:
        """Swings the thumb at its base (across the palm, round its own line and in its bend) to the clear place
        nearest the rifle, then curls its tip bones onto it."""
        b1, b2, b3 = ("Thumb%d_%s" % (k, self.side) for k in (1, 2, 3))
        inv = self.rig.rest[b1].to_3x3().inverted()
        across = inv @ self.palmar
        twist = Vector((0.0, 1.0, 0.0))
        best = None
        for a in range(-50, 55, 10):
            for c in range(-80, 85, 10):
                for t in (-30, 0, 30):
                    rot = (Matrix.Rotation(math.radians(c), 3, across) @ Matrix.Rotation(math.radians(t), 3, twist)
                           @ Matrix.Rotation(math.radians(a), 3, self.axis[b1]))
                    self.rig.fk(b1, rot)
                    self.rig.fk(b2)
                    self.rig.fk(b3)
                    clear = min(self.clearance(b, col) for b in (b1, b2, b3))
                    # Clear of the rifle first; then as close to it as can be, with the least swing.
                    score = (0.0 if clear >= CONTACT else 1.0 + (CONTACT - clear)) + clear * 2.0 + \
                        0.0003 * (abs(a) + abs(c) + abs(t)) / 10.0
                    if best is None or score < best[0]:
                        best = (score, rot, a, c, t)
        self.adduct[b1] = best[1]
        out = self.close("Thumb", col, (0.0, ratio[1], ratio[2]), (0.0, limit[1], limit[2]))
        return list(best[2:]) + out[1:]

    def onto(self, name: str, target: Vector, col: Collider, limits: tuple) -> list:
        """Bends a finger so its last bone's pad comes to `target` (the trigger) without passing into the rifle."""
        bones = ["%s%d_%s" % (name, k, self.side) for k in (1, 2, 3)]
        best = None
        for a1 in range(-10, limits[0] + 1, 5):
            for a2 in range(0, limits[1] + 1, 5):
                for a3 in range(0, limits[2] + 1, 5):
                    for k, ang in enumerate((a1, a2, a3)):
                        rot = Matrix.Rotation(math.radians(ang), 3, self.axis[bones[k]])
                        self.rig.fk(bones[k], self.adduct[bones[k]] @ rot if bones[k] in self.adduct else rot)
                    if any(self.touches(b, col) for b in bones):
                        continue
                    m = self.rig.pose[bones[2]]
                    pad = min((m @ q - target).length for q in self.points[bones[2]])
                    if best is None or pad < best[0]:
                        best = (pad, (a1, a2, a3))
        for k, ang in enumerate(best[1]):
            rot = Matrix.Rotation(math.radians(ang), 3, self.axis[bones[k]])
            self.rig.fk(bones[k], self.adduct[bones[k]] @ rot if bones[k] in self.adduct else rot)
        return list(best[1])

    def close(self, name: str, col: Collider, ratio: tuple, limit: tuple) -> list:
        """Curls one finger joint by joint until each part meets the rifle (or reaches its limit)."""
        bones = ["%s%d_%s" % (name, k, self.side) for k in (1, 2, 3)]
        ang = [0.0, 0.0, 0.0]
        frozen = [False, False, False]
        step = math.radians(1.0)

        def apply() -> None:
            for k, b in enumerate(bones):
                rot = Matrix.Rotation(ang[k], 3, self.axis[b])
                self.rig.fk(b, self.adduct[b] @ rot if b in self.adduct else rot)

        apply()
        # Opened out first if the relaxed hand already meets the rifle.
        while any(self.touches(b, col) for b in bones) and ang[0] > math.radians(-40.0):
            ang = [ang[0] - math.radians(2.0), max(ang[1] - math.radians(2.0), math.radians(-10.0)),
                   max(ang[2] - math.radians(2.0), math.radians(-5.0))]
            apply()
        for _ in range(200):
            moved = False
            for k in range(3):
                if frozen[k]:
                    continue
                old = ang[k]
                ang[k] = min(limit[k], ang[k] + step * ratio[k])
                apply()
                if any(self.touches(b, col) for b in bones[k:]):
                    ang[k] = old
                    apply()
                    for q in range(k + 1):
                        frozen[q] = True
                elif ang[k] >= limit[k]:
                    frozen[k] = True
                else:
                    moved = True
            if not moved:
                break
        return [round(math.degrees(a)) for a in ang]


def two_bone(s: Vector, w: Vector, a: float, b: float, pole: Vector) -> Vector:
    d = w - s
    dist = min(d.length, (a + b) * 0.999)
    d.normalize()
    cos_a = (a * a + dist * dist - b * b) / (2.0 * a * dist)
    ang = math.acos(max(-1.0, min(1.0, cos_a)))
    u = (pole - d * pole.dot(d)).normalized()
    return s + (d * math.cos(ang) + u * math.sin(ang)) * a


def place_arm(rig: Rig, side: str, hand_m: Matrix, pole: Vector, quiet: bool = False) -> None:
    """Upper arm and forearm reach the wrist; the forearm turns with the hand so the wrist never twists."""
    up, fo, hn = "UpperArm_" + side, "Forearm_" + side, "Hand_" + side
    rig.fk("Shoulder_" + side)
    s = rig.pose[up].translation
    a = (rig.rest[fo].translation - rig.rest[up].translation).length
    b = (rig.rest[hn].translation - rig.rest[fo].translation).length
    w = hand_m.translation
    if not quiet:
        print("  %s arm: reach %.3f of %.3f" % (side, (w - s).length, a + b))
    e = two_bone(s, w, a, b, pole)
    r_up = rot_between(rig.rest[up].to_3x3().col[1], e - s) @ rig.rest[up].to_3x3()
    rig.pose[up] = Matrix.Translation(s) @ r_up.to_4x4()
    straight = hand_m.to_3x3() @ rig.rest[hn].to_3x3().inverted() @ rig.rest[fo].to_3x3()
    r_fo = rot_between(straight.col[1], w - e) @ straight
    rig.pose[fo] = Matrix.Translation(e) @ r_fo.to_4x4()
    rig.pose[hn] = hand_m


def rifle_objects() -> list:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=RIFLE_FILE)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.parent is None:
            o.matrix_world = Matrix.Translation(RIFLE_AT) @ o.matrix_world
    bpy.context.view_layer.update()
    return new


def hold(rig: Rig, hands: dict, col: Collider) -> None:
    """The AEG Rifle's hip hold. Rifle-space points and directions are moved to the hip by RIFLE_AT."""
    def rp(x: float, y: float, z: float) -> Vector:
        return RIFLE_AT + Vector((x, y, z))

    def rd(x: float, y: float, z: float) -> Vector:
        return Vector((x, y, z)).normalized()

    # Right hand round the pistol grip (raked 22 degrees): the grip's axis across the palm near the knuckles, the
    # index finger's side up under the receiver, the back of the hand to the right and turned a little forward.
    rake = math.radians(22.0)
    g_down = rd(0.0, -math.sin(rake), -math.cos(rake))
    g_fwd = rd(0.0, math.cos(rake), -math.sin(rake))
    grip_c = rp(0.0, -0.050, -0.016) + g_down * 0.046 - g_fwd * 0.002
    hr = hands["R"]
    turn = math.radians(22.0)
    palm_n = (rd(-1.0, 0.0, 0.0) * math.cos(turn) + g_fwd * math.sin(turn)).normalized()
    fingers = palm_n.cross(-g_down).normalized()
    hand_m = hr.place(grip_c, fingers, palm_n, 0.030, 0.031)
    hand_m = hr.seat(hand_m, palm_n, col)
    hr.normal = palm_n
    place_arm(rig, "R", hand_m, POLE["R"])
    curls = {}
    for name in ("Middle", "Ring", "Pinky"):
        curls[name + "_R"] = hr.close(name, col, (1.0, 1.0, 0.8), (math.radians(95), math.radians(105),
                                                                   math.radians(80)))
    curls["Index_R"] = hr.onto("Index", rp(0.0, 0.0090, -0.040), col, (50, 80, 50))
    curls["Thumb_R"] = hr.thumb(col, (0.5, 1.0, 0.8), (math.radians(30), math.radians(45), math.radians(40)))

    # Left hand under the handguard, palm up, fingers round its right side, thumb along its left.
    hl = hands["L"]
    guard_c = rp(0.0, 0.190, 0.036)
    tilt = math.radians(18.0)
    palm_n = (rd(0.0, 0.0, 1.0) * math.cos(tilt) + rd(1.0, 0.0, 0.0) * math.sin(tilt)).normalized()
    fingers = (rd(1.0, 0.0, 0.0) * math.cos(tilt) - rd(0.0, 0.0, 1.0) * math.sin(tilt)).normalized()
    hand_m = hl.place(guard_c, fingers, palm_n, 0.024, 0.041)
    hand_m = hl.seat(hand_m, palm_n, col)
    hl.normal = palm_n
    place_arm(rig, "L", hand_m, POLE["L"])
    for name in ("Index", "Middle", "Ring", "Pinky"):
        curls[name + "_L"] = hl.close(name, col, (1.0, 1.0, 0.8), (math.radians(90), math.radians(100),
                                                                   math.radians(75)))
    curls["Thumb_L"] = hl.thumb(col, (0.6, 1.0, 0.7), (math.radians(25), math.radians(35), math.radians(30)))
    for side in ("L", "R"):
        rig.fk("Grip_" + side)
    print("  curls (degrees):", curls)


def key_pose(rig: Rig, clip: str) -> None:
    arm = rig.arm
    arm.animation_data_create()
    act = bpy.data.actions.new(clip)
    arm.animation_data.action = act
    for frame in (0, 1):
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
            loc, rot, _ = rig.basis_of(pb.name).decompose()
            pb.location, pb.rotation_quaternion, pb.scale = loc, rot, (1.0, 1.0, 1.0)
            for path in ("location", "rotation_quaternion", "scale"):
                pb.keyframe_insert(path, frame=frame)
    arm.animation_data.action = None
    track = arm.animation_data.nla_tracks.new()
    track.name = clip
    track.strips.new(clip, 0, act)


def clipping(objects: list, solid: list) -> tuple:
    """Pairs of faces where the posed arms pass into the rifle, and how many of them each bone's skin has."""
    dg = bpy.context.evaluated_depsgraph_get()
    verts, polys = [], []
    for ob in objects:
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        base = len(verts)
        verts += [ob.matrix_world @ v.co for v in me.vertices]
        polys += [[base + i for i in p.vertices] for p in me.polygons]
        ev.to_mesh_clear()
    arms = BVHTree.FromPolygons(verts, polys)
    col = Collider(solid)
    pairs = col.tree.overlap(arms)
    tally = {}
    if pairs:
        names = [(ob, len(ob.data.vertices)) for ob in objects]
        for _, fi in pairs:
            vi = polys[fi][0]
            for ob, n in names:
                if vi < n:
                    g = max(ob.data.vertices[vi].groups, key=lambda x: x.weight, default=None)
                    key = ob.vertex_groups[g.group].name if g else "?"
                    tally[key] = tally.get(key, 0) + 1
                    break
                vi -= n
    return len(pairs), tally


def relax(rig: Rig, hands: dict, objects: list, solid: list) -> int:
    """Settles the hold on the skinned surface itself: a finger still touching the rifle opens a little at that
    joint, a palm still pressing in eases back; until nothing passes into the rifle."""
    hits = 0
    for _ in range(60):
        rig.write()
        hits, tally = clipping(objects, solid)
        if not hits:
            break
        moved = set()
        for bone in tally:
            name, side = bone.rsplit("_", 1)
            if name in ("Hand", "Forearm", "UpperArm"):
                if side in moved:
                    continue
                moved.add(side)
                h = hands[side]
                m = Matrix.Translation(-h.normal * 0.0004) @ rig.pose["Hand_" + side]
                place_arm(rig, side, m, POLE[side], quiet=True)
                rig.refresh("Hand_" + side)
            elif bone in hands[side].axis:
                turn = Matrix.Rotation(math.radians(-1.5), 3, hands[side].axis[bone])
                rig.fk(bone, rig.local[bone] @ turn)
                rig.refresh(bone)
    return hits


# ------------------------------------------------------------------------------------------------------ main

def build(keep_rifle: bool = False) -> tuple:
    hs.reset(FPS)
    for name, (colour, rough, metal) in MATERIALS.items():
        hs.material(name, colour, rough, metal)
    mesh, j, fr, pts = build_left()
    arm = armature(pts, fr)
    left = skin_object("Arm_L", mesh, arm, "L")
    right = skin_object("Arm_R", mesh, arm, "R")
    rig = Rig(arm)
    rig.fk("Shoulder_L")
    rig.fk("Shoulder_R")
    hands = {s: Hand(s, rig, mesh, fr, j) for s in ("L", "R")}
    rifle = rifle_objects()
    solid = [o for o in rifle if o.type == "MESH" and o.name not in ("Figure", "Icosphere")]
    hold(rig, hands, Collider(solid))
    hits = relax(rig, hands, [left, right], solid)
    print("  clipping face pairs after settling:", hits)
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    key_pose(rig, "Rifle_Hold")
    bpy.context.scene.frame_set(0)
    hits, tally = clipping([left, right], solid)
    print("  clipping face pairs:", hits, sorted(tally.items(), key=lambda x: -x[1]))
    hs.empty("ReplicaHold", tuple(RIFLE_AT), arm)
    print("  arms: %d triangles" % (hs.tris(left) + hs.tris(right)))
    if keep_rifle:
        return arm, rifle, hits
    for o in rifle:
        bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        if a.name != "Rifle_Hold":
            bpy.data.actions.remove(a)
    if hits:
        raise SystemExit("the posed arms pass into the rifle (%d face pairs)" % hits)
    hs.export(OUT, True)
    print("wrote", OUT)
    return arm, [], hits


if __name__ == "__main__":
    build()
