"""Woodland's tree textures (WQ1, 2026-11-21): the barks and the leaf sheet its trees, thickets, ferns and bushes are
drawn with (game/play/look/look_foliage.gdshader), from the CC0 ambientCG maps `woodland_fetch.gd` caches and leaves,
needles and fronds drawn here.

    godot --headless --path . -s res://tools/textures/woodland_fetch.gd -- <cache>
    python3 -I tools/textures/woodland_textures.py <repo root> <cache>

then import with `godot --headless --path . --import`. Every file is the same every run (seeded).

The colour maps are DETAIL, not paint: a model keeps its palette colours in its vertices (the look's palette, checked
off the team hues by the build scripts) and the shader multiplies them by twice the map, so a texel of 0.5 draws the
paint as it is, darker texels its furrows, shadows and veins, lighter its lit edges. Each photo is divided by its own
blurred mean (the light and colour of the day it was taken go, its relief stays) and kept a little of its own hue.

- `bark_pine.png`, `bark_pine_nor.png`: Bark002, long plated furrows: the pines' lower bole and the oak's limbs' kin.
- `bark_flake.png`, `bark_flake_nor.png`: Bark014, the thin papery flakes of a pine's upper bole (blended in by the
  model's UV2.x).
- `bark_oak.png`, `bark_oak_nor.png`: Bark001, deep blocky oak furrows.
- `bark_birch.png`, `bark_birch_nor.png`: drawn here: a birch's chalky skin with dark lenticels across it, black
  rough diamonds and fissured patches, tiling.
- `surfaces.png`, `surfaces_nor.png`: the structures' and props' surface layers, 512 px each side by side
  (SURFACE_LAYERS and mapkit.SURFACES keep the same order), imported as texture arrays: plain, sawn softwood, log
  bark, sawn ends, concrete, galvanised steel, earth and moss (look_surface.gdshader).
- `leaves.png`: the leaf sheet, 2048 px, a 4 x 4 grid of 512 px cells (CELLS names them; the build scripts'
  treekit.CELLS keeps the same), alpha the leaves' cut-out: pine needle tufts, a young pine's shoot, spruce sprigs,
  oak and birch sprays, hazel sprays, fern fronds; its last row opaque: broadleaf and needle masses for a crown's
  core, and twig bark for the branches.
"""

import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

BARK = 1024
SHEET = 2048
CELL = 512
DRAW = 2          # cells are drawn at twice their size and halved (smooth edges)
SEED = 20261121
OUT = "assets/textures/woodland"

# The sheet's cells, (column, row): treekit.CELLS keeps the same names and places.
CELLS = {
    "pine_a": (0, 0), "pine_b": (1, 0), "pine_young": (2, 0), "spruce_a": (3, 0),
    "oak_a": (0, 1), "oak_b": (1, 1), "birch_a": (2, 1), "birch_b": (3, 1),
    "fern_a": (0, 2), "fern_b": (1, 2), "hazel": (2, 2), "spruce_b": (3, 2),
    "leaf_mass": (0, 3), "needle_mass": (1, 3), "twig": (2, 3), "twig_birch": (3, 3),
}


# ---------------------------------------------------------------------------------------------------- helpers
def load(cache: str, name: str) -> np.ndarray:
    img = Image.open(os.path.join(cache, name + ".png")).convert("RGBA")
    return np.asarray(img).astype(np.float32) / 255.0


def blur(a: np.ndarray, r: float) -> np.ndarray:
    """A tiling Gaussian blur of `a` (H x W x C or H x W), radius `r` px, in the frequency domain."""
    h, w = a.shape[:2]
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2.0 * (math.pi * r) ** 2 * (fx * fx + fy * fy))
    if a.ndim == 2:
        return np.real(np.fft.ifft2(np.fft.fft2(a) * g))
    return np.stack([np.real(np.fft.ifft2(np.fft.fft2(a[..., c]) * g)) for c in range(a.shape[2])], axis=-1)


def srgb_to_linear(c: np.ndarray) -> np.ndarray:
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def detail(photo: np.ndarray, contrast: float, hue_keep: float) -> np.ndarray:
    """A photo's colour as detail (mean 1): divided by its own broad mean, its relief `contrast` times as strong, a
    `hue_keep` share of its own hue against grey."""
    lin = srgb_to_linear(photo[..., :3])
    mean = blur(lin, 96.0)
    rel = lin / np.maximum(mean, 1e-3)
    luma = rel @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    luma = 1.0 + (luma - 1.0) * contrast
    hue = rel / np.maximum(rel @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32), 1e-3)[..., None]
    hue = 1.0 + (hue - 1.0) * hue_keep
    return np.clip(luma[..., None] * hue, 0.0, 1.99)


