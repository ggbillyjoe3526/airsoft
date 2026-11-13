"""The heads' texture atlas, painted with numpy (BL11, 2026-11-05): tools/blender/figures/headwear.py.

The fabrics carry their weave, seams and stitching as colour and a little height (the normal map). Since MQ3B
(2026-11-13) every tile is also drawn as what it is made of, used: a helmet's paint has its fine peel, scuffs and
rubbed crown, moulded polymer its grain and worn edges, cloth its fade and dust, the steel mesh its chipped paint.
The ear defenders' cups and cushions and the goggles' frame have tiles of their own; the small hard parts are flat
swatches and get their detail from the geometry. Every pattern is drawn at its real size for the part that covers
its tile, and none is a letter, a label or a maker's mark.
"""

import math
import os

import numpy as np

import face
import face_paint
from headkit import Atlas, dashes, hash01 as _hash, lines, noise as _noise, soft_box, soft_disc, soft_round_box

KNIT_Z0 = 1.43
KNIT_SPAN = 0.30

# Colours (sRGB) by what they are. Team surfaces are painted light and tinted in game.
SWATCHES = {
    "shell_inside": (0x232425, 0.9), "high_trim": (0x1f2021, 0.6), "full_trim": (0x2a2723, 0.7),
    "screw": (0x2e3031, 0.45), "shroud_block": (0x141516, 0.7), "shroud_frame": (0x4b4a47, 0.5),
    "buckle": (0x1b1c1d, 0.45),
    "chin_cup": (0x2a2b2c, 0.8), "defender": (0x6b6651, 0.55), "cushion": (0x1c1c1d, 0.7),
    "headset": (0x2a2b2c, 0.5), "rail_dark": (0x242526, 0.5), "mic": (0x1d1e1f, 0.5), "mic_foam": (0x161616, 0.95),
    "goggle_frame": (0x34373a, 0.5), "goggle_foam": (0x4a4c4e, 0.95), "glasses_frame": (0x202122, 0.4),
    "nose_pad": (0x3a3b3c, 0.6), "mask_binding": (0x565a40, 0.85), "snap": (0x4c503b, 0.5),
    "boonie_edge": (0x515a46, 0.85), "eyelet": (0x4f513f, 0.45), "cord": (0x4e5743, 0.8), "toggle": (0x2b2c2a, 0.6),
    "cap_inside": (0x45382a, 0.9), "cap_button": (0x5f4c38, 0.8), "cap_edge": (0x5f4c38, 0.85),
    "cap_strap": (0x232425, 0.6),
}

HIGH_SHELL = 0x545350
FULL_COVER = 0x665640
LOOP_DARK = 0x2a2c2d
LOOP_COYOTE = 0x5b4e3a
TEAM_LIGHT = 0xe4e4e4
DEFENDER = 0x6b6651
HEADSET = 0x2a2b2c
CUSHION = 0x1c1c1d
GOGGLE_FRAME = 0x34373a
BARE_STEEL = 0x8a8d86
DUST = 0x8b8370

SHELL_R = 0.11             # m: a helmet shell's radius, for patterns drawn on it at their real size
SHELL_T = (-25.0, 115.0)   # degrees: a shell tile's t is the elevation from the first, over the second (headwear.py)
## An ear defender's cup, from its cushion out to the middle of its outer face: (m out from the head, m radius) of
## each ring headwear.py builds, the last the centre. A cup tile's t is the way along this line, s the way round.
CUP_PROFILE = ((0.017, 0.044), (0.021, 0.047), (0.034, 0.045), (0.042, 0.037), (0.046, 0.024), (0.047, 0.0))
CUP_SQUASH = 0.8           # a cup is this much narrower front to back than it is tall
## A cup's side wall, from the cushion to ring CUP_SPLIT, is unrolled into a strip; from that ring inward its shoulder
## and face lie flat on a square tile CUP_FACE_SPAN metres across, so what is drawn there has one scale every way
## (unrolled to its middle, a tile is far finer round the cup than across it, and any grain comes out as rings).
CUP_SPLIT = 2
CUP_FACE_SPAN = 0.094
CUP_PEEL = (0.0030, 0.07, 0.22)  # m across, roughness either way, pixels deep: the moulded shell's orange peel
CUP_RUB = (0.011, 0.16, 0.035)   # m across, roughness lost, m across the handled side: the shoulder's rubbed
#                            patches
CUP_JOINT = 0.0008         # m, half the width of the joint between a cup and its back plate
## An ear cushion's rings, the same way (its tile's t runs across them).
## The boonie crown's tile runs this many metres over the cloth, from the band's foot up the wall and over the
## shoulder to the seam round the top panel (the ring at BOONIE_TOP_F of the top's radius). The top panel lies flat on
## a square tile of its own, BOONIE_TOP_SPAN metres across.
BOONIE_RUN = 0.0764
BOONIE_TOP_F = 0.85
BOONIE_TOP_SPAN = 0.150
BOONIE_TOP_SEAM = 0.0735   # m over the cloth: the stitched seam just under the top panel's edge
BOONIE_SUN = 0.16          # share paler: the top of the hat, where the sun sits
BOONIE_SWEAT = (0.036, 0.0018, 0.006, 0.24, 0.05)   # m: the sweat mark's edge above the band's foot, its wander,
#                            its soft edge; the share darker under it, the share paler along its salt line
CUSHION_PROFILE = ((0.0, 0.040), (0.004, 0.047), (0.012, 0.049), (0.017, 0.046))
## A strip swept along a path (the mesh mask's binding, the headset's band) draws from a short tile: s runs along the
## path and turns back every RUN metres (headwear.py lays it back and forth, so the strip has no seam), t goes round
## its four-sided profile, each side between two of these.
BINDING = 0x565a40
BINDING_RUN = 0.12
BINDING_T = (0.0, 0.4, 0.5, 0.9, 1.0)      # a wide face, the fold, the other wide face, the fold
BINDING_WIDTH = 0.009                      # m: a wide face
HEADBAND_RUN = 0.18
HEADBAND_T = (0.0, 0.3, 0.375, 0.925, 1.0)   # the underside, an edge, the top, the other edge
HEADBAND_WIDTH = 0.022                     # m: the top
SWATCH_ROWS = 64           # px: the swatches keep to the atlas's lowest rows; the cups' tiles lie above them
KNIT = 0x27292b
BOONIE = 0x58614c
CAP = 0x6c5842
STEEL = 0x5b5f47
SHEMAGH = 0xbcaa84
SHEMAGH_CHECK = 0x6c593d


