"""Turns layout.py into grids: ground height, what blocks walking, what blocks sight (a height band per cell),
the second walking surfaces (bridge decks, tower platform, tunnel floors) and the final tree list."""
from __future__ import annotations

import math

import numpy as np

import layout as L
from layout import GX, GZ, NX, NZ, RES, W, H

h = L.h  # ground (modified below by tunnel cuttings)


def to_cell(x, z):
    return int((x + W) / RES), int((z + H) / RES)


def in_poly(px, pz, poly):
    inside = np.zeros(np.shape(px), bool)
    n = len(poly)
    for k in range(n):
        x1, z1 = poly[k]
        x2, z2 = poly[(k + 1) % n]
        cond = ((z1 > pz) != (z2 > pz))
        xint = (x2 - x1) * (pz - z1) / ((z2 - z1) if z2 != z1 else 1e-9) + x1
        inside ^= cond & (px < xint)
    return inside


def rect_mask(p, grow=0.0, min_dim=0.0):
    c, s = math.cos(math.radians(p["rot"])), math.sin(math.radians(p["rot"]))
    u = (GX - p["cx"]) * c + (GZ - p["cz"]) * s
    v = -(GX - p["cx"]) * s + (GZ - p["cz"]) * c
    hx = max(p["sx"], min_dim) / 2 + grow
    hz = max(p["sz"], min_dim) / 2 + grow
    return (np.abs(u) <= hx) & (np.abs(v) <= hz)


def circ_mask(p, grow=0.0):
    return np.hypot(GX - p["cx"], GZ - p["cz"]) <= p["r"] + grow


# ------------------------------------------------------------------ v3: level pads under the huts (floor within a few cm)
for _r in L.ROOFS:
    _c, _s = math.cos(math.radians(_r["rot"])), math.sin(math.radians(_r["rot"]))
    _u = (GX - _r["cx"]) * _c + (GZ - _r["cz"]) * _s
    _v = -(GX - _r["cx"]) * _s + (GZ - _r["cz"]) * _c
    _out = np.hypot(np.maximum(np.abs(_u) - _r["sx"] / 2, 0), np.maximum(np.abs(_v) - _r["sz"] / 2, 0))
    _in = _out == 0
    _pad = float(np.median(h[_in]))
    _wt = np.clip(1 - _out / 2.0, 0, 1)
    h[:] = h * (1 - _wt) + _pad * _wt

# ------------------------------------------------------------------ tunnels: cuttings and covered middles
OVER_FLOOR = np.full((NX, NZ), np.nan)  # second walking surface height (absolute)
OVER_CROUCH = np.zeros((NX, NZ), bool)
OVER_NAME = np.full((NX, NZ), "", dtype=object)
CROUCH0 = np.zeros((NX, NZ), bool)       # layer-0 cells you can only cross crouched (under a deck)
CUT_RUN_OUT = 1.5  # a tunnel's cutting starts this far (m) past its end, at the ground
CUT_LEVEL = 1.0  # and is at its floor this far (m) short of the roof: a crouched body under it on the level
H0 = h.copy()  # the ground before the cuttings: a covered middle is cut from it, never twice (build_map, CT1)
for t in L.TUNNELS:
    (ax, az), (bx, bz) = t["a"], t["b"]
    Lt = math.hypot(bx - ax, bz - az)
    dx, dz = (bx - ax) / Lt, (bz - az) / Lt
    tt = (GX - ax) * dx + (GZ - az) * dz
    off = np.abs(-(GX - ax) * dz + (GZ - az) * dx)
    t["len"] = Lt
    if t["material"] == "concrete":  # the culvert: bed under the road deck; deck built below
        continue
    mound = L.BERM_H if t["name"] == "Crawl box" else L.KNOLL_H
    floor = h - mound
    cover = t["cover"]
    t["cover"] = cover
    along = (tt >= -CUT_RUN_OUT) & (tt <= Lt + CUT_RUN_OUT)
    mid = np.abs(tt - Lt / 2) <= cover / 2
    # the cutting ramps down from the ground CUT_RUN_OUT past each end to the floor CUT_LEVEL short of the covered
    # middle (CT1: cut to the floor all the way, its ends were walls 1.3 m high and the tunnel a pit)
    run = (Lt - cover) / 2 + CUT_RUN_OUT - CUT_LEVEL
    ramp = np.clip((np.minimum(tt, Lt - tt) + CUT_RUN_OUT) / run, 0, 1)
    floor = np.where(mid, floor, h - mound * ramp)
    trench = along & ~mid & (off <= t["w"] / 2 + 0.4)
    # cutting walls: sloped edges 0.8 m beyond
    edge = along & ~mid & (off > t["w"] / 2 + 0.4) & (off <= t["w"] / 2 + 1.4)
    blend = np.clip((off - (t["w"] / 2 + 0.4)) / 1.0, 0, 1)
    h[:] = np.where(trench, floor, np.where(edge, floor + (h - floor) * blend, h))
    covered = mid & (off <= t["w"] / 2)
    OVER_FLOOR[covered] = floor[covered]
    OVER_CROUCH[covered] = True
    OVER_NAME[covered] = t["name"]

