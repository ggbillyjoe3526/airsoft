"""The first-person arms (BL4): hard-knuckle tactical gloves and the sleeves of a combat shirt over a real human arm
and hand, posed holding each replica.

The mesh is built by `glove.py` (the MakeHuman base mesh's left arm, CC0, under a glove and sleeve), the rig and the
contact solver are `pose.py`'s. Both arms hang from one armature, `Arms`, whose bones are named as the figures'
skeleton names them (Shoulder_R, UpperArm_R, Forearm_R, Hand_R, Thumb1_R..Pinky3_R, Grip_R, and the same _L).

Each replica in HOLDS gets a clip `<id>_Hold` and an empty `Hold_<id>`, where the replica's origin sits in that pose
(the game's hip hold, ViewModelConfig.hip). The right hand closes round the pistol grip: the knuckle line laid along
the grip, the palm seated on it, each finger curled joint by joint until it meets the grip, the index finger's pad on
the trigger and the thumb round the back. The left hand holds a rifle's handguard from below, its fingers up the right
side, or wraps a pistol's grip over the right hand's fingers. The build checks every pose's arms against its replica
(and the left hand against the right) and stops without writing if any face passes into another.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3), after the replicas:

    python -I tools/blender/arms/arms.py <repo root>

It writes assets/models/arms/arms.glb.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "replicas"))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import fabric  # noqa: E402
import glove  # noqa: E402
import hardsurface as hs  # noqa: E402
import pose  # noqa: E402
from pose import Collider, Rig, basis  # noqa: E402

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
OUT = os.environ.get("BL_OUT") or os.path.join(ROOT, "assets/models/arms/arms.glb")
REPLICAS = os.path.join(ROOT, "assets/models/replicas")
FPS = 60

# Colours from the owner's glove photos (ref_images/hands/gloves: dark olive with black moulded knuckles), the same as
# the figures' gloves (BL10), so your arms match what other players wear.
MATERIALS = {
    "Glove": (0x4c4638, 0.85, 0.0), "GloveArmour": (0x242422, 0.68, 0.0), "Sleeve": (0x667052, 0.92, 0.0),
    "SleeveTrim": (0x515a41, 0.88, 0.0),
}
NAMES = list(MATERIALS)

# The shoulders, bladed as a right-handed shooter stands: the left one forward, the right one back (eye space: +X
# right, +Y forward, +Z up).
SHOULDER = {"L": Vector((-0.140, 0.100, -0.215)), "R": Vector((0.170, -0.120, -0.215))}
# How far below its shoulder each elbow hangs at least (m): tucked, not winged out.
ELBOW_DROP = {"R": 0.10, "L": 0.06}
# How far each elbow may come in across the body from its shoulder (m): the right not at all, the left a little
# (reaching across to a pistol).
ACROSS = {"R": 0.0, "L": 0.10}
# Per degree a forearm lies off its hold's `plan` angle (seen from above), as costly as this many degrees of wrist.
PLAN_COST = 1.0
# A pistol hand's palm faces the grip's right side at least this much (cosine), and each metre a placement passes into
# the grip, to be pushed back out of it, costs this many degrees of wrist bend while it is rolled into place.
PALM_FACING = 0.5
ROLL_STEP = 6
# The AEG's handguard: its centre line (x, z in the rifle's space) and radius (m), measured from the model; a support
# hand's finger knuckles want to sit between CUP_GAP of its surface (their joints' centres, a finger's half thickness
# out) to wrap it; the search's step (degrees), and what each degree off the forearm's rise and each metre of loose
# knuckle cost against a degree of wrist bend.
GUARD_AXIS = (0.0015, 0.047)
GUARD_RADIUS = 0.025
CUP_GAP = (0.010, 0.015)
CUP_STEP = 10
RISE_COST = 1.0
LOOSE_COST = 500.0
# The best CUP_TRIES turns try their fingers, which should come to rest round it curled WRAP degrees at their roots;
# each degree outside that costs WRAP_COST.
CUP_TRIES = 16
WRAP = (25.0, 80.0)
WRAP_COST = 0.5
OVER_COST = 4.0
# How far the support forearm's axis keeps from the replica (its sleeve's radius, m) and the cost per mm closer.
FOREARM_CLEAR = float(os.environ.get("BL_FOREARM_CLEAR", "0.045"))
CLEAR_COST = 20.0
# How far a resting finger's last joint bends for each degree of its middle one (relaxed fingers curl together).
TIP_COUPLE = 0.7
# Round a grip with a `thumb_at` mark (the pistols', and the rifle's: the owner, 2026-11-05, its thumb round the
# grip) the thumb turns further at its root (degrees): across the back strap to the grip's far side, twisted so its
# tip joint bends in toward it (the web's weights are smoothed for this, glove.smooth_web); that tip joint may bend up
# to THUMB_TIP (a support hand's thumb up to 45).
THUMB_WIDE = 60
THUMB_TWISTS = tuple(range(-135, 61, 15))
THUMB_TIP = 60
# The knuckle bends a grip's thumb tries with each turn at its root, so it can come round the back strap's corner and
# lie along the grip's side (degrees).
THUMB_BENDS = (0, 20, 40, 60)
MOVE_COST = 1000.0
# With a mark for the little finger's knuckle: its cost per metre off that mark (against degrees of bend), unless the
# hold gives its own (`pinky_cost`).
PINKY_COST = 600.0


def godot_to_eye(x: float, y: float, z: float) -> Vector:
    """A point in the camera's space as the game writes it (x right, y up, -z forward) in the eye space here."""
    return Vector((x, -z, y))