def paint() -> Atlas:
    a = Atlas()
    for name, (colour, rough) in SWATCHES.items():
        a.swatch(name, colour, rough)
    assert len(a.swatches) * a.SWATCH * a.SWATCH <= a.SWATCH_AREA * SWATCH_ROWS, "the swatches reach the cups' tiles"
    _cup(a.tile("cup_defender", 0, 64, 512, 64), DEFENDER, 0.55, 11, False)
    _cup(a.tile("cup_headset", 0, 128, 512, 64), HEADSET, 0.62, 12, False)
    _cup(a.tile("cup_face_defender", 1152, 896, 128, 128), DEFENDER, 0.55, 11, True)
    _cup(a.tile("cup_face_headset", 1280, 896, 128, 128), HEADSET, 0.62, 12, True)
    _binding(a.tile("binding", 0, 192, 256, 64))
    _headband(a.tile("headband", 256, 192, 256, 64))
    _goggle_frame(a.tile("goggle_frame", 1024, 384, 512, 64))
    _cushion(a.tile("cushion", 1024, 448, 512, 64))
    _knit(a.tile("knit", 512, 0, 1024, 384))
    a.face = face_paint.paint()  # the face's own map (MQ3C); its old cells over the swatches stay empty
    _loop(a.tile("loop_cap", 512, 384, 512, 128), 0x5a4936, 0x4a3b2b)
    _mesh(a.tile("mesh", 1536, 0, 512, 512))
    _shemagh(a.tile("shemagh", 0, 512, 1024, 512))
    _brim(a.tile("brim", 1024, 512, 1024, 256))
    _boonie_crown(a.tile("boonie_crown", 1024, 768, 512, 128))
    _boonie_top(a.tile("boonie_top", 1024, 896, 128, 128))
    _cap_crown(a.tile("cap_crown", 1536, 768, 512, 256))
    _cap_brim(a.tile("cap_brim", 0, 1024, 512, 256))
    _loop(a.tile("loop", 512, 1024, 512, 256), LOOP_DARK, 0x1f2021)
    _loop(a.tile("team_loop", 1024, 1024, 512, 256), TEAM_LIGHT, 0xbdbdbd, 0.06)
    _band(a.tile("band", 1536, 1024, 512, 256))
    _rail(a.tile("rail", 0, 1280, 1024, 256))
    _shell_high(a.tile("shell_high", 1024, 1280, 1024, 512))
    _shell_full(a.tile("shell_full", 0, 1536, 1024, 512))
    _shroud(a.tile("shroud", 1024, 1792, 256, 256))
    _strap(a.tile("strap", 1280, 1792, 256, 256))
    _goggle_strap(a.tile("goggle_strap", 1536, 1792, 512, 128))
    _loop(a.tile("loop_full", 1536, 1920, 512, 128), LOOP_COYOTE, 0x5a4c35)
    return a


def save(atlas: Atlas, stem: str) -> dict:
    """Writes an atlas as three WebP files, all without loss (Blender's quality 100); returns their paths by kind.
    A lossy colour map smeared each tile's edge into its neighbour, and a tile that goes round a part showed that as
    a line where its two ends meet (MQ3B). Image.save writes the pixels as painted (save_render would put them
    through the scene's view transform)."""
    images = atlas.images(os.path.basename(stem))
    out = {}
    for key, im in images.items():
        path = "%s_%s.webp" % (stem, key)
        im.filepath_raw = path
        im.file_format = "WEBP"
        im.save(filepath=path, quality=100)
        out[key] = path
    return out


# ------------------------------------------------------------------------------------------------- used surfaces

def _grain(t, pos: tuple, size: float, depth: float, seed: int, wrap: float = 0.0) -> None:
    """A fine even grain in the height alone: paint's peel, moulded polymer's pebble."""
    t.view("height")[:] += depth * _noise(pos[0], pos[1], size, seed, wrap, pos[2])


def _tone(t, pos: tuple, cell: float, share: float, seed: int, wrap: float = 0.0) -> None:
    """Soft patches a share lighter and darker: dye and dust that never lie even."""
    t.shade(1.0 + share * _noise(pos[0], pos[1], cell, seed, wrap, pos[2]))


def _scuffs(t, pos: tuple, marks: list, light: float, rough: float, dent: float = 0.4) -> None:
    """Straight scratches, each (a point, a second point, half its width) in metres: a shade lighter, duller and a
    little sunk."""
    m = np.zeros(pos[0].shape, np.float32)
    for a, b, half in marks:
        ab = [b[k] - a[k] for k in range(3)]
        ln = sum(c * c for c in ab) or 1e-12
        u = sum((pos[k] - a[k]) * ab[k] for k in range(3)) / ln
        u = np.clip(u, 0.0, 1.0)
        d2 = sum((pos[k] - (a[k] + ab[k] * u)) ** 2 for k in range(3))
        ends = np.minimum(u, 1.0 - u) * 6.0 + 0.25  # a scratch thins out at its ends
        m = np.maximum(m, np.clip(1.0 - np.sqrt(d2) / (half * np.minimum(ends, 1.0)), 0.0, 1.0))
    t.shade(1.0 + light * m)
    r = t.view("rough")
    r[:] = np.clip(r + rough * m, 0.0, 1.0)
    t.view("height")[:] -= dent * m


