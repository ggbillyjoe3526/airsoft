class_name CrashScreen
extends Control
## The crash screen (SV6, concept crash-screen.png): full screen, before the title, at the first start after a run that
## closed unexpectedly (RunRecord's `previous`). Left: CRASH REPORT · THE GAME CLOSED UNEXPECTEDLY, the blurb, the facts
## (When: the old log's last write and the time since that run started; Version; Match, or "In the menus"; Seed with
## COPY in a match), the note box (ReportConfig.note_chars, trimmed in script, with its count), REPORT A BUG, COPY
## REPORT, OPEN LOG FOLDER, CONTINUE and the fine print. Right: the crash report as it is sent (ReportFacts.crash and
## BugReport, scrubbed), rebuilt as the note changes. Report a Bug opens IssueLink's address and copies the whole report;
## nothing is sent before the player presses Submit on GitHub. Esc is Continue while the note is empty (a typed note is
## never thrown away by a key). Drawn for 1920x1080 like the title; the
## window's stretch scales it. The entry scene (game/main.gd) clears `previous` on Continue, on Report and on a quit.

## Continue: the title next.
signal continued
## Report a Bug opened the issue.
signal reported

const BACKDROP := TitleScreen.BACKDROP
## The page colour over the picture.
const SHADE := 0.93
## The two columns (px): the left one's edge, the top, their widths and the gap between.
const LEFT := 150.0
const TOP := 86.0
const LEFT_WIDTH := 790.0
const RIGHT_WIDTH := 780.0
const COLUMN_GAP := 50.0
## The warning orange of the tape and the kicker.
const WARN := GraphicsNotice.WARN
const KICK_SIZE := 15
const KICK_SPACING := 0.16
const HEADING_SIZE := 64
const HEADING_SPACING := 0.02
## Line spacing (px) of the heading's two lines (the concept's 1.02 line height), the blurb's and the fine print's.
const HEADING_LINES := -12
const BLURB_LINES := 2
const FINE_LINES := 3
const BLURB_SIZE := 19
const FACTS_SIZE := 18
const FACT_LABEL_WIDTH := 150.0
const FACT_ROW_GAP := 8
const FACTS_PAD := Vector2i(20, 18)
## The facts box: the panel colour, a little see-through.
const FACTS_FILL := Color(GameTheme.PANEL, 0.9)
const MINI_SIZE := 12
const MINI_SPACING := 0.1
const MINI_PAD := Vector2i(8, 3)
const LAB_SIZE := 14
const LAB_SPACING := 0.12
const NOTE_HEIGHT := 96.0
const NOTE_SIZE := 17
const NOTE_PAD := Vector2i(14, 12)
const COUNT_SIZE := 13
const COUNT_INSET := Vector2(12.0, 8.0)
const BUTTON_HEIGHT := 52.0
const BUTTON_SIZE := 17
const BUTTON_SPACING := 0.08
const BUTTON_PAD := 20
const BUTTON_GAP := 12
const FINE_SIZE := 15
const REPORT_SIZE := 14
const REPORT_INK := Color("c8d0dc")
const REPORT_FILL := Color("0a111f")
const REPORT_PAD := Vector2i(14, 12)
const REPORT_HEIGHT := 640.0
## The gaps down the left column (px): under the tape, the kicker, the heading, the blurb, the facts, the note's label,
## the note, the buttons; and above the right column's label.
const TAPE_GAP := 26.0
const KICK_GAP := 10.0
const HEADING_GAP := 18.0
const BLURB_GAP := 24.0
const FACTS_GAP := 24.0
const LAB_GAP := 8.0
const NOTE_GAP := 18.0
const BUTTONS_GAP := 14.0
const REPORT_TOP := 40.0
const SECONDS_PER_DAY := 86400
const SECONDS_PER_MINUTE := 60

## Opens an address or a folder (OS.shell_open; an Error back). Tests give their own: headless, shell_open answers OK
## even when nothing opens.
var open_url: Callable = Callable(OS, &"shell_open")
## Puts text on the clipboard (DisplayServer.clipboard_set). Tests give their own: headless has no clipboard.
var copy_text: Callable = Callable(DisplayServer, &"clipboard_set")
## The folder OPEN LOG FOLDER opens.
var log_dir: String = LogTail.DIR

