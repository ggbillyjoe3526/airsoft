"""The alternative magazines, each its own model built from its replica's standard magazine (MAG1, 2026-11-05).

The owner (2026-11-05): "use the standard magazines for a replica but just make them longer/bigger. they should be
separate models." So each part is its replica's own magazine function run again at another length, with what sets it
apart at a glance:

- `magazine_hiCap` (AEG Rifle): the AEG's curved polymer magazine a third longer, its curve and five ribs a side
  carried on down, and under its base plate the hi-cap's winding wheel (art/reference-list.md: "the hi-cap's wheel"),
  a knurled disc standing proud of the plate with a thumb bar across its face.
- `magazine_lowCap` (AEG Rifle): the same magazine cut short, about a 20-round magazine's length.
- `magazine_extended` (GBB Pistol): the pistol's magazine LONGER along the grip's rake, its base pad in the frame's
  colour so it reads as an add-on.

Each has its `_Figure` copy (the figures' few-face block) and its origin on the replica's MagWell, as
docs/CC0_ASSETS.md › Replica models asks; the materials are the replica magazine's own (Detail, Rubber, BB, Metal,
Accent, Furniture), so ReplicaPaint paints them as it paints the replica's.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3), after the replicas' own scripts (and
tools/blender/parts/fit_parts.py):

    python -I tools/blender/parts/magazines.py <repo root>

It replaces the magazine parts in assets/models/replicaParts/aeg.glb and pistol.glb and leaves every other part as it
is. Running it again builds the same magazines.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "replicas"))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import aeg  # noqa: E402
import gbb  # noqa: E402
import hardsurface as hs  # noqa: E402

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
PARTS = os.path.join(ROOT, "assets/models/replicaParts/%s.glb")

# The AEG magazines' bases in the AEG script's first-pass heights (its standard one's is aeg.MAG_BOTTOM, -0.1585: 9.9 cm
# below the well's foot). The hi-cap's puts it 13.0 cm below with its wheel (1.32 of the standard's), the low-cap's
# 6.9 cm (0.70).
HICAP_BOTTOM = -0.1830
LOWCAP_BOTTOM = -0.1310
# How much finer the parts are than the replica's own magazine (rings down the curve, corners, bevel): a part has its
# own budget (10,000 triangles, docs/CC0_ASSETS.md › Size limits) where the replica's magazine shares the rifle's.
HICAP_FINE = 2
LOWCAP_FINE = 3
EXTENDED_FINE = 7
# The AEG base plate's frame (aeg.mag_plate: its top at z 0, +y toward the muzzle): its foot, its outline's half
# width and depth, the flared rim round its top edge (how far out, its band), the pull tab on its front (half width,
# reach, height) and the grip ridges across its foot (their places along it, half width, width, height).
PLATE_FOOT = -0.0075
PLATE_HW = aeg.MAG_HW + 0.0009
PLATE_HD = aeg.MAG_HD + 0.0004
RIM_OUT = 0.0007
RIM_Z = (-0.0024, -0.0003)
TAB = (0.0095, 0.0032, 0.0040)
RIDGE_Y = (0.0085, 0.0150, 0.0215)
RIDGE = (0.0115, 0.0018, 0.0007)
# The magazine catch's window on the left side, near the top (inside the well while it is fitted, seen on a reload):
# its height in the first pass's heights, its half length and half height.
CATCH_Z = -0.046
CATCH = (0.0042, 0.0034)
# The BB feed nozzle standing up at the front of the feed lips, round the top BB: its radii and its top over the lips.
NOZZLE_R = (0.0042, 0.0032)
NOZZLE_TOP = 0.0058
# The hi-cap's winding wheel, in the base plate's frame: its centre along the plate (the back half, where the rear of
# a real hi-cap's floor plate carries it), its radius, how far its rim stands below the plate, its knurls, its thumb
# bar, and the raised collar round it on the plate.
WHEEL_Y = -0.0115
WHEEL_R = 0.0118
WHEEL_DROP = 0.0034
WHEEL_SEGMENTS = 36
WHEEL_KNURLS = 20
KNURL_W = 0.0013
KNURL_OUT = 0.0006
BAR_HW = (0.0098, 0.0016)
BAR_DROP = 0.0012
COLLAR = (0.0006, 0.0018, 0.0014)
# The pistol's extended magazine: this much longer along the rake than its standard one (4 cm: a long "+10" magazine,
# twice the old part's 2.2 cm so it reads at a glance).
EXTENDED = 0.040
# Its witness holes down its back (as the owner's pistol magazine photos have): the first's distance down the
# magazine from its top, their spacing, radius and depth, and the last's distance from its foot; its exhaust valve on the top behind the follower (its
# place back from the top's centre, radii, height) and its feed lips (inset, height).
HOLES = (0.030, 0.0065, 0.0016, 0.0012)
HOLES_END = 0.010
HOLE_SEGMENTS = 12
VALVE_BACK = 0.0085
VALVE_R = (0.0030, 0.0022)
VALVE_H = 0.0032
LIP = (0.0010, 0.0024)
# The figures' copy of the extended magazine: its half depth, and how far it reaches under the grip's foot.
EXTENDED_FIGURE_HD = 0.021
EXTENDED_FIGURE_REACH = 0.008


def aeg_top_frame(z: float) -> Matrix:
    """The AEG magazine's own frame at height `z` (first-pass heights): on its spine, tilted as the body is there."""
    cy, tilt = aeg.mag_spine(z)
    return Matrix.Translation((0.0, cy, aeg.mz(z))) @ Matrix.Rotation(tilt, 4, "X")