def _marks_on_ball(count: int, radius: float, el: tuple, length: tuple, half: tuple, seed: int) -> list:
    """Scratches scattered on a shell between two elevations (degrees), each lying on its surface."""
    rng = np.random.default_rng(seed)
    out = []
    for _ in range(count):
        az = rng.uniform(-math.pi, math.pi)
        e = math.radians(rng.uniform(el[0], el[1]))
        p = np.array((math.cos(e) * math.sin(az), -math.cos(e) * math.cos(az), math.sin(e)))
        side = np.cross(p, (0.0, 0.0, 1.0))
        side /= np.linalg.norm(side) or 1.0
        up = np.cross(side, p)
        turn = rng.uniform(0.0, math.pi)
        along = (side * math.cos(turn) + up * math.sin(turn)) * rng.uniform(length[0], length[1]) * 0.5
        out.append((tuple(p * radius - along), tuple(p * radius + along), rng.uniform(half[0], half[1])))
    return out


def _st(t) -> tuple:
    """Each pixel's (s, t) as a part's UVs reach it (Tile.uv keeps a pixel in from the tile's edges), so that what
    is drawn round a part meets itself exactly where the tile's two ends meet on it."""
    return (t.s * t.w - 1.0) / (t.w - 2.0), (t.t * t.h - 1.0) / (t.h - 2.0)


def _shell_pos(t) -> tuple:
    """Where each pixel of a shell tile lies on the shell (metres from its centre), and its elevation in degrees."""
    s, tt = _st(t)
    az = (s - 0.5) * math.tau
    el_deg = SHELL_T[0] + tt * SHELL_T[1]
    el = np.radians(el_deg)
    return (SHELL_R * np.cos(el) * np.sin(az), -SHELL_R * np.cos(el) * np.cos(az), SHELL_R * np.sin(el)), el_deg


def _flat_pos(x, y) -> tuple:
    return (x, y, None)


def _worn_cloth(t, x, y, seed: int, wrap: float = 0.0, fade: float = 0.09, mottle: float = 0.045) -> None:
    """Cloth that has been out: broad sun and dust patches, a finer uneven dye."""
    pos = _flat_pos(_st(t)[0] * wrap if wrap > 0.0 else x, y)
    _tone(t, pos, 0.055, fade, seed, wrap)
    _tone(t, pos, 0.014, mottle, seed + 1, wrap)


def _tide(t, top: float, wrap: float, seed: int, wander: float = 0.045, soft: float = 0.03, dark: float = 0.11,
          salt: float = 0.05) -> None:
    """A sweat mark up from the bottom of a crown's tile to about `top` (t): darker cloth under an edge that wanders
    by `wander` (t), and the pale line the salt leaves along it."""
    s, tt = _st(t)
    edge = top + wander * _noise(s * wrap, np.zeros_like(s), 0.03, seed, wrap) + wander / 3.0 * _noise(
        s * wrap, np.zeros_like(s), 0.008, seed + 1, wrap)
    under = np.clip((edge - tt) / soft, 0.0, 1.0)
    line = np.exp(-((tt - edge - 0.4 * soft) / (0.4 * soft)) ** 2)
    t.shade(1.0 - dark * under + salt * line)


def boonie_t(run: float) -> float:
    """The t in the boonie crown's tile of a place `run` metres over the cloth from the band's foot (headwear.py lays
    the wall's and the shoulder's rings with it)."""
    return min(run / BOONIE_RUN, 1.0)


def _along(profile: tuple, t, squash: float = 1.0) -> tuple:
    """For a tile whose t runs along `profile` (rings out from the head: m out, m radius) and whose s runs round
    it: each pixel's place in metres (out, forward, up), and the t of every ring."""
    steps = [math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(profile, profile[1:])]
    at = np.concatenate([[0.0], np.cumsum(steps)]) / sum(steps)
    s, tt = _st(t)
    out = np.interp(tt, at, [q[0] for q in profile])
    r = np.interp(tt, at, [q[1] for q in profile])
    ang = s * math.tau
    return (out, r * squash * np.cos(ang), r * np.sin(ang)), at


def ring_t(profile: tuple, ring: int) -> float:
    """The t of ring `ring` of `profile` in its tile (headwear.py lays the part's UVs with it)."""
    steps = [math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(profile, profile[1:])]
    return sum(steps[:ring]) / sum(steps)


# --------------------------------------------------------------------------------------------------- the tiles

def _cup_place(t, face: bool) -> tuple:
    """Each pixel's place on an ear cup, in its side wall's strip or on its face's flat tile: (m out from the head,
    m forward, m up), its distance in metres along the cup's profile from the cushion, and each ring's distance."""
    steps = [math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(CUP_PROFILE, CUP_PROFILE[1:])]
    along = np.concatenate([[0.0], np.cumsum(steps)])
    outs = [q[0] for q in CUP_PROFILE]
    radii = [q[1] for q in CUP_PROFILE]
    s, tt = _st(t)
    if face:
        forward = (s - 0.5) * CUP_FACE_SPAN
        up = (tt - 0.5) * CUP_FACE_SPAN
        r = np.hypot(forward / CUP_SQUASH, up)
        # From the split ring inward a ring's radius falls all the way to the middle.
        path = np.interp(r, radii[:CUP_SPLIT - 1:-1], along[:CUP_SPLIT - 1:-1])
    else:
        path = tt * along[CUP_SPLIT]
        r = np.interp(path, along, radii)
        forward = r * CUP_SQUASH * np.cos(s * math.tau)
        up = r * np.sin(s * math.tau)
    return (np.interp(path, along, outs), forward, up), path, along


