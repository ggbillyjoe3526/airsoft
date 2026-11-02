class_name SettingsSavePage
extends HBoxContainer
## Settings › Save file (concept `settings-save-file.png`; the browser game's Settings › Save file). On the left Your
## save (Saved automatically, when it was last saved, a warning for a newer version's save or a write that failed this
## run, and the summary tiles) and Save folder (its path and OPEN FOLDER); on the right Restore points (each with its
## day, when it was opened, level, XP, matches and RESTORE, or "None yet"), Undo, and Delete and start over. RESTORE,
## UNDO and DELETE SAVE… ask first (SettingsSaveConfirm); on yes the shared stores are saved, the save is replaced
## (SaveKeeper), renderer.cfg is written from the settings now in place and the game restarts (the screen's `restart`).
## A replace that is refused or fails changes nothing and says why (SaveKeeper.refusal). From the pause menu (no
## restart there) they are greyed with "Leave the match to restore, undo or delete."; so are they all for a save from a
## newer version, Undo with nothing to undo or a slot from a newer build, and Delete for an empty save. Open folder
## works anywhere. The screen builds the page on its tab's first show; it reads the save each time it shows. The
## keeper, the opener, the store flush, the folder and renderer.cfg's path are injected for tests.

## The columns' widths (the right one takes the rest) and the gap between them (px at 1080p).
const LEFT_WIDTH := 860.0
const COLUMN_GAP := 48
## The words' sizes (px): a note, the status line, a tile's label and figure, a point's day and figures, the buttons.
const NOTE_SIZE := 15
const STATUS_SIZE := 20
const STATUS_WHEN_SIZE := 17
const TILE_LABEL_SIZE := 13
const TILE_VALUE_SIZE := 26
const DAY_SIZE := 19
const OPENED_SIZE := 15
const FIGURE_SIZE := 17
const BUTTON_SIZE := 17
const DANGER_SIZE := 20
## The tiles: how many to a row, the gap between them and their inner margins (px).
const TILE_COLUMNS := 3
const TILE_GAP := 10
const TILE_PAD := Vector2i(16, 10)
## The status line's inner margins, its dot's size and the gap after it (px).
const STATUS_PAD := Vector2i(18, 12)
const DOT := 12.0
const DOT_GAP := 12
## The folder's path box and the button beside it; a point's box, its day column's width, the gap before TODAY and
## the figures' gap; a button's margins; the delete box's margins and how much red is in its fill (px, share).
const PATH_PAD := Vector2i(12, 8)
const ROW_GAP := 12
const POINT_PAD := Vector2i(16, 10)
const DAY_WIDTH := 238.0
const TAG_GAP := 8
const FIGURE_GAP := 22
const BUTTON_PAD := Vector2i(18, 8)
const DANGER_PAD := Vector2i(18, 16)
const DANGER_TINT := 0.08
## How fast "Last saved" moves from minutes to a clock time (s).
const MINUTE := 60
const HOUR := 3600
## Words for a date: the weekdays from Sunday (Time's weekday 0) and the months from January.
const WEEKDAY_KEYS: Array[String] = ["SAVE_SUN", "SAVE_MON", "SAVE_TUE", "SAVE_WED", "SAVE_THU", "SAVE_FRI",
		"SAVE_SAT"]
const MONTH_KEYS: Array[String] = ["SAVE_JAN", "SAVE_FEB", "SAVE_MAR", "SAVE_APR", "SAVE_MAY", "SAVE_JUN",
		"SAVE_JUL", "SAVE_AUG", "SAVE_SEP", "SAVE_OCT", "SAVE_NOV", "SAVE_DEC"]
## What a replace was, in SaveKeeper.What's order ("the restore", "the Undo", "the delete").
const WHAT_KEYS: Array[String] = ["SAVE_WHAT_RESTORE", "SAVE_WHAT_UNDO", "SAVE_WHAT_DELETE"]
## Each store as the player knows it, in SaveBundle.KINDS order (a newer version's warning names them).
const PART_KEYS: Array[String] = ["SAVE_PART_SETTINGS", "SAVE_PART_LOADOUTS", "SAVE_PART_PROGRESS",
		"SAVE_PART_RECORDS"]
