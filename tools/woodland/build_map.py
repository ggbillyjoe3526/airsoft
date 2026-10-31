"""Writes data/maps/woodland.json from tools/woodland/layout.py and world.py (the owner's concept 3 of 2026-10-31, the
layout as data). Needs Python 3.10+ and numpy. Run from anywhere:

    python3 tools/woodland/build_map.py

`python3 tools/woodland/check.py` first: the build checker (foliage, pieces, slopes, decks, banks, reachability) must
print TOTAL 0. The JSON is the map file the game reads (game/map/map_data.gd); never edit it by hand. Re-render the
map's card afterwards (`tools/map_pictures.gd`, docs/ASSETS.md).

The concept is a height field on a 0.5 m grid and pieces on it. The game's blocks are axis-aligned boxes, so the
layout squares every piece to the nearest quarter turn, and the stream runs north-south under both crossings. Here the
ground becomes the terrain grid (vertex heights, the mean of the cells round each), the tunnels are cut into it and
roofed with blocks, and every piece, roof, deck, thicket, tree and the boundary fence becomes a block.
"""
from __future__ import annotations

import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
os.chdir(HERE)
import layout as L  # noqa: E402
import world as Wd  # noqa: E402

OUT = os.path.join(HERE, "..", "..", "data", "maps", "woodland.json")

# The concept's piece kinds as the game's block kinds (game/config/map_style.gd).
KINDS = {"palisade": "fence", "logstack": "log", "log": "log", "logpile": "log", "windthrow": "log",
         "crates": "crate", "lowcrates": "crate", "tyre": "tyre", "tyrestack": "tyre", "truck": "truck",
         "fortwall": "plywood", "lowwall": "plywood", "hutwall": "plywood", "window": "plywood", "post": "log",
         "parapet": "plywood"}
# Pieces this long or longer follow the ground in parts no longer than this (m): walls and palisades on slopes.
FOLLOW = {"palisade", "fortwall", "hutwall", "lowwall"}
PART = 4.0
SINK = 0.3  # every block reaches this far under the lowest ground beneath it
WALL_TOP = {"fort": 2.3}  # a window's lintel tops out with its wall: the Fort's 2.3 m, the huts' 2.5 m
LINTEL_FROM = 2.1
TUNNEL_WALL = (0.7, 1.25)  # a tunnel's side walls, from and to this far off its middle line (m)
TUNNEL_ROOF_HALF = 1.75
TUNNEL_SEG = 1.0
THICKET_TOP = 5.0
THICKET_CELL = 1.0
FENCE_SEG, FENCE_TOP = 8.0, 3.0
FERN_RADIUS, FERN_STEP = 1.0, 1.2
FERN_HEIGHT = 1.2  # a crouched head tops out at 1.13 m: the ferns stand just over it
BUSH_HEIGHT = 1.7
TOWER_RAMP_WIDTH = 1.2
EYE_FACING_EAST = -math.pi / 2  # yaw -90 degrees looks along +x
EYE_FACING_WEST = math.pi / 2
FIRE, LANTERN = 0xFF9A4A, 0xFFD27A
BOT_SIGHT = 60.0

h = Wd.h  # the ground on the cells (centres), after pads, tunnel cuttings and landings


def r(v: float) -> float:
    return round(float(v), 3)


def to_cell(x: float, z: float) -> tuple[int, int]:
    return (min(L.NX - 1, max(0, int((x + L.W) / L.RES))), min(L.NZ - 1, max(0, int((z + L.H) / L.RES))))


def cells(x1: float, z1: float, x2: float, z2: float) -> np.ndarray:
    """The ground heights of the cells under a plan box."""
    i1, j1 = to_cell(x1 + 1e-6, z1 + 1e-6)
    i2, j2 = to_cell(x2 - 1e-6, z2 - 1e-6)
    return h[i1:i2 + 1, j1:j2 + 1]


