"""The face in the balaclava's eye opening (FA1, 2026-11-05), shared by tools/blender/figures/headwear.py.

Every head look covers the lower face (the steel mesh mask, the scarf or the balaclava itself), so only the strip
round the eyes is modelled: the skin from the cheek tops to the brows inside the balaclava's eye opening, the eyelids,
the eyeballs and the rolled knit hem round the opening. Players see it through the clear lenses at close range.

  - The opening is a rounded rectangle in the face's (s, z) plane: s is azimuth times R_REF (about metres across the
    face), z the height. The head's knit gets a clean rectangular hole there (headwear.head(..., opening=True)) and
    the hem, a swept roll of knit, covers its edge.
  - The skin is the head's own surface a little under the knit, with each eye's socket carved to a lid shell that
    rides just in front of the eyeball, a crease above it and a roll under it. It is triangulated (constrained
    Delaunay) round two holes, the outer loop of each eye's lids, so the lids join it without a seam.
  - Each eye: an eyeball cap and three loops of lid (tucked into the eyeball, the lid's margin, its rim, out to the
    skin) round an almond-shaped fissure.
  - LOD2 keeps only a coarse skin patch with the eyes painted on it.

The texture is a map of the face's own (MQ3C: FACE_MAP, painted by face_paint.py), four looks side by side
(FACE_CELLS): one skin tone, brow and eye colour each. The mesh's UVs point at the first; the game picks a cell per
figure by offsetting the Face material's UVs (FigureConfig.face_offsets), so the four looks cost no triangles.

Space as head_shapes.py: Blender metres, +Z up, the figure facing -Y, +X its left, the rest pose. Nothing here sits
outside the head's knit surface except the eyelids, by at most LID_PROUD_MAX, well inside every lens: the eyewear,
masks and scarf were fitted to that surface, so nothing clips.
"""

import bisect
import math

import numpy as np
from mathutils import Vector, geometry

import head_shapes as hs
from headkit import GEAR, Part, cull, gauss, smoothstep

FACE = "Face"

# --- the face's plane and the opening ------------------------------------------------------------------------------

R_REF = 0.09          # metres of s per radian of azimuth
KNIT_ROUND = 0.565    # metres round the head at the face (the knit tile's width; head_textures._knit)
OPEN_Z = 1.619        # the opening's centre height
OPEN_HS = 0.066       # half width (s) of the hem's centre line
OPEN_HT = 0.0225      # half height of the hem's centre line
OPEN_R = 0.009        # its corner radius
SKIN_MARGIN = 0.0035  # how far the skin runs on under the knit beyond the hem's centre line
# The knit's hole: exactly the hem's centre-line rectangle (its corners hide under the hem's outer half).
HOLE_AZ = OPEN_HS / R_REF
HOLE_Z0 = OPEN_Z - OPEN_HT
HOLE_Z1 = OPEN_Z + OPEN_HT

# Skin depth under the knit: deeper at the edge (under the knit and hem) than in the middle.
SKIN_EDGE = -0.0022
SKIN_MID = -0.0004
SKIN_HEM_IN = 0.0045  # the hem's inner lip, inside the opening's edge: the skin keeps its edge depth out to it
SKIN_EDGE_FADE = 0.004
SKIN_DIVE = 0.6       # metres deeper per metre beyond the opening's edge

# --- the eyes --------------------------------------------------------------------------------------------------------

