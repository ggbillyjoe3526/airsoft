class_name GraphicsTable
extends RefCounted
## The graphics presets, read from data/graphics.md (the browser game's renderQuality.ts QUALITY and graphics.ts rows):
## per row its label key, the choices offered (or a range), its cost, the renderers that can draw it and each preset's
## value; and the choices only some renderers draw. Never throws: a cell it can't read keeps its built-in value
## (BUILT_IN, the file as shipped) and is listed in `problems`, each "graphics.md:line: …".

const PATH := "res://data/graphics.md"
const FILE_NAME := "graphics.md"
## The presets, cheapest first, and their columns in the file.
const PRESETS: Array[StringName] = [&"low", &"medium", &"high", &"ultra"]
const PRESET_COLUMNS: PackedStringArray = ["Low", "Medium", "High", "Ultra"]
## The preset Custom starts from when it names none, and an unknown name reads as: High, the look before the presets.
const DEFAULT_PRESET := &"high"
## RenderingServer.get_current_rendering_method()'s names, and the Renderers cell that means every one.
const RENDERERS: PackedStringArray = ["forward_plus", "mobile", "gl_compatibility"]
const ALL_RENDERERS := "all"
## Cost squares: 0 free to 3 large.
const MAX_COST := 3
## level_of's answer for a value the row doesn't offer, and level()'s for an unknown row.
const NO_LEVEL := -1
## The tables, by their first column's header, and the Rows table's other columns.
const ID_COLUMN := "ID"
const ROW_COLUMN := "Row"
const LABEL_COLUMN := "Label"
const CHOICES_COLUMN := "Choices"
const COST_COLUMN := "Cost"
const RENDERERS_COLUMN := "Renderers"
const CHOICE_COLUMN := "Choice"
## The Rows table as shipped, cell for cell: Label, Choices, Cost, Renderers, then Low, Medium, High and Ultra. (Arrays,
## as GraphicsQuality.CHOICES says why.)
const BUILT_IN: Dictionary[StringName, Array] = {
	GraphicsQuality.RENDER_SCALE: ["GRAPHICS_RENDER_SCALE", "50–100 %", "3", "all", "80 %", "100 %", "100 %", "100 %"],
	GraphicsQuality.UPSCALER: ["GRAPHICS_UPSCALER", "bilinear, fsr1, fsr2", "1", "all", "fsr1", "fsr1", "fsr1", "fsr1"],
	GraphicsQuality.EDGE_SMOOTHING: ["GRAPHICS_EDGE_SMOOTHING", "off, fxaa, smaa, msaa_2x, msaa_4x", "3", "all", "off",
			"off", "off", "off"],
	GraphicsQuality.TEMPORAL_SMOOTHING: ["GRAPHICS_TEMPORAL_SMOOTHING", "off, on", "2", "forward_plus", "off", "off",
			"off", "off"],
	GraphicsQuality.SUN_SHADOWS: ["GRAPHICS_SUN_SHADOWS", "off, on", "3", "all", "off", "on", "on", "on"],
	GraphicsQuality.SHADOW_DETAIL: ["GRAPHICS_SHADOW_DETAIL", "1024, 2048, 4096, 8192", "2", "all", "1024", "2048",
			"4096", "8192"],
	GraphicsQuality.SHADOW_SOFTNESS: ["GRAPHICS_SHADOW_SOFTNESS", "hard, soft, softer, softest", "1", "all", "hard",
			"soft", "softer", "softest"],
	GraphicsQuality.SHADOW_RANGE: ["GRAPHICS_SHADOW_RANGE", "30–120 m", "1", "all", "40 m", "50 m", "70 m", "100 m"],
	GraphicsQuality.AMBIENT_OCCLUSION: ["GRAPHICS_AMBIENT_OCCLUSION", "off, half, full", "3", "forward_plus", "off",
			"off", "half", "full"],
	GraphicsQuality.BAKED_LIGHT: ["GRAPHICS_BAKED_LIGHT", "off, on", "1", "all", "off", "on", "on", "on"],
	GraphicsQuality.TEXTURE_FILTERING: ["GRAPHICS_TEXTURE_FILTERING", "off, 2x, 4x, 8x, 16x", "1", "all", "2x", "4x",
			"16x", "16x"],
	GraphicsQuality.MESH_DETAIL: ["GRAPHICS_MESH_DETAIL", "low, medium, high, ultra", "1", "all", "low", "medium",
			"high", "ultra"],
	GraphicsQuality.WIND_DUST: ["GRAPHICS_WIND_DUST", "0–100 %", "0", "all", "0 %", "50 %", "100 %", "100 %"],
	GraphicsQuality.GLOBAL_ILLUMINATION: ["GRAPHICS_GLOBAL_ILLUMINATION", "off, screen, scene", "3", "forward_plus",
			"off", "off", "screen", "scene"],
	GraphicsQuality.REFLECTIONS: ["GRAPHICS_REFLECTIONS", "off, probes, screen", "2", "all", "off", "probes", "probes",
			"screen"],
	GraphicsQuality.GLOW: ["GRAPHICS_GLOW", "off, on", "1", "all", "off", "on", "on", "on"],
	GraphicsQuality.VOLUMETRIC_FOG: ["GRAPHICS_VOLUMETRIC_FOG", "off, on", "3", "forward_plus", "off", "off", "off",
			"on"],
}
## BUILT_IN's cells, by column.
const CELL_LABEL := 0
const CELL_CHOICES := 1
const CELL_COST := 2
const CELL_RENDERERS := 3
const CELL_FIRST_PRESET := 4
## The choices only some renderers draw, as shipped: row, choice, renderers.
const BUILT_IN_ONLY: Array[Array] = [
	["upscaler", "fsr1", "forward_plus"],
	["upscaler", "fsr2", "forward_plus"],
	["edge_smoothing", "fxaa", "forward_plus, mobile"],
	["edge_smoothing", "smaa", "forward_plus, mobile"],
	["reflections", "screen", "forward_plus"],
]


