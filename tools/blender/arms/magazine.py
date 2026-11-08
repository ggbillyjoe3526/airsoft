"""The left hand changing the magazine (BP8, the owner's playtest note 9: "when a weapon reloads a new magazine the
left arm should have an animation where it removes it and put a new one in"): a clip `<id>_Reload` (and one from each
foregrip's hold, `<id>_<grip>_Reload`) as long as the replica's own Reload clip, which the game plays at the same
share of the reload (ArmsView.follow), so the game's reload times and rules don't change.

The replica's Reload clip moves its magazine: down out of the well, away, a fresh one back in partway and seated home.
The hand leaves its hold, takes the magazine as it starts down (CATCH of the way), carries it down along the clip's own
path, dips out of view while the replica's clip has no magazine (DIP), comes back with the fresh one where the clip
shows it, pushes it home along its path, and goes back to its hold. Following the clip's magazine, the hand and the
magazine move as one: the magazine rides in the hand.

How the hand takes each replica's magazine (GRASP, replica space): a rifle's from its left side, the palm on it and
the fingers round its front (`side`); a pistol's and the Sniper Rifle's, whose magazine sits in the grip or the stock
with only its base out, from below, the palm under the base plate (`under`). The hand's turn is searched for the
straightest wrist, then the fingers close on the magazine (and never into the right hand)."""

import math
import os

import bpy
from mathutils import Matrix, Quaternion, Vector

import cycle
import pose
from pose import Collider, Rig

CLIP = "Reload"
MAG = "magazine"
SIDE = "L"
# How the hand takes the magazine, by replica: `kind` (side: palm on its left side, the fingers forward round its
# front; under: palm up under its base), `at` (a side grasp's point, replica space: in the magazine below the well,
# which the palm seats against), the fingers' pitch down from forward (side) or yaw from forward toward the right
# (under) searched over `turn` (degrees, from, to), the start bends the fingers settle from, and where the thumb's tip
# reaches for (`thumb`, m from the grasp's point in the replica's axes: on the magazine's left side, toward its back
# for a side grasp, up beside the base for one from below), its base turn the clear one of cycle.THUMB_TURNS whose
# tip comes nearest. The Sniper Rifle's fingers point right, so the forearm comes from the left, clear of the
# pistol grip just behind the magazine (fingers forward, it would pass through it while the magazine is seated).
SIDE_FINGERS = {"Index": (35, 40, 25), "Middle": (40, 45, 30), "Ring": (40, 45, 30), "Pinky": (35, 40, 25)}
UNDER_FINGERS = {"Index": (15, 20, 10), "Middle": (15, 20, 10), "Ring": (20, 25, 15), "Pinky": (25, 30, 20)}
GRASP = {
    "aeg": {"kind": "side", "at": (0.0, 0.068, -0.085), "turn": (-75, -15), "fingers": SIDE_FINGERS,
            "thumb": (-0.02, -0.03, 0.02)},
    "sniper": {"kind": "under", "turn": (75, 90), "fingers": UNDER_FINGERS, "thumb": (-0.02, 0.0, 0.015)},
    "pistol": {"kind": "under", "turn": (0, 90), "fingers": UNDER_FINGERS, "thumb": (-0.02, 0.0, 0.015)},
    "cyber": {"kind": "under", "turn": (0, 90), "fingers": UNDER_FINGERS, "thumb": (-0.02, 0.0, 0.015)},
}
TURN_STEP = 15
# The palm's roll either way about the fingers' line tried with each turn (degrees).
ROLLS = (-20, -10, 0, 10, 20)
# The hand takes the magazine this share of the way through its first move down (it has just started), keyed every
# STEP frames while it carries it; on its way to and from the hold it swings OUT (m, eye space) to the left at its
# middle, so it passes round the magazine and the handguard; away for the fresh magazine it dips DIP (m) down at its
# middle, out of view.
CATCH = 0.3
STEP = 2
OUT = Vector((-0.04, 0.0, -0.02))
DIP = Vector((-0.03, -0.04, -0.12))
# Leaving its hold the hand first uncurls each finger's joints OPEN_TURN (degrees, as the solver's relax opens them)
# over OPEN_FIRST of CLEAR_SHARE of its way to the magazine, then draws CLEAR (m, eye space: straight down) off it, its
# elbow where the hold had it, so the fingers come off the handguard or the grip rather than through it; coming back,
# the same reversed.
CLEAR = Vector((0.0, -0.01, -0.06))
CLEAR_SHARE = 0.4
OPEN_TURN = 30.0
OPEN_FIRST = 0.5
# The thumb stays as the hold has it while the hand comes off (it lies along the handguard's side: opening it would
# swing it in). A key whose left hand still passes into the replica eases it out as the solver's relax does: each
# joint that touches opens EASE_TURN (degrees), a palm that does draws EASE_BACK (m) along CLEAR, an arm that does
# swings its elbow EASE_SWING (degrees), at most EASE_STEPS times.
EASE_TURN = 1.5
EASE_BACK = 0.0008
EASE_SWING = 2.0
EASE_STEPS = 40
# The elbow may come this far across the body while the hand is at the magazine (a pistol's is under the middle of
# the view), and hangs at least DROP below the shoulder.
ACROSS = 0.30
DROP = 0.03
# A magazine counts as moved (m) once this far from its rest, and as still once a frame moves it less than this.
MOVED = 0.001
STILL = 0.0001


