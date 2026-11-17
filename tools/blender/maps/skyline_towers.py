"""The Range skyline's tall steel: the pillar jib crane, the phone mast and the water tower (RQ2: the owner asked for
far more detail on the background models, 2026-11-17), after his photos (art/references/maps/william-2026-11-09/
skyline_buildings/<kind>/). Built with skyline.py's Model and colours, at the size of each kind's first piece, in
Godot coordinates, front toward +Z; skyline.py's crane(), mast() and water_tower() hand over to these.

Seen from 20 to 150 m: the detail is in the silhouette (bracing, rails, cages, rungs, cables, chain) and in shading
breakup (darker trims and proud seams), every curve with enough sides to shade round (vertex_paint.SMOOTH_MOST).
"""

import math

import skyline as sk
import vertex_paint as vp
import hardsurface as hs
from mathutils import Vector


# ---------------------------------------------------------------------------------------------------------- helpers

def block(m: sk.Model, pts: list, mat: str) -> None:
    """A six-sided solid through eight Godot points: a bottom ring of four, then the top ring in the same order,
    each face turned away from the middle."""
    c = sum((Vector(p) for p in pts), Vector()) / 8.0
    quads = [pts[0:4], pts[4:8]] + [[pts[i], pts[(i + 1) % 4], pts[4 + (i + 1) % 4], pts[4 + i]] for i in range(4)]
    for q in quads:
        mid = sum((Vector(p) for p in q), Vector()) / 4.0
        m.face([tuple(p) for p in q], mat, tuple(mid - c))


def obox(m: sk.Model, c, u, v, w, mat: str) -> None:
    """A box about `c` with half-axes `u`, `v`, `w` (Godot vectors, any directions at right angles)."""
    c, u, v, w = Vector(c), Vector(u), Vector(v), Vector(w)
    ring = [c - u - w, c + u - w, c + u + w, c - u + w]
    block(m, [p - v for p in ring] + [p + v for p in ring], mat)


def beam(m: sk.Model, p0, p1, w: float, h: float, mat: str, up=(0.0, 1.0, 0.0)) -> None:
    """A square-ended bar from `p0` to `p1`, `w` across and `h` deep (deep toward `up`)."""
    a, b = Vector(p0), Vector(p1)
    ax = b - a
    side = ax.cross(Vector(up))
    if side.length < 1e-6:
        side = ax.cross(Vector((1.0, 0.0, 0.0)))
    side = side.normalized() * w * 0.5
    dep = side.cross(ax).normalized() * h * 0.5
    obox(m, (a + b) * 0.5, ax * 0.5, dep, side, mat)


def plate(m: sk.Model, tri: list, normal, t: float, mat: str) -> None:
    """A flat plate `t` thick through a polygon of three or four Godot points, its faces either side of it."""
    n = Vector(normal).normalized() * t * 0.5
    lo = [Vector(p) - n for p in tri]
    hi = [Vector(p) + n for p in tri]
    c = sum(lo + hi, Vector()) / (2 * len(tri))
    faces = [lo, hi] + [[lo[i], lo[(i + 1) % len(tri)], hi[(i + 1) % len(tri)], hi[i]] for i in range(len(tri))]
    for q in faces:
        mid = sum(q, Vector()) / len(q)
        m.face([tuple(p) for p in q], mat, tuple(mid - c))


def _clip(poly: list, lo: tuple, hi: tuple) -> list:
    """A convex 2D polygon clipped to the rectangle lo..hi."""
    for axis in (0, 1):
        for bound, keep in ((lo[axis], 1.0), (hi[axis], -1.0)):
            out = []
            for i, a in enumerate(poly):
                b = poly[(i + 1) % len(poly)]
                da, db = (a[axis] - bound) * keep, (b[axis] - bound) * keep
                if da >= 0.0:
                    out.append(a)
                if da * db < 0.0:
                    t = da / (da - db)
                    out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
            poly = out
            if not poly:
                return []
    return poly


def stripes(m: sk.Model, origin, eu, ev, size: tuple, normal, width: float, mat: str, t: float = 0.03) -> None:
    """Hazard stripes at 45 degrees on a face: the face's corner `origin`, its edges along `eu` and `ev` (unit Godot
    vectors), `size` (u, v) long; each stripe `width` wide, `t` thick, standing out along `normal`."""
    o, eu, ev, n = Vector(origin), Vector(eu), Vector(ev), Vector(normal).normalized()
    u_len, v_len = size
    k = -v_len
    while k < u_len:
        band = [(k, 0.0), (k + width, 0.0), (k + width + v_len, v_len), (k + v_len, v_len)]
        poly = _clip(band, (0.0, 0.0), (u_len, v_len))
        if len(poly) >= 3:
            pts = [o + eu * a + ev * b + n * (t * 0.5) for a, b in poly]
            plate(m, pts, n, t, mat)
        k += width * 2.0


def sweep(m: sk.Model, pts: list, radius, sides: int, mat: str, caps=(False, False)) -> None:
    """A round section swept along Godot points (a cable, a hook, a pipe's bend), `radius` one value or one a point,
    each ring square to the path (frames carried along it, so the section doesn't twist)."""
    p = [Vector(q) for q in pts]
    n = len(p)
    radii = radius if isinstance(radius, (list, tuple)) else [radius] * n
    tans = [(p[min(i + 1, n - 1)] - p[max(i - 1, 0)]).normalized() for i in range(n)]
    ref = Vector((0.0, 1.0, 0.0)) if abs(tans[0].y) < 0.9 else Vector((1.0, 0.0, 0.0))
    u = tans[0].cross(ref).normalized()
    rings = []
    for i in range(n):
        t = tans[i]
        u = (u - t * u.dot(t)).normalized()
        v = t.cross(u)
        rings.append([tuple(p[i] + (u * math.cos(a) + v * math.sin(a)) * radii[i])
                      for a in (2.0 * math.pi * k / sides + math.pi / sides for k in range(sides))])
    m.rings(rings, mat, cap0=caps[0], cap1=caps[1])


def lathe(m: sk.Model, profile: list, mat: str, sides: int, centre=(0.0, 0.0, 0.0), cap: bool = False,
          start: float = 0.0) -> None:
    """A profile of (height, radius) turned about the vertical through `centre` (Godot), capped if `cap`, its first
    corner turned `start` radians round."""
    cx, cy, cz = centre
    faces = vp.lathe(m.b, [(h + cy, r) for h, r in profile], mat, sides, (cx, -cz, 0.0), "z", cap=cap)
    if start:
        m.b.transform(faces, hs.rot_about("z", start, (cx, -cz, 0.0)))


def xlathe(m: sk.Model, profile: list, mat: str, sides: int, y: float, z: float, cap: bool = False) -> None:
    """A profile of (x, radius) turned about the line along X at height `y`, depth `z` (Godot)."""
    vp.lathe(m.b, profile, mat, sides, (0.0, -z, y), "x", cap=cap)


