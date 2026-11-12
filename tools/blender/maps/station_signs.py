"""Subway's sign sheet (SM5): assets/textures/station/signs.png, every printed face of the station's extras in one
2048 x 2048 picture (cells in station_cells.py): thirteen posters, three wide trackside ones, the clock's face, the
station's name board, the platform edge's warning, the hanging "Way out" and "Platforms" signs, the line's strip map,
the platforms' departure boards, an information panel and three notices (no smoking, the handrail, CCTV).

From the owner's photos (references/maps/subway/33-extras): black signs with yellow words (direction_signs), a name
band along the platform wall (station_name_platform, but a dark band, not a real network's colour), framed posters
(poster_frames), a round clock with Roman numerals (platform_clock, no maker's name) and the yellow line's warning
(mind_the_gap). Every name and word is invented: the station is "Copperhill" (not "Kingsmere", the name the map
dropped); the posters are the game's own: four from airsoft (hit calling, a skirmish day, goggles on, a chrono night),
a club's call for new players, lost property, and adverts for invented things (a lido, a tea, a lemonade, a jazz
club, the library, a market, a tram museum). No real network, brand or logo. Colours are the look's palette
(mapkit.PALETTE), kept off both team hues; worn a little (grain, a faded rim) for Sunlit Concrete.

Needs Pillow, fontTools and brotli (the repo's fonts are WOFF2): pip install pillow fonttools brotli

    python3 -I tools/blender/maps/station_signs.py <repo root>
"""

import io
import math
import os
import random
import sys

from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from station_cells import CELLS, NOTICES, POSTERS, SHEET, WIDE_POSTERS  # noqa: E402

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
OUT = os.path.join(ROOT, "assets", "textures", "station", "signs.png")
FONTS = os.path.join(ROOT, "assets", "fonts")

INK = (0x22, 0x21, 0x24)
SIGN_BLACK = (0x1E, 0x1E, 0x20)
SIGN_YELLOW = (0xE4, 0xCA, 0x46)   # the palette's yellow, the station's one safety colour
CREAM = (0xF4, 0xEC, 0xDA)
SLATE = (0x3B, 0x40, 0x3E)         # the name band: dark grey-green, no network's colour
TEAL = (0x2A, 0x9C, 0x90)
GREEN = (0x58, 0x90, 0x4E)
FOREST = (0x2B, 0x5C, 0x48)
CRIMSON = (0xC2, 0x38, 0x74)
VIOLET = (0x76, 0x58, 0xAA)
BUTTER = (0xE6, 0xD4, 0x78)
PLASTER = (0xEC, 0xE2, 0xCF)
CLOCK_RIM = (0x2B, 0x4A, 0x3A)
NIGHT = (0x2A, 0x26, 0x3A)
POSTER_DRAW = (384, 576)           # a poster is drawn this size, then fitted to its cell
WIDE_DRAW = (768, 384)             # and a wide trackside one this size


def font(weight: int, size: int) -> ImageFont.FreeTypeFont:
    """Barlow Condensed at `weight` (500, 600, 700), from the repo's WOFF2."""
    tt = TTFont(os.path.join(FONTS, "BarlowCondensed-%d.woff2" % weight))
    tt.flavor = None
    buf = io.BytesIO()
    tt.save(buf)
    buf.seek(0)
    return ImageFont.truetype(buf, size)


def text_centre(d: ImageDraw.ImageDraw, xy: tuple, text: str, f: ImageFont.FreeTypeFont, fill: tuple,
                anchor: str = "mm") -> None:
    d.text(xy, text, font=f, fill=fill, anchor=anchor)


def line(d: ImageDraw.ImageDraw, y: float, text: str, weight: int, size: int, fill: tuple, x0: float = 0.0,
         x1: float = POSTER_DRAW[0]) -> None:
    """`text` centred between x0 and x1 at height `y`, its font shrunk until it fits 28 px in from each side."""
    f = font(weight, size)
    while d.textlength(text, font=f) > x1 - x0 - 56 and size > 12:
        size -= 2
        f = font(weight, size)
    text_centre(d, ((x0 + x1) / 2, y), text, f, fill)


def arrow(d: ImageDraw.ImageDraw, cx: float, cy: float, size: float, fill: tuple, turn: float = 0.0) -> None:
    """A bold arrow `size` px long about (cx, cy), pointing up turned `turn` degrees clockwise."""
    s = size / 2.0
    pts = [(0, -s), (0.62 * s, -0.05 * s), (0.2 * s, -0.05 * s), (0.2 * s, s), (-0.2 * s, s), (-0.2 * s, -0.05 * s),
           (-0.62 * s, -0.05 * s)]
    a = math.radians(turn)
    out = [(cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)) for x, y in pts]
    d.polygon(out, fill=fill)


