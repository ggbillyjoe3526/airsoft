"""The Pump Shotgun's model (SH2, 2026-11-12), from the owner's photos of a spring pump shotgun (art/references/shotgun/
in the project files: a plain barrel over a tube with a fluted cap, a round ribbed pump, a boxy receiver whose top
cover carries a rail and a row of round holes down each shoulder, a short rail on each side, a box magazine (the 30 BB
shell) ahead of the trigger guard, a pistol grip on an adapter and a six-position stock on a receiver extension).
Generic: no maker's marks. The owner (2026-11-12): "Do not include the sights seen on these replicas", so it has no
iron sights (the photos' folding rear sight, front post and reflex frame are left off, with their torch and orange
tip): aimed without an optic, the eye looks along the top rail.

The side outline is traced from the owner's flat side photo (4-left-side-flat-m4-stock.jpg: the left side, muzzle to
the left, so px grows backward; 1.92 px per mm, which its 26 mm barrel and its grip's length agree on) and lined up so
its pistol grip is the AEG Rifle's own (aeg.py `grip`, the same grip the photo shows), foot on foot: the figures'
rifle hold and the hands' land on it as they do on the AEG. The photo's barrel droops 12 px to the muzzle; it is
built level.

It keeps the replica contract (docs/CC0_ASSETS.md › Replica models): the armature PumpShotgun with the bones root,
trigger, selector (the cross-bolt safety), magRelease, magazine and pump; the clips Fire (the pull, then the pump
racked back and home: the game stretches it so the pump is home as it can fire again), Reload, Selector and Inspect
(nothing moves: the left hand stays on the pump); the empties Muzzle, BarrelEnd, FrontSight and RearSight (the sight line
along the rail, no sights on it), MagWell, OpticMount, GripMount and TorchMount; the meshes Body, Pump, Trigger,
Selector, MagRelease, Magazine, FlashHider (the muzzle's ring with its three bores) and Figure (the figures' cut-down
copy); the paintable materials Body, Furniture (the pump, the grip's moulding and the stock), Detail, Accent and
Metal, plus Rubber and BB.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/replicas/shotgun.py <repo root>

It writes assets/models/replicas/shotgun.glb (BL_OUT overrides) and the parts file
assets/models/replicaParts/shotgun.glb (BL_PARTS_OUT): the AEG Rifle's optics, laser and torch moved onto this one's
rails (no silencer, barrels, grips or magazines: owner, 2026-11-12).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import aeg  # noqa: E402
import figure_copy  # noqa: E402
import hardsurface as hs  # noqa: E402
import surface  # noqa: E402
import wear  # noqa: E402

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
OUT = os.environ.get("BL_OUT") or os.path.join(ROOT, "assets/models/replicas/shotgun.glb")
AEG_PARTS = os.path.join(ROOT, "assets/models/replicaParts/aeg.glb")
PARTS_OUT = os.environ.get("BL_PARTS_OUT") or os.path.join(ROOT, "assets/models/replicaParts/shotgun.glb")
ARMATURE = "PumpShotgun"
FPS = 60
# The figures' copy (figure_copy.py): triangles per piece, just under 3,000 in all (the replica budget on a figure).
FIGURE_TRIS = {"Figure": 2552, "Magazine": 240, "FlashHider": 200}
# Skip the wear bake (a quick look at the shapes): BL_NO_WEAR=1.
NO_WEAR = bool(os.environ.get("BL_NO_WEAR"))

# ------------------------------------------------------------------------------------------------------ the photo

# The side photo: px along it (muzzle at 8, butt at 1492), py down it. Blender: +Y forward, +Z up, +X right. The
# photo shows the left side, muzzle to the left, so px grows backward. The origin puts the photo's grip foot (1087,
# 353) on the AEG Rifle's (y -0.079, z -0.0831).
PX_PER_M = 1920.0
ORIGIN_PX = (935.3, 193.4)


def Y(px: float) -> float:
    return (ORIGIN_PX[0] - px) / PX_PER_M


def Z(py: float) -> float:
    return (ORIGIN_PX[1] - py) / PX_PER_M


def smoothstep(a: float, b: float, x: float) -> float:
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def pts(trace: list) -> list:
    """Photo points (px, py[, r px]) as fillet corners (y, z, r m)."""
    return [(Y(p[0]), Z(p[1]), (p[2] / PX_PER_M) if len(p) > 2 else 0.0) for p in trace]


# ------------------------------------------------------------------------------------------------------ measures

# The barrel: its axis, radius, where its plain length ends (the muzzle ring starts) and the muzzle's face.
BORE_PY = 58.0
BORE_Z = Z(BORE_PY)
BARREL_R = 0.0130
BARREL_END_PX = 44.0
MUZZLE_PX = 12.0
# The muzzle's three bores (the game's three BBs a pull leave as they sit: one up, two below), their radius and how
# far from the barrel's axis.
BORE_R = 0.0034
BORE_OFF = 0.0058
# The tube under the barrel, its fluted cap's ends, and the clamp that ties the two.
TUBE_PY = 124.0
TUBE_Z = Z(TUBE_PY)
TUBE_R = 0.0125
CAP_PX = (35.0, 77.0)
CAP_R = 0.0140
CLAMP_PX = (84.0, 110.0)
# The pump: a round ribbed sleeve round the tube, its axis a little under the tube's (the photo's top edge just over
# the tube, its belly 27 mm under it), its ends, radius, ribs and how far it is drawn back.
PUMP_PY = 136.0
PUMP_Z = Z(PUMP_PY)
PUMP_R = 0.0203
PUMP_PX = (73.0, 400.0)
RIB_PX = (113.0, 372.0)
RIBS = 12
RIB_DEPTH = 0.0017
PUMP_TRAVEL = 0.062
# The action bars from the pump into the receiver, one each side of the tube.
BAR_PY = (103.0, 112.0)
BAR_HW = 0.0012
# The receiver: its front and where its back's slope starts, its flat top (under the rail), where the shoulders'
# chamfers end and its foot; its half widths (the body, the cover over it, the flat top).
RX_PX = (553.0, 925.0)
RX_TOP_PY = 15.0
RX_SHOULDER_PY = 52.0
RX_BOTTOM_PY = 150.0
RX_HW = 0.0203
COVER_HW = 0.0213
TOP_HW = 0.0112
# The row of round holes down each shoulder: the first one's centre, their pitch, how many, their radius and depth.
HOLE_PX = 603.0
HOLE_PITCH = 44.0
HOLES = 8
HOLE_PY = 37.0
HOLE_R = 0.0066
HOLE_DEPTH = 0.0040
# The rails (low, as the Compact SMG's): the top rail's ends and its teeth's tops; the short one each side.
RAIL_H = 0.0068
TOP_RAIL_PX = (577.0, 925.0)
RAIL_TOP = Z(5.0)
RAIL_BASE = RAIL_TOP - RAIL_H
SIDE_RAIL_PX = (775.0, 897.0)
SIDE_RAIL_PY = 68.5
# The sight line along the rail (no sights: the owner): this far over its teeth, so the stock's comb under your eye
# (STOCK_TOP_PY) is cut by the view's near plane below the screen's foot when aimed, not across it.
SIGHT_Z = RAIL_TOP + 0.0095
# The grip's adapter behind the receiver (one moulding with the grip and the trigger guard): its half width, its top
# and the round tower at its back the receiver extension screws into.
ADAPTER_HW = 0.0196
ADAPTER_TOP_PY = 36.0
EXT_PY = 78.0
EXT_Z = Z(EXT_PY)
EXT_R = 0.0148
TOWER_R = 0.0215
TOWER_PX = (1076.0, 1093.0)
NUT_PX = (1093.0, 1122.0)
GUARD_HW = 0.0062
# The magazine (the 30 BB shell): its front and back, its top in the well, its foot (front, back), its half width.
MAG_PX = (577.0, 730.0)
MAG_TOP_PY = 124.0
MAG_FOOT_PY = (210.0, 225.0)
MAG_HW = 0.0140
MAG_TOP = (0.0, Y(sum(MAG_PX) / 2.0), Z(MAG_TOP_PY))
# The stock: its body round the extension (front, back), its top and underside, half width; the pad behind it.
STOCK_PX = (1122.0, 1468.0)
STOCK_TOP_PY = 35.0
STOCK_FOOT_PY = 131.0
STOCK_HW = 0.0185
PAD_PX = 1492.0
PAD_HW = 0.0205
# The stock's side grooves: three rows of five.
GROOVE_ROWS = ((84.0, 95.0), (99.5, 110.5), (115.0, 124.0))
GROOVE_PX = 1152.0
GROOVE_PITCH = 63.75
GROOVE_LEN = 59.25
GROOVE_DEPTH = 0.0058
# The grooves open into the stock's hollow, as the photos' do (they read as black slots): one chamber across the
# stock behind each of the upper two rows and the lowest (front, back px; each chamber's top and foot py, a shelf
# between them; the side wall's thickness, m). What the slots show is the receiver extension, which runs the hollow's
# whole length (to EXT_END_PX), and the rail under it (the one a real stock's latch pin locks into: its top and foot
# py, its half width at each; drawn as a keel tapering down from the tube's flanks, so its sides face down as the
# tube's do and take no light), both black aluminium: every slot reads black end to end from either side, where a
# polymer wall or an upright rail behind them read grey (the critic, SH2). The five columns are equal and the last
# runs to the butt pad's lip, as photo 4's (slots 59 to 60 px on a 64 px pitch, the last ending at 1466): its cut
# runs out of the body's back under the pad (GROOVE_OUT, px), and the hollow, the extension and its rail run back
# into the pad too.
HOLLOW_PX = (1146.0, 1472.0)
GROOVE_OUT = 6.0
HOLLOW_PY = ((81.0, 111.8), (113.6, 127.0))
HOLLOW_WALL = 0.0022
EXT_END_PX = 1467.0
EXT_RAIL_PY = (98.0, 126.0)
EXT_RAIL_HW = (0.0105, 0.0008)
# The sling loop hanging at the fin's toe (the photos' left side): its lug on the fin's front edge and the wire loop
# through it (centre px, py; half width and height, m; the wire's radius).
TOE_LOOP = (1437.5, 289.0, 0.0034, 0.0128, 0.0011)
TOE_LUG = ((1432.0, 259.0), (1449.0, 259.0), (1451.0, 273.0), (1434.0, 273.0))

TORCH_Y = Y(sum(SIDE_RAIL_PX) / 2.0)
SIDE_RAIL_X = COVER_HW - 0.0006
SIDE_RAIL_TOP_X = SIDE_RAIL_X + RAIL_H

EMPTIES = {
    "Muzzle": (0.0, Y(MUZZLE_PX), BORE_Z), "BarrelEnd": (0.0, Y(BARREL_END_PX), BORE_Z),
    "FrontSight": (0.0, Y(TOP_RAIL_PX[0] + 8.0), SIGHT_Z), "RearSight": (0.0, Y(TOP_RAIL_PX[1] - 8.0), SIGHT_Z),
    "MagWell": MAG_TOP, "OpticMount": (0.0, Y(840.0), RAIL_TOP),
    "GripMount": (0.0, Y(236.0), PUMP_Z - PUMP_R),
    "TorchMount": (SIDE_RAIL_TOP_X, TORCH_Y, Z(SIDE_RAIL_PY)),
}

TRIGGER_PIVOT = (936.0, 154.0)
SAFETY = (967.0, 171.0)
SAFETY_R = 0.0042
SAFETY_PUSH = 0.0026
BONES = {
    "root": (0.0, 0.0, 0.0),
    "trigger": (0.0, Y(TRIGGER_PIVOT[0]), Z(TRIGGER_PIVOT[1])),
    "selector": (0.0, Y(SAFETY[0]), Z(SAFETY[1])),
    "magRelease": (0.0, Y(741.0), Z(150.0)),
    "magazine": MAG_TOP,
    "pump": (0.0, Y(sum(PUMP_PX) / 2.0), PUMP_Z),
}
BONE_LENGTH = 0.0200

# The AEG Rifle's mounts its parts file's parts sit on (aeg.py EMPTIES; its laser on the left rail), which
# build_parts moves onto this one's.
AEG_MOUNTS = {"optic_": (0.0, 0.025, 0.0735), "light_": (0.0259, 0.195, 0.04725), "laser_": (-0.0259, 0.132, 0.04725)}
PART_MOUNTS = {
    "optic_": EMPTIES["OpticMount"], "light_": EMPTIES["TorchMount"],
    "laser_": (-SIDE_RAIL_TOP_X, TORCH_Y, Z(SIDE_RAIL_PY)),
}

# Plain colours (the game paints the five scheme materials; these are what a viewer without it shows: black metal
# and black polymer a shade lighter).
MATERIALS = {
    "Body": (0x24272c, 0.45, 0.2), "Furniture": (0x2b2d31, 0.7, 0.0), "Detail": (0x30343b, 0.55, 0.0),
    "Accent": (0xf2f0ea, 0.5, 0.0), "Metal": (0x484d56, 0.4, 0.4), "Rubber": (0x1c1d20, 0.8, 0.0),
    "BB": (0xf4f1e8, 0.3, 0.0),
}

# What each material's faces are made of unless a part says otherwise (surface.py, MQ1; owner, 2026-11-12: "Use the
# correct materials and textures (metals, polymer)"), as the pump shotgun it follows: a steel barrel, tube and
# action bars, an aluminium receiver and cover, a polymer pump, grip moulding, stock and magazine, steel controls.
SURFACES = {"Body": "steel", "Furniture": "polymer", "Detail": "steel", "Accent": "polymer", "Metal": "steel"}
# The parts that differ, by their object's name.
PART_SURFACES = {
    "Receiver": "aluminium", "TopRail": "aluminium", "SideRails": "aluminium", "Extension": "aluminium",
    "Magazine": "polymer", "Lever": "polymer", "Selector": "polymer", "RearRail": "polymer",
}


# ------------------------------------------------------------------------------------------------------ helpers

def side_prism(b: hs.Builder, trace: list, hw: float, mat: str, seg: int = 3, x0: float = None) -> list:
    """A side outline (photo points with corner radii) extruded across, -hw to hw (or x0 to hw)."""
    poly = [(y, z) for y, z in hs.fillet(pts(trace), seg)]
    return b.prism(poly, "x", -hw if x0 is None else x0, hw, mat)


def section(hw: float, zb: float, zt: float, rb: float, rt: float, seg: int = 4) -> list:
    """A cross-section (x, z): a rectangle hw either side from zb to zt, its bottom corners rounded by rb and its top
    ones by rt, counter-clockwise from the bottom right."""
    out = []
    for cx, cz, r, a0 in ((hw - rb, zb + rb, rb, -90.0), (hw - rt, zt - rt, rt, 0.0), (-hw + rt, zt - rt, rt, 90.0),
                          (-hw + rb, zb + rb, rb, 180.0)):
        for i in range(seg + 1):
            a = math.radians(a0 + 90.0 * i / seg)
            out.append((cx + r * math.cos(a), cz + r * math.sin(a)))
    return out


def shoulders(hw: float, top_hw: float, zb: float, zs: float, zt: float, foot: float = 0.0025) -> list:
    """The receiver's section (x, z): straight sides from its chamfered foot up to the shoulders at zs, then a flat
    chamfer in to the flat top (top_hw either side) at zt."""
    return [(-hw + foot, zb), (hw - foot, zb), (hw, zb + foot), (hw, zs), (top_hw, zt), (-top_hw, zt), (-hw, zs),
            (-hw, zb + foot)]


def section_prism(name: str, poly: list, y0: float, y1: float, mat: str) -> object:
    c = hs.Builder(name, [mat])
    c.prism(poly, "y", min(y0, y1), max(y0, y1), mat)
    return c.build()


def picatinny(b: hs.Builder, y0: float, y1: float, mat: str, place: Matrix) -> None:
    """A low rail from y0 to y1 along its own +Y, its base at its z 0, built upright and moved by `place` (smg.py's)."""
    y0, y1 = min(y0, y1), max(y0, y1)
    base = [(-0.0085, -0.004), (0.0085, -0.004), (0.0085, 0.0020), (0.0106, 0.0036), (0.0106, 0.0042),
            (-0.0106, 0.0042), (-0.0106, 0.0036), (-0.0085, 0.0020)]
    faces = b.prism(base, "y", y0, y1, mat)
    tooth = [(-0.0106, 0.0041), (0.0106, 0.0041), (0.0104, 0.0046), (0.0080, RAIL_H), (-0.0080, RAIL_H),
             (-0.0104, 0.0046)]
    y = y0 + 0.0026
    while y + 0.0050 <= y1 - 0.0010:
        faces += b.prism(tooth, "y", y, y + 0.0050, mat)
        y += 0.0100
    b.transform(faces, place)


def side_place(sx: int, zc: float, x: float) -> Matrix:
    """Where a rail on the right (sx 1) or left (-1) side goes: its base on the face at x, centred at height zc."""
    return Matrix.Translation((sx * x, 0.0, zc)) @ Matrix.Rotation(sx * math.pi * 0.5, 4, "Y")


def screw(b: hs.Builder, px: float, py: float, r: float, x: float, sides: tuple = (-1, 1), mat: str = "Metal",
          seg: int = 10) -> None:
    """A cross-head screw's domed head on each side face at x (its centre a photo point)."""
    for sx in sides:
        prof = [(-0.0006, 0.0), (-0.0006, r), (0.0004, r), (0.0010, r * 0.6), (0.0011, 0.0)]
        prof = [(sx * a, rr) for a, rr in prof]
        if sx < 0:
            prof = list(reversed(prof))
        b.lathe(prof, mat, seg, centre=(sx * x, Y(px), Z(py)), axis="x")


def box_cutter(name: str, lo: tuple, hi: tuple) -> object:
    c = hs.Builder(name, ["Body"])
    c.box(tuple(min(a, b2) for a, b2 in zip(lo, hi)), tuple(max(a, b2) for a, b2 in zip(lo, hi)), "Body")
    return c.build()


def slot_cutter(name: str, px0: float, px1: float, py0: float, py1: float, x0: float, x1: float,
                r: float = None, seg: int = 3) -> object:
    """A rounded slot's cutter: the photo's rectangle px0..px1 by py0..py1, from x0 to x1 across."""
    hy, hz = abs(px1 - px0) / 2.0 / PX_PER_M, abs(py1 - py0) / 2.0 / PX_PER_M
    cy, cz = Y((px0 + px1) / 2.0), Z((py0 + py1) / 2.0)
    r = min(hy, hz) * 0.98 if r is None else r
    c = hs.Builder(name, ["Body"])
    c.prism([(y + cy, z + cz) for y, z in hs.rounded_rect(hy, hz, r, seg)], "x", min(x0, x1), max(x0, x1), "Body")
    return c.build()


def weld(ob: object, other: object) -> None:
    """Unions `other` into `ob` (exact solver) keeping `other`'s own materials on its faces, then deletes it."""
    mod = ob.modifiers.new("weld", "BOOLEAN")
    mod.operation = "UNION"
    mod.solver = "EXACT"
    mod.use_self = True
    mod.use_hole_tolerant = True
    mod.material_mode = "TRANSFER"
    mod.object = other
    hs.apply_modifiers(ob)
    bpy.data.objects.remove(other, do_unlink=True)


def repaint(ob: object, mat: str) -> object:
    """Every face of `ob` in the material `mat` (aeg.py's grip is built in Body; here it is the Furniture's)."""
    me = ob.data
    me.materials.clear()
    me.materials.append(surface.material(mat))
    for p in me.polygons:
        p.material_index = 0
    return ob


def fluted(b: hs.Builder, profile: list, mat: str, flutes: int, depth: float, centre: tuple, plain: float) -> list:
    """A lathe along Y whose radius dips `depth` in `flutes` grooves round it where the profile's radius is over
    `plain` (a knurled cap): two points a flute."""
    seg = flutes * 4
    rings = []
    for a, r in profile:
        ring = []
        for i in range(seg):
            t = 2.0 * math.pi * i / seg
            rr = r - (depth if r > plain and i % 4 == 0 else 0.0)
            ring.append((centre[0] + rr * math.cos(t), centre[1] + a, centre[2] + rr * math.sin(t)))
        rings.append(ring)
    return b.loft(rings, mat, cap0=profile[0][1] > 1e-6, cap1=profile[-1][1] > 1e-6)


# ------------------------------------------------------------------------------------------------------ the front

def barrel() -> list:
    """The barrel out of the receiver, its collar at the receiver's face, the tube under it with its fluted cap, the
    clamp that ties the two and the sling loop's stud under the cap."""
    out = []
    b = hs.Builder("Barrel", ["Body"])
    b.lathe([(Y(RX_PX[0] + 12), 0.0), (Y(RX_PX[0] + 12), BARREL_R + 0.0016), (Y(RX_PX[0] - 9), BARREL_R + 0.0016),
             (Y(RX_PX[0] - 12), BARREL_R), (Y(BARREL_END_PX), BARREL_R), (Y(BARREL_END_PX), 0.0)], "Body", 40,
            centre=(0.0, 0.0, BORE_Z))
    b.lathe([(Y(RX_PX[0] + 12), 0.0), (Y(RX_PX[0] + 12), TUBE_R + 0.0014), (Y(RX_PX[0] - 7), TUBE_R + 0.0014),
             (Y(RX_PX[0] - 10), TUBE_R), (Y(CAP_PX[1] - 2), TUBE_R), (Y(CAP_PX[1] - 2), 0.0)], "Body", 40,
            centre=(0.0, 0.0, TUBE_Z))
    out.append(hs.finish(b.build(), 0.0004, 1))
    # The cap: a plain collar, then a fluted knob tapering to its rounded nose.
    b = hs.Builder("TubeCap", ["Body"])
    y0, y1 = Y(CAP_PX[1]), Y(CAP_PX[0])
    n = y1 - y0
    prof = [(y0, 0.0), (y0, TUBE_R + 0.0006), (y0 + 0.0030, TUBE_R + 0.0006), (y0 + 0.0036, CAP_R),
            (y0 + n * 0.55, CAP_R), (y0 + n * 0.80, CAP_R - 0.0012), (y0 + n * 0.93, CAP_R - 0.0030),
            (y1 - 0.0006, CAP_R - 0.0048), (y1, CAP_R - 0.0060), (y1, 0.0)]
    fluted(b, prof, "Body", 16, 0.0009, (0.0, 0.0, TUBE_Z), CAP_R - 0.0035)
    out.append(hs.finish(b.build(), 0.0))
    # The clamp: a band round the barrel, a band round the tube, a web between with its cross screw.
    b = hs.Builder("Clamp", ["Body", "Metal"])
    y0, y1 = Y(CLAMP_PX[1]), Y(CLAMP_PX[0])
    for zc, r in ((BORE_Z, BARREL_R), (TUBE_Z, TUBE_R)):
        b.lathe([(y0, r - 0.001), (y0, r + 0.0018), (y0 + 0.0008, r + 0.0024), (y1 - 0.0008, r + 0.0024),
                 (y1, r + 0.0018), (y1, r - 0.001)], "Body", 32, centre=(0.0, 0.0, zc), cap=False)
    b.prism(hs.rounded_rect(0.0062, (BORE_Z - TUBE_Z) / 2.0 - 0.006, 0.0015, 2), "y", y0 + 0.0012, y1 - 0.0012, "Body",
            offset=(0.0, 0.0, (BORE_Z + TUBE_Z) / 2.0))
    screw(b, sum(CLAMP_PX) / 2.0, BORE_PY + (TUBE_PY - BORE_PY) / 2.0, 0.0026, 0.0062)
    out.append(hs.finish(b.build(), 0.0004, 1))
    # The sling stud under the cap and its loop.
    b = hs.Builder("Swivel", ["Metal"])
    yc = Y(61.0)
    zc = TUBE_Z - CAP_R
    b.lathe([(0.0, 0.0), (0.0, 0.0034), (-0.0050, 0.0034), (-0.0062, 0.0026), (-0.0062, 0.0)], "Metal", 16,
            centre=(0.0, yc, zc + 0.001), axis="z")
    loop = []
    for i in range(12):
        a = 2.0 * math.pi * i / 12
        c = Vector((0.0, yc + 0.0052 * math.cos(a) * 0.55, zc - 0.0105 + 0.0085 * math.sin(a)))
        ring = []
        for k in range(5):
            t = 2.0 * math.pi * k / 5
            n2 = Vector((0.0, math.cos(a) * 0.55, math.sin(a))).normalized()
            ring.append(tuple(c + n2 * (0.0012 * math.cos(t)) + Vector((0.0012 * math.sin(t), 0.0, 0.0))))
        loop.append(ring)
    loop.append(loop[0])
    b.loft(loop, "Metal", cap0=False, cap1=False)
    out.append(hs.finish(b.build(), 0.0, 1))
    return out


def flash_hider() -> object:
    """The muzzle: a ring on the barrel's end, its face set back with the three bores in it (one up, two below, as
    the three BBs of a pull leave)."""
    b = hs.Builder("FlashHider", ["Body", "Detail"])
    y0, y1 = Y(BARREL_END_PX), Y(MUZZLE_PX)
    r = BARREL_R
    b.lathe([(y0, 0.0), (y0, r), (y0 + 0.0020, r), (y0 + 0.0028, r + 0.0010), (y1 - 0.0016, r + 0.0010),
             (y1, r - 0.0004), (y1, r - 0.0022), (y1 - 0.0030, r - 0.0030), (y1 - 0.0030, 0.0)], "Body", 32,
            centre=(0.0, 0.0, BORE_Z))
    ob = b.build()
    cutters = []
    for k in range(3):
        a = math.radians(90.0 + 120.0 * k)
        c = hs.Builder("c_bore", ["Body"])
        c.lathe([(y1 - 0.0180, 0.0), (y1 - 0.0180, BORE_R), (y1 + 0.004, BORE_R), (y1 + 0.004, 0.0)], "Body", 16,
                centre=(BORE_OFF * math.cos(a), 0.0, BORE_Z + BORE_OFF * math.sin(a)))
        cutters.append(c.build())
    hs.cut(ob, cutters)
    return hs.finish(ob, 0.0003, 1)


def pump() -> object:
    """The pump: a round sleeve ribbed all the way round (twelve ribs), plain at its ends, with the two action bars
    that run back from it into the receiver. It rides the pump bone."""
    b = hs.Builder("Pump", ["Furniture", "Metal"])
    y_at = lambda px: Y(px)  # noqa: E731
    r0 = PUMP_R
    prof = [(y_at(PUMP_PX[1]), 0.0), (y_at(PUMP_PX[1]), r0 - 0.0050), (y_at(PUMP_PX[1] - 3.0), r0 - 0.0018),
            (y_at(PUMP_PX[1] - 8.0), r0 - 0.0004), (y_at(PUMP_PX[1] - 14.0), r0)]
    pitch = (RIB_PX[1] - RIB_PX[0]) / RIBS
    for k in range(RIBS - 1, -1, -1):
        s = RIB_PX[0] + pitch * k
        # From the back: the groove behind this rib, its rear shoulder, crown and front shoulder.
        prof += [(y_at(s + pitch - 1.0), r0), (y_at(s + pitch - 2.6), r0 - RIB_DEPTH * 0.75),
                 (y_at(s + pitch - 4.0), r0 - RIB_DEPTH), (y_at(s + pitch - 6.0), r0 - RIB_DEPTH),
                 (y_at(s + pitch - 7.4), r0 - RIB_DEPTH * 0.75), (y_at(s + pitch - 9.0), r0)]
    prof += [(y_at(RIB_PX[0] - 2.0), r0), (y_at(PUMP_PX[0] + 12.0), r0), (y_at(PUMP_PX[0] + 6.0), r0 - 0.0008),
             (y_at(PUMP_PX[0] + 2.0), r0 - 0.0030), (y_at(PUMP_PX[0]), r0 - 0.0062), (y_at(PUMP_PX[0]), 0.0)]
    b.lathe(prof, "Furniture", 36, centre=(0.0, 0.0, PUMP_Z))
    for sx in (-1, 1):
        x = sx * (TUBE_R + 0.0002)
        b.box((x - BAR_HW, Y(RX_PX[0] + 150.0), Z(BAR_PY[1])), (x + BAR_HW, Y(PUMP_PX[1] - 6.0), Z(BAR_PY[0])), "Metal")
    return hs.finish(b.build(), 0.0)


# ------------------------------------------------------------------------------------------------------ receiver

def receiver() -> list:
    """The receiver: a box with chamfered shoulders, the cover over its top half a step proud (its skirt's edge
    running back along each side), the row of round holes down each shoulder, a pressed panel each side over the
    magazine, the magazine's well underneath, its screws."""
    out = []
    # The body, to the foot.
    b = hs.Builder("Receiver", ["Body"])
    back = [(RX_PX[1], RX_TOP_PY, 4), (983, 86, 6), (962, RX_BOTTOM_PY)]
    side_prism(b, [(RX_PX[0], RX_BOTTOM_PY), (RX_PX[0], 34, 3), (572, RX_TOP_PY, 3)] + back, 0.03, "Body", 4)
    ob = b.build()
    hs.cut(ob, [section_prism("c_rx", shoulders(RX_HW, TOP_HW - 0.0008, Z(RX_BOTTOM_PY), Z(RX_SHOULDER_PY + 2),
                                                 Z(RX_TOP_PY) - 0.0004), Y(1000), Y(540), "Body")], "INTERSECT")
    # The cover: the top half, a step wider, its skirt slanting down behind the front and stepping down toward the back.
    c = hs.Builder("Cover", ["Body"])
    side_prism(c, [(RX_PX[0], 82), (RX_PX[0], 34, 3), (572, RX_TOP_PY, 3), (RX_PX[1], RX_TOP_PY, 4), (983, 86, 6),
                   (974, 118, 3), (800, 118, 5), (786, 108, 5), (600, 108, 4)], 0.03, "Body", 4)
    cover = c.build()
    hs.cut(cover, [section_prism("c_cv", shoulders(COVER_HW, TOP_HW, Z(RX_BOTTOM_PY), Z(RX_SHOULDER_PY), Z(RX_TOP_PY)),
                                 Y(1000), Y(540), "Body")], "INTERSECT")
    weld(ob, cover)
    cutters = []
    # The holes down each shoulder, square to its face.
    dx, dz = COVER_HW - TOP_HW, Z(RX_TOP_PY) - Z(RX_SHOULDER_PY)
    tilt = math.atan2(dx, dz)
    mid_x = TOP_HW + dx * (HOLE_PY - RX_TOP_PY) / (RX_SHOULDER_PY - RX_TOP_PY)
    mid_z = Z(HOLE_PY)
    for sx in (-1, 1):
        for k in range(HOLES):
            h = hs.Builder("c_hole", ["Body"])
            f = h.lathe([(-HOLE_DEPTH, 0.0), (-HOLE_DEPTH, HOLE_R - 0.0006), (-HOLE_DEPTH + 0.0008, HOLE_R),
                         (0.01, HOLE_R), (0.01, 0.0)], "Body", 20, axis="x")
            h.transform(f, Matrix.Translation((sx * mid_x, Y(HOLE_PX + HOLE_PITCH * k), mid_z))
                        @ Matrix.Rotation(-sx * tilt, 4, "Y")
                        @ (Matrix.Identity(4) if sx > 0 else Matrix.Rotation(math.pi, 4, "Z")))
            cutters.append(h.build())
    # A pressed panel each side over the magazine, and the magazine's well.
    for sx in (-1, 1):
        cutters.append(slot_cutter("c_panel", 606, 772, 114, 145, sx * (RX_HW - 0.0010), sx * (RX_HW + 0.01), 0.0030))
    cutters.append(box_cutter("c_well", (-MAG_HW - 0.0004, Y(MAG_PX[1] + 1), Z(MAG_TOP_PY - 2)),
                              (MAG_HW + 0.0004, Y(MAG_PX[0] - 1), Z(RX_BOTTOM_PY + 10))))
    # The trigger's slot through the foot.
    cutters.append(box_cutter("c_trig", (-0.0040, Y(950), Z(128)), (0.0040, Y(916), Z(RX_BOTTOM_PY + 10))))
    hs.cut(ob, cutters)
    out.append(hs.finish(ob, 0.0009, 1))
    # Screws: two through the receiver's foot each side.
    b = hs.Builder("RxScrews", ["Metal"])
    screw(b, 840, 127, 0.0030, RX_HW)
    screw(b, 948, 128, 0.0030, RX_HW)
    out.append(hs.finish(b.build(), 0.0002, 1, weighted=False))
    return out


def rails() -> list:
    """The top rail along the cover and the short rail on each side of it, each side one's two screws."""
    b = hs.Builder("TopRail", ["Body"])
    picatinny(b, Y(TOP_RAIL_PX[1]), Y(TOP_RAIL_PX[0]), "Body", Matrix.Translation((0.0, 0.0, RAIL_BASE)))
    top = hs.finish(b.build(), 0.0004, 1)
    b = hs.Builder("SideRails", ["Body", "Metal"])
    for sx in (-1, 1):
        picatinny(b, Y(SIDE_RAIL_PX[1]), Y(SIDE_RAIL_PX[0]), "Body", side_place(sx, Z(SIDE_RAIL_PY), SIDE_RAIL_X))
        for px in (803.0, 868.0):
            b.lathe([(0.0, 0.0), (0.0, 0.0030), (0.0008, 0.0030), (0.0012, 0.0022), (0.0012, 0.0)] if sx > 0 else
                    [(-0.0012, 0.0), (-0.0012, 0.0022), (-0.0008, 0.0030), (0.0, 0.0030), (0.0, 0.0)], "Metal", 14,
                    centre=(sx * (SIDE_RAIL_X + 0.0042), Y(px), Z(SIDE_RAIL_PY)), axis="x")
    return [top, hs.finish(b.build(), 0.0004, 1)]


# ------------------------------------------------------------------------------------------------------ the grip

# The trigger guard: a plate under the receiver's foot, its edge running from behind the magazine down round under
# the trigger and up into the adapter, and the oval window through it (centre and half sizes, photo pixels; its top
# is cut flat a lip under the foot).
GUARD_OUTER = [(796, 146), (800, 158), (836, 184), (870, 204), (908, 217), (942, 214), (966, 203), (978, 189),
               (980, 146)]
GUARD_WINDOW = (909.0, 181.0, 47.0, 27.0)
GUARD_WINDOW_TOP_PY = 156.0
# The trigger's blade: its front edge and its back edge, top to tip (wide at its top, a point swept forward).
TRIGGER_FRONT = [(918, 138), (919, 157), (929, 167), (934, 180), (934, 191), (928, 200)]
TRIGGER_BACK = [(948, 138), (948, 160), (945, 176), (942, 188), (937, 197), (930, 201)]


def lower() -> list:
    """The grip's adapter behind the receiver, the AEG Rifle's pistol grip under it and the trigger guard, one
    polymer moulding; the round tower at its back; its screws; the short rail on its top."""
    out = []
    b = hs.Builder("Lower", ["Furniture"])
    side_prism(b, [(945, 41), (962, ADAPTER_TOP_PY, 4), (TOWER_PX[1], ADAPTER_TOP_PY, 5), (TOWER_PX[1], 124, 4),
                   (1080, 132, 10), (1066, 147, 12), (1060, 172), (1057, 198, 6), (1016, 216, 10), (990, 219, 8),
                   (974, 196, 6), (972, 153), (962, RX_BOTTOM_PY), (983, 86)], 0.03, "Furniture", 5)
    ob = b.build()
    # Rounded over its top (it is the nearest thing under the eye), chamfered at its foot.
    hs.cut(ob, [section_prism("c_ad", section(ADAPTER_HW, Z(240), Z(ADAPTER_TOP_PY), 0.0030, 0.0085, 8), Y(1110),
                              Y(930), "Furniture")], "INTERSECT")
    # The tower the extension screws into.
    t = hs.Builder("Tower", ["Furniture"])
    t.lathe([(Y(TOWER_PX[1]), 0.0), (Y(TOWER_PX[1]), TOWER_R - 0.0010), (Y(TOWER_PX[1] - 2), TOWER_R),
             (Y(TOWER_PX[0]), TOWER_R), (Y(TOWER_PX[0] - 6), TOWER_R - 0.0030), (Y(TOWER_PX[0] - 6), 0.0)], "Furniture",
            36, centre=(0.0, 0.0, EXT_Z))
    # The guard: a plate from the receiver's foot down round under the trigger and up into the adapter's front, the
    # oval window through it.
    g = hs.Builder("Guard", ["Furniture"])
    g.prism(hs.smooth([(Y(px), Z(py)) for px, py in GUARD_OUTER], 2), "x", -GUARD_HW, GUARD_HW, "Furniture")
    guard = g.build()
    w = hs.Builder("c_window", ["Furniture"])
    cx, cy, rx, ry = GUARD_WINDOW
    oval = []
    for k in range(40):
        a = math.tau * k / 40.0
        py = cy + ry * math.sin(a)
        if py >= GUARD_WINDOW_TOP_PY:
            oval.append((Y(cx + rx * math.cos(a)), Z(py)))
    w.prism(oval, "x", -0.03, 0.03, "Furniture")
    hs.cut(guard, [w.build()])
    grip, panels = aeg.grip()
    repaint(grip, "Furniture")
    repaint(panels, "Furniture")
    hs.cut(ob, [t.build(), guard, grip], "UNION")
    out.append(hs.finish(ob, 0.0016, 2))
    panels.name = "GripPanels"
    out.append(hs.finish(panels, 0.0))
    # Its screws (the photo's three each side) and the short rail on its top.
    b = hs.Builder("LowerScrews", ["Metal"])
    screw(b, 993, 99, 0.0030, ADAPTER_HW)
    screw(b, 981, 135, 0.0028, ADAPTER_HW)
    screw(b, 1040, 108, 0.0030, ADAPTER_HW)
    out.append(hs.finish(b.build(), 0.0002, 1, weighted=False))
    b = hs.Builder("RearRail", ["Furniture"])
    picatinny(b, Y(1090), Y(992), "Furniture", Matrix.Translation((0.0, 0.0, Z(ADAPTER_TOP_PY) - 0.0006)))
    out.append(hs.finish(b.build(), 0.0004, 1))
    return out


def trigger() -> object:
    b = hs.Builder("Trigger", ["Detail"])
    front = hs.smooth([(Y(px), Z(py)) for px, py in TRIGGER_FRONT], 2)
    back = hs.smooth([(Y(px), Z(py)) for px, py in TRIGGER_BACK], 2)
    b.prism(front + list(reversed(back)), "x", -0.0032, 0.0032, "Detail")
    return hs.finish(b.build(), 0.0009, 2)


def selector() -> object:
    """The cross-bolt safety through the back of the trigger guard: a round button proud on each side (the left
    further out on safe; the Selector clip pushes it across)."""
    b = hs.Builder("Selector", ["Detail", "Accent"])
    x = GUARD_HW + 0.0010
    b.lathe([(-x - 0.0030, 0.0), (-x - 0.0030, SAFETY_R - 0.0008), (-x - 0.0022, SAFETY_R), (x + 0.0004, SAFETY_R),
             (x + 0.0012, SAFETY_R - 0.0008), (x + 0.0012, 0.0)], "Detail", 12,
            centre=(0.0, Y(SAFETY[0]), Z(SAFETY[1])), axis="x")
    # The band that shows on the left while it is safe.
    b.tube([(-x - 0.0019, SAFETY_R + 0.0001), (-x - 0.0006, SAFETY_R + 0.0001)],
           [(-x - 0.0019, SAFETY_R - 0.0004), (-x - 0.0006, SAFETY_R - 0.0004)], "Accent", 12,
           centre=(0.0, Y(SAFETY[0]), Z(SAFETY[1])), axis="x")
    return hs.finish(b.build(), 0.0003, 1)


def mag_release() -> object:
    """The magazine's catch: a paddle behind it under the receiver's foot."""
    b = hs.Builder("MagRelease", ["Detail"])
    side_prism(b, [(733, 146), (748, 146), (750, 156, 3), (746, 170, 4), (740, 176, 2), (735, 174, 2), (737, 160, 4)],
               0.0075, "Detail", 3)
    return hs.finish(b.build(), 0.0008, 2)


def magazine() -> object:
    """The 30 BB shell: a box magazine, its foot slanting down to the back, two grooves down each side toward each
    end, an oval grip pad each side, a floor plate's lip, and at its top the feed lips with the next three BBs."""
    b = hs.Builder("Magazine", ["Detail", "Rubber", "BB"])
    side_prism(b, [(MAG_PX[0], MAG_TOP_PY, 2), (MAG_PX[1], MAG_TOP_PY, 2), (MAG_PX[1], MAG_FOOT_PY[1] - 4),
                   (MAG_PX[0], MAG_FOOT_PY[0] - 4)], MAG_HW, "Detail", 2)
    ob = b.build()
    cutters = []
    for sx in (-1, 1):
        for px in (601.0, 620.0, 688.0, 707.0):
            cutters.append(slot_cutter("c_mg", px, px + 6.0, 156, 232, sx * (MAG_HW - 0.0009), sx * (MAG_HW + 0.01),
                                       0.0006, 1))
    hs.cut(ob, cutters)
    hs.finish(ob, 0.0012, 1)
    d = hs.Builder("MagBits", ["Detail", "Rubber", "BB"])
    # The floor plate, proud all round.
    side_prism(d, [(MAG_PX[0] - 2, MAG_FOOT_PY[0] - 7), (MAG_PX[1] + 2, MAG_FOOT_PY[1] - 7),
                   (MAG_PX[1] + 2, MAG_FOOT_PY[1], 3), (MAG_PX[0] - 2, MAG_FOOT_PY[0], 3)], MAG_HW + 0.0009, "Detail",
               2)
    # The oval pads: ridged rubber, a little proud.
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (MAG_HW - 0.0004), sx * (MAG_HW + 0.0007)))
        for k in range(6):
            px = 636.0 + 7.4 * k
            d.prism([(Y(px) + y, Z(170.0) + z) for y, z in hs.rounded_rect(0.0012, 0.0036 if 0 < k < 5 else 0.0026,
                                                                         0.0011, 2)], "x", x0, x1, "Rubber")
    # The feed lips and the next three BBs, side by side (one for each barrel).
    d.box((-0.0105, Y(MAG_PX[0] + 34), Z(MAG_TOP_PY)), (0.0105, Y(MAG_PX[0] + 8), Z(MAG_TOP_PY) + 0.0030), "Rubber")
    for i in (-1, 0, 1):
        d.lathe([(-0.003, 0.0), (-0.0026, 0.0015), (-0.0015, 0.0026), (0.0, 0.003), (0.0015, 0.0026),
                 (0.0026, 0.0015), (0.003, 0.0)], "BB", 12,
                centre=(i * 0.0064, Y(MAG_PX[0] + 21), Z(MAG_TOP_PY) + 0.0036), axis="z")
    bits = hs.finish(d.build(), 0.0004, 1)
    return hs.join("Magazine", [ob, bits])


