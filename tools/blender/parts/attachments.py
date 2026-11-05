"""The fittable attachments, modelled from the owner's reference photos (BL8, 2026-11-05).

ref_images.zip (art/reference-list.md) has a folder per attachment. Where a folder mixes styles, the model follows
the style most of its photos show, unbranded (no logos, words or trademarked shapes):

- `optic_redDot`: a closed micro reflex sight (red_dot: the two closed-emitter sights) on a low Picatinny riser that
  puts its window on the old sight line, 30.5 mm over the rail.
- `optic_scope2x`: a flip-to-side magnifier (2x_scope: the two magnifier photos): a short body, flat-topped with
  chamfered shoulders, two capped turrets and a side cap, on a hinged mount.
- `optic_scopeVar`: a compact prism scope (variable_scope: all six photos): a boxy objective housing with a sunshade,
  three rails and a fibre front sight, a tapered body to the turret housing (an illumination dial and an elevation
  turret on top, windage on the right), the eyepiece with its diopter ring and a rear aperture sight, on a two-bolt
  clamp.
- `grip_vertical`: a short stubby vertical grip with a textured panel and ribbed sides (vertical_grip).
- `grip_angled`: a swept angled handstop (angled_grip: the two kinesthetic grips), grooved down its front.
- `muzzle_silencer`: a plain tube with rounded ends (silencer); the pistol's slimmer, on a knurled thread adaptor.
- `laser_redLaser`: a small knurled laser module in a rail block (red_laser).
- `light_weaponTorch`: a compact pistol light (weapon_torch: the four X300-style photos): a bezelled head, a squared
  body under a rail clamp with a cross latch, rocker paddles at the back.

Space and contract as docs/CC0_ASSETS.md › Replica models: metres, +Y forward, +Z up, each part's origin on its mount
(the replica's OpticMount, GripMount, BarrelEnd, ThreadEnd or TorchMount / RailMount empty), with its `_Figure`
copy, an optic's `_SightLine`, a silencer's `_Muzzle`, a torch's or laser's `_Beam` and the torch's `_UnderLaser`.
The materials are the parts files' own names (Detail, Furniture, Metal, Rubber, Accent, Lens, LaserLens, TorchLens,
plus LensDot, the red dot's clear coated glass), so ReplicaPaint paints the attachments as it did.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3), after the replicas' own scripts:

    python -I tools/blender/parts/attachments.py <repo root>

It replaces those parts in assets/models/replicaParts/aeg.glb, pistol.glb and cyber.glb (barrels and magazines are
left as they are). Then run tools/blender/replicas/sniper.py, which builds the Sniper Rifle's parts from the AEG's.
Running it again rebuilds the same parts.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "replicas"))

import bpy  # noqa: E402  first: it brings bmesh and mathutils with it
from mathutils import Matrix, Vector  # noqa: E402

import hardsurface as hs  # noqa: E402

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
MM = 0.001

# The parts files written, the replica whose empties place them, and the parts each carries.
FILES = {
    "aeg": ["optic_redDot", "optic_scope2x", "optic_scopeVar", "grip_vertical", "grip_angled", "muzzle_silencer",
            "light_weaponTorch"],
    "pistol": ["muzzle_silencer", "laser_redLaser", "light_weaponTorch"],
    "cyber": ["light_weaponTorch"],
}
# Each part slot's mount empty on the replica, by replica (the pistol's silencer goes on its thread).
MOUNT = {
    "optic_": "OpticMount", "grip_": "GripMount", "light_": "TorchMount", "laser_": "TorchMount",
    "muzzle_": "BarrelEnd",
}
MOUNT_OVERRIDE = {("pistol", "muzzle_"): "ThreadEnd"}

# Materials: colour (sRGB), roughness, metallic, and (glass) alpha and emission. A file's own material of the same
# name is kept when it has one, so a replica's parts keep the colours they had.
MATERIALS = {
    "Detail": (0x2b2e33, 0.5, 0.0, 1.0, 0.0),
    "Furniture": (0x2f333a, 0.56, 0.0, 1.0, 0.0),
    "Metal": (0x4a4f56, 0.38, 0.6, 1.0, 0.0),
    "Rubber": (0x1a1c1f, 0.95, 0.0, 1.0, 0.0),
    "Accent": (0xf2f0ea, 0.45, 0.0, 1.0, 0.0),
    "Lens": (0x4a7088, 0.05, 0.0, 0.55, 0.0),
    "LensDot": (0xc8604a, 0.05, 0.0, 0.2, 0.0),
    "LaserLens": (0xff2a2a, 0.2, 0.0, 1.0, 4.0),
    "TorchLens": (0xdde6ee, 0.1, 0.0, 1.0, 0.0),
    "Fibre": (0xff3a20, 0.3, 0.0, 1.0, 2.0),
}

# Rails, in the part's own space with the rail's face at z 0 and the rail above it (a part hanging under a rail;
# optics are built the other way up): the rail's half width at its widest, how far in that is, and the narrower
# spine past it. Picatinny (the AEG's rails measure 21.2 mm across, widest 3 mm in, 17.4 mm across 5.5 mm in).
PICATINNY = {"half": 10.6, "widest": 3.4, "spine": 8.7, "spine_at": 5.6}
# The pistols' accessory rails (pistol.glb: 24.8 mm across, lips 5 mm deep over a 15.8 mm neck; cyber.glb: 20 mm).
PISTOL_RAIL = {"half": 12.4, "widest": 1.5, "spine": 7.9, "spine_at": 6.5}
CYBER_RAIL = {"half": 10.0, "widest": 1.5, "spine": 8.0, "spine_at": 5.0}


def mm(*v: float) -> tuple:
    return tuple(c * MM for c in v)


def mmp(points: list) -> list:
    return [(x * MM, y * MM) for x, y in points]


def materials() -> None:
    for name, (colour, rough, metal, alpha, emit) in MATERIALS.items():
        if bpy.data.materials.get(name) is not None:
            continue
        m = hs.material(name, colour, rough, metal)
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if alpha < 1.0:
            bsdf.inputs["Alpha"].default_value = alpha
            m.surface_render_method = "BLENDED"
        if emit > 0.0:
            bsdf.inputs["Emission Color"].default_value = bsdf.inputs["Base Color"].default_value
            bsdf.inputs["Emission Strength"].default_value = emit


# ------------------------------------------------------------------------------------------------------- pieces

def cyl(b: hs.Builder, y0: float, y1: float, r: float, mat: str, seg: int = 24, x: float = 0.0, z: float = 0.0,
        chamfer: float = 0.0) -> list:
    """A cylinder along Y from y0 to y1 (mm), radius r, its ends chamfered by `chamfer`."""
    c = chamfer
    prof = [(y0, r - c), (y0 + c, r), (y1 - c, r), (y1, r - c)] if c > 0.0 else [(y0, r), (y1, r)]
    return b.lathe([(a * MM, rr * MM) for a, rr in prof], mat, seg, centre=(x * MM, 0.0, z * MM))


def tube_y(b: hs.Builder, outer: list, inner: list, mat: str, seg: int = 24, x: float = 0.0, z: float = 0.0) -> list:
    return b.tube([(a * MM, r * MM) for a, r in outer], [(a * MM, r * MM) for a, r in inner], mat, seg,
                  centre=(x * MM, 0.0, z * MM))


def lens(b: hs.Builder, y: float, r: float, mat: str, seg: int = 40, x: float = 0.0, z: float = 0.0,
         facing: float = 1.0) -> list:
    """A flat round glass across the Y axis at y, one face, facing +Y (facing 1) or -Y (-1), with its back."""
    ring = [b.bm.verts.new(((x + math.cos(math.tau * i / seg) * r) * MM, y * MM,
                            (z + math.sin(math.tau * i / seg) * r) * MM)) for i in range(seg)]
    front = b.bm.faces.new(ring if facing < 0 else list(reversed(ring)))
    front.normal_update()
    if (front.normal.y > 0) != (facing > 0):
        front.normal_flip()
    front.material_index = b.mat(mat)
    return [front]


def lathe_y(b: hs.Builder, prof: list, mat: str, seg: int = 24, x: float = 0.0, z: float = 0.0,
            cap: bool = True) -> list:
    return b.lathe([(a * MM, r * MM) for a, r in prof], mat, seg, centre=(x * MM, 0.0, z * MM), cap=cap)


def ridged(b: hs.Builder, y0: float, y1: float, r_in: float, r_out: float, ridges: int, mat: str, x: float = 0.0,
           z: float = 0.0, axis: str = "y") -> list:
    """A ring of straight ridges (a knurled or grooved band) round an axis, capped."""
    n = ridges * 2
    rings = []
    for a in (y0, y1):
        ring = []
        for i in range(n):
            t = math.tau * (i + 0.5 * (i % 2)) / n
            r = r_out if i % 2 == 0 else r_in
            u, v = math.cos(t) * r, math.sin(t) * r
            if axis == "y":
                ring.append(((x + u) * MM, a * MM, (z + v) * MM))
            elif axis == "z":
                ring.append(((x + u) * MM, (z + v) * MM, a * MM))
            else:
                ring.append((a * MM, (x + u) * MM, (z + v) * MM))
        rings.append(ring)
    return b.loft(rings, mat)


def disc_z(b: hs.Builder, x: float, y: float, z0: float, z1: float, r: float, mat: str, seg: int = 20,
           chamfer: float = 0.0) -> list:
    """A short cylinder along Z (a dial or screw head seen from above)."""
    c = chamfer
    prof = [(z0, r), (z1 - c, r), (z1, r - c)] if c > 0.0 else [(z0, r), (z1, r)]
    return b.lathe([(a * MM, rr * MM) for a, rr in prof], mat, seg, centre=(x * MM, y * MM, 0.0), axis="z")


def disc_x(b: hs.Builder, x0: float, x1: float, y: float, z: float, r: float, mat: str, seg: int = 20,
           chamfer: float = 0.0) -> list:
    """A short cylinder along X (a side dial or screw head), from x0 to x1 (x1 its outer face)."""
    c = chamfer
    s = 1.0 if x1 > x0 else -1.0
    prof = [(x0, r), (x1 - s * c, r), (x1, r - c)] if c > 0.0 else [(x0, r), (x1, r)]
    return b.lathe([(a * MM, rr * MM) for a, rr in prof], mat, seg, centre=(0.0, y * MM, z * MM), axis="x")


def slot_z(b: hs.Builder, x: float, y: float, z: float, length: float, width: float, angle: float, mat: str) -> list:
    """A screwdriver slot laid on a face looking up: a thin dark bar a hair proud of it."""
    f = b.box(mm(-length / 2, -width / 2, z), mm(length / 2, width / 2, z + 0.06), mat)
    b.transform(f, Matrix.Translation(Vector(mm(x, y, 0.0))) @ Matrix.Rotation(angle, 4, "Z"))
    return f


def hex_x(b: hs.Builder, x0: float, x1: float, y: float, z: float, r: float, mat: str) -> list:
    """A hex nut or socket along X."""
    return b.prism(mmp([(y + r * math.cos(math.tau * i / 6 + math.pi / 6), z + r * math.sin(math.tau * i / 6 +
                                                                                              math.pi / 6))
                        for i in range(6)]), "x", x0 * MM, x1 * MM, mat)


def clamp_profile(rail: dict, top: float, jaw: float) -> list:
    """The cross-section (x, z mm) of a clamp sitting on a rail's face at z 0, the rail below it (an optic's
    clamp): its body up to `top`, its jaws `jaw` thick hooking under the rail's widest point."""
    h, w, s, sa = rail["half"], rail["widest"], rail["spine"], rail["spine_at"]
    gap = 0.35
    inner = h + gap
    lip = s + (h - s) * 0.45 + gap
    bottom = -(w + (sa - w) * 0.7)
    outer = h + jaw
    right = [(outer, top), (outer, bottom + 0.8), (outer - 0.8, bottom), (lip, bottom), (inner, -w), (inner, 0.0)]
    left = [(-x, z) for x, z in reversed(right)]
    return right + left


