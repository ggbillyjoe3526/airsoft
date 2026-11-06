"""The GBB Pistol's model (BL2, 2026-11-04), from the owner's reference photos (a polymer-framed striker pistol: a
square slide with rear serrations, an accessory rail, a squared trigger guard, a raked grip with finger grooves,
stippled panels and a grooved back strap). Generic: no maker's marks.

The side outline is traced from the owner's main photo (a plain side view, 2.95 px per mm) and lined up on the old
model's grip (the best overlap of the grips), so the figures' hold stays where it was. It keeps the old model's
contract (docs/CC0_ASSETS.md › Replica models): the armature GBBPistol with the bones root, slide, trigger, magazine
and magRelease, the four clips (Fire, Reload, Inspect, SlideLock) of the same lengths and timings, the empties
(Muzzle, ThreadEnd, FrontSight, RearSight, MagWell, RailMount, TorchMount) and the meshes Body (the frame), Slide,
Trigger, Magazine, MagRelease and Figure (the figures' cut-down copy); the paintable materials Body, Furniture,
Detail, Accent and Metal (plus Stipple and BB, kept as drawn).

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/replicas/gbb.py <repo root>

It writes assets/models/replicas/pistol.glb (BL_OUT overrides) and the parts file
assets/models/replicaParts/pistol.glb (BL_PARTS_OUT): the silencer moved onto ThreadEnd, the laser and torch onto
RailMount. Then run tools/blender/parts/magazines.py, which builds the Extended Magazine from this magazine.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import figure_copy  # noqa: E402
import hardsurface as hs  # noqa: E402

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
OUT = os.environ.get("BL_OUT") or os.path.join(ROOT, "assets/models/replicas/pistol.glb")
PARTS = os.path.join(ROOT, "assets/models/replicaParts/pistol.glb")
PARTS_OUT = os.environ.get("BL_PARTS_OUT") or PARTS
ARMATURE = "GBBPistol"
FPS = 60
# The figures' copy (figure_copy.py): triangles per piece, 3,000 in all, the replica budget on a figure
# (docs/CC0_ASSETS.md › Size limits), used in full (TP1, 2026-11-05).
FIGURE_TRIS = {"Figure": 2760, "Magazine": 240}

# The owner's main photo (a side view, muzzle left) to model space: PX_PER_M pixels a metre, the photo's (ORIGIN_PX)
# pixel at the model's origin (the old model's grip on the photo's, best overlap).
PX_PER_M = 2951.6
ORIGIN_PX = (314.0, 112.0)


def P(px: float, py: float) -> tuple:
    """A point traced on the photo, as (y, z) in model space."""
    return ((ORIGIN_PX[0] - px) / PX_PER_M, (ORIGIN_PX[1] - py) / PX_PER_M)


def Y(px: float) -> float:
    return P(px, 0.0)[0]


def Z(py: float) -> float:
    return P(0.0, py)[1]


# The slide (photo: x 22 to 565, its face flush with the frame's nose (owner, 2026-11-05), its top at 45; its
# side's foot at 108 and the lower nose's foot at 112, taller than the main photo's 99 to match the owner's second
# photo's proportions, 2026-11-05), its top corners rounded SLIDE_ROUND px.
SLIDE_Y = (Y(565.0), Y(22.0))
SLIDE_ROUND = 5.0
SLIDE_TOP = Z(45.0)
SLIDE_SIDE_FOOT = Z(108.0)
SLIDE_FOOT = Z(112.0)
SLIDE_HW = 0.01275
NOSE_HW = 0.0112
# The top edges' bevel; the rear serrations; the ejection port (y from, to) and its depth down the right flank; the
# spring guide's hole (radius, height); the rear sight's half width and its notch's.
SLIDE_BEVEL = 0.0022
NOSE_CHAMFER = 0.0016
SERRATIONS = 11
SERRATION_DEPTH = 0.0007
PORT_Y = (-0.0095, 0.0225)
PORT_DEPTH = 0.0088
# The port's left edge (x) on the top; the barrel hood's clearance to the port's walls and its right face's inset from
# the flank.
PORT_X = -0.0035
HOOD_GAP = 0.00015
HOOD_INSET = 0.0012
# The hood's sloped front: it leaves the top this far behind the port's front wall and meets that wall this far down.
HOOD_SLOPE = (0.0045, 0.0030)
GUIDE_R = 0.0024
GUIDE_Z = Z(104.0)
REAR_SIGHT_HW = 0.0078
NOTCH_HW = 0.0020
# The bore (the photo's muzzle: py 63 to 99), the barrel's outer radius and the BB bore's, and the barrel's end, just
# proud of the slide's face (photo: x 20).
BORE_Z = Z(81.0)
BARREL_R = 0.0061
BORE_R = 0.0031
BARREL_END = Y(20.0)
# The sights. SIGHT_Z is the sight line (the front post's top, the empties' height and so the eye's when aimed:
# ReplicaView), a hair under the rear sight's top (Z(35)) for an equal-height picture; the rear's notch floor sits
# NOTCH_DROP under it, so aimed the whole post stands in the notch with light either side (owner 2026-11-05: the post
# was hidden, the floor had been on the line). The post stands taller than the photo's (1.7 mm) and its dot is bigger,
# so the sight picture reads at arm's length.
SIGHT_Z = SLIDE_TOP + 0.0030
NOTCH_DROP = 0.0021
FRONT_POST_HW = 0.0016
FRONT_DOT_R = 0.00085
REAR_SIGHT_Y = Y(529.0)
FRONT_SIGHT_Y = Y(49.0)
# The frame: half widths of its upper part (walls, dust cover), the trigger guard and the grip.
FRAME_HW = 0.0124
GUARD_HW = 0.0084
GRIP_HW = 0.0150
GRIP_FOOT = 424.0
# How deep the thumb rest's scoop sinks into the frame's side over the grip.
THUMB_DEPTH = 0.0013
GRIP_CHAMFER = 0.0026
# The takedown lever's recess (owner, 2026-11-05: slightly recessed, its walls curving smoothly, narrow and leaning
# parallel to the lever as in his second photo): the floor's centre and half sizes (photo px), corner radius (px),
# depth (metres) and lean (px back per px down, the lever's, 0.33 as in that photo); and how far the lever stands
# out of the floor.
TAKEDOWN_RECESS = ((273.0, 130.0), (13.5, 14.5), 4.0, 0.0008, 0.33)
TAKEDOWN_PROUD = 0.0009
RAIL_SLOT_DEPTH = 0.0045
BACK_GROOVES, BACK_GROOVE_PY, BACK_GROOVE_PITCH = 18, (244.0, 386.0), 142.0 / 17.0
FRONT_GROOVE_PY = tuple(c + d for c in (260.0, 310.5, 363.5) for d in (-8.25, -2.75, 2.75, 8.25))
THUMB_CLEAR = 0.00015
# The thumb rest's bowl: its centre x and half length, its height (photo px) and its rim's raised bead (metres).
THUMB_PX = (453.0, 47.0)
THUMB_H = 36.0
THUMB_COLS = 30
THUMB_BEAD = 0.0003
# How far the grip's stippled panels stand proud of its sides; their texture's tile (metres), size (px) and dimples.
STIPPLE_RISE = 0.00035
STIPPLE_BACK = 22.0
STIPPLE_TILE = 0.012
STIPPLE_PX = 256
STIPPLE_DIMPLES = 900
# The magazine: raked GRIP_RAKE back like the grip, its top centre in the grip (MagWell) and its base plate's foot.
GRIP_RAKE = 22.0
MAG_TOP_PX = (432.0, 172.0)
MAG_FOOT_PY = 447.0
MAG_HW = 0.0112
# The base plate's two tiers' half widths: the slab and the foot under it.
PLATE_HW = (MAG_HW + 0.0022, MAG_HW + 0.0014)
MAG_HD = 0.0158

MAG_TOP = (0.0, Y(MAG_TOP_PX[0]), Z(MAG_TOP_PX[1]))
# Under the dust cover's rail, where the parts file's laser and light sit (photo about x 100, py 152).
RAIL_MOUNT = (0.0, 0.072, -0.0136)
EMPTIES = {
    "Muzzle": (0.0, BARREL_END, BORE_Z), "ThreadEnd": (0.0, BARREL_END, BORE_Z),
    "FrontSight": (0.0, FRONT_SIGHT_Y, SIGHT_Z), "RearSight": (0.0, REAR_SIGHT_Y, SIGHT_Z),
    "MagWell": MAG_TOP, "RailMount": RAIL_MOUNT, "TorchMount": RAIL_MOUNT,
}

# Bones: name -> head (each points +Y, BONE_LENGTH long, roll 0, as the old file's). The slide and the root where
# they were; the trigger at its pivot, the magazine at its top, the release at its button.
BONES = {
    "root": (0.0, 0.0, 0.0),
    "magazine": MAG_TOP,
    "magRelease": (-0.0160, Y(392.0), Z(210.0)),
    "slide": (0.0, 0.0, 0.018),
    "trigger": (0.0, Y(330.0), Z(163.0)),
}
BONE_LENGTH = 0.0170

# Plain colours (the game paints the five scheme materials; these are what a viewer without it shows).
MATERIALS = {
    "Body": (0x26292e, 0.5, 0.0), "Furniture": (0x2f333a, 0.56, 0.0), "Detail": (0x2b2e33, 0.5, 0.0),
    "Accent": (0xf2f0ea, 0.5, 0.0), "Metal": (0x3c4046, 0.38, 0.6), "Stipple": (0x22252a, 0.95, 0.0),
    "BB": (0xf4f1e8, 0.3, 0.0),
}


def pts(trace: list) -> list:
    """Photo points (px, py[, r px]) as fillet corners (y, z, r m)."""
    out = []
    for p in trace:
        y, z = P(p[0], p[1])
        out.append((y, z, (p[2] / PX_PER_M) if len(p) > 2 else 0.0))
    return out


# ------------------------------------------------------------------------------------------------------------ slide

def slide() -> object:
    """The slide: a square block with bevelled top edges and the narrower nose under its front, rear serrations, the
    ejection port with the barrel's hood filling it, the extractor, the rear cover plate, the sights, and the barrel
    and spring guide in its face."""
    b = hs.Builder("Slide", ["Body", "Detail", "Metal", "Accent"])
    y0, y1 = SLIDE_Y
    top, foot = SLIDE_TOP, SLIDE_SIDE_FOOT
    ch = SLIDE_BEVEL
    sec = [(-NOSE_HW, SLIDE_FOOT), (NOSE_HW, SLIDE_FOOT), (NOSE_HW, foot), (SLIDE_HW, foot), (SLIDE_HW, top - ch),
           (SLIDE_HW - ch, top), (-SLIDE_HW + ch, top), (-SLIDE_HW, top - ch), (-SLIDE_HW, foot), (-NOSE_HW, foot)]
    b.prism(sec, "y", y0, y1, "Body")
    ob = b.build()
    # The side's outline: the top's corners rounded front and back, as the photo's.
    c = hs.Builder("c_side", ["Body"])
    r = SLIDE_ROUND / PX_PER_M
    c.prism(hs.fillet([(y0, SLIDE_FOOT - 0.002, 0.0), (y1, SLIDE_FOOT - 0.002, 0.0), (y1, top, r), (y0, top, r)], 6),
            "x", -0.02, 0.02, "Body")
    hs.cut(ob, [c.build()], "INTERSECT")
    # The face's chamfer: the top and sides run in NOSE_CHAMFER at 45 degrees round the muzzle end.
    c = hs.Builder("c_nose", ["Body"])
    big = 0.001
    chamfer = NOSE_CHAMFER + big

    def box_ring(y: float, d: float) -> list:
        x, zt = SLIDE_HW + big - d, top + big - d
        zb = SLIDE_FOOT - 0.003
        return [(-x, y, zb), (x, y, zb), (x, y, zt), (-x, y, zt)]

    c.loft([box_ring(y0 - 0.01, 0.0), box_ring(y1 - chamfer, 0.0), box_ring(y1 + 0.0001, chamfer + 0.0001)], "Body")
    hs.cut(ob, [c.build()], "INTERSECT")
    cutters = []
    # Rear serrations: flat-bottomed grooves as wide as the lands between them, the flank's full height and into
    # the bevel (photo: nine, x 440 to 532).
    pitch = (Y(440.0) - Y(532.0)) / (SERRATIONS - 0.5)
    for sx in (-1, 1):
        for i in range(SERRATIONS):
            y0s = Y(532.0) + i * pitch
            c = hs.Builder("c_ser", ["Body"])
            xa, xb = sorted((sx * (SLIDE_HW - SERRATION_DEPTH), sx * 0.02))
            c.box((xa, y0s, foot - 0.001), (xb, y0s + pitch * 0.5, top + 0.001), "Body")
            cutters.append(c.build())
    # The ejection port: open on the top's right and down the right side to PORT_DEPTH, its front corners rounded.
    c = hs.Builder("c_port", ["Body"])
    c.prism(hs.fillet([(PORT_Y[0], top - PORT_DEPTH, 0.0), (PORT_Y[1], top - PORT_DEPTH, 0.003),
                       (PORT_Y[1], top + 0.01, 0.0), (PORT_Y[0], top + 0.01, 0.0)], 6), "x", PORT_X, 0.02, "Body")
    cutters.append(c.build())
    # The extractor's slot: a recess in the right flank running back from the port.
    flank = top - foot
    ez0, ez1 = top - 0.40 * flank, top - 0.16 * flank
    c = hs.Builder("c_ext", ["Body"])
    c.prism(hs.fillet([(PORT_Y[0] - 0.0175, ez0, 0.0016), (PORT_Y[0] + 0.002, ez0, 0.0), (PORT_Y[0] + 0.002, ez1, 0.0),
                       (PORT_Y[0] - 0.0175, ez1, 0.0016)], 4), "x", SLIDE_HW - 0.0008, 0.02, "Body")
    cutters.append(c.build())
    # The rear cover plate's outline, a fine groove in the back face.
    c = hs.Builder("c_plate", ["Body"])
    plate = hs.fillet([(-0.0090, SLIDE_FOOT + 0.0012, 0.0015), (0.0090, SLIDE_FOOT + 0.0012, 0.0015),
                       (0.0090, foot + 0.0110, 0.002), (-0.0090, foot + 0.0110, 0.002)], 3)
    inner = hs.fillet([(-0.0085, SLIDE_FOOT + 0.0017, 0.0011), (0.0085, SLIDE_FOOT + 0.0017, 0.0011),
                       (0.0085, foot + 0.0105, 0.0016), (-0.0085, foot + 0.0105, 0.0016)], 3)
    c.prism(plate, "y", y0 - 0.001, y0 + 0.0005, "Body")
    cut_plate = c.build()
    c = hs.Builder("c_plate_in", ["Body"])
    c.prism(inner, "y", y0 - 0.002, y0 + 0.002, "Body")
    hs.cut(cut_plate, [c.build()])
    cutters.append(cut_plate)
    # The muzzle's bore through the face, and the spring guide's hole under it.
    c = hs.Builder("c_bore", ["Body"])
    c.lathe([(y1 - 0.030, BARREL_R + 0.0004), (y1 + 0.01, BARREL_R + 0.0004)], "Body", 28,
            centre=(0.0, 0.0, BORE_Z))
    cutters.append(c.build())
    c = hs.Builder("c_guide", ["Body"])
    c.lathe([(y1 - 0.010, GUIDE_R), (y1 + 0.01, GUIDE_R)], "Body", 24, centre=(0.0, 0.0, GUIDE_Z))
    cutters.append(c.build())
    hs.cut(ob, cutters)
    hs.finish(ob, 0.0008, 2)
    # The cover plate itself, a touch inside the face.
    b = hs.Builder("CoverPlate", ["Body"])
    b.prism(inner, "y", y0 - 0.0002, y0 + 0.001, "Body")
    parts = [ob, hs.finish(b.build(), 0.0003, 1)]
    # The barrel: its hood filling the port to a hairline (HOOD_GAP) front, back and on the left, flush with the top
    # (owner 2026-11-05: no gap between slide and barrel in the port), its front edge sloping down to the barrel as
    # before (owner 2026-11-05: keep the slope), its right face HOOD_INSET inside the flank as the photos' chamber;
    # its tube to the face.
    b = hs.Builder("Barrel", ["Metal"])
    g = HOOD_GAP
    hood = hs.fillet([(PORT_Y[0] + g, BORE_Z, 0.0), (PORT_Y[1] - g, BORE_Z, 0.0),
                      (PORT_Y[1] - g, top - HOOD_SLOPE[1], 0.0015), (PORT_Y[1] - HOOD_SLOPE[0], top - 0.0002, 0.001),
                      (PORT_Y[0] + g, top - 0.0002, 0.0)], 3)
    b.prism(hood, "x", PORT_X + g, SLIDE_HW - HOOD_INSET, "Metal")
    end = BARREL_END
    b.tube([(PORT_Y[0] + 0.002, BARREL_R), (end - 0.0004, BARREL_R), (end, BARREL_R - 0.0005)],
           [(PORT_Y[0] + 0.002, BORE_R), (end - 0.0008, BORE_R), (end, BORE_R + 0.0012)], "Metal", 28,
           centre=(0.0, 0.0, BORE_Z))
    parts.append(hs.finish(b.build(), 0.00025, 1))
    # The spring guide's end, the extractor and the sights.
    b = hs.Builder("Bits", ["Detail", "Metal", "Accent"])
    b.lathe([(y1 - 0.004, GUIDE_R - 0.0008), (y1 - 0.0012, GUIDE_R - 0.0008), (y1 - 0.0008, GUIDE_R - 0.0014),
             (y1 - 0.0008, 0.0)], "Metal", 20, centre=(0.0, 0.0, GUIDE_Z))
    # Extractor: a slim bar in its slot, a little below the flank, its rear end rounded.
    g = 0.0003
    bar = hs.fillet([(PORT_Y[0] - 0.0175 + g, ez0 + g, 0.0013), (PORT_Y[0] - 0.0006, ez0 + g, 0.0),
                     (PORT_Y[0] - 0.0006, ez1 - g, 0.0), (PORT_Y[0] - 0.0175 + g, ez1 - g, 0.0013)], 4)
    b.prism(bar, "x", SLIDE_HW - 0.0009, SLIDE_HW - 0.0002, "Metal")
    # Rear sight: a wide block, sloped front and back (photo: its foot x 521 to 541, its top x 524 to 534 at
    # py 35), a U notch with a white outline on its back face.
    ry = REAR_SIGHT_Y
    rear = [(Y(541.0), top - 0.0004), (Y(521.0), top - 0.0004), (Y(524.0), Z(35.0)), (Y(534.0), Z(35.0))]
    b.prism(rear, "x", -REAR_SIGHT_HW, REAR_SIGHT_HW, "Detail")
    # Front sight: a post with a white dot set into its sloped back face (one piece with it, owner 2026-11-05), the
    # dot laid on the face (tilted with it), standing 0.12 mm proud, centred where the notch's light frames it.
    foot = top - 0.0004
    b.prism(hs.fillet([(Y(53.5), foot, 0.0), (Y(44.5), foot, 0.0), (Y(46.0), SIGHT_Z, 0.0006),
                       (Y(51.5), SIGHT_Z, 0.0006)], 3), "x", -FRONT_POST_HW, FRONT_POST_HW, "Detail")
    dot_z = SIGHT_Z - FRONT_DOT_R - 0.0004
    back = Y(53.5) + (Y(51.5) - Y(53.5)) * (dot_z - foot) / (SIGHT_Z - foot)
    tilt = math.atan2(Y(51.5) - Y(53.5), SIGHT_Z - foot)
    f = b.lathe([(0.0, 0.0), (0.0, FRONT_DOT_R), (0.0004, FRONT_DOT_R), (0.0004, 0.0)], "Accent", 16,
                centre=(0.0, back - 0.00012, dot_z), axis="y")
    b.transform(f, hs.rot_about("x", -tilt, (0.0, back, dot_z)))
    bits = b.build()
    floor = SIGHT_Z - NOTCH_DROP
    c = hs.Builder("c_notch", ["Detail"])
    c.prism(hs.rounded_rect(NOTCH_HW, 0.0030, 0.0009, 3), "y", ry - 0.010, ry + 0.010, "Detail",
            offset=(0.0, 0.0, floor + 0.0030))
    hs.cut(bits, [c.build()])
    # The notch's white outline: a U laid on the sight's back face, one plane leaning forward at its top (from x 541
    # at its foot to 534 at the top). Heights are drawn along the face, so each is its drop over cos(lean): the U's
    # floor band ends exactly on the notch's floor, nothing white across the notch.
    b = hs.Builder("RearDot", ["Accent"])
    w = 0.0006
    zt = Z(35.0) - 0.0001
    lean = math.atan2(Y(534.0) - Y(541.0), Z(35.0) - (top - 0.0004))
    k = 1.0 / math.cos(lean)
    u = [(-NOTCH_HW - w, 0.0), (-NOTCH_HW - w, (floor - w - zt) * k), (NOTCH_HW + w, (floor - w - zt) * k),
         (NOTCH_HW + w, 0.0), (NOTCH_HW, 0.0), (NOTCH_HW, (floor - zt) * k), (-NOTCH_HW, (floor - zt) * k),
         (-NOTCH_HW, 0.0)]
    f = b.prism(u, "y", -0.00012, 0.00012, "Accent")
    face_y = Y(534.0) - (Z(35.0) - zt) * math.tan(lean)
    b.transform(f, Matrix.Translation((0.0, face_y, zt)) @ Matrix.Rotation(-lean, 4, "X"))
    dot = b.build()
    parts += [hs.finish(bits, 0.0003, 1), dot]
    return hs.join("Slide", parts)


# ------------------------------------------------------------------------------------------------------------ frame

# The grip's outline on the photo: front strap (finger grooves) and back strap (with the tang), as px x at py.
FRONT_STRAP = [(232, 381), (240, 384), (250, 391), (260, 395), (270, 399), (280, 399), (288, 397), (294, 398),
               (300, 405), (308, 413), (316, 419), (324, 422), (332, 421), (338, 419), (344, 421), (352, 428),
               (362, 434), (372, 439), (384, 443), (396, 445), (406, 443), (412, 444.5), (416, 446), (420, 449.5),
               (424, 455)]
BACK_STRAP = [(101, 556), (106, 566), (112, 571.5), (116, 574), (119, 574.5), (124, 575), (128, 574), (131, 573),
              (134, 572), (137, 566), (140, 559), (143, 552), (146, 545), (149, 540), (152, 536), (157, 533),
              (161, 530), (165, 528), (170, 527), (182, 527),
              (187, 528), (193, 529), (197, 530), (215, 535), (240, 545), (260, 553), (280, 564), (300, 578),
              (320, 592), (340, 603.5), (360, 613.5), (380, 621), (392, 623), (400, 623), (406, 620), (412, 615),
              (418, 607), (424, 597)]


def _at(table: list, py: float) -> float:
    for (a, xa), (b, xb) in zip(table, table[1:]):
        if a <= py <= b:
            return xa + (xb - xa) * (py - a) / max(1e-9, b - a)
    return table[0][1] if py < table[0][0] else table[-1][1]


def grip_section(py: float) -> tuple:
    """The grip's section at photo height py: its centre and half depth along y, its height, half width and the
    superellipse exponent (flat-sided like the frame up top, rounder down the grip)."""
    if py < FRONT_STRAP[0][0]:
        front_px = FRONT_STRAP[0][1] + 6.0
    else:
        front_px = _at(FRONT_STRAP, py)
    back_px = _at(BACK_STRAP, py)
    yf, yb = Y(front_px), Y(back_px)
    # Width: the frame's at the top, swelling into the grip under the shelf (photo py 150 to 200), a touch fuller
    # at the magazine well's flared foot.
    u = min(1.0, max(0.0, (py - 172.0) / 50.0))
    w = u * u * (3.0 - 2.0 * u)
    hw = FRAME_HW + (GRIP_HW - FRAME_HW) * w
    if py > 390.0:
        # The foot's chamfer, facing down all round over the base plate (photo: a dark band, py 412 to 424).
        hw += 0.0005 * min(1.0, (py - 390.0) / 10.0) - GRIP_CHAMFER * max(0.0, (py - GRIP_FOOT + 12.0) / 12.0)
    n = 24.0 + (3.0 - 24.0) * min(1.0, max(0.0, (py - 160.0) / 70.0)) ** 0.5
    return (yf + yb) * 0.5, (yf - yb) * 0.5, Z(py), hw, n


def _smooth(u: float) -> float:
    u = min(1.0, max(0.0, u))
    return u * u * (3.0 - 2.0 * u)


def swell(py: float, y: float, hw: float) -> float:
    """The grip's half width at photo height py and length y: the swell under the shelf grows from the frame's flat
    wall behind the trigger guard back to the palm, so the grip rises out of the frame's side with no crease; it is
    the full width all round below the frame (photo py 236 to 266)."""
    front_px = FRONT_STRAP[0][1] + 6.0 if py < FRONT_STRAP[0][0] else _at(FRONT_STRAP, py)
    s = _smooth((ORIGIN_PX[0] - y * PX_PER_M - front_px - 8.0) / 60.0)
    s += (1.0 - s) * _smooth((py - 236.0) / 30.0)
    return FRAME_HW + (hw - FRAME_HW) * s


def side_x(py: float, y: float) -> float:
    """The grip's side (x, right) at photo height py and length y."""
    cy, half, _z, hw, n = grip_section(py)
    t = min(1.0, abs(y - cy) / half)
    return swell(py, y, hw) * (1.0 - t ** n) ** (1.0 / n)


