"""The Range's skyline sheds (three sizes) and its watch tower, in the detail that reads from 20 to 150 m (RQ2, the
owner's photos in art/references/maps/william-2026-11-09/skyline_buildings/shed/ and watch_tower/). Built through
skyline.py (`python3 tools/blender/maps/skyline.py shed shed_long shed_deep watch_tower`), which delegates here; its
header holds the conventions (Godot coordinates, front toward +Z, BODY faces take the piece's colour).

The shed: box-profile cladding in proud trapezoid ribs over sheets a shade apart, a concrete plinth and dark base,
corner and verge flashings, a ribbed roof with rooflights and a ridge cap, gutters and swan-necked downpipes, roller
shutters (slats, guides, hood), personnel doors with lamps over them, framed windows with sills.
The watch tower: four braced legs on concrete footings (struts, crossed flat braces, gusset plates), three stair
flights with treads, stringers and handrails round the outside with two landings, a railed deck over a joist grid on
knee braces, a glazed cabin with a door, a ribbed hip roof, an antenna and a floodlight.
"""

import math
import random

import skyline as sk
import vertex_paint as vp
from mathutils import Vector

# ---------------------------------------------------------------------------------------------------------- helpers

FACES = ("+x", "-x", "+y", "-y", "+z", "-z")


def slab(m: sk.Model, lo, hi, mat, skip=()) -> None:
    """An axis-aligned box (Godot) without the faces named in `skip` ("+x" ... "-z": hidden against something); `mat`
    a colour, or a dict of colours by face with "" for the rest."""
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    quads = {
        "+x": [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)],
        "-x": [(x0, y0, z0), (x0, y1, z0), (x0, y1, z1), (x0, y0, z1)],
        "+y": [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)],
        "-y": [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)],
        "+z": [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
        "-z": [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)],
    }
    for k in FACES:
        if k in skip:
            continue
        out = [0.0, 0.0, 0.0]
        out["xyz".index(k[1])] = 1.0 if k[0] == "+" else -1.0
        colour = mat if isinstance(mat, str) else mat.get(k, mat[""])
        m.face(quads[k], colour, out)


def bar(m: sk.Model, p0, p1, a: float, b: float, mat: str, side=(0.0, 1.0, 0.0), caps=(True, True)) -> None:
    """A beam of rectangular section from `p0` to `p1` (Godot): half `a` along `side` (made square to the beam),
    half `b` across both."""
    p0, p1 = Vector(p0), Vector(p1)
    ax = (p1 - p0).normalized()
    e1 = Vector(side) - ax * ax.dot(Vector(side))
    if e1.length < 1e-6:
        e1 = Vector((1.0, 0.0, 0.0)) - ax * ax.x
    e1.normalize()
    e2 = ax.cross(e1)

    def ring(c):
        return [tuple(c + e1 * (sa * a) + e2 * (sb * b)) for sa, sb in ((1, 1), (-1, 1), (-1, -1), (1, -1))]
    m.rings([ring(p0), ring(p1)], mat, caps[0], caps[1])


class Wall:
    """A wall's frame: `key` "+z", "-z", "+x" or "-x" (its outside), its face `plane` m from the middle; u runs
    along it (x on a z wall, z on an x wall), v is height, w is out from its face."""

    def __init__(self, key: str, plane: float, half: float, top):
        sign = 1.0 if key[0] == "+" else -1.0
        self.key = key
        self.n = Vector((sign, 0.0, 0.0)) if key[1] == "x" else Vector((0.0, 0.0, sign))
        self.u = Vector((0.0, 0.0, 1.0)) if key[1] == "x" else Vector((1.0, 0.0, 0.0))
        self.plane = plane
        self.half = half
        self.top = top
        # the box faces by their place on the wall
        nk, uk = key[1], ("z" if key[1] == "x" else "x")
        self.names = {"front": key, "back": ("-" if sign > 0 else "+") + nk, "left": "-" + uk, "right": "+" + uk,
                      "bottom": "-y", "top": "+y"}

    def p(self, u: float, v: float, w: float = 0.0) -> tuple:
        return tuple(self.n * (self.plane + w) + self.u * u + Vector((0.0, v, 0.0)))

    def d(self, du: float, dw: float, dv: float = 0.0) -> tuple:
        return tuple(self.u * du + self.n * dw + Vector((0.0, dv, 0.0)))

    def quad(self, m: sk.Model, ua, ub, va, vb, w, mat, va_b=None, vb_b=None) -> None:
        """A face on the wall `w` out, u from ua to ub, v from va to vb (va_b, vb_b at ub if they differ)."""
        va_b = va if va_b is None else va_b
        vb_b = vb if vb_b is None else vb_b
        m.face([self.p(ua, va, w), self.p(ub, va_b, w), self.p(ub, vb_b, w), self.p(ua, vb, w)], mat, tuple(self.n))

    def box(self, m: sk.Model, ua, ub, va, vb, w0, w1, mat, skip=("back",)) -> None:
        a, c = Vector(self.p(ua, va, w0)), Vector(self.p(ub, vb, w1))
        lo = tuple(min(a[i], c[i]) for i in range(3))
        hi = tuple(max(a[i], c[i]) for i in range(3))
        slab(m, lo, hi, mat, tuple(self.names[s] for s in skip))


