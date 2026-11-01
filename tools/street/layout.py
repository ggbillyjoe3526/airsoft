"""The Street (owner's concept 3, 2026-11-01): the layout as data (metres). x east+, z south+. North is up on the plan.

Laid out from the owner's own plan of a real street (never named or pictured here), then tuned for play
(concept 3's notes: /mnt/project-files/concepts/suburban-street/v3/notes.md, outside the repository). Three lanes run north-south. Left: the road behind the west terrace's back gardens. Middle: the Path between the
fronts of two terraces. Right: the back lane behind the east terrace, and the right road beyond the old works.
Alpha defends from the railway embankment (north); Beta attacks from the Bottom street (south).
A = the House's living room, B = the car park by the arch building.
"""
from __future__ import annotations

import random

import numpy as np

W, H = 52.0, 81.0  # half sizes: 104 x 162 m
T = 0.3
DEAD_H = 2.2

TALL = {"kiosk", "hoarding", "door", "doorleaf", "hwall", "fence", "hedge", "shed", "van", "lorry", "stairs", "fridge", "binstore", "tree",
        "dead", "house", "flats", "shop", "works", "lamp", "phone", "pillar", "gateleaf", "wardrobe"}
LOW = {"cabinet", "lowhedge", "lowwall", "car", "bins", "skip", "bench", "table", "sofa", "units", "tramp", "bollard", "railing",
       "kerbwall"}
SEE_THROUGH = {"window", "glass", "openwin", "frame", "shelter", "railing"}  # block walking, not sight
WALKABLE_KINDS = {"lid", "door", "doorleaf", "upper", "road", "kerb"}  # doors open on use, so routes go through them
HEIGHTS = {"kiosk": 2.2, "cabinet": 1.2, "hwall": 2.7, "fence": 1.83, "hedge": 1.9, "lowwall": 0.9, "car": 1.5, "van": 2.4, "lorry": 3.2, "shed": 2.3,
           "bins": 1.15, "skip": 1.4, "bench": 0.5, "table": 0.78, "sofa": 0.85, "units": 0.92, "fridge": 1.85,
           "stairs": 2.7, "binstore": 2.0, "tree": 6.5, "lamp": 5.0, "phone": 2.4, "window": 2.7, "glass": 2.7,
           "openwin": 2.7, "frame": 2.2, "shelter": 2.5, "tramp": 0.9, "door": 2.1, "doorleaf": 2.1, "dead": DEAD_H,
           "lid": 2.75, "bollard": 0.9, "pillar": 2.75, "railing": 1.0, "gateleaf": 1.83, "wardrobe": 2.0,
           "kerbwall": 0.45, "lowhedge": 1.0}

pieces: list[dict] = []
zones: list[dict] = []
buildings: list[dict] = []
DOORS: list[dict] = []
rng = random.Random(11)


def add(kind, x1, z1, x2, z2, h=None, tag="", **extra):
    p = {"kind": kind, "x1": min(x1, x2), "z1": min(z1, z2), "x2": max(x1, x2), "z2": max(z1, z2), "tag": tag}
    p["h"] = h if h is not None else HEIGHTS[kind]
    p.update(extra)
    pieces.append(p)
    return p


def box(kind, cx, cz, sx, sz, **kw):
    return add(kind, cx - sx / 2, cz - sz / 2, cx + sx / 2, cz + sz / 2, **kw)


def line(kind, x1, z1, x2, z2, openings=(), th=None, tag=""):
    """A wall, fence or hedge along x (z1 == z2) or z (x1 == x2), with openings (a, b, what): what = gap, window,
    dopen, dshut."""
    th = th if th is not None else (T if kind == "hwall" else (0.9 if kind == "hedge" else 0.2))
    horiz = z1 == z2
    a0, a1 = sorted((x1, x2) if horiz else (z1, z2))
    pos, segs = a0, []
    for a, b, what in sorted(openings):
        if a > pos:
            segs.append((pos, a, kind))
        if what in ("window", "openwin", "glass"):
            segs.append((a, b, what))
        if what in ("dopen", "dshut"):
            add_door(x1, z1, horiz, a, b, "open" if what == "dopen" else "shut", th)
        pos = b
    if pos < a1:
        segs.append((pos, a1, kind))
    for s, e, k in segs:
        if horiz:
            add(k, s, z1 - th / 2, e, z1 + th / 2, tag=tag)
        else:
            add(k, x1 - th / 2, s, x1 + th / 2, e, tag=tag)


