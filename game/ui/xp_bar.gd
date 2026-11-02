class_name XpBar
extends Control
## The XP bar (the concept's `.xpbar`): a slanted dim track with a yellow fill, as far along as `set_fraction` says. Used by
## the Armory and the end-of-match XP.

const HEIGHT := 14.0
const TRACK := Color(1.0, 1.0, 1.0, 0.08)

var _fraction: float = 0.0


func _init(height: float = HEIGHT) -> void:
	name = "XpBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0.0, height)


## `fraction` of the way along (0 to 1).
func set_fraction(fraction: float) -> void:
	_fraction = clampf(fraction, 0.0, 1.0)
	queue_redraw()


func fraction() -> float:
	return _fraction


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_colored_polygon(SlantStyle.corners(Rect2(Vector2.ZERO, size)), TRACK)
	if _fraction > 0.0:
		draw_colored_polygon(SlantStyle.corners(Rect2(Vector2.ZERO, Vector2(size.x * _fraction, size.y))), GameTheme.ACCENT)
