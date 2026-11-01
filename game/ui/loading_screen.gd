class_name LoadingScreen
extends CanvasLayer
## The loading screen (concept `loading.png`): from PLAY until the match draws its first frame. The map's picture
## fills the screen under a shade that deepens toward the foot; over it the kicker ("ELIMINATION · 3 V 3 · YOU'RE
## ALPHA"), the map's name and line, a yellow bar and the step under way with the share done; the step's own stretch of
## the bar pulses while it runs (Woodland's nav grid takes about 6 s on a worker thread). It sits on a canvas layer
## above the match's own interface, takes every click, and is freed by whoever made it once the match runs. With
## `show_continue` (MC1, owner 2026-11-01: once the match is fully loaded) a CONTINUE button comes up bottom right,
## focused, and the step says Ready; its press (a click, Enter or Space) says `continued`.

## CONTINUE was pressed: the match can start.
signal continued

## Above the match's interface layer (PlaySession's).
const LAYER := 100
const PICTURE_DIR := "res://assets/maps/"
## The block's margins from the window's left and right edges and its bottom (px at 1080p).
const BLOCK_SIDE := 150.0
const BLOCK_BOTTOM := 150.0
const KICKER_SIZE := 22
const KICKER_SPACING := 0.1
const TITLE_SIZE := 120
const TITLE_TOP_GAP := 10
const BLURB_SIZE := 26
const BLURB_TOP_GAP := 14
const BAR_TOP_GAP := 48
const BAR_HEIGHT := 10.0
const BAR_TRACK := Color(1.0, 1.0, 1.0, 0.12)
## The step under way: its stretch of the bar in yellow, its opacity swinging between these once a period (s).
const PULSE_LOW := 0.15
const PULSE_HIGH := 0.55
const PULSE_PERIOD := 1.2
const STEP_SIZE := 18
const STEP_TOP_GAP := 14
## CONTINUE's offsets from the window's right and bottom edges (px at 1080p): under the block, its right edge on the
## block's.
const CONTINUE_RIGHT := BLOCK_SIDE
const CONTINUE_BOTTOM := 48.0
## The shade's opacity of the page colour, foot to top: (position from the foot, opacity).
const SHADE_STOPS: Array[Vector2] = [Vector2(0.0, 0.97), Vector2(0.18, 0.97), Vector2(0.60, 0.55), Vector2(1.0, 0.35)]
## A Latin line is taller than its capitals; the title's box is cut to its size so the gaps read as the concept's.
const TITLE_LINE_TRIM := 0.1

var _kicker: Label = null
var _title: Label = null
var _blurb: Label = null
var _fill: ColorRect = null
var _pending: ColorRect = null
var _pulse: float = 0.0
var _step: Label = null
var _percent: Label = null
var _picture: TextureRect = null
var _continue: Button = null


func _init() -> void:
	name = "LoadingScreen"
	layer = LAYER
	var root := Control.new()
	root.name = "Root"
	root.theme = GameTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var plate := ColorRect.new()
	plate.color = GameTheme.BG
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(plate)
	_picture = TextureRect.new()
	_picture.name = "Backdrop"
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_picture)
	root.add_child(_shade())
	root.add_child(_block())
	_continue = Button.new()
	_continue.name = "Continue"
	_continue.theme_type_variation = GameTheme.MAIN_BUTTON
	_continue.text = tr("LOAD_CONTINUE").to_upper()
	_continue.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_continue.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_continue.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_continue.offset_right = -CONTINUE_RIGHT
	_continue.offset_bottom = -CONTINUE_BOTTOM
	_continue.visible = false
	_continue.pressed.connect(func() -> void: continued.emit())
	root.add_child(_continue)


## Shows `map_name`, its `blurb` and the kicker, with the picture of `map_id` behind (a plain page when it has none).
func setup(map_id: String, map_name: String, blurb: String, kicker: String) -> void:
	var path := "%s%s.jpg" % [PICTURE_DIR, map_id]
	_picture.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_title.text = map_name.to_upper()
	_blurb.text = blurb
	_kicker.text = kicker
	set_progress(0, 1, "")


