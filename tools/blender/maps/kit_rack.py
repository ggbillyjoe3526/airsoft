"""The Range's kit rack (RK1, Range #8): one bay of Depot's pallet racking (navy uprights, the look's yellow beams,
plywood decks) fitted out as the firing point's replica rack after the owner's photos
(art/references/maps/william-2026-11-09/kit_rack/): a slotted green hanging board across the back with its hooks
(photo 4), two rifle stands on the top deck, tall black end plates with two staggered columns of round holes on three
alloy tubes, U-saddle cradles and knobs (photos 1 and 3), two pistol racks with slanted dividers and hand holes on the middle deck (photos 5
and 6), upright rifle racks on the floor (photo 2), and the kit round them: BB bottles and BB cans on the middle deck, a
stack of hard cases on the floor. The stands are empty: replicas are carried, not racked.

Fills the Range's rack block (2.6 x 2.4 x 0.6 m), its front to the firing line (PropLayout FIT). Both faces show, so
the bay has its rear uprights and beams. Budget 2,500 triangles.

Usage: python3 tools/blender/maps/kit_rack.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402

W, H, D = 2.6, 2.4, 0.6
HW, HD = W / 2, D / 2
COL = 0.08
DECKS = (0.8, 1.6)
BEAM_H = 0.1
UPRIGHT = "ink*1.15"
SLOTS = "ink*0.55"
BEAM = "yellow"
DECK = "plywood*0.95"
BLACK = "rubber*0.85"
ALLOY = "concrete*1.05"
BOARD = "green*0.8"


def frame(p: prop.Prop) -> None:
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * HW, sx * (HW - COL)))
        for sy in (-1.0, 1.0):
            y0, y1 = sorted((sy * HD, sy * (HD - 0.07)))
            p.box((x0, y0, 0.0), (x1, y1, H), UPRIGHT)
            yf = y0 - 0.001 if sy < 0 else y1 + 0.001
            if sy < 0:
                p.front_decal(x0 + 0.025, x1 - 0.025, 0.1, H - 0.05, yf, SLOTS)
            p.box((x0, y0, 0.0), (x1, y1, 0.012), "steel")
        # the side frame's bracing between the front and back uprights
        bx0, bx1 = (x0 + 0.03, x1 - 0.03)
        for z in (0.12, H - 0.12):
            p.box((bx0, -HD + 0.07, z - 0.02), (bx1, HD - 0.07, z + 0.02), "grey*1.2")
        for z0, z1, flip in ((0.14, 1.2, 1.0), (1.2, H - 0.14, -1.0)):
            dy = D - 0.14
            L = math.hypot(z1 - z0, dy)
            faces = p.box((bx0, -0.015, 0.0), (bx1, 0.015, L), "grey*1.2")
            ang = math.atan2(dy, z1 - z0) * flip
            y_start = -HD + 0.07 if flip > 0 else HD - 0.07
            p.transform(faces, prop.Matrix.Translation((0.0, y_start, z0)) @ prop.Matrix.Rotation(-ang, 4, "X"))
    for z in DECKS:
        for sy in (-1.0, 1.0):
            y0, y1 = sorted((sy * HD, sy * (HD - 0.05)))
            p.box((-HW + COL, y0, z - BEAM_H), (HW - COL, y1, z), BEAM)
            for sx in (-1.0, 1.0):
                cx0, cx1 = sorted((sx * (HW - COL), sx * (HW - COL - 0.05)))
                p.box((cx0, y0 - 0.004 * -sy, z - BEAM_H - 0.04), (cx1, y1 + 0.004 * sy, z + 0.02), BEAM + "*0.88")
        p.box((-HW + COL, -HD + 0.05, z - 0.02), (HW - COL, HD - 0.05, z), DECK)


def hanging_board(p: prop.Prop) -> None:
    """Photo 4's slotted board across the back between the decks, a neat row of hooks out of its slots."""
    y0, y1 = HD - 0.07, HD - 0.05
    z0, z1 = DECKS[0] + 0.04, DECKS[1] - BEAM_H - 0.03
    p.box((-HW + COL, y0, z0), (HW - COL, y1, z1), BOARD)
    n = 10
    zh = z1 - 0.16
    for i in range(n):
        x = -HW + COL + (i + 0.5) * (W - 2 * COL) / n
        p.front_decal(x - 0.014, x + 0.014, z0 + 0.06, z1 - 0.06, y0 - 0.001, "green*0.3")
        # a hook out of the slot: an arm forwards, its tip turned up
        hook = [(y0, zh), (y0 - 0.12, zh), (y0 - 0.12, zh + 0.05), (y0 - 0.104, zh + 0.05), (y0 - 0.104, zh + 0.016),
                (y0, zh + 0.016)]
        p.prism(hook, "x", x - 0.009, x + 0.009, ALLOY)


