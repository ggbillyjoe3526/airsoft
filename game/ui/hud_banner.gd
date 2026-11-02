class_name HudBanner
extends MarginContainer
## A round's banner (the concept's `.banner`): heavy capitals on a slanted dark panel with a yellow rule along its top,
## the second line under it in muted capitals. The panel grows to its words; text is set only when a banner is shown.

var _big: Label = null
var _sub: Label = null
var _column: VBoxContainer = null


## `pad` is the padding round the words (left, top, right, bottom; the round banners' by default).
func setup(pad: Vector4 = HudStyle.BANNER_PAD) -> void:
	name = "HudBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override("margin_left", roundi(pad.x))
	add_theme_constant_override("margin_top", roundi(pad.y))
	add_theme_constant_override("margin_right", roundi(pad.z))
	add_theme_constant_override("margin_bottom", roundi(pad.w))
	var column := VBoxContainer.new()
	_column = column
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", HudStyle.BANNER_SUB_GAP)
	add_child(column)
	_big = HudStyle.label(column, HudStyle.BANNER_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER,
			HudStyle.SPACING_BANNER)
	_sub = HudStyle.label(column, HudStyle.BANNER_SUB_SIZE, 700, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER,
			HudStyle.SPACING_SUB)
	visible = false


## Puts `row` under the words (the timed challenge's result); the banner shows it while it is visible.
func add_row(row: Control) -> void:
	_column.add_child(row)


## Shows `big` (in `colour`, the text colour when transparent) over `sub`; either may be empty.
func show_text(big: String, sub: String, colour: Color = Color.TRANSPARENT) -> void:
	_big.text = big
	_big.visible = not big.is_empty()
	_big.add_theme_color_override("font_color", colour if colour.a > 0.0 else GameTheme.TEXT)
	_sub.text = sub
	_sub.visible = not sub.is_empty()
	# Shrink to the new words; the parent lays it out again.
	reset_size()
	visible = true
	queue_redraw()


func big_text() -> String:
	return _big.text


func sub_text() -> String:
	return _sub.text


func _draw() -> void:
	var w := size.x
	var h := size.y
	if h <= 0.0:
		return
	var face := SlantStyle.corners(Rect2(0.0, 0.0, w, h))
	draw_colored_polygon(face, HudStyle.backing_on(self, HudStyle.BACKING_BANNER))
	# The rule: the top strip of the same parallelogram, its ends on the slanted edges.
	var lean := SlantStyle.SKEW
	var r := HudStyle.BANNER_RULE
	var rule := PackedVector2Array([face[0], face[1], Vector2(face[1].x - r * lean, r), Vector2(face[0].x - r * lean, r)])
	draw_colored_polygon(rule, GameTheme.ACCENT)
