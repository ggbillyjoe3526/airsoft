"""The first-person arms' left arm at rest (BL4): a hard-knuckle tactical glove and a combat shirt's sleeve over the
MakeHuman base mesh's arm and hand (CC0 1.0, `source/makehuman_arm.obj`), with per-vertex bone weights. The right arm
is this one mirrored (arms.py).

The glove is the hand's skin pushed out a glove's thickness. On it, as raised shells laid onto its surface, sit the
parts of the owner's reference gloves (ref_images/hands/gloves, 123404 most): one smooth moulded knuckle shell with a
raised border, a small oval pad on the back of each finger's first bone and one on the thumb's, a rounded suede palm
patch, a neoprene cuff and its hook-and-loop strap with a pull tab; the fingertips plain. A shell takes the weights
of the glove beneath it (the knuckle shell only its bone's, so it stays rigid). The sleeve is a loose shell over the
forearm and upper arm with a few soft folds (bunched over the cuff, gathered in the crook of the elbow), a banded,
hemmed cuff and its tab; it follows the forearm and upper arm only, never the wrist's turn.
"""

import math
import os

import bpy
import bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

SOURCE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "source", "makehuman_arm.obj")

# The source arm is a 1.69 m figure's: scaled to a 1.80 m adult's.
SCALE = 1.065
FINGER_NAMES = {1: "Thumb", 2: "Index", 3: "Middle", 4: "Ring", 5: "Pinky"}

# The glove over the skin (m), and where it ends up the forearm (m from the wrist joint; negative up the arm).
GLOVE_THICK = 0.0011
GLOVE_TOP = -0.062
# The neoprene cuff (from, to, thickness) and its strap round it (from, to, thickness) up the forearm.
CUFF = (-0.006, -0.052, 0.0026)
STRAP = (-0.016, -0.044, 0.0016)
# The sleeve: where its cuff ends, how far it stands off the skin at the cuff and at the shoulder, its banded cuff's
# width and its hem.
SLEEVE_END = -0.040
# The wrist, fuller than the source arm's (HA1, the owner: "too thin at the wrist"; it is 50 mm across there, a man's
# about 60): the shares it is widened across and thickened through, whole from WRIST_SPAN's second mark to its third
# (m along the forearm from the wrist joint) and eased out to nothing at the first, up the forearm, and the last, in
# the heel of the hand. The sleeve's cuff sits closer to it (SLEEVE_OFF), so hand, wrist and sleeve run on evenly.
# His fourth look, of a fifth wider and an eighth thicker with the cuff 10.5 mm off: "Wrists are slightly too thick
# holding rifles": half of that taken back, the cuff 9.2 mm off.
WRIST_FULL = (0.10, 0.065)
WRIST_SPAN = (-0.150, -0.060, -0.004, 0.026)
# The hand against the owner's photo of one (HA1, the critic: hand_ratios.py measures both from the back). The
# source hand's little finger was a sixth short beside its middle finger: it is this much longer from its knuckle.
# Its fingers were a tenth slim against the palm's width: every finger this much fuller (m, on top of the glove's
# thickness). And the bare wrist read 14 % narrow against the palm: the skin-only arms' wrist is this much wider and
# thicker again (shares, over WRIST_SPAN), which the gloved arm's is not (the owner's fourth look, above, was of the
# gloved wrist).
# And the hand was a tenth short for its width: it is this much narrower across the knuckles, about the middle
# finger's line, eased in over HAND_NARROW_SPAN (m beyond the wrist joint) so the wrist stays as it is.
PINKY_LONGER = 1.12
FINGER_FULL = 0.00035
SKIN_WRIST_FULL = (0.08, 0.05)
HAND_NARROW = 0.965
HAND_NARROW_SPAN = 0.030
# The bare thumb's section (the critic: "thick, even tubes"): this much slimmer about its bone at the middle of its
# first bone, and at its tip, with nothing taken at the knuckle between them (shares of its thickness). The glove's
# thumb keeps its fuller, even section (THUMB_FULL).
THUMB_TAPER = (0.07, 0.16)
# How much of the upper arm the model keeps above the elbow (m): the view never shows the shoulder, and a moved
# shoulder tore the sleeve's top.
UPPER_KEEP = 0.13
SLEEVE_OFF = (0.0055, 0.0092)
SLEEVE_BAND = 0.030
SLEEVE_HEM = 0.0022
SLEEVE_NORMAL_SMOOTH = 4
# The hard parts' heights over the glove (m).
SHELL_THICK = 0.0016
KNUCKLE_DOME = 0.0024
KNUCKLE_RIM = 0.0012
KNUCKLE_ROUND = 0.75
KNUCKLE_LOBE = 0.0015
KNUCKLE_SEAM = 0.0008
KNUCKLE_U = (-0.75, -0.25, 0.25, 0.75)
PAD_THICK = 0.0012
# How far the muscle between thumb and index stands out under the glove (m).
WEB_BULGE = 0.0040
WEB_RADIUS = 0.017
WEB_TOWARD_INDEX = 0.65
# (easing past its ends, height) of the thumb's bone ridge and the index bone's edge; per joint (middle, last) the
# back's rise; the palm-side crease (half width along the finger, depth); how far from a joint's centre its skin lies.
THUMB_BONE = (0.010, 0.0018)
INDEX_BONE = (0.010, 0.0012)
JOINT_BUMP = ((0.0055, 0.0020), (0.0045, 0.0014))
JOINT_CREASE = (0.0018, 0.0015)
JOINT_REACH = 0.013
THUMB_FULL = 0.0008
# The finger plates bend with the glove beneath them (rigid on one bone, the skin rose through their ends as the joints
# beside them closed).
PAD_RIGID = False
# The knuckle shell: how far it reaches beyond the outer knuckles, back from them over the hand and on over them (m).
KNUCKLE_SPAN = 0.006
KNUCKLE_BACK = 0.050
KNUCKLE_OVER = 0.002
# The finger pads, as shares of each finger's first bone from its root (an oval just short of the middle knuckle), and
# how far round the finger each reaches (degrees either side of its back).
PAD_SPAN = (0.56, 0.84)
PAD_WRAP = 34.0
# The fingernails (skin-only arms): shares of each finger's last bone from its root, how far round the finger each
# reaches (degrees either side of its back), its thickness (m) and its grid (rows along, columns across).
NAIL_SPAN = (0.42, 0.98)
NAIL_WRAP = 38.0
# The thumb's nail is the largest: it starts nearer the knuckle and reaches further round.
THUMB_NAIL_SPAN = (0.36, 0.98)
THUMB_NAIL_WRAP = 50.0
NAIL_THICK = 0.0004
# Its edge's thickness and how far the whole plate stands off the skin (m); and its root, which grows out of the skin:
# the share of its thickness there, and how far along it (of its -1..1) it reaches its full thickness. A plate as thick
# at its root as at its middle left a step in the thumb's outline where it began.
NAIL_EDGE = 0.00005
NAIL_LIFT = 0.0001
NAIL_ROOT = (0.15, 0.8)
NAIL_GRID = (7, 7)
# How much narrower a nail is at its root and at its tip than across its middle (shares of its width).
NAIL_ROUND = (0.30, 0.16)
# The nails wear the skin's material: their tile of its maps (skin.py).
NAIL_MATERIAL = "Skin"


