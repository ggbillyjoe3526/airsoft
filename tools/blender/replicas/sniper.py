"""The Sniper Rifle's model (BL5, 2026-11-05), from the owner's sniper photo (a bolt-action spring rifle in a grey
chassis: a long plain barrel with a thread cap, an M-LOK forend with five slots a side, a black receiver with a top
rail, a short box magazine, a trigger guard with a paddle release, a vertical grip, a stock with a cheek piece and a
rubber butt pad). Generic: no maker's marks.

The side outline is traced from the owner's photo (`ref_images.zip` › replicas/sniper_rifle, "Screenshot 2026-11-04
130204", turned 0.92 degrees so its rail is level; 1.66 px per mm, which the rail's 10 mm teeth confirm) and lined up
so its grip's front at the hand's height sits where the AEG Rifle's does: the figures' rifle hold (human.json
replicaOnGrip) lands on this grip too. It keeps the replica contract (docs/CC0_ASSETS.md › Replica models): the
armature SniperRifle with the bones root, trigger, magazine, magRelease, selector (the safety), rearSight, frontSight
and bolt; the clips Fire (the shot, then the bolt lifted, drawn, pushed home and turned down: about a second, the
rifle's cycle), Reload, Inspect and Selector (no SightsFold: an optic hides the sights whole); the empties Muzzle,
BarrelEnd, FrontSight, RearSight, MagWell, OpticMount, GripMount and TorchMount; the meshes Body, Bolt, Trigger, Magazine, MagRelease, Selector,
FrontSightLeaf, RearSightLeaf, FlashHider (the thread cap, hidden by a muzzle part) and Figure (the figures'
cut-down copy); the paintable materials Body, Furniture (the chassis), Detail, Accent and Metal, plus Rubber and BB.

The photo has no iron sights; the rifle gets low flip-up sights on the rail's ends (hidden while an optic is fitted,
as it comes with the 2x Scope). The photo shows the rifle's left side; the bolt handle is on the right, for a
right-handed shooter, and the left side's pocket holds the bolt release.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/replicas/sniper.py <repo root>

It writes assets/models/replicas/sniper.glb (BL_OUT overrides) and the parts file assets/models/replicaParts/sniper.glb
(BL_PARTS_OUT): the AEG Rifle's optics, grips, torch and silencer moved onto this rifle's mounts (no barrels, no
magazines: its barrel is fixed and its magazines are its own).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import hardsurface as hs  # noqa: E402

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
OUT = os.environ.get("BL_OUT") or os.path.join(ROOT, "assets/models/replicas/sniper.glb")
AEG_PARTS = os.path.join(ROOT, "assets/models/replicaParts/aeg.glb")
PARTS_OUT = os.environ.get("BL_PARTS_OUT") or os.path.join(ROOT, "assets/models/replicaParts/sniper.glb")
ARMATURE = "SniperRifle"
FPS = 60

# ------------------------------------------------------------------------------------------------------ the photo

# The photo (turned level): px along it (muzzle at 27, butt at 1810), py down it. Blender: +Y forward, +Z up, +X right.
PX_PER_M = 1660.0
ORIGIN_PX = (1286.2, 303.6)


def Y(px: float) -> float:
    return (ORIGIN_PX[0] - px) / PX_PER_M


def Z(py: float) -> float:
    return (ORIGIN_PX[1] - py) / PX_PER_M


def P(px: float, py: float) -> tuple:
    return (Y(px), Z(py))


def pts(trace: list) -> list:
    """Photo points (px, py[, r px]) as fillet corners (y, z, r m)."""
    return [(Y(p[0]), Z(p[1]), (p[2] / PX_PER_M) if len(p) > 2 else 0.0) for p in trace]


def at(table: list, px: float) -> float:
    """A traced line (px, value) read at px, straight between its points."""
    if px <= table[0][0]:
        return table[0][1]
    for (x0, v0), (x1, v1) in zip(table, table[1:]):
        if px <= x1:
            return v0 + (v1 - v0) * (px - x0) / max(1e-9, x1 - x0)
    return table[-1][1]


# ------------------------------------------------------------------------------------------------------ measures

BORE_Z = Z(206.5)
MUZZLE_PX = 27.0
BARREL_END_PX = 40.0
# The barrel's radius along it (px, m): it tapers from the receiver to the muzzle, as the photo's.
BARREL_R = [(40.0, 0.0118), (500.0, 0.0136), (925.0, 0.0140)]
CAP_R = 0.0126
RECEIVER_PX = (918.0, 1240.0)
RECEIVER_R = 0.0150
# The rail: from the receiver's front to its back; its teeth's top on the photo's (py 164.5).
RAIL_PX = (920.0, 1237.0)
RAIL_BASE = Z(164.5) - 0.0100
RAIL_TOP = RAIL_BASE + 0.0100
# The chassis: its forend's front, the stock's back (the butt pad behind it), the barrel's channel.
NOSE_PX = 516.0
BUTT_PX = 1772.0
PAD_PX = 1810.0
CHANNEL_R = 0.0168

# The chassis's side outline: its top and bottom lines (px, py), and the line where its lower facet starts.
TOP = [(516, 220), (517, 216.5), (519, 214.5), (522, 213.2), (530, 212.6), (870, 211), (1228, 211), (1236, 218),
       (1242, 228), (1265, 229.5), (1280, 233), (1300, 241), (1320, 248), (1340, 255), (1350, 259), (1360, 267),
       (1370, 279), (1380, 288), (1390, 293), (1400, 295), (1410, 295), (1420, 293), (1430, 287), (1440, 277),
       (1446, 266), (1449, 256), (1450.5, 246), (1452, 241.5), (1455, 239.2), (1462, 238.3), (1470, 238),
       (1600, 239), (1700, 240), (1772, 241)]
BOTTOM = [(516, 262), (517, 266), (519, 269.5), (523, 272.5), (530, 274.5), (540, 275), (600, 274.5), (800, 281),
          (880, 285), (950, 288), (1000, 288.5), (1150, 286.5), (1250, 287.5), (1300, 291), (1325, 292.5),
          (1340, 318), (1462, 393), (1480, 393), (1500, 395), (1540, 399), (1580, 404), (1586, 408), (1589, 414),
          (1592, 420), (1594, 426), (1597, 432), (1600, 438.5), (1650, 444), (1700, 448), (1750, 452), (1772, 454)]
FACET = [(516, 252), (600, 254), (800, 260), (900, 265), (1000, 268), (1150, 272), (1300, 281), (1325, 284),
         (1340, 317), (1462, 392), (1470, 390), (1485, 378), (1530, 371), (1600, 375), (1700, 388), (1772, 395)]
# Its half width (m) at its sides and at its bottom, and the top edge's chamfer, along it.
HALF = [(516, 0.0240), (1240, 0.0240), (1330, 0.0180), (1345, 0.0175), (1446, 0.0175)] + \
       [(1446 + k * 4, 0.0175 + 0.0025 * (lambda t: t * t * (3 - 2 * t))(k / 11)) for k in range(1, 12)] + \
       [(1772, 0.0200)]
HALF_FOOT = [(516, 0.0165), (1240, 0.0165), (1330, 0.0175), (1480, 0.0175), (1530, 0.0135), (1772, 0.0135)]
CHAMFER = [(516, 0.0025), (1228, 0.0025), (1300, 0.0030), (1345, 0.0040), (1446, 0.0040), (1456, 0.0075),
           (1772, 0.0075)]

# The grip: its side outline (px, py), from its top inside the chassis, down its front, along its sloping foot.
GRIP = [(1312, 284), (1318, 300), (1327, 312), (1335, 318), (1340, 324), (1342, 330), (1344, 342), (1346, 360),
        (1347, 380), (1348, 396), (1350, 414), (1351, 430), (1352, 441, 4), (1358, 445.5, 4), (1383, 438.5),
        (1413, 426.5),
        (1435, 414.5), (1452, 402.5), (1466, 391), (1474, 360), (1400, 325), (1340, 290)]
GRIP_HW = 0.0175

# The forend's M-LOK slots (px centres along it, at py 232.5, 51 by 11 px) and the recessed panel round them.
SLOTS = [573.0, 637.5, 702.5, 767.5, 832.5]
SLOT_PY = 232.5
SLOT_LEN = 51.0
SLOT_H = 11.0
PANEL = [(523, 217, 2), (868, 217, 12), (868, 247.5, 12), (523, 247.5, 2)]
PANEL_DEPTH = 0.0006
UNDER_SLOTS = [575.0, 640.0]
SLOT_DEPTH = 0.0045
# The sling socket's boss at the forend's nose (centre px, radius px), as the photo's.
LUG = (522.0, 251.0, 18.0)
# The cheek piece's panel on the stock's sides (proud of them), as the photo's outline.
CHEEK = [(1453, 262.5, 0), (1699, 262.5, 2), (1699, 291, 9), (1690, 300, 4), (1479, 299, 4)]
CHEEK_PROUD = 0.0020
# The stock's screws: (px, py, head radius px, ring radius px).
# The first a hex head in a washer, the second a hex pocket with a round hole in its floor (head = the hex's corner
# radius, ring = the hole's radius, px).
SCREWS = [(1570.0, 325.0, 9.0, 15.5), (1708.0, 337.0, 9.5, 3.5)]
POCKET_DEPTH = 0.0011
INSERT_PROUD = 0.0012

# Under the chassis: the magazine, the bottom metal with the trigger guard, the release paddle, the trigger.
MAG = [(1002, 279), (1148, 279), (1148, 331.5, 2), (1010, 323.5, 4), (1002, 318, 4)]
MAG_HW = 0.0105
MAG_WINDOW = [(1046, 310.5, 7.5), (1141, 310.5, 7.5), (1141, 325.5, 7.5), (1046, 325.5, 7.5)]
PLATE = [(1146, 281), (1326, 281), (1326, 296), (1320, 305), (1146, 308)]
PLATE_HW = 0.0125
GUARD_FRONT = [(1149, 300), (1184, 300), (1184, 352), (1178, 356.5, 2), (1164, 356, 3), (1160, 348, 3), (1154, 331)]
GUARD = [(1176, 300), (1292, 300), (1290, 308, 3), (1284, 316, 4), (1283.5, 337, 10), (1270, 354, 10),
         (1245, 359.5, 6), (1196, 359.5, 4), (1176, 357, 3)]
GUARD_HOLE = [(1186, 309.5, 15), (1271, 309.5, 8), (1272.5, 336, 8), (1262, 349.5, 10), (1240, 352, 6), (1206, 352, 8),
              (1186, 342, 14)]
GUARD_HW = 0.0050
GUARD_FRONT_HW = 0.0085
PADDLE = [(1172, 352), (1188, 352), (1188, 386, 3), (1185, 390, 2), (1181, 389.5, 2), (1176, 365)]
PADDLE_HW = 0.0040
TRIGGER = [(1246, 300), (1256, 300), (1255.5, 318), (1253, 328, 6), (1250, 337, 6), (1244, 345, 4), (1237, 349, 2),
           (1235, 346, 2), (1241, 340, 6), (1246.5, 331, 6), (1247.5, 318)]
TRIGGER_HW = 0.0030

# The bolt: its shroud behind the receiver, its body (seen when it is drawn) and its handle on the right, resting in
# the chassis's pocket, turned LIFT degrees up about the bore and drawn TRAVEL back to cycle.
SHROUD = [(1239, 0.0116), (1242, 0.0118), (1262, 0.0118), (1276, 0.0113), (1286, 0.0103), (1291, 0.0087),
          (1293, 0.0060), (1293.4, 0.0)]
BOLT_R = 0.0086
BOLT_LEN = 0.080
HANDLE_ROOT = 1250.0
HANDLE_ANGLE = -40.0
HANDLE_REACH = 0.0490
KNOB_R = 0.0092
KNOB_LEN = 0.0210
POCKET = (1231.0, 1264.0, 251.0)
LIFT = -70.0
TRAVEL = 0.068

# The safety: a small lever on the tang's top, back for safe; the Selector clip turns it forward.
SAFETY = (0.0060, 1330.0, 252.0)
SAFE_LEAN = 22.0

# The flip-up sights: their clamps on the rail's ends, the sight line SIGHT_UP over the rail's teeth.
SIGHT_UP = 0.0160
SIGHT_Z = RAIL_TOP + SIGHT_UP
CLAMP_TOP = RAIL_TOP + 0.0045
FRONT_SIGHT_Y = Y(RAIL_PX[0]) - 0.0105
REAR_SIGHT_Y = Y(RAIL_PX[1]) + 0.0090

# The mounts the parts file's parts sit on: the scope on the rail (its rings on the rail, its eyepiece over the
# bolt's shroud), the grip on a short rail under the forend, the torch on a short rail on its right.
OPTIC_Y = 0.064
GRIP_RAIL_PX = (690.0, 812.0)
TORCH_RAIL_PX = (676.0, 796.0)


def catmull_rom(table: list, x0: float, x1: float, step: float) -> list:
    """`table`'s points from x0 to x1 resampled every `step` px along a Catmull-Rom curve through them (the rest
    kept), so a traced curve has no kinks between its points."""
    keep = [p for p in table if p[0] < x0 or p[0] > x1]
    inner = [p for p in table if x0 <= p[0] <= x1]
    ext = [table[table.index(inner[0]) - 1]] + inner + [table[table.index(inner[-1]) + 1]]
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        n = max(1, int((p2[0] - p1[0]) / step))
        for k in range(n):
            t = k / n
            out.append(tuple(0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t
                                    + (-a + 3 * b - 3 * c + d) * t ** 3) for a, b, c, d in zip(p0, p1, p2, p3)))
    out.append(inner[-1])
    return sorted(keep + out)


# The tang, comb and wrist curve, smooth for the first-person view (critic, BL5).
TOP = catmull_rom(TOP, 1300.0, 1446.0, 2.0)


def chassis_top(px: float) -> float:
    return Z(at(TOP, px))


def chassis_bottom(px: float) -> float:
    return Z(at(BOTTOM, px))


GRIP_MOUNT_Z = chassis_bottom(sum(GRIP_RAIL_PX) / 2) - 0.0100
TORCH_X = at(HALF, 700.0) + 0.0100
MAG_TOP = (0.0, Y(1075.0), Z(281.0))

EMPTIES = {
    "Muzzle": (0.0, Y(MUZZLE_PX), BORE_Z), "BarrelEnd": (0.0, Y(BARREL_END_PX), BORE_Z),
    "FrontSight": (0.0, FRONT_SIGHT_Y, SIGHT_Z), "RearSight": (0.0, REAR_SIGHT_Y, SIGHT_Z),
    "MagWell": MAG_TOP, "OpticMount": (0.0, OPTIC_Y, RAIL_TOP),
    "GripMount": (0.0, Y(sum(GRIP_RAIL_PX) / 2), GRIP_MOUNT_Z),
    "TorchMount": (TORCH_X, Y(sum(TORCH_RAIL_PX) / 2), Z(SLOT_PY)),
}

BONES = {
    "root": (0.0, 0.0, 0.0),
    "trigger": (0.0, Y(1254.0), Z(302.0)),
    "magazine": MAG_TOP,
    "magRelease": (0.0, Y(1177.0), Z(352.0)),
    "selector": (SAFETY[0], Y(SAFETY[1]), Z(SAFETY[2])),
    "rearSight": (0.0, REAR_SIGHT_Y, CLAMP_TOP),
    "frontSight": (0.0, FRONT_SIGHT_Y, CLAMP_TOP),
    "bolt": (0.0, Y(1240.0), BORE_Z),
}
BONE_LENGTH = 0.0170

# The AEG Rifle's mounts its parts file's parts sit on (aeg.py EMPTIES), which build_parts moves onto this rifle's.
AEG_MOUNTS = {
    "optic_": (0.0, 0.025, 0.0735), "grip_": (0.0, 0.215, 0.0216), "light_": (0.0259, 0.195, 0.04725),
    "muzzle_": (0.0, 0.339, 0.044),
}
PART_MOUNTS = {"optic_": "OpticMount", "grip_": "GripMount", "light_": "TorchMount", "muzzle_": "BarrelEnd"}

# Plain colours (the game paints the five scheme materials; these are what a viewer without it shows: the photo's
# grey chassis and black metal).
MATERIALS = {
    "Body": (0x24282f, 0.5, 0.0), "Furniture": (0x8e8f8a, 0.62, 0.0), "Detail": (0x30343b, 0.55, 0.0),
    "Accent": (0xf2f0ea, 0.5, 0.0), "Metal": (0x484d56, 0.4, 0.4), "Rubber": (0x1c1d20, 0.8, 0.0),
    "BB": (0xf4f1e8, 0.3, 0.0),
}


# ------------------------------------------------------------------------------------------------------ helpers

def side_prism(b: hs.Builder, trace: list, hw: float, mat: str, seg: int = 3, x0: float = None) -> list:
    """A side outline (photo points with corner radii) extruded across the rifle, -hw to hw (or x0 to hw)."""
    poly = [(y, z) for y, z in hs.fillet(pts(trace), seg)]
    return b.prism(poly, "x", -hw if x0 is None else x0, hw, mat)


def picatinny(b: hs.Builder, y0: float, y1: float, mat: str, place: Matrix) -> None:
    """A rail from y0 to y1 along its own +Y, its base at its z 0, built upright and moved by `place` (aeg.py's)."""
    base = [(-0.0085, -0.004), (0.0085, -0.004), (0.0085, 0.0042), (0.0106, 0.0065), (0.0106, 0.0070),
            (-0.0106, 0.0070), (-0.0106, 0.0065), (-0.0085, 0.0042)]
    faces = b.prism(base, "y", y0, y1, mat)
    tooth = [(-0.0106, 0.0069), (0.0106, 0.0069), (0.0104, 0.0074), (0.0078, 0.0100), (-0.0078, 0.0100),
             (-0.0104, 0.0074)]
    y = y0 + 0.0026
    while y + 0.0050 <= y1 - 0.0010:
        faces += b.prism(tooth, "y", y, y + 0.0050, mat)
        y += 0.0100
    b.transform(faces, place)


def slot_outline(cx: float, cy: float, length: float, height: float, seg: int = 4) -> list:
    """A slot with round ends, in (y, z), centred on photo point (cx, cy), its length and height in px."""
    r = height / 2 / PX_PER_M
    hl = length / 2 / PX_PER_M - r
    c = P(cx, cy)
    out = []
    for i in range(seg * 2 + 1):
        a = -math.pi / 2 + math.pi * i / (seg * 2)
        out.append((c[0] - hl - r * math.cos(a), c[1] + r * math.sin(a)))
    for i in range(seg * 2 + 1):
        a = math.pi / 2 + math.pi * i / (seg * 2)
        out.append((c[0] + hl - r * math.cos(a), c[1] + r * math.sin(a)))
    return out


# ------------------------------------------------------------------------------------------------------ chassis

def section(px: float) -> list:
    """The chassis's cross-section at px: flat sides, a chamfered top edge, a lower facet leaning in to its foot."""
    zt, zb = chassis_top(px), chassis_bottom(px)
    hw, hb, c = at(HALF, px), at(HALF_FOOT, px), at(CHAMFER, px)
    c = min(c, (zt - zb) * 0.3)
    zf = min(Z(at(FACET, px)), zt - c - 0.0010)
    zf = max(zf, zb + 0.0008)
    y = Y(px)
    ring = [(hb, zb), (hw, zf), (hw, zt - c), (hw - c, zt), (-hw + c, zt), (-hw, zt - c), (-hw, zf), (-hb, zb)]
    return [(x, y, z) for x, z in ring]


def stations() -> list:
    keys = {p[0] for p in TOP + BOTTOM + FACET + HALF + HALF_FOOT + CHAMFER}
    # Sparse along the straight forend and stock, close round the tang, the comb and the grip's curves.
    keys |= set(range(int(NOSE_PX), int(BUTT_PX) + 1, 12)) | set(range(1228, 1470, 4))
    return sorted(k for k in keys if NOSE_PX <= k <= BUTT_PX)


def chassis() -> object:
    b = hs.Builder("Chassis", ["Furniture", "Detail"])
    b.loft([section(px) for px in stations()], "Furniture")
    ob = b.build()
    cutters = []
    # The barrel's channel along the forend's top, open at its nose, to the receiver's front.
    c = hs.Builder("c_channel", ["Detail"])
    c.lathe([(Y(RECEIVER_PX[0]), CHANNEL_R), (Y(NOSE_PX) + 0.01, CHANNEL_R)], "Detail", 32,
            centre=(0.0, 0.0, BORE_Z))
    cutters.append(c.build())
    # The recessed panel round the slots, then the slots (dark inside), on either side.
    hw = at(HALF, 700.0)
    for x0, x1 in ((hw - PANEL_DEPTH, hw + 0.01), (-hw - 0.01, -hw + PANEL_DEPTH)):
        c = hs.Builder("c_panel", ["Furniture"])
        c.prism([(y, z) for y, z in hs.fillet(pts(PANEL), 3)], "x", x0, x1, "Furniture")
        cutters.append(c.build())
    for x0, x1 in ((hw - PANEL_DEPTH - SLOT_DEPTH, hw + 0.01), (-hw - 0.01, -hw + PANEL_DEPTH + SLOT_DEPTH)):
        c = hs.Builder("c_slots", ["Detail"])
        for cx in SLOTS:
            c.prism(slot_outline(cx, SLOT_PY, SLOT_LEN, SLOT_H), "x", x0, x1, "Detail")
        cutters.append(c.build())
    # Two slots under the forend, ahead of the grip rail.
    c = hs.Builder("c_under", ["Detail"])
    for cx in UNDER_SLOTS:
        z0 = chassis_bottom(cx)
        ring = slot_outline(cx, SLOT_PY, SLOT_LEN, SLOT_H)
        # The slot's outline laid flat (across the rifle instead of up it), cut up into the forend's foot.
        flat = [(z - Z(SLOT_PY), y) for y, z in ring]
        c.prism(flat, "z", z0 - 0.01, z0 + SLOT_DEPTH, "Detail")
    cutters.append(c.build())
    # The scallop on the receiver's left (the photo's flat) runs down into the chassis's top edge.
    # The chassis's notch reaches 0.8 mm past the receiver's flat, so the flat fills it (no shared plane).
    cutters.append(scallop_cutter("Furniture", RECEIVER_R - 0.0033))
    # The bolt handle's pocket on the right, and the bolt release's on the left.
    c = hs.Builder("c_pocket", ["Furniture"])
    for x0, x1 in ((0.0100, 0.0400), (-0.0400, -0.0100)):
        poly = [(y, z) for y, z in hs.fillet(pts([(POCKET[0], 200, 0), (POCKET[1], 200, 0), (POCKET[1], POCKET[2], 5),
                                                  (POCKET[0], POCKET[2], 5)]), 3)]
        c.prism(poly, "x", x0, x1, "Furniture")
    cutters.append(c.build())
    hs.cut(ob, cutters)
    dark_slots(ob)
    return ob


def dark_slots(ob: object) -> None:
    """The slots' walls and floors in the dark material (the boolean leaves them the chassis's), so they read as holes
    through the forend."""
    hw = at(HALF, 700.0)
    inner = hw - PANEL_DEPTH - 0.0002
    r = SLOT_H / 2 / PX_PER_M + 0.0002
    hl = SLOT_LEN / 2 / PX_PER_M + 0.0002
    floor = hw - PANEL_DEPTH - SLOT_DEPTH - 0.0002
    dark = ob.data.materials.find("Detail")
    for p in ob.data.polygons:
        c = p.center
        for cx in SLOTS:
            if floor < abs(c.x) < inner and abs(c.y - Y(cx)) < hl and abs(c.z - Z(SLOT_PY)) < r:
                p.material_index = dark
        # Underneath: only faces inside the cut, above the foot where the face itself is.
        zb = chassis_bottom(ORIGIN_PX[0] - c.y * PX_PER_M)
        for cx in UNDER_SLOTS:
            if zb + 0.0002 < c.z < zb + SLOT_DEPTH + 0.0003 and abs(c.y - Y(cx)) < hl and abs(c.x) < r:
                p.material_index = dark



def scallop_cutter(mat: str, inner: float = RECEIVER_R - 0.0025) -> object:
    """The flat on the receiver's left (the photo's dark scallop), cut in `mat` in to `inner` from the bore."""
    c = hs.Builder("c_scallop", [mat])
    poly = [(y, z) for y, z in hs.fillet(pts([(1033, 187, 14), (1230, 187, 14), (1230, 218, 14), (1033, 218, 14)]),
                                         4)]
    c.prism(poly, "x", -0.040, -inner, mat)
    return c.build()


def nose_lug() -> object:
    """The sling socket's boss across the forend's nose, a hex socket in either end."""
    b = hs.Builder("Lug", ["Furniture", "Detail"])
    cy, cz, r = Y(LUG[0]), Z(LUG[1]), LUG[2] / PX_PER_M
    hw = at(HALF, NOSE_PX) + 0.0010
    b.lathe([(-hw, 0.0), (-hw, r), (hw, r), (hw, 0.0)], "Furniture", 24, centre=(0.0, cy, cz), axis="x")
    # The socket's raised hex ring either side (18 mm across its corners).
    for sx in (1.0, -1.0):
        b.lathe([(sx * (hw - 0.0005), 0.0), (sx * (hw - 0.0005), 0.0090), (sx * (hw + 0.0008), 0.0090),
                 (sx * (hw + 0.0010), 0.0084), (sx * (hw + 0.0010), 0.0)], "Furniture", 6, centre=(0.0, cy, cz),
                axis="x", start=math.pi / 6)
    ob = b.build()
    c = hs.Builder("c_socket", ["Detail"])
    for sx in (1.0, -1.0):
        c.lathe([(sx * (hw - 0.0070), 0.0), (sx * (hw - 0.0070), 0.0030), (sx * (hw + 0.01), 0.0030),
                 (sx * (hw + 0.01), 0.0)], "Detail", 16, centre=(0.0, cy, cz), axis="x")
    hs.cut(ob, [c.build()])
    dark = ob.data.materials.find("Detail")
    for p in ob.data.polygons:
        if math.hypot(p.center.y - cy, p.center.z - cz) < 0.00305 and abs(p.center.x) < hw + 0.0009:
            p.material_index = dark
    hs.finish(ob, 0.0004, 2)
    return ob


def grip() -> object:
    b = hs.Builder("Grip", ["Furniture"])
    side_prism(b, GRIP, GRIP_HW, "Furniture", 4)
    ob = b.build()
    # Rounded by a bevel only: no custom normals, as it is joined to the chassis by a boolean (they would carry over).
    mod = ob.modifiers.new("bevel", "BEVEL")
    mod.width = 0.0050
    mod.segments = 3
    mod.limit_method = "ANGLE"
    mod.use_clamp_overlap = True
    hs.apply_modifiers(ob)
    return ob


def cheek_panels() -> object:
    b = hs.Builder("Cheek", ["Furniture"])
    hw = at(HALF, 1600.0)
    poly = [(y, z) for y, z in hs.fillet(pts(CHEEK), 4)]
    b.prism(poly, "x", hw - 0.002, hw + CHEEK_PROUD, "Furniture")
    b.prism(poly, "x", -hw - CHEEK_PROUD, -hw + 0.002, "Furniture")
    # Its front follows the stock's widening behind the grip, so it stands as proud there as along the stock.
    for v in b.bm.verts:
        px = ORIGIN_PX[0] - v.co.y * PX_PER_M
        v.co.x += math.copysign(at(HALF, px) - hw, v.co.x)
    bmesh.ops.triangulate(b.bm, faces=[f for f in b.bm.faces if len(f.verts) > 4], quad_method="BEAUTY",
                          ngon_method="BEAUTY")
    return hs.finish(b.build(), 0.0003, 1)


def screws() -> object:
    b = hs.Builder("Screws", ["Metal", "Detail"])
    # The rear one's pocket (cut in its insert) has a dark round hole in its floor.
    px, py, _head, hole = SCREWS[1]
    hw = at(HALF, px) + INSERT_PROUD - POCKET_DEPTH
    for sx in (1.0, -1.0):
        r = hole / PX_PER_M
        x0, x1 = sx * (hw - 0.0004), sx * (hw + 0.0001)
        b.lathe([(x0, 0.0), (x0, r), (x1, r), (x1, 0.0)], "Detail", 14, centre=(0.0, Y(px), Z(py)), axis="x")
    for px, py, head, ring in SCREWS[:1]:
        hw = at(HALF, px)
        for sx in (1.0, -1.0):
            centre = (0.0, Y(px), Z(py))
            rr, rh = ring / PX_PER_M, head / PX_PER_M
            b.lathe([(sx * (hw - 0.001), 0.0), (sx * (hw - 0.001), rr), (sx * (hw + 0.0005), rr),
                     (sx * (hw + 0.0008), rr - 0.0006), (sx * (hw + 0.0008), 0.0)], "Detail", 20, centre=centre,
                    axis="x")
            b.lathe([(sx * hw, 0.0), (sx * hw, rh), (sx * (hw + 0.0020), rh), (sx * (hw + 0.0020), 0.0)], "Metal", 6,
                    centre=centre, axis="x", start=math.pi / 6)
            # The head's hex socket, as a dark disc just proud of it.
            b.lathe([(sx * (hw + 0.0020), 0.0), (sx * (hw + 0.0020), rh * 0.45), (sx * (hw + 0.0021), rh * 0.45),
                     (sx * (hw + 0.0021), 0.0)], "Detail", 6, centre=centre, axis="x", start=0.0)
    return hs.finish(b.build(), 0.0002, 1)


def pocket_inserts() -> object:
    """The rear screw's hex pocket in a low round boss on the stock's side, built as rings (a boolean cut in the stock
    itself left long thin triangles that streaked the flat side's shading)."""
    px, py, head, _hole = SCREWS[1]
    hw = at(HALF, px)
    cy, cz = Y(px), Z(py)
    corner = head / PX_PER_M
    count = 24

    def hex_r(a: float) -> float:
        return corner * math.cos(math.pi / 6) / math.cos((a % (math.pi / 3)) - math.pi / 6)

    b = hs.Builder("Inserts", ["Furniture"])
    for sx in (1.0, -1.0):
        rings = []
        angles = [2 * math.pi * i / count for i in range(count)]
        for x, rad in ((hw - 0.0030, None), (hw + INSERT_PROUD, None), (hw + INSERT_PROUD, "hex"),
                       (hw + INSERT_PROUD - POCKET_DEPTH, "hex")):
            rings.append([(sx * x, cy + (hex_r(a) if rad else 0.0080) * math.cos(a),
                           cz + (hex_r(a) if rad else 0.0080) * math.sin(a)) for a in angles])
        b.loft(rings, "Furniture")
    return hs.finish(b.build(), 0.0002, 1)


def rails() -> object:
    """The top rail on the receiver, a short rail under the forend (the grip's) and one on its right (the torch's)."""
    b = hs.Builder("Rails", ["Body"])
    picatinny(b, Y(RAIL_PX[1]), Y(RAIL_PX[0]), "Body", Matrix.Translation((0.0, 0.0, RAIL_BASE)))
    zb = chassis_bottom(sum(GRIP_RAIL_PX) / 2)
    picatinny(b, Y(GRIP_RAIL_PX[1]), Y(GRIP_RAIL_PX[0]), "Body",
              Matrix.Translation((0.0, 0.0, zb)) @ Matrix.Rotation(math.pi, 4, "Y"))
    picatinny(b, Y(TORCH_RAIL_PX[1]), Y(TORCH_RAIL_PX[0]), "Body",
              Matrix.Translation((TORCH_X - 0.0100, 0.0, Z(SLOT_PY))) @ Matrix.Rotation(math.pi * 0.5, 4, "Y"))
    return hs.finish(b.build(), 0.0003, 1)


def receiver() -> object:
    """The receiver (a round action) with the barrel's nut at its front, the scallop on its left, a port on its
    right; the barrel tapering to the thread cap."""
    b = hs.Builder("Receiver", ["Body", "Metal", "Detail"])
    y0, y1 = Y(RECEIVER_PX[1]), Y(RECEIVER_PX[0])
    b.lathe([(y0, 0.0), (y0, RECEIVER_R - 0.0012), (y0 + 0.0012, RECEIVER_R), (y1 - 0.0015, RECEIVER_R),
             (y1, RECEIVER_R - 0.0015), (y1, 0.0)], "Body", 32, centre=(0.0, 0.0, BORE_Z))
    b.lathe([(y1 - 0.002, 0.0), (y1 - 0.002, 0.0157), (y1 + 0.0055, 0.0157), (y1 + 0.0065, 0.0150),
             (y1 + 0.0065, 0.0)], "Body", 32, centre=(0.0, 0.0, BORE_Z))
    prof = [(Y(925.0), 0.0)]
    for px in (925.0, 800.0, 650.0, 500.0, 350.0, 200.0, 40.0):
        prof.append((Y(px), at(BARREL_R, px)))
    prof.append((Y(40.0), 0.0))
    b.lathe(prof, "Body", 32, centre=(0.0, 0.0, BORE_Z))
    ob = b.build()
    cutters = [scallop_cutter("Body")]
    c = hs.Builder("c_port", ["Detail"])
    poly = [(y, z) for y, z in hs.fillet(pts([(1112, 190, 6), (1212, 190, 6), (1212, 207, 6), (1112, 207, 6)]), 3)]
    c.prism(poly, "x", RECEIVER_R - 0.0035, 0.04, "Detail")
    cutters.append(c.build())
    hs.cut(ob, cutters)
    return hs.finish(ob, 0.0004, 2)


def flash_hider() -> object:
    """The thread cap on the barrel's end: rounded at its face, a bore through it."""
    b = hs.Builder("FlashHider", ["Body", "Detail"])
    y0, y1 = Y(BARREL_END_PX) - 0.0015, Y(MUZZLE_PX)
    # Its grip: fine grooves round it between the barrel and the rounded face.
    grooves = []
    y = y0 + 0.0016
    while y + 0.0010 < y1 - 0.0034:
        grooves += [(y, CAP_R), (y + 0.0003, CAP_R - 0.0004), (y + 0.0006, CAP_R - 0.0004), (y + 0.0009, CAP_R)]
        y += 0.0013
    b.lathe([(y0, 0.0), (y0, CAP_R - 0.0004), (y0 + 0.0006, CAP_R)] + grooves + [(y1 - 0.0030, CAP_R),
             (y1 - 0.0012, CAP_R - 0.0008),
             (y1 - 0.0002, CAP_R - 0.0026), (y1, CAP_R - 0.0042), (y1, 0.0048), (y1 - 0.0006, 0.0045)], "Body", 32,
            centre=(0.0, 0.0, BORE_Z), cap=False)
    b.lathe([(y1 - 0.0006, 0.0045), (y1 - 0.0080, 0.0045), (y1 - 0.0080, 0.0)], "Detail", 32,
            centre=(0.0, 0.0, BORE_Z), cap=False)
    ob = b.build()
    return hs.finish(ob, 0.0, 1)


def bottom_metal() -> object:
    b = hs.Builder("BottomMetal", ["Detail"])
    side_prism(b, PLATE, PLATE_HW, "Detail")
    side_prism(b, GUARD_FRONT, GUARD_FRONT_HW, "Detail")
    g = hs.Builder("Guard", ["Detail"])
    side_prism(g, GUARD, GUARD_HW, "Detail")
    guard = g.build()
    c = hs.Builder("c_hole", ["Detail"])
    side_prism(c, GUARD_HOLE, 0.02, "Detail")
    hs.cut(guard, [c.build()])
    ob = hs.join("BottomMetal", [b.build(), guard])
    return hs.finish(ob, 0.0010, 2)


def bolt_release() -> object:
    b = hs.Builder("BoltRelease", ["Detail"])
    side_prism(b, [(1237, 213, 2), (1259, 213, 2), (1259, 243, 3), (1237, 243, 3)], -0.0125, "Detail", 2,
               x0=-0.0195)
    # Its four grip ribs across its face, as the photo's.
    for py in (219.0, 226.0, 233.0, 240.0):
        side_prism(b, [(1239, py - 1.4, 1), (1257, py - 1.4, 1), (1257, py + 1.4, 1), (1239, py + 1.4, 1)], -0.0190,
                   "Detail", 1, x0=-0.0203)
    return hs.finish(b.build(), 0.0006, 1)


def body() -> object:
    # The grip is one piece with the chassis (its sides flush with the wrist's), as the photo's.
    ch = chassis()
    hs.cut(ch, [grip()], "UNION")
    parts = [hs.finish(ch, 0.0012, 2), nose_lug(), cheek_panels(), pocket_inserts(), screws(), rails(), receiver(),
             bottom_metal(), bolt_release()]
    for ob in parts:
        print("  part %-12s %6d" % (ob.name, hs.tris(ob)))
    return hs.join("Body", parts)


# ----------------------------------------------------------------------------------------------------- moving parts

def bolt() -> object:
    """The bolt: its shroud, its body (inside the receiver until it is drawn), the handle's collar, stem and knob."""
    b = hs.Builder("Bolt", ["Detail", "Metal"])
    b.lathe([(Y(px), r) for px, r in SHROUD], "Detail", 32, centre=(0.0, 0.0, BORE_Z))
    # The bright ring at the shroud's front, as the photo's.
    b.lathe([(Y(1244.0), 0.0), (Y(1244.0), 0.0119), (Y(1240.5), 0.0119), (Y(1240.0), 0.0114), (Y(1240.0), 0.0)],
            "Metal", 32, centre=(0.0, 0.0, BORE_Z))
    yb = Y(1240.0)
    b.lathe([(yb + 0.0005, 0.0), (yb + 0.0005, BOLT_R), (yb + BOLT_LEN, BOLT_R), (yb + BOLT_LEN, 0.0)], "Metal", 24,
            centre=(0.0, 0.0, BORE_Z))
    # The handle's collar round the bolt, just ahead of the shroud.
    ry = Y(HANDLE_ROOT)
    b.lathe([(ry - 0.0060, 0.0), (ry - 0.0060, 0.0105), (ry + 0.0060, 0.0105), (ry + 0.0060, 0.0)], "Metal", 24,
            centre=(0.0, 0.0, BORE_Z))
    # The stem: out to the right and down at HANDLE_ANGLE, swept back a little, tapering; then the knob.
    a = math.radians(HANDLE_ANGLE)
    out = Vector((math.cos(a), 0.0, math.sin(a)))
    sweep = Vector((0.0, -0.18, 0.0))
    axis = (out + sweep).normalized()
    root = Vector((0.0, ry, BORE_Z))
    tip = root + axis * HANDLE_REACH
    b.loft([[tuple(root + axis * t + u * r) for u, r in _ring(axis, 0.0042 - 0.0012 * t / HANDLE_REACH)]
            for t in (0.006, HANDLE_REACH * 0.5, HANDLE_REACH)], "Metal")
    knob = []
    for along, r in [(-0.0002, 0.0), (0.0, KNOB_R * 0.55), (0.0015, KNOB_R * 0.85), (0.0040, KNOB_R),
                     (KNOB_LEN - 0.0040, KNOB_R), (KNOB_LEN - 0.0012, KNOB_R * 0.88), (KNOB_LEN, KNOB_R * 0.55),
                     (KNOB_LEN + 0.0002, 0.0)]:
        knob.append([tuple(tip + axis * (along - 0.004) + u * r) for u, r in _ring(axis, r, 20)])
    b.loft(knob, "Detail", cap0=False, cap1=False)
    return hs.finish(b.build(), 0.0003, 1)


def _ring(axis: Vector, r: float, count: int = 12) -> list:
    """`count` points round `axis` at radius r, as (unit offset, r) pairs."""
    side = axis.cross(Vector((0.0, 1.0, 0.0)))
    if side.length < 1e-6:
        side = Vector((1.0, 0.0, 0.0))
    side.normalize()
    up = axis.cross(side).normalized()
    return [((side * math.cos(2 * math.pi * i / count) + up * math.sin(2 * math.pi * i / count)), r)
            for i in range(count)]


def magazine() -> object:
    b = hs.Builder("Magazine", ["Detail", "Metal", "BB"])
    side_prism(b, MAG, MAG_HW, "Detail")
    # The floor plate's lip, a little wider than the body.
    side_prism(b, [(1006, 318.5), (1146, 326), (1146, 331.5, 2), (1010, 323.5, 4), (1004, 319)], MAG_HW + 0.0006,
               "Detail")
    # A BB at the feed lip, for when it is out.
    b.lathe([(-0.003 * math.cos(math.pi * i / 6), 0.003 * math.sin(math.pi * i / 6)) for i in range(7)], "BB", 10,
            centre=(0.0, Y(1015.0), Z(279.0) + 0.0012))
    ob = b.build()
    c = hs.Builder("c_window", ["Metal"])
    poly = [(y, z) for y, z in hs.fillet(pts(MAG_WINDOW), 3)]
    c.prism(poly, "x", MAG_HW - 0.0012, MAG_HW + 0.01, "Metal")
    c.prism(poly, "x", -MAG_HW - 0.01, -MAG_HW + 0.0012, "Metal")
    hs.cut(ob, [c.build()])
    # The follower's spine seen through the window.
    s = hs.Builder("Spine", ["Metal"])
    s.prism([(y, z) for y, z in hs.fillet(pts([(1052, 316.5, 3), (1135, 316.5, 3), (1135, 319.5, 1.5),
                                               (1052, 319.5, 1.5)]), 2)], "x", -MAG_HW + 0.0009, MAG_HW - 0.0009,
            "Metal")
    ob = hs.join("Magazine", [ob, s.build()])
    return hs.finish(ob, 0.0006, 2)


def mag_release() -> object:
    b = hs.Builder("MagRelease", ["Detail"])
    side_prism(b, PADDLE, PADDLE_HW, "Detail", 3)
    return hs.finish(b.build(), 0.0008, 2)


def trigger() -> object:
    b = hs.Builder("Trigger", ["Metal"])
    side_prism(b, TRIGGER, TRIGGER_HW, "Metal", 3)
    return hs.finish(b.build(), 0.0006, 2)


def safety() -> object:
    """The safety's lever on the tang's top right, leaning back (safe)."""
    b = hs.Builder("Selector", ["Detail"])
    x, py0 = SAFETY[0], SAFETY[2]
    lever = [(-0.0022, -0.0030), (0.0022, -0.0030), (0.0018, 0.0062), (0.0006, 0.0072), (-0.0016, 0.0066),
             (-0.0020, 0.0054)]
    faces = b.prism(lever, "x", x - 0.0014, x + 0.0014, "Detail")
    pivot = Vector((x, Y(SAFETY[1]), Z(py0)))
    b.transform(faces, Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(SAFE_LEAN), 4, "X"))
    return hs.finish(b.build(), 0.0004, 1)


