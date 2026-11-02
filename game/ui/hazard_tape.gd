class_name HazardTape
extends Control
## The strip of hazard tape over the title: safety yellow stripes leaning right on near-black (the concept's
## `repeating-linear-gradient(-45deg, yellow 0 14px, #1a1a1a 14px 28px)`).

const SIZE := Vector2(120.0, 14.0)
const DARK := Color("1a1a1a")
## The stripe's width across (px); the gap between stripes is the same.
const STRIPE := 14.0

## The stripes' colour: safety yellow, or the crash screen's warning orange.
var stripe_colour: Color = GameTheme.ACCENT


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DARK)
	# Stripes at 45 degrees: STRIPE across is STRIPE * sqrt(2) along the strip.
	var along := STRIPE * sqrt(2.0)
	var x := -size.y
	while x < size.x + size.y:
		draw_colored_polygon(PackedVector2Array([Vector2(x, size.y), Vector2(x + along, size.y),
				Vector2(x + along + size.y, 0.0), Vector2(x + size.y, 0.0)]), stripe_colour)
		x += along * 2.0
