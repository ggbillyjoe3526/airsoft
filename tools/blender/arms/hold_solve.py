"""The first-person arms' holds solved (HA1): each hand placed and closed on its replica from the marks and costs in
`hold_tables.py`, with `pose.py`'s rig and contact solver. `solve` poses one hold and reports what still passes into
the replica; `solve_grip` and `solve_support` pose the left hand on a foregrip and over the right hand on a pistol.
`arms.py` calls them for every replica and writes the clips.
"""

import math
import os

import bpy
from mathutils import Matrix, Vector

import cycle
import pose
import skin
from pose import Collider, Rig, basis

from hold_tables import (ACROSS, BARE_GRID, BEND_COST, CLEAR_COST, CUP_GAP, CUP_STEP, CUP_TRIES, ELBOW_DROP,
    FOREARM_CLEAR, GRIP_HOLDS, GRIP_SHOULDER, GUARD_AXIS, GUARD_RADIUS, Hold, LEFT_HELD, LOOSE_COST, MOVE_COST,
    OVER_COST, PALM_FACING, PALM_SPARSE, PARTS, PINKY_COST, PLAN_COST, REPLICAS, RIGHT_HELD, RIGHT_THUMB, RISE_COST,
    ROLL_STEP, SHOULDER, THUMB_BENDS, THUMB_TIP, THUMB_TWISTS, THUMB_WIDE, TIP_COUPLE, TIP_MOST, TRIGGER_SLACK, WRAP,
    WRAP_COST, YAW_STEP, aim, roll_about, tuned)


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
            o.matrix_world = hold.to_eye() @ o.matrix_world
    bpy.context.view_layer.update()
    return new


def fitted_optics(hold: Hold) -> tuple:
    """Everything the replica's parts file brought in, and of it the optics it fits on its top rail (`optic_*`, their
    own meshes, not their figure copies), moved to the hold's place as the replica is (BP7): what the right hand
    working a bolt must also clear. Both empty for a replica without a parts file."""
    path = os.path.join(PARTS, hold.file)
    if not os.path.isfile(path):
        return [], []
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    keep = []
    for o in new:
        top = o
        while top.parent is not None:
            top = top.parent
        if o.type == "MESH" and top.name.startswith("optic_") and "Figure" not in o.name:
            keep.append(o)
    for o in new:
        if o.parent is None:
            o.matrix_world = hold.to_eye() @ o.matrix_world
    bpy.context.view_layer.update()
    return new, keep


def has_trigger(objects: list) -> bool:
    """Whether the replica has a trigger for the index finger (a bomb has none: the index closes round it)."""
    return any(o.name.startswith("Trigger") for o in objects)


def trigger_face(objects: list, share: float = 0.55) -> Vector:
    """The trigger's front face `share` of the way down it (just below its middle; lower on a trigger whose top is up
    inside the receiver: `trigger_at`), where the index finger's pad rests (eye space)."""
    trig = next(o for o in objects if o.name.startswith("Trigger"))
    pts = [trig.matrix_world @ v.co for v in trig.data.vertices]
    z0, z1 = min(p.z for p in pts), max(p.z for p in pts)
    zm = z1 - (z1 - z0) * share
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


def straight_elbow(rig: Rig, side: str, hand_m: Matrix, sag: float = 0.0) -> Vector:
    """Where the elbow is when the wrist is straight: the forearm's length back along the hand's own line; with
    `sag`, that many degrees lower (the wrist bent back that little, as a hand carrying a rifle's weight is)."""
    fo, hn = "Forearm_" + side, "Hand_" + side
    line = (hand_m.to_3x3() @ rig.rest[hn].to_3x3().inverted() @ rig.rest[fo].to_3x3()).col[1]
    if sag:
        level = line.cross(Vector((0.0, 0.0, 1.0))).normalized()
        line = max((Matrix.Rotation(math.radians(d), 3, level) @ line for d in (sag, -sag)), key=lambda v: v.z)
    return hand_m.translation - line * (rig.rest[hn].translation - rig.rest[fo].translation).length


