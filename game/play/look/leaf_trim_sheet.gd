class_name LeafTrimSheet
extends Resource
## Where a leaf sheet's cells draw (WF1): for each cell of the sheet's `grid` x `grid` (row by row from its top left),
## the rectangle, in the cell's own 0 to 1 (x right, y down, as the sheet's UVs run), holding every texel the foliage
## shader can draw from it at mip level `max_mip` or finer (look_foliage.gdshader: a texel's alpha, grown by its mip
## level, at or over the cut); an empty rectangle for a cell drawn whole (the opaque masses and twig bark). Written by
## tools/textures/leaf_trim.py from the sheet; LeafTrim cuts the cards down to it.

@export var grid: int = 4
## The coarsest mip level the rectangles hold the cut-out to (look_foliage.gdshader opens a trimmed card out to its whole
## cell before its cut-out reads a coarser one).
@export var max_mip: float = 6.0
@export var rects: Array[Rect2] = []


## Cell `cell`'s rectangle (empty: the cell is drawn whole, or the sheet has no such cell).
func rect_of(cell: Vector2i) -> Rect2:
	var i := cell.y * grid + cell.x
	if cell.x < 0 or cell.y < 0 or cell.x >= grid or cell.y >= grid or i >= rects.size():
		return Rect2()
	return rects[i]
