"""Build checks: is every piece where it should be? Prints the problems and their total."""
from __future__ import annotations

import json
import math

import numpy as np

import layout as L
import world as Wd
from layout import GX, GZ
from world import rect_mask, circ_mask, to_cell

h = Wd.h
issues = []


def note(kind, msg):
    issues.append((kind, msg))


def pmask(p):
    return rect_mask(p) if p["shape"] == "rect" else circ_mask(p)


def fern_mask(f):
    fx, fz, rx, rz, rot, _ = f
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    u = (GX - fx) * c + (GZ - fz) * s
    v = -(GX - fx) * s + (GZ - fz) * c
    return (u / rx) ** 2 + (v / rz) ** 2 <= 1.0


road = L.rd < 2.5 + 0.3
bed = L.sd < L.BED_W + L.BANK + 0.3
deck_m = ~np.isnan(Wd.OVER_FLOOR)
flag_m = np.zeros_like(road)
for (x, z) in L.FLAGS:
    flag_m |= np.hypot(GX - x, GZ - z) < 3.2
solid = [p for p in L.pieces if p["kind"] not in ("window", "door", "post", "parapet")]

# 1. foliage on the road, in the stream, on decks, on flags, in pieces
for f in L.FERNS:
    m = fern_mask(f)
    for nm, area in (("road", road), ("stream", bed), ("deck/tunnel", deck_m), ("flag ring", flag_m)):
        if (m & area).any():
            note("foliage", f"fern bed {f[5]} overlaps the {nm}")
    for p in solid:
        if (m & pmask(p)).any() and p["kind"] != "bush":
            note("foliage", f"fern bed {f[5]} overlaps {p['kind']} at ({p['cx']:.1f}, {p['cz']:.1f})")
for (x, z, r, nm) in L.BUSHES:
    m = np.hypot(GX - x, GZ - z) <= r
    for an, area in (("road", road), ("stream", bed), ("deck/tunnel", deck_m), ("flag ring", flag_m)):
        if (m & area).any():
            note("foliage", f"bush {nm} overlaps the {an}")
# 2. hard pieces on the road or in the stream bed (the culvert deck is the road)
for p in solid:
    if p["kind"] in ("bush", "palisade"):
        continue
    m = pmask(p)
    if (m & (L.rd < 2.5)).any():
        note("piece", f"{p['kind']} at ({p['cx']:.1f}, {p['cz']:.1f}) is on the road")
    if (m & (L.sd < L.BED_W + L.BANK)).any():
        note("piece", f"{p['kind']} at ({p['cx']:.1f}, {p['cz']:.1f}) is in the stream bed or bank")
# 3. pieces overlapping each other (walls of one building excepted)
for a in range(len(solid)):
    for b in range(a + 1, len(solid)):
        p, q = solid[a], solid[b]
        if p["tag"] and p["tag"] == q["tag"]:
            continue
        if math.hypot(p["cx"] - q["cx"], p["cz"] - q["cz"]) > 12:
            continue
        if (pmask(p) & pmask(q)).sum() > 2:
            note("overlap", f"{p['kind']} ({p['cx']:.1f}, {p['cz']:.1f}) overlaps {q['kind']} ({q['cx']:.1f}, {q['cz']:.1f})")
# 4. pieces on slopes: ground under the footprint varies by more than 0.5 m (floats on one side, buried on the other)
for p in solid:
    if p["kind"] in ("palisade", "fortwall", "hutwall", "lowwall", "bush", "windthrow", "log", "logpile"):  # logs lie along the slope
        continue
    v = h[pmask(p)]
    if len(v) and v.max() - v.min() > 0.5:
        note("slope", f"{p['kind']} at ({p['cx']:.1f}, {p['cz']:.1f}) sits on {v.max() - v.min():.2f} m of slope")
# hut floors: ground inside each hut level within 0.4 m
for r in L.ROOFS:
    if r["tag"] in ("tower", "shed"):
        continue
    m = rect_mask({"cx": r["cx"], "cz": r["cz"], "sx": r["sx"] - 1.0, "sz": r["sz"] - 1.0, "rot": r["rot"]})
    v = h[m]
    if v.max() - v.min() > 0.4:
        note("slope", f"hut {r['tag']} floor varies {v.max() - v.min():.2f} m")
# 5. trees touching each other or pieces
T = Wd.TREES
for a in range(len(T)):
    for b in range(a + 1, len(T)):
        if math.hypot(T[a][0] - T[b][0], T[a][1] - T[b][1]) < T[a][2] + T[b][2] + 0.6:
            note("tree", f"trees at ({T[a][0]:.1f}, {T[a][1]:.1f}) and ({T[b][0]:.1f}, {T[b][1]:.1f}) touch")