## One row of the table.
class Row:
	extends RefCounted
	var id: StringName = &""
	## Its name on the Graphics tab, a translation key.
	var label: String = ""
	## A choice row's choices offered, in order (GraphicsQuality.CHOICES' names); empty for a range row.
	var choices: PackedStringArray = PackedStringArray()
	## A range row's lowest and highest number, and its unit as the file writes it ("%", "m").
	var lo: int = 0
	var hi: int = 0
	var unit: String = ""
	var cost: int = 0
	var renderers: PackedStringArray = PackedStringArray()
	## Each preset's level, in PRESETS order.
	var values: Array[int] = []
	## The renderers that can draw a choice, for a choice only some can (by its name).
	var only: Dictionary[String, PackedStringArray] = {}


## Every GraphicsQuality row, always all of them.
var rows: Dictionary[StringName, Row] = {}
var problems: Array[String] = []

static var _shared: GraphicsTable = null


## The table as shipped, read once; its problems go to the log.
static func shared() -> GraphicsTable:
	if _shared == null:
		_shared = read_file()
		for p in _shared.problems:
			push_warning("graphics: %s" % p)
	return _shared


static func read_file(path: String = PATH) -> GraphicsTable:
	if not FileAccess.file_exists(path):
		var none := parse("")
		none.problems.push_front("%s can't be read: using the built-in presets" % path)
		return none
	return parse(FileAccess.get_file_as_string(path))


static func parse(text: String) -> GraphicsTable:
	var t := GraphicsTable.new()
	var tables := DataTable.read_all(text, FILE_NAME)
	for id in GraphicsQuality.ROWS:
		t.rows[id] = t._built_in_row(id)
	for only in BUILT_IN_ONLY:
		t.rows[StringName(only[0])].only[String(only[1])] = _renderers(String(only[2]))
	var main := _first_column(tables, ID_COLUMN)
	if main == null:
		if text != "":
			t.problems.append("%s: no table with an %s column: using the built-in presets" % [FILE_NAME, ID_COLUMN])
	else:
		t._read_rows(main)
	t._read_only(_first_column(tables, ROW_COLUMN))
	for table in tables:
		t.problems.append_array(table.problems)
	return t


## `name`'s values (a new object), or DEFAULT_PRESET's for a name that isn't a preset.
func preset(name: StringName) -> GraphicsQuality:
	var at := PRESETS.find(name)
	if at < 0:
		at = PRESETS.find(DEFAULT_PRESET)
	var q := GraphicsQuality.new()
	for id in GraphicsQuality.ROWS:
		q.set_level(id, rows[id].values[at])
	return q


func row(id: StringName) -> Row:
	return rows.get(id, null)


## True if `row_id` offers `level`: one of its choices, or a number in its range.
func valid(row_id: StringName, level: int) -> bool:
	var r := row(row_id)
	if r == null:
		return false
	if GraphicsQuality.is_range(row_id):
		return level >= r.lo and level <= r.hi
	var names: Array = GraphicsQuality.CHOICES[row_id]
	return level >= 0 and level < names.size() and r.choices.has(String(names[level]))


## The level a saved Custom value stands for (a choice's name, or a range row's whole number), or NO_LEVEL if the row
## doesn't offer it.
func level_of(row_id: StringName, saved: Variant) -> int:
	if row(row_id) == null:
		return NO_LEVEL
	var level := NO_LEVEL
	if GraphicsQuality.is_range(row_id):
		if (saved is int or saved is float) and is_finite(float(saved)):
			level = roundi(float(saved))
	elif saved is String or saved is StringName:
		level = GraphicsQuality.CHOICES[row_id].find(String(saved))
	return level if valid(row_id, level) else NO_LEVEL


