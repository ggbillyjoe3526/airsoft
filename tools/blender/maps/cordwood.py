"""Woodland's cordwood stack and sawn board stack (WG2, model 13): assets/models/props/cordwood.glb, _b and _c, three
2 m sections of split firewood that the game lays along each stack, one a cell at random, stretched to its height (the
Woodpile's 12 m wall, the camp gate screens, the Log stacks, the log piles); each top ragged and its rows waving up and
down, a stack built by hand; and boards.glb, B site's stack of sawn boards (6.4 x 1 x 2 m).

From the owner's photos (references/maps/woodland/13-cordwood-stack-and-board-stack): split logs stacked lengthwise in
rows, their sawn ends to the faces: pale wedges and quarters with bark on their round side, a few small rounds, the
rows uneven so the face is ragged and the gaps between them dark; split pieces lying across the top. The boards are
stacked in layers held apart by stickers (thin battens) so the air gets through, on bearers off the ground.

The cordwood section fills its grid cell (PropDressConfig.grid_cells): its pieces' ends standing out of the faces by
0.3 to 5 cm (WS1: each a solid end, its sides barked or split back to the core, its face tilted a little) over a dark
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
ARC = 5                 # the bark arc's segments on a split piece (a pie slice of its log)
ARC_SPAN = (75.0, 100.0)  # a split piece's angle at the log's heart (degrees): 1.2 to 1.5 times as wide as deep
RIM = 0.07              # a ring of bark on a sawn end: this share of the way in from its edge (about 4 % across)
ARC_BAND = 0.08         # a split piece's band of bark inside its arc: this share of the way to its middle (thin)
CHECK = 0.35            # the share of split pieces with a drying crack from the heart toward the bark
GAP = 0.005             # m between neighbouring ends along a row: a hairline, as the photo's stack packed tight
EDGE = 0.03             # the share of its row's height kept clear above and below each piece
SHOWS = 0.035           # an end standing out less than this (m) shows no side
UNDER_SEEN = 1.6        # a piece's end's sides facing down are left out below this (m): the eye looks down on them
ROWS = 8
ROUND = 0.08            # the share of pieces that are small rounds (most are split, as in the photo)
ROUND_RAD = (0.06, 0.08)  # a round's radius (m): about 0.6 of a split piece across
ROUND_SIDES = 12        # a small round's sides
HEART = 0.05            # the share of four-sided pieces split from a log's heart, no bark
ASIDE = 0.12            # the share of wedges that may lie on their side
LEAN = 14.0             # degrees a split piece may lie off square, as stacked by hand
FULL = 25               # pieces in a row that no longer fit under the top: the face is full
LAY_STEP = 0.015        # m between the places along the face a piece is tried
LOOSE = 6               # split pieces lying across the top
# the sawn ends' colours, each piece its own, from fresh pale to warm tan to weathered grey (as in the photo)
# (warm as the photo's, each just off Beta orange's hue: woodkit.off_team)
END_PAINTS = {"EndPale": 0xE4CC94, "EndLight": 0xDCC07C, "EndWarm": 0xD4B66A, "EndDeep": 0xC8AA5A, "EndTan": 0xBC9E4E,
              "EndOld": 0xCCB688, "EndGrey": 0xA69F8E}
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
    # each face's pieces (lay_face), stretched to the ragged top above them
    for side in (1.0, -1.0):
        out = Vector((0.0, side, 0.0))
        for kind, poly in lay_face(r, half_x, HEIGHT - 0.05):
            outline = [(px, side * core, max(0.01, pz * top_at(px) / (HEIGHT - 0.05))) for px, pz in poly]
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


def lay_face(r: object, half_x: float, top: float) -> list:
    """A face's pieces' ends (kind, outline as (x, z) points) from x = -half_x to half_x and z = 0 to `top`, stacked as
    by hand: each piece in turn set where its middle rests lowest (a split piece tried point up, point down and, now
    and then, on its side, so the wedges lock together), on the ground or on the pieces under it, GAP above them;
    until FULL pieces in a row no longer fit under the top. No outline crosses another (asserted)."""
    h = top / ROWS
    pieces = []
    misses = 0
    while misses < FULL:
        best = None
        for kind, poly in piece_outline(r, h):
            wide = max(px for px, _ in poly)
            mid = _centroid_z(poly)
            steps = int((2.0 * half_x - 2.0 * GAP - wide) / LAY_STEP)
            for i in range(steps + 1):
                x = -half_x + GAP + i * LAY_STEP
                z = rest(pieces, poly, x, wide)
                if best is None or z + mid < best[0] - 1e-6:
                    best = (z + mid, kind, [(px + x, pz + z) for px, pz in poly])
        if max(pz for _, pz in best[2]) > top - h * EDGE:
            misses += 1
            continue
        misses = 0
        assert not any(overlaps(best[2], q) for _, q in pieces), "a piece's end crosses another"
        pieces.append((best[1], best[2]))
    return pieces


def _centroid_z(poly: list) -> float:
    """The height of a convex outline's middle (its area's centroid)."""
    area = zsum = 0.0
    for i in range(len(poly)):
        (x0, z0), (x1, z1) = poly[i], poly[(i + 1) % len(poly)]
        cross = x0 * z1 - x1 * z0
        area += cross
        zsum += (z0 + z1) * cross
    return zsum / (3.0 * area)


def rest(pieces: list, poly: list, x: float, wide: float) -> float:
    """How high `poly` (its foot at z = 0, its left at x = 0), moved to `x`, comes to rest dropped onto `pieces`: GAP
    above every piece under it (the outlines are convex, so the closest they come is over one of their corners), or
    on the ground, EDGE of a row up."""
    z = GAP
    for _, q in pieces:
        qtop = max(pz for _, pz in q)
        if qtop + GAP <= z:
            continue
        qlo, qhi = min(px for px, _ in q), max(px for px, _ in q)
        if qhi <= x or qlo >= x + wide:
            continue
        for xs in [px for px, _ in q if x <= px <= x + wide] + [px + x for px, _ in poly if qlo <= px + x <= qhi]:
            a, c = _vspan(q, xs), _vspan(poly, xs - x)
            if a and c:
                z = max(z, a[1] - c[0] + GAP)
    return z


def _vspan(poly: list, x: float) -> tuple:
    """A convex outline's lowest and highest z at `x`, or () where it doesn't reach."""
    zs = []
    for i in range(len(poly)):
        (x0, z0), (x1, z1) = poly[i], poly[(i + 1) % len(poly)]
        if min(x0, x1) - 1e-7 <= x <= max(x0, x1) + 1e-7:  # with a little slack, for rounding at the corners
            zs += [z0, z1] if abs(x1 - x0) < 1e-9 else [z0 + (z1 - z0) * min(1.0, max(0.0, (x - x0) / (x1 - x0)))]
    return (min(zs), max(zs)) if zs else ()


def piece_outline(r: object, h: float) -> list:
    """One piece's end for rows `h` m high, as the ways it may lie (kind, outline from x = 0 and z = 0): a wedge (a pie
    slice of its log, its point at the log's heart first, then its bark arc) point up or point down, now and then on its
    side either way, each up to LEAN off square; a small round; or a four-sided piece split from a log's heart."""
    room = h * (1.0 - 2.0 * EDGE)
    roll = r.random()
    if roll < ROUND:
        rad = min(room * 0.5, r.uniform(*ROUND_RAD))
        turn = r.uniform(0.0, math.pi)
        m = ROUND_SIDES
        ring = [(rad * math.cos(turn + 2 * math.pi * i / m), rad * math.sin(turn + 2 * math.pi * i / m))
                for i in range(m)]
        return [("round", _from_zero(ring))]
    if roll < ROUND + HEART:
        w = room * r.uniform(0.5, 0.7)
        tall = room * r.uniform(0.8, 1.0)
        return [("heart", _from_zero([(r.uniform(0.0, 0.2) * w, 0.0), (w, r.uniform(0.0, 0.2) * tall),
                                      (w * r.uniform(0.8, 1.0), tall), (0.0, tall * r.uniform(0.8, 1.0))]))]
    span = math.radians(r.uniform(*ARC_SPAN))
    rad = room * r.uniform(0.86, 1.0)
    ways = (0.0, math.pi) + ((0.5 * math.pi, 1.5 * math.pi) if r.random() < ASIDE else ())
    out = []
    for turn in ways:
        # the arc's middle points away from the heart: down (point up), up (point down) or to either side
        mid = turn - 0.5 * math.pi + math.radians(r.uniform(-LEAN, LEAN))
        arc = [(rad * math.cos(mid - span / 2 + span * i / ARC), rad * math.sin(mid - span / 2 + span * i / ARC))
               for i in range(ARC + 1)]
        out.append(("wedge", _from_zero([(0.0, 0.0)] + arc)))
    return out