def zlathe(m: sk.Model, profile: list, mat: str, sides: int, x: float, y: float, cap: bool = False) -> None:
    """A profile of (z, radius) turned about the line along Z through (`x`, `y`) (Godot)."""
    faces = vp.lathe(m.b, [(-a, r) for a, r in profile], mat, sides, (x, 0.0, y), "y", cap=cap)
    del faces


def chain(m: sk.Model, top, bottom, link: float, width: float, mat: str) -> None:
    """A hanging chain of flat links from `top` to `bottom`, each turned a quarter from the last."""
    a, b = Vector(top), Vector(bottom)
    ax = b - a
    n = max(1, int(ax.length / (link * 0.82)))
    d = ax.normalized()
    s1 = d.cross(Vector((0.0, 0.0, 1.0))) if abs(d.z) < 0.9 else d.cross(Vector((1.0, 0.0, 0.0)))
    s1.normalize()
    s2 = d.cross(s1).normalized()
    for k in range(n):
        c = a + ax * ((k + 0.5) / n)
        wide, thin = (s1, s2) if k % 2 == 0 else (s2, s1)
        obox(m, c, d * link * 0.5, wide * width * 0.5, thin * width * 0.18, mat)


# ------------------------------------------------------------------------------------------------------------ crane

def crane() -> sk.Model:
    """A pillar jib crane (photos 103403-103446: bright yellow; a built-up box pillar on a flared foot with gussets
    on an octagonal base plate, a slewing head, a solid knee-brace plate with its flange from the pillar to the jib,
    a tapered I-beam jib with a splice and an end stop, a festoon rail on T brackets along the top with the cable
    sagging in loops in front of the web, a blue-grey electric chain hoist on a four-wheeled trolley with its chain
    bag, a red hook block and a yellow pendant on its cable, an isolator and conduit down the pillar). 24.8 m along X
    (the jib reaching toward +X), 18 m tall, 4.8 m deep (the pad; SkylineConfig.keep_depth scales its depth with its
    length and height, so a deep piece doesn't fatten the pillar)."""
    m = sk.Model("crane", {
        "steel": (1.0, vp.BODY), "steel_shade": (0.8, vp.BODY), "steel_dark": (0.62, vp.BODY),
        "pad": (sk.CONCRETE, vp.FIXED), "grout": (0x86847E, vp.FIXED),
        "hoist": (0x4E5A66, vp.FIXED), "hoist_dark": (0x353C44, vp.FIXED), "chain": (0x75797D, vp.FIXED),
        "hook": (0xA82C68, vp.FIXED), "cable": (0x232527, vp.FIXED), "rail": (sk.GALV, vp.FIXED),
        "bolt": (0x55595D, vp.FIXED), "panel": (0x8C9196, vp.FIXED), "rubber": (0x2A2B2C, vp.FIXED),
    })
    top = 17.9854                   # the festoon rail's top: the model's height
    px = -10.4                      # the pillar's axis
    cw, cd = 0.7, 0.6               # the pillar's half width (X) and half depth (Z)
    jt = 17.4                       # the jib's top
    x0, x1 = px - 1.2, 12.0         # the jib's back end and its tip (with the end stop)
    fw = 0.55                       # the jib's flanges' half width

    def yb(x: float) -> float:      # the jib's underside: 1.5 m deep at the root, 1.05 at the tip
        return jt - 1.5 + 0.45 * (x - x0) / (x1 - x0)

    # the pad, chamfered, its grout bed and the octagonal base plate with anchor nuts
    block(m, [(px - 2.4, 0.0, -2.4), (px + 2.4, 0.0, -2.4), (px + 2.4, 0.0, 2.4), (px - 2.4, 0.0, 2.4),
              (px - 2.25, 0.3, -2.25), (px + 2.25, 0.3, -2.25), (px + 2.25, 0.3, 2.25), (px - 2.25, 0.3, 2.25)], "pad")
    m.box((px - 1.95, 0.28, -1.95), (px + 1.95, 0.36, 1.95), "grout")
    lathe(m, [(0.36, 1.8), (0.5, 1.8)], "steel_dark", 8, (px, 0.0, 0.0), cap=True, start=math.pi / 8)
    for k in range(8):
        a = math.pi / 8 + 2.0 * math.pi * k / 8 + math.pi / 8
        lathe(m, [(0.5, 0.11), (0.6, 0.11), (0.62, 0.07)], "bolt", 6, (px + math.cos(a) * 1.5, 0.0,
                                                                       math.sin(a) * 1.5), cap=True)
    # the foot: a sleeve and eight gussets out to the plate's edge
    m.box((px - cw - 0.1, 0.48, -cd - 0.1), (px + cw + 0.1, 1.1, cd + 0.1), "steel_shade")
    for k in range(8):
        a = 2.0 * math.pi * k / 8
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        # where the ray leaves the pillar's box
        reach = min(cw / abs(d.x) if abs(d.x) > 1e-6 else 99.0, cd / abs(d.z) if abs(d.z) > 1e-6 else 99.0)
        inner = d * (reach - 0.05)
        outer = d * 1.7
        plate(m, [(px + inner.x, 0.49, inner.z), (px + outer.x, 0.49, outer.z), (px + outer.x, 0.62, outer.z),
                  (px + inner.x, 2.4, inner.z)], (-d.z, 0.0, d.x), 0.09, "steel")
    # the pillar: a built-up box with a proud seam down its front and back, a collar where the brace meets it
    m.box((px - cw, 1.0, -cd), (px + cw, 13.6, cd), "steel")
    for s in (-1.0, 1.0):
        m.box((px - 0.05, 1.1, s * cd - 0.02), (px + 0.05, 13.5, s * (cd + 0.035)), "steel_dark")
    m.box((px - cw - 0.07, 10.15, -cd - 0.07), (px + cw + 0.07, 10.55, cd + 0.07), "steel_shade")
    # the slewing head: a bearing ring, a box clasping the jib's root, a cap plate and two lifting lugs
    m.box((px - cw - 0.05, 13.5, -cd - 0.05), (px + cw + 0.05, 13.62, cd + 0.05), "steel_dark")
    m.box((px - cw - 0.12, 13.6, -cd - 0.12), (px + cw + 0.12, jt + 0.08, cd + 0.12), "steel_shade")
    m.box((px - cw - 0.18, jt + 0.08, -cd - 0.18), (px + cw + 0.18, jt + 0.16, cd + 0.18), "steel_dark")
    for s in (-1.0, 1.0):
        plate(m, [(px + s * 0.5 - 0.15, jt + 0.15, 0.0), (px + s * 0.5 + 0.15, jt + 0.15, 0.0),
                  (px + s * 0.5, jt + 0.42, 0.0)], (0.0, 0.0, 1.0), 0.06, "steel_dark")
    # an inspection plate, the isolator with its red handle, and the conduit up to the head
    m.box((px - 0.32, 2.2, cd - 0.02), (px + 0.32, 3.5, cd + 0.05), "steel_shade")
    m.box((px + 0.2, 4.6, cd - 0.02), (px + 0.62, 5.4, cd + 0.24), "panel")
    m.box((px + 0.3, 4.85, cd + 0.2), (px + 0.38, 5.15, cd + 0.32), "hook")
    m.box((px + 0.42, 5.4, cd - 0.02), (px + 0.52, 13.6, cd + 0.07), "cable")
    for y in (6.4, 8.4, 10.7, 12.6):
        m.box((px + 0.38, y, cd - 0.02), (px + 0.56, y + 0.1, cd + 0.09), "rail")

    # the jib: a tapered I-beam, its flanges and web, end plates, a splice and stiffeners
    def span(xa: float, xb: float, ya, yb_, za: float, zb: float, mat: str) -> None:
        """A block from xa to xb whose bottom and top follow ya(x), yb_(x), between za and zb."""
        block(m, [(xa, ya(xa), za), (xb, ya(xb), za), (xb, ya(xb), zb), (xa, ya(xa), zb),
                  (xa, yb_(xa), za), (xb, yb_(xb), za), (xb, yb_(xb), zb), (xa, yb_(xa), zb)], mat)

    span(x0, x1 - 0.12, lambda x: jt - 0.16, lambda x: jt, -fw, fw, "steel")
    span(x0, x1 - 0.12, yb, lambda x: yb(x) + 0.16, -fw, fw, "steel")
    span(x0, x1 - 0.12, lambda x: yb(x) + 0.15, lambda x: jt - 0.15, -0.06, 0.06, "steel_shade")
    m.box((x0 - 0.06, yb(x0) - 0.02, -fw - 0.02), (x0 + 0.02, jt + 0.02, fw + 0.02), "steel_dark")
    for xs in (px + cw + 0.4, px + 5.3, 0.4, 5.2, x1 - 0.9):
        for s in (-1.0, 1.0):
            m.box((xs - 0.05, yb(xs) + 0.14, s * 0.05), (xs + 0.05, jt - 0.14, s * (fw - 0.03)), "steel_shade")
    sx = 0.9                        # the splice: cover plates on the web and both flanges
    for s in (-1.0, 1.0):
        span(sx - 0.55, sx + 0.55, lambda x: yb(x) + 0.2, lambda x: jt - 0.2, s * 0.05, s * 0.1, "steel_dark")
    span(sx - 0.6, sx + 0.6, lambda x: jt - 0.02, lambda x: jt + 0.05, -fw + 0.04, fw - 0.04, "steel_dark")
    span(sx - 0.6, sx + 0.6, lambda x: yb(x) - 0.07, lambda x: yb(x) + 0.02, -fw + 0.04, fw - 0.04, "steel_dark")
    # the end stop at the tip, rubber buffers inside it (and against the head)
    sy0, sy1, sz = yb(x1) - 0.45, jt + 0.06, fw + 0.1
    m.box((x1 - 0.16, sy0, -sz), (x1 - 0.025, sy1, sz), "steel_shade")
    stripes(m, (x1 - 0.03, sy0, sz), (0.0, 0.0, -1.0), (0.0, 1.0, 0.0), (2.0 * sz, sy1 - sy0), (1.0, 0.0, 0.0), 0.2,
            "rubber")
    for s in (-1.0, 1.0):
        stripes(m, (x1 - 0.16, sy0, s * (sz - 0.005)), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.13, sy1 - sy0),
                (0.0, 0.0, s), 0.2, "rubber", 0.02)
    for s in (-1.0, 1.0):
        m.tube((x1 - 0.14, yb(x1) + 0.08, s * 0.32), (x1 - 0.42, yb(x1) + 0.08, s * 0.32), 0.1, 0.1, 10,
               "rubber", caps=(False, True))
        m.tube((px + cw + 0.12, yb(px + cw) + 0.08, s * 0.32), (px + cw + 0.4, yb(px + cw) + 0.08, s * 0.32),
               0.1, 0.1, 10, "rubber", caps=(False, True))
    # the knee brace: a solid triangular plate from the pillar to the jib, its flange along the slope, two ribs
    bx = px + 5.6
    plate(m, [(px + cw - 0.04, 10.35, 0.0), (bx, yb(bx) + 0.04, 0.0), (px + cw - 0.04, yb(px + cw) + 0.04, 0.0)],
          (0.0, 0.0, 1.0), 0.12, "steel_shade")
    beam(m, (px + cw - 0.05, 10.3, 0.0), (bx + 0.12, yb(bx + 0.12) + 0.08, 0.0), 0.62, 0.14, "steel",
         up=(1.0, 1.0, 0.0))
    for f in (0.35, 0.7):
        xr = px + cw + (bx - px - cw) * f
        ylo = 10.35 + (yb(bx) - 10.35) * f
        for s in (-1.0, 1.0):
            m.box((xr - 0.05, ylo, s * 0.05), (xr + 0.05, yb(xr) + 0.02, s * 0.2), "steel_dark")
    # a junction box on the web by the head
    m.box((px + 1.6, 16.3, 0.05), (px + 2.1, 16.95, 0.3), "panel")

    # the festoon: T brackets on the top flange, the rail along their front ends, trolleys and the cable's loops
    rz0, rz1 = 0.5, 0.68
    for k in range(9):
        x = x0 + 0.6 + (x1 - 0.8 - x0 - 0.6) * k / 8.0
        m.box((x - 0.04, jt - 0.02, -0.04), (x + 0.04, 17.84, 0.04), "rail")
        m.box((x - 0.045, 17.8, -0.28), (x + 0.045, 17.88, 0.74), "rail")
    m.box((x0 + 0.4, 17.86, rz0), (x1 - 0.5, top, rz1), "rail")
    m.box((x0 + 0.4, 17.84, rz0 + 0.06), (x1 - 0.5, 17.865, rz1 - 0.06), "cable")
    hx = x1 - 2.9                   # the hoist's middle
    xa, xb = x0 + 1.0, hx - 0.2      # the first trolley, and the last, towed by the hoist
    loops = 10
    cz = 0.62
    for k in range(loops + 1):
        x = xa + (xb - xa) * k / loops
        m.box((x - 0.09, 17.66, rz0 + 0.02), (x + 0.09, 17.845, rz1 - 0.02), "hoist_dark")
    for k in range(loops):
        a, b = xa + (xb - xa) * k / loops, xa + (xb - xa) * (k + 1) / loops
        sag = 1.25 + 0.12 * ((k * 7) % 3)
        pts = []
        for i in range(11):
            f = i / 10.0
            # a slack loop: steep at its ends, round at the bottom, bellied out a little from the web
            y = 17.68 - sag * math.sin(math.pi * f) ** 0.7
            x = a + (b - a) * (0.5 - 0.5 * math.cos(math.pi * f))
            pts.append((x, y, cz + 0.07 * math.sin(math.pi * f)))
        sweep(m, pts, 0.05, 5, "cable")
    # the cable on at the root: down over the head's front into the conduit; on at the hoist: down to its panel
    sweep(m, [(xa, 17.68, cz), (xa + 0.1, 16.9, cz + 0.12), (px + cw + 0.05, 15.6, cd + 0.3),
              (px + 0.47, 14.6, cd + 0.24), (px + 0.47, 13.55, cd + 0.03)], 0.055, 5, "cable")

    # the hoist: a trolley straddling the bottom flange on four wheels, the gearcase and ribbed motor, the panel,
    # the chain bag, the chain, the hook block and hook, the pendant on its cable (q: the hoist's scale, as big
    # against the jib as in the photos)
    yh = yb(hx)
    q = 1.45

    def at(dx: float, dy: float, dz: float) -> tuple:
        return (hx + dx * q, yh + dy * q, dz * q)

    for s in (-1.0, 1.0):
        m.box((hx - 0.75 * q, yh - 0.5 * q, s * (fw + 0.06)), (hx + 0.75 * q, yh + 0.3, s * (fw + 0.16)), "hoist")
        for dx in (-0.48, 0.48):
            m.tube((hx + dx * q, yh + 0.12, s * (fw + 0.16)), (hx + dx * q, yh + 0.12, s * (fw + 0.25)), 0.2, 0.2, 12,
                   "hoist_dark", caps=(False, True))
    m.box(at(-0.7, -0.66, -0.52), at(0.7, -0.48, 0.52), "hoist_dark")
    m.box(at(-0.85, -1.55, -0.46), at(0.32, -0.64, 0.46), "hoist")
    m.box(at(-0.9, -1.25, -0.5), at(0.36, -1.17, 0.5), "hoist_dark")
    m.box(at(-0.9, -0.9, -0.5), at(0.36, -0.84, 0.5), "hoist_dark")
    xlathe(m, [(hx + 0.3 * q, 0.3 * q), (hx + 0.36 * q, 0.4 * q), (hx + 0.52 * q, 0.4 * q), (hx + 0.55 * q, 0.44 * q),
               (hx + 0.63 * q, 0.44 * q), (hx + 0.66 * q, 0.4 * q), (hx + 0.8 * q, 0.4 * q), (hx + 0.83 * q, 0.44 * q),
               (hx + 0.91 * q, 0.44 * q), (hx + 0.94 * q, 0.4 * q), (hx + 1.1 * q, 0.4 * q), (hx + 1.18 * q, 0.32 * q),
               (hx + 1.22 * q, 0.16 * q)], "hoist", 14, yh - 1.1 * q, 0.0, cap=True)
    m.box(at(-0.6, -1.3, 0.44), at(0.1, -0.72, 0.6), "panel")
    block(m, [at(-0.86, -2.5, -0.2), at(-0.44, -2.5, -0.2), at(-0.44, -2.5, 0.2), at(-0.86, -2.5, 0.2),
              at(-0.92, -1.54, -0.27), at(-0.38, -1.54, -0.27), at(-0.38, -1.54, 0.27), at(-0.92, -1.54, 0.27)],
          "hoist_dark")
    m.box(at(-0.95, -1.62, -0.3), at(-0.35, -1.5, 0.3), "hoist")
    sweep(m, [(xb, 17.68, cz), (xb + 0.3, 17.05, 0.9), (xb + 0.3, yh - 0.25, 0.97), at(-0.25, -0.62, 0.52)],
          0.055, 6, "cable")
    m.box((xb - 0.04, yh + 0.3, rz0), (xb + 0.04, 17.7, rz0 + 0.08), "hoist_dark")
    hook_y = 7.4
    hxc = hx - 0.05 * q
    chain(m, (hxc, yh - 1.55 * q, 0.0), (hxc, hook_y + 0.62 * q, 0.0), 0.42, 0.18, "chain")
    zlathe(m, [(-0.17 * q, 0.33 * q), (0.17 * q, 0.33 * q)], "hook", 16, hxc, hook_y + 0.3 * q, cap=True)
    m.box((hxc - 0.27 * q, hook_y + 0.3 * q, -0.14 * q), (hxc + 0.27 * q, hook_y + 0.66 * q, 0.14 * q), "hook")
    m.tube((hxc, hook_y, 0.0), (hxc, hook_y - 0.28 * q, 0.0), 0.09 * q, 0.09 * q, 10, "chain")
    hc = (hxc + 0.22 * q, hook_y - 0.62 * q)
    pts = [(hxc, hook_y - 0.26 * q, 0.0), (hxc, hook_y - 0.48 * q, 0.0)]
    radii = [0.085 * q, 0.085 * q]
    for i in range(10):
        a = math.pi + (math.pi * 1.25) * i / 9.0
        pts.append((hc[0] + 0.22 * q * math.cos(a), hc[1] + 0.22 * q * math.sin(a), 0.0))
        radii.append((0.085 - 0.045 * i / 9.0) * q)
    sweep(m, pts, radii, 8, "hook", caps=(False, True))
    beam(m, pts[-1], (hxc + 0.03, hook_y - 0.45 * q, 0.0), 0.06, 0.04, "rail", up=(0.0, 0.0, 1.0))
    # the pendant: its cable from the panel, the yellow box with its buttons and red stop
    px_ = hx - 0.42 * q
    m.tube((px_, yh - 1.3 * q, 0.75), (px_, 2.72, 0.75), 0.035, 0.035, 4, "cable")
    m.box((px_ - 0.15, 1.75, 0.63), (px_ + 0.15, 2.72, 0.87), "steel")
    m.box((px_ - 0.11, 2.72, 0.67), (px_ + 0.11, 2.84, 0.83), "rubber")
    for y in (1.92, 2.1, 2.28):
        m.box((px_ - 0.07, y, 0.85), (px_ + 0.07, y + 0.1, 0.91), "rubber")
    m.box((px_ - 0.07, 2.46, 0.85), (px_ + 0.07, 2.6, 0.95), "hook")
    return m


