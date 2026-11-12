class_name MatchPage
extends Control
## The Match page (UI concept B v2, owner 2026-11-02, docs/records/UR2.md): MATCH and its line at the top, then three
## glass panels side by side: the fields as a list (each its eye-height picture, name and blurb) over the modes (each
## its name and blurb); the rules (MatchRulesBox: Skirmish's chips or Custom's rows, docs/records/CR2.md); and your team
## over the bots' levels (MatchBotsBox, docs/records/MN3.md), with the Play card at the foot of that column: the picked
## field's picture, its name, the summary line and PLAY. A map that can't load (MapData's problems) is greyed with LATER,
## as a mode that isn't built. Picks go into the MatchPicks it is given (kept by the entry scene across the menus' being
## freed). What reads the round tuning (the Elimination card, the maps a team size can't load) reads the Custom
## switches while Custom is picked, and the team size the picked map plays (data/maps.md: its standard, or the saved
## Custom size where it offers it). `play_pressed` starts the match.
## Everything is drawn for 1920x1080 beside the side rail and the window's stretch scales it.

signal play_pressed
## A field was picked (the menus' backdrop follows it).
signal map_picked(map_id: String)

## The three panels' columns (the page's margins, title and panels are MenuParts'): the fields' and the team's widths.
const FIELDS_WIDTH := 520.0
const SIDE_WIDTH := 500.0
const SECTION_GAP := 26
const HEADING_GAP := 12
## A field's row: its height, picture, name and blurb.
const FIELD_GAP := 6
const FIELD_HEIGHT := 92.0
const FIELD_PICTURE := Vector2(136.0, 76.0)
const FIELD_PAD := Vector2(8.0, 8.0)
const FIELD_TEXT_GAP := 2
const FIELD_NAME_SIZE := 24
const FIELD_BLURB_SIZE := 14
const TAG_GAP := 8
## A mode's row: its height, name and blurb.
const MODE_GAP := 6
const MODE_HEIGHT := 80.0
const MODE_PAD := Vector2(16.0, 8.0)
const MODE_NAME_SIZE := 17
const MODE_BLURB_SIZE := 14
## A mode's line wraps to at most this many lines; MODE_HEIGHT holds two, so every card is one height.
const MODE_BLURB_LINES := 2
const TEAM_GAP := 12
const TEAM_HEIGHT := 64.0
const TEAM_NAME_SIZE := 26
const TEAM_SPACING := 0.04
## The room a team's name keeps at each side: past its colour bar on the left (px).
const TEAM_TEXT_PAD := 20
## How much of a team's colour tints a picked team card.
const TEAM_TINT := 0.06
## Attack / Defend's line under the team cards: its size, and the team's name lightened to read on the page.
const ATTACK_LINE_SIZE := 16
const TEAM_NAME_LIGHTEN := 0.25
## The Play card: the picked field's picture, its name and the summary line over PLAY.
const PLAY_PICTURE := Vector2(100.0, 56.0)
const PLAY_ROW_GAP := 16
const PLAY_NAME_SIZE := 26
const PLAY_LINE_SIZE := 15
## The rest of the match under the field's name wraps to at most this many lines: the longest Custom pick fits.
const PLAY_LINE_LINES := 2
const PLAY_GAP := 16
const PLAY_HEIGHT := 72.0
const PLAY_SIZE := 30
## A mode card's "Needs a map with a flagpole" in a dimmed yellow, and its size.
const NEEDS_DARKEN := 0.3
const NEEDS_SIZE := 13

var picks: MatchPicks = null

