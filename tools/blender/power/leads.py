"""Shared pieces of the batteries' menu models (BL7): wires swept along smooth paths and the plugs on their ends.

Every builder here adds faces to a hardsurface.Builder (tools/blender/replicas/hardsurface.py) in metres. A plug is
made pointing up +Y at the origin and then turned and moved onto the end of its lead.
"""

import math

import hardsurface as hs
from mathutils import Matrix, Vector

MM = 0.001

# The Tamiya-style mini plug on a battery's main lead (the female, battery side), millimetres.
TAMIYA_LENGTH = 18.0
TAMIYA_WIDTH = 10.6
TAMIYA_HEIGHT = 7.6
TAMIYA_CORNER = 1.0
TAMIYA_TAIL_LENGTH = 3.5
TAMIYA_TAIL_WIDTH = 8.2
TAMIYA_TAIL_HEIGHT = 5.6
TAMIYA_SOCKET = 3.3  # the two square sockets in its face
TAMIYA_SOCKET_PITCH = 5.2
TAMIYA_SOCKET_DEPTH = 0.06
TAMIYA_LATCH_LENGTH = 7.0
TAMIYA_LATCH_WIDTH = 4.6
TAMIYA_LATCH_RISE = 1.3
TAMIYA_RIB = 0.35  # the two grip ribs along each side
TAMIYA_RIB_WIDTH = 0.8

# The JST-XH style balance plug (4 pins) on a LiPo's balance lead, millimetres.
XH_PITCH = 2.5
XH_LENGTH = 7.0
XH_DEPTH = 5.8
XH_END = 1.4  # wall past the outer pins
XH_CORNER = 0.4
XH_SLOT = 1.5
XH_SLOT_DEPTH = 0.06


def sample(points: list, per_span: int) -> list:
    """A Catmull-Rom curve through `points` (metres), `per_span` steps between each pair."""
    pts = [Vector(p) for p in points]
    ext = [pts[0] * 2.0 - pts[1]] + pts + [pts[-1] * 2.0 - pts[-2]]
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for k in range(per_span):
            t = k / per_span
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
                              + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
    out.append(pts[-1])
    return out


def frames(path: list, up: Vector) -> list:
    """(tangent, normal, binormal) at each point, carried along the path so the tube does not twist."""
    tangents = []
    for i in range(len(path)):
        a = path[max(i - 1, 0)]
        b = path[min(i + 1, len(path) - 1)]
        tangents.append((b - a).normalized())
    n = (up - tangents[0] * up.dot(tangents[0])).normalized()
    out = []
    for i, t in enumerate(tangents):
        if i > 0:
            n = (n - t * n.dot(t)).normalized()
        out.append((t, n, t.cross(n)))
    return out


def wire(b: hs.Builder, path: list, radius: float, mat: str, sides: int = 6, up: tuple = (1.0, 0.0, 0.0),
         side_offset: float = 0.0, caps: bool = True) -> None:
    """A round wire swept along `path` (already sampled), moved `side_offset` along each frame's binormal: with `up`
    square to a flat path, that keeps a lead's wires side by side in the path's plane, as a flat lead bends."""
    fr = frames(path, Vector(up))
    rings = []
    for p, (t, n, bn) in zip(path, fr):
        c = p + bn * side_offset
        rings.append([tuple(c + (n * math.cos(a) + bn * math.sin(a)) * radius)
                      for a in (math.tau * k / sides for k in range(sides))])
    b.loft(rings, mat, cap0=caps, cap1=caps)


def place(b: hs.Builder, faces: list, at: Vector, forward: Vector, up: Vector) -> None:
    """Turns faces made pointing +Y (top +Z) at the origin so +Y runs along `forward` with +Z nearest `up`, then
    moves them to `at`."""
    f = forward.normalized()
    u = (up - f * up.dot(f)).normalized()
    x = f.cross(u)
    rot = Matrix(((x.x, f.x, u.x, 0.0), (x.y, f.y, u.y, 0.0), (x.z, f.z, u.z, 0.0), (0.0, 0.0, 0.0, 1.0)))
    b.transform(faces, Matrix.Translation(at) @ rot)