def ground(x: float, z: float) -> float:
    """The ground under a point as the game reads it: TerrainGrid.height_at on the vertex heights (each cell two
    triangles split along its (x0, z0) to (x1, z1) diagonal)."""
    v = vertices()
    fx, fz = (x + L.W) / L.RES, (z + L.H) / L.RES
    i, j = min(L.NX - 1, max(0, int(fx))), min(L.NZ - 1, max(0, int(fz)))
    u, w = fx - i, fz - j
    h00, h11 = v[i, j], v[i + 1, j + 1]
    if u >= w:
        return float(h00 + u * (v[i + 1, j] - h00) + w * (h11 - v[i + 1, j]))
    return float(h00 + w * (v[i, j + 1] - h00) + u * (h11 - v[i, j + 1]))


_vertices: list[np.ndarray] = []


def lowest(x1: float, z1: float, x2: float, z2: float) -> float:
    """The lowest ground under a plan box as the game reads it: its cells' and its corners' vertex heights."""
    v = vertices()
    i1, j1 = int(math.floor((x1 + L.W) / L.RES + 1e-6)), int(math.floor((z1 + L.H) / L.RES + 1e-6))
    i2, j2 = int(math.ceil((x2 + L.W) / L.RES - 1e-6)), int(math.ceil((z2 + L.H) / L.RES - 1e-6))
    i1, j1, i2, j2 = max(i1, 0), max(j1, 0), min(i2, L.NX), min(j2, L.NZ)
    return min(float(cells(x1, z1, x2, z2).min()), float(v[i1:i2 + 1, j1:j2 + 1].min()))


def vertices() -> np.ndarray:
    """The terrain's vertex heights, (NX + 1) x (NZ + 1): the mean of the cells round each, rounded as written."""
    if not _vertices:
        p = np.pad(h, 1, mode="edge")
        _vertices.append(np.round((p[:-1, :-1] + p[1:, :-1] + p[:-1, 1:] + p[1:, 1:]) / 4.0, 2))
    return _vertices[0]


def block(kind: str, x1: float, y1: float, z1: float, x2: float, y2: float, z2: float, **extra) -> dict:
    b = {"kind": kind, "center": {"x": r((x1 + x2) / 2), "y": r((y1 + y2) / 2), "z": r((z1 + z2) / 2)},
         "size": {"x": r(x2 - x1), "y": r(y2 - y1), "z": r(z2 - z1)}}
    b.update(extra)
    return b


# ------------------------------------------------------------------ the tunnels: cut through their mounds, then roofed
def cut_tunnels() -> list[dict]:
    """Cuts each covered tunnel's middle down to its floor (the concept keeps it as a second surface under the mound,
    which a height field can't) and returns its walls and roof in segments that follow the floor."""
    out = []
    for t in L.TUNNELS:
        if t["material"] == "concrete":
            continue
        (ax, az), (bx, bz) = t["a"], t["b"]
        assert ax == bx, "a tunnel runs north-south"
        mound = L.BERM_H if t["name"] == "Crawl box" else L.KNOLL_H
        top = h.copy()  # the mound's surface, before the cut
        mid = (az + bz) / 2
        z0, z1 = mid - t["cover"] / 2, mid + t["cover"] / 2
        cut = (np.abs(L.GX - ax) <= TUNNEL_WALL[1]) & (L.GZ >= z0 - 0.25) & (L.GZ <= z1 + 0.25)
        # Down to the floor from the ground before the cuttings: the cells either end already in the cutting stay
        # where they are (cut twice, they were 1.5 m pits either side of the Badger run's floor, CT1).
        h[cut] = np.minimum(h, Wd.H0 - mound)[cut]
        kind = "plywood" if t["material"] == "wood" else "log"
        z = z0
        while z < z1 - 1e-6:
            ze = min(z + TUNNEL_SEG, z1)
            floor = float(cells(ax - t["w"] / 2, z, ax + t["w"] / 2, ze).max())
            low = float(cells(ax - t["w"] / 2, z, ax + t["w"] / 2, ze).min())
            i1, j1 = to_cell(ax - TUNNEL_ROOF_HALF, z)
            i2, j2 = to_cell(ax + TUNNEL_ROOF_HALF, ze - 1e-6)
            crown = float(top[i1:i2 + 1, j1:j2 + 1].max())
            under = floor + L.TUNNEL_CLEAR
            crown = max(crown, under + 0.15)  # where the mound runs out, the box stands proud of the ground
            out.append(block(kind, ax - TUNNEL_ROOF_HALF, under, z, ax + TUNNEL_ROOF_HALF, crown, ze))
            for sg in (-1, 1):
                xa, xb = sorted((ax + sg * TUNNEL_WALL[0], ax + sg * TUNNEL_WALL[1]))
                out.append(block(kind, xa, low - SINK, z, xb, under, ze))
            z = ze
    return out