var _settings: Settings = null
var _tuning: SimTuning = null
## The map the round tuning was read for.
var _tuned_map: String = ""
## The mode you had on the field you left for the Range (Practice too, when you picked it), given back when a field is
## picked next; "" when the page opened on the Range, so the field opens on its first mode, not the Range's Practice.
var _field_mode: String = ""
## The kind of the map picked at the last refresh (&"" before the first or for a map not in the catalogue).
var _last_kind: StringName = &""
var _play_tuning: PlayTuning = null
var _catalog: MapCatalog = null
var _maps_list: VBoxContainer = null
var _modes_box: VBoxContainer = null
var _map_cards: Dictionary[String, MenuCard] = {}
var _mode_cards: Dictionary[String, MenuCard] = {}
var _team_cards: Array[MenuCard] = []
## The team colours the menus show: the saved set's HUD part (Settings › Accessibility), and that set, to tell a change.
var _teams: TeamConfig = null
var _teams_set: int = -1
## Your team's cards and heading tag: NOT USED while Practice is picked.
var _team_row: GridContainer = null
var _team_tag: MenuTag = null
## The ids on offer in the catalogue's order (to tell a change), and as the cards are laid out.
var _offered: PackedStringArray = PackedStringArray()
var _listed: PackedStringArray = PackedStringArray()
var _unloadable: Dictionary[String, bool] = {}
## Which listed maps have a flagpole (Attack / Defend).
var _poles: Dictionary[String, bool] = {}
## Under a pole mode's card, why it can't be picked on a map without a pole.
var _needs_pole: Dictionary[String, Control] = {}
## Under the team cards in Attack / Defend: ATK, the team attacking first, and the rest of the line.
var _attack_row: HBoxContainer = null
var _attack_team: Label = null
var _attack_room: MarginContainer = null
## Whether Attack / Defend's line shows (its room is always kept).
var _attack_shown: bool = false
var _rules: MatchRulesBox = null
var _bots: MatchBotsBox = null
## The mode cards' blurbs (Elimination's reads the rounds to win).
## A mode card's FIELDS ONLY tag, shown while the picked map doesn't host the mode.
var _only_tags: Dictionary[String, MenuTag] = {}
var _mode_blurbs: Dictionary[String, Label] = {}
## The Custom size the maps were last checked for (0 under Skirmish): each is checked at the size it would play.
var _checked_custom: int = -1
## The Play card's picture of the picked field and its name.
var _play_picture: TextureRect = null
var _play_name: Label = null
## The summary line: the map, then the rest (the Play card shows the rest under the map's name).
var _summary: Label = null
var _summary_map: String = ""
var _summary_rest: String = ""
var _play: Button = null


func _init(picked: MatchPicks = null, settings: Settings = null) -> void:
	name = "MatchPage"
	picks = picked if picked != null else MatchPicks.new()
	_settings = settings if settings != null else Settings.shared()
	_tuning = _round_tuning()
	_tuned_map = picks.map_id
	_play_tuning = PlayTuning.load_default()
	_follow_team_colours()
	_catalog = MapCatalog.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_list_maps()
	_refresh()


func _enter_tree() -> void:
	if not _settings.changed.is_connected(_on_rules_changed):
		_settings.changed.connect(_on_rules_changed)


func _exit_tree() -> void:
	if _settings.changed.is_connected(_on_rules_changed):
		_settings.changed.disconnect(_on_rules_changed)


func play_button() -> Button:
	return _play


## PLAY takes the keyboard, its focus ring hidden (MN1; BP7: the concept draws none) until a key or the pad moves the
## focus; Enter starts the match at once all the same.
func focus_play() -> void:
	_play.grab_focus(true)


## The map cards by map id, in the order listed.
func map_card(map_id: String) -> MenuCard:
	return _map_cards.get(map_id)


func map_ids() -> PackedStringArray:
	return _listed


func mode_card(mode: String) -> MenuCard:
	return _mode_cards[mode]


func team_card(team: int) -> MenuCard:
	return _team_cards[team]


## The Opponents row's button for `level`.
func bot_button(level: String) -> MenuCard:
	return _bots.opponents_button(level)


## The Teammates row's button for `level`.
func teammate_button(level: String) -> MenuCard:
	return _bots.teammates_button(level)


func bots_box() -> MatchBotsBox:
	return _bots


func rules_box() -> MatchRulesBox:
	return _rules


## The rule chips of the round tuning in force, one line each (shown in Skirmish; Custom shows its rows instead).
func chip_texts() -> PackedStringArray:
	return _rules.chip_texts()


## The team size the picked map is played and was checked at (its standard, or Custom's where it offers it).
func map_check_size() -> int:
	return _tuning.rounds.team_size


