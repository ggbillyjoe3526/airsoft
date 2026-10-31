"""Woodland redesign concept v3: the layout as data (metres). x east+, z south+, y up. North is up on the plan.

Outdoor wood. The ground is a height field (hills, the dry stream, the sunken Hollow way, the Berm, the Knoll);
everything else is a piece on it. Dead space is spruce thicket and windthrow (fallen-tree tangles): it can't be
entered and blocks sight. Second walking surfaces (bridge decks, the tower platform, tunnel floors) are "overlays".
Not mirrored: fairness comes from measured timings. Attackers/Beta start west, defenders/Alpha east.
"""
from __future__ import annotations

import math
import random

import numpy as np

W, H = 88.0, 60.0  # half sizes: 176 x 120 m
RES = 0.5
NX, NZ = int(2 * W / RES), int(2 * H / RES)
XS = -W + (np.arange(NX) + 0.5) * RES
ZS = -H + (np.arange(NZ) + 0.5) * RES
GX, GZ = np.meshgrid(XS, ZS, indexing="ij")  # [i, j] = (x, z)

RUN, CROUCH = 4.2, 2.1  # m/s, game/config/movement_config.gd
EYE = 1.5  # eye-to-head sight checks, standing


# ------------------------------------------------------------------ helpers
def seg_dist(px, pz, path):
    """Distance from points to a polyline, and the arc position (m) of the nearest point."""
    best = np.full(np.shape(px), np.inf)
    arc = np.zeros(np.shape(px))
    s0 = 0.0
    for (ax, az), (bx, bz) in zip(path, path[1:]):
        dx, dz = bx - ax, bz - az
        L2 = dx * dx + dz * dz
        t = np.clip(((px - ax) * dx + (pz - az) * dz) / L2, 0, 1)
        d = np.hypot(px - (ax + t * dx), pz - (az + t * dz))
        m = d < best
        best = np.where(m, d, best)
        arc = np.where(m, s0 + t * math.sqrt(L2), arc)
        s0 += math.sqrt(L2)
    return best, arc


def gauss(cx, cz, sx, sz, amp, flat=1.0):
    g = np.exp(-(((GX - cx) / sx) ** 2 + ((GZ - cz) / sz) ** 2) / 2)
    return amp * np.minimum(1.0, g * flat)


