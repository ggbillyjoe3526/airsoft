"""The figure body (BL10): the human figure's clothes, boots and gloves, built over the MakeHuman anatomy moved onto
the figures' skeleton at rest (anatomy.py), from the owner's figure photos (ref_images/player/figure: the T-pose
front and back shots and the turnaround lead).

Run with Python 3.13 and pip's bpy==5.2.3, numpy and Pillow (installed with bpy); about a minute:

    BODY_MAPS=<maps dir> python -I tools/blender/figures/body.py <root> [out.blend] [body.glb] [--fast]
    python -I tools/blender/figures/splice_part.py <figure.glb> body.glb Body
    python -I tools/blender/figures/splice_part.py <figure.glb> body.glb Kit_Pads   (only while it carries v12's pads)
    python -I tools/blender/figures/body_weights.py <figure.glb>   (BP6: the glove plates; after pads.py, gear.py)

<root> holds assets/models/characters/human.glb, which the build reads (its Rig, and its Body for the weights): use a
copy of the figure file, never the one being replaced. The weights come from that file's Body by nearest face, so
building over the v12 body or over this script's own output gives the same weights near enough (the v12 body is the
reference: the clips were tuned on it). body.glb holds the Rig and the new Body levels for the splice; BODY_MAPS gets
the baked maps as PNG; --fast skips the bake and the export.
"""

import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anatomy  # noqa: E402
import boots as B  # noqa: E402
import details as D  # noqa: E402
import garment as G  # noqa: E402

ROOT = next((a for a in sys.argv[1:] if os.path.isdir(a)), os.getcwd())
HUMAN = os.path.join(ROOT, "assets/models/characters/human.glb")
OUT_MAPS = os.environ.get("BODY_MAPS", os.path.join(os.path.dirname(os.path.abspath(__file__)), "out"))

# Heights (m, rest pose, the figure standing on z = 0 facing -Y).
SHIRT_TUCK = 0.95      # the shirt's tail, tucked under the trousers' waist
SHIRT_NECK = 1.445     # the shirt body's neckline; the collar stands above it
WAIST_TOP = 1.02       # the trousers' waistband top
HEM = 0.170            # the trousers' hem, bloused over the boots' shafts (about 9 % of the height shows, as photos)
SLEEVE_END = 0.046     # the sleeve's end up the forearm from the wrist joint (m)
GLOVE_TOP = 0.072      # the glove's cuff up the forearm from the wrist joint, tucked under the sleeve
# Triangle budgets of the parts (the body's 34,000 at LOD0, shared with the heads, gear and pads threads).
GLOVE_TRIS = 6000
TROUSER_FOLDS_FROM = 0.60   # the trousers are subdivided below this height (m) for their folds
KNEE_SMOOTH = (0.36, 0.66)   # the heights (m) whose weights smooth_knees blurs
SLEEVE_FROM = 0.19     # |x| (m) past which the shirt is sleeve: finer mesh and folds in the geometry
# The mock-neck collar's rings (z, half width, half depth), from the neckline up to its rolled top and back down
# inside to the neck.
COLLAR = [(1.468, 0.078, 0.073), (1.492, 0.071, 0.067), (1.509, 0.068, 0.064), (1.516, 0.064, 0.060),
          (1.505, 0.059, 0.055), (1.470, 0.060, 0.056)]
SHIRT_BONES = {"Hips", "Spine", "Spine1", "Chest", "Neck"}
ARM_BONES = ("Shoulder", "UpperArm", "Forearm")
LEG_BONES = ("Thigh", "Shin", "Foot", "Toe")
HAND_BONES = ("Hand", "Thumb", "Index", "Middle", "Ring", "Pinky")


def subset(verts, faces, dom, keep) -> bmesh.types.BMesh:
    """The anatomy's faces whose vertices all pass keep(bone, position)."""
    ok = [keep(dom[i], verts[i]) for i in range(len(verts))]
    fs = [f for f in faces if all(ok[i] for i in f)]
    return G.to_bmesh(verts, fs)


def arm_axis(r: dict, side: str) -> tuple:
    w = r["Hand_" + side][0]
    e = r["UpperArm_" + side][1]
    return w, (w - e).normalized()


