"""Subway's tunnel grilles (SW2): the steel grille that shuts each running tunnel at its east end, where the tunnel runs
on round a bend out of sight (the owner, 2026-11-17: "create a tunnel that curves into the distance and continues the
train tunnels ... Block it off with a object model so players can't access it"). A works-yellow frame fitted to the
running tunnel's arched lining (straight sides to its springing, then the arc), galvanised round bars at 160 mm with
three flat rails across, a padlocked wicket gate in the middle, a hazard plate on the gate; its foot stands clear of
the running rails, which carry on under it round the bend. Scuffed, sooty and rusty, no words or names.

Look only: the tunnel's end wall behind it (StationDressing.TunnelVault.shut_end) stops bodies and BBs.

Writes assets/models/props/tunnel_grille.glb, one vertex-coloured mesh filling x -1.79..1.79 (across the tunnel),
y 0..4.09 (up from the track bed) and z 0..0.12 (its back on the end wall at z 0, its front towards the station at +z),
Godot's axes, as a wall fixture's (tools/subway/fixtures.py).

Usage: python3 -I tools/blender/maps/tunnel_grille.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
from mathutils import Vector  # noqa: E402

NAME = "tunnel_grille"
BUDGET = 1100
# The running tunnel's lining (tools/subway/layout.py RUN_VAULTS, RUN_Z0 and RUN_Z1): 3.9 m across, straight sides to
# 2.7 m over the track bed, then an arc rising 1.4 m more at its middle. The grille keeps 10 mm inside it.
LINING = 1.95                              # the lining's half width
HALF = LINING - 0.01
SPRING = 2.7
RISE = 1.4
RADIUS = (LINING * LINING + RISE * RISE) / (2.0 * RISE)
CENTRE = SPRING + RISE - RADIUS            # the arc's centre over the track bed
TOP = CENTRE + RADIUS - 0.01
DEEP = 0.12                                # Blender y: -DEEP (its front) .. 0 (its back on the wall)
FRAME = 0.1                                # the frame's face width
ARC = 18                                   # arc segments
FOOT = 0.24                                # the bottom rail's underside: clear of the rail heads
BAR_STEP = 0.16
BAR_R = 0.016
GATE = (-0.45, 0.45, FOOT, 2.15)           # the wicket gate's frame (x0, x1, z0, z1)


def outline(inset: float) -> list:
    """The lining's outline `inset` m inside the grille's edge, left foot to right foot: (x, z) points."""
    r = RADIUS - 0.01 - inset
    x = HALF - inset
    a = math.asin(min(1.0, x / r))
    pts = [(-x, 0.0)]
    for i in range(ARC + 1):
        t = -a + 2.0 * a * i / ARC
        pts.append((r * math.sin(t), CENTRE + r * math.cos(t)))
    pts.append((x, 0.0))
    return pts


def inner_top(x: float) -> float:
    """The frame's inner edge over `x`: where a bar meets it."""
    r = RADIUS - 0.01 - FRAME
    return CENTRE + math.sqrt(max(0.0, r * r - x * x))


