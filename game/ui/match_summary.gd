class_name MatchSummary
extends Control
## The match summary (concept `summary.png`; the browser game's result screen), once the match's last round table makes
## way: under the match's WON / LOST stamp, on the left everyone's numbers for the match (MatchStats, as on Tab), in
## the middle the XP card as the HUD already shows it (AR1), on the right your records for this difficulty and mode
## (SummaryRecords), What got you for each time you were hit (SummaryHits) and the next Pro tip (Hard bots only), and at
## the foot "A new match starts shortly · click to start now". The HUD opens it at the match's end and closes it when
## the next match starts. At a HUD size too large for the screen's width the HUD holds its panels and the XP card
## smaller (`set_fit`).

## The table: the player's column width (px), then the columns after it: header keys and widths (px).
const PLAYER_WIDTH := 120.0
const COLUMNS: Array[StringName] = [&"HUD_COL_HITS", &"HUD_COL_TIMES_HIT", &"HUD_COL_BBS", &"HUD_COL_ACCURACY",
		&"HUD_COL_TIME"]
const WIDTHS: Array[float] = [64.0, 104.0, 100.0, 100.0, 116.0]
## The right-hand column's width (px), the gap either side of the XP card, between panels, and the foot line's margin.
const SIDE_WIDTH := 520.0
const GAP := 22.0
const PANEL_GAP := 18
const FOOT_MARGIN := 40.0
const FOOT_SIZE := 15
const PAD := Vector2i(24, 18)
const BACKING := 0.9
const TITLE_SIZE := 13
const ROW_SIZE := 17
const ROW_HEIGHT := 36
const TIP_SIZE := 18
const TIP_BAR := 4
const NO_ACCURACY := "–"

var _teams: TeamConfig = null
var _team_names := PackedStringArray()
var _no_colours: Array[Color] = []
var _names := PackedStringArray()
var _table: HudTable = null
var _side: VBoxContainer = null
var _records: SummaryRecords = null
var _hits: SummaryHits = null
var _tip_box: PanelContainer = null
var _tip: Label = null
var _foot: Label = null
var _open: bool = false
## How far under the screen's middle the panels start, and the share of their size they are held at (set_fit).
var _top: float = 0.0
var _fit: float = 1.0


## `top` is how far under the screen's middle the panels start (px), level with the XP card.
func setup(teams: TeamConfig, mate_colour: Color, top: float) -> void:
	name = "MatchSummary"
	_teams = teams
	for key in teams.names:
		_team_names.append(HudStyle.caps(key))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_table = HudTable.new()
	var heads := PackedStringArray()
	for key in COLUMNS:
		heads.append(HudStyle.caps(key))
	_table.setup(PLAYER_WIDTH, heads, PackedFloat32Array(WIDTHS), mate_colour)
	_top = top
	_pin(_table, -XpCard.WIDTH * 0.5 - GAP, top, Control.GROW_DIRECTION_BEGIN)
	_table.pivot_offset_ratio = Vector2(1.0, 0.0) # held smaller about its top corner by the XP card
	add_child(_table)
	_side = VBoxContainer.new()
	_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side.add_theme_constant_override("separation", PANEL_GAP)
	_side.custom_minimum_size.x = SIDE_WIDTH
	_pin(_side, XpCard.WIDTH * 0.5 + GAP, top, Control.GROW_DIRECTION_END)
	add_child(_side)
	_records = SummaryRecords.new()
	_side.add_child(_records)
	_hits = SummaryHits.new()
	_side.add_child(_hits)
	_tip_box = PanelContainer.new()
	_tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := panel_box()
	box.border_color = GameTheme.ACCENT
	box.border_width_top = 0
	box.border_width_right = 0
	box.border_width_bottom = 0
	box.border_width_left = TIP_BAR
	_tip_box.add_theme_stylebox_override("panel", box)
	_side.add_child(_tip_box)
	var tip_column := column(_tip_box)
	title(tip_column, "HUD_PRO_TIP")
	_tip = HudStyle.label(tip_column, TIP_SIZE, 600, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_foot = HudStyle.label(self, FOOT_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, HudStyle.SPACING_ROUND)
	_foot.text = HudStyle.caps("SUM_NEXT")
	_foot.add_theme_stylebox_override("normal", HudStyle.panel_box(HudStyle.BACKING_AIM, 12, 4))
	_foot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, FOOT_MARGIN)
	_foot.grow_horizontal = Control.GROW_DIRECTION_BOTH


## The panels' and the XP card's row across the screen at their full size (px): the card, the gaps and the wider panel
## on each side (they sit either side of the card, level, so the row is symmetric).
func row_width() -> float:
	var panel := maxf(_table.get_combined_minimum_size().x, maxf(SIDE_WIDTH, _side.get_combined_minimum_size().x))
	return XpCard.WIDTH + (GAP + panel) * 2.0


## Holds the panels at `fit` (0..1) of their size about their top corners by the XP card, with the gaps to it, so the
## row fits the screen's width at a large HUD size (the HUD holds the card at the same share). 1 is as built.
func set_fit(fit: float) -> void:
	if is_equal_approx(fit, _fit):
		return
	_fit = fit
	_pin(_table, -(XpCard.WIDTH * 0.5 + GAP) * fit, _top, Control.GROW_DIRECTION_BEGIN)
	_pin(_side, (XpCard.WIDTH * 0.5 + GAP) * fit, _top, Control.GROW_DIRECTION_END)
	_table.scale = Vector2.ONE * fit
	_side.scale = Vector2.ONE * fit