## `level` as a saved Custom value: the inverse of level_of.
func saved_value(row_id: StringName, level: int) -> Variant:
	if GraphicsQuality.is_range(row_id):
		return level
	var names: Array = GraphicsQuality.CHOICES[row_id]
	return String(names[level]) if level >= 0 and level < names.size() else ""


## True if `rendering_method` (RenderingServer.get_current_rendering_method()) can draw `row_id` at `level`.
func can_draw(row_id: StringName, level: int, rendering_method: String) -> bool:
	var r := row(row_id)
	if r == null or not r.renderers.has(rendering_method):
		return false
	if GraphicsQuality.is_range(row_id):
		return true
	var name := String(saved_value(row_id, level))
	return not r.only.has(name) or r.only[name].has(rendering_method)


func _built_in_row(id: StringName) -> Row:
	var cells: Array = BUILT_IN[id]
	var r := Row.new()
	r.id = id
	r.label = String(cells[CELL_LABEL])
	_read_choices(r, String(cells[CELL_CHOICES]))
	r.cost = String(cells[CELL_COST]).to_int()
	r.renderers = _renderers(String(cells[CELL_RENDERERS]))
	for p in PRESETS.size():
		r.values.append(_value(r, String(cells[CELL_FIRST_PRESET + p])))
	return r


func _read_rows(table: DataTable) -> void:
	var missing: Array[String] = []
	for header: String in [LABEL_COLUMN, CHOICES_COLUMN, COST_COLUMN, RENDERERS_COLUMN] + Array(PRESET_COLUMNS):
		if not table.has_column(header):
			missing.append(header)
			table.problem(table.line, "no %s column: every row keeps its built-in %s" % [header, header])
	var seen: Dictionary[StringName, bool] = {}
	for line in table.rows:
		var id := StringName(line.key)
		if not rows.has(id):
			table.problem(line.line, "unknown row \"%s\": skipped (the rows the game knows are %s)"
					% [line.key, ", ".join(PackedStringArray(GraphicsQuality.ROWS))])
			continue
		if seen.has(id):
			table.problem(line.line, "row \"%s\" appears twice: the second is skipped" % line.key)
			continue
		seen[id] = true
		_read_row(table, line, rows[id], missing)
	for id in GraphicsQuality.ROWS:
		if not seen.has(id):
			table.problem(table.line, "no row \"%s\": it keeps its built-in values" % id)


func _read_row(table: DataTable, line: DataTable.Row, r: Row, missing: Array[String]) -> void:
	var built: Array[int] = r.values.duplicate()
	if not missing.has(LABEL_COLUMN):
		var label := line.cell(LABEL_COLUMN)
		if label == "" or label.contains(" "):
			table.problem(line.line, "%s's Label \"%s\" isn't a translation key: kept %s" % [r.id, label, r.label])
		else:
			r.label = label
	if not missing.has(CHOICES_COLUMN):
		var cell := line.cell(CHOICES_COLUMN)
		var tried := Row.new()
		tried.id = r.id
		var why := _read_choices(tried, cell)
		if why != "":
			table.problem(line.line, "%s's Choices \"%s\" %s: kept the built-in ones" % [r.id, cell, why])
		else:
			r.choices = tried.choices
			r.lo = tried.lo
			r.hi = tried.hi
			r.unit = tried.unit
	if not missing.has(COST_COLUMN):
		var cost := line.cell(COST_COLUMN)
		if not cost.is_valid_int() or cost.to_int() < 0 or cost.to_int() > MAX_COST:
			table.problem(line.line, "%s's Cost \"%s\" isn't a whole number from 0 to %d: kept %d" % [r.id, cost, MAX_COST, r.cost])
		else:
			r.cost = cost.to_int()
	if not missing.has(RENDERERS_COLUMN):
		var names := _renderers(line.cell(RENDERERS_COLUMN))
		if names.is_empty():
			table.problem(line.line, "%s's Renderers \"%s\" names none of %s or %s: kept the built-in ones"
					% [r.id, line.cell(RENDERERS_COLUMN), ", ".join(RENDERERS), ALL_RENDERERS])
		else:
			r.renderers = names
	for p in PRESETS.size():
		r.values[p] = _fallback(r, built[p])
		if missing.has(PRESET_COLUMNS[p]):
			continue
		var cell := line.cell(PRESET_COLUMNS[p])
		var v := _value(r, cell)
		if v == NO_LEVEL:
			table.problem(line.line, "%s's %s \"%s\" isn't one of its choices: kept %s"
					% [r.id, PRESET_COLUMNS[p], cell, _shown(r, r.values[p])])
		else:
			r.values[p] = v


