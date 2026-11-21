"""The crowd-control barrier (Subway #26, SM3; finer detail SQ1): a portable galvanised steel barrier, after the
owner's photos (art/references/maps/subway/26-crowd-barrier/), photo 2's above all: a heavy tube frame with round top
corners, its uprights running down past a bottom rail into the feet, two linking hooks on welded lugs at one end and
two eyes at the other (photos 1, 2 and 4), each upright standing in a socket on an arched bridge foot across the
barrier (photo 2), a broad flat steel bar down on rubber pads at its ends. Its infill is covered on both faces by a
taut printed banner, as barriers round closed areas carry: a muted sage sheet from the bottom rail to just under the
top rail, a darker hem standing round it, light and dark printed blocks (no words), steel eyelets in the hem and black
cable ties round the uprights and the bottom rail. The block stops BBs and sight, so the barrier reads as the solid
cover it is, never as open bars a player would try to shoot through (the coordinator's call, SQ1 attempt 2); the
bars behind the sheet are left out, never seen. Galvanised frame and feet (kind aluminium), a satin PVC banner,
rubber ties and pads.

Fills a barrier block (2.0 x 1.1 x 0.6 m, its bounds as before SQ1; the feet reach across its depth). Budget 1,200
triangles (SQ1, from 600).

Usage: python3 tools/blender/maps/crowd_barrier.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402
import hallkit as sk  # noqa: E402
import surface_kinds as kinds  # noqa: E402

L, H, D = 2.0, 1.1, 0.6
STEEL = "concrete*0.74"
FOOT_STEEL = "concrete*0.6"
WELD = "concrete*0.66"
EYELET = "concrete*0.86"
PAD = "slab*0.36"
SHEET = "sage*0.78"
HEMMED = "sage*0.62"
LIGHT = "plaster*0.92"
DARK = "slab*0.42"
TIE = "slab*0.32"
# What they are made of (SQ1): the frame and feet galvanised, the banner satin PVC, the ties and pads rubber.
prop.KINDS.update({STEEL: kinds.ALUMINIUM, FOOT_STEEL: kinds.ALUMINIUM, WELD: kinds.ALUMINIUM, EYELET: kinds.STEEL,
                   PAD: kinds.RUBBER, SHEET: kinds.SATIN, HEMMED: kinds.SATIN, LIGHT: kinds.SATIN, DARK: kinds.SATIN,
                   TIE: kinds.RUBBER})
POST = L / 2 - 0.075     # the frame's uprights, the hooks outside them
R = 0.024                # the frame tube
FOOT = 0.13              # the uprights' foot, in their sockets over the arch
RAIL = 0.24              # the bottom rail
SHEET_Y = R + 0.006      # the banner's inner face, just clear of the frame tube
SHEET_X = POST - 0.055   # its ends, inside the uprights
SHEET_Z = (RAIL, H - 0.1)  # from the bottom rail to just under the top rail
HEM = 0.035              # its hem's width
TOP = H - R              # the top rail's axis (its section's crown at the block's top)


def frame_path() -> list:
    """The frame's tube: up one end, round the top corners, down the other."""
    r = 0.15
    pts = [(-POST, FOOT)]
    for i in range(9):
        a = math.pi - (math.pi / 2) * i / 8
        pts.append((-POST + r + r * math.cos(a), TOP - r + r * math.sin(a)))
    for i in range(9):
        a = math.pi / 2 - (math.pi / 2) * i / 8
        pts.append((POST - r + r * math.cos(a), TOP - r + r * math.sin(a)))
    pts.append((POST, FOOT))
    return [(x, 0.0, z) for x, z in pts]


def flat_bar(p: prop.Prop, x: float, path: list, w: float, t: float, paint: str) -> list:
    """A flat steel bar `w` wide (along x) and `t` thick, bent along a path of (y, z) points: its underside on the
    path."""
    rings = []
    for i, (y, z) in enumerate(path):
        a = path[max(i - 1, 0)]
        b = path[min(i + 1, len(path) - 1)]
        dy, dz = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dy, dz)
        ny, nz = -dz / n, dy / n  # the bar's up, square to the path
        if nz < 0.0:
            ny, nz = -ny, -nz
        rings.append([(x - w / 2, y, z), (x + w / 2, y, z), (x + w / 2, y + ny * t, z + nz * t),
                      (x - w / 2, y + ny * t, z + nz * t)])
    return p.loft(rings, paint)


def eyelet(p: prop.Prop, x: float, z: float) -> None:
    """An eyelet in the hem on both faces."""
    at = SHEET_Y + 0.0068
    sk.disc(p, "-y", -at, x, z, 0.009, EYELET, 6)
    sk.disc(p, "+y", at, -x, z, 0.009, EYELET, 6)


