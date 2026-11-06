"""The heads' texture atlas, painted with numpy (BL11, 2026-11-05): tools/blender/figures/headwear.py.

Clean, stylised surfaces (the art direction: flat colour, crisp patterns, no grime or noise): the fabrics carry their
weave, seams and stitching as colour and a little height (the normal map); hard parts are flat swatches and get their
detail from the geometry. Every pattern is drawn at its real size for the part that covers its tile.
"""

import os

import numpy as np

import face
from headkit import Atlas, dashes, lines, soft_box, soft_disc, soft_round_box

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
    _knit(a.tile("knit", 512, 0, 1024, 384))
    face.paint(a)  # four 256 x 128 cells over the swatch area's top half
    _loop(a.tile("loop_cap", 512, 384, 512, 128), 0x5a4936, 0x4a3b2b)
    _mesh(a.tile("mesh", 1536, 0, 512, 512))
    _shemagh(a.tile("shemagh", 0, 512, 1024, 512))
    _brim(a.tile("brim", 1024, 512, 1024, 256))
    _boonie_crown(a.tile("boonie_crown", 1024, 768, 512, 256))
    _cap_crown(a.tile("cap_crown", 1536, 768, 512, 256))
    _cap_brim(a.tile("cap_brim", 0, 1024, 512, 256))
    _loop(a.tile("loop", 512, 1024, 512, 256), LOOP_DARK, 0x1f2021)
    _loop(a.tile("team_loop", 1024, 1024, 512, 256), TEAM_LIGHT, 0xbdbdbd)
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
    """Writes the atlas as three WebP files (the normal and roughness maps at full quality); returns their paths by
    kind. Image.save writes the pixels as painted (save_render would put them through the scene's view transform)."""
    images = atlas.images(os.path.basename(stem))
    out = {}
    for key, im in images.items():
        path = "%s_%s.webp" % (stem, key)
        im.filepath_raw = path
        im.file_format = "WEBP"
        im.save(filepath=path, quality=90 if key == "col" else 100)
        out[key] = path
    return out


# --------------------------------------------------------------------------------------------------- the tiles

def _knit(t) -> None:
    """The balaclava: fine ribs round the head (the eye opening is cut in the mesh; face.py fills it)."""
    t.fill(KNIT, 0.95)
    x = t.s * face.KNIT_ROUND  # metres round the head at the face
    y = t.t * KNIT_SPAN
    rib = lines(x, 0.0032, 0.0012, 0.0004)
    t.paint(np.ones_like(rib), height=0.0)
    t.paint(rib, add_height=1.2)
    t.shade(1.0 - 0.10 * rib)


def _mesh(t) -> None:
    """Painted steel mesh: square wires 3 mm apart, the face's shadow through the holes."""
    t.fill(0x1c1e16, 0.7, height=-1.5)
    x = t.s * 0.26
    y = t.t * 0.13
    wire = np.maximum(lines(x, 0.003, 0.0009, 0.00025), lines(y, 0.003, 0.0009, 0.00025))
    t.paint(wire, STEEL, 0.45, height=1.5)


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
    y = t.t * 0.11
    _ripstop(t, x, y)
    _seams(t, x, y, 1.0 / 6.0, 0x48503f)
    top = lines(t.t - 0.72, 10.0, 0.012, 0.004)
    t.paint(top, add_height=-1.2)
    t.shade(1.0 - 0.15 * top)


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


def _loop(t, colour: int, border: int) -> None:
    """Loop fabric (the patch panels): a fine, even pile and a sewn binding round the edge."""
    t.fill(colour, 0.97)
    x = t.s * 0.12
    y = t.t * 0.06
    pile = np.sin(x / 0.0011 * 6.283) * np.sin(y / 0.0011 * 6.283)
    t.paint(np.ones_like(pile), add_height=0.0)
    t.view("height")[:] += 0.35 * pile
    t.shade(1.0 + 0.03 * pile)
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
    t.shade(1.0 - 0.06 * weave)
    edge = soft_box(t.s, t.t, -1, 2, 0.06, 0.94, 0.008)
    t.shade(0.85 + 0.15 * edge)


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
    t.paint(slots, 0x0a0b0b, 0.9, height=-1.0)
    t.shade(1.0 - 0.4 * slots)


def _shell_high(t) -> None:
    """The high cut's shell (s round it from the back, t the elevation -25..90 degrees): vents with recessed rims."""
    t.fill(HIGH_SHELL, 0.5)
    # Oval vents with raised rims (photos 1-5): two over the brow, two above the rails behind the side panels, two
    # at the back; clear of the loop panels.
    # The front pair smaller and flatter (photo 122704).
    for az, el, r, aspect in ((23, 40, 0.028, 0.78), (-23, 40, 0.028, 0.78), (122, 50, 0.036, 0.6),
                              (-122, 50, 0.036, 0.6), (152, 40, 0.036, 0.6), (-152, 40, 0.036, 0.6)):
        s = (az + 180.0) / 360.0
        tt = (el + 25.0) / 115.0
        rim = soft_disc(t.s, t.t, s, tt, r, 0.004, aspect=aspect)
        hole = soft_disc(t.s, t.t, s, tt, r - 0.009, 0.003, aspect=aspect)
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


def _shroud(t) -> None:
    t.fill(0x2e3032, 0.5)
    edge = 1.0 - soft_box(t.s, t.t, 0.05, 0.95, 0.08, 0.92, 0.03)
    t.paint(edge, add_height=-1.0)
    t.shade(1.0 - 0.15 * edge)


def _strap(t) -> None:
    """Black webbing: a fine twill and a stitch row along each edge."""
    t.fill(0x262728, 0.85)
    y = t.t * 0.02
    x = t.s * 0.3
    twill = lines(x + y, 0.0012, 0.0004, 0.0002)
    t.paint(twill, add_height=0.4)
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
    t.paint(ribs, add_height=0.4)
