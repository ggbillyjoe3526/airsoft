"""Subway's ballast wagons (SM4, model 8): a low-sided open wagon heaped with ballast, from the owner's photos
(art/references/maps/subway/08-ballast-wagon, the planked engineers' wagons in grey): four-plank sides and ends, each
plank's edges chamfered so the seams read, an outside steel stanchion with a knee at each end and either side of the
door, a bolt through its top plank, diagonal strapping, an angle-iron capping round the top; a drop door in the middle
of each side on two strap hinges with their knuckles, a brace across it, its catches' keepers on the stanchions. Under
it a short channel underframe in finer detail (`underframe`, shared with the engineering wagon): W-irons with their
tie bars, axle boxes with round covers under cambered leaf springs on hangers, riveted solebars and headstocks,
diagonal braces, sprung buffers on square flanges, a coupling hook and a link hanging from it, brake blocks hung on
the wheels with their beams, V-hangers and a lever down each side to its pin rack. Full of grey ballast heaped over the
sides: small angular facets, light and dark, loose stones on top. Engineers' grey, rust at the joints; no lettering.

SQ1 (2026-11-21) rebuilt it finer: chamfered planks and the door's hinges and catches, a lighter grey that reads in
the dark running tunnel (it read as a dark box), the detailed underframe and a finer ballast heap.

Its two blocks (the north running tunnel, 4 x 1.8 m and 2.2 m high, data/maps/subway.json) are centred on the track,
so the wagon's wheels stand on the station's running rails (works_kit.running_rails).

Writes assets/models/props/ballast_wagon.glb, one vertex-coloured mesh filling x -2..2 (along the track), y -0.9..0.9,
z 0..2.2 exactly (Godot: x along, y up, z across).

Usage: python3 -I tools/blender/maps/ballast_wagon.py [--render <sheet.jpg>]
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

NAME = "ballast_wagon"
BUDGET = 5000
HL, HD, HIGH = 2.0, 0.9, 2.2

# The engineers' grey the planks are painted (the photos' grey wagons), lighter than the frames so the body reads in
# the dark tunnel, and a pale stone for the ballast's lighter pieces (sRGB, low saturation: off the teams' hues).
wk.PAINT["plank_grey"] = 0x8c8e88
wk.PAINT["stone_pale"] = 0x8a8680

BODY_X = 1.78        # the body's half length (its ends' outside)
SIDE_Y = 0.85        # the sides' outside (planks); stanchions stand proud to the box's side
SIDE_TOP = 1.86
PLANKS = 4
PLANK_T = 0.05       # a plank's thickness
CHAMFER = 0.014      # its outer edges' chamfer: the seam between two planks
STANCHIONS = (-BODY_X + 0.035, -0.62, 0.62, BODY_X - 0.035)
DOOR_X = 0.58        # the drop door's half length


def leaf_spring(k: wk.Kit, x: float, y: float, z_mid: float, z_end: float, half: float, mat: str,
                leaves: tuple = (1.0, 0.7, 0.42), t: float = 0.016, w: float = 0.06) -> None:
    """A leaf spring seen side on (along x, `half` either side of x): leaves stepping shorter downwards, cambered from
    its buckle at z_mid up to its eyes at z_end, a buckle round its middle."""
    for i, frac in enumerate(leaves):
        h = half * frac
        top = [(x + h * u, z_mid - i * t + (z_end - z_mid) * u * u + t) for u in (-1.0, 0.0, 1.0)]
        bot = [(px, pz - t) for px, pz in reversed(top)]
        k.prism(top + bot, "y", y - w * 0.5, y + w * 0.5, mat)
    k.blk((x - 0.035, y - w * 0.6, z_mid - t * len(leaves) - 0.025), (x + 0.035, y + w * 0.6, z_mid + t + 0.01), mat)


def link(k: wk.Kit, centre: tuple, length: float, width: float, r: float, mat: str, across: bool) -> None:
    """A chain link: an oval loop of round bar `length` long hanging upright, its loop's plane along x or y."""
    cx, cy, cz = centre
    path = []
    for i in range(6):
        a = 2.0 * math.pi * i / 6
        u, v = 0.5 * width * math.cos(a), 0.5 * length * math.sin(a)
        path.append((cx + (0.0 if across else u), cy + (u if across else 0.0), cz + v))
    rings = []
    for i, p in enumerate(path):
        q = Vector(path[(i + 1) % 6]) - Vector(path[i - 1])
        side = Vector((0.0, 1.0, 0.0) if not across else (1.0, 0.0, 0.0))
        n = q.normalized().cross(side).normalized()
        rings.append([tuple(Vector(p) + side * r * math.cos(b) + n * r * math.sin(b))
                      for b in (0.0, 2.0 * math.pi / 3, 4.0 * math.pi / 3)])
    rings.append(rings[0])
    k.loft(rings, mat, cap0=False, cap1=False)