# ------------------------------------------------------------------ decks (bridges, road over the culvert, tower)
DECKS = []


def deck(name, cx, cz, length, width, rot, y, crouch_under=True, rails=True):
    p = {"cx": cx, "cz": cz, "sx": length, "sz": width, "rot": rot}
    m = rect_mask(p)
    DECKS.append({"name": name, "cx": cx, "cz": cz, "sx": length, "sz": width, "rot": rot, "y": float(y), "rails": rails})
    OVER_FLOOR[m] = y
    OVER_NAME[m] = name
    if crouch_under:
        CROUCH0[m & (h < y - 0.6)] = True
    return m


# v3: the North bridge sits square across the stream, its deck level with both bank tops (the bed + 1.7 m), and a
# level landing is cut 1.5 m beyond each end so it meets the ground.
_sd1, _ = L.seg_dist(np.array([L.NB[0]]), np.array([L.NB[1]]), L.STREAM)
_k = min(range(len(L.STREAM) - 1), key=lambda k: L.seg_dist(np.array([L.NB[0]]), np.array([L.NB[1]]), L.STREAM[k:k + 2])[0][0])
(_ax, _az), (_bx, _bz) = L.STREAM[_k], L.STREAM[_k + 1]
NB_ROT = math.degrees(math.atan2(-(_bx - _ax), _bz - _az))  # perpendicular to the stream
nbi, nbj = to_cell(*L.NB)
nb_y = float(L.bed_h[nbi, nbj] + L.STREAM_D)
NB_LEN = 2 * (L.BED_W + L.BANK) + 1.0
_c, _s = math.cos(math.radians(NB_ROT)), math.sin(math.radians(NB_ROT))
_u = (GX - L.NB[0]) * _c + (GZ - L.NB[1]) * _s
_v = -(GX - L.NB[0]) * _s + (GZ - L.NB[1]) * _c
_out = np.hypot(np.maximum(np.abs(_u) - (NB_LEN / 2 + 1.5), 0), np.maximum(np.abs(_v) - 1.6, 0))
_land = (np.abs(_u) >= L.BED_W + L.BANK) & (L.sd >= L.BED_W + L.BANK)
h[:] = np.where(_land, np.minimum(h, nb_y + 0.6 * _out), h)
deck("North bridge", L.NB[0], L.NB[1], NB_LEN, 1.8, NB_ROT, nb_y)
ci, cj = to_cell(*L.CULVERT)
road_y = float(L.road_h[ci, cj])
CUL_LEN, CUL_W = 7.5, 2 * L.CUL_HALF  # along the road (spans the stream's 5.6 m cut at this angle), across it (road + kerbs)
deck("Road over the culvert", L.CULVERT[0], L.CULVERT[1], CUL_LEN, CUL_W, L.CUL_ROT, road_y, rails=False)
# the culvert itself is the bed under that deck: crouch, enclosed (headwalls)
cul_m = rect_mask({"cx": L.CULVERT[0], "cz": L.CULVERT[1], "sx": CUL_LEN, "sz": CUL_W, "rot": L.CUL_ROT})
L.TUNNELS[2]["len"] = 2 * L.CUL_HALF

tx, tz = L.TOWER
ti, tj = to_cell(tx, tz)
tower_g = float(h[ti, tj])
TOWER_Y = tower_g + 3.4
tower_m = deck("Tower platform", tx, tz, 4.0, 4.0, 0.0, TOWER_Y, crouch_under=False, rails=False)
LADDER_FOOT = (tx + 2.9, tz)
LADDER_TOP = (tx + 1.6, tz)