def wear(im: Image.Image, rng: random.Random, grain: float, rim: float) -> Image.Image:
    """Grain over the whole cell and a faded, darker rim (dust in the frame's corner)."""
    w, h = im.size
    noise = Image.effect_noise((w, h), 40).convert("L")
    noise = noise.point(lambda v: 128 + (v - 128) * grain)
    base = im.convert("RGB")
    out = Image.blend(base, Image.merge("RGB", (noise, noise, noise)), 0.06)
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    edge = int(min(w, h) * 0.08)
    for i in range(edge):
        md.rectangle((i, i, w - 1 - i, h - 1 - i), outline=int(255 * rim * (1.0 - i / edge) ** 2))
    dirt = Image.new("RGB", (w, h), (0x5A, 0x52, 0x48))
    out = Image.composite(dirt, out, mask)
    # a few soft blotches
    blot = Image.new("L", (w, h), 0)
    bd = ImageDraw.Draw(blot)
    for _ in range(6):
        x, y, r = rng.uniform(0, w), rng.uniform(0, h), rng.uniform(0.05, 0.2) * min(w, h)
        bd.ellipse((x - r, y - r, x + r, y + r), fill=int(rng.uniform(10, 26)))
    blot = blot.filter(ImageFilter.GaussianBlur(min(w, h) * 0.05))
    return Image.composite(dirt, out, blot)


def poster(kind: str, rng: random.Random) -> Image.Image:
    """The poster `kind`, drawn at POSTER_DRAW and fitted to its cell."""
    w, h = POSTER_DRAW
    im = Image.new("RGB", (w, h), PLASTER)
    d = ImageDraw.Draw(im)
    if kind == "poster_a":
        # Call your hits: a raised hand on teal.
        d.rectangle((0, 0, w, h), fill=TEAL)
        cx, cy = w * 0.5, h * 0.40
        d.rounded_rectangle((cx - 62, cy - 30, cx + 62, cy + 110), 34, fill=CREAM)
        for i, (dx, top) in enumerate(((-48, -150), (-16, -178), (16, -170), (46, -138))):
            d.rounded_rectangle((cx + dx - 14, cy + top, cx + dx + 14, cy + 10), 14, fill=CREAM)
        d.polygon([(cx - 62, cy + 40), (cx - 118, cy - 40), (cx - 96, cy - 58), (cx - 50, cy + 2)], fill=CREAM)
        d.rectangle((cx - 44, cy + 104, cx + 44, cy + 170), fill=CREAM)
        text_centre(d, (w / 2, h * 0.80), "CALL YOUR HITS", font(700, 62), CREAM)
        text_centre(d, (w / 2, h * 0.88), "Hit? Hand up, shout it, walk off.", font(500, 30), INK)
        text_centre(d, (w / 2, h * 0.95), "Fair play keeps the game going", font(500, 22), INK)
    elif kind == "poster_b":
        # A skirmish day in the woods: pines, a pale sun.
        d.rectangle((0, 0, w, h), fill=BUTTER)
        d.ellipse((w * 0.56, h * 0.08, w * 0.86, h * 0.08 + w * 0.3), fill=CREAM)
        for x, s, c in ((0.18, 1.0, FOREST), (0.42, 1.3, GREEN), (0.68, 1.1, FOREST), (0.9, 0.9, GREEN)):
            bx, base = w * x, h * 0.58
            for k in range(3):
                tw, th = 70 * s * (1.0 - 0.22 * k), 80 * s
                ty = base - k * 52 * s
                d.polygon([(bx - tw, ty), (bx + tw, ty), (bx, ty - th)], fill=c)
        d.rectangle((0, h * 0.58, w, h), fill=FOREST)
        text_centre(d, (w / 2, h * 0.70), "SUNDAY", font(700, 76), CREAM)
        text_centre(d, (w / 2, h * 0.80), "SKIRMISH", font(700, 76), BUTTER)
        text_centre(d, (w / 2, h * 0.91), "Woodland site  ·  gates open 9:00", font(500, 30), CREAM)
    elif kind == "poster_c":
        # Lost property: a big question mark on violet.
        d.rectangle((0, 0, w, h), fill=VIOLET)
        text_centre(d, (w / 2, h * 0.36), "?", font(700, 330), CREAM)
        d.rectangle((24, h * 0.66, w - 24, h * 0.665), fill=CREAM)
        text_centre(d, (w / 2, h * 0.75), "LOST PROPERTY", font(700, 58), CREAM)
        text_centre(d, (w / 2, h * 0.84), "Goggles, gloves, one left boot.", font(500, 30), CREAM)
        text_centre(d, (w / 2, h * 0.91), "Ask at the ticket hall window", font(500, 28), BUTTER)
    elif kind == "poster_d":
        # The lido: waves on crimson and cream.
        d.rectangle((0, 0, w, h), fill=CREAM)
        d.rectangle((0, 0, w, h * 0.52), fill=CRIMSON)
        d.ellipse((w * 0.3, h * 0.12, w * 0.7, h * 0.12 + w * 0.4), fill=BUTTER)
        for k in range(4):
            y = h * (0.46 + 0.06 * k)
            pts = [(x, y + 10 * math.sin(x / 26.0 + k)) for x in range(0, w + 8, 8)]
            d.line(pts, fill=TEAL if k % 2 == 0 else FOREST, width=12)
        text_centre(d, (w / 2, h * 0.76), "COPPERHILL LIDO", font(700, 54), CRIMSON)
        text_centre(d, (w / 2, h * 0.85), "Open all summer", font(600, 40), INK)
        text_centre(d, (w / 2, h * 0.92), "Two stops east", font(500, 28), INK)
    else:
        more_posters(kind, d, w, h)
    im = im.resize(CELLS[kind][2:4], Image.LANCZOS)
    return wear(im, rng, 0.9, 0.55)


