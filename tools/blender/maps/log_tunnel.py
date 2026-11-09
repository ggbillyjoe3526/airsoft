"""Woodland's crouch tunnels as hollow logs (WG4, model 16), from the owner's photos
(art/references/maps/woodland/16-crouch-tunnel-kit): an old oak trunk hollowed out, grey furrowed bark outside, the
inside carved smooth and worn pale, the cut ends showing their rings; the Crawl box and the Badger run are each one log
laid through their mound, the mound's earth piled over the log's middle.

The tunnels' blocks (tools/woodland/build_map.py, cut_tunnels) are 1 m sections: a wall either side (0.55 m thick, its
inner face 0.7 m off the tunnel's middle) and a roof over both (2.5 m across, the log's width, from 1.4 m over the
floor to the mound's top). The log fills them so the 1.4 m clear inside stays clear: its inner faces stand at or
outside the walls' and the roof's faces (they bow out a little, and the vault arches up into the roof's shell, look
only), and its outside stays inside the boxes. Three models, each 1 m along the tunnel (glTF z), both ends finished as
the log's cut end (heartwood, sapwood ring, bark rim), so the last section of a tunnel is its mouth; PropLayout bends
each section to meet its neighbours halfway where the floor steps, so the inside runs on without a seam:

- `log_tunnel_side.glb`: a wall's share of the log (0.55 x 1.75 m, its floor 0.35 m over its foot), its inner face
  toward -x (PropDressConfig's SIDE lay turns it to the tunnel's middle, unstretched, its top at the ceiling);
- `log_tunnel_roof.glb`: the log's round top shell, 0.9 m high and 2.5 m across, with the mound's earth heaped against
  its shoulders (PropDressConfig's LINED lay sets it on the roof's underside unstretched);
- `log_tunnel_cap.glb`: the mound's grassy earth over the log, sloping in toward its top, stretched over a roof from
  the earth's foot on the log's shoulders (PropDressConfig.lined_cap_from, WEDGE_FOOT) to the roof's top (LINED's cap),
  so it covers the log's top where the mound runs over it.

Bark, wood and earth are dull colours, off the teams' hues; the sapwood ring is pale yellow-cream.

    python3 -I tools/blender/maps/log_tunnel.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402
import weathering as wt  # noqa: E402
from mathutils import Vector  # noqa: E402

hs = mk.hs

ALONG = 1.0            # a section's length along the tunnel
STEPS = 2              # along it
WALL_IN, WALL_OUT = 0.7, 1.25
CLEAR = 1.4
FOOT = 0.35            # a wall's foot under the floor (build_map's SINK and the floor's fall)
SHELL = 0.9            # the roof model's height: the log's arched top over the clear height (a round log, about
                       # as high as it is wide)
ROOF_HALF = 1.25  # the roof block's half width: the log's outside (build_map.TUNNEL_ROOF_HALF)
WEDGE_FOOT = 0.5   # the earth against the log's shoulders: its height at the box's side, and the arc point it
WEDGE_TOP = 0.6    # climbs to (the first one outside this many metres from the middle)
CAP_SLOPE = 0.45  # the cap's top a share narrower than its foot (the cap is a unit high before LINED stretches it)

# The log's section in tunnel space (u across from the middle, v up from the floor), wall and roof shares, the inner
# and outer lines paired point for point (the cut end is lofted between them).
SIDE_IN = [(0.7, -FOOT), (0.7, 0.0), (0.79, 0.3), (0.83, 0.7), (0.815, 1.05), (0.795, 1.28), (0.78, CLEAR)]
SIDE_OUT = [(1.25, -FOOT), (1.25, 0.0), (1.25, 0.3), (1.25, 0.7), (1.24, 1.05), (1.215, 1.28), (1.15, CLEAR)]
# the hollow's vault: the 1.4 m clear at its sides, arching up to 0.28 m into the shell at the crown (look only: the
# roof block's underside, the 1.4 m ceiling, still stops a standing player)
_ROOF_IN = [(0.78, CLEAR), (0.74, CLEAR + 0.07), (0.63, CLEAR + 0.16), (0.46, CLEAR + 0.23),
            (0.24, CLEAR + 0.27), (0.0, CLEAR + 0.28)]
_ROOF_OUT = [(1.15, CLEAR), (1.094, CLEAR + 0.278), (0.93, CLEAR + 0.529), (0.676, CLEAR + 0.728),
             (0.355, CLEAR + 0.856), (0.0, CLEAR + SHELL)]
# the log's outer arc over the shell's foot, crown first (the earth wedges' inner edge)
ROOF_ARC = [(u, v - CLEAR) for u, v in reversed(_ROOF_OUT[1:-1])]
ROOF_IN = [(-u, v) for u, v in _ROOF_IN] + [(u, v) for u, v in reversed(_ROOF_IN[:-1])]
ROOF_OUT = [(-u, v) for u, v in _ROOF_OUT] + [(u, v) for u, v in reversed(_ROOF_OUT[:-1])]
END_LINES = (0.0, 0.84, 0.91, 1.0)  # a cut end's lines across the shell: heartwood, sapwood rim, bark, bark's edge

BARK = 0x5E5850        # grey-brown furrowed oak bark, dull
FURROW = 0x3C3934
WOOD = 0xB3A891        # the carved inside, weathered pale, dull
WORN = 0xC4B99F        # where knees and boots wear it
SAP = 0xD8CBA6         # the sapwood ring at a cut end, pale cream
HEART = 0x7C705E        # the heartwood, darker
CRACK = 0x4C463E
EARTH = 0x605B52       # earth, dull grey-brown (off the orange team)
ROOT = 0x3B342D
TURF = 0x8E9C5E        # turf and moss on the mound's top
MEADOW = 0x8AA860      # the mound's grass (the look's meadow, the ground's own colour)
LITTER = 0x7D7558      # leaf litter


def _along() -> list:
    return [-ALONG / 2 + ALONG * i / STEPS for i in range(STEPS + 1)]


def _bark_bump(p: Vector, period: float) -> float:
    """Bark furrows along the log, the same at both ends of a section (so sections join): ridges round the section,
    noise along it periodic in `period`."""
    a = 2.0 * math.pi * p.y / period
    q = Vector((p.x * 3.0 + p.z * 3.0, math.cos(a) * 0.6, math.sin(a) * 0.6))
    return wt.noise(q, 0.5, 3) - 0.5


def _shell(b: hs.Builder, inner: list, outer: list, place, mats: tuple, bump: float) -> None:
    """A length of the log's shell between two paired section lines, swept along the tunnel: its inner face, its outer
    face (bark, bumped out and in by `bump` m along the furrows) and both cut ends (lofted across through END_LINES).
    `place(u, v, y)` maps tunnel space to the model's."""
    bm = b.bm
    ys = _along()
    m_in, m_out, m_end = (b.mat(m) for m in mats)

    def ring_points(line: list, y: float, out: bool) -> list:
        pts = []
        for k, (u, v) in enumerate(line):
            p = Vector(place(u, v, y))
            if out and bump > 0.0 and 0 < k < len(line) - 1:
                p += Vector(place(u + bump * (_bark_bump(p, ALONG) - 0.5), v, y)) - Vector(place(u, v, y))
            pts.append(p)
        return pts

    for line, other, out, m in ((inner, outer, False, m_in), (outer, inner, True, m_out)):
        rows = [[bm.verts.new(p) for p in ring_points(line, y, out)] for y in ys]
        faces = []
        for a, c in zip(rows, rows[1:]):
            for k in range(len(line) - 1):
                f = bm.faces.new((a[k], a[k + 1], c[k + 1], c[k]))
                f.material_index = m
                faces.append(f)
        # facing away from the shell: from the paired point on the other line toward this one
        k = len(line) // 2
        away = Vector(place(*line[k], 0.0)) - Vector(place(*other[k], 0.0))
        _face_all(faces, away)
    # the cut ends, lofted from the inner line to the outer
    for y in (ys[0], ys[-1]):
        lines = []
        for t in END_LINES:
            pts = []
            for (ui, vi), (uo, vo) in zip(inner, outer):
                pts.append(Vector(place(ui + (uo - ui) * t, vi + (vo - vi) * t, y)))
            lines.append([bm.verts.new(p) for p in pts])
        faces = []
        for a, c in zip(lines, lines[1:]):
            for k in range(len(inner) - 1):
                f = bm.faces.new((a[k], a[k + 1], c[k + 1], c[k]))
                f.material_index = m_end
                faces.append(f)
        _face_all(faces, Vector(place(0.0, 0.0, y)) - Vector(place(0.0, 0.0, 0.0)))