## The comparison's rows and the summary tiles' labels, in that order: when saved, the version, then the figures.
const ROW_KEYS: Array[String] = ["SAVE_ROW_SAVED", "SAVE_ROW_VERSION", "SAVE_ROW_LEVEL", "SAVE_ROW_XP",
		"SAVE_ROW_UNLOCKED", "SAVE_ROW_MATCHES", "SAVE_ROW_LOADOUTS"]
## The rows that are figures (a lower one shows red), from this one on.
const FIRST_FIGURE := 2
## The tiles on Your save, as the concept orders them (ROW_KEYS indices).
const TILE_ROWS: Array[int] = [2, 3, 4, 5, 6, 1]
## The player's line for each SaveKeeper.Refusal, in its order (NONE has none).
const REFUSAL_KEYS: Array[String] = ["", "SAVE_REFUSED_REPLACED", "SAVE_REFUSED_NEWER", "SAVE_REFUSED_HOLDS_NEWER",
		"SAVE_REFUSED_UNREADABLE", "SAVE_NOT_WRITTEN", "SAVE_REFUSED_NOT_PUT_BACK", "SAVE_NOTHING_TO_UNDO",
		"SAVE_REFUSED_NOTHING_TO_DELETE"]
## The delete question's tiles and their shorter labels.
const GONE_KEYS: Array[String] = ["SAVE_ROW_LEVEL", "SAVE_ROW_XP", "SAVE_GONE_UNLOCKED", "SAVE_GONE_MATCHES",
		"SAVE_GONE_LOADOUTS"]

## Restore points, Undo and delete for the save (the real files by default).
var keeper: SaveKeeper = SaveKeeper.new()
## Opens a folder in the system's file manager: OS.shell_open by default; returns an Error.
var opener: Callable = Callable(OS, &"shell_open")
## Saves whatever the running game holds of the loadouts, progress and records (the shared stores') before a replace;
## the screen's settings are saved too. Empty: the shared stores.
var flush: Callable = Callable()
## The save folder.
var folder: String = OS.get_user_data_dir()
var renderer_path: String = RendererOverride.PATH

var _screen: SettingsScreen = null
var _built := false
var _current: SaveBundle = null
var _points: Array[SaveKeeper.Point] = []
var _slot: SaveKeeper.UndoSlot = null
## What yes does for the question showing: returns whether the save was replaced.
var _pending: Callable = Callable()
var _confirm: SettingsSaveConfirm = null
## The button that asked the question showing: the focus goes back to it when the question closes.
var _asker: Button = null
var _dot: Panel = null
var _when: Label = null
var _warnings: Label = null
var _tiles: Array[Label] = []
var _folder_note: Label = null
var _lock_note: Label = null
var _message: Label = null
var _point_rows: Array[PanelContainer] = []
var _point_days: Array[Label] = []
var _point_today: Array[MenuTag] = []
var _point_opened: Array[Label] = []
var _point_figures: Array[RichTextLabel] = []
var _restore: Array[Button] = []
var _none_yet: Label = null
var _undo: Button = null
var _undo_line: Label = null
var _delete: Button = null
var _open: Button = null
var _path: Label = null


func _init() -> void:
	name = "SettingsSavePage"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", COLUMN_GAP)


