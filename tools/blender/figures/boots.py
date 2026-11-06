"""The figure's boots (BL10): mid-height tactical boots from the owner's figure photos (the T-pose shots: coyote suede
uppers, a darker rubber sole with a lip, a toe cap and heel counter, lacing up the front of the shaft).

Each boot's upper is lofted through horizontal contours, heel to toe, from the sole up to the padded collar: the
footprint at the bottom, the toe box ending lower down the front as the contours rise over the instep, and the shaft's
oval from the ankle up. The sole is a separate lofted slab with a lip all round and a lifted toe. Sizes match the v12
figure's boots (0.115 m wide; heel to toe 0.272 m, a centimetre shorter than v12's at the toe), so the feet meet the
ground where the clips put them.
"""

import math

import bmesh
from mathutils import Vector

N = 56                 # points round each contour
HEEL_BACK = 0.071      # heel back behind the ankle joint along the foot (m)
LENGTH = 0.272         # heel back to toe tip
SOLE_TOP = 0.030
SOLE_LIP = 0.004       # how far the sole stands out of the upper
TOE_SPRING = 0.014     # the toe's lift off the ground at the tip
# Contours of the upper: (z, from heel, to toe, half width, front taper, roundness exponent).
CONTOURS = [
    (0.022, 0.004, 0.268, 0.0465, 0.06, 2.6),
    (0.036, 0.001, 0.270, 0.0482, 0.05, 2.5),
    (0.052, 0.001, 0.266, 0.0484, 0.04, 2.45),
    (0.066, 0.004, 0.252, 0.0478, 0.04, 2.4),
    (0.078, 0.007, 0.230, 0.0468, 0.04, 2.35),
    (0.090, 0.010, 0.200, 0.0462, 0.06, 2.3),
    (0.103, 0.013, 0.166, 0.0442, 0.06, 2.2),
    (0.118, 0.016, 0.140, 0.0432, 0.02, 2.1),
    (0.140, 0.019, 0.127, 0.0425, 0.0, 2.05),
    (0.170, 0.019, 0.125, 0.0428, 0.0, 2.05),
    (0.195, 0.017, 0.128, 0.0445, 0.0, 2.05),
    (0.214, 0.015, 0.131, 0.0462, 0.0, 2.05),
]


class Frame:
    """A boot's footprint frame: origin on the ground under the heel's back, u toward the toe, w outward."""

    def __init__(self, ankle: Vector, toe_tail: Vector, outward_x: float):
        f = Vector((toe_tail.x - ankle.x, toe_tail.y - ankle.y, 0.0)).normalized()
        self.f = f
        w = Vector((-f.y, f.x, 0.0))
        self.w = w if w.x * outward_x > 0 else -w
        self.o = Vector((ankle.x, ankle.y, 0.0)) - f * HEEL_BACK

    def at(self, u: float, w: float, z: float) -> Vector:
        return self.o + self.f * u + self.w * w + Vector((0.0, 0.0, z))


def _sp(x: float, e: float) -> float:
    return math.copysign(abs(x) ** e, x)


def params_at(z: float) -> tuple:
    """The contour parameters at any height, between the listed contours."""
    cs = CONTOURS
    if z <= cs[0][0]:
        return cs[0][1:]
    for a, b in zip(cs, cs[1:]):
        if a[0] <= z <= b[0]:
            f = (z - a[0]) / (b[0] - a[0])
            return tuple(x + (y - x) * f for x, y in zip(a[1:], b[1:]))
    return cs[-1][1:]


def point(fr: Frame, z: float, t: float, grow: float = 0.0) -> Vector:
    """The upper's surface at height z and angle t round it (0 the heel's back, pi the toe), pushed out `grow`."""
    ub, uf, b, taper, n = params_at(z)
    return _point(fr, z, ub, uf, b, taper, n, t, grow)


