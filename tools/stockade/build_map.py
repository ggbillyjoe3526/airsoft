"""Writes data/maps/stockade.json from layout.py (SK1): the blocks with the props they are drawn as, the flat ground
and its paint, the ends, lanes, flags, sites, areas, doors and night's lights.

    python3 tools/stockade/build_map.py

Stockade is flat, so nothing is settled onto a slope: a block is its layout box. Never edit the JSON by hand."""
from __future__ import annotations

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import layout as L  # noqa: E402

OUT = os.path.join(HERE, "..", "..", "data", "maps", "stockade.json")
CELL = 0.5                      # the ground's grid (m), as Woodland's
HUT_ROOF, HUT_ROOF_LONG, HUT_LONG = "hut_roof", "hut_roof_long", 6.0
EYE_FACING_EAST = -math.pi / 2  # yaw -90 degrees looks along +x
EYE_FACING_WEST = math.pi / 2
FIRE, LANTERN = 0xFF9A4A, 0xFFD27A
BOT_SIGHT = 40.0                # the longest line is 34 m (FieldStandard): bots see a little past it
DOOR_H = L.WALL
# A kind with one model names it; plywood walls, drums, barrels and sofas are drawn by their kind.
KIND_DRESS = {"crate": "crate", "sandbags": "sandbags"}


def r(v: float) -> float:
    return round(float(v), 3)


def block(b: dict) -> dict:
    out = {"kind": b["kind"],
           "center": {"x": r((b["x1"] + b["x2"]) / 2), "y": r((b["y1"] + b["y2"]) / 2), "z": r((b["z1"] + b["z2"]) / 2)},
           "size": {"x": r(b["x2"] - b["x1"]), "y": r(b["y2"] - b["y1"]), "z": r(b["z2"] - b["z1"])}}
    dress = b.get("dress", KIND_DRESS.get(b["kind"]))
    if dress is not None:
        out["dress"] = dress
    return out


def blocks() -> list[dict]:
    out = [block(b) for b in L.boxes]
    for t in L.ROOF_TILES:
        long = max(t["x2"] - t["x1"], t["z2"] - t["z1"])
        out.append(block({"kind": "plywood", "x1": t["x1"], "x2": t["x2"], "z1": t["z1"], "z2": t["z2"], "y1": t["y"],
                          "y2": t["y"] + L.ROOF_T, "dress": HUT_ROOF_LONG if long >= HUT_LONG else HUT_ROOF}))
    for (x, z, rad, model, height) in L.TREES:
        out.append(block({"kind": "tree", "x1": x - rad, "x2": x + rad, "z1": z - rad, "z2": z + rad, "y1": -L.SINK,
                          "y2": height, "dress": model}))
    return out


def spot(x: float, z: float) -> dict:
    return {"x": r(x), "y": 0, "z": r(z)}


def bomb_site(x: float, z: float, radius: float) -> dict:
    out = spot(x, z)
    if radius > 0:
        out["radius"] = radius
    return out


def spawns() -> list[list[dict]]:
    return [[{"position": spot(x, z), "yaw": EYE_FACING_EAST} for (x, z) in L.SPAWNS_W],
            [{"position": spot(x, z), "yaw": EYE_FACING_WEST} for (x, z) in L.SPAWNS_E]]


def dead_zones() -> list[list[dict]]:
    out = []
    for (cx, cz), yaw in ((L.DEAD_W, EYE_FACING_EAST), (L.DEAD_E, EYE_FACING_WEST)):
        out.append([{"position": spot(cx + dx, cz + dz), "yaw": yaw}
                    for dz in (-1.5, -0.5, 0.5, 1.5) for dx in (-0.5, 0.5)])
    return out


def doors() -> list[dict]:
    return [{"center": {"x": r(d["x"]), "y": r(DOOR_H / 2), "z": r(d["z"])},
             "size": {"x": r(d["sx"]), "y": r(DOOR_H), "z": r(d["sz"])}, "side": d["side"], "shut": d["shut"]}
            for d in L.DOORS]


def terrain() -> dict:
    cols = int(2 * L.W / CELL)
    rows = int(2 * L.H / CELL)
    return {"minX": -L.W, "minZ": -L.H, "cell": CELL, "cols": cols, "rows": rows,
            "heights": [0] * ((cols + 1) * (rows + 1))}


def path(points: list) -> list[dict]:
    return [{"x": r(x), "z": r(z)} for (x, z) in points]


