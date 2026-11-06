"""The human figure's knee and elbow pads (BL13, 2026-11-05): the `Kit_Pads` part of assets/models/characters/human.glb.

From the owner's knee pad photos (ref_images/clothes/knee_pads, the second photo traced: 81uLdVEli5L): a black
cordura cushion with a piped edge and a stitch line, an hourglass ("X") hard shell with a raised tongue at the top,
two slot vents, a raised dome over the knee cap and six eyelet rivets, and two elastic straps round the back of the
leg, each hooked by a triangle buckle over a stud on a tab at the pad's outer edge. No elbow photo was given: the
elbow pads are the same design at ELBOW_SCALE (the usual matching set). Unbranded.

How it is made: the pad is drawn in the photo's own pixels (PX_PER_M), wrapped round the limb by a radius field cast
from the limb's axis onto the figure's `Body` in its rest pose (smoothed, and never inside the body), so rerunning the
script on a rebuilt body refits the pads. Fine detail (rivets, vents, ridges, stitching, weave) is a 1024 normal map
painted in the same pixel space, so the UVs are the design's own coordinates. Each pad rides one bone rigidly (the
shin, the forearm), as a hard shell does: bent, its top stands off the joint instead of folding round it; the straps
and buckles, where they lie on the body, take the body's own weights there.

Out: three meshes, `Kit_Pads`, `Kit_Pads_LOD1`, `Kit_Pads_LOD2` (budget LOD_BUDGET), one material `Pads` with its
colour, normal and roughness-metal maps; spliced into human.glb by splice_part.py, and listed in human.json's parts.

Run with Python and the `bpy` module (pip install bpy==5.2.3), from the repository root:

    python -I tools/blender/figures/pads.py <repo root>
"""

import json
import math
import os
import sys
import tempfile

import bpy  # first: it brings bmesh and mathutils with it
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
sys.path.insert(0, os.path.join(ROOT, "tools/blender/figures"))
import splice_part  # noqa: E402

FIGURE = os.path.join(ROOT, "assets/models/characters/human.glb")
SIDECAR = os.path.join(ROOT, "assets/models/characters/human.json")
PART = "Kit_Pads"
MATERIAL = "Pads"
LOD_BUDGET = (3000, 1000, 300)  # triangles, all four pads; agreed with the body rebuild (BL10)

# The design space: the traced photo's pixels, x right (the pad's outer side), y down.
PX_PER_M = 5000.0  # the cushion is 1,175 px and 23.5 cm tall
CX, CY = 475.0, 597.0  # the cushion's centre
TURN_WEIGHT = 1300.0  # design px of outline a radian of turning counts as, when spacing the outline's points
OUTLINE_STEPS = 32  # spline samples per traced span, so the turning is measured finely
PAD_RHO = 0.11
FLAT = (0.092, 0.06)  # the pads' own curve round the limb (m): knee, elbow; flatter than the limb, so the edges stand
# off it as a stiff pad's do  # the pad's own curve in the photo (m): its x unrolled to arc length
ELBOW_SCALE = 0.72
ELBOW_DETAIL = 0.78  # the elbow pads' share of each level's outline points and strap segments

# Half outlines, top centre to bottom centre down the outer side, as traced (x from the centre line, y).
CUSHION = [(0, 0), (150, 10), (260, 30), (330, 58), (378, 100), (400, 160), (408, 260), (412, 420), (410, 560),
           (404, 700), (394, 820), (380, 920), (355, 1000), (315, 1065), (250, 1120), (160, 1160), (70, 1180),
           (0, 1185)]
SHELL = [(0, 163), (200, 163), (275, 168), (318, 185), (338, 215), (342, 260), (335, 320), (318, 390), (285, 460),
         (238, 520), (188, 568), (172, 600), (188, 634), (230, 668), (268, 700), (305, 760), (322, 820), (328, 880),
         (322, 940), (290, 1000), (215, 1068), (125, 1100), (0, 1110)]
TONGUE = [(0, 168), (150, 168), (146, 250), (139, 330), (129, 392), (106, 442), (77, 488), (45, 512), (18, 522),
          (0, 524)]  # a broad U from the shell's top edge
DOME = [(0, 680), (40, 686), (68, 704), (90, 734), (112, 774), (136, 822), (162, 870), (186, 914), (204, 948),
        (200, 990), (110, 1000), (0, 1000)]  # the arch over the knee cap, a rounded point, its legs out to beside the
# lower rivets; open below (its lower part fades out over DOME_FADE)
DOME_FADE = (905.0, 990.0)  # design y over which the arch's face fades into the plain shell
VENT = ((213, 340), (172, 468), 30.0, 12.0)  # a rounded oval: top centre, bottom centre, top and bottom half widths
RIVETS = [(0, 245), (240, 262), (232, 895), (0, 1050)]  # mirrored where x is not 0
RIVET_R = (15.0, 40.0)  # the hole's and the washer's radius (px)
DISH = ((6.0, 7.0), (4.0, 5.0))  # the recessed ring round a washer: its middle past the washer's edge and half width
# (px); the second for the upper side eyelets, whose ring stops short of the vents as in the photo
STRAPS = (250.0, 820.0)  # the straps' centre lines (y)
STRAP_WIDTH = 0.025
PAD_BEND = (0.2, 0.0)  # the share of the bone above the joint the cushion's soft top takes (knee, elbow)
BEND_BAND = (157.0, 0.0)  # design y over which that share ramps in: from just above the shell's top edge (163) to the
# cushion's top, so the moulded shell stays rigid on the shin
STRAP_HUG = 0.03  # m round the limb over which a strap leaves the pad's surface for the body's  # m, at the knee's scale

