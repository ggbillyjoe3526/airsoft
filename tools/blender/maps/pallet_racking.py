"""Pallet racking with stock (RK1, Depot #5): one 2.7 m bay of adjustable pallet racking after the owner's photos
(art/references/maps/william-2026-11-09/pallet_racking/): navy slotted uprights with their braced side frames and
foot plates, two levels of step beams (the photos' orange made the look's yellow, off the teams' orange), and stock on
pallets on the floor and both levels: sacks in two colours and kraft cartons below (photo 1), drums lying on their
sides and shrink-wrapped loads (photo 2), cartons and grey cement sacks (photos 1 and 2), mixed over three bays
(BAYS: pallet_racking.glb, _b and _c), some slots an empty pallet or bare.

PropLayout TILE lines a rack block's faces with this bay, as tall as the block (3 m), its front facing out, stretched
a little along the row and to the row's depth, over the block's dark backing drawn half a row in. So only the front
half shows: the bay has no rear uprights or beams, and the stock fills the depth. Each end's upright is half a column,
so neighbouring bays meet in one whole upright. Budget 1,500 triangles a bay.

Usage: python3 tools/blender/maps/pallet_racking.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402

W, H, D = 2.7, 3.0, 0.9
HW = W / 2
FRONT = -D / 2
COL_W = 0.05         # half a 100 mm upright
COL_D = 0.075
BEAM_H = 0.11
BEAM_D = 0.05
BEAM_TOPS = (1.06, 2.12)
PALLET_H = 0.14
UPRIGHT = "ink*1.15"
SLOTS = "grey*1.3"
SLOT_PITCH = 0.12
SLOT_N = 24
BEAM = "yellow"
FOOT = "steel*1.25"
BRACE = "ink*1.45"

DECK = ["crate*1.0", "crate*0.93", "plywood*0.95", "crate*0.97", "timber*1.1"]


def uprights(p: prop.Prop) -> None:
    for side in (-1.0, 1.0):
        x_out = side * HW
        x_in = side * (HW - COL_W)
        lo, hi = min(x_out, x_in), max(x_out, x_in)
        p.box((lo, FRONT, 0.0), (hi, FRONT + COL_D, H), UPRIGHT)
        # the slots punched up the column's face: one column of them on each bay's half, so where two bays meet the
        # whole upright shows its two columns (the photos' pairs), pale on the ink so they read down an aisle
        xc = side * (HW - COL_W * 0.45)
        for i in range(SLOT_N):
            zs = 0.16 + i * SLOT_PITCH
            p.front_decal(xc - 0.007, xc + 0.007, zs, zs + 0.05, FRONT - 0.001, SLOTS)
        # the foot plate, bolted down in front of the column
        p.box((lo, FRONT - 0.045, 0.0), (hi, FRONT + COL_D + 0.02, 0.016), FOOT)
        # the side frame's bracing towards the back, half of it in each bay
        bx = (-HW, -HW + 0.032) if side < 0 else (HW - 0.032, HW)
        for z in (0.14, H - 0.2):
            p.box((bx[0], FRONT + COL_D, z), (bx[1], 0.0, z + 0.05), BRACE)
        for z0, z1 in ((0.18, 1.0), (1.0, 1.9), (1.9, H - 0.24)):
            faces = p.box((bx[0], -0.022, 0.0), (bx[1], 0.022, math.hypot(z1 - z0, 0.0 - FRONT - COL_D) - 0.022),
                          BRACE)
            ang = math.atan2(-(FRONT + COL_D), z1 - z0)
            p.transform(faces, prop.Matrix.Translation((0.0, FRONT + COL_D + 0.02, z0)) @
                        prop.Matrix.Rotation(-ang, 4, "X"))


def beams(p: prop.Prop) -> None:
    x0, x1 = -HW + COL_W, HW - COL_W
    for top in BEAM_TOPS:
        p.box((x0, FRONT, top - BEAM_H), (x1, FRONT + BEAM_D, top), BEAM)
        # the step along the beam's top that the pallets sit in, and the end connectors on the columns
        p.box((x0, FRONT + BEAM_D, top - 0.035), (x1, FRONT + BEAM_D + 0.03, top - 0.004), BEAM + "*0.8")
        for s in (-1.0, 1.0):
            cx0, cx1 = (x0, x0 + 0.05) if s < 0 else (x1 - 0.05, x1)
            p.box((cx0, FRONT - 0.006, top - BEAM_H - 0.05), (cx1, FRONT + BEAM_D, top + 0.03), BEAM + "*0.88")
            # the safety lock, a red-free dark pin on the connector
            p.front_decal(cx0 + 0.016, cx1 - 0.016, top - 0.02, top + 0.012, FRONT - 0.007, "ink")


def pallet(p: prop.Prop, cx: float, z: float, w: float, shade: str, bare: bool = False) -> float:
    """A pallet in the rack, w wide, its deck's top returned. Only its front half shows. Under a load its deck is one
    board; a bare one shows its deck boards with the gaps between them (pallet.py's)."""
    y0, y1 = FRONT + 0.06, D / 2 - 0.02
    if bare:
        n = 6
        gap = 0.035
        bw = (y1 - y0 - gap * (n - 1)) / n
        for i in range(n):
            ya = y0 + i * (bw + gap)
            p.box((cx - w / 2, ya, z + PALLET_H - 0.025), (cx + w / 2, ya + bw, z + PALLET_H),
                  shade if i % 2 else shade + "*0.94" if "*" not in shade else shade.split("*")[0] + "*0.94")
    else:
        p.box((cx - w / 2, y0, z + PALLET_H - 0.025), (cx + w / 2, y1, z + PALLET_H), shade)
    for bx in (cx - w / 2 + 0.05, cx, cx + w / 2 - 0.05):
        p.box((bx - 0.05, y0, z), (bx + 0.05, y1, z + PALLET_H - 0.025), shade + "*0.88" if "*" not in shade else
              shade.split("*")[0] + "*0.85")
    return z + PALLET_H


def cartons(p: prop.Prop, cx: float, z: float, w: float, h: float, cols: int, rows: int, paints: list) -> None:
    """A stack of cartons, cols across and rows high, each with its tape seam on the front."""
    cw, ch = w / cols, h / rows
    y0, y1 = FRONT + 0.08, D / 2 - 0.03
    k = 0
    for r in range(rows):
        inset = 0.01 if r % 2 else 0.0
        for c in range(cols):
            x0 = cx - w / 2 + c * cw + 0.006 + inset
            x1 = x0 + cw - 0.012 - inset
            z0 = z + r * ch
            paint = paints[k % len(paints)]
            k += 1
            p.box((x0, y0 + inset, z0), (x1, y1, z0 + ch - 0.006), paint)
            mid = (x0 + x1) / 2
            p.front_decal(mid - 0.025, mid + 0.025, z0 + ch - 0.09, z0 + ch - 0.006, y0 + inset - 0.001, "sand*1.12")
            if (r + c) % 2 == 0:
                # a pale label low on alternate cartons
                p.front_decal(x0 + 0.04, x0 + 0.04 + cw * 0.3, z0 + 0.05, z0 + 0.05 + ch * 0.2,
                              y0 + inset - 0.001, "cream")


def sacks(p: prop.Prop, cx: float, z: float, w: float, layers: int, paints: list) -> float:
    """Sacks stacked flat, two across a layer, each a pillow (a chamfered slab); returns the stack's top."""
    th = 0.13
    y0, y1 = FRONT + 0.07, D / 2 - 0.04
    # the stack's core, a sack's colour a step darker, set back behind the seams so no gap shows the backing
    p.box((cx - w / 2 + 0.04, y0 + 0.05, z), (cx + w / 2 - 0.04, y1, z + layers * th - 0.01), paints[0] + "*0.75")
    for layer in range(layers):
        for c in range(2):
            sw = w / 2 - 0.02
            x0 = cx - w / 2 + c * (w / 2) + 0.01 + (0.025 if layer % 2 else 0.0) * (1 if c == 0 else -1)
            z0 = z + layer * th
            ch = 0.012
            poly = [(x0 + ch, z0), (x0 + sw - ch, z0), (x0 + sw, z0 + th / 2), (x0 + sw - ch, z0 + th),
                    (x0 + ch, z0 + th), (x0, z0 + th / 2)]
            p.prism(poly, "y", y0 + (0.015 if (layer + c) % 2 else 0.0), y1, paints[(layer + c) % len(paints)])
    return z + layers * th


def drums_lying(p: prop.Prop, cx: float, z: float, w: float, n: int, paint: str) -> None:
    """Drums on their sides, ends to the front (photo 2)."""
    r = min(w / n / 2 - 0.01, 0.29)
    seg = 24
    y0, y1 = FRONT + 0.07, D / 2 - 0.02
    for i in range(n):
        x = cx - w / 2 + (i + 0.5) * w / n
        zc = z + r
        L = y1 - y0
        prof = [(0.0, r * 0.93), (0.014, r), (L, r)]
        faces = p.lathe([(y0 + a, rr) for a, rr in prof], paint, seg, (x, 0.0, zc), axis="y", cap=True,
                        start=math.pi / seg)
        p.faces_paint(faces[-2:-1], paint + "*0.8")
        # the bung on the front end
        p.front_decal(x + r * 0.35, x + r * 0.55, zc - r * 0.62, zc - r * 0.42, y0 - 0.001, "grey*1.25")


def wrapped(p: prop.Prop, cx: float, z: float, w: float, h: float) -> None:
    """A shrink-wrapped load (photo 1's block pack): soft-cornered, a strap round it."""
    y0, y1 = FRONT + 0.07, D / 2 - 0.03
    ch = 0.05
    x0, x1 = cx - w / 2, cx + w / 2
    poly = [(x0 + ch, y0), (x1 - ch, y0), (x1, y0 + ch), (x1, y1), (x0, y1), (x0, y0 + ch)]
    p.prism(poly, "z", z, z + h, "cream*0.97")
    for sx in (x0 + w * 0.3, x1 - w * 0.3):
        p.front_decal(sx - 0.02, sx + 0.02, z, z + h, y0 - 0.001, "ink*1.3")
    p.front_decal(x0 + w * 0.35, x1 - w * 0.35, z + h * 0.55, z + h * 0.8, y0 - 0.001, "grey*1.3")


# The bays' loads (the owner, 2026-11-09: "a mix of pallet racking ... it looks too repetitive"): for each bay, from
# the floor up, each level's left and right slot. A slot holds a load on a pallet, an empty pallet ("pallet") or
# nothing ("none"). PropLayout picks a bay for each place along a rack (PropDressConfig.variants), never the same
# one twice in a row.
BAYS = {
    "pallet_racking.glb": [("sacks", "cartons"), ("drums", "wrapped"), ("cartons_tall", "grey_sacks")],
    "pallet_racking_b.glb": [("wrapped", "pallet"), ("cartons_tall", "none"), ("pallet", "kraft_wide")],
    "pallet_racking_c.glb": [("kraft_wide", "drums"), ("grey_sacks", "cartons"), ("sacks", "none")],
}


def load(p: prop.Prop, what: str, cx: float, level: int, slot: float, k: int) -> None:
    """Slot `what` at x `cx` on `level` (0 the floor), `slot` wide; `k` varies the pallet's shade."""
    if what == "none":
        return
    z = pallet(p, cx, 0.0 if level == 0 else BEAM_TOPS[level - 1], slot, DECK[k % len(DECK)], what == "pallet")
    if what == "sacks":
        sacks(p, cx, z, slot - 0.02, 5, ["teal", "yellow*0.95", "teal*0.92"])
    elif what == "grey_sacks":
        sacks(p, cx, z, slot - 0.02, 4, ["grey*1.15", "grey*1.25"])
    elif what == "cartons":
        cartons(p, cx, z, slot - 0.04, 0.72, 3, 2, ["crate*0.95", "crate*1.02", "sand*0.95"])
    elif what == "cartons_tall":
        cartons(p, cx, z, slot - 0.03, 0.66, 2, 2, ["crate*1.03", "crate*0.94"])
    elif what == "kraft_wide":
        cartons(p, cx, z, slot - 0.05, 0.5, 2, 1, ["sand*0.98", "crate*0.9"])
    elif what == "drums":
        drums_lying(p, cx, z, slot, 2, "crimson")
    elif what == "wrapped":
        wrapped(p, cx, z, slot - 0.03, 0.74)


def build(levels: list) -> prop.Prop:
    p = prop.Prop("pallet_racking")
    uprights(p)
    beams(p)
    inner = W - 2 * COL_W
    slot = inner / 2 - 0.06
    k = 0
    for level, pair in enumerate(levels):
        for cx, what in zip((-inner / 4, inner / 4), pair):
            load(p, what, cx, level, slot, k)
            k += 1
    return p


if __name__ == "__main__":
    for name, levels in BAYS.items():
        build(levels).export(name, budget=1500)
