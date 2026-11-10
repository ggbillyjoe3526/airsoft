"""Review pictures of the range's models (RM1): each built model rendered in Cycles from a few views on a grey floor,
its corner colours as the game draws them, and the views put on one labelled sheet. Dev tool: tools/ never ships.

render_sheet(objects, views, out, title) renders `objects` as they stand in the scene; each view is (label, camera
position, look-at point, lens mm).
"""

import math
import os

import bpy
from mathutils import Vector
from PIL import Image, ImageDraw, ImageFont


def _prop_material() -> None:
    m = bpy.data.materials.get("Prop")
    if m is None:
        return
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    if any(n.type == "ATTRIBUTE" for n in nt.nodes):
        return
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "Color"
    nt.links.new(at.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.7


def _stage(floor: bool) -> None:
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 24
    sc.cycles.use_denoising = True
    sc.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.62, 0.68, 0.78, 1.0)
    bg.inputs["Strength"].default_value = 0.9
    if bpy.data.objects.get("Sun") is None:
        sun = bpy.data.lights.new("Sun", "SUN")
        sun.energy = 3.2
        sun.angle = math.radians(4.0)
        ob = bpy.data.objects.new("Sun", sun)
        sc.collection.objects.link(ob)
        ob.rotation_euler = (math.radians(50.0), math.radians(10.0), math.radians(-35.0))
    if floor and bpy.data.objects.get("Floor") is None:
        bpy.ops.mesh.primitive_plane_add(size=400.0, location=(0.0, 0.0, -0.0005))
        fl = bpy.context.active_object
        fl.name = "Floor"
        mat = bpy.data.materials.new("FloorMat")
        mat.use_nodes = True
        mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.20, 0.19, 0.18, 1.0)
        fl.data.materials.append(mat)


def render_sheet(views: list, out: str, title: str, size: tuple = (640, 480), floor: bool = True,
                 cols: int = 3) -> None:
    _prop_material()
    _stage(floor)
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.resolution_percentage = 100
    cam_data = bpy.data.cameras.get("Cam") or bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.get("Cam") or bpy.data.objects.new("Cam", cam_data)
    if cam.name not in sc.collection.objects:
        sc.collection.objects.link(cam)
    sc.camera = cam
    shots = []
    tmp = out + ".part.png"
    for label, pos, look, lens in views:
        cam.location = Vector(pos)
        d = Vector(look) - Vector(pos)
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        cam_data.lens = lens
        cam_data.clip_start = 0.01
        sc.render.filepath = tmp
        bpy.ops.render.render(write_still=True)
        shots.append((label, Image.open(tmp).convert("RGB")))
    os.remove(tmp)
    w, h = size
    rows = (len(shots) + cols - 1) // cols
    head = 44
    sheet = Image.new("RGB", (w * min(cols, len(shots)), h * rows + head), (24, 24, 28))
    dr = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 22)
        small = ImageFont.truetype("DejaVuSans.ttf", 17)
    except OSError:
        font = small = ImageFont.load_default()
    dr.text((12, 10), title, fill=(240, 240, 240), font=font)
    for i, (label, im) in enumerate(shots):
        x, y = (i % cols) * w, head + (i // cols) * h
        sheet.paste(im, (x, y))
        dr.rectangle((x, y, x + dr.textlength(label, font=small) + 16, y + 26), fill=(0, 0, 0))
        dr.text((x + 8, y + 3), label, fill=(255, 255, 255), font=small)
    sheet.save(out, quality=88)