def reload_action(objects: list) -> tuple:
    """The replica's armature and its Reload clip (the importer's NLA strip of it); None where it has none."""
    for o in objects:
        if o.type != "ARMATURE" or MAG not in o.pose.bones or o.animation_data is None:
            continue
        for track in o.animation_data.nla_tracks:
            for strip in track.strips:
                if strip.action is not None and strip.action.name.split(".")[0] == CLIP:
                    return o, strip.action
    return None, None


def mag_at(arm, action, frame: int) -> Matrix:
    """The magazine bone's matrix (eye space: the replica already stands at its hold) at `frame` of the Reload clip."""
    arm.animation_data.action = action
    bpy.context.scene.frame_set(frame)
    return (arm.matrix_world @ arm.pose.bones[MAG].matrix).copy()


def phases(path: list) -> dict:
    """The magazine's moves through the clip (frames): it starts down (`first`), comes to rest out of the well
    (`out`), the fresh one shows (`back`) and is home (`home`); the hand takes it at `catch`."""
    rest = path[0].translation
    n = len(path) - 1
    first = next(f for f in range(n + 1) if (path[f].translation - rest).length > MOVED)
    jump = max(range(first, n), key=lambda f: (path[f + 1].translation - path[f].translation).length)
    out = next((f for f in range(first + 1, jump) if (path[f + 1].translation - path[f].translation).length < STILL),
               jump)
    back = jump + 1
    home = next((f for f in range(back, n + 1) if (path[f].translation - rest).length < MOVED), n)
    catch = first + int(round((out - first) * CATCH))
    return {"first": first, "catch": catch, "out": out, "back": back, "home": home, "end": n}


def smooth(t: float) -> float:
    t = min(1.0, max(0.0, t))
    return t * t * (3.0 - 2.0 * t)


def between(a: Matrix, b: Matrix, u: float, bump: Vector) -> Matrix:
    """`u` (eased) of the way from hand pose `a` to `b`, carried `bump` aside at the middle."""
    s = smooth(u)
    q = a.to_quaternion().slerp(b.to_quaternion(), s)
    at = a.translation.lerp(b.translation, s) + bump * math.sin(math.pi * s)
    return Matrix.Translation(at) @ q.to_matrix().to_4x4()


