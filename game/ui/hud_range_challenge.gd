class_name HudRangeChallenge
extends Control
## The practice range's timed challenge on the HUD (concepts `challenge-ready.png`, `challenge-run.png`,
## `challenge-time.png`, `challenge-time-notkept.png`), read from GameState.challenge and its CHALLENGE cues. Ready:
## "Shoot START to begin" with the best so far. Countdown and run: the bar at the top, your hits (yellow) beside the
## clock and the best, and the banner: the countdown's number, then GO!. Time: TIME! with the run's hits, shots and
## misses, and NEW BEST, or NOT KEPT (DEV SETTINGS) for a run a Dev setting changed (never kept); it stays up RESULT_TIME,
## the bar with it, then the START line returns. Text is rebuilt only when what it shows changes. Free practice shows
## none of it.

## The bar's top margin, height and blocks' widths, and the clock's smallest width and padding (px at 1080p).
const BAR_TOP := 22.0
const BAR_HEIGHT := 73.0
const BLOCK_WIDTH := 136.0
const CLOCK_WIDTH := 206.0
const CLOCK_PAD := Vector4(26.0, 6.0, 26.0, 8.0)
## Type sizes: a block's number and its label, the clock's time and its words.
const NUMBER_SIZE := 34
const LABEL_SIZE := 13
const LABEL_SPACING := 0.1
const TIME_SIZE := 40
const CLOCK_WORDS_SIZE := 14
## The ready line's top, its padding (left and right, top, bottom) and its type sizes: the kicker and the line.
const HINT_TOP := 330.0
const HINT_PAD := Vector4(26.0, 12.0, 26.0, 14.0)
const HINT_KICKER_SIZE := 13
const HINT_SIZE := 28
const HINT_GAP := 4
## The lit orange the targets glow in and the ready line's rule and kicker take (the concept's, a shade warmer than RangeViewConfig's lit colour).
const LIT := Color("ff9a2e")
## The banners: the countdown's and GO!'s top, TIME!'s top, their padding (the concept's `.banner`), the big words' size.
const BANNER_TOP := 300.0
const RESULT_TOP := 190.0
const BANNER_PAD := Vector4(70.0, 20.0, 70.0, 20.0)
## The result: the gap above its figures (past the banner's own gap), a figure's size and label size, a cell's side
## padding and the rule between cells, the gap above the tag and the two tags' type sizes and paddings.
const RESULT_GAP := 10
const RESULT_SIZE := 54
const RESULT_LABEL_SIZE := 14
const RESULT_LABEL_GAP := 6
const CELL_PAD := 39
const CELL_RULE := 2
const TAG_GAP := 18
const NEW_BEST_SIZE := 20
const NEW_BEST_PAD := Vector2i(18, 6)
const NOT_KEPT_SIZE := 16
const NOT_KEPT_PAD := Vector2i(14, 5)
## How long GO! and the TIME! result stay up (s).
const GO_TIME := 0.8
const RESULT_TIME := 6.0

## The concept's line heights (a share of the type size) where it sets one under the font's own: a figure, the clock's
## time, and the banner's big words.
const FIGURE_LINE := 1.0
const TIME_LINE := 1.05
const BIG_LINE := 1.0

## What the banner says.
enum Banner { NONE, COUNT, GO, TIME }

var _player_id: int = 0
var _run_time: int = 60
var _bar: HBoxContainer = null
var _hits: Label = null
var _clock: Label = null
var _best: Label = null
var _hint: PanelContainer = null
var _hint_line: RichTextLabel = null
var _banner: HudBanner = null
var _title: Label = null
var _result: Control = null
var _result_hits: Label = null
var _result_shots: Label = null
var _result_missed: Label = null
var _tag_new: PanelContainer = null
var _tag_kept: PanelContainer = null
var _lane_banner: VBoxContainer = null
var _kind: Banner = Banner.NONE
var _count: int = 0
var _banner_left: float = 0.0
## What the bar and the ready line show now, so text is rebuilt only on a change.
var _shown_hits: int = -1
var _shown_time: int = -1
var _shown_best: int = -1
var _shown_hint_best: int = -1
## The banner on screen and its countdown number, so a frame with the same banner does no string work.
var _shown_kind: Banner = Banner.NONE
var _shown_count: int = -1


## Built for `range_cfg`'s run length and `player_id`'s cues.
func setup(range_cfg: RangeConfig, player_id: int) -> void:
	name = "RangeChallenge"
	_player_id = player_id
	_run_time = ceili(range_cfg.challenge_run_time)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_bar()
	_build_hint()
	_build_banner()
	_bar.visible = false
	_hint.visible = false
	_banner.visible = false


