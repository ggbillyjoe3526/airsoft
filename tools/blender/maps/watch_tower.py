"""Woodland's watch tower (WG3, Dev 3): assets/models/props/watch_tower.glb, the Tower on the north lane, over its ten
blocks (four legs, the platform, three parapet walls, the roof and the stair; data/maps/woodland.json, `dress`
watch_tower).

From the owner's photos (references/maps/woodland/05-watch-tower): a fire lookout's timber frame on four sawn legs
standing on concrete piers in galvanised post shoes, braced under the platform (a girt round the legs and a
king-post truss in each side over head height, so you walk under it freely); a plank platform on joists; a boarded
parapet (lap boards outside, matchboard inside, a cap rail on top) on three sides and the stair's open side to the
east; corner posts holding a low hipped standing-seam roof; an open-riser stair between two stringers with a handrail
each side. Bolts at the joints. Weathered silver-grey timber, a dark sheet roof. No brands.

Every block is filled by its part: the legs, the platform, the walls, the roof (its pitch kept inside the roof's
0.15 m: a hip so low it reads from the field as a flat cap) and the stair (its nosings on the ramp's slope). The
open timbers (truss, roof posts, handrails) stand between the blocks, over head height or open, inside the box round
them all (timberkit). Budget 6,000 triangles (/mnt/project-files/art/woodland-model-list.md).

    python -I tools/blender/maps/watch_tower.py <repo root>
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402  first: it sets up bpy and the replica helpers
import hardsurface as hs  # noqa: E402
import timberkit as wk  # noqa: E402

NAME = "watch_tower"
BUDGET = 6000
LEG = 0.288         # the sawn legs' width (m): with their shoes' side plates, their 0.3 m blocks' width
CHAMFER = 0.025
PIER = 0.3          # the concrete pier: the leg block's width, from its foot to PIER_TOP over the ground
PIER_TOP = 0.25
GIRT_OVER = 2.3     # the girt round the legs, this far over the highest leg's ground: over any head
TIMBER = (0.075, 0.15)  # braces and girts (w, d)
RIM = (0.075, 0.165)    # the platform's rim and joists (w, d)
JOISTS = 9
DECK_T = 0.035
BOARD = 0.14
GAP = 0.008
LAP = 0.18          # the parapet's lap boards (outside) and how far each stands proud at its foot
LAP_PROUD = 0.022
MATCH = 0.15        # matchboard (inside), with a V groove between boards
CAP_T = 0.045
POST = 0.14         # the roof's corner posts
SEAM = 0.3          # standing seams' spacing on the roof, and their height
SEAM_H = 0.016
EAVE_H = 0.095      # the sheet's eave over the roof block's underside; its peak is the block's top
STEP_RISE = 0.2     # the stair's rise: whole steps between the ground and the platform
STRINGER = (0.05, 0.27)
TREAD_T = 0.04
SKIRT = 0.16        # the boards closing the stair's sides and back under it
RAIL_H, MID_H = 0.95, 0.5
RAIL = (0.07, 0.07)


def parts() -> dict:
    raw = wk.blocks(NAME)
    out = {"legs": [], "walls": []}
    for kind, lo, hi, rise in raw:
        if rise:
            out["stair"] = (lo, hi)
        elif kind == "floor":
            out["deck"] = (lo, hi)
        elif kind == "log":
            out["legs"].append((lo, hi))
        elif hi.y - lo.y < 0.3:
            out["roof"] = (lo, hi)
        else:
            out["walls"].append((lo, hi))
    lo, hi = wk.bounds(raw)
    out["frame"] = wk.Frame(lo, hi)
    return out


def bolt(b: hs.Builder, f: wk.Frame, at: tuple, normal: tuple) -> None:
    """A hex bolt head and washer on a face, `normal` the face's outward axis (map axes, one of +-x, +-z)."""
    n = mk_vec(normal)
    side = mk_vec((0.0, 1.0, 0.0))
    other = n.cross(side)
    c = mk_vec(at)
    ring0 = [tuple(c + (side * math.cos(a) + other * math.sin(a)) * 0.024) for a in hexes()]
    ring1 = [tuple(c + n * 0.012 + (side * math.cos(a) + other * math.sin(a)) * 0.017) for a in hexes()]
    pts0 = [f.G(*p) for p in ring0]
    pts1 = [f.G(*p) for p in ring1]
    b.loft([pts0, pts1], "Bolt", cap0=False, cap1=True)


