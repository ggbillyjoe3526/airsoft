"""Writes data/maps/subway.json from tools/subway/layout.py (the layout as data). Run from anywhere:

    python3 tools/subway/build_map.py

The rooms become the station's shell: a floor slab under each (a ramp room's floor as wedges a SEG m long), a
ceiling over it, and a wall along every edge that opens into no other room, lintels and risers where two rooms of
different heights meet. Every shell box is then cut back out of every room's air, and no box is left inside another.
The lift shafts (layout.SHAFT, MT2) are cut out of the shell whole and walled, a door at each stop; their cars are
the map's `lifts`, which the game moves.
The JSON is the map file the game reads (game/map/map_data.gd).
"""
from __future__ import annotations

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import layout as L  # noqa: E402
import fixtures  # noqa: E402
import station_dress  # noqa: E402

OUT = os.path.join(HERE, "..", "..", "data", "maps", "subway.json")
LIFT = -L.T          # the track bed is the game's floor at 0
FT = 0.3             # slab and wall thickness
SEAL_T = 0.15        # a sealed edge's wall (a train's side, the spiral's well), inside its room
OPEN = 1.9           # rooms whose air overlaps this much along a shared edge open into each other
SEG = 2.0            # a ramp room's floor and ceiling in pieces this long
EPS = 1e-6
SLACK = 0.02         # boxes overlapping less than this on an axis don't clash
GROW = 0.01          # each floor and ramp grown this much a side
EYE_FACING_EAST = -math.pi / 2
EYE_FACING_WEST = math.pi / 2
SHAFT_COLOUR = 0x9c978d   # the shafts' walls, as MT1's shut shaft
HEMI_SKY = 0xdfe6ec       # the fill's colours (sRGB, LightingConfig.override_fill_*): a cool white, no warm bounce
HEMI_GROUND = 0xc9cdd0


def r(v: float) -> float:
    return round(v + 0.0, 3)


# ---------------- Room geometry ----------------

def floor_at(rm: dict, x: float) -> float:
    if rm["ya"] == rm["yb"]:
        return rm["ya"]
    t = (x - rm["x0"]) / (rm["x1"] - rm["x0"])
    return rm["ya"] + (rm["yb"] - rm["ya"]) * min(1.0, max(0.0, t))


def is_ramp(rm: dict) -> bool:
    return rm["ya"] != rm["yb"]


def floor_span(rm: dict, a: float, b: float, axis: str) -> tuple[float, float]:
    """The room's floor's lowest and highest over [a, b] along `axis` (x or z)."""
    if axis == "z" or not is_ramp(rm):
        if axis == "z" and is_ramp(rm):
            raise ValueError("a z edge piece of a ramp room needs its x")
        return rm["ya"], rm["ya"]
    fa, fb = floor_at(rm, a), floor_at(rm, b)
    return min(fa, fb), max(fa, fb)


def edge_floor(rm: dict, edge: str, a: float, b: float) -> tuple[float, float]:
    """Floor low and high along an edge piece: on a ramp's n/s edges it varies with x, on w/e it is the end's."""
    if edge in "ns":
        return floor_span(rm, a, b, "x")
    x = rm["x0"] if edge == "w" else rm["x1"]
    f = floor_at(rm, x)
    return f, f


def ceil_at(rm: dict, f: float) -> float:
    """The ceiling's underside over floor height `f`: `h` over it, or a ramp's level ceiling (`flat`) at `h` over its
    higher end."""
    return max(rm["ya"], rm["yb"]) + rm["h"] if rm.get("flat") else f + rm["h"]


def air_boxes(rm: dict) -> list[list[float]]:
    """The room's air as boxes [x0, x1, y0, y1, z0, z1]: one for a flat room, a slab of each 1 m of a ramp (from its
    floor's highest to its ceiling's lowest there)."""
    if not is_ramp(rm):
        return [[rm["x0"], rm["x1"], rm["ya"], rm["ya"] + rm["h"], rm["z0"], rm["z1"]]]
    out = []
    n = max(1, round((rm["x1"] - rm["x0"]) / 1.0))
    for i in range(n):
        a = rm["x0"] + (rm["x1"] - rm["x0"]) * i / n
        b = rm["x0"] + (rm["x1"] - rm["x0"]) * (i + 1) / n
        lo, hi = floor_span(rm, a, b, "x")
        out.append([a, b, hi, ceil_at(rm, lo), rm["z0"], rm["z1"]])
    return out


# ---------------- Box helpers ----------------

def overlap(a: list[float], b: list[float], slack: float = EPS) -> bool:
    return all(min(a[2 * k + 1], b[2 * k + 1]) - max(a[2 * k], b[2 * k]) > slack for k in range(3))


def subtract(a: list[float], b: list[float]) -> list[list[float]]:
    """Box a minus box b, as up to six boxes."""
    if not overlap(a, b):
        return [a]
    out = []
    rest = list(a)
    for k in range(3):
        lo, hi = 2 * k, 2 * k + 1
        if b[lo] > rest[lo] + EPS:
            piece = list(rest)
            piece[hi] = b[lo]
            out.append(piece)
            rest[lo] = b[lo]
        if b[hi] < rest[hi] - EPS:
            piece = list(rest)
            piece[lo] = b[hi]
            out.append(piece)
            rest[hi] = b[hi]
    return [p for p in out if all(p[2 * k + 1] - p[2 * k] > 0.01 for k in range(3))]


