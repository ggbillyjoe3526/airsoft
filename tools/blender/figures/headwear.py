"""The figure's four heads, rebuilt from the owner's photos (BL11, 2026-11-05): the Head_* meshes of
assets/models/characters/human.glb, each with its LOD1 and LOD2.

Each head is a balaclava'd head with its own head gear and eye protection, as the game has worn since v12 (the owner's
RM9 ruling: four looks, picked per figure by its id, FigureConfig.heads):

  Head_HighCut  a FAST-style high-cut helmet (ref_images/clothes/highcut_helmet, the grey shell of photos 1-5): ear
                cut-outs, side rails, a front shroud, loop strips, vents and a chin harness; electronic ear
                defenders on the rails; wrap-round shooting glasses; the steel mesh lower-face mask
  Head_Cap      a tactical cap (baseball_cap, photo 4: tan ripstop, loop panels, a laser-cut side, the snap strap of
                photo 3) with the team patch on its front; a comms headset over it; full-seal goggles (goggles); the
                mesh mask (mesh_face_mask)
  Head_Boonie   an olive boonie hat (boonie_hat: stitched brim, webbing band, eyelets, chin cord) with the team band;
                wrap-round glasses; a sand check scarf over the nose and neck
  Head_FullCut  a full-cut helmet, the high cut's shell carried down over the ears, in a coyote cover (highcut photo 1's
                cover; its navy is too near Alpha's blue) with rails, shroud and the team band; full-seal goggles;
                the balaclava and the chin harness

Under every look the face shows through the balaclava's eye opening (face.py, FA1): skin, lids and eyeballs.

Every head is skinned whole to the Head bone. The materials: Headwear (one 2048 px atlas painted here, no bakes),
TeamHeadwear (the same atlas, tinted the team's colour in game: FigureConfig.team_material_prefix), Face (the same
atlas, its UVs offset in game to the figure's look: FigureConfig.face_offsets) and the figure's own Lens. Budget: the
largest head 9,000 / 3,200 / 900 triangles (LOD0 / 1 / 2), agreed with the body and carrier threads inside the
figure's 60,000 / 20,000 / 6,000 (8,000 / 2,600 / 800 before the face took the split's spare).

Run with Blender 5.x or Python with the `bpy` module (pip install bpy==5.2.3), from the repository root:

    python tools/blender/figures/headwear.py [--renders DIR]

It writes the four heads into human.glb by splice_heads.py (only the Head_* nodes, their meshes and the two head
materials and Face change; the body, kit, skeleton and clips stay byte for byte), so it can run again on any newer human.glb.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402  (first of Blender's modules: it brings bmesh and mathutils)
from mathutils import Vector  # noqa: E402

import collar  # noqa: E402
import face  # noqa: E402
import head_shapes as hs  # noqa: E402
import head_textures  # noqa: E402
from headkit import DEG, GEAR, TAU, Atlas, Drape, Part, cull, direction, gauss, keyed, smoothstep  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
HUMAN = os.path.join(ROOT, "assets/models/characters/human.glb")

HEADS = ("Head_HighCut", "Head_Cap", "Head_Boonie", "Head_FullCut")
# Triangles per head at each level (the agreed share of the figure's budget).
BUDGET = (9000, 3200, 900)
# Resolution per level: how many columns round the head, and whether the small parts are drawn.
LEVELS = (
    {"around": 44, "rings": 30, "shell": 40, "rows": 12, "fine": True, "small": True, "straps": True},
    {"around": 22, "rings": 15, "shell": 20, "rows": 6, "fine": False, "small": False, "straps": True},
    {"around": 12, "rings": 8, "shell": 12, "rows": 3, "fine": False, "small": False, "straps": False},
)

# Each head's detail per level (1.0 = the counts written in the builders): tuned so every head uses about 95 to 100 %
# of its level's budget (owner, 2026-11-05: as much detail as the budget allows). Override with HEADWEAR_DENSITY.
DENSITY = {
    "Head_HighCut": (0.97, 1.03, 1.2),
    "Head_Cap": (1.15, 1.12, 1.15),
    "Head_Boonie": (1.24, 1.27, 1.13),
    "Head_FullCut": (1.24, 1.26, 1.2),
}


def density(name: str, level: int) -> float:
    """`DENSITY`, or the env's "Head_Cap:1:1.2,..." entries (for tuning)."""
    for entry in os.environ.get("HEADWEAR_DENSITY", "").split(","):
        bits = entry.split(":")
        if len(bits) == 3 and bits[0] == name and int(bits[1]) == level:
            return float(bits[2])
    return DENSITY[name][level]


TEAM = "TeamHeadwear"
LENS = "Lens"


class Kit:
    """What every part builder shares: the atlas (swatches and tiles) and the level being built."""

    def __init__(self, atlas: Atlas, level: int, density: float = 1.0):
        self.atlas = atlas
        self.level = level
        self.lv = LEVELS[level]
        self.density = density

    def sw(self, name: str):
        return self.atlas.swatches[name]

    def tile(self, name: str):
        return self.atlas.tiles[name]

    def n(self, lod0: int, minimum: int = 3) -> int:
        """A count at this level: LOD0's, halved at LOD1, a quarter at LOD2, never under `minimum`."""
        return max(minimum, int(round(lod0 * self.density / (1, 2, 4)[self.level])))

    def cols(self) -> int:
        """Columns round a shell, crown or brim at this level and density, a multiple of four (symmetric)."""
        return 4 * max(3, int(round(self.lv["shell"] * self.density / 4)))

    def rows(self) -> int:
        return max(3, int(round(self.lv["rows"] * self.density)))


# --------------------------------------------------------------------------------------------------- the head

def head(k: Kit, keep=None, opening: bool = False) -> Part:
    """The balaclava'd head from the neck's foot to the crown, its UVs on the knit tile (az across, z up). With
    `opening`, the eye opening is cut out (face.py fills it). `keep(point)` False drops a face hidden under the head
    gear."""
    p = Part("head")
    knit = k.tile("knit")
    azs = hs.head_azimuths(k.lv["around"])
    zs, top = hs.head_rings(k.lv["around"], k.lv["rings"])
    if opening:
        azs = face.with_lines(azs, [-face.HOLE_AZ, face.HOLE_AZ])
        zs = face.with_lines(zs, [face.HOLE_Z0, face.HOLE_Z1])

    def uv(i: int, j: int):
        a = azs[i] if i < len(azs) else math.pi
        return knit.uv((a + math.pi) / TAU, (zs[j] - head_textures.KNIT_Z0) / head_textures.KNIT_SPAN)

    rows = [[hs.head_point(a, z) for a in azs] for z in zs]
    idx = p.grid(rows, GEAR, uv, wrap=True)
    p.fan(idx[-1], top, GEAR, lambda i: uv(min(i, len(azs)), len(zs) - 1),
          knit.uv(0.5, (top.z - head_textures.KNIT_Z0) / head_textures.KNIT_SPAN))
    if opening:
        face.cut_hole(p)
    if keep is not None:
        cull(p, keep)
    return p


# --------------------------------------------------------------------------------------------------- helmets

class Shell:
    """One helmet's shell: its size, rim and tile, and where things sit on it."""

    def __init__(self, size: tuple, rim: list, tile: str, colour: str, trim: str):
        self.size, self.rim, self.tile_name, self.colour, self.trim = size, rim, tile, colour, trim

    def point(self, az: float, el: float, off: float = 0.0) -> Vector:
        return hs.shell_point(self.size, az, el, off)

    def normal(self, az: float, el: float) -> Vector:
        return hs.shell_normal(self.size, az, el)

    def rim_el(self, az: float) -> float:
        return hs.rim_el(self.rim, az)

    def covers(self, pt: Vector, margin: float = 0.006) -> bool:
        """Whether `pt` (on the head) is under the shell, `margin` in from its rim."""
        d = pt - hs.SHELL_CENTRE
        if d.length < 1e-6:
            return True
        az = math.atan2(d.x, -d.y)
        el = math.asin(max(-1.0, min(1.0, d.z / d.length)))
        return el > self.rim_el(az) + margin / 0.11