def more_posters(kind: str, d: ImageDraw.ImageDraw, w: int, h: int) -> None:
    """Posters e to m, on a POSTER_DRAW canvas: airsoft's own, then adverts for invented things."""
    if kind == "poster_e":
        # Goggles on: a pair of goggles on butter.
        d.rectangle((0, 0, w, h), fill=BUTTER)
        cx, cy = w * 0.5, h * 0.34
        d.rectangle((24, cy - 14, w - 24, cy + 14), fill=INK)
        d.rounded_rectangle((cx - 150, cy - 70, cx + 150, cy + 70), 60, fill=INK)
        for sx in (-1, 1):
            d.rounded_rectangle((cx + sx * 74 - 62, cy - 48, cx + sx * 74 + 62, cy + 48), 42, fill=CREAM)
            d.line([(cx + sx * 74 - 30, cy - 30), (cx + sx * 74 - 4, cy - 36)], fill=PLASTER, width=8)
        d.pieslice((cx - 26, cy + 34, cx + 26, cy + 106), 180, 360, fill=BUTTER)
        line(d, h * 0.66, "GOGGLES ON", 700, 76, INK)
        line(d, h * 0.77, "Eyes aren't spare parts.", 600, 36, INK)
        d.rectangle((60, h * 0.84, w - 60, h * 0.845), fill=INK)
        line(d, h * 0.91, "Rule one, in every game zone", 500, 28, INK)
    elif kind == "poster_f":
        # Chrono night: a dial on slate.
        d.rectangle((0, 0, w, h), fill=SLATE)
        cx, cy, r = w * 0.5, h * 0.44, 132
        d.pieslice((cx - r, cy - r, cx + r, cy + r), 180, 360, fill=CREAM)
        d.pieslice((cx - r + 18, cy - r + 18, cx + r - 18, cy + r - 18), 180, 360, fill=SLATE)
        for k in range(11):
            a = math.radians(180 + k * 18)
            r0 = r - (46 if k % 5 == 0 else 34)
            d.line([(cx + r0 * math.cos(a), cy + r0 * math.sin(a)), (cx + (r - 22) * math.cos(a),
                    cy + (r - 22) * math.sin(a))], fill=CREAM, width=6 if k % 5 == 0 else 3)
        a = math.radians(300)
        d.line([(cx, cy), (cx + (r - 40) * math.cos(a), cy + (r - 40) * math.sin(a))], fill=SIGN_YELLOW, width=9)
        d.ellipse((cx - 14, cy - 14, cx + 14, cy + 14), fill=SIGN_YELLOW)
        line(d, h * 0.60, "CHRONO NIGHT", 700, 70, CREAM)
        line(d, h * 0.71, "Every replica tested before play", 500, 30, CREAM)
        line(d, h * 0.80, "Thursdays · 7 pm", 600, 40, SIGN_YELLOW)
        line(d, h * 0.90, "Copperhill Airsoft Club", 500, 28, CREAM)
    elif kind == "poster_g":
        # New players welcome: a scatter of BBs on forest.
        d.rectangle((0, 0, w, h), fill=FOREST)
        g = random.Random(7)
        for _ in range(26):
            x, y, r = g.uniform(30, w - 30), g.uniform(30, h * 0.5), g.uniform(10, 26)
            d.ellipse((x - r, y - r, x + r, y + r), fill=CREAM)
            d.ellipse((x - r * 0.55, y - r * 0.6, x - r * 0.1, y - r * 0.15), fill=PLASTER)
        line(d, h * 0.60, "NEW PLAYERS", 700, 70, CREAM)
        line(d, h * 0.72, "WELCOME", 700, 70, BUTTER)
        line(d, h * 0.82, "Kit hire · your first game free", 500, 30, CREAM)
        line(d, h * 0.90, "Copperhill Airsoft Club", 600, 32, BUTTER)
    elif kind == "poster_h":
        # Halden Tea: a steaming cup on teal.
        d.rectangle((0, 0, w, h), fill=TEAL)
        cx, cy = w * 0.47, h * 0.40
        d.ellipse((cx - 130, cy + 70, cx + 130, cy + 110), fill=CREAM)
        d.chord((cx - 100, cy - 70, cx + 100, cy + 110), 0, 180, fill=CREAM)
        d.rectangle((cx - 100, cy - 10, cx + 100, cy + 20), fill=CREAM)
        d.ellipse((cx + 80, cy - 4, cx + 150, cy + 62), outline=CREAM, width=16)
        d.ellipse((cx - 100, cy - 26, cx + 100, cy + 6), fill=FOREST)
        for k in (-40, 0, 40):
            pts = [(cx + k + 12 * math.sin(t / 9.0), cy - 40 - t) for t in range(0, 110, 4)]
            d.line(pts, fill=CREAM, width=8)
        line(d, h * 0.70, "HALDEN TEA", 700, 76, CREAM)
        line(d, h * 0.80, "A proper cup, strong and hot", 500, 32, INK)
        line(d, h * 0.90, "Brewed in Copperhill since 1931", 500, 26, CREAM)
    elif kind == "poster_i":
        # Fizzbee lemonade: a bottle and bubbles on green.
        d.rectangle((0, 0, w, h), fill=GREEN)
        cx = w * 0.5
        d.rounded_rectangle((cx - 58, h * 0.20, cx + 58, h * 0.56), 30, fill=BUTTER)
        d.polygon([(cx - 58, h * 0.22), (cx + 58, h * 0.22), (cx + 20, h * 0.11), (cx - 20, h * 0.11)], fill=BUTTER)
        d.rectangle((cx - 20, h * 0.05, cx + 20, h * 0.11), fill=BUTTER)
        d.rectangle((cx - 24, h * 0.04, cx + 24, h * 0.065), fill=CRIMSON)
        d.rectangle((cx - 58, h * 0.32, cx + 58, h * 0.42), fill=CREAM)
        text_centre(d, (cx, h * 0.37), "FIZZBEE", font(700, 38), GREEN)
        g = random.Random(3)
        for _ in range(22):
            x, y, r = g.uniform(30, w - 30), g.uniform(h * 0.06, h * 0.58), g.uniform(5, 15)
            if abs(x - cx) > 70:
                d.ellipse((x - r, y - r, x + r, y + r), outline=CREAM, width=4)
        line(d, h * 0.68, "FIZZBEE", 700, 84, BUTTER)
        line(d, h * 0.78, "Lemonade you can hear", 600, 36, CREAM)
        line(d, h * 0.89, "Ice cold at the station kiosk", 500, 28, INK)
    elif kind == "poster_j":
        # The Lamplight Room: a hanging lamp's glow on the night, a crescent moon and stars.
        d.rectangle((0, 0, w, h), fill=NIGHT)
        g = random.Random(11)
        for _ in range(30):
            x, y, r = g.uniform(14, w - 14), g.uniform(14, h * 0.52), g.uniform(1.5, 4)
            d.ellipse((x - r, y - r, x + r, y + r), fill=CREAM)
        d.ellipse((w * 0.66, h * 0.06, w * 0.90, h * 0.06 + w * 0.24), fill=BUTTER)
        d.ellipse((w * 0.61, h * 0.05, w * 0.84, h * 0.05 + w * 0.23), fill=NIGHT)
        cx, top = w * 0.40, h * 0.30
        for k, c in enumerate(((0x46, 0x44, 0x46), (0x66, 0x64, 0x56), (0x8E, 0x8A, 0x64))):
            r = 120 - 34 * k
            d.ellipse((cx - r, top + 40 - r * 0.45, cx + r, top + 40 + r * 1.1), fill=c)
        d.line([(cx, 0), (cx, top - 46)], fill=INK, width=4)
        d.polygon([(cx - 24, top - 46), (cx + 24, top - 46), (cx + 62, top + 10), (cx - 62, top + 10)], fill=INK)
        d.chord((cx - 26, top - 12, cx + 26, top + 36), 0, 180, fill=BUTTER)
        line(d, h * 0.64, "THE LAMPLIGHT ROOM", 700, 64, BUTTER)
        line(d, h * 0.74, "Live jazz every Friday", 600, 38, CREAM)
        d.rectangle((90, h * 0.80, w - 90, h * 0.805), fill=VIOLET)
        line(d, h * 0.87, "Under the arches, Copperhill", 500, 28, CREAM)
        line(d, h * 0.93, "Doors 8 pm", 500, 26, VIOLET)
    elif kind == "poster_k":
        # The library: a stack of books on plaster.
        d.rectangle((0, 0, w, h), fill=PLASTER)
        y = h * 0.55
        for bw, bh, c, dx in ((250, 46, FOREST, 0), (224, 40, CRIMSON, 12), (264, 52, TEAL, -8), (210, 38, VIOLET, 18),
                              (236, 44, SLATE, -4), (190, 36, GREEN, 10)):
            x0 = w * 0.5 - bw / 2 + dx
            d.rounded_rectangle((x0, y - bh, x0 + bw, y), 6, fill=c)
            d.rectangle((x0 + 18, y - bh * 0.62, x0 + bw - 18, y - bh * 0.5), fill=CREAM)
            y -= bh + 2
        line(d, h * 0.66, "READ LATE", 700, 80, INK)
        line(d, h * 0.76, "The library stays open", 600, 36, FOREST)
        line(d, h * 0.82, "till 9 every Wednesday", 600, 36, FOREST)
        line(d, h * 0.91, "Copperhill Library · Station Road", 500, 26, INK)
    elif kind == "poster_l":
        # The market: a striped awning on crimson.
        d.rectangle((0, 0, w, h), fill=CRIMSON)
        top, low = h * 0.12, h * 0.26
        stripes = 8
        sw = w / stripes
        for k in range(stripes):
            c = CREAM if k % 2 == 0 else BUTTER
            d.rectangle((k * sw, top, (k + 1) * sw, low), fill=c)
            d.pieslice((k * sw, low - sw / 2, (k + 1) * sw, low + sw / 2), 0, 180, fill=c)
        for k, c in enumerate((GREEN, BUTTER, CREAM, TEAL, GREEN)):
            x = w * (0.16 + 0.17 * k)
            d.ellipse((x - 30, h * 0.40, x + 30, h * 0.40 + 60), fill=c)
        d.rectangle((24, h * 0.40 + 46, w - 24, h * 0.40 + 70), fill=FOREST)
        line(d, h * 0.62, "SATURDAY", 700, 70, CREAM)
        line(d, h * 0.74, "MARKET", 700, 70, BUTTER)
        line(d, h * 0.84, "Fruit, flowers, old records", 500, 32, CREAM)
        line(d, h * 0.91, "Under the arches · 8 till 2", 500, 28, CREAM)
    else:
        # The tram museum: an old tram on cream.
        d.rectangle((0, 0, w, h), fill=CREAM)
        d.rectangle((0, h * 0.50, w, h * 0.515), fill=INK)
        x0, x1, top, low = w * 0.12, w * 0.88, h * 0.22, h * 0.47
        d.rounded_rectangle((x0, top, x1, low), 22, fill=FOREST)
        d.rectangle((x0, top + 54, x1, top + 62), fill=BUTTER)
        for k in range(5):
            wx = x0 + 22 + k * (x1 - x0 - 44) / 5
            d.rounded_rectangle((wx + 4, top + 12, wx + (x1 - x0 - 44) / 5 - 4, top + 48), 6, fill=PLASTER)
        d.line([(w * 0.5, top), (w * 0.62, h * 0.10)], fill=INK, width=5)
        d.line([(0, h * 0.10), (w, h * 0.10)], fill=INK, width=3)
        for wx in (x0 + 50, x1 - 50):
            d.ellipse((wx - 24, low - 18, wx + 24, low + 30), fill=INK)
        line(d, h * 0.62, "TRAM MUSEUM", 700, 74, FOREST)
        line(d, h * 0.72, "Ride a 1920s tram", 600, 38, INK)
        line(d, h * 0.80, "Free every Sunday", 600, 38, CRIMSON)
        line(d, h * 0.90, "Copperhill Depot Yard · two stops west", 500, 24, INK)


