class_name SettingsGraphicsPage
extends HBoxContainer
## The settings' Graphics tab (concept `settings-graphics.png`; the rows are data/graphics.md's, through
## GraphicsTable.shared()): on the left the preset (Low to Ultra, or Custom) with "For your card" on the card's pick and
## a line on the one in force, Resolution (render scale, upscaler) and Edges (edge and temporal smoothing), then Your
## system; on the right Shadows and Light and detail, Start-up (the renderer the next start asks for: Auto or
## Compatibility, written to RendererOverride's file at once) and Reset to For your card. Each row shows what it takes
## from the graphics card as squares (the table's Cost); a choice the renderer in use can't draw is greyed, and the row
## shows the one drawn instead (on the simpler renderer Low's FSR 1 shows as bilinear). Changing a row makes the choice
## Custom on the preset you were on, its changed rows marked with a dot. Every change is drawn at once
## (SettingsApply.apply_graphics) and `changed` asks the screen to save it; a slider applies when it is let go, since a
## new render size or shadow map can hitch.

## A choice landed: saved now (`immediate`, a click) or a moment after a slider stops.
signal changed(immediate: bool)

## The columns' widths (the right one takes the rest), the labels' widths and the sliders' (px).
const LEFT_WIDTH := 860.0
const COLUMN_GAP := 48
const LEFT_LABEL := 230.0
const RIGHT_LABEL := 230.0
const SLIDER_WIDTH := 260.0
## The notes' text size and the space between the blocks of a column (px).
const NOTE_SIZE := GameTheme.NOTE_SIZE
const BLOCK_GAP := 12.0
## The For your card tag's own room above the preset buttons (px): its height and the gap under it.
const TAG_GAP := 3.0
## A greyed row's or choice's opacity.
const DIM_ALPHA := 0.45
## The sliders' figures.
const PERCENT := "%d%%"
const METRES := "%d m"
## The rows in each column, by section (their order on the page).
const LEFT_SECTIONS: Dictionary[String, Array] = {
	"GRAPHICS_RESOLUTION": [GraphicsQuality.RENDER_SCALE, GraphicsQuality.UPSCALER],
	"GRAPHICS_EDGES": [GraphicsQuality.EDGE_SMOOTHING, GraphicsQuality.TEMPORAL_SMOOTHING],
	"GRAPHICS_EFFECTS": [GraphicsQuality.GLOBAL_ILLUMINATION, GraphicsQuality.REFLECTIONS, GraphicsQuality.GLOW,
			GraphicsQuality.VOLUMETRIC_FOG],
}
const RIGHT_SECTIONS: Dictionary[String, Array] = {
	"GRAPHICS_SHADOWS": [GraphicsQuality.SUN_SHADOWS, GraphicsQuality.SHADOW_DETAIL, GraphicsQuality.SHADOW_SOFTNESS,
			GraphicsQuality.SHADOW_RANGE],
	"GRAPHICS_LIGHT_AND_DETAIL": [GraphicsQuality.AMBIENT_OCCLUSION, GraphicsQuality.BAKED_LIGHT,
			GraphicsQuality.TEXTURE_FILTERING, GraphicsQuality.MESH_DETAIL, GraphicsQuality.WIND_DUST],
}
## A range row's figure, and the note beside a row (none for the others).
const RANGE_FORMATS: Dictionary[StringName, String] = {
	GraphicsQuality.RENDER_SCALE: PERCENT,
	GraphicsQuality.SHADOW_RANGE: METRES,
	GraphicsQuality.WIND_DUST: PERCENT,
}
## A row's explanation, its tooltip (UI1: no paragraph beside a row a player isn't stuck without).
const NOTES: Dictionary[StringName, String] = {
	GraphicsQuality.UPSCALER: "GRAPHICS_UPSCALER_NOTE",
	GraphicsQuality.TEMPORAL_SMOOTHING: "GRAPHICS_TEMPORAL_SMOOTHING_NOTE",
	GraphicsQuality.GLOBAL_ILLUMINATION: "GRAPHICS_GLOBAL_ILLUMINATION_NOTE",
}
## The two choices a row shown as a switch offers, off then on.
const SWITCH_CHOICES: Array = ["off", "on"]
## The words for each choice name ("msaa_2x": GRAPHICS_CHOICE_MSAA_2X), each preset (GRAPHICS_PRESET_HIGH) and its line.
const CHOICE_KEY := "GRAPHICS_CHOICE_%s"
const PRESET_KEY := "GRAPHICS_PRESET_%s"
const BLURB_KEY := "GRAPHICS_BLURB_%s"
## The renderer's and the card's type's words, and the drivers' names (not translated).
const RENDERER_KEYS: Dictionary[String, String] = {
	"forward_plus": "GRAPHICS_FORWARD_PLUS",
	"mobile": "GRAPHICS_MOBILE",
	"gl_compatibility": "GRAPHICS_COMPATIBILITY",
}
const CARD_TYPE_KEYS: Dictionary[int, String] = {
	RenderingDevice.DEVICE_TYPE_OTHER: "GRAPHICS_TYPE_OTHER",
	RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU: "GRAPHICS_TYPE_INTEGRATED",
	RenderingDevice.DEVICE_TYPE_DISCRETE_GPU: "GRAPHICS_TYPE_DISCRETE",
	RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU: "GRAPHICS_TYPE_VIRTUAL",
	RenderingDevice.DEVICE_TYPE_CPU: "GRAPHICS_TYPE_CPU",
}
const DRIVER_NAMES: Dictionary[String, String] = {
	"vulkan": "Vulkan",
	"d3d12": "Direct3D 12",
	"metal": "Metal",
	"opengl3": "OpenGL 3",
	"opengl3_es": "OpenGL ES 3",
	"opengl3_angle": "OpenGL 3 (ANGLE)",
}
## The Renderer row's choices, in Settings.Renderer's order.
const RENDERER_CHOICES: Array[String] = ["GRAPHICS_CHOICE_AUTO", "GRAPHICS_COMPATIBILITY"]
## A screen whose refresh rate the system doesn't give reports this or less.
const NO_RATE := 0.0
## The Your system box's inner margins, its key column and its type sizes (px).
const SYSTEM_PAD := Vector2i(16, 10)
const SYSTEM_KEY_WIDTH := 140.0
const SYSTEM_TITLE_SIZE := 12
const SYSTEM_SIZE := 14
const SYSTEM_SPACING := 0.12

