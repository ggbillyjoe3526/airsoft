"""The Range's skyline buildings (Dev 3 map models): the shed, the jib crane, the mast, the plane fuselage, the silo,
the watch tower and the water tower, after the owner's photos (art/references/maps/william-2026-11-09/
skyline_buildings/<kind>/). Far scenery out of reach: simple shapes and flat colours, no textures. The game joins every
piece it shows into the skyline's one mesh (SkylineView), each model stretched to fill its piece's box, so a model is
built at the size of its kind's first piece in data/maps/range.json and its proportions carry over.

Each model is one vertex-coloured mesh (vertex_paint.py): its BODY faces take the piece's own colour (the map file's,
or SkylineConfig's for the kind) times their shade; its LAMP faces (the mast's floodlights) glow at night; the rest
keep their colour. Every colour stays off the teams' hues (tests/unit/test_skyline.gd).

Godot space: +Y up, the model's long side along X, its front (the side that faces the field: the shed's doors, the
crane's jib, the mast's antennas and lamps, the tower's stairs) toward +Z. Blender's +Z is up and Godot's +Z is
Blender's -Y; every helper here takes Godot coordinates.

Run: python3 tools/blender/maps/skyline.py [kind ...]   (pip install bpy==5.2.3)
Writes assets/models/skyline/<kind>.glb; then `godot --headless --path . --import`.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vertex_paint as vp  # noqa: E402
import hardsurface as hs  # noqa: E402  (vertex_paint puts replicas/ on the path)
from mathutils import Vector  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "models", "skyline")

# Triangle budgets: the plan's skyline is 20k in all; these seven kinds (the shed in three sizes) stand 24 pieces and
# six silo drums on the Range, the containers, chimneys, power lines and hills the rest.
BUDGETS = {"shed": 500, "shed_long": 660, "shed_deep": 600, "crane": 800, "mast": 500, "fuselage": 700, "silo": 650,
           "watch_tower": 750, "water_tower": 900}

# Shared colours (sRGB). A BODY entry's value is its shade of the piece's colour.
DARK_TRIM = 0x2E3234
CONCRETE = 0x9C9A93
GALV = 0xA3A8AC
GLASS = 0x33363A


class Model:
    """A Builder taking Godot coordinates, with a few shapes the skyline needs."""

    def __init__(self, name: str, palette: dict):
        self.palette = palette
        vp.materials(palette)
        self.b = hs.Builder(name, [])

    @staticmethod
    def g(p) -> Vector:
        return Vector((p[0], -p[2], p[1]))

    def face(self, pts: list, mat: str, out=None) -> None:
        """One flat face through Godot points, facing the side they turn anticlockwise toward, or with `out` (a
        direction) turned to face that way."""
        if out is not None:
            a, b, c = (Vector(p) for p in pts[:3])
            if (b - a).cross(c - a).dot(Vector(out)) < 0.0:
                pts = list(reversed(pts))
        f = self.b.bm.faces.new([self.b.bm.verts.new(self.g(p)) for p in pts])
        f.material_index = self.b.mat(mat)

    def box(self, lo, hi, mat: str) -> None:
        x0, y0, z0 = lo
        x1, y1, z1 = hi
        self.b.box((x0, -z1, y0), (x1, -z0, y1), mat)

    def tube(self, p0, p1, r0: float, r1: float, sides: int, mat: str, caps=(False, False), turn: float = 0.0):
        """A section of `sides` swept straight from `p0` to `p1`, radius r0 to r1 (a beam with 4 sides)."""
        a, c = self.g(p0), self.g(p1)
        axis = (c - a).normalized()
        ref = Vector((0.0, 0.0, 1.0)) if abs(axis.z) < 0.9 else Vector((1.0, 0.0, 0.0))
        u = axis.cross(ref).normalized()
        v = axis.cross(u).normalized()
        rings = []
        for centre, r in ((a, r0), (c, r1)):
            ring = []
            for i in range(sides):
                t = turn + 2.0 * math.pi * i / sides + (math.pi / sides if sides == 4 else 0.0)
                ring.append(centre + (u * math.cos(t) + v * math.sin(t)) * r)
            rings.append(ring)
        faces = self.b.loft(rings, mat, cap0=caps[0], cap1=caps[1])
        vp.orient_loft(faces, rings, caps[0], caps[1])

    def rings(self, rings: list, mat: str, cap0: bool = False, cap1: bool = False, out=None, inward=False) -> None:
        """Faces between rings of Godot points, facing away from the rings' middle line (toward it if `inward`), or
        toward `out` (a Godot direction) on a flat band."""
        pts = [[tuple(self.g(p)) for p in ring] for ring in rings]
        faces = self.b.loft(pts, mat, cap0=cap0, cap1=cap1)
        vp.orient_loft(faces, pts, cap0, cap1, self.g(out) if out is not None else None)
        if inward:
            for f in faces:
                f.normal_flip()

    def lathe(self, profile: list, mat: str, sides: int, centre=(0.0, 0.0, 0.0)) -> None:
        """A profile of (height, radius) turned about the vertical through `centre` (Godot)."""
        cx, cy, cz = centre
        vp.lathe(self.b, [(h + cy, r) for h, r in profile], mat, sides, (cx, -cz, 0.0), "z", cap=False)

    def build(self) -> hs.bpy.types.Object:
        ob = self.b.build()
        vp.bake(ob, self.palette)
        return ob


# ------------------------------------------------------------------------------------------------------------- shed

# A shed's sizes (length, depth, eaves), m: the game stands each shed piece the one nearest its proportions
# (SkylineConfig.variants), so its doors, windows and sheets keep their size instead of stretching (the Range's sheds
# run from 20 x 12 x 5 to 54 x 22 x 10 since the owner had them lowered, 2026-11-09).
SHEDS = {"shed": (26.0, 14.0, 6.0), "shed_long": (50.0, 22.0, 9.0), "shed_deep": (40.0, 26.0, 8.0)}


def shed(name: str = "shed") -> Model:
    """A steel-clad portal-frame shed (photos: dark green box-profile cladding, darker trims, a shallow gabled roof
    with rooflights, a concrete plinth, a roller shutter and a door in the gable end, tall windows down the side), at
    one of SHEDS' sizes; its ridge SkylineConfig.roof_rise of its depth over the eaves. Sheets, doors and windows keep
    their real sizes whatever the shed's."""
    m = Model(name, {
        "clad": (1.0, vp.BODY), "clad_dark": (0.82, vp.BODY),
        "roof": (0x5E655F, vp.FIXED), "rooflight": (0xC5CCC4, vp.FIXED), "trim": (DARK_TRIM, vp.FIXED),
        "plinth": (CONCRETE, vp.FIXED), "shutter": (0x4A4F55, vp.FIXED), "shutter_dark": (0x3C4046, vp.FIXED),
        "door": (0xB4B8B4, vp.FIXED), "glass": (GLASS, vp.FIXED), "frame": (0x8E9396, vp.FIXED),
    })
    L, D, H = SHEDS[name]
    R = 0.15 * D
    hl, hd = L * 0.5 - 0.3, D * 0.5 - 0.3   # the walls stand inside the roof's overhang
    plinth = 0.45

    def strips(x0, x1, z, n, top, normal_z):
        """A wall across x at depth z in vertical sheets alternating shade, each `top(x)` tall."""
        for i in range(n):
            a = x0 + (x1 - x0) * i / n
            c = x0 + (x1 - x0) * (i + 1) / n
            pts = [(a, plinth, z), (c, plinth, z), (c, top(c), z), (a, top(a), z)]
            if normal_z < 0:
                pts.reverse()
            m.face(pts, "clad" if i % 2 == 0 else "clad_dark")

    def strips_x(z0, z1, x, n, top, normal_x):
        for i in range(n):
            a = z0 + (z1 - z0) * i / n
            c = z0 + (z1 - z0) * (i + 1) / n
            pts = [(x, plinth, a), (x, plinth, c), (x, top(c), c), (x, top(a), a)]
            if normal_x > 0:
                pts.reverse()
            m.face(pts, "clad" if i % 2 == 0 else "clad_dark")

    def eaves(_x):
        return H

    def gable(z):
        return H + R * (1.0 - abs(z) / (D * 0.5))

    # long sides (front +Z with windows and a door, back plain), gable ends (+X with the shutter and door)
    n = round(L / 1.45)
    strips(-hl, hl, hd, n, eaves, 1)
    strips(-hl, hl, -hd, n, eaves, -1)
    # the gables' sheets: split at the ridge so every face is flat
    g = max(3, round(hd / 1.4))
    strips_x(-hd, 0.0, hl, g, gable, 1)
    strips_x(0.0, hd, hl, g, gable, 1)
    strips_x(-hd, 0.0, -hl, g, gable, -1)
    strips_x(0.0, hd, -hl, g, gable, -1)
    m.box((-hl - 0.05, 0.0, -hd - 0.05), (hl + 0.05, plinth, hd + 0.05), "plinth")
    # the roof: two slopes to the overhang, rooflight strips, the ridge cap
    ov = 0.3
    for s in (-1.0, 1.0):
        z_eave = s * (D * 0.5)
        y_eave = H + R * (1.0 - (D * 0.5) / (D * 0.5)) - 0.05
        lo = [(-L * 0.5, y_eave, z_eave), (L * 0.5, y_eave, z_eave), (L * 0.5, H + R, 0.0), (-L * 0.5, H + R, 0.0)]
        if s < 0:
            lo.reverse()
        m.face(lo, "roof")
        t = 0.12  # the roof sheet's edge
        edge = [(-L * 0.5, y_eave - t, z_eave), (L * 0.5, y_eave - t, z_eave), (L * 0.5, y_eave, z_eave),
                (-L * 0.5, y_eave, z_eave)]
        if s < 0:
            edge.reverse()
        m.face(edge, "trim")
        # rooflights: three pale panels a slope, a hair proud
        lights = max(3, round(L / 9.0))
        for k in range(lights):
            x = -L * 0.5 + L * (k + 0.5) / lights
            w = 1.1
            f0, f1 = 0.25, 0.75
            pts = []
            for xx, f in ((x - w, f0), (x + w, f0), (x + w, f1), (x - w, f1)):
                zz = z_eave * (1.0 - f)
                yy = y_eave + (H + R - y_eave) * f + 0.04
                pts.append((xx, yy, zz))
            if s < 0:
                pts.reverse()
            m.face(pts, "rooflight")
        # the gutter along the eaves
        m.box((-L * 0.5, H - 0.35, s * hd - 0.18 if s > 0 else -hd - 0.12),
              (L * 0.5, H - 0.05, hd + 0.12 if s > 0 else -hd + 0.18), "trim")
    # under the overhang at each gable, the roof's barge boards
    for x in (-L * 0.5, L * 0.5):
        for s in (-1.0, 1.0):
            m.tube((x, H - 0.05, s * D * 0.5), (x, H + R + 0.02, 0.0), 0.12, 0.12, 4, "trim")
    # corner flashings and downpipes
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            m.box((sx * hl - 0.12, plinth, sz * hd - 0.12), (sx * hl + 0.12, H, sz * hd + 0.12), "trim")
            m.tube((sx * (hl - 0.6), 0.0, sz * (hd + 0.1)), (sx * (hl - 0.6), H - 0.2, sz * (hd + 0.1)), 0.08,
                   0.08, 4, "trim")
    # the gable end facing out (+X): a roller shutter in its box and guides, a door and its frame
    gx = hl + 0.03
    sh = min(H - 1.7, 5.0)
    sw = sh * 1.07
    sz = -D * 0.07           # the shutter's middle along the gable
    m.box((gx - 0.03, plinth, -sw * 0.5 + sz), (gx + 0.05, sh, sw * 0.5 + sz), "shutter")
    for k in range(6):  # slat bands
        y0 = plinth + (sh - plinth) * k / 6.0
        m.face([(gx + 0.06, y0, sw * 0.5 + sz), (gx + 0.06, y0, -sw * 0.5 + sz),
                (gx + 0.06, y0 + 0.35, -sw * 0.5 + sz), (gx + 0.06, y0 + 0.35, sw * 0.5 + sz)], "shutter_dark")
    m.box((gx, sh, -sw * 0.5 + sz - 0.25), (gx + 0.45, sh + 0.7, sw * 0.5 + sz + 0.25), "trim")
    for z in (-sw * 0.5 + sz, sw * 0.5 + sz):
        m.box((gx, plinth, z - 0.15), (gx + 0.12, sh, z + 0.15), "trim")
    m.box((gx - 0.02, plinth, hd - 3.5), (gx + 0.06, plinth + 2.2, hd - 2.4), "door")
    m.box((gx, plinth, hd - 3.65), (gx + 0.1, plinth + 2.35, hd - 3.5), "trim")
    m.box((gx, plinth, hd - 2.4), (gx + 0.1, plinth + 2.35, hd - 2.25), "trim")
    m.box((gx, plinth + 2.2, hd - 3.65), (gx + 0.1, plinth + 2.35, hd - 2.25), "trim")
    # the long side facing out (+Z): a row of tall windows (photos 103332) and a door
    fz = hd + 0.03
    dx = hl - 6.7
    x = -hl + 4.0
    while x + 0.5 < dx - 1.5:
        m.box((x - 0.5, 2.4, fz - 0.03), (x + 0.5, 4.2, fz + 0.04), "frame")
        m.face([(x - 0.42, 2.52, fz + 0.05), (x + 0.42, 2.52, fz + 0.05), (x + 0.42, 4.08, fz + 0.05),
                (x - 0.42, 4.08, fz + 0.05)], "glass", (0, 0, 1))
        x += 3.2 if L < 40.0 else 4.0
    m.box((dx, plinth, fz - 0.02), (dx + 1.1, plinth + 2.2, fz + 0.06), "door")
    m.box((dx - 0.15, plinth + 2.2, fz), (dx + 1.25, plinth + 2.35, fz + 0.1), "trim")
    return m


