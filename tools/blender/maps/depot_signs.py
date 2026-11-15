"""Depot's sign sheet (DX1): assets/textures/depot/signs.png, every printed face of Depot's wall extras in one 1024 x
1024 picture (cells in depot_cells.py): the fire assembly point, the fire action notice, the defibrillator sign, no
riding on pallet trucks, PPE stored here, the pallet storage area, fire exit keep clear and the fire point board's
header.

After the owner's 2026-11-15 photos (art/references/depot-props/signs/ and fire_points/): the usual safety signs, their
shapes and pictograms drawn plainly here, no maker's marks. Safety green, fire red and the palette's yellow keep their
meaning; the photos' blue is Alpha's hue, so the blue signs are a deep indigo, 24 degrees off it. Worn a little (grain,
a faded rim) as the station's are (station_signs.py, whose fonts and helpers this uses).

Needs Pillow, fontTools and brotli (the repo's fonts are WOFF2): pip install pillow fonttools brotli

    python3 -I tools/blender/maps/depot_signs.py <repo root>
"""

import math
import os
import random
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import station_signs as ss  # noqa: E402
from depot_cells import CELLS, SHEET  # noqa: E402

OUT = os.path.join(ss.ROOT, "assets", "textures", "depot", "signs.png")
SCALE = 2                          # each cell is drawn at twice its size, then fitted
WHITE = (0xF6, 0xF4, 0xEE)
INK = (0x1E, 0x1E, 0x20)
SAFE_GREEN = (0x16, 0x86, 0x3E)    # safe condition green (hue 141)
FIRE = (0xAC, 0x22, 0x64)          # the props' fire red (prop.PALETTE "fire"): its linear hue 24 degrees off Beta's
INDIGO = (0x4A, 0x2F, 0x7E)        # the photos' sign blue moved to violet: 27 degrees off Alpha's hue
YELLOW = ss.SIGN_YELLOW


def canvas(cell: str, fill: tuple) -> tuple:
    w, h = CELLS[cell][2] * SCALE, CELLS[cell][3] * SCALE
    im = Image.new("RGB", (w, h), fill)
    return im, ImageDraw.Draw(im), w, h


def text(d: ImageDraw.ImageDraw, x0: float, x1: float, y: float, words: str, weight: int, size: int,
         fill: tuple, anchor: str = "mm") -> None:
    """`words` fitted between x0 and x1 at height y (centred, or from x0 with anchor "lm")."""
    f = ss.font(weight, size)
    while d.textlength(words, font=f) > x1 - x0 - 8 and size > 12:
        size -= 2
        f = ss.font(weight, size)
    d.text(((x0 + x1) / 2 if anchor == "mm" else x0, y), words, font=f, fill=fill, anchor=anchor)


def person(d: ImageDraw.ImageDraw, cx: float, cy: float, s: float, fill: tuple) -> None:
    """A standing figure `s` px tall, its middle at (cx, cy): head, rounded body and legs (the assembly point's)."""
    r = s * 0.11
    d.ellipse((cx - r, cy - s / 2, cx + r, cy - s / 2 + 2 * r), fill=fill)
    top = cy - s / 2 + 2.3 * r
    d.rounded_rectangle((cx - s * 0.17, top, cx + s * 0.17, top + s * 0.38), radius=s * 0.06, fill=fill)
    for side in (-1, 1):
        a, b = cx + side * s * 0.02, cx + side * s * 0.13
        d.rectangle((min(a, b), top + s * 0.3, max(a, b), cy + s / 2), fill=fill)


