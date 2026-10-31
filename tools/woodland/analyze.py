"""Run times (fastest player from a team's spawn), sight lines, openness and spawn safety, printed."""
from __future__ import annotations

import heapq
import json
import math

import numpy as np

import layout as L
import world as Wd
from layout import GX, GZ, NX, NZ, RES, W, H, RUN, CROUCH, EYE

h = Wd.h
N = NX * NZ
HT = np.stack([h, np.where(np.isnan(Wd.OVER_FLOOR), -99, Wd.OVER_FLOOR)])
OK = np.stack([Wd.walk0, Wd.walk1])
CR = np.stack([Wd.CROUCH0, Wd.OVER_CROUCH])
STEPS = [(1, 0, 1.0), (-1, 0, 1.0), (0, 1, 1.0), (0, -1, 1.0), (1, 1, 1.4142), (1, -1, 1.4142), (-1, 1, 1.4142), (-1, -1, 1.4142)]
lf = Wd.to_cell(*Wd.LADDER_FOOT)
lt = Wd.to_cell(*Wd.LADDER_TOP)
LADDER_S = 2.2


def nearest_ok(x, z, layer=0):
    i, j = Wd.to_cell(x, z)
    for r in range(0, 30):
        sub = OK[layer, max(i - r, 0):i + r + 1, max(j - r, 0):j + r + 1]
        if sub.any():
            a, b = np.argwhere(sub)[0]
            return max(i - r, 0) + a, max(j - r, 0) + b
    raise ValueError((x, z))


def dijkstra(srcs):
    """Seconds from the nearest of the sources, running (crouched where the roof is low)."""
    if isinstance(srcs[0], (int, float)):
        srcs = [srcs]
    dist = np.full((2, NX, NZ), np.inf)
    pq = []
    for (x, z) in srcs:
        i, j = nearest_ok(x, z)
        dist[0, i, j] = 0.0
        pq.append((0.0, 0, i, j))
    heapq.heapify(pq)
    while pq:
        d, l, i, j = heapq.heappop(pq)
        if d > dist[l, i, j]:
            continue
        ha = HT[l, i, j]
        for di, dj, c in STEPS:
            a, b = i + di, j + dj
            if not (0 <= a < NX and 0 <= b < NZ):
                continue
            step = c * RES
            for lb in (0, 1):
                if not OK[lb, a, b]:
                    continue
                dh = HT[lb, a, b] - ha
                if lb != l:
                    if abs(dh) > 0.4:
                        continue
                elif dh > step * 1.0 or dh < -3.0:
                    continue
                sp = CROUCH if (CR[l, i, j] or CR[lb, a, b]) else RUN
                nd = d + step / sp
                if nd < dist[lb, a, b]:
                    dist[lb, a, b] = nd
                    heapq.heappush(pq, (nd, lb, a, b))
        # same-cell layer change
        lb = 1 - l
        if OK[lb, i, j] and abs(HT[lb, i, j] - ha) <= 0.4 and d < dist[lb, i, j]:
            dist[lb, i, j] = d
            heapq.heappush(pq, (d, lb, i, j))
        # tower ladder
        if l == 0 and (i, j) == lf and d + LADDER_S < dist[1][lt]:
            dist[1][lt] = d + LADDER_S
            heapq.heappush(pq, (d + LADDER_S, 1, *lt))
        if l == 1 and (i, j) == lt and d + LADDER_S < dist[0][lf]:
            dist[0][lf] = d + LADDER_S
            heapq.heappush(pq, (d + LADDER_S, 0, *lf))
    return dist


def at(dist, x, z, r=3.0):
    """Best time to anywhere within r m of (x, z), either layer."""
    m = np.hypot(GX - x, GZ - z) <= r
    v = np.minimum(dist[0][m], dist[1][m])
    v = v[np.isfinite(v)]
    return float(v.min()) if len(v) else float("inf")


SLO, SHI = Wd.SIGHT_LO, Wd.SIGHT_HI
BANDS = [0, 1, 2, 3]  # 3 = ferns; drop it to measure what the ferns hide


