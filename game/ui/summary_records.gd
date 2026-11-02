class_name SummaryRecords
extends PanelContainer
## The match summary's records panel (concept `summary.png`; the browser game's recordsView): "Your records · Hard
## Elimination", then won and lost at that difficulty and mode, the best accuracy (NEW RECORD with the best before it
## when this match beat it; a match counts from Records.ACCURACY_MIN_BBS BBs) and the wins in a row with the best run
## (NEW RECORD when this match made it). A match that stays out of the records says so beside the heading.

const VALUE_SIZE := 17
const NOTE_SIZE := 14
const CHIP_SIZE := 11
const CHIP_PAD := Vector2i(6, 2)

var _column: VBoxContainer = null
var _rule: StyleBoxFlat = null
var _chip: StyleBoxFlat = null
## The rows' values as shown ("9% NEW RECORD was 7%"): for tests.
var _values := PackedStringArray()


func _init() -> void:
	name = "SummaryRecords"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", MatchSummary.panel_box())
	_column = MatchSummary.column(self, 0)
	_rule = MatchSummary.row_rule()
	_chip = GameTheme.box(GameTheme.ACCENT, Color(0.0, 0.0, 0.0, 0.0), CHIP_PAD.x, CHIP_PAD.y)


## Fills it from `records` under `heading`, with `win_loss` at this difficulty and mode and what this match changed
## (`news`; null when it stays out of the records).
func fill(records: Records, win_loss: PackedInt32Array, news: Records.News, heading: String) -> void:
	for c in _column.get_children():
		_column.remove_child(c)
		c.queue_free()
	_values.clear()
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.custom_minimum_size.y = MatchSummary.ROW_HEIGHT
	_column.add_child(top)
	var head := MatchSummary.title(top, "", heading)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if news == null:
		var out := HudStyle.label(top, NOTE_SIZE, 500, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		out.text = tr("SUM_NOT_COUNTED")
		out.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var line := MatchSummary.row(_column, _rule, tr("SUM_WON_LOST"))
	_value(line, tr("SUM_WON_LOST_VALUE") % [win_loss[0], win_loss[1]], false, "")
	line = MatchSummary.row(_column, _rule, tr("SUM_BEST_ACCURACY"))
	var beat := news != null and news.best_accuracy
	if records.best_accuracy < 0.0:
		_value(line, MatchSummary.NO_ACCURACY, false, tr("SUM_FROM_BBS") % Records.ACCURACY_MIN_BBS)
	else:
		_value(line, _percent(records.best_accuracy), beat,
				tr("SUM_WAS") % _percent(news.was_accuracy) if beat and news.was_accuracy >= 0.0 else "")
	line = MatchSummary.row(_column, _rule, tr("SUM_STREAK"))
	_value(line, str(records.streak), news != null and news.best_streak, tr("SUM_BEST") % records.best_streak)


## The rows' values as shown, in order: for tests.
func values() -> PackedStringArray:
	return _values


func _value(line: HBoxContainer, value: String, new_record: bool, note: String) -> void:
	var v := HudStyle.label(line, VALUE_SIZE, 700, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	v.text = value
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var shown := value
	if new_record:
		var chip := HudStyle.label(line, CHIP_SIZE, 800, GameTheme.ACCENT_INK, HORIZONTAL_ALIGNMENT_CENTER,
				HudStyle.SPACING_ROUND)
		chip.text = HudStyle.caps("SUM_NEW_RECORD")
		chip.add_theme_stylebox_override("normal", _chip)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		shown += " " + chip.text
	if note != "":
		var n := HudStyle.label(line, NOTE_SIZE, 500, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		n.text = note
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		shown += " " + note
	_values.append(shown)


static func _percent(share: float) -> String:
	return "%d%%" % roundi(share * 100.0)