def add_door(x1, z1, horiz, a, b, state, th):
    w = b - a
    if horiz:
        gap = (a, z1 - th / 2, b, z1 + th / 2)
        leaf = (a, z1 + th / 2, a + 0.06, z1 + th / 2 + w)
    else:
        gap = (x1 - th / 2, a, x1 + th / 2, b)
        leaf = (x1 + th / 2, a, x1 + th / 2 + w, a + 0.06)
    DOORS.append({"x1": gap[0], "z1": gap[1], "x2": gap[2], "z2": gap[3], "state": state, "horiz": horiz, "leaf": leaf})
    if state == "shut":
        add("door", *gap)
    else:
        add("doorleaf", *leaf)


def zone(name, lane, x1, z1, x2, z2, ground="grass", light="open"):
    """A walkable rectangle. lane: l, m, r, h (the House), x (link), end (spawn street). ground: road, pave, grass,
    path, tarmac, floor (indoors), setts (under an arch). light: open, roofed (arch or indoors)."""
    zones.append({"name": name, "lane": lane, "x1": x1, "z1": z1, "x2": x2, "z2": z2, "ground": ground, "light": light})
    if light == "roofed" and ground != "floor":
        add("lid", x1, z1, x2, z2)


def building(kind, x1, z1, x2, z2, eaves, ridge="z", roof=2.6, colour=0, label=""):
    """kind: house (pitched roof), flats (three storeys, shallow roof), shop (flat roof)."""
    b = {"kind": kind, "x1": x1, "z1": z1, "x2": x2, "z2": z2, "eaves": eaves, "ridge": ridge, "roof": roof,
         "colour": colour, "label": label}
    buildings.append(b)
    add(kind, x1, z1, x2, z2, h=eaves)


def terrace(x1, x2, z1, z2, unit=6.0, ridge="z", front="w"):
    """A row of terraced houses, each its own colour; front = the side with the front doors (w or e)."""
    z = z1
    while z < z2 - 0.01:
        e = min(z + unit, z2)
        if z2 - e < 3:
            e = z2
        building("house", x1, z, x2, e, 5.4, ridge, 2.8, colour=rng.randrange(6))
        z = e




def hterrace(x1, x2, z1, z2, unit=6.0):
    """A row of houses running east-west (ridge along x)."""
    x = x1
    while x < x2 - 0.01:
        e = min(x + unit, x2)
        if x2 - e < 3:
            e = x2
        building("house", x, z1, e, z2, 5.4, "x", 2.8, colour=rng.randrange(6))
        x = e


def plots(z1, z2, unit, exclude=()):
    """Split z1..z2 minus the excluded spans into plots of about `unit` m: yields (a, b, i, first, last)."""
    spans, z = [], z1
    for a, b in sorted(exclude):
        if b <= z1 or a >= z2:
            continue
        if a > z:
            spans.append((z, a))
        z = max(z, b)
    if z < z2:
        spans.append((z, z2))
    i = 0
    for a, b in spans:
        n = max(1, round((b - a) / unit))
        step = (b - a) / n
        for k in range(n):
            yield a + k * step, a + (k + 1) * step, i, k == 0, k == n - 1
            i += 1


