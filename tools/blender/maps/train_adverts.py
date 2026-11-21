"""The trains' advert sheet (TQ2; the owner, 2026-11-21: "add adverts/posters to the signs above the windows inside the
train"): assets/textures/station/train_adverts.png, twelve landscape car cards in one 2048 x 768 picture (cells in
train_ad_cells.py), printed on the cove frames over the cars' windows (train.py, train_adverts.glb).

Every name and word is invented, in the station's town of Copperhill (station_signs.py): its tea, lemonade, lido,
night market, jazz cellar, tram museum, library, bakery and dentist, the airsoft club's skirmish day and goggles rule,
and the line's own "let them off first". No real brand, network or logo. Colours are the station posters' (kept off
both team hues: no blue, no orange); worn a little less than the station's (grain, a faint rim), the cars are clean.

Needs Pillow, fontTools and brotli (as station_signs.py): pip install pillow fonttools brotli

    python3 -I tools/blender/maps/train_adverts.py <repo root>
"""

import math
import os
import random
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from station_signs import (BUTTER, CREAM, CRIMSON, FOREST, GREEN, INK, NIGHT, PLASTER, ROOT, SIGN_YELLOW,  # noqa: E402
                           SLATE, TEAL, VIOLET, font, text_centre, wear)
from train_ad_cells import ADVERTS, CELL, CELLS, SHEET  # noqa: E402

OUT = os.path.join(ROOT, "assets", "textures", "station", "train_adverts.png")
DRAW = (CELL[0] * 2, CELL[1] * 2)   # each card drawn at twice its cell, then fitted to it
LOAF = (0xD8, 0xC8, 0xA8)           # a pale crust, too grey to read as orange


def words(d: ImageDraw.ImageDraw, x0: float, x1: float, rows: list) -> None:
    """Rows of (y share, text, weight, size, colour) centred between x0 and x1, each shrunk until it fits."""
    for y, text, weight, size, fill in rows:
        f = font(weight, size)
        while d.textlength(text, font=f) > x1 - x0 - 48 and size > 14:
            size -= 2
            f = font(weight, size)
        text_centre(d, ((x0 + x1) / 2, DRAW[1] * y), text, f, fill)


