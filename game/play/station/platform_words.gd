class_name PlatformWords
extends RefCounted
## Words painted on a station's floor (TB1: MIND THE GAP along each platform's coping, StationDressing.Words) as flat
## quads in StationSurface's mesh: block capitals on a grid of GLYPH_ROWS rows, each row's runs of paint one quad.
## Look only, at build time; a letter the font lacks is left as a space.

## Each capital's rows, top first, `#` painted: the letters the station's words use.
const GLYPHS: Dictionary[String, PackedStringArray] = {
	"A": [".###.", "#...#", "#####", "#...#", "#...#"],
	"D": ["####.", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "####.", "#....", "#####"],
	"G": [".####", "#....", "#..##", "#...#", ".###."],
	"H": ["#...#", "#...#", "#####", "#...#", "#...#"],
	"I": ["#####", "..#..", "..#..", "..#..", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#...#", "#...#"],
	"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#"],
	"P": ["####.", "#...#", "####.", "#....", "#...."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#.."],
}
const GLYPH_ROWS := 5
const GLYPH_COLUMNS := 5
## Columns between letters (a space is a letter of none).
const GLYPH_GAP := 1


## The painted rectangles of `text` set from its left end at 0, in grid cells: each Rect2i a run along a row (x the
## column, y the row from the top).
static func runs(text: String) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var left := 0
	for ch in text:
		var rows: PackedStringArray = GLYPHS.get(ch, PackedStringArray())
		for r in rows.size():
			var row := rows[r]
			var start := -1
			for c in GLYPH_COLUMNS + 1:
				var on := c < row.length() and row[c] == "#"
				if on and start < 0:
					start = c
				elif not on and start >= 0:
					out.append(Rect2i(left + start, r, c - start, 1))
					start = -1
		left += GLYPH_COLUMNS + GLYPH_GAP
	return out


## `text`'s width in grid cells.
static func width(text: String) -> int:
	return maxi(0, text.length() * (GLYPH_COLUMNS + GLYPH_GAP) - GLYPH_GAP)


## Appends words `w` to `st` in `look`'s words finish: the text centred across its strip, once every `every` m along
## it (as many as fit whole, centred along it), reading from the side its tops face away from.
static func add(st: SurfaceTool, look: StationLook, w: StationDressing.Words) -> void:
	var cell := w.height / float(GLYPH_ROWS)
	var length := float(width(w.text)) * cell
	var count := floori((w.area.size.x - length) / w.every) + 1 if w.area.size.x >= length else 0
	if count <= 0:
		return
	var y := w.y + look.strip_lift + look.words_lift
	# Read facing the tops' way: along +x when they face -z, along -x when +z.
	var run := -w.up
	var top := w.area.get_center().y + w.up * w.height * 0.5
	var first := w.area.get_center().x - float(count - 1) * w.every * 0.5
	var tint := look.tint_of(look.words_finish, null)
	var cells := runs(w.text)
	for i in count:
		var start := first + float(i) * w.every - run * length * 0.5
		for c in cells:
			var xa := start + run * float(c.position.x) * cell
			var xb := start + run * float(c.end.x) * cell
			var za := top - w.up * float(c.position.y) * cell
			var zb := top - w.up * float(c.end.y) * cell
			var x0 := minf(xa, xb)
			var x1 := maxf(xa, xb)
			var z0 := minf(za, zb)
			var z1 := maxf(za, zb)
			var quad := PackedVector3Array([Vector3(x0, y, z0), Vector3(x0, y, z1), Vector3(x1, y, z1),
					Vector3(x1, y, z0)])
			StationSurface.add_face(st, look, quad, look.words_finish, tint, StationSurface.NO_FLOOR)
