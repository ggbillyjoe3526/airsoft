"""The Range's skyline hulls (RQ2): the feed silo's drum and the derelict airliner fuselage, after the owner's photos
(art/references/maps/william-2026-11-09/skyline_buildings/silo and plane_fuselage). Built as skyline.py's other kinds
(its header: one vertex-coloured mesh, BODY faces take the piece's colour times their shade, Godot coordinates, the
front toward +Z); skyline.silo and skyline.fuselage delegate here.

Seen from 20 to 150 m: the silhouettes carry it (the silo's braced stand, caged ladder, fill pipes and roof rail; the
fuselage's drooped nose, torn-open rear, broken-off tail with its fin, wing roots and door ladder), then thin proud
strips and patches for the shading breakup (flanges, seams, door outlines, the cheat line, grime). Every proud patch
follows its hull's facets a set lift off them, so none lies in a plane with another (tools/coplanar_models.py).
"""

import math

from mathutils import Vector

import skyline as sk
import vertex_paint as vp


def _godot(b: Vector) -> Vector:
    """A Blender point or direction back in Godot space (the inverse of Model.g)."""
    return Vector((b.x, b.z, -b.y))


def _turn(faces: list, wants: list, smooth: bool) -> None:
    """Turns each face toward its wanted Blender direction, shaded smooth or flat."""
    for f, want in zip(faces, wants):
        f.normal_update()
        if want.length > 1e-9 and f.normal.dot(want) < 0.0:
            f.normal_flip()
        f.smooth = smooth


def _sheet(m: sk.Model, rows: list, mats, wants, smooth: bool = True, closed: bool = False) -> list:
    """Quads between rows of Godot points (each row the same count) sharing their corners, so a curve shades round.
    `mats(span, k)` names a quad's colour, `wants(span, k)` the Godot direction it faces. Returns its corners."""
    bm = m.b.bm
    vs = [[bm.verts.new(m.g(p)) for p in row] for row in rows]
    n = len(rows[0])
    faces, turns = [], []
    for s, (a, b) in enumerate(zip(vs, vs[1:])):
        for i in range(n if closed else n - 1):
            j = (i + 1) % n
            f = bm.faces.new((a[i], a[j], b[j], b[i]))
            f.material_index = m.b.mat(mats(s, i))
            faces.append(f)
            turns.append(m.g(wants(s, i)))
    _turn(faces, turns, smooth)
    return vs


def _lathe(m: sk.Model, profile: list, mat: str, sides: int, centre=(0.0, 0.0, 0.0), cap: bool = True) -> None:
    """Model.lathe with its ends capped (a profile ending at a radius closes there instead of leaving a hole)."""
    cx, cy, cz = centre
    vp.lathe(m.b, [(h + cy, r) for h, r in profile], mat, sides, (cx, -cz, 0.0), "z", cap=cap)


def _cyl(r: float, sides: int, phi: float, y: float, lift: float = 0.0) -> tuple:
    """A point on a lathed drum's facets (radius `r` at its corners, `sides` of them, the first at phi 0; phi in
    degrees, 90 toward +Z), `lift` m off its facet."""
    step = 360.0 / sides
    k = math.floor(phi / step)
    u = phi / step - k
    a, b = math.radians(k * step), math.radians((k + 1) * step)
    mid = (a + b) * 0.5
    x = r * (math.cos(a) * (1.0 - u) + math.cos(b) * u) + lift * math.cos(mid)
    z = r * (math.sin(a) * (1.0 - u) + math.sin(b) * u) + lift * math.sin(mid)
    return (x, y, z)


def _cyl_patch(m: sk.Model, r: float, sides: int, phi0: float, phi1: float, y0: float, y1: float, mat: str,
               lift: float) -> None:
    """A band on a drum's facets from phi0 to phi1 (degrees) and y0 to y1, `lift` m proud, a face a facet."""
    step = 360.0 / sides
    cuts = [phi0] + [k * step for k in range(math.floor(phi0 / step) + 1, math.ceil(phi1 / step))] + [phi1]
    for a, b in zip(cuts, cuts[1:]):
        mid = math.radians((a + b) * 0.5)
        out = (math.cos(mid), 0.0, math.sin(mid))
        m.face([_cyl(r, sides, a, y0, lift), _cyl(r, sides, b, y0, lift), _cyl(r, sides, b, y1, lift),
                _cyl(r, sides, a, y1, lift)], mat, out)


# ------------------------------------------------------------------------------------------------------------- silo

