"""The range's sandbag wall (RM1, rebuilt RM2): 1.2 m sections of filled hessian sacks, four courses two bags deep,
that lock into each other along a wall as a real wall's courses do. Built against William's photos
(art/references/maps/william-2026-11-09/sand_bag_wall): the real wall's close-up (photo 4) and the two stacks (photos
3 and 5).

Each bag is a sack filled and laid flat: a pillow, full in its belly and thinning to its ends, each end sewn or folded
flat to a seam whose corners stand out as ears (photo 4: an end about 0.6 of the belly high, two bags end to end
meeting in a V), a tied corner here and there gathered to a tail bound with cord (photo 5), the sacking lumped and
creased towards its ends. A bag is 2.6 to 3.2 times as long as it stands on the face (photo 4: 3.1); its length, its
height, how deep it sits in the course below, how it falls along its length and how it leans are its own, so the
bed joints wander as the photo's do.

The bond: every course's joints lie inside a section, a row's half a bag over the course under it and the two rows a
quarter of a bag apart (so no light finds a way through); each course's bag over the section's +x end runs on into
the next section, which carries the rest of it at its -x end (cut flush at the section's ends, the cut never seen).
So no joint runs straight up a wall and nothing ends flat at a section's end. Three sections (sandbags.glb, _b, _c)
share those bags and differ in their own, and the game lays them at random (PropDressConfig.variants), so a wall
never repeats every 1.2 m. PropLayout lays the sections all one way round (PropDressConfig.grid_unturned) and closes
each wall with its end models (PropDressConfig.grid_ends): sandbags_start.glb at the wall's -x end and
sandbags_end.glb at its +x end, a bag laid across the wall in every other course there (a header, its ends on the
faces, 0.34 m wide: 1.5 times a course), as a real wall's ends are built.

The creases are baked in (Cycles' ambient occlusion, range_kit.occlude, with the next sections beside it so the joins
shade alike), the bags' tops paler where the sun bleaches them, their feet darker where rain splashes soil up; the
game draws the sacking matte (PropDressConfig.model_roughness). Each bag keeps one shade of its own (range_kit.tint),
so the two parts of a bag split between sections match.

Writes assets/models/props/sandbags.glb, sandbags_b.glb, sandbags_c.glb, sandbags_start.glb, sandbags_end.glb and
sandbags_single.glb (a wall one section long, closed at both ends), each one vertex-coloured mesh filling x -0.6..0.6, y -0.3..0.3, z 0..0.9 exactly (Godot: x along, y up, z across).

Usage: python3 tools/blender/maps/sand_bag_wall.py [--render <sheet.jpg>]
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import range_kit as rk  # noqa: E402

# (name, the end it closes: -x, none, +x): three sections that take turns along a wall (PropDressConfig.variants),
# their own bags between the bags they share at their ends, and the wall's two end models
MODELS = (("sandbags", 0), ("sandbags_b", 0), ("sandbags_c", 0), ("sandbags_start", -1), ("sandbags_end", 1),
          ("sandbags_single", 2))  # (2: both ends, a wall one section long)
BUDGET = 5000  # docs/CC0_ASSETS.md › Size limits: a prop; about 95 % of it (RM2)
LONG, DEEP, HIGH = 1.2, 0.6, 0.9
HL = LONG * 0.5
COURSES = 4  # 0.225 m a course: a 0.6 m bag 2.67 times as long as it stands (photo 4: 2.7 to 3.1, photo 5: 3.0)
PITCH = HIGH / COURSES
BED = (0.02, 0.04)  # m each bag sits down into the crowns of the bags under it
CROWN = (-0.045, 0.04)  # m a bag's crown stands under or over its course's line, so the bed joints wander
TILT = 0.08  # how far a bag's line may fall along it, m a metre: one end down, one up (photo 4)
ROLL = 0.05  # how far it may lean, m across a metre up: its crown towards one face
ROW = 0.137  # the two rows' middles, m either side of the wall's middle
HALF_W = 0.145  # a stretcher's half width: the rows' bellies pressed together, their faces 0.282 out (its ears,
# creased, 0.298)
HEADER_HW = 0.17  # a header's half width along the wall: 0.34 wide, 1.5 times a course
OVERLAP = 0.03  # m bags end to end in a course run into each other, their eared ends pressed together in a V
# The joints of a course in a section (m from its middle), by (the course's parity, row): every course's bags run on
# over both of the section's ends, so no joint lies at a section's end; a row's joints half a bag over the course
# under them, and the two rows' a quarter of a bag apart, so no light finds a way through the wall.
JOINTS = {(0, 0): (-0.375, 0.225), (1, 0): (-0.075, 0.525), (0, 1): (-0.225, 0.375), (1, 1): (-0.525, 0.075)}
JOINT = 0.1  # m each joint may wander either way: this bond's bags run 0.49 to 0.74 m (photo 4: stubby to long)
# how far apart (m) joints must stay: two rows' in a course, a row's in the courses over and under it, the other
# row's there, and any joint from a section's end
APART = {"rows": 0.08, "courses": 0.12, "across": 0.06, "end": 0.04}
SMOOTH = 100.0  # degrees: faces meeting at less than this are drawn smooth, a seam's flat end too
MIN_BAG = 0.2  # m: a closing bag shorter than this joins the bag beside it instead
HEADED = 0  # the parity of the courses a wall's end lays a header across, its ends on the wall's faces
# Points round a bag, (across, up) from its widest line: 13 on its sides and crown, 0 and 180 degrees its widest (the
# ears' corners); its foot, flat where it sits, is the chord between the first and the last.
ARC = [math.radians(a) for a in (-55, -25, 0, 25, 50, 70, 90, 110, 130, 155, 180, 205, 235)]
ROUND_PTS = 20
# A bag seen end on (a header, or one closing the wall's end: `Bag.end_on`) shows its round as its outline, so it
# has 20 points over its crown, from one ear to the other (sixth pass: 9 drew corners against the sky at 1 m).
ARC_ROUND = [math.radians(a) for a in [-40.0] + [180.0 * k / (ROUND_PTS - 1) for k in range(ROUND_PTS)] + [220.0]]
SIDE_ROUND = 2.3  # the belly's squareness (2 an ellipse): full shoulders, a soft crown
FOOT_ROUND = 4.0  # flatter underneath: it spreads where it sits
CENTRE = (0.36, 0.43)  # its widest line, a share of its height up: lower where the fill has slumped
# Along a bag from an end (m): (along, across scale, up scale, crown sag scale, the seam's middle drawn in): the end's
# flat seam (0.6 of the belly high, its corners standing out as ears), then the bag filling out to its belly; two
# bags pressed end to end meet about 0.68 of their bellies high, a V between them (photo 4).
END = ((0.0, 1.04, 0.32, 0.0, 0.026), (0.02, 1.01, 0.5, 0.15, 0.012), (0.06, 0.995, 0.72, 0.45, 0.0),
       (0.14, 1.0, 0.92, 0.8, 0.0))
# An end pressed full against a header's side, so no light shows between them.
PRESSED = ((0.0, 0.94, 0.8, 0.2, 0.0), (0.015, 0.975, 0.9, 0.45, 0.0), (0.05, 0.995, 0.96, 0.7, 0.0),
           (0.14, 1.0, 0.985, 0.9, 0.0))
# A bag seen end on pays for its 20-point crown with fewer stations along it: its ends' four in three, and no belly
# station on a bag too short to need one.
END_ROUND = (END[0], (0.04, 1.0, 0.62, 0.3, 0.004), END[3])
PRESSED_ROUND = (PRESSED[0], (0.03, 0.985, 0.93, 0.58, 0.0), PRESSED[3])
# The end seen end on: a pillow's end, its rings each inside the next towards the belly, so its outline is the
# belly's round and no corner shows where a flat seam's ring would stand out past it.
ON_END = ((0.0, 0.93, 0.6, 0.2, 0.008), (0.04, 0.985, 0.84, 0.5, 0.0), (0.14, 1.0, 0.96, 0.85, 0.0))
BELLY_ROUND = 0.62  # m: such a bag shorter than this has no belly station (a header, most closing bags)
DOME = 0.04  # m an end seen end on bulges past its seam, at its middle
INTO_HEADER = 0.035  # m such an end runs into the header
LUMP = 0.008  # the sacking's lumps, m in or out
CREASE = 0.006  # its creases fanning in from the ears, m at the seam
SOIL = 0.12  # the splashed foot of the wall, m up
TIE = 0.6  # the share of a section's own bags' ends inside a wall that show a tied corner on the wall's face

rk.check_colours(["hessian", "hessian_dark", "tie"], shade=0.08)


def _pow(v: float, e: float) -> float:
    return math.copysign(abs(v) ** e, v)


def _ring(w: float, h: float, kw: float, kh: float, sag: float, centre: float, arc: list = ARC) -> list:
    """A bag's cross-section as (across, up) points from its foot: a loaf w either side and h tall, its widest line
    `centre` of it up, scaled kw across and kh up about that line (the lower half shrinks less, so a bag's ends stay
    down on the course below), its crown dipped `sag` m."""
    pts = []
    c = centre * h
    up, down = (h - c) * kh, c * min(1.0, kh + 0.5)
    for j, a in enumerate(arc):
        cs, sn = math.cos(a), math.sin(a)
        y = w * kw * _pow(cs, 2.0 / SIDE_ROUND)
        if sn >= 0.0:
            z = c + up * _pow(sn, 2.0 / SIDE_ROUND) - sag * sn ** 4
        elif j in (0, len(arc) - 1):
            z = c - down  # the foot's corners, down where it sits
        else:
            z = c + down * _pow(sn, 2.0 / FOOT_ROUND)
        pts.append((y, z))
    return pts


class Bag:
    """One bag from `a0` to `a1` along the wall (x), or across it (y) when a `header`, its middle line at `mid` the
    other way, `w` either side. A bag `cut` runs on over the section's +x end, each section carrying its part. Its
    shape, lumps, lean, tilt and shade come from its own random stream, seeded by its place in the bond, so a bag
    shared by two sections is the same bag in both; `rest` then sets its foot and height."""

    def __init__(self, seed: int, a0: float, a1: float, mid: float, w: float, header: bool = False,
                 cut: bool = False, face: float = 1.0, tilt: bool = True, pressed: tuple = (False, False)):
        rng = random.Random(seed)
        self.rng = rng
        self.a0, self.a1, self.mid, self.w = a0, a1, mid, w
        self.header, self.cut, self.face, self.pressed = header, cut, face, pressed
        self.zb, self.h = 0.0, PITCH
        self.sag_k = rng.uniform(0.04, 0.08)
        self.centre = rng.uniform(*CENTRE)
        # a bag that is cut, or ends at the section's end, lies square, so it ends flush there
        ends_flush = cut or any(abs(abs(e) - HL) < 1e-6 for e in (a0, a1))
        self.yaw = 0.0 if ends_flush else rng.uniform(-0.03, 0.03)
        self.lean = rng.uniform(-ROLL, ROLL)
        self.tilt = rng.uniform(-TILT, TILT) if tilt and not header else 0.0
        self.phase = (rng.random(), rng.random(), rng.random())
        self.paint = rk.tint("hessian" if rng.random() > 0.35 else "hessian_dark", rng.uniform(0.93, 1.06))
        self.tie_turn = (rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4))
        # tied corners only on a section's own bags (so they differ from section to section, never repeating every
        # section's length), on ends inside the wall, never at the wall's end or against a header
        self.ties = tuple(abs(abs(e) - HL) > 0.01 and rng.random() < TIE and not p and not cut
                          for e, p in zip((a0, a1), pressed)) if not header else (True, False)
        self.bed = rng.uniform(*BED)
        # its ends seen end on: a header's both, a bag's at the wall's end (drawn domed, `_dome`)
        self.end_on = tuple(header or abs(abs(e) - HL) < 1e-6 for e in (a0, a1))
        self.arc = ARC_ROUND if any(self.end_on) else ARC
        self.tie_rng = random.Random(seed + 1)

    def middle(self) -> float:
        return (self.a0 + self.a1) * 0.5

    def rest(self, zb: float, crown: float) -> None:
        """Sits the bag's foot at `zb` (its middle; it tilts about it) and fills it so its crown, sagged, is at
        `crown`."""
        self.zb = zb
        self.h = (crown - zb) / (1.0 - self.sag_k)

    def crown_at(self, x: float) -> float:
        """Its crown's height over the wall's x, where the bag is full."""
        return self.zb + self.h * (1.0 - self.sag_k) + self.tilt * (x - self.middle())

    def stations(self) -> list:
        """(along from a0, across scale, up scale, sag scale, seam drawn in, its end: -1 a0, 1 a1, 0 the belly); a
        cut bag has one more, where it is cut, the same in both parts."""
        n = abs(self.a1 - self.a0)
        lean = any(self.end_on)
        ends = [ON_END if on else (PRESSED_ROUND if lean else PRESSED) if p else (END_ROUND if lean else END)
                for p, on in zip(self.pressed, self.end_on)]
        belly = [(n * 0.5, 1.0, 1.0, 1.0, 0.0, 0)] if not lean or n > BELLY_ROUND else []
        st = [s + (-1,) for s in ends[0]] + belly + [(n - s[0],) + s[1:5] + (1,) for s in reversed(ends[1])]
        if self.cut:
            t = HL - self.a0
            st = [s for s in st if abs(s[0] - t) > 0.004]
            i = next(k for k, s in enumerate(st) if s[0] > t)
            p, q = st[i - 1], st[i]
            f = (t - p[0]) / (q[0] - p[0])
            st.insert(i, (t,) + tuple(p[k] + (q[k] - p[k]) * f for k in range(1, 5)) + (p[5] if f < 0.5 else q[5],))
        return st

    def rings(self) -> tuple:
        """The bag's rings, 3D, from its a0 end, and the index of the ring at its cut (or None)."""
        n = abs(self.a1 - self.a0)
        sense = 1.0 if self.a1 >= self.a0 else -1.0
        tcut = HL - self.a0 if self.cut else None
        p1, p2, p3 = self.phase
        zc = self.centre * self.h
        out, cut_i = [], None
        for i, (t, kw, kh, ks, recess, end) in enumerate(self.stations()):
            ring = _ring(self.w, self.h, kw, kh, self.h * self.sag_k * ks, self.centre, self.arc)
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
                a = self.arc[j]
                if j not in (0, len(ring) - 1):
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
        """A point `a` along the bag's line, `side` across it, `z` over its foot, turned `yaw` about its middle,
        leaning `lean` (its crown towards one face) and tilted `tilt` along it."""
        mid_a = self.middle()
        d = a - mid_a
        side += self.lean * z
        dx = d * math.cos(self.yaw) - side * math.sin(self.yaw)
        dy = d * math.sin(self.yaw) + side * math.cos(self.yaw)
        z += self.zb + self.tilt * d
        return (self.mid + dy, mid_a + dx, z) if self.header else (mid_a + dx, self.mid + dy, z)