def sight(front: bool) -> object:
    """A low flip-up sight on the rail's end: its clamp, its hinge and its leaf (the front's post between two ears,
    the rear's aperture)."""
    name = "FrontSightLeaf" if front else "RearSightLeaf"
    y = FRONT_SIGHT_Y if front else REAR_SIGHT_Y
    b = hs.Builder(name, ["Detail", "Metal", "Accent"])
    clamp = [(-0.0124, RAIL_BASE + 0.0045), (-0.0112, RAIL_BASE + 0.0045), (-0.0112, RAIL_TOP + 0.0002),
             (0.0112, RAIL_TOP + 0.0002), (0.0112, RAIL_BASE + 0.0045), (0.0124, RAIL_BASE + 0.0045),
             (0.0124, CLAMP_TOP - 0.0010), (0.0114, CLAMP_TOP), (-0.0114, CLAMP_TOP), (-0.0124, CLAMP_TOP - 0.0010)]
    b.prism(clamp, "y", y - 0.0090, y + 0.0090, "Detail")
    # The clamp's screw on the left.
    b.lathe([(-0.0124, 0.0), (-0.0124, 0.0032), (-0.0140, 0.0032), (-0.0144, 0.0024), (-0.0144, 0.0)], "Metal", 12,
            centre=(0.0, y, RAIL_BASE + 0.0068), axis="x")
    b.lathe([(-0.0088, 0.0), (-0.0088, 0.0018), (0.0088, 0.0018), (0.0088, 0.0)], "Metal", 12,
            centre=(0.0, y, CLAMP_TOP + 0.0010), axis="x")
    top = SIGHT_Z
    if front:
        for x0, x1 in ((-0.0095, -0.0070), (0.0070, 0.0095)):
            b.prism(hs.fillet([(y - 0.0030, CLAMP_TOP, 0.0), (y + 0.0030, CLAMP_TOP, 0.0),
                               (y + 0.0020, top + 0.0022, 0.0012), (y - 0.0020, top + 0.0022, 0.0012)], 2), "x",
                    x0, x1, "Detail")
        b.prism([(-0.0011, CLAMP_TOP), (0.0011, CLAMP_TOP), (0.0009, top - 0.0012), (-0.0009, top - 0.0012)], "y",
                y - 0.0011, y + 0.0011, "Detail")
        b.prism([(-0.0009, top - 0.0012), (0.0009, top - 0.0012), (0.0008, top), (-0.0008, top)], "y",
                y - 0.0009, y + 0.0009, "Accent")
        return hs.finish(b.build(), 0.0003, 1)
    leaf = hs.fillet([(-0.0085, CLAMP_TOP, 0.0), (0.0085, CLAMP_TOP, 0.0), (0.0085, top + 0.0030, 0.0030),
                      (-0.0085, top + 0.0030, 0.0030)], 3)
    b.prism(leaf, "y", y - 0.0015, y + 0.0015, "Detail")
    ob = b.build()
    c = hs.Builder("c_aperture", ["Detail"])
    c.lathe([(y - 0.01, 0.0), (y - 0.01, 0.0016), (y + 0.01, 0.0016), (y + 0.01, 0.0)], "Detail", 16,
            centre=(0.0, 0.0, top))
    hs.cut(ob, [c.build()])
    return hs.finish(ob, 0.0003, 1)


