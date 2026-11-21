"""Subway's street entrance (the owner, 2026-11-21: "a station entrance/exit door just behind where the players start
in the ticket hall ... an escalator/stairs going up to an outside street. The player shouldn't be able to go out to
the street so maybe add a gate"): the doorway in the ticket hall's street-end wall behind the Street team's spawns.

One model filling its block (tools/subway/layout.py ENTRANCE, facing into the hall): 4.8 m wide, 5.0 m high, 11.5 m
deep. At its front, in the doorway, a folding lattice gate drawn shut and padlocked under a stainless portal, a dark
fascia with a "way out" sign (light and dark blocks, no words) over it. Behind the gate, a tiled passage: a fixed
stair up one side and an escalator up the other, 2.6 m up to a landing, and at its far end the street's daylight
through the exit: paving, a kerb, the road, a railing, a lamp post and the shopfronts across it, a pale sky over them.
Look only: the block's face is the gate's plane, so nothing passes it; the lamps over the stairs are the map's
(build_map.py lamps, ENTRANCE_LAMPS).

Blender space: front (into the hall) -Y, width X, up Z; the front at Y = -5.75.
Budget 5,150 triangles.

Usage: python3 tools/blender/maps/station_entrance.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402
import hallkit as sk  # noqa: E402
import surface_kinds as kinds  # noqa: E402

W, D, H = 4.8, 11.5, 5.0
HW = W / 2
FRONT, BACK = -D / 2, D / 2
WALL_IN = 2.25          # the passage's tiled walls' inner faces (x = +-WALL_IN)
DOOR_H = 3.2            # the hall's doorway, walled over above (layout.py ENTRANCE door_h)
CEIL = 4.95             # the passage's ceiling's underside
F0 = 0.012              # the passage's floor's top over the hall's
GATE_Y = FRONT + 0.1    # the folding gate's plane, just behind the block's face
FOOT_Y = FRONT + 2.6    # the stair's and escalator's foot
RISE = 2.6              # up to the street's landing
RUN = RISE / math.tan(math.radians(30.0))   # 30 degrees, as an escalator
TOP_Y = FOOT_Y + RUN    # their head
EXIT_Y = BACK - 2.3     # the exit's portal, the passage's end; the street beyond it
LINTEL = 4.15           # the exit portal's head: low enough that the sky's top never shows from the hall
STAIR_X = (-WALL_IN, -0.36)      # the fixed stair's width
DIVIDE_X = (-0.35, -0.05)        # the dividing balustrade between them
ESC_X = (0.05, WALL_IN)          # the escalator, its balustrades either side

TILE = "plaster*0.97"
GROUT = "plaster*0.84"
BAND = "green*0.6"            # the station's dark green tile band
FLOOR = "slab*0.78"
FLOOR_TOP = "slab*0.7"
NOSING = "yellow*0.9"
CEILING = "concrete*0.86"
SEAM = "concrete*0.7"
STEP = "concrete*0.6"          # the escalator's treads: ribbed aluminium, its grooves darker
STEP_RISE = "slab*0.5"
RAIL = "rubber*1.05"           # the escalator's handrail
FASCIA = "slab*0.34"
SIGN = "slab*0.31"
GATE = "steel*1.25"
GATE_DARK = "steel*0.95"
# the street, daylight: paler than anything in the station
# the street's paints, each its own string ("*1" on the end) so the daylight kind below is theirs alone
PAVING = "concrete*1.0*1"
KERB = "concrete*0.86*1"
ROAD = "slab*0.8*1"
ROAD_LINE = "cream*0.98*1"
SKY = "plaster*1.0*1"
FACADE = "sand*1.1*1"
FACADE_B = "heartwood*0.95*1"
WINDOW = "grey*0.9*1"
SHOP = "sage*0.8*1"
SHOP_B = "crimson*0.55*1"
AWNING = "teal*0.62*1"
AWNING_TEXT = "cream*0.9*1"
POST = "slab*0.45*1"
SIGN_WORDS = "yellow*0.95"     # the way-out sign's letters, yellow on black as a station's
SIGN_NAME = "cream*0.97"       # the station's name over them
prop.KINDS.update({GATE: sk.kinds.STEEL, GATE_DARK: sk.kinds.STEEL, STEP: sk.kinds.ALUMINIUM, RAIL: sk.kinds.RUBBER,
                   WINDOW: sk.kinds.GLASS, AWNING: sk.kinds.SATIN, FASCIA: sk.kinds.SATIN, SIGN: sk.kinds.GLOSS})


# The street lies in daylight: its faces glow by their own colour (surface kind 9, lit: look_vertex.gdshader), so from
# the hall it reads as the sunlit street up the stair, not a room lit by the passage's lamps; so do the way-out sign's
# letters, as a lit sign's. The escalator's treads are brushed aluminium.
prop.KINDS.update({k: kinds.LIT for k in (PAVING, KERB, ROAD, ROAD_LINE, SKY, FACADE, FACADE_B, WINDOW, SHOP,
                                          SHOP_B, AWNING, AWNING_TEXT, POST, SIGN_WORDS, SIGN_NAME)})
prop.KINDS[STEP] = kinds.ALUMINIUM


def floor_z(y: float) -> float:
    """The passage's floor (and the stair's pitch line) at y: level, then up at 30 degrees, then level."""
    if y <= FOOT_Y:
        return 0.0
    if y >= TOP_Y:
        return RISE
    return (y - FOOT_Y) / RUN * RISE


def walls(p: prop.Prop) -> None:
    """The passage's side walls, tiled: white tiles in joints, the green band at a dado's height, following the floor
    up the slope; the ceiling's panels; the floors either end."""
    pts_y = [GATE_Y + 0.05, FOOT_Y, TOP_Y, EXIT_Y]
    for side in (-1.0, 1.0):
        face = "+x" if side < 0 else "-x"
        at = side * WALL_IN
        p.box((min(at, side * HW), FRONT + 0.15, 0.0), (max(at, side * HW), EXIT_Y + 0.15, CEIL), TILE)

        # u along the face: +y on "+x", -y on "-x"
        def u(y: float) -> float:
            return y if face == "+x" else -y
        o = at - side * 0.002
        # the band, a strip 0.95 to 1.1 m over the floor, in three straight runs
        for a, b in zip(pts_y, pts_y[1:]):
            za, zb = floor_z(a), floor_z(b)
            pts = [(u(a), za + 0.95), (u(b), zb + 0.95), (u(b), zb + 1.1), (u(a), za + 1.1)]
            if face == "-x":
                pts = [pts[1], pts[0], pts[3], pts[2]]
            sk.poly(p, face, o, pts, BAND)
        # tile joints: level courses every 0.3 m, upright joints every 0.6 m
        o2 = at - side * 0.0015
        for k in range(1, 16):
            z = k * 0.3
            if z > CEIL - 0.1:
                break
            y0 = GATE_Y + 0.05
            while y0 < EXIT_Y and floor_z(y0) > z - 0.05:
                y0 += 0.1
            if y0 >= EXIT_Y:
                continue
            a, b = sorted((u(y0), u(EXIT_Y)))
            sk.rect(p, face, o2, a, b, z - 0.004, z + 0.004, GROUT)
        y = GATE_Y + 0.6
        while y < EXIT_Y:
            a, b = sorted((u(y - 0.004), u(y + 0.004)))
            sk.rect(p, face, o2, a, b, floor_z(y) + 0.02, CEIL - 0.02, GROUT)
            y += 0.6
        # posters up the stair's side: three in stainless frames, colour blocks (no words)
        if side < 0:
            for k, cols in enumerate((("crimson*0.95", "cream*0.92"), ("teal*0.92", "butter*0.9"),
                                      ("violet*0.95", "plaster*0.95"))):
                yc = FOOT_Y + RUN * (0.2 + 0.3 * k)
                zc = floor_z(yc) + 1.75
                a, b = u(yc - 0.5), u(yc + 0.5)
                sk.slab(p, face, at, 0.02, a, b, zc - 0.75, zc + 0.75, sk.STAINLESS)
                f = at + 0.0205
                sk.rect(p, face, f, a + 0.04, b - 0.04, zc - 0.71, zc + 0.71, cols[1])
                sk.rect(p, face, f + 0.0005, a + 0.08, b - 0.08, zc - 0.3, zc + 0.6, cols[0])
                sk.lines(p, face, f + 0.0005, a + 0.08, b - 0.3, zc - 0.62, zc - 0.38, "slab*0.4", 3)
    # the ceiling: a slab under the block's top, its panels' seams across it, to the exit's lintel
    p.box((-WALL_IN, FRONT + 0.15, CEIL), (WALL_IN, EXIT_Y + 0.15, H), CEILING)
    y = FRONT + 0.75
    while y < EXIT_Y:
        sk.rect(p, "+z", CEIL - 0.0015, -WALL_IN, WALL_IN, y + 0.006, y - 0.006, SEAM)
        y += 1.2
    for x in (-1.2, 1.2):
        sk.rect(p, "+z", CEIL - 0.0015, x + 0.006, x - 0.006, FRONT + 0.2, EXIT_Y, SEAM)
    # the floors: the foot's landing and the head's, tiled
    p.box((-WALL_IN, FRONT + 0.15, 0.0), (WALL_IN, FOOT_Y, F0), FLOOR)
    p.box((-WALL_IN, TOP_Y, RISE - 0.15), (WALL_IN, EXIT_Y + 0.15, RISE), FLOOR)
    for y0, y1, z in ((FRONT + 0.15, FOOT_Y, F0), (TOP_Y, EXIT_Y, RISE)):
        y = y0 + 0.6
        while y < y1:
            sk.rect(p, "+z", z + 0.0015, -WALL_IN, WALL_IN, y - 0.005, y + 0.005, FLOOR_TOP)
            y += 0.6
    # the tactile warning across the stair's foot and head (yellow, ribbed)
    sk.rect(p, "+z", F0 + 0.002, STAIR_X[0], STAIR_X[1], FOOT_Y - 0.6, FOOT_Y - 0.2, NOSING)
    sk.rect(p, "+z", RISE + 0.002, STAIR_X[0], STAIR_X[1], TOP_Y + 0.2, TOP_Y + 0.6, NOSING)