# ================================================================ ZONES
# --- North: the railway embankment (Alpha spawn) and the Field
zone("Embankment", "end", -17, -66, 26, -60, ground="grass")
zone("Field", "x", -17, -60, 26, -46, ground="grass")
# --- Left lane
zone("Top path", "l", -47, -42, -17, -38, ground="pave")
zone("Left road", "l", -47, -46, -40, 74, ground="road")
zone("Parking bays", "l", -50, -42, -47, 18, ground="tarmac")
zone("Verge", "l", -50, 18, -47, 74, ground="grass")
zone("Back footpath", "l", -40, -38, -38, 18, ground="pave")
zone("Cul-de-sac", "l", -40, 34, -24, 40, ground="road")
zone("Grass", "l", -40, 30, -24, 34, ground="grass")
zone("Corner green", "l", -40, 40, -24, 48, ground="grass")
# --- The House (flag A): back (west) x -31, front (east) x -22, z -8 .. 0
zone("Living room", "h", -31, -8, -26, 0, ground="floor", light="roofed")
zone("Hall", "h", -26, -8, -22, -6.4, ground="floor", light="roofed")
zone("Kitchen", "h", -26, -6.4, -22, 0, ground="floor", light="roofed")
zone("Back garden", "l", -38, -8, -31, 0, ground="grass")
# --- Middle: the Path between the fronts of the two terraces; it steps east by its own width at the Green corner
zone("The path", "m", -17, -46, -13.5, 2, ground="path")
zone("The path", "m", -12, 2, -8.5, 49.5, ground="path")
zone("Path kink", "m", -16, 46, -8.5, 49.5, ground="path")
zone("The path", "m", -16, 49.5, -12.5, 74, ground="path")
zone("Path jog", "m", -17, -2, -8.5, 2, ground="path")
zone("Front gardens", "m", -22, -38, -17, 2, ground="grass")
zone("Front gardens", "m", -22, 2.4, -12, 18, ground="grass")
zone("Grass", "m", -26, 18, -12, 30, ground="grass")
zone("Cul-de-sac", "m", -24, 30, -12, 46, ground="tarmac")
zone("Front green", "m", -24, 46, -16, 74, ground="grass")
zone("Front gardens", "m", -8.5, 2, -5, 49.5, ground="grass")
zone("Front gardens", "m", -12.5, 49.5, -5, 74, ground="grass")
zone("Path verge", "m", -13.5, -46, -10, -26, ground="grass")
zone("Green corner", "m", -13.5, -6, 9, 2, ground="grass")
zone("Path jog", "m", -12, 2, -8.5, 2.4, ground="path")
# --- B and the right lane
zone("The Lane", "x", -13.5, -29, 26, -26, ground="pave")
zone("Car park", "r", -11, -24, 10, -6, ground="tarmac")
zone("Car park verge", "r", -13.5, -26, -11, -6, ground="grass")
zone("Car park gate", "r", -7, -26, -1, -24, ground="tarmac")
zone("Arch", "x", 10, -12, 20, -9, ground="setts", light="roofed")
zone("Arch", "x", 20, -12, 26, -9, ground="pave")
zone("Right road", "r", 26, -60, 34, 2, ground="road")
zone("Road verge", "r", 21, -46, 26, -29, ground="grass")
zone("Yard", "r", 9, -3, 34, 14, ground="tarmac")
zone("Junction", "r", 26, -3, 42, 6, ground="road")
zone("Right road", "r", 34, -3, 42, 74, ground="road")
zone("Parking bays", "r", 42, 6, 45, 74, ground="tarmac")
zone("Back lane", "r", 9, 14, 14, 74, ground="path")
zone("Back lane", "r", 9, 2, 14, 14, ground="path")
# --- South: the Bottom street (Beta spawn)
zone("Bottom street", "end", -50, 74, 45, 80, ground="road")
# enclosed back gardens are drawn as gardens but have no way in (6 ft fences, gates shut)
GARDENS_W = (-38, -31)
GARDENS_E = (4, 9)
zone("Back gardens", "g", -38, -38, -31, -8, ground="grass")
zone("Back gardens", "g", -38, 0, -31, 18, ground="grass")
zone("Back gardens", "g", -40, 48, -32, 74, ground="grass")
zone("Back gardens", "g", 4, 2, 9, 74, ground="grass")

