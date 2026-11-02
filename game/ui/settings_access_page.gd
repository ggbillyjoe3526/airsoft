class_name SettingsAccessPage
extends HBoxContainer
## The settings' Accessibility tab (concept `settings-accessibility.png`; the browser game's Settings › Accessibility):
## on the left Team colours (Standard and High contrast as two cards, each with its figures' two colours and its blurb),
## Gauge patterns and Screen reader messages; on the right Sound cues (on or off, size, colour, the ring's sample and
## what each marker means) and Reduced motion (Follow system, Off or On, and what the system asks for). Every choice
## lands in the settings at once and `changed` asks the screen to save it. A section not built yet is greyed with LATER
## (`LATER`): the task that builds it takes it out of the list.

## A choice landed: saved now (`immediate`, a click) or a moment after a slider stops.
signal changed(immediate: bool)

## The tab's sections, as the concept lays them out.
enum Section { TEAM_COLOURS, GAUGE_PATTERNS, SCREEN_READER, SOUND_CUES, REDUCED_MOTION }

## The sections still to build, greyed with LATER and not clickable: none now.
const LATER: Array[Section] = []
## The columns' widths (the right one takes the rest), the labels' widths and the slider's (px).
const LEFT_WIDTH := 860.0
const COLUMN_GAP := 48
const LEFT_LABEL := 230.0
const RIGHT_LABEL := 230.0
const SLIDER_WIDTH := 300.0
## A note beside a row or under a section: its size and the space before it (px); the room between a heading and its
## LATER tag.
const NOTE_SIZE := GameTheme.NOTE_SIZE
const TAG_GAP := 14
## The colour set cards: the room between them, their inner margins, their title's size, the swatches' height, their
## words' size and inner margin, and the gap between the two swatches (px).
const CARD_GAP := 16
const CARD_PAD := Vector2i(14, 12)
const CARD_TITLE_SIZE := 18
const CARD_ROWS_GAP := 10
const SWATCH_HEIGHT := 44.0
const SWATCH_SIZE := 13
const SWATCH_PAD := 12
const SWATCH_GAP := 8
## The sets' names, their blurbs' bold leads and the rest, in TeamColours.Set's order.
const SET_KEYS: Array[String] = ["SETTINGS_SET_STANDARD", "SETTINGS_SET_HIGH_CONTRAST"]
const SET_LEADS: Array[String] = ["SETTINGS_SET_STANDARD_LEAD", "SETTINGS_SET_HIGH_CONTRAST_LEAD"]
const SET_NOTES: Array[String] = ["SETTINGS_SET_STANDARD_NOTE", "SETTINGS_SET_HIGH_CONTRAST_NOTE"]
## Reduced motion's choices, in Settings.ReducedMotion's order.
const MOTION_KEYS: Array[String] = ["SETTINGS_FOLLOW_SYSTEM", "SETTINGS_OFF", "SETTINGS_ON"]
## What the system answers when asked whether to reduce motion (1 yes, 0 no, -1 it can't say).
const SYSTEM_KEYS: Dictionary[int, String] = {1: "SETTINGS_SYSTEM_YES", 0: "SETTINGS_SYSTEM_NO",
		-1: "SETTINGS_SYSTEM_UNKNOWN"}
## The gauge patterns sample (the concept's `.sample`): the room between its parts, its words' size, how many pips each
## team shows and how many are filled, the scores on the blocks.
const SAMPLE_GAP := 22
const SAMPLE_WORD_SIZE := 12
const SAMPLE_PIPS := 5
const SAMPLE_SCORE: Array[int] = [3, 2]
const PERCENT := "%d%%"
## The sound cue sample beside the key and the gaps between them, between the key's lines and after each icon (px).
const CUE_ROW_GAP := 18
const CUE_KEY_GAP := 6
const CUE_ICON_GAP := 10