def load_source(shoulder: Vector) -> tuple:
    """The left arm's vertices, quads and joints, turned to face +Y (the eye's forward), scaled, and moved so its
    shoulder joint sits at `shoulder`."""
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
    shift = shoulder - joints["shoulder"]
    return [v + shift for v in verts], faces, {k: v + shift for k, v in joints.items()}


def lengthen(verts: list, joints: dict, finger: int, by: float) -> tuple:
    """`verts` and `joints` with finger `finger` (1 the thumb to 5 the little finger) `by` times as long from its
    knuckle: each of its points moved along the finger's line by its distance from the knuckle, so the knuckle and
    the palm stay where they are."""
    root = joints["finger-%d-1" % finger]
    line = (joints["finger-%d-4" % finger] - root).normalized()
    segs = {f: [(joints["finger-%d-%d" % (f, k)], joints["finger-%d-%d" % (f, k + 1)]) for k in (1, 2, 3)]
            for f in FINGER_NAMES}
    palm = [(joints["hand"], joints["finger-%d-1" % f]) for f in FINGER_NAMES]

    def moved(v: Vector) -> Vector:
        t = (v - root).dot(line)
        return v + line * (t * (by - 1.0)) if t > 0.0 else v

    out = []
    for v in verts:
        mine = min(seg_dist(v, a, b) for a, b in segs[finger])
        others = min(min(seg_dist(v, a, b) for f in FINGER_NAMES if f != finger for a, b in segs[f]),
                     min(seg_dist(v, a, b) for a, b in palm))
        out.append(moved(v) if mine < others else v)
    grown = dict(joints)
    for k in (2, 3, 4):
        grown["finger-%d-%d" % (finger, k)] = moved(joints["finger-%d-%d" % (finger, k)])
    return out, grown


def narrow(verts: list, joints: dict, by: float) -> tuple:
    """`verts` and `joints` with the hand `by` times as wide across its knuckles, about the line from the wrist to
    the middle finger's knuckle: nothing at the wrist, all of it from HAND_NARROW_SPAN beyond."""
    wrist = joints["hand"]
    line = (joints["finger-3-1"] - wrist).normalized()
    across = joints["finger-2-1"] - joints["finger-5-1"]
    across = (across - line * across.dot(line)).normalized()

    def moved(v: Vector) -> Vector:
        t = max(0.0, min(1.0, (v - wrist).dot(line) / HAND_NARROW_SPAN))
        return v - across * ((v - wrist).dot(across) * (1.0 - by) * t * t * (3.0 - 2.0 * t))

    out = dict(joints)
    for name in joints:
        if name.startswith("finger-"):
            out[name] = moved(joints[name])
    return [moved(v) for v in verts], out


def thumb_taper(verts: list, joints: dict, wts: list) -> list:
    """`verts` (weights `wts`) with the thumb waisted along its first bone and tapered from its knuckle to its tip
    (THUMB_TAPER), each point drawn toward the bone it lies beside by the thumb's share of it."""
    a, b, c = joints["finger-1-2"], joints["finger-1-3"], joints["finger-1-4"]
    out = []
    for v, w in zip(verts, wts):
        share = w.get("Thumb2", 0.0) + w.get("Thumb3", 0.0)
        past = (v - b).dot(c - b) / (c - b).length_squared
        if share <= 0.0:
            out.append(v)
        elif past > 0.0:
            t = min(past, 1.0)
            out.append(v - (v - (b + (c - b) * t)) * (THUMB_TAPER[1] * t * t * (3.0 - 2.0 * t) * share))
        else:
            t = max(0.0, min(1.0, (v - a).dot(b - a) / (b - a).length_squared))
            out.append(v - (v - (a + (b - a) * t)) * (THUMB_TAPER[0] * math.sin(math.pi * t) * share))
    return out


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
    pts[HEEL] = pts["Thumb1"]
    return pts


# The heel of the thumb (HA1, the owner: "the wrist to thumb joint doesn't look natural"): a bone lying where the
# thumb's first bone does, which swings with it but turns about its own line only HEEL_TWIST of what that bone does
# (pose.Rig keeps it so). The skin along the thumb's first bone goes over from it to that bone between HEEL_SPAN
# (shares of the bone's length), so a thumb turned far round onto a grip winds its skin gradually from the wrist to
# its knuckle, as a hand's does, where it was wrung round in one place and lost its fullness there.
HEEL = "Heel"
HEEL_TWIST = 0.5
HEEL_SPAN = (0.10, 0.95)
PARENT = {"Shoulder": "Root", "UpperArm": "Shoulder", "Forearm": "UpperArm", "Hand": "Forearm", "Grip": "Hand",
          HEEL: "Hand"}
