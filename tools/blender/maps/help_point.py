"""The help point and map board (Subway #24, SM3; finer detail SQ1): a standing information totem on the concourse,
after the owner's photos (art/references/maps/subway/24-help-point-map/), made four-sided to fill its square block.
Its housing is a powder-coated crimson column like photos 3 and 4's (no team's hue), its vertical corners cut back
in deep chamfers, standing on a light base plate over a dark toe kick (photo 2's plinth). Each face has photo 3's
layout: a header with a big light sign block and a smaller one under it (no words), a deep window recessed into the
housing below it, and in the housing's foot a light ring with an "i". Each window has a dark glass bezel round a light
board under glazing: at the front an invented network map (coloured lines, white stations, a red "you are here", no
real network) under photo 4's dark "you are here" strip, at the back an invented street map (photo 5: streets, parks
and a river), on one side the help point (a brushed steel plate in the window: a dark header strip, a big speaker
grille, a green information button and a red emergency one, each in a raised bezel, a camera dome), on the other a
timetable poster. A thin dark shadow gap parts the header from its capping lip.

Fills a help point's block (1.4 x 2.2 x 1.4 m, its bounds as before SQ1). Budget 2,400 triangles (SQ1, from 1,200).

Usage: python3 tools/blender/maps/help_point.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402
import hallkit as sk  # noqa: E402
import surface_kinds as kinds  # noqa: E402

W, H = 1.4, 2.2
HW = W / 2 - 0.0004      # the base plate and cap (the block's bounds as before)
BODY = 0.68              # the housing's faces
CHAMFER = 0.09           # its vertical corners cut back
NOTCH = 0.5              # the windows' half width
DEPTH = 0.07             # the windows' recess
TOE = 0.1                # the housing's foot over the floor
WIN0, WIN1 = 0.6, 1.76   # the windows' sill and head
CAP = H - 0.06           # the capping lip's foot
HOUSING = "crimson*0.72"
CAPPING = "crimson*0.6"
BASE = "concrete*0.82"
KICK = "slab*0.34"
BEZEL = "slab*0.32"
BOARD = "plaster*0.98"
SIGN = "plaster*0.96"
PLATE = "concrete*0.78"
# What they are made of (SQ1): the housing and cap satin powder coat, the base plate and help plate stainless,
# everything under the windows' glazing glossy as glass, the buttons gloss.
GLAZED = (BOARD, BEZEL, "steel*0.6", "green*1.05", "crimson*0.95", "violet*1.05", "teal*0.9", "yellow*0.85",
          "slab*0.3", "plaster", "crimson*1.1", "slab*0.55", "cream*0.92", "sage*0.85", "seafoam*0.85", "slab*0.4",
          "slab*0.6", "slab*0.36")
prop.KINDS.update({k: kinds.GLASS for k in GLAZED})
prop.KINDS.update({HOUSING: kinds.SATIN, CAPPING: kinds.SATIN, SIGN: kinds.SATIN, BASE: kinds.STEEL, PLATE: kinds.STEEL,
                   KICK: kinds.RUBBER, "green*1.0": kinds.GLOSS, "crimson*0.9": kinds.GLOSS})


def section(notched: bool) -> list:
    """The housing's plan (counter-clockwise from above): a square with chamfered corners, each face notched in by
    the window's recess where `notched`."""
    b, c, n, r = BODY, CHAMFER, NOTCH, BODY - DEPTH
    side = [(-b + c, -b)]
    if notched:
        side += [(-n, -b), (-n, -r), (n, -r), (n, -b)]
    side += [(b - c, -b)]
    pts = []
    for k in range(4):  # the -y side turned a quarter at a time: -y, +x, +y, -x
        ca, sa = round(math.cos(k * math.pi / 2)), round(math.sin(k * math.pi / 2))
        pts += [(ca * x - sa * y, sa * x + ca * y) for x, y in side]
    return pts


def line(p: prop.Prop, face: str, at: float, pts: list, w: float, paint: str, step: float = 0.0) -> None:
    """A thick polyline on `face`: a quad a segment, each `step` m over the last where their ends overlap."""
    for i, ((u0, v0), (u1, v1)) in enumerate(zip(pts, pts[1:])):
        du, dv = u1 - u0, v1 - v0
        n = math.hypot(du, dv)
        ou, ov = -dv / n * w / 2, du / n * w / 2
        eu, ev = du / n * w / 2, dv / n * w / 2
        sk.poly(p, face, at + i * step, [(u0 - eu - ou, v0 - ev - ov), (u1 + eu - ou, v1 + ev - ov),
                                         (u1 + eu + ou, v1 + ev + ov), (u0 - eu + ou, v0 - ev + ov)], paint)