def save_detail(d: np.ndarray, path: str, size: int) -> None:
    img = Image.fromarray(np.clip(d * 0.5 * 255.0 + 0.5, 0, 255).astype(np.uint8), "RGB")
    if img.size != (size, size):
        img = img.resize((size, size), Image.LANCZOS)
    img.save(path, optimize=True)


def save_normal(n: np.ndarray, path: str, size: int, strength: float = 1.0) -> None:
    """An OpenGL normal map (x, y in R, G; 0.5 flat), its slopes `strength` times as steep."""
    x = (n[..., 0] - 0.5) * strength
    y = (n[..., 1] - 0.5) * strength
    z = np.sqrt(np.clip(0.25 - x * x - y * y, 0.0, 1.0))
    img = np.stack([x + 0.5, y + 0.5, z + 0.5], axis=-1)
    out = Image.fromarray(np.clip(img * 255.0 + 0.5, 0, 255).astype(np.uint8), "RGB")
    if out.size != (size, size):
        out = out.resize((size, size), Image.LANCZOS)
    out.save(path, optimize=True)


def normal_from_height(h: np.ndarray, strength: float) -> np.ndarray:
    """An OpenGL normal map (0..1) of height field `h` (tiling)."""
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5 * strength
    dy = (np.roll(h, 1, axis=0) - np.roll(h, -1, axis=0)) * 0.5 * strength
    n = np.stack([-dx, -dy, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def noise(shape: tuple, scale: float, rng: np.random.Generator) -> np.ndarray:
    """Tiling noise of features about `scale` px, mean 0, deviation 1."""
    n = blur(rng.standard_normal(shape).astype(np.float32), scale)
    return (n - n.mean()) / (n.std() + 1e-6)


# ---------------------------------------------------------------------------------------------------- barks
def barks(cache: str, out: str) -> None:
    for name, src, contrast, hue, nstr in (("bark_pine", "Bark002", 1.25, 0.35, 1.2),
                                           ("bark_flake", "Bark014", 0.8, 0.1, 0.8),
                                           ("bark_oak", "Bark001", 1.1, 0.25, 1.3)):
        col = load(cache, src + "_Color")
        save_detail(detail(col, contrast, hue), os.path.join(out, name + ".png"), BARK)
        save_normal(load(cache, src + "_NormalGL"), os.path.join(out, name + "_nor.png"), BARK, nstr)
    birch(out)


def birch(out: str) -> None:
    """A birch's skin, tiling: chalky white, faintly banded, dark lenticels as short streaks across the stem (u),
    a few black rough patches and fissures, and the odd peeling curl edge."""
    rng = np.random.default_rng(SEED + 7)
    n = BARK
    d = np.ones((n, n), dtype=np.float32)
    d += 0.04 * noise((n, n), 24.0, rng) + 0.03 * noise((n, n), 4.0, rng)
    # a faint warm-grey banding up the stem
    rows = noise((n, 1), 30.0, rng)
    d -= 0.05 * np.clip(rows, 0.0, None)
    img = Image.fromarray(np.zeros((n, n), dtype=np.uint8), "L")
    draw = ImageDraw.Draw(img)
    r = random.Random(SEED + 8)

    def wrap_line(x0: float, y0: float, x1: float, y1: float, w: int, v: int) -> None:
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                draw.line((x0 + ox, y0 + oy, x1 + ox, y1 + oy), fill=v, width=w)

    def wrap_poly(pts: list, v: int) -> None:
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                draw.polygon([(x + ox, y + oy) for x, y in pts], fill=v)

    # lenticels: thin dark dashes across the stem
    for _ in range(520):
        x, y = r.uniform(0, n), r.uniform(0, n)
        ln = r.uniform(10, 46)
        wrap_line(x, y, x + ln, y + r.uniform(-1.5, 1.5), r.choice((2, 2, 3, 4)), r.randint(120, 200))
    # black rough patches (branch scars, diamonds) and fissures
    for _ in range(14):
        cx, cy = r.uniform(0, n), r.uniform(0, n)
        w, h = r.uniform(30, 90), r.uniform(18, 60)
        pts = []
        for k in range(12):
            a = math.tau * k / 12
            rr = r.uniform(0.6, 1.0)
            tall = 1.6 if abs(math.sin(a)) > 0.7 else 1.0
            pts.append((cx + math.cos(a) * w * rr, cy + math.sin(a) * h * rr * tall))
        wrap_poly(pts, r.randint(200, 240))
    for _ in range(40):
        x, y = r.uniform(0, n), r.uniform(0, n)
        pts = [(x, y)]
        for _k in range(5):
            x += r.uniform(-6, 6)
            y += r.uniform(10, 24)
            pts.append((x, y))
        for a, b in zip(pts, pts[1:]):
            wrap_line(a[0], a[1], b[0], b[1], r.choice((2, 3)), r.randint(150, 220))
    dark = np.asarray(img.filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255.0
    dark *= 0.9 + 0.1 * noise((n, n), 2.0, rng)
    d = d * (1.0 - 0.85 * dark)
    # the skin's warm grey under the chalk where it is dark
    rgb = np.stack([d, d * 0.985, d * 0.96], axis=-1)
    rgb = np.where(dark[..., None] > 0.3, rgb * np.array([1.05, 1.0, 0.92], dtype=np.float32), rgb)
    save_detail(np.clip(rgb, 0.0, 1.99), os.path.join(out, "bark_birch.png"), BARK)
    height = blur(1.0 - dark * 0.8 + 0.02 * noise((n, n), 3.0, rng), 1.0)
    nm = normal_from_height(height, 6.0)
    save_normal(nm, os.path.join(out, "bark_birch_nor.png"), BARK)


# ---------------------------------------------------------------------------------------------------- the leaf sheet
class Cell:
    """One cell of the leaf sheet drawn at DRAW times its size: colour (detail, mean 1 is the paint) and cover."""

    def __init__(self, seed: int, opaque: bool = False, ground: float = 0.45):
        s = CELL * DRAW
        self.s = s
        self.rng = random.Random(seed)
        self.col = Image.new("RGB", (s, s), (0, 0, 0))
        self.cov = Image.new("L", (s, s), 255 if opaque else 0)
        if opaque:
            g = int(ground * 127.5)
            self.col.paste((g, g, g), (0, 0, s, s))
        self.dc = ImageDraw.Draw(self.col)
        self.da = ImageDraw.Draw(self.cov)

    @staticmethod
    def rgb(c: tuple) -> tuple:
        """Detail (1 = the paint) as stored bytes (x 0.5)."""
        return tuple(int(max(0.0, min(1.99, v)) * 127.5) for v in c)

    def line(self, a: tuple, b: tuple, w: float, c: tuple) -> None:
        self.dc.line((a, b), fill=self.rgb(c), width=max(1, int(round(w))))
        self.da.line((a, b), fill=255, width=max(1, int(round(w))))

    def poly(self, pts: list, c: tuple) -> None:
        self.dc.polygon(pts, fill=self.rgb(c))
        self.da.polygon(pts, fill=255)

    def done(self) -> Image.Image:
        """The cell at its size, RGBA, its colour bled out under the cut-away (so mipmaps keep the leaves' colour)."""
        col = np.asarray(self.col).astype(np.float32)
        cov = np.asarray(self.cov).astype(np.float32) / 255.0
        # bleed: blurred colour weighted by cover, filling where there's none
        acc = col * cov[..., None]
        wsum = cov.copy()
        fill = np.zeros_like(col)
        wfill = np.zeros_like(cov)
        for r in (4, 12, 40, 120):
            a = np.asarray(Image.fromarray(np.clip(acc, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)))
            w = np.asarray(Image.fromarray((wsum * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)))
            a = a.astype(np.float32)
            w = w.astype(np.float32) / 255.0
            est = a / np.maximum(w[..., None], 1e-3)
            take = (wfill < 0.5) & (w > 0.02)
            fill[take] = est[take]
            wfill[take] = 1.0
        mean = (acc.sum(axis=(0, 1)) / max(1e-3, wsum.sum()))
        fill[wfill < 0.5] = mean
        col = col * cov[..., None] + fill * (1.0 - cov[..., None])
        rgba = np.dstack([col, cov * 255.0]).clip(0, 255).astype(np.uint8)
        return Image.fromarray(rgba, "RGBA").resize((CELL, CELL), Image.LANCZOS)


def vary(rng: random.Random, base: float, spread: float, warm: float = 0.0) -> tuple:
    """A detail colour near `base` (1 = the paint), `spread` either way, leaning warm (yellow) by up to `warm`."""
    v = base * rng.uniform(1.0 - spread, 1.0 + spread)
    w = rng.uniform(-0.3, 1.0) * warm
    return (v * (1.0 + 0.6 * w), v * (1.0 + 0.15 * w), v * (1.0 - 0.7 * w))


def bend(p0: tuple, ang: float, length: float, curl: float, n: int) -> list:
    """Points along a curved stroke from `p0` heading `ang` (radians, 0 = up the cell, image y down) bending `curl`."""
    pts = [p0]
    x, y = p0
    for i in range(n):
        a = ang + curl * (i + 1) / n
        x += math.sin(a) * length / n
        y -= math.cos(a) * length / n
        pts.append((x, y))
    return pts


def needle_shoot(cell: Cell, base: tuple, ang: float, length: float, needle: float, density: float,
                 spread: float, curl: float, shade: float, forward: float = 0.55, w: float = 3.0) -> None:
    """A pine shoot: a twig from `base` heading `ang`, `length` long, clothed along its outer three quarters in long
    needles `needle` long fanned `spread` radians off it and swept `forward` toward its tip (a bottlebrush seen from
    the side), the inner ones darker (deeper in), the tip's paler (new growth)."""
    rng = cell.rng
    path = bend(base, ang, length, curl, 8)
    count = int(length * density)
    strokes = []
    for i in range(count):
        t = 0.2 + 0.8 * (i / max(1, count - 1)) ** 0.8
        k = t * (len(path) - 1)
        j = min(int(k), len(path) - 2)
        f = k - j
        px = path[j][0] + (path[j + 1][0] - path[j][0]) * f
        py = path[j][1] + (path[j + 1][1] - path[j][1]) * f
        heading = ang + curl * t
        side = rng.choice((-1.0, 1.0))
        a = heading + side * rng.uniform(0.25, spread) * (1.0 - forward * 0.5)
        a = a * (1.0 - forward) + heading * forward if abs(a - heading) > 0.0 else a
        a += side * rng.uniform(0.1, 0.6)
        ln = needle * rng.uniform(0.7, 1.1) * (0.75 + 0.25 * math.sin(math.pi * min(1.0, t * 1.1)))
        tip = (px + math.sin(a) * ln, py - math.cos(a) * ln)
        mid = (px + math.sin(a + side * 0.12) * ln * 0.5, py - math.cos(a + side * 0.12) * ln * 0.5)
        depth = rng.random()
        c = vary(rng, shade * (0.62 + 0.5 * depth + 0.18 * t), 0.08, 0.25 if t > 0.85 else 0.08)
        strokes.append((depth, (px, py), mid, tip, c))
    # the twig under its needles
    for a, b in zip(path, path[1:]):
        cell.line(a, b, w * 1.6, (0.55, 0.42, 0.34))
    for _d, p, m, t, c in sorted(strokes, key=lambda s: s[0]):
        cell.line(p, m, w, c)
        cell.line(m, t, max(1.0, w * 0.75), tuple(v * 1.06 for v in c))
    # a pale bud at the tip
    x, y = path[-1]
    cell.poly([(x - 5, y + 4), (x, y - 14), (x + 5, y + 4)], (1.25, 1.15, 0.85))


def pine_cell(seed: int, young: bool = False) -> Image.Image:
    """A Scots pine's branch end (owner's photos, 01-pine-tree): a bare twig forking into long, narrow bottlebrush
    shoots that turn up at their ends, sky between them, so the spray reads as spiky needle brushes near and as a
    ragged tuft (never a round leaf) once mipped far off. A young pine's: a whorl of long brushes from one node."""
    c = Cell(seed)
    s = c.s
    rng = c.rng
    if young:
        # a young pine's whorl seen from the side: long, thin brushes radiating from its node with gaps between, the
        # upper ones longest (the photos' young pines), so it reads as a spiky star, never a fan or a hand
        hub = (s * 0.5, s * 0.56)
        for k in range(11):
            a = math.tau * k / 11 + rng.uniform(-0.12, 0.12)
            up = -math.cos(a)  # 1 straight up, -1 straight down
            ln = s * (0.36 + 0.08 * max(0.0, up) - 0.1 * max(0.0, -up)) * rng.uniform(0.85, 1.05)
            needle_shoot(c, hub, a, ln, s * 0.075, 0.9, 1.1, -0.35 * math.sin(a), rng.uniform(0.7, 0.95),
                         forward=0.5, w=3.0)
        return c.done()
    # the twig up the cell, forking into brushes that fan out and turn up at their tips
    base = (s * 0.5, s * 0.97)
    hub = (s * 0.5 + rng.uniform(-15, 15), s * 0.74)
    c.line(base, hub, 10, (0.5, 0.4, 0.33))
    n = 7
    for k in range(n):
        a = -1.25 + 2.5 * k / (n - 1) + rng.uniform(-0.1, 0.1)
        ln = s * rng.uniform(0.36, 0.5) * (1.0 - 0.25 * abs(a) / 1.25)
        needle_shoot(c, hub, a, ln, s * 0.08, 1.1, 1.1, -0.45 * a, rng.uniform(0.7, 0.95), forward=0.45, w=4.0)
        # a short side shoot off the brush's middle
        if rng.random() < 0.6:
            mid = (hub[0] + math.sin(a) * ln * 0.45, hub[1] - math.cos(a) * ln * 0.45)
            sa = a + rng.choice((-1.0, 1.0)) * rng.uniform(0.5, 0.8)
            needle_shoot(c, mid, sa, ln * 0.45, s * 0.07, 1.1, 1.1, -0.3 * sa, rng.uniform(0.65, 0.9),
                         forward=0.45, w=3.5)
    return c.done()


def spruce_cell(seed: int) -> Image.Image:
    """A spruce sprig seen from above: a flat, drooping spray, a main twig with side twigs in pairs, each combed with
    short stiff needles all round."""
    c = Cell(seed)
    s = c.s
    rng = c.rng
    main = bend((s * 0.5, s * 0.98), rng.uniform(-0.08, 0.08), s * 0.92, rng.uniform(-0.15, 0.15), 10)

    def comb(path: list, needle: float, shade: float) -> None:
        strokes = []
        for i in range(len(path) - 1):
            a, b = path[i], path[i + 1]
            seg = math.hypot(b[0] - a[0], b[1] - a[1])
            heading = math.atan2(b[0] - a[0], -(b[1] - a[1]))
            for k in range(int(seg / 3.2)):
                t = k * 3.2 / seg
                p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
                side = rng.choice((-1.0, 1.0))
                ang = heading + side * rng.uniform(0.55, 1.15)
                ln = needle * rng.uniform(0.75, 1.1)
                depth = rng.random()
                strokes.append((depth, p, (p[0] + math.sin(ang) * ln, p[1] - math.cos(ang) * ln),
                                vary(rng, shade * (0.7 + 0.45 * depth), 0.06, 0.06)))
        for a, b in zip(path, path[1:]):
            c.line(a, b, 5, (0.55, 0.45, 0.36))
        for _d, p, t, col in sorted(strokes, key=lambda q: q[0]):
            c.line(p, t, 3, col)

    sides = []
    for i in range(2, len(main) - 1):
        for side in (-1.0, 1.0):
            t = i / (len(main) - 1)
            if rng.random() < 0.18:
                continue  # a gap: the sprig's edge is ragged, never a clean diamond
            ln = s * 0.42 * (1.0 - t) ** 0.6 * rng.uniform(0.5, 1.1) + s * 0.06
            heading = math.atan2(main[i + 1][0] - main[i][0], -(main[i + 1][1] - main[i][1]))
            # side twigs hang: swept back and curling down (a spruce's drooping sprays)
            sides.append(bend(main[i], heading + side * rng.uniform(0.9, 1.3), ln, -side * rng.uniform(0.3, 0.6), 6))
    for p in sides:
        comb(p, s * 0.045, 0.95)
    comb(main, s * 0.05, 1.05)
    return c.done()


def leaf_shape(kind: str, rng: random.Random) -> list:
    """A leaf's outline in its own space: its stalk's end at (0, 0), its tip at (0, -1), x across."""
    pts = []
    if kind == "oak":
        # an English oak's: short stalk, 4 or 5 deep round lobes a side, widest past the middle, an earred base
        lobes = rng.choice((4, 5))
        n = 90
        for side in (1.0, -1.0):
            half = []
            for k in range(n + 1):
                t = k / n                     # 0 base .. 1 tip
                env = math.sin(math.pi * (0.08 + 0.9 * t) ** 0.9) * (0.36 + 0.1 * t)
                wave = 0.5 + 0.5 * math.cos(math.tau * lobes * t + (0.4 if side > 0 else 0.9))
                r = env * (0.55 + 0.45 * wave ** 0.7)
                if t < 0.08:
                    r = 0.12 * math.sin(math.pi * t / 0.08) + 0.02
                half.append((side * r, -0.06 - 0.94 * t))
            pts += half if side > 0 else list(reversed(half))
        return pts
    if kind == "birch":
        # a birch's: a small triangle-ovate leaf, toothed, pointed
        n = 60
        for side in (1.0, -1.0):
            half = []
            for k in range(n + 1):
                t = k / n
                env = 0.42 * (math.sin(math.pi * t ** 0.75)) * (1.0 - 0.45 * t)
                tooth = 0.03 * (k % 3 == 0)
                half.append((side * (env + tooth), -0.12 - 0.88 * t))
            pts += half if side > 0 else list(reversed(half))
        return pts
    # hazel: round, heart-based, a short point, double-toothed
    n = 70
    for side in (1.0, -1.0):
        half = []
        for k in range(n + 1):
            t = k / n
            env = 0.5 * math.sin(math.pi * min(1.0, t * 1.05) ** 0.8) * (1.05 - 0.35 * t ** 2)
            tooth = 0.025 * (k % 2) + 0.02 * (k % 5 == 0)
            half.append((side * (env + tooth), -0.1 - 0.9 * t))
        pts += half if side > 0 else list(reversed(half))
    return pts


def draw_leaf(c: Cell, at: tuple, ang: float, size: float, kind: str, shade: float, warm: float) -> None:
    """A leaf `size` px long, stalk at `at`, pointing `ang`: filled, its far half shaded (a fold at the midrib), with
    a midrib and side veins drawn darker."""
    rng = c.rng
    shape = leaf_shape(kind, rng)
    ca, sa = math.cos(ang), math.sin(ang)

    def tx(p: tuple) -> tuple:
        x, y = p[0] * size, p[1] * size
        return (at[0] + x * ca - y * sa, at[1] + x * sa + y * ca)

    base = vary(rng, shade, 0.1, warm)
    c.poly([tx(p) for p in shape], base)
    # the fold: one half a shade darker
    half = [p for p in shape if p[0] <= 0.0]
    if len(half) > 3:
        dim = 0.82 if rng.random() < 0.5 else 1.1
        c.dc.polygon([tx(p) for p in half] + [tx((0.0, -1.0)), tx((0.0, -0.05))],
                     fill=c.rgb(tuple(v * dim for v in base)))
    vein = tuple(v * 0.78 for v in base)
    w = max(1.0, size * 0.025)
    c.dc.line((tx((0.0, 0.12)), tx((0.0, -0.95))), fill=c.rgb((0.85, 0.8, 0.6)), width=int(round(w * 1.3)))
    c.da.line((tx((0.0, 0.12)), tx((0.0, 0.0))), fill=255, width=int(round(w * 1.3)))
    for k in range(1, 6):
        t = -0.15 - 0.14 * k
        for side in (1.0, -1.0):
            c.dc.line((tx((0.0, t)), tx((side * 0.3, t - 0.12))), fill=c.rgb(vein), width=max(1, int(w * 0.7)))


def spray_cell(seed: int, kind: str) -> Image.Image:
    """A spray of leaves: a twig forking up the cell, leaves on short stalks along it and clustered at the ends
    (oak in rosettes at the shoots' ends; birch small and many, hanging; hazel big and round, alternate)."""
    c = Cell(seed)
    s = c.s
    rng = c.rng
    size = {"oak": s * 0.17, "birch": s * 0.11, "hazel": s * 0.2}[kind]
    count = {"oak": 34, "birch": 60, "hazel": 22}[kind]
    twigs = []
    main = bend((s * 0.5, s * 0.99), rng.uniform(-0.1, 0.1), s * 0.8, rng.uniform(-0.3, 0.3), 8)
    twigs.append(main)
    for i in (2, 4, 5, 6):
        side = rng.choice((-1.0, 1.0))
        twigs.append(bend(main[i], side * rng.uniform(0.6, 1.0), s * rng.uniform(0.25, 0.4), -side * 0.3, 5))
    for t in twigs:
        for a, b in zip(t, t[1:]):
            c.line(a, b, 6 if t is main else 4, (0.55, 0.43, 0.35))
    leaves = []
    for _ in range(count):
        t = rng.choice(twigs)
        if kind == "oak":
            f = rng.uniform(0.65, 1.0) if rng.random() < 0.75 else rng.uniform(0.3, 0.65)
        else:
            f = rng.uniform(0.15, 1.0)
        k = f * (len(t) - 1)
        j = min(int(k), len(t) - 2)
        p = (t[j][0] + (t[j + 1][0] - t[j][0]) * (k - j), t[j][1] + (t[j + 1][1] - t[j][1]) * (k - j))
        ang = rng.uniform(-math.pi, math.pi)
        if kind == "birch":
            ang = rng.uniform(1.8, 4.5)   # hanging
        leaves.append((rng.random(), p, ang, size * rng.uniform(0.7, 1.1)))
    for depth, p, ang, sz in sorted(leaves, key=lambda q: q[0]):
        draw_leaf(c, p, ang, sz, kind, 0.66 + 0.48 * depth, 0.18)
    return c.done()


def fern_cell(seed: int) -> Image.Image:
    """A bracken / male-fern frond, base at the cell's foot, tip at its top: a stalk, then pinnae in pairs, longest a
    third of the way up, each cut into rounded pinnules, the frond's tip curled a little."""
    c = Cell(seed)
    s = c.s
    rng = c.rng
    rach = bend((s * 0.5, s * 0.995), rng.uniform(-0.05, 0.05), s * 0.97, rng.uniform(-0.25, 0.25), 34)
    for a, b in zip(rach, rach[1:]):
        c.line(a, b, 6, (0.72, 0.68, 0.48))
    n = len(rach)
    for i in range(5, n - 1, 2):
        t = (i - 5) / (n - 6)
        heading = math.atan2(rach[i + 1][0] - rach[i][0], -(rach[i + 1][1] - rach[i][1]))
        ln = s * 0.4 * math.sin(math.pi * min(1.0, 0.12 + t * 1.0) ** 0.7) * (1.0 - 0.7 * t) + s * 0.02
        for side in (-1.0, 1.0):
            ang = heading + side * (1.15 - 0.4 * t)
            pin = bend(rach[i], ang, ln, -side * 0.35, 6)
            depth = rng.random()
            shade = 0.6 + 0.65 * depth  # each pinna its own depth in the clump: dark deep, pale on top
            for a, b in zip(pin, pin[1:]):
                c.line(a, b, 3, (0.8, 0.8, 0.55))
            # pinnules: rounded lobes along the pinna both sides
            m = max(2, int(ln / 17))
            for k in range(m):
                f = (k + 0.5) / m
                q = (pin[0][0] + (pin[-1][0] - pin[0][0]) * f, pin[0][1] + (pin[-1][1] - pin[0][1]) * f)
                lobe = (1.0 - f * 0.65) * s * 0.016 + 3
                for sd in (-1.0, 1.0):
                    # a pinnule: a narrow, blunt, forward-swept lobe off the pinna
                    aa = ang + sd * 0.95 + side * 0.0
                    tip = (q[0] + math.sin(aa - sd * 0.35) * lobe * 1.6, q[1] - math.cos(aa - sd * 0.35) * lobe * 1.6)
                    wv = (math.cos(aa) * lobe * 0.38, math.sin(aa) * lobe * 0.38)
                    pts = [(q[0] - wv[0], q[1] - wv[1]), (q[0] + wv[0], q[1] + wv[1]),
                           (tip[0] + wv[0] * 0.6, tip[1] + wv[1] * 0.6), tip,
                           (tip[0] - wv[0] * 0.6, tip[1] - wv[1] * 0.6)]
                    # the pinnules facing the light paler than those turned from it, so a frond shows its relief
                    lit = 1.14 if sd > 0.0 else 0.8
                    c.poly(pts, vary(rng, shade * lit * (0.92 + 0.12 * (1 - f)), 0.07, 0.25))
    return c.done()


def mass_cell(seed: int, needles: bool) -> Image.Image:
    """An opaque mass for a crown's core: leaves (or needle brushes) packed over a dark ground, tiling enough that a
    crown's core reads as foliage deep in shade, not as a smooth ball."""
    c = Cell(seed, opaque=True, ground=0.42)
    s = c.s
    rng = c.rng
    if needles:
        for _ in range(260):
            p = (rng.uniform(0, s), rng.uniform(0, s))
            ang = rng.uniform(-math.pi, math.pi)
            ln = s * rng.uniform(0.04, 0.09)
            sh = rng.uniform(0.55, 1.05)
            for _k in range(9):
                a = ang + rng.uniform(-0.6, 0.6)
                c.dc.line((p, (p[0] + math.sin(a) * ln, p[1] - math.cos(a) * ln)), fill=c.rgb(vary(rng, sh, 0.1, 0.1)),
                          width=3)
    else:
        for _ in range(520):
            p = (rng.uniform(0, s), rng.uniform(0, s))
            depth = rng.random()
            draw_leaf(c, p, rng.uniform(-math.pi, math.pi), s * rng.uniform(0.06, 0.09), rng.choice(("oak", "hazel")),
                      0.55 + 0.5 * depth, 0.12)
    img = c.done()
    a = np.asarray(img).copy()
    a[..., 3] = 255
    return Image.fromarray(a, "RGBA")


def twig_cell(cache: str, birch_twig: bool) -> Image.Image:
    """Bark for the crowns' branches (opaque), drawn round each branch and along it: the pine bark's detail, finer;
    a birch's twigs dark purple-brown, smooth with pale lenticels."""
    if birch_twig:
        rng = np.random.default_rng(SEED + 11)
        d = 0.75 + 0.05 * noise((CELL, CELL), 6.0, rng)
        dots = (noise((CELL, CELL), 1.2, rng) > 2.6).astype(np.float32)
        d = d + 0.35 * blur(dots, 0.8)
        rgb = np.stack([d, d * 0.92, d * 0.9], axis=-1)
    else:
        rgb = detail(load(cache, "Bark002_Color"), 1.0, 0.3)
        small = Image.fromarray(np.clip(rgb * 127.5, 0, 255).astype(np.uint8)).resize((CELL, CELL), Image.LANCZOS)
        rgb = np.asarray(small)
        rgb = rgb.astype(np.float32) / 127.5
    out = np.dstack([np.clip(rgb * 127.5, 0, 255), np.full((CELL, CELL), 255.0)]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def sheet(cache: str, out: str) -> None:
    cells = {
        "pine_a": pine_cell(SEED + 1), "pine_b": pine_cell(SEED + 2), "pine_young": pine_cell(SEED + 3, True),
        "spruce_a": spruce_cell(SEED + 4), "spruce_b": spruce_cell(SEED + 5),
        "oak_a": spray_cell(SEED + 6, "oak"), "oak_b": spray_cell(SEED + 7, "oak"),
        "birch_a": spray_cell(SEED + 8, "birch"), "birch_b": spray_cell(SEED + 9, "birch"),
        "hazel": spray_cell(SEED + 10, "hazel"),
        "fern_a": fern_cell(SEED + 12), "fern_b": fern_cell(SEED + 13),
        "leaf_mass": mass_cell(SEED + 14, False), "needle_mass": mass_cell(SEED + 15, True),
        "twig": twig_cell(cache, False), "twig_birch": twig_cell(cache, True),
    }
    img = Image.new("RGBA", (SHEET, SHEET), (0, 0, 0, 0))
    for name, (cx, cy) in CELLS.items():
        img.paste(cells[name], (cx * CELL, cy * CELL))
    img.save(os.path.join(out, "leaves.png"), optimize=True)


# ---------------------------------------------------------------------------------------------------- surfaces
SURF = 512
# The layers of surfaces.png and surfaces_nor.png (mapkit.SURFACES names them by number): its ambientCG set, the
# relief's strength and whether the set's grain runs up it (turned to run along u, a face's longest edge).
SURFACE_LAYERS = [
    None,                               # 0 plain
    ("Wood058", 1.5, 0.2, 1.2, True),   # 1 sawn, weathered softwood: its grain along the board
    ("Bark002", 1.1, 0.25, 1.0, True),  # 2 a log's bark, its furrows along the log
    "end",                              # 3 sawn and split ends: drawn here
    ("Concrete034", 1.8, 0.15, 1.4, False),  # 4 cast concrete: its pits and board marks strong enough to read
    ("Metal038", 1.2, 0.1, 0.6, False),  # 5 galvanised and weathered steel
    ("Ground054", 1.0, 0.3, 1.0, False),  # 6 earth
    ("Moss002", 1.0, 0.4, 1.0, False),  # 7 moss
]


def surfaces(cache: str, out: str) -> None:
    """The props' surface layers side by side (SURF px each): detail as the barks' (mean 0.5) and their OpenGL normal
    maps, for look_surface.gdshader's two texture arrays (imported sliced, a layer a column)."""
    n = len(SURFACE_LAYERS)
    col = np.full((SURF, SURF * n, 3), 0.5, dtype=np.float32)
    nor = np.zeros((SURF, SURF * n, 3), dtype=np.float32)
    nor[..., 0] = 0.5
    nor[..., 1] = 0.5
    nor[..., 2] = 1.0
    rng = np.random.default_rng(SEED + 21)
    for i, spec in enumerate(SURFACE_LAYERS):
        x = i * SURF
        if spec is None:
            continue
        if spec == "end":
            # a sawn end: fine tear-out speckle over slow blotches, faint saw marks across
            size = 1024
            d = 1.0 + 0.08 * noise((size, size), 40.0, rng) + 0.07 * noise((size, size), 1.5, rng)
            marks = np.sin(np.linspace(0.0, 60.0 * math.pi, size))[:, None] * 0.03
            d = d + marks + 0.03 * noise((size, size), 6.0, rng)
            rgb = np.stack([d, d * 0.99, d * 0.97], axis=-1)
            h = blur(d, 1.0)
            n_map = normal_from_height(h, 8.0)
        else:
            name, contrast, hue, strength, turn = spec
            photo = load(cache, name + "_Color")
            rgb = detail(photo, contrast, hue)
            n_map = load(cache, name + "_NormalGL")[..., :3]
            if turn:
                rgb = np.rot90(rgb).copy()
                # a quarter turn of a normal map: its x and y swap (and one flips)
                nm = np.rot90(n_map).copy()
                n_map = np.stack([1.0 - nm[..., 1], nm[..., 0], nm[..., 2]], axis=-1)
            n_map = np.concatenate([0.5 + (n_map[..., :2] - 0.5) * strength, n_map[..., 2:3]], axis=-1)
        small = Image.fromarray(np.clip(rgb * 127.5, 0, 255).astype(np.uint8)).resize((SURF, SURF), Image.LANCZOS)
        col[:, x:x + SURF] = np.asarray(small).astype(np.float32) / 127.5
        small_n = Image.fromarray(np.clip(n_map * 255.0, 0, 255).astype(np.uint8)).resize((SURF, SURF), Image.LANCZOS)
        nor[:, x:x + SURF] = np.asarray(small_n).astype(np.float32) / 255.0
    Image.fromarray(np.clip(col * 127.5 + 0.5, 0, 255).astype(np.uint8), "RGB").save(
        os.path.join(out, "surfaces.png"), optimize=True)
    Image.fromarray(np.clip(nor * 255.0 + 0.5, 0, 255).astype(np.uint8), "RGB").save(
        os.path.join(out, "surfaces_nor.png"), optimize=True)


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit("woodland_textures: <repo root> <cache folder>")
    root, cache = sys.argv[1], sys.argv[2]
    out = os.path.join(root, OUT)
    os.makedirs(out, exist_ok=True)
    random.seed(SEED)
    barks(cache, out)
    sheet(cache, out)
    surfaces(cache, out)
    for f in sorted(os.listdir(out)):
        if f.endswith(".png"):
            print("%s: %d KB" % (f, os.path.getsize(os.path.join(out, f)) // 1024))


if __name__ == "__main__":
    main()