for _n in FINGER_NAMES.values():
    PARENT[_n + "1"] = "Hand"
    PARENT[_n + "2"] = _n + "1"
    PARENT[_n + "3"] = _n + "2"
DEFORM = ["UpperArm", "Forearm", "Hand"] + ["%s%d" % (n, k) for n in FINGER_NAMES.values() for k in (1, 2, 3)]


class Frame:
    """The left arm's reference directions at rest: the forearm's line, the back of the hand, the palm's centre."""

    def __init__(self, j: dict):
        self.j = j
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
        self.knuckles = knuck

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


# Rounds of smoothing over the thumb's root, and how far round it (edge rings): the web between thumb and index
# finger takes the thumb's turn gradually instead of folding to a point (the owner, 2026-11-05).
WEB_SMOOTH = 8
WEB_RINGS = 3
# Rounds of the same over every finger joint's crease (the skin tore at the knuckles of a tight curl).
JOINT_SMOOTH = 3


def smooth_web(wts: list, faces: list) -> list:
    """`wts` with the weights round the thumb's root (Thumb1's skin and WEB_RINGS rings past it) blended with their
    neighbours' WEB_SMOOTH times, and every finger joint's JOINT_SMOOTH times, each vertex keeping its four
    largest."""
    near = [set() for _ in wts]
    for f in faces:
        for k, a in enumerate(f):
            b = f[(k + 1) % len(f)]
            near[a].add(b)
            near[b].add(a)
    region = {i for i, w in enumerate(wts) if "Thumb1" in w}
    for _ in range(WEB_RINGS):
        region |= {n for i in region for n in near[i]}
    joints = {i for i, w in enumerate(wts) if len(w) > 1 and any(b[-1].isdigit() for b in w)}
    out = _blend(wts, near, joints, JOINT_SMOOTH)
    return _blend(out, near, region, WEB_SMOOTH)


def heel_weights(wts: list, verts: list, j: dict) -> list:
    """`wts` with the thumb's first bone's share of each vertex divided between the heel of the thumb and that bone, by
    how far along the bone the vertex lies (HEEL_SPAN); each vertex keeps its four largest."""
    a, b = j["finger-1-1"], j["finger-1-2"]
    ab = b - a
    out = []
    for v, w in zip(verts, wts):
        share = w.get("Thumb1", 0.0)
        if share <= 0.0:
            out.append(w)
            continue
        t = (v - a).dot(ab) / ab.dot(ab)
        g = max(0.0, min(1.0, (t - HEEL_SPAN[0]) / (HEEL_SPAN[1] - HEEL_SPAN[0])))
        g = g * g * (3.0 - 2.0 * g)
        mix = dict(w)
        mix["Thumb1"] = share * g
        mix[HEEL] = share * (1.0 - g)
        top = sorted(((k, x) for k, x in mix.items() if x > 1e-4), key=lambda kv: -kv[1])[:4]
        total = sum(x for _, x in top)
        out.append({k: x / total for k, x in top})
    return out


def _blend(wts: list, near: list, region: set, rounds: int) -> list:
    out = list(wts)
    for _ in range(rounds):
        nxt = list(out)
        for i in region:
            mix = {}
            for b, x in out[i].items():
                mix[b] = mix.get(b, 0.0) + 0.5 * x
            share = 0.5 / max(1, len(near[i]))
            for n in near[i]:
                for b, x in out[n].items():
                    mix[b] = mix.get(b, 0.0) + share * x
            top = sorted(mix.items(), key=lambda kv: -kv[1])[:4]
            tot = sum(x for _, x in top)
            nxt[i] = {b: x / tot for b, x in top if x / tot > 0.01}
        out = nxt
    return out


# ------------------------------------------------------------------------------------------------------ mesh

def subdivide(verts: list, faces: list, cuts: list, levels: int = 1) -> tuple:
    """Catmull-Clark levels of the source quads (the hand and sleeve read smooth, not faceted), then cut through by
    each plane in `cuts` ((point, normal)) so an edge made there is straight."""
    me = bpy.data.meshes.new("src")
    me.from_pydata([tuple(v) for v in verts], [], faces)
    ob = bpy.data.objects.new("src", me)
    bpy.context.scene.collection.objects.link(ob)
    m = ob.modifiers.new("sub", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=m.name)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    for co, no in cuts:
        geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, dist=1e-5)
    bm.verts.index_update()
    vs = [v.co.copy() for v in bm.verts]
    fs = [[v.index for v in f.verts] for f in bm.faces]
    bm.free()
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)
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
        # The faces of the glove's kit laid over the hand (the knuckle shell, the pads, the palm patch, the cuff, its
        # strap and tab), first and past the last (BP8: the skin-only arms hide them); and the fingernails, a mesh of
        # their own that only the skin-only arms show (none until built).
        self.kit = (0, 0)
        # Each piece's faces by its name, first and past the last (HA1: glove_paint.py and sleeve_paint.py paint each
        # as what it is): "hand" the glove's cloth over the hand, then "guard", "pads", "patch", "cuff", "strap",
        # "tab", and the sleeve's "sleeve", "hem", "sleeve_tab" and "cap".
        self.parts = {}
        self.nails = None
        # The hand's own surface as a mesh of its own (HA1: the skin-only arms' skin, skin.py paints it): the glove's
        # surface with a fuller wrist and a tapered thumb (build_left), which the nails are laid on.
        self.skin = None

    def add(self, verts: list, faces: list, mat, wts: list) -> int:
        base = len(self.v)
        self.v += verts
        self.w += wts
        for k, f in enumerate(faces):
            self.f.append([base + i for i in f])
            self.m.append(mat[k] if isinstance(mat, list) else mat)
        return base

    def part(self, name: str, first: int) -> None:
        """Names the faces from `first` to the last one added (a name given twice runs on: its pieces are added
        together)."""
        self.parts[name] = (self.parts.get(name, (first, 0))[0], len(self.f))


def open_edges(faces: list) -> list:
    """The edges used by one face only, in that face's winding."""
    count = {}
    for f in faces:
        for k in range(len(f)):
            e = (f[k], f[(k + 1) % len(f)])
            count.setdefault(tuple(sorted(e)), []).append(e)
    return [es[0] for es in count.values() if len(es) == 1]