def _cup(t, colour: int, rough: float, seed: int, face: bool) -> None:
    """An ear defender's moulded cup, its side wall's strip or its face's flat tile: satin polymer with the mould's
    shallow orange peel, the joint to its back plate, its shoulder rubbed lighter in broken patches, a few scratches
    on its face. Everything is drawn from a pixel's place on the cup, so the two tiles meet without a mark."""
    t.fill(colour, rough)
    pos, path, along = _cup_place(t, face)
    peel = _noise(pos[0], pos[1], CUP_PEEL[0], seed, 0.0, pos[2])
    r = t.view("rough")
    r[:] = np.clip(r + CUP_PEEL[1] * peel, 0.0, 1.0)
    if face:
        # Only the flat tile has one scale every way: the strip is finer across the wall than round it.
        t.view("height")[:] += CUP_PEEL[2] * peel
    # No faint tone in the colour: the game's block-compressed map turns a near-even colour's drift into squares
    # and stains, which a cup this smooth shows. Its colour changes only at the joint and where it is scratched.
    joint = np.clip(1.0 - np.abs(path - along[1]) / CUP_JOINT, 0.0, 1.0)
    t.paint(joint, add_height=-1.2)
    t.shade(1.0 - 0.22 * joint)
    # Rubbed smoother where it is set down and handled: patches on the shoulder, on one side more than the other,
    # fading into the face and the rim with no edge of their own. A rub shows in the sheen, not the colour.
    window = np.sin(math.pi * np.clip((path - along[1]) / (along[4] - along[1]), 0.0, 1.0)) ** 2
    side = np.clip(0.5 + 0.9 * _noise(pos[0], pos[1], CUP_RUB[2], seed + 3, 0.0, pos[2]), 0.0, 1.0)
    patch = np.clip(_noise(pos[0], pos[1], CUP_RUB[0], seed + 2, 0.0, pos[2]) * 1.8 - 0.35, 0.0, 1.0)
    rub = window * side * patch
    r[:] = np.clip(r - CUP_RUB[1] * rub, 0.0, 1.0)
    if not face:
        return
    rng = np.random.default_rng(seed)
    marks = []
    for _ in range(5):
        a = rng.uniform(0.0, math.tau)
        rr = rng.uniform(0.004, 0.03)
        c = np.array((0.045, rr * CUP_SQUASH * math.cos(a), rr * math.sin(a)))
        d = rng.uniform(0.0, math.pi)
        half = np.array((0.0, math.cos(d), math.sin(d))) * rng.uniform(0.003, 0.011)
        marks.append((tuple(c - half), tuple(c + half), rng.uniform(0.0004, 0.0008)))
    _scuffs(t, (np.full_like(pos[1], 0.045), pos[1], pos[2]), marks, 0.12, 0.15)


def _cushion(t) -> None:
    """An ear cushion (s round it, t across it from the head out to the cup): soft leatherette with its fine creases
    running across, a welded seam round its middle, a duller rubbed outer edge."""
    t.fill(CUSHION, 0.55)
    pos, at = _along(CUSHION_PROFILE, t, CUP_SQUASH)
    round_m = _st(t)[0] * 0.27
    crease = _noise(round_m, t.t * 0.004, 0.0009, 21, 0.27)
    t.view("height")[:] += 0.2 * crease
    t.shade(1.0 + 0.05 * crease)
    _tone(t, pos, 0.01, 0.04, 22)
    seam = np.clip(1.0 - np.abs(t.t - at[2]) / 0.05, 0.0, 1.0)
    t.paint(seam, add_height=-1.0)
    t.shade(1.0 - 0.2 * seam)
    worn = np.clip((t.t - at[2]) / (1.0 - at[2]), 0.0, 1.0) * np.clip(_noise(round_m, t.t * 0.02, 0.008, 23, 0.27) + 0.5,
                                                                    0.0, 1.0)
    t.shade(1.0 + 0.10 * worn)
    r = t.view("rough")
    r[:] = np.clip(r + 0.2 * worn, 0.0, 1.0)


def strip_s(metres: float, run: float) -> float:
    """Where along a strip's tile a point `metres` along its path draws from: forth, then back, every `run`."""
    u = (metres / run) % 2.0
    return u if u <= 1.0 else 2.0 - u


def _binding(t) -> None:
    """The mesh mask's binding (s along it, t round it by BINDING_T): olive twill tape folded over the mesh's edge,
    a row of stitches through both faces near the edge it ends at, the folds rubbed paler, dust in patches."""
    t.fill(BINDING, 0.85)
    s, tt = _st(t)
    x = s * BINDING_RUN
    wide = np.zeros_like(x)
    for lo, hi, row in ((BINDING_T[0], BINDING_T[1], 0.72), (BINDING_T[2], BINDING_T[3], 0.28)):
        v = (tt - lo) / (hi - lo)
        on = ((v >= 0.0) & (v <= 1.0)).astype(np.float32)
        y = v * BINDING_WIDTH
        twill = lines(x + y, 0.0016, 0.0006, 0.0003) * on
        t.paint(twill, add_height=0.4)
        t.shade(1.0 - 0.09 * twill)
        stitch = dashes(x, y - row * BINDING_WIDTH, 1.0, 0.0028, 0.0014, 0.0008, 0.0003) * on
        t.paint(stitch * 0.9, 0x40442f, add_height=0.8)
        wide = np.maximum(wide, on)
    pos = _flat_pos(x, tt * 0.026)
    _tone(t, pos, 0.02, 0.08, 201)
    t.shade(1.0 + 0.10 * (1.0 - wide))
    t.paint(0.22 * np.clip(_noise(x, tt * 0.026, 0.012, 202) + 0.1, 0.0, 1.0), DUST)


def _headband(t) -> None:
    """The headset's band over the cap (s along it, t round it by HEADBAND_T): padded leatherette quilted across
    every 30 mm, a stitch row inside each edge of its top, the pads' crowns rubbed duller and paler."""
    t.fill(HEADSET, 0.5)
    s, tt = _st(t)
    x = s * HEADBAND_RUN
    pos = _flat_pos(x, tt * 0.06)
    _grain(t, pos, 0.0008, 0.12, 211)
    _tone(t, pos, 0.02, 0.05, 212)
    v = (tt - HEADBAND_T[2]) / (HEADBAND_T[3] - HEADBAND_T[2])
    top = ((v >= 0.0) & (v <= 1.0)).astype(np.float32)
    y = v * HEADBAND_WIDTH
    quilt = lines(x, 0.03, 0.0012, 0.0008) * top
    pad = np.sin(np.clip(v, 0.0, 1.0) * math.pi) * np.abs(np.sin(x / 0.03 * math.pi)) * top
    t.view("height")[:] += 2.0 * pad
    t.paint(quilt, add_height=-1.0)
    t.shade(1.0 - 0.22 * quilt)
    for at in (0.003, HEADBAND_WIDTH - 0.003):
        stitch = dashes(x, y - at, 1.0, 0.0028, 0.0014, 0.0008, 0.0003) * top
        t.paint(stitch * 0.9, 0x414243, add_height=0.6)
    rub = pad * np.clip(_noise(x, y, 0.012, 213) + 0.6, 0.0, 1.0)
    t.paint(rub * 0.5, rough=0.68)
    t.shade(1.0 + 0.12 * rub)