def runner(d: ImageDraw.ImageDraw, cx: float, cy: float, s: float, fill: tuple) -> None:
    """The running figure of a fire exit sign, `s` px tall, running to the right."""
    w = max(2, int(s * 0.1))
    r = s * 0.1
    d.ellipse((cx + s * 0.08 - r, cy - s * 0.5, cx + s * 0.08 + r, cy - s * 0.5 + 2 * r), fill=fill)
    hip = (cx - s * 0.04, cy + s * 0.08)
    neck = (cx + s * 0.04, cy - s * 0.24)
    d.line([neck, hip], fill=fill, width=int(w * 1.5))
    d.line([neck, (cx + s * 0.22, cy - s * 0.1), (cx + s * 0.34, cy - s * 0.2)], fill=fill, width=w, joint="curve")
    d.line([neck, (cx - s * 0.14, cy - s * 0.14), (cx - s * 0.26, cy - s * 0.02)], fill=fill, width=w, joint="curve")
    d.line([hip, (cx + s * 0.16, cy + s * 0.24), (cx + s * 0.12, cy + s * 0.48)], fill=fill, width=w, joint="curve")
    d.line([hip, (cx - s * 0.18, cy + s * 0.28), (cx - s * 0.36, cy + s * 0.34)], fill=fill, width=w, joint="curve")


def assembly(rng: random.Random) -> Image.Image:
    im, d, w, h = canvas("assembly", WHITE)
    m = 16
    d.rounded_rectangle((m, m, w - m, h * 0.6), radius=12, fill=SAFE_GREEN)
    d.rounded_rectangle((m, h * 0.6 + 12, w - m, h - m), radius=12, fill=SAFE_GREEN)
    cx, cy = w / 2, h * 0.31
    for i, turn in enumerate((135, -135, 45, -45)):
        ox = (-1 if i % 2 == 0 else 1) * w * 0.17
        oy = (-1 if i < 2 else 1) * h * 0.17
        ss.arrow(d, cx + ox, cy + oy, h * 0.17, WHITE, turn)
    for k, dx in enumerate((-0.06, 0.06, 0.0)):
        person(d, cx + dx * w, cy + (0.02 if k < 2 else -0.01) * h, h * 0.22, WHITE)
    text(d, m, w - m, h * 0.72, "Fire assembly point", 700, int(h * 0.12), WHITE)
    text(d, m, w - m, h * 0.87, "Warehouse", 600, int(h * 0.11), WHITE)
    return im


def row_icon(d: ImageDraw.ImageDraw, box: tuple, kind: str) -> None:
    x0, y0, x1, y1 = box
    cx, cy, s = (x0 + x1) / 2, (y0 + y1) / 2, (y1 - y0)
    if kind == "alarm":
        d.rectangle(box, fill=FIRE)
        d.rectangle((cx - s * 0.25, cy - s * 0.25, cx + s * 0.25, cy + s * 0.25), outline=WHITE, width=4)
        d.ellipse((cx - s * 0.07, cy - s * 0.07, cx + s * 0.07, cy + s * 0.07), fill=WHITE)
    elif kind == "exit":
        d.rectangle(box, fill=SAFE_GREEN)
        runner(d, cx, cy, s * 0.8, WHITE)
    elif kind == "assemble":
        d.rectangle(box, fill=SAFE_GREEN)
        for dx in (-0.14, 0.14):
            person(d, cx + dx * s, cy, s * 0.6, WHITE)
    else:
        d.rectangle(box, fill=WHITE)
        d.ellipse((x0 + 6, y0 + 6, x1 - 6, y1 - 6), outline=FIRE, width=8)
        d.line((x0 + 18, y0 + 18, x1 - 18, y1 - 18), fill=FIRE, width=8)
        if kind == "return":
            runner(d, cx, cy, s * 0.55, INK)


def fire_action(rng: random.Random) -> Image.Image:
    im, d, w, h = canvas("fire_action", WHITE)
    m = 12
    d.rectangle((0, 0, w - 1, h - 1), outline=INK, width=4)
    d.ellipse((w / 2 - 34, m + 6, w / 2 + 34, m + 74), fill=INDIGO)
    d.rectangle((w / 2 - 6, m + 18, w / 2 + 6, m + 50), fill=WHITE)
    d.ellipse((w / 2 - 6, m + 56, w / 2 + 6, m + 68), fill=WHITE)
    d.rectangle((m, 96, w - m, 160), fill=INDIGO)
    text(d, m, w - m, 128, "Fire Action", 700, 56, WHITE)
    rows = [("alarm", INDIGO, "Raise the alarm"), ("exit", INDIGO, "Leave by the nearest exit"),
            ("assemble", INDIGO, "Go to the assembly point"), ("return", FIRE, "Do not go back in"),
            ("risk", FIRE, "Do not take any risks")]
    top, step = 172, (h - 172 - m) / len(rows)
    for i, (kind, band, words) in enumerate(rows):
        y0 = top + i * step + 4
        y1 = top + (i + 1) * step - 4
        row_icon(d, (m, y0, m + (y1 - y0), y1), kind)
        d.rectangle((m + (y1 - y0) + 6, y0, w - m, y1), fill=band)
        text(d, m + (y1 - y0) + 14, w - m, (y0 + y1) / 2, words, 600, 30, WHITE, "lm")
    return im


