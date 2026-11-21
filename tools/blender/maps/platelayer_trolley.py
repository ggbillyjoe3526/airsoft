"""Subway's platelayers' trolleys (SM4, model 9): a small four-wheel push trolley left on the track with its tools,
from the owner's photos (art/references/maps/subway/09-platelayer-trolley, the red works trolleys): a pressed-steel
frame on four big spoked wheels, a timber deck, a tall steel screen at one end with its tubular rail over it (photos 3
and 4), a push rail at the other end, and the tools lying on the deck: a shovel, a pick, a long bar. Works yellow, worn
and rusty (the photos' red is the Beta team's hue once weathered); no lettering.

SQ1 (owner, 2026-11-21: every Subway model in finer detail) gave it the photos' parts at about twice the triangles:
cast wheels with a real flange, a rim lip, six spokes and a hub nut; the axles turning in bolted bearing housings on
channel-section side frames, pressed brackets up to the deck and channel headstocks at the ends; five chamfered deck
boards with shadow gaps between them, their dark sawn ends and coach bolts over the bearers; brake blocks on every
wheel and a hand brake lever; bent-tube rails over the screen and at the push end with rubber grips, a lifting handle
at each corner; the screen's folded edges, stiffener and rivets; a dished shovel with its D grip, a pick and a
crowbar with its claw.

Its three blocks (data/maps/subway.json) are three sizes, so three models, each built at its block's size:
`platelayer_trolley` 1.5 x 1.7 m, `platelayer_trolley_short` 1.3 x 1.7 m and `platelayer_trolley_long` 2 x 1.7 m, all
1.2 m high, each centred on its track, its wheels on the station's running rails (works_kit.running_rails).

Writes assets/models/props/platelayer_trolley*.glb, each one vertex-coloured mesh filling x -L/2..L/2 (along the
track), y -W/2..W/2, z 0..1.2 exactly (Godot: x along, y up, z across).

Usage: python3 -I tools/blender/maps/platelayer_trolley.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

BUDGET = 2400
HIGH = 1.2
SIZES = {"platelayer_trolley": (1.5, 1.7), "platelayer_trolley_short": (1.3, 1.7),
         "platelayer_trolley_long": (2.0, 1.7)}
WHEEL_R = 0.26
SPOKES = 6
WHEEL_SEG = 14
BOARDS = 5
BOARD_GAP = 0.018    # the shadow gap between the deck's boards

# The trolley's own paints (works_kit names them to their surface kinds: "rubber" a grip, "steel" a bearing).
wk.PAINT["grip_rubber"] = 0x2c2a2a
wk.PAINT["timber_end"] = 0x6a6256       # a board's sawn end grain, darker than its face
wk.PAINT["tool_ash"] = 0x9a8e78         # a tool's worn ash handle
wk.PAINT["bearing_steel"] = 0x5a5856


def bent(pts: list, bend: float, n: int = 2) -> list:
    """The polyline `pts` (Vectors) with each inner corner rounded over `bend` m either side (n points round it)."""
    out = [pts[0]]
    for i in range(1, len(pts) - 1):
        a, p, b = pts[i - 1], pts[i], pts[i + 1]
        t0 = min(bend, (p - a).length * 0.45)
        t1 = min(bend, (b - p).length * 0.45)
        p0 = p + (a - p).normalized() * t0
        p1 = p + (b - p).normalized() * t1
        for j in range(n + 1):
            u = j / n
            out.append(p0 * (1 - u) ** 2 + p * 2 * u * (1 - u) + p1 * u * u)
    out.append(pts[-1])
    return out


def pipe(k: wk.Kit, pts: list, r: float, mat: str, seg: int = 6, bend: float = 0.06, r_end: float = -1.0,
         n: int = 2) -> list:
    """A round tube along the polyline `pts`, its corners bent round (n steps each), capped; tapered to `r_end` when
    given."""
    path = bent([Vector(p) for p in pts], bend, n)
    rings, nrm = [], None
    for i, p in enumerate(path):
        if i == 0:
            t = (path[1] - path[0]).normalized()
        elif i == len(path) - 1:
            t = (path[-1] - path[-2]).normalized()
        else:
            t = ((path[i + 1] - p).normalized() + (p - path[i - 1]).normalized()).normalized()
        if nrm is None:
            nrm = t.cross(Vector((0.0, 0.0, 1.0)) if abs(t.z) < 0.9 else Vector((1.0, 0.0, 0.0))).normalized()
        else:
            nrm = (nrm - t * nrm.dot(t)).normalized()
        bi = t.cross(nrm)
        rr = r if r_end < 0.0 else r + (r_end - r) * i / (len(path) - 1)
        rings.append([p + (nrm * math.cos(2 * math.pi * (j + 0.5) / seg) + bi * math.sin(2 * math.pi * (j + 0.5) / seg))
                      * rr for j in range(seg)])
    return k.loft(rings, mat)


def spoked_wheel(k: wk.Kit, x: float, y: float, z: float, outward: float) -> None:
    """A cast spoked wheel turning about y at (x, y, z), its flange inside: a rim with its flange and coned tread and a
    lip round its inside, six spokes and a hub with its nut, open between the spokes (photos 1 and 2)."""
    w = 0.055
    s = outward
    a0, a1 = y - s * w * 0.5, y + s * w * 0.5  # the flange's side, the outer side
    outer = [(a0, WHEEL_R + 0.024), (a0 + s * 0.016, WHEEL_R + 0.02), (a1, WHEEL_R - 0.004)]
    inner = [(a0 + s * 0.01, WHEEL_R - 0.048), (a1, WHEEL_R - 0.034)]
    k.tube(outer, inner, "wheel", segments=WHEEL_SEG, centre=(x, 0.0, z), axis="y")
    hub = [(a0 - s * 0.004, 0.07), (a1, 0.07), (a1 + s * 0.028, 0.038)]  # the hub, its boss over the axle's end
    k.lathe(hub, "wheel", segments=6, centre=(x, 0.0, z), axis="y")
    for i in range(SPOKES):
        a = 2.0 * math.pi * (i + 0.25) / SPOKES
        c, sn = math.cos(a), math.sin(a)
        r0, r1 = 0.06, WHEEL_R - 0.04  # a spoke: a three-sided bar from the hub to the rim, its ends inside them
        rings = [[(-0.024, -0.013), (0.024, -0.013), (0.0, 0.016)], [(-0.016, -0.01), (0.016, -0.01), (0.0, 0.012)]]
        k.loft([[(x + r * c - u * sn, y + v * s, z + r * sn + u * c) for u, v in ring] for r, ring in
                zip((r0, r1), rings)], "wheel", cap0=False, cap1=False)


def channel(k: wk.Kit, lo: tuple, hi: tuple, open_to: str, mat: str, t: float = 0.01) -> None:
    """A steel channel filling lo..hi, its web on the far side from `open_to` ("+y", "-y", "+x", "-x"): a web and two
    flanges, so its open side casts a shadow line."""
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    if open_to == "+y":
        k.blk((x0, y0, z0), (x1, y0 + t, z1), mat)
    elif open_to == "-y":
        k.blk((x0, y1 - t, z0), (x1, y1, z1), mat)
    elif open_to == "+x":
        k.blk((x0, y0, z0), (x0 + t, y1, z1), mat)
    else:
        k.blk((x1 - t, y0, z0), (x1, y1, z1), mat)
    k.blk((x0, y0, z0), (x1, y1, z0 + t * 1.2), mat)
    k.blk((x0, y0, z1 - t * 1.2), (x1, y1, z1), mat)


def running_gear(k: wk.Kit, hl: float, hw: float, ax: float, zc: float, dz: float) -> None:
    """The wheels, axles and their bearings, the channel side frames, brackets, headstocks and brakes."""
    gy = wk.WHEEL_IN + 0.0275    # the wheels' middles: their flanges' faces just inside the running rails
    fy = 0.62                    # the side frames' webs, inside the wheels, the axles' bearings on them
    f0, f1 = zc - 0.06, zc + 0.07
    for x in (-ax, ax):
        for sy in (-1.0, 1.0):
            spoked_wheel(k, x, sy * gy, zc, sy)
            # the bearing housing on the frame's outer face: a square plate and its round boss
            yb = sy * fy
            p0, p1 = sorted((yb, yb + sy * 0.012))
            k.blk((x - 0.075, p0, zc - 0.075), (x + 0.075, p1, zc + 0.075), "bearing_steel")
            k.cyl((x, yb + sy * 0.012, zc), 0.055, sy * 0.04, "bearing_steel", seg=6, axis="y")
        k.bar((x, -gy, zc), (x, gy, zc), 0.032, "bearing_steel", seg=6, cap=False)  # the axle
    for sy in (-1.0, 1.0):  # the side frames: channels, webs outward, along the trolley
        y0, y1 = sorted((sy * fy, sy * (fy - 0.06)))
        channel(k, (-hl + 0.1, y0, f0), (hl - 0.1, y1, f1), "-y" if sy > 0 else "+y", "trolley_yellow", t=0.01)
    bz = dz - 0.07               # the bearers' undersides
    for x in (-ax, ax):          # pressed brackets from the frames up to the bearers over the axles, wide at the foot
        for sy in (-1.0, 1.0):
            y0, y1 = sorted((sy * fy, sy * (fy - 0.05)))
            k.prism([(x - 0.13, f1), (x + 0.13, f1), (x + 0.05, bz), (x - 0.05, bz)], "y", y0, y1, "trolley_yellow")
        k.blk((x - 0.04, -hw + 0.06, bz), (x + 0.04, hw - 0.06, dz), "trolley_yellow")  # the bearer across
    for sx in (-1.0, 1.0):       # the headstocks: channels across the ends under the deck, open inward
        xa, xb = sorted((sx * (hl - 0.06), sx * (hl - 0.14)))
        channel(k, (xa, -hw + 0.04, dz - 0.15), (xb, hw - 0.04, dz), "-x" if sx > 0 else "+x", "trolley_yellow",
                t=0.012)
        for sy in (-1.0, 1.0):   # gussets down from the headstock to the side frame's end
            y0, y1 = sorted((sy * (fy - 0.01), sy * (fy - 0.05)))
            xs = sx * (hl - 0.1)
            k.prism([(xs, f0), (xs, dz - 0.15), (xs - sx * 0.16, dz - 0.15)], "y", y0, y1, "trolley_yellow")
    for x in (-ax, ax):          # brake blocks on each wheel's tread, towards the ends, on a beam across
        xb = x + (WHEEL_R + 0.028) * (1.0 if x > 0 else -1.0)
        for sy in (-1.0, 1.0):
            y0, y1 = sorted((sy * (gy - 0.025), sy * (gy + 0.025)))
            k.blk((xb - 0.025, y0, zc - 0.12), (xb + 0.025, y1, zc + 0.02), "rust")
        k.bar((xb, -gy, zc - 0.1), (xb, gy, zc - 0.1), 0.014, "rust", seg=5, cap=False)  # the brake beam


def deck(k: wk.Kit, hl: float, hw: float, ax: float, dz: float) -> float:
    """Five boards along the trolley with a shadow gap between each, their top edges chamfered, dark sawn ends and
    coach bolts into the bearers. Returns the deck's top."""
    t, c = 0.045, 0.008
    bw = (2 * hw - BOARD_GAP * (BOARDS - 1)) / BOARDS
    x0, x1 = -hl + 0.06, hl - 0.06
    for i in range(BOARDS):
        y0 = -hw + i * (bw + BOARD_GAP)
        y1 = y0 + bw
        prof = [(y0, dz), (y1, dz), (y1, dz + t - c), (y1 - c, dz + t), (y0 + c, dz + t), (y0, dz + t - c)]
        faces = k.prism(prof, "x", x0, x1, "timber")
        k._faces(faces[:2], "timber_end")  # the sawn ends, a shade darker
        ym = (y0 + y1) * 0.5
        k.bolts([(x, ym, dz + t) for x in (-ax, ax)], 0.014, 0.006, "z", "rust", seg=4)
    return dz + t


