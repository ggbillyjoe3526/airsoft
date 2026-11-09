"""The wooden crate (DM1, 2026-11-09): assets/models/props/crate.glb, Depot's crate walls and Woodland's crate stacks.

A plywood shipping crate after the owner's photos (art/references/maps/william-2026-11-09/wooden_crate/): birch
plywood sides and lid, the lid a sheet laid on top, galvanised steel edge profiles along all twelve edges with the
clip loops of a nail-less crate along the top, a pine skid base of three runners under a deck, and the stencils a
crate carries (two up arrows and a blank label; no brand). Stacked by PropLayout's GRID in cells of
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

# Wood tones pale and greyed (saturation under 0.3 in linear light), so none reads as Beta's orange
# (tests/unit/test_props.gd).
PLY = 0xd6cbae  # birch plywood, the long sides
PLY_END = 0xc6b99c  # the end panels, a sheet of a darker cut
PLY_LID = 0xe0d8c4  # the lid, catching the light
PINE = 0xb5aa92  # the skids
PINE_END = 0xa09684  # the runners' cut ends
STEEL = 0xb6babd  # galvanised profiles and clips
INK = 0x3b3440  # stencil ink
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


def arrow(cx: float, z0: float, w: float, h: float) -> list:
    """An up arrow's outline, its foot's middle at (cx, z0)."""
    stem, head = w * 0.32, h * 0.45
    return [(cx - stem / 2, z0), (cx + stem / 2, z0), (cx + stem / 2, z0 + h - head), (cx + w / 2, z0 + h - head),
            (cx, z0 + h), (cx - w / 2, z0 + h - head), (cx - stem / 2, z0 + h - head)]


def build() -> list:
    kit.reset()
    parts = []
    hx, hy = LONG / 2, ACROSS / 2
    # The base: three runners along the long side under a deck.
    for y in (-hy + RUNNER / 2, 0.0, hy - RUNNER / 2):
        parts.append(kit.box("runner", (-hx, y - RUNNER / 2, 0.0), (hx, y + RUNNER / 2, BASE - DECK), PINE))
        parts.append(kit.box("block", (-hx, y - RUNNER / 2 - 0.004, 0.0), (-hx + 0.004, y + RUNNER / 2 + 0.004,
                                                                           BASE - DECK), PINE_END))
    parts.append(kit.box("deck", (-hx, -hy, BASE - DECK), (hx, hy, BASE), PINE, shade=1.04))
    # The plywood box, its faces inside the profiles' line, and the lid sheet over its top.
    ix, iy = hx - PROUD, hy - PROUD
    body = kit.box("body", (-ix, -iy, BASE), (ix, iy, HIGH - LID), PLY)
    body.data.materials.append(kit.material(PLY_END))
    for p in body.data.polygons:
        if abs(p.normal.x) > 0.5:
            p.material_index = 1
    parts.append(body)
    parts.append(kit.box("lid", (-ix, -iy, HIGH - LID), (ix, iy, HIGH - PROUD * 0.5), PLY_LID))
    # The twelve edge profiles: square bars on the box's edges, standing PROUD off each face.
    e = EDGE
    for sx in (-1, 1):
        for sy in (-1, 1):
            x0, x1 = sorted((sx * hx, sx * (hx - e)))
            y0, y1 = sorted((sy * hy, sy * (hy - e)))
            parts.append(kit.box("post", (x0, y0, BASE), (x1, y1, HIGH), STEEL))
    for z0, z1 in ((BASE, BASE + e), (HIGH - e, HIGH)):
        for sy in (-1, 1):
            y0, y1 = sorted((sy * hy, sy * (hy - e)))
            parts.append(kit.box("rail", (-hx + e, y0, z0), (hx - e, y1, z1), STEEL, shade=0.97))
        for sx in (-1, 1):
            x0, x1 = sorted((sx * hx, sx * (hx - e)))
            parts.append(kit.box("rail", (x0, -hy + e, z0), (x1, hy - e, z1), STEEL, shade=0.97))
    # The clip loops on the top profiles, standing off them.
    cw, ch = CLIP
    for sy in (-1, 1):
        for x in CLIPS_LONG:
            y0, y1 = sorted((sy * hy, sy * (hy + PROUD)))
            parts.append(kit.box("clip", (x - cw / 2, y0, HIGH - ch - 0.004), (x + cw / 2, y1, HIGH - 0.004), STEEL,
                                 shade=0.9))
    for sx in (-1, 1):
        for y in CLIPS_SHORT:
            x0, x1 = sorted((sx * hx, sx * (hx + PROUD)))
            parts.append(kit.box("clip", (x0, y - cw / 2, HIGH - ch - 0.004), (x1, y + cw / 2, HIGH - 0.004), STEEL,
                                 shade=0.9))
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
