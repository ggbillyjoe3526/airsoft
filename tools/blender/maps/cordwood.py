"""Woodland's cordwood stack and sawn board stack (WG2, model 13): assets/models/props/cordwood.glb, _b and _c, three
2 m sections of split firewood that the game lays along each stack, one a cell at random, stretched to its height (the
Woodpile's 12 m wall, the camp gate screens, the Log stacks, the log piles); each top ragged and its rows waving up and
down, a stack built by hand; and boards.glb, B site's stack of sawn boards (6.4 x 1 x 2 m).

From the owner's photos (references/maps/woodland/13-cordwood-stack-and-board-stack): split logs stacked lengthwise in
rows, their sawn ends to the faces: pale wedges and quarters with bark on their round side, a few small rounds, the
rows uneven so the face is ragged and the gaps between them dark; split pieces lying across the top. The boards are
stacked in layers held apart by stickers (thin battens) so the air gets through, on bearers off the ground.

RM2 (the owner, 2026-11-15: "improve the stacks of wood logs"): the pieces mixed as the photos' are, not one size of
quarter laid in rows like scales: wedges from narrow to wide (55 to 125 degrees at the heart), a tenth of them half
logs, more small rounds, a third free to lie on their side and up to 24 degrees off square, each 0.68 to 1 of a row
high, so the rows break up; no square heart pieces; each bark arc in about 34 degree steps; warmer tans and a brown
among the sawn ends, a darker heart at most wedges' points; the stack's ends built from the end pieces' own round bark
sides, each from the face its sawn end shows on to past the middle, meeting the next, so no dark panel shows between
them; the stack's top the top course's logs lying front to back, rounded, each its own bark, and a piece standing over
it barked behind. The same budget.

The cordwood section fills its grid cell (PropDressConfig.grid_cells): its pieces' ends standing out of the faces by
0.3 to 5 cm (WS1: each a solid end, its sides barked or split back to the core, its face tilted a little) over a dark
core, so nothing is seen through a stack that stops a BB. The boards fill their block's box
with their ground line at y = 0 (PropDressConfig.Lay.GROUND). Budgets 3,200 a section (WS1; was 1,200) and 1,500 the
boards (/mnt/project-files/art/woodland-model-list.md). Plain vertex colours, no texture.

    python -I tools/blender/maps/cordwood.py <repo root>
"""

