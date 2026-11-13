"""Stockade's layout as data (SK1): a plywood village inside a log fort, 104 x 64 m on flat ground. The attackers
(end 0) start in the West camp, the defenders in the East camp; three ways run west to east (the Back Lane, Main
Street through the Green, the Woodyard Road) and the Arches, the Tavern, the Store and the yards join them. Site A is
indoors (the Long House), Site B the open Woodyard under its shed.

Everything is an axis-aligned box on the ground (y = 0): `boxes` (what build_map.py writes as blocks), `DOORS`,
`ROOF_TILES`, and the field's ends, lanes, flags, sites, areas and lights. x runs east, z south. Built only from
models the game already has (PropDressConfig): plywood walls and headers, hut roofs, the palisade, cordwood, crates,
fallen logs, sandbags, drums, barrels, the sofa, the Sawmill's shed, sawbench and boards, trees and spruces.

    python3 tools/stockade/check.py     # overlaps, sight lines, walks, a plan picture
    python3 tools/stockade/build_map.py # writes data/maps/stockade.json
"""
from __future__ import annotations

W, H = 52.0, 32.0           # the field's half size (m)
T = 0.3                     # a plywood wall's thickness (Depot's)
WALL = 2.6                  # and its height: the plywood kit's own
SILL, LINTEL = 1.0, 2.1     # a window's opening
ROOF_T = 0.15               # a roof block (the hut roofs are modelled inside it)
SINK = 0.3                  # every block reaches this far under the ground
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


# ------------------------------------------------------------------ the fort's wall, and the two camps
palisade(-W - PAL_T, -H - PAL_T, W + PAL_T, -H, PAL_OUT)
palisade(-W - PAL_T, H, W + PAL_T, H + PAL_T, PAL_OUT)
palisade(-W - PAL_T, -H, -W, H, PAL_OUT)
palisade(W, -H, W + PAL_T, H, PAL_OUT)

CAMP_X = 42.0                                   # the camps' inner walls
GATES = ((-31.0, -27.0), (-2.5, 2.5), (27.0, 31.0))  # their three gates: the Back Lane, Main Street, the Woodyard Road


def camp(s: int) -> None:
    """A camp behind its inner wall (s -1 west, 1 east): a screen inside the middle gate and four tall woodpiles, two
    reaching in from the fort's wall and two from the inner wall, so nobody sees the length of it."""
    def xs(a: float, b: float) -> tuple[float, float]:
        return (min(s * a, s * b), max(s * a, s * b))
    wx1, wx2 = xs(CAMP_X - PAL_T / 2, CAMP_X + PAL_T / 2)
    z = -H
    for (g1, g2) in GATES:
        palisade(wx1, z, wx2, g1)
        z = g2
    palisade(wx1, z, wx2, H)
    cordwood(*_xz(xs(44.4, 45.6), (-4.0, 4.0)), top=PAL_IN)          # the middle gate's screen
    cordwood(*_xz(xs(CAMP_X + PAL_T / 2, 48.5), (-9.6, -8.4)), top=PAL_IN)
    cordwood(*_xz(xs(45.5, W), (-19.6, -18.4)), top=PAL_IN)
    cordwood(*_xz(xs(45.5, W), (8.4, 9.6)), top=PAL_IN)
    cordwood(*_xz(xs(CAMP_X + PAL_T / 2, 48.5), (18.4, 19.6)), top=PAL_IN)
    crates(*_xz(xs(50.2, 51.4), (22.0, 24.0)), top=LOW)
    crates(*_xz(xs(42.6, 43.8), (11.5, 13.5)))


def _xz(x: tuple[float, float], z: tuple[float, float]) -> tuple[float, float, float, float]:
    return (x[0], z[0], x[1], z[1])


camp(-1)
camp(1)

SPAWNS_W = [(-48.5, -7.0 + 2.0 * i) for i in range(8)]   # the attackers (end 0)
SPAWNS_E = [(48.5, -7.0 + 2.0 * i) for i in range(8)]    # the defenders
DEAD_W = (-50.0, -14.0)
DEAD_E = (50.0, -14.0)
BOMB_START = (-46.2, 6.2)

