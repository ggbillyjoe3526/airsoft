"""Shared helpers for the map models (Dev 3: Depot's hall shell and props), built from code like the replicas.

A map model is a prop: one mesh in metres (Blender +Z up and -Y its front; the glTF export turns them +Y up and +Z,
the front PropLayout faces into the field), painted in vertex colours
(linear, glTF's COLOR_0) from the build's palette materials, so the game draws every prop in one vertex-coloured
material (PropDress, RoofView) and ships no texture. Each model fills its block's box exactly: the build reports its
bounds and triangles, and the game stretches it a little to the box.

Palette colours are docs/ART.md's (LookConfig.palette), sRGB hex here, written linear; every one stays off the teams'
hues (tests/unit/test_props.gd). Run each model's script with Blender 5.x or pip's `bpy` (pip install bpy==5.2.3):

    python -I tools/blender/maps/<model>.py <repo root>
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "replicas"))

import bpy  # noqa: E402  first: it brings bmesh and mathutils with it
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

import hardsurface as hs  # noqa: E402

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
PROPS = os.path.join(ROOT, "assets", "models", "props")

# The look's palette (sRGB), the names LookConfig.palette uses, plus a few shades of them a model needs.
PALETTE = {
    "crimson": 0xC23874, "violet": 0x7658AA, "yellow": 0xE4CA46, "teal": 0x2A9C90, "green": 0x58904E,
    "cream": 0xF4ECDA, "concrete": 0xD2CEC8, "floor": 0xB9B4AE, "steel": 0x6C6A7A, "ink": 0x3A2F5A,
    "slab": 0x7C7670, "plaster": 0xECE2CF, "grey": 0x8C8A96, "pebble": 0xA09A92, "stone": 0x8C8478,
    "ceiling": 0x524A72, "umber": 0x61594F, "rubber": 0x3D3B45, "lilac": 0xB9A8D6, "olive": 0x8C9A48,
    "pine": 0x3D7A4A, "forest": 0x2B5C48, "litter": 0x7C7A58, "canopy": 0x5C9A50, "sage": 0xA9C4BE,
    "moss": 0xB3B891, "earth": 0x8A8070, "spruce": 0x2F6E55, "butter": 0xE6D478,
}


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def linear(hex_colour: int, shade: float = 1.0) -> tuple:
    """`hex_colour` (sRGB) as linear RGBA, its sRGB channels times `shade` first."""
    srgb = [min(1.0, ((hex_colour >> s) & 255) / 255.0 * shade) for s in (16, 8, 0)]
    return (*[srgb_to_linear(c) for c in srgb], 1.0)


def paints(names: dict) -> None:
    """Makes a material for each name: hex (sRGB) or (hex, shade)."""
    for name, spec in names.items():
        colour, shade = spec if isinstance(spec, tuple) else (spec, 1.0)
        srgb = [min(1.0, ((colour >> s) & 255) / 255.0 * shade) for s in (16, 8, 0)]
        hs.material(name, (round(srgb[0] * 255) << 16) | (round(srgb[1] * 255) << 8) | round(srgb[2] * 255), 0.7)


def bake_vertex_colours(ob: bpy.types.Object, keep: tuple = ()) -> None:
    """Paints every face corner of `ob` its material's colour (linear, a corner colour attribute named Color), then
    draws every face with one material, `Prop`, except faces whose material is in `keep` (their own surface: a lamp's
    glowing lens)."""
    me = ob.data
    attr = me.color_attributes.new("Color", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    cols = []
    for m in me.materials:
        bsdf = m.node_tree.nodes["Principled BSDF"]
        cols.append(tuple(bsdf.inputs["Base Color"].default_value))
    data = attr.data
    for p in me.polygons:
        c = cols[p.material_index]
        for li in p.loop_indices:
            data[li].color = c
    prop = bpy.data.materials.get("Prop") or bpy.data.materials.new("Prop")
    names = [m.name for m in me.materials]
    kept = [k for k in keep if k in names]
    slot = [1 + kept.index(name) if name in kept else 0 for name in names]
    faces = [slot[p.material_index] for p in me.polygons]
    # clearing the slots sets every face's index to 0, so the faces' new slots are set after
    me.materials.clear()
    for m in [prop] + [bpy.data.materials[k] for k in kept]:
        me.materials.append(m)
    for p, i in zip(me.polygons, faces):
        p.material_index = i


def export_prop(ob: bpy.types.Object, name: str, keep: tuple = ()) -> str:
    """Bakes `ob`'s vertex colours and writes it alone as assets/models/props/<name>.glb; returns the path."""
    bake_vertex_colours(ob, keep)
    for other in list(bpy.data.objects):
        if other is not ob:
            bpy.data.objects.remove(other, do_unlink=True)
    os.makedirs(PROPS, exist_ok=True)
    path = os.path.join(PROPS, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=True,
                              export_animations=False, export_yup=True, export_vertex_color="ACTIVE",
                              export_all_vertex_colors=False, export_draco_mesh_compression_enable=False,
                              export_extras=False, export_cameras=False, export_lights=False, export_texcoords=False,
                              export_materials="EXPORT")
    return path


