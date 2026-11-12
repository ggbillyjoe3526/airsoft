"""Shared helpers for the map models (DM1, 2026-11-09): Depot's and the Practice Range's props, built from code.

A map model is drawn the way the fields' props are (game/play/site/prop_dress.gd): one mesh, its colours on its
vertices, in one vertex-coloured material in the shared light, laid into its block's box by PropLayout, which stretches
the model's bounds to the box (or to a cell of it). So every model here is:

- built in metres, Blender space (+X along the block's long side, +Y across it, +Z up), its bounds the size it is
  meant to be laid at (the layout stretches it a little either way);
- painted with parts: each part a material whose colour (an sRGB hex, written linear as glTF keeps vertex colours) is
  copied onto its vertices, times the part's shade and a soft darkening towards its foot (`FOOT_SHADE`), so a stack
  reads as stacked;
- shaded within a part where it carries a `tone` (`toned`): a share of its colour on each vertex, so soft grain fades
  in and out across a face with no edge to it;
- perforated where a part is marked `perforated`: its vertices carry UVs (x 2 plus metres across the row's middle, y
  metres along it) that look_vertex.gdshader punches a row of holes into, so a steel profile's dense holes cost no
  triangles; or ribbed (`ribbed`: x -2, y metres across the ribs), grooved finely the same way (an escalator's steps);
- written as one glb of positions, normals and colours (and UVs when a part is perforated), glTF's +Y up (Blender's
  +Z), +Z toward the viewer (Blender's -Y), with no textures.

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
# A perforated strip's holes (`perforated`): their pitch along it and radius, metres; look_vertex.gdshader's
# perforation_pitch and perforation_radius keep the same.
PERF_PITCH = 0.045
PERF_RADIUS = 0.0045
# A ribbed part's ribs (`ribbed`): their pitch, metres; look_vertex.gdshader's rib_pitch keeps the same.
RIB_PITCH = 0.0085
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


def bare(ob: bpy.types.Object) -> bpy.types.Object:
    """Marks `ob` as never painted: its vertex alpha 0, so the game's paint (a container's, PropDress's custom data in
    look_vertex.gdshader) leaves it its own colour, bare steel or rubber. Every other part's alpha is 1."""
    ob["bare"] = True
    return ob


def toned(ob: bpy.types.Object, tones: list) -> bpy.types.Object:
    """Gives each of `ob`'s vertices, in order, a share of its colour (`tones`): soft shading within the part."""
    layer = ob.data.attributes.new("tone", "FLOAT", "POINT")
    for i, t in enumerate(tones):
        layer.data[i].value = t
    return ob


def ribbed(ob: bpy.types.Object, across: int) -> bpy.types.Object:
    """Marks `ob` for fine ribs running square to its axis `across` (0 x, 1 y, 2 z), RIB_PITCH apart:
    look_vertex.gdshader grooves them from the UVs `_gather` writes (x -2, y metres along `across`), an escalator
    step's cleats for no triangles."""
    ob["ribs"] = int(across)
    return ob


def smoothed(ob: bpy.types.Object, sharp_deg: float = 40.0) -> bpy.types.Object:
    """Draws `ob` with rounded normals: Blender's corner normals, sharp only across edges bent more than `sharp_deg`
    (a handrail's round back smooth, its lips crisp). Every other part is flat-shaded, each face its own normal."""
    ob.data.shade_smooth()
    ob.data.set_sharp_from_angle(angle=math.radians(sharp_deg))
    ob["smooth"] = True
    return ob


def foot_span(ob: bpy.types.Object, z0: float, z1: float) -> bpy.types.Object:
    """Shades `ob`'s foot over z0 to z1 instead of its own height (FOOT_SHADE), so a mark laid on a part shades as the
    part under it does and shows no edge."""
    ob["foot"] = (z0, z1)
    return ob


def perforated(ob: bpy.types.Object, across: int, along: int, middle: float) -> bpy.types.Object:
    """Marks `ob` (a flat strip) for a row of holes down its axis `along` (0 x, 1 y, 2 z), centred on `middle` along
    its axis `across`: look_vertex.gdshader draws them from the UVs `_gather` writes."""
    ob["perf"] = True
    ob["perf_axes"] = [int(across), int(along)]
    ob["perf_middle"] = float(middle)
    return ob


