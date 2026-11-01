class_name SettingsHudPage
extends HBoxContainer
## The settings' HUD tab (concept `hud-options.png`; the browser game's Settings › HUD and Crosshair): on the left the
## crosshair (shape, colour, size, thickness, gap, opacity, dynamic or static spread, outline) and the hit marker (on or
## off, colour, size); on the right a live preview (HudPreview), the HUD size (marked at 100 %, concept
## `settings-hud-size.png`), the ammo counter, where the hit feed sits and whether its lines fade or stay, your team's
## callouts in it (CO2), the ping markers (PN2), the magazine hand-off's line (MH3), the navy panels' opacity and What got you, and the minimap's turn
## (Rotating or Fixed, drawn as two small samples). Every choice lands in the settings' HudPrefs at once and `changed` asks the screen to save it.

## A choice changed: saved now (`immediate`, a click) or a moment after a slider stops.
signal changed(immediate: bool)

## The columns' widths (the right one takes the rest), the labels' widths and the sliders' (px).
const LEFT_WIDTH := 780.0
const COLUMN_GAP := 48
const LEFT_LABEL := 200.0
const RIGHT_LABEL := 230.0
const SLIDER_WIDTH := SettingsScreen.SLIDER_WIDTH
## The space before a row's note (px).
const PX := "%d px"
const PERCENT := "%d%%"
## The minimap's samples: the map they draw, the gap between them (px) and the sample's scene: you at THUMB_AT looking
## THUMB_HEADING degrees clockwise from north, a teammate each at THUMB_TEAM (the second one hit).
const THUMB_MAP := "depot"
const THUMB_GAP := 8
const THUMB_AT := Vector2(-10.0, 1.5)
const THUMB_HEADING := 60.0
const THUMB_TEAM: Array[Vector2] = [Vector2(-3.5, -3.5), Vector2(-13.5, 5.5), Vector2(20.0, 2.0)]

var _screen: SettingsScreen = null
var _shape: MenuChoice = null
var _colour: MenuSwatches = null
var _size: HSlider = null
var _thickness: HSlider = null
var _gap: HSlider = null
var _opacity: HSlider = null
var _spread: MenuChoice = null
var _outline: CheckButton = null
var _marker: CheckButton = null
var _marker_colour: MenuSwatches = null
var _marker_size: HSlider = null
var _ammo: CheckButton = null
var _corner: MenuChoice = null
var _lines: MenuChoice = null
var _callouts: CheckButton = null
var _pings: CheckButton = null
var _mag: CheckButton = null
var _panels: HSlider = null
var _hud_size: HSlider = null
var _what_got_you: MenuChoice = null
var _turn: MenuChoice = null
var _zoom: HSlider = null
var _thumbs: Array[Thumb] = []
var _thumbs_row: HBoxContainer = null
var _preview: HudPreview = null
## The team colours the preview and the samples show: the saved set's HUD part, and that set, to tell a change.
var _teams: TeamConfig = null
var _teams_set: int = -1


func _init() -> void:
	name = "SettingsHudPage"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", COLUMN_GAP)


