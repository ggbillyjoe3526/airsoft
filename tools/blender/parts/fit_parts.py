"""Moves each part in a replica's parts file onto its replica's mount points (BL1, 2026-11-04).

Every part in assets/models/replicaParts/<id>.glb has its origin on the mount it sits on (game/play/replica_parts.gd):
a barrel or muzzle part on BarrelEnd, a light on TorchMount, a grip on GripMount, an optic on OpticMount, a magazine
on MagWell. When a replica's model changes shape (the AEG was cut to CQB length in BL1), this puts each part's origin
back on the model's empty, carrying its children (figure copies sit beside the part and are moved with it). The
magazines are built to their lengths by tools/blender/parts/magazines.py, from the replica's own magazine. Running it
again changes nothing.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3), after the replica's own script:

    python -I tools/blender/parts/fit_parts.py <repo root>

It rewrites assets/models/replicaParts/aeg.glb. Re-run tools/blender/replicas/sniper.py and smg.py after it (the rifle's parts
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


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mounts(replica: str) -> dict:
    """The replica model's empties by name, in its space."""
    reset()
    hs.import_glb(os.path.join(ROOT, "assets/models/replicas/%s.glb" % replica))
    return {o.name: o.matrix_world.translation.copy() for o in bpy.data.objects if o.type == "EMPTY"}


def fit(replica: str) -> None:
    at = mounts(replica)
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
    hs.export(path, False)  # the parts' surface kinds (their meshes' extras, MQ2) with them
    print("  %s: %d parts moved" % (replica, moved))


if __name__ == "__main__":
    for f in PARTS_FILES:
        fit(f)
    print("wrote", ", ".join(PARTS_FILES))