def shoulder_behind(rig: Rig, side: str, hand_m: Matrix, upper: tuple, sag: float = 0.0) -> None:
    """Moves the shoulder to where the wrist is straight (or bent back `sag` degrees): the upper arm's length from
    that elbow (`straight_elbow`), along `upper` (eye space, elbow to shoulder). The first-person view never shows
    the shoulder, only the forearm it leaves in line with the hand."""
    up = "UpperArm_" + side
    reach = (rig.rest["Forearm_" + side].translation - rig.rest[up].translation).length
    want = straight_elbow(rig, side, hand_m, sag) + Vector(upper).normalized() * reach
    rig.fk("Shoulder_" + side)
    rig.fk(up)
    key = "Shoulder_" + side
    rig.shift[key] = rig.shift.get(key, Vector()) + want - rig.pose[up].translation
    rig.fk(key)
    rig.fk(up)


def knuckle_pose(rig: Rig, hand: pose.Hand, j: dict, index_at: Vector, line: Vector, palm: Vector) -> Matrix:
    """The hand bone's pose with its index finger's knuckle at `index_at`, its knuckles' line (index to little
    finger) along `line` and its palm facing `palm` as near as that line allows."""
    sx = pose.to_side(hand.side)
    i0, p0 = sx(j["finger-2-1"]), sx(j["finger-5-1"])
    r = basis(line, palm) @ basis(p0 - i0, hand.palmar).transposed()
    return Matrix.Translation(index_at) @ r.to_4x4() @ Matrix.Translation(-i0) @ rig.rest["Hand_" + hand.side]


def pose_fingers(hand: pose.Hand, spec: dict, col: Collider, thumb_to: Vector = None, hug: float = 0.0,
                 wide: bool = False, root: bool = False, verify=None) -> dict:
    """Each finger of `spec` at its authored bends, settled onto the replica, and the thumb: swung so its tip comes
    nearest `thumb_to`, or at its authored turn; their bends, for the log."""
    curls = {}
    swing = dict(zip(("Middle", "Ring", "Pinky"), spec.get("swing", (0.0, 0.0, 0.0))))
    for name, start in spec["fingers"].items():
        curls[name] = hand.settle(name, start, col, swing=swing.get(name, 0.0), root=root,
                                  more=spec.get("curl_more"))
        if name in spec.get("press", ()):
            curls[name] = hand.press(name, curls[name], col, swing.get(name, 0.0))
    if thumb_to is not None:
        turns = (THUMB_WIDE, THUMB_TWISTS) if wide else (pose.THUMB_SWING, (-30, 0, 30))
        # How far its knuckle and tip joints may then close onto the replica (`thumb_curl`, degrees: a pistol's
        # thumb lies nearly straight forward along the frame, as in the owner's photos).
        knuckle, tip = spec.get("thumb_curl", (40.0, THUMB_TIP if wide else 45.0))
        curls["Thumb"] = hand.thumb(col, (0.5, 1.0, 0.8), (0.0, math.radians(knuckle), math.radians(tip)), thumb_to,
                                    hug, *turns,
                                    THUMB_BENDS if wide else (0,), spec.get("thumb_pull", 3.0),
                                    verify if spec.get("thumb_verify", 0.0) > 0.0 else None, spec.get("thumb_turn"))
    else:
        base, bends = spec["thumb"]
        curls["Thumb"] = hand.thumb_at(base, bends, col)
    return curls


def web_pose(rig: Rig, hand: pose.Hand, j: dict, hold: Hold, r: dict, col: Collider, side: str = "R") -> Matrix:
    """The right hand bone's pose on a pistol: its index finger's knuckle at r["index"] and its thumb's root at
    r["web"] (replica space), rolled about the line between them to where the wrist is straightest and the hand clear
    of the grip, its palm toward the grip's right side. With `side` "L", the left hand's on a foregrip, as the mirror
    of that: its palm toward the grip's left side (BP8)."""
    to_eye = hold.to_eye()
    sx = pose.to_side(side)
    out = 1.0 if side == "R" else -1.0
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
    lo, hi = r.get("rolls") or (-180, 174)
    for k in range(int(lo), int(hi) + 1, ROLL_STEP):
        rot = Matrix.Rotation(math.radians(k), 3, axis) @ base
        palm = rot @ hand.palmar
        if palm.x * out > -PALM_FACING:
            continue
        m0 = Matrix.Translation(i_at) @ rot.to_4x4() @ Matrix.Translation(-i_rest) @ rig.rest["Hand_" + side]
        m = hand.seat(m0, palm, col, whole=True)
        moved = (m.translation - m0.translation).length
        _, bend = elbow_for(rig, side, m, quiet=True)
        score = bend + moved * MOVE_COST
        p5 = m @ (rig.rest["Hand_" + side].inverted() @ p_rest)
        if p_at is not None:
            score += (p5 - p_at).length * r.get("pinky_cost", PINKY_COST)
        mcp = to_eye.inverted() @ (m @ (rig.rest["Hand_" + side].inverted() @ t_rest))
        if os.environ.get("BL_DEBUG"):
            print("    roll %4d: bend %5.1f moved %5.1f mm palm %s thumb knuckle %s pinky knuckle %s" % (
                k, bend, moved * 1000, tuple(round(c, 2) for c in palm), tuple(round(c, 3) for c in mcp),
                tuple(round(c, 3) for c in to_eye.inverted() @ p5)))
        if best is None or score < best[0]:
            best = (score, k, m, palm)
    print("  %s: web roll %d deg" % (side, best[1]))
    return best[2], best[3]


