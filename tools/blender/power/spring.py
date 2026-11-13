"""The springs' menu picture model (SN1, 2026-11-02; rebuilt BL7, 2026-11-05): assets/models/powerSources/spring.glb.

One painted main spring, life size (a 20 cm airsoft rifle spring), from the owner's photos (ref_images/springs):
round wire coiled with closed dead coils at both ends and a progressive section, its coils close together, at one
end. The whole wire is the `Label` material, so the menus paint each spring in its own colour, as springs are painted
(game/ui/power_models.gd: one model, three springs). Plain colours, no textures, within the power-source budget
(docs/CC0_ASSETS.md › Power-source models: 6,000 triangles, 120 KB).

Blender axes: the spring runs along Y, its progressive end at -Y.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/power/spring.py <repo root>
"""

import math
import os
import sys

import bpy  # first: it brings bmesh and mathutils with it
import bmesh
from mathutils import Vector

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
OUT = os.path.join(ROOT, "assets/models/powerSources/spring.glb")

MM = 0.001
TAU = math.tau

LENGTH = 200.0
COIL_RADIUS = 8.6  # to the wire's centre: about 18.8 mm across the outside
WIRE_RADIUS = 0.8
WIRE_SIDES = 4
STEPS_PER_TURN = 18
DEAD_TURNS = 1.5  # closed coils at each end, touching
PROGRESSIVE_TURNS = 9.0  # at the -Y end, their pitch half the main coils'
PROGRESSIVE_PITCH = 0.5
MAIN_TURNS = 28.0
BLEND_TURNS = 1.0  # each change of pitch eased over this many turns
LABEL = (1.0, 1.0, 1.0, 1.0)


def material(name: str, colour: tuple) -> bpy.types.Material:
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = colour
    bsdf.inputs["Metallic"].default_value = 0.2
    bsdf.inputs["Roughness"].default_value = 0.38
    return m


def pitches() -> tuple:
    """Each step's pitch along the wire (relative to the main coils', None for a dead coil's), a dead coil's pitch
    (mm a turn) and how many steps a change of pitch is eased over."""
    dead = 2.0 * WIRE_RADIUS
    sections = ((DEAD_TURNS, None), (PROGRESSIVE_TURNS, PROGRESSIVE_PITCH), (MAIN_TURNS, 1.0), (DEAD_TURNS, None))
    raw = []
    for turns, pitch in sections:
        raw += [pitch] * int(round(turns * STEPS_PER_TURN))
    blend = int(BLEND_TURNS * STEPS_PER_TURN)
    return raw, dead, blend


def heights() -> list:
    """The wire centre's height (mm along Y) at each step, the pitch changes eased, LENGTH end to end."""
    raw, dead, blend = pitches()
    steps = len(raw)
    dead_total = sum(1 for p in raw if p is None) * dead / STEPS_PER_TURN
    live_total = sum(p for p in raw if p is not None) / STEPS_PER_TURN
    unit = (LENGTH - 2.0 * WIRE_RADIUS - dead_total) / live_total
    per_step = [dead / STEPS_PER_TURN if p is None else p * unit / STEPS_PER_TURN for p in raw]
    smooth = []
    for i in range(steps):
        lo, hi = max(0, i - blend // 2), min(steps, i + blend // 2 + 1)
        smooth.append(sum(per_step[lo:hi]) / (hi - lo))
    scale = (LENGTH - 2.0 * WIRE_RADIUS) / sum(smooth)
    ys = [-LENGTH * 0.5 + WIRE_RADIUS]
    for s in smooth:
        ys.append(ys[-1] + s * scale)
    return ys


def coil(bm: bmesh.types.BMesh) -> None:
    ys = heights()
    centres = []
    for i, y in enumerate(ys):
        a = TAU * i / STEPS_PER_TURN
        centres.append(Vector((math.cos(a) * COIL_RADIUS, y, math.sin(a) * COIL_RADIUS)))
    rings = []
    for i, c in enumerate(centres):
        t = (centres[min(i + 1, len(centres) - 1)] - centres[max(i - 1, 0)]).normalized()
        out = Vector((c.x, 0.0, c.z)).normalized()
        n = (out - t * out.dot(t)).normalized()
        bn = t.cross(n)
        rings.append([bm.verts.new((c + (n * math.cos(TAU * k / WIRE_SIDES) + bn * math.sin(TAU * k / WIRE_SIDES))
                                    * WIRE_RADIUS) * MM) for k in range(WIRE_SIDES)])
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(WIRE_SIDES):
            k1 = (k + 1) % WIRE_SIDES
            bm.faces.new((r0[k], r0[k1], r1[k1], r1[k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bm = bmesh.new()
    coil(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("Spring")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material("Label", LABEL))
    # What it is made of (tools/blender/replicas/surface.py, MQ2B): steel wire under a baked paint.
    me["surfaces"] = {"Label": "coated"}
    me.shade_smooth()
    ob = bpy.data.objects.new("Spring", me)
    bpy.context.scene.collection.objects.link(ob)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_animations=False,
            export_draco_mesh_compression_enable=False, export_cameras=False, export_lights=False,
            export_extras=True)
    print("Spring: %d triangles; wrote %s (%d bytes)" % (sum(len(p.vertices) - 2 for p in me.polygons), OUT,
                                                         os.path.getsize(OUT)))
