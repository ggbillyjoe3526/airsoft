"""Stockade's quick checks (SK1), before the game's own field checks: blocks standing inside each other, the longest
standing sight lines (a 2D look at eye height: the field is flat), each end's walks, and a plan picture.

    python3 tools/stockade/check.py [plan.png]

Needs numpy; the picture needs Pillow. The game's FieldChecks are the judge (tests/unit/test_field_rules.gd,
test_field_layout.gd); this is the fast look while placing cover."""
from __future__ import annotations

import heapq
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import layout as L  # noqa: E402

EYE = 1.64          # BodyConfig.stand_eye_height + rest_gap
RES = 0.125         # the sight raster (m)
LIMIT = 34.0        # FieldStandard.LONGEST_SIGHTLINE
SEAM = 0.025        # FieldStandard.SEAM_SLACK
BODY = 0.4          # a body's half width, for the walks
SPRINT = 6.0        # m/s, about


def all_boxes() -> list[dict]:
    out = list(L.boxes)
    for (x, z, rad, model, height) in L.TREES:
        out.append({"kind": "tree", "x1": x - rad, "z1": z - rad, "x2": x + rad, "z2": z + rad, "y1": -L.SINK,
                    "y2": height, "dress": model})
    for t in L.ROOF_TILES:
        out.append({"kind": "plywood", "x1": t["x1"], "z1": t["z1"], "x2": t["x2"], "z2": t["z2"], "y1": t["y"],
                    "y2": t["y"] + L.ROOF_T, "dress": "roof"})
    return out


def overlaps(boxes: list[dict]) -> list[str]:
    out = []
    for i, a in enumerate(boxes):
        for b in boxes[i + 1:]:
            if (min(a["x2"], b["x2"]) - max(a["x1"], b["x1"]) > SEAM and min(a["z2"], b["z2"]) - max(a["z1"], b["z1"]) > SEAM
                    and min(a["y2"], b["y2"]) - max(a["y1"], b["y1"]) > SEAM):
                out.append("%s %s at (%.1f, %.1f) stands in %s %s at (%.1f, %.1f)" % (
                    a["kind"], a.get("dress", ""), (a["x1"] + a["x2"]) / 2, (a["z1"] + a["z2"]) / 2,
                    b["kind"], b.get("dress", ""), (b["x1"] + b["x2"]) / 2, (b["z1"] + b["z2"]) / 2))
    return out


def raster(boxes: list[dict], res: float, test) -> np.ndarray:
    nx, nz = int(2 * L.W / res), int(2 * L.H / res)
    g = np.zeros((nx, nz), bool)
    for b in boxes:
        if not test(b):
            continue
        i1, i2 = int(math.floor((b["x1"] + L.W) / res + 1e-6)), int(math.ceil((b["x2"] + L.W) / res - 1e-6))
        j1, j2 = int(math.floor((b["z1"] + L.H) / res + 1e-6)), int(math.ceil((b["z2"] + L.H) / res - 1e-6))
        g[max(i1, 0):max(i2, 0), max(j1, 0):max(j2, 0)] = True
    return g


def rays(boxes: list[dict]) -> tuple:
    """From every place to stand on a 1.5 m grid, how far each ray (every half degree) runs clear at eye height:
    the points, the rays' directions and the clear lengths (points x rays)."""
    solid = raster(boxes, RES, lambda b: b["y1"] < EYE < b["y2"])
    body = raster(boxes, 0.5, lambda b: b["y1"] < 1.7 and b["y2"] > 0.35)
    nx, nz = solid.shape
    pts = [(x, z) for x in np.arange(-L.W + 0.75, L.W, 1.5) for z in np.arange(-L.H + 0.75, L.H, 1.5)
           if not body[int((x + L.W) / 0.5), int((z + L.H) / 0.5)]]
    p = np.array(pts)
    angles = np.radians(np.arange(0, 360, 0.5))
    dx, dz = np.cos(angles), np.sin(angles)
    free = np.zeros((len(p), len(angles)))
    alive = np.ones((len(p), len(angles)), bool)
    step = RES
    d = 0.0
    while alive.any() and d < 120.0:
        d += step
        x = p[:, 0:1] + dx[None, :] * d
        z = p[:, 1:2] + dz[None, :] * d
        i = ((x + L.W) / RES).astype(int)
        j = ((z + L.H) / RES).astype(int)
        inside = (i >= 0) & (i < nx) & (j >= 0) & (j < nz)
        hit = ~inside | solid[np.clip(i, 0, nx - 1), np.clip(j, 0, nz - 1)]
        alive &= ~hit
        free[alive] = d
    return p, dx, dz, free


