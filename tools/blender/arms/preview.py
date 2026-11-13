"""Quick pictures of a hold as it is solved (HA1): the posed arms and the replica drawn by Cycles from the eye, as the
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


# The hand at rest (`rest_hand`): the picture's size, how much taller than wrist to fingertip it frames, and how far
# off (m) the camera stands.
REST_SIZE = (1100, 1400)
REST_FRAME = 1.45
REST_FROM = 0.5
# `rest_thumb.png`: the thumb's last two bones held out this many degrees from the middle finger's line. The line
# hand_ratios.py measures, from the web to the tip, then lies about 16 degrees further out: the owner's photo holds it
# at hand_ratios.PHOTO_THUMB_ANGLE on that measure.
REST_THUMB = 52.0

# BL_PREVIEW_HAND=L or R: the outside views look at that hand alone (a rifle's support hand is far from the other).
LOOK_AT = os.environ.get("BL_PREVIEW_HAND", "")


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
         views: tuple = VIEWS, eye: Vector = None) -> None:
    """The hold posed now, as `name`: from the eye at the hip (at `eye`, where the game draws the replica somewhere
    other than where its hold is solved; else the origin), from the eye aimed (the eye on the replica's rear sight
    line, the replica `aim_forward` m ahead), and from outside round each hand."""
    os.makedirs(folder, exist_ok=True)
    rig.write()
    swapped = [o for o in bpy.context.scene.objects
               if o.name.startswith(SHOW if o.hide_render else HIDE) and (SHOW if o.hide_render else HIDE)]
    for o in swapped:
        o.hide_render = not o.hide_render
    if "hip" in views:
        hip = eye if eye is not None else Vector((0.0, 0.0, 0.0))
        shot(os.path.join(folder, "%s_hip.jpg" % name), hip, hip + Vector((0.0, 1.0, 0.0)))
    rear = next((o for o in objects if o.name.split(".")[0] == "RearSight"), None)
    if "aim" in views and rear is not None:
        sight = rear.matrix_world.translation
        origin = to_eye.translation
        aimed = Vector((sight.x, origin.y - aim_forward, sight.z))
        shot(os.path.join(folder, "%s_aim.jpg" % name), aimed, aimed + Vector((0.0, 1.0, 0.0)))
    # Each hand's middle: between its wrist and its middle finger's knuckle.
    right, left = ((rig.pose["Hand_" + s].translation + rig.pose["Middle1_" + s].translation) * 0.5 for s in "RL")
    # Round both hands when they hold together, else the right one.
    look = (right + left) * 0.5 if (right - left).length < 0.3 else right.copy()
    if LOOK_AT in ("L", "R"):
        look = left if LOOK_AT == "L" else right
    for view, off in OUTSIDE.items():
        if view in views:
            shot(os.path.join(folder, "%s_%s.jpg" % (name, view)), look + off * NEAR, look, OUTSIDE_FOV)
    for o in swapped:
        o.hide_render = not o.hide_render


def _thumb_out(rig, side: str, up: Vector, normal: Vector) -> None:
    """Turns the resting thumb at its root so its last two bones' line lies flat in the hand's plane, REST_THUMB
    degrees out from the middle finger's line."""
    first, last = "Thumb1_" + side, "Thumb3_" + side
    knuckle = rig.pose["Thumb2_" + side].translation
    m = rig.pose[last]
    tip = m.translation + m.to_3x3().col[1] * rig.length[last]
    now = (tip - knuckle).normalized()
    out = knuckle - rig.pose["Hand_" + side].translation
    out = (out - up * out.dot(up) - normal * out.dot(normal)).normalized()
    to = up * math.cos(math.radians(REST_THUMB)) + out * math.sin(math.radians(REST_THUMB))
    rest = rig.rest[first].to_3x3()
    rig.fk(first, rest.inverted() @ now.rotation_difference(to).to_matrix() @ rest)
    rig.refresh(first)
    rig.write()


def rest_hand(folder: str, rig, gloved: list, bare: list, side: str = "L") -> None:
    """The bare hand of `side` as the model rests it, flat from its back and from its palm (no perspective, the
    middle finger up, clear behind), as `rest_back.png` and `rest_palm.png` in `folder`, and from its back with the
    thumb held out as the photo's (`rest_thumb.png`): the framing of the owner's
    photo of a hand, for measuring the model's proportions against it (tools/blender/arms/README, HA1). `gloved`
    are the objects left out of the picture, `bare` the ones put in."""
    os.makedirs(folder, exist_ok=True)
    rig.write()
    kept = {o: o.hide_render for o in gloved + bare}
    for o in gloved:
        o.hide_render = True
    for o in bare:
        o.hide_render = not o.name.endswith("_" + side)
    wrist = rig.pose["Hand_" + side].translation
    knuckle = rig.pose["Middle1_" + side].translation
    last = rig.pose["Middle3_" + side]
    tip = last.translation + last.to_3x3().col[1] * rig.length["Middle3_" + side]
    up = (knuckle - wrist).normalized()
    across = rig.pose["Index1_" + side].translation - rig.pose["Pinky1_" + side].translation
    normal = up.cross(across).normalized()
    middle = (wrist + tip) * 0.5
    scene = bpy.context.scene
    lamps = _lights()
    for name, way in (("back", -normal), ("palm", normal), ("thumb", -normal)):
        if name == "thumb":
            # The thumb held out flat to the side as the owner's photo holds it (REST_THUMB degrees from the middle
            # finger's line), so its length can be measured there (hand_ratios.py ... thumb).
            _thumb_out(rig, side, up, normal)
        data = bpy.data.cameras.new("Rest")
        data.type = "ORTHO"
        data.ortho_scale = (tip - wrist).length * REST_FRAME
        data.clip_start, data.clip_end = 0.01, 5.0
        cam = bpy.data.objects.new("Rest", data)
        scene.collection.objects.link(cam)
        side_way = up.cross(way).normalized()
        cam.matrix_world = Matrix.Translation(middle + way * REST_FROM) @ Matrix(
            (side_way, up, way)).transposed().to_4x4()
        scene.camera = cam
        scene.render.engine = "CYCLES"
        scene.cycles.device = "CPU"
        scene.cycles.samples = SAMPLES
        scene.cycles.use_denoising = True
        scene.render.film_transparent = True
        # The thumb held out needs a square picture (the same scale: the taller side sets it).
        scene.render.resolution_x, scene.render.resolution_y = (REST_SIZE[1], REST_SIZE[1]) if name == "thumb" \
            else REST_SIZE
        scene.render.resolution_percentage = 100
        scene.render.image_settings.file_format = "PNG"
        scene.render.image_settings.color_mode = "RGBA"
        scene.render.filepath = os.path.join(folder, "rest_%s.png" % name)
        scene.view_settings.view_transform = "Standard"
        bpy.ops.render.render(write_still=True)
        scene.camera = None
        bpy.data.objects.remove(cam, do_unlink=True)
        bpy.data.cameras.remove(data)
    scene.render.film_transparent = False
    rig.fk("Thumb1_" + side)
    rig.refresh("Thumb1_" + side)
    rig.write()
    for ob in lamps:
        data = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        bpy.data.lights.remove(data)
    for o, was in kept.items():
        o.hide_render = was