# Heights off the limb (mm, at the knee's scale): cushion, shell, straps, buckles.
CLEAR = 2.0
CUSHION_RINGS = [(-3.0, 0.0, -38.0), (-8.0, 5.0, -22.0), (3.0, 9.0, -4.0), (20.0, 7.5, 18.0)]  # a rolled edge
UNDER_SHELL = (6.0, 9.0, 0.55)  # the padded face's ring round the shell: px outside its edge, height; with no shell
# (the far level), a ring at this share of the outline instead
CUSHION_TOP = 13.0
SHELL_RINGS = [(0.0, 8.5, -26.0), (1.5, 15.0, -12.0), (11.0, 17.6, 11.0), (0.55, 19.2, None)]
SHELL_TOP = 20.0
DOME_RISE = (16.0, 10.0)  # the pad's own bulge at its middle height (knee, elbow): cupped round the joint, as the
# photos' side views show
LIFT_TURN = 0.25  # how far a height off the pad's face turns with it round the limb (0, straight forward; 1, radial)
STRAP_H = 2.0  # the webbing is one face (its edges, 2 mm, are in the normal map)
FIELD_STEP = (math.radians(2.0), 0.003)
FIELD_SMOOTH = (4.0, 3.0)  # gaussian sigma in field samples (round, along)
STRAP_SMOOTH = (1.5, 1.0)  # the straps' field: only lightly smoothed, not spread, so they lie on the sleeve
FIELD_SPREAD = 4  # max filter half width (samples, both ways), so the pad bridges the trousers' folds

# Colours (sRGB 0-255) and roughness, metal.
COL_SHELL = (50, 51, 54)
COL_CUSHION = (29, 29, 30)
COL_THREAD = (44, 44, 45)
COL_RIVET = (40, 40, 42)
COL_HOLE = (12, 12, 12)
COL_VENT = (20, 20, 21)
COL_STRAP = (30, 30, 31)
ROUGH = {"shell": 0.48, "cushion": 0.9, "rivet": 0.4, "dome": 0.56, "strap": 0.85}
METAL_RIVET = 0.5

TEX = 1024
ATLAS_SCALE = 0.6  # texels per design pixel
CUSHION_RECT = (25.0, -45.0, 925.0, 1240.0)  # design px: the cushion island, with room for the piping's UVs
SHELL_RECT = (95.0, 120.0, 855.0, 1150.0)
CUSHION_AT = (0, 0)
SHELL_AT = (548, 0)
STRAP_AT = (0, 790, 1024, 850)  # atlas rows of the webbing
BUCKLE_AT = (560, 650, 680, 770)  # the buckle plate's picture (rim, window, strap over the bar, stud)
BUCKLE_PX_PER_MM = 2.2

# Detail by level: outline points (cushion, shell), strap segments, buckles.
LEVELS = [
    {"cushion": 34, "shell": 44, "strap": 20, "buckles": True, "rings": "full"},
    {"cushion": 20, "shell": 22, "strap": 10, "buckles": False, "rings": "lod1"},
    {"cushion": 14, "shell": 0, "strap": 0, "buckles": False, "rings": "lod2"},
]


# --- design space -----------------------------------------------------------------------------------------------------

def catmull(points: list, steps: int = 8) -> list:
    out = []
    n = len(points)
    for i in range(n - 1):
        p0 = points[max(i - 1, 0)]
        p1, p2 = points[i], points[i + 1]
        p3 = points[min(i + 2, n - 1)]
        for s in range(steps):
            t = s / steps
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t * t
                                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t ** 3) for k in range(2)))
    out.append(points[-1])
    return out


def outline(half: list, count: int) -> list:
    """The closed outline in design px, `count` points (even) evenly along it, from the top centre down the outer side."""
    dense = catmull([(CX + x, y) for x, y in half], OUTLINE_STEPS)
    # Points spaced by length and turning, so the corners get more of them than the straight runs.
    lengths = [0.0]
    for i, (a, b) in enumerate(zip(dense, dense[1:])):
        turn = 0.0
        if 0 < i < len(dense) - 2:
            c = dense[i + 2]
            turn = abs(math.atan2(c[1] - b[1], c[0] - b[0]) - math.atan2(b[1] - a[1], b[0] - a[0]))
            turn = min(turn, math.tau - turn)
        lengths.append(lengths[-1] + math.dist(a, b) + TURN_WEIGHT * turn)
    half_count = count // 2
    right = []
    for i in range(half_count + 1):
        target = lengths[-1] * i / half_count
        j = max(k for k in range(len(lengths)) if lengths[k] <= target + 1e-9)
        j = min(j, len(dense) - 2)
        t = (target - lengths[j]) / max(lengths[j + 1] - lengths[j], 1e-9)
        right.append((dense[j][0] + (dense[j + 1][0] - dense[j][0]) * t, dense[j][1] + (dense[j + 1][1] - dense[j][1]) * t))
    left = [(2 * CX - x, y) for x, y in reversed(right[1:-1])]
    return right + left


def normals2d(points: list) -> list:
    """Each point's outward unit normal (design px)."""
    n = len(points)
    cx = sum(p[0] for p in points) / n
    cy = sum(p[1] for p in points) / n
    out = []
    for i in range(n):
        a, b = points[i - 1], points[(i + 1) % n]
        tx, ty = b[0] - a[0], b[1] - a[1]
        length = math.hypot(tx, ty) or 1.0
        nx, ny = ty / length, -tx / length
        if nx * (points[i][0] - cx) + ny * (points[i][1] - cy) < 0:
            nx, ny = -nx, -ny
        out.append((nx, ny))
    return out


def design_m(x: float, y: float) -> tuple:
    """Design px to the pad's unrolled metres (u along the round, toward the outer side; v up), at the knee's scale."""
    xm = (x - CX) / PX_PER_M
    return PAD_RHO * math.asin(max(-0.999, min(0.999, xm / PAD_RHO))), (CY - y) / PX_PER_M


def atlas_uv(x: float, y: float, island: str) -> tuple:
    rect, at = (CUSHION_RECT, CUSHION_AT) if island == "cushion" else (SHELL_RECT, SHELL_AT)
    px = at[0] + (x - rect[0]) * ATLAS_SCALE
    py = at[1] + (y - rect[1]) * ATLAS_SCALE
    return px / TEX, 1.0 - py / TEX


# --- the limb's surface -----------------------------------------------------------------------------------------------