def shell_body(k: Kit, sh: Shell, inner: bool = True) -> Part:
    """The shell: outer surface from the crown to the rim, a rubber edge trim round the rim, and the dark inside."""
    p = Part("shell")
    tile = k.tile(sh.tile_name)
    cols = k.cols()
    rows_n = k.rows()
    azs = [-math.pi + TAU * i / cols for i in range(cols)]

    def t_el(az: float, t: float) -> float:
        top = 88.0 * DEG
        return top + (sh.rim_el(az) - top) * t

    ts = [(j / rows_n) ** 0.9 for j in range(1, rows_n + 1)]

    def uv_out(i: int, j: int):
        az = azs[i] if i < cols else math.pi
        el = t_el(az, ts[j])
        return tile.uv((az + math.pi) / TAU, (el / DEG + 25.0) / 115.0)

    outer = [[sh.point(a, t_el(a, t)) for a in azs] for t in ts]
    idx = p.grid(outer, GEAR, uv_out, wrap=True)
    p.fan(idx[0], sh.point(0.0, 90.0 * DEG), GEAR, lambda i: uv_out(min(i, cols), 0), tile.uv(0.5, 1.0), flip=True)
    # The edge trim: a rolled rubber lip round the rim.
    trim = k.sw(sh.trim)
    lip_rows = []
    for off_out, drop in ((0.0, 0.0), (0.0025, 0.0028), (0.0, 0.0055), (-0.008, 0.0045)):
        row = []
        for a in azs:
            el = sh.rim_el(a)
            base = sh.point(a, el)
            n = sh.normal(a, el)
            down = (sh.point(a, el - 0.02) - base).normalized()
            row.append(base + n * off_out + down * drop)
        lip_rows.append(row)
    p.grid([outer[-1]] + lip_rows, GEAR, lambda i, j: trim, wrap=True)
    if inner:
        dark = k.sw("shell_inside")
        in_rows = [lip_rows[-1]] + [[sh.point(a, t_el(a, t), -0.008) for a in azs] for t in (1.0, 0.6, 0.25)]
        p.grid(in_rows, GEAR, lambda i, j: dark, wrap=True)
    return p


def shell_patch(k: Kit, sh: Shell, az0: float, az1: float, el0: float, el1: float, off: float, mat: str,
                uv, nu: int, nv: int, taper: float = 1.0, above_rim: bool = False) -> Part:
    """A raised panel on the shell between two azimuths and elevations (radians): its face `off` out, its edges
    sloping down to the shell; `taper` the top's width over the bottom's; `above_rim`: the elevations are above the
    rim at each azimuth. uv(s, t) maps the face; the edges take its border."""
    p = Part("patch")
    face_rows, base_rows = [], []
    for j in range(nv + 1):
        fr, br = [], []
        mid, half = (az0 + az1) / 2, (az1 - az0) / 2 * (1.0 + (taper - 1.0) * j / nv)
        for i in range(nu + 1):
            az = mid - half + 2 * half * i / nu
            el = el0 + (el1 - el0) * j / nv + (sh.rim_el(az) if above_rim else 0.0)
            fr.append(sh.point(az, el, off))
            br.append(sh.point(az, el, off * 0.15))
        face_rows.append(fr)
        base_rows.append(br)
    p.grid(face_rows, mat, lambda i, j: uv(i / nu, j / nv))
    outline_f = face_rows[0] + [r[-1] for r in face_rows[1:]] + list(reversed(face_rows[-1][:-1])) + \
        [r[0] for r in reversed(face_rows[1:-1])]
    outline_b = base_rows[0] + [r[-1] for r in base_rows[1:]] + list(reversed(base_rows[-1][:-1])) + \
        [r[0] for r in reversed(base_rows[1:-1])]
    edge_uv = uv(0.0, 0.0)
    p.grid([outline_b, outline_f], mat, lambda i, j: edge_uv, wrap=True, flip=True)
    return p


def drape_patch(k: Kit, drape: Drape, ray, off: float, mat: str, uv, nu: int, nv: int,
                corner: float = 0.0) -> Part:
    """A raised panel laid on what `drape` holds: ray(s, t) gives (start, target) for each grid point; `corner` cuts
    its corners (a share of each side)."""
    p = Part("patch")
    face_rows, base_rows = [], []
    for j in range(nv + 1):
        fr, br = [], []
        for i in range(nu + 1):
            s, t = i / nu, j / nv
            if corner > 0.0 and i in (0, nu) and j in (0, nv):
                # The corner point drawn in along the diagonal: a cut corner, rounded by the smooth shading.
                s = corner if i == 0 else 1.0 - corner
                t = corner if j == 0 else 1.0 - corner
            a, b = ray(s, t)
            hit_f = drape.toward(a, b, off)
            hit_b = drape.toward(a, b, off * 0.1)
            if hit_f is None or hit_b is None:
                # Off the edge of what it lies on: hold the last point that landed (never fall to the ray's end).
                assert fr, "a patch's first ray must land"
                hit_f, hit_b = fr[-1], br[-1]
            fr.append(hit_f)
            br.append(hit_b)
        face_rows.append(fr)
        base_rows.append(br)
    p.grid(face_rows, mat, lambda i, j: uv(i / nu, j / nv))
    outline_f = face_rows[0] + [r[-1] for r in face_rows[1:]] + list(reversed(face_rows[-1][:-1])) + \
        [r[0] for r in reversed(face_rows[1:-1])]
    outline_b = base_rows[0] + [r[-1] for r in base_rows[1:]] + list(reversed(base_rows[-1][:-1])) + \
        [r[0] for r in reversed(base_rows[1:-1])]
    edge_uv = uv(0.5, 0.0)
    p.grid([outline_b, outline_f], mat, lambda i, j: edge_uv, wrap=True)
    return p


def _solve3(m: list, v: list) -> list:
    """Solves the 3x3 system m x = v (Cramer's rule)."""
    def det(a: list) -> float:
        return (a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1]) - a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0])
                + a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0]))
    d = det(m)
    out = []
    for c in range(3):
        mc = [[v[r] if cc == c else m[r][cc] for cc in range(3)] for r in range(3)]
        out.append(det(mc) / d)
    return out


def _rail_line(sh: Shell, az0: float, az1: float, lift: float):
    """The rail's elevation by azimuth: a smooth line `lift` over the highest rim within 12 degrees either side, so it
    runs straight along the shell over the ear cut-out (photo 2) instead of following each step of the rim."""
    def envelope(az: float) -> float:
        return max(sh.rim_el(az + d * DEG) for d in range(-12, 13, 3)) + lift

    def line(az: float) -> float:
        return sum(envelope(az + d * DEG) for d in range(-12, 13, 3)) / 9.0

    raw = [line(az0 + (az1 - az0) * i / 24) for i in range(25)]
    # A quadratic through it, raised until it clears the envelope: one even curve, no kink at either end.
    xs = [i / 24.0 for i in range(25)]
    sx = [sum(x ** p for x in xs) for p in range(5)]
    sy = [sum(y * x ** p for x, y in zip(xs, raw)) for p in range(3)]
    m = [[sx[r + c] for c in range(3)] for r in range(3)]
    coef = _solve3(m, sy)
    fit = [coef[0] + coef[1] * x + coef[2] * x * x for x in xs]
    # Half the bow, nearer the photo's straight rail.
    fit = [f - 0.5 * coef[2] * x * (x - 1.0) for f, x in zip(fit, xs)]
    lift_up = max(0.0, max(e - f - 1.5 * DEG for e, f in zip(raw, fit)))
    table = [f + lift_up for f in fit]

    def at(az: float) -> float:
        u = max(0.0, min(24.0, (az - az0) / (az1 - az0) * 24.0))
        i = min(int(u), 23)
        return table[i] + (table[i + 1] - table[i]) * (u - i)
    return at


def rails(k: Kit, sh: Shell, az0: float, az1: float, lift: float) -> Part:
    """The side rails (both sides): a slotted strip following the rim `lift` (radians) above it, from az0 to az1
    (radians, the right side mirrored), with a screw at each end and the middle."""
    p = Part("rails")
    tile = k.tile("rail")
    count = k.n(18, 6)
    w, h, c = 0.030, 0.0085, 0.003
    profile = [(-w / 2, -0.001), (w / 2, -0.001), (w / 2, h - c), (w / 2 - c, h), (-w / 2 + c, h), (-w / 2, h - c)]
    rail_el = _rail_line(sh, az0, az1, lift)
    for side in (1.0, -1.0):
        path, outs = [], []
        for i in range(count):
            az = az0 + (az1 - az0) * i / (count - 1)
            el = rail_el(az)
            path.append(sh.point(side * az, el, 0.0005))
            outs.append(sh.normal(side * az, el))
        if side < 0:
            path.reverse()
            outs.reverse()
        prof_n = len(profile)
        p.sweep(path, outs, profile, GEAR, uv=lambda i, j, n=count, m=prof_n: tile.uv(j / (n - 1), i / m))
        if k.lv["small"]:
            screw = k.sw("screw")
            for f in (0.04, 0.5, 0.96):
                az = side * (az0 + (az1 - az0) * f)
                el = rail_el(abs(az))
                n = sh.normal(az, el)
                base = sh.point(az, el, h - 0.0005)
                tan = (sh.point(az + 0.01, el) - sh.point(az - 0.01, el)).normalized()
                p.lathe(base, n, tan, [(0.0, 0.0042), (0.0018, 0.0038), (0.0026, 0.0024), (0.0028, 0.0)],
                        k.n(8, 6), GEAR, uv=lambda i, j, s=screw: s)
    return p