# ------------------------------------------------------------------------------------------------------------- shed

# The cladding's rib spacing (m) at each size, the closest to the real box profile's each budget allows; the roof's.
SHED_RIBS = {"shed": (0.34, 0.8), "shed_long": (0.55, 1.25), "shed_deep": (0.55, 1.2)}
RIB_BASE, RIB_OUT = 0.085, 0.05   # a wall rib's half width and how proud its crease stands
PAN_SHADES = ("clad_pan", "clad_pan", "clad_pan_b", "clad_pan_c")
DOOR_W, DOOR_H = 1.0, 2.15


def _ribs(half: float, s: float, margin: float = 0.3) -> list:
    """Rib middles along a wall from -half to half, symmetric, none on u = 0 (a gable's ridge)."""
    out = []
    u = s * 0.5
    while u < half - margin:
        out += [-u, u]
        u += s
    return sorted(out)


def _clad(m: sk.Model, wall: Wall, base: float, holes: list, s: float, rng: random.Random, gable: bool) -> None:
    """A wall's sheets between its ribs (each sheet a shade of its own) and the ribs, around `holes` (u0, u1, v0,
    v1)."""
    ribs = _ribs(wall.half, s)
    edges = {-wall.half, wall.half}
    edges.update(ribs[::2])
    if gable:
        edges.add(0.0)
    for u0, u1, _v0, _v1 in holes:
        edges.update((u0, u1))
    cuts = sorted(e for e in edges if -wall.half <= e <= wall.half)
    sheets = ribs[::2]
    shade = {k: rng.choice(PAN_SHADES) for k in range(len(sheets) + 1)}
    for a, b in zip(cuts, cuts[1:]):
        if b - a < 1e-4:
            continue
        mid = (a + b) * 0.5
        mat = shade[sum(1 for e in sheets if e <= mid)]
        over = sorted((h for h in holes if h[0] <= mid <= h[1]), key=lambda h: h[2])
        v = base
        for _u0, _u1, v0, v1 in over:
            if v0 > v + 1e-4:
                wall.quad(m, a, b, v, v0, 0.0, mat)
            v = max(v, v1)
        wall.quad(m, a, b, v, wall.top(a), 0.0, mat, None, wall.top(b))
    for c in ribs:
        ua, ub = c - RIB_BASE, c + RIB_BASE
        over = sorted((h for h in holes if h[0] < ub and h[1] > ua), key=lambda h: h[2])
        spans, v = [], base
        for _u0, _u1, v0, v1 in over:
            if v0 > v + 0.05:
                spans.append((v, v0))
            v = max(v, v1)
        spans.append((v, None))
        for v0, v1 in spans:
            def top(u, v1=v1):
                return wall.top(u) if v1 is None else v1
            for s0, s1, side in ((ua, c, -1.0), (c, ub, 1.0)):
                if side < 0:
                    pts = [wall.p(s0, v0, 0.0), wall.p(s1, v0, RIB_OUT), wall.p(s1, top(s1), RIB_OUT),
                           wall.p(s0, top(s0), 0.0)]
                else:
                    pts = [wall.p(s0, v0, RIB_OUT), wall.p(s1, v0, 0.0), wall.p(s1, top(s1), 0.0),
                           wall.p(s0, top(s0), RIB_OUT)]
                m.face(pts, "clad", wall.d(side * RIB_OUT, RIB_BASE))


def _window(m: sk.Model, wall: Wall, u: float, w: float, v0: float, v1: float) -> None:
    ua, ub = u - w * 0.5, u + w * 0.5
    wall.quad(m, ua, ub, v0, v1, -0.04, "glass")
    for a, b in ((ua - 0.08, ua), (ub, ub + 0.08)):
        wall.box(m, a, b, v0, v1 + 0.08, -0.04, 0.07, "frame")
    wall.box(m, ua, ub, v1, v1 + 0.08, -0.04, 0.07, "frame", ("back", "left", "right"))
    wall.box(m, u - 0.03, u + 0.03, v0, v1, -0.04, 0.03, "frame", ("back", "top", "bottom"))
    wall.box(m, ua - 0.14, ub + 0.14, v0 - 0.09, v0, -0.04, 0.12, "trim")


def _door(m: sk.Model, wall: Wall, u: float, w: float, base: float) -> None:
    """A personnel door (photo 103332: pale leaf in a dark frame), a step under it and a lamp over it."""
    ua, ub, top = u - w * 0.5, u + w * 0.5, base + DOOR_H
    wall.quad(m, ua, ub, base + 0.3, top, -0.03, "door")
    wall.quad(m, ua, ub, base, base + 0.3, -0.03, "door_kick")
    for a, b in ((ua - 0.09, ua), (ub, ub + 0.09)):
        wall.box(m, a, b, base, top + 0.09, -0.03, 0.08, "trim", ("back", "bottom"))
    wall.box(m, ua, ub, top, top + 0.09, -0.03, 0.08, "trim", ("back", "left", "right"))
    wall.box(m, ub - 0.16, ub - 0.06, base + 1.0, base + 1.06, -0.03, 0.03, "trim", ("back",))
    wall.box(m, ua - 0.25, ub + 0.25, 0.0, base - 0.12, 0.1, 0.28, "plinth", ("back", "bottom"))
    _lamp(m, wall, u, top + 0.35)