import math
import os
import random
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
PROUD_MODE = 0.015     # most stand out about this far, a few flush or 5 cm out, as a stack built by hand
TILT = 0.14             # an end face sawn off square: up to this much further out per metre across or up it
ARC_STEP = 34.0         # degrees of bark arc a segment (RM2: 24, then 28 to make room for the hearts)
ARC = 5                 # the bark arc's segments on a split piece (a pie slice of its log), the widest 6
ARC_SPAN = (55.0, 125.0)  # a split piece's angle at the log's heart (degrees): 1.2 to 1.5 times as wide as deep
RIM = 0.07              # a ring of bark on a sawn end: this share of the way in from its edge (about 4 % across)
BARK_RIM = 0.1          # a split piece's rim of bark inside its arc: this share of its radius
RIM_MIN = 0.07          # m: a split piece smaller than this (tip to arc) shows no rim of bark (RM2: pays for the top)
CHECKS = (74, 18, 6, 2)  # how often a split piece shows no, one, two or three drying cracks from its heart
GAP = 0.005             # m between neighbouring ends along a row: a hairline, as the photo's stack packed tight
EDGE = 0.03             # the share of its row's height kept clear above and below each piece
SHOWS = 0.035           # an end standing out less than this (m) shows no side
UNDER_SEEN = 1.6        # a piece's end's sides facing down are left out below this (m): the eye looks down on them
ROWS = 8
ROUND = 0.07            # the share of pieces that are small rounds (a few, as in the photo)
ROUND_RAD = (0.045, 0.09)  # a round's radius (m): about 0.6 of a split piece across
ROUND_SIDES = 12        # a small round's sides
HEART = 0.0             # the share of four-sided pieces split from a log's heart, no bark (RM2: none; read as
# square chunks)
ASIDE = 0.3             # the share of wedges that may lie on their side
LEAN = 24.0             # degrees a split piece may lie off square, as stacked by hand
FULL = 25               # pieces in a row that no longer fit under the top: the face is full
LAY_STEP = 0.015        # m between the places along the face a piece is tried
FILL_TRIES = 3000        # places tried for the smaller pieces pushed into the holes left
FILL_SIZES = (0.7, 0.5, 0.36, 0.28)  # their sizes for a row's height, the biggest that fits first
FILL_ARC = 4            # their bark arcs' segments
CORE_COLS = 30          # places along the section where the core's top follows the pieces
END_IN = 0.08           # m in from each end where the core's top is read from the pieces
CROWN_SINK = 0.02       # m the core's top lies under the highest piece's top
EDGE_CUT = 0.35         # how much of a piece's width may run past the section's end, cut off there (RM2)
HALF = 0.1              # the share of split pieces that are half logs (RM2: the photos' mix)
HALF_SPAN = (150.0, 175.0)
END_SET = 0.06          # m the stack's end stands inside the section's end; its logs' sides bulge out of it up to this
END_NEAR = 0.1          # m from the end a piece's sawn end may stand back and still show its side there
END_ARC = 5             # a log's side's segments round (27 degrees each: round, drawn smooth under SMOOTH)
END_PROUD = 0.003       # m past the core an end log's side starts, out with the face's sawn ends
END_TOUCH = 0.004       # m each end log's side runs past the line where it meets the next
LOOSE = 0               # split pieces lying across the top (RM2: none; they read as planks along the top edge)
LOOSE_IN = 0.2          # m they keep in from the section's ends, never over the stack's end
SMOOTH = 34.0           # degrees: faces meeting at less than this are drawn smooth
# the sawn ends' colours, each piece its own, from fresh pale to warm tan to weathered grey (as in the photo)
# (warm as the photo's, each just off Beta orange's hue: woodkit.off_team)
# (RM2: deeper, more of the deep tans and a brown, as the owner's photo's warm brown at eye height; their hue can go
# no nearer orange, so they are darker, not more orange)
END_PAINTS = {"EndPale": 0xC4AF7F, "EndLight": 0xBDA56B, "EndWarm": 0xB69D5B, "EndDeep": 0xAC924D, "EndTan": 0xA28843,
              "EndBrown": 0x927B3C, "EndOld": 0xAF9D75, "Rim": 0x5F543C,
              "EndHeart": 0x7C6838}
END_MATS = tuple(k for k in END_PAINTS if k not in ("Rim", "EndHeart"))  # Rim: a split piece's bark, a warm brown;
# EndHeart: its heart, darker (RM2, the photo's pieces)
HEART_SHARE = 0.45      # how far out from a wedge's point its dark heart reaches
TOP_LOG = 0.03          # m the top course's logs rise in their middle over the creases between them (RM2)
TOP_BARK = ("Bark", "Bark", "BarkDark", "BarkGrey")  # the top's logs' bark, each its own
END_WEIGHTS = (1, 2, 3, 3, 3, 2, 1)
# the boards (m)
BOARDS_LEN, BOARDS_DEPTH, BOARDS_TOP = 6.4, 1.0, 2.0
BOARD_T, STICKER_T = 0.07, 0.03
SHEET = 0.05            # the corrugated sheet weighing the top down
RIBS = 14
BOARDS_ACROSS = 7
STICKERS = 6
BEARER = 0.1


