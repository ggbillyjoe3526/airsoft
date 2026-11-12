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

# The strip lamp, after photo 121814 (seen from the side): 1.52 m long and 0.22 m deep under its hangers, about seven
# to one; a black body flaring to a lip at its foot, a little deeper than the wire cage under it (1.3 to 1), ten hoops
# (nine bays) and a runner down each bottom corner standing clear of a narrower glowing diffuser, four wire spring
# clips a side (at a tenth, a third, two thirds and nine tenths of its length, as the photo), two hook hangers on
# plates a quarter of its length in from each end.
HALF = 0.76          # half its length
TOP = -0.05          # the body's top under the ceiling (the hangers fill the gap)
SIDE_W = 0.058       # half the body's width at its top
LOW_W = 0.06         # and where its lip starts
LIP_Y = -0.158       # where the lip flares out
FOOT = -0.175        # the body's foot, its flat underside round the diffuser
FOOT_W = 0.076       # half the lip's width
LENS_HALF = 0.72     # half the diffuser's length
LENS_W = 0.05        # half the diffuser's width at the body
LENS_D = 0.045       # its depth under the body's foot
CAGE_W = 0.071       # half the cage's width
CAGE_LOW = FOOT - 0.095   # the cage's floor
HOOPS = 10
CLIPS = (-0.608, -0.228, 0.228, 0.608)
HANGERS = (-0.38, 0.38)
WIRE = 0.0034        # a wire's half width
WIRE_RISE = 0.0045   # its crest over that


def strip_lamp() -> sk.Mesh:
    m = sk.Mesh("strip_lamp")
    # The body: a profile in (y, z), counter-clockwise seen from +x, open at its top (edge 5, under the ceiling);
    # upright sides, a lip flaring out at its foot, the flat underside round the diffuser.
    body = [(FOOT, FOOT_W), (FOOT, -FOOT_W), (LIP_Y, -LOW_W), (TOP, -SIDE_W), (TOP, SIDE_W), (LIP_Y, LOW_W)]
    m.prism_x(body, -HALF, HALF, "black", open_edges=(3,))
    # The diffuser: a narrower glowing slab let into the foot, the cage's bays dark round it.
    lens = [(FOOT, LENS_W), (FOOT - LENS_D, LENS_W * 0.86), (FOOT - LENS_D, -LENS_W * 0.86), (FOOT, -LENS_W)]
    m.prism_x(lens, -LENS_HALF, LENS_HALF, "lens", open_edges=(3,), mat="Lens")
    # The cage: ten hoops down from the lip, under and up, a runner along each bottom corner, clear of the diffuser.
    for k in range(HOOPS):
        x = -LENS_HALF + 0.004 + (2.0 * LENS_HALF - 0.008) * k / (HOOPS - 1)
        path = [(x, FOOT, CAGE_W), (x, CAGE_LOW, CAGE_W), (x, CAGE_LOW, -CAGE_W), (x, FOOT, -CAGE_W)]
        outs = [(0.0, 0.0, 1.0), (0.0, -1.0, 1.0), (0.0, -1.0, -1.0), (0.0, 0.0, -1.0)]
        m.wire(path, outs, WIRE, WIRE_RISE, "dark_alu")
    for z in (CAGE_W, -CAGE_W):
        o = (0.0, -1.0, 1.0 if z > 0 else -1.0)
        m.wire([(-LENS_HALF, CAGE_LOW, z), (LENS_HALF, CAGE_LOW, z)], [o, o], WIRE, WIRE_RISE, "dark_alu")
    # The spring clips: a wire latch from the body's side down over the lip onto the cage's top.
    for x in CLIPS:
        for side in (1.0, -1.0):
            o = (0.0, 0.0, side)
            m.wire([(x, -0.118, side * (SIDE_W + 0.0015)), (x, FOOT - 0.006, side * (CAGE_W + 0.002))], [o, o],
                   WIRE * 1.4, WIRE_RISE, "alu")
    # The hangers: a plate on the body's top and a hook rising from it to the ceiling.
    for x in HANGERS:
        m.face_toward([(x - 0.03, TOP + 0.001, -0.03), (x + 0.03, TOP + 0.001, -0.03), (x + 0.03, TOP + 0.001, 0.03),
                       (x - 0.03, TOP + 0.001, 0.03)], (0.0, 1.0, 0.0), "dark_alu")
        m.wire([(x - 0.006, TOP, 0.0), (x + 0.008, -0.0014, 0.0)], [(0.0, 0.0, 1.0)] * 2, 0.005, 0.004, "dark_alu")
    return m


# The tunnel lamp, after photos 122005 and 121940: a stadium (two half circles joined by straight sides) 0.165 m
# wide and 0.30 m tall, five to nine; a deep black cast body, a dome black at its round ends and glass down its
# straight middle (`Lens`), four bars across it and one down its middle standing clear of it, that one's ends
# held at the rim over a screw lug top and bottom.
R = 0.0825           # the half circles' radius
S = 0.0675           # half the straight sides' length
ARC = 6              # segments in each half circle
FLANGE = 0.022       # the cast body's depth off the wall
DOME = ((0.071, 0.058), (0.05, 0.085))   # the dome's rings: radius, depth
BARS = (-0.065, -0.014, 0.014, 0.065)      # the bars across, by height
BAR_FRONT = 0.092    # how far out a bar crosses the front
BAR_TURN = 0.068
LUG = 0.009          # a screw lug's half width
LUG_H = 0.014        # how far it stands past the rim     # where a bar turns across the front (its half width there)


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
    m.face([f[n - 1], f[0], f[ARC], f[ARC + 1]], "lens", "Lens", smooth=True)
    # The cage: each bar out of the body's rim (its end inside it), up the dome's side, across its front and back down;
    # the runs up and down a strap seen side on, the crossing a round bar.
    for y in BARS:
        path = [(-R + 0.004, y, FLANGE * 0.6), (-BAR_TURN, y, BAR_FRONT), (BAR_TURN, y, BAR_FRONT),
                (R - 0.004, y, FLANGE * 0.6)]
        outs = [(-1.0, 0.0, 0.2), (-0.6, 0.0, 1.0), (0.6, 0.0, 1.0), (1.0, 0.0, 0.2)]
        m.wire(path, outs, 0.0032, 0.004, "black", flat_ends=True)
    top = S + R
    path = [(0.0, top - 0.004, FLANGE * 0.6), (0.0, S + 0.065, BAR_FRONT), (0.0, -S - 0.065, BAR_FRONT),
            (0.0, -top + 0.004, FLANGE * 0.6)]
    outs = [(0.0, 1.0, 0.2), (0.0, 0.6, 1.0), (0.0, -0.6, 1.0), (0.0, -1.0, 0.2)]
    m.wire(path, outs, 0.0032, 0.004, "black")
    # A screw lug top and bottom: a round-ended ear off the body's rim, under the bar's end.
    for sgn in (1.0, -1.0):
        y0, y1 = sgn * (top - 0.004), sgn * (top + LUG_H)
        mid = sgn * (top + LUG_H * 0.55)
        m.face_toward([(-LUG, y0, 0.006), (LUG, y0, 0.006), (LUG, mid, 0.006), (0.0, y1, 0.006), (-LUG, mid, 0.006)],
                      (0.0, 0.0, 1.0), "black")
    return m


def main() -> None:
    sk.export(strip_lamp(), "strip_lamp", STRIP_BUDGET)
    sk.export(tunnel_lamp(), "tunnel_lamp", TUNNEL_BUDGET)


if __name__ == "__main__":
    main()
