"""The Variable Scope's placeholder model (SN2, 2026-11-02), added to every parts file whose replica has a top rail.

The owner's brief (2026-11-02): the 2x Scope, but variable zoom and a little longer. So it is the 2x Scope
(`optic_scope2x` in assets/models/replicaParts/<id>.glb) copied as `optic_scopeVar`, its tube run on STRETCH metres in
front of the mount (the eyepiece stays where it is, so the eye and the glass sit as the 2x Scope's), with a ridged zoom
ring round the tube behind the turret and a white index mark on it. Its figure version and sight line are copied the
same. Every other object in the file is left as it was. The owner makes the final model; this one only has to play.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/parts/variable_scope.py <repo root>

It rewrites assets/models/replicaParts/aeg.glb and sniper.glb (an optic_scopeVar already there is replaced).
"""

import math
import os
import sys

import bpy  # first: it brings bmesh and mathutils with it
import bmesh
from mathutils import Vector

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
PARTS_FILES = ["aeg", "sniper"]
SOURCE = "optic_scope2x"
TARGET = "optic_scopeVar"
# How much longer the scope is (m), and where along it (Blender space: +Y forward, +Z up) the tube is cut and run on:
# in front of the mount's front ring, behind the objective bell.
STRETCH = 0.035
CUT_Y = 0.015
# The scope's axis height in its own space, and the zoom ring round it: from RING_Y0 to RING_Y1, ridged between two
# radii in RING_RIDGES ridges.
AXIS_Z = 0.0305
RING_Y0 = -0.046
RING_Y1 = -0.034
RING_INNER = 0.0182
RING_OUTER = 0.0194
RING_RIDGES = 18
# The zoom ring's index mark: a small box on top of the ring.
MARK_SIZE = Vector((0.002, 0.008, 0.0012))


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def stretch(ob: bpy.types.Object) -> None:
    for v in ob.data.vertices:
        if v.co.y > CUT_Y:
            v.co.y += STRETCH


def ring_mesh(ob: bpy.types.Object) -> None:
    """The ridged zoom ring and its index mark, added to the scope's mesh in its Rubber and Accent slots."""
    names = [m.name for m in ob.data.materials]
    rubber = names.index("Rubber")
    accent = names.index("Accent")
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    n = RING_RIDGES * 2
    rings = []
    for y in (RING_Y0, RING_Y1):
        loop = []
        for i in range(n):
            a = math.tau * i / n
            r = RING_OUTER if i % 2 == 0 else RING_INNER
            loop.append(bm.verts.new((math.sin(a) * r, y, AXIS_Z + math.cos(a) * r)))
        rings.append(loop)
    new_faces = []
    for i in range(n):
        j = (i + 1) % n
        new_faces.append(bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i])))
    new_faces.append(bm.faces.new(list(reversed(rings[0]))))
    new_faces.append(bm.faces.new(rings[1]))
    for f in new_faces:
        f.material_index = rubber
    mark = bmesh.ops.create_cube(bm, size=1.0)
    centre = Vector((0.0, (RING_Y0 + RING_Y1) * 0.5, AXIS_Z + RING_OUTER + MARK_SIZE.z * 0.4))
    for v in mark["verts"]:
        v.co = Vector((v.co.x * MARK_SIZE.x, v.co.y * MARK_SIZE.y, v.co.z * MARK_SIZE.z)) + centre
    mark_verts = set(mark["verts"])
    for f in bm.faces:
        if all(v in mark_verts for v in f.verts):
            f.material_index = accent
    bmesh.ops.recalc_face_normals(bm, faces=new_faces)
    bm.to_mesh(ob.data)
    bm.free()


def copy_tree(src: bpy.types.Object, parent: bpy.types.Object | None) -> bpy.types.Object:
    ob = src.copy()
    if src.data is not None:
        ob.data = src.data.copy()
    ob.name = src.name.replace(SOURCE, TARGET)
    if ob.data is not None:
        ob.data.name = ob.name
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent
    for child in src.children:
        copy_tree(child, ob)
    return ob


def build(part_file: str) -> None:
    reset()
    path = os.path.join(ROOT, "assets/models/replicaParts/%s.glb" % part_file)
    bpy.ops.import_scene.gltf(filepath=path)
    old = bpy.data.objects.get(TARGET)
    if old is not None:
        for child in old.children_recursive:
            bpy.data.objects.remove(child, do_unlink=True)
        bpy.data.objects.remove(old, do_unlink=True)
    scope = copy_tree(bpy.data.objects[SOURCE], None)
    for ob in [scope] + list(scope.children_recursive):
        if ob.type == "MESH":
            stretch(ob)
    ring_mesh(scope)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=True,
            export_animations=False, export_yup=True, export_draco_mesh_compression_enable=False,
            export_extras=False, export_cameras=False, export_lights=False)
    tris = sum(len(p.vertices) - 2 for p in scope.data.polygons)
    print("  %s: %s %d triangles" % (part_file, TARGET, tris))


if __name__ == "__main__":
    for f in PARTS_FILES:
        build(f)
    print("wrote", ", ".join(PARTS_FILES))
