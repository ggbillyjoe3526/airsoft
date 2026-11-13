"""Stockade's layout as data (SK1): the owner's concept 1 (concepts/new-map-ptb/idea-1-stockade-plan.png), a plywood
village inside a log fort, 104 x 76 m on flat ground. The attackers (end 0) start in the West camp by the Tents, the
defenders in the East camp; three ways run west to east (the Back Lane, Main Street to the Green, the Woodyard Road
past the Orchard) and the West Arch, the Tavern and the Store look onto the open Green and its campfire. The Bell tower
stands between the sites. Site A is indoors (the Long House), Site B the open Woodyard under its shed.

Everything is an axis-aligned box on the ground (y = 0): `boxes` (what build_map.py writes as blocks), `DOORS`,
`ROOF_TILES`, and the field's ends, lanes, flags, sites, areas and lights. x runs east, z south. Built only from
models the game already has (PropDressConfig): plywood walls and headers, hut roofs, the palisade, cordwood, crates,
fallen logs, sandbags, drums, barrels, the sofa, Woodland's watch tower (the Bell tower), the Sawmill's shed, sawbench
and boards, trees and bushes.

    python3 tools/stockade/check.py     # overlaps, sight lines, walks, a plan picture
    python3 tools/stockade/build_map.py # writes data/maps/stockade.json
"""
from __future__ import annotations

W, H = 52.0, 38.0           # the field's half size (m): the concept's 104 x 76
T = 0.3                     # a plywood wall's thickness (Depot's)
WALL = 2.6                  # and its height: the plywood kit's own
SILL, LINTEL = 1.0, 2.1     # a window's opening
ROOF_T = 0.15               # a roof block (the hut roofs are modelled inside it)
SINK = 0.0                  # the ground is flat: every block stands on it at its model's own height
PAL_T = 0.4                 # the palisade's thickness
PAL_OUT, PAL_IN = 3.2, 2.8  # the fort's wall and the camps' inner walls (m high)
TALL = 2.4                  # a cordwood stack nobody sees over
CRATES = 2.3                # two crates on their pallets (PropDressConfig.grid_cells: 1.15 m each)
LOW = 1.15                  # one crate: crouch cover
DOOR_W = 1.6
DOOR_T, DOOR_GAP = 0.08, 0.005
MEET = 0.01                 # a wall runs this far into what it meets at each end (within FieldStandard.SEAM_SLACK),
                            # so no look slips along the seam between two faces drawn edge to edge

boxes: list[dict] = []
DOORS: list[dict] = []
ROOF_TILES: list[dict] = []
FLOORS: list[tuple[float, float, float, float]] = []  # wooden floors (the ground's paint): x1, x2, z1, z2


def box(kind: str, x1: float, z1: float, x2: float, z2: float, top: float, bottom: float = -SINK, **extra) -> dict:
    assert x2 > x1 and z2 > z1 and top > bottom, (kind, x1, z1, x2, z2)
    b = {"kind": kind, "x1": x1, "z1": z1, "x2": x2, "z2": z2, "y1": bottom, "y2": top}
    b.update(extra)
    boxes.append(b)
    return b


def _run(along_x: bool, a1: float, a2: float, c1: float, c2: float, openings: list, kind: str = "plywood",
         top: float = WALL) -> None:
    """A wall from a1 to a2 along one axis, c1 to c2 across it, with its openings (centre, width, what): a door or a
    gap is left open to the top, a window has a sill and a lintel."""
    cuts = sorted((c - w / 2, c + w / 2, what) for (c, w, what) in openings)
    a1, a2 = a1 - MEET, a2 + MEET
    pos = a1
    parts = []
    for (o1, o2, what) in cuts:
        assert o1 >= pos - 1e-6 and o2 <= a2 + 1e-6, ("opening outside its wall", a1, a2, o1, o2)
        if o1 > pos + 1e-6:
            parts.append((pos, o1, "solid"))
        parts.append((o1, o2, what))
        pos = o2
    if pos < a2 - 1e-6:
        parts.append((pos, a2, "solid"))
    for (p1, p2, what) in parts:
        spans = [(-SINK, top)] if what == "solid" else [(-SINK, SILL), (LINTEL, top)] if what == "window" else []
        for (y1, y2) in spans:
            if along_x:
                box(kind, p1, c1, p2, c2, y2, y1)
            else:
                box(kind, c1, p1, c2, p2, y2, y1)


