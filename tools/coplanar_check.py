#!/usr/bin/env python3
"""Finds faces that lie in one plane over one another in a field's drawn meshes: the cause of z-fighting (two surfaces
flickering through each other as the eye moves). Reads what tools/coplanar_dump.gd wrote.

    godot --headless --path . -s res://tools/coplanar_dump.gd -- <folder> <map>
    python3 tools/coplanar_check.py <folder>/<map> [--tol 0.00004] [--min-area 0.0004] [--json out.json]

Two triangles fight when they face the same way (or either is drawn double-sided), their planes are within `tol` m and
they overlap by at least `min-area` m2. Pairs of one source and one colour are listed apart: they look alike, so they
cost a draw but never show. So are two see-through faces (they blend twice, a steady patch, never a flicker) and
faces looking straight down at the field's lowest floor, which no eye gets under. A source pair is listed once for
each axis its fighting faces mostly face along. `tol` is under the least lift tools/coplanar_models.py gives (0.05 mm).
What is listed is not always seen (a fitting's back against its wall): tools/eye_pictures.gd `raw` shows what is.
Dev only: tools/ never ships.
"""
import argparse
import json
import re
import sys
from collections import defaultdict

import numpy as np

FLOATS = 14
## The lowest floor is the lowest level plane with this much (m2) looking up; faces looking down from within
## UNDER_FLOOR m over it are never seen.
FLOOR_AREA = 100.0
UNDER_FLOOR = 0.05


def clip(subject, clipper):
    """Sutherland-Hodgman: the part of polygon `subject` inside convex polygon `clipper` (both counter-clockwise)."""
    out = subject
    n = len(clipper)
    for i in range(n):
        ax, ay = clipper[i]
        bx, by = clipper[(i + 1) % n]
        inp = out
        out = []
        if not inp:
            break
        sx, sy = inp[-1]
        s_in = (bx - ax) * (sy - ay) - (by - ay) * (sx - ax) >= 0.0
        for ex, ey in inp:
            e_in = (bx - ax) * (ey - ay) - (by - ay) * (ex - ax) >= 0.0
            if e_in != s_in:
                d1x, d1y = ex - sx, ey - sy
                d2x, d2y = bx - ax, by - ay
                den = d1x * d2y - d1y * d2x
                if abs(den) > 1e-18:
                    t = ((ax - sx) * d2y - (ay - sy) * d2x) / den
                    out.append((sx + t * d1x, sy + t * d1y))
            if e_in:
                out.append((ex, ey))
            sx, sy, s_in = ex, ey, e_in
    return out


def area(poly):
    a = 0.0
    for i in range(len(poly)):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % len(poly)]
        a += x0 * y1 - x1 * y0
    return a * 0.5