def hexes() -> list:
    return [math.pi / 3 * i + math.pi / 6 for i in range(6)]


def nail(b: hs.Builder, f: wk.Frame, x: float, y: float, z: float) -> None:
    """A nail head: a small dark square just over a board's face."""
    h = 0.006
    wk.quad(b, f, [(x - h, y + 0.0015, z - h), (x + h, y + 0.0015, z - h), (x + h, y + 0.0015, z + h),
                   (x - h, y + 0.0015, z + h)], "Bolt", (0.0, 1.0, 0.0))


def face_nail(b: hs.Builder, f: wk.Frame, at: tuple, out: tuple) -> None:
    """A nail head on an upright face facing `out` (map +-x or +-z)."""
    h = 0.006
    x, y, z = at
    if out[0] != 0.0:
        x += out[0] * 0.003
        pts = [(x, y - h, z - h), (x, y - h, z + h), (x, y + h, z + h), (x, y + h, z - h)]
    else:
        z += out[2] * 0.003
        pts = [(x - h, y - h, z), (x + h, y - h, z), (x + h, y + h, z), (x - h, y + h, z)]
    wk.quad(b, f, pts, "Bolt", out)


def mk_vec(t: tuple):
    from mathutils import Vector
    return Vector(t)


def legs(b: hs.Builder, f: wk.Frame, p: dict) -> float:
    """Each leg: a concrete pier filling its block's foot to PIER_TOP over the ground, a galvanised shoe, and the
    chamfered sawn leg up to the platform. Returns the girt's height."""
    tops = []
    for lo, hi in p["legs"]:
        cx, cz = (lo.x + hi.x) / 2, (lo.z + hi.z) / 2
        ground = lo.y + 0.3  # every block reaches 0.3 m under the lowest ground beneath it (build_map.SINK)
        tops.append(ground)
        pier = ground + PIER_TOP
        h = PIER / 2
        wk.board(b, f, (cx - h, lo.y, cz - h), (cx + h, pier, cz + h), "Concrete", "xXzZY")
        # the shoe: two side plates either side of the leg, a base plate
        wk.board(b, f, (cx - LEG / 2 - 0.006, pier, cz - LEG / 2 - 0.006), (cx + LEG / 2 + 0.006, pier + 0.008,
                 cz + LEG / 2 + 0.006), "Galv", "xXzZY")
        for s in (-1, 1):
            x0 = cx + s * (LEG / 2) if s > 0 else cx - LEG / 2 - 0.006
            wk.board(b, f, (x0, pier + 0.008, cz - 0.06), (x0 + 0.006, pier + 0.2, cz + 0.06), "Galv", "xXzZY")
            bolt(b, f, (cx + s * (LEG / 2 + 0.006), pier + 0.12, cz), (float(s), 0.0, 0.0))
        r = LEG / 2
        c = CHAMFER
        ring = [(r - c, -r), (r, -r + c), (r, r - c), (r - c, r), (-r + c, r), (-r, r - c), (-r, -r + c), (-r + c, -r)]
        rings = []
        for y in (pier + 0.008, (pier + hi.y) / 2, hi.y):
            rings.append([f.G(cx + u, y, cz + v) for u, v in ring])
        b.loft(rings, "Wood", cap0=False, cap1=True)
        # galvanised plates tying the leg's top to the rim, a pair of bolts through each
        for s in (-1, 1):
            z0 = cz + s * LEG / 2
            wk.board(b, f, (cx - 0.08, hi.y - 0.3, min(z0, z0 + s * 0.006)), (cx + 0.08, hi.y + 0.1,
                     max(z0, z0 + s * 0.006)), "Galv", "xXyYzZ")
            for yy in (hi.y - 0.22, hi.y - 0.08):
                bolt(b, f, (cx, yy, z0 + s * 0.006), (0.0, 0.0, float(s)))
    return max(tops) + GIRT_OVER