def rail_clamp(b: hs.Builder, rail: dict, y0: float, y1: float, top: float, jaw: float, mat: str) -> list:
    """A clamp on a rail along Y from y0 to y1 (mm), the rail below z 0."""
    return b.prism(mmp(clamp_profile(rail, top, jaw)), "y", y0 * MM, y1 * MM, mat)


def child_empty(name: str, loc: tuple, parent: bpy.types.Object) -> bpy.types.Object:
    return hs.empty(name, loc, parent)


def rail_clamp_under(b: hs.Builder, rail: dict, y0: float, y1: float, bottom: float, jaw: float, mat: str) -> list:
    """A clamp under a rail (the rail above z 0) along Y, its body down to `bottom` (negative)."""
    prof = [(x, -z) for x, z in reversed(clamp_profile(rail, -bottom, jaw))]
    return b.prism(mmp(prof), "y", y0 * MM, y1 * MM, mat)


def cutter(name: str, faces_fn) -> bpy.types.Object:
    """A throwaway object for a boolean, built by faces_fn(builder)."""
    b = hs.Builder(name, ["Detail"])
    faces_fn(b)
    return b.build()


def box_cutter(lo: tuple, hi: tuple, rot: Matrix = None) -> bpy.types.Object:
    b = hs.Builder("cut", ["Detail"])
    f = b.box(mm(*lo), mm(*hi), "Detail")
    if rot is not None:
        b.transform(f, rot)
    return b.build()


def prism_cutter(poly: list, axis: str, a0: float, a1: float, rot: Matrix = None) -> bpy.types.Object:
    b = hs.Builder("cut", ["Detail"])
    f = b.prism(mmp(poly), axis, a0 * MM, a1 * MM, "Detail")
    if rot is not None:
        b.transform(f, rot)
    return b.build()


# ------------------------------------------------------------------------------------------------------ red dot

# The micro reflex sight on its riser: the riser's top (mm over the rail) and the sight's window. The window's centre
# is the sight line, 30.5 mm over the rail as the earlier red dot's (the rifle aims as before).
RD_RISER_TOP = 14.5
RD_SIGHT_LINE = 30.5
RD_HALF = 13.0
RD_REAR, RD_FRONT = -24.0, 22.0
RD_GLASS_Y = 14.0
RD_GLASS_TILT = math.radians(6.0)


def rd_window(grow: float = 0.0) -> list:
    """The window's outline seen from behind (x, z over the sight's base, mm): narrower at the top, round-cornered."""
    zc = RD_SIGHT_LINE - RD_RISER_TOP
    b0, t0 = zc - 7.6 - grow, zc + 7.9 + grow
    return hs.fillet([(-11.0 - grow, b0, 1.6), (11.0 + grow, b0, 1.6), (9.4 + grow, t0, 3.6),
                      (-9.4 - grow, t0, 3.6)], 4)


