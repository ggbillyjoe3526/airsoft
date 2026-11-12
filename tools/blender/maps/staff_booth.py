"""Subway's platform staff booths (SM4, model 27): a small prefabricated booth like the owner's photos
(art/references/maps/subway/27-staff-booth, the car-park attendant's booths): an off-white panelled body on a plinth,
a flat roof overhanging all round with a fascia, glazed in its upper half on the front and sides in grey aluminium
frames, a half-glazed door at one side of the front with its handle and kick plate, a lamp over the door, a wall-hung
air conditioner on one side (photo 3), solid back. Abandoned: its blinds are down behind grimy glass (the booth is
solid cover, so nothing is seen inside), dust and grime up from the platform.

Its six blocks (data/maps/subway.json) are three sizes, so three models, each built at its block's size, all 2.6 m
high: `staff_booth` 2 m wide (its front) and 2.2 m deep, `staff_booth_mid` 1.6 x 2.2 m and `staff_booth_small`
1.6 x 1 m. Each faces -y (its door and windows), turned to the platform by its block's facing.

Writes assets/models/props/staff_booth*.glb, each one vertex-coloured mesh filling x -W/2..W/2, y -D/2..D/2,
z 0..2.6 exactly (Godot: x across, y up, z deep).

Usage: python3 -I tools/blender/maps/staff_booth.py [--render <sheet.jpg>]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import works_kit as wk  # noqa: E402
from works_kit import wt  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET = 3000
HIGH = 2.6
SIZES = {"staff_booth": (2.0, 2.2), "staff_booth_mid": (1.6, 2.2), "staff_booth_small": (1.6, 1.0)}
OVER = 0.07          # the roof's overhang all round
PLINTH = 0.08
SILL = 1.05          # the windows' sill
HEAD = 2.25          # the windows' and the door's head
EAVE = 2.42          # the roof's underside
FR = 0.045           # a frame's width
DOOR_W = 0.78


def window(k: wk.Kit, axis: str, plane: float, out: float, a0: float, a1: float, z0: float, z1: float,
           panes: int) -> None:
    """A window on a wall: grimy glass with its blinds down (stripes), aluminium frames round it and between its
    `panes`, standing proud of the wall at `plane` (facing `out`, +1 or -1, along `axis`)."""
    def at(a: float, z: float, d: float) -> tuple:
        return (plane + out * d, a, z) if axis == "x" else (a, plane + out * d, z)

    def rect(b0: float, b1: float, c0: float, c1: float, d: float, mat: str) -> None:
        pts = [at(b0, c0, d), at(b1, c0, d), at(b1, c1, d), at(b0, c1, d)]
        n = Vector(pts[1]) - Vector(pts[0])
        m = Vector(pts[3]) - Vector(pts[0])
        want = Vector((out, 0, 0)) if axis == "x" else Vector((0, out, 0))
        k.quad(pts if n.cross(m).dot(want) > 0 else list(reversed(pts)), mat)

    rect(a0, a1, z0, z1, 0.002, "glass")
    n = 13
    for i in range(n):  # the blinds' slats seen through the glass: pale stripes, a few hanging crooked
        zb = z0 + 0.05 + i * (z1 - z0 - 0.1) / n
        rect(a0 + 0.02, a1 - 0.02, zb, zb + (z1 - z0) / n * 0.6, 0.003, "blind")
    w = FR

    def bar(b0: float, b1: float, c0: float, c1: float) -> None:
        lo = at(b0, c0, 0.0)
        hi = at(b1, c1, 0.028)
        k.blk(tuple(min(lo[i], hi[i]) for i in range(3)), tuple(max(lo[i], hi[i]) for i in range(3)), "booth_frame")

    bar(a0 - w, a1 + w, z0 - w, z0)
    bar(a0 - w, a1 + w, z1, z1 + w)
    bar(a0 - w, a0, z0, z1)
    bar(a1, a1 + w, z0, z1)
    for i in range(1, panes):
        a = a0 + (a1 - a0) * i / panes
        bar(a - w * 0.5, a + w * 0.5, z0, z1)
    lo = at(a0 - w - 0.01, z0 - w - 0.035, 0.0)  # the sill, sloping out
    hi = at(a1 + w + 0.01, z0 - w, 0.05)
    k.blk(tuple(min(lo[i], hi[i]) for i in range(3)), tuple(max(lo[i], hi[i]) for i in range(3)), "booth_frame")


def build(name: str, width: float, depth: float) -> object:
    hw, hd = width * 0.5, depth * 0.5
    bx, by = hw - OVER, hd - OVER
    k = wk.Kit(name)
    k.blk((-bx - 0.02, -by - 0.02, 0.0), (bx + 0.02, by + 0.02, PLINTH), "booth_frame")
    k.panel((-bx, -by, PLINTH), (bx, by, EAVE), "booth_white", step=0.15, skip=("-z", "+z"))
    # corner posts
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            x0, x1 = sorted((sx * (bx + 0.012), sx * (bx - 0.05)))
            y0, y1 = sorted((sy * (by + 0.012), sy * (by - 0.05)))
            k.blk((x0, y0, PLINTH), (x1, y1, EAVE), "booth_frame")
    k.mark("body")
    # The roof: a slab overhanging all round, its fascia, a drip edge.
    k.panel((-hw, -hd, EAVE), (hw, hd, HIGH), "booth_white", step=0.25)
    k.blk((-hw - 0.0, -hd, EAVE - 0.04), (hw, -hd + 0.03, EAVE), "booth_frame")
    k.blk((-hw, hd - 0.03, EAVE - 0.04), (hw, hd, EAVE), "booth_frame")
    k.mark("roof")
    # The front: the door at its +x side, a window over the rest.
    y = -by
    dx1 = bx - 0.06
    dx0 = dx1 - DOOR_W
    k.blk((dx0 - FR, y - 0.03, PLINTH), (dx0, y, HEAD + FR), "booth_frame")  # door frame
    k.blk((dx1, y - 0.03, PLINTH), (dx1 + FR, y, HEAD + FR), "booth_frame")
    k.blk((dx0 - FR, y - 0.03, HEAD), (dx1 + FR, y, HEAD + FR), "booth_frame")
    k.blk((dx0, y - 0.012, PLINTH), (dx1, y, HEAD), "booth_white")  # the door leaf
    window(k, "y", y - 0.012, -1.0, dx0 + 0.08, dx1 - 0.08, 1.15, HEAD - 0.1, 1)
    k.blk((dx0 + 0.02, y - 0.016, PLINTH + 0.02), (dx1 - 0.02, y - 0.012, PLINTH + 0.25), "steel_bare")  # kick plate
    k.blk((dx0 + 0.05, y - 0.06, 1.0), (dx0 + 0.07, y - 0.012, 1.04), "steel_bare")  # the handle and its lock
    k.blk((dx0 + 0.05, y - 0.07, 0.94), (dx0 + 0.2, y - 0.05, 0.97), "steel_bare")
    k.cyl((dx0 + 0.06, y - 0.012, 0.88), 0.016, -0.012, "steel_bare", seg=6, axis="y")
    if dx0 - FR - (-bx + 0.07) > 0.4:
        window(k, "y", y, -1.0, -bx + 0.1, dx0 - FR - 0.06, SILL, HEAD, 2 if dx0 - (-bx) > 1.0 else 1)
    # the lamp over the door
    k.blk(((dx0 + dx1) * 0.5 - 0.09, y - 0.09, HEAD + FR + 0.03), ((dx0 + dx1) * 0.5 + 0.09, y, HEAD + FR + 0.1),
          "booth_frame")
    k.blk(((dx0 + dx1) * 0.5 - 0.07, y - 0.08, HEAD + FR + 0.02), ((dx0 + dx1) * 0.5 + 0.07, y - 0.01,
                                                                   HEAD + FR + 0.03), "glass")
    k.mark("front")
    # The sides: a window in each (not on a booth too shallow), the air conditioner hung on the -x side.
    for sx in (-1.0, 1.0):
        if depth > 1.5:
            window(k, "x", sx * bx, sx, -by + 0.15, by - 0.4, SILL, HEAD, 2)
        elif sx > 0:
            window(k, "x", sx * bx, sx, -by + 0.12, by - 0.12, 1.3, HEAD, 1)
    ax0, ax1 = sorted((-bx, -bx - OVER + 0.003))
    ay = by - 0.45 if depth > 1.5 else 0.0
    k.blk((ax0, ay - 0.3, 0.45), (ax1, ay + 0.3, 0.85), "cab_grey")
    for i in range(6):  # its grille
        z = 0.5 + i * 0.055
        k.blk((ax0 - 0.004, ay - 0.26, z), (ax0, ay + 0.26, z + 0.02), "grille")
    k.bar((ax0 + 0.01, ay + 0.2, 0.45), (ax0 + 0.01, ay + 0.2, PLINTH), 0.012, "plinth", seg=4)  # its drain
    # the back: panel seams; a vent high up
    for x in (-bx / 3, bx / 3):
        k.quad([(x + 0.006, by + 0.002, PLINTH), (x - 0.006, by + 0.002, PLINTH), (x - 0.006, by + 0.002, EAVE),
                (x + 0.006, by + 0.002, EAVE)], "booth_frame")
    k.blk((-0.12, by, 2.0), (0.12, by + 0.02, 2.15), "grille")
    k.mark("sides")
    return k.build()


def weather(p: Vector, n: Vector, c: tuple, paint: str) -> tuple:
    if paint in ("booth_white", "booth_frame", "cab_grey"):
        col = wt.mix(c, wk.lin(wk.GRIME), 0.12 + 0.3 * wt.smooth(0.4, 0.8, wt.fbm(p, 0.2, 81)))
        streak = wt.smooth(0.6, 0.85, wt.fbm(Vector((p.x * 7.0, p.y * 7.0, p.z * 0.5)), 0.5, 83)) * (1 - abs(n.z))
        col = wt.mix(col, wk.lin(wk.GRIME), 0.3 * streak * wt.smooth(1.2, EAVE, p.z))  # streaks from the roof
        return wk.grime(p, n, col, seed=16)
    if paint == "glass":
        return wt.mix(c, wk.lin(wk.GRIME), 0.35 * wt.fbm(p, 0.15, 85))
    if paint == "blind":
        return wt.mix(c, wk.lin("glass"), 0.55 + 0.2 * wt.fbm(p, 0.2, 87))  # seen through dirty glass
    return wk.grime(p, n, c, seed=4, amount=0.6)


def main() -> None:
    wk.check_colours(list(wk.PAINT))
    for name, (width, depth) in SIZES.items():
        wk.reset()
        ob = build(name, width, depth)
        wk.finish(ob, (-width * 0.5, -depth * 0.5, 0.0), (width * 0.5, depth * 0.5, HIGH))
        wk.bake(ob, weather)
        wk.write(ob, name, BUDGET)
        if "--render" in sys.argv:
            out = sys.argv[sys.argv.index("--render") + 1].replace(".jpg", "_%s.jpg" % name)
            wk.render(wk.quarter_views(width, depth, HIGH), out,
                      "SM4 %s (Subway map prop, %g x %g x 2.6 m)" % (name.replace("_", " "), width, depth))


if __name__ == "__main__":
    main()