## The card and renderer the tab shows and picks for: this machine's (GraphicsApply.machine) unless a test gives one.
var probe: GraphicsPick.Probe = null
## The file the Renderer row writes (tests give their own).
var renderer_path: String = RendererOverride.PATH

var _screen: SettingsScreen = null
var _table: GraphicsTable = null
var _preset: MenuChoice = null
var _tag: Label = null
## The tag's room above the preset buttons.
var _tag_room: Control = null
## The preset's story (which preset is on and why), the preset row's tooltip: no line of prose under it (UI1).
var _story: String = ""
var _preset_row: HBoxContainer = null
var _rows: Dictionary[StringName, Line] = {}
var _reset: Button = null
var _card: Label = null
var _renderer: Label = null
var _display: Label = null
var _renderer_choice: MenuChoice = null


func _init() -> void:
	name = "SettingsGraphicsPage"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", COLUMN_GAP)


## Builds the tab with `screen`'s rows (SettingsScreen.add_row and the rest), editing its settings.
func build(screen: SettingsScreen) -> void:
	_screen = screen
	_table = GraphicsTable.shared()
	if probe == null:
		probe = GraphicsApply.machine()
	var left := _column(LEFT_WIDTH)
	screen.add_section(left, tr("GRAPHICS_QUALITY"))
	_build_preset(left)
	_build_sections(left, LEFT_SECTIONS, LEFT_LABEL)
	_build_system(left)
	var right := _column(0.0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_sections(right, RIGHT_SECTIONS, RIGHT_LABEL)
	_build_renderer(right)
	_build_reset(right)


## Shows the settings as they are now: the preset lit, its line, each row's value and mark, and the system. Allocates:
## on opening and after a change only.
func refresh() -> void:
	var s := _screen.settings
	var values := s.graphics_in_force(probe.preset, _table)
	var on := _lit_preset(s)
	_preset.put(_preset_index(on))
	# the card's pick may have stepped down this run: the tag follows it (its anchors and lift are local)
	_place_tag()
	_show_blurb(s, values)
	var marked := s.graphics_forced == &"" and s.graphics_choice == GraphicsQuality.CUSTOM
	var base := _table.preset(s.graphics_base)
	# the choice drawn: one this renderer can't draw shows as the one it draws instead
	var drawn := GraphicsApply.drawable(values, probe.rendering_method, _table)
	for id: StringName in _rows:
		var line := _rows[id]
		line.show_level(drawn.level(id), _screen)
		line.mark(marked and values.level(id) != base.level(id))
	# The upscaler only works below full size.
	_rows[GraphicsQuality.UPSCALER].dim(values.render_scale >= GraphicsApply.PERCENT)
	_show_draws(values.render_scale)
	_reset.text = (tr("GRAPHICS_RESET") % tr(PRESET_KEY % String(probe.preset).to_upper())).to_upper()
	_show_system()
	_renderer_choice.put(int(s.renderer))


## Closed or hidden mid-drag (Esc, or another tab) a slider's drag_ended never comes: apply what each held slider
## holds and stop waiting for the release, or the value is lost and later key steps ignored (QA). The screen calls it
## on close.
func let_go() -> void:
	for id: StringName in _rows:
		var held: Line = _rows[id]
		if held.dragging:
			held.dragging = false
			_on_level(id, roundi(held.slider.value))


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		let_go()


## The row `id`'s line (tests read its controls).
func line(id: StringName) -> Line:
	return _rows[id]


func preset_choice() -> MenuChoice:
	return _preset


## The preset's state in words ("Custom: High with 2 changes."), the first line of the preset row's tooltip.
func blurb() -> String:
	return _story


func reset_button() -> Button:
	return _reset


## The For your card tag's button (the pick's preset).
func tagged() -> Button:
	return _preset.button(_preset_index(probe.preset))


func renderer_choice() -> MenuChoice:
	return _renderer_choice


func system_lines() -> PackedStringArray:
	return PackedStringArray([_card.text, _renderer.text, _display.text])


# --- Building ---

func _column(width: float) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.custom_minimum_size.x = width
	c.add_theme_constant_override("separation", SettingsScreen.ROW_GAP)
	add_child(c)
	return c


## Preset: Low to Ultra and Custom with the For your card tag in its own room above the pick's (never over a button:
## UI1); what is on and why is the row's tooltip.
func _build_preset(column: VBoxContainer) -> void:
	var row := _screen.add_row(column, "GRAPHICS_PRESET", LEFT_LABEL)
	_preset_row = row
	# the name sits level with the buttons, under the tag's room
	var label := row.get_child(0) as Label
	label.size_flags_vertical = Control.SIZE_SHRINK_END
	label.custom_minimum_size.y = GameTheme.CONTROL_HEIGHT
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	row.add_child(stack)
	_tag_room = Control.new()
	_tag_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_tag_room)
	var words := PackedStringArray()
	for p in GraphicsTable.PRESETS:
		words.append(tr(PRESET_KEY % String(p).to_upper()))
	words.append(tr(PRESET_KEY % String(GraphicsQuality.CUSTOM).to_upper()))
	_preset = MenuChoice.new(words)
	stack.add_child(_preset)
	_preset.picked.connect(_on_preset)
	_tag = HudStyle.label(_tag_room, Line.TAG_SIZE, 800, GameTheme.YELLOW_INK, HORIZONTAL_ALIGNMENT_CENTER,
			Line.TAG_SPACING)
	_tag.text = tr("GRAPHICS_FOR_YOUR_CARD").to_upper()
	_tag.add_theme_stylebox_override("normal", GameTheme.box(GameTheme.YELLOW, Color(0.0, 0.0, 0.0, 0.0), Line.TAG_PAD.x,
			Line.TAG_PAD.y))
	_tag_room.custom_minimum_size.y = _tag.get_combined_minimum_size().y + TAG_GAP
	# the tag follows its button wherever the row lays it out
	_preset.sort_children.connect(_place_tag)