def wide_poster(kind: str, rng: random.Random) -> Image.Image:
    """A 6 x 3 m trackside poster, drawn at WIDE_DRAW and fitted to its cell: pictures left, words right."""
    w, h = WIDE_DRAW
    im = Image.new("RGB", (w, h), PLASTER)
    d = ImageDraw.Draw(im)
    mid = w * 0.46
    if kind == "poster_wide_a":
        # Skirmish Sundays: pines under a pale sun, the words on forest.
        d.rectangle((0, 0, w, h), fill=BUTTER)
        d.ellipse((mid * 0.55, h * 0.10, mid * 0.55 + 120, h * 0.10 + 120), fill=CREAM)
        for x, s, c in ((0.10, 0.9, FOREST), (0.30, 1.2, GREEN), (0.52, 1.0, FOREST), (0.74, 1.3, GREEN),
                        (0.92, 0.8, FOREST)):
            bx, base = mid * x, h * 0.86
            for k in range(3):
                tw, th = 46 * s * (1.0 - 0.22 * k), 64 * s
                ty = base - k * 44 * s
                d.polygon([(bx - tw, ty), (bx + tw, ty), (bx, ty - th)], fill=c)
        d.rectangle((0, h * 0.86, mid, h), fill=FOREST)
        d.rectangle((mid, 0, w, h), fill=FOREST)
        line(d, h * 0.22, "SKIRMISH SUNDAYS", 700, 64, BUTTER, mid, w)
        line(d, h * 0.42, "at the Woodland site", 600, 40, CREAM, mid, w)
        line(d, h * 0.60, "Gates open 9:00 · kit hire on the day", 500, 28, CREAM, mid, w)
        line(d, h * 0.80, "Copperhill Airsoft Club", 600, 32, BUTTER, mid, w)
    elif kind == "poster_wide_b":
        # Cycle hire: a bicycle on teal.
        d.rectangle((0, 0, w, h), fill=TEAL)
        r, y = 62, h * 0.62
        back, front = mid * 0.26, mid * 0.80
        for x in (back, front):
            d.ellipse((x - r, y - r, x + r, y + r), outline=CREAM, width=10)
            d.ellipse((x - 8, y - 8, x + 8, y + 8), fill=CREAM)
        crank, seat, head = (mid * 0.50, y), (mid * 0.40, y - 92), (mid * 0.74, y - 96)
        for a, b in ((back, crank), (crank, seat), (seat, head), (head, crank)):
            pa = (a, y) if isinstance(a, float) else a
            d.line([pa, b], fill=BUTTER, width=10)
        d.line([(back, y), seat], fill=BUTTER, width=10)
        d.line([head, (front, y)], fill=BUTTER, width=10)
        d.line([(seat[0] - 26, seat[1] - 14), (seat[0] + 20, seat[1] - 14)], fill=INK, width=12)
        d.line([head, (head[0] + 8, head[1] - 30), (head[0] + 40, head[1] - 34)], fill=INK, width=8)
        line(d, h * 0.24, "TWO WHEELS,", 700, 64, CREAM, mid, w)
        line(d, h * 0.44, "NO TRAFFIC", 700, 64, BUTTER, mid, w)
        line(d, h * 0.64, "Copperhill Cycle Hire", 600, 38, CREAM, mid, w)
        line(d, h * 0.82, "Bikes by the hour, outside the station", 500, 26, INK, mid, w)
    else:
        # The pier: a sun, a gull and the sea, the words on cream.
        d.rectangle((0, 0, mid, h), fill=VIOLET)
        d.ellipse((mid * 0.30, h * 0.18, mid * 0.30 + 150, h * 0.18 + 150), fill=BUTTER)
        d.rectangle((0, h * 0.62, mid, h), fill=TEAL)
        for k in range(3):
            yy = h * (0.66 + 0.1 * k)
            d.line([(x, yy + 7 * math.sin(x / 18.0 + k)) for x in range(0, int(mid) + 6, 6)], fill=CREAM, width=6)
        for x, y, r in ((mid * 0.22, h * 0.24, 44), (mid * 0.80, h * 0.40, 26)):
            d.arc((x - r, y - r * 0.5, x + 4, y + r * 0.5), 195, 330, fill=CREAM, width=7)
            d.arc((x - 4, y - r * 0.5, x + r, y + r * 0.5), 210, 345, fill=CREAM, width=7)
        d.rectangle((mid * 0.55, h * 0.52, mid, h * 0.56), fill=INK)
        for x in (0.62, 0.75, 0.88):
            d.rectangle((mid * x, h * 0.56, mid * x + 8, h * 0.80), fill=INK)
        d.rectangle((mid, 0, w, h), fill=CREAM)
        line(d, h * 0.22, "COPPERHILL PIER", 700, 64, VIOLET, mid, w)
        line(d, h * 0.42, "Fish and chips by the sea", 600, 40, INK, mid, w)
        line(d, h * 0.60, "Twenty minutes from this platform", 500, 28, INK, mid, w)
        line(d, h * 0.80, "Open every day, rain or shine", 600, 30, TEAL, mid, w)
    im = im.resize(CELLS[kind][2:4], Image.LANCZOS)
    return wear(im, rng, 0.9, 0.45)