def grip_ring(py: float, count: int = 40) -> list:
    cy, half, z, hw, n = grip_section(py)
    return [(x * swell(py, cy + d, hw) / hw, cy + d, z) for x, d in hs.superellipse(hw, half, half, n, count)]


def grip() -> object:
    b = hs.Builder("Grip", ["Furniture"])
    pys = [101.0, 103.0, 106.0, 110.0, 115.0, 120.0, 125.0, 130.0, 135.0, 140.0]
    py = 144.0
    while py < 206.0:
        pys.append(py)
        py += 4.0
    py = 206.0
    while py < GRIP_FOOT - 13.0:
        pys.append(py)
        py += 4.0
    # Close rows at the chamfer's top so its edge stays crisp.
    pys += [GRIP_FOOT - d for d in (12.5, 12.0, 8.0, 4.0, 0.0)]
    b.loft([grip_ring(p) for p in pys], "Furniture")
    return b.build()


def stipple_panels() -> object:
    """The stippled panels: shells over the grip's sides from the shelf to the smooth band over the foot, behind the
    front strap's band and ahead of the back strap's checkering: a parallelogram raked with the grip (photo: its
    front edge from x 417 at py 199 to 452 at py 372), its top-front corner rounded under the thumb rest, standing
    STIPPLE_RISE proud with a stepped border."""
    b = hs.Builder("Stipple", ["Stipple", "Furniture"])
    # A thin first and last row and column, so the stepped border is narrow.
    rows = [199.0, 199.5] + [199.0 + 173.0 * i / 18 for i in range(1, 18)] + [371.5, 372.0]
    fracs = [0.0, 0.006] + [k / 10 for k in range(1, 10)] + [0.994, 1.0]
    corner = 18.0
    for sx in (-1, 1):
        grid = []
        for k, py in enumerate(rows):
            fx = 409.0 + (py - 199.0) * 40.0 / 173.0
            if py < 199.0 + corner:
                d = corner - (py - 199.0)
                fx += corner - math.sqrt(max(0.0, corner * corner - d * d))
            front = Y(fx)
            back = Y(_at(BACK_STRAP, py) - STIPPLE_BACK)
            row = []
            for j, f in enumerate(fracs):
                y = back + (front - back) * f
                edge = j in (0, len(fracs) - 1) or k in (0, len(rows) - 1)
                x = side_x(py, y) + (0.00005 if edge else STIPPLE_RISE)
                row.append((sx * x, y, Z(py)))
            grid.append(row)
        b.loft(grid, "Stipple", cap0=False, cap1=False, closed=False)
    # Every face out from the grip's middle.
    for face in b.bm.faces:
        c = face.calc_center_median()
        cy = grip_section(ORIGIN_PX[1] - c.z * PX_PER_M)[0]
        if face.normal.x * c.x + face.normal.y * (c.y - cy) < 0.0:
            face.normal_flip()
    # The stepped border in the frame's plain finish, so the dimples don't smear down its wall.
    rim = b.mat("Furniture")
    for face in b.bm.faces:
        if any(abs(abs(v.co.x) - side_x(ORIGIN_PX[1] - v.co.z * PX_PER_M, v.co.y)) < 0.0001 for v in face.verts):
            face.material_index = rim
    ob = b.build()
    # Its texture's coordinates: the side's length and height, a tile every STIPPLE_TILE metres.
    uv = ob.data.uv_layers.new(name="UVMap")
    for loop in ob.data.loops:
        v = ob.data.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = ((v.y + v.x) / STIPPLE_TILE, v.z / STIPPLE_TILE)
    return ob