## Puts the tag centred over the card's pick, in its room above the buttons.
func _place_tag() -> void:
	if _tag == null or _preset == null:
		return
	var button := tagged()
	var want := _tag.get_combined_minimum_size()
	_tag.size = want
	_tag.position = Vector2(button.position.x + (button.size.x - want.x) * 0.5, 0.0)


func _build_sections(column: VBoxContainer, sections: Dictionary[String, Array], width: float) -> void:
	var first := true
	for key: String in sections:
		_screen.add_section(column, tr(key))
		if first:
			_cost_heading(column)
			first = false
		for id: StringName in sections[key]:
			_rows[id] = _build_row(column, id, width)


## GPU COST at the right of the column's first section heading, over the squares that end each row under it (UI1
## round 3: the squares read as a column, not a riddle); the longer words are its tooltip and the squares'.
func _cost_heading(column: VBoxContainer) -> void:
	var heading := column.get_child(column.get_child_count() - 1) as Control
	column.remove_child(heading)
	var row := HBoxContainer.new()
	row.name = "CostHeading"
	column.add_child(row)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	var cost := SettingsScreen.section_label(tr("GRAPHICS_COST_HEAD"))
	cost.name = "GpuCost"
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.tooltip_text = tr("GRAPHICS_COST_TIP")
	cost.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(cost)


