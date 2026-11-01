"""Writes data/maps/street.json (The Street, ST1) from tools/street/layout.py, the owner's concept 3 as data. Run from
anywhere:

    python3 tools/street/build_map.py

Then re-render its card (`tools/map_pictures.gd`, docs/ASSETS.md). The JSON is the map file the game reads
(game/map/map_data.gd). Every colour is a palette colour of the shared look (LookConfig, by name in PAINT), written
on its block (`colour`, MapData.Block.colour); tests/unit/test_street.gd holds the map to them.
"""
from __future__ import annotations

import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import layout as L  # noqa: E402

OUT = os.path.join(HERE, "..", "..", "data", "maps", "street.json")

# The shared look's palette (game/config/look_config.gd, sRGB), the names this map paints in.
PALETTE = {
    "crimson": 0xC23874, "violet": 0x7658AA, "yellow": 0xE4CA46, "teal": 0x2A9C90, "green": 0x58904E,
    "cream": 0xF4ECDA, "concrete": 0xD2CEC8, "floor": 0xB9B4AE, "plywood": 0xDCCAA8, "timber": 0xA0947C,
    "steel": 0x6C6A7A, "ink": 0x3A2F5A, "slab": 0x7C7670, "sand": 0xB9AE98, "plaster": 0xECE2CF, "grey": 0x8C8A96,
    "stone": 0x8C8478, "ceiling": 0x524A72, "umber": 0x61594F, "bark": 0x7B6F62, "canopy": 0x5C9A50,
    "forest": 0x2B5C48, "meadow": 0x8AA860, "pond": 0x4A6F6C, "rubber": 0x3D3B45,
    # the street's own (ST1): brick, and the terraces' pastel render
    "brick": 0xA34A6A, "seafoam": 0x7FB8AD, "lilac": 0xB9A8D6, "butter": 0xE6D478, "sage": 0xA9C48E,
}
# Each ground (layout.zone) as its surface and paint; a cell no zone holds is grass (under houses and scrub).
GROUND = {"road": ("concrete", "slab"), "pave": ("concrete", "floor"), "grass": ("grass", "meadow"),
          "path": ("concrete", "sand"), "tarmac": ("concrete", "grey"), "floor": ("wood", "timber"),
          "setts": ("concrete", "stone")}
# Where zones overlap, the ground first here wins: the island's setts on the car park, the Path over the green.
GROUND_ORDER = ["floor", "setts", "path", "road", "pave", "tarmac", "grass"]
# The terraces' colours, by layout.building's colour index.
HOUSE_PAINT = ["plaster", "brick", "seafoam", "lilac", "butter", "sage"]
# The concept's piece kinds as the game's block kinds (game/config/map_style.gd) and their paint; a list paints its
# pieces in turn.
KINDS = {
    "hwall": ("wall", "plaster"), "fence": ("fence", "timber"), "gateleaf": ("fence", "timber"),
    "hedge": ("hedge", "canopy"), "lowhedge": ("hedge", "canopy"), "dead": ("scrub", "forest"),
    "railing": ("railing", "steel"), "lowwall": ("lowwall", "stone"), "kerbwall": ("lowwall", "stone"),
    "car": ("car", ["crimson", "teal", "cream", "lilac", "yellow", "green", "grey"]),
    "van": ("van", ["cream", "plaster", "teal", "grey"]), "lorry": ("lorry", ["crimson", "teal", "cream"]),
    "bins": ("bins", ["green", "steel", "teal"]), "skip": ("skip", "yellow"), "binstore": ("brick", "brick"),
    "phone": ("brick", "brick"), "kiosk": ("cabinet", "green"), "cabinet": ("cabinet", "green"),
    "lamp": ("lamp", "steel"), "tree": ("tree", "bark"), "shed": ("shed", "umber"), "sofa": ("furniture", "violet"),
    "table": ("furniture", "timber"), "units": ("furniture", "cream"), "fridge": ("fridge", "cream"),
}
# The CC0 prop (PropDressConfig.models, tools/props/build_props.py) each piece kind is drawn as, in its block's box
# (ST2); "{}" takes the piece's paint, as the props come in the colours the blocks are painted.
DRESS = {"car": "car_{}", "van": "van_{}", "lorry": "lorry_{}", "bins": "bin_{}", "skip": "skip", "lamp": "lamp",
         "tree": "trunk", "sofa": "settee", "table": "table", "units": "units", "fridge": "fridge"}