def aeg_details(name: str, bottom: float, wheel: bool) -> object:
    """What the AEG magazine parts add to the replica's magazine: the base plate's flared rim, pull tab and grip
    ridges (in front of the wheel on the hi-cap), the catch window and the BB feed nozzle."""
    b = hs.Builder(name, ["Rubber", "Detail"])
    plate = []
    plate += b.prism(hs.rounded_rect(PLATE_HW + RIM_OUT, PLATE_HD + RIM_OUT, 0.0036, 4), "z", RIM_Z[0], RIM_Z[1],
                     "Rubber")
    plate += b.box((-TAB[0], PLATE_HD - 0.001, PLATE_FOOT), (TAB[0], PLATE_HD + TAB[1], PLATE_FOOT + TAB[2]), "Rubber")
    for y in RIDGE_Y:
        plate += b.box((-RIDGE[0], y - RIDGE[1] * 0.5, PLATE_FOOT - RIDGE[2]), (RIDGE[0], y + RIDGE[1] * 0.5,
                       PLATE_FOOT + 0.0002), "Rubber")
    b.transform(plate, aeg.mag_plate(bottom))
    catch = b.box((-aeg.MAG_HW - 0.0002, -CATCH[0], -CATCH[1]), (-aeg.MAG_HW + 0.0006, CATCH[0], CATCH[1]), "Rubber")
    b.transform(catch, aeg_top_frame(CATCH_Z))
    lips = aeg.mz(-0.012) + 0.006
    b.tube([(lips - 0.0004, NOZZLE_R[0]), (lips + NOZZLE_TOP - 0.0005, NOZZLE_R[0]), (lips + NOZZLE_TOP, NOZZLE_R[0]
           - 0.0005)], [(lips - 0.0004, NOZZLE_R[1]), (lips + NOZZLE_TOP, NOZZLE_R[1])], "Rubber", 24,
           centre=(0.0, aeg.MAG_TOP[1] + 0.024, 0.0), axis="z")
    return hs.finish(b.build(), 0.0003, 2)


def hicap() -> object:
    """The hi-cap: the AEG's magazine to HICAP_BOTTOM, finer, with its details and its winding wheel."""
    return hs.join("magazine_hiCap", [aeg.magazine("magazine_hiCap", HICAP_BOTTOM, HICAP_FINE),
                                      aeg_details("HiCapDetails", HICAP_BOTTOM, True), hicap_wheel()])


def lowcap() -> object:
    """The low-cap: the AEG's magazine cut short to LOWCAP_BOTTOM, finer, with its details."""
    return hs.join("magazine_lowCap", [aeg.magazine("magazine_lowCap", LOWCAP_BOTTOM, LOWCAP_FINE),
                                       aeg_details("LowCapDetails", LOWCAP_BOTTOM, False)])


