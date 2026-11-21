"""Subway's plant-room ventilation fan housing (SM4, model 29), from the owner's photos
(art/references/maps/subway/29-fan-housing: industrial air handling units): a long boxed unit of light grey panels in
a galvanised angle frame on a skid with fork pockets; a bank of four round fans in its +x end, each in a deep
galvanised shroud behind a bar guard (photos 4-6); two access doors with lever handles, an inspection window, a
louvred intake and a control box with an isolator on its front (-y); a recessed louvred damper in its -x end (photo 2);
lifting eyes on the top corners, and a corrugated flexible sleeve rising from the roof to a round flanged spigot. Its
blocks are 3 x 2.5 m and 2.2 m high.

SQ1 (owner, 2026-11-21: every Subway model in finer detail) rebuilt it at about twice the triangles from the photos'
parts: the frame is real galvanised angle (two legs, a shadow inside them) with corner caps, the panels stand proud in
their bays with screw rows, so every seam casts a line; each fan sits deep in its shroud behind a rolled bell mouth,
its blades, hub and struts inside and the guard's bars across the mouth, the end panel cut round all four; the doors
are proud leaves on knuckled hinges with D handles and rubber shut lines, the window glazed back in its rubber
surround; the louvre has its frame and blades in front of a dark mesh; the control box has its lid seam, hinges,
isolator and a conduit bent up to the roof in saddle clips; the -x end's damper sits in a recess, its blades inside
and a linkage on the side; the skid's runners are open channels with see-through fork pockets; the lifting eyes are
rings, and the roof outlet a corrugated sleeve between two band clamps.

Light grey and galvanised, dusty and scuffed, no writing or maker's marks.

Writes assets/models/props/fan_housing.glb, one vertex-coloured mesh filling its box exactly (x its length, y its
depth, z up; Godot: x across, y up, z deep).

Usage: python3 -I tools/blender/maps/fan_housing.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

BUDGET = 6000
LONG, DEEP, HIGH = 3.0, 2.5, 2.2
HL, HD = LONG * 0.5, DEEP * 0.5
SHIFT = 0.11         # the housing stands this far back in its box, its front's control box and isolator in front
BD = HD - SHIFT      # the housing's half-depth, built round y = 0 and moved back by SHIFT once built
SKID = 0.16          # the skid's height
TOP = 1.98           # the housing's roof
FRAME = 0.06         # the galvanised angles' width
ANGLE_T = 0.006      # their thickness
INSET = 0.035        # the panels sit this far inside the frame's outer faces
MID_Z = 1.07         # the +x end's middle rail, between the fans' rows
HOLE_R = 0.38        # a fan's hole in the end panel (its shroud's inside)
FAN_DEEP = 0.17      # how far back in its shroud a fan's blades turn
SEG = 24             # a fan shroud's segments
BAYS = (-0.35, 0.55)  # the long sides' bay posts
DAMPER = (-0.6, 0.6, 0.55, 1.55)  # the -x end's damper opening (y0, y1, z0, z1)

# The housing's own paints, named to their surface kinds (works_kit: "alu" brushed, "rubber", "glass", "cab_" satin).
wk.PAINT["fan_blade_alu"] = 0x9c9e9c
wk.PAINT["door_rubber"] = 0x2c2c2c
wk.PAINT["galv_clip"] = 0x9a9c9c


def angle(k: wk.Kit, axis: str, a0: float, a1: float, u: float, v: float, du: float, dv: float, mat: str = "galv",
          f: float = FRAME, t: float = ANGLE_T) -> None:
    """A steel angle along `axis` from a0 to a1, its outside corner at (u, v) in the other two axes (x: (y, z), y:
    (x, z), z: (x, y)), its legs `f` wide running towards du, dv (+-1), `t` thick."""
    k.prism([(u, v), (u + du * f, v), (u + du * f, v + dv * t), (u + du * t, v + dv * t), (u + du * t, v + dv * f),
             (u, v + dv * f)], axis, a0, a1, mat)


def frame(k: wk.Kit) -> None:
    """The galvanised angle frame: corner posts, top and bottom rails round the box, moulded caps on the top corners,
    lifting eyes on them; flat posts between the long sides' bays, the +x end's middle post and rail."""
    f = FRAME
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            angle(k, "z", SKID, TOP - 0.025, sx * HL, sy * BD, -sx, -sy)
            # the corner cap and its lifting eye: a moulded block, a ring standing on it across the corner
            x0, x1 = sorted((sx * HL, sx * (HL - 0.09)))
            y0, y1 = sorted((sy * BD, sy * (BD - 0.09)))
            k.blk((x0, y0, TOP - 0.025), (x1, y1, TOP + 0.012), "cab_dark")
            k.tube([(-0.008, 0.045), (0.008, 0.045)], [(-0.008, 0.024), (0.008, 0.024)], "steel_bare", segments=8,
                   centre=(sx * (HL - 0.045), sy * (BD - 0.045), TOP + 0.05), axis="x")
            k.blk((sx * (HL - 0.045) - 0.014, sy * (BD - 0.045) - 0.022, TOP + 0.012),
                  (sx * (HL - 0.045) + 0.014, sy * (BD - 0.045) + 0.022, TOP + 0.03), "steel_bare")
    for z, dz in ((SKID, 1.0), (TOP, -1.0)):  # top and bottom rails, their legs on the face and over the top
        for sy in (-1.0, 1.0):
            angle(k, "x", -HL + 0.09, HL - 0.09, sy * BD, z, -sy, dz)
        for sx in (-1.0, 1.0):
            angle(k, "y", -BD + 0.09, BD - 0.09, sx * HL, z, -sx, dz)
    for x in BAYS:  # flat posts dividing the long sides into bays, a screw row down each
        for sy in (-1.0, 1.0):
            y0, y1 = sorted((sy * (BD - 0.006), sy * (BD - INSET)))  # inside the angles' faces: the screws too
            k.blk((x - 0.035, y0, SKID + f), (x + 0.035, y1, TOP - f), "galv_dark")
            k.bolts([(x, sy * (BD - 0.006), z) for z in (0.45, 0.85, 1.25, 1.65)], 0.009, 0.005,
                    "y" if sy > 0 else "-y", "steel_bare", seg=4)
    k.blk((HL - INSET, -0.035, SKID + f), (HL, 0.035, TOP - f), "galv_dark")  # the end's middle post
    k.blk((HL - INSET, -BD + f, MID_Z - 0.035), (HL, BD - f, MID_Z + 0.035), "galv_dark")  # and its middle rail


def skid(k: wk.Kit) -> None:
    """The base: channel runners along the long sides, open outwards, with box-section fork pockets right through
    (you see through them), cross members at the ends, a deck plate."""
    t = 0.012
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * BD, sy * (BD - 0.12)))
        k.blk((-HL, ya, 0.0), (HL, yb, t), "galv")                    # the bottom flange
        k.blk((-HL, ya, SKID - t), (HL, yb, SKID), "galv")            # the top flange
        yw0, yw1 = sorted((sy * (BD - 0.1), sy * (BD - 0.12)))
        for xa, xb in ((-HL, -0.95), (-0.55, 0.55), (0.95, HL)):      # the web, cut for the fork pockets
            k.blk((xa, yw0, t), (xb, yw1, SKID - t), "galv")
    for px in (-0.75, 0.75):  # the fork pockets: box sections across the skid, open at both ends
        x0, x1, z0, z1 = px - 0.2, px + 0.2, t, SKID - t
        for lo, hi in (((x0, z0), (x1, z0 + 0.008)), ((x0, z1 - 0.008), (x1, z1)), ((x0, z0), (x0 + 0.008, z1)),
                       ((x1 - 0.008, z0), (x1, z1))):
            k.blk((lo[0], -BD + 0.1, lo[1]), (hi[0], BD - 0.1, hi[1]), "galv_dark")
    for x in (-HL, HL - 0.1):
        k.blk((x, -BD + 0.12, 0.0), (x + 0.1, BD - 0.12, SKID - t), "galv_dark")
    k.blk((-HL + 0.1, -BD + 0.12, SKID - t), (HL - 0.1, BD - 0.12, SKID), "galv_dark")


def body(k: wk.Kit) -> None:
    """The panel box (its ends left open for the fan and damper panels), the roof sheet with standing seams across,
    and proud panels in the back's bays with screw rows."""
    k.panel((-HL + INSET, -BD + INSET, SKID), (HL - INSET, BD - INSET, TOP - 0.01), "fan_panel", step=0.5,
            skip=("-z", "+x", "-x"))
    k.blk((-HL + FRAME, -BD + FRAME, TOP - 0.02), (HL - FRAME, BD - FRAME, TOP - 0.004), "fan_panel")
    for x in (-0.75, 0.0, 0.75):  # the roof's standing seams
        k.blk((x - 0.012, -BD + FRAME, TOP - 0.004), (x + 0.012, BD - FRAME, TOP + 0.02), "fan_panel")
    y = BD - INSET
    edges = [-HL + FRAME] + list(BAYS) + [HL - FRAME]
    for xa, xb in zip(edges, edges[1:]):  # the back's panels, each proud of the box and screwed round its edge
        x0, x1 = xa + 0.05, xb - 0.05
        k.blk((x0, y, SKID + FRAME + 0.03), (x1, y + 0.006, TOP - FRAME - 0.03), "fan_panel")
        pts = [(x, y + 0.006, z) for x in (x0 + 0.03, x1 - 0.03) for z in (0.4, 0.8, 1.2, 1.6)]
        pts += [((x0 + x1) * 0.5, y + 0.006, z) for z in (SKID + FRAME + 0.06, TOP - FRAME - 0.06)]
        k.bolts(pts, 0.008, 0.004, "y", "steel_bare", seg=4)


