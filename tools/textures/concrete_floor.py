#!/usr/bin/env python3
"""Depot's concrete floor (Dev 3, the hall shell): assets/textures/site/hall_concrete_col_2k.jpg and
hall_concrete_nor_gl_2k.jpg, a 2K tiling colour and OpenGL normal map synthesised from noise, so the slab reads like
the owner's floor photos (references/maps/william-2026-11-09/ground): a power-floated slab's soft cloudy tone (refs 1,
2), the fine speckle of its sand and aggregate (refs 1, 3), a few pale hairline cracks running across it (refs 2, 3),
small pits, and faint darker stains where the trowel left it (ref 2's spots). The site shader takes the colour map's
brightness round the finish's own paint (SiteLook.slab_luma) and the normal map's relief, so the colours stay the
look's. Every feature wraps at the edges, so it tiles without a seam. Seeded: the same files every run.

Usage: python3 -I tools/textures/concrete_floor.py <repo root>   (numpy and Pillow). Dev tool: tools/ never ships.
"""
import os
import sys

import numpy as np
from PIL import Image

SIZE = 2048
SEED = 4127
OUT = os.path.join(sys.argv[-1] if len(sys.argv) > 1 else os.getcwd(), "assets", "textures", "site")
# Each feature's share of the brightness (0 to 1 is the whole range).
CLOUD = 0.10       # the float finish's broad tonal cloud
MOTTLE = 0.05      # smaller patches within it
SPECKLE = 0.05     # sand
FLECK = 0.09       # the fine aggregate's light and dark flecks
AGGREGATE = 0.13   # the exposed aggregate: pebbles 1 to 3 cm (5 to 15 px on the 4 m tile) all over (refs 1, 3)
STAIN = 0.06       # the faint darker spots
CRACK = 0.16       # how much darker a crack's line is
PIT = 0.18
CRACKS = 5
PITS = 900
# The normal map's relief: the height's slope this many times over.
RELIEF = 2.2


def noise(rng: np.random.Generator, scale: float, power: float = 2.0) -> np.ndarray:
    """Tiling noise: white noise filtered in frequency (1 / f^power, cut below `scale` px), scaled to -1..1."""
    f = np.fft.fftfreq(SIZE)
    fx, fy = np.meshgrid(f, f)
    r = np.sqrt(fx * fx + fy * fy)
    r[0, 0] = 1.0
    amp = 1.0 / np.power(r, power) * np.exp(-(r * scale) ** 2)
    amp[0, 0] = 0.0
    spec = np.fft.fft2(rng.standard_normal((SIZE, SIZE))) * amp
    n = np.real(np.fft.ifft2(spec))
    n -= n.mean()
    return n / np.abs(n).max()


def aggregate(rng: np.random.Generator) -> np.ndarray:
    """The exposed aggregate: two layers of pebbles (band-passed noise thresholded into blobs, about 10 and 5 px
    across), each pebble light or dark, so the surface is covered in them as in the photos; -1..1."""
    out = np.zeros((SIZE, SIZE))
    for scale, share in ((9.0, 0.7), (4.5, 0.6)):
        blob = noise(rng, scale, 0.0)
        blob /= blob.std()
        tone = noise(rng, scale * 0.6, 0.0)
        stone = np.clip((blob - 0.9) * 2.5, 0.0, 1.0)
        out += share * stone * np.sign(tone)
    return np.clip(out, -1.0, 1.0)