def cut(boxes: list[list[float]], holes: list[list[float]]) -> list[list[float]]:
    for h in holes:
        nxt = []
        for bx in boxes:
            nxt.extend(subtract(bx, h))
        boxes = nxt
    return boxes


# ---------------- The shell ----------------

def edge_line(rm: dict, edge: str) -> tuple[str, float, float, float]:
    """(axis the edge runs along, its fixed coordinate, its start, its end)."""
    if edge == "n":
        return "x", rm["z0"], rm["x0"], rm["x1"]
    if edge == "s":
        return "x", rm["z1"], rm["x0"], rm["x1"]
    if edge == "w":
        return "z", rm["x0"], rm["z0"], rm["z1"]
    return "z", rm["x1"], rm["z0"], rm["z1"]


OPPOSITE = {"n": "s", "s": "n", "w": "e", "e": "w"}


def neighbours(i: int, edge: str) -> list[tuple[int, float, float]]:
    """The rooms touching room i's edge from outside, with the stretch of the edge each covers."""
    rm = L.rooms[i]
    axis, at, a, b = edge_line(rm, edge)
    out = []
    for j, other in enumerate(L.rooms):
        if j == i:
            continue
        o_axis, o_at, oa, ob = edge_line(other, OPPOSITE[edge])
        if abs(o_at - at) > EPS:
            continue
        lo, hi = max(a, oa), min(b, ob)
        if hi - lo > EPS:
            out.append((j, lo, hi))
    return out


def pieces_of(a: float, b: float, cuts: list[float]) -> list[tuple[float, float]]:
    pts = sorted({a, b, *[c for c in cuts if a + EPS < c < b - EPS]})
    return [(pts[k], pts[k + 1]) for k in range(len(pts) - 1)]


def in_gap(gaps: list[tuple[float, float]], a: float, b: float) -> bool:
    return any(g0 - EPS <= a and b <= g1 + EPS for g0, g1 in gaps)


def wall_box(rm: dict, edge: str, a: float, b: float, y0: float, y1: float, inside: bool,
             thick: float = FT) -> list[float]:
    axis, at, _, _ = edge_line(rm, edge)
    outward = {"n": -1, "w": -1, "s": 1, "e": 1}[edge]
    d = -outward if inside else outward
    c0, c1 = sorted((at, at + d * thick))
    if axis == "x":
        return [a, b, y0, y1, c0, c1]
    return [c0, c1, y0, y1, a, b]


def ramp_cells(rm: dict) -> list[tuple[float, float]]:
    """A ramp room's length in 1 m cells, each with a ceiling step of its own."""
    n = max(1, round((rm["x1"] - rm["x0"]) / 1.0))
    return [(rm["x0"] + (rm["x1"] - rm["x0"]) * k / n, rm["x0"] + (rm["x1"] - rm["x0"]) * (k + 1) / n)
            for k in range(n)]


def ceil_under(rm: dict, a: float, b: float) -> float:
    """A ramp cell's ceiling's underside: its room's height over the cell's highest floor."""
    return floor_span(rm, a, b, "x")[1] + rm["h"]


def ceil_over(rm: dict, a: float, b: float) -> float:
    """A ramp cell's ceiling's top: a slab over its underside and down to the next step's, closing the riser."""
    lo, hi = floor_span(rm, a, b, "x")
    return hi + rm["h"] + FT + (hi - lo)


def barriers_in(rm: dict) -> list[tuple[float, float]]:
    """The z stretches of the balustrades down ramp room `rm` (blocks with no level)."""
    return sorted((b["z0"], b["z1"]) for b in L.blocks if b["y"] is None and rm["x0"] - EPS <= b["x0"]
                  and b["x1"] <= rm["x1"] + EPS and rm["z0"] <= b["z0"] and b["z1"] <= rm["z1"])


def z_pieces(rm: dict) -> list[tuple[float, float]]:
    """The ramp room's width, less its balustrades."""
    out, at = [], rm["z0"]
    for a, b in barriers_in(rm):
        if a > at + EPS:
            out.append((at, a))
        at = b
    if rm["z1"] > at + EPS:
        out.append((at, rm["z1"]))
    return out