var _config: ReportConfig = null
var _info: BugReport.ReportInfo = null
## The report without its note, scrubbed once: a note's keystroke only puts its own line in.
var _body := PackedStringArray()
var _seed: String = ""
var _facts := PackedStringArray()
var _note: TextEdit = null
var _count: Label = null
var _report: TextEdit = null
var _status: Label = null
var _report_button: Button = null
var _copy_button: Button = null
var _logs_button: Button = null
var _continue_button: Button = null
var _seed_button: Button = null


## The screen for `previous` (RunRecord's) and its log (`tail`), the report scrubbed by `scrub`.
func _init(previous: Dictionary, tail: LogTail, settings: Settings, config: ReportConfig, scrub: ReportScrub) -> void:
	name = "CrashScreen"
	theme = GameTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_config = config
	_info = ReportFacts.crash(previous, tail, settings, "", config, scrub)
	_body = BugReport.write_lines(_info)
	var log_path := tail.path()
	var closed := FileAccess.get_modified_time(log_path) if log_path != "" else 0
	var when := when_text(closed, _whole(previous.get("started")), int(Time.get_unix_time_from_system()),
			int(Time.get_time_zone_from_system().get("bias", 0)))
	var version: Variant = previous.get("version")
	_seed = seed_text(previous)
	_facts = PackedStringArray([when, version if version is String and version != "" else BugReport.UNKNOWN,
			match_words(previous, MapCatalog.shared()), _seed])
	_build_backdrop()
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.position = Vector2(LEFT, TOP)
	columns.add_theme_constant_override("separation", int(COLUMN_GAP))
	add_child(columns)
	_build_left(columns)
	_build_right(columns)
	_ring_focus()
	_rewrite()


func _ready() -> void:
	_note.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo() and _note.text.strip_edges() == "":
		get_viewport().set_input_as_handled()
		_on_continue()


## When, Version, Match and Seed as shown ("" for Seed outside a match).
func facts() -> PackedStringArray:
	return _facts


## The report as shown (and sent), the note in it.
func report_text() -> String:
	return _report.text


## The line under the buttons after one was pressed ("" before).
func status_text() -> String:
	return _status.text


func note_box() -> TextEdit:
	return _note


func report_button() -> Button:
	return _report_button


func copy_button() -> Button:
	return _copy_button


func logs_button() -> Button:
	return _logs_button


func continue_button() -> Button:
	return _continue_button


## The seed's COPY, or null outside a match.
func seed_button() -> Button:
	return _seed_button


## When the run closed, as "Today about 14:32, 12:40 after it started" (Yesterday, or the date before that), in local
## time (`bias_minutes` east of UTC); `closed`, `started` and `now` Unix seconds. Not known without the old log.
static func when_text(closed: int, started: int, now: int, bias_minutes: int) -> String:
	if closed <= 0:
		return TranslationServer.translate("CRASH_WHEN_UNKNOWN")
	var shift := bias_minutes * SECONDS_PER_MINUTE
	var d := Time.get_datetime_dict_from_unix_time(closed + shift)
	var clock := "%02d:%02d" % [int(d.hour), int(d.minute)]
	var days_ago := floori(float(now + shift) / SECONDS_PER_DAY) - floori(float(closed + shift) / SECONDS_PER_DAY)
	var when: String
	if days_ago == 0:
		when = TranslationServer.translate("CRASH_WHEN_TODAY") % clock
	elif days_ago == 1:
		when = TranslationServer.translate("CRASH_WHEN_YESTERDAY") % clock
	else:
		var date := "%d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]
		when = TranslationServer.translate("CRASH_WHEN_ON") % [date, clock]
	if started > 0 and closed >= started:
		when = TranslationServer.translate("CRASH_WHEN_AFTER") % [when, ReportFacts.clock_text(closed - started)]
	return when