def line_map(rng: random.Random) -> Image.Image:
    """The line's strip map: its invented stops along a green line, Copperhill ringed."""
    w, h = CELLS["line_map"][2] * 2, CELLS["line_map"][3] * 2
    im = Image.new("RGB", (w, h), CREAM)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 300, h), fill=SLATE)
    text_centre(d, (150, h * 0.36), "COPPERHILL", font(700, 54), CREAM)
    text_centre(d, (150, h * 0.68), "LINE", font(700, 54), BUTTER)
    stops = ["Ashby Road", "Mill Lane", "Copperhill", "Lido", "Harbour", "Pier"]
    x0, x1, y = 440, w - 110, h * 0.40
    d.line([(x0 - 30, y), (x1 + 30, y)], fill=GREEN, width=22)
    for i, name in enumerate(stops):
        x = x0 + (x1 - x0) * i / (len(stops) - 1)
        here = name == "Copperhill"
        r = 30 if here else 20
        d.ellipse((x - r, y - r, x + r, y + r), fill=CREAM, outline=INK, width=8 if here else 6)
        text_centre(d, (x, h * 0.78), name, font(700 if here else 600, 46 if here else 40), INK)
    return wear(im.resize(CELLS["line_map"][2:4], Image.LANCZOS), rng, 0.6, 0.3)