# ------------------------------------------------------------------------------------------------------------- mast

def _panel(m: sk.Model, cx: float, cz: float, normal: tuple, y0: float, y1: float, w: float, d: float,
           mat: str, cap_mat: str) -> None:
    """A sector antenna: a tall panel with rounded edges (a radome), `w` across and `d` deep, facing `normal`
    (horizontal), its middle at (cx, cz), from y0 to y1, with a darker end cap top and bottom."""
    n = Vector(normal).normalized()
    t = Vector((0.0, 1.0, 0.0)).cross(n)
    c = 0.035                       # the rounding
    outline = [(-w / 2 + c, -d / 2), (w / 2 - c, -d / 2), (w / 2, -d / 2 + c), (w / 2, d / 2 - c),
               (w / 2 - c, d / 2), (-w / 2 + c, d / 2), (-w / 2, d / 2 - c), (-w / 2, -d / 2 + c)]

    def ring(y: float, grow: float = 0.0) -> list:
        return [tuple(Vector((cx, y, cz)) + t * (a * (1.0 + grow)) + n * (b * (1.0 + grow))) for a, b in outline]

    m.rings([ring(y0 + 0.06), ring(y1 - 0.06)], mat)
    m.rings([ring(y0, 0.06), ring(y0 + 0.06, 0.06)], cap_mat, cap0=True)
    m.rings([ring(y1 - 0.06, 0.06), ring(y1, 0.06)], cap_mat, cap1=True)


