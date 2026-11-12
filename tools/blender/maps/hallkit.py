"""Shared parts for Subway's ticket hall and concourse models (Dev 3, SM3): the station's paints, flat details laid
on a face (decals a hair proud of it), roller shutters, louvres and invented sign blocks, on top of prop.py's Prop.

Faces are named by the way they look: "-y" the model's front (PropLayout turns it to the field), "+y" its back, "-x"
and "+x" its ends, "+z" its top. A face's (u, v) run along it as a viewer facing it reads them: u to the right, v up
(on "+z", u along x and v along y). No real brand, logo or network's colours: signs are blocks of light and dark,
never words.

Dev tool: tools/ never ships.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402
from mathutils import Vector  # noqa: E402

# The station's paints (prop.PALETTE names): brushed stainless, moulded dark plastic, the dark slots and the gloss.
STAINLESS = "concrete*0.8"
STAINLESS_DARK = "concrete*0.64"
PLASTIC = "slab*0.58"
BLACK = "slab*0.32"
SLOT = "slab*0.22"
READER = "yellow*0.92"
GLASS = "seafoam*0.5"
SCREEN = "ink*0.55"
LABEL = "cream*0.95"
STICKER = "steel*0.72"


def _point(face: str, at: float, u: float, v: float) -> tuple:
    if face == "-y":
        return (u, at, v)
    if face == "+y":
        return (-u, at, v)
    if face == "+x":
        return (at, u, v)
    if face == "-x":
        return (at, -u, v)
    return (u, v, at)  # "+z"


def rect(p: prop.Prop, face: str, at: float, u0: float, u1: float, v0: float, v1: float, paint: str) -> list:
    """A flat rectangle on `face` at depth `at` (its coordinate across the face), u0..u1 by v0..v1, facing out."""
    return p.quad([_point(face, at, u, v) for u, v in ((u0, v0), (u1, v0), (u1, v1), (u0, v1))], paint)


def poly(p: prop.Prop, face: str, at: float, pts: list, paint: str) -> list:
    """A flat polygon on `face` through (u, v) points counter-clockwise as seen facing it."""
    return p.quad([_point(face, at, u, v) for u, v in pts], paint)


def disc(p: prop.Prop, face: str, at: float, cu: float, cv: float, r: float, paint: str, n: int = 12) -> list:
    return poly(p, face, at, [(cu + r * math.cos(2 * math.pi * i / n), cv + r * math.sin(2 * math.pi * i / n))
                              for i in range(n)], paint)


def slab(p: prop.Prop, face: str, at: float, depth: float, u0: float, u1: float, v0: float, v1: float,
         paint: str) -> list:
    """A box standing `depth` m out of `face` (at depth `at`) over u0..u1 by v0..v1."""
    a = [_point(face, at, u0, v0), _point(face, at + _out(face) * depth, u1, v1)]
    lo = tuple(min(a[0][i], a[1][i]) for i in range(3))
    hi = tuple(max(a[0][i], a[1][i]) for i in range(3))
    return p.box(lo, hi, paint)


def _out(face: str) -> float:
    return -1.0 if face in ("-y", "-x") else 1.0


def shutter(p: prop.Prop, face: str, at: float, u0: float, u1: float, v0: float, v1: float, paint: str,
            slat: float = 0.075, groove: str = "slab*0.45") -> None:
    """A roller shutter down over u0..v1: a dark backing and slats, each a shallow bulge out of it, a bottom rail
    with two lift handles. The slats stand up to 12 mm proud of `at`."""
    rect(p, face, at, u0, u1, v0, v1, groove)
    s = _out(face)
    rail = 0.06
    n = max(1, round((v1 - v0 - rail) / slat))
    h = (v1 - v0 - rail) / n
    for i in range(n):
        z0 = v0 + rail + i * h + 0.004
        z1 = z0 + h - 0.008
        zm = (z0 + z1) / 2
        prof = [(0.0, z0), (0.006, z0 + 0.004), (0.011, zm), (0.006, z1 - 0.004), (0.0, z1)]
        _bar(p, face, at, s, u0, u1, prof, paint)
    slab(p, face, at, 0.018, u0, u1, v0, v0 + rail, paint + "*0.92")
    for k in (0.25, 0.75):
        cu = u0 + (u1 - u0) * k
        slab(p, face, at + s * 0.018, 0.022, cu - 0.06, cu + 0.06, v0 + 0.02, v0 + 0.04, "rubber*1.2")


def _bar(p: prop.Prop, face: str, at: float, s: float, u0: float, u1: float, prof: list, paint: str) -> None:
    """A profile (out, v) swept across u0..u1 on `face`."""
    if face in ("-y", "+y"):
        x0, x1 = (u0, u1) if face == "-y" else (-u1, -u0)
        p.prism([(at + s * o, v) for o, v in prof], "x", x0, x1, paint)
    else:
        y0, y1 = (u0, u1) if face == "+x" else (-u1, -u0)
        p.prism([(at + s * o, v) for o, v in prof], "y", y0, y1, paint)


def louvre(p: prop.Prop, face: str, at: float, u0: float, u1: float, v0: float, v1: float, paint: str,
           n: int = 5) -> None:
    """A vent: a dark slot behind `n` hoods sloping down and out."""
    rect(p, face, at, u0, u1, v0, v1, SLOT)
    s = _out(face)
    h = (v1 - v0) / n
    for i in range(n):
        z = v0 + i * h + h * 0.15
        _bar(p, face, at, s, u0, u1, [(0.0, z), (0.008, z), (0.0, z + h * 0.8)], paint)


def lines(p: prop.Prop, face: str, at: float, u0: float, u1: float, v0: float, v1: float, paint: str,
          rows: int, lengths: tuple = (1.0, 0.8, 0.92, 0.6, 0.85)) -> None:
    """Rows of light 'print' (no words): bars of the lengths given in turn, filling u0..u1 by v0..v1 top down."""
    h = (v1 - v0) / rows
    for i in range(rows):
        top = v1 - i * h
        rect(p, face, at, u0, u0 + (u1 - u0) * lengths[i % len(lengths)], top - h * 0.55, top - h * 0.1, paint)


def tube(p: prop.Prop, pts: list, r: float, paint: str, sides: int = 6, caps: bool = True) -> list:
    """A round bar along a polyline of 3D points, its section carried round the bends (mitred)."""
    vs = [Vector(q) for q in pts]
    rings = []
    side = None
    for i, c in enumerate(vs):
        if i == 0:
            t = (vs[1] - vs[0]).normalized()
        elif i == len(vs) - 1:
            t = (vs[-1] - vs[-2]).normalized()
        else:
            t = ((vs[i] - vs[i - 1]).normalized() + (vs[i + 1] - vs[i]).normalized()).normalized()
        side = t.orthogonal().normalized() if side is None else (side - t * side.dot(t)).normalized()
        up = t.cross(side)
        k = 1.0
        if 0 < i < len(vs) - 1:
            k = 1.0 / max(0.4, (vs[i] - vs[i - 1]).normalized().dot(t))
        ring = []
        for j in range(sides):
            a = 2 * math.pi * j / sides
            d = side * math.cos(a) + up * math.sin(a)
            # a mitre stretches the section across the bend only, so it meets both legs
            ring.append(tuple(c + d * r + _mitre(d, vs, i) * r * (k - 1.0)))
        rings.append(ring)
    return p.loft(rings, paint, cap0=caps, cap1=caps)


def _mitre(d: Vector, vs: list, i: int) -> Vector:
    """The part of a section's offset `d` that a mitre at corner i stretches: along the bend's in-plane normal."""
    if i == 0 or i == len(vs) - 1:
        return Vector((0.0, 0.0, 0.0))
    a = (vs[i] - vs[i - 1]).normalized()
    b = (vs[i + 1] - vs[i]).normalized()
    n = b - a
    if n.length < 1e-6:
        return Vector((0.0, 0.0, 0.0))
    n.normalize()
    return n * d.dot(n)


def arc(c: tuple, r: float, a0: float, a1: float, n: int) -> list:
    """Points on a circle in the x-z plane round c (x, z), from angle a0 to a1 (radians), n steps."""
    return [(c[0] + r * math.cos(a0 + (a1 - a0) * i / n), c[1] + r * math.sin(a0 + (a1 - a0) * i / n))
            for i in range(n + 1)]


def plane_poly(p: prop.Prop, origin: tuple, u: tuple, v: tuple, pts: list, paint: str) -> list:
    """A flat polygon on any plane: (a, b) points at origin + a*u + b*v, counter-clockwise as seen from u x v."""
    o, uu, vv = Vector(origin), Vector(u), Vector(v)
    return p.quad([tuple(o + uu * a + vv * b) for a, b in pts], paint)


def circle_pts(cu: float, cv: float, r: float, n: int = 12) -> list:
    return [(cu + r * math.cos(2 * math.pi * i / n), cv + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
