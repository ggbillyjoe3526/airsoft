"""Shared helpers for Subway's ways between levels (SM2, Dev 3): the escalator banks, the lifts, the spiral stair, the
platform stair and the railing, built from code on map_kit.

Everything here is written in the game's own axes, metres: x east, y up, z south (the map file's), and turned into
Blender's (+Z up, -Y the game's +z) as each vertex is made, so a model laid over its blocks unturned (PropDressConfig
Lay.SET) can be built straight from tools/subway/layout.py's numbers. A part is one paint: its vertices may carry a
tone (a share of the paint), so grime and wear fade across a face without an edge (map_kit.toned); a round part
(a handrail) keeps rounded normals (map_kit.smoothed). Nothing here ships: tools/ is Dev only.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "..", "subway"))

import bpy  # noqa: E402,F401  first: it brings bmesh with it
import bmesh  # noqa: E402
import map_kit as mk  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
PROPS = os.path.join(ROOT, "assets", "models", "props")

# The paints (sRGB), every one off the teams' hues (tests/unit/test_props.gd): brushed stainless, the steps' dark
# aluminium and their lighter risers, safety yellow (the station's only bright colour), the handrails' black rubber,
# chequer plate, a dull bronze for the old lamps, frosted glass, and the dark of a gap.
STAINLESS = 0xBFC1C0
STAINLESS_DARK = 0x8E8C86
TREAD = 0x48484C
RISER = 0x67676A
YELLOW = 0xE4CA46
RUBBER = 0x2A292D
CHEQUER = 0x8A8882
BRONZE = 0x67625A
FROST = 0xEAE4D4
GAP = 0x1E1D20
# Grime: how dark a face is at a floor (a share of its paint), fading to clean this high (m) over it.
GRIME = 0.78
GRIME_UP = 0.6


def B(p: tuple) -> tuple:
    """A game point (x, y up, z south) in Blender's axes."""
    return (p[0], -p[2], p[1])


def part(name: str, colour: int, verts: list, faces: list, tones: list = None, smooth: float = 0.0,
         outward: bool = False) -> object:
    """One painted part from game-space `verts` and `faces` (index lists, wound counter-clockwise seen from outside:
    the game's winding; Blender's turn keeps it), or with `outward` turned to face out of the part (a swept tube).
    `tones` per vertex shade it; `smooth` (degrees) rounds its normals across edges bent less than that."""
    bm = bmesh.new()
    vs = [bm.verts.new(B(v)) for v in verts]
    for f in faces:
        try:
            bm.faces.new([vs[i] for i in f])
        except ValueError:
            pass  # a face given twice (a degenerate sweep's cap)
    if outward:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = mk.mesh_object(name, bm, colour)
    if tones is not None:
        mk.toned(ob, tones)
    if smooth > 0.0:
        mk.smoothed(ob, smooth)
    # No foot shade over a part's height: a 10 m flight would darken end to end. Grime comes from `tones`.
    ob["foot"] = (-1.0e6, 1.0e6)
    return ob


class Mesh:
    """Game-space vertices and faces gathered for one part."""

    def __init__(self) -> None:
        self.v: list = []
        self.f: list = []
        self.t: list = []

    def add(self, p: tuple, tone: float = 1.0) -> int:
        self.v.append(tuple(p))
        self.t.append(tone)
        return len(self.v) - 1

    def quad(self, a: tuple, b: tuple, c: tuple, d: tuple, tones: tuple = (1.0, 1.0, 1.0, 1.0)) -> None:
        """A quad a-b-c-d, counter-clockwise seen from its front."""
        i = [self.add(p, t) for p, t in zip((a, b, c, d), tones)]
        self.f.append(i)

    def poly(self, pts: list, tones: list = None) -> None:
        i = [self.add(p, 1.0 if tones is None else tones[k]) for k, p in enumerate(pts)]
        self.f.append(i)

    def box(self, lo: tuple, hi: tuple, skip: tuple = (), tone=None) -> None:
        """An axis-aligned box, without the faces in `skip` ("-x", "+y"...). `tone` (a function of a game point, or
        None) shades each corner."""
        x0, y0, z0 = lo
        x1, y1, z1 = hi
        faces = {
            "+x": [(x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1)],
            "-x": [(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)],
            "+y": [(x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0)],
            "-y": [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)],
            "+z": [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
            "-z": [(x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0)],
        }
        for k, pts in faces.items():
            if k not in skip:
                self.poly(pts, None if tone is None else [tone(p) for p in pts])

    def sweep(self, path: list, ups: list, profile: list, side: tuple, closed: bool = True,
              caps: bool = False) -> None:
        """A profile swept along `path` (game points): each profile point (a, b) sits at the path point plus a along
        `side` (a unit vector, the same all along) plus b along that point's `ups` (unit, square to side)."""
        rings = []
        for p, u in zip(path, ups):
            rings.append([self.add((p[0] + a * side[0] + b * u[0], p[1] + a * side[1] + b * u[1],
                                    p[2] + a * side[2] + b * u[2])) for a, b in profile])
        n = len(profile)
        last = n if closed else n - 1
        for r0, r1 in zip(rings, rings[1:]):
            for k in range(last):
                j = (k + 1) % n
                self.f.append([r0[k], r0[j], r1[j], r1[k]])
        if caps:
            self.f.append(list(reversed(rings[0])))
            self.f.append(list(rings[-1]))

    def lathe(self, centre: tuple, profile: list, segments: int, cap_top: bool = False, start: float = 0.0) -> None:
        """A turned part round the upright through `centre`: `profile` is (radius, height) from the foot up; the
        outside faces out."""
        cx, cy, cz = centre
        rings = []
        for r, h in profile:
            rings.append([self.add((cx + r * math.cos(start + math.tau * k / segments), cy + h,
                                    cz + r * math.sin(start + math.tau * k / segments))) for k in range(segments)])
        for r0, r1 in zip(rings, rings[1:]):
            for k in range(segments):
                j = (k + 1) % segments
                self.f.append([r0[k], r1[k], r1[j], r0[j]])
        if cap_top:
            self.f.append(list(rings[-1]))

    def build(self, name: str, colour: int, smooth: float = 0.0, toned: bool = True, outward: bool = False) -> object:
        if not self.f:
            return None
        return part(name, colour, self.v, self.f, self.t if toned else None, smooth, outward)


