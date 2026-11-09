"""Woodland's log palisade (WG3, Dev 3): assets/models/props/palisade.glb (one stake) and palisade_rail.glb (one
rail, a metre of it), for the 108 fence blocks of the field's boundary and both camps.

From the owner's photos (references/maps/woodland/04-log-palisade): peeled softwood stakes, weathered silver-grey with
darker streaks, standing shoulder to shoulder, each sharpened by four axe cuts to a point that shows the paler wood,
the tips not quite level; a stake's foot dark where the ground keeps it wet. Two horizontal rails hold them on the
inside (photo 3's wire ties are left out: too fine to see from the field).

PropDressConfig's STAKES lay stands the stake side by side along a fence block (about `pitch` m each, stretched to
fill it, each turned at random and a little shorter or taller under the box's top) and lays two rails along its side
towards the field's middle, so a palisade follows its block, slope steps and all, and never reaches past it.

Budget 1,000 triangles a 4 m section (/mnt/project-files/art/woodland-model-list.md): about 17 stakes at 56 and a
metre of rail at 16 a 4 m section, so the stake carries most of it. Plain vertex colours, no texture.

    python -I tools/blender/maps/palisade.py <repo root>
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402  first: it sets up bpy and the replica helpers
import hardsurface as hs  # noqa: E402
import timberkit as wk  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET_4M = 1000
PITCH = 0.235       # a stake's share of the fence (m): PropDressConfig.stake_pitch
HEIGHT = 3.3        # built this tall (m); the lay stretches it to its block
R = 0.125           # the stake's radius: a touch over half the pitch, so neighbours meet with no gap to see through
SIDES = 8
TIP = 0.34          # the axe-cut point's length
WET = 0.55          # the dark foot's top (m over the stake's foot: the block reaches 0.3 m under the ground)
FACETS = 4
RAIL_R = 0.055
RAIL_SIDES = 6


def stake() -> object:
    """One stake: three bands of bark up the sides (the foot dark), then four axe facets to an off-centre point."""
    b = hs.Builder("Stake", [])
    rng = random.Random(4)
    bm = b.bm
    turn = math.pi / SIDES
    tip_y = HEIGHT
    slope = TIP / R
    # the facets' directions, a quarter turn apart, and the cut each makes: y = tip - slope * (p . d)
    dirs = [turn + math.pi / 4 + k * math.pi / 2 for k in range(FACETS)]
    apex = Vector((0.012, -0.008, tip_y))

    def cut_y(ang: float, r: float) -> float:
        return min(apex.z - slope * (r * math.cos(ang - d) - (apex.x * math.cos(d) + apex.y * math.sin(d)))
                   for d in dirs)

    angles = [turn + 2.0 * math.pi * i / SIDES for i in range(SIDES)]
    bands = [0.0, WET, 1.75, None]  # None: where each column meets the cut
    radii = [R * 1.02, R, R * 0.985, R * 0.97]
    rings = []
    for k, y in enumerate(bands):
        ring = []
        for i, a in enumerate(angles):
            r = radii[k] * (1.0 + (rng.uniform(-0.04, 0.04) if 0 < k < 3 else 0.0))
            yy = cut_y(a, r) if y is None else y
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), yy)))
        rings.append(ring)
    streak = ["Bark", "BarkLight", "Bark", "BarkDark", "BarkLight", "Bark", "BarkDark", "Bark"]
    faces = []
    for k in range(len(rings) - 1):
        for i in range(SIDES):
            j = (i + 1) % SIDES
            f = bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
            f.material_index = b.mat("Damp" if k == 0 else streak[i])
            faces.append(f)
    top = bm.verts.new(apex)
    # each facet: the apex and the ring's corners on its plane (the corners between two facets on both)
    for i in range(SIDES):
        j = (i + 1) % SIDES
        f = bm.faces.new((rings[-1][i], rings[-1][j], top))
        f.material_index = b.mat("Cut" if (i // 2) % 2 == 0 else "CutShade")
        faces.append(f)
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    ob = b.build()
    return ob


def rail() -> object:
    """A metre of rail: a thin peeled pole along x, bark streaked, its ends cut (a gate's end shows them)."""
    b = hs.Builder("Rail", [])
    f = wk.Frame(Vector((-0.5, 0.0, -RAIL_R)), Vector((0.5, 2 * RAIL_R, RAIL_R)))
    wk.log(b, f, (-0.5, RAIL_R, 0.0), (0.5, RAIL_R, 0.0), RAIL_R, ["Bark", "BarkLight", "BarkDark"],
           sides=RAIL_SIDES, rings=1, wobble=0.0, rng=random.Random(9))
    return b.build()


def main() -> None:
    hs.reset()
    wk.paints({"CutShade": (0xcfc2a0, 0.9)})
    ob = stake()
    mk.clean(ob)
    n = round(4.0 / PITCH)
    tris = hs.tris(ob)
    mk.report(ob, "palisade", int(BUDGET_4M / n))
    mk.export_prop(ob, "palisade")
    hs.reset()
    wk.paints()
    ob = rail()
    mk.clean(ob)
    mk.report(ob, "palisade_rail", 20)
    mk.export_prop(ob, "palisade_rail")
    # a section's two rails are one model each, stretched along its block
    print("palisade: a stake %d triangles, %d a 4 m section with its two rails" % (tris, n * tris + 2 * hs.tris(ob)))


if __name__ == "__main__":
    main()