# ------------------------------------------------------------------------------------------------------------ crane

def crane() -> Model:
    """A pillar jib crane (photos: bright yellow; a pillar on a flared foot with gussets, a slewing head and knee
    brace, a box jib, a chain hoist on its trolley with a hook and a pendant, festoon cable loops on a rail along
    the top, an end stop). 24 m along X (the jib reaching toward +X), 18 m tall."""
    m = Model("crane", {
        "steel": (1.0, vp.BODY), "steel_shade": (0.8, vp.BODY),
        "pad": (CONCRETE, vp.FIXED), "hoist": (0x4B5157, vp.FIXED), "chain": (0x6A6E72, vp.FIXED),
        "hook": (0x8A3A62, vp.FIXED), "cable": (0x232527, vp.FIXED), "rail": (GALV, vp.FIXED),
        "bolt": (0x55595D, vp.FIXED),
    })
    L, H = 24.0, 18.0
    px = -L * 0.5 + 1.6           # the pillar's axis
    beam_top = H - 0.6
    beam_h = 1.3
    beam_w = 0.9
    pillar_top = H - beam_h - 0.5
    # the foundation pad and the foot plate with its gussets
    m.box((px - 2.4, 0.0, -2.4), (px + 2.4, 0.3, 2.4), "pad")
    m.lathe([(0.3, 1.9), (0.5, 1.9), (0.5, 0.95), (2.4, 0.75)], "steel_shade", 12, (px, 0.0, 0.0))
    for k in range(8):
        a = 2.0 * math.pi * k / 8
        c, s = math.cos(a), math.sin(a)
        m.face([(px + c * 0.8, 0.5, s * 0.8), (px + c * 1.85, 0.5, s * 1.85), (px + c * 0.75, 2.2, s * 0.75)],
               "steel_shade")
        m.face([(px + c * 0.75, 2.2, s * 0.75), (px + c * 1.85, 0.5, s * 1.85), (px + c * 0.8, 0.5, s * 0.8)],
               "steel_shade")
        m.lathe([(0.5, 0.12), (0.75, 0.08)], "bolt", 4, (px + c * 1.55, 0.0, s * 1.55))
    # the pillar: round, slightly tapered, and its slewing head: a ring and a bracket box
    m.lathe([(2.4, 0.75), (pillar_top - 1.0, 0.68), (pillar_top - 0.9, 0.8), (pillar_top - 0.5, 0.8),
             (pillar_top - 0.4, 0.68), (pillar_top, 0.68)], "steel", 14, (px, 0.0, 0.0))
    m.box((px - 1.1, pillar_top, -beam_w * 0.6), (px + 1.3, beam_top - beam_h, beam_w * 0.6), "steel_shade")
    # a door plate and a red isolator on the pillar's front
    m.box((px - 0.3, 3.0, 0.66), (px + 0.3, 4.1, 0.8), "steel_shade")
    m.box((px - 0.2, 5.0, 0.66), (px + 0.2, 5.5, 0.85), "hook")
    # the jib: a box beam from just behind the pillar to the tip, a flange lip either side at the bottom
    x0, x1 = px - 1.3, L * 0.5
    y0 = beam_top - beam_h
    m.box((x0, y0 + 0.12, -beam_w * 0.5), (x1, beam_top, beam_w * 0.5), "steel")
    m.box((x0, y0, -beam_w * 0.75), (x1, y0 + 0.12, beam_w * 0.75), "steel_shade")
    m.box((x1 - 0.2, y0 - 0.4, -beam_w * 0.75), (x1, beam_top, beam_w * 0.75), "steel_shade")  # the end stop
    # the knee brace from the pillar to the jib's underside, its side plates
    for s in (-1.0, 1.0):
        m.face([(px + 0.6, pillar_top - 3.2, s * 0.35), (px + 0.9, pillar_top, s * 0.35),
                (px + 5.0, y0, s * 0.35)], "steel_shade", (0, 0, s))
    m.tube((px + 0.65, pillar_top - 3.2, 0.0), (px + 5.2, y0 + 0.05, 0.0), 0.32, 0.32, 4, "steel")
    # the festoon rail on posts along the top and its cable sagging in loops
    rail_y = beam_top + 0.55
    m.tube((x0 + 0.3, rail_y, 0.0), (x1 - 0.2, rail_y, 0.0), 0.05, 0.05, 4, "rail")
    for k in range(5):
        x = x0 + 0.3 + (x1 - x0 - 0.5) * k / 4.0
        m.tube((x, beam_top, 0.0), (x, rail_y, 0.0), 0.04, 0.04, 4, "rail")
    loops = 9
    for k in range(loops):
        xa = x0 + 0.3 + (x1 - 2.2 - x0) * k / loops
        xb = x0 + 0.3 + (x1 - 2.2 - x0) * (k + 1) / loops
        pts = [(xa + (xb - xa) * f, rail_y - 0.9 * math.sin(math.pi * f)) for f in (0.0, 0.2, 0.5, 0.8, 1.0)]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            m.tube((ax, ay, 0.12), (bx, by, 0.12), 0.05, 0.05, 3, "cable")
    # the hoist on its trolley near the tip, the chain, hook and pendant
    hx = x1 - 2.6
    m.box((hx - 0.9, y0 - 0.25, -beam_w * 0.8), (hx + 0.9, y0, beam_w * 0.8), "hoist")
    m.box((hx - 0.75, y0 - 1.6, -0.6), (hx + 0.55, y0 - 0.25, 0.6), "hoist")
    m.tube((hx + 0.55, y0 - 1.1, 0.0), (hx + 0.95, y0 - 1.1, 0.0), 0.42, 0.42, 6, "hoist", caps=(False, True))
    hook_y = 7.0
    m.tube((hx, y0 - 1.6, 0.0), (hx, hook_y + 0.6, 0.0), 0.06, 0.06, 3, "chain")
    m.box((hx - 0.3, hook_y, -0.18), (hx + 0.3, hook_y + 0.6, 0.18), "hook")
    m.tube((hx, hook_y, 0.0), (hx + 0.25, hook_y - 0.6, 0.0), 0.1, 0.08, 4, "hook")
    m.tube((hx + 0.25, hook_y - 0.6, 0.0), (hx - 0.15, hook_y - 0.8, 0.0), 0.08, 0.08, 4, "hook")
    m.tube((hx - 0.4, y0 - 1.6, 0.0), (hx - 0.4, 2.2, 0.0), 0.03, 0.03, 3, "cable")
    m.box((hx - 0.55, 1.6, -0.12), (hx - 0.25, 2.3, 0.12), "steel")
    return m


