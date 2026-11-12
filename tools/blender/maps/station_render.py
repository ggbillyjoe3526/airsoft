"""Renders Subway's lamps and extras (SM5) for the owner's review: each built .glb from labelled angles, its vertex
colours in the shared light, its `Lens` glowing and its `Sign` faces printed from the sign sheet, into one picture.

Usage: python3 -I tools/blender/maps/station_render.py <out.jpg> "<title>" <name[:view,view]> ... <repo root>
Views: front, quarter, side, below, rear, top (default: front quarter side). Dev tool: tools/ never ships.
"""

import math
import os
import sys

import bpy
from mathutils import Vector
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = sys.argv[-1] if os.path.isdir(sys.argv[-1]) else os.path.normpath(os.path.join(HERE, "..", "..", ".."))
PROPS = os.path.join(ROOT, "assets", "models", "props")
SHEET = os.path.join(ROOT, "assets", "textures", "station", "signs.png")
PANEL = (640, 520)
VIEWS = {
    "front": (0.0, 6.0, "front"), "quarter": (-38.0, 16.0, "front quarter"), "side": (-90.0, 4.0, "side"),
    "below": (-20.0, -55.0, "from below"), "rear": (150.0, 14.0, "rear quarter"), "top": (-30.0, 55.0, "from above"),
    "back": (180.0, 6.0, "back"), "level": (0.0, 0.0, "front, level"), "low": (-38.0, -30.0, "front quarter from below"),
}


def materials() -> dict:
    prop = bpy.data.materials.new("vc")
    prop.use_nodes = True
    nt = prop.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    lens = bpy.data.materials.new("lens")
    lens.use_nodes = True
    b = lens.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (1.0, 0.95, 0.85, 1.0)
    b.inputs["Emission Color"].default_value = (1.0, 0.93, 0.8, 1.0)
    b.inputs["Emission Strength"].default_value = 6.0
    sign = bpy.data.materials.new("sign")
    sign.use_nodes = True
    nt = sign.node_tree
    b = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(SHEET)
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.55
    return {"Prop": prop, "Lens": lens, "Sign": sign}


def setup(glb: str) -> list:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    mats = materials()
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in obs:
        for i, slot in enumerate(o.material_slots):
            name = slot.material.name.split(".")[0] if slot.material else "Prop"
            o.material_slots[i].material = mats.get(name, mats["Prop"])
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 40
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = PANEL
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.5, 0.5, 0.52, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    sc.world = world
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 2.6
    sun.angle = math.radians(10)
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(50), 0.0, math.radians(-30))
    sc.collection.objects.link(so)
    return obs


def bounds(obs: list) -> tuple:
    pts = [o.matrix_world @ Vector(c) for o in obs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def shoot(obs: list, view: str, out: str) -> None:
    yaw, pitch, _ = VIEWS[view]
    lo, hi = bounds(obs)
    mid = (lo + hi) * 0.5
    size = (hi - lo).length
    cam = bpy.data.cameras.new("cam")
    cam.lens = 50
    co = bpy.data.objects.new("cam", cam)
    bpy.context.scene.collection.objects.link(co)
    y, p = math.radians(yaw), math.radians(pitch)
    d = size * 2.1
    # the model's front is Blender's -Y
    co.location = mid + Vector((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p))) * d
    co.rotation_euler = (mid - co.location).to_track_quat("-Z", "Y").to_euler()
    cam.clip_start = size * 0.01
    cam.clip_end = size * 10
    bpy.context.scene.camera = co
    bpy.context.scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(co, do_unlink=True)


def main() -> None:
    args = [a for a in sys.argv[1:] if a != ROOT]
    out, title, items = args[0], args[1], args[2:]
    tmp = os.path.join(os.path.dirname(os.path.abspath(out)), "_station_render")
    os.makedirs(tmp, exist_ok=True)
    rows = []
    for item in items:
        name, _, views = item.partition(":")
        views = views.split(",") if views else ["front", "quarter", "side"]
        obs = setup(os.path.join(PROPS, name + ".glb"))
        tris = sum(len(p.vertices) - 2 for o in obs for p in o.data.polygons)
        lo, hi = bounds(obs)
        size = hi - lo
        shots = []
        for v in views:
            path = os.path.join(tmp, "%s_%s.png" % (name, v))
            shoot(obs, v, path)
            shots.append((VIEWS[v][2], path))
        rows.append((name, tris, (size.x, size.z, size.y), shots))
    cols = max(len(r[3]) for r in rows)
    head = 44
    sheet = Image.new("RGB", (PANEL[0] * cols, head + len(rows) * (PANEL[1] + 34)), (34, 34, 38))
    d = ImageDraw.Draw(sheet)
    try:
        big = ImageFont.truetype("DejaVuSans-Bold.ttf", 24)
        small = ImageFont.truetype("DejaVuSans.ttf", 17)
    except OSError:
        big = small = ImageFont.load_default()
    d.text((12, 10), title, fill=(240, 240, 240), font=big)
    for r, (name, tris, size, shots) in enumerate(rows):
        y = head + r * (PANEL[1] + 34)
        d.text((12, y + 7), "%s  ·  %d triangles  ·  %.2f x %.2f x %.2f m (wide x tall x deep)" % (
            name, tris, size[0], size[1], size[2]), fill=(250, 220, 120), font=small)
        for c, (label, path) in enumerate(shots):
            im = Image.open(path).convert("RGB")
            sheet.paste(im, (c * PANEL[0], y + 34))
            d.text((c * PANEL[0] + 10, y + 40), label, fill=(255, 255, 255), font=small)
    sheet.save(out, quality=88)
    print(out)


if __name__ == "__main__":
    main()