def stipple_texture() -> None:
    """The stippled panels' bumps: a tiling normal map of small round dimples (seeded, so every build is the same),
    on the Stipple material, which the paint schemes leave as drawn."""
    import random
    size = STIPPLE_PX
    rng = random.Random(7)
    height = [[0.0] * size for _ in range(size)]
    r = 5
    for _ in range(STIPPLE_DIMPLES):
        cx, cy = rng.randrange(size), rng.randrange(size)
        depth = 0.7 + 0.3 * rng.random()
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                d2 = (dx * dx + dy * dy) / float(r * r)
                if d2 < 1.0:
                    row = height[(cy + dy) % size]
                    row[(cx + dx) % size] -= depth * (1.0 - d2) ** 2
    px = []
    k = 1.6
    for y in range(size):
        for x in range(size):
            gx = (height[y][(x + 1) % size] - height[y][x - 1]) * k
            gy = (height[(y + 1) % size][x] - height[y - 1][x]) * k
            ln = math.sqrt(gx * gx + gy * gy + 1.0)
            px += [(-gx / ln) * 0.5 + 0.5, (-gy / ln) * 0.5 + 0.5, (1.0 / ln) * 0.5 + 0.5, 1.0]
    img = bpy.data.images.new("stipple_normal", size, size, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(px)
    img.file_format = "PNG"
    img.pack()
    m = bpy.data.materials["Stipple"]
    nt = m.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nm.inputs["Strength"].default_value = 1.0
    nt.links.new(tex.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], nt.nodes["Principled BSDF"].inputs["Normal"])


