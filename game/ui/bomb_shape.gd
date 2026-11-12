class_name BombShape
extends RefCounted
## Plant The Bomb's sign (PB1): the prop at an airsoft site, a small carry case with a handle and a light, drawn from
## shapes. Fit once into a box, then painted onto any canvas item without allocating, so the marker's glyph, the gauge's
## end, a feed line and the minimap's mark draw it without a node of their own (as ChevronShape).

## The drawing's box: a 24 x 24 viewbox, as HudFlagGlyph's.
const BOX := 24.0
## The case's body, the handle's three strokes (a bar over two legs), the light's spot and radius, in the viewbox.
const BODY := Rect2(2.5, 9.0, 19.0, 11.5)
const HANDLE: PackedVector2Array = [Vector2(8.5, 9.0), Vector2(8.5, 5.0), Vector2(15.5, 5.0), Vector2(15.5, 9.0)]
const HANDLE_WIDTH := 2.2
const LIGHT := Vector2(12.0, 14.75)
const LIGHT_RADIUS := 2.3
## The dark edge round the body and under the handle and the light (viewbox units).
const EDGE_WIDTH := 1.2

var _body := Rect2()
var _handle := PackedVector2Array()
var _light := Vector2.ZERO
var _radius: float = 0.0
var _handle_width: float = 1.0
var _edge: float = 1.0


func _init() -> void:
	_handle.resize(HANDLE.size())


## Fits the case, centred, into `box`.
func fit(box: Rect2) -> void:
	var k := minf(box.size.x, box.size.y) / BOX
	var offset := box.position + (box.size - Vector2.ONE * BOX * k) * 0.5
	_body = Rect2(offset + BODY.position * k, BODY.size * k)
	for i in HANDLE.size():
		_handle[i] = offset + HANDLE[i] * k
	_light = offset + LIGHT * k
	_radius = LIGHT_RADIUS * k
	_handle_width = HANDLE_WIDTH * k
	_edge = EDGE_WIDTH * k


## Paints the case in `colour` with its light in `light`, edged in `ink`.
func paint(item: CanvasItem, colour: Color, light: Color, ink: Color) -> void:
	item.draw_polyline(_handle, ink, _handle_width + _edge * 2.0)
	item.draw_polyline(_handle, colour, _handle_width)
	item.draw_rect(_body.grow(_edge), ink)
	item.draw_rect(_body, colour)
	item.draw_circle(_light, _radius + _edge, ink)
	item.draw_circle(_light, _radius, light)


## The case's body in the box it was fit to, for tests.
func body() -> Rect2:
	return _body
