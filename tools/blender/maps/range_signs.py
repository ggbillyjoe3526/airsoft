"""The Range's sign sheet (RQ1, 0.1 Beta 2): assets/textures/range/signs.png, every printed face of the Range's
extras in one 1024 x 1024 picture (cells in range_cells.py): the range rules board, the chrono station's sign, eye
protection must be worn, the four lanes' numbers, the safe zone's sign and the red flag's notice.

An airsoft site's own signs: the usual safety-sign shapes and colours, drawn plainly, no maker's marks, the words
invented. Safety green and the palette's yellow keep their meaning; the mandatory-sign blue is Alpha's hue, so it is
Depot's deep indigo (depot_signs.py); the red flag's red is Depot's fire red, clear of Beta's orange. Worn a little (grain,
a faded rim) as the station's are (station_signs.py, whose fonts and helpers this uses).

Needs Pillow, fontTools and brotli (the repo's fonts are WOFF2): pip install pillow fonttools brotli

    python3 -I tools/blender/maps/range_signs.py <repo root>
"""

import os
import random
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import depot_signs as ds  # noqa: E402
import station_signs as ss  # noqa: E402
from range_cells import CELLS, SHEET  # noqa: E402

OUT = os.path.join(ss.ROOT, "assets", "textures", "range", "signs.png")
INK, SAFE_GREEN, INDIGO, YELLOW = ds.INK, ds.SAFE_GREEN, ds.INDIGO, ds.YELLOW
WHITE = (0xF0, 0xF2, 0xEE)  # a cool white: the warm dust of the wear over Depot's cream read as a pale orange
FLAG_RED = ds.FIRE  # the flag's red, Depot's fire red (range_extras.py), clear of both sets' Beta oranges
FOREST = ss.FOREST

RULES = [
    "Eye protection on at all times",
    "Shoot from the firing line only",
    "Hear \"Cease fire\"? Stop and repeat it",
    "Line clear? Then walk downrange",
    "Mags out, clear and safe to leave",
    "Hit? Call it loud and proud",
]


def canvas(cell: str, fill: tuple) -> tuple:
    w, h = CELLS[cell][2] * ds.SCALE, CELLS[cell][3] * ds.SCALE
    im = Image.new("RGB", (w, h), fill)
    return im, ImageDraw.Draw(im), w, h


def goggles(d: ImageDraw.ImageDraw, cx: float, cy: float, s: float, fill: tuple) -> None:
    """The mandatory sign's eye protection pictogram: a head's outline wearing goggles, `s` px across."""
    d.ellipse((cx - s * 0.32, cy - s * 0.42, cx + s * 0.32, cy + s * 0.36), outline=fill, width=max(4, int(s * 0.06)))
    d.rectangle((cx - s * 0.12, cy + s * 0.3, cx + s * 0.12, cy + s * 0.5), fill=fill)
    d.rounded_rectangle((cx - s * 0.4, cy - s * 0.12, cx + s * 0.4, cy + s * 0.08), radius=s * 0.08, fill=fill)
    for side in (-1, 1):
        x = cx + side * s * 0.18
        d.ellipse((x - s * 0.12, cy - s * 0.09, x + s * 0.12, cy + s * 0.05), fill=WHITE)


def rules(rng: random.Random) -> Image.Image:
    im, d, w, h = canvas("rules", WHITE)
    d.rectangle((0, 0, w, h * 0.17), fill=FOREST)
    ds.text(d, 30, w - 30, h * 0.06, "PRACTICE RANGE", 700, 96, WHITE)
    ds.text(d, 30, w - 30, h * 0.125, "Range rules", 600, 60, WHITE)
    for n, words in enumerate(RULES):
        y = h * (0.23 + 0.105 * n)
        d.ellipse((40, y - 26, 92, y + 26), fill=FOREST)
        ds.text(d, 40, 92, y, str(n + 1), 700, 40, WHITE)
        ds.text(d, 116, w - 30, y, words, 600, 50, INK, anchor="lm")
    d.rectangle((0, h * 0.86, w, h), fill=YELLOW)
    ds.text(d, 30, w - 30, h * 0.93, "Red flag up: range hot", 700, 64, INK)
    return im


def chrono(rng: random.Random) -> Image.Image:
    im, d, w, h = canvas("chrono", WHITE)
    d.rectangle((14, 14, w - 14, h - 14), outline=INK, width=12)
    d.rectangle((14, 14, w - 14, h * 0.62), fill=INK)
    ds.text(d, 40, w - 40, h * 0.34, "CHRONO", 700, 230, YELLOW)
    ds.text(d, 40, w - 40, h * 0.8, "Every replica, every game day", 600, 70, INK)
    return im


def eye_pro(rng: random.Random) -> Image.Image:
    im, d, w, h = canvas("eye_pro", WHITE)
    r = h * 0.36
    cx, cy = h * 0.46, h * 0.5
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=INDIGO)
    goggles(d, cx, cy, r * 1.25, WHITE)
    x0 = h * 0.92
    for i, words in enumerate(("Eye protection", "must be worn", "beyond this point")):
        ds.text(d, x0, w - 24, h * (0.3 + 0.2 * i), words, 700, 54, INDIGO)
    return im


def lane(n: int):
    def draw(rng: random.Random) -> Image.Image:
        im, d, w, h = canvas("lane_%d" % n, YELLOW)
        d.rectangle((10, 10, w - 10, h - 10), outline=INK, width=10)
        ds.text(d, 20, w - 20, h * 0.54, str(n), 700, 200, INK)
        return im
    return draw


def safe_zone(rng: random.Random) -> Image.Image:
    im, d, w, h = canvas("safe_zone", SAFE_GREEN)
    d.rectangle((14, 14, w - 14, h - 14), outline=WHITE, width=10)
    ds.text(d, 40, w - 40, h * 0.36, "SAFE ZONE", 700, 150, WHITE)
    ds.text(d, 40, w - 40, h * 0.74, "Mags out  ·  barrel bags on", 600, 66, WHITE)
    return im


def range_hot(rng: random.Random) -> Image.Image:
    im, d, w, h = canvas("range_hot", WHITE)
    d.rectangle((0, 0, w, h * 0.55), fill=FLAG_RED)
    ds.text(d, 30, w - 30, h * 0.28, "RANGE HOT", 700, 130, WHITE)
    ds.text(d, 30, w - 30, h * 0.77, "while the red flag flies", 600, 62, INK)
    return im


DRAW = {"rules": rules, "chrono": chrono, "eye_pro": eye_pro, "lane_1": lane(1), "lane_2": lane(2), "lane_3": lane(3),
        "lane_4": lane(4), "safe_zone": safe_zone, "range_hot": range_hot}


def main() -> None:
    rng = random.Random(2117)
    sheet = Image.new("RGB", SHEET, (0x5A, 0x52, 0x48))
    for cell, draw in DRAW.items():
        x, y, w, h = CELLS[cell]
        im = ss.wear(draw(rng), rng, 0.6, 0.18).resize((w, h), Image.LANCZOS)
        sheet.paste(im, (x, y))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT, optimize=True)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
