"""Subway's plant-room ventilation fan housing (SM4, model 29), from the owner's photos
(art/references/maps/subway/29-fan-housing: industrial air handling units): a long boxed unit of light grey panels in
a galvanised angle frame on a skid with fork pockets; a bank of four round fans in its +x end, each in a deep
galvanised shroud behind a bar guard (photos 4-6); two access doors with lever handles, an inspection window, a
louvred intake and a control box with an isolator on its front (-y); lifting eyes on the top corners, and a duct
transition rising from the roof to a round spigot. Its blocks are 3 x 2.5 m and 2.2 m high.

Light grey and galvanised, dusty and scuffed, no writing or maker's marks.

Writes assets/models/props/fan_housing.glb, one vertex-coloured mesh filling its box exactly (x its length, y its
depth, z up; Godot: x across, y up, z deep).

Usage: python3 -I tools/blender/maps/fan_housing.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

BUDGET = 3000
LONG, DEEP, HIGH = 3.0, 2.5, 2.2
HL, HD = LONG * 0.5, DEEP * 0.5
SHIFT = 0.11         # the housing stands this far back in its box, its front's control box and isolator in front
BD = HD - SHIFT      # the housing's half-depth, built round y = 0 and moved back by SHIFT once built
SKID = 0.16          # the skid's height
TOP = 1.98           # the housing's roof
FRAME = 0.06         # the galvanised angles' width
INSET = 0.035        # the panels sit this far inside the frame's outer faces
FAN_R = 0.44         # a fan shroud's outer radius
SEG = 24             # a fan shroud's segments


def fan(k: wk.Kit, y: float, z: float, x: float) -> None:
    """One fan in the +x end: a galvanised shroud standing proud of the panel at x, the dark fan disc inside it with
    its hub and blades, and a guard of horizontal bars across the opening."""
    out = HL - 0.004
    k.lathe([(x, FAN_R), (out, FAN_R), (out, FAN_R - 0.05), (x + 0.006, FAN_R - 0.05)], "galv", segments=SEG,
            centre=(0.0, y, z), axis="x", cap=False)
    disc = [(x + 0.006, y + (FAN_R - 0.05) * math.cos(2 * math.pi * i / SEG),
             z + (FAN_R - 0.05) * math.sin(2 * math.pi * i / SEG)) for i in range(SEG)]
    k.fan(disc, (1.0, 0.0, 0.0), "grille")
    k.lathe([(x + 0.006, 0.09), (x + 0.018, 0.06), (x + 0.024, 0.0)], "duct", segments=8, centre=(0.0, y, z), axis="x",
            cap=False)  # the hub
    for i in range(5):  # the blades, pitched, between the hub and the shroud
        a = 2 * math.pi * i / 5 + 0.3
        b = a + 0.42
        r0, r1 = 0.08, FAN_R - 0.08
        k.quad([(x + 0.016, y + r0 * math.cos(a), z + r0 * math.sin(a)),
                (x + 0.008, y + r0 * math.cos(b), z + r0 * math.sin(b)),
                (x + 0.008, y + r1 * math.cos(b + 0.2), z + r1 * math.sin(b + 0.2)),
                (x + 0.018, y + r1 * math.cos(a + 0.15), z + r1 * math.sin(a + 0.15))], "duct")
    gx = out - 0.008
    for i in range(7):  # the guard's bars across the opening, and one upright through the middle
        dz = (i - 3) * (FAN_R - 0.06) / 3.4
        half = math.sqrt(max(0.0, (FAN_R - 0.04) ** 2 - dz * dz))
        k.sqbar((gx, y - half, z + dz), (gx, y + half, z + dz), 0.014, "steel_bare", h=0.01)
    k.sqbar((gx - 0.012, y, z - FAN_R + 0.05), (gx - 0.012, y, z + FAN_R - 0.05), 0.012, "steel_bare")


def frame(k: wk.Kit) -> None:
    """The galvanised angle frame: corner posts, top and bottom rails, posts between the front's panels."""
    f = FRAME
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            x0, x1 = sorted((sx * HL, sx * (HL - f)))
            y0, y1 = sorted((sy * BD, sy * (BD - f)))
            k.blk((x0, y0, SKID), (x1, y1, TOP), "galv")
    for z0, z1 in ((SKID, SKID + f), (TOP - f, TOP)):
        for sy in (-1.0, 1.0):
            y0, y1 = sorted((sy * BD, sy * (BD - f)))
            k.blk((-HL + f, y0, z0), (HL - f, y1, z1), "galv")
        for sx in (-1.0, 1.0):
            x0, x1 = sorted((sx * HL, sx * (HL - f)))
            k.blk((x0, -BD + f, z0), (x1, BD - f, z1), "galv")
    for x in (-0.35, 0.55):  # posts dividing the long sides into bays
        for sy in (-1.0, 1.0):
            y0, y1 = sorted((sy * BD, sy * (BD - 0.03)))
            k.blk((x - 0.03, y0, SKID + f), (x + 0.03, y1, TOP - f), "galv_dark")
    k.blk((HL - 0.03, -0.03, SKID + f), (HL, 0.03, TOP - f), "galv_dark")  # the end's middle post
    k.blk((HL - 0.03, -BD + f, 1.04), (HL, BD - f, 1.1), "galv_dark")      # and its middle rail
    for sx in (-1.0, 1.0):  # lifting eyes on the top corners
        for sy in (-1.0, 1.0):
            k.prism([(-0.035, 0.0), (0.035, 0.0), (0.025, 0.06), (-0.025, 0.06)], "x", -0.005, 0.005, "steel_bare",
                    offset=(sx * (HL - 0.03), sy * (BD - 0.03), TOP))


