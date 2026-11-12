"""Depot's layout as data (the owner's approved concept 3, 2026-10-31; /mnt/project-files/concepts/depot-redesign/v3/).

Metres, x east, z south (north is up on the plan), the hall's middle at (0, 0). An indoor warehouse 108 x 72 m under a
roof at 8 m. Walkable ZONES are carved out of a solid mass; whatever no zone covers is dead space (closed plywood rooms
and racking, 3 m tall). Then the cover: plywood walls with doorways, windows and doors, huts, containers, crates, drums,
barrels, pillars and netting. Not mirrored: each end has its own shape, and fairness comes from measured timings
(tools/depot/README.md).

Edit this file, then run `python3 tools/depot/build_map.py` to write data/maps/depot.json.
"""
from __future__ import annotations

W, H = 54.0, 36.0  # half sizes: 108 x 72 m
T = 0.3            # a plywood wall's thickness
ROOF = 8.0
DEAD_H = 3.0
LID_H = 2.7        # an unlit tunnel's lid, under it

pieces: list[dict] = []
zones: list[dict] = []
# Hinged doors (DO1): a wall gap and the state it starts each round in ("open" or "shut").
DOORS: list[dict] = []
_HUT_N = [0]
_TAG = [""]


def default_h(kind: str) -> float:
    return {"wall": 2.6, "net": 2.8, "hut": 2.6, "drums": 1.75, "crates": 2.4, "pillar": ROOF, "container": 2.6,
            "wardrobe": 2.2, "barrels": 0.95, "lowcrate": 1.1, "sofa": 0.85, "desk": 0.8, "window": 2.6,
            "dead": DEAD_H, "lid": 0.15}[kind]


def add(kind, x1, z1, x2, z2, h=None, tag=""):
    p = {"kind": kind, "x1": min(x1, x2), "z1": min(z1, z2), "x2": max(x1, x2), "z2": max(z1, z2),
         "tag": tag or _TAG[0], "h": h if h is not None else default_h(kind)}
    pieces.append(p)
    return p


def box(kind, cx, cz, sx, sz, tag=""):
    add(kind, cx - sx / 2, cz - sz / 2, cx + sx / 2, cz + sz / 2, tag=tag)


def wall(kind, x1, z1, x2, z2, openings=()):
    """A wall from (x1, z1) to (x2, z2), along x or z, with openings (a, b, what) along it: "door" an open doorway,
    "window" a gap from sill to lintel, "dopen" / "dshut" a hinged door starting open or shut."""
    horiz = z1 == z2
    a0, a1 = sorted((x1, x2) if horiz else (z1, z2))
    pos, segs = a0, []
    for a, b, what in sorted(openings):
        if a > pos:
            segs.append((pos, a, kind))
        if what == "window":
            segs.append((a, b, "window"))
        if what in ("dopen", "dshut"):
            gap = (a, z1 - T / 2, b, z1 + T / 2) if horiz else (x1 - T / 2, a, x1 + T / 2, b)
            DOORS.append({"x1": gap[0], "z1": gap[1], "x2": gap[2], "z2": gap[3], "along_x": horiz,
                          "h": default_h(kind), "state": "open" if what == "dopen" else "shut"})
        pos = b
    if pos < a1:
        segs.append((pos, a1, kind))
    for s, e, k in segs:
        if horiz:
            add(k, s, z1 - T / 2, e, z1 + T / 2)
        else:
            add(k, x1 - T / 2, s, x1 + T / 2, e)


def hut(x1, z1, x2, z2, doors, windows):
    _HUT_N[0] += 1
    _TAG[0] = f"hut{_HUT_N[0]}"
    for side, (sx1, sz1, sx2, sz2) in {"n": (x1, z1, x2, z1), "s": (x1, z2, x2, z2),
                                        "w": (x1, z1, x1, z2), "e": (x2, z1, x2, z2)}.items():
        ops = [(d[0], d[1], d[2] if len(d) > 2 else "door") for d in doors.get(side, [])]
        ops += [(a, b, "window") for a, b in windows.get(side, [])]
        wall("hut", sx1, sz1, sx2, sz2, ops)
    _TAG[0] = ""