def departures(cell: str, rows: list, rng: random.Random) -> Image.Image:
    """A dot-matrix board: yellow dots on black, its two next trains and a line of advice."""
    w, h = CELLS[cell][2] * 2, CELLS[cell][3] * 2
    text = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(text)
    f = font(700, 62)
    for i, (num, dest, when) in enumerate(rows):
        y = 50 + i * 82
        d.text((36, y), num, font=f, fill=255, anchor="lm")
        d.text((96, y), dest, font=f, fill=255, anchor="lm")
        d.text((w - 36, y), when, font=f, fill=255, anchor="rm")
    d.text((w / 2, h - 34), "Stand behind the yellow line", font=font(500, 40), fill=255, anchor="mm")
    # the words lit in yellow, seen through a grid of dark gaps between the board's dots
    im = Image.composite(Image.new("RGB", (w, h), SIGN_YELLOW), Image.new("RGB", (w, h), (0x14, 0x14, 0x16)), text)
    grid = ImageDraw.Draw(im)
    for k in range(0, max(w, h), 4):
        grid.line([(k, 0), (k, h)], fill=(0x14, 0x14, 0x16), width=1)
        grid.line([(0, k), (w, k)], fill=(0x14, 0x14, 0x16), width=1)
    return wear(im.resize(CELLS[cell][2:4], Image.LANCZOS), rng, 0.3, 0.2)