def underframe(k: wk.Kit, hl: float, hw: float, axle_x: float, wheel_r: float, rail_top: float, paint: str,
               buffer_y: float = 0.5, seg: int = 12, lever: str = "works_yellow", web: str = "") -> float:
    """A short works wagon's underframe in detail, `hl` m from its middle to its buffer faces and `hw` to its
    solebars' outside: two wheelsets `axle_x` m either side of the middle on the running rails, each axle box in a
    W-iron (splayed legs, a tie bar under the box) under a cambered leaf spring on hangers, riveted channel solebars
    and headstocks, cross members and diagonal braces, a sprung buffer on a square flange either side of a coupling
    hook and a link at each end, brake blocks on the wheels' inner treads hung from the solebars, their beams and
    a push rod, a V-hanger and a lever down each side to its pin rack. The solebars' webs are painted `web` when given
    (the engineering wagon's yellow). Returns the solebars' top."""
    zc = rail_top + wheel_r
    z0, z1 = zc + 0.1, zc + 0.36           # the solebars
    zm = (z0 + z1) * 0.5
    for x in (-axle_x, axle_x):
        k.wheelset(x, wk.WHEEL_IN, zc, wheel_r, 0.07, seg=seg)
        for s in (-1.0, 1.0):
            y = s * (hw - 0.05)
            k.axle_box(x, y, zc, 0.17, 0.2, 0.09, paint)
            k.cyl((x, y + s * 0.045, zc - 0.01), 0.055, s * 0.016, paint, seg=6, axis="y")  # its cover
            for dx in (-1.0, 1.0):  # the W-iron's legs, splayed up to the solebar
                k.sqbar((x + dx * 0.1, y, zc - 0.11), (x + dx * 0.27, y, z0 + 0.01), 0.045, paint, h=0.022)
            k.blk((x - 0.12, y - 0.011, zc - 0.135), (x + 0.12, y + 0.011, zc - 0.1), paint)  # its tie bar
            leaf_spring(k, x, y, zc + 0.15, z0 - 0.025, 0.4, paint)
            for dx in (-0.42, 0.42):  # the spring's hangers from the solebar
                k.blk((x + dx - 0.022, y - 0.038, z0 - 0.06), (x + dx + 0.022, y + 0.038, z0 + 0.02), paint)
    for s in (-1.0, 1.0):  # channel solebars, their flanges turned out, riveted at the W-irons and hangers
        y0, y1 = sorted((s * hw, s * (hw - 0.02)))
        k.blk((-hl + 0.12, y0, z0), (hl - 0.12, y1, z1), web or paint)
        yf0, yf1 = sorted((s * (hw - 0.02), s * (hw - 0.09)))
        for z in (z0, z1 - 0.02):
            k.blk((-hl + 0.12, yf0, z), (hl - 0.12, yf1, z + 0.02), paint)
        k.bolts([(sx * (axle_x + dx), s * hw, zm + dz) for sx in (-1.0, 1.0) for dx in (-0.27, 0.27)
                 for dz in (0.06,)], 0.013, 0.01, "y" if s > 0 else "-y", web or paint)
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * (hl - 0.12), sx * (hl - 0.22)))
        k.blk((xa, -hw, z0 - 0.02), (xb, hw, z1), paint)  # the headstock
        xh = sx * (hl - 0.12)
        sxx = "x" if sx > 0 else "-x"
        k.bolts([(xh, y, z) for y in (-hw + 0.06, -0.2, 0.2, hw - 0.06) for z in (z1 - 0.04,)], 0.013, 0.01,
                sxx, paint)
        for y in (-buffer_y, buffer_y):  # buffers: a square flange, the housing, the ram and the sprung head
            fa, fb = sorted((xh, xh + sx * 0.02))
            k.blk((fa, y - 0.11, zm - 0.11), (fb, y + 0.11, zm + 0.11), paint)
            k.lathe([(0.0, 0.085), (sx * 0.04, 0.07), (sx * 0.06, 0.062)], paint, segments=10,
                    centre=(xh + sx * 0.02, y, zm), axis="x", cap=False)
            k.cyl((xh + sx * 0.08, y, zm), 0.04, sx * 0.025, "steel_bare", seg=6, axis="x")  # the ram
            k.lathe([(0.0, 0.11), (sx * 0.018, 0.12), (sx * 0.025, 0.105)], "steel_bare", segments=10,
                    centre=(sx * (hl - 0.025), y, zm), axis="x", cap=True)  # the head, its face crowned
        # the coupling: a drawbar plate, the hook through it, and its chain hanging in two links
        k.blk((min(xh, xh + sx * 0.015), -0.07, zm - 0.08), (max(xh, xh + sx * 0.015), 0.07, zm + 0.06), paint)
        k.prism([(xh, zm - 0.03), (xh + sx * 0.09, zm - 0.03), (xh + sx * 0.11, zm - 0.06), (xh + sx * 0.105,
                 zm + 0.03), (xh + sx * 0.08, zm + 0.04), (xh + sx * 0.085, zm - 0.005), (xh, zm + 0.01)][::int(sx)],
                "y", -0.018, 0.018, "rust")
        link(k, (xh + sx * 0.095, 0.0, zm - 0.1), 0.11, 0.05, 0.009, "rust", across=True)
    for x in (-axle_x * 0.5, 0.0, axle_x * 0.5):  # cross members
        k.blk((x - 0.04, -hw + 0.02, z1 - 0.14), (x + 0.04, hw - 0.02, z1), paint)
    for sx in (-1.0, 1.0):  # diagonal braces from the middle out to the headstock's corners
        for s in (-1.0, 1.0):
            k.sqbar((sx * 0.05, 0.0, z1 - 0.06), (sx * (hl - 0.24), s * (hw - 0.1), z1 - 0.06), 0.06, paint, h=0.012)
    # the brakes: a block on each wheel's inner tread, hung from the solebar, a beam across, a push rod between
    yb = wk.WHEEL_IN + 0.035
    for x in (-axle_x, axle_x):
        sx = 1.0 if x > 0 else -1.0
        xb = x - sx * (wheel_r + 0.02) * 0.9
        for s in (-1.0, 1.0):
            k.prism([(xb - 0.03, zc - 0.1), (xb + 0.01 * sx, zc - 0.12), (xb + 0.025, zc + 0.1),
                     (xb - 0.015 * sx, zc + 0.12)][:: int(sx)], "y", s * yb - 0.04, s * yb + 0.04, "steel_bare")
            k.sqbar((xb - sx * 0.02, s * (hw - 0.12), zc + 0.08), (xb - sx * 0.05, s * (hw - 0.12), z0 + 0.01), 0.03,
                    paint)  # its hanger
        k.blk((xb - sx * 0.05, -yb, zc - 0.018), (xb - sx * 0.02, yb, zc + 0.018), paint)  # the beam
    k.sqbar((-axle_x + wheel_r, 0.0, zc), (axle_x - wheel_r, 0.0, zc), 0.03, paint)  # the push rod
    k.bar((-0.12, -hw + 0.1, zc - 0.05), (-0.12, hw - 0.1, zc - 0.05), 0.02, paint, seg=6)  # the cross shaft
    for s in (-1.0, 1.0):  # a V-hanger and a lever each side, its handle end painted, a pin rack at the end
        y = s * (hw + 0.025)
        side = -1.0 if s < 0 else 1.0
        k.prism([(-0.3, z0), (0.06, z0), (-0.1, zc - 0.1), (-0.14, zc - 0.1)], "y", min(s * hw, s * (hw + 0.012)),
                max(s * hw, s * (hw + 0.012)), paint)
        tip = -hl + 0.36 if side < 0 else hl - 0.36
        mid = -0.12 + (tip + 0.12) * 0.62
        zt = zc - 0.1
        k.sqbar((-0.12, y, zc - 0.05), (mid, y, (zc - 0.05) * 0.38 + zt * 0.62), 0.035, paint, h=0.025)
        k.sqbar((mid, y, (zc - 0.05) * 0.38 + zt * 0.62), (tip, y, zt), 0.035, lever, h=0.025)
        k.blk((tip - 0.06, y - 0.012 * s, zc - 0.28), (tip + 0.06, y, zc + 0.04), paint)  # the pin rack
        k.bar((tip, y + s * 0.012, zc - 0.16), (tip, y - s * 0.03, zc - 0.16), 0.01, "steel_bare", seg=4)  # its pin
    return z1