def cell_ring(yc: float, zc: float, hy: float, hz: float, x: float, n_side: int = 6) -> tuple:
    """The +x end panel's piece round one fan: points round the cell's rectangle (its corners among them) and, for
    each, the hole's point at its angle."""
    rect = []
    corners = [(hy, -hz), (hy, hz), (-hy, hz), (-hy, -hz)]
    for i in range(4):
        a, b = corners[i], corners[(i + 1) % 4]
        for j in range(n_side):
            u = j / n_side
            rect.append((a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u))
    hole = []
    for dy, dz in rect:
        a = math.atan2(dz, dy)
        hole.append((x, yc + HOLE_R * math.cos(a), zc + HOLE_R * math.sin(a)))
    return [(x, yc + dy, zc + dz) for dy, dz in rect], hole


def fan(k: wk.Kit, yc: float, zc: float, hy: float, hz: float) -> None:
    """One fan in the +x end: its piece of the end panel cut round a hole, a galvanised shroud running back into the
    housing to the fan, a rolled bell mouth round the hole, the dark motor plate at the back with the hub, struts and
    pitched blades in front of it, and the guard's bars across the mouth."""
    x = HL - INSET
    outer, hole = cell_ring(yc, zc, hy, hz, x)
    bm = k.bm
    vo = [bm.verts.new(Vector(p)) for p in outer]
    vh = [bm.verts.new(Vector(p)) for p in hole]
    n = len(vo)
    faces = [bm.faces.new((vo[i], vo[(i + 1) % n], vh[(i + 1) % n], vh[i])) for i in range(n)]
    for f in faces:
        f.normal_update()
        if f.normal.x < 0.0:
            f.normal_flip()
    k._faces(faces, "fan_panel")
    xb = x - FAN_DEEP
    k.lathe([(x, HOLE_R), (xb - 0.02, HOLE_R)], "galv", segments=SEG, centre=(0.0, yc, zc), axis="x", cap=False)
    k.lathe([(x, HOLE_R), (HL - 0.012, HOLE_R + 0.012), (HL - 0.004, HOLE_R + 0.04), (x + 0.002, HOLE_R + 0.055)],
            "galv", segments=SEG, centre=(0.0, yc, zc), axis="x", cap=False)  # the bell mouth
    disc = [(xb - 0.02, yc + HOLE_R * math.cos(2 * math.pi * i / SEG), zc + HOLE_R * math.sin(2 * math.pi * i / SEG))
            for i in range(SEG)]
    k.fan(disc, (1.0, 0.0, 0.0), "grille")
    k.lathe([(xb - 0.02, 0.13), (xb + 0.03, 0.13), (xb + 0.06, 0.1), (xb + 0.075, 0.0)], "cab_dark", segments=10,
            centre=(0.0, yc, zc), axis="x", cap=False)  # the motor and its hub
    for i in range(3):  # the motor's struts out to the shroud
        a = 2 * math.pi * i / 3 + math.pi / 2
        k.sqbar((xb - 0.01, yc + 0.12 * math.cos(a), zc + 0.12 * math.sin(a)),
                (xb - 0.01, yc + (HOLE_R - 0.005) * math.cos(a), zc + (HOLE_R - 0.005) * math.sin(a)), 0.02, "galv",
                h=0.012)
    for i in range(6):  # the blades, pitched, between the hub and the shroud
        a = 2 * math.pi * i / 6 + 0.3
        b = a + 0.5
        r0, r1 = 0.1, HOLE_R - 0.025
        k.quad([(xb + 0.05, yc + r0 * math.cos(a), zc + r0 * math.sin(a)),
                (xb + 0.01, yc + r0 * math.cos(b), zc + r0 * math.sin(b)),
                (xb + 0.01, yc + r1 * math.cos(b + 0.22), zc + r1 * math.sin(b + 0.22)),
                (xb + 0.055, yc + r1 * math.cos(a + 0.12), zc + r1 * math.sin(a + 0.12))], "fan_blade_alu")
    gx = HL - 0.009
    for i in range(9):  # the guard's bars across the mouth, and one upright through the middle
        dz = (i - 4) * HOLE_R / 4.6
        half = math.sqrt(max(0.0, (HOLE_R + 0.02) ** 2 - dz * dz))
        k.sqbar((gx, yc - half, zc + dz), (gx, yc + half, zc + dz), 0.012, "steel_bare", h=0.008)
    k.sqbar((gx - 0.01, yc, zc - HOLE_R - 0.02), (gx - 0.01, yc, zc + HOLE_R + 0.02), 0.014, "steel_bare", h=0.01)


