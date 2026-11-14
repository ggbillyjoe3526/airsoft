"""The left hand changing the magazine (BP8, the owner's playtest note 9: "when a weapon reloads a new magazine the
left arm should have an animation where it removes it and put a new one in"): a clip `<id>_Reload` (and one from each
foregrip's hold, `<id>_<grip>_Reload`) as long as the replica's own Reload clip, which the game plays at the same
share of the reload (ArmsView.follow), so the game's reload times and rules don't change.

The replica's Reload clip moves its magazine: down out of the well, away, a fresh one back in partway and seated home.
The hand leaves its hold (a pistol's: round the right hand, HA1), takes the magazine as it starts down,
its fingers and thumb closing on it, pulls it down along the clip's own path, carries it down out of view, comes back
up with the fresh one in hand to where the clip shows it, pushes it home along its path, lets go as it slides into the
well, and drops down out of view before coming back up to its hold. The game's
ViewModelConfig.reload_carry sets when the hand takes the magazine and lets it go, and over that span the game puts
the magazine in the hand (MagazineCarry): out of view with it and back with the fresh one.

Only the hand and the wrist show (the standing ruling for the arms in first person): away from its hold the elbow
goes where the least of the arm shows on screen (View: the game's eye camera through the reload, the replica canted
as ReplicaView cants it), so the forearm comes in from below the view, pointing back at you, never across it.

How the hand takes each replica's magazine (GRASP), as the magazine is when the hand takes it (partly out): a
rifle's or a pistol's from its left side, the palm on it, the knuckles at its front, the fingers round its front and
the thumb round its back (`side`); the Sniper Rifle's small box from below, the palm under it, the knuckles at its
right edge, the fingers up its right side and the thumb up its left (`under`). The hand's turn is searched for the
least arm on screen and the straightest wrist through the change, then the fingers close on the magazine (and never
into the right hand)."""

import math
import os
import re

import bpy
from mathutils import Matrix, Vector

import cycle
import pose
from glove import seg_dist
from pose import Collider, Rig

