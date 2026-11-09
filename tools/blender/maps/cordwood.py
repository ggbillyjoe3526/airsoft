"""Woodland's cordwood stack and sawn board stack (WG2, model 13): assets/models/props/cordwood.glb, _b and _c, three
2 m sections of split firewood that the game lays along each stack, one a cell at random, stretched to its height (the
Woodpile's 12 m wall, the camp gate screens, the Log stacks, the log piles); each top ragged and its rows waving up and
down, a stack built by hand; and boards.glb, B site's stack of sawn boards (6.4 x 1 x 2 m).

From the owner's photos (references/maps/woodland/13-cordwood-stack-and-board-stack): split logs stacked lengthwise in
rows, their sawn ends to the faces: pale wedges and quarters with bark on their round side, a few small rounds, the
rows uneven so the face is ragged and the gaps between them dark; split pieces lying across the top. The boards are
stacked in layers held apart by stickers (thin battens) so the air gets through, on bearers off the ground.

The cordwood section fills its grid cell (PropDressConfig.grid_cells): its pieces' ends standing out of the faces by
up to 10 cm over a dark core, so nothing is seen through a stack that stops a BB. The boards fill their block's box
with their ground line at y = 0 (PropDressConfig.Lay.GROUND). Budgets 1,200 a section and 1,500 the boards
(/mnt/project-files/art/woodland-model-list.md). Plain vertex colours, no texture.

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

CORD_BUDGET = 1200
# the sections, each its own ragged top and pieces; the game picks one a cell (PropDressConfig.variants)
SECTIONS = (("cordwood", 1300), ("cordwood_b", 1301), ("cordwood_c", 1304))
BOARD_BUDGET = 1500
# a cordwood section (m): its length along the stack, its depth across it (the faces at +-DEPTH/2), its height
SECTION, DEPTH, HEIGHT = 2.0, 1.0, 1.8
TOPS = 7                # points along the section where its ragged top is set
SAG = 0.45              # how far under the cell's top the stack's top dips at most
PROUD = (0.015, 0.1)    # how far a piece's end stands out of the core: the face's relief
GAP = 0.1               # a piece's share shrunk from its neighbours: the dark gaps between them
ROWS = 12
ACROSS = 9              # pieces' bases along a row (each row is a strip of wedges, up and down in turn)
BAND = 0.5              # the share of pieces showing a band of bark on their round side
SIDED = 0.0             # the share of pieces whose short sides are drawn (the rest show the core's dark behind)
LOOSE = 6               # split pieces lying across the top
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
    mk.paints({"Gap": 0x47433C})  # dull: a warm brown here reads near Beta orange
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
            base = x - s * 0.085  # the ends stand inside the section's length, so the sections still meet
            for y0, y1 in ((-core, split - 0.015), (split + 0.015, core)):
                bulge = base + s * r.uniform(0.0, 0.05)
                ridge = bulge + s * 0.035
                zm = (z0 + z1) * 0.5 + r.uniform(-0.02, 0.02)
                mat = ("Bark", "BarkDark", "BarkFurrow", "Bark")[r.randrange(4)]
                wk.face(b, wk.verts(b, [(bulge, y0, z0 + 0.012), (bulge, y1, z0 + 0.012), (ridge, y1, zm),
                                        (ridge, y0, zm)]), mat, Vector((s, 0, -0.6)))
                wk.face(b, wk.verts(b, [(ridge, y0, zm), (ridge, y1, zm), (bulge, y1, z1 - 0.012),
                                        (bulge, y0, z1 - 0.012)]), mat, Vector((s, 0, 0.6)))
            q = wk.verts(b, [(base, -core, z0), (base, core, z0), (base, core, z1), (base, -core, z1)])
            wk.face(b, q, "Gap", Vector((s, 0, 0)))
    # the rows of pieces' ends on each face, following the ragged top so they wave up and down along the stack
    for side in (1.0, -1.0):
        out = Vector((0.0, side, 0.0))
        shares = [0.0] + [(k + r.uniform(-0.2, 0.2)) / ROWS for k in range(1, ROWS)] + [1.0]
        for k in range(ROWS):
            for poly in row_pieces(r, half_x, lambda x, a=shares[k]: top_at(x) * a,
                                   lambda x, a=shares[k + 1]: top_at(x) * a):
                cx = sum(p[0] for p in poly) / len(poly)
                cz = sum(p[1] for p in poly) / len(poly)
                outline = [(cx + (x - cx) * (1.0 - GAP), side * core, cz + (z - cz) * (1.0 - GAP)) for x, z in poly]
                # the bark on the piece's longest edge: a wedge's round side
                n = len(outline)
                longest = max(range(n), key=lambda e: (Vector(outline[(e + 1) % n]) - Vector(outline[e])).length)
                end_mat = r.choices(("Cut", "Heart", "Ring", "Split"), (3, 5, 2, 2))[0]
                wk.split_end(b, outline, r.uniform(*PROUD), out, end_mat, longest, r.random() < SIDED,
                             r.random() < BAND)
    # split pieces lying across the top here and there, on the ragged top
    for k in range(LOOSE):
        x = -half_x + SECTION * (k + r.uniform(0.2, 0.8)) / LOOSE
        w = SECTION / LOOSE * r.uniform(0.25, 0.4)
        wk.ridge(b, x, w, top_at(x) - 0.01, r.uniform(0.04, 0.08), core, ("Bark", "Split", "BarkDark")[k % 3])
    ob = b.build()
    wk.finish(ob, 30.0)
    wk.fit_box(ob, (-half_x, -half_y, 0.0), (half_x, half_y, HEIGHT))
    return ob


def row_pieces(r, half_x: float, z0, z1) -> list:
    """A row of split pieces' ends (outlines of (x, z)) between the heights z0(x) and z1(x): wedges pointing up and
    down in turn, their bases spaced unevenly, a few neighbours merged into a quarter or half round."""
    n = ACROSS
    bottom = [-half_x + 2.0 * half_x * (k + r.uniform(-0.2, 0.2)) / n for k in range(n + 1)]
    bottom[0], bottom[-1] = -half_x, half_x
    top = [-half_x] + [(bottom[i] + bottom[i + 1]) * 0.5 + r.uniform(-0.04, 0.04) for i in range(n)] + [half_x]
    lo = [(x, z0(x)) for x in bottom]
    hi = [(x, z1(x)) for x in top]
    tris = [[lo[0], hi[1], hi[0]]]
    for i in range(n):
        tris.append([lo[i], lo[i + 1], hi[i + 1]])
        tris.append([hi[i + 1], lo[i + 1], hi[i + 2]])
    out = []
    i = 0
    while i < len(tris):
        if i + 1 < len(tris) and r.random() < 0.3:
            pts = []
            for p in tris[i] + tris[i + 1]:
                if all(abs(p[0] - q[0]) + abs(p[1] - q[1]) > 1e-6 for q in pts):
                    pts.append(p)
            out.append(sorted_outline(pts))
            i += 2
        else:
            out.append(tris[i])
            i += 1
    return [p for p in out if len(p) >= 3]


def sorted_outline(pts: list) -> list:
    """Points (x, z) wound round their middle."""
    cx = sum(p[0] for p in pts) / len(pts)
    cz = sum(p[1] for p in pts) / len(pts)
    return sorted(pts, key=lambda p: math.atan2(p[1] - cz, p[0] - cx))


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
