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
cut down; each end courses of round logs the face's pieces' size lying front to back, each course tilted 1 to 3
degrees, a front and a back log a course meeting at a step (the fuller one's sawn end showing), each log set in up
to 5 cm its own way, half of them a pale split side out, their bark warm grey-brown; each log closed at its face by
a half-round sawn end (8 sides, a bark rim) flush with the face's sawn ends, so a column of log ends shows at each
corner; the top pieces lying front to back, a third the whole depth, the rest two meeting off the middle, turned up
to 10 degrees, pale split ridges and dark bark, some stopping short of a face. The same budget.

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
SECTIONS = (("cordwood", 1300), ("cordwood_b", 1301), ("cordwood_c", 1304))
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
END_SET = 0.12          # m the face's pieces and the stack's end stand inside the section's end; the end logs bulge out
                        # of it up to this, their sawn ends filling the face to the end (RM2)
END_NEAR = 0.07          # m at most a log end's flat side is drawn in over the dark to the face's last piece
END_ARC = 4             # a log's side's segments round (43 degrees each, drawn smooth all round: _round_ends)
END_CAP = 7             # its sawn end's sides round (a half round: 8 with its flat side), and the sawn face's inside its rim
END_CAP_IN = 3
END_RIM = 0.14          # the bark rim's share of the sawn end's radius
END_H = (0.115, 0.15)   # m an end log's height: the face's pieces' size (RM2, ninth pass; were up to 0.43 m)
END_TILT = (1.0, 3.0)   # degrees a course lies off level, either way, front to back (the ground course level)
END_SETIN = (0.0, 0.05)  # m each log stands in from the end, its own way, so the end is ragged
END_STEP = 0.2          # the narrower log at a joint: this much less full than the other, which shows its sawn end
END_SPLIT = 0.5         # the share of end logs showing a pale split side out, between barked edges
END_BARK = ("Bark", "Rim", "BarkFurrow", "BarkLight", "Bark")  # their bark: warm grey-brown, never neutral grey
END_CREASE = (0.62, 0.78)  # an end log's bark drawn in this much along one line: a crease along it (RM2)
END_PROUD = (0.003, 0.02)  # m past the core an end log's sawn end stands, out with the face's sawn ends
END_TOUCH = 0.004       # m each end log's side runs past the line where it meets the next
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
              "EndHeart": 0x7C6838}
END_MATS = tuple(k for k in END_PAINTS if k not in ("Rim", "EndHeart"))  # Rim: a split piece's bark, a warm brown;
# EndHeart: its heart, darker (RM2, the photo's pieces)
HEART_SHARE = 0.45      # how far out from a wedge's point its dark heart reaches
TOP_LOG = 0.4           # the top course's logs rise this share of their width, at most, between the faces (RM2)
TOP_W = 0.16            # m a top piece's width, about: each 0.5 to 1.5 of it (RM2: was 0.133)
TOP_TURN = 10.0         # degrees a top piece may lie off front to back (RM2, tenth pass)
TOP_WHOLE = 0.33        # the share of the top's pieces the stack's whole depth long
SPIKE = 0.04            # m a face piece may stand over the top course beside it; a taller one is cut down
TOP_BARK = ("Bark", "BarkDark", "BarkFurrow", "Rim", "BarkDark")  # the top's pieces' bark, dark, never the
                        # same as the piece beside it (RM2)