def smoothstep(a, b, v):
    t = np.clip((v - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ paths
STREAM = [(3, -62), (1, -51), (-1, -46), (-1, -37), (-5, -29), (-5, -21), (0, -11), (7, -3), (12, 6), (13, 16),
          (10, 26), (7, 36), (8, 43), (8, 54), (16, 62)]  # game build: north-south under both crossings
ROAD = [(-90, 24), (-66, 27), (-48, 33), (-34, 42), (-18, 49), (-3, 51), (2, 48.3), (14, 48.3), (22, 43.6), (32, 40), (44, 33), (48, 31)]
HOLLOW = [(23, -3), (29, -11), (35, -19), (42, -25)]
BERM = [(-23, -16.5), (-7, -13.5)]
SLIDES = [(1.7, -55.0), (-3.0, -26.0), (9.5, 0.5), (11.5, 21.0), (10.0, 56.5)]  # gentle banks, a way in and out of every stretch of the bed
FORD = (9.5, 0.5)
STREAM_D, BED_W, BANK = 1.7, 1.9, 0.8


def _cross(p1, p2, q1, q2):
    """Where segment p1-p2 meets segment q1-q2 (they must cross)."""
    (ax, az), (bx, bz), (cx, cz), (dx, dz) = p1, p2, q1, q2
    den = (bx - ax) * (dz - cz) - (bz - az) * (dx - cx)
    t = ((cx - ax) * (dz - cz) - (cz - az) * (dx - cx)) / den
    return (ax + (bx - ax) * t, az + (bz - az) * t)


# v3: the culvert sits exactly where the road crosses the stream, square to the road
CULVERT = tuple(round(v, 2) for v in _cross(ROAD[6], ROAD[7], STREAM[12], STREAM[13]))
CUL_ROT = math.degrees(math.atan2(ROAD[7][1] - ROAD[6][1], ROAD[7][0] - ROAD[6][0]))
# the pipe runs square under the road (the bed meets it 15 degrees off, well inside its 3.8 m floor)
_pd = (-math.sin(math.radians(CUL_ROT)), math.cos(math.radians(CUL_ROT)))
CUL_HALF = 3.0  # headwalls 3 m either side of the road's centre line: road 5 m + a 0.5 m kerb each side
CUL_A = (CULVERT[0] - _pd[0] * CUL_HALF, CULVERT[1] - _pd[1] * CUL_HALF)
CUL_B = (CULVERT[0] + _pd[0] * CUL_HALF, CULVERT[1] + _pd[1] * CUL_HALF)  # depth, half floor width, bank run (steep: can't climb, can drop in)
HOLLOW_D = 1.3

# ------------------------------------------------------------------ ground
h = np.zeros((NX, NZ))
h += 1.1 * smoothstep(-52, -80, GX)                        # west camp sits ~1 m up, the attackers come down to mid
h += 1.4 * smoothstep(52, 78, GX) * smoothstep(30, 0, np.abs(GZ + 2))  # east camp shelf
h += gauss(-25, -41, 20, 9.5, 6.4, flat=1.5)                # the Ridge (north-west), a flat top ~6 m up
h += gauss(-4, -44, 9, 7, 2.2)                             # ridge's east shoulder down to the stream
h += gauss(54, -37, 11, 9, 2.3, flat=1.4)                   # the Fort's rise (A site)
KNOLL_H = gauss(31, 19, 6.5, 4.6, 3.4, flat=1.3)
h += KNOLL_H                                                # the Knoll (between Hut row and B)
h += gauss(-62, 44, 16, 10, 1.6)                            # south-west swell along the road
h += gauss(25, 1, 5.5, 9, 1.9, flat=1.3)                    # Hut rise: Hut row sits on a low crest (breaks the mid line)
h += gauss(-12, 42, 8, 8, 2.4, flat=1.2)                    # Road hump: the road climbs over it between Truck bend and the Long road
h += gauss(70, 44, 14, 10, -0.6)                            # a low dip south-east of B
h += 0.18 * np.sin(GX / 9.0) * np.cos(GZ / 11.0)            # gentle undulation everywhere

# the Berm: an earth bank north of the Clearing, 2.6 m, too steep to climb: hides the Clearing from the Ridge
bd, _ = seg_dist(GX, GZ, BERM)
BERM_H = 3.0 * np.clip(1 - (bd - 1.0) / 2.0, 0, 1)
h += BERM_H

# the road: graded flat across its 5 m, blended into the ground over 2.5 m shoulders
rd, rarc = seg_dist(GX, GZ, ROAD)
road_mask = rd < 2.5
# road profile: ground heights along the centreline, smoothed
_samples = []
_s = 0.0
for (ax, az), (bx, bz) in zip(ROAD, ROAD[1:]):
    L = math.hypot(bx - ax, bz - az)
    for t in np.arange(0, L, 1.0):
        x, z = ax + (bx - ax) * t / L, az + (bz - az) * t / L
        i, j = int((x + W) / RES), int((z + H) / RES)
        if 0 <= i < NX and 0 <= j < NZ:
            _samples.append((_s + t, h[i, j]))
    _s += L
_sa = np.array(_samples)
_k = np.ones(15) / 15
_prof = np.convolve(np.pad(_sa[:, 1], 7, mode="edge"), _k, mode="valid")
# v3: the road runs level for 7 m either side of the culvert, so the deck over the stream meets it
_cd, _carc = seg_dist(np.array([CULVERT[0]]), np.array([CULVERT[1]]), ROAD)
_c0 = float(_carc[0])
_cy = float(np.interp(_c0, _sa[:, 0], _prof))
_w = smoothstep(7.0, 11.0, np.abs(_sa[:, 0] - _c0))
_prof = _prof * _w + _cy * (1 - _w)
road_h = np.interp(rarc, _sa[:, 0], _prof)
wroad = 1 - smoothstep(2.5, 5.0, rd)
h = h * (1 - wroad) + road_h * wroad

# the Hollow way: a sunken track 1.3 m deep, ramps at both ends
hd, harc = seg_dist(GX, GZ, HOLLOW)
hlen = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(HOLLOW, HOLLOW[1:]))
hend = np.minimum(smoothstep(0, 6, harc), smoothstep(hlen, hlen - 6, harc))
h -= HOLLOW_D * hend * np.clip(1 - (hd - 1.8) / 0.8, 0, 1)

# the dry stream: 1.7 m deep, 3.8 m floor, steep banks except at the slides and the ford
sd, sarc = seg_dist(GX, GZ, STREAM)
bank = np.full_like(sd, BANK)
for (x, z) in SLIDES:
    # game build: the gentle bank runs along the stream (by arc), not round a point, so both banks are a walkable
    # ramp across the slide's whole width (the round version left a 1:1 lip a few metres off its middle)
    _s0 = float(seg_dist(np.array([x]), np.array([z]), STREAM)[1][0])
    wide = 6.0 if (x, z) == FORD else 3.6
    bank = np.maximum(bank, BANK + wide * np.clip(1 - (np.abs(sarc - _s0) - 3.5) / 4.0, 0, 1))
ground_before_stream = h.copy()
# v3: the bed follows a profile along the stream set by the LOWER bank (minus 1.7 m), so the bed is 1.7 m below both
# banks everywhere. Where one side is higher (the Ridge's flank), the bank wall is 1.7 m and a cut slope (0.7 m per m,
# walkable) climbs from its top to the ground.
_pts = []
_s = 0.0
for (ax, az), (bx, bz) in zip(STREAM, STREAM[1:]):
    _L = math.hypot(bx - ax, bz - az)
    nx, nz = (bz - az) / _L, -(bx - ax) / _L
    for t in np.arange(0, _L, 1.0):
        x, z = ax + (bx - ax) * t / _L, az + (bz - az) * t / _L
        sides = []
        for sg in (-1, 1):
            for off in (BED_W + BANK + 0.3, BED_W + BANK + 1.4):
                px, pz = x + sg * nx * off, z + sg * nz * off
                i, j = int((min(max(px, -W + .01), W - .01) + W) / RES), int((min(max(pz, -H + .01), H - .01) + H) / RES)
                sides.append(h[i, j])
        _pts.append((_s + t, min(sides) - STREAM_D))
    _s += _L
_bp = np.array(_pts)
_raw = _bp[:, 1]
_sm = np.convolve(np.pad(_raw, 6, mode="edge"), np.ones(13) / 13, mode="valid")
_bed = np.minimum(_sm, _raw)
_bed = np.convolve(np.pad(_bed, 5, mode="edge"), np.ones(11) / 11, mode="valid") - 0.08  # smooth floor, never above the banks
bed_h = np.interp(sarc, _bp[:, 0], _bed)
_wall = STREAM_D * np.clip((sd - BED_W) / bank, 0, 1)
_beyond = np.maximum(sd - BED_W - bank, 0) * np.minimum(0.6, STREAM_D / bank)  # game build: never steeper than 0.6 (bots climb 0.75)
stream_target = bed_h + _wall + _beyond
carve = np.maximum(h - stream_target, 0)
h = np.minimum(h, stream_target)
bed_mask = sd < BED_W + 0.2

# ------------------------------------------------------------------ pieces
# kind, shape: rect (cx, cz, sx, sz, rot deg) or circle (cx, cz, r); top = height above local ground;
# walk: blocks walking; bottom: height above ground where it starts (0 = on the ground).
pieces: list[dict] = []
TALL = {"palisade", "tree", "oak", "thicket", "windthrow", "logstack", "crates", "wall", "hutwall", "truck", "fortwall", "tyrestack",
        "headwall", "tunnel", "shed"}
LOW = {"log", "lowcrates", "tyre", "lowwall", "logpile"}
HEIGHTS = {"thicket": 5.0, "windthrow": 2.2, "logstack": 2.0, "crates": 1.8, "lowcrates": 1.0, "log": 0.6,
           "logpile": 0.9, "tyre": 0.85, "tyrestack": 1.7, "truck": 1.9, "fortwall": 2.3, "lowwall": 1.1,
           "hutwall": 2.5, "headwall": 0.0, "tunnel": 0.0}


def rect(kind, cx, cz, sx, sz, rot=0.0, top=None, walk=True, tag="", bottom=0.0):
    q = round(rot / 90.0) % 2  # game build: blocks are axis-aligned, so every piece turns to the nearest quarter
    sx, sz, rot = (sz, sx, 0.0) if q else (sx, sz, 0.0)
    pieces.append({"kind": kind, "shape": "rect", "cx": cx, "cz": cz, "sx": sx, "sz": sz, "rot": rot,
                   "top": HEIGHTS.get(kind, 2.0) if top is None else top, "walk": walk, "tag": tag, "bottom": bottom})


def circ(kind, cx, cz, r, top=None, walk=True, tag=""):
    pieces.append({"kind": kind, "shape": "circle", "cx": cx, "cz": cz, "r": r,
                   "top": HEIGHTS.get(kind, 12.0) if top is None else top, "walk": walk, "tag": tag, "bottom": 0.0})


WALL_T = 0.25


def walls(kind, pts, openings=(), top=None, tag=""):
    """A wall along a polyline of (x, z) points; openings = (segment index, from m, to m, 'gap'|'window'|'door')."""
    for k, ((ax, az), (bx, bz)) in enumerate(zip(pts, pts[1:])):
        L = math.hypot(bx - ax, bz - az)
        rot = math.degrees(math.atan2(bz - az, bx - ax))
        cuts = sorted((a, b, w) for (s, a, b, w) in openings if s == k)
        pos = 0.0
        runs = []
        for a, b, w in cuts:
            if a > pos:
                runs.append((pos, a, "solid"))
            runs.append((a, b, w))
            pos = b
        if pos < L:
            runs.append((pos, L, "solid"))
        for a, b, w in runs:
            if w in ("gap", "door"):
                if w == "door":
                    m = (a + b) / 2
                    DOORWAYS.append((ax + (bx - ax) * m / L, az + (bz - az) * m / L, rot, b - a, tag))
                continue
            m = (a + b) / 2
            cx, cz = ax + (bx - ax) * m / L, az + (bz - az) * m / L
            if w == "window":
                rect("window", cx, cz, b - a, WALL_T, rot, top=1.0, tag=tag)
            else:
                rect(kind, cx, cz, b - a + (WALL_T if w == "solid" else 0), WALL_T, rot, top=top, tag=tag)


DOORWAYS: list[tuple] = []
ROOFS: list[dict] = []
OVERLAYS: list[dict] = []  # second walking surfaces


def hut(cx, cz, sx, sz, rot, openings, tag, roof_h=2.5):
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))

    def P(u, v):
        return (cx + u * c - v * s, cz + u * s + v * c)
    pts = [P(-sx / 2, -sz / 2), P(sx / 2, -sz / 2), P(sx / 2, sz / 2), P(-sx / 2, sz / 2), P(-sx / 2, -sz / 2)]
    walls("hutwall", pts, openings, tag=tag)
    ROOFS.append({"cx": cx, "cz": cz, "sx": sx + 0.6, "sz": sz + 0.6, "rot": rot, "y": roof_h, "tag": tag})


