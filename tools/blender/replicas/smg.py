"""The Compact SMG's model (CS1, 2026-11-10), from the owner's photos of a classic roller-delayed 9 mm sub-machine gun
(art/references/smg/ in the project files: a stamped steel receiver with the cocking tube over the barrel, a drum rear
sight, a hooded ring front sight, a slim polymer handguard, a polymer trigger group and pistol grip, a curved steel
magazine and a collapsed two-strut stock; the owner's magazine photos for the magazine). Generic: no maker's marks,
no selector pictograms, no calibre or law-enforcement stamps.

The side outline is traced from the owner's side photo (4-side-right.jpg, the rifle's right side with the stock
collapsed; 2.33 px per mm, its 550 mm collapsed length) and lined up so its grip's front, just under the trigger
guard, sits where the AEG Rifle's does at the hand's height (as sniper.py): the figures' rifle hold lands on this grip
too. The owner (2026-11-10: "You can add small rails for attachments") asked for small rails: a short top rail on a
low mount over the receiver for the optics, and a short rail on each side of the handguard for the laser (left) and
the torch (right).

It keeps the replica contract (docs/CC0_ASSETS.md › Replica models): the armature CompactSMG with the bones root,
trigger, selector, magRelease, chargingHandle, rearSight, frontSight and magazine; the clips Fire, Reload, Selector and
Inspect (the cocking handle pulled back, flicked up into its notch, then slapped down and home); the empties Muzzle,
BarrelEnd, FrontSight, RearSight, MagWell, OpticMount, GripMount and TorchMount; the meshes Body, Trigger, Selector,
MagRelease, ChargingHandle, Magazine, FrontSightLeaf (the hood and post), RearSightLeaf (the drum and its base),
FlashHider (the thread cap, hidden by the silencer) and Figure (the figures' cut-down copy); the paintable materials
Body, Furniture (the polymer handguard, trigger group, grip and stock), Detail, Accent and Metal, plus Rubber and BB.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/replicas/smg.py <repo root>

It writes assets/models/replicas/smg.glb (BL_OUT overrides) and the parts file assets/models/replicaParts/smg.glb
(BL_PARTS_OUT): the AEG Rifle's optics, laser, torch and silencer moved onto this one's rails and barrel (no barrels,
grips or magazines: its barrel is fixed, it has no under rail and its magazines are its own).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import figure_copy  # noqa: E402
import hardsurface as hs  # noqa: E402
import wear  # noqa: E402

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
OUT = os.environ.get("BL_OUT") or os.path.join(ROOT, "assets/models/replicas/smg.glb")
AEG_PARTS = os.path.join(ROOT, "assets/models/replicaParts/aeg.glb")
PARTS_OUT = os.environ.get("BL_PARTS_OUT") or os.path.join(ROOT, "assets/models/replicaParts/smg.glb")
ARMATURE = "CompactSMG"
FPS = 60
# The figures' copy (figure_copy.py): triangles per piece, 3,000 in all (the replica budget on a figure).
FIGURE_TRIS = {"Figure": 2400, "Magazine": 280, "FlashHider": 100, "Sights": 220}

# ------------------------------------------------------------------------------------------------------ the photo

# The side photo: px along it (butt at 13, muzzle at 1306), py down it. Blender: +Y forward, +Z up, +X right. The
# photo shows the right side, muzzle to the right, so px grows forward.
PX_PER_M = 2330.0
ORIGIN_PX = (540.9, 333.45)


def Y(px: float) -> float:
    return (px - ORIGIN_PX[0]) / PX_PER_M


def Z(py: float) -> float:
    return (ORIGIN_PX[1] - py) / PX_PER_M


def smoothstep(a: float, b: float, x: float) -> float:
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def pts(trace: list) -> list:
    """Photo points (px, py[, r px]) as fillet corners (y, z, r m)."""
    return [(Y(p[0]), Z(p[1]), (p[2] / PX_PER_M) if len(p) > 2 else 0.0) for p in trace]


def at(table: list, x: float) -> float:
    """A traced line (x, value) read at x, straight between its points."""
    if x <= table[0][0]:
        return table[0][1]
    for (x0, v0), (x1, v1) in zip(table, table[1:]):
        if x <= x1:
            return v0 + (v1 - v0) * (x - x0) / max(1e-9, x1 - x0)
    return table[-1][1]


# ------------------------------------------------------------------------------------------------------ measures

BORE_PY = 159.0
BORE_Z = Z(BORE_PY)
# The receiver: its back (the end cap), its front (where the handguard starts), its top and its round roof's foot.
RX_PX = (243.0, 790.0)
RX_TOP_PY = 73.0
RX_ROOF_PY = 108.0
RX_BOTTOM_PY = 212.0
RX_HW = 0.0155
# The side grooves the stock's struts slide in, and the struts.
GROOVE_PY = (151.0, 172.0)
GROOVE_DEPTH = 0.0036
# The ejection port on the right (its ends, its top and bottom).
PORT_PX = (632.0, 716.0)
PORT_PY = (121.0, 149.0)
STRUT_R = 0.0036
# The cocking tube over the barrel, from the receiver to the front sight.
TUBE_PY = 93.5
TUBE_R = 0.0080
TUBE_PX = (785.0, 1186.0)
# The cocking handle: where it rests (forward), how far it pulls back, and its slot's ends on the tube's left.
HANDLE_PX = 1005.0
HANDLE_TRAVEL = 0.048
SLOT_PX = (885.0, 1022.0)
# The top rail's low mount over the receiver (the owner's small rails), the rail's base and top: low, so aimed with
# the iron sights its top stays 5 mm under the sight line and the front post shows over it.
TOP_RAIL_PX = (482.0, 742.0)
RAIL_BASE = Z(RX_TOP_PY) + 0.0010
RAIL_H = 0.0068
RAIL_TOP = RAIL_BASE + RAIL_H
# The handguard: its ends, its top, its bottom line (back to front), its half width, and its side rails.
# Its front butts against the front sight block (the owner: no gap there), its back against the receiver.
HG_PX = (791.0, 1189.0)
HG_TOP_PY = 110.0
HG_BOTTOM = [(791.0, 238.5), (1172.0, 196.5), (1189.0, 194.6)]
HG_HW = 0.0185
HG_SWELL = 0.0010
HG_FLARE = 0.0016
# Toward the front, so the left hand holds the handguard bare behind them.
SIDE_RAIL_PX = (992.0, 1140.0)
SIDE_RAIL_PY = 164.0
# The front sight's block round the tube's end and the barrel, its hood ring and post.
FS_PX = (1186.0, 1222.0)
FS_PY = (76.0, 188.0)
HOOD_PX = 1203.0
HOOD_PY = 35.0
HOOD_R = (0.0098, 0.0128)
HOOD_LEN = 0.0070
SIGHT_Z = Z(35.0)
# The barrel's lug ring, the thread cap (FlashHider) and the muzzle.
BARREL_END_PX = 1236.0
MUZZLE_PX = 1306.0
# The rear sight: the drum's centre, radius, half height and its tilt forward from upright (degrees).
DRUM_PX = (428.0, 44.0)
DRUM_R = 0.0100
DRUM_HH = 0.0095
DRUM_TILT = 10.0
# The drum's aperture: opened up to a ghost ring (fun over simulation: aimed, the whole front hood and its post show
# inside it, with the drum's rim round them).
APERTURE_R = 0.0055
REAR_PX = 428.0
# The trigger group: its half width, the grip's, and the guard's.
# The trigger housing as wide as the receiver: the two are one piece with the grip (the owner), flush, no seam.
LOWER_HW = RX_HW
GRIP_HW = 0.0150
GUARD_HW = 0.0068
# The magazine: half width, its top in the well and where it sits in the well's foot.
MAG_HW = 0.0110
MAG_WELL_HW = 0.0150
MAG_TOP = (0.0, Y(737.0), Z(285.0))
# The stock: the butt's half width at its arm (over the struts' ends) and at its pad, wider, and where the pad starts.
BUTT_HW = 0.0185
PAD_HW = 0.0235
PAD_PX = 58.0
# The pad's sides bow out this much more at its middle (PAD_MID_PY) than PAD_HALF above and below it.
PAD_BOW = 0.0025
PAD_MID_PY = 245.0
PAD_HALF = 0.055

TORCH_Y = Y(sum(SIDE_RAIL_PX) / 2.0 + 15.0)
LASER_Y = Y(sum(SIDE_RAIL_PX) / 2.0 - 15.0)
SIDE_RAIL_TOP_X = HG_HW - 0.0006 + RAIL_H

EMPTIES = {
    "Muzzle": (0.0, Y(MUZZLE_PX), BORE_Z), "BarrelEnd": (0.0, Y(BARREL_END_PX), BORE_Z),
    "FrontSight": (0.0, Y(HOOD_PX), SIGHT_Z), "RearSight": (0.0, Y(REAR_PX), SIGHT_Z),
    "MagWell": MAG_TOP, "OpticMount": (0.0, Y(615.0), RAIL_TOP),
    "GripMount": (0.0, Y(1000.0), Z(216.0)),
    "TorchMount": (SIDE_RAIL_TOP_X, TORCH_Y, Z(SIDE_RAIL_PY)),
}

BONES = {
    "root": (0.0, 0.0, 0.0),
    "trigger": (0.0, Y(536.0), Z(313.0)),
    "selector": (-LOWER_HW, Y(492.0), Z(236.0)),
    "magRelease": (0.0, Y(672.0), Z(308.0)),
    "chargingHandle": (0.0, Y(HANDLE_PX), Z(TUBE_PY)),
    "rearSight": (0.0, Y(REAR_PX), Z(RX_TOP_PY)),
    "frontSight": (0.0, Y(HOOD_PX), Z(FS_PY[0])),
    "magazine": MAG_TOP,
}
BONE_LENGTH = 0.0200

# The AEG Rifle's mounts its parts file's parts sit on (aeg.py EMPTIES; its laser on the left rail), which
# build_parts moves onto this one's.
AEG_MOUNTS = {
    "optic_": (0.0, 0.025, 0.0735), "light_": (0.0259, 0.195, 0.04725), "laser_": (-0.0259, 0.132, 0.04725),
    "muzzle_": (0.0, 0.339, 0.044),
}
PART_MOUNTS = {
    "optic_": EMPTIES["OpticMount"], "light_": EMPTIES["TorchMount"],
    "laser_": (-SIDE_RAIL_TOP_X, LASER_Y, Z(SIDE_RAIL_PY)), "muzzle_": EMPTIES["BarrelEnd"],
}

# Plain colours (the game paints the five scheme materials; these are what a viewer without it shows: blued steel and
# black polymer).
MATERIALS = {
    "Body": (0x24272c, 0.45, 0.2), "Furniture": (0x2b2d31, 0.7, 0.0), "Detail": (0x30343b, 0.55, 0.0),
    "Accent": (0xf2f0ea, 0.5, 0.0), "Metal": (0x484d56, 0.4, 0.4), "Rubber": (0x1c1d20, 0.8, 0.0),
    "BB": (0xf4f1e8, 0.3, 0.0),
}


# ------------------------------------------------------------------------------------------------------ helpers

def side_prism(b: hs.Builder, trace: list, hw: float, mat: str, seg: int = 3, x0: float = None) -> list:
    """A side outline (photo points with corner radii) extruded across, -hw to hw (or x0 to hw)."""
    poly = [(y, z) for y, z in hs.fillet(pts(trace), seg)]
    return b.prism(poly, "x", -hw if x0 is None else x0, hw, mat)


def section(hw: float, zb: float, zt: float, rb: float, rt: float, seg: int = 4) -> list:
    """A cross-section (x, z): a rectangle hw either side from zb to zt, its bottom corners rounded by rb and its top
    ones by rt, counter-clockwise from the bottom right; the same count of points whatever the sizes."""
    out = []
    for cx, cz, r, a0 in ((hw - rb, zb + rb, rb, -90.0), (hw - rt, zt - rt, rt, 0.0), (-hw + rt, zt - rt, rt, 90.0),
                          (-hw + rb, zb + rb, rb, 180.0)):
        for i in range(seg + 1):
            a = math.radians(a0 + 90.0 * i / seg)
            out.append((cx + r * math.cos(a), cz + r * math.sin(a)))
    return out


def swell(ring: list, hw: float, zb: float, zt: float, by: float) -> list:
    """A section's straight sides bowed out by up to `by` at their middle (x scaled with z, its ends kept)."""
    out = []
    for x, z in ring:
        t = min(1.0, max(0.0, (z - zb) / max(1e-6, zt - zb)))
        k = 1.0 + (by / hw) * math.sin(math.pi * t) if abs(x) > hw * 0.5 else 1.0
        out.append((x * k, z))
    return out