def fans(k: wk.Kit) -> None:
    """The +x end: a fan in each quarter of it, between the middle post and rail."""
    ys = (-BD + INSET, 0.0, BD - INSET)
    zs = (SKID, MID_Z, TOP - 0.01)
    for i in range(2):
        for j in range(2):
            yc, zc = (ys[i] + ys[i + 1]) * 0.5, (zs[j] + zs[j + 1]) * 0.5
            fan(k, yc, zc, (ys[i + 1] - ys[i]) * 0.5, (zs[j + 1] - zs[j]) * 0.5)


def damper(k: wk.Kit) -> None:
    """The -x end: its panel round a recessed intake, the recess's galvanised walls back to a dark filter face, the
    damper's blades pitched across it, a flanged frame round its mouth, the linkage's actuator on the side, and a
    filter door beside it."""
    x = -HL + INSET
    y0, y1, z0, z1 = DAMPER
    ya, yb, za, zb = -BD + INSET, BD - INSET, SKID, TOP - 0.01
    for lo, hi in (((ya, za), (y0, zb)), ((y1, za), (yb, zb)), ((y0, za), (y1, z0)), ((y0, z1), (y1, zb))):
        k.blk((x, lo[0], lo[1]), (x + 0.004, hi[0], hi[1]), "fan_panel")
    d = 0.16  # the recess's depth
    k.loft([[(x + dd, y0, z0), (x + dd, y1, z0), (x + dd, y1, z1), (x + dd, y0, z1)] for dd in (0.0, d)], "galv_dark",
           cap0=False, cap1=False)
    k.quad([(x + d, y0, z0), (x + d, y0, z1), (x + d, y1, z1), (x + d, y1, z0)], "grille")
    for i in range(7):  # the blades, each a pitched flat across the opening
        z = z0 + 0.08 + (z1 - z0 - 0.16) * i / 6
        k.prism([(x + 0.03, z - 0.05), (x + 0.04, z - 0.055), (x + 0.11, z + 0.03), (x + 0.1, z + 0.035)], "y",
                y0 + 0.002, y1 - 0.002, "galv")
    k.sqbar((x + 0.06, y0 + 0.08, z0 + 0.04), (x + 0.06, y0 + 0.08, z1 - 0.04), 0.016, "steel_bare")  # its link rod
    f = 0.05  # the flanged frame round the mouth
    for lo, hi in (((y0 - f, z0 - f), (y0, z1 + f)), ((y1, z0 - f), (y1 + f, z1 + f)), ((y0, z0 - f), (y1, z0)),
                   ((y0, z1), (y1, z1 + f))):
        k.blk((-HL + 0.004, lo[0], lo[1]), (x, hi[0], hi[1]), "galv")
    k.bolts([(-HL + 0.004, y, z) for y in (y0 - f * 0.5, y1 + f * 0.5) for z in (z0 + 0.1, (z0 + z1) * 0.5, z1 - 0.1)],
            0.009, 0.004, "-x", "steel_bare", seg=4)
    # the actuator beside it: a small grey box, its shaft and arm to the link rod
    k.blk((-HL + 0.006, y1 + f + 0.04, 1.0), (x, y1 + f + 0.2, 1.16), "cab_dark")
    k.sqbar((-HL + 0.02, y1 + f + 0.05, 1.08), (-HL + 0.02, y1 - 0.05, 1.08), 0.018, "steel_bare", h=0.01)
    # the filter door on the -y side of it: a proud leaf, two quarter-turn latches
    k.blk((-HL + 0.012, ya + 0.06, za + 0.1), (x, y0 - f - 0.06, zb - 0.1), "fan_panel")
    for z in (0.6, 1.5):
        k.cyl((-HL + 0.012, (ya + y0 - f) * 0.5, z), 0.025, -0.01, "door_rubber", seg=6, axis="x")