def shell() -> tuple[list[tuple[list[float], int, str]], list[dict]]:
    """Every shell box with the room it may stand inside (a sealed room's own walls; -1 none) and its kind (a floor
    is walked on; a ceiling or a wall is not, so the bots' grid never takes a ceiling's top for a floor), and the
    ramps."""
    boxes: list[tuple[list[float], int, str]] = []
    ramps: list[dict] = []
    warnings: list[str] = []
    for i, rm in enumerate(L.rooms):
        # The floor: down to the lowest floor it opens onto (a platform's edge over the track).
        if rm["floor"]:
            low = min(rm["ya"], rm["yb"])
            for edge in "nsew":
                for j, lo, hi in neighbours(i, edge):
                    nf, _ = edge_floor(L.rooms[j], OPPOSITE[edge], lo, hi)
                    if nf < low - EPS and nf > low - 1.5:
                        low = nf
            if is_ramp(rm):
                n = max(1, round((rm["x1"] - rm["x0"]) / SEG))
                for k in range(n):
                    a = rm["x0"] + (rm["x1"] - rm["x0"]) * k / n
                    b = rm["x0"] + (rm["x1"] - rm["x0"]) * (k + 1) / n
                    fa, fb = floor_at(rm, a), floor_at(rm, b)
                    for z0, z1 in z_pieces(rm):
                        ramps.append(dict(x0=a, x1=b, z0=z0, z1=z1, y0=min(fa, fb), y1=max(fa, fb),
                                          rise="+x" if fb > fa else "-x", dress=rm.get("dress", "")))
            else:
                boxes.append(([rm["x0"], rm["x1"], low - FT, rm["ya"], rm["z0"], rm["z1"]], -1, "floor"))
        # The ceiling, a ramp's stepped down with it (each step closing the riser to the one above); a vault room's
        # is its platform tunnel's vault (vault_boxes).
        if rm["ceil"] and not rm["vault"]:
            if is_ramp(rm) and rm.get("flat"):
                y = ceil_at(rm, 0.0)
                boxes.append(([rm["x0"], rm["x1"], y, y + FT, rm["z0"], rm["z1"]], -1, "wall"))
            elif is_ramp(rm):
                for a, b in ramp_cells(rm):
                    boxes.append(([a, b, ceil_under(rm, a, b), ceil_over(rm, a, b), rm["z0"], rm["z1"]], -1,
                                  "wall"))
            else:
                y = rm["ya"] + rm["h"]
                boxes.append(([rm["x0"], rm["x1"], y, y + FT, rm["z0"], rm["z1"]], -1, "wall"))
        # The walls, edge by edge.
        for edge in "nsew":
            axis, at, a, b = edge_line(rm, edge)
            nbs = neighbours(i, edge)
            cuts = [c for _, lo, hi in nbs for c in (lo, hi)]
            gaps = rm["seal"].get(edge)
            sealed = gaps is not None
            if sealed:
                cuts += [c for g in gaps for c in g]
            if axis == "x" and is_ramp(rm):
                n = max(1, round((b - a) / 1.0))
                cuts += [a + (b - a) * k / n for k in range(1, n)]
            for pa, pb in pieces_of(a, b, cuts):
                f_lo, f_hi = edge_floor(rm, edge, pa, pb)
                c_lo, c_hi = ceil_at(rm, f_lo), ceil_at(rm, f_hi)
                top = c_hi if rm["vault"] else c_hi + FT if rm["ceil"] else c_hi - 0.01
                if rm["ceil"] and is_ramp(rm) and not rm.get("flat") and edge in "ns":
                    # Up to the stepped ceiling's top over this stretch, so no gap opens between them.
                    ca, cb = next(c for c in ramp_cells(rm) if c[0] - EPS <= (pa + pb) / 2 <= c[1] + EPS)
                    top = max(top, ceil_over(rm, ca, cb))
                bottom = f_lo - FT
                nb = next(((j, lo, hi) for j, lo, hi in nbs if lo - EPS <= pa and pb <= hi + EPS), None)
                # Stretch the ends of the edge by a wall's thickness to close the room's corners.
                ea = pa - (FT if abs(pa - a) < EPS else 0.0)
                eb = pb + (FT if abs(pb - b) < EPS else 0.0)
                if sealed and not in_gap(gaps, pa, pb):
                    boxes.append((wall_box(rm, edge, pa, pb, bottom, top, True, SEAL_T), i, "wall"))
                    continue
                if nb is None:
                    if not sealed:
                        boxes.append((wall_box(rm, edge, ea, eb, bottom, top, False), -1, "wall"))
                    continue
                j = nb[0]
                other = L.rooms[j]
                of_lo, of_hi = edge_floor(other, OPPOSITE[edge], pa, pb)
                oc_lo = ceil_at(other, of_lo)
                o_gaps = other["seal"].get(OPPOSITE[edge])
                o_sealed = o_gaps is not None and not in_gap(o_gaps, pa, pb)
                open_lo, open_hi = max(f_hi, of_hi), min(c_lo, oc_lo)
                thick = SEAL_T if o_gaps is not None else FT
                if open_hi - open_lo < OPEN and not o_sealed:
                    if open_hi - open_lo > 0.05:
                        warnings.append(f"{rm['name']} and {other['name']} overlap {open_hi - open_lo:.2f} m at "
                                        f"{edge} {pa:.1f}..{pb:.1f}: walled")
                    boxes.append((wall_box(rm, edge, pa, pb, bottom, top, False, thick), -1, "wall"))
                    continue
                if o_sealed:
                    # A sealed neighbour (a train's side) walls itself in: open to this room's floor, up to the lower
                    # ceiling, with the lintel over it (the tunnel's wall down to a car's roof).
                    open_lo, open_hi = f_hi, min(c_lo, oc_lo)
                # Risers under the opening and lintels over it.
                # A riser only where the neighbour's floor stands higher (its own slab is the rest), its top a floor.
                if open_lo - f_hi > 0.01 and not is_ramp(other):
                    boxes.append((wall_box(rm, edge, pa, pb, bottom, open_lo, False, thick),
                                  j if thick == SEAL_T else -1, "floor"))
                if top - open_hi > 0.01:
                    boxes.append((wall_box(rm, edge, pa, pb, open_hi, top, False, thick),
                                  j if thick == SEAL_T else -1, "wall"))
    for w in warnings:
        print("warning:", w)
    return boxes, ramps


