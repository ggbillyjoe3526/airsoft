"""The range's water tote (RM1, rebuilt RM2): an IBC, a milky plastic tank in a galvanised tube cage on a black plastic
pallet, a screw cap on top, a ball valve at the front foot and a blank label plate on the cage (William's photos,
art/references/maps/william-2026-11-09/water_tote; no brand or writing). RM2: the cage's top and bottom frames bent
round at their corners and the corner posts bent into them, its rows thicker and welded over the verticals; the valve
back in a moulded recess in the tank's foot, behind the cage's front, so no bar runs through it; the water's line
showing through the milky tank.

Writes assets/models/props/water_tote.glb, one vertex-coloured mesh filling x -0.6..0.6, y -0.6..0.6, z 0..1.2
exactly (its block in range.json; Godot: x across, y up, z deep), the valve towards -y (Godot's +z, the front
PropLayout turns towards the field).

Usage: python3 tools/blender/maps/water_tote.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import range_kit as rk  # noqa: E402
from range_kit import hs  # noqa: E402

OUT = os.path.join(rk.PROPS, "water_tote.glb")
BUDGET = 5000  # docs/CC0_ASSETS.md › Size limits: a prop (RM2: round tubes, a rounder tank)
HW = 0.6
HIGH = 1.2
PALLET = 0.15
CAGE = 0.585  # the cage's tubes' outer faces
TUBE = 0.011
ROW_TUBE = 0.0135  # the cage's rows, thicker than its verticals, welded over them (RM2)
TANK = 0.55
HOOP_OUT = 0.008  # the cage's rows stand this far outside its verticals
TUBE_SEG, FRAME_SEG = 8, 10  # the cage's tubes round (RM2: 5 and 6 sides read square)
BEND = 0.05  # the top and bottom frames' corners bent round this radius, the corner posts bent into them (RM2)
# The tank's moulded recess at its front foot, where the outlet valve sits behind the cage's front (RM2: a real IBC's
# valve sits back in the tank, the cage clear of it): its half width, how deep and how high.
NICHE_W, NICHE_D, NICHE_TOP = 0.11, 0.075, 0.3
FRONT_XS = (-0.18, -NICHE_W, -0.05, 0.05, NICHE_W, 0.18)  # the extra points along the tank's front for the recess
WATER = 0.74  # the water's line seen through the milky tank

rk.check_colours(["tank", "tank_shade", "tank_water", "cage", "pallet_black", "cap", "valve", "lever", "label"],
                 shade=0.05)


def _tank_ring(s: float, r: float, z: float, niche: bool) -> list:
    """A ring of the tank: a square s either side, its corners rounded r in 6 steps, with points along its front for
    the valve's recess, pushed NICHE_D in between +-NICHE_W when `niche`."""
    pts = [(x, y, z) for x, y in hs.rounded_rect(s, s, r, 6)]
    front = []
    for x in FRONT_XS:
        y = -s + (NICHE_D if niche and abs(x) <= NICHE_W + 1e-6 else 0.0)
        front.append((x, y, z))
    i = 3 * 7  # after the third corner (-x, -y), counter-clockwise: the front's run from -x to +x
    return pts[:i] + front + pts[i:]


def _tube(k: rk.Kit, path: list, r: float, mat: str, seg: int, closed: bool = False) -> None:
    """A round tube `r` along `path` (points), its rings square to the path, bent smoothly where it turns; a loop
    when `closed`, else capped at both ends."""
    from mathutils import Vector
    pts = [Vector(p) for p in path]
    n = len(pts)
    rings = []
    ref = None
    for i in range(n):
        if closed:
            t = (pts[(i + 1) % n] - pts[i - 1]).normalized()
        else:
            t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        if ref is None:
            ref = Vector((0.0, 0.0, 1.0)) if abs(t.z) < 0.9 else Vector((1.0, 0.0, 0.0))
        u = (ref - t * ref.dot(t)).normalized()
        ref = u
        v = t.cross(u)
        rings.append([tuple(pts[i] + (u * math.cos(math.tau * j / seg) + v * math.sin(math.tau * j / seg)) * r)
                      for j in range(seg)])
    if closed:
        rings.append(rings[0])
    k.loft(rings, mat, cap0=not closed, cap1=not closed)