def _lamp(m: sk.Model, wall: Wall, u: float, v: float) -> None:
    """A bulkhead lamp (photo 103323), lit at night."""
    wall.box(m, u - 0.17, u + 0.17, v, v + 0.22, 0.0, 0.12, "trim")
    wall.quad(m, u - 0.12, u + 0.12, v + 0.04, v + 0.18, 0.125, "lamp")


def _shutter(m: sk.Model, wall: Wall, u: float, w: float, base: float, top: float) -> None:
    """A roller shutter (photo 103332): slats in light and shade, a bottom rail, guides, the barrel's hood."""
    ua, ub = u - w * 0.5, u + w * 0.5
    n = max(8, round((top - base - 0.12) / 0.2))
    step = (top - base - 0.12) / n
    for k in range(n):
        v0 = base + 0.12 + k * step
        vm = v0 + step * 0.5
        for a, b, wa, wb, mat, dv in ((v0, vm, -0.08, -0.05, "shutter_dark", -1.0),
                                      (vm, v0 + step, -0.05, -0.08, "shutter", 1.0)):
            m.face([wall.p(ua, a, wa), wall.p(ub, a, wa), wall.p(ub, b, wb), wall.p(ua, b, wb)], mat,
                   wall.d(0.0, step * 0.5, dv * 0.03))
    wall.box(m, ua, ub, base, base + 0.12, -0.09, -0.02, "trim", ("back", "left", "right", "bottom"))
    for a, b in ((ua - 0.14, ua + 0.05), (ub - 0.05, ub + 0.14)):
        wall.box(m, a, b, base, top, -0.1, 0.1, "trim", ("back", "bottom", "top"))
    wall.box(m, ua - 0.22, ub + 0.22, top, top + 0.62, -0.1, 0.27, "shutter_hood")


def _layout(name: str, L: float, D: float, H: float, hl: float, hd: float, base: float) -> dict:
    """Each wall's openings: (what, u middle, width, bottom, top). The +X gable and the +Z side carry the doors
    (photos 103316, 103332); the back walls stay plain but for a lamp."""
    door = (base, base + DOOR_H)
    if name == "shed_long":
        sh = min(H - 2.4, 6.0)
        return {
            "+x": [("shutter", -2.5, 6.0, base, sh), ("door", hd - 2.0, DOOR_W, *door)],
            "+z": [("shutter", -14.0, 5.0, base, sh - 0.5), ("shutter", -5.0, 5.0, base, sh - 0.5),
                   ("door", 2.0, DOOR_W, *door)] + [("window", x, 1.2, H - 3.2, H - 1.8) for x in (6.0, 10.0, 14.0,
                                                                                            18.0)],
            "-x": [("door", -hd + 3.0, DOOR_W, *door)], "-z": []}
    if name == "shed_deep":
        sh = min(H - 2.2, 5.5)
        return {
            "+x": [("shutter", -6.0, 5.0, base, sh), ("door", 0.0, DOOR_W, *door), ("shutter", 6.0, 5.0, base, sh)],
            "+z": [("door", hl - 5.0, DOOR_W, *door)] + [("window", x, 1.0, 2.2, 3.7)
                                                        for x in (-14.5, -10.5, -6.5, -2.5, 1.5, 5.5)],
            "-x": [], "-z": [("door", -hl + 4.0, DOOR_W, *door)]}
    sh = min(H - 1.7, 4.4)
    return {
        "+x": [("shutter", -1.0, 4.6, base, sh), ("door", hd - 2.1, DOOR_W, *door)],
        "+z": [("door", hl - 4.7, DOOR_W, *door)] + [("window", x, 1.0, 2.1, 3.6) for x in (-8.7, -5.5, -2.3, 0.9)],
        "-x": [], "-z": []}