def sight_lines(boxes: list[dict], count: int = 400) -> list[tuple]:
    p, dx, dz, free = rays(boxes)
    lines = []
    order = np.dstack(np.unravel_index(np.argsort(-free, axis=None), free.shape))[0]
    seen: list[tuple] = []
    for (k, a) in order:
        ln = free[k, a]
        if ln <= LIMIT or len(lines) >= count:
            break
        x1, z1 = p[k]
        x2, z2 = x1 + dx[a] * ln, z1 + dz[a] * ln
        key = (round((x1 + x2) / 8), round((z1 + z2) / 8), round(math.degrees(math.atan2(z2 - z1, x2 - x1)) % 180 / 12))
        if key in seen:
            continue
        seen.append(key)
        lines.append((ln, x1, z1, x2, z2))
    return lines, float(free.max())


def walk_grid(boxes: list[dict]) -> np.ndarray:
    res = 0.25
    g = np.zeros((int(2 * L.W / res), int(2 * L.H / res)), bool)
    for b in boxes:
        if b["y1"] >= 1.7 or b["y2"] <= 0.35:
            continue
        i1 = int(math.floor((b["x1"] - BODY + L.W) / res))
        i2 = int(math.ceil((b["x2"] + BODY + L.W) / res))
        j1 = int(math.floor((b["z1"] - BODY + L.H) / res))
        j2 = int(math.ceil((b["z2"] + BODY + L.H) / res))
        g[max(i1, 0):max(i2, 0), max(j1, 0):max(j2, 0)] = True
    return g


def walk_from(grid: np.ndarray, x: float, z: float) -> np.ndarray:
    res = 0.25
    nx, nz = grid.shape
    dist = np.full(grid.shape, np.inf)
    s = (int((x + L.W) / res), int((z + L.H) / res))
    dist[s] = 0.0
    heap = [(0.0, s)]
    steps = [(1, 0, 1.0), (-1, 0, 1.0), (0, 1, 1.0), (0, -1, 1.0), (1, 1, 1.4142), (1, -1, 1.4142), (-1, 1, 1.4142),
             (-1, -1, 1.4142)]
    while heap:
        d, (i, j) = heapq.heappop(heap)
        if d > dist[i, j]:
            continue
        for di, dj, c in steps:
            a, b = i + di, j + dj
            if 0 <= a < nx and 0 <= b < nz and not grid[a, b] and d + c * res < dist[a, b]:
                dist[a, b] = d + c * res
                heapq.heappush(heap, (d + c * res, (a, b)))
    return dist


def at(dist: np.ndarray, x: float, z: float) -> float:
    return float(dist[int((x + L.W) / 0.25), int((z + L.H) / 0.25)])