# ------------------------------------------------------------------ pieces
def piece_blocks(p: dict) -> list[dict]:
    kind = p["kind"]
    if kind in ("bush", "door"):
        return []  # bushes are foliage; doors come with the doors (DO1)
    if p["shape"] == "circle":
        hx = hz = p["r"]
    else:
        hx, hz = max(p["sx"], L.RES) / 2, max(p["sz"], L.RES) / 2
    x1, x2, z1, z2 = p["cx"] - hx, p["cx"] + hx, p["cz"] - hz, p["cz"] + hz
    spans = [(x1, x2, z1, z2)]
    if kind in FOLLOW:
        long_x = (x2 - x1) >= (z2 - z1)
        length = (x2 - x1) if long_x else (z2 - z1)
        n = max(1, math.ceil(length / PART - 1e-6))
        spans = [((x1 + (x2 - x1) * k / n, x1 + (x2 - x1) * (k + 1) / n, z1, z2) if long_x else
                  (x1, x2, z1 + (z2 - z1) * k / n, z1 + (z2 - z1) * (k + 1) / n)) for k in range(n)]
    out = []
    for (a1, a2, b1, b2) in spans:
        under = cells(a1, b1, a2, b2)
        lo = float(under.min()) - SINK
        base = p.get("abs_base")
        g = float(base) if base is not None else (float(under.max()) if kind in FOLLOW else ground((a1 + a2) / 2, (b1 + b2) / 2))
        bottom = g + p.get("bottom", 0.0) if p.get("bottom", 0.0) > 0 else lo
        if kind == "window":
            wall_top = WALL_TOP.get(p["tag"], L.HEIGHTS["hutwall"])
            out.append(block(KINDS[kind], a1, lo, b1, a2, g + p["top"], b2))
            out.append(block(KINDS[kind], a1, g + LINTEL_FROM, b1, a2, g + wall_top, b2))
            continue
        out.append(block(KINDS[kind], a1, bottom, b1, a2, g + p.get("bottom", 0.0) + p["top"], b2))
    return out


def roof_blocks() -> list[dict]:
    out = []
    for rf in L.ROOFS:
        base = rf.get("abs_base")
        g = float(base) if base is not None else ground(rf["cx"], rf["cz"])
        y = g + rf["y"]
        out.append(block("plywood", rf["cx"] - rf["sx"] / 2, y, rf["cz"] - rf["sz"] / 2,
                         rf["cx"] + rf["sx"] / 2, y + 0.15, rf["cz"] + rf["sz"] / 2))
    return out


DOOR_T = 0.08  # a leaf's thickness, as Depot's (DO1)


