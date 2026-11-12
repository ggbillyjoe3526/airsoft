"""The alternative magazines, each its own model built from its replica's standard magazine (MAG1, 2026-11-05).

The owner (2026-11-05): "use the standard magazines for a replica but just make them longer/bigger. they should be
separate models." So each part is its replica's own magazine function run again at another length, with what sets it
apart at a glance:

- `magazine_hiCap` (AEG Rifle): the AEG's curved polymer magazine a third longer, its curve and five ribs a side
  carried on down, and under its base plate the hi-cap's winding wheel (art/reference-list.md: "the hi-cap's wheel"),
  a knurled disc in a collar standing proud of the plate with a thumb bar across its face.
- `magazine_lowCap` (AEG Rifle): the same magazine cut short, about a 20-round magazine's length.
- `magazine_extended` (GBB Pistol): the pistol's magazine LONGER along the grip's rake, its base pad in the frame's
  colour so it reads as an add-on.

The outlines are the standard magazines'; the detail is cut into them: on the AEG parts the catch window in the left
side and grip grooves across the base plate's foot, on the extended magazine two columns of witness holes down its
back (the owner's pistol magazine photos) and the catch notch in its side, plus its exhaust valve and feed lips.

Each has its `_Figure` copy (the figures' few-face block) and its origin on the replica's MagWell, as
docs/CC0_ASSETS.md › Replica models asks; the materials are the replica magazine's own (Detail, Rubber, BB, Metal,
Accent, Furniture), so ReplicaPaint paints them as it paints the replica's.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3), after the replicas' own scripts (and
tools/blender/parts/fit_parts.py):

    python -I tools/blender/parts/magazines.py <repo root>

It replaces the magazine parts in assets/models/replicaParts/aeg.glb and pistol.glb and leaves every other part as it
is. Running it again builds the same magazines.

They are lightly used like their replica's own magazine (RW2, owner 2026-11-10: "make sure that magazine models also
have the cosmetic changes"): tools/blender/replicas/wear.py bakes one mask for a file's magazines (WEAR_SIZE, their
scratches times MAGAZINE_SCRATCH as the replicas' magazines have them) on copies of their painted materials, so the
file's other parts stay as they are; Godot's import writes it beside the file as `<replica>_wear.png`.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "replicas"))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import aeg  # noqa: E402
import gbb  # noqa: E402
import hardsurface as hs  # noqa: E402
import surface  # noqa: E402
import wear  # noqa: E402

# What each magazine's materials are made of (surface.py, MQ2): the hi-cap a stamped steel shell, the low-cap moulded
# polymer, the pistol's extended one a steel tube on a polymer base as the pistol's own; pads and dark insides rubber.
SURFACES = {
    "magazine_hiCap": {"Detail": "steel", "Metal": "steel", "Rubber": "rubber"},
    "magazine_lowCap": {"Detail": "polymer", "Metal": "steel", "Rubber": "rubber"},
    "magazine_extended": {"Detail": "polymer", "Metal": "steel", "Accent": "polymer", "Furniture": "polymer",
                          "Rubber": "rubber"},
}

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
PARTS = os.path.join(ROOT, "assets/models/replicaParts/%s.glb")

# The AEG magazines' bases in the AEG script's first-pass heights (its standard one's is aeg.MAG_BOTTOM, -0.1585: 9.9 cm
# below the well's foot). The hi-cap's puts it 13.0 cm below with its wheel (1.32 of the standard's), the low-cap's
# 6.9 cm (0.70).
HICAP_BOTTOM = -0.1830
LOWCAP_BOTTOM = -0.1310
# How much finer the parts are than the replica's own magazine (rings down the curve, corners, bevel): a part has its
# own budget (10,000 triangles, docs/CC0_ASSETS.md › Size limits) where the replica's magazine shares the rifle's. The
# rest of each budget goes on the details below.
PART_TRIS = 10000
HICAP_FINE = 2
LOWCAP_FINE = 3
EXTENDED_FINE = 9
# What tells the two apart at a glance (MQ2). The hi-cap is a pressed steel shell: four narrow pressed ribs a side
# (place along the side, half width, m), the lapped seam down its back (-1: back; half width, height, its flat crown's
# share of the width) with a row of spot welds, folded steel feed lips. The low-cap is moulded polymer: the rifle's
# five wide ribs, and the mould's parting line, a fine ridge down its front and back (through every second ring).
# Their BBs are true balls, as round as each budget holds (`round_bb` sides, half as many bands): the magazine's top
# is in front of the camera on every reload.
HICAP_SHAPE = {"ribs": ((-0.0213, 0.0019), (-0.0071, 0.0019), (0.0071, 0.0019), (0.0213, 0.0019)), "lips": True,
               "seams": ((-1, 0.0024, 0.0005, 0.75),), "welds": 7, "round_bb": 32}
LOWCAP_SHAPE = {"seams": ((1, 0.0005, 0.0003, 0.0), (-1, 0.0005, 0.0003, 0.0)), "seam_step": 2, "round_bb": 34}
# The magazines' wear (RW2): one mask a file, at about the replicas' own texel size (a 2K mask over a whole replica),
# each file's own seed, and the scratches times the replicas' magazines' factor (aeg.py, gbb.py: "Magazine" 2.5).
WEAR_SIZE = 1024
WEAR_SEED = {"aeg": 4, "pistol": 5}
MAGAZINE_SCRATCH = 2.5
# The AEG base plate's frame (aeg.mag_plate: its top at z 0, +y toward the muzzle): its foot, and the grip grooves cut
# across its foot (their places along it, half width, width, depth), inside the standard plate's outline.
PLATE_FOOT = -0.0075
GROOVE_Y = (0.0030, 0.0068, 0.0106, 0.0144, 0.0182, 0.0220)
GROOVE = (0.0120, 0.0012, 0.0008)
# The magazine catch's window cut into the left side near the top (inside the well while it is fitted, seen on a
# reload), with a dark floor: its height in the first pass's heights, its half length, half height and depth.
CATCH_Z = -0.046
CATCH = (0.0042, 0.0034, 0.0012)
# The hi-cap's winding wheel, in the base plate's frame: its centre along the plate (the back half, where the rear of
# a real hi-cap's floor plate carries it), its radius, how far its rim stands below the plate, its knurls, its thumb
# bar, and the raised collar round it on the plate.
WHEEL_Y = -0.0115
WHEEL_R = 0.0118
WHEEL_DROP = 0.0034
WHEEL_SEGMENTS = 36
WHEEL_KNURLS = 24
KNURL_W = 0.0011
KNURL_OUT = 0.0006
BAR_HW = (0.0098, 0.0016)
BAR_DROP = 0.0012
COLLAR = (0.0006, 0.0018, 0.0014)
# Triangles smaller than this (m²) are dropped when a part is cleaned (a boolean's or a bevel's slivers).
SLIVER = 1e-10
# Neighbouring faces this close to parallel (normals' dot) lie in one plane (within about 0.25°).
PLANE_DOT = 0.99999
# The pistol's extended magazine: this much longer along the rake than its standard one (3.5 cm: a long "+10" magazine,
# half as long again as the old part's 2.2 cm so it reads at a glance, and the most the Customise frame holds below
# the grip in the side views: test_ur4_qa.gd).
EXTENDED = 0.035
# Its witness holes down its back in two staggered columns (as the owner's pistol magazine photos have): the first's
# distance down the magazine from its top, the spacing down a column, their radius and depth, the columns' offset
# from the middle, and the last's distance from the foot. Its catch notch cut into the left side near the top (its
# distance down, half length and half height, depth); its exhaust valve on the top behind the follower (its place
# back from the top's centre, radii, height) and its feed lips (inset, height).
HOLES = (0.024, 0.0070, 0.0013, 0.0012)
HOLE_X = 0.0042
HOLES_END = 0.009
HOLE_SEGMENTS = 24
NOTCH = (0.010, 0.0040, 0.0030, 0.0010)
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


def bored(ob: object, cutters: list, floors: object) -> object:
    """`ob` with `cutters` cut out of it, joined with `floors` (the dark faces at the bottoms of the cuts), cleaned:
    the boolean's slivers dropped and its normals weighted again, so the faces round each cut shade flat."""
    cut(ob, cutters)
    ob = hs.join(ob.name, [ob, floors])
    clean(ob)
    return hs.finish(ob, 0.0, 1)


