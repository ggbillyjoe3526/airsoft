"""The AEG Rifle's model (BL1, 2026-11-04), from the owner's reference photos (an M4-style carbine: flat-top upper,
free-float rail, flip-up sights, a stock with battery tubes, a polymer magazine). Generic: no maker's marks.

It keeps the old model's contract (docs/CC0_ASSETS.md › Replica models): the empties (Muzzle, BarrelEnd, RearSight,
FrontSight, MagWell, GripMount, OpticMount, TorchMount); the rear ones where they were, so the sight line and the
figures' hold don't move, and the front ones (Muzzle, BarrelEnd, FrontSight, TorchMount) SHORT metres back with the
carbine-length handguard (owner, 2026-11-04: shorter, then "too short now"; tools/blender/parts/fit_parts.py moves
the parts); the armature AEGRifle with the same bones and the same five clips (Fire, Reload,
Selector, SightsFold, Inspect) of the same lengths; the paintable materials Body, Furniture, Detail, Accent and Metal
(plus Rubber and BB, kept as drawn). `Figure` is the figures' cut-down copy.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/replicas/aeg.py <repo root>

It writes assets/models/replicas/aeg.glb. Re-run tools/blender/parts/fit_parts.py, then
tools/blender/replicas/sniper.py after it (each is built from this file).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import hardsurface as hs  # noqa: E402

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
OUT = os.environ.get("BL_OUT") or os.path.join(ROOT, "assets/models/replicas/aeg.glb")
ARMATURE = "AEGRifle"
FPS = 60

# The owner's rulings (2026-11-04): shorter than the first pass (14:12), "too short now" at CQB length (15:10), then
# "match the reference images as close as possible" (16:49): the length of his main photo's carbine, about 67 cm with
# the stock in. The barrel loses SHORT and the stock sits STOCK_IN forward on its tube (fully in, against the castle
# nut, as in the photo); the parts file follows (tools/blender/parts/fit_parts.py).
SHORT = 0.231
STOCK_IN = 0.078

# The contract's points (Blender space, metres). The rail top and sight line are where they were; the bore sits
# 2.95 cm under the rail top, as in the owner's photos (it was 3.95).
BORE_Z = 0.044
BARREL_END = (0.0, 0.570 - SHORT, BORE_Z)
MUZZLE = (0.0, 0.611 - SHORT, BORE_Z)
RAIL_TOP = 0.0735
RAIL_BASE = 0.0635
# The iron sights' line: 2.45 cm over the rail, so the flip-up sights stand as tall as the owner's photos'
# (it was 1.45).
SIGHT_Z = 0.098
# The rear sight's leaf (its hinge, the rearSight bone): 13 cm behind the receiver's front, as in the photo.
REAR_SIGHT_Y = -0.032
# The front sight base on the barrel against the quad rail's front, as on the owner's photos' carbines; the post
# stands between its ears.
FRONT_SIGHT_Y = 0.318
# The front sight base's length on the barrel (from the handguard's cap to its front) and its platform's top, where
# the ears stand (and the frontSight bone's head).
FSB_Y = (0.277, FRONT_SIGHT_Y + 0.0085)
# The ears' top: 3.4 cm over the handguard's rail, as in the photo.
EARS_TOP = SIGHT_Z + 0.0090
FSB_TOP = 0.064


def fsb_rear(z: float) -> float:
    """The front sight base's sloping back edge: its y at height `z` (the A's back leg, up to the ears' top)."""
    y0, z0 = FSB_Y[0] + 0.0005, BORE_Z + 0.020
    return y0 + (z - z0) / (EARS_TOP - z0) * (FRONT_SIGHT_Y - 0.0060 - y0)


FA_Z = 0.046
# The lower receiver, grip and magazine well (BL1, critic against the owner's photos: the receiver and magazine a third
# too tall). Drawn in the first pass's heights; lz() lifts the lower's top to SEAM and its depth to LOWER_K of what it
# was, so the rail top to the magazine well's foot is 0.103 m, as in the photos (it was 0.144).
SEAM = 0.033
LOWER_K = 0.87
# The pistol grip: raked this far back from vertical (degrees) about its top, and this long, as in the photo.
GRIP_RAKE = 30.0
GRIP_LENGTH = 0.118
# How far the grip's foot turns from square to its rake, toward level (degrees).
GRIP_FOOT_TURN = 17.0
# The grip's top (in the lower; first-pass height), its front tucked under the trigger guard's back, as in the photo.
GRIP_TOP_Y = -0.020
GRIP_TOP_Z = -0.016
# How far the guard, the trigger and the lower's underside round them sit below the first pass's (first-pass metres):
# the guard as low under the rail as the photo's.
GUARD_DROP = 0.0075


def lz(z: float) -> float:
    """A height on the first pass's lower receiver, on this one's."""
    return SEAM + z * LOWER_K


def mz(z: float) -> float:
    """A height on the first pass's magazine: the part in the well follows the lower, the part below it moves up."""
    return lz(z) if z >= -0.076 else z + lz(-0.076) + 0.076


# The magazine's centre along the rifle (in the well) and its depth (MAG_HD), as in the photo.
MAG_Y = 0.0595

EMPTIES = {
    "BarrelEnd": BARREL_END, "Muzzle": MUZZLE, "FrontSight": (0.0, FRONT_SIGHT_Y, SIGHT_Z),
    "RearSight": (0.0, REAR_SIGHT_Y + 0.0013, SIGHT_Z), "MagWell": (0.0, MAG_Y, mz(-0.076)),
    "GripMount": (0.0, 0.215, 0.0216),
    "OpticMount": (0.0, 0.025, RAIL_TOP), "TorchMount": (0.0259, 0.195, 0.04725),
}

# Layout.
UPPER_Y = (-0.085, 0.100)
UPPER_HW = 0.0150
LOWER_HW = 0.0155
WELL_HW = 0.0195
# The quad-rail handguard (the owner's photos): 0.92 of the upper's length, its body square round the barrel with its
# top rail level with the upper's.
GUARD_Y = (0.100, 0.2765)
# The delta ring's length at the handguard's back, and the raised bridge of rail over the receiver's front (y from, to)
# and how far it stands over the rail line, as in the photo.
DELTA_LEN = 0.019
BRIDGE_Y = (0.070, 0.130)
BRIDGE_RISE = 0.012
# The delta ring's radius round the handguard's middle: its top 4 mm under the rail top, as in the photo.
DELTA_R = 0.0250
# The ring's centre below the handguard's middle, so its foot reaches down past the body, as the photo's.
DELTA_DROP = 0.0028
GUARD_HW = 0.0165
GUARD_Z = (0.031, RAIL_BASE)
TUBE_Z = 0.044
TUBE_R = 0.0148
TUBE_Y = (-0.335 + STOCK_IN, -0.094)
MAG_TOP = (0.0, MAG_Y, mz(-0.076))
MAG_HW = 0.0150
MAG_HD = 0.0305
# The magazine's base (owner, 15:10: "slightly too long"), in the first pass's heights (mz() moves it up with the
# lower): 9.9 cm below the well's foot with its base plate, as in the owner's photos; the body's stations below the
# well are scaled to fit.
MAG_BOTTOM = -0.1585

# Bones: name -> head (each points +Y, 0.0313 long, roll 0, as the old file's).
BONES = {
    "root": (0.0, 0.0, 0.0),
    "trigger": (0.0, 0.004, lz(-0.031)),
    "selector": (-LOWER_HW, -0.030, lz(-0.012)),
    "magRelease": (WELL_HW, 0.034, lz(-0.012)),
    "chargingHandle": (0.0, -0.098, 0.0599),
    "dustCover": (UPPER_HW + 0.0012, 0.026, 0.0335),
    "hopDial": (0.0075, 0.026, 0.045),
    "rearSight": (0.0, REAR_SIGHT_Y, 0.0795),
    "frontSight": (0.0, FRONT_SIGHT_Y, FSB_TOP),
    "magazine": MAG_TOP,
}
BONE_LENGTH = 0.0313

# Plain colours (the game paints the five scheme materials; these are what a viewer without it shows).
MATERIALS = {
    "Body": (0x24282f, 0.5, 0.0), "Furniture": (0x2f6fd6, 0.5, 0.0), "Detail": (0x30343b, 0.55, 0.0),
    "Accent": (0xf2f0ea, 0.5, 0.0), "Metal": (0x484d56, 0.4, 0.4), "Rubber": (0x1c1d20, 0.8, 0.0),
    "BB": (0xf4f1e8, 0.3, 0.0),
}


# ------------------------------------------------------------------------------------------------------ picatinny