## The bar's three figures as shown: hits, the clock and the best.
func bar_texts() -> PackedStringArray:
	return PackedStringArray([_hits.text, _clock.text, _best.text])


func bar_visible() -> bool:
	return _bar.visible


## The ready line as shown ("" while it is hidden).
func hint_text() -> String:
	return _hint_line.get_parsed_text() if _hint.visible else ""


## The banner's words ("" while it is hidden): the countdown's number, GO!, or TIME! and the run's figures.
func banner_text() -> String:
	if not _banner.visible:
		return ""
	if _kind != Banner.TIME:
		return _title.text
	var out := "%s %s %s %s" % [_title.text, _result_hits.text, _result_shots.text, _result_missed.text]
	if _tag_new.visible:
		out += " " + tr("CHALLENGE_NEW_BEST").to_upper()
	elif _tag_kept.visible:
		out += " " + tr("CHALLENGE_NOT_KEPT").to_upper()
	return out


func banner_kind() -> Banner:
	return _kind


## The tick's cues: the countdown's seconds, GO and TIME with the run's result.
func on_tick(state: GameState) -> void:
	var events := state.events
	for i in events.count:
		var e := events.items[i]
		if e.kind != GameEvent.Kind.CHALLENGE or e.actor != _player_id:
			continue
		match e.value:
			RangeChallenge.Cue.COUNT:
				_kind = Banner.COUNT
				_count = e.value2
				_banner_left = INF
			RangeChallenge.Cue.GO:
				_kind = Banner.GO
				_banner_left = GO_TIME
			RangeChallenge.Cue.TIME:
				_kind = Banner.TIME
				_banner_left = RESULT_TIME
				_fill_result(state.challenge.last)


## Follows the challenge: what shows for its phase, the timers run `delta` s.
func update(state: GameState, delta: float) -> void:
	var c := state.challenge
	if c.phase == RangeChallenge.Phase.OFF:
		_kind = Banner.NONE
		_banner_left = 0.0
	_banner_left = maxf(0.0, _banner_left - delta) if is_finite(_banner_left) else _banner_left
	if _banner_left <= 0.0:
		_kind = Banner.NONE
	_show_bar(c)
	_show_banner()
	var ready := c.phase == RangeChallenge.Phase.READY and _kind == Banner.NONE
	_hint.visible = ready
	if ready:
		_show_hint(c.best)


## The bar: while the countdown or the run is on, and with the result. Hits read 0 through the countdown (the last run's
## stay until the next one starts), the clock the run's whole length until it does.
func _show_bar(c: RangeChallenge) -> void:
	var counting := c.phase == RangeChallenge.Phase.COUNTDOWN
	var running := c.phase == RangeChallenge.Phase.RUNNING
	var result := c.phase == RangeChallenge.Phase.READY and _kind == Banner.TIME
	_bar.visible = counting or running or result
	if not _bar.visible:
		return
	var hits := 0 if counting else c.hits
	var seconds := _run_time if counting else ceili(c.clock)
	if hits != _shown_hits:
		_shown_hits = hits
		_hits.text = str(hits)
	if seconds != _shown_time:
		_shown_time = seconds
		_clock.text = HudStyle.clock_text(seconds)
	if c.best != _shown_best:
		_shown_best = c.best
		_best.text = str(c.best)


func _show_banner() -> void:
	if _kind == Banner.NONE:
		_banner.visible = false
		_shown_kind = Banner.NONE
		return
	if _banner.visible and _kind == _shown_kind and (_kind != Banner.COUNT or _count == _shown_count):
		return
	_shown_kind = _kind
	_shown_count = _count
	var big := ""
	match _kind:
		Banner.COUNT:
			big = str(_count)
		Banner.GO:
			big = HudStyle.caps("CHALLENGE_GO")
		Banner.TIME:
			big = HudStyle.caps("CHALLENGE_TIME")
	_title.text = big
	_result.visible = _kind == Banner.TIME
	var top := RESULT_TOP if _kind == Banner.TIME else BANNER_TOP
	_lane_banner.offset_top = top
	_lane_banner.offset_bottom = top
	_banner.show_text("", "")
	# The slant takes its share out of the padding: widen it by half the lean over the banner's height, as the concept's
	# skewed box has its padding outside the slant.
	var lean := roundi(_banner.get_combined_minimum_size().y * SlantStyle.SKEW * 0.5)
	_banner.add_theme_constant_override("margin_left", roundi(BANNER_PAD.x) + lean)
	_banner.add_theme_constant_override("margin_right", roundi(BANNER_PAD.z) + lean)
	_banner.reset_size()


