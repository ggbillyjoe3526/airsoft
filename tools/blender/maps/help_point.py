"""The help point and map board (Subway #24, SM3): a standing information column on the concourse, after the
owner's photos (art/references/maps/subway/24-help-point-map/): a framed board on each face like photos 1, 2 and 5's
(a dark bezel, a light board), here four-sided to fill its square block. Its front carries an invented network map
(coloured lines, white stations, a red "you are here": no real network), its back a street map (photo 5: streets,
parks and a river, invented), one side the help point (photo 3's red panel made steel: a green information button,
a red emergency one, the speaker grille and a camera), the other a timetable poster. A light header with an "i" sign
on every face, a stainless plinth.

Fills a help point's block (1.4 x 2.2 x 1.4 m). Budget 1,200 triangles.

Usage: python3 tools/blender/maps/help_point.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402
import hallkit as sk  # noqa: E402

W, H = 1.4, 2.2
HW = W / 2
COL = HW - 0.07          # the column's faces
PLINTH = 0.14
HEAD = H - 0.24          # the header's foot
FRAME = "slab*0.5"
BOARD = "plaster*0.98"


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
    """A face's bezel and its light board; returns the board's depth for what goes on it."""
    s = -1.0 if face in ("-y", "-x") else 1.0
    at = s * COL
    for (a, b, c, d) in ((-COL, -COL + 0.06, PLINTH + 0.1, HEAD - 0.06), (COL - 0.06, COL, PLINTH + 0.1, HEAD - 0.06),
                         (-COL, COL, PLINTH, PLINTH + 0.1), (-COL, COL, HEAD - 0.06, HEAD)):
        sk.slab(p, face, at, 0.03, a, b, c, d, FRAME)
    sk.rect(p, face, at + s * 0.0008, -COL + 0.06, COL - 0.06, PLINTH + 0.1, HEAD - 0.06, BOARD)
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
    s = -1.0 if face in ("-y", "-x") else 1.0
    sk.rect(p, face, at, -0.32, 0.32, 0.9, 1.7, sk.STAINLESS)
    a = at + s * 0.0008
    sk.rect(p, face, a, -0.3, 0.3, 1.55, 1.68, "steel*0.6")
    sk.rect(p, face, a + s * 0.0008, -0.26, -0.14, 1.57, 1.66, "plaster")
    sk.lines(p, face, a + s * 0.0008, -0.1, 0.26, 1.58, 1.65, "plaster*0.8", 2)
    btn = p.piece(0.006, 1)
    for u, paint in ((-0.13, "green*1.0"), (0.13, "crimson*0.95")):
        sk.disc(p, face, a, u, 1.28, 0.08, "slab*0.45", 14)
        sk.slab(btn, face, a, 0.02, u - 0.05, u + 0.05, 1.23, 1.33, paint)
        sk.rect(p, face, a, u - 0.07, u + 0.07, 1.13, 1.17, "slab*0.5")
    for r in range(3):
        for c in range(5):
            u, v = -0.1 + c * 0.05, 0.97 + r * 0.035
            sk.rect(p, face, a, u - 0.008, u + 0.008, v - 0.008, v + 0.008, sk.SLOT)
    sk.disc(p, face, a, 0.22, 1.48, 0.03, "slab*0.35", 10)
    sk.disc(p, face, a + s * 0.0008, 0.22, 1.48, 0.012, "ink*0.6", 8)


def timetable(p: prop.Prop, face: str, at: float) -> None:
    s = -1.0 if face in ("-y", "-x") else 1.0
    sk.rect(p, face, at, -0.48, 0.48, HEAD - 0.32, HEAD - 0.14, "steel*0.6")
    sk.lines(p, face, at + s * 0.0008, -0.44, 0.3, HEAD - 0.3, HEAD - 0.16, "plaster", 2)
    for col in range(3):
        u = -0.46 + col * 0.32
        sk.lines(p, face, at, u, u + 0.28, PLINTH + 0.3, HEAD - 0.4, "slab*0.6", 16, (1.0, 0.7, 0.85, 0.9, 0.6))


def build() -> prop.Prop:
    p = prop.Prop("help_point")
    soft = p.piece(0.01, 2)
    soft.box((-HW + 0.02, -HW + 0.02, 0.0), (HW - 0.02, HW - 0.02, PLINTH), sk.STAINLESS_DARK)
    p.box((-COL, -COL, PLINTH), (COL, COL, HEAD), FRAME)
    head = p.piece(0.014, 3)
    head.box((-HW + 0.002, -HW + 0.002, HEAD), (HW - 0.002, HW - 0.002, H), "plaster*0.92")
    for face in ("-y", "+y", "-x", "+x"):
        s = -1.0 if face in ("-y", "-x") else 1.0
        at = s * (HW - 0.0012)
        sk.disc(p, face, at, 0.0, HEAD + 0.12, 0.08, "steel*0.6", 16)
        sk.rect(p, face, at + s * 0.0008, -0.011, 0.011, HEAD + 0.07, HEAD + 0.14, "plaster")
        sk.disc(p, face, at + s * 0.0008, 0.0, HEAD + 0.165, 0.013, "plaster", 6)
        depth = board(p, face)
        {"-y": network_map, "+y": street_map, "+x": help_panel, "-x": timetable}[face](p, face, depth)
    return p


if __name__ == "__main__":
    build().export("help_point.glb", budget=1200)