def frame_band(b: hs.Builder, f: wk.Frame, p: dict, girt_y: float) -> None:
    """The girt round the legs and an X brace in each side between it and the platform's rim, bolted where it
    crosses."""
    lo, hi = p["deck"]
    xs = sorted({round((l.x + h.x) / 2, 3) for l, h in p["legs"]})
    zs = sorted({round((l.z + h.z) / 2, 3) for l, h in p["legs"]})
    w, d = TIMBER
    r = LEG / 2
    top = lo.y
    for z in zs:
        out = -1.0 if z == zs[0] else 1.0
        zz = z + out * (r + w / 2)
        wk.beam(b, f, (xs[0] - r, girt_y, zz), (xs[1] + r, girt_y, zz), w, d, "WoodDark", chamfer=0.012)
        mid = (xs[0] + xs[1]) / 2
        for k, x in enumerate(xs):
            other = xs[1 - k]
            # an X brace, one diagonal laid a timber's width out from the other where they cross, bolted there
            lay = zz + out * w * k
            wk.beam(b, f, (x, girt_y + d / 2, lay), (other, top - 0.02, lay), w, d * 0.9, "Wood",
                    up=(0.0, 0.0, out), chamfer=0.012)
            bolt(b, f, (x, girt_y, zz + out * w / 2), (0.0, 0.0, out))
        bolt(b, f, (mid, (girt_y + top) / 2, zz + out * w * 1.5), (0.0, 0.0, out))
    for x in xs:
        out = -1.0 if x == xs[0] else 1.0
        xx = x + out * (r + w / 2)
        wk.beam(b, f, (xx, girt_y + 0.16, zs[0] - r), (xx, girt_y + 0.16, zs[1] + r), w, d, "WoodDark",
                up=(0.0, 1.0, 0.0), chamfer=0.012)
        mid = (zs[0] + zs[1]) / 2
        for k, z in enumerate(zs):
            other = zs[1 - k]
            lay = xx + out * w * k
            wk.beam(b, f, (lay, girt_y + 0.16 + d / 2, z), (lay, top - 0.02, other), w, d * 0.9, "Wood",
                    up=(out, 0.0, 0.0), chamfer=0.012)
            bolt(b, f, (xx + out * w / 2, girt_y + 0.16, z), (out, 0.0, 0.0))
        bolt(b, f, (xx + out * w * 1.5, (girt_y + top) / 2, mid), (out, 0.0, 0.0))


def deck(b: hs.Builder, f: wk.Frame, p: dict, rng: random.Random) -> None:
    """Rim beams, joists along x, the boards across them along z with gaps between over dark sarking, the shade under
    it."""
    lo, hi = p["deck"]
    w, d = RIM
    y0, y1 = lo.y, hi.y - DECK_T
    wk.board(b, f, (lo.x, y0, lo.z), (hi.x, y1, lo.z + w), "WoodDark", "xXzZyY")
    wk.board(b, f, (lo.x, y0, hi.z - w), (hi.x, y1, hi.z), "WoodDark", "xXzZyY")
    wk.board(b, f, (lo.x, y0, lo.z + w), (lo.x + w, y1, hi.z - w), "WoodDark", "xXyY")
    wk.board(b, f, (hi.x - w, y0, lo.z + w), (hi.x, y1, hi.z - w), "WoodDark", "xXyY")
    for k in range(1, JOISTS + 1):
        z = lo.z + (hi.z - lo.z) * k / (JOISTS + 1)
        wk.board(b, f, (lo.x + w, y0 + 0.01, z - 0.025), (hi.x - w, y1, z + 0.025), "WoodShade", "yYzZ")
    # the sarking under the boards, dark both ways: what shows between them from above, and under them from below
    for facing, y in ((-1.0, y1 - 0.004), (1.0, y1 - 0.002)):
        wk.quad(b, f, [(lo.x + w, y, lo.z + w), (lo.x + w, y, hi.z - w), (hi.x - w, y, hi.z - w),
                       (hi.x - w, y, lo.z + w)], "WoodShade", (0.0, facing, 0.0))
    n = int((hi.x - lo.x) / (BOARD + GAP))
    pitch = (hi.x - lo.x) / n
    shades = ["Wood", "WoodA", "Wood", "WoodB"]
    joists = [lo.z + (hi.z - lo.z) * k / (JOISTS + 1) for k in range(1, JOISTS + 1)]
    for k in range(n):
        x0 = lo.x + k * pitch + GAP / 2
        # each board in two lengths, butted over a joist, the joints staggered board to board
        j = joists[(k * 3) % len(joists)]
        for za, zb, ends in ((lo.z, j, "z"), (j, hi.z, "Z")):
            wk.board(b, f, (x0, y1, za), (x0 + pitch - GAP, hi.y, zb), shades[rng.randrange(4)], "xXY" + ends)
        # two nail heads where the board crosses every third joist
        for jz in joists[k % 3::3]:
            for nx in (x0 + 0.03, x0 + pitch - GAP - 0.03):
                nail(b, f, nx, hi.y, jz)
    # galvanised hangers holding each joist's ends to the rims
    for jz in joists:
        for xe, s in ((lo.x + w, 1.0), (hi.x - w, -1.0)):
            wk.board(b, f, (xe, y0 + 0.012, jz - 0.04), (xe + s * 0.004 if s > 0 else xe, y1 - 0.02, jz + 0.04),
                     "Galv", "yYzZxX") if s > 0 else wk.board(b, f, (xe - 0.004, y0 + 0.012, jz - 0.04),
                                                                 (xe, y1 - 0.02, jz + 0.04), "Galv", "yYzZxX")
    # herringbone bridging between the joists, a row down the middle
    xm = (lo.x + hi.x) / 2
    for za, zb in zip([lo.z + w] + joists, joists + [hi.z - w]):
        for s in (-1.0, 1.0):
            wk.beam(b, f, (xm - 0.03 * s, y0 + 0.02, za + 0.03), (xm + 0.03 * s, y1 - 0.02, zb - 0.03), 0.035, 0.035,
                    "WoodShade", up=(1.0, 0.0, 0.0))