## One row: its control (a switch, a slider or a row of choices) from the table, a note, its cost squares.
func _build_row(column: VBoxContainer, id: StringName, width: float) -> Line:
	var r := _table.row(id)
	var line: Line = null
	if GraphicsQuality.is_range(id):
		var slider := _screen.add_slider_row(column, r.label, r.lo, r.hi, 1.0, RANGE_FORMATS[id], width)
		slider.custom_minimum_size.x = SLIDER_WIDTH
		line = Line.new(id, slider.get_parent() as HBoxContainer)
		line.slider = slider
		slider.drag_started.connect(func() -> void: line.dragging = true)
		slider.drag_ended.connect(func(_moved: bool) -> void:
			line.dragging = false
			_on_level(id, roundi(slider.value)))
		slider.value_changed.connect(func(v: float) -> void:
			if id == GraphicsQuality.RENDER_SCALE:
				_show_draws(roundi(v))
			if not line.dragging:
				_on_level(id, roundi(v)))
	elif GraphicsQuality.CHOICES[id] == SWITCH_CHOICES:
		var check := _screen.add_check_row(column, r.label, "SETTINGS_ON", "SETTINGS_OFF", width)
		line = Line.new(id, check.get_parent() as HBoxContainer)
		line.check = check
		check.toggled.connect(func(on: bool) -> void: _on_level(id, int(on)))
	else:
		line = Line.new(id, _screen.add_row(column, r.label, width))
		var words := PackedStringArray()
		for choice_name in r.choices:
			line.levels.append(GraphicsQuality.CHOICES[id].find(choice_name))
			words.append(tr(CHOICE_KEY % choice_name.to_upper()))
		line.choice = MenuChoice.new(words)
		line.row.add_child(line.choice)
		line.choice.picked.connect(func(i: int) -> void: _on_level(id, line.levels[i]))
	if NOTES.has(id):
		line.row.tooltip_text = tr(NOTES[id])
	# the room that puts the squares at the column's right edge
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.row.add_child(gap)
	line.row.add_child(CostSquares.new(r.cost, tr("GRAPHICS_COST_TIP")))
	var simpler := probe.rendering_method == GraphicsPick.COMPATIBILITY
	line.grey(_table, probe.rendering_method, tr("GRAPHICS_NOT_WITH_SIMPLER" if simpler else "GRAPHICS_NOT_ON_RENDERER"))
	return line


## Your system: the card and its type, the renderer and its driver, the screen's size and rate.
func _build_system(column: VBoxContainer) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = BLOCK_GAP
	column.add_child(gap)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", GameTheme.box(GameTheme.CARD, GameTheme.LINE, SYSTEM_PAD.x, SYSTEM_PAD.y))
	column.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := HudStyle.label(box, SYSTEM_TITLE_SIZE, 800, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, SYSTEM_SPACING)
	title.text = tr("GRAPHICS_YOUR_SYSTEM").to_upper()
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	_card = _system_row(grid, "GRAPHICS_CARD")
	_renderer = _system_row(grid, "GRAPHICS_RENDERER")
	_display = _system_row(grid, "GRAPHICS_SCREEN")