def roof(hw: float, zb: float, z1: float, zt: float, seg: int = 10) -> list:
    """The receiver's section: straight sides from zb up to z1, then an elliptic roof to zt (x, z)."""
    out = [(-hw, zb), (hw, zb)]
    for i in range(seg + 1):
        a = math.pi * i / seg
        out.append((hw * math.cos(a), z1 + (zt - z1) * math.sin(a)))
    return out


def picatinny(b: hs.Builder, y0: float, y1: float, mat: str, place: Matrix) -> None:
    """A rail from y0 to y1 along its own +Y, its base at its z 0, built upright and moved by `place` (aeg.py's)."""
    # Low (the owner: less tall): RAIL_H from its base to the teeth's tops.
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


def pin(b: hs.Builder, px: float, py: float, r_px: float, x: float, mat: str = "Metal", seg: int = 16,
        sides: tuple = (-1, 1)) -> None:
    """A pin's domed head on each side face at x (its centre a photo point, its radius in px)."""
    r = r_px / PX_PER_M
    for sx in sides:
        prof = [(-0.0006, 0.0), (-0.0006, r), (0.0004, r), (0.0009, r * 0.8), (0.0012, r * 0.45), (0.0012, 0.0)]
        prof = [(sx * a, rr) for a, rr in prof]
        if sx < 0:
            prof = list(reversed(prof))
        b.lathe(prof, mat, seg, centre=(sx * x, Y(px), Z(py)), axis="x")