def build_red_dot() -> bpy.types.Object:
    z0 = RD_RISER_TOP
    # The riser: a clamp on the rail, a pedestal with a pocket each side, a cross bolt and its nut.
    rb = hs.Builder("rd_riser", ["Detail", "Metal", "Rubber"])
    rail_clamp(rb, PICATINNY, -21.0, 19.0, 4.0, 3.0, "Detail")
    rb.prism(mmp(hs.fillet([(-12.6, -22.0, 2.0), (12.6, -22.0, 2.0), (12.6, 20.0, 2.0), (-12.6, 20.0, 2.0)], 3)),
             "z", 3.6 * MM, z0 * MM, "Detail")
    riser = rb.build()
    cuts = []
    for s in (-1.0, 1.0):
        for ya, yb in ((-17.0, -5.0), (1.0, 13.0)):
            cuts.append(prism_cutter(hs.fillet([(ya, 6.2, 1.2), (yb, 6.2, 1.2), (yb, 12.2, 1.2), (ya, 12.2, 1.2)], 2),
                                     "x", s * 11.6, s * 14.0))
    hs.cut(riser, cuts)
    # Front and back of the pedestal sloped (a lighter look than a block).
    hs.cut(riser, [box_cutter((-20, -40, -2), (20, -22, 30), Matrix.Translation(Vector(mm(0, -22, 4))) @
                              Matrix.Rotation(math.radians(-28), 4, "X") @ Matrix.Translation(Vector(mm(0, 22, -4)))),
                   box_cutter((-20, 20, -2), (20, 40, 30), Matrix.Translation(Vector(mm(0, 20, 4))) @
                              Matrix.Rotation(math.radians(28), 4, "X") @ Matrix.Translation(Vector(mm(0, -20, -4))))])
    hs.finish(riser, bevel=0.0004)
    hw = hs.Builder("rd_hardware", ["Metal", "Rubber"])
    hex_x(hw, -13.6, -16.4, -1.0, -1.6, 3.3, "Metal")
    hex_x(hw, -16.45, -16.5, -1.0, -1.6, 1.0, "Rubber")
    disc_x(hw, 13.6, 15.4, -1.0, -1.6, 3.4, "Metal", 18, 0.5)
    hex_x(hw, 15.4, 15.46, -1.0, -1.6, 1.3, "Rubber")
    hardware = hw.build()
    hs.finish(hardware, bevel=0.0002)

    # The sight: its side outline as a prism across, trimmed by its outline from behind, the window cut through.
    sb = hs.Builder("rd_sight", ["Detail", "Metal", "Rubber", "LensDot"])
    side = hs.fillet([(RD_REAR, 0.0, 0.6), (RD_FRONT, 0.0, 0.6), (RD_FRONT, 2.5, 0.0), (RD_FRONT - 1.4, 25.0, 2.0),
                      (RD_FRONT - 3.2, 27.0, 1.5), (6.5, 27.0, 5.0), (2.5, 13.5, 4.0), (-5.0, 11.5, 2.0),
                      (-21.0, 11.5, 1.6), (RD_REAR, 8.5, 1.0)], 4)
    sb.prism(mmp([(y, z0 + z) for y, z in side]), "x", -RD_HALF * MM, RD_HALF * MM, "Detail")
    sight = sb.build()
    front = hs.fillet([(-RD_HALF, -1.0, 0.0), (RD_HALF, -1.0, 0.0), (RD_HALF, 9.0, 3.0), (11.2, 27.0, 7.0),
                       (-11.2, 27.0, 7.0), (-RD_HALF, 9.0, 3.0)], 6)
    hs.cut(sight, [prism_cutter([(x, z0 + z) for x, z in front], "y", RD_REAR - 2, RD_FRONT + 2)], "INTERSECT")
    win = [(x, z0 + z) for x, z in rd_window()]
    hs.cut(sight, [prism_cutter(win, "y", 3.0, RD_FRONT + 3.0),
                   # The big chamfer on the hood's lower front corners and the rear deck's slanted grooves.
                   box_cutter((-30, -6, -6), (-RD_HALF + 0.2, 6, 6), Matrix.Translation(Vector(mm(-RD_HALF, RD_FRONT,
                                                                                                  z0 + 3.0))) @
                              Matrix.Rotation(math.radians(45), 4, "Z")),
                   box_cutter((RD_HALF - 0.2, -6, -6), (30, 6, 6), Matrix.Translation(Vector(mm(RD_HALF, RD_FRONT,
                                                                                                 z0 + 3.0))) @
                              Matrix.Rotation(math.radians(-45), 4, "Z"))]
           + [box_cutter((s * RD_HALF - 0.7, -0.45, -8), (s * RD_HALF + 2, 0.45, 8),
                         Matrix.Translation(Vector(mm(0, y, z0 + 5.5))) @ Matrix.Rotation(math.radians(40), 4, "X"))
              for s in (-1.0, 1.0) for y in (-18.0, -14.5)])
    hs.finish(sight, bevel=0.0005)

    db = hs.Builder("rd_controls", ["Detail", "Metal", "Rubber", "LensDot"])
    # Elevation on top of the rear deck, windage on the right, the battery cap on the left, the emitter.
    disc_z(db, 0.0, -13.0, z0 + 11.3, z0 + 12.3, 4.2, "Detail", 24, 0.35)
    slot_z(db, 0.0, -13.0, z0 + 12.3, 5.4, 0.7, math.radians(30), "Rubber")
    ridged(db, z0 + 11.4, z0 + 12.0, 4.25, 4.45, 24, "Detail", x=0.0, z=-13.0, axis="z")
    disc_x(db, RD_HALF - 0.4, RD_HALF + 0.7, -15.0, z0 + 5.6, 3.6, "Detail", 22, 0.3)
    hex_x(db, RD_HALF + 0.7, RD_HALF + 0.76, -15.0, z0 + 5.6, 1.1, "Rubber")
    db.prism(mmp(hs.fillet([(7.0, z0 + 2.2, 2.0), (19.0, z0 + 2.2, 2.0), (19.0, z0 + 12.0, 2.0),
                            (7.0, z0 + 12.0, 2.0)], 3)), "x", (-RD_HALF + 0.3) * MM, (-RD_HALF - 0.6) * MM, "Detail")
    db.box(mm(-RD_HALF - 0.66, 12.6, z0 + 4.4), mm(-RD_HALF - 0.6, 13.4, z0 + 9.8), "Rubber")
    db.prism(mmp(hs.fillet([(-2.2, 0.0, 0.8), (2.2, 0.0, 0.8), (2.2, 3.0, 1.2), (-2.2, 3.0, 1.2)], 2)), "y",
             -6.5 * MM, -3.0 * MM, "Detail", offset=(0.0, 0.0, (z0 + 11.4) * MM))
    db.box(mm(-1.1, -2.98, z0 + 12.0), mm(1.1, -2.9, z0 + 13.6), "Rubber")
    controls = db.build()
    hs.finish(controls, bevel=0.0002, segments=1, angle=math.radians(50.0))

    gb = hs.Builder("rd_glass", ["LensDot"])
    f = gb.prism(mmp([(x, z0 + z) for x, z in rd_window(0.8)]), "y", -0.6 * MM, 0.6 * MM, "LensDot")
    pivot = Vector(mm(0.0, 0.0, RD_SIGHT_LINE))
    gb.transform(f, Matrix.Translation(Vector(mm(0.0, RD_GLASS_Y, 0.0))) @ Matrix.Translation(pivot) @
                 Matrix.Rotation(-RD_GLASS_TILT, 4, "X") @ Matrix.Translation(-pivot))
    glass = gb.build()

    ob = hs.join("optic_redDot", [sight, riser, hardware, controls, glass])
    fig = hs.Builder("optic_redDot_Figure", ["Detail"])
    fig.box(mm(-12.6, -21, 0), mm(12.6, 19, z0 + 11.5), "Detail")
    fig.prism(mmp([(5.0, z0), (RD_FRONT, z0), (RD_FRONT - 2.0, z0 + 27.0), (6.0, z0 + 27.0)]), "x", -RD_HALF * MM,
              RD_HALF * MM, "Detail")
    f_ob = fig.build()
    f_ob.parent = ob
    child_empty("optic_redDot_SightLine", mm(0.0, 0.0, RD_SIGHT_LINE), ob)
    return ob


# ------------------------------------------------------------------------------------------------------- 2x scope

# The magnifier: its axis over the rail, its body (front and back of the flat-topped section, the round nose and the
# eyepiece), the hinged mount under it (mm).
S2_AXIS = 46.0
S2_R = 20.4
S2_BACK, S2_BODY_FRONT, S2_FRONT = -30.0, 17.0, 26.0
S2_EYE_GLASS = -28.6
S2_GLASS_R = 15.6


def s2_section(axis: float) -> list:
    """The body's section (x, z mm): a flat top, chamfered shoulders, flat sides and a round belly."""
    top, shoulder, side_lo = 19.6, 10.5, -3.0
    pts = [(11.0, axis + top, 2.0), (S2_R - 0.4, axis + shoulder, 2.0), (S2_R - 0.4, axis + side_lo, 3.0)]
    for i in range(1, 12):
        a = math.radians(-12.0 - 156.0 * i / 12)
        pts.append((math.cos(a) * S2_R, axis + math.sin(a) * S2_R, 0.0))
    pts += [(-(S2_R - 0.4), axis + side_lo, 3.0), (-(S2_R - 0.4), axis + shoulder, 2.0), (-11.0, axis + top, 2.0)]
    return hs.fillet(pts, 3)


def turret(b: hs.Builder, p: hs.Builder, axis: str, base: float, pos: tuple, sign: float, mat: str) -> None:
    """A capped adjustment turret standing out of a face: a boss, a knurled cap, a slotted top (mm). `axis` is the
    turret's axis ("z" up or "x" sideways), `base` the face it stands on, `pos` its place on that face, `sign` its
    direction along the axis. Its knurling and slot go in `p`, which isn't bevelled."""
    def ring(a0: float, a1: float, r: float, seg: int = 28) -> None:
        lo, hi = base + sign * a0, base + sign * a1
        if axis == "z":
            disc_z(b, pos[0], pos[1], min(lo, hi), max(lo, hi), r, mat, seg, 0.3)
        else:
            disc_x(b, lo, hi, pos[0], pos[1], r, mat, seg, 0.3)
    ring(-1.0, 1.8, 9.0)
    lo, hi = base + sign * 1.8, base + sign * 7.2
    if axis == "z":
        ridged(p, min(lo, hi), max(lo, hi), 6.9, 7.4, 24, mat, x=pos[0], z=pos[1], axis="z")
    else:
        ridged(p, min(lo, hi), max(lo, hi), 6.9, 7.4, 24, mat, x=pos[0], z=pos[1], axis="x")
    ring(7.0, 8.4, 6.6)
    if axis == "z":
        slot_z(p, pos[0], pos[1], base + sign * 8.4, 9.0, 1.0, 0.0, "Rubber")
    else:
        x = base + sign * 8.4
        p.box(mm(min(x, x + sign * 0.06), pos[0] - 4.5, pos[1] - 0.5), mm(max(x, x + sign * 0.06), pos[0] + 4.5,
                                                                          pos[1] + 0.5), "Rubber")