def pebble(k: wk.Kit, centre: tuple, r: float, mat: str, rng: random.Random, squash: float = 0.7) -> None:
    """An angular stone: an icosahedron, its corners pushed in and out, flattened by `squash`, turned any way."""
    bm = k.bm
    made = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)["verts"]
    for v in made:
        v.co = Vector((v.co.x * rng.uniform(0.75, 1.2), v.co.y * rng.uniform(0.75, 1.2),
                       v.co.z * squash * rng.uniform(0.8, 1.15)))
    faces = list({f for v in made for f in v.link_faces})
    turn = Euler((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), rng.uniform(0.0, math.tau))).to_matrix().to_4x4()
    k.transform(faces, Matrix.Translation(Vector(centre)) @ turn)
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    k._faces(faces, mat)


def plank(k: wk.Kit, axis: str, a0: float, a1: float, out: float, s: float, z0: float, z1: float, mat: str) -> None:
    """A plank along `axis` from a0 to a1, its outer face at `out` (facing the sign s), PLANK_T thick, its outer
    edges chamfered so the seam to the next plank casts a line."""
    o, i, c = out, out - s * PLANK_T, CHAMFER
    poly = [(i, z0), (o - s * c, z0), (o, z0 + c), (o, z1 - c), (o - s * c, z1), (i, z1)]
    k.prism(poly, axis, a0, a1, mat)