def frame_upper() -> object:
    """The frame's upper part: the walls under the slide, the dust cover with its rail, the tang, and the body over
    the trigger guard."""
    b = hs.Builder("Frame", ["Furniture"])
    # The dust cover's underside at py 155 to 159, a slimmer body than the main photo's to match the owner's second
    # photo (2026-11-05).
    out = pts([(22, 110), (22, 136, 4), (26, 145, 6), (34, 151, 6), (48, 154.5, 6), (100, 155), (145, 156),
               (175, 156.5), (212, 157.5, 8), (232, 158.5, 6), (340, 159),
               (380, 172, 6), (392, 200, 6), (394, 236), (420, 236), (432, 150), (440, 100), (172, 100), (160, 110, 4)])
    b.prism(hs.fillet(out, 4), "x", -FRAME_HW, FRAME_HW, "Furniture")
    ob = b.build()
    guard, web = trigger_guard(), guard_web()
    hs.cut(guard, [guard_opening()])
    hs.cut(web, [guard_opening()])
    hs.cut(ob, [guard, web, grip()], "UNION")
    cutters = []
    # The rail's slots under the slide's nose, a side (py 131 to 141.5, x 10 to 166, 4.5 mm deep), so the rail's
    # land stands out under them; and its cross slot.
    for sx in (-1, 1):
        c = hs.Builder("c_rail", ["Furniture"])
        xa, xb = sorted((sx * (FRAME_HW - RAIL_SLOT_DEPTH), sx * 0.02))
        c.box((xa, Y(166.0), Z(141.5)), (xb, Y(10.0), Z(131.0)), "Furniture")
        cutters.append(c.build())
    c = hs.Builder("c_slot", ["Furniture"])
    c.box((-(FRAME_HW - 0.0014), Y(92.0), Z(170.0)), (FRAME_HW - 0.0014, Y(78.0), Z(145.0)), "Furniture")
    cutters.append(c.build())
    for sx in (-1, 1):
        # The takedown lever's shallow recess, its walls curving softly into the side, and the slot under the lever.
        cutters.append(takedown_recess(sx))
        c = hs.Builder("c_td_slot", ["Furniture"])
        xa, xb = sorted((sx * (FRAME_HW - 0.0032), sx * 0.02))
        slot = [(271.8, 131, 1), (279.3, 131, 1), (282.8, 141, 1.5), (275.3, 141, 1.5)]
        c.prism(hs.fillet(pts(slot), 2), "x", xa, xb, "Furniture")
        cutters.append(c.build())
        # The thumb rest: a bowl over the grip's panel (photo: x 406 to 500, py 150 to 193).
        cutters.append(thumb_rest(sx))
    # The slide stop's shelf, a recess in the left wall under the lever, its top a shallow arc and its foot flat
    # (x 386 to 430, py 127 to 138).
    c = hs.Builder("c_shelf", ["Furniture"])
    c.prism(hs.fillet(pts([(386, 127, 2), (397, 130), (408, 131), (419, 130), (430, 127, 2), (430, 138, 3),
                           (386, 138, 3)]), 3), "x", -0.02, -(FRAME_HW - 0.0007), "Furniture")
    cutters.append(c.build())
    # The magazine well's front notch, showing the magazine (photo: under the front strap, py 405 to 425).
    c = hs.Builder("c_notch", ["Furniture"])
    c.prism(hs.fillet([(Y(485.0), Z(425.0), 0.0), (Y(430.0), Z(425.0), 0.0), (Y(430.0), Z(405.0), 0.0),
                       (Y(476.0), Z(405.0), 0.003)], 3), "x", -0.0070, 0.0070, "Furniture")
    cutters.append(c.build())
    # The straps' grooves: a band of slanted grooves down the back strap wrapping onto the sides, and three ribbed
    # pads of four on the front strap's finger bumps (photo: x 393 to 455, py 247 to 377).
    for k in range(BACK_GROOVES):
        cutters.append(strap_groove(BACK_GROOVE_PY[0] + k * BACK_GROOVE_PITCH, False, 30.0, 0.0010, 3.5, 25.0))
    for py in FRONT_GROOVE_PY:
        cutters.append(strap_groove(py, True, 20.0, 0.00055, 3.0, 0.0))
    hs.cut(ob, cutters)
    return hs.finish(ob, 0.0011, 2)