GLASS_PAINT = "pond"
ROOF_PAINT = "ceiling"
WORKS_PAINT = "grey"
HOUSE_WALL = 2.75  # the House's rooms: walls and the floor over them (the arches' lids too)
SILL, LINTEL = 1.0, 2.1  # a window: solid under the sill and over the lintel (no climbing in: vaults stop at 0.95 m)
DOOR_H = 2.1
GLASS_T = 0.06
HOARDING_T = 0.1
BOLLARD = 0.22  # a bollard's side (m), one every BOLLARD_STEP along its row
BOLLARD_STEP = 1.4
TREE_SIDE = 0.4
MAX_ROOF_SLOPE = 0.5  # FieldStandard.MAX_RAMP_SLOPE: a roof is a pair of ramps, so no steeper
EYE_FACING_NORTH = 0.0  # yaw 0 looks along -z
EYE_FACING_SOUTH = math.pi
BOT_SIGHT = 55.0
LAMP_LIGHT = (4.6, 8.0)  # a street lamp's light: its height and its pool's radius (m)
LAMP_COLOUR = 0xFFD27A  # a lantern's (LightingConfig.lantern_colour draws it)
RES = 0.5
SEAM = 0.02  # FieldStandard.SEAM_SLACK is 0.025 m


def r(v: float) -> float:
    return round(v, 3)


def block(kind: str, x1: float, y1: float, z1: float, x2: float, y2: float, z2: float, paint: str, **extra) -> dict:
    b = {"kind": kind, "center": {"x": r((x1 + x2) / 2), "y": r((y1 + y2) / 2), "z": r((z1 + z2) / 2)},
         "size": {"x": r(x2 - x1), "y": r(y2 - y1), "z": r(z2 - z1)}, "colour": PALETTE[paint]}
    b.update(extra)
    return b


# ------------------------------------------------------------------ ground
def rects_of(mask: np.ndarray) -> list[tuple[float, float, float, float]]:
    """Plan rectangles covering a mask on the RES grid from (-W, -H): runs along x, merged down z."""
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
                out.append((-L.W + run[0] * RES, -L.H + j0 * RES, -L.W + run[1] * RES, -L.H + j * RES))
        for run in runs:
            open_runs.setdefault(run, j)
    return out


def cell_span(a: float, b: float, lo: float) -> tuple[int, int]:
    return int(round((a - lo) / RES)), int(round((b - lo) / RES))


def ground_blocks() -> list[dict]:
    """The ground as floor blocks, one per run of a ground (zones rasterised on the RES grid), half a metre deep."""
    nx, nz = int(2 * L.W / RES), int(2 * L.H / RES)
    rank = np.full((nx, nz), GROUND_ORDER.index("grass"))
    for zn in L.zones:
        i1, i2 = cell_span(zn["x1"], zn["x2"], -L.W)
        j1, j2 = cell_span(zn["z1"], zn["z2"], -L.H)
        sub = rank[i1:i2, j1:j2]
        np.minimum(sub, GROUND_ORDER.index(zn["ground"]), out=sub)
    out = []
    for k, g in enumerate(GROUND_ORDER):
        surface, paint = GROUND[g]
        for (x1, z1, x2, z2) in rects_of(rank == k):
            out.append(block("floor", x1, -0.5, z1, x2, 0.0, z2, paint, surface=surface))
    return out


# ------------------------------------------------------------------ houses
def roof_blocks(x1: float, z1: float, x2: float, z2: float, eaves: float, ridge: str, rise: float) -> list[dict]:
    """A pitched roof over the box, its ridge along `ridge`: two ramps (field.ramps holds them to 1:2)."""
    if rise <= 0.0:
        return []
    if ridge == "z":
        half = (x2 - x1) / 2
        h = min(rise, MAX_ROOF_SLOPE * half - 0.01)
        return [block("roof", x1, eaves, z1, x1 + half, eaves + h, z2, ROOF_PAINT, rise="+x"),
                block("roof", x1 + half, eaves, z1, x2, eaves + h, z2, ROOF_PAINT, rise="-x")]
    half = (z2 - z1) / 2
    h = min(rise, MAX_ROOF_SLOPE * half - 0.01)
    return [block("roof", x1, eaves, z1, x2, eaves + h, z1 + half, ROOF_PAINT, rise="+z"),
            block("roof", x1, eaves, z1 + half, x2, eaves + h, z2, ROOF_PAINT, rise="-z")]