def parapet(b: hs.Builder, f: wk.Frame, lo, hi, out: tuple, rng: random.Random) -> None:
    """One wall: lap boards on its outer face (towards `out`, map x or z), matchboard inside, a cap rail on top, both
    ends boarded across."""
    along_x = hi.x - lo.x > hi.z - lo.z
    y0, y1 = lo.y, hi.y - CAP_T
    n = max(1, round((y1 - y0) / LAP))
    step = (y1 - y0) / n
    shades = ["Wood", "WoodA", "WoodB", "Wood"]
    a0, a1 = (lo.x, hi.x) if along_x else (lo.z, hi.z)
    for k in range(n):
        ya, yb = y0 + k * step, y0 + (k + 1) * step
        # each course two or three boards long, their butt joints staggered course to course
        cuts = sorted({a0, a1, *(a0 + (a1 - a0) * rng.uniform(0.25, 0.75) for _ in range(rng.randint(1, 2)))})
        for u0, u1 in zip(cuts, cuts[1:]):
            m = shades[rng.randrange(4)]
            if along_x:
                s = out[2]
                zf = (lo.z if s < 0 else hi.z) - s * LAP_PROUD  # inset: each board's foot meets the block's face
                wk.quad(b, f, [(u0, ya, zf + s * LAP_PROUD), (u1, ya, zf + s * LAP_PROUD), (u1, yb, zf), (u0, yb, zf)],
                        m, (0.0, 0.0, s))
                for un in (u0 + 0.05, u1 - 0.05):
                    face_nail(b, f, (un, ya + 0.04, zf + s * LAP_PROUD * 0.8), (0.0, 0.0, s))
                wk.quad(b, f, [(u0, ya, zf), (u1, ya, zf), (u1, ya, zf + s * LAP_PROUD), (u0, ya, zf + s * LAP_PROUD)],
                        "WoodShade", (0.0, -1.0, 0.0))
            else:
                s = out[0]
                xf = (lo.x if s < 0 else hi.x) - s * LAP_PROUD
                wk.quad(b, f, [(xf + s * LAP_PROUD, ya, u0), (xf, yb, u0), (xf, yb, u1), (xf + s * LAP_PROUD, ya, u1)],
                        m, (s, 0.0, 0.0))
                for un in (u0 + 0.05, u1 - 0.05):
                    face_nail(b, f, (xf + s * LAP_PROUD * 0.8, ya + 0.04, un), (s, 0.0, 0.0))
                wk.quad(b, f, [(xf, ya, u0), (xf + s * LAP_PROUD, ya, u0), (xf + s * LAP_PROUD, ya, u1), (xf, ya, u1)],
                        "WoodShade", (0.0, -1.0, 0.0))
    # corner boards over the lap boards' ends, outside
    for u in (a0, a1):
        d = 0.09 if u == a0 else -0.09
        if along_x:
            zf = lo.z if out[2] < 0 else hi.z
            wk.board(b, f, (min(u, u + d), y0, min(zf, zf - out[2] * 0.02)), (max(u, u + d), y1,
                     max(zf, zf - out[2] * 0.02)), "WoodDark", "xXzZ")
        else:
            xf = lo.x if out[0] < 0 else hi.x
            wk.board(b, f, (min(xf, xf - out[0] * 0.02), y0, min(u, u + d)), (max(xf, xf - out[0] * 0.02), y1,
                     max(u, u + d)), "WoodDark", "xXzZ")
    # inside: matchboard, each board a face and its V groove's side, one running into the next with no slit between
    # (each face leans back V to the groove), stud-height rail at the middle
    V = 0.008
    if along_x:
        zi = hi.z if out[2] < 0 else lo.z
        s = -out[2]
        n = round((hi.x - lo.x) / MATCH)
        for k in range(n):
            xa = lo.x + (hi.x - lo.x) * k / n
            xb = lo.x + (hi.x - lo.x) * (k + 1) / n
            g = 0.012
            m = shades[rng.randrange(4)]
            wk.quad(b, f, [(xa + g, y0, zi - s * V), (xb, y0, zi), (xb, y1, zi), (xa + g, y1, zi - s * V)], m,
                    (0.0, 0.0, s))
            wk.quad(b, f, [(xa, y0, zi), (xa + g, y0, zi - s * V), (xa + g, y1, zi - s * V), (xa, y1, zi)],
                    "WoodShade", (0.0, 0.0, s))
        wk.board(b, f, (lo.x, (y0 + y1) / 2 - 0.05, zi + s * 0.0), (hi.x, (y0 + y1) / 2 + 0.05, zi + s * 0.03),
                 "WoodDark", "yYzZ")
    else:
        xi = hi.x if out[0] < 0 else lo.x
        s = -out[0]
        n = round((hi.z - lo.z) / MATCH)
        for k in range(n):
            za = lo.z + (hi.z - lo.z) * k / n
            zb = lo.z + (hi.z - lo.z) * (k + 1) / n
            g = 0.012
            m = shades[rng.randrange(4)]
            wk.quad(b, f, [(xi - s * V, y0, za + g), (xi - s * V, y1, za + g), (xi, y1, zb), (xi, y0, zb)], m,
                    (s, 0.0, 0.0))
            wk.quad(b, f, [(xi, y0, za), (xi, y1, za), (xi - s * V, y1, za + g), (xi - s * V, y0, za + g)],
                    "WoodShade", (s, 0.0, 0.0))
        wk.board(b, f, (min(xi, xi + s * 0.03), (y0 + y1) / 2 - 0.05, lo.z), (max(xi, xi + s * 0.03),
                 (y0 + y1) / 2 + 0.05, hi.z), "WoodDark", "yYxX")
    # boarded under, where the wall stands out over the platform's edge
    wk.quad(b, f, [(lo.x, y0, lo.z), (hi.x, y0, lo.z), (hi.x, y0, hi.z), (lo.x, y0, hi.z)], "WoodShade",
            (0.0, -1.0, 0.0))
    # both ends boarded across, under the cap: no seeing into the wall from its end
    for u, sgn in ((a0, -1.0), (a1, 1.0)):
        if along_x:
            wk.quad(b, f, [(u, y0, lo.z), (u, y0, hi.z), (u, y1, hi.z), (u, y1, lo.z)], "WoodDark", (sgn, 0.0, 0.0))
        else:
            wk.quad(b, f, [(lo.x, y0, u), (hi.x, y0, u), (hi.x, y1, u), (lo.x, y1, u)], "WoodDark", (0.0, 0.0, sgn))
    c = 0.012  # the cap's top edges chamfered
    if along_x:
        prof = [(lo.z, y1), (hi.z, y1), (hi.z, hi.y - c), (hi.z - c, hi.y), (lo.z + c, hi.y), (lo.z, hi.y - c)]
        b.loft([[f.G(x, y, z) for z, y in prof] for x in (lo.x, hi.x)], "WoodLight", cap0=True, cap1=True)
    else:
        prof = [(lo.x, y1), (hi.x, y1), (hi.x, hi.y - c), (hi.x - c, hi.y), (lo.x + c, hi.y), (lo.x, hi.y - c)]
        b.loft([[f.G(x, y, z) for x, y in prof] for z in (lo.z, hi.z)], "WoodLight", cap0=True, cap1=True)