def stair(p: prop.Prop) -> None:
    """The fixed stair: 15 risers, each tread with a yellow nosing; its handrail on the wall."""
    n = 15
    rise, going = RISE / n, RUN / n
    x0, x1 = STAIR_X
    for i in range(n):
        y0 = FOOT_Y + i * going
        p.box((x0, y0, 0.0), (x1, y0 + going, (i + 1) * rise), FLOOR)
        sk.rect(p, "+z", (i + 1) * rise + 0.0015, x0, x1, y0 + 0.01, y0 + 0.06, NOSING)
    # the wall's handrail on brackets, 0.9 m over the pitch line, level past each end
    zr = 0.9
    pts = [(x0 + 0.08, FOOT_Y - 0.4, zr), (x0 + 0.08, FOOT_Y, zr), (x0 + 0.08, TOP_Y, RISE + zr),
           (x0 + 0.08, TOP_Y + 0.4, RISE + zr)]
    sk.tube(p, pts, 0.022, sk.STAINLESS, sides=8)
    for t in (0.1, 0.5, 0.9):
        y = FOOT_Y + RUN * t
        z = floor_z(y) + zr
        p.box((x0, y - 0.012, z - 0.012), (x0 + 0.08, y + 0.012, z + 0.012), sk.STAINLESS)