def shed(name: str = "shed") -> sk.Model:
    """A steel-clad portal-frame shed at one of skyline.SHEDS' sizes, its ridge SkylineConfig.roof_rise of its depth
    over the eaves; the walls 0.3 m inside the roof's edge. Ribs, sheets, doors and windows keep their real sizes."""
    m = sk.Model(name, {
        "clad": (1.0, vp.BODY), "clad_pan": (0.9, vp.BODY), "clad_pan_b": (0.87, vp.BODY),
        "clad_pan_c": (0.93, vp.BODY),
        "roof": (0x5E655F, vp.FIXED), "roof_rib": (0x6A716B, vp.FIXED), "roof_under": (0x474C48, vp.FIXED),
        "rooflight": (0xC5CCC4, vp.FIXED), "trim": (sk.DARK_TRIM, vp.FIXED), "plinth": (sk.CONCRETE, vp.FIXED),
        "shutter": (0x4D5359, vp.FIXED), "shutter_dark": (0x3A3F44, vp.FIXED), "shutter_hood": (0x3F4448, vp.FIXED),
        "door": (0xB4B8B4, vp.FIXED), "door_kick": (0x8E9290, vp.FIXED), "glass": (sk.GLASS, vp.FIXED),
        "frame": (0x3A3E41, vp.FIXED), "pipe": (0x34383B, vp.FIXED), "lamp": (0xF2E8D0, vp.FIXED),
    })
    L, D, H = sk.SHEDS[name]
    s, sr = SHED_RIBS[name]
    rng = random.Random(name)
    R = 0.15 * D
    k = R / (D * 0.5)                     # the roof's slope
    hl, hd = L * 0.5 - 0.3, D * 0.5 - 0.3
    base = 0.4                            # the plinth's top
    top_y = H + R

    def under(z):                         # the roof sheet's underside, H over the long walls
        return H + k * (hd - abs(z))

    def over(z):
        return under(z) + 0.06

    walls = {"+z": Wall("+z", hd, hl, lambda u: H), "-z": Wall("-z", hd, hl, lambda u: H),
             "+x": Wall("+x", hl, hd, under), "-x": Wall("-x", hl, hd, under)}
    layout = _layout(name, L, D, H, hl, hd, base)
    for key, wall in walls.items():
        # each opening's sides snapped to the middle of a pan, clear of the ribs
        snapped = []
        for what, u, w, v0, v1 in layout[key]:
            ua = round((u - w * 0.5) / s) * s
            ub = ua + max(1, round(w / s)) * s
            snapped.append((what, (ua + ub) * 0.5, ub - ua, v0, v1))
        holes = [(u - w * 0.5, u + w * 0.5, v0, v1) for _what, u, w, v0, v1 in snapped]
        _clad(m, wall, base, holes, s, rng, key[1] == "x")
        for what, u, w, v0, v1 in snapped:
            if what == "window":
                _window(m, wall, u, w, v0, v1)
            elif what == "door":
                _door(m, wall, u, w, base)
            else:
                _shutter(m, wall, u, w, v0, v1)
        # the dark base flashing over the plinth, broken at the doorways
        cuts = sorted((u0 - 0.1, u1 + 0.1) for u0, u1, v0, _v1 in holes if v0 < base + 0.01)
        a = -wall.half
        for u0, u1 in cuts + [(wall.half, wall.half)]:
            if u0 > a:
                wall.box(m, a, u0, base, base + 0.1, 0.0, 0.075, "trim", ("back", "bottom"))
            a = u1
    # lamps on the plain walls' ends, high
    for key, u in (("-x", 0.0), ("-z", -hl * 0.5), ("-z", hl * 0.5)):
        _lamp(m, walls[key], u, H - 1.1)
    # corner flashings: an angle round each corner
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            m_long, m_gable = walls[("+" if sz > 0 else "-") + "z"], walls[("+" if sx > 0 else "-") + "x"]
            m_long.box(m, sx * hl - 0.2 if sx > 0 else -hl - 0.07, hl + 0.07 if sx > 0 else -hl + 0.2, base, H,
                       0.0, 0.055, "trim", ("back", "bottom"))
            m_gable.box(m, sz * hd - 0.2 if sz > 0 else -hd - 0.065, hd + 0.065 if sz > 0 else -hd + 0.2, base, H,
                        0.0, 0.062, "trim", ("back", "bottom"))
    slab(m, (-hl - 0.12, 0.0, -hd - 0.12), (hl + 0.12, base, hd + 0.12), "plinth", ("-y",))
    _roof(m, L, D, H, hd, k, sr, under, over, top_y)
    # gutters along the eaves, downpipes from them by the corners (photo 103338)
    for sz in (-1.0, 1.0):
        z0, z1 = sorted((sz * (hd + 0.06), sz * D * 0.5))
        slab(m, (-L * 0.5 + 0.06, H - 0.3, z0), (L * 0.5 - 0.06, H - 0.08, z1), "trim", ("-z" if sz > 0 else "+z",))
        for x in (-hl + 0.45, hl - 0.45):
            path = [(x, H - 0.25, sz * (hd + 0.19)), (x, H - 0.5, sz * (hd + 0.19)), (x, H - 0.8, sz * (hd + 0.1)),
                    (x, 0.32, sz * (hd + 0.1)), (x, 0.1, sz * (hd + 0.24))]
            _pipe(m, path, 0.055, "pipe")
    return m


def _pipe(m: sk.Model, path: list, r: float, mat: str, sides: int = 4) -> None:
    """A pipe (square by default, as a shed's downpipes are) along `path` (Godot points), bent at each."""
    pts = [Vector(p) for p in path]
    rings = []
    for i, c in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        e1 = Vector((1.0, 0.0, 0.0)) - t * t.x
        e1.normalize()
        e2 = t.cross(e1)
        rings.append([tuple(c + (e1 * math.cos(a) + e2 * math.sin(a)) * r)
                      for a in (math.pi * (2.0 * j + 1.0) / sides for j in range(sides))])
    m.rings(rings, mat)