def roof(b: hs.Builder, f: wk.Frame, p: dict) -> None:
    """A low hip of standing-seam sheet: four slopes from the eaves (EAVE_H over the block's underside) to a peak at
    its top, a seam every SEAM m on each slope running down it, hip cappings, a fascia round the edge and boarded
    soffit under it."""
    lo, hi = p["roof"]
    cx, cz = (lo.x + hi.x) / 2, (lo.z + hi.z) / 2
    eave = lo.y + EAVE_H
    peak = hi.y - SEAM_H
    corners = [(lo.x, lo.z), (hi.x, lo.z), (hi.x, hi.z), (lo.x, hi.z)]
    for i in range(4):
        (ax, az), (bx, bz) = corners[i], corners[(i + 1) % 4]
        wk.quad(b, f, [(ax, eave, az), (bx, eave, bz), (cx, peak, cz)], "Sheet", (0.0, 1.0, 0.0))
        # the fascia: the sheet's edge folded down to the soffit
        mx, mz = (ax + bx) / 2 - cx, (az + bz) / 2 - cz
        wk.quad(b, f, [(ax, lo.y, az), (bx, lo.y, bz), (bx, eave - 0.03, bz), (ax, eave - 0.03, az)], "WoodDark",
                (mx, 0.0, mz))
        wk.quad(b, f, [(ax, eave - 0.03, az), (bx, eave - 0.03, bz), (bx, eave, bz), (ax, eave, az)], "SheetEdge",
                (mx, 0.0, mz))
        # seams down the slope, each a tent the sheet's height
        length = math.hypot(bx - ax, bz - az)
        n = int(length / SEAM)
        ux, uz = (bx - ax) / length, (bz - az) / length
        for k in range(1, n):
            t = k / n
            ex, ez = ax + (bx - ax) * t, az + (bz - az) * t
            # run from the eave towards the peak until the hip line (where |offset along| meets the slope's taper)
            off = abs(t - 0.5) * length
            run = 1.0 - off / (length / 2)
            tx, tz = ex + (cx - ex) * run, ez + (cz - ez) * run
            ty = eave + (peak - eave) * run
            hw = 0.012
            for s in (-1, 1):  # the seam's two sides, either side of its crest
                wk.quad(b, f, [(ex + s * hw * ux, eave, ez + s * hw * uz), (tx + s * hw * ux, ty, tz + s * hw * uz),
                               (tx, ty + SEAM_H, tz), (ex, eave + SEAM_H, ez)], "SheetLight", (s * ux, 0.4, s * uz))
        # hip capping: a strip down each hip, its crest the block's top
        hx, hz = cx - ax, cz - az
        hl = math.hypot(hx, hz)
        px, pz = -hz / hl * 0.05, hx / hl * 0.05
        for s in (-1, 1):
            wk.quad(b, f, [(ax, eave + SEAM_H, az), (cx + s * px, peak + 0.004, cz + s * pz), (cx, hi.y, cz)],
                    "SheetEdge", (s * px, 0.3, s * pz))
    # soffit boards underneath, along x
    n = int((hi.z - lo.z) / 0.15)
    for k in range(n):
        za = lo.z + (hi.z - lo.z) * k / n
        zb = lo.z + (hi.z - lo.z) * (k + 1) / n  # boards butted: no gap to see the sky through
        wk.quad(b, f, [(lo.x, lo.y, za), (hi.x, lo.y, za), (hi.x, lo.y, zb), (lo.x, lo.y, zb)],
                "WoodShade" if k % 2 else "WoodShadeA", (0.0, -1.0, 0.0))


