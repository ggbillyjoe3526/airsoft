"""The crowd-control barrier (Subway #26, SM3; finer detail SQ1): a portable galvanised steel barrier, after the
owner's photos (art/references/maps/subway/26-crowd-barrier/): a tube frame with round top corners and a bottom rail
(photos 1, 2 and 4), close upright bars between them, a small maker's plate on the top rail's end (photo 4), the
linking hooks on one end and their eyes on the other (photos 1, 2 and 4), each hook a bent flat bar on its welded
lug, standing on two arched bridge feet across it (photo 2), each foot a flat bar with a socket round the upright and
rubber pads at its ends. A plain cover sheet is tied over its bars, as barriers put out round closed areas carry: a
hemmed banner with a dark printed band (no words), brass eyelets and black cable ties at its corners and middles. The
block stops BBs, so the barrier reads as the solid cover it is rather than a fence a player would see and shoot
through (a readability default; bare bars are a one-line change). SQ1 gave the frame its rounder tubes and the
galvanised finish (kind aluminium), the banner its hem and ties, the feet their pads.

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
STEEL = "concrete*0.72"
FOOT_STEEL = "concrete*0.62"
SHEET = "plaster*0.9"
HEM = "plaster*0.82"
PRINT = "steel*0.6"
TIE = "rubber*0.9"
EYELET = "sand*0.85"
PAD = "slab*0.4"
# What they are made of (SQ1): the frame and feet galvanised, the ties and pads rubber, the banner a satin PVC.
prop.KINDS.update({STEEL: kinds.ALUMINIUM, FOOT_STEEL: kinds.ALUMINIUM, TIE: kinds.RUBBER, PAD: kinds.RUBBER,
                   SHEET: kinds.SATIN, HEM: kinds.SATIN, EYELET: kinds.STEEL})
POST = L / 2 - 0.075     # the frame's uprights, the hooks outside them
R = 0.02                 # the frame tube
FOOT = 0.1               # the frame's foot over the floor
RAIL = 0.22              # the bottom rail
BARS = 12


def frame_path() -> list:
    """The frame's tube: up one end, round the top corners, down the other."""
    top = H - R
    r = 0.12
    pts = [(-POST, FOOT)]
    for i in range(8):
        a = math.pi - (math.pi / 2) * i / 7
        pts.append((-POST + r + r * math.cos(a), top - r + r * math.sin(a)))
    for i in range(8):
        a = math.pi / 2 - (math.pi / 2) * i / 7
        pts.append((POST - r + r * math.cos(a), top - r + r * math.sin(a)))
    pts.append((POST, FOOT))
    return [(x, 0.0, z) for x, z in pts]