def hicap_wheel() -> object:
    """The winding wheel under the hi-cap's base plate: a raised collar on the plate, the disc in it with a chamfered
    foot standing WHEEL_DROP below the plate, knurls round its rim, a thumb bar across its face and a screw head in
    the middle of the bar."""
    b = hs.Builder("Wheel", ["Metal", "Rubber"])
    top = PLATE_FOOT + 0.0004
    foot = PLATE_FOOT - WHEEL_DROP
    b.tube([(PLATE_FOOT + 0.0003, WHEEL_R + COLLAR[1]), (PLATE_FOOT - COLLAR[2], WHEEL_R + COLLAR[1])],
           [(PLATE_FOOT + 0.0003, WHEEL_R + COLLAR[0]), (PLATE_FOOT - COLLAR[2], WHEEL_R + COLLAR[0])], "Rubber",
           WHEEL_SEGMENTS, centre=(0.0, WHEEL_Y, 0.0), axis="z")
    b.lathe([(top, WHEEL_R), (foot + 0.0006, WHEEL_R), (foot, WHEEL_R - 0.0008), (foot, 0.0)], "Metal", WHEEL_SEGMENTS,
            centre=(0.0, WHEEL_Y, 0.0), axis="z")
    for i in range(WHEEL_KNURLS):
        a = 2.0 * math.pi * (i + 0.5) / WHEEL_KNURLS
        knurl = b.box((WHEEL_R - 0.0004, -KNURL_W * 0.5, foot + 0.0007), (WHEEL_R + KNURL_OUT, KNURL_W * 0.5,
                      PLATE_FOOT - COLLAR[2] - 0.0002), "Metal")
        b.transform(knurl, Matrix.Translation((0.0, WHEEL_Y, 0.0)) @ Matrix.Rotation(a, 4, "Z"))
    b.box((-BAR_HW[0], WHEEL_Y - BAR_HW[1], foot - BAR_DROP), (BAR_HW[0], WHEEL_Y + BAR_HW[1], foot + 0.0002), "Metal")
    b.lathe([(foot - BAR_DROP + 0.0001, 0.0026), (foot - BAR_DROP - 0.0004, 0.0022), (foot - BAR_DROP - 0.0004, 0.0)],
            "Rubber", 16, centre=(0.0, WHEEL_Y, 0.0), axis="z")
    b.box((-0.0018, WHEEL_Y - 0.0003, foot - BAR_DROP - 0.0006), (0.0018, WHEEL_Y + 0.0003, foot - BAR_DROP - 0.0003),
          "Metal")
    ob = b.build()
    ob.data.transform(aeg.mag_plate(HICAP_BOTTOM))
    return hs.finish(ob, 0.0002, 1)


def extended() -> object:
    """The extended magazine: the pistol's magazine EXTENDED longer, finer, its base pad in the frame's colour, with
    witness holes down its back, the exhaust valve on its top and its feed lips."""
    mag = gbb.magazine("magazine_extended", EXTENDED, "Furniture", EXTENDED_FINE)
    rake = math.radians(gbb.GRIP_RAKE)
    down = Vector((0.0, -math.sin(rake), -math.cos(rake)))
    top = Vector(gbb.MAG_TOP)
    length = (top.z - gbb.Z(gbb.GRIP_FOOT + 1.0)) / math.cos(rake) + EXTENDED
    b = hs.Builder("ExtendedDetails", ["Rubber", "Metal"])
    # The holes: bored square into the back face (raked with the magazine), each with a dark floor.
    back = Vector((0.0, -math.cos(rake), math.sin(rake)))
    face = back.to_track_quat("Z", "Y").to_matrix().to_4x4()
    cutters = []
    d = HOLES[0]
    while d <= length - HOLES_END:
        at = Matrix.Translation(top + down * d - Vector((0.0, gbb.MAG_HD, 0.0))) @ face
        c = hs.Builder("c_hole", ["Rubber"])
        c.lathe([(-HOLES[3], HOLES[2]), (0.002, HOLES[2])], "Rubber", HOLE_SEGMENTS, axis="z")
        c.transform(c.bm.faces[:], at)
        cutters.append(c.build())
        floor = b.lathe([(-HOLES[3] + 0.0002, HOLES[2] + 0.0002), (-HOLES[3] + 0.0002, 0.0)], "Rubber", HOLE_SEGMENTS,
                      axis="z")
        b.transform(floor, at)
        d += HOLES[1]
    hs.cut(mag, cutters)
    b.tube([(top.z - 0.0004, VALVE_R[0]), (top.z + VALVE_H, VALVE_R[0])],
           [(top.z - 0.0004, VALVE_R[1]), (top.z + VALVE_H, VALVE_R[1])], "Metal", 24,
           centre=(0.0, top.y - VALVE_BACK, 0.0), axis="z")
    for sx in (-1, 1):
        x0 = sx * (gbb.MAG_HW - LIP[0])
        b.box((min(x0, sx * gbb.MAG_HW), top.y - 0.004, top.z - 0.0004), (max(x0, sx * gbb.MAG_HW), top.y + 0.010,
              top.z + LIP[1]), "Metal")
    return hs.join("magazine_extended", [mag, hs.finish(b.build(), 0.0002, 1)])