class MagChange:
    """The left hand's magazine change for one replica, from one hold."""

    def __init__(self, rig: Rig, hand: pose.Hand, rid: str, hold_to_eye: Matrix, objects: list, solid: list,
                 arms: list, elbow_for):
        self.rig, self.hand, self.rid, self.arms, self.elbow_for = rig, hand, rid, arms, elbow_for
        # The replica's own space into eye space (its hold), and the hand's grasp once found (`grasp`).
        self.hold_to_eye = hold_to_eye
        self.grip = None
        # The left shoulder's shift on the hold the change starts from and on the handguard hold (a grip hold may
        # bring it forward): away at the magazine it is the handguard hold's, so the forearm keeps behind a grip.
        self.shifts = (Vector(), Vector())
        self.spec = GRASP[rid]
        self.arm, self.action = reload_action(objects)
        if self.action is None:
            return
        self.length = int(round(self.action.frame_range[1]))
        self.path = [mag_at(self.arm, self.action, f) for f in range(self.length + 1)]
        self.arm.animation_data.action = None
        for pb in self.arm.pose.bones:
            pb.matrix_basis = Matrix.Identity(4)
        bpy.context.scene.frame_set(0)
        bpy.context.view_layer.update()
        self.at = phases(self.path)
        self.mags = [o for o in objects if o.type == "MESH" and o.parent_bone == MAG]
        # The checks leave the magazine out (it moves with the hand; the clip's poses aren't on the meshes here) and
        # the trigger (the right index finger's pad rests on it).
        self.frame = [o for o in solid if o not in self.mags and not o.name.startswith("Trigger")]
        self.col = Collider(solid)
        self.fingers = [b for b in rig.rest if b.endswith("_" + SIDE) and b.split("_")[0][:-1] in
                        ("Index", "Middle", "Ring", "Pinky", "Thumb")]
        # The magazine's way down out of the well (eye space).
        self.down = (self.path[self.at["out"]].translation - self.path[0].translation).normalized()

    def grasp(self) -> None:
        """The hand round the magazine at rest (`self.grip`: its pose, the elbow's pole, the fingers' turns)."""
        rig, hand, spec = self.rig, self.hand, self.spec
        right = [o for o in self.arms if o.name.endswith("_R")]
        rig.write()
        col = Collider.joined(self.col, Collider.posed(right))
        pts = [o.matrix_world @ v.co for o in self.mags for v in o.data.vertices]
        if spec["kind"] == "side":
            at = self.hold_to_eye @ Vector(spec["at"])
            palm = Vector((1.0, 0.0, 0.0))
            forward = (self.hold_to_eye.to_3x3() @ Vector((0.0, 1.0, 0.0))).normalized()
        else:
            # Under its base plate: the plate's middle (the magazine's lowest points along its way down), the palm
            # facing back up the magazine.
            low = max(p.dot(self.down) for p in pts)
            base = [p for p in pts if p.dot(self.down) > low - 0.004]
            at = sum(base, Vector()) / len(base)
            palm = -self.down
            forward = (self.hold_to_eye.to_3x3() @ Vector((0.0, 1.0, 0.0)))
            forward = (forward - palm * forward.dot(palm)).normalized()
        best = None
        for turn in range(spec["turn"][0], spec["turn"][1] + 1, TURN_STEP):
            for roll in ROLLS:
                if spec["kind"] == "side":
                    fingers = Matrix.Rotation(math.radians(turn), 3, palm) @ forward
                    p = Matrix.Rotation(math.radians(roll), 3, fingers) @ palm
                else:
                    fingers = Matrix.Rotation(math.radians(-turn), 3, palm) @ forward
                    p = Matrix.Rotation(math.radians(roll), 3, fingers) @ palm
                m = hand.place(at, fingers, p, 0.0, 0.0 if spec["kind"] == "under" else 0.03)
                m = hand.seat(m, p, col, whole=True)
                pole, bend = self.elbow_for(rig, SIDE, m, quiet=True)
                if pole is None:
                    continue
                if best is None or bend < best[0]:
                    best = (bend, turn, roll, m, pole, p)
        if best is None:
            raise SystemExit("%s: no elbow for the left hand on the magazine" % self.rid)
        bend, turn, roll, m, pole, p = best
        hand.normal = p
        hand.tip_top = None
        pose.place_arm(rig, SIDE, m, pole, quiet=True)
        rig.refresh("Hand_" + SIDE)
        curls = {name: hand.settle(name, start, col, span=30, root=True) for name, start in spec["fingers"].items()}
        curls["Thumb"] = cycle.clear_thumb(hand, col, at + self.hold_to_eye.to_3x3() @ Vector(spec["thumb"]))
        rig.write()
        print("  reload: the hand takes the magazine turned %d, rolled %d: wrist %.0f deg, fingers %s" % (
            turn, roll, pose.wrist_bend(rig, SIDE), curls))
        self.grip = (m, pole, {b: rig.local.get(b, Matrix.Identity(3)).copy() for b in self.fingers})

    def pose(self, hand_m: Matrix, turns: dict, pole: Vector, kept: Vector = None, free: float = 1.0) -> Vector:
        """The left arm reaching the hand pose `hand_m`, its fingers at `turns`; the elbow's pole used. With `kept`,
        the pole is that much `free` of the way from it to its own, and the shoulder as far to the handguard
        hold's."""
        rig = self.rig
        rig.shift["Shoulder_" + SIDE] = self.shifts[0].lerp(self.shifts[1], smooth(free))
        p, _ = self.elbow_for(rig, SIDE, hand_m, quiet=True)
        pole = p if p is not None else pole
        if kept is not None:
            pole = kept.lerp(pole, smooth(free))
        pose.place_arm(rig, SIDE, hand_m, pole, quiet=True)
        for b in self.fingers:
            rig.local[b] = turns[b]
        rig.refresh("Hand_" + SIDE)
        return pole

    def ease(self, pole: Vector) -> tuple:
        """The left arm as posed, eased out of the replica where it passes in (EASE_*); the clipping left (face
        pairs, and each bone's)."""
        rig, hand = self.rig, self.hand
        back = CLEAR.normalized() * EASE_BACK
        # Each joint opens; one that goes on passing in as much or more closes instead (it is hooked round a corner).
        way, last, best = {}, {}, None
        for _ in range(EASE_STEPS):
            rig.write()
            n, tally = pose.clipping(self.arms, self.frame)
            left = [b for b, k in tally.items() if b.endswith("_" + SIDE) and k]
            if not left:
                return n, tally
            if best is None or n < best[0]:
                best = (n, tally, dict(rig.pose), dict(rig.local))
            arm = [b for b in left if b.split("_")[0] in ("Forearm", "UpperArm")]
            if "Hand_" + SIDE in left:
                pose.place_arm(rig, SIDE, Matrix.Translation(back) @ rig.pose["Hand_" + SIDE], pole, quiet=True)
                rig.refresh("Hand_" + SIDE)
            elif arm:
                # Only the arm passes in (under a long stock): the elbow swings round the shoulder-to-wrist line,
                # the hand where it is, the other way if that does no good.
                count = sum(tally[b] for b in arm)
                if "arm" in last and count >= last["arm"] and "arm" not in way:
                    way["arm"] = -1.0
                last["arm"] = count
                line = rig.pose["Hand_" + SIDE].translation - rig.pose["UpperArm_" + SIDE].translation
                pole = Matrix.Rotation(math.radians(EASE_SWING * way.get("arm", 1.0)), 3, line) @ pole
                pose.place_arm(rig, SIDE, rig.pose["Hand_" + SIDE].copy(), pole, quiet=True)
                rig.refresh("Hand_" + SIDE)
            for b in left:
                if b in hand.axis:
                    if b in last and tally[b] >= last[b] and b not in way:
                        way[b] = -1.0
                    last[b] = tally[b]
                    turn = Matrix.Rotation(math.radians(-EASE_TURN * way.get(b, 1.0)), 3, hand.axis[b])
                    rig.fk(b, rig.local[b] @ turn)
                    rig.refresh(b)
        # Still in: the least clipping met on the way.
        rig.write()
        n, tally = pose.clipping(self.arms, self.frame)
        if n > best[0]:
            n, tally = best[0], best[1]
            rig.pose, rig.local = best[2], best[3]
            rig.write()
        return n, tally

    def turns_between(self, a: dict, b: dict, u: float) -> dict:
        s = smooth(u)
        return {k: a[k].to_quaternion().slerp(b[k].to_quaternion(), s).to_matrix() for k in self.fingers}

    def keys(self, held: dict, held_hand: Matrix, held_turns: dict, held_pole: Vector) -> tuple:
        """Each key's (frame, bases) from the hold (`held`: every bone's basis; the hand's pose, its fingers' turns
        and its elbow's pole) and back, and how many keys pass into the replica."""
        at = self.at
        grip_m, grip_pole, grip_turns = self.grip
        rest_inv = self.path[0].inverted()

        def carried(f: int) -> Matrix:
            return self.path[f] @ rest_inv @ grip_m

        cleared = Matrix.Translation(CLEAR) @ held_hand
        axis = self.hand.axis
        open_turns = {b: held_turns[b] @ Matrix.Rotation(math.radians(-OPEN_TURN), 3, axis[b])
                      if b in axis and not b.startswith("Thumb") else held_turns[b] for b in self.fingers}
        # A finger hooked round a corner (a pinky curled under the handguard) would open into it: it stays closed.
        self.pose(held_hand, open_turns, held_pole, held_pole, 0.0)
        self.rig.write()
        for b in pose.clipping(self.arms, self.frame)[1]:
            finger = b.split("_")[0][:-1]
            for k in (1, 2, 3):
                name = "%s%d_%s" % (finger, k, SIDE)
                if name in open_turns:
                    open_turns[name] = held_turns[name]
        clear_at = max(1, int(round(at["catch"] * CLEAR_SHARE)))
        back_at = at["end"] - max(1, int(round((at["end"] - at["home"]) * CLEAR_SHARE)))

        frames = (set(range(1, at["catch"] + 1, STEP)) | set(range(at["catch"], at["out"] + 1, STEP))
                  | set(range(at["out"], at["back"] + 1, STEP)) | set(range(at["back"], at["home"] + 1, STEP))
                  | set(range(at["home"], at["end"], STEP))
                  | {clear_at, at["catch"], at["out"], at["back"], at["home"], back_at})
        out, hits, pole = [(0, held)], 0, held_pole
        for f in sorted(frames):
            if f >= at["end"]:
                continue
            if f < clear_at:
                u = f / clear_at
                pole = self.pose(between(held_hand, cleared, max(0.0, u - OPEN_FIRST) / (1.0 - OPEN_FIRST),
                                         Vector()),
                                 self.turns_between(held_turns, open_turns, min(1.0, u / OPEN_FIRST)), pole,
                                 held_pole, 0.0)
            elif f < at["catch"]:
                u = (f - clear_at) / (at["catch"] - clear_at)
                pole = self.pose(between(cleared, carried(at["catch"]), u, OUT),
                                 self.turns_between(open_turns, grip_turns, u), pole, held_pole, u)
            elif f <= at["out"] or at["back"] <= f <= at["home"]:
                pole = self.pose(carried(f), grip_turns, pole)
            elif f < at["back"]:
                u = (f - at["out"]) / (at["back"] - at["out"])
                pole = self.pose(between(carried(at["out"]), carried(at["back"]), u, DIP), grip_turns, pole)
            elif f < back_at:
                u = (f - at["home"]) / (back_at - at["home"])
                pole = self.pose(between(carried(at["home"]), cleared, u, OUT),
                                 self.turns_between(grip_turns, open_turns, u), pole, held_pole, 1.0 - u)
            else:
                u = (f - back_at) / (at["end"] - back_at)
                pole = self.pose(between(cleared, held_hand, min(1.0, u / (1.0 - OPEN_FIRST)), Vector()),
                                 self.turns_between(open_turns, held_turns, max(0.0, u - (1.0 - OPEN_FIRST))
                                                    / OPEN_FIRST), pole, held_pole, 0.0)
            n, tally = self.ease(pole)
            if n:
                hits += 1
                print("   reload frame %d: %d face pairs pass into the replica %s" % (
                    f, n, sorted(tally.items(), key=lambda x: -x[1])[:4]))
            out.append((f, cycle.snapshot(self.rig)))
        out.append((at["end"], held))
        return out, hits