def _face_all(faces: list, away: Vector) -> None:
    """Turns `faces` (one swept surface, wound alike) to face `away`, judged by their summed normal."""
    total = Vector()
    for f in faces:
        f.normal_update()
        total += f.normal * f.calc_area()
    if total.dot(away) < 0.0:
        for f in faces:
            f.normal_flip()


def side() -> None:
    """A wall's share: built in tunnel space for the +u wall, then placed with its inner face at x = 0 (model -x)."""
    hs.reset()
    mk.paints({"inside": WOOD, "bark": BARK, "end": SAP})
    b = hs.Builder("log_tunnel_side", ["inside", "bark", "end"])

    def place(u: float, v: float, y: float) -> tuple:
        return (u - WALL_IN, -y, v + FOOT)

    _shell(b, SIDE_IN, SIDE_OUT, place, ("inside", "bark", "end"), 0.035)
    ob = b.build()
    _finish(ob, "log_tunnel_side", 130)


def roof() -> None:
    hs.reset()
    mk.paints({"inside": WOOD, "bark": BARK, "end": SAP, "earth": EARTH})
    b = hs.Builder("log_tunnel_roof", ["inside", "bark", "end", "earth"])

    def place(u: float, v: float, y: float) -> tuple:
        return (u, -y, v - CLEAR)

    _shell(b, ROOF_IN, ROOF_OUT, place, ("inside", "bark", "end"), 0.02)
    # the mound's earth heaped against the log's shoulders, sloping from the box's side up onto the log (the ring
    # stands out of the slope at a mouth; the box's top corners over the slope are left open)
    for s in (-1.0, 1.0):
        outline = [(s * 1.15, 0.0), (s * ROOF_HALF, 0.0), (s * ROOF_HALF, WEDGE_FOOT)] + \
            [(s * u, v) for u, v in ROOF_ARC if u >= WEDGE_TOP]
        if s < 0:
            outline.reverse()
        b.prism(outline, "y", -ALONG / 2, ALONG / 2, "earth")
    ob = b.build()
    _finish(ob, "log_tunnel_roof", 260)


