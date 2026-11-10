class_name ChevronShape
extends RefCounted
## The teammate marker's chevron (concept `hud-feed.png`), pointing down at a teammate: filled in a colour with a dark
## edge, or hollow (an outline over a faint fill) while cover hides them. Fit once into a box, then painted onto any
## canvas item without allocating, so a feed line or a marker draws it without a node of its own.

## The concept's 20 x 15 viewbox: the chevron's four corners.
const BOX := Vector2(20.0, 15.0)
const SHAPE: PackedVector2Array = [Vector2(1.0, 1.5), Vector2(10.0, 13.5), Vector2(19.0, 1.5), Vector2(10.0, 5.5)]
const EDGE := Color(0.055, 0.054, 0.05, 0.85)
const EDGE_WIDTH := 1.2
const HOLLOW_WIDTH := 2.2
const HOLLOW_FILL := 0.25

var _points := PackedVector2Array()
var _ring := PackedVector2Array()
var _scale: float = 1.0


func _init() -> void:
	_points.resize(SHAPE.size())
	_ring.resize(SHAPE.size() + 1)


## Fits the chevron, centred, into `box`.
func fit(box: Rect2) -> void:
	_scale = minf(box.size.x / BOX.x, box.size.y / BOX.y)
	var offset := box.position + (box.size - BOX * _scale) * 0.5
	for i in SHAPE.size():
		_points[i] = offset + SHAPE[i] * _scale
		_ring[i] = _points[i]
	_ring[SHAPE.size()] = _points[0]


func paint(item: CanvasItem, colour: Color, hollow: bool) -> void:
	if hollow:
		item.draw_colored_polygon(_points, Color(colour, colour.a * HOLLOW_FILL))
		item.draw_polyline(_ring, colour, HOLLOW_WIDTH * _scale, true)
	else:
		item.draw_colored_polygon(_points, colour)
		item.draw_polyline(_ring, EDGE, EDGE_WIDTH * _scale, true)
