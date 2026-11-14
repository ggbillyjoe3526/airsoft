"""Posing the first-person arms (BL4): the armature, skinning, the rig's forward kinematics, the arm's two-bone reach
and the contact solver that closes each finger onto a replica's surface without passing into it."""

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

import sight
from glove import FINGER_NAMES, HEEL, HEEL_TWIST, PARENT, Frame, Mesh, seg_dist

# The thumb's first bone, whose heel bone (glove.HEEL) follows it.
THUMB_ROOT = "Thumb1_"

# Each side's shoulder joint (eye space: +X right, +Y forward, +Z up); arms.py sets them.
SHOULDER = {}
# A finger stops this far short of the replica's surface (m): touching, never through.
CONTACT = 0.0008
# How far the thumb's base swings each way (deg): past this, plain linear skinning folds the glove at its web.
THUMB_SWING = 30
# The thumb search's finer step round its best (degrees).
THUMB_FINE = 5
# How many of its turns nearest the target a thumb checked on its skinned glove (`Hand.thumb`'s `verify`) tries.
THUMB_VERIFY = 800
# A point read as further inside a replica than this (m) is checked by rays (`Collider.inside`): the nearest face's
# normal alone misreads points beside a convex corner, a few centimetres out, as deep inside (GS2's AEG beside its
# trigger guard, the model before it to the grip's right), which threw the hand off the grip.
DEEP = 0.004
# A trigger finger asked to arch (`Hand.index_arc`) bends this share of its middle joint's bend at its tip.
ARC_TIP = 0.5
# A finger turned about its own line at the knuckle (`Hand.onto`'s `cup`) keeps the turn only if it scores this much
# better (m) than the smaller turn tried before it.
CUP_GAIN = 0.0005
# The rays' directions for that check: a point is inside when most first hits strike a face from behind.
RAYS = (Vector((0.577, 0.577, 0.577)), Vector((-0.577, 0.577, -0.577)), Vector((0.577, -0.577, -0.577)))
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
        self.plan = {}

    def fk(self, name: str, local_rot: Matrix = None) -> Matrix:
        """Poses a bone from its parent's pose, turned by `local_rot` in its own frame."""
        p = self.parent[name]
        self.local[name] = local_rot.copy() if local_rot is not None else Matrix.Identity(3)
        m = self.pose[p] @ self.rest[p].inverted() @ self.rest[name] @ self.local[name].to_4x4()
        if name in self.shift:
            m = Matrix.Translation(self.shift[name]) @ m
        self.pose[name] = m
        if name.startswith(THUMB_ROOT):
            # The heel of the thumb goes with it: the same swing, a share of its turn about its own line.
            q = self.local[name].to_quaternion()
            turn = Quaternion((q.w, 0.0, q.y, 0.0))
            turn = turn.normalized() if turn.magnitude > 1e-9 else Quaternion()
            part = (q @ turn.inverted()) @ Quaternion().slerp(turn, HEEL_TWIST)
            self.fk(HEEL + name[len(THUMB_ROOT) - 1:], part.to_matrix())
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

    def inside(self, p: Vector) -> bool:
        """Whether `p` is inside this surface: most of RAYS' first hits strike a face from behind."""
        behind = 0
        for d in RAYS:
            hit = self.tree.ray_cast(p, d, 1.0)
            if hit[0] is not None and hit[1].dot(d) > 0.0:
                behind += 1
        return behind * 2 > len(RAYS)

    def dist(self, p: Vector) -> float:
        """Distance to the nearest surface; negative inside it."""
        best = 9.0
        for part in self.parts:
            hit = part.tree.find_nearest(p)
            if hit[0] is None:
                continue
            d = hit[3] if (p - hit[0]).dot(hit[1]) >= 0.0 else -hit[3]
            if d < -DEEP and not part.inside(p):
                d = -d
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
        # The height (eye space) no finger's glove may rise above: a support hand's fingers rest on the handguard's
        # side, their tips below its top (the critic: no tip showing over it from the left). None: no limit.
        self.tip_top = None
        # Where the game's eye may stand as a support hand's fingers are laid (eye space) and the replica that hides
        # them from it (`sight.seen`): no finger may show past the handguard's far side. Empty: not judged.
        self.eyes, self.screen = (), None
        # The replica's right (a direction and a point on its middle, eye space): only a finger's glove
        # sight.SEEN_FAR m or more to that side of the middle is judged. None: all of it.
        self.far = None
        # How far forward a support hand's fingers may reach: a direction (eye space) and the furthest any of a
        # finger's glove may lie along it (m), the handguard's front end. None: no limit.
        self.front, self.front_hard = None, False
        # The fingers already laid (each of their last two bones' ends) and how far (m) apart the next keeps its own
        # from them (`sight.crowd`).
        self.laid, self.apart, self.row = [], 0.0, []
        # The furthest left (eye space) the trigger finger's outer bones may reach (`onto`). None: no limit.
        self.index_left = None
        # How far the trigger finger's joints may bend reaching the trigger (degrees, base to tip; `onto`).
        self.index_bends = (70, 90, 70)
        # The least its base may bend (degrees; below 0 it lifts off the frame's side).
        self.index_from = -10
        # The bend its middle joint is drawn to and what each degree off it costs (m), so it arches (`onto`). None:
        # wherever its pad comes nearest.
        self.index_arc = None
        # Whether the trigger finger's coarse search forgives passing into the replica (`onto_search`).
        self.index_soft = False
        # How far down the trigger (a share of its height, top to tip) the trigger finger's pad rests.
        self.trigger_at = 0.55
        # The whole hand bone's glove (the knuckles and the heel of the thumb too), for seating it clear.
        whole = [hand_rest.inverted() @ sx(v) for v, w in zip(mesh.v, mesh.w) if w.get("Hand", 0.0) > 0.45]
        self.points["Hand_" + side] = [q for i, q in enumerate(whole) if i % max(1, len(whole) // 300) == 0]
        mid = (sx(j["finger-3-2"]) - sx(j["finger-3-1"])).normalized()

        def share(w: dict, name: str, k: int) -> float:
            # The heel of the thumb's skin is its first bone's, for where that bone's surface lies.
            b = "%s%d" % (name, k)
            return w.get(b, 0.0) + (w.get(HEEL, 0.0) if b + "_" == THUMB_ROOT else 0.0)

        for f, name in FINGER_NAMES.items():
            for k in (1, 2, 3):
                b = "%s%d_%s" % (name, k, side)
                h, t = sx(j["finger-%d-%d" % (f, k)]), sx(j["finger-%d-%d" % (f, k + 1)])
                ds = sorted(seg_dist(sx(v), h, t) for v, w in zip(mesh.v, mesh.w) if share(w, name, k) > 0.7)
                self.radius[b] = (ds[int(len(ds) * 0.85)] if ds else 0.008) + 0.0004
                inv = rig.rest[b].inverted()
                pts = [inv @ sx(v) for v, w in zip(mesh.v, mesh.w) if share(w, name, k) > 0.45]
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

    def over(self, name: str) -> float:
        """How far the finger's last two sections' glove rises above `tip_top` (m; 0 when under it or no limit)."""
        if self.tip_top is None or name == "Thumb":
            return 0.0
        high = max((self.rig.pose[b] @ q).z for b in ("%s%d_%s" % (name, k, self.side) for k in (2, 3))
                   for q in self.points[b])
        return max(0.0, high - self.tip_top)

    def thumb(self, col: Collider, ratio: tuple, limit: tuple, target: Vector = None, hug: float = 0.0,
              swing: int = THUMB_SWING, twists: tuple = (-30, 0, 30), bends: tuple = (0,), pull: float = 3.0,
              verify=None, pin: tuple = None) -> list:
        """Swings the thumb at its base (across the palm, round its own line and in its bend) to the clear place
        nearest the rifle (and, given a `target`, with its tip nearest that; with `hug`, its whole length kept close
        to the rifle too; `swing` and `twists` bound its turns at the base, degrees; `bends`, the knuckle bends tried
        with each, so it can turn round a grip's corner; `pull`, how much its tip's distance from `target` counts), then
        curls its tip bones onto it from there. Given `verify` (a check of the skinned glove itself: how many of the
        thumb's faces pass into the replica), the THUMB_VERIFY turns whose tips come nearest the target are tried in that
        order and the first whose glove stays clear is kept: the bones'
        sampled surface can pass a pose whose glove, swung far round the grip's corner, still cuts into it. Given `pin`
        (across, twist, bend, knuckle: a turn the owner approved), the thumb takes that turn and no search runs."""
        b1, b2, b3 = ("Thumb%d_%s" % (k, self.side) for k in (1, 2, 3))
        inv = self.rig.rest[b1].to_3x3().inverted()
        across = inv @ self.palmar
        twist = Vector((0.0, 1.0, 0.0))

        def score_at(a: int, c: int, t: int, k: int = 0) -> tuple:
            rot = (Matrix.Rotation(math.radians(c), 3, across) @ Matrix.Rotation(math.radians(t), 3, twist)
                   @ Matrix.Rotation(math.radians(a), 3, self.axis[b1]))
            self.rig.fk(b1, rot)
            self.rig.fk(b2, Matrix.Rotation(math.radians(k), 3, self.axis[b2]))
            self.rig.fk(b3, Matrix.Rotation(math.radians(k * 0.5), 3, self.axis[b3]))
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
                reach[(a, c, t, k)] = (m.translation + m.to_3x3().col[1] * self.rig.length[b3] - target).length
                score += reach[(a, c, t, k)] * pull
            return score, rot, a, c, t, k

        tried, reach = [], {}
        if pin is not None:
            best = score_at(*(int(round(v)) for v in pin))
        else:
            best = None
            for a in range(-swing, swing + 1, 10):
                for c in range(-80, 85, 10):
                    for t in twists:
                        for k in bends:
                            found = score_at(a, c, t, k)
                            tried.append(found)
                            if best is None or found[0] < best[0]:
                                best = found
            # Then finer round the best, within the same bounds.
            a0, c0, t0, k0 = best[2:6]
            for a in range(max(-swing, a0 - 10), min(swing, a0 + 10) + 1, THUMB_FINE):
                for c in range(max(-80, c0 - 10), min(80, c0 + 10) + 1, THUMB_FINE):
                    for t in range(max(min(twists), t0 - 15), min(max(twists), t0 + 15) + 1, THUMB_FINE):
                        found = score_at(a, c, t, k0)
                        tried.append(found)
                        if found[0] < best[0]:
                            best = found

        def closed(found: tuple) -> list:
            self.adduct[b1] = found[1]
            k = math.radians(found[5])
            return self.close("Thumb", col, (0.0, ratio[1], ratio[2]), (0.0, max(limit[1], k), max(limit[2], k * 0.5)),
                              (0.0, k, k * 0.5))

        out = closed(best)
        if verify is not None and pin is None:
            # Nearest the target first: the bones' own clearance no longer ranks them, the glove's check does.
            for found in sorted(tried, key=lambda f: reach.get(f[2:6], f[0]))[:THUMB_VERIFY]:
                out = closed(found)
                if not verify():
                    best = found
                    break
            else:
                out = closed(best)
        if os.environ.get("BL_DEBUG"):
            print("   thumb search: score %.4f at %s" % (best[0], best[2:6]))
        return list(best[2:6]) + out[1:]

    def settle(self, name: str, start: tuple, col: Collider, span: int = 30, swing: float = 0.0,
               root: bool = False, more: int = None, strict: bool = False) -> list:
        """Poses a finger at its authored bends `start` (degrees, base to tip; its base swung `swing` degrees
        sideways), then curls it further or opens it, its three joints together and the tip a little less, until it
        rests on the replica: the most curl within `span` of the authored pose that stays clear of it (given `more`,
        no more than that past it: a finger reaching round something wide, which a fist closed short of it would
        clear too). With `root`, its first bone may rest on the replica (a palm cupped round a handguard), never
        pass into it. With `strict`, None when no curl clears the replica (the caller then tries another swing)."""
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

        # The most curl that clears the replica and keeps under `tip_top`; failing that, the clear curl rising least
        # above it.
        lowest = None
        for t in range(span if more is None else more, -3 * span - 1, -2):
            angles = apply(t)
            if not (self.clearance(bones[0], col) < (0.0 if root else CONTACT)
                    or any(self.touches(b, col) for b in bones[1:])):
                high = self.over(name)
                if not high:
                    return [round(a) for a in angles]
                if lowest is None or high < lowest[0] - 1e-4:
                    lowest = (high, t)
        if lowest is not None:
            return [round(a) for a in apply(lowest[1])]
        if strict:
            return None
        print("  ! the %s finger can't clear the replica %s" % (name, [round(self.clearance(b, col) * 1000, 1)
                                                                    for b in bones]))
        return [round(a) for a in angles]

    def press(self, name: str, angles: list, col: Collider, swing: float = 0.0, extra: int = 40) -> list:
        """A settled finger (at `angles`, its base swung `swing`) closed further at its two outer joints, its root
        kept, until they touch the replica (up to `extra` degrees, the tip a little less): a finger gripping round a
        narrow or raked grip, its knuckle already against it, rather than lying open beside it."""
        bones = ["%s%d_%s" % (name, k, self.side) for k in (1, 2, 3)]
        side_axis = self.axis[bones[0]].cross(Vector((0.0, 1.0, 0.0))).normalized()

        def apply(t: float) -> list:
            out = [angles[0], angles[1] + t, angles[2] + 0.7 * t]
            for k, ang in enumerate(out):
                rot = Matrix.Rotation(math.radians(ang), 3, self.axis[bones[k]])
                if k == 0 and swing:
                    rot = Matrix.Rotation(math.radians(swing), 3, side_axis) @ rot
                self.rig.fk(bones[k], self.adduct[bones[k]] @ rot if bones[k] in self.adduct else rot)
            return out

        best = 0
        for t in range(2, extra + 1, 2):
            apply(t)
            if any(self.touches(b, col) for b in bones[1:]):
                break
            best = t
        return [round(a) for a in apply(best)]

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

    def onto(self, name: str, target: Vector, col: Collider, limits: tuple, swing: int = 20,
             couple: float = 0.0, pin: tuple = None, back: int = 0, cup: float = 0.0) -> list:
        """Bends a finger so its last bone's pad comes to `target` (the trigger) without passing into the replica: a
        search over its three bends and its base's swing sideways (up to `swing` degrees), coarse then fine. With
        `couple`, the last joint bends that share of the middle one, as a relaxed finger's do, and is not searched;
        its knuckle may then bend `back` degrees the other way (a finger laid flat along a surface the palm is
        tilted up to). Given `pin` (swing and three bends: a pose the owner approved), the finger takes it and no
        search runs. With `cup` (degrees), the finger may also turn that far about its own line at its knuckle, as
        the ring and little fingers' do when a hand cups round a bar (the palm's arch): none, half and all of it are
        tried, either way, and the least that scores best is kept."""
        bones = ["%s%d_%s" % (name, k, self.side) for k in (1, 2, 3)]
        side_axis = self.axis[bones[0]].cross(Vector((0.0, 1.0, 0.0))).normalized()

        turned = [0.0]

        def apply(lat: float, a: tuple) -> None:
            if couple:
                a = (a[0], a[1], a[1] * couple)
            for k, ang in enumerate(a):
                rot = Matrix.Rotation(math.radians(ang), 3, self.axis[bones[k]])
                if k == 0:
                    rot = Matrix.Rotation(math.radians(lat), 3, side_axis) \
                        @ Matrix.Rotation(math.radians(turned[0]), 3, Vector((0.0, 1.0, 0.0))) @ rot
                self.rig.fk(bones[k], self.adduct[bones[k]] @ rot if bones[k] in self.adduct else rot)

        def score(lat: float, a: tuple) -> tuple:
            apply(lat, a)
            clear = min(self.clearance(b, col) for b in bones)
            m = self.rig.pose[bones[2]]
            pad = min((m @ q - target).length for q in self.points[bones[2]])
            # No further left than `index_left` (eye space), when set: the tip kept from showing past the far side of
            # the trigger guard.
            over = 0.0
            if self.index_left is not None:
                over = max(0.0, self.index_left - min((self.rig.pose[b] @ q).x for b in bones[1:]
                                                      for q in self.points[b]))
            # A finger asked to arch (`index_arc`: its middle joint's bend, what each degree off it costs, m, and its
            # tip's share of that bend, ARC_TIP unless given) bends there and that share at its tip, as a relaxed
            # finger does, where the pad still finds the target.
            arch = 0.0
            if self.index_arc is not None:
                mid, cost = self.index_arc[:2]
                tip = self.index_arc[2] if len(self.index_arc) > 2 else ARC_TIP
                arch = cost * (abs(a[1] - mid) + 0.5 * abs(a[2] - tip * mid))
            # Clear of the replica first, then the pad nearest the target; and never standing above `tip_top`, when
            # set (a support hand's fingertips kept under the handguard's top as the eye sees it).
            # Past `front` (a handguard's front end) counts as the height limit does; or, where the hold says so
            # (`front_hard`), as passing into the replica does: never, where any pose keeps behind it.
            past = sight.ahead(self, name)
            over += self.over(name) + (0.0 if self.front_hard else past) + sight.seen(self, name) * sight.SEEN_COST
            over += sight.crowd(self, name)
            return pad + arch + over * 10.0 + (1.0 + past * 10.0 if self.front_hard and past > 0.0 else 0.0) \
                + (0.0 if clear >= CONTACT else 1.0 + (CONTACT - clear) * 10.0), clear

        swing = int(swing)
        if os.environ.get("BL_DEBUG"):
            head = self.rig.pose[bones[0]].translation
            print("   %s: knuckle %s target %s (%.1f mm away), bones %s mm, left limit %s" % (
                name, tuple(round(x, 4) for x in head), tuple(round(x, 4) for x in target), (target - head).length * 1e3,
                [round(self.rig.length[b] * 1e3, 1) for b in bones], self.index_left))
        if pin is not None:
            # A pinned pose (an approved hand) is kept as it is: no search.
            sc, clear = score(pin[0], tuple(pin[1:]))
            best = (sc, list(pin), clear)
        else:
            best, kept = None, 0.0
            for share in ((0.0, 0.5, 1.0, -0.5, -1.0) if cup else (0.0,)):
                turned[0] = cup * share
                found = self.onto_search(score, swing, limits, couple, int(back))
                if best is None or found[0] < best[0] - CUP_GAIN:
                    best, kept = found, turned[0]
            turned[0] = kept
            if cup:
                print("  %s finger cupped %.0f degrees" % (name, kept))
        apply(best[1][0], tuple(best[1][1:]))
        if couple:
            best[1][3] = best[1][2] * couple
        if best[2] < CONTACT:
            print("  ! the %s finger passes %.1f mm into the replica reaching its mark" % (
                name, (CONTACT - best[2]) * 1e3))
        m = self.rig.pose[bones[2]]
        pad = min((m @ q - target).length for q in self.points[bones[2]])
        print("  %s finger on its mark: pad %.1f mm off" % (name, (pad if best[2] >= CONTACT else -1) * 1e3))
        return [round(x) for x in best[1]]

    def onto_search(self, score, swing: int, limits: tuple, couple: float, back: int = 0) -> tuple:
        """`onto`'s search: a coarse grid of the finger's sideways swing and bends, then finer steps from the best,
        each within the bends allowed (a finger told to lie nearly straight stays so; a coupled one's knuckle from
        `back` degrees the other way). The best (score, [swing, bends], clearance). With `index_soft`, the coarse
        grid forgives a pose for passing into the replica (it still pays for how deep): the finer steps then walk
        from the nearest such pose to a clear one, where a clear pose is a pocket too small for the grid to land in
        (a gloved fingertip inside a trigger guard)."""
        best = None
        step_off = 1.0 if self.index_soft else 0.0
        for lat in sorted({-swing, 0, swing} | set(range(-swing, swing + 1, 10))):
            for a1 in sorted({-back} | set(range(0, limits[0] + 1, 10))) if couple else range(
                    self.index_from, limits[0] + 1, 10):
                for a2 in range(0, limits[1] + 1, 10):
                    for a3 in range(0, 1 if couple else limits[2] + 1, 10):
                        sc, clear = score(lat, (a1, a2, a3))
                        if clear < CONTACT:
                            sc -= step_off
                        if best is None or sc < best[0]:
                            best = (sc, [lat, a1, a2, a3], clear)
        if step_off and best[2] < CONTACT:
            best = (best[0] + step_off, best[1], best[2])
        step = 4.0
        while step >= 1.0:
            moved = False
            for k in range(3 if couple else 4):
                for sgn in (-1.0, 1.0):
                    trial = list(best[1])
                    trial[k] += sgn * step
                    if k == 0 and abs(trial[0]) > swing or couple and trial[1] < -back:
                        continue
                    if k > 0 and (trial[k] > limits[k - 1] + 0.5 or k > 1 and trial[k] < -0.5
                                  or k == 1 and not couple and trial[k] < self.index_from - 0.5):
                        continue
                    sc, clear = score(trial[0], tuple(trial[1:]))
                    if sc < best[0]:
                        best = (sc, trial, clear)
                        moved = True
            if not moved:
                step *= 0.5
        return best

    def close(self, name: str, col: Collider, ratio: tuple, limit: tuple, start: tuple = (0.0, 0.0, 0.0)) -> list:
        """Curls one finger joint by joint, from its bends `start` (radians), until each part meets the rifle (or
        reaches its limit)."""
        bones = ["%s%d_%s" % (name, k, self.side) for k in (1, 2, 3)]
        ang = list(start)
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


def frozen(ob: bpy.types.Object, name: str, without: tuple = ()) -> bpy.types.Object:
    """A still copy of `ob`'s skin as its armature poses it now, for the other hand to rest on or keep clear of;
    `without` the skin of the bones named (a thumb that will be laid again, on the hand that comes to rest here)."""
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    me.name = name
    if without:
        names = {g.index: g.name for g in ob.vertex_groups}
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.verts.ensure_lookup_table()
        drop = []
        for sv in ob.data.vertices:
            g = max(sv.groups, key=lambda x: x.weight, default=None)
            if g is not None and names[g.group] in without:
                drop.append(bm.verts[sv.index])
        bmesh.ops.delete(bm, geom=drop, context="VERTS")
        bm.to_mesh(me)
        bm.free()
    still = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(still)
    still.matrix_world = ob.matrix_world.copy()
    bpy.context.view_layer.update()
    return still


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
                    # The heel of the thumb counts as the thumb's first bone, which moves it.
                    key = THUMB_ROOT + key[len(HEEL) + 1:] if key.startswith(HEEL + "_") else key
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
TIGHTEN_WRAP = (0.0, 1.0, 0.8)


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
        hits, tally = clipping(objects, solid)
        if hits:
            if os.environ.get("BL_DEBUG"):
                print("   %s press stopped by" % side, sorted(tally.items(), key=lambda x: -x[1])[:4])
            place_arm(rig, side, before, poles[side], quiet=True)
            rig.refresh("Hand_" + side)
            break
        moved += PRESS_STEP
    rig.write()
    return moved


def tighten(rig: Rig, hands: dict, objects: list, solid: list, fingers: list) -> dict:
    """Closes each finger of `fingers` (("R", "Middle"), ...) onto the replica on the skinned surface itself, one
    finger at a time, a step at a time, each stopping a step short of where its glove would first touch (the owner:
    gripped tight, never clipping): first the whole finger (TIGHTEN_SHARES), then, once its root can close no further
    (the skin of its root's crease meets the grip first), its last two joints alone, so its end wraps on round the
    grip (TIGHTEN_WRAP). The bone-sampled solve leaves gaps the skin doesn't need. Degrees each closed, for the
    log."""
    closed = {}
    for side, name in fingers:
        total = 0.0
        for shares in (TIGHTEN_SHARES, TIGHTEN_WRAP):
            n = 0.0
            while n + TIGHTEN_STEP <= TIGHTEN_MAX:
                high = _strays(hands[side], name)
                _turn_finger(rig, hands, side, name, shares, TIGHTEN_STEP)
                rig.write()
                if _strays(hands[side], name) > high or clipping(objects, solid)[0]:
                    _turn_finger(rig, hands, side, name, shares, -TIGHTEN_STEP)
                    rig.write()
                    break
                n += TIGHTEN_STEP
            total += n
        closed["%s %s" % (side, name)] = total
    return closed


def _strays(hand: Hand, name: str) -> float:
    """What a closing pass must not add to (m): the finger's glove above the hand's `tip_top`, and, for a finger laid
    in a row (`hand.row`), how far it strays from that row as the fingers before it now lie (`sight.crowd`) and past
    a firm front end (`sight.ahead`). Closed without this, a rowed finger curls back out of its row (the critic's
    fourth look: the SMG's little finger in a loop, the Sniper's leaning back from the ring finger)."""
    out = hand.over(name)
    if name in hand.row:
        hand.laid = [line for n in hand.row[:hand.row.index(name)] for line in sight.lines(hand, n)]
        out += sight.crowd(hand, name) + (sight.ahead(hand, name) if hand.front_hard else 0.0)
        hand.laid = []
    return out


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
            high = _strays(hands[side], name)
            _turn_finger(rig, hands, side, name, shares, WRAP_STEP)
            rig.write()
            if _strays(hands[side], name) > high or clipping(objects, solid)[0]:
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