def silo() -> sk.Model:
    """One drum of a feed silo row (photos 103739, 103745, 103753, 103821: a GRP drum banded by flanges on a conical
    hopper, the hopper on a galvanised four-leg stand with two tiers of cross braces and a base frame on footings, a
    low cone roof with its manway hatch, vent and edge rail, the fill pipe and its vent pipe climbing the side and
    turning over into the roof, a caged ladder to the roof, an auger from the outlet). 6 m across, 15 m tall; the
    game stands one a drum along the row, the row's walkway over their tops. The ladder stands back-right, the pipes
    front-left and the auger front-right, so a row reads from either side."""
    m = sk.Model("silo", {
        "drum": (1.0, vp.BODY), "drum_b": (0.95, vp.BODY), "flange": (0.8, vp.BODY), "roof": (0.92, vp.BODY),
        "hopper": (0.84, vp.BODY), "seam": (0.86, vp.BODY),
        "galv": (sk.GALV, vp.FIXED), "galv_dark": (0x7E8488, vp.FIXED), "steel": (0x60666A, vp.FIXED),
        "concrete": (sk.CONCRETE, vp.FIXED), "hatch": (0x8E9397, vp.FIXED), "label": (0xE9E7E0, vp.FIXED),
        "glass": (sk.GLASS, vp.FIXED),
    })
    r = 2.9
    sides = 32
    hop_low, hop_top = 2.9, 6.35          # the hopper's outlet and its top under the skirt ring
    drum_low, drum_top = 6.8, 13.45
    # --- the drum: six courses in two shades, banded by two flanges, on a galvanised skirt ring
    courses = [(6.8, 7.9), (7.9, 9.06), (9.06, 10.18), (10.18, 11.31), (11.31, 12.4), (12.4, drum_top)]
    for i, (y0, y1) in enumerate(courses):
        _lathe(m, [(y0, r), (y1, r)], "drum" if i % 2 == 0 else "drum_b", sides, cap=False)
    for y in (9.0, 11.25):
        _lathe(m, [(y - 0.06, r), (y + 0.06, r + 0.075), (y + 0.18, r)], "flange", sides, cap=False)
    _lathe(m, [(hop_top, r - 0.16), (hop_top, r + 0.08), (drum_low, r + 0.08), (drum_low, r - 0.02)], "galv",
           24, cap=False)
    # vertical seams, a level gauge, the maker's plate (no writing) and three sight glasses on the front
    for phi in (22.0, 112.0, 202.0, 292.0):
        _cyl_patch(m, r, sides, phi - 0.8, phi + 0.8, drum_low + 0.02, drum_top - 0.02, "seam", 0.012)
    m.tube(_cyl(r, sides, 64.0, 7.1, 0.12), _cyl(r, sides, 64.0, 13.2, 0.12), 0.025, 0.025, 4, "galv_dark")
    for y in (7.1, 13.2):
        m.tube(_cyl(r, sides, 64.0, y, 0.0), _cyl(r, sides, 64.0, y, 0.13), 0.02, 0.02, 4, "galv_dark")
    _cyl_patch(m, r, sides, 79.0, 101.0, 12.45, 13.05, "label", 0.02)
    for y in (8.2, 10.6):
        _cyl_patch(m, r, sides, 88.0, 92.0, y, y + 0.2, "glass", 0.02)
    # --- the roof: an eave lip, a low cone, the manway hatch on top, a mushroom vent and a manway box
    _lathe(m, [(drum_top, r), (drum_top, r + 0.09), (drum_top + 0.15, r + 0.09), (drum_top + 0.21, r - 0.04),
               (14.15, 1.75), (14.5, 0.62)], "roof", sides, cap=False)
    _lathe(m, [(14.42, 0.62), (14.8, 0.62), (14.8, 0.7), (14.88, 0.7), (14.95, 0.3)], "hatch", 16)

    def roof_y(rad):
        return drum_top + 0.21 + (r - 0.04 - rad) / (r - 0.04 - 1.75) * (14.15 - drum_top - 0.21)

    vx, vz = 1.5 * math.cos(math.radians(200.0)), 1.5 * math.sin(math.radians(200.0))
    vy = roof_y(1.5)
    _lathe(m, [(vy - 0.15, 0.11), (vy + 0.38, 0.11), (vy + 0.38, 0.26), (vy + 0.47, 0.26), (vy + 0.52, 0.08)],
           "galv", 8, (vx, 0.0, vz))
    # --- the hopper, its outlet spout and slide gate
    _lathe(m, [(hop_low, 0.36), (hop_top + 0.05, r - 0.1)], "hopper", 24, cap=False)
    _lathe(m, [(hop_low + 0.05, 0.43), (hop_low - 0.2, 0.43), (hop_low - 0.2, 0.3), (hop_low - 0.75, 0.3)],
           "galv_dark", 12)
    m.box((-0.45, hop_low - 0.48, -0.25), (0.45, hop_low - 0.3, 0.25), "steel")
    # --- the stand: four legs on footings, a base frame, a mid girt, cross braces in two tiers
    lr = 2.95 / math.sqrt(2.0)
    legs = [(lr, lr), (-lr, lr), (-lr, -lr), (lr, -lr)]
    girts = (0.55, 3.9, hop_top - 0.05)
    for x, z in legs:
        m.box((x - 0.32, 0.0, z - 0.32), (x + 0.32, 0.3, z + 0.32), "concrete")
        m.tube((x, 0.3, z), (x, drum_low - 0.05, z), 0.16, 0.16, 4, "galv")
    for (xa, za), (xb, zb) in zip(legs, legs[1:] + legs[:1]):
        m.tube((xa, girts[0], za), (xb, girts[0], zb), 0.12, 0.12, 4, "galv_dark")
        m.tube((xa, girts[1], za), (xb, girts[1], zb), 0.09, 0.09, 4, "galv")
        for y0, y1 in zip(girts, girts[1:]):
            m.tube((xa, y0 + 0.1, za), (xb, y1 - 0.1, zb), 0.05, 0.05, 4, "galv")
            m.tube((xb, y0 + 0.1, zb), (xa, y1 - 0.1, za), 0.05, 0.05, 4, "galv")
    # --- the auger out of the outlet, front-right, to its boot on the ground
    m.tube((0.0, hop_low - 0.6, 0.0), (2.45, 0.45, 0.9), 0.11, 0.11, 8, "galv_dark", caps=(True, False))
    m.box((2.2, 0.0, 0.62), (2.72, 0.5, 1.18), "steel")
    m.box((0.12, hop_low - 0.95, -0.2), (0.5, hop_low - 0.6, 0.2), "steel")
    # --- the fill pipe (front-left, off the leg) and its vent pipe, each turning over into the roof
    _gooseneck(m, 125.0, 3.22, 0.1, 0.75, 14.35, 0.55, (2.0, 4.6), roof_y, legs[1])
    _gooseneck(m, 147.0, 3.16, 0.07, 1.35, 14.25, 0.4, (), roof_y, None, -1.0, 6)
    # --- the caged ladder, back-right, to a rail on the roof's edge
    _ladder(m, -45.0, r, drum_top, roof_y)
    return m


def _gooseneck(m: sk.Model, phi: float, rad: float, pr: float, y_low: float, y_bend: float, bend: float,
               leg_clamps: tuple, roof_y, leg, turn: float = 1.0, sides: int = 8) -> None:
    """A pipe at angle `phi` (degrees, 90 toward +Z) `rad` m out, from y_low up to y_bend, then over an arc of
    radius `bend` toward the middle and down into the roof; its foot turned along the wall to an open coupling,
    clamped to the drum and (below it) to a leg."""
    d = Vector((math.cos(math.radians(phi)), 0.0, math.sin(math.radians(phi))))
    tg = Vector((-d.z, 0.0, d.x))

    def at(rr, y, t=0.0):
        p = d * rr + tg * t
        return (p.x, y, p.z)

    m.tube(at(rad, y_low), at(rad, y_bend), pr, pr, sides, "galv")
    centre = rad - bend
    prev = at(rad, y_bend)
    steps = 10 if sides >= 8 else 8
    for i in range(1, steps + 1):
        a = math.pi * i / steps
        cur = at(centre + bend * math.cos(a), y_bend + bend * math.sin(a))
        m.tube(prev, cur, pr, pr, sides, "galv")
        prev = cur
    end = rad - 2.0 * bend
    m.tube(prev, at(end, roof_y(end) - 0.1), pr, pr, sides, "galv")
    m.tube(at(end, roof_y(end) - 0.05), at(end, roof_y(end) + 0.18), pr * 1.5, pr * 1.5, sides, "galv_dark",
           caps=(False, True))
    # the foot: an elbow along the wall to a coupling
    foot = at(rad, y_low, 0.0)
    out = at(rad, y_low - 0.25, 0.45 * turn)
    m.tube(foot, out, pr, pr, sides, "galv")
    m.tube(out, at(rad, y_low - 0.33, 0.6 * turn), pr * 1.35, pr * 1.35, sides, "galv_dark", caps=(False, True))
    for y in (7.6, 10.0, 12.4):
        m.tube(at(2.9, y), at(rad - pr, y), 0.035, 0.035, 4, "galv_dark")
        m.tube(at(rad, y - 0.06), at(rad, y + 0.06), pr * 1.35, pr * 1.35, sides, "galv_dark")
    for y in leg_clamps:
        m.tube(at(rad, y), (leg[0], y, leg[1]), 0.04, 0.04, 4, "galv_dark")