# ------------------------------------------------------------------------------------------------------ the stock

def stock() -> list:
    """The receiver extension with its lock nut, and the six-position stock on it as the photo's: a body round the
    extension with three rows of grooves along each side, a fin under its back half down to the toe with a sling
    slot, the latch lever under its front, and a ribbed butt pad."""
    out = []
    b = hs.Builder("Extension", ["Detail", "Metal"])
    b.lathe([(Y(EXT_END_PX), 0.0), (Y(EXT_END_PX), EXT_R - 0.002), (Y(EXT_END_PX - 2), EXT_R),
             (Y(NUT_PX[0] - 6), EXT_R), (Y(NUT_PX[0] - 6), 0.0)], "Detail", 24, centre=(0.0, 0.0, EXT_Z))
    # The rail under it, inside the stock: what the lowest row of slots shows.
    (top, foot), (hw_top, hw_foot) = EXT_RAIL_PY, EXT_RAIL_HW
    b.prism([(-hw_foot, Z(foot)), (hw_foot, Z(foot)), (hw_top, Z(top)), (-hw_top, Z(top))], "y", Y(EXT_END_PX),
            Y(HOLLOW_PX[0] + 4), "Detail")
    # The lock nut against the tower, notched round its back.
    y0, y1 = Y(NUT_PX[1]), Y(NUT_PX[0])
    b.lathe([(y0, 0.0), (y0, TOWER_R - 0.0026), (y0 + 0.0010, TOWER_R - 0.0012), (y1 - 0.0052, TOWER_R - 0.0012),
             (y1 - 0.0046, TOWER_R + 0.0004), (y1 - 0.0008, TOWER_R + 0.0004), (y1, TOWER_R - 0.0006), (y1, 0.0)],
            "Metal", 32, centre=(0.0, 0.0, EXT_Z))
    ob = b.build()
    cutters = []
    for i in range(6):
        c = hs.Builder("c_notch", ["Metal"])
        f = c.box((-0.0024, y0 - 0.001, EXT_Z + TOWER_R - 0.0040), (0.0024, y0 + 0.0048, EXT_Z + TOWER_R + 0.002),
                  "Metal")
        c.transform(f, hs.rot_about("y", math.radians(30 + 60 * i), (0.0, 0.0, EXT_Z)))
        cutters.append(c.build())
    hs.cut(ob, cutters)
    out.append(hs.finish(ob, 0.0004, 1))

    # The body: round over its top, flat-sided, its front sloped over the nut.
    b = hs.Builder("Stock", ["Furniture"])
    side_prism(b, [(STOCK_PX[0] + 9, STOCK_TOP_PY, 4), (STOCK_PX[1], STOCK_TOP_PY), (STOCK_PX[1], STOCK_FOOT_PY),
                   (1182, STOCK_FOOT_PY, 8), (STOCK_PX[0] + 4, 124, 6), (STOCK_PX[0], 60, 4)], 0.03, "Furniture", 4)
    ob = b.build()
    hs.cut(ob, [section_prism("c_st", section(STOCK_HW, Z(STOCK_FOOT_PY + 4), Z(STOCK_TOP_PY), 0.0030, 0.0125, 8),
                              Y(1500), Y(1100), "Furniture")], "INTERSECT")
    # The fin under its back half: its lower edge running down to the toe, a raised rim along it.
    f = hs.Builder("Fin", ["Furniture"])
    side_prism(f, [(1186, STOCK_FOOT_PY - 4), (STOCK_PX[1], STOCK_FOOT_PY - 4), (STOCK_PX[1], 306), (1454, 312, 3),
                   (1440, 252, 6), (1300, 203), (1250, 188, 6), (1196, 152, 5)], 0.0062, "Furniture", 4)
    side_prism(f, [(1250, 186), (1300, 201), (1441, 250), (1456, 310), (1447, 312), (1432, 258), (1298, 211),
                   (1246, 195)], 0.0080, "Furniture", 0)
    # The bracket the lever hangs from.
    side_prism(f, [(1196, STOCK_FOOT_PY - 2), (1262, STOCK_FOOT_PY - 2), (1262, 152), (1250, 164, 4), (1204, 164, 4)],
               0.0052, "Furniture", 3)
    weld(ob, f.build())
    cutters = [slot_cutter("c_sling", 1370, 1446, 133.5, 146.0, -0.03, 0.03)]
    c = hs.Builder("c_ext", ["Furniture"])
    c.lathe([(Y(EXT_END_PX + 3), 0.0), (Y(EXT_END_PX + 3), EXT_R + 0.0004), (Y(STOCK_PX[0] - 30), EXT_R + 0.0004),
             (Y(STOCK_PX[0] - 30), 0.0)], "Furniture", 24, centre=(0.0, 0.0, EXT_Z))
    cutters.append(c.build())
    for sx in (-1, 1):
        for py0, py1 in GROOVE_ROWS:
            for k in range(5):
                px = GROOVE_PX + GROOVE_PITCH * k
                # Square-cornered (the body's bevel softens them): rounded corners cost 400 triangles over 30 slots.
                back = Y(px + GROOVE_LEN + (GROOVE_OUT if k == 4 else 0.0))
                cutters.append(box_cutter("c_gr", (sx * (STOCK_HW - GROOVE_DEPTH), back, Z(py1)),
                                          (sx * (STOCK_HW + 0.01), Y(px), Z(py0))))
    # The hollow behind the slots, across the stock: the extension and its rail stand in it.
    x_wall = STOCK_HW - HOLLOW_WALL
    for top, foot in HOLLOW_PY:
        cutters.append(box_cutter("c_hollow", (-x_wall, Y(HOLLOW_PX[1]), Z(foot)), (x_wall, Y(HOLLOW_PX[0]), Z(top))))
    hs.cut(ob, cutters)
    out.append(hs.finish(ob, 0.0011, 1))

    # The latch lever under the body's front, its pin's knob.
    b = hs.Builder("Lever", ["Detail", "Metal"])
    side_prism(b, [(1200, 160, 4), (1212, 151, 4), (1296, 151, 6), (1368, 204, 4), (1368, 242, 3), (1361, 246, 3),
                   (1272, 200, 8), (1206, 184, 5)], 0.0072, "Detail", 4)
    b.lathe([(-0.0086, 0.0), (-0.0086, 0.0024), (-0.0078, 0.0030), (0.0078, 0.0030), (0.0086, 0.0024), (0.0086, 0.0)],
            "Metal", 14, centre=(0.0, Y(1228), Z(168)), axis="x")
    out.append(hs.finish(b.build(), 0.0010, 2))

    # The sling loop at the toe: a lug on the fin's front edge, a steel wire loop hanging through it.
    b = hs.Builder("ToeLoop", ["Furniture", "Metal"])
    side_prism(b, [(px, py, 2) for px, py in TOE_LUG], 0.0034, "Furniture", 2)
    lx, lz, hw, hh, wire = Y(TOE_LOOP[0]), Z(TOE_LOOP[1]), TOE_LOOP[2], TOE_LOOP[3], TOE_LOOP[4]
    loop = []
    for i in range(12):
        a = 2.0 * math.pi * i / 12
        # A stadium: straight sides, round ends.
        cy, cz = hw * math.cos(a), (hh - hw) * (1.0 if math.sin(a) > 0.0 else -1.0) + hw * math.sin(a)
        c = Vector((0.0, lx + cy, lz + cz))
        n2 = Vector((0.0, math.cos(a), math.sin(a)))
        loop.append([tuple(c + n2 * (wire * math.cos(2.0 * math.pi * k / 5))
                           + Vector((wire * math.sin(2.0 * math.pi * k / 5), 0.0, 0.0))) for k in range(5)])
    loop.append(loop[0])
    b.loft(loop, "Metal", cap0=False, cap1=False)
    out.append(hs.finish(b.build(), 0.0, 1))

    # The butt pad, finely ribbed across its back.
    b = hs.Builder("ButtPad", ["Rubber"])
    side_prism(b, [(STOCK_PX[1] - 2, 33), (1480, 33, 6), (PAD_PX, 46, 8), (PAD_PX - 2, 300, 6), (1478, 314, 4),
                   (1456, 314, 2), (STOCK_PX[1] - 2, 302)], PAD_HW, "Rubber", 4)
    ob = b.build()
    hs.cut(ob, [section_prism("c_pad", section(PAD_HW, Z(330), Z(30), 0.0060, 0.0125, 6), Y(1510), Y(1440),
                              "Rubber")], "INTERSECT")
    cutters = []
    for i in range(22):
        py = 52.0 + i * 11.5
        cutters.append(box_cutter("c_rib", (-0.03, Y(PAD_PX + 8), Z(py + 4.5)), (0.03, Y(PAD_PX - 3.2), Z(py))))
    hs.cut(ob, cutters)
    out.append(hs.finish(ob, 0.0007, 1))
    return out


