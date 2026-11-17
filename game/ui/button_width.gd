class_name ButtonWidth
extends RefCounted
## The menus' one rule for button widths (owner, 2026-10-29): a button is as wide as its words plus the theme's padding,
## and the buttons in one group (a row, a column or a bar on one screen) all take the widest one's width, so the group
## reads even and none has a field of empty space in it.
##
## `ButtonWidth.group(buttons)` sets each button's `custom_minimum_size.x` to the widest `get_minimum_size().x` (the
## button's own size, which leaves out `custom_minimum_size`, so measuring never feeds back) and makes it hug that width
## instead of filling its container. A button that is hidden (`visible` false: the pause menu's practice-only rows) sets no
## width. A group measures itself again when a button's words, font, theme or visibility change (`minimum_size_changed`,
## `visibility_changed`), so a translation, a rebound key name, a row shown at run time or a theme that arrives once the
## buttons are in the tree all settle on their own. Each button keeps its group (meta), so nothing else needs to hold it, and it goes with them.

## The meta a button keeps its group in, and the one a button keeps its overlay in (see `overlay`).
const META := &"button_width"
const OVERLAY_META := &"button_overlay"
## The room kept between a button's words and its overlay's (px).
const OVERLAY_GAP := 24.0

## Untyped: a freed button is only a stale entry, skipped.
var _buttons: Array = []
## How the buttons sit in a container wider than they are.
var _align: Control.SizeFlags = Control.SIZE_SHRINK_BEGIN
## The width the group has now (px).
var _width: float = 0.0


## Makes `buttons` one group, hugging the container's start (`align` SHRINK_BEGIN), or its middle or end.
static func group(buttons: Array, align: Control.SizeFlags = Control.SIZE_SHRINK_BEGIN) -> ButtonWidth:
	var g := ButtonWidth.new()
	g._align = align
	for b: Button in buttons:
		g._hold(b)
	g.refresh()
	return g


## Adds `b` to the group (a button made later, as a rebound key's), and measures the group again.
func add(b: Button) -> void:
	_hold(b)
	refresh()


## Tells the group that `overlay`, a control drawn over the right of `b` (the pause menu's ON and OFF chips, a key's cap),
## takes room of its own: `b` is as wide as its words, a gap and the overlay.
static func overlay(b: Button, overlay_control: Control) -> void:
	b.set_meta(OVERLAY_META, overlay_control)


## The width every button in the group has (px).
func width() -> float:
	return _width


## Measures the group and sets every button to the widest. A button not yet in a tree has no theme to measure with: it is
## measured again when it gets one.
func refresh() -> void:
	var live: Array[Button] = []
	for entry: Variant in _buttons:
		if is_instance_valid(entry) and not (entry as Button).is_queued_for_deletion():
			live.append(entry as Button)
	_buttons = live
	var widest := 0.0
	for b in live:
		if b.visible:
			widest = maxf(widest, _natural(b))
	_width = widest
	for b in live:
		b.size_flags_horizontal = _align
		b.custom_minimum_size.x = widest


func _hold(b: Button) -> void:
	_buttons.append(b)
	b.set_meta(META, self)
	b.minimum_size_changed.connect(refresh)
	b.visibility_changed.connect(refresh)


## The width `b` needs on its own: its words and padding, and an overlay's room; words set in the middle need that room
## on both sides, or they run under the overlay (the pause menu's TIMED CHALLENGE under its ON and OFF, owner
## 2026-11-17).
static func _natural(b: Button) -> float:
	var width := b.get_minimum_size().x
	if b.has_meta(OVERLAY_META):
		var over := b.get_meta(OVERLAY_META) as Control
		if over != null and is_instance_valid(over):
			var room := OVERLAY_GAP + over.get_combined_minimum_size().x
			width += room * 2.0 if b.alignment == HORIZONTAL_ALIGNMENT_CENTER else room
	return width