class Grip:
    """A pistol grip in its replica's space: the top of its back strap (where the hand's web sits), its rake back
    from upright (degrees), its depth back to front and its half width."""

    def __init__(self, top: tuple, rake: float, depth: float, half_width: float):
        self.top = Vector(top)
        r = math.radians(rake)
        self.down = Vector((0.0, -math.sin(r), -math.cos(r)))
        self.fwd = Vector((0.0, math.cos(r), -math.sin(r)))
        self.depth = depth
        self.hw = half_width

    def at(self, d: float, f: float, x: float) -> Vector:
        """The point `d` down the back strap from its top, `f` forward of it and `x` to the right."""
        return self.top + self.down * d + self.fwd * f + Vector((x, 0.0, 0.0))


class Hold:
    """How one replica is held: where it sits (its origin in eye space), its grip, the right hand's knuckles on it
    (down the grip, forward of the back strap) and the palm's roll, and the left hand's kind and place."""

    def __init__(self, file: str, at: Vector, grip: Grip, right: dict, left: dict):
        self.file, self.at, self.grip, self.right, self.left = file, at, grip, right, left


# The right hand on every grip (metres, degrees): its index finger's knuckle `d` down the back strap from its top,
# `f` forward of it and `x` out from the grip's side (the knuckle's joint, inside the hand); the knuckles' line slanted
# `slant` forward from the grip's line (the grip lies across the palm on a diagonal, which keeps the wrist straight);
# the palm facing the grip's side, turned `wrap` toward its front (negative: round its back).
RIGHT = {"d": 0.006, "f": 0.038, "x": 0.012, "slant": 30.0, "wrap": -30.0, "thumb_d": 0.030, "thumb_f": 0.030,
         "thumb_hug": 0.0, "thumb_pull": 3.0, "thumb_aim": 1.0, "swing": (0.0, 0.0, 0.0),
         "fingers": {"Middle": (60, 60, 45), "Ring": (60, 60, 45), "Pinky": (55, 55, 40)},
         "thumb": ((-45.0, 0.0, 30.0), (35.0, 25.0))}
# The left hand under a rifle's handguard (the owner's photos 123627, 123646, 123656): `y` along it (rifle +Y), its
# palm centre placed with the handguard's centre line `forward` toward the fingers (far enough that the fingers rest on
# its right side rather than reaching over its top: the owner, 2026-11-05; the hand a little further right, its
# wrist less turned in: 19:41) and `depth` out of the palm, seated
# on it and held `standoff` off; its turn found by `cup` over `search` ((yaw), (pitch), (roll) ranges, degrees: the
# fingers' line yawed from forward toward the right and pitched up, the palm rolled either way from facing up). The
# owner (2026-11-06): the hand holds under the rifle, the thumb slightly forward and almost relaxed, and the forearm
# meets the rifle at about 40 degrees seen from above (`plan`), not square across it. So the turn is fixed at 60, 40
# and -20 degrees: the fingers run a little diagonally forward up the right side, their tips below the rail (aimed at
# `tip_at`), the palm under the handguard, the wrist about 27 degrees off the 40-degree forearm; turned further
# forward the fingers stand over the rail, and the forearm, steeper, passes through the magazine (`cup` keeps it
# FOREARM_CLEAR off the replica). The forearm rises toward `rise` degrees from below. The arm comes
# from a bladed stance: its shoulder moved `shoulder` (eye space; left, a little forward and down), the elbow at
# least `drop` below it and at most `across` in toward the body. The thumb lies forward along the handguard's left
# side, low and loose, toward (thumb_x, y + thumb_f, thumb_z) (`thumb_pull`, held lightly: `thumb_hug`); the palm
# only 34 mm (`forward`) to the right of the handguard's centre line, so the thumb's base sits under its left side
# and the whole thumb rests on it (the owner, 2026-11-06), not just its tip. No
# finger's glove rises above `tips_below` (replica space; the rail's top is 0.0735): the fingers rest on the right side
# and none stands over the top from the left (the owner's 16:30 note, the critic).
GUARD = {"kind": "guard", "y": 0.190, "forward": 0.034, "depth": 0.034, "standoff": 0.0,
         "search": ((60, 60), (40, 40), (-20, -20)), "rise": 40.0, "shoulder": (-0.06, 0.04, -0.06), "drop": 0.06,
         "across": 0.25, "thumb_x": -0.030, "thumb_f": 0.065, "thumb_z": 0.038, "thumb_hug": 2.0,
         "thumb_pull": 30.0, "thumb_wide": 0.0, "tips_below": 0.068, "plan": 40.0,
         "tip_at": (0.0275, 0.005, 0.044), "tip_swing": 8.0,
         "fingers": {"Index": (35, 35, 20), "Middle": (40, 45, 30), "Ring": (40, 45, 30), "Pinky": (35, 40, 25)},
         "thumb": ((20.0, 0.0, 10.0), (10.0, 10.0))}