def build_scope_2x() -> bpy.types.Object:
    h = S2_AXIS
    bb = hs.Builder("s2_body", ["Detail", "Metal", "Rubber", "Lens"])
    bb.prism(mmp(s2_section(h)), "y", S2_BACK * MM + 0.004, S2_BODY_FRONT * MM, "Detail")
    body = bb.build()
    # A step along each shoulder, and the flat for the side cap.
    hs.cut(body, [box_cutter((-30, S2_BACK + 6, h + 10.5), (30, S2_BODY_FRONT + 1, h + 11.3)),
                  box_cutter((-30, S2_BACK - 1, h + 18.8), (30, S2_BACK + 7, h + 30),
                             Matrix.Translation(Vector(mm(0, S2_BACK + 7, h + 18.8))) @
                             Matrix.Rotation(math.radians(20), 4, "X") @
                             Matrix.Translation(-Vector(mm(0, S2_BACK + 7, h + 18.8))))])
    hs.finish(body, bevel=0.0006)
    eb = hs.Builder("s2_ends", ["Detail", "Metal", "Rubber", "Lens"])
    pb = hs.Builder("s2_plain", ["Detail", "Rubber", "Lens"])
    # The round nose and its lens, the eyepiece and its lens, each in a dark retaining ring.
    lathe_y(eb, [(S2_BODY_FRONT - 0.5, S2_R - 0.6), (S2_FRONT - 3.0, S2_R - 0.6), (S2_FRONT - 2.2, S2_R),
                 (S2_FRONT - 0.6, S2_R), (S2_FRONT, S2_R - 0.6)], "Detail", 40, z=h, cap=False)
    tube_y(pb, [(S2_FRONT, S2_R - 0.6), (S2_FRONT + 0.6, S2_R - 1.4)], [(S2_FRONT, 16.8), (S2_FRONT + 0.6, 16.8)],
           "Rubber", 40, z=h)
    lens(pb, S2_FRONT - 1.6, 16.9, "Lens", 40, z=h, facing=1.0)
    lathe_y(eb, [(S2_BACK + 4.5, S2_R - 0.6), (S2_BACK + 1.6, S2_R - 0.6), (S2_BACK + 1.0, S2_R - 2.2),
                 (S2_BACK, S2_R - 2.2), (S2_BACK - 0.6, S2_R - 2.8)], "Detail", 40, z=h, cap=False)
    tube_y(pb, [(S2_BACK - 0.6, S2_R - 2.8), (S2_BACK - 1.2, S2_R - 3.4)],
           [(S2_BACK - 0.6, 15.8), (S2_BACK - 1.2, 15.8)], "Rubber", 40, z=h)
    lens(pb, S2_EYE_GLASS, 15.9, "Lens", 40, z=h, facing=-1.0)
    # Turrets at the back: elevation on top, windage on the left; the round cap on the left flank.
    turret(eb, pb, "z", h + 19.4, (0.0, -17.5), 1.0, "Detail")
    turret(eb, pb, "x", -(S2_R - 0.6), (-17.5, h + 2.0), -1.0, "Detail")
    disc_x(eb, -(S2_R - 1.2), -(S2_R + 1.4), 3.5, h - 6.0, 7.6, "Detail", 36, 0.6)
    ends = eb.build()
    hs.finish(ends, bevel=0.0003, segments=1, angle=math.radians(50.0))
    plain = pb.build()
    hs.finish(plain, bevel=0.0)

    # The hinged mount: a rail clamp, the lower block, the hinge knuckle along the bore (left), the upper block and
    # the saddle the body sits in.
    mb = hs.Builder("s2_mount", ["Detail", "Metal", "Rubber"])
    rail_clamp(mb, PICATINNY, -13.0, 17.0, 5.0, 3.2, "Detail")
    mb.prism(mmp(hs.fillet([(-12.6, 4.5, 0.0), (12.6, 4.5, 0.0), (12.6, 15.0, 1.5), (-12.6, 15.0, 1.5)], 2)), "y",
             -12.0 * MM, 16.0 * MM, "Detail")
    mb.prism(mmp(hs.fillet([(-12.6, 15.0, 1.0), (12.6, 15.0, 1.0), (12.6, 22.0, 1.0), (-12.6, 22.0, 1.0)], 2)), "y",
             -11.0 * MM, 15.0 * MM, "Detail")
    saddle = [(-13.0, 21.0), (13.0, 21.0), (13.0, h - 14.0)] + \
             [(math.cos(math.radians(-38.0 - 104.0 * i / 8)) * (S2_R + 0.2),
               h + math.sin(math.radians(-38.0 - 104.0 * i / 8)) * (S2_R + 0.2)) for i in range(9)] + \
             [(-13.0, h - 14.0)]
    mb.prism(mmp(saddle), "y", -11.0 * MM, 15.0 * MM, "Detail")
    cyl(mb, -11.0, 15.0, 4.2, "Detail", 20, x=-12.8, z=18.5, chamfer=0.6)
    cyl(mb, -11.6, -11.0, 2.0, "Metal", 14, x=-12.8, z=18.5)
    cyl(mb, 15.0, 15.6, 2.0, "Metal", 14, x=-12.8, z=18.5)
    disc_x(mb, 12.4, 13.4, 2.0, 10.0, 1.8, "Metal", 14, 0.3)
    hex_x(mb, -15.8, -13.4, 2.0, -1.8, 3.2, "Metal")
    disc_x(mb, 15.6, 13.6, 2.0, -1.8, 3.4, "Metal", 18, 0.4)
    mount = mb.build()
    hs.finish(mount, bevel=0.0004)

    ob = hs.join("optic_scope2x", [body, ends, plain, mount])
    fig = hs.Builder("optic_scope2x_Figure", ["Detail"])
    fig.lathe([(S2_BACK * MM, 0.0), (S2_BACK * MM, S2_R * MM), (S2_FRONT * MM, S2_R * MM), (S2_FRONT * MM, 0.0)],
              "Detail", 8, centre=(0.0, 0.0, h * MM))
    fig.box(mm(-12.6, -12, 0), mm(12.6, 16, h - 14), "Detail")
    fig.build().parent = ob
    child_empty("optic_scope2x_SightLine", mm(0.0, 0.0, h), ob)
    return ob


# ------------------------------------------------------------------------------------------------- variable scope

# The prism scope, traced from the owner's side photo (variable_scope › Screenshot 2026-11-04 124208.png, 4.6 px a
# millimetre, the clamp's middle at x 321 px, the rail's face at y 340 px): its axis, the eyepiece, the turret
# housing, the cone and the objective housing with its sunshade (mm along +Y from the mount, mm up from the rail).
SV_AXIS = 32.6
SV_EYE_BACK, SV_EYE_GLASS = -66.0, -64.6
SV_HOUSING = (-40.0, 15.0)
SV_BOX = (33.0, 80.0)
SV_BOX_HW, SV_BOX_LO, SV_BOX_HI = 20.5, 14.5, 52.5
SV_GLASS_R = 12.0


def ring_super(n_pts: int, y: float, hw: float, hh: float, cz: float, n: float) -> list:
    """A ring of points round the Y axis by angle: a circle at n 2, squarer as n grows."""
    pts = []
    for i in range(n_pts):
        t = math.tau * i / n_pts
        c, s = math.cos(t), math.sin(t)
        x = hw * math.copysign(abs(c) ** (2.0 / n), c)
        z = hh * math.copysign(abs(s) ** (2.0 / n), s)
        pts.append((x * MM, y * MM, (cz + z) * MM))
    return pts


def rail_teeth(b: hs.Builder, a0: float, a1: float, count: int, at: float, half: float, depth: float,
               mat: str) -> None:
    """Picatinny teeth on top of a spine: `count` teeth evenly between a0 and a1 along Y, standing `depth` up from z
    `at`, `half` either side across (mm)."""
    pitch = (a1 - a0) / count
    for i in range(count):
        y0, y1 = a0 + i * pitch + pitch * 0.18, a0 + (i + 1) * pitch - pitch * 0.18
        b.prism(mmp([(-half, at), (half, at), (half - 1.0, at + depth), (-half + 1.0, at + depth)]), "y",
                y0 * MM, y1 * MM, mat)