# ------------------------------------------------------------------------------------------------------- rig

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


# The magazine's way out: straight down out of the well, a little forward (the hand's pull).
MAG_OUT = (0.012, -0.200)
# Clips: seconds, and per bone a list of (time, value) keys: degrees about x ("rx"), a (y, z) move ("yz"), a move
# along the bore ("y") or across it ("x"). Every bone is keyed in every clip. Fire is the trigger's pull, then the
# pump racked back and home by 0.88 s (ViewModelConfig.bolt_cycle_end: the game stretches the clip so that moment is
# when it can fire again, 0.59 s with the spring it comes with). The Reload keeps the AEG Rifle's timeline (the arms'
# magazine change is keyed to its shares). Selector: safe at 0, fire from half on (it has no other mode). The Inspect
# moves nothing.
CLIPS = {
    "Fire": (1.0, {
        "trigger": ("rx", [(0.0, 0.0), (0.03, -14.0), (0.07, -14.0), (0.16, 0.0)]),
        "pump": ("y", [(0.0, 0.0), (0.14, 0.0), (0.44, -PUMP_TRAVEL), (0.52, -PUMP_TRAVEL), (0.84, 0.0), (1.0, 0.0)]),
    }),
    "Reload": (1.8, {
        "magRelease": ("rx", [(0.0, 0.0), (0.05, 14.0), (0.35, 14.0), (0.40, 0.0)]),
        "magazine": ("yz", [(0.0, (0.0, 0.0)), (0.08, (0.0, 0.0)), (0.43, MAG_OUT), (0.90, MAG_OUT),
                            (0.9001, (MAG_OUT[0] * 0.53, MAG_OUT[1] * 0.53)), (1.40, (0.0, 0.0)), (1.8, (0.0, 0.0))]),
    }),
    "Selector": (0.5, {"selector": ("x", [(0.0, 0.0), (0.25, SAFETY_PUSH), (0.5, SAFETY_PUSH)])}),
    # Nothing moves as it is turned over: your left hand stays on the pump, which only a shot works.
    "Inspect": (3.0, {"pump": ("y", [(0.0, 0.0), (3.0, 0.0)])}),
}


