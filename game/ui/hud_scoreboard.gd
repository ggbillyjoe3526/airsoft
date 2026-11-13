class_name HudScoreboard
extends VBoxContainer
## The scoreboard while Tab is held (concept `scoreboard.png`; the browser game's hold-key board): the map, the mode,
## the bots and the size, the round and its time left; each team with its score and how many are in play, your team
## first and you first in it; per player this round's hits, then the match's hits, times hit, BBs fired, accuracy and
## time in play (MatchStats), those out this round greyed with a raised hand. Against Hard bots a Pro tip under it, one
## per round in order. The field stays live under it: it refills at once when a round, the clock's second or who is in
## play changes, and when only the numbers moved (each BB fired moves them) at most every HudConfig.board_refill_gap.

## The player's column width (px), then the columns after it: header keys and widths (px). "This round" is shaded.
## Compact (owner, 2026-11-03: the board was too big): 30 px rows, so a 6v6 board ends well above the replica panel.
const PLAYER_WIDTH := 200.0
const COLUMNS: Array[StringName] = [&"HUD_COL_THIS_ROUND", &"HUD_COL_HITS", &"HUD_COL_TIMES_HIT", &"HUD_COL_BBS",
		&"HUD_COL_ACCURACY", &"HUD_COL_TIME"]
const WIDTHS: Array[float] = [120.0, 60.0, 110.0, 110.0, 110.0, 130.0]
const THIS_ROUND := 0
## The Pro tips (the browser game's PRO_TIPS), one per round, round 1 first, then round again.
const PRO_TIPS: Array[StringName] = [&"PRO_TIP_1", &"PRO_TIP_2", &"PRO_TIP_3", &"PRO_TIP_4"]
const TIP_SIZE := 18
const TIP_LABEL_SIZE := 13
const TIP_PAD := Vector2i(16, 14)
const TIP_GAP := 18
const NO_ACCURACY := "–"

var _cfg: HudConfig = null
var _teams: TeamConfig = null
## The teams' names as the board shows them, and one empty colours list every row shares (no cell has its own).
var _team_names := PackedStringArray()
var _no_colours: Array[Color] = []
var _table: HudTable = null
var _tip_box: PanelContainer = null
var _tip: Label = null
var _names := PackedStringArray()
var _map_name := ""
var _sub := ""
var _tips: bool = false
## Attack / Defend's longest overtime (s), for the heading's OT countdown.
var _max_overtime: float = 0.0
## The most a plant under way at the buzzer may run on in Plant The Bomb (PlantConfig.max_overtime).
var _plant_overtime: float = 0.0
## What the board last showed: the numbers' version, the round, the clock's second and who was in play (bits by id).
var _shown_version: int = -1
var _shown_round: int = -1
var _shown_second: int = -1
var _shown_in_play: int = -1
var _filled_at: float = 0.0


