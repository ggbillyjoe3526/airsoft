"""The right hand working a bolt-action replica's bolt (BW1, the owner 2026-11-06: "fix the no hand on the sniper
bolt"): a clip `<id>_Fire`, in which the hand leaves the stock's grip after the shot, takes the bolt's knob, follows it
up, back, forward and down as the replica's own Fire clip works it, and returns to the grip a little after that clip
ends. The game plays it in step with the replica's Fire clip, then lets it run on (ArmsView.follow), so the hand drives
the bolt on screen."""

import math
import os

import bpy
from mathutils import Matrix, Quaternion, Vector

import pose
from pose import Collider, Rig

# The replica's clip and part the hand works.
CLIP = "Fire"
BOLT = "bolt"
# The knob: the bolt mesh's vertices this far out from the bolt's axis, at most (m from the furthest).
KNOB_DEPTH = 0.008
SIDE = "R"
# How the hand takes the knob: hooked in the curl of the index finger (bent HOOK_INDEX, degrees base to tip, then
# settled onto it), the knob's centre at the centre of the circle through the finger's three sections, its axis across
# the finger's bend; the other fingers curled out past the knob's end in a loose fist (HOOK). The hand's turn about the
# handle is searched in steps of HOOK_ROLL degrees for the one whose glove clears the replica with the straightest
# wrist; then the thumb's base turn (degrees: across the palm, round its own line, in its bend, as Hand.thumb_at) from
# THUMB_TURNS whose settled tip comes nearest the knob, its tip joints bent THUMB_BENDS.
HOOK_INDEX = (35.0, 50.0, 35.0)
HOOK = {"Middle": (60.0, 80.0, 45.0), "Ring": (70.0, 85.0, 45.0), "Pinky": (75.0, 85.0, 45.0)}
HOOK_ROLL = 15
THUMB_TURNS = [(a, t, b) for a in (-40.0, -20.0, 0.0, 20.0, 40.0) for t in (0.0, 30.0, 60.0) for b in (0.0, 30.0, 60.0)]
THUMB_BENDS = (20.0, 15.0)
# The wrist bends no further than this (degrees) on the knob, as near as the search finds.
WRIST_MOST = 30.0
# The hand turns this share of the bolt's turn as it lifts the handle (all of it would roll the wrist over the
# receiver's top, where the scope sits).
ROLL_SHARE = 0.5
# On the knob the hand also turns about it, each key, to keep the wrist straightest (the knob turning in the curl of
# the fingers): about the handle's line and about the bolt's axis, at most SPIN_STEP degrees from the last key's turn
# (so it eases round), at most SPIN_MOST either way, each degree of change from the last key costing SPIN_COST of a
# degree of bend.
SPIN_STEP = 10.0
SPIN_MOST = (70.0, 40.0)
SPIN_COST = 0.3
# The hand leaves the grip on the clip's first frame (the shot), reaches the knob as the bolt first moves, and is back
# on the grip TRAIL seconds after the replica's clip ends (the game lets the arms' clip run on: ArmsView.follow; the
# rifle is ready again about 1.25 s after a shot), carried this far up and out to the right (m) at the middle of each
# reach so it passes round the stock's side.
TRAIL = 0.25
LIFT = 0.03
OUT = 0.025
# The fingers open off the grip over this share of the reach as the hand draws CLEAR (m, eye space) off the grip's side,
# and the hand travels to the knob over the rest (on the way back, the same reversed).
OPEN_BY = 0.35
CLEAR = Vector((0.025, -0.01, 0.005))
CLOSE_FROM = 0.6
STRAIGHTEN = 0.5
OPEN_AHEAD = 0.6
RELAXED = 0.45
# How far (degrees, all three joints) a finger passing into the replica on the way is bent further to clear it, tried
# in this order: curled first, then opened.
FINGER_WAY = (0.0, 10.0, -10.0, 20.0, -20.0, 30.0, -30.0, 45.0, -45.0, 60.0, -60.0)
# Clear by this much (m) at the glove's sample points, so the faces between them clear too.
FINGER_CLEAR = 0.0015
# The elbow out this far (m) from where it would bend with the hand on the knob, so the upper arm clears the stock.
ELBOW_OUT = Vector((0.03, 0.0, 0.0))
# A key every this many frames while the hand rides the knob (every frame as it leaves the grip and comes back).
STEP = 2


