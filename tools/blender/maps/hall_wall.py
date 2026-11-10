"""Depot's hall walls (Dev 3, the hall shell): three 8 m bays that line the hall's four 8 m walls,
assets/models/props/hall_wall.glb (the plain bay), hall_shutter.glb (a roller shutter) and hall_exit.glb (a fire exit).

From the owner's photos (references/maps/william-2026-11-09/hall_wall_bay) and the roof photos beside them: a painted
blockwork dado on a concrete kerb, a steel flashing on its top, then the profiled steel liner of the cladding (ribs
upright, a lap halfway up) with a band of translucent rooflight sheets under the eaves, and the hall's portal frame
(the roof trusses' galvanised grey, SL3) at each bay's ends: an I-section column on a base plate, a knee bracket and
the eaves beam the trusses land on. A conduit runs along at 3 m on saddle clips.
- **hall_shutter**: a roller shutter 4.5 m wide in steel guides under its coil box, curved slats, a bottom rail with a
  rubber seal, hazard-striped guard posts at the guides' feet (ref 1) and a push-button box on the right.
- **hall_exit**: a pair of crimson fire doors (refs 5, 7) in a steel frame under a concrete lintel: push bars, vertical
  latch rods, kick plates and closers, a green exit sign (a running figure and an arrow, no words) above, a fire
  extinguisher on its bracket and a call point beside them. No brands, no text.

Each bay is 8 m wide (x), 8 m tall and the wall's 0.5 m deep, its front (-Y here, +Z in the game) the hall's side; it
fills its cell of the wall's box exactly. The column is split down its web: half at each end, so bays side by side
make whole columns, and PropLayout lays the cells on the roof's 8 m truss grid (PropDressConfig.bay_pitch) so every
column stands under a truss. Budgets: 2,000 triangles the plain bay, 4,000 a feature bay (the planning list's 1,500
and 3,000 a 6 m bay, at 8 m). Plain vertex colours, no texture.

    python -I tools/blender/maps/hall_wall.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402  first: it sets up bpy and the replica helpers
import hardsurface as hs  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET_PLAIN = 2000
BUDGET_FEATURE = 4000
HALF = 4.0              # half the bay's width
FRONT = -0.25           # the box's front face (y)
TOP = 8.0
# Heights (m)
KERB = 0.15
BLOCK_TOP = 2.40
COURSE = 0.225
BLOCK_PITCH = 0.5       # a block's length: 16 a bay, so the bond carries on across bays
CLAD_FOOT = 2.50
LAP = 4.40
LIGHT = (6.30, 7.00)    # the rooflight band
EAVES = 7.55
CONDUIT_Z = 3.0
# Depths (y; more negative is further into the hall)
BLOCK_FACE = -0.20
KERB_FACE = -0.23
LINER = -0.10           # the cladding's troughs
RIB = -0.125            # its crests (a shallow 25 mm rib, so far walls don't shimmer)
RIB_PITCH = 8.0 / 24.0  # 24 ribs a bay (a 333 mm profile)
COLUMN_DEPTH = 0.25     # flange front at the box face, web back to the middle
FLANGE_HALF = 0.15
FLANGE_T = 0.02
WEB_HALF = 0.006


def sweep(b: hs.Builder, profile: list, axis: str, a0: float, a1: float, mat: str) -> list:
    """Quads swept along `axis` from a0 to a1 between consecutive (u, v) points of an open `profile`; each faces the
    profile's left as it runs (its normal (-dv, du)). Axes: x sweeps (y, z) profiles, z sweeps (x, y), y sweeps (x, z)."""
    def p3(u: float, v: float, a: float) -> Vector:
        return Vector((a, u, v)) if axis == "x" else Vector((u, v, a)) if axis == "z" else Vector((u, a, v))

    out = []
    for (u0, v0), (u1, v1) in zip(profile, profile[1:]):
        want = p3(-(v1 - v0), u1 - u0, 0.0) - p3(0.0, 0.0, 0.0)
        out += quad(b, [p3(u0, v0, a0), p3(u0, v0, a1), p3(u1, v1, a1), p3(u1, v1, a0)], mat, want)
    return out


def quad(b: hs.Builder, pts: list, mat: str, want: Vector) -> list:
    """A face through `pts`, wound so its normal points along `want`."""
    pts = [Vector(p) for p in pts]
    n = (pts[1] - pts[0]).cross(pts[2] - pts[0])
    if n.dot(want) < 0.0:
        pts.reverse()
    return mk.quad(b, [tuple(p) for p in pts], mat)