def _ladder(m: sk.Model, phi: float, r: float, drum_top: float, roof_y) -> None:
    """A caged ladder at angle `phi` (degrees) up the drum from the ground, its stiles turning over the eave onto the
    roof, a short guard rail along the roof's edge either side of it."""
    d = Vector((math.cos(math.radians(phi)), 0.0, math.sin(math.radians(phi))))
    tg = Vector((-d.z, 0.0, d.x))

    def at(rr, y, t=0.0):
        p = d * rr + tg * t
        return (p.x, y, p.z)

    rad, half = 3.2, 0.23
    for t in (-half, half):
        m.tube(at(rad, 0.0, t), at(rad, 14.4, t), 0.035, 0.035, 4, "galv")
        m.tube(at(rad, 14.4, t), at(2.75, 14.6, t), 0.03, 0.03, 4, "galv")
        m.tube(at(2.75, 14.6, t), at(2.45, roof_y(2.45) - 0.05, t), 0.03, 0.03, 4, "galv")
        for y in (7.6, 10.0, 12.4):
            m.tube(at(2.9, y, t), at(rad, y, t), 0.03, 0.03, 4, "galv_dark")
        for y in (1.2, 4.6):
            m.tube(at(2.95, y, t * 0.3), at(rad, y, t), 0.03, 0.03, 4, "galv_dark")
    y = 0.35
    while y < drum_top:
        m.tube(at(rad, y, -half), at(rad, y, half), 0.022, 0.022, 3, "galv")
        y += 0.4
    # the cage: hoops every metre from 2.5 m, five straps up them
    hoop = [(rad, -0.25), (3.62, -0.4), (4.0, 0.0), (3.62, 0.4), (rad, 0.25)]
    y0, y1 = 2.5, 14.3
    n = 9
    for i in range(n):
        y = y0 + (y1 - y0) * i / (n - 1)
        for (ra, ta), (rb, tb) in zip(hoop, hoop[1:]):
            m.tube(at(ra, y, ta), at(rb, y, tb), 0.035, 0.035, 4, "galv")
    for rr, t in hoop[1:-1]:
        m.tube(at(rr, y0, t), at(rr, y1, t), 0.03, 0.03, 4, "galv")
    # the roof-edge guard rail, from the ladder round either side
    rail_r = 2.62
    posts = (-34.0, -17.0, 17.0, 34.0)
    for a in posts:
        q = Vector((math.cos(math.radians(phi + a)), 0.0, math.sin(math.radians(phi + a)))) * rail_r
        base = roof_y(rail_r) - 0.05
        m.tube((q.x, base, q.z), (q.x, base + 1.05, q.z), 0.03, 0.03, 4, "galv")
    for s in (-1.0, 1.0):
        arc = [s * a for a in (8.0, 17.0, 25.5, 34.0)]
        for a0, a1 in zip(arc, arc[1:]):
            pa = Vector((math.cos(math.radians(phi + a0)), 0.0, math.sin(math.radians(phi + a0)))) * rail_r
            pb = Vector((math.cos(math.radians(phi + a1)), 0.0, math.sin(math.radians(phi + a1)))) * rail_r
            for h in (1.0,):
                y = roof_y(rail_r) - 0.05 + h
                m.tube((pa.x, y, pa.z), (pb.x, y, pb.z), 0.025, 0.025, 4, "galv")
    # the manway box beside the ladder's top
    c = d * 1.55
    yb = roof_y(1.55)
    m.box((c.x - 0.28, yb - 0.25, c.z - 0.28), (c.x + 0.28, yb + 0.22, c.z + 0.28), "hatch")


# --------------------------------------------------------------------------------------------------------- fuselage

