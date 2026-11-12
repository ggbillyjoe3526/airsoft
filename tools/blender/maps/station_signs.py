"""Subway's sign sheet (SM5): assets/textures/station/signs.png, every printed face of the station's extras in one
2048 x 1024 picture (cells in station_cells.py): four posters, the platform clock's face, the station's name board,
the platform edge's warning, and the hanging "Way out" and "Platforms" signs.

From the owner's photos (references/maps/subway/33-extras): black signs with yellow words (direction_signs), a name
band along the platform wall (station_name_platform, but a dark band, not a real network's colour), framed posters
(poster_frames), a round clock with Roman numerals (platform_clock, no maker's name) and the yellow line's warning
(mind_the_gap). Every name and word is invented: the station is "Copperhill" (not "Kingsmere", the name the map
dropped); the posters are the game's own (hit calling, a skirmish day, lost property, a lido). No real network, brand or logo. Colours are the look's
palette (mapkit.PALETTE), kept off both team hues; worn a little (grain, a faded rim) for Sunlit Concrete.

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

from station_cells import CELLS, SHEET  # noqa: E402

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
    w, h = CELLS[kind][2], CELLS[kind][3]
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
    else:
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
    return wear(im, rng, 0.9, 0.55)


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
    pictures = {k: poster(k, rng) for k in ("poster_a", "poster_b", "poster_c", "poster_d")}
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