## Builds the tab for `screen`; its question goes over the whole screen.
func build(screen: SettingsScreen) -> void:
	_screen = screen
	var left := _column(LEFT_WIDTH)
	_build_your_save(left)
	_build_folder(left)
	var right := _column(0.0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_points(right)
	_build_undo(right)
	_build_delete(right)
	_confirm = SettingsSaveConfirm.new()
	_confirm.confirmed.connect(_on_confirmed)
	_confirm.closed.connect(_give_focus_back)
	screen.add_child(_confirm)
	_built = true


func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED or not _built:
		return
	if is_visible_in_tree():
		refresh()
	else:
		_confirm.close()


## Reads the save, its restore points and the Undo slot, and shows them.
func refresh() -> void:
	var now := _now()
	_current = SaveBundle.read(keeper.store_paths)
	var summary := _current.summary()
	_when.text = tr("SAVE_NOTHING_YET") if _current.is_empty() else tr("SAVE_LAST_SAVED") % ago(summary.saved_at,
			now, keeper.utc_offset_minutes)
	var figures := _figures(summary)
	for i in TILE_ROWS.size():
		_tiles[i].text = figures[TILE_ROWS[i]]
	var warnings := PackedStringArray()
	if _current.refusal() != "":
		warnings.append(tr("SAVE_NEWER") % ", ".join(_newer_parts(_current)))
	if SaveFile.last_failure != null:
		warnings.append(tr("SAVE_WRITE_FAILED") % [_part_of(SaveFile.last_failure.path),
				clock_words(int(SaveFile.last_failure.time), keeper.utc_offset_minutes)])
	_warnings.text = "\n".join(warnings)
	_warnings.visible = not warnings.is_empty()
	(_dot.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = GameTheme.BAD if _warnings.visible \
			else GameTheme.GOOD
	_path.text = folder.replace("/", "\\") if OS.get_name() == "Windows" else folder
	var can := can_replace()
	_lock_note.visible = not _screen.can_replace()
	_points = keeper.restore_points()
	var today := keeper.day_of(now)
	for i in _point_rows.size():
		_point_rows[i].visible = i < _points.size()
		if i >= _points.size():
			continue
		var p := _points[i]
		var s := p.save.summary()
		_point_days[i].text = date_words(p.taken_at, keeper.utc_offset_minutes)
		_point_today[i].visible = p.day == today
		_point_opened[i].text = tr("SAVE_OPENED_AT") % clock_words(p.taken_at, keeper.utc_offset_minutes)
		_point_figures[i].text = "%s    %s    %s" % [tr("SAVE_POINT_LEVEL") % _bold(str(s.level)),
				tr("SAVE_POINT_XP") % _bold(ArmoryFacts.grouped(s.xp)),
				tr("SAVE_POINT_MATCHES") % _bold(ArmoryFacts.grouped(s.matches))]
		_restore[i].disabled = not can or p.save.refusal() != ""
	_none_yet.visible = _points.is_empty()
	_slot = keeper.undo_slot()
	_undo.disabled = not can or _slot == null or _slot.save.refusal() != ""
	_undo_line.text = tr("SAVE_NOTHING_TO_UNDO") if _slot == null else tr("SAVE_UNDO_TAKES_BACK") % [
			tr(WHAT_KEYS[_slot.what]), stamp(_slot.taken_at, now, keeper.utc_offset_minutes)]
	_delete.disabled = not can or _current.is_empty()


## Whether a restore, an Undo or a delete may run: out of a match (the screen can restart the game) and not over a save
## from a newer version.
func can_replace() -> bool:
	return _screen.can_replace() and _current != null and _current.refusal() == ""


# --- For tests ---

func confirm() -> SettingsSaveConfirm:
	return _confirm


func restore_buttons() -> Array[Button]:
	return _restore


func point_rows() -> Array[PanelContainer]:
	return _point_rows


func undo_button() -> Button:
	return _undo


func delete_button() -> Button:
	return _delete


func open_button() -> Button:
	return _open


## The lines that say something: the warnings, the match's lock, a failed replace, "None yet", Undo's, the folder's.
func warnings() -> Label:
	return _warnings


func lock_note() -> Label:
	return _lock_note


func message() -> Label:
	return _message


func none_yet() -> Label:
	return _none_yet


func undo_line() -> Label:
	return _undo_line


func last_saved() -> Label:
	return _when


func folder_path() -> Label:
	return _path


func tiles() -> Array[Label]:
	return _tiles


# --- Your save ---

func _build_your_save(col: VBoxContainer) -> void:
	col.add_child(MenuParts.heading(tr("SAVE_YOUR_SAVE").to_upper()))
	var status := PanelContainer.new()
	status.add_theme_stylebox_override("panel", GameTheme.box(GameTheme.CARD, GameTheme.LINE, STATUS_PAD.x,
			STATUS_PAD.y))
	col.add_child(status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DOT_GAP)
	status.add_child(row)
	_dot = Panel.new()
	_dot.custom_minimum_size = Vector2(DOT, DOT)
	_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var round_box := GameTheme.box(GameTheme.GOOD, Color(0.0, 0.0, 0.0, 0.0), 0, 0)
	round_box.set_corner_radius_all(int(DOT / 2.0))
	_dot.add_theme_stylebox_override("panel", round_box)
	row.add_child(_dot)
	var saved := MenuParts.spaced(tr("SAVE_AUTOMATIC").to_upper(), STATUS_SIZE, 800, GameTheme.TEXT,
			GameTheme.SPACING_TAB)
	saved.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(saved)
	_when = MenuParts.text("", STATUS_WHEN_SIZE, 600, GameTheme.MUTED)
	row.add_child(_when)
	_warnings = _note_label("", GameTheme.BAD)
	col.add_child(_warnings)
	# what saves, and when: the status line's tooltip (UI1)
	status.tooltip_text = tr("SAVE_AUTOMATIC_HELP")
	var grid := GridContainer.new()
	grid.columns = TILE_COLUMNS
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	col.add_child(grid)
	for i: int in TILE_ROWS:
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("panel", GameTheme.box(GameTheme.CARD, GameTheme.LINE, TILE_PAD.x,
				TILE_PAD.y))
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", 0)
		tile.add_child(words)
		words.add_child(MenuParts.spaced(tr(ROW_KEYS[i]).to_upper(), TILE_LABEL_SIZE, 800, GameTheme.MUTED,
				GameTheme.SPACING_HEADING))
		var figure := MenuParts.text("", TILE_VALUE_SIZE, 800, GameTheme.TEXT)
		words.add_child(figure)
		_tiles.append(figure)
		grid.add_child(tile)


# --- Save folder ---

func _build_folder(col: VBoxContainer) -> void:
	_gap(col)
	col.add_child(MenuParts.heading(tr("SAVE_FOLDER").to_upper()))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_GAP)
	col.add_child(row)
	_path = MenuParts.text("", NOTE_SIZE + 2, 600, GameTheme.TEXT)
	# a path has no spaces: it wraps anywhere, so it is shown whole however long the player's folder is (UI1 round 1)
	_path.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_path.add_theme_stylebox_override("normal", GameTheme.box(GameTheme.BG, GameTheme.LINE, PATH_PAD.x, PATH_PAD.y))
	row.add_child(_path)
	_open = _button("SAVE_OPEN_FOLDER", Color(0.0, 0.0, 0.0, 0.0), GameTheme.ACCENT, GameTheme.TEXT)
	_open.pressed.connect(_open_folder)
	row.add_child(_open)
	_path.tooltip_text = tr("SAVE_FOLDER_HELP")
	_path.mouse_filter = Control.MOUSE_FILTER_PASS
	_folder_note = _note_label(tr("SAVE_FOLDER_UNOPENED"), GameTheme.BAD)
	_folder_note.visible = false
	col.add_child(_folder_note)


func _open_folder() -> void:
	var opened: int = opener.call(folder)
	_folder_note.visible = opened != OK


# --- Restore points ---

func _build_points(col: VBoxContainer) -> void:
	col.add_child(MenuParts.heading(tr("SAVE_RESTORE_POINTS").to_upper()))
	col.add_child(_note_label(tr("SAVE_RESTORE_HELP") % SaveKeeper.RESTORE_POINTS, GameTheme.MUTED))
	_lock_note = _note_label(tr("SAVE_IN_MATCH"), GameTheme.ACCENT)
	_lock_note.visible = false
	col.add_child(_lock_note)
	_message = _note_label(tr("SAVE_NOT_WRITTEN"), GameTheme.BAD)
	_message.visible = false
	col.add_child(_message)
	for i in SaveKeeper.RESTORE_POINTS:
		col.add_child(_point_row(i))
	_none_yet = _note_label(tr("SAVE_NONE_YET"), GameTheme.TEXT)
	col.add_child(_none_yet)


## A restore point's line: its day (TODAY on today's) over when it was opened, its figures, and RESTORE.
func _point_row(i: int) -> PanelContainer:
	var line := PanelContainer.new()
	line.add_theme_stylebox_override("panel", GameTheme.box(GameTheme.CARD, GameTheme.LINE, POINT_PAD.x, POINT_PAD.y))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", FIGURE_GAP)
	line.add_child(row)
	var day_col := VBoxContainer.new()
	day_col.custom_minimum_size.x = DAY_WIDTH
	day_col.add_theme_constant_override("separation", 0)
	row.add_child(day_col)
	var day_row := HBoxContainer.new()
	day_row.add_theme_constant_override("separation", TAG_GAP)
	day_col.add_child(day_row)
	var day := MenuParts.text("", DAY_SIZE, 800, GameTheme.TEXT)
	day_row.add_child(day)
	var tag := MenuTag.make(tr("SAVE_TODAY").to_upper(), GameTheme.ACCENT_INK, GameTheme.ACCENT, GameTheme.ACCENT)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	day_row.add_child(tag)
	var opened := MenuParts.text("", OPENED_SIZE, 600, GameTheme.MUTED)
	day_col.add_child(opened)
	var figures := RichTextLabel.new()
	figures.bbcode_enabled = true
	figures.fit_content = true
	figures.autowrap_mode = TextServer.AUTOWRAP_OFF
	figures.scroll_active = false
	figures.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figures.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	figures.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	figures.add_theme_font_override("normal_font", GameTheme.font(600))
	figures.add_theme_font_override("bold_font", GameTheme.font(800))
	figures.add_theme_font_size_override("normal_font_size", FIGURE_SIZE)
	figures.add_theme_font_size_override("bold_font_size", FIGURE_SIZE)
	figures.add_theme_color_override("default_color", GameTheme.MUTED)
	row.add_child(figures)
	var restore := _button("SAVE_RESTORE", Color(0.0, 0.0, 0.0, 0.0), GameTheme.LINE, GameTheme.TEXT)
	restore.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	restore.pressed.connect(_ask_restore.bind(i))
	row.add_child(restore)
	_point_rows.append(line)
	_point_days.append(day)
	_point_today.append(tag)
	_point_opened.append(opened)
	_point_figures.append(figures)
	_restore.append(restore)
	return line


func _ask_restore(i: int) -> void:
	if not can_replace() or i >= _points.size():
		return
	var point := _points[i]
	var a := _compare(point.save, "SAVE_RESTORE_POINT")
	a.kicker = tr("SAVE_RESTORE_POINT")
	a.title = tr("SAVE_RESTORE_TITLE")
	a.lead = tr("SAVE_RESTORE_LEAD") % [_bold(date_words(point.taken_at, keeper.utc_offset_minutes)),
			_bold(tr("SAVE_UNDO"))]
	a.after = tr("SAVE_RESTORE_AFTER")
	a.yes = tr("SAVE_RESTORE_YES")
	_ask(a, func() -> bool: return keeper.replace(point.save, SaveKeeper.What.RESTORE), _restore[i])


# --- Undo ---

func _build_undo(col: VBoxContainer) -> void:
	_gap(col)
	col.add_child(MenuParts.heading(tr("SAVE_UNDO").to_upper()))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_GAP)
	col.add_child(row)
	_undo = _button("SAVE_UNDO", Color(0.0, 0.0, 0.0, 0.0), GameTheme.ACCENT, GameTheme.TEXT)
	_undo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_undo.pressed.connect(_ask_undo)
	row.add_child(_undo)
	_undo_line = _note_label("", GameTheme.MUTED)
	_undo_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_undo_line)