def spiral() -> tuple[list[dict], list[list[float]]]:
    """The spiral stair (layout.SPIRAL): a square well, flights round a core, each side a ramp, a landing at each
    corner; the core runs up to the hall's ceiling."""
    s = L.SPIRAL
    x0, x1, z0, z1 = s["x0"] + SEAL_T, s["x1"] - SEAL_T, s["z0"] + SEAL_T, s["z1"] - SEAL_T
    f = s["flight"]
    rise = (s["y1"] - s["y0"]) / s["sides"]
    corners = {"se": (x1 - f, x1, z1 - f, z1), "sw": (x0, x0 + f, z1 - f, z1),
               "nw": (x0, x0 + f, z0, z0 + f), "ne": (x1 - f, x1, z0, z0 + f)}
    sides = [("s", (x0 + f, x1 - f, z1 - f, z1), "-x", "sw"), ("w", (x0, x0 + f, z0 + f, z1 - f), "-z", "nw"),
             ("n", (x0 + f, x1 - f, z0, z0 + f), "+x", "ne"), ("e", (x1 - f, x1, z0 + f, z1 - f), "+z", "se")]
    ramps, boxes = [], []
    for k in range(s["sides"]):
        _, (a, b, c, d), way, corner = sides[k % 4]
        y = s["y0"] + rise * k
        ramps.append(dict(x0=a, x1=b, z0=c, z1=d, y0=y, y1=y + rise, rise=way, dress=s.get("dress", "")))
        ca, cb, cc, cd = corners[corner]
        top = y + rise
        boxes.append([ca, cb, top - FT, top, cc, cd])
    boxes.append([x0 + f, x1 - f, s["y0"], s["y1"] + s["top"], z0 + f, z1 - f])  # the core
    return ramps, boxes


# ---------------- The platform tunnels' vaults ----------------

VAULT_PROUD = 0.08   # a vault's collider boxes stand at most this far (m) in front of its drawn arc


def vault_circle(v: dict) -> tuple[float, float, float]:
    """A vault's arc: the circle (its middle's z and y, its radius) through both springings and the crown."""
    half = (v["z1"] - v["z0"]) / 2
    radius = (half * half + L.VAULT_RISE * L.VAULT_RISE) / (2 * L.VAULT_RISE)
    return (v["z0"] + v["z1"]) / 2, v["y"] + L.VAULT_RISE - radius, radius


def vault_y(v: dict, z: float) -> float:
    """The vault's underside over z (its springing's height at or past a wall)."""
    zc, yc, radius = vault_circle(v)
    d = min(abs(z - zc), (v["z1"] - v["z0"]) / 2)
    return yc + math.sqrt(radius * radius - d * d)


def vault_top(v: dict) -> float:
    return v["y"] + L.VAULT_RISE + FT


def vault_air(v: dict) -> list[float]:
    """The air a vault holds: its tunnel from a car's roof up, cut out of the shell (the lintels over a car)."""
    return [v["x0"], v["x1"], v["low"] + FT, vault_top(v), v["z0"], v["z1"]]


def vault_pieces(v: dict) -> list[tuple[float, float]]:
    """The arc's points (z, y) from one springing to the other, each piece as long as its bounds' corner inside the arc
    (at the lower end's height and the z nearest the crown's) stays within VAULT_PROUD of it: short
    pieces where the arc is steep, long ones over the crown."""
    zc, yc, radius = vault_circle(v)
    alpha = math.asin((v["z1"] - v["z0"]) / 2 / radius)

    def point(a: float) -> tuple[float, float]:
        return zc + radius * math.sin(a), yc + radius * math.cos(a)

    def proud(a: float, b: float) -> float:
        (za, ya), (zb, yb) = point(a), point(b)
        inner = zc if (za - zc) * (zb - zc) < 0 else za if abs(za - zc) < abs(zb - zc) else zb
        return radius - math.hypot(inner - zc, min(ya, yb) - yc)

    out = [point(-alpha)]
    a = -alpha
    while a < alpha - EPS:
        lo, hi = 0.0, alpha - a
        if proud(a, a + hi) > VAULT_PROUD:
            for _ in range(40):
                mid = (lo + hi) / 2
                lo, hi = (mid, hi) if proud(a, a + mid) <= VAULT_PROUD else (lo, mid)
            hi = lo
        a += hi
        out.append(point(a))
    return out


