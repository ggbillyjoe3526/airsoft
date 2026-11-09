"""The wooden crate (DM1, 2026-11-09): assets/models/props/crate.glb, Depot's crate walls and Woodland's crate stacks.

A plywood shipping crate after the owner's photos (art/references/maps/william-2026-11-09/wooden_crate/): birch
plywood sides and lid, the lid a sheet laid on top, galvanised steel edge profiles along all twelve edges with the
clip loops of a nail-less crate along the top and flat clips along the foot, a block pallet under it (three bottom
boards, nine blocks, a deck; its fork openings dark), grain streaks down each face, and the stencils a crate carries
(two up arrows and a blank label; no brand). The map's blocks set its footprint (GRID cells), not the photos'. Stacked by PropLayout's GRID in cells of
PropDressConfig.grid_cells[&"crate"] (two high in a 2.4 m wall, one in waist cover), each turned end for end at random.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/maps/crate.py <repo root> [pictures folder]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_kit as kit  # noqa: E402
import bmesh  # noqa: E402

ARGS = [a for a in sys.argv[1:] if os.path.isdir(a)]
ROOT = ARGS[0] if ARGS else os.getcwd()
PICTURES = ARGS[1] if len(ARGS) > 1 else ""
OUT = os.path.join(ROOT, "assets/models/props/crate.glb")

BUDGET = 400
# The crate's size (m): long side x, across y, up z; PropDressConfig's grid cell stretches it a little either way.
LONG, ACROSS, HIGH = 1.2, 1.0, 1.15
BASE = 0.12  # the skids and deck under the box
DECK = 0.025  # the deck boards on the runners
RUNNER = 0.1  # each runner's width
EDGE = 0.026  # an edge profile's leg on each face
PROUD = 0.006  # how far a profile stands off the plywood
LID = 0.012  # the lid sheet's thickness over the sides' tops
CLIP = (0.05, 0.03)  # a clip loop's width and height on the top profile
CLIPS_LONG = (-0.36, 0.0, 0.36)
CLIPS_SHORT = (0.0,)

# Wood tones kept out of Beta's orange (hue at least 20 degrees from it, or greyed: tests/unit/test_props.gd).
PLY = 0xd2c88c  # pine plywood, the long sides (his photos' warm tan, its hue past orange's band toward yellow)
PLY_END = 0xc6bc84  # the end panels, a sheet of a darker cut
PLY_LID = 0xded49e  # the lid, catching the light
PINE = 0xbab07c  # the pallet's boards
PINE_END = 0xaaa274  # its blocks, end grain
STEEL = 0xb6babd  # galvanised profiles and clips
INK = 0x3b3440  # stencil ink
SHADOW = 0x2a2824  # the dark inside the pallet's fork openings
GRAIN = 0xb2a874  # grain streaks on the sides' plywood
GRAIN_END = 0xaaa274  # and on the ends'
CLIP_C = 0x8a8e90  # the foot's clips, flat
HOLE = 0x3a3c40  # the profiles' perforations
LABEL = 0xefe8d6  # the shipping label


def flat(name: str, outline: list, y: float, colour: int, facing: int) -> object:
    """A flat stencil on the plane y, its outline (x, z) points, facing -Y (facing -1) or +Y (facing 1)."""
    bm = bmesh.new()
    pts = outline if facing < 0 else list(reversed(outline))
    bm.faces.new([bm.verts.new((x, y, z)) for x, z in pts])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = kit.mesh_object(name, bm, colour)
    n = ob.data.polygons[0].normal
    if (n.y > 0) != (facing > 0):
        ob.data.flip_normals()
    return ob


def turned_flat(name: str, outline: list, x: float, colour: int, facing: int) -> object:
    """A flat mark on the plane x, its outline (y, z) points, facing -X or +X."""
    bm = bmesh.new()
    bm.faces.new([bm.verts.new((x, y, z)) for y, z in outline])
    ob = kit.mesh_object(name, bm, colour)
    ob.data.update()
    if (ob.data.polygons[0].normal.x > 0) != (facing > 0):
        ob.data.flip_normals()
    return ob


def shadow_sheet(name: str, along: str, at: float, a0: float, a1: float, z0: float, z1: float) -> object:
    """A dark sheet, both faces, in the pallet's fork openings: along x at y `at`, or along y at x `at`."""
    bm = bmesh.new()
    if along == "x":
        pts = [(a0, at, z0), (a1, at, z0), (a1, at, z1), (a0, at, z1)]
    else:
        pts = [(at, a0, z0), (at, a1, z0), (at, a1, z1), (at, a0, z1)]
    bm.faces.new([bm.verts.new(p) for p in pts])
    bm.faces.new([bm.verts.new(p) for p in reversed(pts)])
    return kit.mesh_object(name, bm, SHADOW)