# ------------------------------------------------------------------------------------------------------------- mast

def mast() -> Model:
    """A telecom monopole with the field's floodlights (photos: a pale tapered pole, tall antenna panels on a head
    frame, radio units and cable runs, a lightning rod; the floodlight bar the Range's yard is lit by stays on it,
    under the antennas, its glass glowing at night). 2.4 m across (X) x 0.5 m deep x 14 m tall, the antennas and
    lamps facing +Z."""
    m = Model("mast", {
        "pole": (1.0, vp.BODY), "pole_shade": (0.86, vp.BODY),
        "antenna": (0xE2E4E0, vp.FIXED), "antenna_shade": (0xC2C6C4, vp.FIXED), "unit": (0x8E9498, vp.FIXED),
        "frame": (0x70767B, vp.FIXED), "plinth": (CONCRETE, vp.FIXED), "cable": (0x2E3134, vp.FIXED),
        "housing": (0x3A3E46, vp.FIXED), "glass": (0xD6D6D0, vp.LAMP),
    })
    W, D, H = 2.4, 0.5, 14.0
    # the plinth and flange
    m.box((-0.25, 0.0, -0.25), (0.25, 0.3, 0.25), "plinth")
    m.lathe([(0.3, 0.2), (0.38, 0.2), (0.38, 0.16)], "pole_shade", 8)
    # the pole, tapering, with a joint collar
    m.lathe([(0.38, 0.16), (6.5, 0.14), (6.6, 0.155), (6.75, 0.155), (6.85, 0.13), (H - 0.6, 0.1)], "pole", 8)
    # the cable tray up the back
    m.box((-0.05, 0.4, -0.22), (0.05, 10.6, -0.15), "cable")
    # the floodlight bar at 10.4 m: a cross arm and four lamps facing +Z, glass a hair proud
    ly = 10.4
    m.box((-W * 0.5, ly - 0.08, -0.08), (W * 0.5, ly + 0.08, 0.08), "frame")
    for k in range(4):
        x = -W * 0.5 + W * (k + 0.5) / 4.0
        m.box((x - 0.24, ly - 0.2, 0.0), (x + 0.24, ly + 0.2, 0.2), "housing")
        m.face([(x - 0.2, ly - 0.16, 0.22), (x + 0.2, ly - 0.16, 0.22), (x + 0.2, ly + 0.16, 0.22),
                (x - 0.2, ly + 0.16, 0.22)], "glass", (0, 0, 1))
    # radio units clamped to the pole under the head
    for x in (-0.3, 0.3):
        m.box((x - 0.14, 11.2, 0.06), (x + 0.14, 11.75, 0.24), "unit")
    # the head frame: two cross arms and three tall panels across the front, cable loops behind
    for y in (11.95, 13.25):
        m.box((-W * 0.5 + 0.1, y - 0.05, -0.05), (W * 0.5 - 0.1, y + 0.05, 0.05), "frame")
    for k, x in enumerate((-0.85, 0.0, 0.85)):
        m.box((x - 0.17, 11.7, 0.07), (x + 0.17, 13.75, 0.2), "antenna")
        m.box((x - 0.17, 11.62, 0.07), (x + 0.17, 11.7, 0.2), "antenna_shade")
        m.box((x - 0.04, 11.95, 0.03), (x + 0.04, 13.25, 0.07), "frame")
        m.tube((x, 11.7, 0.1), (x * 0.3, 11.2, -0.05), 0.025, 0.025, 3, "cable")
    # side panels turned a little, like the photos' three-sector heads
    for s in (-1.0, 1.0):
        x = s * 1.1
        m.face([(x, 11.8, 0.22), (x, 11.8, -0.2), (x, 13.6, -0.2), (x, 13.6, 0.22)], "antenna_shade", (s, 0, 0))
        xi = x - s * 0.03  # its back, seen across the head from the other side
        m.face([(xi, 11.8, 0.22), (xi, 11.8, -0.2), (xi, 13.6, -0.2), (xi, 13.6, 0.22)], "antenna_shade", (-s, 0, 0))
    # two microwave dishes on short arms below the head, facing out to the sides
    for s in (-1.0, 1.0):
        m.tube((0.0, 10.95, -0.05), (s * 0.55, 10.95, -0.05), 0.03, 0.03, 3, "frame")
        cx = s * 0.6
        vp.lathe(m.b, [(0.0, 0.2), (0.1 * s, 0.0)], "antenna", 8, (cx, 0.05, 10.95), "x", cap=False)
        # its face, turned away from the cone behind it (toward the mast)
        vp.lathe(m.b, [(0.0, 0.0) if s > 0 else (0.0, 0.2), (0.0, 0.2) if s > 0 else (0.0, 0.0)], "antenna_shade",
                 8, (cx, 0.05, 10.95), "x", cap=False)
    # the top: a cap and the lightning rod
    m.lathe([(H - 0.6, 0.1), (H - 0.5, 0.12), (H - 0.42, 0.06)], "pole_shade", 8)
    m.tube((0.0, H - 0.42, 0.0), (0.0, H, 0.0), 0.025, 0.012, 3, "frame")
    return m