def skid(k: wk.Kit) -> None:
    """The base: channel runners along the long sides with fork pockets, cross members, a deck plate."""
    for sy in (-1.0, 1.0):
        y0, y1 = sorted((sy * BD, sy * (BD - 0.12)))
        k.panel((-HL, y0, 0.0), (HL, y1, SKID), "galv", step=0.5, skip=("-z",))
        for px in (-0.75, 0.75):  # fork pockets: dark mouths in the runner's face
            yf = sy * (BD + 0.001)
            pts = [(px - 0.18, yf, 0.03), (px + 0.18, yf, 0.03), (px + 0.18, yf, 0.12), (px - 0.18, yf, 0.12)]
            k.quad(pts if sy < 0 else list(reversed(pts)), "grille")
    for x in (-HL, HL - 0.12):
        k.blk((x, -BD + 0.12, 0.0), (x + 0.12, BD - 0.12, SKID), "galv_dark")
    k.blk((-HL + 0.12, -BD + 0.12, SKID - 0.02), (HL - 0.12, BD - 0.12, SKID), "galv_dark")


def front(k: wk.Kit) -> None:
    """The -y side: two access doors with lever handles and hinges, an inspection window, the louvred intake, the
    control box with its isolator, a plain warning plate."""
    y = -BD + INSET - 0.002
    for x0, x1 in ((-HL + FRAME + 0.04, -0.4), (-0.3, 0.5)):  # the doors' shut lines
        for xa, xb, za, zb in ((x0, x0 + 0.012, SKID + 0.1, TOP - 0.1), (x1 - 0.012, x1, SKID + 0.1, TOP - 0.1),
                               (x0, x1, SKID + 0.1, SKID + 0.112), (x0, x1, TOP - 0.112, TOP - 0.1)):
            k.quad([(xa, y, za), (xb, y, za), (xb, y, zb), (xa, y, zb)], "hazard_black")
        for z in (0.55, 1.6):  # hinges on the door's left edge
            k.cyl((x0 + 0.02, y - 0.015, z - 0.07), 0.015, 0.14, "steel_bare", seg=6)
        hx = x1 - 0.08
        k.blk((hx - 0.03, y - 0.02, 1.0), (hx + 0.03, y, 1.14), "plinth")  # a lever handle on its plate
        k.sqbar((hx, y - 0.04, 1.07), (hx - 0.16, y - 0.04, 1.07), 0.025, "plinth")
        k.blk((hx - 0.015, y - 0.04, 1.06), (hx + 0.015, y - 0.02, 1.08), "plinth")
    # the inspection window in the right door, a dark pane in a rubber surround
    wx, wz = 0.1, 1.45
    k.blk((wx - 0.17, y - 0.012, wz - 0.12), (wx + 0.17, y, wz + 0.12), "rubber")
    k.quad([(wx - 0.14, y - 0.013, wz - 0.09), (wx + 0.14, y - 0.013, wz - 0.09), (wx + 0.14, y - 0.013, wz + 0.09),
            (wx - 0.14, y - 0.013, wz + 0.09)], "glass")
    # the louvred intake in the right-hand bay
    ix0, ix1, iz0, iz1 = 0.75, HL - FRAME - 0.12, 0.5, 1.7
    k.blk((ix0 - 0.04, y - 0.03, iz0 - 0.04), (ix1 + 0.04, y, iz1 + 0.04), "galv")
    k.quad([(ix0, y - 0.031, iz0), (ix1, y - 0.031, iz0), (ix1, y - 0.031, iz1), (ix0, y - 0.031, iz1)], "grille")
    n = 11
    for i in range(n):
        z = iz0 + 0.03 + (iz1 - iz0 - 0.08) * i / (n - 1)
        k.prism([(y - 0.031, z), (y - 0.07, z - 0.03), (y - 0.07, z - 0.012), (y - 0.031, z + 0.02)], "x", ix0, ix1,
                "galv")
    # the control box on the left door's side, its isolator switch, a conduit to the roof
    cx0, cx1, cz0, cz1 = -0.95, -0.55, 1.1, 1.6
    k.blk((cx0, y - 0.18, cz0), (cx1, y, cz1), "cab_grey")
    k.blk((cx0 - 0.005, y - 0.185, cz1 - 0.01), (cx1 + 0.005, y - 0.002, cz1 + 0.01), "cab_dark")
    k.blk((-0.8, y - 0.21, 1.27), (-0.7, y - 0.18, 1.37), "label_yellow")  # the isolator's plate and handle
    k.blk((-0.765, y - 0.25, 1.24), (-0.735, y - 0.21, 1.4), "hazard_black")
    k.cyl(((cx0 + cx1) * 0.5, y - 0.09, cz1), 0.025, TOP - cz1, "duct", seg=6)
    s, wxz = 0.13, (-1.2, 1.55)  # a plain warning triangle
    k.quad([(wxz[0] - s * 0.5, y - 0.001, wxz[1]), (wxz[0] + s * 0.5, y - 0.001, wxz[1]),
            (wxz[0], y - 0.001, wxz[1] + s * 0.87)], "hazard_black")
    t = s * 0.72
    k.quad([(wxz[0] - t * 0.5, y - 0.002, wxz[1] + (s - t) * 0.3), (wxz[0] + t * 0.5, y - 0.002,
            wxz[1] + (s - t) * 0.3), (wxz[0], y - 0.002, wxz[1] + (s - t) * 0.3 + t * 0.87)], "label_yellow")