EYE_AZ = 0.345        # the pupils' azimuth (about 61 mm apart)
EYE_Z = 1.6155
EYE_R = 0.0125        # eyeball radius
EYE_PROUD = 0.0003    # the cornea's front ahead of the head's socket floor (the brow's ridge stands over it)
# The eye's surface is the ball out to EYE_BALL from the cornea's middle (toward the ear, toward the nose); beyond
# it runs on, flattening over EYE_EASE: the folds in the corners fill in front of the ball, most by the nose.
EYE_BALL = (0.0070, 0.0060)
EYE_EASE = (0.0060, 0.0015)
# The fissure (the almond between the lids): its middle from the cornea's (toward the nose: the inner corner holds the
# caruncle), half width, height above and below the centre, the outer corner's lift, and the superellipse power (under
# 2 makes the corners pointed). 28.8 mm wide and 9.5 high; the inner corners 31 mm apart, a little over an eye's
# width; the upper lid rests 1.7 mm over the iris and the lower just meets it (a relaxed look, not a stare).
FIS_MID = -0.0005
FIS_W = 0.0144
FIS_UP = 0.0041
FIS_LO = 0.0054
FIS_TILT = 0.0007
FIS_POW = 1.7
# The eyeball's cap: how far past the fissure it runs under the lids (across, up and down).
EYE_REACH = (1.10, 1.28)
# The lid shell (a paraboloid riding LID in front of the cornea, its radii across and up): the lids and the skin of
# the carved socket lie on it.
LID = 0.0019
LID_RU = 0.016
LID_RU_OUT = 0.0105   # toward the outer corner it curves back faster (the eye shows in profile)
LID_RV = 0.013
# The lids' loops: (u scale, rise above, drop below) from the fissure; L1 on the shell, L2 on the skin.
LID_L1 = (1.06, 0.0013, 0.0009)
LID_L2 = (1.14, 0.0032, 0.0030)
LID_SEG_FULL = 20         # lid segments at full detail: no head has fewer, and a denser head gains them at
LID_SEG_GAIN = 0.8        # this share of its density over 1 (each costs 28 triangles of the head's 9,000)
LID_MARGIN_OUT = 0.0004   # the lid's margin, off the eyeball
LID_TUCK = 0.0011         # its inner edge, tucked into the eyeball (deeper than the cap's flat faces sag: no gap)
# The carve: full inside the CARVE superellipse (u, up, down half sizes), fading to none at CARVE_OUT (kept tight
# across, so the nose's bridge and the temples keep the head's own shape).
CARVE = (0.0180, 0.0100, 0.0086, 0.0172)          # out, up, down, in (toward the nose: shallower)
CARVE_OUT = (0.0225, 0.0170, 0.0135, 0.0265)
# Toward the nose the lid shell comes forward by up to this, so the socket's wall by the bridge is a gentle slope.
MEDIAL_LIFT = 0.0024
# The lid shell stops deepening this far behind its front (across, up): beyond the lids it only needs to meet the skin.
SHELL_MAX = (0.0060, 0.0060)
# Rings of skin quads round each eye beyond the lids, each offset from the lids' outer loop along its normal (at the
# corners, above, below; so their corners round off instead of bunching) with 1 or 2 points per lid point.
EYE_RINGS = ((0.0010, 0.0016, 0.0014, 1), (0.0024, 0.0038, 0.0032, 1), (0.0040, 0.0063, 0.0052, 1),
             (0.0058, 0.0090, 0.0075, 1), (0.0040, 0.0063, 0.0052, 2), (0.0058, 0.0090, 0.0075, 2))
LID_PROUD_MAX = 0.0015    # how far the carved socket may stand out of the knit surface (lens clearance: > 15 mm)
CREASE_DEPTH = 0.0005
CREASE_UP = 0.0036        # the fold over the upper lid, above the lid's edge
ROLL_HEIGHT = 0.0004

# --- the texture cells ------------------------------------------------------------------------------------------------

# The face's own map (MQ3C): its size, and each look's pixel rectangle in it (x, y from the bottom, w, h). The mesh
# uses the first; FigureConfig.face_offsets holds the others' offsets in Godot's UV space (v flipped). face_paint.py
# paints them.
FACE_MAP = (2048, 1024)
FACE_CELLS = ((0, 0, 1024, 512), (1024, 0, 1024, 512), (0, 512, 1024, 512), (1024, 512, 1024, 512))
TILE_S = 0.072                                # the cell spans s in [-TILE_S, TILE_S]
TILE_Z = (OPEN_Z - 0.0448, OPEN_Z + 0.0272)   # and z between these: a pixel is as high as it is wide
# The strip of the cell under the skin holds each eyeball's own patch, drawn flat (u across, v up from the cornea) so
# the eyeball's paint keeps its shape however deep its corners lie: the patch's middle (s for the left eye, z) and
# its scale (map metres per metre of eye). The skin's part of the cell keeps the eyes too, for the lowest level.
EYE_PATCH = (0.0250, OPEN_Z - 0.0357, 1.15)
EYE_PATCH_HALF = (0.0205, 0.0085)             # half the patch's size on the map (s, z)

# Each look (sRGB): skin, brow, iris, the ring round its pupil and how strong it is, lip-pink for the lid margins;
# how strongly the iris's fibres show (a dark eye's hardly do), freckles, the brow's hairs and width, how deep the
# fine lines are. The looks differ as people do, not only in colour.
LOOKS = (
    {"skin": 0xe3b89c, "brow": 0x4a3020, "iris": 0x5f8496, "ring": 0x9c8f66, "ring_in": 0.55, "pink": 0xd99a8a,
     "fibre": 0.30, "freckles": 70, "hairs": 2400, "brow_w": 1.05, "lines": 0.85},
    {"skin": 0xc8956c, "brow": 0x35241a, "iris": 0x5e7048, "ring": 0x8a6a34, "ring_in": 0.70, "pink": 0xd09682,
     "fibre": 0.26, "freckles": 0, "hairs": 2200, "brow_w": 1.08, "lines": 1.0},
    {"skin": 0x965f3f, "brow": 0x241911, "iris": 0x5b3a21, "ring": 0x7a4a22, "ring_in": 0.60, "pink": 0xa06450,
     "fibre": 0.16, "freckles": 0, "hairs": 2000, "brow_w": 1.0, "lines": 0.7},
    {"skin": 0x6f4531, "brow": 0x18120e, "iris": 0x3b2414, "ring": 0x4f2f18, "ring_in": 0.50, "pink": 0x8a5444,
     "fibre": 0.10, "freckles": 0, "hairs": 1800, "brow_w": 0.92, "lines": 0.6},
)