def box_cutter(name: str, lo: tuple, hi: tuple) -> object:
    c = hs.Builder(name, ["Body"])
    c.box(lo, hi, "Body")
    return c.build()


def weld(ob: object, other: object) -> None:
    """Unions `other` into `ob` (exact solver) keeping `other`'s own materials on its faces, then deletes it (hs.cut's
    tool mesh carries no material slots, so its faces would take `ob`'s first material)."""
    mod = ob.modifiers.new("weld", "BOOLEAN")
    mod.operation = "UNION"
    mod.solver = "EXACT"
    mod.use_self = True
    mod.use_hole_tolerant = True
    mod.material_mode = "TRANSFER"
    mod.object = other
    hs.apply_modifiers(ob)
    bpy.data.objects.remove(other, do_unlink=True)


def section_prism(name: str, poly: list, y0: float, y1: float, mat: str) -> object:
    c = hs.Builder(name, [mat])
    c.prism(poly, "y", y0, y1, mat)
    return c.build()


# ------------------------------------------------------------------------------------------------------ receiver

def receiver(lower_moulding: object) -> list:
    """The stamped receiver: its side outline (the end cap's slope at the top, its foot reaching down behind the trigger
    group) cut to its round-roofed section, the struts' grooves along each side, the ejection port on the right."""
    b = hs.Builder("Receiver", ["Body"])
    side_prism(b, [(RX_PX[1], RX_TOP_PY), (RX_PX[1], RX_BOTTOM_PY), (346, RX_BOTTOM_PY), (346, 248, 4), (262, 248, 8),
                   (RX_PX[0], 236, 8), (RX_PX[0], 110), (252, 95, 6), (268, 78, 8), (284, RX_TOP_PY)],
               0.03, "Body", 8)
    ob = b.build()
    shape = section_prism("c_roof", roof(RX_HW, Z(260), Z(RX_ROOF_PY), Z(RX_TOP_PY), 24), Y(200), Y(800), "Body")
    hs.cut(ob, [shape], "INTERSECT")
    # The trigger housing, grip and guard welded on underneath: one solid piece, rounded together.
    weld(ob, lower_moulding)
    cutters = []
    # The struts' grooves, open at the back; and a pressed line along each side under the roof.
    half = (GROOVE_PY[1] - GROOVE_PY[0]) / 2.0 / PX_PER_M
    r = (half * half + GROOVE_DEPTH * GROOVE_DEPTH) / (2.0 * GROOVE_DEPTH)
    for sx in (-1, 1):
        # A round-bottomed channel: an arc through the groove's top and bottom edges, GROOVE_DEPTH deep.
        g = hs.Builder("c_groove", ["Body"])
        g.lathe([(Y(RX_PX[0]) - 0.01, 0.0), (Y(RX_PX[0]) - 0.01, r), (Y(722), r), (Y(722) + 0.004, r * 0.5),
                 (Y(722) + 0.004, 0.0)], "Body", 32, centre=(sx * (RX_HW - GROOVE_DEPTH + r), 0.0,
                                                               Z(sum(GROOVE_PY) / 2.0)))
        cutters.append(g.build())
        x0, x1 = sorted((sx * (RX_HW - 0.0006), sx * (RX_HW + 0.01)))
        cutters.append(box_cutter("c_line", (x0, Y(300), Z(124)), (x1, Y(760), Z(121))))
    # The ejection port on the right, and the cocking handle's channel the bolt rides in behind it.
    cutters.append(box_cutter("c_port", (RX_HW - 0.0065, Y(PORT_PX[0]), Z(PORT_PY[1])), (RX_HW + 0.01, Y(PORT_PX[1]), Z(PORT_PY[0]))))
    hs.cut(ob, cutters)
    hs.finish(ob, 0.0014, 3)
    out = [ob]
    # Inside the port: the bolt's face, dark.
    b = hs.Builder("PortFloor", ["Detail"])
    b.box((RX_HW - 0.0070, Y(PORT_PX[0] - 2), Z(PORT_PY[1] + 2)), (RX_HW - 0.0055, Y(PORT_PX[1] + 2), Z(PORT_PY[0] - 2)),
          "Detail")
    out.append(hs.finish(b.build(), 0.0))
    # The bolt's lug showing in the port.
    b = hs.Builder("PortBolt", ["Metal"])
    b.box((RX_HW - 0.0060, Y(PORT_PX[0] + 12), Z(PORT_PY[1] - 5)), (RX_HW - 0.0030, Y(PORT_PX[0] + 48), Z(PORT_PY[0] + 5)),
          "Metal")
    out.append(hs.finish(b.build(), 0.0004, 1))
    # The end cap's plate and the stock's latch block behind the receiver.
    b = hs.Builder("EndCap", ["Detail"])
    side_prism(b, [(RX_PX[0] + 3, 112), (RX_PX[0] + 3, 236, 6), (222, 236, 4), (222, 122, 4)], 0.0125, "Detail", 3)
    side_prism(b, [(226, 236), (262, 236), (264, 255, 3), (258, 261, 3), (232, 261, 3), (226, 255, 3)], 0.0060,
               "Detail", 3)
    out.append(hs.finish(b.build(), 0.0016, 4))
    # Pins: the trigger group's rear pin, the receiver's front pin by the handguard.
    b = hs.Builder("RxPins", ["Metal"])
    pin(b, 310, 226, 7.5, RX_HW)
    pin(b, 762, 157, 6.5, RX_HW)
    out.append(hs.finish(b.build(), 0.0002, 1, weighted=False))
    return out


def struts() -> object:
    """The collapsed stock's two struts, one in each side groove, out of the butt's arm."""
    b = hs.Builder("Struts", ["Detail"])
    for sx in (-1, 1):
        b.lathe([(Y(150), 0.0), (Y(150), STRUT_R), (Y(715), STRUT_R), (Y(718), STRUT_R * 0.7), (Y(718), 0.0)], "Detail",
                12, centre=(sx * (RX_HW - GROOVE_DEPTH + STRUT_R * 0.55), 0.0, Z(sum(GROOVE_PY) / 2.0)))
    return hs.finish(b.build(), 0.0, 1)