# ================================================================ BUILDINGS
# backdrop houses beyond the play space (their own random colours so the play space's draws don't change); the rest
# of the edge is gardens and scrub ("dead" space)
brng = random.Random(5)
for bx in range(-52, -17, 7):
    building("house", bx, -50, min(bx + 7, -17), -42, 5.4, "x", 2.8, colour=brng.randrange(6))
for bz in range(-60, -3, 6):
    building("house", 37, bz, 45, min(bz + 6, -3), 5.4, "z", 2.8, colour=brng.randrange(6))
for bz in range(0, 74, 6):
    building("house", 46, bz, 52, min(bz + 6, 74), 5.4, "z", 2.8, colour=brng.randrange(6))
terrace(-31, -22, -38, -17, unit=7.0)                                          # west terrace, fronts face the Path
terrace(-31, -22, -14, -8, unit=6.0)
terrace(-31, -22, 0, 18, unit=6.0)
hterrace(-40, -26, 18, 30, unit=7.0)                                           # its south end turns east-west
terrace(-32, -24, 48, 74, unit=6.5)                                            # the lower terrace
hterrace(-10, 12, -44, -31, unit=5.5)                                          # the horizontal houses
building("house", -10, -46, 12, -44, 0.01, "x", 0.0)                           # (their back gardens: drawn below)
pieces.pop(); buildings.pop()
building("house", 10, -26, 20, -12, 5.4, "z", 2.8, colour=2, label="")         # the arch building
building("house", 10, -9, 20, -3, 5.4, "z", 2.8, colour=2)
terrace(-5, 4, 2, 74, unit=6.0)                                                # east terrace, fronts face the Path
building("works", 14, 14, 34, 74, 7.5, "z", 0.0, colour=0, label="Old works")
HOUSE = {"x1": -31, "z1": -8, "x2": -22, "z2": 0, "ext": None}
ARCHES = [(10, -12, 20, -9, 5.4)]

# ================================================================ PIECES
SPAWNS_N = [(x, -64.0) for x in (-2.0, 1.0, 4.0, 7.0, 10.0, 13.0)]
SPAWNS_S = [(x, 78.0) for x in (-1.0, 2.0, 5.0, 8.0, 11.0, 14.0)]

# --- Embankment: scrub along the railway screens the spawn; gaps at the ends
line("hedge", -4, -60.5, 19, -60.5)
line("hedge", -4, -63.5, -4, -60.5)
line("hedge", 19, -63.5, 19, -60.5)
line("hedge", -8, -64.5, -8, -59.0)
line("hedge", 23, -64.5, 23, -59.0)
for x in (-12, 22.5):
    box("tree", x, -64.5, 0.5, 0.5)
add("bollard", 26, -60.2, 34, -59.9)
# Field: a few lone trees on the grass, the horizontal houses' back fences on its south side
for x, z in ((-6, -55), (8, -57), (16, -51)):
    box("tree", x, z, 0.5, 0.5)
line("fence", -10, -46, 12, -46, th=0.15)
line("fence", 12, -46, 12, -29, th=0.15)
line("fence", 21, -46, 21, -29, th=0.15)
box("bins", 0.5, -28.4, 1.4, 0.7)

# --- Top path: bollards closing the road's north end, a lamp
add("bollard", -47, -46.2, -40, -45.9)
box("lamp", -20, -38.4, 0.25, 0.25)

# --- Left road: bays down the west side in the north, grass verge in the south; two vans and a lorry break the lines
for z in (-39, -27, -15, -3, 3):
    box("car", -48.5, z, 1.9, 4.4)