def banner(p: prop.Prop) -> None:
    """The banner on both faces: a thin sheet, its hem standing proud round the edge, the printed blocks (a dark
    band with two light blocks, a light band along the foot), the eyelets and the cable ties round the
    frame (round each upright at the sheet's corners, two round the bottom rail)."""
    x0, x1 = -SHEET_X, SHEET_X
    z0, z1 = SHEET_Z
    for s in (-1.0, 1.0):
        y0, y1, y2 = s * SHEET_Y, s * (SHEET_Y + 0.003), s * (SHEET_Y + 0.006)
        p.box((x0, min(y0, y1), z0), (x1, max(y0, y1), z1), SHEET)
        for a, b, c, d in ((x0, x1, z0, z0 + HEM), (x0, x1, z1 - HEM, z1), (x0, x0 + HEM, z0 + HEM, z1 - HEM),
                           (x1 - HEM, x1, z0 + HEM, z1 - HEM)):
            p.box((a, min(y1, y2), c), (b, max(y1, y2), d), HEMMED)
        face = "-y" if s < 0 else "+y"
        at = y1 + s * 0.0008
        sk.rect(p, face, at, x0 + 0.09, x1 - 0.09, z1 - 0.3, z1 - 0.08, DARK)
        sk.rect(p, face, at + s * 0.0008, x0 + 0.15, 0.35, z1 - 0.24, z1 - 0.14, LIGHT)
        sk.rect(p, face, at + s * 0.0008, 0.5, x1 - 0.15, z1 - 0.24, z1 - 0.14, LIGHT)
        sk.rect(p, face, at, x0 + 0.09, x1 - 0.09, z0 + 0.1, z0 + 0.2, LIGHT)
    y = SHEET_Y + 0.008
    for sx in (-1.0, 1.0):
        ex = sx * (SHEET_X - HEM / 2)
        for z in (z0 + HEM / 2, z1 - HEM / 2):
            eyelet(p, ex, z)
            sk.tube(p, [(ex, -y, z), (sx * POST, -R - 0.004, z), (sx * (POST + R + 0.005), 0.0, z),
                        (sx * POST, R + 0.004, z), (ex, y, z)], 0.006, TIE, 3, caps=False)
    zb = z0 + HEM / 2
    for x in (-0.45, 0.45):
        eyelet(p, x, zb)
        sk.tube(p, [(x, -y, zb), (x, -0.022, RAIL - 0.022), (x, 0.0, RAIL - 0.026), (x, 0.022, RAIL - 0.022),
                    (x, y, zb)], 0.006, TIE, 3, caps=False)


def build() -> prop.Prop:
    p = prop.Prop("crowd_barrier")
    sk.tube(p, frame_path(), R, STEEL, 8)
    sk.tube(p, [(-POST, 0.0, RAIL), (POST, 0.0, RAIL)], 0.02, STEEL, 6, caps=False)
    banner(p)
    # the hooks at +X (round bars bent down on their welded lugs) and the eyes at -X they drop into
    for z in (0.33, 0.83):
        sk.tube(p, [(POST, 0.0, z), (L / 2 - 0.013, 0.0, z), (L / 2 - 0.013, 0.0, z - 0.13)], 0.009, STEEL, 6)
        p.box((POST + 0.01, -0.016, z - 0.03), (POST + 0.04, 0.016, z + 0.02), WELD)
        sk.tube(p, [(-POST, 0.0, z + 0.035), (-L / 2 + 0.013, 0.0, z + 0.035), (-L / 2 + 0.013, 0.0, z - 0.045),
                    (-POST, 0.0, z - 0.045)], 0.009, STEEL, 6)
    # the bridge feet across the barrier (photo 2): broad flat bars down on the floor at their ends and arched up in
    # the middle, a socket welded on the crown round each upright, a rubber pad under each end
    arch = [(-D / 2 + 0.035, 0.008), (-0.21, 0.008), (-0.16, 0.05), (-0.1, 0.1), (-0.05, FOOT - 0.012),
            (0.05, FOOT - 0.012), (0.1, 0.1), (0.16, 0.05), (0.21, 0.008), (D / 2 - 0.035, 0.008)]
    for x in (-POST, POST):
        flat_bar(p, x, arch, 0.07, 0.012, FOOT_STEEL)
        p.lathe([(FOOT - 0.004, 0.036), (FOOT + 0.07, 0.036), (FOOT + 0.08, 0.03)], FOOT_STEEL, 10, (x, 0.0, 0.0),
                "z", cap=False)
        for y in (-D / 2 + 0.055, D / 2 - 0.055):
            p.box((x - 0.045, y - 0.055, -0.0018), (x + 0.045, y + 0.055, 0.008), PAD)
    return p


if __name__ == "__main__":
    build().export("crowd_barrier.glb", budget=1200)
