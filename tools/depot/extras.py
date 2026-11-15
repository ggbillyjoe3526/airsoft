"""Depot's other rack bays and its wall extras (DX1, the owner's photos of 2026-11-15), for tools/depot/build_map.py.

- `rack_dress`: which model each rack block (a `dead` piece) is drawn as. Its box stays as it was, so cover, sight
  lines and the bots' routes don't change: only its look. The two long strips along the north and south walls stay
  pallet racking; the others take turns through RACK_TURNS (racking, wrapped racking, drum and IBC stacks, a parts
  cage), so no area is all one kind.
- `fixtures`: the look-only models on the hall's walls and pillars (StationFixtures draws them: no collider, no nav
  cell, no shadow): the pipework along every wall at PIPE_Y, safety signs over the racking, fire points and cable
  on open walls by the columns, the "keep clear" sign beside each fire exit, and a call point and an
  extinguisher on each pillar. Each spot is checked clear of every block in front of it, so a model never stands in
  a stack or behind a wall, wherever the layout puts them.

The hall's walls are laid by PropLayout._bays as bays of the hall wall model (hall_wall.py) on an 8 m grid, with a
column at each bay's ends and up to two feature bays a wall (a shutter or a fire exit, taken in turn) where the wall
is open in front. `feature_bays` follows that rule, so the extras keep off the shutters and the exits' own signs;
tests/unit/test_dx1_depot_props.gd checks it against PropLayout.
"""
from __future__ import annotations

import math

# Rack blocks: one of these a block, in the layout's order (an empty name is the hall's own pallet racking).
RACK_TURNS = ["", "wrapped_racking", "drum_ibc_stack", "", "parts_cage"]
LONG_STRIP = 60.0  # (m) a rack block this long is a wall's whole run of racking, and stays racking

# The hall wall's bays (PropDressConfig.bay_pitch, bay_anchor, bay_features, bay_feature_most, bay_clear and
# bay_clear_height; hall_wall.py's depths in from its box's face).
PITCH = 8.0
ANCHOR = (0.0, 4.0)
FEATURES = ["hall_shutter", "hall_exit"]
FEATURE_MOST = 2
BAY_CLEAR = 2.0
BAY_CLEAR_HEIGHT = 3.0
LINER = 0.10       # the cladding's troughs
RIB = 0.125        # its crests: a sign's back sits on them
BLOCK_FACE = 0.20  # the blockwork dado's face, up to 2.4 m

PIPE_Y = 5.6       # the services' foot: over the shutters' coil boxes (5.32 m), under the rooflights (6.3 m)
PIPE_MODULES = [("pipe_run", 4.0), ("pipe_run_2", 2.0)]
PIPE_FITTED = ("pipe_run_b", 3)  # every third 4 m length along a wall is the one with its valve, drop and box
PIPE_BELOW = 0.3   # (m) the fitted length's conduit and sprinkler head reach this far under PIPE_Y
PIPE_CORNER = 2.0  # (m) the end walls' pipework stops this far from a corner, under the long walls' runs
PIPE_OUT = 0.7     # how far the pipework stands out from the wall (pipe_run is 0.66 m)
FIRE_POINT_Y = 0.3  # the fire point hangs this far off the floor (photo 3's wall-mounting board)
BESIDE = 0.9       # (m) a fire point's or a sign's middle from its column
FIRE_POINT_APART = 20.0
SPARE_APART = 6.0  # (m) an eye-height sign from another extra on its wall
# every safety sign on the lower wall at eye height, in turn (the owner, 2026-11-15: "signs should be on the lower
# part of the wall at roughly eye height")
EYE_SIGNS = ["depot_sign_pallet_storage", "depot_sign_defib", "depot_sign_ppe", "depot_sign_fire_action",
             "depot_sign_no_riding", "depot_sign_assembly"]
EYE_Y = 1.6
EYE_MOST = 14      # eye-height signs in all
EXIT_SIGN = ("depot_sign_fire_exit", -1.1, 1.75)  # beside the exit door, over its extinguisher's recess
PILLAR_R = 0.195   # the steel pillar's post is 0.2 m round (steel_pillar.py)
CALL_Y = 1.35
EXTINGUISHER_Y = 0.4
FLOOR_CLEAR = (1.2, 2.3)  # (m) out and up in front of a fire point or an eye-height sign


def rack_dress(pieces: list[dict]) -> list[str]:
    """The dress of each `dead` piece of `pieces`, in their order."""
    out: list[str] = []
    turn = 0
    for p in pieces:
        if p["kind"] != "dead":
            continue
        if max(p["x2"] - p["x1"], p["z2"] - p["z1"]) >= LONG_STRIP:
            out.append("")
            continue
        out.append(RACK_TURNS[turn % len(RACK_TURNS)])
        turn += 1
    return out