## A mode card's blurb: its tooltip, so every card is one height whatever the rules say (UI1).
func mode_blurb(mode: String) -> String:
	return _mode_cards[mode].tooltip_text


## The summary line as shown: "Depot · Elimination · Alpha · Normal bots", with " · Easy teammates" when they play
## another level than the opponents and " · Custom 2v2" under Custom.
func summary_text() -> String:
	return _summary_map + _summary_rest


## Whether a listed map can't be played (its file is refused).
func is_unloadable(map_id: String) -> bool:
	return _unloadable.get(map_id, false)


## Whether a pole mode's card says it needs a map with a flagpole.
func says_needs_pole(mode: String) -> bool:
	return _needs_pole.has(mode) and _needs_pole[mode].visible


## The line under the team cards in Attack / Defend ("Alpha attacks first, ..."), or "" while it is hidden.
func attack_line() -> String:
	if not _attack_shown:
		return ""
	return "%s %s" % [_attack_team.text, tr("MENU_ATTACKS_FIRST")]


func _build() -> void:
	var m := MenuParts.PAGE_MARGIN
	var margin := MenuParts.padded(m.x, m.y, m.z, m.w)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", MenuParts.PAGE_TITLE_AFTER)
	margin.add_child(page)
	page.add_child(MenuParts.page_title(tr("MENU_TAB_MATCH"), MenuParts.page_line(tr("MENU_MATCH_LINE"))))
	var panels := HBoxContainer.new()
	panels.name = "Panels"
	panels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panels.add_theme_constant_override("separation", MenuParts.PANEL_GAP)
	page.add_child(panels)
	var fields := MenuParts.glass(_build_fields())
	fields.custom_minimum_size.x = FIELDS_WIDTH
	panels.add_child(fields)
	_rules = MatchRulesBox.new(picks, _settings, _tuning)
	_rules.changed.connect(_on_rules_changed)
	var rules := MenuParts.glass(_rules)
	rules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panels.add_child(rules)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = SIDE_WIDTH
	side.add_theme_constant_override("separation", MenuParts.PANEL_GAP)
	side.add_child(MenuParts.glass(_build_side()))
	var room := Control.new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(room)
	var play := MenuParts.glass(_build_play())
	play.name = "PlayCard"
	side.add_child(play)
	panels.add_child(side)


func _section(heading: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", HEADING_GAP)
	box.add_child(heading)
	return box


func _text(text: String, size: int, weight: int, colour: Color) -> Label:
	return MenuParts.text(text, size, weight, colour)


## FIELD over its list, then MODE over the modes.
func _build_fields() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SECTION_GAP)
	var fields := _section(MenuParts.heading(tr("MENU_FIELD")))
	_maps_list = VBoxContainer.new()
	_maps_list.name = "Fields"
	_maps_list.add_theme_constant_override("separation", FIELD_GAP)
	fields.add_child(_maps_list)
	column.add_child(fields)
	column.add_child(_build_modes())
	return column