def has_bolt(objects: list) -> bool:
    """Whether the replica has a bolt the hand works (a bolt-action replica)."""
    return any(o.type == "ARMATURE" and BOLT in o.pose.bones for o in objects)


def fire_action(objects: list) -> tuple:
    """The replica's armature and its Fire clip (the importer's NLA strip of it)."""
    arm = next(o for o in objects if o.type == "ARMATURE")
    for track in arm.animation_data.nla_tracks:
        for strip in track.strips:
            if strip.action is not None and strip.action.name.split(".")[0] == CLIP:
                return arm, strip.action
    raise SystemExit("no %s clip on %s" % (CLIP, arm.name))


def bolt_at(arm, action, frame: float) -> Matrix:
    """The bolt bone's matrix (eye space: the replica already stands at its hold) at `frame` of its Fire clip."""
    arm.animation_data.action = action
    bpy.context.scene.frame_set(int(frame), subframe=frame - int(frame))
    m = arm.matrix_world @ arm.pose.bones[BOLT].matrix
    return m.copy()


def knob_centre(objects: list, rest: Matrix) -> Vector:
    """The knob's centre in the bolt bone's own space (the bolt at rest)."""
    bolt = next(o for o in objects if o.type == "MESH" and o.parent_bone == BOLT)
    inv = rest.inverted()
    pts = [inv @ (bolt.matrix_world @ v.co) for v in bolt.data.vertices]
    # The bone's own Y is the bolt's axis: the knob is the part furthest from it.
    far = max(math.hypot(p.x, p.z) for p in pts)
    knob = [p for p in pts if math.hypot(p.x, p.z) > far - KNOB_DEPTH]
    return sum(knob, Vector()) / len(knob)


def clear_thumb(hand: pose.Hand, col: Collider, target: Vector) -> list:
    """The thumb's base turn (THUMB_TURNS, tip joints THUMB_BENDS) that clears `col` with its tip nearest `target`,
    settled onto it; its curls."""
    rig, side = hand.rig, hand.side
    bones = ["Thumb%d_%s" % (k, side) for k in (1, 2, 3)]
    best = None
    for turn in THUMB_TURNS:
        hand.thumb_at(turn, THUMB_BENDS, col, span=40)
        t3 = rig.pose[bones[2]]
        tip = t3.translation + t3.to_3x3().col[1] * rig.length[bones[2]]
        clear = min(hand.clearance(b, col) for b in bones)
        score = (tip - target).length + (0.0 if clear >= 0.0 else 1.0 - clear * 100.0)
        if best is None or score < best[0]:
            best = (score, turn)
    return hand.thumb_at(best[1], THUMB_BENDS, col, span=40)


def snapshot(rig: Rig) -> dict:
    return {b: rig.basis_of(b) for b in rig.rest}


def key_frames(rig: Rig, clip: str, frames: list) -> None:
    """An action `clip` keyed at each (frame, {bone: basis}) of `frames`, on its own NLA track."""
    arm = rig.arm
    arm.animation_data_create()
    act = bpy.data.actions.new(clip)
    arm.animation_data.action = act
    for frame, bases in frames:
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
            loc, rot, _ = bases[pb.name].decompose()
            pb.location, pb.rotation_quaternion, pb.scale = loc, rot, (1.0, 1.0, 1.0)
            for path in ("location", "rotation_quaternion", "scale"):
                pb.keyframe_insert(path, frame=frame)
    arm.animation_data.action = None
    track = arm.animation_data.nla_tracks.new()
    track.name = clip
    track.strips.new(clip, 0, act)


def smooth(t: float) -> float:
    t = min(1.0, max(0.0, t))
    return t * t * (3.0 - 2.0 * t)