def ccw(tri):
    return tri if area(tri) >= 0.0 else [tri[0], tri[2], tri[1]]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("base")
    ap.add_argument("--tol", type=float, default=0.00004)
    ap.add_argument("--min-area", type=float, default=0.0004)
    ap.add_argument("--json")
    ap.add_argument("--top", type=int, default=60)
    ap.add_argument("--limit", type=int, default=400, help="overlaps measured per source pair; the rest are counted")
    ap.add_argument("--low", type=float, help="the lowest floor's height (m); found from the triangles without it")
    ap.add_argument("--skip", default=r"/(Puffs|Grenades|BBs|LaserBeams|Shells|Tracers)(/|$)",
                    help="node paths left out: the effect pools, which park their pieces on one spot until used")
    args = ap.parse_args()
    meta = json.load(open(args.base + ".json"))
    sources = meta["sources"]
    raw = np.fromfile(args.base + ".bin", dtype=np.float32).reshape(-1, FLOATS)
    p = raw[:, :9].astype(np.float64).reshape(-1, 3, 3)
    src = raw[:, 9].astype(np.int64)
    col = raw[:, 10:14]
    e1 = p[:, 1] - p[:, 0]
    e2 = p[:, 2] - p[:, 0]
    n = np.cross(e1, e2)
    length = np.linalg.norm(n, axis=1)
    keep = length > 2e-6  # over 1 mm2
    skip = re.compile(args.skip)
    keep &= ~np.array([bool(skip.search(s["node"])) for s in sources])[src]
    p, src, col, n, length = p[keep], src[keep], col[keep], n[keep], length[keep]
    n = n / length[:, None]
    cull_off = np.array([s["cull"] == "off" for s in sources])[src]
    blended = np.array([s.get("blend", "opaque") != "opaque" for s in sources])[src]
    # The lowest floor: the lowest level plane with FLOOR_AREA m2 or more of faces looking up. A face looking down
    # from within UNDER_FLOOR m of it has no room under it for an eye.
    level_up = n[:, 1] > 0.999
    low = args.low
    if low is None and level_up.any():
        heights = np.round(p[level_up, 0, 1], 2)
        areas = length[level_up] * 0.5
        found = [h for h in np.unique(heights) if areas[heights == h].sum() >= FLOOR_AREA]
        low = float(min(found)) if found else None
    under = (n[:, 1] < -0.999) & (p[:, 0, 1] <= low + UNDER_FLOOR) if low is not None else np.zeros(len(n), dtype=bool)
    # one hemisphere, so a face and its back share a bucket; `sign` remembers which way it faced
    dom = np.argmax(np.abs(n), axis=1)
    sign = np.sign(n[np.arange(len(n)), dom])
    nh = n * sign[:, None]
    d = np.einsum("ij,ij->i", nh, p[:, 0])
    qn = np.round(nh * 2000.0).astype(np.int64)  # about 0.03 degrees
    groups = defaultdict(lambda: {"area": 0.0, "pairs": 0, "largest": 0.0, "at": None, "gap": 0.0, "normal": None,
                                  "untested": 0})
    alike = defaultdict(lambda: {"area": 0.0, "pairs": 0, "largest": 0.0, "at": None, "untested": 0})
    unseen = defaultdict(lambda: {"area": 0.0, "pairs": 0, "largest": 0.0, "at": None, "untested": 0})
    qd0 = np.floor(d / args.tol).astype(np.int64)
    for shift in (0.0, 0.5):
        qd = np.floor(d / args.tol + shift).astype(np.int64)
        key = np.stack([qn[:, 0], qn[:, 1], qn[:, 2], qd], axis=1)
        order = np.lexsort(key.T[::-1])
        ks = key[order]
        change = np.any(ks[1:] != ks[:-1], axis=1)
        starts = np.concatenate([[0], np.nonzero(change)[0] + 1, [len(ks)]])
        for b in range(len(starts) - 1):
            lo, hi = starts[b], starts[b + 1]
            if hi - lo < 2:
                continue
            idx = order[lo:hi]
            axis = dom[idx[0]]
            u, v = [(1, 2), (2, 0), (0, 1)][axis]
            pts = p[idx][:, :, [u, v]]
            mn = pts.min(axis=1)
            mx = pts.max(axis=1)
            o = np.argsort(mn[:, 0], kind="stable")
            idx, pts, mn, mx = idx[o], pts[o], mn[o], mx[o]
            eps = 0.002
            m = len(idx)
            ends = np.searchsorted(mn[:, 0], mx[:, 0] - eps, side="left")
            sgn = sign[idx]
            off = cull_off[idx]
            sr = src[idx]
            q0 = qd0[idx]
            cl = col[idx]
            bl = blended[idx]
            un = under[idx]
            for i in range(m):
                j1 = ends[i]
                if j1 <= i + 1:
                    continue
                js = np.arange(i + 1, j1)
                ok = (mn[js, 1] < mx[i, 1] - eps) & (mx[js, 1] > mn[i, 1] + eps)
                ok &= (sgn[js] == sgn[i]) | off[js] | off[i]
                if shift:
                    ok &= q0[js] != q0[i]  # the first pass had the pairs of one bin
                if not ok.any():
                    continue
                ti = None
                for j in js[ok]:
                    sa, sb = int(sr[i]), int(sr[j])
                    same_colour = float(np.abs(cl[i] - cl[j]).max()) < 0.02
                    if sa == sb and same_colour:
                        g = alike[sa]
                    elif (bl[i] and bl[j]) or (un[i] and un[j]):
                        g = unseen[(min(sa, sb), max(sa, sb))]
                    else:
                        g = groups[(min(sa, sb), max(sa, sb), sa == sb, int(axis))]
                    if g["pairs"] >= args.limit:
                        g["untested"] += 1
                        continue
                    if ti is None:
                        ti = ccw([tuple(q) for q in pts[i]])
                    tj = ccw([tuple(q) for q in pts[j]])
                    over = clip(ti, tj)
                    if len(over) < 3:
                        continue
                    ar = abs(area(over))
                    if ar < args.min_area:
                        continue
                    a, bb = int(idx[i]), int(idx[j])
                    g["area"] += ar
                    g["pairs"] += 1
                    if "gap" in g:
                        g["gap"] = max(g["gap"], abs(d[a] - d[bb]))
                    if ar > g["largest"]:
                        if "gap" in g:
                            g["normal"] = [round(float(x), 3) for x in n[a]]
                        cx = sum(q[0] for q in over) / len(over)
                        cy = sum(q[1] for q in over) / len(over)
                        centre = [0.0, 0.0, 0.0]
                        centre[u], centre[v] = cx, cy
                        nn = nh[a]
                        centre[axis] = (d[a] - nn[u] * cx - nn[v] * cy) / nn[axis]
                        g["largest"] = ar
                        g["at"] = [round(float(x), 3) for x in centre]

    def label(i):
        s = sources[i]
        node = s["node"].split("/PlaySession/")[-1] if "/PlaySession/" in s["node"] else s["node"]
        mesh = s["mesh"].split("/")[-1] if s["mesh"] else s["name"]
        return "%s [%s #%d] %s" % (node[-70:], mesh[-40:], s["surface"], s["material"][-50:])

    rows = sorted(groups.items(), key=lambda kv: -kv[1]["area"])
    print("%d triangles, %d sources; %d fighting pairs in %d source pairs (%.2f m2); %d alike pairs in %d sources "
          "(%.2f m2); %.2f m2 blended twice or under the floor" % (
              len(p), len(sources), sum(g["pairs"] for _, g in rows), len(rows), sum(g["area"] for _, g in rows),
              sum(g["pairs"] for g in alike.values()), len(alike), sum(g["area"] for g in alike.values()),
              sum(g["area"] for g in unseen.values())))
    for (sa, sb, same, _axis), g in rows[:args.top]:
        if g["pairs"] == 0:
            continue
        print("%8.3f m2 %5d pairs (+%d untested), largest %.4f m2 at %s n=%s gap %.2f mm%s\n      A %s\n      B %s" % (
            g["area"], g["pairs"], g["untested"], g["largest"], g["at"], g["normal"], g["gap"] * 1000.0,
            " (one source, two colours)" if same else "", label(sa), label(sb)))
    for sa, g in sorted(alike.items(), key=lambda kv: -kv[1]["area"])[:15]:
        if g["pairs"]:
            print("alike %8.3f m2 %5d pairs (+%d untested) at %s  %s" % (g["area"], g["pairs"], g["untested"], g["at"],
                                                                        label(sa)))
    if args.json:
        json.dump({"fighting": [{"a": label(sa), "b": label(sb), **g} for (sa, sb, _same, _axis), g in rows],
                   "alike": [{"a": label(sa), **g} for sa, g in alike.items()],
                   "unseen": [{"a": label(sa), "b": label(sb), **g} for (sa, sb), g in unseen.items()]},
                  open(args.json, "w"), indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