def wall_x(z1: float, x1: float, x2: float, openings: list = (), **kw) -> None:
    """A plywood wall along x, its north face at z1."""
    _run(True, x1, x2, z1, z1 + T, list(openings), **kw)


def wall_z(x1: float, z1: float, z2: float, openings: list = (), **kw) -> None:
    """A plywood wall along z, its west face at x1."""
    _run(False, z1, z2, x1, x1 + T, list(openings), **kw)


def door(along_x: bool, c: float, face: float, side: int, shut: bool, width: float = DOOR_W) -> None:
    """A hinged door (DO1's format) in a doorway of a wall along x (or z), centred at `c` along it, hung just outside
    the wall's `face` on the side it swings out to (1: east or south, -1: west or north)."""
    off = face + side * (DOOR_T / 2 + DOOR_GAP)
    if along_x:
        DOORS.append({"x": c, "z": off, "sx": width, "sz": DOOR_T, "side": side, "shut": shut})
    else:
        DOORS.append({"x": off, "z": c, "sx": DOOR_T, "sz": width, "side": side, "shut": shut})


def building(x1: float, z1: float, x2: float, z2: float, openings: list, eaves: tuple = (0.3, 0.3, 0.3, 0.3),
             roof: bool = True) -> None:
    """A plywood building, its outer faces at x1, z1, x2, z2. `openings`: (side n/s/w/e, centre along the wall, width,
    'door' | 'shut' (a door that starts the round shut) | 'gap' | 'window'). `eaves`: how far the roof stands out past
    the west, north, east and south faces."""
    by = {s: [] for s in "nswe"}
    for (side, c, w, what) in openings:
        by[side].append((c, w, "door" if what == "shut" else what))
        if what in ("door", "shut"):
            if side == "n":
                door(True, c, z1, -1, what == "shut", w)
            elif side == "s":
                door(True, c, z2, 1, what == "shut", w)
            elif side == "w":
                door(False, c, x1, -1, what == "shut", w)
            else:
                door(False, c, x2, 1, what == "shut", w)
    wall_x(z1, x1, x2, by["n"])
    wall_x(z2 - T, x1, x2, by["s"])
    wall_z(x1, z1 + T, z2 - T, by["w"])
    wall_z(x2 - T, z1 + T, z2 - T, by["e"])
    FLOORS.append((x1 + T, x2 - T, z1 + T, z2 - T))
    if roof:
        roof_over(x1 - eaves[0], z1 - eaves[1], x2 + eaves[2], z2 + eaves[3])


def roof_over(x1: float, z1: float, x2: float, z2: float, y: float = WALL) -> None:
    """Shingled roof modules over a box, each near a hut roof's own size (hut_roof.py: 6.6 x 4.85 m and 5.6 x 4.6 m),
    their long sides along the box's."""
    sx, sz = x2 - x1, z2 - z1
    long_x = sx >= sz
    n_long = max(1, round((sx if long_x else sz) / 6.3))
    n_short = max(1, round((sz if long_x else sx) / 5.0))
    nx, nz = (n_long, n_short) if long_x else (n_short, n_long)
    for i in range(nx):
        for j in range(nz):
            ROOF_TILES.append({"x1": x1 + sx * i / nx, "x2": x1 + sx * (i + 1) / nx, "z1": z1 + sz * j / nz,
                               "z2": z1 + sz * (j + 1) / nz, "y": y})