def _roof(m: sk.Model, L, D, H, hd, k, sr, under, over, top_y) -> None:
    """Two ribbed slopes to the gutters, rooflights between ribs (photo 103323), the ridge cap and the verges."""
    ze, xr = D * 0.5 - 0.1, L * 0.5 - 0.05
    rib_h, rib_b, cap = 0.05, 0.07, 0.45
    ribs = _ribs(xr, sr, 0.25)
    for s in (-1.0, 1.0):
        def p(x, z, dy=0.0):
            return (x, over(z) + dy, s * z)
        up = (0.0, 1.0, s * k)
        m.face([p(-xr, ze), p(xr, ze), p(xr, 0.0), p(-xr, 0.0)], "roof", up)
        m.face([p(-xr, ze, -0.06), p(xr, ze, -0.06), p(xr, 0.0, -0.06), p(-xr, 0.0, -0.06)], "roof_under",
               (0.0, -1.0, -s * k))
        m.face([p(-xr, ze, -0.06), p(xr, ze, -0.06), p(xr, ze), p(-xr, ze)], "trim", (0.0, 0.0, s))
        z0 = 0.36
        for x in ribs:
            for side in (-1.0, 1.0):
                m.face([p(x + side * rib_b, z0), p(x + side * rib_b, ze), p(x, ze, rib_h), p(x, z0, rib_h)],
                       "roof_rib", (side, 1.0, 0.0))
            m.face([p(x - rib_b, ze), p(x + rib_b, ze), p(x, ze, rib_h)], "roof_rib", (0.0, 0.0, s))
        # rooflights: every third bay, staggered between the slopes, two rows up the slope
        for i, (a, b) in enumerate(zip(ribs, ribs[1:])):
            if (i + (1 if s > 0 else 0)) % 3:
                continue
            for f0, f1 in ((0.18, 0.42), (0.55, 0.8)):
                za, zb = ze * (1.0 - f0), ze * (1.0 - f1)
                m.face([p(a + rib_b, za, 0.015), p(b - rib_b, za, 0.015), p(b - rib_b, zb, 0.015),
                        p(a + rib_b, zb, 0.015)], "rooflight", up)
        # the ridge cap's slope and its drip edge
        m.face([(-xr, over(cap) + 0.06, s * cap), (xr, over(cap) + 0.06, s * cap), (xr, top_y, 0.0),
                (-xr, top_y, 0.0)], "trim", (0.0, 1.0, s * 0.2))
        m.face([(-xr, over(cap), s * cap), (xr, over(cap), s * cap), (xr, over(cap) + 0.06, s * cap),
                (-xr, over(cap) + 0.06, s * cap)], "trim", (0.0, 0.0, s))
        # the verges down each gable's rake
        for sx in (-1.0, 1.0):
            x = sx * (L * 0.5 - 0.045)
            bar(m, (x, over(ze) - 0.035, s * ze), (x, over(0.0) - 0.035, 0.0), 0.045, 0.0575, "trim",
                side=(1.0, 0.0, 0.0))
    for sx in (-1.0, 1.0):
        m.face([(sx * xr, over(cap), -cap), (sx * xr, over(cap) + 0.06, -cap), (sx * xr, top_y, 0.0),
                (sx * xr, over(cap) + 0.06, cap), (sx * xr, over(cap), cap)], "trim", (sx, 0.0, 0.0))


# ------------------------------------------------------------------------------------------------------ watch tower

def watch_tower() -> sk.Model:
    """A steel watch tower, 5.2 m square (its deck), 12.4 m to the antenna's tip (photos 103631 and 103640: braced
    legs on footings, gusset plates where the braces cross; 103711 and 103648: stair flights round the outside with
    landings and handrails, a railed deck over a joist grid, a glazed cabin; 103631: a ribbed hip roof). The first
    flight climbs the +Z side, the second the +X, the last the -Z up through the deck's stairwell."""
    m = sk.Model("watch_tower", {
        "steel": (1.0, vp.BODY), "steel_shade": (0.82, vp.BODY), "steel_dark": (0.64, vp.BODY),
        "panel": (0xC9CBC6, vp.FIXED), "panel_shade": (0xAEB1AC, vp.FIXED), "frame": (0xDADCD8, vp.FIXED),
        "glass": (sk.GLASS, vp.FIXED), "door": (0x9EA3A0, vp.FIXED),
        "roof": (0x6E776F, vp.FIXED), "roof_rib": (0x7D867E, vp.FIXED), "roof_under": (0x555C57, vp.FIXED),
        "deck": (0x7D7F7C, vp.FIXED), "tread": (sk.GALV, vp.FIXED), "pad": (sk.CONCRETE, vp.FIXED),
        "trim": (sk.DARK_TRIM, vp.FIXED), "lamp": (0xF2E8D0, vp.FIXED),
    })
    P, f = 2.6, 1.5                      # the deck's and the legs' half widths
    deck, deck_under, joist = 8.2, 7.92, 7.7
    rise = deck / 3.0                    # each flight's
    lv = [0.35, rise, 2.0 * rise, joist]
    run = 1.75                           # a flight's half run
    bi, bo = 1.82, 2.53                  # the stairs' band, in from the deck's edge
    # footings, base plates, legs
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            x, z = sx * f, sz * f
            slab(m, (x - 0.3, 0.0, z - 0.3), (x + 0.3, 0.32, z + 0.3), "pad", ("-y",))
            slab(m, (x - 0.18, 0.32, z - 0.18), (x + 0.18, 0.35, z + 0.18), "steel_dark", ("-y",))
            bar(m, (x, 0.35, z), (x, deck_under, z), 0.08, 0.08, "steel", side=(1.0, 0.0, 0.0), caps=(False, False))
    # each face: struts at the landings' levels, crossed flat braces in each bay, a gusset where they cross
    faces = [((-f, -f), (f, -f), (0.0, 0.0, -1.0)), ((f, -f), (f, f), (1.0, 0.0, 0.0)),
             ((f, f), (-f, f), (0.0, 0.0, 1.0)), ((-f, f), (-f, -f), (-1.0, 0.0, 0.0))]
    for (xa, za), (xb, zb), n in faces:
        for y in lv[1:3]:
            bar(m, (xa, y, za), (xb, y, zb), 0.06, 0.07, "steel_shade", side=n, caps=(False, False))
        for ya, yb in zip(lv, lv[1:]):
            ya += 0.05
            yb -= 0.05
            for (x0, z0), (x1, z1) in (((xa, za), (xb, zb)), ((xb, zb), (xa, za))):
                bar(m, (x0, ya, z0), (x1, yb, z1), 0.012, 0.05, "steel", side=n, caps=(False, False))
            c = Vector(((xa + xb) * 0.5, (ya + yb) * 0.5, (za + zb) * 0.5))
            bar(m, c - Vector(n) * 0.03, c + Vector(n) * 0.03, 0.13, 0.13, "steel_shade",
                side=(Vector((0.0, 1.0, 0.0)) + Vector(n).cross(Vector((0.0, 1.0, 0.0)))))
    _tower_deck(m, P, f, deck, deck_under, joist, bi)
    _tower_stairs(m, P, f, deck, rise, run, bi, bo)
    _tower_cabin(m, deck)
    # a cable conduit down the -X +Z leg's outside to a junction box (photo 103655)
    x, z = -f - 0.11, f + 0.11
    bar(m, (x, 0.32, z), (x, deck_under, z), 0.025, 0.025, "trim", side=(1.0, 0.0, 0.0), caps=(False, False))
    slab(m, (x - 0.16, 1.1, z - 0.04), (x + 0.04, 1.55, z + 0.16), {"": "panel_shade", "-x": "panel"})
    return m