def thumb_edge(px: float) -> float:
    """The thumb rest's rim, a smile under its bowl (photo: from 408, 180 down to 455, 193 and up to 498, 180)."""
    return 193.0 - 13.0 * ((px - THUMB_PX[0]) / (THUMB_PX[1] - 1.0)) ** 2


def thumb_rest(sx: int) -> object:
    """The thumb rest's cutter: a closed sheet whose inner face follows the frame's side, a bowl over the rim
    (thumb_edge) rising crisply from it, an oval fading softly into the frame above (THUMB_H px tall) and at its ends,
    THUMB_DEPTH deep at most; elsewhere the face stands THUMB_CLEAR proud and cuts nothing."""
    b = hs.Builder("c_thumb", ["Furniture"])
    x0, x1 = THUMB_PX[0] - THUMB_PX[1], THUMB_PX[0] + THUMB_PX[1]
    rings = []
    # Rows run with the rim, close together over its crisp rise.
    vs = [-0.4, -0.2, -0.08, 0.0] + [0.025 * k for k in range(1, 9)] + [0.2 + 0.08 * k for k in range(1, 11)] + [1.2]
    for v in vs:
        ring = []
        for j in range(THUMB_COLS + 1):
            px = x0 + (x1 - x0) * j / THUMB_COLS
            u = abs(px - THUMB_PX[0]) / THUMB_PX[1]
            py = thumb_edge(px) - v * THUMB_H
            # An oval: the bowl's top rounds down into the rim's ends.
            r = math.hypot(u, max(0.0, (v - 0.2) / 0.8))
            dish = (THUMB_DEPTH + THUMB_CLEAR) * math.cos(0.5 * math.pi * min(1.0, r)) ** 2 * _smooth(v / 0.15)
            x = max(FRAME_HW, side_x(py, Y(px))) + THUMB_CLEAR - dish
            ring.append((sx * x, Y(px), Z(py)))
        ring += [(sx * 0.03, ring[-1][1], ring[-1][2]), (sx * 0.03, ring[0][1], ring[0][2])]
        rings.append(ring)
    b.loft(rings, "Furniture")
    return b.build()


def thumb_rim(b: hs.Builder, sx: int) -> None:
    """The thumb rest's rim: a rounded bead along thumb_edge, THUMB_BEAD proud of the frame and 4 px wide, sinking
    into the frame at its ends."""
    rings = []
    for k in range(25):
        px = THUMB_PX[0] - THUMB_PX[1] + 2.0 + (2.0 * THUMB_PX[1] - 4.0) * k / 24
        taper = math.sin(math.pi * k / 24) ** 0.5
        rise = THUMB_BEAD * taper - 0.00025 * (1.0 - taper)
        ring = []
        for i in range(9):
            t = math.pi * i / 8
            py = thumb_edge(px) + 2.0 * math.cos(t)
            base = max(FRAME_HW, side_x(py, Y(px))) - 0.0006
            ring.append((sx * (base + (0.0006 + rise) * math.sin(t)), Y(px), Z(py)))
        rings.append(ring)
    b.loft(rings, "Furniture")