var _screen: SettingsScreen = null
var _set_cards: Array[MenuCard] = []
var _in_use: Array[MenuTag] = []
var _patterns: CheckButton = null
var _read_out: CheckButton = null
var _cues: CheckButton = null
var _cue_size: HSlider = null
var _cue_colour: MenuSwatches = null
## The cue ring's sample and the key's icons (a step, a shot, a hit call), drawn by the HUD's own painter.
var _cue_sample: CueSample = null
var _cue_icons: Array[CueIcon] = []
var _motion: MenuChoice = null
var _system: Label = null
## Each set's HUD colours, in TeamColours.Set's order (the sample's), and the sample's parts: each team's pips and
## block in side order, then the low magazine.
var _hud_sets: Array[TeamConfig] = []
var _samples: Array[GaugeSample] = []
## Each section's body under its heading and the heading's LATER tag (both shown greyed while the section is LATER).
var _bodies: Dictionary[Section, VBoxContainer] = {}
var _later_tags: Dictionary[Section, MenuTag] = {}


func _init() -> void:
	name = "SettingsAccessPage"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", COLUMN_GAP)


## Builds the tab with `screen`'s rows (SettingsScreen.add_row and the rest), editing its settings.
func build(screen: SettingsScreen) -> void:
	_screen = screen
	var left := _column(LEFT_WIDTH)
	_build_team_colours(_section(left, "SETTINGS_TEAM_COLOURS", Section.TEAM_COLOURS))
	_build_patterns(_section(left, "SETTINGS_GAUGE_PATTERNS", Section.GAUGE_PATTERNS))
	_build_read_out(_section(left, "SETTINGS_SCREEN_READER", Section.SCREEN_READER))
	var right := _column(0.0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_cues(_section(right, "SETTINGS_SOUND_CUES", Section.SOUND_CUES))
	_build_motion(_section(right, "SETTINGS_REDUCED_MOTION", Section.REDUCED_MOTION))
	for section: Section in _bodies:
		var parts: Array[Control] = [_bodies[section]]
		MenuParts.set_unused(parts, _later_tags[section], LATER.has(section))


## Shows the settings as they are now, and what the system asks for.
func refresh() -> void:
	var s := _screen.settings
	_show_set(s.team_colours)
	_screen.set_check(_patterns, s.gauge_patterns)
	_screen.set_check(_read_out, s.read_out)
	_screen.set_check(_cues, s.sound_cues)
	_screen.set_slider(_cue_size, s.sound_cue_size * 100.0)
	_cue_colour.put(s.sound_cue_colour)
	_show_cues()
	_motion.put(s.reduced_motion)
	_show_system(DisplayServer.accessibility_should_reduce_animation())


## The colour set cards, in TeamColours.Set's order.
func set_card(colour_set: TeamColours.Set) -> MenuCard:
	return _set_cards[colour_set]


func patterns() -> CheckButton:
	return _patterns


func read_out() -> CheckButton:
	return _read_out


func cues() -> CheckButton:
	return _cues


func cue_size() -> HSlider:
	return _cue_size


func cue_colour() -> MenuSwatches:
	return _cue_colour


func motion() -> MenuChoice:
	return _motion


## Whether `section` is greyed with LATER.
func greyed(section: Section) -> bool:
	return _bodies[section].modulate.a < 1.0


## The system line for its answer to "reduce animation?" (`answer`: 1 yes, 0 no, -1 it can't say).
func _show_system(answer: int) -> void:
	_system.text = tr("SETTINGS_SYSTEM_ASKS") % tr(SYSTEM_KEYS.get(answer, SYSTEM_KEYS[-1]))


# --- Team colours ---

func _build_team_colours(body: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CARD_GAP)
	body.add_child(row)
	for colour_set: int in TeamColours.Set.values():
		var resolved := TeamColours.resolve(colour_set as TeamColours.Set, false, null, _screen.settings.tuning.teams)
		row.add_child(_set_card(colour_set as TeamColours.Set, resolved.figures))
		_hud_sets.append(resolved.hud)
	_screen.explain(row, tr("SETTINGS_TEAM_COLOURS_NOTE"))


## One set's card: its name with IN USE while picked, its figures' two colours with their codes, and its blurb.
func _set_card(colour_set: TeamColours.Set, teams: TeamConfig) -> MenuCard:
	var card := MenuCard.new()
	card.name = "Set_%d" % colour_set
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := MenuParts.padded(CARD_PAD.x, CARD_PAD.y, CARD_PAD.x, CARD_PAD.y)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", CARD_ROWS_GAP)
	pad.add_child(rows)
	var head := HBoxContainer.new()
	var title := MenuParts.spaced(tr(SET_KEYS[colour_set]).to_upper(), CARD_TITLE_SIZE, 800, GameTheme.TEXT,
			GameTheme.SPACING_TAB)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var tag := MenuTag.make(tr("SETTINGS_IN_USE"), GameTheme.ACCENT_INK, GameTheme.ACCENT, GameTheme.ACCENT)
	head.add_child(tag)
	rows.add_child(head)
	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", SWATCH_GAP)
	for side in 2:
		swatches.add_child(_swatch(tr(teams.names[side]), teams.colours[side]))
	rows.add_child(swatches)
	# what the set is for: the card's tooltip (UI1)
	card.tooltip_text = "%s %s" % [tr(SET_LEADS[colour_set]), tr(SET_NOTES[colour_set])]
	card.add_content(pad)
	# The content is laid over the card, so the card takes its height (the blurb's wraps are known only once laid out).
	pad.minimum_size_changed.connect(func() -> void:
		card.custom_minimum_size.y = pad.get_combined_minimum_size().y)
	card.pressed.connect(func() -> void:
		_screen.settings.team_colours = colour_set
		_show_set(colour_set)
		changed.emit(true))
	_set_cards.append(card)
	_in_use.append(tag)
	return card


## A team's swatch: its name on the left and its colour's code on the right, in ink that reads on it.
func _swatch(team_name: String, colour: Color) -> PanelContainer:
	var swatch := PanelContainer.new()
	swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swatch.custom_minimum_size.y = SWATCH_HEIGHT
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.add_theme_stylebox_override("panel", GameTheme.box(colour, Color(0.0, 0.0, 0.0, 0.0), SWATCH_PAD, 0))
	var words := HBoxContainer.new()
	var ink := HudStyle.ink_on(colour)
	var label := MenuParts.spaced(team_name.to_upper(), SWATCH_SIZE, 800, ink, GameTheme.SPACING_TAB)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(label)
	words.add_child(MenuParts.text("#" + colour.to_html(false), SWATCH_SIZE, 700, ink))
	swatch.add_child(words)
	return swatch


func _show_set(colour_set: TeamColours.Set) -> void:
	for i in _set_cards.size():
		_set_cards[i].set_picked(i == colour_set)
		_in_use[i].visible = i == colour_set
	_show_sample()


# --- Gauge patterns and screen reader messages ---

func _build_patterns(body: VBoxContainer) -> void:
	_patterns = _screen.add_check_row(body, "SETTINGS_PATTERNS", "SETTINGS_ON", "SETTINGS_OFF", LEFT_LABEL)
	_note(_patterns.get_parent() as Control, "SETTINGS_PATTERNS_NOTE")
	# the sample sits on the switch's row, after it
	var switch_row := _patterns.get_parent() as HBoxContainer
	_patterns.toggled.connect(func(on: bool) -> void:
		_screen.settings.gauge_patterns = on
		_show_sample()
		changed.emit(true))
	var sample := _build_sample()
	sample.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	switch_row.add_child(sample)
	_screen.explain(switch_row, "%s %s" % [tr("SETTINGS_PATTERNS_NOTE"), tr("SETTINGS_PATTERNS_HELP")])
	_show_sample()


## The sample: Alpha's pips and block, Beta's block and pips (as the score bar sets them out), then a low magazine.
func _build_sample() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "PatternSample"
	row.add_theme_constant_override("separation", SAMPLE_GAP)
	var names := _screen.settings.tuning.teams.names
	for side in 2:
		row.add_child(MenuParts.spaced(tr(names[side]).to_upper(), SAMPLE_WORD_SIZE, 800, GameTheme.MUTED,
				HudStyle.SPACING_ROUND))
		var pips := GaugeSample.new(GaugeSample.Kind.PIPS, SAMPLE_PIPS, SAMPLE_SCORE[side], side)
		var block := GaugeSample.new(GaugeSample.Kind.BLOCK, 1, SAMPLE_SCORE[side], side)
		# Each block faces the clock: Alpha's after its pips, Beta's before.
		row.add_child(pips)
		row.add_child(block)
		if side == HudStyle.STRIPED_TEAM:
			row.move_child(block, pips.get_index())
		_samples.append(pips)
		_samples.append(block)
	row.add_child(MenuParts.spaced(tr("SETTINGS_LOW_MAG").to_upper(), SAMPLE_WORD_SIZE, 800, GameTheme.MUTED,
			HudStyle.SPACING_ROUND))
	var mag := GaugeSample.new(GaugeSample.Kind.MAG, 1, 0, -1)
	mag.share = _screen.settings.tuning.hud.low_mag_share
	row.add_child(mag)
	_samples.append(mag)
	return row


## The sample in the picked set's HUD colours, striped while gauge patterns are on.
func _show_sample() -> void:
	if _samples.is_empty() or _hud_sets.is_empty():
		return
	var s := _screen.settings
	var teams := _hud_sets[clampi(s.team_colours, 0, _hud_sets.size() - 1)]
	for part in _samples:
		var colour := GameTheme.WARN if part.side < 0 else teams.colours[part.side]
		part.show_as(colour, s.gauge_patterns and (part.side < 0 or part.side == HudStyle.STRIPED_TEAM))


## The sample's parts, for tests: each team's pips and block in side order, then the low magazine.
func sample_parts() -> Array[GaugeSample]:
	return _samples


func _build_read_out(body: VBoxContainer) -> void:
	_read_out = _screen.add_check_row(body, "SETTINGS_READ_OUT", "SETTINGS_ON", "SETTINGS_OFF", LEFT_LABEL)
	_read_out.toggled.connect(func(on: bool) -> void:
		_screen.settings.read_out = on
		changed.emit(true))
	_note(_read_out.get_parent() as Control, "SETTINGS_READ_OUT_NOTE")


# --- Sound cues ---

func _build_cues(body: VBoxContainer) -> void:
	_cues = _screen.add_check_row(body, "SETTINGS_SHOW_CUES", "SETTINGS_ON", "SETTINGS_OFF", RIGHT_LABEL)
	_note(_cues.get_parent() as Control, "SETTINGS_SHOW_CUES_NOTE")
	_cues.toggled.connect(func(on: bool) -> void:
		_screen.settings.sound_cues = on
		changed.emit(true))
	var sizes := AccessibilityConfig.CUE_SIZE_RANGE * 100.0
	_cue_size = _screen.add_slider_row(body, "SETTINGS_SIZE", sizes.x, sizes.y,
			AccessibilityConfig.CUE_SIZE_STEP * 100.0, PERCENT, RIGHT_LABEL)
	_cue_size.custom_minimum_size.x = SLIDER_WIDTH
	_cue_size.value_changed.connect(func(v: float) -> void:
		_screen.settings.sound_cue_size = v / 100.0
		_show_cues()
		changed.emit(false))
	var colour_row := _screen.add_row(body, "SETTINGS_COLOUR", RIGHT_LABEL)
	_cue_colour = MenuSwatches.new(HudPrefs.COLOURS)
	_cue_colour.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	colour_row.add_child(_cue_colour)
	_note(colour_row, "SETTINGS_CUE_COLOUR_NOTE")
	_cue_colour.picked.connect(func(i: int) -> void:
		_screen.settings.sound_cue_colour = i
		_show_cues()
		changed.emit(true))
	# The ring's sample, and beside it what each marker means with how far its sound carries (its reach in play).
	var row := HBoxContainer.new()
	row.name = "CueSample"
	row.add_theme_constant_override("separation", CUE_ROW_GAP)
	body.add_child(row)
	_cue_sample = CueSample.new()
	row.add_child(_cue_sample)
	var key_lines := VBoxContainer.new()
	key_lines.add_theme_constant_override("separation", CUE_KEY_GAP)
	key_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_lines.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(key_lines)
	var sound := _screen.settings.tuning.sound
	var reach: Dictionary[String, float] = {"SETTINGS_CUE_STEP": sound.step_reach,
			"SETTINGS_CUE_SHOT": sound.max_distance, "SETTINGS_CUE_HIT": sound.max_distance}
	var kinds: Array[SoundCues.Kind] = [SoundCues.Kind.STEP, SoundCues.Kind.SHOT, SoundCues.Kind.HIT]
	var i := 0
	for key: String in reach:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", CUE_ICON_GAP)
		key_lines.add_child(line)
		var icon := CueIcon.new(kinds[i])
		line.add_child(icon)
		_cue_icons.append(icon)
		var words := _lead_note(key + "_LEAD", "")
		words.text += " " + tr(key) % roundi(reach[key])
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(words)
		i += 1
	_screen.explain(row, tr("SETTINGS_CUES_HELP"))
	_show_cues()


## The sample and the key's icons in the picked colour, the sample's markers at the picked size.
func _show_cues() -> void:
	if _cue_sample == null:
		return
	var s := _screen.settings
	var colour := HudPrefs.COLOURS[clampi(s.sound_cue_colour, 0, HudPrefs.COLOURS.size() - 1)]
	_cue_sample.show_as(s.sound_cue_size, colour)
	for icon in _cue_icons:
		icon.show_as(colour)


## The cue sample and the key's icons, for tests.
func cue_sample() -> CueSample:
	return _cue_sample


func cue_icons() -> Array[CueIcon]:
	return _cue_icons


# --- Reduced motion ---

func _build_motion(body: VBoxContainer) -> void:
	var row := _screen.add_row(body, "SETTINGS_MOTION", RIGHT_LABEL)
	var words := PackedStringArray()
	for key in MOTION_KEYS:
		words.append(tr(key))
	_motion = MenuChoice.new(words)
	_motion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_motion)
	_motion.picked.connect(func(i: int) -> void:
		_screen.settings.reduced_motion = i as Settings.ReducedMotion
		changed.emit(true))
	# Each choice's blurb (the browser game's REDUCED_MOTION_CHOICES), its name first: the row's tooltip (UI1)
	var blurb := PackedStringArray()
	for key: String in ["SETTINGS_MOTION_SYSTEM", "SETTINGS_MOTION_OFF", "SETTINGS_MOTION_ON"]:
		blurb.append(tr(key + "_LEAD") + " " + tr(key + "_NOTE"))
	_screen.explain(row, " ".join(blurb))
	# what the system asks for, under the choices: Follow system means it
	_system = MenuParts.text("", NOTE_SIZE, 600, GameTheme.MUTED)
	var indent := StyleBoxEmpty.new()
	indent.content_margin_left = RIGHT_LABEL + SettingsScreen.ROW_SEPARATION
	_system.add_theme_stylebox_override("normal", indent)
	body.add_child(_system)