def building_blocks() -> list[dict]:
    out = []
    for b in L.buildings:
        paint = WORKS_PAINT if b["kind"] == "works" else HOUSE_PAINT[b["colour"] % len(HOUSE_PAINT)]
        out.append(block("house", b["x1"], 0.0, b["z1"], b["x2"], b["eaves"], b["z2"], paint))
        out += roof_blocks(b["x1"], b["z1"], b["x2"], b["z2"], b["eaves"], b["ridge"], b["roof"])
    # The arches: the house over each covered passage, from its lid up, in its neighbours' colour.
    for (x1, z1, x2, z2, eaves), paint in zip(L.ARCHES, ARCH_PAINT):
        out.append(block("house", x1, HOUSE_WALL, z1, x2, eaves, z2, paint))
        out += roof_blocks(x1, z1, x2, z2, eaves, "z", 2.8)
    # The House: its rooms' walls (pieces) under the floor above, then its roof.
    h = L.HOUSE
    out.append(block("house", h["x1"], HOUSE_WALL, h["z1"], h["x2"], 5.4, h["z2"], "plaster"))
    out += roof_blocks(h["x1"], h["z1"], h["x2"], h["z2"], 5.4, "z", 2.8)
    return out


ARCH_PAINT = ["seafoam", "brick"]  # the arch building's (its colour 2) and the Pend's (colour 1), in L.ARCHES order


# ------------------------------------------------------------------ pieces
def paint_of(kind: str, n: int) -> str:
    p = KINDS[kind][1]
    return p[n % len(p)] if isinstance(p, list) else p


def piece_blocks() -> list[dict]:
    out = []
    count: dict[str, int] = {}
    for p in L.pieces:
        k, x1, z1, x2, z2, h = p["kind"], p["x1"], p["z1"], p["x2"], p["z2"], p["h"]
        n = count.get(k, 0)
        count[k] = n + 1
        if k in ("house", "works", "lid", "doorleaf"):
            continue  # drawn by building_blocks; an open door is a door (doors())
        if k == "door":  # a doorway's lintel; the door itself is a door (doors())
            out.append(block("wall", x1, DOOR_H, z1, x2, HOUSE_WALL, z2, "plaster"))
        elif k in ("window", "glass", "openwin"):
            out.append(block("wall", x1, 0.0, z1, x2, SILL, z2, "plaster"))
            out.append(block("wall", x1, LINTEL, z1, x2, HOUSE_WALL, z2, "plaster"))
            if k != "openwin":
                out.append(pane(x1, SILL, z1, x2, LINTEL, z2))
        elif k == "hwall":
            out.append(block("wall", x1, 0.0, z1, x2, HOUSE_WALL, z2, "plaster"))
        elif k == "hoarding":
            out += hoarding(x1, z1, x2, z2, h)
        elif k == "bollard":
            out += bollards(x1, z1, x2, z2, h)
        elif k == "shelter":
            out += shelter(x1, z1, x2, z2, h)
        elif k == "tree":
            cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
            s = TREE_SIDE / 2
            out.append(block("tree", cx - s, 0.0, cz - s, cx + s, h, cz + s, "bark", dress=DRESS["tree"]))
        else:
            kind, _ = KINDS[k]
            paint = paint_of(k, n)
            extra = {"dress": DRESS[k].format(paint)} if k in DRESS else {}
            out.append(block(kind, x1, 0.0, z1, x2, h, z2, paint, **extra))
    return out


def pane(x1: float, y1: float, z1: float, x2: float, y2: float, z2: float) -> dict:
    """A window's glass, GLASS_T thick down the middle of its wall."""
    if x2 - x1 < z2 - z1:
        c = (x1 + x2) / 2
        x1, x2 = c - GLASS_T / 2, c + GLASS_T / 2
    else:
        c = (z1 + z2) / 2
        z1, z2 = c - GLASS_T / 2, c + GLASS_T / 2
    return block("glass", x1, y1, z1, x2, y2, z2, GLASS_PAINT)


