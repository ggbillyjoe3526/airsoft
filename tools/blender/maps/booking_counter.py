"""The old booking counter (Subway #23, SM3): the waist-high counter in the lower booking hall, after the owner's
photos (art/references/maps/subway/23-booking-counter/): dark wood panelling in framed, raised and fielded panels, two
to a bay (photos 1 and 2), a skirting, a moulded cornice under a lighter polished top with a rounded nose, the
panelling carried round both ends. The photos' ticket windows stand over such panelling; the map's block is a 6 m
counter at waist height, so this is that panelling as a counter (the agreed default). On it: a wooden leaflet rack
(photo 1), a counter bell, a closed ledger and an old ticket dating press, left behind when the station shut.

Fills the counter's block (6.0 x 1.1 x 0.9 m), its front to the hall, its back to the wall. Budget 1,500 triangles.

Usage: python3 tools/blender/maps/booking_counter.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402
import hallkit as sk  # noqa: E402

W, H, D = 6.0, 1.1, 0.9
HW, HD = W / 2, D / 2
TOP = 1.04          # the polished top's surface; the things on it reach the box's top
NOSE = 0.045        # the top's overhang past the panelling
FACE = -HD + NOSE   # the panelling's face
SKIRT = 0.13
# Mahogany (photos 1 and 2): the fields a shade lighter than their frames, the top polished lighter still
FIELD = "walnut*0.62"
FRAME = "walnut*0.5"
TOP_WOOD = "walnut*0.82"
MOULD = "walnut*0.56"
BAYS = 8


def panels(p: prop.Prop, face: str, at: float, u0: float, u1: float, bays: int) -> None:
    """Framed raised panels on `face` over u0..u1: stiles between the bays, three rails, two fields a bay."""
    s = -1.0 if face in ("-y", "-x") else 1.0
    z0, z1 = SKIRT, TOP - 0.1
    mid = z0 + (z1 - z0) * 0.68
    st = 0.07
    rails = ((z0, z0 + 0.09), (mid - 0.04, mid + 0.04), (z1 - 0.08, z1))
    for a, b in rails:
        sk.slab(p, face, at, 0.016, u0, u1, a, b, FRAME)
    bw = (u1 - u0) / bays
    for i in range(bays + 1):
        u = u0 + i * bw
        for a, b in ((z0 + 0.09, mid - 0.04), (mid + 0.04, z1 - 0.08)):  # between the rails, never through them
            sk.slab(p, face, at, 0.016, max(u0, u - st / 2), min(u1, u + st / 2), a, b, FRAME)
        if i == bays:
            break
        for a, b in ((z0 + 0.09, mid - 0.04), (mid + 0.04, z1 - 0.08)):
            fu0, fu1 = u + st / 2 + 0.008, u + bw - st / 2 - 0.008
            field(p, face, at, s, fu0, fu1, a + 0.008, b - 0.008)


def field(p: prop.Prop, face: str, at: float, s: float, u0: float, u1: float, v0: float, v1: float) -> None:
    """A raised field: its bevelled margin rising 12 mm to a flat centre."""
    m = 0.035
    outer = [sk._point(face, at, u, v) for u, v in ((u0, v0), (u1, v0), (u1, v1), (u0, v1))]
    inner = [sk._point(face, at + s * 0.012, u, v) for u, v in ((u0 + m, v0 + m), (u1 - m, v0 + m), (u1 - m, v1 - m),
                                                                (u0 + m, v1 - m))]
    p.loft([outer, inner], FIELD, cap0=False, cap1=True)


def build() -> prop.Prop:
    p = prop.Prop("booking_counter")
    # the carcass, its skirting, the cornice moulding under the top
    p.box((-HW + NOSE, FACE, 0.0), (HW - NOSE, HD, TOP - 0.04), FRAME)
    sk.slab(p, "-y", FACE, 0.02, -HW + NOSE, HW - NOSE, 0.0, SKIRT, "slab*0.3")
    for face, at in (("-x", -HW + NOSE), ("+x", HW - NOSE)):
        sk.slab(p, face, at, 0.02, -HD + NOSE, HD, 0.0, SKIRT, "slab*0.3")
    ogee = [(0.0, TOP - 0.1), (0.008, TOP - 0.095), (0.012, TOP - 0.075), (0.026, TOP - 0.06), (0.03, TOP - 0.045),
            (0.03, TOP - 0.04), (0.0, TOP - 0.04)]
    p.prism([(FACE - o, z) for o, z in ogee], "x", -HW + NOSE - 0.03, HW - NOSE + 0.03, MOULD)
    for sx in (-1.0, 1.0):
        x = sx * (HW - NOSE)
        p.prism([(x + sx * o, z) for o, z in ogee], "y", FACE - 0.03, HD, MOULD)
    # the panelling, front and ends
    panels(p, "-y", FACE, -HW + NOSE + 0.02, HW - NOSE - 0.02, BAYS)
    panels(p, "+x", HW - NOSE, -HD + NOSE + 0.02, HD - 0.02, 1)
    panels(p, "-x", -HW + NOSE, -HD + 0.02, HD - NOSE - 0.02, 1)
    # the top, its nose rounded, a little lighter where hands wore it
    top = p.piece(0.016, 2)
    top.box((-HW, -HD, TOP - 0.04), (HW, HD, TOP), TOP_WOOD)
    sk.rect(p, "+z", TOP + 0.0008, -HW + 0.5, HW - 0.5, -HD + 0.05, -HD + 0.25, "walnut*0.94")
    # left on the top: the leaflet rack (photo 1), a bell, a ledger, a ticket dating press
    rack = p.piece(0.004, 1)
    rx = -HW + 0.55
    rack.box((rx - 0.2, 0.12, TOP), (rx + 0.2, 0.3, TOP + 0.012), FRAME)
    for i, (y, zt) in enumerate(((0.14, 0.035), (0.2, 0.05), (0.26, H - TOP))):
        rack.box((rx - 0.2, y, TOP), (rx + 0.2, y + 0.012, TOP + zt), FRAME)
        for j in range(3):
            lx = rx - 0.18 + j * 0.125
            sk.rect(p, "-y", y - 0.0008, lx, lx + 0.1, TOP + 0.012, TOP + min(zt + 0.02, H - TOP - 0.004),
                    ("plaster", "cream*0.9", "plaster*0.9")[(i + j) % 3])
    for sx in (-1.0, 1.0):
        rack.box((rx + sx * 0.2 - 0.006, 0.12, TOP), (rx + sx * 0.2 + 0.006, 0.3, TOP + 0.05), FRAME)
    bell = [(TOP, 0.045), (TOP + 0.006, 0.045), (TOP + 0.008, 0.038), (TOP + 0.03, 0.032), (TOP + 0.04, 0.02),
            (TOP + 0.043, 0.008), (TOP + 0.05, 0.004), (TOP + 0.052, 0.0)]
    p.lathe([(z, r) for z, r in bell], "butter*0.72", 10, (0.9, -0.15, 0.0), "z")
    p.piece(0.003, 1).box((1.4, -0.2, TOP), (1.66, 0.0, TOP + 0.04), "slab*0.4")
    p.box((1.405, -0.198, TOP + 0.004), (1.655, -0.002, TOP + 0.036), "plaster*0.85")
    press = p.piece(0.005, 1)
    press.box((2.15, -0.05, TOP), (2.35, 0.12, TOP + 0.035), "slab*0.45")
    press.box((2.18, -0.02, TOP + 0.035), (2.32, 0.1, TOP + 0.045), "slab*0.4")
    press.box((2.23, -0.05, TOP + 0.045), (2.27, 0.08, H), "slab*0.5")
    return p


if __name__ == "__main__":
    build().export("booking_counter.glb", budget=1500)