func _ask_undo() -> void:
	if not can_replace() or _slot == null or _slot.save.refusal() != "":
		return
	var slot := _slot
	var a := _compare(slot.save, "SAVE_UNDO_HEAD")
	a.kicker = tr("SAVE_UNDO")
	a.title = tr("SAVE_UNDO_TITLE")
	a.lead = tr("SAVE_UNDO_LEAD") % [tr(WHAT_KEYS[slot.what]), stamp(slot.taken_at, _now(),
			keeper.utc_offset_minutes)]
	a.after = tr("SAVE_RESTORE_AFTER")
	a.yes = tr("SAVE_UNDO_YES")
	_ask(a, keeper.undo, _undo)


# --- Delete ---

func _build_delete(col: VBoxContainer) -> void:
	_gap(col)
	var box := PanelContainer.new()
	var fill := GameTheme.PANEL.lerp(GameTheme.BAD, DANGER_TINT)
	box.add_theme_stylebox_override("panel", GameTheme.box(fill, GameTheme.BAD.darkened(0.3), DANGER_PAD.x,
			DANGER_PAD.y))
	col.add_child(box)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", SettingsScreen.ROW_GAP)
	box.add_child(words)
	var head := HBoxContainer.new()
	words.add_child(head)
	var title := MenuParts.spaced(tr("SAVE_DELETE_HEAD").to_upper(), DANGER_SIZE, 800, GameTheme.BAD,
			GameTheme.SPACING_TAB)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	_delete = _button("SAVE_DELETE", Color(0.0, 0.0, 0.0, 0.0), GameTheme.BAD, GameTheme.BAD)
	_delete.pressed.connect(_ask_delete)
	head.add_child(_delete)
	words.add_child(_note_label(tr("SAVE_DELETE_HELP"), GameTheme.MUTED))