def picatinny(b: hs.Builder, y0: float, y1: float, mat: str, place: Matrix, teeth_from: float = None) -> None:
    """A rail from y0 to y1 along its own +Y, base at its z 0, built upright and moved by `place`."""
    base = [(-0.0085, -0.004), (0.0085, -0.004), (0.0085, 0.0042), (0.0106, 0.0065), (0.0106, 0.0070),
            (-0.0106, 0.0070), (-0.0106, 0.0065), (-0.0085, 0.0042)]
    faces = b.prism(base, "y", y0, y1, mat)
    tooth = [(-0.0106, 0.0069), (0.0106, 0.0069), (0.0104, 0.0074), (0.0078, 0.0100), (-0.0078, 0.0100),
             (-0.0104, 0.0074)]
    pitch = 0.0100
    start = y0 + 0.0026 if teeth_from is None else teeth_from
    y = start
    while y + 0.0050 <= y1 - 0.0010:
        faces += b.prism(tooth, "y", y, y + 0.0050, mat)
        y += pitch
    b.transform(faces, place)


def rail_on(face: str, y0: float, y1: float, x: float = 0.0, z: float = 0.0) -> Matrix:
    """Where a rail on the `face` of the receiver or rail goes: its base on that face."""
    if face == "top":
        return Matrix.Translation((x, 0.0, z))
    if face == "bottom":
        return Matrix.Translation((x, 0.0, z)) @ Matrix.Rotation(math.pi, 4, "Y")
    if face == "right":
        return Matrix.Translation((x, 0.0, z)) @ Matrix.Rotation(math.pi * 0.5, 4, "Y")
    return Matrix.Translation((x, 0.0, z)) @ Matrix.Rotation(-math.pi * 0.5, 4, "Y")


# --------------------------------------------------------------------------------------------------------- parts

def upper() -> list:
    out = []
    b = hs.Builder("Upper", ["Body"])
    sec = [(-UPPER_HW, SEAM), (UPPER_HW, SEAM), (UPPER_HW, 0.055), (0.0115, 0.0590), (0.0098, RAIL_BASE),
           (-0.0098, RAIL_BASE), (-0.0115, 0.0590), (-UPPER_HW, 0.055)]
    b.prism(sec, "y", UPPER_Y[0], UPPER_Y[1], "Body")
    # Brass deflector, behind the ejection port.
    b.prism([(-0.017, 0.042), (-0.001, 0.042), (0.002, 0.051), (-0.003, 0.0590), (-0.017, 0.0590)], "x",
            UPPER_HW - 0.002, UPPER_HW + 0.0062, "Body")
    # Forward-assist housing: a round boss on the right at the back, blending forward into the side in a teardrop.
    rings = []
    for y, r, dx in ((-0.0660, 0.0089, 0.0016), (-0.0600, 0.0090, 0.0016), (-0.0540, 0.0085, 0.0008),
                     (-0.0480, 0.0072, -0.0008), (-0.0420, 0.0054, -0.0028), (-0.0370, 0.0034, -0.0050)):
        rings.append([(UPPER_HW + dx + r * math.cos(t), y, FA_Z + r * math.sin(t))
                      for t in (2.0 * math.pi * i / 24 for i in range(24))])
    b.loft(rings, "Body")
    ob = b.build()
    cutters = []
    c = hs.Builder("c_port", ["Body"])
    c.box((UPPER_HW - 0.0055, 0.002, 0.0345), (0.03, 0.050, 0.0540), "Body")
    cutters.append(c.build())
    c = hs.Builder("c_ch", ["Body"])
    c.box((-0.0062, UPPER_Y[0] - 0.01, 0.048), (0.0062, UPPER_Y[0] + 0.012, 0.070), "Body")
    cutters.append(c.build())
    # Machining lines along each side under the shoulder.
    for sx in (-1, 1):
        c = hs.Builder("c_groove", ["Body"])
        c.box((sx * UPPER_HW - 0.0006, UPPER_Y[0] + 0.010, 0.0525), (sx * UPPER_HW + 0.0006, UPPER_Y[1] - 0.008,
              0.0537), "Body")
        cutters.append(c.build())
    hs.cut(ob, cutters)
    hs.finish(ob, 0.0008)
    out.append(ob)

    # Inside the port: the bolt face the hop dial shows through.
    b = hs.Builder("PortFloor", ["Detail"])
    b.box((UPPER_HW - 0.0070, 0.001, 0.0335), (UPPER_HW - 0.0050, 0.051, 0.0550), "Detail")
    out.append(hs.finish(b.build(), 0.0))

    # Forward-assist plunger, ribbed, out of the back of the boss.
    b = hs.Builder("ForwardAssist", ["Detail"])
    prof = [(0.0, 0.0), (0.0, 0.0068)]
    for i in range(3):
        a = 0.002 + i * 0.0028
        prof += [(a, 0.0068), (a + 0.0005, 0.0075), (a + 0.0018, 0.0075), (a + 0.0023, 0.0068)]
    prof += [(0.0118, 0.0068), (0.0130, 0.0056), (0.0134, 0.0030), (0.0134, 0.0)]
    fa = b.lathe(prof, "Detail", 16)
    b.transform(fa, Matrix.Translation((UPPER_HW + 0.0016, -0.0655, FA_Z)) @ Matrix.Rotation(math.pi, 4, "Z"))
    out.append(hs.finish(b.build(), 0.0003, 1))

    # The upper's rail, full length.
    b = hs.Builder("UpperRail", ["Body"])
    picatinny(b, UPPER_Y[0], UPPER_Y[1], "Body", rail_on("top", 0, 0, 0.0, RAIL_BASE))
    out.append(hs.finish(b.build(), 0.0003, 1))
    return out