def hinge(k: wk.Kit, x: float, y: float, z: float) -> None:
    """A door hinge: three knuckles on a pin, its leaf on the door."""
    for i in range(3):
        k.cyl((x, y, z - 0.075 + i * 0.052), 0.013, 0.046, "steel_bare" if i != 1 else "galv_dark", seg=6)
    k.blk((x + 0.008, y - 0.002, z - 0.07), (x + 0.05, y + 0.006, z + 0.07), "galv_dark")


def front(k: wk.Kit) -> None:
    """The -y side: two access doors (proud leaves on knuckled hinges, rubber shut lines, D handles), the inspection
    window, the louvred intake in the third bay, the control box with its isolator and conduit, a plain warning
    plate."""
    y = -BD + INSET
    for x0, x1 in ((-0.92, BAYS[0] - 0.05), (BAYS[0] + 0.05, BAYS[1] - 0.05)):
        z0, z1 = SKID + FRAME + 0.03, TOP - FRAME - 0.03
        k.blk((x0 - 0.008, y - 0.002, z0 - 0.008), (x1 + 0.008, y, z1 + 0.008), "door_rubber")  # the seal
        k.blk((x0, y - 0.012, z0), (x1, y - 0.002, z1), "fan_panel")                          # the leaf
        for z in (0.5, 1.65):
            hinge(k, x0 - 0.01, y - 0.02, z)
        hx = x1 - 0.07  # the D handle on its plate, a lock under it
        k.blk((hx - 0.025, y - 0.018, 0.98), (hx + 0.025, y - 0.012, 1.2), "door_rubber")
        for z in (1.0, 1.18):
            k.sqbar((hx, y - 0.018, z), (hx, y - 0.05, z), 0.018, "door_rubber")
        k.sqbar((hx, y - 0.05, 0.99), (hx, y - 0.05, 1.19), 0.02, "door_rubber")
        k.cyl((hx, y - 0.012, 0.92), 0.014, -0.008, "steel_bare", seg=6, axis="y")
    # the inspection window in the right door: a rubber surround and the glass set back in it
    wx, wz, ww, wh = (BAYS[0] + BAYS[1]) * 0.5, 1.45, 0.17, 0.12
    yl = y - 0.012
    k.blk((wx - ww, yl - 0.01, wz - wh), (wx + ww, yl, wz + wh), "door_rubber")
    k.quad([(wx - ww + 0.025, yl - 0.0105, wz - wh + 0.025), (wx + ww - 0.025, yl - 0.0105, wz - wh + 0.025),
            (wx + ww - 0.025, yl - 0.0105, wz + wh - 0.025), (wx - ww + 0.025, yl - 0.0105, wz + wh - 0.025)],
           "door_rubber")
    k.quad([(wx - ww + 0.03, yl - 0.011, wz - wh + 0.03), (wx + ww - 0.03, yl - 0.011, wz - wh + 0.03),
            (wx + ww - 0.03, yl - 0.011, wz + wh - 0.03), (wx - ww + 0.03, yl - 0.011, wz + wh - 0.03)], "glass")
    # the louvred intake in the third bay: a deep galvanised frame, a dark mesh behind, pitched blades
    ix0, ix1, iz0, iz1 = BAYS[1] + 0.12, HL - FRAME - 0.1, 0.45, 1.75
    f = 0.04
    for lo, hi in (((ix0 - f, iz0 - f), (ix0, iz1 + f)), ((ix1, iz0 - f), (ix1 + f, iz1 + f)),
                   ((ix0, iz0 - f), (ix1, iz0)), ((ix0, iz1), (ix1, iz1 + f))):
        k.blk((lo[0], y - 0.07, lo[1]), (hi[0], y, hi[1]), "galv")
    k.quad([(ix0, y - 0.002, iz0), (ix1, y - 0.002, iz0), (ix1, y - 0.002, iz1), (ix0, y - 0.002, iz1)], "grille")
    n = 12
    for i in range(n):
        z = iz0 + 0.06 + (iz1 - iz0 - 0.1) * i / (n - 1)
        k.prism([(y - 0.006, z), (y - 0.062, z - 0.045), (y - 0.062, z - 0.033), (y - 0.006, z + 0.012)], "x", ix0,
                ix1, "galv")
    # the control box on the fixed panel left of the doors: its lid, hinges, isolator plate and rotary handle, a
    # gland under it, and its conduit up the panel in saddle clips, out round the top rail and over to the roof
    cx0, cx1, cz0, cz1 = -1.37, -1.02, 1.1, 1.58
    yb = y - 0.012
    cxm = (cx0 + cx1) * 0.5
    k.blk((cx0, yb - 0.17, cz0), (cx1, y, cz1), "cab_grey")
    k.blk((cx0 + 0.012, yb - 0.176, cz0 + 0.012), (cx1 - 0.012, yb - 0.17, cz1 - 0.012), "cab_grey")  # its lid
    for z in (cz0 + 0.08, cz1 - 0.08):
        k.cyl((cx0 - 0.004, yb - 0.17, z - 0.03), 0.008, 0.06, "cab_dark", seg=6)
    k.blk((cxm - 0.05, yb - 0.182, 1.28), (cxm + 0.05, yb - 0.176, 1.38), "label_yellow")  # the isolator's plate
    k.cyl((cxm, yb - 0.182, 1.33), 0.032, -0.02, "hazard_black", seg=8, axis="y")       # and its handle
    k.blk((cxm - 0.011, yb - 0.243, 1.29), (cxm + 0.011, yb - 0.2, 1.37), "hazard_black")
    k.cyl((cxm, yb - 0.085, cz0), 0.022, -0.04, "door_rubber", seg=6)  # a cable gland under it
    xc, yc = cx1 - 0.07, y - 0.03
    conduit(k, [Vector((xc, yc, cz1)), Vector((xc, yc, TOP - 0.12)), Vector((xc, -BD - 0.03, TOP - 0.06)),
                Vector((xc, -BD - 0.03, TOP + 0.035)), Vector((xc, -BD + 0.3, TOP + 0.035)),
                Vector((xc, -BD + 0.3, TOP - 0.004))], 0.02)
    k.blk((xc - 0.035, yc - 0.024, 1.75), (xc + 0.035, y, 1.78), "galv_clip")  # saddle clips
    k.blk((xc - 0.035, -BD + 0.15, TOP - 0.004), (xc + 0.035, -BD + 0.18, TOP + 0.06), "galv_clip")
    s, wxz = 0.13, (-0.66, 1.55)  # a plain warning triangle
    k.quad([(wxz[0] - s * 0.5, yl - 0.001, wxz[1]), (wxz[0] + s * 0.5, yl - 0.001, wxz[1]),
            (wxz[0], yl - 0.001, wxz[1] + s * 0.87)], "hazard_black")
    t = s * 0.72
    k.quad([(wxz[0] - t * 0.5, yl - 0.002, wxz[1] + (s - t) * 0.3), (wxz[0] + t * 0.5, yl - 0.002,
            wxz[1] + (s - t) * 0.3), (wxz[0], yl - 0.002, wxz[1] + (s - t) * 0.3 + t * 0.87)], "label_yellow")