# ------------------------------------------------------------------ the village: west of the Green
LANE = 26.0      # the Back Lane and the Woodyard Road lie beyond this
YARD = 14.0      # the buildings' fronts on the yards and the Green
STREET = 4.0     # Main Street's half width
EDGE = CAMP_X - PAL_T / 2  # the camps' inner walls' village faces

# The Forge (north) and the Barn (south), each with its yard on Main Street behind a plywood fence.
building(-EDGE, -LANE, -29.0, -YARD, [("n", -35.5, DOOR_W, "door"), ("s", -33.0, DOOR_W, "shut"),
                                         ("e", -22.5, DOOR_W, "door"), ("n", -31.5, 2.0, "window"),
                                         ("s", -38.5, 2.0, "window")], eaves=(0.0, 0.3, 0.3, 0.3))
building(-EDGE, YARD, -29.0, LANE, [("s", -35.5, DOOR_W, "door"), ("n", -33.0, DOOR_W, "shut"),
                                      ("e", 22.5, DOOR_W, "door"), ("s", -31.5, 2.0, "window"),
                                      ("n", -38.5, 2.0, "window")], eaves=(0.0, 0.3, 0.3, 0.3))
# Each is two rooms: a partition across it, its doorway at the west end, so no line runs door to door through it.
PART = 20.0 - T / 2
wall_x(-PART - T, -EDGE + T, -29.0 - T, [(-39.5, DOOR_W, "gap")])
wall_x(PART, -EDGE + T, -29.0 - T, [(-39.5, DOOR_W, "gap")])
wall_x(-STREET - T, -EDGE, -22.0, [(-34.75, 2.5, "gap")])
wall_x(STREET, -EDGE, -22.0, [(-29.75, 2.5, "gap")])
# The West Arch: a hut either side of Main Street's mouth on the Green, each a way through from its square.
ARCH = (STREET + T, STREET + T + 6.0)   # the huts' z, either side
building(-22.0, -ARCH[1], -16.0, -ARCH[0], [("n", -20.2, DOOR_W, "door"), ("s", -17.8, DOOR_W, "door"),
                                              ("e", -8.6, 1.8, "window")])
building(-22.0, ARCH[0], -16.0, ARCH[1], [("n", -20.2, DOOR_W, "door"), ("s", -17.8, DOOR_W, "door"),
                                            ("e", 6.0, 1.8, "window")])

# ------------------------------------------------------------------ the Green, the Tavern north of it, the Store south
building(-9.0, -LANE, 9.0, -YARD, [("n", 6.0, DOOR_W, "door"), ("s", -3.0, DOOR_W, "door"),
                                     ("w", -17.5, DOOR_W, "door"), ("e", -22.5, DOOR_W, "shut"),
                                     ("s", 5.0, 2.4, "window"), ("n", -4.5, 2.0, "window")])
building(-9.0, YARD, 9.0, LANE, [("s", -6.0, DOOR_W, "door"), ("n", 3.0, DOOR_W, "door"),
                                   ("e", 17.5, DOOR_W, "door"), ("w", 22.5, DOOR_W, "shut"),
                                   ("n", -5.0, 2.4, "window"), ("s", 4.5, 2.0, "window")])
# Each has a front room on the Green and a back room on its lane, the doorway between them off to one side; and a
# plywood wing at each front corner, which ends the long look along the building fronts.
wall_x(-PART - T, -9.0 + T, 9.0 - T, [(-6.5, DOOR_W, "gap")])
wall_x(PART, -9.0 + T, 9.0 - T, [(6.5, DOOR_W, "gap")])
WING = YARD - ARCH[1]      # as far out as the Arch huts' corners (3.7 m)
for wx in (-9.0 - T, 9.0):
    wall_z(wx, -YARD, -YARD + WING)
    wall_z(wx, YARD - WING, YARD)
