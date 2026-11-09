"""Renders a built prop (.glb from assets/models/props/) from labelled angles into one picture, for the owner's review
before a pull request (RK1). Shows the exported file itself: its vertex colours, its normals.

Usage: python3 tools/blender/maps/render_prop.py <name.glb> <out.jpg> "<title>" [view ...]
Views: front, quarter, side, back, rear, top, low (default: front quarter side rear). Dev tool: tools/ never ships.
"""
import math
import os
import sys

import bpy
from mathutils import Vector
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PROPS = os.path.normpath(os.path.join(HERE, "..", "..", "..", "assets", "models", "props"))
PANEL = (900, 700)

# yaw (degrees, 0 = looking at the front, the model's -Y in Blender) and pitch (degrees down)
VIEWS = {
    "front": (0.0, 8.0, "front"), "quarter": (-35.0, 18.0, "front quarter"), "side": (-90.0, 6.0, "side"),
    "back": (180.0, 8.0, "back"), "rear": (145.0, 18.0, "rear quarter"), "top": (-30.0, 55.0, "from above"),
    "low": (-25.0, -4.0, "crouched eye level"),
}


def setup(glb: str) -> list:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    mat = bpy.data.materials.new("vc")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.7
    for o in obs:
        o.data.materials.clear()
        o.data.materials.append(mat)
        if o.data.color_attributes:
            attr.layer_name = o.data.color_attributes[0].name
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = PANEL
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.62, 0.64, 0.7, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    sc.world = world
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.2
    sun.angle = math.radians(8)
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(50), 0.0, math.radians(-35))
    sc.collection.objects.link(so)
    # a floor to ground it
    bpy.ops.mesh.primitive_plane_add(size=60.0, location=(0, 0, 0))
    floor = bpy.context.active_object
    fm = bpy.data.materials.new("floor")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.42, 0.40, 0.38, 1.0)
    floor.data.materials.append(fm)
    return obs


def bounds(obs: list) -> tuple:
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for o in obs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def render(obs: list, view: str, path: str) -> None:
    yaw, pitch, _ = VIEWS[view]
    lo, hi = bounds(obs)
    centre = (lo + hi) / 2
    radius = (hi - lo).length / 2
    cam = bpy.data.cameras.new("cam")
    cam.lens = 50
    co = bpy.data.objects.new("cam", cam)
    bpy.context.scene.collection.objects.link(co)
    dist = radius / math.tan(math.radians(17.0)) * 1.05
    y, p = math.radians(yaw), math.radians(pitch)
    d = Vector((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p)))
    co.location = centre + d * dist
    co.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = co
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(co)


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    glb, out, title = args[0], args[1], args[2]
    views = args[3:] or ["front", "quarter", "side", "rear"]
    obs = setup(os.path.join(PROPS, glb) if not os.path.isabs(glb) else glb)
    tmp = os.path.splitext(out)[0]
    panels = []
    for v in views:
        p = f"{tmp}_{v}.png"
        render(obs, v, p)
        panels.append((Image.open(p).convert("RGB"), VIEWS[v][2]))
        os.remove(p)
    cols = min(len(panels), 2)
    rows = (len(panels) + cols - 1) // cols
    head = 70
    sheet = Image.new("RGB", (PANEL[0] * cols, PANEL[1] * rows + head), (250, 250, 250))
    dr = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 34)
        small = ImageFont.truetype("DejaVuSans-Bold.ttf", 28)
    except OSError:
        font = small = ImageFont.load_default()
    dr.text((20, 16), title, fill=(20, 20, 30), font=font)
    for i, (im, label) in enumerate(panels):
        x, y = (i % cols) * PANEL[0], head + (i // cols) * PANEL[1]
        sheet.paste(im, (x, y))
        dr.rectangle((x, y, x + 12 + len(label) * 17, y + 44), fill=(20, 20, 30))
        dr.text((x + 8, y + 6), label, fill=(255, 255, 255), font=small)
    sheet.save(out, quality=88)
    print("wrote", out)


main()
