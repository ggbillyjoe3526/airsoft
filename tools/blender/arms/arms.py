"""The first-person arms (BL4): hard-knuckle tactical gloves and the sleeves of a combat shirt over a real human arm
and hand, posed holding each replica.

The mesh is built by `glove.py` (the MakeHuman base mesh's left arm, CC0, under a glove and sleeve), the rig and the
contact solver are `pose.py`'s, each hold's marks and costs are data in `hold_tables.py`, and `hold_solve.py` places
and closes the hands on each replica from them. Both arms hang from one armature, `Arms`, whose bones are named as
the figures' skeleton names them (Shoulder_R, UpperArm_R, Forearm_R, Hand_R, Thumb1_R..Pinky3_R, Grip_R, and the same
_L).

Each replica in HOLDS gets a clip `<id>_Hold` and an empty `Hold_<id>`, where the replica's origin sits in that pose
(the game's hip hold, ViewModelConfig.hip). The right hand closes round the pistol grip: the knuckle line laid along
the grip, the palm seated on it, each finger curled joint by joint until it meets the grip, the index finger's pad on
the trigger and the thumb round the back. The left hand holds a rifle's handguard from below, its fingers open under
it and out of the eye's sight, or wraps a pistol's grip over the right hand's fingers. The build checks every pose's
arms against its replica (and the left hand against the right) and stops without writing if any face passes into
another.

BP8 (the owner's playtest notes 6, 9 and 11): a replica that takes a foregrip gets `<id>_grip_<key>_Hold` for each
(the left hand wraps a vertical grip and cups an angled one's swept face; the right hand as approved), and a
bolt-action one `<id>_grip_<key>_Fire` too. Every replica with a Reload clip gets `<id>[_grip_<key>]_Reload` from each
hold, as long as that clip (`magazine.py`): the left hand pulls the magazine, takes it down out of view and seats the
fresh one. The glove's kit is an object of its own (GloveKit_<side>) and the fingernails another (Nails_<side>), so
the game can show skin-only arms on the same skeleton and clips.

HA1 (the owner): the glove's cloth over the hand is its own object too (HandSurface_<side>), and the bare hand
another (Skin_<side>: the same faces in the hand's own shape, a fuller wrist and a tapered thumb), and everything is
painted at 2K from where it lies on the arm: the bare skin (`skin.py`), the glove and its kit over the same atlas
(`glove_paint.py`) and the sleeve (`sleeve_paint.py`). A pistol gets a second hold in both hands
(`<id>_two_Hold`, `<id>_two_Reload`), the player's; `<id>_Hold` stays the bots' one-handed one. A helper bone at each
thumb's root (Heel_<side>) keeps the skin between wrist and thumb from wringing. BL_PREVIEW=<folder> draws each hold
(`preview.py`).

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3), after the replicas:

    python -I tools/blender/arms/arms.py <repo root>

It writes assets/models/arms/arms.glb.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "replicas"))

import bpy  # noqa: E402  first: it brings bmesh and mathutils with it
import bmesh  # noqa: E402
from mathutils import Matrix  # noqa: E402

import cycle  # noqa: E402
import glove  # noqa: E402
import glove_paint  # noqa: E402
import hardsurface as hs  # noqa: E402
import magazine  # noqa: E402
import pose  # noqa: E402
import skin  # noqa: E402
import sleeve_paint  # noqa: E402
import preview  # noqa: E402
from pose import Rig  # noqa: E402
from hold_tables import GRIP_HOLDS, HOLDS, ROOT, SHOULDER, SUPPORT, TWO, pictures  # noqa: E402
from hold_solve import (  # noqa: E402
    elbow_for, fitted_optics, grip_parts, kept, left_bases, reset_left, solve, solve_grip, solve_support)

OUT = os.environ.get("BL_OUT") or os.path.join(ROOT, "assets/models/arms/arms.glb")
FPS = 60

# Colours from the owner's glove photos (ref_images/hands/gloves: dark olive with black moulded knuckles), the same as
# the figures' gloves (BL10), so your arms match what other players wear.
MATERIALS = {
    "Glove": (0x4c4638, 0.85, 0.0), "GloveArmour": (0x242422, 0.68, 0.0), "Sleeve": (0x667052, 0.92, 0.0),
    "SleeveTrim": (0x515a41, 0.88, 0.0),
}
NAMES = list(MATERIALS)
# HA1: every surface is painted at 2K. The glove's two materials share one set of maps (glove_paint.py, over the
# skin's atlas: the cloth over the hand and the cuff are "Glove", the moulded and sewn-on pieces "GloveArmour", two
# names so a robot's arms can still colour them apart); the sleeve's faces all end on "Sleeve" (sleeve_paint.py).
GLOVE = ("Glove", "GloveArmour")
SLEEVE = "Sleeve"
# The glove's cloth over the hand, an object of its own: the skin-only arms show it in the skin's material.
HAND = "HandSurface_"
# The painted maps are stored as WebP at this quality (hardsurface.export).
WEBP = 95
# The skin-only arms' skin and fingernails (HA1): one material, its colour, roughness and normal maps painted by
# skin.py; this plain tone only until they are.
SKIN = "Skin"
SKIN_PLAIN = (0xcc9b82, 0.5, 0.0)


def split_off(ob: bpy.types.Object, name: str, faces: set) -> bpy.types.Object:
    """Moves the faces `faces` (by index) of `ob` into an object of their own named `name`, skinned as `ob` is."""
    part = ob.copy()
    part.data = ob.data.copy()
    part.name = part.data.name = name
    bpy.context.scene.collection.objects.link(part)
    for o, drop in ((ob, lambda i: i in faces), (part, lambda i: i not in faces)):
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if drop(f.index)], context="FACES")
        bm.to_mesh(o.data)
        bm.free()
    return part


def build() -> None:
    hs.reset(FPS)
    for name, (colour, rough, metal) in MATERIALS.items():
        hs.material(name, colour, rough, metal)
    pose.SHOULDER.update(SHOULDER)
    mesh, j, fr, pts = glove.build_left(SHOULDER["L"])
    arm = pose.armature(pts, fr)
    left = pose.skin_object("Arm_L", mesh, arm, "L", NAMES)
    right = pose.skin_object("Arm_R", mesh, arm, "R", NAMES)
    for ob in (left, right):
        ob.data.uv_layers.new(name="UVMap")
    # The bare hands under the gloves (BP8, the owner's playtest note 11; HA1): the hand's skin, Skin_<side>, and the
    # fingernails, Nails_<side>, painted by skin.py. Made before the holds so the build's pictures can show them
    # (BL_PREVIEW_SHOW), and left out of those pictures otherwise.
    hs.material(SKIN, *SKIN_PLAIN)
    skins = [pose.skin_object("Skin_" + side, mesh.skin, arm, side, [SKIN]) for side in "LR"]
    nails = [pose.skin_object("Nails_" + side, mesh.nails, arm, side, [SKIN]) for side in "LR"]
    laid = skin.dress(skins[0], skins[1], nails, mesh.nails.v, fr, SKIN)
    glove_paint.dress([left, right], skins, mesh.parts, laid, GLOVE)
    sleeve_paint.dress([left, right], mesh.parts, fr, SLEEVE)
    for ob in skins + nails:
        ob.hide_render = True
    rig = Rig(arm)
    rig.fk("Shoulder_L")
    rig.fk("Shoulder_R")
    hands = {s: pose.Hand(s, rig, mesh, fr, j) for s in ("L", "R")}
    if os.environ.get("BL_REST"):
        # The bare left hand as the model rests it, from the back and the palm, for measuring against the owner's
        # photo of a hand (tools/blender/arms/hand_ratios.py); no hold is solved and nothing is written.
        preview.rest_hand(os.environ["BL_REST"], rig, [left, right], skins + nails)
        return
    only = os.environ.get("BL_ONLY")
    failed = []
    clips = {"%s_Hold" % r for r in HOLDS}
    for rid, hold in HOLDS.items():
        if only and rid not in only.split(","):
            continue
        print("%s:" % rid)
        objects, solid, hits = solve(rig, hands, j, hold, [left, right])
        for side in ("R", "L"):
            print("  %s wrist bend %.1f deg" % (side, pose.wrist_bend(rig, side)))
        pose.key_pose(rig, "%s_Hold" % rid)
        holds = {"": kept(rig)}
        pictures(rid, hold, rid, rig, objects)
        if rid in SUPPORT and os.environ.get("BL_TWO") != "0":
            # A pistol in both hands (HA1): the right hand as approved, the left wrapped round it.
            print("%s in both hands:" % rid)
            two_hits = solve_support(rig, hands, j, hold, [left, right], solid, SUPPORT[rid], holds[""])
            pose.key_pose(rig, "%s_%s_Hold" % (rid, TWO))
            clips.add("%s_%s_Hold" % (rid, TWO))
            holds[TWO] = kept(rig)
            pictures("%s_%s" % (rid, TWO), hold, rid, rig, objects)
            if two_hits:
                failed.append("%s in both hands (%d face pairs)" % (rid, two_hits))
        bolt_keys = None
        if cycle.has_bolt(objects):
            # A bolt-action replica: the right hand leaves the grip after the shot and works the bolt.
            # Each optic it can fit is checked too (BP7): the hand's path keeps it under the receiver's top, and
            # this proves it clears every scope (a check only: the optics never steer the hand).
            optics, optic_meshes = fitted_optics(hold)
            bolt_hits, bolt_keys = cycle.work_bolt(rig, hands["R"], objects, solid, [left, right],
                                                   "%s_%s" % (rid, cycle.CLIP), elbow_for, optic_meshes)
            for o in optics:
                bpy.data.objects.remove(o, do_unlink=True)
            if bolt_hits:
                failed.append("%s working the bolt (%d keys)" % (rid, bolt_hits))
            clips.add("%s_%s" % (rid, cycle.CLIP))
        if cycle.has_pump(objects):
            # A pump-action replica (SH2): the left hand goes back and home with the pump after each shot.
            # Its wrist stays straight enough to read as one arm, held and through the stroke (cycle.PUMP_WRIST).
            held_bend = pose.wrist_bend(rig, cycle.PUMP_SIDE)
            pump_hits, pump_bend = cycle.work_pump(rig, objects, solid, [left, right], "%s_%s" % (rid, cycle.CLIP))
            reset_left(rig, holds[""])
            if pump_hits:
                failed.append("%s working the pump (%d keys)" % (rid, pump_hits))
            if max(held_bend, pump_bend) > cycle.PUMP_WRIST:
                failed.append("%s's pumping wrist bends %.0f deg held and %.0f deg at most over the stroke (the "
                              "limit is %.0f)" % (rid, held_bend, pump_bend, cycle.PUMP_WRIST))
            clips.add("%s_%s" % (rid, cycle.CLIP))
        # Each foregrip it takes (BP8): the left hand round it, the right hand as approved; a bolt-action replica's
        # bolt worked from that hold too (the same right hand's keys, the left arm on the grip throughout).
        parts, grips = grip_parts(hold) if os.environ.get("BL_GRIPS") != "0" else ([], {})
        for name, grip in sorted(grips.items()):
            if os.environ.get("BL_GRIP_ONLY") and name not in os.environ["BL_GRIP_ONLY"].split(","):
                continue
            print("%s with %s:" % (rid, name))
            grip_hits = solve_grip(rig, hands, j, hold, rid, [left, right], solid, grip, GRIP_HOLDS[name],
                                   holds[""])
            pose.key_pose(rig, "%s_%s_Hold" % (rid, name))
            clips.add("%s_%s_Hold" % (rid, name))
            holds[name] = kept(rig)
            if os.environ.get("BL_PREVIEW"):
                # The pictures show this grip alone of the parts the file brought in.
                others = [o for o in parts if o is not grip[0] and not o.hide_render]
                for o in others:
                    o.hide_render = True
                pictures("%s_%s" % (rid, name), hold, rid, rig, objects)
                for o in others:
                    o.hide_render = False
            if grip_hits:
                failed.append("%s with %s (%d face pairs)" % (rid, name, grip_hits))
            if bolt_keys is not None:
                on_grip = left_bases(rig)
                cycle.key_frames(rig, "%s_%s_%s" % (rid, name, cycle.CLIP),
                                 [(f, dict(bases, **on_grip)) for f, bases in bolt_keys])
                clips.add("%s_%s_%s" % (rid, name, cycle.CLIP))
        # The magazine change, from each hold (BP8).
        if os.environ.get("BL_RELOAD") != "0":
            # A pistol's is from the hold in both hands alone: the one in the right hand is the bots', who have
            # their own reloads.
            reload_hits, reload_clips = magazine.change_mag(rig, hands["L"], rid, hold.to_eye(), objects, solid,
                                                          [left, right], holds, TWO if TWO in holds else None)
            clips.update(reload_clips)
            if reload_hits:
                failed.append("%s changing the magazine (%d keys)" % (rid, reload_hits))
        reset_left(rig, holds[""])
        for o in parts:
            bpy.data.objects.remove(o, do_unlink=True)
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
    # The skin-only arms: the glove's kit (the moulded shell, pads, palm patch, cuff and strap) is an object of its
    # own, GloveKit_<side>, and so is its cloth over the hand, HandSurface_<side> (its faces are the arm's first); the
    # game hides both to show the bare hands made above (Skin_<side>, the same faces in the hand's own shape:
    # glove.build_left) and their nails. The same skeleton and clips: only what the game shows changes.
    kits = [split_off(ob, "GloveKit_" + side, set(range(*mesh.kit))) for side, ob in (("L", left), ("R", right))]
    cloth = [split_off(ob, HAND + side, set(range(*mesh.parts["hand"]))) for side, ob in (("L", left), ("R", right))]
    for ob in skins + nails:
        ob.hide_render = False
    sleeves = sum(hs.tris(o) for o in (left, right))
    gloved, bare = sum(hs.tris(o) for o in cloth + kits), sum(hs.tris(o) for o in skins + nails)
    print("  arms: %d triangles in the file (%d drawn with the gloves, %d skin only)" % (
        sleeves + gloved + bare, sleeves + gloved, sleeves + bare))
    for a in list(bpy.data.actions):
        if a.name not in clips:
            bpy.data.actions.remove(a)
    if failed and not os.environ.get("BL_FORCE"):
        raise SystemExit("the posed arms fail a check (a hand in a replica, a wrist bent too far): " + ", ".join(failed))
    hs.export(OUT, True, WEBP)
    print("wrote", OUT)


if __name__ == "__main__":
    build()