func _build_modes() -> Control:
	var column := _section(MenuParts.heading(tr("MENU_MODE")))
	_modes_box = VBoxContainer.new()
	_modes_box.add_theme_constant_override("separation", MODE_GAP)
	column.add_child(_modes_box)
	for mode in MatchOptions.MODES:
		# a row of its name over its blurb; its tags after the name, the room for them kept so a tag showing or going
		# moves nothing (UI1)
		var card := MenuCard.new()
		card.name = "Mode_" + mode
		card.ring = true
		card.custom_minimum_size = Vector2(0.0, MODE_HEIGHT)
		var pad := MenuParts.padded(MODE_PAD.x, MODE_PAD.y, MODE_PAD.x, MODE_PAD.y)
		var words := VBoxContainer.new()
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_theme_constant_override("separation", FIELD_TEXT_GAP)
		var title := HBoxContainer.new()
		title.add_theme_constant_override("separation", TAG_GAP)
		var name_label := _text(tr(MatchOptions.MODE_NAME[mode]), MODE_NAME_SIZE, 700, GameTheme.TEXT)
		name_label.name = "Name"
		title.add_child(name_label)
		if not MatchOptions.BUILT_MODES.has(mode):
			title.add_child(_centred(MenuTag.later()))
		var only := MenuTag.grey(MatchOptions.FIELDS_ONLY_KEY)
		only.name = "OnlyTag"
		only.visible = false
		title.add_child(_centred(only))
		_only_tags[mode] = only
		if MatchOptions.POLE_MODES.has(mode):
			var needs := _text(tr("MENU_NEEDS_POLE"), NEEDS_SIZE, 700, GameTheme.WARN.darkened(NEEDS_DARKEN))
			needs.name = "NeedsPole"
			needs.visible = false
			needs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			title.add_child(needs)
			_needs_pole[mode] = needs
		words.add_child(title)
		var blurb := _text("", MODE_BLURB_SIZE, 500, GameTheme.MUTED)
		blurb.name = "Blurb"
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.max_lines_visible = MODE_BLURB_LINES
		words.add_child(blurb)
		_mode_blurbs[mode] = blurb
		pad.add_child(words)
		card.add_content(pad)
		card.pressed.connect(_pick_mode.bind(mode))
		_modes_box.add_child(card)
		_mode_cards[mode] = card
	return column


## `c` held at its own height, in the middle of a row.
static func _centred(c: Control) -> Control:
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


func _build_side() -> Control:
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", SECTION_GAP)
	# Your team.
	var team_head := MenuParts.heading_row(tr("MENU_TEAM"))
	_team_tag = team_head.get_child(1) as MenuTag
	var team := _section(team_head)
	var team_row := GridContainer.new()
	_team_row = team_row
	team_row.columns = 2
	team_row.add_theme_constant_override("h_separation", TEAM_GAP)
	team.add_child(team_row)
	for t in MatchOptions.TEAM_KEYS.size():
		var card := MenuCard.new()
		card.name = "Team_" + str(t)
		card.custom_minimum_size = Vector2(0.0, TEAM_HEIGHT)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# only its name, in condensed capitals: the two are one width, half the panel each (owner, 2026-10-29)
		card.text = tr(MatchOptions.TEAM_KEYS[t]).to_upper()
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.text_pad = TEAM_TEXT_PAD
		card.add_theme_font_override("font", GameTheme.heading_font(700, TEAM_SPACING, TEAM_NAME_SIZE))
		card.add_theme_font_size_override("font_size", TEAM_NAME_SIZE)
		for colour: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color",
				"font_focus_color"]:
			card.add_theme_color_override(colour, GameTheme.TEXT)
		_colour_team_card(card, _teams.colours[t])
		card.pressed.connect(_pick_team.bind(t))
		team_row.add_child(card)
		_team_cards.append(card)
	_attack_row = HBoxContainer.new()
	_attack_row.name = "AttacksFirst"
	_attack_row.add_theme_constant_override("separation", TAG_GAP + 2)
	_attack_row.add_child(MenuTag.attack())
	_attack_team = _text("", ATTACK_LINE_SIZE, 700, GameTheme.TEXT)
	_attack_row.add_child(_attack_team)
	_attack_row.add_child(_text(tr("MENU_ATTACKS_FIRST"), ATTACK_LINE_SIZE, 600, GameTheme.MUTED))
	# its room is kept whether it shows or not (it is see-through when not), so the bots under it never move as the mode
	# changes (UI1); the room fades with the team cards under Practice
	_attack_row.modulate.a = 0.0
	_attack_room = MarginContainer.new()
	_attack_room.name = "AttacksFirstRoom"
	_attack_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attack_room.add_child(_attack_row)
	team.add_child(_attack_room)
	side.add_child(team)
	# The bots' levels.
	_bots = MatchBotsBox.new(picks)
	_bots.changed.connect(_refresh)
	side.add_child(_bots)
	return side