def container_row(x1, x2, zc, ports):
    """Containers end to end along x from x1 to x2, 2.4 m deep round z = zc, with a port cut through each (a, b)."""
    pos = x1
    for a, b in sorted(ports) + [(x2, x2)]:
        if a > pos:
            add("container", pos, zc - 1.2, a, zc + 1.2)
        if b > a:
            add("window", a, zc - 1.2, b, zc + 1.2, tag="port")
        pos = b


def zone(name, lane, x1, z1, x2, z2, light="lit"):
    """A walkable rectangle and its callout name. lane: n, m, s, x (a link) or end (a spawn). light: lit, dim or dark
    (an unlit tunnel: a lid over it at LID_H, no roof lamp)."""
    zones.append({"name": name, "lane": lane, "x1": x1, "z1": z1, "x2": x2, "z2": z2, "light": light})
    if light == "dark":
        add("lid", x1, z1, x2, z2)


# ================================================================ ZONES
# West end (Beta in Elimination, attackers in Attack / Defend at the start)
zone("Staging", "end", -54, -13, -44, 4.5)        # its chicanes too
zone("North stairs", "n", -52, -22, -45, -13)
zone("Yard", "n", -54, -35, -36, -22)
zone("Shoot House", "n", -36, -35, -10, -20)
zone("Mid exit", "m", -44, -6, -34, 2)
zone("Upper mid", "m", -34, -16, -20, 2)
zone("Doors", "m", -20, -16, -12, -8)
zone("South stairs", "s", -52, 4.5, -45, 16)
zone("Pens", "s", -54, 16, -36, 35)
zone("Huts", "s", -36, 18, -12, 35)
# Centre
zone("Lounge", "n", -10, -33, 10, -18, light="dim")
zone("Chrono hall", "m", -12, -14, 14, 8)
zone("Box yard", "s", -12, 13, 12, 32)
# East end (Alpha in Elimination, defenders in Attack / Defend)
zone("Offices", "n", 10, -35, 30, -22)
zone("A site", "n", 30, -35, 54, -17)
zone("A stairs", "n", 46, -17, 53, -4)
zone("Loading bay", "end", 44, -4, 54, 13)         # its chicanes too
zone("Lower mid", "m", 14, -6, 30, 12)
zone("Garage", "m", 30, 0, 44, 8)
zone("B ramp", "s", 46, 13, 53, 17)
zone("Containers", "s", 12, 16, 32, 35)
zone("B site", "s", 32, 17, 54, 35)

# Links. Open links are 4 to 6 m wide; the two alleys stay tight (3 m); one unlit tunnel each half.
zone("Cut", "x", -30, -20.5, -25, -15.5)                         # Shoot House <-> Upper mid, open
zone("Side alley", "x", -40, -22.5, -37, -5.5)                   # Yard <-> Mid exit, tight
zone("Gallery", "x", -6, -18.5, 0, -13.5)                        # Lounge <-> Chrono hall, open
zone("Drum alley", "x", -8, 7.5, -2, 13.5)                       # Chrono hall <-> Box yard, open
zone("West tunnel", "x", -31, 1.5, -28, 9.5, light="dark")       # Upper mid <-> Huts, unlit, two bends
zone("West tunnel", "x", -31, 7, -22, 10, light="dark")
zone("West tunnel", "x", -25, 7, -22, 18.5, light="dark")
zone("East tunnel", "x", 20, -22.5, 23, -14.5, light="dark")     # Offices <-> Lower mid, unlit, two bends
zone("East tunnel", "x", 20, -17, 27, -14, light="dark")
zone("East tunnel", "x", 24, -17, 27, -5.5, light="dark")
zone("A short", "x", 36, -17.5, 41, -8)                          # A site <-> Garage, open, one bend
zone("A short", "x", 33, -10, 41, -5)
zone("A short", "x", 33, -6, 38, 0.5)
zone("Dock", "x", 18, 11.5, 24, 16.5)                            # Lower mid <-> Containers, open
zone("B alley", "x", 38, 7.5, 41, 17.5)                          # Garage <-> B site, tight

