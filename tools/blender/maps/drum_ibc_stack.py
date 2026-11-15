"""Pallet stacks of IBC totes and steel drums (DX1, Depot): one 2.7 m bay after the owner's 2026-11-15 photos
(art/references/depot-props/pallet_stacks/), standing in for some of Depot's racking bays (pallet_racking.py). No
racking: two IBCs at a real tote's size (1.2 x 1.0 x 1.16 m) stacked on their own black pallets on a yellow spill
bund (photos 1 to 3: white tanks in galvanised cages, each with its label plate, filler cap and bottom valve, the
liquid showing through; the bund's sump and fork slots) beside drums stacked two a pallet, three pallets high (photos
4 to 6; their blue is Alpha's hue, so the drums are steel violet, black and grey). Three bays (BAYS) take turns along a
row (PropDressConfig.variants), the tower and the drums swapped and their fills changed; the third two towers side by
side (photo 2).

Usage: python3 -I tools/blender/maps/drum_ibc_stack.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bay_kit as bk  # noqa: E402
import prop  # noqa: E402

GALV = "concrete*0.86"
IBC_H = 1.16             # a tote: its pallet, tank and cage (a 1,000 litre IBC is 1.2 x 1.0 x 1.16 m)
BUND_H = 0.52            # the spill bund under the stack (photo 3), so two totes on it come to 2.84 m
IBC_W = 1.2              # the long side faces out, as in photo 2's rows
Y0 = bk.FRONT + 0.03
DRUM_R = 0.285
DRUM_H = 0.855            # a 205 litre drum, 0.585 x 0.88 m, to the bay's 3 m in three pallets
DECK = ["crate*1.0", "timber*1.1", "crate*0.93"]


def ibc(p: prop.Prop, cx: float, z: float, tank: str, fill: float, seed: int, top_most: bool) -> None:
    """One IBC tote's front half on its black pallet: the tank `fill` full, its cage, label plate, cap (on the stack's
    top tote; the others' are under the pallet over them) and valve."""
    x0, x1 = cx - IBC_W / 2, cx + IBC_W / 2
    top = bk.plastic_pallet(p, cx, z, IBC_W, Y0, bk.BACK)
    tz0, tz1 = top + 0.01, z + IBC_H - 0.04
    # the tank, its corners rounded by chamfers, the liquid's level showing through its milky wall
    bk.chamfered(p, x0 + 0.03, x1 - 0.03, Y0 + 0.035, bk.BACK, tz0, tz1, 0.05, tank, tank + "*1.04", tank + "*0.95")
    level = tz0 + (tz1 - tz0) * fill
    p.front_decal(x0 + 0.08, x1 - 0.08, tz0 + 0.02, level, Y0 + 0.034, tank + "*0.86*0.86")
    p.front_decal(x0 + 0.08, x1 - 0.08, level, level + 0.014, Y0 + 0.033, tank + "*0.68")
    # the moulded label panel and its sticker (photo 3), the graduation down the left
    p.front_decal(cx - 0.21, cx + 0.21, tz1 - 0.36, tz1 - 0.08, Y0 + 0.032, tank + "*0.92")
    p.front_decal(cx - 0.17, cx + 0.12, tz1 - 0.33, tz1 - 0.12, Y0 + 0.031, "cream*1.04" if seed % 2 else "concrete*1.02")
    # the hazard diamond on the label (photo 5): a red-bordered white square on its point
    hx, hz, hr = cx + 0.06, tz1 - 0.22, 0.06
    p.quad([(hx, Y0 + 0.03, hz - hr), (hx + hr, Y0 + 0.03, hz), (hx, Y0 + 0.03, hz + hr), (hx - hr, Y0 + 0.03, hz)],
           "fire*0.95")
    p.quad([(hx, Y0 + 0.029, hz - hr * 0.78), (hx + hr * 0.78, Y0 + 0.029, hz), (hx, Y0 + 0.029, hz + hr * 0.78),
            (hx - hr * 0.78, Y0 + 0.029, hz)], "cream*1.04")
    for i in range(4):
        gz = tz0 + 0.12 + i * 0.15
        p.front_decal(x0 + 0.1, x0 + (0.16 if i % 2 else 0.13), gz, gz + 0.008, Y0 + 0.032, tank + "*0.7")
    # the filler cap on top, and the bottom valve with its lever (photo 3)
    if top_most:
        p.lathe([(tz1, 0.075), (tz1 + 0.03, 0.075), (tz1 + 0.03, 0.0)], "cream*0.9", 6, (cx, Y0 + 0.3, 0.0), axis="z")
    p.box((cx - 0.05, Y0 - 0.045, tz0 + 0.02), (cx + 0.05, Y0 + 0.05, tz0 + 0.1), "grey*1.15")
    p.box((cx + 0.015, Y0 - 0.05, tz0 + 0.085), (cx + 0.13, Y0 - 0.03, tz0 + 0.105), "ink*1.3")
    # the cage: its frame round the top, the corner posts, and the bars across the front and down the sides
    cz0, cz1 = top - 0.01, z + IBC_H - 0.004
    p.box((x0, Y0 - 0.006, cz1 - 0.03), (x1, Y0 + 0.024, cz1), GALV)
    for sx in (x0, x1 - 0.03):
        p.box((sx, Y0 - 0.006, cz0), (sx + 0.03, Y0 + 0.024, cz1), GALV)
    yb = Y0 - 0.004
    n = 7
    for i in range(1, n):
        x = x0 + IBC_W * i / n
        bk.wire(p, (x, yb, cz0), (x, yb, cz1 - 0.03), 0.009, GALV)
    for j in range(1, 4):
        zz = cz0 + (cz1 - cz0) * j / 4
        bk.wire(p, (x0 + 0.03, yb - 0.01, zz), (x1 - 0.03, yb - 0.01, zz), 0.009, GALV + "*0.95")
    # the sides' frame and bars stay inside the corner posts' outer faces (x0, x1), so nothing pokes past a post
    for sx, out in ((x0, -1.0), (x1, 1.0)):
        p.box((min(sx, sx - out * 0.03), Y0 + 0.024, cz1 - 0.03), (max(sx, sx - out * 0.03), 0.0, cz1), GALV)
        bar = sx - out * 0.01
        y = Y0 / 2
        bk.wire(p, (bar, y, cz0), (bar, y, cz1 - 0.03), 0.009, GALV, facing=(out, 0.0, 0.0))
        for j in (1, 3):
            zz = cz0 + (cz1 - cz0) * j / 4
            bk.wire(p, (bar, Y0 + 0.024, zz), (bar, 0.0, zz), 0.009, GALV + "*0.95", facing=(out, 0.0, 0.0))