def doors() -> list[dict]:
    """The huts' hinged doors (DO1's format), in the layout's order: each its shut leaves' box, as tall as the hut's
    wall and standing on the doorway's ground, hung on the wall's outer face (the side it swings out to, as check.py
    clears it) and whether it starts the round shut (layout.DOOR_SHUT)."""
    out = []
    off = L.WALL_T / 2 + DOOR_T / 2
    h = L.HEIGHTS["hutwall"]
    for d in Wd.DOORS:
        along_x = abs(math.cos(math.radians(d["rot"]))) > 0.5
        side = 1 if d["side"] in ("east", "south") else -1
        cx, cz = d["x"], d["z"]
        if along_x:
            sx, sz, cz = d["w"], DOOR_T, cz + side * off
        else:
            sx, sz, cx = DOOR_T, d["w"], cx + side * off
        g = ground(d["x"], d["z"])
        out.append({"center": {"x": r(cx), "y": r(g + h / 2), "z": r(cz)},
                    "size": {"x": r(sx), "y": r(h), "z": r(sz)}, "side": side, "shut": d["shut"]})
    return out


# ------------------------------------------------------------------ decks: the North bridge, the culvert, the tower
def deck_blocks() -> list[dict]:
    out = []
    for d in Wd.DECKS:
        assert d["rot"] % 90 == 0, f"{d['name']} must be square to the axes"
        sx, sz = (d["sx"], d["sz"]) if d["rot"] % 180 == 0 else (d["sz"], d["sx"])
        x1, x2, z1, z2 = d["cx"] - sx / 2, d["cx"] + sx / 2, d["cz"] - sz / 2, d["cz"] + sz / 2
        y = d["y"]
        if d["name"].startswith("Road"):
            # The road over the culvert: a slab from the pipe's top to the road, the pipe's walls under it.
            bed = cells(L.CULVERT[0] - 0.8, z1, L.CULVERT[0] + 0.8, z2)
            pipe_top = float(bed.max()) + L.TUNNEL_CLEAR
            assert y - pipe_top >= 0.15, f"the road is {y - pipe_top:.2f} m over the culvert's pipe"
            out.append(block("floor", x1, pipe_top, z1, x2, y, z2, surface="gravel"))
            for (a1, a2) in ((x1, L.CULVERT[0] - 0.8), (L.CULVERT[0] + 0.8, x2)):
                out.append(block("wall", a1, float(bed.min()) - SINK, z1, a2, pipe_top, z2))
            for zz in (z1, z2 - 0.3):  # the kerbs over the headwalls
                out.append(block("wall", x1, y, zz, x2, y + 0.45, zz + 0.3))
        elif d["name"] == "Tower platform":
            out.append(block("floor", x1, y - 0.2, z1, x2, y, z2, surface="wood"))
            # Its stair: a ramp off the open east side, 1:2, down to the ground.
            run = 2.0 * (y - ground(x2 + 6.8, d["cz"])) + 0.2
            foot = ground(x2 + run, d["cz"])
            run = 2.0 * (y - foot) + 0.2
            rz1, rz2 = d["cz"] - TOWER_RAMP_WIDTH / 2, d["cz"] + TOWER_RAMP_WIDTH / 2
            out.append(block("ramp", x2, foot, rz1, x2 + run, y, rz2, rise="-x", surface="wood"))
            under = cells(x2, rz1, x2 + run, rz2)
            assert float((under - foot).max()) <= 0.6, "the ground pokes through the tower's stair"
        else:
            out.append(block("floor", x1, y - 0.3, z1, x2, y, z2, surface="wood"))
            for zz in (z1, z2 - 0.1):  # rails along both sides
                out.append(block("fence", x1, y, zz, x2, y + 1.0, zz + 0.1))
    return out


# ------------------------------------------------------------------ dead space and the edge
def rects_of(mask: np.ndarray, cell: float) -> list[tuple[float, float, float, float]]:
    """Plan rectangles covering a mask on a grid of `cell` m from (-W, -H): runs along x, merged down z."""
    nx, nz = mask.shape
    out, open_runs = [], {}
    for j in range(nz + 1):
        runs = set()
        if j < nz:
            i = 0
            while i < nx:
                if mask[i, j]:
                    k = i
                    while k < nx and mask[k, j]:
                        k += 1
                    runs.add((i, k))
                    i = k
                else:
                    i += 1
        for run in list(open_runs):
            if run not in runs:
                j0 = open_runs.pop(run)
                out.append((-L.W + run[0] * cell, -L.H + j0 * cell, -L.W + run[1] * cell, -L.H + j * cell))
        for run in runs:
            open_runs.setdefault(run, j)
    return out


