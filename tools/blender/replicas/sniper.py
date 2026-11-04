"""The Sniper Rifle's placeholder model and its parts file (SN1, 2026-11-02).

The owner's brief (2026-11-02): it looks like the AEG with a longer barrel, and is driven by a spring. So it is the AEG's
model (assets/models/replicas/aeg.glb) with its barrel run on EXTENSION metres (an outer barrel and a band where it
leaves the handguard), the flash hider, Muzzle and BarrelEnd moved out to the new end, the figure version lengthened
the same, and a new Fire clip: the trigger, then the charging handle drawn back and let go, cocking the spring for the
next shot (about a second, the rifle's cycle). Every other clip, bone, material and empty is the AEG's. The parts file
is the AEG's (assets/models/replicaParts/aeg.glb) without its barrels and magazines (the rifle's barrel is fixed and
its magazines are its own), the silencer moved out to the new barrel end. The owner makes the final model from his
reference photos; this one only has to play.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/replicas/sniper.py <repo root>

It writes assets/models/replicas/sniper.glb and assets/models/replicaParts/sniper.glb.
"""

import math
import os
import sys

import bpy  # first: it brings bmesh and mathutils with it
import bmesh
from mathutils import Matrix, Vector

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
AEG_MODEL = os.path.join(ROOT, "assets/models/replicas/aeg.glb")
AEG_PARTS = os.path.join(ROOT, "assets/models/replicaParts/aeg.glb")
OUT_MODEL = os.path.join(ROOT, "assets/models/replicas/sniper.glb")
OUT_PARTS = os.path.join(ROOT, "assets/models/replicaParts/sniper.glb")

ARMATURE_NAME = "SniperRifle"
# How much longer the barrel is than the AEG's (m), and the AEG's barrel end and bore height (Blender space: +Y
# forward, +Z up) that it grows from. The AEG was cut to its photos' length in BL1 (its barrel end 0.565 -> 0.339); the
# rifle kept its own length (barrel end 0.765), so its run grew by as much. build_model checks the AEG's BarrelEnd.
EXTENSION = 0.426
AEG_BARREL_END = Vector((0.0, 0.339, 0.044))
BARREL_RADIUS = 0.0105
BAND_RADIUS = 0.0135
BAND_LENGTH = 0.014
CYL_SEGMENTS = 16
FIGURE_SEGMENTS = 6
# The figure version's vertices this close behind the AEG's barrel end (m) or past it are its muzzle: moved out too.
FIGURE_END_SLACK = 0.005
# The AEG's objects that move out with the barrel's end.
MOVED_OUT = ["FlashHider", "Muzzle", "BarrelEnd"]
# The parts the rifle doesn't take (pool.md: no barrel-mount, no aeg-mag).
DROPPED_PARTS = ["barrel_", "magazine_"]
FPS = 24
# Fire: the trigger pulled (the AEG's own pull), then the charging handle drawn CHARGE_TRAVEL m back and let go.
TRIGGER_PULL = math.radians(17.0)
CHARGE_TRAVEL = 0.05
FIRE_KEYS = [
    (0, {}), (2, {"trigger": (-TRIGGER_PULL, 0.0)}), (4, {}), (7, {}), (12, {"chargingHandle": (0.0, -CHARGE_TRAVEL)}),
    (14, {"chargingHandle": (0.0, -CHARGE_TRAVEL)}), (17, {}), (24, {}),
]


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS


def add_cylinder_y(bm: bmesh.types.BMesh, y0: float, y1: float, r: float, z: float, mat: int, segments: int) -> None:
    """A cylinder along +Y from y0 to y1, its axis at (0, z), its faces in material slot `mat`."""
    geom = bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=r, radius2=r, depth=y1 - y0)
    verts = geom["verts"]
    bmesh.ops.transform(bm, matrix=Matrix.Rotation(-math.pi * 0.5, 4, "X"), verts=verts)
    bmesh.ops.translate(bm, vec=Vector((0.0, (y0 + y1) * 0.5, z)), verts=verts)
    vs = set(verts)
    for f in bm.faces:
        if all(v in vs for v in f.verts):
            f.material_index = mat


