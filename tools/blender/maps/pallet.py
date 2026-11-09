"""The pallet (RK1, Depot #14, shared with the Range): a four-way block pallet in pale pine after the owner's photos
(art/references/maps/william-2026-11-09/pallet/): nine top deck boards with real gaps, three cross boards under
them, nine blocks and three bottom boards across the foot, each board a slightly different shade with one weathered
darker board (photo 2). Modelled at the drum blocks' foot, 1.8 x 1.8 x 0.15 m, the pallet under nine drum stacks (PropLayout CLUSTER fits it
to the block's foot, 0.15 m high, unstretched). Budget 300 triangles.

Usage: python3 tools/blender/maps/pallet.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402

SIZE = 1.8
BOARD_T = 0.022       # every board's thickness
BLOCK_H = 0.084       # the blocks between the bottom boards and the cross boards
TOP_BOARDS = 9
TOP_W = 0.12
EDGE_W = 0.145        # the lead boards and the cross / bottom boards are wider
BLOCK_W = 0.13
INSET = 0.012         # the blocks stand this far in from the boards' edges, so the layers read
# A shade for each top board (pale pine, one weathered board), the boards under the deck a step darker.
TOP_SHADES = ["crate*1.04", "crate*0.97", "plywood*0.96", "crate*1.0", "timber*1.08", "crate*1.02", "plywood*0.94",
              "crate*0.98", "crate*1.03"]


def build() -> prop.Prop:
    p = prop.Prop("pallet")
    h = SIZE / 2
    z_block = BOARD_T + BLOCK_H
    z_cross = z_block + BOARD_T
    z_top = z_cross + BOARD_T
    rows = [-h + EDGE_W / 2, 0.0, h - EDGE_W / 2]
    # Bottom boards along x (the front one runs across the pallet's foot, photo 5), the blocks on them, the cross
    # boards along y over the blocks.
    for j, y in enumerate(rows):
        p.box((-h, y - EDGE_W / 2, 0.0), (h, y + EDGE_W / 2, BOARD_T), "crate*0.84")
    for i, x in enumerate(rows):
        for j, y in enumerate(rows):
            p.box((x - BLOCK_W / 2, y - BLOCK_W / 2, BOARD_T), (x + BLOCK_W / 2, y + BLOCK_W / 2, z_block),
                  "timber*1.12" if (i + j) % 2 else "crate*0.8")
        p.box((x - EDGE_W / 2, -h + INSET, z_block), (x + EDGE_W / 2, h - INSET, z_cross), "crate*0.88")
    # The top deck: boards along x, wider lead boards at the front and back, even gaps between.
    widths = [EDGE_W] + [TOP_W] * (TOP_BOARDS - 2) + [EDGE_W]
    gap = (SIZE - sum(widths)) / (TOP_BOARDS - 1)
    y = -h
    for w, shade in zip(widths, TOP_SHADES):
        p.box((-h, y, z_cross), (h, y + w, z_top), shade)
        y += w + gap
    return p


if __name__ == "__main__":
    build().export("pallet.glb", budget=300)