## "Shoot START to begin · best 14": the best only once there is one.
func _show_hint(best: int) -> void:
	if best == _shown_hint_best:
		return
	_shown_hint_best = best
	var muted := GameTheme.MUTED.to_html(false)
	var line := tr("CHALLENGE_READY")
	if best > 0:
		line += " [color=#%s]·[/color] %s [color=#%s][b]%d[/b][/color]" % [muted, tr("CHALLENGE_BEST_LINE"),
				GameTheme.ACCENT.to_html(false), best]
	_hint_line.text = line


func _fill_result(run: RangeChallenge.Run) -> void:
	if run == null:
		return
	_result_hits.text = str(run.hits)
	_result_shots.text = str(run.shots)
	_result_missed.text = str(run.missed)
	_tag_new.visible = run.best
	_tag_kept.visible = run.helped and not run.best


func _build_bar() -> void:
	_bar = HBoxContainer.new()
	_bar.name = "Bar"
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_theme_constant_override("separation", 0)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_lane(BAR_TOP).add_child(_bar)
	_hits = _block(tr("CHALLENGE_HITS"), GameTheme.ACCENT, GameTheme.ACCENT_INK, GameTheme.ACCENT_INK, 1.0)
	_build_clock()
	_best = _block(tr("CHALLENGE_BEST"), Color(0.0, 0.0, 0.0, 0.0), GameTheme.TEXT, GameTheme.MUTED,
			HudStyle.BACKING_CLOCK)