# Per level: the skin's depth at its edge and how far it runs on under the knit (the knit's chords cut deeper at
# the coarser levels), skin sample spacing (s, z), eyeball segments and rings (shares of the way from the cornea to
# the cap's edge), lid segments, hem segments and its profile.
LEVELS = (
    {"edge": SKIN_EDGE, "margin": SKIN_MARGIN, "ds": 0.0092, "dz": 0.0072, "rings": (0, 1, 2, 3),
     "eye_seg": 10, "eye_rings": (0.22, 0.45, 0.72, 1.0), "lid_seg": 20,
     "hem_seg": 32, "hem_corner": 4, "hem_nose": (0.005, 0.010, 0.0145, 0.026, 0.0475),
     "hem": ((-0.0050, -0.0032), (-0.0018, 0.0021), (0.0016, 0.0020), (0.0040, -0.0016))},
    {"edge": -0.0028, "margin": 0.0025, "ds": 0.0140, "dz": 0.0100, "rings": (0, 4, 5),
     "eye_seg": 8, "eye_rings": (0.4, 0.75, 1.0), "lid_seg": 10, "bridge": (0.4, 0.8),
     "hem_seg": 24, "hem_corner": 2, "hem_nose": (0.008, 0.028),
     "hem": ((-0.0050, -0.0032), (0.0004, 0.0022), (0.0040, -0.0016))},
    {"edge": -0.0025, "margin": 0.0010, "ds": 0.034, "dz": 0.022, "rings": (),
     "eye_seg": 0, "eye_rings": (), "lid_seg": 0,
     "hem_seg": 12, "hem_corner": 1,
     "hem": ((-0.0050, -0.0032), (0.0004, 0.0022), (0.0040, -0.0016)), "outer_min": 16},
)


# ------------------------------------------------------------------------------------------------------- shapes

def opening_sdf(s, z, grow: float = 0.0):
    """Signed distance (negative inside) from the opening's rounded rectangle grown by `grow`; floats or arrays."""
    qs = np.abs(s) - (OPEN_HS + grow) + (OPEN_R + grow)
    qz = np.abs(z - OPEN_Z) - (OPEN_HT + grow) + (OPEN_R + grow)
    out = np.sqrt(np.maximum(qs, 0.0) ** 2 + np.maximum(qz, 0.0) ** 2)
    return out + np.minimum(np.maximum(qs, qz), 0.0) - (OPEN_R + grow)


def rounded_rect(grow: float, count: int, corner: int = 0, nose: tuple = ()) -> list:
    """`count` (s, z) points round the opening's outline grown by `grow`, counter-clockwise from the bottom edge's
    left end. Spaced evenly along it, or with `corner` segments on each corner's arc and the rest shared by the edges
    by length (the hem's corners stay round). `nose` adds points on the bottom edge at ±each s (over the nose, which is
    narrower than the spacing)."""
    hs_, ht, r = OPEN_HS + grow, OPEN_HT + grow, OPEN_R + grow
    straight_s, straight_z = 2 * (hs_ - r), 2 * (ht - r)
    arc = 0.5 * math.pi * r
    segs = [("line", (-hs_ + r, OPEN_Z - ht), (1, 0), straight_s),
            ("arc", (hs_ - r, OPEN_Z - ht + r), -0.5 * math.pi, arc),
            ("line", (hs_, OPEN_Z - ht + r), (0, 1), straight_z),
            ("arc", (hs_ - r, OPEN_Z + ht - r), 0.0, arc),
            ("line", (hs_ - r, OPEN_Z + ht), (-1, 0), straight_s),
            ("arc", (-hs_ + r, OPEN_Z + ht - r), 0.5 * math.pi, arc),
            ("line", (-hs_, OPEN_Z + ht - r), (0, -1), straight_z),
            ("arc", (-hs_ + r, OPEN_Z - ht + r), math.pi, arc)]
    if corner > 0:
        left = max(4, count - 4 * corner)
        lines_total = 2 * straight_s + 2 * straight_z
        counts = []
        for kind, _a, a_, length in segs:
            n = max(1, int(round(left * length / lines_total)))
            if kind == "line" and a_[1] == 0:
                n = max(2, n + n % 2)  # even along the top and bottom: a point over the nose's ridge
            counts.append(corner if kind == "arc" else n)
    else:
        total = 2 * straight_s + 2 * straight_z + 4 * arc
        counts = [max(1, int(round(count * length / total))) for _k, _a, _b, length in segs]
        counts = [n + n % 2 if seg[0] == "line" and seg[2][1] == 0 else n for n, seg in zip(counts, segs)]
    pts = []
    for k, ((kind, a, b, length), n) in enumerate(zip(segs, counts)):
        line = []
        for i in range(n):
            d = length * i / n
            if kind == "line":
                line.append((a[0] + b[0] * d, a[1] + b[1] * d))
            else:
                ang = b + d / r
                line.append((a[0] + r * math.cos(ang), a[1] + r * math.sin(ang)))
        if k == 0 and nose:
            extra = [x for v in nose for x in (-v, v) if all(abs(x - q[0]) > 0.0025 for q in line)]
            line = sorted(line + [(x, a[1]) for x in extra])
        pts += line
    return pts