class Surface:
    """The glove's outer surface at rest, for laying parts onto it: each part's vertices sit on the surface (found by
    casting onto it) and take the weights of the glove beneath them, or one bone's only (a rigid part)."""

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

    def solid(self, rings: list, normals: list, thick, mat: str, closed: bool, bone: str = None,
              lift: float = 0.0004) -> tuple:
        """A raised part from rows of surface points: a top `thick` out (a number, or one per point), its edge rows
        drawn in and lower (a rounded edge), an underside on the surface, and walls round the edge. With a `bone`, the
        part follows that bone only."""
        rows, cols = len(rings), len(rings[0])
        top, bottom, wts = [], [], []
        for r in range(rows):
            for c in range(cols):
                p, n = rings[r][c], normals[r][c]
                t = thick[r][c] if isinstance(thick, list) else thick
                edge_r = min(r, rows - 1 - r)
                edge_c = cols if closed else min(c, cols - 1 - c)
                edge = min(edge_r, edge_c)
                share = 0.35 if edge == 0 else (0.82 if edge == 1 else 1.0)
                top.append(p + n * (lift + t * share))
                bottom.append(p + n * lift * 0.5)
                wts.append({bone: 1.0} if bone else self.weight(p))
        n = rows * cols
        faces = []
        cspan = cols if closed else cols - 1
        for r in range(rows - 1):
            for c in range(cspan):
                a, b = r * cols + c, r * cols + (c + 1) % cols
                faces.append([a, b, b + cols, a + cols])
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

    def cast_out(self, origin: Vector, d: Vector) -> tuple:
        """The first point of the surface out from `origin` (inside the hand or arm) along `d`, and the surface's
        normal there turned outward. Cast from inside, a ray never lands on a neighbouring finger."""
        hit = self.tree.ray_cast(origin, d, 0.06)
        if hit[0] is None:
            hit = self.tree.find_nearest(origin + d * 0.012)
        n = hit[1] if hit[1].dot(d) > 0.0 else -hit[1]
        return hit[0], n

    def shell(self, origin_at, dir_at, rows: int, cols: int, thick, mat: str, closed: bool = False,
              bone: str = None, smooth: int = 2, lift: float = 0.0004) -> tuple:
        """A raised part over a patch of the surface: for each (u, v) in -1..1 a ray from `origin_at(u, v)` along
        `dir_at(u, v)` finds the surface; the patch is smoothed so a skin crease under it never shows through, and
        stands `thick(u, v)` (or a number) off it."""
        rings, normals, dirs = [], [], []
        for r in range(rows):
            v = -1.0 + 2.0 * r / (rows - 1)
            row, nrow, drow = [], [], []
            for c in range(cols):
                u = (-1.0 + 2.0 * c / cols) if closed else (-1.0 + 2.0 * c / (cols - 1))
                d = dir_at(u, v).normalized()
                p, n = self.cast_out(origin_at(u, v), d)
                row.append(p)
                nrow.append((n + d).normalized())
                drow.append((u, v))
            rings.append(row)
            normals.append(nrow)
            dirs.append(drow)
        cast = [list(row) for row in rings]
        for _ in range(smooth):
            rings = _smoothed(rings, closed)
            normals = [[n.normalized() for n in row] for row in _smoothed(normals, closed)]
        # Smoothing a patch over a rounded finger pulls it in under the skin, and the skin then shows through its
        # edges in a ragged line: no point may end below where its ray met the surface.
        rings = [[p + n * max(0.0, (q - p).dot(n)) for p, q, n in zip(row, crow, nrow)]
                 for row, crow, nrow in zip(rings, cast, normals)]
        if callable(thick):
            thick = [[thick(u, v) for u, v in row] for row in dirs]
        return self.solid(rings, normals, thick, mat, closed, bone, lift)


def _smoothed(grid: list, closed: bool) -> list:
    """One round of averaging each inner point of a grid with its four neighbours; the first and last rows only
    along themselves, so a part's edge runs clean (the corners of an open patch stay put)."""
    rows, cols = len(grid), len(grid[0])
    out = [list(row) for row in grid]
    for r in range(rows):
        for c in range(cols):
            if not closed and c in (0, cols - 1):
                continue
            side = grid[r][(c - 1) % cols] + grid[r][(c + 1) % cols]
            if r in (0, rows - 1):
                out[r][c] = grid[r][c] * 0.5 + side * 0.25
            else:
                out[r][c] = grid[r][c] * 0.5 + (grid[r - 1][c] + grid[r + 1][c] + side) * 0.125
    return out


# ------------------------------------------------------------------------------------------------------ the arm

def _smooth01(t: float) -> float:
    t = min(1.0, max(0.0, t))
    return t * t * (3.0 - 2.0 * t)


def _soft_box(u: float, v: float, edge: float = 0.18) -> float:
    """1 inside a rounded box over u, v in -1..1, easing to 0 over `edge` at its sides and corners."""
    du = max(0.0, abs(u) - (1.0 - edge)) / edge
    dv = max(0.0, abs(v) - (1.0 - edge)) / edge
    t = min(1.0, math.sqrt(du * du + dv * dv))
    return 1.0 - t * t * (3.0 - 2.0 * t)