box("van", -48.5, -9, 2.1, 5.6)
# Roadworks across the west two-thirds of the road (solid hoarding round a dug-up patch), then a removal lorry
# parked half on the footpath: together they stop any line running the length of the road.
ROADWORKS = (-50, 8, -41, 16)
add("hoarding", -50, 8, -41, 16, h=2.2)        # a closed compound: nobody goes in
box("lorry", -41.1, 25.5, 5.6, 7.0)
for z in (44, 62):
    box("car", -41.0, z, 1.9, 4.4)
for z in (24, 38, 52, 66):
    box("tree", -48.6, z, 0.5, 0.5)       # trees on the verge, clear of the road
for z in (-30, 0, 30, 60):
    box("lamp", -39.8, z, 0.25, 0.25)

# --- Back footpath and back gardens: 6 ft fences on the footpath, gates shut except the House's
line("fence", -38.1, -38, -38.1, 18, [(-17, -14, "gap"), (-7.6, -6.4, "gap")], th=0.15)
for z, e, i, first, last in plots(-38, 18, 6.0, [(-17, -14), (-8, 0)]):
    if not last:
        line("fence", -38, e, -31, e, th=0.15)
# fences round the pend's passage and the House's garden
for zz in (-17, -14, -8, 0, -38, 18):
    line("fence", -38, zz, -31, zz, th=0.15)
# lower terrace back gardens (behind the verge side of the road)
line("fence", -40.1, 48, -40.1, 74, th=0.15)
for z, e, i, first, last in plots(48, 74, 6.5):
    line("fence", -40, e, -32, e, th=0.15)
line("fence", -40, 48, -32, 48, th=0.15)

# --- Pend (left <-> mid): through the back gardens, under the terrace, out through the front gardens
zone("Pend", "x", -38, -17, -31, -14, ground="pave")
zone("Pend", "x", -31, -17, -22, -14, ground="setts", light="roofed")
building("house", -31, -17, -22, -14, 5.4, "z", 2.8, colour=1)
pieces.pop()                                                                  # the arch itself is open underneath
ARCHES.append((-31, -17, -22, -14, 5.4))
buildings.pop()
line("railing", -22, -14, -17.1, -14, th=0.08)
box("bins", -29.5, -16.4, 1.4, 0.7)

# --- The House
# Doors are 0.9 m: each leaf (half its width) folds back flat against the wall beside its gap (DO1), clear of the
# corner walls; `side` is the face it hangs on (1: +x, -1: -x). The back door opens into the living room, the hall
# door back into the living room, the front door out over the front garden.
line("hwall", -31, -8, -31, 0, [(-7.3, -6.4, "dshut"), (-4.6, -1.6, "window")])     # back: door left of the window
DOORS[-1]["side"] = 1
line("hwall", -31, -8, -22, -8)
line("hwall", -31, 0, -22, 0)
line("hwall", -26, -8, -26, 0, [(-7.3, -6.4, "dopen")])                               # living room -> hall door
DOORS[-1]["side"] = -1
line("hwall", -26, -6.4, -22, -6.4, [(-23.7, -22.6, "gap")])                          # hall -> kitchen, no door
line("hwall", -22, -8, -22, 0, [(-7.4, -6.5, "dshut"), (-5.0, -3.2, "openwin"), (-3.2, -1.4, "glass")])
DOORS[-1]["side"] = 1
for p in pieces:                                                                      # windows: glass, except the open half
    if p["kind"] == "window" and -31.3 < p["x1"] < -21.7 and -8 < p["z1"] < 0:
        p["kind"] = "glass"
add("sofa", -30.5, -0.8, -27.3, -0.1)          # sofa on the party wall
add("sofa", -27.0, -4.4, -26.3, -2.2)          # armchair
add("table", -29.6, -3.1, -28.4, -2.1)         # coffee table
add("units", -30.6, -5.6, -30.1, -4.8)         # TV unit
add("units", -25.9, -0.6, -22.4, -0.15)        # kitchen worktop on the party wall
add("fridge", -25.9, -6.25, -25.25, -5.55)
add("table", -25.0, -3.6, -23.8, -2.2)
FLAG_A = (-28.4, -5.0)
# back garden: shed, washing line, the gate left open
box("shed", -36.4, -1.6, 2.2, 2.4)
add("gateleaf", -38.1, -6.4, -37.2, -6.34)
# front garden: waist-high metal railings, gate gap in line with the front door
line("railing", -22, -8, -17.1, -8, th=0.08)
line("railing", -22, 0, -17.1, 0, th=0.08)
line("railing", -17.1, -8, -17.1, 0, [(-7.5, -6.4, "gap")], th=0.08)
box("bins", -21.3, -1.2, 0.7, 1.3)