def build() -> prop.Prop:
    p = prop.Prop("crowd_barrier")
    sk.tube(p, frame_path(), R, STEEL, 8)
    sk.tube(p, [(-POST, 0.0, RAIL), (POST, 0.0, RAIL)], 0.016, STEEL, 8)
    for i in range(BARS):
        x = -POST + (i + 1) * 2 * POST / (BARS + 1)
        sk.tube(p, [(x, 0.0, RAIL), (x, 0.0, H - 2 * R)], 0.008, STEEL, 4, caps=False)
    # the maker's plate on the top rail's end (photo 4): a small riveted steel tag
    p.box((-POST + 0.07, -0.011, H - 0.125), (-POST + 0.15, -0.008, H - 0.065), "concrete*0.8")
    for x in (-POST + 0.08, -POST + 0.14):
        sk.disc(p, "-y", -0.0118, x, H - 0.075, 0.004, "concrete*0.6", 6)
    # the hooks at +X (two flat bars bent down on their welded lugs) and the eyes at -X they drop into
    for z in (0.33, 0.83):
        sk.tube(p, [(POST, 0.0, z), (L / 2 - 0.012, 0.0, z), (L / 2 - 0.012, 0.0, z - 0.09)], 0.009, STEEL, 4)
        p.box((POST - 0.004, -0.012, z - 0.022), (POST + 0.03, 0.012, z + 0.014), STEEL)
        p.box((POST + 0.006, -0.016, z - 0.03), (POST + 0.02, 0.016, z + 0.02), FOOT_STEEL)
        sk.tube(p, [(-POST, 0.0, z + 0.03), (-L / 2 + 0.012, 0.0, z + 0.03), (-L / 2 + 0.012, 0.0, z - 0.04),
                    (-POST, 0.0, z - 0.04)], 0.008, STEEL, 4)
    # the bridge feet across the barrier (photo 2): flat steel bars running the block's whole depth, down flat on
    # the floor at their ends and bridged up in the middle, each with its socket round the upright, a rubber pad
    # under each end
    arch = [(-D / 2 + 0.02, 0.012), (-0.2, 0.012), (-0.11, 0.105), (0.11, 0.105), (0.2, 0.012), (D / 2 - 0.02, 0.012)]
    for x in (-POST, POST):
        sk.tube(p, [(x, y, z) for y, z in arch], 0.016, FOOT_STEEL, 4)
        p.lathe([(0.09, 0.03), (FOOT + 0.08, 0.03), (FOOT + 0.08, 0.026)], FOOT_STEEL, 8, (x, 0.0, 0.0), "z")
        p.lathe([(FOOT + 0.05, 0.034), (FOOT + 0.07, 0.034)], FOOT_STEEL, 8, (x, 0.0, 0.0), "z", cap=False)
        for y in (-D / 2 + 0.06, D / 2 - 0.06):
            p.box((x - 0.035, y - 0.06, 0.0), (x + 0.035, y + 0.06, 0.006), PAD)
    # the cover sheet over the bars: hemmed all round, a dark printed band (no words), eyelets with cable ties round
    # the frame at its corners and the middles of its long edges
    sz0, sz1 = RAIL + 0.03, H - 0.14
    x0, x1 = -POST + 0.05, POST - 0.05
    p.box((x0, -0.014, sz0), (x1, -0.01, sz1), SHEET)
    for a, b, c, d in ((x0, x1, sz0, sz0 + 0.03), (x0, x1, sz1 - 0.03, sz1), (x0, x0 + 0.03, sz0 + 0.03, sz1 - 0.03),
                       (x1 - 0.03, x1, sz0 + 0.03, sz1 - 0.03)):
        p.box((a, -0.0156, c), (b, -0.0084, d), HEM)
    for z0, z1 in ((sz1 - 0.2, sz1 - 0.12), (sz0 + 0.1, sz0 + 0.14)):
        sk.rect(p, "-y", -0.0148, -POST + 0.12, POST - 0.12, z0, z1, PRINT)
        sk.rect(p, "+y", -0.0092, -POST + 0.12, POST - 0.12, z0, z1, PRINT)
    ties = [(x, z) for x in (x0 + 0.015, x1 - 0.015) for z in (sz0 + 0.015, sz1 - 0.015)]
    ties += [(0.0, sz0 + 0.015), (0.0, sz1 - 0.015)]
    for x, z in ties:
        sk.disc(p, "-y", -0.0164, x, z, 0.008, EYELET, 6)
        sk.disc(p, "-y", -0.0172, x, z, 0.0045, sk.SLOT, 6)
        sk.disc(p, "+y", -0.0076, -x, z, 0.008, EYELET, 6)
        # the tie: out through the eyelet and round the frame (the uprights at the ends, the rails top and bottom)
        if x == 0.0:
            tz = RAIL if z < 0.5 else H - R
            ends = [(x, -0.018, z), (x, -0.022, tz), (x, 0.012, tz)]
        else:
            tx = -POST if x < 0 else POST
            ends = [(x, -0.018, z), (tx, -0.022, z), (tx, 0.014, z)]
        sk.tube(p, ends, 0.0035, TIE, 4)
    return p


if __name__ == "__main__":
    build().export("crowd_barrier.glb", budget=1200)