def cut(ob: object, cutters: list) -> None:
    """`ob` less `cutters` (exact boolean), the cutters deleted. Unlike hardsurface.cut it doesn't resolve `ob`'s own
    overlaps (a magazine's ribs, plate and BBs overlap its body): only where a cutter meets it changes."""
    tool = hs.join("cutters", cutters)
    before = shells(ob)
    mod = ob.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.use_self = False
    mod.use_hole_tolerant = True
    mod.object = tool
    hs.apply_modifiers(ob)
    me = tool.data
    bpy.data.objects.remove(tool, do_unlink=True)
    bpy.data.meshes.remove(me)
    # A cut takes a bite, never a whole shell: the boolean has dropped ones a cutter never touched.
    if shells(ob) < before:
        raise SystemExit("%s: the cut lost a shell (%d of %d left)" % (ob.name, shells(ob), before))


def shells(ob: object) -> int:
    """How many separate shells (pieces joined by no edge) `ob`'s mesh is."""
    me = ob.data
    root = list(range(len(me.vertices)))

    def find(i: int) -> int:
        while root[i] != i:
            root[i] = root[root[i]]
            i = root[i]
        return i

    for e in me.edges:
        a, b = find(e.vertices[0]), find(e.vertices[1])
        if a != b:
            root[a] = b
    return len({find(i) for i in range(len(me.vertices))})


