"""Moves each part in a replica's parts file onto its replica's mount points (BL1, 2026-11-04).

Every part in assets/models/replicaParts/<id>.glb has its origin on the mount it sits on (game/play/replica_parts.gd):
a barrel or muzzle part on BarrelEnd, a light on TorchMount, a grip on GripMount, an optic on OpticMount, a magazine
on MagWell. When a replica's model changes shape (the AEG was cut to CQB length in BL1), this puts each part's origin
back on the model's empty, carrying its children (figure copies sit beside the part and are moved with it), and sizes
each magazine part's length below the well to the replica's own magazine (MAG_LENGTH: a hi-cap a little longer, a
low-cap shorter), so a magazine part keeps its place beside a replica that changed length. Running it again changes
nothing.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3), after the replica's own script:

    python -I tools/blender/parts/fit_parts.py <repo root>

It rewrites assets/models/replicaParts/aeg.glb. Re-run tools/blender/replicas/sniper.py after it (the rifle's parts
are built from this file).
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "replicas"))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import hardsurface as hs  # noqa: E402

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
# The parts files fitted, by replica id.
PARTS_FILES = ["aeg"]
# Each part slot (the name's prefix) and the replica's empty its origin sits on.
MOUNTS = {
    "barrel_": "BarrelEnd",
    "muzzle_": "BarrelEnd",
    "light_": "TorchMount",
    "grip_": "GripMount",
    "optic_": "OpticMount",
    "magazine_": "MagWell",
}
# A magazine part's length below its replica's magazine well, against the replica's own magazine's (the hi-cap as the
# first AEG's was beside its standard one, the low-cap shorter).
MAG_LENGTH = {"magazine_hiCap": 1.05, "magazine_lowCap": 0.65}
# A part's figure copy: its name with this suffix, sized as the part is.
FIGURE_SUFFIX = "_Figure"


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def lowest(ob: bpy.types.Object) -> float:
    """The lowest point of a mesh object, in the file's space."""
    return min((ob.matrix_world @ v.co).z for v in ob.data.vertices)


def mounts(replica: str) -> tuple:
    """The replica model's empties by name, in its space, and its own magazine's lowest point."""
    reset()
    hs.import_glb(os.path.join(ROOT, "assets/models/replicas/%s.glb" % replica))
    mag = bpy.data.objects.get("Magazine")
    return ({o.name: o.matrix_world.translation.copy() for o in bpy.data.objects if o.type == "EMPTY"},
            lowest(mag) if mag is not None else None)


def size_magazine(ob: bpy.types.Object, well_z: float, own_bottom: float) -> None:
    """A magazine part (or its figure copy) stretched or squeezed below the well to MAG_LENGTH of the replica's own."""
    ratio = MAG_LENGTH.get(ob.name.removesuffix(FIGURE_SUFFIX))
    if ratio is None or own_bottom is None:
        return
    k = ratio * (well_z - own_bottom) / (well_z - lowest(ob))
    if abs(k - 1.0) < 1e-4:
        return
    for o in [ob] + list(ob.children_recursive):
        if o.type != "MESH":
            continue
        to_local = o.matrix_world.inverted()
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            if w.z < well_z:
                w.z = well_z + (w.z - well_z) * k
                v.co = to_local @ w
    print("  %s: length below the well x%.3f" % (ob.name, k))


def fit(replica: str) -> None:
    at, own_bottom = mounts(replica)
    reset()
    path = os.path.join(ROOT, "assets/models/replicaParts/%s.glb" % replica)
    bpy.ops.import_scene.gltf(filepath=path)
    moved = 0
    for ob in [o for o in bpy.data.objects if o.parent is None]:
        prefix = next((p for p in MOUNTS if ob.name.startswith(p)), None)
        if prefix is None:
            continue
        target = at.get(MOUNTS[prefix])
        if target is None:
            raise SystemExit("%s has no %s empty for %s" % (replica, MOUNTS[prefix], ob.name))
        shift = target - ob.location
        if shift.length > 1e-5:
            ob.location = Vector(target)
            moved += 1
            print("  %s: %s -> %s" % (ob.name, tuple(round(c, 4) for c in target - shift),
                                     tuple(round(c, 4) for c in target)))
        if prefix == "magazine_":
            bpy.context.view_layer.update()
            size_magazine(ob, target.z, own_bottom)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=True,
            export_animations=False, export_yup=True, export_draco_mesh_compression_enable=False,
            export_extras=False, export_cameras=False, export_lights=False)
    print("  %s: %d parts moved" % (replica, moved))


if __name__ == "__main__":
    for f in PARTS_FILES:
        fit(f)
    print("wrote", ", ".join(PARTS_FILES))