def lower() -> list:
    out = []
    b = hs.Builder("Lower", ["Body"])
    # The back: a smooth round tail under the buffer tower (Chaikin-rounded so no facets show in a close-up).
    g = GUARD_DROP
    tail = hs.smooth([(-0.085, 0.018), (-0.093, 0.016), (-0.098, 0.010), (-0.0995, 0.002), (-0.097, -0.008),
                      (-0.091, -0.017), (-0.083, -0.024), (-0.074, -0.029), (-0.050, -0.033 - 0.5 * g),
                      (-0.030, -0.033 - g)], 2)
    prof = [(0.099, 0.0), (-0.085, 0.0)] + tail + [(0.0265, -0.034 - g), (0.0265, -0.014), (0.0935, -0.014),
                                                   (0.0935, -0.004)]
    b.prism([(y, lz(z)) for y, z in prof], "x", -LOWER_HW, LOWER_HW, "Body")
    # Buffer tower: the round boss the tube threads into.
    b.lathe([(0.0, 0.0), (0.0, 0.0172), (0.0130, 0.0172), (0.0130, 0.0)], "Body", 28,
            centre=(0.0, -0.0980, TUBE_Z))
    # Magazine well, its front raked back, flared at the bottom.
    # Its front a little ahead of the upper's, raked back, and flaring out at the foot in one piece with it.
    well = [(0.0260, -0.004), (0.0935, -0.004), (0.0933, -0.016), (0.0929, -0.040), (0.0925, -0.060),
            (0.0260, -0.060)]
    b.prism([(y, lz(z)) for y, z in well], "x", -WELL_HW, WELL_HW, "Body")
    b.loft([[(x, y + 0.0593, lz(z)) for x, y in hs.rounded_rect(hw, hd, 0.004, 2)]
            for z, hw, hd in ((-0.056, WELL_HW, 0.0332), (-0.064, WELL_HW + 0.0008, 0.0339),
                              (-0.0705, WELL_HW + 0.0012, 0.0342))], "Body")
    # Trigger guard: one piece with the lower, a rounded bow whose ends run up into a lug each (the front lug
    # against the well's back, the rear one ahead of the grip), so no daylight between guard and receiver.
    guard = hs.fillet([(0.0275, -0.030, 0.0), (0.0275, -0.0675 - g, 0.011), (-0.0430, -0.0675 - g, 0.004),
                       (-0.0510, -0.0300, 0.0), (-0.0285, -0.0300, 0.0), (-0.0225, -0.0640 - g, 0.008),
                       (0.0235, -0.0640 - g, 0.0065), (0.0235, -0.030, 0.0)], 6)
    b.prism([(y, lz(z)) for y, z in guard], "x", -0.0052, 0.0052, "Body")
    b.prism([(y, lz(z)) for y, z in ((0.0185, -0.030), (0.0275, -0.030), (0.0275, -0.0520 - g),
                                     (0.0220, -0.0480 - g), (0.0185, -0.0400 - g))], "x", -0.0078, 0.0078, "Body")
    # The guard's back runs down into the grip's front, blended (no shelf).
    b.prism([(y, lz(z)) for y, z in ((-0.0360, -0.030), (-0.0255, -0.030), (-0.0255, -0.0380 - g),
                                     (-0.0292, -0.0460 - g), (-0.0360, -0.0430 - g))], "x", -0.0072, 0.0072, "Body")
    # Mag release fence (right) and bolt-catch bosses (left).
    b.prism([(y, lz(z)) for y, z in ((0.024, -0.021), (0.044, -0.021), (0.044, -0.004), (0.024, -0.004))], "x",
            WELL_HW - 0.001, WELL_HW + 0.0018, "Body")
    b.prism([(y, lz(z)) for y, z in ((0.004, -0.004), (0.022, -0.004), (0.022, 0.012), (0.004, 0.012))], "x",
            -LOWER_HW - 0.0016, -LOWER_HW + 0.001, "Body")
    ob = b.build()
    cutters = []
    c = hs.Builder("c_mag", ["Body"])
    c.prism([(x, y + MAG_Y) for x, y in hs.rounded_rect(MAG_HW + 0.0004, MAG_HD + 0.0006, 0.0055, 3)], "z",
            lz(-0.090), lz(-0.010), "Body")
    cutters.append(c.build())
    c = hs.Builder("c_trig", ["Body"])
    c.box((-0.0045, -0.0125, lz(-0.040 - GUARD_DROP)), (0.0045, 0.0138, lz(-0.024)), "Body")
    cutters.append(c.build())
    # The mag release sits in a pocket in its fence.
    c = hs.Builder("c_mr", ["Body"])
    c.lathe([(0.0, 0.0), (0.0, 0.0054), (0.008, 0.0054), (0.008, 0.0)], "Body", 20,
            centre=(WELL_HW - 0.0002, 0.034, lz(-0.012)), axis="x")
    cutters.append(c.build())
    # Side panels on the well.
    for sx, y0 in ((-1, 0.029), (1, 0.050)):
        c = hs.Builder("c_wp", ["Body"])
        f = c.prism(hs.rounded_rect(0.5 * (0.095 - y0), 0.0200 * LOWER_K, 0.004, 3), "x", 0.0, 0.01, "Body")
        c.transform(f, Matrix.Translation((sx * WELL_HW - (0.0006 if sx > 0 else 0.0094), 0.5 * (0.095 + y0),
                                           lz(-0.036))))
        cutters.append(c.build())
    hs.cut(ob, cutters)
    hs.finish(ob, 0.0009)
    out.append(ob)

    # Pins, both sides.
    b = hs.Builder("Pins", ["Metal"])
    for y, z, r in ((0.098, -0.008, 0.0030), (-0.078, 0.009, 0.0030), (0.006, -0.018, 0.0021),
                    (-0.016, -0.018, 0.0021)):
        b.lathe([(-LOWER_HW - 0.0009, 0.0), (-LOWER_HW - 0.0009, r * 0.85), (-LOWER_HW - 0.0005, r),
                 (LOWER_HW + 0.0005, r), (LOWER_HW + 0.0009, r * 0.85), (LOWER_HW + 0.0009, 0.0)], "Metal", 14,
                centre=(0.0, y, lz(z)), axis="x")
    out.append(hs.finish(b.build(), 0.0))

    # Bolt catch (left).
    b = hs.Builder("BoltCatch", ["Detail"])
    b.prism(hs.fillet([(0.008, lz(-0.004), 0.0008), (0.018, lz(-0.002), 0.0015), (0.018, lz(0.008), 0.0015),
                       (0.012, lz(0.010), 0.0008), (0.008, lz(0.004), 0.0008)], 2), "x", -LOWER_HW - 0.0026,
            -LOWER_HW - 0.0004, "Detail")
    out.append(hs.finish(b.build(), 0.0004, 1))

    # Selector markings (the scheme's accent): safe (forward), semi (up), burst, auto (back) around the hub.
    b = hs.Builder("Marks", ["Accent"])
    hub = Vector(BONES["selector"])
    for ang in (0.0, 90.0, 135.0, 180.0):
        a = math.radians(ang)
        p = hub + Vector((0.0, 0.0105 * math.cos(a), 0.0105 * math.sin(a)))
        b.lathe([(0.0, 0.0), (0.0, 0.0010), (0.0003, 0.0010), (0.0003, 0.0)], "Accent", 10,
                centre=(p.x - 0.0003, p.y, p.z), axis="x")
    out.append(hs.finish(b.build(), 0.0))
    return out


def grip() -> object:
    """A pistol grip raked GRIP_RAKE back, lofted through sections with a finger swell."""
    rake = math.radians(GRIP_RAKE)
    down = Vector((0.0, -math.sin(rake), -math.cos(rake)))
    fwd = Vector((0.0, math.cos(rake), -math.sin(rake)))
    top = Vector((0.0, GRIP_TOP_Y, lz(GRIP_TOP_Z)))
    length = GRIP_LENGTH
    # t, half width, front, back
    stations = [(0.00, 0.0128, 0.0085, 0.0215), (0.10, 0.0133, 0.0100, 0.0222), (0.20, 0.0140, 0.0110, 0.0228),
                (0.30, 0.0144, 0.0118, 0.0230), (0.38, 0.0145, 0.0125, 0.0231), (0.47, 0.0145, 0.0130, 0.0232),
                (0.53, 0.0146, 0.0150, 0.0233), (0.59, 0.0146, 0.0195, 0.0234), (0.66, 0.0147, 0.0162, 0.0236),
                (0.80, 0.0148, 0.0165, 0.0240), (0.92, 0.0150, 0.0170, 0.0250), (0.965, 0.0156, 0.0226, 0.0275),
                (0.988, 0.0156, 0.0226, 0.0275), (1.00, 0.0144, 0.0212, 0.0262)]
    fine = []
    for (ta, *va), (tb, *vb) in zip(stations, stations[1:]):
        steps = max(1, int(round((tb - ta) / 0.05)))
        for k in range(steps):
            u = k / steps
            w = u * u * (3.0 - 2.0 * u) if tb - ta > 0.06 else u
            fine.append((ta + (tb - ta) * u, *[a + (b2 - a) * w for a, b2 in zip(va, vb)]))
    fine.append(stations[-1])
    rings = []
    # The foot cut nearer level than square to the rake (the heel lower than the toe), as the photo's.
    k = math.tan(math.radians(GRIP_FOOT_TURN))
    for t, hw, fr, bk in fine:
        c = top + down * (length * t)
        w = min(1.0, max(0.0, (t - 0.80) / 0.12))
        ring = []
        for x, f in hs.superellipse(hw, fr, bk, 2.6, 32):
            ring.append(c + Vector((x, 0.0, 0.0)) + fwd * f + down * (w * k * (fr - f)))
        rings.append(ring)
    b = hs.Builder("Grip", ["Detail"])
    b.loft(rings, "Detail")
    ob = b.build()
    # Stippled panels: shallow recesses on each side.
    cutters = []
    for sx in (-1, 1):
        c = hs.Builder("c_st", ["Detail"])
        f = c.prism(hs.rounded_rect(0.0105, 0.030, 0.006, 3), "x", 0.0, 0.01, "Detail")
        c.transform(f, Matrix.Translation(top + down * 0.064 + fwd * 0.001 + Vector((sx * 0.0141 if sx > 0 else
                    -0.0141 - 0.01, 0.0, 0.0))) @ Matrix.Rotation(-rake, 4, "X"))
        cutters.append(c.build())
    hs.cut(ob, cutters)
    return hs.finish(ob, 0.0010)


def mag_z(z: float) -> float:
    """A height on the first magazine's body (base at -0.222) moved to the shorter one's (base at MAG_BOTTOM)."""
    return -0.076 + (z + 0.076) * (MAG_BOTTOM + 0.076) / (-0.222 + 0.076)


def mag_spine(z: float) -> tuple:
    """Where the magazine's spine is at height `z` (first-pass heights): its y, and its tilt forward. Straight in the
    well, then curving forward 1.3 cm over the body below it, as in the owner's photo."""
    d = max(0.0, -0.075 - z)
    return MAG_TOP[1] + 0.10 * d + 1.4 * d * d, math.atan(0.10 + 2.8 * d)