def out(face: str) -> float:
    return -1.0 if face in ("-y", "-x") else 1.0


def window(p: prop.Prop, face: str) -> float:
    """A window's dark glass bezel on the recess floor and the light board inside it; returns the board's depth."""
    s = out(face)
    at = s * (BODY - DEPTH + 0.0008)
    sk.rect(p, face, at, -NOTCH, NOTCH, WIN0, WIN1, BEZEL)
    sk.rect(p, face, at + s * 0.0008, -NOTCH + 0.035, NOTCH - 0.035, WIN0 + 0.035, WIN1 - 0.035, BOARD)
    return at + s * 0.0016


def face_signs(p: prop.Prop, face: str) -> None:
    """The header's two light sign blocks (no words) and the "i" ring in the housing's foot."""
    s = out(face)
    at = s * (BODY + 0.0008)
    sk.rect(p, face, at, -0.46, 0.46, 1.9, 2.04, SIGN)
    sk.rect(p, face, at, -0.24, 0.24, 1.82, 1.86, SIGN)
    sk.disc(p, face, at, 0.0, 0.36, 0.15, SIGN, 24)
    sk.disc(p, face, at + s * 0.0008, 0.0, 0.36, 0.122, HOUSING, 24)
    sk.rect(p, face, at + s * 0.0016, -0.022, 0.022, 0.27, 0.4, SIGN)
    sk.disc(p, face, at + s * 0.0016, 0.0, 0.445, 0.026, SIGN, 8)


def pill(cu: float, cv: float, hw: float, hh: float, vertical: bool = False) -> list:
    """A rounded bar's outline (u, v) centred on cu, cv: half sizes hw by hh, its short ends round."""
    r = hw if vertical else hh
    if vertical:
        return sk.arc((cu, cv + hh - r), r, 0.0, math.pi, 4) + sk.arc((cu, cv - hh + r), r, math.pi, 2 * math.pi, 4)
    return sk.arc((cu + hw - r, cv), r, -math.pi / 2, math.pi / 2, 4) + \
        sk.arc((cu - hw + r, cv), r, math.pi / 2, 3 * math.pi / 2, 4)


def network_map(p: prop.Prop, face: str, at: float) -> None:
    """The invented network map under photo 4's dark "you are here" strip."""
    s = out(face)
    sk.rect(p, face, at, -0.465, 0.465, WIN1 - 0.135, WIN1 - 0.035, "slab*0.4")
    sk.disc(p, face, at + s * 0.0008, -0.41, WIN1 - 0.085, 0.022, "plaster", 8)
    sk.rect(p, face, at + s * 0.0008, -0.36, -0.12, WIN1 - 0.1, WIN1 - 0.07, "plaster")
    sk.rect(p, face, at + s * 0.0008, 0.2, 0.43, WIN1 - 0.1, WIN1 - 0.07, "plaster*0.8")
    z0, k = WIN0 + 0.1, 0.84
    routes = (
        ("green*1.05", [(-0.46, 0.25), (-0.15, 0.25), (0.05, 0.45), (0.46, 0.45)]),
        ("crimson*0.95", [(-0.4, 1.05), (-0.4, 0.75), (-0.1, 0.45), (0.2, 0.45), (0.2, 0.0)]),
        ("violet*1.05", [(-0.46, 0.65), (0.0, 0.65), (0.35, 1.0), (0.46, 1.0)]),
        ("teal*0.9", [(0.1, 1.05), (0.1, 0.7), (0.35, 0.45), (0.35, 0.05)]),
        ("yellow*0.85", [(-0.25, 0.0), (-0.25, 0.45), (-0.42, 0.9)]),
    )
    for i, (paint, pts) in enumerate(routes):  # each route a hair over the last, where they cross
        line(p, face, at + s * 0.0004 * i, [(u, z0 + v * k) for u, v in pts], 0.034, paint, s * 0.0001)
    stations = ((-0.15, 0.25), (0.05, 0.45), (-0.1, 0.45), (0.2, 0.45), (0.0, 0.65), (-0.4, 0.75), (0.1, 0.7),
                (0.35, 0.45), (0.35, 1.0), (-0.25, 0.45), (0.2, 0.15), (-0.25, 0.1))
    for u, v in stations:
        sk.disc(p, face, at + s * 0.0024, u, z0 + v * k, 0.026, "slab*0.3", 10)
        sk.disc(p, face, at + s * 0.0032, u, z0 + v * k, 0.016, "plaster", 10)
    sk.disc(p, face, at + s * 0.004, 0.05, z0 + 0.45 * k, 0.014, "crimson*1.1", 8)
    # photo 4's screen controls: a dark search pill low in the middle and a dark level pill at the right edge
    sk.poly(p, face, at + s * 0.0048, pill(0.06, WIN0 + 0.2, 0.2, 0.028), "slab*0.4")
    sk.rect(p, face, at + s * 0.0056, -0.06, 0.2, WIN0 + 0.192, WIN0 + 0.208, "plaster*0.8")
    sk.poly(p, face, at + s * 0.0048, pill(0.43, WIN0 + 0.5, 0.022, 0.1, vertical=True), "slab*0.4")
    for v in (-0.05, 0.0, 0.05):
        sk.disc(p, face, at + s * 0.0056, 0.43, WIN0 + 0.5 + v, 0.01, "plaster", 6)
    # the key along its foot: each line's colour block and a light-grey label bar (no words)
    for i, (paint, _pts) in enumerate(routes):
        u = -0.45 + i * 0.185
        sk.rect(p, face, at, u, u + 0.04, WIN0 + 0.05, WIN0 + 0.08, paint)
        sk.rect(p, face, at, u + 0.055, u + 0.15, WIN0 + 0.057, WIN0 + 0.073, "slab*0.55")