def conduit(k: wk.Kit, pts: list, r: float, seg: int = 6) -> None:
    """A round conduit along the polyline `pts` (Vectors), each inner corner bent round, capped."""
    path = [pts[0]]
    for i in range(1, len(pts) - 1):
        a, p, b = pts[i - 1], pts[i], pts[i + 1]
        p0 = p + (a - p).normalized() * min(0.05, (p - a).length * 0.45)
        p1 = p + (b - p).normalized() * min(0.05, (b - p).length * 0.45)
        path += [p0 * (1 - u) ** 2 + p * 2 * u * (1 - u) + p1 * u * u for u in (0.0, 0.5, 1.0)]
    path.append(pts[-1])
    rings, nrm = [], None
    for i, p in enumerate(path):
        t = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        nrm = t.cross(Vector((1.0, 0.0, 0.0))).normalized() if nrm is None else (nrm - t * nrm.dot(t)).normalized()
        bi = t.cross(nrm)
        rings.append([p + (nrm * math.cos(2 * math.pi * j / seg) + bi * math.sin(2 * math.pi * j / seg)) * r
                      for j in range(seg)])
    k.loft(rings, "galv_clip")


def roof(k: wk.Kit) -> None:
    """The roof's outlet at the -x end: a square flanged base on the roof, a short transition to round, a corrugated
    flexible sleeve between two band clamps and a flanged spigot at the top (the box leaves 0.22 m over the roof)."""
    cx, cy = -0.7, 0.2
    sq, r = 0.3, 0.21
    n = 16
    base = []
    for i in range(n):  # a square ring with as many points as the round one, so the loft twists cleanly
        a = 2 * math.pi * (i + 0.5) / n
        c, s = math.cos(a), math.sin(a)
        m = max(abs(c), abs(s))
        base.append((cx + sq * c / m, cy + sq * s / m, TOP))
    mid = [(p[0], p[1], TOP + 0.03) for p in base]

    def ring(rr: float, z: float) -> list:
        return [(cx + rr * math.cos(2 * math.pi * (i + 0.5) / n), cy + rr * math.sin(2 * math.pi * (i + 0.5) / n), z)
                for i in range(n)]
    k.loft([base, mid, ring(r + 0.01, TOP + 0.07)], "galv", cap0=False, cap1=False)
    # the sleeve: five corrugations between its clamps
    z0, z1 = TOP + 0.085, HIGH - 0.075
    rings = [ring(r + 0.012, TOP + 0.07), ring(r + 0.012, z0)]
    m = 10
    for i in range(1, m):
        rings.append(ring(r + (0.012 if i % 2 else -0.004), z0 + (z1 - z0) * i / m))
    rings += [ring(r + 0.012, z1), ring(r + 0.012, z1 + 0.015)]
    k.loft(rings, "duct", cap0=False, cap1=False)
    for z in (TOP + 0.07, z1):  # the band clamps
        k.lathe([(z, r + 0.012), (z, r + 0.02), (z + 0.015, r + 0.02), (z + 0.015, r + 0.012)], "steel_bare",
                segments=n, centre=(cx, cy, 0.0), axis="z", start=math.pi / n, cap=False)
    zs = z1 + 0.015
    k.lathe([(zs, r + 0.012), (zs, r + 0.04), (HIGH - 0.02, r + 0.04), (HIGH - 0.02, r + 0.005),
             (HIGH, r - 0.005)], "galv", segments=n, centre=(cx, cy, 0.0), axis="z", start=math.pi / n, cap=False)
    disc = [(cx + (r - 0.005) * math.cos(2 * math.pi * (i + 0.5) / n),
             cy + (r - 0.005) * math.sin(2 * math.pi * (i + 0.5) / n), HIGH - 0.04) for i in range(n)]
    k.fan(disc, (0.0, 0.0, 1.0), "grille")  # the spigot's blanking: dark inside
    k.bolts([(cx + (r + 0.025) * math.cos(a), cy + (r + 0.025) * math.sin(a), HIGH - 0.02)
             for a in (2 * math.pi * i / 8 for i in range(8))], 0.01, 0.008, "z", "steel_bare", seg=4)