class Fit:
    """One pad's place: a centre on the limb's axis, the axis (up), the pad's facing, its outer side, and the body's
    radius round the axis sampled on a grid (smoothed, never inside the body)."""

    def __init__(self, bvh: BVHTree, bone: str, centre: Vector, axis: Vector, facing: Vector, outer: Vector,
                 scale: float, flat: float, dome: float, reach: float) -> None:
        self.bone, self.flat = bone, flat
        self.centre, self.axis, self.scale, self.dome = centre, axis.normalized(), scale, dome
        self.facing = (facing - facing.dot(self.axis) * self.axis).normalized()
        side = outer - outer.dot(self.axis) * self.axis - outer.dot(self.facing) * self.facing
        self.outer = side.normalized()
        self.mirrored = self.facing.cross(self.outer).dot(self.axis) < 0.0
        self.angles = np.arange(-math.pi, math.pi, FIELD_STEP[0])
        self.heights = np.arange(-reach, reach + 1e-9, FIELD_STEP[1])
        field = np.full((len(self.heights), len(self.angles)), np.nan)
        for i, v in enumerate(self.heights):
            origin = self.centre + self.axis * float(v)
            for j, a in enumerate(self.angles):
                hit = bvh.ray_cast(origin, self.direction(float(a)), 0.25)
                if hit[0] is not None:
                    field[i, j] = hit[3]
        for i in range(len(self.heights)):  # a missed ray takes its row's neighbours
            row = field[i]
            if np.isnan(row).all():
                field[i] = np.nanmean(field)
            elif np.isnan(row).any():
                good = ~np.isnan(row)
                idx = np.arange(len(row))
                field[i] = np.interp(idx, idx[good], row[good], period=len(row))
        spread = field.copy()
        rows = np.arange(field.shape[0])
        for k in range(1, FIELD_SPREAD + 1):
            spread = np.maximum(spread, np.maximum(np.roll(field, k, 1), np.roll(field, -k, 1)))
        wide = spread.copy()
        for k in range(1, FIELD_SPREAD + 1):
            wide = np.maximum(wide, np.maximum(spread[np.clip(rows - k, 0, rows[-1])], spread[np.clip(rows + k, 0, rows[-1])]))
        spread = wide
        smooth = blur_wrap(spread, FIELD_SMOOTH)
        self.field = np.maximum(smooth, field)
        self.snug = np.maximum(blur_wrap(field, STRAP_SMOOTH), field)  # the body itself, for the straps lying on it
        self.front = self.radius(0.0, 0.0) + CLEAR * 0.001

    def direction(self, angle: float) -> Vector:
        return self.facing * math.cos(angle) + self.outer * math.sin(angle)

    def radius(self, angle: float, v: float, snug: bool = False) -> float:
        a = (angle + math.pi) / FIELD_STEP[0]
        h = (v - self.heights[0]) / FIELD_STEP[1]
        h = min(max(h, 0.0), len(self.heights) - 1.001)
        i, fh = int(h), h - int(h)
        j0 = int(math.floor(a)) % len(self.angles)
        j1 = (j0 + 1) % len(self.angles)
        fa = a - math.floor(a)
        f = self.snug if snug else self.field
        return float((f[i, j0] * (1 - fa) + f[i, j1] * fa) * (1 - fh) + (f[i + 1, j0] * (1 - fa) + f[i + 1, j1] * fa) * fh)

    def point(self, u: float, v: float, h_mm: float, bulge: bool = True, hug: float = 0.0,
              radial: bool = False) -> Vector:
        """The point `u` round and `v` up (knee-scale metres, scaled here), `h_mm` off the pad's surface: the pad's own
        curve (FLAT), never inside the body; `hug` (0-1) eases it onto the body itself, for the straps."""
        u, v = u * self.scale, v * self.scale
        rise = self.dome * max(0.0, 1.0 - (v / (0.1175 * self.scale)) ** 2) * (1.0 - hug) if bulge else 0.0
        front = self.radius(0.0, v) + CLEAR * 0.001
        turn = u / self.flat
        across = self.facing * (front - self.flat + self.flat * math.cos(turn)) + self.outer * (self.flat * math.sin(turn))
        pad_angle = math.atan2(across.dot(self.outer), across.dot(self.facing))
        pad_r = max(across.length, self.radius(pad_angle, v) + CLEAR * 0.001)
        body_angle = u / front
        body_r = self.radius(body_angle, v, snug=True) + CLEAR * 0.001
        angle = pad_angle + (body_angle - pad_angle) * hug
        r = pad_r + (body_r - pad_r) * hug
        # Heights stand off the pad's face mostly forward, as a stiff shell's do (radially, the shell's rim would spread
        # wider than the cushion it sits on); a strap lying on the body stands off it radially.
        lift = self.direction(angle if radial else angle * (LIFT_TURN + (1.0 - LIFT_TURN) * hug))
        return self.centre + self.axis * v + self.direction(angle) * r + lift * ((h_mm * self.scale + rise) * 0.001)


def blur_wrap(field: np.ndarray, sigma: tuple) -> np.ndarray:
    out = field
    for axis, s in ((1, sigma[0]), (0, sigma[1])):
        radius = int(math.ceil(s * 3))
        kernel = np.exp(-0.5 * (np.arange(-radius, radius + 1) / s) ** 2)
        kernel /= kernel.sum()
        acc = np.zeros_like(out)
        for k, w in zip(range(-radius, radius + 1), kernel):
            if axis == 1:
                acc += w * np.roll(out, k, 1)
            else:
                idx = np.clip(np.arange(out.shape[0]) - k, 0, out.shape[0] - 1)
                acc += w * out[idx]
        out = acc
    return out


# --- mesh building -----------------------------------------------------------------------------------------------------

class Sheets:
    """Vertices, faces and their UVs, built up sheet by sheet."""

    def __init__(self) -> None:
        self.verts = []
        self.hugs = []  # per vertex: how far it lies on the body (0, the pad's rigid bone; 1, the body's own weights)
        self.faces = []
        self.uvs = []

    def sheet(self, rings: list, ring_uvs: list, centre=None, centre_uv=None, outward: Vector = None,
              closed: bool = True, hugs: list = None, centre_hug: float = 0.0) -> None:
        """Quads between consecutive rings (each a list of points), a fan to `centre` if given; faced along
        `outward` (tested on the last band)."""
        base = len(self.verts)
        n = len(rings[0])
        for k, ring in enumerate(rings):
            self.verts.extend(ring)
            self.hugs.extend(hugs[k] if hugs is not None else [0.0] * len(ring))
        faces, uvs = [], []
        span = n if closed else n - 1
        for k in range(len(rings) - 1):
            for i in range(span):
                j = (i + 1) % n
                a, b = base + k * n + i, base + k * n + j
                c, d = base + (k + 1) * n + j, base + (k + 1) * n + i
                faces.append((a, b, c, d))
                uvs.append((ring_uvs[k][i], ring_uvs[k][j], ring_uvs[k + 1][j], ring_uvs[k + 1][i]))
        if centre is not None:
            self.verts.append(centre)
            self.hugs.append(centre_hug)
            ci = len(self.verts) - 1
            last = base + (len(rings) - 1) * n
            for i in range(n):
                j = (i + 1) % n
                faces.append((last + i, last + j, ci))
                uvs.append((ring_uvs[-1][i], ring_uvs[-1][j], centre_uv))
        if outward is not None and faces:
            probe = faces[-1]
            pts = [self.verts[i] for i in probe]
            normal = (pts[1] - pts[0]).cross(pts[2] - pts[0])
            if normal.dot(outward) < 0.0:
                faces = [tuple(reversed(f)) for f in faces]
                uvs = [tuple(reversed(u)) for u in uvs]
        self.faces.extend(faces)
        self.uvs.extend(uvs)


