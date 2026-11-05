"""The human figure's gear (BL12, 2026-11-05): the plate carrier, its pouches, the belt and holster (`Kit`), the
backpack (`Kit_Pack`) and the radio in its pouch (`Kit_Radio`), each at three levels of detail (the radio two), built
from the owner's reference photos (ref_images/player/plate_carrier, pouches, backpack, radio) and spliced into
assets/models/characters/human.glb in place of the old ones (splice.py), so the body, heads and clips stay as they are.

- The carrier: a JPC-style front plate bag with a shooter's cut and a loop panel, a back plate bag with a MOLLE field
  and a drag handle, padded shoulder straps with quick-release buckles and a laser-cut-style cummerbund with three
  rows of loops, in the team colour (`TeamGear`, painted per team by the game).
- Coyote pouches: three open-top magazine pouches with bungee pull tabs and magazines in them on the front, a
  general-purpose pouch with a buckled lid on the right side; on the belt, an empty polymer holster (either pistol
  fits) on the right hip, a grenade pouch on the left and a folded dump pouch at the back.
- The pack: a ranger-green two-compartment assault pack with a grab handle, a loop panel, MOLLE rows, compression
  straps and shoulder straps over the carrier's.
- The radio: an unbranded dual-band handheld with a display, a knob and a 6 cm stub antenna, in an open pouch on the
  left of the cummerbund.

No brand marks. Plain colours from a small swatch texture (`gear_col`, `gear_orm`, `teamgear_col`), each surface a
soft vertical gradient; detail is geometry. Fitted to the body in the file by rays (fit.py), clear of it at rest.

Run with Blender 5.x's Python, or Python with the `bpy` module (pip install bpy==5.2.3), from the repo root:

    python -I tools/blender/figure-gear/gear.py [--render <dir>] [--no-splice]
"""

import math
import os
import struct
import sys

import bpy  # first: it brings bmesh and mathutils with it
import bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "replicas"))
import hardsurface as hs  # noqa: E402
import fit  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
HUMAN = os.path.join(ROOT, "assets/models/characters/human.glb")

# ------------------------------------------------------------------------------------------------------ swatches
# name: (family, column, sRGB, roughness, metallic). Gear is drawn as modelled; TeamGear is multiplied by the team's
# colour in the game, so its swatches are greys (light for the fabric, darker for webbing and loop panels).
SWATCHES = {
    "coyote": ("Gear", 0, 0x8B7458, 0.88, 0.0),
    "coyote_web": ("Gear", 1, 0x625039, 0.85, 0.0),
    "coyote_loop": ("Gear", 2, 0x5D4D3B, 0.95, 0.0),
    "polymer": ("Gear", 3, 0x232427, 0.45, 0.0),
    "metal": ("Gear", 4, 0x44474C, 0.35, 0.8),
    "ranger": ("Gear", 5, 0x4F5639, 0.88, 0.0),
    "ranger_web": ("Gear", 6, 0x3C422E, 0.85, 0.0),
    "rubber": ("Gear", 7, 0x18191A, 0.75, 0.0),
    "lcd": ("Gear", 8, 0x2A3A46, 0.15, 0.0),
    "cord": ("Gear", 9, 0x2C2C2C, 0.7, 0.0),
    "tan_web": ("Gear", 10, 0x8C7759, 0.85, 0.0),
    "ranger_loop": ("Gear", 11, 0x3B4132, 0.95, 0.0),
    "team": ("TeamGear", 0, 0xC2C2C2, 0.9, 0.0),
    "team_web": ("TeamGear", 1, 0x7A7A7A, 0.86, 0.0),
    "team_loop": ("TeamGear", 2, 0x6E6E6E, 0.95, 0.0),
    "team_bind": ("TeamGear", 3, 0x9A9A9A, 0.88, 0.0),
}
COLUMNS = 16          # swatch columns in each texture
TEX_W, TEX_H = 256, 32
GRADIENT = (0.84, 1.0)  # a surface's colour at its foot and its top


def swatch_materials() -> None:
    for name, (_fam, _col, rgb, rough, metal) in SWATCHES.items():
        hs.material(name, rgb, rough, metal)


# --------------------------------------------------------------------------------------------------- dimensions
# Metres, Blender space (see fit.py). Measured off the owner's photos against a 1.74 m figure.
FRONT = dict(bottom=1.05, top=1.375, half=0.13, top_half=0.097, cut=0.062, radius=0.32, gap=0.013, thick=0.030)
BACK = dict(bottom=1.03, top=1.395, half=0.13, top_half=0.116, cut=0.035, radius=0.36, gap=0.012, thick=0.028)
CUMMER = dict(bottom=1.03, top=1.20, thick=0.011, gap=0.006, tuck=0.100)
BELT = dict(bottom=0.94, top=1.0, thick=0.013, gap=0.003)  # at the waist (the owner, 2026-11-05)
STRAP = dict(width=0.064, thick=0.022, gap=0.004, front_x=0.078, crest_x=0.108, back_x=0.092)
MOLLE = dict(row=0.025, pitch_z=0.05, loop=0.031, pitch_x=0.038, raise_=0.005)
PILLOW = 0.005  # how far a filled bag's face bulges at its middle
HOLSTER_DROP = 0.05  # the holster's mouth below the belt's top (a drop mount)
# Where a pistol out of the hand sits (FigureHands, FigureConfig.holster_node): an empty at the holster's mouth on the
# slide's line, in the replica's axes (+Z up out of the mouth, +Y the slide's top, toward the figure's front). Its place
# in the holster's frame (x forward, z up, -y out from the hip): the front inner wall, the pocket's middle, the mouth.
# Both pistols' figure meshes clear the pocket's walls seated 0.10 to 0.13 m deep (FigureConfig.holster_depth, 0.11).
PISTOL_SEAT_NODE = "PistolHolster"
PISTOL_SEAT_AT = (0.0, -0.030, 0.0)
PLATE_GAP = 0.006  # the plate bags' inner faces off the body where they come closest


class Kit:
    """One piece of gear being built at one level of detail: its parts, each with a skin rule."""

    def __init__(self, name: str, lod: int):
        self.name = name
        self.lod = lod
        self.parts = []  # (object, weights) where weights is a bone name or a function(world co) -> {bone: w}

    def add(self, ob: bpy.types.Object, weights) -> bpy.types.Object:
        self.parts.append((ob, weights))
        return ob


# ------------------------------------------------------------------------------------------------- small makers

def builder(name: str) -> hs.Builder:
    return hs.Builder(name, [])