def figure() -> object:
    """The figures' cut-down copy: the silhouette in a few hundred faces."""
    b = hs.Builder("Figure", ["Furniture", "Body", "Detail"])
    outline = [(516, 214), (1236, 212), (1265, 229), (1340, 255), (1400, 295), (1440, 277), (1452, 239),
               (1772, 241), (1772, 454), (1600, 439), (1580, 404), (1466, 392), (1352, 445), (1344, 330),
               (1325, 292), (1000, 289), (540, 276), (516, 262)]
    b.prism([P(*p) for p in outline], "x", -0.019, 0.019, "Furniture")
    b.prism([P(*p) for p in [(1772, 241), (1808, 242), (1810, 450), (1800, 455), (1772, 454)]], "x", -0.020, 0.020,
            "Detail")
    b.lathe([(Y(925), 0.0137), (Y(30), 0.0127)], "Body", 6, centre=(0.0, 0.0, BORE_Z))
    b.box((-0.011, Y(RAIL_PX[1]), BORE_Z - 0.010), (0.011, Y(RAIL_PX[0]), RAIL_TOP), "Body")
    b.lathe([(Y(1292), 0.0118), (Y(1240), 0.0118)], "Detail", 6, centre=(0.0, 0.0, BORE_Z))
    b.prism([P(*p) for p in [(1002, 285), (1300, 285), (1290, 358), (1180, 358), (1148, 331), (1002, 322)]], "x",
            -0.0105, 0.0105, "Detail")
    ob = b.build()
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