def _rail(m: sk.Model, a, b, posts: int, height: float = 1.05, toe: bool = True, infill: float = 0.2) -> None:
    """A guard rail from `a` to `b` (deck-level Godot points): posts, a top and a knee rail, balusters about
    `infill` m apart between them (photo 103640), a toe board."""
    a, b = Vector(a), Vector(b)
    up = Vector((0.0, 1.0, 0.0))
    for i in range(posts):
        p = a + (b - a) * (i / (posts - 1))
        bar(m, p, p + up * height, 0.028, 0.028, "steel", side=(1.0, 0.0, 0.0), caps=(False, True))
    n = round((b - a).length / infill)
    for i in range(n):
        t = (i + 0.5) / n
        if abs(t - round(t * (posts - 1)) / (posts - 1)) * (b - a).length < 0.06:   # none on a post
            continue
        p = a + (b - a) * t
        bar(m, p + up * (0.14 if toe else 0.0), p + up * height, 0.011, 0.011, "steel", side=(1.0, 0.0, 0.0),
            caps=(False, False))
    for h, r in ((height, 0.03), (height * 0.5, 0.02)):
        bar(m, a + up * h, b + up * h, r, r, "steel", caps=(True, True))
    if toe:
        bar(m, a + up * 0.077, b + up * 0.077, 0.07, 0.012, "steel_shade", caps=(True, True))


def _tower_deck(m: sk.Model, P, f, deck, deck_under, joist, bi) -> None:
    """The deck over a joist grid on knee braces, its stairwell over the last flight (the -Z side), its rails."""
    well = -(bi - 0.04)                       # the stairwell's inner edge (z)
    corner = -1.75                            # where the last flight arrives (x)
    sides = {"+y": "deck", "-y": "steel_dark", "": "steel_shade"}
    slab(m, (-P, deck_under, well), (P, deck, P), sides)
    slab(m, (-P, deck_under, -P), (corner, deck, well), sides, ("+z",))
    for z in (-f, -0.75, 0.0, 0.75, f, 2.15):
        slab(m, (-P + 0.1, joist, z - 0.06), (P - 0.1, deck_under, z + 0.06), "steel_shade", ("+y",))
    for x in (-2.15, -f, f, 2.15):
        z0 = -P + 0.1 if x < corner else well + 0.05
        slab(m, (x - 0.055, joist + 0.04, z0), (x + 0.055, deck_under, P - 0.1), "steel_dark", ("+y",))
    slab(m, (-P + 0.1, joist + 0.02, -2.15 - 0.06), (corner - 0.05, deck_under, -2.15 + 0.06), "steel_shade",
         ("+y",))
    # knee braces from the legs out under the deck's edge (none over the last flight)
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            for d in ((sx, 0.0), (0.0, sz)):
                if d[1] < 0.0:
                    continue
                x, z = sx * f, sz * f
                bar(m, (x, joist - 1.0, z), (x + d[0] * (P - f - 0.15), joist, z + d[1] * (P - f - 0.15)), 0.04,
                    0.05, "steel_shade", side=(0.0, 1.0, 0.0), caps=(False, False))
    # the rails: round the edge, open where the stair arrives, along the stairwell
    e = P - 0.035
    _rail(m, (-e, deck, e), (e, deck, e), 7)
    _rail(m, (e, deck, well + 0.04), (e, deck, e - 0.07), 6)
    _rail(m, (-e, deck, -e), (-e, deck, e - 0.07), 7)
    _rail(m, (-e + 0.07, deck, -e), (corner + 0.03, deck, -e), 2)
    _rail(m, (corner + 0.03, deck, well + 0.035), (e - 0.07, deck, well + 0.035), 6)