class Hull:
    """A lofted round hull along X through stations (x, half-height, half-width, axis drop), `sides` facets round,
    the first corner `t0` degrees up from +Z (angles run up over the top toward -Z), turned `yaw` degrees about the
    vertical through `pivot` (x, z). Patches laid on its facets follow them `lift` m out."""

    def __init__(self, m: sk.Model, cy: float, stations: list, sides: int, t0: float, yaw: float = 0.0,
                 pivot=(0.0, 0.0)):
        self.m, self.cy, self.st, self.sides, self.t0 = m, cy, sorted(stations), sides, t0
        self.step = 360.0 / sides
        self.yaw = math.radians(yaw)
        self.pivot = pivot

    def put(self, p) -> tuple:
        """A local point turned into place."""
        if self.yaw == 0.0:
            return tuple(p)
        x, z = p[0] - self.pivot[0], p[2] - self.pivot[1]
        c, s = math.cos(self.yaw), math.sin(self.yaw)
        return (self.pivot[0] + x * c + z * s, p[1], self.pivot[1] - x * s + z * c)

    def turn(self, v) -> tuple:
        c, s = math.cos(self.yaw), math.sin(self.yaw)
        return (v[0] * c + v[2] * s, v[1], -v[0] * s + v[2] * c)

    def section(self, x: float) -> tuple:
        st = self.st
        if x <= st[0][0]:
            return st[0][1:]
        for a, b in zip(st, st[1:]):
            if x <= b[0]:
                u = (x - a[0]) / (b[0] - a[0])
                return tuple(a[i] + (b[i] - a[i]) * u for i in (1, 2, 3))
        return st[-1][1:]

    def corner(self, x: float, k: int, shrink: float = 0.0) -> Vector:
        ry, rz, dy = self.section(x)
        t = math.radians(self.t0 + k * self.step)
        return Vector((x, self.cy + dy + (ry - shrink) * math.sin(t), (rz - shrink) * math.cos(t)))

    def surf(self, x: float, t: float) -> Vector:
        """The faceted skin at x, angle t (degrees), local."""
        k = math.floor((t - self.t0) / self.step)
        u = (t - self.t0) / self.step - k
        return self.corner(x, k) * (1.0 - u) + self.corner(x, k + 1) * u

    def normal(self, x: float, t: float) -> Vector:
        h, dt = 0.05, 0.5
        along = self.surf(x + h, t) - self.surf(x - h, t)
        round_ = self.surf(x, t + dt) - self.surf(x, t - dt)
        n = round_.cross(along)
        _, _, dy = self.section(x)
        out = self.surf(x, t) - Vector((x, self.cy + dy, 0.0))
        if n.dot(out) < 0.0:
            n = -n
        return n.normalized()

    def skin(self, xs: list, mats, tip=None, jag=None) -> None:
        """The hull's skin through rings at `xs` (the first ring's corners pushed along X by `jag(k)`: a torn edge),
        `mats(span, k)` naming each quad's colour; closed to a point at `tip` (local) when given."""
        m = self.m
        rows = []
        for i, x in enumerate(xs):
            ring = []
            for k in range(self.sides):
                ring.append(self.put(self.corner(x + (jag(k) if i == 0 and jag is not None else 0.0), k)))
            rows.append(ring)

        def wants(s, k):
            x = (xs[s] + xs[s + 1]) * 0.5
            _, _, dy = self.section(x)
            mid = (self.corner(x, k) + self.corner(x, k + 1)) * 0.5
            return self.turn((0.0, mid.y - self.cy - dy, mid.z))

        vs = _sheet(m, rows, mats, wants, smooth=True, closed=True)
        if tip is not None:
            bm = m.b.bm
            last = vs[-1]   # shared with the skin, so the tip shades on round without a crease
            apex = bm.verts.new(m.g(self.put(tip)))
            faces, turns = [], []
            for k in range(self.sides):
                f = bm.faces.new((last[k], last[(k + 1) % self.sides], apex))
                f.material_index = m.b.mat(mats(len(xs) - 1, k))
                faces.append(f)
                turns.append(m.g(self.turn((1.0, 0.0, 0.0))))
            _turn(faces, turns, True)

    def cut(self, x: float, jag, inner: float, depth: float, rim: str, lining: str, end: str) -> None:
        """An open end at x (torn by `jag(k)`): a rim `inner` m thick, the lining inside running `depth` m into the
        hull (negative: toward -X), closed there by a dark bulkhead facing the opening."""
        m = self.m
        n = self.sides
        sgn = 1.0 if depth > 0.0 else -1.0
        for k in range(n):
            j = (k + 1) % n
            a, b = self.corner(x + jag(k), k), self.corner(x + jag(j), j)
            ai, bi = self.corner(x + jag(k), k, inner), self.corner(x + jag(j), j, inner)
            m.face([self.put(a), self.put(b), self.put(bi), self.put(ai)], rim, self.turn((-sgn, 0.0, 0.0)))
        rows = []
        for i, xx in enumerate((x, x + depth)):
            ring = []
            for k in range(n):
                ring.append(self.put(self.corner(xx + (jag(k) if i == 0 else 0.0), k, inner)))
            rows.append(ring)

        def wants(s, k):
            xm = x + depth * 0.5
            _, _, dy = self.section(xm)
            mid = (self.corner(xm, k) + self.corner(xm, k + 1)) * 0.5
            return self.turn((0.0, self.cy + dy - mid.y, -mid.z))

        _sheet(m, rows, lambda s, k: lining, wants, smooth=True, closed=True)
        m.face(rows[-1], end, self.turn((-sgn, 0.0, 0.0)))

    def patch(self, x0: float, x1: float, t0: float, t1: float, mat: str, lift: float) -> None:
        """A patch on the skin from x0 to x1 and t0 to t1 degrees, `lift` m proud, its corners shared so it shades
        as round as the skin."""
        xs = [x0] + [s[0] for s in self.st if x0 < s[0] < x1] + [x1]
        k0 = math.floor((t0 - self.t0) / self.step) + 1
        k1 = math.ceil((t1 - self.t0) / self.step)
        ts = [t0] + [self.t0 + k * self.step for k in range(k0, k1)] + [t1]
        rows = [[self.put(self.surf(x, t) + self.normal(x, t) * lift) for t in ts] for x in xs]

        def wants(s, k):
            return self.turn(self.normal((xs[s] + xs[s + 1]) * 0.5, (ts[k] + ts[k + 1]) * 0.5))

        _sheet(self.m, rows, lambda s, k: mat, wants, smooth=True)

    def t_at(self, x: float, y: float) -> float:
        """The angle (degrees, on the +Z side) at which the skin at x stands `y` m over the hull's axis line."""
        ry, _, dy = self.section(x)
        return math.degrees(math.asin(max(-1.0, min(1.0, (y - dy) / ry))))

    def quad(self, corners: list, mat: str, lift: float, nx: int = 3) -> None:
        """A patch over the skin between four (x, t degrees) corners (aft-low, fore-low, fore-high, aft-high), a grid
        laid on the facets `lift` m proud, its corners shared."""
        span = max(abs(corners[3][1] - corners[0][1]), abs(corners[2][1] - corners[1][1]))
        nt = max(2, math.ceil(span / 6.0))

        def at(a, b):
            lo = [corners[0][i] + (corners[1][i] - corners[0][i]) * a for i in (0, 1)]
            hi = [corners[3][i] + (corners[2][i] - corners[3][i]) * a for i in (0, 1)]
            return lo[0] + (hi[0] - lo[0]) * b, lo[1] + (hi[1] - lo[1]) * b

        grid = [[at(i / nx, j / nt) for j in range(nt + 1)] for i in range(nx + 1)]
        rows = [[self.put(self.surf(x, t) + self.normal(x, t) * lift) for x, t in row] for row in grid]

        def wants(s, k):
            x, t = at((s + 0.5) / nx, (k + 0.5) / nt)
            return self.turn(self.normal(x, t))

        _sheet(self.m, rows, lambda s, k: mat, wants, smooth=True)

    def pane(self, x: float, t: float, w: float, h: float, mat: str, lift: float) -> None:
        """A small rounded window (an octagon) centred at x, t (degrees), `w` m along and `h` m round."""
        ry, rz, _ = self.section(x)
        dt = math.degrees(h / max(ry, rz))
        c = 0.3
        pts = []
        for u, v in ((-0.5 + c * 0.5, -0.5), (0.5 - c * 0.5, -0.5), (0.5, -0.5 + c), (0.5, 0.5 - c),
                     (0.5 - c * 0.5, 0.5), (-0.5 + c * 0.5, 0.5), (-0.5, 0.5 - c), (-0.5, -0.5 + c)):
            xx, tt = x + u * w, t + v * dt
            pts.append(self.put(self.surf(xx, tt) + self.normal(xx, tt) * lift))
        self.m.face(pts, mat, self.turn(self.normal(x, t)))


