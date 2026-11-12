"""Subway's balustrade railing round the spiral stair's hole (SM2, model #18), after the owner's photos
(art/references/maps/subway/18-railing/): dark grey powder-coated steel, square bars between a round-topped capping
rail and a flat foot rail, a square post with a floor plate between panels.

A kit, not one model: the railing's bars and rails are Railings.parts (RailingConfig), the same boxes a BB meets, so
MapLevel fits each piece to its part's box (what you see is what stops a BB) and these keep only the shape inside it:
- railing_bar.glb: one bar, a chamfered square, built 1 m tall (fitted to each bar's box);
- railing_top.glb: the capping, its top rounded over the rail's whole depth, built 1 m long along x;
- railing_foot.glb: the foot rail, a flat bar with chamfered top edges, 1 m long along x;
- railing_post.glb: a post, a chamfered square as wide along the run as a bar (MapLevel stands it on a panel's end
  bar, so it adds no steel a BB could meet), deeper across it, built 1 m tall.
The posts' floor plates are plain boxes MapLevel draws in the post's paint.

Budget 800 triangles a 5 m run (37 bars, 3 posts and their plates, both rails): about 730.

Usage: python3 -I tools/blender/maps/railing.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import transit_kit as tk  # noqa: E402
import map_kit as mk  # noqa: E402

RUN_BUDGET = 800
BAR = 0.025            # RailingConfig.bar_width
RAIL_H = 0.04          # RailingConfig.rail_height
DEPTH = 0.12           # the Subway's railing blocks' depth
POST_ACROSS = 0.05
CHAMFER = 0.15         # of a bar's width
PAINT = 0x464A4E       # dark grey powder coat, as the photos'
CAP_SEG = 6


def chamfered(w: float, d: float, c: float) -> list:
    """A chamfered rectangle `w` (x) by `d` (z) round its middle, its corners cut `c`, counter-clockwise from +y."""
    hw, hd = w / 2, d / 2
    return [(hw - c, -hd), (hw, -hd + c), (hw, hd - c), (hw - c, hd), (-hw + c, hd), (-hw, hd - c), (-hw, -hd + c),
            (-hw + c, -hd)]


def face(m: tk.Mesh, pts: list, centre: tuple, tones: tuple = None) -> None:
    """A convex piece's face, wound counter-clockwise seen from outside (from `centre`, a point inside the piece)."""
    n = [0.0, 0.0, 0.0]
    for i, a in enumerate(pts):
        b = pts[(i + 1) % len(pts)]
        n[0] += (a[1] - b[1]) * (a[2] + b[2])
        n[1] += (a[2] - b[2]) * (a[0] + b[0])
        n[2] += (a[0] - b[0]) * (a[1] + b[1])
    mid = [sum(p[k] for p in pts) / len(pts) - centre[k] for k in range(3)]
    if sum(n[k] * mid[k] for k in range(3)) < 0.0:
        pts = list(reversed(pts))
        tones = None if tones is None else list(reversed(tones))
    m.poly(pts, None if tones is None else list(tones))


def upright(name: str, w: float, d: float, cap: bool) -> list:
    """A chamfered upright `w` by `d`, 1 m tall from y 0, its ends open (they meet the rails) or its top capped."""
    mk.reset()
    m = tk.Mesh()
    sec = chamfered(w, d, CHAMFER * min(w, d))
    n = len(sec)
    for i in range(n):
        (xa, za), (xb, zb) = sec[i], sec[(i + 1) % n]
        face(m, [(xa, 0.0, za), (xa, 1.0, za), (xb, 1.0, zb), (xb, 0.0, zb)], (0.0, 0.5, 0.0), (0.86, 1.0, 1.0, 0.86))
    if cap:
        face(m, [(x, 1.0, z) for x, z in sec], (0.0, 0.5, 0.0))
    return [m.build(name, PAINT)]


def rail(name: str, profile: list, tones: list) -> list:
    """A rail 1 m along x from `profile` (z, y) points round its section, its two ends capped."""
    mk.reset()
    m = tk.Mesh()
    n = len(profile)
    centre = (0.5, sum(y for _, y in profile) / n, sum(z for z, _ in profile) / n)
    for i in range(n):
        (za, ya), (zb, yb) = profile[i], profile[(i + 1) % n]
        face(m, [(0.0, ya, za), (1.0, ya, za), (1.0, yb, zb), (0.0, yb, zb)], centre,
             (tones[i], tones[i], tones[(i + 1) % n], tones[(i + 1) % n]))
    face(m, [(0.0, y, z) for z, y in profile], centre)
    face(m, [(1.0, y, z) for z, y in profile], centre)
    return [m.build(name, PAINT)]


def top_profile() -> tuple:
    """The capping's section over the rail's depth: a flat underside, short upright sides and a rounded top."""
    hd = DEPTH / 2
    side = RAIL_H * 0.35
    pts = [(-hd, 0.0), (hd, 0.0), (hd, side)]
    for k in range(1, CAP_SEG):
        a = math.pi * k / CAP_SEG
        pts.append((hd * math.cos(a), side + (RAIL_H - side) * math.sin(a)))
    pts.append((-hd, side))
    tones = [0.7, 0.7, 0.85] + [0.85 + 0.15 * math.sin(math.pi * k / CAP_SEG) for k in range(1, CAP_SEG)] + [0.85]
    return pts, tones


def foot_profile() -> tuple:
    hd, c = DEPTH / 2, RAIL_H * 0.25
    pts = [(-hd, 0.0), (hd, 0.0), (hd, RAIL_H - c), (hd - c, RAIL_H), (-hd + c, RAIL_H), (-hd, RAIL_H - c)]
    return pts, [0.7, 0.7, 0.9, 1.0, 1.0, 0.9]


def build() -> None:
    tris = {}
    tris["bar"] = tk.report("railing_bar", upright("railing_bar", BAR, BAR, False), 40)
    tris["post"] = tk.report("railing_post", upright("railing_post", BAR, POST_ACROSS, False), 60)
    tris["top"] = tk.report("railing_top", rail("railing_top", *top_profile()), 60)
    tris["foot"] = tk.report("railing_foot", rail("railing_foot", *foot_profile()), 40)
    # A 5 m run as Railings lays it: 35 bars (34 gaps at about 0.14 m), three posts with their plates (12 each).
    bars = round((5.0 - BAR) / 0.14) + 1
    run = bars * tris["bar"] + 3 * (tris["post"] + 12) + tris["top"] + tris["foot"]
    print("railing: a 5 m run draws %d tris of %d (%.0f%%)" % (run, RUN_BUDGET, 100.0 * run / RUN_BUDGET))
    if run > RUN_BUDGET:
        raise SystemExit("railing: a 5 m run is over its budget")


if __name__ == "__main__":
    build()
