"""The help point and map board (Subway #24, SM3; finer detail SQ1): a standing information column on the
concourse, after the owner's photos (art/references/maps/subway/24-help-point-map/): a glazed board on each face like
photos 1, 2 and 5's (a deep dark bezel, bevelled, a gasket round a light board under glass), here four-sided to fill
its square block. Its front carries an invented network map (coloured lines, white stations, a red "you are here": no
real network), its back a street map (photo 5: streets, parks and a river, invented), one side the help point
(photo 3's red panel made steel: a raised brushed plate, a green information button and a red emergency one, each
in its bezel ring, the speaker grille and a camera dome), the other a timetable poster. Rounded powder-coated posts
stand at its corners; a lit header box with an "i" sign on every face, a shadow gap under it and a capping lip over
it; a stainless plinth on a dark toe kick, a vent and bolt heads in its faces. SQ1 gave it its depth and materials:
the boards and maps glass (glossy, as behind glazing), the plinth and plate stainless, the posts and bezels satin.

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
import hardsurface as hs  # noqa: E402

W, H = 1.4, 2.2
HW = W / 2
COL = HW - 0.07          # the column's faces
PLINTH = 0.14
HEAD = H - 0.24          # the header's foot
FRAME = "slab*0.5"
BOARD = "plaster*0.98"
POST = "slab*0.42"
GASKET = "slab*0.24"
HEADER = "plaster*0.92"
LIT = "cream*0.98"
PLATE = "concrete*0.78"
# What they are made of (SQ1): everything under the boards' glazing glossy as glass, the posts, bezels and header
# satin powder coat, the plate stainless, the buttons gloss.
GLAZED = (BOARD, "steel*0.6", "green*1.05", "crimson*0.95", "violet*1.05", "teal*0.9", "yellow*0.85", "slab*0.3",
          "plaster", "crimson*1.1", "slab*0.55", "cream*0.92", "sage*0.85", "seafoam*0.85", "slab*0.4",
          "plaster*0.8", "slab*0.6", LIT)
prop.KINDS.update({k: kinds.GLASS for k in GLAZED})
prop.KINDS.update({FRAME: kinds.SATIN, POST: kinds.SATIN, HEADER: kinds.SATIN, PLATE: kinds.STEEL,
                   "green*1.0": kinds.GLOSS, "crimson*0.9": kinds.GLOSS})


def line(p: prop.Prop, face: str, at: float, pts: list, w: float, paint: str) -> None:
    """A thick polyline on `face`: a quad a segment."""
    for (u0, v0), (u1, v1) in zip(pts, pts[1:]):
        du, dv = u1 - u0, v1 - v0
        n = math.hypot(du, dv)
        ou, ov = -dv / n * w / 2, du / n * w / 2
        eu, ev = du / n * w / 2, dv / n * w / 2
        sk.poly(p, face, at, [(u0 - eu - ou, v0 - ev - ov), (u1 + eu - ou, v1 + ev - ov), (u1 + eu + ou, v1 + ev + ov),
                              (u0 - eu + ou, v0 - ev + ov)], paint)


def board(p: prop.Prop, face: str) -> float:
    """A face's deep bevelled bezel, a dark gasket inside it and its light glazed board; returns the board's depth for
    what goes on it."""
    s = -1.0 if face in ("-y", "-x") else 1.0
    at = s * COL
    # the rails bevelled on their own, the stiles plain between them (their long edges in the posts' shadow)
    bez = p.piece(0.008, 1)
    for (c, d) in ((PLINTH + 0.02, PLINTH + 0.1), (HEAD - 0.06, HEAD - 0.01)):
        sk.slab(bez, face, at, 0.03, -COL + 0.03, COL - 0.03, c, d, FRAME)
    for (a, b) in ((-COL + 0.03, -COL + 0.09), (COL - 0.09, COL - 0.03)):
        sk.slab(p, face, at, 0.026, a, b, PLINTH + 0.1, HEAD - 0.06, FRAME)
    u0, u1, v0, v1 = -COL + 0.09, COL - 0.09, PLINTH + 0.1, HEAD - 0.06
    g = 0.012
    for a, b, c, d in ((u0, u1, v0, v0 + g), (u0, u1, v1 - g, v1), (u0, u0 + g, v0 + g, v1 - g),
                       (u1 - g, u1, v0 + g, v1 - g)):
        sk.rect(p, face, at + s * 0.0008, a, b, c, d, GASKET)
    sk.rect(p, face, at + s * 0.0008, u0 + g, u1 - g, v0 + g, v1 - g, BOARD)
    return at + s * 0.0016


def network_map(p: prop.Prop, face: str, at: float) -> None:
    s = -1.0 if face in ("-y", "-x") else 1.0
    z0, z1 = PLINTH + 0.25, HEAD - 0.15
    sk.rect(p, face, at, -0.5, 0.5, z1 + 0.02, z1 + 0.08, "steel*0.6")
    routes = (
        ("green*1.05", [(-0.5, 0.25), (-0.15, 0.25), (0.05, 0.45), (0.5, 0.45)]),
        ("crimson*0.95", [(-0.4, 1.05), (-0.4, 0.75), (-0.1, 0.45), (0.2, 0.45), (0.2, 0.0)]),
        ("violet*1.05", [(-0.5, 0.65), (0.0, 0.65), (0.35, 1.0), (0.5, 1.0)]),
        ("teal*0.9", [(0.1, 1.15), (0.1, 0.7), (0.35, 0.45), (0.35, 0.05)]),
        ("yellow*0.85", [(-0.25, 0.0), (-0.25, 0.45), (-0.45, 0.9)]),
    )
    for i, (paint, pts) in enumerate(routes):  # each route a hair over the last, where they cross
        line(p, face, at + s * 0.0004 * i, [(u, z0 + v) for u, v in pts], 0.028, paint)
    stations = ((-0.15, 0.25), (0.05, 0.45), (-0.1, 0.45), (0.2, 0.45), (0.0, 0.65), (-0.4, 0.75), (0.1, 0.7),
                (0.35, 0.45), (0.35, 1.0), (-0.25, 0.45), (0.2, 0.15), (-0.25, 0.1))
    for u, v in stations:
        sk.disc(p, face, at + s * 0.0024, u, z0 + v, 0.024, "slab*0.3", 8)
        sk.disc(p, face, at + s * 0.0032, u, z0 + v, 0.015, "plaster", 8)
    sk.disc(p, face, at + s * 0.004, 0.05, z0 + 0.45, 0.012, "crimson*1.1", 8)
    sk.lines(p, face, at, -0.5, -0.05, PLINTH + 0.03, PLINTH + 0.2, "slab*0.55", 3)


def street_map(p: prop.Prop, face: str, at: float) -> None:
    s = -1.0 if face in ("-y", "-x") else 1.0
    z0 = PLINTH + 0.15
    sk.rect(p, face, at, -0.5, 0.5, z0, HEAD - 0.12, "cream*0.92")
    sk.poly(p, face, at + s * 0.0008, [(-0.5, z0 + 0.95), (-0.05, z0 + 1.2), (0.25, z0 + 1.45), (-0.5, z0 + 1.45)],
            "sage*0.85")
    sk.poly(p, face, at + s * 0.0008, [(0.15, z0), (0.5, z0), (0.5, z0 + 0.4), (0.3, z0 + 0.5)], "sage*0.85")
    line(p, face, at + s * 0.0016, [(-0.5, z0 + 0.35), (-0.1, z0 + 0.55), (0.2, z0 + 0.95), (0.5, z0 + 1.05)], 0.05,
         "seafoam*0.85")
    for v in (0.2, 0.75, 1.25):
        line(p, face, at + s * 0.0024, [(-0.48, z0 + v), (0.48, z0 + v + 0.08)], 0.022, "plaster")
    for u in (-0.3, 0.05, 0.32):
        line(p, face, at + s * 0.0032, [(u, z0 + 0.02), (u + 0.06, HEAD - 0.14)], 0.022, "plaster")
    sk.disc(p, face, at + s * 0.004, -0.12, z0 + 0.78, 0.035, "crimson*1.1", 10)
    sk.rect(p, face, at + s * 0.004, -0.07, 0.2, z0 + 0.76, z0 + 0.8, "slab*0.4")


def help_panel(p: prop.Prop, face: str, at: float) -> None:
    """The help point: a raised brushed plate, its dark header strip, the two buttons in their bezel rings (green
    information, red emergency under a guard), the speaker grille and the camera dome."""
    s = -1.0 if face in ("-y", "-x") else 1.0
    sk.slab(p.piece(0.004, 1), face, at, 0.008, -0.32, 0.32, 0.9, 1.7, PLATE)
    a = at + s * 0.0088
    sk.rect(p, face, a, -0.3, 0.3, 1.55, 1.68, "steel*0.58")
    sk.rect(p, face, a + s * 0.0008, -0.26, -0.14, 1.57, 1.66, "plaster*0.96")
    sk.lines(p, face, a + s * 0.0008, -0.1, 0.26, 1.58, 1.65, "plaster*0.78", 2)
    axis = "x" if face in ("+x", "-x") else "y"

    def centre(u: float, v: float) -> tuple:
        pt = sk._point(face, 0.0, u, v)
        return (0.0, pt[1], v) if axis == "x" else (pt[0], 0.0, v)

    for u, paint, r in ((-0.13, "green*1.0", 0.045), (0.13, "crimson*0.9", 0.055)):
        prof = [(a, r + 0.028), (a + s * 0.012, r + 0.026), (a + s * 0.014, r + 0.01), (a + s * 0.006, r + 0.004)]
        p.lathe(prof, "slab*0.45", 12, centre(u, 1.28), axis, cap=False)
        cap = [(a + s * 0.004, r), (a + s * 0.02, r), (a + s * 0.024, r * 0.75), (a + s * 0.025, 0.0)]
        p.lathe(cap, paint, 12, centre(u, 1.28), axis)
        sk.rect(p, face, a, u - 0.07, u + 0.07, 1.13, 1.17, "slab*0.48")
    for r in range(4):
        for c in range(6):
            u, v = -0.125 + c * 0.05, 0.95 + r * 0.032
            sk.disc(p, face, a, u, v, 0.009, sk.SLOT, 6)
    sk.disc(p, face, a, 0.22, 1.48, 0.034, "slab*0.35", 12)
    dome = [(a, 0.026), (a + s * 0.01, 0.024), (a + s * 0.018, 0.016), (a + s * 0.022, 0.0)]
    p.lathe(dome, "ink*0.6", 12, centre(0.22, 1.48), axis)
    for u, v in ((-0.3, 0.92), (0.3, 0.92), (-0.3, 1.68), (0.3, 1.68)):
        sk.disc(p, face, a, u, v, 0.007, "concrete*0.6", 6)


def timetable(p: prop.Prop, face: str, at: float) -> None:
    s = -1.0 if face in ("-y", "-x") else 1.0
    sk.rect(p, face, at, -0.48, 0.48, HEAD - 0.32, HEAD - 0.14, "steel*0.6")
    sk.lines(p, face, at + s * 0.0008, -0.44, 0.3, HEAD - 0.3, HEAD - 0.16, "plaster", 2)
    for col in range(3):
        u = -0.46 + col * 0.32
        sk.lines(p, face, at, u, u + 0.28, PLINTH + 0.3, HEAD - 0.4, "slab*0.6", 16, (1.0, 0.7, 0.85, 0.9, 0.6))


def corner_posts(p: prop.Prop) -> None:
    """The rounded powder-coated posts at the column's four corners, plinth to header, framing the bezels."""
    post = p
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            pts = [(sx * (COL + 0.005) + x, sy * (COL + 0.005) + y) for x, y in hs.rounded_rect(0.04, 0.04, 0.012, 3)]
            post.prism(pts, "z", PLINTH, HEAD - 0.012, POST)