def screen(k: wk.Kit, hl: float, hw: float, deck_top: float, dz: float) -> None:
    """The +x end's screen: a steel sheet with folded edges and a stiffener across, rivets down its posts, on two
    angle posts from the headstock, and the bent tube rail over it to the box's top."""
    sx0, sx1 = hl - 0.075, hl - 0.065
    zt = HIGH - 0.26
    fy = hw - 0.02
    k.blk((sx0, -fy + 0.04, deck_top), (sx1, fy - 0.04, zt), "trolley_yellow")
    k.blk((sx1, -fy + 0.04, zt - 0.04), (sx1 + 0.025, fy - 0.04, zt), "trolley_yellow")  # its folded top edge
    k.blk((sx1, -fy + 0.04, deck_top + 0.2), (sx1 + 0.018, fy - 0.04, deck_top + 0.26), "trolley_yellow")  # stiffener
    for sy in (-1.0, 1.0):       # angle posts down the sheet's sides, from the headstock to the rail
        y0, y1 = sorted((sy * fy, sy * (fy - 0.05)))
        k.blk((sx0 - 0.004, y0, dz - 0.14), (sx1 + 0.04, y1, zt + 0.02), "trolley_yellow")
        k.blk((sx0 - 0.004, y0, dz - 0.14), (sx1 + 0.002, y1, zt + 0.02), "trolley_yellow")
        k.bolts([(sx1 + 0.04, sy * (fy - 0.025), z) for z in (deck_top + 0.06, deck_top + 0.23, zt - 0.04)], 0.011,
                0.006, "x", "steel_bare", seg=4)
    xr = sx1 + 0.014             # the rail: a tube from post to post, bent over the top, two uprights between
    pipe(k, [(xr, -fy + 0.025, zt), (xr, -fy + 0.025, HIGH - 0.022), (xr, fy - 0.025, HIGH - 0.022),
             (xr, fy - 0.025, zt)], 0.022, "trolley_yellow", seg=6, bend=0.07)
    for y in (-fy * 0.33, fy * 0.33):
        k.bar((xr, y, zt - 0.01), (xr, y, HIGH - 0.03), 0.016, "trolley_yellow", seg=5, cap=False)