CLIP = "Reload"
MAG = "magazine"
SIDE = "L"
# How the hand takes the magazine, by replica: `kind` (side: palm on its left side, the fingers forward round its
# front; under: palm up under its base, the fingers over the edge they point at), `up` (a side grasp's palm centre, as a
# share of the magazine's height out of the well when the hand takes it, from its base), the fingers' pitch up from
# forward (side) or yaw from forward toward the right (under) searched over `turn` (degrees, from, to), the start
# bends the fingers settle from, and where the thumb's tip reaches for (`thumb`, m from the middle knuckle's point,
# in the replica's axes: round the magazine's back), its base turn the clear one of cycle.THUMB_TURNS whose tip comes
# nearest.
SIDE_FINGERS = {"Index": (70, 40, 30), "Middle": (70, 45, 30), "Ring": (70, 45, 30), "Pinky": (65, 45, 30)}
UNDER_FINGERS = {"Index": (70, 40, 30), "Middle": (70, 40, 30), "Ring": (70, 45, 30), "Pinky": (70, 50, 35)}
GRASP = {
    "aeg": {"kind": "side", "up": 0.45, "turn": (0, 60), "fingers": SIDE_FINGERS, "thumb": (-0.01, -0.045, 0.0)},
    "pistol": {"kind": "side", "up": 0.15, "turn": (0, 60), "fingers": SIDE_FINGERS, "thumb": (-0.01, -0.04, 0.0)},
    "cyber": {"kind": "side", "up": 0.15, "turn": (0, 60), "fingers": SIDE_FINGERS, "thumb": (-0.01, -0.04, 0.0)},
    "sniper": {"kind": "side", "up": 0.5, "turn": (0, 0), "fingers": SIDE_FINGERS, "thumb": (-0.01, -0.045, 0.0)},
    "smg": {"kind": "side", "up": 0.45, "turn": (0, 60), "fingers": SIDE_FINGERS, "thumb": (-0.01, -0.045, 0.0)},
    "shotgun": {"kind": "side", "up": 0.1, "turn": (0, 0), "fingers": SIDE_FINGERS, "thumb": (-0.01, -0.045, 0.0)},
}
TURN_STEP = 15
# A side grasp's palm centre sits on the magazine's points within BAND (m) of its height; the well's mouth is the
# replica's lowest point over the magazine's footprint, MOUTH_MARGIN (m) either side.
BAND = 0.01
MOUTH_MARGIN = 0.01
# The knuckles sit this far (m) behind the magazine's front (below 0: past it), so the fingers' first bones turn
# across its front and the rest round its far side (not further on, closing on nothing; nor further back, lying
# flat along its near side).
KNUCKLE_BACK = -0.005
# Pushing the fresh magazine home the hand lets go (ViewModelConfig.reload_carry's end): it stays where it is, its
# fingers opening, for LET_GO of the magazine's slide up out of it into the well, then drops away out of view.
LET_GO = 0.3
# Settled on the magazine, each finger's two outer joints close up to PRESS degrees more until they touch it: the
# fingers grip it rather than lie open beside it.
PRESS = 20
# A finger that finds nothing to close on (past a small magazine's end) curls only this far (degrees, base to tip),
# loose beside the others rather than in a fist; SETTLE_SPAN is how far past its start a finger may curl looking.
FREE_CURL = (45, 50, 35)
SETTLE_SPAN = 30
# The palm's roll either way about the fingers' line tried with each turn (degrees).
ROLLS = (-20, -10, 0, 10, 20)
# Away from its hold the elbow's place round the shoulder-to-wrist line is searched every POLE_STEP degrees for the
# least cost: VIS_COST for the whole screen covered by the arm (the upper arm, and the forearm up to WRIST_SHOWS m
# short of the wrist; as capsules of UPPER_R and FOREARM_R m drawn on a GRID of cells), BEND_COST a degree of wrist
# bend over BEND_FREE (BEND_HARD_COST over BEND_HARD), PLACE_COST a metre the elbow rises over the shoulder
# (ELBOW_RISE), crosses the body's middle
# (ELBOW_X) or sinks into the chest (CHEST: behind y, inside |x|), and MOVE_COST a metre it moves from the last key's.
# SHOWN_COST a metre the arm shows on screen past SHOWN_FROM from the wrist (sampled ARM_SAMPLES times along the
# forearm and the upper arm from UPPER_FROM of the way down it, ARM_R m thick: tests/unit/test_bp8_arms.gd's check).
POLE_STEP = 15
VIS_COST = 1000.0
SHOWN_COST = 2000.0
SHOWN_FROM = 0.03
ARM_SAMPLES = 24
UPPER_FROM = 0.4
ARM_R = 0.02
WRIST_SHOWS = 0.05
UPPER_R = 0.065
FOREARM_R = 0.05
GRID = (48, 27)
SAMPLE = 0.02
BEND_COST = 1.0
BEND_FREE = 30.0
BEND_HARD_COST = 10.0
BEND_HARD = 40.0
PLACE_COST = 1000.0
ELBOW_RISE = 0.05
ELBOW_X = 0.1
CHEST = (0.0, 0.15)
MOVE_COST = 30.0
# The game's tuning the view is read from (ReplicaView's reload cant; the eye camera's field of view and near plane).
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
VIEWMODEL = os.path.join(ROOT, "game", "config", "viewmodel_config.gd")
VIEW = os.path.join(ROOT, "game", "config", "view_config.gd")
# Out of view, the hand (and the magazine it carries) is straight down the view from where it would be, far enough
# that every point of it is HIDE_MARGIN (m) clear of the screen's edges, in steps of DROP_STEP (m) up to DROP_MAX:
# carrying the old magazine away it is down there from DIP_IN of the way between the clip's old magazine out and the
# fresh one showing to DIP_OUT; going home, from RETURN_DOWN of the way between the hand letting go and its
# last stretch to its hold (the last RETURN_CLEAR of the way home) to RETURN_UP, so it comes up into its hold
# only as the replica's cant goes.
HIDE_MARGIN = 0.03
DROP_STEP = 0.01
DROP_MAX = 0.8
DIP_IN = 0.35
DIP_OUT = 0.65
RETURN_DOWN = 0.35
RETURN_UP = 0.75
RETURN_CLEAR = 0.15
# The hand is keyed every STEP frames while it carries the magazine; on its way from the hold it swings OUT (m, eye
# space) to the left at its middle, so it passes round the magazine and the handguard.
STEP = 2
OUT = Vector((-0.04, 0.0, -0.02))
# Leaving its hold the hand first uncurls each finger's joints OPEN_TURN (degrees, as the solver's relax opens them)
# over OPEN_FIRST of CLEAR_SHARE of its way to the magazine, then draws CLEAR (m, eye space: straight down) off it, its
# elbow where the hold had it, so the fingers come off the handguard or the grip rather than through it; coming back,
# the same reversed, over the last RETURN_CLEAR of the way home.
CLEAR = Vector((0.0, -0.01, -0.06))
# Off a pistol held in both hands (HA1) it draws out to the left first: straight down, the palm dragged through the
# right hand's fingers it lies on.
CLEAR_BOTH = Vector((-0.035, -0.01, -0.035))
# And its elbow keeps ARM_CLEAR (m) off the right arm's bones as posed: tucked in under the pistol it would pass through
# the right forearm, below the screen. Checked at the elbow and these shares of the way up the upper arm and down the
# forearm from it (the wrists meet at the pistol).
ARM_CLEAR = 0.09
ARM_CLEAR_AT = (0.0, 0.2, 0.4)
CLEAR_SHARE = 0.4
OPEN_TURN = 30.0
OPEN_FIRST = 0.5
# The thumb stays as the hold has it while the hand comes off (it lies along the handguard's side: opening it would
# swing it in). A key whose left hand still passes into the replica eases it out as the solver's relax does: each
# joint that touches opens EASE_TURN (degrees), a palm that does draws EASE_BACK (m) along CLEAR, an arm that does
# swings its elbow EASE_SWING (degrees), at most EASE_STEPS times.
# Coming off its hold and going back onto it, the arm shows no more than the hold itself does plus KEEP_SLACK (m), or
# KEEP_CUFF (m, the hand and cuff: just inside the test's ARM_CUFF): where the hold's own elbow would swing a straight
# forearm up into view as the hand drops (HA1), the elbow goes KEEP_STEP of the way to `elbow_for`'s at a time until
# it doesn't.
KEEP_SLACK = 0.01
KEEP_CUFF = 0.065
KEEP_STEP = 0.125
# The replica cants up as the change starts and ends, lifting the arm with it: where the hand drawn CLEAR off its hold
# still shows more arm than that, it draws CLEAR_MORE of CLEAR further at a time, at most CLEAR_TRIES times.
CLEAR_MORE = 0.25
CLEAR_TRIES = 4
EASE_TURN = 1.5
EASE_BACK = 0.0008
EASE_SWING = 2.0
EASE_STEPS = 40
# A magazine counts as moved (m) once this far from its rest, and as still once a frame moves it less than this.
MOVED = 0.001
STILL = 0.0001