def balustrade(p: prop.Prop, x0: float, x1: float, glass: bool) -> None:
    """A balustrade from the foot to the head: a stainless deck to 0.3 m over the pitch line (glass panels over it to
    0.95 m on the escalator's), its handrail along the top, round at either end."""
    lead = 0.9
    ya, yb = FOOT_Y - lead, TOP_Y + lead

    def prof(top: float) -> list:
        return [(ya, 0.0), (FOOT_Y, 0.0), (TOP_Y, RISE - 0.02), (yb, RISE - 0.02), (yb, RISE + top),
                (TOP_Y, RISE + top), (FOOT_Y, top), (ya, top)]

    p.prism(prof(0.3), "x", x0, x1, sk.STAINLESS)
    xm = (x0 + x1) / 2
    if glass:
        p.prism([(ya + 0.1, 0.3), (FOOT_Y, 0.3), (TOP_Y, RISE + 0.3), (yb - 0.1, RISE + 0.3), (yb - 0.1, RISE + 0.92),
                 (TOP_Y, RISE + 0.92), (FOOT_Y, 0.92), (ya + 0.1, 0.92)], "x", xm - 0.006, xm + 0.006, sk.GLASS)
        zr = 0.97
    else:
        zr = 0.34
    # round newels either end: a half circle back from the rail's top down to its foot
    r = 0.12
    foot = [(ya + r + r * math.cos(a), zr - r + r * math.sin(a))
            for a in (math.radians(-90 - 45 * k) for k in range(5))]
    head = [(yb - r + r * math.cos(a), RISE + zr - r + r * math.sin(a))
            for a in (math.radians(90 - 45 * k) for k in range(5))]
    pts = [(xm, y, z) for y, z in foot] + [(xm, FOOT_Y, zr), (xm, TOP_Y, RISE + zr)] + [(xm, y, z) for y, z in head]
    sk.tube(p, pts, 0.04 if glass else 0.03, RAIL if glass else sk.STAINLESS, sides=8)