def _point(fr: Frame, z: float, ub: float, uf: float, b: float, taper: float, n: float, t: float,
           grow: float) -> Vector:
    c, a = (ub + uf) * 0.5, (uf - ub) * 0.5 + grow
    s, co = -math.cos(t), math.sin(t)
    u = c + a * _sp(s, 2.0 / n)
    rel = (u - c) / max(1e-6, a)
    w = (b + grow) * _sp(co, 2.0 / n) * (1.0 + taper * rel)
    w -= 0.009 * max(0.0, (u - 0.17) / 0.11) ** 1.5
    lift = TOE_SPRING * max(0.0, (u - 0.20) / (LENGTH - 0.20)) ** 2 * max(0.0, (0.07 - z) / 0.07)
    return fr.at(u, w, z + lift)


def contour(fr: Frame, z: float, ub: float, uf: float, b: float, taper: float, n: float, grow: float = 0.0) -> list:
    """One closed contour, N points starting at the heel's back and going round the outside first."""
    return [_point(fr, z, ub, uf, b, taper, n, math.tau * k / N, grow) for k in range(N)]


ARCH = 0.0100          # the arch's lift under the waist of the sole
ARCH_SPAN = (0.088, 0.100, 0.150, 0.180)   # heel step, full lift, and back down to the ball (m from the heel)


def _arch(u: float) -> float:
    a, b, c, d = ARCH_SPAN
    if u <= a or u >= d:
        return 0.0
    if u < b:
        return (u - a) / (b - a)
    if u > c:
        x = (d - u) / (d - c)
        return x * x * (3 - 2 * x)
    return 1.0


def _loft(bm: bmesh.types.BMesh, rings: list, cap_bottom: bool = False, cap_top: bool = False) -> None:
    vs = [[bm.verts.new(p) for p in ring] for ring in rings]
    for i in range(len(vs) - 1):
        for k in range(N):
            a, b = vs[i][k], vs[i][(k + 1) % N]
            c, d = vs[i + 1][(k + 1) % N], vs[i + 1][k]
            bm.faces.new([a, b, c, d])
    if cap_bottom:
        _cap(bm, vs[0], down=True)
    if cap_top:
        _cap(bm, vs[-1], down=False)


def _cap(bm: bmesh.types.BMesh, ring: list, down: bool) -> None:
    """A strip-quad cap across a contour (pairs of points across the sole, heel to toe)."""
    half = N // 2
    left = ring[1:half]
    right = list(reversed(ring[half + 1:]))
    faces = []
    prev = (ring[0], ring[0])
    for k in range(len(left)):
        a, b = left[k], right[k]
        if k == 0:
            faces.append([ring[0], a, b] if down else [b, a, ring[0]])
        else:
            pa, pb = prev
            faces.append([pa, a, b, pb] if down else [pb, b, a, pa])
        prev = (a, b)
    faces.append([prev[0], ring[half], prev[1]] if down else [prev[1], ring[half], prev[0]])
    for f in faces:
        bm.faces.new(f)


def upper(fr: Frame) -> bmesh.types.BMesh:
    bm = bmesh.new()
    _loft(bm, [contour(fr, *c) for c in CONTOURS])
    bm.normal_update()
    _outward(bm, fr)
    return bm


def sole(fr: Frame) -> bmesh.types.BMesh:
    z0, ub, uf, b, tp, n = CONTOURS[0]
    rings = [
        contour(fr, SOLE_TOP + 0.002, ub, uf, b, tp, n, grow=SOLE_LIP),
        contour(fr, SOLE_TOP - 0.004, ub, uf, b, tp, n, grow=SOLE_LIP + 0.0012),
        contour(fr, 0.006, ub, uf, b, tp, n, grow=SOLE_LIP + 0.0008),
        contour(fr, 0.0, ub, uf, b, tp, n, grow=SOLE_LIP - 0.0015),
    ]
    bm = bmesh.new()
    _loft(bm, rings, cap_top=False, cap_bottom=False)
    bm.verts.ensure_lookup_table()
    # The waist of the sole: the heel's front step and the arch lifted off the ground between heel and ball.
    for ring, share in ((3, 1.0), (2, 0.85)):
        for v in bm.verts[ring * N:(ring + 1) * N]:
            v.co.z += ARCH * share * _arch((v.co - fr.o).dot(fr.f))
    _cap(bm, list(bm.verts[-N:]), down=True)
    _cap(bm, list(bm.verts[:N]), down=False)
    bm.normal_update()
    _outward(bm, fr)
    return bm