def exported(path: str) -> dict:
    """Each `@export var <name>: <type> = <value>` of a config script (its value may go on over indented lines):
    name -> the value's text."""
    out, name = {}, None
    with open(path) as f:
        for line in f:
            m = re.match(r"@export var (\w+)\s*:[^=]*=\s*(.+)$", line.rstrip())
            if m:
                name = m.group(1)
                out[name] = m.group(2)
            elif name is not None and line.startswith("\t"):
                out[name] += " " + line.strip()
            else:
                name = None
    return out


def listed(text: str, rid: str):
    """Replica `rid`'s entry of a dictionary's text (a float, or a vector's numbers as a tuple); None if not there."""
    m = re.search(r'&"%s"\s*:\s*(Vector[23]\(([^)]*)\)|[-\d.]+)' % re.escape(rid), text)
    if m is None:
        return None
    if m.group(2) is not None:
        return tuple(float(v) for v in m.group(2).split(","))
    return float(m.group(1))


def smoothstep(a: float, b: float, x: float) -> float:
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


class View:
    """The game's eye camera through one replica's reload, in the build's eye space: ReplicaView cants the replica
    (and the arms on it) about its origin (`pivot`, eye space) by ViewModelConfig's reload cant, as much as its
    reload bell has at that share of the reload; the camera sees ViewConfig's field of view (16:9) from its near
    plane."""

    def __init__(self, rid: str, pivot: Vector):
        vm, vc = exported(VIEWMODEL), exported(VIEW)
        self.cant = listed(vm["reload_cant_by"], rid) or tuple(
            float(vm[k]) for k in ("reload_tilt", "reload_turn", "reload_roll"))
        self.move = listed(vm["reload_move_by"], rid) or (float(vm["reload_lift"]), float(vm["reload_inward"]), 0.0)
        self.rise = listed(vm["reload_rise"], rid) or 0.0
        # When the hand takes the magazine and lets it go (shares of the reload).
        self.carry = listed(vm["reload_carry"], rid)
        self.pivot = pivot.copy()
        # The game draws the replica at ViewModelConfig.hip, which need not be where its hold is solved (`pivot`: a
        # rifle's, HA1): the arms ride it there, so the view is that much off.
        hip = listed(vm["hip"], rid)
        self.seen = Vector((hip[0], -hip[2], hip[1])) - pivot if hip else Vector((0.0, 0.0, 0.0))
        self.tan_h = math.tan(math.radians(float(vc["horizontal_fov_16x9"])) * 0.5)
        self.tan_v = self.tan_h * 9.0 / 16.0
        self.near = float(vc["near"])

    def bell(self, share: float) -> float:
        """ViewModelConfig.reload_bell."""
        if self.rise <= 0.0:
            return math.sin(math.pi * min(1.0, max(0.0, share)))
        return smoothstep(0.0, self.rise, share) * smoothstep(0.0, self.rise, 1.0 - share)

    def at(self, share: float) -> Matrix:
        """Eye space as built into the game's eye space, `share` of the way through the reload. The game's Euler
        (YXZ: turn about up, tilt about right, roll about back) and moves (lift, inward, forward) in eye space."""
        b = self.bell(share)
        tilt, turn, roll = (v * b for v in self.cant)
        lift, inward, forward = (v * b for v in self.move)
        r = (Matrix.Rotation(turn, 4, "Z") @ Matrix.Rotation(tilt, 4, "X")
             @ Matrix.Rotation(-roll, 4, "Y"))
        return (Matrix.Translation(self.seen + self.pivot + Vector((-inward, forward, lift))) @ r
                @ Matrix.Translation(-self.pivot))

    def hidden(self, cam: Matrix, pts: list) -> bool:
        """Whether every point (eye space as built) is out of view through `cam`, HIDE_MARGIN clear of its edges."""
        for p in pts:
            q = cam @ p
            if q.y < self.near:
                continue
            mx, mz = HIDE_MARGIN / (q.y * self.tan_h), HIDE_MARGIN / (q.y * self.tan_v)
            sx, sz = q.x / (q.y * self.tan_h), q.z / (q.y * self.tan_v)
            if abs(sx) < 1.0 + mx and abs(sz) < 1.0 + mz:
                return False
        return True

    def shown(self, cam: Matrix, shoulder: Vector, elbow: Vector, wrist: Vector) -> float:
        """How far from the wrist (m) the arm shows through `cam`: its samples ARM_R clear of the screen's edges."""
        most = 0.0
        fore = (wrist - elbow).length
        for a, b, upper in ((shoulder.lerp(elbow, UPPER_FROM), elbow, True), (elbow, wrist, False)):
            for k in range(ARM_SAMPLES + 1):
                q = a.lerp(b, k / ARM_SAMPLES)
                c = cam @ q
                if c.y <= 0.0:
                    continue
                mx, mz = ARM_R / (c.y * self.tan_h), ARM_R / (c.y * self.tan_v)
                if abs(c.x / (c.y * self.tan_h)) < 1.0 + mx and abs(c.z / (c.y * self.tan_v)) < 1.0 + mz:
                    most = max(most, (q - elbow).length + fore if upper else (wrist - q).length)
        return most

    def covered(self, cam: Matrix, capsules: list) -> float:
        """The share of the screen the capsules ((from, to, radius), eye space as built) cover through `cam`."""
        nx, nz = GRID
        cells = set()
        for a, b, r in capsules:
            a, b = cam @ a, cam @ b
            n = max(1, int((b - a).length / SAMPLE))
            for k in range(n + 1):
                q = a.lerp(b, k / n)
                if q.y < self.near:
                    continue
                sx, sz = q.x / (q.y * self.tan_h), q.z / (q.y * self.tan_v)
                rx, rz = r / (q.y * self.tan_h), r / (q.y * self.tan_v)
                if sx - rx > 1.0 or sx + rx < -1.0 or sz - rz > 1.0 or sz + rz < -1.0:
                    continue
                i0, i1 = max(0, int((sx - rx + 1.0) * 0.5 * nx)), min(nx - 1, int((sx + rx + 1.0) * 0.5 * nx))
                j0, j1 = max(0, int((sz - rz + 1.0) * 0.5 * nz)), min(nz - 1, int((sz + rz + 1.0) * 0.5 * nz))
                for i in range(i0, i1 + 1):
                    cx = ((i + 0.5) / nx * 2.0 - 1.0 - sx) / rx
                    for j in range(j0, j1 + 1):
                        cz = ((j + 0.5) / nz * 2.0 - 1.0 - sz) / rz
                        if cx * cx + cz * cz <= 1.0:
                            cells.add((i, j))
        return len(cells) / float(nx * nz)


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