def shroud(k: Kit, sh: Shell) -> Part:
    """The front shroud (photos 1, 3): a trapezoid plate from the brow's rim up the front, narrower at the top, a
    raised frame round the dark mount window, two screws low on its sides and the bolt on a tab above."""
    el0 = sh.rim_el(0.0) + 0.3 * DEG
    el1 = el0 + 29.0 * DEG
    tile = k.tile("shroud")
    p = shell_patch(k, sh, -18 * DEG, 18 * DEG, el0, el1, 0.0035, GEAR, lambda s, t: tile.uv(s, t),
                    k.n(8, 2), k.n(4, 1), taper=0.6)
    if k.lv["small"]:
        mid_el = el0 + 12.0 * DEG
        n = sh.normal(0.0, mid_el)
        up = (sh.point(0.0, mid_el + 0.02) - sh.point(0.0, mid_el - 0.02)).normalized()
        across = up.cross(n).normalized()
        centre = sh.point(0.0, mid_el, 0.0035)
        frame = k.sw("shroud_frame")
        w, h, bar, depth = 0.030, 0.048, 0.005, 0.006
        for dx, dy, sx, sy in ((0, h / 2 - bar / 2, w, bar), (0, -h / 2 + bar / 2, w, bar),
                               (w / 2 - bar / 2, 0, bar, h), (-w / 2 + bar / 2, 0, bar, h)):
            p.box(centre + across * dx + up * dy + n * (depth / 2), across, up, (sx, sy, depth), GEAR, frame,
                  bevel=0.0012)
        p.box(centre + n * 0.0012, across, up, (w - bar, h - bar, 0.0024), GEAR, k.sw("shroud_block"))
        screw = k.sw("screw")
        for az, el in ((-13 * DEG, el0 + 4.0 * DEG), (13 * DEG, el0 + 4.0 * DEG), (0.0, el1 - 1.5 * DEG)):
            nn = sh.normal(az, el)
            p.lathe(sh.point(az, el, 0.0035), nn, Vector((1, 0, 0)),
                    [(0.0, 0.0042), (0.0018, 0.0036), (0.0026, 0.0)], k.n(8, 6), GEAR, uv=lambda i, j: screw)
    return p


def chin_harness(k: Kit, drape: Drape, front_az: float, back_az: float, front_el: float, back_el: float,
                 sh: Shell) -> Part:
    """The chin harness: a strap from the rim before and behind each ear meeting under the ear, then on to a
    chin cup, buckles at the joins."""
    p = Part("harness")
    strap = k.tile("strap")
    w, t = 0.017, 0.0022
    profile = [(-w / 2, 0.0), (w / 2, 0.0), (w / 2, t), (-w / 2, t)]
    centre = Vector((0.0, -0.005, 1.60))
    count = k.n(9, 3)

    def laid(points: list) -> tuple:
        out, outs = [], []
        for q in points:
            q = Vector(q)
            d = (q - centre)
            hit = drape.toward(centre + d.normalized() * 0.35, centre, 0.0018)
            pt = hit if hit is not None else q
            out.append(pt)
            outs.append((pt - centre).normalized())
        return out, outs

    def chain(a: Vector, b: Vector, c: Vector = None) -> list:
        pts = []
        for i in range(count):
            f = i / (count - 1)
            if c is None:
                pts.append(a.lerp(b, f))
            else:
                pts.append(a.lerp(b, f).lerp(b.lerp(c, f), f))
        return pts

    for side in (1.0, -1.0):
        fr = sh.point(side * front_az, front_el - 0.5 * DEG)
        bk = sh.point(side * back_az, back_el - 0.5 * DEG)
        junction = Vector((side * 0.074, 0.006, 1.552))
        cup = Vector((side * 0.024, -0.085, 1.482))
        for a, b, c in ((fr, junction, None), (bk, junction, None), (junction, Vector((side * 0.058, -0.05, 1.5)),
                                                                      cup)):
            path, outs = laid(chain(a, b, c))
            p.sweep(path, outs, profile, GEAR,
                    uv=lambda i, j, n=count: strap.uv(j / (n - 1), (0.0, 1.0, 1.0, 0.0, 0.0)[i]))
        if k.lv["small"]:
            jp, jn = laid([junction])
            p.box(jp[0] + jn[0] * 0.003, (Vector((0, 0, 1)).cross(jn[0])).normalized(), Vector((0, 0, 1)),
                  (0.022, 0.026, 0.005), GEAR, k.sw("buckle"), bevel=0.002)
    # The chin cup across the chin.
    cup_pts = [Vector((x, -0.088 + 0.6 * x * x * 10, 1.48 + 3.0 * x * x)) for x in
               [-0.03 + 0.06 * i / (count - 1) for i in range(count)]]
    path, outs = laid(cup_pts)
    p.sweep(path, outs, [(-0.013, 0.0), (0.013, 0.0), (0.012, 0.004), (-0.012, 0.004)], GEAR,
            uv=lambda i, j: k.sw("chin_cup"))
    return p


def ear_defenders(k: Kit, sh: Shell, cups: str, cushion: str, arm_to_rail: bool) -> Part:
    """Electronic ear defenders over the ears: oval cups on cushions, joined to the rails (helmet) or by a headband
    (the caller adds it)."""
    p = Part("ears")
    seg = k.n(20, 8)
    for side in (1.0, -1.0):
        x0 = side * 0.083
        c = Vector((x0, 0.012, 1.597))
        ax = Vector((side, 0.0, 0.0))

        def ring(dx: float, r: float, sy: float = 0.8, sz: float = 1.0) -> list:
            return [c + ax * dx + Vector((0.0, math.cos(TAU * i / seg) * r * sy, math.sin(TAU * i / seg) * r * sz))
                    for i in range(seg)]
        cushion_rows = [ring(0.0, 0.040), ring(0.004, 0.047), ring(0.012, 0.049), ring(0.017, 0.046)]
        if not k.lv["straps"]:
            cushion_rows = [cushion_rows[0], cushion_rows[2]]
        inner = p.grid(cushion_rows, GEAR, lambda i, j: k.sw(cushion), wrap=True)[0]
        cup_rows = [ring(0.017, 0.044), ring(0.021, 0.047), ring(0.034, 0.045), ring(0.042, 0.037),
                    ring(0.046, 0.024)]
        if not k.lv["straps"]:
            cup_rows = [cup_rows[0], cup_rows[2], cup_rows[4]]
        idx = p.grid(cup_rows, GEAR, lambda i, j: k.sw(cups), wrap=True)
        p.fan(idx[-1], c + ax * 0.047, GEAR, lambda i: k.sw(cups), k.sw(cups), flip=side < 0)
        p.fan(inner, c + ax * 0.002, GEAR, lambda i: k.sw(cushion), k.sw(cushion), flip=side > 0)
        if k.lv["small"]:
            # The volume knobs on the cup's front, a battery door at its back (no logos).
            p.lathe(c + ax * 0.030 + Vector((0.0, -0.036, 0.008)), Vector((0, -1, 0)), Vector((1, 0, 0)),
                    [(0.0, 0.006), (0.006, 0.0058), (0.0075, 0.0)], k.n(10, 6), GEAR, uv=lambda i, j: k.sw(cushion))
            p.box(c + ax * 0.046 + Vector((0.0, 0.006, -0.004)), Vector((0, 1, 0)), Vector((0, 0, 1)),
                  (0.028, 0.034, 0.003), GEAR, k.sw(cushion), bevel=0.004)
        if arm_to_rail:
            # The rail adapter: a strap-like arm from the cup's top up to the rail above the ear.
            az = side * 92 * DEG
            el = sh.rim_el(az) + 7.5 * DEG
            top = sh.point(az, el, 0.008)
            base = c + ax * 0.03 + Vector((0.0, 0.0, 0.046))
            path = [base, base.lerp(top, 0.5) + Vector((side * 0.006, 0, 0)), top]
            outs = [Vector((side, 0, 0))] * 3
            p.sweep(path, outs, [(-0.008, -0.003), (0.008, -0.003), (0.008, 0.003), (-0.008, 0.003)], GEAR,
                    uv=lambda i, j: k.sw(cups))
            if k.lv["small"]:
                p.box(top, Vector((0, 1, 0)), (top - hs.SHELL_CENTRE).normalized(), (0.024, 0.012, 0.016), GEAR,
                      k.sw("rail_dark"), bevel=0.002)
    return p


def boom_mic(k: Kit, side: float = 1.0) -> Part:
    p = Part("mic")
    pts = [Vector((side * 0.124, -0.012, 1.586)), Vector((side * 0.118, -0.06, 1.572)),
           Vector((side * 0.085, -0.108, 1.556)), Vector((side * 0.035, -0.132, 1.551))]
    path = []
    count = k.n(9, 3)
    for i in range(count):
        t = i / (count - 1)
        a, b, c, d = pts
        path.append(a * (1 - t) ** 3 + b * 3 * t * (1 - t) ** 2 + c * 3 * t * t * (1 - t) + d * t ** 3)
    outs = [Vector((0, 0, 1))] * count
    r = 0.0022
    seg = k.n(6, 4)
    prof = [(math.cos(TAU * i / seg) * r, math.sin(TAU * i / seg) * r) for i in range(seg)]
    p.sweep(path, outs, prof, GEAR, uv=lambda i, j: k.sw("mic"))
    if k.lv["small"]:
        d = (path[-1] - path[-2]).normalized()
        p.lathe(path[-1], d, Vector((0, 0, 1)), [(-0.004, 0.0), (-0.003, 0.0055), (0.008, 0.0062), (0.013, 0.0)],
                k.n(10, 6), GEAR, uv=lambda i, j: k.sw("mic_foam"))
    return p