# A pistol is held in the right hand alone, as the game's look draws it: the left arm hangs at the side, out of view
# (the game doesn't draw it), its hand's knuckles this far from its shoulder (eye space) and loosely curled.
DOWN = {"kind": "down", "at": (0.0, 0.06, -0.40),
        "fingers": {"Index": (20, 25, 15), "Middle": (25, 30, 20), "Ring": (30, 35, 20), "Pinky": (35, 40, 25)},
        "thumb": ((0.0, 0.0, 10.0), (10.0, 10.0))}
# The right hand high on a pistol's grip (the owner's photos, one-handed: 123843, 123830, 123816), in the replica's own
# space (x right, y forward, z up): the thumb's root joint (deep in the heel of the thumb) behind the back strap's right
# corner, the index finger's knuckle on the grip's right side under the trigger guard and the little finger's knuckle
# near the front strap low down (`pinky`: the hand turned to lay all three nearest their marks, then rolled about the
# first two to keep the wrist straightest and the little finger's knuckle near its mark); so the web of the hand wraps
# the back strap under the beavertail, the fingers close up under the trigger guard (swung `swing` toward the index)
# with the little finger on the grip too, and the thumb comes round the back strap's corner and lies forward along
# the frame's left side just under the slide (its tip toward `thumb_at`, drawn there hard, `thumb_pull`: the owner,
# 2026-11-06, "the thumb is sitting too low"), held lightly to the frame (`thumb_hug`). The web sits high, 3 cm
# under the slide (the owner's Glock photos: the web up at the beavertail), and on the back strap's centre line (to
# its right, the thumb's base stood off the frame and the thumb ran across the back strap, seen from the eye), so
# the thumb lies high and forward along the frame, while the
# finger marks stay a little lower so the middle finger still wraps the front strap under the trigger guard (all
# three as high made it lie straight out under the guard); the thumb's knuckle and tip close onto the frame at most
# `thumb_curl` degrees. The arm reaches out to it, as a pistol is held, a little bent (the owner, 2026-11-06: not
# straight; the critic: 96 % of its reach, the elbow under 30 degrees): its shoulder raised and drawn back
# `shoulder` (eye space), its elbow free to come up to the shoulder's height (`drop`).
PISTOL_RIGHT = dict(RIGHT, web=(0.012, -0.095, -0.045), index=(0.018, -0.042, -0.040), pinky=(0.018, -0.058, -0.098),
                    thumb_at=(-0.020, -0.050, -0.040), thumb_hug=2.0, thumb_pull=30.0, thumb_curl=(40.0, 60.0),
                    shoulder=(0.0, -0.14, 0.105), drop=0.0, swing=(-15.0, -15.0, -15.0))
# The Cyber Pistol, resized to the GBB's proportions (CZ1): its own marks, 1 cm lower than the GBB's (its frame
# stands up beside the slide, so a thumb as high as the GBB's would pass into it): the web on its more upright back
# strap's centre line, the index knuckle 2 mm back for its trigger (5 mm further from the back strap than the GBB's)
# and the thumb aimed along the frame's side under that raised edge.
CYBER_RIGHT = dict(PISTOL_RIGHT, web=(0.012, -0.097, -0.047), index=(0.018, -0.044, -0.040),
                   thumb_at=(-0.020, -0.054, -0.040))
# The AEG Rifle's grip: the same three marks, the hand high on the short grip with the little finger wholly on it, its
# knuckle above the grip's flared foot (the owner, 2026-11-05; the critic: half of it hung below), the knuckles' line
# raked back with the grip, the web closer in over the back strap so the thumb reaches round onto the grip's left
# side, high at its top under the receiver (`thumb_at`, drawn there hard: the owner, 2026-11-06, the thumb too
# low); the shoulder drawn in, back and a
# little down to keep the wrist straighter (about 22 degrees).
AEG_RIGHT = dict(RIGHT, web=(0.042, -0.103, -0.056), index=(0.030, -0.031, -0.036), pinky=(0.024, -0.068, -0.078),
                 pinky_cost=2000.0, swing=(-10.0, -10.0, -10.0), shoulder=(-0.04, -0.08, -0.02),
                 thumb_at=(-0.022, -0.050, -0.026), thumb_hug=2.0, thumb_pull=30.0)
HOLDS = {
    "aeg": Hold("aeg.glb", godot_to_eye(0.12, -0.19, -0.26), Grip((0.0, -0.073, -0.026), 31.0, 0.046, 0.0155),
                AEG_RIGHT, GUARD),
    "pistol": Hold("pistol.glb", godot_to_eye(0.12, -0.15, -0.34), Grip((0.0, -0.070, -0.016), 27.0, 0.046, 0.0130),
                   PISTOL_RIGHT, DOWN),
    "cyber": Hold("cyber.glb", godot_to_eye(0.12, -0.15, -0.34), Grip((0.0, -0.074, -0.024), 17.0, 0.048, 0.0128),
                  CYBER_RIGHT, DOWN),
}


def aim(base: Vector, yaw: float, pitch: float) -> Vector:
    """`base` pitched up `pitch` degrees round X, then yawed `yaw` degrees toward -X round Z."""
    return Matrix.Rotation(math.radians(yaw), 3, "Z") @ Matrix.Rotation(math.radians(pitch), 3, "X") @ base


def roll_about(v: Vector, axis: Vector, deg: float) -> Vector:
    return Matrix.Rotation(math.radians(deg), 3, axis.normalized()) @ v