def build_scope_var() -> bpy.types.Object:
    h = SV_AXIS
    # The objective housing: lofted from the tube in front of the turrets out to a squared section, run on to the
    # sunshade, its underside cut rising to the front and its bore hollowed.
    ob_b = hs.Builder("sv_box", ["Detail"])
    n = 48
    ob_b.loft([ring_super(n, SV_HOUSING[1] - 1.0, 15.6, 15.6, h, 2.0),
               ring_super(n, 24.0, 15.6, 15.6, h, 2.0),
               ring_super(n, 28.5, 18.4, 17.6, h + 0.4, 2.8),
               ring_super(n, SV_BOX[0], SV_BOX_HW, (SV_BOX_HI - SV_BOX_LO) / 2, (SV_BOX_HI + SV_BOX_LO) / 2, 4.5),
               ring_super(n, SV_BOX[1], SV_BOX_HW, (SV_BOX_HI - SV_BOX_LO) / 2, (SV_BOX_HI + SV_BOX_LO) / 2, 4.5)],
              "Detail")
    box = ob_b.build()
    slant = math.atan2(21.5 - SV_BOX_LO, SV_BOX[1] - 46.0)
    hs.cut(box, [box_cutter((-40, 0, -30), (40, 60, 0), Matrix.Translation(Vector(mm(0, 46.0, SV_BOX_LO + 0.01))) @
                            Matrix.Rotation(slant, 4, "X")),
                 cutter("bore", lambda b: cyl(b, 60.0, SV_BOX[1] + 5.0, 17.0, "Detail", 32, z=h))])
    hs.finish(box, bevel=0.0005)

    hb = hs.Builder("sv_housing", ["Detail", "Metal", "Rubber"])
    # The turret housing: a rounded block, the collar at its back, the tube to the eyepiece.
    hb.prism(mmp(hs.fillet([(-17.0, 15.6, 6.0), (17.0, 15.6, 6.0), (17.0, 50.0, 11.0), (-17.0, 50.0, 11.0)], 4)),
             "y", SV_HOUSING[0] * MM, SV_HOUSING[1] * MM, "Detail")
    lathe_y(hb, [(-41.5, 15.5), (-41.0, 17.6), (-34.0, 17.6), (-33.0, 16.8)], "Detail", 32, z=h)
    # Pads under the dials, the side caps' bosses.
    disc_z(hb, 0.0, -18.5, 44.0, 51.0, 13.4, "Detail", 32, 0.6)
    disc_z(hb, 0.0, 4.6, 44.0, 50.6, 8.0, "Detail", 28, 0.5)
    for s in (-1.0, 1.0):
        disc_x(hb, s * 12.0, s * 18.6, 5.2, h - 1.1, 10.6, "Detail", 28, 0.5)
    housing = hb.build()
    hs.finish(housing, bevel=0.0006, segments=1)

    db = hs.Builder("sv_dials", ["Detail", "Metal", "Rubber", "Accent"])
    pb = hs.Builder("sv_plain", ["Detail", "Rubber", "Lens", "Fibre", "Accent", "Metal"])
    # The illumination dial (a plain numbered skirt, the knurled cap, a slotted top), the elevation turret.
    disc_z(db, 0.0, -18.5, 50.5, 57.0, 13.6, "Detail", 32, 0.4)
    ridged(pb, 57.0, 62.6, 13.4, 13.95, 30, "Detail", x=0.0, z=-18.5, axis="z")
    disc_z(db, 0.0, -18.5, 62.4, 64.0, 13.0, "Detail", 32, 0.6)
    slot_z(pb, 0.0, -18.5, 64.0, 15.0, 1.2, 0.0, "Rubber")
    for a in (-50.0, -25.0, 0.0, 25.0, 50.0):
        t = math.radians(180.0 + a)
        pb.box(mm(math.cos(t) * 13.62 - 0.3, -18.5 + math.sin(t) * 13.62 - 0.6, 53.0),
               mm(math.cos(t) * 13.62 + 0.3, -18.5 + math.sin(t) * 13.62 + 0.6, 55.0), "Accent")
    disc_z(db, 0.0, 4.6, 50.0, 52.0, 7.4, "Detail", 28, 0.3)
    ridged(pb, 52.0, 59.4, 7.0, 7.45, 22, "Detail", x=0.0, z=4.6, axis="z")
    disc_z(db, 0.0, 4.6, 59.2, 60.4, 6.8, "Detail", 28, 0.5)
    # The side caps: windage on the right, the battery cap on the left, each with a groove ring.
    for s in (-1.0, 1.0):
        disc_x(db, s * 18.4, s * 21.6, 5.2, h - 1.1, 9.8, "Detail", 28, 0.8)
        disc_x(pb, s * 21.62, s * 21.66, 5.2, h - 1.1, 7.6, "Rubber", 36)
        disc_x(db, s * 21.6, s * 22.1, 5.2, h - 1.1, 7.4, "Detail", 28, 0.3)
    db.box(mm(-19.6, -30.0, h - 6.0), mm(-16.0, -24.0, h + 0.4), "Detail")
    # The eyepiece: a flange, the tube, the knurled diopter ring and its face, the glass.
    lathe_y(db, [(SV_HOUSING[0] - 1.0, 16.7), (-47.0, 16.7), (-47.6, 14.0), (-56.0, 14.0), (-56.0, 15.0),
                 (-57.0, 15.0)], "Detail", 32, z=h)
    ridged(pb, -65.0, -57.0, 15.4, 16.2, 24, "Detail", z=h)
    pb.tube([(-66.0 * MM, 15.4 * MM), (-65.0 * MM, 15.4 * MM)], [(-66.0 * MM, 12.6 * MM), (-65.0 * MM, 12.6 * MM)],
            "Rubber", 40, centre=(0.0, 0.0, h * MM))
    lens(pb, SV_EYE_GLASS, 12.8, "Lens", 40, z=h, facing=-1.0)
    lens(pb, 62.0, 17.2, "Lens", 40, z=h, facing=1.0)
    pb.tube([(62.0 * MM, 17.2 * MM), (63.5 * MM, 17.2 * MM)], [(62.0 * MM, 15.0 * MM), (63.5 * MM, 15.0 * MM)],
            "Rubber", 40, centre=(0.0, 0.0, h * MM))
    # Rails on the objective housing: the top one carrying the fibre front sight, one each side.
    db.box(mm(-8.0, SV_BOX[0] + 2.0, SV_BOX_HI - 1.5), mm(8.0, SV_BOX[1] - 0.6, SV_BOX_HI + 2.6), "Detail")
    rail_teeth(db, SV_BOX[0] + 2.0, SV_BOX[1] - 0.6, 5, SV_BOX_HI + 2.6, 10.6, 3.6, "Detail")
    for s in (-1.0, 1.0):
        db.box(mm(s * (SV_BOX_HW - 1.5), 36.0, 24.0), mm(s * (SV_BOX_HW + 1.6), 64.0, 41.0), "Detail")
        pitch = 28.0 / 3
        for i in range(3):
            y0, y1 = 36.0 + i * pitch + 1.6, 36.0 + (i + 1) * pitch - 1.6
            db.prism(mmp([(s * (SV_BOX_HW + 1.6), 22.4), (s * (SV_BOX_HW + 1.6), 42.6), (s * (SV_BOX_HW + 4.4), 41.6),
                          (s * (SV_BOX_HW + 4.4), 23.4)]), "y", y0 * MM, y1 * MM, "Detail")
    fy0, fy1, ftop = 64.0, 78.5, SV_BOX_HI + 6.2
    db.prism(mmp(hs.fillet([(-6.0, SV_BOX_HI + 6.2, 0.0), (6.0, SV_BOX_HI + 6.2, 0.0), (6.0, ftop + 2.0, 1.0),
                            (3.2, ftop + 5.6, 1.2), (-3.2, ftop + 5.6, 1.2), (-6.0, ftop + 2.0, 1.0)], 2)),
             "y", fy0 * MM, fy1 * MM, "Detail")
    db.box(mm(-1.1, fy0 + 2.0, ftop + 5.4), mm(1.1, fy1 - 2.0, ftop + 6.6), "Detail")
    cyl(pb, fy0 + 1.0, fy1 - 1.0, 0.85, "Fibre", 10, z=ftop + 7.2)
    db.box(mm(-1.6, fy1 - 2.0, ftop + 6.0), mm(1.6, fy1, ftop + 9.0), "Detail")
    db.box(mm(-1.6, fy0, ftop + 6.0), mm(1.6, fy0 + 2.0, ftop + 9.0), "Detail")
    # The rear aperture sight: a stem off the collar, its block over the eyepiece, the leaf and its windage screw.
    db.box(mm(-3.0, -40.5, 46.0), mm(3.0, -35.5, 54.0), "Detail")
    db.prism(mmp(hs.fillet([(-35.5, 52.6, 1.0), (-35.5, 58.0, 1.0), (-57.0, 64.5, 1.5),
                            (-59.0, 64.5, 0.5), (-59.0, 52.6, 0.5)], 2)), "x", -9.0 * MM, 9.0 * MM, "Detail")
    leaf = [(-9.0, 52.6), (9.0, 52.6), (9.0, 66.0), (6.5, 69.5), (2.2, 69.5), (1.4, 67.2), (-1.4, 67.2),
            (-2.2, 69.5), (-6.5, 69.5), (-9.0, 66.0)]
    db.prism(mmp(leaf), "y", -62.0 * MM, -59.0 * MM, "Detail")
    disc_x(db, 9.0, 10.4, -50.5, 60.0, 3.0, "Metal", 18, 0.3)
    hex_x(pb, 10.4, 10.46, -50.5, 60.0, 1.2, "Rubber")
    # The mount: a two-bolt clamp, the neck up into the housing.
    rail_clamp(db, PICATINNY, -31.7, 31.7, 8.7, 3.2, "Detail")
    db.prism(mmp(hs.fillet([(-12.0, 8.0, 0.0), (12.0, 8.0, 0.0), (12.0, 18.0, 0.0), (-12.0, 18.0, 0.0)], 1)),
             "y", -30.0 * MM, 14.0 * MM, "Detail")
    for y in (-19.3, 20.0):
        disc_x(db, 13.4, 16.2, y, 2.6, 5.0, "Metal", 24, 0.6)
        hex_x(pb, 16.2, 16.26, y, 2.6, 1.8, "Rubber")
        hex_x(db, -13.4, -16.4, y, 2.6, 4.6, "Metal")
    dials = db.build()
    hs.finish(dials, bevel=0.0003, segments=1, angle=math.radians(50.0))
    plain = pb.build()
    hs.finish(plain, bevel=0.0)

    ob = hs.join("optic_scopeVar", [box, housing, dials, plain])
    fig = hs.Builder("optic_scopeVar_Figure", ["Detail"])
    fig.lathe([(SV_EYE_BACK * MM, 0.0), (SV_EYE_BACK * MM, 16.0 * MM), (24.0 * MM, 16.0 * MM),
               (SV_BOX[0] * MM, SV_BOX_HW * MM), (SV_BOX[1] * MM, SV_BOX_HW * MM), (SV_BOX[1] * MM, 0.0)],
              "Detail", 8, centre=(0.0, 0.0, h * MM))
    fig.box(mm(-12.6, -31.7, 0.0), mm(12.6, 31.7, 18.0), "Detail")
    fig.box(mm(-8.0, -32.0, 46.0), mm(8.0, -6.0, 62.0), "Detail")
    fig.build().parent = ob
    child_empty("optic_scopeVar_SightLine", mm(0.0, 0.0, h), ob)
    return ob


# ---------------------------------------------------------------------------------------------------------- grips

# The angled handstop, traced from the owner's side photo (angled_grip › the kinesthetic grip, 7.2 px a millimetre):
# its side outline (y forward, z down from the rail's face, mm; a third value rounds that corner), the tall end in
# front, the swept face behind it where the palm sits.
AG_SIDE = [(42.0, 0.0, 0.0), (-42.7, 0.0, 0.0), (-42.4, -3.8, 1.0), (-23.3, -6.6, 0.0), (-6.6, -11.1, 0.0),
           (3.1, -17.4, 0.0), (8.0, -24.3, 0.0), (9.0, -31.3, 0.0), (7.3, -41.0, 0.0), (4.5, -46.2, 3.0),
           (18.4, -47.6, 6.0), (30.6, -46.2, 4.0), (33.0, -41.0, 0.0), (35.8, -24.3, 0.0), (38.1, -9.0, 0.0),
           (40.6, -2.1, 1.5)]