def push_end(k: wk.Kit, hl: float, hw: float, deck_top: float, dz: float) -> None:
    """The -x end: the bent push rail in its sockets on the headstock, rubber grips on its bar, a hand brake lever on
    the -y side, and a lifting handle at each of the trolley's four corners."""
    xr = -hl + 0.085
    y = hw - 0.07
    pipe(k, [(xr, -y, deck_top + 0.05), (xr - 0.025, -y, 0.95), (xr - 0.025, y, 0.95), (xr, y, deck_top + 0.05)],
         0.02, "trolley_yellow", seg=6, bend=0.08)
    for sy in (-1.0, 1.0):
        k.cyl((xr, sy * y, deck_top - 0.004), 0.03, 0.08, "trolley_yellow", seg=6)  # the socket
        k.bar((xr - 0.025, sy * (y - 0.12), 0.95), (xr - 0.025, sy * (y - 0.42), 0.95), 0.027, "grip_rubber", seg=6)
    # the hand brake: a pivot bracket on the deck and the lever leaning back, its round knob worn bare
    bx, by = -hl + 0.3, -hw + 0.12
    k.blk((bx - 0.05, by - 0.03, deck_top), (bx + 0.05, by + 0.03, deck_top + 0.06), "trolley_yellow")
    pipe(k, [(bx, by, deck_top + 0.03), (bx - 0.08, by, 0.82)], 0.014, "frame_black", seg=5)
    k.cyl((bx - 0.084, by, 0.82), 0.026, 0.04, "steel_bare", seg=6)
    for sx in (-1.0,):           # the lifting handles: a bent bar out from the headstock at each corner
        xa = sx * (hl - 0.06)
        for sy in (-1.0, 1.0):
            yy = sy * (hw - 0.17)
            pipe(k, [(xa, yy - 0.07, dz - 0.08), (sx * (hl - 0.014), yy - 0.06, dz - 0.08),
                     (sx * (hl - 0.014), yy + 0.06, dz - 0.08), (xa, yy + 0.07, dz - 0.08)], 0.014, "trolley_yellow",
                 seg=4, bend=0.03, n=1)


