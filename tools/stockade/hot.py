"""Where a tall piece would cut the most over-long sight lines (SK1): the spots most of them cross near their middles,
a metre grid, spaced out. A help while placing cover; check.py is the look after.

    python3 tools/stockade/hot.py [how many]"""
from __future__ import annotations

import sys

import numpy as np

import check as C
import layout as L


def main() -> None:
    boxes = C.all_boxes()
    p, dx, dz, free = C.rays(boxes)
    k, a = np.nonzero(free > C.LIMIT)
    ln = free[k, a]
    print("%d rays over %.0f m, longest %.1f m" % (len(ln), C.LIMIT, ln.max() if len(ln) else 0.0))
    nx, nz = int(2 * L.W), int(2 * L.H)
    heat = np.zeros((nx, nz))
    for d in np.arange(1.0, 110.0, 0.5):
        # A cut at d leaves d and ln - d: both within the limit where it can be, else the middle third.
        ok = (d < ln) & (((d <= C.LIMIT) & (ln - d <= C.LIMIT)) | ((ln > 2 * C.LIMIT) & (d > ln / 3) & (d < 2 * ln / 3)))
        x = p[k[ok], 0] + dx[a[ok]] * d
        z = p[k[ok], 1] + dz[a[ok]] * d
        i = np.clip((x + L.W).astype(int), 0, nx - 1)
        j = np.clip((z + L.H).astype(int), 0, nz - 1)
        np.add.at(heat, (i, j), ln[ok] - C.LIMIT)
    want = int(sys.argv[1]) if len(sys.argv) > 1 else 12
    out = []
    while len(out) < want and heat.max() > 0:
        i, j = np.unravel_index(np.argmax(heat), heat.shape)
        out.append((i - L.W + 0.5, j - L.H + 0.5, heat[i, j]))
        heat[max(i - 5, 0):i + 6, max(j - 5, 0):j + 6] = 0
    for (x, z, h) in out:
        print("HOT (%.1f, %.1f) %.0f" % (x, z, h))


if __name__ == "__main__":
    main()
