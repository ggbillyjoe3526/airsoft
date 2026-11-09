"""Shared helpers for the map models (DM1, 2026-11-09): Depot's and the Practice Range's props, built from code.

A map model is drawn the way the fields' props are (game/play/site/prop_dress.gd): one mesh, its colours on its
vertices, in one vertex-coloured material in the shared light, laid into its block's box by PropLayout, which stretches
the model's bounds to the box (or to a cell of it). So every model here is:

- built in metres, Blender space (+X along the block's long side, +Y across it, +Z up), its bounds the size it is
  meant to be laid at (the layout stretches it a little either way);
- painted with parts: each part a material whose colour (an sRGB hex, written linear as glTF keeps vertex colours) is
  copied onto its vertices, times the part's shade and a soft darkening towards its foot (`FOOT_SHADE`), so a stack
  reads as stacked;
- written as one glb of positions, normals and colours, glTF's +Y up (Blender's +Z), +Z toward the viewer (Blender's
  -Y), with no textures.

Every colour stays off the teams' hues (tests/unit/test_props.gd); metallic is the props' (none). Run the build scripts
with Blender 5.x or pip's `bpy` (pip install bpy==5.2.3); see each script's docstring.
"""

import json
import math
import os
import struct

import bpy  # first: it brings bmesh and mathutils with it
import bmesh
from mathutils import Vector

# How much darker a part is at its lowest point than at its highest (a share of its colour): the soft shade at a
# crate's foot, under a wall's skirting.
FOOT_SHADE = 0.12
# Who made the files, written into each glb.
COPYRIGHT = "airsoft project; made by tools/blender/maps"


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def scaled(colour: int, k: float) -> int:
    """`colour` (0xRRGGBB, sRGB) with each channel scaled by k."""
    return sum(min(255, round(((colour >> sh) & 0xff) * k)) << sh for sh in (16, 8, 0))


def material(colour: int) -> bpy.types.Material:
    """The material of sRGB hex `colour`, made once."""
    name = "c%06x" % colour
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    m = bpy.data.materials.new(name)
    srgb = [((colour >> s) & 255) / 255.0 for s in (16, 8, 0)]
    m.diffuse_color = (*[srgb_to_linear(c) for c in srgb], 1.0)
    m.roughness = 0.8
    return m


def mesh_object(name: str, bm: bmesh.types.BMesh, colour: int, shade: float = 1.0) -> bpy.types.Object:
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(material(colour))
    ob["shade"] = shade
    return ob


def box(name: str, lo: tuple, hi: tuple, colour: int, shade: float = 1.0) -> bpy.types.Object:
    """An axis-aligned box from corner `lo` to corner `hi`."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector([lo[i] + (v.co[i] + 0.5) * (hi[i] - lo[i]) for i in range(3)])
    return mesh_object(name, bm, colour, shade)


def prism(name: str, outline: list, y0: float, y1: float, colour: int, shade: float = 1.0) -> bpy.types.Object:
    """A flat shape `outline` ((x, z) points, counter-clockwise seen from -Y) pushed from y0 to y1 along Y."""
    bm = bmesh.new()
    front = [bm.verts.new((x, y0, z)) for x, z in outline]
    back = [bm.verts.new((x, y1, z)) for x, z in outline]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([front[j], front[i], back[i], back[j]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm, colour, shade)


def turned(ob: bpy.types.Object, degrees_z: float, pivot: tuple = (0.0, 0.0, 0.0)) -> bpy.types.Object:
    """Turns `ob`'s mesh about the Z axis through `pivot`."""
    a = math.radians(degrees_z)
    c, s = math.cos(a), math.sin(a)
    for v in ob.data.vertices:
        x, y = v.co.x - pivot[0], v.co.y - pivot[1]
        v.co.x, v.co.y = pivot[0] + x * c - y * s, pivot[1] + x * s + y * c
    return ob


def mirrored(ob: bpy.types.Object, axis: int, name: str = "") -> bpy.types.Object:
    """A copy of `ob` mirrored across the plane through the origin normal to `axis` (0 x, 1 y, 2 z)."""
    me = ob.data.copy()
    for v in me.vertices:
        v.co[axis] = -v.co[axis]
    me.flip_normals()
    new = bpy.data.objects.new(name or ob.name + "_m", me)
    new["shade"] = ob.get("shade", 1.0)
    bpy.context.scene.collection.objects.link(new)
    return new


def tris(objects: list) -> int:
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objects)


def bounds(objects: list) -> tuple:
    pts = [v.co for o in objects for v in o.data.vertices]
    lo = tuple(min(p[i] for p in pts) for i in range(3))
    hi = tuple(max(p[i] for p in pts) for i in range(3))
    return lo, hi


# ------------------------------------------------------------------------------------------------------------ export

