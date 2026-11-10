class_name ButtonPress
extends Control
## Every button answers a press (owner, 2026-11-10: "a simple animation where it looks like the button is being clicked
## ... even a simple highlight outline"): it dips in a little about its middle and springs back, and an outline in the
## accent lights just round it and fades. With Reduced motion (Settings › Accessibility) only the outline shows.
##
## `ButtonPress.install(tree)` (once, at boot; `uninstall` as the game leaves the tree) hooks every BaseButton in the
## tree and every one added later, as TooltipWrap watches for tooltips. A button gets its ring, an internal child drawn
## over it (so `get_children()` and the pages' own children never see it), the first time it is pressed; the ring plays
## the press on its button. A key or a pad presses a focused button as a click does (ui_accept sends button_down).

## A press dips the button to PRESS_SCALE of its size, but never more than MAX_DIP px at a side, so a big card dips by
## as much as a small button and its words don't swim.
const PRESS_SCALE := 0.95
const MAX_DIP := 4.0
## The dip's way in and back out, and how long the outline takes to fade after the dip (s).
const DIP_IN := 0.05
const DIP_OUT := 0.16
const RING_FADE := 0.3
## The outline's width and the dark gap between it and the button's edge (px at 1080p).
const RING_WIDTH := 2
const RING_GAP := 2
## A button scales about its middle.
const PIVOT := Vector2(0.5, 0.5)

var _box: StyleBoxFlat = null
var _tween: Tween = null


static func install(tree: SceneTree) -> void:
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	for found: Node in tree.root.find_children("*", "BaseButton", true, false):
		_on_node_added(found)


## Stops hooking buttons added from now on (the game leaving the tree: a test's game must not leave the hook behind).
## Buttons already hooked keep their hook until they are freed.
static func uninstall(tree: SceneTree) -> void:
	if tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)


static func _on_node_added(node: Node) -> void:
	var b := node as BaseButton
	if b == null:
		return
	# a button that leaves the tree and comes back keeps its one hook
	var down := _on_down.bind(b)
	if not b.button_down.is_connected(down):
		b.button_down.connect(down)


static func _on_down(b: BaseButton) -> void:
	var ring := ring_of(b)
	if ring == null:
		ring = ButtonPress.new()
		b.add_child(ring, false, Node.INTERNAL_MODE_BACK)
	ring.play(Settings.shared().reduces_motion_now())


## The ring `b` was given on its first press, or null before then.
static func ring_of(b: BaseButton) -> ButtonPress:
	for i: int in range(b.get_child_count(true) - 1, -1, -1):
		var ring := b.get_child(i, true) as ButtonPress
		if ring != null:
			return ring
	return null


func _init() -> void:
	name = "PressRing"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_box = GameTheme.focus_box()
	_box.border_color = GameTheme.ACCENT
	_box.set_border_width_all(RING_WIDTH)
	_box.set_expand_margin_all(RING_GAP + RING_WIDTH)


## Plays the press on the button this ring is in: the outline lights and fades, and unless `still` the button dips and
## springs back. A press during the last one starts it again.
func play(still: bool = false) -> void:
	var b := get_parent() as Control
	if _tween != null:
		_tween.kill()
	_box.set_corner_radius_all(_radius(b) + RING_GAP + RING_WIDTH)
	visible = true
	modulate.a = 1.0
	queue_redraw()
	_tween = create_tween().set_parallel(true)
	if not still:
		b.pivot_offset_ratio = PIVOT
		var longest := maxf(b.size.x, b.size.y)
		var dip := maxf(PRESS_SCALE, 1.0 - 2.0 * MAX_DIP / longest) if longest > 0.0 else PRESS_SCALE
		b.scale = Vector2.ONE
		_tween.tween_property(b, "scale", Vector2.ONE * dip, DIP_IN).set_trans(Tween.TRANS_QUAD) \
				.set_ease(Tween.EASE_OUT)
		_tween.tween_property(b, "scale", Vector2.ONE, DIP_OUT).set_delay(DIP_IN).set_trans(Tween.TRANS_BACK) \
				.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, RING_FADE).set_delay(DIP_IN).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(hide)


## Whether the press is still playing.
func playing() -> bool:
	return _tween != null and _tween.is_running()


func _draw() -> void:
	draw_style_box(_box, Rect2(Vector2.ZERO, size))


## The corner radius of the box `b` is drawn in, so the outline follows its corners (a card's, a pill's).
func _radius(b: Control) -> int:
	var face := b.get_theme_stylebox(&"normal") as StyleBoxFlat
	return face.corner_radius_top_left if face != null else GameTheme.RADIUS