def cordwood(seed: int, hearts: float = 1.0) -> object:
    """One section; `hearts` the share of wedges drawn with a dark heart (as many as its budget leaves room for)."""
    hs.reset()
    wk.paint_all()
    mk.paints({"Gap": 0x2A2621})  # near black, dull: the deep shade between the pieces, as in the photo
    assert wk.off_team(0x2A2621), "Gap reads as a team"
    for name, colour in END_PAINTS.items():
        assert wk.off_team(colour), "%s #%06x reads as a team" % (name, colour)
    mk.paints(END_PAINTS)
    r = wk.rng(seed)
    dark = random.Random(seed * 7 + 1)  # which wedges show a dark heart: a stream of its own
    top = random.Random(seed * 7 + 2)  # the top's logs' bark: a stream of its own, so the pieces stay put
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

    # each face's pieces (lay_face), rigid, under the ragged top
    faces = {side: lay_face(r, half_x, top_at) for side in (1.0, -1.0)}
    # the dark core: what shows between the pieces, its top along each face just under that face's highest pieces, so
    # the stack's ragged top is the pieces' own
    cols = [-half_x + SECTION * k / CORE_COLS for k in range(CORE_COLS + 1)]
    # (read a little in from each end, where the pieces stand GAP or more short of the section's edge, so the core's top
    # never falls to the ground there and opens the seam between sections)
    # (RM2) each the highest of three reads about it, and at the ends every piece out to the end, so the top's
    # logs lie close under the face's highest pieces and no tall piece stands far over them as a loose flake
    step = SECTION / CORE_COLS * 0.5

    def env_read(pieces: list, x: float) -> float:
        reads = [min(max(x + step * d, -half_x + END_IN), half_x - END_IN) for d in (-0.5, 0.0, 0.5)]
        if abs(x) > half_x - 1e-6:
            reads += [math.copysign(half_x - 2.0 * GAP - END_IN * k / 8.0, x) for k in range(8)]
        return max(crown(pieces, xr) for xr in reads)

    env = {side: [env_read(faces[side], x) for x in cols] for side in faces}
    def env_at(side: float, x: float) -> float:
        t = min(max((x + half_x) / SECTION * CORE_COLS, 0.0), CORE_COLS - 1e-9)
        k = int(t)
        return env[side][k] + (env[side][k + 1] - env[side][k]) * (t - k)

    # the core's sides, under each face's pieces
    for k in range(CORE_COLS):
        x0, x1 = cols[k], cols[k + 1]
        for side in faces:
            y = side * core
            q = wk.verts(b, [(x0, y, 0.0), (x1, y, 0.0), (x1, y, env[side][k + 1]), (x0, y, env[side][k])])
            wk.face(b, q, "Gap", Vector((0, side, 0)))
    # (RM2) its top: the top course's logs lying front to back, two columns each, each its own bark, rounded across
    # and rising to its middle between the faces (at the faces it meets the core's sides), a crease between them; the
    # two at the stack's ends flat, stopping at the end (END_SET in) so nothing stands out over the end's logs
    logs = CORE_COLS // 2
    lim = half_x - END_SET
    for m in range(logs):
        x0, xm, x1 = cols[2 * m], cols[2 * m + 1], cols[2 * m + 2]
        w = x1 - x0
        flat = m in (0, logs - 1)
        prof = ((x0, 0.0), (xm, 0.0), (x1, 0.0)) if flat else \
            ((x0, 0.0), (x0 + 0.2 * w, 0.6), (xm, 1.0), (x1 - 0.2 * w, 0.6), (x1, 0.0))
        rise = TOP_LOG * top.uniform(0.7, 1.0)
        xs = []
        for x, k in prof:
            xc = min(max(x, -lim), lim)
            if not xs or xc - xs[-1][0] > 1e-4:
                xs.append((xc, k))
        rows = ((-core, 0.0), (core, 0.0)) if flat else ((-core, 0.0), (0.0, 1.0), (core, 0.0))
        mat = top.choice(TOP_BARK)

        def at(x: float, y: float, kx: float, ky: float) -> tuple:
            z = env_at(-1.0, x) + (env_at(1.0, x) - env_at(-1.0, x)) * (y + core) / (2.0 * core)
            return (x, y, z + rise * kx * ky)

        for (xa, ka), (xb, kb) in zip(xs, xs[1:]):
            for (ya, ja), (yb, jb) in zip(rows, rows[1:]):
                q = wk.verts(b, [at(xa, ya, ka, ja), at(xb, ya, kb, ja), at(xb, yb, kb, jb), at(xa, yb, ka, jb)])
                wk.face(b, q, mat, Vector((0, 0, 1)))
    # its ends, seen at a stack's end: the bark sides of the end pieces, each log's side rounded out of the end from
    # the face its sawn end shows on to where the front pieces meet the back ones, the dark of the stack between (RM2:
    # were flat slabs in rows, as brick)
    for x, s in ((cols[0], -1.0), (cols[-1], 1.0)):
        base = x - s * END_SET
        split = r.uniform(-0.12, 0.12)
        # the dark between them, up to each face's crown (sloping across the top as the core's does), so no hole
        # opens at the section's end and nothing stands over the stack's top there
        e0, e1 = env_at(-1.0, base), env_at(1.0, base)
        q = wk.verts(b, [(base, -core, 0.0), (base, core, 0.0), (base, core, e1), (base, -core, e0)])
        wk.face(b, q, "Gap", Vector((s, 0, 0)))
        for side, crest in ((1.0, e1), (-1.0, e0)):
            for z0, z1, back in end_logs(faces[side], s * half_x):
                if z0 < crest - 0.03:
                    end_log(b, r, base, s, side * core, split + side * 0.006, z0, min(z1, crest), back)
    for side, pieces in faces.items():
        out = Vector((0.0, side, 0.0))
        for kind, poly in pieces:
            outline = [(px, side * core, pz) for px, pz in poly]
            end_mat = r.choices(END_MATS, END_WEIGHTS)[0]
            depth = r.triangular(PROUD[0], PROUD[1], PROUD_MODE)
            if any(abs(px) >= SECTION * 0.5 - GAP - 1e-6 for px, _ in poly):
                depth = PROUD[0]  # cut at the section's end: flush, so no side of it stands out past the end's logs
            # (RM2) a piece standing over the core's top shows its back from behind the stack: barked, its sides drawn
            cx = sum(px for px, _ in poly) / len(poly)
            over = max(pz for _, pz in poly) > env_at(side, cx) + 0.005
            piece_end(b, outline, depth, out, end_mat, kind,
                      (r.uniform(-TILT, TILT), r.uniform(-TILT, TILT)), r.choices((0, 1, 2, 3), CHECKS)[0], r,
                      heart=dark.random() < hearts, backed=over)
    # split pieces lying across the top here and there, on the pieces' top
    for k in range(LOOSE):
        x = -half_x + LOOSE_IN + (SECTION - 2.0 * LOOSE_IN) * (k + r.uniform(0.2, 0.8)) / LOOSE
        w = SECTION / LOOSE * r.uniform(0.25, 0.4)
        z = min(crown(faces[1.0], x), crown(faces[-1.0], x))
        wk.ridge(b, x, w, z, r.uniform(0.03, 0.055), core, ("Bark", "Split", "BarkLight")[k % 3])
    ob = b.build()
    wk.finish(ob, SMOOTH)
    wk.fit_box(ob, (-half_x, -half_y, 0.0), (half_x, half_y, HEIGHT))
    return ob