def roof(k: wk.Kit) -> None:
    """The roof's duct transition: a square base on the roof rising to a round spigot with a flange, at the -x end."""
    cx, cy = -0.7, 0.2
    sq, r = 0.5, 0.36
    n = 16
    base = []
    for i in range(n):  # a square ring with as many points as the round one, so the loft twists cleanly
        a = 2 * math.pi * (i + 0.5) / n
        c, s = math.cos(a), math.sin(a)
        m = max(abs(c), abs(s))
        base.append((cx + sq * c / m, cy + sq * s / m, TOP))
    mid = [(p[0], p[1], TOP + 0.06) for p in base]
    rnd = [(cx + r * math.cos(2 * math.pi * (i + 0.5) / n), cy + r * math.sin(2 * math.pi * (i + 0.5) / n), HIGH - 0.06)
           for i in range(n)]
    k.loft([base, mid, rnd], "duct", cap0=False, cap1=False)
    k.lathe([(HIGH - 0.06, r), (HIGH - 0.06, r + 0.035), (HIGH - 0.02, r + 0.035), (HIGH - 0.02, r),
             (HIGH, r - 0.01)], "galv", segments=n, centre=(cx, cy, 0.0), axis="z", start=math.pi / n, cap=False)
    disc = [(cx + (r - 0.01) * math.cos(2 * math.pi * (i + 0.5) / n),
             cy + (r - 0.01) * math.sin(2 * math.pi * (i + 0.5) / n), HIGH - 0.03) for i in range(n)]
    k.fan(disc, (0.0, 0.0, 1.0), "grille")  # the spigot's blanking: dark inside
    k.bolts([(cx + (r + 0.02) * math.cos(a), cy + (r + 0.02) * math.sin(a), HIGH - 0.02)
             for a in (2 * math.pi * i / 8 for i in range(8))], 0.01, 0.008, "z", "steel_bare", seg=4)


