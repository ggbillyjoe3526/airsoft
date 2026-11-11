"""The shirt's mock-neck collar as numbers (CN1, 2026-11-10), shared by body.py, which grows it from the shirt's
neckline (garment.grow_collar), and headwear.py, whose scarf lies over it. Plain Python: no Blender modules.

Blender space at the figure's rest pose: metres, +Z up, the figure facing -Y, +X its left.
"""

import math

# The rings (z, half width, depth ahead, depth behind) round the heads' neck (head_shapes.NECK: its axis 16 mm behind
# the figure's, 54 mm half wide, 57 mm deep), from the neckline up to the rolled top and back down inside to the neck.
# Behind, the inner wall stands 7 mm clear of the neck (BL10's collar, sized round the figure's axis, let the neck's
# back cut through it in a dark V); ahead, the front as BL10 cut it, the zip's pull on it.
AXIS_Y = 0.016
RINGS = [(1.468, 0.078, 0.085, 0.080), (1.492, 0.071, 0.079, 0.076), (1.509, 0.068, 0.076, 0.073),
         (1.516, 0.064, 0.072, 0.069), (1.505, 0.059, 0.067, 0.064), (1.470, 0.060, 0.068, 0.064)]
# The collar stands this much higher at the back (m), as a shirt's does, rising broadly from the front.
BACK_RISE = 0.005
# The first ring stands only halfway out from the neckline (garment.grow_collar): the foot's outside lies about this
# much (m) inside the ring.
FOOT_INSET = 0.015
# Its weights, by height alone (body.collar_weights): the chest's share at the foot (WEIGHTS_FOOT) fading to none at the
# top (WEIGHTS_TOP), the head's growing from none to HEAD_TOP there, the neck's the rest; within WEIGHTS_REACH (m) of
# the axis, eased in over WEIGHTS_EASE (m) above the neckline. The heads' necks copy them (splice_heads.py).
WEIGHTS_FOOT = 1.46
WEIGHTS_TOP = 1.526
CHEST_FOOT = 0.3
HEAD_TOP = 0.3
WEIGHTS_REACH = 0.1
WEIGHTS_EASE = 0.012


def rise(ahead: float, z: float) -> float:
    """How much higher than its ring's height a ring at height z stands where cos(angle from straight ahead) is
    `ahead`: in proportion to its height over the first ring (the foot stays on the neckline), none at the front, half
    at the sides (a broad rise, no peak at the back)."""
    foot = RINGS[0][0]
    top = max(r[0] for r in RINGS)
    return BACK_RISE * (1.0 - ahead) * 0.5 * (z - foot) / (top - foot)


def ring_point(ring: tuple, ang: float) -> tuple:
    """(x, y, z) on a ring at angle `ang` round the axis (0 straight ahead, -Y; positive toward +X): two half ellipses
    meeting at the sides."""
    z, rx, ry_front, ry_back = ring
    ahead = math.cos(ang)
    ry = ry_front if ahead >= 0.0 else ry_back
    return rx * math.sin(ang), AXIS_Y - ry * ahead, z + rise(ahead, z)


def outer_radius(ang: float, z: float) -> float:
    """The outside of the collar's wall at angle `ang` and height z: its distance from the axis (m), 0 above the top."""
    outer = [ring_point(r, ang) for r in RINGS[:4]]
    if z > outer[-1][2]:
        return 0.0
    rs = [(p[2], math.hypot(p[0], p[1] - AXIS_Y)) for p in outer]
    rs[0] = (rs[0][0], rs[0][1] - FOOT_INSET)
    if z <= rs[0][0]:
        return rs[0][1]
    for (z0, r0), (z1, r1) in zip(rs, rs[1:]):
        if z <= z1:
            return r0 + (r1 - r0) * (z - z0) / max(z1 - z0, 1e-9)
    return rs[-1][1]


def top(ang: float) -> float:
    """The height of the collar's rolled top at angle `ang`."""
    return ring_point(RINGS[3], ang)[2]


def smoothstep(a: float, b: float, x: float) -> float:
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def weights(z: float) -> dict:
    """The collar's weights at height z, by bone."""
    h = min(1.0, max(0.0, (z - WEIGHTS_FOOT) / (WEIGHTS_TOP - WEIGHTS_FOOT)))
    chest = CHEST_FOOT * (1.0 - h)
    head = HEAD_TOP * h
    return {"Chest": chest, "Head": head, "Neck": 1.0 - chest - head}