def _tower_stairs(m: sk.Model, P, f, deck, rise, run, bi, bo) -> None:
    """Three flights round the outside, each rising a third of the deck's height, with landings at the corners."""
    def at(axis, t, lat, y):
        return (t, y, lat) if axis == "x" else (lat, y, t)

    flights = [("x", -run, run, 0.0, rise, 1.0), ("z", run, -run, rise, 2.0 * rise, 1.0),
               ("x", run, -run, 2.0 * rise, deck, -1.0)]
    for axis, t0, t1, y0, y1, side in flights:
        li, lo = side * bi, side * bo
        n = round((y1 - y0) / 0.2)
        go = (t1 - t0) / n
        slope = (y1 - y0) / (t1 - t0)

        def line(t, t0=t0, y0=y0, slope=slope):
            return y0 + (t - t0) * slope
        # treads: grating plates between the stringers
        for i in range(1, n):
            t = t0 + go * i
            y = line(t)
            a, b = sorted((t - go * 0.5, t + go * 0.5))
            lo_, hi_ = sorted((li + side * 0.05, lo - side * 0.05))
            pa, pb = at(axis, a, lo_, y - 0.04), at(axis, b, hi_, y)
            slab(m, tuple(min(pa[k], pb[k]) for k in range(3)), tuple(max(pa[k], pb[k]) for k in range(3)), "tread",
                 ("+x", "-x") if axis == "z" else ("+z", "-z"))
        # stringers, the foot of the first raised clear of the ground
        ts = t0 + (0.22 / slope if y0 < 0.01 else 0.0)
        lat_n = (0.0, 0.0, 1.0) if axis == "x" else (1.0, 0.0, 0.0)
        for lat in (li + side * 0.025, lo - side * 0.025):
            bar(m, at(axis, ts, lat, line(ts) - 0.05), at(axis, t1, lat, y1 - 0.05), 0.025, 0.11, "steel_shade",
                side=lat_n)
            # handrails both sides: posts, the rail and a knee rail
            for i in range(4):
                t = t0 + (t1 - t0) * (0.06 + 0.88 * i / 3)
                bar(m, at(axis, t, lat, line(t) + 0.06), at(axis, t, lat, line(t) + 1.0), 0.022, 0.022, "steel",
                    side=(0.0, 0.0, 1.0) if axis == "x" else (1.0, 0.0, 0.0), caps=(False, True))
            for h, r in ((1.0, 0.026), (0.5, 0.018)):
                bar(m, at(axis, t0, lat, y0 + h), at(axis, t1, lat, y1 + h), r, r, "steel")
        # balusters on the outside rail (photo 103711)
        lat = lo - side * 0.025
        bars = round(abs(t1 - t0) / 0.25)
        for i in range(bars):
            t = t0 + (t1 - t0) * (i + 0.5) / bars
            bar(m, at(axis, t, lat, line(t) + 0.06), at(axis, t, lat, line(t) + 1.0), 0.011, 0.011, "steel",
                side=(1.0, 0.0, 0.0), caps=(False, False))
    # the landings at the +X corners: a plate on a bracket from the leg, rails round the outside
    for sz, y in ((1.0, rise), (-1.0, 2.0 * rise)):
        z0, z1 = sorted((sz * (run - 0.02), sz * bo))
        slab(m, (run - 0.02, y - 0.08, z0), (bo, y, z1), {"+y": "deck", "": "steel_shade"})
        bar(m, (f, y - 0.9, sz * f), (2.3, y - 0.08, sz * 2.3), 0.04, 0.05, "steel_shade", caps=(False, False))
        bar(m, (f, y - 0.12, sz * f), (2.45, y - 0.12, sz * 2.45), 0.04, 0.04, "steel_shade", caps=(False, True))
        c = (bo + 0.02, y, sz * (bo + 0.02))
        _rail(m, (run, y, c[2]), c, 2, 1.0, False)
        _rail(m, c, (c[0], y, sz * run), 2, 1.0, False)
    slab(m, (-run - 0.3, 0.0, bi - 0.05), (-run + 0.25, 0.08, bo + 0.05), "pad", ("-y",))


