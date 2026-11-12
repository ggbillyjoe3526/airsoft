"""Subway's lamps (SM5, models 31 and 32 of art/subway-model-list.md), from the owner's photos
(references/maps/subway/31-ceiling-lamp and 32-tunnel-lamp):

- **strip_lamp.glb** (budget 200): the fitting on every station ceiling, the caged industrial batten of photo 121814:
  a black body with a lip round its foot, an opal diffuser under it (`Lens`, which the game draws glowing) in a wire
  cage as deep as the body (ten hoops, a runner down each bottom corner), four spring clips a side and two hook
  hangers a quarter of its length in from each end. 1.52 m long (x), 0.16 m across, 0.17 m deep under the hangers;
  their top (y 0) at the ceiling, so RoofView hangs it from each lamp spot, turned along its room.
- **tunnel_lamp.glb** (budget 150): the caged bulkhead of photos 122005 and 121940, black as the fourth: a stadium
  outline (two half circles joined by straight sides) 0.165 m wide and 0.30 m tall, a deep cast body, a dome black
  at its ends and glass down its middle (`Lens`), four round bars across it and one down it standing clear of the
  glass, that one held at the rim over a small screw lug top and bottom.
  Its back (z 0) on the wall, facing +z, its middle at the origin.

    python3 -I tools/blender/maps/station_lamps.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import stationkit as sk  # noqa: E402

STRIP_BUDGET = 200
TUNNEL_BUDGET = 150

# The strip lamp, after photo 121814 (seen from the side, measured by pixel): 1.52 m long and 0.18 m deep under its
# hangers, about eight and a half to one; a black body flaring to a lip at its foot over a wire cage as deep, ten
# hoops (nine bays) and a runner down each bottom corner round a clear diffuser that fills the cage (pale glass, the
# tube's glow along its floor), four wire spring clips a side (at a tenth, a third, two thirds and nine tenths of its
# length), two hook hangers on plates a quarter of its length in from each end.
HALF = 0.76          # half its length
TOP = -0.05          # the body's top under the ceiling (the hangers fill the gap)
SIDE_W = 0.058       # half the body's width at its top
LOW_W = 0.06         # and where its lip starts
LIP_Y = -0.128       # where the lip flares out
FOOT = -0.14         # the body's foot, where the diffuser and the cage hang from it
FOOT_W = 0.074       # half the lip's width
LIP_OVER = 0.03      # how far the lip runs on past each end of the body
LENS_HALF = 0.735    # half the diffuser's length
LENS_W = 0.062       # half the diffuser's width at the body
LENS_D = 0.08        # its depth under the body's foot
GLOW_W = 0.032       # half the width of the glow along its floor
CAGE_W = 0.07        # half the cage's width
CAGE_LOW = FOOT - 0.09    # the cage's floor
HOOPS = 10
CLIPS = (-0.608, -0.228, 0.228, 0.608)
HANGERS = (-0.38, 0.38)
WIRE = 0.0034        # a wire's half width
WIRE_RISE = 0.0045   # its crest over that


def strip_lamp() -> sk.Mesh:
    m = sk.Mesh("strip_lamp")
    # The body: a profile in (y, z), counter-clockwise seen from +x, open at its top (under the ceiling) and its foot;
    # upright sides, on a lip flaring out at its foot that runs on past each end, as the photo's.
    body = [(LIP_Y, -LOW_W), (TOP, -SIDE_W), (TOP, SIDE_W), (LIP_Y, LOW_W)]
    m.prism_x(body, -HALF + LIP_OVER, HALF - LIP_OVER, "black", open_edges=(1, 3))
    lip = [(FOOT, FOOT_W), (FOOT, -FOOT_W), (LIP_Y, -LOW_W), (LIP_Y, LOW_W)]
    m.prism_x(lip, -HALF, HALF, "black", open_edges=(2,))
    # The diffuser filling the cage: pale glass down its sides and ends, the tube's glow along its floor.
    low = FOOT - LENS_D
    glass = [(FOOT, LENS_W), (low + 0.012, LENS_W - 0.003), (low, GLOW_W), (low, -GLOW_W),
             (low + 0.012, -LENS_W + 0.003), (FOOT, -LENS_W)]
    m.prism_x(glass, -LENS_HALF, LENS_HALF, "clear", open_edges=(2, 5), smooth=True)
    m.face_toward([(-LENS_HALF, low, GLOW_W), (LENS_HALF, low, GLOW_W), (LENS_HALF, low, -GLOW_W),
                   (-LENS_HALF, low, -GLOW_W)], (0.0, -1.0, 0.0), "lens", "Lens")
    # The cage: ten hoops down from the lip, under and up (their legs straps seen side on, the crossing a round bar),
    # a runner along each bottom corner, clear of the diffuser.
    for k in range(HOOPS):
        x = -LENS_HALF + 0.004 + (2.0 * LENS_HALF - 0.008) * k / (HOOPS - 1)
        path = [(x, FOOT, CAGE_W), (x, CAGE_LOW, CAGE_W), (x, CAGE_LOW, -CAGE_W), (x, FOOT, -CAGE_W)]
        outs = [(0.0, 0.0, 1.0), (0.0, -1.0, 1.0), (0.0, -1.0, -1.0), (0.0, 0.0, -1.0)]
        m.wire(path, outs, WIRE, WIRE_RISE, "dark_alu", flat_ends=True)
    for z in (CAGE_W, -CAGE_W):
        o = (0.0, -1.0, 1.0 if z > 0 else -1.0)
        m.wire([(-LENS_HALF, CAGE_LOW, z), (LENS_HALF, CAGE_LOW, z)], [o, o], WIRE, WIRE_RISE, "dark_alu")
    # The spring clips: a wire bail, two legs down the body's side and over the lip, a cross bar on the cage's top.
    for x in CLIPS:
        for side in (1.0, -1.0):
            o, z0, z1 = (0.0, 0.0, side), side * (SIDE_W + 0.0015), side * (CAGE_W + 0.003)
            for dx in (-0.008, 0.008):
                m.face_toward([(x + dx - 0.0015, -0.1, z0), (x + dx + 0.0015, -0.1, z0),
                               (x + dx + 0.0015, FOOT - 0.008, z1), (x + dx - 0.0015, FOOT - 0.008, z1)], o, "alu")
            m.face_toward([(x - 0.0095, FOOT - 0.005, z1), (x + 0.0095, FOOT - 0.005, z1),
                           (x + 0.0095, FOOT - 0.011, z1), (x - 0.0095, FOOT - 0.011, z1)], o, "alu")
    # The hangers: a plate on the body's top and a hook rising from it to the ceiling.
    for x in HANGERS:
        m.face_toward([(x - 0.03, TOP + 0.001, -0.03), (x + 0.03, TOP + 0.001, -0.03), (x + 0.03, TOP + 0.001, 0.03),
                       (x - 0.03, TOP + 0.001, 0.03)], (0.0, 1.0, 0.0), "dark_alu")
        m.wire([(x - 0.006, TOP, 0.0), (x - 0.004, -0.012, 0.0), (x + 0.01, -0.0044, 0.0)], [(0.0, 0.0, 1.0)] * 3,
               0.005, 0.004, "dark_alu")
    return m


# The tunnel lamp, after photos 122005 and 121940: a stadium (two half circles joined by straight sides) 0.165 m
# wide and 0.30 m tall, five to nine; a deep black cast body, a dome black at its round ends and glass down its
# straight middle (`Lens`), four bars across it and one down its middle standing clear of it, that one's ends
# held at the rim over a screw lug top and bottom.
R = 0.0825           # the half circles' radius
S = 0.0675           # half the straight sides' length
ARC = 9              # segments in each half circle (odd: its top and bottom on an edge's middle, not a point)
FLANGE = 0.026       # the cast body's depth off the wall
RIM = 0.008          # how far the body's front edge stands in from its back, round the glass
DOME = ((0.058, 0.084),)   # the dome's front ring: radius, depth
SPINE = 0.095        # the glass's front raised along its middle (under the vertical bar), an arc of three facets
BARS = (-S, -0.014, 0.014, S)      # the bars across, by height: the outer two over the glass's edges
BAR_FRONT = 0.092    # how far out a bar turns onto the front
BAR_SPINE = 0.0985   # and how far out it crosses the glass's spine
BAR_TURN = 0.066     # where a bar turns across the front (its half width there)
LUG = 0.009          # a screw lug's half width
LUG_H = 0.014        # how far it stands past the rim


def stadium(r: float, z: float) -> list:
    """The outline at depth `z`, radius `r` round the two centres (0, +-S), counter-clockwise seen from +z."""
    pts = []
    for k in range(ARC + 1):
        a = math.pi * k / ARC
        pts.append((r * math.cos(a), S + r * math.sin(a), z))
    for k in range(ARC + 1):
        a = math.pi + math.pi * k / ARC
        pts.append((r * math.cos(a), -S + r * math.sin(a), z))
    return pts


def tunnel_lamp() -> sk.Mesh:
    m = sk.Mesh("tunnel_lamp")
    base, rim = stadium(R, 0.0), stadium(R - RIM, FLANGE)
    rings = [rim] + [stadium(r, z) for r, z in DOME]
    n = len(base)
    # Faces 0..ARC-1 run round the top half circle, ARC the left side, ARC+1..2*ARC the bottom one, the last the right
    # side; the glass is the dome's front band along the straight sides, inset from the body's rim.
    m.quad_strip(base, rim, "black", closed=True, smooth=True)
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            glass = i in (ARC, n - 1) and b is rings[-1]
            m.face([a[i], a[j], b[j], b[i]], "lens" if glass else "black", "Lens" if glass else "Prop", smooth=True)
    # The front: rungs between the outline's left and right points, the middle (between the straight sides) glass.
    f = rings[-1]
    for k in range(ARC // 2 + 1):
        # top half: points k and ARC-k (right, left); bottom half: ARC+1+k and n-1-k
        a, b = f[k], f[ARC - k]
        c, d = f[k + 1], f[ARC - k - 1]
        if k + 1 <= ARC - k - 1:
            m.face([a, c, d, b] if k + 1 < ARC - k - 1 else [a, c, b], "black", smooth=True)
        a, b = f[n - 1 - k], f[ARC + 1 + k]
        c, d = f[n - 2 - k], f[ARC + 2 + k]
        if ARC + 2 + k <= n - 2 - k:
            m.face([b, d, c, a] if ARC + 2 + k < n - 2 - k else [b, d, a], "black", smooth=True)
    top_spine, low_spine = (0.0, S, SPINE), (0.0, -S, SPINE)
    m.face([f[n - 1], f[0], top_spine, low_spine], "lens", "Lens", smooth=True)
    m.face([low_spine, top_spine, f[ARC], f[ARC + 1]], "lens", "Lens", smooth=True)
    # the body's lip over the raised glass's top and bottom edges, closing the wedge under the spine
    m.face_toward([f[ARC], top_spine, f[0]], (0.0, 1.0, 0.0), "black")
    m.face_toward([f[ARC + 1], low_spine, f[n - 1]], (0.0, -1.0, 0.0), "black")
    # The cage: each bar out of the body's rim (its end inside it), up the dome's side, over the glass's spine and back
    # down, bending with the glass's arc: a flat strap all round (round ones cost twice), the vertical one a round bar.
    for y in BARS:
        path = [(-R + 0.007, y, FLANGE * 0.6), (-BAR_TURN, y, BAR_FRONT), (0.0, y, BAR_SPINE), (BAR_TURN, y, BAR_FRONT),
                (R - 0.007, y, FLANGE * 0.6)]
        outs = [(-1.0, 0.0, 0.2), (-0.6, 0.0, 1.0), (0.0, 0.0, 1.0), (0.6, 0.0, 1.0), (1.0, 0.0, 0.2)]
        m.wire(path, outs, 0.0032, 0.004, "black", flat=True)
    top = S + R * math.sin(math.pi * (ARC // 2) / ARC)
    path = [(0.0, top - 0.008, FLANGE * 0.6), (0.0, S + 0.06, BAR_SPINE), (0.0, -S - 0.06, BAR_SPINE),
            (0.0, -top + 0.008, FLANGE * 0.6)]
    outs = [(0.0, 1.0, 0.2), (0.0, 0.6, 1.0), (0.0, -0.6, 1.0), (0.0, -1.0, 0.2)]
    m.wire(path, outs, 0.0032, 0.004, "black")
    # A screw lug top and bottom: a blunt ear off the body's rim, under the bar's end.
    for sgn in (1.0, -1.0):
        y0, y1 = sgn * (top - 0.004), sgn * (top + LUG_H)
        m.face_toward([(-LUG, y0, 0.006), (LUG, y0, 0.006), (LUG * 0.6, y1, 0.006), (-LUG * 0.6, y1, 0.006)],
                      (0.0, 0.0, 1.0), "black")
    return m


def main() -> None:
    sk.export(strip_lamp(), "strip_lamp", STRIP_BUDGET)
    sk.export(tunnel_lamp(), "tunnel_lamp", TUNNEL_BUDGET)


if __name__ == "__main__":
    main()