## Builds the tab with `screen`'s rows (SettingsScreen.add_row and the rest), editing its settings.
func build(screen: SettingsScreen) -> void:
	_screen = screen
	var left := _column(LEFT_WIDTH)
	screen.add_section(left, tr("SETTINGS_CROSSHAIR"))
	_shape = _choice(left, "SETTINGS_SHAPE", ["SETTINGS_SHAPE_CROSS", "SETTINGS_SHAPE_CROSS_DOT", "SETTINGS_SHAPE_CIRCLE",
			"SETTINGS_SHAPE_DOT"], LEFT_LABEL, "")
	_shape.picked.connect(func(i: int) -> void:
		_prefs().shape = i as HudPrefs.Shape
		_after(true))
	_colour = _swatches(left, "SETTINGS_COLOUR", "SETTINGS_COLOUR_NOTE")
	_colour.picked.connect(func(i: int) -> void:
		_prefs().colour = i
		_after(true))
	_size = _px_slider(left, "SETTINGS_SIZE", HudPrefs.SIZE_RANGE)
	_size.value_changed.connect(func(v: float) -> void:
		_prefs().size = v
		_after(false))
	_thickness = _px_slider(left, "SETTINGS_THICKNESS", HudPrefs.THICKNESS_RANGE)
	_thickness.value_changed.connect(func(v: float) -> void:
		_prefs().thickness = v
		_after(false))
	_gap = _px_slider(left, "SETTINGS_GAP", HudPrefs.GAP_RANGE)
	_gap.value_changed.connect(func(v: float) -> void:
		_prefs().gap = v
		_after(false))
	_opacity = _percent_slider(left, "SETTINGS_OPACITY", HudPrefs.OPACITY_RANGE, LEFT_LABEL)
	_opacity.value_changed.connect(func(v: float) -> void:
		_prefs().opacity = v / 100.0
		_after(false))
	_spread = _choice(left, "SETTINGS_SPREAD", ["SETTINGS_DYNAMIC", "SETTINGS_STATIC"], LEFT_LABEL,
			"SETTINGS_SPREAD_NOTE")
	_spread.picked.connect(func(i: int) -> void:
		_prefs().dynamic = i == 0
		_after(true))
	_outline = screen.add_check_row(left, "SETTINGS_OUTLINE", "SETTINGS_ON", "SETTINGS_OFF", LEFT_LABEL)
	_outline.toggled.connect(func(on: bool) -> void:
		_prefs().outline = on
		_after(true))
	screen.add_section(left, tr("SETTINGS_HIT_MARKER"))
	_marker = screen.add_check_row(left, "SETTINGS_HIT_MARKER", "SETTINGS_ON", "SETTINGS_OFF", LEFT_LABEL)
	_note(_marker.get_parent() as Control, "SETTINGS_HIT_MARKER_NOTE")
	_marker.toggled.connect(func(on: bool) -> void:
		_prefs().marker = on
		_after(true))
	_marker_colour = _swatches(left, "SETTINGS_COLOUR", "")
	_marker_colour.picked.connect(func(i: int) -> void:
		_prefs().marker_colour = i
		_after(true))
	_marker_size = _percent_slider(left, "SETTINGS_SIZE", HudPrefs.MARKER_SIZE_RANGE, LEFT_LABEL)
	_marker_size.value_changed.connect(func(v: float) -> void:
		_prefs().marker_size = v / 100.0
		_after(false))
	var right := _column(0.0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview = HudPreview.new()
	right.add_child(_preview)
	_follow_teams()
	_hud_size = _hud_size_row(right)
	screen.add_section(right, tr("SETTINGS_AMMO_AND_FEED"))
	_ammo = screen.add_check_row(right, "SETTINGS_AMMO_COUNTER", "SETTINGS_ON", "SETTINGS_OFF", RIGHT_LABEL)
	_note(_ammo.get_parent() as Control, "SETTINGS_AMMO_COUNTER_NOTE")
	_ammo.toggled.connect(func(on: bool) -> void:
		_prefs().ammo_counter = on
		_after(true))
	_corner = _choice(right, "SETTINGS_FEED_CORNER", ["SETTINGS_TOP_RIGHT", "SETTINGS_BOTTOM_LEFT"], RIGHT_LABEL, "")
	_corner.picked.connect(func(i: int) -> void:
		_prefs().feed_corner = i as HudPrefs.FeedCorner
		_after(true))
	_lines = _choice(right, "SETTINGS_FEED_LINES", ["SETTINGS_FADE", "SETTINGS_KEEP"], RIGHT_LABEL, "")
	_screen.explain(_lines.get_parent() as Control, tr("SETTINGS_FEED_LINES_NOTE") % [
			roundi(HudConfig.new().feed_line_time), HudPrefs.KEPT_LINES])
	_lines.picked.connect(func(i: int) -> void:
		_prefs().feed_lines = i as HudPrefs.FeedLines
		_after(true))
	_callouts = screen.add_check_row(right, "SETTINGS_CALLOUTS", "SETTINGS_ON", "SETTINGS_OFF", RIGHT_LABEL)
	_note(_callouts.get_parent() as Control, "SETTINGS_CALLOUTS_NOTE")
	_callouts.toggled.connect(func(on: bool) -> void:
		_prefs().callouts = on
		_after(true))
	_pings = screen.add_check_row(right, "SETTINGS_PING_MARKERS", "SETTINGS_ON", "SETTINGS_OFF", RIGHT_LABEL)
	_note(_pings.get_parent() as Control, "SETTINGS_PING_MARKERS_NOTE")
	_pings.toggled.connect(func(on: bool) -> void:
		_prefs().ping_markers = on
		_after(true))
	_mag = screen.add_check_row(right, "SETTINGS_MAG_HAND_OFF", "SETTINGS_ON", "SETTINGS_OFF", RIGHT_LABEL)
	_note(_mag.get_parent() as Control, "SETTINGS_MAG_HAND_OFF_NOTE")
	_mag.toggled.connect(func(on: bool) -> void:
		_prefs().mag_hand_off = on
		_after(true))
	screen.add_section(right, tr("SETTINGS_PANELS"))
	_panels = _percent_slider(right, "SETTINGS_HUD_OPACITY", HudPrefs.PANEL_OPACITY_RANGE, RIGHT_LABEL)
	_note(_panels.get_parent() as Control, "SETTINGS_HUD_OPACITY_NOTE")
	_panels.value_changed.connect(func(v: float) -> void:
		_prefs().panel_opacity = v / 100.0
		_after(false))
	_what_got_you = _choice(right, "SETTINGS_WHAT_GOT_YOU", ["SETTINGS_AUTO", "SETTINGS_ON", "SETTINGS_OFF"],
			RIGHT_LABEL, "")
	# what Auto means would surprise: said beside it
	_screen.add_note(_what_got_you.get_parent() as Control, tr("SETTINGS_WHAT_GOT_YOU_NOTE"))
	_what_got_you.picked.connect(func(i: int) -> void:
		_screen.settings.what_got_you = i as Settings.WhatGotYou
		changed.emit(true))
	_build_minimap(right)


## Shows the settings as they are now.
func refresh() -> void:
	var p := _prefs()
	_shape.put(p.shape)
	_colour.put(p.colour)
	_screen.set_slider(_size, p.size)
	_screen.set_slider(_thickness, p.thickness)
	_screen.set_slider(_gap, p.gap)
	_screen.set_slider(_opacity, p.opacity * 100.0)
	_spread.put(0 if p.dynamic else 1)
	_screen.set_check(_outline, p.outline)
	_screen.set_check(_marker, p.marker)
	_marker_colour.put(p.marker_colour)
	_screen.set_slider(_marker_size, p.marker_size * 100.0)
	_screen.set_check(_ammo, p.ammo_counter)
	_corner.put(p.feed_corner)
	_lines.put(p.feed_lines)
	_screen.set_check(_callouts, p.callouts)
	_screen.set_check(_pings, p.ping_markers)
	_screen.set_check(_mag, p.mag_hand_off)
	_screen.set_slider(_panels, p.panel_opacity * 100.0)
	_screen.set_slider(_hud_size, p.hud_size * 100.0)
	_what_got_you.put(_screen.settings.what_got_you)
	_turn.put(p.minimap_turn)
	_show_turn(p.minimap_turn)
	_screen.set_slider(_zoom, p.minimap_zoom * 100.0)
	_zoom_thumbs(p.minimap_zoom)
	_preview.show_prefs(p)
	_follow_teams()


func preview() -> HudPreview:
	return _preview


func hud_size() -> HSlider:
	return _hud_size


func _prefs() -> HudPrefs:
	return _screen.settings.hud


## HUD size in percent (AccessibilityConfig's range and step), marked at 100 % under its slider, with its note.
func _hud_size_row(column: Control) -> HSlider:
	var lo := roundf(AccessibilityConfig.HUD_SIZE_RANGE.x * 100.0)
	var hi := roundf(AccessibilityConfig.HUD_SIZE_RANGE.y * 100.0)
	var step := roundf(AccessibilityConfig.HUD_SIZE_STEP * 100.0)
	var slider := _narrow(_screen.add_slider_row(column, "SETTINGS_HUD_SIZE", lo, hi, step, PERCENT, RIGHT_LABEL))
	slider.add_child(Mark.new(AccessibilityConfig.HUD_SIZE_DEFAULT * 100.0, PERCENT))
	_screen.explain(slider.get_parent() as Control, tr("SETTINGS_HUD_SIZE_NOTE") % [lo, hi])
	slider.value_changed.connect(func(v: float) -> void:
		_prefs().hud_size = v / 100.0
		_after(false))
	return slider


## The minimap's section: Turn (Rotating or Fixed) with a note under it, and the two samples beside them.
func _build_minimap(right: VBoxContainer) -> void:
	# the section's gap goes above the whole block: the samples start level with the heading
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, SettingsScreen.SECTION_GAP)
	right.add_child(gap)
	var block := HBoxContainer.new()
	right.add_child(block)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", SettingsScreen.ROW_GAP)
	block.add_child(rows)
	_screen.add_section(rows, tr("SETTINGS_MINIMAP"))
	_turn = _choice(rows, "SETTINGS_MINIMAP_TURN", ["SETTINGS_MINIMAP_ROTATING", "SETTINGS_MINIMAP_FIXED"], RIGHT_LABEL,
			"")
	_turn.picked.connect(func(i: int) -> void:
		_prefs().minimap_turn = i as HudPrefs.MinimapTurn
		_show_turn(_prefs().minimap_turn)
		changed.emit(true))
	_screen.explain(_turn.get_parent() as Control, "%s %s %s %s" % [tr("SETTINGS_MINIMAP_ROTATING_LEAD"),
			tr("SETTINGS_MINIMAP_ROTATING_NOTE"), tr("SETTINGS_MINIMAP_FIXED_LEAD"), tr("SETTINGS_MINIMAP_FIXED_NOTE")])
	# Zoom (MC1): in percent, marked at 100 % under the slider; the samples follow it.
	var zoom_step := roundf(HudPrefs.MINIMAP_ZOOM_STEP * 100.0)
	_zoom = _narrow(_screen.add_slider_row(rows, "SETTINGS_MINIMAP_ZOOM", HudPrefs.MINIMAP_ZOOM_RANGE.x * 100.0,
			HudPrefs.MINIMAP_ZOOM_RANGE.y * 100.0, zoom_step, PERCENT, RIGHT_LABEL))
	_zoom.add_child(Mark.new(100.0, PERCENT))
	_note(_zoom.get_parent() as Control, "SETTINGS_MINIMAP_ZOOM_NOTE")
	_zoom.value_changed.connect(func(v: float) -> void:
		_prefs().minimap_zoom = v / 100.0
		_zoom_thumbs(_prefs().minimap_zoom)
		_after(false))
	_thumbs_row = HBoxContainer.new()
	_thumbs_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_thumbs_row.add_theme_constant_override("separation", THUMB_GAP)
	block.add_child(_thumbs_row)
	for key: String in ["SETTINGS_MINIMAP_ROTATING", "SETTINGS_MINIMAP_FIXED"]:
		var thumb := Thumb.new(HudStyle.caps(key))
		_thumbs_row.add_child(thumb)
		_thumbs.append(thumb)
	# The samples draw Depot's field, built once the first time the tab is seen; the team colours follow a set picked
	# on the Accessibility tab when this one shows again.
	_thumbs_row.visibility_changed.connect(_on_shown)