def knuckle_guard(surf: Surface, fr: Frame) -> tuple:
    """The moulded knuckle shell (the owner's glove photo 123404: one smooth hard shell): across the back of the hand
    from beyond the index to beyond the little finger, from half way back over the hand to just over the knuckles, a
    rounded oval outline, an even dome across it and a raised, stitched-looking border round it, its edges easing
    down into the glove; rigid on the hand."""
    j, k = fr.j, fr.knuckles
    up = fr.dorsal
    across = (k[3] - k[0]).normalized()
    f = (j["finger-3-2"] - j["finger-3-1"]).normalized()
    f = (f - up * f.dot(up)).normalized()

    def line(u: float) -> Vector:
        """The knuckles' line from just beyond the index (-1) to just beyond the little finger (+1)."""
        s = (u + 1.0) * 0.5 * 3.0
        i = min(2, max(0, int(s)))
        return k[i].lerp(k[i + 1], s - i) + across * KNUCKLE_SPAN * u

    def origin(u: float, v: float) -> Vector:
        # From well back over the back of the hand (v = -1) to just over the knuckles (v = +1), narrowing a little
        # towards the wrist; its corners rounded (the square pulled part way to a disc: the photos' shells are
        # rounded plates, never cut sheets).
        u, v = (u * (1.0 - KNUCKLE_ROUND + KNUCKLE_ROUND * math.sqrt(1.0 - v * v * 0.5)),
                v * (1.0 - KNUCKLE_ROUND + KNUCKLE_ROUND * math.sqrt(1.0 - u * u * 0.5)))
        back = KNUCKLE_BACK * (1.0 - v) * 0.5
        # Its edge over the knuckles lobed, a rounded tongue reaching on over each (photo 123404).
        lobe = KNUCKLE_LOBE * sum(math.exp(-((u - ku) / 0.2) ** 2) for ku in KNUCKLE_U) * max(0.0, v) ** 2
        return line(u * (1.0 - 0.30 * (1.0 - v) * 0.5)) + f * (KNUCKLE_OVER - back + lobe) - up * 0.006

    def direction(u: float, v: float) -> Vector:
        return up + across * u * 0.15

    def thick(u: float, v: float) -> float:
        # One even dome, highest a little behind the knuckles, and a raised border just inside its edge.
        dome = max(0.0, 1.0 - (u * u * 0.8 + (v - 0.2) * (v - 0.2) * 0.5))
        edge = max(abs(u), abs(v))
        rim = KNUCKLE_RIM * math.exp(-((edge - 0.86) / 0.05) ** 2)
        # A stitched seam just inside the border: a fine groove.
        seam = KNUCKLE_SEAM * math.exp(-((edge - 0.76) / 0.025) ** 2)
        return (SHELL_THICK + KNUCKLE_DOME * dome + rim - seam) * _soft_box(u, v, 0.14) + 0.0003

    return surf.shell(origin, direction, 13, 29, thick, "GloveArmour", False, "Hand", 8, 0.0010)


def _bump(p: Vector, a: Vector, b: Vector, along: float, height: float, face: Vector, sharp: float,
          reach: float) -> float:
    """A soft rise of `height` over the bone or joint a-b: easing out over `along` past its ends, and round it over the
    skin facing `face` (narrower as `sharp` grows); only skin within `reach` of it (not a neighbouring finger's)."""
    ab = b - a
    t = (p - a).dot(ab) / max(1e-12, ab.dot(ab))
    q = a + ab * max(0.0, min(1.0, t))
    off = p - q
    radial = off - ab.normalized() * off.dot(ab.normalized()) if ab.length > 1e-9 else off
    if radial.length > reach or radial.length < 1e-9:
        return 0.0
    x = (off - radial).length / along
    if x >= 1.0:
        return 0.0
    facing = max(0.0, radial.normalized().dot(face))
    return height * (1.0 - x * x) ** 2 * facing ** sharp


def hand_forms(p: Vector, n: Vector, fr: Frame) -> float:
    """How far the glove stands out at `p` (normal `n`) over the hand's forms, so it reads as a gloved hand and not a
    smooth sheet (the critic): the muscle between the thumb's and the index finger's bones (first dorsal interosseous),
    a soft bulge fullest toward the index; the thumb's own bone as a separate ridge beside it, a valley between the two;
    the index bone's edge along the thumb's side; and the finger joints, a small rise over the back of each middle and
    last joint, a fine crease across the palm's side of each. The glove's own surface, so it bends as the skin does."""
    j = fr.j
    up = fr.dorsal
    centre = j["finger-1-2"].lerp(j["finger-2-1"], WEB_TOWARD_INDEX).lerp(fr.wrist.lerp(j["finger-2-1"], 0.6), 0.35)
    d = p - centre
    r = (d - up * d.dot(up)).length / WEB_RADIUS
    out = WEB_BULGE * max(0.0, 1.0 - r * r) ** 2 * max(0.0, n.dot(up) + 0.3) / 1.3
    # The thumb's bone, from its root to its first knuckle, on its back and outer side.
    t0, t1 = j["finger-1-1"], j["finger-1-2"]
    away = t1 - fr.palm_centre
    away = (away - (t1 - t0).normalized() * away.dot((t1 - t0).normalized())).normalized()
    out += _bump(p, t0.lerp(t1, 0.3), t1.lerp(t0, 0.15), THUMB_BONE[0], THUMB_BONE[1], (away + up).normalized(), 3.0,
                 0.020)
    # The index bone's edge on the thumb's side, from half way down the back of the hand to its knuckle.
    radial = (j["finger-2-1"] - j["finger-3-1"]).normalized()
    out += _bump(p, fr.wrist.lerp(j["finger-2-1"], 0.45), j["finger-2-1"].lerp(fr.wrist, 0.12), INDEX_BONE[0],
                 INDEX_BONE[1], (up + radial).normalized(), 3.0, 0.020)
    for f in (2, 3, 4, 5):
        a, b = j["finger-%d-2" % f], j["finger-%d-3" % f]
        axis = (b - j["finger-%d-1" % f]).normalized()
        for joint, (along, h) in ((a, JOINT_BUMP[0]), (b, JOINT_BUMP[1])):
            out += _bump(p, joint, joint + axis * 1e-6, along, h, up, 2.0, JOINT_REACH)
            # The crease: a narrow groove across the palm's side of the joint.
            out -= _bump(p, joint, joint + axis * 1e-6, JOINT_CREASE[0], JOINT_CREASE[1], -up, 1.0, JOINT_REACH)
    return out