# ------------------------------------------------------------------ ends
SPAWNS_W = [(-83.0, z) for z in (-3.0, -0.5, 2.0, 4.5, 7.0, 9.5)]   # Beta / attackers
SPAWNS_E = [(79.5, z) for z in (-8.5, -6.0, -3.5, -1.0, 1.5, 4.0)]  # Alpha / defenders
DEAD_W = (-85.0, 26.0)
DEAD_E = (84.5, -24.0)
FLAG_A = (55.0, -38.5)
FLAG_B = (49.0, 38.5)
OT_FLAG = (-3.0, 1.0)
FLAGS = [FLAG_A, FLAG_B]

# West camp: a log palisade with three gates; a screen inside each gate so no line reaches a spawn point
walls("palisade", [(-88, -14), (-72, -14), (-72, 20), (-88, 20)],
      [(0, 9.0, 14.0, "gap"), (1, 15.0, 20.5, "gap"), (2, 9.0, 14.0, "gap")], top=2.8)
rect("logstack", -76.0, 3.0, 1.2, 9.0, 0, top=2.8)           # screen inside the mid gate
rect("logstack", -79.0, -11.5, 9.0, 1.2, 0, top=2.8)          # north gate screen, past the gate's east post
rect("logstack", -81.25, 17.5, 10.5, 1.2, 0, top=2.8)         # south gate screen, past the gate's west post
rect("lowcrates", -84.5, -6.5, 2.0, 1.0)
rect("crates", -84.0, 13.5, 1.6, 1.6)
# East camp
walls("palisade", [(88, -16), (72, -16), (72, 14), (88, 14)],
      [(0, 5.0, 10.0, "gap"), (1, 12.0, 18.0, "gap"), (2, 5.0, 10.0, "gap")], top=2.8)