# --------------------------------------------------------------------------------------------------- eyewear

def lens_point(spec: dict, a: float, b: float, off: float = 0.0) -> Vector:
    """A point on a wrap-round lens: `a` -1..1 across (right to left), `b` 0..1 bottom to top."""
    alpha = a * spec["wrap"]
    zt = spec["top"] - spec["top_drop"] * a * a - spec["corner"] * a ** 8
    zb = lens_bottom(spec, alpha)
    z = zb + (zt - zb) * b
    rx, ry = spec["rx"] + off, spec["ry"] + off
    bulge = spec["bulge"] * math.sin(math.pi * b)
    tilt = spec["tilt"] * (0.5 - b)
    return Vector((math.sin(alpha) * rx, spec["cy"] - math.cos(alpha) * (ry + bulge + tilt), z))


GOGGLE = {"wrap": 62 * DEG, "corner": 0.011, "top": 1.641, "top_drop": 0.013, "bottom": 1.570, "bottom_rise": 0.012, "nose": 0.032,
          "nose_width": 21.0, "rx": 0.093, "ry": 0.130, "cy": 0.010, "bulge": 0.003, "tilt": 0.004}
GLASSES = {"wrap": 66 * DEG, "corner": 0.007, "top": 1.641, "top_drop": 0.004, "bottom": 1.597, "bottom_rise": 0.006, "nose": 0.013,
           "nose_width": 12.0, "rx": 0.088, "ry": 0.124, "cy": 0.008, "bulge": 0.002, "tilt": 0.003}


def outline(spec: dict, n_across: int, n_side: int, off: float = 0.0, ea: float = 1.0, b0: float = 0.0,
            b1: float = 1.0) -> list:
    """The lens's edge as a closed loop: along the top right to left, down the left end, back along the bottom, up
    the right end. `ea`, `b0`, `b1` draw it inset: across to +-ea, from b0 up to b1."""
    def at(a: float, b: float) -> Vector:
        return lens_point(spec, a * ea, b0 + (b1 - b0) * b, off)
    pts = [at(-1 + 2 * i / n_across, 1.0) for i in range(n_across + 1)]
    pts += [at(1.0, 1 - i / n_side) for i in range(1, n_side)]
    pts += [at(1 - 2 * i / n_across, 0.0) for i in range(n_across + 1)]
    pts += [at(-1.0, i / n_side) for i in range(1, n_side)]
    return pts


def lens(k: Kit, spec: dict, nu: int, nv: int) -> Part:
    p = Part("lens")
    rows = [[lens_point(spec, -1 + 2 * i / nu, j / nv) for i in range(nu + 1)] for j in range(nv + 1)]
    p.grid(rows, LENS, lambda i, j: (0.0, 0.0), flip=True)
    return p


def goggles(k: Kit, drape: Drape, strap_z: float = 1.622, strap_b: float = 0.5) -> Part:
    """Full-seal goggles (the owner's goggle photos 1-4: a one-piece wrap lens in a rubber frame, a foam gasket to
    the face, a wide strap with clips). The strap leaves the lens's ends `strap_b` up them (0 bottom, 1 top)."""
    p = lens(k, GOGGLE, k.n(16, 4), k.n(4, 1))
    na, ns = k.n(18, 5), k.n(4, 1)
    front = outline(GOGGLE, na, ns, 0.0015)
    # The frame's face over the lens's edge: a dark band, deepest at the ends where the strap clips sit, thin along
    # the bottom where the photos show the clear lens run past the gasket.
    inset = outline(GOGGLE, na, ns, 0.0018, ea=0.9, b0=0.07, b1=0.86)
    p.grid([[q + (q - Vector((0, GOGGLE["cy"], q.z))).normalized() * 0.0003 for q in front], inset], GEAR,
           lambda i, j: k.sw("goggle_frame"), wrap=True, flip=True)
    centre = Vector((0.0, 0.025, 1.615))
    face = []
    for q in outline(GOGGLE, na, ns, -0.012):
        d = Vector((q.x, q.y - centre.y, 0.0)).normalized()
        hit = drape.toward(Vector((q.x, q.y, q.z)) + d * 0.05, Vector((0.0, centre.y, q.z)), 0.0025)
        face.append(hit if hit is not None else q)
    # The rubber frame round the lens, its body back to the gasket, the gasket on the face.
    frame = k.sw("goggle_frame")
    foam = k.sw("goggle_foam")
    lip = [q + (q - Vector((0, centre.y, q.z))).normalized() * 0.0025 + Vector((0, 0, 0)) for q in front]
    mid = [a.lerp(b, 0.45) for a, b in zip(front, face)]
    grow = []
    for q, m in zip(front, mid):
        c = Vector((0, centre.y, q.z))
        grow.append(m + (m - c).normalized() * 0.0005 + (Vector((0, 0, 1)) if q.z > 1.62 else Vector((0, 0, -1)))
                    * 0.0035)
    p.grid([[q.lerp(Vector((0, centre.y, q.z)), 0.004) for q in front], lip, grow, mid], GEAR,
           lambda i, j: frame, wrap=True)
    foam_out = [a.lerp(b, 0.75) for a, b in zip(mid, face)]
    p.grid([mid, foam_out, face], GEAR, lambda i, j: foam, wrap=True)
    # The strap round the back of the head over whatever is there.
    strap = k.tile("goggle_strap")
    count = k.n(24, 6)
    w = 0.03
    profile = [(-w / 2, 0.0), (w / 2, 0.0), (w / 2, 0.0025), (-w / 2, 0.0025)]
    end_l = lens_point(GOGGLE, 1.0, strap_b, -0.006)
    end_r = lens_point(GOGGLE, -1.0, strap_b, -0.006)
    az_l = math.atan2(end_l.x, -end_l.y)
    ring = drape.ring((0.0, 0.0), strap_z, az_l + 0.2, TAU - az_l - 0.2, count, 0.0015)
    path = [end_l] + ring + [end_r]
    outs = [Vector((q.x, q.y, 0.0)).normalized() for q in path]
    p.sweep(path, outs, profile, GEAR, uv=lambda i, j, n=len(path): strap.uv(j / (n - 1), (0.0, 1.0, 1.0, 0.0, 0.0)[i]))
    if k.lv["small"]:
        for e in (end_l, end_r):
            d = Vector((e.x, e.y, 0)).normalized()
            p.box(e + d * 0.004, Vector((0, 0, 1)), d.cross(Vector((0, 0, 1))), (0.03, 0.022, 0.008), GEAR,
                  frame, bevel=0.003)
    return p


def glasses(k: Kit, drape: Drape) -> Part:
    """Wrap-round shooting glasses: the goggles' one-piece lens shape without strap or foam, a top bar, nose pads and
    arms back over the ears (the owner's goggle photos 1 and 3, as glasses)."""
    p = lens(k, GLASSES, k.n(16, 4), k.n(3, 1))
    frame = k.sw("glasses_frame")
    count = k.n(18, 5)
    path = [lens_point(GLASSES, -1 + 2 * i / (count - 1), 1.0, 0.001) + Vector((0, 0, 0.0012)) for i in range(count)]
    outs = [Vector((q.x, q.y - GLASSES["cy"], 0.0)).normalized() for q in path]
    p.sweep(path, outs, [(-0.0035, -0.004), (0.0025, -0.004), (0.003, 0.0015), (-0.0035, 0.0015)], GEAR,
            uv=lambda i, j: frame)
    # Arms: from each end of the bar back along the head over the ear.
    for side in (1.0, -1.0):
        hinge = lens_point(GLASSES, side, 0.82, -0.002)
        pts = []
        n = k.n(8, 3)
        az0 = math.atan2(hinge.x, -hinge.y)
        for i in range(n):
            f = i / (n - 1)
            az = side * (abs(az0) + (122 * DEG - abs(az0)) * f)
            z = hinge.z - 0.022 * smoothstep(0.6, 1.0, f) - 0.004 * f
            q = drape.toward(Vector((0, 0, z)) + direction(az, 0.0) * 0.3, Vector((0, 0, z)), 0.0018)
            pts.append(q if q is not None else hinge)
        pts[0] = hinge
        outs = [Vector((q.x, q.y, 0.0)).normalized() for q in pts]
        p.sweep(pts, outs, [(-0.0045, 0.0), (0.0045, 0.0), (0.0045, 0.0026), (-0.0045, 0.0026)], GEAR,
                uv=lambda i, j: frame)
    return p


# --------------------------------------------------------------------------------------------------- face covers

MASK_CENTRE = Vector((0.0, -0.005, 1.56))
MASK_TOP = [(0, 31.0), (9, 26.0), (24, 9.0), (38, 10.0), (60, 21.0), (82, 27.0), (100, 26.0)]
MASK_BOTTOM = [(0, -62.0), (25, -61.0), (45, -52.0), (70, -36.0), (100, -21.0)]
MASK_WRAP = 100.0
MASK_UNDER_LENS = 0.004