def end_logs(pieces: list, end_x: float) -> list:
    """The pieces whose sides show at the section's end `end_x`: those reaching within END_NEAR of it, the nearest
    first where two would lie in the same place, as (bottom, top, how far back from the end)."""
    cands = []
    for _kind, poly in pieces:
        xs = [px for px, _ in poly]
        back = end_x - max(xs) if end_x > 0.0 else min(xs) - end_x
        if back < END_NEAR:
            zs = [pz for _, pz in poly]
            cands.append((back, min(zs), max(zs)))
    picked = []
    for back, z0, z1 in sorted(cands):
        if all(z1 <= a + 0.01 or z0 >= c - 0.01 for a, c, _ in picked):
            picked.append((z0, z1, back))
    picked.sort()
    # (RM2) each log's side widened to meet the next, from the ground up, so no flat dark panel shows between them
    out = []
    for i, (z0, z1, back) in enumerate(picked):
        lo = 0.0 if i == 0 else (picked[i - 1][1] + z0) * 0.5 - END_TOUCH
        hi = z1 if i == len(picked) - 1 else (z1 + picked[i + 1][0]) * 0.5 + END_TOUCH
        out.append((min(z0, lo), max(z1, hi), back))
    return out


def end_log(b: hs.Builder, r: object, base: float, s: float, y0: float, y1: float, z0: float, z1: float,
            back: float) -> None:
    """A log's side at the section's end (s: -1 or 1): its bark from the face (y0) in towards the middle (y1),
    between z0 and z1, bulging out of the end's dark `base`, each its own: set further in or further out, starting a
    little inside the face, stopping short of the middle or running past it (so the front and back logs' ends
    stagger), its round a wedge's edge or flatter, uneven, twisting and narrowing or swelling along it, its bark in
    streaks of light and dark; now and then a flatter, pale split side."""
    bulge = END_SET * r.uniform(0.45, 1.0) - back * 0.5
    sink = r.uniform(0.0, 0.035) * (1.0 if bulge > 0.03 else 0.3)  # set further into the stack than its neighbours
    # its two ends: some a little inside the face, and short of the middle or past it, among the far side's logs
    face = y0
    y0 = y0 + math.copysign(END_PROUD - r.uniform(0.0, 0.03), y0)  # with the core's face (never past it), or a little in
    y1 = y1 + math.copysign(r.uniform(0.02, 0.12), y1 - face)  # past the middle, among the far side's logs
    zc, rz = (z0 + z1) * 0.5, (z1 - z0) * 0.49
    turn = r.uniform(-35.0, 35.0)  # where its round stands out furthest, up or down: twisting a little along it
    sharp = r.choice((0.45, 0.7, 0.7, 1.0, 1.3))  # a wedge's edge (under 0.7) or a flatter split face (over)
    rings = []
    for k, y in enumerate((y0, y1)):
        swell = r.uniform(0.85, 1.12)  # thicker or thinner at its two ends
        turn += r.uniform(-15.0, 15.0)
        ring = []
        for i in range(END_ARC + 1):
            a = math.radians(-80.0 + 160.0 * i / END_ARC)
            out = max(0.004, bulge * swell - sink) * max(0.0, math.cos(a - math.radians(turn))) ** sharp
            if 0 < i < END_ARC:
                out *= r.uniform(0.8, 1.15)  # an uneven, knotty round
            ring.append((base + s * max(0.003, out), y, zc + rz * math.sin(a)))
        rings.append(ring)
    # one bark a log, a darker streak on a facet here and there
    own = r.choice(("Bark", "Bark", "BarkDark", "BarkGrey"))
    bark = (own, own, own, "BarkDark", "BarkFurrow")
    for i in range(END_ARC):
        q = wk.verts(b, [rings[0][i], rings[1][i], rings[1][i + 1], rings[0][i + 1]])
        a = math.radians(-80.0 + 160.0 * (i + 0.5) / END_ARC)
        mat = r.choice(bark)
        wk.face(b, q, mat, Vector((s * math.cos(a), 0.0, math.sin(a))))