def turn_between(a: Quaternion, b: Quaternion, u: float, long_way: bool) -> Quaternion:
    """`u` of the turn from `a` to `b`, the short way round or the long."""
    axis, angle = (b @ a.inverted()).to_axis_angle()
    if angle > math.pi:
        angle -= 2.0 * math.pi
    if long_way:
        angle -= math.copysign(2.0 * math.pi, angle)
    return Quaternion(axis, angle * u) @ a


class BoltWork:
    """The hand's way from the stock's grip to the bolt's knob and back, keyed over the replica's Fire clip."""

    def __init__(self, rig: Rig, hand: pose.Hand, objects: list, solid: list, arms: list, elbow_for,
                 optics: list = ()):
        self.rig, self.hand, self.arms, self.elbow_for = rig, hand, arms, elbow_for
        # The fitted optics, in the check only (BP7): the hand's path never reads them.
        self.optics = list(optics)
        self.optic_hits = 0
        self.arm, self.action = fire_action(objects)
        self.length = int(round(self.action.frame_range[1]))
        self.rest = bolt_at(self.arm, self.action, 0.0)
        moving = [f for f in range(self.length + 1) if self.moved(f)]
        self.first, self.last = moving[0] - 1, moving[-1] + 1
        self.end = self.length + int(round(TRAIL * bpy.context.scene.render.fps))
        self.knob = knob_centre(objects, self.rest)
        self.knob_rest = self.rest @ self.knob
        # The handle's line out from the bolt's axis through the knob.
        self.out = (self.rest.to_3x3() @ Vector((self.knob.x, 0.0, self.knob.z))).normalized()
        self.col = Collider(solid)
        self.frame = [o for o in solid if not o.name.startswith("Trigger")]
        self.bone = "Hand_" + SIDE
        self.fingers = [b for b in rig.rest if b.endswith("_" + SIDE) and b.split("_")[0][:-1] in
                        ("Index", "Middle", "Ring", "Pinky", "Thumb")]
        # The hold, as posed.
        self.held = snapshot(rig)
        self.held_hand = rig.pose[self.bone].copy()
        self.held_local = self.finger_turns()
        # The elbow bends as the hold's does where no elbow below the shoulder reaches (the knob sits near it).
        self.held_pole = rig.pose["Forearm_" + SIDE].translation - rig.pose["UpperArm_" + SIDE].translation

    def moved(self, f: int) -> bool:
        m = bolt_at(self.arm, self.action, f)
        return ((m.translation - self.rest.translation).length > 1e-5
                or m.to_quaternion().rotation_difference(self.rest.to_quaternion()).angle > 1e-4)

    def finger_turns(self) -> dict:
        return {b: self.rig.local.get(b, Matrix.Identity(3)).copy() for b in self.fingers}

    def palm_of(self, hand_m: Matrix) -> Vector:
        """Where the palm of a hand bone posed `hand_m` faces (eye space)."""
        return hand_m.to_3x3() @ self.rig.rest[self.bone].to_3x3().inverted() @ self.hand.palmar

    def bend_finger(self, name: str, angles: tuple) -> None:
        """Poses one finger at `angles` (degrees, base to tip), with no check against the replica."""
        hand = self.hand
        for k, ang in enumerate(angles):
            b = "%s%d_%s" % (name, k + 1, SIDE)
            rot = Matrix.Rotation(math.radians(ang), 3, hand.axis[b])
            self.rig.fk(b, hand.adduct[b] @ rot if b in hand.adduct else rot)

    def curl(self) -> tuple:
        """The index finger's curl at HOOK_INDEX, in the hand bone's own space: where the knob's centre sits in it,
        and the knob's axis through it, pointing out past the knob's end (the side the middle finger lies)."""
        rig = self.rig
        self.bend_finger("Index", HOOK_INDEX)
        self.bend_finger("Middle", HOOK["Middle"])
        inv = rig.pose[self.bone].inverted()

        def middle_of(b: str) -> tuple:
            m = rig.pose[b]
            line = m.to_3x3().col[1].normalized()
            return m.translation + line * rig.length[b] * 0.5, line

        # The centre of the circle through the middles of its three sections.
        p1, p2, p3 = (middle_of("Index%d_%s" % (k, SIDE))[0] for k in (1, 2, 3))
        u, v = p1 - p2, p3 - p2
        n = u.cross(v)
        hole = inv @ (p2 + (v.cross(n) * u.length_squared + n.cross(u) * v.length_squared) / (2.0 * n.length_squared))
        mid = p2
        axis = (inv.to_3x3() @ rig.pose["Index2_" + SIDE].to_3x3() @ self.hand.axis["Index2_" + SIDE]).normalized()
        if axis.dot(inv @ middle_of("Middle2_" + SIDE)[0] - inv @ mid) < 0.0:
            axis = -axis
        return hole, axis

    def hook(self, roll: float, thumb: tuple = None) -> tuple:
        """The hand with the knob in its index finger's curl, turned `roll` degrees about the handle: its pose, the
        elbow's pole, the fingers' turns, and a score (lower is better: the right arm's glove passing into the
        replica, then the wrist's bend, then how far the thumb's tip is from the knob)."""
        rig, hand = self.rig, self.hand
        hand.tip_top = None
        turn = (Matrix.Rotation(math.radians(roll), 3, self.out)
                @ self.hole_axis.rotation_difference(self.out).to_matrix())
        hand_m = Matrix.Translation(self.knob_rest - turn @ self.hole) @ turn.to_4x4()
        pole_k, _ = self.elbow_for(rig, SIDE, hand_m, quiet=True)
        pole_k = pole_k if pole_k is not None else self.held_pole
        pose.place_arm(rig, SIDE, hand_m, pole_k, quiet=True)
        rig.refresh(self.bone)
        short = (rig.pose[self.bone].translation - hand_m.translation).length
        hand.settle("Index", HOOK_INDEX, self.col, span=30, root=True)
        for name, angles in HOOK.items():
            hand.settle(name, angles, self.col, span=20)
        hand.thumb_at(thumb or THUMB_TURNS[0], THUMB_BENDS, self.col, span=40)
        rig.write()
        _, tally = pose.clipping(self.arms, self.frame)
        n = sum(v for k, v in tally.items() if k.endswith("_" + SIDE))
        bend = pose.wrist_bend(rig, SIDE)
        score = n * 10.0 + short * 1000.0 + bend + max(0.0, bend - WRIST_MOST) * 10.0
        return hand_m, pole_k, self.finger_turns(), score

    def thumb_tip(self) -> float:
        """How far the thumb's tip is from the knob's centre (m)."""
        t3 = self.rig.pose["Thumb3_" + SIDE]
        return (t3.translation + t3.to_3x3().col[1] * self.rig.length["Thumb3_" + SIDE] - self.knob_rest).length

    def grip(self) -> tuple:
        """The hook whose turn about the handle scores best, its thumb the turn that closes nearest the knob."""
        self.hole, self.hole_axis = self.curl()
        roll = min((self.hook(r)[3], r) for r in range(-180, 180, HOOK_ROLL))[1]
        self.hook(roll)
        near = []
        for turn in THUMB_TURNS:
            self.hand.thumb_at(turn, THUMB_BENDS, self.col, span=40)
            near.append((self.thumb_tip(), turn))
        thumb = min(near)[1]
        best = self.hook(roll, thumb)
        print("  bolt grip: roll %d, thumb %s (tip %.1f mm from the knob), wrist %.0f deg, score %.1f" % (
            roll, thumb, self.thumb_tip() * 1000.0, pose.wrist_bend(self.rig, SIDE), best[3]))
        return best

    def on_knob_at(self, f: int) -> Matrix:
        """The hand on the knob at frame `f`: carried with it, turned ROLL_SHARE of the bolt's turn."""
        now = bolt_at(self.arm, self.action, min(f, self.length))
        turn = Quaternion().slerp(now.to_quaternion() @ self.rest.to_quaternion().inverted(), ROLL_SHARE)
        return (Matrix.Translation(now @ self.knob) @ turn.to_matrix().to_4x4() @ Matrix.Translation(-self.knob_rest)
                @ self.on_knob)

    def pose_hand(self, hand_m: Matrix, local: dict, pole_now: Vector) -> None:
        pose.place_arm(self.rig, SIDE, hand_m, pole_now, quiet=True)
        self.rig.local.update(local)
        self.rig.refresh(self.bone)

    def way(self, knob_hand: Matrix, t: float) -> tuple:
        """The hand `t` of the way from the grip to the knob: first (to OPEN_BY) its fingers open as it draws off the
        grip's side by CLEAR, then it is carried up and out round the stock's side to the knob, turning over the way
        that keeps its palm down, the fingers closing on the knob as it arrives; the elbow's pole between the hold's
        and the knob's."""
        if t < OPEN_BY:
            u = smooth(t / OPEN_BY)
            # The fingers open ahead of the hand's drawing off, so they leave the trigger and the grip's front clear.
            v = smooth(t / (OPEN_BY * OPEN_AHEAD))
            local = {b: self.held_local[b].to_quaternion().slerp(self.relaxed[b], v).to_matrix() for b in self.fingers}
            # Out to the side first, back only after (the web of the hand would press into the grip's back).
            return (Matrix.Translation(Vector((CLEAR.x * u, CLEAR.y * u * u, CLEAR.z * u))) @ self.held_hand, local,
                    self.held_pole)
        u = smooth((t - OPEN_BY) / (1.0 - OPEN_BY))
        start = Matrix.Translation(CLEAR) @ self.held_hand
        loc = start.translation.lerp(knob_hand.translation, u) + Vector((OUT, 0.0, LIFT)) * math.sin(math.pi * u)
        rot = turn_between(self.held_hand.to_quaternion(), knob_hand.to_quaternion(), u, self.long_way)
        hand_m = Matrix.Translation(loc) @ rot.to_matrix().to_4x4()
        # They close on the knob only over the last of the way, once it is in the hand.
        v = smooth((u - CLOSE_FROM) / (1.0 - CLOSE_FROM))
        local = {b: self.relaxed[b].slerp(self.grip_local[b].to_quaternion(), v).to_matrix() for b in self.fingers}
        # The elbow where the wrist is straightest for the hand there, eased in from the hold's.
        pole_now, _ = self.elbow_for(self.rig, SIDE, hand_m, quiet=True)
        pole_now = pole_now + ELBOW_OUT * u if pole_now is not None else self.knob_pole
        pole_now = self.held_pole.lerp(pole_now, smooth(u / OPEN_BY))
        # Mid-way the hand turns part way (STRAIGHTEN at the middle, none at either end) toward lying in line with
        # the forearm, so the wrist doesn't stay cocked as it travels.
        w = STRAIGHTEN * math.sin(math.pi * u)
        if w > 0.0:
            rig = self.rig
            pose.place_arm(rig, SIDE, hand_m, pole_now, quiet=True)
            fo = "Forearm_" + SIDE
            straight = (rig.pose[fo].to_3x3() @ rig.rest[fo].to_3x3().inverted()
                        @ rig.rest[self.bone].to_3x3()).to_quaternion()
            rot = hand_m.to_quaternion().slerp(straight, w)
            hand_m = Matrix.Translation(hand_m.translation) @ rot.to_matrix().to_4x4()
        return hand_m, local, pole_now

    def palm_down_way(self) -> bool:
        """Whether the hand turns the long way round from the grip to the knob: the way whose palm faces up least."""
        a, b = self.held_hand.to_quaternion(), self.on_knob.to_quaternion()

        def up(long_way: bool) -> float:
            return max(self.palm_of(turn_between(a, b, k / 8.0, long_way).to_matrix().to_4x4()).z for k in range(9))

        return up(True) < up(False)

    def clear_fingers(self) -> None:
        """Each finger passing into the replica on the way (sweeping off or onto the grip) bent the least further
        either way, all its joints together, that takes it clear."""
        rig, hand = self.rig, self.hand
        for name in ("Index", "Middle", "Ring", "Pinky", "Thumb"):
            bones = ["%s%d_%s" % (name, k, SIDE) for k in (1, 2, 3)]
            base = [rig.local[b].copy() for b in bones]

            def bent(d: float) -> bool:
                for b, m in zip(bones, base):
                    rig.local[b] = m @ Matrix.Rotation(math.radians(d), 3, hand.axis[b])
                rig.refresh(self.bone)
                return all(self.col.dist(rig.pose[b] @ q) >= FINGER_CLEAR for b in bones for q in hand.points[b])

            # Failing a clear bend, the one whose glove passes into the replica least (a finger rooted on the grip
            # at the hold's own clearance, the hand all but back on it).
            least = None
            for d in FINGER_WAY:
                clear = bent(d)
                into, whole = self.skin_in(name)
                if clear and not into:
                    break
                if least is None or whole < least[0]:
                    least = (whole, d)
            else:
                bent(least[1])

    def skin_in(self, name: str) -> tuple:
        """How many face pairs of the finger `name`'s skinned glove pass into the replica (its faces, not only sample
        points), and how many of the whole hand and arm's (a finger's bend moves the knuckles' skin too)."""
        self.rig.write()
        tally = pose.clipping(self.arms, self.frame)[1]
        side = {b: n for b, n in tally.items() if b.endswith("_" + SIDE)}
        return sum(n for b, n in side.items() if b.startswith(name)), sum(side.values())

    def spun(self, f: int, turn: tuple) -> Matrix:
        """The hand on the knob at frame `f` turned about the knob's centre `turn` degrees: about the handle's line,
        then about the bolt's axis."""
        now = bolt_at(self.arm, self.action, min(f, self.length))
        centre = now @ self.knob
        moved = now.to_3x3() @ self.rest.to_3x3().inverted()
        about = (Matrix.Rotation(math.radians(turn[0]), 4, moved @ self.out)
                 @ Matrix.Rotation(math.radians(turn[1]), 4, now.to_3x3().col[1].normalized()))
        return Matrix.Translation(centre) @ about @ Matrix.Translation(-centre) @ self.on_knob_at(f)

    def straightest(self, f: int, last: tuple) -> tuple:
        """Within SPIN_STEP of `last`, the turn on the knob at frame `f` that bends the wrist least with the glove
        clear of the replica: the turn, and the elbow's pole for it."""
        rig, hand = self.rig, self.hand
        bones = [self.bone] + self.fingers

        def cost(turn: tuple) -> tuple:
            hand_m = self.spun(f, turn)
            pole_now, _ = self.elbow_for(rig, SIDE, hand_m, quiet=True)
            pole_now = pole_now + ELBOW_OUT if pole_now is not None else self.knob_pole
            self.pose_hand(hand_m, self.grip_local, pole_now)
            inside = sum(max(0.0, FINGER_CLEAR - self.col.dist(rig.pose[b] @ q)) for b in bones
                         for q in hand.points.get(b, ()))
            change = abs(turn[0] - last[0]) + abs(turn[1] - last[1])
            return pose.wrist_bend(rig, SIDE) + inside * 1e4 + change * SPIN_COST, pole_now

        tried = []
        for da in (-SPIN_STEP, 0.0, SPIN_STEP):
            for db in (-SPIN_STEP, 0.0, SPIN_STEP):
                turn = (last[0] + da, last[1] + db)
                if abs(turn[0]) <= SPIN_MOST[0] and abs(turn[1]) <= SPIN_MOST[1]:
                    tried.append((cost(turn)[0], turn))
        # The best whose arm clears the replica (its skinned faces: the upper arm swings in toward the stock as the
        # hand turns), else the best.
        tried.sort()
        best = tried[0]
        for sc, turn in tried:
            cost(turn)
            self.rig.write()
            if not any(k.endswith("_" + SIDE) and n for k, n in pose.clipping(self.arms, self.frame)[1].items()):
                best = (sc, turn)
                break
        return best[1], cost(best[1])[1]

    def keys(self) -> tuple:
        """Each key's (frame, bases), and how many keys pass into the replica; the wrist's greatest bend on the way
        and on the knob."""
        self.on_knob, pole, self.grip_local, _ = self.grip()
        self.knob_pole = pole + ELBOW_OUT
        # The open hand between: the fingers part way from the rest hand's splay to their grip on the knob.
        self.relaxed = {b: Quaternion().slerp(self.grip_local[b].to_quaternion(), RELAXED) for b in self.fingers}
        self.long_way = self.palm_down_way()
        first, last, end = self.first, self.last, self.end
        out, hits, bend = [(0, self.held)], 0, [0.0, 0.0]
        spin = (0.0, 0.0)
        frames = set(range(1, first + 1)) | set(range(first, last, STEP)) | set(range(last, end + 1))
        for f in sorted(frames):
            knob_hand = self.on_knob_at(f)
            if f < first:
                self.pose_hand(*self.way(knob_hand, f / first))
                self.clear_fingers()
            elif f <= last:
                # The hand turned on the knob where the wrist is straightest, the elbow where it is straightest too;
                # the fingers keep clear of the replica.
                spin, pole_now = self.straightest(f, spin)
                self.pose_hand(self.spun(f, spin), self.grip_local, pole_now)
                self.clear_fingers()
            elif f < end:
                self.pose_hand(*self.way(self.spun(f, spin), 1.0 - (f - last) / (end - last)))
                self.clear_fingers()
            else:
                out.append((f, self.held))
                continue
            self.rig.write()
            k = 1 if first <= f <= last else 0
            bend[k] = max(bend[k], pose.wrist_bend(self.rig, SIDE))
            # BL_BOLT_TRACE=1: each key's wrist bend and turn on the knob, to check a change by.
            if os.environ.get("BL_BOLT_TRACE"):
                print("   frame %d: wrist %.0f deg, turn on the knob %s" % (f, pose.wrist_bend(self.rig, SIDE), spin))
            n, tally = pose.clipping(self.arms, self.frame)
            if self.optics:
                on, otally = pose.clipping(self.arms, self.optics)
                if on:
                    self.optic_hits += 1
                    print("   frame %d: %d face pairs pass into a fitted optic %s" % (
                        f, on, sorted(otally.items(), key=lambda x: -x[1])[:4]))
                n += on
            if n:
                hits += 1
                print("   frame %d: %d face pairs pass into the replica %s" % (
                    f, n, sorted(tally.items(), key=lambda x: -x[1])[:4]))
            out.append((f, snapshot(self.rig)))
        return out, hits, bend


def work_bolt(rig: Rig, hand: pose.Hand, objects: list, solid: list, arms: list, clip: str, elbow_for,
              optics: list = ()) -> tuple:
    """Keys `clip` from the hold now posed; how many of its keys have the arms passing into the replica or into one
    of `optics` (the fitted optics, checked only), and the keys (each (frame, bases): a foregrip's hold keys its own
    clip from them, its left arm's bases in place of these, BP8)."""
    kept = (dict(hand.adduct), hand.normal, hand.tip_top, dict(rig.local))
    work = BoltWork(rig, hand, objects, solid, arms, elbow_for, optics)
    keys, hits, bend = work.keys()
    work.arm.animation_data.action = None
    for pb in work.arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    key_frames(rig, clip, keys)
    hand.adduct, hand.normal, hand.tip_top, rig.local = kept
    print("  bolt: the hand on the knob %d-%d, back on the grip at %d (the replica's clip %d frames); %d keys pass "
          "into the replica (%d into a fitted optic of %d checked); the wrist bends %.0f deg at most on the way, %.0f "
          "on the knob" % (work.first, work.last, work.end, work.length, hits, work.optic_hits, len(work.optics),
                           bend[0], bend[1]))
    return hits, keys