class Eye:
    """One eye: σ +1 is the figure's left (+X). u runs out toward the ear, v up, both in metres from the cornea."""

    def __init__(self, side: float):
        self.side = side
        self.front = hs.head_point(side * EYE_AZ, EYE_Z) + Vector((0.0, -EYE_PROUD, 0.0))
        self.r_front = math.hypot(self.front.x, self.front.y)

    def uv_of(self, x: float, z: float) -> tuple:
        return self.side * (x - self.front.x), z - self.front.z

    def x_of(self, u: float) -> float:
        return self.front.x + self.side * u

    @staticmethod
    def depth(u, v):
        """How far behind the cornea's front the eye's surface lies at (u, v); floats or arrays."""
        d = np.hypot(u, v)
        w = 0.5 - 0.5 * u / np.maximum(d, 1e-9)      # 1 toward the nose
        w = w * w * (3.0 - 2.0 * w)
        ball = EYE_BALL[0] + (EYE_BALL[1] - EYE_BALL[0]) * w
        ease = EYE_EASE[0] + (EYE_EASE[1] - EYE_EASE[0]) * w
        slope = ball / np.sqrt(EYE_R * EYE_R - ball * ball)
        on_ball = EYE_R - np.sqrt(EYE_R * EYE_R - np.minimum(d, ball) ** 2)
        return on_ball + slope * ease * (1.0 - np.exp(-np.maximum(d - ball, 0.0) / ease))

    def surface(self, u: float, v: float, out: float = 0.0) -> Vector:
        """The eye's surface at (u, v), or the point `out` in front of it (behind it when negative)."""
        e = 1e-4
        g = math.hypot(float(self.depth(u + e, v) - self.depth(u - e, v)),
                       float(self.depth(u, v + e) - self.depth(u, v - e))) / (2.0 * e)
        y = self.front.y + float(self.depth(u, v)) - out * min(math.sqrt(1.0 + g * g), 1.6)
        return Vector((self.x_of(u), y, self.front.z + v))

    def patch(self, u: float, v: float) -> tuple:
        """Where (u, v) of this eye lies in its own patch of the map: (s, z)."""
        return self.side * (EYE_PATCH[0] + EYE_PATCH[2] * u), EYE_PATCH[1] + EYE_PATCH[2] * v

    def shell_y(self, u, v):
        qu = SHELL_MAX[0] * np.tanh(u * u / (2.0 * np.where(u > 0.0, LID_RU_OUT, LID_RU)) / SHELL_MAX[0])
        qv = SHELL_MAX[1] * np.tanh(v * v / (2.0 * LID_RV) / SHELL_MAX[1])
        medial = np.clip((-u - 0.006) / 0.008, 0.0, 1.0)
        medial = medial * medial * (3.0 - 2.0 * medial)
        # Toward the nose the shell flattens top to bottom (no ridge running in from the inner corner).
        return self.front.y - LID + qu + qv * (1.0 - 0.8 * medial) - MEDIAL_LIFT * medial


EYES = (Eye(1.0), Eye(-1.0))


def fissure(t: float) -> tuple:
    """The almond at angle t (0 the outer corner, pi/2 the top): (u, v)."""
    a, b = math.cos(t), math.sin(t)
    ua = math.copysign(abs(a) ** (2.0 / FIS_POW), a)
    va = math.copysign(abs(b) ** (2.0 / FIS_POW), b)
    h = FIS_UP * (1.0 - 0.10 * ua) if b >= 0.0 else FIS_LO * (1.0 + 0.12 * ua)
    return FIS_MID + FIS_W * ua, h * va + FIS_TILT * ua


def fissure_scaled(t: float, across: float, up: float, down: float = -1.0) -> tuple:
    """The almond at angle t scaled about its own middle line: `across`, and by `up` above it and `down` below
    (metres added when the two are given, else a scale both ways)."""
    u0, v0 = fissure(t)
    ua = (u0 - FIS_MID) / FIS_W
    mid = FIS_TILT * ua
    if down < 0.0:
        return FIS_MID + FIS_W * ua * across, mid + (v0 - mid) * up
    return FIS_MID + FIS_W * ua * across, v0 + up * max(math.sin(t), 0.0) - down * max(-math.sin(t), 0.0)


def along(u):
    """Where u lies along the fissure: -1 the inner corner, 1 the outer; floats or arrays."""
    return (u - FIS_MID) / FIS_W


def fissure_rho(u, v):
    """1 on the almond, under 1 inside it; floats or arrays."""
    ua = (u - FIS_MID) / FIS_W
    vv = v - FIS_TILT * np.clip(ua, -1.0, 1.0)
    h = np.where(vv >= 0.0, FIS_UP * (1.0 - 0.10 * np.clip(ua, -1, 1)), FIS_LO * (1.0 + 0.12 * np.clip(ua, -1, 1)))
    return (np.abs(ua) ** FIS_POW + np.abs(vv / h) ** FIS_POW) ** (1.0 / FIS_POW)


def lid_out(t: float) -> tuple:
    """The lids' outer loop (on the skin) at angle t: (u, v)."""
    return fissure_scaled(t, *LID_L2)