rect("logstack", 75.5, -1.75, 1.2, 10.5, 0, top=2.8)  # the west gate screen, past its north post
rect("logstack", 80.5, -13.5, 7.0, 1.2, 0, top=2.8)
rect("logstack", 80.5, 11.5, 7.0, 1.2, 0, top=2.8)
rect("logstack", 58.0, 1.0, 1.6, 6.0, 0, top=2.0)             # Back yard: breaks the line from Hut row to the gate
rect("crates", 84.5, 7.5, 1.6, 1.6)

# ------------------------------------------------------------------ NORTH LANE: Pine slope > Ridge > North bridge > Tower > Fern hollow > A
# Pine slope (west, climbing): two log piles as stepping cover
rect("logpile", -63.0, -22.0, 5.0, 1.0, 35)
rect("log", -55.0, -31.0, 6.0, 0.7, -20)
# Ridge top: open tall pines, long east-west view; cover = fallen trunks and a root plate, nothing tall in the middle
rect("log", -40.0, -44.5, 8.0, 0.8, 8)
rect("logpile", -31.0, -37.5, 4.0, 1.2, -10)
rect("windthrow", -22.0, -46.5, 5.0, 1.4, 70, top=2.4)       # root plate: the ridge's one tall cover
rect("log", -12.0, -40.0, 7.0, 0.8, -25)
rect("log", -24.0, -33.0, 6.0, 0.7, 15)
# North bridge: a log footbridge over the stream (deck at bank height; crouch under it)
NB = (-1.0, -41.5)
# Tower (defenders' side): 4 x 4 m platform at 3.4 m, 1.1 m parapet, roof, ladder on the east side
TOWER = (19.0, -43.0)
rect("tyrestack", 14.5, -38.0, 1.8, 1.8)
rect("lowcrates", 23.5, -46.5, 2.2, 1.0, 0)
rect("log", 10.0, -48.5, 6.0, 0.7, 70)
# Fern hollow: low ground before A, open, ferns (no cover value), two logs and a crate stack
rect("crates", 31.0, -40.0, 2.4, 1.6, 15)
rect("log", 36.0, -32.0, 6.0, 0.7, -40)
rect("logpile", 27.0, -49.0, 4.0, 1.0, 0)

# ------------------------------------------------------------------ A SITE: the Fort (plywood walls on the rise)
FORT = [(46.0, -46.0), (64.0, -46.0), (64.0, -24.5)]
walls("fortwall", FORT, [(0, 6.0, 9.5, "window"), (1, 7.0, 10.5, "gap")], tag="fort")  # north window, east gate
walls("lowwall", [(46.0, -46.0), (46.0, -40.0)], tag="fort")                          # west low wall, open south of it
walls("lowwall", [(52.0, -27.0), (60.0, -27.0)], tag="fort")                          # south low wall
hut(59.5, -41.5, 5.0, 4.0, 0, [(1, 1.2, 2.8, "door"), (3, 1.0, 2.6, "door"), (0, 1.2, 3.2, "window"),
                              (2, 1.0, 2.6, "window")], tag="box")           # the Box (hut on the site)
rect("crates", 50.5, -33.5, 2.4, 1.6, 0)
rect("tyrestack", 53.0, -43.0, 1.8, 1.8)
rect("lowcrates", 58.0, -31.5, 2.0, 1.0, 0)
rect("tyre", 47.5, -36.0, 1.7, 1.7)

# ------------------------------------------------------------------ MID LANE: Cabin > Woodpile > Birch stand > Clearing > Ford > Hut row
hut(-52.0, 9.0, 6.0, 4.5, 0, [(0, 1.5, 3.0, "door"), (1, 1.4, 3.0, "door"), (2, 2.0, 4.0, "window"),
                              (3, 1.4, 3.0, "window")], tag="cabin")
rect("logstack", -34.5, 8.0, 1.8, 12.0, 0, top=2.6)          # the Woodpile: a 12 m cordwood wall across the lane
rect("logpile", -40.0, 13.0, 4.0, 1.2, 0)
rect("lowcrates", -26.0, 3.0, 2.0, 1.0, 20)
# Clearing (centre, overtime flag): open moss floor, three islands of cover, two hero oaks
rect("crates", -10.0, 6.5, 2.6, 2.6, 10, top=2.6)            # ammo-crate stack, double height
rect("tyrestack", -1.0, -5.0, 1.8, 1.8)
rect("log", -4.0, 9.5, 6.5, 0.8, -8)
rect("crates", -1.0, 12.0, 2.4, 1.6, 0, top=2.4)            # south crate stack: cover for the Tyre wall exit
rect("tyre", -15.0, -4.0, 1.7, 1.7)
# Hut row (defenders' mid): two huts with doors and windows, a crate yard between
hut(27.0, -0.5, 6.0, 4.0, 0, [(3, 1.3, 2.7, "door"), (1, 1.3, 2.7, "door"), (0, 1.5, 4.5, "window"),
                              (2, 1.5, 4.5, "window")], tag="hut1")