## The Play card: the picked field's picture beside its name and the summary line, then PLAY across the card.
func _build_play() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", PLAY_GAP)
	var row := HBoxContainer.new()
	row.name = "Summary"
	row.add_theme_constant_override("separation", PLAY_ROW_GAP)
	_play_picture = MenuParts.picture(PLAY_PICTURE)
	_play_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_play_picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_play_picture)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", FIELD_TEXT_GAP)
	_play_name = MenuParts.head_text("", PLAY_NAME_SIZE, 700, GameTheme.TEXT, TEAM_SPACING)
	_play_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(_play_name)
	_summary = _text("", PLAY_LINE_SIZE, 500, GameTheme.MUTED)
	_summary.name = "SummaryLine"
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.max_lines_visible = PLAY_LINE_LINES
	# room for both lines always, so a pick that wraps it moves nothing on the card (UI1)
	_summary.custom_minimum_size.y = _summary.get_line_height() * PLAY_LINE_LINES \
			+ _summary.get_theme_constant("line_spacing") * (PLAY_LINE_LINES - 1)
	_summary.mouse_filter = Control.MOUSE_FILTER_PASS
	words.add_child(_summary)
	row.add_child(words)
	column.add_child(row)
	_play = Button.new()
	_play.name = "Play"
	_play.theme_type_variation = GameTheme.MAIN_BUTTON
	_play.text = tr("MENU_PLAY")
	_play.custom_minimum_size = Vector2(0.0, PLAY_HEIGHT)
	_play.add_theme_font_override("font", GameTheme.heading_font(700, GameTheme.SPACING_HEADING_CAPS, PLAY_SIZE))
	_play.add_theme_font_size_override("font_size", PLAY_SIZE)
	_play.pressed.connect(func() -> void: play_pressed.emit())
	column.add_child(_play)
	return column


## The map cards for the maps on offer now (public fields, dev ones too while Dev content is on). Rebuilt only when
## that list changes, since Settings reports every slider move.
func _list_maps() -> void:
	var fields := _catalog.listed(_settings.dev.dev_content)
	var offered := PackedStringArray()
	for e in fields:
		offered.append(e.id)
	var custom := picks.custom_rules(_settings)
	var custom_size := custom.team_size if custom != null else 0
	if offered == _offered and _checked_custom == custom_size and not _map_cards.is_empty():
		return
	_offered = offered
	_checked_custom = custom_size
	# The maps that can play come first, then those greyed with LATER, each in the catalogue's order.
	var problems: Dictionary[String, bool] = {}
	var playable: Array[MapCatalog.Entry] = []
	var later: Array[MapCatalog.Entry] = []
	for e in fields:
		var m := MatchOptions.map_check(e.id, _play_tuning.map_style, MatchOptions.team_size(e, custom))
		var refused := not m.problems.is_empty()
		problems[e.id] = refused
		_poles[e.id] = m.has_pole
		(later if refused else playable).append(e)
	var ordered := playable + later
	var ids := PackedStringArray()
	for e in ordered:
		ids.append(e.id)
	_listed = ids
	for id: String in _map_cards:
		_maps_list.remove_child(_map_cards[id])
		_map_cards[id].queue_free()
	_map_cards.clear()
	_unloadable = problems
	for e in ordered:
		var card := _map_card(e, problems[e.id])
		_maps_list.add_child(card)
		_map_cards[e.id] = card
	_keep_a_playable_map()
	_refresh()


## Keeps the picked map if it is still listed and can load; else the first that can.
func _keep_a_playable_map() -> void:
	if _map_cards.has(picks.map_id) and not _unloadable[picks.map_id]:
		_play.disabled = false
		return
	for id in _listed:
		if not _unloadable[id]:
			picks.map_id = id
			_play.disabled = false
			# the backdrop follows the field that stands in
			map_picked.emit(id)
			return
	_play.disabled = true


## A field card's tooltip: its blurb, then its weather (PH1, data/maps.md Wind and Air): still air or open to the
## breeze, and its air by day (the pause menu has the match's own, a night's colder air included).
static func field_tip(e: MapCatalog.Entry, tuning: SimTuning) -> String:
	var day := roundi(e.air_or(tuning.ballistics.air_temperature))
	var words := "MATCH_FIELD_STILL" if e.wind <= 0.0 else "MATCH_FIELD_BREEZY"
	return TranslationServer.translate(words) % [e.blurb, day]


