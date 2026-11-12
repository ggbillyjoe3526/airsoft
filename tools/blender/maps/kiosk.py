"""The shuttered kiosks (Subway #21, SM3): a newsagent's kiosk standing in the ticket hall and a longer one between
the escalator banks, after the owner's photos (art/references/maps/subway/21-kiosk/): a free-standing booth with
round corners and a stainless plinth (photos 3 and 4), a dark fascia with a light sign board (photo 1's, its words
left off), and its roller shutter down over the counter (the station is shut: the agreed default), a stainless
counter ledge under it and empty wire news racks below (photo 5). A staff door at one end, a poster frame at the other,
an extractor on the roof. The long one is open on two bays at its front, a service hatch and two poster frames at its
back, as it stands clear of the walls.

Two models, each filling its block: `kiosk` 3.0 x 2.5 x 2.6 m (the hall's, its back to the wall) and `kiosk_long`
5.2 x 2.8 x 2.0 m (the concourse's). Budget 4,000 triangles each.

Usage: python3 tools/blender/maps/kiosk.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402
import hardsurface as hs  # noqa: E402
import hallkit as sk  # noqa: E402

R = 0.34            # the corners' radius on plan
INSET = 0.07        # the body's walls inside the roof cap's edge
PLINTH = 0.18
BODY = "green*0.58"
TRIM = sk.STAINLESS
FASCIA = "slab*0.36"
SHUTTER = "concrete*0.74"
COUNTER = 0.92      # the counter ledge's top
POSTERS = (("cream*0.9", "crimson*0.75", "teal*0.7"), ("plaster", "violet*0.8", "butter*0.85"))


def outline(hw: float, hd: float, inset: float, seg: int = 5) -> list:
    return hs.rounded_rect(hw - inset, hd - inset, max(0.02, R - inset), seg)


def frame(p: prop.Prop, face: str, at: float, u0: float, u1: float, v0: float, v1: float, colours: tuple) -> None:
    """A poster in a stainless frame, faded: a pale sheet with a few blocks of colour (no words)."""
    sk.slab(p, face, at, 0.02, u0, u1, v0, v1, TRIM)
    s = -1.0 if face in ("-y", "-x") else 1.0
    a = at + s * 0.0208
    sk.rect(p, face, a, u0 + 0.03, u1 - 0.03, v0 + 0.03, v1 - 0.03, colours[0])
    w, h = u1 - u0 - 0.06, v1 - v0 - 0.06
    sk.rect(p, face, a + s * 0.0008, u0 + 0.06, u0 + 0.06 + w * 0.7, v1 - 0.06 - h * 0.18, v1 - 0.06, colours[1])
    sk.rect(p, face, a + s * 0.0008, u0 + 0.06, u1 - 0.06, v0 + 0.06 + h * 0.2, v0 + 0.06 + h * 0.6, colours[2])
    sk.lines(p, face, a + s * 0.0008, u0 + 0.06, u1 - 0.12, v0 + 0.06, v0 + 0.04 + h * 0.18, "slab*0.5", 3)


def shuttered_bay(p: prop.Prop, soft: prop.Prop, face: str, at: float, u0: float, u1: float, top: float) -> None:
    """A counter opening on `face`: its shutter down from its box under the fascia to the counter ledge, guide rails
    each side, the ledge on brackets and wire news racks under it."""
    s = -1.0 if face in ("-y", "-x") else 1.0
    sk.shutter(p, face, at, u0, u1, COUNTER + 0.02, top - 0.2, SHUTTER, slat=0.06)
    # a padlock on the bottom rail's hasp, in the middle
    cu = (u0 + u1) / 2
    sk.slab(p, face, at, 0.03, cu - 0.03, cu + 0.03, COUNTER + 0.02, COUNTER + 0.07, "slab*0.5")
    sk.slab(p, face, at + s * 0.03, 0.02, cu - 0.025, cu + 0.025, COUNTER - 0.03, COUNTER + 0.03, "yellow*0.6")
    soft.box(*_box(face, at, INSET - 0.006, u0 - 0.03, u1 + 0.03, top - 0.2, top), TRIM)
    for u in (u0 - 0.04, u1):
        sk.slab(p, face, at, 0.03, u, u + 0.04, COUNTER, top - 0.2, TRIM)
    soft.box(*_box(face, at, INSET - 0.002, u0 - 0.06, u1 + 0.06, COUNTER - 0.03, COUNTER + 0.02), TRIM)
    # the news racks: three sloped wire shelves under the ledge, their lips and end rails
    for i in range(3):
        z = 0.3 + i * 0.2
        sk.slab(p, face, at, 0.05, u0 + 0.05, u1 - 0.05, z, z + 0.012, "concrete*0.62")
        sk.slab(p, face, at + s * 0.05, 0.008, u0 + 0.05, u1 - 0.05, z, z + 0.06, "concrete*0.62")
    for u in (u0 + 0.05, (u0 + u1) / 2 - 0.006, u1 - 0.062):
        sk.slab(p, face, at, 0.058, u, u + 0.012, 0.28, 0.76, "concrete*0.62")


def _box(face: str, at: float, depth: float, u0: float, u1: float, v0: float, v1: float) -> tuple:
    a = sk._point(face, at, u0, v0)
    b = sk._point(face, at + (-1.0 if face in ("-y", "-x") else 1.0) * depth, u1, v1)
    return tuple(min(a[i], b[i]) for i in range(3)), tuple(max(a[i], b[i]) for i in range(3))


def build(w: float, h: float, d: float, name: str, bays: int, open_back: bool, seg: int) -> prop.Prop:
    p = prop.Prop(name)
    soft = p.piece(0.008, 2)
    hw, hd = w / 2, d / 2
    # the plinth, the body, the fascia, the roof cap with its drip edge
    p.prism(outline(hw, hd, INSET + 0.03, seg), "z", 0.0, 0.02, "slab*0.3")
    soft.prism(outline(hw, hd, INSET - 0.01, seg), "z", 0.02, PLINTH, TRIM)
    p.prism(outline(hw, hd, INSET, seg), "z", PLINTH, h - 0.4, BODY)
    soft.prism(outline(hw, hd, INSET - 0.02, seg), "z", h - 0.4, h - 0.16, FASCIA)
    roof = p.piece(0.012, 3)
    roof.prism(outline(hw, hd, 0.0, 8), "z", h - 0.16, h - 0.09, TRIM)
    roof.prism(outline(hw, hd, 0.08, 6), "z", h - 0.09, h - 0.07, "concrete*0.6")
    # a panel seam band round the body at the counter's height and over the plinth
    for z in (PLINTH + 0.04, h - 0.46):
        p.prism(outline(hw, hd, INSET - 0.004, seg), "z", z, z + 0.012, "green*0.45")
    # the sign boards on the fascia, front and back: a light board, dark blocks for its words
    fy = hd - INSET + 0.02
    for face, at in (("-y", -fy), ("+y", fy)):
        bw = min(w - 2 * R - 0.2, 2.4)
        sk.rect(p, face, at - (0.0008 if face == "-y" else -0.0008), -bw / 2, bw / 2, h - 0.37, h - 0.19, "cream*0.88")
        for i, (a, b) in enumerate(((-0.42, -0.1), (-0.06, 0.18), (0.22, 0.42))):
            sk.rect(p, face, at - (0.0016 if face == "-y" else -0.0016), a * bw, b * bw, h - 0.33, h - 0.23,
                    "slab*0.4" if i != 1 else "crimson*0.7")
    # the front: its shuttered bays over the counter
    fa = -(hd - INSET) - 0.001
    span = w - 2 * R - 0.2
    gap = 0.12
    bw = (span - (bays - 1) * gap) / bays
    for i in range(bays):
        u0 = -span / 2 + i * (bw + gap)
        shuttered_bay(p, soft, "-y", fa, u0, u0 + bw, h - 0.4)
    # the back: a service hatch and posters where it stands clear, else plain with a vent
    ba = hd - INSET + 0.001
    if open_back:
        frame(p, "+y", ba, -span / 2, -span / 2 + 0.75, 0.9, 1.95, POSTERS[0])
        frame(p, "+y", ba, span / 2 - 0.75, span / 2, 0.9, 1.95, POSTERS[1])
        sk.shutter(p, "+y", ba, -0.5, 0.5, 0.95, 1.85, SHUTTER)
        soft.box(*_box("+y", ba, 0.05, -0.53, 0.53, 1.85, 1.95), TRIM)
    else:
        sk.louvre(p, "+y", ba, -0.4, 0.4, 1.6, 1.85, BODY, 5)
    # the ends: the staff door at +X with its handle, lock and kick plate; a poster at -X
    ea = hw - INSET + 0.001
    dw = min(0.82, d - 2 * R - 0.12)
    sk.rect(p, "+x", ea, -dw / 2 - 0.012, dw / 2 + 0.012, PLINTH, 2.05, sk.SLOT)
    door = p.piece(0.004, 1)
    door.box((ea - 0.001, -dw / 2, PLINTH + 0.01), (ea + 0.012, dw / 2, 2.04), BODY)
    sk.rect(p, "+x", ea + 0.0128, -dw / 2 + 0.08, dw / 2 - 0.08, 1.5, 1.9, "green*0.48")
    sk.rect(p, "+x", ea + 0.0128, -dw / 2 + 0.08, dw / 2 - 0.08, 0.5, 1.35, "green*0.48")
    sk.rect(p, "+x", ea + 0.0128, -dw / 2 + 0.02, dw / 2 - 0.02, PLINTH + 0.02, PLINTH + 0.22, TRIM)
    door.box((ea + 0.012, dw / 2 - 0.12, 1.02), (ea + 0.05, dw / 2 - 0.1, 1.12), TRIM)
    door.box((ea + 0.04, dw / 2 - 0.26, 1.06), (ea + 0.055, dw / 2 - 0.1, 1.08), TRIM)
    sk.disc(p, "+x", ea + 0.0128, dw / 2 - 0.11, 1.22, 0.016, "slab*0.4", 8)
    frame(p, "-x", -ea, -min(0.5, dw / 2), min(0.5, dw / 2), 0.9, 2.0, POSTERS[0 if open_back else 1])
    # panel seams down the body's straight runs, between its sheets
    for face, half, run in (("-y", hd, w), ("+y", hd, w), ("+x", hw, d), ("-x", hw, d)):
        at = (half - INSET) * (-1.0 if face in ("-y", "-x") else 1.0)
        at += 0.0008 * (-1.0 if face in ("-y", "-x") else 1.0)
        n = max(1, round((run - 2 * R) / 0.62))
        for i in range(n + 1):
            u = -(run / 2 - R) + i * (run - 2 * R) / n
            sk.rect(p, face, at, u - 0.004, u + 0.004, PLINTH + 0.06, h - 0.48, "green*0.4")
    # the roof's extractor: a low box with a louvre each side
    ex = p.piece(0.006, 1)
    ex.box((-0.3, -0.22, h - 0.07), (0.3, 0.22, h), "concrete*0.55")
    for face, at in (("-y", -0.2208), ("+y", 0.2208)):
        sk.louvre(p, face, at, -0.25, 0.25, h - 0.06, h - 0.012, "concrete*0.55", 4)
    return p


if __name__ == "__main__":
    build(3.0, 2.5, 2.6, "kiosk", 1, False, 10).export("kiosk.glb", budget=4000)
    build(5.2, 2.8, 2.0, "kiosk_long", 2, True, 4).export("kiosk_long.glb", budget=4000)