def hoarding(x1: float, z1: float, x2: float, z2: float, h: float) -> list[dict]:
    """The roadworks' closed compound: four boards round it."""
    t = HOARDING_T
    return [block("hoarding", x1, 0.0, z1, x2, h, z1 + t, "yellow"),
            block("hoarding", x1, 0.0, z2 - t, x2, h, z2, "yellow"),
            block("hoarding", x1, 0.0, z1 + t, x1 + t, h, z2 - t, "yellow"),
            block("hoarding", x2 - t, 0.0, z1 + t, x2, h, z2 - t, "yellow")]


def bollards(x1: float, z1: float, x2: float, z2: float, h: float) -> list[dict]:
    """A row of posts down the row's long side."""
    along_x = x2 - x1 >= z2 - z1
    a, b = (x1, x2) if along_x else (z1, z2)
    c = (z1 + z2) / 2 if along_x else (x1 + x2) / 2
    n = max(2, int(round((b - a) / BOLLARD_STEP)) + 1)
    out, s = [], BOLLARD / 2
    for i in range(n):
        t = a + s + (b - a - BOLLARD) * i / (n - 1)
        if along_x:
            out.append(block("bollard", t - s, 0.0, c - s, t + s, h, c + s, "ink"))
        else:
            out.append(block("bollard", c - s, 0.0, t - s, c + s, h, t + s, "ink"))
    return out


def shelter(x1: float, z1: float, x2: float, z2: float, h: float) -> list[dict]:
    """The bus shelter: a glass back on its south side, a steel roof over it and the bench's depth."""
    roof_t = 0.12
    return [block("glass", x1, 0.0, z2 - GLASS_T, x2, h - roof_t, z2, GLASS_PAINT),
            block("shelter", x1, h - roof_t, z1, x2, h, z2, "steel")]


def doors() -> list[dict]:
    """The House's hinged doors (DO1's format): each its shut leaves' box, hung on the face `side` names."""
    out = []
    for d in L.DOORS:
        side = d.get("side", 1)
        cx, cz = (d["x1"] + d["x2"]) / 2, (d["z1"] + d["z2"]) / 2
        off = (d["x2"] - d["x1"] if not d["horiz"] else d["z2"] - d["z1"]) / 2 + DOOR_T / 2
        if d["horiz"]:
            sx, sz, cz = d["x2"] - d["x1"], DOOR_T, cz + side * off
        else:
            sx, sz, cx = DOOR_T, d["z2"] - d["z1"], cx + side * off
        out.append({"center": {"x": r(cx), "y": r(DOOR_H / 2), "z": r(cz)},
                    "size": {"x": r(sx), "y": r(DOOR_H), "z": r(sz)}, "side": side, "shut": d["state"] == "shut"})
    return out


DOOR_T = 0.08  # a leaf's thickness, as Depot's and Woodland's (DO1)


# ------------------------------------------------------------------ clashes
def box(b: dict) -> tuple[list[float], list[float]]:
    c, s = b["center"], b["size"]
    return ([c["x"] - s["x"] / 2, c["y"] - s["y"] / 2, c["z"] - s["z"] / 2],
            [c["x"] + s["x"] / 2, c["y"] + s["y"] / 2, c["z"] + s["z"] / 2])


def set_box(b: dict, lo: list[float], hi: list[float]) -> None:
    for k, a in enumerate("xyz"):
        b["center"][a] = r((lo[k] + hi[k]) / 2)
        b["size"][a] = r(hi[k] - lo[k])


def volume(lo: list[float], hi: list[float]) -> float:
    return (hi[0] - lo[0]) * (hi[1] - lo[1]) * (hi[2] - lo[2])