AG_HALF = 10.5
# The side pocket and the swept face's ridges (the face points they run between).
AG_POCKET = [(30.6, -9.4, 1.5), (11.6, -9.4, 1.5), (16.6, -17.5, 2.0), (16.4, -41.6, 2.0), (28.4, -42.8, 2.0),
             (31.6, -28.0, 2.0)]


def sweep_ridges(b: hs.Builder, path: list, count: int, half: float, height: float, mat: str,
                 inward: float = 1.0) -> None:
    """`count` small ridges spaced evenly along a side path (y, z mm), each across the grip (x +-half), standing
    `height` off the face along its normal (the side `inward` says, 1 to the path's left)."""
    seg = []
    total = 0.0
    for (ya, za), (yb, zb) in zip(path, path[1:]):
        d = math.hypot(yb - ya, zb - za)
        seg.append((ya, za, yb, zb, d))
        total += d
    for i in range(count):
        s = total * (i + 0.5) / count
        for ya, za, yb, zb, d in seg:
            if s <= d:
                t = s / d
                y, z = ya + (yb - ya) * t, za + (zb - za) * t
                ty, tz = (yb - ya) / d, (zb - za) / d
                ny, nz = -tz * inward, ty * inward
                w = 0.75
                pts = [(y - ty * w, z - tz * w), (y + ty * w, z + tz * w),
                       (y + ty * w * 0.5 + ny * height, z + tz * w * 0.5 + nz * height),
                       (y - ty * w * 0.5 + ny * height, z - tz * w * 0.5 + nz * height)]
                b.prism(mmp(pts), "x", -half * MM, half * MM, mat)
                break
            s -= d


def build_grip_angled() -> bpy.types.Object:
    gb = hs.Builder("ag_body", ["Furniture"])
    gb.prism(mmp(hs.fillet(AG_SIDE, 4)), "x", -AG_HALF * MM, AG_HALF * MM, "Furniture")
    body = gb.build()
    pockets = [prism_cutter(hs.fillet(AG_POCKET, 3), "x", s * (AG_HALF - 1.3), s * (AG_HALF + 2.0))
               for s in (-1.0, 1.0)]
    hs.cut(body, pockets)
    hs.finish(body, bevel=0.0009, segments=2)
    rb = hs.Builder("ag_ribs", ["Furniture", "Metal", "Rubber"])
    # The diagonal web in each pocket, the swept face's and the front's ridges, the rail clamp and its metal bar.
    for s in (-1.0, 1.0):
        rb.prism(mmp([(27.0, -11.0), (29.6, -12.6), (19.4, -40.2), (16.8, -39.0)]), "x", s * (AG_HALF - 1.4) * MM,
                 s * (AG_HALF - 0.3) * MM, "Furniture")
    sweep_ridges(rb, [(-40.0, -4.1), (-23.3, -6.6), (-6.6, -11.1), (3.1, -17.4), (8.0, -24.3), (9.0, -31.3),
                      (7.6, -40.0)], 26, AG_HALF - 1.2, 1.0, "Furniture", inward=1.0)
    sweep_ridges(rb, [(33.2, -41.0), (35.8, -24.3), (38.1, -9.0)], 13, AG_HALF - 1.2, 1.0, "Furniture",
                 inward=1.0)
    rail_clamp_under(rb, PICATINNY, -8.0, 38.0, -3.2, 1.8, "Furniture")
    rb.prism(mmp(hs.fillet([(-42.6, 0.0, 0.0), (-36.0, 0.0, 0.0), (-36.0, -3.0, 0.6), (-42.6, -3.0, 0.6)], 2)), "x",
             -8.0 * MM, 8.0 * MM, "Furniture")
    rb.prism(mmp([(-14.2, 1.2), (-12.6, 1.2), (-12.6, -4.2), (-14.2, -3.6)]), "y", 0.0 * MM, 28.0 * MM, "Metal")
    hex_x(rb, -14.2, -14.26, 14.0, -1.6, 1.4, "Rubber")
    disc_x(rb, 12.6, 14.0, 14.0, -1.6, 2.6, "Metal", 16, 0.3)
    ribs = rb.build()
    hs.finish(ribs, bevel=0.0003, segments=1, angle=math.radians(50.0))
    ob = hs.join("grip_angled", [body, ribs])
    fig = hs.Builder("grip_angled_Figure", ["Furniture"])
    fig.prism(mmp([(42.0, 0.0), (-42.7, 0.0), (-6.6, -11.1), (8.0, -24.3), (4.5, -47.0), (31.0, -47.0), (40.6, -2.0)]),
              "x", -AG_HALF * MM, AG_HALF * MM, "Furniture")
    fig.build().parent = ob
    return ob


# The short vertical grip (vertical_grip): its clamp, then its body as rings from the top down (z mm under the rail's
# face, the half width across, the half length fore and aft, mm): a slight waist and a flared foot.
VG_RINGS = [(-6.0, 13.2, 19.0), (-11.0, 12.6, 18.0), (-30.0, 12.1, 17.2), (-49.0, 12.2, 17.3), (-54.0, 13.2, 18.6),
            (-57.5, 13.4, 18.8), (-59.5, 12.6, 18.0)]
VG_RIBS = 12


def vg_ring(z: float, hw: float, hl: float, n: int = 32) -> list:
    """A rounded oblong ring across the grip at z (mm), its sides flatter than its ends."""
    pts = []
    for i in range(n):
        t = math.tau * i / n
        c, s = math.cos(t), math.sin(t)
        x = hw * math.copysign(abs(c) ** (2.0 / 3.2), c)
        y = hl * math.copysign(abs(s) ** (2.0 / 2.6), s)
        pts.append((x * MM, y * MM, z * MM))
    return pts


def stud(b: hs.Builder, side: float, x: float, y: float, z: float, r: float, height: float, mat: str) -> None:
    """A small four-sided stud on a side face (the face at x, `side` its direction): one grain of a stippled panel."""
    bm = b.bm
    base = [bm.verts.new(((side * x) * MM, (y + r * math.cos(a)) * MM, (z + r * math.sin(a)) * MM))
            for a in (0.0, math.pi / 2, math.pi, 1.5 * math.pi)]
    tip = bm.verts.new((side * (x + height) * MM, y * MM, z * MM))
    faces = [bm.faces.new((base[i], base[(i + 1) % 4], tip)) for i in range(4)]
    for f in faces:
        f.normal_update()
        if f.normal.x * side < 0:
            f.normal_flip()
        f.material_index = b.mat(mat)


def build_grip_vertical() -> bpy.types.Object:
    gb = hs.Builder("vg_body", ["Furniture", "Rubber"])
    gb.loft([vg_ring(z, hw, hl) for z, hw, hl in VG_RINGS], "Furniture")
    body = gb.build()
    # A textured panel let into each side, a groove ring above the foot.
    cuts = [prism_cutter(hs.fillet([(-9.5, -15.0, 3.0), (9.5, -15.0, 3.0), (9.5, -48.0, 3.0), (-9.5, -48.0, 3.0)], 3),
                         "x", s * 10.8, s * 16.0) for s in (-1.0, 1.0)]
    hs.cut(body, cuts)
    hs.finish(body, bevel=0.0008, segments=2)
    db = hs.Builder("vg_detail", ["Furniture", "Rubber", "Metal"])
    pb = hs.Builder("vg_stipple", ["Furniture"])
    # The panels: a stippled face (rows of small studs) at the pocket's floor.
    for s in (-1.0, 1.0):
        db.prism(mmp(hs.fillet([(-9.3, -15.2, 2.8), (9.3, -15.2, 2.8), (9.3, -47.8, 2.8), (-9.3, -47.8, 2.8)], 2)),
                 "x", s * 10.4 * MM, s * 11.25 * MM, "Furniture")
        for row in range(11):
            for col in range(6):
                y = -7.5 + col * 3.0 + (1.5 if row % 2 else 0.0)
                if y > 8.2:
                    continue
                z = -17.4 + row * -2.8
                stud(pb, s, 11.2, y, z, 0.9, 0.55, "Furniture")
    # The ribs down the front and back faces.
    for end in (-1.0, 1.0):
        for i in range(VG_RIBS):
            z = -14.0 - i * 2.9
            db.prism(mmp([(-6.5, z), (6.5, z), (6.0, z - 1.3), (-6.0, z - 1.3)]), "y",
                     end * 16.9 * MM, end * 18.0 * MM, "Furniture")
    # The clamp, its cross bolt and nut.
    rail_clamp_under(db, PICATINNY, -19.0, 19.0, -7.0, 2.6, "Furniture")
    disc_x(db, 13.2, 15.0, 0.0, -2.8, 4.0, "Metal", 24, 0.6)
    db.box(mm(15.0, -3.2, -3.25), mm(15.06, 3.2, -2.35), "Rubber")
    hex_x(db, -13.2, -15.6, 0.0, -2.6, 3.0, "Metal")
    detail = db.build()
    hs.finish(detail, bevel=0.0003, segments=1, angle=math.radians(50.0))
    stipple = pb.build()
    hs.finish(stipple, bevel=0.0)
    ob = hs.join("grip_vertical", [body, detail, stipple])
    fig = hs.Builder("grip_vertical_Figure", ["Furniture"])
    fig.box(mm(-12.6, -18.0, -59.5), mm(12.6, 18.0, 0.0), "Furniture")
    fig.build().parent = ob
    return ob