hut(38.5, 8.0, 5.0, 4.0, 90, [(0, 1.0, 2.6, "door"), (2, 1.0, 2.6, "door"), (1, 1.2, 3.0, "window")], tag="hut2")
rect("crates", 33.0, 3.5, 2.0, 1.6, 0)
rect("lowcrates", 20.5, 6.0, 2.0, 1.0, 70)
rect("log", 26.0, -3.6, 5.0, 0.8, 0)  # game build: on the Hut rise crest, north of hut 1: breaks a 98 m Birch stand to Back yard line
rect("logpile", 46.0, -4.0, 4.0, 1.0, 90)

# ------------------------------------------------------------------ SOUTH LANE: Road west > Truck bend > Long road > Culvert > Log stacks > B
rect("logpile", -57.5, 34.6, 5.0, 1.0, 18)                  # v3: off the road, on its south verge
rect("tyre", -46.0, 39.0, 1.7, 1.7)
rect("truck", -34.4, 46.7, 5.4, 2.1, 30)                      # the pickup, parked on the verge at the Truck bend
rect("tyrestack", -26.0, 41.0, 1.8, 1.8)
rect("log", -12.0, 46.0, 6.0, 0.8, 5)
rect("logpile", -4.0, 55.0, 5.0, 1.0, 0)
rect("lowcrates", 1.0, 45.5, 2.0, 1.0, 0)
rect("logstack", 25.0, 47.6, 6.0, 1.6, -20, top=2.0)          # Log stacks (on the verge: breaks the Truck bend to B line)
rect("logstack", 29.7, 35.9, 5.0, 1.6, -25, top=2.0)
rect("tyre", 19.0, 39.0, 1.7, 1.7)
rect("logstack", 36.5, 42.3, 5.0, 1.6, -30, top=2.0)          # v3: along the verge, off the road

# ------------------------------------------------------------------ B SITE: the Sawmill (open shed, log stacks, sawdust yard)
SHED = (56.0, 36.0, 10.0, 6.0)  # cx, cz, sx, sz: open sides, roof at 3.2 m, posts
rect("logpile", 56.0, 36.0, 8.0, 1.4, 0, top=1.2)             # sawbench + logs inside the shed: low cover
rect("logstack", 44.0, 44.5, 7.0, 1.6, 0, top=2.0)
rect("logstack", 60.5, 45.0, 1.6, 6.0, 0, top=2.0)
rect("crates", 42.5, 29.4, 2.0, 2.0, 15)                      # v3: off the road
rect("logstack", 43.0, 39.0, 5.0, 1.6, -30, top=2.0)          # v3: B's road mouth, south verge: the Truck bend can't see through the Sawmill
rect("tyre", 49.5, 44.8, 1.7, 1.7)
rect("crates", 52.5, 40.95, 2.4, 2.6, 10)                     # yard crates: the road can't see deep into B
rect("lowcrates", 64.0, 30.0, 2.0, 1.0, 90)
rect("logstack", 53.0, 34.0, 6.4, 1.0, 0, top=2.0, tag="boards")  # v3: sawn boards stacked along the shed's north side: no road line through B
rect("logstack", 51.6, 30.6, 4.4, 1.4, 63, top=2.0)          # v3: where the road ends: it can't look on into B's back yard

# ------------------------------------------------------------------ links (beyond the stream, ridge and road)
# 1 Birch gap: open slope Woodpile <-> Pine slope/Ridge foot (west half), a log mid-way
rect("log", -44.0, -8.0, 5.0, 0.7, 60)
# 4 Tyre wall: open link Birch stand <-> Truck bend (west half), tractor-tyre wall
rect("tyrestack", -22.0, 24.0, 1.8, 1.8)
rect("tyrestack", -20.2, 24.6, 1.8, 1.8)
rect("tyre", -27.0, 30.0, 1.7, 1.7)
# 6 Back track: the defenders' rotation A <-> B behind their camp (open)
rect("logpile", 70.0, 24.0, 4.0, 1.0, 60)
rect("crates", 69.0, -22.0, 2.0, 2.0, 0)

# tunnels (crouch only, 1.4 m clear inside: a crouched head tops out at 1.13 m, a standing one at 1.75 m): wooden crawl through the Berm, earth run through the Knoll, concrete culvert
TUNNEL_CLEAR = 1.4
TUNNELS = [
    {"name": "Crawl box", "material": "wood", "a": (-14.0, -20.5), "b": (-14.0, -9.5), "w": 1.4, "cover": 6.0},
    {"name": "Badger run", "material": "earth", "a": (31.0, 13.0), "b": (31.0, 25.0), "w": 1.4, "cover": 7.0},
    {"name": "Culvert", "material": "concrete", "a": None, "b": None, "w": 1.6},  # under the road: set below
]
# the culvert: the stream bed under the road deck, 8 m
_c = (12.0, 44.0)
TUNNELS[2]["a"], TUNNELS[2]["b"] = CUL_A, CUL_B

