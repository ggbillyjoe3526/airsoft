"""Writes data/maps/depot.json from tools/depot/layout.py (the layout as data). Run from anywhere:

    python3 tools/depot/build_map.py

Then rebake its light (`godot --headless --path . -s res://tools/bake_light.gd -- depot`) and re-render its card
(`tools/map_pictures.gd`, docs/ASSETS.md). The JSON is the map file the game reads (game/map/map_data.gd).
"""
from __future__ import annotations

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import layout as L  # noqa: E402

OUT = os.path.join(HERE, "..", "..", "data", "maps", "depot.json")

# The concept's piece kinds as the game's block kinds (game/config/map_style.gd).
KINDS = {"wall": "plywood", "hut": "plywood", "wardrobe": "plywood", "window": "plywood", "dead": "rack",
         "crates": "crate", "lowcrate": "crate", "desk": "crate", "drums": "drum", "barrels": "barrel",
         "pillar": "pillar", "net": "net", "sofa": "sofa", "container": "container", "lid": "rack"}
# A window or a container's port: solid under the sill and over the lintel.
SILL, LINTEL = 1.0, 2.0
EYE_FACING_EAST = -math.pi / 2  # yaw -90 degrees looks along +x
EYE_FACING_WEST = math.pi / 2


def r(v: float) -> float:
    return round(v, 3)


def block(kind: str, x1: float, y1: float, z1: float, x2: float, y2: float, z2: float) -> dict:
    return {"kind": kind, "center": {"x": r((x1 + x2) / 2), "y": r((y1 + y2) / 2), "z": r((z1 + z2) / 2)},
            "size": {"x": r(x2 - x1), "y": r(y2 - y1), "z": r(z2 - z1)}}


def blocks() -> list[dict]:
    out = [block("floor", -L.W, -0.5, -L.H, L.W, 0.0, L.H)]
    # The hall's shell, up to the roof.
    t = 0.5
    out.append(block("wall", -L.W - t, 0, -L.H - t, L.W + t, L.ROOF, -L.H))
    out.append(block("wall", -L.W - t, 0, L.H, L.W + t, L.ROOF, L.H + t))
    out.append(block("wall", -L.W - t, 0, -L.H, -L.W, L.ROOF, L.H))
    out.append(block("wall", L.W, 0, -L.H, L.W + t, L.ROOF, L.H))
    boxes: list[list] = []
    for p in L.pieces:
        k, x1, z1, x2, z2, h = p["kind"], p["x1"], p["z1"], p["x2"], p["z2"], p["h"]
        kind = KINDS[k]
        if k == "window":
            kind = "container" if p["tag"] == "port" else kind
            boxes.append([kind, x1, 0, z1, x2, SILL, z2])
            boxes.append([kind, x1, LINTEL, z1, x2, p["h"], z2])
        elif k == "lid":
            boxes.append([kind, x1, L.LID_H, z1, x2, L.LID_H + h, z2])
        elif p["tag"] == "boxroof":
            boxes.append([kind, x1, 2.6, z1, x2, 2.6 + h, z2])
        else:
            boxes.append([kind, x1, 0, z1, x2, h, z2])
    unseat(boxes)
    out.extend(block(*b) for b in boxes)
    return out


# Two blocks may share no more than this every way (FieldStandard.SEAM_SLACK is 0.025 m).
SEAM = 0.02


def _overlap(a: list, b: list, axis: int) -> float:
    return min(a[axis + 4], b[axis + 4]) - max(a[axis + 1], b[axis + 1])


def _trim_end(a: list, b: list, whole: bool) -> bool:
    """Shortens `a` along its long side to the face of `b` where `b` sits over one of its ends: walls meeting at a
    corner or a T, a lid over a tunnel's bend. With `whole`, only where `b` spans all of `a`'s width there, so the cut
    leaves no gap (a lid's bend, a wall's T). False when it can't."""
    axis = 0 if a[4] - a[1] >= a[6] - a[3] else 2
    across = 2 - axis
    if whole and (b[across + 1] > a[across + 1] + SEAM or b[across + 4] < a[across + 4] - SEAM):
        return False
    lo, hi = a[axis + 1], a[axis + 4]
    if b[axis + 1] <= lo + SEAM and b[axis + 4] < hi:
        a[axis + 1] = b[axis + 4]
        return True
    if b[axis + 4] >= hi - SEAM and b[axis + 1] > lo:
        a[axis + 4] = b[axis + 1]
        return True
    return False


def unseat(boxes: list[list]) -> None:
    """Two pieces drawn to the same line (two walls at a corner, a wall into a dead block, two lids at a tunnel's bend)
    overlap by half a thickness; each pair is cut back so they meet face to face (field.blocks)."""
    for i, a in enumerate(boxes):
        for b in boxes[:i]:
            if all(_overlap(a, b, k) > SEAM for k in range(3)):
                if not any(_trim_end(x, y, whole) for whole in (True, False) for x, y in ((a, b), (b, a))):
                    raise SystemExit(f"{a} and {b} cross: neither ends on the other")