def lens_bottom(spec: dict, az: float) -> float:
    """The height of a lens's lower edge at azimuth `az` (radians), held at its end beyond the wrap."""
    a = max(-1.0, min(1.0, az / spec["wrap"]))
    nose = spec["nose"] * gauss(a * spec["wrap"] / DEG, spec["nose_width"])
    return spec["bottom"] + spec["bottom_rise"] * a * a + spec["corner"] * a ** 8 + nose


def mask(k: Kit, drape: Drape, eyewear: dict) -> Part:
    """The steel mesh lower-face mask (mesh_face_mask photos 2-5): a mesh shell from the nose bridge under the
    chin, its edge bound in fabric, straps with snaps round the back. Its top stays under the lower edge of the
    `eyewear` worn with it, so the lens and frame sit over it as they do on a player."""
    p = Part("mask")
    tile = k.tile("mesh")
    nu, nv = k.n(24, 6), k.n(7, 2)
    tops = {}

    def stand_off(a: float) -> float:
        # Off the face, less toward the ends so the wings lie on the cheeks.
        return 0.006 + 0.008 * (1.0 - a ** 4)

    def top_el(az: float) -> float:
        if az not in tops:
            el = keyed(MASK_TOP, abs(az))
            limit = lens_bottom(eyewear, az * DEG) - MASK_UNDER_LENS
            for _ in range(4):
                q = drape.around(MASK_CENTRE, az * DEG, el * DEG, stand_off(az / MASK_WRAP))
                if q is None or q.z <= limit:
                    break
                el -= math.degrees((q.z - limit) / (q - MASK_CENTRE).length) + 0.05
            tops[az] = el
        return tops[az]

    def pt(a: float, b: float, extra: float = 0.0) -> Vector:
        off = stand_off(a) + extra
        az = a * MASK_WRAP
        spread = math.copysign(8.0 * b * abs(a) ** 3, a)  # the wings lean out toward the ear tabs at the top
        el = keyed(MASK_BOTTOM, abs(az)) + (top_el(az) - keyed(MASK_BOTTOM, abs(az))) * b
        bulge = 0.009 * math.sin(math.pi * b) * (1 - a * a)
        q = drape.around(MASK_CENTRE, (az + spread) * DEG, el * DEG, off + bulge)
        return q if q is not None else MASK_CENTRE + direction((az + spread) * DEG, el * DEG) * 0.1

    # The top edge smoothed along its length, so it follows the lens's nose arch in one curve, kept a little under it.
    col_az = [(-1 + 2 * i / nu) * MASK_WRAP for i in range(nu + 1)]
    raw = [top_el(az) for az in col_az]
    smooth = raw
    for _ in range(3):
        smooth = [smooth[0]] + [(smooth[i - 1] + 2 * smooth[i] + smooth[i + 1]) / 4 for i in range(1, nu)] + \
            [smooth[-1]]
    tops.update({az: min(sm, r + 1.0) - 0.4 for az, sm, r in zip(col_az, smooth, raw)})
    rows = [[pt(-1 + 2 * i / nu, j / nv) for i in range(nu + 1)] for j in range(nv + 1)]
    p.grid(rows, GEAR, lambda i, j: tile.uv(i / nu, j / nv), flip=False)
    if not k.lv["straps"]:
        return p
    # The binding round the edge.
    loop = rows[-1] + [r[-1] for r in reversed(rows[1:-1])] + list(reversed(rows[0])) + [r[0] for r in rows[1:-1]]
    outs = [(q - MASK_CENTRE).normalized() for q in loop]
    p.sweep(loop, outs, [(-0.0045, -0.002), (0.0045, -0.002), (0.0045, 0.002), (-0.0045, 0.002)], GEAR,
            uv=lambda i, j: k.sw("mask_binding"), closed_path=True)
    # Straps: top and bottom, from the mask's ends round the back of the head.
    strap = k.tile("strap")
    w = 0.019
    for b, z in ((0.85, 1.606), (0.2, 1.545)):
        end_l = pt(1.0, b, 0.002)
        end_r = pt(-1.0, b, 0.002)
        az_l = math.atan2(end_l.x, -end_l.y)
        count = k.n(16, 4)
        ring = drape.ring((0.0, 0.0), z, az_l + 0.12, TAU - az_l - 0.12, count, 0.0016)
        path = [end_l] + ring + [end_r]
        outs = [Vector((q.x, q.y, 0)).normalized() for q in path]
        p.sweep(path, outs, [(-w / 2, 0.0), (w / 2, 0.0), (w / 2, 0.002), (-w / 2, 0.002)], GEAR,
                uv=lambda i, j, n=len(path): strap.uv(j / (n - 1), (0.0, 1.0, 1.0, 0.0, 0.0)[i]))
        if k.lv["small"]:
            for e in (end_l, end_r):
                n = (e - MASK_CENTRE).normalized()
                p.lathe(e, n, Vector((0, 0, 1)), [(0.0, 0.0062), (0.0022, 0.0055), (0.0032, 0.0)], k.n(10, 6), GEAR,
                        uv=lambda i, j: k.sw("snap"))
    return p


SCARF_CENTRE = Vector((0.0, 0.004, 1.535))
# The scarf lies this far (m) over the shirt's collar (collar.py), easing back onto the neck over this height (m) above
# the collar's top (CN1: the bigger collar of 2026-11-10 would otherwise take the scarf's tail inside it).
SCARF_OVER_COLLAR = 0.007
SCARF_OVER_EASE = 0.015


def over_collar(q: Vector, folds: float) -> Vector:
    """Point q of the scarf carried out from the neck's axis, if need be, to lie over the shirt's collar."""
    off = Vector((q.x, q.y - collar.AXIS_Y, 0.0))
    r = off.length
    if r < 1e-6:
        return q
    ang = math.atan2(q.x, -(q.y - collar.AXIS_Y))
    rim = collar.top(ang)
    need = (collar.outer_radius(ang, min(q.z, rim)) + SCARF_OVER_COLLAR + folds) * (
        1.0 - smoothstep(rim, rim + SCARF_OVER_EASE, q.z))
    if r >= need:
        return q
    return q + off * (need / r - 1.0)


def scarf(k: Kit, drape: Drape) -> Part:
    """A sand check scarf (shemagh) over the nose and round the neck, folds across it, a rolled lower edge."""
    p = Part("scarf")
    tile = k.tile("shemagh")
    nu, nv = k.n(34, 10), k.n(10, 3)
    top = [(0, 33.0), (20, 25.0), (60, 26.0), (100, 22.0), (140, 12.0), (180, 8.0)]
    bottom = -58.0

    def pt(i: int, j: int) -> Vector:
        az = -math.pi + TAU * i / nu
        a = abs(az / DEG)
        b = j / nv
        el = bottom + (keyed(top, a) - bottom) * b
        folds = 0.0028 * math.sin(b * 9.5 + 0.8 * math.sin(az * 3.0)) + 0.002 * math.sin(az * 7.0 + b * 3.0)
        drop = 0.006 * gauss(az, 0.5) * math.sin(math.pi * b)  # the front sags into a soft V under the chin
        q = drape.around(SCARF_CENTRE, az, el * DEG, 0.009 + folds + drop + 0.004 * (1 - b))
        q = q if q is not None else SCARF_CENTRE + direction(az, el * DEG) * 0.1
        return over_collar(q, folds)

    rows = [[pt(i, j) for i in range(nu)] for j in range(nv + 1)]
    p.grid(rows, GEAR, lambda i, j: tile.uv(i / nu, j / nv), wrap=True)
    # The rolled hem round the bottom and the upper edge's turn-in.
    for row, r in ((rows[0], 0.0075), (rows[-1], 0.0035)):
        outs = [(q - SCARF_CENTRE).normalized() for q in row]
        seg = k.n(6, 4)
        prof = [(math.cos(TAU * i / seg) * r, math.sin(TAU * i / seg) * r) for i in range(seg)]
        p.sweep(row, outs, prof, GEAR, uv=lambda i, j: tile.uv(j / nu, 0.0 if r > 0.005 else 1.0),
                closed_path=True, caps=False)
    return p


# --------------------------------------------------------------------------------------------------- hats

BOONIE_BAND_Z = 1.655
CROWN_TAPER = 0.17
# Soft dents in the crown (azimuth, height): the cotton gives where it has been handled.
BOONIE_DENTS = [(-0.6, 0.0035), (2.2, 0.003), (1.0, 0.0025)]


def _dents(az: float, f: float) -> float:
    d = 0.0
    for a0, depth in BOONIE_DENTS:
        da = (az - a0 + math.pi) % TAU - math.pi
        d += depth * gauss(da, 0.32) * math.sin(math.pi * f)
    return d