def los_many(ax, az, ay, bx, bz, by, step=0.25, fat=0.25):
    """Vectorised: is each target (bx, bz, by) visible from (ax, az, ay)? bx.. are 1-D arrays. A target counts as seen
    only if a body-wide window is clear: the centre ray and two rays 0.25 m to each side (a gap between two trunks
    narrower than a body doesn't count)."""
    if fat:
        d = np.hypot(bx - ax, bz - az) + 1e-9
        nx, nz = -(bz - az) / d * fat, (bx - ax) / d * fat
        ok = _los(ax, az, ay, bx, bz, by, step, 0.0, 0.0)
        ok &= _los(ax, az, ay, bx, bz, by, step, nx, nz)
        ok &= _los(ax, az, ay, bx, bz, by, step, -nx, -nz)
        return ok
    return _los(ax, az, ay, bx, bz, by, step, 0.0, 0.0)


def _los(ax, az, ay, bx, bz, by, step, ox, oz):
    """One ray per target, shifted sideways by (ox, oz) along its whole length."""
    ax = (np.zeros_like(bx) + ax + ox)[:, None]
    az = (np.zeros_like(bx) + az + oz)[:, None]
    bx = (bx + ox)[:, None]
    bz = (bz + oz)[:, None]
    d = np.hypot(bx - ax, bz - az)[:, 0]
    n = int(d.max() / step) + 2
    t = np.linspace(0, 1, n)[None, :]
    xs = ax + (bx - ax) * t
    zs = az + (bz - az) * t
    ys = ay + (by[:, None] - ay) * t
    ii = ((xs + W) / RES).astype(int).clip(0, NX - 1)
    jj = ((zs + H) / RES).astype(int).clip(0, NZ - 1)
    blocked = (ys < h[ii, jj] - 0.05)
    for k in BANDS:
        blocked |= (ys >= SLO[k][ii, jj]) & (ys <= SHI[k][ii, jj])
    along = t * d[:, None]
    ok_zone = (along > 0.6) & (along < d[:, None] - 0.6)
    return ~(blocked & ok_zone).any(axis=1)


def grid_pts(step, mask_extra=None):
    xs = np.arange(-W + step / 2, W, step)
    zs = np.arange(-H + step / 2, H, step)
    P = []
    for x in xs:
        for z in zs:
            i, j = Wd.to_cell(x, z)
            if Wd.walk0[i, j] and (mask_extra is None or mask_extra[i, j]):
                P.append((x, z, h[i, j] + EYE))
    return np.array(P)


area_of = np.full((NX, NZ), -1)
for k, (name, lane, poly) in enumerate(L.AREAS):
    m = Wd.in_poly(GX, GZ, poly) & (area_of < 0)
    area_of[m] = k
lane_of = np.full((NX, NZ), "", dtype=object)
for k, (name, lane, poly) in enumerate(L.AREAS):
    lane_of[area_of == k] = lane


if __name__ == "__main__":
    import time
    T0 = time.time()
    rep = {}
    west = dijkstra(L.SPAWNS_W)
    east = dijkstra(L.SPAWNS_E)
    pts = {
        "Clearing (overtime flag)": L.OT_FLAG, "A site flag": L.FLAG_A, "B site flag": L.FLAG_B,
        "Ridge top": (-24.0, -41.0), "North bridge": L.NB, "Tower platform": L.TOWER, "Fern hollow": (32.0, -40.0),
        "Woodpile": (-36.0, 8.0), "Ford": L.FORD, "Hut row": (27.0, 3.0), "Truck bend": (-30.0, 46.0),
        "Culvert": L.CULVERT, "Log stacks": (29.0, 41.0), "Knoll top": (31.0, 19.0),
    }
    times = {}
    for name, (x, z) in pts.items():
        times[name] = {"west_s": round(at(west, x, z), 1), "east_s": round(at(east, x, z), 1)}
    rep["times"] = times
    fa, fb = dijkstra(L.FLAG_A), dijkstra(L.FLAG_B)
    rep["rotations"] = {
        "A flag to B flag (defenders, Back track)": round(at(fa, *L.FLAG_B), 1),
        "Ridge top to Clearing (Crawl box)": round(at(dijkstra((-20.0, -30.0)), -14.0, -6.0), 1),
        "Clearing to Truck bend (Tyre wall)": round(at(dijkstra(L.OT_FLAG), -30.0, 46.0), 1),
        "Ford to Log stacks (stream bed + Culvert)": round(at(dijkstra(L.FORD), 22.0, 52.0), 1),
        "Hut row to A flag (Hollow way)": round(at(dijkstra((27.0, 3.0)), *L.FLAG_A), 1),
        "Hut row to B flag (Badger run)": round(at(dijkstra((31.0, 8.0)), *L.FLAG_B), 1),
    }
    print(json.dumps(rep, indent=1))
    print("dijkstra done", round(time.time() - T0, 1))
