"""Fitting helpers for the figure's gear (BL12, 2026-11-05): the torso measured by rays, contours round it, sheet
mappings that wrap flat-built parts onto a contour, sweeps along paths and the clearance check.

Blender space: metres, +Z up, the figure faces -Y, its left is +X. Angles round the torso (theta) start at the front
(-Y) and grow towards the figure's left (+X), so they run to the viewer's right seen from outside, front or back.
Every flat-built "sheet" part is made as if seen from the front: +X along the surface to the viewer's right, +Z up,
-Y out of the surface (towards the viewer). `Sheet.warp` then lays it on a contour.
"""

import math

import bpy  # first: it brings bmesh and mathutils with it
import bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree


def body_tree(ob: bpy.types.Object) -> BVHTree:
    """A BVH of `ob`'s evaluated mesh in world space (the rest pose when its armature is at rest)."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = ev.to_mesh()
    verts = [ob.matrix_world @ v.co for v in me.vertices]
    polys = [tuple(p.vertices) for p in me.polygons]
    ev.to_mesh_clear()
    return BVHTree.FromPolygons(verts, polys)


def way(theta: float) -> Vector:
    """The horizontal unit direction at angle `theta` (radians) round the torso."""
    return Vector((math.sin(theta), -math.cos(theta), 0.0))


class Torso:
    """The body's radius round a vertical axis through (0, axis_y), measured by rays cast out from the axis, so arms
    beside the torso are never met first (or, given `outside`, in from that far out, for the hips: the outermost
    layer, inside the hanging arms). `r(z, theta)` interpolates the grid; holes take their neighbours' value."""

    def __init__(self, tree: BVHTree, z0: float, z1: float, dz: float = 0.01, dtheta_deg: float = 3.0,
                 axis_y: float = 0.0, reach: float = 0.3, outside: float = 0.0):
        self.tree = tree
        self.z0, self.dz = z0, dz
        self.axis_y = axis_y
        self.nz = int(round((z1 - z0) / dz)) + 1
        self.na = int(round(360.0 / dtheta_deg))
        self.grid = []
        for i in range(self.nz):
            z = z0 + i * dz
            row = []
            for j in range(self.na):
                t = math.tau * j / self.na
                if outside > 0.0:
                    # From `outside` out, in towards the axis: the outermost surface (inner layers ignored).
                    o = Vector((0.0, axis_y, z)) + way(t) * outside
                    hit = tree.ray_cast(o, -way(t), outside)
                    row.append(outside - hit[3] if hit[0] is not None else None)
                else:
                    hit = tree.ray_cast(Vector((0.0, axis_y, z)), way(t), reach)
                    row.append(hit[3] if hit[0] is not None else None)
            self.grid.append(self._fill(row))

    @staticmethod
    def _fill(row: list) -> list:
        known = [(j, r) for j, r in enumerate(row) if r is not None]
        if not known:
            return [0.12] * len(row)
        out = list(row)
        n = len(row)
        for j in range(n):
            if out[j] is None:
                best = min(known, key=lambda k: min(abs(k[0] - j), n - abs(k[0] - j)))
                out[j] = best[1]
        return out

    def r(self, z: float, theta: float) -> float:
        fz = min(max((z - self.z0) / self.dz, 0.0), self.nz - 1.0)
        i0 = int(fz)
        i1 = min(i0 + 1, self.nz - 1)
        tz = fz - i0
        fa = (theta % math.tau) / math.tau * self.na
        j0 = int(fa) % self.na
        j1 = (j0 + 1) % self.na
        ta = fa - int(fa)
        a = self.grid[i0][j0] * (1 - ta) + self.grid[i0][j1] * ta
        b = self.grid[i1][j0] * (1 - ta) + self.grid[i1][j1] * ta
        return a * (1 - tz) + b * tz

    def point(self, z: float, theta: float, off: float = 0.0) -> Vector:
        return Vector((0.0, self.axis_y, z)) + way(theta) * (self.r(z, theta) + off)

    def band_radii(self, z0: float, z1: float, gap: float, smooth_deg: float = 12.0, step_deg: float = 2.0,
                   bridge_deg: float = 40.0) -> list:
        """(theta, radius) all the way round: the widest the body gets between z0 and z1 at each angle, smoothed
        round (a stiff band doesn't follow every dip), plus `gap`."""
        n = int(round(360.0 / step_deg))
        raw = []
        for j in range(n):
            t = math.tau * j / n
            raw.append(max(self.r(z0 + (z1 - z0) * k / 8.0, t) for k in range(9)))
        # Bridge dips narrower than `bridge_deg` (a stiff band spans them): the farthest chord between samples either
        # side that crosses each angle's ray.
        pts = [way(math.tau * j / n) * raw[j] for j in range(n)]
        conv = list(raw)
        span = max(1, int(round(bridge_deg / step_deg)))
        for j in range(n):
            d = way(math.tau * j / n)
            for k in range(1, span + 1):
                a, b = pts[(j - k) % n], pts[(j + k) % n]
                e = b - a
                # Solve a + e t = d r for r (2D, z is 0).
                det = e.x * (-d.y) - e.y * (-d.x)
                if abs(det) < 1e-9:
                    continue
                t = ((-a.x) * (-d.y) - (-a.y) * (-d.x)) / det
                if 0.0 <= t <= 1.0:
                    r = (a + e * t).length
                    conv[j] = max(conv[j], r)
        w = max(1, int(round(smooth_deg / step_deg)))
        sm = []
        for j in range(n):
            vals = [conv[(j + k) % n] for k in range(-w, w + 1)]
            sm.append(max(conv[j], sum(vals) / len(vals)) + gap)
        return [(math.tau * j / n, sm[j]) for j in range(n)]