# ================================================================ PIECES
# --- Staging (west spawn): gear racks screen the spawn from the Mid exit
add("crates", -46.4, -8.6, -45.6, 1.2)
# Each stairs mouth is a chicane of two screens, so no straight line from the Yard, the Pens or the stairs reaches a
# spawn (DR1 critic): in by the screen's west gap, along between them, out by the inner screen's east gap.
# The corridor between is 3 m and the gaps 2 m (outer, by the stairs' rack) to 2.6 m, so a squad following its leader
# out doesn't queue (the follow guard).
# The outer screen's gap ends west of the spawn line and the inner one's starts east of it, so no line through both
# reaches a spawn.
add("crates", -50.0, -13.5, -45.0, -12.5)             # north stairs screen, gap west
add("crates", -54.0, -9.5, -49.0, -8.5)               # inner screen, gap east
add("crates", -50.0, 4.5, -45.0, 5.5)                 # south stairs screen, gap west
add("crates", -54.0, 0.5, -49.0, 1.5)                 # inner screen, gap east
# Eight a side (8v8, TS1), 1 m apart between the inner screens: 0.75 m clear of the north one, 1.25 m of the south.
SPAWNS_W = [(-50.0, -7.75 + i) for i in range(8)]
DEAD_W = (-52.8, -4.5)                                # the dead zone, behind the spawn line

# --- Yard (18 x 13): the west end room
box("crates", -46.0, -29.0, 2.4, 2.4)
box("lowcrate", -50.5, -25.0, 3.0, 1.0)
box("drums", -40.0, -31.5, 1.8, 1.8)
box("barrels", -52.2, -33.5, 1.3, 0.65)
box("lowcrate", -42.0, -24.5, 1.0, 2.6)

# --- Shoot House (26 x 15): two rows of rooms
wall("wall", -36, -35, -36, -22, [(-33, -31, "dshut"), (-27, -25, "door")])
wall("wall", -10, -33, -10, -20, [(-31.5, -29.5, "dshut"), (-24, -22, "door")])
wall("wall", -36, -28, -10, -28, [(-34, -32, "door"), (-24, -22, "dshut"), (-15, -13, "dopen")])
wall("wall", -27, -35, -27, -28, [(-31.6, -29.6, "dopen")])
wall("wall", -19, -28, -19, -20, [(-22, -20, "door")])
box("drums", -19.0, -30.5, 1.8, 1.8)
box("desk", -32.0, -22.5, 2.2, 1.0)
box("barrels", -13.5, -25.0, 0.65, 1.3)
box("lowcrate", -23.0, -32.5, 1.0, 2.4)

# --- Upper mid (14 x 18) and the Doors gate
box("crates", -27.5, -6.5, 2.4, 2.4)
box("lowcrate", -31.0, -12.5, 3.0, 1.0)
box("lowcrate", -22.5, -1.0, 1.0, 2.6)
box("barrels", -21.0, -12.0, 0.65, 1.3)
box("barrels", -38.0, 0.5, 1.3, 0.65)
wall("wall", -16, -16, -16, -8, [(-14, -11, "door")])

# --- Pens (18 x 19): netting pens
wall("net", -46, 16, -46, 22)
wall("net", -46, 27, -41, 27)
box("crates", -41.0, 21.0, 2.4, 2.4)
box("lowcrate", -50.0, 30.5, 3.0, 1.0)
box("drums", -51.0, 20.0, 1.8, 1.8)
box("barrels", -43.0, 33.0, 1.3, 0.65)
wall("net", -36, 16, -36, 35, [(20, 24, "door"), (28.5, 32.5, "door")])

