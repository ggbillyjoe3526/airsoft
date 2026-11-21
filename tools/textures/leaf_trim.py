"""Woodland's leaf sheet trimmed (WF1): for each cell of assets/textures/woodland/leaves.png that a leaf card draws
(tools/blender/maps/treekit.py CELLS, rows 0 to 2), the smallest rectangle holding every texel the foliage shader can
draw from it at mip level MAX_MIP or finer (look_foliage.gdshader: a texel's alpha, grown by its mip level, at or over
the cut), written to assets/textures/woodland/leaves_trim.tres (LeafTrimSheet). LeafTrim cuts a tree crown's cards down
to it, and the shader opens each card out to its whole cell before its cut-out reads a coarser level, so every leaf
is drawn where it was at every distance while the near cards (most of a crown's fill) lose their empty margins.

A texel counts when its alpha at a level L up to MAX_MIP, read bilinearly at the texel's middle and times
(1 + (L + 1) * MIP_COVER) (a trilinear read between two levels is never over the larger), reaches CUT; the rectangle
is then grown MARGIN texels of the full sheet each way (the VRAM compression's alpha error). The mips are the 2 x 2 box
average the importer takes (Image.generate_mipmaps on a power-of-two sheet). Run it again when the sheet changes;
tests/unit/test_wf1_leaf_trim.gd checks the rectangles still hold the sheet's drawn texels.

    python3 -I tools/textures/leaf_trim.py <repo root>

Dev only: tools/ never ships.
"""

import os
import sys

import numpy as np
from PIL import Image

SHEET = "assets/textures/woodland/leaves.png"
OUT = "assets/textures/woodland/leaves_trim.tres"
GRID = 4
CARD_ROWS = 3          # rows 0 to 2 are cards; row 3 the opaque masses and twig bark (never trimmed)
CUT = 0.5              # look_foliage.gdshader alpha_cut
MIP_COVER = 0.35       # its mip_cover at the most any model sets it (PropDress.MIP_COVER)
MAX_MIP = 6            # a cell eight texels across; the shader opens the card out before its cut-out reads coarser
MARGIN = 4             # full-sheet texels
UID = "uid://bwqcaehdoqvg"  # the resource's own, kept every run so the editor never rewrites it


def mips(a: np.ndarray) -> list:
    out = [a]
    while a.shape[0] > 1:
        a = a.reshape(a.shape[0] // 2, 2, a.shape[1] // 2, 2).mean(axis=(1, 3))
        out.append(a)
    return out


def bilinear(level: np.ndarray, shift: int, x0: int, y0: int, size: int) -> np.ndarray:
    """A mip level read bilinearly (as the GPU reads it, edges clamped) at each full-size texel's middle of the
    `size`-square from (`x0`, `y0`)."""
    n = level.shape[0]
    at = (np.arange(size) + 0.5) / (1 << shift) - 0.5
    xs = at + x0 / (1 << shift)
    ys = at + y0 / (1 << shift)
    x_lo = np.clip(np.floor(xs).astype(int), 0, n - 1)
    y_lo = np.clip(np.floor(ys).astype(int), 0, n - 1)
    x_hi = np.clip(x_lo + 1, 0, n - 1)
    y_hi = np.clip(y_lo + 1, 0, n - 1)
    fx = np.clip(xs - np.floor(xs), 0.0, 1.0)[None, :]
    fy = np.clip(ys - np.floor(ys), 0.0, 1.0)[:, None]
    top = level[np.ix_(y_lo, x_lo)] * (1 - fx) + level[np.ix_(y_lo, x_hi)] * fx
    bottom = level[np.ix_(y_hi, x_lo)] * (1 - fx) + level[np.ix_(y_hi, x_hi)] * fx
    return top * (1 - fy) + bottom * fy


def kept(levels: list, cx: int, cy: int, size: int) -> np.ndarray:
    """The cell's texels (full size, True where the shader may draw one at MAX_MIP or finer)."""
    keep = np.zeros((size, size), bool)
    for lv in range(MAX_MIP + 1):
        a = bilinear(levels[lv], lv, cx * size, cy * size, size)
        keep |= a * (1.0 + (lv + 1) * MIP_COVER) >= CUT
    return keep


def rect(keep: np.ndarray, size: int) -> tuple:
    """The kept texels' rectangle, grown MARGIN texels each way and held to the cell (x, y, width, height in 0..1)."""
    ys, xs = np.nonzero(keep)
    if xs.size == 0:
        return (0.0, 0.0, 0.0, 0.0)
    x0 = max(int(xs.min()) - MARGIN, 0)
    y0 = max(int(ys.min()) - MARGIN, 0)
    x1 = min(int(xs.max()) + 1 + MARGIN, size)
    y1 = min(int(ys.max()) + 1 + MARGIN, size)
    return (x0 / size, y0 / size, (x1 - x0) / size, (y1 - y0) / size)


def main() -> None:
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    a = np.asarray(Image.open(os.path.join(root, SHEET)).convert("RGBA").getchannel("A"), dtype=np.float64) / 255.0
    size = a.shape[0] // GRID
    levels = mips(a)
    rects = []
    for cy in range(GRID):
        for cx in range(GRID):
            if cy >= CARD_ROWS:
                rects.append((0.0, 0.0, 0.0, 0.0))  # drawn whole
                continue
            r = rect(kept(levels, cx, cy, size), size)
            print("cell %d,%d: %.2f of the cell" % (cx, cy, r[2] * r[3]))
            rects.append(r)
    lines = [
        '[gd_resource type="Resource" script_class="LeafTrimSheet" load_steps=2 format=3 uid="%s"]' % UID,
        "",
        '[ext_resource type="Script" path="res://game/play/look/leaf_trim_sheet.gd" id="1"]',
        "",
        "[resource]",
        'script = ExtResource("1")',
        "grid = %d" % GRID,
        "max_mip = %.1f" % MAX_MIP,
        "rects = Array[Rect2]([%s])" % ", ".join("Rect2(%.6f, %.6f, %.6f, %.6f)" % r for r in rects),
    ]
    with open(os.path.join(root, OUT), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
