"""The figure's anatomy (BL10): the MakeHuman base body (source/makehuman_body.obj, CC0 1.0) moved onto the figures'
skeleton at rest, so the clothes built over it fit the bones the 32 clips drive.

Each of the skeleton's bones has a matching span between two of the base mesh's joint centres. A bone's move is the
turn from its span's line to the bone's, a stretch along it to the bone's length and a girth scale across it; each
vertex blends the moves of its nearest bones by inverse distance (blend_weights, below).
"""

import os

import numpy as np
from mathutils import Matrix, Vector

SOURCE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "source", "makehuman_body.obj")
FINGERS = {1: "Thumb", 2: "Index", 3: "Middle", 4: "Ring", 5: "Pinky"}
SPINE = ["Hips", "Spine", "Spine1", "Chest"]
# Girth across each bone's line (1 = the base mesh's): a weekend player's build, filled out a touch over the
# base mesh's average man so the clothes hang on shoulders and thighs, not on a mannequin.
GIRTH = {"Hips": 1.0, "Spine": 0.98, "Spine1": 1.0, "Chest": 1.02, "Neck": 0.98, "Shoulder": 1.0, "UpperArm": 1.04,
         "Forearm": 1.02, "Hand": 1.0, "Thigh": 1.0, "Shin": 1.0, "Foot": 1.0, "Toe": 1.0}


def load() -> tuple:
    """(verts N x 3, quads, joints {name: Vector}) of the base body, metres, facing -Y."""
    verts, faces, joints = [], [], {}
    for line in open(SOURCE):
        if line.startswith("# joint"):
            _, _, name, x, y, z = line.split()
            joints[name] = Vector((float(x), float(y), float(z)))
        elif line.startswith("v "):
            verts.append([float(t) for t in line.split()[1:4]])
        elif line.startswith("f "):
            faces.append([int(t) - 1 for t in line.split()[1:]])
    return np.array(verts), faces, joints


def rig_points(rig) -> dict:
    """Rest head and tail of every bone of the armature object, world space."""
    mw = rig.matrix_world
    return {b.name: (mw @ b.head_local, mw @ b.tail_local) for b in rig.data.bones}


def spans(j: dict, r: dict) -> list:
    """(bone, base mesh head, base mesh tail, rig head, rig tail, girth key, side) for every bone the body follows."""
    out = []
    # The spine: the base mesh's pelvis-to-neck line against the rig's Hips head to Neck head, by height.
    mh_lo, mh_hi = Vector((0.0, j["pelvis"].y, j["pelvis"].z)), Vector((0.0, j["neck"].y, j["neck"].z))
    rg_lo, rg_hi = r["Hips"][0], r["Neck"][0]

    def mh_at(p: Vector) -> Vector:
        f = (p.z - rg_lo.z) / (rg_hi.z - rg_lo.z)
        return mh_lo.lerp(mh_hi, f)

    chain = [r["Hips"][0], r["Spine"][0], r["Spine1"][0], r["Chest"][0], r["Neck"][0]]
    for k, name in enumerate(SPINE):
        out.append((name, mh_at(chain[k]), mh_at(chain[k + 1]), chain[k], chain[k + 1], name, ""))
    out.append(("Neck", j["neck"], j["head"], r["Neck"][0], r["Head"][0], "Neck", ""))
    for side, s in (("L", "l"), ("R", "r")):
        sh = j[s + "-shoulder"]
        out.append(("Shoulder_" + side, Vector((sh.x * 0.15, mh_at(r["Shoulder_" + side][0]).y, j[s + "-clavicle"].z)),
                    sh, r["Shoulder_" + side][0], r["Shoulder_" + side][1], "Shoulder", side))
        out.append(("UpperArm_" + side, sh, j[s + "-elbow"], r["UpperArm_" + side][0], r["UpperArm_" + side][1],
                    "UpperArm", side))
        out.append(("Forearm_" + side, j[s + "-elbow"], j[s + "-hand"], r["UpperArm_" + side][1],
                    r["Hand_" + side][0], "Forearm", side))
        out.append(("Hand_" + side, j[s + "-hand"], j[s + "-finger-3-1"], r["Hand_" + side][0],
                    r["Middle1_" + side][0], "Hand", side))
        for f, name in FINGERS.items():
            for k in (1, 2, 3):
                bone = "%s%d_%s" % (name, k, side)
                tail = r[bone][1]
                out.append((bone, j["%s-finger-%d-%d" % (s, f, k)], j["%s-finger-%d-%d" % (s, f, k + 1)],
                            r[bone][0], tail, "Hand", side))
        out.append(("Thigh_" + side, j[s + "-upper-leg"], j[s + "-knee"], r["Thigh_" + side][0],
                    r["Thigh_" + side][1], "Thigh", side))
        out.append(("Shin_" + side, j[s + "-knee"], j[s + "-ankle"], r["Shin_" + side][0], r["Shin_" + side][1],
                    "Shin", side))
        out.append(("Foot_" + side, j[s + "-ankle"], j[s + "-foot-1"], r["Foot_" + side][0], r["Foot_" + side][1],
                    "Foot", side))
        out.append(("Toe_" + side, j[s + "-foot-1"], j[s + "-foot-2"], r["Toe_" + side][0],
                    r["Toe_" + side][0].lerp(r["Toe_" + side][1], 0.55), "Toe", side))
    return out