## A block of the bar (hits, best): its number over its label, on `fill` (the page colour at `alpha` when clear).
func _block(words: String, fill: Color, number_colour: Color, label_colour: Color, alpha: float) -> Label:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(BLOCK_WIDTH, BAR_HEIGHT)
	panel.add_theme_stylebox_override("panel", _fill(fill, alpha))
	_bar.add_child(panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	var number := _figure(column, NUMBER_SIZE, number_colour, FIGURE_LINE)
	var label := HudStyle.label(column, LABEL_SIZE, 800, label_colour, HORIZONTAL_ALIGNMENT_CENTER, LABEL_SPACING)
	label.text = words.to_upper()
	return number


func _build_clock() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(CLOCK_WIDTH, BAR_HEIGHT)
	var face := HudStyle.panel_box(HudStyle.BACKING_CLOCK, 0, 0)
	face.content_margin_left = CLOCK_PAD.x
	face.content_margin_top = CLOCK_PAD.y
	face.content_margin_right = CLOCK_PAD.z
	face.content_margin_bottom = CLOCK_PAD.w
	panel.add_theme_stylebox_override("panel", face)
	_bar.add_child(panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	_clock = _figure(column, TIME_SIZE, GameTheme.TEXT, TIME_LINE)
	_clock.text = HudStyle.clock_text(_run_time)
	var words := HudStyle.label(column, CLOCK_WORDS_SIZE, 700, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER,
			LABEL_SPACING)
	words.text = tr("CHALLENGE_KICKER").to_upper()


func _build_hint() -> void:
	_hint = PanelContainer.new()
	_hint.name = "Ready"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var face := HudStyle.panel_box(HudStyle.BACKING_BANNER, 0, 0)
	face.border_width_top = roundi(HudStyle.BANNER_RULE)
	face.border_color = LIT
	face.content_margin_left = HINT_PAD.x
	face.content_margin_top = HINT_PAD.y
	face.content_margin_right = HINT_PAD.z
	face.content_margin_bottom = HINT_PAD.w
	_hint.add_theme_stylebox_override("panel", face)
	_lane(HINT_TOP).add_child(_hint)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", HINT_GAP)
	_hint.add_child(column)
	var kicker := HudStyle.label(column, HINT_KICKER_SIZE, 800, LIT, HORIZONTAL_ALIGNMENT_CENTER, LABEL_SPACING)
	kicker.text = tr("CHALLENGE_KICKER").to_upper()
	_hint_line = RichTextLabel.new()
	_hint_line.bbcode_enabled = true
	_hint_line.fit_content = true
	_hint_line.scroll_active = false
	_hint_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_line.focus_mode = Control.FOCUS_NONE
	_hint_line.add_theme_font_override("normal_font", GameTheme.font(800))
	_hint_line.add_theme_font_override("bold_font", GameTheme.font(800))
	_hint_line.add_theme_font_size_override("normal_font_size", HINT_SIZE)
	_hint_line.add_theme_font_size_override("bold_font_size", HINT_SIZE)
	_hint_line.add_theme_color_override("default_color", GameTheme.TEXT)
	column.add_child(_hint_line)


func _build_banner() -> void:
	_banner = HudBanner.new()
	_banner.setup(BANNER_PAD)
	_banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_lane_banner = _lane(BANNER_TOP)
	_lane_banner.add_child(_banner)
	# The banner's own big words stay empty: the title is the same size with the concept's line height.
	var heading := VBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_row(heading)
	_title = _figure(heading, HudStyle.BANNER_SIZE, GameTheme.TEXT, BIG_LINE)
	_title.add_theme_font_override("font", GameTheme.spaced_font(800, HudStyle.SPACING_BANNER, HudStyle.BANNER_SIZE))
	_result = MenuParts.padded(0.0, RESULT_GAP, 0.0, 0.0)
	_result.visible = false
	_banner.add_row(_result)
	var figures := VBoxContainer.new()
	figures.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figures.add_theme_constant_override("separation", TAG_GAP)
	_result.add_child(figures)
	var cells := HBoxContainer.new()
	cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cells.alignment = BoxContainer.ALIGNMENT_CENTER
	cells.add_theme_constant_override("separation", 0)
	figures.add_child(cells)
	_result_hits = _cell(cells, tr("CHALLENGE_HITS"), false)
	_result_shots = _cell(cells, tr("CHALLENGE_SHOTS"), true)
	_result_missed = _cell(cells, tr("CHALLENGE_MISSED"), true)
	_tag_new = _tag(NEW_BEST_SIZE, NEW_BEST_PAD, tr("CHALLENGE_NEW_BEST"), GameTheme.ACCENT_INK,
			GameTheme.ACCENT, GameTheme.ACCENT)
	_tag_kept = _tag(NOT_KEPT_SIZE, NOT_KEPT_PAD, tr("CHALLENGE_NOT_KEPT"), MenuTag.DEV_TEXT,
			Color(0.0, 0.0, 0.0, 0.0), MenuTag.DEV_EDGE)
	var tags := HBoxContainer.new()
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tags.alignment = BoxContainer.ALIGNMENT_CENTER
	tags.add_child(_tag_new)
	tags.add_child(_tag_kept)
	figures.add_child(tags)


## One figure of the result: its number over its label, a rule down its left edge unless it is the first.
func _cell(row: Control, words: String, rule: bool) -> Label:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := GameTheme.box(Color(0.0, 0.0, 0.0, 0.0), GameTheme.LINE, 0, 0)
	face.set_border_width_all(0)
	face.border_width_left = CELL_RULE if rule else 0
	face.content_margin_left = CELL_PAD + (CELL_RULE if rule else 0)
	face.content_margin_right = CELL_PAD
	face.content_margin_top = 0.0
	face.content_margin_bottom = 0.0
	panel.add_theme_stylebox_override("panel", face)
	row.add_child(panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", RESULT_LABEL_GAP)
	panel.add_child(column)
	var number := _figure(column, RESULT_SIZE, GameTheme.TEXT, FIGURE_LINE)
	var label := HudStyle.label(column, RESULT_LABEL_SIZE, 800, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER,
			LABEL_SPACING)
	label.text = words.to_upper()
	return number


## A small capitals tag on `fill`, outlined in `edge`.
func _tag(size: int, pad: Vector2i, words: String, colour: Color, fill: Color, edge: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	panel.add_theme_stylebox_override("panel", GameTheme.box(fill, edge, pad.x, pad.y))
	var label := HudStyle.label(panel, size, 800, colour, HORIZONTAL_ALIGNMENT_CENTER, LABEL_SPACING)
	label.text = words.to_upper()
	return panel


## A flat box of `fill` at `alpha` (the page colour's when `fill` is clear).
func _fill(fill: Color, alpha: float) -> StyleBoxFlat:
	if fill.a > 0.0:
		return GameTheme.box(fill, Color(0.0, 0.0, 0.0, 0.0), 0, 0)
	return HudStyle.panel_box(alpha, 0, 0)


## A lane across the top of the screen, `top` px down, holding one thing centred: it grows down with it.
func _lane(top: float) -> VBoxContainer:
	var lane := VBoxContainer.new()
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lane.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lane.offset_top = top
	lane.offset_bottom = top
	add_child(lane)
	return lane


## A figure's label in Inter 800, centred, under `parent`, its line `line` times its size (the concept's `line-height`)
## instead of the font's: the label sits in a box of that height and the spare spills over its edges evenly.
func _figure(parent: Control, size: int, colour: Color, line: float) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", GameTheme.font(800))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = "0"
	var trim := maxi(0, floori(GameTheme.font(800).get_height(size) - size * line))
	var box := MenuParts.padded(0.0, 0.0, 0.0, 0.0)
	box.add_theme_constant_override("margin_top", -(trim / 2))
	box.add_theme_constant_override("margin_bottom", -(trim - trim / 2))
	box.add_child(label)
	parent.add_child(box)
	return label