# How far each kind of patch stands off the skin, m: each its own plane, the later over the earlier.
GRIME, DOOR_SKIN, STRIPE, GLASS_LIFT, FRAME, VOID = 0.008, 0.013, 0.018, 0.023, 0.028, 0.033
# The nose: its length from the full section to the radome's tip (0.8 of the diameter, photo 103958), the tip's
# height off the axis (the droop), and the stations along it (shares of its length; closer toward the round tip).
NOSE_LONG, NOSE_TIP = 3.6, -0.6
NOSE_STEPS = (0.0, 0.12, 0.24, 0.36, 0.48, 0.6, 0.7, 0.79, 0.87, 0.94, 0.99)


def _nose_station(x0: float, length: float, r: float, u: float) -> tuple:
    """A nose station (x, half-height, half-width, axis drop) `u` of the way along it: the crown falls steadily over
    the windscreen to the tip, the keel runs on nearly level and turns up under it, the sides close in round."""
    top = NOSE_TIP + (r - NOSE_TIP) * (1.0 - u ** 1.7) ** 0.62
    bot = NOSE_TIP - (r + NOSE_TIP) * (1.0 - u ** 2.6) ** 0.5
    return (x0 + length * u, (top - bot) * 0.5, r * (1.0 - u ** 2.0) ** 0.55, (top + bot) * 0.5)


# How far the broken-off tail lies turned off the body's line, degrees.
TAIL_YAW = 6.0


def fuselage() -> sk.Model:
    """A derelict airliner fuselage (photos 103958, 104010, 104028, 104040): off-white, weathered, lying low on
    sleeper cribs; a tapered, drooped radome nose with a low band of cockpit panes, a long row of
    rounded windows over a two-stripe cheat line, the lower body a shade greyer, panel seams, closed doors and
    overwing exits outlined, the forward port door gone dark with a ladder up to it, the wing roots cut off short on
    their belly fairing; the rear section torn open (the cabin's seats and floor inside, bare frames past the skin)
    and the tail broken off behind it, lying askew with its fin and stub tailplanes. 24 m long (X, the nose toward
    +X), 4.45 m across, the fin's top 9 m up; the port side (-Z, the doors and the ladder) faces the field."""
    m = sk.Model("fuselage", {
        "skin": (1.0, vp.BODY), "skin_b": (0.94, vp.BODY), "grime": (0.86, vp.BODY), "belly": (0.87, vp.BODY),
        "seam": (0.66, vp.BODY),
        "glass": (0x2A2D30, vp.FIXED), "void": (0x17191A, vp.FIXED), "frame": (0x45484B, vp.FIXED),
        "lining": (0x4E504B, vp.FIXED), "floor": (0x5B5A52, vp.FIXED), "seat": (0x5A555B, vp.FIXED),
        "stripe": (0x7E2046, vp.FIXED), "stripe2": (0x4A2F55, vp.FIXED), "dirt": (0x6B665A, vp.FIXED),
        "moss": (0x5C6248, vp.FIXED), "timber": (0x625A52, vp.FIXED), "ladder": (0x857868, vp.FIXED),
        "alu": (sk.GALV, vp.FIXED),
    })
    R = 2.2
    cy = 0.42 + R
    sides = 32
    t0 = 90.0 - 15 * 360.0 / sides * 0.5     # corners symmetric about the top; the window band one facet
    win_lo, win_hi = t0, t0 + 360.0 / sides  # 5.6 to 16.9 degrees: the window facet
    nose_x = 8.4
    nose = [_nose_station(nose_x, NOSE_LONG, R, u) for u in NOSE_STEPS]
    body = Hull(m, cy, [(-8.0, R, R, 0.0)] + nose, sides, t0)
    cut_x = -4.6

    def jag(k):
        """The torn rear edge: lower at the bottom, ragged."""
        t = math.radians(t0 + k * body.step)
        return -0.5 * math.sin(t) + (0.16, -0.08, 0.1, -0.14, 0.05, -0.04, 0.13)[k % 7]

    upper = set(range(16)) | {sides - 1}   # from the cheat line's facet over the top to the other's

    def mats(s, k):
        return "skin" if k in upper else "belly"

    body.skin([cut_x] + [st[0] for st in nose], mats, tip=(nose_x + NOSE_LONG, cy + NOSE_TIP, 0.0), jag=jag)
    body.cut(cut_x, jag, 0.07, 3.6, "skin_b", "lining", "void")
    # the cabin seen through the tear: its floor running out past the skin, three rows of seats a side
    fy = cy - 0.75
    m.box((cut_x - 0.45, fy - 0.12, -1.98), (cut_x + 3.55, fy, 1.98), "floor")
    for x in (-2.4, -3.2, -4.0):
        for z0, z1 in ((-1.8, -0.4), (0.4, 1.8)):
            m.box((x - 0.25, fy, z0), (x + 0.25, fy + 0.45, z1), "seat")
            m.box((x - 0.36, fy + 0.45, z0), (x - 0.22, fy + 1.15, z1), "seat")
    # bare frames past the torn skin over the top, joined by stringers
    arc = [-8.0 + 196.0 * i / 18 for i in range(19)]
    for fx in (-5.35, -5.75):
        rows = []
        for t in arc:
            c, sn = math.cos(math.radians(t)), math.sin(math.radians(t))
            rows.append([(fx + dx, cy + (R - 0.03 - dr) * sn, (R - 0.03 - dr) * c)
                         for dr, dx in ((0.0, -0.04), (0.0, 0.04), (0.11, 0.04), (0.11, -0.04))])
        _sheet(m, rows, lambda s, k: "frame", lambda s, k: _frame_want(arc, s, k), smooth=False, closed=True)
        m.face(rows[0], "frame", (0.0, -0.2, 1.0))
        m.face(rows[-1], "frame", (0.0, -0.2, -1.0))
    # a sheet of skin peeled back off the tear on the port shoulder, curling out
    ks = range(7, 11)
    rows_out, rows_in = [], []
    for u in (0.0, 0.5, 1.0):
        ro, ri = [], []
        for k in ks:
            t = math.radians(t0 + k * body.step)
            x = cut_x + jag(k) + 0.05 - 0.75 * u
            for rr, row in ((R + 0.02 + 0.45 * u * u, ro), (R - 0.01 + 0.45 * u * u, ri)):
                row.append((x, cy + rr * math.sin(t), rr * math.cos(t)))
        rows_out.append(ro)
        rows_in.append(ri)

    def flap_out(s_, k, sign=1.0):
        t = math.radians(t0 + (ks[0] + k + 0.5) * body.step)
        return (0.0, sign * math.sin(t), sign * math.cos(t))

    _sheet(m, rows_out, lambda s_, k: "skin_b", flap_out)
    _sheet(m, rows_in, lambda s_, k: "lining", lambda s_, k: flap_out(s_, k, -1.0))
    _sheet(m, [rows_out[-1], rows_in[-1]], lambda s_, k: "frame", lambda s_, k: (-1.0, 0.0, 0.0), smooth=False)
    for t in (40.0, 90.0, 140.0):
        c, sn = math.cos(math.radians(t)), math.sin(math.radians(t))
        m.tube((-4.7, cy + (R - 0.06) * sn, (R - 0.06) * c), (-5.8, cy + (R - 0.06) * sn, (R - 0.06) * c), 0.035,
               0.035, 4, "frame")
    _fuselage_livery(m, body, cut_x, nose_x, win_lo, win_hi)
    _fuselage_nose(m, body, win_lo)
    _fuselage_underside(m, body, cy, R)
    _fuselage_tail(m, cy, R, sides, t0, win_lo)
    # the ladder up to the open forward port door, leaning on its sill
    sill = cy - math.sin(math.radians(25.0)) * R
    for x in (7.38, 7.82):
        m.tube((x, 0.0, -2.19), (x, sill + 0.25, -2.07), 0.035, 0.035, 4, "ladder")
    for i in range(1, 6):
        y = i * 0.3
        z = -2.19 + 0.12 * y / (sill + 0.25)
        m.tube((7.38, y, z), (7.82, y, z), 0.024, 0.024, 3, "ladder")
    # sleeper cribs under the body
    for x in (-4.2, 1.2, 6.2):
        for z in (-0.95, 0.95):
            m.box((x - 1.1, 0.0, z - 0.12), (x + 1.1, 0.2, z + 0.12), "timber")
        for dx in (-0.75, 0.75):
            m.box((x + dx - 0.12, 0.2, -1.25), (x + dx + 0.12, 0.44, 1.25), "timber")
    return m


