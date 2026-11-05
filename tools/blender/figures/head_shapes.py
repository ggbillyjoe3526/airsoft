"""The head and the helmet shells as formulas (BL11, 2026-11-05), shared by tools/blender/figures/headwear.py.

Blender space at the figure's rest pose: metres, +Z up, the figure facing -Y, +X its left. The Head bone sits at
HEAD_BONE; the head below is sized to the v12 figure (1.74 m): crown 1.715 m, eye line 1.615 m, chin 1.49 m, nose tip
12 cm in front of the head's axis, so the old heads' fit (the hit volume, the first-person camera, the collar) holds.
"""

import math

from mathutils import Vector

from headkit import DEG, direction, gauss, keyed, smoothstep

HEAD_BONE = Vector((0.0, 0.008, 1.5099))

# --- the head (a balaclava over it): a smooth union of three solids, then the face's features --------------------

# (centre y, centre z, half width, half depth, half height)
CRANIUM = (0.006, 1.618, 0.0755, 0.099, 0.097)
FACE = (-0.028, 1.575, 0.064, 0.074, 0.085)
NECK = (0.016, 0.054, 0.057)  # centre y, half width, half depth
NECK_TOP = 1.63
NECK_BOTTOM = 1.44
CROWN = CRANIUM[1] + CRANIUM[4]
EYE_Z = 1.615
UNION_POWER = 9.0
# The crown is squarer than an ellipse from behind (the parietal bones), so the upper half uses a superellipse.
CRANIUM_POWER = 2.45


def _ray_ellipse(dx: float, dy: float, cy: float, a: float, b: float) -> float:
    """How far along (dx, dy) from the slice's axis the ellipse centred (0, cy), half axes a, b, reaches (0: none)."""
    if a <= 0.0 or b <= 0.0:
        return 0.0
    qa = (dx / a) ** 2 + (dy / b) ** 2
    qb = -2.0 * dy * cy / (b * b)
    qc = (cy / b) ** 2 - 1.0
    disc = qb * qb - 4.0 * qa * qc
    if disc < 0.0:
        return 0.0
    return max(0.0, (-qb + math.sqrt(disc)) / (2.0 * qa))


def _slice(cy: float, cz: float, a: float, b: float, c: float, z: float, power: float = 2.0) -> tuple:
    k = 1.0 - abs((z - cz) / c) ** power
    if k <= 0.0:
        return 0.0, 0.0
    s = k ** (1.0 / power)
    return a * s, b * s


def head_radius(az: float, z: float) -> float:
    """The head's distance from its vertical axis (x 0, y 0) at azimuth `az` and height `z`."""
    dx, dy = math.sin(az), -math.cos(az)
    rs = []
    a, b = _slice(*CRANIUM, z, CRANIUM_POWER if z > CRANIUM[1] else 2.0)
    rs.append(_ray_ellipse(dx, dy, CRANIUM[0], a, b))
    a, b = _slice(*FACE, z)
    taper = keyed([(1.49, 0.6), (1.525, 0.84), (1.575, 1.0)], z)
    rs.append(_ray_ellipse(dx, dy, FACE[0], a * taper, b))
    if z <= NECK_TOP:
        fade = 1.0 - smoothstep(NECK_TOP - 0.05, NECK_TOP, z)
        rs.append(_ray_ellipse(dx, dy, NECK[0], NECK[1], NECK[2]) * fade)
    r = sum(x ** UNION_POWER for x in rs) ** (1.0 / UNION_POWER)
    return r + _features(az, z)


def _features(az: float, z: float) -> float:
    a = abs(az)
    nose = keyed([(1.565, 0.0), (1.574, 0.011), (1.584, 0.021), (1.60, 0.013), (1.62, 0.006), (1.636, 0.0)], z)
    width = keyed([(1.57, 0.17), (1.585, 0.15), (1.62, 0.09)], z)
    f = nose * gauss(az, width)
    f += 0.005 * gauss(z - 1.641, 0.008) * gauss(az, 0.55)                             # brow
    f -= 0.009 * gauss(z - 1.614, 0.010) * gauss(a - 0.33, 0.12)                       # eye sockets
    f += 0.004 * gauss(z - 1.594, 0.014) * gauss(a - 0.62, 0.2)                        # cheekbones
    f += 0.003 * gauss(z - 1.552, 0.006) * gauss(az, 0.28)                             # lips
    f += 0.006 * gauss(z - 1.507, 0.012) * gauss(az, 0.32)                             # chin
    f += 0.006 * gauss(z - 1.600, 0.020) * gauss(a - 1.70, 0.18)                        # ears
    return f


