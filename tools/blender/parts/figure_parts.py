"""The figures' copy of every part in the replicas' parts files, cut down from the part itself (TP1, 2026-11-05).

A figure carries a part as its `<part>_Figure` copy (game/play/replica_parts.gd `take`). Each copy used to be a
hand-made block of a few dozen faces; this remakes every one from its part the way the replicas' own figure copies are
made (tools/blender/replicas/figure_copy.py): the part and the meshes under it, hidden faces dropped, cut down to
FIGURE_SHARE of its triangles (between FIGURE_MIN and FIGURE_MAX; a magazine to its replica's own figure magazine's
count, MAGAZINE), shaded with its hard edges kept. The copy keeps the old one's place: under the part, or beside it at
the top level, then drawn in the replica's space at its origin.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3), LAST, after every script that writes a
parts file (the replicas' scripts, tools/blender/parts/fit_parts.py and attachments.py):

    python -I tools/blender/parts/figure_parts.py <repo root>

It rewrites assets/models/replicaParts/<id>.glb for every replica id in FILES. Running it again makes the same copies.
A worn part's copy (RW2: the alternative magazines, tools/blender/parts/magazines.py) is put on the plain paint with no
UV layers (wear.plain_copy), and the worn materials keep their names through the rewrite (wear.resuffix, unsuffix).
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "replicas"))

import bpy  # noqa: E402

import figure_copy  # noqa: E402
import hardsurface as hs  # noqa: E402
import wear  # noqa: E402

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
FILES = ["aeg", "pistol", "cyber", "sniper", "smg"]
SUFFIX = "_Figure"
# A part's copy: this share of its triangles, kept between FIGURE_MIN and FIGURE_MAX (a part's small round shapes, a
# laser's knurled body, thin out below it), and always under the part's own count. FIGURE_MAX 600 (from 900): the
# AEG's parts file also holds MAG1's magazines and BA1's barrels (4 MiB, docs/CC0_ASSETS.md › Size limits).
FIGURE_SHARE = 0.15
FIGURE_MIN = 120
# Parts whose own script builds their figures' copy, kept as it is: a barrel's (tools/blender/parts/barrels.py, BA1),
# a plain tube in a few faces, as its inner barrel and hop-up unit take its triangles nearly to the last.
OWN_COPY = ("barrel_",)
FIGURE_MAX = 600
UNDER = 0.8
# A magazine part's copy: as many triangles as the replica's own figure magazine (Figure_Magazine in its model file,
# assets/models/replicas/<id>.glb, read when the file is written).
MAGAZINE = "Figure_Magazine"


def magazine_tris(part_file: str) -> int:
    """How many triangles replica `part_file`'s own figure magazine has (0: none)."""
    path = os.path.join(ROOT, "assets/models/replicas/%s.glb" % part_file)
    if not os.path.exists(path):
        return 0
    hs.reset()
    bpy.ops.import_scene.gltf(filepath=path)
    ob = bpy.data.objects.get(MAGAZINE)
    return hs.tris(ob) if ob is not None else 0


def budget(name: str, have: int, magazine: int) -> int:
    if name.startswith("magazine_") and magazine > 0:
        want = magazine
    else:
        want = min(FIGURE_MAX, max(FIGURE_MIN, round(have * FIGURE_SHARE)))
    return min(want, int(have * UNDER))


def copy_of(part: bpy.types.Object, magazine: int) -> bpy.types.Object:
    """The cut-down copy of `part` and the meshes under it (not its old copy), in `part`'s own frame."""
    sources = [part] + [o for o in part.children_recursive if o.type == "MESH" and not o.name.endswith(SUFFIX)]
    to_part = part.matrix_world.inverted()
    meshes = []
    for o in sources:
        me = figure_copy._copy_mesh(o, True)
        me.transform(to_part)
        meshes.append(me)
    have = sum(sum(len(p.vertices) - 2 for p in me.polygons) for me in meshes)
    ob = figure_copy._object(part.name + SUFFIX, meshes, figure_copy._materials(meshes))
    wear.plain_copy(ob)
    figure_copy.cut_down(ob, budget(part.name, have, magazine))
    return ob


def write(part_file: str) -> None:
    path = os.path.join(ROOT, "assets/models/replicaParts/%s.glb" % part_file)
    if not os.path.exists(path):
        return
    magazine = magazine_tris(part_file)
    hs.reset()
    bpy.ops.import_scene.gltf(filepath=path)
    wear.resuffix()
    parts = [o for o in bpy.data.objects if o.type == "MESH" and o.parent is None and not o.name.endswith(SUFFIX)]
    for part in parts:
        old = bpy.data.objects.get(part.name + SUFFIX)
        if old is not None and part.name.startswith(OWN_COPY):
            continue
        under = old is not None and old.parent is part
        if old is not None:
            bpy.data.objects.remove(old, do_unlink=True)
        new = copy_of(part, magazine)
        if under:
            new.parent = part
            new.matrix_parent_inverse.identity()
        else:
            # Beside the part, in the replica's space at its origin: a magazine's copy is the figures' reload magazine
            # too, drawn in the frame of the replica's own figure magazine (which is the replica's).
            new.data.transform(part.matrix_world)
        print("  %-8s %-22s %6d triangles, figure %d" % (part_file, part.name, hs.tris(part), hs.tris(new)))
    for m in list(bpy.data.meshes):
        if m.users == 0:
            bpy.data.meshes.remove(m)
    hs.export(path, False)
    wear.unsuffix(path)


def main() -> None:
    for f in FILES:
        write(f)
    print("wrote the figure copies in", ", ".join(FILES))


if __name__ == "__main__":
    main()