def _frame_want(arc: list, s: int, k: int) -> tuple:
    """A bare frame's quad faces at span s of its arc (degrees): out (k 0), aft (k 1, +X), in (k 2), fore (k 3)."""
    t = math.radians((arc[s] + arc[s + 1]) * 0.5)
    radial = (0.0, math.sin(t), math.cos(t))
    return [radial, (1.0, 0.0, 0.0), tuple(-c for c in radial), (-1.0, 0.0, 0.0)][k]


def _fuselage_livery(m: sk.Model, body: Hull, cut_x: float, nose_x: float, win_lo: float, win_hi: float) -> None:
    """Both sides' windows, cheat line, doors, exits, seams and grime."""
    for side in (1.0, -1.0):
        def ang(t, side=side):
            return t if side > 0.0 else 180.0 - t

        def band(x0, x1, ta, tb, mat, lift, ang=ang):
            a, b = sorted((ang(ta), ang(tb)))
            body.patch(x0, x1, a, b, mat, lift)

        # the two-stripe cheat line under the windows, sweeping on round the nose under the cockpit
        band(cut_x + 0.35, 10.9, -0.8, 4.8, "stripe", STRIPE)
        band(cut_x + 0.35, 10.9, -4.9, -2.4, "stripe2", STRIPE)
        # the doors: forward and aft each side, the forward port one gone (a dark opening, framed)
        fwd, aft = (7.15, 8.05), (-3.9, -3.05)
        for (x0, x1), gone in ((fwd, side < 0.0), (aft, False)):
            ta, tb = -25.0, 25.0
            fw = 0.05
            fdeg = math.degrees(fw / 2.2)
            if gone:
                band(x0, x1, ta, tb, "void", VOID)
                band(x0, x1, ta - fdeg * 1.6, ta, "alu", VOID)
            else:
                band(x0, x1, ta, tb, "skin_b", DOOR_SKIN)
                body.pane((x0 + x1) * 0.5, ang(14.0), 0.2, 0.26, "glass", GLASS_LIFT)
                band(x1 - 0.2, x1 - 0.08, -3.0, 1.0, "frame", FRAME)
            band(x0 - fw, x1 + fw, tb, tb + fdeg, "frame", FRAME)
            band(x0 - fw, x1 + fw, ta - fdeg, ta, "frame", FRAME)
            band(x0 - fw, x0, ta, tb, "frame", FRAME)
            band(x1, x1 + fw, ta, tb, "frame", FRAME)
        # overwing exits, outlined, each with its window
        for x0 in (0.15, 0.85):
            x1 = x0 + 0.5
            band(x0 - 0.03, x1 + 0.03, 22.0, 23.2, "frame", FRAME)
            band(x0 - 0.03, x1 + 0.03, win_lo - 4.2, win_lo - 3.0, "frame", FRAME)
            band(x0 - 0.03, x0, win_lo - 3.0, 22.0, "frame", FRAME)
            band(x1, x1 + 0.03, win_lo - 3.0, 22.0, "frame", FRAME)
        # the window row: 21 a side, skipping the doors and exits
        x = -2.55
        while x < 6.75:
            if not (0.05 < x < 1.45):
                body.pane(x, ang((win_lo + win_hi) * 0.5), 0.23, 0.32, "glass", GLASS_LIFT)
            x += 0.5
        for xe in (0.4, 1.1):
            body.pane(xe, ang((win_lo + win_hi) * 0.5), 0.23, 0.32, "glass", GLASS_LIFT)
        # rain streaks under the windows, grime along the crown and the waterline, moss along the ground
        for xs in (-2.9, -1.4, 2.3, 3.6, 5.1):
            band(xs, xs + 0.14, -12.0, -5.5, "grime", GRIME)
        for x0, x1, ta, tb, mat in ((-4.5, -1.0, 30.0, 50.0, "grime"), (2.0, 6.0, 25.0, 38.0, "grime"),
                                    (-3.9, 2.0, -48.0, -30.0, "dirt"), (3.0, 8.0, -52.0, -38.0, "dirt"),
                                    (-3.8, -1.5, -62.0, -52.0, "moss"), (4.5, 9.0, -64.0, -55.0, "moss")):
            band(x0, x1, ta, tb, mat, GRIME)
        # lap seams along the body
        band(cut_x + 0.45, nose_x - 0.3, 33.25, 34.25, "seam", FRAME)
        for x0, x1 in ((-2.95, 7.05), (8.15, nose_x + 1.2)):
            band(x0, x1, -17.4, -16.4, "seam", FRAME)
        # the forward hold's door, outlined low under the cheat line
        x0, x1, ta, tb = 4.4, 5.9, -46.0, -25.0
        band(x0, x1, ta - 1.3, ta, "frame", FRAME)
        band(x0, x1, tb, tb + 1.3, "frame", FRAME)
        band(x0 - 0.05, x0, ta - 1.3, tb + 1.3, "frame", FRAME)
        band(x1, x1 + 0.05, ta - 1.3, tb + 1.3, "frame", FRAME)
    # seams round the crown between the windows, a darker crown patch, and two blade antennas
    for xs in (-2.3, 0.0, 2.2, 4.7, 6.7):
        x = xs - 0.05 if xs != 0.0 else -0.1
        body.patch(x, x + 0.04, 27.0, 153.0, "seam", FRAME)
    body.patch(-1.8, 1.9, 62.0, 118.0, "grime", GRIME)
    for x in (-2.8, 3.2):
        top = body.cy + 2.2
        m.box((x - 0.18, top - 0.05, -0.03), (x + 0.18, top + 0.24, 0.03), "frame")


