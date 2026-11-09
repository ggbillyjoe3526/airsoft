"""The office desk (RK1, Depot #9): a panel-end office desk after the owner's photos
(art/references/maps/william-2026-11-09/office_desk/): a pale beech top with its dark edging and two cable grommets
(photos 1, 4 and 5), panel ends on levelling feet (photos 4 and 5), a fixed three-drawer pedestal with bar handles and
a lock (photo 3), and a modesty panel along the back, a darker kick panel under it to the floor, so nothing is seen through the desk that its box
would stop. A waste bin and a computer tower stand in the legroom, under the top (nothing sits on a box).

Fills Depot's desk blocks (2.2 x 0.8 x 1.0 m), the drawers' side to the field (PropLayout FIT). Budget 2,000
triangles.

Usage: python3 tools/blender/maps/office_desk.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402

W, H, D = 2.2, 0.8, 1.0
HW, HD = W / 2, D / 2
TOP_T = 0.025
PANEL_T = 0.025
FOOT = 0.012
WOOD = "crate*1.12"
WOOD_SIDE = "crate*1.02"
EDGE = "timber*0.95"
METAL = "steel*1.1"
HANDLE = "steel*0.75"


def build() -> prop.Prop:
    p = prop.Prop("office_desk")
    top = p.piece(0.008, 3)
    soft = p.piece(0.005, 2)
    z_top = H - TOP_T
    # the top, its edging a band round it
    top.box((-HW, -HD, z_top), (HW, HD, H), WOOD)
    p.front_decal(-HW + 0.006, HW - 0.006, z_top + 0.004, H - 0.004, -HD - 0.0005, EDGE)
    # two cable grommets, a ring and its dark cap
    for gx in (-HW + 0.18, HW - 0.18):
        faces = p.lathe([(H - 0.0005, 0.04), (H + 0.0, 0.03)], METAL, 16, (gx, HD - 0.12, 0.0), axis="z", cap=True)
        p.faces_paint(faces[-1:], "rubber")
    # panel ends on levelling feet
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * (HW - 0.02), sx * (HW - 0.02 - PANEL_T)))
        soft.box((x0, -HD + 0.03, FOOT), (x1, HD - 0.03, z_top), WOOD_SIDE)
        for y in (-HD + 0.07, HD - 0.07):
            p.lathe([(0.0, 0.016), (FOOT, 0.016)], "rubber", 8, ((x0 + x1) / 2, y, 0.0), axis="z", cap=True)
    # the modesty panel down to the floor along the back
    inner0, inner1 = -HW + 0.02 + PANEL_T, HW - 0.02 - PANEL_T
    soft.box((inner0, HD - 0.12, 0.3), (inner1, HD - 0.1, z_top), WOOD_SIDE)
    # under a reveal, a darker kick panel set back a little to the floor (photo 5's panel reads as a panel)
    soft.box((inner0, HD - 0.135, 0.02), (inner1, HD - 0.115, 0.29), "timber*0.85")
    # the pedestal: a carcass and three drawers with bar handles, a lock in the top one
    px0, px1 = HW - 0.02 - PANEL_T - 0.43, inner1
    pz0 = 0.03
    soft.box((px0, -HD + 0.06, pz0), (px1, HD - 0.12, z_top - 0.005), WOOD_SIDE)
    gap = 0.006
    dh = (z_top - 0.03 - pz0 - 2 * gap) / 3
    for i in range(3):
        z0 = pz0 + 0.02 + i * (dh + gap)
        z1 = z0 + dh
        soft.box((px0 + 0.006, -HD + 0.045, z0), (px1 - 0.006, -HD + 0.06, z1), WOOD)
        hz = z1 - 0.05
        p.box((px0 + 0.1, -HD + 0.025, hz - 0.012), (px1 - 0.1, -HD + 0.045, hz + 0.012), HANDLE)
        for hx in (px0 + 0.1, px1 - 0.1):
            p.box((hx - 0.008, -HD + 0.03, hz - 0.01), (hx + 0.008, -HD + 0.045, hz + 0.01), HANDLE)
        if i == 2:
            p.lathe([(-HD + 0.044, 0.011), (-HD + 0.038, 0.011)], METAL, 10, (px1 - 0.06, 0.0, z1 - 0.045),
                    axis="y", cap=True)
    # in the legroom: a waste bin and a computer tower
    p.lathe([(0.0, 0.13), (0.005, 0.135), (0.3, 0.16), (0.31, 0.165), (0.31, 0.155), (0.03, 0.125)], "grey*0.9", 16,
            (-HW + 0.3, -0.05, 0.0), axis="z", cap=True)
    tx0, tx1 = px0 - 0.24, px0 - 0.05
    soft.box((tx0, -0.2, 0.0), (tx1, 0.3, 0.44), "rubber*1.1")
    p.front_decal(tx0 + 0.03, tx1 - 0.03, 0.3, 0.32, -0.2 - 0.001, "grey*0.9")
    p.lathe([(-0.2 - 0.003, 0.012), (-0.2, 0.012)], "teal*1.2", 10, ((tx0 + tx1) / 2, 0.0, 0.38), axis="y", cap=True)
    for k in range(4):
        z = 0.06 + k * 0.035
        p.front_decal(tx0 + 0.04, tx1 - 0.04, z, z + 0.012, -0.2 - 0.001, "rubber*0.6")
    return p


if __name__ == "__main__":
    build().export("office_desk.glb", budget=2000)