func _ask_delete() -> void:
	if not can_replace():
		return
	_flush()
	var now := SaveBundle.read(keeper.store_paths)
	if now.is_empty():
		return
	var figures := _figures(now.summary())
	var a := SettingsSaveConfirm.Ask.new()
	a.tone = SettingsSaveConfirm.Tone.DANGER
	a.kicker = tr("SAVE_DELETE_HEAD")
	a.title = tr("SAVE_DELETE_TITLE")
	a.lead = tr("SAVE_DELETE_LEAD")
	a.tiles = true
	for i in GONE_KEYS.size():
		a.labels.append(tr(GONE_KEYS[i]))
		a.now.append(figures[FIRST_FIGURE + i])
	a.after = tr("SAVE_DELETE_AFTER") % _bold(tr("SAVE_UNDO"))
	a.keeps = tr("SAVE_DELETE_KEEPS")
	a.yes = tr("SAVE_DELETE_YES")
	_ask(a, keeper.delete_save, _delete)


# --- Asking, and yes ---

## The question comparing the save now with `then` (a restore point's or the Undo slot's) under `head_key`.
func _compare(then: SaveBundle, head_key: String) -> SettingsSaveConfirm.Ask:
	_flush()
	var now_summary := SaveBundle.read(keeper.store_paths).summary()
	var then_summary := then.summary()
	var a := SettingsSaveConfirm.Ask.new()
	a.then_head = tr(head_key)
	var now_cells := _figures(now_summary)
	var then_cells := _figures(then_summary)
	var at := _now()
	now_cells[0] = _saved_words(now_summary.saved_at, at)
	then_cells[0] = _saved_words(then_summary.saved_at, at)
	var now_counts := _counts(now_summary)
	var then_counts := _counts(then_summary)
	for i in ROW_KEYS.size():
		a.labels.append(tr(ROW_KEYS[i]))
		a.lower.append(i >= FIRST_FIGURE and then_counts[i - FIRST_FIGURE] < now_counts[i - FIRST_FIGURE])
	a.now = now_cells
	a.then = then_cells
	return a