## A field's row: its eye-height picture, then its name (with DEV or LATER) over its blurb.
func _map_card(e: MapCatalog.Entry, later: bool) -> MenuCard:
	var card := MenuCard.new()
	card.name = "Map_" + e.id
	card.ring = true
	card.custom_minimum_size = Vector2(0.0, FIELD_HEIGHT)
	var pad := MenuParts.padded(FIELD_PAD.x, FIELD_PAD.y, FIELD_PAD.x * 2.0, FIELD_PAD.y)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", PLAY_ROW_GAP)
	var picture := _picture(e.id, FIELD_PICTURE)
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(picture)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", FIELD_TEXT_GAP)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", TAG_GAP)
	var name_label := MenuParts.head_text(e.display_name, FIELD_NAME_SIZE, 700, GameTheme.TEXT, TEAM_SPACING)
	name_label.name = "Name"
	title.add_child(name_label)
	if e.tag == &"dev":
		title.add_child(_centred(MenuTag.dev()))
	if later:
		title.add_child(_centred(MenuTag.later()))
	text.add_child(title)
	var blurb := _text(e.blurb, FIELD_BLURB_SIZE, 500, GameTheme.MUTED)
	blurb.name = "Blurb"
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.max_lines_visible = 2
	text.add_child(blurb)
	row.add_child(text)
	pad.add_child(row)
	card.tooltip_text = field_tip(e, _tuning)
	card.add_content(pad)
	card.set_greyed(later)
	card.pressed.connect(_pick_map.bind(e.id))
	return card


## The map's picture (its small copy, _map_texture: an eye-height view, made by tools/eye_pictures.gd) cut to `box`; a
## plain plate when the map has none.
func _picture(map_id: String, box: Vector2) -> Control:
	var texture := _map_texture(map_id)
	if texture == null:
		var plate := ColorRect.new()
		plate.color = GameTheme.CARD_HI
		plate.custom_minimum_size = box
		return plate
	var picture := MenuParts.picture(box)
	picture.texture = texture
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# drawn at a fifth of its size: smoothed from its mipmaps (the map pictures import with them, BP6)
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return picture


## The map's small copy (assets/maps/cards/<id>.jpg, 480 x 270): the page shows every map's at once, so never the
## loading screen's full-screen picture (BP7 performance).
static func _map_texture(map_id: String) -> Texture2D:
	var path := "res://assets/maps/cards/%s.jpg" % map_id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## The round tuning the page reads: the loaded one, with the Custom switches in force while Custom is picked, at the
## team size the picked map plays (MatchOptions.match_tuning).
func _round_tuning() -> SimTuning:
	return MatchOptions.match_tuning(SimTuning.load_default(), MapCatalog.shared().find(picks.map_id),
			picks.custom_rules(_settings))


## Takes the saved team colour set's HUD part when the set changed (or on the first call): whether it did.
func _follow_team_colours() -> bool:
	if _teams != null and _settings.team_colours == _teams_set:
		return false
	_teams_set = _settings.team_colours
	_teams = TeamColours.resolve(_settings.team_colours, false, null, _play_tuning.teams).hud
	return true


## A team's card in `colour`: its edge and bar when picked, and its fill tinted with it.
static func _colour_team_card(card: MenuCard, colour: Color) -> void:
	card.accent = colour
	card.picked_fill = GameTheme.CARD.lerp(colour, TEAM_TINT)
	card.bar = colour
	card.refresh()


## The rule set, a Custom switch or any setting changed (Dev content, a reset save): the round tuning is read again,
## and what reads it redrawn, the Custom rows included.
func _on_rules_changed() -> void:
	_retune()
	_list_maps()
	_refresh()


## Reads the round tuning again and redraws the rules with it (the Team size row shows the picked map's sizes).
func _retune() -> void:
	_tuning = _round_tuning()
	_tuned_map = picks.map_id
	_rules.show_tuning(_tuning)


## A map picked: its team sizes on the Team size row and its size played (the saved Custom size where it offers it,
## else its standard).
func _pick_map(map_id: String) -> void:
	picks.map_id = map_id
	_refresh()
	map_picked.emit(map_id)


