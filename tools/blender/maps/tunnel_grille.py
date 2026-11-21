"""Subway's tunnel grilles (SW2): the steel grille that shuts each running tunnel at its east end, where the tunnel runs
on round a bend out of sight (the owner, 2026-11-17: "create a tunnel that curves into the distance and continues the
train tunnels ... Block it off with a object model so players can't access it"). A works-yellow frame fitted to the
running tunnel's arched lining (straight sides to its springing, then the arc), galvanised round bars at 160 mm with
three rails across, a padlocked wicket gate in the middle, a hazard plate on the gate; its foot stands clear of
the running rails, which carry on under it round the bend. Scuffed, sooty and rusty, no words or names.

Look only: the tunnel's end wall behind it (StationDressing.TunnelVault.shut_end) stops bodies and BBs.

SQ1 (owner, 2026-11-21: every Subway model in finer detail) gave it twice the triangles: the frame is a channel now,
open towards the middle so its inside reads as a shadow line, bolted to the lining through washers; two box-section
posts stand on bolted base plates either side of the gate; the rails are angles bolted at their ends; an anti-climb
mesh of welded wires covers the lower bars and the gate's; the gate hangs on knuckled strap hinges, its padlock
through a staple, with a drop bolt at its foot.

Writes assets/models/props/tunnel_grille.glb, one vertex-coloured mesh filling x -1.94..1.94 (across the tunnel),
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
BUDGET = 2200
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
POST_X = 1.04                              # the two posts either side of the gate, clear of the running rails
MESH_WIRES = 9                             # the anti-climb mesh's wires up to the middle rail


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


def frame_ring(o: tuple, n: tuple) -> list:
    """The frame's section at one outline point: a channel, its back flange on the wall, its web round the outside,
    its front flange to the station, open towards the grille's middle (`o` the outer edge, `n` the inner)."""
    def at(w: float, y: float) -> tuple:
        u = w / FRAME
        return (o[0] + (n[0] - o[0]) * u, y, o[1] + (n[1] - o[1]) * u)
    d, t = -DEEP + 0.012, 0.012
    return [at(0.0, 0.0), at(0.0, d), at(FRAME, d), at(FRAME, d + t), at(t, d + t), at(t, -t), at(FRAME, -t),
            at(FRAME, 0.0)]


def rail(k: wk.Kit, a: float, b: float, z: float) -> None:
    """A flat-bar rail across, from a to b at z: an angle, its upright leg to the station, its flat leg back over
    the bars' line, a bolt through each end."""
    k.blk((a, -0.092, z), (b, -0.082, z + 0.07), "works_yellow")
    k.blk((a, -0.082, z), (b, -0.032, z + 0.01), "works_yellow")
    k.bolts([(x, -0.092, z + 0.035) for x in (a + 0.03, b - 0.03)], 0.014, 0.01, "-y", "rust", seg=6)


