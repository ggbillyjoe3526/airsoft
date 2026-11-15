"""The range's sandbag wall (RM1, rebuilt RM2): a 1.2 m section of filled hessian bags, four courses two bags deep laid
half a bag over, the offset courses ended by a bag laid across the wall; each bag a heavy loaf, flat where it sits and
pressed 3 cm into the course below, its belly full against its neighbours, one end a flat sewn seam, the other
folded under or (a bag laid across) gathered to a round neck bound with cord and a frayed tuft. Built against William's
photos (art/references/maps/william-2026-11-09/sand_bag_wall): the real wall's close-up (photo 4) and the two stacks
(photos 3 and 5) give a bag 2.6 to 3 times as long as it stands on the face, about twice as long as it is wide, the
courses tight with dark creases and no light between them, the knots small and round.

PropLayout lays the section along each sandbag block in cells about 1.2 m long and 0.6 m deep
(PropDressConfig.grid_cells), stretched to its cell: the backstop's line (22 x 1.2 m) is two sections deep, the
firing point's low wall (2.4 x 0.4 m) one section a little squeezed. The courses that sit half a bag over end in
a whole bag laid across, so a line's end never shows a cut bag; either face can face the range.

The creases are baked in: Cycles' ambient occlusion darkens each bag where it meets the next (range_kit.occlude), and
the game draws the sacking matte (PropDressConfig.model_roughness).

Writes assets/models/props/sandbags.glb, one vertex-coloured mesh filling x -0.6..0.6, y -0.3..0.3, z 0..0.9
exactly (Godot: x along, y up, z across).

Usage: python3 tools/blender/maps/sand_bag_wall.py [--render <sheet.jpg>]
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import range_kit as rk  # noqa: E402

OUT = os.path.join(rk.PROPS, "sandbags.glb")
BUDGET = 5000  # docs/CC0_ASSETS.md › Size limits: a prop; 16 bags, about 95 % of it (RM2)
LONG, DEEP, HIGH = 1.2, 0.6, 0.9
COURSES = 4  # 0.225 m a course: a 0.6 m bag 2.67 times as long as it stands (photo 4: 2.7, photo 5: 3.0)
PITCH = HIGH / COURSES
BED = 0.03  # each course pressed this far into the crowns of the one below
OVERLAP = 0.06  # bags end to end in a course run into each other this far, so their bellies touch
STAGGER = 0.05  # the two rows' joints a little apart along the wall, so no crease runs straight through it
KNOT = 0.04  # a gathered neck and its tuft stand this far proud of the wall's face
FACE = DEEP * 0.5 - KNOT  # the bags' faces; the knots reach the box
# Points round a bag: 15 on its arc (sides and crown) and one under it, where it sits on the course below.
ARC = [math.radians(-66.0 + 312.0 * i / 14.0) for i in range(15)]
UNDER = math.radians(-90.0)
RING = len(ARC) + 1
SIDE_ROUND = 2.3  # the loaf's squareness (2 an ellipse): full shoulders, a soft crown
FOOT_ROUND = 4.0  # flatter underneath: it spreads where it sits
CENTRE = 0.42  # its widest point, a share of its height up
LUMP = 0.007  # the sacking's lumps, m in or out
SOIL = 0.12  # the splashed foot of the wall, m up

rk.check_colours(["hessian", "hessian_dark", "tie"], shade=0.08)


def _pow(v: float, e: float) -> float:
    return math.copysign(abs(v) ** e, v)


def _ring(w: float, h: float, kw: float, kh: float, zb: float, sag: float, neck: float = -1.0,
          neck_z: float = 0.0) -> list:
    """A bag's cross-section as (across, up) points, its foot at zb: a loaf w either side and h tall, scaled kw across
    and kh up about its widest line (the lower half shrinks less, so a bag's ends stay down on the course below), the
    crown dipped `sag` m; or, with `neck` > 0, a round neck of that radius at height `neck_z`."""
    pts = []
    c = CENTRE * h
    up, down = (h - c) * kh, c * min(1.0, kh + 0.55)
    for a in ARC + [UNDER]:
        cs, sn = math.cos(a), math.sin(a)
        if neck > 0.0:
            pts.append((neck * cs, neck_z + neck * sn))
            continue
        y = w * kw * _pow(cs, 2.0 / SIDE_ROUND)
        if sn >= 0.0:
            z = zb + c + up * _pow(sn, 2.0 / SIDE_ROUND) - sag * sn ** 4
        else:
            z = zb + c + down * _pow(sn, 2.0 / FOOT_ROUND)
        pts.append((y, z))
    return pts


def _lumps(ring: list, zc: float, u: float, p1: float, p2: float) -> list:
    """The sacking's lumps: each point of a body ring pushed in or out up to LUMP m from the bag's middle line, in two
    soft waves along and round it, their phases the bag's own (`p1`, `p2`), so no two bags are the same loaf."""
    out = []
    for j, (y, z) in enumerate(ring):
        if j in (0, len(ARC) - 1, len(ARC)):
            out.append((y, z))  # its foot stays down on the course below
            continue
        a = ARC[j]
        f = 0.6 * math.sin(math.tau * (1.5 * u + p1) + 2.0 * a) + 0.4 * math.sin(math.tau * (2.5 * u + p2) - 3.0 * a)
        d = math.hypot(y, z - zc)
        k = 1.0 + LUMP * f / max(d, 1e-6)
        out.append((y * k, zc + (z - zc) * k))
    return out


def _soil(ob: object) -> None:
    """The lowest course's sacking a little darker towards the ground, where rain splashes it (SOIL m up)."""
    me = ob.data
    col = me.color_attributes["Color"]
    for li, loop in enumerate(me.loops):
        z = me.vertices[loop.vertex_index].co.z
        if z < SOIL:
            k = 0.8 + 0.2 * z / SOIL
            c = col.data[li].color
            col.data[li].color = (c[0] * k, c[1] * k, c[2] * k, 1.0)


def _blend(a: list, b: list, t: float) -> list:
    return [(p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t) for p, q in zip(a, b)]


def bag(kit: rk.Kit, a0: float, a1: float, across: float, zb: float, w: float, h: float, header: bool, knot: bool,
        rng: random.Random) -> None:
    """One bag lying from a0 to a1 along x (along y when it is a `header`, laid across the wall), its middle `across`
    the other way, its foot at zb, w either side and h tall. Its a0 end is the flat sewn seam; its a1 end is folded
    under (blunt) or, with `knot`, gathered to a neck bound with cord and a frayed tuft standing KNOT past a1. Its
    size, sag, lean and how it lies are a little its own."""
    w *= rng.uniform(0.96, 1.03)
    h *= rng.uniform(0.97, 1.02)
    sag = h * rng.uniform(0.03, 0.06)
    yaw = rng.uniform(-0.025, 0.025)
    lean = rng.uniform(-0.03, 0.03)
    sense = 1.0 if a1 >= a0 else -1.0
    n = abs(a1 - a0)
    mid = (a0 + a1) * 0.5
    # Stations along from a0 (m): (along, across scale, up scale, crown sag scale).
    st = [(0.0, 0.72, 0.34, 0.0), (0.02, 0.88, 0.68, 0.2), (0.06, 0.965, 0.9, 0.5), (0.13, 1.0, 0.97, 0.8),
          (n * 0.5, 1.0, 1.0, 1.0), (n - 0.13, 1.0, 0.97, 0.8)]
    if knot:
        st += [(n - 0.035, 0.94, 0.87, 0.4), (n - 0.004, 0.62, 0.62, 0.0)]
    else:
        st += [(n - 0.06, 0.965, 0.88, 0.5), (n - 0.02, 0.89, 0.64, 0.2), (n, 0.7, 0.34, 0.0)]
    sections = [(t, _lumps(_ring(w, h, kw, kh, zb, sag * ks), zb + CENTRE * h, t / n, rng.random(), rng.random())
                 if 0 < i < len(st) - 1 else _ring(w, h, kw, kh, zb, sag * ks))
                for i, (t, kw, kh, ks) in enumerate(st)]
    tie = None
    if knot:
        # The neck drops a little below the bag's widest line, gathered to 16 points round (it reads round close up),
        # the cord over it, then the tuft flaring out frayed.
        nz = zb + CENTRE * h * 0.9
        neck = _ring(w, h, 1.0, 1.0, zb, 0.0, neck=0.024, neck_z=nz)
        cord = _ring(w, h, 1.0, 1.0, zb, 0.0, neck=0.029, neck_z=nz - 0.004)
        tz = nz - 0.016
        tuft = _ring(w, h, 1.0, 1.0, zb, 0.0, neck=0.04, neck_z=tz)
        fray = [1.0 if i % 2 else 0.86 for i in range(RING)]  # its frayed edge, every other point drawn in
        tuft = [(y * f, tz + (z - tz) * f) for (y, z), f in zip(tuft, fray)]
        sections[-1] = (sections[-1][0], _blend(sections[-1][1], neck, 0.45))
        sections += [(n + KNOT * 0.3, neck), (n + KNOT * 0.5, cord), (n + KNOT, tuft)]
        tie = len(sections) - 3

    def place(along: float, side: float, z: float) -> tuple:
        # Turned `yaw` about the bag's middle and leaning `lean` (its crown towards one face).
        d = along - mid
        side += lean * (z - zb)
        dx, dy = d * math.cos(yaw) - side * math.sin(yaw), d * math.sin(yaw) + side * math.cos(yaw)
        return (across + dy, mid + dx, z) if header else (mid + dx, across + dy, z)

    rings = [[place(a0 + sense * t, y, z) for y, z in ring] for t, ring in sections]
    paint = "hessian" if rng.random() > 0.35 else "hessian_dark"
    if tie is None:
        kit.loft(rings, paint, cap0=False, cap1=False)
    else:
        kit.loft(rings[:tie + 1], paint, cap0=False, cap1=False)
        kit.loft(rings[tie:tie + 2], "tie", cap0=False, cap1=False)
        kit.loft(rings[tie + 1:], "hessian_dark", cap0=False, cap1=False)
    kit.fan(rings[0], _facing(rings[0], rings[1]), paint)
    out = _facing(rings[-1], rings[-2])
    if knot:
        # The tuft's frayed end bunched to a blunt point, drooping.
        d = math.sqrt(sum(v * v for v in out)) or 1.0
        kit.fan(rings[-1], out, "hessian_dark", apex=(out[0] / d * 0.014, out[1] / d * 0.014, -0.006))
    else:
        kit.fan(rings[-1], out, paint)


def _facing(first: list, second: list) -> tuple:
    a = [sum(p[i] for p in first) / len(first) for i in range(3)]
    b = [sum(p[i] for p in second) / len(second) for i in range(3)]
    return tuple(a[i] - b[i] for i in range(3))


def section() -> object:
    rng = random.Random(11)
    k = rk.Kit("Sandbags")
    hl = LONG * 0.5
    w = FACE * 0.5 + 0.008  # two rows across, their bellies pressed together
    for c in range(COURSES):
        zb = 0.0 if c == 0 else c * PITCH - BED
        h = (c + 1) * PITCH - zb
        rows = (-FACE * 0.5, FACE * 0.5)
        if c % 2 == 0:
            # Stretchers: two rows of bags along the wall, end to end, their seams to the section's ends (blunt, so the
            # next section's bags close up to them) and their folded ends meeting in the middle.
            for side, row in zip((-1.0, 1.0), rows):
                joint = side * STAGGER * (1.0 if c == 0 else -1.0)
                bag(k, -hl, joint + OVERLAP * 0.5, row, zb, w, h, False, False, rng)
                bag(k, hl, joint - OVERLAP * 0.5, row, zb, w, h, False, False, rng)
        else:
            # Half a bag over: a stretcher in each row in the middle, and a whole bag laid across the wall at each end
            # (a header), so a line's end shows tied bags, never a cut one. The headers' knots face opposite ways and
            # swap each offset course, so both faces show them.
            for row in rows:
                bag(k, -hl * 0.5 - OVERLAP * 0.5, hl * 0.5 + OVERLAP * 0.5, row, zb, w, h, False, False, rng)
            hw = hl * 0.25 + OVERLAP * 0.25
            for sx in (-1.0, 1.0):
                out = sx if c == 1 else -sx
                bag(k, -out * FACE, out * FACE, sx * (hl - hw), zb, hw, h, True, True, rng)
    ob = k.build()
    rk.finish(ob, angle=math.radians(70.0))
    rk.stretch_to(ob, (-hl, -DEEP * 0.5, 0.0), (hl, DEEP * 0.5, HIGH))
    rk.bake(ob, jitter={"hessian": 0.1, "hessian_dark": 0.1, "tie": 0.05}, seed=7, islands=True)
    _soil(ob)
    rk.occlude(ob, strength=0.6, distance=0.15)
    rk.fit_box(ob, (-hl, -DEEP * 0.5, 0.0), (hl, DEEP * 0.5, HIGH))
    return ob


def main() -> None:
    rk.reset()
    ob = section()
    n = rk.report([ob])
    if n > BUDGET:
        raise SystemExit("over budget")
    rk.export(OUT, [ob])
    print("wrote", os.path.relpath(OUT, rk.ROOT))
    if "--render" in sys.argv:
        _render(ob, sys.argv[sys.argv.index("--render") + 1])


def _render(ob: object, out: str) -> None:
    import bpy
    from mathutils import Matrix
    ob.hide_render = True
    # Six sections two deep (the backstop's line), and the firing point's wall: two sections squeezed to 0.4 m.
    for i in range(6):
        for j in (0, 1):
            c = ob.copy()
            bpy.context.scene.collection.objects.link(c)
            c.matrix_world = Matrix.Translation((i * LONG, j * DEEP, 0.0)) @ Matrix.Rotation(math.pi * ((i + j) % 2),
                                                                                              4, "Z")
            c.hide_render = False
    for i in range(2):
        c = ob.copy()
        bpy.context.scene.collection.objects.link(c)
        c.matrix_world = Matrix.Translation((1.2 + i * LONG, -2.6, 0.0)) @ Matrix.Diagonal((1.0, 0.4 / DEEP, 1.0, 1.0))
        c.hide_render = False
    import range_render as rr
    rr.render_sheet([
        ("Backstop line: 6 sections, 2 deep (7.2 x 1.2 m)", (3.0, -6.0, 1.8), (3.0, 0.3, 0.45), 30),
        ("Down the line", (8.2, -1.2, 1.1), (0.0, 0.3, 0.4), 30),
        ("Bags close-up: creases, a knot", (2.0, -1.2, 0.9), (1.6, 0.0, 0.45), 40),
        ("Firing point's low wall (2.4 x 0.4 m)", (1.0, -4.5, 1.2), (1.8, -2.6, 0.45), 35),
        ("Top of the line", (2.6, -1.0, 2.0), (2.4, 0.6, 0.8), 35),
        ("Line's end, against the light", (-1.6, -0.7, 0.45), (0.0, 0.6, 0.4), 35),
    ], out, "Sandbag wall (Range map prop, rebuilt): one 1.2 m section repeated", roughness=0.97)


if __name__ == "__main__":
    main()