func _system_row(grid: GridContainer, key: String) -> Label:
	var k := _quiet_label(grid, SYSTEM_SIZE)
	k.text = tr(key)
	k.custom_minimum_size.x = SYSTEM_KEY_WIDTH
	var v := HudStyle.label(grid, SYSTEM_SIZE, 600, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	return v


## Start-up: the renderer the next start asks for.
func _build_renderer(column: VBoxContainer) -> void:
	_screen.add_section(column, tr("GRAPHICS_START_UP"))
	var row := _screen.add_row(column, "GRAPHICS_RENDERER_ROW", RIGHT_LABEL)
	var words := PackedStringArray()
	for key in RENDERER_CHOICES:
		words.append(tr(key))
	_renderer_choice = MenuChoice.new(words)
	_renderer_choice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_renderer_choice)
	_renderer_choice.picked.connect(_on_renderer)
	# that it waits for the next start is what surprises; the rest is the tooltip
	_note(row, "GRAPHICS_RENDERER_NEXT_START")
	row.tooltip_text = tr("GRAPHICS_RENDERER_NOTE")


func _build_reset(column: VBoxContainer) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = BLOCK_GAP
	column.add_child(gap)
	var row := HBoxContainer.new()
	column.add_child(row)
	row.add_theme_constant_override("separation", SettingsScreen.ROW_SEPARATION)
	_reset = Button.new()
	GameTheme.small_button(_reset, GameTheme.YELLOW)
	_reset.pressed.connect(_on_reset)
	row.add_child(_reset)


func _quiet_label(parent: Control, font_size: int) -> Label:
	var l := Label.new()
	GameTheme.note_label(l)
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


## A quiet note at the end of `row` (`key` translated).
func _note(row: Control, key: String) -> Label:
	var note := _quiet_label(row, NOTE_SIZE)
	note.text = tr(key)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return note


# --- Changes ---

func _on_preset(index: int) -> void:
	var choice := GraphicsQuality.CUSTOM
	if index < GraphicsTable.PRESETS.size():
		choice = GraphicsTable.PRESETS[index]
	if _screen.settings.choose_graphics(choice, probe.preset):
		_landed()


## A row moved to `level`: Custom on the preset you were on, unless it is already at that level.
func _on_level(id: StringName, level: int) -> void:
	var s := _screen.settings
	if s.graphics_in_force(probe.preset, _table).level(id) == level:
		return
	if s.change_graphics_row(id, _table.saved_value(id, level), probe.preset, _table):
		_landed()


## Back to the card's pick, which follows the card from then on.
func _on_reset() -> void:
	_screen.settings.choose_graphics(Settings.GRAPHICS_AUTOMATIC, probe.preset)
	_landed()


## A renderer picked: written for the next start and saved at once; nothing changes in this one.
func _on_renderer(index: int) -> void:
	var s := _screen.settings
	if index == int(s.renderer):
		return
	s.renderer = index as Settings.Renderer
	RendererOverride.put(s.renderer, renderer_path)
	changed.emit(true)
	refresh()


## A change landed: drawn at once, saved at once, and the tab shows it.
func _landed() -> void:
	SettingsApply.apply_graphics(_screen.settings)
	changed.emit(true)
	refresh()


# --- Showing ---

## The preset lit: the forced one, the card's pick while automatic, the one chosen, or Custom.
func _lit_preset(s: Settings) -> StringName:
	if s.graphics_forced != &"":
		return s.graphics_forced
	if s.graphics_choice == Settings.GRAPHICS_AUTOMATIC:
		return probe.preset
	return s.graphics_choice


func _preset_index(choice: StringName) -> int:
	var at := GraphicsTable.PRESETS.find(choice)
	return at if at >= 0 else GraphicsTable.PRESETS.size()