def build() -> object:
    k = wk.Kit(NAME)
    # The frame: one channel swept from foot to foot round the lining's outline, its face towards the station.
    outer, inner = outline(0.0), outline(FRAME)
    rings = [[(o[0], 0.0, o[1]), (o[0], -DEEP + 0.012, o[1]), (n[0], -DEEP + 0.012, n[1]), (n[0], 0.0, n[1])]
             for o, n in zip(outer, inner)]
    k.loft(rings, "works_yellow", cap0=True, cap1=True, closed=True)
    # Base plates bolted to the track bed at each foot, and wall cleats bolted into the lining up each side.
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * HALF, sx * (HALF - 0.2)))
        k.blk((x0, -DEEP + 0.012, 0.0), (x1, -0.0, 0.02), "works_yellow")
        k.bolts([(sx * (HALF - 0.16), y, 0.02) for y in (-0.085, -0.03)], 0.014, 0.012, "z", "rust", seg=6)
        for z in (0.5, 1.5, 2.4):
            k.bolts([(sx * (HALF - FRAME * 0.5), -DEEP + 0.012, z)], 0.016, 0.012, "-y", "rust", seg=6)
    for t in (0.2, 0.5, 0.8):  # round the arc
        o = outer[1 + int(t * ARC)]
        n = inner[1 + int(t * ARC)]
        k.bolts([((o[0] + n[0]) * 0.5, -DEEP + 0.012, (o[1] + n[1]) * 0.5)], 0.016, 0.012, "-y", "rust", seg=6)
    k.mark("frame")
    # Three flat rails across: the bottom one over the rail heads, two higher, the top one under the springing.
    rail_x = HALF - FRAME + 0.005
    for z in (FOOT, 1.25, 2.4):
        spans = [(-rail_x, rail_x)] if z > GATE[3] else [(-rail_x, GATE[0]), (GATE[1], rail_x)]  # the gate's gap
        for a, b in spans:
            k.blk((a, -0.085, z), (b, -0.035, z + 0.07), "works_yellow")
    k.mark("rails")
    # The bars, round galvanised steel, foot rail to the frame's arc, past the gate's frame.
    n = int((2.0 * (HALF - FRAME)) / BAR_STEP)
    x0 = -(n - 1) * BAR_STEP * 0.5
    for i in range(n):
        x = x0 + i * BAR_STEP
        if GATE[0] - 0.02 < x < GATE[1] + 0.02:
            lo = GATE[3] + 0.05
        else:
            lo = FOOT + 0.02
        k.bar((x, -0.06, lo), (x, -0.06, inner_top(x) + 0.03), BAR_R, "galv", seg=6, cap=False)
    k.mark("bars")
    # The wicket gate: a flat-bar frame and its own bars, two hinges on its left, a hasp and padlock on its right, a
    # hazard plate on its face.
    g0, g1, gz0, gz1 = GATE
    w = 0.06
    for lo, hi in (((g0, gz0), (g0 + w, gz1)), ((g1 - w, gz0), (g1, gz1)), ((g0, gz0), (g1, gz0 + w)),
                   ((g0, gz1 - w), (g1, gz1))):
        k.blk((lo[0], -0.1, lo[1]), (hi[0], -0.02, hi[1]), "works_yellow")
    k.blk((g0 + w, -0.075, 1.1), (g1 - w, -0.045, 1.16), "works_yellow")  # its middle rail
    for i in range(5):
        x = g0 + w + (i + 0.5) * (g1 - g0 - 2 * w) / 5
        k.bar((x, -0.06, gz0 + w - 0.01), (x, -0.06, gz1 - w + 0.01), BAR_R, "galv", seg=6, cap=False)
    for z in (gz0 + 0.3, gz1 - 0.3):  # hinges: a knuckle on the gate's side bar
        k.cyl((g0 - 0.025, -0.06, z - 0.07), 0.022, 0.14, "frame_black", seg=8)
    k.blk((g1 - 0.02, -0.112, 1.0), (g1 + 0.05, -0.1, 1.12), "steel_bare")  # the hasp's plate
    k.blk((g1 + 0.0, -0.118, 0.93), (g1 + 0.05, -0.105, 0.99), "frame_black")  # the padlock's body
    k.bar((g1 + 0.008, -0.111, 0.99), (g1 + 0.008, -0.111, 1.03), 0.004, "steel_bare", seg=4)  # its shackle
    k.bar((g1 + 0.042, -0.111, 0.99), (g1 + 0.042, -0.111, 1.03), 0.004, "steel_bare", seg=4)
    k.bar((g1 + 0.008, -0.111, 1.03), (g1 + 0.042, -0.111, 1.03), 0.004, "steel_bare", seg=4)
    # The hazard plate: yellow, black chevrons, on the gate's upper bars.
    px0, px1, pz0, pz1 = -0.28, 0.28, 1.45, 1.8
    k.blk((px0, -0.1, pz0), (px1, -0.088, pz1), "works_yellow")
    cw = 0.07
    for i in range(-4, 5):
        x = i * 0.12
        a0, a1 = x - cw * 0.5, x + cw * 0.5
        pts = [(a0 - 0.06, pz0 + 0.03), (a1 - 0.06, pz0 + 0.03), (a1 + 0.06, pz1 - 0.03), (a0 + 0.06, pz1 - 0.03)]
        pts = [(min(max(u, px0 + 0.03), px1 - 0.03), v) for u, v in pts]
        if abs(pts[0][0] - pts[1][0]) < 0.005 and abs(pts[2][0] - pts[3][0]) < 0.005:
            continue
        k.quad([(u, -0.1015, v) for u, v in pts], "hazard_black")
    k.bolts([(x, -0.1, z) for x in (px0 + 0.025, px1 - 0.025) for z in (pz0 + 0.025, pz1 - 0.025)], 0.008, 0.004,
            "-y", "steel_bare", seg=4)
    k.mark("gate")
    return k.build()


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint == "works_yellow":
        col = wk.rusty(p, n, c, seed=31, amount=0.45)
        col = wt.mix(col, wk.lin(wk.SOOT), 0.35 * wt.fbm(p, 0.3, 33))  # tunnel soot from the trains
        return wk.grime(p, n, col, seed=12, top=4.1)
    if paint == "galv":
        col = wt.mix(c, wk.lin(wk.SOOT), 0.3 * wt.fbm(p, 0.25, 35))
        return wk.grime(p, n, wk.rusty(p, n, col, seed=37, amount=0.25, streaks=False), seed=4, top=4.1)
    if paint == "hazard_black":
        return wt.mix(c, wk.lin("steel_bare"), 0.15 * wt.fbm(p, 0.05, 39))
    return wk.grime(p, n, wk.rusty(p, n, c, seed=7, amount=0.4, streaks=False), seed=2)


def main() -> None:
    wk.reset()
    wk.check_colours(list(wk.PAINT))
    ob = build()
    wk.finish(ob, (-HALF, -DEEP, 0.0), (HALF, 0.0, TOP))
    wk.bake(ob, weather)
    wk.write(ob, NAME, BUDGET)
    if "--render" in sys.argv:
        wk.render(wk.quarter_views(2 * HALF, DEEP, TOP), sys.argv[sys.argv.index("--render") + 1],
                  "SW2 tunnel grille (Subway map prop, 3.58 x 0.12 x 4.09 m)")


if __name__ == "__main__":
    main()