func _ask(a: SettingsSaveConfirm.Ask, replace: Callable, asker: Button) -> void:
	_message.visible = false
	_pending = replace
	_asker = asker
	_confirm.ask(a)


## The question closed: the focus goes back to the button that asked it, or Back when that one is greyed now.
func _give_focus_back() -> void:
	var asker := _asker
	_asker = null
	if not is_visible_in_tree():
		return
	if asker != null and asker.is_visible_in_tree() and not asker.disabled:
		asker.grab_focus()
	else:
		_screen.focus_back()


## Yes: the shared stores saved, the save replaced, renderer.cfg from the settings now in place, then the restart. A
## replace that is refused or fails changes nothing, restarts nothing and says why.
func _on_confirmed() -> void:
	var replace := _pending
	_pending = Callable()
	if not replace.is_valid() or not can_replace():
		_confirm.close()
		return
	_flush()
	if not bool(replace.call()):
		push_warning("save file: %s" % keeper.last_error)
		refresh()
		_message.text = tr(refusal_key(keeper.refusal))
		_message.visible = true
		_confirm.close()
		return
	_pending = Callable()
	_asker = null
	_confirm.close()
	_put_renderer()
	_screen.restart.call()


## The en.po key of the player's line for `refusal` (a failed write's for NONE: a replace that said no without one).
static func refusal_key(refusal: SaveKeeper.Refusal) -> String:
	return REFUSAL_KEYS[refusal] if refusal != SaveKeeper.Refusal.NONE else "SAVE_NOT_WRITTEN"