# --- Building blocks ---

func _column(width: float) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.custom_minimum_size.x = width
	c.add_theme_constant_override("separation", SettingsScreen.ROW_GAP)
	add_child(c)
	return c


## A section's heading under `column` (`key` translated, its LATER tag after it) and the body its rows go in; build()
## greys the body and shows the tag while the section is in `LATER`.
func _section(column: VBoxContainer, key: String, section: Section) -> VBoxContainer:
	if column.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size.y = SettingsScreen.SECTION_GAP
		column.add_child(gap)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", TAG_GAP)
	head.add_child(SettingsScreen.section_label(tr(key)))
	var tag := MenuTag.later()
	head.add_child(tag)
	column.add_child(head)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", SettingsScreen.ROW_GAP)
	column.add_child(body)
	_bodies[section] = body
	_later_tags[section] = tag
	return body


## A wrapped note in the muted colour with `lead_key`'s words first in the text colour and bold, then `note_key`'s
## ("" for either leaves it out; the caller may set the text itself).
func _lead_note(lead_key: String, note_key: String) -> RichTextLabel:
	var note := RichTextLabel.new()
	note.bbcode_enabled = true
	note.fit_content = true
	note.scroll_active = false
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.add_theme_font_override("normal_font", GameTheme.font(600))
	note.add_theme_font_override("bold_font", GameTheme.font(800))
	note.add_theme_font_size_override("normal_font_size", NOTE_SIZE)
	note.add_theme_font_size_override("bold_font_size", NOTE_SIZE)
	note.add_theme_color_override("default_color", GameTheme.MUTED)
	var parts := PackedStringArray()
	if lead_key != "":
		parts.append(_bold(tr(lead_key)))
	if note_key != "":
		parts.append(tr(note_key))
	note.text = " ".join(parts)
	return note


