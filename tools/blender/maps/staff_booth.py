"""Subway's platform staff booths (SM4, model 27): a small prefabricated booth like the owner's photos
(art/references/maps/subway/27-staff-booth, the car-park attendant's booths): off-white sandwich panels between
aluminium corner posts on a dark steel base, a flat roof overhanging all round (an aluminium capping, a painted fascia
and a drip bead under it, a grey membrane on top), glazed in its upper half on the front and sides, a half-glazed door
at one side of the front, a lamp over the door, a through-wall air conditioner on one side (photo 3), a vent high on
the solid back. Abandoned: roller blinds part down behind grimy glass (the booth is solid cover, so nothing is seen
inside), dust and grime up from the platform, streaks down from the roof.

SQ1 (owner, 2026-11-21: finer detail): the walls were one box with frames drawn on it and striped blinds that read as
louvres; now each wall is its panels with dark seams between them, every window sits 35 mm back in its opening behind
an aluminium frame standing proud, on a sloped sill with a drip nose, the blinds are plain roller blinds with a
bottom bar over dark glass with a sheen, and the door is a real leaf in its frame (stiles and rails, glass, kick
plate, lever handle and lock, three hinges, a closer, a threshold). The air conditioner has its sleeve, angled fins
in a framed grille, knobs and brackets.

Its six blocks (data/maps/subway.json) are three sizes, so three models, each built at its block's size, all 2.6 m
high: `staff_booth` 2 m wide (its front) and 2.2 m deep, `staff_booth_mid` 1.6 x 2.2 m and `staff_booth_small`
1.6 x 1 m. Each faces -y (its door and windows), turned to the platform by its block's facing.

Writes assets/models/props/staff_booth*.glb, each one vertex-coloured mesh filling x -W/2..W/2, y -D/2..D/2,
z 0..2.6 exactly (Godot: x across, y up, z deep).

Usage: python3 -I tools/blender/maps/staff_booth.py [--render <sheet.jpg>]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET = 4300
HIGH = 2.6
SIZES = {"staff_booth": (2.0, 2.2), "staff_booth_mid": (1.6, 2.2), "staff_booth_small": (1.6, 1.0)}
OVER = 0.07          # the roof's overhang all round
PLINTH = 0.08        # the steel base's height
SILL = 1.05          # the windows' sill
HEAD = 2.25          # the windows' and the door's head
EAVE = 2.42          # the roof's underside
FR = 0.045           # a window frame's width
PT = 0.035           # a wall panel's thickness (the glass sits this far back)
POST = 0.06          # a corner post's side
SEAM = 0.004         # half a panel joint's width
DOOR_W = 0.78

# This script's own paints (sRGB), greys off the teams' hues; their names pick the shader's kind
# (surface_kinds.by_name): the dark behind the seams, the glass's sheen, the air conditioner's satin casing, the roof
# membrane, the base's steel, the door's ironmongery, a blank sign.
wk.PAINT.update({
    "seam_dark": 0x34343a,
    "glass_sheen": 0x4a5052,
    "cab_ac": 0xc8c6be,
    "roof_felt": 0x5e5c5a,
    "base_steel": 0x4c4c4a,
    "closer_grey": 0x6c6c6a,
    "lock_chrome": 0xb4b4b2,
    "hinge_steel": 0x8c8c8a,
    "sign_plate": 0x3a3a3c,
})


class Face:
    """One wall of the booth, its panels' outer face at `at` looking `out` (+1 or -1) along the axis across `along`
    ("x" or "y"): every piece is placed by (a along it, d out of the panels' face, z)."""

    def __init__(self, k: wk.Kit, along: str, at: float, out: float, half: float):
        self.k, self.along, self.at, self.out, self.half = k, along, at, out, half

    def p(self, a: float, d: float, z: float) -> tuple:
        c = self.at + self.out * d
        return (a, c, z) if self.along == "x" else (c, a, z)

    def box(self, a0: float, a1: float, d0: float, d1: float, z0: float, z1: float, mat: str, step: float = 0.0,
            skip: tuple = ()) -> None:
        p0, p1 = self.p(a0, d0, z0), self.p(a1, d1, z1)
        lo = tuple(min(p0[i], p1[i]) for i in range(3))
        hi = tuple(max(p0[i], p1[i]) for i in range(3))
        if step > 0.0:
            self.k.panel(lo, hi, mat, step=step, skip=skip)
        else:
            self.k.blk(lo, hi, mat)

    def back(self) -> str:
        """The lattice face of a panel that looks into the booth (left off)."""
        return ("-" if self.out > 0 else "+") + ("y" if self.along == "x" else "x")

    def quad(self, pts: list, d: float, mat: str) -> None:
        """A flat face at depth d through (a, z) points, its front looking out."""
        q = [self.p(a, d, z) for a, z in pts]
        n = (Vector(q[1]) - Vector(q[0])).cross(Vector(q[2]) - Vector(q[1]))
        want = Vector((0.0, self.out, 0.0)) if self.along == "x" else Vector((self.out, 0.0, 0.0))
        self.k.quad(q if n.dot(want) > 0 else list(reversed(q)), mat)

    def rect(self, a0: float, a1: float, z0: float, z1: float, d: float, mat: str) -> None:
        self.quad([(a0, z0), (a1, z0), (a1, z1), (a0, z1)], d, mat)

    def run(self, a0: float, a1: float, prof: list, mat: str) -> None:
        """A rail along the wall from a0 to a1, its section `prof` as (d, z)."""
        self.k.prism([(self.at + self.out * d, z) for d, z in prof], self.along, a0, a1, mat)

    def slab(self, a0: float, a1: float, z0: float, z1: float, d0: float, d1: float, edge: float, mat: str) -> None:
        """A plate from depth d0 (behind) out to its face at d1, its face's edges rounded back by `edge`."""
        def ring(d: float, i: float) -> list:
            return [self.p(a0 + i, d, z0 + i), self.p(a1 - i, d, z0 + i), self.p(a1 - i, d, z1 - i),
                    self.p(a0 + i, d, z1 - i)]
        self.k.loft([ring(d0, 0.0), ring(d1 - edge, 0.0), ring(d1, edge)], mat)

    def panels(self, openings: list, seams: list) -> None:
        """The wall's sandwich panels between its posts, round its openings ((a0, a1, z0, z1)), with a dark joint at
        each of `seams` and round every opening."""
        lo, hi = -self.half + POST, self.half - POST
        cuts = sorted({lo, hi} | {a for o in openings for a in o[:2]} | {s for s in seams if lo < s < hi})
        for c0, c1 in zip(cuts, cuts[1:]):
            over = [o for o in openings if o[0] <= c0 + 1e-6 and o[1] >= c1 - 1e-6]
            if over:
                spans = [(PLINTH, over[0][2]), (over[0][3], EAVE)]
            else:  # a solid column: its panels under and over the belt rail running round at the sill
                spans = [(PLINTH, SILL - FR), (SILL, EAVE)]
                self.slab(c0 - 0.001, c1 + 0.001, SILL - FR + 0.002, SILL - 0.002, -PT, 0.006, 0.003, "booth_frame")
            for z0, z1 in spans:
                if z1 - z0 < 0.02:
                    continue
                zb = z0 + (SEAM if z0 > PLINTH else 0.0)
                zt = z1 - (SEAM if z1 < EAVE else 0.0)
                self.box(c0 + SEAM, c1 - SEAM, -PT - 0.002, 0.0, zb, zt, "booth_white", step=0.16,
                         skip=("-z", "+z", self.back()))


def window(f: Face, a0: float, a1: float, z0: float, z1: float, panes: int, transom: bool, blind: float) -> None:
    """A window in the opening a0..a1, z0..z1: grimy glass at the back of the opening with a roller blind `blind`
    of the way down and a sheen below it, an aluminium frame standing proud round it and between its panes (a
    transom across a third down when `transom`), a sloped sill with a drip nose under it."""
    g = -PT + 0.001
    f.rect(a0, a1, z0, z1, g, "glass")
    zb = z1 - FR - (z1 - z0 - 2 * FR) * blind  # the blind's foot
    for i in range(panes):
        p0 = a0 + (a1 - a0) * i / panes + (FR if i == 0 else FR * 0.5)
        p1 = a0 + (a1 - a0) * (i + 1) / panes - (FR if i == panes - 1 else FR * 0.5)
        f.rect(p0, p1, zb, z1 - FR, g + 0.001, "blind")
        f.rect(p0, p1, zb - 0.025, zb, g + 0.0015, "booth_frame")  # its bottom bar
        h = zb - 0.06 - (z0 + FR + 0.03)
        if h > 0.12 and p1 - p0 > 0.25:  # a sheen across the dark glass under it
            s = min(0.5 * h, p1 - p0 - 0.2)
            b0 = p0 + 0.05
            f.quad([(b0, z0 + FR + 0.03), (b0 + 0.09, z0 + FR + 0.03), (b0 + 0.09 + s, zb - 0.06), (b0 + s, zb - 0.06)],
                   g + 0.001, "glass_sheen")
    f.slab(a0, a1, z0, z0 + FR, -PT, 0.008, 0.003, "booth_frame")
    f.slab(a0, a1, z1 - FR, z1, -PT, 0.008, 0.003, "booth_frame")
    f.slab(a0, a0 + FR, z0 + FR - 0.002, z1 - FR + 0.002, -PT, 0.008, 0.003, "booth_frame")
    f.slab(a1 - FR, a1, z0 + FR - 0.002, z1 - FR + 0.002, -PT, 0.008, 0.003, "booth_frame")
    cuts = [a0 + FR] + [a0 + (a1 - a0) * i / panes for i in range(1, panes)] + [a1 - FR]
    for a in cuts[1:-1]:
        f.slab(a - FR * 0.5, a + FR * 0.5, z0 + FR - 0.002, z1 - FR + 0.002, -PT, 0.004, 0.003, "booth_frame")
    if transom:  # in lengths between the mullions
        zt = z1 - (z1 - z0) / 3.0
        for i, (c0, c1) in enumerate(zip(cuts, cuts[1:])):
            c0 += 0.0 if i == 0 else FR * 0.5
            c1 -= 0.0 if i == len(cuts) - 2 else FR * 0.5
            f.slab(c0 - 0.002, c1 + 0.002, zt - FR * 0.4, zt + FR * 0.4, -PT, 0.003, 0.003, "booth_frame")
    f.run(a0 - 0.03, a1 + 0.03, [(-0.002, z0 - 0.035), (0.04, z0 - 0.035), (0.048, z0 - 0.027), (0.048, z0 - 0.017),
                                 (-0.002, z0 + 0.003)], "booth_frame")


def door(f: Face, a0: float, a1: float) -> None:
    """The half-glazed door in the opening a0..a1 from the base to HEAD, hung at a1: its frame standing proud, a
    threshold, the leaf set back in it (aluminium stiles and rails, glass over a painted panel, a kick plate), three
    hinges, a lever handle and lock at a0, a closer on its head."""
    f.box(a0, a0 + FR, -PT, 0.012, PLINTH, HEAD, "booth_frame")
    f.box(a1 - FR, a1, -PT, 0.012, PLINTH, HEAD, "booth_frame")
    f.box(a0 + FR, a1 - FR, -PT, 0.012, HEAD - FR, HEAD, "booth_frame")
    f.run(a0 + FR, a1 - FR, [(-PT, PLINTH), (0.022, PLINTH), (0.022, PLINTH + 0.008), (0.0, PLINTH + 0.02),
                             (-PT, PLINTH + 0.02)], "steel_bare")
    l0, l1 = a0 + FR + 0.004, a1 - FR - 0.004   # the leaf
    z0, z1 = PLINTH + 0.024, HEAD - FR - 0.004
    st, mid = 0.06, 1.02
    f.box(l0, l1, -0.03, -0.014, z0, z1, "booth_white")             # its infill, under the glass and the panel
    f.box(l0, l0 + st, -0.03, -0.004, z0, z1, "booth_frame")         # stiles
    f.box(l1 - st, l1, -0.03, -0.004, z0, z1, "booth_frame")
    for r0, r1 in ((z0, z0 + 0.12), (mid, mid + 0.07), (z1 - st, z1)):  # rails
        f.box(l0 + st, l1 - st, -0.03, -0.004, r0, r1, "booth_frame")
    f.rect(l0 + st, l1 - st, mid + 0.07, z1 - st, -0.0135, "glass")
    zb = z1 - st - 0.45
    f.rect(l0 + st, l1 - st, zb, z1 - st, -0.013, "blind")
    f.rect(l0 + st, l1 - st, zb - 0.025, zb, -0.0125, "booth_frame")
    f.quad([(l0 + st + 0.06, mid + 0.12), (l0 + st + 0.14, mid + 0.12), (l0 + st + 0.32, zb - 0.06),
            (l0 + st + 0.24, zb - 0.06)], -0.013, "glass_sheen")
    f.slab(l0 + 0.01, l1 - 0.01, z0 + 0.01, z0 + 0.27, -0.006, -0.001, 0.0015, "steel_bare")  # the kick plate
    # hinges at a1: knuckles in the gap by the frame; the lever handle and the lock at a0
    for z in (0.3, 1.2, 2.0):
        x, y, _ = f.p(l1 + 0.002, 0.004, z)
        f.k.cyl((x, y, z), 0.009, 0.1, "hinge_steel", seg=6)
    hx = l0 + st * 0.5
    f.slab(hx - 0.018, hx + 0.018, 0.92, 1.16, -0.005, 0.0, 0.002, "lock_chrome")
    x, y, _ = f.p(hx, 0.0, 1.08)
    x2, y2, _ = f.p(hx, 0.045, 1.08)
    f.k.bar((x, y, 1.08), (x2, y2, 1.08), 0.009, "lock_chrome", seg=6)
    x3, y3, _ = f.p(hx + 0.13, 0.045, 1.08)
    f.k.sqbar((x2, y2, 1.08), (x3, y3, 1.08), 0.02, "lock_chrome", h=0.012)
    x, y, _ = f.p(hx, 0.0, 0.98)
    x2, y2, _ = f.p(hx, 0.008, 0.98)
    f.k.bar((x, y, 0.98), (x2, y2, 0.98), 0.012, "lock_chrome", seg=8)
    f.rect(hx - 0.002, hx + 0.002, 0.972, 0.988, 0.0085, "seam_dark")  # its keyway
    # the closer on the head rail by the hinges, its arm to the frame's head
    f.slab(l1 - 0.33, l1 - 0.07, z1 - 0.06, z1 - 0.005, -0.004, 0.04, 0.006, "closer_grey")
    x, y, _ = f.p(l1 - 0.31, 0.03, z1 - 0.03)
    x2, y2, _ = f.p(l1 - 0.52, 0.03, HEAD - 0.02)
    f.k.sqbar((x, y, z1 - 0.03), (x2, y2, HEAD - 0.02), 0.016, "closer_grey", h=0.008)


def grille(f: Face, a0: float, a1: float, z0: float, z1: float, d: float, fins: int, deep: float, mat: str) -> None:
    """A framed grille on a face at depth d: its frame `deep` out, a dark inside and slanted fins in it."""
    w = 0.02
    f.box(a0, a1, d - 0.002, d + deep, z0, z0 + w, mat)
    f.box(a0, a1, d - 0.002, d + deep, z1 - w, z1, mat)
    f.box(a0, a0 + w, d - 0.002, d + deep, z0 + w, z1 - w, mat)
    f.box(a1 - w, a1, d - 0.002, d + deep, z0 + w, z1 - w, mat)
    f.rect(a0 + w, a1 - w, z0 + w, z1 - w, d + 0.0008, "grille")
    step = (z1 - z0 - 2 * w) / fins
    for i in range(fins):
        z = z0 + w + i * step
        f.run(a0 + w, a1 - w, [(d + 0.002, z + step * 0.2), (d + deep - 0.002, z), (d + deep - 0.002, z + step * 0.3),
                               (d + 0.002, z + step * 0.9)], mat)


def air_conditioner(f: Face, a: float) -> None:
    """A through-wall air conditioner centred at `a` along the face: its sleeve, its casing with the edges rounded,
    angled fins in a framed grille, two knobs, brackets under it and a drain pipe down to the base."""
    z0, z1, w = 0.44, 0.86, 0.3
    f.box(a - w - 0.02, a + w + 0.02, -0.002, 0.01, z0 - 0.02, z1 + 0.02, "booth_frame")  # the sleeve
    f.slab(a - w, a + w, z0, z1, 0.008, 0.056, 0.008, "cab_ac")
    grille(f, a - w + 0.03, a + 0.12, z0 + 0.04, z1 - 0.04, 0.056, 8, 0.012, "cab_ac")
    for z in (0.74, 0.66):
        x, y, _ = f.p(a + 0.2, 0.056, z)
        x2, y2, _ = f.p(a + 0.2, 0.066, z)
        f.k.bar((x, y, z), (x2, y2, z), 0.016, "closer_grey", seg=8)
    for i in range(4):  # the intake slots under the knobs
        z = z0 + 0.05 + i * 0.03
        f.rect(a + 0.15, a + 0.26, z, z + 0.012, 0.0565, "grille")
    for s in (-1.0, 1.0):  # brackets: plates under the casing back to the wall
        aa = a + s * (w - 0.06)
        f.run(aa - 0.006, aa + 0.006, [(0.0, z0), (0.05, z0), (0.0, z0 - 0.14)], "booth_frame")
    x, y, _ = f.p(a + w - 0.05, 0.02, z0)
    f.k.bar((x, y, z0), (x, y, PLINTH + 0.02), 0.01, "base_steel", seg=6)  # the drain


def lamp(f: Face, a: float, z: float) -> None:
    """A bulkhead lamp at `a`, its foot at z: a base, a lens and the cage's bars over it."""
    f.slab(a - 0.1, a + 0.1, z, z + 0.11, -0.002, 0.03, 0.008, "closer_grey")
    f.slab(a - 0.08, a + 0.08, z + 0.015, z + 0.095, 0.028, 0.055, 0.01, "glass")
    for zz in (z + 0.035, z + 0.075):
        f.box(a - 0.085, a + 0.085, 0.055, 0.062, zz - 0.004, zz + 0.004, "hinge_steel")
    f.box(a - 0.004, a + 0.004, 0.055, 0.063, z + 0.01, z + 0.1, "hinge_steel")


def build(name: str, width: float, depth: float) -> object:
    hw, hd = width * 0.5, depth * 0.5
    bx, by = hw - OVER, hd - OVER
    k = wk.Kit(name)
    # The base, a shadow line in under the panels; the core behind the panels (it shows in the joints); the posts.
    k.blk((-bx + 0.012, -by + 0.012, 0.0), (bx - 0.012, by - 0.012, PLINTH), "base_steel")
    k.blk((-bx + PT, -by + PT, PLINTH - 0.01), (bx - PT, by - PT, EAVE), "seam_dark")
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            pts = [(-POST, -POST), (0.008, -POST), (0.008, -0.004), (-0.004, 0.008), (-POST, 0.008)]
            k.prism([(sx * (bx + u), sy * (by + v)) for u, v in pts], "z", 0.05, EAVE, "booth_frame")
            cx, cy = sx * (bx - POST * 0.5 + 0.004), sy * (by - POST * 0.5 + 0.004)
            k.blk((cx - 0.045, cy - 0.045, 0.0), (cx + 0.045, cy + 0.045, 0.016), "base_steel")  # its levelling foot
            k.cyl((cx, cy, 0.016), 0.012, 0.034, "hinge_steel", seg=6)
            k.cyl((cx, cy, 0.036), 0.02, 0.014, "hinge_steel", seg=6)
    k.mark("body")
    # The roof: a slab overhanging all round, a painted fascia under an aluminium capping, a drip bead under it, the
    # grey membrane on top.
    k.panel((-hw + 0.01, -hd + 0.01, EAVE), (hw - 0.01, hd - 0.01, HIGH - 0.022), "booth_white", step=0.3,
            skip=("+z",))
    k.panel((-hw + 0.03, -hd + 0.03, HIGH - 0.024), (hw - 0.03, hd - 0.03, HIGH - 0.02), "roof_felt", step=0.3,
            skip=("-z",))
    cap = [(-0.03, HIGH - 0.035), (0.0, HIGH - 0.035), (0.0, HIGH - 0.006), (-0.006, HIGH), (-0.03, HIGH)]
    fascia = [(-0.026, EAVE - 0.03), (-0.008, EAVE - 0.03), (-0.008, HIGH - 0.035), (-0.026, HIGH - 0.035)]
    drip = [(-0.026, EAVE - 0.042), (-0.002, EAVE - 0.042), (-0.002, EAVE - 0.03), (-0.026, EAVE - 0.03)]
    for prof, mat in ((cap, "booth_frame"), (fascia, "booth_white"), (drip, "booth_frame")):
        inset = -min(d for d, _ in prof)
        for sy in (-1.0, 1.0):
            k.prism([(sy * (hd + d), z) for d, z in prof], "x", -hw, hw, mat)
        for sx in (-1.0, 1.0):
            k.prism([(sx * (hw + d), z) for d, z in prof], "y", -hd + inset, hd - inset, mat)
    k.mark("roof")
    # The front: the door at its +x side, a window over the rest, the lamp over the door, a blank sign.
    front = Face(k, "x", -by, -1.0, bx)
    d1 = bx - POST - 0.01
    d0 = d1 - DOOR_W
    w0, w1 = -bx + POST + 0.07, d0 - 0.09
    openings = [(d0, d1, PLINTH, HEAD)]
    if w1 - w0 > 0.35:
        openings.append((w0, w1, SILL, HEAD))
        window(front, w0, w1, SILL, HEAD, 2 if w1 - w0 > 1.0 else 1, False, 0.55)
        front.rect(w1 - 0.2, w1 - 0.08, 0.84, 0.92, 0.0015, "sign_plate")
    front.panels(openings, [])
    door(front, d0, d1)
    lamp(front, (d0 + d1) * 0.5, HEAD + 0.035)
    k.mark("front")
    # The sides: a window in each (the shallow booth: only on +x), the air conditioner on the -x side.
    for sx in (-1.0, 1.0):
        side = Face(k, "y", sx * bx, sx, by)
        openings = []
        if depth > 1.5:
            openings.append((-by + POST + 0.08, by - 0.42, SILL, HEAD))
            window(side, *openings[0], 2, True, 0.35 if sx > 0 else 0.8)
        elif sx > 0:
            openings.append((-by + POST + 0.07, by - POST - 0.07, 1.3, HEAD))
            window(side, *openings[0], 1, False, 0.4)
        side.panels(openings, [] if openings else [0.0])
        if sx < 0:
            air_conditioner(side, by - 0.45 if depth > 1.5 else 0.0)
    k.mark("sides")
    # The back: panels with their joints, a vent high up, a cable conduit up to the roof.
    back = Face(k, "x", by, 1.0, bx)
    n = max(2, round((2 * bx - 2 * POST) / 0.65))
    back.panels([], [-bx + POST + (2 * bx - 2 * POST) * i / n for i in range(1, n)])
    grille(back, -0.14, 0.14, 1.98, 2.16, 0.0, 5, 0.02, "booth_frame")
    x = bx - POST - 0.12
    k.bar((x, by + 0.02, PLINTH + 0.1), (x, by + 0.02, EAVE), 0.016, "base_steel", seg=6)
    for z in (0.6, 1.4, 2.2):
        k.blk((x - 0.025, by, z), (x + 0.025, by + 0.04, z + 0.02), "hinge_steel")
    k.blk((x - 0.06, by, PLINTH + 0.02), (x + 0.06, by + 0.05, PLINTH + 0.18), "closer_grey")  # its box
    k.mark("back")
    return k.build()


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint in ("booth_white", "booth_frame", "cab_ac"):
        col = wt.mix(c, wk.lin(wk.GRIME), 0.12 + 0.3 * wt.smooth(0.4, 0.8, wt.fbm(p, 0.2, 81)))
        streak = wt.smooth(0.6, 0.85, wt.fbm(Vector((p.x * 7.0, p.y * 7.0, p.z * 0.5)), 0.5, 83)) * (1 - abs(n.z))
        col = wt.mix(col, wk.lin(wk.GRIME), 0.3 * streak * wt.smooth(1.2, EAVE, p.z))  # streaks from the roof
        return wk.grime(p, n, col, seed=16)
    if paint in ("glass", "glass_sheen"):
        return wt.mix(c, wk.lin(wk.GRIME), 0.3 * wt.fbm(p, 0.15, 85))
    if paint == "blind":
        return wt.mix(c, wk.lin("glass"), 0.35 + 0.2 * wt.fbm(p, 0.2, 87))  # seen through dirty glass
    if paint == "roof_felt":
        return wt.mix(c, wk.lin(wk.DUST), 0.2 + 0.35 * wt.fbm(p, 0.3, 89))  # dust settled on the roof
    return wk.grime(p, n, c, seed=4, amount=0.6)


def main() -> None:
    wk.check_colours(list(wk.PAINT))
    for name, (width, depth) in SIZES.items():
        wk.reset()
        ob = build(name, width, depth)
        wk.finish(ob, (-width * 0.5, -depth * 0.5, 0.0), (width * 0.5, depth * 0.5, HIGH))
        wk.bake(ob, weather)
        wk.write(ob, name, BUDGET)
        if "--render" in sys.argv:
            out = sys.argv[sys.argv.index("--render") + 1].replace(".jpg", "_%s.jpg" % name)
            wk.render(wk.quarter_views(width, depth, HIGH), out,
                      "SM4 %s (Subway map prop, %g x %g x 2.6 m)" % (name.replace("_", " "), width, depth))


if __name__ == "__main__":
    main()