def streak(c: float, w: float, wave: float, z0: float, z1: float) -> list:
    """A grain streak's outline (across, up): `w` wide, wavering `wave` off its line at a third and two thirds up."""
    zs = (z0, z0 + (z1 - z0) / 3, z0 + 2 * (z1 - z0) / 3, z1)
    offs = (0.0, wave, -wave * 0.5, wave * 0.3)
    left = [(c + o - w / 2, z) for o, z in zip(offs, zs)]
    right = [(c + o + w / 2, z) for o, z in zip(offs, zs)]
    return right + list(reversed(left))


def arrow(cx: float, z0: float, w: float, h: float) -> list:
    """An up arrow's outline, its foot's middle at (cx, z0)."""
    stem, head = w * 0.32, h * 0.45
    return [(cx - stem / 2, z0), (cx + stem / 2, z0), (cx + stem / 2, z0 + h - head), (cx + w / 2, z0 + h - head),
            (cx, z0 + h), (cx - w / 2, z0 + h - head), (cx - stem / 2, z0 + h - head)]


def build() -> list:
    kit.reset()
    parts = []
    hx, hy = LONG / 2, ACROSS / 2
    # The base, a block pallet: three bottom boards along the long side, nine blocks, a deck of boards across. The
    # fork openings between the blocks are dark (a shadow sheet down the middle each way), so they read as openings.
    bz = BASE - DECK
    board = 0.02
    for y in (-hy + RUNNER / 2, 0.0, hy - RUNNER / 2):
        parts.append(kit.open_box("board", (-hx, y - RUNNER / 2, 0.0), (hx, y + RUNNER / 2, board), PINE, ("-z",)))
        for x in (-hx + RUNNER / 2, 0.0, hx - RUNNER / 2):
            if x == 0.0 and y == 0.0:
                continue  # the middle block: nobody sees it past the dark sheets
            # Each block's faces toward the pallet's middle look past the dark sheets only: left out.
            inward = tuple(h for h, v in (("-x", x), ("-y", y)) if v > 0) + \
                tuple(h for h, v in (("+x", x), ("+y", y)) if v < 0)
            parts.append(kit.open_box("block", (x - RUNNER / 2, y - RUNNER / 2, board), (x + RUNNER / 2, y + RUNNER / 2, bz),
                                      PINE_END, ("-z", "+z") + inward))
    parts.append(shadow_sheet("opening", "x", 0.0, -hx + RUNNER, hx - RUNNER, board, bz))
    parts.append(shadow_sheet("opening", "y", 0.0, -hy + RUNNER, hy - RUNNER, board, bz))
    parts.append(kit.open_box("deck", (-hx, -hy, bz), (hx, hy, BASE), PINE, ("+z",), shade=1.04))
    # The plywood box, its faces inside the profiles' line, and the lid sheet over its top.
    ix, iy = hx - PROUD, hy - PROUD
    body = kit.open_box("body", (-ix, -iy, BASE), (ix, iy, HIGH - LID), PLY, ("+z", "-z"))
    body.data.materials.append(kit.material(PLY_END))
    for p in body.data.polygons:
        if abs(p.normal.x) > 0.5:
            p.material_index = 1
    parts.append(body)
    parts.append(kit.open_box("lid", (-ix, -iy, HIGH - LID), (ix, iy, HIGH - PROUD * 0.5), PLY_LID, ("-z",)))
    # The twelve edge profiles: square bars on the box's edges, standing PROUD off each face.
    e = EDGE
    for sx in (-1, 1):
        for sy in (-1, 1):
            x0, x1 = sorted((sx * hx, sx * (hx - e)))
            y0, y1 = sorted((sy * hy, sy * (hy - e)))
            parts.append(kit.open_box("post", (x0, y0, BASE), (x1, y1, HIGH), STEEL,
                                  ("-x" if sx > 0 else "+x", "-y" if sy > 0 else "+y", "-z")))
    for z0, z1 in ((BASE, BASE + e), (HIGH - e, HIGH)):
        low = ("-z",) if z0 == BASE else ()
        for sy in (-1, 1):
            y0, y1 = sorted((sy * hy, sy * (hy - e)))
            parts.append(kit.open_box("rail", (-hx + e, y0, z0), (hx - e, y1, z1), STEEL, ("-y" if sy > 0 else "+y",) + low,
                                  shade=0.97))
        for sx in (-1, 1):
            x0, x1 = sorted((sx * hx, sx * (hx - e)))
            parts.append(kit.open_box("rail", (x0, -hy + e, z0), (x1, hy - e, z1), STEEL, ("-x" if sx > 0 else "+x",) + low,
                                  shade=0.97))
    # The clip loops on the top profiles, standing off them.
    cw, ch = CLIP
    for sy in (-1, 1):
        for x in CLIPS_LONG:
            y0, y1 = sorted((sy * hy, sy * (hy + PROUD)))
            parts.append(kit.open_box("clip", (x - cw / 2, y0, HIGH - ch - 0.004), (x + cw / 2, y1, HIGH - 0.004), STEEL,
                                      ("-y" if sy > 0 else "+y", "+x", "-x"), shade=0.9))
            # Its partner on the foot's profile, flat.
            parts.append(flat("clip", [(x - cw / 2, BASE + 0.003), (x + cw / 2, BASE + 0.003),
                                       (x + cw / 2, BASE + ch), (x - cw / 2, BASE + ch)], sy * (hy + 0.0015), CLIP_C, sy))
    for sx in (-1, 1):
        for y in CLIPS_SHORT:
            x0, x1 = sorted((sx * hx, sx * (hx + PROUD)))
            parts.append(kit.open_box("clip", (x0, y - cw / 2, HIGH - ch - 0.004), (x1, y + cw / 2, HIGH - 0.004), STEEL,
                                      ("-x" if sx > 0 else "+x", "+y", "-y"), shade=0.9))
            parts.append(turned_flat("clip", [(y - cw / 2, BASE + 0.003), (y + cw / 2, BASE + 0.003),
                                              (y + cw / 2, BASE + ch), (y - cw / 2, BASE + ch)], sx * (hx + 0.0015),
                                     CLIP_C, sx))
    # Grain streaks down each face, darker (his photos' strong figure): thin and wavering, three on each long side
    # and two on each end, so they read as grain, not as the seams between boards.
    top = HIGH - e - LID
    for facing in (-1, 1):
        y = facing * (iy + 0.001)
        for gx, w, wave in ((-0.31, 0.016, 0.03), (0.04, 0.012, -0.025), (0.3, 0.02, 0.035)):
            parts.append(flat("grain", streak(gx * -facing, w, wave, BASE + e, top), y, GRAIN, facing))
    for sx in (-1, 1):
        x = sx * (ix + 0.001)
        for gy, w, wave in ((-0.2, 0.016, 0.03), (0.22, 0.013, -0.03)):
            parts.append(turned_flat("grain", streak(gy * sx, w, wave, BASE + e, top), x, GRAIN_END, sx))
    # The edge profiles' perforations: a column of dark holes up each outer face of the corner profiles.
    for sx in (-1, 1):
        for sy in (-1, 1):
            for k in range(3):
                z = BASE + 0.2 + k * (HIGH - BASE - 0.4) / 2
                px = sx * (hx - e / 2)
                parts.append(flat("hole", [(px - 0.005, z - 0.005), (px + 0.005, z - 0.005), (px + 0.005, z + 0.005),
                                           (px - 0.005, z + 0.005)], sy * (hy + 0.0008), HOLE, sy))
                py = sy * (hy - e / 2)
                parts.append(turned_flat("hole", [(py - 0.005, z - 0.005), (py + 0.005, z - 0.005),
                                                  (py + 0.005, z + 0.005), (py - 0.005, z + 0.005)], sx * (hx + 0.0008),
                                         HOLE, sx))
    # Stencils on both long sides: two up arrows high on the left, a blank label low on the right.
    for facing in (-1, 1):
        y = facing * (iy + 0.0015)
        s = -facing  # mirror so each side reads left to right from outside
        for k in (0, 1):
            parts.append(flat("arrow", arrow(s * (-0.40 + k * 0.08), 0.82, 0.06, 0.12), y, INK, facing))
        lx = s * 0.36
        parts.append(flat("label", [(lx - 0.07, 0.24), (lx + 0.07, 0.24), (lx + 0.07, 0.33), (lx - 0.07, 0.33)], y,
                          LABEL, facing))
    return parts


def main() -> None:
    parts = build()
    count = kit.tris(parts)
    lo, hi = kit.bounds(parts)
    written = kit.export(OUT, "crate", parts)
    print("crate: %d triangles (budget %d), bounds %s to %s -> %s" % (written, BUDGET, lo, hi, OUT))
    if count > BUDGET:
        raise SystemExit("over budget")
    if PICTURES:
        kit.render(os.path.join(PICTURES, "crate"), parts,
                   [("front", 30, 20, 3.4), ("rear", 210, 20, 3.4), ("top", 60, 55, 3.6), ("close", 20, 12, 1.9)])


if __name__ == "__main__":
    main()