TOP_SPLIT = 0.4         # the share of the top's pieces lying point up: pale split sides meeting at a ridge (RM2)
TOP_SHORT = (0.1, 0.2)  # m a top piece may stop short of a face, a piece's back showing beyond it (RM2)
TOP_BACK = "BarkGrey"   # that piece's back: weathered bark, paler than the top's
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
    # the stack's top along the section: near level (RM2), a few centimetres lower here and there, never stepping more
    # than SAG_STEP from one point to the next, its highest point at the cell's top
    xs = [-half_x + SECTION * k / (TOPS - 1) for k in range(TOPS)]
    dips = [r.uniform(0.0, SAG)]
    for _ in xs[1:]:
        dips.append(min(SAG, max(0.0, dips[-1] + r.uniform(-SAG_STEP, SAG_STEP))))
    tops = [HEIGHT - 0.05 - (d - min(dips)) for d in dips]

    def top_at(x: float) -> float:
        t = min(max((x + half_x) / SECTION * (TOPS - 1), 0.0), TOPS - 1.0)
        k = min(TOPS - 2, int(t))
        return tops[k] + (tops[k + 1] - tops[k]) * (t - k)

    # each face's pieces (lay_face), rigid, under the top, stopping END_SET short of the section's ends, where the end
    # logs' sawn ends fill the face (RM2: the pieces ran on past the end, cut off there, and showed edge on as cards)
    lim = half_x - END_SET
    faces = {side: lay_face(r, lim, top_at) for side in (1.0, -1.0)}
    # (RM2) a piece standing up out of the top course (a wedge on its point, a thin shard) is cut down: the face's
    # crown read every 2 cm and opened (its narrow peaks cut down to their neighbours: the lowest over SPIKE_W each
    # way, then the highest of those), and a piece whose top stands more than SPIKE over that line cut level there, a
    # piece with its point broken off lying on its flat (its sawn end then plain, no bark rim), or taken off when
    # little of it is left; so the top course lies near level and nothing stands up out of it
    edge = lim - 2.0 * GAP  # (read inside the pieces' ends, where every place along the face has a piece over it)
    grid = [-edge + 0.02 * k for k in range(int(2.0 * edge / 0.02) + 1)]
    w = int(round(SPIKE_W / 0.02))

    def opened(line: list) -> list:
        low = [min(line[max(0, i - w):i + w + 1]) for i in range(len(line))]
        return [max(low[max(0, i - w):i + w + 1]) for i in range(len(line))]

    def under(level: list, x: float) -> float:
        t = min(max((x + edge) / 0.02, 0.0), len(level) - 1.0 - 1e-9)
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
    # the dark core: what shows between the pieces, its top along each face just under that face's highest pieces, so
    # the stack's top is the pieces' own; each the highest of three reads about it (read a little in from each end,
    # where the pieces stand GAP short of it, and there every piece out to the end, so the core's top never falls to
    # the ground at the end)
    cols = [-lim + 2.0 * lim * k / CORE_COLS for k in range(CORE_COLS + 1)]
    step = lim / CORE_COLS

    def env_read(pieces: list, x: float) -> float:
        reads = [min(max(x + step * d, -lim + END_IN), lim - END_IN) for d in (-0.5, 0.0, 0.5)]
        if abs(x) > lim - 1e-6:
            reads += [math.copysign(lim - 2.0 * GAP - END_IN * k / 8.0, x) for k in range(8)]
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
        t = min(max((x + lim) / (2.0 * lim) * CORE_COLS, 0.0), CORE_COLS - 1e-9)
        k = int(t)
        return env[side][k] + (env[side][k + 1] - env[side][k]) * (t - k)

    # the core's sides, under each face's pieces, out to the stack's end (never past it, so no dark flap shows
    # there): each one face, its top along the pieces' crown
    for side in faces:
        y = side * core
        q = wk.verts(b, [(-lim, y, 0.0), (lim, y, 0.0)] + [(x, y, z) for x, z in zip(cols[::-1], env[side][::-1])])
        wk.face(b, q, "Gap", Vector((0, side, 0)))
    top_course(b, top, lim, core, env_at)
    # its ends, seen at a stack's end: a column of logs lying front to back, the face's pieces' size, each course a
    # front and a back log meeting by turns in front of and behind the middle (RM2, ninth pass)
    for base, s in ((-lim, -1.0), (lim, 1.0)):
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
    _round_ends(ob, lim)
    wk.fit_box(ob, (-half_x, -half_y, 0.0), (half_x, half_y, HEIGHT))
    return ob