def info_panel(rng: random.Random) -> Image.Image:
    """The station's information panel: a slate head, then what a visitor needs."""
    w, h = CELLS["info_panel"][2] * 3, CELLS["info_panel"][3] * 3
    im = Image.new("RGB", (w, h), CREAM)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, w, 120), fill=SLATE)
    d.ellipse((24, 22, 100, 98), fill=CREAM)
    text_centre(d, (62, 60), "i", font(700, 66), SLATE)
    d.text((124, 60), "Copperhill · station information", font=font(700, 56), fill=CREAM, anchor="lm")
    rows = ["Lifts to every level", "Help point by the ticket gates", "Lost property: the ticket hall window",
            "First train 05:30 · last train 00:30", "Keep your belongings with you"]
    for i, t in enumerate(rows):
        y = 172 + i * 70
        d.ellipse((40, y - 10, 60, y + 10), fill=GREEN)
        d.text((84, y), t, font=font(500, 46), fill=INK, anchor="lm")
    return wear(im.resize(CELLS["info_panel"][2:4], Image.LANCZOS), rng, 0.5, 0.3)


def notice(cell: str, rng: random.Random) -> Image.Image:
    """A square wall notice: a pictogram over two words."""
    w = CELLS[cell][2] * 3
    im = Image.new("RGB", (w, w), CREAM)
    d = ImageDraw.Draw(im)
    c, r = w / 2, w * 0.27
    cy = w * 0.36
    if cell == "notice_smoking":
        d.rectangle((c - 120, cy - 12, c + 70, cy + 22), fill=INK)
        d.rectangle((c + 74, cy - 12, c + 104, cy + 22), fill=PLASTER)
        for k in range(3):
            d.arc((c + 70 + k * 14, cy - 80, c + 110 + k * 14, cy - 20), 200, 340, fill=INK, width=6)
        d.ellipse((c - r, cy - r, c + r, cy + r), outline=CRIMSON, width=26)
        d.line([(c - r * 0.7, cy - r * 0.7), (c + r * 0.7, cy + r * 0.7)], fill=CRIMSON, width=26)
        words = ("NO SMOKING", "anywhere in the station")
    elif cell == "notice_handrail":
        d.ellipse((c - r, cy - r, c + r, cy + r), fill=GREEN)
        # an escalator's steps climbing right under its handrail, a figure on them holding it
        steps = [(c - r * 0.75, cy + r * 0.55)]
        for k in range(5):
            x, y = c - r * 0.75 + k * r * 0.3, cy + r * 0.55 - k * r * 0.22
            steps += [(x, y - r * 0.22), (x + r * 0.3, y - r * 0.22)]
        steps += [(c + r * 0.75, cy + r * 0.55)]
        d.polygon(steps, fill=CREAM)
        d.line([(c - r * 0.8, cy + r * 0.05), (c + r * 0.8, cy - r * 0.6)], fill=CREAM, width=12)
        fx, fy = c - r * 0.1, cy - r * 0.05
        d.ellipse((fx - 18, fy - 92, fx + 18, fy - 56), fill=CREAM)
        d.line([(fx, fy - 54), (fx, fy + 4)], fill=CREAM, width=18)
        d.line([(fx, fy - 40), (fx + 34, fy - 52)], fill=CREAM, width=12)
        words = ("HOLD THE HANDRAIL", "Stand on the right")
    else:
        d.rounded_rectangle((c - r, cy - r, c + r, cy + r), 30, fill=SIGN_YELLOW)
        d.rounded_rectangle((c - 90, cy - 40, c + 50, cy + 20), 14, fill=INK)
        d.polygon([(c + 50, cy - 26), (c + 96, cy - 50), (c + 96, cy + 30), (c + 50, cy + 8)], fill=INK)
        d.rectangle((c - 36, cy + 20, c - 16, cy + 70), fill=INK)
        d.rectangle((c - 70, cy + 64, c + 18, cy + 80), fill=INK)
        words = ("CCTV IN USE", "Images kept for safety")
    text_centre(d, (c, w * 0.76), words[0], font(700, 70), INK)
    text_centre(d, (c, w * 0.88), words[1], font(500, 46), INK)
    return wear(im.resize(CELLS[cell][2:4], Image.LANCZOS), rng, 0.5, 0.3)