def clean(ob: object) -> None:
    """Drops doubled faces and zero-area slivers (smaller than SLIVER) from a mesh, triangulated as it will be
    exported."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.dissolve_degenerate(bm, dist=2e-6, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    thin = [f for f in bm.faces if f.calc_area() < SLIVER]
    bmesh.ops.delete(bm, geom=thin, context="FACES_ONLY")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.validate(clean_customdata=False)


def flat_planes(ob: object) -> None:
    """Gives each face lying in one plane with two or more of its neighbours (the flat side a hole or window is cut
    into, triangulated round it; on a curve only a quad's own two triangles are in one plane) its own normal at every
    corner, so its long thin triangles don't streak; curved faces keep their weighted normals."""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    flat = [sum(1 for e in f.edges for g in e.link_faces if g is not f and f.normal.dot(g.normal) > PLANE_DOT) >= 2
            for f in bm.faces]
    bm.free()
    normals = [n.vector.copy() for n in me.corner_normals]
    for p, is_flat in zip(me.polygons, flat):
        if is_flat:
            for i in p.loop_indices:
                normals[i] = p.normal.copy()
    me.normals_split_custom_set(normals)


def aeg_part(name: str, bottom: float, fine: int, seams: tuple = (), welds: int = 0, seam_step: int = 1,
             ribs: tuple = aeg.MAG_RIBS, lips: bool = False, round_bb: int = 16) -> object:
    """An AEG magazine part: the replica's magazine's body and plate to `bottom`, `fine` times finer, the catch window
    cut into its left side and grip grooves cut across its base plate's foot (inside the standard plate's outline).
    Joined after the cuts, so the cut takes nothing else: its `ribs` (aeg.mag_ribs), its feed tower with folded steel
    `lips` or none and BBs `round_bb` sides round (aeg.mag_top), and its `seams` with their `welds` (aeg.mag_seams)."""
    ribs = aeg.mag_ribs(name + "Ribs", bottom, fine, ribs)
    top = aeg.mag_top(name + "Top", fine, lips, round_bb)
    mag = aeg.magazine(name, bottom, fine)
    cutters = []
    floors = hs.Builder(name + "Floors", ["Rubber"])
    c = hs.Builder("c_catch", ["Rubber"])
    faces = c.box((-aeg.MAG_HW - 0.003, -CATCH[0], -CATCH[1]), (-aeg.MAG_HW + CATCH[2], CATCH[0], CATCH[1]), "Rubber")
    c.transform(faces, aeg_top_frame(CATCH_Z))
    cutters.append(c.build())
    floor = floors.box((-aeg.MAG_HW + CATCH[2] - 0.0003, -CATCH[0] - 0.0002, -CATCH[1] - 0.0002),
                       (-aeg.MAG_HW + CATCH[2] - 0.0001, CATCH[0] + 0.0002, CATCH[1] + 0.0002), "Rubber")
    floors.transform(floor, aeg_top_frame(CATCH_Z))
    plate = aeg.mag_plate(bottom)
    for y in GROOVE_Y:
        if bottom == HICAP_BOTTOM and y - GROOVE[1] < WHEEL_Y + WHEEL_R + COLLAR[1]:
            continue
        c = hs.Builder("c_groove", ["Rubber"])
        faces = c.box((-GROOVE[0], y - GROOVE[1] * 0.5, PLATE_FOOT - 0.003), (GROOVE[0], y + GROOVE[1] * 0.5,
                      PLATE_FOOT + GROOVE[2]), "Rubber")
        c.transform(faces, plate)
        cutters.append(c.build())
    mag = hs.join(name, [bored(mag, cutters, floors.build()), top, ribs])
    if not seams:
        return mag
    return hs.join(name, [mag, aeg.mag_seams(name + "Seams", bottom, fine, seams, welds, seam_step)])


def hicap() -> object:
    """The hi-cap: the AEG's magazine to HICAP_BOTTOM, finer, with its details and its winding wheel."""
    return hs.join("magazine_hiCap", [aeg_part("magazine_hiCap", HICAP_BOTTOM, HICAP_FINE, **HICAP_SHAPE),
                                      hicap_wheel()])


def lowcap() -> object:
    """The low-cap: the AEG's magazine cut short to LOWCAP_BOTTOM, finer, with its details."""
    return aeg_part("magazine_lowCap", LOWCAP_BOTTOM, LOWCAP_FINE, **LOWCAP_SHAPE)


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
    return hs.finish(ob, 0.00015, 1)


