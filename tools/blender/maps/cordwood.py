"""Woodland's cordwood stack and sawn board stack (WG2, model 13): assets/models/props/cordwood.glb, _b and _c, three
2 m sections of split firewood that the game lays along each stack, one a cell at random, stretched to its height (the
Woodpile's 12 m wall, the camp gate screens, the Log stacks, the log piles); each top ragged and its rows waving up and
down, a stack built by hand; and boards.glb, B site's stack of sawn boards (6.4 x 1 x 2 m).

From the owner's photos (references/maps/woodland/13-cordwood-stack-and-board-stack): split logs stacked lengthwise in
rows, their sawn ends to the faces: pale wedges and quarters with bark on their round side, a few small rounds, the
rows uneven so the face is ragged and the gaps between them dark; split pieces lying across the top. The boards are
stacked in layers held apart by stickers (thin battens) so the air gets through, on bearers off the ground.

The cordwood section fills its grid cell (PropDressConfig.grid_cells): its pieces' ends standing out of the faces by
3 to 20 cm (WS1: each a solid end, its sides barked or split back to the core, its face tilted a little) over a dark
core, so nothing is seen through a stack that stops a BB. The boards fill their block's box
with their ground line at y = 0 (PropDressConfig.Lay.GROUND). Budgets 3,200 a section (WS1; was 1,200) and 1,500 the
boards (/mnt/project-files/art/woodland-model-list.md). Plain vertex colours, no texture.

    python -I tools/blender/maps/cordwood.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402
import woodkit as wk  # noqa: E402
import hardsurface as hs  # noqa: E402
from mathutils import Vector  # noqa: E402

CORD_BUDGET = 3200      # WS1: solid, rounded ends packed tight (was 1,200, flat ends)
# the sections, each its own ragged top and pieces; the game picks one a cell (PropDressConfig.variants)
SECTIONS = (("cordwood", 1300), ("cordwood_b", 1301), ("cordwood_c", 1304))
BOARD_BUDGET = 1500
# a cordwood section (m): its length along the stack, its depth across it (the faces at +-DEPTH/2), its height
SECTION, DEPTH, HEIGHT = 2.0, 1.0, 1.8
TOPS = 7                # points along the section where its ragged top is set
SAG = 0.45              # how far under the cell's top the stack's top dips at most
PROUD = (0.003, 0.05)   # how far a piece's end stands out of the core: the face's relief (WS1: solid ends, near flush)
PROUD_MODE = 0.015      # most stand out about this far, a few flush or 5 cm out, as a stack built by hand
TILT = 0.08             # an end face sawn off square: up to this much further out per metre across or up it
SIDES = (14, 16)        # a round's sides, so it reads round
ARC = 6                 # the bark arc's segments on a split piece (a pie slice of its log)
ARC_SPAN = (75.0, 100.0)  # a split piece's angle at the log's heart (degrees): 1.2 to 1.5 times as wide as deep
RIM = 0.07              # a ring of bark on a sawn end: this share of the way in from its edge (about 4 % across)
ARC_BAND = 0.16         # a split piece's band of bark inside its arc: this share of the way to its middle (7 % deep)
CHECK = 0.35            # the share of split pieces with a drying crack from the heart toward the bark
PACK = (1.75, 1.95)     # a piece's size for its cell (its radius over half the cell): packed tight, few gaps
SHOWS = 0.035           # an end standing out less than this (m) shows no side
UNDER_SEEN = 1.6        # a piece's end's sides facing down are left out below this (m): the eye looks down on them
ROWS = 10
ACROSS = 10             # pieces along a row, on average
ROUND = 0.12            # the share of pieces that are rounds (most are split, as in the photos)
BAND = 0.75             # the share of pieces showing a band of bark on their round side
LOOSE = 6               # split pieces lying across the top
# the sawn ends' colours, each piece its own, from fresh pale to warm tan to weathered grey (as in the photo)
# (warm as the photo's, each just off Beta orange's hue: woodkit.off_team)
END_PAINTS = {"EndPale": 0xDBC693, "EndLight": 0xD6BC81, "EndWarm": 0xCCB270, "EndDeep": 0xC2A765, "EndTan": 0xB8A26A,
              "EndOld": 0xB29E72, "EndGrey": 0xA69F8E}
END_MATS = tuple(END_PAINTS)
END_WEIGHTS = (2, 3, 3, 2, 2, 2, 1)
# the boards (m)
BOARDS_LEN, BOARDS_DEPTH, BOARDS_TOP = 6.4, 1.0, 2.0
BOARD_T, STICKER_T = 0.07, 0.03
SHEET = 0.05            # the corrugated sheet weighing the top down
RIBS = 14
BOARDS_ACROSS = 7
STICKERS = 6
BEARER = 0.1


def cordwood(seed: int) -> object:
    hs.reset()
    wk.paint_all()
    mk.paints({"Gap": 0x5C5545})  # a dull mid brown (any warmer reads near Beta orange): the shade between the pieces
    assert wk.off_team(0x5C5545), "Gap reads as a team"
    for name, colour in END_PAINTS.items():
        assert wk.off_team(colour), "%s #%06x reads as a team" % (name, colour)
    mk.paints(END_PAINTS)
    r = wk.rng(seed)
    b = hs.Builder("Cordwood", [])
    half_x, half_y = SECTION * 0.5, DEPTH * 0.5
    core = half_y - PROUD[1]
    # the stack's top along the section: ragged, a piece or two lower here and there, as a stack built by hand
    xs = [-half_x + SECTION * k / (TOPS - 1) for k in range(TOPS)]
    tops = [HEIGHT - 0.05 - SAG * max(0.0, r.uniform(-0.3, 1.0)) for _ in xs]
    tops[r.randrange(TOPS)] = HEIGHT - 0.05  # its highest point meets the cell's top

    def top_at(x: float) -> float:
        t = (x + half_x) / SECTION * (TOPS - 1)
        k = min(TOPS - 2, int(t))
        return tops[k] + (tops[k + 1] - tops[k]) * (t - k)

    # the dark core: what shows between the pieces
    for k in range(TOPS - 1):
        x0, x1 = xs[k], xs[k + 1]
        for y, s in ((-core, -1.0), (core, 1.0)):
            q = wk.verts(b, [(x0, y, 0.0), (x1, y, 0.0), (x1, y, tops[k + 1]), (x0, y, tops[k])])
            wk.face(b, q, "Gap", Vector((0, s, 0)))
        q = wk.verts(b, [(x0, -core, tops[k]), (x1, -core, tops[k + 1]), (x1, core, tops[k + 1]), (x0, core, tops[k])])
        wk.face(b, q, "Gap", Vector((0, 0, 1)))
    # its ends, seen at a stack's end: each row the bark sides of the two pieces lying across the stack, rounded
    # (a ridge along each), split where the front piece meets the back one, each standing out by its own amount
    for x, s, t in ((xs[0], -1.0, tops[0]), (xs[-1], 1.0, tops[-1])):
        for k in range(ROWS):
            z0, z1 = t * k / ROWS, t * (k + 1) / ROWS
            split = r.uniform(-0.15, 0.15)
            base = x - s * 0.02  # the ends stand just inside the section's length, so the sections meet closely
            for y0, y1 in ((-core, split - 0.015), (split + 0.015, core)):
                bulge = base + s * r.uniform(0.0, 0.008)
                ridge = bulge + s * 0.012
                zm = (z0 + z1) * 0.5 + r.uniform(-0.02, 0.02)
                mat = ("Bark", "BarkDark", "BarkFurrow", "Bark")[r.randrange(4)]
                wk.face(b, wk.verts(b, [(bulge, y0, z0 + 0.012), (bulge, y1, z0 + 0.012), (ridge, y1, zm),
                                        (ridge, y0, zm)]), mat, Vector((s, 0, -0.6)))
                wk.face(b, wk.verts(b, [(ridge, y0, zm), (ridge, y1, zm), (bulge, y1, z1 - 0.012),
                                        (bulge, y0, z1 - 0.012)]), mat, Vector((s, 0, 0.6)))
            q = wk.verts(b, [(base, -core, z0), (base, core, z0), (base, core, z1), (base, -core, z1)])
            wk.face(b, q, "BarkDark", Vector((s, 0, 0)))
    # the rows of pieces' ends on each face, in rows following the ragged top, each row's pieces their own sizes and
    # shapes: split wedges (most, as in the photos) turned every way, their round side bowed and barked, and rounds
    for side in (1.0, -1.0):
        out = Vector((0.0, side, 0.0))
        for k in range(ROWS):
            x = -half_x + r.uniform(0.0, 0.08)
            while x < half_x - 0.04:
                w = SECTION / ACROSS * r.uniform(0.75, 1.3)
                cx = min(x + w * 0.5, half_x - w * 0.4)
                row = top_at(cx) / ROWS
                cz = row * (k + 0.5) + r.uniform(-0.15, 0.15) * row
                rad = min(w, row) * 0.5 * r.uniform(*PACK)
                x += w
                kind = "round" if r.random() < ROUND else ("wedge" if r.random() < BAND else "heart")
                if kind == "round":
                    m = r.choice(SIDES)
                    turn = r.uniform(0.0, math.pi)
                    poly = [(cx + rad * math.cos(turn + 2 * math.pi * i / m),
                             cz + rad * math.sin(turn + 2 * math.pi * i / m)) for i in range(m)]
                elif kind == "wedge":
                    # a pie slice of its log: its point at the log's heart, two split sides, its bark round an arc
                    t = r.uniform(0.0, 2.0 * math.pi)
                    span = math.radians(r.uniform(*ARC_SPAN))
                    big = rad * 1.45
                    hx, hz = cx - math.cos(t) * big * 0.6, cz - math.sin(t) * big * 0.6
                    poly = [(hx, hz)] + [(hx + big * math.cos(t - span / 2 + span * i / ARC),
                                          hz + big * math.sin(t - span / 2 + span * i / ARC)) for i in range(ARC + 1)]
                else:
                    # from the log's middle: four split sides, no bark
                    t = r.uniform(0.0, 2.0 * math.pi)
                    poly = [(cx + rad * r.uniform(0.75, 1.0) * math.cos(t + math.pi * 0.5 * i + r.uniform(-0.25, 0.25)),
                             cz + rad * r.uniform(0.75, 1.0) * math.sin(t + math.pi * 0.5 * i + r.uniform(-0.25, 0.25)))
                            for i in range(4)]
                # the bottom row rests on the ground, never under it (or out over the grass)
                outline = [(px, side * core, max(pz, 0.01)) for px, pz in poly]
                end_mat = r.choices(END_MATS, END_WEIGHTS)[0]
                piece_end(b, outline, r.triangular(PROUD[0], PROUD[1], PROUD_MODE), out, end_mat, kind,
                          (r.uniform(-TILT, TILT), r.uniform(-TILT, TILT)), r.random() < CHECK)
    # split pieces lying across the top here and there, on the ragged top
    for k in range(LOOSE):
        x = -half_x + SECTION * (k + r.uniform(0.2, 0.8)) / LOOSE
        w = SECTION / LOOSE * r.uniform(0.25, 0.4)
        wk.ridge(b, x, w, top_at(x) - 0.01, r.uniform(0.04, 0.08), core, ("Bark", "Split", "BarkDark")[k % 3])
    ob = b.build()
    wk.finish(ob, 30.0)
    wk.fit_box(ob, (-half_x, -half_y, 0.0), (half_x, half_y, HEIGHT))
    return ob


def piece_end(b: hs.Builder, outline: list, depth: float, out: Vector, end_mat: str, kind: str, tilt: tuple,
              check: bool = False) -> None:
    """A piece's end standing `depth` proud of the stack's dark core (outline: points on the core's face), as a solid
    log end (WS1, the owner: the stacks read flat): its sides run back to the core where it stands out enough to show
    them (SHOWS), and its end face is sawn a little off square (`tilt`: how much further out it stands per metre across
    and up the face). A "wedge" (a split piece, a pie slice of its log, as most in the photos: its outline the heart's
    point, then its bark arc) has its arc barked and a band of dark bark (ARC_BAND) inside it on its face, its split
    sides pale, and with `check` a drying crack from its heart; a "round" a thin ring of bark round its sawn face and a
    darker growth ring; a "heart" (split from the log's middle) no bark at all."""
    n = len(outline)
    c0 = sum((Vector(p) for p in outline), Vector()) / n
    base = [Vector(p) for p in outline]
    bark = range(1, n - 1) if kind == "wedge" else range(0)  # the arc's edges

    def proud(p: Vector) -> Vector:
        d = depth + tilt[0] * (p.x - c0.x) + tilt[1] * (p.z - c0.z)
        return p + out * max(0.003, d)

    front = [proud(p) for p in base]
    front_ids = wk.verts(b, front)
    c = sum(front, Vector()) / n
    if depth >= SHOWS:
        back_ids = wk.verts(b, base)
        for i in range(n):
            j = (i + 1) % n
            side_out = ((base[i] + base[j]) * 0.5 - c0).normalized()
            if side_out.z < -0.5 and c0.z < UNDER_SEEN:
                continue  # a side facing down under eye height is never seen
            if kind == "round" or i in bark:
                mat = "Bark"
            else:
                mat = "Split" if kind == "wedge" else "Heart"
            wk.face(b, [back_ids[i], back_ids[j], front_ids[j], front_ids[i]], mat, side_out)
    if kind == "heart":
        wk.face(b, front_ids, end_mat, out)
        return
    if kind == "round":
        wk.face(b, front_ids, "Bark", out)
        inner = [p.lerp(c, RIM) for p in front]
        wk.face(b, wk.verts(b, [p + out * 0.004 for p in inner]), end_mat, out)
        # a darker growth ring round its heart
        k = 8
        ring = [c.lerp(inner[i * len(inner) // k], 0.45) + out * 0.006 for i in range(k)]
        wk.face(b, wk.verts(b, ring), "Ring", out)
        return
    wk.face(b, front_ids, "BarkDark", out)
    inner = [p if i == 0 else p.lerp(c, ARC_BAND) for i, p in enumerate(front)]
    wk.face(b, wk.verts(b, [p + out * 0.004 for p in inner]), end_mat, out)
    if check:
        # a drying crack from the heart toward the bark, narrow and dark
        tip = inner[0]
        mid = inner[len(inner) // 2]
        side = (mid - tip).cross(out).normalized() * (mid - tip).length * 0.03
        wk.face(b, wk.verts(b, [tip.lerp(mid, 0.12) + out * 0.006, tip.lerp(mid, 0.8) + side + out * 0.006,
                                tip.lerp(mid, 0.8) - side + out * 0.006]), "Gap", out)


def boards() -> object:
    hs.reset()
    wk.paint_all()
    mk.paints({"Gap": 0x2E2924, "Sheet": 0x8C8A96})
    r = wk.rng(1350)
    b = hs.Builder("Boards", [])
    hx, hy = BOARDS_LEN * 0.5, BOARDS_DEPTH * 0.5
    # three bearers on the ground under it, across the stack
    for x in (-hx + 0.4, 0.0, hx - 0.4):
        b.box((x - BEARER * 0.5, -hy, 0.0), (x + BEARER * 0.5, hy, BEARER), "Bark")
    # the dark core behind the layers and stickers
    b.prism([(-hx + 0.08, -hy + 0.04), (hx - 0.08, -hy + 0.04), (hx - 0.08, hy - 0.04), (-hx + 0.08, hy - 0.04)], "z",
            BEARER, BOARDS_TOP - SHEET, "Gap")
    z = BEARER
    layer = 0
    width = BOARDS_DEPTH / BOARDS_ACROSS
    stack_top = BOARDS_TOP - SHEET
    while z + BOARD_T <= stack_top + 1e-6:
        for i in range(BOARDS_ACROSS):
            y0 = -hy + i * width + 0.004
            y1 = y0 + width - 0.008
            x0 = -hx + r.uniform(0.0, 0.06)
            x1 = hx - r.uniform(0.0, 0.06)
            board(b, x0, x1, y0, y1, z, z + BOARD_T, i == 0, i == BOARDS_ACROSS - 1,
                  z + BOARD_T + STICKER_T + BOARD_T > stack_top, r.choice(("Split", "Weathered", "Weathered")))
        z += BOARD_T
        if z + STICKER_T + BOARD_T <= stack_top + 1e-6:
            for k in range(STICKERS):
                x = -hx + 0.25 + (BOARDS_LEN - 0.5) * k / (STICKERS - 1)
                for side in (-1.0, 1.0):
                    wk.face(b, wk.verts(b, [(x - 0.022, side * hy * 0.995, z), (x + 0.022, side * hy * 0.995, z),
                                            (x + 0.022, side * hy * 0.995, z + STICKER_T),
                                            (x - 0.022, side * hy * 0.995, z + STICKER_T)]), "Weathered",
                            Vector((0, side, 0)))
            z += STICKER_T
        layer += 1
    # a corrugated sheet laid over the top against the rain, its ribs across the stack
    sheet(b, -hx + 0.02, hx - 0.02, -hy, hy, z, BOARDS_TOP)
    ob = b.build()
    wk.finish(ob, 30.0)
    wk.fit_box(ob, (-hx, -hy, 0.0), (hx, hy, BOARDS_TOP))
    return ob


def sheet(b: hs.Builder, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> None:
    """A corrugated steel sheet from z0 to z1 (its ribs' tops), its ribs running along y, its edges folded down."""
    pts = []
    for k in range(RIBS * 2 + 1):
        x = x0 + (x1 - x0) * k / (RIBS * 2)
        pts.append((x, z1 if k % 2 else z0 + (z1 - z0) * 0.35))
    for k in range(len(pts) - 1):
        (xa, za), (xb, zb) = pts[k], pts[k + 1]
        wk.face(b, wk.verts(b, [(xa, y0, za), (xb, y0, zb), (xb, y1, zb), (xa, y1, za)]), "Sheet",
                Vector((-(zb - za), 0, xb - xa)))
    for y, s in ((y0, -1.0), (y1, 1.0)):
        ring = [(x, y, z) for x, z in pts] + [(x1, y, z0), (x0, y, z0)]
        wk.face(b, wk.verts(b, ring), "Sheet", Vector((0, s, 0)))


def board(b: hs.Builder, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, front: bool, back: bool,
          top: bool, mat: str) -> None:
    """One sawn board's faces you can see: its two sawn ends, its outer side on a face of the stack, its top on the
    top layer."""
    for x, s in ((x0, -1.0), (x1, 1.0)):
        wk.face(b, wk.verts(b, [(x, y0, z0), (x, y1, z0), (x, y1, z1), (x, y0, z1)]), "Cut", Vector((s, 0, 0)))
    if front:
        wk.face(b, wk.verts(b, [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)]), mat, Vector((0, -1, 0)))
    if back:
        wk.face(b, wk.verts(b, [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)]), mat, Vector((0, 1, 0)))
    if top:
        wk.face(b, wk.verts(b, [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]), mat, Vector((0, 0, 1)))


def main() -> None:
    for name, seed in SECTIONS:
        ob = cordwood(seed)
        mk.report(ob, name, CORD_BUDGET)
        print("  wrote", mk.export_prop(ob, name))
    ob = boards()
    mk.report(ob, "boards", BOARD_BUDGET)
    print("  wrote", mk.export_prop(ob, "boards"))


if __name__ == "__main__":
    main()