# ------------------------------------------------------------------------------------------------------------ rig

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


# Clips: seconds, and per bone a list of (time, value) keys: degrees about x ("rx"), a (y, z) move in metres ("yz"),
# or the bolt's (degrees about the bore, metres along it) ("bolt"). Between keys the value eases. Every bone is keyed
# in every clip (SelectorPose). The Fire clip is the rifle's cycle (stats.md fire rate 0.8 a second): the trigger
# pulled, then the bolt turned up, drawn back, pushed home and turned down; the Reload's phases are the AEG Rifle's.
CLIPS = {
    "Fire": (1.0, {
        "trigger": ("rx", [(0.0, 0.0), (0.033, -15.0), (0.06, -15.0), (0.13, 0.0)]),
        "bolt": ("bolt", [(0.0, (0.0, 0.0)), (0.15, (0.0, 0.0)), (0.29, (LIFT, 0.0)), (0.31, (LIFT, 0.0)),
                          (0.48, (LIFT, -TRAVEL)), (0.55, (LIFT, -TRAVEL)), (0.72, (LIFT, 0.0)),
                          (0.75, (LIFT, 0.0)), (0.88, (0.0, 0.0)), (1.0, (0.0, 0.0))]),
    }),
    "Reload": (1.8, {
        "magRelease": ("rx", [(0.0, 0.0), (0.05, 16.0), (0.35, 16.0), (0.40, 0.0)]),
        "magazine": ("yz", [(0.0, (0.0, 0.0)), (0.08, (0.0, 0.0)), (0.43, (0.02, -0.26)), (0.90, (0.02, -0.26)),
                            (0.9001, (0.012, -0.14)), (1.40, (0.0, 0.0)), (1.8, (0.0, 0.0))]),
    }),
    "Inspect": (3.0, {
        "bolt": ("bolt", [(0.0, (0.0, 0.0)), (0.30, (0.0, 0.0)), (0.50, (LIFT, 0.0)), (0.85, (LIFT, -0.045)),
                          (2.00, (LIFT, -0.045)), (2.30, (LIFT, 0.0)), (2.50, (0.0, 0.0)), (3.0, (0.0, 0.0))]),
    }),
    "Selector": (0.5, {"selector": ("rx", [(0.0, 0.0), (0.25, -2.0 * SAFE_LEAN), (0.5, -2.0 * SAFE_LEAN)])}),
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
        frames = int(round(length * FPS))
        for f in range(frames + 1):
            t = f / FPS
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
                    elif kind == "bolt":
                        rot = Matrix.Rotation(math.radians(v[0]), 3, "Y")
                        loc = Vector((0.0, v[1], 0.0))
                pb.rotation_quaternion = rot.to_quaternion()
                pb.location = loc
                pb.scale = Vector((1.0, 1.0, 1.0))
                for path in ("rotation_quaternion", "location", "scale"):
                    pb.keyframe_insert(path, frame=f)
        ad.action = None
        track = ad.nla_tracks.new()
        track.name = clip
        track.strips.new(clip, 0, act)
    # At rest from here on (renders, the figure copy), the tracks muted; every one is still exported.
    hs.rest_pose(arm)


# ------------------------------------------------------------------------------------------------------------ main

def build() -> None:
    hs.reset(FPS)
    for name, (colour, rough, metal) in MATERIALS.items():
        hs.material(name, colour, rough, metal)
    arm = armature()
    bod = body()
    bod.parent = arm
    hider = flash_hider()
    hider.parent = arm
    for ob, bone in ((bolt(), "bolt"), (trigger(), "trigger"), (magazine(), "magazine"),
                     (mag_release(), "magRelease"), (safety(), "selector"), (sight(True), "frontSight"),
                     (sight(False), "rearSight")):
        hs.parent_to_bone(ob, arm, bone)
    fig = figure()
    fig.parent = arm
    pad = butt_pad()
    hs.join("Body", [bod, pad])
    for name, loc in EMPTIES.items():
        hs.empty(name, loc, arm)
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
    build_parts()


def butt_pad() -> object:
    b = hs.Builder("ButtPad", ["Rubber", "Furniture"])
    hw = at(HALF, BUTT_PX) + 0.0007
    side_prism(b, [(BUTT_PX - 0.5, 241, 0), (1802.5, 242, 6), (1800.5, 300, 0), (1800, 350, 0), (1802.5, 400, 0),
                   (1810, 438, 6), (1809, 452, 4), (1800, 455.5, 4), (BUTT_PX - 0.5, 454.5, 0)], hw, "Rubber", 3)
    # A spacer between the stock and the pad.
    side_prism(b, [(BUTT_PX - 1.0, 241.5), (BUTT_PX + 5.0, 241.5), (BUTT_PX + 5.0, 454.5), (BUTT_PX - 1.0, 454.5)],
               hw + 0.0003, "Furniture", 1)
    return hs.finish(b.build(), 0.0025, 3)


def build_parts() -> None:
    """The parts file: the AEG Rifle's optics, grips, torch and silencer moved from its mounts onto this rifle's
    (each top-level part by the mount its name's prefix sits on); its barrels and magazines dropped. Running it again
    changes nothing."""
    hs.reset(FPS)
    bpy.ops.import_scene.gltf(filepath=AEG_PARTS)
    for ob in list(bpy.data.objects):
        if ob.name.startswith(("barrel_", "magazine_")):
            bpy.data.objects.remove(ob, do_unlink=True)
    for ob in bpy.data.objects:
        if ob.parent is not None:
            continue
        for prefix, mount in PART_MOUNTS.items():
            if ob.name.startswith(prefix):
                ob.location += Vector(EMPTIES[mount]) - Vector(AEG_MOUNTS[prefix])
    for ob in bpy.data.objects:
        if ob.type == "MESH" and ob.parent is None:
            print("  part %-26s %6d triangles" % (ob.name, hs.tris(ob)))
    hs.export(PARTS_OUT, False)
    print("wrote", PARTS_OUT)


if __name__ == "__main__":
    build()