def tools(k: wk.Kit, hl: float, hw: float, deck_top: float) -> None:
    """The tools on the deck: a shovel with its D grip and dished blade lying across the boards, a pick, a crowbar."""
    lx = 2 * hl - 0.4
    z = deck_top + 0.02
    # the shovel: an ash shaft, a D grip at its end, the steel socket and a dished blade
    a = Vector((-hl + 0.22, -hw + 0.2, z))
    b = Vector((-hl + 0.22 + lx * 0.72, -hw + 0.36, z))
    d = (b - a).normalized()
    side = Vector((-d.y, d.x, 0.0))
    k.bar(a, b, 0.017, "tool_ash", seg=6)
    g = a - d * 0.02
    pipe(k, [g + side * 0.06, g - d * 0.14 + side * 0.07, g - d * 0.14 - side * 0.07, g - side * 0.06], 0.011,
         "tool_ash", seg=5, bend=0.03, n=1)
    pipe(k, [b - d * 0.06, b + d * 0.06], 0.02, "steel_bare", seg=6, r_end=0.03)
    blade = [(-0.12, 0.012), (-0.06, 0.003), (0.06, 0.003), (0.12, 0.012), (0.12, 0.017), (0.06, 0.008),
             (-0.06, 0.008), (-0.12, 0.017)]
    faces = k.prism(blade, "x", 0.0, 0.27, "steel_bare")
    turn = Matrix.Rotation(math.atan2(d.y, d.x), 4, "Z")
    k.transform(faces, Matrix.Translation(b + d * 0.05 + Vector((0.0, 0.0, deck_top - z))) @ turn)
    # the pick: a handle along the deck's +y side and its head lying flat, both points tapered
    p0 = Vector((-hl + 0.3, hw - 0.3, z + 0.003))
    p1 = p0 + Vector((min(0.85, lx * 0.8), -0.05, 0.0))
    k.bar(p0, p1, 0.02, "tool_ash", seg=6)
    head = p1 - Vector((0.05, 0.0, 0.0))
    for sy in (-1.0, 1.0):
        pipe(k, [head, head + Vector((-0.03, sy * 0.14, 0.0)), head + Vector((-0.08, sy * 0.28, -0.004))], 0.02,
             "steel_bare", seg=5, bend=0.06, r_end=0.004, n=1)
    # the crowbar: a long hex bar along the middle board, its claw end bent up off the deck
    c0 = Vector((-hl + 0.14, 0.03, deck_top + 0.016))
    c1 = Vector((hl - 0.22, -0.04, deck_top + 0.016))
    pipe(k, [c0, c1 - (c1 - c0).normalized() * 0.08, c1 + Vector((0.0, 0.0, 0.07))], 0.015, "steel_bare", seg=6,
         bend=0.04, r_end=0.008)