def support_pose(rig: Rig, hand: pose.Hand, j: dict, hold: Hold, r: dict, col: Collider) -> tuple:
    """The left hand bone's pose wrapped round a pistol the right hand holds (HA1; the owner, 2026-11-12: "the player
    is gripping the pistol tight"): laid by its three marks as `web_pose` lays a hand, then turned about the upright
    line through its index knuckle (r["yaws"], degrees: the heel of the hand in toward the grip) and rolled about the
    line from that knuckle to the thumb's root (r["rolls"]), each turn seated clear of the pistol and the right
    hand, to the turn whose palm lies closest over them (the mean gap under its skin, r["gap_cost"] a metre) and
    is pressed on the grip's bare left side behind the right hand's fingertips (the owner, of the view over the
    sights: "a gap between the left hand and the pistol grip. The hand should be pressed against the handle/grip"):
    the mean distance from that side (r["bare"], replica space: its y and z ranges on the side at x r["side"]) to
    the hand's skin, the heel of the thumb's too, r["bare_cost"] a metre; with the wrist least bent
    (r["bend_cost"] a degree). `web_pose` counts how far the hand was pushed off its marks instead, which stood
    this hand off the grip, flat beside it."""
    to_eye = hold.to_eye()
    sx = pose.to_side("L")
    i_rest, w_rest, p_rest = sx(j["finger-2-1"]), sx(j["finger-1-1"]), sx(j["finger-5-1"])
    i_at, w_at, p_at = (to_eye @ Vector(r[k]) for k in ("index", "web", "pinky"))
    base = pose.fit_turn([w_rest, i_rest, p_rest], [w_at, i_at, p_at])
    axis = (base @ (w_rest - i_rest)).normalized()
    up = (to_eye.to_3x3() @ Vector((0.0, 0.0, 1.0))).normalized()
    rest = rig.rest["Hand_L"]
    # The palm's own side of the hand bone's skin: the half of it furthest out toward what it holds.
    out = rest.to_3x3().inverted() @ hand.palmar
    skin = sorted(hand.palm, key=lambda q: -q.dot(out))[:len(hand.palm) // 2][::PALM_SPARSE]
    # The grip's bare side, and the skin that should lie on it: the hand bone's and the heel of the thumb's (the
    # thumb as it rests; it is laid along the frame afterwards).
    (y0, y1), (z0, z1) = r["bare"]
    bare = [to_eye @ Vector((r["side"], y0 + (y1 - y0) * a / BARE_GRID[0], z0 + (z1 - z0) * b / BARE_GRID[1]))
            for a in range(BARE_GRID[0] + 1) for b in range(BARE_GRID[1] + 1)]
    thumb = rest.inverted() @ rig.rest["Thumb1_L"]
    near = hand.points["Hand_L"] + [thumb @ q for q in hand.points["Thumb1_L"]]
    best = None
    for yaw in range(int(r["yaws"][0]), int(r["yaws"][1]) + 1, YAW_STEP):
        for roll in range(int(r["rolls"][0]), int(r["rolls"][1]) + 1, ROLL_STEP):
            rot = Matrix.Rotation(math.radians(yaw), 3, up) @ Matrix.Rotation(math.radians(roll), 3, axis) @ base
            palm = rot @ hand.palmar
            m0 = Matrix.Translation(i_at) @ rot.to_4x4() @ Matrix.Translation(-i_rest) @ rest
            m = hand.seat(m0, palm, col, whole=True)
            gap = sum(max(col.dist(m @ q), 0.0) for q in skin) / len(skin)
            posed = [m @ q for q in near]
            off = sum(min((q - p).length_squared for q in posed) ** 0.5 for p in bare) / len(bare)
            _, bend = elbow_for(rig, "L", m, quiet=True)
            score = gap * r["gap_cost"] + off * r["bare_cost"] + bend * r["bend_cost"]
            if os.environ.get("BL_DEBUG"):
                print("    yaw %3d roll %3d: gap %4.1f mm bare %4.1f mm bend %4.1f moved %4.1f mm" % (
                    yaw, roll, gap * 1000, off * 1000, bend, (m.translation - m0.translation).length * 1000))
            if best is None or score < best[0]:
                best = (score, yaw, roll, m, palm)
    print("  L: support turned %d deg, rolled %d deg" % best[1:3])
    return best[3], best[4]


def right_hand(rig: Rig, hand: pose.Hand, j: dict, hold: Hold, col: Collider, objects: list, arms: list,
               frame: list) -> tuple:
    """The right hand round the pistol grip; its curls, for the log. `arms` and `frame` (the replica less its
    trigger) check a thumb on its skinned glove (`thumb_verify`)."""
    g, r = hold.grip, tuned(hold.right)
    to_eye = hold.to_eye()
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
    def thumb_clips() -> int:
        rig.write()
        return sum(n for b, n in pose.clipping(arms, frame)[1].items() if b.startswith("Thumb") and b.endswith("_R"))

    curls = pose_fingers(hand, r, col, thumb_to, r["thumb_hug"], "thumb_at" in r, verify=thumb_clips)
    if not has_trigger(objects):
        return pole_r, curls
    if os.environ.get("BL_DEBUG") and thumb_to is not None:
        m = rig.pose["Thumb3_R"]
        tip = m.translation + m.to_3x3().col[1] * rig.length["Thumb3_R"]
        print("   thumb tip", tuple(round(v, 3) for v in to_eye.inverted() @ tip))
    # The index finger's pad rests on the trigger: the trigger itself is left out of what it must clear.
    frame = Collider([o for o in objects if o.type == "MESH" and not o.name.startswith(("Figure", "Icosphere",
                                                                                          "Trigger"))])
    # The trigger finger's tip kept `index_left` (m) short of the trigger's far side, when the hold asks.
    hand.trigger_at = float(r.get("trigger_at") or 0.55)
    face = trigger_face(objects, hand.trigger_at)
    hand.index_left = face.x - r["index_left"] if r.get("index_left") is not None else None
    # How far each of its joints may bend (degrees, base to tip): a pistol's trigger finger lies nearly straight, its
    # last pad on the trigger (the owner, 2026-11-06), never hooked round it.
    hand.index_bends = tuple(int(v) for v in r.get("index_bends") or (70, 90, 70))
    hand.index_from = -10 if r.get("index_from") is None else int(r["index_from"])
    hand.index_arc = r.get("index_arc")
    curls["Index"] = hand.onto("Index", face, frame, hand.index_bends, 40, pin=r.get("index_turn"))
    return pole_r, curls


def trigger_again(rig: Rig, hand: pose.Hand, objects: list, arms: list, frame: list) -> None:
    """After the palm has pressed in, the trigger finger finds the trigger again from where the hand now is; kept only
    if its glove stays clear of the frame and its pad is no further from the trigger than it was (the Cyber's
    second search loses the trigger inside its taller guard)."""
    bones = ["Index%d_R" % k for k in (1, 2, 3)]
    before = {b: rig.local[b].copy() for b in bones}
    col = Collider([o for o in objects if o.type == "MESH" and not o.name.startswith(("Figure", "Icosphere",
                                                                                        "Trigger"))])
    face = trigger_face(objects, hand.trigger_at)

    def pad_off() -> float:
        m = rig.pose[bones[2]]
        return min((m @ q - face).length for q in hand.points[bones[2]])

    was = pad_off()
    hand.onto("Index", face, col, hand.index_bends, 40)
    rig.write()
    clips = pose.clipping(arms, frame)[0]
    if clips or pad_off() > was + TRIGGER_SLACK:
        for b in bones:
            rig.fk(b, before[b])
        rig.refresh("Index1_R")
        rig.write()
        print("  trigger finger kept where it was (%s)" % ("clipping" if clips else "nearer the trigger"))


def left_on_guard(rig: Rig, hand: pose.Hand, j: dict, hold: Hold, col: Collider, spec: dict = None) -> tuple:
    """The left hand under a rifle's handguard, its fingers up the right side and the index finger along the side
    rail, the thumb along the left side (as the hold's spec, or `spec`)."""
    spec = tuned(hold.left if spec is None else spec)
    to_eye = hold.to_eye()
    y = spec["y"]
    at = to_eye @ Vector((0.0, y, spec.get("axis", GUARD_AXIS)[1]))

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
    if "upper" in spec:
        shoulder_behind(rig, "L", hand_m, spec["upper"], spec.get("sag", 0.0))
        rig.plan.pop("L", None)
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
        target = to_eye @ Vector((spec["tip_at"][0], k.y + spec["tip_at"][1],
                                  spec["tip_at"][2] - spec.get("tip_drop", {}).get(name, 0.0)))
        most = spec.get("tip_most", TIP_MOST)
        curls[name] = hand.onto(name, target, col, (int(most[0]), int(most[1]), 0), spec["tip_swing"], TIP_COUPLE,
                                back=int(spec.get("tip_back", 0.0)))
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
    axis = Vector(spec.get("axis", GUARD_AXIS))
    radius = spec.get("radius", GUARD_RADIUS)
    found = []
    (y0, y1), (p0, p1), (r0, r1) = spec["search"]
    for yaw in range(y0, y1 + 1, CUP_STEP):
        for pitch in range(p0, p1 + 1, CUP_STEP):
            for roll in range(r0, r1 + 1, CUP_STEP):
                m, palm = placed(float(yaw), float(pitch), float(roll))
                if "upper" in spec:
                    # The forearm lies on the hand's own line (`straight_elbow`): no bend to weigh.
                    elbow, bend = straight_elbow(rig, "L", m, spec.get("sag", 0.0)), 0.0
                else:
                    pole, bend = elbow_for(rig, "L", m, quiet=True)
                    if pole is None:
                        continue
                    rig.fk("Shoulder_L")
                    rig.fk("UpperArm_L")
                    elbow = rig.pose["UpperArm_L"].translation + pole
                fore = m.translation - elbow
                rise = math.degrees(math.atan2(fore.z, fore.xy.length))
                plan = math.degrees(math.atan2(abs(fore.x), fore.y))
                # The forearm (its sleeve) clears the replica: the magazine hangs just behind the support hand.
                clear = sum(max(0.0, FOREARM_CLEAR - col.dist(elbow.lerp(m.translation, t / 8.0)))
                            for t in range(1, 8))
                gaps = []
                for q in mcps:
                    p = to_eye.inverted() @ (m @ (rest_inv @ q))
                    gaps.append(math.hypot(p.x - axis[0], p.z - axis[1]) - radius)
                loose = sum(max(0.0, g - CUP_GAP[1], CUP_GAP[0] - g) for g in gaps)
                score = bend + abs(rise - spec["rise"]) * RISE_COST + loose * LOOSE_COST + \
                    clear * 1000.0 * CLEAR_COST + max(0.0, bend - spec.get("bend_most", 180.0)) * BEND_COST + \
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


def grip_parts(hold: Hold) -> tuple:
    """Everything the replica's parts file brought in, and of it each grip part's own mesh (`grip_*`, not its figure
    copy) by name, with its mount (the part's origin, replica space), moved to the hold's place as the replica is
    (BP8). Both empty for a replica without a parts file."""
    path = os.path.join(PARTS, hold.file)
    if not os.path.isfile(path):
        return [], {}
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    grips = {}
    for o in new:
        if o.type == "MESH" and o.parent is None and o.name.split(".")[0] in GRIP_HOLDS:
            grips[o.name.split(".")[0]] = (o, o.matrix_world.translation.copy())
    for o in new:
        if o.parent is None:
            o.matrix_world = hold.to_eye() @ o.matrix_world
    bpy.context.view_layer.update()
    return new, grips


def in_replica(spec: dict, mount: Vector) -> dict:
    """A grip hold's spec with its marks moved from the grip part's space onto the replica's (the part's origin at
    `mount`), the whole hand turned about the grip's middle (`pivot`) as `turn` asks (degrees: tilted so the
    forearm rises to the hand, then swung so it comes from the left)."""
    out = dict(spec)
    tilt, yaw = spec.get("turn", (0.0, 0.0))
    turn = Matrix.Rotation(math.radians(-yaw), 3, "Z") @ Matrix.Rotation(math.radians(tilt), 3, "X")
    pivot = Vector(spec["pivot"])
    for k in ("web", "index", "pinky", "thumb_at"):
        out[k] = tuple(turn @ (Vector(spec[k]) - pivot) + pivot + mount)
    return out


def left_on_grip(rig: Rig, hand: pose.Hand, j: dict, hold: Hold, spec: dict, col: Collider, arms: list,
                 frame: list) -> tuple:
    """The left hand round a foregrip (spec in replica space): placed by its marks as the right hand is on a pistol's
    grip (web_pose, mirrored), its fingers closed round the grip's front and its thumb round the back over them."""
    to_eye = hold.to_eye()
    hand.tip_top = None
    if spec["kind"] == "support":
        hand_m, palm = support_pose(rig, hand, j, hold, spec, col)
    else:
        hand_m, palm = web_pose(rig, hand, j, hold, spec, col, "L")
    hand.normal = palm
    if "upper" in spec:
        shoulder_behind(rig, "L", hand_m, spec["upper"], spec.get("sag", 0.0))
    pole_l, _ = elbow_for(rig, "L", hand_m)
    pose.place_arm(rig, "L", hand_m, pole_l, quiet=True)
    rig.refresh("Hand_L")

    def thumb_clips() -> int:
        rig.write()
        return sum(n for b, n in pose.clipping(arms, frame)[1].items() if b.startswith("Thumb") and b.endswith("_L"))

    curls = pose_fingers(hand, spec, col, to_eye @ Vector(spec["thumb_at"]), spec["thumb_hug"], True,
                         verify=thumb_clips)
    return pole_l, curls


def left_bases(rig: Rig) -> dict:
    """Every left-side bone's basis as posed now (the left arm's part of a key)."""
    return {b: rig.basis_of(b) for b in rig.rest if b.endswith("_L")}


def kept(rig: Rig) -> tuple:
    """The hold as posed now: every bone's pose and turn, and the arms' shoulder shifts, drops, across and plan."""
    return (dict(rig.pose), dict(rig.local), dict(rig.shift), dict(rig.drop), dict(rig.across), dict(rig.plan))


def reset_left(rig: Rig, held: tuple) -> None:
    """The rig back to the hold `held` (as `kept` took it)."""
    rig.pose, rig.local = dict(held[0]), dict(held[1])
    rig.shift, rig.drop, rig.across, rig.plan = (dict(d) for d in held[2:6])
    rig.write()


def solve_grip(rig: Rig, hands: dict, j: dict, hold: Hold, rid: str, arms: list, solid: list, grip,
               spec: dict, held: tuple) -> int:
    """With the hold `held` posed (the right hand as approved), the left hand re-solved round the fitted grip `grip`
    (its mesh and mount) as `spec` asks, settled and closed onto it as `solve` does; the clipping left (face pairs)."""
    reset_left(rig, held)
    mesh, mount = grip
    spec = in_replica(tuned(spec), mount)
    rig.shift["Shoulder_L"] = Vector(GRIP_SHOULDER.get(rid, spec["shoulder"]))
    rig.drop["L"], rig.across["L"] = spec["drop"], spec["across"]
    rig.plan.pop("L", None)
    for b in rig.rest:
        if b.endswith("_L"):
            rig.local.pop(b, None)
            rig.pose[b] = rig.rest[b]
    rig.fk("Shoulder_L")
    frame = [o for o in solid if not o.name.startswith("Trigger")] + [mesh]
    col = Collider(solid + [mesh])
    pole_l, curls = left_on_grip(rig, hands["L"], j, hold, spec, col, arms, frame)
    rig.fk("Grip_L")
    # A thumb laid where the hold asks may pass into the grip or the replica (an angled grip's swept face, a vertical
    # grip's top): the clear turn nearest that spot instead.
    rig.write()
    thumb = [b for b, n in pose.clipping(arms, frame)[1].items() if b.startswith("Thumb") and b.endswith("_L") and n]
    if thumb:
        t3 = rig.pose["Thumb3_L"]
        tip = t3.translation + t3.to_3x3().col[1] * rig.length["Thumb3_L"]
        curls["Thumb"] = cycle.clear_thumb(hands["L"], col, tip)
        rig.fk("Grip_L")
    print("  left curls", curls)
    poles = {"R": rig.poles["R"], "L": pole_l}
    hits = 0 if os.environ.get("BL_NORELAX") else pose.relax(rig, hands, arms, frame, poles)
    if not hits and not os.environ.get("BL_NORELAX"):
        print("  L palm pressed in %.1f mm" % (pose.press(rig, hands, arms, frame, poles, "L") * 1000))
        fingers = [("L", n) for n in ("Index", "Middle", "Ring", "Pinky", "Thumb")]
        print("  tightened", pose.tighten(rig, hands, arms, frame, fingers))
        print("  wrapped", pose.wrap(rig, hands, arms, frame, [f for f in fingers if f[1] != "Thumb"]))
        hits, tally = pose.clipping(arms, frame)
        if hits:
            print("  still passing into the replica:", sorted(tally.items(), key=lambda x: -x[1]))
    print("  L wrist bend %.1f deg" % pose.wrist_bend(rig, "L"))
    return hits


def solve_support(rig: Rig, hands: dict, j: dict, hold: Hold, arms: list, solid: list, spec: dict,
                  held: tuple) -> int:
    """With the hold `held` posed (the right hand as approved, the left down), the left hand wrapped round the pistol
    and the right hand as `spec` asks (HA1): placed by its marks, turned to where its palm lies closest
    (`support_pose`), then settled, pressed and closed on the skinned surface against the pistol and the right arm as
    posed, less the right thumb's two outer sections, which lie where its heel belongs; that thumb is then laid again,
    on the left hand (`lay_right_thumb`). The clipping left (face pairs)."""
    reset_left(rig, held)
    left, right = arms
    spec = tuned(spec)
    rig.shift["Shoulder_L"] = Vector(spec["shoulder"])
    rig.drop["L"], rig.across["L"] = spec["drop"], spec["across"]
    rig.plan.pop("L", None)
    for b in rig.rest:
        if b.endswith("_L"):
            rig.local.pop(b, None)
            rig.pose[b] = rig.rest[b]
    rig.fk("Shoulder_L")
    rig.write()
    still = pose.frozen(right, RIGHT_HELD, RIGHT_THUMB)
    if os.environ.get("BL_DEBUG"):
        inv = hold.to_eye().inverted()
        for name in ("Thumb", "Index", "Middle", "Ring", "Pinky"):
            print("   R %s joints" % name, [tuple(round(c, 3) for c in inv @ rig.pose["%s%d_R" % (name, k)].translation)
                                           for k in (1, 2, 3)])
    frame = [o for o in solid if not o.name.startswith("Trigger")] + [still]
    col = Collider(solid + [still])
    pole_l, curls = left_on_grip(rig, hands["L"], j, hold, spec, col, [left], frame)
    rig.fk("Grip_L")
    rig.write()
    thumb = [b for b, n in pose.clipping([left], frame)[1].items() if b.startswith("Thumb") and n]
    if thumb:
        t3 = rig.pose["Thumb3_L"]
        tip = t3.translation + t3.to_3x3().col[1] * rig.length["Thumb3_L"]
        curls["Thumb"] = cycle.clear_thumb(hands["L"], col, tip)
        rig.fk("Grip_L")
    print("  left curls", curls)
    poles = {"R": rig.poles["R"], "L": pole_l}
    hits = 0 if os.environ.get("BL_NORELAX") else pose.relax(rig, hands, [left], frame, poles)
    if not hits and not os.environ.get("BL_NORELAX"):
        print("  L palm pressed in %.1f mm" % (pose.press(rig, hands, [left], frame, poles, "L") * 1000))
        fingers = [("L", n) for n in ("Index", "Middle", "Ring", "Pinky", "Thumb")]
        print("  tightened", pose.tighten(rig, hands, [left], frame, fingers))
        print("  wrapped", pose.wrap(rig, hands, [left], frame, [f for f in fingers if f[1] != "Thumb"]))
        hits, tally = pose.clipping([left], frame)
        if hits:
            print("  still passing into the pistol or the right hand:", sorted(tally.items(), key=lambda x: -x[1]))
        if os.environ.get("BL_DEBUG"):
            print("   L skin gaps (mm)", pose.skin_gaps([left], frame, "L"))
            inv = hold.to_eye().inverted()
            for name in ("Thumb", "Index", "Middle", "Ring", "Pinky"):
                print("   L %s joints" % name, [tuple(round(c, 3) for c in inv @ rig.pose["%s%d_L" % (name, k)]
                                                      .translation) for k in (1, 2, 3)])
    print("  L wrist bend %.1f deg" % pose.wrist_bend(rig, "L"))
    bpy.data.objects.remove(still, do_unlink=True)
    return hits + lay_right_thumb(rig, hands, hold, arms, solid, spec)


def lay_right_thumb(rig: Rig, hands: dict, hold: Hold, arms: list, solid: list, spec: dict) -> int:
    """The right thumb laid on the left hand that now wraps the pistol (HA1; the owner, 2026-11-12: "the right hand
    thumb should be resting on the left hand"): swung to the clear place whose tip comes nearest a spot over the left
    thumb's first section (spec["right_thumb"]: how far along that section, and how far above the two thumbs' skins
    meeting, m), then closed onto it. The face pairs where the two arms still pass into each other or the pistol."""
    left, right = arms
    under = pose.frozen(left, LEFT_HELD)
    frame = [o for o in solid if not o.name.startswith("Trigger")]
    col = Collider(solid + [under])
    to_eye = hold.to_eye()
    up = (to_eye.to_3x3() @ Vector((0.0, 0.0, 1.0))).normalized()
    along, lift = spec["right_thumb"]
    m = rig.pose["Thumb2_L"]
    target = m.translation + m.to_3x3().col[1] * rig.length["Thumb2_L"] * along + \
        up * (hands["L"].radius["Thumb2_L"] + hands["R"].radius["Thumb3_R"] + lift)

    def thumb_clips() -> int:
        rig.write()
        return sum(n for b, n in pose.clipping([right], frame + [under])[1].items() if b.startswith("Thumb"))

    knuckle, tip = spec["right_thumb_curl"]
    curls = hands["R"].thumb(col, (0.5, 1.0, 0.8), (0.0, math.radians(knuckle), math.radians(tip)), target,
                             spec["right_thumb_hug"], THUMB_WIDE, THUMB_TWISTS, THUMB_BENDS,
                             spec["right_thumb_pull"], thumb_clips, spec.get("right_thumb_turn"))
    rig.fk("Grip_R")
    rig.write()
    print("  right thumb on the left hand", curls)
    print("  tightened", pose.tighten(rig, hands, [right], frame + [under], [("R", "Thumb")]))
    hits, tally = pose.clipping([right], frame + [under])
    if hits:
        print("  the right hand still passing into the pistol or the left hand:",
              sorted(tally.items(), key=lambda x: -x[1]))
    if os.environ.get("BL_DEBUG"):
        inv = to_eye.inverted()
        print("   R thumb joints", [tuple(round(c, 3) for c in inv @ rig.pose["Thumb%d_R" % k].translation)
                                    for k in (1, 2, 3)], "target", tuple(round(c, 3) for c in inv @ target))
        print("   R skin gaps (mm)", pose.skin_gaps([right], frame + [under], "R"))
        # How far each hand's skin stands off the grip's left side (replica space: rows down the grip, front to back).
        other = pose.frozen(right, RIGHT_HELD)
        for name, c in (("L", Collider([under])), ("R", Collider([other]))):
            for z in (-0.050, -0.065, -0.080, -0.095, -0.110):
                print("   %s off the left side at z %.3f:" % (name, z), " ".join(
                    "%3d" % round(c.dist(to_eye @ Vector((-0.015, y / 1000.0, z))) * 1000)
                    for y in range(-40, -106, -8)))
        bpy.data.objects.remove(other, do_unlink=True)
    bpy.data.objects.remove(under, do_unlink=True)
    return hits


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
    # The trigger finger's pad rests on the trigger (`onto` keeps it there), so the checks leave the trigger out.
    frame = [o for o in solid if not o.name.startswith("Trigger")]
    rig.fk("Shoulder_L")
    rig.fk("Shoulder_R")
    pole_r, curls_r = right_hand(rig, hands["R"], j, hold, col, objects, arms, frame)
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
    rig.poles = poles
    hits = 0 if os.environ.get("BL_NORELAX") else pose.relax(rig, hands, arms, frame, poles)
    if not hits and not os.environ.get("BL_NORELAX"):
        # Then each holding palm seats on the replica and every holding finger closes until its glove all but
        # touches it (the trigger finger stays on its mark).
        for side in ("R", "L") if hold.left["kind"] == "guard" else ("R",):
            print("  %s palm pressed in %.1f mm" % (side, pose.press(rig, hands, arms, frame, poles, side) * 1000))
        trigger = has_trigger(objects)
        if trigger:
            trigger_again(rig, hands["R"], objects, arms, frame)
        fingers = [("R", n) for n in ("Middle", "Ring", "Pinky", "Thumb")]
        if not trigger:
            fingers.insert(0, ("R", "Index"))
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