def magazine() -> object:
    """A polymer magazine, curved forward toward the base, with raised ribs down each side and a square base plate."""
    b = hs.Builder("Magazine", ["Detail", "Rubber", "BB"])
    sec = hs.rounded_rect(MAG_HW, MAG_HD, 0.0055, 2)
    zs = [-0.012, -0.070, -0.071, -0.075, -0.076] + [mag_z(z) for z in (-0.100, -0.130, -0.160, -0.190, -0.212,
                                                                          -0.222)]
    scale = {-0.071: 1.0, -0.075: 1.045, -0.076: 1.045}

    def place(x: float, y: float, z: float, s: float = 1.0) -> tuple:
        cy, tilt = mag_spine(z)
        p = Matrix.Rotation(tilt, 3, "X") @ Vector((x * s, y * s, 0.0))
        return (p.x, cy + p.y, mz(z) + p.z)

    b.loft([[place(x, y, z, scale.get(z, 1.0)) for x, y in sec] for z in zs], "Detail")
    # Five wide ribs down each side below the well, the flutes between them running its whole length.
    rib_zs = [-0.084] + [mag_z(z) for z in (-0.100, -0.130, -0.160, -0.190, -0.212)]
    for sx in (-1, 1):
        for yo in (-0.0228, -0.0114, 0.0, 0.0114, 0.0228):
            rect = [(sx * (MAG_HW - 0.0006), yo - 0.0032), (sx * (MAG_HW + 0.0008), yo - 0.0027),
                    (sx * (MAG_HW + 0.0008), yo + 0.0027), (sx * (MAG_HW - 0.0006), yo + 0.0032)]
            b.loft([[place(x, y, z) for x, y in rect] for z in rib_zs], "Detail")
    # Base plate, square-cornered, its top on the body's last section (no gap) and barely proud of the body's faces.
    cy, tilt = mag_spine(MAG_BOTTOM)
    plate = b.prism(hs.rounded_rect(MAG_HW + 0.0009, MAG_HD + 0.0004, 0.0030, 2), "z", -0.0075, 0.0, "Rubber")
    b.transform(plate, Matrix.Translation((0.0, cy, mz(MAG_BOTTOM) + 0.0005)) @ Matrix.Rotation(tilt, 4, "X"))
    # Feed lips and the top BBs.
    b.box((-0.0045, MAG_TOP[1] + 0.012, mz(-0.012)), (0.0045, MAG_TOP[1] + 0.030, mz(-0.012) + 0.006), "Rubber")
    for i in range(3):
        b.lathe([(-0.003, 0.0), (-0.0026, 0.0015), (-0.0015, 0.0026), (0.0, 0.003), (0.0015, 0.0026),
                 (0.0026, 0.0015), (0.003, 0.0)], "BB", 10, centre=(0.0, MAG_TOP[1] + 0.024 - i * 0.0062,
                 mz(-0.012) + 0.0090 - i * 0.0007), axis="z")
    return hs.finish(b.build(), 0.0006, 1)


def stock() -> list:
    """The buffer tube with its end plate and castle nut, and a crane stock as in the owner's photos (built fully out,
    then slid STOCK_IN in): a body round the tube with a battery tube along each side, a toe plate under its back half
    with a slot along it, a slot down it and a pin hole, the adjustment lever in front of it, and a ribbed butt pad."""
    out = []
    front = -0.186
    slid = Matrix.Translation((0.0, STOCK_IN, 0.0))
    # Buffer tube with its end plate (a QD sling socket on its left) and castle nut, against the receiver's tower.
    b = hs.Builder("Tube", ["Detail", "Metal"])
    b.lathe([(TUBE_Y[0], 0.0), (TUBE_Y[0], TUBE_R - 0.002), (TUBE_Y[0] + 0.002, TUBE_R), (TUBE_Y[1], TUBE_R),
             (TUBE_Y[1], 0.0)], "Detail", 20, centre=(0.0, 0.0, TUBE_Z))
    b.lathe([(-0.0965, 0.0), (-0.0965, 0.0170), (-0.0959, 0.0176), (-0.0941, 0.0176), (-0.0935, 0.0170),
             (-0.0935, 0.0)], "Detail", 20, centre=(0.0, 0.0, TUBE_Z))
    b.lathe([(-0.1010, 0.0), (-0.1010, 0.0166), (-0.1003, 0.0176), (-0.0972, 0.0176), (-0.0965, 0.0166),
             (-0.0965, 0.0)], "Metal", 24, centre=(0.0, 0.0, TUBE_Z))
    b.lathe([(0.0, 0.0), (0.0, 0.0026), (0.0040, 0.0026), (0.0040, 0.0014), (0.0030, 0.0014), (0.0030, 0.0)],
            "Metal", 16, centre=(-0.0168 - 0.0036, -0.0950, TUBE_Z - 0.011), axis="x")
    ob = b.build()
    cutters = []
    for i in range(3):
        c = hs.Builder("c_notch", ["Metal"])
        f = c.box((-0.0022, -0.1015, TUBE_Z + 0.0150), (0.0022, -0.0985, TUBE_Z + 0.0200), "Metal")
        c.transform(f, hs.rot_about("y", math.radians(30 + 120 * i), (0.0, 0.0, TUBE_Z)))
        cutters.append(c.build())
    hs.cut(ob, cutters)
    out.append(hs.finish(ob, 0.0004))

    # The body: flat-topped, chamfered at the front over the nut, its underside sloping up to the tube at the front.
    b = hs.Builder("Stock", ["Furniture"])
    hw = 0.0172
    # Its front face sloped, the top reaching forward over the castle nut, as the photo's.
    body = hs.fillet([(front + 0.0060, 0.024, 0.0), (front + 0.0075, 0.040, 0.0), (front + 0.0055, 0.0585, 0.002),
                      (front + 0.0015, 0.063, 0.002), (-0.330, 0.063, 0.008), (-0.3385, 0.054, 0.0),
                      (-0.3385, 0.0148, 0.0), (front - 0.0015, 0.0148, 0.003)], 4)
    b.prism(body, "x", -hw, hw, "Furniture")
    for sx in (-1, 1):
        b.lathe([(front - 0.012, 0.0), (front - 0.012, 0.0112), (front - 0.006, 0.0146), (-0.3225, 0.0150),
                 (-0.3235, 0.0)], "Furniture", 22, centre=(sx * 0.0162, 0.0, TUBE_Z - 0.004))
    # The toe plate under the body's back half, its lower edge running diagonally down to the toe.
    b.prism(hs.fillet([(-0.212, 0.016, 0.0), (-0.3385, 0.016, 0.0), (-0.3385, -0.0470, 0.0), (-0.3343, -0.0505, 0.002),
                       (-0.2576, 0.0042, 0.003), (-0.212, 0.0042, 0.002)], 3), "x", -0.0058, 0.0058, "Furniture")
    # A raised rim along the diagonal.
    b.prism([(-0.2576, 0.0042), (-0.3343, -0.0505), (-0.3370, -0.0468), (-0.2603, 0.0080)], "x", -0.0075, 0.0075,
            "Furniture")
    # The bracket under the body's front, with its pin.
    b.prism([(-0.1875, 0.0155), (-0.2045, 0.0155), (-0.2045, 0.0), (-0.1970, 0.0), (-0.1875, 0.0080)], "x",
            -0.0050, 0.0050, "Furniture")
    ob = b.build()
    cutters = []
    c = hs.Builder("c_tube", ["Furniture"])
    c.lathe([(front - 0.06, 0.0), (front - 0.06, TUBE_R + 0.0004), (front + 0.02, TUBE_R + 0.0004),
             (front + 0.02, 0.0)], "Furniture", 24, centre=(0.0, 0.0, TUBE_Z))
    cutters.append(c.build())
    # The slot along the toe plate, the slot down it at the back (a sling slot) and the pin hole between them.
    for cy, cz, hy, hz in ((-0.2920, 0.0080, 0.0218, 0.0023), (-0.3263, -0.0149, 0.0023, 0.0172)):
        c = hs.Builder("c_slot", ["Furniture"])
        c.prism([(y + cy, z + cz) for y, z in hs.rounded_rect(hy, hz, min(hy, hz) * 0.98, 3)], "x", -0.02, 0.02,
                "Furniture")
        cutters.append(c.build())
    c = hs.Builder("c_pin", ["Furniture"])
    c.lathe([(-0.02, 0.0), (-0.02, 0.0019), (0.02, 0.0019), (0.02, 0.0)], "Furniture", 12,
            centre=(0.0, -0.3073, -0.0091), axis="x")
    cutters.append(c.build())
    hs.cut(ob, cutters)
    ob.data.transform(slid)
    out.append(hs.finish(ob, 0.0012))

    # Battery-tube caps, the adjustment lever on the toe plate's front with its knob, and the bracket's pin.
    b = hs.Builder("StockDetail", ["Detail", "Metal"])
    for sx in (-1, 1):
        cap = [(-0.3225, 0.0), (-0.3225, 0.0146), (-0.3235, 0.0157)]
        for i in range(2):
            a = -0.3255 - i * 0.0050
            cap += [(a, 0.0157), (a - 0.0008, 0.0163), (a - 0.0022, 0.0163), (a - 0.0030, 0.0157)]
        cap += [(-0.3365, 0.0152), (-0.3375, 0.0)]
        b.lathe(cap, "Detail", 16, centre=(sx * 0.0162, 0.0, TUBE_Z - 0.004))
    b.prism(hs.fillet([(-0.2118, 0.0, 0.001), (-0.2128, 0.0155, 0.0), (-0.2542, 0.0155, 0.0),
                       (-0.2759, -0.0126, 0.001), (-0.2759, -0.0217, 0.001), (-0.2702, -0.0217, 0.001),
                       (-0.2485, 0.0, 0.001)], 2), "x", -0.0070, 0.0070, "Detail")
    b.lathe([(0.0, 0.0), (0.0, 0.0030), (-0.0060, 0.0030), (-0.0070, 0.0024), (-0.0070, 0.0)], "Metal", 14,
            centre=(0.0, -0.2336, 0.0005), axis="z")
    b.lathe([(-0.0062, 0.0), (-0.0062, 0.0019), (0.0062, 0.0019), (0.0062, 0.0)], "Metal", 12,
            centre=(0.0, -0.1970, 0.0080), axis="x")
    ob = b.build()
    ob.data.transform(slid)
    out.append(hs.finish(ob, 0.0003, 1))

    # Butt pad, as tall as body and toe together, finely ribbed across its back.
    b = hs.Builder("ButtPad", ["Rubber"])
    side = hs.fillet([(-0.3380, -0.0505, 0.0), (-0.3380, 0.0630, 0.0), (-0.3465, 0.0630, 0.0050),
                      (-0.3515, 0.0560, 0.0060), (-0.3515, -0.0475, 0.0030), (-0.3480, -0.0505, 0.0015)], 3)
    b.prism(side, "x", -0.0200, 0.0200, "Rubber")
    ob = b.build()
    # Its edges rounded round the back.
    for v in ob.data.vertices:
        if abs(v.co.x) > 0.019:
            v.co.x *= 0.92
    cutters = []
    for i in range(12):
        c = hs.Builder("c_rib", ["Rubber"])
        z = -0.0440 + i * 0.0085
        c.box((-0.03, -0.360, z), (0.03, -0.3507, z + 0.0035), "Rubber")
        cutters.append(c.build())
    hs.cut(ob, cutters)
    ob.data.transform(slid)
    out.append(hs.finish(ob, 0.0008, 1))
    return out