static func _bold(words: String) -> String:
	return "[b][color=#%s]%s[/color][/b]" % [GameTheme.TEXT.to_html(false), words]


## A row's explanation (`key` translated): its tooltip (UI1: only what a player would be stuck without is written out).
func _note(row: Control, key: String) -> void:
	_screen.explain(row, tr(key))


## One part of the gauge patterns sample, drawn as the HUD draws it (HudStyle's pips, a score block, a magazine box) at
## the concept's sizes, with its stripes (GaugePattern) built once.
class GaugeSample:
	extends Control

	enum Kind { PIPS, BLOCK, MAG }

	## The concept's sizes (px): the pips' gap, the block, its number's size, the magazine box and its edge.
	const PIP_GAP := 3.0
	const BLOCK := Vector2(44.0, 30.0)
	const NUMBER_SIZE := 20
	const MAG := Vector2(18.0, 34.0)
	const MAG_LINE := 2.0

	## The team it shows (-1: the magazine, yellow), its share filled (the magazine) and how it is drawn now.
	var side: int = -1
	var share: float = 0.0
	var colour: Color = Color.WHITE
	var striped: bool = false
	var _kind: Kind = Kind.PIPS
	var _count: int = 1
	var _filled: int = 0
	var _shapes: Array[PackedVector2Array] = []
	var _outlines: Array[PackedVector2Array] = []
	var _stripes: Array[GaugePattern] = []
	var _number: Label = null

	func _init(kind: Kind, count: int, filled: int, team: int) -> void:
		_kind = kind
		_count = count
		_filled = filled
		side = team
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		match kind:
			Kind.PIPS:
				var lean := HudStyle.PIP_SIZE.y * 0.5 * HudStyle.PIP_LEAN
				for i in count:
					_shapes.append(HudStyle.pip_shape(Vector2(lean + i * (HudStyle.PIP_SIZE.x + PIP_GAP), 0.0)))
				custom_minimum_size = Vector2(count * (HudStyle.PIP_SIZE.x + PIP_GAP) - PIP_GAP + lean * 2.0,
						HudStyle.PIP_SIZE.y)
			Kind.BLOCK:
				custom_minimum_size = BLOCK
				_number = HudStyle.label(self, NUMBER_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
				_number.text = str(filled)
				_number.size = BLOCK
				_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				_shapes.append(PackedVector2Array([Vector2.ZERO, Vector2(BLOCK.x, 0.0), BLOCK, Vector2(0.0, BLOCK.y)]))
			Kind.MAG:
				custom_minimum_size = MAG
				_stripes.append(GaugePattern.new())
		for shape in _shapes:
			var stripes := GaugePattern.new()
			stripes.set_shape(shape)
			_stripes.append(stripes)
			var outline := shape.duplicate()
			outline.append(shape[0])
			_outlines.append(outline)

	## Draws in `fill`, striped or not; the magazine's stripes follow its share.
	func show_as(fill: Color, on: bool) -> void:
		colour = fill
		striped = on
		if _number != null:
			_number.add_theme_color_override("font_color", HudStyle.ink_on(fill))
			HudStyle.edge_number(_number, on)
		if _kind == Kind.MAG:
			_stripes[0].set_rect(_mag_fill(), true)
		queue_redraw()

	func _mag_fill() -> Rect2:
		var inner := Rect2(Vector2.ZERO, MAG).grow(-MAG_LINE)
		var h := inner.size.y * share
		return Rect2(inner.position.x, inner.end.y - h, inner.size.x, h)

	func _draw() -> void:
		if _kind == Kind.MAG:
			draw_rect(Rect2(Vector2.ZERO, MAG).grow(-MAG_LINE * 0.5), colour, false, MAG_LINE)
			draw_rect(_mag_fill(), colour)
			if striped:
				_stripes[0].draw(self)
			return
		var empty := Color(GameTheme.TEXT, HudStyle.PIP_EMPTY_ALPHA)
		for i in _shapes.size():
			var filled := _kind == Kind.BLOCK or i < _filled
			if not filled:
				draw_polyline(_outlines[i], empty, HudStyle.PIP_BORDER)
				continue
			draw_colored_polygon(_shapes[i], colour)
			if striped:
				_stripes[i].draw(self)


## The sound cue ring's sample (concept `settings-accessibility.png`): a stretch of field with the crosshair, the ring
## and three markers on it, a step behind and to the left, a fainter shot to the right and a hit call ahead, drawn by
## the HUD's painter (HudSoundCues.Painter) at the concept's smaller scale times the picked size.
class CueSample:
	extends Control

	## The sample's size, its ring's radius and the markers' scale at 100 % (px; the concept's), its field and edge.
	const SIZE := Vector2(200.0, 176.0)
	const RADIUS := 62.0
	const SCALE := 0.62
	const FIELD := Color("6b6452")
	const EDGE := 2.0
	## The crosshair: a plus this wide (px) in lines this thick.
	const CROSS := 14.0
	const CROSS_WIDTH := 1.6
	## The markers: each kind's bearing (radians clockwise from ahead) and strength.
	const KINDS: Array[SoundCues.Kind] = [SoundCues.Kind.STEP, SoundCues.Kind.SHOT, SoundCues.Kind.HIT]
	const BEARINGS: Array[float] = [-0.75 * PI, 0.5 * PI, 0.0]
	const STRENGTHS: Array[float] = [1.0, 0.55, 1.0]

	var painter: HudSoundCues.Painter = HudSoundCues.Painter.new()

	func _init() -> void:
		custom_minimum_size = SIZE
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	## The markers at `cue_scale` (1 = 100 %) in `colour`.
	func show_as(cue_scale: float, colour: Color) -> void:
		painter.set_style(SCALE * cue_scale, colour)
		queue_redraw()

	func _draw() -> void:
		var centre := size * 0.5
		draw_rect(Rect2(Vector2.ZERO, size), FIELD)
		var half := CROSS * 0.5
		draw_line(centre - Vector2(half, 0.0), centre + Vector2(half, 0.0), GameTheme.TEXT, CROSS_WIDTH)
		draw_line(centre - Vector2(0.0, half), centre + Vector2(0.0, half), GameTheme.TEXT, CROSS_WIDTH)
		painter.ring(self, centre, RADIUS, 1.0)
		for i in KINDS.size():
			var b := BEARINGS[i]
			painter.marker(self, KINDS[i], centre + Vector2(sin(b), -cos(b)) * RADIUS, b, STRENGTHS[i])
		draw_rect(Rect2(Vector2.ZERO, size).grow(-EDGE * 0.5), GameTheme.LINE, false, EDGE)


## One marker of the key (concept `settings-accessibility.png`): a step's dots rising to the right, an arrowhead
## pointing up, a HIT tag, each scaled to fit its box.
class CueIcon:
	extends Control

	const SIZE := Vector2(34.0, 24.0)
	## Each kind's scale and bearing (radians clockwise from up), in SoundCues.Kind's order.
	const SCALES: Array[float] = [0.8, 0.68, 0.58]
	const BEARINGS: Array[float] = [0.5 * PI, 0.0, 0.0]

	var kind: SoundCues.Kind = SoundCues.Kind.STEP
	var painter: HudSoundCues.Painter = HudSoundCues.Painter.new()

	func _init(cue_kind: SoundCues.Kind) -> void:
		kind = cue_kind
		custom_minimum_size = SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	## The marker in `colour`.
	func show_as(colour: Color) -> void:
		painter.set_style(SCALES[kind], colour)
		queue_redraw()

	func _draw() -> void:
		painter.marker(self, kind, size * 0.5, BEARINGS[kind], 1.0)