def tamiya(b: hs.Builder, body: str, socket: str) -> list:
    """The mini plug, its tail (where the lead goes in) at the origin and its face, with the two sockets, at
    +Y = tail + length. The latch ramp is on top (+Z), grip ribs on both sides."""
    m = MM
    faces = []
    y0 = 0.0
    y1 = TAMIYA_TAIL_LENGTH * m
    y2 = y1 + TAMIYA_LENGTH * m
    faces += b.prism(hs.rounded_rect(TAMIYA_TAIL_WIDTH * 0.5 * m, TAMIYA_TAIL_HEIGHT * 0.5 * m, 0.8 * m, 2), "y",
                     y0, y1 + 0.5 * m, body)
    faces += b.prism(hs.rounded_rect(TAMIYA_WIDTH * 0.5 * m, TAMIYA_HEIGHT * 0.5 * m, TAMIYA_CORNER * m, 2), "y",
                     y1, y2, body)
    # The latch: a ramp rising toward the face, its tip a little short of it.
    lw = TAMIYA_LATCH_WIDTH * 0.5 * m
    top = TAMIYA_HEIGHT * 0.5 * m
    ramp = [(y2 - (TAMIYA_LATCH_LENGTH + 1.5) * m, top - 0.2 * m), (y2 - 1.5 * m, top - 0.2 * m),
            (y2 - 1.5 * m, top + TAMIYA_LATCH_RISE * m), (y2 - 2.6 * m, top + TAMIYA_LATCH_RISE * m)]
    latch = b.prism(ramp, "x", -lw, lw, body)
    faces += latch
    # Grip ribs down each side.
    for sx in (-1.0, 1.0):
        for zc in (-1.6, 1.6):
            x0 = sx * (TAMIYA_WIDTH * 0.5 - 0.1) * m
            x1 = sx * (TAMIYA_WIDTH * 0.5 + TAMIYA_RIB) * m
            faces += b.box((min(x0, x1), y1 + 3.0 * m, (zc - TAMIYA_RIB_WIDTH * 0.5) * m),
                           (max(x0, x1), y2 - 3.0 * m, (zc + TAMIYA_RIB_WIDTH * 0.5) * m), body)
    # The two sockets: dark squares just proud of the face, so they read as openings.
    s = TAMIYA_SOCKET * 0.5 * m
    for sx in (-1.0, 1.0):
        cx = sx * TAMIYA_SOCKET_PITCH * 0.5 * m
        faces += b.box((cx - s, y2 - 0.2 * m, -s), (cx + s, y2 + TAMIYA_SOCKET_DEPTH * m, s), socket)
    return faces


def balance_plug(b: hs.Builder, body: str, slot: str, pins: int = 4) -> list:
    """The balance plug: the lead goes in at the origin, the mating face at +Y = length; pins across X."""
    m = MM
    hw = ((pins - 1) * XH_PITCH * 0.5 + XH_END) * m
    faces = b.prism(hs.rounded_rect(hw, XH_DEPTH * 0.5 * m, XH_CORNER * m, 2), "y", 0.0, XH_LENGTH * m, body)
    # The locking bump on the back and a slot per pin in the face.
    faces += b.box((-hw * 0.5, XH_LENGTH * 0.35 * m, XH_DEPTH * 0.5 * m - 0.1 * m),
                   (hw * 0.5, XH_LENGTH * 0.85 * m, XH_DEPTH * 0.5 * m + 0.7 * m), body)
    s = XH_SLOT * 0.5 * m
    for k in range(pins):
        cx = (k - (pins - 1) * 0.5) * XH_PITCH * m
        faces += b.box((cx - s, XH_LENGTH * m - 0.2 * m, -s), (cx + s, (XH_LENGTH + XH_SLOT_DEPTH) * m, s), slot)
    return faces