# ------------------------------------------------------------------ dead space: spruce thickets and windthrow
THICKETS = [  # polygons (x, z)
    [(-70, -20), (-56, -16), (-48, -12), (-50, -4), (-62, -5), (-71, -10)],             # T1 north-west, between Pine slope and Cabin
    [(-35, -26), (-25, -21), (-24, -16), (-31, -12), (-37, -18)],                          # T2 the Berm's west end
    [(-26, -29), (-17, -26), (-17, -21), (-24, -20)],                                       # T9 ridge foot, west of the Crawl box path
    [(-11, -28), (-7.5, -30), (-7.5, -21), (-11, -20)],                                     # T10 ridge foot, east of it
    [(7, -31), (16, -33), (25, -26), (24, -15), (17, -10), (8, -18)],                     # T3 east of the stream, north of Hut row
    [(38, -14), (50, -18), (63, -16), (64, -8), (52, -6), (42, -7)],                      # T4 between the Hollow way and the camp
    [(-68, 17), (-52, 17), (-40, 21), (-40, 29), (-50, 27), (-66, 22)],                   # T5 between Cabin and the road
    [(-14, 22), (-4, 18), (5, 22), (5, 37), (-4, 40.5), (-15, 36)],                         # T6 between Clearing and the Long road
    [(40, 14), (54, 13), (62, 18), (60, 25), (48, 25), (40, 21)],                         # T7 between Hut row and B
    [(-90, -62), (90, -62), (90, -55), (40, -56), (20, -57), (-10, -55), (-50, -57), (-90, -54)],  # north edge
    [(-90, 62), (90, 62), (90, 56), (50, 54), (25, 58), (-5, 56), (-40, 55), (-70, 52), (-90, 50)],  # south edge
    [(-24, 56), (-8, 54), (-12, 60), (-26, 60)],
    [(64, -60), (90, -60), (90, -26), (78, -26), (70, -36), (66, -48)],                    # north-east corner behind the Fort
    [(-90, -54), (-74, -52), (-80, -34), (-90, -30)],                                      # north-west corner
    [(66, 50), (90, 46), (90, 62), (66, 62)],                                              # south-east corner
    [(14, 26), (20, 24), (24, 30), (18, 34)],                                              # small: east of the stream, south
    [(-48, 44), (-38, 48), (-44, 56), (-54, 52)],                                          # small: south of Road west
    [(-34, -57), (-26, -57), (-28, -51), (-33, -51)],                                       # edge bites: break lines that hug the boundary
    [(10, -58), (18, -58), (16, -51), (11, -52)],
    [(34, -57), (40, -57), (39, -52), (35, -52)],
    [(-66, 36), (-60, 38), (-62, 46), (-70, 44)],
    [(28, 56), (36, 54), (34, 49), (29, 50)],
    [(-90, 30), (-80, 32), (-82, 40), (-90, 40)],
]
WINDTHROW = [
    (-44.0, -26.0, 7.0, 2.2, 35),    # Pine slope, splits the climb
    (2.0, -22.0, 6.0, 2.0, 80),      # west bank, north of the Fallen oak slide
    (19.0, 20.0, 6.0, 2.0, 100),     # east bank by the Knoll
    (-30.0, 22.0, 7.0, 2.0, 10),     # Tyre wall's west side
    (40.0, -36.0, 5.0, 2.0, 120),    # Fern hollow edge
]
for (x, z, sx, sz, r) in WINDTHROW:
    rect("windthrow", x, z, sx, sz, r, top=2.2)

# ------------------------------------------------------------------ v2: foliage you can hide in
# Fern beds (ellipses: cx, cz, rx, rz, rot): knee-to-hip high (1.0 m). Walk through at full speed; a CROUCHED player in
# or behind one is hidden from anyone looking in at a low angle. BBs pass straight through (concealment, not cover), so
# a suspicious fern bed can be sprayed. From the Tower or the Ridge you look down into them.
FERNS = [
    (-9.8, -36.6, 3.2, 2.0, 25, "Bridge ferns"),        # attackers wait here, crouched, to cross the North bridge
    (31.0, -45.0, 5.0, 2.4, 8, "Fern hollow north"),    # creep towards the Fort's north window
    (32.0, -34.6, 3.8, 2.0, -30, "Fern hollow south"),  # creep towards the Fort's open south-west corner
    (-25.0, -5.5, 4.0, 2.4, 15, "Birch ferns"),         # attackers' mid: a hidden start for the Clearing push
    (18.0, -5.5, 4.0, 2.0, 35, "Ford ferns"),           # just over the Ford: hide after crossing, or get sprayed
    (50.5, 7.0, 5.0, 2.4, -10, "Back yard ferns"),      # defenders' lurk spot on the mid flank
    (-39.1, 32.1, 3.5, 1.8, 33, "Verge ferns"),         # Road west's north verge, clear of the road: attackers' south approach
    (21.0, 53.0, 4.5, 2.0, 5, "Log stack ferns"),       # B's south-west corner, under the edge thicket
]
FERN_TOP = 1.0
# Bushes (hazel and young spruce, 1.7 m): hide a STANDING player; can't be walked through; BBs pass through.
BUSHES = [
    (19.5, 9.5, 1.3, "Ford bush"),      # replaces some of the trees thinned east of the stream
    (44.0, -1.0, 1.2, "Yard bush"),
    (-58.0, -10.0, 1.2, "Pine bush"),   # Pine slope foot: a hidden peek at the Birch gap
    (-30.5, 1.0, 1.3, "Woodpile bush"),  # a standing hide at the Woodpile's open north end
    (12.5, -44.5, 1.2, "Tower bush"),   # under the Tower's west side
    (-19.0, 41.0, 1.3, "Hump bush"),    # top of the Road hump
    (39.0, 31.0, 1.2, "Sawmill bush"),
]
for (x, z, r, _) in BUSHES:
    circ("bush", x, z, r, top=1.7)