def build() -> object:
    k = wk.Kit(NAME)
    # The frame: one channel swept from foot to foot round the lining's outline, its face towards the station.
    outer, inner = outline(0.0), outline(FRAME)
    k.loft([frame_ring(o, n) for o, n in zip(outer, inner)], "works_yellow", cap0=True, cap1=True, closed=True)
    # Base plates bolted to the track bed at each foot, and the frame bolted into the lining up each side and round
    # the arc, each through a washer.
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * HALF, sx * (HALF - 0.2)))
        k.blk((x0, -DEEP + 0.012, 0.0), (x1, -0.0, 0.02), "works_yellow")
        k.bolts([(sx * (HALF - 0.16), y, 0.02) for y in (-0.085, -0.03)], 0.016, 0.012, "z", "rust", seg=6)
        for z in (0.5, 1.5, 2.4):
            k.bolts([(sx * (HALF - FRAME * 0.5), -DEEP + 0.012, z)], 0.026, 0.004, "-y", "steel_bare", seg=6)
            k.bolts([(sx * (HALF - FRAME * 0.5), -DEEP + 0.008, z)], 0.017, 0.008, "-y", "rust", seg=6)
    for t in (0.15, 0.38, 0.62, 0.85):  # round the arc
        o = outer[1 + int(t * ARC)]
        n = inner[1 + int(t * ARC)]
        c = ((o[0] + n[0]) * 0.5, (o[1] + n[1]) * 0.5)
        k.bolts([(c[0], -DEEP + 0.012, c[1])], 0.026, 0.004, "-y", "steel_bare", seg=6)
        k.bolts([(c[0], -DEEP + 0.008, c[1])], 0.017, 0.008, "-y", "rust", seg=6)
    k.mark("frame")
    # Two box-section posts standing up to the arc either side of the gate, clear of the running rails, each on a
    # bolted base plate.
    for sx in (-1.0, 1.0):
        x = sx * POST_X
        k.blk((x - 0.04, -0.1, 0.02), (x + 0.04, -0.04, inner_top(x) + 0.02), "works_yellow")
        k.blk((x - 0.1, -0.11, 0.0), (x + 0.1, -0.02, 0.02), "works_yellow")
        k.bolts([(x + dx, -0.065, 0.02) for dx in (-0.07, 0.07)], 0.014, 0.012, "z", "rust", seg=6)
    k.mark("posts")
    # Three angle rails across: the bottom one over the rail heads, two higher, the top one under the springing.
    rail_x = HALF - FRAME + 0.005
    for z in (FOOT, 1.25, 2.4):
        spans = [(-rail_x, rail_x)] if z > GATE[3] else [(-rail_x, GATE[0] - 0.03), (GATE[1] + 0.03, rail_x)]
        for a, b in spans:
            rail(k, a, b, z)
    k.mark("rails")
    # The bars, round galvanised steel, foot rail to the frame's arc, past the gate's frame and the posts.
    n = int((2.0 * (HALF - FRAME)) / BAR_STEP)
    x0 = -(n - 1) * BAR_STEP * 0.5
    for i in range(n):
        x = x0 + i * BAR_STEP
        if abs(abs(x) - POST_X) < 0.06:
            continue
        lo = GATE[3] + 0.05 if GATE[0] - 0.05 < x < GATE[1] + 0.05 else FOOT + 0.02
        k.bar((x, -0.06, lo), (x, -0.06, inner_top(x) + 0.03), BAR_R, "galv", seg=6, cap=False)
    k.mark("bars")
    # The anti-climb mesh over the lower bars: welded wires across in front of them, up to the middle rail.
    for i in range(MESH_WIRES):
        z = FOOT + 0.12 + (1.25 - FOOT - 0.16) * i / (MESH_WIRES - 1)
        for a, b in ((-rail_x, GATE[0] - 0.03), (GATE[1] + 0.03, rail_x)):
            k.sqbar((a, -0.06 - BAR_R - 0.004, z), (b, -0.06 - BAR_R - 0.004, z), 0.008, "galv", h=0.008)
    k.mark("mesh")
    # The wicket gate: a box-section frame and its own bars, a middle rail, two strap hinges on knuckles at its
    # left, a hasp and padlock on its right, a drop bolt at its foot and a hazard plate on its face.
    g0, g1, gz0, gz1 = GATE
    w = 0.06
    for lo, hi in (((g0, gz0), (g0 + w, gz1)), ((g1 - w, gz0), (g1, gz1)), ((g0 + w, gz0), (g1 - w, gz0 + w)),
                   ((g0 + w, gz1 - w), (g1 - w, gz1))):
        k.blk((lo[0], -0.1, lo[1]), (hi[0], -0.02, hi[1]), "works_yellow")
    k.blk((g0 + w, -0.075, 1.1), (g1 - w, -0.045, 1.16), "works_yellow")  # its middle rail
    for i in range(5):
        x = g0 + w + (i + 0.5) * (g1 - g0 - 2 * w) / 5
        k.bar((x, -0.06, gz0 + w - 0.01), (x, -0.06, gz1 - w + 0.01), BAR_R, "galv", seg=6, cap=False)
    for i in range(MESH_WIRES // 2):  # the gate's own mesh, under its middle rail
        z = gz0 + w + 0.08 + (1.1 - gz0 - w - 0.14) * i / (MESH_WIRES // 2 - 1)
        k.sqbar((g0 + w, -0.06 - BAR_R - 0.004, z), (g1 - w, -0.06 - BAR_R - 0.004, z), 0.008, "galv", h=0.008)
    for z in (gz0 + 0.3, gz1 - 0.3):  # hinges: knuckles on a pin by the gate's side bar, a strap along the gate
        k.cyl((g0 - 0.03, -0.06, z - 0.08), 0.022, 0.07, "frame_black", seg=8)
        k.cyl((g0 - 0.03, -0.06, z - 0.01), 0.022, 0.07, "rust", seg=8)
        k.blk((g0 - 0.03, -0.106, z - 0.025), (g0 + 0.25, -0.1, z + 0.025), "frame_black")
        k.bolts([(g0 + x, -0.106, z) for x in (0.08, 0.2)], 0.01, 0.006, "-y", "rust", seg=4)
    k.blk((g1 - 0.02, -0.112, 1.0), (g1 + 0.05, -0.1, 1.12), "steel_bare")  # the hasp's plate
    k.tube([(-0.006, 0.02), (0.006, 0.02)], [(-0.006, 0.011), (0.006, 0.011)], "steel_bare", segments=6,
           centre=(g1 + 0.025, -0.113, 1.06), axis="y")  # the staple through it
    k.blk((g1 + 0.0, -0.12, 0.93), (g1 + 0.05, -0.104, 0.99), "frame_black")  # the padlock's body
    k.bar((g1 + 0.008, -0.114, 0.99), (g1 + 0.008, -0.114, 1.03), 0.004, "steel_bare", seg=4)  # its shackle
    k.bar((g1 + 0.042, -0.114, 0.99), (g1 + 0.042, -0.114, 1.03), 0.004, "steel_bare", seg=4)
    k.bar((g1 + 0.008, -0.114, 1.03), (g1 + 0.042, -0.114, 1.03), 0.004, "steel_bare", seg=4)
    k.blk((g1 - 0.05, -0.11, gz0 + 0.06), (g1 - 0.02, -0.1, gz0 + 0.18), "steel_bare")  # the drop bolt's keeper
    k.bar((g1 - 0.035, -0.114, gz0 - 0.02), (g1 - 0.035, -0.114, gz0 + 0.24), 0.008, "steel_bare", seg=5)
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
                  "SW2 tunnel grille (Subway map prop, 3.88 x 0.12 x 4.09 m)")


if __name__ == "__main__":
    main()