# --------------------------------------------------------------------------------------------------------- fuselage

def fuselage() -> Model:
    """A dumped airliner fuselage (photos: off-white, weathered, a long row of small windows, cabin doors, a cockpit
    with its windows, a cheat line, wing-root fairings, the fin; it rests on railway-sleeper cribs). 24 m long (X,
    the nose toward +X), 4.4 m across, the fin's top 9 m up."""
    m = Model("fuselage", {
        "skin": (1.0, vp.BODY), "skin_grime": (0.84, vp.BODY), "belly": (0.9, vp.BODY),
        "glass": (GLASS, vp.FIXED), "stripe": (0x7A3A5C, vp.FIXED), "stripe2": (0x55585C, vp.FIXED),
        "door": (0x1E2124, vp.FIXED), "timber": (0x625A52, vp.FIXED), "fin": (0x55585C, vp.FIXED),
    })
    L, R = 24.0, 2.2
    cy = 1.0 + R           # the axis' height over the cribs
    sides = 20

    def ring(x, ry, rz, dy=0.0):
        out = []
        for i in range(sides):
            t = 2.0 * math.pi * i / sides
            out.append((x, cy + dy + ry * math.sin(t), rz * math.cos(t)))
        return out

    tail0, nose0 = -L * 0.5 + 6.0, L * 0.5 - 3.4
    stations = [
        (-L * 0.5, 0.28, 0.28, 1.25),
        (-L * 0.5 + 2.2, 0.95, 0.9, 0.75),
        (-L * 0.5 + 4.2, 1.7, 1.65, 0.3),
        (tail0, R, R, 0.0),
        (nose0, R, R, 0.0),
        (L * 0.5 - 2.0, 1.95, 1.95, -0.12),
        (L * 0.5 - 0.9, 1.4, 1.35, -0.35),
        (L * 0.5 - 0.25, 0.7, 0.65, -0.55),
    ]
    rs = [ring(x, ry, rz, dy) for x, ry, rz, dy in stations]
    m.rings(rs, "skin", cap0=True, cap1=False)
    tip = (L * 0.5, cy - 0.65, 0.0)
    last = rs[-1]
    for i in range(sides):
        j = (i + 1) % sides
        m.face([last[i], last[j], tip], "skin", (1, 0, 0))
    # grime: a few darker panels hanging off the body a hair proud
    for x0, x1, s in ((-3.0, 1.0, 1.0), (3.5, 6.0, -1.0), (-7.5, -5.0, -1.0), (5.0, 8.0, 1.0), (-1.5, 2.0, -1.0),
                      (-8.0, -6.0, 1.0)):
        z = s * (R + 0.02)
        pts = [(x0, cy - 1.5, z), (x1, cy - 1.5, z), (x1, cy - 0.3, z), (x0, cy - 0.3, z)]
        m.face(pts, "skin_grime", (0, 0, s))
    # the cheat line and the window row along both sides, the doors
    for s in (-1.0, 1.0):
        z = s * (R + 0.015)
        def band(x0, x1, y0, y1, mat, zz=z):
            pts = [(x0, y0, zz), (x1, y0, zz), (x1, y1, zz), (x0, y1, zz)]
            m.face(pts, mat, (0, 0, s))
        band(tail0 - 0.5, nose0 + 0.6, cy - 0.55, cy - 0.3, "stripe")
        band(tail0 - 0.5, nose0 + 0.6, cy - 0.75, cy - 0.6, "stripe2")
        for k in range(21):
            x = tail0 + 0.7 + k * 0.7
            if abs(x - (nose0 - 1.6)) < 0.8 or abs(x - (tail0 + 4.0)) < 0.6:
                continue
            band(x - 0.17, x + 0.17, cy + 0.15, cy + 0.6, "glass", z + s * 0.01)
        band(nose0 - 2.1, nose0 - 1.1, cy - 0.9, cy + 1.0, "door", z + s * 0.01)
        band(tail0 + 3.6, tail0 + 4.4, cy - 0.7, cy + 0.9, "skin_grime", z + s * 0.005)
    # the cockpit's windscreen (photos 103958, 104028): six panes across the top of the nose, laid on its skin
    # between the nose's first two stations, framed by the skin left between them
    ra, rb = rs[5], rs[6]
    for i in range(2, 8):   # the facets from 36 to 144 degrees round, over the top
        j = i + 1
        u0, u1 = 0.18, 0.72
        w0, w1 = 0.1, 0.9
        corners = []
        for u, w in ((u0, w0), (u0, w1), (u1, w1), (u1, w0)):
            p_a = tuple(ra[i][k] + (ra[j][k] - ra[i][k]) * w for k in range(3))
            p_b = tuple(rb[i][k] + (rb[j][k] - rb[i][k]) * w for k in range(3))
            corners.append(tuple(p_a[k] + (p_b[k] - p_a[k]) * u for k in range(3)))
        mid = [sum(c[k] for c in corners) / 4.0 for k in range(3)]
        out = (0.25, mid[1] - (cy - 0.2), mid[2])
        lift = Vector(out).normalized() * 0.03
        m.face([(c[0] + lift.x, c[1] + lift.y, c[2] + lift.z) for c in corners], "glass", out)
    # the wing-root fairings under the middle
    for s in (-1.0, 1.0):
        m.tube((-2.5, cy - 1.5, s * 1.5), (3.0, cy - 1.5, s * 1.5), 0.6, 0.6, 5, "belly", caps=(True, True))
    # the tail cone's exhaust and the bays under the nose and the middle, open and dark
    m.tube((-L * 0.5 + 0.4, cy + 1.25, 0.0), (-L * 0.5, cy + 1.25, 0.0), 0.22, 0.22, 8, "door",
           caps=(False, True))
    for x0, x1 in ((L * 0.5 - 4.2, L * 0.5 - 2.8), (-1.5, 1.5)):
        m.face([(x0, cy - R + 0.06, -0.5), (x1, cy - R + 0.06, -0.5), (x1, cy - R + 0.06, 0.5),
                (x0, cy - R + 0.06, 0.5)], "door", (0, -1, 0))
    # the wing roots, cut off short: a stub either side over the fairings
    for s in (-1.0, 1.0):
        root = [(-2.0, 0.0), (1.8, 0.0), (1.2, 0.0), (-1.4, 0.0)]
        z0, z1 = s * 1.9, s * 2.2
        y = cy - 1.25
        m.box((-2.0, y - 0.18, min(z0, z1)), (1.8, y + 0.18, max(z0, z1)), "belly")
        del root
    # the fin, swept, from the tail cone to 9 m, and the stubs of the tailplane
    fx0, fx1 = -L * 0.5 + 0.7, -L * 0.5 + 4.6
    top = 9.0
    t = 0.14
    fin = [(fx0, cy + 0.9), (fx1, cy + 1.5), (fx0 + 2.3, top), (fx0 + 0.3, top)]
    for s in (-1.0, 1.0):
        pts = [(x, y, s * t) for x, y in fin]
        m.face(pts, "fin", (0, 0, s))
    for (xa, ya), (xb, yb) in zip(fin, fin[1:] + fin[:1]):
        mid = (sum(x for x, _ in fin) / 4.0, sum(y for _, y in fin) / 4.0)
        m.face([(xa, ya, t), (xb, yb, t), (xb, yb, -t), (xa, ya, -t)], "fin",
               ((xa + xb) * 0.5 - mid[0], (ya + yb) * 0.5 - mid[1], 0.0))
    m.box((fx0 + 1.6, cy + 0.4, -t - 0.02), (fx0 + 2.6, cy + 1.6, t + 0.02), "stripe")
    for s in (-1.0, 1.0):
        m.face([(-L * 0.5 + 1.2, cy + 0.55, s * 0.6), (-L * 0.5 + 3.2, cy + 0.55, s * 0.9),
                (-L * 0.5 + 2.6, cy + 0.6, s * 2.1), (-L * 0.5 + 1.5, cy + 0.6, s * 2.0)], "skin", (0, 1, 0))
        m.face([(-L * 0.5 + 1.2, cy + 0.5, s * 0.6), (-L * 0.5 + 3.2, cy + 0.5, s * 0.9),
                (-L * 0.5 + 2.6, cy + 0.55, s * 2.1), (-L * 0.5 + 1.5, cy + 0.55, s * 2.0)], "skin", (0, -1, 0))
    # sleeper cribs: two stacks of two layers, crossing
    for x in (-5.0, 5.0):
        for layer in range(2):
            y0 = layer * 0.5
            if layer == 0:
                for z in (-1.1, 1.1):
                    m.box((x - 1.3, y0, z - 0.13), (x + 1.3, y0 + 0.5, z + 0.13), "timber")
            else:
                for dx in (-1.0, 1.0):
                    m.box((x + dx - 0.13, y0, -1.5), (x + dx + 0.13, y0 + 0.5, 1.5), "timber")
    return m