def vault_boxes(v: dict) -> list[list[float]]:
    """A vault's colliders: each arc piece's bounds up to the vault's top, which sit on the drawn arc (never short of
    it, at most VAULT_PROUD in front of it: vault_pieces); its walls from a car's roof up to the springing (the
    trackside wall over a car); and its ends, under the springing and over it."""
    top = vault_top(v)
    low = v["low"] + FT
    out = []
    pts = vault_pieces(v)
    for (za, ya), (zb, yb) in zip(pts, pts[1:]):
        out.append([v["x0"], v["x1"], min(ya, yb), top, min(za, zb), max(za, zb)])
    out.append([v["x0"] - FT, v["x1"] + FT, low, v["y"], v["z0"] - FT, v["z0"]])
    out.append([v["x0"] - FT, v["x1"] + FT, low, v["y"], v["z1"], v["z1"] + FT])
    for xa, xb in ((v["x0"] - FT, v["x0"]), (v["x1"], v["x1"] + FT)):
        out.append([xa, xb, low, v["y"], v["z0"], v["z1"]])
        out.append([xa, xb, v["y"], top, v["z0"], v["z1"]])
    return [[r(c) for c in bx] for bx in out]


def ramp_barrier(bl: dict) -> list[tuple[list[float], str]]:
    """A balustrade down an escalator (`y` None), SEG m at a time: a box `h` m tall from the floor's low end, and on
    it a wedge rising with the floor, so its top runs `h` m over the floor all the way."""
    rm = next(r_ for r_ in L.rooms if is_ramp(r_) and r_["x0"] <= bl["x0"] + EPS and bl["x1"] <= r_["x1"] + EPS
              and r_["z0"] <= bl["z0"] and bl["z1"] <= r_["z1"])
    out = []
    n = max(1, round((bl["x1"] - bl["x0"]) / SEG))
    for k in range(n):
        a = bl["x0"] + (bl["x1"] - bl["x0"]) * k / n
        b = bl["x0"] + (bl["x1"] - bl["x0"]) * (k + 1) / n
        fa, fb = floor_at(rm, a), floor_at(rm, b)
        lo, hi = min(fa, fb), max(fa, fb)
        out.append(([a, b, lo, lo + bl["h"], bl["z0"], bl["z1"]], ""))
        out.append(([a, b, lo + bl["h"], hi + bl["h"], bl["z0"], bl["z1"]], "+x" if fb > fa else "-x"))
    return out


def shaft_hole() -> list[float]:
    """The lift shafts' whole volume, walls and all: nothing of the shell stands in it."""
    s = L.SHAFT
    return [s["x0"], s["x1"], L.P - s["pit"] - FT, s["top"], s["z0"], s["z1"]]


def shaft_boxes() -> list[tuple[list[float], str]]:
    """The shafts' walls (north, south, west, east and a partition between each two wells), each car's door cut out of
    the north wall at every stop, and the pit's floor under the lowest stop (a wall's kind: the bots' grid walks no
    floor in a shaft, MT2)."""
    s, t = L.SHAFT, L.SHAFT_T
    y0, y1 = L.P - s["pit"] - FT, s["top"]
    walls = [[s["x0"], s["x1"], y0, y1, s["z0"], s["z0"] + t], [s["x0"], s["x1"], y0, y1, s["z1"] - t, s["z1"]],
             [s["x0"], s["x0"] + t, y0, y1, s["z0"] + t, s["z1"] - t],
             [s["x1"] - t, s["x1"], y0, y1, s["z0"] + t, s["z1"] - t]]
    for a, b in zip(L.LIFTS, L.LIFTS[1:]):
        walls.append([a["x1"], b["x0"], y0 + FT, y1, s["z0"] + t, s["z1"] - t])  # on the pit's floor
    doors = []
    for lf in L.LIFTS:
        mid = (lf["x0"] + lf["x1"]) / 2
        for y in L.LIFT_STOPS:
            doors.append([mid - L.LIFT_DOOR_W / 2, mid + L.LIFT_DOOR_W / 2, y, y + L.LIFT_DOOR_H, s["z0"], s["z0"] + t])
    out = [(p, "wall") for p in cut(walls, doors)]
    out.append(([s["x0"] + t, s["x1"] - t, y0, y0 + FT, s["z0"] + t, s["z1"] - t], "wall"))
    return out


def lifts() -> list[dict]:
    """The cars (MT2): each one's well inside the shaft's walls, its door on the north face, its stops' floor heights
    and names, the stop it waits at as each round starts."""
    s, t = L.SHAFT, L.SHAFT_T
    out = []
    for lf in L.LIFTS:
        mid = (lf["x0"] + lf["x1"]) / 2
        out.append({"name": lf["name"],
                    "well": {"x0": lf["x0"], "x1": lf["x1"], "z0": r(s["z0"] + t), "z1": r(s["z1"] - t)},
                    "door": {"face": "n", "from": r(mid - L.LIFT_DOOR_W / 2), "to": r(mid + L.LIFT_DOOR_W / 2),
                             "height": L.LIFT_DOOR_H},
                    "stops": [r(y + LIFT) for y in L.LIFT_STOPS], "stopNames": L.LIFT_STOP_NAMES,
                    "start": L.LIFT_STOPS.index(lf["start"])})
    return out