def head_azimuths(count: int) -> list:
    """`count` azimuths round the head from the back (-pi) through the front (0), closer together at the face."""
    out = []
    for i in range(count):
        u = 2.0 * i / count - 1.0
        out.append(math.copysign(abs(u) ** 1.3, u) * math.pi)
    return out


def head_point(az: float, z: float, off: float = 0.0) -> Vector:
    return Vector((math.sin(az), -math.cos(az), 0.0)) * (head_radius(az, z) + off) + Vector((0.0, 0.0, z))


def head_rings(count_az: int, count_z: int) -> tuple:
    """The heights of the head's rings (the neck's foot up to just under the crown, denser at the chin and the
    crown) and the crown's own point."""
    low = int(count_z * 0.55)
    zs = []
    for i in range(low):
        t = i / low
        # denser round the chin (1.47-1.53)
        zs.append(NECK_BOTTOM + (CRANIUM[1] - NECK_BOTTOM) * (t + 0.08 * math.sin(t * math.tau)))
    for i in range(count_z - low):
        phi = (i / (count_z - low)) * 84.0 * DEG
        zs.append(CRANIUM[1] + CRANIUM[4] * math.sin(phi))
    return zs, Vector((0.0, CRANIUM[0] * 0.3, CROWN + _features(0.0, CROWN)))


# --- the helmet shells: a rounded box-ish ellipsoid about SHELL_CENTRE, cut by a rim curve --------------------------

SHELL_CENTRE = Vector((0.0, 0.006, 1.612))
SHELL_POWER = 2.35
# Half sizes: width, front, back, height.
HIGH_CUT_SIZE = (0.097, 0.118, 0.125, 0.146)
FULL_CUT_SIZE = (0.100, 0.120, 0.127, 0.139)

# The rim's elevation (degrees) by |azimuth| (degrees): the high cut's ear cut-out rises over the ear between the
# brow and the nape (the owner's FAST-style photos), the full cut comes down over the ear with a small notch.
HIGH_CUT_RIM = [(0, 12.0), (38, 11.0), (50, 10.0), (72, 27.0), (100, 29.0), (112, 24.0), (142, -6.0), (180, -12.0)]
# The full cut rises a little at the temples so goggles sit under it.
FULL_CUT_RIM = [(0, 13.0), (35, 12.0), (55, 9.0), (68, 4.0), (80, -7.0), (90, -6.0), (102, -10.0), (128, -18.0),
                (180, -17.0)]


def shell_radius(size: tuple, d: Vector) -> float:
    ax, ay_front, ay_back, az = size
    ay = ay_front if d.y < 0.0 else ay_back
    p = SHELL_POWER
    s = (abs(d.x) / ax) ** p + (abs(d.y) / ay) ** p + (abs(d.z) / az) ** p
    return s ** (-1.0 / p)


def shell_point(size: tuple, az: float, el: float, off: float = 0.0) -> Vector:
    d = direction(az, el)
    return SHELL_CENTRE + d * (shell_radius(size, d) + off)


def shell_normal(size: tuple, az: float, el: float) -> Vector:
    e = 0.002
    p = shell_point(size, az, el)
    du = shell_point(size, az + e, el) - shell_point(size, az - e, el)
    dv = shell_point(size, az, min(el + e, 89.9 * DEG)) - shell_point(size, az, el - e)
    n = du.cross(dv)
    if n.length < 1e-9:
        return (p - SHELL_CENTRE).normalized()
    n.normalize()
    if n.dot(p - SHELL_CENTRE) < 0.0:
        n = -n
    return n


def rim_el(rim: list, az: float) -> float:
    """The rim's elevation (radians) at azimuth `az` (radians)."""
    a = abs(((az / DEG) + 180.0) % 360.0 - 180.0)
    return keyed(rim, a) * DEG
