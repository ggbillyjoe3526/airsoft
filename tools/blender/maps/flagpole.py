"""The flagpole (Dev 3 map models, all maps): Attack / Defend's two poles and Elimination's overtime flag, after the
owner's photos (art/references/maps/william-2026-11-09/flag_pole/): a sectional pole, black below and bare aluminium
on top, joined by twist-lock collars with thumb screws, ribbed marks along the black sections and a flat cap (no ball
finial: the owner, 2026-11-09), on a weighted base with a halyard over a sheave at the top and a horn cleat, because
the round's flag climbs the pole.

Sizes match FlagViewConfig (3.4 m pole, base 0.28 m across its foot, the halyard's runs 0.058 m either side, the cleat
at 0.85 m) so the cloth and ring sit where they always have. Budget 2,500 triangles (aim ~95%).

Godot space is +Y up, +X the side the cloth flies from; Blender's +Z is up and Godot's +Z is Blender's -Y.

Run: python3 tools/blender/maps/flagpole.py   (pip install bpy==5.2.3)
Writes assets/models/props/flagpole.glb; then `godot --headless --path . --import`.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vertex_paint as vp  # noqa: E402
import hardsurface as hs  # noqa: E402  (vertex_paint puts replicas/ on the path)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "models", "props",
                   "flagpole.glb")
BUDGET = 2500

PALETTE = {
    "pole_black": (0x24272D, vp.FIXED),
    "pole_alu": (0xB4BAC2, vp.FIXED),
    "collar": (0x3A3F48, vp.FIXED),
    "knob": (0x17191D, vp.FIXED),
    "base": (0x2B303A, vp.FIXED),
    "rubber": (0x1A1C20, vp.FIXED),
    "bolt": (0x8A9096, vp.FIXED),
    "rope": (0xE9E2CF, vp.FIXED),
}

# Heights (m) up the pole.
BASE_TOP = 0.14
SOCKET_TOP = 0.27
JOINTS = (1.25, 2.30)          # the twist-lock collars
TOP = 3.30                     # the top of the aluminium section
SHEAVE_Z = 3.362               # the truck's axle
TRUCK_R = 0.034                # the truck's radius, a little over the pole's (the photos' slim top)
ROPE_IN = 0.13                 # how far under the axle the halyard's runs turn in to the truck
RADII = (0.032, 0.029, 0.025)  # the three sections, bottom to top
ROPE_LOW = 0.30                # FlagViewConfig.cloth_low
ROPE_OFF = 0.058               # FlagViewConfig.rope_offset
ROPE_R = 0.007
CLEAT_Z = 0.85
SEG = 16                       # sides of the pole's sections


def lathe_z(b: hs.Builder, profile: list, mat: str, seg: int = SEG, centre=(0.0, 0.0, 0.0), cap: bool = False):
    """A profile turned about the pole's axis; open-ended unless `cap` (sleeves and sections hide their ends)."""
    return vp.lathe(b, profile, mat, seg, centre, "z", cap)


def collar(b: hs.Builder, z: float, below: float, above: float, knob_side: float) -> None:
    """A twist-lock collar at `z`: a flared sleeve from the section below onto the thinner one above, a knurled band
    and a thumb screw on the back (-X)."""
    w = below + 0.008
    lathe_z(b, [(z - 0.05, below), (z - 0.04, w), (z + 0.02, w), (z + 0.035, w - 0.003), (z + 0.05, above)],
            "collar")
    lathe_z(b, [(z - 0.025, w), (z - 0.022, w + 0.0015), (z + 0.002, w + 0.0015), (z + 0.005, w)], "knob")
    # the thumb screw: a stem and a T wing across it
    thumb(b, -w * knob_side, z - 0.01)


def thumb(b: hs.Builder, x0: float, z: float) -> None:
    """A thumb screw standing out along -X from `x0` at height `z`: a round stem and a flat wing."""
    vp.lathe(b, [(-0.014, 0.0055), (0.0, 0.0055)], "collar", 8, (x0, 0.0, z), "x")
    b.prism([(-0.013, z - 0.0045), (0.013, z - 0.0045), (0.013, z + 0.0045), (-0.013, z + 0.0045)], "x",
            x0 - 0.024, x0 - 0.014, "knob")


def rope(b: hs.Builder, p0: tuple, p1: tuple) -> None:
    """A straight run of the halyard from `p0` to `p1` (Blender points), six-sided, its faces turned out."""
    a, c = hs.Vector(p0), hs.Vector(p1)
    axis = (c - a).normalized()
    u = axis.cross(hs.Vector((1.0, 0.0, 0.0))).normalized()
    v = axis.cross(u)
    rings = [[tuple(o + (u * math.cos(2.0 * math.pi * i / 6) + v * math.sin(2.0 * math.pi * i / 6)) * ROPE_R)
              for i in range(6)] for o in (a, c)]
    vp.orient_loft(b.loft(rings, "rope", cap0=False, cap1=True), rings, False, True)


def band(b: hs.Builder, z: float, r: float) -> None:
    """A ribbed mark round a black section (the photo's pale-edged rings)."""
    lathe_z(b, [(z - 0.005, r), (z, r + 0.002), (z + 0.005, r)], "collar")