# ---------------- Writing ----------------

def as_block(kind: str, bx: list[float], rise: str = "", colour: int = 0, dress: str = "") -> dict:
    x0, x1, y0, y1, z0, z1 = bx
    if kind in ("floor", "ramp"):
        # Floors drawn edge to edge are grown a centimetre a side to meet (as Depot's): an edge on a grid cell's middle
        # never leaves the bots' grid a row of cells with no floor.
        x0, x1, z0, z1 = x0 - GROW, x1 + GROW, z0 - GROW, z1 + GROW
    b = {"kind": kind, "center": {"x": r((x0 + x1) / 2), "y": r((y0 + y1) / 2 + LIFT), "z": r((z0 + z1) / 2)},
         "size": {"x": r(x1 - x0), "y": r(y1 - y0), "z": r(z1 - z0)}}
    if rise:
        b["rise"] = rise
    if colour:
        b["colour"] = colour
    if dress:
        b["dress"] = dress
    return b


def floor_y(x: float, z: float, near: float) -> float:
    """The floor under (x, z) nearest the height `near` (concept levels): a room's, or the spiral's."""
    best = None
    for rm in L.rooms:
        if rm["x0"] - EPS <= x <= rm["x1"] + EPS and rm["z0"] - EPS <= z <= rm["z1"] + EPS and rm["floor"]:
            y = floor_at(rm, x)
            if best is None or abs(y - near) < abs(best - near):
                best = y
    if best is None:
        raise ValueError(f"no floor under {x}, {z}")
    return best


def spot(x: float, z: float, y: float, yaw: float) -> dict:
    return {"position": {"x": x, "y": r(floor_y(x, z, y) + LIFT), "z": z}, "yaw": yaw}


def build() -> dict:
    shell_boxes, ramps = shell()
    sp_ramps, sp_boxes = spiral()
    ramps = sp_ramps + ramps
    blocks: list[dict] = []
    solid: list[list[float]] = []
    # The ramps first (never cut), then the cover, then the shell cut out of every room's air and of what stands.
    for rp in ramps:
        bx = [rp["x0"], rp["x1"], rp["y0"], rp["y1"], rp["z0"], rp["z1"]]
        blocks.append(as_block("ramp", bx, rp["rise"], dress=rp.get("dress", "")))
        solid.append(bx)
    for bx in sp_boxes:
        # The landings take the spiral's model (SM2); the core stays the station's tiled pillar.
        kind = "pillar" if bx[3] - bx[2] > 3 else "floor"
        blocks.append(as_block(kind, bx, dress=L.SPIRAL.get("dress", "") if kind == "floor" else ""))
        solid.append(bx)
    for bl in L.blocks:
        if bl["y"] is None:
            for bx, rise in ramp_barrier(bl):
                blocks.append(as_block(bl["kind"], bx, rise, colour=bl["colour"], dress=bl["dress"]))
                solid.append(bx)
            continue
        bx = [bl["x0"], bl["x1"], bl["y"], bl["y"] + bl["h"], bl["z0"], bl["z1"]]
        for other in solid:
            if overlap(bx, other, SLACK):
                print("warning: cover", bl["kind"], bx, "overlaps", other)
        blocks.append(as_block(bl["kind"], bx, colour=bl["colour"], dress=bl["dress"]))
        solid.append(bx)
    air = [(i, a) for i, rm in enumerate(L.rooms) for a in air_boxes(rm)]
    shaft = shaft_hole()
    for bx in solid:
        if overlap(bx, shaft, SLACK):
            print("warning: a ramp or cover", bx, "stands in the lift shafts")
    for bx, kind in shaft_boxes():
        blocks.append(as_block(kind, bx, colour=SHAFT_COLOUR))
        solid.append(bx)
    vaults = [vault_air(v) for v in L.VAULTS]
    for bx, owner, kind in shell_boxes:
        holes = [a for i, a in air if i != owner] + [shaft] + vaults
        parts = cut([bx], holes)
        parts = cut(parts, [s for s in solid if overlap(s, bx)])
        for p in parts:
            blocks.append(as_block(kind, p))
            solid.append(p)
    # The vaults over the platform tunnels, round the shell already standing and clear of every room's air.
    for v in L.VAULTS:
        for bx in vault_boxes(v):
            parts = cut(cut([bx], [a for _, a in air]), [s for s in solid if overlap(s, bx)])
            for p in parts:
                blocks.append(as_block("wall", p))
                solid.append(p)
    # The cover must stand clear of every room's walls: none inside another's air but its own room's.
    sx = L.SPIRAL
    m = {
        "name": "Subway",
        "blocks": blocks,
        "killY": -5,
        "storeys": [0, r(L.C + LIFT), r(L.G + LIFT)],
        "spawns": [[spot(x, z, L.G, EYE_FACING_EAST) for x, z in L.SPAWNS_W],
                   [spot(x, z, L.T, EYE_FACING_WEST) for x, z in L.SPAWNS_E]],
        "deadZones": [[spot(x, z, L.G, EYE_FACING_EAST) for x, z in L.DEAD_W],
                      [spot(x, z, L.T, EYE_FACING_WEST) for x, z in L.DEAD_E]],
        "lanes": [[lane_point(*p) for p in L.LANES[k]] for k in ("n", "m", "s")],
        "flags": [{"x": x, "y": r(y + LIFT), "z": z} for x, z, y in L.FLAGS],
        "overtimeFlag": {"x": L.OT_FLAG[0], "y": r(L.OT_FLAG[2] + LIFT), "z": L.OT_FLAG[1]},
        "botSight": 50,
        "poleHeight": L.POLE_HEIGHT,
        "ambience": "tunnel",  # his tunnel recording (2026-11-11)
        # Depot's overhead light: the lamps' stand-in on Low and Medium (RoofConfig); the fill a cool white, as a
        # station's fluorescent tubes light white tiles (owner, 2026-11-12: "a more white/grey look", TB1).
        "lighting": {"presets": ["day"], "overrides": {"day": {"key": {"elevation": 76, "heading": 25, "intensity": 1.1},
                                                             "hemi": {"intensity": 0.55, "sky": HEMI_SKY,
                                                                      "ground": HEMI_GROUND},
                                                             "exposureScale": 0.85}}},
        "roof": {"height": r(max(ceil_at(rm, max(rm["ya"], rm["yb"])) for rm in L.rooms if rm["ceil"]) + FT + ROOF_OVER
                             + LIFT), "plain": True,
                 # UL1: no sky down here; the sun standing in for the lamps (Low, Medium) casts no shadow.
                 "underground": True, "lamps": lamps()},
        "areas": areas(),
        "lifts": lifts(),
        # UL1: the grey puff feet kick up off the station's dusty floors (white without a tint).
        "dressing": {"station": station_dress.dress(L, floor_at, ceil_at, LIFT, FT),
                     "kickedDust": {"tint": 0xB0AEA8, "scale": 0.9}},
    }
    # nothing in the shafts, nor in a balustrade down an escalator (its pieces' whole boxes, as the game's tests take them)
    holes = [shaft_hole()] + [box for bl in L.blocks if bl["y"] is None for box, _ in ramp_barrier(bl)]
    m["dressing"]["station"]["fixtures"] = fixtures.place(L, floor_at, ceil_at, air_boxes, LIFT, holes)
    m["dressing"]["station"]["trims"] += drop_rods(m["dressing"]["station"]["fixtures"])
    del sx
    return m