def defib(rng: random.Random) -> Image.Image:
    im, d, w, h = canvas("defib", SAFE_GREEN)
    text(d, 10, w - 10, h * 0.08, "Defibrillator", 700, 52, WHITE)
    # the defibrillator: a white case with a heart and its pulse line
    cx, cy = w / 2, h * 0.3
    d.rounded_rectangle((cx - 70, cy - 70, cx + 70, cy + 70), radius=18, fill=WHITE)
    d.rectangle((cx - 26, cy - 86, cx + 26, cy - 66), fill=WHITE)
    for sx in (-1, 1):
        d.ellipse((cx + sx * 22 - 26, cy - 34, cx + sx * 22 + 26, cy + 14), fill=FIRE)
    d.polygon([(cx - 48, cy - 6), (cx + 48, cy - 6), (cx, cy + 48)], fill=FIRE)
    d.line([(cx - 50, cy), (cx - 20, cy), (cx - 10, cy - 22), (cx + 4, cy + 22), (cx + 14, cy), (cx + 50, cy)],
           fill=WHITE, width=6)
    text(d, 10, w - 10, h * 0.6, "Nearest defibrillator", 600, 34, WHITE)
    d.rectangle((24, h * 0.66, w - 24, h * 0.78), fill=WHITE)
    text(d, 10, w - 10, h * 0.84, "Person in charge", 600, 32, WHITE)
    d.rectangle((24, h * 0.88, w - 24, h * 0.97), fill=WHITE)
    return im


def no_riding(rng: random.Random) -> Image.Image:
    im, d, w, h = canvas("no_riding", WHITE)
    cx, cy, r = w / 2, h * 0.3, w * 0.36
    # a figure standing on a pallet truck's deck, holding its tiller
    d.rectangle((cx - r * 0.75, cy + r * 0.42, cx + r * 0.45, cy + r * 0.52), fill=INK)
    for wx in (cx - r * 0.6, cx + r * 0.3):
        d.ellipse((wx - 14, cy + r * 0.5, wx + 14, cy + r * 0.5 + 28), fill=INK)
    d.line([(cx + r * 0.4, cy + r * 0.45), (cx + r * 0.62, cy - r * 0.35)], fill=INK, width=12)
    d.line([(cx + r * 0.5, cy - r * 0.38), (cx + r * 0.74, cy - r * 0.32)], fill=INK, width=12)
    person(d, cx - r * 0.12, cy - r * 0.06, r * 0.95, INK)
    d.line([(cx - r * 0.05, cy - r * 0.2), (cx + r * 0.55, cy - r * 0.25)], fill=INK, width=12)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=FIRE, width=34)
    a = math.radians(45)
    d.line([(cx - r * math.cos(a) * 0.92, cy - r * math.sin(a) * 0.92),
            (cx + r * math.cos(a) * 0.92, cy + r * math.sin(a) * 0.92)], fill=FIRE, width=34)
    d.rounded_rectangle((20, h * 0.6, w - 20, h - 20), radius=14, fill=FIRE)
    for i, words in enumerate(("No riding", "on pallet", "trucks")):
        text(d, 24, w - 24, h * (0.67 + 0.1 * i), words, 700, 64, WHITE)
    return im