# --- West front gardens: waist-high railings; the gates are shut except the pockets below, chosen for a reason
POCKETS = {"W3": "defenders' pocket by the Pend, facing the car park's Path gap, privet on the Pend side",
           "W5": "first garden past the Green corner, hidden from the north by the privet",
           "E5": "opposite the Cul-de-sac gap, hidden from the north by its hedge"}
for z, e, i, first, last in plots(-38, 18, 6.0, [(-17, -14), (-8, 2.4)]):
    xp = -17.1 if z < 2 else -12.1
    key = f"W{i}"
    line("railing", xp, z, xp, e, [(z + 2.0, z + 3.1, "gap")] if key in POCKETS else [], th=0.08)
    if key == "W3":
        add("hedge", -22, e - 0.9, xp + 0.05, e)          # privet on the Pend side: hidden from the attackers' Pend exit
        box("bins", -18.4, z + 1.6, 0.7, 1.4)
    elif key == "W5":
        box("bins", -14.0, e - 1.0, 1.4, 0.7)
    if i not in (3, 4) and e < 17.9:
        line("railing", -22, e, xp, e, th=0.08)
add("hedge", -22, 0.1, -17.05, 2.6)                   # the jog: a privet bed across the corner
add("hedge", -17.05, 2.4, -12.1, 2.9)

# --- East front gardens: railings, gates shut except the pocket opposite the Cul-de-sac
for z, e, i, first, last in [*plots(2, 49.5, 6.0), *plots(50.4, 74, 6.0)]:
    xp = -8.4 if z < 49 else -12.4
    key = f"E{i}" if z < 49 else ""
    line("railing", xp, z, xp, e, [(z + 2.6, z + 3.7, "gap")] if key in POCKETS else [], th=0.08)
    if key == "E5":
        line("hedge", xp, e, -5, e)                     # hides the pocket from the north
        box("bins", -6.0, z + 1.2, 1.4, 0.7)
    elif e < 73.9 and abs(e - 49.5) > 0.1:
        line("railing", xp, e, -5, e, th=0.08)
add("hedge", -8.4, 1.4, -5, 2.0)                       # the jog's other corner: a privet on the first front garden
add("binstore", -13.4, -5.0, -10.4, -3.0)
add("hedge", -12.5, 49.5, -5, 50.4)                     # the kink's corners: privet on the first garden past it
add("hedge", -24, 45.1, -12.1, 46.0)                    # and along the cul-de-sac car park's end              # and a bin store on the Green corner

# --- East back gardens (x 3 .. 9): 6 ft fences on the back lane, gates shut
line("fence", 9.1, 2, 9.1, 74, th=0.15)
for z, e, i, first, last in plots(2, 74, 6.0):
    if not last:
        line("fence", 4, e, 9, e, th=0.15)
line("fence", 4, 2, 9, 2, th=0.15)

# --- Back lane: only what a back lane holds. Three tall pieces alternate sides so no line runs its length (a
# substation kiosk, the works' van at its side door, the terrace's brick bin store); bins, a skip and a utility
# cabinet between them are the crouch hops.
add("kiosk", 9.2, 28.5, 11.8, 31.0)                    # electricity kiosk against the garden fences
box("van", 12.85, 45.0, 2.1, 5.6)                      # the works' van at its side door
add("binstore", 9.2, 58.5, 12.0, 61.5)                 # the terrace's bin store
box("bins", 13.3, 20.0, 0.7, 1.4)                      # the works' bins, the last hop before the yard
box("skip", 12.9, 36.5, 1.8, 3.6)
box("bins", 9.65, 52.0, 0.7, 1.4)
add("cabinet", 13.35, 66.0, 13.95, 67.2)               # telecoms cabinet near the bottom