def boonie(k: Kit) -> list:
    """The boonie (boonie_hat photos 1, 4, 6): a soft six-panel crown with a pinched top, the webbing band with its
    foliage loops (the team band), two eyelets each side, a wide stitched brim drooping at the sides, the chin cord.
    Returns [hat, band]."""
    p = Part("boonie")
    crown_t = k.tile("boonie_crown")
    brim_t = k.tile("brim")
    cols = k.cols()
    azs = [-math.pi + TAU * i / cols for i in range(cols)]

    def base_r(az: float) -> float:
        return hs.head_radius(az, BOONIE_BAND_Z) + 0.008

    heights = [0.0, 0.024, 0.042, 0.055, 0.0625] if k.lv["straps"] else [0.0, 0.04, 0.0625]
    crown_rows = []
    for h in heights:
        f = h / heights[-1]
        row = []
        for a in azs:
            r = base_r(a) * (1.0 - CROWN_TAPER * f * f) + 0.003 * math.sin(math.pi * f) - _dents(a, f)
            z = BOONIE_BAND_Z + h + 0.004 * math.cos(2 * a) * f
            row.append(Vector((math.sin(a) * r, -math.cos(a) * r, z)))
        crown_rows.append(row)

    def uv_crown(i: int, j: int):
        return crown_t.uv(i / cols, j / (len(heights) + 2))

    idx = p.grid(crown_rows, GEAR, uv_crown, wrap=True)
    # The top: a soft dome with the front-to-back pinch.
    # A rounded shoulder into the top (soft cotton, no crease), then the top with its front-to-back pinch.
    top_rows = []
    shoulder = [(0.95, 0.0042), (0.85, 0.0075), (0.62, 0.0098), (0.35, 0.0106)] if k.lv["straps"] else \
        [(0.85, 0.0075), (0.45, 0.0104)]
    for f, dz in shoulder:
        row = []
        for a in azs:
            r = base_r(a) * (1.0 - CROWN_TAPER) * f - _dents(a, 1.0) * f
            z = BOONIE_BAND_Z + heights[-1] + dz + 0.004 * math.cos(2 * a) - 0.003 * (1 - f) * abs(math.sin(a))
            row.append(Vector((math.sin(a) * r, -math.cos(a) * r, z)))
        top_rows.append(row)
    idx2 = p.grid([crown_rows[-1]] + top_rows, GEAR,
                  lambda i, j: crown_t.uv(i / cols, (len(heights) - 1 + j) / (len(heights) + 2)), wrap=True)
    p.fan(idx2[-1], Vector((0, 0.004, BOONIE_BAND_Z + heights[-1] + 0.0112)), GEAR,
          lambda i: crown_t.uv(i / cols, 0.97), crown_t.uv(0.5, 1.0))
    del idx
    # The brim: upper and lower surfaces, a rolled edge.
    width = 0.063
    rings = [0.0, 0.012, 0.025, 0.038, 0.051, width] if k.lv["straps"] else [0.0, 0.032, width]

    def brim_pt(a: float, d: float, dz: float = 0.0) -> Vector:
        # Soft cotton: it falls away from the crown, more at the sides, the edge rolling down further, with the
        # slow waves of the photos (front and back held up a little by the stitching).
        f = d / width
        side = 0.5 - 0.5 * math.cos(2 * a)  # 0 front and back, 1 at the sides
        wave = 0.05 * math.sin(3 * a + 1.0) + 0.035 * math.sin(5 * a + 2.0) + 0.03 * math.sin(2 * a + 0.5) + \
            0.02 * math.sin(7 * a + 1.3)
        slope = 0.34 + 0.05 * side + wave
        r = base_r(a) + d * (1.0 - 0.08 * f * side)
        # Down 1.5 cm at the front and back, the sides' edge curling up a little (boonie_olive_3).
        z = BOONIE_BAND_Z - 0.002 - d * slope - f * f * (0.015 * (1.0 - side) - 0.004 * side) + dz \
            + 0.006 * f * f * math.sin(3 * a + 2.2)
        return Vector((math.sin(a) * r, -math.cos(a) * r, z))

    up = [[brim_pt(a, d, 0.0013) for a in azs] for d in rings]
    down = [[brim_pt(a, d, -0.0013) for a in azs] for d in rings]
    p.grid(up, GEAR, lambda i, j: brim_t.uv(i / cols, 0.5 + 0.5 * j / (len(rings) - 1)), wrap=True, flip=True)
    p.grid(down, GEAR, lambda i, j: brim_t.uv(i / cols, 0.5 - 0.5 * j / (len(rings) - 1)), wrap=True)
    edge = [[brim_pt(a, width + 0.0016, 0.0) for a in azs]]
    p.grid([up[-1]] + edge + [down[-1]], GEAR, lambda i, j: k.sw("boonie_edge"), wrap=True, flip=True)
    # The crown's lower edge meets the brim (the brim's inner ring is the crown's base ring), so it is closed.
    if k.lv["small"]:
        eyelet = k.sw("eyelet")
        for side in (1.0, -1.0):
            for a in (72 * DEG, 108 * DEG):
                az = side * a
                r = base_r(az) * (1.0 - CROWN_TAPER * 0.64 ** 2) + 0.003 * math.sin(math.pi * 0.64) + 0.0004
                c = Vector((math.sin(az) * r, -math.cos(az) * r, BOONIE_BAND_Z + 0.044))
                n = Vector((math.sin(az), -math.cos(az), 0.0))
                p.lathe(c, n, Vector((0, 0, 1)), [(0.0, 0.0052), (0.0012, 0.0046), (0.0012, 0.0026), (0.0, 0.0022)],
                        k.n(10, 6), GEAR, uv=lambda i, j: eyelet)
    # The team band: webbing with foliage loops (bar tacks), round the crown's foot.
    band = Part("band")
    band_t = k.tile("band")
    rows = []
    for h, off in ((-0.0005, 0.0), (0.0, 0.0013), (0.019, 0.0013), (0.0195, 0.0)):
        row = []
        for a in azs:
            f = (h + 0.0005) / heights[-1]
            r = base_r(a) * (1.0 - CROWN_TAPER * f * f) + 0.003 * math.sin(math.pi * f) + off
            z = BOONIE_BAND_Z + 0.002 + h + 0.004 * math.cos(2 * a) * f
            row.append(Vector((math.sin(a) * r, -math.cos(a) * r, z)))
        rows.append(row)
    band.grid(rows, TEAM, lambda i, j: band_t.uv(i / cols, (0.0, 0.05, 0.95, 1.0)[j]), wrap=True)
    # The foliage loops: six raised webbing loops round the band (boonie_olive_3).
    if k.lv["small"]:
        for i in range(6):
            a = (i + 0.5) * TAU / 6 - math.pi
            f = 0.15
            r = base_r(a) * (1.0 - CROWN_TAPER * f * f) + 0.003 * math.sin(math.pi * f) + 0.0028
            n = Vector((math.sin(a), -math.cos(a), 0.0))
            c = Vector((n.x * r, n.y * r, BOONIE_BAND_Z + 0.0115 + 0.004 * math.cos(2 * a) * f))
            band.box(c, n.cross(Vector((0, 0, 1))), Vector((0, 0, 1)), (0.016, 0.021, 0.003), TEAM,
                     band_t.uv(0.5, 0.5), bevel=0.001)
    return [p, band]


def chin_cord(k: Kit, drape: Drape) -> Part:
    """The boonie's chin cord: from inside the band at each side down under the chin to a toggle."""
    p = Part("cord")
    count = k.n(10, 3)
    seg = k.n(6, 4)
    r = 0.0016
    prof = [(math.cos(TAU * i / seg) * r, math.sin(TAU * i / seg) * r) for i in range(seg)]
    centre = Vector((0.0, -0.01, 1.58))
    toggle = Vector((0.0, -0.07, 1.468))
    for side in (1.0, -1.0):
        start = Vector((side * (hs.head_radius(side * 1.6, BOONIE_BAND_Z) + 0.006), 0.0, BOONIE_BAND_Z - 0.004))
        pts = []
        for i in range(count):
            f = i / (count - 1)
            q = start.lerp(toggle, f) + Vector((0, -0.01, -0.012)) * math.sin(math.pi * f)
            hit = drape.toward(centre + (q - centre).normalized() * 0.3, centre, 0.002)
            pts.append(hit if hit is not None and (hit - centre).length > (q - centre).length else q)
        outs = [(q - centre).normalized() for q in pts]
        p.sweep(pts, outs, prof, GEAR, uv=lambda i, j: k.sw("cord"))
    if k.lv["small"]:
        p.lathe(toggle + Vector((0, 0, -0.008)), Vector((0, 0, 1)), Vector((1, 0, 0)),
                [(0.0, 0.0), (0.001, 0.0062), (0.013, 0.0058), (0.014, 0.0)], k.n(10, 6), GEAR,
                uv=lambda i, j: k.sw("toggle"))
    return p


CAP_CENTRE = Vector((0.0, 0.004, 1.600))
CAP_EDGE = [(0, 1.656), (50, 1.646), (100, 1.622), (140, 1.606), (152, 1.606), (164, 1.627), (180, 1.633)]


