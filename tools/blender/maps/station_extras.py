"""Subway's look-only extras (SM5, model 33 of art/subway-model-list.md), from the owner's photos
(references/maps/subway/33-extras/<kind>/). Each writes one model to assets/models/props/, placed by
tools/subway/fixtures.py and drawn by StationFixtures; none has a collider, so none changes play. A wall model's back
is z 0 on the wall, facing +z; a hanging one's top is y 0 at the ceiling; a standing one's foot is y 0 on the floor.

| Model | Photos | Budget |
|---|---|---|
| `cctv_camera.glb` | cctv_camera 3 and 4: a bullet camera under a sun shield on a wall arm, aimed down | 400 |
| `way_sign.glb` | direction_signs 1 and 2: a black box sign on two drop rods, "Way out" in yellow one side, "Platforms" the other | 150 |
| `fire_extinguisher.glb` | fire_extinguisher: a 2 kg CO2 cylinder on a wall bracket, its valve, squeeze lever and horn | 500 |
| `litter_bin.glb` | litter_bin: a steel-topped bin, black corner posts, open sides showing its bag, a round slot in the top | 500 |
| `edge_sign.glb` | mind_the_gap 3: "STAY BEHIND THE YELLOW LINE" on a black plate on the platform's coping | 12 |
| `platform_clock.glb` | platform_clock: a round double-sided clock on a wall bracket, Roman numerals, a dark green case | 400 |
| `poster_a..m.glb` | poster_frames: a 1 x 1.5 m poster in a slim aluminium frame, thirteen invented posters | 30 |
| `poster_wide_a..c.glb` | the same frame 6 x 3 m (50 mm), the trackside walls' big posters | 30 |
| `name_board.glb` | station_name_platform: the station's name on a long band on the platform wall | 80 |

Every word and name is invented (station_signs.py); no real network, brand or logo.

    python3 -I tools/blender/maps/station_extras.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import stationkit as sk  # noqa: E402
from station_cells import POSTERS, WIDE_POSTERS  # noqa: E402

BUDGETS = {
    "cctv_camera": 320, "way_sign": 90, "fire_extinguisher": 480, "litter_bin": 320, "edge_sign": 12,
    "platform_clock": 300, "poster": 40, "name_board": 40,
}


def cctv_camera() -> sk.Mesh:
    """A bullet camera as the owner's photos 3 and 4: a round housing under a curved sun shield, aimed 25 degrees down,
    on a ball joint at the end of a stout box arm out of a wall plate, its cable looping back to the wall."""
    m = sk.Mesh("cctv_camera")
    cam = sk.Mesh("camera")
    # the housing along +z from its back (z 0), its axis at the origin: a rounded back, the barrel, the bezel
    cam.lathe([(0.0, 0.0), (0.03, 0.0), (0.045, 0.02), (0.045, 0.19)], 12, (0.0, 0.0, 0.0), "alu", axis="z",
              cap_bottom=False, cap_top=False)
    cam.lathe([(0.045, 0.19), (0.041, 0.2), (0.031, 0.198)], 12, (0.0, 0.0, 0.0), "dark_alu", axis="z",
              cap_bottom=False, cap_top=False)
    cam.lathe([(0.031, 0.198), (0.016, 0.194), (0.0, 0.196)], 10, (0.0, 0.0, 0.0), ["black", "glass"], axis="z",
              cap_bottom=False, cap_top=False)
    # the sun shield: a curved hood over the top, from behind the housing to past its front
    hood = [(0.058 * math.cos(math.radians(d)), 0.058 * math.sin(math.radians(d))) for d in
            (-12, 22, 56, 90, 124, 158, 192)]
    for i in range(len(hood) - 1):
        (xa, ya), (xb, yb) = hood[i], hood[i + 1]
        cam.face([(xa, ya, -0.012), (xa, ya, 0.235), (xb, yb, 0.235), (xb, yb, -0.012)], "alu", smooth=True)
        cam.face([(xb * 0.95, yb * 0.95, -0.012), (xb * 0.95, yb * 0.95, 0.235), (xa * 0.95, ya * 0.95, 0.235),
                  (xa * 0.95, ya * 0.95, -0.012)], "dark_alu", smooth=True)
        cam.face([(xa, ya, 0.235), (xa * 0.95, ya * 0.95, 0.235), (xb * 0.95, yb * 0.95, 0.235), (xb, yb, 0.235)],
                 "alu")
    # the mount: a stem down from the housing's belly to the ball joint
    cam.lathe([(0.012, -0.075), (0.012, -0.043)], 6, (0.0, 0.0, 0.08), "alu", axis="y", cap_bottom=False,
              cap_top=False)
    cam.lathe([(0.0, -0.096), (0.015, -0.091), (0.021, -0.077), (0.015, -0.063), (0.0, -0.058)], 8, (0.0, 0.0, 0.08),
              "dark_alu", axis="y", cap_bottom=False, cap_top=False)

    def aim(p: tuple) -> tuple:
        a = math.radians(25.0)
        y, z = p[1] * math.cos(a) - p[2] * math.sin(a), p[1] * math.sin(a) + p[2] * math.cos(a)
        return (p[0], y + 0.02, z + 0.07)
    joint = aim((0.0, -0.077, 0.08))
    m.extend(cam.transformed(aim))
    # the wall plate and the arm out of it to under the joint, a box section tapering a little
    m.box((-0.045, joint[1] - 0.06, 0.0), (0.045, joint[1] + 0.035, 0.014), "alu", skip="b")
    arm = [(-0.016, joint[1] - 0.026), (0.016, joint[1] - 0.026), (0.016, joint[1] + 0.012),
           (-0.016, joint[1] + 0.012)]
    near = [(x, y, 0.014) for x, y in arm]
    far = [(x * 0.8, y + 0.004 if y > joint[1] else y + 0.008, joint[2] + 0.012) for x, y in arm]
    m.quad_strip(near, far, "alu", closed=True)
    m.face(far, "alu")
    # the cable from the housing's back, down and round into the plate
    back = aim((0.0, -0.03, 0.01))
    m.tube([back, (0.0, back[1] - 0.03, back[2] - 0.03), (0.0, joint[1] - 0.045, 0.03), (0.0, joint[1] - 0.045,
           0.014)], 0.004, "black", sides=3)
    return m


def way_sign() -> sk.Mesh:
    """A box sign 1.28 x 0.28 m, 0.07 deep, "Way out" on its front (+z), "Platforms" on its back, hung 0.3 m under
    the ceiling on two rods with their roses."""
    m = sk.Mesh("way_sign")
    w, h, d, top = 0.64, 0.28, 0.035, -0.3
    y0, y1 = top - h, top
    m.box((-w, y0, -d), (w, y1, d), "sign_black", skip="fb")
    f = 0.012
    m.sign("way_out", [(-w + f, y0 + f, d), (w - f, y0 + f, d), (w - f, y1 - f, d), (-w + f, y1 - f, d)])
    m.sign("platforms", [(w - f, y0 + f, -d), (-w + f, y0 + f, -d), (-w + f, y1 - f, -d), (w - f, y1 - f, -d)])
    # the dark frame round each printed face
    for z, sgn in ((d, 1.0), (-d, -1.0)):
        for a, b in (((-w, y0), (w, y0 + f)), ((-w, y1 - f), (w, y1)), ((-w, y0 + f), (-w + f, y1 - f)),
                     ((w - f, y0 + f), (w, y1 - f))):
            (xa, ya), (xb, yb) = a, b
            pts = [(xa, ya, z), (xb, ya, z), (xb, yb, z), (xa, yb, z)]
            m.face(pts if sgn > 0 else [pts[1], pts[0], pts[3], pts[2]], "charcoal")
    for x in (-0.45, 0.45):
        m.tube([(x, top, 0.0), (x, 0.0, 0.0)], 0.008, "dark_alu", sides=4)
        m.box((x - 0.035, -0.012, -0.035), (x + 0.035, 0.0, 0.035), "dark_alu", skip="u")
        m.box((x - 0.02, top, -0.02), (x + 0.02, top + 0.02, 0.02), "dark_alu", skip="d")
    return m


def fire_extinguisher() -> sk.Mesh:
    """A red CO2 cylinder 0.58 m tall and 0.16 m across (3.6 to 1, as the photos) on a wall bracket, its back 0.02 m
    off the wall: a black label band, the brass neck, the valve and its two levers, the hose from the valve and the
    black horn, a round cone, clipped down its left side."""
    m = sk.Mesh("fire_extinguisher")
    r = 0.08
    c = (0.0, 0.0, 0.02 + r)
    top = 0.58
    prof = [(0.07, 0.0), (r, 0.02), (r, 0.41), (r, 0.475), (0.068, 0.53), (0.04, 0.565), (0.022, top)]
    m.lathe(prof, 16, c, ["dark_red", "red", "sign_black", "red", "red", "red"])
    # the valve: a brass neck, a block, the carrying handle under the squeeze lever, both pointing out
    m.lathe([(0.016, top), (0.016, top + 0.03)], 8, c, "brass", cap_bottom=False)
    v = top + 0.03
    m.box((c[0] - 0.022, v, c[2] - 0.018), (c[0] + 0.022, v + 0.035, c[2] + 0.018), "zinc")
    m.box((c[0] - 0.012, v + 0.035, c[2] - 0.04), (c[0] + 0.012, v + 0.045, c[2] + 0.11), "red")
    m.box((c[0] - 0.012, v + 0.005, c[2] + 0.01), (c[0] + 0.012, v + 0.015, c[2] + 0.12), "red")
    # the hose out of the valve's side, over and down to the horn's swivel on the cylinder's left
    hx = c[0] - r - 0.035
    hose = [(c[0] - 0.022, v + 0.015, c[2]), (c[0] - 0.06, v + 0.02, c[2] + 0.01), (hx, v - 0.03, c[2] + 0.02),
            (hx, 0.5, c[2] + 0.03)]
    m.tube(hose, 0.009, "black", sides=4)
    # the horn: a round black cone hanging from its swivel, its mouth at the foot, tilted a little off the body
    horn = (hx, 0.17, c[2] + 0.03)
    m.lathe([(0.048, 0.0), (0.036, 0.15), (0.022, 0.29), (0.014, 0.315)], 10, horn, "black",
            cap_top=False)
    m.lathe([(0.042, 0.004), (0.02, 0.035)], 10, horn, "charcoal", cap_top=True, cap_bottom=False)
    m.lathe([(0.015, 0.315), (0.015, 0.335)], 6, horn, "charcoal", cap_bottom=False)
    # the bracket: a plate on the wall and a strap round the cylinder
    m.box((-0.04, 0.26, 0.0), (0.04, 0.42, 0.02), "black", skip="b")
    m.lathe([(r + 0.004, 0.36), (r + 0.004, 0.39)], 16, c, "black", cap_top=False, cap_bottom=False, smooth=False)
    return m


def litter_bin() -> sk.Mesh:
    """A free-standing bin 0.46 x 0.36 m, 0.95 m tall: a plinth, four black corner posts with rails top and bottom,
    its open sides showing the bag, a brushed steel top with a round slot and a black rim."""
    m = sk.Mesh("litter_bin")
    hx, hz, top = 0.23, 0.18, 0.95
    m.box((-hx + 0.01, 0.0, -hz + 0.01), (hx - 0.01, 0.05, hz - 0.01), "black", skip="d")
    p = 0.035
    for sx in (-1, 1):
        for sz in (-1, 1):
            x0, x1 = sorted((sx * hx, sx * (hx - p)))
            z0, z1 = sorted((sz * hz, sz * (hz - p)))
            m.box((x0, 0.05, z0), (x1, top - 0.08, z1), "black", skip="du")
    for y0, y1 in ((0.05, 0.09), (top - 0.12, top - 0.08)):
        m.box((-hx + p, y0, hz - 0.02), (hx - p, y1, hz), "black", skip="lr")
        m.box((-hx + p, y0, -hz), (hx - p, y1, -hz + 0.02), "black", skip="lr")
        m.box((-hx, y0, -hz + p), (-hx + 0.02, y1, hz - p), "black", skip="bf")
        m.box((hx - 0.02, y0, -hz + p), (hx, y1, hz - p), "black", skip="bf")
    # the bag, a little slack and crumpled, and the rubbish showing at its mouth
    bag = []
    for k, (y, s) in enumerate(((0.06, 0.78), (0.28, 0.88), (0.5, 0.8), (0.7, 0.9), (0.8, 0.96))):
        ring = []
        for i in range(8):
            a = 2.0 * math.pi * (i + 0.5) / 8
            wob = 1.0 + 0.1 * math.sin(i * 2.3 + k * 1.7) * (1.0 if k < 4 else 0.3)
            ring.append(((hx - 0.03) * s * wob * math.cos(a) / math.cos(math.pi / 8) * 0.92,
                         y, -(hz - 0.03) * s * wob * math.sin(a) / math.cos(math.pi / 8) * 0.92))
        bag.append(ring)
    for k in range(len(bag) - 1):
        m.quad_strip(bag[k], bag[k + 1], "bag" if k < 3 else "bag_rim", closed=True, smooth=True)
    # the top: a steel lid with chamfered edges, the slot cut through it
    lid_lo, lid_hi = top - 0.08, top
    t = 0.02
    outline = [(hx, -hz), (hx, hz), (-hx, hz), (-hx, -hz)]
    inset = [(x - math.copysign(t, x), z - math.copysign(t, z)) for x, z in outline]
    for i in range(4):
        j = (i + 1) % 4
        (xa, za), (xb, zb) = outline[i], outline[j]
        (xc, zc), (xd, zd) = inset[i], inset[j]
        m.face([(xa, lid_lo, za), (xb, lid_lo, zb), (xb, lid_hi - t, zb), (xa, lid_hi - t, za)][::-1], "alu")
        m.face([(xa, lid_hi - t, za), (xb, lid_hi - t, zb), (xd, lid_hi, zd), (xc, lid_hi, zc)][::-1], "alu")
    hole = 0.075
    n = 12
    ring_out = []
    for i in range(n):
        a = 2.0 * math.pi * i / n
        ring_out.append((hole * math.cos(a), lid_hi, -hole * math.sin(a)))
    # the lid's top: from its inset outline in to the slot, a face from each edge of the outline to the slot's arc
    # facing it
    def angle(x: float, z: float) -> float:
        return math.atan2(-z, x) % (2.0 * math.pi)
    corners = sorted(inset, key=lambda c: angle(*c))
    steps = [2.0 * math.pi * i / n for i in range(n)]
    for k in range(4):
        a0 = angle(*corners[k])
        a1 = angle(*corners[(k + 1) % 4]) + (2.0 * math.pi if k == 3 else 0.0)
        first = [i for i in range(2 * n) if steps[i % n] + (i // n) * 2.0 * math.pi >= a0][0]
        last = [i for i in range(2 * n) if steps[i % n] + (i // n) * 2.0 * math.pi >= a1][0]
        arc = [ring_out[i % n] for i in range(first, last + 1)]
        (xa, za), (xb, zb) = corners[k], corners[(k + 1) % 4]
        up_face(m, [(xa, lid_hi, za), (xb, lid_hi, zb)] + arc[::-1], "alu")
    m.lathe([(hole, -0.03), (hole, 0.0), (hole + 0.012, 0.004), (hole + 0.02, 0.0)], n, (0.0, lid_hi, 0.0),
            ["charcoal", "black", "black"], cap_top=False, cap_bottom=False, smooth=False)
    m.lathe([(hole, -0.03), (0.0, -0.03)], n, (0.0, lid_hi, 0.0), "black", cap_top=False, cap_bottom=False)
    m.face([(x, lid_hi - 0.03, z) for x, _, z in ring_out], "black")
    # the label strip on the lid's front edge
    m.box((-0.12, top - 0.055, hz), (0.12, top - 0.035, hz + 0.003), "sign_black", skip="b")
    return m


def up_face(m: sk.Mesh, pts: list, paint: str) -> None:
    """A level face, wound to look up."""
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][2] - pts[(i + 1) % len(pts)][0] * pts[i][2] for i in range(len(pts)))
    m.face(pts if area < 0.0 else pts[::-1], paint)


def edge_sign() -> sk.Mesh:
    """A 2 x 0.25 m plate 6 mm proud of the coping, the words along it reading from the platform side (+z)."""
    m = sk.Mesh("edge_sign")
    w, h, t = 1.0, 0.125, 0.006
    m.box((-w, 0.0, -h), (w, t, h), "sign_black", skip="du")
    m.sign("edge", [(-w, t, h), (w, t, h), (w, t, -h), (-w, t, -h)])
    return m


def platform_clock() -> sk.Mesh:
    """A round clock 0.46 m across, double-sided, its faces looking along the wall (+x and -x), hung from a bracket
    0.42 m out from the wall: a wall plate, an arm with a brace under it, a short rod down to the case."""
    m = sk.Mesh("platform_clock")
    clock = sk.Mesh("clock")
    r, half = 0.23, 0.05
    sides = 20
    clock.lathe([(r, -half), (r, half)], sides, (0.0, 0.0, 0.0), "clock_rim", axis="z", cap_top=False,
                cap_bottom=False)
    for sgn in (1.0, -1.0):
        prof = [(r, half), (r - 0.018, half + 0.006), (r - 0.024, half - 0.012)]
        prof = [(a, b * sgn) for a, b in prof]
        if sgn < 0:
            prof = prof[::-1]
        clock.lathe(prof, sides, (0.0, 0.0, 0.0), "clock_rim", axis="z", cap_top=False, cap_bottom=False)
        clock.disc_sign("clock", (0.0, 0.0, sgn * (half - 0.012)), r - 0.024, sides, sgn)
    # the hanger lug on top of the case
    clock.box((-0.02, r - 0.01, -0.02), (0.02, r + 0.035, 0.02), "clock_rim", skip="d")
    hang = 0.42
    # a quarter turn about up (not a mirror), so both faces read the right way round
    turned = clock.transformed(lambda p: (p[2], p[1] - 0.12 - r - 0.035, hang - p[0]))
    m.extend(turned)
    m.box((-0.05, -0.2, 0.0), (0.05, 0.03, 0.02), "black", skip="b")
    m.box((-0.015, -0.02, 0.02), (0.015, 0.02, hang + 0.03), "black", skip="b")
    m.tube([(0.0, -0.17, 0.02), (0.0, -0.02, hang * 0.7)], 0.01, "black", sides=4)
    m.tube([(0.0, -0.02, hang), (0.0, -0.12, hang)], 0.01, "black", sides=4)
    return m


def poster(cell: str, w: float = 0.5, h: float = 0.75, f: float = 0.025) -> sk.Mesh:
    """A 2w x 2h poster (1 x 1.5 m) in an f wide aluminium frame standing 20 mm off the wall, its middle at the
    origin."""
    m = sk.Mesh(cell)
    d = 0.02
    m.sign(cell, [(-w, -h, d - 0.004), (w, -h, d - 0.004), (w, h, d - 0.004), (-w, h, d - 0.004)])
    for a, b in (((-w - f, -h - f), (w + f, -h)), ((-w - f, h), (w + f, h + f)), ((-w - f, -h), (-w, h)),
                 ((w, -h), (w + f, h))):
        (x0, y0), (x1, y1) = a, b
        m.box((x0, y0, 0.0), (x1, y1, d), "alu", skip="b" + ("u" if y0 >= h else "") + ("d" if y1 <= -h else ""))
    return m


def name_board() -> sk.Mesh:
    """The station's name on a 2.88 x 0.45 m band in a dark frame, 40 mm off the wall, its middle at the origin."""
    m = sk.Mesh("name_board")
    w, h, d, f = 1.44, 0.225, 0.04, 0.02
    m.sign("name", [(-w, -h, d), (w, -h, d), (w, h, d), (-w, h, d)])
    m.box((-w - f, -h - f, 0.0), (w + f, -h, d + 0.006), "charcoal", skip="b")
    m.box((-w - f, h, 0.0), (w + f, h + f, d + 0.006), "charcoal", skip="b")
    m.box((-w - f, -h, 0.0), (-w, h, d + 0.006), "charcoal", skip="bud")
    m.box((w, -h, 0.0), (w + f, h, d + 0.006), "charcoal", skip="bud")
    return m


def main() -> None:
    sk.export(cctv_camera(), "cctv_camera", BUDGETS["cctv_camera"])
    sk.export(way_sign(), "way_sign", BUDGETS["way_sign"])
    sk.export(fire_extinguisher(), "fire_extinguisher", BUDGETS["fire_extinguisher"])
    sk.export(litter_bin(), "litter_bin", BUDGETS["litter_bin"])
    sk.export(edge_sign(), "edge_sign", BUDGETS["edge_sign"])
    sk.export(platform_clock(), "platform_clock", BUDGETS["platform_clock"])
    for cell in POSTERS:
        sk.export(poster(cell), cell, BUDGETS["poster"])
    for cell in WIDE_POSTERS:
        sk.export(poster(cell, 3.0, 1.5, 0.05), cell, BUDGETS["poster"])
    sk.export(name_board(), "name_board", BUDGETS["name_board"])


if __name__ == "__main__":
    main()