class Contour:
    """A horizontal polyline (XY points) walked by arc length s from its first point, with its outward normal (the
    side facing away from `centre`)."""

    def __init__(self, pts: list, centre: tuple = (0.0, 0.0)):
        self.p = [Vector((x, y)) for x, y in pts]
        self.c = Vector(centre)
        self.s = [0.0]
        for a, b in zip(self.p, self.p[1:]):
            self.s.append(self.s[-1] + (b - a).length)
        self.length = self.s[-1]

    def _seg(self, s: float) -> tuple:
        s = min(max(s, 0.0), self.length)
        lo, hi = 0, len(self.s) - 1
        while hi - lo > 1:
            mid = (lo + hi) // 2
            if self.s[mid] <= s:
                lo = mid
            else:
                hi = mid
        seg = self.s[hi] - self.s[lo]
        t = 0.0 if seg <= 0.0 else (s - self.s[lo]) / seg
        return lo, hi, t

    def at(self, s: float) -> tuple:
        """(point, tangent, outward normal), each a 2D Vector, at arc length `s` (clamped to the ends, extrapolated
        straight beyond them)."""
        extra = 0.0
        if s < 0.0:
            extra, s = s, 0.0
        elif s > self.length:
            extra, s = s - self.length, self.length
        lo, hi, t = self._seg(s)
        p = self.p[lo].lerp(self.p[hi], t)
        tan = (self.p[hi] - self.p[lo]).normalized()
        # Average with the neighbouring segments' directions for smooth normals.
        if 0 < lo and t < 0.5:
            prev = (self.p[lo] - self.p[lo - 1]).normalized()
            tan = prev.lerp(tan, 0.5 + t).normalized()
        elif hi < len(self.p) - 1 and t >= 0.5:
            nxt = (self.p[hi + 1] - self.p[hi]).normalized()
            tan = tan.lerp(nxt, t - 0.5).normalized()
        p = p + tan * extra
        n = Vector((tan.y, -tan.x))
        if n.dot(p - self.c) < 0.0:
            n = -n
        return p, tan, n

    def s_where(self, test) -> float:
        """The first arc length (sampled every mm) at which `test(point)` holds."""
        s = 0.0
        while s <= self.length:
            if test(self.at(s)[0]):
                return s
            s += 0.001
        return self.length


def arc_contour(theta0: float, theta1: float, radii: list, centre_y: float = 0.0) -> Contour:
    """The contour of (theta, radius) samples from theta0 to theta1 (radians; theta1 may pass 2 pi)."""
    out = []
    n = len(radii)
    step = math.tau / n
    t = theta0
    while t <= theta1 + 1e-9:
        f = (t % math.tau) / step
        j0 = int(f) % n
        j1 = (j0 + 1) % n
        a = f - int(f)
        r = radii[j0][1] * (1 - a) + radii[j1][1] * a
        d = way(t)
        out.append((d.x * r, centre_y + d.y * r))
        t += step / 2.0
    return Contour(out, (0.0, centre_y))