def _goggle_frame(t) -> None:
    """The goggles' rubber frame (s round it, t from the lens's edge back to the gasket): matte rubber with a fine
    grain, its lip rubbed a shade lighter, dust lying toward the face."""
    t.fill(GOGGLE_FRAME, 0.72)
    x = _st(t)[0] * 0.5
    y = t.t * 0.022
    pos = _flat_pos(x, y)
    _grain(t, pos, 0.0006, 0.1, 31, 0.5)
    _tone(t, pos, 0.015, 0.04, 32, 0.5)
    lip = np.clip(1.0 - np.abs(t.t - 1.0 / 3.0) / 0.12, 0.0, 1.0) * np.clip(_noise(x, y, 0.01, 33, 0.5) + 0.6, 0.0, 1.0)
    t.shade(1.0 + 0.12 * lip)
    dust = np.clip((t.t - 0.55) / 0.45, 0.0, 1.0) * np.clip(_noise(x, y, 0.02, 34, 0.5) * 0.6 + 0.6, 0.0, 1.0)
    t.paint(dust * 0.22, DUST, 0.9)


def _knit(t) -> None:
    """The balaclava: fine ribs round the head (the eye opening is cut in the mesh; face.py fills it)."""
    t.fill(KNIT, 0.95)
    x = t.s * face.KNIT_ROUND  # metres round the head at the face
    y = t.t * KNIT_SPAN
    rib = lines(x, 0.0032, 0.0012, 0.0004)
    t.paint(np.ones_like(rib), height=0.0)
    t.paint(rib, add_height=1.2)
    t.shade(1.0 - 0.10 * rib)
    _worn_cloth(t, x, y, 41, face.KNIT_ROUND, fade=0.05, mottle=0.03)
    # Pilling: small pale bobbles where a knit has rubbed.
    pill = np.clip(_noise(_st(t)[0] * face.KNIT_ROUND, y, 0.0016, 43, face.KNIT_ROUND) * 2.0 - 1.25, 0.0, 1.0)
    t.shade(1.0 + 0.35 * pill)
    t.paint(pill, add_height=0.6)


def _mesh(t) -> None:
    """Painted steel mesh: square wires 3 mm apart, the face's shadow through the holes."""
    t.fill(0x1c1e16, 0.7, height=-1.5)
    x = t.s * 0.26
    y = t.t * 0.13
    wire = np.maximum(lines(x, 0.003, 0.0009, 0.00025), lines(y, 0.003, 0.0009, 0.00025))
    t.paint(wire, STEEL, 0.45, height=1.5)
    # The paint chips off a steel mask: at wire crossings here and there, and in small round patches where BBs
    # have struck it, the bare steel shows.
    chip = (_hash(np.floor(x / 0.003).astype(np.int64), np.floor(y / 0.003).astype(np.int64), np.zeros(x.shape, np.int64),
                  51) > 0.84).astype(np.float32)
    rng = np.random.default_rng(52)
    struck = np.zeros_like(x)
    for _ in range(34):
        cx, cy, r = rng.uniform(0.02, 0.24), rng.uniform(0.02, 0.11), rng.uniform(0.0025, 0.0050)
        struck = np.maximum(struck, np.clip(1.5 - np.hypot(x - cx, y - cy) / r, 0.0, 1.0))
    bare = wire * np.clip(chip * 0.8 + struck, 0.0, 1.0)
    t.paint(bare * 0.85, BARE_STEEL, 0.32)
    t.shade(1.0 + 0.05 * _noise(x, y, 0.03, 53) * wire)


def _shemagh(t) -> None:
    """The sand scarf: a woven check of brown lines, a darker band near the hem."""
    t.fill(SHEMAGH, 0.95)
    x = t.s * 0.62
    y = t.t * 0.16
    weave = lines(x, 0.0016, 0.0006, 0.0003) * 0.5 + lines(y, 0.0016, 0.0006, 0.0003) * 0.5
    t.paint(np.ones_like(weave), add_height=0.0)
    t.paint(weave, add_height=0.6)
    # The classic pattern: thin paired lines in a 16 mm check, small solid squares where they cross.
    lx = lines(x, 0.016, 0.0011, 0.0003) + lines(x + 0.0022, 0.016, 0.0011, 0.0003)
    ly = lines(y, 0.016, 0.0011, 0.0003) + lines(y + 0.0022, 0.016, 0.0011, 0.0003)
    cross = soft_box(np.mod(x + 0.0011, 0.016), np.mod(y + 0.0011, 0.016), 0.0, 0.0044, 0.0, 0.0044, 0.0003)
    t.paint(np.clip(lx + ly, 0, 1) * 0.55, SHEMAGH_CHECK)
    t.paint(cross * 0.8, SHEMAGH_CHECK)
    band = soft_box(t.s, t.t, -1, 2, 0.06, 0.12, 0.004)
    t.paint(band * 0.7, 0x7a6544)
    _worn_cloth(t, x, y, 61, 0.62, fade=0.06, mottle=0.03)


def _ripstop(t, x, y, strength: float = 0.05, height: float = 0.4) -> None:
    grid = np.maximum(lines(x, 0.005, 0.0004, 0.0002), lines(y, 0.005, 0.0004, 0.0002))
    t.shade(1.0 - strength * grid)
    t.paint(grid, add_height=height)