def street_map(p: prop.Prop, face: str, at: float) -> None:
    """The invented street map: parks, a river, streets and a "you are here" dot."""
    s = out(face)
    z0, z1 = WIN0 + 0.04, WIN1 - 0.04
    k = (z1 - z0) / 1.45
    sk.rect(p, face, at, -0.46, 0.46, z0, z1, "cream*0.92")
    sk.poly(p, face, at + s * 0.0008, [(-0.46, z0 + 0.95 * k), (-0.05, z0 + 1.2 * k), (0.25, z1), (-0.46, z1)],
            "sage*0.85")
    sk.poly(p, face, at + s * 0.0008, [(0.15, z0), (0.46, z0), (0.46, z0 + 0.4 * k), (0.3, z0 + 0.5 * k)],
            "sage*0.85")
    line(p, face, at + s * 0.0016, [(-0.46, z0 + 0.35 * k), (-0.1, z0 + 0.55 * k), (0.2, z0 + 0.95 * k),
                                     (0.46, z0 + 1.05 * k)], 0.06, "seafoam*0.85", s * 0.0002)
    for v in (0.2, 0.75, 1.25):
        line(p, face, at + s * 0.0024, [(-0.44, z0 + v * k), (0.44, z0 + v * k + 0.06)], 0.026, "plaster")
    for u in (-0.3, 0.05, 0.32):
        line(p, face, at + s * 0.0032, [(u, z0 + 0.02), (u + 0.05, z1 - 0.02)], 0.026, "plaster")
    sk.disc(p, face, at + s * 0.004, -0.12, z0 + 0.78 * k, 0.04, "crimson*1.1", 10)
    sk.rect(p, face, at + s * 0.004, -0.07, 0.24, z0 + 0.76 * k, z0 + 0.8 * k, "slab*0.4")