def picture(boxes: list[dict], lines: list[tuple], path: str) -> None:
    from PIL import Image, ImageDraw
    s = 12
    im = Image.new("RGB", (int(2 * L.W * s), int(2 * L.H * s)), (150, 170, 120))
    dr = ImageDraw.Draw(im)
    colours = {"plywood": (196, 160, 110), "fence": (110, 80, 50), "log": (140, 100, 60), "crate": (200, 180, 120),
               "tree": (40, 90, 40), "sandbags": (170, 160, 130), "thicket": (30, 70, 30)}

    def px(x: float, z: float) -> tuple[float, float]:
        return ((x + L.W) * s, (z + L.H) * s)
    for (x1, x2, z1, z2) in L.FLOORS:
        dr.rectangle([px(x1, z1), px(x2, z2)], fill=(215, 200, 170))
    for b in sorted(boxes, key=lambda b: b["y2"]):
        if b.get("dress") == "roof":
            continue
        c = colours.get(b["kind"], (120, 120, 120))
        if b["y2"] < EYE:
            c = tuple(int(v * 0.6 + 100) for v in c)
        if b["y1"] > EYE:
            dr.rectangle([px(b["x1"], b["z1"]), px(b["x2"], b["z2"])], outline=(90, 90, 200))
            continue
        dr.rectangle([px(b["x1"], b["z1"]), px(b["x2"], b["z2"])], fill=c, outline=(40, 30, 20))
    for d in L.DOORS:
        dr.rectangle([px(d["x"] - d["sx"] / 2, d["z"] - d["sz"] / 2), px(d["x"] + d["sx"] / 2, d["z"] + d["sz"] / 2)],
                     fill=(40, 160, 60) if not d["shut"] else (200, 60, 40))
    for (x, z, r) in L.BOMB_SITES:
        r = r or 4.5
        dr.ellipse([px(x - r, z - r), px(x + r, z + r)], outline=(230, 200, 30), width=3)
    for (x, z) in L.FLAGS + [L.OT_FLAG]:
        dr.ellipse([px(x - 0.4, z - 0.4), px(x + 0.4, z + 0.4)], fill=(255, 255, 255), outline=(0, 0, 0))
    for (x, z) in L.SPAWNS_W + L.SPAWNS_E:
        dr.ellipse([px(x - 0.3, z - 0.3), px(x + 0.3, z + 0.3)], fill=(60, 60, 220))
    for k, lane in enumerate(getattr(L, "LANE_PATHS", {}).values()):
        dr.line([px(x, z) for (x, z) in lane], fill=[(200, 40, 40), (40, 40, 200), (160, 40, 160)][k % 3], width=2)
    for (ln, x1, z1, x2, z2) in lines:
        dr.line([px(x1, z1), px(x2, z2)], fill=(255, 0, 0), width=1)
    for x in range(int(-L.W), int(L.W) + 1, 10):
        dr.text(px(x, -L.H + 0.2), str(x), fill=(0, 0, 0))
    for z in range(int(-L.H), int(L.H) + 1, 10):
        dr.text(px(-L.W + 0.2, z), str(z), fill=(0, 0, 0))
    im.save(path)


def main() -> None:
    boxes = all_boxes()
    bad = overlaps(boxes)
    for line in bad[:20]:
        print("OVERLAP", line)
    lines, longest = sight_lines(boxes)
    for (ln, x1, z1, x2, z2) in lines:
        print("LINE %.1f m: (%.1f, %.1f) to (%.1f, %.1f)" % (ln, x1, z1, x2, z2))
    grid = walk_grid(boxes)
    west = walk_from(grid, *L.SPAWNS_W[3])
    east = walk_from(grid, *L.SPAWNS_E[3])
    rows = [("the overtime flag", L.OT_FLAG), ("flag A", L.FLAG_A), ("flag B", L.FLAG_B),
            ("site A", L.BOMB_SITES[0][:2]), ("site B", L.BOMB_SITES[1][:2])]
    for name, (x, z) in rows:
        a, d = at(west, x, z), at(east, x, z)
        print("WALK %-18s attackers %5.1f m (%4.1f s)  defenders %5.1f m (%4.1f s)  x%.2f" % (
            name, a, a / SPRINT, d, d / SPRINT, a / max(d, 0.1)))
    cut = [(x, z) for (x, z) in L.SPAWNS_W + L.SPAWNS_E + [L.DEAD_W, L.DEAD_E] + L.FLAGS + [L.OT_FLAG]
           if not math.isfinite(at(west, x, z))]
    for (x, z) in cut:
        print("UNREACHED (%.1f, %.1f)" % (x, z))
    print("TOTAL %d overlaps, %d lines over %.0f m (longest %.1f m), %d spots unreached" % (
        len(bad), len(lines), LIMIT, longest, len(cut)))
    if len(sys.argv) > 1:
        picture(boxes, lines, sys.argv[1])


if __name__ == "__main__":
    main()