def escalator(p: prop.Prop) -> None:
    """The escalator: its steps a ribbed dark tread on each, yellow edge lines, flat at either end over its comb
    plates; balustrades either side with glass panels and black handrails."""
    xa, xb = ESC_X[0] + 0.19, ESC_X[1] - 0.19
    lift = F0 + 0.004
    step_r = 0.2
    n = round(RISE / step_r)
    going = RUN / n
    prof = [(FOOT_Y - 0.9, 0.0), (FOOT_Y + 0.15, 0.0)]
    for i in range(n):
        y = FOOT_Y + 0.15 + i * going
        prof += [(y, (i + 1) * step_r), (y + going, (i + 1) * step_r)]
    prof += [(TOP_Y + 0.9, RISE), (TOP_Y + 0.9, RISE - 0.1), (FOOT_Y + 0.4, -lift), (FOOT_Y - 0.9, -lift)]
    # the steps as one sawtooth swept across, a hair over the floors either end
    p.prism(prof, "x", xa, xb, STEP, (0.0, 0.0, lift))
    for i in range(n):
        y = FOOT_Y + 0.15 + i * going
        z = (i + 1) * step_r + lift + 0.0015
        sk.rect(p, "+z", z, xa, xb, y + 0.005, y + 0.04, NOSING)
        for x in (xa + 0.02, xb - 0.06):
            sk.rect(p, "+z", z, x, x + 0.04, y + 0.04, min(y + going, TOP_Y + 0.9) - 0.01, NOSING)
        for k in range(1, 6):
            xr = xa + (xb - xa) * k / 6
            sk.rect(p, "+z", z, xr - 0.006, xr + 0.006, y + 0.05, y + going - 0.02, STEP_RISE)
    # comb plates at either end
    sk.rect(p, "+z", lift + 0.002, xa, xb, FOOT_Y - 0.9, FOOT_Y - 0.4, sk.STAINLESS)
    sk.rect(p, "+z", RISE + lift + 0.002, xa, xb, TOP_Y + 0.4, TOP_Y + 0.9, sk.STAINLESS)
    balustrade(p, ESC_X[0], ESC_X[0] + 0.18, True)
    balustrade(p, ESC_X[1] - 0.18, ESC_X[1], True)
    balustrade(p, *DIVIDE_X, False)


