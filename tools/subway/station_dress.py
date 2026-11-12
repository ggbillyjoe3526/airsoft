"""Subway's station dress (MT3): `dressing.station` in data/maps/subway.json, which build_map.py writes. The game
draws each block face in the CC0 photo set its room's style gives it (game/config/station_look.gd), lays the
platforms' edge strips and the track's rails and sleepers (game/play/station/station_surface.gd). Look only: nothing
here adds, moves or cuts a block.

- zones: every room's air as boxes with its style; a ramp room's in slices SLICE m long, each from its floor's lowest
  there, so a face looking into the slope finds it. Rooms that own their blocks (the trains) come first.
- strips: each platform's edge as London's (owner, 2026-11-12: the yellow line only at the platforms' edges): a pale
  coping stone, MIND THE GAP painted on it every few metres, and the yellow line behind it.
- words: the painted words, along each platform's coping, reading from the platform.
- tracks: each line's centre through the track and tunnel rooms on the track bed.
- vaults: each platform tunnel's barrel vault (layout.VAULTS), drawn curved over its colliders' boxes.
"""
from __future__ import annotations

import sys

# Each area's style (StationLook.style_floors, style_walls, style_ceilings). An area not listed is a passage.
STYLES = {
    "Ticket hall": "hall", "Booking hall": "hall", "Concourse": "hall", "Stair top": "hall", "Lower hall": "hall",
    "Spiral stair": "passage", "West passage": "passage", "North passage": "passage", "South passage": "passage",
    "Stair": "passage", "Stair landing": "passage", "Mid passage": "passage", "East passage": "passage",
    "Lift landing": "passage", "Escalators": "escalator", "Low escalators": "escalator", "Plant room": "plant",
    "North platform": "platform", "South platform": "platform", "North track": "track", "South track": "track",
    "North train": "train", "South train": "train", "North tunnel": "tunnel", "South tunnel": "tunnel",
    "Cross passage": "service",
}
OWNS = {"train"}           # styles whose rooms draw the blocks inside them (a car's sides and ends)
SLICE = 1.0                # a ramp room's zone slices (m along x)
UNDER = 0.1                # each zone reaches this far under its floor
# The platforms' edges: the room and the side its track lies on; the coping and the tactile strip's widths (m).
EDGES = [("plat_n", "n"), ("plat_s", "s")]
COPING = 0.45
GAP_LINE = 0.1
# The words on the coping: the text, its letters' height (m, across the coping) and one every WORDS_EVERY m.
WORDS = "MIND THE GAP"
WORDS_HEIGHT = 0.24
WORDS_EVERY = 12.0
# The tracks' centre lines (z) and the areas whose rooms on the track bed carry them.
LINES = [(-10.75, ("North track", "North tunnel")), (10.75, ("South track", "South tunnel"))]


def r(v: float) -> float:
    return round(v + 0.0, 3)


def style_of(rm: dict) -> str:
    style = STYLES.get(rm["area"])
    if style is None:
        print(f"station_dress: area {rm['area']!r} has no style; drawn as a passage", file=sys.stderr)
        return "passage"
    return style


def zones(L, floor_at, ceil_at, lift: float) -> list[dict]:
    out = []
    for rm in L.rooms:
        style = style_of(rm)
        ramp = rm["ya"] != rm["yb"]
        cuts = [rm["x0"]]
        if ramp:
            n = max(1, round((rm["x1"] - rm["x0"]) / SLICE))
            cuts = [rm["x0"] + (rm["x1"] - rm["x0"]) * i / n for i in range(n)]
        cuts.append(rm["x1"])
        for a, b in zip(cuts, cuts[1:]):
            lo = min(floor_at(rm, a), floor_at(rm, b))
            hi = max(ceil_at(rm, floor_at(rm, a)), ceil_at(rm, floor_at(rm, b)))
            z = {"style": style, "box": [r(a), r(b), r(lo - UNDER + lift), r(hi + lift), rm["z0"], rm["z1"]]}
            if style in OWNS:
                z["owns"] = True
            out.append(z)
    out.sort(key=lambda z: 0 if z.get("owns") else 1)
    return out


def strips(L, lift: float) -> list[dict]:
    out = []
    by_name = {rm["name"]: rm for rm in L.rooms}
    for name, side in EDGES:
        rm = by_name[name]
        y = r(rm["ya"] + lift)
        edge = rm["z0"] if side == "n" else rm["z1"]
        inward = 1 if side == "n" else -1
        for finish, a, b in (("coping", 0.0, COPING), ("gap_line", COPING, COPING + GAP_LINE)):
            z0, z1 = sorted((edge + inward * a, edge + inward * b))
            out.append({"finish": finish, "x0": rm["x0"], "x1": rm["x1"], "z0": r(z0), "z1": r(z1), "y": y})
    return out


def tracks(L, lift: float) -> list[dict]:
    out = []
    for z, areas in LINES:
        spans = sorted((rm["x0"], rm["x1"]) for rm in L.rooms
                       if rm["area"] in areas and rm["ya"] == rm["yb"] == L.T and rm["z0"] < z < rm["z1"])
        merged: list[list[float]] = []
        for a, b in spans:
            if merged and a <= merged[-1][1] + 1e-6:
                merged[-1][1] = max(merged[-1][1], b)
            else:
                merged.append([a, b])
        for a, b in merged:
            out.append({"x0": a, "x1": b, "z0": r(z - 0.5), "z1": r(z + 0.5), "y": r(L.T + lift)})
    return out


def words(L, lift: float) -> list[dict]:
    """The words along each platform's coping: `up` the way their tops face (towards the track), so they read from
    the platform."""
    out = []
    by_name = {rm["name"]: rm for rm in L.rooms}
    for name, side in EDGES:
        rm = by_name[name]
        edge = rm["z0"] if side == "n" else rm["z1"]
        inward = 1 if side == "n" else -1
        z0, z1 = sorted((edge, edge + inward * COPING))
        out.append({"text": WORDS, "x0": rm["x0"], "x1": rm["x1"], "z0": r(z0), "z1": r(z1), "y": r(rm["ya"] + lift),
                    "height": WORDS_HEIGHT, "every": WORDS_EVERY, "up": -inward})
    return out


def vaults(L, lift: float, thick: float) -> list[dict]:
    return [{"x0": v["x0"], "x1": v["x1"], "z0": v["z0"], "z1": v["z1"], "y": r(v["y"] + lift), "rise": L.VAULT_RISE,
             "thick": thick} for v in L.VAULTS]


def dress(L, floor_at, ceil_at, lift: float, thick: float) -> dict:
    return {"zones": zones(L, floor_at, ceil_at, lift), "strips": strips(L, lift), "words": words(L, lift),
            "tracks": tracks(L, lift), "vaults": vaults(L, lift, thick)}