def ring_uv(t: float, off: tuple) -> tuple:
    """A point of the ring `off` (an EYE_RINGS entry) at angle t: the lids' outer loop pushed out along its normal."""
    a, b, c = lid_out(t), lid_out(t + 1e-4), lid_out(t - 1e-4)
    tu, tv = b[0] - c[0], b[1] - c[1]
    n = math.hypot(tu, tv)
    sn = math.sin(t)
    d = off[0] * math.cos(t) ** 2 + (off[1] if sn > 0.0 else off[2]) * sn * sn
    return a[0] + tv / n * d, a[1] - tu / n * d


def _super(u, v, size, p: float = 2.5):
    h = np.where(v >= 0.0, size[1], size[2])
    w = np.where(u >= 0.0, size[0], size[3])
    return (np.abs(u / w) ** p + np.abs(v / h) ** p) ** (1.0 / p)


def carve_weight(u, v):
    """1 inside CARVE, 0 outside CARVE_OUT, smooth between (along each ray from the cornea); floats or arrays."""
    a = np.maximum(_super(u, v, CARVE), 1e-9)
    b = np.maximum(_super(u, v, CARVE_OUT), 1e-9)
    t = np.clip((a - 1.0) * b / np.maximum(a - b, 1e-9), 0.0, 1.0)
    t = t * t * (3.0 - 2.0 * t)
    return np.where(a <= 1.0, 1.0, np.where(b >= 1.0, 0.0, 1.0 - t))


def _skin_offset(s: float, z: float, edge: float) -> float:
    """How far under the knit's surface the skin lies: SKIN_MID in the middle, `edge` from the hem's inner lip out to
    the opening's edge (the hem lies over it), then diving away under the knit (its chords cut inside the surface)."""
    d = float(opening_sdf(s, z))
    return edge + (SKIN_MID - edge) * smoothstep(SKIN_HEM_IN, SKIN_HEM_IN + SKIN_EDGE_FADE, -d) - SKIN_DIVE * max(d, 0.0)


def skin_radius(s: float, z: float, carve: bool = True, edge: float = SKIN_EDGE) -> float:
    """The skin's distance from the head's axis at (s, z)."""
    az = s / R_REF
    head_r = hs.head_radius(az, z)
    r = head_r + _skin_offset(s, z, edge)
    if not carve:
        return _smin(r, head_r - 0.0003, 0.0015)
    proud = -0.0003
    for eye in EYES:
        if eye.side * az <= 0.0:
            continue
        u0, v = eye.uv_of(head_r * math.sin(az), z)
        w = float(carve_weight(u0, v))
        if w <= 0.0:
            continue
        # The point on the lid shell along this ray from the axis (a few fixed-point steps: the ray is nearly level).
        rs = head_r
        for _ in range(4):
            u, _v = eye.uv_of(rs * math.sin(az), z)
            rs = -float(eye.shell_y(u, v)) / math.cos(az)
        u, _v = eye.uv_of(rs * math.sin(az), z)
        # The crease over the upper lid and the roll under the lower one, on the shell.
        rho = float(fissure_rho(u, v))
        top = smoothstep(-0.2, 0.4, v / FIS_UP)
        rs -= CREASE_DEPTH * gauss(rho - CREASE_RHO, 0.14) * top * (1.0 - smoothstep(0.9, 1.3, abs(float(along(u)))))
        rs += ROLL_HEIGHT * gauss(rho - LID_L2_RHO_LO - 0.2, 0.18) * (1.0 - top) * (1.0 - smoothstep(0.8, 1.2, abs(float(along(u)))))
        r = r + (rs - r) * w
        # Only the lids may stand out of the head's surface (beyond them the socket stays under it: no lumps).
        proud = max(proud, -0.0003 + (LID_PROUD_MAX + 0.0003) * (1.0 - smoothstep(LID_L2_RHO_LO, LID_L2_RHO_LO + 0.5, rho)))
    return _smin(r, head_r + proud, 0.0015)


def _smin(a: float, b: float, k: float) -> float:
    """A smooth minimum (no crease where the two meet)."""
    h = max(0.0, min(1.0, 0.5 + 0.5 * (b - a) / k))
    return b + (a - b) * h - k * h * (1.0 - h)


# The lid's outer loop in fissure terms (for the crease and roll placement).
LID_L2_RHO_UP = (FIS_UP + LID_L2[1]) / FIS_UP
LID_L2_RHO_LO = (FIS_LO + LID_L2[2]) / FIS_LO
CREASE_RHO = (FIS_UP + CREASE_UP) / FIS_UP


def skin_point(s: float, z: float, carve: bool = True, edge: float = SKIN_EDGE) -> Vector:
    az = s / R_REF
    r = skin_radius(s, z, carve, edge)
    return Vector((math.sin(az) * r, -math.cos(az) * r, z))


def face_s(p: Vector) -> float:
    return math.atan2(p.x, -p.y) * R_REF


def skin_s(x: float, z: float, edge: float = SKIN_EDGE) -> float:
    """The s at which the carved skin at height z lies at `x` across the face. (The skin round an eye lies deeper
    than the head's surface, more toward the outer corner: placed by the head's azimuth alone, the lids' outer loop
    fell 2 mm short there and folded back under the lid's rim.)"""
    s = math.atan2(x, -EYES[0].front.y) * R_REF
    for _ in range(8):
        s = math.atan2(x, -skin_point(s, z, True, edge).y) * R_REF
    return s