def offset_ring(points: list, norms: list, inset: float) -> list:
    return [(p[0] - n[0] * inset, p[1] - n[1] * inset) for p, n in zip(points, norms)]


def radial(points: list, edge: list, outside: float) -> list:
    """For each of `points`, where the ray from their centre to it crosses `edge` (a closed outline), `outside` px
    further along: so the two rings' points pair up by direction."""
    cx = sum(p[0] for p in points) / len(points)
    cy = sum(p[1] for p in points) / len(points)
    out = []
    for px, py in points:
        dx, dy = px - cx, py - cy
        best = 0.0
        for (ax, ay), (bx, by) in zip(edge, edge[1:] + edge[:1]):
            ex, ey = bx - ax, by - ay
            den = dx * ey - dy * ex
            if abs(den) < 1e-12:
                continue
            t = ((ax - cx) * ey - (ay - cy) * ex) / den
            s = ((ax - cx) * dy - (ay - cy) * dx) / den
            if 0.0 <= s <= 1.0 and t > best:
                best = t
        length = math.hypot(dx, dy) or 1.0
        t = best + outside / length
        out.append((cx + dx * t, cy + dy * t))
    return out


def scale_ring(points: list, s: float) -> list:
    cx = sum(p[0] for p in points) / len(points)
    cy = sum(p[1] for p in points) / len(points)
    return [(cx + (p[0] - cx) * s, cy + (p[1] - cy) * s) for p in points]


def pad(sheets: Sheets, fit: Fit, level: dict) -> None:
    """One pad: cushion, shell, straps, buckles."""
    out_dir = fit.facing

    def to3d(ring: list, h: float) -> list:
        return [fit.point(*design_m(x, y), h) for x, y in ring]

    # The cushion: its back, the piped edge, the padded face.
    detail = 1.0 if fit.scale == 1.0 else ELBOW_DETAIL
    count = lambda key: 2 * max(2, round(level[key] * detail / 2))
    pts = outline(CUSHION, count("cushion"))
    nrm = normals2d(pts)
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    spec = CUSHION_RINGS if level["rings"] == "full" else [CUSHION_RINGS[0], CUSHION_RINGS[2]]
    rings, ring_uvs = [], []
    for inset, h, uv_inset in spec:
        ring = offset_ring(pts, nrm, inset)
        rings.append(to3d(ring, h))
        ring_uvs.append([atlas_uv(x, y, "cushion") for x, y in offset_ring(pts, nrm, uv_inset)])
    if level["shell"]:
        # The padded face's last ring runs just outside the shell's edge, so the face between them follows the limb
        # (a fan from the edge would cut a chord through it); inside it the cushion is hidden.
        ring = radial(pts, outline(SHELL, 240), UNDER_SHELL[0])
        rings.append(to3d(ring, UNDER_SHELL[1]))
        ring_uvs.append([atlas_uv(x, y, "cushion") for x, y in ring])
    else:
        ring = scale_ring(pts, UNDER_SHELL[2])
        rings.append(to3d(ring, UNDER_SHELL[1]))
        ring_uvs.append([atlas_uv(x, y, "cushion") for x, y in ring])
    sheets.sheet(rings, ring_uvs, fit.point(*design_m(cx, cy), CUSHION_TOP), atlas_uv(cx, cy, "cushion"), out_dir)
    back = [rings[0]]
    sheets.sheet(back, [ring_uvs[0]], fit.point(*design_m(cx, cy), 0.0, bulge=False), atlas_uv(cx, cy, "cushion"),
                 -out_dir)
    if level["shell"]:
        pts = outline(SHELL, count("shell"))
        nrm = normals2d(pts)
        sx = sum(p[0] for p in pts) / len(pts)
        sy = sum(p[1] for p in pts) / len(pts)
        spec = SHELL_RINGS if level["rings"] == "full" else SHELL_RINGS[:3]
        rings, ring_uvs = [], []
        for inset, h, uv_inset in spec:
            ring = offset_ring(pts, nrm, inset) if uv_inset is not None else scale_ring(pts, inset)
            uv_ring = offset_ring(pts, nrm, uv_inset) if uv_inset is not None else ring
            rings.append(to3d(ring, h))
            ring_uvs.append([atlas_uv(x, y, "shell") for x, y in uv_ring])
        sheets.sheet(rings, ring_uvs, fit.point(*design_m(sx, sy), SHELL_TOP), atlas_uv(sx, sy, "shell"), out_dir)
    if level["strap"]:
        for y in STRAPS:
            strap(sheets, fit, y, max(2, round(level["strap"] * detail)), level["buckles"])