def _stitch_row(t, along, across, at: float, colour: int, scale: float = 1.0) -> None:
    st = dashes(along, across - at, 1.0, 0.0028 * scale, 0.0014 * scale, 0.0008 * scale, 0.0003)
    t.paint(st * 0.9, colour, add_height=0.8)


def _brim(t) -> None:
    """The boonie's brim, round (s) and out from the crown (t: 0.5 up to 1 on top, down to 0 underneath): rows of
    stitching every 7 mm, the fabric's ripstop."""
    t.fill(BOONIE, 0.9)
    x = t.s * 0.78
    width = 0.066
    d = np.abs(t.t - 0.5) * 2.0 * width
    _ripstop(t, x, d)
    rows = lines(d - 0.0045, 0.0068, 0.0009, 0.0003)
    stitch = rows * (((x / 0.0042) % 1.0) < 0.66)
    groove = lines(d - 0.0045 + 0.0034, 0.0068, 0.0016, 0.0006)
    t.paint(groove, add_height=-0.8)
    t.shade(1.0 - 0.10 * groove)
    t.paint(stitch * 0.8, 0x48503f, add_height=0.6)
    under = soft_box(t.s, t.t, -1, 2, -1, 0.5, 0.002)
    t.shade(1.0 - 0.1 * under)
    _worn_cloth(t, x, d, 71, 0.78)
    # The sun fades the top of a brim, and its edge frays a shade paler.
    t.shade(1.0 + 0.10 * (1.0 - under))
    fray = np.clip((d - (width - 0.005)) / 0.005, 0.0, 1.0) * np.clip(_noise(_st(t)[0] * 0.78, d, 0.006, 73, 0.78) + 0.7,
                                                                    0.0, 1.0)
    t.shade(1.0 + 0.18 * fray)


def _seams(t, x, along, pitch_s: float, colour: int) -> None:
    """Vertical panel seams every `pitch_s` of s, each with a stitch row either side."""
    seam = lines(t.s, pitch_s, 0.0015, 0.0008)
    t.paint(seam, add_height=-1.5)
    t.shade(1.0 - 0.18 * seam)
    for off in (-0.0042, 0.0042):
        st = lines(t.s + off / 0.68, pitch_s, 0.0011, 0.0005) * (((along / 0.0045) % 1.0) < 0.6)
        t.paint(st * 0.8, colour, add_height=0.6)
    del x


def _boonie_crown(t) -> None:
    t.fill(BOONIE, 0.9)
    x = t.s * 0.68
    y = t.t * BOONIE_RUN
    _ripstop(t, x, y)
    _seams(t, x, y, 1.0 / 6.0, 0x48503f)
    top = lines(y - BOONIE_TOP_SEAM, 10.0, 0.0013, 0.0005)
    t.paint(top, add_height=-1.2)
    t.shade(1.0 - 0.15 * top)
    _worn_cloth(t, x, y, 81, 0.68)
    # Paler toward the top, where the sun sits; a sweat-dark band just above the hat band.
    t.shade(1.0 + BOONIE_SUN * np.clip((y - 0.03) / 0.04, 0.0, 1.0))
    _tide(t, boonie_t(BOONIE_SWEAT[0]), 0.68, 83, boonie_t(BOONIE_SWEAT[1]), boonie_t(BOONIE_SWEAT[2]),
          BOONIE_SWEAT[3], BOONIE_SWEAT[4])


def _boonie_top(t) -> None:
    """The boonie's top panel, laid flat: the same ripstop, square, as sun-faded as the top of the wall."""
    t.fill(BOONIE, 0.9)
    x = (t.s - 0.5) * BOONIE_TOP_SPAN
    y = (t.t - 0.5) * BOONIE_TOP_SPAN
    _ripstop(t, x, y)
    _worn_cloth(t, x, y, 85)
    t.shade(1.0 + BOONIE_SUN)


def _cap_crown(t) -> None:
    """The tactical cap's crown: six panels, double stitching, the laser-cut side-rear panels, the edge stitching."""
    t.fill(CAP, 0.88)
    x = t.s * 0.62
    y = t.t * 0.13
    _ripstop(t, x, y, 0.02, 0.2)
    _seams(t, x, y, 1.0 / 6.0, 0x564533)
    edge = dashes(x, y - 0.006, 1.0, 0.0028, 0.0014, 0.0008, 0.0003)
    t.paint(edge * 0.9, 0x564533, add_height=0.7)
    holes = np.zeros_like(x)
    for centre in (0.5 + 122.0 / 360.0, 0.5 - 122.0 / 360.0):
        px = (x - centre * 0.62)
        region = soft_box(px, y, -0.018, 0.018, 0.016, 0.06, 0.002)
        dot = soft_disc(np.mod(px, 0.006), np.mod(y + 0.003 * (np.floor(px / 0.006) % 2), 0.006), 0.003, 0.003,
                        0.0011, 0.0003)
        holes = np.maximum(holes, dot * region)
    t.paint(holes, 0x3e3426, 0.9, add_height=-1.2)
    _worn_cloth(t, x, y, 91, 0.62)
    t.shade(1.0 + 0.16 * np.clip((t.t - 0.45) / 0.4, 0.0, 1.0))
    _tide(t, 0.20, 0.62, 93)


def _cap_brim(t) -> None:
    """The bill: rows of stitching following its edge on top, plain underneath."""
    t.fill(CAP, 0.85)
    x = t.s * 0.19
    d = (1.0 - np.abs(t.t - 0.5) * 2.0) * 0.075  # metres in from the edge
    _ripstop(t, x, d, 0.02, 0.15)
    # Five rows of stitching following the edge (photo 122905).
    rows = lines(d - 0.004, 0.0065, 0.0009, 0.0003) * (d < 0.031)
    stitch = rows * (((x / 0.0042) % 1.0) < 0.66)
    t.paint(stitch * 0.85, 0x564533, add_height=0.7)
    under = soft_box(t.s, t.t, -1, 2, -1, 0.5, 0.002)
    t.paint(under * 0.6, 0x5c513b)
    _worn_cloth(t, x, d, 101)
    # A cap's bill wears pale along its edge first.
    fray = np.clip(1.0 - d / 0.004, 0.0, 1.0) * np.clip(_noise(x, d, 0.005, 103) + 0.7, 0.0, 1.0)
    t.shade(1.0 + 0.20 * fray)