def _interp(keys: list, t: float):
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1 + 1e-9:
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
        frames = max(2, int(round(length * FPS)))
        for f in range(frames + 1):
            t = length * f / frames
            for pb in arm.pose.bones:
                pb.rotation_mode = "QUATERNION"
                rot = Matrix.Identity(3)
                loc = Vector((0.0, 0.0, 0.0))
                if pb.name in tracks:
                    kind, keys = tracks[pb.name]
                    v = _interp(keys, t)
                    if kind == "rx":
                        rot = Matrix.Rotation(math.radians(v), 3, "X")
                    elif kind == "yz":
                        loc = Vector((0.0, v[0], v[1]))
                    elif kind == "y":
                        loc = Vector((0.0, v, 0.0))
                    elif kind == "x":
                        loc = Vector((v, 0.0, 0.0))
                pb.rotation_quaternion = rot.to_quaternion()
                pb.location = loc
                pb.scale = Vector((1.0, 1.0, 1.0))
                for path in ("rotation_quaternion", "location", "scale"):
                    pb.keyframe_insert(path, frame=t * FPS)
        ad.action = None
        track = ad.nla_tracks.new()
        track.name = clip
        track.strips.new(clip, 0, act)
    hs.rest_pose(arm)


# ------------------------------------------------------------------------------------------------------------ main

