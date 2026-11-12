"""Subway's spiral stair (SM2, model #16), after the owner's photos (art/references/maps/subway/16-spiral-stair/): dark
worn treads with bright yellow anti-slip nosings (photos 3 to 6) climbing round the well's tiled central column (the
station's own tiles: the column stays the map's pillar, StationSurface draws it), a black steel handrail on the outer
wall on short brackets (photos 3, 5 and 6), and the stair's solid undersides seen from below.

The map's stair is square: ten flights, one up each side of the well in turn, each a ramp a metre high, with a corner
landing at the top of each (tools/subway/build_map.py, spiral(); layout.SPIRAL). The model is laid over those blocks
(PropDressConfig Lay.SET, unturned): every flight and landing names it, so it fills their box exactly and the ramps stay
the colliders. Each flight's five risers are equal (0.2 m); each tread is level, its middle on the ramp's slope, and
the landings' levels run on to the first riser up, so feet never sink or float more than 10 cm. A flight and its
landing are solid, as their blocks are: from below the soffits show as their boxes' undersides.

The handrail runs from the well's foot round every flight and landing, 0.9 m over the stair, until the last flight's,
where it would stand over the stair's box (the hall's railing is there): it turns into the wall a metre below the
hall's floor.

Writes assets/models/props/spiral_stair.glb. Budget 6,000 triangles.

Usage: python3 -I tools/blender/maps/spiral_stair.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import transit_kit as tk  # noqa: E402
import map_kit as mk  # noqa: E402
import build_map as BM  # noqa: E402  tools/subway/build_map.py

BUDGET = 6000
RISERS = 5            # a flight's risers, all alike
NOSING = 0.055        # the yellow nosing's depth on each tread
RAIL_UP = 0.9         # the handrail's height over the pitch line and the landings
RAIL_R = 0.021
RAIL_OFF = 0.065      # its middle off the wall
BRACKET_STEP = 1.1    # brackets along the rail (m)
TREAD = 0x4A4845
RISER = 0x5A5752
SOFFIT = 0x8C877E
RAIL = 0x232226
SEED = 16


class Flight:
    """One flight: its box, the axis it climbs along and which way, its low and high ends, its width's two edges (the
    wall's and the column's) and its foot's and head's heights."""

    def __init__(self, rp: dict, well: tuple) -> None:
        self.rp = rp
        self.axis = rp["rise"][1]
        self.way = 1.0 if rp["rise"][0] == "+" else -1.0
        a0, a1 = (rp["x0"], rp["x1"]) if self.axis == "x" else (rp["z0"], rp["z1"])
        self.low, self.high = (a0, a1) if self.way > 0 else (a1, a0)
        self.length = abs(self.high - self.low)
        c0, c1 = (rp["z0"], rp["z1"]) if self.axis == "x" else (rp["x0"], rp["x1"])
        # The wall's edge is the one on the well's boundary.
        wx0, wx1, wz0, wz1 = well
        bounds = (wz0, wz1) if self.axis == "x" else (wx0, wx1)
        self.wall = c0 if abs(c0 - bounds[0]) < 1e-6 or abs(c0 - bounds[1]) < 1e-6 else c1
        self.core = c1 if self.wall == c0 else c0
        self.y0, self.y1 = rp["y0"], rp["y1"]

    def P(self, d: float, y: float, c: float) -> tuple:
        """The point `d` along the flight from its foot, at height `y`, at `c` across it."""
        a = self.low + self.way * d
        return (a, y, c) if self.axis == "x" else (c, y, a)


def quad_facing(m: tk.Mesh, pts: list, normal: tuple, tones: tuple = None) -> None:
    """A quad from `pts` wound to face `normal`."""
    a, b, c = pts[0], pts[1], pts[2]
    e1 = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
    e2 = (c[0] - b[0], c[1] - b[1], c[2] - b[2])
    n = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
    if n[0] * normal[0] + n[1] * normal[1] + n[2] * normal[2] < 0:
        pts = list(reversed(pts))
        tones = None if tones is None else tuple(reversed(tones))
    m.quad(*pts, tones=tones or (1.0, 1.0, 1.0, 1.0))


def flight_steps(f: Flight, first: bool, treads: tk.Mesh, yellow: tk.Mesh, risers: tk.Mesh, under: tk.Mesh,
                 rng: random.Random) -> None:
    """A flight's treads (worn paler in the walking line), yellow nosings, risers and its underside; the first
    flight's foot just over the well's floor."""
    rise = (f.y1 - f.y0) / RISERS
    going = f.length / RISERS
    w0, w1 = sorted((f.wall, f.core))
    up = (0.0, 1.0, 0.0)
    down = (0.0, -1.0, 0.0)
    back = (-f.way, 0.0, 0.0) if f.axis == "x" else (0.0, 0.0, -f.way)
    # Levels along the flight: the landing below runs on to the first riser, the treads between, the landing above
    # from the last.
    spans = [(0.0, going / 2, f.y0 + (0.003 if first else 0.0))]
    for j in range(1, RISERS):
        spans.append((going * (j - 0.5), going * (j + 0.5), f.y0 + rise * j))
    spans.append((going * (RISERS - 0.5), f.length, f.y1))
    for k, (d0, d1, y) in enumerate(spans):
        wear = rng.uniform(0.94, 1.06)
        third = (w1 - w0) / 3
        cuts = [w0, w0 + third * 0.7, w1 - third * 0.7, w1]
        tones = [0.86, 1.06, 1.06, 0.86]
        nose = d0 + NOSING if k > 0 else d0
        if k > 0:
            for a, b in ((w0, w1),):
                quad_facing(yellow, [f.P(d0, y, a), f.P(nose, y, a), f.P(nose, y, b), f.P(d0, y, b)], up)
        for i in range(3):
            quad_facing(treads, [f.P(nose, y, cuts[i]), f.P(d1, y, cuts[i]), f.P(d1, y, cuts[i + 1]),
                                 f.P(nose, y, cuts[i + 1])], up,
                        (tones[i] * wear, tones[i] * wear, tones[i + 1] * wear, tones[i + 1] * wear))
        if k > 0:
            y_prev = spans[k - 1][2]
            quad_facing(risers, [f.P(d0, y_prev, w0), f.P(d0, y_prev, w1), f.P(d0, y, w1), f.P(d0, y, w0)], back,
                        (0.8, 0.8, 1.0, 1.0))
            # The nosing's front edge, yellow, the top of the riser.
            quad_facing(yellow, [f.P(d0 - 0.001, y - 0.025, w0), f.P(d0 - 0.001, y - 0.025, w1),
                                 f.P(d0 - 0.001, y, w1), f.P(d0 - 0.001, y, w0)], back)
    # The underside: flat at the flight's foot, as its block.
    quad_facing(under, [f.P(0.0, f.y0, w0), f.P(f.length, f.y0, w0), f.P(f.length, f.y0, w1),
                        f.P(0.0, f.y0, w1)], down)


def build() -> None:
    mk.reset()
    rng = random.Random(SEED)
    ramps, boxes = BM.spiral()
    s = BM.L.SPIRAL
    well = (s["x0"] + BM.SEAL_T, s["x1"] - BM.SEAL_T, s["z0"] + BM.SEAL_T, s["z1"] - BM.SEAL_T)
    flights = [Flight(rp, well) for rp in ramps]
    landings = [bx for bx in boxes if bx[3] - bx[2] <= 3.0]
    treads, yellow, risers, under, rail, brackets = (tk.Mesh() for _ in range(6))
    g = BM.GROW
    for k, f in enumerate(flights):
        flight_steps(f, k == 0, treads, yellow, risers, under, rng)
    # The landings: a worn top, a plain underside, the edge over the next flight up's underside, and the face of the
    # flight that climbs to it, under it, down to that flight's foot.
    for k, (x0, x1, y0, y1, z0, z1) in enumerate(landings):
        x0, x1, z0, z1 = x0 - g, x1 + g, z0 - g, z1 + g
        tone = rng.uniform(0.95, 1.05)
        quad_facing(treads, [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], (0.0, 1.0, 0.0),
                    (tone * 0.9, tone, tone * 0.9, tone))
        quad_facing(under, [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], (0.0, -1.0, 0.0))
        if k + 1 < len(flights):
            nxt = flights[k + 1]
            n = (nxt.way, 0.0, 0.0) if nxt.axis == "x" else (0.0, 0.0, nxt.way)
            edge = nxt.low
            if nxt.axis == "x":
                quad_facing(under, [(edge, y0, z0), (edge, y0, z1), (edge, y1, z1), (edge, y1, z0)], n)
            else:
                quad_facing(under, [(x0, y0, edge), (x1, y0, edge), (x1, y1, edge), (x0, y1, edge)], n)
        f = flights[k]
        n = (f.way, 0.0, 0.0) if f.axis == "x" else (0.0, 0.0, f.way)
        w0, w1 = sorted((f.wall, f.core))
        quad_facing(under, [f.P(f.length, f.y0, w0), f.P(f.length, f.y0, w1), f.P(f.length, y0, w1),
                            f.P(f.length, y0, w0)], n)
    # The handrail: along the wall up each flight and level round each landing's outer corner, bent at each turn.
    top = max(f.y1 for f in flights)
    path = []
    for k, f in enumerate(flights):
        c = f.wall + (RAIL_OFF if f.wall < f.core else -RAIL_OFF)
        foot = f.P(0.0, f.y0 + RAIL_UP, c)
        head = f.P(f.length, f.y1 + RAIL_UP, c)
        if k == 0:
            wall_foot = f.P(0.0, f.y0 + RAIL_UP, f.wall)
            path.append(wall_foot)
        if head[1] + RAIL_R > top - 0.004:
            # The last flight that would stand over the box: end where the rail meets it, turned into the wall.
            share = (top - 0.004 - RAIL_R - foot[1]) / (head[1] - foot[1])
            end = f.P(f.length * share, top - 0.004 - RAIL_R, c)
            path += [foot, end, f.P(f.length * share + 0.001, top - 0.004 - RAIL_R, f.wall)]
            break
        path += [foot, head]
        nxt = flights[k + 1]
        cn = nxt.wall + (RAIL_OFF if nxt.wall < nxt.core else -RAIL_OFF)
        corner = (c, head[1], cn) if f.axis == "z" else (cn, head[1], c)
        path.append(corner)
    # Drop the doubled points the corners leave (a flight's head and the corner coincide only in plan).
    clean = [path[0]]
    for p in path[1:]:
        if tk._len(tk._sub(p, clean[-1])) > 1e-4:
            clean.append(p)
    tk.tube(rail, tk.bent(clean, 0.12, 4), RAIL_R, 10)
    # Brackets every BRACKET_STEP m along it: a short arm from a wall rose up to the rail's underside.
    walked = 0.0
    nxt_at = BRACKET_STEP / 2
    for p, q in zip(clean, clean[1:]):
        seg = tk._len(tk._sub(q, p))
        while nxt_at < walked + seg:
            t = (nxt_at - walked) / seg
            at = tk._add(p, tk._sub(q, p), t)
            # The wall it hangs off: the nearest of the well's four.
            dists = [(abs(at[0] - well[0]), (well[0], None)), (abs(at[0] - well[1]), (well[1], None)),
                     (abs(at[2] - well[2]), (None, well[2])), (abs(at[2] - well[3]), (None, well[3]))]
            _, (wx, wz) = min(dists)
            base = (wx if wx is not None else at[0], at[1] - 0.055, wz if wz is not None else at[2])
            tk.tube(brackets, [base, (at[0], at[1] - 0.055, at[2]), (at[0], at[1] - RAIL_R, at[2])], 0.007, 6)
            axis = "x" if wx is not None else "z"
            facing = 1.0 if (wx is not None and wx < at[0]) or (wz is not None and wz < at[2]) else -1.0
            tk.knob(brackets, base, 0.03, 0.026, 0.008, facing, 8, axis)
            nxt_at += BRACKET_STEP
        walked += seg
    objects = [treads.build("treads", TREAD), mk.ribbed(yellow.build("nosings", tk.YELLOW), 1),
               risers.build("risers", RISER), under.build("soffits", SOFFIT, toned=False),
               rail.build("handrail", RAIL, smooth=50.0, toned=False),
               brackets.build("brackets", RAIL, smooth=50.0, toned=False)]
    lo = (min(min(f.rp["x0"] for f in flights), min(b[0] for b in landings)) - g, min(f.y0 for f in flights),
          min(min(f.rp["z0"] for f in flights), min(b[4] for b in landings)) - g)
    hi = (max(max(f.rp["x1"] for f in flights), max(b[1] for b in landings)) + g, top,
          max(max(f.rp["z1"] for f in flights), max(b[5] for b in landings)) + g)
    tk.report("spiral_stair", objects, BUDGET, (lo, hi))


if __name__ == "__main__":
    build()