def cocking_tube() -> list:
    """The tube over the barrel from the receiver to the front sight, its slot on the left for the cocking handle
    (with the notch at its back the handle is flicked up into)."""
    b = hs.Builder("Tube", ["Body"])
    zc = Z(TUBE_PY)
    b.lathe([(Y(TUBE_PX[0]), 0.0), (Y(TUBE_PX[0]), TUBE_R), (Y(1140), TUBE_R), (Y(1141), TUBE_R + 0.0008),
             (Y(TUBE_PX[1]), TUBE_R + 0.0008), (Y(TUBE_PX[1]), 0.0)], "Body", 32, centre=(0.0, 0.0, zc))
    ob = b.build()
    cutters = [box_cutter("c_slot", (-0.02, Y(SLOT_PX[0]), zc - 0.0022), (-0.0035, Y(SLOT_PX[1]), zc + 0.0022))]
    # The notch, up and back from the slot's back end.
    notch = hs.Builder("c_notch", ["Body"])
    notch.prism([(Y(SLOT_PX[0]), zc - 0.0022), (Y(SLOT_PX[0]) + 0.0110, zc - 0.0022), (Y(SLOT_PX[0]) + 0.0110,
                 zc + 0.0022), (Y(SLOT_PX[0]) + 0.0060, zc + 0.0068), (Y(SLOT_PX[0]), zc + 0.0068)], "x", -0.02,
                -0.0030, "Body")
    cutters.append(notch.build())
    hs.cut(ob, cutters)
    hs.finish(ob, 0.0004, 2)
    # Dark inside the slot.
    b = hs.Builder("TubeCore", ["Detail"])
    b.lathe([(Y(SLOT_PX[0]) - 0.002, 0.0), (Y(SLOT_PX[0]) - 0.002, TUBE_R - 0.0016), (Y(SLOT_PX[1]) + 0.002,
             TUBE_R - 0.0016), (Y(SLOT_PX[1]) + 0.002, 0.0)], "Detail", 16, centre=(0.0, 0.0, zc))
    return [ob, hs.finish(b.build(), 0.0)]


def top_rail() -> object:
    """The owner's short top rail on a low mount over the receiver: the mount's riser along the roof, three clamp
    jaws down the receiver's sides with a screw each on the right, and the rail."""
    b = hs.Builder("TopRail", ["Body", "Metal"])
    y0, y1 = Y(TOP_RAIL_PX[0]), Y(TOP_RAIL_PX[1])
    riser = [(-0.0090, Z(RX_TOP_PY) - 0.0040), (0.0090, Z(RX_TOP_PY) - 0.0040), (0.0090, RAIL_BASE - 0.0030),
             (0.0072, RAIL_BASE), (-0.0072, RAIL_BASE), (-0.0090, RAIL_BASE - 0.0030)]
    b.prism(riser, "y", y0 + 0.002, y1 - 0.002, "Body")
    picatinny(b, y0, y1, "Body", Matrix.Translation((0.0, 0.0, RAIL_BASE)))
    for px in (TOP_RAIL_PX[0] + 30, sum(TOP_RAIL_PX) / 2.0, TOP_RAIL_PX[1] - 30):
        yc = Y(px)
        # A jaw: a plate either side, from the riser down the roof's shoulder.
        for sx in (-1, 1):
            jaw = [(sx * 0.0090, RAIL_BASE - 0.0030), (sx * (RX_HW + 0.0016), Z(RX_ROOF_PY) + 0.004),
                   (sx * (RX_HW + 0.0016), Z(RX_ROOF_PY) - 0.0030), (sx * (RX_HW - 0.0004), Z(RX_ROOF_PY) - 0.0030),
                   (sx * (RX_HW - 0.0004), Z(RX_ROOF_PY) + 0.0030), (sx * 0.0080, Z(RX_TOP_PY) - 0.0010)]
            if sx < 0:
                jaw = list(reversed(jaw))
            b.prism(jaw, "y", yc - 0.0060, yc + 0.0060, "Body")
        b.lathe([(RX_HW + 0.0016, 0.0), (RX_HW + 0.0016, 0.0026), (RX_HW + 0.0034, 0.0026), (RX_HW + 0.0040, 0.0018),
                 (RX_HW + 0.0040, 0.0)], "Metal", 12, centre=(0.0, yc, Z(RX_ROOF_PY) + 0.0006), axis="x")
    return hs.finish(b.build(), 0.0004, 1)


def front_block() -> list:
    """The front sight's block round the tube's end and the barrel, with its cross screw and pin, the tube's collar
    and the barrel's lug ring."""
    b = hs.Builder("FrontBlock", ["Body"])
    y0, y1 = Y(FS_PX[0]), Y(FS_PX[1])
    for zc, r in ((Z(TUBE_PY), 0.0098), (BORE_Z, 0.0118)):
        b.lathe([(y0, 0.0), (y0, r - 0.0010), (y0 + 0.0010, r), (y1 - 0.0010, r), (y1, r - 0.0010), (y1, 0.0)], "Body",
                32, centre=(0.0, 0.0, zc))
    b.prism([(-0.0086, Z(TUBE_PY)), (0.0086, Z(TUBE_PY)), (0.0086, BORE_Z), (-0.0086, BORE_Z)], "y", y0 + 0.0008,
            y1 - 0.0008, "Body")
    ob = hs.finish(b.build(), 0.0006, 1)
    b = hs.Builder("FrontBits", ["Body", "Metal"])
    # The collar over the tube's end, ringed.
    zc = Z(TUBE_PY)
    prof = [(Y(1140), 0.0), (Y(1140), 0.0094), (Y(1146), 0.0094), (Y(1147), 0.0088), (Y(1150), 0.0088),
            (Y(1151), 0.0094), (Y(1180), 0.0094), (Y(1181), 0.0090), (Y(FS_PX[0] + 2), 0.0090),
            (Y(FS_PX[0] + 2), 0.0)]
    b.lathe(prof, "Body", 28, centre=(0.0, 0.0, zc))
    # The barrel itself, one piece from inside the receiver, under the handguard, through the block.
    b.lathe([(Y(RX_PX[1] - 30), 0.0), (Y(RX_PX[1] - 30), 0.0082), (Y(FS_PX[0] + 4), 0.0082), (Y(FS_PX[0] + 4), 0.0)],
            "Body", 28, centre=(0.0, 0.0, BORE_Z))
    # The barrel out of the block's front, its three lugs, to the thread cap.
    prof = [(Y(FS_PX[1] - 4), 0.0), (Y(FS_PX[1] - 4), 0.0082), (Y(BARREL_END_PX), 0.0082), (Y(BARREL_END_PX), 0.0)]
    b.lathe(prof, "Body", 28, centre=(0.0, 0.0, BORE_Z))
    for k in range(3):
        a = math.radians(90.0 + 120.0 * k)
        lug = b.box((-0.0022, Y(FS_PX[1] - 2), 0.0070), (0.0022, Y(BARREL_END_PX - 2), 0.0096), "Body")
        b.transform(lug, Matrix.Translation((0.0, 0.0, BORE_Z)) @ Matrix.Rotation(a - math.pi * 0.5, 4, "Y"))
    pin(b, 1210, 118, 5.0, 0.0086)
    pin(b, 1204, 144, 4.0, 0.0090)
    return [ob, hs.finish(b.build(), 0.0004, 1)]