LAMP_STEP = 8.0      # m between a room's ceiling lamps along it
LAMP_ROOM_MIN = 3.0  # a smaller room (a doorway, a short flight) is lit by its neighbours' lamps
LAMP_ROWS_OVER = 8.0  # a room wider than this gets two rows of lamps
ROOF_OVER = 0.4      # the roof's height (m) over the highest ceiling's top: an unseen lid; its lamps hang lower
ROD = 0.025            # a drop rod's half thickness (m)
ROD_IN = 0.15          # each rod in from its hung model's end
ROD_INTO = 0.05        # and run this far up into the arc, hidden behind it


def drop_rods(placed: list[dict]) -> list[dict]:
    """Two look-only rods (trims) holding each model hung under a vault (fixtures.VAULT_DROP), from its top up into
    the arc over each rod (TB1 x SM5: the platforms' departure boards)."""
    out = []
    for f in placed:
        b, how = fixtures.MODELS[f["model"]]
        y = f["y"] - LIFT
        v = next((v for v in L.VAULTS if v["x0"] <= f["x"] <= v["x1"] and v["z0"] <= f["z"] <= v["z1"]
                  and v["y"] - fixtures.VAULT_DROP - EPS <= y < v["y"]), None)
        if how != "hung" or v is None:
            continue
        c, s = math.cos(math.radians(f["yaw"])), math.sin(math.radians(f["yaw"]))
        for px in (b[0] + ROD_IN, b[1] - ROD_IN):
            x, z = f["x"] + px * c, f["z"] - px * s
            top = vault_y(v, z) + ROD_INTO + LIFT
            out.append({"finish": "steel", "box": [r(x - ROD), r(x + ROD), r(f["y"]), r(top), r(z - ROD), r(z + ROD)]})
    return out


LAMP_HALF_DEPTH = 0.3  # a lamp panel's half depth (RoofConfig.lamp_size.y) and a little: hung clear of a vault


def vault_of(rm: dict) -> dict | None:
    """The vault over a vault room (the one whose tunnel holds it)."""
    if not rm["vault"]:
        return None
    return next(v for v in L.VAULTS if v["x0"] - EPS <= rm["x0"] and rm["x1"] <= v["x1"] + EPS
                and v["z0"] - EPS <= rm["z0"] and rm["z1"] <= v["z1"] + EPS)


