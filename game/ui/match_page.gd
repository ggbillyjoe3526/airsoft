class_name MatchPage
extends Control
## The Match page's body (concept `match.png`, docs/records/MN2.md), laid out on one grid of equal columns (UI1 round 2):
## the map picture cards in a row across the top, one a column; under them the modes, the rules (MatchRulesBox:
## Skirmish's chips or Custom's rows, docs/records/CR2.md), and your team over the bots' levels (MatchBotsBox: Opponents
## and Teammates, docs/records/MN3.md), each column's left edge under a map card's; a one-line summary bottom left and the
## slanted PLAY bottom right. A map that can't load (MapData's problems) is greyed with LATER, as a mode that isn't built. Picks go
## into the MatchPicks it is given (kept by the entry scene across the menus' being freed). What reads the round tuning
## (the Elimination card, the maps a team size can't load) reads the Custom switches while Custom is picked, and the
## team size the picked map plays (data/maps.md: its standard, or the saved Custom size where it offers it).
## `play_pressed` starts the match.
## Everything is drawn for 1920x1080 and the window's stretch scales it.

signal play_pressed
## A field was picked (the menus' backdrop follows it).
signal map_picked(map_id: String)

const MARGIN_X := 56
const TOP := 40
## The gap under the map cards, before the row of columns (px).
const ROW_GAP := 40
const SECTION_GAP := 30
const HEADING_GAP := 16
const PLAY_RIGHT := 56.0
const PLAY_BOTTOM := 48.0
const SUMMARY_LEFT := 56.0
const SUMMARY_BOTTOM := 60.0
const SUMMARY_SIZE := 18
## The page's grid: at least this many equal columns, MAP_GAP apart; the map cards share its width in one row (a fourth
## map makes a fourth column), the columns under them its left edges. A card's picture is this tall.
const GRID_COLUMNS := 3
const MAP_GAP := 20
const MAP_IMAGE_HEIGHT := 230.0
const MAP_TEXT_PAD := Vector4(16.0, 12.0, 16.0, 14.0)
const MAP_TEXT_GAP := 6
const MAP_NAME_SIZE := 22
const TAG_GAP := 8
const MODE_GAP := 8
## The room a mode's button keeps at each side of its name (px).
const MODE_PAD_X := 24
const TEAM_GAP := 12
const TEAM_HEIGHT := 48.0
const TEAM_NAME_SIZE := 18
## The room a team's name keeps at each side: past its colour bar on the left (px).
const TEAM_TEXT_PAD := 24
## How much of a team's colour tints a picked team card.
const TEAM_TINT := 0.06
## Attack / Defend's line under the team cards: its size, and the team's name lightened to read on the page.
const ATTACK_LINE_SIZE := 16
const TEAM_NAME_LIGHTEN := 0.25
## A mode card's "Needs a map with a flagpole" in a dimmed yellow, and its size.
const NEEDS_DARKEN := 0.3
const NEEDS_SIZE := 14
## The summary line's width: it never changes as the picks do.
const SUMMARY_WIDTH := 1100.0
## The Play button's words, one for a match and one for Practice.
const PLAY_KEYS: Array[String] = ["MENU_PLAY", "MENU_GO_PRACTICE"]

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
var _maps_grid: GridContainer = null
## The row of columns under the maps (modes, rules, your team and bots), on the maps' grid.
var _columns: HBoxContainer = null
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
## The Custom size the maps were last checked for (0 under Skirmish): each is checked at the size it would play.
var _checked_custom: int = -1
## The summary line: the map in bold, then the rest.
var _summary: RichTextLabel = null
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
	# measured once in the tree too: the button's theme_changed can come while the page is not yet under the menus'
	# theme, and its children's theme is only settled after this
	_fit_play.call_deferred()
	if not _settings.changed.is_connected(_on_rules_changed):
		_settings.changed.connect(_on_rules_changed)


func _exit_tree() -> void:
	if _settings.changed.is_connected(_on_rules_changed):
		_settings.changed.disconnect(_on_rules_changed)


func play_button() -> Button:
	return _play


func focus_play() -> void:
	_play.grab_focus()


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
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", MARGIN_X)
	margin.add_theme_constant_override("margin_right", MARGIN_X)
	margin.add_theme_constant_override("margin_top", TOP)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", ROW_GAP)
	margin.add_child(page)
	page.add_child(_build_maps())
	_columns = HBoxContainer.new()
	_columns.name = "Columns"
	_columns.add_theme_constant_override("separation", MAP_GAP)
	page.add_child(_columns)
	_column(_build_modes())
	_rules = MatchRulesBox.new(picks, _settings, _tuning)
	_rules.changed.connect(_on_rules_changed)
	_column(_rules)
	_column(_build_side())
	_build_foot()


