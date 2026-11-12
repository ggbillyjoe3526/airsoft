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
  glass, that one held at the rim top and bottom (the budget goes on a round outline, not on screw lugs).
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

# The strip lamp, after photo 121814 (seen from the side): 1.52 m long and 0.17 m deep, nine to one; a black body
# and a wire cage under it of about equal depth, ten hoops (nine bays) and a runner down each bottom corner, four
# spring clips a side, two hook hangers a quarter of its length in from each end.
HALF = 0.76          # half its length
TOP = -0.05          # the body's top under the ceiling (the hangers fill the gap)
SIDE_W = 0.062       # half the body's width
LIP_W = 0.07         # half the width of the lip round its foot
LIP_TOP = -0.113     # where the lip steps out
FOOT = -0.127        # the body's foot, where the diffuser meets it
LENS_HALF = 0.735    # half the diffuser's length
LENS_W = 0.066       # half the diffuser's width
LENS_LOW = -0.205    # the diffuser's lowest point
CAGE_W = 0.074       # half the cage's width
CAGE_LOW = -0.213    # the cage's floor
HOOPS = 10
CLIPS = (-0.6, -0.22, 0.22, 0.6)
HANGERS = (-0.395, 0.395)
WIRE = 0.0034        # a wire's half width
WIRE_RISE = 0.0045   # its crest over that


def strip_lamp() -> sk.Mesh:
    m = sk.Mesh("strip_lamp")
    # The body: a profile in (y, z), counter-clockwise seen from +x, open at its top (edge 4) and its foot (edge 0,
    # the diffuser's top); upright sides, a lip stepping out round its foot.
    body = [(FOOT, LIP_W), (FOOT, -LIP_W), (LIP_TOP, -LIP_W), (LIP_TOP + 0.003, -SIDE_W), (TOP, -SIDE_W),
            (TOP, SIDE_W), (LIP_TOP + 0.003, SIDE_W), (LIP_TOP, LIP_W)]
    m.prism_x(body, -HALF, HALF, "black", open_edges=(0, 4))
    m.face_toward([(-HALF, TOP, -SIDE_W), (-HALF, TOP, SIDE_W), (HALF, TOP, SIDE_W), (HALF, TOP, -SIDE_W)],
                  (0.0, 1.0, 0.0), "black")
    # The diffuser under it (glowing), its top in the body's foot, its bottom corners rounded.
    lens = [(FOOT, LENS_W), (-0.19, LENS_W - 0.002), (LENS_LOW, 0.042), (LENS_LOW, -0.042), (-0.19, -LENS_W + 0.002),
            (FOOT, -LENS_W)]
    m.prism_x(lens, -LENS_HALF, LENS_HALF, "lens", open_edges=(5,), mat="Lens")
    # The cage: ten hoops down, under and up round the diffuser, a runner along each bottom corner.
    for k in range(HOOPS):
        x = -LENS_HALF + 0.004 + (2.0 * LENS_HALF - 0.008) * k / (HOOPS - 1)
        path = [(x, FOOT, CAGE_W), (x, CAGE_LOW, CAGE_W), (x, CAGE_LOW, -CAGE_W), (x, FOOT, -CAGE_W)]
        outs = [(0.0, 0.0, 1.0), (0.0, -1.0, 1.0), (0.0, -1.0, -1.0), (0.0, 0.0, -1.0)]
        m.wire(path, outs, WIRE, WIRE_RISE, "charcoal")
    for z in (CAGE_W, -CAGE_W):
        o = (0.0, -1.0, 1.0 if z > 0 else -1.0)
        m.wire([(-LENS_HALF, CAGE_LOW, z), (LENS_HALF, CAGE_LOW, z)], [o, o], WIRE, WIRE_RISE, "charcoal")
    # Spring clips down each side, over the lip to the cage.
    for x in CLIPS:
        for side in (1.0, -1.0):
            z = side * (SIDE_W + 0.002)
            m.face_toward([(x - 0.007, -0.072, z), (x + 0.007, -0.072, z), (x + 0.007, LIP_TOP - 0.004, z),
                           (x - 0.007, LIP_TOP - 0.004, z)], (0.0, 0.0, side), "alu")
    # The hook hangers: a bent rod from the body's top up to the ceiling's hook.
    for x in HANGERS:
        m.tube([(x, TOP, 0.0), (x + 0.012, 0.0, 0.0)], 0.004, "dark_alu", sides=3)
    return m


# The tunnel lamp, after photos 122005 and 121940: a stadium (two half circles joined by straight sides) 0.165 m
# wide and 0.30 m tall, five to nine; a deep black cast body, a dome black at its round ends and glass down its
# straight middle (`Lens`), four bars across it and one down its middle standing clear of it, that one's ends
# held at the rim top and bottom.
R = 0.0825           # the half circles' radius
S = 0.0675           # half the straight sides' length
ARC = 8              # segments in each half circle
FLANGE = 0.024       # the cast body's depth off the wall
DOME = ((0.054, 0.09),)   # the dome's rings: radius, depth
BARS = (-0.065, -0.014, 0.014, 0.065)      # the bars across, by height
BAR_FRONT = 0.096    # how far out a bar crosses the front
BAR_TURN = 0.066     # where a bar turns across the front (its half width there)


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
    base, rim = stadium(R, 0.0), stadium(R, FLANGE)
    rings = [rim] + [stadium(r, z) for r, z in DOME]
    n = len(base)
    # Faces 0..ARC-1 run round the top half circle, ARC the left side, ARC+1..2*ARC the bottom one, the last the right
    # side; the straight sides' dome is glass.
    m.quad_strip(base, rim, "black", closed=True, smooth=True)
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            glass = i in (ARC, n - 1)
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
    m.face([f[n - 1], f[0], f[ARC], f[ARC + 1]], "lens", "Lens", smooth=True)
    # The cage: each bar off the flange, up over the dome's side, across its front and down the other side.
    for y in BARS:
        path = [(-R - 0.001, y, FLANGE * 0.8), (-BAR_TURN, y, BAR_FRONT), (BAR_TURN, y, BAR_FRONT),
                (R + 0.001, y, FLANGE * 0.8)]
        outs = [(-1.0, 0.0, 0.2), (-0.6, 0.0, 1.0), (0.6, 0.0, 1.0), (1.0, 0.0, 0.2)]
        m.wire(path, outs, 0.0032, 0.004, "black")
    top = S + R
    path = [(0.0, top + 0.002, FLANGE * 0.8), (0.0, S + 0.05, BAR_FRONT), (0.0, -S - 0.05, BAR_FRONT),
            (0.0, -top - 0.002, FLANGE * 0.8)]
    outs = [(0.0, 1.0, 0.2), (0.0, 0.6, 1.0), (0.0, -0.6, 1.0), (0.0, -1.0, 0.2)]
    m.wire(path, outs, 0.0032, 0.004, "black")
    return m


def main() -> None:
    sk.export(strip_lamp(), "strip_lamp", STRIP_BUDGET)
    sk.export(tunnel_lamp(), "tunnel_lamp", TUNNEL_BUDGET)


if __name__ == "__main__":
    main()