## Reads the choices offered into `r` (or a range, with its unit); the reason it can't, or "".
func _read_choices(r: Row, cell: String) -> String:
	if GraphicsQuality.is_range(r.id):
		var text := cell.strip_edges().replace("–", "-").replace("—", "-")
		var bare := _without_unit(text)
		var ends := bare.split("-")
		if ends.size() != 2 or not ends[0].strip_edges().is_valid_int() or not ends[1].strip_edges().is_valid_int():
			return "isn't a range such as 30–120"
		var limits: Vector2i = GraphicsQuality.LIMITS[r.id]
		var lo := ends[0].strip_edges().to_int()
		var hi := ends[1].strip_edges().to_int()
		if lo > hi or lo < limits.x or hi > limits.y:
			return "isn't a range within %d–%d" % [limits.x, limits.y]
		r.lo = lo
		r.hi = hi
		r.unit = text.substr(bare.length()).strip_edges()
		return ""
	var known := PackedStringArray(GraphicsQuality.CHOICES[r.id])
	var offered := DataTable.names(cell)
	if offered.is_empty():
		return "offers nothing"
	for i in offered.size():
		if not known.has(offered[i]):
			return "names \"%s\", which isn't one of %s" % [offered[i], ", ".join(known)]
		if offered.find(offered[i]) != i:
			return "names \"%s\" twice" % offered[i]
	r.choices = offered
	return ""


## A preset cell's level for `r`, or NO_LEVEL.
static func _value(r: Row, cell: String) -> int:
	var text := cell.strip_edges()
	if GraphicsQuality.is_range(r.id):
		var bare := _without_unit(text).strip_edges()
		if not bare.is_valid_int() or bare.to_int() < r.lo or bare.to_int() > r.hi:
			return NO_LEVEL
		return bare.to_int()
	if not r.choices.has(text):
		return NO_LEVEL
	return GraphicsQuality.CHOICES[r.id].find(text)


## The built-in `level` if the row (its choices maybe changed by the file) still offers it, else its nearest: the first
## choice offered, or the range's nearer end.
static func _fallback(r: Row, level: int) -> int:
	if GraphicsQuality.is_range(r.id):
		return clampi(level, r.lo, r.hi)
	var names: Array = GraphicsQuality.CHOICES[r.id]
	if level >= 0 and level < names.size() and r.choices.has(String(names[level])):
		return level
	return names.find(r.choices[0])


## `level` as the file writes it, for messages.
static func _shown(r: Row, level: int) -> String:
	if GraphicsQuality.is_range(r.id):
		return "%d %s" % [level, r.unit] if r.unit != "" else str(level)
	return String(GraphicsQuality.CHOICES[r.id][level])


func _read_only(table: DataTable) -> void:
	if table == null:
		return
	var kept: Dictionary[String, PackedStringArray] = {}
	for line in table.rows:
		var id := StringName(line.key)
		var choice := line.cell(CHOICE_COLUMN).strip_edges()
		var names := _renderers(line.cell(RENDERERS_COLUMN))
		var r := row(id)
		if r == null or GraphicsQuality.is_range(id) or not GraphicsQuality.CHOICES[id].has(choice):
			table.problem(line.line, "\"%s\" \"%s\" isn't a row and one of its choices: skipped" % [line.key, choice])
		elif names.is_empty():
			table.problem(line.line, "%s %s's Renderers \"%s\" names none of %s: kept the built-in ones"
					% [id, choice, line.cell(RENDERERS_COLUMN), ", ".join(RENDERERS)])
			if r.only.has(choice):
				kept[String(id) + "/" + choice] = r.only[choice]
		else:
			kept[String(id) + "/" + choice] = names
	# The file's table replaces the built-in one: a choice it leaves out is drawn by every renderer its row is.
	for id in GraphicsQuality.ROWS:
		rows[id].only.clear()
	for key in kept:
		var parts := key.split("/")
		rows[StringName(parts[0])].only[parts[1]] = kept[key]


## The renderers a Renderers cell names (`all` for every one), or none if it names one the game doesn't know.
static func _renderers(cell: String) -> PackedStringArray:
	if cell.strip_edges() == ALL_RENDERERS:
		return RENDERERS.duplicate()
	var names := DataTable.names(cell)
	for n in names:
		if not RENDERERS.has(n):
			return PackedStringArray()
	return names


## `text` up to its trailing unit ("80 %" → "80 ", "30-120 m" → "30-120 ").
static func _without_unit(text: String) -> String:
	var end := text.length()
	while end > 0 and not (text[end - 1] >= "0" and text[end - 1] <= "9"):
		end -= 1
	return text.left(end)


static func _first_column(tables: Array[DataTable], header: String) -> DataTable:
	for t in tables:
		if t.headers.size() > 0 and t.headers[0] == header:
			return t
	return null