def _outward(bm: bmesh.types.BMesh, fr: Frame) -> None:
    """Point the faces out of the boot (the loft's winding depends on the side)."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    c = fr.at(LENGTH * 0.4, 0.0, 0.08)
    score = sum((f.calc_center_median() - c).dot(f.normal) for f in bm.faces)
    if score < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.normal_update()


def skin_shell(fr: Frame, z_of, t0: float, t1: float, rows: int, cols: int, grow: float, thick: float) -> tuple:
    """A raised piece on the upper (toe cap, heel counter, tongue): rows up from z_of(v, 0) to z_of(v, 1) over angles
    t0..t1 (v = 0..1 across them), grow out from the upper and thick. Returns (verts, faces), walls included."""
    top, bot = [], []
    for i in range(rows + 1):
        for j in range(cols + 1):
            v = j / cols
            t = t0 + (t1 - t0) * v
            z = z_of(v, i / rows)
            bot.append(point(fr, z, t, grow))
            top.append(point(fr, z, t, grow + thick))
    return _shell(top, bot, rows, cols)


def _shell(top: list, bot: list, rows: int, cols: int) -> tuple:
    w, k = cols + 1, len(top)
    faces = []
    for i in range(rows):
        for j in range(cols):
            a = i * w + j
            faces.append([a, a + 1, a + w + 1, a + w])
    ring = [(0, j) for j in range(cols)] + [(i, cols) for i in range(rows)] + \
        [(rows, cols - j) for j in range(cols)] + [(rows - i, 0) for i in range(rows)]
    for idx in range(len(ring)):
        i0, j0 = ring[idx]
        i1, j1 = ring[(idx + 1) % len(ring)]
        a, b = i0 * w + j0, i1 * w + j1
        faces.append([b, a, a + k, b + k])
    return top + bot, faces


def toe_cap(fr: Frame) -> tuple:
    """The rubber toe cap: up to 6 cm at the tip, lower round the sides."""
    def z_of(v: float, h: float) -> float:
        top = 0.044 + 0.018 * math.sin(v * math.pi)
        return 0.028 + (top - 0.028) * h
    return skin_shell(fr, z_of, math.pi - 1.05, math.pi + 1.05, 4, 16, 0.0006, 0.0013)


def heel_counter(fr: Frame) -> tuple:
    def z_of(v: float, h: float) -> float:
        top = 0.052 + 0.026 * math.sin(v * math.pi)
        return 0.028 + (top - 0.028) * h
    return skin_shell(fr, z_of, -1.25, 1.25, 3, 12, 0.0006, 0.0020)


def tongue(fr: Frame) -> tuple:
    """The lacing panel up the front: from the instep to the collar."""
    def z_of(v: float, h: float) -> float:
        return 0.094 + (0.214 - 0.094) * h
    return skin_shell(fr, z_of, math.pi - 0.42, math.pi + 0.42, 6, 4, 0.0004, 0.0016)


def eyelets(fr: Frame) -> list:
    """The lacing's metal eyelets beside the tongue at each lace level, speed hooks (taller) at the top two."""
    out = []
    for k in range(7):
        z = 0.098 + k * 0.0175
        tall = 0.0026 if k >= 5 else 0.0
        for t in (math.pi - 0.47, math.pi + 0.47):
            def z_of(v: float, h: float, z=z, tall=tall) -> float:
                return z - 0.0015 + (0.0055 + tall) * h
            out.append(skin_shell(fr, z_of, t - 0.05, t + 0.05, 1, 2, 0.0018, 0.0016 + tall * 0.5))
    return out


def laces(fr: Frame) -> list:
    """Lace crossings over the tongue: short raised bars, alternate ones canted."""
    out = []
    for k in range(7):
        z = 0.098 + k * 0.0175
        for sgn in (1, -1):
            def z_of(v: float, h: float, z=z, sgn=sgn) -> float:
                return z + 0.0045 * h + sgn * 0.006 * (v - 0.5)
            out.append(skin_shell(fr, z_of, math.pi - 0.36, math.pi + 0.36, 1, 4, 0.0026, 0.0018))
    return out