def _turn(a: Vector, b: Vector) -> Matrix:
    """The smallest turn taking direction a to direction b."""
    return a.normalized().rotation_difference(b.normalized()).to_matrix()


def _hand_frame(base: Vector, mid: Vector, index: Vector, pinky: Vector) -> Matrix:
    x = (mid - base).normalized()
    y = (index - pinky)
    y = (y - x * y.dot(x)).normalized()
    return Matrix((x, y, x.cross(y))).transposed()


def moves(sp: list, j: dict, r: dict) -> dict:
    """Each bone's affine move (3x3, mh origin, rig origin)."""
    out = {}
    for bone, ma, mb, ra, rb, key, side in sp:
        d_mh, d_rg = mb - ma, rb - ra
        k = d_rg.length / max(1e-9, d_mh.length)
        g = GIRTH[key]
        u = d_mh.normalized()
        stretch = Matrix.Identity(3) * g + (k - g) * Matrix((u * u.x, u * u.y, u * u.z)).transposed()
        rot = _turn(d_mh, d_rg)
        if key == "Hand" and side:
            s = side.lower()
            f_mh = _hand_frame(j[s + "-hand"], j[s + "-finger-3-1"], j[s + "-finger-2-1"], j[s + "-finger-5-1"])
            f_rg = _hand_frame(r["Hand_" + side][0], r["Middle1_" + side][0], r["Index1_" + side][0],
                               r["Pinky1_" + side][0])
            hand_rot = f_rg @ f_mh.transposed()
            # Keep the hand's palm turn, then line the bone up exactly.
            rot = _turn(hand_rot @ d_mh, d_rg) @ hand_rot
        out[bone] = (np.array(rot @ stretch), np.array(ma), np.array(ra))
    return out


def _seg_dist(p: np.ndarray, a: np.ndarray, b: np.ndarray) -> np.ndarray:
    ab = b - a
    t = np.clip(((p - a) @ ab) / max(1e-12, ab @ ab), 0.0, 1.0)
    return np.linalg.norm(p - (a + t[:, None] * ab), axis=1)


PARENTS = {"Hips": None, "Spine": "Hips", "Spine1": "Spine", "Chest": "Spine1", "Neck": "Chest"}
for _s in ("L", "R"):
    PARENTS.update({"Shoulder_" + _s: "Chest", "UpperArm_" + _s: "Shoulder_" + _s, "Forearm_" + _s: "UpperArm_" + _s,
                    "Hand_" + _s: "Forearm_" + _s, "Thigh_" + _s: "Hips", "Shin_" + _s: "Thigh_" + _s,
                    "Foot_" + _s: "Shin_" + _s, "Toe_" + _s: "Foot_" + _s})
    for _n in FINGERS.values():
        PARENTS["%s1_%s" % (_n, _s)] = "Hand_" + _s
        PARENTS["%s2_%s" % (_n, _s)] = "%s1_%s" % (_n, _s)
        PARENTS["%s3_%s" % (_n, _s)] = "%s2_%s" % (_n, _s)


def blend_weights(verts: np.ndarray, sp: list) -> tuple:
    """(bone names, N x B weights): each vertex's nearest bone and its chain neighbours, inverse distance to the 4th."""
    names = [s[0] for s in sp]
    d = np.stack([_seg_dist(verts, np.array(s[1]), np.array(s[2])) for s in sp], axis=1)
    near = np.argmin(d, axis=1)
    idx = {n: i for i, n in enumerate(names)}
    allow = np.zeros_like(d, dtype=bool)
    for i, n in enumerate(names):
        rows = near == i
        cand = {n, PARENTS.get(n)} | {c for c, p in PARENTS.items() if p == n}
        for c in cand:
            if c in idx:
                allow[rows, idx[c]] = True
    w = np.where(allow, 1.0 / (d ** 2 + 1e-6) ** 2, 0.0)
    w /= w.sum(axis=1, keepdims=True)
    return names, w


def repose(verts: np.ndarray, sp: list, mv: dict) -> np.ndarray:
    names, w = blend_weights(verts, sp)
    out = np.zeros_like(verts)
    for i, n in enumerate(names):
        m, o_mh, o_rg = mv[n]
        out += w[:, i:i + 1] * ((verts - o_mh) @ m.T + o_rg)
    return out


def build(rig) -> tuple:
    """(verts, quads, joints, dominant bone per vertex) of the base body on `rig`'s rest pose."""
    verts, faces, j = load()
    r = rig_points(rig)
    sp = spans(j, r)
    names, w = blend_weights(verts, sp)
    dominant = [names[i] for i in np.argmax(w, axis=1)]
    return repose(verts, sp, moves(sp, j, r)), faces, r, dominant