def build() -> hs.bpy.types.Object:
    vp.materials(PALETTE)
    b = hs.Builder("Flagpole", [])
    # the weighted base: a rubber foot ring, a chamfered steel dish, a socket boss with a lip and four bolts
    lathe_z(b, [(0.0, 0.0), (0.0, 0.28), (0.018, 0.28), (0.022, 0.274)], "rubber", seg=32)
    lathe_z(b, [(0.022, 0.274), (0.03, 0.272), (0.11, 0.232), (0.13, 0.222), (BASE_TOP, 0.21), (BASE_TOP, 0.0)],
            "base", seg=32)
    lathe_z(b, [(BASE_TOP - 0.001, 0.07), (BASE_TOP + 0.02, 0.066), (SOCKET_TOP - 0.03, 0.05),
                (SOCKET_TOP - 0.012, 0.05), (SOCKET_TOP - 0.008, 0.044), (SOCKET_TOP, RADII[0] + 0.004),
                (SOCKET_TOP, RADII[0])], "base", seg=SEG)
    for i in range(4):
        a = math.pi * 0.25 + i * math.pi * 0.5
        c = (0.15 * math.cos(a), 0.15 * math.sin(a), 0.0)
        vp.lathe(b, [(BASE_TOP - 0.02, 0.014), (BASE_TOP + 0.008, 0.014), (BASE_TOP + 0.008, 0.0)], "bolt", 6, c,
                 "z")
    # the socket's thumb screw
    thumb(b, -0.05, SOCKET_TOP - 0.06)
    # the three sections, black, black, aluminium
    lows = (SOCKET_TOP, JOINTS[0] + 0.05, JOINTS[1] + 0.05)
    highs = (JOINTS[0] - 0.05, JOINTS[1] - 0.05, TOP)
    for i, (lo, hi) in enumerate(zip(lows, highs)):
        lathe_z(b, [(lo, RADII[i]), (hi, RADII[i])], "pole_alu" if i == 2 else "pole_black")
    for z in (0.62, 0.95, 1.62, 1.95):
        band(b, z, RADII[0] if z < JOINTS[0] else RADII[1])
    collar(b, JOINTS[0], RADII[0], RADII[1], 1.0)
    collar(b, JOINTS[1], RADII[1], RADII[2], 1.0)
    # the top: a ferrule, the truck (a round pulley housing across the pole, its axle along X, the halyard running
    # into it either side), and a flat cap (no ball: the owner, 2026-11-09)
    lathe_z(b, [(TOP - 0.02, RADII[2]), (TOP - 0.015, 0.03), (TOP + 0.012, 0.03), (TOP + 0.016, 0.022)], "collar")
    hub = TRUCK_R - 0.006
    vp.lathe(b, [(-0.016, 0.0), (-0.016, hub), (-0.012, TRUCK_R), (0.012, TRUCK_R), (0.016, hub), (0.016, 0.0)],
             "collar", 20, (0.0, 0.0, SHEAVE_Z), "x")
    for side in (-1.0, 1.0):  # the axle's nuts
        vp.lathe(b, [(0.0, 0.009), (0.007 * side, 0.009), (0.007 * side, 0.0)], "bolt", 6,
                 (0.016 * side, 0.0, SHEAVE_Z), "x")
    top = SHEAVE_Z + TRUCK_R
    lathe_z(b, [(top - 0.01, 0.0), (top - 0.01, 0.012), (top + 0.004, 0.011), (top + 0.006, 0.0)], "collar", seg=16)
    # the halyard's two runs from the cloth's foot into the truck
    for side in (-1.0, 1.0):
        y = -side * ROPE_OFF
        vp.lathe(b, [(ROPE_LOW, ROPE_R), (SHEAVE_Z - ROPE_IN, ROPE_R)], "rope", 6, (0.0, y, 0.0), "z")
        rope(b, (0.0, y, SHEAVE_Z - ROPE_IN), (0.0, -side * (TRUCK_R - 0.004), SHEAVE_Z))
    # the horn cleat on the +Z (Godot) side, horns along the pole, the halyard's tail wrapped on it
    y0 = -(RADII[0] - 0.002)
    b.box((-0.012, y0 - 0.014, CLEAT_Z - 0.022), (0.012, y0, CLEAT_Z + 0.022), "base")
    z = CLEAT_Z
    b.prism([(y0 - 0.012, z - 0.03), (y0 - 0.02, z - 0.052), (y0 - 0.028, z - 0.048), (y0 - 0.028, z + 0.048),
             (y0 - 0.02, z + 0.052), (y0 - 0.012, z + 0.03)], "x", -0.009, 0.009, "base")
    # the halyard's tail, a few turns round the horns
    for k, dz in enumerate((-0.03, -0.01, 0.01, 0.03)):
        tilt = 0.35 if k % 2 == 0 else -0.35
        faces = vp.lathe(b, [(-0.013, 0.0045), (0.013, 0.0045)], "rope", 6, (0.0, y0 - 0.021, 0.0), "x")
        b.transform(faces, hs.Matrix.Translation((0.0, 0.0, z + dz)) @ hs.rot_about("y", tilt, (0.0, 0.0, 0.0)))
    return b


def main() -> None:
    hs.reset()
    b = build()
    ob = b.build()
    vp.bake(ob, PALETTE)
    n = hs.tris(ob)
    print("flagpole tris", n, "of", BUDGET)
    assert n <= BUDGET, "over budget"
    vp.export(os.path.abspath(OUT))


if __name__ == "__main__":
    main()