def aeg_figure(name: str, bottom: float) -> object:
    """An AEG magazine's figure copy: the replica's figure magazine (three rounded rings) down to `bottom`."""
    b = hs.Builder(name, ["Detail"])
    rings = []
    for z in (-0.020, -0.075, bottom):
        cy = aeg.mag_spine(z)[0]
        rings.append([(x, cy + y, aeg.mz(z)) for x, y in hs.rounded_rect(aeg.MAG_HW, aeg.MAG_HD, 0.006, 1)])
    b.loft(rings, "Detail")
    ob = b.build()
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


def extended_figure() -> object:
    """The extended magazine's figure copy: the block that shows under the grip's foot, EXTENDED longer."""
    b = hs.Builder("magazine_extended_Figure", ["Detail"])
    rake = math.radians(gbb.GRIP_RAKE)
    down = Vector((0.0, -math.sin(rake), -math.cos(rake)))
    lo = Vector((0.0, gbb.Y(528.0), gbb.Z(420.0)))
    reach = down * (EXTENDED + EXTENDED_FIGURE_REACH)
    sec = hs.rounded_rect(gbb.MAG_HW + 0.001, EXTENDED_FIGURE_HD, 0.004, 1)
    b.loft([[(x, lo.y + y, lo.z) for x, y in sec], [(x, lo.y + reach.y + y, lo.z + reach.z) for x, y in sec]],
           "Detail")
    return b.build()


def replace(part_file: str, materials: dict, well: tuple, build: list) -> None:
    """Rebuilds the magazine parts of replicaParts/`part_file`.glb: the old ones out, each of `build` (functions
    making a part and its figure copy) in, origins on `well`; every other part as it was."""
    hs.reset(aeg.FPS)
    path = PARTS % part_file
    bpy.ops.import_scene.gltf(filepath=path)
    for ob in list(bpy.data.objects):
        if ob.name.startswith("magazine_"):
            bpy.data.objects.remove(ob, do_unlink=True)
    for name, (colour, rough, metal) in materials.items():
        hs.material(name, colour, rough, metal)
    at = Vector(well)
    for make in build:
        for ob in make():
            # The holes' boolean can leave a few doubled faces where a bore meets the body's bevel: dropped here.
            ob.data.validate(clean_customdata=False)
            ob.data.transform(Matrix.Translation(-at))
            ob.location = at
            print("  %-26s %6d triangles" % (ob.name, hs.tris(ob)))
    hs.export(path, False)
    print("wrote", path)


def main() -> None:
    replace("aeg", aeg.MATERIALS, aeg.EMPTIES["MagWell"], [
        lambda: (hicap(), aeg_figure("magazine_hiCap_Figure", HICAP_BOTTOM)),
        lambda: (lowcap(), aeg_figure("magazine_lowCap_Figure", LOWCAP_BOTTOM)),
    ])
    replace("pistol", {**gbb.MATERIALS, "Rubber": aeg.MATERIALS["Rubber"]}, gbb.EMPTIES["MagWell"], [
        lambda: (extended(), extended_figure()),
    ])


if __name__ == "__main__":
    main()