def flash_hider() -> object:
    """The thread cap on the barrel: a hex collar and a plain tube to the muzzle."""
    b = hs.Builder("FlashHider", ["Metal", "Detail"])
    hexr = 0.0100
    prof = [(Y(BARREL_END_PX), 0.0), (Y(BARREL_END_PX), hexr), (Y(1254), hexr), (Y(1258), 0.0080),
            (Y(1260), 0.0074), (Y(MUZZLE_PX - 2), 0.0074), (Y(MUZZLE_PX), 0.0068), (Y(MUZZLE_PX), 0.0032),
            (Y(MUZZLE_PX - 8), 0.0032), (Y(MUZZLE_PX - 8), 0.0)]
    b.lathe(prof[:3] + [(Y(1254), hexr * 0.0 + hexr), (Y(1254), 0.0)], "Metal", 6, centre=(0.0, 0.0, BORE_Z))
    b.lathe([(Y(1253), 0.0), (Y(1253), 0.0084)] + prof[3:], "Metal", 28, centre=(0.0, 0.0, BORE_Z))
    return hs.finish(b.build(), 0.0004, 1)


def handguard() -> list:
    """The slim polymer handguard: lofted along the barrel, its bottom rising forward as the photo's, the top tucked
    under the tube; its front pin; and the owner's short rail on each side."""
    b = hs.Builder("Handguard", ["Furniture"])
    rings = []
    n = 40
    for i in range(n + 1):
        px = HG_PX[0] + (HG_PX[1] - HG_PX[0]) * i / n
        # Its sides bowed, round underneath; it flares a little over its last tenth, a lip round the front.
        flare = HG_FLARE * smoothstep(0.88, 1.0, i / n)
        hw = HG_HW + flare
        zb = Z(at(HG_BOTTOM, px)) - flare
        ring = section(hw, zb, Z(HG_TOP_PY), 0.0125, 0.0070, 8)
        rings.append([(x, Y(px), z) for x, z in swell(ring, hw, zb, Z(HG_TOP_PY), HG_SWELL)])
    b.loft(rings, "Furniture")
    ob = b.build()
    # The tube's channel along its top.
    c = hs.Builder("c_tube", ["Body"])
    c.lathe([(Y(HG_PX[0]) - 0.01, 0.0), (Y(HG_PX[0]) - 0.01, TUBE_R + 0.0004), (Y(HG_PX[1]) + 0.01, TUBE_R + 0.0004),
             (Y(HG_PX[1]) + 0.01, 0.0)], "Body", 24, centre=(0.0, 0.0, Z(TUBE_PY)))
    hs.cut(ob, [c.build()])
    hs.finish(ob, 0.0030, 3)
    out = [ob]
    b = hs.Builder("HgBits", ["Body", "Metal"])
    pin(b, 1155, 130, 9.0, HG_HW - 0.0004, "Body", 20)
    pin(b, 1155, 130, 4.5, HG_HW + 0.0008, "Metal", 12)
    for sx in (-1, 1):
        picatinny(b, Y(SIDE_RAIL_PX[0]), Y(SIDE_RAIL_PX[1]), "Body", side_place(sx, Z(SIDE_RAIL_PY), HG_HW - 0.0006))
    out.append(hs.finish(b.build(), 0.0003, 1))
    return out


# The grip's front and back edges, top (inside the housing) to the foot (the toe, the heel), as the photo's.
GRIP_FRONT = [(504, 284), (502, 300), (500, 316), (497, 330), (490, 348), (484, 365), (476, 382), (468, 395),
              (464, 403), (457, 415),
              (450, 430), (443, 445), (436, 460), (430, 475), (423, 490), (418, 505), (417, 516), (411, 526)]
GRIP_BACK = [(404, 268), (401, 284), (398, 300), (395, 310), (391, 320), (385, 330), (378, 340), (372, 350), (365, 360), (359, 370),
             (353, 380), (346, 390), (340, 400), (330, 415), (321, 430), (311, 445), (303, 457), (300, 467)]


def _along(trace: list, t: float) -> Vector:
    """The point a share t of the way along a photo polyline, in model (y, z)."""
    p = [Vector((Y(x), Z(y))) for x, y in trace]
    seg = [(a - b).length for a, b in zip(p[1:], p)]
    goal = t * sum(seg)
    for a, b, d in zip(p, p[1:], seg):
        if goal <= d:
            return a.lerp(b, goal / max(1e-9, d))
        goal -= d
    return p[-1]


def grip() -> object:
    """The pistol grip, lofted from the housing down to its foot through rounded sections between the photo's front
    and back edges, flaring slightly toward the foot; its sides lightly stippled panels (a raised pad each side)."""
    rings = []
    n = 30
    for i in range(n + 1):
        t = i / n
        f, bk = _along(GRIP_FRONT, t), _along(GRIP_BACK, t)
        mid, half = (f + bk) / 2.0, (f - bk) / 2.0
        # Flush with the housing's sides where it leaves them (one moulding), then its own width, flaring to the foot.
        hw = GRIP_HW - 0.0012 + 0.0016 * t + (LOWER_HW - GRIP_HW + 0.0012) * (1.0 - smoothstep(0.14, 0.36, t))
        ring = []
        for k in range(32):
            a = 2.0 * math.pi * k / 32
            c, sn = math.cos(a), math.sin(a)
            # Square at its top, where it leaves the housing's box (one moulding, no ledge), rounding down the grip.
            sq = 1.0 - smoothstep(0.14, 0.38, t)
            u = math.copysign(abs(c) ** (2.0 / (3.2 + 30.0 * sq)), c)
            w = math.copysign(abs(sn) ** (2.0 / (2.6 + 30.0 * sq)), sn)
            # The front a little rounder than the back strap.
            q = mid + half * u
            ring.append((hw * w * (0.92 if u > 0.0 else 1.0), q.x, q.y))
        rings.append(ring)
    b = hs.Builder("Grip", ["Furniture"])
    b.loft(rings, "Furniture")
    return b.build()