def phases(path: list, carry: tuple) -> dict:
    """The magazine's moves through the clip (frames): it starts down (`first`), comes to rest out of the well
    (`out`), the fresh one shows (`back`) and is home (`home`); the hand takes it at `catch` and lets it go at `push`,
    `carry`'s shares of the clip (ViewModelConfig.reload_carry)."""
    rest = path[0].translation
    n = len(path) - 1
    first = next(f for f in range(n + 1) if (path[f].translation - rest).length > MOVED)
    jump = max(range(first, n), key=lambda f: (path[f + 1].translation - path[f].translation).length)
    out = next((f for f in range(first + 1, jump) if (path[f + 1].translation - path[f].translation).length < STILL),
               jump)
    back = jump + 1
    home = next((f for f in range(back, n + 1) if (path[f].translation - rest).length < MOVED), n)
    catch, push = (int(round(share * n)) for share in carry)
    if not (first <= catch < out and back <= push < home):
        raise ValueError("reload_carry %s: the hand must take the magazine between frames %d and %d and let it go "
                         "between %d and %d of %d (it has %d and %d)" % (carry, first, out, back, home, n, catch, push))
    return {"first": first, "catch": catch, "out": out, "back": back, "push": push, "home": home, "end": n}


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
                 arms: list):
        self.rig, self.hand, self.rid, self.arms = rig, hand, rid, arms
        # The arms checked against the replica (`frame`): both, or the left alone where the right is part of the frame.
        self.moving = arms
        # Bones the left elbow keeps clear of (each its two ends, eye space): the right arm's, in both hands.
        self.avoid = []
        # The replica's own space into eye space (its hold), and the hand's grasp once found (`grasp`).
        self.hold_to_eye = hold_to_eye
        self.grip = None
        # The left shoulder's shift on the hold the change starts from and on the handguard hold (a grip hold may
        # bring it forward): away at the magazine it is the handguard hold's, so the forearm keeps behind a grip.
        self.shifts = (Vector(), Vector())
        # How the hand draws off its hold (CLEAR, or CLEAR_BOTH off the right hand).
        self.clear = CLEAR
        self.spec = GRASP[rid]
        self.solid = solid
        self.view = View(rid, hold_to_eye.translation)
        # The frame being keyed (its view) and the last key's elbow (`pose` keeps it near).
        self.now, self.elbow = 0, None
        # The most of the arm that may show while its elbow keeps to the hold's (KEEP_*; None: no limit yet).
        self.most = None
        self.arm, self.action = reload_action(objects)
        if self.action is None:
            return
        self.length = int(round(self.action.frame_range[1]))
        self.path = [mag_at(self.arm, self.action, f) for f in range(self.length + 1)]
        if self.view.carry is None:
            raise ValueError("%s: no ViewModelConfig.reload_carry for its magazine change" % rid)
        self.at = phases(self.path, self.view.carry)
        # The hand stays under the fresh magazine, opening, for LET_GO of its slide home, then goes.
        self.at["let_go"] = self.at["push"] + max(STEP, int(round((self.at["home"] - self.at["push"]) * LET_GO)))
        self.rest()
        self.mags = [o for o in objects if o.type == "MESH" and o.parent_bone == MAG]
        # The checks leave the magazine out (it moves with the hand; the clip's poses aren't on the meshes here) and
        # the trigger (the right index finger's pad rests on it).
        self.frame = [o for o in solid if o not in self.mags and not o.name.startswith("Trigger")]
        self.frame_col = None
        self.fingers = [b for b in rig.rest if b.endswith("_" + SIDE) and b.split("_")[0][:-1] in
                        ("Index", "Middle", "Ring", "Pinky", "Thumb")]

    def rest(self) -> None:
        """The replica's armature back at rest, no clip on it."""
        self.arm.animation_data.action = None
        for pb in self.arm.pose.bones:
            pb.matrix_basis = Matrix.Identity(4)
        bpy.context.scene.frame_set(0)
        bpy.context.view_layer.update()

    def elbow_for(self, hand_m: Matrix, f: int, near: Vector = None) -> tuple:
        """The least cost (POLE_STEP ...) elbow for the left hand at `hand_m` at frame `f`, kept near `near`: (cost,
        the pole, the elbow, the share of the screen the arm covers, the wrist's bend)."""
        rig = self.rig
        up, fo, hn = "UpperArm_" + SIDE, "Forearm_" + SIDE, "Hand_" + SIDE
        rig.fk("Shoulder_" + SIDE)
        rig.fk(up)
        s = rig.pose[up].translation.copy()
        a = (rig.rest[fo].translation - rig.rest[up].translation).length
        b = (rig.rest[hn].translation - rig.rest[fo].translation).length
        w = hand_m.translation
        line = (w - s).normalized()
        u0 = line.orthogonal().normalized()
        straight = (hand_m.to_3x3() @ rig.rest[hn].to_3x3().inverted() @ rig.rest[fo].to_3x3()).col[1]
        cam = self.view.at(f / max(self.length, 1))
        best = None
        for k in range(0, 360, POLE_STEP):
            pole = Matrix.Rotation(math.radians(k), 3, line) @ u0
            e = pose.two_bone(s, w, a, b, pole)
            fore = w - e
            shown = w - fore.normalized() * WRIST_SHOWS
            cover = self.view.covered(cam, [(s, e, UPPER_R), (e, shown, FOREARM_R)])
            bend = math.degrees(straight.angle(fore))
            wrong = (max(0.0, e.z - s.z - ELBOW_RISE) + max(0.0, e.x - ELBOW_X)
                     + (min(CHEST[0] - e.y, CHEST[1] - abs(e.x)) if e.y < CHEST[0] and abs(e.x) < CHEST[1] else 0.0))
            for share in ARM_CLEAR_AT:
                for p in (e.lerp(s, share), e.lerp(w, share)):
                    wrong += sum(max(0.0, ARM_CLEAR - seg_dist(p, a2, b2)) for a2, b2 in self.avoid)
            past = max(0.0, self.view.shown(cam, s, e, w) - SHOWN_FROM)
            cost = (cover * VIS_COST + past * SHOWN_COST + max(0.0, bend - BEND_FREE) * BEND_COST
                    + max(0.0, bend - BEND_HARD) * BEND_HARD_COST + wrong * PLACE_COST
                    + ((e - near).length * MOVE_COST if near is not None else 0.0))
            if best is None or cost < best[0]:
                best = (cost, pole, e, cover, bend)
        return best

    def reach(self, hand_m: Matrix, f: int) -> tuple:
        """The left arm reaching hand pose `hand_m` at frame `f`, its elbow where `elbow_for` puts it; that."""
        found = self.elbow_for(hand_m, f)
        pose.place_arm(self.rig, SIDE, hand_m, found[1], quiet=True)
        return found

    def grasp(self) -> None:
        """The hand round the magazine where it takes it (`self.grip`: its pose there, the fingers' turns)."""
        rig, hand, spec = self.rig, self.hand, self.spec
        right = [o for o in self.arms if o.name.endswith("_R")]
        rig.write()
        self.arm.animation_data.action = self.action
        bpy.context.scene.frame_set(self.at["catch"])
        bpy.context.view_layer.update()
        col = Collider.joined(Collider(self.solid), Collider.posed(right))
        pts = [o.matrix_world @ v.co for o in self.mags for v in o.data.vertices]
        self.rest()
        to_eye = self.hold_to_eye.to_3x3()
        forward = (to_eye @ Vector((0.0, 1.0, 0.0))).normalized()
        up = (to_eye @ Vector((0.0, 0.0, 1.0))).normalized()
        left = -(to_eye @ Vector((1.0, 0.0, 0.0))).normalized()
        # The magazine's part out of the well (eye space heights along the replica's up): from its base to the well's
        # mouth, the replica's lowest point over the magazine's footprint.
        low = min(p.dot(up) for p in pts)
        fwd = (min(p.dot(forward) for p in pts), max(p.dot(forward) for p in pts))
        side = (min(p.dot(left) for p in pts) - MOUTH_MARGIN, max(p.dot(left) for p in pts) + MOUTH_MARGIN)
        body = [q for o in self.frame for q in (o.matrix_world @ v.co for v in o.data.vertices)
                if fwd[0] <= q.dot(forward) <= fwd[1] and side[0] <= q.dot(left) <= side[1]]
        mouth = min((q.dot(up) for q in body if q.dot(up) > low), default=max(p.dot(up) for p in pts))
        top = min(max(p.dot(up) for p in pts), mouth)
        if spec["kind"] == "side":
            height = low + (top - low) * spec["up"]
            # The points near that height (a low-poly box has its corners only at its ends: then all of them).
            face = [p for p in pts if abs(p.dot(up) - height) < BAND] or pts
            mid = (min(p.dot(forward) for p in face) + max(p.dot(forward) for p in face)) * 0.5
            centre = forward * mid + up * height + left * max(p.dot(left) for p in face)
            palm = -left
        else:
            face = [p for p in pts if p.dot(up) < low + 0.004]
            centre = sum(face, Vector()) / len(face)
            palm = up
        # The palm's centre to its middle knuckle, along the fingers.
        knuckle = (rig.rest["Middle1_" + SIDE].translation - hand.palm_centre).dot(hand.fingers)
        best = None
        catch_inv = self.path[self.at["catch"]].inverted()
        for turn in range(spec["turn"][0], spec["turn"][1] + 1, TURN_STEP):
            for roll in ROLLS:
                if spec["kind"] == "side":
                    fingers = Matrix.Rotation(math.radians(turn), 3, palm) @ forward
                else:
                    fingers = Matrix.Rotation(math.radians(-turn), 3, palm) @ forward
                p = Matrix.Rotation(math.radians(roll), 3, fingers) @ palm
                # The knuckles at the face's edge the fingers point over.
                at = centre + fingers * (max(q.dot(fingers) for q in face) - KNUCKLE_BACK - centre.dot(fingers))
                m = hand.place(at, fingers, p, knuckle, 0.0)
                m = hand.seat(m, p, col, whole=True)
                cost = sum(self.elbow_for(self.path[self.at[k]] @ catch_inv @ m, self.at[k])[0]
                           for k in ("catch", "out", "back", "home"))
                if best is None or cost < best[0]:
                    best = (cost, turn, roll, m, p, at)
        cost, turn, roll, m, p, at = best
        hand.normal = p
        hand.tip_top = None
        found = self.reach(m, self.at["catch"])
        rig.refresh("Hand_" + SIDE)
        curls = {}
        for name, start in spec["fingers"].items():
            settled = hand.settle(name, start, col, span=SETTLE_SPAN, root=True)
            if settled[0] >= start[0] + SETTLE_SPAN:
                curls[name] = hand.settle(name, FREE_CURL, col, span=0, root=True)
            else:
                curls[name] = hand.press(name, settled, col, extra=PRESS)
        curls["Thumb"] = cycle.clear_thumb(hand, col, at + to_eye @ Vector(spec["thumb"]))
        rig.write()
        print("  reload: the hand takes the magazine turned %d, rolled %d: wrist %.0f deg, arm on %.0f%% of the "
              "screen, fingers %s" % (turn, roll, pose.wrist_bend(rig, SIDE), found[3] * 100.0, curls))
        self.grip = (m, {b: rig.local.get(b, Matrix.Identity(3)).copy() for b in self.fingers})
        # The hand's reach (its fingers' joints and tips) and the magazine's box, in the hand's space: what must be
        # out of view to call the hand out of view.
        hand_inv = rig.pose["Hand_" + SIDE].inverted()
        self.hand_pts = [hand_inv @ rig.pose["Hand_" + SIDE].translation]
        for b in self.fingers:
            self.hand_pts.append(hand_inv @ rig.pose[b].translation)
            self.hand_pts.append(hand_inv @ (rig.pose[b].translation + rig.pose[b].to_3x3().col[1] * rig.length[b]))
        local = [hand_inv @ p for p in pts]
        lo = Vector([min(p[k] for p in local) for k in range(3)])
        hi = Vector([max(p[k] for p in local) for k in range(3)])
        self.mag_pts = [Vector((hi.x if k & 1 else lo.x, hi.y if k & 2 else lo.y, hi.z if k & 4 else lo.z))
                        for k in range(8)]

    def below(self, hand_m: Matrix, frames: list, carrying: bool) -> Matrix:
        """`hand_m` moved straight down the view (the camera's at the frames' middle) until the hand, and the
        magazine if `carrying`, is out of view at each of `frames` (DROP_*)."""
        pts = self.hand_pts + (self.mag_pts if carrying else [])
        cams = [self.view.at(f / max(self.length, 1)) for f in frames]
        mid = cams[len(cams) // 2]
        down = mid.to_3x3().inverted() @ Vector((0.0, 0.0, -1.0))
        drop = 0.0
        while drop < DROP_MAX:
            m = Matrix.Translation(down * drop) @ hand_m
            if all(self.view.hidden(cam, [m @ p for p in pts]) for cam in cams):
                return m
            drop += DROP_STEP
        print("   reload: the hand is still in view %.2f m down at frames %s" % (DROP_MAX, frames))
        return Matrix.Translation(down * DROP_MAX) @ hand_m

    def pose(self, hand_m: Matrix, turns: dict, kept: Vector = None, free: float = 1.0) -> Vector:
        """The left arm reaching the hand pose `hand_m` at frame `self.now`, its fingers at `turns`; the elbow's pole
        used. With `kept` (the hold's pole), the pole is `free` of the way from it to `elbow_for`'s, and the shoulder
        as far to the handguard hold's."""
        rig = self.rig
        rig.shift["Shoulder_" + SIDE] = self.shifts[0].lerp(self.shifts[1], smooth(free))
        found = self.elbow_for(hand_m, self.now, self.elbow)
        pole = found[1]
        if kept is not None:
            share = smooth(free)
            pole = kept.lerp(found[1], share)
            pose.place_arm(rig, SIDE, hand_m, pole, quiet=True)
            while self.most is not None and share < 1.0 and self.arm_shown() > self.most:
                share = min(1.0, share + KEEP_STEP)
                pole = kept.lerp(found[1], share)
                pose.place_arm(rig, SIDE, hand_m, pole, quiet=True)
        else:
            pose.place_arm(rig, SIDE, hand_m, pole, quiet=True)
        self.elbow = rig.pose["Forearm_" + SIDE].translation.copy()
        if os.environ.get("BL_DEBUG"):
            print("   frame %d: arm on %.1f%% of the screen at best, wrist %.0f deg, elbow %s, shows %.3f m" % (
                self.now, found[3] * 100.0, found[4], tuple(round(v, 3) for v in self.elbow), self.arm_shown()))
        for b in self.fingers:
            rig.local[b] = turns[b]
        rig.refresh("Hand_" + SIDE)
        return pole

    def arm_shown(self) -> float:
        """How far from the wrist (m) the left arm as posed shows at frame `self.now` (View.shown)."""
        at = self.rig.pose
        return self.view.shown(self.view.at(self.now / max(self.length, 1)), at["UpperArm_" + SIDE].translation,
                               at["Forearm_" + SIDE].translation, at["Hand_" + SIDE].translation)

    def ease(self, pole: Vector) -> tuple:
        """The left arm as posed, eased out of the replica where it passes in (EASE_*); the clipping left (face
        pairs, and each bone's)."""
        rig, hand = self.rig, self.hand
        back = self.clear.normalized() * EASE_BACK
        # Each joint opens; one that goes on passing in as much or more closes instead (it is hooked round a corner).
        way, last, best = {}, {}, None
        for _ in range(EASE_STEPS):
            rig.write()
            n, tally = pose.clipping(self.moving, self.frame)
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
        n, tally = pose.clipping(self.moving, self.frame)
        if n > best[0]:
            n, tally = best[0], best[1]
            rig.pose, rig.local = best[2], best[3]
            rig.write()
        return n, tally

    def turns_between(self, a: dict, b: dict, u: float) -> dict:
        s = smooth(u)
        return {k: a[k].to_quaternion().slerp(b[k].to_quaternion(), s).to_matrix() for k in self.fingers}

    def push_start(self) -> int:
        """The frame the hand lets the fresh magazine go, to slide on home."""
        return self.at["push"]

    def pushing(self, f: int, turns: dict) -> dict:
        """The fingers' turns at frame `f` while the hand carries the magazine: from `turns` round it, opening
        (`opened`) once it lets go, as it slides up out of the hand into the well."""
        at = self.at
        if f < at["back"]:
            return turns
        start = self.push_start()
        return self.turns_between(turns, self.opened(turns), (f - start) / max(at["let_go"] - start, 1.0))

    def opened(self, turns: dict) -> dict:
        """`turns` with each finger's joints (not the thumb's) uncurled OPEN_TURN."""
        axis = self.hand.axis
        return {b: turns[b] @ Matrix.Rotation(math.radians(-OPEN_TURN), 3, axis[b])
                if b in axis and not b.startswith("Thumb") else turns[b] for b in self.fingers}

    def keys(self, held: dict, held_hand: Matrix, held_turns: dict, held_pole: Vector) -> tuple:
        """Each key's (frame, bases) from the hold (`held`: every bone's basis; the hand's pose, its fingers' turns
        and its elbow's pole) and back, and how many keys pass into the replica."""
        at = self.at
        grip_m, grip_turns = self.grip
        catch_inv = self.path[at["catch"]].inverted()
        push = self.push_start()

        def carried(f: int) -> Matrix:
            # Pushing it home the hand stays where it is as the magazine slides up out of it into the well.
            m = self.path[f] @ catch_inv @ grip_m
            if at["back"] <= f and f > push:
                m = Matrix.Translation(self.path[push].translation - self.path[f].translation) @ m
            return m

        def part(a: int, b: int, share: float) -> int:
            return a + int(round((b - a) * share))

        clear_at = max(1, int(round(at["catch"] * CLEAR_SHARE)))
        back_at = at["end"] - max(1, int(round((at["end"] - at["let_go"]) * RETURN_CLEAR)))
        # Away for the fresh magazine: the old one carried down out of view, the fresh one brought up from there.
        dip_in, dip_out = part(at["out"], at["back"], DIP_IN), part(at["out"], at["back"], DIP_OUT)
        self.now, self.elbow = at["out"], None
        dip_m = self.below(between(carried(at["out"]), carried(at["back"]), 0.5, Vector()),
                           list(range(dip_in, dip_out + 1)), True)
        frames = (set(range(1, at["catch"] + 1, STEP)) | set(range(at["catch"], at["out"] + 1, STEP))
                  | set(range(at["out"], at["back"] + 1, STEP)) | set(range(at["back"], at["home"] + 1, STEP))
                  | set(range(at["home"], at["end"], STEP))
                  | {clear_at, at["catch"], at["out"], dip_in, dip_out, at["back"], push, at["let_go"], back_at})

        def carrying(f: int, turns: dict) -> Vector:
            # From taking the old magazine to the fresh one home: along the clip's path, or down out of view between.
            if f <= at["out"] or at["back"] <= f <= at["let_go"]:
                return self.pose(carried(f), self.pushing(f, turns))
            if f < dip_in:
                return self.pose(between(carried(at["out"]), dip_m, (f - at["out"]) / (dip_in - at["out"]),
                                         Vector()), turns)
            if f <= dip_out:
                return self.pose(dip_m, turns)
            return self.pose(between(dip_m, carried(at["back"]), (f - dip_out) / (at["back"] - dip_out), Vector()),
                             turns)

        open_turns = self.opened(held_turns)
        open_turns.update({b: held_turns[b] for b in self.fingers if b.startswith("Thumb")})
        # A finger hooked round a corner (a pinky curled under the handguard) would open into it: it stays closed.
        self.now, self.elbow, self.most = 0, None, None
        self.pose(held_hand, open_turns, held_pole, 0.0)
        self.most = max(KEEP_CUFF, self.arm_shown() + KEEP_SLACK)
        # Drawn off the hold: as far as CLEAR, or further where the arm would show more than the hold's (CLEAR_MORE),
        # as the hand leaves and as it comes back.
        cleared = Matrix.Translation(self.clear) @ held_hand
        for k in range(CLEAR_TRIES + 1):
            cleared = Matrix.Translation(self.clear * (1.0 + CLEAR_MORE * k)) @ held_hand
            shown = 0.0
            for f in (clear_at, back_at):
                self.now, self.elbow = f, None
                self.pose(cleared, open_turns, held_pole, 0.0)
                shown = max(shown, self.arm_shown())
            if shown <= self.most:
                break
        if os.environ.get("BL_DEBUG"):
            print("   drawn off the hold %.0f mm: %.3f m of the arm shows (the hold's most %.3f)" % (
                (cleared.translation - held_hand.translation).length * 1000.0, shown, self.most))
        self.now, self.elbow = 0, None
        self.pose(held_hand, open_turns, held_pole, 0.0)
        self.rig.write()
        for b in pose.clipping(self.moving, self.frame)[1]:
            finger = b.split("_")[0][:-1]
            for k in (1, 2, 3):
                name = "%s%d_%s" % (finger, k, SIDE)
                if name in open_turns:
                    open_turns[name] = held_turns[name]
        # Going home: down out of view from the fresh magazine, then up under the hold from below.
        ret_down, ret_up = part(at["let_go"], back_at, RETURN_DOWN), part(at["let_go"], back_at, RETURN_UP)
        away_m = self.below(cleared, list(range(ret_down, ret_up + 1)), False)
        frames |= {ret_down, ret_up}
        out, hits = [(0, held)], 0
        for f in sorted(frames):
            if f >= at["end"]:
                continue
            self.now = f
            # The elbow stays as the hold has it while the fingers come off (so the thumb stays clear of a grip), goes
            # over on the way to the magazine, and comes back over the way up to the hold.
            if f < clear_at:
                u = f / clear_at
                pole = self.pose(between(held_hand, cleared, max(0.0, u - OPEN_FIRST) / (1.0 - OPEN_FIRST),
                                         Vector()),
                                 self.turns_between(held_turns, open_turns, min(1.0, u / OPEN_FIRST)), held_pole, 0.0)
            elif f < at["catch"]:
                u = (f - clear_at) / (at["catch"] - clear_at)
                pole = self.pose(between(cleared, carried(at["catch"]), u, OUT),
                                 self.turns_between(open_turns, grip_turns, u), held_pole, u)
            elif f <= at["let_go"]:
                pole = carrying(f, grip_turns)
            elif f < ret_down:
                u = (f - at["let_go"]) / (ret_down - at["let_go"])
                pole = self.pose(between(carried(at["let_go"]), away_m, u, Vector()),
                                 self.turns_between(self.opened(grip_turns), open_turns, u))
            elif f <= ret_up:
                pole = self.pose(away_m, open_turns)
            elif f < back_at:
                u = (f - ret_up) / (back_at - ret_up)
                pole = self.pose(between(away_m, cleared, u, Vector()), open_turns, held_pole, 1.0 - u)
            else:
                u = (f - back_at) / (at["end"] - back_at)
                pole = self.pose(between(cleared, held_hand, min(1.0, u / (1.0 - OPEN_FIRST)), Vector()),
                                 self.turns_between(open_turns, held_turns, max(0.0, u - (1.0 - OPEN_FIRST))
                                                    / OPEN_FIRST), held_pole, 0.0)
            hits += self.key(f, pole, out)
        out.append((at["end"], held))
        return out, hits

    def key(self, f: int, pole: Vector, out: list) -> int:
        """The pose as it stands, eased out of the replica, appended to `out` as frame `f`'s key; 1 if it still
        passes in."""
        n, tally = self.ease(pole)
        if any(b.startswith("Thumb") and b.endswith("_" + SIDE) and k for b, k in tally.items()):
            # A thumb still in (laid round a grip's face as the hold has it, dragged as the hand comes off): the
            # clear turn of it nearest where its tip is.
            rig, tip = self.rig, "Thumb3_" + SIDE
            if self.frame_col is None:
                self.frame_col = Collider(self.frame)
            t3 = rig.pose[tip]
            cycle.clear_thumb(self.hand, self.frame_col, t3.translation + t3.to_3x3().col[1] * rig.length[tip])
            rig.write()
            n, tally = pose.clipping(self.moving, self.frame)
        out.append((f, cycle.snapshot(self.rig)))
        if n:
            print("   reload frame %d: %d face pairs pass into the replica %s" % (
                f, n, sorted(tally.items(), key=lambda x: -x[1])[:4]))
        return 1 if n else 0


def change_mag(rig: Rig, hand: pose.Hand, rid: str, hold_to_eye: Matrix, objects: list, solid: list, arms: list,
               holds: dict, both: str = None) -> tuple:
    """Keys `<rid>_Reload` and `<rid>_<grip>_Reload` from each of `holds` ("" or the grip -> the rig on that hold:
    its pose, turns, shifts, drops, across and plan, as arms.kept takes them); how many keys pass into the replica in
    all, and the clips keyed. Nothing for a replica without a GRASP or a Reload clip. With `both` (a pistol's hold in
    both hands, HA1), that hold's alone: `<rid>_<both>_Reload`, the left hand keeping clear of the right arm as posed
    as it does of the replica."""
    if rid not in GRASP:
        return 0, []
    change = MagChange(rig, hand, rid, hold_to_eye, objects, solid, arms)
    if change.action is None:
        return 0, []
    kept = (dict(hand.adduct), hand.normal, hand.tip_top)
    print("  reload: the magazine starts down at frame %(first)d, is out at %(out)d, the fresh one shows at %(back)d "
          "and is home at %(home)d of %(end)d; the hand takes it at %(catch)d" % change.at)
    hits, clips = 0, []
    still = None
    for name, kept_hold in holds.items():
        if both is not None and name != both:
            continue
        rig.pose, rig.local = dict(kept_hold[0]), dict(kept_hold[1])
        rig.shift, rig.drop, rig.across, rig.plan = (dict(d) for d in kept_hold[2:6])
        rig.write()
        if both is not None:
            still = pose.frozen(arms[1], "RightHeld")
            change.frame.append(still)
            change.moving = arms[:1]
            change.clear = CLEAR_BOTH
            change.avoid = [(rig.pose[a2 + "_R"].translation.copy(), rig.pose[b2 + "_R"].translation.copy())
                            for a2, b2 in (("UpperArm", "Forearm"), ("Forearm", "Hand"))]
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
    if still is not None:
        bpy.data.objects.remove(still, do_unlink=True)
    return hits, clips