def body() -> object:
    parts = []
    parts += barrel()
    parts += receiver()
    parts += rails()
    parts += lower()
    parts += stock()
    for ob in parts:
        print("  part %-14s %6d" % (ob.name, hs.tris(ob)))
    surface.tag_named(parts, PART_SURFACES)
    return hs.join("Body", parts)


def build() -> None:
    hs.reset(FPS)
    for name, (colour, rough, metal) in MATERIALS.items():
        hs.material(name, colour, rough, metal)
    arm = armature()
    bod = body()
    bod.parent = arm
    hider = flash_hider()
    hider.parent = arm
    for ob, bone in ((trigger(), "trigger"), (selector(), "selector"), (mag_release(), "magRelease"),
                     (magazine(), "magazine"), (pump(), "pump")):
        surface.tag_named([ob], PART_SURFACES)
        hs.parent_to_bone(ob, arm, bone)
    for name, loc in EMPTIES.items():
        hs.empty(name, loc, arm)
    clips(arm)
    surface.resolve(SURFACES)
    fig = figure_copy.make(FIGURE_TRIS)
    surface.strip()
    total = 0
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            n = hs.tris(ob)
            if not ob.name.startswith("Figure"):
                total += n
            print("  %-16s %6d triangles" % (ob.name, n))
    print("  in the hands: %d triangles; figure: %d" % (total, sum(hs.tris(o) for o in [fig] + list(fig.children))))
    hs.fold_material("Rubber", "BB")  # BP6: within the 6 materials, looking the same
    if not NO_WEAR:
        # RW1: light use-wear in the hands, its own seed; the shell and the pump handled most.
        wear.apply(seed=4, heavier={"Magazine": 2.5, "Pump": 1.6})
    hs.export(OUT, True)
    print("wrote", OUT)
    build_parts()


def build_parts() -> None:
    """The parts file: the AEG Rifle's optics, laser and torch moved from its mounts onto this one's (each top-level
    part by the mount its name's prefix sits on); its silencer, barrels, grips and magazines dropped. Running it again
    changes nothing."""
    hs.reset(FPS)
    bpy.ops.import_scene.gltf(filepath=AEG_PARTS)
    for ob in list(bpy.data.objects):
        if ob.name.startswith(("barrel_", "magazine_", "grip_", "muzzle_")):
            bpy.data.objects.remove(ob, do_unlink=True)
    for ob in bpy.data.objects:
        if ob.parent is not None:
            continue
        for prefix, mount in PART_MOUNTS.items():
            if ob.name.startswith(prefix):
                ob.location += Vector(mount) - Vector(AEG_MOUNTS[prefix])
    for ob in bpy.data.objects:
        if ob.type == "MESH" and ob.parent is None:
            print("  part %-26s %6d triangles" % (ob.name, hs.tris(ob)))
    hs.export(PARTS_OUT, False)
    print("wrote", PARTS_OUT)


if __name__ == "__main__":
    build()