# A stroke font for the sign's few letters: each a list of strokes, each stroke (x, y) points in a cell 0.6 wide (the
# I narrower) and 1 high, drawn as flat bars.
GLYPHS = {
    "W": (0.7, [[(0, 1), (0.17, 0), (0.35, 0.62), (0.53, 0), (0.7, 1)]]),
    "A": (0.6, [[(0, 0), (0.3, 1), (0.6, 0)], [(0.13, 0.38), (0.47, 0.38)]]),
    "Y": (0.6, [[(0, 1), (0.3, 0.52), (0.6, 1)], [(0.3, 0.52), (0.3, 0)]]),
    "O": (0.6, [[(0.18, 0), (0.42, 0), (0.6, 0.2), (0.6, 0.8), (0.42, 1), (0.18, 1), (0, 0.8), (0, 0.2), (0.18, 0)]]),
    "U": (0.6, [[(0, 1), (0, 0.2), (0.15, 0), (0.45, 0), (0.6, 0.2), (0.6, 1)]]),
    "T": (0.6, [[(0, 1), (0.6, 1)], [(0.3, 1), (0.3, 0)]]),
    "M": (0.7, [[(0, 0), (0, 1), (0.35, 0.45), (0.7, 1), (0.7, 0)]]),
    "R": (0.6, [[(0, 0), (0, 1), (0.42, 1), (0.6, 0.86), (0.6, 0.64), (0.42, 0.5), (0, 0.5)], [(0.3, 0.5), (0.6, 0)]]),
    "I": (0.12, [[(0.06, 0), (0.06, 1)]]),
    "N": (0.6, [[(0, 0), (0, 1), (0.6, 0), (0.6, 1)]]),
    "S": (0.6, [[(0.6, 0.84), (0.44, 1), (0.16, 1), (0, 0.84), (0, 0.66), (0.16, 0.52), (0.44, 0.48), (0.6, 0.34),
                 (0.6, 0.16), (0.44, 0), (0.16, 0), (0, 0.16)]]),
    "E": (0.55, [[(0.55, 1), (0, 1), (0, 0), (0.55, 0)], [(0, 0.5), (0.45, 0.5)]]),
    " ": (0.35, []),
}


def lettering(p: prop.Prop, at: float, text: str, cu: float, v0: float, size: float, stroke: float, paint: str) -> None:
    """`text` on the front face at depth `at`, centred on u = cu, its baseline at v0, letters `size` high, strokes
    `stroke` thick: each stroke's bars squared off half a stroke past their ends, so their corners close."""
    gap = 0.22
    width = sum(GLYPHS[ch][0] for ch in text) + gap * (len(text) - 1)
    u = cu - width * size / 2
    for ch in text:
        w, strokes = GLYPHS[ch]
        for line in strokes:
            for (xa, ya), (xb, yb) in zip(line, line[1:]):
                a = (u + xa * size, v0 + ya * size)
                b = (u + xb * size, v0 + yb * size)
                dx, dy = b[0] - a[0], b[1] - a[1]
                n = math.hypot(dx, dy)
                tx, ty = dx / n * stroke / 2, dy / n * stroke / 2
                nx, ny = -ty, tx
                pts = [(a[0] - tx + nx, a[1] - ty + ny), (a[0] - tx - nx, a[1] - ty - ny),
                       (b[0] + tx - nx, b[1] + ty - ny), (b[0] + tx + nx, b[1] + ty + ny)]
                # counter-clockwise seen from the front (-y): u runs to the right
                area = sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]))
                sk.poly(p, "-y", at, pts if area > 0 else pts[::-1], paint)
        u += (w + gap) * size