def takedown_recess(sx: int) -> object:
    """The takedown lever's recess cutter: a rounded rectangle sheared to lean with the lever (TAKEDOWN_RECESS's
    lean, px back per px down), sunk its depth, its walls a soft curve from 5 px outside the floor's outline (the
    owner's second photo: a narrow, leaning, shallow pocket)."""
    (cx, cz), (hx, hz), r, depth, lean = TAKEDOWN_RECESS
    b = hs.Builder("c_td", ["Furniture"])
    rings = []
    # From the floor out: the floor's outline, the wall easing out over 5 px (a cosine, meeting the side
    # tangentially), the outline 5 px out just proud of the side, then straight out of the side.
    for o, f in ((0.0, 1.0), (1.0, 0.9), (2.0, 0.65), (3.0, 0.35), (4.0, 0.1), (4.6, 0.02), (5.0, -0.25),
                 (5.0, None)):
        x = 0.02 if f is None else FRAME_HW - f * depth
        rings.append([(sx * x, Y(cx) - (u - lean * v) / PX_PER_M, Z(cz) + v / PX_PER_M)
                      for u, v in hs.rounded_rect(hx + o, hz + o, r + o, 4)])
    b.loft(rings, "Furniture")
    return b.build()


OPENING = [(340, 148), (346, 186), (352, 188), (356, 190), (359, 194), (361, 197), (362, 200), (362, 204),
           (361.5, 207), (360, 210), (358.5, 213), (356.5, 216), (354, 218), (351.5, 220), (349, 222), (345, 224),
           (340, 226), (335, 227), (316, 227), (300, 226), (243, 225, 24), (243, 159, 22), (290, 160.5),
           (310, 162.5), (324, 163.5), (324.3, 148)]


def trigger_guard() -> object:
    """The guard's loop, solid: its front bar slim, sweeping forward to its foot and filleted into the frame's
    underside (photo: x 226 to 218); the opening is cut through it and the web together (guard_opening)."""
    b = hs.Builder("Guard", ["Furniture"])
    out = pts([(190, 151), (340, 157), (376, 184), (391, 236, 6), (378, 238, 8), (352, 244, 12), (300, 245.5),
               (224, 244, 4), (218, 239, 3), (218, 232), (221, 220, 6), (226, 205, 8), (226, 158, 11), (200, 157.5),
               (190, 153)])
    b.prism(hs.fillet(out, 10), "x", -GUARD_HW, GUARD_HW, "Furniture")
    return b.build()


def guard_opening() -> object:
    """The trigger guard's opening (photo: a D, its front x 243, its foot py 225 dropping to 227 under the
    trigger's toe, its corners well rounded)."""
    c = hs.Builder("c_opening", ["Furniture"])
    c.prism(hs.fillet(pts(OPENING), 10), "x", -0.03, 0.03, "Furniture")
    return c.build()


def guard_web() -> object:
    """The body behind the trigger and under its guard: rounded sections from the guard's bar back into the front
    strap, widening from the guard's width to the frame's so the guard, frame and grip meet without a ledge; the
    opening is cut out of it after."""
    b = hs.Builder("Web", ["Furniture"])
    rings = []
    for i in range(15):
        px = 348.0 + 50.0 * i / 14
        hw = GUARD_HW + (FRAME_HW - 0.00005 - GUARD_HW) * _smooth((px - 350.0) / 36.0)
        foot = 245.5 - 1.5 * _smooth((px - 300.0) / 52.0) - 8.0 * _smooth((px - 352.0) / 32.0)
        lo, hi = Z(foot), Z(154.0)
        r = min(0.0022, hw * 0.4)
        sec = hs.rounded_rect(hw, (hi - lo) * 0.5, r, 3)
        rings.append([(x, Y(px), (lo + hi) * 0.5 + z) for x, z in sec])
    b.loft(rings, "Furniture")
    return b.build()


def strap_groove(py: float, front: bool, band_px: float, depth: float, width_px: float, slant: float) -> object:
    """A groove's cutter across the back (or front) strap at photo height py: band_px deep into the side from the
    strap, `depth` deep in its middle and shallow at its ends, width_px wide, slanted `slant` degrees (its forward
    end higher)."""
    count = 40
    ring = grip_ring(py, count)
    if front:
        limit = Y(_at(FRONT_STRAP, py) + band_px)
        idx = [i for i, p in enumerate(ring) if p[1] > limit]
    else:
        limit = Y(_at(BACK_STRAP, py) - band_px)
        idx = [i for i, p in enumerate(ring) if p[1] < limit]
    start = next(i for i in idx if (i - 1) % count not in idx)
    arc = []
    i = start
    while i in idx:
        arc.append(i)
        i = (i + 1) % count
    cy = grip_section(py)[0]
    rings = []
    for dpx, d in ((-0.5, -0.00005), (-0.2, 1.0), (0.2, 1.0), (0.5, -0.00005)):
        r = grip_ring(py + dpx * width_px, count)
        inner, outer = [], []
        for k, j in enumerate(arc):
            x, y, z = r[j]
            ax, ay = r[(j + 1) % count][0] - r[j - 1][0], r[(j + 1) % count][1] - r[j - 1][1]
            nx, ny = ay, -ax
            if nx * x + ny * (y - cy) < 0.0:
                nx, ny = -nx, -ny
            ln = math.hypot(nx, ny) or 1.0
            nx, ny = nx / ln, ny / ln
            end = _smooth(min(k, len(arc) - 1 - k) / max(1.0, len(arc) * 0.12))
            dd = depth * end if d > 0.0 else d
            inner.append((x - nx * dd, y - ny * dd, z))
            outer.append((x + nx * 0.0015, y + ny * 0.0015, z))
        rings.append(inner + outer[::-1])
    b = hs.Builder("c_groove", ["Furniture"])
    b.loft(rings, "Furniture")
    ob = b.build()
    pivot = Vector((0.0, Y(_at(FRONT_STRAP if front else BACK_STRAP, py)), Z(py)))
    ob.data.transform(Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(slant), 4, "X") @
                      Matrix.Translation(-pivot))
    return ob


def frame_bits() -> object:
    """The frame's small parts: the takedown lever, the thumb rest's rim, the slide stop and the pins (the straps'
    grooves are cut in frame_upper)."""
    b = hs.Builder("FrameBits", ["Detail", "Metal", "Furniture"])
    for sx in (-1, 1):
        # Takedown lever: a small tab standing out of its recess's floor, leaning back, ridged across, over the dark
        # slot it slides in (x 268 to 283, py 119 to 141), as narrow and leaning as the second photo's.
        floor = FRAME_HW - TAKEDOWN_RECESS[3]
        xa, xb = sorted((sx * (floor - 0.0003), sx * (floor + TAKEDOWN_PROUD)))
        b.prism(hs.fillet(pts([(268, 119, 1.5), (275, 119, 1.5), (278.8, 130.5, 1), (271.8, 130.5, 1)]), 2), "x",
                xa, xb, "Metal")
        for i in range(4):
            py = 121.0 + i * 2.8
            lean = (py - 119.0) * TAKEDOWN_RECESS[4]
            xa, xb = sorted((sx * (floor + TAKEDOWN_PROUD - 0.0002), sx * (floor + TAKEDOWN_PROUD + 0.0003)))
            b.prism(hs.fillet(pts([(268.5 + lean, py - 0.6, 0.4), (274.5 + lean, py - 0.6, 0.4),
                                   (274.5 + lean, py + 0.6, 0.4), (268.5 + lean, py + 0.6, 0.4)]), 1), "x", xa, xb,
                    "Metal")
        thumb_rim(b, sx)
        # Pins: the trigger's (325, 139), the housing's (511, 186) and, on the right, the locking block's.
        pins = [(325.0, 139.0), (511.0, 186.0)] + ([(329.0, 126.0)] if sx > 0 else [])
        for px, py in pins:
            x = sx * (side_x(py, Y(px)) if py > 150.0 else FRAME_HW)
            f = b.lathe([(-0.0012, 0.0017), (0.0003, 0.0017), (0.0005, 0.0012), (0.0005, 0.0)], "Metal", 14,
                        centre=(x, Y(px), Z(py)), axis="x")
            if sx < 0:
                b.transform(f, hs.rot_about("z", math.pi, (x, Y(px), Z(py))))
    # The slide stop: a lever on the left wall, ridged across its width (x 393 to 423, py 109 to 126, just under the
    # slide's foot),
    # over a crescent shelf recessed in the frame (cut in frame_upper).
    b.prism(hs.fillet(pts([(393, 109, 3), (423, 109, 3), (423, 126, 3), (393, 126, 3)]), 2), "x",
            -FRAME_HW - 0.0007, -FRAME_HW + 0.0004, "Metal")
    for i in range(4):
        py = 110.5 + i * 3.3
        b.prism(hs.fillet(pts([(395, py - 1.1, 0.6), (421, py - 1.1, 0.6), (421, py + 1.1, 0.6), (395, py + 1.1, 0.6)]),
                          1), "x", -FRAME_HW - 0.0011, -FRAME_HW - 0.0005, "Metal")
    return hs.finish(b.build(), 0.0003, 1)