def change_mag(rig: Rig, hand: pose.Hand, rid: str, hold_to_eye: Matrix, objects: list, solid: list, arms: list,
               elbow_for, holds: dict) -> tuple:
    """Keys `<rid>_Reload` and `<rid>_<grip>_Reload` from each of `holds` ("" or the grip -> the rig on that hold:
    its pose, turns, shifts, drops, across and plan, as arms.kept takes them); how many keys pass into the replica in
    all, and the clips keyed. Nothing for a replica without a GRASP or a Reload clip."""
    if rid not in GRASP:
        return 0, []
    change = MagChange(rig, hand, rid, hold_to_eye, objects, solid, arms, elbow_for)
    if change.action is None:
        return 0, []
    kept = (dict(hand.adduct), hand.normal, hand.tip_top)
    print("  reload: the magazine starts down at frame %(first)d, is out at %(out)d, the fresh one shows at %(back)d "
          "and is home at %(home)d of %(end)d; the hand takes it at %(catch)d" % change.at)
    hits, clips = 0, []
    for name, kept_hold in holds.items():
        rig.pose, rig.local = dict(kept_hold[0]), dict(kept_hold[1])
        rig.shift, rig.drop, rig.across, rig.plan = (dict(d) for d in kept_hold[2:6])
        # The elbow free to come across under a pistol, and the forearm's angle from above left to the wrist.
        rig.plan.pop(SIDE, None)
        rig.across[SIDE] = max(rig.across.get(SIDE, 0.0), ACROSS)
        rig.drop[SIDE] = min(rig.drop.get(SIDE, DROP), DROP)
        rig.write()
        held = cycle.snapshot(rig)
        held_hand = rig.pose["Hand_" + SIDE].copy()
        held_turns = {b: rig.local.get(b, Matrix.Identity(3)).copy() for b in change.fingers}
        held_pole = rig.pose["Forearm_" + SIDE].translation - rig.pose["UpperArm_" + SIDE].translation
        change.shifts = tuple(Vector(h[2].get("Shoulder_" + SIDE, Vector())) for h in (kept_hold, holds[""]))
        if change.grip is None:
            # Once a replica: the hand takes the magazine the same way whichever hold it comes from.
            change.grasp()
        keys, n = change.keys(held, held_hand, held_turns, held_pole)
        clip = "%s_%s%s" % (rid, name + "_" if name else "", CLIP)
        rig.arm.animation_data.action = None
        cycle.key_frames(rig, clip, keys)
        clips.append(clip)
        print("  %s: %d keys, %d pass into the replica" % (clip, len(keys), n))
        hits += n
        if os.environ.get("BL_DEBUG"):
            print("   reload keys at", [k[0] for k in keys])
    hand.adduct, hand.normal, hand.tip_top = kept
    return hits, clips