def portal(p: prop.Prop) -> None:
    """The doorway's stainless portal in the hall's wall, the dark fascia over it with its way-out sign, and the
    folding gate drawn shut across it."""
    p.box((-HW, FRONT, 0.0), (-WALL_IN, FRONT + 0.15, H), sk.STAINLESS)
    p.box((WALL_IN, FRONT, 0.0), (HW, FRONT + 0.15, H), sk.STAINLESS)
    p.box((-WALL_IN, FRONT, DOOR_H - 0.1), (WALL_IN, FRONT + 0.15, DOOR_H + 0.08), sk.STAINLESS)
    p.box((-WALL_IN, FRONT + 0.06, DOOR_H + 0.08), (WALL_IN, FRONT + 0.15, H), FASCIA)
    # the sign: a black lightbox standing out of the fascia (inside the block's face): the station's name in cream
    # over WAY OUT in yellow, an up arrow beside it, as a station's way-out signs
    sk.slab(p, "-y", FRONT + 0.06, 0.05, -1.7, 1.7, DOOR_H + 0.22, DOOR_H + 1.12, SIGN)
    f = FRONT + 0.0095
    lettering(p, f, "MORRIN STREET", 0.0, DOOR_H + 0.82, 0.2, 0.034, SIGN_NAME)
    lettering(p, f, "WAY OUT", 0.22, DOOR_H + 0.32, 0.36, 0.058, SIGN_WORDS)
    # the up arrow: its head, then its shaft (each counter-clockwise from the front)
    sk.poly(p, "-y", f, [(-1.44, DOOR_H + 0.5), (-0.96, DOOR_H + 0.5), (-1.2, DOOR_H + 0.74)], SIGN_WORDS)
    sk.poly(p, "-y", f, [(-1.27, DOOR_H + 0.3), (-1.13, DOOR_H + 0.3), (-1.13, DOOR_H + 0.5), (-1.27, DOOR_H + 0.5)],
            SIGN_WORDS)
    # the gate: its track at the head, a guide at the foot, pickets every 0.3 m with a lattice of scissor bars
    g0, g1 = -WALL_IN, WALL_IN
    p.box((g0, GATE_Y - 0.04, DOOR_H - 0.22), (g1, GATE_Y + 0.04, DOOR_H - 0.1), GATE_DARK)
    p.box((g0, GATE_Y - 0.03, 0.0), (g1, GATE_Y + 0.03, 0.04), GATE_DARK)
    n = 15
    xs = [g0 + 0.06 + (g1 - g0 - 0.12) * k / n for k in range(n + 1)]
    for x in xs:
        p.box((x - 0.016, GATE_Y - 0.012, 0.04), (x + 0.016, GATE_Y + 0.012, DOOR_H - 0.22), GATE)
    tiers = 7
    zs = [0.12 + (DOOR_H - 0.46) * k / tiers for k in range(tiers + 1)]
    for a, b in zip(xs, xs[1:]):
        for k, (z0, z1) in enumerate(zip(zs, zs[1:])):
            yb = GATE_Y + (0.006 if k % 2 else -0.006)
            prop.beam_between(p, (a, yb, z0), (b, yb, z1), 0.022, 0.008, GATE)
            prop.beam_between(p, (a, -yb + 2 * GATE_Y, z1), (b, -yb + 2 * GATE_Y, z0), 0.022, 0.008, GATE)
    # the two leaves' meeting posts and the padlock on their hasp
    for x in (-0.03, 0.03):
        p.box((x - 0.025, GATE_Y - 0.02, 0.04), (x + 0.025, GATE_Y + 0.02, DOOR_H - 0.22), GATE_DARK)
    p.box((-0.07, GATE_Y - 0.05, 1.02), (0.07, GATE_Y - 0.02, 1.1), GATE_DARK)
    p.box((-0.035, GATE_Y - 0.08, 0.92), (0.035, GATE_Y - 0.05, 1.0), "yellow*0.75")
    sk.tube(p, [(-0.022, GATE_Y - 0.065, 1.0), (-0.022, GATE_Y - 0.065, 1.05), (0.022, GATE_Y - 0.065, 1.05),
                (0.022, GATE_Y - 0.065, 1.0)], 0.006, GATE, sides=4)