def finger_pads(surf: Surface, fr: Frame) -> list:
    """The finger pads (the owner's glove photo 123404): a small domed oval on the back of each finger's first bone,
    just short of the middle knuckle; none on the thumb (photo 123404's thumb is plain suede; the critic) nor on the
    palm's side, the fingertips plain. Each bends with the glove beneath it."""
    j = fr.j
    out = []

    def pad(a: Vector, b: Vector, up: Vector, span: tuple, wrap: float, bone: str, grid: tuple = (9, 1, 0.5)) -> tuple:
        d = (b - a).normalized()
        up = (up - d * up.dot(d)).normalized()
        side = d.cross(up)

        def origin(u: float, v: float) -> Vector:
            return a.lerp(b, span[0] + (span[1] - span[0]) * (v + 1.0) * 0.5)

        def direction(u: float, v: float) -> Vector:
            # Narrowing towards its ends: an oval, not a cut strip.
            t = math.radians(wrap) * u * math.sqrt(1.0 - 0.8 * v * v)
            return up * math.cos(t) + side * math.sin(t)

        def thick(u: float, v: float) -> float:
            # A domed oval with a sunken hole in its middle (the photo's rubber knuckle pads).
            r2 = u * u + v * v
            hole = 1.0 - 0.9 * math.exp(-r2 / 0.12)
            return PAD_THICK * max(0.0, 1.0 - r2) ** 0.6 * hole * _soft_box(u, v, grid[2]) + 0.0003

        return surf.shell(origin, direction, grid[0], 11, thick, "GloveArmour", False, PAD_RIGID and bone, grid[1],
                          0.0008)

    for f in (2, 3, 4, 5):
        name = FINGER_NAMES[f]
        a, b = j["finger-%d-1" % f], j["finger-%d-2" % f]
        out.append(pad(a, b, fr.dorsal, PAD_SPAN, PAD_WRAP, name + "1"))
    return out


def _nail_root(v: float) -> float:
    """A nail's thickness along it (v -1 at its root, 1 at its tip), as a share: it grows out of the skin."""
    t = min(1.0, max(0.0, (v + 1.0) / NAIL_ROOT[1]))
    return NAIL_ROOT[0] + (1.0 - NAIL_ROOT[0]) * t * t * (3.0 - 2.0 * t)


def nails(surf: Surface, fr: Frame) -> Mesh:
    """The fingernails (BP8, the owner's playtest note 11: skin-only arms): a thin rounded plate on the back of each
    finger's last bone, from NAIL_SPAN of it to its tip, NAIL_WRAP degrees round either side; the thumb's faces away
    from the palm. Each bends with the skin beneath it. A mesh of its own: only the skin-only arms show it."""
    j = fr.j
    out = Mesh()
    for f, name in FINGER_NAMES.items():
        a, b = j["finger-%d-3" % f], j["finger-%d-4" % f]
        d = (b - a).normalized()
        up = fr.dorsal if f != 1 else (a - (fr.palm_centre + fr.palmar * 0.02))
        up = (up - d * up.dot(d)).normalized()
        side = d.cross(up)

        span, wrap = (THUMB_NAIL_SPAN, THUMB_NAIL_WRAP) if f == 1 else (NAIL_SPAN, NAIL_WRAP)

        def origin(u: float, v: float, a: Vector = a, b: Vector = b, span: tuple = span) -> Vector:
            return a.lerp(b, span[0] + (span[1] - span[0]) * (v + 1.0) * 0.5)

        def direction(u: float, v: float, up: Vector = up, side: Vector = side, wrap: float = wrap) -> Vector:
            # Rounded at its root and a little narrower at its tip: a nail's outline, not a cut strip's.
            narrow = 1.0 - NAIL_ROUND[0] * max(0.0, -v) ** 3 - NAIL_ROUND[1] * max(0.0, v) ** 3
            t = math.radians(wrap) * u * narrow
            return up * math.cos(t) + side * math.sin(t)

        out.add(*surf.shell(origin, direction, NAIL_GRID[0], NAIL_GRID[1],
                            lambda u, v: (NAIL_THICK * _soft_box(u, v, 0.4) + NAIL_EDGE) * _nail_root(v),
                            NAIL_MATERIAL, smooth=1, lift=NAIL_LIFT))
    return out


def ring(surf: Surface, fr: Frame, span: tuple, thick: float, mat: str, cols: int = 32) -> tuple:
    """A band round the wrist between `span` (m along the forearm from the wrist joint)."""
    side = fr.dorsal.cross(fr.fdir)

    def origin(u: float, v: float) -> Vector:
        return fr.wrist + fr.fdir * (span[0] + (span[1] - span[0]) * (v + 1.0) * 0.5)

    def direction(u: float, v: float) -> Vector:
        t = math.pi * (u + 1.0)
        return fr.dorsal * math.cos(t) + side * math.sin(t)

    return surf.shell(origin, direction, 5, cols, thick, mat, True, None, 3)


def wrist_full(verts: list, fr: Frame, full: tuple = None) -> list:
    """`verts` with the wrist widened and thickened (`full`, else WRIST_FULL, over WRIST_SPAN), about the forearm's
    line."""
    full = WRIST_FULL if full is None else full
    across = fr.knuckles[3] - fr.knuckles[0]
    across = (across - fr.fdir * across.dot(fr.fdir)).normalized()
    through = fr.fdir.cross(across)
    a, b, c, d = WRIST_SPAN
    out = []
    for v in verts:
        t = fr.along(v)
        if t <= a or t >= d:
            out.append(v)
            continue
        k = (t - a) / (b - a) if t < b else (d - t) / (d - c) if t > c else 1.0
        k = k * k * (3.0 - 2.0 * k)
        radial = v - fr.wrist - fr.fdir * t
        out.append(v + across * (radial.dot(across) * full[0] * k) +
                   through * (radial.dot(through) * full[1] * k))
    return out


