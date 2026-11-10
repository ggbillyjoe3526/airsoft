"""The range's figure targets (RM1): a flat plywood cut-out in a peg figure's outline on a steel hinge plate, standing
(William's first photo, art/references/maps/william-2026-11-09/plywood_figure_target: a round head on a collar over
a straight body) and crouched (his second: the head on a cone with a foot ring), flat as he asked (2026-11-09),
plus the pop-up's motor box and the mover's rails, end stops and trolley.

A cut-out is the size of a player's hit volume, so what you see is what a BB hits (HitConfig: the head's ball, radius
0.13 m, 1.62 m over the feet, the body 0.2 m round up to 1.5 m; a crouch drops both 0.62 m), standing on its hinge
plate BodyConfig.rest_gap (0.04 m) high.

Writes assets/models/range/figure_target.glb, one mesh a part, each laid where RangeTargetsView puts it:

  PegBase       the hinge plate under the peg, its origin the figure's feet (it rides a mover's trolley)
  Peg           the standing cut-out (0.025 m board, its face to the front) and its hinge leaf, its origin the
                hinge's axis (0.039 m behind the board's face, 0.04 m up): it falls back about it
  PegCrouched   the crouched (cone) cut-out, the same
  MotorBox      the pop-up's motor box, 0.2 x 0.16 x 0.24 m (RangeViewConfig.popup_box) about its middle, its drive
                shaft reaching the hinge
  Rail          one rail, 1 m along x about its middle (stretched to the track), on the floor
  RailStop      a rail's end stop across both rails (0.08 x 0.1 m, RangeViewConfig.stop_size), its origin its foot
  Trolley       the mover's trolley under the feet: 0.5 x 0.42 m, from the rails' tops (0.08 m down) to the feet

Usage: python3 tools/blender/maps/plywood_figure_target.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import range_kit as rk  # noqa: E402

OUT = os.path.join(rk.RANGE, "figure_target.glb")
PEG_BUDGET = 600
BASE_BUDGET = 250  # the hinge plate under every peg
BOX_BUDGET = 800
RAIL_BUDGET = 1500

GAP = 0.04  # BodyConfig.rest_gap
HEAD = 1.62  # HitConfig.head_height
HEAD_R = 0.13  # HitConfig.head_radius
BODY_R = 0.2  # HitConfig.body_radius
TOP = 1.5  # HitConfig.body_top
DROP = 0.62  # HitConfig.crouch_drop
THICK = 0.025  # the cut-out's board (William: flat, like thick card)
HINGE = (THICK + 0.014, GAP)  # the hinge's axis: (behind the board's face, up)
BOX = (0.2, 0.16, 0.24)  # RangeViewConfig.popup_box: across, up, deep
RAIL = 0.04  # RangeViewConfig.rail
GAUGE = 0.3  # RangeViewConfig.rail_gauge
STOP = (0.08, 0.1)  # RangeViewConfig.stop_size
TROLLEY = (0.5, 0.42)  # RangeViewConfig.trolley_size
FEET = 0.12  # RangeConfig.mover_trolley_height
SEG = 15

rk.check_colours(["peg_wood", "peg_end", "stand_black", "zinc", "motor_grey", "rail_steel", "rubber"])


def _head(z: float, from_r: float, steps: int) -> list:
    """The head's ball, centred `z` high, from where it is `from_r` round to its crown, as (z, r)."""
    a0 = -math.pi * 0.5 + math.asin(from_r / HEAD_R)
    pts = []
    for i in range(steps + 1):
        a = a0 + (math.pi * 0.5 - a0) * i / steps
        pts.append((z + HEAD_R * math.sin(a), HEAD_R * math.cos(a)))
    pts[-1] = (z + HEAD_R, 0.0)
    return pts


def _leaf(k: rk.Kit) -> None:
    """The hinge's moving leaf: a strap up the board's back from the knuckle, screwed on."""
    hy, hz = HINGE
    k.blk((-0.05, THICK, hz - 0.004), (0.05, THICK + 0.01, hz + 0.16), "stand_black")
    k.cyl((-0.03, hy, hz), 0.014, 0.06, "stand_black", seg=8, axis="x")
    for z in (hz + 0.06, hz + 0.13):
        for x in (-0.028, 0.028):
            k.cyl((x, THICK + 0.01, z), 0.006, 0.003, "zinc", seg=5, axis="y")