# --- Huts (24 x 17)
hut(-32, 21, -26, 26, doors={"w": [(22, 24, "dshut")], "s": [(-30, -28)]}, windows={"n": [(-30, -28)]})
hut(-21, 28, -15, 34.7, doors={"n": [(-19, -17, "dopen")]}, windows={"w": [(30, 31.5)]})
box("drums", -23.8, 27.2, 1.8, 1.8)
box("barrels", -19.0, 22.0, 1.3, 0.65)
wall("wall", -12, 18, -12, 22.5)
wall("wall", -12, 26.5, -12, 35)                  # Huts open into the Box yard through one 4 m gap, behind the Box

# --- Lounge (20 x 15, dim)
add("wall", -0.15, -33, 0.15, -24)
box("sofa", -5.0, -28.0, 1.0, 3.2)
box("desk", 4.0, -20.0, 2.2, 1.0)
box("wardrobe", 7.0, -23.5, 1.0, 2.0)                # in front of the Offices door: no line down the corridor
box("barrels", -7.0, -31.5, 1.3, 0.65)
box("crates", 4.5, -29.0, 2.0, 2.0)
wall("wall", 10, -33, 10, -22, [(-31, -29, "dshut"), (-25, -23, "dopen")])

# --- Chrono hall (26 x 22): the chrono hut holds the overtime flag
hut(-3.5, -5.5, 2.5, -0.5, doors={"n": [(-1.5, 0.5, "dopen")], "s": [(-1.5, 0.5, "dshut")]}, windows={"w": [(-4.8, -3.4)], "e": [(-2.6, -1.2)]})
box("pillar", -6.0, -9.0, 0.6, 0.6)
box("pillar", 8.0, 3.0, 0.6, 0.6)
add("crates", -9.0, 0.0, -7.0, 5.0)
box("drums", 8.5, -9.5, 1.8, 1.8)
box("lowcrate", -4.0, 5.0, 2.6, 1.0)
box("lowcrate", 10.5, -3.5, 1.0, 3.0)
box("barrels", 12.0, 6.0, 1.3, 0.65)
add("crates", -1.2, -14, 1.2, -11.6)               # off the Gallery mouth: no line from the Doors to the Arch
OT_FLAG = (-0.5, -3.0)

# --- Lower mid (16 x 18): the Arch is a wide opening into the hall
wall("wall", 14, -6, 14, -2)
box("crates", 22.0, 2.0, 2.4, 2.4)
box("lowcrate", 18.0, 9.0, 3.0, 1.0)
box("lowcrate", 27.5, -2.5, 1.0, 2.6)
box("drums", 27.0, 9.5, 1.8, 1.8)
box("barrels", 36.0, 6.5, 1.3, 0.65)
add("crates", 37.4, 0.0, 38.6, 4.5)                   # the Garage dog-leg: no line from the hall to the bay
add("crates", 31.4, 4.5, 32.6, 8.0)

# --- Offices (20 x 13): a corridor along the south with rooms off it
wall("wall", 10, -26, 30, -26, [(12.5, 14.5, "door"), (19.5, 21.5, "dshut"), (26, 28, "dopen")])
wall("wall", 17, -35, 17, -26, [(-31, -29, "door")])
wall("wall", 24, -35, 24, -26, [(-33, -31, "dshut")])
wall("wall", 30, -35, 30, -22, [(-33, -31, "dopen"), (-24.5, -22.5, "door")])
box("drums", 16.5, -24.2, 1.8, 1.8)
box("desk", 20.5, -31.5, 2.2, 1.0)
box("barrels", 27.0, -33.5, 1.3, 0.65)