def cap() -> None:
    hs.reset()
    mk.paints({"earth": EARTH})
    b = hs.Builder("log_tunnel_cap", ["earth"])
    edge = 0.15   # the mound's shoulders rounded off its long top edges (a share of its height at the top)
    xs = [-ROOF_HALF, -ROOF_HALF + edge, -0.5, 0.0, 0.5, ROOF_HALF - edge, ROOF_HALF]
    ys = [-0.5, 0.5]
    zs = [0.0, 0.4, 0.8, 1.0]
    verts = wt.lattice_box(b, xs, ys, zs, "earth", skip=("-z",))
    nx, nz = len(xs) - 1, len(zs) - 1
    for i, di in ((0, 1), (nx, -1)):
        wt.chamfer_edge(verts, [(i, j, nz) for j in range(len(ys))], [((i + di, j, nz), (i, j, nz - 1))
                                                                       for j in range(len(ys))])
    ob = b.build()
    # the mound slopes in from the log's full width at its foot toward the crown, so it reads as earth heaped over
    # the log, not a block; the foot stays full width, so the model still fills its box
    for v in ob.data.vertices:
        v.co.x *= 1.0 - CAP_SLOPE * v.co.z
    _finish(ob, "log_tunnel_cap", 120)


def _finish(ob, name: str, budget: int) -> None:
    mk.clean(ob)
    mk.bake_vertex_colours(ob)
    bark, furrow, wood, worn, sap, heart, crack, earth, root, turf, litter = (
        mk.linear(c) for c in (BARK, FURROW, WOOD, WORN, SAP, HEART, CRACK, EARTH, ROOT, TURF, LITTER))
    meadow = mk.linear(MEADOW)
    sap_lin, wood_lin, bark_lin, earth_lin = sap, mk.linear(WOOD), mk.linear(BARK), mk.linear(EARTH)

    def near(c: tuple, ref: tuple) -> bool:
        return sum(abs(c[i] - ref[i]) for i in range(3)) < 1e-3

    def paint(p: Vector, n: Vector, c: tuple, slot: int) -> tuple:
        if near(c, bark_lin):
            # furrows dark, ridges paler, lichen grey-green in patches
            col = wt.mix(bark, furrow, wt.smooth(0.35, 0.65, wt.fbm(Vector((p.x * 2, p.y * 0.3, p.z * 2)), 0.12, 41)))
            return wt.mix(col, turf, 0.35 * wt.smooth(0.6, 0.8, wt.fbm(p, 0.4, 43)))
        if near(c, wood_lin):
            col = wt.mix(wood, heart, 0.4 * wt.fbm(Vector((p.x, p.y * 0.25, p.z)), 0.3, 47))
            # worn pale along the floor's edge and at shoulder height, where you brush past
            col = wt.mix(col, worn, 0.6 * wt.smooth(0.4, 0.8, wt.fbm(p, 0.5, 49)))
            return col
        if near(c, sap_lin):
            # the cut end: bark ring outside, sapwood, then heartwood and its rings; radial checks
            return _end_colour(p, name, bark, sap, heart, crack)
        if near(c, earth_lin):
            col = wt.mix(earth, root, 0.5 * wt.fbm(p, 0.25, 53))
            if n.z > 0.6:
                # the mound's own grass on top, a little turf and litter in it
                col = wt.mix(meadow, turf, 0.6 * wt.smooth(0.4, 0.8, wt.fbm(p, 0.6, 59)))
                return wt.mix(col, litter, 0.4 * wt.smooth(0.6, 0.85, wt.fbm(p, 0.3, 61)))
            if name == "log_tunnel_roof":
                # the wedges' ends: earth against the log, the mound's grass over it toward the top
                return wt.mix(col, wt.mix(meadow, turf, 0.4 * wt.fbm(p, 0.4, 67)), wt.smooth(0.0, 0.45, p.z / SHELL))
            if name == "log_tunnel_cap":
                # the mound's grass all over, a little earth showing through low down, so it reads as the mound
                grass = 1.0 - 0.3 * wt.smooth(0.3, 0.0, p.z) * wt.fbm(p, 0.3, 63)
                col = wt.mix(col, wt.mix(meadow, turf, 0.4 * wt.fbm(p, 0.4, 65)), grass)
            return col
        return c

    wt.weather(ob, paint)
    mk.report(ob, name, budget)
    wt.export(ob, name)