def handguard() -> list:
    """The quad-rail handguard as on the owner's photos' carbines: a square body round the barrel with a rail on each
    face, a ribbed delta ring behind it and a cap in front; the barrel (thick under the rail, stepped down past the
    front sight); and the front sight base on it, an A-frame with protective ears round the post."""
    out = []
    z0, z1 = GUARD_Z
    hw = GUARD_HW
    zc = 0.5 * (z0 + z1)
    ch = 0.0045
    sec = [(-hw + ch, z0), (hw - ch, z0), (hw, z0 + ch), (hw, z1 - ch), (hw - ch, z1), (-hw + ch, z1),
           (-hw, z1 - ch), (-hw, z0 + ch)]
    ring_end = GUARD_Y[0] + DELTA_LEN
    b = hs.Builder("Handguard", ["Furniture"])
    b.prism(sec, "y", ring_end - 0.001, GUARD_Y[1], "Furniture")
    out.append(hs.finish(b.build(), 0.0008, 1))

    # Delta ring (ribbed, as tall as the handguard's body) and the handguard's rounded front cap.
    b = hs.Builder("GuardEnds", ["Detail"])
    r = DELTA_R
    ring = [(GUARD_Y[0], 0.0), (GUARD_Y[0], r - 0.0012), (GUARD_Y[0] + 0.0012, r)]
    pitch = (DELTA_LEN - 0.0024) / 8.0
    for k in range(1, 8):
        a = GUARD_Y[0] + 0.0012 + k * pitch
        ring += [(a - 0.0005, r), (a, r - 0.0008), (a + 0.0005, r)]
    ring += [(ring_end - 0.0012, r), (ring_end, r - 0.0012), (ring_end, 0.0)]
    b.lathe(ring, "Detail", 22, centre=(0.0, -0.002, zc - DELTA_DROP))
    b.lathe([(GUARD_Y[1] - 0.001, 0.0), (GUARD_Y[1] - 0.001, 0.0150), (GUARD_Y[1] + 0.0002, 0.0148),
             (GUARD_Y[1] + 0.0010, 0.0140), (GUARD_Y[1] + 0.0013, 0.0126), (GUARD_Y[1] + 0.0013, 0.0)], "Detail", 24,
            centre=(0.0, 0.0, BORE_Z))
    out.append(hs.finish(b.build(), 0.0004, 1))

    # Rails: the top one raised on a bridge over the receiver's front (as in the photo), then on along the handguard,
    # its teeth in step with the upper's; the bottom and right ones bare.
    b = hs.Builder("GuardRails", ["Furniture"])
    by0, by1 = BRIDGE_Y
    b.box((-0.0106, by0, RAIL_BASE - 0.0010), (0.0106, by1, RAIL_BASE + BRIDGE_RISE), "Furniture")
    picatinny(b, by0, by1, "Furniture", rail_on("top", 0, 0, 0.0, RAIL_BASE + BRIDGE_RISE),
              teeth_from=UPPER_Y[0] + 0.0026 + 16 * 0.0100)
    picatinny(b, by1, GUARD_Y[1] - 0.001, "Furniture", rail_on("top", 0, 0, 0.0, RAIL_BASE),
              teeth_from=UPPER_Y[0] + 0.0026 + 22 * 0.0100)
    picatinny(b, ring_end + 0.001, GUARD_Y[1] - 0.001, "Furniture", rail_on("bottom", 0, 0, 0.0, z0 + 0.0006))
    picatinny(b, ring_end + 0.001, GUARD_Y[1] - 0.001, "Furniture", rail_on("right", 0, 0, hw - 0.0006, zc))
    out.append(hs.finish(b.build(), 0.0003, 1))

    # The left rail under a cover with raised ribs across it, as in the owner's photo; the right one stays bare for
    # the torch.
    b = hs.Builder("RailCover", ["Furniture"])
    cy0, cy1 = ring_end + 0.001, GUARD_Y[1] - 0.003
    ch_ = 0.0180
    b.prism(hs.fillet([(-hw + 0.0050, zc - ch_, 0.0), (-hw + 0.0050, zc + ch_, 0.0),
                       (-hw - 0.0030, zc + ch_, 0.0020), (-hw - 0.0045, zc + ch_ - 0.0022, 0.0020),
                       (-hw - 0.0045, zc - ch_ + 0.0022, 0.0020), (-hw - 0.0030, zc - ch_, 0.0020)], 3), "y", cy0,
            cy1, "Furniture")
    # Raised ribs across it, 1.5 mm proud, the cover's full height, rounded over at top and bottom.
    n = 12
    for k in range(n):
        y = cy0 + 0.006 + k * (cy1 - cy0 - 0.012) / (n - 1)
        b.prism(hs.fillet([(-hw - 0.0030, zc - ch_ + 0.0002, 0.0), (-hw - 0.0030, zc + ch_ - 0.0002, 0.0),
                           (-hw - 0.0060, zc + ch_ - 0.0016, 0.0020), (-hw - 0.0060, zc - ch_ + 0.0016, 0.0020)],
                          2), "y", y - 0.0014, y + 0.0014, "Furniture")
    out.append(hs.finish(b.build(), 0.0004, 1))

    # The barrel: thick under the handguard, then a carbine's profile, stepped down past the front sight.
    b = hs.Builder("Barrel", ["Metal"])
    b.lathe([(UPPER_Y[1] - 0.004, 0.0), (UPPER_Y[1] - 0.004, 0.0110), (0.13, 0.0110), (0.135, 0.0092),
             (FSB_Y[1], 0.0092), (FSB_Y[1] + 0.0015, 0.0086), (BARREL_END[1] + 0.003, 0.0086),
             (BARREL_END[1] + 0.003, 0.0)], "Metal", 20, centre=(0.0, 0.0, BORE_Z))
    out.append(hs.finish(b.build(), 0.0004, 1))

    # The front sight base, open as in the owner's photo: a collar round the barrel at each end (the rear one against
    # the handguard's cap), a post up from each to the bar the ears stand on, the bare barrel and a slot of daylight
    # between them, a bayonet lug under the front collar and a sling swivel under the rear one. Its ears and post are
    # the front sight's leaf (sight_leaf), on the frontSight bone, so they disappear under an optic
    # (game/play/sight_fold.gd).
    yb, yf = FSB_Y
    rc, fc = (yb + 0.001, 0.2925), (0.3155, yf)
    bar = 0.0565
    b = hs.Builder("FrontSightBase", ["Detail", "Metal"])
    for c0, c1 in (rc, fc):
        b.lathe([(c0, 0.0), (c0, 0.0090), (c0 + 0.0010, 0.0100), (c1 - 0.0010, 0.0100), (c1, 0.0090), (c1, 0.0)],
                "Detail", 20, centre=(0.0, 0.0, BORE_Z))
    b.prism(hs.fillet([(rc[0], BORE_Z, 0.0), (rc[1], BORE_Z, 0.0), (rc[1] + 0.0025, bar, 0.0015),
                       (fc[0], bar, 0.0015), (fc[0], BORE_Z, 0.0), (yf, BORE_Z, 0.0), (yf, FSB_TOP, 0.0),
                       (rc[0], FSB_TOP, 0.0)], 2), "x", -0.0085, 0.0085, "Detail")
    b.box((-0.0040, fc[0] + 0.001, BORE_Z - 0.0205), (0.0040, yf, BORE_Z - 0.0095), "Detail")
    swivel = b.tube([(-0.0012, 0.0062), (0.0012, 0.0062)], [(-0.0012, 0.0042), (0.0012, 0.0042)], "Metal", 12,
                    axis="x")
    b.transform(swivel, Matrix.Translation((0.0, 0.5 * (rc[0] + rc[1]), BORE_Z - 0.0218)) @
                Matrix.Scale(2.0, 4, (0, 0, 1)))
    out.append(hs.finish(b.build(), 0.0006, 1))
    return out