def _gather(objects: list, unit: tuple = None, middle: tuple = None) -> tuple:
    """Triangles of `objects` as glTF rows: positions, normals and colours per corner (flat-shaded hard surfaces:
    every face its own normal), welded where all three match. With `unit` (the model's size, Blender x, y, z), the
    positions are divided by it round the bounds' middle, so the model fills a 1 m cube a game scales back to any
    size (a door's leaf, DoorView), and the normals follow (times the size, normalised). `middle` is the point that
    goes to the cube's middle (the bounds' middle without it); parts past `unit` (a handle) stand out of the cube."""
    positions, normals, colours, indices = [], [], [], []
    mid = [0.0, 0.0, 0.0]
    if unit is not None:
        lo, hi = bounds(objects)
        mid = list(middle) if middle is not None else [(lo[i] + hi[i]) * 0.5 for i in range(3)]
    seen = {}
    for ob in objects:
        me = ob.data
        shade = float(ob.get("shade", 1.0))
        zs = [v.co.z for v in me.vertices]
        z0, z1 = min(zs), max(zs)
        span = max(z1 - z0, 1e-6)
        me.calc_loop_triangles()
        for tri in me.loop_triangles:
            mat = me.materials[me.polygons[tri.polygon_index].material_index]
            base = mat.diffuse_color
            n = tri.normal
            if unit is not None:
                n = Vector((n.x * unit[0], n.y * unit[1], n.z * unit[2])).normalized()
            for vi in tri.vertices:
                co = me.vertices[vi].co
                if unit is not None:
                    co = Vector([(co[i] - mid[i]) / unit[i] for i in range(3)])
                foot = 1.0 - FOOT_SHADE * (1.0 - (me.vertices[vi].co.z - z0) / span)
                k = shade * foot
                row = ((round(co.x, 5), round(co.z, 5), round(-co.y, 5)), (round(n.x, 4), round(n.z, 4),
                       round(-n.y, 4)), (round(base[0] * k, 4), round(base[1] * k, 4), round(base[2] * k, 4), 1.0))
                if row not in seen:
                    seen[row] = len(positions)
                    positions.append(row[0])
                    normals.append(row[1])
                    colours.append(row[2])
                indices.append(seen[row])
    return positions, normals, colours, indices


def export(path: str, name: str, objects: list, unit: tuple = None, middle: tuple = None) -> int:
    """Writes `objects` as one vertex-coloured mesh `name` to the glb at `path` (in a 1 m cube with `unit`, _gather);
    returns its triangle count."""
    positions, normals, colours, indices = _gather(objects, unit, middle)

    def pack(fmt: str, rows: list) -> bytes:
        return b"".join(struct.pack("<" + fmt, *r) for r in rows)

    chunks = [pack("3f", positions), pack("3f", normals), pack("4f", colours),
              struct.pack("<%dI" % len(indices), *indices)]
    views, blob = [], b""
    for c in chunks:
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(c)})
        blob += c + b"\0" * (-len(c) % 4)
    lo = [min(p[i] for p in positions) for i in range(3)]
    hi = [max(p[i] for p in positions) for i in range(3)]
    count = len(positions)
    gltf = {
        "asset": {"version": "2.0", "generator": "airsoft tools/blender/maps", "copyright": COPYRIGHT},
        "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"name": name, "mesh": 0}],
        "meshes": [{"name": name, "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "COLOR_0": 2},
                                                    "indices": 3, "material": 0}]}],
        "materials": [{"name": "vertex_colour", "pbrMetallicRoughness": {"metallicFactor": 0.0,
                                                                         "roughnessFactor": 0.8}}],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": count, "type": "VEC3", "min": lo, "max": hi},
            {"bufferView": 1, "componentType": 5126, "count": count, "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": count, "type": "VEC4"},
            {"bufferView": 3, "componentType": 5125, "count": len(indices), "type": "SCALAR"}],
        "bufferViews": views, "buffers": [{"byteLength": len(blob)}],
    }
    j = json.dumps(gltf, separators=(",", ":")).encode()
    j += b" " * (-len(j) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(blob))
    out += struct.pack("<II", len(j), 0x4E4F534A) + j + struct.pack("<II", len(blob), 0x004E4942) + blob
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(out)
    return len(indices) // 3


# ----------------------------------------------------------------------------------------------------------- picture

def render(path: str, objects: list, views: list, size: tuple = (900, 700)) -> list:
    """Studio pictures of `objects` (Cycles on the CPU, a grey floor, a sun and a soft sky), one a view: each view
    (name, azimuth degrees from the front (-Y), elevation degrees, distance as a share of the model's size). Writes
    `<path>_<name>.png`; returns the files. For the owner's review sheets only: nothing here ships."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    # Paint the vertex colours in the picture: each part's material shows its colour.
    for ob in objects:
        for m in ob.data.materials:
            m.use_nodes = True
            bsdf = m.node_tree.nodes.get("Principled BSDF")
            bsdf.inputs["Base Color"].default_value = m.diffuse_color
            bsdf.inputs["Roughness"].default_value = 0.8
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.76, 0.8, 1.0)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.45
    scene.world = world
    lo, hi = bounds(objects)
    mid = Vector([(lo[i] + hi[i]) * 0.5 for i in range(3)])
    extent = max(hi[i] - lo[i] for i in range(3))
    floor = box("_floor", (mid.x - extent * 6, mid.y - extent * 6, lo[2] - 0.01),
                (mid.x + extent * 6, mid.y + extent * 6, lo[2]), 0x9a9690)
    floor.data.materials[0].use_nodes = True
    floor.data.materials[0].node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.3, 0.29, 0.28, 1.0)
    sun = bpy.data.objects.new("_sun", bpy.data.lights.new("_sun", "SUN"))
    sun.data.energy = 2.2
    sun.data.angle = math.radians(8)
    sun.rotation_euler = (math.radians(40), math.radians(10), math.radians(-35))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam"))
    cam.data.lens = 50
    scene.collection.objects.link(cam)
    scene.camera = cam
    out = []
    for name, az, el, dist in views:
        a, e = math.radians(az), math.radians(el)
        d = extent * dist
        cam.location = mid + Vector((math.sin(a) * math.cos(e) * d, -math.cos(a) * math.cos(e) * d, math.sin(e) * d))
        direction = mid - cam.location
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = "%s_%s.png" % (path, name)
        bpy.ops.render.render(write_still=True)
        out.append(scene.render.filepath)
    bpy.data.objects.remove(floor)
    bpy.data.objects.remove(sun)
    bpy.data.objects.remove(cam)
    return out