def octagon(xf: float, yc: float, zc: float, r: float, outward: bool, n: int = 8) -> list:
    """A round hole's outline on a plate's face at x = xf (n-sided), wound to face +x when `outward`, else -x."""
    pts = [(xf, yc + r * math.cos(2 * math.pi * i / n + math.pi / n), zc + r * math.sin(2 * math.pi * i / n + math.pi / n))
           for i in range(n)]
    return pts if outward else list(reversed(pts))


def rifle_rack(p: prop.Prop, cx: float, z: float, length: float, height: float, cradles: int) -> None:
    """Photos 1 and 3: two tall narrow black end plates, tapering up, with two staggered columns of large round holes,
    joined by a bright alloy tube at the top and two at the foot (front and back), a knob on each tube's end outside
    the plates, and U-saddle cradles along the top tube reaching forwards."""
    foot, top, th = 0.14, 0.1, 0.035
    zt = z + height - 0.05
    tubes = ((0.0, zt), (-foot * 0.3, z + 0.05), (foot * 0.3, z + 0.05))
    for s in (-1.0, 1.0):
        x0, x1 = sorted((cx + s * length / 2, cx + s * (length / 2 - th)))
        plate = [(-foot / 2, z), (foot / 2, z), (top / 2, z + height), (-top / 2, z + height)]
        p.prism(plate, "x", x0, x1, BLACK)
        xf = x1 + 0.001 if s > 0 else x0 - 0.001
        for k in range(7):
            zz = z + 0.12 + k * (height - 0.24) / 6.0
            p.quad(octagon(xf, -0.022 if k % 2 else 0.022, zz, 0.021, s > 0, 6), "grey*0.75")
        for ty, tz in tubes[:2]:
            k0, k1 = (x1, x1 + 0.025) if s > 0 else (x0 - 0.025, x0)
            p.lathe([(k0, 0.02), (k1, 0.02)], BLACK, 6, (0.0, ty, tz), axis="x", cap=True)
    for ty, tz in tubes:
        p.lathe([(cx - length / 2 + th, 0.014), (cx + length / 2 - th, 0.014)], ALLOY, 8, (0.0, ty, tz), axis="x",
                cap=False)
    # the cradles: an arm forwards from the top tube ending in a U-saddle, its front lip the taller
    saddle = [(0.02, zt - 0.02), (-0.13, zt - 0.02), (-0.13, zt + 0.05), (-0.112, zt + 0.05), (-0.112, zt + 0.012),
              (-0.066, zt + 0.012), (-0.066, zt + 0.035), (-0.048, zt + 0.035), (-0.048, zt + 0.012),
              (0.02, zt + 0.012)]
    for i in range(cradles):
        x = cx - length / 2 + (i + 1) * length / (cradles + 1)
        p.prism(saddle, "x", x - 0.022, x + 0.022, BLACK)


def pistol_rack(p: prop.Prop, cx: float, z: float) -> None:
    """Photos 5 and 6: a base, side cheeks rising to the back with a hand slot, three dividers leaning back."""
    w, d, h = 0.25, 0.24, 0.18
    p.box((cx - w / 2, -d / 2, z), (cx + w / 2, d / 2, z + 0.03), BLACK)
    cheek = [(-d / 2, z), (d / 2, z), (d / 2, z + h), (d / 2 - 0.04, z + h), (-d / 2 + 0.02, z + 0.07),
             (-d / 2, z + 0.07)]
    for s in (-1.0, 1.0):
        x0, x1 = sorted((cx + s * w / 2, cx + s * (w / 2 - 0.012)))
        p.prism(cheek, "x", x0, x1, BLACK)
        xf = x1 + 0.001 if s > 0 else x0 - 0.001
        slot = [(xf, 0.0, z + 0.1), (xf, 0.07, z + 0.1), (xf, 0.07, z + 0.125), (xf, 0.0, z + 0.125)]
        p.quad(slot if s > 0 else list(reversed(slot)), "slab*0.3")
    lean = [(-d / 2 + 0.02, z + 0.03), (-d / 2 + 0.07, z + 0.03), (d / 2 - 0.01, z + h), (d / 2 - 0.06, z + h)]
    for i in range(1, 4):
        x = cx - w / 2 + i * w / 4
        p.prism(lean, "x", x - 0.005, x + 0.005, BLACK)