## Adds `c` as one of the grid's equal columns.
func _column(c: Control) -> void:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = 1.0
	_columns.add_child(c)


func _section(heading: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", HEADING_GAP)
	box.add_child(heading)
	return box


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", GameTheme.spaced_font(800, GameTheme.SPACING_HEADING, GameTheme.HEADING_SIZE))
	label.add_theme_font_size_override("font_size", GameTheme.HEADING_SIZE)
	label.add_theme_color_override("font_color", GameTheme.MUTED)
	return label


func _text(text: String, size: int, weight: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", GameTheme.font(weight))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _build_maps() -> Control:
	var column := _section(_heading(tr("MENU_MAP")))
	_maps_grid = GridContainer.new()
	_maps_grid.columns = GRID_COLUMNS
	_maps_grid.add_theme_constant_override("h_separation", MAP_GAP)
	_maps_grid.add_theme_constant_override("v_separation", MAP_GAP)
	column.add_child(_maps_grid)
	return column


func _build_modes() -> Control:
	var column := _section(_heading(tr("MENU_MODE")))
	_modes_box = VBoxContainer.new()
	_modes_box.add_theme_constant_override("separation", MODE_GAP)
	column.add_child(_modes_box)
	var cards: Array[Button] = []
	for mode in MatchOptions.MODES:
		# a row of one choice-height button, one width for the three (owner, 2026-10-29), and its tags after it: a tag
		# showing or going moves nothing (UI1: the cards were 464 x 64 bars with one word)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", TAG_GAP)
		var card := MenuCard.new()
		card.name = "Mode_" + mode
		card.text = tr(MatchOptions.MODE_NAME[mode]).to_upper()
		card.ring = true
		card.text_pad = MODE_PAD_X
		card.refresh()
		card.custom_minimum_size = Vector2(0.0, GameTheme.CONTROL_HEIGHT)
		card.add_theme_font_override("font", GameTheme.spaced_font(800, GameTheme.SPACING_TAB, GameTheme.CONTROL_SIZE))
		card.add_theme_font_size_override("font_size", GameTheme.CONTROL_SIZE)
		card.add_theme_constant_override("outline_size", 0)
		for colour: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color",
				"font_focus_color"]:
			card.add_theme_color_override(colour, GameTheme.TEXT)
		card.pressed.connect(_pick_mode.bind(mode))
		row.add_child(card)
		if not MatchOptions.BUILT_MODES.has(mode):
			row.add_child(_centred(MenuTag.later()))
		var only := MenuTag.grey(MatchOptions.FIELDS_ONLY_KEY)
		only.name = "OnlyTag"
		only.visible = false
		row.add_child(_centred(only))
		_only_tags[mode] = only
		if MatchOptions.POLE_MODES.has(mode):
			var needs := _text(tr("MENU_NEEDS_POLE"), NEEDS_SIZE, 700, GameTheme.ACCENT.darkened(NEEDS_DARKEN))
			needs.name = "NeedsPole"
			needs.visible = false
			needs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(needs)
			_needs_pole[mode] = needs
		_modes_box.add_child(row)
		_mode_cards[mode] = card
		cards.append(card)
	ButtonWidth.group(cards)
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
		# only its name: a card of words, so the two are one width, the longer name's (owner, 2026-10-29)
		card.text = tr(MatchOptions.TEAM_KEYS[t]).to_upper()
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.text_pad = TEAM_TEXT_PAD
		card.add_theme_font_override("font", GameTheme.font(800))
		card.add_theme_font_size_override("font_size", TEAM_NAME_SIZE)
		for colour: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color",
				"font_focus_color"]:
			card.add_theme_color_override(colour, GameTheme.TEXT)
		_colour_team_card(card, _teams.colours[t])
		card.pressed.connect(_pick_team.bind(t))
		team_row.add_child(card)
		_team_cards.append(card)
	ButtonWidth.group(_team_cards)
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