def shirt(verts, faces, r, dom) -> tuple:
    """The shirt (bmesh) and the surface its details are cast onto."""
    def keep(b: str, p) -> bool:
        return (b in SHIRT_BONES or b.startswith(ARM_BONES) or b.startswith(HAND_BONES)
                or (b.startswith("Thigh") and p[2] > SHIRT_TUCK - 0.03))
    bm = subset(verts, faces, dom, keep)
    G.cut(bm, Vector((0, 0, SHIRT_TUCK)), Vector((0, 0, -1)), near=(Vector((0, 0, SHIRT_TUCK)), 0.30))
    G.cut(bm, Vector((0, 0, SHIRT_NECK)), Vector((0, -0.25, 1)).normalized())
    for s in ("L", "R"):
        w, a = arm_axis(r, s)
        G.cut(bm, w - a * SLEEVE_END, a, near=(w, 0.2))
    G.keep_largest(bm)
    G.relax(bm, rounds=6, amount=0.5)
    # Cloth over the chest and back: no pecs or spine through it.
    G.relax(bm, rounds=24, amount=0.5, pin=lambda v: abs(v.co.x) > 0.15 or not 1.0 < v.co.z < 1.40)
    for _ in range(2):
        flatten_chest(bm)

    def ease(p: Vector) -> float:
        # Snug on the torso (the carrier presses it), loose on the arms, gathered at the cuffs.
        ax = abs(p.x)
        if ax < 0.17:
            return 0.006
        best = 0.006
        for s in ("L", "R"):
            w, a = arm_axis(r, s)
            t = (w - p).dot(a)  # distance up the arm from the wrist
            if t < 0.30 and (p.x > 0) == (s == "L"):
                best = 0.008 + 0.006 * min(1.0, (t - SLEEVE_END) / 0.08)
            elif (p.x > 0) == (s == "L"):
                best = 0.013
        return best
    sleeves = [e for e in bm.edges if all(abs(v.co.x) > SLEEVE_FROM for v in e.verts)]
    bmesh.ops.subdivide_edges(bm, edges=sleeves, cuts=1, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    G.offset(bm, ease)
    sleeve_folds(bm, r)
    surf = G.Surface(bm)
    G.grow_collar(bm, COLLAR, 0.004)
    G.hem(bm, depth=0.012)
    return bm, surf


def flatten_chest(bm: bmesh.types.BMesh, radius: float = 0.08) -> None:
    """Smooth the torso's depth (y) over `radius`: the shirt hangs flat over the chest and back, no pecs, nipples or
    spine through it. Only the middle of the torso moves, easing out toward the arms, the neck and the waist, and only
    inward."""
    from mathutils.kdtree import KDTree
    zone = [v for v in bm.verts if abs(v.co.x) < 0.16 and 1.02 < v.co.z < 1.40]
    tree = KDTree(len(zone))
    for i, v in enumerate(zone):
        tree.insert(v.co, i)
    tree.balance()
    new = {}
    for v in zone:
        near = [zone[i] for _, i, _ in tree.find_range(v.co, radius) if (zone[i].co.y < 0) == (v.co.y < 0)]
        if not near:
            continue
        y = sum(n.co.y for n in near) / len(near)
        edge = min(1.0, (0.16 - abs(v.co.x)) / 0.04, (v.co.z - 1.02) / 0.05, (1.40 - v.co.z) / 0.05)
        # Only ever inward: the bumps go down, nothing moves out toward the carrier over the shirt.
        inward = (y - v.co.y) * (1.0 if v.co.y < 0 else -1.0) > 0
        if inward:
            new[v] = v.co.y + (y - v.co.y) * edge
    for v, y in new.items():
        v.co.y = y
    bm.normal_update()


def _wave(x: float) -> float:
    """A fold's profile: a soft ridge with a sharper valley, -1..1."""
    s = math.sin(x)
    return s if s > 0 else -abs(s) ** 0.6


def sleeve_folds(bm: bmesh.types.BMesh, r: dict) -> None:
    """Folds in the sleeves' geometry, big enough to read at play distance: a stack of compression folds above the
    cuff, deep creases in the crook of the elbow and a drape from the armpit across the upper arm. Pushed along the
    smoothed normals, inward no further than the sleeve's ease."""
    n = G.smooth_normals(bm, 2)
    moves = {}
    for v in bm.verts:
        p = v.co
        if abs(p.x) < SLEEVE_FROM - 0.02:
            continue
        s = "L" if p.x > 0 else "R"
        sx = 1.0 if s == "L" else -1.0
        sh, el = r["UpperArm_" + s]
        wr = r["Hand_" + s][0]
        fade = min(1.0, (abs(p.x) - (SLEEVE_FROM - 0.02)) / 0.04)
        fa = (el - wr).normalized()
        t = (p - wr).dot(fa)                     # up the forearm from the wrist
        rel = p - (wr + fa * t)
        ref = Vector((0.0, 0.0, 1.0)) - fa * fa.z
        ang = math.atan2(rel.cross(ref).dot(fa), rel.dot(ref.normalized())) if rel.length > 1e-6 else 0.0
        jitter = 0.6 * math.sin(3.1 * ang + 7.0 * t) + 0.4 * math.sin(5.3 * ang - 11.0 * t + sx)
        d = 0.0
        # Compression folds above the cuff, 6-8 cm of them.
        if SLEEVE_END + 0.025 < t < 0.16:
            k = math.sin(math.pi * (t - SLEEVE_END - 0.025) / (0.16 - SLEEVE_END - 0.025))
            d += 0.0042 * k * _wave(math.tau * t / 0.030 + 1.4 * math.sin(ang + sx) + jitter)
        # The elbow's crook: creases on the inside of the joint (the side away from the elbow's point).
        de = (p - el).length
        if de < 0.10:
            ua = (sh - el).normalized()
            inside = -(rel.normalized().dot((ua + fa).normalized())) if rel.length > 1e-6 else 0.0
            k = math.exp(-(de / 0.055) ** 2) * max(0.0, 0.35 + 0.65 * inside)
            d += 0.0060 * k * _wave(math.tau * de / 0.034 + 0.8 * jitter)
        # The drape: one or two diagonal folds from the armpit across the upper arm.
        ua = (el - sh).normalized()
        tu = (p - sh).dot(ua)
        ln = (el - sh).length
        if 0.03 < tu < ln - 0.02:
            k = math.sin(math.pi * tu / ln) * math.exp(-((tu / ln - 0.30) / 0.30) ** 2)
            d += 0.0040 * k * _wave(math.tau * (tu + 0.05 * ang) / 0.075 + 0.5 * jitter)
        if d:
            moves[v] = n[v] * (max(-0.0050, d) * fade)
    for v, m in moves.items():
        v.co += m
    bm.normal_update()


def trousers(verts, faces, r, dom) -> tuple:
    """The trousers (bmesh) and the surface their details are cast onto."""
    def keep(b: str, p) -> bool:
        return b == "Hips" or b.startswith(LEG_BONES) or (b in SHIRT_BONES and p[2] < WAIST_TOP + 0.05)
    bm = subset(verts, faces, dom, keep)
    G.cut(bm, Vector((0, 0, WAIST_TOP)), Vector((0, 0, 1)))
    G.cut(bm, Vector((0, 0, HEM)), Vector((0, 0, -1)))
    G.keep_largest(bm)
    G.relax(bm, rounds=4, amount=0.5)
    straight_legs(bm, r)
    # The lower legs at twice the density, for the knee creases and the stacked folds over the boots in the geometry.
    shins = [e for e in bm.edges if all(v.co.z < TROUSER_FOLDS_FROM for v in e.verts)]
    bmesh.ops.subdivide_edges(bm, edges=shins, cuts=1, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    knee_y = (r["Shin_L"][0].y + r["Shin_R"][0].y) * 0.5

    def ease(p: Vector) -> float:
        z = p.z
        if z > 0.97:
            return 0.006
        if z > 0.93:
            return 0.006 + 0.003 * (0.97 - z) / 0.04
        if z > 0.62:
            return 0.009 + 0.004 * (0.93 - z) / 0.31
        if z > 0.40:
            # Creases across the back of the knee, where the cloth bunches as it bends.
            back = min(1.0, max(0.0, (p.y - knee_y) / 0.03))
            crease = math.exp(-((z - 0.50) / 0.04) ** 2) * math.sin(math.tau * z / 0.019 + 40.0 * p.x)
            return 0.012 + 0.0024 * back * crease
        # Bloused over the boot's collar, gathered again at the hem, in stacked folds.
        blouse = math.exp(-((z - (HEM + 0.035)) / 0.035) ** 2)
        return 0.010 + 0.012 * blouse + 0.0035 * blouse * math.sin(math.tau * (z - HEM) / 0.024)
    G.offset(bm, ease)
    surf = G.Surface(bm)
    G.hem(bm, depth=0.020)
    return bm, surf


# Combat trousers hang as tubes from the thigh down: the least distance (m) of the cloth from each leg's line
# (hip joint to ankle) by height, and how far below the crotch the tube takes over.
LEG_TUBE = [(0.80, 0.084), (0.66, 0.075), (0.50, 0.063), (0.36, 0.056), (0.30, 0.054)]
TUBE_FROM = (0.80, 0.70)


def _tube_radius(z: float) -> float:
    pts = LEG_TUBE
    if z >= pts[0][0]:
        return pts[0][1]
    for (z0, r0), (z1, r1) in zip(pts, pts[1:]):
        if z1 <= z <= z0:
            return r1 + (r0 - r1) * (z - z1) / (z0 - z1)
    return pts[-1][1]


# Below BOOT_FIT[0] the legs close round the boots' shafts: an egg round the ankle (m ahead, behind and to the side,
# before the cloth's ease), blending from the tube over BOOT_FIT[0]..BOOT_FIT[1].
BOOT_FIT = (0.26, 0.32)
BOOT_EGG = (0.060, 0.050, 0.044)


def _boot_radius(d: Vector, fwd: Vector) -> float:
    """The egg's radius in the horizontal direction d (unit) round the ankle."""
    c = d.dot(fwd)
    s = d.cross(fwd).z
    a = BOOT_EGG[0] if c > 0 else BOOT_EGG[1]
    return 1.0 / math.sqrt((c / a) ** 2 + (s / BOOT_EGG[2]) ** 2)


def straight_legs(bm: bmesh.types.BMesh, r: dict) -> None:
    """Fill each trouser leg out to a tube round the leg's line (no calf, knee or shin shapes through the cloth), the
    inner thigh only part way (the crotch stays high), closing round the boot at the bottom; never past the body's
    mid-plane."""
    for v in bm.verts:
        z = v.co.z
        if z > TUBE_FROM[0] or abs(v.co.x) < 0.004:
            continue
        s = "L" if v.co.x > 0 else "R"
        sx = 1.0 if s == "L" else -1.0
        hip, ankle = r["Thigh_" + s][0], r["Shin_" + s][1]
        t = (z - ankle.z) / (hip.z - ankle.z)
        axis = ankle.lerp(hip, max(0.0, t))
        d = Vector((v.co.x - axis.x, v.co.y - axis.y, 0.0))
        rad = d.length
        if rad < 1e-6:
            continue
        dn = d / rad
        k = min(1.0, (TUBE_FROM[0] - z) / (TUBE_FROM[0] - TUBE_FROM[1]))
        tube = _tube_radius(z)
        if z > 0.55 and dn.x * sx < 0:
            tube *= 1.0 - 0.14 * (-dn.x * sx) * min(1.0, (z - 0.55) / 0.15)
        if z < BOOT_FIT[1]:
            toe = r["Toe_" + s][1]
            fwd = Vector((toe.x - ankle.x, toe.y - ankle.y, 0.0)).normalized()
            egg = _boot_radius(dn, fwd)
            f = min(1.0, max(0.0, (z - BOOT_FIT[0]) / (BOOT_FIT[1] - BOOT_FIT[0])))
            axis = Vector((ankle.x, ankle.y, z)).lerp(axis, f)
            d = Vector((v.co.x - axis.x, v.co.y - axis.y, 0.0))
            rad = max(1e-6, d.length)
            dn = d / rad
            tube = egg + (tube - egg) * f
            want = max(rad, tube)
        else:
            want = rad + max(0.0, tube - rad) * 0.85 * k
        p = axis + dn * want
        if (p.x > 0) != (v.co.x > 0) or abs(p.x) < 0.010:
            p.x = math.copysign(max(0.010, min(abs(p.x), abs(v.co.x))), v.co.x)
        v.co.x, v.co.y = p.x, p.y
    bm.normal_update()


def gloves(verts, faces, r, dom) -> tuple:
    """The gloves (bmesh) and the surface their details are cast onto."""
    def keep(b: str, p) -> bool:
        return b.startswith(HAND_BONES) or b.startswith("Forearm")
    bm = subset(verts, faces, dom, keep)
    for s in ("L", "R"):
        w, a = arm_axis(r, s)
        G.cut(bm, w - a * GLOVE_TOP, -a, near=(w, 0.25))
    # Twice the base mesh's density, smoothed, so the fingers are round, then decimated back to GLOVE_TRIS.
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True, smooth=1.0)
    G.relax(bm, rounds=3, amount=0.4)

    def ease(p: Vector) -> float:
        # A glove's thickness over the hand, its cuff standing a little off the wrist.
        best = 0.0022
        for s in ("L", "R"):
            w, a = arm_axis(r, s)
            if (p.x > 0) == (s == "L"):
                t = (w - p).dot(a)
                best = 0.0022 + 0.0016 * min(1.0, max(0.0, (t - 0.01) / 0.04))
        return best
    G.offset(bm, ease, rounds=1)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    G.decimate(bm, GLOVE_TRIS)
    surf = G.Surface(bm)
    G.hem(bm, depth=0.006)
    return bm, surf


def boots(r: dict) -> dict:
    """Both boots by paint region (boots.py)."""
    out = {k: bmesh.new() for k in ("boot", "sole", "boot_trim", "lace", "eyelet")}
    for s in ("L", "R"):
        fr = B.Frame(r["Foot_" + s][0], r["Toe_" + s][1], 1.0 if s == "L" else -1.0)
        up = B.upper(fr)
        G.hem(up, depth=0.010, roll=0.002)
        for dst, src in ((out["boot"], up), (out["sole"], B.sole(fr))):
            G.append(dst, src)
            src.free()
        for shell in (B.toe_cap(fr), B.heel_counter(fr)):
            G.add(out["boot_trim"], *shell)
        G.add(out["boot"], *B.tongue(fr))
        for shell in B.laces(fr):
            G.add(out["lace"], *shell)
        for shell in B.eyelets(fr):
            G.add(out["eyelet"], *shell)
    return out


def to_object(bm: bmesh.types.BMesh, name: str, colour: tuple) -> bpy.types.Object:
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    m = bpy.data.materials.new(name)
    m.diffuse_color = colour
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = colour
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    me.materials.append(m)
    return ob


def skin(ob: bpy.types.Object, rig: bpy.types.Object, src: bpy.types.Object) -> None:
    """Weight `ob` to the rig by the v12 body's weights (nearest face, interpolated): the clips were tuned on those."""
    for b in rig.data.bones:
        ob.vertex_groups.new(name=b.name)
    m = ob.modifiers.new("w", "DATA_TRANSFER")
    m.object = src
    m.use_vert_data = True
    m.data_types_verts = {"VGROUP_WEIGHTS"}
    m.vert_mapping = "POLYINTERP_NEAREST"
    m.layers_vgroup_select_src = "ALL"
    m.layers_vgroup_select_dst = "NAME"
    with bpy.context.temp_override(object=ob, active_object=ob):
        bpy.ops.object.modifier_apply(modifier=m.name)
    if ob.name in ("trousers", "pocket"):
        hem_to_shins(ob)
        smooth_knees(ob)
    with bpy.context.temp_override(object=ob, active_object=ob, selected_editable_objects=[ob]):
        bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
        bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    ob.parent = rig
    a = ob.modifiers.new("Armature", "ARMATURE")
    a.object = rig


def hem_to_shins(ob: bpy.types.Object) -> None:
    """The trousers' hem hangs from the shin, not the foot: the feet's and toes' weights move onto the shins, so a
    flexed foot (kneeling, crouching) does not drag the bloused hem into spikes."""
    groups = ob.vertex_groups
    for s in ("L", "R"):
        shin = groups.get("Shin_" + s)
        feet = [g for g in (groups.get("Foot_" + s), groups.get("Toe_" + s)) if g is not None]
        if shin is None or not feet:
            continue
        idx = {g.index for g in feet}
        for v in ob.data.vertices:
            moved = sum(e.weight for e in v.groups if e.group in idx)
            if moved > 0.0:
                shin.add([v.index], moved, "ADD")
                for g in feet:
                    g.remove([v.index])


def smooth_knees(ob: bpy.types.Object, rounds: int = 12) -> None:
    """Blur the weights round the knees (z KNEE_SMOOTH), every bone's together: next to the v12 knee pads the
    nearest-face transfer gives neighbouring vertices very different weights, which tears the cloth into spikes when
    the knee bends right over (kneeling)."""
    me = ob.data
    n, g = len(me.vertices), len(ob.vertex_groups)
    w = np.zeros((n, g))
    for v in me.vertices:
        for e in v.groups:
            w[v.index, e.group] = e.weight
    z = np.array([v.co.z for v in me.vertices])
    zone = (z > KNEE_SMOOTH[0]) & (z < KNEE_SMOOTH[1])
    ease = np.clip(np.minimum(z - KNEE_SMOOTH[0], KNEE_SMOOTH[1] - z) / 0.05, 0.0, 1.0) * zone
    a = np.array([e.vertices[:] for e in me.edges])
    deg = np.bincount(a.ravel(), minlength=n).astype(float)
    for _ in range(rounds):
        s = np.zeros_like(w)
        np.add.at(s, a[:, 0], w[a[:, 1]])
        np.add.at(s, a[:, 1], w[a[:, 0]])
        avg = s / np.maximum(deg, 1.0)[:, None]
        w = w + (avg - w) * (0.6 * ease)[:, None]
    for vg in ob.vertex_groups:
        col = w[:, vg.index]
        for i in np.nonzero(zone)[0]:
            if col[i] > 1e-4:
                vg.add([int(i)], float(col[i]), "REPLACE")
            else:
                vg.remove([int(i)])


def srgb(h: int) -> tuple:
    c = [((h >> s) & 255) / 255.0 for s in (16, 8, 0)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c) + (1.0,)


# The paint regions and their colours (sRGB): the combat shirt's olive sleeves, as the first-person arms' Sleeve and
# SleeveTrim (its darker body is bake.py's TORSO); the trousers, the coyote boots, the dark gloves (the owner's glove
# photos) and the team's armbands (painted in the team colour by the game).
REGIONS = {
    "shirt": 0x667052, "pocket_shirt": 0x667052, "trim": 0x515a41,
    "trousers": 0x8a7f62, "pocket": 0x8a7f62,
    "glove": 0x4c4638, "glove_armour": 0x242422, "glove_palm": 0x37342d, "glove_border": 0x5e5546,
    "boot": 0x74634e, "boot_trim": 0x5c4d3d, "sole": 0x3a3632, "lace": 0x3b3328, "eyelet": 0x2e2e2c,
    "snap": 0x3f3b33, "loop": 0x5d684a,
    "team": 0x3366ee,
}


def build(rig) -> dict:
    """Every part of the body by paint region, at rest on `rig`."""
    verts, faces, r, dom = anatomy.build(rig)
    parts = {k: bmesh.new() for k in REGIONS}

    def put(region: str, pieces: list) -> None:
        for v, f in pieces:
            G.add(parts[region], v, f)

    sh, sh_surf = shirt(verts, faces, r, dom)
    G.append(parts["shirt"], sh)
    sh.free()
    for k, v in D.shirt(sh_surf, r, SLEEVE_END).items():
        put(k, v)
    put("trim", [D.zip_pull(1.502, -0.0625, -0.0685)])

    tr, tr_surf = trousers(verts, faces, r, dom)
    G.append(parts["trousers"], tr)
    tr.free()
    for k, v in D.trousers(tr_surf, r).items():
        put(k, v)

    gl, gl_surf = gloves(verts, faces, r, dom)
    G.append(parts["glove"], gl)
    gl.free()
    for k, v in D.gloves(gl_surf, r).items():
        put(k, v)

    for k, bm in boots(r).items():
        G.append(parts[k], bm)
        bm.free()
    for bm in parts.values():
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return parts


ROUGH = {"boot": 0.82, "boot_trim": 0.7, "sole": 0.88, "lace": 0.8, "glove": 0.85, "glove_armour": 0.55,
         "glove_palm": 0.9, "glove_border": 0.8, "eyelet": 0.35, "snap": 0.5, "loop": 1.0,
         "team": 0.75}
TEAM_REGIONS = ("team",)
LOD_TRIS = (11000, 3300)
PADS_Z = (0.36, 0.72)   # the v12 knee pads' islands lie wholly between these heights


def rig_flat(r: dict) -> dict:
    """The rig's bone ends as name_h / name_t lists, for bake.py."""
    out = {}
    for k, (h, t) in r.items():
        out[k + "_h"] = list(h)
        out[k + "_t"] = list(t)
    return out


def join(objs: list, name: str) -> bpy.types.Object:
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = objs[0]
    ob.name = name
    ob.data.name = name
    return ob


def compose(baked: dict, low, names: list) -> dict:
    """The game's three maps from the bakes: colour under the body's occlusion; roughness by region."""
    col = baked["col"]
    ao = np.clip(baked["ao"], 0.0, 1.0)
    shade = 0.52 + 0.48 * ao
    out_col = np.clip(col * shade[:, :, None], 0.0, 1.0)
    # Roughness per region: paint each region's UV islands.
    size = ao.shape[0]
    from PIL import Image, ImageDraw
    img = Image.new("L", (size, size), int(0.9 * 255))
    draw = ImageDraw.Draw(img)
    uv = low.data.uv_layers.active.data
    for poly in low.data.polygons:
        reg = names[poly.material_index]
        if reg not in ROUGH:
            continue
        pts = [(uv[li].uv[0] * size, (1.0 - uv[li].uv[1]) * size) for li in poly.loop_indices]
        draw.polygon(pts, fill=int(ROUGH[reg] * 255), outline=int(ROUGH[reg] * 255))
    rough = np.asarray(img, dtype=np.float32) / 255.0
    orm = np.stack([np.ones_like(rough), rough, np.zeros_like(rough)], axis=2)
    return {"col": out_col, "nrm": baked["nrm"], "orm": orm}


def save_maps(maps: dict, folder: str) -> dict:
    from PIL import Image
    paths = {}
    os.makedirs(folder, exist_ok=True)
    for k, a in maps.items():
        p = os.path.join(folder, "body_%s.png" % k)
        Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)).save(p)
        paths[k] = p
    return paths


