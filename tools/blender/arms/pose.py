"""Posing the first-person arms (BL4): the armature, skinning, the rig's forward kinematics, the arm's two-bone reach
and the contact solver that closes each finger onto a replica's surface without passing into it."""

import math
import os

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

from glove import FINGER_NAMES, PARENT, Frame, Mesh, seg_dist

# Each side's shoulder joint (eye space: +X right, +Y forward, +Z up); arms.py sets them.
SHOULDER = {}
# A finger stops this far short of the replica's surface (m): touching, never through.
CONTACT = 0.0008
# How far the thumb's base swings each way (deg): past this, plain linear skinning folds the glove at its web.
THUMB_SWING = 30
# The thumb search's finer step round its best (degrees).
THUMB_FINE = 5
# How much of each finger's splay from the middle finger a hold takes out.
ADDUCT = {2: 0.9, 4: 0.9, 5: 0.95}


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


def skin_object(name: str, mesh: Mesh, arm: bpy.types.Object, side: str, names: list) -> bpy.types.Object:
    sx = to_side(side)
    verts = [sx(v) for v in mesh.v]
    faces = mesh.f if side == "L" else [list(reversed(f)) for f in mesh.f]
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
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


def rot_between(a: Vector, b: Vector) -> Matrix:
    return a.normalized().rotation_difference(b.normalized()).to_matrix()


