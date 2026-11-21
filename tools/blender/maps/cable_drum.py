"""Subway's cable drums (SM4, model 11): a big wooden reel of black cable standing on its rims, from the owner's photos
(art/references/maps/subway/11-cable-drum): two flanges of sawn boards with a steel band round each rim and a steel
plate round the spindle hole, the cable wound turn on turn between them, each turn a round-shouldered ridge, with
its loose end trailing to the floor (photo 3), timber chocks under the rims. Weathered grey timber, black cable.

SQ1 (owner, 2026-11-21: every Subway model in finer detail) gave it the photos' parts at about twice the triangles:
each turn of the cable is now a real ridge between two grooves (smooth shaded, the grooves painted dark), the
flanges' steel bands stand proud of the boards, rusty square washers and bolts sit in two rings on each face, the
spindle plate is a bolted square plate round an arbor hole going dark into the drum, and the loose end comes off the
top of the coil, hangs in a loop past the flange and runs along the floor to its cut end.

Its blocks (data/maps/subway.json) are two sizes, so two models, each built at its block's size: `cable_drum` 2 m
along, 1.4 m across and 1.8 m high (the west passage's two; the chocks reach out along it), and `cable_drum_small`
1.4 m each way (the north tunnel's).

Writes assets/models/props/cable_drum*.glb, each one vertex-coloured mesh filling x -L/2..L/2, y -W/2..W/2 (the
drum's axle across), z 0..H exactly (Godot: x along, y up, z across).

Usage: python3 -I tools/blender/maps/cable_drum.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET = 2000
SIZES = {"cable_drum": (2.0, 1.4, 1.8), "cable_drum_small": (1.4, 1.4, 1.4)}
SEG = 28             # round the flanges
COIL_SEG = 20        # round the cable's coil (smooth shaded: its silhouette is the flanges')
TURNS = 11           # the cable's turns across the drum (a 115 mm cable), each a ridge between two grooves
GROOVE = 0.016       # how deep the grooves between the turns lie under their crowns
FLANGE_T = 0.07      # a flange's thickness

wk.PAINT["bolt_plate"] = 0x6a5a52      # the rusty square washers under the flanges' bolts
wk.PAINT["cable_core"] = 0x8a8a86      # the cable's cut end: its grey insulated cores


def bent(pts: list, bend: float, n: int = 2) -> list:
    """The polyline `pts` (Vectors) with each inner corner rounded over `bend` m either side (n points round it)."""
    out = [pts[0]]
    for i in range(1, len(pts) - 1):
        a, p, b = pts[i - 1], pts[i], pts[i + 1]
        p0 = p + (a - p).normalized() * min(bend, (p - a).length * 0.45)
        p1 = p + (b - p).normalized() * min(bend, (b - p).length * 0.45)
        for j in range(n + 1):
            u = j / n
            out.append(p0 * (1 - u) ** 2 + p * 2 * u * (1 - u) + p1 * u * u)
    out.append(pts[-1])
    return out


def pipe(k: wk.Kit, pts: list, r: float, mat: str, seg: int = 8, bend: float = 0.15) -> list:
    """A round cable along the polyline `pts`, its corners bent round, capped."""
    path = bent([Vector(p) for p in pts], bend, 3)
    rings, nrm = [], None
    for i, p in enumerate(path):
        if i == 0:
            t = (path[1] - path[0]).normalized()
        elif i == len(path) - 1:
            t = (path[-1] - path[-2]).normalized()
        else:
            t = ((path[i + 1] - p).normalized() + (p - path[i - 1]).normalized()).normalized()
        if nrm is None:
            nrm = t.cross(Vector((0.0, 0.0, 1.0)) if abs(t.z) < 0.9 else Vector((1.0, 0.0, 0.0))).normalized()
        else:
            nrm = (nrm - t * nrm.dot(t)).normalized()
        bi = t.cross(nrm)
        rings.append([p + (nrm * math.cos(2 * math.pi * j / seg) + bi * math.sin(2 * math.pi * j / seg)) * r
                      for j in range(seg)])
    return k.loft(rings, mat)


def flange(k: wk.Kit, s: float, y0: float, r: float, zc: float, coil_r: float) -> None:
    """One flange, its outer face at y0 (s its outward side): a disc of sawn boards (their joints dark lines down the
    face), a steel band round its rim standing a little proud of the boards, rusty square washers and bolts in two
    rings, and the square spindle plate round the arbor hole."""
    t = FLANGE_T
    rw = r - 0.012                     # the boards' face, inside the band
    k.lathe([(y0, rw), (y0 + s * 0.004, r - 0.004), (y0 - s * t, r), (y0 - s * t, coil_r)], "steel_bare",
            segments=SEG, centre=(0.0, 0.0, zc), axis="y", cap=False)
    ring = [(rw * math.cos(2 * math.pi * i / SEG), y0, zc + rw * math.sin(2 * math.pi * i / SEG)) for i in range(SEG)]
    k.fan(ring, (0.0, s, 0.0), "drum_wood")
    face = y0 + s * 0.0015
    for i in range(-3, 4):  # board joints: thin dark lines down the face
        x = i * r * 0.24
        h = math.sqrt(max(0.0, (rw - 0.01) ** 2 - x * x))
        pts = [(x - 0.007, face, zc - h), (x + 0.007, face, zc - h), (x + 0.007, face, zc + h),
               (x - 0.007, face, zc + h)]
        k.quad(pts if s < 0 else list(reversed(pts)), "drum_wood_dark")
    axis = "y" if s > 0 else "-y"
    pts = [(rr * math.cos(a), y0, zc + rr * math.sin(a)) for rr, n, a0 in ((r * 0.68, 6, 0.3), (r * 0.4, 5, 0.0))
           for a in (a0 + 2 * math.pi * i / n for i in range(n))]
    k.bolts(pts, 0.04, 0.007, axis, "bolt_plate", seg=4)  # the square washers, their bolt heads the raised tops
    # the spindle plate (a square steel plate), its arbor hole going dark into the drum, four bolts
    p = 0.17
    y1 = y0 + s * 0.006
    k.prism([(-p, zc - p), (p, zc - p), (p, zc + p), (-p, zc + p)], "y", *sorted((y0 - s * 0.002, y1)), "rust")
    k.lathe([(y1 + s * 0.0005, 0.065), (y1 - s * 0.08, 0.065)], "cable", segments=8, centre=(0.0, 0.0, zc),
            axis="y", cap=True)
    k.bolts([(sx * (p - 0.04), y1, zc + sz * (p - 0.04)) for sx in (-1, 1) for sz in (-1, 1)], 0.018, 0.006, axis,
            "steel_bare", seg=4)


def build(name: str, length: float, width: float, high: float) -> object:
    k = wk.Kit(name)
    r = high * 0.5
    zc = r
    hw = width * 0.5 - 0.012  # the flanges' faces, the spindle plates standing out to the box
    coil_r = r * 0.88                 # the cable's outside
    for s in (-1.0, 1.0):
        flange(k, s, s * hw, r, zc, coil_r)
    k.mark("flanges")
    # The cable: turn on turn between the flanges, each turn a ridge between two grooves (smooth shaded, the grooves
    # painted dark by `shade_turns`).
    inner = hw - FLANGE_T
    prof = [(-inner + inner * i / TURNS, coil_r - (0.0 if i % 2 else GROOVE)) for i in range(2 * TURNS + 1)]
    k.lathe(prof, "cable", segments=COIL_SEG, centre=(0.0, 0.0, zc), axis="y", cap=False)
    k.mark("coil")
    # its loose end: off the top of the coil at the +x side, hanging in a loop past the flanges' edge down to the
    # floor and along it, its cut end showing its grey cores
    y = inner * 0.45
    a = math.radians(35.0)
    reach = min(length * 0.5 - 0.06, r + 0.25)  # past the flanges where the box has room (the long drum's chocks)
    end = [(coil_r * math.cos(a) - 0.03, y, zc + coil_r * math.sin(a) - 0.02),
           (min(coil_r + 0.07, length * 0.5 - 0.05), y + 0.02, zc + 0.05), (min(reach, r - 0.04), y + 0.06, zc * 0.45),
           (reach - 0.1, y + 0.1, 0.04), (reach - 0.04, y + 0.3, 0.04)]
    pipe(k, end, 0.04, "cable", seg=6)
    k.cyl((reach - 0.04, y + 0.3 - 0.004, 0.04), 0.03, 0.008, "cable_core", seg=6, axis="y")
    k.mark("cable end")
    # Chocks: a timber wedge each side under the rims, reaching to the box's ends, a nail head or two on each.
    for sx in (-1.0, 1.0):
        x_out = sx * length * 0.5
        x_in = sx * (r * 0.55)
        for yy in (-(width * 0.5 - 0.07), width * 0.5 - 0.07):  # under the rims, inside the box
            k.prism([(x_in, 0.0), (x_out, 0.0), (x_out, 0.06), (x_in + sx * 0.05, 0.22)], "y", yy - 0.07, yy + 0.07,
                    "timber")
    k.mark("chocks")
    return k.build()


def shade_turns(ob: object, high: float, width: float) -> None:
    """Paints the coil's grooves after the bake: each corner of the coil at a groove (between two turns of the cable)
    dark, each at a turn's crown lit, so the turns read at a distance as well as by their shading."""
    zc = high * 0.5
    coil_r = zc * 0.88
    inner = width * 0.5 - 0.012 - FLANGE_T
    me = ob.data
    attr = me.color_attributes["Color"]
    vs = me.vertices

    def radius(v: object) -> float:
        return math.hypot(v.co.x, v.co.z - zc)

    for poly in me.polygons:
        rs = [radius(vs[i]) for i in poly.vertices]
        if len(rs) != 4 or min(rs) < coil_r - GROOVE - 0.003 or max(rs) > coil_r + 0.003 or \
                max(abs(vs[i].co.y) for i in poly.vertices) > inner + 0.002:
            continue
        for li, vi in zip(poly.loop_indices, poly.vertices):
            c = attr.data[li].color
            k = 0.4 if radius(vs[vi]) < coil_r - GROOVE * 0.5 else 1.7
            attr.data[li].color = (min(1.0, c[0] * k), min(1.0, c[1] * k), min(1.0, c[2] * k), 1.0)


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint in ("drum_wood", "drum_wood_dark", "timber"):
        col = wt.mix(c, wk.lin(wk.GRIME), 0.3 * wt.fbm(p, 0.2, 61))  # weathered grey timber, damp at the foot
        return wk.grime(p, n, col, seed=10)
    if paint in ("cable", "cable_core"):
        return wt.mix(c, wk.lin(wk.DUST), max(0.0, n.z) * 0.3 * wt.fbm(p, 0.3, 63))
    return wk.grime(p, n, wk.rusty(p, n, c, seed=7, amount=0.5, streaks=False), seed=2)


def main() -> None:
    wk.check_colours(list(wk.PAINT))
    for name, (length, width, high) in SIZES.items():
        wk.reset()
        ob = build(name, length, width, high)
        wk.finish(ob, (-length * 0.5, -width * 0.5, 0.0), (length * 0.5, width * 0.5, high))
        wk.bake(ob, weather, jitter={"timber": 0.08})
        shade_turns(ob, high, width)
        wk.write(ob, name, BUDGET)
        if "--render" in sys.argv:
            out = sys.argv[sys.argv.index("--render") + 1].replace(".jpg", "_%s.jpg" % name)
            wk.render(wk.quarter_views(length, width, high), out,
                      "SM4 %s (Subway map prop, %g x %g x %g m)" % (name.replace("_", " "), length, width, high))


if __name__ == "__main__":
    main()