def flash_hider() -> object:
    """A birdcage flash hider: two bands at its back, then a cage with five slots round it (none underneath)."""
    y0, y1 = BARREL_END[1], MUZZLE[1]
    b = hs.Builder("FlashHider", ["Metal", "Detail"])
    # Two bands 5 mm long, 3 mm apart, then the cage (as the photo's).
    outer = [(y0, 0.0090)]
    for a in (y0, y0 + 0.0078):
        outer += [(a + 0.0004, 0.0110), (a + 0.0046, 0.0110), (a + 0.0050, 0.0085)]
    outer += [(y0 + 0.0154, 0.0085), (y0 + 0.0158, 0.0112), (y1 - 0.0025, 0.0112), (y1, 0.0100)]
    inner = [(y0, 0.0060), (y1, 0.0060)]
    b.tube(outer, inner, "Metal", 20, centre=(0.0, 0.0, BORE_Z))
    ob = b.build()
    cutters = []
    for ang in (90.0, 150.0, 210.0, 330.0, 30.0):
        c = hs.Builder("c_fh", ["Metal"])
        f = c.prism(hs.rounded_rect(0.0016, 0.5 * (y1 - 0.0045 - y0 - 0.0170), 0.0015, 3), "z", 0.0, 0.02, "Metal")
        c.transform(f, Matrix.Translation((0.0, 0.0, BORE_Z)) @ Matrix.Rotation(math.radians(ang - 90.0), 4, "Y") @
                    Matrix.Translation((0.0, 0.5 * (y1 - 0.0045 + y0 + 0.0170), 0.0)))
        cutters.append(c.build())
    hs.cut(ob, cutters)
    return hs.finish(ob, 0.0004, 1)


def sight_base(name: str, y0: float, y1: float, leaf: float) -> object:
    """A flip-up sight's body on the rail: a clamp (its back half 4 mm lower), a short cheek either side of the leaf's
    hinge (at y `leaf`), an ear at its back and a windage drum low on its left front, as the photo's rear sight."""
    b = hs.Builder(name, ["Detail", "Metal"])
    split = leaf - 0.0110
    for ya, yb_, top in ((split, y1, 0.0800), (y0, split + 0.001, 0.0760)):
        sec = [(-0.0128, RAIL_TOP - 0.0062), (-0.0110, RAIL_TOP - 0.0080), (0.0110, RAIL_TOP - 0.0080),
               (0.0128, RAIL_TOP - 0.0062), (0.0128, top - 0.0010), (0.0118, top), (-0.0118, top),
               (-0.0128, top - 0.0010)]
        b.prism(sec, "y", ya, yb_, "Detail")
    cheek = hs.fillet([(leaf - 0.0110, 0.0795, 0.0), (leaf + 0.0110, 0.0795, 0.0), (leaf + 0.0090, 0.0870, 0.002),
                       (leaf - 0.0090, 0.0870, 0.002)], 3)
    for x0, x1 in ((0.0100, 0.0128), (-0.0128, -0.0100)):
        b.prism(cheek, "x", x0, x1, "Detail")
    # The ear at its back, as the photo's: a thin upright with a hook forward at its top, 9 mm long.
    top = RAIL_TOP + 0.0150
    b.prism(hs.fillet([(y0 + 0.0010, 0.0755, 0.0), (y0 + 0.0042, 0.0755, 0.0), (y0 + 0.0042, top - 0.0024, 0.0008),
                       (y0 + 0.0100, top - 0.0024, 0.0006), (y0 + 0.0100, top, 0.0006), (y0 + 0.0022, top, 0.0012),
                       (y0 + 0.0010, top - 0.0012, 0.0)], 2), "x", -0.0100, 0.0100, "Detail")
    drum = [(0.0, 0.0), (0.0, 0.0046)]
    for k in range(3):
        a = 0.0006 + k * 0.0010
        drum += [(a, 0.0046), (a + 0.0002, 0.0050), (a + 0.0006, 0.0050), (a + 0.0008, 0.0046)]
    drum += [(0.0036, 0.0046), (0.0040, 0.0040), (0.0040, 0.0)]
    b.lathe([(-u, r) for u, r in drum], "Metal", 14, centre=(-0.0126, y1 - 0.0060, RAIL_TOP + 0.0030), axis="x")
    b.lathe([(0.0, 0.0), (0.0, 0.0032), (0.0016, 0.0032), (0.0020, 0.0024), (0.0020, 0.0)], "Metal", 16,
            centre=(-0.0128, 0.5 * (y0 + y1), RAIL_TOP - 0.0030), axis="x", start=0.0)
    ob = b.build()
    c = hs.Builder("c_rail", ["Detail"])
    c.prism([(-0.0108, RAIL_TOP - 0.0100), (0.0108, RAIL_TOP - 0.0100), (0.0108, RAIL_TOP), (-0.0108, RAIL_TOP)],
            "y", y0 - 0.01, y1 + 0.01, "Detail")
    hs.cut(ob, [c.build()])
    return hs.finish(ob, 0.0004)


