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
    "Glove": (0x4c4638, 0.85, 0.0), "GloveArmour": (0x242422, 0.55, 0.0), "Sleeve": (0x667052, 0.92, 0.0),
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
RIGHT = {"d": 0.006, "f": 0.038, "x": 0.012, "slant": 25.0, "wrap": -30.0, "thumb_d": 0.030, "thumb_f": 0.030,
         "thumb_hug": 0.0, "thumb_aim": 1.0,
         "fingers": {"Middle": (60, 60, 45), "Ring": (65, 65, 45), "Pinky": (70, 70, 45)},
         "thumb": ((-45.0, 0.0, 30.0), (35.0, 25.0))}
# The left hand under a rifle's handguard: where along it (rifle +Y), its fingers' line yawed from forward toward the
# right and pitched, its palm rolled from facing up toward the left; the handguard's centre line from the palm's
# centre as RIGHT's. The thumb reaches along the handguard's left side for (thumb_x, y + thumb_f, thumb_z), its length
# kept close to it (thumb_hug: Hand.thumb).
GUARD = {"kind": "guard", "y": 0.190, "yaw": 75.0, "pitch": 30.0, "roll": 35.0, "forward": 0.014, "depth": 0.034,
         "thumb_x": -0.023, "thumb_f": 0.05, "thumb_z": 0.055, "thumb_hug": 3.0,
         "fingers": {"Index": (35, 35, 20), "Middle": (50, 55, 35), "Ring": (55, 60, 40), "Pinky": (60, 60, 40)},
         "thumb": ((20.0, 0.0, 10.0), (10.0, 10.0))}
# A pistol is held in the right hand alone, as the game's look draws it: the left arm hangs at the side, out of view
# (the game doesn't draw it), its hand's knuckles this far from its shoulder (eye space) and loosely curled.
DOWN = {"kind": "down", "at": (0.0, 0.06, -0.40),
        "fingers": {"Index": (20, 25, 15), "Middle": (25, 30, 20), "Ring": (30, 35, 20), "Pinky": (35, 40, 25)},
        "thumb": ((0.0, 0.0, 10.0), (10.0, 10.0))}
# The right hand on a pistol's grip: as RIGHT, its knuckles a little higher under the trigger guard and further
# forward, the palm turned less round the front strap (a pistol's grip is short and narrow).
PISTOL_RIGHT = dict(RIGHT, d=0.004, f=0.044, wrap=-15.0, slant=25.0, thumb_d=0.0, thumb_f=0.035)
# The Cyber Pistol's grip is deep and its trigger about 3 cm ahead of it: the knuckles higher and further forward, the
# knuckles' line more upright.
CYBER_RIGHT = dict(PISTOL_RIGHT, d=-0.008, f=0.058, slant=15.0)
HOLDS = {
    "aeg": Hold("aeg.glb", godot_to_eye(0.12, -0.19, -0.26), Grip((0.0, -0.073, -0.026), 31.0, 0.046, 0.0155),
                RIGHT, GUARD),
    "pistol": Hold("pistol.glb", godot_to_eye(0.12, -0.15, -0.34), Grip((0.0, -0.070, -0.016), 27.0, 0.046, 0.0130),
                   PISTOL_RIGHT, DOWN),
    "cyber": Hold("cyber.glb", godot_to_eye(0.12, -0.15, -0.34), Grip((0.0, -0.0905, -0.036), 17.0, 0.060, 0.0158),
                  CYBER_RIGHT, DOWN),
}


def aim(base: Vector, yaw: float, pitch: float) -> Vector:
    """`base` pitched up `pitch` degrees round X, then yawed `yaw` degrees toward -X round Z."""
    return Matrix.Rotation(math.radians(yaw), 3, "Z") @ Matrix.Rotation(math.radians(pitch), 3, "X") @ base


def roll_about(v: Vector, axis: Vector, deg: float) -> Vector:
    return Matrix.Rotation(math.radians(deg), 3, axis.normalized()) @ v


def tuned(spec: dict) -> dict:
    """`spec` with any value overridden from the environment (BL_<KEY>=value; BL_THUMB=across,twist,bend,tip1,tip2),
    for tuning a hold by eye."""
    out = dict(spec)
    for k, v in spec.items():
        env = os.environ.get("BL_" + k.upper())
        if env is not None and isinstance(v, float):
            out[k] = float(env)
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
        if e.z > s.z - ELBOW_DROP[side] or (s.x - e.x) * out > ACROSS[side]:
            continue
        bend = math.degrees(straight.angle(w - e))
        if best is None or bend < best[0]:
            best = (bend, e)
    if best is None:
        if quiet:
            return None, 180.0
        raise SystemExit("no elbow for the %s arm below its shoulder" % side)
    if quiet:
        return best[1] - s, best[0]
    print("  %s: reach %.3f of %.3f, elbow %s, wrist %.1f deg off the forearm" % (
        side, (w - s).length, a + b, tuple(round(c, 3) for c in best[1]), best[0]))
    return best[1] - s, best[0]


def knuckle_pose(rig: Rig, hand: pose.Hand, j: dict, index_at: Vector, line: Vector, palm: Vector) -> Matrix:
    """The hand bone's pose with its index finger's knuckle at `index_at`, its knuckles' line (index to little
    finger) along `line` and its palm facing `palm` as near as that line allows."""
    sx = pose.to_side(hand.side)
    i0, p0 = sx(j["finger-2-1"]), sx(j["finger-5-1"])
    r = basis(line, palm) @ basis(p0 - i0, hand.palmar).transposed()
    return Matrix.Translation(index_at) @ r.to_4x4() @ Matrix.Translation(-i0) @ rig.rest["Hand_" + hand.side]