def build() -> object:
    k = wk.Kit(NAME)
    rng = random.Random(8)
    rail_top = k.running_rails(-HL, HL)
    k.mark("track")
    deck = underframe(k, HL, 0.86, 1.1, 0.3, rail_top, "frame_black", seg=10)
    k.mark("underframe")
    floor = deck + 0.08
    k.blk((-BODY_X, -SIDE_Y, deck), (BODY_X, SIDE_Y, floor), "plank_grey")  # the floor's planks, edge on
    # Sides and ends: chamfered planks, each side's in three lengths (the door between the middle stanchions).
    ph = (SIDE_TOP - 0.05 - floor) / PLANKS
    for i in range(PLANKS):
        z0, z1 = floor + i * ph, floor + (i + 1) * ph
        for s in (-1.0, 1.0):
            for a0, a1 in ((-BODY_X, -DOOR_X - 0.04), (-DOOR_X, DOOR_X), (DOOR_X + 0.04, BODY_X)):
                plank(k, "x", a0, a1, s * SIDE_Y, s, z0, z1, "plank_grey")
        for sx in (-1.0, 1.0):
            o, inn, c = sx * BODY_X, sx * (BODY_X - PLANK_T), CHAMFER
            k.prism([(inn, z0), (o - sx * c, z0), (o, z0 + c), (o, z1 - c), (o - sx * c, z1), (inn, z1)], "y",
                    -SIDE_Y + PLANK_T, SIDE_Y - PLANK_T, "plank_grey")
    k.mark("planks")
    # Outside stanchions (flat bars, a knee at the foot onto the solebar, a bolt through each plank), the strapping,
    # the capping, the corner plates.
    for s in (-1.0, 1.0):
        sy = "y" if s > 0 else "-y"
        y0, y1 = sorted((s * SIDE_Y, s * HD))
        ym = (y0 + y1) * 0.5
        for x in STANCHIONS:
            k.blk((x - 0.035, y0, deck - 0.04), (x + 0.035, y1, SIDE_TOP), "plank_grey")
            k.prism([(s * (0.86 - 0.02), deck - 0.2), (s * HD, deck - 0.04), (s * SIDE_Y, deck - 0.04),
                     (s * (0.86 - 0.02), deck - 0.12)], "x", x - 0.025, x + 0.025, "plank_grey")  # the knee
            k.bolts([(x, s * HD, floor + ph * (j + 0.5)) for j in (PLANKS - 1,)], 0.014, 0.01, sy, "frame_black")
        for xa, xb in ((-BODY_X + 0.08, -0.66), (0.66, BODY_X - 0.08)):  # diagonal straps, bolted at the middle
            k.sqbar((xa, ym, floor + 0.05), (xb, ym, SIDE_TOP - 0.08), 0.045, "plank_grey", h=0.014)
            k.bolts([((xa + xb) * 0.5, s * (SIDE_Y + 0.014), (floor + SIDE_TOP) * 0.5 - 0.015)], 0.014, 0.01, sy,
                    "frame_black")
        # the capping: an angle along the top, its upstand on the outside
        k.blk((-BODY_X, min(s * (SIDE_Y - PLANK_T), s * SIDE_Y), SIDE_TOP - 0.05),
              (BODY_X, max(s * (SIDE_Y - PLANK_T), s * SIDE_Y), SIDE_TOP - 0.035), "plank_grey")
        k.blk((-BODY_X, min(y0, s * (SIDE_Y + 0.012)), SIDE_TOP - 0.09), (BODY_X, max(s * SIDE_Y, s * (SIDE_Y + 0.012)),
              SIDE_TOP), "plank_grey")
        # the drop door: three strap hinges along its foot, their knuckles on a pin; two cotter catches at the top
        for x in (-0.36, 0.36):
            k.blk((x - 0.03, min(s * SIDE_Y, s * (SIDE_Y + 0.01)), floor + 0.02),
                  (x + 0.03, max(s * SIDE_Y, s * (SIDE_Y + 0.01)), floor + 0.36), "frame_black")
            k.cyl((x - 0.05, s * (SIDE_Y + 0.02), floor + 0.02), 0.022, 0.1, "steel_bare", seg=6, axis="x")
        for x in (-DOOR_X + 0.05, DOOR_X - 0.05):
            k.blk((x - 0.035, min(s * SIDE_Y, s * HD), SIDE_TOP - 0.3), (x + 0.035, max(s * SIDE_Y, s * HD),
                  SIDE_TOP - 0.22), "steel_bare")  # the catch's keeper on the stanchion
        k.blk((-DOOR_X, min(s * SIDE_Y, s * (SIDE_Y + 0.008)), floor + ph * 2 - 0.035),
              (DOOR_X, max(s * SIDE_Y, s * (SIDE_Y + 0.008)), floor + ph * 2 + 0.035), "frame_black")  # its brace
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * BODY_X, sx * (BODY_X + 0.02)))
        for y in (-0.45, 0.0, 0.45):  # the end stanchions
            k.blk((x0, y - 0.035, floor - 0.04), (x1, y + 0.035, SIDE_TOP), "plank_grey")
            k.bolts([(sx * (BODY_X + 0.02), y, floor + ph * (j + 0.5)) for j in (PLANKS - 1,)], 0.014, 0.01,
                    "x" if sx > 0 else "-x", "frame_black")
        k.blk((x0, -SIDE_Y, SIDE_TOP - 0.09), (x1, SIDE_Y, SIDE_TOP), "plank_grey")  # the end's capping
    k.mark("ironwork")
    # The ballast, heaped over the sides to the box's top: small angular facets, loose stones on top.
    k.rubble(-BODY_X + 0.05, BODY_X - 0.05, -SIDE_Y + 0.05, SIDE_Y - 0.05, SIDE_TOP - 0.08, HIGH,
             ["ballast_dark", "ballast_dark", "ballast_dark", "ballast", "ballast", "stone_pale"], 32, 13, 0.1, 8,
             shape=heap)
    for i in range(10):
        x, y = rng.uniform(-BODY_X + 0.25, BODY_X - 0.25), rng.uniform(-SIDE_Y + 0.25, SIDE_Y - 0.25)
        z = SIDE_TOP - 0.08 + (HIGH - SIDE_TOP + 0.08) * heap(x / BODY_X, y / SIDE_Y)
        r = rng.uniform(0.04, 0.075)
        pebble(k, (x, y, min(z, HIGH - r * 0.5)), r, ("ballast_dark", "ballast", "stone_pale")[i % 3], rng,
               squash=rng.uniform(0.55, 0.85))
    k.mark("ballast")
    return k.build()