def lower() -> list:
    """The polymer trigger group: its housing under the receiver, the pistol grip raked back, the trigger guard; pins
    through it; the magazine well (steel, the receiver's) in front of it."""
    b = hs.Builder("Lower", ["Furniture"])
    # Its back runs down into the grip's back strap (one moulding, no ledge where they meet).
    side_prism(b, [(342, 202), (680, 202), (680, 309, 3), (650, 314), (520, 314), (404, 314), (393, 314),
                   (396, 304), (397, 296, 8), (394, 280, 8), (386, 268, 8), (372, 259, 8), (356, 253, 6), (342, 250, 4)],
               LOWER_HW, "Furniture", 4)
    # A web filling the corner where the grip's front leaves the housing, curved, so they read as one moulding.
    web = hs.Builder("Web", ["Furniture"])
    corner, p1, p2 = Vector((Y(499.0), Z(313.0))), Vector((Y(530.0), Z(313.0))), Vector((Y(492.0), Z(338.0)))
    arc = [p1]
    for k in range(1, 12):
        t = k / 12.0
        arc.append(p1 * (1 - t) ** 2 + corner * 2 * t * (1 - t) * 0.0 + Vector((Y(503.0), Z(318.0))) * 2 * t * (1 - t)
                   + p2 * t * t)
    arc.append(p2)
    web.prism([(v.x, v.y) for v in [corner + Vector((0.0, 0.004))] + arc[::-1] + [Vector((p1.x, corner.y + 0.004))]],
              "x", -LOWER_HW, LOWER_HW, "Furniture")
    housing = b.build()
    # The guard: a band from the grip's front round under the trigger to the housing's front.
    b = hs.Builder("Guard", ["Furniture"])
    guard = [(462, 378), (466, 396), (500, 394, 6), (522, 400, 6), (588, 400, 8), (606, 392, 8), (614, 378, 6), (621, 358),
             (628, 338), (636, 320), (646, 310), (624, 310), (618, 330), (612, 350), (604, 372, 4), (594, 387, 4),
             (520, 388, 5), (505, 382, 4), (482, 366)]
    side_prism(b, guard, GUARD_HW, "Furniture", 3)
    # One moulded piece (the owner): the housing, the grip and the guard welded, rounded together.
    hs.cut(housing, [grip(), b.build(), web.build()], "UNION")
    # Not finished here: the receiver welds it on (receiver()) and rounds the whole.
    out = [housing]
    # The magazine well: a steel box in front of the housing, open underneath for the magazine.
    b = hs.Builder("MagWell", ["Body"])
    side_prism(b, [(678, 206), (775, 206), (777, 272, 4), (752, 282, 6), (702, 300, 4), (678, 300)], MAG_WELL_HW,
               "Body", 3)
    ob = b.build()
    c = hs.Builder("c_mag", ["Body"])
    side_prism(c, [(691, 212), (773, 212), (779, 300), (782, 330), (699, 330), (696, 300)], MAG_HW + 0.0004, "Body",
               0)
    hs.cut(ob, [c.build()])
    out.append(hs.finish(ob, 0.0010, 2))
    # The magazine catch's button on the well's right.
    b = hs.Builder("Bits", ["Metal", "Detail"])
    b.lathe([(MAG_WELL_HW - 0.0004, 0.0), (MAG_WELL_HW - 0.0004, 0.0042), (MAG_WELL_HW + 0.0014, 0.0042),
             (MAG_WELL_HW + 0.0020, 0.0034), (MAG_WELL_HW + 0.0020, 0.0)], "Detail", 16,
            centre=(0.0, Y(728), Z(242)), axis="x")
    # The housing's pins: front two, and the selector's pivot boss on each side.
    pin(b, 662, 257, 5.0, LOWER_HW)
    pin(b, 668, 293, 5.0, LOWER_HW)
    out.append(hs.finish(b.build(), 0.0002, 1, weighted=False))
    return out


def stock() -> object:
    """The collapsed stock's butt: the arm that runs forward over the struts, the butt plate, the sling loop."""
    b = hs.Builder("Butt", ["Furniture"])
    trace = [(75, 108, 14), (222, 117, 8), (222, 202, 8), (160, 204, 14), (140, 211), (128, 220), (120, 230),
             (115, 240), (112, 250), (109, 260), (106, 270), (103, 280), (101, 292, 4), (112, 304, 6), (119, 318, 7),
             (118, 334, 8), (108, 344, 6), (91, 351, 5), (81, 360), (78, 370, 6), (68, 382, 10), (52, 384, 10),
             (40, 376, 8), (17, 363, 9), (13, 350, 8), (21, 320), (26, 300), (29, 280), (31, 260), (33, 200),
             (33, 130, 14), (42, 114, 16)]
    side_prism(b, trace, PAD_HW, "Furniture", 4)
    ob = b.build()
    # Seen from above: the pad wider than the arm, swelling out behind it, its back corners rounded (a moulded shell,
    # not a plate).
    plan = []
    for i in range(13):
        px = PAD_PX + 34.0 - 34.0 * i / 12
        plan.append((BUTT_HW + (PAD_HW - BUTT_HW) * smoothstep(PAD_PX + 34.0, PAD_PX, px), Y(px)))
    plan += [(PAD_HW, Y(18.0)), (PAD_HW - 0.0040, Y(6.0)), (PAD_HW - 0.0100, Y(2.0))]
    outline = [(x, y) for x, y in plan] + [(-x, y) for x, y in reversed(plan)]
    outline = [(BUTT_HW, Y(260.0))] + outline + [(-BUTT_HW, Y(260.0))]
    shell = hs.Builder("c_shell", ["Furniture"])
    shell.prism([(x, y) for x, y in outline], "z", Z(420.0), Z(80.0), "Furniture")
    # Seen from behind: its sides bowed out PAD_BOW at the middle of the pad, an elliptic section round to its top
    # and toe, so it reads moulded, not cut from a plate.
    k = (PAD_HW - PAD_BOW) / PAD_HW
    half = PAD_HALF / math.sqrt(1.0 - k * k)
    bow = [(PAD_HW * math.cos(2.0 * math.pi * i / 32), Z(PAD_MID_PY) + half * math.sin(2.0 * math.pi * i / 32))
           for i in range(32)]
    barrel = section_prism("c_bow", bow, Y(0.0) - 0.01, Y(260.0), "Furniture")
    hs.cut(ob, [shell.build(), barrel], "INTERSECT")
    c = hs.Builder("c_loop", ["Body"])
    c.lathe([(-0.03, 0.0), (-0.03, 5.5 / PX_PER_M), (0.03, 5.5 / PX_PER_M), (0.03, 0.0)], "Body", 16,
            centre=(0.0, Y(100), Z(326)), axis="x")
    cutters = [c.build()]
    hs.cut(ob, cutters)
    return hs.finish(ob, 0.0090, 5)


# ----------------------------------------------------------------------------------------------------- moving parts

def trigger() -> object:
    b = hs.Builder("Trigger", ["Detail"])
    side_prism(b, [(522, 300), (552, 300), (551, 318, 3), (546, 335, 6), (545, 355, 6), (548, 368, 5), (556, 382, 2),
                   (552, 387, 2), (538, 376, 6), (529, 360, 8), (525, 340, 6)], 0.0030, "Detail", 3)
    return hs.finish(b.build(), 0.0006, 2)


