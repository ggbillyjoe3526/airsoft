"""Subway's engineering wagon (SM4, model 7): a works flat wagon left loaded on the north track, from the owner's
photos (art/references/maps/subway/07-engineering-wagon: the long sleeper-carrying flat wagons and the low-sided works
wagon) and the model list's default for its 2.6 m box (thread "Subway models", 2026-11-11: a loaded flat wagon that
fills it): a steel deck with a works-yellow edge angle and timber cross-bearers on the ballast wagon's detailed
underframe (ballast_wagon.underframe: W-irons, leaf springs, axle boxes, buffers, coupling, brake gear) with
works-yellow solebar webs, corner steps and grab handles at the ends; tapered yellow stanchions down both sides in
riveted U-pockets, each capped; loaded with two stacks of concrete sleepers on timber dunnage and, over them, a load
of kit under a lashed tarpaulin, crumpled a little, its skirt's hem rolled, its four webbing straps running down the
sleepers' ends to ratchets with their handles and on under the solebars. No lettering, no livery.

SQ1 (2026-11-21) rebuilt it finer: the detailed underframe, the stanchions' pockets and caps, the deck's edge, the
steps and handles, and straps with thickness and ratchets (they were flat ribbons ending in mid-air).

Its block (4 x 2 m and 2.6 m high, data/maps/subway.json) is centred on the north track, so the wagon's wheels stand
on the station's running rails (works_kit.running_rails).

Writes assets/models/props/engineering_wagon.glb, one vertex-coloured mesh filling x -2..2 (along the track),
y -1..1, z 0..2.6 exactly (Godot: x along, y up, z across).

Usage: python3 -I tools/blender/maps/engineering_wagon.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
import ballast_wagon as bw  # noqa: E402  (the detailed underframe both wagons share)
from works_kit import wt  # noqa: E402
from mathutils import Vector  # noqa: E402

NAME = "engineering_wagon"
BUDGET = 6000
HL, HD, HIGH = 2.0, 1.0, 2.6

# The deck's steel plate (a satin steel by its name)
wk.PAINT["deck_steel"] = 0x55534f

DECK_X = 1.86          # the deck's half length
DECK_Y = 0.94          # the deck's half width (the stanchions stand outside it, to the box's side)
SLEEPER = (0.26, 1.86, 0.2)   # a concrete sleeper: wide (x), long (across), tall
STACK_X = (-1.78, 0.12)      # each stack's -x end
PER_LAYER = 6
LAYERS = 3
TARP_X, TARP_Y = 1.74, 0.88  # the tarpaulin's half length and half width over the stacks
STRAPS = (-1.25, -0.42, 0.42, 1.25)  # the straps' x over the tarp


def tarp_h(x: float, y: float, z0: float) -> float:
    """The tarpaulin's height over (x, y): pulled tight over a boxy load of crates, its top flat, its shoulders
    rounded, pressed in a little under each strap."""
    u, v = abs(x) / TARP_X, abs(y) / TARP_Y
    fu = min(1.0, (1.0 - u) / 0.1)  # the shoulders: the last tenth of the length, the last fifth of the width
    fv = min(1.0, (1.0 - v) / 0.2)
    shoulder = math.sqrt(max(0.0, min(fu, fv) * (2.0 - min(fu, fv))))  # a quarter round
    pinch = sum(0.025 * math.exp(-((x - sx) / 0.08) ** 2) for sx in STRAPS) * (1.0 - v ** 4)
    return z0 + (HIGH - z0) * shoulder - pinch


def tarp_lines(n: int, half: float, shoulder: float, n_sh: int = 4) -> list:
    """The grid's n + 1 lines across `half` either side of the middle: `n_sh` lines round each shoulder (the outer
    `shoulder` of the half, a quarter round) at equal turns of the round, so its faces meet at under 25 degrees and
    shade smooth, and the rest evenly over the flat top."""
    sh = []
    for k in range(n_sh):
        f = 1.0 - math.cos(0.5 * math.pi * k / n_sh)  # 0 at the edge, round to the top
        sh.append(1.0 - shoulder * f)
    mid = n - 2 * n_sh
    top = [(1.0 - shoulder) * (2.0 * i / mid - 1.0) for i in range(mid + 1)]
    return [-u * half for u in sh] + [t * half for t in top] + [u * half for u in reversed(sh)]


def strap(k: wk.Kit, x: float, pts: list, mid: tuple, w: float = 0.05, t: float = 0.006) -> None:
    """A webbing strap `w` wide along x through the points (y, z) at x, `t` thick on the side away from `mid` (y, z):
    a flat loft, closed, so it reads from either side."""
    rings = []
    for i, (y, z) in enumerate(pts):
        a, b = pts[max(0, i - 1)], pts[min(len(pts) - 1, i + 1)]
        ty, tz = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(ty, tz) or 1.0
        ny, nz = -tz / ln, ty / ln
        if ny * (y - mid[0]) + nz * (z - mid[1]) < 0.0:
            ny, nz = -ny, -nz
        rings.append([(x - w * 0.5, y, z), (x + w * 0.5, y, z), (x + w * 0.5, y + ny * t, z + nz * t),
                      (x - w * 0.5, y + ny * t, z + nz * t)])
    k.loft(rings, "strap")


def build() -> object:
    k = wk.Kit(NAME)
    rail_top = k.running_rails(-HL, HL)
    k.mark("track")
    top = bw.underframe(k, HL, 0.9, 1.15, 0.3, rail_top, "frame_black", buffer_y=0.55, web="works_yellow")
    zc = rail_top + 0.3
    # Corner steps under the headstocks' ends and a grab handle on each headstock's corners.
    for sx in (-1.0, 1.0):
        for s in (-1.0, 1.0):
            x = sx * (HL - 0.17)
            k.sqbar((x, s * 0.88, zc + 0.1), (x, s * 0.95, zc - 0.2), 0.04, "frame_black", h=0.014)
            k.blk((x - 0.08, min(s * 0.86, s * 0.99), zc - 0.215), (x + 0.08, max(s * 0.86, s * 0.99), zc - 0.19),
                  "works_yellow")  # its tread
            xg = sx * (HL - 0.115)
            for a, b in (((xg, s * 0.66, top - 0.04), (xg + sx * 0.06, s * 0.66, top - 0.04)),
                         ((xg + sx * 0.06, s * 0.66, top - 0.04), (xg + sx * 0.06, s * 0.82, top - 0.04)),
                         ((xg + sx * 0.06, s * 0.82, top - 0.04), (xg, s * 0.82, top - 0.04))):
                k.bar(a, b, 0.012, "works_yellow", seg=5)
    k.mark("underframe")
    deck = top + 0.04
    k.blk((-DECK_X, -DECK_Y, top), (DECK_X, DECK_Y, deck), "deck_steel")
    for s in (-1.0, 1.0):  # the deck's edge: a yellow angle along each side, its toe up
        y0, y1 = sorted((s * DECK_Y, s * (DECK_Y - 0.04)))
        k.blk((-DECK_X, y0, deck), (DECK_X, y1, deck + 0.035), "works_yellow")
    for i in range(7):  # cross-bearers, the sleepers' dunnage on the deck
        x = -DECK_X + 0.12 + i * (2 * DECK_X - 0.24) / 6
        k.blk((x - 0.05, -DECK_Y + 0.04, deck), (x + 0.05, DECK_Y - 0.04, deck + 0.07), "timber")
    # Stanchions: tapered steel posts in U-pockets riveted to the solebars, a cap on each, standing out to the
    # box's side.
    for s in (-1.0, 1.0):
        y0, y1 = sorted((s * (DECK_Y - 0.005), s * (HD - 0.012)))
        for x in (-1.6, -0.8, 0.0, 0.8, 1.6):
            k.prism([(x - 0.042, top - 0.2), (x + 0.042, top - 0.2), (x + 0.03, deck + 0.55), (x - 0.03, deck + 0.55)],
                    "y", y0, y1, "works_yellow")
            k.blk((x - 0.038, min(y0, y1) - 0.004, deck + 0.55), (x + 0.038, max(y0, y1) + 0.004, deck + 0.575),
                  "frame_black")  # its cap
            for dx in (-1.0, 1.0):  # the pocket's cheeks and its face
                k.blk((x + dx * 0.055 - 0.01, min(s * 0.9, s * HD), top - 0.2),
                      (x + dx * 0.055 + 0.01, max(s * 0.9, s * HD), top - 0.04), "frame_black")
            k.blk((x - 0.065, min(s * (HD - 0.012), s * HD), top - 0.2), (x + 0.065, max(s * (HD - 0.012), s * HD),
                  top - 0.12), "frame_black")
    k.mark("deck")
    # Two stacks of concrete sleepers across the wagon, three layers on timber dunnage.
    sw, sl, sh = SLEEPER
    z = deck + 0.07
    for layer in range(LAYERS):
        for x0 in STACK_X:
            for i in range(PER_LAYER):
                x = x0 + i * (sw + 0.03)
                # its ends chamfered, its top a little narrower: the sleeper's trapezoid section
                k.prism([(x, z), (x + sw, z), (x + sw - 0.025, z + sh), (x + 0.025, z + sh)], "y", -sl * 0.5,
                        sl * 0.5, "concrete")
        z += sh
        if layer < LAYERS - 1:
            for x0 in STACK_X:
                for y in (-0.6, 0.6):
                    k.blk((x0, y - 0.05, z), (x0 + PER_LAYER * (sw + 0.03) - 0.03, y + 0.05, z + 0.05), "timber")
            z += 0.05
    k.mark("sleepers")
    # The tarpaulin over a load of kit on the top layer, crumpled a little, lashed down by four straps.
    z0 = z
    bm = k.bm
    nx, ny = 19, 14
    xs, ys = tarp_lines(nx, TARP_X, 0.1), tarp_lines(ny, TARP_Y, 0.2)

    def crumple(x: float, y: float) -> float:
        return (wt.fbm(Vector((x * 2.0, y * 2.0, 0.0)), 0.5, 57) - 0.5) * 0.03 * (1.0 - (abs(y) / TARP_Y) ** 6)
    grid = [[bm.verts.new(Vector((x, y, min(HIGH, tarp_h(x, y, z0) + crumple(x, y))))) for x in xs] for y in ys]
    faces = [bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])) for j in range(ny)
             for i in range(nx)]
    # the tarp's skirt hanging down over the top layer's sides and ends, its hem rolled
    edge = [grid[0][i] for i in range(nx + 1)] + [grid[j][nx] for j in range(1, ny + 1)] + \
        [grid[ny][i] for i in range(nx - 1, -1, -1)] + [grid[j][0] for j in range(ny - 1, 0, -1)]
    low = [bm.verts.new(Vector((v.co.x * 1.012, v.co.y * 1.02,
                                z0 - 0.15 - 0.02 * math.sin(v.co.x * 9.0 + v.co.y * 7.0)))) for v in edge]
    hem = [bm.verts.new(Vector((v.co.x * 1.0 + (0.008 if v.co.x > 0 else -0.008) * (abs(v.co.x) > TARP_X * 0.99),
                                v.co.y * 1.0 + (0.008 if v.co.y > 0 else -0.008) * (abs(v.co.y) > TARP_Y * 0.99),
                                v.co.z - 0.03))) for v in low]
    for a in range(len(edge)):
        b = (a + 1) % len(edge)
        faces.append(bm.faces.new((edge[a], edge[b], low[b], low[a])))
        faces.append(bm.faces.new((low[a], low[b], hem[b], hem[a])))
    for f in faces:
        f.normal_update()
    import bmesh
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    k._faces(faces, "tarp")
    k.mark("tarp")
    for x in STRAPS:  # straps over the tarp, down the sleepers' ends to ratchets and hooks under the solebars
        over = [(y * 1.01, tarp_h(x, y, z0) + crumple(x, y) + 0.004) for y in ys]
        down = [(TARP_Y * 1.03, z0 - 0.17), (0.945, z0 - 0.2), (0.945, deck + 0.12), (0.93, top - 0.25)]
        pts = [(-y, z) for y, z in reversed(down)] + over + down
        strap(k, x, pts, (0.0, z0 - 0.3))
        for s in (-1.0, 1.0):
            zr = deck + 0.22
            k.blk((x - 0.04, min(s * 0.951, s * 0.985), zr - 0.06), (x + 0.04, max(s * 0.951, s * 0.985), zr + 0.06),
                  "steel_bare")  # its ratchet
            k.sqbar((x, s * 0.975, zr + 0.04), (x, s * 0.975, zr + 0.2), 0.03, "rubber", h=0.014)  # its handle
    k.mark("straps")
    return k.build()


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint in ("frame_black", "works_yellow"):
        col = wk.rusty(p, n, c, seed=9, amount=0.55)
        return wk.grime(p, n, col, seed=3)
    if paint == "concrete":
        col = wt.mix(c, wk.lin("concrete_dark"), 0.5 * wt.fbm(p, 0.2, 51))
        return wk.grime(p, n, col, seed=5, amount=0.6)
    if paint == "tarp":
        col = wt.mix(c, wk.lin(wk.GRIME), 0.3 * wt.fbm(p, 0.3, 53))  # stains in the folds
        return wt.mix(col, wk.lin(wk.DUST), max(0.0, n.z) * 0.25 * wt.fbm(p, 0.5, 55))
    if paint in ("wheel", "rust"):
        return wk.grime(p, n, wk.rusty(p, n, c, seed=7, amount=0.4, streaks=False), seed=2)
    return wk.grime(p, n, c, seed=4)


def main() -> None:
    wk.reset()
    wk.check_colours(list(wk.PAINT))
    ob = build()
    wk.finish(ob, (-HL, -HD, 0.0), (HL, HD, HIGH))
    wk.bake(ob, weather, jitter={"timber": 0.07, "concrete": 0.05})
    wk.write(ob, NAME, BUDGET)
    if "--render" in sys.argv:
        wk.render(wk.quarter_views(2 * HL, 2 * HD, HIGH), sys.argv[sys.argv.index("--render") + 1],
                  "SM4 engineering wagon (Subway map prop, 4 x 2 x 2.6 m)")


if __name__ == "__main__":
    main()