def help_panel(p: prop.Prop, face: str) -> None:
    """The help point filling its window: a brushed steel plate, its dark header strip with a light block, the big
    speaker grille, the two buttons in raised bezels (green information, red emergency) and the camera dome."""
    s = out(face)
    at = s * (BODY - DEPTH)
    sk.slab(p.piece(0.004, 1), face, at, 0.012, -NOTCH + 0.02, NOTCH - 0.02, WIN0 + 0.02, WIN1 - 0.02, PLATE)
    a = at + s * 0.0128
    sk.rect(p, face, a, -0.44, 0.44, WIN1 - 0.2, WIN1 - 0.06, "slab*0.4")
    sk.rect(p, face, a + s * 0.0008, -0.38, 0.12, WIN1 - 0.16, WIN1 - 0.1, "plaster*0.96")
    axis = "x" if face in ("+x", "-x") else "y"

    def centre(u: float, v: float) -> tuple:
        pt = sk._point(face, 0.0, u, v)
        return (0.0, pt[1], v) if axis == "x" else (pt[0], 0.0, v)

    # the speaker: a dark grille in a raised steel ring, its slots in rings
    gz = 1.3
    p.lathe([(a, 0.15), (a + s * 0.018, 0.145), (a + s * 0.018, 0.12), (a + s * 0.006, 0.115)], PLATE, 20,
            centre(0.0, gz), axis, cap=False)
    sk.disc(p, face, a + s * 0.006, 0.0, gz, 0.118, "slab*0.3", 20)
    for r, n in ((0.0, 1), (0.04, 6), (0.08, 10)):
        for i in range(n):
            t = 2 * math.pi * (i + 0.5) / n
            sk.disc(p, face, a + s * 0.0068, r * math.cos(t), gz + r * math.sin(t), 0.011, "slab*0.6", 6)
    for u, paint, r in ((-0.22, "green*1.0", 0.055), (0.22, "crimson*0.9", 0.065)):
        prof = [(a, r + 0.035), (a + s * 0.022, r + 0.032), (a + s * 0.026, r + 0.012), (a + s * 0.012, r + 0.004)]
        p.lathe(prof, "slab*0.45", 16, centre(u, 0.9), axis, cap=False)
        cap = [(a + s * 0.008, r), (a + s * 0.03, r), (a + s * 0.036, r * 0.7), (a + s * 0.037, 0.0)]
        p.lathe(cap, paint, 16, centre(u, 0.9), axis)
        sk.rect(p, face, a, u - 0.09, u + 0.09, 0.71, 0.75, "slab*0.48")
    sk.disc(p, face, a, 0.34, 1.5, 0.045, "slab*0.35", 12)
    dome = [(a, 0.034), (a + s * 0.014, 0.031), (a + s * 0.024, 0.02), (a + s * 0.028, 0.0)]
    p.lathe(dome, "slab*0.36", 12, centre(0.34, 1.5), axis)
    for u, v in ((-0.43, WIN0 + 0.05), (0.43, WIN0 + 0.05), (-0.43, WIN1 - 0.24), (0.43, WIN1 - 0.24)):
        sk.disc(p, face, a, u, v, 0.009, "concrete*0.6", 6)


def timetable(p: prop.Prop, face: str, at: float) -> None:
    """A timetable poster: a dark header band with light blocks, three columns of print."""
    s = out(face)
    sk.rect(p, face, at, -0.465, 0.465, WIN1 - 0.22, WIN1 - 0.035, "steel*0.6")
    sk.lines(p, face, at + s * 0.0008, -0.42, 0.3, WIN1 - 0.2, WIN1 - 0.06, "plaster", 2)
    for col in range(3):
        u = -0.44 + col * 0.3
        sk.lines(p, face, at, u, u + 0.26, WIN0 + 0.08, WIN1 - 0.28, "slab*0.6", 12, (1.0, 0.7, 0.85, 0.9, 0.6))


def build() -> prop.Prop:
    p = prop.Prop("help_point")
    # the light base plate on its dark toe kick, the housing in three courses (the middle one notched by the
    # windows), the shadow gap and the capping lip
    p.piece(0.008, 1).box((-HW, -HW, 0.0), (HW, HW, 0.035), BASE)
    p.box((-BODY + 0.06, -BODY + 0.06, 0.035), (BODY - 0.06, BODY - 0.06, TOE), KICK)
    p.piece(0.012, 2).prism(section(False), "z", TOE, WIN0, HOUSING)
    p.piece(0.008, 1).prism(section(True), "z", WIN0, WIN1, HOUSING)
    p.piece(0.012, 2).prism(section(False), "z", WIN1, CAP - 0.02, HOUSING)
    p.box((-BODY + 0.04, -BODY + 0.04, CAP - 0.02), (BODY - 0.04, BODY - 0.04, CAP), BEZEL)
    p.piece(0.01, 1).box((-HW, -HW, CAP), (HW, HW, H), CAPPING)
    for face in ("-y", "+y", "-x", "+x"):
        face_signs(p, face)
        if face == "+x":
            help_panel(p, face)
            continue
        depth = window(p, face)
        {"-y": network_map, "+y": street_map, "-x": timetable}[face](p, face, depth)
    return p


if __name__ == "__main__":
    build().export("help_point.glb", budget=2400)