def rounded_profile(w: float, h: float, r_top: float, r_foot: float, seg: int) -> list:
    """A handrail's section, (across, up) round its middle: `w` wide and `h` tall, its top corners rounded `r_top`
    in `seg` steps and its foot's `r_foot` in one, wound counter-clockwise."""
    hw, hh = w / 2, h / 2
    pts = []
    corners = [(hw - r_foot, -hh + r_foot, r_foot, -math.pi / 2, 1), (hw - r_top, hh - r_top, r_top, 0.0, seg),
               (-hw + r_top, hh - r_top, r_top, math.pi / 2, seg), (-hw + r_foot, -hh + r_foot, r_foot, math.pi, 1)]
    for cx, cy, r, a0, n in corners:
        for k in range(n + 1):
            a = a0 + (math.pi / 2) * k / n
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def report(name: str, objects: list, budget: int, box: tuple = None, unit: bool = False) -> int:
    """Writes `objects` as assets/models/props/<name>.glb and prints its triangles against `budget` and its bounds
    (game axes) against the box it must fill. With `unit` the model is written in a 1 m cube round its bounds' middle
    (map_kit.export), for a game that scales it to each use (a lift's leaves and buttons)."""
    objects = [o for o in objects if o is not None]
    lo, hi = mk.bounds(objects)
    size = tuple(hi[i] - lo[i] for i in range(3)) if unit else None
    n = mk.export(os.path.join(PROPS, name + ".glb"), name, objects, unit=size)
    g_lo = (lo[0], lo[2], -hi[1])
    g_hi = (hi[0], hi[2], -lo[1])
    print("%s: %d tris of %d (%.0f%%); bounds %s .. %s" % (name, n, budget, 100.0 * n / budget,
                                                         tuple(round(v, 3) for v in g_lo),
                                                         tuple(round(v, 3) for v in g_hi)))
    if box is not None:
        off = max(max(abs(a - b) for a, b in zip(g_lo, box[0])), max(abs(a - b) for a, b in zip(g_hi, box[1])))
        print("  box %s .. %s, worst edge off by %.4f m" % (box[0], box[1], off))
        if off > 0.005:
            raise SystemExit("%s does not fill its box" % name)
    if n > budget:
        raise SystemExit("%s is over its budget" % name)
    return n


def _sub(a: tuple, b: tuple) -> tuple:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _add(a: tuple, b: tuple, k: float = 1.0) -> tuple:
    return (a[0] + b[0] * k, a[1] + b[1] * k, a[2] + b[2] * k)


def _len(a: tuple) -> float:
    return math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])


def _unit(a: tuple) -> tuple:
    n = _len(a)
    return (a[0] / n, a[1] / n, a[2] / n)