def report(ob: bpy.types.Object, name: str, budget: int) -> None:
    """Prints the model's triangles against its budget and its bounds (glTF axes: x, y up, z)."""
    lo = Vector((min(v.co.x for v in ob.data.vertices), min(v.co.y for v in ob.data.vertices),
                 min(v.co.z for v in ob.data.vertices)))
    hi = Vector((max(v.co.x for v in ob.data.vertices), max(v.co.y for v in ob.data.vertices),
                 max(v.co.z for v in ob.data.vertices)))
    t = hs.tris(ob)
    print("%s: %d triangles (%.0f%% of %d), x %.3f..%.3f, y(up) %.3f..%.3f, z %.3f..%.3f" % (
        name, t, 100.0 * t / budget, budget, lo.x, hi.x, lo.z, hi.z, -hi.y, -lo.y))


def cylinder(b: hs.Builder, base: tuple, top: tuple, r: float, mat: str, sides: int = 8, caps: bool = True) -> list:
    """A round bar from `base` to `top` (any direction), `sides` sided."""
    a, c = Vector(base), Vector(top)
    axis = (c - a).normalized()
    side = axis.orthogonal().normalized()
    other = axis.cross(side)
    rings = []
    for end in (a, c):
        rings.append([tuple(end + (side * math.cos(2 * math.pi * i / sides) + other * math.sin(2 * math.pi * i / sides))
                            * r) for i in range(sides)])
    return b.loft(rings, mat, cap0=caps, cap1=caps)


def beam(b: hs.Builder, base: tuple, top: tuple, w: float, d: float, mat: str, up: tuple = (0.0, 0.0, 1.0),
         caps: bool = False) -> list:
    """A square bar `w` by `d` from `base` to `top`, its `d` side towards `up` (as near as the bar allows)."""
    a, c = Vector(base), Vector(top)
    axis = (c - a).normalized()
    u = Vector(up)
    side = axis.cross(u)
    if side.length < 1e-6:
        side = axis.orthogonal()
    side.normalize()
    upv = side.cross(axis).normalized()
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    rings = [[tuple(end + side * (sx * w * 0.5) + upv * (sy * d * 0.5)) for sx, sy in corners] for end in (a, c)]
    return b.loft(rings, mat, cap0=caps, cap1=caps)


def profile_bar(b: hs.Builder, outline: list, a0: float, a1: float, axis: str, mat: str, offset: tuple = (0, 0, 0),
                caps: bool = False) -> list:
    """A 2D outline (prism) swept along `axis` from a0 to a1, its end caps left off unless `caps` (a bar running into
    a wall or the next bay hides its ends)."""
    faces = b.prism(outline, axis, a0, a1, mat, offset)
    if not caps:
        bm = b.bm
        for f in faces[:2]:
            bm.faces.remove(f)
        return faces[2:]
    return faces


def quad(b: hs.Builder, pts: list, mat: str) -> list:
    """One quad (or polygon) through `pts`, wound as given (its front by the right-hand rule)."""
    bm = b.bm
    f = bm.faces.new([bm.verts.new(Vector(p)) for p in pts])
    f.material_index = b.mat(mat)
    return [f]


def clean(ob: bpy.types.Object) -> None:
    """Merges coincident vertices and drops degenerate faces, no bevel, smooth shading split at hard edges."""
    hs.finish(ob, bevel=0.0, weighted=True)