## `done` of `total` steps are finished; `step_text` is the one under way.
func set_progress(done: int, total: int, step_text: String) -> void:
	var share := clampf(float(done) / maxf(1.0, float(total)), 0.0, 1.0)
	_fill.anchor_right = share
	_pending.anchor_left = share
	_pending.anchor_right = clampf(float(done + 1) / maxf(1.0, float(total)), 0.0, 1.0)
	_pending.visible = done < total
	_step.text = step_text
	_percent.text = tr("LOAD_PERCENT") % roundi(share * 100.0)


## PlaySession's `progressed`: `step_key` is the translation key of the step under way ("" once all are built).
func set_progress_step(done: int, total: int, step_key: String) -> void:
	set_progress(done, total, tr(step_key if not step_key.is_empty() else "LOAD_START"))


## The match is fully loaded: the bar full, "Ready", and CONTINUE up and focused.
func show_continue() -> void:
	set_progress(1, 1, tr("LOAD_READY"))
	_continue.visible = true
	_continue.grab_focus()


func continue_button() -> Button:
	return _continue


func kicker_text() -> String:
	return _kicker.text


func title_text() -> String:
	return _title.text


func blurb_text() -> String:
	return _blurb.text


func step_text() -> String:
	return _step.text


func percent_text() -> String:
	return _percent.text


## The bar's filled share, 0 to 1.
func progress() -> float:
	return _fill.anchor_right


## The step under way's stretch of the bar: its opacity now (0 while none is under way).
func pulse() -> float:
	return _pending.modulate.a if _pending.visible else 0.0


func _process(delta: float) -> void:
	if not _pending.visible:
		return
	_pulse = fmod(_pulse + delta, PULSE_PERIOD)
	_pending.modulate.a = lerpf(PULSE_LOW, PULSE_HIGH, 0.5 - 0.5 * cos(TAU * _pulse / PULSE_PERIOD))


func _shade() -> Control:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colours := PackedColorArray()
	for stop in SHADE_STOPS:
		offsets.append(stop.x)
		colours.append(Color(GameTheme.BG, stop.y))
	gradient.offsets = offsets
	gradient.colors = colours
	var ramp := GradientTexture2D.new()
	ramp.gradient = gradient
	ramp.fill_from = Vector2(0.5, 1.0)
	ramp.fill_to = Vector2(0.5, 0.0)
	var shade := TextureRect.new()
	shade.name = "Shade"
	shade.texture = ramp
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	return shade


func _block() -> Control:
	var block := VBoxContainer.new()
	block.name = "Block"
	block.add_theme_constant_override("separation", 0)
	block.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	block.grow_vertical = Control.GROW_DIRECTION_BEGIN
	block.offset_left = BLOCK_SIDE
	block.offset_right = -BLOCK_SIDE
	block.offset_bottom = -BLOCK_BOTTOM
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kicker = _label(KICKER_SIZE, 800, GameTheme.YELLOW)
	_kicker.add_theme_font_override("font", GameTheme.spaced_font(800, KICKER_SPACING, KICKER_SIZE))
	block.add_child(_kicker)
	block.add_child(_space(TITLE_TOP_GAP))
	_title = _label(TITLE_SIZE, 800, GameTheme.TEXT)
	var box := Control.new()
	box.custom_minimum_size = Vector2(0.0, TITLE_SIZE)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.position.y = -TITLE_SIZE * TITLE_LINE_TRIM
	box.add_child(_title)
	block.add_child(box)
	block.add_child(_space(BLURB_TOP_GAP))
	_blurb = _label(BLURB_SIZE, 600, GameTheme.MUTED)
	block.add_child(_blurb)
	block.add_child(_space(BAR_TOP_GAP))
	var track := ColorRect.new()
	track.name = "Track"
	track.color = BAR_TRACK
	track.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill = ColorRect.new()
	_fill.name = "Fill"
	_fill.color = GameTheme.YELLOW
	_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_fill)
	_pending = ColorRect.new()
	_pending.name = "Pending"
	_pending.color = GameTheme.YELLOW
	_pending.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pending.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pending.modulate.a = PULSE_LOW
	track.add_child(_pending)
	block.add_child(track)
	block.add_child(_space(STEP_TOP_GAP))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_step = _label(STEP_SIZE, 600, GameTheme.MUTED)
	_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_percent = _label(STEP_SIZE, 600, GameTheme.MUTED)
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_step)
	row.add_child(_percent)
	block.add_child(row)
	return block


func _label(size: int, weight: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", GameTheme.font(weight))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _space(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap
