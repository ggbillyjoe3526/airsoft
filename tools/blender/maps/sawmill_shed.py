"""Woodland's Sawmill open shed (WG3, Dev 3): assets/models/props/sawmill_shed.glb, B site's shed, over its seven blocks
(six posts and the roof; data/maps/woodland.json, `dress` sawmill_shed).

From the owner's photos (references/maps/woodland/07-sawmill-open-shed): a post-and-beam timber frame open on every
side: square sawn posts on concrete piers in galvanised shoes, a top plate along each row of posts and a tie beam
across the shed at each pair, curved-in-look knee braces from the posts to both (the "Y" at every post in photos 1, 3,
4 and 5), bolted; rafters across the plates, purlins over them, and corrugated galvanised sheet on top in two runs
lapped over the middle, a fascia board round the edge. The roof keeps inside the roof block's 0.15 m (flat to the eye,
as photo 2's lean-to nearly is). No brands.

The posts and the roof fill their blocks; the plates, ties and braces stand under the roof between them, over head
height (timberkit). Budget 5,000 triangles (/mnt/project-files/art/woodland-model-list.md). Plain vertex colours.

    python -I tools/blender/maps/sawmill_shed.py <repo root>
"""

import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402  first: it sets up bpy and the replica helpers
import hardsurface as hs  # noqa: E402
import timberkit as wk  # noqa: E402
import watch_tower as wt  # noqa: E402  its bolts and post shoes

NAME = "sawmill_shed"
BUDGET = 5000
POST = 0.288         # with the shoes' side plates, the posts' 0.3 m blocks' width
CHAMFER = 0.02
PIER, PIER_TOP = 0.3, 0.3
PLATE = (0.16, 0.24)    # top plates and tie beams (w, d)
BRACE = (0.12, 0.15)
BRACE_DROP = 0.55       # a knee brace meets its post this far under the plate, and the plate as far from the post
RAFTER = (0.06, 0.075)
RAFTER_STEP = 0.6
PURLIN = (0.05, 0.045)
PURLIN_STEP = 0.9
WAVE = 0.068            # the corrugation's pitch across the sheet, and its depth
WAVE_D = 0.022
FASCIA_T = 0.025
HEADER = 0.24        # the deep fascia hanging under the roof block's edge, round the shed over any head


def parts() -> dict:
    raw = wk.blocks(NAME)
    out = {"posts": []}
    for kind, lo, hi, _ in raw:
        if hi.y - lo.y < 0.3:
            out["roof"] = (lo, hi)
        else:
            out["posts"].append((lo, hi))
    lo, hi = wk.bounds(raw)
    out["frame"] = wk.Frame(lo, hi)
    return out


def post(b: hs.Builder, f: wk.Frame, lo, hi) -> None:
    cx, cz = (lo.x + hi.x) / 2, (lo.z + hi.z) / 2
    ground = lo.y + 0.3
    top = ground + PIER_TOP
    h = PIER / 2
    wk.board(b, f, (cx - h, lo.y, cz - h), (cx + h, top, cz + h), "Concrete", "xXzZY")
    wk.board(b, f, (cx - POST / 2 - 0.006, top, cz - POST / 2 - 0.006), (cx + POST / 2 + 0.006, top + 0.008,
             cz + POST / 2 + 0.006), "Galv", "xXzZY")
    for s in (-1, 1):
        x0 = cx + POST / 2 if s > 0 else cx - POST / 2 - 0.006
        wk.board(b, f, (x0, top + 0.008, cz - 0.06), (x0 + 0.006, top + 0.22, cz + 0.06), "Galv", "xXzZY")
        wt.bolt(b, f, (cx + s * (POST / 2 + 0.006), top + 0.13, cz), (float(s), 0.0, 0.0))
    r, c = POST / 2, CHAMFER
    ring = [(r - c, -r), (r, -r + c), (r, r - c), (r - c, r), (-r + c, r), (-r, r - c), (-r, -r + c), (-r + c, -r)]
    rings = [[f.G(cx + u, y, cz + v) for u, v in ring] for y in (top + 0.008, (top + hi.y) / 2, hi.y)]
    b.loft(rings, "Wood", cap0=False, cap1=False)