def tuned(spec: dict) -> dict:
    """`spec` with any value overridden from the environment (BL_<KEY>=value; BL_THUMB=across,twist,bend,tip1,tip2;
    BL_SEARCH=yaw0,yaw1,pitch0,pitch1,roll0,roll1; BL_G_<KEY> for the support hand's spec alone),
    for tuning a hold by eye."""
    out = dict(spec)
    for k, v in spec.items():
        env = os.environ.get("BL_" + k.upper())
        if spec.get("kind") == "guard":
            env = os.environ.get("BL_G_" + k.upper(), env)
        if env is not None and isinstance(v, float):
            out[k] = float(env)
        elif env is not None and isinstance(v, tuple) and all(isinstance(c, float) for c in v):
            out[k] = tuple(float(x) for x in env.split(","))
        elif env is not None and k == "search":
            f = [int(x) for x in env.split(",")]
            out[k] = ((f[0], f[1]), (f[2], f[3]), (f[4], f[5]))
        elif env is not None and k == "thumb":
            f = [float(x) for x in env.split(",")]
            out[k] = (tuple(f[:3]), tuple(f[3:5]))
    return out


# ------------------------------------------------------------------------------------------------------ placing

def replica_objects(hold: Hold) -> list:
    """The replica's meshes, its origin moved to the hold's place."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(REPLICAS, hold.file))
    new = [o for o in bpy.data.objects if o not in before]
    # The importer leaves the replica's first clip (Fire) playing, its slide part way back: the hold is fitted to
    # the replica at rest, so no clip may pose it.
    for o in new:
        if o.type == "ARMATURE":
            if o.animation_data:
                o.animation_data.action = None
                for track in o.animation_data.nla_tracks:
                    track.mute = True
            for pb in o.pose.bones:
                pb.matrix_basis = Matrix.Identity(4)
    for o in new:
        if o.parent is None:
            o.matrix_world = Matrix.Translation(hold.at) @ o.matrix_world
    bpy.context.view_layer.update()
    return new


def trigger_face(objects: list) -> Vector:
    """The middle of the trigger's front face, where the index finger's pad rests (eye space)."""
    trig = next(o for o in objects if o.name.startswith("Trigger"))
    pts = [trig.matrix_world @ v.co for v in trig.data.vertices]
    z0, z1 = min(p.z for p in pts), max(p.z for p in pts)
    zm = z1 - (z1 - z0) * 0.55
    band = [p for p in pts if abs(p.z - zm) < (z1 - z0) * 0.15]
    front = max(band, key=lambda p: p.y)
    return Vector((sum(p.x for p in pts) / len(pts), front.y + 0.0015, front.z))


def elbow_for(rig: Rig, side: str, hand_m: Matrix, quiet: bool = False) -> tuple:
    """The pole the elbow bends toward: round the circle the arm's two lengths allow, where the wrist is straightest
    with the elbow hanging below the shoulder (ELBOW_DROP) and never across the body."""
    up, fo, hn = "UpperArm_" + side, "Forearm_" + side, "Hand_" + side
    a = (rig.rest[fo].translation - rig.rest[up].translation).length
    b = (rig.rest[hn].translation - rig.rest[fo].translation).length
    rig.fk("Shoulder_" + side)
    rig.fk(up)
    s = rig.pose[up].translation
    w = hand_m.translation
    d = (w - s).normalized()
    u0 = (Vector((0.0, 0.0, -1.0)) + d * d.z).normalized()
    v0 = d.cross(u0)
    straight = (hand_m.to_3x3() @ rig.rest[hn].to_3x3().inverted() @ rig.rest[fo].to_3x3()).col[1]
    out = 1.0 if side == "R" else -1.0
    best = None
    for k in range(0, 360, 2):
        t = math.radians(k)
        e = pose.two_bone(s, w, a, b, u0 * math.cos(t) + v0 * math.sin(t))
        if e.z > s.z - rig.drop.get(side, ELBOW_DROP[side]) or (s.x - e.x) * out > rig.across.get(side, ACROSS[side]):
            continue
        bend = math.degrees(straight.angle(w - e))
        # Seen from above, the forearm's angle off the bore (0: along it, 90: square across it), near `plan` when
        # the hold asks for one (the support arm: the owner, 2026-11-06, about 40 degrees, not square across).
        cost = bend
        if rig.plan.get(side, 0.0) > 0.0:
            f = w - e
            cost += abs(math.degrees(math.atan2(abs(f.x), f.y)) - rig.plan[side]) * PLAN_COST
        if best is None or cost < best[2]:
            best = (bend, e, cost)
    if best is None:
        if quiet:
            return None, 180.0
        raise SystemExit("no elbow for the %s arm below its shoulder" % side)
    if quiet:
        return best[1] - s, best[0]
    fore = w - best[1]
    if os.environ.get("BL_DEBUG"):
        ideal = w - straight * b
        print("   %s straight-wrist elbow %s, %.3f from the shoulder %s (upper arm %.3f)" % (
            side, tuple(round(c, 3) for c in ideal), (ideal - s).length, tuple(round(c, 3) for c in s), a))
    print("  %s: reach %.3f of %.3f, elbow %s, wrist %.1f deg off the forearm, forearm rising %.0f deg, %.0f deg off "
          "the bore from above" % (side, (w - s).length, a + b, tuple(round(c, 3) for c in best[1]), best[0],
                                   math.degrees(math.atan2(fore.z, fore.xy.length)),
                                   math.degrees(math.atan2(abs(fore.x), fore.y))))
    return best[1] - s, best[0]


def knuckle_pose(rig: Rig, hand: pose.Hand, j: dict, index_at: Vector, line: Vector, palm: Vector) -> Matrix:
    """The hand bone's pose with its index finger's knuckle at `index_at`, its knuckles' line (index to little
    finger) along `line` and its palm facing `palm` as near as that line allows."""
    sx = pose.to_side(hand.side)
    i0, p0 = sx(j["finger-2-1"]), sx(j["finger-5-1"])
    r = basis(line, palm) @ basis(p0 - i0, hand.palmar).transposed()
    return Matrix.Translation(index_at) @ r.to_4x4() @ Matrix.Translation(-i0) @ rig.rest["Hand_" + hand.side]


def pose_fingers(hand: pose.Hand, spec: dict, col: Collider, thumb_to: Vector = None, hug: float = 0.0,
                 wide: bool = False, root: bool = False) -> dict:
    """Each finger of `spec` at its authored bends, settled onto the replica, and the thumb: swung so its tip comes
    nearest `thumb_to`, or at its authored turn; their bends, for the log."""
    curls = {}
    swing = dict(zip(("Middle", "Ring", "Pinky"), spec.get("swing", (0.0, 0.0, 0.0))))
    for name, start in spec["fingers"].items():
        curls[name] = hand.settle(name, start, col, swing=swing.get(name, 0.0), root=root)
    if thumb_to is not None:
        turns = (THUMB_WIDE, THUMB_TWISTS) if wide else (pose.THUMB_SWING, (-30, 0, 30))
        # How far its knuckle and tip joints may then close onto the replica (`thumb_curl`, degrees: a pistol's
        # thumb lies nearly straight forward along the frame, as in the owner's photos).
        knuckle, tip = spec.get("thumb_curl", (40.0, THUMB_TIP if wide else 45.0))
        curls["Thumb"] = hand.thumb(col, (0.5, 1.0, 0.8), (0.0, math.radians(knuckle), math.radians(tip)), thumb_to,
                                    hug, *turns,
                                    THUMB_BENDS if wide else (0,), spec.get("thumb_pull", 3.0))
    else:
        base, bends = spec["thumb"]
        curls["Thumb"] = hand.thumb_at(base, bends, col)
    return curls


def web_pose(rig: Rig, hand: pose.Hand, j: dict, hold: Hold, r: dict, col: Collider) -> Matrix:
    """The right hand bone's pose on a pistol: its index finger's knuckle at r["index"] and its thumb's root at
    r["web"] (replica space), rolled about the line between them to where the wrist is straightest and the hand clear
    of the grip, its palm toward the grip's right side."""
    to_eye = Matrix.Translation(hold.at)
    sx = pose.to_side("R")
    i_rest, w_rest, t_rest = sx(j["finger-2-1"]), sx(j["finger-1-1"]), sx(j["finger-1-2"])
    i_at, w_at = to_eye @ Vector(r["index"]), to_eye @ Vector(r["web"])
    p_rest = sx(j["finger-5-1"])
    p_at = to_eye @ Vector(r["pinky"]) if "pinky" in r else None
    if p_at is None:
        base = pose.rot_between(w_rest - i_rest, w_at - i_at)
    else:
        # The turn that best lays the thumb's root, the index knuckle and the little finger's knuckle on their marks.
        base = pose.fit_turn([w_rest, i_rest, p_rest], [w_at, i_at, p_at])
    axis = (base @ (w_rest - i_rest)).normalized()
    best = None
    lo, hi = r.get("rolls", (-180, 174))
    for k in range(int(lo), int(hi) + 1, ROLL_STEP):
        rot = Matrix.Rotation(math.radians(k), 3, axis) @ base
        palm = rot @ hand.palmar
        if palm.x > -PALM_FACING:
            continue
        m0 = Matrix.Translation(i_at) @ rot.to_4x4() @ Matrix.Translation(-i_rest) @ rig.rest["Hand_R"]
        m = hand.seat(m0, palm, col, whole=True)
        moved = (m.translation - m0.translation).length
        _, bend = elbow_for(rig, "R", m, quiet=True)
        score = bend + moved * MOVE_COST
        p5 = m @ (rig.rest["Hand_R"].inverted() @ p_rest)
        if p_at is not None:
            score += (p5 - p_at).length * r.get("pinky_cost", PINKY_COST)
        mcp = to_eye.inverted() @ (m @ (rig.rest["Hand_R"].inverted() @ t_rest))
        if os.environ.get("BL_DEBUG"):
            print("    roll %4d: bend %5.1f moved %5.1f mm palm %s thumb knuckle %s pinky knuckle %s" % (
                k, bend, moved * 1000, tuple(round(c, 2) for c in palm), tuple(round(c, 3) for c in mcp),
                tuple(round(c, 3) for c in to_eye.inverted() @ p5)))
        if best is None or score < best[0]:
            best = (score, k, m, palm)
    print("  R: web roll %d deg" % best[1])
    return best[2], best[3]