def _outline(profile: list) -> list:
    """A flat cut-out's outline (x, z) from a peg's turned profile (z, r): its right side up, its left side down."""
    right = [(r, z) for z, r in profile if r > 1e-6]
    crown = [(0.0, z) for z, r in profile if r <= 1e-6]
    return right + crown + [(-x, z) for x, z in reversed(right)]


def peg(name: str, crouched: bool) -> object:
    """A flat plywood cut-out in the outline of William's pegs (2026-11-09: "flat, like a thick piece of cardboard,
    2D not 3D; keep the outline"), its face through y = 0 and THICK deep behind it, its sawn edge a shade darker."""
    k = rk.Kit(name)
    drop = DROP if crouched else 0.0
    head_z = GAP + HEAD - drop
    top = GAP + TOP - drop
    if not crouched:
        # The straight body, its foot and shoulders rounded; the collar under the head (photo 1).
        profile = [(GAP, 0.18), (GAP + 0.012, 0.197), (GAP + 0.03, BODY_R), (top - 0.07, BODY_R),
                   (top - 0.035, 0.192), (top - 0.012, 0.165), (top, 0.12), (top + 0.006, 0.1),
                   (top + 0.012, 0.094), (top + 0.026, 0.094),
                   (top + 0.032, 0.097)] + _head(head_z, 0.1, 24)  # the head swells from the neck, never back down
    else:
        # The cone body on a foot ring, rising straight into the head (photo 2).
        profile = [(GAP, 0.15), (GAP + 0.04, 0.158), (GAP + 0.045, 0.2), (GAP + 0.06, 0.218), (GAP + 0.08, 0.22),
                   (top - 0.12, 0.125), (top - 0.03, 0.098), (top + 0.02, 0.083)] + _head(head_z, 0.083, 24)[1:]
    faces = k.prism(_outline(profile), "y", 0.0, THICK, "peg_wood")
    k._faces(faces[2:], "peg_end")
    _leaf(k)
    ob = k.build()
    rk.finish(ob, angle=math.radians(35.0))
    # The hinge's axis to the origin.
    ob.data.transform(_to_hinge())
    rk.bake(ob)
    return ob


def _to_hinge():
    from mathutils import Matrix
    return Matrix.Translation((0.0, -HINGE[0], -HINGE[1]))


def peg_base() -> object:
    k = rk.Kit("PegBase")
    hy, hz = HINGE
    # The plate on two feet running front to back, its fixed knuckles either side of the board's and the pin through
    # all three.
    k.blk((-0.22, -0.08, 0.026), (0.22, 0.1, GAP - 0.001), "stand_black")
    for x in (-0.18, 0.18):
        k.blk((x - 0.02, -0.2, 0.0), (x + 0.02, 0.2, 0.026), "stand_black")
    for x0 in (-0.12, 0.04):
        k.cyl((x0, hy, hz), 0.014, 0.08, "stand_black", seg=8, axis="x")
        k.blk((x0, hy - 0.004, 0.026), (x0 + 0.08, hy + 0.012, hz), "stand_black")
    k.cyl((-0.13, hy, hz), 0.005, 0.26, "zinc", seg=6, axis="x")
    for x in (-0.18, 0.18):
        for y in (-0.05, 0.07):
            k.cyl((x, y, GAP - 0.001), 0.009, 0.003, "zinc", seg=6)
    ob = k.build()
    rk.finish(ob)
    rk.bake(ob)
    return ob