def _from_zero(poly: list) -> list:
    """`poly` moved so its leftmost point lies at x = 0 and its lowest at z = 0."""
    lo, foot = min(px for px, _ in poly), min(pz for _, pz in poly)
    return [(px - lo, pz - foot) for px, pz in poly]


def overlaps(a: list, c: list, margin: float = 0.0) -> bool:
    """Whether two convex outlines cross or come within `margin` m (separating axes), allowing for rounding."""
    for poly in (a, c):
        for i in range(len(poly)):
            (x0, v0), (x1, v1) = poly[i], poly[(i + 1) % len(poly)]
            nx, nv = v1 - v0, x0 - x1
            pa = [nx * px + nv * pv for px, pv in a]
            pc = [nx * px + nv * pv for px, pv in c]
            m = margin * math.hypot(nx, nv) - 1e-9
            if max(pa) + m <= min(pc) or max(pc) + m <= min(pa):
                return False
    return True


def piece_end(b: hs.Builder, outline: list, depth: float, out: Vector, end_mat: str, kind: str, tilt: tuple,
              check: bool = False) -> None:
    """A piece's end standing `depth` proud of the stack's dark core (outline: points on the core's face), as a solid
    log end (WS1, the owner: the stacks read flat): its sides run back to the core where it stands out enough to show
    them (SHOWS), and its end face is sawn a little off square (`tilt`: how much further out it stands per metre across
    and up the face). A "wedge" (a split piece, a pie slice of its log, as most in the photos: its outline the heart's
    point, then its bark arc) has its arc barked and a band of dark bark (ARC_BAND) inside it on its face, its split
    sides pale, and with `check` a drying crack from its heart; a "round" a thin ring of bark round its sawn face; a
    "heart" (split from the log's middle) no bark at all."""
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