def fit_turn(rest: list, at: list) -> Matrix:
    """The rotation that best turns the points `rest` onto `at` about their centres (least squares, Kabsch)."""
    import numpy as np
    a = np.array([tuple(p) for p in rest])
    b = np.array([tuple(p) for p in at])
    h = (a - a.mean(0)).T @ (b - b.mean(0))
    u, _, vt = np.linalg.svd(h)
    d = np.sign(np.linalg.det(vt.T @ u.T))
    r = vt.T @ np.diag((1.0, 1.0, d)) @ u.T
    return Matrix([tuple(row) for row in r])


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
        # Each bone moved this far (eye space) from where its parent puts it: a hold's own shoulder.
        self.shift = {}
        self.drop = {}
        self.across = {}

    def fk(self, name: str, local_rot: Matrix = None) -> Matrix:
        """Poses a bone from its parent's pose, turned by `local_rot` in its own frame."""
        p = self.parent[name]
        self.local[name] = local_rot.copy() if local_rot is not None else Matrix.Identity(3)
        m = self.pose[p] @ self.rest[p].inverted() @ self.rest[name] @ self.local[name].to_4x4()
        if name in self.shift:
            m = Matrix.Translation(self.shift[name]) @ m
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
    """What a hand closes onto: the replica's surface, and for a hand wrapping the other, that hand's posed skin."""

    def __init__(self, objects: list, evaluated: bool = False):
        verts, polys = [], []
        dg = bpy.context.evaluated_depsgraph_get() if evaluated else None
        for ob in objects:
            base = len(verts)
            mw = ob.matrix_world
            ev = ob.evaluated_get(dg) if evaluated else ob
            me = ev.to_mesh() if evaluated else ob.data
            verts += [mw @ v.co for v in me.vertices]
            polys += [[base + i for i in p.vertices] for p in me.polygons]
            if evaluated:
                ev.to_mesh_clear()
        self.verts, self.polys = verts, polys
        self.tree = BVHTree.FromPolygons(verts, polys)
        self.parts = [self]

    @staticmethod
    def posed(objects: list) -> "Collider":
        """The skin of `objects` as their armature poses it now."""
        return Collider(objects, True)

    @staticmethod
    def joined(*cols: "Collider") -> "Collider":
        out = Collider([])
        out.parts = [p for c in cols for p in c.parts]
        return out

    def dist(self, p: Vector) -> float:
        """Distance to the nearest surface; negative inside it."""
        best = 9.0
        for part in self.parts:
            hit = part.tree.find_nearest(p)
            if hit[0] is None:
                continue
            d = hit[3] if (p - hit[0]).dot(hit[1]) >= 0.0 else -hit[3]
            if abs(d) < abs(best):
                best = d
        return best


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
        # The palm's own skin: the hand bone's, short of the knuckles (the fingers' roots are open while it seats).
        wrist = sx(fr.wrist)
        reach = min((sx(k) - wrist).dot(self.fingers) for k in fr.knuckles) - 0.012
        self.palm = [hand_rest.inverted() @ sx(v) for v, w in zip(mesh.v, mesh.w)
                     if w.get("Hand", 0.0) > 0.85 and (sx(v) - wrist).dot(self.fingers) < reach]
        self.palm = [p for k, p in enumerate(self.palm) if k % max(1, len(self.palm) // 800) == 0]
        self.radius, self.axis, self.adduct, self.points = {}, {}, {}, {}
        # The whole hand bone's glove (the knuckles and the heel of the thumb too), for seating it clear.
        whole = [hand_rest.inverted() @ sx(v) for v, w in zip(mesh.v, mesh.w) if w.get("Hand", 0.0) > 0.45]
        self.points["Hand_" + side] = [q for i, q in enumerate(whole) if i % max(1, len(whole) // 300) == 0]
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

    def seat(self, hand_m: Matrix, toward: Vector, col: Collider, whole: bool = False) -> Matrix:
        """Slides the hand along `toward` until the palm rests on the rifle without passing into it (with `whole`,
        nor any of the hand bone's glove: its knuckles and the heel of the thumb)."""
        d = toward.normalized()
        bone = self.points["Hand_" + self.side]

        def gap(m: Matrix) -> float:
            g = self.gap(m, col)
            return min(g, min(col.dist(m @ q) for q in bone)) if whole else g

        for _ in range(150):
            if gap(hand_m) >= 0.0002:
                break
            hand_m = Matrix.Translation(-d * 0.0004) @ hand_m
        for _ in range(100):
            g = gap(hand_m)
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

    def thumb(self, col: Collider, ratio: tuple, limit: tuple, target: Vector = None, hug: float = 0.0,
              swing: int = THUMB_SWING, twists: tuple = (-30, 0, 30)) -> list:
        """Swings the thumb at its base (across the palm, round its own line and in its bend) to the clear place
        nearest the rifle (and, given a `target`, with its tip nearest that; with `hug`, its whole length kept close
        to the rifle too; `swing` and `twists` bound its turns at the base, degrees), then curls its tip bones onto
        it."""
        b1, b2, b3 = ("Thumb%d_%s" % (k, self.side) for k in (1, 2, 3))
        inv = self.rig.rest[b1].to_3x3().inverted()
        across = inv @ self.palmar
        twist = Vector((0.0, 1.0, 0.0))

        def score_at(a: int, c: int, t: int) -> tuple:
            rot = (Matrix.Rotation(math.radians(c), 3, across) @ Matrix.Rotation(math.radians(t), 3, twist)
                   @ Matrix.Rotation(math.radians(a), 3, self.axis[b1]))
            self.rig.fk(b1, rot)
            self.rig.fk(b2)
            self.rig.fk(b3)
            gaps = [self.clearance(b, col) for b in (b1, b2, b3)]
            # Its root may rest on the grip (the web of the hand on the back strap), never pass into it.
            clear = min(gaps[0] + CONTACT, gaps[1], gaps[2])
            # Clear of the rifle first; then as close to it as can be, with the least swing.
            score = (0.0 if clear >= CONTACT else 1.0 + (CONTACT - clear)) + clear * 2.0 + \
                0.0003 * (abs(a) + abs(c) + abs(t)) / 10.0
            if hug:
                score += hug * sum(max(g, 0.0) for g in gaps[1:]) / 2.0
            if target is not None:
                m = self.rig.pose[b3]
                score += (m.translation + m.to_3x3().col[1] * self.rig.length[b3] - target).length * 3.0
            return score, rot, a, c, t

        best = None
        for a in range(-swing, swing + 1, 10):
            for c in range(-80, 85, 10):
                for t in twists:
                    found = score_at(a, c, t)
                    if best is None or found[0] < best[0]:
                        best = found
        # Then finer round the best, within the same bounds.
        a0, c0, t0 = best[2:]
        for a in range(max(-swing, a0 - 10), min(swing, a0 + 10) + 1, THUMB_FINE):
            for c in range(max(-80, c0 - 10), min(80, c0 + 10) + 1, THUMB_FINE):
                for t in range(max(min(twists), t0 - 15), min(max(twists), t0 + 15) + 1, THUMB_FINE):
                    found = score_at(a, c, t)
                    if found[0] < best[0]:
                        best = found
        self.adduct[b1] = best[1]
        if os.environ.get("BL_DEBUG"):
            print("   thumb search: score %.4f at %s" % (best[0], best[2:]))
        out = self.close("Thumb", col, (0.0, ratio[1], ratio[2]), (0.0, limit[1], limit[2]))
        return list(best[2:]) + out[1:]

    def settle(self, name: str, start: tuple, col: Collider, span: int = 30, swing: float = 0.0,
               root: bool = False) -> list:
        """Poses a finger at its authored bends `start` (degrees, base to tip; its base swung `swing` degrees
        sideways), then curls it further or opens it, its three joints together and the tip a little less, until it
        rests on the replica: the most curl within `span` of the authored pose that stays clear of it. With `root`,
        its first bone may rest on the replica (a palm cupped round a handguard), never pass into it."""
        bones = ["%s%d_%s" % (name, k, self.side) for k in (1, 2, 3)]
        side_axis = self.axis[bones[0]].cross(Vector((0.0, 1.0, 0.0))).normalized()

        def apply(t: float) -> list:
            angles = [max(-15.0, start[0] + t), max(0.0, start[1] + t), max(0.0, start[2] + 0.7 * t)]
            for k, ang in enumerate(angles):
                rot = Matrix.Rotation(math.radians(ang), 3, self.axis[bones[k]])
                if k == 0 and swing:
                    rot = Matrix.Rotation(math.radians(swing), 3, side_axis) @ rot
                self.rig.fk(bones[k], self.adduct[bones[k]] @ rot if bones[k] in self.adduct else rot)
            return angles

        for t in range(span, -3 * span - 1, -2):
            angles = apply(t)
            if not (self.clearance(bones[0], col) < (0.0 if root else CONTACT)
                    or any(self.touches(b, col) for b in bones[1:])):
                return [round(a) for a in angles]
        print("  ! the %s finger can't clear the replica %s" % (name, [round(self.clearance(b, col) * 1000, 1)
                                                                    for b in bones]))
        return [round(a) for a in angles]

    def thumb_at(self, base: tuple, bends: tuple, col: Collider, span: int = 20) -> list:
        """Poses the thumb: its base turned `base` (degrees: across the palm, round its own line, in its bend), its
        two tip joints bent `bends`, then settled onto the replica as `settle` does."""
        b1 = "Thumb1_" + self.side
        inv = self.rig.rest[b1].to_3x3().inverted()
        across = inv @ self.palmar
        self.adduct[b1] = (Matrix.Rotation(math.radians(base[0]), 3, across)
                           @ Matrix.Rotation(math.radians(base[1]), 3, Vector((0.0, 1.0, 0.0)))
                           @ Matrix.Rotation(math.radians(base[2]), 3, self.axis[b1]))
        return self.settle("Thumb", (0.0, bends[0], bends[1]), col, span)

    def onto(self, name: str, target: Vector, col: Collider, limits: tuple, swing: int = 20) -> list:
        """Bends a finger so its last bone's pad comes to `target` (the trigger) without passing into the replica: a
        search over its three bends and its base's swing sideways (up to `swing` degrees), coarse then fine."""
        bones = ["%s%d_%s" % (name, k, self.side) for k in (1, 2, 3)]
        side_axis = self.axis[bones[0]].cross(Vector((0.0, 1.0, 0.0))).normalized()

        def apply(lat: float, a: tuple) -> None:
            for k, ang in enumerate(a):
                rot = Matrix.Rotation(math.radians(ang), 3, self.axis[bones[k]])
                if k == 0:
                    rot = Matrix.Rotation(math.radians(lat), 3, side_axis) @ rot
                self.rig.fk(bones[k], self.adduct[bones[k]] @ rot if bones[k] in self.adduct else rot)

        def score(lat: float, a: tuple) -> tuple:
            apply(lat, a)
            clear = min(self.clearance(b, col) for b in bones)
            m = self.rig.pose[bones[2]]
            pad = min((m @ q - target).length for q in self.points[bones[2]])
            # Clear of the replica first, then the pad nearest the target.
            return pad + (0.0 if clear >= CONTACT else 1.0 + (CONTACT - clear) * 10.0), clear

        best = None
        for lat in range(-swing, swing + 1, 10):
            for a1 in range(-10, limits[0] + 1, 10):
                for a2 in range(0, limits[1] + 1, 10):
                    for a3 in range(0, limits[2] + 1, 10):
                        sc, clear = score(lat, (a1, a2, a3))
                        if best is None or sc < best[0]:
                            best = (sc, [lat, a1, a2, a3], clear)
        step = 4.0
        while step >= 1.0:
            moved = False
            for k in range(4):
                for sgn in (-1.0, 1.0):
                    trial = list(best[1])
                    trial[k] += sgn * step
                    if k == 0 and abs(trial[0]) > swing:
                        continue
                    sc, clear = score(trial[0], tuple(trial[1:]))
                    if sc < best[0]:
                        best = (sc, trial, clear)
                        moved = True
            if not moved:
                step *= 0.5
        apply(best[1][0], tuple(best[1][1:]))
        if best[2] < CONTACT:
            print("  ! the %s finger passes %.1f mm into the replica reaching its mark" % (
                name, (CONTACT - best[2]) * 1e3))
        print("  %s finger on its mark: pad %.1f mm off" % (name, (best[0] if best[2] >= CONTACT else -1) * 1e3))
        return [round(x) for x in best[1]]

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
        if sum(ang) < math.radians(30.0):
            ang = self.wrap(bones, limit, apply, ang, col)
        return [round(math.degrees(a)) for a in ang]

    def wrap(self, bones: list, limit: tuple, apply, ang: list, col: Collider) -> list:
        """A finger the joint-by-joint curl left straight (its tip met the rifle as it swung): every bend of its three
        joints, curled together as a hand does, kept clear of the rifle and as close round it as can be."""
        best = None
        for a0 in range(-10, int(math.degrees(limit[0])) + 1, 5):
            # The middle joint bends about as far as the base, the tip a little less: a finger curls as one.
            for a1 in range(max(0, a0 - 15), min(int(math.degrees(limit[1])), a0 + 25) + 1, 5):
                for a2 in range(int(a1 * 0.6), min(int(math.degrees(limit[2])), a1) + 1, 5):
                    ang[:] = [math.radians(a0), math.radians(a1), math.radians(a2)]
                    apply()
                    clear = [self.clearance(b, col) for b in bones]
                    if min(clear) < CONTACT:
                        continue
                    # Close round the rifle, joints bent alike (a hand's fingers curl together).
                    score = sum(clear) + 0.0002 * (abs(a1 - a0) + abs(a2 - 0.8 * a1)) / 5.0
                    if best is None or score < best[0]:
                        best = (score, list(ang))
        if best is not None:
            ang[:] = best[1]
        apply()
        return ang


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
    rig.fk(up)
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



def wrist_bend(rig: Rig, side: str) -> float:
    """The wrist's bend from its rest line (degrees)."""
    fo, hn = "Forearm_" + side, "Hand_" + side
    rest = rig.rest[fo].to_3x3().inverted() @ rig.rest[hn].to_3x3()
    pose = rig.pose[fo].to_3x3().inverted() @ rig.pose[hn].to_3x3()
    return math.degrees((rest.inverted() @ pose).to_quaternion().angle)


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


# The last pass's steps: each finger's curl (degrees at its root; the middle joint as much, the tip TIGHTEN_TIP of it)
# and how far it may close in all.
TIGHTEN_STEP = 1.5
TIGHTEN_MAX = 24.0
TIGHTEN_TIP = 0.7
TIGHTEN_SHARES = (1.0, 1.0, TIGHTEN_TIP)


def skin_gaps(objects: list, solid: list, side: str) -> dict:
    """The nearest the skinned glove of each bone of `side`'s hand comes to the replica (mm), for the log."""
    dg = bpy.context.evaluated_depsgraph_get()
    col = Collider(solid)
    out = {}
    for ob in objects:
        if not ob.name.endswith("_" + side):
            continue
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        names = {g.index: g.name for g in ob.vertex_groups}
        for v, sv in zip(me.vertices, ob.data.vertices):
            g = max(sv.groups, key=lambda x: x.weight, default=None)
            if g is None:
                continue
            b = names[g.group]
            if b.startswith(("UpperArm", "Forearm", "Shoulder")):
                continue
            d = col.dist(ob.matrix_world @ v.co)
            if d < out.get(b, 9.0):
                out[b] = d
        ev.to_mesh_clear()
    return {b.rsplit("_", 1)[0]: round(d * 1000, 1) for b, d in sorted(out.items())}


PRESS_STEP = 0.0004
PRESS_MAX = 0.008


def press(rig: Rig, hands: dict, objects: list, solid: list, poles: dict, side: str) -> float:
    """Moves `side`'s hand into its palm, toward the replica, a step at a time until its skin would first touch it,
    and stops a step short: the palm seated on the grip, not standing off it. How far it moved (m)."""
    h = hands[side]
    moved = 0.0
    while moved + PRESS_STEP <= PRESS_MAX:
        before = rig.pose["Hand_" + side].copy()
        m = Matrix.Translation(h.normal * PRESS_STEP) @ before
        place_arm(rig, side, m, poles[side], quiet=True)
        rig.refresh("Hand_" + side)
        rig.write()
        if clipping(objects, solid)[0]:
            place_arm(rig, side, before, poles[side], quiet=True)
            rig.refresh("Hand_" + side)
            break
        moved += PRESS_STEP
    rig.write()
    return moved


def tighten(rig: Rig, hands: dict, objects: list, solid: list, fingers: list) -> dict:
    """Closes each finger of `fingers` (("R", "Middle"), ...) onto the replica on the skinned surface itself: all of
    them curl a step at a time, and each stops a step short of where its glove would first touch (the owner: gripped
    tight, never clipping). The bone-sampled solve leaves gaps the skin doesn't need. Degrees each closed, for the
    log."""
    closed = {f: 0.0 for f in fingers}
    live = set(fingers)
    while live:
        turned = []
        for side, name in sorted(live):
            if closed[(side, name)] + TIGHTEN_STEP > TIGHTEN_MAX:
                live.discard((side, name))
                continue
            for k, share in zip((1, 2, 3), TIGHTEN_SHARES):
                bone = "%s%d_%s" % (name, k, side)
                turn = Matrix.Rotation(math.radians(TIGHTEN_STEP * share), 3, hands[side].axis[bone])
                rig.fk(bone, rig.local[bone] @ turn)
                rig.refresh(bone)
            closed[(side, name)] += TIGHTEN_STEP
            turned.append((side, name))
        if not turned:
            break
        rig.write()
        hits, tally = clipping(objects, solid)
        if not hits:
            continue
        # A clip on a bone no turned finger owns (the trigger finger, the arm) stops every finger that just turned.
        owned = {b for b in tally if any(b.startswith(n) and b.endswith("_" + sd) for sd, n in turned)}
        stray = bool(set(tally) - owned)
        for side, name in turned:
            mine = [b for b in tally if b.startswith(name) and b.endswith("_" + side)]
            if mine or stray:
                for k, share in reversed(list(zip((1, 2, 3), TIGHTEN_SHARES))):
                    bone = "%s%d_%s" % (name, k, side)
                    turn = Matrix.Rotation(math.radians(-TIGHTEN_STEP * share), 3, hands[side].axis[bone])
                    rig.fk(bone, rig.local[bone] @ turn)
                    rig.refresh(bone)
                closed[(side, name)] -= TIGHTEN_STEP
                live.discard((side, name))
    rig.write()
    return {"%s %s" % f: round(a, 1) for f, a in closed.items()}


# The wrap's step: the root joint closes WRAP_STEP while the middle joint and the tip open by their share of it, so
# the finger's first section comes down onto the grip and its end stays where it rests.
WRAP_STEP = 1.5
WRAP_MAX = 30.0
WRAP_OPEN = (0.6, 0.4)


def _turn_finger(rig: Rig, hands: dict, side: str, name: str, shares: tuple, step: float) -> None:
    for k, share in zip((1, 2, 3), shares):
        if share:
            bone = "%s%d_%s" % (name, k, side)
            rig.fk(bone, rig.local[bone] @ Matrix.Rotation(math.radians(step * share), 3, hands[side].axis[bone]))
            rig.refresh(bone)


def wrap(rig: Rig, hands: dict, objects: list, solid: list, fingers: list) -> dict:
    """After `tighten`, lays each finger's first section onto the replica: its root joint closes while the joints
    past it open (WRAP_OPEN), a step at a time, until its glove would first touch. A tightened finger touches with its
    end; this brings its whole length down (the critic: first sections standing off the grip). Degrees each wrapped."""
    shares = (1.0, -WRAP_OPEN[0], -WRAP_OPEN[1])
    back = tuple(-x for x in shares)
    done = {}
    for side, name in fingers:
        n = 0.0
        while n + WRAP_STEP <= WRAP_MAX:
            _turn_finger(rig, hands, side, name, shares, WRAP_STEP)
            rig.write()
            if clipping(objects, solid)[0]:
                _turn_finger(rig, hands, side, name, back, WRAP_STEP)
                break
            n += WRAP_STEP
        rig.write()
        done["%s %s" % (side, name)] = n
    return done


def relax(rig: Rig, hands: dict, objects: list, solid: list, poles: dict) -> int:
    """Settles the hold on the skinned surface itself: a finger still touching the rifle opens a little at that
    joint, a palm still pressing in eases back (its thumb waits until it has, or the thumb would swing out from the
    grip when it is the web of the hand pressing in); until nothing passes into the rifle."""
    hits = 0
    turned = {}
    for _ in range(60):
        rig.write()
        hits, tally = clipping(objects, solid)
        if not hits:
            break
        last = tally
        moved = set()
        for bone in tally:
            name, side = bone.rsplit("_", 1)
            if name in ("Hand", "Forearm", "UpperArm"):
                if side in moved:
                    continue
                moved.add(side)
                h = hands[side]
                m = Matrix.Translation(-h.normal * 0.0004) @ rig.pose["Hand_" + side]
                place_arm(rig, side, m, poles[side], quiet=True)
                rig.refresh("Hand_" + side)
            elif bone.startswith("Thumb") and any(b in tally for b in ("Hand_" + side, "Forearm_" + side)):
                # The thumb's root is the web of the hand: let the hand ease back first.
                continue
            elif bone in hands[side].axis:
                turned[bone] = turned.get(bone, 0) + 1
                turn = Matrix.Rotation(math.radians(-1.5), 3, hands[side].axis[bone])
                rig.fk(bone, rig.local[bone] @ turn)
                rig.refresh(bone)
    if os.environ.get("BL_DEBUG"):
        print("   relaxed:", turned)
    if hits:
        print("  still passing into the replica:", sorted(last.items(), key=lambda x: -x[1]))
    return hits
