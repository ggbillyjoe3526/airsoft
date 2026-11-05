"""The BB in flight (BM1, 2026-11-05): assets/models/effects/bb.glb.

One 6 mm airsoft BB: a smooth, polished ball. Every BB in the air is this mesh, drawn in one batch
(game/play/bb_view.gd, a MultiMesh): white BBs with their rim shader, glowing BBs self-lit green, both by the game's own
materials (the mesh carries a plain placeholder one). Modelled 1 m across, centred on the origin, because the game draws
it at EffectsConfig.bb_size (a little larger than life, so it reads at range) and never under its least size on screen.

An icosphere, not a UV sphere: its triangles are all about one size, so its outline stays round from every side with few
triangles, and it has no pinched poles. Two subdivisions of the icosahedron (320 triangles): round at the size a BB is
seen next to the muzzle at 4K, and still cheap with every BB of the pool (BallisticsConfig.max_bbs) in the air at once.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/effects/bb.py <repo root>
"""

import os
import sys

import bpy

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
OUT = os.path.join(ROOT, "assets/models/effects/bb.glb")

DIAMETER = 1.0  # the game scales it to EffectsConfig.bb_size
SUBDIVISIONS = 3  # Blender counts the plain icosahedron as 1: 20 x 4 x 4 = 320 triangles
COLOUR = (1.0, 0.98, 0.92, 1.0)  # EffectsConfig.bb_colour; the game replaces the material


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=SUBDIVISIONS, radius=DIAMETER * 0.5, location=(0.0, 0.0, 0.0))
    ball = bpy.context.active_object
    ball.name = "BB"
    ball.data.name = "BB"
    for poly in ball.data.polygons:
        poly.use_smooth = True
    mat = bpy.data.materials.new("BB")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = COLOUR
    bsdf.inputs["Roughness"].default_value = 0.25
    ball.data.materials.append(mat)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_animations=False,
            export_draco_mesh_compression_enable=False, export_cameras=False, export_lights=False,
            export_texcoords=False)
    print("BB: %d triangles; wrote %s (%d bytes)" % (len(ball.data.polygons), OUT, os.path.getsize(OUT)))


main()