def ground_paint() -> dict:
    """Grass, with the ways worn to earth and gravel and the buildings' board floors."""
    e, y, st, ln = L.EDGE, L.YARD, L.STREET, L.LANE
    patches = [
        {"surface": "earth", "box": [-L.W, -L.CAMP_X, -L.H, L.H]},
        {"surface": "earth", "box": [L.CAMP_X, L.W, -L.H, L.H]},
        {"surface": "gravel", "path": path([(-L.CAMP_X, 0.0), (L.CAMP_X, 0.0)]), "width": 2 * st},
        {"surface": "earth", "path": path([(-L.CAMP_X, -(ln + L.H) / 2), (L.CAMP_X, -(ln + L.H) / 2)]), "width": 4.0},
        {"surface": "earth", "path": path([(-L.CAMP_X, (ln + L.H) / 2), (L.CAMP_X, (ln + L.H) / 2)]), "width": 4.0},
        {"surface": "earth", "box": [-e, -22.0, -y, -st]},
        {"surface": "earth", "box": [-e, -22.0, st, y]},
        {"surface": "earth", "box": [22.0, e, -y, -st]},
        {"surface": "earth", "box": [22.0, e, st, ln]},     # the Woodyard's sawdust
        {"surface": "gravel", "path": path([(-12.5, -y), (-12.5, y)]), "width": 5.0},
        {"surface": "gravel", "path": path([(12.5, -y), (12.5, y)]), "width": 5.0},
    ]
    for (x1, x2, z1, z2) in L.FLOORS:
        patches.append({"surface": "wood", "box": [r(x1), r(x2), r(z1), r(z2)]})
    return {"base": "grass", "underTrees": "leaves", "patches": patches}


def lights() -> list[dict]:
    out = []
    for (x, z, kind) in L.LIGHTS:
        fire = kind == "fire"
        out.append({"position": {"x": r(x), "y": 0.7 if fire else 2.2, "z": r(z)}, "radius": 7 if fire else 5.5,
                    "colour": FIRE if fire else LANTERN, "kind": kind})
    return out


def dressing() -> dict:
    edge = [(-L.W - 8, -L.H - 8), (L.W + 8, -L.H - 8), (L.W + 8, L.H + 8), (-L.W - 8, L.H + 8)]
    lines = [[edge[0], edge[1]], [edge[3], edge[2]], [edge[0], edge[3]], [edge[1], edge[2]]]
    return {
        "seed": 5113,
        "woods": {"leaves": 0.12, "fallen": 0.05},
        "skyline": [{"kind": "treeline", "height": 16, "depth": 5, "points": path(ln)} for ln in lines] + [
            {"kind": "hill", "x": 140, "z": 30, "width": 100, "depth": 120, "height": 26, "colour": 0x4F6B45},
            {"kind": "hill", "x": -20, "z": -120, "width": 210, "depth": 90, "height": 20, "colour": 0x587450},
            {"kind": "hill", "x": -150, "z": -10, "width": 100, "depth": 130, "height": 22, "colour": 0x4A6542},
            {"kind": "hill", "x": 30, "z": 125, "width": 180, "depth": 80, "height": 14, "colour": 0x5B7652}],
        "fireflies": {"count": 90},
        "motes": {"tint": 0xD2CDB8},
        "kickedDust": {"tint": 0x9A8E6C, "scale": 1.0},
        "grass": {"height": 0.22},
        "forest": {"trees": 900},
    }


def main() -> None:
    data = {
        "name": "Stockade",
        "blocks": blocks(),
        "killY": -10,
        "spawns": spawns(),
        "deadZones": dead_zones(),
        "lanes": [[spot(x, z) for (x, z) in L.LANES[k]] for k in ("n", "m", "s")],
        "flags": [spot(x, z) for (x, z) in L.FLAGS],
        "bombSites": [bomb_site(*s) for s in L.BOMB_SITES],
        "bombStart": spot(*L.BOMB_START),
        "overtimeFlag": spot(*L.OT_FLAG),
        "botSight": BOT_SIGHT,
        "night": False,
        "lighting": {"presets": ["day", "night"], "moonOver": {"x": 0.0, "z": 0.0},
                     "overrides": {"night": {"hemi": {"intensity": 1.4}, "key": {"intensity": 1.35},
                                             "exposureScale": 1.55}}},
        "terrain": terrain(),
        "ground": ground_paint(),
        "lights": lights(),
        "ambience": "woods",
        "dressing": dressing(),
        "areas": [{"name": n, "box": [r(x1), r(x2), r(z1), r(z2)]} for (n, x1, x2, z1, z2) in L.AREAS],
        "doors": doors(),
    }
    with open(OUT, "w") as f:
        json.dump(data, f, separators=(",", ":"))
        f.write("\n")
    kinds: dict[str, int] = {}
    for b in data["blocks"]:
        kinds[b["kind"]] = kinds.get(b["kind"], 0) + 1
    print("stockade.json: %d blocks %s, %d doors, %d lights, %d KB" % (
        len(data["blocks"]), kinds, len(data["doors"]), len(data["lights"]), os.path.getsize(OUT) // 1024))


if __name__ == "__main__":
    main()