# ------------------------------------------------------------------------------------------------------------- silo

def silo() -> Model:
    """One drum of a feed silo row (photos: a GRP drum on a conical hopper, the hopper on a galvanised leg frame
    with cross braces and a base ring, a low rounded top with its hatch, the fill pipe climbing the side and curving
    over into the top). 6 m across, 15 m tall: the drum and its top about 1.4 times its width, the hopper about half
    the drum, as in the photos (103739, 103753); the game stands one a drum along the row."""
    m = Model("silo", {
        "drum": (1.0, vp.BODY), "drum_shade": (0.88, vp.BODY), "galv": (GALV, vp.FIXED),
        "galv_dark": (0x7E8488, vp.FIXED), "hatch": (0x6F7378, vp.FIXED), "label": (0xE9E7E0, vp.FIXED),
    })
    H = 15.0
    r = 2.9                   # the drum; the fill pipe stands just outside it on a diagonal, inside the 3 m
    legs_top, cone_top, drum_top = 3.4, 6.8, 14.1
    sides = 16
    m.lathe([(legs_top - 0.1, 0.5), (cone_top - 0.25, r - 0.05), (cone_top, r)], "drum_shade", sides)
    m.lathe([(cone_top, r), (cone_top + 0.25, r + 0.05), (cone_top + 0.5, r), (drum_top, r)], "drum", sides)
    m.lathe([(drum_top, r), (drum_top + 0.3, r - 0.12), (drum_top + 0.6, r * 0.72), (H - 0.35, 0.45)],
            "drum_shade", sides)
    m.lathe([(H - 0.35, 0.45), (H - 0.05, 0.45), (H, 0.0)], "hatch", 8)
    # a pale maker's plate on the front, high up (no logos)
    m.face([(-0.6, 12.6, r + 0.03), (0.6, 12.6, r + 0.03), (0.6, 13.2, r + 0.03), (-0.6, 13.2, r + 0.03)], "label",
           (0, 0, 1))
    # the leg frame: four legs to a ring beam under the drum, braced, on a base ring
    lr = r * 0.9
    corners = [(lr * math.cos(a), lr * math.sin(a)) for a in (math.pi * 0.25 + k * math.pi * 0.5 for k in range(4))]
    for x, z in corners:
        m.tube((x, 0.0, z), (x * 1.0, cone_top - 0.1, z * 1.0), 0.13, 0.13, 4, "galv")
    for (xa, za), (xb, zb) in zip(corners, corners[1:] + corners[:1]):
        m.tube((xa, 0.35, za), (xb, 0.35, zb), 0.11, 0.11, 4, "galv_dark")
        m.tube((xa, 0.35, za), (xb, cone_top - 0.2, zb), 0.06, 0.06, 4, "galv")
        m.tube((xb, 0.35, zb), (xa, cone_top - 0.2, za), 0.06, 0.06, 4, "galv")
        m.tube((xa, cone_top - 0.2, za), (xb, cone_top - 0.2, zb), 0.09, 0.09, 4, "galv")
    m.lathe([(cone_top - 0.3, r + 0.08), (cone_top - 0.05, r + 0.08)], "galv_dark", sides)
    # the outlet under the hopper
    m.lathe([(legs_top - 0.1, 0.5), (legs_top - 0.6, 0.25), (legs_top - 1.0, 0.25)], "galv_dark", 6)
    # the fill pipe: up the front-left side and over into the dome (a gooseneck)
    a = math.radians(135.0)
    pr = r + 0.28
    px, pz = pr * math.cos(a), pr * math.sin(a)
    m.tube((px, 0.6, pz), (px, H - 0.2, pz), 0.11, 0.11, 6, "galv")
    bend = [(1.0, H - 0.2), (0.85, H + 0.25), (0.55, H + 0.42), (0.3, H + 0.2)]
    prev = (px, H - 0.2, pz)
    for f, y in bend[1:]:
        cur = (px * f, min(y, H - 0.12), pz * f)
        m.tube(prev, cur, 0.11, 0.11, 6, "galv")
        prev = cur
    m.tube(prev, (px * 0.15, H - 0.75, pz * 0.15), 0.11, 0.11, 6, "galv")
    # pipe brackets
    for y in (4.5, 9.0, 13.0):
        m.tube((px * (r / pr), y, pz * (r / pr)), (px, y, pz), 0.05, 0.05, 4, "galv_dark")
    return m


