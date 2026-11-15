"""Woodland's cordwood stack and sawn board stack (WG2, model 13): assets/models/props/cordwood.glb, _b and _c, three
2 m sections of split firewood that the game lays along each stack, one a cell at random, stretched to its height (the
Woodpile's 12 m wall, the camp gate screens, the Log stacks, the log piles); each top near level and its rows uneven,
a stack built by hand; and boards.glb, B site's stack of sawn boards (6.4 x 1 x 2 m).

From the owner's photos (references/maps/woodland/13-cordwood-stack-and-board-stack): split logs stacked lengthwise in
rows, their sawn ends to the faces: pale wedges and quarters with bark on their round side, a few small rounds, the
rows uneven so the face is ragged and the gaps between them dark; split pieces lying across the top. The boards are
stacked in layers held apart by stickers (thin battens) so the air gets through, on bearers off the ground.

RM2 (the owner, 2026-11-15: "improve the stacks of wood logs"): the pieces mixed as the photos' are, not one size of
quarter laid in rows like scales: wedges from narrow to wide (55 to 125 degrees at the heart), a tenth of them half
logs, more small rounds, a third free to lie on their side and up to 24 degrees off square, each 0.68 to 1 of a row
high, so the rows break up; no square heart pieces; each bark arc in about 34 degree steps; warmer tans and a brown
among the sawn ends, a darker heart at most wedges' points; the stack's top near level, a piece standing up out of it
cut down; each end courses of split pieces the face's pieces' size lying front to back, each course tilted 1 to 3
degrees and lying on the one under it, a front and a back piece a course meeting 1 to 3 cm apart, each closed there
by its sawn end; each piece its own kind (a round log, a log split down one side with a flat pale face out, a wedge
point out, a quarter), set in up to 5 cm its own way, its split faces crisp and its bark warm grey-brown and smooth;
its sawn end at the face drawn in to the face's pieces beside it, so no dark seam runs up a corner; the top pieces
lying front to back, a third the whole depth, the rest two meeting off the middle, turned up to 12 degrees, pale
split ridges and dark bark, two or three more lying over them turned 20 to 40 degrees, the end's top piece the
highest at each corner. The twelfth pass: a stack's middle sections cut flush at both ends (their face pieces
clipped at the cut, so they run on into the next section with no seam), only the stack's first and last sections
(cordwood_start, _end, _single: PropDressConfig.grid_ends) closed by end courses 8 to 20 cm high, each set in or out
up to 4 cm and turned up to 8 degrees seen from above, one piece in four a long one standing 10 to 15 cm out, every
split face broken by a crease; no chip that rests on nothing; the top's pieces apart, touching or riding half on a
neighbour, the crossing ones inside the end courses, the end's top piece no higher than the crest. The same budget.

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
# the sections, each its own top line and pieces; the game picks one a cell (PropDressConfig.variants)
SECTIONS = (("cordwood", 1300), ("cordwood_b", 1301), ("cordwood_c", 1304), ("cordwood_start", 1310),
            ("cordwood_end", 1311), ("cordwood_single", 1312))
# (RM2, twelfth pass) which of a section's ends close the stack ([-x, +x], PropDressConfig.grid_ends): the stack's
# first and last sections, and a stack one section long; the rest carry on into their neighbours
ENDS = {"cordwood_start": (True, False), "cordwood_end": (False, True), "cordwood_single": (True, True)}
BOARD_BUDGET = 1500
# a cordwood section (m): its length along the stack, its depth across it (the faces at +-DEPTH/2), its height
SECTION, DEPTH, HEIGHT = 2.0, 1.0, 1.8
TOPS = 9                # points along the section where its top line is set
SAG = 0.1               # how far under the cell's top the stack's top dips at most (RM2: was 0.45; near level)
SAG_STEP = 0.05         # m the top may rise or fall from one of those points to the next (RM2)
SPIKE_W = 0.1           # m: a crown narrower than twice this standing over its neighbours is a piece on its point (RM2)
SPIKE_ROUNDS = 3        # times the top is read again and its spikes cut down
SPIKE_KEEP = 0.45       # a piece cut down to less than this share of its height is taken off instead
NOTCH_W = 0.08          # m: a notch in the top course narrower than twice this is bridged by the top's logs (RM2)
PROUD = (0.003, 0.05)   # how far a piece's end stands out of the core: the face's relief (WS1: solid ends, near flush)
PROUD_MODE = 0.015     # most stand out about this far, a few flush or 5 cm out, as a stack built by hand
TILT = 0.14             # an end face sawn off square: up to this much further out per metre across or up it
ARC_STEP = 34.0         # degrees of bark arc a segment (RM2: 24, then 28 to make room for the hearts)
ARC = 5                 # the bark arc's segments on a split piece (a pie slice of its log), the widest 6
ARC_SPAN = (55.0, 125.0)  # a split piece's angle at the log's heart (degrees): 1.2 to 1.5 times as wide as deep
RIM = 0.07              # a ring of bark on a sawn end: this share of the way in from its edge (about 4 % across)
BARK_RIM = 0.1          # a split piece's rim of bark inside its arc: this share of its radius
RIM_MIN = 0.085         # m: a split piece smaller than this (tip to arc) shows no rim of bark (RM2: pays for the top)
CHECKS = (85, 11, 4, 0)  # how often a split piece shows no, one, two or three drying cracks from its heart
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
CORE_COLS = 20          # places along the section where the core's top follows the pieces
END_IN = 0.08           # m in from each end where the core's top is read from the pieces
CROWN_SINK = 0.0        # m the core's top lies under the highest piece's top (RM2: was 0.02; now at it, so few stand over it)
HALF = 0.1              # the share of split pieces that are half logs (RM2: the photos' mix)
HALF_SPAN = (150.0, 175.0)
END_SET = 0.28          # m the face's pieces and the stack's end stand inside a closing end; the end pieces stand out
                        # of it up to this (the long ones), their sawn ends filling the face to the end (RM2)
END_OUT = 0.09          # m an end piece stands out of the stack's end, about (twelfth pass: 0.12 was the most)
END_COURSE_SET = 0.04   # m a course stands in or out of that, its own way (twelfth pass)
END_TURN = 8.0          # degrees a course lies turned off front to back, seen from above (twelfth pass)
END_LONG = 0.25         # the share of end pieces that are long, split down one side, past the others by END_LONG_OUT
END_LONG_OUT = (0.10, 0.15)
END_WEDGE = 1.3         # a wedge stands out at most this many of its course's half height (twelfth pass: no blades)
END_CREASE = 0.012      # m a split face is broken out or in along a line, so no piece reads as a plank
EDGE_CUT = 0.35         # how much of a piece's width may run past an end the stack carries on from, cut off there
CHIP = 0.075            # m: a face piece smaller than this each way near a closing end is taken off (no loose chips)
CHIP_NEAR = 0.2         # m from the end
TOP_SINK = 0.004        # m the core's top lies under its top pieces' edges
END_REACH = 0.16        # m at most a log end's flat side is drawn in over the dark to the face's last piece
END_ARC = 4             # a round log's side's segments (43 degrees each, drawn smooth: _round_ends)
END_CAP = 7             # a round log's sawn end's sides (a half round: 8 with its flat side), and the sawn face's
END_CAP_IN = 3          # inside its rim
END_RIM = 0.14          # the bark rim's share of the sawn end's radius
END_H = (0.08, 0.2)     # m an end course's height (RM2: 0.115 to 0.15 in the ninth pass, each course alike)
END_TILT = (1.0, 3.0)   # degrees a course lies off level, either way, front to back (the ground course level)
END_SETIN = (0.0, 0.02)  # m each piece stands in from its course, its own way
END_GAP = (0.01, 0.03)  # m between a course's front and back pieces where they meet, each closed by its sawn end
END_KINDS = ("round", "flat", "wedge", "quarter")  # (RM2, eleventh pass) an end piece: a round log, bark all round;
END_KIND_W = (0.25, 0.35, 0.25, 0.15)  # a log split down one side, a flat pale face out between bark; a wedge, point
                        # out, two split faces; a quarter, a split face and a bark round
END_BARK = ("EndBark", "EndBarkDark", "EndBarkLight", "Rim", "EndBark")  # their bark: warm grey-brown
END_TOP = 0.0           # m the end's top piece stands over the stack's crest (twelfth pass: was 3 cm, a lid)
END_PROUD = 0.002       # m past the core an end piece's sawn end stands: in the face's plane, just behind its pieces
END_JOINT = (0.08, 0.3)  # where a course's front and back logs meet: this share of the way to a face from the
                        # middle, to the front and the back by turns, so the joints stagger
LOOSE = 0               # split pieces lying across the top (RM2: none; they read as planks along the top edge)
LOOSE_IN = 0.2          # m they keep in from the section's ends, never over the stack's end
SMOOTH = 45.0           # degrees: faces meeting at less than this are drawn smooth (RM2: was 34; the end logs and top logs round)
# the sawn ends' colours, each piece its own, from fresh pale to warm tan to weathered grey (as in the photo)
# (warm as the photo's, each just off Beta orange's hue: woodkit.off_team)
# (RM2: deeper, more of the deep tans and a brown, as the owner's photo's warm brown at eye height; their hue can go
# no nearer orange, so they are darker, not more orange)
END_PAINTS = {"EndPale": 0xC4AF7F, "EndLight": 0xBDA56B, "EndWarm": 0xB69D5B, "EndDeep": 0xAC924D, "EndTan": 0xA28843,
              "EndBrown": 0x927B3C, "EndOld": 0xAF9D75, "Rim": 0x5F543C,
              "EndHeart": 0x7C6838, "EndBark": 0x6B614A, "EndBarkDark": 0x5B5340, "EndBarkLight": 0x7A6F55}
END_MATS = tuple(k for k in END_PAINTS if k not in ("Rim", "EndHeart") and not k.startswith("EndBark"))
# Rim: a split piece's bark, a warm brown; EndBark*: the end pieces' (eleventh pass); EndHeart: its heart, darker
# (RM2, the photo's pieces)
HEART_SHARE = 0.45      # how far out from a wedge's point its dark heart reaches
TOP_LOG = 0.4           # the top course's logs rise this share of their width, at most, between the faces (RM2)
TOP_W = 0.16            # m a top piece's width, about: each 0.5 to 1.5 of it (RM2: was 0.133)
TOP_TURN = 12.0         # degrees a top piece may lie off front to back (RM2, tenth pass; 10, then 12)
TOP_WHOLE = 0.33        # the share of the top's pieces the stack's whole depth long
SPIKE = 0.04            # m a face piece may stand over the top course beside it; a taller one is cut down
TOP_BARK = ("Bark", "BarkDark", "BarkFurrow", "Rim", "BarkDark")  # the top's pieces' bark, dark, never the
                        # same as the piece beside it (RM2)
TOP_SPLIT = 0.4         # the share of the top's pieces lying point up: pale split sides meeting at a ridge (RM2)
TOP_CROSS = (2, 3)      # pieces lying over the top course, turned 20 to 40 degrees off front to back (RM2, eleventh
TOP_CROSS_TURN = (20.0, 40.0)  # pass), so the top is never an even row
TOP_BY_END = 0.25       # the end columns' top pieces rise this share of the others', under the end's top piece
TOP_APART = 0.3         # the share of the top's pieces lying apart from their neighbours, TOP_GAP each side
TOP_GAP = (0.015, 0.03)
TOP_RIDE = 0.2          # the share lying half on a neighbour: TOP_RIDE_W of their width over it (twelfth pass)
TOP_RIDE_W = 0.35
END_WEIGHTS = (1, 2, 3, 3, 3, 2, 1)
# the boards (m)
BOARDS_LEN, BOARDS_DEPTH, BOARDS_TOP = 6.4, 1.0, 2.0
BOARD_T, STICKER_T = 0.07, 0.03
SHEET = 0.05            # the corrugated sheet weighing the top down
RIBS = 14
BOARDS_ACROSS = 7
STICKERS = 6
BEARER = 0.1


def cordwood(seed: int, hearts: float = 1.0, ends: tuple = (False, False)) -> object:
    """One section; `hearts` the share of wedges drawn with a dark heart (as many as its budget leaves room for);
    `ends` whether its -x and its +x end close the stack (an end column of split pieces, RM2) or carry on into the
    next section (its face's pieces cut flush there, its top at the cell's top, so any two sections meet)."""
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
    # the stack's top along the section: near level (RM2), a few centimetres lower here and there, never stepping more
    # than SAG_STEP from one point to the next, at the cell's top at both ends (so the next section's top meets it)
    dips = [0.0]
    for k in range(1, TOPS):
        dips.append(min(SAG, SAG_STEP * (TOPS - 1 - k), max(0.0, dips[-1] + r.uniform(-SAG_STEP, SAG_STEP))))
    tops = [HEIGHT - 0.05 - d for d in dips]

    def top_at(x: float) -> float:
        t = min(max((x + half_x) / SECTION * (TOPS - 1), 0.0), TOPS - 1.0)
        k = min(TOPS - 2, int(t))
        return tops[k] + (tops[k + 1] - tops[k]) * (t - k)

    # each face's pieces (lay_face), rigid, under the top: at a closing end stopping END_SET short of it, where the end
    # column's sawn ends fill the face (RM2: cut off there, the pieces showed edge on as cards); at an end the stack
    # carries on from, cut off flush with it (RM2, twelfth pass)
    lo, hi = -half_x + (END_SET if ends[0] else 0.0), half_x - (END_SET if ends[1] else 0.0)
    cut = (not ends[0], not ends[1])
    faces = {side: lay_face(r, lo, hi, top_at, cut) for side in (1.0, -1.0)}
    # (RM2) a piece standing up out of the top course (a wedge on its point, a thin shard) is cut down: the face's
    # crown read every 2 cm and opened (its narrow peaks cut down to their neighbours: the lowest over SPIKE_W each
    # way, then the highest of those), and a piece whose top stands more than SPIKE over that line cut level there, a
    # piece with its point broken off lying on its flat (its sawn end then plain, no bark rim), or taken off when
    # little of it is left; so the top course lies near level and nothing stands up out of it
    e_lo, e_hi = lo + (2.0 * GAP if ends[0] else 0.0), hi - (2.0 * GAP if ends[1] else 0.0)  # (read inside a closing
    # end's pieces, where every place along the face has a piece over it)
    grid = [e_lo + 0.02 * k for k in range(int((e_hi - e_lo) / 0.02) + 1)]
    w = int(round(SPIKE_W / 0.02))

    def opened(line: list) -> list:
        low = [min(line[max(0, i - w):i + w + 1]) for i in range(len(line))]
        return [max(low[max(0, i - w):i + w + 1]) for i in range(len(line))]

    def under(level: list, x: float) -> float:
        t = min(max((x - e_lo) / 0.02, 0.0), len(level) - 1.0 - 1e-9)
        k = int(t)
        return level[k] + (level[k + 1] - level[k]) * (t - k)

    for _ in range(SPIKE_ROUNDS):
        cut_any = False
        for side in faces:
            level = opened([crown(faces[side], x) for x in grid])
            kept = []
            for kind, poly in faces[side]:
                peak = max(poly, key=lambda p: p[1])
                cap = under(level, peak[0]) + SPIKE
                if peak[1] > cap:
                    cut_any = True
                    low = min(pz for _, pz in poly)
                    poly = _clip_z(poly, cap) if cap - low > SPIKE_KEEP * (peak[1] - low) else []
                    if len(poly) < 3:
                        continue
                    kind = "heart"
                kept.append((kind, poly))
            faces[side] = kept
        if not cut_any:
            break
    # (RM2, twelfth pass) no chip by a closing end: a small piece there (pushed into a hole, or what was left of one
    # cut down) is taken off, and the end column's sawn ends are drawn in over its place
    for side in faces:
        faces[side] = [(kind, poly) for kind, poly in faces[side]
                       if max(max(px for px, _ in poly) - min(px for px, _ in poly),
                              max(pz for _, pz in poly) - min(pz for _, pz in poly)) >= CHIP
                       or not ((ends[0] and min(px for px, _ in poly) < lo + CHIP_NEAR)
                               or (ends[1] and max(px for px, _ in poly) > hi - CHIP_NEAR))]
    # the dark core: what shows between the pieces, its top along each face just under that face's highest pieces, so
    # the stack's top is the pieces' own; each the highest of three reads about it (read a little in from a closing
    # end, where the pieces stand GAP short of it, and there every piece out to the end, so the core's top never falls
    # to the ground at the end)
    cols = [lo + (hi - lo) * k / CORE_COLS for k in range(CORE_COLS + 1)]
    step = (hi - lo) * 0.5 / CORE_COLS
    r_lo, r_hi = lo + (END_IN if ends[0] else 0.0), hi - (END_IN if ends[1] else 0.0)

    def env_read(pieces: list, x: float) -> float:
        reads = [min(max(x + step * d, r_lo), r_hi) for d in (-0.5, 0.0, 0.5)]
        if ends[0] and x < lo + 1e-6:
            reads += [lo + 2.0 * GAP + END_IN * k / 8.0 for k in range(8)]
        if ends[1] and x > hi - 1e-6:
            reads += [hi - 2.0 * GAP - END_IN * k / 8.0 for k in range(8)]
        return max(crown(pieces, xr) for xr in reads)

    # (RM2) and over a notch in the top course narrower than NOTCH_W each way, up to the pieces either side: a dark
    # pocket between them under the top's logs, as the photo's, not a V cut into the stack's top line
    k_n = int(round(NOTCH_W / 0.02))

    def closed(line: list) -> list:
        high = [max(line[max(0, i - k_n):i + k_n + 1]) for i in range(len(line))]
        return [min(high[max(0, i - k_n):i + k_n + 1]) for i in range(len(line))]

    shut = {side: closed([crown(faces[side], x) for x in grid]) for side in faces}
    env = {side: [max(env_read(faces[side], x), under(shut[side], x)) for x in cols] for side in faces}

    def env_at(side: float, x: float) -> float:
        t = min(max((x - lo) / (hi - lo) * CORE_COLS, 0.0), CORE_COLS - 1e-9)
        k = int(t)
        return env[side][k] + (env[side][k + 1] - env[side][k]) * (t - k)

    # the core's sides, under each face's pieces, out to the stack's end (never past it, so no dark flap shows
    # there): each one face, its top along the pieces' crown
    for side in faces:
        y = side * core
        q = wk.verts(b, [(lo, y, 0.0), (hi, y, 0.0)] + [(x, y, z) for x, z in zip(cols[::-1], env[side][::-1])])
        wk.face(b, q, "Gap", Vector((0, side, 0)))
    # (twelfth pass) and its top, under the top's pieces, dark where they lie apart
    for x0, x1, a0, a1, c0, c1 in zip(cols, cols[1:], env[-1.0], env[-1.0][1:], env[1.0], env[1.0][1:]):
        q = wk.verts(b, [(x0, -core, a0 - TOP_SINK), (x1, -core, a1 - TOP_SINK), (x1, core, c1 - TOP_SINK),
                         (x0, core, c0 - TOP_SINK)])
        wk.face(b, q, "Gap", Vector((0, 0, 1)))
    top_course(b, top, lo, hi, core, env_at, ends)
    # its ends, seen at a stack's end: a column of logs lying front to back, the face's pieces' size, each course a
    # front and a back log meeting by turns in front of and behind the middle (RM2, ninth pass)
    for base, s in [(x, t) for x, t, closing in ((lo, -1.0, ends[0]), (hi, 1.0, ends[1])) if closing]:
        e0, e1 = env_at(-1.0, base), env_at(1.0, base)
        # the dark behind them, up to each face's crown (sloping across the top as the core's does)
        q = wk.verts(b, [(base, -core, 0.0), (base, core, 0.0), (base, core, e1), (base, -core, e0)])
        wk.face(b, q, "Gap", Vector((s, 0, 0)))
        end_column(b, r, base, s, core, {-1.0: e0, 1.0: e1}, faces)
    for side, pieces in faces.items():
        out = Vector((0.0, side, 0.0))
        for kind, poly in pieces:
            outline = [(px, side * core, pz) for px, pz in poly]
            end_mat = r.choices(END_MATS, END_WEIGHTS)[0]
            depth = r.triangular(PROUD[0], PROUD[1], PROUD_MODE)
            tilt = (r.uniform(-TILT, TILT), r.uniform(-TILT, TILT))
            checks = r.choices((0, 1, 2, 3), CHECKS)[0]
            # (RM2) a piece standing over the core's top shows its back from behind the stack: barked, its sides drawn
            cx = sum(px for px, _ in poly) / len(poly)
            over = max(pz for _, pz in poly) > env_at(side, cx) + 0.005
            # (twelfth pass) a piece cut at the section's end: its sawn face runs out flush to the cut, square across
            # it, so it and the next section's piece there meet as two pieces, no rim or step along the cut
            flush = ()
            if kind.startswith("cut-"):
                kind, tilt, flush = kind[4:], (0.0, tilt[1]), (lo, hi)
            piece_end(b, outline, depth, out, end_mat, kind, tilt, checks, r,
                      heart=dark.random() < hearts and kind != "heart", backed=over, flush=flush)
    # split pieces lying across the top here and there, on the pieces' top
    for k in range(LOOSE):
        x = -half_x + LOOSE_IN + (SECTION - 2.0 * LOOSE_IN) * (k + r.uniform(0.2, 0.8)) / LOOSE
        w = SECTION / LOOSE * r.uniform(0.25, 0.4)
        z = min(crown(faces[1.0], x), crown(faces[-1.0], x))
        wk.ridge(b, x, w, z, r.uniform(0.03, 0.055), core, ("Bark", "Split", "BarkLight")[k % 3])
    ob = b.build()
    wk.finish(ob, SMOOTH)
    _round_ends(ob, lo, hi)
    wk.fit_box(ob, (-half_x, -half_y, 0.0), (half_x, half_y, HEIGHT))
    return ob


def top_course(b: hs.Builder, top: random.Random, lo: float, hi: float, core: float, env_at: object,
               ends: tuple = (True, True)) -> None:
    """(RM2) The stack's top: the top course's split pieces lying on the core's top (`env_at`), front to back or up to
    TOP_TURN off it, each its own width (0.45 to 1.6 of TOP_W), a third the stack's whole depth long and the rest in
    a front and a back piece meeting where they will (0.3 to 0.7 of the depth each); TOP_SPLIT of them lying point up,
    two pale split faces meeting at a ridge, the rest bark up and rounded (full shoulders), each its own warm bark;
    each its own height, a little higher at one end than the other, and closed at both ends by its sawn end, its face
    end at the core's face, behind the face's pieces (no lip). Over them TOP_CROSS pieces lie turned 20 to 40 degrees
    (eleventh pass), so the top is never an even row; (twelfth pass) some touch their neighbours, some lie 3 to 6 cm
    apart (the core's dark top between them) and some lie half on a neighbour. It runs from `lo` to `hi`; by a closing
    end (`ends`) its pieces lie low (TOP_BY_END), under the end's top piece, so nothing stands proud over a corner."""
    edges = [(lo, 0.0)]
    while True:
        nxt = edges[-1][0] + TOP_W * top.uniform(0.45, 1.6)
        if nxt > hi - 0.5 * TOP_W:
            edges.append((hi, 0.0))
            break
        edges.append((nxt, top.uniform(-1.0, 1.0) * core * math.tan(math.radians(TOP_TURN))))
    # (no two edges nearer than 4 cm at either face, so the pieces never cross)
    for i in range(1, len(edges)):
        (e_a, k_a), (e_b, k_b) = edges[i - 1], edges[i]
        d = e_b - e_a
        edges[i] = (e_b, min(max(k_b, k_a - d + 0.04), k_a + d - 0.04))
    if edges[-1][1] != 0.0:  # the last edge is the stack's end: square
        (e_a, k_a), (e_b, _k) = edges[-2], edges[-1]
        edges[-2] = (e_a, min(max(k_a, -(e_b - e_a) + 0.04), (e_b - e_a) - 0.04))
        edges[-1] = (e_b, 0.0)
    rounded = ((0.0, 0.0), (1.0 / 3.0, 0.75), (2.0 / 3.0, 0.75), (1.0, 0.0))
    last = ""

    def ground(x: float, y: float) -> float:
        u = (y + core) / (2.0 * core)
        return env_at(-1.0, x) + (env_at(1.0, x) - env_at(-1.0, x)) * u

    for n, ((e0, k0), (e1, k1)) in enumerate(zip(edges, edges[1:])):
        first, final = n == 0, n == len(edges) - 2
        by_end = (first and ends[0]) or (final and ends[1])
        if top.random() < TOP_WHOLE:
            spans = [(-core, core)]
        else:
            joint = core * top.uniform(-0.4, 0.4)
            spans = [(-core, joint), (joint, core)]
        for ya, yb in spans:
            split = top.random() < TOP_SPLIT and not by_end
            if split:  # point up: a wedge's two split faces, its ridge off its middle
                across = ((0.0, 0.0), (top.uniform(0.35, 0.65), 1.0), (1.0, 0.0))
                rise = (e1 - e0) * top.uniform(0.22, 0.32)
                mat = "Split"
            else:
                across = rounded
                rise = TOP_LOG * (e1 - e0) * top.uniform(0.4, 1.1) * (TOP_BY_END if by_end else 1.0)
                mat = top.choice([m for m in TOP_BARK if m != last])
            last = mat
            lift = (top.uniform(0.7, 1.0), top.uniform(0.7, 1.0))  # at its two ends
            # (twelfth pass) touching its neighbours, or narrower (a gap each side), or half on a neighbour
            lie, trim, ride = top.random(), [0.0, 0.0], [0.0, 0.0]
            if lie < TOP_APART:
                trim = [0.0 if first else top.uniform(*TOP_GAP), 0.0 if final else top.uniform(*TOP_GAP)]
            elif lie < TOP_APART + TOP_RIDE and not by_end:
                way = top.choice([w for w, ok in ((0, not first), (1, not final)) if ok] or [None])
                if way is not None:
                    trim[way] = -(e1 - e0) * TOP_RIDE_W
                    ride[way] = TOP_LOG * TOP_W * 0.6

            def at(f: float, v: float, kx: float) -> tuple:
                y = ya + (yb - ya) * v
                a, c = e0 + k0 * y / core + trim[0], e1 + k1 * y / core - trim[1]
                x = a + (c - a) * f
                base = ground(x, y) + ride[0] * (1.0 - f) + ride[1] * f
                return (x, y, base + rise * kx * (lift[0] + (lift[1] - lift[0]) * v))

            for (fa, ka), (fb, kb) in zip(across, across[1:]):
                q = wk.verts(b, [at(fa, 0.0, ka), at(fb, 0.0, kb), at(fb, 1.0, kb), at(fa, 1.0, ka)])
                wk.face(b, q, mat, Vector((0, 0, 1)))
            # its two sawn ends
            for v, way in ((0.0, -1.0), (1.0, 1.0)):
                wk.face(b, wk.verts(b, [at(f, v, k) for f, k in across]), top.choice(END_MATS), Vector((0, way, 0)))
    # (eleventh pass) a few pieces lying over the course, turned well off front to back, bark or split side up, each
    # resting on the pieces under it and closed by its sawn ends; kept inside the faces and off the ends
    for k in sorted(top.sample(range(TOP_CROSS[1]), top.randint(*TOP_CROSS))):
        w = TOP_W * top.uniform(0.7, 1.0)
        turn = math.radians(top.uniform(*TOP_CROSS_TURN)) * top.choice((-1.0, 1.0))
        half = min(top.uniform(0.25, 0.4), (core - 0.04) / math.cos(turn) - 0.5 * w * abs(math.tan(turn)))
        keep = 0.05 + half * abs(math.sin(turn)) + 0.5 * w * math.cos(turn)  # off the stack's ends
        cx = lo + keep + (hi - lo - 2.0 * keep) * (k + top.uniform(0.25, 0.75)) / TOP_CROSS[1]
        cy = top.uniform(-1.0, 1.0) * max(0.0, core - 0.04 - half * math.cos(turn) - 0.5 * w * math.sin(abs(turn)))
        axis = Vector((math.sin(turn), math.cos(turn), 0.0))
        across_v = Vector((math.cos(turn), -math.sin(turn), 0.0))
        split = top.random() < 0.4
        prof = ((0.0, 0.0), (top.uniform(0.35, 0.65), 1.0), (1.0, 0.0)) if split else rounded
        rise = w * (top.uniform(0.25, 0.32) if split else top.uniform(0.3, 0.42))
        mat = "Split" if split else top.choice(TOP_BARK)
        sink = top.uniform(0.01, 0.025)  # how far it beds down between the pieces under it

        def on(f: float, v: float, kx: float) -> tuple:
            p = Vector((cx, cy, 0.0)) + axis * (v * 2.0 - 1.0) * half + across_v * (f - 0.5) * w
            return (p.x, p.y, ground(p.x, p.y) + TOP_LOG * TOP_W * 0.75 - sink + rise * kx)

        for (fa, ka), (fb, kb) in zip(prof, prof[1:]):
            q = wk.verts(b, [on(fa, 0.0, ka), on(fb, 0.0, kb), on(fb, 1.0, kb), on(fa, 1.0, ka)])
            wk.face(b, q, mat, Vector((0, 0, 1)))
        for v, way in ((0.0, -1.0), (1.0, 1.0)):
            wk.face(b, wk.verts(b, [on(f, v, kx) for f, kx in prof] + [on(1.0, v, -0.6), on(0.0, v, -0.6)]),
                    top.choice(END_MATS), axis * way)


def _profile(kind: str, bulge: float, rz: float, r: object) -> tuple:
    """(RM2, eleventh pass) An end piece's outline out of the stack's end, from its foot to its top: (out, up) points
    (m, from the end's plane and the piece's middle) and each side's paint, "bark" or "Split" (its pale split face)."""
    lo, hi = math.radians(-86.0), math.radians(86.0)
    foot, head = (bulge * math.cos(lo), rz * math.sin(lo)), (bulge * math.cos(hi), rz * math.sin(hi))
    if kind == "round":
        pts = [(bulge * math.cos(a), rz * math.sin(a))
               for a in (math.radians(-86.0 + 172.0 * i / END_ARC) for i in range(END_ARC + 1))]
        return pts, ["bark"] * END_ARC
    def crease(a: tuple, c: tuple) -> tuple:  # (twelfth pass) a split face broken along a line, out or in
        return ((a[0] + c[0]) * 0.5 + r.choice((-1.0, 1.0)) * END_CREASE * r.uniform(0.6, 1.0),
                (a[1] + c[1]) * 0.5 + rz * r.uniform(-0.15, 0.15))

    if kind == "flat":  # split down one side: a flat pale face between its bark edges, a half to two-thirds round
        a0, a1 = math.radians(-r.uniform(30.0, 60.0)), math.radians(r.uniform(30.0, 60.0))
        p0, p1 = (bulge * math.cos(a0), rz * math.sin(a0)), (bulge * math.cos(a1), rz * math.sin(a1))
        return [foot, p0, crease(p0, p1), p1, head], ["bark", "Split", "Split", "bark"]
    if kind == "wedge":  # point out: two split faces meeting at its edge, now and then one of them its bark
        foot, head = (0.003, -rz), (0.003, rz)
        tip = (bulge * r.uniform(0.85, 1.0), rz * r.uniform(-0.35, 0.35))
        if r.random() < 0.3:  # one side its bark, rounded
            return [foot, crease(foot, tip), tip, head], ["bark", "bark", "Split"]
        return [foot, crease(foot, tip), tip, crease(tip, head), head], ["Split"] * 4
    # a quarter: a split face out from its foot (or down from its top), then its bark round
    p0, p1 = (0.003, -rz), (bulge * r.uniform(0.85, 1.0), -rz * r.uniform(0.3, 0.55))
    pts = [p0, crease(p0, p1), p1, (bulge * 0.72, rz * 0.55), (bulge * 0.12, rz)]
    mats = ["Split", "Split", "bark", "bark"]
    if r.random() < 0.5:  # bark below, split face on top
        pts = [(x, -z) for x, z in reversed(pts)]
        mats = mats[::-1]
    return pts, mats


def _reach(pieces: list, base: float, s: float, z: float) -> float:
    """How far in from the end (`base`) a face's outermost piece stands at height `z`; END_REACH when none does."""
    best = END_REACH
    for _, poly in pieces:
        for (x0, z0), (x1, z1) in zip(poly, poly[1:] + poly[:1]):
            if (z0 - z) * (z1 - z) <= 0.0 and z0 != z1:
                x = x0 + (x1 - x0) * (z - z0) / (z1 - z0)
                best = min(best, s * base - s * x)
    return max(0.0, best)


def end_column(b: hs.Builder, r: object, base: float, s: float, core: float, crest: dict, faces: dict) -> None:
    """(RM2, ninth to twelfth passes) A stack's closed end (`base`, s: -1 or 1): courses of split pieces from the ground
    to each face's crest (END_TOP), each END_H high, tilted a little (the ground course level), set in or out
    (END_COURSE_SET) and turned (END_TURN) its own way, one piece in four a long one (END_LONG, END_LONG_OUT), a front
    and a back piece lying front to back and meeting in front of or behind the middle by turns, so the joints stagger,
    an END_GAP between them; each its own kind (END_KINDS: a round log, a log split down one side, a wedge point out, a
    quarter), its split faces flat and pale with crisp edges, its bark warm grey-brown and drawn smooth; each set its
    own way in from the end (END_SETIN), a little fuller or slimmer at its joint end, and closed at both ends by its
    sawn end: a round log's a half round of END_CAP sides, a bark rim round a sawn face; at the face, in the face's
    plane, its flat side drawn in to the face's pieces beside it (sampled at its foot, middle and top), so no dark seam
    runs up the corner. Each piece a closed shell with the end's dark behind it, so nothing is seen through."""
    # the lines between the courses: each its own height and tilt, the next course lying on the one under it (so
    # no course stands into the next or leaves a slot under it at a face), the ground's level, the top's over the crest
    lo = min(crest.values())
    lines, z = [(0.0, 0.0)], 0.0
    while True:
        h = r.uniform(*END_H)
        if z + h > lo - END_H[0] * 0.6:
            break
        z += h
        z_p, t_p = lines[-1]
        t = math.tan(math.radians(r.uniform(*END_TILT))) * r.choice((-1.0, 1.0))
        t = min(max(t, t_p - (z - z_p - END_H[0] * 0.75) / core), t_p + (z - z_p - END_H[0] * 0.75) / core)
        lines.append((z, t))

    def line(k: int, y: float) -> float:
        if k < len(lines):
            return lines[k][0] + lines[k][1] * y
        return crest[-1.0] + (crest[1.0] - crest[-1.0]) * (y + core) / (2.0 * core) + END_TOP

    way = r.choice((-1.0, 1.0))
    for k in range(len(lines)):
        way = -way
        joint = way * core * r.uniform(*END_JOINT)
        gap = r.uniform(*END_GAP) * 0.5
        # (twelfth pass) the course set in or out its own way, and turned off front to back seen from above
        c_set = r.uniform(-END_COURSE_SET, END_COURSE_SET)
        c_turn = math.tan(math.radians(r.uniform(-END_TURN, END_TURN)))
        for side in (1.0, -1.0):
            y_face, y_joint = side * (core + END_PROUD), joint + side * gap
            hh = (line(k + 1, 0.0) - line(k, 0.0)) * 0.5  # the course's half height at its middle
            if r.random() < END_LONG:  # a long piece, a log split down one side, pushed on past the others
                kind, bulge = "flat", END_OUT + c_set
                pts, mats = _profile(kind, bulge, 1.0, r)
                more = r.uniform(*END_LONG_OUT)  # its bark top and foot run straight out to its split face
                pts = [(0.003, pts[0][1])] + [(x + more, z) for x, z in pts] + [(0.003, pts[-1][1])]
                mats = ["bark"] + mats + ["bark"]
                bulge += more
            else:
                kind = r.choices(END_KINDS, END_KIND_W)[0]
                bulge = max(END_OUT * 0.4, END_OUT + c_set - r.uniform(*END_SETIN))
                if kind == "wedge":  # no thin blade: its point at most END_WEDGE of the course's half height out
                    bulge = min(bulge, hh * END_WEDGE)
                pts, mats = _profile(kind, bulge, 1.0, r)
            own = r.choice(END_BARK)
            swell = r.uniform(0.88, 1.06)  # at its joint end

            def at(y: float, out: float, up: float) -> Vector:
                z0, z1 = line(k, y), line(k + 1, y)
                turned = max(0.4, (bulge + c_turn * y) / bulge)  # the course turned
                return Vector((base + s * min(END_SET, max(0.003, out * turned)), y,
                               (z0 + z1) * 0.5 + (z1 - z0) * 0.5 * up))

            outer = [at(y_face, ox, oz) for ox, oz in pts]
            inner = [at(y_joint, ox * swell, oz) for ox, oz in pts]
            for i, mat in enumerate(mats):
                q = wk.verts(b, [outer[i], inner[i], inner[i + 1], outer[i + 1]])
                way_out = Vector((s * 0.6, 0.0, (pts[i][1] + pts[i + 1][1]) * 0.5))
                wk.face(b, q, own if mat == "bark" else mat, way_out)
            if k == len(lines) - 1:  # the top piece's inside, over the end's dark: its split side, closed
                q = wk.verts(b, [outer[0], inner[0], inner[-1], outer[-1]])
                wk.face(b, q, "Split", Vector((-s, 0.0, 0.0)))
            # its sawn end at the joint, facing along it, and at the face (drawn in to the face's pieces)
            for y, ring, fac, at_face in ((y_joint, inner, swell, False), (y_face, outer, 1.0, True)):
                fy = Vector((0.0, -side if not at_face else side, 0.0))
                inward = []
                if at_face:
                    for t in (0.9, 0.0, -0.9):
                        p = at(y, 0.0, t)
                        p.x = base - s * min(END_REACH, _reach(faces[side], base, s, p.z) + 0.01)
                        inward.append(p)
                if kind == "round":
                    cap = [at(y, bulge * fac * math.cos(a), math.sin(a))
                           for a in (math.radians(-86.0 + 172.0 * i / END_CAP) for i in range(END_CAP + 1))]
                    sawn = []
                    for i in range(END_CAP_IN + 1):
                        a = math.radians(-86.0 + 172.0 * i / END_CAP_IN)
                        f = 1.0 if i in (0, END_CAP_IN) else 1.0 - END_RIM
                        sawn.append(at(y, bulge * fac * f * math.cos(a), f * math.sin(a)) + fy * 0.003)
                    if at_face:
                        sawn[0].x, sawn[-1].x = inward[-1].x, inward[0].x
                    wk.face(b, wk.verts(b, _wound(cap + inward, fy)), "Rim")
                    wk.face(b, wk.verts(b, _wound(sawn, fy)), r.choices(END_MATS, END_WEIGHTS)[0])
                else:
                    wk.face(b, wk.verts(b, _wound(list(ring) + inward, fy)), r.choices(END_MATS, END_WEIGHTS)[0])


def _round_ends(ob: object, lo: float, hi: float) -> None:
    """(RM2, tenth and eleventh passes) The end pieces' bark drawn smooth (no facet steps) and their split faces crisp:
    every edge between two of their sides past the stack's body (`lo` to `hi`; not facing a face, so their sawn ends
    stay crisp by angle) smooth where both are bark, sharp where either is a split face."""
    me = ob.data
    sharp = me.attributes.get("sharp_edge")
    if sharp is None:
        sharp = me.attributes.new("sharp_edge", "BOOLEAN", "EDGE")
    barks = set(END_BARK)
    names = [m.name if m else "" for m in me.materials]
    side = [(p.center.x < lo - 0.002 or p.center.x > hi + 0.002) and abs(p.normal.y) < 0.7 for p in me.polygons]
    bark = [names[p.material_index] in barks for p in me.polygons]
    owners = {}
    for p in me.polygons:
        for key in p.edge_keys:
            owners.setdefault(key, []).append(p.index)
    for e in me.edges:
        ps = owners.get(e.key, [])
        if len(ps) == 2 and side[ps[0]] and side[ps[1]]:
            sharp.data[e.index].value = not (bark[ps[0]] and bark[ps[1]])


def _wound(points: list, outward: Vector) -> list:
    """An outline's points in the order that faces it `outward`, by its whole area (Newell), so a creased, concave
    outline is never turned the wrong way by its first corner."""
    n = Vector()
    for i, p in enumerate(points):
        a, c = Vector(p), Vector(points[(i + 1) % len(points)])
        n += Vector(((a.y - c.y) * (a.z + c.z), (a.z - c.z) * (a.x + c.x), (a.x - c.x) * (a.y + c.y)))
    return list(points) if n.dot(outward) >= 0.0 else list(reversed(points))


def lay_face(r: object, lo: float, hi: float, top_at: object, cut: tuple = (False, False)) -> list:
    """A face's pieces' ends (kind, outline as (x, z) points) from x = `lo` to `hi`, from the ground up to the
    stack's top (`top_at(x)`, each piece wholly under it, never stretched to it), stacked as
    by hand: each piece in turn set where its middle rests lowest (a split piece tried point up, point down and, now
    and then, on its side, so the wedges lock together), on the ground or on the pieces under it, GAP above them;
    until FULL pieces in a row fit nowhere under the top. No outline crosses another (asserted). At an end `cut`
    (where the next section of the stack carries on: RM2, twelfth pass) a piece may run up to EDGE_CUT of its width
    past it, cut off flush there (its kind "cut-" and what it was: its bark rim and sides only along what is left of
    its arc, its sawn face running out to the cut), so it and the next section's cut pieces meet as pieces do, no
    line up the stack where the sections meet."""
    h = (HEIGHT - 0.05) / ROWS
    pieces = []
    misses = 0
    while misses < FULL:
        best = None
        for kind, whole in piece_outline(r, h):
            wide0 = max(px for px, _ in whole)
            over = (wide0 * EDGE_CUT if cut[0] else -GAP, wide0 * EDGE_CUT if cut[1] else -GAP)
            for i in range(int((hi - lo + over[0] + over[1] - wide0) / LAY_STEP) + 1):
                x0 = lo - over[0] + i * LAY_STEP
                poly = [(px + x0, pz) for px, pz in whole]
                if (cut[0] and x0 < lo) or (cut[1] and x0 + wide0 > hi):
                    poly = _clip_x(poly, lo, hi)
                    if len(poly) < 3:
                        continue
                x = min(px for px, _ in poly)
                poly = [(px - x, pz) for px, pz in poly]
                wide = max(px for px, _ in poly)
                if wide < wide0 * (1.0 - EDGE_CUT) - 1e-9:
                    continue
                z = rest(pieces, poly, x, wide)
                if any(pz + z > top_at(px + x) - h * EDGE for px, pz in poly):
                    continue
                mid = _centroid_z(poly)
                if best is None or z + mid < best[0] - 1e-6:
                    best = (z + mid, kind if wide >= wide0 - 1e-9 else "cut-" + kind,
                            [(px + x, pz + z) for px, pz in poly])
        if best is None:
            misses += 1
            continue
        misses = 0
        assert not any(overlaps(best[2], q) for _, q in pieces), "a piece's end crosses another"
        pieces.append((best[1], best[2]))
    # then smaller pieces pushed into the holes left, as a stack is filled by hand: at each place tried, the biggest
    # that fits
    for _ in range(FILL_TRIES):
        x, z = r.uniform(lo, hi), r.uniform(0.0, HEIGHT)
        if z > top_at(x):
            continue
        near = [q for _, q in pieces if min(px for px, _ in q) - 0.3 < x < max(px for px, _ in q) + 0.3
                and min(pz for _, pz in q) - 0.3 < z < max(pz for _, pz in q) + 0.3]
        for scale in FILL_SIZES:
            done = False
            for kind, poly in piece_outline(r, h * scale, FILL_ARC, True):
                wide, tall = max(px for px, _ in poly), max(pz for _, pz in poly)
                cand = [(px + x - wide * 0.5, pz + z - tall * 0.5) for px, pz in poly]
                if min(px for px, _ in cand) < lo + GAP or max(px for px, _ in cand) > hi - GAP:
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
    assert all(lo - 1e-9 <= px <= hi + 1e-9 for _, q in pieces for px, _ in q), "a piece past the section's end"
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


def _clip_z(poly: list, top: float) -> list:
    """A convex outline cut level at z = `top`, its points in order (Sutherland-Hodgman)."""
    out = []
    for i in range(len(poly)):
        a, c = poly[i], poly[(i + 1) % len(poly)]
        if a[1] <= top:
            out.append(a)
        if (a[1] <= top) != (c[1] <= top):
            t = (top - a[1]) / (c[1] - a[1])
            out.append((a[0] + (c[0] - a[0]) * t, top))
    return out


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
              checks: int = 0, r: object = None, heart: bool = False, backed: bool = False, flush: tuple = ()) -> None:
    """A piece's end standing `depth` proud of the stack's dark core (outline: points on the core's face), as a solid
    log end (WS1, the owner: the stacks read flat): its sides run back to the core where it stands out enough to show
    them (SHOWS), and its end face is sawn a little off square (`tilt`: how much further out it stands per metre across
    and up the face). A "wedge" (a split piece, a pie slice of its log, as most in the photos: its outline the heart's
    point, then its bark arc) has its arc barked and a rim of bark (BARK_RIM) inside it on its face, its split
    sides pale, and `checks` drying cracks from its heart (each laid out with `r`); a "round" a thin ring of bark
    round its sawn face; a "heart" (split from the log's middle) no bark at all. A point on one of the x lines in
    `flush` (a piece cut at the section's end) keeps to that line as the rim is drawn in, so the sawn face runs out to
    the cut with no rim along it."""
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
            if any(abs(base[i].x - f) < 1e-6 and abs(base[j].x - f) < 1e-6 for f in flush):
                mat = end_mat  # its side along the cut: the sawn face's paint, so a step there reads as its face
            elif kind == "round" or i in bark:
                mat = "Bark"
            else:
                mat = "Split" if kind == "wedge" else "Heart"
            wk.face(b, [back_ids[i], back_ids[j], front_ids[j], front_ids[i]], mat, side_out)
    if kind == "heart":
        wk.face(b, front_ids, end_mat, out)
        return
    def keep(p: Vector, q: Vector) -> Vector:
        return Vector((p.x, q.y, q.z)) if any(abs(p.x - f) < 1e-6 for f in flush) else q

    if kind == "round":
        wk.face(b, front_ids, "Bark", out)
        inner = [keep(p, p.lerp(c, RIM)) for p in front]
        wk.face(b, wk.verts(b, [p + out * 0.004 for p in inner]), end_mat, out)
        return
    if max((p - front[0]).length for p in front[1:]) < RIM_MIN:
        # (RM2) a small piece: its rim of bark would be a hairline, so its sawn face runs to its arc
        inner = front
        wk.face(b, front_ids, end_mat, out)
    else:
        wk.face(b, front_ids, "Rim", out)
        # the sawn face inside its bark: the arc drawn in toward the heart by BARK_RIM of its radius
        inner = [p if i == 0 else keep(p, front[0].lerp(p, 1.0 - BARK_RIM)) for i, p in enumerate(front)]
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
        ends = ENDS.get(name, (False, False))
        ob = cordwood(seed, 1.0, ends)
        over = _tris(ob) - int(CORD_BUDGET * 0.995)
        if over > 0:
            ob = cordwood(seed, max(0.0, 1.0 - over / max(1, HEARTS[0])), ends)
        mk.report(ob, name, CORD_BUDGET)
        print("  wrote", mk.export_prop(ob, name))
    ob = boards()
    mk.report(ob, "boards", BOARD_BUDGET)
    print("  wrote", mk.export_prop(ob, "boards"))


if __name__ == "__main__":
    main()