def cracks(rng: np.random.Generator) -> np.ndarray:
    """Hairline cracks: wandering walks that wrap round the edges, a pixel or two wide, fading at their ends."""
    out = np.zeros((SIZE, SIZE), np.float32)
    for _ in range(CRACKS):
        x, y = rng.uniform(0, SIZE, 2)
        heading = rng.uniform(0, 2 * np.pi)
        length = int(rng.uniform(0.35, 0.8) * SIZE)
        for i in range(length):
            heading += rng.normal(0.0, 0.035)
            x = (x + np.cos(heading)) % SIZE
            y = (y + np.sin(heading)) % SIZE
            fade = min(1.0, i / 60.0, (length - i) / 60.0)
            w = 1 if rng.random() < 0.7 else 2
            out[int(y) % SIZE:int(y) % SIZE + w, int(x) % SIZE] = np.maximum(
                out[int(y) % SIZE:int(y) % SIZE + w, int(x) % SIZE], fade)
            if rng.random() < 0.004:
                # a short branch
                bx, by, bh = x, y, heading + rng.choice((-1.0, 1.0)) * rng.uniform(0.5, 1.1)
                for k in range(int(rng.uniform(40, 160))):
                    bh += rng.normal(0.0, 0.1)
                    bx, by = (bx + np.cos(bh)) % SIZE, (by + np.sin(bh)) % SIZE
                    out[int(by), int(bx)] = max(out[int(by), int(bx)], fade * 0.7)
    # soften a touch so the line isn't a jagged pixel trail
    soft = (out + 0.5 * (np.roll(out, 1, 0) + np.roll(out, -1, 0) + np.roll(out, 1, 1) + np.roll(out, -1, 1)) * 0.25)
    return np.clip(soft, 0.0, 1.0)


def pits(rng: np.random.Generator) -> np.ndarray:
    out = np.zeros((SIZE, SIZE), np.float32)
    ys, xs = rng.integers(0, SIZE, PITS), rng.integers(0, SIZE, PITS)
    for x, y in zip(xs, ys):
        r = rng.integers(1, 4)
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r:
                    out[(y + dy) % SIZE, (x + dx) % SIZE] = 1.0
    return out


def main() -> None:
    rng = np.random.default_rng(SEED)
    cloud = noise(rng, 6.0, 2.2)
    mottle = noise(rng, 2.0, 1.4)
    speck = rng.standard_normal((SIZE, SIZE))
    speck = (speck + np.roll(speck, 1, 0) + np.roll(speck, 1, 1)) / 3.0
    speck /= np.abs(speck).max()
    stain = np.clip(noise(rng, 3.0, 1.6) * 2.5 - 1.4, 0.0, 1.0)
    grain = noise(rng, 0.9, 0.3)
    fleck = np.clip((grain - 0.22) * 6.0, 0.0, 1.0) - np.clip((-grain - 0.22) * 6.0, 0.0, 1.0)
    agg = aggregate(rng)
    crack = cracks(rng)
    pit = pits(rng)
    tone = (0.5 + CLOUD * cloud + MOTTLE * mottle + SPECKLE * speck + FLECK * fleck + AGGREGATE * agg - STAIN * stain - CRACK * crack
            - PIT * pit * 0.6)
    tone = np.clip(tone, 0.0, 1.0)
    # a hint of warmth in the stains, the rest a neutral grey (the shader reads brightness only; the warmth is for
    # anyone opening the file)
    rgb = np.stack([tone + 0.012 * stain, tone, tone - 0.01 * stain], -1)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).save(
        os.path.join(OUT, "hall_concrete_col_2k.jpg"), quality=88)
    # the height: speckle grain up, cracks and pits down
    height = 0.25 * speck + 0.3 * fleck + 0.5 * np.abs(agg) + 0.4 * mottle - 1.4 * crack - 1.0 * pit
    gx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5 * RELIEF
    gy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5 * RELIEF
    # OpenGL normals: +x right, +y up the image (image rows run down)
    n = np.stack([-gx, gy, np.ones_like(gx)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8)).save(
        os.path.join(OUT, "hall_concrete_nor_gl_2k.jpg"), quality=92)
    lin = np.where(tone <= 0.04045, tone / 12.92, ((tone + 0.055) / 1.055) ** 2.4)
    print("hall_concrete: mean linear luma %.3f (SiteLook.slab_luma)" % lin.mean())


if __name__ == "__main__":
    main()