def band(name: str, c: float, w: float, bend: float, z0: float, z1: float, plane: float, axis: int, facing: int,
         colour: int, foot: tuple, dark: float) -> bpy.types.Object:
    """A soft grain band on a face: a lens from z0 to z1, `w` wide at its widest, its middle `c` across the face
    bending `bend` over its length, its middle line `dark` of its colour fading to the colour's own at its
    edges and tips, so it has no edge. On the plane `plane` of axis `axis` (0: a face across x, 1: across y), facing
    `facing` along it."""
    zs = (z0, z0 + (z1 - z0) * 0.3, z0 + (z1 - z0) * 0.68, z1)
    offs = (0.0, bend, bend * 0.4, -bend * 0.3)
    widths = (0.0, w, w * 0.8, 0.0)
    pts, tones = [], []
    for z, o, ww in zip(zs, offs, widths):
        row = [(c + o, z)] if ww == 0.0 else [(c + o - ww / 2, z), (c + o, z), (c + o + ww / 2, z)]
        pts.append(row)
        tones += [1.0] if ww == 0.0 else [1.0, dark, 1.0]
    bm = bmesh.new()

    def at(a: float, z: float) -> tuple:
        return (plane, a, z) if axis == 0 else (a, plane, z)
    rows = [[bm.verts.new(at(a, z)) for a, z in row] for row in pts]
    tip0, mid0, mid1, tip1 = rows
    bm.faces.new([tip0[0], mid0[2], mid0[1]])
    bm.faces.new([tip0[0], mid0[1], mid0[0]])
    for k in range(2):
        bm.faces.new([mid0[k], mid0[k + 1], mid1[k + 1], mid1[k]])
    bm.faces.new([tip1[0], mid1[0], mid1[1]])
    bm.faces.new([tip1[0], mid1[1], mid1[2]])
    ob = mesh_object(name, bm, colour)
    ob.data.update()
    for p in ob.data.polygons:
        if (p.normal[axis] > 0) != (facing > 0):
            p.flip()
    ob.data.update()
    toned(ob, tones)
    return foot_span(ob, *foot)


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


def hide(ob: bpy.types.Object, hidden: tuple) -> bpy.types.Object:
    """Drops `ob`'s faces whose normals point along any of `hidden` ("+x", "-z"...): the faces nobody sees (against
    another part, the floor or a wall), so the budget goes on what shows."""
    if hidden:
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        drop = [f for f in bm.faces if any(
            f.normal["xyz".index(h[1])] * (1 if h[0] == "+" else -1) > 0.9 for h in hidden)]
        bmesh.ops.delete(bm, geom=drop, context="FACES")
        bm.to_mesh(ob.data)
        bm.free()
    return ob


def open_box(name: str, lo: tuple, hi: tuple, colour: int, hidden: tuple, shade: float = 1.0) -> bpy.types.Object:
    """A box without its faces in `hidden` (hide)."""
    return hide(box(name, lo, hi, colour, shade), hidden)


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
    positions, normals, colours, uvs, indices = [], [], [], [], []
    mid = [0.0, 0.0, 0.0]
    if unit is not None:
        lo, hi = bounds(objects)
        mid = list(middle) if middle is not None else [(lo[i] + hi[i]) * 0.5 for i in range(3)]
    seen = {}
    for ob in objects:
        me = ob.data
        shade = float(ob.get("shade", 1.0))
        alpha = 0.0 if ob.get("bare", False) else 1.0
        zs = [v.co.z for v in me.vertices]
        z0, z1 = ob["foot"] if "foot" in ob else (min(zs), max(zs))
        span = max(z1 - z0, 1e-6)
        tone = me.attributes.get("tone")
        perf = (int(ob["perf_axes"][0]), int(ob["perf_axes"][1]), ob["perf_middle"]) if "perf" in ob else None
        ribs = int(ob["ribs"]) if "ribs" in ob else None
        smooth = bool(ob.get("smooth", False))
        me.calc_loop_triangles()
        for tri in me.loop_triangles:
            mat = me.materials[me.polygons[tri.polygon_index].material_index]
            base = mat.diffuse_color
            for corner, vi in enumerate(tri.vertices):
                # A smooth part (`smoothed`) keeps Blender's corner normals (round where its edges aren't sharp).
                n = Vector(tri.split_normals[corner]) if smooth else tri.normal
                if unit is not None:
                    n = Vector((n.x * unit[0], n.y * unit[1], n.z * unit[2])).normalized()
                co = me.vertices[vi].co
                if unit is not None:
                    co = Vector([(co[i] - mid[i]) / unit[i] for i in range(3)])
                foot = 1.0 - FOOT_SHADE * (1.0 - (me.vertices[vi].co.z - z0) / span)
                k = shade * foot * (tone.data[vi].value if tone is not None else 1.0)
                own = me.vertices[vi].co
                uv = (round(2.0 + own[perf[0]] - perf[2], 5), round(own[perf[1]], 5)) if perf else (0.0, 0.0)
                if ribs is not None:
                    uv = (-2.0, round(own[ribs], 5))
                row = ((round(co.x, 5), round(co.z, 5), round(-co.y, 5)), (round(n.x, 4), round(n.z, 4),
                       round(-n.y, 4)), (round(base[0] * k, 4), round(base[1] * k, 4), round(base[2] * k, 4), alpha),
                       uv)
                if row not in seen:
                    seen[row] = len(positions)
                    positions.append(row[0])
                    normals.append(row[1])
                    colours.append(row[2])
                    uvs.append(row[3])
                indices.append(seen[row])
    return positions, normals, colours, uvs, indices