# ------------------------------------------------------------------------------------------------------ watch tower

def watch_tower() -> Model:
    """A steel watch tower (photos 103631, 103648: a braced four-leg frame on concrete footings, a stair up one side,
    a deck with an open cab on it: low corrugated panels round its edge, posts up to a pitched hip roof that overhangs
    the deck all round). 5.2 m square (the roof), 12.4 m tall: the cab about two thirds of the legs' height, as in the
    photos; the stair on the +Z side."""
    m = Model("watch_tower", {
        "steel": (1.0, vp.BODY), "steel_shade": (0.82, vp.BODY),
        "panel": (0xC9CBC6, vp.FIXED), "panel_shade": (0xAEB1AC, vp.FIXED),
        "roof": (0x7F8780, vp.FIXED), "roof_under": (0x5D6560, vp.FIXED), "deck": (0x7D7F7C, vp.FIXED),
        "pad": (CONCRETE, vp.FIXED),
    })
    S, H = 5.2, 12.4
    f = 1.45                       # the leg frame's half width
    d = 1.95                       # the deck's half width (the stair passes outside it)
    deck_y = 7.55
    eave_y = 10.75                 # the roof's eaves; its ridge point at H
    # footings and legs
    legs = [(sx * f, sz * f) for sx in (-1.0, 1.0) for sz in (-1.0, 1.0)]
    for x, z in legs:
        m.box((x - 0.3, 0.0, z - 0.3), (x + 0.3, 0.45, z + 0.3), "pad")
        m.tube((x, 0.45, z), (x, deck_y, z), 0.12, 0.12, 4, "steel")
    # the bays: a strut round each level and crossed braces on every side
    levels = [0.6, 2.9, 5.2, deck_y - 0.2]
    sides = [((-f, -f), (f, -f)), ((f, -f), (f, f)), ((f, f), (-f, f)), ((-f, f), (-f, -f))]
    for y in levels[1:]:
        for (xa, za), (xb, zb) in sides:
            m.tube((xa, y, za), (xb, y, zb), 0.08, 0.08, 4, "steel_shade")
    for ya, yb in zip(levels, levels[1:]):
        for (xa, za), (xb, zb) in sides:
            m.tube((xa, ya, za), (xb, yb, zb), 0.045, 0.045, 4, "steel")
            m.tube((xb, ya, zb), (xa, yb, za), 0.045, 0.045, 4, "steel")
    # the deck: a slab over the frame, joists under it
    top = deck_y + 0.2
    m.box((-d, deck_y, -d), (d, top, d), "deck")
    for x in (-f, f):
        m.box((x - 0.1, deck_y - 0.3, -d), (x + 0.1, deck_y, d), "steel_shade")
    # the cab: low corrugated panels round the deck's edge (a gap on the stair side), posts to the eaves, a beam
    # round their tops
    wall = top + 1.15
    door = (-1.7, -0.5)
    m.box((-d, top, -d), (d, wall, -d + 0.06), "panel")
    m.box((-d, top, -d), (-d + 0.06, wall, d), "panel")
    m.box((d - 0.06, top, -d), (d, wall, d), "panel")
    m.box((-d, top, d - 0.06), (door[0], wall, d), "panel")
    m.box((door[1], top, d - 0.06), (d, wall, d), "panel")
    for k in range(5):  # the corrugation's shadow lines on the outside faces
        t = -d + 2.0 * d * (k + 0.5) / 5.0
        z = -d - 0.01
        m.face([(t - 0.08, top + 0.05, z), (t + 0.08, top + 0.05, z), (t + 0.08, wall - 0.05, z),
                (t - 0.08, wall - 0.05, z)], "panel_shade", (0, 0, -1))
        for sx in (-1.0, 1.0):
            m.face([(sx * (d + 0.01), top + 0.05, t - 0.08), (sx * (d + 0.01), top + 0.05, t + 0.08),
                    (sx * (d + 0.01), wall - 0.05, t + 0.08), (sx * (d + 0.01), wall - 0.05, t - 0.08)],
                   "panel_shade", (sx, 0, 0))
    e = d - 0.05
    posts = [(-e, -e), (0.0, -e), (e, -e), (e, 0.0), (e, e), (-e, e), (-e, 0.0)]
    for x, z in posts:
        m.tube((x, top, z), (x, eave_y, z), 0.05, 0.05, 4, "steel")
    ring = [(-e, -e), (e, -e), (e, e), (-e, e)]
    for (xa, za), (xb, zb) in zip(ring, ring[1:] + ring[:1]):
        m.tube((xa, eave_y - 0.06, za), (xb, eave_y - 0.06, zb), 0.06, 0.06, 4, "steel_shade")
        m.tube((xa, wall + 0.05, za), (xb, wall + 0.05, zb), 0.035, 0.035, 4, "steel")
    # the roof: a hip over the whole square, its fascia, and its underside (seen from the ground)
    h = S * 0.5
    apex = (0.0, H, 0.0)
    rr = [(-h, eave_y, -h), (h, eave_y, -h), (h, eave_y, h), (-h, eave_y, h)]
    for a, c in zip(rr, rr[1:] + rr[:1]):
        mid = ((a[0] + c[0]) * 0.5, 0.0, (a[2] + c[2]) * 0.5)
        m.face([a, c, apex], "roof", (mid[0], 1.0, mid[2]))
        m.face([(a[0], a[1] - 0.08, a[2]), (c[0], c[1] - 0.08, c[2]), (0.0, H - 0.1, 0.0)], "roof_under", (0, -1, 0))
        m.face([(a[0], a[1] - 0.12, a[2]), (c[0], c[1] - 0.12, c[2]), c, a], "roof", mid)
    # the stair: two flights up the +Z side outside the deck, a landing between, a hand rail on the outside
    sz0, sz1 = d + 0.04, S * 0.5 - 0.02
    flights = [(0.45, -2.3, 3.6, 2.2), (3.6, 2.2, top, door[0] + 0.1)]
    for y0, xa, y1, xb in flights:
        m.face([(xa, y0, sz1), (xb, y1, sz1), (xb, y1, sz0), (xa, y0, sz0)], "deck", (0, 1, 0))
        m.face([(xa, y0 - 0.25, sz0), (xb, y1 - 0.25, sz0), (xb, y1 - 0.25, sz1), (xa, y0 - 0.25, sz1)],
               "steel_shade", (0, -1, 0))
        for z, out in ((sz1, 1), (sz0, -1)):
            m.face([(xa, y0 - 0.25, z), (xb, y1 - 0.25, z), (xb, y1, z), (xa, y0, z)], "steel_shade", (0, 0, out))
        m.tube((xa, y0 + 0.9, sz1), (xb, y1 + 0.9, sz1), 0.03, 0.03, 4, "steel")
        m.tube((xa, y0, sz1), (xa, y0 + 0.9, sz1), 0.03, 0.03, 4, "steel")
    m.box((2.2, 3.48, sz0), (2.6, 3.6, sz1), "deck")
    m.tube((2.4, 0.0, (sz0 + sz1) * 0.5), (2.4, 3.48, (sz0 + sz1) * 0.5), 0.05, 0.05, 4, "steel")
    return m


