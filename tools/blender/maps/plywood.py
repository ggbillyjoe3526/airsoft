"""The plywood wall kit (DM1, 2026-11-09): assets/models/props/plywood*.glb, Depot's and Woodland's plywood walls.

One module of an airsoft site's plywood wall after the owner's photos (art/references/maps/william-2026-11-09/
plywood_wall/): half a 1.22 m birch sheet each side between pine battens screwed over the joints (the board-and-batten
wall in his third photo, a batten every 0.61 m), nails up the stud behind the sheet's middle, oval football patches, a
pine rail where the 2.44 m sheet meets the filler strip above it, a darker skirting board at the foot and a timber cap
along the top. PropLayout's RUN lays the modules end to end along each wall's box (PropDressConfig.run_lengths), a
whole number of them each stretched under 10 % to the wall's length, height and thickness, so two neighbours' half
battens meet as one.

Four heights (PropDressConfig.heights picks the nearest for a block): the full 2.6 m, a 1.7 m and a 1 m one without
the rail, and a 0.5 m one for sills and lintels, so a cap is never squashed far. A fifth, the 0.2 m header (WG3), is
a lintel or sill too low for those, with no skirting: Woodland names it on its thin window blocks.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/maps/plywood.py <repo root> [pictures folder]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_kit as kit  # noqa: E402
import bmesh  # noqa: E402

ARGS = [a for a in sys.argv[1:] if os.path.isdir(a)]
ROOT = ARGS[0] if ARGS else os.getcwd()
PICTURES = ARGS[1] if len(ARGS) > 1 else ""

BUDGET = 245  # one 0.61 m module (a sheet's half: about 400 a metre of wall)
WIDE = 0.61  # half a 1.22 m sheet, the batten pitch: a wall is a whole number of them, stretched under 10 %
THICK = 0.30  # the wall's box
HEIGHTS = {"plywood": 2.6, "plywood_mid": 1.7, "plywood_low": 1.0, "plywood_short": 0.5}  # PropDressConfig.heights
HEADER = {"plywood_header": 0.2}  # named by a block (Woodland's thin lintels), not picked by height
HEADER_UNDER = 0.3  # a module this low is a header: no skirting at its foot
SHEET = 2.44  # the full sheet's height; the filler strip runs above it
FACE = 0.012  # how far a batten stands off the sheet
SKIRT = 0.12  # the skirting board's height
SKIRT_PROUD = 0.008
CAP = 0.045  # the cap's height on top
RAIL = 0.08  # the rail over the sheet's top edge
BATTEN = 0.064  # a batten's width (the module's end ones are half of it, meeting their neighbour's)
CHAMFER = 0.006  # a batten's eased edges
SCREW = 0.012  # a screw head's size
SCREW_STEP = 0.45  # screws up each batten
NAIL = 0.008  # a nail head in the sheet
NAIL_STEP = 0.24 # nails up the stud behind the sheet's middle
PATCHES = ((-0.14, 0.62), (0.12, 1.43), (-0.1, 2.05), (0.15, 0.3))  # (x, z), mirrored

# Wood tones pale and greyed (saturation under 0.3 in linear light), so none reads as Beta's orange
# (tests/unit/test_props.gd).
SHEET_A = 0xd6cbae  # birch plywood (each module a shade apart, PropLayout's RUN)
FILLER = 0xccc0a2
BATTEN_C = 0xbfb39a  # planed pine
SKIRT_C = 0xa09684  # the darker skirting
CAP_C = 0xb5aa92
SCREW_C = 0x5a5450
PATCH_C = 0xc8bc9e  # the oval football patches, a shade under the sheet
NAIL_C = 0x6e665c


def batten(name: str, x0: float, x1: float, z0: float, z1: float, side: int) -> object:
    """A batten on face `side` (-1: -Y, 1: +Y) from x0 to x1, its outer edges eased."""
    y_in = side * (THICK / 2 - FACE)
    y_out = side * (THICK / 2 - 0.001)
    c = CHAMFER
    # Outline in (x, y) across the batten, then pushed up z.
    pts = [(x0, y_in), (x1, y_in), (x1, y_out - side * c), (x1 - c, y_out), (x0 + c, y_out), (x0, y_out - side * c)]
    bm = bmesh.new()
    lo = [bm.verts.new((x, y, z0)) for x, y in pts]
    hi = [bm.verts.new((x, y, z1)) for x, y in pts]
    # No end caps: the skirting and the cap cover them. The sides only, the back against the sheet left out too.
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        if i != 0:
            bm.faces.new([lo[i], lo[j], hi[j], hi[i]])
    ob = kit.mesh_object(name, bm, BATTEN_C)
    ob.data.update()
    for p in ob.data.polygons:  # face out of the batten's middle
        c = p.center
        if (c.x - (x0 + x1) / 2) * p.normal.x + (c.y - y_in) * p.normal.y < 0:
            p.flip()
    return ob


def rod(name: str, profile: list, colour: int, caps: bool = False) -> object:
    """A length of moulding the module's width along X, its cross-section `profile` ((y, z) points); its ends open
    (the next module's carries on from it) unless `caps`."""
    hw = WIDE / 2
    bm = bmesh.new()
    a = [bm.verts.new((-hw, y, z)) for y, z in profile]
    b = [bm.verts.new((hw, y, z)) for y, z in profile]
    if caps:
        bm.faces.new(a)
        bm.faces.new(list(reversed(b)))
    for i in range(len(profile)):
        j = (i + 1) % len(profile)
        bm.faces.new([a[i], a[j], b[j], b[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return kit.mesh_object(name, bm, colour)


def dot(name: str, x: float, z: float, side: int, w: float, h: float, colour: int, y: float,
        sides: int = 4) -> object:
    """A flat mark (a screw or nail head, a patch) on the face at |y|, facing out on `side`: a square, or with
    `sides` other than 4 a football patch's lens."""
    bm = bmesh.new()
    yy = side * y
    if sides == 4:
        pts = [(x - w / 2, z - h / 2), (x + w / 2, z - h / 2), (x + w / 2, z + h / 2), (x - w / 2, z + h / 2)]
    else:  # a lens: pointed at both ends, its sides curved (a football patch)
        pts = [(x - w / 2, z), (x - w / 4, z - h * 0.42), (x, z - h / 2), (x + w / 4, z - h * 0.42), (x + w / 2, z),
               (x + w / 4, z + h * 0.42), (x, z + h / 2), (x - w / 4, z + h * 0.42)]
    bm.faces.new([bm.verts.new((px, yy, pz)) for px, pz in pts])
    ob = kit.mesh_object(name, bm, colour)
    ob.data.update()
    if (ob.data.polygons[0].normal.y > 0) != (side > 0):
        ob.data.flip_normals()
    return ob


def build(tall: float) -> list:
    """One module: a sheet each side between half battens at both ends (two modules side by side meet as one batten),
    a stud's row of nails up the sheet's middle, oval patches, the skirting and the cap; full height also a rail
    over the sheet's top edge with the filler strip above."""
    kit.reset()
    parts = []
    hw, ht = WIDE / 2, THICK / 2
    inner = ht - FACE
    full = tall > SHEET
    top = tall - CAP
    skirt = 0.0 if tall < HEADER_UNDER else min(SKIRT, tall * 0.2)
    sheet_top = SHEET - RAIL / 2 if full else top
    parts.append(kit.box("core", (-hw, -inner + 0.001, skirt), (hw, inner - 0.001, top), SHEET_A, shade=0.8))
    for side in (-1, 1):
        y0, y1 = sorted((side * (inner - 0.002), side * inner))
        # The sheet's face only: the core is behind it, the battens over its ends.
        parts.append(dot("sheet", 0.0, (skirt + sheet_top) / 2, side, WIDE, sheet_top - skirt, SHEET_A, inner))
        if full:
            parts.append(dot("filler", 0.0, (SHEET + RAIL / 2 + top) / 2, side, WIDE, top - SHEET - RAIL / 2, FILLER,
                             inner))
            ri, ro = side * (inner - 0.002), side * (ht - 0.002)
            parts.append(rod("rail", [(ri, SHEET - RAIL / 2), (ro, SHEET - RAIL / 2), (ro, SHEET + RAIL / 2),
                                      (ri, SHEET + RAIL / 2)], BATTEN_C))
            for rx in (-0.15, 0.15):
                parts.append(dot("screw", rx, SHEET, side, SCREW, SCREW, SCREW_C, ht - 0.0012))
        # The skirting, its top edge bevelled off (a header has none).
        if skirt > 0.0:
            y0s, y1s = side * (inner - 0.002), side * (inner + SKIRT_PROUD)
            parts.append(rod("skirt", [(y0s, 0.0), (y1s, 0.0), (y1s, skirt - 0.006), (y0s + side * 0.002, skirt)],
                             SKIRT_C))
        # Half battens at both ends, screws up each (the pair at a joint shows two rows).
        for x0, x1 in ((-hw, -hw + BATTEN / 2), (hw - BATTEN / 2, hw)):
            parts.append(batten("batten", x0, x1, skirt, top, side))
            sx = (x0 + x1) / 2
            z = skirt + 0.15
            while z < top - 0.1:
                parts.append(dot("screw", sx, z, side, SCREW, SCREW, SCREW_C, ht - 0.0002))
                z += SCREW_STEP
        # The stud's nails up the sheet's middle.
        z = skirt + 0.1
        while z < sheet_top - 0.05:
            parts.append(dot("nail", 0.0, z, side, NAIL, NAIL, NAIL_C, inner + 0.0006))
            z += NAIL_STEP if full else 0.12
        for kx, kz in PATCHES:
            if kz < sheet_top - 0.08 and kz > skirt + 0.05:
                parts.append(dot("patch", kx * side, kz, side, 0.07, 0.03, PATCH_C, inner + 0.0008, sides=8))
    # The cap along the top, its outer edges eased.
    e = 0.008
    parts.append(rod("cap", [(-ht, top), (ht, top), (ht, tall - e), (ht - e, tall), (-ht + e, tall), (-ht, tall - e)],
                     CAP_C))
    return parts


def make(name: str, tall: float) -> None:
    parts = build(tall)
    count = kit.tris(parts)
    lo, hi = kit.bounds(parts)
    out = os.path.join(ROOT, "assets/models/props/%s.glb" % name)
    written = kit.export(out, name, parts)
    print("%s: %d triangles (budget %d), bounds %s to %s" % (name, written, BUDGET, lo, hi))
    if count > BUDGET:
        raise SystemExit("over budget")
    if PICTURES:
        kit.render(os.path.join(PICTURES, name), parts, [("front", 25, 12, 1.7), ("close", 15, 6, 0.8)])


def main() -> None:
    for name, tall in {**HEIGHTS, **HEADER}.items():
        make(name, tall)


if __name__ == "__main__":
    main()