def strap(sheets: Sheets, fit: Fit, y: float, segments: int, buckle_too: bool) -> None:
    """A strap from under the cushion's inner edge round the back of the limb to the buckle at its outer edge."""
    pts = outline(CUSHION, 64)
    edge = max(p[0] for p in pts if abs(p[1] - y) < 40) - CX
    u_edge, v = design_m(CX + edge, y)
    buckle_u = u_edge + BUCKLE_AT_EDGE + BUCKLE_LENGTH * 0.45  # its apex over the cushion's edge, the stud on the edge
    u_out = buckle_u + BUCKLE_LENGTH * 0.55 - 0.004  # loops round the buckle's far bar, under it
    round_m = 2 * math.pi * fit.front / fit.scale  # once round the limb, in design metres
    u_in = u_out
    u_end = -u_edge + 0.012 + round_m  # round the back, ending under the cushion's inner edge
    half = STRAP_WIDTH * 0.5
    section = [(half, STRAP_H), (-half, STRAP_H)]
    rings, ring_uvs, ring_hugs = [], [], []
    total = u_end - u_in
    u0, u1, v0, v1 = STRAP_AT[0] / TEX, STRAP_AT[2] / TEX, 1 - STRAP_AT[3] / TEX, 1 - STRAP_AT[1] / TEX
    # Three short segments at each end, where it leaves the buckle and goes under the cushion, the rest evenly round.
    ease = min(STRAP_HUG, total * 0.2)
    rest = max(1, segments - 6)
    us = [u_in + ease * k / 3 for k in range(3)]
    us += [u_in + ease + (total - 2 * ease) * k / rest for k in range(rest + 1)]
    us += [u_end - ease + ease * k / 3 for k in range(1, 4)]
    for u in us:
        t = (u - u_in) / total
        hug = hug_at(u, u_edge, round_m)
        u = (u + round_m * 0.5) % round_m - round_m * 0.5  # the pad's curve is laid out from the front, either way
        rings.append([fit.point(u, v + dv, h, bulge=False, hug=hug, radial=True) for dv, h in section])
        ring_hugs.append(hug)
        ring_uvs.append([(u0 + (u1 - u0) * t, v0 + (v1 - v0) * k) for k in range(2)])
    # Rings run along the strap; the sheet wants rings round it, so the cross-sections are transposed.
    cross = [[ring[k] for ring in rings] for k in range(2)]
    cross_uvs = [[ring[k] for ring in ring_uvs] for k in range(2)]
    mid_u = u_in + total * 0.5
    outward = fit.direction(mid_u * fit.scale / fit.front)
    sheets.sheet(cross, cross_uvs, closed=False, outward=outward, hugs=[ring_hugs] * 2)
    if buckle_too:
        buckle(sheets, fit, buckle_u, v, u_edge)


