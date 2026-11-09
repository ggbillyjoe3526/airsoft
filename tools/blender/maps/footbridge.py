"""Woodland's log footbridge (WG3, Dev 3): assets/models/props/footbridge.glb, the North bridge over the stream, over its
three blocks (the deck and its two 1 m side walls; data/maps/woodland.json, `dress` footbridge).

From the owner's photos (references/maps/woodland/06-log-footbridge): three peeled log stringers bedded in both banks,
decked across with split half-logs (photos 1 and 4), round side posts with a pole handrail (photos 2, 6, 8). The game's
side walls stop BBs and sight to a metre, so the rails are closed: a slab fence of half-logs laid flat side in, bark
side out, between the posts, under the handrail; open rails would show a crossing player who can't be shot. Moss on
the slabs' tops and the deck's edges; iron dogs where the slabs meet the posts.

Each part fills its block: stringers and decking the deck's 0.3 m, the side walls their 0.1 by 1 m. Budget 3,000
triangles (/mnt/project-files/art/woodland-model-list.md). Plain vertex colours, no texture.

    python -I tools/blender/maps/footbridge.py <repo root>
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402  first: it sets up bpy and the replica helpers
import hardsurface as hs  # noqa: E402
import timberkit as wk  # noqa: E402

NAME = "footbridge"
BUDGET = 3000
STRINGERS = 3
SPLIT = 0.15        # a split half-log's width across the deck (m), and its thickness
SPLIT_T = 0.075
ARC = 5             # segments round a half-log's top
SIDE = 0.6          # a half-log's straight sides, of its thickness: the groove between two no deeper than the rest
POSTS = 6           # posts a side, the ends and between
SLABS = 5           # slabs up a side under the handrail
HANDRAIL_R = 0.05
BANK = 0.9          # the stringers' ends bedded this far into each bank: the deck's ends stand on a sill log


def parts() -> dict:
    raw = wk.blocks(NAME)
    out = {"walls": []}
    for kind, lo, hi, _ in raw:
        if kind == "floor":
            out["deck"] = (lo, hi)
        else:
            out["walls"].append((lo, hi))
    lo, hi = wk.bounds(raw)
    out["frame"] = wk.Frame(lo, hi)
    return out


def half_log(b: hs.Builder, f: wk.Frame, x0: float, x1: float, y0: float, z0: float, z1: float, t: float, mats: list,
             rng: random.Random, bark_up: bool = True, flat_face: str = "Cut") -> None:
    """A split half-log lying across z from z0 to z1, its flat side down at y0 and its round top `t` over it,
    between x0 and x1 (its width), ends cut. The bark streaks a segment at a time from `mats`."""
    w = x1 - x0
    side = t * SIDE
    pts = [(x0, y0)]
    for k in range(ARC + 1):
        a = math.pi * k / ARC
        # straight sides, then the round full in the shoulders: the logs meet with only a shallow groove between
        pts.append((x0 + w / 2 - math.cos(a) * w / 2, y0 + side + math.sin(a) ** 0.5 * (t - side) * rng.uniform(0.9, 1.0)
                    if 0 < k < ARC else y0 + side))
    pts.append((x1, y0))
    for k in range(len(pts) - 1):
        (xa, ya), (xb, yb) = pts[k], pts[k + 1]
        out = 1.0 if bark_up else -1.0  # each face turned out from the log, its sides too
        wk.quad(b, f, [(xa, ya, z0), (xb, yb, z0), (xb, yb, z1), (xa, ya, z1)], mats[rng.randrange(len(mats))],
                (-(yb - ya) * out, (xb - xa) * out, 0.0))
    # the flat side, under: no seeing up into the log from below
    wk.quad(b, f, [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], flat_face,
            (0.0, -1.0 if bark_up else 1.0, 0.0))
    for z, s in ((z0, -1.0), (z1, 1.0)):
        wk.quad(b, f, [(x, y, z) for x, y in pts], flat_face, (0.0, 0.0, s))


def slab(b: hs.Builder, f: wk.Frame, x0: float, x1: float, y0: float, y1: float, zf: float, zb: float,
         rng: random.Random, moss: bool) -> None:
    """A slab lying along x in a side wall: its flat sawn face at zb (inside), its bark rounded out to zf, ends cut."""
    out = 1.0 if zf > zb else -1.0
    h = y1 - y0
    rows = []
    for k in range(ARC + 1):
        a = math.pi * k / ARC
        rows.append((y0 + h / 2 - math.cos(a) * h / 2, zb + (zf - zb) * math.sin(a) * (0.75 + 0.25 * math.sin(a))))
    for k in range(ARC):
        (ya, za), (yb, zb_) = rows[k], rows[k + 1]
        top = k >= ARC - 1
        m = "Moss" if (moss and top) else ["Bark", "BarkLight", "BarkDark"][rng.randrange(3)]
        wk.quad(b, f, [(x0, ya, za), (x1, ya, za), (x1, yb, zb_), (x0, yb, zb_)], m, (0.0, 0.3 if top else 0.0, out))
    wk.quad(b, f, [(x0, y0, zb), (x1, y0, zb), (x1, y1, zb), (x0, y1, zb)], "Wood", (0.0, 0.0, -out))
    for x, s in ((x0, -1.0), (x1, 1.0)):
        wk.quad(b, f, [(x, y, z) for y, z in rows], "Cut", (s, 0.0, 0.0))


def build() -> tuple:
    wk.paints()
    p = parts()
    f = p["frame"]
    rng = random.Random(6)
    b = hs.Builder("Bridge", [])
    lo, hi = p["deck"]
    deck_top = hi.y
    bed = deck_top - SPLIT_T
    # the stringers, bedded in the banks, on a sill log at each end
    span = hi.z - lo.z
    r = (bed - lo.y) / 2
    for k in range(STRINGERS):
        # the outer two flush with the deck's sides: no seeing in under the decking from the side
        z = lo.z + r + (span - 2 * r) * k / (STRINGERS - 1)
        wk.log(b, f, (lo.x, lo.y + r, z), (hi.x, lo.y + r, z), r * 0.98, ["Bark", "BarkLight", "BarkDark"],
               sides=10, rings=6, wobble=0.05, rng=rng)
    for x in (lo.x + r, hi.x - r):
        wk.log(b, f, (x, lo.y + r, lo.z), (x, lo.y + r, hi.z), r, ["BarkDark", "Damp"], sides=8,
               rings=2, wobble=0.04, rng=rng)
    # the decking: split half-logs across the stringers, flat side down, every one a little different
    n = round((hi.x - lo.x) / SPLIT)
    w = (hi.x - lo.x) / n
    for k in range(n):
        x0 = lo.x + k * w
        mats = ["BarkLight", "Bark", "WoodA"] if rng.random() < 0.7 else ["Bark", "BarkDark", "Wood"]
        if rng.random() < 0.15:
            mats = ["Moss", "Bark"]
        half_log(b, f, x0, x0 + w, bed, lo.z, hi.z, SPLIT_T, mats, rng)
    # the side walls: posts, slabs between them, a pole handrail on top
    for wlo, whi in p["walls"]:
        outer = whi.z if (whi.z + wlo.z) / 2 > (lo.z + hi.z) / 2 else wlo.z
        inner = wlo.z if outer == whi.z else whi.z
        zc = (wlo.z + whi.z) / 2
        t = whi.z - wlo.z
        rail_y = whi.y - HANDRAIL_R
        wk.log(b, f, (wlo.x, rail_y, zc), (whi.x, rail_y, zc), HANDRAIL_R, ["BarkLight", "Bark"], sides=8, rings=4,
               wobble=0.05, rng=rng)
        xs = [wlo.x + t / 2 + (whi.x - wlo.x - t) * k / (POSTS - 1) for k in range(POSTS)]
        for x in xs:
            wk.log(b, f, (x, wlo.y, zc), (x, rail_y - HANDRAIL_R * 0.6, zc), t / 2, ["Bark", "BarkDark", "BarkLight"],
                   sides=8, rings=3, wobble=0.04, rng=rng, caps=(False, True))
        top = rail_y - HANDRAIL_R
        h = (top - wlo.y) / SLABS
        for k in range(SLABS):
            y0, y1 = wlo.y + k * h, wlo.y + (k + 1) * h
            # each course in two lengths meeting at a post, the joint moving course to course
            j = xs[1 + (k % (POSTS - 2))]
            for xa, xb in ((wlo.x, j), (j, whi.x)):
                slab(b, f, xa, xb, y0, y1, outer, inner, rng, moss=(k == SLABS - 1 and rng.random() < 0.5))
            # an iron dog over the joint, on the inside
            s = 1.0 if inner > outer else -1.0
            wk.board(b, f, (j - 0.07, (y0 + y1) / 2 - 0.006, min(inner, inner + s * 0.008)),
                     (j + 0.07, (y0 + y1) / 2 + 0.006, max(inner, inner + s * 0.008)), "Steel", "xXyYzZ")
    return b.build(), f


def main() -> None:
    hs.reset()
    ob, f = build()
    wk.export(ob, NAME, BUDGET)


if __name__ == "__main__":
    main()