# --- A site (24 x 18)
box("crates", 36.0, -30.0, 2.4, 2.4)
box("lowcrate", 47.5, -21.0, 3.0, 1.0)
box("drums", 50.5, -32.0, 1.8, 1.8)
box("lowcrate", 39.5, -23.5, 1.0, 2.6)
box("barrels", 33.0, -19.0, 1.3, 0.65)
box("crates", 32.4, -23.5, 1.2, 2.4)                  # default box inside the Offices door
# MB1: the site's two stacks are set by the pole's lines. The flag stack stands between the pole and both Offices
# doors, so whoever is at the pole (the defender holding it, later whoever raises) is hidden from the way the attack
# comes in and is cleared only by swinging wide round a crate or by the A short mouth behind them. The stairs stack
# stands between the pole and the A stairs mouth, so a raise is not shot down from the defenders' own stairs: they
# come onto the site to stop it.
box("crates", 41.5, -27.2, 1.2, 2.4)                  # the flag stack
box("crates", 46.2, -23.8, 2.4, 1.2)                  # the stairs stack
box("pillar", 41.0, -20.5, 0.6, 0.6)
FLAG_A = (44.0, -27.0)

# --- Loading bay (east spawn)
add("crates", 45.6, -1.2, 46.4, 8.6)
# Each mouth is a chicane of two screens, so no straight line from A site, the stairs, the ramp or B site reaches a
# spawn (DR1 critic: one screen left the east wall a 70 m lane through the spawn): in by the screen's east gap, along
# between them, out by the inner screen's west gap.
add("crates", 45.5, -5.0, 50.0, -4.0)                 # stairs screen, gap east
add("crates", 49.0, -1.0, 54.0, 0.0)                  # inner screen, gap west
add("crates", 45.5, 13.0, 50.0, 14.0)                 # ramp screen, gap east
add("crates", 49.0, 9.0, 54.0, 10.0)                  # inner screen, gap west
SPAWNS_E = [(50.0, 0.75 + i) for i in range(8)]   # the west line mirrored
DEAD_E = (52.8, 4.5)

# --- Containers (20 x 19): stacked containers make three corridors
container_row(15, 27, 20.75, [(20, 22)])
container_row(17, 29, 28.25, [(22, 24)])
box("crates", 14.0, 33.0, 2.4, 2.4)
box("lowcrate", 25.0, 24.5, 1.0, 2.6)
box("barrels", 30.0, 32.5, 0.65, 1.3)
wall("wall", 32, 17, 32, 35, [(18.5, 22.5, "door"), (29.5, 33.5, "door")])
wall("wall", 12, 21, 12, 32)                      # Box yard to Containers: one 5 m opening at the north end
box("crates", 29.4, 18.4, 1.2, 2.4)               # off the B door: no line down the north corridor

# --- B site (22 x 18)
box("crates", 38.0, 30.0, 2.4, 2.4)
box("lowcrate", 47.5, 21.0, 3.0, 1.0)
box("drums", 51.0, 32.0, 1.8, 1.8)
box("lowcrate", 41.0, 23.5, 1.0, 2.6)
box("crates", 34.5, 21.0, 1.2, 3.0)                  # default box inside the north B door
# MB1: as on A, the flag stack between the pole and both Containers doors, the ramp stack between it and the B ramp
# mouth; the B alley mouth is the way round both.
box("crates", 42.5, 27.6, 1.2, 2.4)                   # the flag stack
box("crates", 47.0, 24.4, 2.4, 1.2)                   # the ramp stack
box("pillar", 40.5, 26.5, 0.6, 0.6)
FLAG_B = (45.0, 28.0)