# Doors (Depot rules: noisy to open or shut, reset each round). The door facing the enemy starts shut, the one facing
# your own side starts open, so every hut can be entered at once from home and must be opened, loudly, from outside.
DOOR_SHUT = {("cabin", "east"), ("hut1", "west"), ("hut2", "west"), ("box", "west")}

# Night lights (the game's night already has lanterns, fires and torches; bots see you from 40 m in light, 25 m under
# the moon, 10 m under the trees). Placed so the fights at flags and huts are lit and the flanks are dark.
LIGHTS = [
    (-80.0, 1.0, "fire"), (80.0, -2.5, "fire"),                  # camp fires
    (-49.5, 6.0, "lantern"), (23.3, -3.2, "lantern"), (36.0, 8.0, "lantern"),  # Cabin, Hut row
    (-5.0, 3.0, "lantern"),                                       # the overtime flag
    (58.0, -44.6, "lantern"), (66.0, -32.0, "lantern"),          # the Box, the Fort gate
    (56.0, 33.0, "lamp"),                                        # Sawmill work lamp
    (-30.5, 41.0, "fire"),                                        # fire drum at the Truck bend
    (2.0, -39.0, "lantern"),                                     # North bridge, west end
]

AREAS = [  # name, lane, polygon
    ("West camp", "end", [(-88, -14), (-72, -14), (-72, 20), (-88, 20)]),
    ("Pine slope", "n", [(-72, -14), (-62, -28), (-52, -36), (-44, -32), (-46, -22), (-56, -16), (-70, -20)]),
    ("Ridge", "n", [(-52, -36), (-44, -52), (-6, -52), (-4, -34), (-24, -27), (-40, -28)]),
    ("North bridge", "n", [(-6, -52), (10, -52), (10, -34), (-4, -34)]),
    ("Tower", "n", [(10, -52), (26, -52), (26, -34), (10, -34)]),
    ("Fern hollow", "n", [(26, -52), (46, -50), (46, -27), (36, -24), (26, -34)]),
    ("A site", "n", [(46, -50), (64, -50), (64, -27), (46, -27)]),
    ("Fort gate", "end", [(64, -36), (72, -32), (72, -16), (62, -16), (64, -27)]),
    ("East camp", "end", [(72, -16), (88, -16), (88, 14), (72, 14)]),
    ("Cabin", "m", [(-72, -2), (-50, -4), (-44, 4), (-44, 16), (-72, 16)]),
    ("Woodpile", "m", [(-44, -4), (-30, -8), (-28, 16), (-44, 16)]),
    ("Birch stand", "m", [(-30, -8), (-20, -12), (-18, 14), (-28, 16)]),
    ("Clearing", "m", [(-20, -12), (4, -10), (6, 14), (-18, 14)]),
    ("Hut row", "m", [(16, -10), (44, -8), (46, 12), (18, 12)]),
    ("Back yard", "m", [(44, -8), (72, -6), (72, 12), (46, 12)]),
    ("Road west", "s", [(-72, 20), (-60, 22), (-40, 30), (-36, 40), (-46, 44), (-68, 34), (-72, 30)]),
    ("Truck bend", "s", [(-36, 32), (-14, 36), (-14, 54), (-30, 54), (-40, 44)]),
    ("Long road", "s", [(-14, 38), (6, 38), (6, 54), (-14, 54)]),
    ("Log stacks", "s", [(18, 32), (38, 28), (40, 50), (20, 54)]),
    ("B site", "s", [(40, 28), (66, 26), (66, 48), (40, 50)]),
    ("Back track", "end", [(62, 14), (72, 14), (76, 30), (66, 30)]),
]
LINKS = [  # number, name, kind, where (label point), lanes joined
    (1, "Birch gap", "open", (-40.0, -14.0), "north and mid, west half"),
    (2, "Fallen oak", "sunken", (-3.0, -26.0), "north and mid, through the stream bed"),
    (3, "Crawl box", "tunnel", (-14.0, -15.0), "Ridge and Clearing, wooden crawl through the Berm"),
    (4, "Tyre wall", "open", (-24.0, 27.0), "mid and south, west half"),
    (5, "Hollow way", "sunken", (33.0, -16.0), "mid and A site, defenders' half"),
    (6, "Badger run", "tunnel", (31.0, 19.0), "mid and south, earth tunnel through the Knoll"),
    (7, "Stream bed", "sunken", (10.0, 30.0), "mid and south, through the stream bed"),
    (8, "Culvert", "tunnel", CULVERT, "Long road and Log stacks, concrete pipe under the road"),
    (9, "Back track", "open", (69.0, 22.0), "A and B, behind the defenders' camp"),
]
LANE_PATHS = {
    "n": [(-76, -10), (-65, -24.5), (-50, -34), (-36, -42), (-16, -43), (-1, -41.5), (19, -40), (32, -38), (48, -38), (56, -38)],
    "m": [(-74, 4), (-52, 4), (-36, 8), (-22, 2), (-6, 2), (9.5, 0.5), (24, 3), (44, 2), (74, -1)],
    "s": [(-77, 21), (-66, 27), (-48, 33), (-34, 42), (-18, 49), (-3, 51), (2, 48.3), (14, 48.3), (22, 43.6), (32, 40), (44, 35), (49, 37)],
}