## The preset row's tooltip: its lead (the preset, Automatic, Custom or the launch option) and a few words, then the
## longer story. Allocates: on opening and after a change only.
func _show_blurb(s: Settings, values: GraphicsQuality) -> void:
	var lead := ""
	var body := ""
	var more := ""
	var on := s.graphics_preset_on(probe.preset)
	var on_name := tr(PRESET_KEY % String(on).to_upper())
	if s.graphics_forced != &"":
		lead = tr("GRAPHICS_LEAD_FORCED") % String(s.graphics_forced)
		body = tr("GRAPHICS_FORCED_SHORT") % on_name
		more = tr("GRAPHICS_FORCED") % on_name
	elif s.graphics_choice == GraphicsQuality.CUSTOM:
		lead = tr("GRAPHICS_LEAD") % tr(PRESET_KEY % String(GraphicsQuality.CUSTOM).to_upper())
		var count := GraphicsQuality.overrides(values, on, _table).size()
		if count == 0:
			body = tr("GRAPHICS_CUSTOM_NONE_SHORT") % on_name
		elif count == 1:
			body = tr("GRAPHICS_CUSTOM_ONE_SHORT") % on_name
		else:
			body = tr("GRAPHICS_CUSTOM_MANY_SHORT") % [on_name, count]
		more = tr("GRAPHICS_CUSTOM_RESET")
	elif s.graphics_choice == Settings.GRAPHICS_AUTOMATIC:
		lead = tr("GRAPHICS_LEAD_AUTOMATIC") % on_name
		body = tr("GRAPHICS_AUTOMATIC_SHORT")
		more = "%s %s" % [tr(BLURB_KEY % String(on).to_upper()), tr("GRAPHICS_AUTOMATIC_NOTE")]
	else:
		lead = tr("GRAPHICS_LEAD") % on_name
		body = tr("GRAPHICS_CHOSEN")
		more = tr(BLURB_KEY % String(on).to_upper())
	_story = "%s %s" % [lead, body]
	_tell(_preset_row, "%s\n%s %s" % [_story, more, tr("GRAPHICS_STUTTER")])


## Puts `text` as the tooltip of `row` and of every button and slider in it (they take the pointer, so the row's own
## tip would never show over them).
static func _tell(row: Control, text: String) -> void:
	row.tooltip_text = text
	for c: Node in row.find_children("*", "", true, false):
		if c is BaseButton or c is Range:
			(c as Control).tooltip_text = text


## The size the 3D view is drawn at, the window's at the render scale `percent`: the row's tooltip (UI1).
func _show_draws(percent: int) -> void:
	var window := Vector2(get_window().size) if is_inside_tree() else Vector2.ZERO
	var drawn := (window * percent / GraphicsApply.PERCENT).round()
	var line: Line = _rows.get(GraphicsQuality.RENDER_SCALE)
	if line != null and not line.shut:
		_tell(line.row, draws_text(drawn))


## "Draws 1920 × 1080." for the size `drawn` (tests read it).
func draws_text(drawn: Vector2) -> String:
	return tr("GRAPHICS_DRAWS") % [int(drawn.x), int(drawn.y)]


func _show_system() -> void:
	_card.text = card_words(probe)
	_renderer.text = renderer_words(probe)
	var at := DisplayServer.window_get_current_screen()
	var size := DisplayServer.screen_get_size(at)
	var rate := DisplayServer.screen_get_refresh_rate(at)
	if rate > NO_RATE:
		_display.text = tr("GRAPHICS_SCREEN_LINE") % [size.x, size.y, roundi(rate), at + 1]
	else:
		_display.text = tr("GRAPHICS_SCREEN_LINE_NO_RATE") % [size.x, size.y, at + 1]


## The card in words: its name ("Not reported" when the driver doesn't say) and type.
static func card_words(machine: GraphicsPick.Probe) -> String:
	var card: String = machine.adapter_name
	if card == "":
		card = TranslationServer.translate("GRAPHICS_UNKNOWN_CARD")
	var kind: String = CARD_TYPE_KEYS.get(machine.adapter_type, "GRAPHICS_TYPE_OTHER")
	return "%s · %s" % [card, TranslationServer.translate(kind)]