# ------------------------------------------------------------------------------------------------------- moving parts

def trigger() -> object:
    """The trigger: a broad curved blade with a blunt toe clear of the guard's floor (photo: its face concave, x 325
    to 328 to 319, its back x 354 to 335, its toe square at py 226.5), the safety blade standing out of its face,
    hung from its pivot."""
    b = hs.Builder("Trigger", ["Detail", "Metal"])
    front = [P(323, 150), P(324, 161), P(324.5, 170), P(325, 176), P(327, 180), P(328, 184), P(328, 194), P(326, 200),
             P(323, 207), P(321, 212), P(319, 216), P(319, 222), P(319, 226), P(320, 226.5)]
    back = [P(333, 226.5), P(335, 224), P(339, 220), P(342, 216), P(344, 212), P(346, 206), P(348, 202),
            P(351, 198), P(354, 190), P(353, 178), P(349, 166), P(340, 160), P(337, 150)]
    shoe = hs.smooth(front, 2) + hs.smooth(back, 2)
    b.prism(shoe, "x", -0.0037, 0.0037, "Detail")
    # The safety blade, standing out of the shoe's face down its length.
    blade = [P(323.5, 174), P(326.5, 186), P(326.5, 194), P(324, 203), P(317.5, 217), P(319.5, 221), P(326, 207),
             P(330, 195), P(330, 174)]
    b.prism(hs.smooth(blade, 2), "x", -0.0012, 0.0012, "Detail")
    # The pins through the shoe (photo: 333, 176 and 336, 188).
    for px, py in ((333.0, 176.0), (336.0, 188.0)):
        b.lathe([(-0.0039, 0.0), (-0.0039, 0.0008), (0.0039, 0.0008), (0.0039, 0.0)], "Metal", 10,
                centre=(0.0, Y(px), Z(py)), axis="x")
    ob = b.build()
    return hs.finish(ob, 0.0004, 1)


def mag_release() -> object:
    """The magazine release: a ribbed button standing out of the left side behind the guard, leaning back with the
    front strap (photo: 20 by 27 px, x 385 to 405, py 197 to 223), and its plain end out of the right side."""
    b = hs.Builder("MagRelease", ["Detail"])
    _bx, by, bz = BONES["magRelease"]
    wall = -(FRAME_HW - 0.0002)
    b.prism(hs.rounded_rect(0.0029, 0.0046, 0.0010, 2), "x", wall - 0.0020, wall, "Detail", offset=(0.0, by, bz))
    # Its plain right end, standing out of the right side (photo 125109).
    b.prism(hs.rounded_rect(0.0040, 0.0046, 0.0010, 2), "x", -wall, -wall + 0.0009, "Detail", offset=(0.0, by, bz))
    ob = b.build()
    cs = []
    for i in range(7):
        c = hs.Builder("c_mr", ["Detail"])
        y0 = by - 0.0024 + i * 0.00075
        c.box((wall - 0.004, y0, bz - 0.0036), (wall - 0.0016, y0 + 0.00035, bz + 0.0036), "Detail")
        cs.append(c.build())
    hs.cut(ob, cs)
    pivot = Vector((0.0, by, bz))
    ob.data.transform(Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(20.0), 4, "X") @
                      Matrix.Translation(-pivot))
    return hs.finish(ob, 0.0003, 1)


def magazine(name: str = "Magazine", extra: float = 0.0, plate_mat: str = "Detail", fine: int = 1) -> object:
    """A double-stack gas magazine raked like the grip: its body, a base plate under a flanged lip, the follower
    with the top BBs, and its gas valve under the plate. `extra` metres longer along the rake for a magazine part
    (tools/blender/parts/magazines.py), its plate in `plate_mat`; `fine` times rounder corners, BBs and valve and a
    finer bevel (the parts' own budget)."""
    rake = math.radians(GRIP_RAKE)
    down = Vector((0.0, -math.sin(rake), -math.cos(rake)))
    top = Vector(MAG_TOP)
    foot_z = Z(MAG_FOOT_PY)
    plate_top = Z(GRIP_FOOT + 1.0)
    length = (top.z - plate_top) / math.cos(rake) + extra
    mats = ["Detail", "Metal", "BB", "Accent"]
    b = hs.Builder(name, mats + ([plate_mat] if plate_mat not in mats else []))

    def ring(t: float, s: float = 1.0) -> list:
        c = top + down * (length * t)
        return [(x * s, c.y + y * s, c.z) for x, y in hs.rounded_rect(MAG_HW, MAG_HD, 0.0045, 2 * fine)]

    b.loft([ring(0.0), ring(1.0 - 0.003 / length), ring(1.0)], "Metal")
    # The base plate (photo: x 462 to 594, py 420 to 447), in two tiers.
    plate = _base_plate(plate_mat)
    if extra > 0.0:
        plate.data.transform(Matrix.Translation(down * extra))
    faces = []
    # The plate's grip on each side, in the foot (photo): a pill, a slot and three slanted slots.
    marks = [[(486, 439.5, 2.5), (500, 439.5, 2.5), (500, 444.5, 2.5), (486, 444.5, 2.5)],
             [(508, 440, 2), (526, 440, 2), (526, 444, 2), (508, 444, 2)]]
    marks += [[(x, 444.5), (x + 10, 444.5), (x + 14, 439.5), (x + 4, 439.5)] for x in (530.0, 545.0, 560.0)]
    for sx in (-1, 1):
        for m in marks:
            faces += b.prism(hs.fillet(pts(m), 1), "x", sx * PLATE_HW[1] - 0.0003, sx * PLATE_HW[1] + 0.0001,
                             "Metal")
    # The gas valve's cap, flush in the plate's foot.
    faces += b.lathe([(0.0, 0.0), (0.0, 0.0030), (0.0006, 0.0030), (0.0006, 0.0)], "Metal", 14 * fine,
                     centre=(0.0, Y(530.0), foot_z - 0.0001), axis="z")
    if extra > 0.0:
        b.transform(faces, Matrix.Translation(down * extra))
    # The follower and two BBs at the lips; a small accent tab on the follower.
    c = top + down * 0.002
    b.box((-0.0040, c.y - 0.012, c.z - 0.002), (0.0040, c.y + 0.010, c.z + 0.0005), "Detail")
    for i in range(2):
        b.lathe([(-0.003, 0.0), (-0.0026, 0.0015), (-0.0015, 0.0026), (0.0, 0.003), (0.0015, 0.0026),
                 (0.0026, 0.0015), (0.003, 0.0)], "BB", 10 if fine == 1 else 16, centre=(0.0, c.y + 0.006 - i * 0.0062,
                 c.z + 0.0032 - i * 0.0008), axis="z")
    b.box((-0.0015, c.y - 0.011, c.z + 0.0005), (0.0015, c.y - 0.007, c.z + 0.0012), "Accent")
    return hs.join(name, [hs.finish(b.build(), 0.0005, 1 if fine == 1 else 2), plate])