def build_left(shoulder: Vector) -> tuple:
    """The left arm: glove and its parts, cuff and strap, and sleeve, with weights; and its joints."""
    src_v, src_f, j = load_source(shoulder)
    src_v, j = lengthen(src_v, j, 5, PINKY_LONGER)
    src_v, j = narrow(src_v, j, HAND_NARROW)
    fr = Frame(j)
    src_v = wrist_full(src_v, fr)
    up_dir = (j["shoulder"] - j["elbow"]).normalized()
    # Cut where the sleeve ends and where its band does, so both run clean round the arm (a face-by-face edge left
    # the cuff ragged and some of its edges open, which the shoulder's cap then closed in long slivers through the arm).
    cuts = [(fr.wrist + fr.fdir * t, fr.fdir) for t in (SLEEVE_END, SLEEVE_END - SLEEVE_BAND, GLOVE_TOP)]
    cuts.append((j["elbow"] + up_dir * UPPER_KEEP, up_dir))
    verts, faces = subdivide(src_v, src_f, cuts)
    pts = bone_points(j)
    wts = weights(verts, j, pts)
    if WEB_SMOOTH:
        wts = smooth_web(wts, faces)
    wts = heel_weights(wts, verts, j)
    nrm = vertex_normals(verts, faces)
    mesh = Mesh()

    # The gloved hand: the skin from up the forearm (hidden in the sleeve) to the fingertips.
    hand_f = [f for f in faces if fr.along(centre(verts, f)) > GLOVE_TOP]
    used = sorted({i for f in hand_f for i in f})
    idx = {o: k for k, o in enumerate(used)}
    # The thumb's glove a little fuller (the photos' gloved thumbs are thicker than the hand's skin makes them: the
    # critic, 123843; fuller still, the thumb found no room on the grip's panel and stood out from it).
    fingers = ["%s%d" % (n, k) for n in FINGER_NAMES.values() for k in (1, 2, 3)]
    gv = [verts[o] + nrm[o] * (GLOVE_THICK + hand_forms(verts[o], nrm[o], fr) +
                               THUMB_FULL * (wts[o].get("Thumb2", 0.0) + wts[o].get("Thumb3", 0.0)) +
                               FINGER_FULL * sum(wts[o].get(b, 0.0) for b in fingers)) for o in used]
    gf = [[idx[i] for i in f] for f in hand_f]
    gw = [wts[o] for o in used]
    mesh.add(gv, gf, "Glove", gw)
    mesh.part("hand", 0)

    surf = Surface(gv, gf, gw)
    first = len(mesh.f)
    mesh.add(*knuckle_guard(surf, fr))
    mesh.part("guard", first)
    first = len(mesh.f)
    for part in finger_pads(surf, fr):
        mesh.add(*part)
    mesh.part("pads", first)
    # The palm's suede patch, over the heel of the hand and up to the fingers' roots: a rounded square (its corners
    # pulled in to a radius of about 8 mm), its thickness easing out in from its edges.
    across = (fr.knuckles[3] - fr.knuckles[0]).normalized()
    pc = fr.palm_centre + fr.fingers * 0.002

    def palm_origin(u: float, v: float) -> Vector:
        return pc + across * (u * 0.024 * math.sqrt(1.0 - 0.35 * v * v)) + \
            fr.fingers * (v * 0.024 * math.sqrt(1.0 - 0.35 * u * u))

    first = len(mesh.f)
    mesh.add(*surf.shell(palm_origin, lambda u, v: fr.palmar, 7, 11,
                         lambda u, v: 0.0021 * _soft_box(u, v, 0.6) + 0.0001, "GloveArmour", smooth=4, lift=0.0008))
    mesh.part("patch", first)
    # The neoprene cuff, and its strap round it with a pull tab on the little finger's side.
    first = len(mesh.f)
    mesh.add(*ring(surf, fr, CUFF[:2], CUFF[2], "Glove"))
    mesh.part("cuff", first)
    first = len(mesh.f)
    mesh.add(*ring(surf, fr, STRAP[:2], CUFF[2] + STRAP[2], "GloveArmour"))
    mesh.part("strap", first)
    side = fr.dorsal.cross(fr.fdir)
    out = side if (fr.knuckles[3] - fr.wrist).dot(side) > 0.0 else -side

    def tab_origin(u: float, v: float) -> Vector:
        return fr.wrist + fr.fdir * (STRAP[0] + (STRAP[1] - STRAP[0]) * (0.5 + 0.42 * v))

    def tab_dir(u: float, v: float) -> Vector:
        t = math.radians(40.0) * u
        return (out * math.cos(t) + fr.dorsal * math.sin(t)) + fr.dorsal * 0.9

    first = len(mesh.f)
    mesh.add(*surf.shell(tab_origin, tab_dir, 5, 9, lambda u, v: (CUFF[2] + STRAP[2] + 0.0022) * _soft_box(u, v, 0.3),
                         "GloveArmour", smooth=3))
    mesh.part("tab", first)
    # The glove's kit, which the skin-only arms hide: all of it but the cloth over the hand, which they show as skin.
    mesh.kit = (mesh.parts["hand"][1], len(mesh.f))
    bare = thumb_taper(wrist_full(gv, fr, SKIN_WRIST_FULL), j, gw)
    mesh.nails = nails(Surface(bare, gf, gw), fr)
    mesh.skin = Mesh()
    mesh.skin.add(bare, gf, "Skin", gw)

    sleeve(mesh, verts, faces, wts, fr)
    return mesh, j, fr, pts


def _loose(w: dict) -> dict:
    """A sleeve vertex's weights: the skin's beneath it, with the hand's share moved onto the forearm. The sleeve is
    loose on the arm and doesn't turn with the wrist; following the hand, it folded in on itself along the top of the
    forearm when a pistol hold turned the wrist (the critic's dark wedges in the pistol's aimed view)."""
    out = {}
    for b, v in w.items():
        k = "Forearm" if b not in ("Forearm", "UpperArm") else b
        out[k] = out.get(k, 0.0) + v
    return out