def palisade(x1: float, z1: float, x2: float, z2: float, top: float = PAL_IN) -> None:
    """A run of palisade, in parts no longer than 8 m."""
    long_x = (x2 - x1) >= (z2 - z1)
    length = (x2 - x1) if long_x else (z2 - z1)
    n = max(1, int(-(-length // 8.0)))
    for k in range(n):
        if long_x:
            box("fence", x1 + length * k / n, z1, x1 + length * (k + 1) / n, z2, top, dress="palisade")
        else:
            box("fence", x1, z1 + length * k / n, x2, z1 + length * (k + 1) / n, top, dress="palisade")


def cordwood(x1: float, z1: float, x2: float, z2: float, top: float = TALL) -> None:
    box("log", x1, z1, x2, z2, top, dress="cordwood")


def crates(x1: float, z1: float, x2: float, z2: float, top: float = CRATES) -> None:
    box("crate", x1, z1, x2, z2, top)


def log(x1: float, z1: float, x2: float, z2: float) -> None:
    """A fallen log, 0.6 m high: the nearest of the three lengths modelled."""
    long = max(x2 - x1, z2 - z1)
    box("log", x1, z1, x2, z2, 0.6, dress="fallen_log_%d" % min((5, 6, 8), key=lambda n: abs(n - long)))


def sandbags(x1: float, z1: float, x2: float, z2: float, top: float = 1.0) -> None:
    box("sandbags", x1, z1, x2, z2, top, dress="sandbags")


TREES: list[tuple[float, float, float, str, float]] = []  # x, z, trunk half-width, model, height


def tree(x: float, z: float, model: str, height: float) -> None:
    rad = {"oak": 0.85, "birch": 0.17, "pine_young": 0.2, "pine_grown": 0.33, "pine_old": 0.42}[model]
    TREES.append((x, z, rad, model, height))


BUSHES: list[tuple[float, float, float, float]] = []  # x, z, radius, height (foliage: looked through, walked through)


def bush(x: float, z: float, radius: float = 1.0, height: float = 1.2) -> None:
    BUSHES.append((x, z, radius, height))


def tower(cx: float, cz: float) -> None:
    """Woodland's watch tower (one model, fitted over all its blocks), as the Bell tower: a 4 x 4 m platform at 3.4 m on
    four posts, a 1.1 m parapet open on the east where its stair comes up, a roof, and the stair (1 in 2) off the east
    side. Its parts are Woodland's blocks, stood on flat ground."""
    top, deck = 3.4, 0.2
    box("floor", cx - 2.0, cz - 2.0, cx + 2.0, cz + 2.0, top, top - deck, surface="wood", dress="watch_tower")
    box("ramp", cx + 2.0, cz - 0.6, cx + 2.0 + 2.0 * top + 0.2, cz + 0.6, top, 0.0, rise="-x", surface="wood",
        dress="watch_tower")
    box("plywood", cx - 2.4, cz - 2.4, cx + 2.4, cz + 2.4, 5.75, 5.6, dress="watch_tower")
    for px in (-2.0, 2.0):
        for pz in (-2.0, 2.0):
            box("log", cx + px - 0.15, cz + pz - 0.15, cx + px + 0.15, cz + pz + 0.15, top - deck, 0.0,
                dress="watch_tower")
    rail = top + 1.1
    for pz in (-2.0, 2.0):
        box("plywood", cx - 2.25, cz + pz - 0.25, cx + 2.0, cz + pz + 0.25, rail, top, dress="watch_tower")
    box("plywood", cx - 2.25, cz - 1.75, cx - 1.75, cz + 1.75, rail, top, dress="watch_tower")
    for pz in (-1.175, 1.175):
        box("plywood", cx + 1.5, cz + pz - 0.575, cx + 2.0, cz + pz + 0.575, rail, top, dress="watch_tower")


# ------------------------------------------------------------------ the fort's wall, and the two camps
palisade(-W - PAL_T, -H - PAL_T, W + PAL_T, -H, PAL_OUT)
palisade(-W - PAL_T, H, W + PAL_T, H + PAL_T, PAL_OUT)
palisade(-W - PAL_T, -H, -W, H, PAL_OUT)
palisade(W, -H, W + PAL_T, H, PAL_OUT)

CAMP_X = 42.0                                   # the camps' inner walls
ORCHARD_Z = 34.0                                # the Orchard's fence (south of the Woodyard Road)
GATES = ((-35.5, -30.5), (-2.5, 2.5), (29.5, ORCHARD_Z))  # their three gates: the Back Lane, Main Street, the Woodyard Road


def _xz(x: tuple[float, float], z: tuple[float, float]) -> tuple[float, float, float, float]:
    return (x[0], z[0], x[1], z[1])


def camp(s: int) -> None:
    """A camp behind its inner wall (s -1 west, 1 east): a screen inside the middle gate and five tall woodpiles reaching
    in from the fort's wall and from the inner wall by turns, so nobody sees the length of it."""
    def xs(a: float, b: float) -> tuple[float, float]:
        return (min(s * a, s * b), max(s * a, s * b))
    wx1, wx2 = xs(CAMP_X - PAL_T / 2, CAMP_X + PAL_T / 2)
    z = -H
    for (g1, g2) in GATES:
        palisade(wx1, z, wx2, g1)
        z = g2
    palisade(wx1, z, wx2, H)
    cordwood(*_xz(xs(44.4, 45.6), (-5.5, 5.5)), top=PAL_IN)          # the middle gate's screen
    cordwood(*_xz(xs(CAMP_X + PAL_T / 2, 50.0), (-12.6, -11.4)), top=PAL_IN)
    cordwood(*_xz(xs(44.5, W), (-22.6, -21.4)), top=PAL_IN)
    cordwood(*_xz(xs(CAMP_X + PAL_T / 2, 50.0), (11.4, 12.6)), top=PAL_IN)
    cordwood(*_xz(xs(44.5, W), (21.4, 22.6)), top=PAL_IN)
    cordwood(*_xz(xs(49.2, W), (-0.6, 0.6)), top=PAL_IN)


camp(-1)
camp(1)
EDGE = CAMP_X - PAL_T / 2  # the camps' inner walls' village faces

# The Tents: two small huts in the West camp's corners, a door each onto the camp.
building(-50.6, -32.0, -45.4, -27.0, [("e", -29.5, DOOR_W, "door")], eaves=(0.3, 0.3, 0.3, 0.3))
building(-50.6, 27.0, -45.4, 32.0, [("e", 29.5, DOOR_W, "door")], eaves=(0.3, 0.3, 0.3, 0.3))

SPAWNS_W = [(-48.5, -7.0 + 2.0 * i) for i in range(8)]   # the attackers (end 0)
SPAWNS_E = [(48.5, -7.0 + 2.0 * i) for i in range(8)]    # the defenders
DEAD_W = (-49.0, -18.0)
DEAD_E = (49.0, -18.0)
BOMB_START = (-46.2, 6.2)

# ------------------------------------------------------------------ the village west of the Green
STREET = 4.5     # Main Street's half width at the West Arch

# The Forge (north-west) and the Barn (south-west), as the concept stands them: the Barn the bigger, nearer the Green.
FORGE = (-36.0, -29.0, -24.0, -18.0)
building(*FORGE, [("e", -23.0, DOOR_W, "door"), ("s", -33.0, DOOR_W, "door"), ("n", -33.0, DOOR_W, "shut"),
                  ("n", -26.0, 2.0, "window")])
BARN = (-37.0, 14.0, -23.0, 27.0)
building(*BARN, [("e", 15.5, DOOR_W, "door"), ("e", 21.0, DOOR_W, "door"), ("n", -35.0, DOOR_W, "door"),
                 ("s", -33.0, DOOR_W, "shut"), ("s", -35.0, 2.0, "window")])
# The Barn's stalls: a partition across it, its doorway at the west end.
wall_z(-29.0 - T / 2, 14.0 + T, 27.0 - T, [(16.5, DOOR_W, "gap")])
wall_z(-24.0, -18.0, -15.0 - T)   # the Forge's east face run on, and a fence to the north hut's corner: the Forge
wall_x(-15.0 - T, -24.0, -21.0)   # yard is shut off from the North court but through the Forge or the hut
# The West Arch: a hut either side of Main Street's mouth on the Green, each a way through, a window onto the Green.
ARCH_N = (-21.0, -15.0, -15.0, -STREET)
ARCH_S = (-21.0, STREET, -15.0, 13.0)
building(*ARCH_N, [("n", -16.4, DOOR_W, "door"), ("s", -19.6, DOOR_W, "door")])
building(*ARCH_S, [("n", -19.6, DOOR_W, "door"), ("s", -16.4, DOOR_W, "door")])

# The yards on Main Street: a plywood fence along the street, one gate each, and the Arch's screen in its mouth.
wall_x(-STREET - T, -EDGE, -21.0, [(-27.0, 2.5, "gap")])
wall_x(STREET, -EDGE, -21.0, [(-38.0, 2.5, "gap")])

# The Arch's gates: a plywood wall across each half of Main Street, at the huts' west and east faces, overlapping by
# three metres, so the street dog-legs through the Arch and nobody sees down it from the Green, nor across the Green
# from the street.
wall_z(-21.0, -1.5, STREET)
wall_z(-15.0 - T, -STREET, 1.5)

# ------------------------------------------------------------------ the Tavern north of the Green, the Store south
TAVERN = (-10.0, -29.0, 8.0, -15.0)
building(*TAVERN, [("w", -27.5, DOOR_W, "door"), ("e", -17.5, DOOR_W, "door"), ("s", -1.0, DOOR_W, "door"),
                   ("s", -6.0, 2.0, "window"), ("s", 4.0, 2.0, "window"), ("n", 3.0, 2.0, "window")])
# A front room on the Green and a back room on the Back Lane, the doorway between them off to the east.
wall_x(-20.0 - T / 2, -10.0 + T, 8.0 - T, [(5.0, DOOR_W, "gap")])
STORE = (-8.0, 13.0, 8.0, 27.0)
building(*STORE, [("w", 18.5, DOOR_W, "door"), ("e", 23.0, DOOR_W, "door"), ("n", -3.0, 2.0, "window"),
                  ("n", 3.0, 2.0, "window")])
wall_x(20.0 - T / 2, -8.0 + T, 8.0 - T, [(5.0, DOOR_W, "gap")])
# Wings at the two buildings' front corners and fences across the alleys' mouths: the Green is a square framed by
# its houses, come into by Main Street, the four alleys and the Bell tower's yard.
for wx in (-10.0, 8.0 - T):
    wall_z(wx, -15.0, -11.0)
for wx in (-8.0, 8.0 - T):
    wall_z(wx, 9.0, 13.0)
wall_x(-15.0 - T, -15.0, -12.5)             # the alleys' fences, in line with the house fronts
wall_x(-15.0 - T, 10.5, 22.0)
wall_x(13.0, -15.0, -12.5)
wall_x(13.0, 10.5, 19.0)

# The Orchard's fence: a palisade along the Woodyard Road's south side, two gates into the trees behind it.
palisade(-EDGE, ORCHARD_Z, -26.0 - 1.25, ORCHARD_Z + PAL_T)
palisade(-26.0 + 1.25, ORCHARD_Z, 10.0 - 1.25, ORCHARD_Z + PAL_T)
palisade(10.0 + 1.25, ORCHARD_Z, EDGE, ORCHARD_Z + PAL_T)

# The courts' fences on the outer lanes: a plywood fence with one gate each, so a court is a yard of its own and the
# lanes are lanes.
wall_x(-29.0, -EDGE, -36.0, [(-37.7, 2.5, "gap")])
wall_x(-29.0, -24.0, -10.0, [(-17.5, 2.5, "gap")])
wall_x(-29.0, 8.0, 22.0, [(18.5, 2.5, "gap")])
wall_x(27.0 - T, -EDGE, -37.0, [(-39.5, 2.5, "gap")])
wall_x(27.0 - T, -23.0, -8.0, [(-18.0, 2.5, "gap")])
wall_x(27.0 - T, 8.0, 19.0, [(9.5, 2.5, "gap")])

# ------------------------------------------------------------------ east of the Green: the Bell tower and the sites
BELL = (15.0, 0.0)
BELL_TOWER = False    # the owner's call (SK1): from 3.4 m up it sees over every roof to the attackers' gate
if BELL_TOWER:
    tower(*BELL)
else:
    # The Bell house in its place: a plywood hut across Main Street's east end, its one door on the street behind, so
    # the street is walked round it, never seen down.
    # It spans the street 1 cm into each of its fences, so no line slips between them.
    building(BELL[0] - 3.0, -STREET - 0.01, BELL[0] + 3.0, STREET + 0.01, [("e", BELL[1], DOOR_W, "door")])
# Site A, the Long House: two rooms, four doors; the partition's doorway is the site's middle.
LONG = (22.0, -29.0, 38.0, -15.0)
building(*LONG, [("w", -26.0, DOOR_W, "door"), ("s", 26.5, DOOR_W, "door"), ("s", 35.0, DOOR_W, "door"),
                 ("e", -24.0, DOOR_W, "shut"), ("n", 25.0, 2.0, "window"), ("n", 36.0, 2.0, "window")])
wall_z(30.0 - T / 2, -29.0 + T, -15.0 - T, [(-22.0, 3.0, "gap")])
# Site B, the Woodyard: the Sawmill's open shed (its six posts and roof are one model, 10 x 6 m as modelled).
SHED = (31.0, 21.0)
for px in (-5.0, 0.0, 5.0):
    for pz in (-3.0, 3.0):
        box("log", SHED[0] + px - 0.15, SHED[1] + pz - 0.15, SHED[0] + px + 0.15, SHED[1] + pz + 0.15, 3.2,
            dress="sawmill_shed")
box("plywood", SHED[0] - 5.5, SHED[1] - 3.5, SHED[0] + 5.5, SHED[1] + 3.5, 3.35, 3.2, dress="sawmill_shed")
# The yards behind the Bell: a fence from each woodpile beside it towards the houses, a way left open at each end.
wall_z(BELL[0] - 3.0, -11.8, -STREET)
wall_z(BELL[0] - 3.0, STREET, 13.0)
# East Lane: the defenders' way between the sites, behind a plywood fence, hidden from the Green.
LANE_X = 38.0
wall_z(LANE_X - T, -15.0, -STREET)
wall_z(LANE_X - T, STREET, 12.0)
# Main Street east of the Bell house, between the yards' fences, a gate into each yard off to one side.
wall_x(-STREET - T, BELL[0] + 3.0 - 0.01, LANE_X - T, [(34.0, 2.5, "gap")])
wall_x(STREET, BELL[0] + 3.0 - 0.01, LANE_X - T, [(25.5, 2.5, "gap")])

FLAG_A = (30.0, -9.5)      # Attack / Defend's poles: before the Long House, and in the Woodyard by the road
FLAG_B = (32.5, 25.6)
FLAGS = [FLAG_A, FLAG_B]
OT_FLAG = (0.0, -5.0)      # Elimination's: on the Green, beside the campfire
FIRE = (0.0, 0.0)
# Plant The Bomb's sites (x, z, radius m; 0 the game's usual): A in the Long House, B under the Woodyard's shed.
BOMB_SITES = [(30.0, -22.0, 0), (SHED[0], SHED[1], 0)]

# The bots' lanes, West camp to East camp: the Back Lane to flag A, Main Street over the Green to the Bell tower, the
# Woodyard Road to flag B. A defender holds its lane's last point or the one before (RoundPlanner).
LANES = {
    "n": [(-47.0, -14.0), (-46.5, -33.0), (-36.0, -33.0), (-24.0, -32.0), (-12.0, -31.5), (0.0, -31.0), (8.0, -31.5),
          (17.0, -31.0), (19.0, -22.0), (22.0, -12.0), (30.0, -9.5)],
    "m": [(-48.5, 0.0), (-46.5, -5.3), (-43.3, -1.5), (-38.0, 0.0), (-30.0, 2.5), (-24.0, 0.0), (-19.0, -3.0),
          (-13.0, 0.0), (-6.0, -5.5), (6.0, -5.0), (13.0, 0.0), (16.0, -8.0), (30.0, -12.0)],
    "s": [(-47.0, 14.0), (-46.5, 33.0), (-36.0, 33.0), (-24.0, 32.0), (-10.0, 32.5), (6.0, 32.5), (17.0, 32.5),
          (25.0, 33.0), (31.0, 31.5), (31.0, 27.0)],
}
# The areas, as the callouts and the map name them: boxes (x1, x2, z1, z2), the first that holds a spot naming it.
AREAS = [
    ("Tents", -51.0, -45.0, -32.5, -26.5), ("Tents", -51.0, -45.0, 26.5, 32.5),
    ("West camp", -W, -CAMP_X, -H, H), ("East camp", CAMP_X, W, -H, H),
    ("Bell tower", 16.0, 30.5, -2.5, 2.5),
    ("Forge", FORGE[0], FORGE[2], FORGE[1], FORGE[3]), ("Barn", BARN[0], BARN[2], BARN[1], BARN[3]),
    ("Tavern", TAVERN[0], TAVERN[2], TAVERN[1], TAVERN[3]), ("Store", STORE[0], STORE[2], STORE[1], STORE[3]),
    ("Long House", LONG[0], LONG[2], LONG[1], LONG[3]),
    ("West Arch", ARCH_N[0], ARCH_N[2], ARCH_N[1], ARCH_N[3]), ("West Arch", ARCH_S[0], ARCH_S[2], ARCH_S[1], ARCH_S[3]),
    ("Woodyard", 19.0, LANE_X, 12.0, 30.6), ("East Lane", LANE_X, CAMP_X, -29.0, 30.5),
    ("Back Lane", -CAMP_X, CAMP_X, -H, -29.0),
    ("North court", -24.0, -10.0, -29.0, -17.0), ("House court", 8.0, 22.0, -29.0, -15.0),
    ("South court", -23.0, -8.0, 15.0, 25.0), ("Store court", 8.0, 19.0, 13.0, 25.0),
    ("Orchard", -20.0, 18.0, 33.0, H), ("Woodyard Road", -CAMP_X, CAMP_X, 25.0, H),
    ("Green", -16.0, 16.0, -17.0, 15.0),
    ("House yard", 16.0, LANE_X, -15.0, 0.0), ("Shed yard", 16.0, LANE_X, 0.0, 12.0),
    ("Main Street", -CAMP_X, -16.0, -STREET, STREET),
    ("Forge yard", -CAMP_X, -16.0, -29.0, -STREET), ("Barn yard", -CAMP_X, -16.0, STREET, 25.0),
]
# Night's lights: a fire in each camp and the Green's campfire, lanterns by the doors that matter (x, z, kind).
LIGHTS = [(-47.0, 18.0, "fire"), (47.0, 18.0, "fire"), (FIRE[0], FIRE[1], "fire"),
          (-35.2, -22.0, "lantern"), (-24.0, -21.5, "lantern"), (-23.0, 19.0, "lantern"), (-30.0, 13.2, "lantern"),
          (-19.0, -11.2, "lantern"), (-19.0, 11.2, "lantern"), (-10.8, -24.0, "lantern"), (-1.0, -16.2, "lantern"),
          (8.8, -22.0, "lantern"), (-8.8, 18.0, "lantern"), (8.8, 22.0, "lantern"), (21.2, -20.0, "lantern"),
          (26.5, -14.2, "lantern"), (35.0, -14.2, "lantern"), (24.0, 1.4, "lantern"), (31.0, 17.0, "lantern"),
          (31.0, 25.0, "lantern"), (40.0, -10.0, "lantern"), (40.0, 10.0, "lantern"), (-44.6, -29.5, "lantern"),
          (-44.6, 29.5, "lantern"), (-43.0, 0.0, "lantern"), (43.0, 0.0, "lantern")]

# ------------------------------------------------------------------ cover, place by place
import cover  # noqa: E402,F401  (adds to `boxes`, TREES and BUSHES)