def top_course(b: hs.Builder, top: random.Random, lim: float, core: float, env_at: object) -> None:
    """(RM2) The stack's top: the top course's split pieces lying on the core's top (`env_at`), front to back or up to
    TOP_TURN off it, each its own width (0.5 to 1.5 of TOP_W), a third the stack's whole depth long and the rest in
    a front and a back piece meeting where they will (0.3 to 0.7 of the depth each); TOP_SPLIT of them lying point up,
    two pale split faces meeting at a ridge, the rest bark up and rounded (full shoulders), each its own warm bark;
    each its own height, a little higher at one end than the other, and closed at both ends by its sawn end, its face
    end at the core's face, behind the face's pieces (no lip); now and then one stops TOP_SHORT short of its face, the
    back of the piece under it showing beyond. It stops at the stack's end (`lim`); the pieces by the ends lie lower
    and bark up, so nothing stands proud over a corner."""
    edges = [(-lim, 0.0)]
    while True:
        nxt = edges[-1][0] + TOP_W * top.uniform(0.5, 1.5)
        if nxt > lim - 0.5 * TOP_W:
            edges.append((lim, 0.0))
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
    for n, ((e0, k0), (e1, k1)) in enumerate(zip(edges, edges[1:])):
        by_end = n == 0 or n == len(edges) - 2
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
                rise = TOP_LOG * (e1 - e0) * top.uniform(0.4, 1.1) * (0.6 if by_end else 1.0)
                mat = top.choice([m for m in TOP_BARK if m != last])
            last = mat
            short = [0.0, 0.0]  # how far short of the -y and the +y face it stops
            if top.random() < 0.3:
                at_face = [k for k, on in ((0, ya <= -core + 1e-6), (1, yb >= core - 1e-6)) if on]
                short[top.choice(at_face)] = top.uniform(*TOP_SHORT)
            ya, yb = ya + short[0], yb - short[1]
            lift = (top.uniform(0.7, 1.0), top.uniform(0.7, 1.0))  # at its two ends

            def at(f: float, v: float, kx: float) -> tuple:
                y = ya + (yb - ya) * v
                a, c = e0 + k0 * y / core, e1 + k1 * y / core
                x = a + (c - a) * f
                u = (y + core) / (2.0 * core)
                z = env_at(-1.0, x) + (env_at(1.0, x) - env_at(-1.0, x)) * u
                return (x, y, z + rise * kx * (lift[0] + (lift[1] - lift[0]) * v))

            for (fa, ka), (fb, kb) in zip(across, across[1:]):
                q = wk.verts(b, [at(fa, 0.0, ka), at(fb, 0.0, kb), at(fb, 1.0, kb), at(fa, 1.0, ka)])
                wk.face(b, q, mat, Vector((0, 0, 1)))
            # its two sawn ends
            for v, way in ((0.0, -1.0), (1.0, 1.0)):
                wk.face(b, wk.verts(b, [at(f, v, k) for f, k in across]), top.choice(END_MATS), Vector((0, way, 0)))
            # beyond a piece stopping short of its face: the back of the piece under it, flat on the core's top
            for v, gap, face_y in ((0.0, short[0], -core), (1.0, short[1], core)):
                if gap:
                    pts = [at(0.0, v, 0.0), at(1.0, v, 0.0)]
                    for e, k in ((e1, k1), (e0, k0)):
                        x = e + k * face_y / core
                        pts.append((x, face_y, env_at(math.copysign(1.0, face_y), x)))
                    wk.face(b, wk.verts(b, pts), TOP_BACK, Vector((0, 0, 1)))