def circle_contour(radius: float, face_y: float, facing: float, half_width: float, step: float = 0.004) -> Contour:
    """A vertical cylinder's arc, its middle at (0, face_y) facing -Y (facing -1, the front) or +Y (facing 1, the
    back), running from the viewer's left to right across 2 * half_width. Arc length 0 is at the left end."""
    out = []
    n = max(2, int(math.ceil(2.0 * half_width / step)))
    for i in range(n + 1):
        u = -half_width + 2.0 * half_width * i / n
        a = u / radius
        x = radius * math.sin(a)
        y = face_y - facing * (radius * (1.0 - math.cos(a)))
        out.append((x if facing < 0 else -x, y))
    centre = (0.0, face_y - facing * radius)
    c = Contour(out, centre)
    # The outward side faces away from the cylinder's own axis.
    return c


class Sheet:
    """Lays flat-built geometry onto a contour: local x is arc length from `s0`, local z is height, -y is outward."""

    def __init__(self, contour: Contour, s0: float, w0: float = 0.0, inset=None):
        self.c = contour
        self.s0 = s0
        self.w0 = w0
        # Optional: a function of height giving how far the sheet is drawn in towards the body there (an Inset).
        self.inset = inset

    def _drawn_in(self, z: float) -> tuple:
        return self.inset.at(z) if self.inset is not None else (0.0, 0.0)

    def map(self, co: Vector) -> Vector:
        p, _tan, n = self.c.at(self.s0 + co.x)
        w = self.w0 - co.y - self._drawn_in(co.z)[0]
        return Vector((p.x + n.x * w, p.y + n.y * w, co.z))

    def warp(self, ob: bpy.types.Object) -> None:
        me = ob.data
        for v in me.vertices:
            v.co = self.map(v.co)
        me.update()

    def frame(self, u: float, z: float, w: float = 0.0) -> Matrix:
        """A rigid frame on the sheet at (u, z), w out from it: x along it, -y out of it, z up."""
        p, tan, n = self.c.at(self.s0 + u)
        d, slope = self._drawn_in(z)
        w = self.w0 + w - d
        o = Vector((p.x + n.x * w, p.y + n.y * w, z))
        nn = Vector((n.x, n.y, 0.0)).normalized()
        # Up the sheet, which leans as it is drawn in more or less with height.
        up = (Vector((0.0, 0.0, 1.0)) - nn * slope).normalized()
        x = Vector((tan.x, tan.y, 0.0)).normalized()
        y = -(nn - up * nn.dot(up)).normalized()
        m = Matrix.Identity(4)
        for i in range(3):
            m[i][0], m[i][1], m[i][2], m[i][3] = x[i], y[i], up[i], o[i]
        return m


class Inset:
    """How far a plate is drawn in towards the body at each height: sampled every `step` from `z0`, smoothed."""

    def __init__(self, z0: float, step: float, values: list):
        self.z0, self.step, self.v = z0, step, values

    def at(self, z: float) -> tuple:
        f = (z - self.z0) / self.step
        i = max(0, min(len(self.v) - 2, int(math.floor(f))))
        t = max(0.0, min(1.0, f - i))
        return self.v[i] + (self.v[i + 1] - self.v[i]) * t, (self.v[i + 1] - self.v[i]) / self.step


def plate_inset(tree, contour: Contour, s0: float, half: float, z0: float, z1: float, need) -> Inset:
    """Draws a plate built on `contour` in towards the body, as close as `need(u, z)` allows at its nearest point across
    its width at each height (never into it), then smooths that up the plate so it bends, not kinks."""
    step = 0.01
    zs = [z0 - 0.02 + step * i for i in range(int((z1 - z0 + 0.04) / step) + 2)]
    raw = []
    for z in zs:
        best = None
        u = -half
        while u <= half + 1e-6:
            p, _tan, n = contour.at(s0 + u)
            nn = Vector((n.x, n.y, 0.0)).normalized()
            start = Vector((p.x, p.y, z)) + nn * 0.25
            hit = tree.ray_cast(start, -nn, 0.6)[0]
            if hit is not None:
                room = (Vector((p.x, p.y, z)) - hit).dot(nn) - need(u, z)
                best = room if best is None else min(best, room)
            u += 0.02
        raw.append(best if best is not None else 0.0)
    # The lowest room within 3 cm, then averaged over 3 cm: a smooth curve that stays clear of the body.
    k = 3
    low = [min(raw[max(0, i - k):i + k + 1]) for i in range(len(raw))]
    smooth = [sum(low[max(0, i - k):i + k + 1]) / len(low[max(0, i - k):i + k + 1]) for i in range(len(low))]
    return Inset(zs[0], step, smooth)