def front_rect(b: hs.Builder, x0: float, x1: float, z0: float, z1: float, y: float, mat: str) -> None:
    """A flat rectangle facing the hall at depth y."""
    quad(b, [(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], mat, Vector((0, -1, 0)))


def box(b: hs.Builder, lo: tuple, hi: tuple, mat: str, skip: str = "") -> None:
    """A box's faces but those named in `skip` (+x -x +y -y +z -z): hidden faces left out."""
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    faces = {
        "-y": ([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], (0, -1, 0)),
        "+y": ([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], (0, 1, 0)),
        "-x": ([(x0, y0, z0), (x0, y1, z0), (x0, y1, z1), (x0, y0, z1)], (-1, 0, 0)),
        "+x": ([(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], (1, 0, 0)),
        "-z": ([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)], (0, 0, -1)),
        "+z": ([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], (0, 0, 1)),
    }
    for key, (pts, n) in faces.items():
        if key not in skip.split():
            quad(b, pts, mat, Vector(n))


def bar(b: hs.Builder, a: tuple, c: tuple, r: float, mat: str, sides: int = 8) -> None:
    mk.cylinder(b, a, c, r, mat, sides=sides, caps=False)


# --------------------------------------------------------------------------------------------------------- the wall

def kerb(b: hs.Builder, x0: float, x1: float) -> None:
    sweep(b, [(KERB_FACE, 0.0), (KERB_FACE, KERB - 0.02), (KERB_FACE + 0.02, KERB), (BLOCK_FACE, KERB)], "x", x0, x1,
          "Kerb")


def blockwork(b: hs.Builder, x0: float, x1: float, z0: float, z1: float, flash: bool = True) -> None:
    """Courses of painted block from z0 to z1 between x0 and x1: each course's face with a struck bed joint under
    it, and its head joints (thin strips just proud, stretcher bond a half block on each course, on the bay's grid
    so it carries on across bays) where they fall inside x0..x1."""
    n = max(1, round((z1 - z0) / COURSE))
    h = (z1 - z0) / n
    for k in range(n):
        c0, c1 = z0 + h * k, z0 + h * (k + 1)
        sweep(b, [(BLOCK_FACE + 0.008, c0), (BLOCK_FACE, c0 + 0.012), (BLOCK_FACE, c1)], "x", x0, x1, "Block")
        shift = BLOCK_PITCH * 0.5 * (k % 2)
        j = -HALF + shift
        while j <= HALF + 1e-6:
            if x0 + 0.02 < j < x1 - 0.02:
                front_rect(b, j - 0.006, j + 0.006, c0 + 0.012, c1, BLOCK_FACE - 0.0015, "Joint")
            j += BLOCK_PITCH
    if flash:
        flashing(b, x0, x1, z1)


def flashing(b: hs.Builder, x0: float, x1: float, z1: float) -> None:
    """The flashing over the blockwork's top at z1, sloping back to the cladding."""
    sweep(b, [(BLOCK_FACE, z1), (BLOCK_FACE - 0.015, z1), (BLOCK_FACE - 0.015, z1 + 0.03), (RIB + 0.005, CLAD_FOOT)],
          "x", x0, x1, "Flash")


def cladding(b: hs.Builder, x0: float, x1: float, z0: float, z1: float, mat: str, proud: float = 0.0) -> None:
    """The profiled liner from z0 to z1: trapezoid ribs every RIB_PITCH on the bay's grid, cut at x0 and x1."""
    prof = []
    k0 = math.floor((x0 + HALF) / RIB_PITCH)
    k1 = math.ceil((x1 + HALF) / RIB_PITCH)
    for k in range(k0, k1):
        s = -HALF + k * RIB_PITCH
        # trough, rising flank, crest, falling flank (fractions of a pitch)
        for f, y in ((0.0, LINER), (0.34, LINER), (0.5, RIB), (0.64, RIB), (0.8, LINER)):
            prof.append((s + f * RIB_PITCH, y - proud))
    prof.append((-HALF + k1 * RIB_PITCH, LINER - proud))
    # clip to x0..x1
    clipped = []
    for (xa, ya), (xb, yb) in zip(prof, prof[1:]):
        if xb <= x0 or xa >= x1:
            continue
        if xa < x0:
            ya = ya + (yb - ya) * (x0 - xa) / (xb - xa)
            xa = x0
        if xb > x1:
            yb = ya + (yb - ya) * (x1 - xa) / (xb - xa)
            xb = x1
        if not clipped or abs(clipped[-1][0] - xa) > 1e-6:
            clipped.append((xa, ya))
        clipped.append((xb, yb))
    # sweep up z; profile (x, y) traced along +x faces -y with normal (-dy, dx): flip by tracing it as (x, y)
    # going +x, whose left (normal (-dv, du)) is +y, so reverse it to face the hall
    sweep(b, list(reversed(clipped)), "z", z0, z1, mat)


def column_half(b: hs.Builder, side: float) -> None:
    """Half the portal frame's column at the bay's end `side` (-1 left, +1 right), split down its web: the flange's
    face and inner edge, its back face beside the web, and the web's face, from the base plate to the eaves beam; with
    half its base plate and anchor bolts and a knee bracket under the eaves."""
    e = side * HALF
    fx = e - side * FLANGE_HALF
    wx = e - side * WEB_HALF
    z0, z1 = 0.025, EAVES
    y_f, y_b = FRONT + 0.012, FRONT + 0.012 + FLANGE_T
    xs = sorted((e, fx))
    front_rect(b, xs[0], xs[1], z0, z1, y_f, "Frame")
    quad(b, [(fx, y_f, z0), (fx, y_b, z0), (fx, y_b, z1), (fx, y_f, z1)], "Frame", Vector((-side, 0, 0)))
    xw = sorted((wx, fx))
    quad(b, [(xw[0], y_b, z0), (xw[1], y_b, z0), (xw[1], y_b, z1), (xw[0], y_b, z1)], "Frame", Vector((0, 1, 0)))
    quad(b, [(wx, y_b, z0), (wx, LINER, z0), (wx, LINER, z1), (wx, y_b, z1)], "Frame", Vector((-side, 0, 0)))
    # the base plate (half) and two anchor bolts
    px = e - side * 0.22
    pxs = sorted((e, px))
    box(b, (pxs[0], FRONT, 0.0), (pxs[1], BLOCK_FACE + 0.02, 0.025), "Frame", "-z +y " + ("-x" if side < 0 else "+x"))
    for by in (FRONT + 0.035,):
        for bx in (e - side * 0.17, e - side * 0.035):
            mk.cylinder(b, (bx, by, 0.025), (bx, by, 0.045), 0.012, "Steel", sides=6, caps=True)
    # the knee bracket: a triangular stiffener under the eaves beam, beside the web
    kx = e - side * 0.012
    quad(b, [(kx, FRONT + 0.03, EAVES), (kx, FRONT + 0.03, EAVES - 0.45), (kx, LINER - 0.01, EAVES)], "Frame",
         Vector((-side, 0, 0)))
    # bolts through the flange at the eaves
    for bz in (EAVES - 0.08, EAVES - 0.2):
        bx = e - side * 0.08
        mk.cylinder(b, (bx, y_f, bz), (bx, FRONT, bz), 0.012, "Steel", sides=6, caps=True)


def eaves_beam(b: hs.Builder) -> None:
    """The eaves beam along the wall's top, an I-section the trusses land on: its bottom flange's underside, edge and
    top, the web's face and the top flange's underside and edge (its top is under the roof)."""
    y0, y1 = FRONT, LINER + 0.02
    yw = (y0 + y1) * 0.5
    t = 0.018
    prof = [(yw, TOP - t), (y0, TOP - t), (y0, TOP), ]
    sweep(b, list(reversed(prof)), "x", -HALF, HALF, "Frame")
    sweep(b, [(y0, EAVES + t), (yw, EAVES + t), (yw, TOP - t)], "x", -HALF, HALF, "Frame")
    sweep(b, [(y1, EAVES), (y0, EAVES), (y0, EAVES + t), (yw - 0.0, EAVES + t)], "x", -HALF, HALF, "Frame")
    # the cladding's head flashing tucked under it
    sweep(b, [(RIB - 0.005, EAVES - 0.06), (y1, EAVES)], "x", -HALF, HALF, "Flash")


def conduit(b: hs.Builder, x0: float, x1: float) -> None:
    y = RIB - 0.022
    bar(b, (x0, y, CONDUIT_Z), (x1, y, CONDUIT_Z), 0.012, "Steel", sides=8)
    for cx in (-3.0, -1.0, 1.0, 3.0):
        if x0 + 0.05 < cx < x1 - 0.05:
            sweep(b, [(RIB, CONDUIT_Z - 0.03), (y - 0.014, CONDUIT_Z - 0.016), (y - 0.016, CONDUIT_Z + 0.016),
                      (RIB, CONDUIT_Z + 0.03)], "x", cx - 0.012, cx + 0.012, "Steel")


def upper(b: hs.Builder, x0: float, x1: float, z0: float) -> None:
    """The cladding from z0 to the eaves between x0 and x1 (the lap's upper sheet a little proud), its rooflights,
    then the frame's two half columns, the eaves beam and the bay's back (the hall's outside, never seen from in it,
    there so the bay fills its box's depth)."""
    if z0 < LAP:
        cladding(b, x0, x1, z0, LAP, "Clad")
    cladding(b, x0, x1, max(z0, LAP), LIGHT[0], "Clad", proud=0.004)
    cladding(b, x0, x1, LIGHT[0], LIGHT[1], "Rooflight", proud=0.006)
    cladding(b, x0, x1, LIGHT[1], EAVES - 0.06, "Clad", proud=0.004)
    for side in (-1.0, 1.0):
        column_half(b, side)
    eaves_beam(b)
    quad(b, [(-HALF, -FRONT, 0.0), (HALF, -FRONT, 0.0), (HALF, -FRONT, TOP), (-HALF, -FRONT, TOP)], "Back",
         Vector((0, 1, 0)))


def plain() -> object:
    b = hs.Builder("HallWall", [])
    kerb(b, -HALF, HALF)
    blockwork(b, -HALF, HALF, KERB, BLOCK_TOP)
    upper(b, -HALF, HALF, CLAD_FOOT)
    conduit(b, -HALF, HALF)
    return b.build()


# --------------------------------------------------------------------------------------------------------- shutter

SHUT_HALF = 2.25
SHUT_TOP = 4.70
SLAT = 0.08
GUIDE_W = 0.11
HOOD_HALF = SHUT_HALF + GUIDE_W + 0.3   # the coil box's half width, past the guides and the low cladding's ends


def shutter() -> object:
    b = hs.Builder("HallShutter", [])
    g0, g1 = -SHUT_HALF - GUIDE_W, SHUT_HALF + GUIDE_W
    # the wall round the opening: blockwork and the low cladding cut at the guides, cladding over the coil box
    for x0, x1 in ((-HALF, g0), (g1, HALF)):
        kerb(b, x0, x1)
        blockwork(b, x0, x1, KERB, BLOCK_TOP)
        cladding(b, x0, x1, CLAD_FOOT, LAP, "Clad")
    hood_top = SHUT_TOP + 0.62
    # beside the coil box the lap's upper sheet, over it the rest of the wall
    cladding(b, -HALF, -HOOD_HALF, LAP, hood_top, "Clad", proud=0.004)
    cladding(b, HOOD_HALF, HALF, LAP, hood_top, "Clad", proud=0.004)
    upper(b, -HALF, HALF, hood_top)
    conduit(b, -HALF, g0 - 0.2)
    conduit(b, g1 + 0.2, HALF)
    # the curtain: curved slats from the floor to the hood, set back in the opening
    yc = LINER + 0.03
    n = round((SHUT_TOP - 0.06) / SLAT)
    h = (SHUT_TOP - 0.06) / n
    for k in range(n):
        z0 = 0.06 + h * k
        sweep(b, [(yc, z0), (yc - 0.012, z0 + h * 0.22), (yc - 0.018, z0 + h * 0.55), (yc - 0.012, z0 + h * 0.85),
                  (yc - 0.002, z0 + h)], "x", -SHUT_HALF, SHUT_HALF, "Slat")
    # the bottom rail and its rubber seal
    box(b, (-SHUT_HALF, yc - 0.035, 0.012), (SHUT_HALF, yc + 0.01, 0.06), "Rail", "-x +x +y")
    box(b, (-SHUT_HALF, yc - 0.02, 0.0), (SHUT_HALF, yc + 0.005, 0.012), "Rubber", "-x +x +y -z")
    # the guides: steel channels up each side, their reveal back to the curtain
    for side in (-1.0, 1.0):
        xi, xo = side * SHUT_HALF, side * (SHUT_HALF + GUIDE_W)
        lo, hi = sorted((xi, xo))
        box(b, (lo, FRONT + 0.06, 0.0), (hi, yc + 0.02, SHUT_TOP), "Guide", "-z +y +z")
        # the opening's reveal: blockwork end and cladding end beside the guide
        rx = side * (SHUT_HALF + GUIDE_W)
        quad(b, [(rx, BLOCK_FACE, KERB), (rx, LINER, KERB), (rx, LINER, BLOCK_TOP), (rx, BLOCK_FACE, BLOCK_TOP)],
             "Block", Vector((-side, 0, 0)))
        # a guard post at the guide's foot, yellow with black stripes on its front and inner side
        p0, p1 = sorted((side * (SHUT_HALF + 0.02), side * (SHUT_HALF + 0.17)))
        box(b, (p0, FRONT + 0.002, 0.0), (p1, FRONT + 0.15, 1.2), "Guard", "-z +y")
        stripes(b, p0, p1, 0.05, 1.15, FRONT + 0.0005, "-y")
        stripes_side(b, side * (SHUT_HALF + 0.02) - side * 0.0015, FRONT + 0.002, FRONT + 0.15, 0.05, 1.15, -side)
    # the coil box over the opening, from the lap (over the curtain's and the guides' tops) out past the low
    # cladding's ends, so the wall shows no gap beside it
    box(b, (-HOOD_HALF, FRONT + 0.01, LAP), (HOOD_HALF, LINER, hood_top), "Hood", "+y")
    sweep(b, [(FRONT + 0.01, hood_top), (FRONT + 0.03, hood_top + 0.03), (LINER, hood_top + 0.03)], "x",
          -HOOD_HALF, HOOD_HALF, "Hood")
    # its end plates' motor housing on the right
    mk.cylinder(b, (HOOD_HALF, FRONT + 0.12, SHUT_TOP + 0.3), (HOOD_HALF + 0.25, FRONT + 0.12, SHUT_TOP + 0.3),
                0.11, "Rail", sides=12, caps=True)
    # the push-button box on the right, beside the guide
    bx0 = SHUT_HALF + GUIDE_W + 0.25
    box(b, (bx0, BLOCK_FACE - 0.035, 1.25), (bx0 + 0.16, BLOCK_FACE, 1.55), "Control", "+y")
    for bz, mat in ((1.47, "Go"), (1.40, "Go"), (1.32, "Stop")):
        mk.cylinder(b, (bx0 + 0.08, BLOCK_FACE - 0.035, bz), (bx0 + 0.08, BLOCK_FACE - 0.047, bz), 0.02, mat, sides=8,
                    caps=True)
    bar(b, (bx0 + 0.08, BLOCK_FACE - 0.02, 1.55), (bx0 + 0.08, BLOCK_FACE - 0.02, SHUT_TOP + 0.3), 0.012, "Steel")
    return b.build()


def stripes(b: hs.Builder, x0: float, x1: float, z0: float, z1: float, y: float, facing: str) -> None:
    """Black 45-degree stripes over a face from x0 to x1, z0 to z1 at depth y: parallelograms cut to the face."""
    w = x1 - x0
    step = 0.1
    z = z0 - w
    while z < z1:
        a, c = z, z + step * 0.5
        # a band between the lines z' = a + (x - x0) and z' = c + (x - x0), cut to z0..z1
        pts = []
        for zz, xx in ((a, x0), (a + w, x1), (c + w, x1), (c, x0)):
            pts.append((xx, max(z0, min(z1, zz))))
        if pts[2][1] - pts[1][1] > 1e-4 or pts[3][1] - pts[0][1] > 1e-4:
            quad(b, [(px, y, pz) for px, pz in pts], "Hazard", Vector((0, -1, 0)))
        z += step


def stripes_side(b: hs.Builder, x: float, y0: float, y1: float, z0: float, z1: float, facing: float) -> None:
    w = y1 - y0
    step = 0.1
    z = z0 - w
    while z < z1:
        a, c = z, z + step * 0.5
        pts = []
        for zz, yy in ((a, y0), (a + w, y1), (c + w, y1), (c, y0)):
            pts.append((yy, max(z0, min(z1, zz))))
        if pts[2][1] - pts[1][1] > 1e-4 or pts[3][1] - pts[0][1] > 1e-4:
            quad(b, [(x, py, pz) for py, pz in pts], "Hazard", Vector((facing, 0, 0)))
        z += step


# ------------------------------------------------------------------------------------------------------- fire exit

DOOR_HALF = 0.68        # the pair's half width (two 0.68 m leaves): tall and narrow, as in the photos
DOOR_TOP = 2.22
FRAME_W = 0.06
LINTEL = BLOCK_TOP - DOOR_TOP - FRAME_W  # the lintel fills to the blockwork's top, under its flashing


def fire_exit() -> object:
    b = hs.Builder("HallExit", [])
    o0, o1 = -DOOR_HALF - FRAME_W, DOOR_HALF + FRAME_W
    n0, n1 = NICHE_X
    for x0, x1 in ((-HALF, n0), (n1, o0), (o1, HALF)):
        blockwork(b, x0, x1, KERB, BLOCK_TOP)
    blockwork(b, n0, n1, KERB, NICHE_Z[0], flash=False)
    blockwork(b, n0, n1, NICHE_Z[1], BLOCK_TOP)
    for x0, x1 in ((-HALF, o0), (o1, HALF)):
        kerb(b, x0, x1)
    # the lintel over the frame, then blockwork to the flashing
    sweep(b, [(BLOCK_FACE, DOOR_TOP + FRAME_W), (BLOCK_FACE, DOOR_TOP + FRAME_W + LINTEL)], "x", o0, o1, "Lintel")
    quad(b, [(o0, BLOCK_FACE, DOOR_TOP + FRAME_W), (o1, BLOCK_FACE, DOOR_TOP + FRAME_W),
             (o1, LINER, DOOR_TOP + FRAME_W), (o0, LINER, DOOR_TOP + FRAME_W)], "Lintel", Vector((0, 0, -1)))
    flashing(b, o0, o1, BLOCK_TOP)
    upper(b, -HALF, HALF, CLAD_FOOT)
    # the conduit steps up over the sign
    conduit(b, -HALF, -1.6)
    conduit(b, 1.6, HALF)
    yd = LINER + 0.02        # the leaves' faces, set back in the frame
    # the frame: jambs and head, their faces and reveals
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * DOOR_HALF, side * (DOOR_HALF + FRAME_W)))
        box(b, (lo, BLOCK_FACE - 0.012, 0.0), (hi, yd + 0.01, DOOR_TOP + FRAME_W), "DoorFrame", "-z +y +z")
    box(b, (-DOOR_HALF, BLOCK_FACE - 0.012, DOOR_TOP), (DOOR_HALF, yd + 0.01, DOOR_TOP + FRAME_W), "DoorFrame",
        "-x +x +y +z")
    # the leaves, a hair apart, each with its kick plate, push bar, latch rod and closer
    for side in (-1.0, 1.0):
        x0, x1 = sorted((side * 0.004, side * DOOR_HALF))
        front_rect(b, x0, x1, 0.008, DOOR_TOP, yd, "Door")
        quad(b, [(side * 0.004, yd, 0.008), (side * 0.004, yd + 0.02, 0.008), (side * 0.004, yd + 0.02, DOOR_TOP),
                 (side * 0.004, yd, DOOR_TOP)], "DoorEdge", Vector((-side, 0, 0)))
        k0, k1 = sorted((side * 0.06, side * (DOOR_HALF - 0.04)))
        box(b, (k0, yd - 0.003, 0.03), (k1, yd, 0.33), "Kick", "+y")
        # push bar: two end housings and the bar between them, at 1 m
        hx_in, hx_out = side * 0.12, side * (DOOR_HALF - 0.1)
        for hx in (hx_in, hx_out):
            h0, h1 = sorted((hx, hx - side * 0.07))
            box(b, (h0, yd - 0.075, 0.96), (h1, yd, 1.06), "Bar", "+y")
        bar(b, (min(hx_in, hx_out) + 0.04, yd - 0.06, 1.01), (max(hx_in, hx_out) - 0.04, yd - 0.06, 1.01), 0.018,
            "BarSteel", sides=8)
        # the vertical latch rod near the meeting edge
        rx = side * 0.09
        bar(b, (rx, yd - 0.025, 0.04), (rx, yd - 0.025, 0.96), 0.008, "BarSteel", sides=6)
        bar(b, (rx, yd - 0.025, 1.06), (rx, yd - 0.025, DOOR_TOP - 0.04), 0.008, "BarSteel", sides=6)
        # the closer at the head, its arm to the frame
        c0, c1 = sorted((side * 0.18, side * 0.5))
        box(b, (c0, yd - 0.06, DOOR_TOP - 0.11), (c1, yd, DOOR_TOP - 0.03), "Closer", "+y")
        mk.beam(b, (side * 0.42, yd - 0.07, DOOR_TOP - 0.06), (side * 0.62, BLOCK_FACE - 0.015, DOOR_TOP + 0.03),
                0.02, 0.012, "Closer", caps=True)
    # the exit sign above: a green box with a pale running figure and arrow (pictogram only)
    sz0, sz1 = 2.62, 2.92
    box(b, (-0.36, RIB - 0.06, sz0), (0.36, RIB, sz1), "Sign", "+y")
    pictogram(b, 0.0, (sz0 + sz1) * 0.5, RIB - 0.0615)
    bar(b, (0.0, RIB - 0.03, sz1), (0.0, RIB - 0.03, CONDUIT_Z), 0.01, "Steel", sides=6)
    bar(b, (-1.6, RIB - 0.022, CONDUIT_Z), (1.6, RIB - 0.022, CONDUIT_Z), 0.012, "Steel", sides=8)
    # the extinguisher on its bracket, left of the door, and the call point
    fire_point(b)
    box(b, (1.3, BLOCK_FACE - 0.045, 1.3), (1.42, BLOCK_FACE, 1.42), "CallPoint", "+y")
    front_rect(b, 1.32, 1.40, 1.32, 1.40, BLOCK_FACE - 0.0465, "CallGlass")
    bar(b, (1.36, BLOCK_FACE - 0.02, 1.42), (1.36, BLOCK_FACE - 0.02, BLOCK_TOP), 0.009, "Steel", sides=6)
    return b.build()