def right_hand(rig: Rig, hand: pose.Hand, j: dict, hold: Hold, col: Collider, objects: list) -> tuple:
    """The right hand round the pistol grip; its curls, for the log."""
    g, r = hold.grip, tuned(hold.right)
    to_eye = Matrix.Translation(hold.at)
    if "web" in r:
        hand_m, palm = web_pose(rig, hand, j, hold, r, col)
    else:
        index_at = to_eye @ g.at(r["d"], r["f"], g.hw + r["x"])
        line = g.down * math.cos(math.radians(r["slant"])) + g.fwd * math.sin(math.radians(r["slant"]))
        palm = Vector((-1.0, 0.0, 0.0)) * math.cos(math.radians(r["wrap"])) + \
            g.fwd * math.sin(math.radians(r["wrap"]))
        hand_m = hand.seat(knuckle_pose(rig, hand, j, index_at, line, palm), palm, col)
    hand.normal = palm
    if os.environ.get("BL_DEBUG"):
        sx = pose.to_side("R")
        rest_inv = rig.rest["Hand_R"].inverted()
        for name in ("hand", "finger-1-1", "finger-2-1", "finger-5-1", "finger-1-2"):
            p = to_eye.inverted() @ (hand_m @ (rest_inv @ sx(j[name])))
            print("   %s: %s" % (name, tuple(round(c, 3) for c in p)))
    pole_r, _ = elbow_for(rig, "R", hand_m)
    pose.place_arm(rig, "R", hand_m, pole_r, quiet=True)
    # The thumb round the back strap's top and forward along the frame's left side.
    if "thumb_at" in r:
        thumb_to = to_eye @ Vector(r["thumb_at"])
    elif r["thumb_aim"]:
        thumb_to = to_eye @ g.at(r["thumb_d"], r["thumb_f"], -g.hw - 0.008)
    else:
        thumb_to = None
    curls = pose_fingers(hand, r, col, thumb_to, r["thumb_hug"], "thumb_at" in r)
    if os.environ.get("BL_DEBUG") and thumb_to is not None:
        m = rig.pose["Thumb3_R"]
        tip = m.translation + m.to_3x3().col[1] * rig.length["Thumb3_R"]
        print("   thumb tip", tuple(round(v, 3) for v in to_eye.inverted() @ tip))
    # The index finger's pad rests on the trigger: the trigger itself is left out of what it must clear.
    frame = Collider([o for o in objects if o.type == "MESH" and not o.name.startswith(("Figure", "Icosphere",
                                                                                          "Trigger"))])
    curls["Index"] = hand.onto("Index", trigger_face(objects), frame, (70, 90, 70), 40)
    return pole_r, curls