def settle(blocks: list[dict]) -> list[dict]:
    """No block inside another (field.blocks): where two overlap, the smaller gives way along the axis they overlap
    least (a wall's end at a corner, a fence's at a T, a sofa against its wall); one inside a bigger block goes. The
    ground never gives way. Blocks are bucketed on a 4 m grid so each meets only its neighbours."""
    out = list(blocks)
    for _ in range(6):
        changed = False
        boxes = [box(b) for b in out]
        grid: dict[tuple[int, int], list[int]] = {}
        for i, (lo, hi) in enumerate(boxes):
            for gx in range(int(math.floor(lo[0] / 4)), int(math.floor(hi[0] / 4)) + 1):
                for gz in range(int(math.floor(lo[2] / 4)), int(math.floor(hi[2] / 4)) + 1):
                    grid.setdefault((gx, gz), []).append(i)
        drop: set[int] = set()
        seen: set[tuple[int, int]] = set()
        for members in grid.values():
            for ai in range(len(members)):
                for bi in range(ai + 1, len(members)):
                    i, j = members[ai], members[bi]
                    if (i, j) in seen or i in drop or j in drop:
                        continue
                    seen.add((i, j))
                    (alo, ahi), (blo, bhi) = boxes[i], boxes[j]
                    grip = [min(ahi[k], bhi[k]) - max(alo[k], blo[k]) for k in range(3)]
                    if min(grip) <= SEAM:
                        continue
                    if out[i]["kind"] == "floor" or out[j]["kind"] == "floor":
                        raise SystemExit(f"{out[i]} and {out[j]} cross the ground")
                    give, keep = (i, j) if volume(alo, ahi) < volume(blo, bhi) else (j, i)
                    glo, ghi = boxes[give]
                    klo, khi = boxes[keep]
                    sizes = [ghi[k] - glo[k] for k in range(3)]
                    fits = [k for k in range(3) if grip[k] < sizes[k] - 0.05]
                    if not fits:
                        drop.add(give)
                        changed = True
                        continue
                    axis = min(fits, key=lambda k: grip[k])
                    if (glo[axis] + ghi[axis]) / 2 < (klo[axis] + khi[axis]) / 2:
                        ghi[axis] = klo[axis]
                    else:
                        glo[axis] = khi[axis]
                    set_box(out[give], glo, ghi)
                    boxes[give] = box(out[give])
                    changed = True
        out = [b for k, b in enumerate(out) if k not in drop]
        if not changed:
            return out
    raise SystemExit("blocks still cross after six passes")


# ------------------------------------------------------------------ the rest of the file
def spot(x: float, z: float) -> dict:
    return {"x": r(x), "y": 0, "z": r(z)}


def dead_zone(cx: float, cz: float, yaw: float) -> list[dict]:
    """Six walk-off spots: two columns of three, 0.8 m apart, round (cx, cz)."""
    return [{"position": spot(cx + dx, cz + dz), "yaw": yaw} for dz in (-0.8, 0.0, 0.8) for dx in (-0.4, 0.4)]


def areas() -> list[dict]:
    """Every zone as a named area, the smallest first so where two overlap the smaller names it (the Hall in the
    House, the Pend through the back gardens); then every square no zone holds (houses' tops, the scrub) takes the
    nearest zone's name, so every walkable spot is in one (field.areas)."""
    zs = sorted(L.zones, key=lambda z: (z["x2"] - z["x1"]) * (z["z2"] - z["z1"]))
    out = [{"name": z["name"], "box": [r(z["x1"]), r(z["x2"]), r(z["z1"]), r(z["z2"])]} for z in zs]
    cell = 1.0
    nx, nz = int(2 * L.W / cell), int(2 * L.H / cell)
    xs = -L.W + (np.arange(nx) + 0.5) * cell
    zz = -L.H + (np.arange(nz) + 0.5) * cell
    gx, gz = np.meshgrid(xs, zz, indexing="ij")
    held = np.zeros(gx.shape, bool)
    near = np.full(gx.shape, np.inf)
    owner = np.full(gx.shape, -1)
    for k, z in enumerate(zs):
        inside = (gx >= z["x1"]) & (gx < z["x2"]) & (gz >= z["z1"]) & (gz < z["z2"])
        held |= inside
        dx = np.maximum(np.maximum(z["x1"] - gx, gx - z["x2"]), 0)
        dz = np.maximum(np.maximum(z["z1"] - gz, gz - z["z2"]), 0)
        d = np.hypot(dx, dz)
        closer = d < near
        near[closer], owner[closer] = d[closer], k
    names = sorted({z["name"] for z in zs})
    for name in names:
        mask = ~held & np.isin(owner, [k for k, z in enumerate(zs) if z["name"] == name])
        for (x1, z1, x2, z2) in rects_cells(mask, cell):
            out.append({"name": name, "box": [r(x1), r(x2), r(z1), r(z2)]})
    return out


def rects_cells(mask: np.ndarray, cell: float) -> list[tuple[float, float, float, float]]:
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