def mesh_object(name: str, bm: bmesh.types.BMesh, materials: list) -> bpy.types.Object:
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in materials:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def lengthen_barrel(arm: bpy.types.Object) -> None:
    """The outer barrel run on from the AEG's barrel end, a band where it leaves the handguard, and the barrel's end
    (flash hider, Muzzle, BarrelEnd) moved out to the new end."""
    mats = bpy.data.materials
    y0 = AEG_BARREL_END.y
    y1 = y0 + EXTENSION
    z = AEG_BARREL_END.z
    bm = bmesh.new()
    add_cylinder_y(bm, y0 - 0.01, y1, BARREL_RADIUS, z, 0, CYL_SEGMENTS)
    add_cylinder_y(bm, y0, y0 + BAND_LENGTH, BAND_RADIUS, z, 1, CYL_SEGMENTS)
    ext = mesh_object("BarrelExtension", bm, [mats["Metal"], mats["Detail"]])
    ext.parent = arm
    body = bpy.data.objects["Body"]
    # One mesh with the body, as the docs ask (no draw call of its own).
    bpy.ops.object.select_all(action="DESELECT")
    ext.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    for name in MOVED_OUT:
        bpy.data.objects[name].location.y += EXTENSION
    # The figures' version: its own barrel run on as far, in its own few faces.
    fig = bpy.data.objects["Figure"]
    for v in fig.data.vertices:
        if v.co.y > y0 - FIGURE_END_SLACK:
            v.co.y += EXTENSION
    bm = bmesh.new()
    add_cylinder_y(bm, y0, y1, BARREL_RADIUS, z, 0, FIGURE_SEGMENTS)
    fext = mesh_object("FigureExtension", bm, [mats["Metal"]])
    bpy.ops.object.select_all(action="DESELECT")
    fext.select_set(True)
    fig.select_set(True)
    bpy.context.view_layer.objects.active = fig
    bpy.ops.object.join()


def key_pose(arm: bpy.types.Object, frame: float, poses: dict) -> None:
    """Keys every bone at `frame`: those in `poses` as (rotation about the bone's X, move along its Y), the rest at rest."""
    for pb in arm.pose.bones:
        tilt, slide = poses.get(pb.name, (0.0, 0.0))
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Matrix.Rotation(tilt, 4, "X").to_quaternion()
        pb.location = Vector((0.0, slide, 0.0))
        pb.scale = Vector((1.0, 1.0, 1.0))
        for path in ("rotation_quaternion", "location", "scale"):
            pb.keyframe_insert(path, frame=frame)


def new_fire_clip(arm: bpy.types.Object) -> None:
    """Replaces the AEG's Fire clip with the spring rifle's: trigger, then the charging handle back and home."""
    ad = arm.animation_data
    for track in list(ad.nla_tracks):
        if track.name == "Fire":
            ad.nla_tracks.remove(track)
    bpy.data.actions.remove(bpy.data.actions["Fire"])
    act = bpy.data.actions.new("Fire")
    ad.action = act
    for frame, poses in FIRE_KEYS:
        key_pose(arm, frame, poses)
    ad.action = None
    track = ad.nla_tracks.new()
    track.name = "Fire"
    track.strips.new("Fire", 0, act)


def build_model() -> None:
    reset()
    bpy.ops.import_scene.gltf(filepath=AEG_MODEL)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    arm.name = ARMATURE_NAME
    arm.data.name = ARMATURE_NAME
    # The importer's bone display shape is no part of the model.
    for ob in [o for o in bpy.data.objects if o.type == "MESH" and not o.data.materials]:
        bpy.data.objects.remove(ob, do_unlink=True)
    end = bpy.data.objects["BarrelEnd"].matrix_world.translation
    if (end - AEG_BARREL_END).length > 0.001:
        raise SystemExit("the AEG's BarrelEnd is at %s, not %s: update AEG_BARREL_END" % (tuple(end), tuple(AEG_BARREL_END)))
    lengthen_barrel(arm)
    new_fire_clip(arm)
    export(OUT_MODEL, True)
    tris()


def build_parts() -> None:
    reset()
    bpy.ops.import_scene.gltf(filepath=AEG_PARTS)
    for ob in [o for o in bpy.data.objects if o.parent is None]:
        if any(ob.name.startswith(p) for p in DROPPED_PARTS):
            for child in ob.children_recursive:
                bpy.data.objects.remove(child, do_unlink=True)
            bpy.data.objects.remove(ob, do_unlink=True)
        elif ob.name.startswith("muzzle_"):
            ob.location.y += EXTENSION
    export(OUT_PARTS, False)
    tris()


def export(path: str, animated: bool) -> None:
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=True,
            export_animations=animated, export_animation_mode="NLA_TRACKS", export_yup=True,
            export_draco_mesh_compression_enable=False, export_extras=False, export_cameras=False,
            export_lights=False)


def tris() -> None:
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            print("  %s: %d triangles" % (ob.name, sum(len(p.vertices) - 2 for p in ob.data.polygons)))


if __name__ == "__main__":
    build_model()
    build_parts()
    print("wrote", OUT_MODEL, "and", OUT_PARTS)