## The renderer in force and its driver in words ("Forward+ · Vulkan").
static func renderer_words(machine: GraphicsPick.Probe) -> String:
	var renderer: String = RENDERER_KEYS.get(machine.rendering_method, "")
	var words: String = TranslationServer.translate(renderer) if renderer != "" else machine.rendering_method
	return "%s · %s" % [words, DRIVER_NAMES.get(machine.driver, machine.driver)]


## One row of the tab: its label, its control (one of `choice`, `check` and `slider`) and its changed mark.
class Line:
	extends RefCounted
	## The For your card tag's look (the preset row's), and the changed mark's size and place left of the label (px).
	const TAG_SIZE := 10
	const TAG_SPACING := 0.1
	const TAG_PAD := Vector2i(5, 1)
	const MARK_RADIUS := 4.0
	const MARK_LEFT := 14.0

	var id: StringName = &""
	var row: HBoxContainer = null
	var choice: MenuChoice = null
	## The level of each of `choice`'s buttons.
	var levels: Array[int] = []
	var check: CheckButton = null
	var slider: HSlider = null
	## The slider is held: it applies when let go.
	var dragging: bool = false
	## The renderer can't draw the row at all: greyed whatever else.
	var shut: bool = false
	var _mark: Mark = null

	func _init(row_id: StringName, parent: HBoxContainer) -> void:
		id = row_id
		row = parent
		_mark = Mark.new()
		row.get_child(0).add_child(_mark)
		_mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_mark.visible = false

	## Shows `level` without sending a change.
	func show_level(level: int, screen: SettingsScreen) -> void:
		if choice != null:
			choice.put(levels.find(level))
		elif check != null:
			screen.set_check(check, level != 0)
		elif slider != null:
			screen.set_slider(slider, level)

	func mark(on: bool) -> void:
		_mark.visible = on

	func marked() -> bool:
		return _mark.visible

	## The whole row greyed (still usable), or not; a shut row stays greyed.
	func dim(on: bool) -> void:
		row.modulate.a = DIM_ALPHA if on or shut else 1.0

	func dimmed() -> bool:
		return row.modulate.a < 1.0

	## Each choice `rendering_method` can't draw greyed and shut, and a row it can't draw at all, with `why` as its tip.
	func grey(table: GraphicsTable, rendering_method: String, why: String) -> void:
		shut = not table.row(id).renderers.has(rendering_method)
		if choice != null:
			for i in levels.size():
				var b := choice.button(i)
				b.disabled = not table.can_draw(id, levels[i], rendering_method)
				b.tooltip_text = why if b.disabled else ""
		if check != null:
			check.disabled = shut
			check.tooltip_text = why if shut else ""
		if slider != null:
			slider.editable = not shut
			slider.tooltip_text = why if shut else ""
		dim(false)


## The yellow dot left of a changed row's label.
class Mark:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(Vector2(-Line.MARK_LEFT, size.y * 0.5), Line.MARK_RADIUS, GameTheme.YELLOW)


## What a row takes from the graphics card: three squares, as many filled as its cost, under the column's GPU COST.
class CostSquares:
	extends Control
	const SIDE := 9.0
	const GAP := 3.0
	const FILLED := Color("8a94a6")

	var _cost: int = 0
	var _word: String = ""

	## `word` explains the squares, their tooltip (no line of prose about them: UI1).
	func _init(cost: int, word: String) -> void:
		_cost = cost
		_word = word
		tooltip_text = word
		mouse_filter = Control.MOUSE_FILTER_PASS
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		custom_minimum_size = Vector2(GraphicsTable.MAX_COST * (SIDE + GAP) - GAP, SIDE * 2.0)

	func cost() -> int:
		return _cost

	func _draw() -> void:
		var mid := size.y * 0.5
		var x := size.x - GraphicsTable.MAX_COST * (SIDE + GAP) + GAP
		for i in GraphicsTable.MAX_COST:
			var square := Rect2(x + i * (SIDE + GAP), mid - SIDE * 0.5, SIDE, SIDE)
			draw_rect(square, FILLED if i < _cost else GameTheme.CARD_HI)
			draw_rect(square, FILLED if i < _cost else GameTheme.LINE, false, 1.0)