def game_material(name: str, paths: dict, team: bool = False) -> bpy.types.Material:
    m = bpy.data.materials.new(name)
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")

    def tex(key: str, colour: bool):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(paths[key], check_existing=True)
        n.image.colorspace_settings.name = "sRGB" if colour else "Non-Color"
        return n
    if team:
        # The game paints this material's colour (no colour map: the band is the team colour, lit by its normals).
        bsdf.inputs["Base Color"].default_value = (0.9, 0.9, 0.9, 1.0)
    else:
        c = tex("col", True)
        nt.links.new(c.outputs["Color"], bsdf.inputs["Base Color"])
    o = tex("orm", False)
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(o.outputs["Color"], sep.inputs[0])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    n = tex("nrm", False)
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(n.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def lod(ob, tris: int, name: str):
    c = ob.copy()
    c.data = ob.data.copy()
    c.name = name
    c.data.name = name
    bpy.context.scene.collection.objects.link(c)
    n = sum(len(p.vertices) - 2 for p in c.data.polygons)
    m = c.modifiers.new("d", "DECIMATE")
    m.ratio = tris / n
    m.use_collapse_triangulate = True
    m.vertex_group_factor = 0.0
    c.modifiers.move(len(c.modifiers) - 1, 0)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = c
    with bpy.context.temp_override(object=c, active_object=c):
        bpy.ops.object.modifier_apply(modifier="d")
    return c


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=HUMAN)
    rig = bpy.data.objects["Rig"]
    rig.data.pose_position = "REST"
    old = bpy.data.objects["Body"]
    old.name = "Body_v12"
    # The v12 body (still wearing the Outfit atlas) carries the knee pads; a rebuild over this body's own output
    # leaves them to Kit_Pads.
    if "Kit_Pads" not in bpy.data.objects and any(m.name == "Outfit" for m in old.data.materials):
        for n in ("Body", "Body_LOD1", "Body_LOD2"):
            src_ob = old if n == "Body" else bpy.data.objects[n]
            pads_from_v12(src_ob, "Kit_Pads" + n[4:])
    for n in ("Body_LOD1", "Body_LOD2"):
        bpy.data.objects.remove(bpy.data.objects[n])
    parts = build(rig)
    names = [k for k in REGIONS if parts[k].faces]
    objs = []
    for name in names:
        ob = to_object(parts[name], name, srgb(REGIONS[name]))
        skin(ob, rig, old)
        objs.append(ob)
    body = join(objs, "Body")
    print("Body", sum(len(p.vertices) - 2 for p in body.data.polygons), "tris")
    fast = "--fast" in sys.argv
    if not fast:
        import bake as K
        K.uv_unwrap(body)
        regions = dict(REGIONS)
        regions["team"] = 0xe6e6e6
        baked = K.bake_all(body, names, regions, rig_flat(anatomy.rig_points(rig)))
        maps = compose(baked, body, names)
        paths = save_maps(maps, OUT_MAPS)
        cloth = game_material("Clothing", paths)
        team = game_material("TeamCloth", paths, team=True)
        # Two slots: the cloth and the team paint.
        slot = np.array([1 if n in TEAM_REGIONS else 0 for n in names])
        idx = np.empty(len(body.data.polygons), dtype=np.int32)
        body.data.polygons.foreach_get("material_index", idx)
        body.data.materials.clear()
        body.data.materials.append(cloth)
        body.data.materials.append(team)
        body.data.polygons.foreach_set("material_index", slot[idx].astype(np.int32))
        body.data.update()
        for i, t in enumerate(LOD_TRIS):
            lod(body, t, "Body_LOD%d" % (i + 1))
    out = next((a for a in sys.argv[1:] if a.endswith(".blend")), None)
    if out:
        bpy.ops.wm.save_as_mainfile(filepath=out)
    donor = next((a for a in sys.argv[1:] if a.endswith(".glb")), None)
    if donor and not fast:
        export_donor(rig, donor)