def sleeve(mesh: Mesh, verts: list, faces: list, wts: list, fr: Frame) -> None:
    """The sleeve: a loose shell over the forearm and upper arm with soft folds, its cuff banded and hemmed."""
    j = fr.j
    wts = [_loose(w) for w in wts]
    up_dir = (j["shoulder"] - j["elbow"]).normalized()
    sleeve_f = [f for f in faces if fr.along(centre(verts, f)) < SLEEVE_END
                and (centre(verts, f) - j["elbow"]).dot(up_dir) < UPPER_KEEP]
    cuff_edges = [e for e in open_edges(sleeve_f) if all(abs(fr.along(verts[i]) - SLEEVE_END) < 0.001 for i in e)]
    snrm = vertex_normals(verts, sleeve_f)
    # Smoothed a few rounds over its neighbours: a skewed normal at a crease of the base mesh pushed a fin out of the
    # top of the forearm (the critic's dark wedge on the pistol's aimed view).
    near = {}
    for f in sleeve_f:
        for a, b in zip(f, f[1:] + f[:1]):
            near.setdefault(a, set()).add(b)
            near.setdefault(b, set()).add(a)
    for _ in range(SLEEVE_NORMAL_SMOOTH):
        snrm = list(snrm)
        smoothed = {i: (snrm[i] + sum((snrm[k] for k in ks), Vector())).normalized() for i, ks in near.items()}
        for i, n in smoothed.items():
            snrm[i] = n
    elbow_t = fr.along(j["elbow"])
    shoulder_t = fr.along(j["shoulder"])
    side_ref = fr.dorsal.cross(fr.fdir)
    # The crook of the elbow faces where the palm does at rest.
    crook = fr.palmar

    def off(p: Vector) -> float:
        t = fr.along(p)
        radial = p - fr.wrist - fr.fdir * t
        rn = radial.normalized() if radial.length > 1e-6 else fr.dorsal
        ang = math.atan2(radial.dot(fr.dorsal), radial.dot(side_ref))
        share = max(0.0, min(1.0, (t - SLEEVE_END) / (shoulder_t - SLEEVE_END)))
        base = SLEEVE_OFF[0] + (SLEEVE_OFF[1] - SLEEVE_OFF[0]) * share
        # Bunched over the cuff: three soft rolls, deepest nearest the cuff, a little skewed round the arm.
        u = (SLEEVE_END - t)
        rolls = math.exp(-(u / 0.07) ** 2) * math.sin((u + 0.004 * math.sin(ang + 0.6)) / 0.024 * 2.0 * math.pi)
        # Gathered in the crook of the elbow: folds across the inside of the arm.
        inside = max(0.0, rn.dot(crook))
        gather = math.exp(-((t - elbow_t) / 0.05) ** 2) * inside * math.sin((t - elbow_t) / 0.018 * 2.0 * math.pi)
        # Slack hanging under the forearm and a slow twist along it.
        sag = 0.0012 * max(0.0, -rn.dot(fr.dorsal)) + 0.0009 * math.sin(2.0 * ang + t * 18.0)
        return base + 0.0021 * rolls + 0.0024 * gather + sag

    used = sorted({i for f in sleeve_f for i in f})
    idx = {o: k for k, o in enumerate(used)}
    smats = ["SleeveTrim" if fr.along(centre(verts, f)) > SLEEVE_END - SLEEVE_BAND else "Sleeve" for f in sleeve_f]
    outer = []
    for o in used:
        d = off(verts[o])
        # The banded cuff stands a little proud of the sleeve.
        if fr.along(verts[o]) > SLEEVE_END - SLEEVE_BAND - 1e-6:
            d += 0.0012
        outer.append(verts[o] + snrm[o] * d)
    first = len(mesh.f)
    base = mesh.add(outer, [[idx[i] for i in f] for f in sleeve_f], smats, [wts[o] for o in used])
    mesh.part("sleeve", first)
    first = len(mesh.f)
    # The hem: the cuff's open edge turned in towards the glove.
    hem = {}
    for a, b in cuff_edges:
        for i in (a, b):
            if i not in hem:
                p = verts[i] + snrm[i] * (off(verts[i]) + 0.0012 - SLEEVE_HEM) - fr.fdir * 0.0015
                hem[i] = mesh.add([p], [], "SleeveTrim", [wts[i]])
        mesh.f.append([base + idx[b], base + idx[a], hem[a], hem[b]])
        mesh.m.append("SleeveTrim")
    mesh.part("hem", first)
    # The cuff's tab, on the back of the wrist.
    sv = [outer[idx[o]] for o in used]
    sf = [[idx[i] for i in f] for f in sleeve_f]
    ssurf = Surface(sv, sf, [wts[o] for o in used])
    tab_side = side_ref if (fr.knuckles[3] - fr.wrist).dot(side_ref) > 0 else -side_ref
    toward = (fr.dorsal * 0.6 + tab_side).normalized()
    across = toward.cross(fr.fdir).normalized()

    def tab_origin(u: float, v: float) -> Vector:
        return fr.wrist + fr.fdir * (SLEEVE_END - SLEEVE_BAND * (0.5 - 0.40 * v))

    def tab_dir(u: float, v: float) -> Vector:
        t = math.radians(30.0) * u
        return toward * math.cos(t) + across * math.sin(t)

    first = len(mesh.f)
    mesh.add(*ssurf.shell(tab_origin, tab_dir, 5, 9, 0.0017, "SleeveTrim"))
    mesh.part("sleeve_tab", first)
    first = len(mesh.f)
    # The top, at the shoulder: closed, so the sleeve's inside never shows.
    top_edges = [e for e in open_edges(sleeve_f) if e not in cuff_edges]
    ring = sorted({i for e in top_edges for i in e})
    if ring:
        mid = sum((outer[idx[i]] for i in ring), Vector()) / len(ring)
        # The cap's centre moves as its rim does (the rim's own weights, averaged): on one bone alone it pulled the
        # cap into a torn flap once the shoulder was moved.
        cw = {}
        for i in ring:
            for b, w in wts[i].items():
                cw[b] = cw.get(b, 0.0) + w / len(ring)
        c = mesh.add([mid], [], "Sleeve", [cw])
        for a, b in top_edges:
            mesh.f.append([base + idx[b], base + idx[a], c])
            mesh.m.append("Sleeve")
    mesh.part("cap", first)