def selector() -> object:
    """The selector's lever on each side: a paddle on a round boss, its pointer's tip white."""
    b = hs.Builder("Selector", ["Detail", "Accent"])
    pivot = (492.0, 236.0)
    for sx in (-1, 1):
        x0 = sx * (LOWER_HW + 0.0002)
        x1 = sx * (LOWER_HW + 0.0022)
        side_prism(b, [(470, 224, 5), (484, 212, 6), (502, 222, 6), (508, 238), (519, 261, 2), (513, 265, 2),
                       (497, 246), (476, 241, 6)], max(x0, x1), "Detail", 3, min(x0, x1))
        prof = [(0.0, 0.0), (0.0, 0.0050), (0.0024, 0.0050), (0.0030, 0.0040), (0.0030, 0.0)]
        prof = [(sx * a + sx * LOWER_HW, r) for a, r in prof]
        if sx < 0:
            prof = list(reversed(prof))
        b.lathe(prof, "Detail", 16, centre=(0.0, Y(pivot[0]), Z(pivot[1])), axis="x")
        xa, xb = sorted((sx * (LOWER_HW + 0.0021), sx * (LOWER_HW + 0.0025)))
        side_prism(b, [(511, 252), (515, 251), (519, 260, 1), (514, 263, 1)], xb, "Accent", 1, xa)
    return hs.finish(b.build(), 0.0004, 1)


def mag_release() -> object:
    """The paddle catch behind the magazine, under the housing's front."""
    b = hs.Builder("MagRelease", ["Detail"])
    side_prism(b, [(666, 300), (679, 300), (675, 322, 4), (668, 338, 4), (664, 347, 2), (658, 345, 2),
                   (662, 328, 4)], 0.0080, "Detail", 3)
    return hs.finish(b.build(), 0.0008, 2)


def charging_handle() -> object:
    """The cocking handle at rest, forward in its slot: one turned piece out of the tube's left, up at 40 degrees, a
    stem swelling into a knurled bolt-like knob."""
    b = hs.Builder("ChargingHandle", ["Detail", "Metal"])
    zc = Z(TUBE_PY)
    yc = Y(HANDLE_PX)
    a = math.radians(40.0)
    d = Vector((-math.cos(a), 0.0, math.sin(a)))
    # One turned piece (the owner: a bolt, not a disc on a stick): the stem out of the slot swelling into a knurled
    # round-ended knob.
    prof = [(0.0, 0.0), (0.0, 0.0022), (0.0100, 0.0022), (0.0128, 0.0040), (0.0132, 0.0044)]
    for k in range(3):
        y = 0.0150 + 0.0034 * k
        prof += [(y, 0.0044), (y + 0.0004, 0.0041), (y + 0.0010, 0.0041), (y + 0.0014, 0.0044)]
    prof += [(0.0262, 0.0044), (0.0272, 0.0036), (0.0278, 0.0018), (0.0280, 0.0)]
    bolt = b.lathe(prof, "Detail", 14)
    rot = Vector((0.0, 1.0, 0.0)).rotation_difference(d).to_matrix().to_4x4()
    b.transform(bolt, Matrix.Translation((-0.0040, yc, zc)) @ rot)
    return hs.finish(b.build(), 0.0003, 1)


def front_sight() -> object:
    """The hooded ring front sight on the block's top and its post (an optic hides both: the iron sights rule)."""
    b = hs.Builder("FrontSightLeaf", ["Body", "Detail", "Accent"])
    yc = Y(HOOD_PX)
    zc = Z(HOOD_PY)
    b.tube([(-HOOD_LEN / 2, HOOD_R[1]), (HOOD_LEN / 2, HOOD_R[1])], [(-HOOD_LEN / 2, HOOD_R[0]),
                                                                    (HOOD_LEN / 2, HOOD_R[0])],
           "Body", 32, centre=(0.0, yc, zc))
    # The hood's neck down into the block.
    b.prism([(-0.0050, Z(FS_PY[0]) - 0.003), (0.0050, Z(FS_PY[0]) - 0.003), (0.0060, zc - HOOD_R[1] + 0.002),
             (-0.0060, zc - HOOD_R[1] + 0.002)], "y", yc - HOOD_LEN / 2 - 0.0020, yc + HOOD_LEN / 2 + 0.0020, "Body")
    # The post, up from the ring's foot to the sight line, its tip white.
    b.prism([(-0.0011, zc - HOOD_R[0] - 0.0005), (0.0011, zc - HOOD_R[0] - 0.0005), (0.0008, SIGHT_Z - 0.0010),
             (-0.0008, SIGHT_Z - 0.0010)], "y", yc - 0.0011, yc + 0.0011, "Detail")
    b.prism([(-0.0008, SIGHT_Z - 0.0010), (0.0008, SIGHT_Z - 0.0010), (0.0006, SIGHT_Z), (-0.0006, SIGHT_Z)], "y",
            yc - 0.0009, yc + 0.0009, "Accent")
    return hs.finish(b.build(), 0.0003, 1)


def rear_sight() -> object:
    """The rotary drum rear sight on its base at the receiver's back: the base, its screw, and the drum tilted forward
    with the aperture through it on the sight line."""
    b = hs.Builder("RearSightLeaf", ["Body", "Detail", "Metal"])
    # Its top under the sight line, so aimed it never stands in the aperture's way.
    # The drum sits down in its front step (no gap under it).
    side_prism(b, [(366, RX_TOP_PY + 6), (366, 62, 10), (386, 52, 4), (406, 52, 3), (410, 61, 2), (452, 61, 4),
                   (456, RX_TOP_PY + 6)], 0.0110, "Body", 4)
    base = b.build()
    # Its top rounded across, a moulded block rather than a box (aimed, it is the nearest thing under the drum).
    hs.cut(base, [section_prism("c_rsb", section(0.0110, Z(RX_TOP_PY + 20), Z(52.0), 0.0010, 0.0070, 8),
                                Y(350.0), Y(470.0), "Body")], "INTERSECT")
    hs.finish(base, 0.0014, 3)
    d = hs.Builder("Drum", ["Detail"])
    drum = d.lathe([(-DRUM_HH, 0.0), (-DRUM_HH, DRUM_R - 0.0008), (-DRUM_HH + 0.0008, DRUM_R), (DRUM_HH - 0.0008,
                    DRUM_R), (DRUM_HH, DRUM_R - 0.0008), (DRUM_HH, 0.0)], "Detail", 32, axis="z")
    # Its knurl: 24 ribs round the middle band.
    for k in range(24):
        a = 2.0 * math.pi * k / 24
        rib = d.box((-0.0006, DRUM_R - 0.0004, -DRUM_HH + 0.0030), (0.0006, DRUM_R + 0.0005, DRUM_HH - 0.0030), "Detail")
        drum += rib
        d.transform(rib, Matrix.Rotation(a, 4, "Z"))
    d.transform(drum, Matrix.Translation((0.0, Y(DRUM_PX[0]), Z(DRUM_PX[1]))) @
                Matrix.Rotation(math.radians(-DRUM_TILT), 4, "X"))
    ob = d.build()
    c = hs.Builder("c_aperture", ["Detail"])
    c.lathe([(Y(DRUM_PX[0]) - 0.02, 0.0), (Y(DRUM_PX[0]) - 0.02, APERTURE_R), (Y(DRUM_PX[0]) + 0.02, APERTURE_R),
             (Y(DRUM_PX[0]) + 0.02, 0.0)], "Detail", 24, centre=(0.0, 0.0, SIGHT_Z))
    hs.cut(ob, [c.build()])
    hs.finish(ob, 0.0004, 1)
    s = hs.Builder("RsScrew", ["Metal"])
    pin(s, 378, 60, 5.0, 0.0110)
    return hs.join("RearSightLeaf", [base, ob, hs.finish(s.build(), 0.0002, 1, weighted=False)])