func _pick_mode(mode: String) -> void:
	picks.mode = mode
	_refresh()


func _pick_team(team: int) -> void:
	picks.team = team
	_refresh()


## Lights the picks and greys what the picked map doesn't host or isn't built; rewrites the summary.
func _refresh() -> void:
	if _summary == null or _play == null:
		return
	# Another map picked (by hand, or the picked one fell back): its own team size.
	if _tuned_map != picks.map_id:
		_retune()
	for id: String in _map_cards:
		_map_cards[id].set_picked(id == picks.map_id)
	var entry := _catalog.find(picks.map_id)
	var pole: bool = _poles.get(picks.map_id, false)
	var on_field := entry != null and entry.kind != &"range"
	var kind: StringName = entry.kind if entry != null else &""
	if on_field and _last_kind == &"range":
		# The Range's Practice gives way: to your field's mode, or the field's first where there is none or it can't be
		# picked ("" is never pickable, so the fallback below takes the first).
		picks.mode = _field_mode
		_field_mode = ""
	elif kind == &"range" and _last_kind != &"range" and _last_kind != &"":
		_field_mode = picks.mode
	_last_kind = kind
	if not MatchOptions.mode_pickable(picks.mode, entry, pole):
		picks.mode = MatchOptions.DEFAULT_MODE
	if not MatchOptions.mode_pickable(picks.mode, entry, pole):
		for mode in MatchOptions.MODES:
			if MatchOptions.mode_pickable(mode, entry, pole):
				picks.mode = mode
				break
	for mode: String in _mode_cards:
		var card := _mode_cards[mode]
		card.set_greyed(not MatchOptions.mode_pickable(mode, entry, pole))
		card.set_picked(mode == picks.mode)
		var only_key := MatchOptions.only_tag_key(mode, entry)
		_only_tags[mode].visible = not only_key.is_empty()
		if not only_key.is_empty():
			_only_tags[mode].set_text(tr(only_key))
	for mode: String in _needs_pole:
		_needs_pole[mode].visible = MatchOptions.needs_pole(mode, entry, pole)
	if _follow_team_colours():
		for t in _team_cards.size():
			_colour_team_card(_team_cards[t], _teams.colours[t])
	for t in _team_cards.size():
		_team_cards[t].set_picked(t == picks.team)
	var practice := picks.mode == MatchOptions.MODE_PRACTICE
	_attack_shown = MatchOptions.POLE_MODES.has(picks.mode)
	_attack_row.modulate.a = 1.0 if _attack_shown else 0.0
	var team_parts: Array[Control] = [_team_row, _attack_room]
	MenuParts.set_unused(team_parts, _team_tag, practice)
	_rules.set_unused(practice)
	_bots.set_unused(practice)
	_play.text = tr("MENU_GO_PRACTICE" if practice else "MENU_PLAY")
	_attack_team.text = tr(MatchOptions.TEAM_KEYS[picks.team])
	var colour := _teams.colours[picks.team].lightened(TEAM_NAME_LIGHTEN)
	_attack_team.add_theme_color_override("font_color", colour)
	_bots.show_picks(_tuning.rounds.team_size, picks.rules == MatchOptions.RULES_CUSTOM)
	_summary_map = entry.display_name if entry != null else picks.map_id
	for mode: String in _mode_cards:
		var blurb_text := tr(MatchOptions.MODE_BLURB[mode])
		var blurb := blurb_text % _tuning.rounds.wins_needed if blurb_text.contains("%d") else blurb_text
		_mode_cards[mode].tooltip_text = blurb
		_mode_blurbs[mode].text = blurb
	var mates := MatchOptions.teammates_level(picks.bots, picks.teammates) if _tuning.rounds.team_size > 1 else ""
	_summary_rest = " · " + MatchOptions.summary_rest(picks.mode, picks.team, picks.bots,
			picks.custom_rules(_settings), mates, _tuning.rounds.team_size)
	_play_name.text = _summary_map.to_upper()
	_summary.text = _summary_rest.trim_prefix(" · ")
	_summary.tooltip_text = summary_text()
	_play_picture.texture = _map_texture(picks.map_id)