def lamps() -> list[dict]:
    """A strip lamp on each room's own ceiling (but a doorway's), every LAMP_STEP m along its longer side (two rows across a wide room),
    its `y` the ceiling's underside there, turned (`turn` 90) to run along a room longer in z than in x."""
    out = []
    for rm in L.rooms:
        if not rm["ceil"] or max(rm["x1"] - rm["x0"], rm["z1"] - rm["z0"]) < LAMP_ROOM_MIN:
            continue
        along_x = rm["x1"] - rm["x0"] >= rm["z1"] - rm["z0"]
        a0, a1 = (rm["x0"], rm["x1"]) if along_x else (rm["z0"], rm["z1"])
        b0, b1 = (rm["z0"], rm["z1"]) if along_x else (rm["x0"], rm["x1"])
        n = max(1, round((a1 - a0) / LAMP_STEP))
        rows = [0.25, 0.75] if b1 - b0 > LAMP_ROWS_OVER else [0.5]
        for i in range(n):
            a = a0 + (a1 - a0) * (i + 0.5) / n
            for t in rows:
                b = b0 + (b1 - b0) * t
                x, z = (a, b) if along_x else (b, a)
                v = vault_of(rm)
                if v is not None:
                    # Under the vault, low enough that the panel's side nearer the wall clears the curve.
                    zc = (v["z0"] + v["z1"]) / 2
                    y = vault_y(v, zc + math.copysign(abs(z - zc) + LAMP_HALF_DEPTH, z - zc))
                elif is_ramp(rm) and not rm.get("flat"):
                    cell = next(c for c in ramp_cells(rm) if c[0] - EPS <= x <= c[1] + EPS)
                    y = ceil_under(rm, *cell)
                else:
                    y = ceil_at(rm, floor_at(rm, x))
                lamp = {"x": r(x), "z": r(z), "y": r(y + LIFT)}
                if not along_x:
                    lamp["turn"] = 90   # the strip lamp (SM5) runs along its room
                out.append(lamp)
    return out


def spiral_floor(x: float, z: float, near: float) -> float | None:
    """The spiral's floor under (x, z) nearest `near`, or None off its flights."""
    s = L.SPIRAL
    if not (s["x0"] <= x <= s["x1"] and s["z0"] <= z <= s["z1"]):
        return None
    ramps, boxes = spiral()
    best = None
    for rp in ramps:
        if rp["x0"] <= x <= rp["x1"] and rp["z0"] <= z <= rp["z1"]:
            if rp["rise"] in ("+x", "-x"):
                t = (x - rp["x0"]) / (rp["x1"] - rp["x0"])
                t = t if rp["rise"] == "+x" else 1 - t
            else:
                t = (z - rp["z0"]) / (rp["z1"] - rp["z0"])
                t = t if rp["rise"] == "+z" else 1 - t
            y = rp["y0"] + (rp["y1"] - rp["y0"]) * t
            if best is None or abs(y - near) < abs(best - near):
                best = y
    for bx in boxes[:-1]:
        if bx[0] <= x <= bx[1] and bx[4] <= z <= bx[5]:
            if best is None or abs(bx[3] - near) < abs(best - near):
                best = bx[3]
    return best


def lane_point(x: float, z: float, near: float) -> dict:
    y = spiral_floor(x, z, near)
    if y is None:
        y = floor_y(x, z, near)
    return {"x": x, "y": r(y + LIFT), "z": z}


def areas() -> list[dict]:
    # Each lift's car (MT2) first, over its well's whole height: a body in it is "Lift" at every stop, never the room
    # round the shaft (MapAreas.area_at takes the first area that holds a point).
    s, t = L.SHAFT, L.SHAFT_T
    out = [{"name": "Lift", "box": [lf["x0"], lf["x1"], r(s["z0"] + t), r(s["z1"] - t)],
            "floor": [r(min(L.LIFT_STOPS) + LIFT - 0.5), r(s["top"] + LIFT)]} for lf in L.LIFTS]
    seen = set()
    for rm in sorted(L.rooms, key=lambda q: 0 if q["name"] == "spiral" or is_ramp(q) else 1):
        lo = min(rm["ya"], rm["yb"]) + LIFT
        hi = max(rm["ya"], rm["yb"]) + LIFT + rm["h"] - (0.5 if rm["name"] == "spiral" else 0.0)
        key = (rm["area"], rm["x0"], rm["z0"], lo)
        if key in seen:
            continue
        seen.add(key)
        out.append({"name": rm["area"], "box": [rm["x0"], rm["x1"], rm["z0"], rm["z1"]],
                    "floor": [r(lo - 0.5), r(hi)]})
    return out


def main() -> None:
    data = build()
    for a in data["areas"]:
        assert len(a["name"]) <= 14, a["name"]
    with open(OUT, "w") as f:
        json.dump(data, f, indent=1)
        f.write("\n")
    print(f"{os.path.relpath(OUT)}: {len(data['blocks'])} blocks, {len(data['areas'])} areas")
    if len(sys.argv) > 1:
        # Each room's middle on its floor, for a probe of where the bots' grid reaches.
        pts = [{"name": rm["name"], "x": (rm["x0"] + rm["x1"]) / 2, "z": (rm["z0"] + rm["z1"]) / 2,
                "y": floor_at(rm, (rm["x0"] + rm["x1"]) / 2) + LIFT} for rm in L.rooms]
        with open(sys.argv[1], "w") as f:
            json.dump(pts, f)


if __name__ == "__main__":
    main()