def card(kind: str, rng: random.Random) -> Image.Image:
    """The car card `kind`: a picture on the left (0 to `mid`), its words on the right."""
    w, h = DRAW
    mid = w * 0.40
    im = Image.new("RGB", (w, h), PLASTER)
    d = ImageDraw.Draw(im)
    if kind == "ad_a":
        # Halden Tea: a steaming cup on teal.
        d.rectangle((0, 0, w, h), fill=TEAL)
        cx, cy = mid * 0.5, h * 0.56
        d.ellipse((cx - 150, cy + 90, cx + 150, cy + 136), fill=CREAM)
        d.chord((cx - 115, cy - 80, cx + 115, cy + 126), 0, 180, fill=CREAM)
        d.rectangle((cx - 115, cy - 14, cx + 115, cy + 24), fill=CREAM)
        d.ellipse((cx + 92, cy - 8, cx + 170, cy + 66), outline=CREAM, width=18)
        d.ellipse((cx - 115, cy - 34, cx + 115, cy + 4), fill=FOREST)
        for k in (-48, 0, 48):
            d.line([(cx + k + 14 * math.sin(t / 10.0), cy - 50 - t) for t in range(0, 150, 4)], fill=CREAM, width=9)
        words(d, mid, w, [(0.34, "HALDEN TEA", 700, 120, CREAM), (0.58, "A proper cup, strong and hot", 600, 52, INK),
                          (0.78, "Brewed in Copperhill since 1931", 500, 40, CREAM)])
    elif kind == "ad_b":
        # Fizzbee lemonade: a bottle in a rising fizz on green.
        d.rectangle((0, 0, w, h), fill=GREEN)
        g = random.Random(3)
        for _ in range(30):
            x, y, r = g.uniform(20, mid - 20), g.uniform(20, h - 20), g.uniform(6, 18)
            d.ellipse((x - r, y - r, x + r, y + r), outline=CREAM, width=4)
        cx = mid * 0.5
        d.rounded_rectangle((cx - 70, h * 0.36, cx + 70, h * 0.92), 34, fill=BUTTER)
        d.polygon([(cx - 70, h * 0.40), (cx + 70, h * 0.40), (cx + 24, h * 0.22), (cx - 24, h * 0.22)], fill=BUTTER)
        d.rectangle((cx - 24, h * 0.12, cx + 24, h * 0.23), fill=BUTTER)
        d.rectangle((cx - 28, h * 0.10, cx + 28, h * 0.14), fill=FOREST)
        d.rectangle((cx - 70, h * 0.56, cx + 70, h * 0.70), fill=CREAM)
        text_centre(d, (cx, h * 0.63), "FIZZBEE", font(700, 40), GREEN)
        words(d, mid, w, [(0.32, "FIZZBEE", 700, 140, BUTTER), (0.58, "Cloudy lemonade you can hear", 600, 52, CREAM),
                          (0.78, "Ice cold at the station kiosk", 500, 40, INK)])
    elif kind == "ad_c":
        # Copperhill Lido: a sun over the waves on crimson, its words on cream.
        d.rectangle((0, 0, w, h), fill=CREAM)
        d.rectangle((0, 0, mid, h), fill=CRIMSON)
        d.ellipse((mid * 0.5 - 90, h * 0.14, mid * 0.5 + 90, h * 0.14 + 180), fill=CREAM)
        d.rectangle((0, h * 0.58, mid, h), fill=TEAL)
        for k in range(4):
            y = h * (0.60 + 0.1 * k)
            d.line([(x, y + 10 * math.sin(x / 24.0 + k)) for x in range(0, int(mid) + 8, 8)], fill=CREAM, width=10)
        words(d, mid, w, [(0.32, "COPPERHILL LIDO", 700, 112, CRIMSON), (0.58, "Open-air pool, open all summer", 600,
                                                                          52, INK),
                          (0.78, "Two stops east · bring a towel", 500, 40, TEAL)])
    elif kind == "ad_d":
        # Skirmish Sundays: pines in the morning, the words on forest.
        d.rectangle((0, 0, w, h), fill=BUTTER)
        d.ellipse((mid * 0.56, h * 0.10, mid * 0.56 + 130, h * 0.10 + 130), fill=CREAM)
        for x, s, c in ((0.12, 0.9, FOREST), (0.34, 1.2, GREEN), (0.58, 1.0, FOREST), (0.82, 1.15, GREEN)):
            bx, base = mid * x, h * 0.88
            for k in range(3):
                tw, th = 60 * s * (1.0 - 0.22 * k), 84 * s
                ty = base - k * 60 * s
                d.polygon([(bx - tw, ty), (bx + tw, ty), (bx, ty - th)], fill=c)
        d.rectangle((0, h * 0.88, mid, h), fill=FOREST)
        d.rectangle((mid, 0, w, h), fill=FOREST)
        words(d, mid, w, [(0.30, "SKIRMISH SUNDAYS", 700, 112, BUTTER),
                          (0.56, "Woodland site · gates open 9:00", 600, 52, CREAM),
                          (0.78, "Copperhill Airsoft Club · kit hire", 500, 40, BUTTER)])
    elif kind == "ad_e":
        # The night market: a string of lanterns under the arches.
        d.rectangle((0, 0, w, h), fill=NIGHT)
        pts = [(x, 60 + 60 * math.sin(math.pi * x / mid)) for x in range(0, int(mid) + 8, 8)]
        d.line(pts, fill=CREAM, width=4)
        for k in range(5):
            x = mid * (0.1 + 0.2 * k)
            y = 60 + 60 * math.sin(math.pi * x / mid)
            c = (SIGN_YELLOW, CREAM, TEAL, BUTTER)[k % 4]
            d.line([(x, y), (x, y + 22)], fill=CREAM, width=3)
            d.ellipse((x - 22, y + 20, x + 22, y + 70), fill=c)
        for k in range(3):
            ax = mid * (0.18 + 0.32 * k)
            d.arc((ax - 70, h * 0.48, ax + 70, h * 0.48 + 140), 180, 360, fill=SLATE, width=18)
            d.rectangle((ax - 79, h * 0.48 + 70, ax - 61, h), fill=SLATE)
            d.rectangle((ax + 61, h * 0.48 + 70, ax + 79, h), fill=SLATE)
        words(d, mid, w, [(0.40, "NIGHT MARKET", 700, 124, BUTTER),
                          (0.63, "Fridays under the railway arches", 600, 52, CREAM),
                          (0.82, "Street food · records · 6 till late", 500, 40, CREAM)])
    elif kind == "ad_f":
        # The Cellar: notes rising from a double bass on violet.
        d.rectangle((0, 0, w, h), fill=VIOLET)
        cx = mid * 0.45
        d.ellipse((cx - 80, h * 0.50, cx + 80, h * 0.94), fill=CREAM)
        d.ellipse((cx - 62, h * 0.30, cx + 62, h * 0.62), fill=CREAM)
        d.rectangle((cx - 10, h * 0.06, cx + 10, h * 0.40), fill=INK)
        d.ellipse((cx - 22, h * 0.70 - 10, cx + 22, h * 0.70 + 10), fill=VIOLET)
        for k, (nx, ny) in enumerate(((mid * 0.78, h * 0.30), (mid * 0.92, h * 0.16), (mid * 0.70, h * 0.62))):
            d.ellipse((nx - 22, ny - 16, nx + 22, ny + 16), fill=BUTTER)
            d.rectangle((nx + 14, ny - 80, nx + 22, ny), fill=BUTTER)
            if k == 0:
                d.polygon([(nx + 22, ny - 80), (nx + 56, ny - 56), (nx + 22, ny - 60)], fill=BUTTER)
        words(d, mid, w, [(0.32, "THE CELLAR", 700, 130, CREAM), (0.57, "Live jazz every night from 8", 600, 52,
                                                                  BUTTER),
                          (0.78, "Down the steps, Mill Lane", 500, 40, CREAM)])
    elif kind == "ad_g":
        # The tram museum: an old tram on cream.
        d.rectangle((0, 0, w, h), fill=CREAM)
        x0, x1, top, low = mid * 0.08, mid * 0.94, h * 0.34, h * 0.74
        d.line([(0, h * 0.16), (mid, h * 0.16)], fill=INK, width=4)
        d.line([(mid * 0.5, top), (mid * 0.64, h * 0.16)], fill=INK, width=6)
        d.rounded_rectangle((x0, top, x1, low), 26, fill=VIOLET)
        d.rectangle((x0, top + 76, x1, top + 86), fill=BUTTER)
        for k in range(4):
            wx = x0 + 22 + k * (x1 - x0 - 44) / 4
            d.rounded_rectangle((wx + 5, top + 16, wx + (x1 - x0 - 44) / 4 - 5, top + 66), 8, fill=PLASTER)
        for wx in (x0 + 64, x1 - 64):
            d.ellipse((wx - 30, low - 24, wx + 30, low + 36), fill=INK)
        d.rectangle((0, low + 30, mid, low + 40), fill=INK)
        words(d, mid, w, [(0.32, "TRAM MUSEUM", 700, 124, VIOLET), (0.57, "Ride a 1920s tram, free on Sundays", 600, 52,
                                                                    INK),
                          (0.78, "Depot Yard · two stops west", 500, 40, FOREST)])
    elif kind == "ad_h":
        # Late at the library: a stack of books on slate.
        d.rectangle((0, 0, w, h), fill=SLATE)
        y = h * 0.92
        for bw, bh, c, dx in ((300, 54, FOREST, 0), (270, 48, CRIMSON, 14), (310, 60, TEAL, -10), (250, 44, VIOLET, 20),
                              (280, 52, CREAM, -6), (230, 42, GREEN, 12)):
            x0 = mid * 0.5 - bw / 2 + dx
            d.rounded_rectangle((x0, y - bh, x0 + bw, y), 6, fill=c)
            d.rectangle((x0 + 20, y - bh * 0.62, x0 + bw - 20, y - bh * 0.5), fill=INK if c == CREAM else CREAM)
            y -= bh + 3
        words(d, mid, w, [(0.32, "READ LATE", 700, 130, CREAM), (0.57, "The library's open till 9 on Thursdays", 600,
                                                                 52, BUTTER),
                          (0.78, "Copperhill Library · Station Road", 500, 40, CREAM)])
    elif kind == "ad_i":
        # Kettle & Crumb: a warm loaf on forest, its words on cream.
        d.rectangle((0, 0, w, h), fill=CREAM)
        d.rectangle((0, 0, mid, h), fill=FOREST)
        cx = mid * 0.5
        d.chord((cx - 140, h * 0.40, cx + 140, h * 0.92), 180, 360, fill=LOAF)
        d.rectangle((cx - 140, h * 0.66 - 1, cx + 140, h * 0.80), fill=LOAF)
        for k in (-80, -20, 40, 100):
            d.line([(cx + k - 20, h * 0.50), (cx + k + 20, h * 0.62)], fill=PLASTER, width=10)
        d.rectangle((cx - 160, h * 0.80, cx + 160, h * 0.84), fill=CREAM)
        for k in (-50, 0, 50):
            d.line([(cx + k + 12 * math.sin(t / 10.0), h * 0.36 - t) for t in range(0, 110, 4)], fill=CREAM, width=8)
        words(d, mid, w, [(0.32, "KETTLE & CRUMB", 700, 120, FOREST), (0.57, "Fresh bread from 6 every morning", 600,
                                                                       52, INK),
                          (0.78, "The bakery by the station steps", 500, 40, FOREST)])
    elif kind == "ad_j":
        # Goggles on: a pair of goggles on butter.
        d.rectangle((0, 0, w, h), fill=BUTTER)
        cx, cy = mid * 0.5, h * 0.5
        d.rectangle((0, cy - 16, mid, cy + 16), fill=INK)
        d.rounded_rectangle((cx - 170, cy - 80, cx + 170, cy + 80), 70, fill=INK)
        for sx in (-1, 1):
            d.rounded_rectangle((cx + sx * 84 - 70, cy - 54, cx + sx * 84 + 70, cy + 54), 48, fill=CREAM)
            d.line([(cx + sx * 84 - 34, cy - 32), (cx + sx * 84 - 4, cy - 40)], fill=PLASTER, width=9)
        d.pieslice((cx - 30, cy + 40, cx + 30, cy + 120), 180, 360, fill=BUTTER)
        words(d, mid, w, [(0.32, "GOGGLES ON", 700, 140, INK), (0.57, "Eyes aren't spare parts", 600, 56, INK),
                          (0.78, "Rule one, every game · Copperhill Airsoft Club", 500, 40, INK)])
    elif kind == "ad_k":
        # The line's own: let them off first, two arrows out and one in.
        d.rectangle((0, 0, w, h), fill=SLATE)
        for k, (cx, turn) in enumerate(((mid * 0.24, 270.0), (mid * 0.76, 90.0))):
            s = 120 / 2.0
            pts = [(0, -s), (0.62 * s, -0.05 * s), (0.2 * s, -0.05 * s), (0.2 * s, s), (-0.2 * s, s),
                   (-0.2 * s, -0.05 * s), (-0.62 * s, -0.05 * s)]
            a = math.radians(turn)
            d.polygon([(cx + x * math.cos(a) - y * math.sin(a), h * 0.36 + x * math.sin(a) + y * math.cos(a))
                       for x, y in pts], fill=SIGN_YELLOW)
        d.rectangle((mid * 0.46, h * 0.12, mid * 0.54, h * 0.60), fill=CREAM)
        d.polygon([(mid * 0.5 - 70, h * 0.92), (mid * 0.5 + 70, h * 0.92), (mid * 0.5, h * 0.70)], fill=SIGN_YELLOW)
        words(d, mid, w, [(0.32, "LET THEM OFF FIRST", 700, 120, SIGN_YELLOW),
                          (0.57, "Then step in, and mind the gap", 600, 52, CREAM),
                          (0.78, "Thank you for travelling with us", 500, 40, CREAM)])
    else:
        # Pebble Dental: a smiling tooth on green, its words on plaster.
        d.rectangle((0, 0, mid, h), fill=GREEN)
        cx, cy = mid * 0.5, h * 0.50
        d.rounded_rectangle((cx - 110, cy - 130, cx + 110, cy + 40), 70, fill=CREAM)
        for sx in (-1, 1):
            d.rounded_rectangle((cx + sx * 60 - 46, cy, cx + sx * 60 + 46, cy + 150), 40, fill=CREAM)
        d.arc((cx - 50, cy - 70, cx + 50, cy + 10), 20, 160, fill=INK, width=10)
        for sx in (-1, 1):
            d.ellipse((cx + sx * 40 - 10, cy - 80, cx + sx * 40 + 10, cy - 58), fill=INK)
        words(d, mid, w, [(0.32, "PEBBLE DENTAL", 700, 124, GREEN), (0.57, "Smile, it's only a check-up", 600, 52, INK),
                          (0.78, "New patients welcome · High Street", 500, 40, FOREST)])
    im = im.resize(CELL, Image.LANCZOS)
    return wear(im, rng, 0.7, 0.25)


def main() -> None:
    rng = random.Random(17)
    sheet = Image.new("RGB", SHEET, PLASTER)
    for k in ADVERTS:
        x, y, w, h = CELLS[k]
        im = card(k, rng)
        assert im.size == (w, h), k
        sheet.paste(im, (x, y))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT, optimize=True)
    print("%s: %d x %d, %d cards" % (os.path.relpath(OUT, ROOT), SHEET[0], SHEET[1], len(ADVERTS)))


if __name__ == "__main__":
    main()