def _cross(a: tuple, b: tuple) -> tuple:
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _dot(a: tuple, b: tuple) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def bent(points: list, radius: float, steps: int = 6) -> list:
    """The polyline `points` (game points) with each inner corner bent round an arc of `radius` (less where its legs
    are short), as a bent tube runs."""
    out = [points[0]]
    for k in range(1, len(points) - 1):
        p, c, n = points[k - 1], points[k], points[k + 1]
        a, b = _unit(_sub(p, c)), _unit(_sub(n, c))
        cosang = max(-1.0, min(1.0, _dot(a, b)))
        ang = math.acos(cosang)
        if ang > math.pi - 1e-3:
            out.append(c)
            continue
        cut = radius / math.tan(ang / 2)
        cut = min(cut, 0.45 * _len(_sub(p, c)), 0.45 * _len(_sub(n, c)))
        s, e = _add(c, a, cut), _add(c, b, cut)
        # A quadratic arc from s to e with c its control: near enough a circle for a handrail's bend.
        for i in range(steps + 1):
            t = i / steps
            q = tuple((1 - t) ** 2 * s[j] + 2 * (1 - t) * t * c[j] + t * t * e[j] for j in range(3))
            out.append(q)
    out.append(points[-1])
    return out


def tube(m: Mesh, path: list, r: float, sides: int = 10, caps: bool = True) -> None:
    """A round tube of radius `r` along `path` (game points), its rings carried along without twisting (a rotation
    minimising frame), closed at both ends with `caps`."""
    t = [_unit(_sub(path[min(i + 1, len(path) - 1)], path[max(i - 1, 0)])) for i in range(len(path))]
    up = (0.0, 1.0, 0.0) if abs(t[0][1]) < 0.9 else (1.0, 0.0, 0.0)
    n = _unit(_cross(_cross(t[0], up), t[0]))
    rings = []
    for i, p in enumerate(path):
        if i > 0:
            # Carry the frame: take the turn from the last tangent to this one off its normal.
            v = _sub(n, _add((0, 0, 0), t[i], _dot(n, t[i])))
            n = _unit(v) if _len(v) > 1e-9 else n
        b = _cross(t[i], n)
        rings.append([m.add(_add(_add(p, n, r * math.cos(math.tau * k / sides)), b, r * math.sin(math.tau * k / sides)))
                      for k in range(sides)])
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(sides):
            j = (k + 1) % sides
            m.f.append([r0[k], r0[j], r1[j], r1[k]])
    if caps:
        m.f.append(list(reversed(rings[0])))
        m.f.append(list(rings[-1]))


def rounded_rect(x0: float, y0: float, x1: float, y1: float, r: float, steps: int = 4) -> list:
    """A rectangle's outline in a plane's (a, b), its corners rounded `r`, counter-clockwise."""
    out = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -math.pi / 2), (x1 - r, y1 - r, 0.0), (x0 + r, y1 - r, math.pi / 2),
                       (x0 + r, y0 + r, math.pi)):
        for k in range(steps + 1):
            a = a0 + (math.pi / 2) * k / steps
            out.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return out


def knob(m: Mesh, centre: tuple, r_foot: float, r_face: float, depth: float, facing: float, segs: int = 12,
         axis: str = "z") -> None:
    """A round button or boss standing `depth` proud of a face along `axis` ("x" or "z") toward `facing` (+1/-1):
    a tapered side from `r_foot` to `r_face` and a flat face."""
    cx, cy, cz = centre

    def at(r: float, a: float, d: float) -> tuple:
        u, v = r * math.cos(a), r * math.sin(a)
        return (cx + u, cy + v, cz + d * facing) if axis == "z" else (cx + d * facing, cy + v, cz + u)

    # Counter-clockwise seen from the way it faces: z faces turn with +a seen from +z, x faces with -a from +x.
    turn = 1.0 if (axis == "z") == (facing > 0) else -1.0
    for k in range(segs):
        a0, a1 = turn * math.tau * k / segs, turn * math.tau * (k + 1) / segs
        m.quad(at(r_foot, a0, 0.0), at(r_foot, a1, 0.0), at(r_face, a1, depth), at(r_face, a0, depth))
    m.poly([at(r_face, turn * math.tau * k / segs, depth) for k in range(segs)])


def ring(m: Mesh, centre: tuple, outer: float, inner: float, facing: float, segs: int = 16, axis: str = "z") -> None:
    """A flat ring (a bezel) on a face along `axis` toward `facing`, round `centre`."""
    cx, cy, cz = centre

    def at(r: float, a: float) -> tuple:
        u, v = r * math.cos(a), r * math.sin(a)
        return (cx + u, cy + v, cz) if axis == "z" else (cx, cy + v, cz + u)

    turn = 1.0 if (axis == "z") == (facing > 0) else -1.0
    for k in range(segs):
        a0, a1 = turn * math.tau * k / segs, turn * math.tau * (k + 1) / segs
        m.quad(at(inner, a0), at(outer, a0), at(outer, a1), at(inner, a1))