def _fuselage_nose(m: sk.Model, body: Hull, win_lo: float) -> None:
    """The cockpit (photo 103958): a band of panes 3 m long, 0.7 of the diameter, set low on the nose just over the
    window row: two side windows and the windscreen's side pane, then its front pane over the nose to the centre
    post, the skin between them their frames; the radome's seam ahead of them, the nose gear bay under it."""
    # side panes by (x, height over the axis) corners: aft-low, fore-low, fore-high, aft-high
    sides_ = (((8.3, 0.66), (8.85, 0.62), (8.9, 1.22), (8.36, 1.26)),
              ((9.0, 0.6), (9.75, 0.56), (9.72, 1.2), (9.05, 1.22)),
              ((9.9, 0.55), (10.78, 0.5), (10.7, 1.02), (9.95, 1.2)))
    for side in (1.0, -1.0):
        def ang(t, side=side):
            return t if side > 0.0 else 180.0 - t

        for pane in sides_:
            body.quad([(x, ang(body.t_at(x, y))) for x, y in pane], "glass", GLASS_LIFT)
        front = [(10.85, body.t_at(10.85, 0.5)), (11.3, body.t_at(11.3, 0.42)), (11.08, 87.5), (10.82, 87.5)]
        body.quad([(x, ang(t)) for x, t in front], "glass", GLASS_LIFT)
    body.patch(9.2, 10.4, 262.0, 278.0, "void", VOID)


def _fuselage_underside(m: sk.Model, body: Hull, cy: float, R: float) -> None:
    """The belly fairing under the wing roots and the roots themselves, cut off short, their torn ends dark."""
    n = 16
    arc = [175.0 + 190.0 * i / n for i in range(n + 1)]
    rows = []
    for x, s in ((-3.6, 0.55), (-2.4, 0.9), (2.6, 0.9), (3.9, 0.5)):
        ry, rz = 1.45 * s + 0.55 * (1.0 - s), 1.95 * s + 1.5 * (1.0 - s)
        oy = cy - 0.9
        rows.append([(x, oy + ry * math.sin(math.radians(t)), rz * math.cos(math.radians(t))) for t in arc])

    def wants(s, k):
        t = math.radians((arc[k] + arc[k + 1]) * 0.5)
        return (0.0, math.sin(t), math.cos(t))

    _sheet(m, rows, lambda s, k: "belly", wants, smooth=True)
    for sgn in (1.0, -1.0):
        y = cy - 1.3
        root = [(-1.4, 0.0), (-1.0, 0.16), (0.4, 0.2), (2.4, 0.04), (2.4, -0.04), (0.4, -0.15), (-1.0, -0.12)]
        rings = []
        for z, dx in ((sgn * 1.4, 0.0), (sgn * 2.2, 0.55)):
            rings.append([(x + dx, y + h, z) for x, h in root])
        _sheet(m, rings,
               lambda s, k: "belly", lambda s, k, rings=rings: _ring_out(rings[0], k), smooth=False, closed=True)
        m.face(rings[1], "void", (0.0, 0.0, sgn))
        m.face([(x + 0.55, y + h * 0.7, sgn * 2.205) for x, h in root[1:4]] +
               [(root[4][0] + 0.55, y + root[4][1] * 0.7, sgn * 2.205)], "frame", (0.0, 0.0, sgn))


def _ring_out(ring: list, k: int) -> tuple:
    """The outward direction of a closed section's edge k (in its own plane, away from its middle)."""
    n = len(ring)
    a, b = Vector(ring[k]), Vector(ring[(k + 1) % n])
    mid = sum((Vector(p) for p in ring), Vector()) / n
    return tuple((a + b) * 0.5 - mid)