def export(path: str, name: str, objects: list, unit: tuple = None, middle: tuple = None) -> int:
    """Writes `objects` as one vertex-coloured mesh `name` to the glb at `path` (in a 1 m cube with `unit`, _gather);
    returns its triangle count. The UVs (TEXCOORD_0) are written only when a part is perforated or ribbed."""
    positions, normals, colours, uvs, indices = _gather(objects, unit, middle)
    with_uv = any("perf" in ob or "ribs" in ob for ob in objects)

    def pack(fmt: str, rows: list) -> bytes:
        return b"".join(struct.pack("<" + fmt, *r) for r in rows)

    chunks = [pack("3f", positions), pack("3f", normals), pack("4f", colours),
              struct.pack("<%dI" % len(indices), *indices)]
    if with_uv:
        chunks.append(pack("2f", uvs))
    views, blob = [], b""
    for c in chunks:
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(c)})
        blob += c + b"\0" * (-len(c) % 4)
    lo = [min(p[i] for p in positions) for i in range(3)]
    hi = [max(p[i] for p in positions) for i in range(3)]
    count = len(positions)
    attributes = {"POSITION": 0, "NORMAL": 1, "COLOR_0": 2}
    if with_uv:
        attributes["TEXCOORD_0"] = 4
    gltf = {
        "asset": {"version": "2.0", "generator": "airsoft tools/blender/maps", "copyright": COPYRIGHT},
        "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"name": name, "mesh": 0}],
        "meshes": [{"name": name, "primitives": [{"attributes": attributes, "indices": 3, "material": 0}]}],
        "materials": [{"name": "vertex_colour", "pbrMetallicRoughness": {"metallicFactor": 0.0,
                                                                         "roughnessFactor": 0.8}}],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": count, "type": "VEC3", "min": lo, "max": hi},
            {"bufferView": 1, "componentType": 5126, "count": count, "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": count, "type": "VEC4"},
            {"bufferView": 3, "componentType": 5125, "count": len(indices), "type": "SCALAR"}]
        + ([{"bufferView": 4, "componentType": 5126, "count": count, "type": "VEC2"}] if with_uv else []),
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

def render(path: str, objects: list, views: list, size: tuple = (900, 700), paint: int = None) -> list:
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
    # Paint the vertex colours in the picture: each part's material shows its colour, times `paint` (as the game
    # paints a container) unless the part is bare.
    tint = [srgb_to_linear(((paint >> sh) & 0xff) / 255.0) for sh in (16, 8, 0)] if paint is not None else None
    for ob in objects:
        toned_part = ob.data.attributes.get("tone") is not None
        for i, m in enumerate(ob.data.materials):
            if (tint is not None and not ob.get("bare", False)) or toned_part:
                m = m.copy()
                if tint is not None and not ob.get("bare", False):
                    m.diffuse_color = [m.diffuse_color[c] * tint[c] for c in range(3)] + [1.0]
                ob.data.materials[i] = m
            m.use_nodes = True
            bsdf = m.node_tree.nodes.get("Principled BSDF")
            bsdf.inputs["Base Color"].default_value = m.diffuse_color
            bsdf.inputs["Roughness"].default_value = 0.8
            if toned_part:  # the tone times the colour, as _gather writes it
                tone = m.node_tree.nodes.new("ShaderNodeAttribute")
                tone.attribute_name = "tone"
                mul = m.node_tree.nodes.new("ShaderNodeMix")
                mul.data_type = "RGBA"
                mul.blend_type = "MULTIPLY"
                mul.inputs[0].default_value = 1.0
                mul.inputs[6].default_value = m.diffuse_color
                m.node_tree.links.new(tone.outputs["Color"], mul.inputs[7])
                m.node_tree.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
    # The perforations the game's shader draws, as dark dots for the pictures only.
    dots = []
    for ob in objects:
        if "perf" not in ob:
            continue
        across, along, middle = int(ob["perf_axes"][0]), int(ob["perf_axes"][1]), ob["perf_middle"]
        cos = [v.co for v in ob.data.vertices]
        flat_axis = 3 - across - along
        level = cos[0][flat_axis] + math.copysign(0.0004, ob.data.polygons[0].normal[flat_axis])
        a0, a1 = min(c[along] for c in cos), max(c[along] for c in cos)
        at = math.ceil(a0 / PERF_PITCH) * PERF_PITCH
        bm = bmesh.new()
        while at < a1 - PERF_RADIUS:
            ring = []
            for k in range(8):
                co = [0.0, 0.0, 0.0]
                co[across] = middle + PERF_RADIUS * math.cos(math.tau * k / 8)
                co[along] = at + PERF_RADIUS * math.sin(math.tau * k / 8)
                co[flat_axis] = level
                ring.append(bm.verts.new(co))
            bm.faces.new(ring)
            at += PERF_PITCH
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        dot = mesh_object("_holes", bm, 0x2a2c30)
        dot.data.materials[0].use_nodes = True
        dot.data.materials[0].node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (
            0.02, 0.02, 0.025, 1.0)
        dots.append(dot)
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
    for dot in dots:
        bpy.data.objects.remove(dot)
    bpy.data.objects.remove(floor)
    bpy.data.objects.remove(sun)
    bpy.data.objects.remove(cam)
    return out