# ------------------------------------------------------------------------------------------------------ silencers

# A plain tube with rounded ends and end-cap seams, its bore let into the front face (silencer): the rifle's and the
# pistol's (slimmer, on a knurled thread adaptor), as (length, radius, adaptor length) in mm from the barrel's end.
SILENCERS = {"rifle": (150.0, 17.0, 0.0), "pistol": (112.0, 13.4, 9.0)}


def build_silencer(kind: str = "rifle") -> bpy.types.Object:
    length, r, adaptor = SILENCERS[kind]
    y0, y1 = adaptor, length
    e = 2.4
    prof = [(y0, 6.0), (y0, r - e), (y0 + e * 0.3, r - e * 0.35), (y0 + e, r), (y0 + 5.6, r), (y0 + 5.8, r - 0.45),
            (y0 + 6.3, r - 0.45), (y0 + 6.5, r), (y1 - 7.5, r), (y1 - 7.3, r - 0.45), (y1 - 6.8, r - 0.45),
            (y1 - 6.6, r), (y1 - e, r), (y1 - e * 0.3, r - e * 0.35), (y1, r - e), (y1, 6.4), (y1 - 1.2, 5.0),
            (y1 - 4.0, 4.6), (y1 - 4.0, 0.0)]
    b = hs.Builder("muzzle_silencer", ["Detail", "Metal", "Rubber"])
    lathe_y(b, prof, "Detail", 48)
    pb = hs.Builder("sil_plain", ["Metal", "Rubber"])
    tube_y(pb, [(y1 - 3.9, 4.6), (y1 - 3.0, 4.6)], [(y1 - 3.9, 3.4), (y1 - 3.0, 3.4)], "Rubber", 20)
    if adaptor > 0.0:
        lathe_y(b, [(-0.5, 0.0), (-0.5, 6.6), (0.0, 7.2), (1.0, 7.2)], "Metal", 32)
        ridged(pb, 1.0, adaptor - 1.0, 7.0, 7.6, 28, "Metal")
        lathe_y(b, [(adaptor - 1.0, 7.2), (adaptor - 0.4, 7.2), (adaptor, 6.0)], "Metal", 32)
    ob = b.build()
    hs.finish(ob, bevel=0.0)
    plain = pb.build()
    hs.finish(plain, bevel=0.0)
    ob = hs.join("muzzle_silencer", [ob, plain])
    fig = hs.Builder("muzzle_silencer_Figure", ["Detail"])
    fig.lathe([(y0 * MM, 0.0), (y0 * MM, r * MM), (y1 * MM, r * MM), (y1 * MM, 0.0)], "Detail", 8)
    fig.build().parent = ob
    child_empty("muzzle_silencer_Muzzle", mm(0.0, length, 0.0), ob)
    return ob


# ---------------------------------------------------------------------------------------------------- red laser

# The laser module under a pistol's rail (red_laser: the knurled module in a rail block): the block, the tube through
# it and its knurled nose, the emitter (mm, under the rail's face).
LZ_AXIS = -13.2
LZ_BLOCK = (-12.0, 12.0, -4.0, -21.0)
LZ_NOSE = 37.0


def build_laser(rail_name: str = "pistol") -> bpy.types.Object:
    rail = PISTOL_RAIL if rail_name == "pistol" else CYBER_RAIL
    y0, y1, ztop, zbot = LZ_BLOCK
    bb = hs.Builder("lz_block", ["Detail", "Metal", "Rubber", "LaserLens"])
    rail_clamp_under(bb, rail, y0, y1, ztop, 2.2, "Detail")
    bb.prism(mmp(hs.fillet([(-13.4, ztop + 0.2, 0.0), (13.4, ztop + 0.2, 0.0), (13.4, zbot, 2.4), (-13.4, zbot, 2.4)],
                           3)), "y", y0 * MM, y1 * MM, "Detail")
    block = bb.build()
    hs.cut(block, [box_cutter((-20, y0 - 1, ztop - 3.0), (20, y0 + 2.0, ztop - 2.2)),
                   box_cutter((-20, y1 - 2.0, ztop - 3.0), (20, y1 + 1, ztop - 2.2))])
    hs.finish(block, bevel=0.0004)
    tb = hs.Builder("lz_tube", ["Detail", "Metal", "Rubber", "LaserLens"])
    lathe_y(tb, [(y0 - 3.0, 0.0), (y0 - 3.0, 5.4), (y0 - 2.4, 6.0), (y0, 6.0)], "Detail", 28, z=LZ_AXIS)
    lathe_y(tb, [(y1, 6.0), (y1 + 1.6, 6.0), (y1 + 1.6, 5.6)], "Detail", 28, z=LZ_AXIS)
    lathe_y(tb, [(LZ_NOSE - 1.6, 5.8), (LZ_NOSE - 0.6, 5.8), (LZ_NOSE, 5.2), (LZ_NOSE, 2.2), (LZ_NOSE - 0.6, 1.6),
                 (LZ_NOSE - 0.6, 0.0)], "Detail", 28, z=LZ_AXIS)
    # The adjusting screws (elevation under the block, windage on its right) and the clamp's cross screws.
    disc_z(tb, 0.0, 2.0, zbot - 1.2, zbot + 0.2, 2.6, "Detail", 16, 0.3)
    disc_x(tb, 13.2, 14.4, 2.0, LZ_AXIS + 0.6, 2.6, "Detail", 16, 0.3)
    for y in (-6.0, 6.0):
        disc_x(tb, 14.4, 15.4, y, -1.8, 1.6, "Metal", 14, 0.3)
    tube = tb.build()
    hs.finish(tube, bevel=0.0003, segments=1, angle=math.radians(50.0))
    pb = hs.Builder("lz_plain", ["Detail", "Rubber", "LaserLens"])
    ridged(pb, y1 + 1.6, LZ_NOSE - 1.6, 5.5, 6.0, 20, "Detail", z=LZ_AXIS)
    lens(pb, LZ_NOSE - 0.55, 1.65, "LaserLens", 16, z=LZ_AXIS)
    slot_z(pb, 0.0, 2.0, zbot - 1.25, 3.2, 0.6, 0.0, "Rubber")
    hex_x(pb, 14.4, 14.46, 2.0, LZ_AXIS + 0.6, 1.0, "Rubber")
    plain = pb.build()
    hs.finish(plain, bevel=0.0)
    ob = hs.join("laser_redLaser", [block, tube, plain])
    fig = hs.Builder("laser_redLaser_Figure", ["Detail"])
    fig.box(mm(-13.4, y0, zbot), mm(13.4, y1, 0.0), "Detail")
    fig.lathe([(y1 * MM, 6.0 * MM), (LZ_NOSE * MM, 6.0 * MM)], "Detail", 6, centre=(0.0, 0.0, LZ_AXIS * MM))
    fig.build().parent = ob
    child_empty("laser_redLaser_Beam", mm(0.0, LZ_NOSE + 0.1, LZ_AXIS), ob)
    return ob


# ------------------------------------------------------------------------------------------------- weapon torch

# The compact pistol light (weapon_torch: the X300-style photos), built under a rail and turned onto the AEG's side
# rail: its clamp, body and head (mm under the rail's face, along +Y from the clamp's middle).
WT_CLAMP = (-12.0, 12.0)
WT_BODY = (-32.0, 12.0)
WT_TOP, WT_BOTTOM, WT_HALF = -5.5, -30.0, 12.4
WT_AXIS = -17.6
WT_HEAD = (14.0, 35.5)
WT_HEAD_R = 13.6


