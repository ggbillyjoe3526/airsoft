"""Weathering for the map models (WG4, Woodland's small props): soft colour variation painted onto a model's vertices
after mapkit has baked its parts' colours, so rust, mud, moss, dust and soot read without a texture.

A model is built with mapkit (one material a part, palette colours), then `weather` walks every face corner and hands
its position, normal and baked colour (linear) to a function that returns the corner's new colour. The helpers here
are the pieces such a function is made of: a seeded value noise (`noise`, `fbm`), `mix` in linear light, and
`export`, which writes the model as mapkit.export_prop does but keeps the weathered colours (export_prop bakes them
again). Everything is deterministic: the same script writes the same glb.

Every colour a model ends with must stay off the teams' hues (tests/unit/test_props.gd): a blend of two colours that
pass can fail between them, so blends here go through dull colours (greys, dull browns), never from one strong hue to
another.
"""

import math
import os

import bpy  # noqa: F401  (mapkit brings it; imported first for bmesh and mathutils)
from mathutils import Vector

import mapkit as mk


def _hash(ix: int, iy: int, iz: int, seed: int) -> float:
    h = (ix * 374761393 + iy * 668265263 + iz * 2147483647 + seed * 144665) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def noise(p: Vector, scale: float, seed: int = 0) -> float:
    """Value noise in 0..1 at `p` with features about `scale` m across, smoothly interpolated."""
    x, y, z = p.x / scale, p.y / scale, p.z / scale
    ix, iy, iz = math.floor(x), math.floor(y), math.floor(z)
    fx, fy, fz = x - ix, y - iy, z - iz
    ux, uy, uz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (ux if dx else 1 - ux) * (uy if dy else 1 - uy) * (uz if dz else 1 - uz)
                out += w * _hash(ix + dx, iy + dy, iz + dz, seed)
    return out


def fbm(p: Vector, scale: float, seed: int = 0, octaves: int = 3) -> float:
    """Noise summed over `octaves`, each half the size and half the weight of the last; 0..1."""
    total, weight, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        total += weight * noise(p, scale / (2 ** o), seed + 17 * o)
        norm += weight
        weight *= 0.5
    return total / norm


def smooth(e0: float, e1: float, x: float) -> float:
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def mix(a: tuple, b: tuple, t: float) -> tuple:
    """Linear colours a to b by t (0..1), alpha 1."""
    t = min(1.0, max(0.0, t))
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, 1.0)


def scale(c: tuple, k: float) -> tuple:
    return (c[0] * k, c[1] * k, c[2] * k, 1.0)


def weather(ob: bpy.types.Object, paint) -> None:
    """Repaints every face corner of `ob` (after mapkit.bake_vertex_colours): `paint(position, normal, colour,
    material_slot)` returns its new linear colour. Positions are in the model's own space (Blender's, +Z up)."""
    me = ob.data
    data = me.color_attributes["Color"].data
    for poly in me.polygons:
        n = Vector(poly.normal)
        for li, vi in zip(poly.loop_indices, poly.vertices):
            p = me.vertices[vi].co
            data[li].color = paint(p, n, tuple(data[li].color), poly.material_index)


def export(ob: bpy.types.Object, name: str) -> str:
    """Writes `ob` (baked and weathered) alone as assets/models/props/<name>.glb, as mapkit.export_prop does without
    baking again; returns the path."""
    for other in list(bpy.data.objects):
        if other is not ob:
            bpy.data.objects.remove(other, do_unlink=True)
    os.makedirs(mk.PROPS, exist_ok=True)
    path = os.path.join(mk.PROPS, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=True,
                              export_animations=False, export_yup=True, export_vertex_color="ACTIVE",
                              export_all_vertex_colors=False, export_draco_mesh_compression_enable=False,
                              export_extras=False, export_cameras=False, export_lights=False, export_texcoords=False,
                              export_materials="EXPORT")
    return path


def copy_object(ob: bpy.types.Object, name: str) -> bpy.types.Object:
    """A full copy of `ob` (mesh too), linked to the scene: one build exported in two colourings."""
    dup = ob.copy()
    dup.data = ob.data.copy()
    dup.name = name
    bpy.context.scene.collection.objects.link(dup)
    return dup


def lattice_box(b, xs: list, ys: list, zs: list, mat: str, skip: tuple = ()) -> dict:
    """A box whose faces are grids through the planes x in `xs`, y in `ys`, z in `zs` (each sorted, its ends the
    box's), watertight along its edges, so a model's weathering and chamfers have vertices where they need them.
    Faces named in `skip` ("+x", "-z"...) are left off (against a wall, under the ground). Returns the vertices by
    lattice index (i, j, k), to be moved (`chamfer_edge`, or grooves pushed in) before the mesh is built."""
    import bmesh
    bm = b.bm
    nx, ny, nz = len(xs) - 1, len(ys) - 1, len(zs) - 1
    verts = {}

    def v(i: int, j: int, k: int):
        key = (i, j, k)
        if key not in verts:
            verts[key] = bm.verts.new(Vector((xs[i], ys[j], zs[k])))
        return verts[key]

    faces = []
    m = b.mat(mat)
    # each face: its fixed axis and end, then its two running axes in a right-handed order (normal outward)
    for axis, end, sign in (("x", nx, "+x"), ("x", 0, "-x"), ("y", ny, "+y"), ("y", 0, "-y"), ("z", nz, "+z"),
                            ("z", 0, "-z")):
        if sign in skip:
            continue
        if axis == "x":
            grid = [[v(end, j, k) for k in range(nz + 1)] for j in range(ny + 1)]
        elif axis == "y":
            grid = [[v(i, end, k) for k in range(nz + 1)] for i in range(nx + 1)]
        else:
            grid = [[v(i, j, end) for j in range(ny + 1)] for i in range(nx + 1)]
        outward = sign[0] == "+"
        for a in range(len(grid) - 1):
            for c in range(len(grid[0]) - 1):
                quad = [grid[a][c], grid[a + 1][c], grid[a + 1][c + 1], grid[a][c + 1]]
                f = bm.faces.new(quad)
                f.material_index = m
                f.normal_update()
                want = Vector((1 if axis == "x" else 0, 1 if axis == "y" else 0, 1 if axis == "z" else 0))
                if (f.normal.dot(want) > 0) != outward:
                    f.normal_flip()
                faces.append(f)
    bm.normal_update()
    _ = bmesh
    return verts


def chamfer_edge(verts: dict, keys: list, inner: list) -> None:
    """Cuts the box edge through lattice points `keys` to a 45 degree chamfer: each point moves to the middle of its
    two neighbours `inner` (the lattice points one step in along each face, given per key as a pair)."""
    for key, (a, c) in zip(keys, inner):
        if key in verts and a in verts and c in verts:
            verts[key].co = (verts[a].co + verts[c].co) * 0.5