def extended() -> object:
    """The extended magazine: the pistol's magazine EXTENDED longer, finer, its base pad in the frame's colour, with
    two columns of witness holes down its back, the catch notch in its side, the exhaust valve on its top and its feed
    lips."""
    mag = gbb.magazine("magazine_extended", EXTENDED, "Furniture", EXTENDED_FINE)
    rake = math.radians(gbb.GRIP_RAKE)
    down = Vector((0.0, -math.sin(rake), -math.cos(rake)))
    top = Vector(gbb.MAG_TOP)
    length = (top.z - gbb.Z(gbb.GRIP_FOOT + 1.0)) / math.cos(rake) + EXTENDED
    b = hs.Builder("ExtendedDetails", ["Rubber", "Metal"])
    floors = hs.Builder("ExtendedFloors", ["Rubber"])
    # The holes: bored square into the back face (raked with the magazine), each with a dark floor.
    back = Vector((0.0, -math.cos(rake), math.sin(rake)))
    face = back.to_track_quat("Z", "Y").to_matrix().to_4x4()
    cutters = []
    for col, x in enumerate((-HOLE_X, HOLE_X)):
        d = HOLES[0] + col * HOLES[1] * 0.5
        while d <= length - HOLES_END:
            at = Matrix.Translation(top + down * d + Vector((x, -gbb.MAG_HD, 0.0))) @ face
            c = hs.Builder("c_hole", ["Rubber"])
            c.lathe([(-HOLES[3], HOLES[2]), (0.002, HOLES[2])], "Rubber", HOLE_SEGMENTS, axis="z")
            c.transform(c.bm.faces[:], at)
            cutters.append(c.build())
            floor = floors.lathe([(-HOLES[3] + 0.0002, HOLES[2] + 0.0002), (-HOLES[3] + 0.0002, 0.0)], "Rubber",
                                 HOLE_SEGMENTS, axis="z")
            floors.transform(floor, at)
            d += HOLES[1]
    # The catch notch in the left side, near the front of the top.
    c = hs.Builder("c_notch", ["Rubber"])
    at = top + down * NOTCH[0] + Vector((0.0, gbb.MAG_HD * 0.45, 0.0))
    c.box((-gbb.MAG_HW - 0.003, at.y - NOTCH[1], at.z - NOTCH[2]), (-gbb.MAG_HW + NOTCH[3], at.y + NOTCH[1],
          at.z + NOTCH[2]), "Rubber")
    cutters.append(c.build())
    floors.box((-gbb.MAG_HW + NOTCH[3] - 0.0003, at.y - NOTCH[1] - 0.0002, at.z - NOTCH[2] - 0.0002),
               (-gbb.MAG_HW + NOTCH[3] - 0.0001, at.y + NOTCH[1] + 0.0002, at.z + NOTCH[2] + 0.0002), "Rubber")
    mag = bored(mag, cutters, floors.build())
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
    plain_materials()
    for name, (colour, rough, metal) in materials.items():
        hs.material(name, colour, rough, metal)
    at = Vector(well)
    for make in build:
        for ob in make():
            if not ob.name.endswith("_Figure"):
                # Cleaned as exported, then its sharp edges and weighted normals set again over the cleaned faces.
                clean(ob)
                hs.finish(ob, 0.0, 1)
                flat_planes(ob)
            ob.data.transform(Matrix.Translation(-at))
            ob.location = at
            count = hs.tris(ob)
            print("  %-26s %6d triangles" % (ob.name, count))
            if count > PART_TRIS and not ob.name.endswith("_Figure"):
                raise SystemExit("%s: %d triangles is over the part budget of %d" % (ob.name, count, PART_TRIS))
    worn = [ob.name for ob in bpy.data.objects if ob.type == "MESH" and ob.name.startswith("magazine_")
            and not ob.name.endswith("_Figure")]
    for name in worn:
        part = bpy.data.objects[name]
        surface.name([part] + list(part.children_recursive), SURFACES.get(name, {}))
    wear.apply(seed=WEAR_SEED[part_file], heavier={name: MAGAZINE_SCRATCH for name in worn}, size=WEAR_SIZE,
               only=("magazine_",))
    hs.export(path, False)
    wear.unsuffix(path)
    print("wrote", path)


def plain_materials() -> None:
    """The last build's worn magazine materials (wear.resuffix names them apart from the plain ones they share a name
    with in the file) and its mask let go once the magazines are out."""
    wear.resuffix()
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)
    for m in list(bpy.data.materials):
        if m.name.endswith(wear.SUFFIX):
            bpy.data.materials.remove(m)
    for image in list(bpy.data.images):
        if image.users == 0:
            bpy.data.images.remove(image)


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