# Fences shut most of each alley's mouth on the Green; the gaps north and south never line up.
wall_x(-YARD - T, -16.0, -11.5)
wall_x(-YARD - T, 11.5, 16.0)
wall_x(YARD, -13.5, -9.0)
wall_x(YARD, 9.0, 13.5)
# The four courts between the buildings: a fence along each outer lane with one gap, and one along the building
# fronts, so a court is a room of its own and the lanes are lanes.
wall_x(-LANE, -29.0, -9.0, [(-26.0, 2.5, "gap")])
wall_x(-LANE, 9.0, 24.0, [(21.5, 2.5, "gap")])
wall_x(LANE - T, -29.0, -9.0, [(-27.5, 2.5, "gap")])
wall_x(LANE - T, 9.0, 22.0, [(11.0, 2.5, "gap")])
wall_x(-YARD - T, -29.0, -20.5)
wall_x(YARD, -29.0, -20.5)
wall_x(-YARD - T, 20.5, 24.0)
# A screen stands in each Arch's mouth: Main Street is walked round it, never seen through.
wall_z(-19.0 - T / 2, -2.0, 2.0)
wall_z(19.0 - T / 2, -2.0, 2.0)
# Main Street's mouths: two crate stacks each, so nobody sees the street's length across the Green.
crates(-15.5, -STREET - T, -14.3, 0.6)
crates(-11.5, -0.6, -10.3, STREET + T)
crates(14.3, -0.6, 15.5, STREET + T + 1.15)   # a cell longer: the slit past the East Arch hut's corner
crates(10.3, -STREET - T, 11.5, 0.6)

# ------------------------------------------------------------------ east of the Green: the East Arch and the sites
building(16.0, -ARCH[1], 22.0, -ARCH[0], [("n", 17.8, DOOR_W, "door"), ("s", 20.2, DOOR_W, "door"),
                                           ("w", -6.0, 1.8, "window")])
building(16.0, ARCH[0], 22.0, ARCH[1], [("n", 17.8, DOOR_W, "door"), ("s", 20.2, DOOR_W, "door"),
                                         ("w", 8.6, 1.8, "window")])
# Site A, the Long House: two rooms, four doors.
LONG = (24.0, -LANE, 38.0, -YARD)
building(*LONG, [("n", 27.5, DOOR_W, "door"), ("w", -18.0, DOOR_W, "door"), ("s", 34.5, DOOR_W, "door"),
                 ("e", -21.0, DOOR_W, "shut"), ("n", 36.3, 2.0, "window"), ("s", 27.5, 2.0, "window")])
wall_z(31.0 - T / 2, -LANE + T, -YARD - T, [(-20.0, 3.0, "gap")])
wall_x(-STREET - T, 22.0, EDGE, [(30.25, 2.5, "gap")])
wall_x(STREET, 22.0, EDGE, [(33.75, 2.5, "gap")])
# Site B, the Woodyard: the Sawmill's open shed (its six posts and roof are one model, 10 x 6 m as modelled).
SHED = (32.0, 15.0)
for px in (-5.0, 0.0, 5.0):
    for pz in (-3.0, 3.0):
        box("log", SHED[0] + px - 0.15, SHED[1] + pz - 0.15, SHED[0] + px + 0.15, SHED[1] + pz + 0.15, 3.2,
            dress="sawmill_shed")
box("plywood", SHED[0] - 5.5, SHED[1] - 3.5, SHED[0] + 5.5, SHED[1] + 3.5, 3.35, 3.2, dress="sawmill_shed")

FLAG_A = (30.5, -9.0)      # Attack / Defend's poles: in the Long House's yard and beside the shed
FLAG_B = (32.0, 21.5)
FLAGS = [FLAG_A, FLAG_B]
OT_FLAG = (0.0, 0.0)
# Plant The Bomb's sites (x, z, radius m; 0 the game's usual): A in the Long House, B under the Woodyard's shed.
BOMB_SITES = [(31.0, -20.0, 0), (SHED[0], SHED[1], 0)]