def corner_posts(b: hs.Builder, f: wk.Frame, p: dict) -> None:
    """Posts at the parapet's corners, from the walls' top to the roof, the west ones on the corners where the walls
    meet, the east ones on the walls' open ends."""
    lo, hi = p["deck"]
    rlo, rhi = p["roof"]
    wall_top = max(h.y for _, h in p["walls"])
    west = min(l.x for l, _ in p["walls"])
    zlo = min(l.z for l, _ in p["walls"])
    zhi = max(h.z for _, h in p["walls"])
    for x, z in ((west + POST / 2, zlo + POST / 2), (west + POST / 2, zhi - POST / 2), (hi.x - POST / 2, zlo + POST / 2),
                 (hi.x - POST / 2, zhi - POST / 2)):
        wk.board(b, f, (x - POST / 2, wall_top, z - POST / 2), (x + POST / 2, rlo.y, z + POST / 2), "Wood", "xXzZ")
        # short knee braces from each post up to the roof's edge, both ways along the walls
        sx = 1.0 if x < (lo.x + hi.x) / 2 else -1.0
        sz = 1.0 if z < (lo.z + hi.z) / 2 else -1.0
        for dx, dz in ((sx, 0.0), (0.0, sz)):
            wk.beam(b, f, (x + dx * POST / 2, rlo.y - 0.45, z + dz * POST / 2),
                    (x + dx * 0.5, rlo.y - 0.005, z + dz * 0.5), 0.06, 0.08, "WoodDark",
                    up=(-dz, 0.0, dx) if dz else (0.0, 0.0, 1.0))