# --- Box yard (24 x 19): the Box, a crate stack off each end
wall("container", -5, 21.15, 7, 21.15, [(0, 2, "window")])
wall("container", -5, 23.35, 7, 23.35, [(0, 2, "window")])
add("container", -5, 21.0, 7, 23.5, h=0.2, tag="boxroof")     # the Box's roof, from 2.6 m
box("crates", -7.2, 22.25, 2.4, 2.3)
box("crates", 9.2, 22.25, 2.4, 2.3)
box("crates", -3.0, 28.5, 2.4, 2.4)
box("lowcrate", 4.0, 16.0, 2.6, 1.0)
add("crates", -9.0, 16.0, -3.5, 17.0)                # screens the Drum alley mouth: no 65 m line from the Lounge
box("crates", 10.5, 17.5, 2.4, 2.4)                   # breaks the strip from the Huts to B
box("barrels", 8.5, 29.5, 1.3, 0.65)


FLAGS = [FLAG_A, FLAG_B]

# ================================================================ the bots' lanes (end 0's side to end 1's)
# MB1: the north and south lanes end ON the sites. Attack / Defend's defenders hold a lane's last two points
# (RoundPlanner), and those were the foot of the A stairs and the B ramp, outside the sites and open to them: now one
# holds the pole from behind its flag stack and one the low crate by the stairs (ramp) mouth, across the pole from it.
# The middle lane's two posts are behind the Garage dog-leg's two stacks (they stood in the open beside them).
LANES = {
    "n": [(-51.2, -14.5), (-48.5, -16), (-46.5, -21.5), (-42.6, -26.4), (-36, -26), (-28, -24.5),
          (-19, -21), (-11.5, -22.6), (-6, -22), (3, -21.2), (10, -24), (18, -24), (27, -24), (30, -23.5),
          (36, -25), (41.5, -24.8), (42.9, -27.2), (47.7, -19.6)],
    "m": [(-40, -1), (-30, -8.5), (-23, -12.5), (-16, -12.5), (-9, -7.5), (-1, -7), (8, -5),
          (15, 0), (19, 5.5), (25.5, 4.6), (29.5, 2.2), (34, 2.2), (33.8, 6.3), (40.3, 2.3)],
    "s": [(-51.2, 6.5), (-48.5, 10), (-48.5, 15), (-45, 19), (-37, 22), (-30, 19.5), (-21, 19.5),
          (-14, 24.5), (-9.5, 24.6), (-8, 19.5), (-4, 18.2), (5, 18.8), (12, 18.6), (20, 18.6), (27.5, 18.4),
          (31, 20.5), (33, 18.8), (39, 20.5), (42.8, 23.0), (43.9, 27.7), (47.6, 19.6)],
}


# ================================================================ dead space: what no zone covers, greedy-meshed
def _dead_blocks(res: float = 0.5) -> list[tuple[float, float, float, float]]:
    nx, nz = int(2 * W / res), int(2 * H / res)
    open_ = [[False] * nz for _ in range(nx)]
    for zn in zones:
        i1, i2 = int(round((zn["x1"] + W) / res)), int(round((zn["x2"] + W) / res))
        j1, j2 = int(round((zn["z1"] + H) / res)), int(round((zn["z2"] + H) / res))
        for i in range(i1, i2):
            for j in range(j1, j2):
                open_[i][j] = True
    used = [[False] * nz for _ in range(nx)]
    out = []
    for i in range(nx):
        for j in range(nz):
            if open_[i][j] or used[i][j]:
                continue
            j2 = j
            while j2 + 1 < nz and not open_[i][j2 + 1] and not used[i][j2 + 1]:
                j2 += 1
            i2 = i
            while i2 + 1 < nx and all(not open_[i2 + 1][k] and not used[i2 + 1][k] for k in range(j, j2 + 1)):
                i2 += 1
            for a in range(i, i2 + 1):
                for k in range(j, j2 + 1):
                    used[a][k] = True
            out.append((-W + i * res, -H + j * res, -W + (i2 + 1) * res, -H + (j2 + 1) * res))
    return out


for _x1, _z1, _x2, _z2 in _dead_blocks():
    add("dead", _x1, _z1, _x2, _z2)
