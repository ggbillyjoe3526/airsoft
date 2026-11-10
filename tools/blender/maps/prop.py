"""Shared helpers for the map props built in Blender (Dev 3, RK1): one vertex-coloured mesh a model, exported as a
.glb into assets/models/props/, so PropDress draws it in the props' one material (PropDressConfig).

A prop is built from code with hardsurface.py's Builder, each face painted a palette colour by name (LookConfig.palette,
sRGB here, written linear): "crate", or "crate*0.9" for a shade of it. On export every face's paint becomes the colour
of its corners (COLOR_0, linear), times a gentle vertical gradient (the look's clean surfaces: darker at the foot,
docs/ART.md), and the materials are dropped. Blender space: +Z up, the model's front towards -Y (glTF +Z, the
model's front in PropLayout), metres, its foot on z = 0. Each model is modelled at its block's size so the game's fit
stretches it as little as possible.

Run a model's script with pip's bpy (pip install bpy==5.2.3): python3 tools/blender/maps/<model>.py
Dev tool: tools/ never ships.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "replicas"))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import hardsurface as hs  # noqa: E402

OUT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "assets", "models", "props"))

# LookConfig.palette (sRGB), the names the props paint with. Every colour stays off the teams' hues
# (tests/unit/test_props.gd).
PALETTE = {
    "crimson": 0xc23874, "violet": 0x7658aa, "yellow": 0xe4ca46, "teal": 0x2a9c90, "green": 0x58904e,
    "cream": 0xf4ecda, "concrete": 0xd2cec8, "plywood": 0xdccaa8, "timber": 0xa0947c, "crate": 0xc2b698,
    "steel": 0x6c6a7a, "ink": 0x3a2f5a, "sand": 0xb9ae98, "plaster": 0xece2cf, "grey": 0x8c8a96,
    "pebble": 0xa09a92, "stone": 0x8c8478, "umber": 0x61594f, "moss": 0xb3b891, "bark": 0x7b6f62,
    "heartwood": 0xe4dccd, "rubber": 0x3d3b45, "lilac": 0xb9a8d6, "butter": 0xe6d478, "sage": 0xa9c48e,
    "seafoam": 0x7fb8ad, "olive": 0x8c9a48, "slab": 0x7c7670,
}

# The vertical gradient: a corner at the model's foot takes this share of its paint, one at the top all of it.
FOOT_SHADE = 0.86


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def paint_rgb(paint: str) -> tuple:
    """A paint's sRGB colour (0..1): a palette name, or "name*shade" (shades multiply: "name*0.9*0.8")."""
    name, *shades = paint.split("*")
    hexc = PALETTE[name]
    k = math.prod(float(s) for s in shades)
    return tuple(min(1.0, ((hexc >> s) & 255) / 255.0 * k) for s in (16, 8, 0))


