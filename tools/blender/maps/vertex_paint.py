"""Vertex-coloured map models (Dev 3): a model built with hardsurface.Builder, one material a colour, baked to one
colour on every face corner and exported as one mesh in one material, "vertex_colour", like the Kenney props
(tools/props/build_props.py), so the game draws it in one batch and ships no texture.

A colour is (sRGB hex, mask), or for BODY (shade, mask): the share of the piece's colour drawn there. The mask, kept
in the colour's alpha, tells the game what to paint there:
- FIXED (1.0): the colour as given;
- BODY (0.0): the piece's own colour (a skyline shed's paint from the map file) times the colour's shade, a grey;
- LAMP (0.5): a lamp's glass, drawn self-lit at night (SkylineView).
Colours are written linear, as glTF keeps vertex colours.
"""

import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "replicas"))
import hardsurface as hs  # noqa: E402

FIXED = 1.0
BODY = 0.0
LAMP = 0.5


AXES = {"x": Vector((1.0, 0.0, 0.0)), "y": Vector((0.0, 1.0, 0.0)), "z": Vector((0.0, 0.0, 1.0))}


def _turn(faces: list, wants: list) -> None:
    """Turns each face to face its wanted direction (None leaves it). Builder's recalc_face_normals guesses an open
    surface's outside (a drum open at both ends, a cone) and can guess wrong, which the game draws as a hole."""
    for f, want in zip(faces, wants):
        f.normal_update()
        if want is not None and want.length > 1e-9 and f.normal.dot(want) < 0.0:
            f.normal_flip()


def lathe(b: hs.Builder, profile: list, mat: str, segments: int, centre=(0.0, 0.0, 0.0), axis: str = "z",
          cap: bool = True) -> list:
    """Builder.lathe, each face turned outward: a profile walked along the axis has its outside on the right, away
    from the axis on a wall and away from the next ring on a step (whichever way the profile walks)."""
    faces = b.lathe(profile, mat, segments=segments, centre=centre, axis=axis, cap=cap)
    ax = AXES[axis]
    o = Vector(centre)
    walk = 1.0 if profile[-1][0] >= profile[0][0] else -1.0
    wants = []
    for (a0, r0), (a1, r1) in zip(profile, profile[1:]):
        for f in faces[len(wants):len(wants) + segments]:
            d = f.calc_center_median() - o
            radial = d - ax * d.dot(ax)
            radial = radial.normalized() if radial.length > 1e-9 else Vector()
            wants.append((radial * (a1 - a0) - ax * (r1 - r0)) * walk)
    rest = faces[len(wants):]
    caps = []
    if cap and profile[0][1] > 1e-6:
        caps.append(ax * (profile[0][0] - profile[1][0]))
    if cap and profile[-1][1] > 1e-6:
        caps.append(ax * (profile[-1][0] - profile[-2][0]))
    _turn(faces, wants + caps[:len(rest)])
    return faces


def orient_loft(faces: list, rings: list, cap0: bool = False, cap1: bool = False, out=None) -> None:
    """Turns a Builder.loft's faces (between `rings` of Blender points, then its caps) away from the rings' middle
    line, or toward `out` (a Blender direction) on a flat one such as an annulus. Caps face away from the next ring."""
    n = len(rings[0])
    mids = [sum((Vector(p) for p in r), Vector()) / n for r in rings]
    wants = []
    for k in range(len(rings) - 1):
        mid = (mids[k] + mids[k + 1]) * 0.5
        for f in faces[len(wants):len(wants) + n]:
            wants.append(Vector(out) if out is not None else f.calc_center_median() - mid)
    if cap0:
        wants.append(mids[0] - mids[1])
    if cap1:
        wants.append(mids[-1] - mids[-2])
    _turn(faces, wants)


def linear(hex_colour: int) -> tuple:
    srgb = [((hex_colour >> s) & 255) / 255.0 for s in (16, 8, 0)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb)


def materials(palette: dict) -> None:
    """One plain material per palette name, so a Builder can name its faces' colours."""
    for name, (colour, _mask) in palette.items():
        hs.material(name, colour if isinstance(colour, int) else 0xFFFFFF, 0.8)


def bake(ob: bpy.types.Object, palette: dict) -> None:
    """Paints every face corner of `ob` its material's palette colour, then leaves it one "vertex_colour" material.
    Faces stay flat: the skyline and the flagpole are read at a distance, and flat faces keep the edges crisp."""
    me = ob.data
    names = [m.name for m in me.materials]
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    for p in me.polygons:
        colour, mask = palette[names[p.material_index]]
        rgba = (*(linear(colour) if isinstance(colour, int) else (colour, colour, colour)), mask)
        for li in p.loop_indices:
            attr.data[li].color = rgba
        p.material_index = 0
        p.use_smooth = False
    me.materials.clear()
    vc = bpy.data.materials.get("vertex_colour") or bpy.data.materials.new("vertex_colour")
    me.materials.append(vc)


def export(path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=True,
                              export_animations=False, export_yup=True, export_normals=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                              export_draco_mesh_compression_enable=False, export_extras=False,
                              export_cameras=False, export_lights=False, export_materials="EXPORT")
