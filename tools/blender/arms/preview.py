"""Quick pictures of a hold as it is solved (FP1): the posed arms and the replica drawn by Cycles from the eye, as the
game frames them (ViewConfig's field of view, 16:9), and from outside. A build aid: `arms.py` calls `hold` after each
solve when BL_PREVIEW names a folder, so a hold can be judged in a minute without exporting and importing the model.
Nothing here reaches the exported file."""

import math
import os

import bpy
from mathutils import Matrix, Vector

# The game's eye camera: 90 degrees across at 16:9 (ViewConfig.horizontal_fov_16x9).
FOV_ACROSS = math.radians(90.0)
SIZE = (960, 540)
SAMPLES = int(os.environ.get("BL_PREVIEW_SAMPLES", "24"))
# Outside views: the camera's place from what it looks at (eye space: +X right, +Y forward, +Z up; m).
OUTSIDE = {"left": Vector((-0.45, -0.05, 0.10)), "right": Vector((0.45, -0.05, 0.10)),
           "front": Vector((-0.12, 0.45, 0.12)), "under": Vector((-0.15, -0.10, -0.42)),
           "top": Vector((-0.02, -0.12, 0.45)), "behind": Vector((-0.16, -0.40, 0.20)),
           "ahead": Vector((0.30, 0.34, 0.06))}
OUTSIDE_FOV = math.radians(48.0)
# BL_PREVIEW_VIEWS=<view>,... draws those views alone; BL_PREVIEW_NEAR=<share> brings the outside views that much
# nearer (0.5: half as far, for a close look at a finger).
VIEWS = tuple(v for v in os.environ.get("BL_PREVIEW_VIEWS", "hip,aim,left,right,front,under,top").split(",") if v)
NEAR = float(os.environ.get("BL_PREVIEW_NEAR", "1"))
# BL_PREVIEW_HIDE=<prefix>,... leaves the objects so named out of the pictures and BL_PREVIEW_SHOW=<prefix>,... puts
# in those the build keeps out of them (HIDE=Arm_ SHOW=Skin_,Nails_: the bare hands).
HIDE = tuple(v for v in os.environ.get("BL_PREVIEW_HIDE", "").split(",") if v)
SHOW = tuple(v for v in os.environ.get("BL_PREVIEW_SHOW", "").split(",") if v)


def _camera(at: Vector, toward: Vector, fov_across: float) -> bpy.types.Object:
    data = bpy.data.cameras.new("Preview")
    data.sensor_fit = "HORIZONTAL"
    data.angle = fov_across
    data.clip_start, data.clip_end = 0.01, 50.0
    cam = bpy.data.objects.new("Preview", data)
    bpy.context.scene.collection.objects.link(cam)
    fwd = (toward - at).normalized()
    side = fwd.cross(Vector((0.0, 0.0, 1.0))).normalized()
    up = side.cross(fwd)
    # A camera looks along its -Z, +Y up.
    rot = Matrix((side, up, -fwd)).transposed()
    cam.matrix_world = Matrix.Translation(at) @ rot.to_4x4()
    return cam


def _lights() -> list:
    out = []
    for name, way, power in (("Key", Vector((-0.4, -0.5, 1.0)), 3.0), ("Fill", Vector((0.6, -0.3, 0.2)), 1.0)):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = power
        data.angle = math.radians(20.0)
        lamp = bpy.data.objects.new(name, data)
        bpy.context.scene.collection.objects.link(lamp)
        lamp.matrix_world = way.to_track_quat("Z", "Y").to_matrix().to_4x4()
        out.append(lamp)
    world = bpy.context.scene.world or bpy.data.worlds.new("Preview")
    bpy.context.scene.world = world
    world.use_nodes = True
    back = world.node_tree.nodes.get("Background")
    if back is not None:
        back.inputs[0].default_value = (0.55, 0.57, 0.6, 1.0)
        back.inputs[1].default_value = 1.0
    return out


def shot(path: str, at: Vector, toward: Vector, fov_across: float = FOV_ACROSS) -> None:
    """One picture from `at` looking `toward` (eye space) to `path`."""
    scene = bpy.context.scene
    cam = _camera(at, toward, fov_across)
    lamps = _lights()
    scene.camera = cam
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = SIZE
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "JPEG"
    scene.render.image_settings.quality = 88
    scene.render.filepath = path
    scene.view_settings.view_transform = "Standard"
    bpy.ops.render.render(write_still=True)
    scene.camera = None
    for ob in [cam] + lamps:
        data = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        if isinstance(data, bpy.types.Camera):
            bpy.data.cameras.remove(data)
        else:
            bpy.data.lights.remove(data)


def hold(folder: str, name: str, to_eye: Matrix, rig, objects: list, aim_forward: float = 0.25,
         views: tuple = VIEWS) -> None:
    """The hold posed now, as `name`: from the eye at the hip, from the eye aimed (the eye on the replica's rear sight
    line, the replica `aim_forward` m ahead), and from outside round each hand."""
    os.makedirs(folder, exist_ok=True)
    rig.write()
    swapped = [o for o in bpy.context.scene.objects
               if o.name.startswith(SHOW if o.hide_render else HIDE) and (SHOW if o.hide_render else HIDE)]
    for o in swapped:
        o.hide_render = not o.hide_render
    if "hip" in views:
        shot(os.path.join(folder, "%s_hip.jpg" % name), Vector((0.0, 0.0, 0.0)), Vector((0.0, 1.0, 0.0)))
    rear = next((o for o in objects if o.name.split(".")[0] == "RearSight"), None)
    if "aim" in views and rear is not None:
        sight = rear.matrix_world.translation
        origin = to_eye.translation
        eye = Vector((sight.x, origin.y - aim_forward, sight.z))
        shot(os.path.join(folder, "%s_aim.jpg" % name), eye, eye + Vector((0.0, 1.0, 0.0)))
    # Each hand's middle: between its wrist and its middle finger's knuckle.
    right, left = ((rig.pose["Hand_" + s].translation + rig.pose["Middle1_" + s].translation) * 0.5 for s in "RL")
    # Round both hands when they hold together, else the right one.
    look = (right + left) * 0.5 if (right - left).length < 0.3 else right.copy()
    for view, off in OUTSIDE.items():
        if view in views:
            shot(os.path.join(folder, "%s_%s.jpg" % (name, view)), look + off * NEAR, look, OUTSIDE_FOV)
    for o in swapped:
        o.hide_render = not o.hide_render