class Prop:
    """One prop's geometry: a hardsurface Builder whose material names are paints."""

    def __init__(self, name: str):
        hs.reset()
        self.name = name
        self.b = hs.Builder(name, [])
        self.parts: list = []  # extra objects (booleans, bevelled pieces) joined in on export

    def _paint(self, paint: str) -> str:
        if bpy.data.materials.get(paint) is None:
            r, g, b = paint_rgb(paint)
            hs.material(paint, (int(r * 255) << 16) | (int(g * 255) << 8) | int(b * 255))
        return paint

    def box(self, lo: tuple, hi: tuple, paint: str) -> list:
        return self.b.box(lo, hi, self._paint(paint))

    def prism(self, poly: list, axis: str, a0: float, a1: float, paint: str, offset: tuple = (0.0, 0.0, 0.0)) -> list:
        return self.b.prism(poly, axis, a0, a1, self._paint(paint), offset)

    def lathe(self, profile: list, paint: str, segments: int, centre: tuple, axis: str = "z", cap: bool = True,
              start: float = 0.0) -> list:
        return self.b.lathe(profile, self._paint(paint), segments, centre, axis, cap, start)

    def loft(self, rings: list, paint: str, cap0: bool = True, cap1: bool = True) -> list:
        return self.b.loft(rings, self._paint(paint), cap0, cap1)

    def quad(self, pts: list, paint: str) -> list:
        """One flat face through `pts` (counter-clockwise seen from its front): a decal a hair proud of a surface."""
        f = self.b.bm.faces.new([self.b.bm.verts.new(Vector(v)) for v in pts])
        self.faces_paint([f], paint)
        return [f]

    def front_decal(self, x0: float, x1: float, z0: float, z1: float, y: float, paint: str) -> list:
        """A rectangle on a face looking towards -Y (the model's front), at depth y."""
        return self.quad([(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], paint)

    def faces_paint(self, faces: list, paint: str) -> None:
        i = self.b.mat(self._paint(paint))
        for f in faces:
            f.material_index = i

    def transform(self, faces: list, m: Matrix) -> None:
        self.b.transform(faces, m)

    def piece(self, bevel: float, segments: int = 1) -> "Prop":
        """A separate Builder for a piece bevelled on its own (`bevel` m, in `segments`), joined in on export."""
        sub = Prop.__new__(Prop)
        sub.name = f"{self.name}_{len(self.parts)}"
        sub.b = hs.Builder(sub.name, [])
        sub.parts = []
        sub.bevel = (bevel, segments)
        self.parts.append(sub)
        return sub

    def _object(self, bevel: float, segments: int) -> bpy.types.Object:
        ob = self.b.build()
        hs.finish(ob, bevel=bevel, segments=segments, weighted=bevel > 0.0)
        return ob

    def export(self, file_name: str, budget: int, bevel: float = 0.0, segments: int = 1) -> int:
        """Finishes, paints the corners and writes assets/models/props/<file_name>; returns the triangle count."""
        obs = [self._object(bevel, segments)]
        for sub in self.parts:
            obs.append(sub._object(*sub.bevel))
        ob = hs.join(self.name, obs)
        bake_colours(ob)
        n = hs.tris(ob)
        if n > budget:
            raise SystemExit(f"{self.name}: {n} triangles, over its budget of {budget}")
        ob.data.materials.clear()
        path = os.path.join(OUT, file_name)
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=True,
                                  export_animations=False, export_yup=True, export_materials="NONE",
                                  export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                                  export_draco_mesh_compression_enable=False, export_extras=False,
                                  export_cameras=False, export_lights=False, export_texcoords=False)
        dims = ob.dimensions
        print(f"{file_name}: {n} triangles of {budget} ({100.0 * n / budget:.0f}%), "
              f"{dims.x:.3f} x {dims.z:.3f} x {dims.y:.3f} m (w x h x d)")
        return n


def bake_colours(ob: bpy.types.Object) -> None:
    """Each face's paint (its material's colour, linear) onto its corners, times the vertical gradient."""
    me = ob.data
    zs = [v.co.z for v in me.vertices]
    z0, z1 = min(zs), max(zs)
    span = max(z1 - z0, 1e-6)
    attr = me.color_attributes.new("Color", "FLOAT_COLOR", "CORNER")
    lin = []
    for m in me.materials:
        r, g, b = paint_rgb(m.name)
        lin.append((srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b)))
    for p in me.polygons:
        c = lin[p.material_index]
        for li in p.loop_indices:
            z = me.vertices[me.loops[li].vertex_index].co.z
            t = (z - z0) / span
            k = FOOT_SHADE + (1.0 - FOOT_SHADE) * (t * t * (3.0 - 2.0 * t))
            attr.data[li].color = (c[0] * k, c[1] * k, c[2] * k, 1.0)
    me.color_attributes.active_color = attr
    me.color_attributes.render_color_index = 0


# ------------------------------------------------------------------------------------------------ shape helpers

def rect(cx: float, cy: float, hw: float, hh: float) -> list:
    return [(cx - hw, cy - hh), (cx + hw, cy - hh), (cx + hw, cy + hh), (cx - hw, cy + hh)]


def ring(cx: float, cy: float, z: float, r: float, n: int, start: float = 0.0, sx: float = 1.0) -> list:
    return [(cx + sx * r * math.cos(start + 2 * math.pi * i / n), cy + r * math.sin(start + 2 * math.pi * i / n), z)
            for i in range(n)]


def beam_between(p: Prop, a: tuple, b: tuple, w: float, d: float, paint: str) -> list:
    """A square-section bar w x d from point a to point b (any direction)."""
    av, bv = Vector(a), Vector(b)
    length = (bv - av).length
    faces = p.box((-w / 2, -d / 2, 0.0), (w / 2, d / 2, length), paint)
    z = Vector((0, 0, 1))
    rot = z.rotation_difference((bv - av).normalized()).to_matrix().to_4x4()
    p.transform(faces, Matrix.Translation(av) @ rot)
    return faces