def build_torch(rail_name: str = "pistol") -> bpy.types.Object:
    rail = {"pistol": PISTOL_RAIL, "cyber": CYBER_RAIL, "rifle": PICATINNY}[rail_name]
    bb = hs.Builder("wt_body", ["Detail", "Metal", "Rubber", "TorchLens"])
    # The body as a prism of its section, eased into the round head by a loft.
    sec = hs.fillet([(-WT_HALF, WT_TOP, 1.5), (WT_HALF, WT_TOP, 1.5), (WT_HALF, WT_BOTTOM, 7.0),
                     (-WT_HALF, WT_BOTTOM, 7.0)], 6)
    bb.prism(mmp(sec), "y", WT_BODY[0] * MM, (WT_BODY[1] - 6.0) * MM, "Detail")
    circle_ring = []
    for x, z in sec:
        a = math.atan2(z - WT_AXIS, x)
        circle_ring.append((math.cos(a) * (WT_HEAD_R - 0.4) * MM, WT_HEAD[0] * MM,
                            (WT_AXIS + math.sin(a) * (WT_HEAD_R - 0.4)) * MM))
    bb.loft([[(x * MM, (WT_BODY[1] - 6.0) * MM, z * MM) for x, z in sec], circle_ring], "Detail", cap0=False,
            cap1=True)
    body = bb.build()
    # A long flat channel down each flank, the slot under the clamp.
    hs.cut(body, [prism_cutter(hs.fillet([(-21.0, -12.0, 1.5), (3.0, -12.0, 1.5), (3.0, -21.0, 1.5),
                                          (-21.0, -21.0, 1.5)], 2), "x", s * (WT_HALF - 0.7), s * (WT_HALF + 3.0))
                  for s in (-1.0, 1.0)])
    hs.finish(body, bevel=0.0005)
    hb = hs.Builder("wt_head", ["Detail", "Metal", "Rubber", "TorchLens"])
    lathe_y(hb, [(WT_HEAD[0] - 1.0, WT_HEAD_R - 0.4), (WT_HEAD[0] + 0.5, WT_HEAD_R),
                 (WT_HEAD[1] - 4.6, WT_HEAD_R),
                 (WT_HEAD[1] - 4.4, WT_HEAD_R - 0.4), (WT_HEAD[1] - 4.0, WT_HEAD_R - 0.4),
                 (WT_HEAD[1] - 3.8, WT_HEAD_R + 0.2), (WT_HEAD[1] - 0.8, WT_HEAD_R + 0.2),
                 (WT_HEAD[1], WT_HEAD_R - 0.8), (WT_HEAD[1], WT_HEAD_R - 2.2), (WT_HEAD[1] - 1.2, WT_HEAD_R - 3.0)],
            "Detail", 40, z=WT_AXIS, cap=False)
    # The clamp: its housing on the body's top, the jaws round the rail, the cross latch (left) and its screw (right).
    rail_clamp_under(hb, rail, WT_CLAMP[0], WT_CLAMP[1], WT_TOP - 0.5, 2.4, "Detail")
    hb.prism(mmp([(WT_CLAMP[0] - 4.0, 0.0), (WT_CLAMP[1] + 3.0, 0.0), (WT_CLAMP[1] + 6.0, WT_TOP - 0.2),
                  (WT_CLAMP[0] - 7.0, WT_TOP - 0.2)]), "x", -(rail["half"] + 1.2) * MM,
             (rail["half"] + 1.2) * MM, "Detail")
    lx = -(rail["half"] + 2.4)
    hb.prism(mmp(hs.fillet([(-4.0, 1.5, 1.0), (4.0, 1.5, 1.0), (5.0, -6.5, 1.5), (-5.0, -6.5, 1.5)], 2)), "x",
             lx * MM, (lx - 2.2) * MM, "Detail", offset=(0.0, -2.0 * MM, 0.0))
    disc_x(hb, -lx, -lx + 1.4, -2.0, -2.4, 2.4, "Metal", 16, 0.3)
    # The rocker paddles at the back, one each side, and the tail cap.
    for s in (-1.0, 1.0):
        hb.prism(mmp(hs.fillet([(-32.0, -9.0, 1.0), (-23.0, -9.0, 2.0), (-25.0, -21.0, 2.0), (-34.0, -21.0, 1.0)],
                               2)), "x", s * (WT_HALF - 0.6) * MM, s * (WT_HALF + 1.6) * MM, "Detail")
    hb.prism(mmp(hs.fillet([(-WT_HALF + 1.5, WT_TOP - 1.0, 1.5), (WT_HALF - 1.5, WT_TOP - 1.0, 1.5),
                            (WT_HALF - 1.5, WT_BOTTOM + 1.0, 5.5), (-WT_HALF + 1.5, WT_BOTTOM + 1.0, 5.5)], 4)),
             "y", (WT_BODY[0] - 1.8) * MM, (WT_BODY[0] + 0.2) * MM, "Detail")
    head = hb.build()
    hs.finish(head, bevel=0.0003, segments=1, angle=math.radians(50.0))
    pb = hs.Builder("wt_plain", ["Detail", "Metal", "Rubber", "TorchLens"])
    # The reflector behind the lens, the LED, the lens; the latch's ribs, the paddles' grip lines, the screw slot.
    lathe_y(pb, [(WT_HEAD[1] - 9.0, 2.0), (WT_HEAD[1] - 2.4, WT_HEAD_R - 2.6)], "TorchLens", 40, z=WT_AXIS)
    lathe_y(pb, [(WT_HEAD[1] - 9.2, 0.0), (WT_HEAD[1] - 9.2, 2.0)], "Rubber", 16, z=WT_AXIS)
    disc_z(pb, 0.0, WT_HEAD[1] - 8.6, WT_AXIS - 1.0, WT_AXIS + 1.0, 1.1, "TorchLens", 10)
    for s in (-1.0, 1.0):
        for y in (-8.0, 0.0, 8.0):
            disc_x(pb, s * (rail["half"] + 2.4), s * (rail["half"] + 2.46), y, 2.0, 0.9, "Rubber", 10)
    for i in range(5):
        y = -5.6 + i * 1.8
        pb.box(mm(lx - 2.7, y, -5.4), mm(lx - 2.1, y + 0.7, 0.6), "Detail")
    for s in (-1.0, 1.0):
        for i in range(4):
            y = -31.0 + i * 2.0
            pb.box(mm(min(s * (WT_HALF + 1.6), s * (WT_HALF + 2.1)), y, -19.5),
                   mm(max(s * (WT_HALF + 1.6), s * (WT_HALF + 2.1)), y + 0.8, -10.5), "Detail")
    hex_x(pb, -lx + 1.4, -lx + 1.46, -2.0, -2.4, 1.0, "Rubber")
    plain = pb.build()
    hs.finish(plain, bevel=0.0)
    ob = hs.join("light_weaponTorch", [body, head, plain])
    fig = hs.Builder("light_weaponTorch_Figure", ["Detail"])
    fig.box(mm(-WT_HALF, WT_BODY[0], WT_BOTTOM), mm(WT_HALF, WT_BODY[1], 0.0), "Detail")
    fig.lathe([(WT_BODY[1] * MM, WT_HEAD_R * MM), (WT_HEAD[1] * MM, WT_HEAD_R * MM)], "Detail", 8,
              centre=(0.0, 0.0, WT_AXIS * MM))
    fig.build().parent = ob
    child_empty("light_weaponTorch_Beam", mm(0.0, WT_HEAD[1] + 0.1, WT_AXIS), ob)
    return ob


# --------------------------------------------------------------------------------------------------------- writing

# Which builder makes each part, by parts file (the rail it clamps to, the silencer's kind).
BUILDERS = {
    "optic_redDot": lambda f: build_red_dot(),
    "optic_scope2x": lambda f: build_scope_2x(),
    "optic_scopeVar": lambda f: build_scope_var(),
    "grip_vertical": lambda f: build_grip_vertical(),
    "grip_angled": lambda f: build_grip_angled(),
    "muzzle_silencer": lambda f: build_silencer("rifle" if f == "aeg" else "pistol"),
    "laser_redLaser": lambda f: build_laser(f),
    "light_weaponTorch": lambda f: build_torch({"aeg": "rifle"}.get(f, f)),
}
# A torch on the AEG clamps to the handguard's right side: turned from under the rail to face out to the right.
SIDE_MOUNTED = {("aeg", "light_weaponTorch")}


def mounts(replica: str) -> dict:
    """The replica model's empties by name, in its space."""
    hs.reset()
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/models/replicas/%s.glb" % replica))
    return {o.name: o.matrix_world.translation.copy() for o in bpy.data.objects if o.type == "EMPTY"}


def turn(ob: bpy.types.Object, m: Matrix) -> None:
    """Turns a part and everything under it about its origin, baked into the meshes and the empties' places."""
    for o in [ob] + list(ob.children_recursive):
        if o.type == "MESH":
            o.data.transform(m)
        if o is not ob:
            o.location = m @ o.location


def write(part_file: str) -> None:
    at = mounts(part_file)
    hs.reset()
    path = os.path.join(ROOT, "assets/models/replicaParts/%s.glb" % part_file)
    bpy.ops.import_scene.gltf(filepath=path)
    for name in FILES[part_file]:
        old = bpy.data.objects.get(name)
        if old is not None:
            for o in list(old.children_recursive) + [old]:
                bpy.data.objects.remove(o, do_unlink=True)
        old_fig = bpy.data.objects.get(name + "_Figure")
        if old_fig is not None:
            bpy.data.objects.remove(old_fig, do_unlink=True)
    materials()
    for name in FILES[part_file]:
        ob = BUILDERS[name](part_file)
        if (part_file, name) in SIDE_MOUNTED:
            turn(ob, Matrix.Rotation(math.radians(-90.0), 4, "Y"))
        if name.startswith("light_") and part_file != "aeg":
            child_empty(name + "_UnderLaser", mm(0.0, 0.0, LZ_BLOCK[3]), ob)
        prefix = name.split("_")[0] + "_"
        mount = MOUNT_OVERRIDE.get((part_file, prefix), MOUNT[prefix])
        ob.location = at[mount]
        print("  %-12s %-20s %6d triangles (figure %d)" % (part_file, name, hs.tris(ob),
                                                            hs.tris(bpy.data.objects[name + "_Figure"])))
    for m in list(bpy.data.meshes):
        if m.users == 0:
            bpy.data.meshes.remove(m)
    hs.export(path, False)


def main() -> None:
    for f in FILES:
        write(f)
    print("wrote", ", ".join(FILES), "(now run tools/blender/replicas/sniper.py)")


if __name__ == "__main__":
    main()