def _box(b: dict) -> tuple:
    c, s = b["center"], b["size"]
    return (c["x"] - s["x"] / 2, c["y"] - s["y"] / 2, c["z"] - s["z"] / 2,
            c["x"] + s["x"] / 2, c["y"] + s["y"] / 2, c["z"] + s["z"] / 2)


def _hits(a: tuple, b: tuple) -> bool:
    """Whether boxes a and b overlap (touching isn't: Godot's AABB.intersects)."""
    return all(a[i] < b[i + 3] and b[i] < a[i + 3] for i in range(3))


class Wall:
    """One of the hall's four walls: its block, the way into the hall (`n`, a unit axis), the turn a model on it
    takes (yaw, degrees: its front +z into the hall) and its x axis along the wall (`along`)."""

    def __init__(self, block: dict, middle: tuple):
        self.block = block
        self.box = _box(block)
        s = block["size"]
        self.along_x = s["x"] >= s["z"]
        c = block["center"]
        if self.along_x:
            self.n = (0.0, 1.0) if middle[1] >= c["z"] else (0.0, -1.0)
            self.yaw = 0.0 if self.n[1] > 0 else 180.0
            self.face = c["z"] + self.n[1] * s["z"] / 2
            self.lo, self.hi = c["x"] - s["x"] / 2, c["x"] + s["x"] / 2
        else:
            self.n = (1.0, 0.0) if middle[0] >= c["x"] else (-1.0, 0.0)
            self.yaw = 90.0 if self.n[0] > 0 else -90.0
            self.face = c["x"] + self.n[0] * s["x"] / 2
            self.lo, self.hi = c["z"] - s["z"] / 2, c["z"] + s["z"] / 2
        r = math.radians(self.yaw)
        self.x_axis = (round(math.cos(r)), round(-math.sin(r)))  # the model's +x on the floor (world x, z)
        self.sign = self.x_axis[0] if self.along_x else self.x_axis[1]  # +1 when the model's x runs up the wall's

    def point(self, s: float, out: float) -> tuple:
        """The floor's (x, z) at `s` along the wall and `out` m in from its face."""
        if self.along_x:
            return (s, self.face + self.n[1] * out)
        return (self.face + self.n[0] * out, s)

    def strip(self, s0: float, s1: float, y0: float, y1: float, out: float) -> tuple:
        """The box in front of the wall from s0 to s1 along it, y0 to y1 up, `out` m deep."""
        a, b = self.point(s0, 0.0), self.point(s1, out)
        return (min(a[0], b[0]), y0, min(a[1], b[1]), max(a[0], b[0]), y1, max(a[1], b[1]))

    def cells(self) -> list[float]:
        """Its bays' edges (PropLayout.bay_cells): its ends and every grid line at least half a pitch inside them."""
        origin = ANCHOR[0] if self.along_x else ANCHOR[1]
        edges = [self.lo]
        line = origin + math.ceil((self.lo + PITCH * 0.5 - origin) / PITCH) * PITCH
        while line <= self.hi - PITCH * 0.5 + 1e-4:
            edges.append(line)
            line += PITCH
        edges.append(self.hi)
        return edges


def fixture(model: str, x: float, y: float, z: float, yaw: float) -> dict:
    return {"model": model, "x": round(x, 3), "y": round(y, 3), "z": round(z, 3), "yaw": round(yaw, 1)}


def _on(w: Wall, model: str, s: float, y: float, out: float) -> dict:
    x, z = w.point(s, out)
    return fixture(model, x, y, z, w.yaw)


def feature_bays(walls: list[Wall], others: list[tuple]) -> dict:
    """Each wall's feature bays (PropLayout._bays): {(wall index, cell index): feature}, taken in turn across the walls
    in their order, at most FEATURE_MOST a wall, never side by side, each a whole cell clear in front."""
    out = {}
    laid = 0
    for wi, w in enumerate(walls):
        edges = w.cells()
        on_wall, last = 0, -2
        for i in range(len(edges) - 1):
            if on_wall >= FEATURE_MOST or i <= last + 1 or abs(edges[i + 1] - edges[i] - PITCH) >= 0.01:
                continue
            strip = w.strip(edges[i], edges[i + 1], 0.1, BAY_CLEAR_HEIGHT, BAY_CLEAR)
            if any(_hits(strip, o) for o in others):
                continue
            out[(wi, i)] = FEATURES[laid % len(FEATURES)]
            laid += 1
            on_wall += 1
            last = i
    return out


