"""The range's sandbag wall (RM1): a 1.2 m section of filled hessian bags 0.6 x 0.3 m, four courses two bags deep laid
half a bag over, the offset courses ended by a bag laid across the wall; each a soft pillow with a flat sewn seam at
one end and its neck bound with cord at the other (William's photos, art/references/maps/william-2026-11-09/
sand_bag_wall: the long backstop line of fat tan bags, every other course half a bag over).

PropLayout lays the section along each sandbag block in cells about 1.2 m long and 0.6 m deep
(PropDressConfig.grid_cells), stretched to its cell: the backstop's line (22 x 1.2 m) is two sections deep, the
firing point's low wall (2.4 x 0.4 m) one section a little squeezed. The courses that sit half a bag over end in
a whole bag laid across, so a line's end never shows a cut bag; either face can face the range.

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
BUDGET = 4200  # the plan said 800; sixteen round bags, each with a seam and a tied neck (RM1); AUD2: 20 points round
LONG, DEEP, HIGH = 1.2, 0.6, 0.9
COURSES = 4  # a bag 0.6 x 0.3 m lies about 0.23 m high (the photos' 2:1 in plan and 2.5:1 on the face)
BAG = 0.6  # a bag's length
# Points round a bag: most on its visible arc (sides and top), one on its flat underside on the course below.
ARC = [math.radians(-25.0 + 12.0 * i) for i in range(20)]  # -25 to 203 degrees: no facet reads on the round (AUD2)
UNDER = [math.radians(a) for a in (270.0,)]
RING = len(ARC) + len(UNDER)

rk.check_colours(["hessian", "hessian_dark", "tie"], shade=0.08)


def _section(cy: float, cz: float, ry: float, rz: float, ky: float, kz: float, turn: float) -> list:
    """A bag's cross-section round (cy, cz): a pillow ry by rz, scaled ky across and kz up (a seam is wide and flat,
    a tied neck small), flat underneath where it sits on the course below, rolled `turn` (rad)."""
    pts = []
    ct, st = math.cos(turn), math.sin(turn)
    for a in ARC + UNDER:
        c, s = math.cos(a), math.sin(a)
        y = ry * ky * math.copysign(abs(c) ** 0.55, c)
        z = rz * kz * (math.copysign(abs(s) ** 0.75, s) if s > 0 else 0.7 * s)
        pts.append((cy + y * ct - z * st, cz + y * st + z * ct))
    return pts


def bag(kit: rk.Kit, a0: float, a1: float, across: float, cz: float, ry: float, rz: float, header: bool,
        rng: random.Random) -> None:
    """One bag lying from a0 to a1 along x (along y when it is a `header`, laid across the wall), its middle
    `across` the other way: its sewn end a flat seam, its other end gathered to a neck bound with cord and a tuft
    beyond; pillowed between, its size, sag, roll and which way it lies a little its own."""
    ry *= rng.uniform(0.94, 1.03)
    rz *= rng.uniform(0.94, 1.06)
    turn = rng.uniform(-0.05, 0.05)
    sag = rng.uniform(-0.015, 0.008)
    flip = rng.random() < 0.5
    n = a1 - a0
    # (along from the seam, across, up, lift): the seam, the shoulder, the belly, the shoulder, the neck.
    body = [(0.0, 0.9, 0.16, 0.25), (0.06 / n, 0.96, 0.8, 0.06), (0.5, 1.0, 1.0, 0.0),
            (1.0 - 0.1 / n, 0.82, 0.78, 0.04), (1.0 - 0.035 / n, 0.36, 0.4, 0.2)]
    ear = [(1.0 - 0.035 / n, 0.38, 0.42, 0.2), (1.0, 0.4, 0.28, 0.26)]

    def place(along: float, side: float, z: float) -> tuple:
        return (side, along, z) if header else (along, side, z)

    def rings(stations: list) -> list:
        out = []
        for t, ky, kz, lift in stations:
            a = a1 - t * n if flip else a0 + t * n
            dz = sag if 0.2 < t < 0.8 else 0.0
            out.append([place(a, y, z + dz) for y, z in _section(across, cz - rz * (1.0 - kz) * 0.5 + rz * lift * 0.3,
                                                                ry, rz, ky, kz, turn)])
        return out

    def facing(first: list, second: list) -> tuple:
        return tuple(first[0][i] - second[0][i] for i in range(3))

    hull, tuft = rings(body), rings(ear)
    paint = "hessian" if rng.random() > 0.3 else "hessian_dark"
    kit.loft(hull, paint, cap0=False, cap1=False)
    kit.fan(hull[0], facing(hull[0], hull[1]), paint)
    kit.loft(tuft, "tie", cap0=False, cap1=False)
    kit.fan(tuft[-1], facing(tuft[-1], tuft[0]), "tie")


def section() -> object:
    rng = random.Random(7)
    k = rk.Kit("Sandbags")
    hl, hd = LONG * 0.5, DEEP * 0.5
    h = HIGH / COURSES
    for c in range(COURSES):
        cz = (c + 0.5) * h
        rz = h * 0.54  # a bag bulges a little into the next course, so no light shows between them
        if c % 2 == 0:
            # Stretchers: two rows of bags along the wall, end to end.
            for row in (-1.0, 1.0):
                for x0 in (-hl, 0.0):
                    bag(k, x0, x0 + BAG, row * hd * 0.5, cz, hd * 0.5, rz, False, rng)
        else:
            # Half a bag over: two rows of stretchers in the middle, and a whole bag laid across the wall at each
            # end (a header), so a line's end shows tied bags, never a cut one.
            for row in (-1.0, 1.0):
                bag(k, -BAG * 0.5, BAG * 0.5, row * hd * 0.5, cz, hd * 0.5, rz, False, rng)
            for sx in (-1.0, 1.0):
                bag(k, -hd, hd, sx * (hl - BAG * 0.25), cz, BAG * 0.25, rz, True, rng)
    ob = k.build()
    rk.finish(ob, angle=math.radians(70.0))
    rk.stretch_to(ob, (-hl, -hd, 0.0), (hl, hd, HIGH))
    rk.bake(ob, jitter={"hessian": 0.08, "hessian_dark": 0.08, "tie": 0.05}, seed=7, islands=True)
    rk.fit_box(ob, (-hl, -hd, 0.0), (hl, hd, HIGH))
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
        ("Bags close-up", (2.0, -1.2, 0.9), (1.6, 0.0, 0.45), 40),
        ("Firing point's low wall (2.4 x 0.4 m)", (1.0, -4.5, 1.2), (1.8, -2.6, 0.45), 35),
        ("Top of the line", (2.6, -1.0, 2.0), (2.4, 0.6, 0.8), 35),
        ("From 20 m", (3.0, -20.0, 1.6), (3.0, 0.0, 0.5), 30),
    ], out, "RM1 sandbag wall (map prop): 1.2 m section, from William's sandbag photos")


if __name__ == "__main__":
    main()
