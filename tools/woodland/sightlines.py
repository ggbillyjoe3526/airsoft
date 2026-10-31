"""Finds the longest clear standing lines across the built Woodland (data/maps/woodland.json), any spot to any spot, as
the game's field check measures them (tests/support/field_measure.gd: standing eye to standing eye over walkable
ground). Needs numpy. Run after build_map.py:

    python3 tools/woodland/sightlines.py [count]

Prints the longest lines, each with its ends, so a piece can be placed to break one. The field check is the judge;
this is the quick look (blocks and the ground rasterised to 0.5 m, a line sampled every 0.25 m, spots every 2 m).
"""
from __future__ import annotations

import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
MAP = os.path.join(HERE, "..", "..", "data", "maps", "woodland.json")
EYE = 1.62 + 0.02  # BodyConfig.stand_eye_height + rest_gap
SPACING = 2.0
STEP = 0.25
SHORTEST = 60.0  # lines shorter than this aren't reported


def main() -> None:
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 12
    d = json.load(open(MAP))
    t = d["terrain"]
    cell, cols, rows, x0, z0 = t["cell"], t["cols"], t["rows"], t["minX"], t["minZ"]
    v = np.array(t["heights"]).reshape(rows + 1, cols + 1).T  # [i, j]
    ground = (v[:-1, :-1] + v[1:, :-1] + v[:-1, 1:] + v[1:, 1:]) / 4.0  # cell centres
    lo = np.full((2, cols, rows), np.inf)
    hi = np.full((2, cols, rows), -np.inf)
    walk = np.ones((cols, rows), bool)
    for b in d["blocks"]:
        c, s = b["center"], b["size"]
        i1, i2 = int((c["x"] - s["x"] / 2 - x0) / cell), int(math.ceil((c["x"] + s["x"] / 2 - x0) / cell))
        j1, j2 = int((c["z"] - s["z"] / 2 - z0) / cell), int(math.ceil((c["z"] + s["z"] / 2 - z0) / cell))
        i1, j1, i2, j2 = max(i1, 0), max(j1, 0), min(i2, cols), min(j2, rows)
        if i1 >= i2 or j1 >= j2:
            continue
        bottom, top = c["y"] - s["y"] / 2, c["y"] + s["y"] / 2
        g = ground[i1:i2, j1:j2]
        band = 1 if b["kind"] in ("floor", "ramp") or bottom > float(g.max()) + 0.5 else 0
        lo[band, i1:i2, j1:j2] = np.minimum(lo[band, i1:i2, j1:j2], bottom)
        hi[band, i1:i2, j1:j2] = np.maximum(hi[band, i1:i2, j1:j2], top)
        if band == 0 and top > float(g.min()) + 0.3:
            walk[max(i1 - 1, 0):i2 + 1, max(j1 - 1, 0):j2 + 1] = False
    xs = np.arange(x0 + SPACING / 2, x0 + cols * cell, SPACING)
    zs = np.arange(z0 + SPACING / 2, z0 + rows * cell, SPACING)
    pts = []
    for x in xs:
        for z in zs:
            i, j = int((x - x0) / cell), int((z - z0) / cell)
            if walk[i, j]:
                pts.append((x, z, ground[i, j] + EYE))
    p = np.array(pts)

    def clear(a: np.ndarray, bs: np.ndarray) -> np.ndarray:
        n = int(np.max(np.hypot(bs[:, 0] - a[0], bs[:, 1] - a[1])) / STEP) + 2
        f = np.linspace(0.0, 1.0, n)[None, :]
        x = a[0] + (bs[:, 0:1] - a[0]) * f
        z = a[1] + (bs[:, 1:2] - a[1]) * f
        y = a[2] + (bs[:, 2:3] - a[2]) * f
        i = ((x - x0) / cell).astype(int).clip(0, cols - 1)
        j = ((z - z0) / cell).astype(int).clip(0, rows - 1)
        blocked = y < ground[i, j] - 0.05
        for band in range(2):
            blocked |= (y >= lo[band, i, j]) & (y <= hi[band, i, j])
        return ~blocked.any(axis=1)

    found = []
    for k in range(len(p)):
        a = p[k]
        dist = np.hypot(p[:, 0] - a[0], p[:, 1] - a[1])
        far = np.where(dist > SHORTEST)[0]
        far = far[np.argsort(-dist[far])]
        for s in range(0, len(far), 256):
            c = far[s:s + 256]
            ok = clear(a, p[c])
            if ok.any():
                b = p[c[np.argmax(ok)]]
                found.append((float(math.hypot(b[0] - a[0], b[1] - a[1])), (a[0], a[1]), (b[0], b[1])))
                break
    found.sort(key=lambda q: -q[0])
    shown = []
    for q in found:
        if all(min(math.dist(q[1], o[1]) + math.dist(q[2], o[2]), math.dist(q[1], o[2]) + math.dist(q[2], o[1])) > 20
               for o in shown):
            shown.append(q)
        if len(shown) >= count:
            break
    print(f"{len(p)} spots; longest lines:")
    for dd, a, b in shown:
        print(f"  {dd:6.1f} m  ({a[0]:.0f}, {a[1]:.0f}) to ({b[0]:.0f}, {b[1]:.0f})")


if __name__ == "__main__":
    main()