def _loop(c: float, z: float, bend: float) -> list:
    """A square loop c either side at height z, its corners bent round `bend` in 3 steps."""
    return [(x, y, z) for x, y in hs.rounded_rect(c, c, bend, 3)]


def build() -> object:
    k = rk.Kit("WaterTote")
    # The pallet: a deck on three runners with a foot block at each corner and middle (black plastic).
    k.blk((-HW, -HW, PALLET - 0.035), (HW, HW, PALLET), "pallet_black")
    for x in (-HW + 0.07, 0.0, HW - 0.07):
        for y in (-HW + 0.07, 0.0, HW - 0.07):
            k.blk((x - 0.07, y - 0.07, 0.0), (x + 0.07, y + 0.07, PALLET - 0.035), "pallet_black")
    for y in (-HW + 0.07, HW - 0.07):
        k.blk((-HW, y - 0.07, 0.0), (HW, y + 0.07, 0.025), "pallet_black")
    # The tank: a rounded box, moulded with a shallow lid well, its lower corners a shade darker where the cage's
    # base holds it.
    top = HIGH - 0.06
    rings = []
    # (RM2: its corners rounded in 6 steps, its shoulders rolled over in three rings, its walls bellied 6 mm by
    # the water between the cage's bars; a recess at its front foot for the valve; below the water's line it shows
    # the water through the milky plastic.)
    for z, s, r, nc in ((PALLET, TANK - 0.03, 0.07, True), (PALLET + 0.015, TANK - 0.01, 0.08, True),
                        (PALLET + 0.04, TANK, 0.09, True), (NICHE_TOP, TANK + 0.002, 0.092, True),
                        (NICHE_TOP + 0.03, TANK + 0.003, 0.093, False), (WATER, TANK + 0.006, 0.095, False),
                        (top - 0.05, TANK, 0.09, False), (top - 0.02, TANK - 0.012, 0.085, False),
                        (top, TANK - 0.04, 0.07, False)):
        rings.append(_tank_ring(s, r, z, nc))
    k.loft(rings[:6], "tank_water", cap1=False)
    k.loft(rings[5:], "tank", cap0=False)
    def span(sv: float) -> tuple:
        return (TANK - 0.12, TANK + 0.004) if sv > 0 else (-TANK - 0.004, -TANK + 0.12)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            (x0, x1), (y0, y1) = span(sx), span(sy)
            k.blk((x0, y0, PALLET), (x1, y1, PALLET + 0.12), "pallet_black")
    # The screw cap on the lid, and the ball valve at the front foot with its yellow lever.
    k.cyl((0.0, 0.05, top), 0.075, 0.035, "cap", seg=24)
    k.lathe([(0.0, 0.0), (0.0, 0.062), (0.008, 0.06), (0.012, 0.052), (0.012, 0.0)], "cap", segments=24,
            centre=(0.0, 0.05, top + 0.035), axis="z")
    # The ball valve: a stub out of the tank's foot, the valve's round body across it, its outlet with a screw cap
    # to the front, and the yellow lever on top.
    # The valve sits back in the tank's recess, behind the cage's front (its verticals' backs at y -0.563) and under
    # its lowest row (z 0.257), between its two middle verticals (x +-0.082): nothing of the cage runs through it.
    back = -TANK + NICHE_D
    vx, vz, vy = 0.0, PALLET + 0.055, -0.525
    k.cyl((vx, vy, vz), 0.034, back - vy, "valve", seg=16, axis="y")  # the stub out of the recess's back
    k.cyl((vx - 0.06, vy, vz), 0.026, 0.12, "valve", seg=16, axis="x")  # the valve's body, 0.12 m across
    for x in (vx - 0.062, vx + 0.042):  # its union nuts
        k.cyl((x, vy, vz), 0.031, 0.02, "valve", seg=6, axis="x")
    k.cyl((vx, -0.552, vz), 0.028, vy + 0.552, "valve", seg=16, axis="y")  # the outlet
    k.cyl((vx, -0.558, vz), 0.033, 0.008, "cap", seg=16, axis="y")  # its cap
    k.blk((vx - 0.012, vy - 0.007, vz + 0.027), (vx + 0.06, vy + 0.007, vz + 0.038), "lever")  # flat on top
    # The cage: a frame at the top, posts at the corners, verticals between, five rows of horizontals (the photos'
    # grid), two bars over the top.
    c = CAGE - TUBE
    z0, z1 = PALLET, HIGH - TUBE
    n = 7
    xs = [-c + 2 * c * i / n for i in range(n + 1)]
    for side in range(4):
        def at(u: float, z: float, inset: float = 0.0) -> tuple:
            w = c - inset
            return [(u, -w, z), (w, u, z), (-u, w, z), (-w, -u, z)][side]
        for u in xs[1:-1]:
            k.bar(at(u, z0), at(u, z1), TUBE, "cage", seg=TUBE_SEG, cap=False)
        # the corner post, bent in at its top into the frame's bent corner
        cx, cy, _ = at(-c, z1)
        corner = []
        for i in range(4):
            a = 0.5 * math.pi * i / 3
            pull = BEND * (1.0 - math.sqrt(0.5)) * (1.0 - math.cos(a))
            corner.append((cx - math.copysign(pull, cx), cy - math.copysign(pull, cy), z1 - BEND + BEND * math.sin(a)))
        _tube(k, [(cx, cy, z0)] + corner, TUBE * 1.3, "cage", FRAME_SEG)
        for row in range(5):
            z = z0 + 0.12 + row * (z1 - z0 - 0.12) / 4.5
            # The rows sit on the outside of the verticals, welded where they cross (never one tube through the
            # other's middle, where the two round faces meet in a point), thicker, running round the corner posts.
            k.bar(at(-c - HOOP_OUT, z, -HOOP_OUT), at(c + HOOP_OUT, z, -HOOP_OUT), ROW_TUBE, "cage", seg=TUBE_SEG,
                  cap=False)
    _tube(k, _loop(c, z1, BEND), TUBE * 1.3, "cage", FRAME_SEG, closed=True)
    _tube(k, _loop(c, z0 + 0.01, BEND), TUBE * 1.3, "cage", FRAME_SEG, closed=True)
    for y in (-0.22, 0.32):
        k.bar((-c, y, z1), (c, y, z1), TUBE, "cage", seg=TUBE_SEG)
    # A blank dark label plate on the front (the photos' notice plate, no writing).
    # Fixed on the cage over its bars, with a clip at each corner.
    k.blk((-0.42, -CAGE - 0.008, 0.42), (-0.02, -CAGE - 0.002, 0.82), "label")
    for x in (-0.4, -0.04):
        for z in (0.44, 0.8):
            k.blk((x - 0.012, -CAGE - 0.011, z - 0.012), (x + 0.012, -CAGE - 0.008, z + 0.012), "cage")
    ob = k.build()
    rk.finish(ob, bevel=0.004, angle=math.radians(50.0))  # the pallet and plate edges rounded (RM2)
    rk.clamp_to(ob, (-HW, -HW, 0.0), (HW, HW, HIGH))
    rk.bake(ob, seed=5)
    rk.occlude(ob, strength=0.45, distance=0.1)
    rk.fit_box(ob, (-HW, -HW, 0.0), (HW, HW, HIGH))
    return ob