def build() -> object:
    k = wk.Kit("fan_housing")
    skid(k)
    k.mark("skid")
    k.panel((-HL + INSET, -BD + INSET, SKID), (HL - INSET, BD - INSET, TOP - 0.01), "fan_panel", step=0.5,
            skip=("-z",))
    k.blk((-HL + FRAME, -BD + FRAME, TOP - 0.02), (HL - FRAME, BD - FRAME, TOP), "fan_panel")
    frame(k)
    k.mark("body, frame")
    for y in (-0.6, 0.6):
        for z in (0.62, 1.5):
            fan(k, y, z, HL - INSET)
    k.mark("fans")
    front(k)
    k.mark("front")
    roof(k)
    k.mark("roof")
    # the back (+y): panel bolts down the bays' edges
    k.bolts([(x, BD - INSET, z) for x in (-HL + 0.12, -0.45, -0.25, 0.45, 0.65, HL - 0.12)
             for z in (0.45, 1.05, 1.65)], 0.012, 0.008, "y", "steel_bare", seg=4)
    k.mark("bolts")
    ob = k.build()
    ob.data.transform(Matrix.Translation((0.0, SHIFT, 0.0)))
    return ob


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint in ("fan_panel", "cab_grey", "cab_dark"):
        col = wt.mix(c, wk.lin(wk.GRIME), 0.2 * wt.smooth(0.55, 0.8, wt.fbm(p, 0.2, 31)))  # scuffs, handprints
        return wk.grime(p, n, col, floor=SKID, seed=21)
    if paint in ("galv", "galv_dark"):
        col = wk.rusty(p, n, c, seed=33, amount=0.18, streaks=False)  # white rust spots on old galvanising
        return wk.grime(p, n, col, seed=27, amount=0.8)
    if paint == "grille":
        return wt.mix(c, wk.lin(wk.SOOT), 0.3 * wt.fbm(p, 0.2, 35))
    return wk.grime(p, n, c, seed=4, amount=0.6)


def main() -> None:
    wk.check_colours(list(wk.PAINT))
    wk.reset()
    ob = build()
    wk.finish(ob, (-HL, -HD, 0.0), (HL, HD, HIGH))
    wk.bake(ob, weather, jitter={"fan_panel": 0.03, "galv": 0.04})
    wk.write(ob, "fan_housing", BUDGET)
    if "--render" in sys.argv:
        out = sys.argv[sys.argv.index("--render") + 1]
        wk.render(wk.quarter_views(LONG, DEEP, HIGH), out, "SM4 fan housing (Subway map prop, 3 x 2.5 x 2.2 m)")


if __name__ == "__main__":
    main()