def lay_face(r: object, half_x: float, top_at: object) -> list:
    """A face's pieces' ends (kind, outline as (x, z) points) from x = -half_x to half_x, from the ground up to the
    stack's ragged top (`top_at(x)`, each piece wholly under it, never stretched to it), stacked as
    by hand: each piece in turn set where its middle rests lowest (a split piece tried point up, point down and, now
    and then, on its side, so the wedges lock together), on the ground or on the pieces under it, GAP above them;
    until FULL pieces in a row fit nowhere under the top. No outline crosses another (asserted)."""
    h = (HEIGHT - 0.05) / ROWS
    pieces = []
    misses = 0
    while misses < FULL:
        best = None
        for kind, whole in piece_outline(r, h):
            wide0 = max(px for px, _ in whole)
            # (RM2) a piece may run past the section's end, cut off flush there, so its neighbour section's pieces
            # butt against it and no straight dark seam runs up the stack where two sections meet
            over = wide0 * EDGE_CUT
            steps = int((2.0 * half_x + 2.0 * over - wide0) / LAY_STEP)
            for i in range(steps + 1):
                x0 = -half_x - over + i * LAY_STEP
                cut = _clip_x([(px + x0, pz) for px, pz in whole], -half_x + GAP, half_x - GAP)
                if len(cut) < 3:
                    continue
                x = min(px for px, _ in cut)
                poly = [(px - x, pz) for px, pz in cut]
                wide = max(px for px, _ in poly)
                if wide < wide0 * (1.0 - EDGE_CUT) - 1e-9:
                    continue
                z = rest(pieces, poly, x, wide)
                if any(pz + z > top_at(px + x) - h * EDGE for px, pz in poly):
                    continue
                mid = _centroid_z(poly)
                if best is None or z + mid < best[0] - 1e-6:
                    # a piece cut at the section's end shows its sawn face whole, no bark rim (its heart may be gone)
                    cut_kind = kind if wide >= wide0 - 1e-9 else "heart"
                    best = (z + mid, cut_kind, [(px + x, pz + z) for px, pz in poly])
        if best is None:
            misses += 1
            continue
        misses = 0
        assert not any(overlaps(best[2], q) for _, q in pieces), "a piece's end crosses another"
        pieces.append((best[1], best[2]))
    # then smaller pieces pushed into the holes left, as a stack is filled by hand: at each place tried, the biggest
    # that fits
    for _ in range(FILL_TRIES):
        x, z = r.uniform(-half_x, half_x), r.uniform(0.0, HEIGHT)
        if z > top_at(x):
            continue
        near = [q for _, q in pieces if min(px for px, _ in q) - 0.3 < x < max(px for px, _ in q) + 0.3
                and min(pz for _, pz in q) - 0.3 < z < max(pz for _, pz in q) + 0.3]
        for scale in FILL_SIZES:
            done = False
            for kind, poly in piece_outline(r, h * scale, FILL_ARC, True):
                wide, tall = max(px for px, _ in poly), max(pz for _, pz in poly)
                cand = [(px + x - wide * 0.5, pz + z - tall * 0.5) for px, pz in poly]
                if min(px for px, _ in cand) < -half_x + GAP or max(px for px, _ in cand) > half_x - GAP:
                    continue
                if min(pz for _, pz in cand) < GAP or any(pz > top_at(px) - h * EDGE for px, pz in cand):
                    continue
                if any(overlaps(cand, q, GAP) for q in near):
                    continue
                pieces.append((kind, cand))
                done = True
                break
            if done:
                break
    assert not any(overlaps(a[1], c[1]) for i, a in enumerate(pieces) for c in pieces[i + 1:]), "pieces cross"
    assert all(abs(px) <= half_x - GAP + 1e-9 for _, q in pieces for px, _ in q), "a piece past the section's end"
    return pieces