def spot(x: float, z: float, yaw: float) -> dict:
    return {"position": {"x": r(x), "y": 0, "z": r(z)}, "yaw": yaw}


def dead_zone(cx: float, cz: float, yaw: float) -> list[dict]:
    """Six walk-off spots: two columns of three, 0.8 m apart, round (cx, cz)."""
    return [spot(cx + dx, cz + dz, yaw) for dz in (-0.8, 0.0, 0.8) for dx in (-0.4, 0.4)]


def areas() -> list[dict]:
    """Every zone as a named area, the rooms and lanes first so where a link overlaps one the room names it."""
    rooms = [z for z in L.zones if z["lane"] != "x"]
    links = [z for z in L.zones if z["lane"] == "x"]
    return [{"name": z["name"], "box": [z["x1"], z["x2"], z["z1"], z["z2"]]} for z in rooms + links]


def roof() -> dict:
    """The roof (look only): its height and its lamp panels, every 7 m over each lit room, none over the tunnels."""
    lamps = []
    for z in L.zones:
        if z["light"] == "dark" or z["lane"] == "x":
            continue
        step = 7.0 if z["light"] == "lit" else 10.0
        x = z["x1"] + 3.0
        while x < z["x2"] - 1.0:
            zz = z["z1"] + 3.0
            while zz < z["z2"] - 1.0:
                lamps.append({"x": r(x), "z": r(zz)})
                zz += step
            x += step
    return {"height": L.ROOF, "lamps": lamps}


def site() -> dict:
    lines = [{"x": 1.0, "z": z, "w": 25.2, "d": 0.12} for z in (-10.8, 6.6)]
    stencils = [
        {"area": "A site", "x": 30.16, "y": 1.9, "z": -28.0, "facing": "+x", "height": 0.7},
        {"area": "B site", "x": 32.16, "y": 1.9, "z": 26.0, "facing": "+x", "height": 0.7},
        {"area": "Shoot House", "x": -36.16, "y": 1.9, "z": -29.0, "facing": "-x", "height": 0.45},
        {"area": "Offices", "x": 16.5, "y": 1.9, "z": -25.84, "facing": "+z", "height": 0.45},
    ]
    return {"stencils": stencils, "lines": lines}


# A door's leaves (DO1): this thick (m), hung on one face of the wall (the +x or +z one, `side` 1) across its gap, as
# tall as the wall. Two leaves, each hinged at its jamb in the leaf's middle plane, so an open leaf folds back flat
# against the wall's face; each wall piece beside a gap is at least a leaf wide.
DOOR_T = 0.08


def doors() -> list[dict]:
    """The hinged doors, in the layout's order: each its shut leaves' box, the side it hangs on and whether it starts
    the round shut."""
    out = []
    off = L.T / 2 + DOOR_T / 2
    for d in L.DOORS:
        cx, cz = (d["x1"] + d["x2"]) / 2, (d["z1"] + d["z2"]) / 2
        if d["along_x"]:
            sx, sz, cz = d["x2"] - d["x1"], DOOR_T, cz + off
        else:
            sx, sz, cx = DOOR_T, d["z2"] - d["z1"], cx + off
        out.append({"center": {"x": r(cx), "y": r(d["h"] / 2), "z": r(cz)},
                    "size": {"x": r(sx), "y": r(d["h"]), "z": r(sz)}, "side": 1, "shut": d["state"] == "shut"})
    return out


def build() -> dict:
    return {
        "name": "Depot",
        "blocks": blocks(),
        "killY": -10,
        "spawns": [[spot(x, z, EYE_FACING_EAST) for x, z in L.SPAWNS_W],
                   [spot(x, z, EYE_FACING_WEST) for x, z in L.SPAWNS_E]],
        "deadZones": [dead_zone(*L.DEAD_W, EYE_FACING_EAST), dead_zone(*L.DEAD_E, EYE_FACING_WEST)],
        "lanes": [[{"x": x, "y": 0, "z": z} for x, z in L.LANES[k]] for k in ("n", "m", "s")],
        "flags": [{"x": x, "y": 0, "z": z} for x, z in L.FLAGS],
        "overtimeFlag": {"x": L.OT_FLAG[0], "y": 0, "z": L.OT_FLAG[1]},
        "botSight": 55,
        "roof": roof(),
        "doors": doors(),
        "lighting": {"presets": ["day"], "overrides": {"day": {
            "key": {"elevation": 76, "heading": 25, "intensity": 1.1}, "hemi": {"intensity": 0.55}}}},
        "bakedLight": {"file": "depot"},
        # The yard's dust: motes in the lamps' light and the grey puff feet kick up off the slab.
        "dressing": {"seed": 4127, "motes": {"tint": 14210767}, "kickedDust": {"tint": 12171184, "scale": 1},
                     "site": site()},
        "areas": areas(),
    }


if __name__ == "__main__":
    data = build()
    with open(OUT, "w") as f:
        json.dump(data, f, indent=1)
        f.write("\n")
    print(f"{os.path.relpath(OUT)}: {len(data['blocks'])} blocks, {len(data['areas'])} areas, "
          f"{len(data['roof']['lamps'])} lamps, {len(data['doors'])} doors")
