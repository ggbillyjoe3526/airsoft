"""Woodland's earth bank (WG2): assets/models/props/earth_bank.glb, the bank of earth and leaf litter the game draws
under a log, a root plate, the sawbench or the boards where the ground falls away inside their box
(PropDressConfig.Lay.GROUND), so a model standing on the ground at its box's middle never floats over a slope, and
the box under it, which stops a BB, is never empty air.

A slab of earth a metre each way, nearly square, its sides bulging a little and its top lumpy with leaf litter and
moss; the game stretches it to the part of each box it fills. Budget 340 triangles (it is seen only on slopes, under
another model). Plain vertex colours, no texture.

    python -I tools/blender/maps/earth_bank.py <repo root>
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402
import woodkit as wk  # noqa: E402
import hardsurface as hs  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET = 340


def colour(c: Vector, n: Vector) -> str:
    """The ground's own earth (LookConfig's "earth") and leaf litter, so a bank reads as the slope it fills, not a dark
    slab in a shed's shade."""
    if n.z > 0.5:
        return "Litter" if wk.lump(c, 0.3, 1.0) > -0.1 else "Soil"
    return "Soil" if wk.lump(c, 0.25, 2.0) > -0.2 else "SoilDark"


def build() -> object:
    hs.reset()
    wk.paint_all()
    r = wk.rng(1500)
    b = hs.Builder("EarthBank", [])
    wk.blob(b, Vector((0.0, 0.0, 0.5)), Vector((0.5, 0.5, 0.5)), 3, r, colour, rough=0.08, seed=4.0, square=0.3)
    ob = b.build()
    wk.finish(ob, 50.0)
    wk.fit_box(ob, (-0.5, -0.5, 0.0), (0.5, 0.5, 1.0))
    return ob


def main() -> None:
    ob = build()
    mk.report(ob, "earth_bank", BUDGET)
    print("  wrote", mk.export_prop(ob, "earth_bank"))


if __name__ == "__main__":
    main()