# ------------------------------------------------------------------ blocking grids
walk_block = np.zeros((NX, NZ), bool)
sight_lo = np.full((4, NX, NZ), np.inf)   # absolute bands that block sight: 0 on the ground, 1 decks, 2 roofs, 3 ferns
sight_hi = np.full((4, NX, NZ), -np.inf)


def add_sight(mask, lo, hi, band=0):
    lo = np.broadcast_to(lo, mask.shape)
    hi = np.broadcast_to(hi, mask.shape)
    sight_lo[band][mask] = np.minimum(sight_lo[band][mask], lo[mask])
    sight_hi[band][mask] = np.maximum(sight_hi[band][mask], hi[mask])


thicket_mask = np.zeros((NX, NZ), bool)
for poly in L.THICKETS:
    thicket_mask |= in_poly(GX, GZ, poly)
walk_block |= thicket_mask
add_sight(thicket_mask, h - 1, h + 5.0)

# structures: posts (shed, tower legs)
sx, sz_, ssx, ssz = L.SHED
for px in (sx - ssx / 2, sx, sx + ssx / 2):
    for pz in (sz_ - ssz / 2, sz_ + ssz / 2):
        L.circ("post", px, pz, 0.15, top=3.2)
for px in (tx - 2, tx + 2):
    for pz in (tz - 2, tz + 2):
        L.circ("post", px, pz, 0.15, top=3.4)
# tower parapet (on the platform), roof
for (a, b, sx2, sz2) in [(tx, tz - 2, 4.0, 0.2), (tx, tz + 2, 4.0, 0.2), (tx - 2, tz, 0.2, 4.0)]:
    L.rect("parapet", a, b, sx2, sz2, 0, top=4.5 - 3.4, walk=False, bottom=3.4)
    L.pieces[-1]["abs_base"] = tower_g
L.ROOFS.append({"cx": tx, "cz": tz, "sx": 4.8, "sz": 4.8, "rot": 0, "y": 5.6, "tag": "tower", "abs_base": tower_g})
L.ROOFS.append({"cx": sx, "cz": sz_, "sx": ssx + 1, "sz": ssz + 1, "rot": 0, "y": 3.2, "tag": "shed"})
# doors: the start state (shut ones block sight; every door counts as open for run times, opening takes a moment)
DOORS = []
for (x, z, rot, w, tag) in L.DOORWAYS:
    hr = next(r for r in L.ROOFS if r["tag"] == tag)
    dx, dz = x - hr["cx"], z - hr["cz"]
    side = ("east" if dx > 0 else "west") if abs(dx) > abs(dz) else ("south" if dz > 0 else "north")
    shut = (tag, side) in L.DOOR_SHUT
    DOORS.append({"x": x, "z": z, "rot": rot, "w": w, "tag": tag, "side": side, "shut": shut})
    if shut:
        L.rect("door", x, z, w, 0.12, rot, top=2.1, walk=False, tag=tag)
# ferns: hide a crouched player (band 3, ground to 1.0 m); walkable
FERN_MASK = np.zeros((NX, NZ), bool)
for (fx, fz, rx, rz, rot, _) in L.FERNS:
    c, s_ = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    u = (GX - fx) * c + (GZ - fz) * s_
    v = -(GX - fx) * s_ + (GZ - fz) * c
    FERN_MASK |= (u / rx) ** 2 + (v / rz) ** 2 <= 1.0
add_sight(FERN_MASK, h - 0.5, h + L.FERN_TOP, band=3)
# culvert headwalls (the road embankment faces): block sight across the bed under the road except along the pipe
for p in L.pieces:
    m = rect_mask(p, min_dim=RES) if p["shape"] == "rect" else circ_mask(p, grow=0.1)
    base = p.get("abs_base")
    g = h if base is None else base
    if p["walk"] and p["kind"] != "window" and p.get("bottom", 0) == 0:
        walk_block |= (rect_mask(p, min_dim=RES) if p["shape"] == "rect" else circ_mask(p))
    if p["kind"] == "window":
        walk_block |= rect_mask(p, min_dim=RES)
        add_sight(m, g, g + 1.0)
        add_sight(m, g + 2.1, g + 2.5, band=2)
    else:
        add_sight(m, g + p.get("bottom", 0), g + p.get("bottom", 0) + p["top"], band=1 if p.get("bottom", 0) > 0 else 0)