def hug_at(u: float, u_edge: float, round_m: float) -> float:
    """How far a strap at `u` lies on the body rather than the pad: none under the cushion or the buckle (which the pad
    carries), all of it a STRAP_HUG past the buckle's far bar."""
    wrapped = (u + round_m * 0.5) % round_m - round_m * 0.5
    t = min(max((abs(wrapped) - u_edge - BUCKLE_AT_EDGE - BUCKLE_LENGTH + 0.004) / STRAP_HUG, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


BUCKLE_LENGTH, BUCKLE_WIDTH, BUCKLE_CHAMFER = 0.034, 0.042, 0.006
BUCKLE_AT_EDGE = -0.010  # the apex's place from the cushion's edge (design m): the stud 7.5 mm in sits on the edge
BUCKLE_H = (3.0, 5.0)  # the plate's underside and face over the pad (mm)
STUD_AT = 0.0075  # from the apex (m)
STUD = [(2.2, 0.0), (4.0, 1.8), (2.6, 3.2)]  # the mushroom stud's rings over the plate's face: radius, height (mm)
STUD_TOP = 3.6
STUD_SIDES = 6


def buckle_outline() -> list:
    """The buckle plate's rounded triangle (m), apex at 0, pointing to the pad (-u), base across at BUCKLE_LENGTH."""
    tri = [(0.0, 0.0), (BUCKLE_LENGTH, BUCKLE_WIDTH * 0.5), (BUCKLE_LENGTH, -BUCKLE_WIDTH * 0.5)]
    out = []
    for i, p in enumerate(tri):
        for q in (tri[i - 1], tri[(i + 1) % 3]):
            d = math.dist(p, q)
            out.append((p[0] + (q[0] - p[0]) * BUCKLE_CHAMFER / d, p[1] + (q[1] - p[1]) * BUCKLE_CHAMFER / d))
    return out


def buckle_uv(x: float, y: float) -> tuple:
    px = BUCKLE_AT[0] + 8 + x * 1000.0 * BUCKLE_PX_PER_MM
    py = (BUCKLE_AT[1] + BUCKLE_AT[3]) * 0.5 - y * 1000.0 * BUCKLE_PX_PER_MM
    return px / TEX, 1.0 - py / TEX


def buckle(sheets: Sheets, fit: Fit, u: float, v: float, u_edge: float) -> None:
    """The triangle buckle: a solid plate, apex over the cushion's edge, hooked over the stud sewn there; the pad
    carries it (it rides the pad's bone). The rim, window and the strap round its far bar are its picture (BUCKLE_AT);
    the stud is modelled."""
    apex = u - BUCKLE_LENGTH * 0.45
    plate = buckle_outline()
    cx = sum(p[0] for p in plate) / len(plate)
    top = [(cx + (x - cx) * 0.9, y * 0.9) for x, y in plate]
    rings = [[fit.point(apex + x, v + y, h, bulge=False) for x, y in ring] for ring, h in ((plate, BUCKLE_H[0]), (top, BUCKLE_H[1]))]
    uvs = [[buckle_uv(x, y) for x, y in plate], [buckle_uv(x, y) for x, y in top]]
    centre = fit.point(apex + cx, v, BUCKLE_H[1] + 0.2, bulge=False)
    outward = fit.direction(u * fit.scale / fit.front)
    sheets.sheet(rings, uvs, centre, buckle_uv(cx, 0.0), outward)
    ring_at = lambda r, h: [fit.point(apex + STUD_AT + r * 0.001 * math.cos(a), v + r * 0.001 * math.sin(a),
                                      BUCKLE_H[1] + h, bulge=False)
                            for a in np.linspace(0.0, math.tau, STUD_SIDES, endpoint=False)]
    uv_at = lambda r: [buckle_uv(STUD_AT + r * 0.001 * math.cos(a), r * 0.001 * math.sin(a))
                       for a in np.linspace(0.0, math.tau, STUD_SIDES, endpoint=False)]
    sheets.sheet([ring_at(r, h) for r, h in STUD], [uv_at(r) for r, h in STUD],
                 fit.point(apex + STUD_AT, v, BUCKLE_H[1] + STUD_TOP, bulge=False), buckle_uv(STUD_AT, 0.0), outward)


# --- textures ----------------------------------------------------------------------------------------------------------

def raster(polys: list, shape: tuple, transform) -> np.ndarray:
    """A mask (0-1) of `polys` (design px) on the atlas, 4x supersampled."""
    from PIL import Image, ImageDraw
    ss = 4
    img = Image.new("L", (shape[1] * ss, shape[0] * ss), 0)
    draw = ImageDraw.Draw(img)
    for poly in polys:
        draw.polygon([tuple(c * ss for c in transform(*p)) for p in poly], fill=255)
    img = img.resize((shape[1], shape[0]), Image.BOX)
    return np.asarray(img, dtype=np.float32) / 255.0


def blur(a: np.ndarray, sigma: float) -> np.ndarray:
    if sigma <= 0:
        return a
    radius = int(math.ceil(sigma * 3))
    k = np.exp(-0.5 * (np.arange(-radius, radius + 1) / sigma) ** 2)
    k /= k.sum()
    out = np.apply_along_axis(lambda r: np.convolve(np.pad(r, radius, mode="edge"), k, "valid"), 1, a)
    return np.apply_along_axis(lambda c: np.convolve(np.pad(c, radius, mode="edge"), k, "valid"), 0, out)


def mirror(half: list) -> list:
    full = [(CX + x, y) for x, y in half]
    return full + [(2 * CX - x, y) for x, y in reversed(full[1:-1])]


def textures(folder: str) -> dict:
    """Paints the atlas: colour (sRGB), normal (OpenGL), roughness-metal; returns the PNG paths."""
    from PIL import Image
    h = np.zeros((TEX, TEX), np.float32)  # mm
    col = np.zeros((TEX, TEX, 3), np.float32)
    rough = np.full((TEX, TEX), ROUGH["cushion"], np.float32)
    metal = np.zeros((TEX, TEX), np.float32)
    mm_per_texel = 1000.0 / PX_PER_M / ATLAS_SCALE

    def put(mask: np.ndarray, colour: tuple, r: float, m: float = 0.0) -> None:
        col[:] = col * (1 - mask[..., None]) + np.array(colour, np.float32)[None, None] * mask[..., None]
        rough[:] = rough * (1 - mask) + r * mask
        metal[:] = metal * (1 - mask) + m * mask

    # Cushion island.
    tc = lambda x, y: ((CUSHION_AT[0] + (x - CUSHION_RECT[0]) * ATLAS_SCALE), (CUSHION_AT[1] + (y - CUSHION_RECT[1]) * ATLAS_SCALE))
    island = raster([[(CUSHION_RECT[0], CUSHION_RECT[1]), (CUSHION_RECT[2], CUSHION_RECT[1]),
                      (CUSHION_RECT[2], CUSHION_RECT[3]), (CUSHION_RECT[0], CUSHION_RECT[3])]], h.shape, tc)
    put(island, COL_CUSHION, ROUGH["cushion"])
    yy, xx = np.mgrid[0:TEX, 0:TEX].astype(np.float32)
    weave = 0.05 * np.sin(xx * mm_per_texel * 2 * math.pi / 1.4) * np.sin(yy * mm_per_texel * 2 * math.pi / 1.4)
    h += weave * island
    pts = outline(CUSHION, 240)
    nrm = normals2d(pts)
    seam_out = raster([offset_ring(pts, nrm, 24)], h.shape, tc)
    seam_in = raster([offset_ring(pts, nrm, 32)], h.shape, tc)
    seam = np.clip(seam_out - seam_in, 0, 1)
    along = np.arctan2(yy - tc(CX, CY)[1], xx - tc(CX, CY)[0])
    dash = (np.sin(along * 260) > -0.2).astype(np.float32)
    h += blur(seam, 0.6) * (-0.25 + 0.4 * dash)
    put(seam * dash * 0.8, COL_THREAD, 0.8)
    # Shell island.
    ts = lambda x, y: ((SHELL_AT[0] + (x - SHELL_RECT[0]) * ATLAS_SCALE), (SHELL_AT[1] + (y - SHELL_RECT[1]) * ATLAS_SCALE))
    island = raster([[(SHELL_RECT[0], SHELL_RECT[1]), (SHELL_RECT[2], SHELL_RECT[1]),
                      (SHELL_RECT[2], SHELL_RECT[3]), (SHELL_RECT[0], SHELL_RECT[3])]], h.shape, ts)
    put(island, COL_SHELL, ROUGH["shell"])
    h *= 1 - island
    pts = outline(SHELL, 240)
    nrm = normals2d(pts)
    rim = np.clip(raster([offset_ring(pts, nrm, 13)], h.shape, ts) - raster([offset_ring(pts, nrm, 21)], h.shape, ts), 0, 1)
    h += blur(rim, 1.2) * 0.45
    tongue = raster([catmull(mirror(TONGUE) + mirror(TONGUE)[:1])], h.shape, ts)
    h += blur(tongue, 2.5) * 1.1
    dome = raster([catmull(mirror(DOME) + mirror(DOME)[:1])], h.shape, ts)
    design_y = SHELL_RECT[1] + (yy - SHELL_AT[1]) / ATLAS_SCALE
    dome *= np.clip((DOME_FADE[1] - design_y) / (DOME_FADE[1] - DOME_FADE[0]), 0.0, 1.0)
    h += blur(dome, 2.5) * 1.6
    # The arch's face is stippled matt, as moulded grip is; the rest of the shell is smooth.
    stipple = np.random.default_rng(13).random(h.shape).astype(np.float32)
    grain = np.clip(dome + tongue, 0, 1)
    h += blur(stipple, 0.7) * 0.2 * grain
    put(grain * 0.9, COL_SHELL, ROUGH["dome"])
    for side in (1, -1):
        (tx, ty), (bx, by), tw, bw = VENT
        poly = []
        for a in np.linspace(math.pi, 0, 10):
            poly.append((CX + side * (tx + tw * math.cos(a)), ty - tw * math.sin(a)))
        for a in np.linspace(0, -math.pi, 10):
            poly.append((CX + side * (bx + bw * math.cos(a)), by - bw * math.sin(a)))
        vent = raster([poly], h.shape, ts)
        h += blur(vent, 1.0) * -3.0
        put(blur(vent, 0.6), COL_VENT, 0.92)
    for rx, ry in RIVETS:
        for side in ((1, -1) if rx else (1,)):
            px, py = ts(CX + side * rx, ry)
            d = np.hypot(xx - px, yy - py) / ATLAS_SCALE  # design px
            washer = np.clip((RIVET_R[1] - d) / 2.0, 0, 1)
            hole = np.clip((RIVET_R[0] - d) / 1.5, 0, 1)
            crown = np.clip(1 - ((d - (RIVET_R[0] + RIVET_R[1]) * 0.5) / ((RIVET_R[1] - RIVET_R[0]) * 0.5)) ** 2, 0, 1)
            mid, width = DISH[1 if rx and ry < CY else 0]
            dish = np.clip(1 - ((d - RIVET_R[1] - mid) / width) ** 2, 0, 1) * (d > RIVET_R[1])
            h += washer * (0.3 + 0.5 * crown) - hole * 2.0 - dish * 0.6
            put(washer, COL_RIVET, ROUGH["rivet"], METAL_RIVET)
            put(hole, COL_HOLE, 0.9)
    # Webbing and plastic patches.
    sx0, sy0, sx1, sy1 = STRAP_AT
    strap_mask = ((xx >= sx0) & (xx < sx1) & (yy >= sy0) & (yy < sy1)).astype(np.float32)
    put(strap_mask, COL_STRAP, ROUGH["strap"])
    across = (yy - sy0) / max(sy1 - sy0, 1)
    h = h * (1 - strap_mask) + strap_mask * (0.12 * np.sin(across * 2 * math.pi * 14) - 0.4 * (np.abs(across - 0.5) * 2) ** 6)
    # The buckle plate: a raised rim round a window the strap shows through, the strap round the far bar, the stud.
    bx0, by0, bx1, by1 = BUCKLE_AT
    patch = ((xx >= bx0) & (xx < bx1) & (yy >= by0) & (yy < by1)).astype(np.float32)
    put(patch, COL_SHELL, ROUGH["shell"])
    h *= 1 - patch
    to_px = lambda x, y: (buckle_uv(x, y)[0] * TEX, (1.0 - buckle_uv(x, y)[1]) * TEX)
    plate = buckle_outline()
    cx = sum(p[0] for p in plate) / len(plate)
    inner = [(cx + (x - cx) * 0.48, y * 0.48) for x, y in plate]
    plate_mask = raster([plate], h.shape, to_px)
    window = raster([inner], h.shape, to_px)
    h += blur(plate_mask - raster([[(cx + (x - cx) * 0.86, y * 0.86) for x, y in plate]], h.shape, to_px), 0.8) * 0.5
    h += blur(window, 0.8) * -1.4
    put(window, COL_STRAP, ROUGH["strap"])
    half = STRAP_WIDTH * 0.5
    bar = raster([[(BUCKLE_LENGTH - 0.007, half), (BUCKLE_LENGTH + 0.004, half), (BUCKLE_LENGTH + 0.004, -half),
                   (BUCKLE_LENGTH - 0.007, -half)]], h.shape, to_px)
    h += blur(bar, 0.8) * 0.9
    put(bar, COL_STRAP, ROUGH["strap"])
    sx, sy = to_px(STUD_AT, 0.0)
    d = np.hypot(xx - sx, yy - sy) / BUCKLE_PX_PER_MM  # mm
    stud = np.clip(4.2 - d, 0, 1)
    h += stud * np.sqrt(np.clip(1 - (d / 4.2) ** 2, 0, 1)) * 2.0
    put(stud, COL_RIVET, ROUGH["rivet"], METAL_RIVET * 0.5)
    # Cavities darken the colour a little (baked occlusion).
    cavity = np.clip(blur(h, 4.0) - h, 0, 2.0) * (1 - 0.8 * grain)
    col *= (1 - 0.25 * cavity)[..., None]
    # Normals from the heights (OpenGL: +Y is up the texture).
    gy, gx = np.gradient(h, mm_per_texel)
    n = np.dstack((-gx, gy, np.ones_like(h)))
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    paths = {}
    for name, data in (("col", np.clip(col, 0, 255).astype(np.uint8)),
                       ("nrm", ((n * 0.5 + 0.5) * 255).round().astype(np.uint8)),
                       ("orm", np.dstack((np.full_like(h, 255), rough * 255, metal * 255)).round().astype(np.uint8))):
        paths[name] = os.path.join(folder, "pads_%s.png" % name)
        Image.fromarray(data).save(paths[name])
    return paths


def make_material(paths: dict) -> bpy.types.Material:
    mat = bpy.data.materials.new(MATERIAL)
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    images = {}
    for name, path in paths.items():
        img = bpy.data.images.load(path)
        img.name = "pads_" + name
        img.colorspace_settings.name = "sRGB" if name == "col" else "Non-Color"
        img.pack()
        node = nodes.new("ShaderNodeTexImage")
        node.image = img
        images[name] = node
    links.new(images["col"].outputs["Color"], bsdf.inputs["Base Color"])
    split = nodes.new("ShaderNodeSeparateColor")
    links.new(images["orm"].outputs["Color"], split.inputs["Color"])
    links.new(split.outputs["Green"], bsdf.inputs["Roughness"])
    links.new(split.outputs["Blue"], bsdf.inputs["Metallic"])
    normal = nodes.new("ShaderNodeNormalMap")
    links.new(images["nrm"].outputs["Color"], normal.inputs["Color"])
    links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


# --- the figure ----------------------------------------------------------------------------------------------------------

def load_figure() -> tuple:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=FIGURE)
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    rig.data.pose_position = "REST"
    bpy.context.view_layer.update()
    body = bpy.data.objects["Body"]
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = body.evaluated_get(depsgraph).to_mesh()
    verts = [body.matrix_world @ v.co for v in mesh.vertices]
    polys = [tuple(p.vertices) for p in mesh.polygons]
    bvh = BVHTree.FromPolygons(verts, polys)
    body.evaluated_get(depsgraph).to_mesh_clear()
    return rig, body, bvh


def bone_point(rig: bpy.types.Object, name: str, tail: bool = False) -> Vector:
    bone = rig.data.bones[name]
    return rig.matrix_world @ (bone.tail_local if tail else bone.head_local)


def fits(rig: bpy.types.Object, bvh: BVHTree) -> list:
    out = []
    for side, sign in (("L", 1.0), ("R", -1.0)):
        knee = bone_point(rig, "Shin_" + side)
        axis = (bone_point(rig, "Thigh_" + side) - bone_point(rig, "Shin_" + side, True)).normalized()
        out.append(Fit(bvh, "Shin_" + side, knee - axis * 0.01, axis, Vector((0.0, -1.0, 0.0)),
                       Vector((sign, 0.0, 0.0)), 1.0, FLAT[0], DOME_RISE[0], 0.16))
        elbow = bone_point(rig, "Forearm_" + side)
        upper = (bone_point(rig, "UpperArm_" + side) - elbow).normalized()
        fore = (bone_point(rig, "Hand_" + side) - elbow).normalized()
        axis = (upper - fore).normalized()
        back = -(upper + fore)
        # The elbow's point is the outside of its bend: away from both bones.
        facing = back if back.length > 1e-4 else Vector((0.0, 1.0, 0.0))
        out.append(Fit(bvh, "Forearm_" + side, elbow - axis * 0.005, axis, facing,
                       Vector((sign, 0.0, 0.0)), ELBOW_SCALE, FLAT[1], DOME_RISE[1], 0.12))
    return out


def build_level(fits_: list, level: dict, name: str, mat: bpy.types.Material, body: bpy.types.Object,
                rig: bpy.types.Object) -> bpy.types.Object:
    sheets = Sheets()
    for fit in fits_:
        pad(sheets, fit, level)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in sheets.verts], [], sheets.faces)
    uv = mesh.uv_layers.new(name="UVMap")
    for poly, face_uvs in zip(mesh.polygons, sheets.uvs):
        for li, coord in zip(poly.loop_indices, face_uvs):
            uv.data[li].uv = coord
    hug = mesh.attributes.new("hug", "FLOAT", "POINT")
    hug.data.foreach_set("value", sheets.hugs)
    mesh.materials.append(mat)
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(ob)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = True
    mesh.set_sharp_from_angle(angle=math.radians(50.0))
    # Weights: each pad rides one bone rigidly, as a hard shell strapped to the limb does (the shin, and the forearm,
    # whose end the elbow's point is): bent, its top stands off the joint instead of folding round it. A strap or buckle
    # lying on the body takes the body's own weights there (Blender's data transfer), blended by its hug, so it stays
    # on the thigh or upper arm, and turns with the forearm's twist, as the sleeve under it does.
    hug_layer = mesh.attributes["hug"].data
    hugs = [hug_layer[i].value for i in range(len(mesh.vertices))]
    for group in body.vertex_groups:
        ob.vertex_groups.new(name=group.name)
    mod = ob.modifiers.new("weights", "DATA_TRANSFER")
    mod.object = body
    mod.use_vert_data = True
    mod.data_types_verts = {"VGROUP_WEIGHTS"}
    mod.vert_mapping = "POLYINTERP_NEAREST"
    mod.layers_vgroup_select_src = "ALL"
    mod.layers_vgroup_select_dst = "NAME"
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    names = {g.index: g.name for g in ob.vertex_groups}
    plan = []
    for v in mesh.vertices:
        fit = min(fits_, key=lambda f: (f.centre - v.co).length)
        hug = hugs[v.index]
        up = (v.co - fit.centre).dot(fit.axis)
        # The cushion's soft top band, above the shell, eases toward the bone above the joint, so bent it folds onto
        # the thigh instead of standing off it; the shell below stays rigid.
        lo, hi = ((CY - y) / PX_PER_M * fit.scale for y in BEND_BAND)
        t = min(max((up - lo) / (hi - lo), 0.0), 1.0)
        bend = PAD_BEND[0 if fit.scale == 1.0 else 1] * t * t * (3.0 - 2.0 * t)
        above = fit.bone.replace("Shin", "Thigh").replace("Forearm", "UpperArm")
        weights = {fit.bone: (1.0 - hug) * (1.0 - bend)}
        if bend > 0.0:
            weights[above] = (1.0 - hug) * bend
        if hug > 0.0:
            for g in v.groups:
                weights[names[g.group]] = weights.get(names[g.group], 0.0) + hug * g.weight
        plan.append(weights)
    for group in list(ob.vertex_groups):
        ob.vertex_groups.remove(group)
    groups = {}
    for v, weights in zip(mesh.vertices, plan):
        top = sorted(((w, n) for n, w in weights.items() if w > 1e-4), reverse=True)[:4]
        total = sum(w for w, _ in top)
        for w, n in top:
            if n not in groups:
                groups[n] = ob.vertex_groups.new(name=n)
            groups[n].add([v.index], w / total, "REPLACE")
    ob.parent = rig
    arm = ob.modifiers.new("Armature", "ARMATURE")
    arm.object = rig
    ob.select_set(False)
    return ob