def _tie(kit: rk.Kit, bag: Bag, ring: list, end: int) -> None:
    """A tied corner: the ear on the wall's face gathered to a tail, bound with cord, its frayed end drooping (photo
    5). `ring` is the bag's end ring as built, `end` -1 its a0 end, 1 its a1."""
    from mathutils import Vector
    rng = bag.tie_rng
    ear = Vector(ring[min(range(len(bag.arc)), key=lambda j: abs(bag.arc[j] - (0.0 if bag.face > 0 else math.pi)))])
    sense = 1.0 if bag.a1 >= bag.a0 else -1.0
    along = Vector((0.0, sense * end, 0.0) if bag.header else (sense * end, 0.0, 0.0))
    side = Vector((bag.face, 0.0, 0.0) if bag.header else (0.0, bag.face, 0.0))
    turn = bag.tie_turn[0 if end < 0 else 1]
    # along the face, a little out of it, drooping (kept in the box: see below); a header's along the bag
    d = along * 0.85 + side * 0.12 if bag.header else along * (0.8 + turn * 0.3) + side * 0.25
    d = (d + Vector((0.0, 0.0, -0.4))).normalized()
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
    # kept inside the model's box (a tail past it would be pressed flat against it there, and shade black): moved
    # back off the face, and off the wall's end, by what runs past
    for axis, half in ((1, DEEP * 0.5), (0, HL)):
        over = max(abs(p[axis]) for r in rings for p in r) - (half - 0.003)
        if over > 0.0:
            k = max((p for r in rings for p in r), key=lambda p: abs(p[axis]))
            shift = -math.copysign(over, k[axis])
            rings = [[tuple(q + (shift if i == axis else 0.0) for i, q in enumerate(p)) for p in r] for r in rings]
    _outward(kit, kit.loft(rings[:2], bag.paint, cap0=False, cap1=False), rings[:2])
    _outward(kit, kit.loft(rings[1:3], "tie", cap0=False, cap1=False), rings[1:3])
    _outward(kit, kit.loft(rings[2:], "hessian_dark", cap0=False, cap1=False), rings[2:])
    kit.fan(rings[-1], tuple(d), "hessian_dark", apex=tuple(d * 0.012 + Vector((0.0, 0.0, -0.006))))