def build() -> object:
    k = wk.Kit("fan_housing")
    skid(k)
    k.mark("skid")
    body(k)
    k.mark("body")
    frame(k)
    k.mark("frame")
    fans(k)
    k.mark("fans")
    damper(k)
    k.mark("damper")
    front(k)
    k.mark("front")
    roof(k)
    k.mark("roof")
    ob = k.build()
    ob.data.transform(Matrix.Translation((0.0, SHIFT, 0.0)))
    return ob


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint in ("fan_panel", "cab_grey", "cab_dark"):
        col = wt.mix(c, wk.lin(wk.GRIME), 0.2 * wt.smooth(0.55, 0.8, wt.fbm(p, 0.2, 31)))  # scuffs, handprints
        return wk.grime(p, n, col, floor=SKID, seed=21)
    if paint in ("galv", "galv_dark", "galv_clip"):
        col = wk.rusty(p, n, c, seed=33, amount=0.18, streaks=False)  # white rust spots on old galvanising
        return wk.grime(p, n, col, seed=27, amount=0.8)
    if paint == "grille":
        return wt.mix(c, wk.lin(wk.SOOT), 0.3 * wt.fbm(p, 0.2, 35))
    if paint == "fan_blade_alu":  # the blades' leading edges dark with the dust they've thrown
        return wt.mix(c, wk.lin(wk.SOOT), 0.35 * wt.fbm(p, 0.1, 37))
    return wk.grime(p, n, c, seed=4, amount=0.6)


def main() -> None:
    wk.check_colours(list(wk.PAINT))
    wk.reset()
    ob = build()
    wk.finish(ob, (-HL, -HD, 0.0), (HL, HD, HIGH))
    wk.bake(ob, weather, jitter={"fan_panel": 0.03, "galv": 0.04})
    wk.write(ob, "fan_housing", BUDGET)
    if "--render" in sys.argv:
        out = sys.argv[sys.argv.index("--render") + 1]
        wk.render(wk.quarter_views(LONG, DEEP, HIGH), out, "SM4 fan housing (Subway map prop, 3 x 2.5 x 2.2 m)")


if __name__ == "__main__":
    main()