def mast() -> sk.Model:
    """A phone mast with the field's floodlights (photos 103509-103605: a pale tapered monopole in sections with
    slip-joint collars and step bolts up it, a cable tray up its back, a head frame of tall rounded antenna panels in
    three sectors (front, back and either side) on mounting pipes that stand above them, radio units clamped under
    the head with their jumper cables, two radome dishes on side arms, a lightning rod; the floodlight bar the
    Range's yard is lit by stays on it under the dishes, four lamps on yokes tilted to the field, their glass the
    model's only LAMP faces; an equipment cabinet at its foot). 2.4 m across (X) x 0.5 m deep x 14 m tall, the
    antennas' front sector and the lamps facing +Z."""
    m = sk.Model("mast", {
        "pole": (1.0, vp.BODY), "pole_shade": (0.84, vp.BODY), "pole_dark": (0.66, vp.BODY),
        "antenna": (0xE2E4E0, vp.FIXED), "antenna_shade": (0xC2C6C4, vp.FIXED), "cap": (0x8F9496, vp.FIXED),
        "unit": (0x9AA0A4, vp.FIXED), "unit_dark": (0x6A7075, vp.FIXED), "frame": (0x70767B, vp.FIXED),
        "plinth": (sk.CONCRETE, vp.FIXED), "cable": (0x2E3134, vp.FIXED), "housing": (0x3A3E46, vp.FIXED),
        "glass": (0xD6D6D0, vp.LAMP), "cabinet": (0xB4B8B4, vp.FIXED), "galv": (sk.GALV, vp.FIXED),
    })
    W, D, H = 2.4, 0.5, 14.0
    sides = 16
    # the plinth (it sets the depth) and the base flange with its gussets and nuts
    block(m, [(-0.45, 0.0, -D / 2), (0.45, 0.0, -D / 2), (0.45, 0.0, D / 2), (-0.45, 0.0, D / 2),
              (-0.42, 0.3, -0.22), (0.42, 0.3, -0.22), (0.42, 0.3, 0.22), (-0.42, 0.3, 0.22)], "plinth")
    lathe(m, [(0.29, 0.21), (0.36, 0.21)], "pole_dark", sides, cap=True)
    for k in range(8):
        a = math.pi / 8 + 2.0 * math.pi * k / 8
        lathe(m, [(0.36, 0.025), (0.41, 0.025)], "frame", 6, (math.cos(a) * 0.185, 0.0, math.sin(a) * 0.185),
              cap=True)
    for k in range(4):
        a = 2.0 * math.pi * k / 4
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        plate(m, [tuple(d * 0.15 + Vector((0, 0.35, 0))), tuple(d * 0.205 + Vector((0, 0.35, 0))),
                  tuple(d * 0.15 + Vector((0, 0.85, 0)))], (-d.z, 0.0, d.x), 0.025, "pole_dark")
    # the pole: three tapering sections, the slip joints proud collars
    lathe(m, [(0.36, 0.17), (4.7, 0.155)], "pole", sides)
    lathe(m, [(4.6, 0.156), (4.7, 0.172), (4.92, 0.168), (5.0, 0.15)], "pole_shade", sides)
    lathe(m, [(4.98, 0.152), (9.3, 0.133)], "pole", sides)
    lathe(m, [(9.2, 0.134), (9.3, 0.15), (9.5, 0.146), (9.58, 0.128)], "pole_shade", sides)
    lathe(m, [(9.56, 0.129), (13.62, 0.11), (13.68, 0.125), (13.76, 0.06)], "pole", sides)
    # step bolts up both sides, staggered
    for k in range(25):
        y = 2.3 + 0.38 * k
        if 10.15 < y < 10.75:       # the lamp bar's arm
            continue
        s = 1.0 if k % 2 == 0 else -1.0
        r = 0.17 - 0.06 * (y / 13.6)
        m.tube((s * (r - 0.02), y, 0.0), (s * (r + 0.16), y + 0.015, 0.0), 0.016, 0.016, 4, "galv",
               caps=(False, True))
    # the cable tray up the back, its clamps, and the cables out of it into the cabinet
    m.box((-0.08, 0.6, -0.235), (0.08, 11.2, -0.205), "frame")
    for s in (-1.0, 1.0):
        m.box((s * 0.08 - 0.012, 0.6, -0.235), (s * 0.08 + 0.012, 11.2, -0.17), "frame")
    m.box((-0.05, 0.6, -0.208), (0.05, 11.15, -0.17), "cable")
    for k in range(9):
        y = 1.4 + 1.15 * k
        m.box((-0.1, y, -0.245), (0.1, y + 0.06, -0.14), "galv")
    sweep(m, [(0.0, 0.65, -0.19), (0.12, 0.45, -0.17), (0.45, 0.4, -0.12), (0.62, 0.62, -0.1)], 0.045, 6, "cable")
    # the equipment cabinet at the foot: on its own slab, a door seam, louvres, an overhanging lid
    m.box((0.48, 0.0, -0.24), (1.15, 0.16, 0.24), "plinth")
    m.box((0.53, 0.16, -0.19), (1.1, 1.45, 0.19), "cabinet")
    m.box((0.5, 1.45, -0.22), (1.13, 1.52, 0.22), "unit_dark")
    m.box((0.81, 0.24, 0.185), (0.825, 1.38, 0.2), "unit_dark")
    for y in (0.4, 0.5, 0.6, 1.1, 1.2):
        m.box((0.6, y, 0.185), (0.77, y + 0.04, 0.2), "unit_dark")
    m.box((0.86, 0.75, 0.185), (0.9, 0.92, 0.215), "frame")

    # the floodlight bar: an arm on struts, four lamps on yokes tilted down to the field, glass a hair proud
    ly = 10.4
    m.box((-1.12, ly - 0.42, -0.05), (1.12, ly - 0.32, 0.05), "frame")
    for s in (-1.0, 1.0):
        beam(m, (s * 0.12, 9.75, 0.0), (s * 0.85, ly - 0.36, 0.0), 0.06, 0.06, "frame")
    m.box((-0.16, ly - 0.55, 0.1), (0.16, ly - 0.25, 0.22), "housing")
    tilt = math.radians(12.0)
    f = Vector((0.0, -math.sin(tilt), math.cos(tilt)))     # the lamps' facing
    up = Vector((0.0, math.cos(tilt), math.sin(tilt)))
    ex = Vector((1.0, 0.0, 0.0))
    for k in range(4):
        x = -0.9 + 0.6 * k
        c = Vector((x, ly, 0.055))
        fr, bk = c + f * 0.1, c - f * 0.13
        ring_f = [fr - ex * 0.25 - up * 0.2, fr + ex * 0.25 - up * 0.2, fr + ex * 0.25 + up * 0.2,
                  fr - ex * 0.25 + up * 0.2]
        ring_b = [bk - ex * 0.17 - up * 0.13, bk + ex * 0.17 - up * 0.13, bk + ex * 0.17 + up * 0.13,
                  bk - ex * 0.17 + up * 0.13]
        block(m, [tuple(p) for p in ring_b + ring_f], "housing")
        g = [fr + f * 0.006 + ex * a + up * b for a, b in ((-0.21, -0.165), (0.21, -0.165), (0.21, 0.165),
                                                             (-0.21, 0.165))]
        m.face([tuple(p) for p in g], "glass", tuple(f))
        # the visor over the glass
        plate(m, [tuple(fr + up * 0.21 - ex * 0.26), tuple(fr + up * 0.21 + ex * 0.26),
                  tuple(fr + up * 0.17 + ex * 0.26 + f * 0.035), tuple(fr + up * 0.17 - ex * 0.26 + f * 0.035)],
              up, 0.015, "housing")
        # the yoke from the arm, its pivots either side
        for s in (-1.0, 1.0):
            m.box((x + s * 0.27 - 0.015, ly - 0.33, 0.0), (x + s * 0.27 + 0.015, ly + 0.02, 0.07), "frame")
            m.tube((x + s * 0.26, ly - 0.02, 0.035), (x + s * 0.3, ly - 0.02, 0.035), 0.035, 0.035, 8, "frame",
                   caps=(False, True))
        m.box((x - 0.27, ly - 0.35, 0.0), (x + 0.27, ly - 0.31, 0.07), "frame")
        sweep(m, [(x, ly - 0.08, -0.07), (x * 0.9, ly - 0.3, -0.08), (x * 0.5, ly - 0.45, -0.1),
                  (0.0, ly - 0.6, -0.16)], 0.018, 4, "cable")

    # the dishes on side arms above the lamps, facing out to either side: a radome, its shroud, the back can
    for s, y, r in ((-1.0, 11.15, 0.22), (1.0, 10.95, 0.17)):
        m.tube((0.0, y, 0.0), (s * 0.62, y, 0.0), 0.03, 0.03, 6, "frame")
        m.box((s * 0.2 - 0.03, y - 0.25, -0.03), (s * 0.2 + 0.03, y + 0.25, 0.03), "frame")
        xb = s * 0.6
        prof = [(xb, 0.05), (xb + s * 0.06, r * 0.55), (xb + s * 0.11, r * 0.95), (xb + s * 0.13, r),
                (xb + s * 0.24, r), (xb + s * 0.26, r * 0.85), (xb + s * 0.275, r * 0.5), (xb + s * 0.28, r * 0.1)]
        xlathe(m, prof, "antenna", sides, y, 0.0, cap=True)
        xlathe(m, [(xb + s * 0.125, r + 0.012), (xb + s * 0.16, r + 0.012)], "antenna_shade", sides, y, 0.0)
        xlathe(m, [(xb + s * 0.16, r + 0.012), (xb + s * 0.125, r + 0.012)], "antenna_shade", sides, y, 0.0)

    # radio units clamped round the pole under the head, front and back, each with a darker finned face
    for z, s in ((0.13, 1.0), (-0.13, -1.0)):
        for x in (-0.33, 0.33):
            m.box((x - 0.15, 11.15, z - 0.07), (x + 0.15, 11.68, z + 0.07), "unit")
            m.box((x - 0.12, 11.2, s * 0.199), (x + 0.12, 11.63, s * 0.215), "unit_dark")
            m.box((x * 0.2 - 0.02, 11.25, z - 0.08), (x * 1.0 - s * 0.0, 11.32, z - 0.06), "frame")
    m.box((-0.5, 11.3, -0.02), (0.5, 11.36, 0.02), "frame")
    # the head frame: two cross arms with stand-offs, mounting pipes standing above the panels
    for y in (11.86, 13.5):
        m.box((-1.1, y - 0.04, -0.035), (1.1, y + 0.04, 0.035), "frame")
        for x in (-0.36, 0.36):
            m.box((x - 0.03, y - 0.035, -0.2), (x + 0.03, y + 0.035, 0.2), "frame")
    for x in (-0.36, 0.36):
        for z in (-0.11, 0.11):
            m.tube((x, 11.7, z), (x, 13.98, z), 0.024, 0.024, 6, "galv", caps=(False, True))
    for s in (-1.0, 1.0):
        m.tube((s * 0.98, 11.7, 0.0), (s * 0.98, 13.98, 0.0), 0.024, 0.024, 6, "galv", caps=(False, True))
    # the panels: two to the front, two to the back, one either side
    for x in (-0.36, 0.36):
        _panel(m, x, 0.16, (0.0, 0.0, 1.0), 11.72, 13.9, 0.3, 0.1, "antenna", "cap")
        _panel(m, x, -0.16, (0.0, 0.0, -1.0), 11.72, 13.9, 0.3, 0.1, "antenna_shade", "cap")
    for s in (-1.0, 1.0):
        _panel(m, s * (W / 2 - 0.053), 0.0, (s, 0.0, 0.0), 11.82, 13.82, 0.3, 0.1, "antenna", "cap")
        m.box((s * 0.98 - 0.03, 12.2, -0.03), (s * (W / 2 - 0.1), 12.26, 0.03), "frame")
        m.box((s * 0.98 - 0.03, 13.3, -0.03), (s * (W / 2 - 0.1), 13.36, 0.03), "frame")
    # the jumpers: from each panel's foot down to its radio unit
    for x in (-0.36, 0.36):
        for z in (0.16, -0.16):
            for dx in (-0.06, 0.06):
                sweep(m, [(x + dx, 11.7, z), (x + dx * 1.6, 11.55, z * 1.25), (x * 0.9 + dx, 11.7, z * 0.7)],
                      0.016, 4, "cable")
    for s in (-1.0, 1.0):
        sweep(m, [(s * 1.147, 11.8, 0.0), (s * 1.0, 11.5, 0.05), (s * 0.6, 11.45, 0.1), (s * 0.46, 11.5, 0.06)],
              0.02, 4, "cable")
    # the lamps' conduit down the pole's front from their junction box to the cabinet, strapped at each section
    sweep(m, [(0.09, ly - 0.55, 0.128), (0.09, 1.55, 0.177), (0.13, 1.2, 0.18), (0.3, 1.0, 0.16), (0.55, 0.98, 0.1)],
          0.03, 6, "galv")
    for y in (2.6, 4.3, 6.4, 8.2):
        t = (y - 1.55) / (ly - 0.55 - 1.55)
        m.box((0.03, y, 0.1), (0.15, y + 0.05, 0.215 - 0.05 * t), "frame")
    # the lightning rod
    m.tube((0.0, 13.74, 0.0), (0.0, H, 0.0), 0.022, 0.008, 5, "galv")
    return m


