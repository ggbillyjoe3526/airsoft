class_name PerformanceSheet
extends PanelContainer
## The Performance panel on the Loadout and Customise pages (concept `.perf`): a row for each figure with its bar and value,
## the value green when it beats the replica as it comes and red when it falls short, and a yellow CAPPED tag when the site
## limit cut the energy. What got better and worse, in words, is the panel's tooltip and the limit's line the energy row's,
## so the panel keeps one height while a slider is dragged (UI1 round 1). Rows are built once; `show_sheet` changes their
## texts, bars and colours.

const PAD := Vector2i(24, 22)
const WIDTH := 500.0
## The gap under the title.
const SUB_GAP := 16
const ROW_HEIGHT := 38.0
const ROW_GAP := 12
const NAME_WIDTH := 150.0
const VALUE_WIDTH := 130.0
const NAME_SIZE := 16
const VALUE_SIZE := 17
const UNIT_SIZE := 13
const UNIT_GAP := 5
const BAR_HEIGHT := 8.0
const BAR_BACK := Color(1.0, 1.0, 1.0, 0.08)

var _rows: Array[Dictionary] = []
## The heading's " · AEG RIFLE" ("" until a page names the replica).
var _replica: Label = null
## What the sheet compares, and the lines in words of what got better, worse and capped ("" for none).
var _sub: String = ""
var _better: String = ""
var _worse: String = ""
var _capped: String = ""


func _init() -> void:
	name = "PerformanceSheet"
	custom_minimum_size = Vector2(WIDTH, 0.0)
	add_theme_stylebox_override("panel", GameTheme.panel_box(PAD.x, PAD.y))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	# a section heading like the pages' others (UR3): PERFORMANCE · and the replica it shows
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 0)
	title.add_child(MenuParts.heading(TranslationServer.translate("PERF_TITLE")))
	_replica = MenuParts.heading("")
	title.add_child(_replica)
	column.add_child(title)
	column.add_child(_gap(SUB_GAP))
	for spec in LoadoutPerformance.SPECS:
		_rows.append(_build_row(column, spec))


## Names the replica the sheet shows, after PERFORMANCE.
func set_replica(display_name: String) -> void:
	_replica.text = (" · " + display_name).to_upper() if display_name != "" else ""


## The row for `field`'s value label, for the tests and the screenshots.
func value_label(field: StringName) -> Label:
	for r in _rows:
		if r["field"] == field:
			return r["value"]
	return null


## The Magazines row's count label beside its value (hidden on the other rows), for the tests.
func second_label(field: StringName) -> Label:
	for r in _rows:
		if r["field"] == field:
			return r["second"]
	return null


## The CAPPED tag on the energy row.
func capped_tag() -> Control:
	return _rows[0]["tag"]


## What got better, in the panel's tooltip; "" for nothing.
func better_line() -> String:
	return _better


func worse_line() -> String:
	return _worse


## The line in words about the site limit, in the energy row's tooltip; "" when nothing was capped.
func capped_line() -> String:
	return _capped


## What the sheet compares, in words: the start of the panel's tooltip (UI1: the line under the title only explained).
func sub_text() -> String:
	return _sub


## True if the row for `field` is on show.
func row_shown(field: StringName) -> bool:
	for r in _rows:
		if r["field"] == field:
			return (r["row"] as Control).visible
	return false


## Shows `sheet`, with `sub` and what got better and worse as the panel's tooltip. `extra` names the tab-only rows this page wants (Zoom aimed, Aim in); with `words`
## false the better and worse lines are left off (a part tab says it under its cards).
func show_sheet(sheet: LoadoutPerformance.Sheet, sub: String, extra: PackedStringArray = PackedStringArray(),
		words: bool = true) -> void:
	_sub = sub
	for i in sheet.rows.size():
		var row := sheet.rows[i]
		var ui: Dictionary = _rows[i]
		(ui["row"] as Control).visible = row.is_shown(extra)
		var colour := verdict_colour(row.verdict)
		var split := row.parts.size() == 2
		(ui["value"] as Label).text = row.parts[0] if split else row.text
		(ui["value"] as Label).add_theme_color_override("font_color",
				verdict_colour(row.part_verdicts[0]) if split else colour)
		var second := ui["second"] as Label
		second.visible = split
		if split:
			second.text = row.parts[1]
			second.add_theme_color_override("font_color", verdict_colour(row.part_verdicts[1]))
		(ui["fill"] as ColorRect).anchor_right = row.bar
		(ui["fill"] as ColorRect).color = colour
		var unit: String = TranslationServer.translate(row.unit_key) if row.unit_key != "" else ""
		(ui["unit"] as Label).text = unit
		(ui["row"] as Control).tooltip_text = TranslationServer.translate("PERF_AS_COMES") % [
				TranslationServer.translate(row.name_key), row.as_comes_text, unit]
	var capped := sheet.capped
	(_rows[0]["tag"] as Control).visible = capped
	_better = _line("PERF_BETTER", sheet.keys_with(1, extra) if words else PackedStringArray())
	_worse = _line("PERF_WORSE", sheet.keys_with(-1, extra) if words else PackedStringArray())
	_capped = TranslationServer.translate("PERF_CAPPED") % sheet.limit if capped else ""
	if capped:
		var energy := _rows[0]["row"] as Control
		energy.tooltip_text = "%s\n%s" % [energy.tooltip_text, _capped]
	var tip := PackedStringArray([sub])
	for l: String in [_better, _worse]:
		if l != "":
			tip.append(l)
	tooltip_text = "\n".join(tip)


## `key`'s line naming the rows `names`; "" for none.
static func _line(key: String, names: PackedStringArray) -> String:
	if names.is_empty():
		return ""
	var words := PackedStringArray()
	for n in names:
		words.append(TranslationServer.translate(n))
	return TranslationServer.translate(key) % ", ".join(words)


func _build_row(into: Control, spec: Dictionary) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_GAP)
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	into.add_child(row)
	var label := MenuParts.text(TranslationServer.translate(spec["name"]), NAME_SIZE, 600, GameTheme.MUTED)
	label.custom_minimum_size = Vector2(NAME_WIDTH, 0.0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var track := ColorRect.new()
	track.color = BAR_BACK
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(track)
	var fill := ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = 0.0
	track.add_child(fill)
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", UNIT_GAP)
	cell.alignment = BoxContainer.ALIGNMENT_END
	cell.custom_minimum_size = Vector2(VALUE_WIDTH, 0.0)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cell)
	var tag := MenuTag.make(TranslationServer.translate("PERF_CAPPED_TAG"), GameTheme.ACCENT, GameTheme.ACCENT)
	tag.visible = false
	cell.add_child(tag)
	var value := MenuParts.text("", VALUE_SIZE, 800, GameTheme.TEXT)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(value)
	# the Magazines row's count, coloured apart from its size (Row.parts)
	var second := MenuParts.text("", VALUE_SIZE, 800, GameTheme.TEXT)
	second.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	second.visible = false
	cell.add_child(second)
	var unit := MenuParts.text("", UNIT_SIZE, 700, GameTheme.MUTED)
	unit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(unit)
	return {"field": spec["field"], "row": row, "fill": fill, "value": value, "second": second, "unit": unit, "tag": tag}


## Better green, worse red, the same in the text's colour.
static func verdict_colour(verdict: int) -> Color:
	return GameTheme.GOOD if verdict > 0 else GameTheme.BAD if verdict < 0 else GameTheme.TEXT


func _gap(height: int) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0.0, height)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g
