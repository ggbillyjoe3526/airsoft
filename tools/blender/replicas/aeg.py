"""The AEG Rifle's model (BL1, 2026-11-04), from the owner's reference photos (an M4-style carbine: flat-top upper,
free-float rail, flip-up sights, a stock with battery tubes, a polymer magazine). Generic: no maker's marks.

It keeps the old model's contract (docs/CC0_ASSETS.md › Replica models): the empties (Muzzle, BarrelEnd, RearSight,
FrontSight, MagWell, GripMount, OpticMount, TorchMount); the rear ones where they were, so the sight line and the
figures' hold don't move, and the front ones (Muzzle, BarrelEnd, FrontSight, TorchMount) SHORT metres back with the
CQB-length handguard (owner, 2026-11-04: "make the AEG shorter"; tools/blender/parts/fit_parts.py moves the parts); the armature AEGRifle with the same bones and the same five clips (Fire, Reload,
Selector, SightsFold, Inspect) of the same lengths; the paintable materials Body, Furniture, Detail, Accent and Metal
(plus Rubber and BB, kept as drawn). `Figure` is the figures' cut-down copy.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/replicas/aeg.py <repo root>

It writes assets/models/replicas/aeg.glb. Re-run tools/blender/parts/fit_parts.py, then
tools/blender/replicas/sniper.py, then tools/blender/arms/arms.py after it (each is built from this file).
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

# The owner's ruling (2026-11-04): shorter than the first pass, a CQB carbine like his reference photos. The barrel
# and handguard lose SHORT and the stock sits STOCK_IN further forward on its tube (one position in); the parts file
# follows (tools/blender/parts/fit_parts.py).
SHORT = 0.154
STOCK_IN = 0.030

# The contract's points (Blender space, metres).
BORE_Z = 0.034
BARREL_END = (0.0, 0.565 - SHORT, BORE_Z)
MUZZLE = (0.0, 0.611 - SHORT, BORE_Z)
FRONT_SIGHT_Y = 0.4875 - SHORT
RAIL_TOP = 0.0735
RAIL_BASE = 0.0635
SIGHT_Z = 0.088
FA_Z = 0.036
EMPTIES = {
    "BarrelEnd": BARREL_END, "Muzzle": MUZZLE, "FrontSight": (0.0, FRONT_SIGHT_Y, SIGHT_Z),
    "RearSight": (0.0, -0.0693, SIGHT_Z), "MagWell": (0.0, 0.062, -0.076), "GripMount": (0.0, 0.22, 0.0),
    "OpticMount": (0.0, 0.025, RAIL_TOP), "TorchMount": (0.038, 0.505 - SHORT - 0.072, BORE_Z),
}

# Layout.
UPPER_Y = (-0.085, 0.100)
UPPER_HW = 0.0150
LOWER_HW = 0.0155
WELL_HW = 0.0195
GUARD_Y = (0.101, 0.505 - SHORT)
GUARD_HW = 0.029
GUARD_Z = (0.009, RAIL_BASE)
TUBE_Z = 0.030
TUBE_R = 0.0148
TUBE_Y = (-0.335 + STOCK_IN, -0.100)
MAG_TOP = (0.0, 0.062, -0.076)
MAG_HW = 0.0150
MAG_HD = 0.034

# Bones: name -> head (each points +Y, 0.0313 long, roll 0, as the old file's).
BONES = {
    "root": (0.0, 0.0, 0.0),
    "trigger": (0.0, 0.004, -0.031),
    "selector": (-LOWER_HW, -0.030, -0.006),
    "magRelease": (WELL_HW, 0.034, -0.012),
    "chargingHandle": (0.0, -0.098, 0.0545),
    "dustCover": (UPPER_HW + 0.0012, 0.026, 0.0215),
    "hopDial": (0.0075, 0.026, 0.035),
    "rearSight": (0.0, -0.0706, 0.0795),
    "frontSight": (0.0, FRONT_SIGHT_Y - 0.0015, 0.0795),
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
        return Matrix.Translation((x, 0.0, z)) @ Matrix.Rotation(-math.pi * 0.5, 4, "Y")
    return Matrix.Translation((x, 0.0, z)) @ Matrix.Rotation(math.pi * 0.5, 4, "Y")


# --------------------------------------------------------------------------------------------------------- parts

def upper() -> list:
    out = []
    b = hs.Builder("Upper", ["Body"])
    sec = [(-UPPER_HW, 0.0), (UPPER_HW, 0.0), (UPPER_HW, 0.050), (0.0115, 0.0565), (0.0098, RAIL_BASE),
           (-0.0098, RAIL_BASE), (-0.0115, 0.0565), (-UPPER_HW, 0.050)]
    b.prism(sec, "y", UPPER_Y[0], UPPER_Y[1], "Body")
    # Brass deflector, behind the ejection port.
    b.prism([(-0.017, 0.033), (-0.001, 0.033), (0.002, 0.044), (-0.003, 0.0565), (-0.017, 0.0565)], "x",
            UPPER_HW - 0.002, UPPER_HW + 0.0062, "Body")
    # Forward-assist housing: a round boss on the right at the back, tapering forward into the side (a teardrop).
    rings = []
    for y, r, dx in ((-0.0660, 0.0089, 0.0016), (-0.0560, 0.0090, 0.0016), (-0.0470, 0.0087, 0.0010),
                     (-0.0390, 0.0078, -0.0002), (-0.0320, 0.0063, -0.0018), (-0.0260, 0.0046, -0.0034),
                     (-0.0215, 0.0030, -0.0048)):
        rings.append([(UPPER_HW + dx + r * math.cos(t), y, FA_Z + r * math.sin(t))
                      for t in (2.0 * math.pi * i / 24 for i in range(24))])
    b.loft(rings, "Body")
    ob = b.build()
    cutters = []
    c = hs.Builder("c_port", ["Body"])
    c.box((UPPER_HW - 0.0055, 0.002, 0.024), (0.03, 0.050, 0.047), "Body")
    cutters.append(c.build())
    c = hs.Builder("c_ch", ["Body"])
    c.box((-0.0062, UPPER_Y[0] - 0.01, 0.048), (0.0062, UPPER_Y[0] + 0.012, 0.070), "Body")
    cutters.append(c.build())
    # Machining lines along each side under the shoulder, and the left side's flat panel.
    for sx in (-1, 1):
        c = hs.Builder("c_groove", ["Body"])
        c.box((sx * UPPER_HW - 0.0006, UPPER_Y[0] + 0.010, 0.0500), (sx * UPPER_HW + 0.0006, UPPER_Y[1] - 0.008,
              0.0512), "Body")
        cutters.append(c.build())
    c = hs.Builder("c_panel", ["Body"])
    f = c.prism(hs.rounded_rect(0.034, 0.0105, 0.004, 3), "x", -0.01, 0.0, "Body")
    c.transform(f, Matrix.Translation((-UPPER_HW + 0.0006, 0.040, 0.030)))
    cutters.append(c.build())
    hs.cut(ob, cutters)
    hs.finish(ob, 0.0008)
    out.append(ob)

    # Inside the port: the bolt face the hop dial shows through.
    b = hs.Builder("PortFloor", ["Detail"])
    b.box((UPPER_HW - 0.0070, 0.001, 0.023), (UPPER_HW - 0.0050, 0.051, 0.048), "Detail")
    out.append(hs.finish(b.build(), 0.0))

    # Forward-assist plunger, ribbed, out of the back of the boss.
    b = hs.Builder("ForwardAssist", ["Detail"])
    prof = [(0.0, 0.0), (0.0, 0.0062)]
    for i in range(3):
        a = 0.002 + i * 0.0028
        prof += [(a, 0.0062), (a + 0.0005, 0.0068), (a + 0.0018, 0.0068), (a + 0.0023, 0.0062)]
    prof += [(0.0118, 0.0062), (0.0128, 0.0048), (0.0128, 0.0)]
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
    prof = [(0.099, 0.0), (-0.085, 0.0), (-0.085, 0.018), (-0.093, 0.016), (-0.098, 0.010), (-0.0995, 0.002),
            (-0.097, -0.008), (-0.091, -0.017), (-0.083, -0.024), (-0.074, -0.029), (-0.040, -0.033),
            (0.022, -0.034), (0.022, -0.014), (0.104, -0.014), (0.104, -0.004)]
    b.prism(prof, "x", -LOWER_HW, LOWER_HW, "Body")
    # Buffer tower: the round boss the tube threads into.
    b.lathe([(0.0, 0.0), (0.0, 0.0172), (0.019, 0.0172), (0.019, 0.0)], "Body", 28,
            centre=(0.0, -0.104, TUBE_Z))
    # Magazine well, its front raked back, flared at the bottom.
    well = [(0.0215, -0.004), (0.1045, -0.004), (0.1045, -0.016), (0.0990, -0.064), (0.0215, -0.064)]
    b.prism(well, "x", -WELL_HW, WELL_HW, "Body")
    flare = hs.rounded_rect(WELL_HW + 0.0013, 0.0430, 0.006, 3)
    b.prism([(x, y + 0.0605) for x, y in flare], "z", -0.0705, -0.0620, "Body")
    # Trigger guard.
    # Trigger guard: one piece with the lower, its loop run up into a lug at each end (the front lug against the
    # well's back, the rear one ahead of the grip), so no daylight between guard and receiver.
    guard = [(0.0225, -0.030), (0.0225, -0.0600), (0.0150, -0.0675), (-0.0235, -0.0675), (-0.0340, -0.0595),
             (-0.0385, -0.0300), (-0.0315, -0.0300), (-0.0275, -0.0540), (-0.0210, -0.0612), (0.0135, -0.0612),
             (0.0180, -0.0570), (0.0180, -0.030)]
    b.prism(guard, "x", -0.0052, 0.0052, "Body")
    b.prism([(0.0140, -0.030), (0.0230, -0.030), (0.0230, -0.0520), (0.0175, -0.0480), (0.0140, -0.0400)], "x",
            -0.0078, 0.0078, "Body")
    b.prism([(-0.0465, -0.030), (-0.0262, -0.030), (-0.0262, -0.0380), (-0.0300, -0.0440), (-0.0465, -0.0460)],
            "x", -0.0078, 0.0078, "Body")
    # Mag release fence (right) and bolt-catch bosses (left).
    b.prism([(0.024, -0.021), (0.044, -0.021), (0.044, -0.004), (0.024, -0.004)], "x", WELL_HW - 0.001,
            WELL_HW + 0.0018, "Body")
    b.prism([(0.004, -0.004), (0.022, -0.004), (0.022, 0.012), (0.004, 0.012)], "x", -LOWER_HW - 0.0016,
            -LOWER_HW + 0.001, "Body")
    ob = b.build()
    cutters = []
    c = hs.Builder("c_mag", ["Body"])
    c.prism([(x, y + 0.0620) for x, y in hs.rounded_rect(MAG_HW + 0.0004, MAG_HD + 0.0006, 0.0055, 3)], "z",
            -0.090, -0.010, "Body")
    cutters.append(c.build())
    c = hs.Builder("c_trig", ["Body"])
    c.box((-0.0045, -0.0125, -0.040), (0.0045, 0.0138, -0.024), "Body")
    cutters.append(c.build())
    # The mag release sits in a pocket in its fence.
    c = hs.Builder("c_mr", ["Body"])
    c.lathe([(0.0, 0.0), (0.0, 0.0054), (0.008, 0.0054), (0.008, 0.0)], "Body", 20,
            centre=(WELL_HW - 0.0002, 0.034, -0.012), axis="x")
    cutters.append(c.build())
    # Side panels on the well, and grip lines across its front.
    for sx, y0 in ((-1, 0.029), (1, 0.050)):
        c = hs.Builder("c_wp", ["Body"])
        f = c.prism(hs.rounded_rect(0.5 * (0.095 - y0), 0.0200, 0.004, 3), "x", 0.0, 0.01, "Body")
        c.transform(f, Matrix.Translation((sx * WELL_HW - (0.0006 if sx > 0 else 0.0094), 0.5 * (0.095 + y0), -0.036)))
        cutters.append(c.build())
    for i in range(4):
        c = hs.Builder("c_fg", ["Body"])
        z = -0.028 - i * 0.0075
        c.box((-0.014, 0.0985, z), (0.014, 0.112, z + 0.0022), "Body")
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
                centre=(0.0, y, z), axis="x")
    out.append(hs.finish(b.build(), 0.0))

    # Bolt catch (left).
    b = hs.Builder("BoltCatch", ["Detail"])
    b.prism([(0.006, -0.002), (0.020, 0.000), (0.020, 0.010), (0.010, 0.012), (0.006, 0.006)], "x",
            -LOWER_HW - 0.0040, -LOWER_HW - 0.0010, "Detail")
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
    """A pistol grip raked 22 degrees back, lofted through sections with a finger swell."""
    rake = math.radians(22.0)
    down = Vector((0.0, -math.sin(rake), -math.cos(rake)))
    fwd = Vector((0.0, math.cos(rake), -math.sin(rake)))
    top = Vector((0.0, -0.050, -0.016))
    length = 0.122
    # t, half width, front, back
    stations = [(0.00, 0.0128, 0.0165, 0.0215), (0.10, 0.0133, 0.0172, 0.0222), (0.25, 0.0140, 0.0195, 0.0228),
                (0.38, 0.0144, 0.0232, 0.0230), (0.48, 0.0145, 0.0212, 0.0232), (0.60, 0.0146, 0.0200, 0.0234),
                (0.80, 0.0148, 0.0208, 0.0238), (0.93, 0.0150, 0.0215, 0.0242), (0.965, 0.0158, 0.0228, 0.0254),
                (1.00, 0.0158, 0.0228, 0.0254)]
    fine = []
    for (ta, *va), (tb, *vb) in zip(stations, stations[1:]):
        steps = max(1, int(round((tb - ta) / 0.05)))
        for k in range(steps):
            u = k / steps
            w = u * u * (3.0 - 2.0 * u) if tb - ta > 0.06 else u
            fine.append((ta + (tb - ta) * u, *[a + (b2 - a) * w for a, b2 in zip(va, vb)]))
    fine.append(stations[-1])
    rings = []
    for t, hw, fr, bk in fine:
        c = top + down * (length * t)
        ring = []
        for x, f in hs.superellipse(hw, fr, bk, 2.6, 32):
            ring.append(c + Vector((x, 0.0, 0.0)) + fwd * f)
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


def magazine() -> object:
    """A polymer magazine, curved forward toward the base, with side panels and a base plate."""
    b = hs.Builder("Magazine", ["Detail", "Rubber", "BB"])
    sec = hs.rounded_rect(MAG_HW, MAG_HD, 0.0055, 2)
    zs = [-0.012, -0.070, -0.071, -0.075, -0.076, -0.100, -0.130, -0.160, -0.190, -0.212, -0.222]
    scale = {-0.071: 1.0, -0.075: 1.045, -0.076: 1.045}

    def spine(z: float) -> tuple:
        d = max(0.0, -0.075 - z)
        return MAG_TOP[1] + d * d / 1.2, math.atan2(d / 0.6, 1.0)

    rings = []
    for z in zs:
        cy, tilt = spine(z)
        s = scale.get(z, 1.0)
        ring = []
        for x, y in sec:
            p = Vector((x * s, y * s, 0.0))
            p = Matrix.Rotation(tilt, 3, "X") @ p
            ring.append((p.x, cy + p.y, z + p.z))
        rings.append(ring)
    b.loft(rings, "Detail")
    # Base plate.
    cy, tilt = spine(-0.222)
    plate = b.prism(hs.rounded_rect(MAG_HW + 0.0018, MAG_HD + 0.0035, 0.006, 3), "z", -0.0105, 0.0, "Rubber")
    b.transform(plate, Matrix.Translation((0.0, cy + 0.0015, -0.2215)) @ Matrix.Rotation(tilt, 4, "X"))
    # Feed lips and the top BBs.
    b.box((-0.0045, MAG_TOP[1] + 0.012, -0.012), (0.0045, MAG_TOP[1] + 0.030, -0.006), "Rubber")
    for i in range(3):
        b.lathe([(-0.003, 0.0), (-0.0026, 0.0015), (-0.0015, 0.0026), (0.0, 0.003), (0.0015, 0.0026),
                 (0.0026, 0.0015), (0.003, 0.0)], "BB", 10, centre=(0.0, MAG_TOP[1] + 0.024 - i * 0.0062,
                 -0.0030 - i * 0.0007), axis="z")
    ob = b.build()
    # Side panels: two columns, three rows, recessed.
    cutters = []
    for row, (za, zb) in enumerate(((-0.084, -0.122), (-0.128, -0.164), (-0.170, -0.205))):
        zm = 0.5 * (za + zb)
        cy, tilt = spine(zm)
        for ya, yb in ((-0.029, 0.004), (0.009, 0.028)):
            for sx in (-1, 1):
                c = hs.Builder("c_pan", ["Detail"])
                hh = 0.5 * (za - zb)
                f = c.prism(hs.rounded_rect(0.5 * (yb - ya), hh, 0.004, 2), "x", 0.0, 0.01, "Detail")
                x0 = MAG_HW - 0.0008 if sx > 0 else -MAG_HW + 0.0008 - 0.01
                c.transform(f, Matrix.Translation((x0, cy + 0.5 * (ya + yb), zm)) @ Matrix.Rotation(tilt, 4, "X"))
                cutters.append(c.build())
    hs.cut(ob, cutters)
    return hs.finish(ob, 0.0008, 1)


def stock() -> list:
    """The buffer tube on the receiver, and the stock, butt pad and lever built fully out then slid STOCK_IN in."""
    out = []
    front = -0.186
    slid = Matrix.Translation((0.0, STOCK_IN, 0.0))
    # Buffer tube with its castle nut and end plate.
    b = hs.Builder("Tube", ["Detail", "Metal"])
    b.lathe([(TUBE_Y[0], 0.0), (TUBE_Y[0], TUBE_R - 0.002), (TUBE_Y[0] + 0.002, TUBE_R), (TUBE_Y[1], TUBE_R),
             (TUBE_Y[1], 0.0)], "Detail", 20, centre=(0.0, 0.0, TUBE_Z))
    b.lathe([(-0.112, 0.0), (-0.112, 0.0170), (-0.1105, 0.0176), (-0.1055, 0.0176), (-0.105, 0.0170),
             (-0.105, 0.0)], "Detail", 28, centre=(0.0, 0.0, TUBE_Z))
    nut = [(-0.1215, 0.0), (-0.1215, 0.0166), (-0.1205, 0.0176), (-0.1130, 0.0176), (-0.1120, 0.0166),
           (-0.1120, 0.0)]
    b.lathe(nut, "Metal", 28, centre=(0.0, 0.0, TUBE_Z))
    # QD sling socket on the end plate, left.
    b.lathe([(0.0, 0.0), (0.0, 0.0055), (0.0045, 0.0055), (0.0045, 0.0028), (0.0030, 0.0028), (0.0030, 0.0)],
            "Metal", 16, centre=(-0.0172 - 0.0040, -0.1085, TUBE_Z - 0.006), axis="x")
    ob = b.build()
    cutters = []
    for i in range(3):
        c = hs.Builder("c_notch", ["Metal"])
        f = c.box((-0.0022, -0.1225, 0.0145), (0.0022, -0.1170, 0.021), "Metal")
        c.transform(f, hs.rot_about("y", math.radians(30 + 120 * i), (0.0, 0.0, TUBE_Z)))
        cutters.append(c.build())
    for i in range(2):
        c = hs.Builder("c_hole", ["Metal"])
        c.lathe([(-0.01, 0.0), (-0.01, 0.0022), (0.01, 0.0022), (0.01, 0.0)], "Metal", 10,
                centre=(0.0, front + STOCK_IN - 0.004 + i * 0.0105 + 0.0105 * 2, TUBE_Z - TUBE_R), axis="z")
        cutters.append(c.build())
    hs.cut(ob, cutters)
    out.append(hs.finish(ob, 0.0004))

    # The stock shell: a body round the tube, a toe frame down to the butt, battery tubes along each side.
    b = hs.Builder("Stock", ["Furniture"])
    hw = 0.0172
    shell = [(front, 0.009), (front, 0.042), (front - 0.007, 0.049), (-0.300, 0.0525), (-0.334, 0.0545),
             (-0.346, 0.058), (-0.346, -0.086), (-0.335, -0.093), (-0.319, -0.093), (-0.297, -0.066),
             (-0.244, -0.003), (front - 0.020, 0.005)]
    b.prism(shell, "x", -hw, hw, "Furniture")
    for sx in (-1, 1):
        b.lathe([(front - 0.012, 0.0), (front - 0.012, 0.0112), (front - 0.006, 0.0146), (-0.318, 0.0150),
                 (-0.320, 0.0)], "Furniture", 22, centre=(sx * 0.0162, 0.0, 0.026))
    ob = b.build()
    cutters = []
    c = hs.Builder("c_loop", ["Furniture"])
    c.prism([(-0.332, -0.075), (-0.332, -0.011), (-0.283, -0.011)], "x", -0.05, 0.05, "Furniture")
    cutters.append(c.build())
    c = hs.Builder("c_slot", ["Furniture"])
    c.box((-0.006, -0.3395, -0.090), (0.006, -0.3335, -0.074), "Furniture")
    cutters.append(c.build())
    c = hs.Builder("c_tube", ["Furniture"])
    c.lathe([(front - 0.06, 0.0), (front - 0.06, TUBE_R + 0.0004), (front + 0.02, TUBE_R + 0.0004),
             (front + 0.02, 0.0)], "Furniture", 24, centre=(0.0, 0.0, TUBE_Z))
    cutters.append(c.build())
    hs.cut(ob, cutters)
    ob.data.transform(slid)
    out.append(hs.finish(ob, 0.0016))

    # Battery-tube caps and the release lever.
    b = hs.Builder("StockDetail", ["Detail", "Metal"])
    for sx in (-1, 1):
        cap = [(-0.3175, 0.0), (-0.3175, 0.0146), (-0.3185, 0.0157)]
        for i in range(3):
            a = -0.3190 - i * 0.0040
            cap += [(a, 0.0157), (a - 0.0008, 0.0163), (a - 0.0022, 0.0163), (a - 0.0030, 0.0157)]
        cap += [(-0.3315, 0.0152), (-0.3325, 0.0)]
        b.lathe(cap, "Detail", 16, centre=(sx * 0.0162, 0.0, 0.026))
    b.prism([(front - 0.004, 0.0), (front - 0.036, 0.0), (front - 0.040, 0.004), (front - 0.040, 0.010),
             (front - 0.012, 0.010), (front - 0.004, 0.006)], "x", -0.0045, 0.0045, "Detail",
            offset=(0.0, 0.0, TUBE_Z - TUBE_R - 0.0105))
    ob = b.build()
    ob.data.transform(slid)
    out.append(hs.finish(ob, 0.0003, 1))

    # Butt pad, ribbed.
    b = hs.Builder("ButtPad", ["Rubber"])
    pad = hs.rounded_rect(0.0200, 0.0745, 0.012, 4)
    b.prism([(x, y - 0.0145) for x, y in pad], "y", -0.3575, -0.3450, "Rubber")
    ob = b.build()
    cutters = []
    for i in range(11):
        c = hs.Builder("c_rib", ["Rubber"])
        z = -0.078 + i * 0.0128
        c.box((-0.03, -0.365, z), (0.03, -0.3555, z + 0.0055), "Rubber")
        cutters.append(c.build())
    hs.cut(ob, cutters)
    ob.data.transform(slid)
    out.append(hs.finish(ob, 0.0008, 1))
    return out


def handguard() -> list:
    out = []
    z0, z1 = GUARD_Z
    hw = GUARD_HW
    ch_lo, ch_hi = 0.012, 0.011
    sec = [(-hw + ch_lo, z0), (hw - ch_lo, z0), (hw, z0 + ch_lo), (hw, z1 - ch_hi), (hw - ch_hi, z1),
           (-hw + ch_hi, z1), (-hw, z1 - ch_hi), (-hw, z0 + ch_lo)]
    t = 0.0032
    inner = [(-hw + ch_lo + t * 0.4, z0 + t), (hw - ch_lo - t * 0.4, z0 + t), (hw - t, z0 + ch_lo + t * 0.4),
             (hw - t, z1 - ch_hi - t * 0.4), (hw - ch_hi - t * 0.4, z1 - t), (-hw + ch_hi + t * 0.4, z1 - t),
             (-hw + t, z1 - ch_hi - t * 0.4), (-hw + t, z0 + ch_lo + t * 0.4)]
    b = hs.Builder("Handguard", ["Furniture"])
    b.prism(sec, "y", GUARD_Y[0], GUARD_Y[1], "Furniture")
    ob = b.build()
    cutters = []
    c = hs.Builder("c_in", ["Furniture"])
    c.prism(inner, "y", GUARD_Y[0] - 0.01, GUARD_Y[1] + 0.01, "Furniture")
    cutters.append(c.build())
    slot = hs.rounded_rect(0.0160, 0.0036, 0.0036, 3)
    zc = 0.5 * (z0 + ch_lo + z1 - ch_hi)
    # M-LOK slots on the sides, skipping where the torch rail sits on the right.
    torch_y = EMPTIES["TorchMount"][1]
    for i in range(8):
        y = 0.140 + i * 0.0465
        if y > GUARD_Y[1] - 0.0395:
            break
        for sx in (-1, 1):
            if sx > 0 and torch_y - 0.055 < y < torch_y + 0.070:
                continue
            c = hs.Builder("c_slot", ["Furniture"])
            f = c.prism(slot, "x", -0.006, 0.006, "Furniture")
            c.transform(f, Matrix.Translation((sx * hw, y, zc)))
            cutters.append(c.build())
    # On the lower chamfers, staggered between the side slots.
    for i in range(7):
        y = 0.163 + i * 0.0465
        if y > GUARD_Y[1] - 0.0375:
            break
        for sx in (-1, 1):
            c = hs.Builder("c_low", ["Furniture"])
            f = c.prism(hs.rounded_rect(0.0125, 0.0026, 0.0026, 3), "x", -0.006, 0.006, "Furniture")
            c.transform(f, Matrix.Translation((sx * (hw - 0.5 * ch_lo), y, z0 + 0.5 * ch_lo)) @
                        Matrix.Rotation(math.radians(45.0 * sx), 4, "Y"))
            cutters.append(c.build())
    # Underneath, ahead of the grip rail.
    for y in (0.322, 0.368, 0.414, 0.460):
        if y > GUARD_Y[1] - 0.046:
            break
        c = hs.Builder("c_bot", ["Furniture"])
        f = c.prism(hs.rounded_rect(0.0036, 0.0160, 0.0036, 3), "z", z0 - 0.006, z0 + 0.006, "Furniture")
        c.transform(f, Matrix.Translation((0.0, y, 0.0)))
        cutters.append(c.build())
    hs.cut(ob, cutters)
    hs.finish(ob, 0.0011, 1)
    out.append(ob)

    # Rails: the full top, a grip section underneath, a torch section on the right; a QD socket on the left.
    b = hs.Builder("GuardRails", ["Furniture", "Metal"])
    picatinny(b, GUARD_Y[0] + 0.001, GUARD_Y[1], "Furniture", rail_on("top", 0, 0, 0.0, RAIL_BASE),
              teeth_from=UPPER_Y[0] + 0.0026 + 19 * 0.0100)
    picatinny(b, 0.150, 0.292, "Furniture", rail_on("bottom", 0, 0, 0.0, z0 + 0.0006))
    picatinny(b, torch_y - 0.048, torch_y + 0.062, "Furniture", rail_on("right", 0, 0, hw - 0.0006, BORE_Z))
    for y in (0.165, 0.277):
        b.lathe([(0.0, 0.0), (0.0, 0.0021), (0.0010, 0.0021), (0.0010, 0.0)], "Metal", 10,
                centre=(0.0, y, z0 - 0.0045), axis="z")
    for y in (torch_y - 0.032, torch_y + 0.046):
        b.lathe([(0.0, 0.0), (0.0, 0.0021), (0.0010, 0.0021), (0.0010, 0.0)], "Metal", 10,
                centre=(hw + 0.0045, y, BORE_Z), axis="x")
    b.lathe([(0.0, 0.0), (0.0, 0.0060), (0.0040, 0.0060), (0.0040, 0.0030), (0.0026, 0.0030), (0.0026, 0.0)], "Metal",
            16, centre=(-hw - 0.0040, 0.135, zc), axis="x")
    out.append(hs.finish(b.build(), 0.0003, 1))

    # Barrel and gas block, seen through the slots.
    b = hs.Builder("Barrel", ["Metal", "Detail"])
    b.lathe([(UPPER_Y[1] - 0.004, 0.0), (UPPER_Y[1] - 0.004, 0.0110), (0.13, 0.0110), (0.135, 0.0098),
             (BARREL_END[1] + 0.003, 0.0098), (BARREL_END[1] + 0.003, 0.0)], "Metal", 24,
            centre=(0.0, 0.0, BORE_Z))
    b.box((-0.0115, FRONT_SIGHT_Y - 0.0155, BORE_Z - 0.0115), (0.0115, FRONT_SIGHT_Y + 0.0065, BORE_Z + 0.0130),
          "Detail")
    out.append(hs.finish(b.build(), 0.0004, 1))
    return out


def flash_hider() -> object:
    y0, y1 = BARREL_END[1], MUZZLE[1]
    b = hs.Builder("FlashHider", ["Metal", "Detail"])
    outer = [(y0, 0.0118), (y0 + 0.0035, 0.0118), (y0 + 0.0040, 0.0108), (y0 + 0.0060, 0.0112), (y1 - 0.0030, 0.0112),
             (y1, 0.0098)]
    inner = [(y0, 0.0060), (y1, 0.0060)]
    b.tube(outer, inner, "Metal", 22, centre=(0.0, 0.0, BORE_Z))
    b.lathe([(y0 + 0.012, 0.0), (y0 + 0.012, 0.0062), (y0 + 0.013, 0.0062), (y0 + 0.013, 0.0)], "Detail", 16,
            centre=(0.0, 0.0, BORE_Z))
    ob = b.build()
    cutters = []
    for ang in (0.0, 60.0, 120.0, 180.0):
        c = hs.Builder("c_fh", ["Metal"])
        f = c.box((0.0, y0 + 0.0135, -0.0016), (0.02, y1 - 0.0075, 0.0016), "Metal")
        c.transform(f, Matrix.Translation((0.0, 0.0, BORE_Z)) @ Matrix.Rotation(math.radians(ang), 4, "Y"))
        cutters.append(c.build())
    hs.cut(ob, cutters)
    return hs.finish(ob, 0.0004, 1)


def sight_base(name: str, y0: float, y1: float) -> object:
    b = hs.Builder(name, ["Detail", "Metal"])
    sec = [(-0.0128, RAIL_TOP - 0.0062), (-0.0110, RAIL_TOP - 0.0080), (0.0110, RAIL_TOP - 0.0080),
           (0.0128, RAIL_TOP - 0.0062), (0.0128, 0.0790), (0.0118, 0.0800), (-0.0118, 0.0800), (-0.0128, 0.0790)]
    b.prism(sec, "y", y0, y1, "Detail")
    b.lathe([(0.0, 0.0), (0.0, 0.0032), (0.0016, 0.0032), (0.0020, 0.0024), (0.0020, 0.0)], "Metal", 16,
            centre=(-0.0128, 0.5 * (y0 + y1), RAIL_TOP - 0.0030), axis="x", start=0.0)
    ob = b.build()
    c = hs.Builder("c_rail", ["Detail"])
    c.prism([(-0.0108, RAIL_TOP - 0.0100), (0.0108, RAIL_TOP - 0.0100), (0.0108, RAIL_TOP), (-0.0108, RAIL_TOP)],
            "y", y0 - 0.01, y1 + 0.01, "Detail")
    hs.cut(ob, [c.build()])
    return hs.finish(ob, 0.0004)


def sight_leaf(name: str, y: float, front: bool) -> object:
    """A flip-up sight's leaf, standing: ears either side, an aperture (rear) or a post (front) in the middle."""
    pz = BONES["rearSight" if not front else "frontSight"][2]
    b = hs.Builder(name, ["Detail", "Accent"])
    t = 0.0015
    b.prism([(-0.0090, pz), (0.0090, pz), (0.0090, pz + 0.0030), (-0.0090, pz + 0.0030)], "y", y - t, y + t, "Detail")
    for sx in (-1, 1):
        ear = [(0.0058, pz), (0.0090, pz), (0.0090, SIGHT_Z + 0.0060), (0.0074, SIGHT_Z + 0.0078),
               (0.0058, SIGHT_Z + 0.0060)]
        b.prism([(sx * u, v) for u, v in ear], "y", y - t, y + t, "Detail")
    if front:
        b.prism([(-0.0013, pz), (0.0013, pz), (0.0011, SIGHT_Z - 0.0012), (-0.0011, SIGHT_Z - 0.0012)], "y",
                y - 0.0011, y + 0.0011, "Detail")
        b.prism([(-0.0011, SIGHT_Z - 0.0012), (0.0011, SIGHT_Z - 0.0012), (0.0009, SIGHT_Z), (-0.0009, SIGHT_Z)], "y",
                y - 0.0011, y + 0.0011, "Accent")
    else:
        b.prism([(-0.0026, pz), (0.0026, pz), (0.0026, SIGHT_Z - 0.003), (-0.0026, SIGHT_Z - 0.003)], "y", y - t,
                y + t, "Detail")
        b.tube([(y - t, 0.0040), (y + t, 0.0040)], [(y - t, 0.0013), (y + t, 0.0013)], "Detail", 14,
               centre=(0.0, 0.0, SIGHT_Z))
    return hs.finish(b.build(), 0.0003)


