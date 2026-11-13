"""Subway's trains (SM1, models 1 to 5 of art/subway-model-list.md), from the owner's photos
(art/references/maps/subway/01..05): a small-profile metro car with big round-cornered windows, plug doors flush with
the body, longitudinal seats under padded backs, steel grab poles, a cove of advert frames over the windows and a lit
ceiling; open gangways between coupled cars, a blank end where they are not; a cab front with a tall dark glass mask, a
centre door and lamp strips down its sides. Plain unpainted grey and worn (the owner, 2026-11-11): no stripe, no
livery, no logo, no line name, no number.

The game's train is rooms (tools/subway/layout.py): each car is a 15 m stretch of its train's room, a 2.4 m box of air
walled 0.15 m thick on every side, its ceiling slab 0.3 m over it and its floor slab down to the track bed. Every model
here fills those boxes exactly (TrainView lays them; StationSurface leaves the train's walls, slabs and car ends to
them): what you see is what a BB or a body meets but for the thin look-only fittings (the poles and rails, the cove,
the screens at the seats' ends over the seat blocks, handles and the folded-back cab door leaves).

Frame (the game's, metres): x along the car, y up from the car's floor, z across it, +z the platform side; Blender
gets (x, -z, y), so the glTF export gives the game's axes back.

    train_lights.glb      half its ceiling's two lamp strips (x 0 to its end), glowing cool white, laid twice a car
    train_cab_leds.glb    a cab front's white LED lamps (headlamps, side strips, marker lamps), drawn glowing over it
    train_end_leds.glb    the uncoupled end's white LED lamps, drawn glowing over train_end_outer
    train_body.glb        a car's sides, floor, ceiling and fittings, every door hole open (x +-7.35, z +-1.75)
    train_door.glb        a shut pair of door leaves, filling a door hole (x +-0.7, z 1.6..1.75)
    train_gangway.glb     the joint between two coupled cars, an open gangway through it (x +-0.15)
    train_end.glb         a car's blank end with its shut end door (x 0..0.15, the car's inside at x 0)
    train_end_outer.glb   the same at the uncoupled end of a train, its outside face and underframe drawn
    train_cab.glb         a cab front, its door shut (x 0..0.15, the track side at x 0.15)
    train_cab_open.glb    the same with its door open: the way out onto the track
    train_seat.glb        a 2 m run of seat cushions on its plinth (the seat block, PropDressConfig: FIT)
    train_seat_short.glb  the 1.25 m run at a car's ends
    train_bogie.glb       a bogie under each train end: four wheels on the rails, axles, axle boxes and their coil
                          springs, side frames, air springs, motors, gearboxes and tread brakes (its block's 2.7 x 0.64
                          x 2.4 m box over the rails, PropDressConfig: FIT; the owner, 2026-11-12: "model the wheels")
    tool_cart.glb         model 5: the maintenance crew's tool trolley left in the south train's aisle (its block's
                          1.5 x 1.7 x 1.2 m box, PropDressConfig: FIT), from art/references/maps/subway/05-tool-cart

    python3 -I tools/blender/maps/train.py <repo root>
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402  (brings bpy, hardsurface)
import weathering as wt  # noqa: E402
from mathutils import Vector  # noqa: E402

hs = mk.hs

# ------------------------------------------------------------------------------------------------- the car's numbers

HALF = 7.5            # half a car's length, joint to joint
END = 0.15            # a car end's thickness (half the joint's 0.3 m block; a cab end's sealed wall)
IN_X = HALF - END     # the inside's half length
OUT_Z = 1.75          # the sides' outer faces (the room's edge)
IN_Z = 1.60           # their inner faces
TOP = 2.40            # the ceiling (the car's air is 2.4 m tall)
UNDER = -0.9          # the track bed under the car's floor (the platform's height over it)
UNDER_H = 0.75        # the space under a train's end (layout.py UNDER_ENDS): its height over the track bed
UNDER_D = 3.85        # and how far in it runs from the end, past the bogie
SOLE_Z = 1.45         # the sole bars' inner faces either side of it
SLAB = -1.2           # the floor slab's foot (the track bed's 0.3 m slab)
DOOR_SLOTS = (-5.3, -1.8, 1.8, 5.3)    # each side's door holes (layout.py's doors stand 2.2, 5.7, 9.3, 12.8 m along)
# The side doors are tall and wide and run up into the roof's curve, the windows deep (the owner's photos, the critic's
# proportions: door width to height 0.71, car to door height 1.2, sill 0.38 and window 0.49 of the door's height).
DOOR_HW = 0.8
DOOR_H = 2.25
END_DOOR_H = 1.95     # a car end's door, and the cab's
DOOR_WIN_Y = (0.95, 2.0)   # a door leaf's window, up into the roof's curve (layout.py DOOR_WIN_Y)
SILL = 0.85           # the windows' sills and heads
HEAD = 1.95
WIN_R = 0.14          # the windows' corner radius
WIN_SEG = 5           # each corner's segments
CANT = 1.95           # the door heads: the side's cells end here and the roof's begin
# The car's cross-section, rounder than a box (the owner, 2026-11-12: "more round and less boxy"): its foot curves in
# over BILGE to BILGE_IN under the side, the side stands upright from there to SPRING, then leans in ever more, LEAN by
# the door heads (the doors curve with it, the owner's ask), and the roof rounds on over to the crown on a superellipse
# of power ROUND_N (z_at). The interior stays upright inside it (IN_Z, the cove).
BILGE = 0.40
BILGE_IN = 0.12
SPRING = 0.55
LEAN = 0.20
ROUND_N = 2.2
SKIN = 0.07           # the inside wall stands this far in from the leaning side (zin), never further out than IN_Z
ROOF_TOP = 2.70       # the roof's crown: the top of the ceiling slab over the car's air (TOP + 0.3), the train's box
SKIRT = 0.10          # the dark strip along the side's foot
STRIPE = (0.66, 0.84)  # the orange band under the windows, round the sides, ends and cab corners (owner, 2026-11-12)
CLEAN = 0.4            # the outsides' grime, a share of what a grey car wore: the paint is clean white (owner, 2026-11-12)
SEAT_H = 0.45         # the seat blocks' height and depth (layout.py)
SEAT_D = 0.52         # the seat cushion's depth, deeper than its back (the owner, 2026-11-12: "slightly longer")
COVE_Y = 1.95         # the cove of advert frames, from the wall at this height to COVE_Z at the ceiling
COVE_Z = 1.15
POLE_R = 0.018
POLE_Z = 1.22         # the poles stand over the seats' front edge
RAIL_Y = 1.98
GANG_HW = 0.6         # the gangway's half width (layout.py's car ends leave 1.2 m between them)
CAB_DOOR_HW = 0.6     # the cab's door (the south train's way out: 1.2 m)
END_DOOR_HW = 0.4
FLECKS = 10.0         # the floor's flecks a square metre

# A car is 22k (the list: 12k outside, 10k inside): its body, its eight door pairs and its seats (up to 1.6k a car).
# A car end is 1.5k, a gangway two of them; the uncoupled end adds its underframe's end (1k, the slack in its car).
BUDGET = {"train_body": 16400, "train_door": 640, "train_door_glazed": 640, "train_windows": 240, "train_door_glass": 60, "train_gangway": 3000, "train_end": 1500, "train_end_outer": 2600,
          "train_cab": 4000, "train_cab_open": 4000, "train_seat": 700, "train_seat_short": 500, "train_lights": 100,
          "tool_cart": 1500, "train_bogie": 3000, "train_cab_leds": 270, "train_end_leds": 180}

# Colours (sRGB): clean white paint (the owner, 2026-11-12: "more clean white than the grey"), black rubber, dark glass
# (the far side's, against the tunnel wall; the platform side's panes are see-through, `pane`, TrainView); inside,
# off-white panels, a dark speckled floor, steel poles and charcoal moquette. All white, grey or near it but the orange
# band along the sides, a worn burnt orange (the owner, 2026-11-12: "give the trains an orange stripe"), the one colour
# near a team's hue.
COLOURS = {
    "body": 0xE6E6E2, "body_lo": 0xD6D6D2, "seam": 0x9A9A96, "rubber": 0x2C2B2E, "glass": 0x2A3033,
    "glass_hi": 0x46505A, "skirt": 0x3B3936, "under": 0x262523, "steel": 0x8A8A88, "pole": 0xB9B9B5,
    "inner": 0xDAD6CE, "fleck": 0x9C9A96, "fleck_lo": 0x67666A, "poster_b": 0xB3B891, "poster_c": 0x9A968C,
    "inner_lo": 0xBDB9B1, "trim": 0x9E9B95, "floor": 0x3E3D40, "light": 0xF4ECDA,
    "vent": 0x77756F, "poster": 0xC9C3B6, "frame": 0x5B5A5C, "seat": 0x535661, "seat_dot": 0x7A7D88,
    "seat_ring": 0x8F8E8A, "plinth": 0x2F2E31, "bellows": 0x262527, "gang_in": 0x9C9A95, "lamp": 0xE8E2D2,
    "mask": 0x1E2022, "yellow": 0xB8A858, "stripe": 0xC0652F, "led": 0xFFFFFF, "pane": 0x58656B,
    "cart": 0x6F7174, "cart_lo": 0x5C5E61, "peg": 0x8A877E, "wood": 0x7E776E, "castor": 0x2E2D2F,
    "tool": 0x7D8084, "tape": 0xB8A858, "cable": 0x34363A,
}


def B(x: float, y: float, z: float) -> tuple:
    """The game's frame to Blender's."""
    return (x, -z, y)


class Model:
    """One model's faces in the game's frame, each wound to face where it is told."""

    def __init__(self, name: str):
        hs.reset()
        mk.paints(COLOURS)
        self.name = name
        self.b = hs.Builder(name, [])

    def poly(self, pts: list, facing: tuple, paint: str) -> None:
        """A flat face through `pts` (the game's frame), turned to face `facing` (any vector on its front side)."""
        bm = self.b.bm
        n = Vector((0.0, 0.0, 0.0))
        for i, p in enumerate(pts):
            q = pts[(i + 1) % len(pts)]
            n.x += (p[1] - q[1]) * (p[2] + q[2])
            n.y += (p[2] - q[2]) * (p[0] + q[0])
            n.z += (p[0] - q[0]) * (p[1] + q[1])
        if n.dot(Vector(facing)) < 0.0:
            pts = list(reversed(pts))
        f = bm.faces.new([bm.verts.new(Vector(B(*p))) for p in pts])
        f.material_index = self.b.mat(paint)

    def rect_z(self, x0: float, x1: float, y0: float, y1: float, z: float, s: float, paint: str) -> None:
        """A rectangle across x and y at depth z, facing s * z."""
        self.poly([(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)], (0, 0, s), paint)

    def rect_x(self, z0: float, z1: float, y0: float, y1: float, x: float, s: float, paint: str) -> None:
        self.poly([(x, y0, z0), (x, y0, z1), (x, y1, z1), (x, y1, z0)], (s, 0, 0), paint)

    def rect_y(self, x0: float, x1: float, z0: float, z1: float, y: float, s: float, paint: str) -> None:
        self.poly([(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], (0, s, 0), paint)

    def box(self, lo: tuple, hi: tuple, paint: str, skip: str = "") -> None:
        """A box in the game's frame, its faces outwards; `skip` names faces left off ("-y+z": its foot, its back)."""
        (x0, y0, z0), (x1, y1, z1) = lo, hi
        for s, x in ((-1, x0), (1, x1)):
            if ("+x" if s > 0 else "-x") not in skip:
                self.rect_x(z0, z1, y0, y1, x, s, paint)
        for s, y in ((-1, y0), (1, y1)):
            if ("+y" if s > 0 else "-y") not in skip:
                self.rect_y(x0, x1, z0, z1, y, s, paint)
        for s, z in ((-1, z0), (1, z1)):
            if ("+z" if s > 0 else "-z") not in skip:
                self.rect_z(x0, x1, y0, y1, z, s, paint)

    def bar(self, a: tuple, c: tuple, r: float, paint: str, sides: int = 8) -> None:
        mk.cylinder(self.b, B(*a), B(*c), r, paint, sides=sides, caps=False)

    def finish(self, weather=None) -> None:
        ob = self.b.build()
        mk.clean(ob)
        mk.bake_vertex_colours(ob)
        if weather is not None:
            wt.weather(ob, weather)
        mk.report(ob, self.name, BUDGET[self.name])
        tris = hs.tris(ob)
        if tris > BUDGET[self.name]:
            raise SystemExit(f"{self.name}: {tris} triangles, over its budget of {BUDGET[self.name]}")
        wt.export(ob, self.name)


class Glow(Model):
    """Faces kept while another model is built (hs holds one model at a time) and then built on their own (`finish`),
    all in `paint`: an end's white LED lenses (TrainView draws them glowing over the end, in their own lamp material)
    or a car's see-through window panes (drawn in a clear material)."""

    def __init__(self, name: str, paint: str = "led"):
        self.name = name
        self.paint = paint
        self.faces = []

    def poly(self, pts: list, facing: tuple, paint: str) -> None:
        self.faces.append((pts, facing))

    def finish(self, weather=None) -> None:
        m = Model(self.name)
        for pts, facing in self.faces:
            Model.poly(m, pts, facing, self.paint)
        Model.finish(m)


def led_cluster(g: Glow, c: tuple, pitch: float = 0.026, r: float = 0.0105) -> None:
    """A round LED lamp's seven emitters facing +x round c: one in the middle, six round it."""
    disc(g, c, r, (1, 0, 0), "led", 8)
    for k in range(6):
        a = math.pi * k / 3
        disc(g, (c[0], c[1] + pitch * math.cos(a), c[2] + pitch * math.sin(a)), r, (1, 0, 0), "led", 8)


# ------------------------------------------------------------------------------------------------------ shape helpers

def rounded(x0: float, x1: float, y0: float, y1: float, r: float, seg: int = 3) -> list:
    """A rounded rectangle's outline (x, y), anticlockwise from its bottom-right corner, with the middles of its arcs'
    centres beside each point (for projecting it onto the square corner)."""
    out = []
    corners = [((x1 - r, y0 + r), -0.5 * math.pi), ((x1 - r, y1 - r), 0.0), ((x0 + r, y1 - r), 0.5 * math.pi),
               ((x0 + r, y0 + r), math.pi)]
    for (cx, cy), a0 in corners:
        for k in range(seg + 1):
            a = a0 + 0.5 * math.pi * k / seg
            out.append(((cx + r * math.cos(a), cy + r * math.sin(a)), (cx, cy)))
    return out


def squared(outline: list, r: float) -> list:
    """Each point of a rounded outline pushed out along the ray from its arc's centre onto the square corner, the point
    nearest each arc's middle onto the corner itself (with an odd count of segments no point lies on the diagonal, and
    the band between the outlines would leave the corner open)."""
    out = []
    for (x, y), (cx, cy) in outline:
        dx, dy = x - cx, y - cy
        k = r / max(abs(dx), abs(dy), 1e-9)
        out.append((cx + dx * k, cy + dy * k))
    arcs: dict = {}
    for i, ((x, y), c) in enumerate(outline):
        arcs.setdefault(c, []).append(i)
    for (cx, cy), idx in arcs.items():
        mid = min(idx, key=lambda i: abs(abs(outline[i][0][0] - cx) - abs(outline[i][0][1] - cy)))
        (x, y), _ = outline[mid]
        out[mid] = (cx + math.copysign(r, x - cx), cy + math.copysign(r, y - cy))
    return out


def framed(m: Model, x0: float, x1: float, y0: float, y1: float, face: float, s: float, layers: list, cap: str | None,
           r: float = WIN_R, seg: int = WIN_SEG) -> list:
    """A rounded window in a square hole (x0..x1, y0..y1) of a face at depth `face` facing s * z (or at `face(y)`, a
    curved side's depth at each height): the face's paint up to the round (layers[0]'s paint), then each layer (inset
    m, depth m in from the face, paint) as a band, then the pane (`cap`, none: left open) at the last layer's depth.
    Returns the last layer's ring, its points in the game's frame (for a reveal through to the other face, `bridge`)."""
    face_at = face if callable(face) else (lambda y: face)
    rings = []
    outline = rounded(x0, x1, y0, y1, r, seg)
    rings.append((squared(outline, r), 0.0))
    rings.append(([p for p, _ in outline], 0.0))
    for inset, depth, _ in layers[1:]:
        o = rounded(x0 + inset, x1 - inset, y0 + inset, y1 - inset, max(r - inset, 0.02), seg)
        rings.append(([p for p, _ in o], depth))
    paints = [layers[0][2]] + [p for _, _, p in layers[1:]]
    cx, cy = (x0 + x1) * 0.5, (y0 + y1) * 0.5
    for k in range(len(rings) - 1):
        (a, da), (b, db) = rings[k], rings[k + 1]
        n = len(a)
        for i in range(n):
            j = (i + 1) % n
            mx = (a[i][0] + a[j][0] + b[i][0] + b[j][0]) * 0.25
            my = (a[i][1] + a[j][1] + b[i][1] + b[j][1]) * 0.25
            toward = Vector((cx - mx, cy - my, 0.0))
            if toward.length > 0:
                toward.normalize()
            facing = (toward.x, toward.y, s)
            pts = [(a[i][0], a[i][1], face_at(a[i][1]) - s * da), (a[j][0], a[j][1], face_at(a[j][1]) - s * da),
                   (b[j][0], b[j][1], face_at(b[j][1]) - s * db), (b[i][0], b[i][1], face_at(b[i][1]) - s * db)]
            m.poly(pts, facing, paints[k])
    last, d = rings[-1]
    ring = [(x, y, face_at(y) - s * d) for x, y in last]
    if cap is not None:
        m.poly(ring, (0, 0, s), cap)
    return ring


def bridge(m: Model, a: list, b: list, paint: str) -> None:
    """The reveal through a see-through window's wall: a band from ring `a` (an outer frame's last, framed) to ring `b`
    (its inner lining's, as many points), each quad facing in towards the window's middle."""
    cx = sum(p[0] for p in a) / len(a)
    cy = sum(p[1] for p in a) / len(a)
    for i in range(len(a)):
        j = (i + 1) % len(a)
        mx, my = (a[i][0] + a[j][0]) * 0.5 - cx, (a[i][1] + a[j][1]) * 0.5 - cy
        m.poly([a[i], a[j], b[j], b[i]], (-mx, -my, 0.0), paint)


def pane(g: "Glow", ring: list) -> None:
    """A see-through window's glass on `ring` (framed's), both faces: seen from the platform and from inside."""
    g.poly(ring, (0, 0, 1), "pane")
    g.poly([(x, y, z - 0.001) for x, y, z in ring], (0, 0, -1), "pane")


def grid_face(m: Model, xs: list, ys: list, z: float, s: float, holes: list, paint) -> None:
    """A face at depth z facing s * z, tiled on the breaks `xs` by `ys`, leaving out every cell inside a hole
    (x0, x1, y0, y1); `paint(x, y)` names each cell's paint at its middle."""
    for xa, xb in zip(xs, xs[1:]):
        for ya, yb in zip(ys, ys[1:]):
            mx, my = (xa + xb) * 0.5, (ya + yb) * 0.5
            if any(h[0] <= mx <= h[1] and h[2] <= my <= h[3] for h in holes):
                continue
            m.rect_z(xa, xb, ya, yb, z, s, paint(mx, my))


def grid_side(m: Model, xs: list, ys: list, s: float, holes: list, paint, inset: float = 0.0) -> None:
    """grid_face on the side's curved face (z_at, `inset` in from it, facing s * z): each row of cells at its own
    depth."""
    for xa, xb in zip(xs, xs[1:]):
        for ya, yb in zip(ys, ys[1:]):
            mx, my = (xa + xb) * 0.5, (ya + yb) * 0.5
            if any(h[0] <= mx <= h[1] and h[2] <= my <= h[3] for h in holes):
                continue
            za, zb = s * (z_at(ya) - inset), s * (z_at(yb) - inset)
            m.poly([(xa, ya, za), (xb, ya, za), (xb, yb, zb), (xa, yb, zb)], (0, 0, s), paint(mx, my))


def breaks(edges: list, lo: float, hi: float, step: float) -> list:
    """Every edge between lo and hi, with more between so no cell is wider than `step`."""
    pts = sorted({round(e, 4) for e in edges if lo - 1e-6 <= e <= hi + 1e-6} | {lo, hi})
    out = [pts[0]]
    for a, b in zip(pts, pts[1:]):
        n = max(1, math.ceil((b - a) / step - 1e-6))
        out += [a + (b - a) * k / n for k in range(1, n + 1)]
    return out


def z_at(y: float) -> float:
    """The side's outer face (its z, the platform side's) at height y over the car's floor, from the foot (0) up the
    side and round the roof to the crown (ROOF_TOP, z 0): the car's cross-section."""
    if y < BILGE:
        c = (BILGE - y) / BILGE
        return OUT_Z - BILGE_IN + BILGE_IN * math.sqrt(max(0.0, 1.0 - c * c))
    if y <= SPRING:
        return OUT_Z
    if y <= CANT:
        return OUT_Z - LEAN * ((y - SPRING) / (CANT - SPRING)) ** 2
    v = min(1.0, (y - CANT) / (ROOF_TOP - CANT))
    return (OUT_Z - LEAN) * (1.0 - v ** ROUND_N) ** (1.0 / ROUND_N)


def zin(y: float) -> float:
    """The inside wall's face (its z) at height y up to the cove: upright at IN_Z, then following the side's lean in."""
    return IN_Z if y < SPRING else min(IN_Z, z_at(y) - SKIN)


def cove_at(t: float) -> tuple:
    """The cove's slope from the wall's head (t 0: COVE_Y, zin) to the ceiling's edge (t 1: TOP, COVE_Z), (y, z)."""
    return (COVE_Y + (TOP - COVE_Y) * t, zin(COVE_Y) + (COVE_Z - zin(COVE_Y)) * t)


def lining_at(y: float) -> float:
    """The inside's face (its z) at height y: the wall (zin) up to the cove, then the cove's slope up to the ceiling."""
    if y <= COVE_Y:
        return zin(y)
    return cove_at(min(1.0, (y - COVE_Y) / (TOP - COVE_Y)))[1]


def inner_outline() -> list:
    """The car's inside across, (z, y), anticlockwise: the floor, the walls, the coves and the ceiling (an end wall is
    cut to it, so its corners never poke out through the roof)."""
    right = [(zin(y), y) for y in breaks([SPRING, 1.3, 1.6], 0.0, COVE_Y, 0.2)] + [(COVE_Z, TOP)]
    return [(-IN_Z, -0.1), (IN_Z, -0.1)] + right + [(-z, y) for z, y in reversed(right)]


def side_rows(edges: list = (), top: float = CANT, step: float = 0.5) -> list:
    """Heights up the side from its foot to `top` for cells that follow its curve: finer round the foot, at the skirt
    and the stripe and `edges`."""
    return breaks([SKIRT, 0.19, 0.28, BILGE, SPRING, *STRIPE, *edges], 0.0, top, step)


def row_paint(y: float, paint: str) -> str:
    """A side cell's paint at height y: the dark skirt along its foot, the orange stripe, else `paint`."""
    if y < SKIRT:
        return "skirt"
    return "stripe" if STRIPE[0] <= y <= STRIPE[1] else paint


def side_strip(m: "Model", x0: float, x1: float, s: float, rows: list, paint, inset: float = 0.0) -> None:
    """The side's curved face from x0 to x1 (s: the platform side's or the far one), `inset` in from the outer face,
    in `rows`; `paint(y)` names each row's paint at its middle."""
    for ya, yb in zip(rows, rows[1:]):
        za, zb = s * (z_at(ya) - inset), s * (z_at(yb) - inset)
        m.poly([(x0, ya, za), (x1, ya, za), (x1, yb, zb), (x0, yb, zb)], (0, 0, s), paint((ya + yb) * 0.5))


def cant_profile(below: int = 7, above: int = 7) -> list:
    """The roof's outline, (z, y) from the side's top (z_at(CANT), CANT) round to the crown (0, ROOF_TOP), on the
    superellipse z_at follows over CANT: `below` segments up to the ceiling's height TOP (where the tunnel's lintel
    over a platform hides the rest) and `above` over it."""
    h, e = ROOF_TOP - CANT, 2.0 / ROUND_N
    knee = math.asin(((TOP - CANT) / h) ** (ROUND_N / 2.0))
    angles = [knee * k / below for k in range(below)] + [knee + (0.5 * math.pi - knee) * k / above
                                                          for k in range(above + 1)]
    return [((OUT_Z - LEAN) * math.cos(a) ** e, CANT + h * math.sin(a) ** e) for a in angles]


def roof_outline(inset: float = 0.0) -> list:
    """The car's outline across, (z, y), anticlockwise: its foot, its curved sides and the roof over them (convex);
    `inset` draws it in at the sides (a cab front inside its rounded corners), never past the roof."""
    top = z_at(CANT) - inset
    right = [(z_at(y) - inset, y) for y in side_rows()[:-1]] + [(min(z, top), y) for z, y in cant_profile()]
    foot = z_at(0.0) - inset
    return [(-foot, SLAB), (foot, SLAB)] + right + [(-z, y) for z, y in reversed(right[:-1])]


def face_x(m: "Model", z0: float, z1: float, y0: float, y1: float, x: float, f: float, paint: str,
           inset: float = 0.0, ring: list | None = None) -> None:
    """A rectangle across the car at depth x facing f * x, cut to the car's outline (an end face under the roof; a
    cab's face inside its rounded corners, the outline drawn in by `inset`), or to `ring` (an inside wall)."""
    pts = [(z0, y0), (z1, y0), (z1, y1), (z0, y1)]
    ring = ring or roof_outline(inset)
    for (az, ay), (bz, by) in zip(ring, ring[1:] + ring[:1]):
        def side(p: tuple) -> float:
            return (bz - az) * (p[1] - ay) - (by - ay) * (p[0] - az)
        out = []
        for i, p in enumerate(pts):
            q = pts[(i + 1) % len(pts)]
            sp, sq = side(p), side(q)
            if sp >= -1e-9:
                out.append(p)
            if (sp >= -1e-9) != (sq >= -1e-9):
                t = sp / (sp - sq)
                out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
        pts = out
        if len(pts) < 3:
            return
    area = sum(p[0] * q[1] - q[0] * p[1] for p, q in zip(pts, pts[1:] + pts[:1])) * 0.5
    if abs(area) < 1e-6:
        return
    m.poly([(x, y, z) for z, y in pts], (f, 0, 0), paint)


def disc(m: Model, c: tuple, r: float, facing: tuple, paint: str, n: int = 10) -> None:
    """A flat round face of radius r at c (the game's frame), facing along an axis (one of x, y or z)."""
    ax = max(range(3), key=lambda i: abs(facing[i]))
    u, v = [i for i in range(3) if i != ax]
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        p = list(c)
        p[u] += r * math.cos(a)
        p[v] += r * math.sin(a)
        pts.append(tuple(p))
    m.poly(pts, facing, paint)


def dome(m: Model, c: tuple, r: float, paint: str, n: int = 10, rings: int = 3, up: float = -1.0) -> None:
    """A half sphere on its flat side at c (the game's frame), bulging down from a ceiling (up -1) or up (up 1)."""
    prev = [(c[0] + r * math.cos(2 * math.pi * k / n), c[1], c[2] + r * math.sin(2 * math.pi * k / n))
            for k in range(n)]
    for j in range(1, rings + 1):
        a = 0.5 * math.pi * j / rings
        rr, dy = r * math.cos(a), r * math.sin(a)
        if j == rings:
            tip = (c[0], c[1] + up * r, c[2])
            for k in range(n):
                p, q = prev[k], prev[(k + 1) % n]
                m.poly([p, q, tip], ((p[0] + q[0]) * 0.5 - c[0], up * 0.5, (p[2] + q[2]) * 0.5 - c[2]), paint)
            break
        ring = [(c[0] + rr * math.cos(2 * math.pi * k / n), c[1] + up * dy, c[2] + rr * math.sin(2 * math.pi * k / n))
                for k in range(n)]
        for k in range(n):
            p, q, pq, pp = prev[k], prev[(k + 1) % n], ring[(k + 1) % n], ring[k]
            m.poly([p, q, pq, pp], ((p[0] + q[0]) * 0.5 - c[0], up * 0.3 * j, (p[2] + q[2]) * 0.5 - c[2]), paint)
        prev = ring


# --------------------------------------------------------------------------------------------------------- the body

def bays() -> list:
    """The stretches of side between the door holes, (x0, x1), end to end."""
    edges = [-IN_X] + [e for c in DOOR_SLOTS for e in (c - DOOR_HW, c + DOOR_HW)] + [IN_X]
    return [(edges[i], edges[i + 1]) for i in range(0, len(edges), 2)]


def windows() -> list:
    """Each window's hole (x0, x1), one a bay, inset from the bay's ends."""
    out = []
    for a, b in bays():
        inset = 0.22 if b - a > 1.8 else 0.18
        out.append((a + inset, b - inset))
    return out


def side(m: Model, s: float, panes: "Glow | None" = None) -> None:
    """One side, outer skin and inner, the platform's (s = 1) or the far one. With `panes` its windows are see-through
    (the owner, 2026-11-12: "can the player see through them?"): open through the wall, a reveal between the frame and
    the lining, their glass kept in `panes`; else dark glass (the far side's, against the tunnel wall)."""
    doors = [(c - DOOR_HW, c + DOOR_HW) for c in DOOR_SLOTS]
    wins = windows()
    holes = [(a, b, 0.0, DOOR_H) for a, b in doors] + [(a, b, SILL, HEAD) for a, b in wins]
    seal = 0.035   # the dark rubber edge round each door hole
    xe = [-IN_X, IN_X] + [e for a, b in doors for e in (a - seal, a, b, b + seal)]
    xe += [e for a, b in wins for e in (a, b)]
    # fine cells, so the baked grime (road dirt, the streaks under the sills) has the vertices to show in
    xs = breaks(xe, -IN_X, IN_X, 0.3)
    ys = side_rows([SKIRT, 0.5, 0.512, SILL, HEAD], CANT, 0.3)

    def outer(x: float, y: float) -> str:
        if any(a - seal <= x <= b + seal for a, b in doors) and y <= DOOR_H + seal:
            return "rubber"     # round the door hole, up its sides and over its head in the roof's curve
        if y < SKIRT:
            return "skirt"
        if 0.5 <= y <= 0.512:
            return "seam"
        if STRIPE[0] <= y <= STRIPE[1]:
            return "stripe"
        return "body_lo" if y < 0.5 else "body"

    grid_side(m, xs, ys, s, holes, outer)
    outer_rings = []
    for a, b in wins:
        outer_rings.append(framed(m, a, b, SILL, HEAD, lambda y: s * z_at(y), s,
                                  [(0, 0, "body"), (0.0, 0.004, "body"), (0.045, 0.012, "rubber"),
                                   (0.05, 0.03, "rubber")], "glass" if panes is None else None))
    # the roof: the side rounds in over the windows up to the crown, the door holes running on up into it, in fine
    # cells up to the ceiling's height (seen from a platform under the tunnel's lintel), coarser over it
    ys_roof = sorted({round(y, 4) for _, y in cant_profile()} | {DOOR_H, DOOR_H + seal})
    coarse = breaks([], -IN_X, IN_X, 1.5)
    for ya, yb in zip(ys_roof, ys_roof[1:]):
        za, zb = z_at(ya), z_at(yb)
        for xa, xb in zip(*((xs, xs[1:]) if yb <= TOP + 1e-6 else (coarse, coarse[1:]))):
            mx, my = (xa + xb) * 0.5, (ya + yb) * 0.5
            if my < DOOR_H and any(a <= mx <= b for a, b in doors):
                continue
            m.poly([(xa, ya, s * za), (xb, ya, s * za), (xb, yb, s * zb), (xa, yb, s * zb)],
                   (0, my - CANT, s * (za + zb) * 0.5), outer(mx, my) if yb <= TOP + 1e-6 else "body")

    # each door hole's jambs and head, following the side's curve: rubber at the outer edge, the inner lining behind
    # it in to the wall, and over the wall's head in to the cove (the hole runs up through it)
    jamb = [0.0, 0.1, 0.19, 0.28, BILGE, SPRING, 1.25, 1.65, CANT, 2.1, DOOR_H]    # enough to follow the curve
    for a, b in doors:
        for x, f in ((a, 1), (b, -1)):
            for ya, yb in zip(jamb, jamb[1:]):
                oa, ob = z_at(ya), z_at(yb)
                m.poly([(x, ya, s * oa), (x, yb, s * ob), (x, yb, s * (ob - 0.02)), (x, ya, s * (oa - 0.02))],
                       (f, 0, 0), "rubber")
                m.poly([(x, ya, s * (oa - 0.02)), (x, yb, s * (ob - 0.02)), (x, yb, s * lining_at(yb)),
                        (x, ya, s * lining_at(ya))], (f, 0, 0), "trim")
        head, head_in = z_at(DOOR_H), lining_at(DOOR_H)
        m.poly([(a, DOOR_H, s * head), (b, DOOR_H, s * head), (b, DOOR_H, s * head_in), (a, DOOR_H, s * head_in)],
               (0, -1, 0), "trim")
        # the threshold plate, and its yellow nosing out to the side's foot
        foot = z_at(0.0)
        m.poly([(a, 0.004, s * IN_Z), (b, 0.004, s * IN_Z), (b, 0.004, s * (foot - 0.02)),
                (a, 0.004, s * (foot - 0.02))], (0, 1, 0), "steel")
        m.poly([(a, 0.004, s * (foot - 0.02)), (b, 0.004, s * (foot - 0.02)), (b, 0.004, s * foot),
                (a, 0.004, s * foot)], (0, 1, 0), "yellow")
        # the door's open/close lamp over its head, outside, on the side's lean
        xm = (a + b) * 0.5
        lo, hi = DOOR_H + 0.02, DOOR_H + 0.05
        m.poly([(xm - 0.06, lo, s * (z_at(lo) + 0.002)), (xm + 0.06, lo, s * (z_at(lo) + 0.002)),
                (xm + 0.06, hi, s * (z_at(hi) + 0.002)), (xm - 0.06, hi, s * (z_at(hi) + 0.002))], (0, 0, s), "lamp")
    # inside: off-white wall, the window linings deeper than the skin, the cove of advert frames over it
    xi = [-IN_X, IN_X] + [e for a, b in doors for e in (a, b)] + [e for a, b in wins for e in (a, b)]
    xs_in = breaks(xi, -IN_X, IN_X, 0.5)
    ys_in = breaks([0.0, 0.08, SPRING, SILL, 1.3, 1.6, HEAD, DOOR_H], 0.0, COVE_Y, 0.4)

    def inner(x: float, y: float) -> str:
        if y < 0.08:
            return "frame"   # the kick strip along the floor
        return "inner_lo" if y < SILL else "inner"

    for xa, xb in zip(xs_in, xs_in[1:]):
        for ya, yb in zip(ys_in, ys_in[1:]):
            mx, my = (xa + xb) * 0.5, (ya + yb) * 0.5
            if not any(h[0] <= mx <= h[1] and h[2] <= my <= h[3] for h in holes):
                m.poly([(xa, ya, s * zin(ya)), (xb, ya, s * zin(ya)), (xb, yb, s * zin(yb)), (xa, yb, s * zin(yb))],
                       (0, 0, -s), inner(mx, my))
    lining = [(0, 0, "inner"), (0.0, -0.01, "inner_lo"), (0.04, -0.035, "trim")]
    for (a, b), ring in zip(wins, outer_rings):
        if panes is None:
            framed(m, a, b, SILL, HEAD, lambda y: s * zin(y), -s, lining, "glass", r=WIN_R + 0.02)
            continue
        # see-through: the lining's lip runs on to the frame's inset, the reveal joins them, the glass in the frame
        inner_ring = framed(m, a, b, SILL, HEAD, lambda y: s * zin(y), -s, lining + [(0.05, -0.035, "trim")], None,
                            r=WIN_R + 0.02)
        bridge(m, ring, inner_ring, "trim")
        pane(panes, ring)
    # the cove: a sloping band of advert frames from the wall's head to the ceiling's edge; over each door only from
    # the door hole's head, which runs up into it
    t_head = (DOOR_H - COVE_Y) / (TOP - COVE_Y)
    for xa, xb in zip(xs_in, xs_in[1:]):
        (ya, za) = cove_at(t_head) if any(a <= (xa + xb) * 0.5 <= b for a, b in doors) else (COVE_Y, zin(COVE_Y))
        m.poly([(xa, ya, s * za), (xb, ya, s * za), (xb, TOP, s * COVE_Z), (xa, TOP, s * COVE_Z)], (0, -0.6, -s),
               "inner")
    for a, b in bays():
        if b - a < 1.6:
            continue
        mid, hw = (a + b) * 0.5, min(0.8, (b - a) * 0.5 - 0.15)
        t0, t1 = 0.12, 0.88   # the frame's share of the cove's slope

        def at(t: float) -> tuple:
            y, z = cove_at(t)
            return (y, s * (z - 0.004))
        (ya, za), (yb, zb) = at(t0), at(t1)
        m.poly([(mid - hw, ya, za), (mid + hw, ya, za), (mid + hw, yb, zb), (mid - hw, yb, zb)], (0, -0.6, -s),
               "frame")
        (ya, za), (yb, zb) = at(t0 + 0.08), at(t1 - 0.08)
        za2, zb2 = za - s * 0.002, zb - s * 0.002
        # two adverts a frame, plain blocks of muted colour (no words, no brands)
        for k, paint in enumerate(("poster", "poster_b") if (mid > 0) == (s > 0) else ("poster_c", "poster")):
            x0 = mid - hw + 0.04 + k * (hw - 0.02)
            x1 = x0 + hw - 0.06
            m.poly([(x0, ya, za2), (x1, ya, za2), (x1, yb, zb2), (x0, yb, zb2)], (0, -0.6, -s), paint)
    # padded backs over the seats, one a sitter (about half a metre), a rounded pad with a seam between each, on a dark
    # backing rail; and the grab rail over them
    prof = [(IN_Z, SEAT_H), (IN_Z - 0.05, SEAT_H + 0.005), (IN_Z - 0.09, SEAT_H + 0.04), (IN_Z - 0.105, 0.62),
            (IN_Z - 0.095, 0.74), (IN_Z - 0.07, SILL - 0.06), (IN_Z - 0.03, SILL - 0.025), (IN_Z, SILL - 0.02)]
    for a, b in bays():
        a2, b2 = a + 0.06, b - 0.06
        m.rect_z(a2 - 0.02, b2 + 0.02, SEAT_H - 0.01, SILL - 0.01, s * (IN_Z - 0.004), -s, "plinth")
        n = max(2, round((b2 - a2) / 0.5))
        for k in range(n):
            pa, pb = a2 + (b2 - a2) * k / n + 0.006, a2 + (b2 - a2) * (k + 1) / n - 0.006
            for (za, ya), (zb, yb) in zip(prof, prof[1:]):
                m.poly([(pa, ya, s * za), (pb, ya, s * za), (pb, yb, s * zb), (pa, yb, s * zb)], (0, 0.2, -s), "seat")
            for x, f in ((pa, -1), (pb, 1)):
                m.poly([(x, y, s * z) for z, y in prof], (f, 0, 0), "seat")
        m.bar((a + 0.05, RAIL_Y, s * POLE_Z), (b - 0.05, RAIL_Y, s * POLE_Z), POLE_R, "pole", sides=10)
        # the rail's brackets up into the cove
        for x in (a + 0.12, b - 0.12):
            m.bar((x, RAIL_Y, s * POLE_Z), (x, TOP - 0.02, s * (COVE_Z + 0.04)), 0.012, "pole", sides=6)
    # the poles at the door holes' edges, over the seats' front corners, floor to ceiling
    for a, b in doors:
        for x in (a - 0.09, b + 0.09):
            m.bar((x, 0.0, s * POLE_Z), (x, TOP, s * POLE_Z), POLE_R, "pole", sides=12)
            # its round feet on the floor and the ceiling
            disc(m, (x, 0.003, s * POLE_Z), POLE_R + 0.02, (0, 1, 0), "trim", 12)
            disc(m, (x, TOP - 0.003, s * POLE_Z), POLE_R + 0.02, (0, -1, 0), "trim", 12)
        # and the screen beside each door hole: a solid panel at the seat's end, round-topped
        for x, f in ((a - 0.02, -1), (b + 0.02, 1)):
            top = [(IN_Z, 0.0), (IN_Z - SEAT_D + 0.04, 0.0), (IN_Z - SEAT_D + 0.04, 1.35),
                   (IN_Z - SEAT_D + 0.10, 1.55), (IN_Z - 0.1, 1.62), (IN_Z, 1.62)]
            for xx, ff in ((x, -f), (x + f * 0.045, f)):
                m.poly([(xx, y, s * z) for z, y in top], (ff, 0, 0), "inner")
            for (za, ya), (zb, yb) in zip(top[1:], top[2:]):
                m.poly([(x, ya, s * za), (x + f * 0.045, ya, s * za), (x + f * 0.045, yb, s * zb), (x, yb, s * zb)],
                       (0, 0.3, -s), "trim")
            # on its doorway face: the passenger alarm's panel, its handle and call button, and the door's
            # open button lower down
            xp = x - f * 0.003
            m.rect_x(s * (IN_Z - 0.32), s * (IN_Z - 0.12), 1.12, 1.4, xp, -f, "frame")
            m.rect_x(s * (IN_Z - 0.29), s * (IN_Z - 0.15), 1.3, 1.36, xp - f * 0.004, -f, "yellow")
            disc(m, (xp - f * 0.004, 1.2, s * (IN_Z - 0.22)), 0.025, (-f, 0, 0), "trim", 10)
            disc(m, (xp - f * 0.004, 1.06, s * (IN_Z - 0.22)), 0.03, (-f, 0, 0), "rubber", 10)
            disc(m, (xp - f * 0.006, 1.06, s * (IN_Z - 0.22)), 0.018, (-f, 0, 0), "seat_ring", 10)


def body() -> None:
    m = Model("train_body")
    panes = Glow("train_windows", "pane")
    side(m, 1.0, panes)
    side(m, -1.0)
    # the floor: dark rubber, speckled pale and grey (a seeded scatter of flecks, the same every build)
    xs = breaks([], -IN_X, IN_X, 0.5)
    zs = breaks([-0.8, 0.0, 0.8], -IN_Z, IN_Z, 0.4)
    for xa, xb in zip(xs, xs[1:]):
        for za, zb in zip(zs, zs[1:]):
            m.rect_y(xa, xb, za, zb, 0.0, 1, "floor")
    rng = random.Random(7)
    for _ in range(int(2 * IN_X * 2 * IN_Z * FLECKS)):
        x, z = rng.uniform(-IN_X + 0.03, IN_X - 0.03), rng.uniform(-IN_Z + 0.03, IN_Z - 0.03)
        h = rng.uniform(0.008, 0.016)
        a = rng.uniform(0.0, math.pi)
        c, sn = math.cos(a) * h, math.sin(a) * h
        m.poly([(x + c, 0.002, z + sn), (x - sn, 0.002, z + c), (x - c, 0.002, z - sn), (x + sn, 0.002, z - c)],
               (0, 1, 0), "fleck" if rng.random() < 0.6 else "fleck_lo")
    # the ceiling: panels either side of two lamp strips and a vent strip down the middle
    zc = [-COVE_Z, -0.62, -0.48, -0.12, 0.12, 0.48, 0.62, COVE_Z]
    paints = ["inner", "light", "inner", "vent", "inner", "light", "inner"]
    for xa, xb in zip(xs, xs[1:]):
        for (za, zb), paint in zip(zip(zc, zc[1:]), paints):
            m.rect_y(xa, xb, za, zb, TOP, -1, paint)
    # the vent strip's slots, and the air diffusers' slots along the ceiling's edges by the cove
    for k in range(int(IN_X * 2 / 0.6)):
        x = -IN_X + 0.3 + k * 0.6
        m.rect_y(x - 0.18, x + 0.18, -0.08, 0.08, TOP - 0.003, -1, "frame")
    for k in range(int(IN_X * 2 / 0.3)):
        x = -IN_X + 0.15 + k * 0.3
        for z in (-1.0, 1.0):
            m.rect_y(x - 0.09, x + 0.09, z - 0.015, z + 0.015, TOP - 0.003, -1, "vent")
    # a speaker grille over each bay's middle, between the lamp strip and the cove: a rim round a grille of holes
    for a, b in bays():
        x = (a + b) * 0.5
        for z in (-0.84, 0.84):
            disc(m, (x, TOP - 0.003, z), 0.09, (0, -1, 0), "trim", 14)
            disc(m, (x, TOP - 0.005, z), 0.07, (0, -1, 0), "vent", 14)
            for i in range(-2, 3):
                for j in range(-2, 3):
                    if i * i + j * j <= 5:
                        disc(m, (x + i * 0.025, TOP - 0.007, z + j * 0.025), 0.007, (0, -1, 0), "frame", 4)
    # the cameras: a dark dome either end of the car over the vent strip
    for x in (-IN_X + 1.2, IN_X - 1.2):
        disc(m, (x, TOP - 0.003, 0.0), 0.085, (0, -1, 0), "trim", 12)
        dome(m, (x, TOP - 0.006, 0.0), 0.065, "mask", 12, 3)
    # over each door hole inside, in the cove over its head: the next-stop screen (dark, off) in its frame, and the
    # grab bar across the doorway's head from jamb to jamb
    for c in DOOR_SLOTS:
        for s in (-1, 1):
            def at(t: float) -> tuple:
                y, z = cove_at(t)
                return (y, s * z)
            for t0, t1, hw, paint, off in ((0.71, 0.97, 0.36, "rubber", 0.004), (0.74, 0.94, 0.32, "glass", 0.007)):
                (ya, za), (yb, zb) = at(t0), at(t1)
                za, zb = za - s * off, zb - s * off
                m.poly([(c - hw, ya, za), (c + hw, ya, za), (c + hw, yb, zb), (c - hw, yb, zb)], (0, -0.6, -s), paint)
            yb = DOOR_H - 0.08
            zb = lining_at(yb) - 0.05
            m.bar((c - DOOR_HW, yb, s * zb), (c + DOOR_HW, yb, s * zb), POLE_R, "pole", sides=10)

    def weather(p: Vector, n: Vector, c: tuple, slot: int) -> tuple:
        x, y, z = p.x, p.z, -p.y     # the game's frame
        outside = abs(z) > IN_Z + 0.02 and n.y * (-1 if z > 0 else 1) < -0.3
        if outside:
            # road dirt up the side's foot and a faint patchiness: clean paint, no streaks (they banded the white)
            low = 1.0 - wt.smooth(0.0, 0.7, y + 0.15 * (wt.fbm(p, 0.3, 3) - 0.5))
            dull = 0.12 * wt.fbm(p, 0.8, 11)
            grime = wt.mix(c, wt.scale(c, 0.55), CLEAN * min(1.0, low * 0.8 + dull))
            return grime
        if n.z > 0.7 and y < 0.05:
            # the floor: worn paler down the aisle, darker at the walls
            wear = (1.0 - wt.smooth(0.2, 1.1, abs(z))) * 0.25 * wt.fbm(p, 0.5, 13)
            return wt.mix(wt.scale(c, 0.85 + 0.3 * wt.fbm(p, 0.15, 17)), wt.scale(c, 1.5), wear)
        # inside: a little grime low on the walls, a faint yellowing up near the lamps
        low = (1.0 - wt.smooth(0.0, 0.5, y)) * 0.25
        return wt.mix(c, wt.scale(c, 0.7), low + 0.08 * wt.fbm(p, 0.5, 19))

    m.finish(weather)
    panes.finish()


# -------------------------------------------------------------------------------------------------------- the doors

def door(glazed: bool) -> None:
    """A shut pair of plug doors filling one door hole: a tall window in each leaf, black seals down the middle and
    round the edge, a footstep plate inside; their outer skin curves with the side, its foot tucked in under, its head
    leaning in as the roof begins (the owner, 2026-11-12). `glazed`: the platform side's, its windows see-through (open
    through the leaf, a reveal, their glass its own model, train_door_glass); else the far side's, dark glass."""
    m = Model("train_door_glazed" if glazed else "train_door")
    panes = Glow("train_door_glass", "pane") if glazed else None
    inset = 0.015    # the outer skin follows the side's curve (z_at) 1.5 cm in; the inside the wall's (zin) 1 cm out

    def zi(y: float) -> float:
        return zin(y) + 0.01

    w0, w1 = DOOR_WIN_Y
    rows = [0.0, 0.08, 0.19, 0.28, BILGE, *STRIPE, w0, 1.4, CANT, w1, DOOR_H]    # enough to follow the curve
    for s0, s1 in ((-DOOR_HW, -0.006), (0.006, DOOR_HW)):
        a, b = s0, s1
        wx0, wx1 = a + 0.13 if a < 0 else a + 0.09, b - 0.09 if a < 0 else b - 0.13
        xs = [a, wx0, wx1, b]
        hole = [(wx0, wx1, w0, w1)]
        grid_side(m, xs, rows, 1, hole, lambda x, y: "skirt" if y < 0.08 else row_paint(y, "body"), inset)
        ring = framed(m, wx0, wx1, w0, w1, lambda y: z_at(y) - inset, 1,
                      [(0, 0, "body"), (0.0, 0.003, "body"), (0.035, 0.01, "rubber")], None if glazed else "glass",
                      r=0.1, seg=3)
        inside = [0.0, 0.08, w0, 1.4, CANT, w1, DOOR_H]
        for xa, xb in zip(xs, xs[1:]):
            for ya, yb in zip(inside, inside[1:]):
                mx, my = (xa + xb) * 0.5, (ya + yb) * 0.5
                if not (wx0 <= mx <= wx1 and w0 <= my <= w1):
                    m.poly([(xa, ya, zi(ya)), (xb, ya, zi(ya)), (xb, yb, zi(yb)), (xa, yb, zi(yb))], (0, 0, -1),
                           "frame" if my < 0.08 else "inner")
        inner_ring = framed(m, wx0, wx1, w0, w1, zi, -1, [(0, 0, "inner"), (0.0, 0.003, "inner"),
                                                             (0.035, 0.01, "trim")], None if glazed else "glass",
                            r=0.1, seg=3)
        if panes is not None:
            bridge(m, ring, inner_ring, "rubber")
            pane(panes, ring)
        # the leaves' meeting edge: black rubber seal
        x = b if a < 0 else a
        for ya, yb in zip(rows, rows[1:]):
            m.poly([(x, ya, zi(ya)), (x, ya, z_at(ya) - inset), (x, yb, z_at(yb) - inset), (x, yb, zi(yb))],
                   (1 if a < 0 else -1, 0, 0), "rubber")
    m.rect_y(-DOOR_HW, DOOR_HW, zi(DOOR_H), z_at(DOOR_H) - inset, DOOR_H, 1, "rubber")

    def weather(p: Vector, n: Vector, c: tuple, slot: int) -> tuple:
        y = p.z
        low = 1.0 - wt.smooth(0.0, 0.6, y)
        # hand grime at the leaves' middle edges, where they are pushed apart
        hands = (1.0 - wt.smooth(0.0, 0.18, abs(p.x))) * wt.smooth(0.8, 1.2, y) * (1.0 - wt.smooth(1.4, 1.7, y))
        return wt.mix(c, wt.scale(c, 0.55), CLEAN * min(1.0, low * 0.6 + hands * 0.35 + 0.1 * wt.fbm(p, 0.4, 5)))

    m.finish(weather)
    if panes is not None:
        panes.finish()


# --------------------------------------------------------------------------------------------------------- the ends

def inset_profile(d: float) -> list:
    """The roof's outline drawn in by d at the side (the gangway's bellows under the cars' roofs), (z, y)."""
    k = (z_at(CANT) - d) / z_at(CANT)
    return [(z * k, CANT + (y - CANT) * k) for z, y in cant_profile()]


def side_cap(m: Model, x: float, f: float, s: float, d: float) -> None:
    """The cut end of a side and its half of the roof, at x facing f * x: from the outer outline in by d."""
    rows = side_rows()
    for ya, yb in zip(rows, rows[1:]):
        oa, ob = z_at(ya), z_at(yb)
        m.poly([(x, ya, s * oa), (x, yb, s * ob), (x, yb, s * (ob - d)), (x, ya, s * (oa - d))], (f, 0, 0),
               row_paint((ya + yb) * 0.5, "body"))
    out, ins = cant_profile(), inset_profile(d)
    for (za, ya), (zb, yb), (zc, yc), (zd, yd) in zip(out, out[1:], ins[1:], ins):
        m.poly([(x, ya, s * za), (x, yb, s * zb), (x, yc, s * zc), (x, yd, s * zd)], (f, 0, 0), "body")


def gangway() -> None:
    """The joint between two coupled cars: each car's end wall round a full-height portal, a grab pole each side of it,
    the gangway's folds lining the passage (pale grey inside, the black bellows showing in the gap outside), two hinged tread plates across its
    floor and a small lamp in its roof."""
    m = Model("train_gangway")
    rows = breaks([], 0.0, TOP, 0.3)
    for f in (-1, 1):
        x = f * END
        a = ClipAcross(m, ring=inner_outline())
        # the end wall either side of the portal, in panels, a trim round the portal
        for s in (-1, 1):
            zs = breaks([GANG_HW, GANG_HW + 0.06], GANG_HW, IN_Z, 0.25)
            ys = breaks([0.08, 2.2, 2.28], 0.0, TOP, 0.3)
            if s < 0:
                zs = [-z for z in reversed(zs)]

            def paint(z: float, y: float) -> str:
                if abs(z) < GANG_HW + 0.06:
                    return "trim"
                if y < 0.08:
                    return "frame"
                return "vent" if 2.2 <= y <= 2.28 else "inner"

            grid_face(a, zs, ys, x, f, [], paint)
            # an information panel on the wall
            m.rect_x(s * 0.95, s * 1.35, 1.45, 1.75, x + f * 0.003, f, "frame")
            m.rect_x(s * 0.98, s * 1.32, 1.48, 1.72, x + f * 0.005, f, "poster")
            for k in range(3):
                y = 1.53 + k * 0.06
                m.rect_x(s * 1.02, s * 1.28, y, y + 0.012, x + f * 0.006, f, "frame")
            # the grab pole beside the portal, on its brackets
            zp = s * (GANG_HW + 0.16)
            m.bar((x + f * 0.05, 0.8, zp), (x + f * 0.05, 1.8, zp), POLE_R, "pole", sides=10)
            for y in (0.8, 1.8):
                m.bar((x, y, zp), (x + f * 0.05, y, zp), 0.012, "pole", sides=6)
                disc(m, (x + f * 0.002, y, zp), 0.03, (f, 0, 0), "trim", 10)
        # the gap outside: the car ends' cut edges
        for s in (-1, 1):
            side_cap(m, x, -f, s, 0.09)
    # the bellows: folds down both sides of the passage, over it, and in the gap outside each side, rounding over the
    # passage's top corners; in rows, so the grime has the vertices to show in
    folds = 10
    rc = 0.14
    for k in range(folds):
        x0 = -END + 2 * END * k / folds
        x1 = -END + 2 * END * (k + 0.5) / folds
        x2 = -END + 2 * END * (k + 1) / folds
        for (xa, xb, da, db) in ((x0, x1, 0.0, 0.03), (x1, x2, 0.03, 0.0)):
            for s in (-1, 1):
                # inside the passage (folds stand off the joint's wall into it)
                za, zb = s * (GANG_HW + 0.035 - da), s * (GANG_HW + 0.035 - db)
                for ya, yb in zip(rows, rows[1:]):
                    yb = min(yb, TOP - rc)
                    if ya >= yb:
                        continue
                    m.poly([(xa, ya, za), (xb, ya, zb), (xb, yb, zb), (xa, yb, za)], (0, 0, -s), "gang_in")
                # outside in the gap
                rows = [0.02, 0.1, 0.19, 0.28, BILGE, SPRING, 0.95, 1.45, CANT]    # enough to follow the curve
                for ya, yb in zip(rows, rows[1:]):
                    m.poly([(xa, ya, s * (z_at(ya) - 0.09 + da)), (xb, ya, s * (z_at(ya) - 0.09 + db)),
                            (xb, yb, s * (z_at(yb) - 0.09 + db)), (xa, yb, s * (z_at(yb) - 0.09 + da))], (0, 0, s),
                           "bellows")
                # the rounded corner over the passage
                for j in range(4):
                    t0, t1 = 0.5 * math.pi * j / 4, 0.5 * math.pi * (j + 1) / 4
                    cz, cy = s * (GANG_HW + 0.035 - rc), TOP - rc

                    def on(t: float, d: float) -> tuple:
                        return (cz + s * (rc - d) * math.cos(t), cy + (rc - d) * math.sin(t))
                    (pa, qa), (pb, qb) = on(t0, da), on(t1, da)
                    (pc, qc), (pd, qd) = on(t1, db), on(t0, db)
                    m.poly([(xa, qa, pa), (xa, qb, pb), (xb, qc, pc), (xb, qd, pd)], (0, -0.5, -s), "gang_in")
            # over the passage
            ya, yb = TOP - da, TOP - db
            zr = GANG_HW + 0.035 - rc
            m.poly([(xa, ya, -zr), (xb, yb, -zr), (xb, yb, zr), (xa, ya, zr)], (0, -1, 0), "gang_in")
    # the bellows' top in the gap, under the cars' roofs and over the passage's
    ins = inset_profile(0.09)
    for s in (-1, 1):
        for (za, ya), (zb, yb) in zip(ins, ins[1:]):
            m.poly([(-END, ya, s * za), (END, ya, s * za), (END, yb, s * zb), (-END, yb, s * zb)],
                   (0, (ya + yb) * 0.5 - CANT, s * (za + zb) * 0.5), "bellows")
    # the lamp in the gangway's roof
    m.rect_y(-0.06, 0.06, -0.25, 0.25, TOP - 0.035, -1, "rubber")
    m.rect_y(-0.045, 0.045, -0.22, 0.22, TOP - 0.037, -1, "light")
    # two hinged tread plates across the floor, overlapping at the joint, their hinges and tread
    for f in (-1, 1):
        x0, x1 = sorted((f * END, -f * 0.01))
        m.rect_y(x0, x1, -GANG_HW, GANG_HW, 0.006 + (0.002 if f > 0 else 0.0), 1, "steel")
        m.rect_x(-GANG_HW, GANG_HW, 0.0, 0.008, -f * 0.01, -f, "frame")
        for k in range(4):
            xc = x0 + (x1 - x0) * (k + 0.5) / 4
            for j in range(10):
                zc = -GANG_HW + 0.06 + j * (2 * GANG_HW - 0.12) / 9 + (0.03 if k % 2 else 0.0)
                m.rect_y(xc - 0.008, xc + 0.008, zc - 0.022, zc + 0.022, 0.0085 + (0.002 if f > 0 else 0.0), 1,
                         "frame")
        for z in (-GANG_HW + 0.1, 0.0, GANG_HW - 0.1):
            m.bar((f * END, 0.012, z - 0.08), (f * END, 0.012, z + 0.08), 0.01, "steel", sides=6)

    def weather(p: Vector, n: Vector, c: tuple, slot: int) -> tuple:
        y = p.z
        low = (1.0 - wt.smooth(0.0, 0.6, y)) * 0.3
        return wt.mix(c, wt.scale(c, 0.65), CLEAN * (low + 0.15 * wt.fbm(p, 0.3, 37)))

    m.finish(weather)


class ClipAcross:
    """Across, each rectangle cut to the car's outline (face_x), drawn in by `inset`: an end's outside face under the
    round roof, inside the curved sides."""

    def __init__(self, m: "Model", inset: float = 0.0, ring: list | None = None):
        self.m = m
        self.inset = inset
        self.ring = ring

    def poly(self, pts: list, facing: tuple, paint: str) -> None:
        self.m.poly([(d, y, u) for u, y, d in pts], (facing[2], facing[1], facing[0]), paint)

    def rect_z(self, u0: float, u1: float, y0: float, y1: float, d: float, s: float, paint: str) -> None:
        face_x(self.m, u0, u1, y0, y1, d, s, paint, self.inset, self.ring)


class Across:
    """A model seen with x and z swapped, so the z-facing helpers (framed, grid_face) draw on a face across the car
    (one at depth x): their (u, y, d) is the car's (d, y, u)."""

    def __init__(self, m: Model):
        self.m = m

    def poly(self, pts: list, facing: tuple, paint: str) -> None:
        self.m.poly([(d, y, u) for u, y, d in pts], (facing[2], facing[1], facing[0]), paint)

    def rect_z(self, u0: float, u1: float, y0: float, y1: float, d: float, s: float, paint: str) -> None:
        self.m.rect_x(u0, u1, y0, y1, d, s, paint)


def end_wall(m: Model, door_open: bool = False) -> None:
    """A car's blank end seen from inside (the wall at x = 0, facing -x): panels round a shut end door with a rounded
    window, an equipment cupboard on one side and a network map's frame on the other, a vent grille along its head."""
    hw = END_DOOR_HW
    a = ClipAcross(m, ring=inner_outline())
    cup = (0.75, 1.35, 0.35, 1.75)      # the cupboard (z0, z1, y0, y1), on the +z side
    info = (-1.35, -0.8, 1.1, 1.7)      # the map frame, on the -z side
    zs = breaks([-hw - 0.06, -hw, hw, hw + 0.06, cup[0], cup[1], info[0], info[1]], -IN_Z, IN_Z, 0.2)
    ys = breaks([0.08, END_DOOR_H, END_DOOR_H + 0.06, 2.2, 2.28, cup[2], cup[3], info[2], info[3]], 0.0, TOP, 0.25)

    def wall(z: float, y: float) -> str:
        if abs(z) <= hw + 0.06 and y <= END_DOOR_H + 0.06:
            return "trim"
        if y < 0.08:
            return "frame"
        if 2.2 <= y <= 2.28:
            return "vent"
        return "inner"

    grid_face(a, zs, ys, 0.0, -1, [(-hw, hw, 0.0, END_DOOR_H), (cup[0], cup[1], cup[2], cup[3])], wall)
    # the vent grille's slats over the band
    edge = cove_at((2.27 - COVE_Y) / (TOP - COVE_Y))[1]    # the cove's edge at the grille's head
    for k in range(int(2 * IN_Z / 0.08)):
        z = -IN_Z + 0.04 + k * 0.08
        if abs(z) + 0.015 < edge:
            m.rect_x(z - 0.015, z + 0.015, 2.21, 2.27, -0.002, -1, "frame")
    # the door: a leaf set in a little, a rounded window in a rubber seal, a kick plate, hinges and its handle
    m.rect_x(-hw, hw, 0.0, END_DOOR_H, -0.002, -1, "rubber")
    d = -0.006
    zd = breaks([-hw + 0.12, hw - 0.12], -hw + 0.02, hw - 0.02, 0.2)
    yd = breaks([0.25, 0.95, 1.8], 0.0, END_DOOR_H - 0.02, 0.3)
    grid_face(a, zd, yd, d, -1, [(-hw + 0.12, hw - 0.12, 0.95, 1.8)],
              lambda z, y: "steel" if y < 0.25 else "inner_lo")
    framed(a, -hw + 0.12, hw - 0.12, 0.95, 1.8, d, -1, [(0, 0, "inner_lo"), (0.0, -0.004, "inner_lo"),
                                                        (0.03, 0.006, "rubber")], "glass", r=0.07, seg=8)
    for y in (0.3, 1.0, 1.7):
        m.box((d - 0.02, y, -hw + 0.01), (d, y + 0.08, -hw + 0.04), "steel", skip="+x")
    m.bar((d - 0.04, 0.95, hw - 0.08), (d - 0.04, 1.25, hw - 0.08), 0.014, "pole", sides=10)
    for y in (0.95, 1.25):
        m.bar((d, y, hw - 0.08), (d - 0.04, y, hw - 0.08), 0.01, "pole", sides=6)
    m.rect_x(hw - 0.11, hw - 0.05, 1.05, 1.15, d - 0.001, -1, "steel")
    # the emergency lamp over the door: a lens in a grey box
    m.box((-0.05, 2.04, -0.16), (0.0, 2.14, 0.16), "trim", skip="+x")
    m.rect_x(-0.13, 0.13, 2.06, 2.12, -0.051, -1, "lamp")
    # the grab rail up the wall beside the door
    for z in (-hw - 0.16, hw + 0.16):
        m.bar((-0.05, 0.85, z), (-0.05, 1.75, z), POLE_R, "pole", sides=10)
        for y in (0.85, 1.75):
            m.bar((0.0, y, z), (-0.05, y, z), 0.012, "pole", sides=6)
            disc(m, (-0.002, y, z), 0.03, (-1, 0, 0), "trim", 10)
    # the cupboard: a door in a frame, set back, a recessed catch and a yellow strip across it
    z0, z1, y0, y1 = cup
    for (za, zb, ya, yb) in ((z0, z1, y0, y0 + 0.03), (z0, z1, y1 - 0.03, y1), (z0, z0 + 0.03, y0, y1),
                             (z1 - 0.03, z1, y0, y1)):
        m.rect_x(za, zb, ya, yb, -0.004, -1, "trim")
    for z, f in ((z0, -1), (z1, 1)):
        m.rect_z(-0.004, 0.0, y0, y1, z, f, "trim")
    m.rect_y(-0.004, 0.0, z0, z1, y1, 1, "trim")
    m.rect_y(-0.004, 0.0, z0, z1, y0, -1, "trim")
    zc = breaks([], z0 + 0.03, z1 - 0.03, 0.2)
    yc = breaks([1.45, 1.5], y0 + 0.03, y1 - 0.03, 0.25)
    grid_face(a, zc, yc, 0.0, -1, [], lambda z, y: "yellow" if 1.45 <= y <= 1.5 else "inner_lo")
    m.rect_x(z1 - 0.15, z1 - 0.07, 0.95, 1.1, -0.001, -1, "frame")
    for k in range(5):
        y = 0.5 + k * 0.05
        m.rect_x(z0 + 0.12, z1 - 0.12, y, y + 0.02, -0.001, -1, "vent")
    # the network map's frame: a plain diagram of grey lines and dots (an invented network, no words)
    z0, z1, y0, y1 = info
    m.rect_x(z0, z1, y0, y1, -0.003, -1, "frame")
    m.rect_x(z0 + 0.02, z1 - 0.02, y0 + 0.02, y1 - 0.02, -0.005, -1, "poster")
    for k, (ya, yb) in enumerate(((1.25, 1.26), (1.4, 1.41), (1.55, 1.56))):
        m.rect_x(z0 + 0.05, z1 - 0.05, ya, yb, -0.007, -1, "frame" if k != 1 else "seam")
        for j in range(6):
            z = z0 + 0.06 + j * (z1 - z0 - 0.12) / 5
            disc(m, (-0.008, ya + 0.005, z), 0.011, (-1, 0, 0), "trim", 8)
    m.rect_x(z0 + 0.25, z0 + 0.26, 1.25, 1.56, -0.007, -1, "frame")


def end_piece(outer: bool) -> None:
    """A car's blank end: its inside wall, the cut ends of its sides; `outer` draws its outside face too (the end of a
    train standing uncoupled), with the folded-back bellows' frame, a shut end door, tail lamps and, under it, the
    underframe and coupler over its bogie's space (under_end)."""
    name = "train_end_outer" if outer else "train_end"
    m = Model(name)
    end_wall(m)
    for s in (-1, 1):
        # the side's last 15 cm, outside, on its curve: grey, rounding in to a dark seam at the very end
        rows = side_rows()
        side_strip(m, 0.0, END - 0.025, s, rows, lambda y: row_paint(y, "body"))
        side_strip(m, END - 0.025, END, s, [0.0, SKIRT, 0.19, BILGE, SPRING, 1.25, CANT],
                   lambda y: "skirt" if y < SKIRT else "rubber")
        prof = cant_profile()
        for (za, ya), (zb, yb) in zip(prof, prof[1:]):
            m.poly([(0.0, ya, s * za), (END, ya, s * za), (END, yb, s * zb), (0.0, yb, s * zb)], (0, 0.5, s), "body")
    if outer:
        x = END
        # the outside face: grey end sheet, the bellows' frame folded flat round the end door, tail lamps low
        zs = [-OUT_Z, -1.0, -0.94, -END_DOOR_HW, END_DOOR_HW, 0.94, 1.0, OUT_Z]
        ys = [0.0, 0.1, 0.2, *STRIPE, END_DOOR_H, 2.05, TOP, ROOF_TOP]
        lamps = [tuple(sorted((s * 1.17, s * 1.53))) + (0.29, 0.52) for s in (-1, 1)]
        for za, zb in zip(zs, zs[1:]):
            for ya, yb in zip(ys, ys[1:]):
                mz, my = (za + zb) * 0.5, (ya + yb) * 0.5
                if abs(mz) < END_DOOR_HW and my < END_DOOR_H:
                    paint = "inner_lo" if 0.95 < my < 1.8 else "body_lo"
                elif abs(mz) < 1.0 and 0.1 < my < 2.05 and (abs(mz) > 0.94 or my > END_DOOR_H or my < 0.2):
                    paint = "bellows"
                elif my < 0.1:
                    paint = "skirt"
                else:
                    paint = "body"
                if paint in ("body", "body_lo") and STRIPE[0] <= my <= STRIPE[1]:
                    paint = "stripe"
                lamp = [h for h in lamps if za <= h[0] and h[1] <= zb and ya <= h[2] and h[3] <= yb]
                if lamp:
                    # round the lamp's hole in the end sheet
                    z0, z1, y0, y1 = lamp[0]
                    for c in ((za, z0, ya, yb), (z1, zb, ya, yb), (z0, z1, ya, y0), (z0, z1, y1, yb)):
                        face_x(m, *c, x, 1, paint)
                else:
                    face_x(m, za, zb, ya, yb, x, 1, paint)
        m.rect_x(-END_DOOR_HW + 0.1, END_DOOR_HW - 0.1, 0.95, 1.8, x - 0.004, 1, "glass")
        # the end's white LED lamps low either side, set into the end sheet (its box ends at the sheet): a chrome-lined
        # recess, a thin running-light strip over two round lamps on its dark back
        led = Glow("train_end_leds")
        for z0, z1, y0, y1 in lamps:
            back = x - 0.014
            for z, f in ((z0, 1), (z1, -1)):
                m.rect_z(back, x, y0, y1, z, f, "steel")
            m.rect_y(back, x, z0, z1, y0, 1, "steel")
            m.rect_y(back, x, z0, z1, y1, -1, "steel")
            m.rect_x(z0, z1, y0, y1, back, 1, "rubber")
            zm, hw = (z0 + z1) * 0.5, (z1 - z0) * 0.5
            m.rect_x(zm - hw + 0.03, zm + hw - 0.03, 0.465, 0.49, back + 0.001, 1, "mask")
            led.rect_x(zm - hw + 0.04, zm + hw - 0.04, 0.47, 0.485, back + 0.002, 1, "led")
            for zc in (zm - 0.08, zm + 0.08):
                disc(m, (back + 0.001, 0.375, zc), 0.05, (1, 0, 0), "mask", 12)
                led_cluster(led, (back + 0.002, 0.375, zc), 0.022, 0.009)
        under_end(m, x)
    m.finish(None if not outer else outside_weather)
    if outer:
        led.finish()


def under_end(m: Model, x: float) -> None:
    """Under the floor at a train's end (x = END the end face, facing +x): the open space the bogie stands in
    (tools/subway/layout.py UNDER_ENDS, UNDER_D deep and UNDER_H tall over the track bed, its foot the station's): the
    floor slab's 15 cm edge over its mouth with the anticlimber's ribs, the underframe over it (its dark underside, the
    sole bars down either side and the slab's end face behind the bogie), and the coupler on its draft gear hanging in
    the mouth, its head in the end's plane, with its air hoses. The bogie itself is a block of its own (train_bogie)."""
    top, back = UNDER + UNDER_H, x - UNDER_D
    # the slab's edge over the mouth, its ribs across the middle
    zs = breaks([-1.2, 1.2], -z_at(0.0), z_at(0.0), 0.35)
    for za, zb in zip(zs, zs[1:]):
        m.rect_x(za, zb, top, -0.02, x, 1, "skirt")
        m.rect_x(za, zb, -0.02, 0.0, x, 1, "seam")
    for k in range(4):
        y = top + 0.02 + k * 0.028
        m.box((x - 0.03, y, -1.2), (x - 0.001, y + 0.013, 1.2), "steel", skip="-x")
    # the underframe's underside, the slab's end face behind the bogie
    xs = breaks([], back, x, 0.55)
    zs = breaks([-SOLE_Z, SOLE_Z], -OUT_Z, OUT_Z, 0.5)
    for xa, xb in zip(xs, xs[1:]):
        for za, zb in zip(zs, zs[1:]):
            m.rect_y(xa, xb, za, zb, top, -1, "under")
    for za, zb in zip(zs, zs[1:]):
        for ya, yb in ((UNDER, UNDER + 0.3), (UNDER + 0.3, top)):
            m.rect_x(za, zb, ya, yb, back, 1, "under")
    # the sole bars, channels down the space's sides, and a cross bearer behind the coupler
    for sz in (-1, 1):
        z0, z1 = sorted((sz * SOLE_Z, sz * (SOLE_Z + 0.16)))
        m.box((back, top - 0.2, z0), (x - 0.02, top, z1), "skirt", skip="+y")
    m.box((x - 0.95, top - 0.16, -SOLE_Z), (x - 0.82, top, SOLE_Z), "skirt", skip="+y")
    # the coupler: the draft gear's housing under the bearer, its shank out to a square head with a round face
    cy = top - 0.27
    m.box((x - 0.82, cy - 0.11, -0.2), (x - 0.4, top, 0.2), "under", skip="+y")
    revolve(m, (x, cy, 0.0), 0, [(-0.4, 0.075), (-0.33, 0.075), (-0.33, 0.06), (-0.12, 0.06), (-0.12, 0.075),
                                 (-0.09, 0.075), (-0.09, 0.0)], ["skirt", "skirt", "steel", "steel", "steel", "steel"],
            10)
    m.box((x - 0.09, cy - 0.12, -0.13), (x - 0.01, cy + 0.12, 0.13), "steel")
    disc(m, (x - 0.008, cy, 0.0), 0.1, (1, 0, 0), "trim", 14)
    revolve(m, (x - 0.007, cy, -0.05), 0, [(0.0, 0.035), (-0.04, 0.012), (-0.04, 0.0)], ["under", "under"], 8)
    m.box((x - 0.06, cy - 0.04, 0.025), (x - 0.007, cy + 0.035, 0.09), "skirt", skip="-x")
    for z in (0.06, 0.09):
        disc(m, (x - 0.006, cy + 0.07, z), 0.012, (1, 0, 0), "rubber", 6)
    # its gathering horn beside the face, the electric head under it behind its rubber flap on its arm
    m.box((x - 0.08, cy - 0.06, 0.13), (x - 0.01, cy + 0.06, 0.2), "steel", skip="-z")
    m.box((x - 0.16, cy - 0.3, -0.11), (x - 0.03, cy - 0.14, 0.11), "skirt")
    m.rect_x(-0.1, 0.1, cy - 0.29, cy - 0.15, x - 0.029, 1, "rubber")
    m.box((x - 0.3, cy - 0.2, -0.03), (x - 0.16, cy - 0.17, 0.03), "skirt")
    # the pipes and the cables in their conduits along the underside, a box of gear on the slab's end behind the bogie
    for z, r in ((-0.62, 0.022), (-0.52, 0.018), (0.55, 0.03), (0.66, 0.018)):
        m.bar((back + 0.02, top - 0.05, z), (x - 0.95, top - 0.05, z), r, "under" if r > 0.025 else "steel", sides=6)
        for xc in breaks([], back + 0.3, x - 1.0, 0.8):
            m.box((xc - 0.02, top - 0.08, z - 0.03), (xc + 0.02, top, z + 0.03), "skirt", skip="+y")
    for sz in (-1, 1):
        z0, z1 = sorted((sz * 0.35, sz * 0.8))
        m.box((back, top - 0.32, z0), (back + 0.14, top, z1), "skirt", skip="-x+y")
    # the slab's edge's bolts either side of the ribs
    for sz in (-1, 1):
        for k in range(4):
            disc(m, (x - 0.001, top + 0.075, sz * (1.28 + k * 0.1)), 0.012, (1, 0, 0), "steel", 6)
    # the air hoses either side, looped down from the bearer
    for sz in (-1, 1):
        prev = None
        for k in range(6):
            t = k / 5
            p = (x - 0.05, top - 0.04 - 0.3 * math.sin(math.pi * t), sz * (0.24 + 0.1 * t))
            if prev is not None:
                m.bar(prev, p, 0.016, "rubber", sides=6)
            prev = p


def outside_weather(p: Vector, n: Vector, c: tuple, slot: int) -> tuple:
    y = p.z
    low = 1.0 - wt.smooth(-0.3, 0.6, y + 0.15 * (wt.fbm(p, 0.3, 3) - 0.5))
    return wt.mix(c, wt.scale(c, 0.55), CLEAN * min(1.0, low * 0.7 + 0.1 * wt.fbm(p, 0.8, 11)))


def cab(open_door: bool) -> None:
    """A cab front (its track side at x = END, facing +x; the car's inside at x = 0): the tall dark glass mask with its
    rounded corners over most of the face, the centre door in it, lamp strips down its sides, headlamps low in its
    corners, the body's grey round it rounding in at the corners; the underframe under it (under_end). Inside, the cab's
    back wall with its door. `open_door`: the centre door stands open, a hole the full height to the ceiling."""
    name = "train_cab_open" if open_door else "train_cab"
    m = Model(name)
    led = Glow("train_cab_leds")
    x = END
    hw = CAB_DOOR_HW if open_door else 0.42
    corner = 0.12    # the front's corners round back into the sides over this much
    # the face round the mask: grey body
    mz, my0, my1, mr = 1.45, 0.22, 2.28, 0.32
    outline = rounded(-mz, mz, my0, my1, mr, 12)
    sq = squared(outline, mr)
    # outer frame: from the face's rectangle in to the mask's squared outline, in small cells for the grime
    face_z = OUT_Z - corner
    a = ClipAcross(m, corner)
    horns = [(s * 0.95 - 0.12, s * 0.95 + 0.12, 0.06, 0.16) for s in (-1, 1)]
    # under a shut door its recessed step; under an open one the doorway runs down to the floor
    step = (-0.36, 0.36, 0.02, 0.14) if not open_door else (-hw, hw, 0.0, my0)
    zf = breaks([-mz, mz] + [e for h in horns + [step] for e in h[:2]], -face_z, face_z, 0.15)
    grid_face(a, zf, breaks([0.06, 0.16, 0.02, 0.14, SKIRT], 0.0, my0, 0.08), x, 1, horns + [step],
              lambda z, y: "body_lo")
    grid_face(a, zf, [my1, TOP, ROOF_TOP], x, 1, [], lambda z, y: "body")
    for s in (-1, 1):
        grid_face(a, [s * mz, s * face_z] if s > 0 else [-face_z, -mz],
                  breaks([*STRIPE, BILGE, SPRING, CANT], my0, my1, 0.22), x, 1, [],
                  lambda z, y: "stripe" if STRIPE[0] <= y <= STRIPE[1] else "body")
    # the horns' grilles under the mask, and the step's tread plate under the door, each set back a little
    for z0, z1, y0, y1 in horns:
        m.rect_x(z0, z1, y0, y1, x - 0.02, 1, "under")
        for zz, f in ((z0, 1), (z1, -1)):
            m.rect_z(x - 0.02, x, y0, y1, zz, f, "skirt")
        m.rect_y(x - 0.02, x, z0, z1, y0, 1, "skirt")
        m.rect_y(x - 0.02, x, z0, z1, y1, -1, "skirt")
        for k in range(6):
            zz = z0 + 0.02 + k * (z1 - z0 - 0.04) / 5
            m.box((x - 0.02, y0 + 0.01, zz - 0.006), (x - 0.008, y1 - 0.01, zz + 0.006), "rubber", skip="-x")
    if not open_door:
        z0, z1, y0, y1 = step
        m.rect_x(z0, z1, y0, y1, x - 0.06, 1, "rubber")
        m.rect_y(x - 0.06, x, z0, z1, y0, 1, "steel")
        m.rect_y(x - 0.06, x, z0, z1, y1, -1, "skirt")
        for zz, f in ((z0, 1), (z1, -1)):
            m.rect_z(x - 0.06, x, y0, y1, zz, f, "skirt")
        for k in range(8):
            zz = z0 + 0.03 + k * (z1 - z0 - 0.06) / 7
            m.rect_y(x - 0.055, x - 0.005, zz - 0.008, zz + 0.008, y0 + 0.003, 1, "yellow")

    # the corners of the mask's square: grey to the round
    rings_sq = [(z, y) for (z, y) in sq]
    rings_rd = [p for p, _ in outline]
    n = len(rings_sq)
    for i in range(n):
        j = (i + 1) % n
        a, b, c, d = rings_sq[i], rings_sq[j], rings_rd[j], rings_rd[i]
        if abs(a[0] - d[0]) + abs(a[1] - d[1]) + abs(b[0] - c[0]) + abs(b[1] - c[1]) < 1e-6:
            continue
        m.poly([(x, a[1], a[0]), (x, b[1], b[0]), (x, c[1], c[0]), (x, d[1], d[0])], (1, 0, 0), "body")
    # the mask: a rubber lip, then the dark glass set back, the door's frame in it
    mid = [p for p, _ in rounded(-mz + 0.02, mz - 0.02, my0 + 0.02, my1 - 0.02, mr - 0.02, 12)]
    inset = rounded(-mz + 0.04, mz - 0.04, my0 + 0.04, my1 - 0.04, mr - 0.04, 12)
    for i in range(n):
        j = (i + 1) % n
        for (pa, pb, xa), (qa, qb, xb), paint in (((rings_rd[i], rings_rd[j], x), (mid[i], mid[j], x - 0.008), "body"),
                                                  ((mid[i], mid[j], x - 0.008),
                                                   (inset[i][0], inset[j][0], x - 0.03), "rubber")):
            spans = [(pa, pb, qa, qb)]
            if open_door and pa[1] < my0 + 0.05 and pb[1] < my0 + 0.05 and pa[0] * pb[0] < 0.0:
                # the lip's foot runs across the open doorway: only its two ends, either side of it
                def cut(p: tuple, q: tuple, z: float) -> tuple:
                    return (z, p[1] + (q[1] - p[1]) * (z - p[0]) / (q[0] - p[0]))
                lo, hi = (-hw, hw) if pa[0] < pb[0] else (hw, -hw)
                spans = [(pa, cut(pa, pb, lo), qa, cut(qa, qb, lo)), (cut(pa, pb, hi), pb, cut(qa, qb, hi), qb)]
            for p0, p1, q0, q1 in spans:
                m.poly([(xa, p0[1], p0[0]), (xa, p1[1], p1[0]), (xb, q1[1], q1[0]), (xb, q0[1], q0[0])], (1, 0, 0),
                       paint)
    inner = [p for p, _ in inset]
    xg = x - 0.03
    if not open_door:
        m.poly([(xg, y, z) for z, y in inner], (1, 0, 0), "mask")
    else:
        # the glass either side of the doorway, the doorway itself open
        for s in (-1, 1):
            pts = [(z, y) for z, y in inner if s * z >= hw - 1e-6]
            pts = sorted(pts, key=lambda q: math.atan2(q[1] - (my0 + my1) / 2, s * (q[0] - s * hw)))
            side_pts = [(s * hw, my0 + 0.04)] + [q for q in inner if s * q[0] > hw] + [(s * hw, my1 - 0.04)]
            m.poly([(xg, y, z) for z, y in side_pts], (1, 0, 0), "mask")
        m.rect_x(-hw, hw, my1 - 0.04, TOP, x, 1, "body")
    # the windscreen's frames in the mask: the door's edges and its window's head, dull black on the glass
    for s in (-1, 1):
        m.rect_x(s * hw, s * (hw + 0.05), my0 + 0.04, my1 - 0.04, xg + 0.003, 1, "rubber")
    if not open_door:
        m.rect_x(-hw, hw, 1.05, 1.1, xg + 0.003, 1, "rubber")
        m.rect_x(-hw + 0.1, hw - 0.1, 0.25, 1.0, xg + 0.002, 1, "glass")
        # the door's handle in its dished plate, its lock, and the hinges down its far edge
        m.rect_x(hw - 0.16, hw - 0.06, 0.82, 1.22, xg + 0.004, 1, "skirt")
        m.bar((xg + 0.017, 0.88, hw - 0.11), (xg + 0.017, 1.16, hw - 0.11), 0.01, "steel", sides=8)
        for y in (0.88, 1.16):
            m.bar((xg + 0.005, y, hw - 0.11), (xg + 0.017, y, hw - 0.11), 0.008, "steel", sides=6)
        disc(m, (xg + 0.006, 1.3, hw - 0.11), 0.02, (1, 0, 0), "steel", 10)
        for y in (0.4, 1.0, 1.7):
            m.box((xg + 0.003, y, -hw + 0.005), (xg + 0.015, y + 0.12, -hw + 0.04), "rubber", skip="-x")
        # the door's window: a paler pane where the cab's back wall shows dimly through it
        m.rect_x(-hw + 0.08, hw - 0.08, 1.16, 1.98, xg + 0.002, 1, "glass_hi")
    # the destination screen over the door (dark, off), in its frame
    m.rect_x(-0.38, 0.38, 2.02, 2.2, xg + 0.004, 1, "rubber")
    m.rect_x(-0.34, 0.34, 2.05, 2.17, xg + 0.006, 1, "glass")
    # wipers parked across the windscreens either side of the door, a reflection's pale band slanting over each
    for s in (-1, 1):
        root = (xg + 0.008, 0.62, s * (hw + 0.18))
        tip = (xg + 0.008, 1.45, s * (hw + 0.55))
        m.bar(root, tip, 0.008, "rubber", sides=6)
        # its blade along the arm's outer end, its pivot cap
        d = (tip[1] - root[1], tip[2] - root[2])
        ln = math.hypot(*d)
        u = (d[0] / ln, d[1] / ln)
        b0 = (xg + 0.012, tip[1] - u[0] * 0.55, tip[2] - u[1] * 0.55)
        b1 = (xg + 0.012, tip[1] + u[0] * 0.05, tip[2] + u[1] * 0.05)
        m.bar(b0, b1, 0.007, "rubber", sides=6)
        m.box((xg + 0.003, root[1] - 0.035, root[2] - 0.035), (xg + 0.02, root[1] + 0.035, root[2] + 0.035), "rubber",
              skip="-x")
        disc(m, (xg + 0.021, root[1], root[2]), 0.022, (1, 0, 0), "steel", 10)
        m.poly([(xg + 0.002, 1.25, s * (hw + 0.1)), (xg + 0.002, 1.55, s * (hw + 0.1)),
                (xg + 0.002, 2.05, s * (mz - 0.25)), (xg + 0.002, 1.75, s * (mz - 0.25))], (1, 0, 0), "glass_hi")
    # the lamp strips: long and narrow, curving in at the top, down each side of the mask; headlamps low; marker
    # lamps behind the glass in its top corners, white and red
    for s in (-1, 1):
        for k in range(2):
            zc = s * (1.06 - 0.08 * k)
            disc(m, (xg + 0.003, 2.12, zc), 0.028, (1, 0, 0), "rubber", 12)
            disc(m, (xg + 0.005, 2.12, zc), 0.02, (1, 0, 0), "steel", 12)
            disc(led, (xg + 0.006, 2.12, zc), 0.016, (1, 0, 0), "led", 12)
        zz = s * (mz - 0.13)
        pts = []
        for k in range(13):
            t = k / 12
            y = 0.42 + (1.95 - 0.42) * t
            dz = -s * 0.10 * (t ** 3)
            pts.append((zz + dz, y))
        for (za, ya), (zb, yb) in zip(pts, pts[1:]):
            # the strip in its housing: a dark surround, a chrome edge, the glowing lens
            for w, d, paint in ((0.05, 0.002, "rubber"), (0.037, 0.003, "steel"), (0.03, 0.004, "led")):
                (led if paint == "led" else m).poly([(xg + d, ya, za - w), (xg + d, ya, za + w), (xg + d, yb, zb + w),
                                                     (xg + d, yb, zb - w)], (1, 0, 0), paint)
        # the headlamps: two round LED lamps in a dark housing, each a chrome ring, a reflector, its black face and its
        # seven white emitters
        m.rect_x(s * (mz - 0.6), s * (mz - 0.24), 0.26, 0.40, xg + 0.003, 1, "rubber")
        for k in range(2):
            zc = s * (mz - 0.33 - 0.17 * k)
            for r, d, paint in ((0.062, 0.004, "steel"), (0.052, 0.005, "trim"), (0.044, 0.006, "mask")):
                disc(m, (xg + d, 0.33, zc), r, (1, 0, 0), paint, 16)
            led_cluster(led, (xg + 0.007, 0.33, zc))
    # the corners: the side's last 15 cm, on its curve, rounding back to the front face
    rows = side_rows()
    for s in (-1, 1):
        plan = [(0.0, 0.0)]    # (x, how far in from the side's face)
        for k in range(5):
            a = 0.5 * math.pi * k / 4
            plan.append((END - corner + corner * math.sin(a), corner - corner * math.cos(a)))
        for (xa, ia), (xb, ib) in zip(plan, plan[1:]):
            for ya, yb in zip(rows, rows[1:]):
                oa, ob = z_at(ya), z_at(yb)
                m.poly([(xa, ya, s * (oa - ia)), (xb, ya, s * (oa - ib)), (xb, yb, s * (ob - ib)),
                        (xa, yb, s * (ob - ia))], ((xa + xb) * 0.5 - (END - corner) + 0.0001, 0, s * 0.5),
                       row_paint((ya + yb) * 0.5, "body"))
        top = z_at(CANT) - corner
        for (za, ya), (zb, yb) in zip(cant_profile(), cant_profile()[1:]):
            zc_a, zc_b = min(za, top), min(zb, top)
            m.poly([(0.0, ya, s * za), (END - corner, ya, s * za), (END - corner, yb, s * zb), (0.0, yb, s * zb)],
                   (0, 0.5, s), "body")
            m.poly([(END - corner, ya, s * za), (END, ya, s * zc_a), (END, yb, s * zc_b), (END - corner, yb, s * zb)],
                   (0.5, 0.5, s), "body")
    under_end(m, x)
    # inside: the cab's back wall and its door (or the open doorway)
    if open_door:
        # the back wall round the open doorway, in panels, its vent grille along the head
        a = ClipAcross(m, ring=inner_outline())
        zs = breaks([-hw - 0.06, -hw, hw, hw + 0.06], -IN_Z, IN_Z, 0.25)
        ys = breaks([0.08, 2.12, 2.18, 2.2, 2.28], 0.0, TOP, 0.3)

        def wall(z: float, y: float) -> str:
            if abs(z) <= hw + 0.06 and y <= 2.18:
                return "trim"
            if y < 0.08:
                return "frame"
            return "vent" if 2.2 <= y <= 2.28 else "inner"

        grid_face(a, zs, ys, 0.0, -1, [(-hw, hw, 0.0, 2.12)], wall)
        for k in range(int(2 * IN_Z / 0.08)):
            z = -IN_Z + 0.04 + k * 0.08
            if hw + 0.08 < abs(z) < cove_at((2.27 - COVE_Y) / (TOP - COVE_Y))[1] - 0.015:
                m.rect_x(z - 0.015, z + 0.015, 2.21, 2.27, -0.002, -1, "frame")
        # the doorway's jambs through the cab end, and the lintel over it
        for s in (-1, 1):
            m.rect_z(0.0, x, 0.0, 2.12, s * hw, -s, "trim")
        m.rect_y(0.0, x, -hw, hw, 2.12, -1, "trim")
        m.rect_x(-hw, hw, 2.12, TOP, x - 0.001, 1, "body")
        m.rect_y(0.0, x, -hw, hw, 0.004, 1, "steel")
        m.rect_y(x - 0.05, x, -hw, hw, 0.006, 1, "yellow")
        # its two leaves folded back flat against the wall either side, each with a rounded window and a handle
        lw = hw - 0.02
        for s in (-1, 1):
            z0, z1 = sorted((s * (hw + 0.08), s * (hw + 0.08 + lw)))
            d = -0.045
            m.box((d, 0.02, z0), (-0.005, END_DOOR_H, z1), "inner_lo", skip="+x")
            zd = breaks([z0 + 0.12, z1 - 0.12], z0, z1, 0.2)
            yd = breaks([0.25, 0.95, 1.8], 0.02, END_DOOR_H, 0.3)
            grid_face(a, zd, yd, d - 0.001, -1, [(z0 + 0.12, z1 - 0.12, 0.95, 1.8)],
                      lambda z, y: "steel" if y < 0.25 else "inner_lo")
            framed(a, z0 + 0.12, z1 - 0.12, 0.95, 1.8, d - 0.001, -1, [(0, 0, "inner_lo"), (0.0, -0.004, "inner_lo"),
                                                                       (0.03, 0.006, "rubber")], "glass", r=0.07,
                   seg=5)
            zh = z0 + 0.07 if s > 0 else z1 - 0.07
            m.bar((d - 0.04, 0.95, zh), (d - 0.04, 1.25, zh), 0.014, "pole", sides=10)
            for y in (0.95, 1.25):
                m.bar((d - 0.001, y, zh), (d - 0.04, y, zh), 0.01, "pole", sides=6)
            # the leaf's catch holding it back, on the wall above it
            m.box((-0.03, END_DOOR_H + 0.01, (z0 + z1) * 0.5 - 0.04), (-0.002, END_DOOR_H + 0.07, (z0 + z1) * 0.5 + 0.04),
                  "steel", skip="+x")
    else:
        end_wall(m)
    m.finish(outside_weather)
    if not open_door:
        led.finish()


# -------------------------------------------------------------------------------------------------------- the seats

def seat(name: str, length: float, cushions: int) -> None:
    """A run of seat cushions on a dark plinth, its block's size (length x SEAT_D deep x SEAT_H high), the same front
    and back (it is fitted either way round; its padded back is the car's wall). The moquette's pattern of rings."""
    m = Model(name)
    hl, hd = length * 0.5, SEAT_D * 0.5
    m.box((-hl + 0.02, 0.0, -hd + 0.07), (hl - 0.02, 0.30, hd - 0.07), "plinth", skip="-y")
    gap = 0.012
    w = (length - gap * (cushions - 1)) / cushions
    prof = [(-hd, 0.30), (-hd, 0.40), (-hd + 0.03, SEAT_H), (hd - 0.03, SEAT_H), (hd, 0.40), (hd, 0.30)]
    for k in range(cushions):
        a = -hl + k * (w + gap)
        b = a + w
        for (za, ya), (zb, yb) in zip(prof, prof[1:]):
            mz = (za + zb) * 0.5
            m.poly([(a, ya, za), (b, ya, za), (b, yb, zb), (a, yb, zb)], (0, (ya + yb) * 0.5 - 0.3, mz), "seat")
        m.poly([(a, 0.30, -hd), (b, 0.30, -hd), (b, 0.30, hd), (a, 0.30, hd)], (0, -1, 0), "seat")
        for x, f in ((a, -1), (b, 1)):
            m.poly([(x, y, z) for z, y in prof], (f, 0, 0), "seat")
        # the moquette's rings: a few small squares on the top, light and dark
        for i in range(5):
            for j in range(3):
                cx = a + w * (0.1 + 0.2 * i) + 0.04 * ((j % 2) - 0.5)
                cz = -hd + 0.08 + 0.145 * j
                paint = "seat_ring" if (i + 2 * j + k) % 4 == 0 else "seat_dot"
                rr = 0.022 if paint == "seat_ring" else 0.014
                m.rect_y(cx - rr, cx + rr, cz - rr, cz + rr, SEAT_H + 0.002, 1, paint)

    def weather(p: Vector, n: Vector, c: tuple, slot: int) -> tuple:
        return wt.mix(c, wt.scale(c, 0.7), 0.25 * wt.fbm(p, 0.25, 31) + 0.15 * max(0.0, n.z))

    m.finish(weather)


# ---------------------------------------------------------------------------------------------------- the tool cart

def revolve(m: Model, c: tuple, axis: int, profile: list, paints: list, n: int) -> None:
    """A round part turned about a line through c along the game's x, y or z (`axis` 0, 1 or 2): `profile` is (along,
    radius) points, its outside on the left going along it (radius up a face at its start, along its rim, down at its
    end); band k between points k and k + 1 painted paints[k]. A radius of 0 closes it to a point. A point of each ring
    stands at -90 degrees (straight down about x or z), so a wheel's lowest point is on its circle."""
    u, v = [i for i in range(3) if i != axis]

    def at(along: float, r: float, a: float) -> tuple:
        p = list(c)
        p[axis] += along
        p[u] += r * math.cos(a)
        p[v] += r * math.sin(a)
        return tuple(p)

    for (wa, ra), (wb, rb), paint in zip(profile, profile[1:], paints):
        for k in range(n):
            a0, a1 = 2 * math.pi * k / n - 0.5 * math.pi, 2 * math.pi * (k + 1) / n - 0.5 * math.pi
            am = (a0 + a1) * 0.5
            pts = [at(wa, ra, a0), at(wa, ra, a1), at(wb, rb, a1), at(wb, rb, a0)]
            if ra < 1e-6:
                pts = pts[1:]
            elif rb < 1e-6:
                pts = pts[:3]
            f = [0.0, 0.0, 0.0]
            f[axis] = -(rb - ra)
            f[u] = (wb - wa) * math.cos(am)
            f[v] = (wb - wa) * math.sin(am)
            m.poly(pts, tuple(f), paint)


def coil(m: Model, c: tuple, r: float, wire: float, y0: float, y1: float, turns: float, paint: str) -> None:
    """A coil spring standing up at c (x, z) from y0 to y1, its wire square in section."""
    steps = max(4, round(turns * 8))
    prev = None
    for k in range(steps + 1):
        a = 2 * math.pi * turns * k / steps
        p = (c[0] + r * math.cos(a), y0 + wire + (y1 - y0 - 2 * wire) * k / steps, c[1] + r * math.sin(a))
        if prev is not None:
            m.bar(prev, p, wire, paint, sides=4)
        prev = p


def bogie() -> None:
    """A motor bogie under a train's end, filling its block's box over the rails (x +-1.35 along the track, y from its
    flanges' foot 0.11 to the car's underside 0.75, z +-1.2 across; the track bed at y 0, the rails' top at 0.14, their
    middles at z +-0.75): two axles 1.9 m apart, each with its wheels on the rails (their flanges inside them), its
    axle boxes outside and two coil springs on each box's arms up to the side frames; the side frames, dropped in the
    middle where an air spring stands on each up to the car; two transoms across, a motor and gearbox on each axle and a
    tread brake at each wheel. The same turned a half turn about up, as FIT may lay it. Greys, dirty low down."""
    m = Model("train_bogie")
    ay, r_tread, r_flange = 0.14 + 0.28, 0.28, 0.31
    # each wheel's profile (out from the track's middle, radius): its inner hub, the flange inside the rail, the
    # coned tread on it, its rim, the dished web and the outer hub round the axle
    wheel = [(0.665, 0.09), (0.665, 0.19), (0.69, 0.23), (0.69, r_flange), (0.712, r_flange), (0.72, r_tread),
             (0.83, r_tread - 0.008), (0.83, 0.25), (0.8, 0.21), (0.8, 0.14), (0.845, 0.1)]
    paints = ["under", "skirt", "skirt", "steel", "steel", "steel", "skirt", "skirt", "skirt", "under"]
    for ax in (-0.95, 0.95):
        for sz in (-1, 1):
            revolve(m, (ax, ay, 0.0), 2, [(sz * w, r) for w, r in wheel], paints, 14)
        # the axle between them, its box outside each wheel: a round housing with its end cover, arms either side
        mk.cylinder(m.b, B(ax, ay, -0.665), B(ax, ay, 0.665), 0.085, "under", sides=10, caps=False)
        for sz in (-1, 1):
            revolve(m, (ax, ay, 0.0), 2, [(sz * w, r) for w, r in
                                          [(0.85, 0.13), (1.04, 0.13), (1.04, 0.0)]], ["skirt", "steel"], 8)
            z0, z1 = sorted((sz * 0.89, sz * 1.01))
            m.box((ax - 0.29, ay - 0.01, z0), (ax + 0.29, ay + 0.05, z1), "skirt")
            for dx in (-0.21, 0.21):
                coil(m, (ax + dx, sz * 0.95), 0.06, 0.016, ay + 0.05, 0.62, 1.5, "steel")
    # the side frames: deep over the axle boxes and springs, dropped in the middle under the air springs
    stations = [(1.35, 0.58, 0.70), (1.2, 0.62, 0.74), (0.7, 0.62, 0.74), (0.58, 0.52, 0.74), (0.45, 0.36, 0.6)]
    stations = stations + [(-x, lo, hi) for x, lo, hi in reversed(stations)]
    for sz in (-1, 1):
        za, zb = sz * 0.9, sz * 1.1
        for (xa, la, ha), (xb, lb, hb) in zip(stations, stations[1:]):
            for z in (za, zb):
                m.poly([(xa, la, z), (xb, lb, z), (xb, hb, z), (xa, ha, z)], (0, 0, z - sz), "skirt")
            m.poly([(xa, ha, za), (xb, hb, za), (xb, hb, zb), (xa, ha, zb)], (0, 1, 0), "skirt")
            m.poly([(xa, la, za), (xb, lb, za), (xb, lb, zb), (xa, la, zb)], (0, -1, 0), "under")
        for x, lo, hi in (stations[0], stations[-1]):
            m.rect_x(za, zb, lo, hi, x, x, "skirt")
        # an air spring on the frame's middle up to the car, its rubber bellows in two lobes
        revolve(m, (0.0, 0.6, sz * 1.0), 1, [(0.0, 0.0), (0.0, 0.16), (0.025, 0.195), (0.06, 0.2), (0.085, 0.18),
                                             (0.11, 0.2), (0.135, 0.17), (0.15, 0.17), (0.15, 0.0)],
                ["steel", "rubber", "rubber", "rubber", "rubber", "rubber", "steel", "steel"], 10)
        # a damper outside the frame beside it
        dx = sz * 0.55
        mk.cylinder(m.b, B(dx, 0.45, sz * 1.15), B(dx, 0.6, sz * 1.15), 0.04, "under", sides=8, caps=False)
        mk.cylinder(m.b, B(dx, 0.6, sz * 1.15), B(dx, 0.73, sz * 1.15), 0.016, "steel", sides=6, caps=False)
    # the transoms across between the frames
    for x in (-0.3, 0.3):
        m.box((x - 0.07, 0.38, -0.9), (x + 0.07, 0.52, 0.9), "under", skip="-z+z")
    # each axle's motor beside it on the transom, its gearbox on the axle; the pairs turned about the middle
    for sx in (-1, 1):
        mx = sx * 0.55
        za, zb = (-0.45, 0.3) if sx > 0 else (-0.3, 0.45)
        revolve(m, (mx, ay, 0.0), 2, [(za, 0.0), (za, 0.15), (za + 0.04, 0.17), (zb - 0.04, 0.17), (zb, 0.15),
                                      (zb, 0.0)], ["under", "skirt", "skirt", "skirt", "under"], 10)
        gz0, gz1 = sorted((sx * 0.42, sx * 0.58))
        m.box((sx * 0.95 - 0.23, 0.3, gz0), (sx * 0.95 + 0.15, 0.58, gz1), "skirt")
    # a tread brake at each wheel: its block on the tread, the cylinder behind it, hung from the frame
    for ax in (-0.95, 0.95):
        for sz in (-1, 1):
            f = -1 if ax > 0 else 1
            bx = ax + f * (r_tread + 0.005)
            x0, x1 = sorted((bx, bx + f * 0.05))
            z0, z1 = sorted((sz * 0.72, sz * 0.83))
            m.box((x0, ay - 0.08, z0), (x1, ay + 0.08, z1), "under")
            mk.cylinder(m.b, B(bx + f * 0.05, ay + 0.04, sz * 0.78), B(bx + f * 0.2, ay + 0.04, sz * 0.78), 0.06,
                        "skirt", sides=8, caps=False)
            z0, z1 = sorted((sz * 0.8, sz * 0.9))
            x0, x1 = sorted((bx + f * 0.1, bx + f * 0.18))
            m.box((x0, ay + 0.08, z0), (x1, 0.62, z1), "skirt")
    m.finish(bogie_weather)


def bogie_weather(p: Vector, n: Vector, c: tuple, slot: int) -> tuple:
    """Brake dust and track dirt: darkest low down, streaked, the wheels' treads left bright."""
    y = p.z
    low = 1.0 - wt.smooth(0.1, 0.75, y + 0.1 * (wt.fbm(p, 0.25, 5) - 0.5))
    return wt.mix(c, wt.scale(c, 0.6), min(1.0, low * 0.6 + 0.15 * wt.fbm(p, 0.5, 13)))


def tool_cart() -> None:
    """A steel workshop trolley, worn grey: four castors under a frame of four corner posts, a lower tray with a tool
    box and a coil of cable on it, a drawer unit on the middle deck beside an open bay, a top tray with tools in it,
    a pegboard standing up its back with tools hung on it, and a push handle at one end. Its block's box: 1.5 m long
    (x), 1.7 m high, 1.2 m deep (z, its front the -z face's mirror: +z)."""
    m = Model("tool_cart")
    hl, hd = 0.75, 0.6
    post = 0.035
    xa, xb = -hl + 0.12, hl             # the frame, the handle's end left free at -x; it fills its box
    za, zb = -hd, hd
    # castors: a swivel fork and a wheel at each corner
    for x in (xa + 0.08, xb - 0.08):
        for z in (za + 0.08, zb - 0.08):
            m.box((x - 0.035, 0.07, z - 0.03), (x + 0.035, 0.16, z + 0.03), "castor", skip="-y")
            pts = [(x - 0.07 * math.cos(a), 0.07 + 0.07 * math.sin(a), z) for a in
                   [2 * math.pi * k / 14 for k in range(14)]]
            for dz in (-0.022, 0.022):
                m.poly([(p[0], p[1], p[2] + dz) for p in pts], (0, 0, dz), "castor")
                disc(m, (x, 0.07, z + dz * 1.05), 0.03, (0, 0, dz), "steel", 10)
            for k in range(14):
                p, q = pts[k], pts[(k + 1) % 14]
                mx, my = (p[0] + q[0]) * 0.5 - x, (p[1] + q[1]) * 0.5 - 0.07
                m.poly([(p[0], p[1], z - 0.022), (q[0], q[1], z - 0.022), (q[0], q[1], z + 0.022),
                        (p[0], p[1], z + 0.022)], (mx, my, 0), "castor")
    # corner posts and three trays (each a shallow lipped box)
    for x in (xa, xb - post):
        for z in (za, zb - post):
            m.box((x, 0.16, z), (x + post, 1.12, z + post), "cart", skip="-y")
    for y, lip in ((0.22, 0.05), (0.66, 0.04), (1.08, 0.05)):
        m.box((xa, y, za), (xb, y + 0.025, zb), "cart_lo")
        for z, f in ((za, -1), (zb, 1)):
            m.rect_z(xa, xb, y, y + lip, z, f, "cart")
        for x, f in ((xa, -1), (xb, 1)):
            m.rect_x(za, zb, y, y + lip, x, f, "cart")
    # the push handle at the -x end: two arms and a rubber grip
    for z in (za + 0.15, zb - 0.15):
        m.bar((xa, 0.95, z), (-hl + 0.02, 1.0, z), 0.014, "cart", sides=8)
    m.bar((-hl + 0.02, 1.0, za + 0.13), (-hl + 0.02, 1.0, zb - 0.13), 0.02, "castor", sides=12)
    # the drawer unit on the middle deck, the +x half: four drawers with pulls
    dx0, dx1, dy0, dy1 = 0.05, xb - 0.01, 0.685, 1.07
    m.box((dx0, dy0, za + 0.02), (dx1, dy1, zb - 0.02), "cart_lo", skip="-y")
    for k in range(4):
        y0 = dy0 + 0.01 + k * (dy1 - dy0 - 0.02) / 4
        y1 = y0 + (dy1 - dy0 - 0.02) / 4 - 0.008
        m.rect_z(dx0 + 0.02, dx1 - 0.02, y0, y1, zb - 0.017, 1, "cart")
        m.box(((dx0 + dx1) * 0.5 - 0.1, (y0 + y1) * 0.5 - 0.008, zb - 0.017), ((dx0 + dx1) * 0.5 + 0.1,
              (y0 + y1) * 0.5 + 0.008, zb - 0.003), "steel", skip="-z")
    # the lower tray's tool box and coil of cable
    m.box((xa + 0.08, 0.245, za + 0.1), (xa + 0.6, 0.47, za + 0.45), "tape", skip="-y")
    m.box((xa + 0.08, 0.47, za + 0.25), (xa + 0.6, 0.5, za + 0.3), "castor", skip="-y")
    coil = [(0.0, 0.17), (0.07, 0.17), (0.07, 0.07), (0.0, 0.07)]
    m.b.tube([(0.0, 0.2), (0.08, 0.2)], [(0.0, 0.09), (0.08, 0.09)], m.b.mat("cable"), segments=12,
             centre=B(0.25, 0.245, 0.15), axis="z")
    del coil
    # the top tray's tools: a drill case, a socket box, a hammer, a spanner
    m.box((xa + 0.1, 1.105, za + 0.1), (xa + 0.55, 1.22, za + 0.45), "castor", skip="-y")
    m.box((0.1, 1.105, 0.05), (0.5, 1.15, 0.3), "tool", skip="-y")
    m.bar((-0.1, 1.12, 0.3), (0.25, 1.12, 0.38), 0.014, "wood", sides=6)
    m.box((0.22, 1.105, 0.34), (0.3, 1.165, 0.43), "tool")
    # the pegboard up the back (-z), on two uprights, with tools hung on it
    pz = za + 0.02
    for x in (xa + 0.02, xb - 0.06):
        m.box((x, 1.1, pz), (x + 0.04, 1.7, pz + 0.04), "cart", skip="-y")
    m.box((xa + 0.02, 1.15, pz + 0.04), (xb - 0.02, 1.66, pz + 0.055), "peg")
    for k in range(7):
        x = xa + 0.12 + k * 0.17
        length = 0.18 + 0.08 * ((k * 5) % 3)
        paint = "wood" if k % 3 == 1 else "tool"
        m.box((x - 0.012, 1.58 - length, pz + 0.055), (x + 0.012, 1.58, pz + 0.075), paint, skip="-z")
        m.box((x - 0.025, 1.58 - length - 0.04, pz + 0.055), (x + 0.025, 1.58 - length, pz + 0.08), "tool",
              skip="-z")
    m.box((xb - 0.3, 1.25, pz + 0.055), (xb - 0.12, 1.4, pz + 0.12), "tape", skip="-z")
    # the pegboard's holes between the tools
    for i in range(14):
        for j in range(6):
            x, y = xa + 0.07 + i * 0.085, 1.2 + j * 0.075
            m.rect_z(x - 0.006, x + 0.006, y - 0.006, y + 0.006, pz + 0.0555, 1, "castor")
    # the middle deck's open bay: a row of spray cans and a folded rag
    for k in range(3):
        cx, cz = xa + 0.12 + k * 0.09, zb - 0.16
        mk.cylinder(m.b, B(cx, 0.685, cz), B(cx, 0.88, cz), 0.032, "tool" if k != 1 else "tape", sides=10)
        mk.cylinder(m.b, B(cx, 0.88, cz), B(cx, 0.92, cz), 0.02, "castor", sides=8)
    m.box((xa + 0.1, 0.685, za + 0.12), (xa + 0.42, 0.72, za + 0.4), "peg", skip="-y")
    # the tool box's catches and handle
    for x in (xa + 0.18, xa + 0.5):
        m.box((x - 0.02, 0.4, za + 0.08), (x + 0.02, 0.44, za + 0.1), "steel", skip="+z")
    # a hard hat on the top tray, its brim round it
    dome(m, (0.38, 1.105, -0.2), 0.13, "tape", 12, 4, up=1.0)
    for k in range(12):
        a, b = 2 * math.pi * k / 12, 2 * math.pi * (k + 1) / 12
        m.poly([(0.38 + 0.13 * math.cos(a), 1.105, -0.2 + 0.13 * math.sin(a)),
                (0.38 + 0.13 * math.cos(b), 1.105, -0.2 + 0.13 * math.sin(b)),
                (0.38 + 0.17 * math.cos(b), 1.11, -0.2 + 0.15 * math.sin(b)),
                (0.38 + 0.17 * math.cos(a), 1.11, -0.2 + 0.15 * math.sin(a))], (0, 1, 0), "tape")

    def weather(p: Vector, n: Vector, c: tuple, slot: int) -> tuple:
        # chipped, oily grey: darker low and on the deck tops' edges, a few bright scuffs
        y = p.z
        low = (1.0 - wt.smooth(0.1, 0.8, y)) * 0.35
        scuff = wt.smooth(0.78, 0.9, wt.fbm(p, 0.08, 23)) * 0.4
        col = wt.mix(c, wt.scale(c, 0.6), low + 0.15 * wt.fbm(p, 0.2, 29))
        return wt.mix(col, wt.scale(c, 1.35), scuff)

    m.finish(weather)


def lights() -> None:
    """Half the ceiling's two lamp strips (x 0 to the car's end), drawn glowing (TrainView's lamp material) just under
    the body's own; TrainView lays it twice a car, the second turned about, so each half can flicker on its own."""
    m = Model("train_lights")
    xs = breaks([], 0.0, IN_X - 0.05, 2.5)
    for za, zb in ((-0.62, -0.48), (0.48, 0.62)):
        for xa, xb in zip(xs, xs[1:]):
            m.rect_y(xa + 0.02, xb - 0.02, za + 0.015, zb - 0.015, TOP - 0.004, -1, "light")
    m.finish()


def main() -> None:
    body()
    lights()
    door(False)
    door(True)
    gangway()
    end_piece(False)
    end_piece(True)
    cab(False)
    cab(True)
    seat("train_seat", 2.0, 3)
    seat("train_seat_short", 1.25, 2)
    tool_cart()
    bogie()


main()