NICHE_X = (-1.80, -1.30)    # the fire point's recess in the blockwork, on the courses' joints
NICHE_Z = (0.60, 1.50)
NICHE_BACK = -0.02


def fire_point(b: hs.Builder) -> None:
    """The fire point left of the doors: a recess in the blockwork with a crimson board at its back and an
    extinguisher standing on a bracket in it, its hose clipped down its side."""
    n0, n1 = NICHE_X
    z0, z1 = NICHE_Z
    front_rect(b, n0, n1, z0, z1, NICHE_BACK, "FirePoint")
    quad(b, [(n0, BLOCK_FACE, z0), (n1, BLOCK_FACE, z0), (n1, NICHE_BACK, z0), (n0, NICHE_BACK, z0)], "Block",
         Vector((0, 0, 1)))
    quad(b, [(n0, BLOCK_FACE, z1), (n1, BLOCK_FACE, z1), (n1, NICHE_BACK, z1), (n0, NICHE_BACK, z1)], "Joint",
         Vector((0, 0, -1)))
    for x, n in ((n0, 1.0), (n1, -1.0)):
        quad(b, [(x, BLOCK_FACE, z0), (x, NICHE_BACK, z0), (x, NICHE_BACK, z1), (x, BLOCK_FACE, z1)], "Joint",
             Vector((n, 0, 0)))
    ex, ey = (n0 + n1) * 0.5, -0.105
    base = z0 + 0.04
    box(b, (ex - 0.1, ey - 0.03, z0), (ex + 0.1, NICHE_BACK, base), "Steel", "-z +y")
    b.lathe([(base, 0.0), (base, 0.07), (base + 0.02, 0.077), (base + 0.5, 0.077), (base + 0.56, 0.066),
             (base + 0.6, 0.03)], "Extinguisher", segments=16, centre=(ex, ey, 0.0), axis="z", cap=True)
    top = base + 0.6
    b.lathe([(top, 0.022), (top + 0.07, 0.022), (top + 0.08, 0.0)], "Valve", segments=8, centre=(ex, ey, 0.0),
            axis="z", cap=True)
    mk.beam(b, (ex - 0.03, ey, top + 0.075), (ex + 0.09, ey, top + 0.095), 0.025, 0.012, "Valve", caps=True)
    hose = [(ex + 0.02, ey - 0.02, top + 0.04), (ex + 0.1, ey - 0.03, top - 0.05), (ex + 0.1, ey - 0.06, base + 0.25),
            (ex + 0.08, ey - 0.06, base + 0.1)]
    for a, c in zip(hose, hose[1:]):
        bar(b, a, c, 0.009, "Hose", sides=6)