def motor_box() -> object:
    k = rk.Kit("MotorBox")
    hx, hz, hy = BOX[0] * 0.5, BOX[1] * 0.5, BOX[2] * 0.5
    # The housing, a lid with screws and a lip, cooling fins down the outer side, a cable gland and cable at the
    # back, a stub aerial, and the drive shaft out of the inner side to the hinge (0.2 m behind the figure's middle,
    # 0.04 m up: 0.08 m behind and 0.04 m under the box's middle).
    k.blk((-hx, -hy, -hz), (hx, hy, hz - 0.03), "motor_grey")
    k.blk((-hx - 0.004, -hy - 0.004, hz - 0.03), (hx + 0.004, hy + 0.004, hz - 0.022), "motor_grey")
    k.blk((-hx + 0.004, -hy + 0.004, hz - 0.022), (hx - 0.004, hy - 0.004, hz), "stand_black")
    for x in (-hx + 0.018, hx - 0.018):
        for y in (-hy + 0.018, hy - 0.018):
            k.cyl((x, y, hz), 0.006, 0.002, "zinc", seg=6)
    for i in range(5):
        y = -hy + 0.03 + i * (2 * hy - 0.06) / 4.0
        k.blk((hx, y - 0.004, -hz + 0.02), (hx + 0.012, y + 0.004, hz - 0.045), "motor_grey")
    k.blk((-hx - 0.006, -hy - 0.006, -hz), (hx + 0.006, hy + 0.006, -hz + 0.01), "stand_black")
    k.cyl((0.04, hy, -hz + 0.05), 0.012, 0.02, "rubber", seg=8, axis="y")
    k.bar((0.04, hy + 0.02, -hz + 0.05), (0.04, hy + 0.035, -hz + 0.005), 0.006, "rubber", seg=5)
    k.cyl((hx - 0.03, hy - 0.03, hz), 0.006, 0.13, "rubber", seg=6)
    k.cyl((hx - 0.03, hy - 0.03, hz), 0.011, 0.02, "rubber", seg=6)
    sy, sz = 0.08, -0.04
    k.cyl((-hx - 0.012, sy, sz), 0.022, 0.012, "stand_black", seg=10, axis="x")
    k.cyl((-hx - 0.11, sy, sz), 0.008, 0.11, "zinc", seg=8, axis="x")
    ob = k.build()
    rk.finish(ob)
    rk.bake(ob)
    return ob


def rail() -> object:
    k = rk.Kit("Rail")
    # A light flat-bottomed rail: foot, web and head, RAIL wide and high, 1 m long.
    w = RAIL * 0.5
    prof = [(-w, 0.0), (w, 0.0), (w, 0.006), (0.004, 0.01), (0.004, RAIL - 0.012), (0.011, RAIL - 0.01),
            (0.011, RAIL), (-0.011, RAIL), (-0.011, RAIL - 0.01), (-0.004, RAIL - 0.012), (-0.004, 0.01),
            (-w, 0.006)]
    k.prism(prof, "x", -0.5, 0.5, "rail_steel")
    ob = k.build()
    rk.finish(ob)
    rk.bake(ob)
    return ob


def rail_stop() -> object:
    k = rk.Kit("RailStop")
    half = (GAUGE + RAIL) * 0.5
    w, h = STOP
    # A welded block over both rails' ends, a rubber buffer facing the trolley (towards -x), bolts down through it.
    k.blk((-w * 0.5, -half, 0.0), (w * 0.5, half, h), "stand_black")
    for y in (-GAUGE * 0.5, GAUGE * 0.5):
        k.cyl((-w * 0.5 - 0.02, y, h * 0.55), 0.022, 0.02, "rubber", seg=10, axis="x")
        k.cyl((0.0, y + 0.05 * (-1 if y > 0 else 1), h), 0.01, 0.004, "zinc", seg=6)
    ob = k.build()
    rk.finish(ob)
    rk.bake(ob)
    return ob


def trolley() -> object:
    k = rk.Kit("Trolley")
    hx, hy = TROLLEY[0] * 0.5, TROLLEY[1] * 0.5
    high = FEET - RAIL
    # The deck the figure stands on, side skirts outside the rails, four flanged wheels on the rail heads, the axle
    # boxes, and the tow bracket the drive cable pulls.
    k.blk((-hx, -hy, -0.012), (hx, hy, 0.0), "stand_black")
    for sy in (-1.0, 1.0):
        k.blk((-hx, sy * hy - 0.006, -high + 0.012), (hx, sy * hy + 0.006 * -sy, -0.012), "stand_black")
        for sx in (-1.0, 1.0):
            y = sy * GAUGE * 0.5
            k.cyl((sx * 0.17, y - 0.012, -high + 0.026), 0.026, 0.024, "rail_steel", seg=12, axis="y")
            k.cyl((sx * 0.17, y - 0.016 if sy > 0 else y + 0.012, -high + 0.026), 0.032, 0.004, "rail_steel",
                  seg=12, axis="y")
            k.blk((sx * 0.17 - 0.02, y - 0.03 if sy < 0 else y + 0.012, -high + 0.012),
                  (sx * 0.17 + 0.02, y - 0.012 if sy < 0 else y + 0.03, -0.012), "motor_grey")
    k.blk((-hx - 0.0, -0.03, -0.05), (-hx + 0.04, 0.03, -0.012), "motor_grey")
    k.cyl((-hx - 0.0, 0.0, -0.032), 0.008, 0.04, "zinc", seg=6, axis="x")
    ob = k.build()
    rk.finish(ob)
    rk.bake(ob)
    return ob