def thicket_blocks() -> list[dict]:
    f = int(round(THICKET_CELL / L.RES))
    m = Wd.thicket_mask.reshape(L.NX // f, f, L.NZ // f, f).mean(axis=(1, 3)) >= 0.5
    out = []
    for (x1, z1, x2, z2) in rects_of(m, THICKET_CELL):
        under = cells(x1, z1, x2, z2)
        out.append(block("thicket", x1, lowest(x1, z1, x2, z2) - SINK, z1, x2, float(under.max()) + THICKET_TOP, z2))
    return out


def fence_blocks() -> list[dict]:
    out = []
    t = 0.4
    for zz, za, zb in ((-L.H, -L.H - t, -L.H), (L.H, L.H, L.H + t)):
        x = -L.W - t
        while x < L.W + t - 1e-6:
            xe = min(x + FENCE_SEG, L.W + t)
            under = cells(max(x, -L.W), zz - 1 if zz > 0 else zz, min(xe, L.W), zz + 1 if zz < 0 else zz)
            out.append(block("fence", x, float(under.min()) - SINK, za, xe, float(under.max()) + FENCE_TOP, zb))
            x = xe
    for xx, xa, xb in ((-L.W, -L.W - t, -L.W), (L.W, L.W, L.W + t)):
        z = -L.H
        while z < L.H - 1e-6:
            ze = min(z + FENCE_SEG, L.H)
            under = cells(xx - 1 if xx > 0 else xx, z, xx + 1 if xx < 0 else xx, ze)
            out.append(block("fence", xa, float(under.min()) - SINK, z, xb, float(under.max()) + FENCE_TOP, ze))
            z = ze
    return out


def overlaps(a: dict, x: float, z: float, rad: float) -> bool:
    c, s = a["center"], a["size"]
    return abs(x - c["x"]) < s["x"] / 2 + rad and abs(z - c["z"]) < s["z"] / 2 + rad


def tree_blocks(others: list[dict]) -> tuple[list[dict], int]:
    out, dropped = [], 0
    solid = [b for b in others if b["kind"] not in ("fence", "thicket")]
    for (x, z, rad, _kind, height) in Wd.TREES:
        if any(overlaps(b, x, z, rad + 0.3) for b in solid):
            dropped += 1
            continue
        under = cells(x - rad, z - rad, x + rad, z + rad)
        out.append(block("tree", x - rad, float(under.min()) - SINK, z - rad, x + rad, float(under.max()) + height,
                         z + rad))
    return out, dropped


# ------------------------------------------------------------------ the terrain, its surfaces, the foliage
def terrain() -> dict:
    v = vertices()
    heights = [float(v[i, j]) for j in range(L.NZ + 1) for i in range(L.NX + 1)]
    return {"minX": -L.W, "minZ": -L.H, "cell": L.RES, "cols": L.NX, "rows": L.NZ, "heights": heights}


def path(points: list) -> list[dict]:
    return [{"x": r(x), "z": r(z)} for (x, z) in points]


def ground_paint() -> dict:
    patches = [
        {"surface": "earth", "path": path(L.STREAM), "width": r(2 * L.BED_W)},
        {"surface": "earth", "path": path(L.HOLLOW), "width": 3.6},
        {"surface": "gravel", "path": path(L.ROAD), "width": 5.0},
        {"surface": "earth", "box": [-88, -72, -14, 20]},
        {"surface": "earth", "box": [72, 88, -16, 14]},
        {"surface": "earth", "box": [46, 66, 31, 41]},  # the Sawmill's sawdust yard
    ]
    for rf in L.ROOFS:
        if rf["tag"] in ("cabin", "hut1", "hut2", "box"):
            hx, hz = rf["sx"] / 2 - 0.3, rf["sz"] / 2 - 0.3
            patches.append({"surface": "wood", "box": [r(rf["cx"] - hx), r(rf["cx"] + hx), r(rf["cz"] - hz),
                                                       r(rf["cz"] + hz)]})
    for t in L.TUNNELS:
        if t["material"] != "concrete":
            patches.append({"surface": "earth", "path": path([t["a"], t["b"]]), "width": r(t["w"])})
    return {"base": "grass", "underTrees": "leaves", "patches": patches}


def foliage() -> list[dict]:
    out = []
    for (fx, fz, rx, rz, rot, _name) in L.FERNS:
        c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        ax, az = max(rx - FERN_RADIUS * 0.5, 0.0), max(rz - FERN_RADIUS * 0.5, 0.0)
        u = -ax
        while u <= ax + 1e-6:
            v = -az
            while v <= az + 1e-6:
                if ax == 0 or az == 0 or (u / ax) ** 2 + (v / az) ** 2 <= 1.0 + 1e-6:
                    x, z = fx + u * c - v * s, fz + u * s + v * c
                    out.append({"x": r(x), "y": r(ground(x, z)), "z": r(z), "radius": FERN_RADIUS,
                                "height": FERN_HEIGHT})
                v += FERN_STEP
            u += FERN_STEP
    for (x, z, rad, _name) in L.BUSHES:
        out.append({"x": r(x), "y": r(ground(x, z)), "z": r(z), "radius": r(rad), "height": BUSH_HEIGHT})
    return out


# ------------------------------------------------------------------ the field: ends, lanes, flags, areas, lights
def floor_at(x: float, z: float) -> float:
    for d in Wd.DECKS:
        if not d["name"].startswith("Road") and abs(x - d["cx"]) <= d["sx"] / 2 and abs(z - d["cz"]) <= d["sz"] / 2:
            return d["y"]
    return ground(x, z)


def spot(x: float, z: float) -> dict:
    return {"x": r(x), "y": r(floor_at(x, z)), "z": r(z)}


def spawns() -> list[list[dict]]:
    return [[{"position": spot(x, z), "yaw": EYE_FACING_EAST} for (x, z) in L.SPAWNS_W],
            [{"position": spot(x, z), "yaw": EYE_FACING_WEST} for (x, z) in L.SPAWNS_E]]


def dead_zones() -> list[list[dict]]:
    out = []
    for (cx, cz), yaw in ((L.DEAD_W, EYE_FACING_EAST), (L.DEAD_E, EYE_FACING_WEST)):
        out.append([{"position": spot(cx + dx, cz + dz), "yaw": yaw} for dz in (-1.0, 0.0, 1.0) for dx in (-0.5, 0.5)])
    return out


def lanes() -> list[list[dict]]:
    return [[spot(x, z) for (x, z) in L.LANE_PATHS[k]] for k in ("n", "m", "s")]


def areas() -> list[dict]:
    """Each concept area (a polygon) as the plan boxes covering it on a 2 m grid, first listed first."""
    out = []
    cell = 2.0
    xs = -L.W + (np.arange(int(2 * L.W / cell)) + 0.5) * cell
    zs = -L.H + (np.arange(int(2 * L.H / cell)) + 0.5) * cell
    gx, gz = np.meshgrid(xs, zs, indexing="ij")
    owner = np.full(gx.shape, -1)
    for k, (_name, _lane, poly) in enumerate(L.AREAS):
        owner[(owner < 0) & Wd.in_poly(gx, gz, poly)] = k
    # Every square no concept area holds (dead space, the field's edges) takes the nearest area's name, so every
    # walkable spot is in one (field.areas).
    near = np.full(gx.shape, np.inf)
    nearest = np.full(gx.shape, -1)
    for k, (_name, _lane, poly) in enumerate(L.AREAS):
        d, _ = L.seg_dist(gx, gz, list(poly) + [poly[0]])
        closer = d < near
        near[closer], nearest[closer] = d[closer], k
    owner[owner < 0] = nearest[owner < 0]
    for k, (name, _lane, _poly) in enumerate(L.AREAS):
        for (x1, z1, x2, z2) in rects_of(owner == k, cell):
            out.append({"name": name, "box": [r(x1), r(x2), r(z1), r(z2)]})
    return out


def lights() -> list[dict]:
    out = []
    for (x, z, kind) in L.LIGHTS:
        fire = kind == "fire"
        out.append({"position": {"x": r(x), "y": r(floor_at(x, z) + (1.0 if fire else 2.2)), "z": r(z)},
                    "radius": 7 if fire else 5.5, "colour": FIRE if fire else LANTERN,
                    "kind": "fire" if fire else "lantern"})
    return out


def dressing() -> dict:
    edge = [(-L.W - 6, -L.H - 6), (L.W + 6, -L.H - 6), (L.W + 6, L.H + 6), (-L.W - 6, L.H + 6)]
    lines = [[edge[0], edge[1]], [edge[3], edge[2]], [edge[0], edge[3]], [edge[1], edge[2]]]
    return {
        "seed": 3107,
        "woods": {"leaves": 0.22, "fallen": 0.15},
        "moss": {"colour": 0x4E6B3A, "share": 0.4},
        "puddles": [{"x": 8.0, "z": 30.0, "width": 2.4, "depth": 1.6, "mud": True},
                    {"x": -4.5, "z": -25.0, "width": 2.2, "depth": 1.5, "mud": True},
                    {"x": -52.0, "z": 30.5, "width": 3.0, "depth": 1.8},
                    {"x": 30.0, "z": -14.0, "width": 2.4, "depth": 1.6, "mud": True}],
        "skyline": [{"kind": "treeline", "height": 16, "depth": 5, "points": path(ln)} for ln in lines] + [
            {"kind": "hill", "x": 150, "z": -10, "width": 90, "depth": 110, "height": 30, "colour": 0x4F6B45},
            {"kind": "hill", "x": 40, "z": -130, "width": 200, "depth": 90, "height": 22, "colour": 0x587450},
            {"kind": "hill", "x": -160, "z": 20, "width": 110, "depth": 140, "height": 18, "colour": 0x4A6542},
            {"kind": "hill", "x": -40, "z": 135, "width": 190, "depth": 80, "height": 15, "colour": 0x5B7652}],
        "fireflies": {"count": 220},
        "motes": {"tint": 0xC9D2BC},
        "kickedDust": {"tint": 0x8D8467, "scale": 0.9},
        "grass": {"height": 0.34},
        "forest": {"trees": 1800},  # about what fits between the fence and the ground's edge (WoodsConfig.forest_reach)
    }


SEAM = 0.025  # FieldStandard.SEAM_SLACK: blocks may overlap this much


def box(b: dict) -> tuple[list[float], list[float]]:
    c, s = b["center"], b["size"]
    return ([c["x"] - s["x"] / 2, c["y"] - s["y"] / 2, c["z"] - s["z"] / 2],
            [c["x"] + s["x"] / 2, c["y"] + s["y"] / 2, c["z"] + s["z"] / 2])


def set_box(b: dict, lo: list[float], hi: list[float]) -> None:
    for k, a in enumerate("xyz"):
        b["center"][a] = r((lo[k] + hi[k]) / 2)
        b["size"][a] = r(hi[k] - lo[k])


def settle(blocks: list[dict]) -> list[dict]:
    """No block inside another (the field check): a tree in a thicket is left out; a post or a sill under a roof,
    lintel or platform stops at its underside; walls meeting at a corner or a window give way along the wall."""
    out = list(blocks)
    for _ in range(3):
        changed = False
        boxes = [box(b) for b in out]
        drop = set()
        for i in range(len(out)):
            if i in drop:
                continue
            for j in range(i + 1, len(out)):
                if j in drop:
                    continue
                (alo, ahi), (blo, bhi) = boxes[i], boxes[j]
                grip = [min(ahi[k], bhi[k]) - max(alo[k], blo[k]) for k in range(3)]
                if min(grip) <= SEAM:
                    continue
                kinds = {out[i]["kind"], out[j]["kind"]}
                if "tree" in kinds:
                    drop.add(i if out[i]["kind"] == "tree" else j)
                    continue
                # The thinnest overlap gives way, unless that would leave nothing of a block (a wall end inside a post).
                sizes = [min(ahi[k] - alo[k], bhi[k] - blo[k]) for k in range(3)]
                fits = [k for k in range(3) if grip[k] < sizes[k] - 0.05] or [1]
                axis = min(fits, key=lambda k: grip[k])
                if axis == 1:
                    lower, upper = (i, j) if alo[1] < blo[1] else (j, i)
                    lo, hi = boxes[lower]
                    hi[1] = boxes[upper][0][1]
                    set_box(out[lower], lo, hi)
                else:
                    # j gives way, unless it is a walking surface: that never does.
                    keep, give = (j, i) if out[j]["kind"] in ("floor", "ramp") else (i, j)
                    (klo, khi), (glo, ghi) = boxes[keep], boxes[give]
                    if (glo[axis] + ghi[axis]) / 2 < (klo[axis] + khi[axis]) / 2:
                        ghi[axis] = klo[axis]
                    else:
                        glo[axis] = khi[axis]
                    set_box(out[give], glo, ghi)
                    if ghi[axis] - glo[axis] < 0.05:
                        drop.add(give)
                changed = True
                boxes = [box(b) for b in out]
        out = [b for k, b in enumerate(out) if k not in drop]
        if not changed:
            break
    return out


def main() -> None:
    tunnels = cut_tunnels()
    blocks = tunnels + deck_blocks() + roof_blocks()
    for p in L.pieces:
        blocks += piece_blocks(p)
    blocks += thicket_blocks()
    trees, dropped = tree_blocks(blocks)
    blocks = settle(blocks + fence_blocks() + trees)
    trees = [t for t in blocks if t["kind"] == "tree"]
    data = {
        "name": "Woodland",
        "blocks": blocks,
        "killY": -10,
        "spawns": spawns(),
        "deadZones": dead_zones(),
        "lanes": lanes(),
        "flags": [spot(x, z) for x, z in L.FLAGS],
        "overtimeFlag": spot(*L.OT_FLAG),
        "botSight": BOT_SIGHT,
        "night": False,  # day by default (the first preset); night is the Time of day setting's
        "lighting": {"presets": ["day", "night"], "moonOver": {"x": r(L.OT_FLAG[0]), "z": r(L.OT_FLAG[1])},
                     "overrides": {"night": {"hemi": {"intensity": 1.4}, "key": {"intensity": 1.35},
                                             "exposureScale": 1.55}}},
        "terrain": terrain(),
        "ground": ground_paint(),
        "foliage": foliage(),
        "lights": lights(),
        "ambience": "woods",
        "dressing": dressing(),
        "areas": areas(),
        "doors": doors(),
    }
    with open(OUT, "w") as f:
        json.dump(data, f, separators=(",", ":"))
        f.write("\n")
    kinds: dict[str, int] = {}
    for b in blocks:
        kinds[b["kind"]] = kinds.get(b["kind"], 0) + 1
    print(f"woodland.json: {len(blocks)} blocks {kinds}, {len(trees)} trees ({dropped} left out by a block), "
          f"{len(data['foliage'])} foliage, {len(data['areas'])} area boxes, {len(data['doors'])} doors, {os.path.getsize(OUT) // 1024} KB")


if __name__ == "__main__":
    main()
