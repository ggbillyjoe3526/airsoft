"""The ticket machines (Subway #20, SM3): a row of four along the ticket hall, after the owner's photos
(art/references/maps/subway/20-ticket-machine/), photo 3 above all: each machine a stainless cabinet with a dark
header (a light ticket sign, no words), a white instruction panel of three numbered steps, a light grey fascia with the
touch screen in its hooded bezel, the round yellow reader beside it, a card and note column on the right (keypad,
card slot, note slot: photos 1 to 3), the ticket and change cup under them, a lower door with its lock, a dark kick.
Pilasters between the machines (photo 3's coloured ones are dark grey here: no line colours). The station is shut:
one screen is dark with a paper sign taped over it, the rest dim.

Fills the ticket machines' block (5.5 x 2.0 x 0.6 m), its front to the hall; its back, seen from the street side,
the service panels with vents. Budget 2,500 triangles a machine, 10,000 the row.

Usage: python3 tools/blender/maps/ticket_machine.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402
import hallkit as sk  # noqa: E402

W, H, D = 5.5, 2.0, 0.6
HW, HD = W / 2, D / 2
UNITS = 4
PIL = 0.22                       # a pilaster between the machines: the machines tall and narrow, as photo 1's
MW = (W - (UNITS + 1) * PIL) / UNITS
FACE = -HD + 0.16                # the machines' faces: their hoods and keys stay inside the box
BODY = sk.STAINLESS
FASCIA = "cream*0.86"
HEADER = "steel*0.5"
PILASTER = "slab*0.5"
STEP_BAR = "steel*0.75"


def machine(p: prop.Prop, soft: prop.Prop, x0: float, k: int) -> None:
    x1 = x0 + MW
    cx = (x0 + x1) / 2
    f = FACE
    keys = p.piece(0.003, 1)
    # the carcass back to the wall, its lower door, the dark kick
    soft.box((x0, f, 0.1), (x1, HD - 0.02, H - 0.2), BODY)
    p.box((x0 + 0.02, f + 0.03, 0.0), (x1 - 0.02, HD - 0.04, 0.1), sk.SLOT)
    sk.rect(p, "-y", f - 0.0008, x0 + 0.05, x1 - 0.05, 0.86, 0.864, sk.SLOT)
    for u in (x0 + 0.05, x1 - 0.054):
        sk.rect(p, "-y", f - 0.0008, u, u + 0.004, 0.14, 0.864, sk.SLOT)
    sk.rect(p, "-y", f - 0.0008, x0 + 0.05, x1 - 0.05, 0.14, 0.144, sk.SLOT)
    sk.slab(keys, "-y", f, 0.014, x1 - 0.13, x1 - 0.1, 0.42, 0.56, "concrete*0.55")
    sk.disc(p, "-y", f - 0.0008, x1 - 0.115, 0.62, 0.014, "slab*0.5", 10)
    sk.louvre(p, "-y", f - 0.0008, cx - 0.3, cx + 0.3, 0.2, 0.3, BODY, 4)
    # the fascia module, proud of the carcass: screen bay, reader, the card and note column
    fz0, fz1 = 0.86, 1.56
    soft.box((x0 + 0.02, f - 0.05, fz0), (x1 - 0.02, f, fz1), FASCIA)
    ff = f - 0.05
    # the screen's hooded bezel, tilted back, left of middle
    sx0, sx1 = x0 + 0.06, x0 + 0.6
    hood = [(ff, 1.0), (ff - 0.1, 1.02), (ff - 0.1, 1.5), (ff, 1.52)]
    bezel = p.piece(0.006, 2)
    bezel.prism(hood, "x", sx0, sx1, "slab*0.45")
    screen = "ink*0.6" if k != 1 else "slab*0.2"
    for (a, b, c, d) in ((sx0 + 0.01, sx0 + 0.04, 1.05, 1.47), (sx1 - 0.04, sx1 - 0.01, 1.05, 1.47),
                         (sx0 + 0.01, sx1 - 0.01, 1.03, 1.06), (sx0 + 0.01, sx1 - 0.01, 1.46, 1.49)):
        sk.slab(keys, "-y", ff - 0.1, 0.012, a, b, c, d, "slab*0.38")
    sk.rect(p, "-y", ff - 0.1008, sx0 + 0.04, sx1 - 0.04, 1.06, 1.46, screen)
    if k != 1:  # a dim menu: six bars and a lighter header strip
        sk.rect(p, "-y", ff - 0.1016, sx0 + 0.06, sx1 - 0.06, 1.41, 1.44, "cream*0.75")
        for i in range(6):
            z = 1.36 - i * 0.05
            sk.rect(p, "-y", ff - 0.1016, sx0 + 0.07, sx0 + 0.07 + (0.22 if i % 2 else 0.3), z - 0.022, z,
                    "seafoam*0.6")
    else:  # out of order: a paper sign taped across the dark screen, a little skew
        a = math.radians(-4)
        cxs, czs, hw, hh = (sx0 + sx1) / 2, 1.27, 0.15, 0.1
        pts = [(cxs + u * math.cos(a) - v * math.sin(a), czs + u * math.sin(a) + v * math.cos(a))
               for u, v in ((-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh))]
        sk.poly(p, "-y", ff - 0.1016, pts, "plaster")
        for i, (u, v) in enumerate(((-0.08, 0.04), (-0.1, 0.0), (-0.06, -0.04))):
            sk.rect(p, "-y", ff - 0.1024, cxs + u, cxs - u * 0.6, czs + v - 0.012, czs + v + 0.012, "crimson*0.8")
        for u, v in ((-hw, hh), (hw, hh)):
            sk.rect(p, "-y", ff - 0.1024, cxs + u - 0.03, cxs + u + 0.03, czs + v - 0.015, czs + v + 0.015,
                    "cream*0.7")
    # soft keys down the screen's right side
    for i in range(2):
        z = 1.42 - i * 0.08
        sk.slab(keys, "-y", ff - 0.03, 0.012, sx1 + 0.01, sx1 + 0.045, z - 0.03, z, "slab*0.6")
    # the round reader between the screen and the column (photo 3), in a raised dark bezel
    rx, rz = sx1 + 0.1, 1.1
    keys.prism([(rx + 0.072 * c, rz + 0.072 * v) for c, v in sk.circle_pts(0.0, 0.0, 1.0, 20)], "y", ff - 0.02, ff,
               "slab*0.45")
    sk.disc(p, "-y", ff - 0.0208, rx, rz, 0.058, sk.READER, 20)
    sk.disc(p, "-y", ff - 0.0216, rx, rz, 0.042, "yellow*0.78", 20)
    sk.rect(p, "-y", ff - 0.0224, rx - 0.016, rx + 0.016, rz - 0.011, rz + 0.013, "yellow*0.55")
    # the card and note column at the right: keypad on a dark panel, card slot, note slot, coin slot
    kx0, kx1 = x1 - 0.3, x1 - 0.06
    soft.box((kx0, ff - 0.03, 0.96), (kx1, ff, 1.50), "slab*0.4")
    kf = ff - 0.03
    sk.rect(p, "-y", kf - 0.0008, kx0 + 0.04, kx1 - 0.04, 1.38, 1.46, "teal*0.45")
    for r in range(4):
        for c in range(3):
            u = kx0 + 0.06 + c * 0.05
            z = 1.33 - r * 0.045
            sk.slab(keys, "-y", kf, 0.01, u, u + 0.036, z - 0.032, z, "concrete*0.72" if r < 3 or c == 1 else
                    ("green*0.9" if c == 2 else "crimson*0.9"))
    sk.rect(p, "-y", kf - 0.0008, kx0 + 0.05, kx1 - 0.05, 1.135, 1.145, sk.SLOT)
    sk.slab(p, "-y", kf, 0.01, kx0 + 0.04, kx1 - 0.04, 1.12, 1.13, "slab*0.6")
    sk.rect(p, "-y", kf - 0.0008, kx0 + 0.04, kx1 - 0.04, 1.03, 1.045, sk.SLOT)
    sk.slab(p, "-y", kf, 0.014, kx0 + 0.03, kx1 - 0.03, 1.0, 1.03, "slab*0.6")
    sk.slab(keys, "-y", ff, 0.008, kx0 - 0.11, kx0 - 0.03, 1.2, 1.3, "concrete*0.65")
    sk.rect(p, "-y", ff - 0.0088, kx0 - 0.08, kx0 - 0.06, 1.22, 1.28, sk.SLOT)
    # a speaker grille over the keypad's left, a coin return button
    for r in range(3):
        for c in range(4):
            u, z = kx0 - 0.1 + c * 0.018, 1.42 - r * 0.018
            sk.rect(p, "-y", ff - 0.0008, u, u + 0.008, z, z + 0.008, sk.SLOT)
    sk.slab(keys, "-y", ff, 0.012, kx0 - 0.1, kx0 - 0.05, 0.92, 0.96, "crimson*0.7")
    # the ticket and change cup: a dark mouth under a stainless lip, across the fascia's foot
    p.box((x0 + 0.12, ff - 0.035, 0.88), (x1 - 0.4, ff, 0.89), "concrete*0.9")
    sk.rect(p, "-y", ff - 0.0008, x0 + 0.13, x1 - 0.41, 0.895, 0.97, sk.SLOT)
    p.box((x0 + 0.13, ff - 0.03, 0.89), (x1 - 0.41, ff - 0.0016, 0.9), "slab*0.35")
    p.box((x0 + 0.12, ff - 0.035, 0.97), (x1 - 0.4, ff, 0.98), "concrete*0.9")
    # the instruction panel: three numbered steps, each a dark disc and a bar of pictograms
    iz0, iz1 = 1.56, H - 0.2
    soft.box((x0 + 0.02, f - 0.02, iz0), (x1 - 0.02, f, iz1), "plaster*0.98")
    for i in range(3):
        z = iz1 - 0.05 - i * 0.065
        sk.disc(p, "-y", f - 0.0208, x0 + 0.08, z - 0.012, 0.018, "steel*0.6", 8)
        sk.rect(p, "-y", f - 0.0208, x0 + 0.12, x0 + 0.12 + (0.5, 0.36, 0.44)[i], z - 0.026, z, STEP_BAR)
        for j in range(3):
            u = x0 + 0.14 + j * 0.06
            sk.rect(p, "-y", f - 0.0216, u, u + 0.04, z - 0.022, z - 0.004, ("cream", "green*1.1", "plaster")[j])
    sk.lines(p, "-y", f - 0.0208, x1 - 0.42, x1 - 0.08, iz0 + 0.03, iz1 - 0.03, "steel*0.85", 6,
             (0.9, 0.7, 1.0, 0.55, 0.8))


def build() -> prop.Prop:
    p = prop.Prop("ticket_machine")
    soft = p.piece(0.008, 2)
    # the header across the row's top, proud to the box's front: dark, a ticket sign over each machine
    p.piece(0.01, 3).box((-HW, -HD + 0.002, H - 0.2), (HW, HD - 0.02, H), HEADER)
    for k in range(UNITS):
        x0 = -HW + PIL + k * (MW + PIL)
        machine(p, soft, x0, k)
        # the sign: a light ticket in a rounded square, then two light bars (no words)
        sk.rect(p, "-y", -HD - 0.0008, x0 + 0.05, x0 + 0.17, H - 0.17, H - 0.05, "plaster")
        sk.rect(p, "-y", -HD - 0.0016, x0 + 0.075, x0 + 0.145, H - 0.135, H - 0.085, HEADER)
        sk.rect(p, "-y", -HD - 0.0008, x0 + 0.21, x0 + 0.62, H - 0.1, H - 0.05, "plaster")
        sk.rect(p, "-y", -HD - 0.0008, x0 + 0.21, x0 + 0.52, H - 0.15, H - 0.12, "plaster*0.8")
        # a small green status lamp on the header's lip
        sk.slab(p, "-y", -HD + 0.006, 0.006, x0 + MW - 0.08, x0 + MW - 0.05, H - 0.17, H - 0.15, "green*1.2" if k != 1
                else "crimson")
    # the pilasters, full height to the box's front
    for i in range(UNITS + 1):
        x0 = -HW + i * (MW + PIL)
        p.piece(0.01, 3).box((x0, -HD + 0.002, 0.0), (x0 + PIL, HD - 0.02, H - 0.2), PILASTER)
    # the back: service panels, a seam between each machine, vents high and low, the row's base
    p.piece(0.006, 2).box((-HW + 0.002, HD - 0.03, 0.0), (HW - 0.002, HD - 0.012, H - 0.002), "concrete*0.6")
    for k in range(UNITS):
        x0 = -HW + PIL + k * (MW + PIL)
        u0, u1 = -(x0 + MW), -x0
        sk.louvre(p, "+y", HD - 0.0112, u0 + 0.2, u1 - 0.2, H - 0.5, H - 0.32, "concrete*0.6", 5)
        sk.louvre(p, "+y", HD - 0.0112, u0 + 0.2, u1 - 0.2, 0.14, 0.3, "concrete*0.6", 4)
        sk.rect(p, "+y", HD - 0.0112, u0 + 0.5, u1 - 0.5, 1.0, 1.06, "butter*0.9")
        sk.disc(p, "+y", HD - 0.0112, u1 - 0.1, 1.0, 0.014, "steel*1.1", 8)
    for i in range(UNITS + 1):
        u = -(-HW + i * (MW + PIL)) - PIL / 2
        sk.rect(p, "+y", HD - 0.0112, u - 0.003, u + 0.003, 0.0, H, sk.SLOT)
    return p


if __name__ == "__main__":
    build().export("ticket_machine.glb", budget=10000)
