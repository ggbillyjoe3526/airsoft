"""The range's steel plate targets (RM1): a white round plate hung by its hooked neck from a pin, on a timber post in a
black steel H-stand (William's photos, art/references/maps/william-2026-11-09/steel_plate_target: the round white
plate, the 2x2 post in a welded base, the hook over a bracket), and the swinger's frame and arm.

Writes assets/models/range/steel_target.glb, one mesh a part, each laid where RangeTargetsView puts it:

  Base     the H-stand and the post's socket, its origin the post's foot (the post stands RangeConfig.post_behind
           behind the plate's face)
  Post     a 1 m timber post from its foot, stretched to the post's height
  Bracket  the steel cap on the post's top with the hanger pin, its origin the post's top
  Hanger   the plate's neck and hook round the pin, its origin the pin (the plate swings about it)
  Face     the plate, radius 0.2 m (the small plate is it scaled), its front face through the origin: the disc the
           simulation tests BBs against (RangeConfig.plate_radius)
  SwingLeg, SwingFoot, SwingBar, SwingPivot, SwingArm
           the swinger's frame: a 1 m square-tube leg from its foot, its splayed foot, a 1 m bar along x (both
           stretched), the bearing under the bar's middle and the 1 m arm down from it to the plate's clamp

Usage: python3 tools/blender/maps/steel_plate_target.py [--render <sheet.jpg>]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import range_kit as rk  # noqa: E402
from range_kit import hs  # noqa: E402

OUT = os.path.join(rk.RANGE, "steel_target.glb")
BUDGET = 800  # stand and plate
FRAME_BUDGET = 1500

PLATE_R = 0.2  # RangeConfig.plate_radius
PLATE_T = 0.025  # RangeViewConfig.plate_thickness
POST_W = 0.05  # RangeConfig.post_width
POST_BEHIND = 0.06  # RangeConfig.post_behind
NECK_DROP = 0.1  # RangeConfig.post_above_plate: the pin to the plate's top
FRAME_W = 0.06  # RangeConfig.swinger_frame_width
ARM = 1.0  # RangeConfig.swinger_arm

rk.check_colours(["plate_white", "stand_black", "zinc", "post_timber"])


def base() -> object:
    k = rk.Kit("Base")
    # Two runners front to back and the cross channel joining them under the socket (the photos' welded H).
    for sx in (-1.0, 1.0):
        x = sx * 0.21
        k.blk((x - 0.02, -0.28, 0.0), (x + 0.02, 0.22, 0.006), "stand_black")
        k.blk((x - 0.02, -0.28, 0.006), (x - 0.014, 0.22, 0.04), "stand_black")  # the angle's upright leg
        # stake slots: a raised lip round each end
        for y in (-0.25, 0.19):
            k.blk((x - 0.016, y - 0.012, 0.006), (x + 0.016, y + 0.012, 0.009), "stand_black")
    k.blk((-0.23, -0.025, 0.0), (0.23, 0.025, 0.035), "stand_black")
    # The socket: a square tube round the post's foot, a gusset either side, a bolt through it.
    t = 0.007
    h = 0.24
    w = POST_W * 0.5 + t
    k.blk((-w, -w, 0.0), (w, -w + t, h), "stand_black")
    k.blk((-w, w - t, 0.0), (w, w, h), "stand_black")
    k.blk((-w, -w + t, 0.0), (-w + t, w - t, h), "stand_black")
    k.blk((w - t, -w + t, 0.0), (w, w - t, h), "stand_black")
    for sx in (-1.0, 1.0):
        k.prism([(sx * w, 0.035), (sx * 0.17, 0.035), (sx * w, 0.17)], "y", -0.004, 0.004, "stand_black")
    k.cyl((-w - 0.012, 0.0, 0.16), 0.008, 2 * w + 0.024, "zinc", seg=6, axis="x")
    k.cyl((-w - 0.012, 0.0, 0.16), 0.012, 0.006, "zinc", seg=6, axis="x")
    k.cyl((w + 0.006, 0.0, 0.16), 0.012, 0.006, "zinc", seg=6, axis="x")
    ob = k.build()
    rk.finish(ob)
    rk.bake(ob)
    return ob


def post() -> object:
    k = rk.Kit("Post")
    hw = POST_W * 0.5
    c = 0.004
    oct_ = [(-hw + c, -hw), (hw - c, -hw), (hw, -hw + c), (hw, hw - c), (hw - c, hw), (-hw + c, hw), (-hw, hw - c),
            (-hw, -hw + c)]
    k.prism(oct_, "z", 0.0, 1.0, "post_timber")
    ob = k.build()
    rk.finish(ob)
    rk.bake(ob)
    return ob


def bracket() -> object:
    k = rk.Kit("Bracket")
    t = 0.005
    w = POST_W * 0.5 + t
    # The cap over the post's top and its cheeks reaching forward past the pin (at y = -POST_BEHIND).
    k.blk((-w, -w, 0.0), (w, w, t), "stand_black")
    for sx in (-1.0, 1.0):
        x0, x1 = (w - t, w) if sx > 0 else (-w, -w + t)
        k.prism([(w, -0.05), (w, t), (-POST_BEHIND - 0.016, t), (-POST_BEHIND - 0.016, -0.012),
                 (-POST_BEHIND + 0.02, -0.03), (-w, -0.05)], "x", x0, x1, "stand_black")
    # The pin across the cheeks, with its head and nut.
    k.cyl((-w - 0.008, -POST_BEHIND, 0.0), 0.0055, 2 * w + 0.016, "zinc", seg=8, axis="x")
    k.cyl((-w - 0.008, -POST_BEHIND, 0.0), 0.01, 0.005, "zinc", seg=6, axis="x")
    k.cyl((w + 0.003, -POST_BEHIND, 0.0), 0.01, 0.005, "zinc", seg=6, axis="x")
    ob = k.build()
    rk.finish(ob)
    rk.bake(ob)
    return ob


def _strap(k: rk.Kit, path: list, w: float, t: float, mat: str) -> None:
    """A flat strap `w` wide (along x) and `t` thick following `path` (y, z) points."""
    from mathutils import Vector
    rings = []
    for i, (y, z) in enumerate(path):
        a = Vector(path[max(i - 1, 0)])
        b = Vector(path[min(i + 1, len(path) - 1)])
        d = (b - a).normalized()
        n = Vector((-d.y, d.x)) * (t * 0.5)
        rings.append([(-w * 0.5, y - n.x, z - n.y), (w * 0.5, y - n.x, z - n.y), (w * 0.5, y + n.x, z + n.y),
                      (-w * 0.5, y + n.x, z + n.y)])
    k.loft(rings, mat)


def hanger() -> object:
    k = rk.Kit("Hanger")
    mid = PLATE_T * 0.5
    r = mid
    path = [(mid, -NECK_DROP - 0.03), (mid, -0.03), (mid, 0.0)]
    for i in range(1, 9):
        a = math.pi * i / 8.0
        path.append((r * math.cos(a), r * math.sin(a)))
    path.append((-mid, -0.012))
    _strap(k, path, 0.05, 0.012, "plate_white")
    # The neck's shoulders where it widens into the plate, as thick as the plate.
    # Its foot sinks into the disc's curve (the disc is 8 mm below its top at the shoulder's ends), so no gap shows.
    k.prism([(-0.055, -NECK_DROP - 0.012), (0.055, -NECK_DROP - 0.012), (0.025, -NECK_DROP + 0.014),
             (-0.025, -NECK_DROP + 0.014)][::-1], "y", 0.0005, PLATE_T - 0.0005, "plate_white")
    ob = k.build()
    rk.finish(ob)
    rk.bake(ob)
    return ob


def face() -> object:
    k = rk.Kit("Face")
    seg = 48
    # The disc, its front edge chamfered so the rim catches the light.
    c = 0.003
    k.lathe([(0.0, PLATE_R - c), (c, PLATE_R), (PLATE_T, PLATE_R)], "plate_white", segments=seg, axis="y")
    ob = k.build()
    rk.finish(ob, angle=math.radians(50.0))
    rk.bake(ob)
    return ob


def swing_leg() -> object:
    k = rk.Kit("SwingLeg")
    h = FRAME_W * 0.5
    k.blk((-h, -h, 0.0), (h, h, 1.0), "stand_black")
    ob = k.build()
    rk.finish(ob, bevel=0.003)
    rk.bake(ob)
    return ob


def swing_foot() -> object:
    k = rk.Kit("SwingFoot")
    h = FRAME_W * 0.5
    # A foot bar front to back with two braces up to the leg, and a base plate under the leg.
    k.blk((-0.025, -0.45, 0.0), (0.025, 0.45, 0.04), "stand_black")
    k.blk((-0.05, -0.05, 0.0), (0.05, 0.05, 0.012), "stand_black")
    for sy in (-1.0, 1.0):
        k.sqbar((0.0, sy * 0.38, 0.03), (0.0, sy * h, 0.36), 0.025, "stand_black")
        for y in (sy * 0.42,):
            k.cyl((0.0, y, 0.04), 0.009, 0.006, "zinc", seg=6)
    ob = k.build()
    rk.finish(ob)
    rk.bake(ob)
    return ob


def swing_bar() -> object:
    k = rk.Kit("SwingBar")
    h = FRAME_W * 0.5
    k.blk((0.0, -h, -h), (1.0, h, h), "stand_black")
    ob = k.build()
    rk.finish(ob, bevel=0.003)
    rk.bake(ob)
    return ob


def swing_pivot() -> object:
    k = rk.Kit("SwingPivot")
    # A clamp plate on the bar's front face standing proud of its top, the pin through it at the pivot (the bar's
    # top edge, where the simulation swings the arm from) with a washer and nut in front of the arm.
    face_y = POST_BEHIND - FRAME_W * 0.5
    k.blk((-0.05, face_y - 0.006, -FRAME_W - 0.004), (0.05, face_y, 0.03), "stand_black")
    for x in (-0.035, 0.035):
        k.cyl((x, face_y - 0.010, -FRAME_W * 0.5), 0.008, 0.004, "zinc", seg=6, axis="y")
    k.cyl((0.0, -0.006, 0.0), 0.006, face_y, "zinc", seg=8, axis="y")
    k.cyl((0.0, PLATE_T - 0.004, 0.0), 0.013, 0.004, "zinc", seg=8, axis="y")
    ob = k.build()
    rk.finish(ob, bevel=0.0015)
    rk.bake(ob)
    return ob


def swing_arm() -> object:
    k = rk.Kit("SwingArm")
    a = 0.035  # RangeViewConfig.arm
    y0, y1 = PLATE_T, PLATE_T + 0.005
    # A flat steel strap from round the pin down to the plate's back, its top end rounded about the pin.
    top = [(0.0175 * math.cos(math.pi * i / 6.0), 0.0175 * math.sin(math.pi * i / 6.0)) for i in range(7)]
    k.prism([(-a * 0.5, -ARM + PLATE_R * 0.5)] + [(a * 0.5, -ARM + PLATE_R * 0.5)] + top[:: 1], "y", y0, y1,
            "stand_black")
    # The clamp plate bolted to the plate's back, and its bolts.
    k.blk((-0.06, y1, -ARM - 0.05), (0.06, y1 + 0.006, -ARM + PLATE_R * 0.55), "stand_black")
    for z in (-ARM + 0.07, -ARM - 0.03):
        for x in (-0.04, 0.04):
            k.cyl((x, y1 + 0.006, z), 0.008, 0.005, "zinc", seg=6, axis="y")
    ob = k.build()
    rk.finish(ob, bevel=0.001)
    rk.bake(ob)
    return ob


def main() -> None:
    rk.reset()
    parts = [base(), post(), bracket(), hanger(), face()]
    frame = [swing_leg(), swing_foot(), swing_bar(), swing_pivot(), swing_arm()]
    print("steel_target stand and plate (budget %d):" % BUDGET)
    n = rk.report(parts)
    print("swinger frame (budget %d):" % FRAME_BUDGET)
    m = rk.report(frame, {"SwingLeg": 2, "SwingFoot": 2})  # as RangeTargetsView draws them
    if n > BUDGET or m > FRAME_BUDGET:
        raise SystemExit("over budget")
    os.makedirs(rk.RANGE, exist_ok=True)
    rk.export(OUT, parts + frame)
    print("wrote", os.path.relpath(OUT, rk.ROOT))
    if "--render" in sys.argv:
        _render(parts, frame, sys.argv[sys.argv.index("--render") + 1])


def _render(parts: list, frame: list, out: str) -> None:
    """The stand and plate as the game lays them (large plate at 1.25 m, a small one beside it), and the swinger."""
    import bpy
    from mathutils import Matrix
    base_, post_, bracket_, hanger_, face_ = parts
    leg, foot, bar, pivot, arm = frame

    def place(ob: object, at: tuple, scale: tuple = (1.0, 1.0, 1.0), name: str = "") -> object:
        c = ob.copy()
        bpy.context.scene.collection.objects.link(c)
        c.matrix_world = Matrix.Translation(at) @ Matrix.Diagonal((*scale, 1.0))
        c.hide_render = False
        return c

    for ob in parts + frame:
        ob.hide_render = True

    def plate(x: float, r: float) -> None:
        top = 1.25 + r + NECK_DROP
        place(base_, (x, POST_BEHIND, 0.0))
        place(post_, (x, POST_BEHIND, 0.0), (1.0, 1.0, top))
        place(bracket_, (x, POST_BEHIND, top))
        place(hanger_, (x, 0.0, top))
        place(face_, (x, 0.0, 1.25), (r / PLATE_R, 1.0, r / PLATE_R))

    plate(0.0, 0.2)
    plate(0.7, 0.1)
    # The swinger at x = 3: legs half = 1 sin(45) + 0.2 + 0.15 apart, its top at 2.25 m.
    sx = 3.0
    half = ARM * math.sin(math.pi / 4.0) + PLATE_R + 0.15
    top = 1.25 + ARM
    for s in (-1.0, 1.0):
        place(leg, (sx + s * half, POST_BEHIND, 0.0), (1.0, 1.0, top))
        place(foot, (sx + s * half, POST_BEHIND, 0.0))
    span = 2 * half + FRAME_W
    place(bar, (sx - span * 0.5, POST_BEHIND, top - FRAME_W * 0.5), (span, 1.0, 1.0))
    place(pivot, (sx, 0.0, top))
    place(arm, (sx, 0.0, top))
    place(face_, (sx, 0.0, top - ARM))
    import range_render as rr
    rr.render_sheet([
        ("Steel plate 0.4 m + small 0.2 m: front quarter", (-1.6, -2.6, 1.6), (0.35, 0.0, 0.9), 40),
        ("Same: rear quarter (post, H-stand)", (1.9, 2.2, 1.5), (0.35, 0.0, 0.8), 40),
        ("Hook on the pin: close-up", (-0.35, -0.3, 1.62), (0.0, 0.03, 1.53), 50),
        ("H-stand and socket: close-up", (-0.7, -0.6, 0.55), (0.0, 0.06, 0.08), 40),
        ("Swinger frame and arm", (sx - 2.4, -3.6, 1.6), (sx, 0.0, 1.1), 32),
        ("Large plate from the firing line (10 m)", (0.3, -10.0, 1.55), (0.3, 0.0, 1.0), 50),
    ], out, "RM1 steel plate targets (range model, not a figure): new Blender model vs William's photos")


if __name__ == "__main__":
    main()