def main() -> None:
    rk.reset()
    ob = build()
    n = rk.report([ob])
    if n > BUDGET:
        raise SystemExit("over budget")
    rk.export(OUT, [ob])
    print("wrote", os.path.relpath(OUT, rk.ROOT))
    if "--render" in sys.argv:
        import range_render as rr
        rr.render_sheet([
            ("Front quarter (valve, label plate)", (-2.0, -2.8, 1.7), (0.0, 0.0, 0.6), 35),
            ("Rear quarter", (2.3, 2.6, 1.9), (0.0, 0.0, 0.6), 35),
            ("Valve in its recess, behind the cage: close-up", (0.3, -1.25, 0.32), (0.0, -0.55, 0.22), 40),
            ("Top: cap and cage bars", (-1.0, -1.4, 2.6), (0.0, 0.0, 1.1), 35),
            ("Side", (3.0, 0.0, 0.9), (0.0, 0.0, 0.6), 35),
            ("From 10 m", (-3.0, -9.5, 1.6), (0.0, 0.0, 0.6), 40),
        ], sys.argv[sys.argv.index("--render") + 1],
            "Water tote / IBC (Range map prop, RM2 rebuild): bent frame, thick welded rows, valve in its recess, "
            "the water's line")


if __name__ == "__main__":
    main()