def _clip_x(poly: list, lo: float, hi: float) -> list:
    """A convex outline cut to lo <= x <= hi (Sutherland-Hodgman on the two lines), its points in order."""
    for edge, keep in ((lo, lambda px: px >= lo - 1e-12), (hi, lambda px: px <= hi + 1e-12)):
        out = []
        for i in range(len(poly)):
            a, c = poly[i], poly[(i + 1) % len(poly)]
            if keep(a[0]):
                out.append(a)
            if keep(a[0]) != keep(c[0]):
                t = (edge - a[0]) / (c[0] - a[0])
                out.append((edge, a[1] + (c[1] - a[1]) * t))
        poly = out
        if len(poly) < 3:
            return []
    return poly


def crown(pieces: list, x: float) -> float:
    """The core's top at `x` on a face: just under the highest piece over it there (CROWN_SINK under its top), or the
    ground where none is."""
    z = 0.0
    for _, q in pieces:
        if min(px for px, _ in q) <= x <= max(px for px, _ in q):
            span = _vspan(q, x)
            if span:
                z = max(z, span[1])
    return max(0.0, z - CROWN_SINK)


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


def piece_outline(r: object, h: float, arc_n: int = ARC, split_only: bool = False) -> list:
    """One piece's end for rows `h` m high, as the ways it may lie (kind, outline from x = 0 and z = 0): a wedge (a pie
    slice of its log, its point at the log's heart first, then its bark arc) point up or point down, now and then on its
    side either way, each up to LEAN off square; a small round; or a four-sided piece split from a log's heart
    (with `split_only`, always a wedge)."""
    room = h * (1.0 - 2.0 * EDGE)
    roll = 1.0 if split_only else r.random()
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
    rad = room * r.uniform(0.68, 1.0)
    if r.random() < HALF:
        span = math.radians(r.uniform(*HALF_SPAN))
        rad *= 0.7
    ways = (0.0, math.pi) + ((0.5 * math.pi, 1.5 * math.pi) if r.random() < ASIDE else ())
    out = []
    for turn in ways:
        # the arc's middle points away from the heart: down (point up), up (point down) or to either side
        mid = turn - 0.5 * math.pi + math.radians(r.uniform(-LEAN, LEAN))
        # (RM2: the arc in about ARC_STEP degree steps, so a wide piece's bark rounds as a narrow one's does)
        n = max(3, min(arc_n + 1, round(math.degrees(span) / ARC_STEP)))
        arc = [(rad * math.cos(mid - span / 2 + span * i / n), rad * math.sin(mid - span / 2 + span * i / n))
               for i in range(n + 1)]
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
              checks: int = 0, r: object = None, heart: bool = False, backed: bool = False) -> None:
    """A piece's end standing `depth` proud of the stack's dark core (outline: points on the core's face), as a solid
    log end (WS1, the owner: the stacks read flat): its sides run back to the core where it stands out enough to show
    them (SHOWS), and its end face is sawn a little off square (`tilt`: how much further out it stands per metre across
    and up the face). A "wedge" (a split piece, a pie slice of its log, as most in the photos: its outline the heart's
    point, then its bark arc) has its arc barked and a rim of bark (BARK_RIM) inside it on its face, its split
    sides pale, and `checks` drying cracks from its heart (each laid out with `r`); a "round" a thin ring of bark
    round its sawn face; a "heart" (split from the log's middle) no bark at all."""
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
    if depth >= SHOWS or backed:
        back_ids = wk.verts(b, base)
        if backed:
            wk.face(b, back_ids[::-1], "Bark", -out)  # over the stack's top: its back seen from behind it
        for i in range(n):
            j = (i + 1) % n
            side_out = ((base[i] + base[j]) * 0.5 - c0).normalized()
            if side_out.z < -0.5 and (c0.z < UNDER_SEEN or backed):
                continue  # a side facing down under eye height (or under the top) is never seen
            if depth < SHOWS and side_out.z < 0.2:
                continue  # a thin piece over the top: only its upper sides, seen from above
            cut = all(abs(abs(p.x) - (SECTION * 0.5 - GAP)) < 1e-6 for p in (base[i], base[j]))
            if kind == "round" or i in bark or cut:
                mat = "Bark"  # (a piece cut at the section's end: its side there reads with the end's logs)
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
    if max((p - front[0]).length for p in front[1:]) < RIM_MIN:
        # (RM2) a small piece: its rim of bark would be a hairline, so its sawn face runs to its arc
        inner = front
        wk.face(b, front_ids, end_mat, out)
    else:
        wk.face(b, front_ids, "Rim", out)
        # the sawn face inside its bark: the arc drawn in toward the heart by BARK_RIM of its radius
        inner = [p if i == 0 else front[0].lerp(p, 1.0 - BARK_RIM) for i, p in enumerate(front)]
        wk.face(b, wk.verts(b, [p + out * 0.004 for p in inner]), end_mat, out)
    if heart:
        # the heart, darker, at the wedge's point
        tip = inner[0]
        HEARTS[0] += 1
        wk.face(b, wk.verts(b, [tip + out * 0.005, tip.lerp(inner[1], HEART_SHARE) + out * 0.005,
                                tip.lerp(inner[-1], HEART_SHARE) + out * 0.005]), "EndHeart", out)
    for _ in range(checks):
        # a drying crack from near the heart toward the bark, thin and dark, each its own length and way
        tip = inner[0]
        j = r.randrange(1, len(inner))
        to = inner[j].lerp(inner[min(len(inner) - 1, j + 1)], r.random())
        start, end = r.uniform(0.05, 0.3), r.uniform(0.45, 0.85)
        side = (to - tip).cross(out).normalized() * (to - tip).length * r.uniform(0.012, 0.025)
        wk.face(b, wk.verts(b, [tip.lerp(to, start) + out * 0.006, tip.lerp(to, end) + side + out * 0.006,
                                tip.lerp(to, end) - side + out * 0.006]), "Gap", out)


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


HEARTS = [0]  # the dark hearts drawn in the section being built


def _tris(ob: object) -> int:
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def main() -> None:
    for name, seed in SECTIONS:
        # built once with every heart, then again with as many as its budget leaves room for (the hearts draw from
        # a stream of their own, so the pieces stay where they were)
        HEARTS[0] = 0
        ob = cordwood(seed)
        over = _tris(ob) - int(CORD_BUDGET * 0.995)
        if over > 0:
            ob = cordwood(seed, max(0.0, 1.0 - over / max(1, HEARTS[0])))
        mk.report(ob, name, CORD_BUDGET)
        print("  wrote", mk.export_prop(ob, name))
    ob = boards()
    mk.report(ob, "boards", BOARD_BUDGET)
    print("  wrote", mk.export_prop(ob, "boards"))


if __name__ == "__main__":
    main()