def sight_leaf(name: str, y: float, front: bool) -> object:
    """A sight's part on its bone: the front's ears (on the front sight base) and post, or the rear's flip-up leaf."""
    pz = BONES["rearSight" if not front else "frontSight"][2]
    if front:
        # The ears: an A on the base's platform round the post, a triangular window through each, the post between.
        fy = FRONT_SIGHT_Y
        yf = FSB_Y[1]
        e = hs.Builder(name + "Ears", ["Detail"])
        top = EARS_TOP
        e.prism(hs.fillet([(yf, pz - 0.0005, 0.0), (yf, top, 0.0030), (fy - 0.0060, top, 0.0025),
                           (fsb_rear(pz - 0.0005), pz - 0.0005, 0.0)], 3), "x", -0.0085, 0.0085, "Detail")
        ears = e.build()
        cutters = []
        c = hs.Builder("c_win", ["Detail"])
        wz0, wz1 = pz + 0.0015, EARS_TOP - 0.0090
        c.prism(hs.fillet([(fy + 0.0020, wz0, 0.0010), (fy + 0.0020, wz1, 0.0012),
                           (fsb_rear(wz1) + 0.0060, wz1, 0.0012), (fsb_rear(wz0) + 0.0060, wz0, 0.0010)], 2),
                "x", -0.02, 0.02, "Detail")
        cutters.append(c.build())
        c = hs.Builder("c_gap", ["Detail"])
        c.box((-0.0045, FSB_Y[0] - 0.01, pz - 0.01), (0.0045, yf + 0.01, SIGHT_Z + 0.01), "Detail")
        cutters.append(c.build())
        hs.cut(ears, cutters)
        hs.finish(ears, 0.0006, 1)
        b = hs.Builder(name, ["Detail", "Accent"])
        b.lathe([(pz, 0.0), (pz, 0.0034), (pz + 0.0030, 0.0034), (pz + 0.0036, 0.0016), (pz + 0.0036, 0.0)], "Detail",
                16, centre=(0.0, y, 0.0), axis="z")
        b.prism([(-0.0013, pz + 0.003), (0.0013, pz + 0.003), (0.0011, SIGHT_Z - 0.0012), (-0.0011, SIGHT_Z - 0.0012)],
                "y", y - 0.0013, y + 0.0013, "Detail")
        b.prism([(-0.0011, SIGHT_Z - 0.0012), (0.0011, SIGHT_Z - 0.0012), (0.0009, SIGHT_Z), (-0.0009, SIGHT_Z)], "y",
                y - 0.0011, y + 0.0011, "Accent")
        return hs.join(name, [hs.finish(b.build(), 0.0003), ears])
    # The rear leaf, as the photo's flip-up sight: leaning back 8 degrees on its hinge, a hook forward at its top, a
    # wide hole through it on the sight line half way up with a thin aperture disc in it, and the aperture's boss
    # on its left side.
    b = hs.Builder(name, ["Detail", "Metal"])
    hy = 0.0070
    top = SIGHT_Z + 0.0150
    f = b.prism(hs.fillet([(y - hy, pz, 0.0), (y + hy, pz, 0.0), (y + hy, top - 0.0040, 0.0010),
                           (y + hy + 0.0030, top - 0.0022, 0.0010), (y + hy + 0.0030, top, 0.0008),
                           (y - hy + 0.0030, top, 0.0030), (y - hy, top - 0.0035, 0.0)], 3), "x", -0.0090, 0.0090,
                "Detail")
    b.transform(f, hs.rot_about("x", math.radians(8.0), (0.0, y, pz)))
    b.lathe([(0.0, 0.0), (0.0, 0.0040), (-0.0010, 0.0040), (-0.0015, 0.0034), (-0.0015, 0.0)], "Metal", 16,
            centre=(-0.0088, y - 0.0015, SIGHT_Z - 0.0002), axis="x")
    ob = b.build()
    c = hs.Builder("c_ap", ["Detail"])
    c.lathe([(-0.02, 0.0), (-0.02, 0.0058), (0.02, 0.0058), (0.02, 0.0)], "Detail", 20, centre=(0.0, y, SIGHT_Z))
    hs.cut(ob, [c.build()])
    hs.finish(ob, 0.0004)
    d = hs.Builder(name + "Disc", ["Detail"])
    d.tube([(-0.0010, 0.0060), (0.0010, 0.0060)], [(-0.0010, 0.0016), (0.0010, 0.0016)], "Detail", 20,
           centre=(0.0, y, SIGHT_Z))
    return hs.join(name, [ob, hs.finish(d.build(), 0.0002, 1)])


def moving_parts() -> dict:
    parts = {}
    # Trigger.
    b = hs.Builder("Trigger", ["Metal"])
    g = GUARD_DROP
    front = [(0.0065, -0.024), (0.0078, -0.034 - 0.4 * g), (0.0072, -0.044 - g), (0.0048, -0.052 - g),
             (0.0005, -0.0575 - g)]
    back = [(-0.0030, -0.0555 - g), (0.0010, -0.0500 - g), (0.0028, -0.0430 - g), (0.0030, -0.0350 - 0.4 * g),
            (0.0010, -0.0260), (0.0010, -0.0240)]
    b.prism([(y, lz(z)) for y, z in hs.smooth(front, 2) + hs.smooth(back, 2)], "x", -0.0031, 0.0031, "Metal")
    parts["trigger"] = hs.finish(b.build(), 0.0005)
    # Selector: hub and lever pointing back (safe).
    hub = Vector(BONES["selector"])
    b = hs.Builder("Selector", ["Detail"])
    b.lathe([(0.0, 0.0), (0.0, 0.0060), (-0.0018, 0.0060), (-0.0028, 0.0052), (-0.0028, 0.0)], "Detail", 20,
            centre=tuple(hub), axis="x")
    lever = [(0.0, -0.0042), (0.0050, -0.0038), (0.0200, -0.0022), (0.0222, 0.0), (0.0205, 0.0030),
             (0.0050, 0.0044), (0.0, 0.0046)]
    b.prism(lever, "x", -0.0030, -0.0010, "Detail", offset=(hub.x - 0.0012, hub.y, hub.z))
    parts["selector"] = hs.finish(b.build(), 0.0004)
    # Mag release.
    b = hs.Builder("MagRelease", ["Detail"])
    prof = [(0.0, 0.0), (0.0, 0.0047), (0.0024, 0.0047), (0.0032, 0.0040), (0.0032, 0.0)]
    b.lathe(prof, "Detail", 16, centre=BONES["magRelease"], axis="x")
    ob = b.build()
    cs = []
    for i in range(2):
        c = hs.Builder("c_mr", ["Detail"])
        c.box((BONES["magRelease"][0] + 0.0027, BONES["magRelease"][1] - 0.006, BONES["magRelease"][2] - 0.0027 +
               i * 0.0022), (0.04, BONES["magRelease"][1] + 0.006, BONES["magRelease"][2] - 0.0019 + i * 0.0022),
              "Detail")
        cs.append(c.build())
    hs.cut(ob, cs)
    parts["magRelease"] = hs.finish(ob, 0.0003, 1)
    # Charging handle: a T behind the upper, its shaft under the rail.
    b = hs.Builder("ChargingHandle", ["Detail"])
    top = [(-0.0150, -0.0905), (0.0150, -0.0905), (0.0156, -0.0880), (0.0128, -0.0858), (0.0058, -0.0852),
           (0.0058, -0.0660), (-0.0058, -0.0660), (-0.0058, -0.0852), (-0.0128, -0.0858), (-0.0156, -0.0880)]
    b.prism(top, "z", 0.0570, 0.0628, "Detail")
    parts["chargingHandle"] = hs.finish(b.build(), 0.0006)
    # Dust cover, hinged at its bottom on a rod.
    hz = BONES["dustCover"][2]
    b = hs.Builder("DustCover", ["Body", "Metal"])
    b.box((UPPER_HW + 0.0001, 0.0005, hz + 0.0006), (UPPER_HW + 0.0016, 0.0515, 0.0548), "Body")
    b.box((UPPER_HW + 0.0010, 0.004, 0.0505), (UPPER_HW + 0.0026, 0.012, 0.0535), "Body")
    b.lathe([(0.0, 0.0), (0.0, 0.0011), (0.0545, 0.0011), (0.0545, 0.0)], "Metal", 10,
            centre=(BONES["dustCover"][0], -0.0015, hz))
    parts["dustCover"] = hs.finish(b.build(), 0.0003)
    # Hop-up dial: a knurled wheel, its axis across the receiver.
    b = hs.Builder("HopDial", ["Metal"])
    hd = Vector(BONES["hopDial"])
    b.lathe([(-0.0025, 0.0), (-0.0025, 0.0064), (0.0025, 0.0064), (0.0025, 0.0)], "Metal", 20, centre=tuple(hd),
            axis="x")
    for i in range(10):
        f = b.box((hd.x - 0.0024, hd.y - 0.0007, hd.z + 0.0060), (hd.x + 0.0024, hd.y + 0.0007, hd.z + 0.0072),
                  "Metal")
        b.transform(f, hs.rot_about("x", 2.0 * math.pi * i / 10, tuple(hd)))
    parts["hopDial"] = hs.finish(b.build(), 0.0)
    parts["rearSight"] = sight_leaf("RearSightLeaf", BONES["rearSight"][1], False)
    parts["frontSight"] = sight_leaf("FrontSightLeaf", BONES["frontSight"][1], True)
    parts["magazine"] = magazine()
    return parts