def cap(k: Kit, drape: Drape) -> list:
    """The tactical cap (baseball_cap photo 4): six panels over a structured front, loop panels front and sides, the
    laser-cut side panels, the button, a curved stitched bill; the back's arch over the snap strap (photo 3).
    Returns [cap, team patch, crown] (the crown alone, for what sits on it)."""
    crown = Part("crown")
    crown_t = k.tile("cap_crown")
    cols = k.cols()
    rows_n = k.n(9, 3)
    azs = [-math.pi + TAU * i / cols for i in range(cols)]
    fs = [(j / rows_n) ** 1.1 for j in range(rows_n + 1)]
    rows = [[cap_point(drape, a, f) for a in azs] for f in fs]
    idx = crown.grid(rows, GEAR, lambda i, j: crown_t.uv(i / cols, fs[j]), wrap=True, flip=True)
    crown.fan(idx[-1], cap_point(drape, 0.0, 1.0) + Vector((0, 0.0, 0.002)), GEAR,
              lambda i: crown_t.uv(i / cols, 1.0), crown_t.uv(0.5, 1.0))
    # The sweatband: a short turn in at the edge.
    inner = [q.lerp(Vector((0.0, CAP_CENTRE.y, q.z)), 0.06) + Vector((0, 0, 0.004)) for q in rows[0]]
    crown.grid([inner, rows[0]], GEAR, lambda i, j: k.sw("cap_inside"), wrap=True, flip=True)
    p = Part("cap")
    if k.lv["small"]:
        top = cap_point(drape, 0.0, 1.0)
        p.lathe(top - Vector((0, 0, 0.001)), Vector((0, 0, 1)), Vector((1, 0, 0)),
                [(0.0, 0.0085), (0.0025, 0.0075), (0.0042, 0.004), (0.0047, 0.0)], k.n(12, 6), GEAR,
                uv=lambda i, j: k.sw("cap_button"))
    p.add(bill(k, drape))
    # The snap strap across the back's arch.
    if k.lv["straps"]:
        count = k.n(10, 3)
        path = []
        for i in range(count):
            az = math.pi - 24 * DEG + 48 * DEG * i / (count - 1)
            c = Vector((0.0, 0.0, 1.627))
            q = drape.toward(c + direction(az, 0.0) * 0.3, c, 0.0035)
            path.append(q if q is not None else c)
        outs = [Vector((q.x, q.y, 0)).normalized() for q in path]
        p.sweep(path, outs, [(-0.0085, 0.0), (0.0085, 0.0), (0.0085, 0.0022), (-0.0085, 0.0022)], GEAR,
                uv=lambda i, j: k.sw("cap_strap"))
    # Loop panels on the crown alone, in the cap's own colour: the front one (the team patch on it) and one each
    # side.
    loop_t = k.tile("loop_cap")
    # The panels lie on the LOD0 crown at every level, so they land where they do at LOD0 and never break up on the
    # coarser crowns (whose faces lie a little inside it).
    holder = Drape([crown]) if k.level == 0 else Drape([cap(Kit(k.atlas, 0, k.density), drape)[2]])

    def panel(az0: float, az1: float, f0: float, f1: float, off: float, mat: str, tile, on: Drape) -> Part:
        def ray(s: float, t: float):
            q = cap_point(drape, az0 + (az1 - az0) * s, f0 + (f1 - f0) * t)
            n = (q - CAP_CENTRE).normalized()
            return q + n * 0.05, q - n * 0.02
        return drape_patch(k, on, ray, off, mat, lambda s, t: tile.uv(s, t), k.n(5, 2), k.n(3, 2))

    front = panel(-25 * DEG, 25 * DEG, 0.1, 0.5, 0.0016, GEAR, loop_t, holder)
    p.add(front)
    if k.lv["fine"]:
        for side in (1.0, -1.0):
            p.add(panel(min(side * 64 * DEG, side * 90 * DEG), max(side * 64 * DEG, side * 90 * DEG), 0.1, 0.4,
                        0.0014, GEAR, loop_t, holder))
    # On the front panel at LOD0; on the crown below that, where the coarser panel would break it up.
    if k.level == 0:
        team = panel(-16 * DEG, 16 * DEG, 0.16, 0.42, 0.0026, TEAM, k.tile("team_loop"), Drape([front]))
    else:
        team = panel(-16 * DEG, 16 * DEG, 0.16, 0.42, 0.0045, TEAM, k.tile("team_loop"), holder)
    p.add(crown)
    return [p, team, crown]


def cap_point(drape: Drape, az: float, f: float) -> Vector:
    """A point on the cap's crown: `f` 0 at its edge to 1 at the button, standing off the head (more at the
    structured front)."""
    z_edge = keyed(CAP_EDGE, abs(az / DEG))
    e0 = math.asin((z_edge - CAP_CENTRE.z) / 0.098)
    el = e0 + (88 * DEG - e0) * f
    off = 0.0065 + 0.016 * gauss(az, 0.7) * gauss(el - 40 * DEG, 0.4) + 0.008 * math.sin(max(el, 0.0)) ** 2
    q = drape.around(CAP_CENTRE, az, el, off)
    return q if q is not None else CAP_CENTRE + direction(az, el) * 0.1


BILL_SPAN = 64 * DEG
BILL_LENGTH = 0.062


def bill(k: Kit, drape: Drape) -> Part:
    """The cap's bill from the crown's front edge: 7 cm long, curved down at the sides, stitched rows on top."""
    p = Part("bill")
    bill_t = k.tile("cap_brim")
    nb = k.n(20, 4)
    nr = k.n(5, 1)
    bases = []
    # Across the bill closer together toward its ends, so its outline rounds into the crown.
    us = [-math.cos(math.pi * i / nb) for i in range(nb + 1)]
    for u in us:
        bases.append(cap_point(drape, BILL_SPAN * u, 0.0) + Vector((0, 0, 0.0015)))
    front_y = min(q.y for q in bases)

    def bill_pt(i: int, r: float, dz: float) -> Vector:
        base = bases[i]
        u = us[i]
        reach = math.sqrt(max(0.0, 1.0 - u * u))
        # Out from its own base point, furthest at the middle and none at the ends, so the edge is one curve into
        # the crown at each side (photo 122905).
        tip = Vector((base.x * (1.0 + 0.08 * reach), base.y - (base.y - front_y + BILL_LENGTH + 0.006) * reach,
                      base.z))
        q = base.lerp(tip, r)
        # The droop grows with the distance out from the crown, more toward the sides (the bill's curve).
        out = (tip - base).length * r
        q.z = base.z - out * (0.09 + 0.36 * u * u) - 0.04 * out * out / BILL_LENGTH + dz
        return q

    up = [[bill_pt(i, j / nr, 0.0018) for i in range(nb + 1)] for j in range(nr + 1)]
    down = [[bill_pt(i, j / nr, -0.0018) for i in range(nb + 1)] for j in range(nr + 1)]
    p.grid(up, GEAR, lambda i, j: bill_t.uv(i / nb, 0.5 + 0.5 * j / nr), flip=True)
    p.grid(down, GEAR, lambda i, j: bill_t.uv(i / nb, 0.5 - 0.5 * j / nr))
    rim = [up[-1], [bill_pt(i, 1.0, 0.0) + (bill_pt(i, 1.0, 0.0) - bases[i]).normalized() * 0.0016
                    for i in range(nb + 1)], down[-1]]
    p.grid(rim, GEAR, lambda i, j: k.sw("cap_edge"), flip=True)
    return p


def headband(k: Kit, crown_drape: Drape, drape: Drape) -> Part:
    """The comms headset's band from cup to cup over the cap's crown."""
    p = Part("headband")
    count = k.n(14, 8)
    path = []
    centre = Vector((0.0, 0.012, 1.60))
    for i in range(count):
        a = -math.pi / 2 + math.pi * i / (count - 1)  # from the right cup over the top to the left one
        d = Vector((math.sin(a), 0.0, math.cos(a)))
        q = crown_drape.toward(centre + d * 0.3, centre, 0.004)
        if q is None:
            q = drape.toward(centre + d * 0.3, centre, 0.004)
        path.append(q if q is not None else centre + d * 0.12)
    # Each end runs down into its cup's yoke.
    for i, side in ((0, -1.0), (count - 1, 1.0)):
        path[i] = Vector((side * 0.122, 0.012, 1.638))
    outs = [(q - centre).normalized() for q in path]
    outs[0], outs[-1] = Vector((-1.0, 0.0, 0.0)), Vector((1.0, 0.0, 0.0))
    p.sweep(path, outs, [(-0.013, 0.0), (0.013, 0.0), (0.011, 0.006), (-0.011, 0.006)], GEAR,
            uv=lambda i, j: k.sw("headset"))
    return p


# --------------------------------------------------------------------------------------------------- the heads

HIGH_CUT = Shell(hs.HIGH_CUT_SIZE, hs.HIGH_CUT_RIM, "shell_high", "high_shell", "high_trim")
FULL_CUT = Shell(hs.FULL_CUT_SIZE, hs.FULL_CUT_RIM, "shell_full", "full_cover", "full_trim")