# --- Grass and cul-de-sac (bottom left)
for x, z in ((-36, 31.5), (-30, 44.0), (-35, 45.5)):
    box("tree", x, z, 0.5, 0.5)
for x in (-22.5, -19.8, -17.1):
    box("car", x, 32.6, 1.9, 4.4)
box("van", -22.2, 42.2, 2.1, 5.6)
box("car", -19.0, 42.6, 1.9, 4.4)
add("kerbwall", -24, 30, -12.1, 30.3)
line("lowwall", -12.1, 30, -12.1, 46, [(36, 41, "gap")], th=0.25)
add("binstore", -15.0, 18.2, -12.2, 20.2)              # the lawn's bin store: the one hard cover on the open middle of the Path
for x, z in ((-20, 52), (-18.5, 63), (-21, 69)):
    box("tree", x, z, 0.5, 0.5)
line("railing", -24, 46, -24, 74, th=0.08)

# --- Green corner (south of the car park): grass with two trees off the path, a bench, the overtime flag
for x, z in ((-2, -2.5), (5.5, -1.0)):
    box("tree", x, z, 0.5, 0.5)
OT_FLAG = (-10.2, 8.5)

# --- Car park B: smaller, bays on two sides, the paved island in the middle, a van and a bin store
line("hedge", -11.2, -26, -11.2, -6, [(-21.0, -18.6, "gap")])
line("fence", -11, -24.4, 10, -24.4, [(-7, -1, "gap")], th=0.15)
line("lowwall", -11, -6.0, 9, -6.0, [(-4.0, 0.0, "gap"), (5.0, 9.0, "gap")], th=0.25)
zone("Island", "r", -4.5, -19.5, 3.5, -12.5, ground="setts")    # the paved island in the middle, planters at its corners
for cx, cz in ((-3.9, -18.9), (2.9, -18.9), (-3.9, -13.1), (2.9, -13.1)):
    box("lowhedge", cx, cz, 1.2, 1.2, h=0.8)
for x in (-9.0, -6.3, 3.6):
    box("car", x, -9.2, 1.9, 4.4)
for z in (-22.2, -19.5, -16.8):
    box("car", 7.6, z, 4.4, 1.9)
box("van", -8.6, -21.0, 2.1, 5.6)
box("car", 1.0, -9.2, 1.9, 4.4)
box("binstore", 7.8, -7.8, 3.0, 2.0)
box("lamp", 3.6, -16.0, 0.25, 0.25)
FLAG_B = (-1.0, -16.0)

# --- Arch building: the arch from the car park through to the right road, fenced gardens either side of its exit
line("fence", 20, -12, 26, -12, th=0.15)
line("fence", 20, -9, 26, -9, th=0.15)
line("fence", 25.9, -26, 25.9, -12, th=0.15)
line("fence", 25.9, -9, 25.9, -3, th=0.15)
box("bins", 12.0, -9.6, 1.4, 0.7)

# --- Right road (north): the access road beside the Field; (south): the old works on one side, bays on the other
box("lorry", 30.6, -50.0, 6.8, 2.6)                    # the works' lorry turned in the dead end: a one-at-a-time squeeze
for z in (-20,):
    box("car", 32.6, z, 1.9, 4.4)
box("van", 27.4, -34, 2.1, 5.6)
box("van", 27.3, -22.5, 2.1, 5.6)
for z in (-58, -48, -28, -10):
    box("lamp", 26.2, z, 0.25, 0.25)
for z, k in ((10, "car"), (21, "car"), (42, "van"), (46, "car"), (58, "car"), (70, "car")):
    box(k, 43.5, z, 1.9, 4.4 if k == "car" else 5.6)