SPACING = {"wood": 3.6, "ridge": 5.6, "birch": 3.0, "fern": 3.4, "eastmid": 4.2}  # eastmid: v2, thinner east of the stream


def build_tree_list(seed=7):
    """Gameplay trees: Poisson-disc trunks, thinned off walking lines and away from structures, plus hand-placed oaks."""
    rnd = random.Random(seed)
    trees = []
    hero = [(-12.0, -2.5, 0.9), (-41.0, 0.7, 0.85), (-24.0, 5.2, 0.8), (-46.0, 6.0, 0.8), (1.5, 12.0, 0.85), (-33.0, -2.0, 0.8), (-58.0, -2.0, 0.8), (40.0, -44.0, 0.85),
            (24.0, -8.0, 0.8), (-36.0, 30.0, 0.85), (-6.0, 40.5, 0.8), (35.0, 30.5, 0.85), (-30.0, -46.0, 0.7),
            (-8.0, -47.0, 0.7), (60.0, 20.0, 0.75), (68.0, -40.0, 0.8), (-60.0, 36.0, 0.8), (46.0, 12.0, 0.8),
            (16.0, 30.0, 0.75), (-18.0, -38.0, 0.7), (6.0, -30.0, 0.7)]
    for x, z, r in hero:
        trees.append((x, z, r, "oak"))
    # spacing by zone: ridge pines wide apart (long views), birch stand dense and thin, elsewhere mixed
    pts = []
    cell = 3.0
    grid = {}

    def ok(x, z, sp):
        gi, gj = int((x + W) / cell), int((z + H) / cell)
        for a in range(gi - 3, gi + 4):
            for b in range(gj - 3, gj + 4):
                for (px, pz, psp) in grid.get((a, b), []):
                    if math.hypot(px - x, pz - z) < max(sp, psp) * 0.5 + min(sp, psp) * 0.5:
                        return False
        return True
    tries = 0
    while tries < 160000:
        tries += 1
        x, z = rnd.uniform(-W + 1, W - 1), rnd.uniform(-H + 1, H - 1)
        sp, kind, rr = SPACING["wood"], "pine", rnd.uniform(0.26, 0.4)
        if -50 < x < -4 and -54 < z < -30:
            sp, kind, rr = SPACING["ridge"], "pine", rnd.uniform(0.32, 0.45)
        elif -30 < x < -16 and -10 < z < 16:
            sp, kind, rr = SPACING["birch"], "birch", rnd.uniform(0.14, 0.2)
        elif -44 < x < -28 and -14 < z < 0:
            sp, kind, rr = SPACING["birch"], "birch", rnd.uniform(0.14, 0.2)
        elif 20 < x < 46 and -54 < z < -27:
            sp, kind, rr = SPACING["fern"], "birch", rnd.uniform(0.15, 0.22)
        elif x > 14 and -9 < z < 13:  # Ford's east bank, Hut row, Back yard (William: thinner here only)
            sp, kind, rr = SPACING["eastmid"], "pine", rnd.uniform(0.28, 0.42)
        elif x > 40 and z > 26:
            sp, kind, rr = SPACING["wood"], "pine", rnd.uniform(0.28, 0.4)
        if not ok(x, z, sp):
            continue
        pts.append((x, z, rr, kind))
        grid.setdefault((int((x + W) / cell), int((z + H) / cell)), []).append((x, z, sp))
    return [t + (tree_height(*t),) for t in trees], [tree_sized(t) for t in pts]


def _trnd(x, z):
    return random.Random(int((x + 200) * 1000) * 7919 + int((z + 200) * 1000))


def tree_height(x, z, r, kind):
    """Oaks: 12 to 17 m, bigger trunk taller."""
    return round(_trnd(x, z).uniform(12.0, 15.0) + (r - 0.7) * 12, 1)


def tree_sized(t):
    """Three ages per wood so the canopy isn't one flat height: young (thin, low), grown, and old (thick, tall).
    The Ridge's pines are mostly old (a high, open canopy over long views)."""
    x, z, r, kind = t
    q = _trnd(x, z)
    u = q.random()
    ridge = -50 < x < -4 and -54 < z < -30
    young, old = (0.08, 0.55) if ridge else (0.22, 0.8)
    if kind == "pine":
        if u < young:
            return (x, z, round(r * 0.6, 2), kind, round(q.uniform(6.0, 9.5), 1))
        if u > old:
            return (x, z, round(r * 1.15, 2), kind, round(q.uniform(19.0, 25.0), 1))
        return (x, z, r, kind, round(q.uniform(12.0, 17.5), 1))
    if u < young:
        return (x, z, round(r * 0.75, 2), kind, round(q.uniform(5.5, 8.5), 1))
    if u > old:
        return (x, z, round(r * 1.1, 2), kind, round(q.uniform(15.0, 19.0), 1))
    return (x, z, r, kind, round(q.uniform(10.0, 14.0), 1))


def keep_tree(x, z, r, clear_mask_fn):
    return clear_mask_fn(x, z)
