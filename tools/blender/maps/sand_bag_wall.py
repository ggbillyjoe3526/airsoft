"""The range's sandbag wall (RM1, rebuilt RM2): 1.2 m sections of filled hessian sacks, four courses two bags deep,
that lock into each other along a wall as a real wall's courses do. Built against William's photos
(art/references/maps/william-2026-11-09/sand_bag_wall): the real wall's close-up (photo 4) and the two stacks (photos
3 and 5).

Each bag is a sack filled and laid flat: a pillow, full in its belly and thinning to its ends, each end sewn or folded
flat to a seam whose corners stand out as ears (photo 4: an end about 0.6 of the belly high), a tied corner here and
there gathered to a tail bound with cord (photo 5), the sacking lumped and creased towards its ends. A bag is 2.6 to
3.2 times as long as it stands on the face (photo 4: 3.1); its length, its height, how deep it sits in the course
below and how it lies are its own, so the joints wander as the photo's do.

The bond: the first and third courses end at the section's ends; the second and fourth lie half a bag over, the bag
over the section's +x end running on into the next section, which carries the rest of it at its -x end (cut flush
at the section's ends, the cut never seen). So no joint runs straight up a wall, and a wall reads as one, not a
section repeated. PropLayout lays the sections all one way round (PropDressConfig.grid_unturned) and closes each wall
with its end models (PropDressConfig.grid_ends): sandbags_start.glb at the wall's -x end and sandbags_end.glb at its
+x end, where the part of a running-on bag gives way to a bag laid across the wall (a header, its ends on the faces,
0.34 m wide: 1.5 times a course), as a real wall's ends are built.

The creases are baked in (Cycles' ambient occlusion, range_kit.occlude, with the next sections beside it so the joins
shade alike), the bags' tops paler where the sun bleaches them, their feet darker where rain splashes soil up; the
game draws the sacking matte (PropDressConfig.model_roughness). Each bag keeps one shade of its own (range_kit.tint),
so the two parts of a bag split between sections match.

Writes assets/models/props/sandbags.glb, sandbags_start.glb and sandbags_end.glb, each one vertex-coloured mesh
filling x -0.6..0.6, y -0.3..0.3, z 0..0.9 exactly (Godot: x along, y up, z across).

Usage: python3 tools/blender/maps/sand_bag_wall.py [--render <sheet.jpg>]
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import range_kit as rk  # noqa: E402

MODELS = (("sandbags", 0), ("sandbags_start", -1), ("sandbags_end", 1))  # (name, the end it closes: -x, none, +x)
BUDGET = 5000  # docs/CC0_ASSETS.md › Size limits: a prop; about 95 % of it (RM2)
LONG, DEEP, HIGH = 1.2, 0.6, 0.9
HL = LONG * 0.5
COURSES = 4  # 0.225 m a course: a 0.6 m bag 2.67 times as long as it stands (photo 4: 2.7 to 3.1, photo 5: 3.0)
PITCH = HIGH / COURSES
BED = (0.02, 0.04)  # m each bag sits down into the crowns of the bags under it
ROW = 0.137  # the two rows' middles, m either side of the wall's middle
HALF_W = 0.145  # a stretcher's half width: the rows' bellies pressed together, their faces 0.282 out (its ears,
# creased, 0.298)
HEADER_HW = 0.17  # a header's half width along the wall: 0.34 wide, 1.5 times a course
OVERLAP = 0.05  # m bags end to end in a course run into each other, their ends pressed together
JOINT = 0.08  # m the middle joint of a course that ends at the section's ends may wander either way
STRADDLE = (0.26, 0.34)  # m of the running-on bag inside each of the two sections that carry it
# Points round a bag, (across, up) from its widest line: 13 on its sides and crown, 0 and 180 degrees its widest (the
# ears' corners), and one under it, where it sits.
ARC = [math.radians(a) for a in (-55, -25, 0, 25, 50, 70, 90, 110, 130, 155, 180, 205, 235)]
UNDER = math.radians(-90.0)
FOOT = (0, len(ARC) - 1, len(ARC))  # the points that stay down on the course below
SIDE_ROUND = 2.3  # the belly's squareness (2 an ellipse): full shoulders, a soft crown
FOOT_ROUND = 4.0  # flatter underneath: it spreads where it sits
CENTRE = 0.42  # its widest line, a share of its height up
# Along a bag from an end (m): (along, across scale, up scale, crown sag scale, the seam's middle drawn in): the end's
# flat seam, its corners standing out as ears, then the bag filling out to its belly.
END = ((0.0, 1.04, 0.32, 0.0, 0.026), (0.02, 1.01, 0.56, 0.15, 0.012), (0.06, 0.995, 0.75, 0.45, 0.0),
       (0.14, 1.0, 0.92, 0.8, 0.0))
# An end at a section's end that the next section's bag meets: pressed full against it, so no light shows through the
# joint between the two (the bags inside a section run into each other OVERLAP instead).
PRESSED = ((0.0, 0.94, 0.8, 0.2, 0.0), (0.015, 0.975, 0.9, 0.45, 0.0), (0.05, 0.995, 0.96, 0.7, 0.0),
           (0.14, 1.0, 0.985, 0.9, 0.0))
LUMP = 0.007  # the sacking's lumps, m in or out
CREASE = 0.006  # its creases fanning in from the ears, m at the seam
SOIL = 0.12  # the splashed foot of the wall, m up
TIE = 0.55  # the share of a bag's ends inside a section that show a tied corner on the wall's face

rk.check_colours(["hessian", "hessian_dark", "tie"], shade=0.08)


def _pow(v: float, e: float) -> float:
    return math.copysign(abs(v) ** e, v)


def _ring(w: float, h: float, kw: float, kh: float, sag: float) -> list:
    """A bag's cross-section as (across, up) points from its foot: a loaf w either side and h tall, scaled kw across
    and kh up about its widest line (the lower half shrinks less, so a bag's ends stay down on the course below), its
    crown dipped `sag` m."""
    pts = []
    c = CENTRE * h
    up, down = (h - c) * kh, c * min(1.0, kh + 0.5)
    for a in ARC + [UNDER]:
        cs, sn = math.cos(a), math.sin(a)
        y = w * kw * _pow(cs, 2.0 / SIDE_ROUND)
        if sn >= 0.0:
            z = c + up * _pow(sn, 2.0 / SIDE_ROUND) - sag * sn ** 4
        else:
            z = c + down * _pow(sn, 2.0 / FOOT_ROUND)
        pts.append((y, z))
    return pts


class Bag:
    """One bag from `a0` to `a1` along the wall (x), or across it (y) when a `header`, its middle line at `mid` the
    other way, its foot at `zb`, `w` either side and `h` tall. The bag running on past the section's +x end is `cut`
    there into the part each section carries. Its sag, lumps, lean, turn and shade come from its own random stream,
    seeded by its place in the bond, so it is the same bag in every model that has it."""

    def __init__(self, seed: int, a0: float, a1: float, mid: float, zb: float, w: float, h: float,
                 header: bool = False, cut: bool = False, ties: tuple = (False, False), face: float = 1.0,
                 pressed: tuple = (False, False)):
        rng = random.Random(seed)
        self.a0, self.a1, self.mid, self.zb, self.w, self.h = a0, a1, mid, zb, w, h
        self.header, self.cut, self.ties, self.face, self.pressed = header, cut, ties, face, pressed
        self.sag = h * rng.uniform(0.03, 0.07)
        # a bag that is cut, or ends at the section's end, lies square, so it ends flush there
        yaw = rng.uniform(-0.03, 0.03)
        self.yaw = 0.0 if cut or abs(abs(a0) - HL) < 1e-6 or abs(abs(a1) - HL) < 1e-6 else yaw
        self.lean = rng.uniform(-0.03, 0.03)
        self.phase = (rng.random(), rng.random(), rng.random())
        self.paint = rk.tint("hessian" if rng.random() > 0.35 else "hessian_dark", rng.uniform(0.94, 1.05))
        self.tie_turn = (rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4))
        self.tie_rng = random.Random(seed + 1)

    def stations(self) -> list:
        """(along from a0, across scale, up scale, sag scale, seam drawn in, its end: -1 a0, 1 a1, 0 the belly)."""
        n = abs(self.a1 - self.a0)
        ends = [PRESSED if p else END for p in self.pressed]
        st = [s + (-1,) for s in ends[0]]
        if not self.cut:
            st.append((n * 0.5, 1.0, 1.0, 1.0, 0.0, 0))
        else:
            t = HL - self.a0
            st += [(t - 0.05, 1.0, 1.0, 1.0, 0.0, 0), (t, 1.0, 1.0, 1.0, 0.0, 0), (t + 0.05, 1.0, 1.0, 1.0, 0.0, 0)]
        return st + [(n - s[0],) + s[1:4] + (s[4], 1) for s in reversed(ends[1])]

    def rings(self) -> tuple:
        """The bag's rings, 3D, from its a0 end, and the index of the ring at its cut (or None)."""
        n = abs(self.a1 - self.a0)
        sense = 1.0 if self.a1 >= self.a0 else -1.0
        tcut = HL - self.a0 if self.cut else None
        p1, p2, p3 = self.phase
        zc = CENTRE * self.h
        out, cut_i = [], None
        for i, (t, kw, kh, ks, recess, end) in enumerate(self.stations()):
            ring = _ring(self.w, self.h, kw, kh, self.sag * ks)
            u = t / n
            # the lumps fade out at the seams and, on a cut bag, at its cut (where both parts must meet alike)
            fade = min(1.0, t / 0.06, (n - t) / 0.06)
            if tcut is not None:
                fade = min(fade, abs(t - tcut) / 0.08)
                if abs(t - tcut) < 1e-9:
                    cut_i = i
            crease = CREASE * max(0.0, 1.0 - min(t, n - t) / 0.14)
            pts = []
            for j, (y, z) in enumerate(ring):
                a = (ARC + [UNDER])[j]
                if j not in FOOT:
                    f = 0.6 * math.sin(math.tau * (1.5 * u + p1) + 2.0 * a) + \
                        0.4 * math.sin(math.tau * (2.5 * u + p2) - 3.0 * a)
                    d = LUMP * fade * f + crease * math.sin(3.0 * a + math.tau * p3 + (0.0 if end < 0 else 1.7))
                    r = math.hypot(y, z - zc)
                    k = 1.0 + d / max(r, 1e-6)
                    y, z = y * k, zc + (z - zc) * k
                # the seam's middle drawn in, its corners (the ears, at 0 and 180 degrees) standing out furthest
                along = t - end * recess * (1.0 - abs(math.cos(a)) ** 3)
                pts.append(self.place(self.a0 + along * sense, y, z))
            out.append(pts)
        return out, cut_i

    def place(self, a: float, side: float, z: float) -> tuple:
        """A point `a` along the bag's line, `side` across it, `z` over its foot, turned `yaw` about its middle and
        leaning `lean` (its crown towards one face)."""
        mid_a = (self.a0 + self.a1) * 0.5
        d = a - mid_a
        side += self.lean * z
        dx = d * math.cos(self.yaw) - side * math.sin(self.yaw)
        dy = d * math.sin(self.yaw) + side * math.cos(self.yaw)
        z += self.zb
        return (self.mid + dy, mid_a + dx, z) if self.header else (mid_a + dx, self.mid + dy, z)

    def crown(self) -> float:
        return self.zb + self.h


def _tie(kit: rk.Kit, bag: Bag, ring: list, end: int) -> None:
    """A tied corner: the ear on the wall's face gathered to a tail, bound with cord, its frayed end drooping (photo
    5). `ring` is the bag's end ring as built, `end` -1 its a0 end, 1 its a1."""
    from mathutils import Vector
    rng = bag.tie_rng
    ear = Vector(ring[ARC.index(0.0) if bag.face > 0 else ARC.index(math.pi)])
    sense = 1.0 if bag.a1 >= bag.a0 else -1.0
    along = Vector((0.0, sense * end, 0.0) if bag.header else (sense * end, 0.0, 0.0))
    side = Vector((bag.face, 0.0, 0.0) if bag.header else (0.0, bag.face, 0.0))
    turn = bag.tie_turn[0 if end < 0 else 1]
    # out of the face and a little along it, drooping; a header's tail points out of the face, along the bag
    d = along * 0.85 + side * 0.25 if bag.header else along * (0.35 + turn * 0.3) + side * 0.8
    d = (d + Vector((0.0, 0.0, -0.35))).normalized()
    u = d.cross(Vector((0.0, 0.0, 1.0))).normalized()
    v = u.cross(d).normalized()
    rings = []
    for off, r, fray in ((-0.012, 0.017, 0.0), (0.004, 0.0185, 0.0), (0.013, 0.0185, 0.0), (0.02, 0.011, 0.0),
                         (0.045, 0.019, 0.3)):
        c = ear + d * off
        pts = []
        for i in range(6):
            ang = math.tau * i / 6 + rng.uniform(-0.15, 0.15)
            rr = r * (1.0 - fray * (i % 2)) * rng.uniform(0.92, 1.08)
            pts.append(tuple(c + (u * math.cos(ang) + v * math.sin(ang)) * rr))
        rings.append(pts)
    kit.loft(rings[:2], bag.paint, cap0=False, cap1=False)
    kit.loft(rings[1:3], "tie", cap0=False, cap1=False)
    kit.loft(rings[2:], "hessian_dark", cap0=False, cap1=False)
    kit.fan(rings[-1], tuple(d), "hessian_dark", apex=tuple(d * 0.012 + Vector((0.0, 0.0, -0.006))))


def _facing(first: list, second: list) -> tuple:
    a = [sum(p[i] for p in first) / len(first) for i in range(3)]
    b = [sum(p[i] for p in second) / len(second) for i in range(3)]
    return tuple(a[i] - b[i] for i in range(3))


def _part(kit: rk.Kit, bag: Bag, rings: list, end: int, shift: float) -> None:
    """Builds `rings` (a bag, or the part of a cut bag a section carries) moved `shift` along x, its `end` (-1 the a0
    end, the first ring; 1 the a1 end, the last; 0 both, a whole bag) the bag's own, its other end the cut, closed flat
    there too (inside the next section's part of the bag, never seen, but no section is open)."""
    rs = [[(p[0] + shift, p[1], p[2]) for p in r] for r in rings]
    kit.loft(rs, bag.paint, cap0=False, cap1=False)
    for e, i, j in ((-1, 0, 1), (1, -1, -2)):
        kit.fan(rs[i], _facing(rs[i], rs[j]), bag.paint)
        if end in (0, e) and bag.ties[0 if e < 0 else 1]:
            _tie(kit, bag, rs[i], e)


def bags(closes: int) -> list:
    """Every bag of a section, as (course, bag). `closes` -1 or 1: the section ends a wall at that end, a header there
    in each course that runs on; 0: it runs on both ways."""
    plan = random.Random(23)
    out = []
    below = []  # (x0, x1, row, crown) of the course under, its bags repeated a section either way (the bond runs on)
    for c in range(COURSES):
        course = []
        top = (c + 1) * PITCH
        last = c == COURSES - 1
        runs_on = c % 2 == 1
        for ri, row in enumerate((-ROW, ROW)):
            if not runs_on:
                j = plan.uniform(-JOINT, JOINT) + (0.03 if ri else -0.03)
                spans = [(-HL, j + OVERLAP * 0.5, False), (HL, j - OVERLAP * 0.5, False)]
            else:
                a, b = plan.uniform(*STRADDLE), plan.uniform(*STRADDLE)
                # the bag over the +x end, HL - a in this section to HL + b in the next (whose -x end carries it from
                # -HL to -HL + b), and the middle bag between, pressed into both
                spans = [(HL - a - OVERLAP * 0.5, HL + b + OVERLAP * 0.5, True),
                         (-HL + b - OVERLAP * 0.5, HL - a + OVERLAP * 0.5, False)]
            for si, (a0, a1, cut) in enumerate(spans):
                seed = 1000 + c * 100 + ri * 10 + si
                rng = random.Random(seed + 7)
                lo, hi = min(a0, a1), max(a0, a1)
                zb = 0.0
                if c > 0:
                    zb = min(cr for x0, x1, r_, cr in below if r_ == ri and x1 > lo + 0.05 and x0 < hi - 0.05) - \
                        rng.uniform(*BED)
                # the top course's middle bags are the wall's highest, in every model alike; the rest stand a little
                # under or over their course's line, so the bed joints wander
                if last:
                    h = top - (rng.uniform(0.012, 0.03) if cut else rng.uniform(0.0, 0.006)) - zb
                else:
                    h = top + rng.uniform(-0.02, 0.012) - zb
                # tied corners only on ends inside the section, never at its ends, where the next bag is
                ties = tuple(abs(abs(e) - HL) > 0.01 and rng.random() < TIE for e in (a0, a1))
                # an end at a section's end is pressed against the next section's bag, unless it ends the wall
                pressed = tuple(abs(abs(e) - HL) < 1e-6 and closes * e <= 0.0 for e in (a0, a1))
                course.append(Bag(seed, a0, a1, row, zb, HALF_W * rng.uniform(0.97, 1.03), h, cut=cut,
                                  ties=ties, face=-1.0 if row < 0 else 1.0, pressed=pressed))
        if runs_on and closes:
            sx = closes
            seed = 5000 + c
            rng = random.Random(seed + 7)
            x_in = sx * (HL - 2.0 * HEADER_HW)
            zb = min(cr for x0, x1, r_, cr in below if x1 > min(x_in, sx * HL) and x0 < max(x_in, sx * HL)) - \
                rng.uniform(*BED)
            h = top - rng.uniform(0.012, 0.03) - zb
            course.append(Bag(seed, -sx * (DEEP * 0.5 - 0.012), sx * (DEEP * 0.5 - 0.012),
                              sx * (HL - HEADER_HW * END[0][1] - 0.002), zb, HEADER_HW, h, header=True, ties=(True, c == 1),
                              face=sx))
        below = []
        for b in course:
            out.append((c, b))
            if b.header:
                below += [(b.mid - b.w, b.mid + b.w, r_, b.crown()) for r_ in (0, 1)]
                continue
            lo, hi = min(b.a0, b.a1), max(b.a0, b.a1)
            ri = 0 if b.mid < 0 else 1
            below += [(lo + s, hi + s, ri, b.crown()) for s in (-LONG, 0.0, LONG)]
    return out


def section(name: str, closes: int) -> object:
    """One model: the section's bags in its own place; at the end it `closes`, a header instead of the part of the
    running-on bag that would lie there."""
    k = rk.Kit(name)
    for c, b in bags(closes):
        if not b.cut:
            _part(k, b, b.rings()[0], 0, 0.0)
            continue
        rings, i = b.rings()
        if closes <= 0:
            _part(k, b, rings[:i + 1], -1, 0.0)  # its a0 part, by this section's +x end
        if closes >= 0:
            _part(k, b, rings[i:], 1, -LONG)  # its a1 part, the next section's, carried here at the -x end
    ob = k.build()
    ob.name = name
    return ob


def _soil_and_sun(ob: object) -> None:
    """The lowest course's sacking a little darker towards the ground, where rain splashes it (SOIL m up), and the
    bags' tops a little paler, where the sun bleaches them."""
    me = ob.data
    col = me.color_attributes["Color"]
    for p in me.polygons:
        up = max(0.0, p.normal.z)
        for li in p.loop_indices:
            z = me.vertices[me.loops[li].vertex_index].co.z
            k = 1.0 + 0.07 * up * up
            if z < SOIL:
                k *= 0.8 + 0.2 * z / SOIL
            c = col.data[li].color
            col.data[li].color = (min(1.0, c[0] * k), min(1.0, c[1] * k), min(1.0, c[2] * k), 1.0)


def _seam(ob: object) -> dict:
    """The corners of the cut bags' rings at the section's two ends, keyed by (end, y, z)."""
    me = ob.data
    out = {}
    for p in me.polygons:
        if abs(p.normal.x) > 0.9:
            continue  # a seam's own face
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if abs(abs(co.x) - HL) < 1e-5:
                out.setdefault((1 if co.x > 0 else -1, round(co.y, 4), round(co.z, 4)), []).append(li)
    return out


def _match_seams(main: object, others: list) -> None:
    """Gives each cut bag's corners at the main section's two ends one colour, the mean of the two sides' bakes (the
    same ring of the same bag, seen from each section), and the end models' running-on ends the same, so no line of
    shade shows where two sections meet."""
    col = main.data.color_attributes["Color"]
    seam = _seam(main)
    mean = {}
    for (side, y, z), loops in seam.items():
        if side < 0 or (-1, y, z) not in seam:
            continue
        both = loops + seam[(-1, y, z)]
        c = tuple(sum(col.data[li].color[i] for li in both) / len(both) for i in range(3))
        mean[(y, z)] = c
        for li in both:
            col.data[li].color = c + (1.0,)
    for ob, side in others:
        cm = ob.data.color_attributes["Color"]
        for (s, y, z), loops in _seam(ob).items():
            if s == side and (y, z) in mean:
                for li in loops:
                    cm.data[li].color = mean[(y, z)] + (1.0,)


def build_all() -> dict:
    import bpy
    obs = {name: section(name, closes) for name, closes in MODELS}
    main = obs["sandbags"]
    zmax = max(v.co.z for v in main.data.vertices)
    lo, hi = (-HL, -DEEP * 0.5, 0.0), (HL, DEEP * 0.5, HIGH)
    for name, _ in MODELS:
        ob = obs[name]
        rk.finish(ob, angle=math.radians(70.0))
        for v in ob.data.vertices:
            v.co.z *= HIGH / zmax
        rk.clamp_to(ob, lo, hi)
        rk.bake(ob, jitter={}, seed=7, islands=False)
        _soil_and_sun(ob)
    for name, closes in MODELS:
        # each baked alone (the other models moved out of the way), its neighbours in a wall beside it
        for other in obs.values():
            other.location.z = 0.0 if other is obs[name] else 1000.0
        bpy.context.view_layer.update()
        beside = [(-closes * LONG,)] if closes else [(LONG,), (-LONG,)]
        rk.occlude(obs[name], strength=0.6, distance=0.15, neighbours=[(main, (o[0], 0.0, 0.0)) for o in beside])
    for ob in obs.values():
        ob.location.z = 0.0
    bpy.context.view_layer.update()
    _match_seams(main, [(obs["sandbags_start"], 1), (obs["sandbags_end"], -1)])
    for name, _ in MODELS:
        rk.fit_box(obs[name], lo, hi)
    return obs


def main() -> None:
    rk.reset()
    obs = build_all()
    for name, _ in MODELS:
        n = rk.report([obs[name]])
        if n > BUDGET:
            raise SystemExit("%s over budget" % name)
        rk.export(os.path.join(rk.PROPS, name + ".glb"), [obs[name]])
        print("wrote", name)
    if "--render" in sys.argv:
        _render(obs, sys.argv[sys.argv.index("--render") + 1])


def _render(obs: dict, out: str) -> None:
    import bpy
    from mathutils import Matrix
    for ob in obs.values():
        ob.hide_render = True

    def lay(name: str, m: object) -> None:
        c = obs[name].copy()
        bpy.context.scene.collection.objects.link(c)
        c.matrix_world = m
        c.hide_render = False

    # A wall six sections long, two deep, as PropLayout lays the backstop: all one way round, its ends closed.
    for i in range(6):
        name = "sandbags_start" if i == 0 else "sandbags_end" if i == 5 else "sandbags"
        for j in (0, 1):
            lay(name, Matrix.Translation((i * LONG, j * DEEP, 0.0)))
    # The firing point's low wall: two sections squeezed to 0.4 m, its ends closed.
    for i, name in enumerate(("sandbags_start", "sandbags_end")):
        lay(name, Matrix.Translation((1.2 + i * LONG, -2.6, 0.0)) @ Matrix.Diagonal((1.0, 0.4 / DEEP, 1.0, 1.0)))
    import range_render as rr
    rr.render_sheet([
        ("Backstop line: 6 sections, 2 deep (7.2 x 1.2 m)", (3.0, -6.0, 1.8), (3.0, 0.3, 0.45), 30),
        ("Down the line", (8.2, -1.2, 1.1), (0.0, 0.3, 0.4), 30),
        ("Bags close-up: ears, tied corners", (2.0, -1.2, 0.9), (1.6, 0.0, 0.45), 40),
        ("Firing point's low wall (2.4 x 0.4 m)", (1.0, -4.5, 1.2), (1.8, -2.6, 0.45), 35),
        ("Top of the line", (2.6, -1.0, 2.0), (2.4, 0.6, 0.8), 35),
        ("Line's end: headers across it", (-1.6, -0.7, 0.45), (0.0, 0.6, 0.4), 35),
    ], out, "Sandbag wall (Range map prop, rebuilt): sections that lock into each other, the wall's ends closed",
        roughness=0.97)


if __name__ == "__main__":
    main()