## Where the run was: "Depot · Elimination · round 4, 2–1" in a match (no round before the first), "Practice · Range"
## on the range, "In the menus" otherwise. Map names from `catalog`, else the id capitalised.
static func match_words(previous: Dictionary, catalog: MapCatalog) -> String:
	var facts: Dictionary = previous.get("match") if previous.get("match") is Dictionary else {}
	var map_id := str(facts.get("map", ""))
	var entry: MapCatalog.Entry = catalog.find(map_id) if catalog != null and map_id != "" else null
	var map_name := entry.display_name if entry != null else map_id.capitalize()
	var place := str(previous.get("place", ""))
	if place == RunRecord.PRACTICE:
		var practice := TranslationServer.translate(MatchOptions.MODE_NAME[MatchOptions.MODE_PRACTICE])
		return practice + ReportFacts.SEP + map_name if map_name != "" else practice
	if place != RunRecord.MATCH:
		return TranslationServer.translate("CRASH_IN_MENUS")
	var parts := PackedStringArray([map_name if map_name != "" else BugReport.UNKNOWN])
	var mode := str(facts.get("mode", ""))
	if MatchOptions.MODE_NAME.has(mode):
		parts.append(TranslationServer.translate(MatchOptions.MODE_NAME[mode]))
	elif mode != "":
		parts.append(mode.capitalize())
	var number := _whole(previous.get("round"))
	if number > 0:
		var score := PackedInt32Array()
		var given: Variant = previous.get("score")
		if given is Array:
			for n: Variant in given:
				score.append(_whole(n))
		parts.append(TranslationServer.translate("CRASH_MATCH_ROUND") % [number, ReportFacts.score_text(score)])
	return ReportFacts.SEP.join(parts)


## The match's seed as the record kept it, "" outside a match.
static func seed_text(previous: Dictionary) -> String:
	if str(previous.get("place", "")) != RunRecord.MATCH or not previous.get("match") is Dictionary:
		return ""
	var given: Variant = (previous["match"] as Dictionary).get("seed")
	return str(given) if given != null else ""


## A JSON number as a whole number of 0 or more; anything else 0.
static func _whole(v: Variant) -> int:
	return maxi(int(v), 0) if v is int or v is float else 0


# --- Building ---

func _build_backdrop() -> void:
	var picture := TextureRect.new()
	picture.name = "Backdrop"
	picture.texture = load(BACKDROP) as Texture2D
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(picture)
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(GameTheme.BG, SHADE)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)