def pictogram(b: hs.Builder, cx: float, cz: float, y: float) -> None:
    """The running figure through a door and an arrow, in pale strokes on the sign's face."""
    s = 0.24
    strokes = [
        # the door
        ((-0.30, -0.10), (-0.30, 0.11), 0.022), ((-0.30, 0.11), (-0.16, 0.11), 0.022),
        ((-0.16, 0.11), (-0.16, -0.10), 0.022),
        # the runner: body, legs, arms
        ((-0.02, 0.05), (-0.06, -0.03), 0.03), ((-0.06, -0.03), (-0.12, -0.10), 0.024),
        ((-0.06, -0.03), (0.0, -0.06), 0.024), ((0.0, -0.06), (0.01, -0.11), 0.022),
        ((-0.02, 0.04), (-0.09, 0.01), 0.02), ((-0.02, 0.04), (0.04, 0.06), 0.02),
        # the arrow
        ((0.10, 0.0), (0.30, 0.0), 0.03), ((0.30, 0.0), (0.23, 0.07), 0.026), ((0.30, 0.0), (0.23, -0.07), 0.026),
    ]
    for (ax, az), (bx, bz), w in strokes:
        a = Vector((cx + ax * s * 3.0, cz + az * s * 1.2))
        c = Vector((cx + bx * s * 3.0, cz + bz * s * 1.2))
        d = (c - a).normalized()
        n = Vector((-d.y, d.x)) * w * 0.5
        a -= d * w * 0.4
        c += d * w * 0.4
        pts = [a - n, c - n, c + n, a + n]
        quad(b, [(p.x, y, p.y) for p in pts], "SignFigure", Vector((0, -1, 0)))
    # the head
    hx, hz = cx + 0.0 * s * 3.0, cz + 0.11 * s * 1.2
    ring = [(hx + 0.018 * math.cos(2 * math.pi * i / 8), y, hz + 0.018 * math.sin(2 * math.pi * i / 8))
            for i in range(8)]
    quad(b, ring, "SignFigure", Vector((0, -1, 0)))