def bund(p: prop.Prop, cx: float) -> float:
    """The yellow spill bund the totes stand on (photo 3): its sump with a rolled lip, the ribs down its front, the
    fork slots under it and its label; returns its top."""
    x0, x1 = cx - IBC_W / 2 - 0.05, cx + IBC_W / 2 + 0.05
    y0 = Y0 - 0.02
    feet = 0.12
    bk.chamfered(p, x0, x1, y0, bk.BACK, feet, BUND_H - 0.04, 0.04, "yellow*0.9", "yellow*0.95", "yellow*0.98")
    # the lip round its top, proud of the sump, and the grating the pallet stands on inside it
    p.box((x0 - 0.015, y0 - 0.015, BUND_H - 0.05), (x1 + 0.015, bk.BACK, BUND_H), "yellow*0.97")
    # the moulded ribs down its front, between the fork slots
    for i in range(5):
        x = x0 + 0.1 + (x1 - x0 - 0.2) * i / 4
        p.box((x - 0.04, y0 - 0.03, feet), (x + 0.04, y0, BUND_H - 0.06), "yellow*0.86")
    # the feet and the fork slots between them, in shadow
    for i in range(4):
        fx = x0 + 0.06 + (x1 - x0 - 0.2) * i / 3
        p.box((fx, y0 + 0.02, 0.0), (fx + 0.08, bk.BACK, feet), "yellow*0.8")
    p.front_decal(x0 + 0.04, x1 - 0.04, 0.0, feet, y0 + 0.03, "ink*0.9")
    # its maker's plate (no brand: a blank green band, as the photo's)
    p.front_decal(x1 - 0.42, x1 - 0.12, BUND_H - 0.2, BUND_H - 0.12, y0 - 0.031, "green*0.85")
    return BUND_H