def main() -> None:
    rk.reset()
    pegs = [peg("Peg", False), peg("PegCrouched", True)]
    base = peg_base()
    box = motor_box()
    rails = [rail(), rail_stop(), trolley()]
    print("pegs (budget %d each):" % PEG_BUDGET)
    rk.report(pegs + [base])
    print("motor box (budget %d):" % BOX_BUDGET)
    nb = rk.report([box])
    print("rails and trolley (budget %d):" % RAIL_BUDGET)
    nr = rk.report(rails, {"Rail": 2, "RailStop": 2})  # as RangeTargetsView draws them
    if any(rk.hs.tris(p) > PEG_BUDGET for p in pegs) or rk.hs.tris(base) > BASE_BUDGET or nb > BOX_BUDGET \
            or nr > RAIL_BUDGET:
        raise SystemExit("over budget")
    os.makedirs(rk.RANGE, exist_ok=True)
    parts = [base] + pegs + [box] + rails
    rk.export(OUT, parts)
    print("wrote", os.path.relpath(OUT, rk.ROOT))
    if "--render" in sys.argv:
        _render(parts, sys.argv[sys.argv.index("--render") + 1])


def _render(parts: list, out: str) -> None:
    import bpy
    from mathutils import Matrix
    base, peg_, crouched, box, rail_, stop, troll = parts

    def place(ob: object, at: tuple, scale: tuple = (1.0, 1.0, 1.0), rot_x: float = 0.0) -> None:
        c = ob.copy()
        bpy.context.scene.collection.objects.link(c)
        c.matrix_world = Matrix.Translation(at) @ Matrix.Rotation(rot_x, 4, "X") @ Matrix.Diagonal((*scale, 1.0))
        c.hide_render = False

    for ob in parts:
        ob.hide_render = True

    def figure(x: float, which: object, feet: float = 0.0, down: float = 0.0) -> None:
        place(base, (x, 0.0, feet))
        place(which, (x, HINGE[0], feet + HINGE[1]), rot_x=down)

    figure(0.0, peg_)
    figure(0.8, crouched)
    # A pop-up, its motor box beside the hinge.
    figure(1.8, peg_)
    place(box, (1.8 + 0.21 + 0.03 + BOX[0] * 0.5, BOX[2] * 0.5, BOX[1] * 0.5))
    # A figure lying back after a hit.
    figure(-1.0, peg_, down=-1.45)
    # A mover: 3.7 m of track at x = 4.5, the figure on its trolley.
    mx = 4.6
    half = 1.6 + TROLLEY[0] * 0.5
    for s in (-1.0, 1.0):
        place(rail_, (mx, s * GAUGE * 0.5, 0.0), (half * 2.0, 1.0, 1.0))
        place(stop, (mx + s * (half + STOP[0] * 0.5), 0.0, 0.0), (s, 1.0, 1.0))
    place(troll, (mx + 0.6, 0.0, FEET))
    figure(mx + 0.6, crouched, feet=FEET)
    import range_render as rr
    rr.render_sheet([
        ("Peg figures: standing, crouched, a pop-up (motor box); one down", (-1.6, -4.2, 1.5), (1.0, 0.0, 0.8), 32),
        ("Rear quarter: hinge plates and leaves", (2.6, 2.9, 1.0), (0.6, 0.0, 0.5), 35),
        ("Standing peg head and collar", (-0.2, -1.1, 1.75), (0.0, 0.0, 1.6), 45),
        ("Pop-up motor box and hinge: close-up", (2.6, -0.9, 0.5), (2.0, 0.12, 0.08), 40),
        ("Mover: rails, end stops, trolley (crouched peg)", (mx - 2.2, -3.0, 1.4), (mx + 0.3, 0.0, 0.3), 32),
        ("From the firing line (10 m)", (0.8, -10.0, 1.55), (1.5, 0.0, 0.9), 40),
    ], out, "RM1 range figure targets (range model, not a bot): flat plywood cut-outs in his pegs' outlines")


if __name__ == "__main__":
    main()