def trigger_again(rig: Rig, hand: pose.Hand, objects: list, arms: list, frame: list) -> None:
    """After the palm has pressed in, the trigger finger finds the trigger again from where the hand now is; kept only
    if its glove stays clear of the frame."""
    bones = ["Index%d_R" % k for k in (1, 2, 3)]
    before = {b: rig.local[b].copy() for b in bones}
    col = Collider([o for o in objects if o.type == "MESH" and not o.name.startswith(("Figure", "Icosphere",
                                                                                        "Trigger"))])
    hand.onto("Index", trigger_face(objects), col, (70, 90, 70), 40)
    rig.write()
    if pose.clipping(arms, frame)[0]:
        for b in bones:
            rig.fk(b, before[b])
        rig.refresh("Index1_R")
        rig.write()
        print("  trigger finger kept where it was (clipping)")


def left_on_guard(rig: Rig, hand: pose.Hand, j: dict, hold: Hold, col: Collider) -> tuple:
    """The left hand under a rifle's handguard, its fingers up the right side and the index finger along the side
    rail, the thumb along the left side."""
    spec = tuned(hold.left)
    to_eye = Matrix.Translation(hold.at)
    y = spec["y"]
    at = to_eye @ Vector((0.0, y, GUARD_AXIS[1]))

    def placed(yaw: float, pitch: float, roll: float) -> tuple:
        fingers = aim(Vector((0.0, 1.0, 0.0)), -yaw, pitch)
        palm = roll_about(Vector((0.0, 0.0, 1.0)), fingers, roll)
        m = hand.seat(hand.place(at, fingers, palm, spec["forward"], spec["depth"]), palm, col, whole=True)
        # Held off the handguard a little where the fingers' roots would press into it.
        return Matrix.Translation(-palm.normalized() * spec["standoff"]) @ m, palm

    hand.tip_top = None
    hand_m, palm = cup(rig, hand, j, to_eye, spec, col, placed)
    hand.normal = palm
    # The fingers' highest (eye space) where they rest, level with the hand on the handguard.
    hand.tip_top = (to_eye @ Vector((0.0, y, spec["tips_below"]))).z
    pole_l, _ = elbow_for(rig, "L", hand_m)
    pose.place_arm(rig, "L", hand_m, pole_l, quiet=True)
    # The thumb forward along the handguard's left side.
    thumb_to = to_eye @ Vector((spec["thumb_x"], spec["y"] + spec["thumb_f"], spec["thumb_z"]))
    curls = pose_fingers(hand, spec, col, thumb_to, spec["thumb_hug"], spec.get("thumb_wide", 0.0) > 0.0, root=True)
    # Each fingertip then reaches for its own point on the handguard's right side, level with its knuckle and below
    # the top (`tip_at`, replica space: x, y from the knuckle, z), so the fingers rest on the side (the owner, 16:30)
    # rather than over the rail (the critic); each curls as a relaxed finger does (TIP_COUPLE), never a claw.
    # tip_at x 0 turns this off.
    inv = to_eye.inverted()
    for name in spec["fingers"] if spec["tip_at"][0] > 0.0 else ():
        k = inv @ rig.pose["%s1_L" % name].translation
        target = to_eye @ Vector((spec["tip_at"][0], k.y + spec["tip_at"][1], spec["tip_at"][2]))
        curls[name] = hand.onto(name, target, col, (90, 100, 0), spec["tip_swing"], TIP_COUPLE)
    if os.environ.get("BL_DEBUG"):
        m = rig.pose["Thumb3_L"]
        tip = m.translation + m.to_3x3().col[1] * rig.length["Thumb3_L"]
        print("   thumb tip", tuple(round(v, 3) for v in to_eye.inverted() @ tip), "target",
              tuple(round(v, 3) for v in to_eye.inverted() @ thumb_to))
    return pole_l, curls


