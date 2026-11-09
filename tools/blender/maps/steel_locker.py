"""The steel lockers (RK1, Depot #10): three double-door steel lockers on each face, back to back, after the owner's
photos (art/references/maps/william-2026-11-09/steel_locker/): tall narrow doors (photo 3), each with pressed louvres
high and low (photos 1, 3 and 5), three pressed rails across it (under the top louvres, a full-width latch rail at
mid-height with the lift latch on it, over the bottom louvres), a card holder (photos 3 and 5), the doors a pale grey
on a dark carcass (photos 1 and 2), on short splayed legs (photos 3, 5 and 6) with a plinth set back between them, so
nothing is seen under the lockers that their box would stop.

Fills Depot's wardrobe block (2.0 x 2.2 x 1.0 m; doors on both faces, so either way it stands it reads; PropLayout
FIT). Budget 2,000 triangles.

Usage: python3 tools/blender/maps/steel_locker.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402

W, H, D = 2.0, 2.2, 1.0
HW, HD = W / 2, D / 2
LEG_H = 0.13
DOOR_T = 0.014
# The doors' faces stand this far inside the box, so the latches stay in it.
PROUD = 0.036
CARCASS = "steel*0.82"
DOOR = "grey*1.08"
SLOT = "slab*0.3"
LOUVRE = "grey*1.2"
RAIL = "grey*1.0"
LATCH = "steel*0.7"
UNITS = 3


def door(p: prop.Prop, x0: float, x1: float, face: float, k: int) -> None:
    """One door on the face at y = face (towards -Y: the front; +Y: the back), x0..x1, its details out from it."""
    s = -1.0 if face < 0 else 1.0
    z0, z1 = LEG_H + 0.03, H - 0.04
    y_in, y_out = sorted((face, face + s * DOOR_T))
    p.box((x0, y_in, z0), (x1, y_out, z1), DOOR)
    yd = (y_out if s > 0 else y_in) + s * 0.001
    w = x1 - x0

    def decal(u0: float, u1: float, v0: float, v1: float, paint: str, lift: float = 0.0) -> None:
        y = yd + s * lift
        if s < 0:
            p.front_decal(u0, u1, v0, v1, y, paint)
        else:
            p.quad([(u1, y, v0), (u0, y, v0), (u0, y, v1), (u1, y, v1)], paint)

    # pressed louvres: one dark slot behind three hoods standing proud across it
    u0, u1 = x0 + w * 0.25, x1 - w * 0.25
    zm = (z0 + z1) / 2
    for zb in (z1 - 0.26, z0 + 0.1):
        decal(u0, u1, zb, zb + 0.13, SLOT)
        for i in range(3):
            zz = zb + 0.012 + i * 0.042
            hood = [(0.0, zz), (s * 0.01, zz), (0.0, zz + 0.03)]
            p.prism([(yd + a, b) for a, b in hood], "x", u0, u1, LOUVRE)
    # three pressed rails across the door: under the top louvres, the latch rail at mid-height, over the bottom ones
    ya, yb = sorted((yd - s * 0.001, yd + s * 0.008))
    for zr, hr in ((z1 - 0.36, 0.035), (zm - 0.03, 0.06), (z0 + 0.33, 0.035)):
        p.box((x0 + 0.012, ya, zr), (x1 - 0.012, yb, zr + hr), RAIL)
    # the card holder under the top rail
    decal(x0 + w * 0.3, x1 - w * 0.3, z1 - 0.47, z1 - 0.41, "plaster", 0.001)
    # the lift latch on the middle rail, standing out from it
    hx = x1 - 0.06 if k % 2 == 0 else x0 + 0.06
    y_c, y_d = sorted((yd + s * 0.008, yd + s * 0.034))
    p.box((hx - 0.013, y_c, zm - 0.06), (hx + 0.013, y_d, zm + 0.02), LATCH)
    # two hinges down the edge away from the latch
    ex = x0 if k % 2 == 0 else x1
    for zz in (z0 + 0.18, z1 - 0.18):
        h0, h1 = sorted((yd - s * DOOR_T * 0.5, yd + s * 0.008))
        p.box((ex - 0.008, h0, zz - 0.04), (ex + 0.008, h1, zz + 0.04), LATCH)


def build() -> prop.Prop:
    p = prop.Prop("steel_locker")
    soft = p.piece(0.004, 1)
    # the carcass, a cap on top, a plinth set back between the legs
    soft.box((-HW, -HD + PROUD + DOOR_T, LEG_H), (HW, HD - PROUD - DOOR_T, H - 0.012), CARCASS)
    soft.box((-HW, -HD + PROUD + DOOR_T, H - 0.012), (HW, HD - PROUD - DOOR_T, H), CARCASS)
    p.box((-HW + 0.08, -HD + PROUD + 0.1, 0.0), (HW - 0.08, HD - PROUD - 0.1, LEG_H), "slab*0.3")
    # splayed legs at the corners, straight ones between the lockers
    for x in [-HW] + [-HW + W * i / UNITS for i in range(1, UNITS)] + [HW]:
        for y in (-HD + PROUD + DOOR_T, HD - PROUD - DOOR_T):
            y0, y1 = sorted((y, y - 0.05 if y > 0 else y + 0.05))
            if abs(x) < HW - 1e-6:
                p.box((x - 0.03, y0, 0.0), (x + 0.03, y1, LEG_H), CARCASS)
                continue
            sx = 1.0 if x < 0 else -1.0
            leg = [(0.0, 0.0), (0.05, 0.0), (0.05, LEG_H), (0.012, LEG_H)]
            p.prism([(x + sx * u, z) for u, z in leg], "y", y0, y1, CARCASS)
    k = 0
    for face in (-HD + PROUD + DOOR_T, HD - PROUD - DOOR_T):
        for u in range(UNITS):
            ux0, ux1 = -HW + W * u / UNITS + 0.012, -HW + W * (u + 1) / UNITS - 0.012
            mid = (ux0 + ux1) / 2
            for dx0, dx1 in ((ux0, mid - 0.004), (mid + 0.004, ux1)):
                door(p, dx0, dx1, face, k)
                k += 1
    return p


if __name__ == "__main__":
    build().export("steel_locker.glb", budget=2000)