func minimap_zoom() -> HSlider:
	return _zoom


## The samples drawn at the minimap's zoom `zoom`.
func _zoom_thumbs(zoom: float) -> void:
	for thumb in _thumbs:
		thumb.set_zoom(zoom)


## Marks the sample of the turn chosen.
func _show_turn(turn: HudPrefs.MinimapTurn) -> void:
	for i in _thumbs.size():
		_thumbs[i].mark(i == turn)


func _on_shown() -> void:
	_follow_teams()
	_build_thumbs()


## Takes the saved team colour set's HUD part into the preview and the samples when the set changed.
func _follow_teams() -> void:
	var picked := _screen.settings.team_colours
	if _teams != null and picked == _teams_set:
		return
	_teams_set = picked
	_teams = TeamColours.resolve(picked, false).hud
	_preview.show_teams(_teams)
	for thumb in _thumbs:
		if thumb.built():
			thumb.paint(_teams.colours[0], _teams.colours[1])


## The first time the samples are on screen: Depot's field once, the same sample character and teammates in both.
func _build_thumbs() -> void:
	if not _thumbs_row.is_visible_in_tree() or _thumbs[0].built():
		return
	var cfg := MinimapConfig.new()
	var map := MapData.load_map(THUMB_MAP, MapStyle.new(), 1)
	if not map.ok():
		return
	var field := MinimapField.build(map, cfg)
	var textures := HudMinimap.textures_of(field)
	for i in _thumbs.size():
		_thumbs[i].build(cfg, textures, field, _teams.colours[0], _teams.colours[1], i == 0)
	_zoom_thumbs(_prefs().minimap_zoom)