def _tower_cabin(m: sk.Model, deck) -> None:
    """The cabin: low panels, a band of windows with mullions, a door to the -X, an upper band; corner posts, a
    ribbed hip roof with fascia and soffit, an antenna, a floodlight and an air-conditioning unit."""
    c, sill, head, eave = 1.45, deck + 1.0, deck + 1.95, deck + 2.4
    door = (-1.2, -0.4)
    for key in ("+x", "-x", "+z", "-z"):
        wall = Wall(key, c, c, lambda u: eave)
        spans = [(-c + 0.06, door[0]), (door[1], c - 0.06)] if key == "-x" else [(-c + 0.06, c - 0.06)]
        for ua, ub in spans:
            wall.box(m, ua, ub, deck, sill - 0.06, -0.06, 0.0, "panel", ("back", "left", "right", "bottom", "top"))
            seams = round((ub - ua) / 0.45)
            for i in range(1, seams):
                u = ua + (ub - ua) * i / seams
                wall.quad(m, u - 0.025, u + 0.025, deck + 0.05, sill - 0.05, 0.012, "panel_shade")
            wall.quad(m, ua, ub, sill, head, -0.05, "glass")
            wall.box(m, ua, ub, sill - 0.06, sill, -0.06, 0.07, "frame", ("back", "left", "right"))
            panes = max(1, round((ub - ua) / 0.95))
            for i in range(1, panes):
                u = ua + (ub - ua) * i / panes
                wall.box(m, u - 0.03, u + 0.03, sill, head, -0.06, 0.03, "frame", ("back", "top", "bottom"))
        if key == "-x":
            wall.quad(m, door[0], door[1], deck, head, -0.045, "door")
            wall.quad(m, door[0] + 0.15, door[1] - 0.15, deck + 1.2, head - 0.15, -0.03, "glass")
            for a, b in ((door[0] - 0.06, door[0]), (door[1], door[1] + 0.06)):
                wall.box(m, a, b, deck, head, -0.06, 0.04, "frame", ("back", "bottom"))
            wall.box(m, door[1] - 0.14, door[1] - 0.08, deck + 1.0, deck + 1.05, -0.04, 0.02, "trim")
        wall.box(m, -c + 0.06, c - 0.06, head + 0.07, eave, -0.06, 0.0, "panel", ("back", "left", "right", "bottom"))
        wall.box(m, -c + 0.06, c - 0.06, head, head + 0.07, -0.06, 0.05, "frame", ("back", "left", "right"))
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            slab(m, (sx * c - 0.065, deck, sz * c - 0.065), (sx * c + 0.065, eave, sz * c + 0.065), "frame",
                 ("-y", "+y"))
    # the hip roof: four slopes to a point, ribs down them, the hips capped, a fascia and a soffit
    r, apex = 1.95, deck + 3.55
    k = (apex - eave) / r
    corners = [(-r, -r), (r, -r), (r, r), (-r, r)]
    for (xa, za), (xb, zb) in zip(corners, corners[1:] + corners[:1]):
        n = Vector(((xa + xb) * 0.5, 0.0, (za + zb) * 0.5)).normalized()
        m.face([(xa, eave, za), (xb, eave, zb), (0.0, apex, 0.0)], "roof", (n.x, 1.0, n.z))
        m.face([(xa, eave - 0.14, za), (xb, eave - 0.14, zb), (xb, eave, zb), (xa, eave, za)], "trim", tuple(n))
        m.face([(xa, eave - 0.14, za), (xb, eave - 0.14, zb), (0.0, eave + 0.2, 0.0)], "roof_under", (0, -1, 0))
        bar(m, (xa, eave + 0.02, za), (0.0, apex + 0.02, 0.0), 0.045, 0.045, "trim", caps=(True, False))
        along = Vector((xb - xa, 0.0, zb - za)).normalized()
        for i in range(1, 9):
            u = -r + 2.0 * r * i / 9.0
            depth = r - abs(u) - 0.08
            if depth < 0.2:
                continue
            p0 = Vector((0.0, eave, 0.0)) + n * r + along * u
            p1 = p0 - n * depth + Vector((0.0, depth * k, 0.0))
            lift = Vector((0.0, 0.035, 0.0)) * (1.0 + k * k) ** 0.5
            for s in (-1.0, 1.0):
                m.face([tuple(p0 + along * (s * 0.05)), tuple(p1 + along * (s * 0.05)), tuple(p1 + lift),
                        tuple(p0 + lift)], "roof_rib", tuple(along * s + Vector((0.0, 1.0, 0.0))))
            m.face([tuple(p0 - along * 0.05), tuple(p0 + along * 0.05), tuple(p0 + lift)], "roof_rib", tuple(n))
    # the antenna on the apex, a floodlight on the deck's front corner post, the air conditioner on the +X wall
    bar(m, (0.0, apex - 0.05, 0.0), (0.0, 12.4, 0.0), 0.025, 0.025, "trim", caps=(False, True))
    slab(m, (-0.09, apex - 0.12, -0.09), (0.09, apex + 0.1, 0.09), "trim", ("-y",))
    e = 2.6 - 0.035
    slab(m, (e - 0.2, deck + 1.12, e - 0.24), (e + 0.02, deck + 1.36, e + 0.02), "trim")
    m.face([(e - 0.17, deck + 1.15, e + 0.025), (e - 0.01, deck + 1.15, e + 0.025), (e - 0.01, deck + 1.33, e + 0.025),
            (e - 0.17, deck + 1.33, e + 0.025)], "lamp", (0.0, 0.0, 1.0))
    slab(m, (c, deck + 0.05, 0.1), (c + 0.32, deck + 0.6, 0.9), {"+x": "panel_shade", "": "panel"}, ("-x",))
    m.face([(c + 0.325, deck + 0.12, 0.25), (c + 0.325, deck + 0.12, 0.75), (c + 0.325, deck + 0.53, 0.75),
            (c + 0.325, deck + 0.53, 0.25)], "trim", (1.0, 0.0, 0.0))