def bevel(ob: bpy.types.Object, width: float, segments: int, angle: float = 30.0) -> None:
    if width <= 0.0 or segments <= 0:
        return
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bm.to_mesh(ob.data)
    bm.free()
    mod = ob.modifiers.new("bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle)
    mod.use_clamp_overlap = True
    mod.miter_outer = "MITER_ARC"
    mod.profile = 0.5
    hs.apply_modifiers(ob)


def shade(ob: bpy.types.Object, angle: float = 40.0) -> None:
    """Smooth shading split at sharp edges, normals weighted to the big faces."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-7, edges=bm.edges)
    # Flat stretches the bending cuts left (a band's top and bottom edges) are merged back into single faces.
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.6), use_dissolve_boundaries=False,
                             verts=bm.verts, edges=bm.edges, delimit={"MATERIAL"})
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.to_mesh(ob.data)
    bm.free()
    for p in ob.data.polygons:
        p.use_smooth = True
    ob.data.set_sharp_from_angle(angle=math.radians(angle))
    mod = ob.modifiers.new("weighted", "WEIGHTED_NORMAL")
    mod.keep_sharp = True
    mod.weight = 50
    mod.mode = "FACE_AREA"
    hs.apply_modifiers(ob)


def soft_box(name: str, hw: float, hh: float, depth: float, mat: str, r: float, bev: float, seg: int,
             corner_seg: int = 3, taper_top: float = 1.0) -> bpy.types.Object:
    """A padded box: a rounded outline (front view, centred on x, z from 0 to 2 hh) pushed out from y=0 to -depth,
    its edges rounded by `bev`. taper_top < 1 thins it towards its top (a pack)."""
    b = builder(name)
    outline = [(x, z + hh) for x, z in rrect(hw, hh, r, corner_seg)]
    b.prism(outline, "y", -depth, 0.0, mat)
    ob = b.build()
    bevel(ob, bev, seg)
    if taper_top != 1.0:
        for v in ob.data.vertices:
            f = 1.0 - (1.0 - taper_top) * max(0.0, min(1.0, v.co.z / (2 * hh)))
            v.co.y *= f
    return ob


def rrect(hw: float, hh: float, r: float, seg: int) -> list:
    """A rectangle 2 hw by 2 hh about the origin, its corners rounded by r in `seg` steps (square at seg 0)."""
    if seg <= 0 or r <= 0.0:
        return [(hw, hh), (-hw, hh), (-hw, -hh), (hw, -hh)]
    return hs.rounded_rect(hw, hh, r, seg)


def rounded(pts: list, r: float, seg: int) -> list:
    """A closed outline with every corner rounded by r in `seg` steps (sharp at seg 0)."""
    return hs.fillet([(x, y, r) for x, y in pts], seg) if seg > 0 else list(pts)


def place(ob: bpy.types.Object, m: Matrix) -> bpy.types.Object:
    ob.data.transform(m)
    ob.data.update()
    return ob


def box_ob(name: str, lo: tuple, hi: tuple, mat: str, bev: float = 0.0, seg: int = 1) -> bpy.types.Object:
    b = builder(name)
    b.box(lo, hi, mat)
    ob = b.build()
    bevel(ob, bev, seg)
    return ob


def join(name: str, obs: list) -> bpy.types.Object:
    if os.environ.get("GEAR_TRIS") and name in ("PackAll", "MagPouch0", "HolsterAll", "RadioAll", "GPPouch"):
        print("   ", name, [(o.name, hs.tris(o)) for o in obs if o is not None])
    return hs.join(name, [o for o in obs if o is not None])


def section_rect(w: float, t: float, r: float, seg: int) -> list:
    """A strap's cross-section, `across` -w/2..w/2, `out` 0..t, corners rounded by r."""
    if seg <= 0 or r <= 0.0:
        return [(-w / 2, 0.0), (w / 2, 0.0), (w / 2, t), (-w / 2, t)]
    pts = rrect(w / 2, t / 2, r, seg)
    return [(x, y + t / 2) for x, y in pts]


def sweep_ob(name: str, path: list, outs: list, section: list, mat: str) -> bpy.types.Object:
    b = builder(name)
    faces = fit.sweep(b.bm, path, outs, section)
    b._faces(faces, mat)
    return b.build()


def molle(name: str, x0: float, x1: float, rows: list, base: float, mat: str, lod: int) -> bpy.types.Object:
    """MOLLE webbing on a flat-built sheet: rows (centre heights) of webbing between x0 and x1, standing `base` out,
    bowed out into loops between bar tacks (LOD0); LOD1 draws each row as a plain strip; LOD2 none."""
    if lod >= 2 or x1 - x0 < MOLLE["loop"]:
        return None
    b = builder(name)
    h = MOLLE["row"] / 2
    low, high = 0.0007, MOLLE["raise_"]
    for zc in rows:
        if lod == 1:
            xs = [(x0, high), (x1, high)]
        else:
            n = max(1, int((x1 - x0 + (MOLLE["pitch_x"] - MOLLE["loop"])) // MOLLE["pitch_x"]))
            pitch = (x1 - x0) / n
            xs = [(x0, low)]
            for i in range(n):
                xa = x0 + i * pitch
                xs += [(xa + 0.0035, high), (xa + pitch - 0.0035, high), (xa + pitch, low)]
        rings = []
        for x, r in xs:
            rings.append([(x, -base + 0.0004, zc - h), (x, -base - r, zc - h), (x, -base - r, zc + h),
                          (x, -base + 0.0004, zc + h)])
        b.loft(rings, mat, closed=False)
    return b.build()


def side_release(name: str, lod: int, w: float = 0.026, h: float = 0.034, d: float = 0.008) -> bpy.types.Object:
    """A side-release buckle standing up (front view), its foot at z=0, its back on y=0: the female body and the male
    tongue's two prongs and bar, all polymer."""
    if lod >= 2:
        return None
    b = builder(name)
    fem = [(-w / 2, 0.0), (w / 2, 0.0), (w / 2 * 0.86, h * 0.55), (-w / 2 * 0.86, h * 0.55)]
    b.prism(fem, "y", -d, 0.0, "polymer")
    if lod == 0:
        # The male part: a bar across the top and two prongs into the female body.
        b.prism([(-w / 2 * 0.8, h * 0.82), (w / 2 * 0.8, h * 0.82), (w / 2 * 0.8, h), (-w / 2 * 0.8, h)],
                "y", -d * 0.75, 0.0, "polymer")
        for sx in (-1, 1):
            x0, x1 = sx * w * 0.32, sx * w * 0.44
            b.prism([(min(x0, x1), h * 0.5), (max(x0, x1), h * 0.5), (max(x0, x1), h * 0.84),
                     (min(x0, x1), h * 0.84)], "y", -d * 0.7, -d * 0.1, "polymer")
    else:
        b.prism([(-w / 2 * 0.8, h * 0.55), (w / 2 * 0.8, h * 0.55), (w / 2 * 0.8, h), (-w / 2 * 0.8, h)],
                "y", -d * 0.75, 0.0, "polymer")
    ob = b.build()
    bevel(ob, 0.0008 if lod == 0 else 0.0, 1)
    return ob


# ------------------------------------------------------------------------------------------------ the carrier

def plate_outline(p: dict, seg: int) -> list:
    hw, top, bot = p["half"], p["top"], p["bottom"]
    pts = [(-hw, bot), (hw, bot), (hw, top - p["cut"]), (p["top_half"], top), (-p["top_half"], top),
           (-hw, top - p["cut"])]
    return rounded(pts, 0.016, seg)


def plate_contour(p: dict, facing: float) -> fit.Contour:
    face = fit_state.front_y if facing < 0 else fit_state.back_y
    return fit.circle_contour(p["radius"], face, facing, p["half"] + 0.05)


class _FitState:
    front_y = -0.133
    back_y = 0.122
    # How far each plate is drawn in towards the body by height (fit.Inset), measured once per build.
    front_inset = None
    back_inset = None

    def drawn_in(self, facing: float, z: float) -> float:
        inset = self.front_inset if facing < 0 else self.back_inset
        return inset.at(z)[0] if inset is not None else 0.0


def measure_insets(tree) -> None:
    """Fits both plates to the body up their height: as close as PLATE_GAP, but clear of the cummerbund where its
    wings pass under the plates' edges."""
    def need(u: float, z: float) -> float:
        under = CUMMER["bottom"] - 0.01 <= z <= CUMMER["top"] + 0.01 and abs(u) > CUMMER["tuck"] - 0.02
        return CUMMER["gap"] + CUMMER["thick"] + 0.003 if under else PLATE_GAP

    for p, facing in ((FRONT, -1.0), (BACK, 1.0)):
        con = plate_contour(p, facing)
        inset = fit.plate_inset(tree, con, con.length / 2, p["half"], p["bottom"], p["top"], need)
        if facing < 0:
            fit_state.front_inset = inset
        else:
            fit_state.back_inset = inset


fit_state = _FitState()


def plate_bulge(p: dict, x: float, z: float, lod: int) -> float:
    """How far the plate bag's pillowed face stands out at (x, z), so what's sewn onto it follows it."""
    if lod > 0:
        return 0.0
    hz = (p["top"] - p["bottom"]) / 2
    u = min(1.0, abs(x) / p["half"])
    w = min(1.0, abs(z - (p["bottom"] + hz)) / hz)
    return PILLOW * (1.0 - u * u) * (1.0 - w * w)


def on_plate(ob: bpy.types.Object, p: dict, lod: int) -> None:
    for v in ob.data.vertices:
        v.co.y -= plate_bulge(p, v.co.x, v.co.z, lod)


def plate_bag(kit: Kit, p: dict, facing: float, lod: int) -> fit.Sheet:
    """The plate bag: a padded slab with rounded edges on a shallow cylinder, its inner face p['gap'] off the body."""
    contour = plate_contour(p, facing)
    sheet = fit.Sheet(contour, contour.length / 2,
                      inset=fit_state.front_inset if facing < 0 else fit_state.back_inset)
    b = builder("PlateBag")
    t = p["thick"]
    b.prism(plate_outline(p, (3, 2, 1)[lod]), "y", -t, 0.0, "team")
    ob = b.build()
    bevel(ob, (0.011, 0.008, 0.0)[lod], (2, 1, 0)[lod], angle=25.0)
    fit.subdivide_x(ob, (0.052, 0.07, 0.1)[lod])
    if lod == 0:
        fit.subdivide_z(ob, 0.09)
        fit.pillow(ob, PILLOW, -t * 0.6)
    sheet.warp(ob)
    shade(ob)
    kit.add(ob, "Chest")
    if lod < 2:
        # The binding tape round the bag's outer face: a thin raised rim, one ring.
        rim = builder("PlateRim")
        seg = (3, 1)[lod]
        outer = plate_outline(p, seg)
        inner = plate_outline({**p, "half": p["half"] - 0.011, "top_half": p["top_half"] - 0.008,
                               "top": p["top"] - 0.011, "bottom": p["bottom"] + 0.011}, seg)
        if len(inner) == len(outer):
            def ring(pts: list, y: float) -> list:
                return [(x, y, z) for x, z in pts]
            rim.loft([ring(outer, -t + 0.006), ring(outer, -t - 0.0035), ring(inner, -t - 0.0035),
                      ring(inner, -t + 0.002)], "team_bind", cap0=False, cap1=False)
            ob = rim.build()
            fit.subdivide_x(ob, (0.035, 0.07)[lod])
            sheet.warp(ob)
            shade(ob)
            kit.add(ob, "Chest")
    return sheet


def front_carrier(kit: Kit, lod: int) -> fit.Sheet:
    p = FRONT
    sheet = plate_bag(kit, p, -1.0, lod)
    t = p["thick"]
    # The loop panel across the top (for patches), its own darker loop fabric.
    panel = builder("FrontLoop")
    ph = 0.034
    zc = p["top"] - 0.052
    panel.prism(rrect(0.078, ph, 0.006, (1, 1, 0)[lod]), "y", -t - 0.0035, -t + 0.002, "team_loop",
                offset=(0.0, 0.0, zc))
    ob = panel.build()
    bevel(ob, (0.0012, 0.0, 0.0)[lod], 1)
    fit.subdivide_x(ob, 0.03)
    on_plate(ob, p, lod)
    sheet.warp(ob)
    shade(ob)
    kit.add(ob, "Chest")
    if lod == 0:
        # Two webbing rows under the panel, like the JPC's front.
        ob = molle("FrontWeb", -0.115, 0.115, [p["top"] - 0.112], t, "team_web", lod)
        fit.subdivide_x(ob, 0.04)
        on_plate(ob, p, lod)
        sheet.warp(ob)
        shade(ob)
        kit.add(ob, "Chest")
    return sheet


def back_carrier(kit: Kit, lod: int, with_pack: bool) -> fit.Sheet:
    p = BACK
    sheet = plate_bag(kit, p, 1.0, lod)
    t = p["thick"]
    rows = [p["top"] - 0.085 - i * MOLLE["pitch_z"] for i in range(5)]
    ob = molle("BackWeb", -0.112, 0.112, rows, t, "team_web", lod)
    if ob is not None:
        fit.subdivide_x(ob, 0.04)
        on_plate(ob, p, lod)
        sheet.warp(ob)
        shade(ob)
        kit.add(ob, "Chest")
    if lod < 2:
        # The drag handle: a padded loop across the top of the back.
        b = builder("DragHandle")
        n = (6, 4)[lod]
        path, outs = [], []
        for i in range(n + 1):
            a = math.pi * i / n
            x = -0.068 * math.cos(a)
            out = t * 0.5
            z = p["top"] - 0.012 + 0.034 * math.sin(a)
            path.append(Vector((x, -out, z)))
            outs.append(Vector((0.0, -1.0, 0.0)))
        faces = fit.sweep(b.bm, path, outs, section_rect(0.022, 0.008, 0.003, (1, 0)[lod]))
        for sx in (-1, 1):
            # The handle's ends sewn down under tabs.
            b.box((sx * 0.068 - 0.018, -t - 0.006, p["top"] - 0.05), (sx * 0.068 + 0.018, -t + 0.002, p["top"] - 0.018),
                  "team_web")
        b._faces(faces, "team_web")
        ob = b.build()
        sheet.warp(ob)
        shade(ob)
        kit.add(ob, "Chest")
    return sheet


def cummerbund(kit: Kit, torso: fit.Torso, lod: int, front: fit.Sheet, back: fit.Sheet) -> dict:
    """The two cummerbund wings, front plate to back plate on each side; returns each side's sheet for pouches."""
    c = CUMMER
    radii = torso.band_radii(c["bottom"], c["top"], c["gap"], smooth_deg=14.0)
    sheets = {}
    for side, (t0, t1) in (("L", (8.0, 172.0)), ("R", (188.0, 352.0))):
        con = fit.arc_contour(math.radians(t0), math.radians(t1), radii)
        if side == "L":
            s_a = con.s_where(lambda q: q.x >= c["tuck"])
            s_b = con.s_where(lambda q: q.y > 0.0 and q.x <= c["tuck"])
            vis_a = con.s_where(lambda q: q.x >= FRONT["half"] + 0.008)
            vis_b = con.s_where(lambda q: q.y > 0.0 and q.x <= BACK["half"] + 0.008)
        else:
            s_a = con.s_where(lambda q: q.x <= -c["tuck"])
            s_b = con.s_where(lambda q: q.y < 0.0 and q.x >= -c["tuck"])
            vis_a = con.s_where(lambda q: q.x <= -(BACK["half"] + 0.008))
            vis_b = con.s_where(lambda q: q.y < 0.0 and q.x >= -(FRONT["half"] + 0.008))
        sheet = fit.Sheet(con, 0.0)
        b = builder("Cummerbund" + side)
        h = (c["top"] - c["bottom"]) / 2
        outline = [(x + (s_a + s_b) / 2, z + c["bottom"] + h)
                   for x, z in rrect((s_b - s_a) / 2, h, 0.02, (3, 1, 0)[lod])]
        b.prism(outline, "y", -c["thick"], 0.0, "team")
        ob = b.build()
        bevel(ob, (0.004, 0.0, 0.0)[lod], 1)
        fit.subdivide_x(ob, (0.03, 0.05, 0.1)[lod])
        sheet.warp(ob)
        shade(ob)
        kit.add(ob, "Chest")
        rows = [c["bottom"] + 0.035 + i * MOLLE["pitch_z"] for i in range(3)]
        ob = molle("CummerWeb" + side, vis_a + 0.006, vis_b - 0.006, rows, c["thick"], "team_web", lod)
        if ob is not None:
            fit.subdivide_x(ob, 0.04)
            sheet.warp(ob)
            shade(ob)
            kit.add(ob, "Chest")
        sheets[side] = (sheet, vis_a, vis_b)
    return sheets


def shoulder_path(tree, side: float, z_front: float, y_front: float, z_back: float, y_back: float,
                  gap: float, x_front: float, x_crest: float, x_back: float, half_width: float) -> tuple:
    """The centre line of a strap from the front plate over the shoulder to the back plate, `gap` off the body,
    and the outward direction at each point."""
    centre_z = 1.30
    hits = []
    for i in range(0, 61):
        phi = math.radians(-80.0 + 160.0 * i / 60)
        f = (phi + math.radians(80.0)) / math.radians(160.0)
        x = side * (x_front + (x_crest - x_front) * min(1.0, 2 * f) if f < 0.5
                    else x_crest + (x_back - x_crest) * (2 * f - 1))
        x = side * abs(x)
        d = Vector((0.0, math.sin(phi), math.cos(phi)))
        o = Vector((x, 0.0, centre_z))
        hit = tree.ray_cast(o, d, 0.5)
        if hit[0] is None:
            continue
        p = hit[0] + d * gap
        if p.z < (z_front if phi < 0 else z_back) + 0.01:
            continue
        hits.append((p, d))
    front_x = side * x_front
    back_x = side * x_back
    path = [Vector((front_x, y_front, z_front - 0.045)), Vector((front_x, y_front, z_front - 0.005))]
    path += [h[0] for h in hits]
    path += [Vector((back_x, y_back, z_back - 0.005)), Vector((back_x, y_back, z_back - 0.045))]
    path = fit.smooth_path(fit.resample(path, 0.024), 4)
    # Push any point the smoothing pulled under the body back out, measured across the strap's whole width.
    out_path, outs = [], []
    for p in path:
        o = Vector((p.x, 0.0, centre_z))
        d = (p - o)
        d.x = 0.0
        d.normalize()
        need = (p - o).length
        for dx in (-half_width * 0.5, 0.0, half_width * 0.5):
            oo = o + Vector((dx, 0.0, 0.0))
            hit = tree.ray_cast(oo, d, 0.5)
            if hit[0] is not None:
                need = max(need, (hit[0] - oo).length + gap)
        out_path.append(o + d * need)
        outs.append(d)
    return out_path, outs


def shoulder_straps(kit: Kit, tree, lod: int, pack: bool = False) -> list:
    """The carrier's padded shoulder straps, coming out of the plate bags' top edges (or, with `pack`, the pack's,
    laid over them from just above the front plate to the pack's face)."""
    s = STRAP
    fy = fit_state.front_y + fit_state.drawn_in(-1.0, FRONT["top"]) - FRONT["thick"] / 2
    by = fit_state.back_y - fit_state.drawn_in(1.0, BACK["top"]) + BACK["thick"] / 2
    made = []
    for side in (1.0, -1.0):
        path, outs = shoulder_path(tree, side, FRONT["top"], fy, BACK["top"], by, s["gap"], s["front_x"],
                                   s["crest_x"], s["back_x"], s["width"] / 2)
        w, t = s["width"], s["thick"]
        mat = "team"
        if pack:
            lift = s["thick"] + 0.003
            path = [p + o * lift for p, o in zip(path, outs)]
            first = next(i for i, p in enumerate(path) if p.z > FRONT["top"] + 0.03)
            path, outs = path[first:], outs[first:]
            w, t = 0.058, 0.012
            mat = "ranger"
        ob = sweep_ob("Strap", path, outs, section_rect(w, t, t * 0.45, (1, 0, 0)[lod]), mat)
        if not pack:
            # Where it goes into a plate bag's top the strap thins, so it can't show through the bag's rounded edge.
            for v in ob.data.vertices:
                if v.co.y < 0.0 and v.co.z < FRONT["top"] + 0.012:
                    v.co.y = min(max(v.co.y, fy - 0.009), fy + 0.009)
                elif v.co.y > 0.0 and v.co.z < BACK["top"] + 0.012:
                    v.co.y = min(max(v.co.y, by - 0.009), by + 0.009)
        shade(ob)
        crest = max(p.z for p in path)

        def rule(co, crest=crest, side=side):
            # Over the shoulder the strap follows the collarbone a little.
            k = max(0.0, min(1.0, (co.z - (crest - 0.05)) / 0.05)) * 0.3
            return {"Chest": 1.0 - k, ("Shoulder_L" if side > 0 else "Shoulder_R"): k}
        kit.add(ob, rule)
        made.append((path, outs))
        if lod < 2 and not pack:
            # A quick-release buckle on the front of each strap, just above the plate.
            k = next(i for i, p in enumerate(path) if p.z > FRONT["top"] + 0.04)
            p, o = path[k], outs[k]
            tng = (path[k + 1] - path[k - 1]).normalized()
            x = tng.cross(o).normalized()
            m = Matrix((
                (x.x, -o.x, tng.x, p.x), (x.y, -o.y, tng.y, p.y), (x.z, -o.z, tng.z, p.z), (0, 0, 0, 1)))
            buckle = side_release("StrapBuckle", lod, w=0.062, h=0.068, d=0.012)
            if buckle is not None:
                place(buckle, m @ Matrix.Translation((0.0, -t + 0.002, -0.034)))
                shade(buckle)
                kit.add(buckle, "Chest")
    return made


# ----------------------------------------------------------------------------------------------------- pouches

def mag_pouch(lod: int) -> list:
    """A tall open-top AEG magazine pouch after the owner's olive single-mag photo (front view, foot at z=0, back on
    y=0): a filled body with a webbing band across its face, the magazine standing well proud of it, a shock cord
    over the magazine's base plate and down across its front, and a webbing pull tab with a ring above it all."""
    hw, h, d = 0.035, 0.13, 0.034
    obs = []
    body = soft_box("MagPouch", hw, h / 2, d, "coyote", 0.008, (0.007, 0.004, 0.0)[lod], (2, 1, 0)[lod],
                    corner_seg=(2, 1, 0)[lod])
    if lod == 0:
        fit.subdivide_z(body, 0.045)
        fit.pillow(body, 0.004, -d * 0.6)
    obs.append(body)
    if lod < 2:
        band = builder("MagBand")
        for z0, z1 in ((0.01, 0.032), (0.052, 0.08)):
            band.prism(rounded([(-hw - 0.0015, z0), (hw + 0.0015, z0), (hw + 0.0015, z1), (-hw - 0.0015, z1)],
                               0.002, (1, 0)[lod]), "y", -d - 0.0075, -d + 0.004, "coyote_web")
        if lod == 0:
            # The bound mouth: a lip of binding tape round the top.
            band.prism(rrect(hw + 0.0018, d / 2 + 0.0018, 0.008, 1), "z", h - 0.009, h + 0.0015, "coyote_web",
                       offset=(0.0, -d / 2, 0.0))
        ob = band.build()
        obs.append(ob)
    # The magazine: base plate up, standing 35 mm proud.
    mag = builder("Mag")
    mw, md = 0.029, 0.0115
    yc = -d / 2
    mag.prism(rrect(mw, md, 0.003, (1, 0, 0)[lod]), "z", h - 0.03, h + 0.036, "polymer", offset=(0.0, yc, 0.0))
    mag.prism(rrect(mw + 0.003, md + 0.0028, 0.004, (1, 0, 0)[lod]), "z", h + 0.036, h + 0.046, "polymer",
              offset=(0.0, yc, 0.0))
    if lod == 0:
        # The magazine's ribs on its face.
        for i in range(2):
            zz = h + 0.008 + i * 0.012
            mag.box((-mw * 0.8, yc - md - 0.0012, zz), (mw * 0.8, yc - md + 0.001, zz + 0.004), "polymer")
    ob = mag.build()
    obs.append(ob)
    if lod == 0:
        # The shock cord: from each side of the pouch's mouth, over the base plate and down the magazine's front to
        # the pull tab, which stands up above it with its ring.
        cord = [(-0.0019, -0.0019), (0.0019, -0.0019), (0.0019, 0.0019), (-0.0019, 0.0019)]
        b = builder("Bungee")
        for sx in (-1, 1):
            pts = [Vector((sx * (hw - 0.004), -d - 0.002, h - 0.012)), Vector((sx * (mw + 0.003), yc - md - 0.004, h + 0.02)),
                   Vector((sx * 0.012, yc - md - 0.004, h + 0.04)), Vector((sx * 0.004, yc, h + 0.05)),
                   Vector((0.0, yc + md + 0.002, h + 0.045))]
            outs = [Vector((0.0, -1.0, 0.0))] * len(pts)
            b._faces(fit.sweep(b.bm, pts, outs, cord), "cord")
        tab = rounded([(-0.0105, h + 0.044), (0.0105, h + 0.044), (0.0105, h + 0.07), (-0.0105, h + 0.07)], 0.004, 1)
        b.prism(tab, "y", yc - md - 0.0075, yc - md - 0.0045, "tan_web")
        # The ring at the tab's foot, where the cord meets it.
        ring_c = Vector((0.0, yc - md - 0.006, h + 0.038))
        segs = 8
        rr, tt = 0.009, 0.0016
        rings = []
        for i in range(segs + 1):
            a = math.tau * i / segs
            c = ring_c + Vector((rr * math.cos(a), 0.0, rr * math.sin(a)))
            n = Vector((math.cos(a), 0.0, math.sin(a)))
            rings.append([c + n * (tt * math.cos(math.tau * k / 4)) + Vector((0.0, tt * math.sin(math.tau * k / 4), 0.0))
                          for k in range(4)])
        b.loft(rings, "metal", cap0=False, cap1=False)
        obs.append(b.build())
    elif lod == 1:
        b = builder("Tab")
        b.prism([(-0.0105, h + 0.03), (0.0105, h + 0.03), (0.0105, h + 0.07), (-0.0105, h + 0.07)], "y",
                yc - md - 0.0075, yc - md - 0.0045, "tan_web")
        obs.append(b.build())
    return obs


def lid_pouch(name: str, hw: float, h: float, d: float, lod: int, mat: str = "coyote", web: str = "coyote_web",
              buckle: bool = True) -> list:
    """A pouch with a lid folded over its top and down its face, held by a strap and a side-release buckle (the
    owner's general-purpose and grenade pouch photos). Front view, foot at z=0, back on y=0."""
    obs = []
    body = soft_box(name, hw, h / 2, d, mat, 0.01, (0.007, 0.004, 0.0)[lod], (2, 1, 0)[lod],
                    corner_seg=(2, 1, 0)[lod])
    if lod == 0:
        fit.subdivide_x(body, hw * 0.9)
        fit.subdivide_z(body, h * 0.45)
        fit.pillow(body, 0.006, -d * 0.6)
    obs.append(body)
    # The lid: over the top, down the face a quarter of the way.
    lid = builder(name + "Lid")
    drop = h * 0.26
    top = [(-hw - 0.003, h - 0.004), (hw + 0.003, h - 0.004), (hw + 0.003, h + 0.006), (-hw - 0.003, h + 0.006)]
    lid.prism(top, "y", -d - 0.006, 0.0, mat)
    front = [(-hw - 0.003, h - drop), (hw + 0.003, h - drop), (hw + 0.003, h + 0.006), (-hw - 0.003, h + 0.006)]
    lid.prism(rounded(front, 0.006, 1 if lod == 0 else 0), "y", -d - 0.009, -d - 0.002, mat)
    ob = lid.build()
    bevel(ob, (0.003, 0.0, 0.0)[lod], 1)
    for v in ob.data.vertices:
        # The lid's flap droops out over the filled body.
        if v.co.z < h - 0.004:
            v.co.y -= 0.004 * (h - v.co.z) / drop
    obs.append(ob)
    if lod < 2:
        strap = builder(name + "Strap")
        strap.box((-0.0125, -d - 0.0115, h - drop - 0.035), (0.0125, -d - 0.0085, h - drop + 0.012), web)
        strap.box((-0.0125, -d - 0.0045, 0.012), (0.0125, -d + 0.001, h - drop - 0.01), web)
        ob = strap.build()
        bevel(ob, (0.0007, 0.0, 0.0)[lod], 1)
        obs.append(ob)
        if buckle:
            bk = side_release(name + "Buckle", lod)
            if bk is not None:
                place(bk, Matrix.Translation((0.0, -d - 0.006, h - drop - 0.05)))
                obs.append(bk)
    return obs


def on_sheet(obs: list, m: Matrix, kit: Kit, weights, name: str) -> bpy.types.Object:
    obs = [o for o in obs if o is not None]
    for o in obs:
        place(o, m)
    ob = join(name, obs)
    shade(ob)
    kit.add(ob, weights)
    return ob


def front_pouches(kit: Kit, front: fit.Sheet, lod: int) -> None:
    for i, u in enumerate((-0.083, 0.0, 0.083)):
        m = front.frame(u, FRONT["bottom"] + 0.012, FRONT["thick"] + plate_bulge(FRONT, u, FRONT["bottom"] + 0.07, lod))
        on_sheet(mag_pouch(lod), m, kit, "Chest", "MagPouch%d" % i)


def side_pouch(kit: Kit, sheets: dict, lod: int) -> None:
    sheet, a, b = sheets["R"]
    u = a + (b - a) * 0.36
    m = sheet.frame(u, CUMMER["bottom"] + 0.012, CUMMER["thick"])
    on_sheet(lid_pouch("GPPouch", 0.05, 0.125, 0.05, lod), m, kit, "Chest", "GPPouch")


# ------------------------------------------------------------------------------------------------------ the belt

def belt(kit: Kit, torso: fit.Torso, lod: int) -> fit.Sheet:
    p = BELT
    radii = torso.band_radii(p["bottom"] - 0.01, p["top"] + 0.01, p["gap"], smooth_deg=10.0)
    con = fit.arc_contour(0.0, math.tau, radii)
    sheet = fit.Sheet(con, 0.0)
    gap_half = 0.045  # the front, where the rigger belt and buckle show
    h = (p["top"] - p["bottom"]) / 2
    b = builder("Belt")
    outline = [(x + con.length / 2, z + p["bottom"] + h)
               for x, z in rrect(con.length / 2 - gap_half, h, 0.012, (2, 1, 0)[lod])]
    b.prism(outline, "y", -p["thick"], 0.0, "coyote")
    ob = b.build()
    bevel(ob, (0.004, 0.002, 0.0)[lod], 1)
    fit.subdivide_x(ob, (0.04, 0.06, 0.1)[lod])
    sheet.warp(ob)
    shade(ob)
    kit.add(ob, "Hips")
    # The rigger belt through it, all the way round, showing at the front.
    rb = builder("Rigger")
    rh = 0.019
    zc = p["bottom"] + h
    rb.prism([(-0.01, zc - rh), (con.length + 0.01, zc - rh), (con.length + 0.01, zc + rh), (-0.01, zc + rh)],
             "y", -0.004, 0.001, "tan_web")
    ob = rb.build()
    fit.subdivide_x(ob, (0.045, 0.07, 0.12)[lod])
    sheet.warp(ob)
    shade(ob)
    kit.add(ob, "Hips")
    rows = [(p["bottom"] + p["top"]) / 2]
    ob = molle("BeltWeb", gap_half + 0.05, con.length - gap_half - 0.05, rows, p["thick"], "coyote_web", lod)
    if ob is not None:
        fit.subdivide_x(ob, 0.04)
        sheet.warp(ob)
        shade(ob)
        kit.add(ob, "Hips")
    if lod < 2:
        # The buckle at the front: a dark metal frame either side of a centre plate.
        bk = builder("BeltBuckle")
        bk.prism(rrect(0.032, 0.022, 0.006, (1, 1, 0)[lod]), "y", -0.007, 0.0, "metal",
                 offset=(0.0, 0.0, zc))
        if lod == 0:
            bk.prism(rrect(0.012, 0.016, 0.003, 1), "y", -0.0105, -0.006, "metal", offset=(0.0, 0.0, zc))
            for sx in (-1, 1):
                bk.box((sx * 0.024 - 0.004, -0.0095, zc - 0.019), (sx * 0.024 + 0.004, -0.006, zc + 0.019), "metal")
        ob = bk.build()
        bevel(ob, (0.0012, 0.0, 0.0)[lod], 1)
        place(ob, sheet.frame(0.0, 0.0, 0.004))
        shade(ob)
        kit.add(ob, "Hips")
    return sheet


def _open_mouth(ob, wall: float, depth: float) -> None:
    """Opens the holster's mouth: its faces looking up are inset by the wall and sunk `depth` into a pocket."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    top = [f for f in bm.faces if f.normal.z > 0.6 and f.calc_center_median().z > -0.02]
    res = bmesh.ops.inset_region(bm, faces=top, thickness=wall, depth=0.0, use_even_offset=True)
    del res
    for v in {v for f in top for v in f.verts}:
        v.co.z -= depth
    bm.normal_update()
    bm.to_mesh(ob.data)
    bm.free()


def holster(lod: int) -> list:
    """An empty moulded polymer holster on a drop mount, muzzle down, its open mouth showing the pocket. Sized to take
    either pistol (the Cyber Pistol is the larger: 38 mm wide, 84 mm deep over its trigger guard, 67 mm at its muzzle).
    Built in the belt's frame: x towards the figure's front (the slide's top faces forward), z up from the belt's top
    edge, -y out from the hip; its back on y=0."""
    obs = []
    wall = 0.004
    t0, t1 = -0.054, -0.006  # the shell's outer and inner faces: 40 mm inside
    b = builder("Holster")
    prof = [(0.004, -0.178), (0.004, 0.0), (-0.004, 0.008), (-0.05, 0.008), (-0.086, -0.004), (-0.092, -0.05),
            (-0.077, -0.078), (-0.072, -0.178), (-0.062, -0.186), (-0.006, -0.186)]
    b.prism(rounded(prof, 0.009, (2, 1, 0)[lod]), "y", t0, t1, "polymer")
    ob = b.build()
    bevel(ob, (0.005, 0.003, 0.0)[lod], (2, 1, 1)[lod], angle=35.0)
    if lod < 2:
        _open_mouth(ob, wall, (0.06, 0.03)[lod])
    obs.append(ob)
    if lod == 0:
        # The sight channel along the front edge and the moulded ejection-port bulge on the outside.
        d = builder("HolsterDetail")
        d.prism(rounded([(0.0, -0.17), (0.0075, -0.17), (0.0075, -0.006), (0.0, -0.002)], 0.002, 1), "y",
                -0.036, -0.024, "polymer")
        d.prism(rounded([(-0.04, -0.07), (-0.008, -0.07), (-0.008, -0.026), (-0.04, -0.026)], 0.006, 2), "y",
                t0 - 0.0035, t0 + 0.004, "polymer")
        ob = d.build()
        bevel(ob, 0.0012, 1)
        obs.append(ob)
    if lod < 2:
        # The retention screw over the trigger guard, through the outside face.
        sc = builder("HolsterScrew")
        sc.lathe([(0.0, 0.0065), (0.003, 0.0065), (0.0045, 0.004)], "metal", (8, 6)[lod],
                 centre=(-0.07, t0 - 0.0015, -0.03), axis="y")
        obs.append(sc.build())
        # The mount: a plate on the belt with the holster's back screwed to it.
        mt = builder("Mount")
        mt.prism(rounded([(-0.052, -0.068), (0.008, -0.068), (0.008, HOLSTER_DROP - 0.006), (-0.052, HOLSTER_DROP - 0.006)],
                         0.008, (1, 0)[lod]),
                 "y", -0.0065, 0.0, "polymer")
        if lod == 0:
            # The mount's two belt loops, wrapping over the belt above and below its screws.
            for z0 in (HOLSTER_DROP - 0.05, HOLSTER_DROP - 0.016):
                mt.box((-0.056, -0.0095, z0 - 0.007), (0.012, -0.006, z0 + 0.007), "polymer")
        ob = mt.build()
        bevel(ob, (0.0015, 0.0, 0.0)[lod], 1)
        obs.append(ob)
    return obs


def dump_pouch(lod: int) -> list:
    """A rolled-up dump pouch (front view, foot at z=0): a soft roll under a flap with a hook tab."""
    roll = soft_box("DumpRoll", 0.085, 0.034, 0.045, "coyote", 0.024, (0.016, 0.008, 0.0)[lod], (2, 1, 0)[lod],
                    corner_seg=(2, 1, 0)[lod])
    if lod == 0:
        fit.subdivide_x(roll, 0.05)
        fit.pillow(roll, 0.007, -0.045 * 0.6)
    for v in roll.data.vertices:
        # The rolled fabric sags at its middle and rounds over at its top.
        u = min(1.0, abs(v.co.x) / 0.085)
        if v.co.z < 0.034:
            v.co.z -= 0.009 * (1.0 - u * u) * (1.0 - v.co.z / 0.034)
        else:
            v.co.y *= 1.0 - 0.12 * min(1.0, (v.co.z - 0.034) / 0.034)
    obs = [roll]
    if lod < 2:
        flap = builder("DumpFlap")
        flap.prism(rounded([(-0.06, 0.03), (0.06, 0.03), (0.06, 0.075), (-0.06, 0.075)], 0.01, 2 if lod == 0 else 0),
                   "y", -0.05, -0.043, "coyote_web")
        ob = flap.build()
        bevel(ob, (0.0015, 0.0, 0.0)[lod], 1)
        for v in ob.data.vertices:
            v.co.y *= 1.0 - 0.12 * max(0.0, min(1.0, (v.co.z - 0.034) / 0.034))
        obs.append(ob)
        if lod == 0:
            obs.append(box_ob("DumpTab", (-0.015, -0.053, 0.02), (0.015, -0.049, 0.04), "tan_web", 0.0008))
    return obs


def belt_gear(kit: Kit, sheet: fit.Sheet, lod: int) -> Matrix:
    """The belt's holster and pouches; gives the pistol's seat in the holster (PISTOL_SEAT_NODE), in the figure's frame
    (Blender's axes)."""
    con = sheet.c
    L = con.length

    def s_at(theta_deg: float) -> float:
        want = fit.way(math.radians(theta_deg))
        return con.s_where(lambda q: Vector((q.x, q.y, 0.0)).normalized().dot(want) > 0.9995)

    # Holster, the figure's right hip, a little forward of the side, canted forward.
    # Hung HOLSTER_DROP below the belt's top on a drop mount, so a drawn pistol would clear the cummerbund now
    # the belt rides at the waist.
    m = sheet.frame(s_at(258.0), BELT["top"] - HOLSTER_DROP, BELT["thick"] - 0.008)
    m = m @ Matrix.Rotation(math.radians(10.0), 4, "Y")
    seat = m @ Matrix.Translation(PISTOL_SEAT_AT)
    obs = holster(lod)
    for o in obs:
        place(o, m)
    ob = join("HolsterAll", obs)
    shade(ob)

    def holster_rule(co):
        k = max(0.0, min(1.0, (BELT["bottom"] - co.z) / 0.12)) * 0.35
        return {"Hips": 1.0 - k, "Thigh_R": k}
    kit.add(ob, holster_rule)
    # The grenade pouch on the left front of the belt.
    m = sheet.frame(s_at(62.0), BELT["top"] - 0.105, BELT["thick"] + 0.001)
    on_sheet(lid_pouch("GrenadePouch", 0.032, 0.105, 0.05, lod), m, kit, "Hips", "GrenadePouch")
    # The dump pouch at the back, left of the spine.
    m = sheet.frame(s_at(162.0), BELT["bottom"] - 0.03, BELT["thick"] + 0.001)
    on_sheet(dump_pouch(lod), m, kit, "Hips", "DumpPouch")
    del L
    return seat


# ------------------------------------------------------------------------------------------------------ the radio

def radio(kit: Kit, sheets: dict, lod: int) -> None:
    sheet, a, b = sheets["L"]
    u = a + (b - a) * 0.62
    m = sheet.frame(u, CUMMER["bottom"] + 0.02, CUMMER["thick"])
    obs = []
    hw, h, d = 0.033, 0.074, 0.038
    obs.append(soft_box("RadioPouch", hw, h / 2, d, "coyote", 0.008, (0.005, 0.003, 0.0)[lod], (2, 1, 0)[lod],
                        corner_seg=(2, 1, 0)[lod]))
    if lod == 0:
        obs.append(box_ob("RadioPouchBand", (-hw - 0.0015, -d - 0.004, h - 0.024), (hw + 0.0015, -d + 0.003, h - 0.002),
                          "coyote_web", 0.0008))
    # The radio: body, the top with knob and antenna, the display and speaker on its face, standing in the pouch.
    rw, rd, rh = 0.029, 0.016, 0.112
    r = builder("Radio")
    yc = -d / 2
    r.prism(rrect(rw, rd, 0.006, (3, 1, 1)[lod]), "z", 0.008, rh, "polymer", offset=(0.0, yc, 0.0))
    ob = r.build()
    bevel(ob, (0.002, 0.0, 0.0)[lod], 1)
    obs.append(ob)
    top = rh
    knob = builder("Knob")
    seg = (10, 6, 4)[lod]
    knob.lathe([(top - 0.001, 0.0085), (top + 0.013, 0.0085), (top + 0.015, 0.0065)], "rubber", seg,
               centre=(0.015, yc, 0.0), axis="z")
    knob.lathe([(top - 0.001, 0.007), (top + 0.008, 0.0068), (top + 0.012, 0.0045)], "rubber", seg,
               centre=(-0.015, yc + 0.002, 0.0), axis="z")
    ob = knob.build()
    obs.append(ob)
    # The antenna: a 6 cm stub (the owner, 2026-11-05: the long whip reached under the arm), nearly upright, leaning a
    # little back, its tip well under the armpit. Its profile in metres up from its base.
    ant = builder("Antenna")
    base = Vector((-0.015, yc + 0.002, top + 0.008))
    lean = Vector((0.2, 0.03, 1.0)).normalized()
    rings = []
    segs = (8, 4, 4)[lod]
    prof = ((0.0, 0.0078), (0.018, 0.0072), (0.022, 0.0054), (0.048, 0.005), (0.057, 0.0044), (0.06, 0.0028))
    if lod == 0:
        # The ribbed base.
        prof = ((0.0, 0.008), (0.006, 0.008), (0.007, 0.0064), (0.01, 0.0064), (0.011, 0.0075), (0.015, 0.0075),
                (0.016, 0.006), (0.019, 0.0058), (0.022, 0.0048)) + prof[3:]
    for i, (f, rr) in enumerate(prof):
        c = base + lean * f
        side = lean.cross(Vector((0.0, 1.0, 0.0))).normalized()
        up = side.cross(lean).normalized()
        rings.append([c + side * (rr * math.cos(math.tau * k / segs)) + up * (rr * math.sin(math.tau * k / segs))
                      for k in range(segs)])
    ant.loft(rings, "rubber")
    ob = ant.build()
    obs.append(ob)
    if lod < 2:
        face = builder("Face")
        face.box((-0.022, yc - rd - 0.0012, rh - 0.045), (0.022, yc - rd + 0.001, rh - 0.012), "lcd")
        if lod == 0:
            # The speaker's grille, a strip of slots below the display.
            for i in range(5):
                zz = rh - 0.054 - i * 0.0042
                face.box((-0.016, yc - rd - 0.0009, zz), (0.016, yc - rd + 0.001, zz + 0.0018), "rubber")
            # The push-to-talk key on the side.
            face.box((rw - 0.001, yc - 0.008, rh - 0.06), (rw + 0.0028, yc + 0.008, rh - 0.032), "rubber")
        ob = face.build()
        obs.append(ob)
    for o in obs:
        place(o, m)
    ob = join("RadioAll", obs)
    shade(ob)
    kit.add(ob, "Chest")


# ------------------------------------------------------------------------------------------------------- the pack

PACK = dict(half=0.138, bottom=0.995, top=1.39, depth=0.105, top_depth=0.045)


def piping(name: str, outline: list, y: float, mat: str, r: float = 0.0028, step: float = 0.04) -> bpy.types.Object:
    """A zip's piping: a thin square tube round a closed outline (x, z) at depth y."""
    b = builder(name)
    pts = []
    for (xa, za), (xb, zb) in zip(outline, outline[1:] + outline[:1]):
        # Densified, so the piping follows whatever the face is bent to after.
        n = max(1, int(math.hypot(xb - xa, zb - za) / step + 0.5))
        pts += [Vector((xa + (xb - xa) * i / n, y, za + (zb - za) * i / n)) for i in range(n)]
    pts.append(pts[0])
    rings = []
    for i, p in enumerate(pts[:-1]):
        a = pts[i - 1] if i > 0 else pts[-2]
        c = pts[i + 1]
        t = (c - a).normalized()
        side = t.cross(Vector((0.0, -1.0, 0.0))).normalized()
        rings.append([p + side * r, p + Vector((0.0, -r, 0.0)), p - side * r, p + Vector((0.0, r * 0.3, 0.0))])
    vr = [[b.bm.verts.new(q) for q in ring] for ring in rings]
    faces = []
    for i in range(len(vr)):
        ra, rb = vr[i], vr[(i + 1) % len(vr)]
        for k in range(4):
            q = (k + 1) % 4
            faces.append(b.bm.faces.new((ra[k], ra[q], rb[q], rb[k])))
    bmesh.ops.recalc_face_normals(b.bm, faces=faces)
    b._faces(faces, mat)
    return b.build()


def pack(kit: Kit, tree, lod: int) -> None:
    """The assault pack, built seen from behind (x to the viewer's right, z up, -y out of its back, its face against
    the carrier on y=0), then turned to face +Y onto the back plate's webbing."""
    p = PACK
    y0 = fit_state.back_y + BACK["thick"] + MOLLE["raise_"] - 0.001
    to_back = Matrix.Translation((0.0, y0, 0.0)) @ Matrix.Rotation(math.pi, 4, "Z")
    obs = []
    hh = (p["top"] - p["bottom"]) / 2
    zc = p["bottom"] + hh

    def taper(ob: bpy.types.Object, z0: float, z1: float, f0: float, f1: float) -> None:
        for v in ob.data.vertices:
            f = max(0.0, min(1.0, (v.co.z - z0) / (z1 - z0)))
            v.co.y *= f0 + (f1 - f0) * f * f

    # The main compartment: a padded body, rounder and thinner at the top.
    main = builder("PackMain")
    outline = rounded([(-p["half"], p["bottom"]), (p["half"], p["bottom"]), (p["half"], p["top"] - 0.05),
                       (p["half"] - 0.05, p["top"]), (-p["half"] + 0.05, p["top"]), (-p["half"], p["top"] - 0.05)],
                      0.035, (3, 2, 1)[lod])
    main.prism(outline, "y", -p["depth"], 0.0, "ranger")
    ob = main.build()
    bevel(ob, (0.032, 0.022, 0.0)[lod], (2, 1, 0)[lod], angle=25.0)
    for v in ob.data.vertices:
        # The back panel lies flat on the carrier: its bevel squashed.
        if v.co.y > -0.032:
            v.co.y *= 0.3
    taper(ob, p["bottom"] + 0.12, p["top"], 1.0, p["top_depth"] / p["depth"])
    obs.append(ob)
    if lod == 0:
        # The main zip's piping round the back panel's edge.
        e = 0.034  # inside the bevel, on the flat face
        inner = rounded([(-p["half"] + e, p["bottom"] + e), (p["half"] - e, p["bottom"] + e),
                         (p["half"] - e, p["top"] - 0.055), (p["half"] - 0.068, p["top"] - e),
                         (-p["half"] + 0.068, p["top"] - e), (-p["half"] + e, p["top"] - 0.055)], 0.03, 2)
        pip = piping("PackZip", inner, 0.0, "cord")
        face = BVHTree.FromPolygons([v.co.copy() for v in ob.data.vertices],
                                    [list(q.vertices) for q in ob.data.polygons])
        for v in pip.data.vertices:
            # Dropped onto the tapered, bevelled body's outer face.
            hit = face.ray_cast(Vector((v.co.x, -1.0, v.co.z)), Vector((0.0, 1.0, 0.0)))[0]
            if hit is not None:
                v.co.y += hit.y + 0.0005
        obs.append(pip)
    # The lower front pocket over half the height, the admin pocket above it (the owner's pack photos).
    fc_d, fc_hh, fc_z0, sink = 0.05, 0.116, 0.02, 0.016
    fc_h = 2 * fc_hh
    front_z = lambda z: -p["depth"] * (1.0 - (1.0 - p["top_depth"] / p["depth"]) * max(
        0.0, min(1.0, (z - p["bottom"] - 0.12) / (p["top"] - p["bottom"] - 0.12))) ** 2)

    def fc_pillow(x: float, z: float) -> float:
        """How far the lower pocket's pillowed face stands out at (x, z), z from its foot."""
        if lod > 0:
            return 0.0
        u, w = min(1.0, abs(x) / 0.118), min(1.0, abs(z - fc_hh) / fc_hh)
        return 0.008 * (1.0 - u * u) * (1.0 - w * w)

    fc = soft_box("PackFront", 0.118, fc_hh, fc_d, "ranger", 0.03, (0.014, 0.01, 0.0)[lod], (2, 1, 0)[lod],
                  corner_seg=(2, 2, 1)[lod])
    if lod == 0:
        fit.subdivide_x(fc, 0.08)
        fit.subdivide_z(fc, 0.075)
        fit.pillow(fc, 0.008, -fc_d * 0.6)
        # The pocket's zip round its face.
        fpip = piping("PackFrontZip", rounded([(-0.104, 0.014), (0.104, 0.014), (0.104, fc_h - 0.014),
                                               (-0.104, fc_h - 0.014)], 0.024, 2), -fc_d - 0.0005, "cord", r=0.0024)
        for v in fpip.data.vertices:
            v.co.y -= fc_pillow(v.co.x, v.co.z)
        fc = join("PackFront", [fc, fpip])
    for v in fc.data.vertices:
        z = v.co.z + p["bottom"] + fc_z0
        v.co.y += front_z(z) + sink
        v.co.z = z
    obs.append(fc)
    web = molle("PackWeb", -0.088, 0.088, [0.03 + i * MOLLE["pitch_z"] for i in range(3)], 0.0, "ranger_web", lod)
    if web is not None:
        for v in web.data.vertices:
            z = v.co.z + p["bottom"] + fc_z0
            v.co.y += front_z(z) + sink - fc_d + 0.0012 - fc_pillow(v.co.x, v.co.z)
            v.co.z = z
        obs.append(web)
    # The admin pocket above it, with a loop panel for a patch and its own zip.
    ad_d, ad_hh, ad_z0 = 0.034, 0.076, fc_z0 + fc_h + 0.003
    ad = soft_box("PackAdmin", 0.1, ad_hh, ad_d, "ranger", 0.024, (0.01, 0.006, 0.0)[lod], (2, 1, 0)[lod],
                  corner_seg=(2, 1, 0)[lod])
    if lod == 0:
        fit.subdivide_x(ad, 0.1)
        fit.pillow(ad, 0.005, -ad_d * 0.6)
        apip = piping("PackAdminZip", rounded([(-0.086, 0.09), (0.086, 0.09), (0.086, 2 * ad_hh - 0.012),
                                               (-0.086, 2 * ad_hh - 0.012)], 0.02, 2), -ad_d - 0.0005, "cord",
                      r=0.0022)
        for v in apip.data.vertices:
            # Riding the pocket's pillow.
            u, w = min(1.0, abs(v.co.x) / 0.1), min(1.0, abs(v.co.z - ad_hh) / ad_hh)
            v.co.y -= 0.005 * (1.0 - u * u) * (1.0 - w * w)
        ad = join("PackAdmin", [ad, apip])
    for v in ad.data.vertices:
        z = v.co.z + p["bottom"] + ad_z0
        v.co.y += front_z(z) + sink * 0.6
        v.co.z = z
    obs.append(ad)
    if lod < 2:
        lp = builder("PackLoop")
        lp.prism(rounded([(-0.07, -0.022), (0.07, -0.022), (0.07, 0.022), (-0.07, 0.022)], 0.005, (1, 0)[lod]),
                 "y", -0.003, 0.002, "ranger_loop")
        ob = lp.build()
        if lod == 0:
            fit.subdivide_x(ob, 0.035)
            fit.subdivide_z(ob, 0.015)
        z0 = ad_z0 + 0.042
        face = BVHTree.FromPolygons([v.co.copy() for v in ad.data.vertices],
                                    [list(q.vertices) for q in ad.data.polygons])
        for v in ob.data.vertices:
            # Dropped onto the admin pocket's face, which leans in with the pack's taper and bulges at its middle.
            z = p["bottom"] + z0 + v.co.z
            hit = face.ray_cast(Vector((v.co.x, -1.0, z)), Vector((0.0, 1.0, 0.0)))[0]
            v.co.y += (hit.y if hit is not None else front_z(z) - ad_d) - 0.0015
            v.co.z = z
        obs.append(ob)
        # The grab handle over the top.
        b = builder("PackHandle")
        n = (8, 4)[lod]
        path, outs = [], []
        for i in range(n + 1):
            a = math.pi * i / n
            path.append(Vector((-0.04 * math.cos(a), -p["top_depth"] * 0.45, p["top"] - 0.006 + 0.026 * math.sin(a))))
            outs.append(Vector((0.0, 0.0, 1.0)))
        faces = fit.sweep(b.bm, path, outs, section_rect(0.022, 0.005, 0.002, (1, 0)[lod]))
        b._faces(faces, "ranger_web")
        obs.append(b.build())
        # Two 25 mm compression straps round each side, each with a big side-release buckle.
        for sx in (-1, 1):
            x = sx * p["half"]
            for zc in (p["bottom"] + 0.11, p["bottom"] + 0.29):
                depth = -front_z(zc)
                st = builder("PackSideStrap")
                st.box((min(x - sx * 0.002, x + sx * 0.005), -depth * 0.86, zc - 0.0125),
                       (max(x - sx * 0.002, x + sx * 0.005), -0.012, zc + 0.0125), "ranger_web")
                obs.append(st.build())
                # A plain moulded buckle, light enough for the budget.
                bk = builder("PackBuckle")
                bk.box((-0.016, -0.006, -0.023), (0.016, 0.0, 0.023), "ranger_loop")
                if lod == 0:
                    bk.box((-0.011, -0.0095, -0.012), (0.011, -0.006, 0.019), "ranger_loop")
                bk = bk.build()
                if bk is not None:
                    place(bk, Matrix.Translation((x + sx * 0.005, -depth * 0.45, zc))
                          @ Matrix.Rotation(sx * math.pi / 2, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "Y"))
                    obs.append(bk)
    if lod == 0:
        # Zip pullers: cord loops with tabs, two at the main zip's top, two on each pocket.
        zf, za = p["bottom"] + fc_z0 + fc_h - 0.008, p["bottom"] + ad_z0 + 2 * ad_hh - 0.006
        for (x, z, y) in ((-0.045, p["top"] - 0.012, -0.004), (0.045, p["top"] - 0.012, -0.004),
                          (-0.03, zf, front_z(zf) + sink - fc_d), (0.03, zf, front_z(zf) + sink - fc_d),
                          (-0.03, za, front_z(za) + sink * 0.6 - ad_d), (0.03, za, front_z(za) + sink * 0.6 - ad_d)):
            obs.append(box_ob("Puller", (x - 0.0035, y - 0.004, z - 0.024), (x + 0.0035, y, z), "cord"))
    for o in obs:
        # The pack hugs the back plate's curve, and follows it in where the plate is drawn in to the back.
        r = BACK["radius"]
        for v in o.data.vertices:
            v.co.y += r * (1.0 - math.cos(v.co.x / r))
        place(o, to_back)
        for v in o.data.vertices:
            v.co.y -= fit_state.drawn_in(1.0, v.co.z)
    ob = join("PackAll", obs)
    shade(ob)
    kit.add(ob, "Chest")
    # The shoulder straps, over the carrier's, each ending in a ladder lock and a webbing tail on the chest.
    straps = Kit("PackStraps", lod)
    made = shoulder_straps(straps, tree, lod, pack=True)
    for o, w in straps.parts:
        kit.add(o, w)
    if lod < 2:
        for path, outs in made:
            p0, o0 = path[0], outs[0]
            tng = (path[1] - path[0]).normalized()
            x = tng.cross(o0).normalized()
            m = Matrix(((x.x, -o0.x, tng.x, p0.x), (x.y, -o0.y, tng.y, p0.y), (x.z, -o0.z, tng.z, p0.z),
                        (0, 0, 0, 1)))
            tail = builder("StrapTail")
            tail.box((-0.024, -0.016, -0.012), (0.024, -0.004, 0.004), "polymer")
            tail.box((-0.0125, -0.009, -0.05), (0.0125, -0.006, -0.01), "ranger_web")
            ob = tail.build()
            place(ob, m)
            shade(ob)
            kit.add(ob, "Chest")


# ------------------------------------------------------------------------------------------------- whole pieces

def build(lod: int, tree, torso: fit.Torso, hips: fit.Torso) -> tuple:
    """Every piece at level `lod`, and the pistol's seat in the holster."""
    kit = Kit("Kit", lod)
    front = front_carrier(kit, lod)
    back = back_carrier(kit, lod, False)
    sheets = cummerbund(kit, torso, lod, front, back)
    shoulder_straps(kit, tree, lod)
    front_pouches(kit, front, lod)
    side_pouch(kit, sheets, lod)
    bs = belt(kit, hips, lod)
    seat = belt_gear(kit, bs, lod)
    pk = Kit("Kit_Pack", lod)
    pack(pk, tree, lod)
    out = {"Kit": kit, "Kit_Pack": pk}
    if lod < 2:
        rd = Kit("Kit_Radio", lod)
        radio(rd, sheets, lod)
        out["Kit_Radio"] = rd
    return out, seat


# ------------------------------------------------------------------------------------------- skin, paint, export

BUDGET = {  # triangles per piece and level (the figure's gear share: 14,000 / 4,500 / 1,500, BL10-BL12 split)
    "Kit": (10550, 3480, 1100),
    "Kit_Pack": (2680, 780, 400),
    "Kit_Radio": (770, 240),
}
LOD_SUFFIX = ("", "_LOD1", "_LOD2")


def paint(ob: bpy.types.Object) -> None:
    """Each face's UVs on its swatch's column, v rising with height through the part (the soft gradient)."""
    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    zs = [v.co.z for v in me.vertices]
    z0, z1 = min(zs), max(zs)
    span = max(z1 - z0, 1e-4)
    for p in me.polygons:
        name = me.materials[p.material_index].name
        col = SWATCHES[name][1]
        u = (col + 0.5) / COLUMNS
        for li in p.loop_indices:
            z = me.vertices[me.loops[li].vertex_index].co.z
            uv[li].uv = (u, 0.06 + 0.88 * (z - z0) / span)


def skin_groups(ob: bpy.types.Object, weights) -> None:
    for v in ob.data.vertices:
        w = {weights: 1.0} if isinstance(weights, str) else weights(v.co)
        for bone, x in w.items():
            if x <= 0.0:
                continue
            g = ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone)
            g.add([v.index], x, "REPLACE")


def finish_piece(kit: Kit) -> bpy.types.Object:
    """Paints and skins every part, then joins them into the piece's object, named as in the figure."""
    for ob, weights in kit.parts:
        if os.environ.get("GEAR_TRIS"):
            print("  %-8s L%d %-22s %5d" % (kit.name, kit.lod, ob.name, hs.tris(ob)))
        paint(ob)
        skin_groups(ob, weights)
    ob = join(kit.name + LOD_SUFFIX[kit.lod], [o for o, _ in kit.parts])
    return ob


def fit_budget(ob: bpy.types.Object, budget: int) -> None:
    """Collapses the piece down to its budget if the build ran over (never at LOD0: the build must fit)."""
    n = hs.tris(ob)
    if n <= budget:
        return
    if not ob.name.endswith(("_LOD1", "_LOD2")):
        raise SystemExit("%s: %d triangles, over its %d: trim the build, LOD0 is never decimated" % (ob.name, n, budget))
    print("%s over budget: %d of %d triangles, decimated" % (ob.name, n, budget))
    mod = ob.modifiers.new("decimate", "DECIMATE")
    mod.ratio = budget / n * 0.98
    mod.use_collapse_triangulate = True
    hs.apply_modifiers(ob)


def _srgb(c: float) -> float:
    return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def _lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def png(width: int, height: int, rows: list) -> bytes:
    """An 8-bit RGB PNG from rows of (r, g, b) byte tuples, top row first."""
    import zlib
    raw = b"".join(b"\0" + bytes(c for px in row for c in px) for row in rows)

    def chunk(kind: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))
    head = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", head) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def textures() -> dict:
    """PNG bytes of each family's colour strip (sRGB, each column a swatch, lighter towards the top) and the Gear
    ORM strip (occlusion 1, roughness, metal)."""
    out = {}
    cw = TEX_W // COLUMNS
    for fam in ("Gear", "TeamGear"):
        col_rows, orm_rows = [], []
        for y in range(TEX_H):
            # Row 0 is the image's top: glTF v 0, the top of each part.
            k = GRADIENT[1] - (GRADIENT[1] - GRADIENT[0]) * y / (TEX_H - 1)
            crow, orow = [], []
            for x in range(TEX_W):
                c = x // cw
                hit = [v for v in SWATCHES.values() if v[0] == fam and v[1] == c]
                if hit:
                    _f, _c, rgb, rough, metal = hit[0]
                    lin = [_lin(((rgb >> s) & 255) / 255.0) * k for s in (16, 8, 0)]
                    crow.append(tuple(int(round(_srgb(min(1.0, v)) * 255)) for v in lin))
                    orow.append((255, int(round(rough * 255)), int(round(metal * 255))))
                else:
                    crow.append((128, 128, 128))
                    orow.append((255, 230, 0))
            col_rows.append(crow)
            orm_rows.append(orow)
        out[(fam, "col")] = png(TEX_W, TEX_H, col_rows)
        if fam == "Gear":
            out[(fam, "orm")] = png(TEX_W, TEX_H, orm_rows)
    return out


def extract(ob: bpy.types.Object, max_index_family: dict = None) -> list:
    """The object's triangles as glTF primitives, one per material family: positions, normals and UVs per corner
    (shared where equal), its four strongest bones per vertex."""
    me = ob.data
    me.calc_loop_triangles()
    normals = me.corner_normals
    uv = me.uv_layers.active.data
    groups = {g.index: g.name for g in ob.vertex_groups}
    vw = []
    for v in me.vertices:
        ws = sorted(((g.weight, groups[g.group]) for g in v.groups if g.weight > 1e-4), reverse=True)[:4]
        total = sum(w for w, _ in ws) or 1.0
        ws = [(w / total, b) for w, b in ws]
        while len(ws) < 4:
            ws.append((0.0, ws[0][1] if ws else "Chest"))
        vw.append(ws)
    prims = {}
    for tri in me.loop_triangles:
        fam = SWATCHES[me.materials[tri.material_index].name][0]
        p = prims.setdefault(fam, {"material": fam, "positions": [], "normals": [], "uvs": [], "joints": [],
                                   "weights": [], "indices": [], "_key": {}})
        for li in tri.loops:
            vi = me.loops[li].vertex_index
            co = me.vertices[vi].co
            n = normals[li].vector
            t = uv[li].uv
            key = (vi, round(n.x, 4), round(n.y, 4), round(n.z, 4), round(t.x, 5), round(t.y, 5))
            idx = p["_key"].get(key)
            if idx is None:
                idx = len(p["positions"])
                p["_key"][key] = idx
                # Blender (x, y, z) with the figure facing -Y is glTF (x, z, -y).
                p["positions"].append((co.x, co.z, -co.y))
                p["normals"].append((n.x, n.z, -n.y))
                p["uvs"].append((t.x, 1.0 - t.y))
                p["joints"].append(tuple(b for _, b in vw[vi]))
                p["weights"].append(tuple(w for w, _ in vw[vi]))
            p["indices"].append(idx)
    out = []
    for fam in ("TeamGear", "Gear"):
        if fam in prims:
            prims[fam].pop("_key")
            out.append(prims[fam])
    return out


def load_figure() -> tuple:
    """Imports the figure at rest; returns (armature, body object)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=HUMAN)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    return arm, bpy.data.objects["Body"]


def build_all(arm, body) -> tuple:
    """Every piece at every level: {node name: object}, skinned to `arm`; and the pistol's seat in the holster."""
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.name.startswith("Kit"):
            bpy.data.objects.remove(o)
    tree = fit.body_tree(body)
    torso = fit.Torso(tree, 0.95, 1.50)
    hips = fit.Torso(tree, 0.88, 1.04, outside=0.28)
    measure_insets(tree)
    swatch_materials()
    out = {}
    for lod in range(3):
        kits, seat = build(lod, tree, torso, hips)
        for name, kit in kits.items():
            ob = finish_piece(kit)
            fit_budget(ob, BUDGET[name][lod])
            mod = ob.modifiers.new("skin", "ARMATURE")
            mod.object = arm
            out[ob.name] = ob
        if lod == 0:
            seat0 = seat
    return out, seat0


def main() -> None:
    import splice
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    arm, body = load_figure()
    pieces, seat = build_all(arm, body)
    meshes = {}
    for name, ob in pieces.items():
        meshes[name] = extract(ob)
    tex = textures()
    mats = [
        {"name": "Gear", "col": tex[("Gear", "col")], "col_name": "gear_col", "orm": tex[("Gear", "orm")],
         "orm_name": "gear_orm"},
        {"name": "TeamGear", "col": tex[("TeamGear", "col")], "col_name": "teamgear_col", "metallic": 0.0,
         "roughness": SWATCHES["team"][3]},
    ]
    if "--no-splice" not in args:
        report = splice.splice(HUMAN, HUMAN, meshes, mats, sibling="Kit")
        write_seat(HUMAN, seat)
        for name in sorted(report):
            print("%-16s %6d triangles" % (name, report[name]))


def write_seat(path: str, seat: Matrix) -> None:
    """Writes the pistol's `seat` (belt_gear's) into the glb at `path` as the empty PISTOL_SEAT_NODE at the scene's root
    (replacing one there): its axes turned to the replica's (x out from the hip, y forward, z up) and to glTF's
    (x, z, -y)."""
    import splice
    gltf, binary = splice.read(path)
    belt = seat.to_3x3().normalized()

    def gl(v: Vector) -> Vector:
        return Vector((v.x, v.z, -v.y))
    axes = Matrix((gl(-belt.col[1]), gl(belt.col[0]), gl(belt.col[2]))).transposed()
    q = axes.to_quaternion()
    at = gl(seat.translation)
    node = {"name": PISTOL_SEAT_NODE, "translation": [round(c, 6) for c in at],
            "rotation": [round(q.x, 6), round(q.y, 6), round(q.z, 6), round(q.w, 6)]}
    names = [n.get("name") for n in gltf["nodes"]]
    if PISTOL_SEAT_NODE in names:
        gltf["nodes"][names.index(PISTOL_SEAT_NODE)] = node
    else:
        gltf["nodes"].append(node)
        gltf["scenes"][gltf.get("scene", 0)]["nodes"].append(len(gltf["nodes"]) - 1)
    splice.write(path, gltf, binary)


if __name__ == "__main__":
    main()