## A choice landed: the preview follows and the screen saves it.
func _after(immediate: bool) -> void:
	_preview.show_prefs(_prefs())
	_preview.queue_redraw()
	changed.emit(immediate)


func _column(width: float) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.custom_minimum_size.x = width
	c.add_theme_constant_override("separation", SettingsScreen.ROW_GAP)
	add_child(c)
	return c


## A row of buttons (`keys` translated) with a note after it (`note_key`, "" for none).
func _choice(column: Control, label_key: String, keys: Array[String], width: float, note_key: String) -> MenuChoice:
	var row := _screen.add_row(column, label_key, width)
	var words := PackedStringArray()
	for key in keys:
		words.append(tr(key))
	var choice := MenuChoice.new(words)
	choice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(choice)
	if note_key != "":
		_note(row, note_key)
	return choice


func _swatches(column: Control, label_key: String, note_key: String) -> MenuSwatches:
	var row := _screen.add_row(column, label_key, LEFT_LABEL)
	var swatches := MenuSwatches.new(HudPrefs.COLOURS)
	swatches.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatches)
	if note_key != "":
		_note(row, note_key)
	return swatches


func _px_slider(column: Control, label_key: String, bounds: Vector2) -> HSlider:
	return _narrow(_screen.add_slider_row(column, label_key, bounds.x, bounds.y, 1.0, PX, LEFT_LABEL))