func setup(cfg: HudConfig, teams: TeamConfig, mate_colour: Color, max_overtime: float,
		plant_overtime: float = -1.0) -> void:
	name = "HudScoreboard"
	_cfg = cfg
	_teams = teams
	for key in teams.names:
		_team_names.append(HudStyle.caps(key))
	_max_overtime = max_overtime
	_plant_overtime = plant_overtime if plant_overtime >= 0.0 else max_overtime
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 0)
	visible = false
	_table = HudTable.new()
	var heads := PackedStringArray()
	for key in COLUMNS:
		heads.append(HudStyle.caps(key))
	_table.setup(PLAYER_WIDTH, heads, PackedFloat32Array(WIDTHS), mate_colour, THIS_ROUND)
	add_child(_table)
	_tip_box = PanelContainer.new()
	_tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := HudStyle.panel_box(HudStyle.BACKING_CLOCK, TIP_PAD.x, TIP_PAD.y)
	box.border_color = GameTheme.LINE
	box.border_width_top = 1
	_tip_box.add_theme_stylebox_override("panel", box)
	_tip_box.visible = false
	add_child(_tip_box)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", TIP_GAP)
	_tip_box.add_child(row)
	var label := HudStyle.label(row, TIP_LABEL_SIZE, 800, GameTheme.ACCENT, HORIZONTAL_ALIGNMENT_LEFT,
			HudStyle.SPACING_ROUND)
	label.text = HudStyle.caps("HUD_PRO_TIP")
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tip = HudStyle.label(row, TIP_SIZE, 600, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## The names by character id ("" for you), the map's name, the line after it ("Elimination · Hard bots · 3 v 3"), and
## whether the Pro tips show (opponents at Hard).
func set_match(names: PackedStringArray, map_name: String, sub: String, tips: bool) -> void:
	_names = names
	_map_name = map_name.to_upper()
	_sub = sub.to_upper()
	_tips = tips
	_shown_version = -1


## Shows the board (`show`) as `state` and `stats` stand, as `you` see it; refills only when something on it changed.
## The clock's second is negative in overtime (-1 - the OT seconds left), so the key moves then too.
func update(state: GameState, stats: MatchStats, you: Character, show: bool) -> void:
	visible = show
	if not show:
		return
	var rs := state.round_state
	# In overtime (Attack / Defend's at the rope, Elimination's at the flag) the clock stands at 0 and the OT countdown
	# runs instead (as the score bar shows).
	var overtime := HudStyle.overtime_clock(rs, _plant_overtime if rs.mode == RoundState.Mode.PLANT_THE_BOMB
			else _max_overtime)
	var second := -1 - overtime if overtime >= 0 else ceili(rs.clock)
	var in_play := 0
	for c in state.characters:
		if Elimination.is_in_play(c):
			in_play |= 1 << c.id
	if rs.number == _shown_round and second == _shown_second and in_play == _shown_in_play \
			and (stats.version == _shown_version or state.time - _filled_at < _cfg.board_refill_gap):
		return
	_filled_at = state.time
	_shown_version = stats.version
	_shown_round = rs.number
	_shown_second = second
	_shown_in_play = in_play
	_fill(state, stats, you, second)


func table() -> HudTable:
	return _table


## The Pro tip shown ("" when none): for tests.
func tip_text() -> String:
	return _tip.text if _tip_box.visible else ""


## The Pro tip key for round `number` (1 first), cycling through PRO_TIPS.
static func tip_for(number: int) -> StringName:
	return PRO_TIPS[(maxi(1, number) - 1) % PRO_TIPS.size()]


func _fill(state: GameState, stats: MatchStats, you: Character, second: int) -> void:
	var rs := state.round_state
	_table.begin("")
	# Overtime, or in Plant The Bomb the armed bomb's fuse
	var over_key := "HUD_BOARD_ROUND_BOMB" if rs.mode == RoundState.Mode.PLANT_THE_BOMB and rs.plant.planted() \
			else "HUD_BOARD_ROUND_OT"
	var when := tr("HUD_BOARD_ROUND_LEFT") % [rs.number, HudStyle.clock_text(second)] if second >= 0 \
			else tr(over_key) % [rs.number, HudStyle.clock_text(-1 - second)]
	_table.heading(_map_name, _sub, when.to_upper())
	for i in 2:
		var side := you.team if i == 0 else 1 - you.team
		var count := 0
		var playing := 0
		for c in state.characters:
			if c.team == side:
				count += 1
				if Elimination.is_in_play(c):
					playing += 1
		var note := tr("HUD_BOARD_IN_PLAY") % [playing, count]
		if side == you.team:
			note = tr("HUD_BOARD_YOUR_TEAM") % note
		_table.add_team(_teams.colours[side], _team_names[side], str(rs.score[side]), note.to_upper())
		if side == you.team:
			_add_row(you, stats, you)
		for c in state.characters:
			if c.team == side and c.id != you.id:
				_add_row(c, stats, you)
	_table.finish()
	_tip_box.visible = _tips
	if _tips:
		_tip.text = tr(tip_for(rs.number))
	_tip_box.custom_minimum_size.x = _table.size.x


func _add_row(c: Character, stats: MatchStats, you: Character) -> void:
	var m := stats.match_of(c.id)
	var accuracy := m.accuracy()
	var cells := PackedStringArray([str(stats.round_of(c.id).hits), str(m.hits), str(m.times_hit), str(m.bbs_fired),
			NO_ACCURACY if accuracy < 0.0 else "%d%%" % roundi(accuracy * 100.0), HudStyle.clock_text(roundi(m.time_in_play))])
	var name_text := tr("HUD_YOU") if c.id == you.id \
			else (_names[c.id] if c.id < _names.size() and _names[c.id] != "" else tr(_teams.names[c.team]))
	_table.add_row(name_text, c.id == you.id, c.team == you.team and c.id != you.id, not Elimination.is_in_play(c),
			cells, _no_colours)