def plinth(p: prop.Prop) -> None:
    """The stainless plinth on its dark toe kick: a vent and two bolt heads in each face."""
    p.box((-HW + 0.04, -HW + 0.04, 0.0), (HW - 0.04, HW - 0.04, 0.025), sk.SLOT)
    p.piece(0.01, 2).box((-HW + 0.02, -HW + 0.02, 0.025), (HW - 0.02, HW - 0.02, PLINTH), sk.STAINLESS_DARK)
    for face in ("-y", "+y", "-x", "+x"):
        s = -1.0 if face in ("-y", "-x") else 1.0
        at = s * (HW - 0.02 + 0.0008)
        sk.louvre(p, face, at, -0.18, 0.18, 0.05, 0.11, "concrete*0.56", 3)
        for u in (-0.5, 0.5):
            sk.disc(p, face, at, u, 0.08, 0.01, "concrete*0.84", 6)


def header(p: prop.Prop) -> None:
    """The lit header box: satin, bevelled, a capping lip over it and a shadow gap under it; on each face its lit
    panel and the "i" sign."""
    p.box((-COL - 0.02, -COL - 0.02, HEAD - 0.02), (COL + 0.02, COL + 0.02, HEAD + 0.002), GASKET)
    p.piece(0.012, 2).box((-HW + 0.012, -HW + 0.012, HEAD), (HW - 0.012, HW - 0.012, H - 0.03), HEADER)
    p.piece(0.008, 2).box((-HW + 0.0004, -HW + 0.0004, H - 0.032), (HW - 0.0004, HW - 0.0004, H), HEADER + "*0.9")
    for face in ("-y", "+y", "-x", "+x"):
        s = -1.0 if face in ("-y", "-x") else 1.0
        at = s * (HW - 0.012 + 0.0008)
        sk.rect(p, face, at, -HW + 0.06, HW - 0.06, HEAD + 0.03, H - 0.06, LIT)
        a = at + s * 0.0008
        sk.rect(p, face, a, -0.45, -0.12, HEAD + 0.09, HEAD + 0.12, "slab*0.62")
        sk.rect(p, face, a, 0.12, 0.38, HEAD + 0.09, HEAD + 0.12, "slab*0.62")
        sk.disc(p, face, a, 0.0, HEAD + 0.105, 0.092, "slab*0.5", 14)
        sk.disc(p, face, a + s * 0.0008, 0.0, HEAD + 0.105, 0.08, "steel*0.6", 14)
        sk.rect(p, face, a + s * 0.0016, -0.011, 0.011, HEAD + 0.055, HEAD + 0.125, "plaster")
        sk.disc(p, face, a + s * 0.0016, 0.0, HEAD + 0.15, 0.013, "plaster", 6)


def build() -> prop.Prop:
    p = prop.Prop("help_point")
    plinth(p)
    p.box((-COL, -COL, PLINTH), (COL, COL, HEAD), FRAME)
    corner_posts(p)
    header(p)
    for face in ("-y", "+y", "-x", "+x"):
        depth = board(p, face)
        {"-y": network_map, "+y": street_map, "+x": help_panel, "-x": timetable}[face](p, face, depth)
    return p


if __name__ == "__main__":
    build().export("help_point.glb", budget=2400)