## renderer.cfg asks for what the settings now in place ask for, so the restarted game starts on their renderer.
func _put_renderer() -> void:
	var restored := Settings.new(_screen.settings.tuning)
	restored.load_file(keeper.store_paths[SaveBundle.KINDS.find(Settings.KIND)])
	if not RendererOverride.put(restored.renderer, renderer_path):
		# the restart goes ahead: the save is replaced; the next start may use the renderer it had for one run
		push_warning("save file: %s couldn't be written for the restored settings (renderer %d); restarting anyway"
				% [renderer_path, restored.renderer])


## Saves what the running game holds that hasn't been, so the save kept for Undo is the one the player has.
func _flush() -> void:
	_screen.settings.save_if_dirty(_screen.save_path)
	if flush.is_valid():
		flush.call()
	else:
		SavedLoadouts.shared().save_if_dirty()
		Progress.shared().save_if_dirty()
		Records.shared().save_if_dirty()


# --- Words ---

## "Fri 23 Oct": `unix`'s day where the player is (`offset` minutes east of UTC).
static func date_words(unix: int, offset: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix + offset * MINUTE)
	return _t("SAVE_DATE") % [_t(WEEKDAY_KEYS[int(d["weekday"])]),
			int(d["day"]), _t(MONTH_KEYS[int(d["month"]) - 1])]


## "09:14": `unix`'s clock time where the player is.
static func clock_words(unix: int, offset: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix + offset * MINUTE)
	return "%02d:%02d" % [int(d["hour"]), int(d["minute"])]


## "Today 14:30", or "Thu 22 Oct 18:40" on another day than `now`'s.
static func stamp(unix: int, now: int, offset: int) -> String:
	var day := _t("SAVE_TODAY") if _same_day(unix, now, offset) else date_words(unix, offset)
	return _t("SAVE_STAMP") % [day, clock_words(unix, offset)]


## How long ago `unix` was, from `now`: "just now", "1 minute ago", "2 minutes ago" within the hour, then "today at
## 14:30" or "on Thu 22 Oct at 18:40".
static func ago(unix: int, now: int, offset: int) -> String:
	var gone := now - unix
	if gone < MINUTE:
		return _t("SAVE_JUST_NOW")
	if gone < HOUR:
		var minutes := gone / MINUTE
		return _t("SAVE_MINUTE_AGO" if minutes == 1 else "SAVE_MINUTES_AGO") % minutes
	if _same_day(unix, now, offset):
		return _t("SAVE_TODAY_AT") % clock_words(unix, offset)
	return _t("SAVE_ON_DAY_AT") % [date_words(unix, offset), clock_words(unix, offset)]