def _end_colour(p: Vector, name: str, bark, sap, heart, crack) -> tuple:
    """A cut end's colour at `p` by how far across the shell it lies (0 inner face, 1 bark): the darker heartwood
    inside, the pale sapwood ring, then a dark bark rim (END_LINES' bands), as in every photo of a cut log."""
    if name == "log_tunnel_side":
        u, v = p.x + WALL_IN, p.z - FOOT
        line_in, line_out = SIDE_IN, SIDE_OUT
    else:
        u, v = abs(p.x), p.z + CLEAR
        line_in, line_out = _ROOF_IN, _ROOF_OUT
    t = _across(u, v, line_in, line_out)
    if t >= END_LINES[2] - 1e-3:
        return wt.mix(bark, crack, 0.3 * wt.fbm(p, 0.2, 61))
    col = wt.mix(heart, sap, wt.smooth(0.0, END_LINES[1], t))
    return wt.scale(col, 0.94 + 0.06 * wt.fbm(p, 0.15, 63))


def _across(u: float, v: float, line_in: list, line_out: list) -> float:
    """How far (0..1) a point lies from the inner line to the outer: the nearest pair's share."""
    best, t_best = 1e9, 0.0
    for (ui, vi), (uo, vo) in zip(line_in, line_out):
        d = Vector((uo - ui, vo - vi))
        L2 = max(d.length_squared, 1e-9)
        t = max(0.0, min(1.0, ((u - ui) * d.x + (v - vi) * d.y) / L2))
        q = Vector((ui + d.x * t - u, vi + d.y * t - v)).length
        if q < best:
            best, t_best = q, t
    return t_best


side()
roof()
cap()