for z, k in ((18, "van"), (54, "car"), (62, "van")):
    box(k, 35.2, z, 1.9, 4.4 if k == "car" else 5.6)
for z in (20, 44, 68):
    box("lamp", 34.2, z, 0.25, 0.25)
# A delivery jam: a lorry and a van double-parked on the east side, then a skip lorry and a van on the west side a
# little further on. The road stays open (one lane each time) but no line runs its length.
box("lorry", 40.7, 28.0, 2.6, 8.0)
box("van", 38.2, 29.0, 2.1, 5.6)
box("van", 43.5, 28.0, 2.1, 5.6)
box("lorry", 35.5, 44.0, 2.6, 8.0)
box("van", 38.0, 43.0, 2.1, 5.6)
# Yard: paved, two trees in a grass bed, parked cars, a skip
add("phone", 27.0, 8.5, 35.0, 11.5, h=2.6)          # a brick substation on the corner
box("van", 33.0, -9.0, 2.1, 5.6)
add("lowhedge", 18, 4, 22, 8, h=0.6)
box("tree", 20, 6, 0.5, 0.5)
box("car", 13.5, 0.5, 4.4, 1.9)
box("car", 24.5, 11.5, 4.4, 1.9)
box("skip", 24.0, 7.0, 3.6, 1.8)

# --- Bottom street: the bus stop, hedges screening the spawn
line("hedge", -6, 75.5, 19, 75.5)
line("hedge", -6, 75.5, -6, 78.5)
line("hedge", 19, 75.5, 19, 78.5)
line("hedge", -9.5, 76.5, -9.5, 80)
line("hedge", 22.5, 76.5, 22.5, 80)
add("shelter", 2.0, 76.2, 9.0, 77.0)
# Parked on the Bottom street's north kerb, either side of the spawn hedges: no line runs the street's length.
box("van", -30.0, 75.05, 5.6, 2.1)
box("van", 28.0, 75.05, 5.6, 2.1)

# --- The Path: lamps on the verge side (never on the path), a bin
for x, z in ((-16.9, -41), (-16.9, -23), (-12.25, 20.5), (-16.25, 58)):
    box("lamp", x, z, 0.2, 0.2)
# ================================================================ dead space -> pieces
RES = 0.5
NX, NZ = int(2 * W / RES), int(2 * H / RES)
open_mask = np.zeros((NX, NZ), bool)
for zn in zones:
    i1, i2 = int(round((zn["x1"] + W) / RES)), int(round((zn["x2"] + W) / RES))
    j1, j2 = int(round((zn["z1"] + H) / RES)), int(round((zn["z2"] + H) / RES))
    open_mask[i1:i2, j1:j2] = True
built = np.zeros_like(open_mask)
for b in buildings:
    i1, i2 = int(round((b["x1"] + W) / RES)), int(round((b["x2"] + W) / RES))
    j1, j2 = int(round((b["z1"] + H) / RES)), int(round((b["z2"] + H) / RES))
    built[i1:i2, j1:j2] = True
dead = ~open_mask & ~built
used = np.zeros_like(dead)
for i in range(NX):
    for j in range(NZ):
        if dead[i, j] and not used[i, j]:
            j2 = j
            while j2 + 1 < NZ and dead[i, j2 + 1] and not used[i, j2 + 1]:
                j2 += 1
            i2 = i
            while i2 + 1 < NX and dead[i2 + 1, j:j2 + 1].all() and not used[i2 + 1, j:j2 + 1].any():
                i2 += 1
            used[i:i2 + 1, j:j2 + 1] = True
            add("dead", -W + i * RES, -H + j * RES, -W + (i2 + 1) * RES, -H + (j2 + 1) * RES)

# House interior zones must not be blocked by the terrace pieces: the House is not a terrace building (gap left above)
FLAG = FLAG_A
FLAGS = [FLAG_A, FLAG_B]