def helmet_parts(k: Kit, sh: Shell, cover: bool) -> list:
    """The shell with its rails, shroud and loop panels; the team patch (high cut) or band (full cut)."""
    parts = [shell_body(k, sh)]
    if cover:
        rail_from, rail_to, lift = 62 * DEG, 128 * DEG, 9.0 * DEG
    else:
        rail_from, rail_to, lift = 57 * DEG, 136 * DEG, 8.0 * DEG
    if k.lv["straps"]:
        parts.append(rails(k, sh, rail_from, rail_to, lift))
    parts.append(shroud(k, sh))
    loop_t = k.tile("loop_full" if cover else "loop")
    on_shell = Drape(parts[:1])

    def from_above(front: float, top: float, y0: float, y1: float):
        """The band over the top: `front` half wide at y0, widening to `top` over its first third."""
        def ray(s: float, t: float):
            half = front + (top - front) * smoothstep(0.0, 0.35, t)
            x, y = -half + 2 * half * s, y0 + (y1 - y0) * t
            # Toward the shell's centre, so the panel stands off along the shell's normal down the back's slope.
            d = (Vector((x, y, 1.76)) - hs.SHELL_CENTRE).normalized()
            return hs.SHELL_CENTRE + d * 0.3, hs.SHELL_CENTRE
        return ray

    def from_side(a0: float, a1: float, z0: float, z1: float):
        def ray(s: float, t: float):
            az = a0 + (a1 - a0) * s
            z = z0 + (z1 - z0) * t
            # Toward the shell's centre (not level), so the panel follows the normal where the side rounds over.
            d = (Vector((0, 0, z)) + direction(az, 0.0) * 0.1 - hs.SHELL_CENTRE).normalized()
            return hs.SHELL_CENTRE + d * 0.3, hs.SHELL_CENTRE
        return ray

    nu, nv = k.n(6, 1), k.n(4, 1)
    uvl = lambda s, t: loop_t.uv(s, t)  # noqa: E731
    if k.lv["small"]:
        # The broad band from the front edge over to the back (photos 1-3), clear of the front vents, and a panel each
        # side from the band down to the rail behind the front vent.
        parts.append(drape_patch(k, on_shell, from_above(0.03, 0.058, -0.10, 0.12), 0.0019, GEAR, uvl, k.n(8, 1),
                                 k.n(11, 2), corner=0.06))
        for side in (1.0, -1.0):
            parts.append(drape_patch(k, on_shell, from_side(side * 40 * DEG, side * 104 * DEG, 1.672, 1.86), 0.0015,
                                     GEAR, uvl, k.n(8, 1), nv, corner=0.06))
    parts.append(shell_patch(k, sh, 138 * DEG, 222 * DEG, 1.5 * DEG, 13.5 * DEG, 0.0011, GEAR, uvl, k.n(10, 2), nv,
                             above_rim=True))
    team_t = k.tile("team_loop")
    if cover:
        # The team band: a wide elastic band round the cover above the rails, broken by the shroud.
        band = Part("team_band")
        n = k.n(30, 12)
        for a0, a1 in ((22 * DEG, 338 * DEG),):
            rows = []
            for el, off in ((34 * DEG, 0.0005), (34.3 * DEG, 0.0035), (44.7 * DEG, 0.0035), (45 * DEG, 0.0005)):
                rows.append([sh.point(a0 + (a1 - a0) * i / n, el, off) for i in range(n + 1)])
            band.grid(rows, TEAM, lambda i, j: team_t.uv(i / n, (0, 0.1, 0.9, 1)[j]), flip=True)
        parts.append(band)
    else:
        # The team patch on the back's loop band.
        parts.append(shell_patch(k, sh, 165 * DEG, 195 * DEG, 3.5 * DEG, 11.5 * DEG, 0.0034, TEAM,
                                 lambda s, t: team_t.uv(s, t), k.n(4, 1), k.n(2, 1), above_rim=True))
    return parts


def build_head(name: str, k: Kit, full: Drape) -> Part:
    """One whole head at level `k.level`. Everything that sits on the head is placed on `full` (the whole head at
    LOD0), so the gear lands in the same place at every level and never on a culled hole."""
    parts = []
    if name in ("Head_HighCut", "Head_FullCut"):
        sh = HIGH_CUT if name == "Head_HighCut" else FULL_CUT
        bare = head(k, keep=lambda q: not sh.covers(q), opening=True)
        parts.append(bare)
        parts.append(face.face_part(k, keep=lambda q: not sh.covers(q)))
        parts += helmet_parts(k, sh, cover=(sh is FULL_CUT))
        under = full
        if name == "Head_HighCut":
            m = mask(k, under, GLASSES)
            parts.append(m)
            parts.append(glasses(k, Drape([full_part(k), m])))
            parts.append(ear_defenders(k, sh, "defender", "cushion", True))
            if k.lv["small"]:
                parts.append(boom_mic(k, 1.0))
            if k.lv["straps"]:
                parts.append(chin_harness(k, Drape([full_part(k), m]), 64 * DEG, 122 * DEG, sh.rim_el(64 * DEG),
                                          sh.rim_el(122 * DEG), sh))
        else:
            # Under the full cut: the strap leaves low and runs round under the shell's edge.
            parts.append(goggles(k, Drape([full_part(k), parts[1]]), strap_z=1.565, strap_b=0.35))
            if k.lv["straps"]:
                parts.append(chin_harness(k, under, 70 * DEG, 114 * DEG, sh.rim_el(70 * DEG), sh.rim_el(114 * DEG),
                                          sh))
    elif name == "Head_Boonie":
        bare = head(k, keep=lambda q: q.z < BOONIE_BAND_Z + 0.006, opening=True)
        parts.append(bare)
        parts.append(face.face_part(k, keep=lambda q: q.z < BOONIE_BAND_Z + 0.006))
        hat = boonie(k)
        parts += hat
        sc = scarf(k, full)
        parts.append(sc)
        parts.append(glasses(k, Drape([full_part(k), sc])))
        if k.lv["small"]:
            parts.append(chin_cord(k, Drape([full_part(k), sc])))
    else:
        under_cap = lambda q: q.z < keyed(CAP_EDGE, abs(math.degrees(math.atan2(q.x, -q.y)))) + 0.006  # noqa: E731
        bare = head(k, keep=under_cap, opening=True)
        parts.append(bare)
        parts.append(face.face_part(k, keep=under_cap))
        under = full
        m = mask(k, under, GOGGLE)
        parts.append(m)
        cap_parts = cap(k, under)
        parts += cap_parts[:2]
        parts.append(goggles(k, Drape([full_part(k), m, cap_parts[2]]), strap_z=1.596))
        parts.append(ear_defenders(k, None, "headset", "cushion", False))
        parts.append(headband(k, Drape([cap_parts[2]]), under))
        if k.lv["small"]:
            parts.append(boom_mic(k, 1.0))
    whole = Part(name if k.level == 0 else "%s_LOD%d" % (name, k.level))
    for q in parts:
        whole.add(q)
    if os.environ.get("HEADWEAR_PARTS"):
        print("  ", name, k.level, ", ".join("%s %d" % (q.name, q.tris()) for q in parts))
    return whole


_FULL: dict = {}


def full_part(k: Kit) -> Part:
    """The whole head at LOD0 (made once), for placing things on."""
    if "part" not in _FULL:
        _FULL["part"] = head(Kit(k.atlas, 0))
    return _FULL["part"]


def materials(atlas: Atlas) -> dict:
    """Plain Blender materials for the export (the splice gives the game's ones their textures)."""
    out = {}
    for name in (GEAR, TEAM, LENS, face.FACE):
        m = bpy.data.materials.new(name)
        out[name] = m
    return out


def build_all(renders: str = "") -> dict:
    """Builds every head at every level; returns {node name: object} and the atlas."""
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    atlas = head_textures.paint()
    mats = materials(atlas)
    objects = {}
    for level in range(3):
        full = Drape([full_part(Kit(atlas, level))])
        for name in HEADS:
            k = Kit(atlas, level, density(name, level))
            part = build_head(name, k, full)
            ob = part.build(mats, sharp_angle=50.0, smooth_mats=(face.FACE,))
            objects[ob.name] = ob
            tri = part.tris()
            print("%-22s %6d triangles" % (ob.name, tri))
            over = "%s has %d triangles, over %d" % (ob.name, tri, BUDGET[level])
            assert tri <= BUDGET[level] or os.environ.get("HEADWEAR_PARTS"), over
    del renders
    return {"objects": objects, "atlas": atlas}


def main() -> None:
    import splice_heads

    tmp = os.path.join(bpy.app.tempdir or "/tmp", "headwear_build")
    os.makedirs(tmp, exist_ok=True)
    out = HUMAN
    if "--out" in sys.argv:
        out = sys.argv[sys.argv.index("--out") + 1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    made = build_all()
    heads_glb = os.path.join(tmp, "heads.glb")
    splice_heads.export_heads(heads_glb, made["objects"])
    images = head_textures.save(made["atlas"], os.path.join(tmp, "headwear"))
    splice_heads.splice(HUMAN, heads_glb, images, out)
    print("wrote", out)


if __name__ == "__main__":
    main()