def stair(b: hs.Builder, f: wk.Frame, p: dict, rng: random.Random) -> None:
    """Two stringers along the ramp's slope, treads between them with boarded risers, their nosings on it, the sides
    and back boarded down to the ground, a handrail and a mid rail on posts each side."""
    lo, hi = p["stair"]
    top, foot = hi.y, lo.y
    x_top, x_foot = lo.x, hi.x  # the ramp rises towards -x
    slope = (top - foot) / (x_foot - x_top)

    def surface(x: float) -> float:
        return top - (x - x_top) * slope

    sw, sd = STRINGER
    for z0, z1 in ((lo.z, lo.z + sw), (hi.z - sw, hi.z)):
        depth = sd / math.cos(math.atan(slope))
        outline = [(x_top, top), (x_top, top - depth), (x_foot - depth / slope, foot), (x_foot, foot)]
        rings = []
        for z in (z0, z1):
            rings.append([f.G(x, y, z) for x, y in outline])
        b.loft(rings, "WoodDark", cap0=True, cap1=True)
    steps = max(2, round((top - foot) / STEP_RISE))
    rise = (top - foot) / steps
    going = rise / slope
    shades = ["Wood", "WoodA", "WoodB"]
    for k in range(1, steps):
        y = foot + k * rise - 0.02
        xn = x_top + (top - y) / slope - 0.02
        c = 0.01  # the nosing's edges rounded off
        prof = [(xn - going - 0.03, y - TREAD_T), (xn - c, y - TREAD_T), (xn, y - TREAD_T + c), (xn, y - c), (xn - c, y),
                (xn - going - 0.03, y)]
        b.loft([[f.G(x, yy, z) for x, yy in prof] for z in (lo.z + sw, hi.z - sw)], shades[rng.randrange(3)],
               cap0=False, cap1=False)
        for nz in (lo.z + sw + 0.03, hi.z - sw - 0.03):
            for nx in (xn - 0.06, xn - going + 0.04):
                nail(b, f, nx, y, nz)
        for z0, z1 in ((lo.z + sw, lo.z + sw + 0.03), (hi.z - sw - 0.03, hi.z - sw)):  # the cleats under it
            wk.board(b, f, (xn - going * 0.8, y - TREAD_T - 0.05, z0), (xn - 0.04, y - TREAD_T, z1), "WoodShade",
                     "xXyzZ")
    # closed under: boarded risers between the treads, and vertical boards on both sides and the back down to the
    # ground, so the stair reads as solid as the ramp it stands on (BBs stop on it, so nothing is seen through it)
    prev = foot
    for k in range(1, steps + 1):
        y = foot + k * rise - 0.02
        xn = x_top + (top - y) / slope - 0.02
        wk.quad(b, f, [(xn - 0.015, prev, lo.z + sw), (xn - 0.015, prev, hi.z - sw),
                       (xn - 0.015, y - TREAD_T, hi.z - sw), (xn - 0.015, y - TREAD_T, lo.z + sw)],
                "WoodShade", (1.0, 0.0, 0.0))
        prev = y
    # the bottom step: a sill on the ground under the first tread's nosing, out to the ramp's foot
    x1 = x_top + (top - (foot + rise - 0.02)) / slope - 0.02
    wk.board(b, f, (x1 - 0.02, foot, lo.z + sw), (x_foot, foot + 0.05, hi.z - sw), "WoodDark", "xXY")
    skirt = ["WoodDark", "Wood", "WoodB", "WoodDark", "WoodA"]
    n = max(2, round((x_foot - x_top) / SKIRT))
    wd = (x_foot - x_top) / n
    for z, out in ((lo.z, -1.0), (hi.z, 1.0)):
        for k in range(n):
            xa, xb = x_top + k * wd, x_top + (k + 1) * wd
            ya, yb = surface(xa) - sd * 0.6, surface(xb) - sd * 0.6
            if ya <= foot + 0.01:
                continue
            wk.quad(b, f, [(xa, foot, z), (xb + 0.002, foot, z), (xb + 0.002, max(yb, foot), z), (xa, ya, z)],
                    skirt[rng.randrange(len(skirt))], (0.0, 0.0, out))
            wk.quad(b, f, [(xb - 0.004, foot, z + out * 0.004), (xb + 0.004, foot, z + out * 0.004),
                           (xb + 0.004, max(yb, foot), z + out * 0.004), (xb - 0.004, max(yb, foot), z + out * 0.004)],
                    "WoodShade", (0.0, 0.0, out))
    m = max(2, round((hi.z - lo.z) / SKIRT))
    for k in range(m):
        za, zb = lo.z + (hi.z - lo.z) * k / m, lo.z + (hi.z - lo.z) * (k + 1) / m
        wk.quad(b, f, [(x_top, foot, za), (x_top, foot, zb), (x_top, top - 0.2, zb), (x_top, top - 0.2, za)],
                skirt[rng.randrange(len(skirt))], (-1.0, 0.0, 0.0))
    rw, rd = RAIL
    n_posts = 4
    for z in (lo.z + rw / 2, hi.z - rw / 2):
        posts = [x_top + 0.1 + (x_foot - x_top - 0.25) * k / (n_posts - 1) for k in range(n_posts)]
        for x in posts:
            wk.board(b, f, (x - rw / 2, surface(x), z - rw / 2), (x + rw / 2, surface(x) + RAIL_H, z + rw / 2),
                     "Wood", "xXzZY")
            out = -1.0 if z < (lo.z + hi.z) / 2 else 1.0
            for dy in (-0.12, -0.04):
                bolt(b, f, (x, surface(x) + dy, z + out * rw / 2), (0.0, 0.0, out))
        for hgt, m in ((RAIL_H, "WoodLight"), (MID_H, "Wood")):
            a = (posts[0] - 0.06, surface(posts[0] - 0.06) + hgt, z)
            c = (posts[-1] + 0.06, surface(posts[-1] + 0.06) + hgt, z)
            wk.beam(b, f, a, c, rw * 0.8, 0.06, m, up=(0.0, 1.0, 0.0), chamfer=0.01)


