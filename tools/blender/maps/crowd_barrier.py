"""The crowd-control barrier (Subway #26, SM3): a portable steel barrier, after the owner's photos
(art/references/maps/subway/26-crowd-barrier/): a galvanised tube frame with round top corners and a bottom rail
(photos 1, 2 and 4), close upright bars between them, the linking hooks on one end and their eyes on the other
(photos 1, 2 and 4), standing on two arched bridge feet across it (photo 2). A plain cover sheet is tied over its
bars, as barriers put out round closed areas carry: the block stops BBs, so the barrier reads as the solid cover it
is rather than a fence a player would see and shoot through (a readability default; bare bars are a one-line change).

Fills a barrier block (2.0 x 1.1 x 0.6 m; the feet reach across its depth). Budget 600 triangles.

Usage: python3 tools/blender/maps/crowd_barrier.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402
import hallkit as sk  # noqa: E402

L, H, D = 2.0, 1.1, 0.6
STEEL = "concrete*0.72"
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
    for i in range(6):
        a = math.pi - (math.pi / 2) * i / 5
        pts.append((-POST + r + r * math.cos(a), top - r + r * math.sin(a)))
    for i in range(6):
        a = math.pi / 2 - (math.pi / 2) * i / 5
        pts.append((POST - r + r * math.cos(a), top - r + r * math.sin(a)))
    pts.append((POST, FOOT))
    return [(x, 0.0, z) for x, z in pts]


def build() -> prop.Prop:
    p = prop.Prop("crowd_barrier")
    sk.tube(p, frame_path(), R, STEEL, 6)
    sk.tube(p, [(-POST, 0.0, RAIL), (POST, 0.0, RAIL)], 0.016, STEEL, 6)
    for i in range(BARS):
        x = -POST + (i + 1) * 2 * POST / (BARS + 1)
        sk.tube(p, [(x, 0.0, RAIL), (x, 0.0, H - 2 * R)], 0.008, STEEL, 4, caps=False)
    # the hooks at +X (two flat plates bent down, welded to the upright) and the eyes at -X they drop into
    for z in (0.33, 0.83):
        sk.tube(p, [(POST, 0.0, z), (L / 2 - 0.012, 0.0, z), (L / 2 - 0.012, 0.0, z - 0.09)], 0.009, STEEL, 4)
        p.box((POST - 0.004, -0.012, z - 0.022), (POST + 0.03, 0.012, z + 0.014), STEEL)
        sk.tube(p, [(-POST, 0.0, z + 0.03), (-L / 2 + 0.012, 0.0, z + 0.03), (-L / 2 + 0.012, 0.0, z - 0.04),
                    (-POST, 0.0, z - 0.04)], 0.008, STEEL, 4)
    # the bridge feet across the barrier (photo 2): flat steel bars running the block's whole depth, down flat on
    # the floor at their ends and bridged up in the middle, each with its socket round the upright
    arch = [(-D / 2 + 0.02, 0.012), (-0.2, 0.012), (-0.11, 0.105), (0.11, 0.105), (0.2, 0.012), (D / 2 - 0.02, 0.012)]
    for x in (-POST, POST):
        sk.tube(p, [(x, y, z) for y, z in arch], 0.016, "concrete*0.62", 4)
        p.box((x - 0.028, -0.03, 0.09), (x + 0.028, 0.03, FOOT + 0.08), "concrete*0.62")
        for y in (-D / 2 + 0.06, D / 2 - 0.06):
            p.box((x - 0.035, y - 0.06, 0.0), (x + 0.035, y + 0.06, 0.006), "slab*0.4")
    # the cover sheet over the bars, tied at its corners, two dark printed bands on it (no words)
    sz0, sz1 = RAIL + 0.03, H - 0.14
    p.box((-POST + 0.05, -0.014, sz0), (POST - 0.05, -0.01, sz1), "plaster*0.9")
    for z0, z1 in ((sz1 - 0.2, sz1 - 0.12), (sz0 + 0.1, sz0 + 0.14)):
        sk.rect(p, "-y", -0.0148, -POST + 0.12, POST - 0.12, z0, z1, "steel*0.6")
        sk.rect(p, "+y", -0.0092, -POST + 0.12, POST - 0.12, z0, z1, "steel*0.6")
    for x in (-POST + 0.06, POST - 0.06):
        for z in (sz0 + 0.02, sz1 - 0.02):
            sk.rect(p, "-y", -0.0148, x - 0.012, x + 0.012, z - 0.03, z + 0.03, sk.BLACK)
            sk.rect(p, "+y", -0.0092, -x - 0.012, -x + 0.012, z - 0.03, z + 0.03, sk.BLACK)
    return p


if __name__ == "__main__":
    build().export("crowd_barrier.glb", budget=600)