def ppe(rng: random.Random) -> Image.Image:
    im, d, w, h = canvas("ppe", WHITE)
    d.rounded_rectangle((10, 10, w - 10, h - 10), radius=22, outline=INDIGO, width=18)
    for i, words in enumerate(("Personal", "Protective", "Equipment")):
        text(d, 40, w - 40, h * (0.2 + 0.18 * i), words, 700, 92, INDIGO)
    d.rectangle((90, h * 0.71, w - 90, h * 0.71 + 6), fill=INDIGO)
    text(d, 40, w - 40, h * 0.83, "Stored Here", 700, 92, INDIGO)
    return im


def pallet_storage(rng: random.Random) -> Image.Image:
    im, d, w, h = canvas("pallet_storage", YELLOW)
    step = 70
    for k in range(-h, w + h, step * 2):
        d.polygon([(k, 0), (k + step, 0), (k + step - h, h), (k - h, h)], fill=INK)
    d.rectangle((w * 0.12, h * 0.16, w * 0.88, h * 0.84), fill=YELLOW, outline=INK, width=8)
    for i, words in enumerate(("PALLET", "STORAGE", "AREA")):
        text(d, w * 0.14, w * 0.86, h * (0.3 + 0.2 * i), words, 700, 120, INK)
    return im


def fire_exit(rng: random.Random) -> Image.Image:
    im, d, w, h = canvas("fire_exit", WHITE)
    m = 10
    d.rectangle((m, m, h / 2 - 2, h / 2 - 4), fill=SAFE_GREEN)
    runner(d, (m + h / 2) / 2, (m + h / 2) / 2, h * 0.34, WHITE)
    d.rectangle((h / 2 + 8, m, w - m, h / 2 - 4), fill=SAFE_GREEN)
    text(d, h / 2 + 8, w - m, h * 0.25, "Fire exit", 700, int(h * 0.38), WHITE)
    d.ellipse((m + 8, h / 2 + 8, h / 2 - 10, h - m - 4), fill=INDIGO)
    cx = (m + h / 2) / 2
    d.rectangle((cx - 7, h / 2 + 26, cx + 7, h * 0.82), fill=WHITE)
    d.ellipse((cx - 8, h * 0.85, cx + 8, h * 0.85 + 16), fill=WHITE)
    d.rectangle((h / 2 + 8, h / 2 + 4, w - m, h - m), fill=INDIGO)
    text(d, h / 2 + 8, w - m, h * 0.74, "Keep clear", 700, int(h * 0.38), WHITE)
    return im


def fire_point(rng: random.Random) -> Image.Image:
    im, d, w, h = canvas("fire_point", WHITE)
    m = 10
    d.rectangle((m, m, w - m, h - m), fill=FIRE)
    # the extinguisher pictogram in its own square
    s = h - 2 * m - 20
    x0, y0 = m + 10, m + 10
    d.rectangle((x0, y0, x0 + s, y0 + s), outline=WHITE, width=6)
    cx = x0 + s * 0.5
    d.rounded_rectangle((cx - s * 0.12, y0 + s * 0.3, cx + s * 0.12, y0 + s * 0.88), radius=10, fill=WHITE)
    d.rectangle((cx - s * 0.05, y0 + s * 0.16, cx + s * 0.05, y0 + s * 0.3), fill=WHITE)
    d.line([(cx + s * 0.05, y0 + s * 0.2), (cx + s * 0.3, y0 + s * 0.3), (cx + s * 0.32, y0 + s * 0.6)], fill=WHITE,
           width=8)
    for k in range(3):
        y = y0 + s * (0.3 + 0.18 * k)
        d.line([(x0 + s * 0.12, y), (x0 + s * 0.24, y - s * 0.1)], fill=WHITE, width=6)
    text(d, x0 + s + 20, w - m, h * 0.5, "Fire Point", 700, int(h * 0.62), WHITE)
    return im


DRAW = {"assembly": assembly, "fire_action": fire_action, "defib": defib, "no_riding": no_riding, "ppe": ppe,
        "pallet_storage": pallet_storage, "fire_exit": fire_exit, "fire_point": fire_point}


def main() -> None:
    rng = random.Random(1115)
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