def cup(rig: Rig, hand: pose.Hand, j: dict, to_eye: Matrix, spec: dict, col: Collider, placed) -> tuple:
    """The support hand's turn under the handguard (yaw, pitch, roll from spec["search"]'s ranges) that cups it: every
    finger's knuckle close round it, so all four can wrap its far side; the wrist straight; the forearm rising toward
    spec["rise"] degrees, up from below as the owner's photos hold it (123627, 123646)."""
    sx = pose.to_side("L")
    rest_inv = rig.rest["Hand_L"].inverted()
    mcps = [sx(j["finger-%d-1" % f]) for f in (2, 3, 4, 5)]
    axis = Vector(GUARD_AXIS)
    found = []
    (y0, y1), (p0, p1), (r0, r1) = spec["search"]
    for yaw in range(y0, y1 + 1, CUP_STEP):
        for pitch in range(p0, p1 + 1, CUP_STEP):
            for roll in range(r0, r1 + 1, CUP_STEP):
                m, palm = placed(float(yaw), float(pitch), float(roll))
                pole, bend = elbow_for(rig, "L", m, quiet=True)
                if pole is None:
                    continue
                rig.fk("Shoulder_L")
                rig.fk("UpperArm_L")
                fore = m.translation - (rig.pose["UpperArm_L"].translation + pole)
                rise = math.degrees(math.atan2(fore.z, fore.xy.length))
                plan = math.degrees(math.atan2(abs(fore.x), fore.y))
                # The forearm (its sleeve) clears the replica: the magazine hangs just behind the support hand.
                elbow = rig.pose["UpperArm_L"].translation + pole
                clear = sum(max(0.0, FOREARM_CLEAR - col.dist(elbow.lerp(m.translation, t / 8.0)))
                            for t in range(1, 8))
                gaps = []
                for q in mcps:
                    p = to_eye.inverted() @ (m @ (rest_inv @ q))
                    gaps.append(math.hypot(p.x - axis[0], p.z - axis[1]) - GUARD_RADIUS)
                loose = sum(max(0.0, g - CUP_GAP[1], CUP_GAP[0] - g) for g in gaps)
                score = bend + abs(rise - spec["rise"]) * RISE_COST + loose * LOOSE_COST + \
                    clear * 1000.0 * CLEAR_COST + \
                    (abs(plan - spec["plan"]) * PLAN_COST if spec.get("plan", 0.0) > 0.0 else 0.0)
                found.append((score, yaw, pitch, roll, m, palm, bend, rise, gaps))
    # The few best then try their fingers: each should curl round the handguard and come to rest on it, neither
    # flattened along it nor closed in a fist short of it.
    found.sort(key=lambda c: c[0])
    best = None
    for c in found[:CUP_TRIES]:
        rig.pose["Hand_L"] = c[4]
        curls = [hand.settle(name, start, col, root=True)[0] for name, start in spec["fingers"].items()]
        off = sum(max(0.0, WRAP[0] - a, a - WRAP[1]) for a in curls)
        # Fingertips standing over the handguard's top cost as much as fingers left open (mm over).
        over = sum(hand.over(name) for name in spec["fingers"]) * 1000.0
        score = c[0] + (off + over * OVER_COST) * WRAP_COST
        if os.environ.get("BL_DEBUG"):
            print("    cup yaw %d pitch %d roll %d: %.1f + fingers %s" % (c[1], c[2], c[3], c[0], curls))
        if best is None or score < best[0]:
            best = (score,) + c[1:]
    print("  L: cupped at yaw %d pitch %d roll %d: wrist %.0f deg, forearm rising %.0f deg, knuckles %s mm out" % (
        best[1], best[2], best[3], best[6], best[7], [round(g * 1000) for g in best[8]]))
    return best[4], best[5]


def left_down(rig: Rig, hand: pose.Hand, j: dict, hold: Hold, col: Collider) -> tuple:
    """The left arm hanging at the side, its hand loosely curled (a pistol held in the right hand alone)."""
    spec = hold.left
    index_at = SHOULDER["L"] + Vector(spec["at"])
    hand_m = knuckle_pose(rig, hand, j, index_at, Vector((0.0, -1.0, 0.0)), Vector((1.0, 0.0, 0.0)))
    hand.normal = Vector((1.0, 0.0, 0.0))
    hand.tip_top = None
    pole_l, _ = elbow_for(rig, "L", hand_m)
    pose.place_arm(rig, "L", hand_m, pole_l, quiet=True)
    curls = pose_fingers(hand, spec, col)
    return pole_l, curls