def end_column(b: hs.Builder, r: object, base: float, s: float, core: float, crest: dict, faces: dict) -> None:
    """(RM2, ninth and tenth passes) A stack's end (`base`, s: -1 or 1): courses of logs from the ground to each face's
    crest, each END_H high and tilted a little (the ground course level), a front and a back log lying front to back
    and meeting at a joint in front of or behind the middle by turns, so the joints stagger; at the joint the one
    log stands END_STEP fuller than the other and shows its sawn end there (a real break, not a colour change); each
    log set its own way in from the end (END_SETIN), its bark round out of the end (drawn smooth all round, a crease
    along it towards the joint, twisting a little), warm brown bark or, on about half, a pale split side between
    barked edges; each closed at its face by its sawn end, a half round of END_CAP sides, a bark rim round a sawn face,
    in the face's plane with its flat side drawn in to the face's last piece. Each log a closed shell with the end's
    dark behind it, so nothing is seen through it."""
    lo = min(crest.values())
    z, courses = 0.0, []
    while True:
        h = r.uniform(*END_H)
        if z + h > lo - END_H[0] * 0.6:
            courses.append((z, None))  # the top course: up to each face's crest
            break
        courses.append((z, z + h))
        z += h
    way = r.choice((-1.0, 1.0))
    for k, (z0, z1) in enumerate(courses):
        way = -way
        joint = way * core * r.uniform(*END_JOINT)
        tilt = math.tan(math.radians(r.uniform(*END_TILT))) * r.choice((-1.0, 1.0)) if k else 0.0
        crease, deep = r.randrange(1, END_ARC), r.uniform(*END_CREASE)
        sharp = r.choice((0.75, 0.9, 1.0, 1.0))
        turn = r.uniform(-15.0, 15.0)
        big = r.choice((-1.0, 1.0))  # the log standing fuller at the joint
        for side in (1.0, -1.0):
            a0 = z0 - (END_TOUCH if k else 0.0)
            a1 = (z1 if z1 is not None else crest[side]) + END_TOUCH
            y_face = side * (core + r.uniform(*END_PROUD))
            bulge = END_SET * r.uniform(0.85, 1.0) - r.uniform(*END_SETIN)
            if side != big:
                bulge = min(bulge, END_SET * 0.85 - END_SETIN[1])
            split = r.random() < END_SPLIT
            own = r.choice(END_BARK)

            def zc_at(y: float) -> float:
                return (a0 + a1) * 0.5 + tilt * y

            def ring(y: float, scale: float, shaped: bool) -> list:
                rz = (a1 - a0) * 0.5 * (scale ** 0.5)
                pts = []
                for i in range(END_ARC + 1):
                    a = math.radians(-86.0 + 172.0 * i / END_ARC)
                    if shaped:  # towards the joint: twisting, fuller or rounder, creased
                        out = bulge * scale * max(0.0, math.cos(a - math.radians(turn))) ** sharp
                        out *= deep if i == crease else 1.0
                    else:  # at the face: the half round its sawn end closes
                        out = bulge * scale * math.cos(a)
                    pts.append(Vector((base + s * min(END_SET, max(0.003, out)), y, zc_at(y) + rz * math.sin(a))))
                return pts

            outer = ring(y_face, 1.0, False)
            inner = ring(joint, 1.0 if side == big else 1.0 - END_STEP, True)
            for i in range(END_ARC):
                q = wk.verts(b, [outer[i], inner[i], inner[i + 1], outer[i + 1]])
                a = math.radians(-86.0 + 172.0 * (i + 0.5) / END_ARC)
                if split and 0 < i < END_ARC - 1:
                    mat = "Split"  # a split side out, between its barked edges
                elif i == crease:
                    mat = "BarkFurrow" if own != "BarkFurrow" else "BarkDark"  # a darker furrow beside its crease
                else:
                    mat = own
                wk.face(b, q, mat, Vector((s * math.cos(a), 0.0, math.sin(a))))
            if side == big:
                # its sawn end at the joint, where the other log, narrower, butts against it
                wk.face(b, wk.verts(b, _wound(inner, Vector((0.0, -side, 0.0)))), r.choices(END_MATS, END_WEIGHTS)[0])
            # its sawn end at the face: a half round of END_CAP sides round the log's own (the log inside it), a bark
            # rim round a sawn face, in the face's plane, its flat side (split) drawn in over the dark to the face's
            # last piece, so no dark seam runs up the corner
            fy = Vector((0.0, side, 0.0))
            near = [s * base - max(s * px for px, _ in poly) for _, poly in faces[side]
                    if min(pz for _, pz in poly) < a1 and max(pz for _, pz in poly) > a0]
            inset = min(max(0.0, min(near, default=END_NEAR)) + 0.012, END_NEAR)
            zc, rz = zc_at(y_face), (a1 - a0) * 0.5
            cap, sawn = [], []
            for i in range(END_CAP + 1):
                a = math.radians(-86.0 + 172.0 * i / END_CAP)
                cap.append(Vector((base + s * min(END_SET, max(0.003, bulge * math.cos(a))), y_face,
                                   zc + rz * math.sin(a))))
            for i in range(END_CAP_IN + 1):
                a = math.radians(-86.0 + 172.0 * i / END_CAP_IN)
                f = 1.0 if i in (0, END_CAP_IN) else 1.0 - END_RIM
                sawn.append(Vector((base + s * max(0.003, bulge * f * math.cos(a)), y_face + side * 0.003,
                                    zc + rz * f * math.sin(a))))
            for p in (cap[0], cap[-1], sawn[0], sawn[-1]):
                p.x = base - s * inset
            wk.face(b, wk.verts(b, _wound(cap, fy)), "Rim")
            wk.face(b, wk.verts(b, _wound(sawn, fy)), r.choices(END_MATS, END_WEIGHTS)[0])