def _base_plate(mat: str) -> object:
    """The magazine's base plate in two tiers (photo): a thick slab under the grip's foot, its top edge bevelled
    (x 462 to 594, py 420 to 437), over a narrower foot (x 462 to 590, py 437 to 447) whose rear slants
    in; each a rounded section run along the plate and trimmed by its side outline."""
    parts = []
    for hw, r, side, rr in ((PLATE_HW[0], 0.0016, [(464, 420), (590, 420), (594, 424, 3), (594, 437), (462, 437),
                                                   (462, 423, 3)], 2),
                            (PLATE_HW[1], 0.0011, [(462, 436), (590, 436), (584, 447, 3), (468, 447, 4),
                                                   (462, 442, 3)], 3)):
        zs = [p[1] for p in side]
        lo, hi = Z(max(zs)), Z(min(zs))
        b = hs.Builder("Plate", [mat])
        b.prism([(x, (lo + hi) * 0.5 + z) for x, z in hs.rounded_rect(hw, (hi - lo) * 0.5 + 0.0002, r, 4)], "y",
                Y(max(p[0] for p in side)) - 0.001, Y(min(p[0] for p in side)) + 0.001, mat)
        ob = b.build()
        c = hs.Builder("c_plate", [mat])
        c.prism(hs.fillet(pts(side), rr), "x", -0.03, 0.03, mat)
        hs.cut(ob, [c.build()], "INTERSECT")
        parts.append(hs.finish(ob, 0.0006, 2))
    return hs.join("Plate", parts)


# ------------------------------------------------------------------------------------------------------------- rig

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


def ease_out(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return 1.0 - (1.0 - t) * (1.0 - t)


# Clips: seconds, and per bone a list of (time, value[, "out"]) keys; value is degrees for a turn about x ("rx") or
# metres along an axis ("lx", "ly"), or a (y, z) move ("yz"). Between keys the value eases (smoothstep, or ease-out
# where the later key says "out"). The lengths and the phases are the old file's: the magazine leaves the grip from
# 0.05 to 0.33 s along the rake, and the new one goes in from 0.62 to 1.02 s with a small overshoot.
DROP = (-0.0814, -0.2046)
CLIPS = {
    "Fire": (7 / 60, {
        "slide": ("ly", [(0.0, 0.0), (0.05, -0.026, "out"), (7 / 60, 0.0)]),
        "trigger": ("rx", [(0.0, 0.0), (0.0333, -16.04), (0.05, -16.04), (7 / 60, 0.0)]),
    }),
    "Reload": (1.2, {
        "magRelease": ("lx", [(0.0, 0.0), (0.05, 0.0025), (0.233, 0.0025), (0.30, 0.0)]),
        "magazine": ("yz", [(0.0, (0.0, 0.0)), (0.05, (0.0, 0.0)), (0.333, DROP), (0.60, DROP),
                            (0.6167, (DROP[0] * 0.636, DROP[1] * 0.636)), (1.0167, (0.0, 0.0), "out"),
                            (1.05, (0.00074, 0.00186)), (1.1167, (0.0, 0.0)), (1.2, (0.0, 0.0))]),
    }),
    "Inspect": (2.0, {
        "slide": ("ly", [(0.0, 0.0), (0.283, 0.0), (0.55, -0.016), (1.333, -0.016), (1.40, 0.0), (2.0, 0.0)]),
    }),
    "SlideLock": (1 / 60, {
        "slide": ("ly", [(0.0, 0.0), (1 / 60, -0.026)]),
    }),
}


def _interp(keys: list, t: float):
    if t <= keys[0][0]:
        return keys[0][1]
    for k0, k1 in zip(keys, keys[1:]):
        (t0, v0), (t1, v1) = k0[:2], k1[:2]
        if t <= t1 + 1e-9:
            u = (t - t0) / max(1e-9, t1 - t0)
            s = ease_out(u) if len(k1) > 2 and k1[2] == "out" else ease(u)
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
                    elif kind == "lx":
                        loc = Vector((v, 0.0, 0.0))
                    elif kind == "ly":
                        loc = Vector((0.0, v, 0.0))
                    elif kind == "yz":
                        loc = Vector((0.0, v[0], v[1]))
                pb.rotation_quaternion = rot.to_quaternion()
                pb.location = loc
                pb.scale = Vector((1.0, 1.0, 1.0))
                for path in ("rotation_quaternion", "location", "scale"):
                    pb.keyframe_insert(path, frame=f)
        ad.action = None
        track = ad.nla_tracks.new()
        track.name = clip
        track.strips.new(clip, 0, act)
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)


# ------------------------------------------------------------------------------------------------------------ main

def build() -> None:
    hs.reset(FPS)
    for name, (colour, rough, metal) in MATERIALS.items():
        hs.material(name, colour, rough, metal)
    stipple_texture()
    arm = armature()
    # The panels first, so the joined frame keeps their texture coordinates.
    parts = [hs.finish(stipple_panels(), 0.0, 1), frame_upper(), frame_bits()]
    for ob in parts:
        print("  part %-12s %6d" % (ob.name, hs.tris(ob)))
    body = hs.join("Body", parts)
    body.parent = arm
    for ob, bone in ((slide(), "slide"), (trigger(), "trigger"), (magazine(), "magazine"),
                     (mag_release(), "magRelease")):
        hs.parent_to_bone(ob, arm, bone)
    for name, loc in EMPTIES.items():
        hs.empty(name, loc, arm)
    clips(arm)
    fig = figure_copy.make(FIGURE_TRIS)
    total = 0
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            n = hs.tris(ob)
            if not ob.name.startswith("Figure"):
                total += n
            print("  %-16s %6d triangles" % (ob.name, n))
    print("  in the hands: %d triangles; figure: %d" % (total, sum(hs.tris(o) for o in [fig] + list(fig.children))))
    hs.export(OUT, True)
    print("wrote", OUT)
    build_parts()


def build_parts() -> None:
    """The parts file: the silencer moved onto the new ThreadEnd, its origin on its mount; the laser and torch moved
    onto the rail mount; the magazines left as they are (tools/blender/parts/magazines.py builds them). Running it
    again changes nothing."""
    hs.reset(FPS)
    bpy.ops.import_scene.gltf(filepath=PARTS)
    sil = bpy.data.objects["muzzle_silencer"]
    sil.location += Vector(EMPTIES["ThreadEnd"]) - sil.matrix_world.translation
    # The laser and torch follow the rail mount (their roots' origins on it; the beams and figures with them).
    shift = Vector(RAIL_MOUNT) - bpy.data.objects["laser_redLaser"].matrix_world.translation
    for ob in bpy.data.objects:
        if ob.parent is None and ob.name.startswith(("laser_", "light_")):
            ob.location += shift
    for name, (colour, rough, metal) in MATERIALS.items():
        hs.material(name, colour, rough, metal)
    for ob in bpy.data.objects:
        if ob.type == "MESH" and ob.parent is None:
            print("  part %-26s %6d triangles" % (ob.name, hs.tris(ob)))
    hs.export(PARTS_OUT, False)
    print("wrote", PARTS_OUT)


if __name__ == "__main__":
    build()