def solve(rig: Rig, hands: dict, j: dict, hold: Hold, arms: list) -> tuple:
    """Poses both arms holding `hold`'s replica; the replica's objects and the clipping left (face pairs)."""
    rig.pose = dict(rig.rest)
    rig.local = {}
    rig.shift, rig.drop, rig.across, rig.plan = {}, {}, {}, {}
    for side, spec in (("R", tuned(hold.right)), ("L", tuned(hold.left))):
        if "shoulder" in spec:
            rig.shift["Shoulder_" + side] = Vector(spec["shoulder"])
        if "drop" in spec:
            rig.drop[side] = spec["drop"]
        if "across" in spec:
            rig.across[side] = spec["across"]
        if "plan" in spec:
            rig.plan[side] = spec["plan"]
    objects = replica_objects(hold)
    solid = [o for o in objects if o.type == "MESH" and not o.name.startswith(("Figure", "Icosphere"))]
    col = Collider(solid)
    rig.fk("Shoulder_L")
    rig.fk("Shoulder_R")
    pole_r, curls_r = right_hand(rig, hands["R"], j, hold, col, objects)
    for b in ("Grip_R",):
        rig.fk(b)
    rig.write()
    if hold.left["kind"] == "guard":
        pole_l, curls_l = left_on_guard(rig, hands["L"], j, hold, col)
    else:
        pole_l, curls_l = left_down(rig, hands["L"], j, hold, col)
    rig.fk("Grip_L")
    print("  right curls", curls_r)
    print("  left curls", curls_l)
    poles = {"R": pole_r, "L": pole_l}
    # The trigger finger's pad rests on the trigger (`onto` keeps it there), so the check leaves the trigger out.
    frame = [o for o in solid if not o.name.startswith("Trigger")]
    hits = 0 if os.environ.get("BL_NORELAX") else pose.relax(rig, hands, arms, frame, poles)
    if not hits and not os.environ.get("BL_NORELAX"):
        # Then each holding palm seats on the replica and every holding finger closes until its glove all but
        # touches it (the trigger finger stays on its mark).
        for side in ("R", "L") if hold.left["kind"] == "guard" else ("R",):
            print("  %s palm pressed in %.1f mm" % (side, pose.press(rig, hands, arms, frame, poles, side) * 1000))
        trigger_again(rig, hands["R"], objects, arms, frame)
        fingers = [("R", n) for n in ("Middle", "Ring", "Pinky", "Thumb")]
        if hold.left["kind"] == "guard":
            fingers += [("L", n) for n in ("Index", "Middle", "Ring", "Pinky", "Thumb")]
        print("  tightened", pose.tighten(rig, hands, arms, frame, fingers))
        print("  wrapped", pose.wrap(rig, hands, arms, frame, [f for f in fingers if f[1] != "Thumb"]))
        # Whatever the last passes did, the arms are checked once more before anything is written.
        hits, tally = pose.clipping(arms, frame)
        if hits:
            print("  still passing into the replica:", sorted(tally.items(), key=lambda x: -x[1]))
        if os.environ.get("BL_DEBUG"):
            for side in ("R", "L") if hold.left["kind"] == "guard" else ("R",):
                print("   %s skin gaps (mm)" % side, pose.skin_gaps(arms, frame, side))
    return objects, solid, hits


def build() -> None:
    hs.reset(FPS)
    for name, (colour, rough, metal) in MATERIALS.items():
        hs.material(name, colour, rough, metal)
    pose.SHOULDER.update(SHOULDER)
    mesh, j, fr, pts = glove.build_left(SHOULDER["L"])
    arm = pose.armature(pts, fr)
    left = pose.skin_object("Arm_L", mesh, arm, "L", NAMES)
    right = pose.skin_object("Arm_R", mesh, arm, "R", NAMES)
    # The cloth's weave over the glove, its moulded parts and the sleeve.
    fabric.wear(fabric.weave_image())
    for ob in (left, right):
        fabric.unwrap(ob)
    rig = Rig(arm)
    rig.fk("Shoulder_L")
    rig.fk("Shoulder_R")
    hands = {s: pose.Hand(s, rig, mesh, fr, j) for s in ("L", "R")}
    only = os.environ.get("BL_ONLY")
    failed = []
    for rid, hold in HOLDS.items():
        if only and rid not in only.split(","):
            continue
        print("%s:" % rid)
        objects, solid, hits = solve(rig, hands, j, hold, [left, right])
        for side in ("R", "L"):
            print("  %s wrist bend %.1f deg" % (side, pose.wrist_bend(rig, side)))
        pose.key_pose(rig, "%s_Hold" % rid)
        hs.empty("Hold_%s" % rid, tuple(hold.at), arm)
        if hits:
            failed.append("%s (%d face pairs)" % (rid, hits))
        if os.environ.get("BL_KEEP") == rid:
            return
        for o in objects:
            if o.type == "ARMATURE" or o.type == "MESH" or o.type == "EMPTY":
                bpy.data.objects.remove(o, do_unlink=True)
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    print("  arms: %d triangles" % (hs.tris(left) + hs.tris(right)))
    clips = {"%s_Hold" % r for r in HOLDS}
    for a in list(bpy.data.actions):
        if a.name not in clips:
            bpy.data.actions.remove(a)
    if failed and not os.environ.get("BL_FORCE"):
        raise SystemExit("the posed arms pass into a replica: " + ", ".join(failed))
    hs.export(OUT, True)
    print("wrote", OUT)


if __name__ == "__main__":
    build()
