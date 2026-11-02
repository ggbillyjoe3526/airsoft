"""The springs' menu picture model (SN1, 2026-11-02): assets/models/powerSources/spring.glb.

One coil spring, about life size (a 20 cm airsoft rifle spring), with a paper band round its middle whose material is
named `Label`, so the menus paint each spring in its own colour (game/ui/power_models.gd: one model, three springs).
Plain colours, no textures, within the power-source budget (docs/CC0_ASSETS.md › Power-source models: about 1,500
triangles, 60 KB).

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/power/spring.py <repo root>
"""

import math
import os
import sys

import bpy  # first: it brings bmesh and mathutils with it
import bmesh
from mathutils import Matrix, Vector

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
OUT = os.path.join(ROOT, "assets/models/powerSources/spring.glb")

LENGTH = 0.20
COIL_RADIUS = 0.0105
WIRE_RADIUS = 0.0011
TURNS = 14
STEPS_PER_TURN = 8
WIRE_SIDES = 4
BAND_RADIUS = 0.0125
BAND_LENGTH = 0.035
BAND_SIDES = 16
STEEL = (0.62, 0.64, 0.66, 1.0)
LABEL = (1.0, 1.0, 1.0, 1.0)


def material(name: str, colour: tuple) -> bpy.types.Material:
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = colour
    bsdf.inputs["Metallic"].default_value = 0.2
    bsdf.inputs["Roughness"].default_value = 0.45
    return m


def coil(bm: bmesh.types.BMesh) -> None:
    """The wire: a square tube swept along a helix up +Y, closed coils at each end."""
    steps = TURNS * STEPS_PER_TURN
    rings = []
    for i in range(steps + 1):
        a = TAU * i / STEPS_PER_TURN
        y = -LENGTH * 0.5 + LENGTH * i / steps
        centre = Vector((math.cos(a) * COIL_RADIUS, y, math.sin(a) * COIL_RADIUS))
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        up = Vector((0.0, 1.0, 0.0))
        ring = []
        for k in range(WIRE_SIDES):
            b = TAU * k / WIRE_SIDES
            ring.append(bm.verts.new(centre + (out * math.cos(b) + up * math.sin(b)) * WIRE_RADIUS))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(WIRE_SIDES):
            k1 = (k + 1) % WIRE_SIDES
            bm.faces.new((r0[k], r0[k1], r1[k1], r1[k])).material_index = 0


def band(bm: bmesh.types.BMesh) -> None:
    geom = bmesh.ops.create_cone(bm, cap_ends=False, segments=BAND_SIDES, radius1=BAND_RADIUS, radius2=BAND_RADIUS,
            depth=BAND_LENGTH)
    bmesh.ops.transform(bm, matrix=Matrix.Rotation(-math.pi * 0.5, 4, "X"), verts=geom["verts"])
    vs = set(geom["verts"])
    for f in bm.faces:
        if all(v in vs for v in f.verts):
            f.material_index = 1


TAU = math.tau

if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bm = bmesh.new()
    coil(bm)
    band(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("Spring")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material("Steel", STEEL))
    me.materials.append(material("Label", LABEL))
    ob = bpy.data.objects.new("Spring", me)
    bpy.context.scene.collection.objects.link(ob)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_animations=False,
            export_draco_mesh_compression_enable=False, export_cameras=False, export_lights=False)
    print("Spring: %d triangles; wrote %s" % (sum(len(p.vertices) - 2 for p in me.polygons), OUT))