def upright_rack(p: prop.Prop, cx: float, z: float) -> None:
    """Photo 2: an upright rack, two end plates on alloy bars, two hooks, standing on the floor."""
    length, height = 0.5, 0.62
    for s in (-1.0, 1.0):
        x0, x1 = sorted((cx + s * length / 2, cx + s * (length / 2 - 0.03)))
        plate = [(-0.09, z), (0.09, z), (0.06, z + height), (-0.06, z + height)]
        p.prism([(y, zz) for y, zz in plate], "x", x0, x1, BLACK)
        xf = x1 + 0.001 if s > 0 else x0 - 0.001
        for k in range(3):
            zz = z + 0.12 + k * 0.17
            ring = [(xf, -0.02, zz), (xf, 0.02, zz), (xf, 0.02, zz + 0.04), (xf, -0.02, zz + 0.04)]
            p.quad(ring if s > 0 else list(reversed(ring)), "slab*0.3")
    for zt in (z + 0.05, z + height - 0.06):
        p.lathe([(cx - length / 2 + 0.03, 0.014), (cx + length / 2 - 0.03, 0.014)], ALLOY, 8, (0.0, 0.0, zt),
                axis="x", cap=False)
    for xh in (cx - 0.1, cx + 0.1):
        hook = [(-0.02, z + height - 0.1), (0.07, z + height - 0.1), (0.07, z + height - 0.04),
                (-0.02, z + height - 0.06)]
        p.prism(hook, "x", xh - 0.018, xh + 0.018, BLACK)


def hard_case(p: prop.Prop, cx: float, z: float, length: float, width: float, th: float, paint: str) -> float:
    """A replica hard case lying flat: a soft-cornered shell, its lid's seam, the latches and handle on the front."""
    ch = 0.025
    x0, x1, y0, y1 = cx - length / 2, cx + length / 2, -width / 2, width / 2
    poly = [(x0 + ch, y0), (x1 - ch, y0), (x1, y0 + ch), (x1, y1 - ch), (x1 - ch, y1), (x0 + ch, y1), (x0, y1 - ch),
            (x0, y0 + ch)]
    p.prism(poly, "z", z, z + th, paint)
    p.front_decal(x0 + ch, x1 - ch, z + th * 0.45, z + th * 0.55, y0 - 0.001, paint + "*0.6")
    for xl in (x0 + 0.12, x1 - 0.12, cx - 0.08, cx + 0.08):
        if abs(xl - cx) < 0.1:
            continue
        p.box((xl - 0.025, y0 - 0.012, z + th * 0.3), (xl + 0.025, y0, z + th * 0.7), "grey*1.2")
    p.box((cx - 0.07, y0 - 0.03, z + th * 0.42), (cx + 0.07, y0, z + th * 0.58), "rubber*0.7")
    return z + th


def ammo_can(p: prop.Prop, cx: float, z: float) -> None:
    """A steel BB can: a box, its lid's lip and the folding handle on top."""
    w, d, h = 0.28, 0.15, 0.18
    p.box((cx - w / 2, -d / 2, z), (cx + w / 2, d / 2, z + h), "olive*0.85")
    p.box((cx - w / 2 - 0.006, -d / 2 - 0.006, z + h - 0.03), (cx + w / 2 + 0.006, d / 2 + 0.006, z + h), "olive*0.75")
    p.box((cx - 0.06, -0.012, z + h), (cx + 0.06, 0.012, z + h + 0.02), "rubber")


def bb_bottle(p: prop.Prop, cx: float, cy: float, z: float) -> None:
    """A bottle of BBs: a white tub, its screw cap."""
    faces = p.lathe([(z, 0.045), (z + 0.005, 0.05), (z + 0.15, 0.05), (z + 0.17, 0.035), (z + 0.2, 0.035)], "cream",
                    10, (cx, cy, 0.0), axis="z", cap=True)
    p.faces_paint(faces[-1:], "teal")
    p.lathe([(z + 0.17, 0.037), (z + 0.205, 0.037)], "teal", 10, (cx, cy, 0.0), axis="z", cap=True)


def build() -> prop.Prop:
    p = prop.Prop("kit_rack")
    frame(p)
    hanging_board(p)
    rifle_rack(p, -0.62, DECKS[1], 0.78, 0.66, 3)
    rifle_rack(p, 0.55, DECKS[1], 0.78, 0.66, 3)
    pistol_rack(p, -0.9, DECKS[0])
    pistol_rack(p, -0.58, DECKS[0])
    pistol_rack(p, -0.26, DECKS[0])
    for i, (bx, by) in enumerate(((0.12, -0.12), (0.26, -0.1), (0.19, 0.06), (0.36, 0.08))):
        bb_bottle(p, bx, by, DECKS[0])
    ammo_can(p, 0.75, DECKS[0])
    ammo_can(p, 0.78, DECKS[0] + 0.2)
    upright_rack(p, -0.85, 0.0)
    upright_rack(p, -0.25, 0.0)
    z = hard_case(p, 0.62, 0.0, 1.05, 0.36, 0.12, "rubber*1.1")
    z = hard_case(p, 0.6, z, 0.95, 0.34, 0.11, "olive*0.7")
    hard_case(p, 0.64, z, 0.8, 0.3, 0.1, "rubber*1.1")
    return p


if __name__ == "__main__":
    build().export("kit_rack.glb", budget=2500)