def pose_fingers(hand: pose.Hand, spec: dict, col: Collider, thumb_to: Vector = None, hug: float = 0.0) -> dict:
    """Each finger of `spec` at its authored bends, settled onto the replica, and the thumb: swung so its tip comes
    nearest `thumb_to`, or at its authored turn; their bends, for the log."""
    curls = {}
    for name, start in spec["fingers"].items():
        curls[name] = hand.settle(name, start, col)
    if thumb_to is not None:
        curls["Thumb"] = hand.thumb(col, (0.5, 1.0, 0.8), (0.0, math.radians(40), math.radians(45)), thumb_to, hug)
    else:
        base, bends = spec["thumb"]
        curls["Thumb"] = hand.thumb_at(base, bends, col)
    return curls


def right_hand(rig: Rig, hand: pose.Hand, j: dict, hold: Hold, col: Collider, objects: list) -> tuple:
    """The right hand round the pistol grip; its curls, for the log."""
    g, r = hold.grip, tuned(hold.right)
    to_eye = Matrix.Translation(hold.at)
    index_at = to_eye @ g.at(r["d"], r["f"], g.hw + r["x"])
    line = g.down * math.cos(math.radians(r["slant"])) + g.fwd * math.sin(math.radians(r["slant"]))
    palm = Vector((-1.0, 0.0, 0.0)) * math.cos(math.radians(r["wrap"])) + g.fwd * math.sin(math.radians(r["wrap"]))
    hand_m = hand.seat(knuckle_pose(rig, hand, j, index_at, line, palm), palm, col)
    hand.normal = palm
    if os.environ.get("BL_DEBUG"):
        sx = pose.to_side("R")
        rest_inv = rig.rest["Hand_R"].inverted()
        for name in ("hand", "finger-2-1", "finger-5-1", "finger-1-2"):
            p = to_eye.inverted() @ (hand_m @ (rest_inv @ sx(j[name])))
            q = p - g.top
            print("   %s: d %.3f f %.3f x %.3f" % (name, q.dot(g.down), q.dot(g.fwd), q.x))
    pole_r, _ = elbow_for(rig, "R", hand_m)
    pose.place_arm(rig, "R", hand_m, pole_r, quiet=True)
    # The thumb round the back strap's top and forward along the lower receiver's left side.
    thumb_to = to_eye @ g.at(r["thumb_d"], r["thumb_f"], -g.hw - 0.008) if r["thumb_aim"] else None
    curls = pose_fingers(hand, r, col, thumb_to, r["thumb_hug"])
    # The index finger's pad rests on the trigger: the trigger itself is left out of what it must clear.
    frame = Collider([o for o in objects if o.type == "MESH" and not o.name.startswith(("Figure", "Icosphere",
                                                                                          "Trigger"))])
    curls["Index"] = hand.onto("Index", trigger_face(objects), frame, (70, 90, 70), 40)
    return pole_r, curls


def left_on_guard(rig: Rig, hand: pose.Hand, j: dict, hold: Hold, col: Collider) -> tuple:
    """The left hand under a rifle's handguard, its fingers up the right side and the index finger along the side
    rail, the thumb along the left side."""
    spec = tuned(hold.left)
    to_eye = Matrix.Translation(hold.at)
    y = spec["y"]
    fingers = aim(Vector((0.0, 1.0, 0.0)), -spec["yaw"], spec["pitch"])
    palm = roll_about(Vector((0.0, 0.0, 1.0)), fingers, spec["roll"])
    at = to_eye @ Vector((0.0, y, 0.049))
    hand_m = hand.seat(hand.place(at, fingers, palm, spec["forward"], spec["depth"]), palm, col, whole=True)
    hand.normal = palm
    pole_l, _ = elbow_for(rig, "L", hand_m)
    pose.place_arm(rig, "L", hand_m, pole_l, quiet=True)
    # The thumb forward along the handguard's left side.
    thumb_to = to_eye @ Vector((spec["thumb_x"], spec["y"] + spec["thumb_f"], spec["thumb_z"]))
    curls = pose_fingers(hand, spec, col, thumb_to, spec["thumb_hug"])
    if os.environ.get("BL_DEBUG"):
        m = rig.pose["Thumb3_L"]
        tip = m.translation + m.to_3x3().col[1] * rig.length["Thumb3_L"]
        print("   thumb tip", tuple(round(v, 3) for v in to_eye.inverted() @ tip), "target",
              tuple(round(v, 3) for v in to_eye.inverted() @ thumb_to))
    return pole_l, curls


def left_down(rig: Rig, hand: pose.Hand, j: dict, hold: Hold, col: Collider) -> tuple:
    """The left arm hanging at the side, its hand loosely curled (a pistol held in the right hand alone)."""
    spec = hold.left
    index_at = SHOULDER["L"] + Vector(spec["at"])
    hand_m = knuckle_pose(rig, hand, j, index_at, Vector((0.0, -1.0, 0.0)), Vector((1.0, 0.0, 0.0)))
    hand.normal = Vector((1.0, 0.0, 0.0))
    pole_l, _ = elbow_for(rig, "L", hand_m)
    pose.place_arm(rig, "L", hand_m, pole_l, quiet=True)
    curls = pose_fingers(hand, spec, col)
    return pole_l, curls


def solve(rig: Rig, hands: dict, j: dict, hold: Hold, arms: list) -> tuple:
    """Poses both arms holding `hold`'s replica; the replica's objects and the clipping left (face pairs)."""
    rig.pose = dict(rig.rest)
    rig.local = {}
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