def tris(ob: bpy.types.Object) -> int:
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def main() -> None:
    rig, body, bvh = load_figure()
    for ob in list(bpy.data.objects):
        if ob.type == "MESH" and ob.name.startswith(PART):
            bpy.data.objects.remove(ob)
    old = bpy.data.materials.get(MATERIAL)  # a figure built by an earlier run carries the pads' material already
    if old is not None:
        bpy.data.materials.remove(old)
    folder = tempfile.mkdtemp(prefix="pads_")
    mat = make_material(textures(folder))
    fits_ = fits(rig, bvh)
    names = [PART, PART + "_LOD1", PART + "_LOD2"]
    made = [build_level(fits_, level, name, mat, body, rig) for level, name in zip(LEVELS, names)]
    for ob, budget in zip(made, LOD_BUDGET):
        count = tris(ob)
        print("%s: %d triangles (budget %d)" % (ob.name, count, budget))
        if count > budget:
            sys.exit("%s is over its budget" % ob.name)
    for ob in list(bpy.data.objects):
        if ob.type == "MESH" and ob not in made:
            bpy.data.objects.remove(ob)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in made + [rig]:
        ob.select_set(True)
    part = os.path.join(folder, "pads.glb")
    bpy.ops.export_scene.gltf(filepath=part, use_selection=True, export_format="GLB", export_animations=False,
                              export_skins=True, export_image_format="WEBP", export_image_quality=90,
                              export_tangents=False, export_yup=True, export_apply=False)
    if os.environ.get("PADS_BLEND"):
        bpy.ops.wm.save_as_mainfile(filepath=os.environ["PADS_BLEND"])
    print("spliced", ", ".join(splice_part.splice(FIGURE, part, PART)))
    with open(SIDECAR) as f:
        side = json.load(f)
    for name in names:
        if name not in side["parts"]:
            side["parts"].append(name)
    with open(SIDECAR, "w") as f:
        json.dump(side, f, indent=1)


if __name__ == "__main__":
    main()