def _loop(t, colour: int, border: int, lint_share: float = 0.25) -> None:
    """Loop fabric (the patch panels): a fine, even pile and a sewn binding round the edge."""
    t.fill(colour, 0.97)
    x = t.s * 0.12
    y = t.t * 0.06
    pile = np.sin(x / 0.0011 * 6.283) * np.sin(y / 0.0011 * 6.283)
    t.paint(np.ones_like(pile), add_height=0.0)
    t.view("height")[:] += 0.6 * pile
    t.shade(1.0 + 0.05 * pile)
    # The pile mats down in patches and holds pale lint.
    _tone(t, _flat_pos(x, y), 0.012, 0.05, 111)
    lint = np.clip(_noise(x, y, 0.0013, 112) * 3.0 - 2.2, 0.0, 1.0)
    t.shade(1.0 + lint_share * lint)
    rim = 1.0 - soft_box(t.s, t.t, 0.035, 0.965, 0.07, 0.93, 0.01)
    t.paint(rim, border, 0.8, add_height=1.0)
    st = dashes(x, np.minimum(t.t, 1 - t.t) * 0.06 - 0.0028, 1.0, 0.0025, 0.0012, 0.0006, 0.0002)
    t.paint(st * 0.7, border)


def _band(t) -> None:
    """The boonie's team band: webbing with foliage loops held by bar tacks every 35 mm (painted light, tinted)."""
    t.fill(TEAM_LIGHT, 0.85)
    x = t.s * 0.66
    tack = lines(x, 0.035, 0.0022, 0.0005) * soft_box(t.s, t.t, -1, 2, 0.12, 0.88, 0.01)
    t.paint(tack, 0xb4b4b4, add_height=-0.8)
    weave = lines(t.t * 0.03, 0.0012, 0.0005, 0.0002)
    t.shade(1.0 - 0.10 * weave)
    t.paint(weave, add_height=-0.7)
    # Webbing is woven: each rib is crossed by the weft every 1.6 mm, and its selvedges are tighter and darker.
    weft = lines(x, 0.0016, 0.0005, 0.0002) * (1.0 - weave)
    t.shade(1.0 - 0.06 * weft)
    t.paint(weft, add_height=-0.3)
    edge = soft_box(t.s, t.t, -1, 2, 0.06, 0.94, 0.008)
    t.shade(0.85 + 0.15 * edge)
    _tone(t, _flat_pos(_st(t)[0] * 0.66, t.t * 0.03), 0.03, 0.04, 121, 0.66)


def _rail(t) -> None:
    """The side rail (s along it, t round its profile; the top face is t 3/6-4/6): slots every 16 mm."""
    t.fill(0x3a3c3e, 0.55)
    x = t.s * 0.2
    # Two rows of slots on the top face (photo 2): long ones above, short ones below, staggered.
    top0, top1 = 3.0 / 6, 4.0 / 6
    band = top1 - top0
    # Short slots along the top row, long ones across the rail below them (photo 2).
    upper = soft_box(np.mod(x, 0.016), t.t, 0.004, 0.012, top0 + band * 0.66, top0 + band * 0.86, 0.002)
    lower = soft_box(np.mod(x + 0.008, 0.016), t.t, 0.0065, 0.0095, top0 + band * 0.12, top0 + band * 0.56, 0.002)
    ends = soft_box(t.s, t.t, 0.03, 0.97, -1, 2, 0.004)
    slots = np.maximum(upper, lower) * ends
    # Through-slots: near black with the shell's shadow in them, only a shallow bevel in the normal (a deep one read
    # as raised blocks under the rail's mirrored UVs).
    # Moulded polymer: a fine pebble, and the corners of its section and the slots' lips rubbed paler and
    # smoother where hands and kit ride along it.
    y = t.t * 0.05
    pos = _flat_pos(x, y)
    _grain(t, pos, 0.0006, 0.12, 131)
    _tone(t, pos, 0.02, 0.04, 132)
    rub = np.clip(_noise(x, y, 0.012, 133) * 0.7 + 0.6, 0.0, 1.0)
    corners = lines(t.t, 1.0 / 6.0, 0.012, 0.008) * rub
    gy, gx = np.gradient(slots)
    lips = np.clip(np.hypot(gx, gy) * 2.0, 0.0, 1.0) * (1.0 - slots)
    worn = np.clip(corners + lips * 0.8, 0.0, 1.0)
    t.shade(1.0 + 0.2 * worn)
    r = t.view("rough")
    r[:] = np.clip(r - 0.15 * worn, 0.0, 1.0)
    t.paint(slots, 0x0a0b0b, 0.9, height=-1.0)
    t.shade(1.0 - 0.4 * slots)