def magazine() -> object:
    """The curved steel magazine (the owner's magazine photos): its side outline from the gun photo, rounded; the
    raised band pressed along each side near the front; the floor plate's lip."""
    back = [(694, 212), (696, 280), (698, 310), (702, 320), (704, 330), (707, 340), (709, 350), (712, 360), (714, 370),
            (717, 380), (719, 390), (722, 400), (727, 415), (732, 430), (737, 445), (742, 460), (747, 475), (753, 490),
            (759, 505), (766, 520), (772, 535), (779, 550), (786, 565), (794, 580), (802, 595), (810, 610)]
    front = [(772, 212), (773, 250), (776, 300), (778, 310), (780, 320), (782, 330), (785, 340), (788, 350), (790, 360),
             (793, 370), (796, 380), (799, 390), (802, 400), (807, 415), (812, 430), (817, 445), (823, 460), (829, 475),
             (835, 490), (842, 505), (849, 520), (856, 535), (864, 550), (872, 565), (880, 580), (886, 592)]
    b = hs.Builder("Magazine", ["Body", "Detail"])
    trace = [(x, y) for x, y in back] + [(817, 624, 3), (821, 630, 3), (888, 597, 3)] + \
        [(x, y) for x, y in reversed(front)]
    side_prism(b, trace, MAG_HW, "Body", 2)
    ob = hs.finish(b.build(), 0.0026, 3)
    # The raised band on each side, a fifth to two fifths of the way back from the front.
    bb = hs.Builder("MagBand", ["Body"])
    rows = [(f, bk) for f, bk in zip(front, back) if 296 <= f[1] <= 590]
    for f0, f1, proud in ((0.10, 0.34, 0.0008), (0.80, 0.86, 0.0005)):
        edge_a = [(f[0] - f0 * (f[0] - bk[0]), f[1]) for f, bk in rows]
        edge_b = [(f[0] - f1 * (f[0] - bk[0]), f[1]) for f, bk in rows]
        band = edge_a + list(reversed(edge_b))
        for sx in (-1, 1):
            xa, xb = sorted((sx * (MAG_HW - 0.0010), sx * (MAG_HW + proud)))
            side_prism(bb, band, xb, "Body", 0, xa)
    band_ob = hs.finish(bb.build(), 0.0005, 2)
    # The floor plate's lip, slightly proud all round the foot.
    fp = hs.Builder("MagFloor", ["Detail"])
    side_prism(fp, [(810, 610), (886, 590), (888, 597, 2), (821, 630, 2), (815, 624)], MAG_HW + 0.0006, "Detail", 2)
    floor = hs.finish(fp.build(), 0.0008, 2)
    return hs.join("Magazine", [ob, band_ob, floor])


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


# The magazine's way out: down its top's line (forward 0.27 per metre down), as the AEG Rifle's 0.29 m drop.
MAG_OUT = (0.075, -0.280)
# The Reload keeps the AEG Rifle's timeline (the game plays it as a share of the reload, and the arms' magazine change
# and ViewModelConfig.reload_carry are keyed to those shares).
# Clips: seconds, and per bone a list of (time, value) keys: degrees about x ("rx"), a (y, z) move ("yz"), or the
# cocking handle's (degrees about the tube, metres along it) ("ch"). Every bone is keyed in every clip. Fire is one
# shot's trigger pull at 18 a second; Selector runs safe (0), semi (half) and auto (the end); the Inspect pulls the
# cocking handle back, flicks it up into its notch and slaps it down and home.
CLIPS = {
    "Fire": (0.055, {"trigger": ("rx", [(0.0, 0.0), (0.018, -16.0), (0.030, -16.0), (0.055, 0.0)])}),
    "Reload": (1.8, {
        "magRelease": ("rx", [(0.0, 0.0), (0.05, -18.0), (0.35, -18.0), (0.40, 0.0)]),
        "magazine": ("yz", [(0.0, (0.0, 0.0)), (0.08, (0.0, 0.0)), (0.43, MAG_OUT), (0.90, MAG_OUT),
                            (0.9001, (MAG_OUT[0] * 0.53, MAG_OUT[1] * 0.53)), (1.40, (0.0, 0.0)), (1.8, (0.0, 0.0))]),
    }),
    "Selector": (0.5, {"selector": ("rx", [(0.0, 0.0), (0.5, 90.0)])}),
    "Inspect": (3.0, {
        "chargingHandle": ("ch", [(0.0, (0.0, 0.0)), (0.25, (0.0, 0.0)), (0.55, (0.0, -HANDLE_TRAVEL)),
                                  (0.70, (24.0, -HANDLE_TRAVEL)), (2.05, (24.0, -HANDLE_TRAVEL)),
                                  (2.12, (0.0, -HANDLE_TRAVEL)), (2.20, (0.0, 0.0)), (3.0, (0.0, 0.0))]),
    }),
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
                    elif kind == "ch":
                        rot = Matrix.Rotation(math.radians(v[0]), 3, "Y")
                        loc = Vector((0.0, v[1], 0.0))
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
    low = lower()
    parts += receiver(low[0])
    parts += cocking_tube()
    parts.append(struts())
    parts.append(top_rail())
    parts += front_block()
    parts += handguard()
    parts += low[1:]
    parts.append(stock())
    for ob in parts:
        print("  part %-14s %6d" % (ob.name, hs.tris(ob)))
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
                     (charging_handle(), "chargingHandle"), (magazine(), "magazine"), (front_sight(), "frontSight"),
                     (rear_sight(), "rearSight")):
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
    hs.fold_material("Rubber", "BB")  # BP6: within the 6 materials, looking the same
    # RW1: light use-wear in the hands, its own seed; the magazine handled most, as the AEG Rifle's.
    wear.apply(seed=3, heavier={"Magazine": 2.5})
    hs.export(OUT, True)
    print("wrote", OUT)
    build_parts()


def build_parts() -> None:
    """The parts file: the AEG Rifle's optics, laser, torch and silencer moved from its mounts onto this one's (each
    top-level part by the mount its name's prefix sits on); its barrels, grips and magazines dropped. Running it again
    changes nothing."""
    hs.reset(FPS)
    bpy.ops.import_scene.gltf(filepath=AEG_PARTS)
    for ob in list(bpy.data.objects):
        if ob.name.startswith(("barrel_", "magazine_", "grip_")):
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