def figure() -> object:
    """The figures' cut-down copy: the silhouette in a few hundred faces."""
    b = hs.Builder("Figure", ["Body", "Furniture", "Detail", "Metal"])
    b.box((-UPPER_HW, UPPER_Y[0], SEAM), (UPPER_HW, UPPER_Y[1], RAIL_TOP - 0.004), "Body")
    b.prism([(y, lz(z)) for y, z in ((-0.096, 0.020), (-0.096, 0.004), (-0.081, -0.021), (-0.034, -0.025),
                                     (0.024, -0.025), (0.024, -0.066), (0.1005, -0.066), (0.104, -0.003),
                                     (-0.085, 0.0), (-0.085, 0.020))], "x", -LOWER_HW, LOWER_HW, "Body")
    b.prism([(y, lz(z)) for y, z in ((0.024, -0.062), (0.016, -0.068), (-0.024, -0.068), (-0.040, -0.040),
                                     (-0.030, -0.040), (-0.022, -0.0635), (0.024, -0.0635))], "x", -0.004, 0.004,
            "Body")
    gw = GUARD_HW + 0.0094
    sec = [(-gw + 0.004, GUARD_Z[0] - 0.009), (gw - 0.004, GUARD_Z[0] - 0.009), (gw, GUARD_Z[0]), (gw, RAIL_BASE),
           (gw - 0.004, RAIL_TOP - 0.003), (-gw + 0.004, RAIL_TOP - 0.003), (-gw, RAIL_BASE), (-gw, GUARD_Z[0])]
    b.prism(sec, "y", GUARD_Y[0], GUARD_Y[1], "Furniture")
    b.lathe([(GUARD_Y[1] - 0.01, 0.0092), (MUZZLE[1], 0.0092)], "Metal", 8, centre=(0.0, 0.0, BORE_Z))
    b.lathe([(BARREL_END[1], 0.0115), (MUZZLE[1], 0.0112)], "Metal", 8, centre=(0.0, 0.0, BORE_Z))
    b.lathe([(-0.1010, 0.0176), (-0.090, 0.0176)], "Detail", 8, centre=(0.0, 0.0, TUBE_Z))
    b.prism([(y + STOCK_IN, z) for y, z in ((-0.188, 0.033), (-0.1805, 0.0585), (-0.1845, 0.063), (-0.3515, 0.063),
             (-0.3515, -0.0505), (-0.3343, -0.0505), (-0.2576, 0.0042), (-0.197, 0.0148))], "x", -0.0185, 0.0185,
            "Furniture")
    rake = math.radians(GRIP_RAKE)
    down = Vector((0.0, -math.sin(rake), -math.cos(rake)))
    fwd = Vector((0.0, math.cos(rake), -math.sin(rake)))
    top = Vector((0.0, GRIP_TOP_Y, lz(GRIP_TOP_Z)))
    rings = []
    for t, hw, fr, bk in ((0.0, 0.0128, 0.0165, 0.0215), (0.38, 0.0144, 0.0232, 0.023), (1.0, 0.0158, 0.0228, 0.0254)):
        c = top + down * (GRIP_LENGTH * t)
        rings.append([c + Vector((x, 0.0, 0.0)) + fwd * f for x, f in hs.superellipse(hw, fr, bk, 2.6, 8)])
    b.loft(rings, "Detail")
    rings = []
    for z in (-0.020, -0.075, MAG_BOTTOM):
        cy = mag_spine(z)[0]
        rings.append([(x, cy + y, mz(z)) for x, y in hs.rounded_rect(MAG_HW, MAG_HD, 0.006, 1)])
    b.loft(rings, "Detail")
    b.box((-0.008, -0.0721, RAIL_TOP), (0.008, -0.0691, SIGHT_Z + 0.004), "Detail")
    b.prism([(GUARD_Y[1] + 0.006, BORE_Z), (FRONT_SIGHT_Y + 0.0065, BORE_Z), (FRONT_SIGHT_Y + 0.0065, SIGHT_Z + 0.0035),
             (FRONT_SIGHT_Y - 0.0055, SIGHT_Z + 0.0035), (GUARD_Y[1] + 0.006, BORE_Z + 0.020)], "x", -0.0085, 0.0085,
            "Detail")
    ob = b.build()
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


# --------------------------------------------------------------------------------------------------------- rig

def armature() -> bpy.types.Object:
    data = bpy.data.armatures.new(ARMATURE)
    arm = bpy.data.objects.new(ARMATURE, data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name, head in BONES.items():
        eb = data.edit_bones.new(name)
        eb.head = head
        eb.tail = (head[0], head[1] + BONE_LENGTH, head[2])
        eb.roll = 0.0
        if name != "root":
            eb.parent = data.edit_bones["root"]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def ease(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


# Clips: seconds, and per bone a list of (time, value) keys; value is (axis, angle in degrees) for a turn or
# (axis, metres) for a move. Between keys the value eases. Every bone is keyed in every clip (SelectorPose).
CLIPS = {
    "Fire": (0.1, {"trigger": ("rx", [(0.0, 0.0), (0.033, -17.0), (0.05, -17.0), (0.1, 0.0)])}),
    "Reload": (1.8, {
        "magRelease": ("lx", [(0.0, 0.0), (0.05, -0.003), (0.35, -0.003), (0.40, 0.0)]),
        "magazine": ("mag", [(0.0, (0.0, 0.0)), (0.08, (0.0, 0.0)), (0.43, (0.075, -0.291)), (0.90, (0.075, -0.291)),
                             (0.9001, (0.04, -0.155)), (1.40, (0.0, 0.0)), (1.8, (0.0, 0.0))]),
    }),
    "Selector": (0.5, {"selector": ("rx", [(0.0, 0.0), (0.5, 180.0)])}),
    "SightsFold": (0.3, {"rearSight": ("rx", [(0.0, 0.0), (0.3, 90.0)]),
                         "frontSight": ("rx", [(0.0, 0.0), (0.3, 90.0)])}),
    "Inspect": (3.0, {
        "chargingHandle": ("ly", [(0.0, 0.0), (0.17, 0.0), (0.40, -0.050), (1.83, -0.050), (1.97, 0.0), (3.0, 0.0)]),
        "dustCover": ("ry", [(0.0, 0.0), (0.33, 0.0), (0.40, 100.0), (0.46, 92.0), (2.33, 92.0), (2.50, 0.0),
                             (3.0, 0.0)]),
        "hopDial": ("rx", [(0.0, 0.0), (0.67, 0.0), (1.33, 90.0), (1.75, 30.0), (3.0, 30.0)]),
    }),
}


def _interp(keys: list, t: float):
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            s = ease((t - t0) / max(1e-9, t1 - t0))
            if isinstance(v0, tuple):
                return tuple(a + (b - a) * s for a, b in zip(v0, v1))
            return v0 + (v1 - v0) * s
    return keys[-1][1]


def clips(arm: bpy.types.Object) -> None:
    arm.animation_data_create()
    ad = arm.animation_data
    for clip, (length, tracks) in CLIPS.items():
        act = bpy.data.actions.new(clip)
        ad.action = act
        frames = int(round(length * FPS))
        # Key times: each key's frame, plus every frame where something eases.
        times = sorted({round(i / FPS, 6) for i in range(frames + 1)})
        for t in times:
            frame = t * FPS
            for pb in arm.pose.bones:
                pb.rotation_mode = "QUATERNION"
                rot = Matrix.Identity(3)
                loc = Vector((0.0, 0.0, 0.0))
                if pb.name in tracks:
                    kind, keys = tracks[pb.name]
                    v = _interp(keys, t)
                    if kind == "rx":
                        rot = Matrix.Rotation(math.radians(v), 3, "X")
                    elif kind == "ry":
                        rot = Matrix.Rotation(math.radians(v), 3, "Y")
                    elif kind == "lx":
                        loc = Vector((v, 0.0, 0.0))
                    elif kind == "ly":
                        loc = Vector((0.0, v, 0.0))
                    elif kind == "mag":
                        loc = Vector((0.0, v[0], v[1]))
                pb.rotation_quaternion = rot.to_quaternion()
                pb.location = loc
                pb.scale = Vector((1.0, 1.0, 1.0))
                for path in ("rotation_quaternion", "location", "scale"):
                    pb.keyframe_insert(path, frame=frame)
        ad.action = None
        track = ad.nla_tracks.new()
        track.name = clip
        track.strips.new(clip, 0, act)
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)


# --------------------------------------------------------------------------------------------------------- main

def build() -> None:
    hs.reset(FPS)
    for name, (colour, rough, metal) in MATERIALS.items():
        hs.material(name, colour, rough, metal)
    arm = armature()
    body_parts = []
    body_parts += upper()
    body_parts += lower()
    body_parts.append(grip())
    body_parts += stock()
    body_parts += handguard()
    body_parts.append(sight_base("RearBase", REAR_SIGHT_Y - 0.0440, REAR_SIGHT_Y + 0.0150, REAR_SIGHT_Y))
    for ob in body_parts:
        print("  part %-14s %6d" % (ob.name, hs.tris(ob)))
    body = hs.join("Body", body_parts)
    body.parent = arm
    fh = flash_hider()
    fh.parent = arm
    fh.location = (0.0, 0.0, 0.0)
    for bone, ob in moving_parts().items():
        hs.parent_to_bone(ob, arm, bone)
    fig = figure()
    for name, loc in EMPTIES.items():
        hs.empty(name, loc, arm)
    # The flash hider's origin at the barrel's end, like the old file's (a muzzle part replaces it there).
    me = fh.data
    me.transform(Matrix.Translation(-Vector(BARREL_END)))
    fh.location = BARREL_END
    clips(arm)
    total = 0
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            n = hs.tris(ob)
            if ob.name != "Figure":
                total += n
            print("  %-16s %6d triangles" % (ob.name, n))
    print("  in the hands: %d triangles; figure: %d" % (total, hs.tris(fig)))
    hs.export(OUT, True)
    print("wrote", OUT)


if __name__ == "__main__":
    build()
