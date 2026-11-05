"""The Cyber Pistol's model (BL6, 2026-11-05): the old model's (M101, RM1) shape and colours, which the owner likes,
rebuilt at the GBB Pistol's quality with the owner's reference photos' details: a front shroud with three teeth cut in
its lower edge and glowing slashes, a muzzle block with the barrel standing out of it, a slide with a glowing core
window and cocking grooves, a rear block with an inset hex plate and a finned cap, an angular trigger guard, a
fire-mode slider with three lights, a ribbed magazine release, and a grip whose ribbed power cell shows through
windows in its sides. An original design: no maker's marks, no writing.

It keeps the old model's contract (docs/CC0_ASSETS.md › Replica models): the armature CyberPistol with the bones
root, magazine, selector, slide and trigger where they were, the four clips (Fire, Selector, Reload, Inspect) of the
same lengths and keys, the empties (Muzzle, FrontSight, RearSight, MagWell, SlideBack, TorchMount) where they were
(the parts file's torch stays on), the meshes Body, Slide, Trigger, Selector, Magazine and Figure, and the five
materials CyberSlab, CyberFrame, CyberLine, CyberCore and CyberMetal with the old file's colours (the game keeps a
Cyber Pistol's own colours; Realistic colours greys the glow).

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/replicas/cyber.py <repo root>

It writes assets/models/replicas/cyber.glb (BL_OUT overrides). Model space: metres, +Y along the bore, +Z up, +X the
replica's right; the numbers below are millimetres in the left side view (y forward, z up) unless named otherwise.
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
OUT = os.environ.get("BL_OUT") or os.path.join(ROOT, "assets/models/replicas/cyber.glb")
ARMATURE = "CyberPistol"
FPS = 60
MM = 0.001


def m(v: float) -> float:
    return v * MM


def poly(points: list) -> list:
    """Millimetre (y, z[, r]) corners to a filleted outline in metres."""
    return hs.fillet([(m(p[0]), m(p[1]), m(p[2]) if len(p) > 2 else 0.0) for p in points], 3)


def side(name: str, points: list, hw: float, mat: str, x0: float = None) -> object:
    """A part extruded across the replica from a side outline (mm), hw (mm) either side, or from x0 to hw."""
    b = hs.Builder(name, [mat])
    b.prism(poly(points), "x", m(-hw if x0 is None else x0), m(hw), mat)
    return b.build()


def box(name: str, lo: tuple, hi: tuple, mat: str) -> object:
    b = hs.Builder(name, [mat])
    b.box(tuple(m(v) for v in lo), tuple(m(v) for v in hi), mat)
    return b.build()


def both(fn) -> list:
    """`fn(sx)` for the left (-1) and right (+1) sides."""
    return [fn(-1), fn(1)]


def xs(sx: int, inner: float, outer: float) -> tuple:
    """The x range (mm) from `inner` to `outer` on side sx, low to high."""
    return tuple(sorted((sx * inner, sx * outer)))


# ------------------------------------------------------------------------------------------------------- dimensions

# The slide: its length (y), height (z) and half width, as the old model's; the bore's height.
SLIDE_Y = (-64.0, 85.0)
SLIDE_Z = (0.0, 30.5)
SLIDE_HW = 14.0
BORE_Z = 15.0
# The front shroud's and rear block's half width, the frame's, the trigger guard's and the grip's.
SHROUD_HW = 18.5
FRAME_HW = 15.8
GUARD_HW = 6.5
# The shroud: its side outline (front face at 101, top at 37, the lower edge at -21 with its three teeth' gaps).
SHROUD = [(17.0, 37.0), (95.5, 37.0), (101.0, 31.5), (101.0, -18.0), (94.5, -26.6), (52.0, -26.6), (52.0, 0.0),
          (36.0, 0.0), (45.0, 31.0), (12.0, 31.0)]
# The four gaps between the teeth: centre y, width at the foot and at the top, height (trapezoids).
TEETH = (61.0, 70.0, 79.0, 88.0)
TOOTH_GAP = (6.4, 3.6)
TOOTH_H = 11.0
SHROUD_FOOT = -26.6
# The step that sinks the lower half of the shroud's sides, and the rear block's lower skirt: (z, depth).
SHROUD_STEP = (2.0, 1.5)
REAR_SKIRT = (-8.0, 1.2)
# The big chamfer along the shroud's and rear block's top edges, and the shroud's inset side panel.
TOP_CHAMFER = 5.0
SHROUD_PANEL = [(97.0, 4.0, 1.5), (56.0, 4.0, 1.5), (56.0, 31.5, 1.5), (97.0, 31.5, 1.5)]
# The glowing slashes on its flanks: three, leaning back at the top, their foot's centre y, foot and top z, width.
SLASH_Y = (63.0, 72.0, 81.0)
SLASH_Z = (6.0, 27.0)
SLASH_LEAN = 7.5
SLASH_W = 2.4
# The muzzle block in front of the shroud and the barrel standing out of it (Muzzle at its end).
CAP_Y = (100.0, 110.0)
CAP_Z = (-15.5, 34.0)
CAP_HW = 16.5
BARREL_END = 114.0
BARREL_R = 5.6
BORE_R = 3.0
# The rear block over the slide's back and the finned cap behind it.
REAR = [(-31.0, 37.0), (-90.5, 37.0), (-93.5, 34.0), (-93.5, -8.0), (-89.0, -13.5), (-56.0, -13.5), (-45.0, -8.5),
        (-34.0, -3.0), (-31.0, 0.0)]
REAR_CAP_Y = (-112.0, -93.0)
REAR_CAP_Z = (-7.0, 33.0)
REAR_CAP_HW = 16.5
FIN_ZONES = ((21.5, 31.0), (-5.0, 6.5))
FIN_COUNT = 3
# The hex plate on the rear block's side: its centre, radius across the corners, depth.
HEX_C = (-66.0, 16.0)
HEX_R = 20.0
HEX_SQUASH = 0.68
# The frame: its outline (the dust cover's front at 52, the guard, the grip with its finger scallops and the tang).
GRIP = [(-20.0, -20.0), (-24.0, -34.0), (-27.5, -36.0, 4.0), (-31.5, -60.0, 30.0), (-54.0, -126.0, 1.5),
        (-115.0, -126.0, 1.5), (-114.0, -118.0, 4.0), (-99.0, -62.0, 30.0), (-86.0, -22.0, 4.0), (-99.0, -14.5, 2.0),
        (-104.5, -10.5, 1.5), (-103.0, -7.0), (-93.5, -7.0), (-90.0, -20.0)]
# The trigger guard's opening and the slot the trigger hangs from.
# The old model's shape (owner, 2026-11-05: "more like the original trigger and guard"): a narrow loop in front, a
# full-width web behind, the opening tall enough for the trigger and a little more. The trigger and guard sit 12 mm
# nearer the grip than the old model's (owner, 2026-11-05: "the player would need to stretch their finger"); the loop's
# front slants up to the front block's foot, so no notch opens under it.
GUARD_HOLE = [(33.7, -16.5, 1.0), (33.7, -35.5), (29.0, -40.0, 1.0), (-11.5, -40.0, 1.0), (-11.5, -16.5, 1.0)]
GUARD_LOOP = [(52.0, -14.0), (52.0, -24.0, 1.0), (42.0, -34.0, 2.0), (42.0, -42.5), (37.5, -47.0, 1.5), (-2.0, -47.0),
              (-2.0, -14.0)]
GUARD_WEB = [(-1.0, -20.0), (-1.0, -47.0), (-20.0, -47.0, 5.0), (-27.5, -38.0), (-26.0, -20.0)]
TRIGGER_SLOT = ((-8.0, 13.0), (-26.0, -8.0), 3.4)
# The grip's windows, where the power cell shows (inset in the frame's sides), and their depth.
GRIP_WINDOW = [(-31.5, -27.0, 3.0), (-82.0, -27.0, 4.0), (-109.6, -118.0, 3.0), (-59.5, -118.0, 3.0)]
WINDOW_DEPTH = 3.5
# The magazine (the power cell): raked back like the grip, its top at -16, the base pad's foot at -151.
MAG = [(-27.0, -18.0), (-81.5, -18.0), (-112.0, -122.0), (-57.4, -122.0)]
MAG_HW = 15.0
PAD = [(-55.5, -126.3), (-114.5, -126.3, 1.0), (-117.0, -131.0, 1.0), (-115.0, -147.0, 2.0), (-63.0, -147.0, 2.0),
       (-56.5, -131.0, 1.0)]
PAD_HW = 17.0
CELL_RING = (-67.0, -62.0)
# The rail under the shroud (the torch's clamp at TorchMount) and its cross slots.
RAIL_Y = (57.0, 92.0)
RAIL_Z = (-26.6, -21.0)
RAIL_HW = 10.0
RAIL_SLOTS = 4
# The sights' tops on one line (z 40, the old marks).
SIGHT_Z = 40.0
FRONT_SIGHT_Y = 103.8
REAR_SIGHT_Y = -76.8
# The selector's track on the frame's sides and its three lights (semi, burst, auto: the slider's centre at half,
# three quarters and the whole of its 16 mm travel).
TRACK = ((2.5, 30.0), (-7.6, -2.4))
SELECTOR_TRAVEL = 16.0
LIGHT_Y = (8.25 + 8.0, 8.25 + 12.0, 8.25 + 16.0)
LIGHT_Z = -11.0
LIGHT_R = 1.3
# The selector's dark housing round the track and lights: the recess in the frame, the plate in it and its face.
HOUSING = [(31.5, -14.0, 1.6), (1.0, -14.0, 1.6), (1.0, -0.8, 1.6), (31.5, -0.8, 1.6)]
HOUSING_IN = [(31.2, -13.7), (1.3, -13.7), (1.3, -1.1), (31.2, -1.1)]
HOUSING_FACE = FRAME_HW - 0.4
FRONT_SERRATIONS = 7

EMPTIES = {
    "Muzzle": (0.0, m(BARREL_END), m(BORE_Z)),
    "FrontSight": (0.0, m(FRONT_SIGHT_Y), m(SIGHT_Z)),
    "RearSight": (0.0, m(REAR_SIGHT_Y), m(SIGHT_Z)),
    "MagWell": (0.0, -0.0819, -0.1209),
    "SlideBack": (0.0, -0.09, m(BORE_Z)),
    "TorchMount": (0.0, 0.078, -0.027),
}
# Bones: name -> head, each pointing +Y BONE_LENGTH long with no roll, as the old file's.
BONES = {
    "root": (0.0, 0.0, 0.0),
    "magazine": (0.0, -0.0819, -0.1209),
    "selector": (0.0, 0.0083, -0.0055),
    "slide": (0.0, 0.0, 0.015),
    "trigger": (0.0, 0.0045, -0.0125),
}
BONE_LENGTH = 0.01

# The old file's colours (linear), roughness, metalness and glow.
MATERIALS = {
    "CyberSlab": ((0.80, 0.83, 0.86), 0.45, 0.0, False),
    "CyberFrame": ((0.017, 0.019, 0.025), 0.65, 0.0, False),
    "CyberLine": ((0.03, 0.87, 1.0), 0.35, 0.0, True),
    "CyberMetal": ((0.20, 0.22, 0.25), 0.38, 0.85, False),
    "CyberCore": ((1.0, 0.04, 0.39), 0.35, 0.0, True),
}


def materials() -> None:
    for name, (colour, rough, metal, glow) in MATERIALS.items():
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        if glow:
            bsdf.inputs["Emission Color"].default_value = (*colour, 1.0)
            bsdf.inputs["Emission Strength"].default_value = 1.0
        mat.diffuse_color = (*colour, 1.0)


# ------------------------------------------------------------------------------------------------------- small bits

def place(b: hs.Builder, faces: list, sx: int, at: tuple) -> None:
    """Moves faces built along +x (local x 0 the side's face, negative into the part) to the side sx at `at`
    (metres), mirrored for the left side with their normals kept facing out."""
    b.transform(faces, Matrix.Translation(at) @ Matrix.Diagonal((sx, 1.0, 1.0, 1.0)))
    if sx < 0:
        bmesh.ops.recalc_face_normals(b.bm, faces=faces)


def screw(b: hs.Builder, sx: int, y: float, z: float, face: float, r: float = 1.5) -> None:
    """A socket-head screw on the side at x = sx*face (mm): a domed head and a dark hex socket in it."""
    c = (m(sx * face), m(y), m(z))
    prof = [(0.0, m(r)), (m(0.35), m(r)), (m(0.55), m(r * 0.75)), (m(0.6), 0.0)]
    place(b, b.lathe(prof, "CyberMetal", 12, axis="x"), sx, c)
    place(b, b.lathe([(0.0, m(r * 0.45)), (m(0.62), m(r * 0.45))], "CyberFrame", 6, axis="x"), sx, c)


def pin(b: hs.Builder, y: float, z: float, hw: float, r: float = 1.2) -> None:
    """A cross pin through the frame, its ends just proud of both sides."""
    b.lathe([(m(-hw - 0.25), 0.0), (m(-hw - 0.25), m(r)), (m(hw + 0.25), m(r)), (m(hw + 0.25), 0.0)], "CyberMetal", 10,
            centre=(0.0, m(y), m(z)), axis="x")


def light(b: hs.Builder, sx: int, y: float, z: float, face: float, r: float = 0.85) -> None:
    """A small glowing dome on the side (the fire-mode lights)."""
    prof = [(0.0, m(r)), (m(0.25), m(r * 0.85)), (m(0.4), 0.0)]
    place(b, b.lathe(prof, "CyberLine", 10, axis="x"), sx, (m(sx * face), m(y), m(z)))


def side_recess(name: str, points: list, sx: int, face: float, depth: float, mat: str = "CyberSlab") -> object:
    """A cutter for a recess `depth` mm into the side at x = sx*face, shaped by a side outline (mm)."""
    lo, hi = xs(sx, face - depth, face + 5.0)
    b = hs.Builder(name, [mat])
    b.prism(poly(points), "x", m(lo), m(hi), mat)
    return b.build()


def inlay(name: str, points: list, sx: int, face: float, depth: float, mat: str) -> object:
    """A plate filling a recess, its face `depth` mm under the side at x = sx*face."""
    lo, hi = xs(sx, face - depth - 1.0, face - depth)
    b = hs.Builder(name, [mat])
    b.prism(poly(points), "x", m(lo), m(hi), mat)
    return b.build()


def slanted(y: float, z0: float, z1: float, lean: float, w: float, grow: float = 0.0) -> list:
    """A slot's outline from z0 to z1, its top `lean` mm behind its foot, `w` wide (plus 2*grow)."""
    h = w * 0.5 + grow
    return [(y + h, z0 - grow), (y - h, z0 - grow), (y - lean - h, z1 + grow), (y - lean + h, z1 + grow)]


def top_chamfer(ob: object, hw: float, top: float, c: float) -> None:
    """Cuts a 45 degree chamfer `c` mm along both top edges of a part `hw` mm either side, its top at `top`."""
    b = hs.Builder("c_chamfer", ["CyberSlab"])
    sec = [(m(-hw - 5.0), m(-300.0)), (m(hw + 5.0), m(-300.0)), (m(hw + 5.0), m(top - c - 5.0)), (m(hw), m(top - c)),
           (m(hw - c), m(top)), (m(-hw + c), m(top)), (m(-hw), m(top - c)), (m(-hw - 5.0), m(top - c - 5.0))]
    b.prism(sec, "y", m(-300.0), m(300.0), "CyberSlab")
    hs.cut(ob, [b.build()], "INTERSECT")


def side_step(name: str, hw: float, step: tuple, span: tuple, sx: int) -> object:
    """A cutter sinking a side's part below z = step[0] by step[1] mm, a 45 degree chamfer up to the part above,
    from y span[0] to span[1] (mm)."""
    z, d = step
    lo = [(hw - d, -300.0), (hw + 5.0, -300.0), (hw + 5.0, z + d), (hw, z + d), (hw - d, z)]
    b = hs.Builder(name, ["CyberSlab"])
    b.prism([(m(sx * x), m(zz)) for x, zz in lo], "y", m(span[0]), m(span[1]), "CyberSlab")
    return b.build()


# ------------------------------------------------------------------------------------------------------------ shroud

def shroud() -> list:
    """The front shroud (with the strap over the slide), its teeth, slashes and screws; the muzzle block and barrel;
    the rail under it; the front sight."""
    ob = side("Shroud", SHROUD, SHROUD_HW, "CyberSlab")
    top_chamfer(ob, SHROUD_HW, 37.0, TOP_CHAMFER)
    cut = []
    # The top strap over the slide is narrower than the shroud: trim its sides back to the slide's width plus a lip.
    for sx in (-1, 1):
        lo, hi = xs(sx, 15.5, 30.0)
        cut.append(box("c_strap", (lo, 11.0, 30.0), (hi, 44.0, 38.0), "CyberSlab"))
        # The gaps between the teeth, in the flanks either side of the rail.
        for y in TEETH:
            lo, hi = xs(sx, RAIL_HW + 0.6, 30.0)
            wb, wt = TOOTH_GAP[0] * 0.5, TOOTH_GAP[1] * 0.5
            top = SHROUD_FOOT + TOOTH_H
            cut.append(side("c_tooth", [(y - wb - 1.0, SHROUD_FOOT - 3.0), (y + wb + 1.0, SHROUD_FOOT - 3.0),
                                        (y + wb, SHROUD_FOOT), (y + wt, top, 0.8), (y - wt, top, 0.8),
                                        (y - wb, SHROUD_FOOT)], hi, "CyberSlab", lo))
        # The lower half of each side sunk a step, a 45 degree chamfer up to the upper half.
        cut.append(side_step("c_step", SHROUD_HW, SHROUD_STEP, (53.5, 110.0), sx))
        # The inset side panel the slashes are cut in.
        cut.append(side_recess("c_panel", SHROUD_PANEL, sx, SHROUD_HW, 0.5))
        # The slashes' slots.
        for y in SLASH_Y:
            cut.append(side_recess("c_slash", slanted(y, *SLASH_Z, SLASH_LEAN, SLASH_W), sx, SHROUD_HW - 0.5, 1.1))
        # A seam where the shroud meets the frame's dust cover.
        cut.append(side_recess("c_seam", [(52.6, -21.5), (51.8, -21.5), (51.8, 0.4), (52.6, 0.4)], sx, SHROUD_HW,
                               0.5))
    # The rail's channel under the shroud and the muzzle block's seat.
    cut.append(box("c_rail", (-RAIL_HW - 0.2, RAIL_Y[0] - 0.5, -30.0), (RAIL_HW + 0.2, 100.5, -20.4), "CyberSlab"))
    hs.cut(ob, cut)
    hs.finish(ob, m(1.5), 3)
    parts = [ob]
    # The slashes' glowing strips, sunk in their slots.
    b = hs.Builder("Slashes", ["CyberLine", "CyberMetal", "CyberFrame"])
    for sx in (-1, 1):
        for y in SLASH_Y:
            lo, hi = xs(sx, SHROUD_HW - 2.3, SHROUD_HW - 0.95)
            b.prism([(m(p[0]), m(p[1])) for p in slanted(y, SLASH_Z[0] + 0.6, SLASH_Z[1] - 0.6, SLASH_LEAN,
                                                          SLASH_W - 1.0)], "x", m(lo), m(hi), "CyberLine")
        screw(b, sx, 95.0, -9.0, SHROUD_HW - SHROUD_STEP[1])
        screw(b, sx, 93.0, 25.0, SHROUD_HW)
        screw(b, sx, 30.0, 34.0, 15.5, 1.2)
    parts.append(b.build())
    parts.append(muzzle_block())
    parts.append(rail())
    return parts


def muzzle_block() -> object:
    """The muzzle block: a chamfered metal block in front of the shroud with two grooves round it, a recessed face,
    and the barrel standing out of it, its crown bored."""
    hw, (z0, z1), (y0, y1) = CAP_HW, CAP_Z, CAP_Y
    ch = 2.2
    rings = []
    for y, d in ((y0, 0.0), (y1 - ch, 0.0), (y1, ch)):
        rings.append([(m(-hw + d), m(y), m(z0 + d)), (m(hw - d), m(y), m(z0 + d)), (m(hw - d), m(y), m(z1 - d)),
                      (m(-hw + d), m(y), m(z1 - d))])
    b = hs.Builder("MuzzleBlock", ["CyberMetal"])
    b.loft(rings, "CyberMetal")
    ob = b.build()
    cut = []
    for y in (y0 + 2.6, y0 + 5.0):
        g = hs.Builder("c_groove", ["CyberMetal"])
        g.box((m(-30.0), m(y - 0.5), m(z0 - 10.0)), (m(30.0), m(y + 0.5), m(z1 - 3.0)), "CyberMetal")
        inner = box("c_in", (-hw + 0.7, y0 - 1.0, z0 + 0.7), (hw - 0.7, y1 + 5.0, z1 + 5.0), "CyberMetal")
        gg = g.build()
        hs.cut(gg, [inner])
        cut.append(gg)
    # The recessed face, and the barrel's hole through it.
    face = hs.Builder("c_face", ["CyberMetal"])
    zc = (z0 + z1) * 0.5
    fw, fh = hw - ch - 2.6, (z1 - z0) * 0.5 - ch - 2.6
    face.loft([[(m(x), m(y), m(zc + zz)) for x, zz in hs.rounded_rect(fw + g, fh + g, 2.0 + g, 3)]
               for y, g in ((y1 - 1.2, 0.0), (y1, 1.2), (y1 + 2.0, 1.2))], "CyberMetal")
    cut.append(face.build())
    hole = hs.Builder("c_hole", ["CyberMetal"])
    hole.lathe([(m(y0), m(BARREL_R + 0.3)), (m(y1 + 3.0), m(BARREL_R + 0.3))], "CyberMetal", 24,
               centre=(0.0, 0.0, m(BORE_Z)))
    cut.append(hole.build())
    hs.cut(ob, cut)
    hs.finish(ob, m(0.8), 2)
    b = hs.Builder("Barrel", ["CyberMetal", "CyberFrame"])
    end = BARREL_END
    b.tube([(m(y0 + 2.0), m(BARREL_R)), (m(end - 1.2), m(BARREL_R)), (m(end - 0.3), m(BARREL_R - 0.4)),
            (m(end), m(BARREL_R - 1.0))],
           [(m(y0 + 2.0), m(BORE_R)), (m(end - 2.0), m(BORE_R)), (m(end), m(BORE_R + 0.8))], "CyberMetal", 28,
           centre=(0.0, 0.0, m(BORE_Z)))
    # A dark collar where it leaves the face.
    b.lathe([(m(y1 - 0.9), m(BARREL_R + 0.9)), (m(y1 + 0.6), m(BARREL_R + 0.9)), (m(y1 + 1.0), m(BARREL_R + 0.3)),
             (m(y1 + 1.0), m(BARREL_R))], "CyberFrame", 28, centre=(0.0, 0.0, m(BORE_Z)), cap=False)
    # The front sight: a post on the block's top with a glowing dot on its back.
    b.prism(poly([(106.5, z1 - 0.5), (101.0, z1 - 0.5), (101.8, SIGHT_Z, 0.5), (105.2, SIGHT_Z, 0.5)]), "x",
            m(-1.7), m(1.7), "CyberFrame")
    b.lathe([(0.0, 0.0), (0.0, m(0.6)), (m(0.3), m(0.6)), (m(0.3), 0.0)], "CyberLine", 12,
            centre=(0.0, m(101.45), m(SIGHT_Z - 1.4)))
    bar = b.build()
    for p in bar.data.polygons:
        p.use_smooth = True
    bar.data.set_sharp_from_angle(angle=hs.SHARP_ANGLE)
    return hs.join("Muzzle", [ob, bar])


def rail() -> object:
    """The rail under the shroud: a dovetail with cross slots, the torch's clamp seat."""
    y0, y1 = RAIL_Y
    z0, z1 = RAIL_Z
    hw = RAIL_HW
    sec = [(m(-hw + 1.6), m(z0)), (m(hw - 1.6), m(z0)), (m(hw), m(z0 + 1.6)), (m(hw - 1.4), m(z0 + 3.0)),
           (m(hw - 1.4), m(z1)), (m(-hw + 1.4), m(z1)), (m(-hw + 1.4), m(z0 + 3.0)), (m(-hw), m(z0 + 1.6))]
    b = hs.Builder("Rail", ["CyberFrame"])
    b.prism(sec, "y", m(y0), m(y1), "CyberFrame")
    ob = b.build()
    pitch = (y1 - y0 - 6.0) / RAIL_SLOTS
    cut = [box("c_slot", (-hw - 1.0, y0 + 3.0 + pitch * (i + 0.5) - 1.6, z0 - 1.0),
               (hw + 1.0, y0 + 3.0 + pitch * (i + 0.5) + 1.6, z0 + 2.4), "CyberFrame") for i in range(RAIL_SLOTS)]
    hs.cut(ob, cut)
    return hs.finish(ob, m(0.5), 1)


# ------------------------------------------------------------------------------------------------------------- slide

def slide() -> object:
    """The slide between the shroud and the rear block: chamfered top edges, the glowing core in a barred window on
    each side and a slot on top, slanted cocking grooves at the back, and a glowing line along each flank."""
    (y0, y1), (z0, z1), hw = SLIDE_Y, SLIDE_Z, SLIDE_HW
    ch = 2.0
    sec = [(m(-hw), m(z0)), (m(hw), m(z0)), (m(hw), m(z1 - ch)), (m(hw - ch), m(z1)), (m(-hw + ch), m(z1)),
           (m(-hw), m(z1 - ch))]
    b = hs.Builder("SlideBlock", ["CyberMetal"])
    b.prism(sec, "y", m(y0), m(y1), "CyberMetal")
    ob = b.build()
    window = [(25.5, 11.0, 1.5), (8.5, 11.0, 1.5), (8.5, 24.5, 1.5), (25.5, 24.5, 1.5)]
    cut = []
    for sx in (-1, 1):
        cut.append(side_recess("c_window", window, sx, hw, 1.6))
        for i in range(6):
            y = -26.0 + i * 3.2
            cut.append(side_recess("c_groove", slanted(y, 8.0, 27.0, 3.0, 1.3), sx, hw, 0.8))
        cut.append(side_recess("c_line", [(5.0, 4.2), (-28.0, 4.2), (-28.0, 5.8), (5.0, 5.8)], sx, hw, 0.7))
    top = hs.Builder("c_top", ["CyberMetal"])
    top.prism(hs.rounded_rect(m(4.0), m(11.0), m(1.5), 3), "z", m(z1 - 1.5), m(z1 + 2.0), "CyberMetal",
              offset=(0.0, m(-8.0), 0.0))
    cut.append(top.build())
    hs.cut(ob, cut)
    hs.finish(ob, m(0.9), 2)
    b = hs.Builder("SlideBits", ["CyberCore", "CyberMetal", "CyberLine"])
    for sx in (-1, 1):
        lo, hi = xs(sx, hw - 2.8, hw - 1.2)
        b.prism(poly(window), "x", m(lo), m(hi), "CyberCore")
        # Two bars across the window, flush with the flank.
        for y in (14.2, 19.8):
            lo, hi = xs(sx, hw - 1.7, hw - 0.05)
            b.box((m(lo), m(y - 0.7), m(10.5)), (m(hi), m(y + 0.7), m(25.0)), "CyberMetal")
        lo, hi = xs(sx, hw - 1.4, hw - 0.3)
        b.box((m(lo), m(-27.6), m(4.5)), (m(hi), m(4.6), m(5.5)), "CyberLine")
    b.prism(hs.rounded_rect(m(3.6), m(10.6), m(1.2), 3), "z", m(z1 - 3.0), m(z1 - 1.0), "CyberCore",
            offset=(0.0, m(-8.0), 0.0))
    b.box((m(-4.2), m(-8.6), m(z1 - 1.6)), (m(4.2), m(-7.4), m(z1 - 0.05)), "CyberMetal")
    bits = b.build()
    bits.data.polygons.foreach_set("use_smooth", [False] * len(bits.data.polygons))
    return hs.join("Slide", [ob, bits])


# ------------------------------------------------------------------------------------------------------- rear block

def hexagon(c: tuple, r: float, grow: float = 0.0) -> list:
    """A hexagon in the side view, pointy front and back, as (y, z, fillet) mm."""
    rr = r + grow
    return [(c[0] + rr * math.cos(math.radians(a)), c[1] + rr * math.sin(math.radians(a)) * HEX_SQUASH, 1.0)
            for a in range(0, 360, 60)]


def rear_block() -> list:
    """The rear block over the slide's back, its hex plate and screws; the finned cap behind it; the rear sight."""
    ob = side("RearBlock", REAR, SHROUD_HW, "CyberSlab")
    top_chamfer(ob, SHROUD_HW, 37.0, TOP_CHAMFER)
    cut = []
    for sx in (-1, 1):
        cut.append(side_step("c_skirt", SHROUD_HW, REAR_SKIRT, (-120.0, -29.0), sx))
        cut.append(side_recess("c_hex", hexagon(HEX_C, HEX_R), sx, SHROUD_HW, 1.0))
        # A glowing slot low on the block, behind the hex plate.
        cut.append(side_recess("c_lslot", [(-83.0, -6.5, 0.8), (-60.0, -6.5, 0.8), (-60.0, -4.3, 0.8),
                                           (-83.0, -4.3, 0.8)], sx, SHROUD_HW, 0.9))
    hs.cut(ob, cut)
    hs.finish(ob, m(1.5), 3)
    b = hs.Builder("RearBits", ["CyberSlab", "CyberMetal", "CyberLine", "CyberFrame"])
    for sx in (-1, 1):
        # The hex plate: a slightly smaller plate in the recess, its face 0.35 mm under the block's side.
        lo, hi = xs(sx, SHROUD_HW - 1.6, SHROUD_HW - 0.35)
        b.prism(poly(hexagon(HEX_C, HEX_R, -0.9)), "x", m(lo), m(hi), "CyberSlab")
        screw(b, sx, HEX_C[0] + 9.0, HEX_C[1], SHROUD_HW - 0.35, 1.5)
        screw(b, sx, -87.5, -10.5, SHROUD_HW - REAR_SKIRT[1])
        screw(b, sx, -38.0, 27.0, SHROUD_HW)
        lo, hi = xs(sx, SHROUD_HW - 1.5, SHROUD_HW - 0.45)
        b.prism(poly([(-82.6, -6.1, 0.6), (-60.4, -6.1, 0.6), (-60.4, -4.7, 0.6), (-82.6, -4.7, 0.6)]), "x", m(lo),
                m(hi), "CyberLine")
    bits = b.build()
    vents = []
    for sx in (-1, 1):
        for i in range(3):
            z = HEX_C[1] - 5.0 + i * 5.0
            vents.append(side_recess("c_vent", [(HEX_C[0] + 3.0, z - 1.0, 0.9), (HEX_C[0] - 11.0, z - 1.0, 0.9),
                                                (HEX_C[0] - 11.0, z + 1.0, 0.9), (HEX_C[0] + 3.0, z + 1.0, 0.9)], sx,
                                     SHROUD_HW - 0.35, 0.8))
    hs.cut(bits, vents)
    rs = rear_sight()
    return [ob, bits, rear_cap(), rs]


def rear_cap() -> object:
    """The finned cap at the very back: grooves round its sides and back in two bands, a plain band between them
    with a glowing ring on each side and a glowing line across the back."""
    (y0, y1), (z0, z1), hw = REAR_CAP_Y, REAR_CAP_Z, REAR_CAP_HW
    ch = 2.2
    rings = []
    for y, d in ((y0, ch), (y0 + ch, 0.0), (y1, 0.0)):
        rings.append([(m(-hw + d), m(y), m(z0 + d)), (m(hw - d), m(y), m(z0 + d)), (m(hw - d), m(y), m(z1 - d)),
                      (m(-hw + d), m(y), m(z1 - d))])
    b = hs.Builder("RearCap", ["CyberMetal"])
    b.loft(rings, "CyberMetal")
    ob = b.build()
    cut = []
    for za, zb in FIN_ZONES:
        pitch = (zb - za) / FIN_COUNT
        for i in range(FIN_COUNT):
            z = za + pitch * (i + 0.5)
            g = box("c_fin", (-30.0, y0 - 5.0, z - 0.8), (30.0, y1 - 0.8, z + 0.8), "CyberMetal")
            inner = box("c_in", (-hw + 1.8, y0 + 1.8, z0 - 5.0), (hw - 1.8, y1 + 5.0, z1 + 5.0), "CyberMetal")
            hs.cut(g, [inner])
            cut.append(g)
    for sx in (-1, 1):
        ring = hs.Builder("c_ring", ["CyberMetal"])
        place(ring, ring.lathe([(m(-1.2), m(4.4)), (m(1.0), m(4.4))], "CyberMetal", 24, axis="x"), sx,
              (m(sx * hw), m(-102.5), m(14.0)))
        cut.append(ring.build())
    back = hs.Builder("c_back", ["CyberMetal"])
    back.box((m(-9.0), m(y0 - 3.0), m(12.8)), (m(9.0), m(y0 + 0.8), m(15.2)), "CyberMetal")
    cut.append(back.build())
    hs.cut(ob, cut)
    hs.finish(ob, m(0.5), 2)
    b = hs.Builder("CapGlow", ["CyberLine", "CyberMetal"])
    for sx in (-1, 1):
        # A glowing ring round a metal button in each side's round recess.
        at = (m(sx * hw), m(-102.5), m(14.0))
        place(b, b.tube([(m(-0.9), m(4.0)), (m(-0.3), m(4.0))], [(m(-0.9), m(2.6)), (m(-0.3), m(2.6))], "CyberLine",
                        24, axis="x"), sx, at)
        place(b, b.lathe([(m(-1.5), m(2.5)), (m(-0.5), m(2.5)), (m(-0.2), m(2.0)), (m(-0.2), 0.0)], "CyberMetal", 16,
                         axis="x"), sx, at)
    b.box((m(-8.4), m(y0 - 0.2), m(13.3)), (m(8.4), m(y0 + 1.0), m(14.7)), "CyberLine")
    glow = b.build()
    return hs.join("RearCapAll", [ob, glow])


def rear_sight() -> object:
    """The rear sight: a wide block on the rear block's top, sloped front and back, a square notch and a glowing line
    under it on its back face."""
    y = REAR_SIGHT_Y
    b = hs.Builder("RearSight", ["CyberFrame"])
    b.prism(poly([(y + 5.5, 36.6), (y - 4.0, 36.6), (y - 3.2, SIGHT_Z + 1.8, 0.4), (y + 3.2, SIGHT_Z + 1.8, 0.4)]),
            "x", m(-6.5), m(6.5), "CyberFrame")
    ob = b.build()
    notch = box("c_notch", (-1.6, y - 8.0, SIGHT_Z), (1.6, y + 8.0, SIGHT_Z + 5.0), "CyberFrame")
    hs.cut(ob, [notch])
    hs.finish(ob, m(0.3), 1)
    return ob


# ------------------------------------------------------------------------------------------------------------- frame

def frame() -> list:
    """The frame: the dust cover under the slide, the trigger guard (narrower), the grip with its windows, finger
    scallops and back strap grooves; the selector's track and lights, the release button, takedown lever and pins."""
    upper = side("FrameUpper", [(52.0, 0.0), (52.0, -21.0), (-90.0, -21.0), (-93.5, -7.0), (-93.5, 0.0)],
                 FRAME_HW, "CyberSlab")
    guard = side("Guard", GUARD_LOOP, GUARD_HW, "CyberSlab")
    web = side("Web", GUARD_WEB, FRAME_HW, "CyberSlab")
    grip = side("Grip", GRIP, FRAME_HW, "CyberSlab")
    hs.cut(upper, [guard, web, grip], "UNION")
    ob = upper
    ob.name = "Frame"
    cut = [side("c_guard", GUARD_HOLE, 30.0, "CyberSlab")]
    (ty0, ty1), (tz0, tz1), thw = TRIGGER_SLOT
    cut.append(box("c_tslot", (-thw, ty0, tz0), (thw, ty1, tz1), "CyberSlab"))
    for sx in (-1, 1):
        cut.append(side_recess("c_window", GRIP_WINDOW, sx, FRAME_HW, WINDOW_DEPTH))
        cut.append(side_recess("c_housing", HOUSING, sx, FRAME_HW, 1.6))
        # A channel along the guard's bottom bar.
        cut.append(side_recess("c_gch", [(32.0, -44.1, 0.6), (0.0, -44.1, 0.6), (0.0, -42.9, 0.6), (32.0, -42.9, 0.6)],
                               sx, GUARD_HW, 0.6))
        # Grooves down the guard's front and the seam lines between the dust cover and the guard.
        for z in (-37.0, -41.0):
            cut.append(side_recess("c_gg", [(43.0, z - 0.5), (37.0, z - 0.5), (37.0, z + 0.5), (43.0, z + 0.5)], sx,
                                   GUARD_HW, 0.5))
    # Serrations down the front strap (the old model's teeth), through its whole width.
    for i in range(FRONT_SERRATIONS):
        z = -53.0 - i * 9.0
        yf = _front_y(z)
        cut.append(side("c_fs", [(yf + 4.0, z - 2.2), (yf - 2.5, z - 1.0), (yf - 2.5, z + 1.0), (yf + 4.0, z + 2.2)],
                        30.0, "CyberSlab"))
    # A groove round the grip's shell just above the base pad.
    for sx in (-1, 1):
        cut.append(side_recess("c_gring", [(-40.0, -120.6), (-130.0, -120.6), (-130.0, -119.4), (-40.0, -119.4)], sx,
                               FRAME_HW, 0.8))
    # Back strap grooves: across the back of the grip.
    for i in range(7):
        z = -40.0 - i * 9.0
        yb = _back_y(z)
        g = hs.Builder("c_bs", ["CyberSlab"])
        g.box((m(-6.5), m(yb - 3.0), m(z - 1.3)), (m(6.5), m(yb + 2.0), m(z + 1.3)), "CyberSlab")
        cut.append(g.build())
    hs.cut(ob, cut)
    hs.finish(ob, m(1.2), 2)
    b = hs.Builder("FrameBits", ["CyberLine", "CyberMetal", "CyberFrame", "CyberSlab"])
    for sx in (-1, 1):
        # The selector's dark housing, sunk in the frame, with the track cut in it and the glowing line in the track.
        lo, hi = xs(sx, HOUSING_FACE - 0.85, HOUSING_FACE - 0.55)
        b.prism(poly([(TRACK[0][1] - 0.6, -5.6, 0.5), (TRACK[0][0] + 0.6, -5.6, 0.5), (TRACK[0][0] + 0.6, -4.4, 0.5),
                      (TRACK[0][1] - 0.6, -4.4, 0.5)]), "x", m(lo), m(hi), "CyberLine")
        for y in LIGHT_Y:
            light(b, sx, y, LIGHT_Z, HOUSING_FACE, LIGHT_R)
        screw(b, sx, -98.0, -72.0, FRAME_HW)
        screw(b, sx, -110.5, -113.0, FRAME_HW)
        # The ribbed magazine release above the grip's front (both sides, as the cell's catch).
        lo, hi = xs(sx, FRAME_HW - 0.5, FRAME_HW + 0.9)
        b.prism(poly([(-31.0, -17.5, 0.8), (-43.0, -17.5, 0.8), (-43.0, -12.0, 0.8), (-31.0, -12.0, 0.8)]), "x",
                m(lo), m(hi), "CyberFrame")
        for i in range(4):
            y = -33.0 - i * 2.8
            lo2, hi2 = xs(sx, FRAME_HW + 0.8, FRAME_HW + 1.3)
            b.box((m(lo2), m(y - 0.6), m(-16.8)), (m(hi2), m(y + 0.6), m(-12.7)), "CyberFrame")
        # The takedown lever ahead of the track.
        lo, hi = xs(sx, FRAME_HW - 0.3, FRAME_HW + 1.3)
        b.prism(poly([(45.0, -12.8, 1.0), (35.0, -14.2, 2.0), (35.0, -8.8, 2.0), (45.0, -7.8, 1.0)]), "x", m(lo),
                m(hi), "CyberMetal")
        screw(b, sx, 37.6, -11.5, FRAME_HW + 1.3, 1.5)
    pin(b, -86.0, -16.5, FRAME_HW, 1.5)
    bits = b.build()
    bits.data.polygons.foreach_set("use_smooth", [True] * len(bits.data.polygons))
    bits.data.set_sharp_from_angle(angle=hs.SHARP_ANGLE)
    return [ob, bits, housing()]


def housing() -> object:
    """The selector's dark housing plates, one in each side's recess, the track cut in each."""
    b = hs.Builder("Housing", ["CyberFrame"])
    for sx in (-1, 1):
        lo, hi = xs(sx, HOUSING_FACE - 1.2, HOUSING_FACE)
        b.prism(poly([(p[0], p[1], 1.2) for p in HOUSING_IN]), "x", m(lo), m(hi), "CyberFrame")
    ob = b.build()
    tr = [(TRACK[0][1], TRACK[1][0], 1.0), (TRACK[0][0], TRACK[1][0], 1.0), (TRACK[0][0], TRACK[1][1], 1.0),
          (TRACK[0][1], TRACK[1][1], 1.0)]
    hs.cut(ob, [side_recess("c_track", tr, sx, HOUSING_FACE, 0.9, "CyberFrame") for sx in (-1, 1)])
    return hs.finish(ob, m(0.4), 1)


def _front_y(z: float) -> float:
    """The front strap's y (mm) at height z, on the frame's outline."""
    pts = [(-27.5, -36.0), (-31.5, -60.0), (-54.0, -126.0)]
    for (ya, za), (yb, zb) in zip(pts, pts[1:]):
        if zb <= z <= za:
            return ya + (yb - ya) * (z - za) / (zb - za)
    return pts[-1][0]


def _back_y(z: float) -> float:
    """The back strap's y (mm) at height z, on the frame's outline."""
    pts = [(-86.0, -22.0), (-99.0, -62.0), (-114.0, -118.0)]
    for (ya, za), (yb, zb) in zip(pts, pts[1:]):
        if zb <= z <= za:
            return ya + (yb - ya) * (z - za) / (zb - za)
    return pts[-1][0]


# --------------------------------------------------------------------------------------------- trigger and selector

def trigger() -> object:
    """The old model's curved blade, a little longer (its foot 3 mm above the guard's floor) and stood upright:
    the finger face hollow, the foot curling slightly forward of the root (owner, 2026-11-05)."""
    blade = [(1.9, -11.0), (8.6, -13.4, 1.0), (7.0, -19.0, 5.0), (6.6, -27.0, 8.0), (8.2, -35.5, 1.2),
             (6.0, -37.0, 1.2), (3.6, -35.0, 1.2), (2.6, -28.0, 8.0), (2.0, -19.5, 5.0), (1.2, -11.3)]
    ob = side("Trigger", blade, 2.8, "CyberFrame")
    return hs.finish(ob, m(0.4), 2)


def selector() -> object:
    """The fire-mode slider: a ribbed thumb piece on each side of the frame, joined through it."""
    b = hs.Builder("Selector", ["CyberFrame", "CyberMetal"])
    for sx in (-1, 1):
        lo, hi = xs(sx, FRAME_HW - 0.8, 18.2)
        b.prism(poly([(12.3, -8.8, 1.0), (4.2, -8.8, 1.0), (4.2, -1.6, 1.0), (12.3, -1.6, 1.0)]), "x", m(lo), m(hi),
                "CyberFrame")
        for y in (6.2, 8.25, 10.3):
            lo2, hi2 = xs(sx, 18.1, 18.4)
            b.box((m(lo2), m(y - 0.45), m(-8.0)), (m(hi2), m(y + 0.45), m(-2.4)), "CyberMetal")
    ob = b.build()
    return hs.finish(ob, m(0.3), 1, weighted=False)


# ---------------------------------------------------------------------------------------------------------- magazine

def magazine() -> object:
    """The power cell: its sides (seen through the grip's windows) ribbed across, a glowing ring round a metal
    button on each side, and a stepped metal base pad with a dark foot."""
    ob = side("Cell", MAG, MAG_HW, "CyberFrame")
    cut = []
    for sx in (-1, 1):
        for i in range(10):
            z = -32.0 - i * 8.5
            if abs(z - CELL_RING[1]) < 9.0:
                continue
            if abs(z - CELL_RING[1]) < 13.5:
                y = _mag_front(z)
                cut.append(side_recess("c_wide", [(y + 2.0, z - 1.5), (y - 60.0, z - 1.5), (y - 60.0, z + 1.5),
                                                  (y + 2.0, z + 1.5)], sx, MAG_HW, 0.8, "CyberFrame"))
                continue
            y = _mag_front(z)
            cut.append(side_recess("c_rib", [(y + 2.0, z - 0.9), (y - 60.0, z - 0.9), (y - 60.0, z + 0.9),
                                             (y + 2.0, z + 0.9)], sx, MAG_HW, 0.6, "CyberFrame"))
        r = hs.Builder("c_ring", ["CyberFrame"])
        place(r, r.lathe([(m(-1.0), m(5.2)), (m(1.0), m(5.2))], "CyberFrame", 28, axis="x"), sx,
              (m(sx * MAG_HW), m(CELL_RING[0]), m(CELL_RING[1])))
        cut.append(r.build())
    hs.cut(ob, cut)
    hs.finish(ob, m(0.5), 1)
    b = hs.Builder("CellBits", ["CyberCore", "CyberMetal", "CyberFrame"])
    for sx in (-1, 1):
        at = (m(sx * MAG_HW), m(CELL_RING[0]), m(CELL_RING[1]))
        place(b, b.tube([(m(-1.6), m(4.9)), (m(-0.7), m(4.9))], [(m(-1.6), m(3.2)), (m(-0.7), m(3.2))], "CyberCore",
                        28, axis="x"), sx, at)
        place(b, b.lathe([(m(-2.5), m(3.1)), (m(-0.9), m(3.1)), (m(-0.4), m(2.5)), (m(-0.4), 0.0)], "CyberMetal", 20,
                         axis="x"), sx, at)
    bits = b.build()
    bits.data.polygons.foreach_set("use_smooth", [True] * len(bits.data.polygons))
    bits.data.set_sharp_from_angle(angle=hs.SHARP_ANGLE)
    pad = side("Pad", PAD, PAD_HW, "CyberMetal")
    cut = [side_recess("c_padg", [(-50.0, -134.5), (-120.0, -134.5), (-120.0, -133.0), (-50.0, -133.0)], sx, PAD_HW,
                       0.7, "CyberMetal") for sx in (-1, 1)]
    cut.append(side("c_foot", [(-50.0, -160.0), (-120.0, -160.0), (-120.0, -142.5), (-50.0, -142.5)], 30.0,
                    "CyberMetal"))
    hs.cut(pad, cut)
    hs.finish(pad, m(0.6), 2)
    foot = side("Foot", [(-62.5, -142.0), (-114.5, -142.0), (-113.5, -150.8, 2.0), (-64.5, -150.8, 2.0)], PAD_HW - 0.8,
                "CyberFrame")
    hs.finish(foot, m(0.6), 2)
    mag = hs.join("Magazine", [ob, bits, pad, foot])
    return mag


def _mag_front(z: float) -> float:
    (ya, za), (yb, zb) = MAG[0], MAG[3]
    return ya + (yb - ya) * (z - za) / (zb - za)


# ------------------------------------------------------------------------------------------------------------ figure

def figure() -> object:
    """The figures' cut-down copy: the silhouette in a couple of hundred faces."""
    b = hs.Builder("Figure", ["CyberSlab", "CyberMetal", "CyberFrame", "CyberLine"])
    b.prism([(m(p[0]), m(p[1])) for p in SHROUD], "x", m(-SHROUD_HW), m(SHROUD_HW), "CyberSlab")
    b.prism([(m(p[0]), m(p[1])) for p in REAR], "x", m(-SHROUD_HW), m(SHROUD_HW), "CyberSlab")
    b.box((m(-SLIDE_HW), m(-31.0), m(SLIDE_Z[0])), (m(SLIDE_HW), m(40.0), m(SLIDE_Z[1])), "CyberMetal")
    b.box((m(-CAP_HW), m(CAP_Y[0]), m(CAP_Z[0])), (m(CAP_HW), m(CAP_Y[1]), m(CAP_Z[1])), "CyberMetal")
    b.box((m(-REAR_CAP_HW), m(REAR_CAP_Y[0]), m(REAR_CAP_Z[0])), (m(REAR_CAP_HW), m(REAR_CAP_Y[1]), m(REAR_CAP_Z[1])),
          "CyberMetal")
    b.lathe([(m(CAP_Y[1]), m(BARREL_R)), (m(BARREL_END), m(BARREL_R))], "CyberMetal", 8, centre=(0.0, 0.0, m(BORE_Z)))
    # The frame's outline: the guard loop's front (as the hands' model), its floor, the grip and the tang.
    outline = ([(52.0, 0.0)] + [(p[0], p[1]) for p in GUARD_LOOP[:5]]
               + [(-20.0, -47.0), (-27.5, -38.0), (-54.0, -126.0), (-115.0, -126.0), (-86.0, -22.0), (-104.5, -10.5),
                  (-93.5, 0.0)])
    b.prism([(m(p[0]), m(p[1])) for p in outline], "x", m(-FRAME_HW), m(FRAME_HW), "CyberSlab")
    b.prism([(m(p[0]), m(p[1])) for p in [(-55.5, -126.0), (-116.0, -126.0), (-114.5, -150.0), (-63.0, -150.0)]],
            "x", m(-PAD_HW), m(PAD_HW), "CyberMetal")
    for sx in (-1, 1):
        lo, hi = xs(sx, FRAME_HW, FRAME_HW + 0.2)
        b.prism([(m(p[0]), m(p[1])) for p in GRIP_WINDOW], "x", m(lo), m(hi), "CyberFrame")
        lo, hi = xs(sx, SLIDE_HW, SLIDE_HW + 0.2)
        b.box((m(lo), m(8.5), m(11.0)), (m(hi), m(25.5), m(24.5)), "CyberLine")
    ob = b.build()
    ob.data.polygons.foreach_set("use_smooth", [False] * len(ob.data.polygons))
    return ob


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


# The old file's clips, per frame at 60 fps: the slide's travel back (m), the trigger's turn (degrees about x), the
# selector's travel forward (m) and the magazine's (y, z) offset from its rest (m). Keys are (frame, value) and the
# value runs straight between them, as the old file's linear samples.
SLIDE_BACK = 0.014
TRIGGER_TURN = -17.18
FIRE = {
    "slide": [(0, 0.0), (1, -0.007), (2, -SLIDE_BACK), (4, -SLIDE_BACK), (5, -0.0118), (6, -0.007), (7, -0.0022),
              (8, 0.0)],
    "trigger": [(0, 0.0), (1, TRIGGER_TURN * 0.5), (2, TRIGGER_TURN), (4, TRIGGER_TURN), (5, -12.73), (6, -4.46),
                (7, 0.0), (8, 0.0)],
}
SELECTOR = {"selector": [(0, 0.0), (12, SELECTOR_TRAVEL * MM)]}
# The reload: the cell drops along the rake (frames 4 to 20), is gone until 34, a new one is at 62 % of the way out
# at 35 and goes home by 58 with a small overshoot (the old file's samples).
REST = (-0.0819, -0.1209)
RELOAD_SAMPLES = [
    (4, (-0.0819, -0.1209)), (5, (-0.0820, -0.1211)), (6, (-0.0824, -0.1226)), (7, (-0.0836, -0.1267)),
    (8, (-0.0861, -0.1354)), (9, (-0.0902, -0.1492)), (10, (-0.0954, -0.1673)), (11, (-0.1016, -0.1884)),
    (12, (-0.1084, -0.2117)), (13, (-0.1155, -0.2361)), (14, (-0.1226, -0.2605)), (15, (-0.1295, -0.2840)),
    (16, (-0.1357, -0.3055)), (17, (-0.1411, -0.3240)), (18, (-0.1454, -0.3385)), (19, (-0.1481, -0.3479)),
    (20, (-0.1491, -0.3513)), (34, (-0.1491, -0.3513)), (35, (-0.1239, -0.2649)), (36, (-0.1180, -0.2446)),
    (37, (-0.1128, -0.2268)), (38, (-0.1082, -0.2112)), (39, (-0.1043, -0.1976)), (40, (-0.1009, -0.1860)),
    (41, (-0.0980, -0.1761)), (42, (-0.0956, -0.1678)), (43, (-0.0935, -0.1608)), (44, (-0.0919, -0.1551)),
    (45, (-0.0905, -0.1505)), (46, (-0.0894, -0.1467)), (47, (-0.0886, -0.1437)), (48, (-0.0878, -0.1412)),
    (49, (-0.0872, -0.1391)), (50, (-0.0867, -0.1373)), (51, (-0.0861, -0.1354)), (52, (-0.0856, -0.1335)),
    (53, (-0.0849, -0.1313)), (54, (-0.0841, -0.1286)), (55, (-0.0832, -0.1254)), (56, (-0.0823, -0.1223)),
    (57, (-0.0816, -0.1199)), (58, (-0.0813, -0.1190)), (59, (-0.0814, -0.1193)), (60, (-0.0816, -0.1199)),
    (61, (-0.0818, -0.1206)), (62, (-0.0819, -0.1209)), (66, (-0.0819, -0.1209)),
]
# The inspect: the cell eases out a little (frames 20 to 34), waits, and eases home with a small overshoot.
INSPECT_SAMPLES = [
    (20, (-0.0819, -0.1209)), (34, (-0.0864, -0.1363)), (84, (-0.0864, -0.1363)), (94, (-0.0816, -0.1199)),
    (98, (-0.0819, -0.1209)), (120, (-0.0819, -0.1209)),
]
CLIPS = {
    "Fire": (8, FIRE),
    "Selector": (12, SELECTOR),
    "Reload": (66, {"magazine": [(0, REST)] + RELOAD_SAMPLES}),
    "Inspect": (120, {"magazine": [(0, REST)] + INSPECT_SAMPLES}),
}
EASED = {"Inspect"}


def _value(keys: list, f: int, eased: bool):
    if f <= keys[0][0]:
        return keys[0][1]
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if f <= f1:
            u = (f - f0) / max(1, f1 - f0)
            u = ease(u) if eased else u
            if isinstance(v0, tuple):
                return tuple(a + (b - a) * u for a, b in zip(v0, v1))
            return v0 + (v1 - v0) * u
    return keys[-1][1]


def clips(arm: bpy.types.Object) -> None:
    arm.animation_data_create()
    ad = arm.animation_data
    for clip, (frames, tracks) in CLIPS.items():
        act = bpy.data.actions.new(clip)
        ad.action = act
        for f in range(frames + 1):
            for pb in arm.pose.bones:
                pb.rotation_mode = "QUATERNION"
                rot = Matrix.Identity(3)
                loc = Vector((0.0, 0.0, 0.0))
                if pb.name in tracks:
                    v = _value(tracks[pb.name], f, clip in EASED)
                    if pb.name == "trigger":
                        rot = Matrix.Rotation(math.radians(v), 3, "X")
                    elif pb.name in ("slide", "selector"):
                        loc = Vector((0.0, v, 0.0))
                    elif pb.name == "magazine":
                        loc = Vector((0.0, v[0] - REST[0], v[1] - REST[1]))
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
    materials()
    arm = armature()
    parts = shroud() + rear_block() + frame()
    for ob in parts:
        print("  part %-14s %6d" % (ob.name, hs.tris(ob)))
    body = hs.join("Body", parts)
    body.parent = arm
    for ob, bone in ((slide(), "slide"), (trigger(), "trigger"), (selector(), "selector"), (magazine(), "magazine")):
        hs.parent_to_bone(ob, arm, bone)
    fig = figure()
    fig.parent = arm
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


if __name__ == "__main__":
    build()