def _pipes(w: Wall, walls: list[Wall], others: list[tuple], corner: float) -> list[dict]:
    """The pipework along wall w, a module a stretch between its columns, left out where anything stands in front."""
    out: list[dict] = []
    edges = w.cells()
    long = 0
    for i in range(len(edges) - 1):
        a, b = edges[i], edges[i + 1]
        if i == 0:
            a = max(a, _end(w, walls, -1) + corner)
        if i == len(edges) - 2:
            b = min(b, _end(w, walls, 1) - corner)
        s = a
        while b - s >= PIPE_MODULES[-1][1] - 1e-6:
            model, length = next((m, n) for m, n in PIPE_MODULES if b - s >= n - 1e-6)
            strip = w.strip(s, s + length, PIPE_Y - PIPE_BELOW, PIPE_Y + PIPE_OUT, PIPE_OUT)
            if not any(_hits(strip, o) for o in others):
                if length == PIPE_MODULES[0][1]:
                    long += 1
                    if long % PIPE_FITTED[1] == 2:
                        model = PIPE_FITTED[0]
                # the model runs from its origin along its own +x
                out.append(_on(w, model, s if w.sign > 0 else s + length, PIPE_Y, LINER))
            s += length
    return out


def _end(w: Wall, walls: list[Wall], side: int) -> float:
    """Where wall w meets the hall's wall across its low (side -1) or high (+1) end: that wall's face."""
    ends = [o.face for o in walls if o.along_x != w.along_x]
    return min(ends) if side < 0 else max(ends)


def fixtures(blocks: list[dict], middle: tuple) -> list[dict]:
    """Every wall extra for the map's `blocks` (its four hall walls first after the floor, as build_map.blocks writes
    them), the hall's `middle` (x, z) to tell which way each wall faces."""
    walls = [Wall(b, middle) for b in blocks[1:5]]
    others = [_box(b) for b in blocks[5:]]
    features = feature_bays(walls, others)
    out: list[dict] = []
    for w in walls:
        out += _pipes(w, walls, others, 0.0 if w.along_x else PIPE_CORNER)
    # the spots beside the columns, in wall order, open in front below 2.3 m (a fire point, a sign at eye height)
    floor_spots: list[tuple] = []
    for wi, w in enumerate(walls):
        edges = w.cells()
        a_end, b_end = _end(w, walls, -1), _end(w, walls, 1)
        for i, col in enumerate(edges):
            for side in (-1, 1):
                cell = i + (0 if side > 0 else -1)
                if cell < 0 or cell >= len(edges) - 1:
                    continue
                s = col + side * BESIDE
                if s - 0.5 < a_end or s + 0.5 > b_end:
                    continue
                if features.get((wi, cell)) == "hall_exit":
                    continue  # the exit bay has its own extinguisher and call point
                floor = w.strip(s - 0.4, s + 0.4, 0.05, FLOOR_CLEAR[1], FLOOR_CLEAR[0])
                if not any(_hits(floor, o) for o in others):
                    floor_spots.append((wi, cell, s))
    # fire points FIRE_POINT_APART apart along each wall; then the eye-height signs on the spots left, in turn, never
    # on a fire point's column
    taken: list[tuple] = []
    for wi, cell, s in floor_spots:
        w = walls[wi]
        if all(t[0] != wi or abs(t[2] - s) >= FIRE_POINT_APART for t in taken):
            taken.append((wi, cell, s))
            out.append(_on(w, "fire_point", s, FIRE_POINT_Y, BLOCK_FACE + 0.01))
    used = list(taken)
    spare = [p for p in floor_spots if all(p[0] != t[0] or abs(p[2] - t[2]) > 2 * BESIDE + 0.01 for t in taken)]
    eye = 0
    for wi, cell, s in spare:
        if eye >= EYE_MOST:
            break
        if any(u[0] == wi and abs(u[2] - s) < SPARE_APART for u in used):
            continue
        out.append(_on(walls[wi], EYE_SIGNS[eye % len(EYE_SIGNS)], s, EYE_Y, BLOCK_FACE + 0.005))
        eye += 1
        used.append((wi, cell, s))
    # each fire exit's "keep clear" sign beside its door
    for (wi, cell), feature in sorted(features.items()):
        if feature != "hall_exit":
            continue
        w = walls[wi]
        edges = w.cells()
        mid = (edges[cell] + edges[cell + 1]) * 0.5
        model, dx, y = EXIT_SIGN
        out.append(_on(w, model, mid + w.sign * dx, y, BLOCK_FACE + 0.005))
    # a call point and an extinguisher on each pillar, on its side towards the hall's middle
    for b in blocks[5:]:
        if b["kind"] != "pillar":
            continue
        c = b["center"]
        dx, dz = middle[0] - c["x"], middle[1] - c["z"]
        if abs(dx) >= abs(dz):
            n, yaw = ((1.0, 0.0), 90.0) if dx > 0 else ((-1.0, 0.0), -90.0)
        else:
            n, yaw = ((0.0, 1.0), 0.0) if dz > 0 else ((0.0, -1.0), 180.0)
        x, z = c["x"] + n[0] * PILLAR_R, c["z"] + n[1] * PILLAR_R
        out.append(fixture("call_point", x, CALL_Y, z, yaw))
        out.append(fixture("fire_extinguisher", x, EXTINGUISHER_Y, z, yaw))
    return out