def build() -> object:
    wk.paints({"Sheet": 0x46504c, "SheetLight": 0x56605b, "SheetEdge": 0x3c4542, "WoodShadeA": (0x5d554a, 1.08)})
    p = parts()
    f = p["frame"]
    rng = random.Random(5)
    b = hs.Builder("Tower", [])
    girt = legs(b, f, p)
    frame_band(b, f, p, girt)
    deck(b, f, p, rng)
    dlo, dhi = p["deck"]
    for lo, hi in p["walls"]:
        cx, cz = (lo.x + hi.x) / 2, (lo.z + hi.z) / 2
        along_x = hi.x - lo.x > hi.z - lo.z
        out = (0.0, 0.0, -1.0 if cz < (dlo.z + dhi.z) / 2 else 1.0) if along_x else \
            (-1.0 if cx < (dlo.x + dhi.x) / 2 else 1.0, 0.0, 0.0)
        parapet(b, f, lo, hi, out, rng)
    corner_posts(b, f, p)
    roof(b, f, p)
    stair(b, f, p, rng)
    return b.build(), f


def main() -> None:
    hs.reset()
    ob, f = build()
    print("watch_tower: box %s .. %s" % (tuple(round(v, 3) for v in f.lo), tuple(round(v, 3) for v in f.hi)))
    wk.export(ob, NAME, BUDGET)


if __name__ == "__main__":
    main()