def _fuselage_tail(m: sk.Model, cy: float, R: float, sides: int, t0: float, win_lo: float) -> None:
    """The broken-off tail: its cone lying askew behind the torn body, open at the front onto a dark bulkhead, the
    swept fin with its rudder and two-stripe livery, the dorsal fillet, stub tailplanes torn off short. Its tear
    runs back over the top and down the port side (toward the field), so the skin's thickness, the bare frames and
    stringers and the dark inside show from the side and above, as the body's own tear does."""
    front = -6.7
    tail = Hull(m, cy, [(front, R, R, 0.0), (-8.6, R * 0.88, R * 0.86, 0.25),
                        (-9.6, R * 0.72, R * 0.68, 0.55), (-10.5, R * 0.54, R * 0.5, 0.85),
                        (-11.3, R * 0.36, R * 0.33, 1.1), (-11.75, R * 0.24, R * 0.22, 1.24),
                        (-11.93, R * 0.15, R * 0.14, 1.3)],
                sides, t0, yaw=TAIL_YAW, pivot=(front, 0.0))

    def torn(t):
        """How far back the tear runs at angle t (degrees): deepest over the top and down the port side."""
        a = math.radians(t)
        return -(0.45 * (1.0 + math.sin(a)) - 0.75 * math.cos(a))

    def jag(k):
        return torn(t0 + k * tail.step) + (0.12, -0.13, 0.06, -0.08, 0.15, 0.0, -0.1)[k % 7]

    upper = set(range(16)) | {sides - 1}
    tail.skin([s[0] for s in reversed(tail.st)], lambda s, k: "skin" if k in upper else "belly", jag=jag)
    tail.cut(front, jag, 0.07, -1.85, "skin_b", "lining", "void")
    # bare frames where the skin has gone, stringers running out past the tear, broken off at different lengths
    for fx in (-7.2, -7.7):
        ts = [t0 + k * tail.step for k in range(sides + 1)]
        bare = [t for t in ts if front + torn(t) < fx - 0.1]
        if len(bare) < 2:
            continue
        ry, rz, dy = tail.section(fx)
        rows = []
        for t in bare:
            c, sn = math.cos(math.radians(t)), math.sin(math.radians(t))
            rows.append([tail.put((fx + dx, cy + dy + (ry - 0.04 - dr) * sn, (rz - 0.04 - dr) * c))
                         for dr, dx in ((0.0, -0.04), (0.0, 0.04), (0.12, 0.04), (0.12, -0.04))])

        def frame_want(s_, k, bare=bare):
            return tail.turn(_frame_want(bare, s_, k))

        _sheet(m, rows, lambda s_, k: "frame", frame_want, smooth=False, closed=True)
        m.face(rows[0], "frame", tail.turn((0.0, -0.3, 1.0)))
        m.face(rows[-1], "frame", tail.turn((0.0, -0.3, -1.0)))
    for t, reach in ((50.0, 0.25), (78.0, 0.55), (101.0, 0.35), (124.0, 0.6), (147.0, 0.3), (172.0, 0.5)):
        ry, rz, dy = tail.section(-7.9)
        c, sn = math.cos(math.radians(t)), math.sin(math.radians(t))
        y, z = cy + dy + (ry - 0.06) * sn, (rz - 0.06) * c
        m.tube(tail.put((-8.4, y, z)), tail.put((front + torn(t) + reach, y, z)), 0.035, 0.035, 4, "frame")
    # the APU exhaust closing the cone
    end = tail.st[0]
    m.face([tail.put(tail.corner(end[0], k)) for k in range(sides)], "frame", tail.turn((-1.0, 0.0, 0.0)))
    yaw = math.radians(TAIL_YAW)
    tip_x = front + (-12.0 - front + 0.12 * math.sin(yaw)) / math.cos(yaw)   # the exhaust's end on the bounds
    m.tube(tail.put((-11.8, cy + end[3], 0.0)), tail.put((tip_x, cy + end[3], 0.0)), 0.12, 0.12, 8, "void",
           caps=(False, True))
    for side in (1.0, -1.0):
        ta, tb = (-0.8, 4.8) if side > 0 else (175.2, 180.8)
        tail.patch(-9.2, -6.75 if side > 0 else -8.15, ta, tb, "stripe", STRIPE)
        ta, tb = (-4.9, -2.4) if side > 0 else (182.4, 184.9)
        tail.patch(-9.2, -6.75 if side > 0 else -8.15, ta, tb, "stripe2", STRIPE)
    # the fin: a swept airfoil from the cone's top to 9 m, the rudder behind its hinge
    root_y, top = cy + 1.7, 9.0
    root = (-8.0, -11.6, 0.2)     # leading edge, trailing edge, half-thickness
    tip = (-10.6, -11.95, 0.09)

    prof = [(0.0, 0.0), (0.1, 0.75), (0.35, 1.0), (0.68, 0.8)]
    sec_f = prof + [(0.68, -0.8), (0.35, -1.0), (0.1, -0.75)]
    sec_r = [(0.7, 0.75), (1.0, 0.08), (1.0, -0.08), (0.7, -0.75)]
    for sec, mat in ((sec_f, "skin"), (sec_r, "skin_b")):
        rings = []
        for (le, te, th), y in ((root, root_y), (tip, top)):
            rings.append([tail.put((le + (te - le) * f, y, th * h)) for f, h in sec])
        _sheet(m, rings, lambda s, k, mat=mat: mat, lambda s, k, rings=rings: _ring_out(rings[0], k), smooth=False,
               closed=True)
        m.face(rings[1], "frame" if mat == "skin" else "skin_b", (0.0, 1.0, 0.0))
    # the fin's livery: the cheat line's two stripes across it, low, and a dark tip
    for y0, y1, mat in ((5.6, 6.3, "stripe"), (6.45, 6.75, "stripe2")):
        for side in (1.0, -1.0):
            for (fa, ha), (fb, hb) in zip(prof, prof[1:]):
                pts = []
                for y, (f, h) in ((y0, (fa, ha)), (y0, (fb, hb)), (y1, (fb, hb)), (y1, (fa, ha))):
                    u = (y - root_y) / (top - root_y)
                    le = root[0] + (tip[0] - root[0]) * u
                    te = root[1] + (tip[1] - root[1]) * u
                    th = root[2] + (tip[2] - root[2]) * u
                    pts.append(tail.put((le + (te - le) * f, y, (th * h + STRIPE) * side)))
                m.face(pts, mat, tail.turn((0.0, 0.0, side)))
    # the dorsal fillet running into the fin's root
    for sgn in (1.0, -1.0):
        ridge = [tail.put((-7.95, cy + 2.2, 0.0)), tail.put((-8.6, cy + 2.8, 0.0))]
        foot = [tail.put((-7.95, cy + 2.16, sgn * 0.05)), tail.put((-8.6, cy + 2.05, sgn * 0.2))]
        m.face([ridge[0], ridge[1], foot[1], foot[0]], "skin", tail.turn((0.0, 0.4, sgn)))
    # stub tailplanes, torn off short
    for sgn in (1.0, -1.0):
        y = cy + 1.0
        foil = [(-9.9, 0.0), (-10.4, 0.11), (-11.4, 0.03), (-11.4, -0.03), (-10.4, -0.09)]
        rings = [[tail.put((x, y + h, sgn * z)) for x, h in foil] for z in (0.3, 1.65)]
        _sheet(m, rings, lambda s, k: "skin", lambda s, k, rings=rings: _ring_out(rings[0], k), smooth=False,
               closed=True)
        m.face(rings[1], "void", tail.turn((0.0, 0.0, sgn)))
    # sleepers under it: one under the torn front, a crib under the raised cone
    p = tail.put((-7.0, 0.0, 0.0))
    m.box((p[0] - 0.12, 0.0, -1.2), (p[0] + 0.12, 0.46, 1.2), "timber")
    p = tail.put((-8.4, 0.0, 0.0))
    for y0, y1, along in ((0.0, 0.3, True), (0.3, 0.6, False), (0.6, 0.88, True)):
        for d in (-0.55, 0.55):
            if along:
                m.box((p[0] - 0.75, y0, p[2] + d - 0.12), (p[0] + 0.75, y1, p[2] + d + 0.12), "timber")
            else:
                m.box((p[0] + d - 0.12, y0, p[2] - 0.8), (p[0] + d + 0.12, y1, p[2] + 0.8), "timber")