def drums(p: prop.Prop, cx: float, z: float, paints: tuple, k: int, top_most: bool) -> float:
    """A pallet of two drums standing side by side, their bungs up (their lids drawn on the stack's top pallet only);
    returns the drums' tops."""
    deck = bk.euro_pallet(p, cx, z, IBC_W, DECK[k % len(DECK)], Y0 + 0.02)
    for i, paint in enumerate(paints):
        x = cx + (i - 0.5) * (2 * DRUM_R + 0.04)
        bk.half_drum(p, x, Y0 + 0.04 + DRUM_R, deck, DRUM_R, DRUM_H, paint, seg=6, open_top=top_most)
        # the drum's hazard diamond or product label, on alternate drums
        if (i + k) % 2 == 0:
            p.front_decal(x - 0.08, x + 0.08, deck + 0.42, deck + 0.58, Y0 + 0.035, "cream*1.02")
            p.front_decal(x - 0.06, x + 0.06, deck + 0.53, deck + 0.555, Y0 + 0.034, "ink*1.1")
    return deck + DRUM_H


def build(sides: tuple) -> prop.Prop:
    """The bay: its two stacks, left then right, each ("ibc", its totes' (tank, fill) from the bottom) or ("drums",
    its pallets' drum paints from the bottom)."""
    p = prop.Prop("drum_ibc_stack")
    # the yellow line painted on the floor along the stacks' front, the bay's whole width (photos 5 and 6)
    p.quad([(-bk.HW, bk.FRONT, 0.004), (bk.HW, bk.FRONT, 0.004), (bk.HW, bk.FRONT + 0.06, 0.004),
            (-bk.HW, bk.FRONT + 0.06, 0.004)], "yellow*0.92")
    xs = (-bk.HW + IBC_W / 2 + 0.07, bk.HW - IBC_W / 2 - 0.07)
    for side, (cx, (what, levels)) in enumerate(zip(xs, sides)):
        if what == "ibc":
            base = bund(p, cx)
            capped = what == "ibc" and all(s[0] == "ibc" for s in sides)
            for level, (tank, fill) in enumerate(levels):
                ibc(p, cx, base + level * IBC_H, tank, fill, level + 2 * side, level == len(levels) - 1 and not capped)
            if capped:
                # two towers side by side (the third bay) come to the bay's 3 m with a card slip sheet and an empty
                # pallet on each, as the photos' stacks are topped
                top = base + len(levels) * IBC_H
                p.box((cx - IBC_W / 2, Y0 + 0.02, top), (cx + IBC_W / 2, bk.BACK, bk.H - 0.144), "cream*0.88")
                bk.euro_pallet(p, cx, bk.H - 0.144, IBC_W, DECK[side % len(DECK)], Y0 + 0.02)
        else:
            z = 0.0
            for level, paints in enumerate(levels):
                z = drums(p, cx, z, paints, level, level == len(levels) - 1)
    return p


# Each bay's two stacks, left then right: an IBC tower's totes (tank paint, fill) from the bottom, or a drum stack's
# pallets of two drums (their paints) from the bottom.
BAYS = {
    "drum_ibc_stack.glb": (("ibc", [("cream*0.93", 0.82), ("cream*0.95", 0.45)]),
                           ("drums", [("violet*0.78", "violet*0.78"), ("violet*0.74", "violet*0.8"),
                                      ("grey*1.05", "violet*0.78")])),
    "drum_ibc_stack_b.glb": (("drums", [("rubber*1.25", "rubber*1.25"), ("grey*1.05", "grey*1.0"),
                                        ("olive*0.8", "violet*0.78")]),
                             ("ibc", [("cream*0.93", 0.66), ("rubber*1.15", 0.9)])),
    # photo 2's two towers side by side, one of them black, the totes filled to different levels
    "drum_ibc_stack_c.glb": (("ibc", [("cream*0.94", 0.3), ("cream*0.92", 0.9)]),
                             ("ibc", [("rubber*1.15", 0.7), ("cream*0.95", 0.55)])),
}

if __name__ == "__main__":
    for name, sides in BAYS.items():
        build(sides).export(name, budget=1500)