def _shell_high(t) -> None:
    """The high cut's shell (s round it from the back, t the elevation -25..90 degrees): vents with recessed rims."""
    t.fill(HIGH_SHELL, 0.5)
    # A sprayed coat: its fine peel, never quite one tone; the crown and the brow rubbed smoother and paler; a
    # scatter of scratches from branches and doorways.
    pos, el = _shell_pos(t)
    _grain(t, pos, 0.0012, 0.08, 141)
    _tone(t, pos, 0.03, 0.03, 142)
    _tone(t, pos, 0.009, 0.02, 143)
    exposed = np.clip((el - 45.0) / 30.0, 0.0, 1.0)
    rub = exposed * np.clip(_noise(pos[0], pos[1], 0.018, 144, 0.0, pos[2]) * 1.4 + 0.2, 0.0, 1.0)
    t.shade(1.0 + 0.09 * rub)
    r = t.view("rough")
    r[:] = np.clip(r - 0.12 * rub, 0.0, 1.0)
    _scuffs(t, pos, _marks_on_ball(70, SHELL_R, (5.0, 82.0), (0.006, 0.032), (0.00035, 0.0008), 145), 0.2, 0.2)
    dusty = np.clip((30.0 - el) / 40.0, 0.0, 1.0) * np.clip(_noise(pos[0], pos[1], 0.025, 146, 0.0, pos[2]) + 0.5, 0, 1)
    t.paint(dusty * 0.14, DUST, 0.75)
    # Oval vents with raised rims (photos 1-5): two over the brow, two above the rails behind the side panels, two
    # at the back; clear of the loop panels.
    # The front pair smaller and flatter (photo 122704).
    for az, el, r, aspect in ((23, 40, 0.028, 0.78), (-23, 40, 0.028, 0.78), (122, 50, 0.036, 0.6),
                              (-122, 50, 0.036, 0.6), (152, 40, 0.036, 0.6), (-152, 40, 0.036, 0.6)):
        s = (az + 180.0) / 360.0
        tt = (el + 25.0) / 115.0
        rim = soft_disc(t.s, t.t, s, tt, r, 0.004, aspect=aspect)
        hole = soft_disc(t.s, t.t, s, tt, r - 0.009, 0.003, aspect=aspect)
        foot = soft_disc(t.s, t.t, s, tt, r + 0.012, 0.01, aspect=aspect) - rim
        t.paint(np.clip(foot, 0.0, 1.0) * 0.2, DUST, 0.8)  # dust gathers round a vent's raised rim
        t.paint(rim - hole, 0x5c5b58, add_height=2.0)
        t.paint(hole, 0x1a1b1c, 0.9, add_height=-3.0)
    top = soft_box(t.s, t.t, -1, 2, 0.6, 1.1, 0.25)
    t.shade(1.0 + 0.04 * top)


def _shell_full(t) -> None:
    """The full cut's cover: coyote ripstop, seams down the sides and over the crown, a hem at the rim."""
    t.fill(FULL_COVER, 0.9)
    x = t.s * 0.75
    y = t.t * 0.24
    _ripstop(t, x, y, 0.012, 0.2)
    seam = lines(t.s, 0.25, 0.002, 0.001)
    t.paint(seam, add_height=-1.2)
    t.shade(1.0 - 0.15 * seam)
    hem = soft_box(t.s, t.t, -1, 2, -1, 0.07, 0.01)
    t.shade(1.0 - 0.12 * hem)
    # A cloth cover fades on top, holds dust beside its seams and along its hem, and scuffs pale where it rubs.
    pos, el = _shell_pos(t)
    _tone(t, pos, 0.05, 0.10, 151)
    _tone(t, pos, 0.013, 0.045, 152)
    t.shade(1.0 + 0.15 * np.clip((el - 35.0) / 40.0, 0.0, 1.0))
    patchy = np.clip(_noise(pos[0], pos[1], 0.02, 153, 0.0, pos[2]) + 0.7, 0.0, 1.0)
    beside = lines(t.s, 0.25, 0.02, 0.016) * (1.0 - seam)
    t.paint(beside * 0.34 * patchy, DUST)
    low = np.clip((12.0 - el) / 30.0, 0.0, 1.0)
    t.paint(low * 0.30 * patchy, DUST)
    scuff = np.clip(_noise(pos[0], pos[1], 0.011, 154, 0.0, pos[2]) * 2.2 - 1.2, 0.0, 1.0) * np.clip((el - 10.0) / 30.0, 0, 1)
    t.shade(1.0 + 0.20 * scuff)


def _shroud(t) -> None:
    t.fill(0x2e3032, 0.5)
    edge = 1.0 - soft_box(t.s, t.t, 0.05, 0.95, 0.08, 0.92, 0.03)
    t.paint(edge, add_height=-1.0)
    t.shade(1.0 - 0.15 * edge)
    x = t.s * 0.05
    y = t.t * 0.05
    _grain(t, _flat_pos(x, y), 0.0006, 0.12, 161)
    _tone(t, _flat_pos(x, y), 0.012, 0.04, 162)
    lip = np.clip(soft_box(t.s, t.t, 0.07, 0.93, 0.10, 0.90, 0.02) - soft_box(t.s, t.t, 0.13, 0.87, 0.16, 0.84, 0.02), 0, 1)
    t.shade(1.0 + 0.14 * lip * np.clip(_noise(x, y, 0.008, 163) + 0.6, 0.0, 1.0))


def _strap(t) -> None:
    """Black webbing: a fine twill and a stitch row along each edge."""
    t.fill(0x262728, 0.85)
    y = t.t * 0.02
    x = t.s * 0.3
    twill = lines(x + y, 0.0012, 0.0004, 0.0002)
    t.paint(twill, add_height=0.4)
    t.shade(1.0 - 0.07 * twill)
    _tone(t, _flat_pos(x, y), 0.02, 0.05, 171)
    for at in (0.0022, 0.0178):
        st = dashes(x, y - at, 1.0, 0.003, 0.0015, 0.0006, 0.0002)
        t.paint(st * 0.6, 0x3d3e40, add_height=0.5)


def _goggle_strap(t) -> None:
    """The goggles' strap (goggle photo 1): grey elastic with dark grey edges (no logo; darker than the photo's
    near white, so it neither reads as a mark nor shows as a pale block by the face)."""
    t.fill(0x5f605d, 0.85)
    edge = 1.0 - soft_box(t.s, t.t, -1, 2, 0.1, 0.9, 0.02)
    t.paint(edge, 0x2e3032, 0.7)
    ribs = lines(t.t * 0.036, 0.0015, 0.0006, 0.0002)
    t.paint(ribs, add_height=0.6)
    t.shade(1.0 - 0.08 * ribs)
    _tone(t, _flat_pos(t.s * 0.5, t.t * 0.036), 0.03, 0.05, 181)
