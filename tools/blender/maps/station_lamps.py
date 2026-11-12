"""Subway's lamps (SM5, models 31 and 32 of art/subway-model-list.md), from the owner's photos
(references/maps/subway/31-ceiling-lamp and 32-tunnel-lamp):

- **strip_lamp.glb** (budget 200): the fitting on every station ceiling, the caged industrial batten of the first
  photo: a dark steel body with chamfered lower edges, a bracket at each end of its top, spring clips down its sides,
  an opal diffuser under it (`Lens`, which the game draws glowing) and a wire guard of hoops and runners round the
  diffuser, a cable gland at one end. 1.5 m long (x), 0.16 m across, 0.125 m deep, on two brackets; their top (y 0) at the ceiling, so
  RoofView hangs it from each lamp spot, turned along its room.
- **tunnel_lamp.glb** (budget 150): the caged oval bulkhead of the tunnel photos (1, 2 and 4), black as the fourth:
  an oval cast body, a flange round the glass dome (`Lens`), the "eyelid" cage of two bars across and one down it,
  a screw lug top and bottom. 0.17 m wide, 0.29 m tall, 0.1 m deep; its back (z 0) on the
  wall, facing +z, its middle at the origin.

    python3 -I tools/blender/maps/station_lamps.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import stationkit as sk  # noqa: E402

STRIP_BUDGET = 200
TUNNEL_BUDGET = 150

# The strip lamp.
HALF = 0.75          # half its length
BODY_W = 0.08        # half its body's width
BODY_D = 0.065       # its body's depth under the ceiling
LENS_HALF = 0.70     # half the diffuser's length
LENS_W = 0.052       # half the diffuser's width where it meets the body
LENS_D = 0.10        # the diffuser's lowest point under the ceiling
GUARD = 0.012        # the wire guard's clearance round the diffuser
WIRE = 0.0035        # a wire's half thickness
HOOPS = 7
BRACKET = 0.012      # the end brackets' height over the body, up to the ceiling


def strip_lamp() -> sk.Mesh:
    m = sk.Mesh("strip_lamp")
    # The body: a profile in (y, z), counter-clockwise seen from +x; its top (edge 3) against the ceiling.
    body = [(-BODY_D, 0.06), (-BODY_D, -0.06), (-0.045, -BODY_W), (0.0, -BODY_W), (0.0, BODY_W), (-0.045, BODY_W)]
    m.prism_x(body, -HALF, HALF, "charcoal", open_edges=(3,))
    # The opal diffuser under it, its top (edge 5) inside the body's floor.
    lens = [(-BODY_D, LENS_W), (-0.085, 0.05), (-LENS_D, 0.03), (-LENS_D, -0.03), (-0.085, -0.05), (-BODY_D, -LENS_W)]
    m.prism_x(lens, -LENS_HALF, LENS_HALF, "lens", open_edges=(5,), mat="Lens")
    # The wire guard: hoops round the diffuser and four runners along it.
    g = GUARD
    hoop = [(-BODY_D, LENS_W + g), (-0.085 - g * 0.6, 0.05 + g), (-LENS_D - g, 0.03 + g * 0.3),
            (-LENS_D - g, -0.03 - g * 0.3), (-0.085 - g * 0.6, -0.05 - g), (-BODY_D, -LENS_W - g)]
    for k in range(HOOPS):
        x = -LENS_HALF + 0.04 + (2.0 * LENS_HALF - 0.08) * k / (HOOPS - 1)
        # a flat wire facing out: each segment a quad WIRE either side of x
        for i in range(len(hoop) - 1):
            (ya, za), (yb, zb) = hoop[i], hoop[i + 1]
            m.face([(x + WIRE, ya, za), (x - WIRE, ya, za), (x - WIRE, yb, zb), (x + WIRE, yb, zb)], "dark_alu")
    for y, z in ((-LENS_D - g, 0.03 + g * 0.3), (-LENS_D - g, -0.03 - g * 0.3), (-0.085 - g * 0.6, 0.05 + g),
                 (-0.085 - g * 0.6, -0.05 - g)):
        m.tube([(-LENS_HALF + 0.02, y, z), (LENS_HALF - 0.02, y, z)], WIRE, "dark_alu", sides=3)
    # Spring clips down each side, holding the diffuser and guard.
    for x in (-0.45, 0.45):
        for side in (-1.0, 1.0):
            z0, z1 = (BODY_W, BODY_W + 0.008) if side > 0 else (-BODY_W - 0.008, -BODY_W)
            m.box((x - 0.02, -0.075, z0), (x + 0.02, -0.02, z1), "alu", skip="u" + ("b" if side > 0 else "f"))
    # A hanging bracket at each end of its top, and the cable gland at one end.
    for x in (-0.62, 0.62):
        m.box((x - 0.025, 0.0, -0.03), (x + 0.025, BRACKET, 0.03), "dark_alu", skip="u")
    m.box((HALF, -0.045, -0.015), (HALF + 0.02, -0.015, 0.015), "black", skip="l")
    # the brackets hold it a hand's breadth under the ceiling: its top at y 0
    return m.transformed(sk.move(0.0, -BRACKET, 0.0))


# The tunnel lamp: an oval, its half width and half height.
OX, OY = 0.085, 0.13
SIDES = 10
STAND_OFF = 0.016    # the cage's bars over the glass, clear of its facets between their bends


def tunnel_lamp() -> sk.Mesh:
    m = sk.Mesh("tunnel_lamp")
    centre = (0.0, 0.0, 0.0)
    # The cast body (no back: it sits on the wall) and the flange round the glass.
    m.lathe([(1.0, 0.0), (1.0, 0.03), (0.84, 0.037)], SIDES, centre, "black", axis="z", sx=OX, sz=OY,
            cap_top=False, cap_bottom=False, smooth=True, start=math.pi / SIDES)
    # The glass dome, glowing.
    m.lathe([(0.84, 0.037), (0.76, 0.07), (0.47, 0.092)], SIDES, centre, "lens", mat="Lens", axis="z", sx=OX, sz=OY,
            cap_bottom=False, smooth=True, start=math.pi / SIDES)

    def dome(x: float, y: float) -> float:
        """How far out (z) the glass is at (x, y), a little over it."""
        r = math.sqrt((x / OX) ** 2 + (y / OY) ** 2)
        if r <= 0.47:
            return 0.092 + STAND_OFF
        if r <= 0.76:
            return 0.07 + (0.092 - 0.07) * (0.76 - r) / (0.76 - 0.47) + STAND_OFF
        return 0.037 + (0.07 - 0.037) * (0.84 - r) / (0.84 - 0.76) + STAND_OFF

    def bar(pts: list) -> None:
        """A cage bar over the glass: a ridge of two faces along the points (x, y), standing off the dome."""
        for i in range(len(pts) - 1):
            (xa, ya), (xb, yb) = pts[i], pts[i + 1]
            dx, dy = xb - xa, yb - ya
            n = math.hypot(dx, dy)
            sx, sy = -dy / n * 0.005, dx / n * 0.005
            za, zb = dome(xa, ya), dome(xb, yb)
            ridge_a, ridge_b = (xa, ya, za + 0.006), (xb, yb, zb + 0.006)
            m.face([(xa + sx, ya + sy, za), ridge_a, ridge_b, (xb + sx, yb + sy, zb)], "black")
            m.face([ridge_a, (xa - sx, ya - sy, za), (xb - sx, yb - sy, zb), ridge_b], "black")

    for y in (-0.045, 0.045):
        w = OX * 0.84 * math.sqrt(max(0.0, 1.0 - (y / (OY * 0.84)) ** 2))
        bar([(-w, y), (-w * 0.35, y), (w * 0.35, y), (w, y)])
    bar([(0.0, -OY * 0.8), (0.0, -0.02), (0.0, 0.02), (0.0, OY * 0.8)][::-1])
    # A screw lug top and bottom.
    for y0, y1 in ((OY - 0.004, OY + 0.022), (-OY - 0.022, -OY + 0.004)):
        m.box((-0.016, y0, 0.0), (0.016, y1, 0.018), "black", skip="b")
    return m


def main() -> None:
    sk.export(strip_lamp(), "strip_lamp", STRIP_BUDGET)
    sk.export(tunnel_lamp(), "tunnel_lamp", TUNNEL_BUDGET)


if __name__ == "__main__":
    main()