## `key`'s words (a static function can't call tr).
static func _t(key: String) -> String:
	return String(TranslationServer.translate(key))


static func _same_day(a: int, b: int, offset: int) -> bool:
	return Time.get_date_string_from_unix_time(a + offset * MINUTE) == Time.get_date_string_from_unix_time(
			b + offset * MINUTE)


func _now() -> int:
	return int(keeper.clock.call())


## A summary's cells in ROW_KEYS order (when saved left for the caller).
func _figures(s: SaveBundle.Summary) -> PackedStringArray:
	return PackedStringArray(["", s.version, str(s.level), ArmoryFacts.grouped(s.xp), ArmoryFacts.grouped(s.unlocked),
			ArmoryFacts.grouped(s.matches), str(s.loadouts)])


## A summary's figures, in ROW_KEYS order from FIRST_FIGURE.
func _counts(s: SaveBundle.Summary) -> Array[int]:
	return [s.level, s.xp, s.unlocked, s.matches, s.loadouts]


func _saved_words(saved_at: int, now: int) -> String:
	return tr("SAVE_NEVER") if saved_at == 0 else stamp(saved_at, now, keeper.utc_offset_minutes)


## The parts of `bundle` from a newer version, in the player's words.
func _newer_parts(bundle: SaveBundle) -> PackedStringArray:
	var out := PackedStringArray()
	for i in SaveBundle.KINDS.size():
		var kind := SaveBundle.KINDS[i]
		if bundle.stores.has(kind) and int(bundle.stores[kind]["version"]) > SaveBundle.VERSIONS[i]:
			out.append(tr(PART_KEYS[i]))
	return out


## A store's file in the player's words (its part), or the file's own name.
func _part_of(path: String) -> String:
	var at := keeper.store_paths.find(path)
	return tr(PART_KEYS[at]) if at >= 0 else path.get_file()


static func _bold(words: String) -> String:
	return "[b][color=#%s]%s[/color][/b]" % [GameTheme.TEXT.to_html(false), words]


# --- Building blocks ---

func _column(width: float) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.custom_minimum_size.x = width
	c.add_theme_constant_override("separation", SettingsScreen.ROW_GAP)
	add_child(c)
	return c


func _gap(col: VBoxContainer) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = SettingsScreen.SECTION_GAP
	col.add_child(gap)


func _note_label(words: String, colour: Color) -> Label:
	var note := MenuParts.text(words, NOTE_SIZE, 600, colour)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return note


func _button(key: String, fill: Color, edge: Color, ink: Color) -> Button:
	var b := Button.new()
	b.text = tr(key).to_upper()
	paint(b, fill, edge, ink, BUTTON_SIZE, BUTTON_PAD)
	return b


## Gives `b` a `fill` with an `edge` and words in `ink` at `size` (the concepts' `.btn` kinds); greyed, it is dim.
static func paint(b: Button, fill: Color, edge: Color, ink: Color, size: int, pad: Vector2i) -> void:
	var hover := fill.lightened(0.15) if fill.a > 0.0 else Color(edge, 0.15)
	var looks: Dictionary[String, StyleBoxFlat] = {"normal": GameTheme.box(fill, edge, pad.x, pad.y),
			"hover": GameTheme.box(hover, edge, pad.x, pad.y), "pressed": GameTheme.box(hover, edge, pad.x, pad.y),
			"disabled": GameTheme.box(Color(0.0, 0.0, 0.0, 0.0), GameTheme.LINE, pad.x, pad.y)}
	GameTheme.dress(b, looks["normal"], looks["hover"], looks["pressed"])
	b.add_theme_stylebox_override("disabled", looks["disabled"])
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(colour, ink)
	b.add_theme_font_override("font", GameTheme.spaced_font(800, GameTheme.SPACING_TAB, size))
	b.add_theme_font_size_override("font_size", size)