# ------------------------------------------------------------------------------------------------------ water tower

def water_tower() -> Model:
    """A water tower (photos: a drum tank with a low conical roof overhanging it and a deep rounded bowl under it, on
    four tall legs leaning in, struts and crossed rods in each bay, a balcony with a railing round the bowl's rim, a
    ladder up a leg and the tank, a riser pipe in the middle, a finial). 7 m across, 22 m tall; the legs stand about
    1.7 times the tank and bowl, as in the photos (103841)."""
    m = Model("water_tower", {
        "tank": (1.0, vp.BODY), "tank_shade": (0.86, vp.BODY), "legs": (0xA5AAAE, vp.FIXED),
        "rods": (0x8E949A, vp.FIXED), "rail": (0x7C8288, vp.FIXED), "pad": (CONCRETE, vp.FIXED),
    })
    H, R = 22.0, 2.6
    sides = 16
    bowl = 3.9                 # the bowl's depth, about three quarters of the tank's width
    bal_y = 16.6               # the balcony's floor: the bowl's rim and the drum's foot
    tank_top = bal_y + 3.5     # the drum, about two thirds of its width tall
    eave = R + 0.4             # the roof's overhang
    roof_top = H - 0.55
    # the bowl: a deep rounded bottom (half an ellipse), the drum, the low overhanging roof and the finial
    prof = [(bal_y - bowl, 0.0)]
    for k in range(1, 4):
        t = math.pi * 0.5 * k / 4
        prof.append((bal_y - bowl * math.cos(t), R * math.sin(t)))
    m.lathe(prof + [(bal_y, R)], "tank_shade", sides)
    m.lathe([(bal_y, R), (tank_top, R)], "tank", sides)
    m.lathe([(tank_top, R), (tank_top + 0.02, eave), (tank_top + 0.2, eave), (roof_top, 0.2)], "tank_shade", sides)
    m.lathe([(roof_top, 0.2), (H - 0.2, 0.08), (H, 0.0)], "rail", 6)
    # the legs: four, leaning in from a wide stance to the balcony
    foot, head = 3.4, R * 0.92
    angles = [math.pi * 0.25 + k * math.pi * 0.5 for k in range(4)]
    feet = [(foot * math.cos(a), foot * math.sin(a)) for a in angles]
    heads = [(head * math.cos(a), head * math.sin(a)) for a in angles]
    for (fx, fz), (hx, hz) in zip(feet, heads):
        m.box((fx - 0.4, 0.0, fz - 0.4), (fx + 0.4, 0.4, fz + 0.4), "pad")
        m.tube((fx, 0.4, fz), (hx, bal_y, hz), 0.2, 0.16, 6, "legs")
    # the bays: struts round each level and crossed rods
    levels = [0.4, 4.6, 8.8, 12.6]

    def at(i, y):
        t = (y - 0.4) / (bal_y - 0.4)
        return (feet[i][0] + (heads[i][0] - feet[i][0]) * t, y, feet[i][1] + (heads[i][1] - feet[i][1]) * t)

    for y in levels[1:]:
        for i in range(4):
            m.tube(at(i, y), at((i + 1) % 4, y), 0.09, 0.09, 4, "legs")
    for ya, yb in zip(levels, levels[1:]):
        for i in range(4):
            j = (i + 1) % 4
            m.tube(at(i, ya), at(j, yb), 0.035, 0.035, 3, "rods")
            m.tube(at(j, ya), at(i, yb), 0.035, 0.035, 3, "rods")
    # the riser pipe in the middle, into the bowl's bottom
    m.tube((0.0, 0.0, 0.0), (0.0, bal_y - bowl + 0.3, 0.0), 0.32, 0.32, 8, "tank_shade")
    # the balcony: a floor ring round the rim, a railing round it on posts
    br = R + 0.6
    floor_in, floor_out = [], []
    rail_lo, rail_hi = [], []
    for i in range(sides):
        t = 2.0 * math.pi * i / sides
        c, s = math.cos(t), math.sin(t)
        floor_in.append((R * c, bal_y, R * s))
        floor_out.append((br * c, bal_y, br * s))
        rail_lo.append((br * c, bal_y + 0.95, br * s))
        rail_hi.append((br * c, bal_y + 1.05, br * s))
    m.rings([floor_in, floor_out], "rail", out=(0.0, 1.0, 0.0))
    m.rings([[(x, y - 0.15, z) for x, y, z in floor_out], floor_out], "rail")
    m.rings([[(x, y - 0.15, z) for x, y, z in floor_in], [(x, y - 0.15, z) for x, y, z in floor_out]], "rail",
            out=(0.0, -1.0, 0.0))
    m.rings([rail_lo, rail_hi], "rail")
    m.rings([rail_lo, rail_hi], "rail", inward=True)
    for i in range(0, sides, 4):
        x, _, z = floor_out[i]
        m.tube((x, bal_y, z), (x, bal_y + 1.0, z), 0.03, 0.03, 3, "rail")
    # the ladder: up the +Z side to the balcony, then up the drum to the roof's eave
    for dx in (-0.22, 0.22):
        m.tube((dx, 0.4, foot * 0.92), (dx, bal_y, br - 0.05), 0.03, 0.03, 3, "rail")
        m.tube((dx, bal_y + 1.0, R + 0.12), (dx, tank_top + 0.1, R + 0.12), 0.03, 0.03, 3, "rail")
    for k in range(5):
        y = 0.4 + (bal_y - 0.4) * (k + 0.5) / 5.0
        t = (y - 0.4) / (bal_y - 0.4)
        z = foot * 0.92 + (br - 0.05 - foot * 0.92) * t
        m.tube((-0.22, y, z), (0.22, y, z), 0.025, 0.025, 3, "rail")
    return m


KINDS = {"shed": shed, "shed_long": lambda: shed("shed_long"), "shed_deep": lambda: shed("shed_deep"),
         "crane": crane, "mast": mast, "fuselage": fuselage, "silo": silo, "watch_tower": watch_tower,
         "water_tower": water_tower}


def main() -> None:
    names = sys.argv[1:] or list(KINDS)
    failed = False
    for name in names:
        hs.reset()
        model = KINDS[name]()
        ob = model.build()
        n = hs.tris(ob)
        lo = [min(v.co[i] for v in ob.data.vertices) for i in range(3)]
        hi = [max(v.co[i] for v in ob.data.vertices) for i in range(3)]
        size = (hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1])  # Godot x, y, z
        print("%-12s %4d of %4d tris  %.2f x %.2f x %.2f m" % (name, n, BUDGETS[name], *size))
        if n > BUDGETS[name]:
            failed = True
            continue
        vp.export(os.path.abspath(os.path.join(OUT, name + ".glb")))
    if failed:
        sys.exit("over budget")


if __name__ == "__main__":
    main()