for (x, z, r, k, th) in T:
    i, j = to_cell(x, z)
    if road[i, j] or (L.sd[i, j] < L.BED_W + L.BANK) or deck_m[i, j]:
        note("tree", f"tree at ({x:.1f}, {z:.1f}) on road/stream/deck")
# 6. open doors: the leaf's swing is clear
for d in Wd.DOORS:
    if d["shut"]:
        continue
    r = next(q for q in L.ROOFS if q["tag"] == d["tag"])
    c, s = math.cos(math.radians(d["rot"])), math.sin(math.radians(d["rot"]))
    nx, nz = -s, c
    if (d["x"] - r["cx"]) * nx + (d["z"] - r["cz"]) * nz < 0:
        nx, nz = -nx, -nz
    sw = np.hypot(GX - (d["x"] - c * d["w"] / 2), GZ - (d["z"] - s * d["w"] / 2)) <= d["w"]
    sw &= ((GX - d["x"]) * nx + (GZ - d["z"]) * nz) > 0.2
    hit = [p for p in solid if p["tag"] != d["tag"] and (sw & pmask(p)).any()]
    tr = [t for t in T if sw[to_cell(t[0], t[1])]]
    if hit or tr:
        note("door", f"{d['tag']} {d['side']} door swing blocked by {[p['kind'] for p in hit]} {len(tr)} trees")
# 7. lights in the open
for (x, z, k) in L.LIGHTS:
    i, j = to_cell(x, z)
    if Wd.walk_block[i, j]:
        note("light", f"{k} at ({x}, {z}) is inside a piece")
# 8. bridge and culvert decks level with the ground at their ends
for dk in Wd.DECKS:
    if dk["name"].startswith("Tower"):
        continue
    c, s = math.cos(math.radians(dk["rot"])), math.sin(math.radians(dk["rot"]))
    for e in (-1, 1):
        x, z = dk["cx"] + e * (dk["sx"] / 2 + 0.3) * c, dk["cz"] + e * (dk["sx"] / 2 + 0.3) * s
        g = h[to_cell(x, z)]
        if abs(g - dk["y"]) > 0.15:
            note("deck", f"{dk['name']} end {e:+d}: ground {g:.2f} vs deck {dk['y']:.2f}")
# 9. stream banks: the ground just past each bank top is at least 1.35 m above the bed, away from the slides, Ford,
#    the North bridge's landings and the culvert
ring = (L.sd > L.BED_W + L.BANK + 0.2) & (L.sd < L.BED_W + L.BANK + 0.7) & (np.abs(GX) < 86) & (np.abs(GZ) < 58)
for (sx, sz) in L.SLIDES + [L.NB, L.CULVERT]:
    ring &= np.hypot(GX - sx, GZ - sz) > 10  # game build: slides ramp 7.5 m along the stream
low = ring & (h - L.bed_h < 1.35)
if low.any():
    pts = np.argwhere(low)
    note("stream", f"{len(pts)} bank cells under 1.35 m, e.g. ({L.XS[pts[0][0]]:.1f}, {L.ZS[pts[0][1]]:.1f}) "
                   f"{(h - L.bed_h)[tuple(pts[0])]:.2f} m")
# 10. reachability from both spawns (layer 0 or 1)
from analyze import dijkstra, at  # noqa: E402
west, east = dijkstra(L.SPAWNS_W), dijkstra(L.SPAWNS_E)
reach = np.isfinite(np.minimum(west[0], west[1])) | np.isfinite(np.minimum(east[0], east[1]))
walkable = Wd.walk0
unreached = walkable & ~np.isfinite(np.minimum(west[0], west[1]))
frac = unreached.sum() / max(walkable.sum(), 1)
if frac > 0.002:
    note("reach", f"{100 * frac:.1f}% of walkable ground can't be reached from the west spawn")
for t in L.TUNNELS:
    m = (Wd.OVER_NAME == t["name"])
    if t["material"] == "concrete":
        m = rect_mask({"cx": L.CULVERT[0], "cz": L.CULVERT[1], "sx": 2, "sz": 2, "rot": 0}) & Wd.walk0
    v = np.minimum(west[0][m], west[1][m])
    if not np.isfinite(v).any():
        note("reach", f"tunnel {t['name']} can't be entered")
for nm, (x, z) in (("A", L.FLAG_A), ("B", L.FLAG_B), ("OT", L.OT_FLAG), ("North bridge", L.NB), ("Tower", L.TOWER)):
    if not math.isfinite(at(west, x, z)) or not math.isfinite(at(east, x, z)):
        note("reach", f"{nm} unreachable")

kinds = {}
for k, m in issues:
    kinds[k] = kinds.get(k, 0) + 1
    print(f"[{k}] {m}")
print("TOTAL", len(issues), kinds)