def clock(rng: random.Random) -> Image.Image:
    w = CELLS["clock"][2]
    im = Image.new("RGB", (w, w), CLOCK_RIM)
    d = ImageDraw.Draw(im)
    c = w / 2.0
    d.ellipse((4, 4, w - 4, w - 4), fill=CREAM)
    for m in range(60):
        a = math.radians(m * 6)
        r0 = c * (0.84 if m % 5 == 0 else 0.88)
        r1 = c * 0.94
        width = 6 if m % 5 == 0 else 3
        d.line([(c + r0 * math.sin(a), c - r0 * math.cos(a)), (c + r1 * math.sin(a), c - r1 * math.cos(a))],
               fill=INK, width=width)
    numerals = ["XII", "I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
    f = font(600, 52)
    for i, n in enumerate(numerals):
        a = math.radians(i * 30)
        r = c * 0.68
        text_centre(d, (c + r * math.sin(a), c - r * math.cos(a)), n, f, INK)
    # the hands at ten past ten, with a counterweight tail
    for turn, length, width in ((-58.0, 0.44, 16), (60.0, 0.74, 10)):
        a = math.radians(turn)
        tip = (c + c * length * math.sin(a), c - c * length * math.cos(a))
        tail = (c - c * 0.14 * math.sin(a), c + c * 0.14 * math.cos(a))
        d.line([tail, tip], fill=INK, width=width)
    d.ellipse((c - 14, c - 14, c + 14, c + 14), fill=INK)
    im = wear(im, rng, 0.5, 0.0)
    # the face yellows with age towards its rim
    return im


def name_board(rng: random.Random) -> Image.Image:
    w, h = CELLS["name"][2], CELLS["name"][3]
    im = Image.new("RGB", (w, h), SLATE)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 10, w, 16), fill=CREAM)
    d.rectangle((0, h - 16, w, h - 10), fill=CREAM)
    text_centre(d, (w / 2, h / 2 + 2), "Copperhill", font(700, 112), CREAM)
    return wear(im, rng, 0.7, 0.35)


def edge_warning(rng: random.Random) -> Image.Image:
    w, h = CELLS["edge"][2], CELLS["edge"][3]
    im = Image.new("RGB", (w, h), SIGN_BLACK)
    d = ImageDraw.Draw(im)
    text_centre(d, (w / 2, h / 2 + 2), "STAY BEHIND THE YELLOW LINE", font(700, 70), SIGN_YELLOW)
    for x in (56, w - 56):
        arrow(d, x, h / 2, 70, SIGN_YELLOW, 180.0)
    return wear(im, rng, 1.0, 0.5)


def hanging_sign(words: str, rng: random.Random, cell: str) -> Image.Image:
    w, h = CELLS[cell][2], CELLS[cell][3]
    im = Image.new("RGB", (w, h), SIGN_BLACK)
    d = ImageDraw.Draw(im)
    arrow(d, 62, h / 2, 76, SIGN_YELLOW)
    d.text((118, h / 2 + 2), words, font=font(700, 84), fill=SIGN_YELLOW, anchor="lm")
    return wear(im, rng, 0.6, 0.3)


def main() -> None:
    rng = random.Random(5)
    sheet = Image.new("RGB", SHEET, (0x5A, 0x52, 0x48))
    pictures = {k: poster(k, rng) for k in POSTERS}
    pictures.update({k: wide_poster(k, rng) for k in WIDE_POSTERS})
    pictures["line_map"] = line_map(rng)
    pictures["departures_n"] = departures("departures_n", [("1", "Pier", "2 min"), ("2", "Harbour", "9 min")], rng)
    pictures["departures_s"] = departures("departures_s", [("1", "Ashby Road", "3 min"), ("2", "Mill Lane", "11 min")],
                                          rng)
    pictures["info_panel"] = info_panel(rng)
    pictures.update({k: notice(k, rng) for k in NOTICES})
    pictures["clock"] = clock(rng)
    pictures["name"] = name_board(rng)
    pictures["edge"] = edge_warning(rng)
    pictures["way_out"] = hanging_sign("Way out", rng, "way_out")
    pictures["platforms"] = hanging_sign("Platforms", rng, "platforms")
    for k, im in pictures.items():
        x, y, w, h = CELLS[k]
        assert im.size == (w, h), k
        sheet.paste(im, (x, y))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT, optimize=True)
    print("%s: %d x %d, %d cells" % (os.path.relpath(OUT, ROOT), SHEET[0], SHEET[1], len(pictures)))


if __name__ == "__main__":
    main()