def _outward(kit: rk.Kit, faces: list, rings: list) -> None:
    """Turns a tube's faces (an open loft, whose own normals can come out either way) to face out of it: each away
    from the middle of the rings it runs between."""
    import bmesh
    from mathutils import Vector
    mids = [sum((Vector(p) for p in r), Vector()) / len(r) for r in rings]
    n = len(rings[0])
    flip = []
    for k, f in enumerate(faces):
        seg = min(k // n, len(mids) - 2)
        f.normal_update()
        if f.normal.dot(f.calc_center_median() - (mids[seg] + mids[seg + 1]) * 0.5) < 0.0:
            flip.append(f)
    if flip:
        bmesh.ops.reverse_faces(kit.bm, faces=flip)


def _facing(first: list, second: list) -> tuple:
    a = [sum(p[i] for p in first) / len(first) for i in range(3)]
    b = [sum(p[i] for p in second) / len(second) for i in range(3)]
    return tuple(a[i] - b[i] for i in range(3))


def _part(kit: rk.Kit, bag: Bag, rings: list, end: int, shift: float) -> None:
    """Builds `rings` (a bag, or the part of a cut bag a section carries) moved `shift` along x, its `end` (-1 the a0
    end, the first ring; 1 the a1 end, the last; 0 both, a whole bag) the bag's own, its other end the cut, closed flat
    there too (inside the next section's part of the bag, never seen, but no section is open)."""
    rs = [[(p[0] + shift, p[1], p[2]) for p in r] for r in rings]
    _outward(kit, kit.loft(rs, bag.paint, cap0=False, cap1=False), rs)
    for e, i, j in ((-1, 0, 1), (1, -1, -2)):
        if end in (0, e) and bag.end_on[0 if e < 0 else 1]:
            _dome(kit, bag, rs[i], _facing(rs[i], rs[j]))
        else:
            kit.fan(rs[i], _facing(rs[i], rs[j]), bag.paint)
        if end in (0, e) and bag.ties[0 if e < 0 else 1]:
            _tie(kit, bag, rs[i], e)


def _dome(kit: rk.Kit, bag: Bag, ring: list, facing: tuple) -> None:
    """An end seen end on (a header's, or a bag's at the wall's end): its seam closed by a low dome to its middle,
    DOME out, drawn smooth, so it reads round, never a flat star."""
    from mathutils import Vector
    f = Vector(facing).normalized()
    kit.fan(ring, tuple(f), bag.paint, apex=tuple(f * DOME))


_JOINTS = {}


def _apart(a: float, b: float) -> float:
    d = abs(a - b) % LONG
    return min(d, LONG - d)


def _joints(c: int, ri: int) -> tuple:
    """Course `c`'s two joints in row `ri` of every section, each up to JOINT off its place in the bond, drawn
    together (one stream) until no two joints come nearer than APART says, so no light finds a way through."""
    if not _JOINTS:
        rng = random.Random(3000)
        for _ in range(20000):
            js = {k: tuple(j + rng.uniform(-JOINT, JOINT) for j in JOINTS[(k[0] % 2, k[1])])
                  for k in ((cc, rr) for cc in range(COURSES) for rr in (0, 1))}
            ok = all(_apart(j, HL) >= APART["end"] for v in js.values() for j in v)
            for (cc, rr), v in js.items():
                for (c2, r2), w in js.items():
                    if (c2, r2) <= (cc, rr) or abs(c2 - cc) > 1:
                        continue
                    need = APART["rows"] if c2 == cc else APART["courses"] if r2 == rr else APART["across"]
                    ok = ok and all(_apart(a, b) >= need for a in v for b in w)
            if ok:
                _JOINTS.update(js)
                break
        else:
            raise SystemExit("no bond found")
    return _JOINTS[(c, ri)]


def _closing(closes: int) -> tuple:
    """The ends (-1 its -x, 1 its +x) a model closes: 2 both."""
    return (-1, 1) if closes == 2 else (closes,) if closes else ()


def _spans(c: int, ri: int, closes: int) -> list:
    """Row `ri` of course `c` in a model closing the wall at `closes` (-1 its -x end, 1 its +x, 0 neither) as (a0,
    a1, the ends pressed against a header) spans of the model's own bags; the bag over the +x end that every section
    shares is laid apart (`plan`)."""
    j1, j2 = _joints(c, ri)
    ov = OVERLAP * 0.5
    lo, hi = j1 - ov, j2 + ov
    press = [False, False]
    out = []
    # the wall's end: a bag laid across it in a headed course, else this row's bags run on to the end, one more
    # short one, or the bag by it longer
    headed = c % 2 == HEADED
    edge = HL - 2.0 * HEADER_HW if headed else HL
    e = edge + INTO_HEADER if headed else edge
    for side in _closing(closes):
        j = -j1 if side < 0 else j2
        if edge - j >= MIN_BAG:
            out.append((-e, j1 + ov, (headed, False)) if side < 0 else (j2 - ov, e, (False, headed)))
        elif side < 0:
            lo, press[0] = -e, headed
        else:
            hi, press[1] = e, headed
    out.append((lo, hi, tuple(press)))
    return out


def _rest(bag: Bag, belows: list, rows: tuple, crown: float) -> None:
    """Sits `bag` down into the crowns under it, in `rows`, wherever both are full (every 3 cm along it): the lowest
    of `belows` (one list a model; a bag shared by several sits on the lowest of them all) less its bed, so it never
    stands off any of them."""
    if bag.header:
        xs = [bag.mid + bag.w * k for k in (-0.5, 0.0, 0.5)]
    else:
        lo, hi = min(bag.a0, bag.a1) + 0.08, max(bag.a0, bag.a1) - 0.08
        xs = [lo + (hi - lo) * i / max(1, round((hi - lo) / 0.03)) for i in range(round((hi - lo) / 0.03) + 1)]
    zb = None
    for below in belows:
        for x in xs:
            for b, r in below:
                if r in rows and min(b.a0, b.a1) + 0.08 <= x <= max(b.a0, b.a1) - 0.08:
                    z = b.crown_at(x) - bag.tilt * (x - bag.middle())
                    zb = z if zb is None else min(zb, z)
    bag.rest(0.0 if zb is None else zb - bag.bed, crown)


def _crown(bag: Bag, c: int, shared: bool) -> float:
    """Where `bag`'s crown stands in course `c`: about its course's line; on top, the bags every section shares stand
    a little over the top (the box flattens them to it, so every model is as high), the rest a little under it."""
    if c == COURSES - 1:
        if shared and not bag.header:
            return HIGH + 0.012
        return HIGH - bag.rng.uniform(0.0, 0.05) - abs(bag.tilt) * 0.35
    return (c + 1) * PITCH + bag.rng.uniform(*CROWN)


def plan() -> dict:
    """Every model's bags, as (course, bag, part: "whole", or the a0 or a1 part of a bag shared over a section's
    end), course by course: each model's own bags sit on its own courses; the shared ones, on the lowest of them."""
    own = {name: i for i, (name, _) in enumerate(MODELS)}
    out = {name: [] for name, _ in MODELS}
    below = {name: [] for name, _ in MODELS}  # (bag, row) under the next course, repeated a section either way
    for c in range(COURSES):
        last = c == COURSES - 1
        course = {name: [] for name, _ in MODELS}
        for ri, row in enumerate((-ROW, ROW)):
            j1, j2 = _joints(c, ri)
            ov = OVERLAP * 0.5
            seed = 1000 + c * 100 + ri * 10
            # (its belly a few millimetres past the wall's face, pressed flat there: every model has these bags, so
            # every model fills its box's depth exactly)
            shared = Bag(seed, j2 - ov, j1 + LONG + ov, row, DEEP * 0.5 - ROW + 0.003,
                         cut=True, face=-1.0 if row < 0 else 1.0, tilt=c > 0 and not last)
            # (on every section it may lie over: never the one-cell wall's, which shares none)
            _rest(shared, [below[name] for name, closes in MODELS if closes != 2], (ri,), _crown(shared, c, True))
            for name, closes in MODELS:
                if closes in (0, -1):
                    course[name].append((shared, "a0", ri))
                if closes in (0, 1):
                    course[name].append((shared, "a1", ri))
                spans = _spans(c, ri, closes)
                # (a one-cell wall shares no bags, so its longest top bag a row stands over the top in their place)
                reach = max(range(len(spans)), key=lambda i: spans[i][1] - spans[i][0]) \
                    if last and closes == 2 else -1
                for si, (a0, a1, pressed) in enumerate(spans):
                    s = 20000 + own[name] * 1000 + c * 100 + ri * 10 + si
                    bag = Bag(s, a0, a1, row, HALF_W * random.Random(s + 5).uniform(0.97, 1.03),
                              face=-1.0 if row < 0 else 1.0, tilt=c > 0 and si != reach, pressed=pressed)
                    _rest(bag, [below[name]], (ri,), _crown(bag, c, si == reach))
                    course[name].append((bag, "whole", ri))
        for name, closes in MODELS:
            for side in _closing(closes) if c % 2 == HEADED else ():
                s = 5000 + c * 10 + (side > 0)
                head = Bag(s, -side * (DEEP * 0.5 - 0.012), side * (DEEP * 0.5 - 0.012),
                           side * (HL - HEADER_HW * END[0][1] - 0.002), HEADER_HW, header=True, face=side)
                _rest(head, [below[name]], (0, 1), _crown(head, c, False))
                course[name].append((head, "whole", -1))
            below[name] = []
            seen = set()
            for bag, part, ri in course[name]:
                out[name].append((c, bag, part))
                if id(bag) in seen:
                    continue  # a shared bag is under the next course once, with its copies
                seen.add(id(bag))
                if bag.header:
                    below[name] += [(_moved(bag, 0.0), r) for r in (0, 1)]
                    continue
                below[name] += [(_moved(bag, s), ri) for s in (-LONG, 0.0, LONG)]
    return out


class _Under:
    """A bag under the next course, `shift` m along the wall (the same bag a section either way)."""

    def __init__(self, bag: Bag, shift: float):
        self.bag, self.shift = bag, shift
        if bag.header:
            self.a0, self.a1 = bag.mid - bag.w * 1.3 + shift, bag.mid + bag.w * 1.3 + shift
        else:
            self.a0, self.a1 = bag.a0 + shift, bag.a1 + shift

    def crown_at(self, x: float) -> float:
        b = self.bag
        if b.header:
            # a bag laid across: its top falls away round its two sides, so a bag over its side sits down on it
            f = min(1.0, abs(x - self.shift - b.mid) / b.w)
            return b.zb + b.h * (1.0 - b.sag_k) * (1.0 - 0.5 * (1.0 - math.sqrt(1.0 - f * f)))
        return b.crown_at(x - self.shift)


def _moved(bag: Bag, shift: float) -> _Under:
    return _Under(bag, shift)


_PLAN = {}


def section(name: str) -> object:
    """One model: its bags in their own places, the shared bags' parts by its two ends (or, at an end it closes, the
    wall's end instead)."""
    if not _PLAN:
        _PLAN.update(plan())
    k = rk.Kit(name)
    for _c, b, part in _PLAN[name]:
        if part == "whole":
            _part(k, b, b.rings()[0], 0, 0.0)
            continue
        rings, i = b.rings()
        if part == "a0":
            _part(k, b, rings[:i + 1], -1, 0.0)  # its a0 part, by this section's +x end
        else:
            _part(k, b, rings[i:], 1, -LONG)  # its a1 part, the next section's, carried here at the -x end
    ob = k.build()
    ob.name = name
    return ob


_SEAM_N = {}


def _whole_normals() -> dict:
    """The normals round each shared bag's cut, from the bag built whole and smoothed as the models are, keyed by
    (y, z): so the two parts two sections carry shade as one bag, no line where it is cut."""
    import bpy
    if not _SEAM_N:
        k = rk.Kit("whole")
        seen = set()
        for name, _ in MODELS:
            for _c, b, _p in _PLAN[name]:
                if b.cut and id(b) not in seen:
                    seen.add(id(b))
                    _part(k, b, b.rings()[0], 0, 0.0)
        ob = k.build()
        rk.finish(ob, angle=math.radians(SMOOTH))
        rk.clamp_to(ob, (-10.0, -DEEP * 0.5, 0.0), (10.0, DEEP * 0.5, HIGH))
        for v in ob.data.vertices:
            if abs(v.co.x - HL) < 1e-5:
                _SEAM_N[(round(v.co.y, 4), round(v.co.z, 4))] = v.normal.copy()
        bpy.data.objects.remove(ob)
    return _SEAM_N


def _seam_normals(ob: object) -> None:
    """Gives the corners of each shared bag's cut, at the section's two ends, the whole bag's normals there."""
    me = ob.data
    whole = _whole_normals()
    normals = [c.vector.copy() for c in me.corner_normals]
    for p in me.polygons:
        if abs(p.normal.x) > 0.9:
            continue  # the cut's own flat end, inside the next section's part
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if abs(abs(co.x) - HL) < 1e-5:
                n = whole.get((round(co.y, 4), round(co.z, 4)))
                if n is not None:
                    normals[li] = n
    me.normals_split_custom_set(normals)


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


def _match_seams(obs: dict) -> None:
    """Gives each shared bag's corners at the sections' ends one colour, the mean of every model's bakes of that ring
    (the same ring of the same bag, seen from each side), so no line of shade shows where two sections meet."""
    seams = {name: _seam(ob) for name, ob in obs.items()}
    rings = {}
    for name, closes in MODELS:
        for (side, y, z), loops in seams[name].items():
            if closes != 2 and side * closes <= 0:
                rings.setdefault((y, z), []).append((name, loops))
    for parts in rings.values():
        cols = [obs[name].data.color_attributes["Color"].data[li].color for name, loops in parts for li in loops]
        c = tuple(sum(col[i] for col in cols) / len(cols) for i in range(3)) + (1.0,)
        for name, loops in parts:
            col = obs[name].data.color_attributes["Color"]
            for li in loops:
                col.data[li].color = c


def build_all() -> dict:
    import bpy
    obs = {name: section(name) for name, _ in MODELS}
    lo, hi = (-HL, -DEEP * 0.5, 0.0), (HL, DEEP * 0.5, HIGH)
    for name, _ in MODELS:
        ob = obs[name]
        rk.finish(ob, angle=math.radians(SMOOTH))
        rk.clamp_to(ob, lo, hi)
        _seam_normals(ob)
        rk.bake(ob, jitter={}, seed=7, islands=False)
        _soil_and_sun(ob)
    main = obs["sandbags"]
    for name, closes in MODELS:
        # each baked alone (the other models moved out of the way), sections beside it as in a wall
        for other in obs.values():
            other.location.z = 0.0 if other is obs[name] else 1000.0
        bpy.context.view_layer.update()
        beside = [] if closes == 2 else [-closes * LONG] if closes else [LONG, -LONG]
        rk.occlude(obs[name], strength=0.6, distance=0.15, neighbours=[(main, (o, 0.0, 0.0)) for o in beside])
    for ob in obs.values():
        ob.location.z = 0.0
    bpy.context.view_layer.update()
    _match_seams(obs)
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
    mains = ("sandbags", "sandbags_c", "sandbags_b", "sandbags", "sandbags_c", "sandbags_b")
    for i in range(6):
        for j in (0, 1):
            name = "sandbags_start" if i == 0 else "sandbags_end" if i == 5 else mains[i - 1 + j]
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