def subdivide_x(ob: bpy.types.Object, step: float) -> None:
    """Cuts `ob` with planes across x every `step`, so it bends smoothly when warped."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    xs = [v.co.x for v in bm.verts]
    x = math.floor(min(xs) / step) * step + step
    while x < max(xs):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(x, 0.0, 0.0), plane_no=(1.0, 0.0, 0.0))
        x += step
    bm.to_mesh(ob.data)
    bm.free()


def subdivide_z(ob: bpy.types.Object, step: float) -> None:
    """Cuts `ob` with level planes every `step` up, for a pillow's bulge."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    zs = [v.co.z for v in bm.verts]
    z = math.floor(min(zs) / step) * step + step
    while z < max(zs):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0.0, 0.0, z), plane_no=(0.0, 0.0, 1.0))
        z += step
    bm.to_mesh(ob.data)
    bm.free()


def pillow(ob: bpy.types.Object, amount: float, outer: float) -> None:
    """Bulges the outer face (local y below `outer`) of a flat-built part out by up to `amount` at its middle,
    falling to nothing at its edges, like a filled fabric bag."""
    xs = [v.co.x for v in ob.data.vertices]
    zs = [v.co.z for v in ob.data.vertices]
    cx, hx = (min(xs) + max(xs)) / 2, max(1e-4, (max(xs) - min(xs)) / 2)
    cz, hz = (min(zs) + max(zs)) / 2, max(1e-4, (max(zs) - min(zs)) / 2)
    for v in ob.data.vertices:
        if v.co.y < outer:
            u = min(1.0, abs(v.co.x - cx) / hx)
            w = min(1.0, abs(v.co.z - cz) / hz)
            v.co.y -= amount * (1.0 - u * u) * (1.0 - w * w)
    ob.data.update()


def smooth_path(pts: list, rounds: int = 3) -> list:
    pts = [Vector(p) for p in pts]
    for _ in range(rounds):
        pts = [pts[0]] + [(pts[i - 1] + pts[i] * 2.0 + pts[i + 1]) / 4.0 for i in range(1, len(pts) - 1)] + [pts[-1]]
    return pts


def resample(pts: list, step: float) -> list:
    pts = [Vector(p) for p in pts]
    s = [0.0]
    for a, b in zip(pts, pts[1:]):
        s.append(s[-1] + (b - a).length)
    n = max(2, int(math.ceil(s[-1] / step)))
    out = []
    j = 0
    for i in range(n + 1):
        t = s[-1] * i / n
        while j < len(s) - 2 and s[j + 1] < t:
            j += 1
        seg = s[j + 1] - s[j]
        f = 0.0 if seg <= 0 else (t - s[j]) / seg
        out.append(pts[j].lerp(pts[j + 1], f))
    return out


def sweep(bm: bmesh.types.BMesh, path: list, outs: list, section: list) -> list:
    """Quads along `path` (3D points) of a closed `section` [(across, out)], `across` along tangent x out and `out`
    along `outs` (each point's outward direction, made square to the path). Capped. Returns the faces."""
    rings = []
    n = len(path)
    for i, p in enumerate(path):
        a = path[max(i - 1, 0)]
        b = path[min(i + 1, n - 1)]
        t = (b - a).normalized()
        o = Vector(outs[i])
        o = (o - t * o.dot(t)).normalized()
        side = t.cross(o).normalized()
        rings.append([bm.verts.new(p + side * u + o * v) for u, v in section])
    faces = []
    m = len(section)
    for ra, rb in zip(rings, rings[1:]):
        for k in range(m):
            q = (k + 1) % m
            faces.append(bm.faces.new((ra[k], ra[q], rb[q], rb[k])))
    faces.append(bm.faces.new(list(reversed(rings[0]))))
    faces.append(bm.faces.new(rings[-1]))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return faces


def clearance(obs: list, tree: BVHTree, min_gap: float) -> tuple:
    """(how many vertices of `obs` sit closer than min_gap outside the body or inside it, the worst gap)."""
    bad, worst = 0, 1.0
    for ob in obs:
        for v in ob.data.vertices:
            p = ob.matrix_world @ v.co
            loc, nrm, _i, _d = tree.find_nearest(p)
            if loc is None:
                continue
            gap = (p - loc).dot(nrm)
            worst = min(worst, gap)
            if gap < min_gap:
                bad += 1
    return bad, worst