## A slider in percent over `bounds` (shares of 1).
func _percent_slider(column: Control, label_key: String, bounds: Vector2, width: float) -> HSlider:
	return _narrow(_screen.add_slider_row(column, label_key, bounds.x * 100.0, bounds.y * 100.0,
			SettingsScreen.PERCENT_STEP, PERCENT, width))


## This page's sliders are shorter than the other tabs', so a note fits beside them.
static func _narrow(slider: HSlider) -> HSlider:
	slider.custom_minimum_size.x = SLIDER_WIDTH
	return slider


## A row's explanation (`key` translated): its tooltip, not words on the page (UI1: only what a player would be stuck
## without is written out).
func _note(row: Control, key: String) -> void:
	_screen.explain(row, tr(key))


## One sample of the minimap's turn: the panel as it shows with that turn, framed in yellow while it is the one chosen,
## its name in a tag at the bottom left.
class Thumb:
	extends Control

	const SIDE := 104.0
	const OUTLINE := 2.0
	const TAG_SIZE := 11
	const TAG_SPACING := 0.1
	const TAG_PAD := Vector2i(7, 2)
	const TAG_BACKING := 0.9

	var _on: bool = false
	var _frame: Control = null
	var _view: HudMinimap.View = null
	var _cfg: MinimapConfig = null
	var _rotating: bool = false
	var _zoom: float = 1.0
	var _team: Color = Color.WHITE
	var _enemy: Color = Color.WHITE
	var _tag: Label = null
	var _built: bool = false

	func _init(words: String) -> void:
		var room := (OUTLINE + OUTLINE) * 2.0 + SIDE
		custom_minimum_size = Vector2(room, room)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame = Control.new()
		_frame.position = Vector2.ONE * (OUTLINE + OUTLINE)
		_frame.size = Vector2.ONE * SIDE
		_frame.clip_contents = true
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_frame)
		_tag = HudStyle.label(_frame, TAG_SIZE, 800, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, TAG_SPACING)
		_tag.text = words
		_tag.add_theme_stylebox_override("normal", HudStyle.panel_box(TAG_BACKING, TAG_PAD.x, TAG_PAD.y))
		_tag.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE)
		_tag.grow_vertical = Control.GROW_DIRECTION_BEGIN

	func built() -> bool:
		return _built

	## Draws the sample on `field`'s `textures`: you and the teammates (`team`'s colour), the field turning with you or not.
	func build(cfg: MinimapConfig, textures: Array[Texture2D], field: MinimapField, team: Color, enemy: Color,
			rotating: bool) -> void:
		_built = true
		_cfg = cfg
		_rotating = rotating
		_view = HudMinimap.View.new()
		var inner := cfg.size - cfg.ring * 2.0
		_view.size = Vector2.ONE * inner
		_view.scale = Vector2.ONE * (SIDE / inner)
		_view.setup(cfg, textures, field.scale, field.origin, THUMB_TEAM.size())
		_frame.add_child(_view)
		_frame.move_child(_view, 0)
		paint(team, enemy)

	## Draws the sample at the minimap's zoom `zoom` (HudPrefs.minimap_zoom), once built.
	func set_zoom(zoom: float) -> void:
		if is_equal_approx(zoom, _zoom):
			return
		_zoom = zoom
		if _built:
			paint(_team, _enemy)

	## Draws the sample's scene with you and your teammates in `team`'s colour, `enemy` the other team's.
	func paint(team: Color, enemy: Color) -> void:
		_team = team
		_enemy = enemy
		_view.begin(THUMB_AT, 0, -deg_to_rad(THUMB_HEADING), _rotating, team, enemy, _zoom)
		for i in THUMB_TEAM.size():
			_view.add_dot(THUMB_TEAM[i], _cfg.out_colour if i == 1 else team, 0)
		_view.queue_redraw()

	func mark(on: bool) -> void:
		_on = on
		_tag.add_theme_color_override("font_color", GameTheme.TEXT if on else GameTheme.MUTED)
		queue_redraw()

	func _draw() -> void:
		var line := Rect2(Vector2.ONE * (OUTLINE + OUTLINE - 1.0), Vector2.ONE * (SIDE + 2.0))
		draw_rect(line, GameTheme.LINE, false, 1.0)
		if not _on:
			return
		var side := custom_minimum_size.x
		var inner := side - OUTLINE * 2.0
		draw_rect(Rect2(0.0, 0.0, side, OUTLINE), GameTheme.YELLOW)
		draw_rect(Rect2(0.0, side - OUTLINE, side, OUTLINE), GameTheme.YELLOW)
		draw_rect(Rect2(0.0, OUTLINE, OUTLINE, inner), GameTheme.YELLOW)
		draw_rect(Rect2(side - OUTLINE, OUTLINE, OUTLINE, inner), GameTheme.YELLOW)