def lights() -> list[dict]:
    """A pool of lamplight under every street lamp (night)."""
    out = []
    y, radius = LAMP_LIGHT
    for p in L.pieces:
        if p["kind"] == "lamp":
            out.append({"position": {"x": r((p["x1"] + p["x2"]) / 2), "y": y, "z": r((p["z1"] + p["z2"]) / 2)},
                        "radius": radius, "colour": LAMP_COLOUR, "kind": "lantern"})
    return out


def dressing() -> dict:
    """The look beyond the field: a treeline and a wood round it, dust in the air and underfoot."""
    e = 6.0
    corners = [(-L.W - e, -L.H - e), (L.W + e, -L.H - e), (L.W + e, L.H + e), (-L.W - e, L.H + e)]
    lines = [(corners[0], corners[1]), (corners[3], corners[2]), (corners[0], corners[3]), (corners[1], corners[2])]
    sky = [{"kind": "treeline", "height": 12, "depth": 5, "points": [{"x": a[0], "z": a[1]}, {"x": b[0], "z": b[1]}]}
           for a, b in lines]
    return {"seed": 5311, "skyline": sky, "motes": {"tint": 0xD2CEC8}, "kickedDust": {"tint": 0xB9B4AE, "scale": 0.8},
            "forest": {"trees": 900}}


def lanes() -> list[list[dict]]:
    return [[spot(x, z) for (x, z) in LANES[k]] for k in ("l", "m", "r")]


# From the attackers' end (the Bottom street, end 0) towards the defenders' (the embankment, end 1). Each lane stops at
# the defenders' posts by the flags, not at their spawn: in Attack / Defend a defender holds the first point (or two)
# of its lane from its own end (RoundPlanner), so the last point is a lane's post and the one before its forward post.
# Left: the Pend's mouth over the back garden, then the left road. Middle: the path beside the House's front garden
# over the car park, then the path jog. Right: the Arch over the island and the yard, then the yard.
LANES = {
    "l": [(-20.0, 77.0), (-45.5, 60.0), (-45.5, 25.5), (-39.5, 12.0), (-44.0, -10.0), (-34.5, -15.5)],
    "m": [(-3.0, 77.0), (-14.0, 70.0), (-10.0, 30.0), (-10.0, 5.0), (-15.0, -10.0)],
    "r": [(14.0, 77.0), (13.2, 60.0), (11.5, 20.0), (20.0, 0.0), (15.0, -10.5)],
}
DEAD_S = (-14.0, 77.5)  # the attackers' walk-off, west of the Bottom street's spawn hedge
DEAD_N = (-14.5, -63.5)  # the defenders', west of the embankment's


def build() -> dict:
    blocks = ground_blocks() + settle(building_blocks() + piece_blocks())
    return {
        "name": "The Street",
        "blocks": blocks,
        "killY": -10,
        "spawns": [[{"position": spot(x, z), "yaw": EYE_FACING_NORTH} for x, z in L.SPAWNS_S],
                   [{"position": spot(x, z), "yaw": EYE_FACING_SOUTH} for x, z in L.SPAWNS_N]],
        "deadZones": [dead_zone(*DEAD_S, EYE_FACING_NORTH), dead_zone(*DEAD_N, EYE_FACING_SOUTH)],
        "lanes": lanes(),
        "flags": [spot(*L.FLAG_A), spot(*L.FLAG_B)],
        "overtimeFlag": spot(*L.OT_FLAG),
        "botSight": BOT_SIGHT,
        "night": False,  # day by default (the first preset); night is the Time of day setting's
        "lighting": {"presets": ["day", "night"], "moonOver": {"x": r(L.OT_FLAG[0]), "z": r(L.OT_FLAG[1])},
                     # pale render and paving under a clear sky take a little less exposure, as Depot's floor (AD1)
                     "overrides": {"day": {"exposureScale": 0.85}}},
        "lights": lights(),
        "doors": doors(),
        "dressing": dressing(),
        "areas": areas(),
    }


def main() -> None:
    data = build()
    with open(OUT, "w") as f:
        json.dump(data, f, separators=(",", ":"))
        f.write("\n")
    kinds: dict[str, int] = {}
    for b in data["blocks"]:
        kinds[b["kind"]] = kinds.get(b["kind"], 0) + 1
    print(f"street.json: {len(data['blocks'])} blocks {kinds}, {len(data['areas'])} area boxes, "
          f"{len(data['lights'])} lights, {len(data['doors'])} doors, {os.path.getsize(OUT) // 1024} KB")


if __name__ == "__main__":
    main()