func _build_left(parent: Control) -> void:
	var left := VBoxContainer.new()
	left.name = "Left"
	left.custom_minimum_size.x = LEFT_WIDTH
	left.add_theme_constant_override("separation", 0)
	parent.add_child(left)
	var tape := HazardTape.new()
	tape.stripe_colour = WARN
	tape.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(tape)
	_space(left, TAPE_GAP)
	HudStyle.label(left, KICK_SIZE, 800, WARN, HORIZONTAL_ALIGNMENT_LEFT, KICK_SPACING).text = \
			tr("CRASH_KICKER").to_upper()
	_space(left, KICK_GAP)
	var heading := HudStyle.label(left, HEADING_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT, HEADING_SPACING)
	heading.text = tr("CRASH_HEADING").to_upper()
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_constant_override("line_spacing", HEADING_LINES)
	_space(left, HEADING_GAP)
	var blurb := HudStyle.label(left, BLURB_SIZE, 600, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	blurb.text = tr("CRASH_BLURB")
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_constant_override("line_spacing", BLURB_LINES)
	_space(left, BLURB_GAP)
	_build_facts(left)
	_space(left, FACTS_GAP)
	_build_note(left)
	_space(left, NOTE_GAP)
	_build_buttons(left)
	_space(left, BUTTONS_GAP)
	_status = HudStyle.label(left, FINE_SIZE, 700, GameTheme.YELLOW, HORIZONTAL_ALIGNMENT_LEFT)
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.visible = false
	left.add_child(_fine_print())


func _build_facts(parent: Control) -> void:
	var box := PanelContainer.new()
	box.name = "Facts"
	box.add_theme_stylebox_override("panel", GameTheme.box(FACTS_FILL, GameTheme.LINE, FACTS_PAD.x, FACTS_PAD.y))
	parent.add_child(box)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("v_separation", FACT_ROW_GAP)
	grid.add_theme_constant_override("h_separation", 0)
	box.add_child(grid)
	var keys: PackedStringArray = ["CRASH_WHEN", "CRASH_VERSION", "CRASH_MATCH", "CRASH_SEED"]
	for i in keys.size():
		if i == keys.size() - 1 and _seed == "":
			break
		var label := HudStyle.label(grid, FACTS_SIZE, 600, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
		label.text = tr(keys[i])
		label.custom_minimum_size.x = FACT_LABEL_WIDTH
		if i < keys.size() - 1:
			HudStyle.label(grid, FACTS_SIZE, 600, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT).text = _facts[i]
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", FACT_ROW_GAP * 2)
		grid.add_child(row)
		HudStyle.label(row, FACTS_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT).text = _seed
		_seed_button = Button.new()
		_seed_button.name = "CopySeed"
		_seed_button.text = tr("CRASH_COPY").to_upper()
		_seed_button.add_theme_font_override("font", GameTheme.spaced_font(800, MINI_SPACING, MINI_SIZE))
		_seed_button.add_theme_font_size_override("font_size", MINI_SIZE)
		_seed_button.add_theme_color_override("font_color", GameTheme.MUTED)
		var mini := GameTheme.box(Color(0.0, 0.0, 0.0, 0.0), GameTheme.LINE, MINI_PAD.x, MINI_PAD.y)
		GameTheme.dress(_seed_button, mini, mini, mini)
		_seed_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_seed_button.pressed.connect(_on_copy_seed)
		row.add_child(_seed_button)


func _build_note(parent: Control) -> void:
	_lab_row(parent, "CRASH_NOTE_LABEL", "CRASH_NOTE_OPTIONAL")
	_space(parent, LAB_GAP)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0.0, NOTE_HEIGHT)
	parent.add_child(holder)
	_note = TextEdit.new()
	_note.name = "Note"
	_note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	# Tab moves round the screen; a note has no use for a tab character
	_note.tab_input_mode = false
	_note.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_note.add_theme_font_override("font", GameTheme.font(600))
	_note.add_theme_font_size_override("font_size", NOTE_SIZE)
	_note.add_theme_stylebox_override("normal", GameTheme.box(GameTheme.BG, GameTheme.LINE, NOTE_PAD.x, NOTE_PAD.y))
	_note.add_theme_stylebox_override("focus", GameTheme.box(GameTheme.BG, GameTheme.YELLOW, NOTE_PAD.x, NOTE_PAD.y))
	_note.text_changed.connect(_on_note_changed)
	holder.add_child(_note)
	_count = HudStyle.label(holder, COUNT_SIZE, 700, GameTheme.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_count.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_count.offset_right = -COUNT_INSET.x
	_count.offset_bottom = -COUNT_INSET.y
	_count.offset_left = _count.offset_right
	_count.offset_top = _count.offset_bottom
	_show_count()


func _build_buttons(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "Buttons"
	row.add_theme_constant_override("separation", BUTTON_GAP)
	parent.add_child(row)
	_report_button = _button(row, "CRASH_REPORT_BUG", GameTheme.YELLOW, GameTheme.YELLOW, GameTheme.YELLOW_INK)
	_report_button.pressed.connect(_on_report)
	_copy_button = _button(row, "CRASH_COPY_REPORT", GameTheme.CARD, GameTheme.YELLOW, GameTheme.TEXT)
	_copy_button.pressed.connect(_on_copy_report)
	_logs_button = _button(row, "CRASH_OPEN_LOGS", GameTheme.CARD, GameTheme.LINE, GameTheme.TEXT)
	_logs_button.pressed.connect(_on_open_logs)
	_continue_button = _button(row, "CRASH_CONTINUE", GameTheme.CARD, GameTheme.LINE, GameTheme.TEXT)
	_continue_button.pressed.connect(_on_continue)
	ButtonWidth.group([_report_button, _copy_button, _logs_button, _continue_button])


func _build_right(parent: Control) -> void:
	var right := VBoxContainer.new()
	right.name = "Right"
	right.custom_minimum_size.x = RIGHT_WIDTH
	right.add_theme_constant_override("separation", 0)
	parent.add_child(right)
	# the right column's label stands level with the kicker
	_space(right, TAPE_GAP + HazardTape.SIZE.y)
	_lab_row(right, "CRASH_REPORT_LABEL", "CRASH_REPORT_SENT")
	_space(right, LAB_GAP)
	_report = TextEdit.new()
	_report.name = "Report"
	_report.editable = false
	_report.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_report.custom_minimum_size = Vector2(0.0, REPORT_HEIGHT)
	_report.add_theme_font_override("font", GameTheme.font(500))
	_report.add_theme_font_size_override("font_size", REPORT_SIZE)
	_report.add_theme_color_override("font_readonly_color", REPORT_INK)
	var plate := GameTheme.box(REPORT_FILL, GameTheme.LINE, REPORT_PAD.x, REPORT_PAD.y)
	_report.add_theme_stylebox_override("read_only", plate)
	_report.add_theme_stylebox_override("normal", plate)
	var lit := GameTheme.box(REPORT_FILL, GameTheme.YELLOW, REPORT_PAD.x, REPORT_PAD.y)
	lit.draw_center = false
	_report.add_theme_stylebox_override("focus", lit)
	right.add_child(_report)


## Tab and Shift+Tab go round the screen's parts as the report panel's do: the note, the four buttons, the report,
## then Copy beside the seed when there is one.
func _ring_focus() -> void:
	var ring: Array[Control] = [_note, _report_button, _copy_button, _logs_button, _continue_button, _report]
	if _seed_button != null:
		ring.append(_seed_button)
	for i in ring.size():
		var c := ring[i]
		c.focus_next = c.get_path_to(ring[(i + 1) % ring.size()])
		c.focus_previous = c.get_path_to(ring[(i - 1 + ring.size()) % ring.size()])


## A small capitals label, with its quiet note at the right.
func _lab_row(parent: Control, key: String, note_key: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lab := HudStyle.label(row, LAB_SIZE, 800, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, LAB_SPACING)
	lab.text = tr(key).to_upper()
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HudStyle.label(row, LAB_SIZE, 600, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT).text = tr(note_key)


func _button(parent: Control, key: String, fill: Color, edge: Color, ink: Color) -> Button:
	var b := Button.new()
	b.text = tr(key).to_upper()
	b.custom_minimum_size.y = BUTTON_HEIGHT
	b.add_theme_font_override("font", GameTheme.spaced_font(800, BUTTON_SPACING, BUTTON_SIZE))
	b.add_theme_font_size_override("font_size", BUTTON_SIZE)
	GameTheme.dress(b, GameTheme.box(fill, edge, BUTTON_PAD, 0), GameTheme.box(fill.lightened(0.1), edge, BUTTON_PAD, 0),
			GameTheme.box(fill.lightened(0.1), GameTheme.YELLOW, BUTTON_PAD, 0))
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(colour, ink)
	parent.add_child(b)
	return b


func _fine_print() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.name = "Fine"
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", GameTheme.font(600))
	r.add_theme_font_override("bold_font", GameTheme.font(800))
	r.add_theme_font_size_override("normal_font_size", FINE_SIZE)
	r.add_theme_font_size_override("bold_font_size", FINE_SIZE)
	r.add_theme_color_override("default_color", GameTheme.MUTED)
	r.add_theme_constant_override("line_separation", FINE_LINES)
	var text := tr("CRASH_FINE")
	r.text = text.replace("[b]", "[b][color=#%s]" % GameTheme.TEXT.to_html(false)).replace("[/b]", "[/color][/b]")
	return r


func _space(parent: Control, height: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0.0, height)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)


# --- Acting ---

## The note held to note_chars (cut in script: a TextEdit has no limit of its own), the count and the report after it.
func _on_note_changed() -> void:
	if _note.text.length() > _config.note_chars:
		_note.text = _note.text.left(_config.note_chars)
		_note.set_caret_line(_note.get_line_count() - 1)
		_note.set_caret_column(_note.get_line(_note.get_line_count() - 1).length())
	_show_count()
	_rewrite()


func _show_count() -> void:
	_count.text = tr("CRASH_COUNT") % [_note.text.length(), _config.note_chars]


## The report with the note's line put in after the title, as BugReport writes it.
func _rewrite() -> void:
	_info.note = _note.text.strip_edges()
	var lines := _body.duplicate()
	var note := BugReport.note_line(_info)
	if note != "":
		lines.insert(1, _info.scrub.line(note))
	# the reader keeps their place in the report as the note changes
	var scroll := _report.scroll_vertical
	_report.text = "\n".join(lines)
	_report.scroll_vertical = scroll


func _on_report() -> void:
	_rewrite()
	var link := IssueLink.make(_info, _config)
	var answer: Variant = open_url.call(link.url)
	copy_text.call(_report.text)
	if answer is int and answer != OK:
		# nothing opened: the crash stays to report, the copied report to paste elsewhere
		_say(tr("CRASH_REPORT_FAILED"))
		return
	_say(tr("CRASH_REPORTED_CUT") if link.cut else tr("CRASH_REPORTED"))
	reported.emit()


func _on_copy_report() -> void:
	_rewrite()
	copy_text.call(_report.text)
	_say(tr("CRASH_COPIED"))


func _on_copy_seed() -> void:
	copy_text.call(_seed)
	_say(tr("CRASH_SEED_COPIED"))


func _on_open_logs() -> void:
	var answer: Variant = open_url.call(ProjectSettings.globalize_path(log_dir))
	if answer is int and answer != OK:
		_say(tr("CRASH_LOGS_FAILED"))


func _on_continue() -> void:
	continued.emit()


func _say(text: String) -> void:
	_status.text = text
	_status.visible = true