def _round_ends(ob: object, lim: float) -> None:
    """(RM2, tenth pass) The end logs' bark drawn smooth all round (no facet steps), crease and all: every edge between
    two of their sides past the stack's end (`lim`) and not facing a face (their sawn ends stay crisp)."""
    me = ob.data
    sharp = me.attributes.get("sharp_edge")
    if sharp is None:
        return
    side = [abs(p.center.x) > lim + 0.002 and abs(p.normal.y) < 0.7 for p in me.polygons]
    owners = {}
    for p in me.polygons:
        for key in p.edge_keys:
            owners.setdefault(key, []).append(p.index)
    for e in me.edges:
        ps = owners.get(e.key, [])
        if len(ps) == 2 and side[ps[0]] and side[ps[1]]:
            sharp.data[e.index].value = False


def _wound(points: list, outward: Vector) -> list:
    """An outline's points in the order that faces it `outward`, by its whole area (Newell), so a creased, concave
    outline is never turned the wrong way by its first corner."""
    n = Vector()
    for i, p in enumerate(points):
        a, c = Vector(p), Vector(points[(i + 1) % len(points)])
        n += Vector(((a.y - c.y) * (a.z + c.z), (a.z - c.z) * (a.x + c.x), (a.x - c.x) * (a.y + c.y)))
    return list(points) if n.dot(outward) >= 0.0 else list(reversed(points))


def lay_face(r: object, half_x: float, top_at: object) -> list:
    """A face's pieces' ends (kind, outline as (x, z) points) from x = -half_x to half_x, from the ground up to the
    stack's top (`top_at(x)`, each piece wholly under it, never stretched to it), stacked as
    by hand: each piece in turn set where its middle rests lowest (a split piece tried point up, point down and, now
    and then, on its side, so the wedges lock together), on the ground or on the pieces under it, GAP above them;
    until FULL pieces in a row fit nowhere under the top. No outline crosses another (asserted)."""
    h = (HEIGHT - 0.05) / ROWS
    pieces = []
    misses = 0
    while misses < FULL:
        best = None
        for kind, whole in piece_outline(r, h):
            wide = max(px for px, _ in whole)
            for i in range(int((2.0 * (half_x - GAP) - wide) / LAY_STEP) + 1):
                x = -half_x + GAP + i * LAY_STEP
                z = rest(pieces, whole, x, wide)
                if any(pz + z > top_at(px + x) - h * EDGE for px, pz in whole):
                    continue
                mid = _centroid_z(whole)
                if best is None or z + mid < best[0] - 1e-6:
                    best = (z + mid, kind, [(px + x, pz + z) for px, pz in whole])
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