def build(name: str, length: float, width: float) -> object:
    hl, hw = length * 0.5, width * 0.5
    k = wk.Kit(name)
    rail_top = k.running_rails(-hl, hl)
    k.mark("track")
    zc = rail_top + WHEEL_R
    ax = hl - 0.34
    dz = zc + WHEEL_R + 0.035    # the deck clears the wheels' flanges
    running_gear(k, hl, hw, ax, zc, dz)
    k.mark("running gear")
    deck_top = deck(k, hl, hw, ax, dz)
    k.mark("deck")
    screen(k, hl, hw, deck_top, dz)
    k.mark("screen")
    push_end(k, hl, hw, deck_top, dz)
    k.mark("push end")
    tools(k, hl, hw, deck_top)
    k.mark("tools")
    return k.build()


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint == "trolley_yellow":
        col = wk.rusty(p, n, c, seed=13, amount=0.6)
        if p.z > 0.85:  # the rails worn bare where they're gripped
            col = wt.mix(col, wk.lin("steel_bare"), 0.45 * wt.fbm(p, 0.06, 15))
        return wk.grime(p, n, col, seed=6)
    if paint in ("wheel", "rust", "bearing_steel"):
        return wk.grime(p, n, wk.rusty(p, n, c, seed=7, amount=0.4, streaks=False), seed=2)
    if paint in ("timber", "timber_end", "tool_ash"):
        col = wt.mix(c, wk.lin(wk.GRIME), 0.25 * wt.fbm(p, 0.15, 17))  # weathered, oil-stained boards
        return wk.grime(p, n, col, seed=4)
    return wk.grime(p, n, c, seed=4)


def main() -> None:
    wk.check_colours(list(wk.PAINT))
    for name, (length, width) in SIZES.items():
        wk.reset()
        ob = build(name, length, width)
        wk.finish(ob, (-length * 0.5, -width * 0.5, 0.0), (length * 0.5, width * 0.5, HIGH))
        wk.bake(ob, weather, jitter={"timber": 0.1, "timber_end": 0.08})
        wk.write(ob, name, BUDGET)
        if "--render" in sys.argv:
            out = sys.argv[sys.argv.index("--render") + 1].replace(".jpg", "_%s.jpg" % name)
            wk.render(wk.quarter_views(length, width, HIGH), out,
                      "SM4 %s (Subway map prop, %g x %g x 1.2 m)" % (name.replace("_", " "), length, width))


if __name__ == "__main__":
    main()