def moving_parts() -> dict:
    parts = {}
    # Trigger.
    b = hs.Builder("Trigger", ["Metal"])
    front = [(0.0065, -0.024), (0.0078, -0.034), (0.0072, -0.044), (0.0048, -0.052), (0.0005, -0.0575)]
    back = [(-0.0030, -0.0555), (0.0010, -0.0500), (0.0028, -0.0430), (0.0030, -0.0350), (0.0010, -0.0260),
            (0.0010, -0.0240)]
    b.prism(front + back, "x", -0.0026, 0.0026, "Metal")
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
    parts["magRelease"] = hs.finish(ob, 0.0003)
    # Charging handle: a T behind the upper, its shaft under the rail.
    b = hs.Builder("ChargingHandle", ["Detail"])
    top = [(-0.0180, -0.1065), (0.0180, -0.1065), (0.0186, -0.1010), (0.0150, -0.0960), (0.0058, -0.0950),
           (0.0058, -0.0700), (-0.0058, -0.0700), (-0.0058, -0.0950), (-0.0150, -0.0960), (-0.0186, -0.1010)]
    b.prism(top, "z", 0.0500, 0.0592, "Detail")
    parts["chargingHandle"] = hs.finish(b.build(), 0.0006)
    # Dust cover, hinged at its bottom on a rod.
    hz = BONES["dustCover"][2]
    b = hs.Builder("DustCover", ["Body", "Metal"])
    b.box((UPPER_HW + 0.0001, 0.0005, hz + 0.0006), (UPPER_HW + 0.0016, 0.0515, 0.0482), "Body")
    b.box((UPPER_HW + 0.0010, 0.004, 0.0440), (UPPER_HW + 0.0026, 0.012, 0.0470), "Body")
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
    b.box((-UPPER_HW, UPPER_Y[0], 0.0), (UPPER_HW, UPPER_Y[1], RAIL_TOP - 0.004), "Body")
    b.prism([(-0.096, 0.020), (-0.096, 0.004), (-0.081, -0.021), (-0.034, -0.025), (0.024, -0.025), (0.024, -0.066),
             (0.1005, -0.066), (0.104, -0.003), (-0.085, 0.0), (-0.085, 0.020)], "x", -LOWER_HW, LOWER_HW, "Body")
    b.prism([(0.024, -0.062), (0.016, -0.068), (-0.024, -0.068), (-0.040, -0.040), (-0.030, -0.040),
             (-0.022, -0.0635), (0.024, -0.0635)], "x", -0.004, 0.004, "Body")
    sec = [(-0.0170, GUARD_Z[0]), (0.0170, GUARD_Z[0]), (GUARD_HW, GUARD_Z[0] + 0.012), (GUARD_HW, RAIL_BASE - 0.011),
           (0.0185, RAIL_TOP - 0.003), (-0.0185, RAIL_TOP - 0.003), (-GUARD_HW, RAIL_BASE - 0.011),
           (-GUARD_HW, GUARD_Z[0] + 0.012)]
    b.prism(sec, "y", GUARD_Y[0], GUARD_Y[1], "Furniture")
    b.lathe([(GUARD_Y[1] - 0.01, 0.0098), (MUZZLE[1], 0.0098)], "Metal", 8, centre=(0.0, 0.0, BORE_Z))
    b.lathe([(BARREL_END[1], 0.0115), (MUZZLE[1], 0.0112)], "Metal", 8, centre=(0.0, 0.0, BORE_Z))
    b.lathe([(TUBE_Y[0], TUBE_R), (-0.090, TUBE_R)], "Detail", 8, centre=(0.0, 0.0, TUBE_Z))
    b.prism([(y + STOCK_IN, z) for y, z in ((-0.200, 0.008), (-0.200, 0.043), (-0.330, 0.054), (-0.357, 0.060),
             (-0.357, -0.088), (-0.318, -0.093), (-0.246, -0.004))], "x", -0.0185, 0.0185, "Furniture")
    rake = math.radians(22.0)
    down = Vector((0.0, -math.sin(rake), -math.cos(rake)))
    fwd = Vector((0.0, math.cos(rake), -math.sin(rake)))
    top = Vector((0.0, -0.050, -0.016))
    rings = []
    for t, hw, fr, bk in ((0.0, 0.0128, 0.0165, 0.0215), (0.38, 0.0144, 0.0232, 0.023), (1.0, 0.0158, 0.0228, 0.0254)):
        c = top + down * (0.122 * t)
        rings.append([c + Vector((x, 0.0, 0.0)) + fwd * f for x, f in hs.superellipse(hw, fr, bk, 2.6, 8)])
    b.loft(rings, "Detail")
    rings = []
    for z in (-0.020, -0.075, -0.222):
        d = max(0.0, -0.075 - z)
        cy = MAG_TOP[1] + d * d / 1.2
        rings.append([(x, cy + y, z) for x, y in hs.rounded_rect(MAG_HW, MAG_HD, 0.006, 1)])
    b.loft(rings, "Detail")
    for x, y0, y1 in ((0.0, -0.0721, -0.0691), (0.0, FRONT_SIGHT_Y - 0.003, FRONT_SIGHT_Y)):
        b.box((-0.008, y0, RAIL_TOP), (0.008, y1, SIGHT_Z + 0.004), "Detail")
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
    body_parts.append(sight_base("RearBase", -0.0835, -0.0580))
    body_parts.append(sight_base("FrontBase", FRONT_SIGHT_Y - 0.0100, FRONT_SIGHT_Y + 0.0125))
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