def frame(b: hs.Builder, f: wk.Frame, p: dict) -> None:
    """Top plates along x on each row of posts, tie beams across z at each pair, knee braces to both, bolted."""
    rlo, rhi = p["roof"]
    xs = sorted({round((l.x + h.x) / 2, 3) for l, h in p["posts"]})
    zs = sorted({round((l.z + h.z) / 2, 3) for l, h in p["posts"]})
    w, d = PLATE
    y1 = rlo.y
    y0 = y1 - d
    reach = 0.45  # the plates and ties run on past the outer posts, under the roof's overhang
    for z in zs:
        wk.beam(b, f, (rlo.x + 0.1, (y0 + y1) / 2, z), (rhi.x - 0.1, (y0 + y1) / 2, z), w, d, "WoodDark",
                chamfer=0.015)
    for x in xs:
        wk.beam(b, f, (x, (y0 + y1) / 2 - 0.002, rlo.z + 0.1), (x, (y0 + y1) / 2 - 0.002, rhi.z - 0.1), w, d, "Wood",
                chamfer=0.015)
    bw, bd = BRACE
    mid_x = (xs[0] + xs[-1]) / 2
    mid_z = (zs[0] + zs[-1]) / 2
    for x in xs:
        for z in zs:
            # along x: towards the middle from the end posts, both ways from the middle ones
            dirs = [1.0, -1.0] if abs(x - mid_x) < 0.01 else [1.0 if x < mid_x else -1.0]
            for s in dirs:
                wk.beam(b, f, (x + s * POST / 2, y0 - BRACE_DROP, z), (x + s * (POST / 2 + BRACE_DROP), y0 + 0.01, z),
                        bw, bd, "Wood", up=(0.0, 0.0, 1.0), chamfer=0.012)
            s = 1.0 if z < mid_z else -1.0
            wk.beam(b, f, (x, y0 - BRACE_DROP, z + s * POST / 2), (x, y0 + 0.01, z + s * (POST / 2 + BRACE_DROP)),
                    bw, bd, "Wood", up=(1.0, 0.0, 0.0), chamfer=0.012)
            # a bolt through each brace's foot into its post, from both sides
            for t in (-1.0, 1.0):
                wt.bolt(b, f, (x + t * bw / 2, y0 - BRACE_DROP + 0.08, z + s * (POST / 2 + 0.05)), (t, 0.0, 0.0))
            for sx in dirs:
                for t in (-1.0, 1.0):
                    wt.bolt(b, f, (x + sx * (POST / 2 + 0.05), y0 - BRACE_DROP + 0.08, z + t * bw / 2), (0.0, 0.0, t))
            for sz in (-1.0, 1.0):
                wt.bolt(b, f, (x, y0 + d / 2, z + sz * w / 2), (0.0, 0.0, sz))
            wt.bolt(b, f, (x + w / 2, y0 + d * 0.3, z), (1.0, 0.0, 0.0))


def roof(b: hs.Builder, f: wk.Frame, p: dict, rng: random.Random) -> None:
    """Rafters across z on the plates, purlins along x over them, the corrugated sheet in two runs (the upper lapped
    over the lower at the middle), a fascia board round the edge and the sheet's dark underside between the rafters."""
    lo, hi = p["roof"]
    rw, rd = RAFTER
    pw, pd = PURLIN
    y_r1 = lo.y + rd
    y_p1 = y_r1 + pd
    n = int((hi.x - lo.x - 0.2) / RAFTER_STEP)
    for k in range(n + 1):
        x = lo.x + 0.1 + (hi.x - lo.x - 0.2) * k / n
        wk.board(b, f, (x - rw / 2, lo.y, lo.z + FASCIA_T), (x + rw / 2, y_r1, hi.z - FASCIA_T), "WoodShade", "yxX")
    m = int((hi.z - lo.z - 0.2) / PURLIN_STEP)
    for k in range(m + 1):
        z = lo.z + 0.1 + (hi.z - lo.z - 0.2) * k / m
        wk.board(b, f, (lo.x + FASCIA_T, y_r1, z - pw / 2), (hi.x - FASCIA_T, y_p1, z + pw / 2), "WoodShade", "yzZ")
    wk.quad(b, f, [(lo.x, y_p1, lo.z), (hi.x, y_p1, lo.z), (hi.x, y_p1, hi.z), (lo.x, y_p1, hi.z)], "GalvUnder",
            (0.0, -1.0, 0.0))
    # the corrugated sheet: a profile across x run along z, two runs, the upper lapping the lower at the middle
    waves = round((hi.x - lo.x) / WAVE)
    pitch = (hi.x - lo.x) / waves
    mid = (lo.z + hi.z) / 2
    top = hi.y
    for z0, z1, lift in ((lo.z, mid + 0.08, 0.0), (mid - 0.08, hi.z, 0.006)):
        base = top - WAVE_D - 0.006 + lift
        for k in range(waves):
            xa = lo.x + k * pitch
            prof = [(xa, base), (xa + pitch * 0.25, base + WAVE_D), (xa + pitch * 0.5, base + WAVE_D),
                    (xa + pitch * 0.75, base), (xa + pitch, base)]
            # sheets about 0.9 m wide, each a touch apart in shade
            shade = "Galv" if int(k * pitch / 0.9) % 2 == 0 else "GalvDark"
            for (ax, ay), (bx, by) in zip(prof, prof[1:]):
                wk.quad(b, f, [(ax, ay, z0), (bx, by, z0), (bx, by, z1), (ax, ay, z1)], shade, (0.0, 1.0, 0.0))
        # the run's cut edges show the waves end on
    # the fascia boards round the edge, from under the rafters to under the sheet, and a deep header hanging under them
    for (x0, z0, x1, z1, face) in ((lo.x, lo.z, hi.x, lo.z + FASCIA_T, "z"), (lo.x, hi.z - FASCIA_T, hi.x, hi.z, "Z"),
                                   (lo.x, lo.z, lo.x + FASCIA_T, hi.z, "x"), (hi.x - FASCIA_T, lo.z, hi.x, hi.z, "X")):
        wk.board(b, f, (x0, lo.y, z0), (x1, top - WAVE_D - 0.006, z1), "WoodDark", face + "y")
        wk.board(b, f, (x0, lo.y - HEADER, z0), (x1, lo.y, z1), "Wood", face + face.swapcase() + "y")


def build() -> tuple:
    wk.paints({"GalvDark": (0x9c9ca4, 0.95), "GalvUnder": 0x77746c})
    p = parts()
    f = p["frame"]
    rng = random.Random(7)
    b = hs.Builder("Shed", [])
    for lo, hi in p["posts"]:
        post(b, f, lo, hi)
    frame(b, f, p)
    roof(b, f, p, rng)
    return b.build(), f


def main() -> None:
    hs.reset()
    ob, f = build()
    wk.export(ob, NAME, BUDGET)


if __name__ == "__main__":
    main()