# ------------------------------------------------------------------------------------------------------ water tower

def _hoop(m: sk.Model, radius: float, y: float, r: float, sides: int, segments: int, mat: str) -> None:
    """A ring of round bar (a railing's rail) of `radius` about the vertical axis at height `y`, the bar `r` thick,
    one corner of the ring on each axis."""
    rings = []
    for k in range(segments + 1):
        a = 2.0 * math.pi * k / segments
        c, s = math.cos(a), math.sin(a)
        rings.append([((radius + r * math.cos(b)) * c, y + r * math.sin(b), (radius + r * math.cos(b)) * s)
                      for b in (2.0 * math.pi * i / sides for i in range(sides))])
    m.rings(rings, mat)


def water_tower() -> sk.Model:
    """A water tower (photos 103841-103911, after 103841 most: a drum tank with welded seams under a low conical roof
    overhanging it, a vent finial with its rod, a deep rounded bowl under it; a balcony walkway round the drum's foot
    on brackets, its railing of posts, two rails and a toe board; four tall laced lattice legs leaning in from a wide
    stance on concrete piers, laced struts between them at three levels and crossed tie rods in every bay; a big
    riser pipe with flanged joints up the middle into the bowl; a caged ladder up the front to the balcony, on up the
    drum and over the eave, a short ladder up the roof to a hatch). 6.45 m across, 22 m tall."""
    m = sk.Model("water_tower", {
        "tank": (1.0, vp.BODY), "tank_shade": (0.86, vp.BODY), "tank_dark": (0.72, vp.BODY),
        "legs": (0xA5AAAE, vp.FIXED), "legs_dark": (0x80868B, vp.FIXED), "rods": (0x8E949A, vp.FIXED),
        "rail": (0x7C8288, vp.FIXED), "pad": (sk.CONCRETE, vp.FIXED), "riser": (0x9EA2A3, vp.FIXED),
        "riser_dark": (0x7A7E80, vp.FIXED),
    })
    H, R = 22.0, 2.6
    sides = 24
    bowl = 3.9                  # the bowl's depth, about three quarters of the tank's width
    bal_y = 16.6                # the balcony's floor: the bowl's rim and the drum's foot
    tank_top = bal_y + 3.5      # the drum, about two thirds of its width tall
    eave = R + 0.4              # the roof's overhang
    roof_top = H - 0.75
    rail_r = 3.2                # the balcony's top rail (with its bar, the model's half width, 3.225 m)
    # the bowl: half an ellipse into the riser, the drum with two welded seams, the roof with its drip skirt
    prof = []
    for k in range(6):
        t = math.pi * 0.5 * k / 5
        prof.append((bal_y - bowl * math.cos(t), max(0.36, R * math.sin(t))))
    lathe(m, prof, "tank_shade", sides, cap=True)
    lathe(m, [(bal_y, R), (bal_y + 1.72, R), (bal_y + 1.72, R + 0.025), (bal_y + 1.8, R + 0.025), (bal_y + 1.8, R),
              (tank_top, R)], "tank", sides)
    lathe(m, [(tank_top, R), (tank_top - 0.1, eave - 0.03), (tank_top, eave), (tank_top + 0.2, eave)], "tank_dark",
          sides)
    lathe(m, [(tank_top + 0.2, eave), (tank_top + 0.24, eave - 0.1), (roof_top, 0.42), (roof_top + 0.03, 0.3)],
          "tank_shade", sides)
    # the finial: a vent with a mushroom cap, its rod
    lathe(m, [(roof_top, 0.3), (roof_top + 0.25, 0.22), (roof_top + 0.27, 0.36), (roof_top + 0.47, 0.06)],
          "tank_dark", 12, cap=True)
    m.tube((0.0, roof_top + 0.45, 0.0), (0.0, H, 0.0), 0.03, 0.012, 5, "rail")
    # the roof hatch by the ladder's head
    hz = 1.55
    hy = tank_top + 0.24 + (eave - 0.1 - hz) / (eave - 0.1 - 0.42) * (roof_top - tank_top - 0.24)
    m.box((-0.35, hy - 0.2, hz - 0.35), (0.35, hy + 0.32, hz + 0.25), "tank_dark")
    m.box((-0.4, hy + 0.3, hz - 0.4), (0.4, hy + 0.38, hz + 0.3), "tank_shade")

    def roof_at(r: float) -> float:
        return tank_top + 0.24 + (eave - 0.1 - r) / (eave - 0.1 - 0.42) * (roof_top - tank_top - 0.24)


    # the balcony: its floor round the drum's foot, a toe board, posts, a mid rail and the top rail, brackets under it
    fo = rail_r - 0.05
    seg = 28
    turns = [2.0 * math.pi * i / seg for i in range(seg)]
    floor_in = [(R * math.cos(a), bal_y, R * math.sin(a)) for a in turns]
    floor_out = [(fo * math.cos(a), bal_y, fo * math.sin(a)) for a in turns]
    m.rings([floor_in, floor_out], "rail", out=(0.0, 1.0, 0.0))
    low = [(x, y - 0.12, z) for x, y, z in floor_out]
    m.rings([[(x, y - 0.12, z) for x, y, z in floor_in], low], "legs_dark", out=(0.0, -1.0, 0.0))
    toe = [(x, y + 0.14, z) for x, y, z in floor_out]
    m.rings([low, toe], "rail")
    m.rings([low, toe], "rail", inward=True)
    _hoop(m, rail_r, bal_y + 1.05, 0.025, 3, seg, "rail")
    _hoop(m, rail_r - 0.02, bal_y + 0.55, 0.02, 3, seg, "rail")
    for i in range(seg):
        a = 2.0 * math.pi * i / seg
        c, s = math.cos(a), math.sin(a)
        if i % 2 or i == seg // 4:  # every other one, and none in the ladder's way through
            continue
        m.tube((fo * c, bal_y + 0.1, fo * s), ((rail_r - 0.01) * c, bal_y + 1.05, (rail_r - 0.01) * s), 0.025, 0.025,
               3, "rail")
    for i in range(0, seg, 2):
        a = 2.0 * math.pi * (i + 0.5) / seg
        c, s = math.cos(a), math.sin(a)
        rb = R * math.sin(math.acos(1.1 / bowl))
        m.tube((rb * c, bal_y - 1.1, rb * s), ((fo - 0.1) * c, bal_y - 0.1, (fo - 0.1) * s), 0.05, 0.05, 4,
               "legs_dark")

    # the legs: four laced lattice columns, two channels each with a zigzag of bars between, on concrete piers
    foot_r, head_r = 3.8, R + 0.06
    angles = [math.pi * 0.25 + k * math.pi * 0.5 for k in range(4)]
    leg_y0 = 0.55

    def leg_at(i: int, y: float) -> Vector:
        a = angles[i]
        r = foot_r + (head_r - foot_r) * (y - leg_y0) / (bal_y - leg_y0)
        return Vector((r * math.cos(a), y, r * math.sin(a)))

    for i, a in enumerate(angles):
        rad = Vector((math.cos(a), 0.0, math.sin(a)))
        tan = Vector((-math.sin(a), 0.0, math.cos(a)))
        f = leg_at(i, 0.0)
        block(m, [tuple(f + Vector((dx, 0.0, dz))) for dx, dz in ((-0.45, -0.45), (0.45, -0.45), (0.45, 0.45),
                                                                 (-0.45, 0.45))] +
              [tuple(f + Vector((dx, 0.45, dz))) for dx, dz in ((-0.38, -0.38), (0.38, -0.38), (0.38, 0.38),
                                                                (-0.38, 0.38))], "pad")
        m.box(tuple(f + Vector((-0.34, 0.43, -0.34))), tuple(f + Vector((0.34, 0.55, 0.34))), "legs_dark")
        p0, p1 = leg_at(i, leg_y0), leg_at(i, bal_y + 0.05)
        for s in (-1.0, 1.0):
            beam(m, p0 + tan * s * 0.17, p1 + tan * s * 0.17, 0.08, 0.34, "legs")
        n = 34                      # the lacing: flat bars zigzagging between the channels, seen from either side
        ax = p1 - p0
        along = ax.normalized() * 0.035
        for k in range(n):
            qa = p0 + ax * (k / n) + tan * (0.15 if k % 2 == 0 else -0.15)
            qb = p0 + ax * ((k + 1) / n) + tan * (-0.15 if k % 2 == 0 else 0.15)
            strip = [qa - along, qb - along, qb + along, qa + along]
            for side in (-1.0, 1.0):
                m.face([tuple(p + rad * side * 0.012) for p in strip], "legs_dark", tuple(rad * side))
    # the struts: laced girders between the legs at three levels, and crossed tie rods in every bay
    levels = [leg_y0, 4.8, 8.9, 12.8, bal_y - 1.0]
    for y in levels[1:4]:
        for i in range(4):
            a, b = leg_at(i, y), leg_at((i + 1) % 4, y)
            d = (b - a).normalized()
            a, b = a + d * 0.22, b - d * 0.22
            for dy in (-0.2, 0.2):
                m.tube(tuple(a + Vector((0, dy, 0))), tuple(b + Vector((0, dy, 0))), 0.06, 0.06, 4, "legs")
            n = 5
            for k in range(n):
                qa = a + (b - a) * (k / n) + Vector((0, 0.17 if k % 2 == 0 else -0.17, 0))
                qb = a + (b - a) * ((k + 1) / n) + Vector((0, -0.17 if k % 2 == 0 else 0.17, 0))
                m.tube(tuple(qa), tuple(qb), 0.025, 0.025, 3, "legs_dark")
    for ya, yb_ in zip(levels, levels[1:]):
        for i in range(4):
            j = (i + 1) % 4
            for u, v in ((i, j), (j, i)):
                pa, pb = leg_at(u, ya + (0.3 if ya > 1.0 else 0.4)), leg_at(v, yb_ - 0.3)
                m.tube(tuple(pa), tuple(pb), 0.03, 0.03, 3, "rods")
    # the riser: up the middle into the bowl, flanged joints, a footing
    rr = 0.36
    prof = [(0.0, rr)]
    for y in (4.2, 9.0):
        prof += [(y - 0.08, rr), (y - 0.08, rr + 0.07), (y + 0.08, rr + 0.07), (y + 0.08, rr)]
    prof.append((bal_y - bowl + 0.25, rr))
    lathe(m, prof, "riser", 12)
    block(m, [(-0.7, 0.0, -0.7), (0.7, 0.0, -0.7), (0.7, 0.0, 0.7), (-0.7, 0.0, 0.7),
              (-0.62, 0.3, -0.62), (0.62, 0.3, -0.62), (0.62, 0.3, 0.62), (-0.62, 0.3, 0.62)], "pad")
    lathe(m, [(0.3, rr + 0.12), (0.45, rr + 0.12)], "riser_dark", 12, cap=True)

    # the ladder up the front: from the ground to the balcony, caged from 2.6 m; on up the drum, caged, over the eave
    zl, zu = 2.85, R + 0.22
    for dx in (-0.22, 0.22):
        m.box((dx - 0.025, 0.0, zl - 0.04), (dx + 0.025, bal_y + 1.05, zl + 0.04), "rail")
        m.box((dx - 0.025, bal_y + 0.95, zu - 0.04), (dx + 0.025, tank_top + 0.1, zu + 0.04), "rail")
        sweep(m, [(dx, tank_top + 0.05, zu), (dx, tank_top + 0.5, zu), (dx, tank_top + 0.66, zu - 0.12),
                  (dx, tank_top + 0.62, zu - 0.3), (dx, roof_at(zu - 0.42) + 0.02, zu - 0.42)], 0.025, 4, "rail")
    for y0, y1, z in ((0.35, bal_y, zl), (bal_y + 0.3, tank_top - 0.2, zu)):
        k = 0
        y = y0
        while y < y1:
            m.tube((-0.2, y, z), (0.2, y, z), 0.02, 0.02, 3, "rods")
            k += 1
            y = y0 + 0.4 * k
    for y in levels[1:4]:                # stand-offs to the front struts
        z0 = leg_at(0, y).z
        for dx in (-0.25, 0.2):
            m.box((dx, y - 0.04, z0), (dx + 0.05, y + 0.04, zl), "rail")
    for y in (bal_y + 1.4, tank_top - 0.5):
        m.box((-0.25, y, R - 0.02), (0.25, y + 0.07, zu), "rail")

    def cage(z: float, y0: float, y1: float, r: float, step: float) -> None:
        n = int((y1 - y0) / step) + 1
        for k in range(n):
            y = y0 + (y1 - y0) * k / max(1, n - 1)
            pts = [(r * math.cos(math.pi * i / 4), y, z + r * math.sin(math.pi * i / 4) * 0.95) for i in range(5)]
            sweep(m, [(0.22, y, z)] + pts + [(-0.22, y, z)], 0.022, 3, "rail")
        for i in (1, 2, 3):
            a = math.pi * i / 4
            x, dz = r * math.cos(a), r * math.sin(a) * 0.95
            m.box((x - 0.025, y0, z + dz - 0.012), (x + 0.025, y1, z + dz + 0.012), "rail")

    cage(zl, 2.6, bal_y - 0.3, 0.34, 1.4)
    cage(zu, bal_y + 2.3, tank_top - 0.15, 0.3, 0.9)
    return m