for r in L.ROOFS:
    m = rect_mask({"cx": r["cx"], "cz": r["cz"], "sx": r["sx"], "sz": r["sz"], "rot": r["rot"]})
    g = r.get("abs_base", h)
    add_sight(m, g + r["y"], g + r["y"] + 0.2, band=2)
for d in DECKS:
    m = rect_mask(d)
    if d["name"].startswith("Road"):
        # embankment: solid from the pipe top (bed + 1.3) to the road, except the pipe's 1.6 m wide line
        add_sight(m, h + 1.3, d["y"], band=1)
    else:
        add_sight(m, d["y"] - 0.3, d["y"], band=1)

# ------------------------------------------------------------------ trees
heroes, raw = L.build_tree_list()
clear = np.zeros((NX, NZ), bool)
clear |= walk_block | thicket_mask
lane_d = np.full((NX, NZ), np.inf)
for path in L.LANE_PATHS.values():
    d, _ = L.seg_dist(GX, GZ, path)
    lane_d = np.minimum(lane_d, d)
link_paths = [[(-36, 6), (-41, -6), (-46, -20)], [(-20, 10), (-22, 22), (-26, 38)], [(46, 2), (64, 12), (70, 22), (64, 30)],
              [(66, -10), (68, -24), (62, -32)]]
for path in link_paths:
    d, _ = L.seg_dist(GX, GZ, path)
    lane_d = np.minimum(lane_d, d)
from numpy.lib.stride_tricks import sliding_window_view  # noqa: E402


def dilate(m, r):
    p = np.pad(m, r)
    return sliding_window_view(p, (2 * r + 1, 2 * r + 1)).any(axis=(2, 3))


near_struct = dilate(walk_block & ~thicket_mask, 3)
clearing_poly = [(-19, -11), (4, -9), (6, 13), (-17, 13)]
no_tree = (near_struct | (L.sd < L.BED_W + L.BANK + 0.8) | (L.rd < 4.0) | (L.hd < 3.0)
           | in_poly(GX, GZ, clearing_poly) | (L.BERM_H > 0.05) | thicket_mask
           | in_poly(GX, GZ, [(-88, -12), (-73, -12), (-73, 18), (-88, 18)])
           | in_poly(GX, GZ, [(73, -16), (88, -16), (88, 14), (73, 14)])
           | in_poly(GX, GZ, [(45, -47), (65, -47), (65, -26), (45, -26)])
           | in_poly(GX, GZ, [(41, 29), (63, 29), (63, 43), (41, 43)])
           | ~np.isnan(OVER_FLOOR))
for t in L.TUNNELS:
    d, _ = L.seg_dist(GX, GZ, [t["a"], t["b"]])
    no_tree |= d < 3.0
TREES = []
for t in heroes:
    TREES.append(t)
for t in raw:
    i, j = to_cell(t[0], t[1])
    if any(math.hypot(t[0] - o[0], t[1] - o[1]) < o[2] + t[2] + 1.2 for o in heroes):
        continue
    if not no_tree[i, j] and not FERN_MASK[i, j]:
        TREES.append(t)
for (x, z, r, k, th) in TREES:
    m = np.hypot(GX - x, GZ - z) <= r + 0.12
    walk_block |= np.hypot(GX - x, GZ - z) <= r
    add_sight(m, h - 0.5, h + th)

# ------------------------------------------------------------------ walkable (layer 0 and layer 1)
pad = dilate(walk_block, 1)  # a body's clearance
walk0 = ~pad
# culvert: enclosed sideways, open along its pipe
_pipe_off, _ = L.seg_dist(GX, GZ, [L.CUL_A, L.CUL_B])
walk0 &= ~(cul_m & (_pipe_off > 0.6))  # under the road you're inside the pipe
walk1 = ~np.isnan(OVER_FLOOR)
inner_tower = rect_mask({"cx": tx, "cz": tz, "sx": 3.2, "sz": 3.2, "rot": 0})
walk1 &= ~(tower_m & ~inner_tower)
SIGHT_LO, SIGHT_HI = sight_lo, sight_hi