def pads_from_v12(src, name: str) -> None:
    """The v12 body's knee pads and their straps (the islands wholly round the knees) as their own part, so a figure
    file without the pads thread's Kit_Pads keeps its pads; that thread's own Kit_Pads replaces it."""
    bm = bmesh.new()
    bm.from_mesh(src.data)
    mw = src.matrix_world
    seen, drop = set(), []
    for f in bm.faces:
        if f in seen:
            continue
        stack, isl = [f], []
        seen.add(f)
        while stack:
            g = stack.pop()
            isl.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen:
                        seen.add(h)
                        stack.append(h)
        zs = [(mw @ v.co).z for g in isl for v in g.verts]
        xs = [abs((mw @ v.co).x) for g in isl for v in g.verts]
        if not (min(zs) > PADS_Z[0] and max(zs) < PADS_Z[1] and min(xs) > 0.03):
            drop += isl
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in src.data.materials:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for vg in src.vertex_groups:
        ob.vertex_groups.new(name=vg.name)
    ob.parent = src.parent
    ob.matrix_world = mw
    a = ob.modifiers.new("Armature", "ARMATURE")
    a.object = src.parent


def export_donor(rig, path: str) -> None:
    """The armature and the three Body levels alone, for splice_part.py to put into human.glb."""
    keep = {"Rig", "Body", "Body_LOD1", "Body_LOD2", "Kit_Pads", "Kit_Pads_LOD1", "Kit_Pads_LOD2"}
    for o in list(bpy.data.objects):
        if o.name not in keep:
            bpy.data.objects.remove(o)
    for o in bpy.context.scene.objects:
        o.select_set(True)
    rig.data.pose_position = "POSE"
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_skins=True,
                              export_animations=False, export_image_format="WEBP", export_image_quality=92,
                              export_yup=True, export_morph=False, export_tangents=False)


if __name__ == "__main__":
    main()