def heap(u: float, v: float) -> float:
    """The ballast heap's height (0..1) over the wagon, u along and v across in -1..1: flat on top, falling away."""
    return 1.0 - max(abs(u) ** 5.0 * 0.9, abs(v) ** 1.8)


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint in ("plank_grey", "frame_black"):
        col = wk.rusty(p, n, c, seed=5, amount=0.45 if paint == "plank_grey" else 0.55)
        if p.z > SIDE_TOP - 0.1:
            col = wt.mix(col, wk.lin("ballast"), 0.35 * wt.fbm(p, 0.1, 6))  # stone dust on the top rail
        return wk.grime(p, n, col, seed=2)
    if paint in ("ballast", "ballast_dark", "stone_pale"):
        col = wt.mix(c, wk.lin("ballast_dark"), 0.4 * wt.fbm(p, 0.06, 31))
        return wt.scale(col, 0.75 + 0.5 * wt.fbm(p * 7.0, 0.05, 33))  # a speckle: stone by stone, light and dark
    if paint in ("wheel", "rust"):
        return wk.grime(p, n, wk.rusty(p, n, c, seed=7, amount=0.4, streaks=False), seed=2)
    return wk.grime(p, n, c, seed=4)


def main() -> None:
    wk.reset()
    wk.check_colours(list(wk.PAINT))
    ob = build()
    wk.finish(ob, (-HL, -HD, 0.0), (HL, HD, HIGH))
    wk.bake(ob, weather, jitter={"plank_grey": 0.03, "ballast_dark": 0.1, "ballast": 0.08, "stone_pale": 0.1})
    wk.write(ob, NAME, BUDGET)
    if "--render" in sys.argv:
        wk.render(wk.quarter_views(2 * HL, 2 * HD, HIGH), sys.argv[sys.argv.index("--render") + 1],
                  "SM4 ballast wagon (Subway map prop, 4 x 1.8 x 2.2 m)")


if __name__ == "__main__":
    main()