func _build_foot() -> void:
	var summary := HBoxContainer.new()
	summary.name = "Summary"
	summary.add_theme_constant_override("separation", 0)
	summary.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	summary.grow_vertical = Control.GROW_DIRECTION_BEGIN
	summary.offset_left = SUMMARY_LEFT
	summary.offset_bottom = -SUMMARY_BOTTOM
	_summary = RichTextLabel.new()
	_summary.bbcode_enabled = true
	_summary.fit_content = true
	_summary.scroll_active = false
	_summary.autowrap_mode = TextServer.AUTOWRAP_OFF
	_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary.custom_minimum_size.x = SUMMARY_WIDTH
	_summary.add_theme_font_override("normal_font", GameTheme.font(600))
	_summary.add_theme_font_override("bold_font", GameTheme.font(800))
	_summary.add_theme_font_size_override("normal_font_size", SUMMARY_SIZE)
	_summary.add_theme_font_size_override("bold_font_size", SUMMARY_SIZE)
	_summary.add_theme_color_override("default_color", GameTheme.MUTED)
	summary.add_child(_summary)
	add_child(summary)
	_play = Button.new()
	_play.name = "Play"
	_play.theme_type_variation = GameTheme.MAIN_BUTTON
	_play.text = tr("MENU_PLAY")
	_play.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_play.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_play.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_play.offset_right = -PLAY_RIGHT
	_play.offset_bottom = -PLAY_BOTTOM
	_play.pressed.connect(func() -> void: play_pressed.emit())
	_play.theme_changed.connect(_fit_play)
	add_child(_play)


## PLAY and PRACTICE take one width, the wider's, so the button never changes size as the mode does (UI1).
func _fit_play() -> void:
	var now := _play.text
	var widest := 0.0
	for key: String in PLAY_KEYS:
		_play.text = tr(key)
		widest = maxf(widest, _play.get_minimum_size().x)
	_play.text = now
	_play.custom_minimum_size.x = widest


## A margin container with the given margins (left, top, right, bottom).
func _padded(left: float, top: float, right: float, bottom: float) -> MarginContainer:
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", int(left))
	pad.add_theme_constant_override("margin_top", int(top))
	pad.add_theme_constant_override("margin_right", int(right))
	pad.add_theme_constant_override("margin_bottom", int(bottom))
	return pad


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
		_maps_grid.remove_child(_map_cards[id])
		_map_cards[id].queue_free()
	_map_cards.clear()
	_unloadable = problems
	# one row: a column a map, at least the grid's
	_maps_grid.columns = maxi(GRID_COLUMNS, ordered.size())
	for e in ordered:
		var card := _map_card(e, MAP_IMAGE_HEIGHT, problems[e.id])
		_maps_grid.add_child(card)
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
			return
	_play.disabled = true


func _map_card(e: MapCatalog.Entry, image_height: float, later: bool) -> MenuCard:
	var card := MenuCard.new()
	card.name = "Map_" + e.id
	card.ring = true
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, image_height + MAP_TEXT_PAD.y + MAP_TEXT_PAD.w + MAP_NAME_SIZE * 1.4 +
			GameTheme.BORDER * 2)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.add_child(_picture(e.id, image_height))
	var pad := _padded(MAP_TEXT_PAD.x, MAP_TEXT_PAD.y, MAP_TEXT_PAD.z, MAP_TEXT_PAD.w)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", MAP_TEXT_GAP)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", TAG_GAP)
	var name_label := _text(e.display_name.to_upper(), MAP_NAME_SIZE, 800, GameTheme.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(name_label)
	if e.tag == &"dev":
		title.add_child(MenuTag.dev())
	if later:
		title.add_child(MenuTag.later())
	text.add_child(title)
	# the map in a line: the card's tooltip (UI1)
	card.tooltip_text = e.blurb
	pad.add_child(text)
	column.add_child(pad)
	card.add_content(column)
	card.set_greyed(later)
	card.pressed.connect(_pick_map.bind(e.id))
	return card


## The map's picture (assets/maps/<id>.jpg, made by tools/map_pictures.gd) cropped to the card; a plain plate when the
## map has none.
func _picture(map_id: String, height: float) -> Control:
	var path := "res://assets/maps/%s.jpg" % map_id
	if not ResourceLoader.exists(path):
		var plate := ColorRect.new()
		plate.color = GameTheme.CARD_HI
		plate.custom_minimum_size = Vector2(0.0, height)
		return plate
	var picture := TextureRect.new()
	picture.texture = load(path) as Texture2D
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.custom_minimum_size = Vector2(0.0, height)
	return picture


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
		_mode_cards[mode].tooltip_text = blurb_text % _tuning.rounds.wins_needed if blurb_text.contains("%d") \
				else blurb_text
	var mates := MatchOptions.teammates_level(picks.bots, picks.teammates) if _tuning.rounds.team_size > 1 else ""
	_summary_rest = " · " + MatchOptions.summary_rest(picks.mode, picks.team, picks.bots,
			picks.custom_rules(_settings), mates, _tuning.rounds.team_size)
	_summary.text = "[b][color=#%s]%s[/color][/b]%s" % [GameTheme.TEXT.to_html(false), _summary_map.replace("[", "[lb]"),
			_summary_rest.replace("[", "[lb]")]