## Moves the panels to start `top` px under the screen's middle (the XP card moves with them in the HUD).
func set_top(top: float) -> void:
	if is_equal_approx(top, _top):
		return
	_top = top
	_pin(_table, -(XpCard.WIDTH * 0.5 + GAP) * _fit, _top, Control.GROW_DIRECTION_BEGIN)
	_pin(_side, (XpCard.WIDTH * 0.5 + GAP) * _fit, _top, Control.GROW_DIRECTION_END)


## The taller of the two panels at their full size (px).
func column_height() -> float:
	return maxf(_table.get_combined_minimum_size().y, _side.get_combined_minimum_size().y)


func fit() -> float:
	return _fit


func set_names(names: PackedStringArray) -> void:
	_names = names


## A new match: forgets the hits on you.
func clear_hits() -> void:
	_hits.clear()


## You were hit in round `number` (`facts`, by `shooter_name` in their team's `colour`, the bot's `note`).
func add_hit(number: int, facts: HitFacts, shooter_name: String, colour: Color, note: String) -> void:
	_hits.add(number, facts, shooter_name, colour, note)


## Fills it for the match `state` just finished, as `stats` stand, from `you`'s side: What got you only when
## `show_hits`, the Pro tip `tip` ("" for none). The records come later with set_records (only a counted match has them).
func open(state: GameState, stats: MatchStats, you: Character, show_hits: bool, tip: String) -> void:
	_open = true
	_fill_table(state, stats, you)
	_records.visible = false
	_hits.visible = show_hits
	if show_hits:
		_hits.fill()
	_tip_box.visible = tip != ""
	_tip.text = tip


## Your records for `heading` ("Your records · Hard Elimination"): `win_loss` there, with what this match changed
## (`news`; null when it stays out of the records).
func set_records(records: Records, win_loss: PackedInt32Array, news: Records.News, heading: String) -> void:
	_records.fill(records, win_loss, news, heading)
	_records.visible = true


func close() -> void:
	_open = false
	visible = false


func is_open() -> bool:
	return _open


func table() -> HudTable:
	return _table


func records() -> SummaryRecords:
	return _records


func hits() -> SummaryHits:
	return _hits


## The Pro tip shown ("" for none): for tests.
func tip_text() -> String:
	return _tip.text if _tip_box.visible else ""


func foot_text() -> String:
	return _foot.text


## A summary panel's box: navy with a thin edge, as the XP card's.
static func panel_box() -> StyleBoxFlat:
	return HudStyle.navy_box(BACKING, GameTheme.LINE, PAD.x, PAD.y)


## A column inside `parent`.
static func column(parent: Control, gap: int = 10) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_theme_constant_override("separation", gap)
	parent.add_child(c)
	return c


## A panel's yellow title in capitals (`key` translated, or `text` when given).
static func title(parent: Control, key: String, text: String = "") -> Label:
	var l := HudStyle.label(parent, TITLE_SIZE, 800, GameTheme.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, HudStyle.SPACING_ROUND)
	l.text = text.to_upper() if text != "" else HudStyle.caps(key)
	return l


## A row with a rule above it (`rule`, shared by a panel's rows), its words on the left: returns the row's line, for
## its values on the right.
static func row(parent: Control, rule: StyleBox, words: String) -> HBoxContainer:
	var r := PanelContainer.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_stylebox_override("panel", rule)
	r.custom_minimum_size.y = ROW_HEIGHT
	parent.add_child(r)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 10)
	r.add_child(line)
	var left := HudStyle.label(line, ROW_SIZE, 500, GameTheme.MUTED.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT)
	left.text = words
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return line


## The rule over each row: a one-pixel line on top.
static func row_rule() -> StyleBoxFlat:
	var rule := GameTheme.box(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 0)
	rule.border_width_top = 1
	rule.border_color = GameTheme.LINE
	return rule


## Pins `c` to the screen's middle: its near edge `x` px across from it (growing away along `grow`), `y` px down.
static func _pin(c: Control, x: float, y: float, grow: Control.GrowDirection) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = x
	c.offset_right = x
	c.offset_top = y
	c.offset_bottom = y
	c.grow_horizontal = grow
	c.grow_vertical = Control.GROW_DIRECTION_END


func _fill_table(state: GameState, stats: MatchStats, you: Character) -> void:
	_table.begin(HudStyle.caps("SUM_THE_MATCH"))
	for i in 2:
		var side := you.team if i == 0 else 1 - you.team
		_table.add_team(_teams.colours[side], _team_names[side], str(state.round_state.score[side]), "")
		if side == you.team:
			_add_row(you, stats, you)
		for c in state.characters:
			if c.team == side and c.id != you.id:
				_add_row(c, stats, you)
	_table.finish()


func _add_row(c: Character, stats: MatchStats, you: Character) -> void:
	var m := stats.match_of(c.id)
	var accuracy := m.accuracy()
	var cells := PackedStringArray([str(m.hits), str(m.times_hit), str(m.bbs_fired),
			NO_ACCURACY if accuracy < 0.0 else "%d%%" % roundi(accuracy * 100.0), HudStyle.clock_text(roundi(m.time_in_play))])
	var name_text := tr("HUD_YOU") if c.id == you.id \
			else (_names[c.id] if c.id < _names.size() and _names[c.id] != "" else tr(_teams.names[c.team]))
	_table.add_row(name_text, c.id == you.id, c.team == you.team and c.id != you.id, false, cells, _no_colours)