## A mark on a slider's track at one value, its figure under it (the concept's 100 % tick under HUD size).
class Mark:
	extends Control

	const TICK := Vector2(2.0, 20.0)
	const FIGURE_SIZE := 11
	const FIGURE_DROP := 4.0

	var _value: float = 0.0
	var _figure: String = ""

	func _init(value: float, fmt: String) -> void:
		_value = value
		_figure = fmt % value
		name = "Mark"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true # under the grabber
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	## Where the grabber's middle sits at the value (px across the slider).
	func at() -> float:
		var slider := get_parent() as Range
		if slider == null or slider.max_value <= slider.min_value:
			return 0.0
		var grab := float(get_theme_icon(&"grabber", &"HSlider").get_width())
		var share := (_value - slider.min_value) / (slider.max_value - slider.min_value)
		return grab * 0.5 + share * (size.x - grab)

	func _draw() -> void:
		var x := at()
		var mid := size.y * 0.5
		draw_rect(Rect2(x - TICK.x * 0.5, mid - TICK.y * 0.5, TICK.x, TICK.y), GameTheme.MUTED)
		var font := GameTheme.font(700)
		var wide := font.get_string_size(_figure, HORIZONTAL_ALIGNMENT_LEFT, -1, FIGURE_SIZE).x
		draw_string(font, Vector2(x - wide * 0.5, mid + TICK.y * 0.5 + FIGURE_DROP + font.get_ascent(FIGURE_SIZE)), _figure,
				HORIZONTAL_ALIGNMENT_LEFT, -1, FIGURE_SIZE, GameTheme.DIM)