# ------------------------------------------------------------------------------------------------------- the mesh

def face_part(k, keep=None) -> Part:
    """The face at level `k.level` (k: headwear.Kit). `keep(point)` False drops a face hidden under the head gear."""
    lv = LEVELS[k.level]
    margin = lv["margin"]
    tile = k.atlas.face.tiles["face"]
    p = Part("face")

    def uv(q: Vector) -> tuple:
        return tile.uv((face_s(q) + TILE_S) / (2 * TILE_S), (q.z - TILE_Z[0]) / (TILE_Z[1] - TILE_Z[0]))

    uv_at = {}     # point index -> the point whose paint it takes (the lids: where they would lie flat on the face)
    uv_fixed = {}  # point index -> its place (s, z) on the map (the eyeballs: their own patches)

    def uv_of(i: int) -> tuple:
        if i in uv_fixed:
            s, z = uv_fixed[i]
            return tile.uv((s + TILE_S) / (2 * TILE_S), (z - TILE_Z[0]) / (TILE_Z[1] - TILE_Z[0]))
        return uv(uv_at.get(i, p.pts[i]))

    def tri(a: int, b: int, c: int, mat: str = FACE) -> None:
        p.faces.append((a, b, c))
        p.uvs.append(tuple(uv_of(i) for i in (a, b, c)))
        p.mats.append(mat)
        p.flat.append(False)

    def quad(a: int, b: int, c: int, d: int) -> None:
        p.faces.append((a, b, c, d))
        p.uvs.append(tuple(uv_of(i) for i in (a, b, c, d)))
        p.mats.append(FACE)
        p.flat.append(False)

    carve = lv["lid_seg"] > 0
    lids = _lid_loops(lv, k.density) if carve else []

    # The skin: constrained Delaunay over the grown opening with the lids' outer loops as holes.
    coords, edges = [], []

    def loop_in(points: list) -> list:
        base = len(coords)
        coords.extend(Vector(q) for q in points)
        m = len(points)
        edges.extend((base + i, base + (i + 1) % m) for i in range(m))
        return list(range(base, base + m))

    perim = 2 * (2 * OPEN_HS + 2 * OPEN_HT) + 2 * math.pi * OPEN_R
    outer = loop_in(rounded_rect(margin, max(lv.get("outer_min", 24), int(perim / lv["ds"] * 1.1))))
    # Each eye's rings (s, z), the lids' outer loop first; the last ring is the skin triangulation's hole.
    eye_rings = []
    for eye, loops in lids:
        seq = [[Vector(q) for q in loops["out"]]]
        for ri in lv["rings"]:
            off = EYE_RINGS[ri]
            m = len(loops["out"]) * off[3]
            ring = []
            for i in range(m):
                u, v = ring_uv(math.tau * i / m, off)
                ring.append(Vector((skin_s(eye.x_of(u), eye.front.z + v, lv["edge"]), eye.front.z + v)))
            seq.append(ring)
        eye_rings.append(seq)
    holes = [loop_in(seq[-1]) for seq in eye_rings]
    hole_polys = [[coords[i] for i in h] for h in holes]
    constraint = [coords[i] for i in outer] + [q for h in hole_polys for q in h]
    ds, dz = lv["ds"], lv["dz"]
    if not carve:
        # LOD2's flat patch: points on and round each eye, so its big triangles don't skew the painted eyes.
        for eye in EYES:
            for du, dv in ((0.0, 0.0), (FIS_MID + FIS_W, 0.0), (FIS_MID - FIS_W, 0.0)):
                x = eye.x_of(du)
                coords.append(Vector((math.atan2(x, -eye.front.y) * R_REF, eye.front.z + dv)))
                constraint.append(coords[-1])
    ns = int(2 * (OPEN_HS + margin) / ds)
    nz = int(2 * (OPEN_HT + margin) / dz)
    for j in range(nz + 1):
        z = OPEN_Z - (OPEN_HT + margin) + j * 2 * (OPEN_HT + margin) / nz
        step = 2 * (OPEN_HS + margin) / ns
        shift = 0.5 * step if j % 2 else 0.0   # staggered rows (better triangles), mirrored about the nose
        row = [shift + i * step for i in range(ns)]
        for s in sorted({round(x, 9) for x in row} | {round(-x, 9) for x in row}):
            if float(opening_sdf(s, z, margin)) > -0.45 * min(ds, dz) or abs(s) < 0.3 * ds:
                continue  # (the bridge's own column goes down the middle below)
            q = Vector((s, z))
            if any(_inside(q, poly) for poly in hole_polys):
                continue
            if any((q - c).length < 0.45 * min(ds, dz) for c in constraint):
                continue
            coords.append(q)
    # The nose's bridge between the eyes: its ridge is narrower than the grid, so a column down the middle and one
    # each side of it.
    for j in range(2 * nz + 1):
        z = OPEN_Z - OPEN_HT + j * 2 * OPEN_HT / (2 * nz)
        cols = [0.0] + [f * ds * side for f in lv.get("bridge", (0.55,)) for side in (-1.0, 1.0)]
        for s in cols if j % 2 == 0 else (0.0,):
            q = Vector((s, z))
            if any(_inside(q, poly) for poly in hole_polys):
                continue
            if any((q - c).length < 0.3 * min(ds, dz) for c in coords):
                continue
            coords.append(q)
    out = geometry.delaunay_2d_cdt(coords, edges, [], 0, 1e-7)
    verts2, faces2, orig = out[0], out[2], out[3]
    base = len(p.pts)
    for q in verts2:
        p.pts.append(skin_point(q.x, q.y, carve, lv["edge"]))
    by_input = {}
    for vi, origs in enumerate(orig):
        for o in origs:
            by_input[o] = base + vi
    for f in faces2:
        c = sum((verts2[i] for i in f), Vector((0.0, 0.0))) / len(f)
        if float(opening_sdf(c.x, c.y, margin)) > 0.0 or any(_inside(c, poly) for poly in hole_polys):
            continue
        tri(*(base + i for i in f))

    # The lids: tuck -> margin -> rim -> the lids' outer loop, then the rings out to the skin's hole (shared points).
    for (eye, loops), hole, seq in zip(lids, holes, eye_rings):
        m = len(loops["tuck"])
        rows = []
        for name in ("tuck", "margin", "rim"):
            start = len(p.pts)
            p.pts.extend(loops[name])
            rows.append(list(range(start, start + m)))
            for i, q in enumerate(loops.get(name + "_paint", ())):
                uv_at[start + i] = q
        for ring in seq[:-1]:
            start = len(p.pts)
            p.pts.extend(skin_point(q.x, q.y, carve, lv["edge"]) for q in ring)
            rows.append(list(range(start, start + len(ring))))
        rows.append([by_input[i] for i in hole])
        for a, b in zip(rows, rows[1:]):
            ma = len(a)
            for i in range(ma):
                i1 = (i + 1) % ma
                if len(b) == ma:
                    quad(a[i], a[i1], b[i1], b[i])
                else:  # twice the points outside: three triangles per quad
                    bm, bl, br = b[2 * i + 1], b[2 * i], b[(2 * i + 2) % len(b)]
                    tri(a[i], a[i1], bm)
                    tri(a[i], bm, bl)
                    tri(a[i1], br, bm)

        _eyeball(eye, lv, k.density, p, tri, quad, uv_fixed)

    if lv["hem_seg"]:
        _hem(p, lv, k.tile("knit"), KnitGrid(k.lv), perim)

    if keep is not None:
        cull(p, keep)
    return p


def _lid_loops(lv: dict, density: float) -> list:
    """The lid loops of each eye, (eye, {loop name: points}): the outer loop (in (s, z)) a hole in the skin."""
    lids = []
    n = max(8, int(round(lv["lid_seg"] * min(1.25, density))))
    if lv["lid_seg"] >= LID_SEG_FULL:
        n = int(round(lv["lid_seg"] * (1.0 + LID_SEG_GAIN * max(density - 1.0, 0.0))))
    for eye in EYES:
        loops = {"tuck": [], "margin": [], "rim": [], "out": [], "tuck_paint": [], "margin_paint": [],
                 "rim_paint": []}
        for i in range(n):
            t = math.tau * i / n
            u0, v0 = fissure(t)
            loops["tuck"].append(eye.surface(u0, v0, -LID_TUCK))
            for name, f in (("tuck_paint", 1.0), ("margin_paint", 1.06)):
                uf, vf = fissure_scaled(t, f, f)
                loops[name].append(Vector((eye.x_of(uf), eye.front.y, eye.front.z + vf)))
            loops["margin"].append(eye.surface(u0, v0, LID_MARGIN_OUT))
            u1, v1 = fissure_scaled(t, *LID_L1)
            loops["rim"].append(Vector((eye.x_of(u1), float(eye.shell_y(u1, v1)), eye.front.z + v1)))
            loops["rim_paint"].append(Vector((eye.x_of(u1), eye.front.y, eye.front.z + v1)))
            u2, v2 = lid_out(t)
            loops["out"].append((skin_s(eye.x_of(u2), eye.front.z + v2, lv["edge"]), eye.front.z + v2))
        lids.append((eye, loops))
    return lids


def _eyeball(eye, lv: dict, density: float, p: Part, tri, quad, uv_fixed: dict) -> None:
    """The eyeball: a cap round the cornea out past the fissure (under the lids), the cornea a touch proud. Its
    points take their paint from the eye's own patch of the map."""
    seg = max(6, int(round(lv["eye_seg"] * min(1.25, density))))

    def point(u: float, v: float, out: float) -> int:
        p.pts.append(eye.surface(u, v, out))
        uv_fixed[len(p.pts) - 1] = eye.patch(u, v)
        return len(p.pts) - 1

    apex = point(0.0, 0.0, 0.0003)
    ring_idx = []
    for share in lv["eye_rings"]:
        bulge = 0.0003 * (1.0 - smoothstep(0.15, 0.42, share))
        ring = []
        for i in range(seg):
            u, v = fissure_scaled(math.tau * i / seg, *EYE_REACH)
            ring.append(point(u * share, v * share, bulge))
        ring_idx.append(ring)
    for i in range(seg):
        tri(apex, ring_idx[0][i], ring_idx[0][(i + 1) % seg])
    for a, b in zip(ring_idx, ring_idx[1:]):
        for i in range(seg):
            i1 = (i + 1) % seg
            quad(a[i], b[i], b[i1], a[i1])


def _hem(p: Part, lv: dict, knit_tile, knit: "KnitGrid", length: float) -> None:
    """The hem: a rolled knit edge over the opening's outline, its outer side tucked under the knit, its inner side
    under the skin."""
    path2 = rounded_rect(0.0, lv["hem_seg"], lv["hem_corner"], lv.get("hem_nose", ()))
    hem_n = len(path2)
    prof = lv["hem"]
    rows = []
    for s, z in path2:
        base_pt = hs.head_point(s / R_REF, z)
        e = 0.0008
        ns_ = hs.head_point((s + e) / R_REF, z) - hs.head_point((s - e) / R_REF, z)
        nz_ = hs.head_point(s / R_REF, z + e) - hs.head_point(s / R_REF, z - e)
        normal = ns_.cross(nz_).normalized()
        if normal.dot(Vector((base_pt.x, base_pt.y, 0.0))) < 0.0:
            normal = -normal
        # Inward (toward the opening's middle) along the surface.
        g = Vector((float(opening_sdf(s + e, z) - opening_sdf(s - e, z)),
                    float(opening_sdf(s, z + e) - opening_sdf(s, z - e))))
        g.normalize()
        target = hs.head_point((s - g.x * 0.002) / R_REF, z - g.y * 0.002)
        inward = target - base_pt
        inward = (inward - normal * inward.dot(normal)).normalized()
        row = []
        for a, b in prof:
            q = base_pt + inward * a
            if a < 0.0:  # under the knit: follow its faces' chords, which cut inside the true surface
                b += knit.drop(math.atan2(q.x, -q.y), q.z)
            row.append(q + normal * b)
        rows.append(row)
    rows.append(rows[0])
    hem_rows = [[rows[j][i] for j in range(len(rows))] for i in range(len(prof))]
    p.grid(hem_rows, GEAR,
           lambda i, j: knit_tile.uv(0.5 + 0.5 * (i / hem_n) * length / KNIT_ROUND - 0.15, 0.62 + 0.012 * j))


def _inside(q: Vector, poly: list) -> bool:
    inside = False
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        if (a.y > q.y) != (b.y > q.y):
            x = a.x + (q.y - a.y) * (b.x - a.x) / (b.y - a.y)
            if x > q.x:
                inside = not inside
    return inside


# ------------------------------------------------------------------------------------------------------- knit hole

def with_lines(values: list, lines: list, close: float = 0.2) -> list:
    """`values` (sorted) with each of `lines` in it: the nearest value moved onto a line when it is within `close` of
    the local spacing, else the line inserted."""
    out = list(values)
    for line in lines:
        i = min(range(len(out)), key=lambda k: abs(out[k] - line))
        spacing = abs(out[min(i + 1, len(out) - 1)] - out[max(i - 1, 0)]) / 2.0
        if abs(out[i] - line) < close * spacing:
            out[i] = line
        else:
            out.append(line)
            out.sort()
    return out


class KnitGrid:
    """The opening head's knit grid (headwear.head with `opening`): how far its flat faces lie inside the true
    surface at a point (negative), for tucking the hem under them."""

    def __init__(self, lv: dict):
        self.azs = with_lines(hs.head_azimuths(lv["around"]), [-HOLE_AZ, HOLE_AZ])
        self.zs = with_lines(hs.head_rings(lv["around"], lv["rings"])[0], [HOLE_Z0, HOLE_Z1])

    @staticmethod
    def _cell(values: list, x: float) -> tuple:
        i = max(0, min(len(values) - 2, bisect.bisect_right(values, x) - 1))
        t = (x - values[i]) / max(values[i + 1] - values[i], 1e-9)
        return i, min(max(t, 0.0), 1.0)

    def drop(self, az: float, z: float) -> float:
        i, ta = self._cell(self.azs, az)
        j, tz = self._cell(self.zs, z)
        r = 0.0
        for di, wa in ((0, 1.0 - ta), (1, ta)):
            for dj, wz in ((0, 1.0 - tz), (1, tz)):
                r += wa * wz * hs.head_radius(self.azs[i + di], self.zs[j + dj])
        return min(0.0, r - hs.head_radius(az, z))


def cut_hole(p: Part) -> None:
    """Drops the head's faces inside the knit's hole (all corners within the rectangle: its edges are grid lines)."""
    eps = 1e-6

    def outside(q: Vector) -> bool:
        return abs(math.atan2(q.x, -q.y)) > HOLE_AZ + eps or not HOLE_Z0 - eps <= q.z <= HOLE_Z1 + eps

    cull(p, outside)
