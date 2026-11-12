"""The replicas' surface grain (MQ1, 2026-11-12): one small tiling texture every replica, part and accessory shares,
read by game/play/replica_surface.gdshaderinc on the model's own space (three flat projections, no texture
coordinates), so metal, polymer and wood each have their own fine structure under any paint.

    python3 -I tools/textures/replica_grain.py <repo root>

writes assets/textures/replica/replica_grain.png (512 px, the same file every run; then import with
`godot --headless --path . --import`). Its channels:

- R, G  the fine grain's slope (a normal map's x and y, 0.5 flat): a moulded pebble a few pixels across. Read as it
        is for polymer and blasted aluminium; stretched along the bore it becomes a steel part's brushed finish;
- B     a slow cloud (0.5 mid): the uneven sheen of a handled surface (oil, a palm's polish);
- A     wood figure (0.5 mid, low is the dark late wood): long streaks along the texture's u, with a slow drift and
        the odd wide band, to be stretched along the stock, under thin dark growth rings unevenly spaced, swept
        into the long arches of a plain-sawn board.

Everything tiles in both directions (the noise is filtered in the frequency domain).
"""

import os
import sys

import numpy as np
from PIL import Image

SIZE = 512
SEED = 20261112
OUT = "assets/textures/replica/replica_grain.png"
# The pebble's size (px) and how steep its slopes are drawn (a slope of 1 fills the channel).
PEBBLE_PX = 5.0
PEBBLE_SLOPE = 0.9
# The cloud's size (px).
CLOUD_PX = 90.0
# Wood: streaks this long and this thick (px), the drift that bends them, and the share the wide bands add.
STREAK_PX = (220.0, 2.6)
BAND_PX = (512.0, 22.0)
BAND_SHARE = 0.45
PORE_PX = (26.0, 1.1)
PORE_SHARE = 0.25
# The growth rings, as a plain-sawn board shows them: this many dark lines up the tile, their spacing uneven (each
# (waves up the tile, share of a turn) squeezes and opens them), swept into long arches by a slow drift of ARCH ring
# widths and wandered by a quicker one of RING_DRIFT, each line thin (the power its wave is raised to, between the
# two given, slowly varying), and the share of the figure they are.
RINGS = 7
RING_SPACING = ((2.0, 0.03, 1.3), (3.0, 0.015, 0.4))
ARCH = 1.5
ARCH_PX = (512.0, 256.0)
RING_DRIFT = 0.35
DRIFT_PX = (150.0, 34.0)
RING_THIN = (3.0, 7.0)
THIN_PX = (360.0, 120.0)
RING_SHARE = 0.5


def _band(rng: np.random.Generator, along: float, across: float, low_cut: float = 0.0) -> np.ndarray:
    """Tiling noise whose features are about `along` px in u and `across` px in v: white noise under a Gaussian in the
    frequency domain (less a wider one, `low_cut` times as large, to take the slow drift out), scaled to unit spread."""
    white = rng.standard_normal((SIZE, SIZE))
    fy = np.fft.fftfreq(SIZE)[:, None]
    fx = np.fft.fftfreq(SIZE)[None, :]
    keep = np.exp(-0.5 * ((fx * along * 2.0) ** 2 + (fy * across * 2.0) ** 2))
    if low_cut > 0.0:
        keep -= np.exp(-0.5 * ((fx * along * 2.0 * low_cut) ** 2 + (fy * across * 2.0 * low_cut) ** 2))
    out = np.fft.ifft2(np.fft.fft2(white) * keep).real
    return out / out.std()


def _unit(a: np.ndarray, spread: float = 3.0) -> np.ndarray:
    """`a` (unit spread) as 0..1 with 0.5 its mean, `spread` deviations to either end."""
    return np.clip(0.5 + a / (2.0 * spread), 0.0, 1.0)


def build() -> np.ndarray:
    rng = np.random.default_rng(SEED)
    height = _band(rng, PEBBLE_PX, PEBBLE_PX, 3.0)
    # The slope across a pixel, on the wrapped image.
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    nx = np.clip(0.5 - dx * PEBBLE_SLOPE * 0.5, 0.0, 1.0)
    ny = np.clip(0.5 - dy * PEBBLE_SLOPE * 0.5, 0.0, 1.0)
    cloud = _unit(_band(rng, CLOUD_PX, CLOUD_PX, 2.5), 2.5)
    streak = _band(rng, *STREAK_PX, 4.0)
    band = _band(rng, *BAND_PX)
    pore = _band(rng, *PORE_PX, 3.0)
    fibre = _unit(streak * (1.0 - BAND_SHARE - PORE_SHARE) + band * BAND_SHARE + pore * PORE_SHARE, 2.2)
    drift = _band(rng, *DRIFT_PX)
    arch = _band(rng, *ARCH_PX)
    thin = _unit(_band(rng, *THIN_PX), 2.0)
    v = np.arange(SIZE)[:, None] / SIZE
    # Uneven spacing: the way up the tile bent by whole waves, so it still tiles and never turns back.
    up = v + sum(share * np.sin(2.0 * np.pi * (waves * v) + phase) for waves, share, phase in RING_SPACING)
    wave = 0.5 + 0.5 * np.sin(2.0 * np.pi * (up * RINGS + arch * ARCH + drift * RING_DRIFT))
    rings = 1.0 - wave ** (RING_THIN[0] + (RING_THIN[1] - RING_THIN[0]) * thin)
    wood = np.clip(fibre * (1.0 - RING_SHARE) + rings * RING_SHARE + 0.5 * RING_SHARE * (1.0 - 0.72), 0.0, 1.0)
    return np.stack([nx, ny, cloud, wood], axis=-1)


def main() -> None:
    root = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
    path = os.path.join(root, OUT)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pixels = (build() * 255.0 + 0.5).astype(np.uint8)
    Image.fromarray(pixels, "RGBA").save(path, optimize=True)
    print("wrote %s (%d px), means %s" % (OUT, SIZE, np.round(pixels.reshape(-1, 4).mean(axis=0) / 255.0, 3)))


if __name__ == "__main__":
    main()