def street(p: prop.Prop) -> None:
    """The exit's portal and the street beyond it in daylight: paving, a kerb, the road with its line, a railing at
    the kerb, a lamp post, the shopfronts across the road and a pale sky over them."""
    # the exit's portal: its head down to LINTEL and its jambs
    p.box((-WALL_IN, EXIT_Y, LINTEL), (WALL_IN, EXIT_Y + 0.15, H), sk.STAINLESS)
    p.box((-HW, EXIT_Y, RISE), (-WALL_IN + 0.12, EXIT_Y + 0.15, H), sk.STAINLESS)
    p.box((WALL_IN - 0.12, EXIT_Y, RISE), (HW, EXIT_Y + 0.15, H), sk.STAINLESS)
    y0 = EXIT_Y + 0.15
    # the pavement and kerb, then the road
    kerb_y = BACK - 1.05
    p.box((-HW, y0, RISE - 0.1), (HW, kerb_y, RISE), PAVING)
    y = y0 + 0.45
    while y < kerb_y:
        sk.rect(p, "+z", RISE + 0.0015, -HW, HW, y - 0.006, y + 0.006, KERB)
        y += 0.45
    p.box((-HW, kerb_y, RISE - 0.22), (HW, kerb_y + 0.15, RISE), KERB)
    p.box((-HW, kerb_y + 0.15, RISE - 0.3), (HW, BACK - 0.02, RISE - 0.12), ROAD)
    for x in (-2.2, -0.9, 0.4, 1.6):
        sk.rect(p, "+z", RISE - 0.12 + 0.0015, x, x + 0.6, BACK - 0.6, BACK - 0.5, ROAD_LINE)
    # the railing along the kerb: posts, top rail and a mid rail
    ry = kerb_y - 0.25
    for x in (-2.1, -0.7, 0.7, 2.1):
        p.box((x - 0.025, ry - 0.025, RISE), (x + 0.025, ry + 0.025, RISE + 1.0), POST)
    for z in (RISE + 0.5, RISE + 0.98):
        p.box((-HW + 0.02, ry - 0.02, z - 0.02), (HW - 0.02, ry + 0.02, z + 0.02), POST)
    # a lamp post at the kerb, its arm over the road
    lx = -1.4
    p.box((lx - 0.05, ry + 0.15, RISE), (lx + 0.05, ry + 0.25, H - 0.05), POST)
    # the buildings either side of the exit, along the pavement: plain flanks with a window each, so the street's edges
    # are its buildings wherever it shows
    for side, face in ((-1.0, "+x"), (1.0, "-x")):
        at = side * (HW - 0.001)

        def span(ya: float, yb: float) -> tuple:
            return (ya, yb) if face == "+x" else (-yb, -ya)
        sk.rect(p, face, at, *span(y0, BACK), RISE - 0.3, H, FACADE_B if side < 0 else FACADE)
        a, b = span(y0 + 0.5, y0 + 1.2)
        sk.rect(p, face, at - side * 0.001, a, b, 3.5, 4.3, WINDOW)
    # the far side: shopfronts at street level, upper floors, the sky over them, on the block's back
    f = BACK
    sk.rect(p, "-y", f, -HW, HW, RISE - 0.3, H, SKY)
    # the buildings stop low enough that the sky shows over them through the exit, from anywhere in the hall
    sk.rect(p, "-y", f - 0.001, -HW, 0.6, RISE - 0.3, 3.85, FACADE)
    sk.rect(p, "-y", f - 0.001, 0.6, HW, RISE - 0.3, 4.05, FACADE_B)
    for x0, x1 in ((-2.2, -1.5), (-1.1, -0.4), (0.9, 1.5), (1.8, 2.3)):
        sk.rect(p, "-y", f - 0.002, x0, x1, 3.6, 3.78 if x1 < 0.6 else 3.95, WINDOW)
    sk.rect(p, "-y", f - 0.002, -2.3, 0.4, RISE - 0.3, 3.4, SHOP)
    sk.rect(p, "-y", f - 0.003, -2.1, 0.2, RISE - 0.25, 3.1, WINDOW)
    sk.rect(p, "-y", f - 0.002, 0.8, 2.3, RISE - 0.3, 3.3, SHOP_B)
    sk.rect(p, "-y", f - 0.003, 0.95, 2.15, RISE - 0.25, 3.05, WINDOW)
    sk.slab(p, "-y", f - 0.003, 0.25, -2.4, 0.5, 3.42, 3.6, AWNING)
    sk.rect(p, "-y", f - 0.004, -1.9, -0.1, 3.47, 3.56, AWNING_TEXT)


def build() -> prop.Prop:
    p = prop.Prop("station_entrance")
    walls(p)
    stair(p)
    escalator(p)
    portal(p)
    street(p)
    return p


if __name__ == "__main__":
    build().export("station_entrance.glb", budget=5150)