# The bots' lanes, West camp to East camp: the Back Lane to flag A, Main Street to its east end between the two
# sites, the Woodyard Road to flag B. A defender holds its lane's last point or the one before (RoundPlanner).
LANES = {
    "n": [(-47.0, -12.0), (-46.5, -29.0), (-36.0, -29.0), (-24.8, -27.2), (-20.5, -31.0), (-10.0, -29.0),
          (-5.5, -28.5), (5.5, -30.0), (15.5, -27.3), (19.6, -31.0), (21.5, -27.0), (22.0, -23.5), (19.4, -17.5),
          (18.5, -11.0), (24.0, -11.0), (30.5, -9.5)],
    "m": [(-48.5, 0.0), (-46.5, -5.3), (-43.3, -1.5), (-40.0, 0.0), (-35.0, 2.5), (-29.5, -2.5), (-23.0, -1.5),
          (-20.6, -3.0), (-17.0, 1.2), (-12.6, -1.6), (-6.0, -4.0), (0.0, -2.4), (6.0, 4.0), (12.6, 2.2), (17.0, -1.6),
          (20.6, 3.0), (24.0, 0.0), (29.5, 2.6), (35.5, 0.0)],
    "s": [(-47.0, 12.0), (-46.5, 29.0), (-36.0, 29.0), (-25.0, 27.2), (-21.0, 31.0), (-10.0, 29.0), (-2.0, 30.8),
          (2.0, 27.2), (9.0, 29.0), (14.0, 27.2), (18.6, 31.0), (24.0, 28.0), (30.5, 26.0), (32.0, 22.0)],
}
# The areas, as the callouts and the map name them: boxes (x1, x2, z1, z2) tiling the whole fort.
AREAS = [
    ("West camp", -W, -CAMP_X, -H, H), ("East camp", CAMP_X, W, -H, H),
    ("Back Lane", -CAMP_X, CAMP_X, -H, -LANE), ("Woodyard Road", -CAMP_X, CAMP_X, LANE, H),
    ("Forge", -CAMP_X, -29.0, -LANE, -YARD), ("Forge court", -29.0, -9.0, -LANE, -YARD),
    ("Tavern", -9.0, 9.0, -LANE, -YARD), ("Tavern court", 9.0, 24.0, -LANE, -YARD),
    ("Long House", 24.0, CAMP_X, -LANE, -YARD),
    ("Forge yard", -CAMP_X, -22.0, -YARD, -STREET), ("House yard", 22.0, CAMP_X, -YARD, -STREET),
    ("West Arch", -22.0, -16.0, -YARD, YARD), ("East Arch", 16.0, 22.0, -YARD, YARD),
    ("Green", -16.0, 16.0, -YARD, YARD),
    ("West street", -CAMP_X, -22.0, -STREET, STREET), ("East street", 22.0, CAMP_X, -STREET, STREET),
    ("Barn yard", -CAMP_X, -22.0, STREET, YARD), ("Barn", -CAMP_X, -29.0, YARD, LANE),
    ("Barn court", -29.0, -9.0, YARD, LANE), ("Store", -9.0, 9.0, YARD, LANE),
    ("Store court", 9.0, 22.0, YARD, LANE), ("Woodyard", 22.0, CAMP_X, STREET, LANE),
]
# Night's lights: a fire in each camp and on the Green's edge, lanterns by the doors that matter (x, z, kind).
LIGHTS = [(-47.0, 14.5, "fire"), (47.0, 14.5, "fire"),
          (-35.5, -27.2, "lantern"), (-27.8, -22.5, "lantern"), (-10.2, -17.5, "lantern"), (-3.0, -12.9, "lantern"),
          (6.0, -27.2, "lantern"), (27.5, -27.2, "lantern"), (22.8, -18.0, "lantern"), (34.5, -12.9, "lantern"),
          (-35.5, 27.2, "lantern"), (-27.8, 22.5, "lantern"), (3.0, 12.9, "lantern"), (10.2, 17.5, "lantern"),
          (-6.0, 27.2, "lantern"), (-19.0, -3.2, "lantern"), (19.0, 3.2, "lantern"), (-11.0, -8.0, "lantern"),
          (11.0, 8.0, "lantern"), (27.0, 12.2, "lantern"), (37.0, 17.8, "lantern"), (-43.0, 0.0, "lantern"),
          (43.0, 0.0, "lantern"), (-30.0, 5.2, "lantern"), (30.0, -5.2, "lantern")]

# ------------------------------------------------------------------ cover, lane by lane (check.py's lines placed these)
import cover  # noqa: E402,F401  (adds to `boxes` and TREES)