# ------------------------------------------------------------------------------------------------------------ main

COLOURS = {
    "Kerb": mk.PALETTE["slab"], "Block": mk.PALETTE["plaster"], "Joint": (mk.PALETTE["plaster"], 0.84),
    "Flash": mk.PALETTE["grey"], "Clad": mk.PALETTE["concrete"], "Rooflight": mk.PALETTE["cream"],
    "Frame": mk.PALETTE["grey"], "Steel": mk.PALETTE["steel"], "Back": mk.PALETTE["concrete"],
    "Slat": mk.PALETTE["grey"], "Rail": mk.PALETTE["steel"], "Rubber": mk.PALETTE["rubber"],
    "Guide": (mk.PALETTE["steel"], 0.9), "Guard": mk.PALETTE["yellow"], "Hazard": mk.PALETTE["rubber"],
    "Hood": (mk.PALETTE["steel"], 0.85), "Control": mk.PALETTE["concrete"], "Go": mk.PALETTE["green"],
    "Stop": mk.PALETTE["crimson"],
    "Lintel": mk.PALETTE["concrete"], "DoorFrame": mk.PALETTE["grey"], "Door": mk.PALETTE["crimson"],
    "DoorEdge": (mk.PALETTE["crimson"], 0.8), "Kick": mk.PALETTE["grey"], "Bar": mk.PALETTE["steel"],
    "BarSteel": mk.PALETTE["grey"], "Closer": mk.PALETTE["steel"], "Sign": mk.PALETTE["green"],
    "SignFigure": mk.PALETTE["cream"], "Extinguisher": mk.PALETTE["crimson"], "FirePoint": (mk.PALETTE["crimson"], 0.85), "Valve": mk.PALETTE["rubber"],
    "Hose": mk.PALETTE["rubber"], "CallPoint": mk.PALETTE["crimson"], "CallGlass": mk.PALETTE["cream"],
}


def main() -> None:
    for name, build, budget in (("hall_wall", plain, BUDGET_PLAIN), ("hall_shutter", shutter, BUDGET_FEATURE),
                                ("hall_exit", fire_exit, BUDGET_FEATURE)):
        hs.reset()
        mk.paints(COLOURS)
        ob = build()
        mk.clean(ob)
        mk.report(ob, name, budget)
        mk.export_prop(ob, name)


if __name__ == "__main__":
    main()
