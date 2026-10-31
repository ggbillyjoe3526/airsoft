extends GutTest
## The colour check (AC1; the browser game's colourVision.test.ts and its map rule readsAsTeam): both team colour sets
## seen with normal, protan, deutan and tritan vision (Machado, Oliveira and Fernandes 2009 at full severity, on linear
## RGB) and compared in CIE Lab (ΔE 1976); and no prop or map paint near a team's hue unless data/accessibility.md lists
## it as an exception. A ΔE over about 50 is two plainly different colours; under about 10 they can be mistaken.

## The visions' matrices, row by row.
const VISIONS: Dictionary[String, Array] = {
	"normal": [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
	"protan": [0.152286, 1.052583, -0.204868, 0.114503, 0.786281, 0.099216, -0.003882, -0.048116, 1.051998],
	"deutan": [0.367322, 0.860646, -0.227968, 0.280085, 0.672501, 0.047413, -0.01182, 0.04294, 0.968881],
	"tritan": [1.255528, -0.076749, -0.178779, -0.078411, 0.930809, 0.147602, 0.004733, 0.691367, 0.3039],
}
## The browser game's thresholds: teams this far apart in ΔE under every vision; High contrast this far apart in
## lightness on figures and on the HUD (whose orange is lifted to read on the dark panels), and its least gap more than
## LIGHTNESS_TIMES Standard's least.
const MIN_DELTA_E := 60.0
const MIN_FIGURES_GAP := 25.0
const MIN_HUD_GAP := 15.0
const LIGHTNESS_TIMES := 3.0
## Standard's published ΔE (protan, deutan, tritan) for #3d8bff and #ff8a2a, within GUARD_SLACK (the browser's
## toBeCloseTo(x, -1)): guards the simulation itself.
const PUBLISHED_STANDARD: Array[float] = [122.0, 138.0, 94.0]
const GUARD_SLACK := 5.0
## The prop rule (the browser game's TEAM_COLOUR_RULE): a colour this saturated or more (HSL on linear RGB) and this
## close to a team's hue reads as that team.
const HUE_MARGIN := 20.0
const MIN_SATURATION := 0.3
## A colour written as #rrggbb matches one within half a step of 8 bits each way.
const HEX_SLACK := 1.0 / 255.0 + 1e-6
const MAPS_DIR := "res://data/maps"
## The old Woodland kept for tests (OldWoodland): its painted pieces keep the reader checked while no shipped map
## paints.
const FIXTURE_DIR := "res://tests/support/maps"

var table: AccessibilityTable


func before_all() -> void:
	table = AccessibilityTable.read_file()


## `c` as CIE Lab (D65) as seen with `vision`.
static func _lab(c: Color, vision: String) -> Vector3:
	var lin := Vector3(_linear(c.r), _linear(c.g), _linear(c.b))
	var m: Array = VISIONS[vision]
	var r := clampf(m[0] * lin.x + m[1] * lin.y + m[2] * lin.z, 0.0, 1.0)
	var g := clampf(m[3] * lin.x + m[4] * lin.y + m[5] * lin.z, 0.0, 1.0)
	var b := clampf(m[6] * lin.x + m[7] * lin.y + m[8] * lin.z, 0.0, 1.0)
	var x := _f((0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047)
	var y := _f(0.2126 * r + 0.7152 * g + 0.0722 * b)
	var z := _f((0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883)
	return Vector3(116.0 * y - 16.0, 500.0 * (x - y), 200.0 * (y - z))


static func _linear(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 216.0 / 24389.0 else ((24389.0 / 27.0) * t + 16.0) / 116.0


static func _delta_e(a: Color, b: Color, vision: String) -> float:
	return _lab(a, vision).distance_to(_lab(b, vision))


static func _gap(a: Color, b: Color, vision: String) -> float:
	return absf(_lab(a, vision).x - _lab(b, vision).x)


## The least lightness gap between a pair's two colours across the four visions.
static func _least_gap(pair: PackedColorArray) -> float:
	var least := INF
	for vision: String in VISIONS:
		least = minf(least, _gap(pair[0], pair[1], vision))
	return least


## HSL hue (degrees) and saturation of `c` on linear RGB.
static func _hue_sat(c: Color) -> Vector2:
	var lin := Color(_linear(c.r), _linear(c.g), _linear(c.b))
	var hi := maxf(lin.r, maxf(lin.g, lin.b))
	var lo := minf(lin.r, minf(lin.g, lin.b))
	var d := hi - lo
	if d <= 0.0:
		return Vector2.ZERO
	var l := (hi + lo) * 0.5
	return Vector2(lin.h * 360.0, d / (1.0 - absf(2.0 * l - 1.0)))


## Whether `c` reads as one of the teams of either set, figures or HUD.
func _reads_as_team(c: Color) -> bool:
	var hs := _hue_sat(c)
	if hs.y < MIN_SATURATION:
		return false
	for team in table.colours:
		var d := fmod(absf(hs.x - _hue_sat(team).x), 360.0)
		if minf(d, 360.0 - d) <= HUE_MARGIN:
			return true
	return false


## MapStyle's colours by the names data/accessibility.md's exceptions use: each kind, "container N" (1-based),
## "default" and "ground".
func _style_colours() -> Dictionary[String, Color]:
	var style := PlayTuning.load_default().map_style
	var out: Dictionary[String, Color] = {}
	for kind: StringName in style.colours:
		out[String(kind)] = style.colours[kind]
	for i in style.container_colours.size():
		out["container %d" % (i + 1)] = style.container_colours[i]
	out["default"] = style.default_colour
	out["ground"] = style.ground_colour
	return out


## Every paint in data/maps and the test fixtures: blocks', look-only blocks' and painted markings' (glowing signs and
## windows are light, not paint, and may be any colour), each as "file: what #rrggbb".
func _map_paints() -> Dictionary[String, Color]:
	var out: Dictionary[String, Color] = {}
	for dir: String in [MAPS_DIR, FIXTURE_DIR]:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".json"):
				_add_map_paints(out, file, JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(file))))
	return out


static func _add_map_paints(out: Dictionary[String, Color], file: String, map: Dictionary) -> void:
	for list: String in ["blocks", "decor"]:
		for block: Dictionary in map.get(list, []):
			if block.has("paint"):
				_add_paint(out, file, "%s %s" % [list, block.get("kind", "")], block["paint"])
	for sign: Dictionary in map.get("signs", []):
		if sign.get("kind", "") == "paint":
			_add_paint(out, file, "marking", sign["colour"])


static func _add_paint(out: Dictionary[String, Color], file: String, what: String, paint: Variant) -> void:
	var hex := int(paint)
	var c := Color8((hex >> 16) & 255, (hex >> 8) & 255, hex & 255)
	out["%s: %s #%s" % [file, what, c.to_html(false)]] = c


func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= HEX_SLACK and absf(a.g - b.g) <= HEX_SLACK and absf(a.b - b.b) <= HEX_SLACK


func test_the_simulation_reproduces_standards_published_numbers() -> void:
	var blue := Color("3d8bff")
	var orange := Color("ff8a2a")
	var visions: Array[String] = ["protan", "deutan", "tritan"]
	for i in visions.size():
		assert_almost_eq(_delta_e(blue, orange, visions[i]), PUBLISHED_STANDARD[i], GUARD_SLACK, visions[i])
	# The game's own Standard, a hex step or two off the browser's, stays as close.
	var std := table.pair(TeamColours.Set.STANDARD, TeamColours.Part.FIGURES)
	for i in visions.size():
		assert_almost_eq(_delta_e(std[0], std[1], visions[i]), PUBLISHED_STANDARD[i], GUARD_SLACK, "game's " + visions[i])


func test_every_set_keeps_its_teams_far_apart_for_every_vision() -> void:
	for s in AccessibilityTable.SET_NAMES.size():
		for p in AccessibilityTable.PART_NAMES.size():
			var pair := table.pair(s, p)
			for vision: String in VISIONS:
				var where := "%s %s, %s" % [AccessibilityTable.SET_NAMES[s], AccessibilityTable.PART_NAMES[p], vision]
				assert_gt(_delta_e(pair[0], pair[1], vision), MIN_DELTA_E, where)


func test_high_contrast_is_apart_in_lightness_for_every_vision() -> void:
	var figures := table.pair(TeamColours.Set.HIGH_CONTRAST, TeamColours.Part.FIGURES)
	var hud := table.pair(TeamColours.Set.HIGH_CONTRAST, TeamColours.Part.HUD)
	for vision: String in VISIONS:
		assert_gt(_gap(figures[0], figures[1], vision), MIN_FIGURES_GAP, "figures, " + vision)
		assert_gt(_gap(hud[0], hud[1], vision), MIN_HUD_GAP, "hud, " + vision)


func test_high_contrasts_least_lightness_gap_is_over_three_times_standards() -> void:
	# Worst case against worst case: High contrast's lowest gap across the four visions against Standard's lowest.
	for p in AccessibilityTable.PART_NAMES.size():
		var hc := _least_gap(table.pair(TeamColours.Set.HIGH_CONTRAST, p))
		var std := _least_gap(table.pair(TeamColours.Set.STANDARD, p))
		assert_gt(hc, LIGHTNESS_TIMES * std, "%s: %.1f against %.1f" % [AccessibilityTable.PART_NAMES[p], hc, std])


func test_the_rule_catches_near_team_colours_and_passes_greys_and_far_hues() -> void:
	for near: String in ["3d6ea8", "f07c2a", "8c5b3e", "3b87f5", "b8460c"]:
		assert_true(_reads_as_team(Color(near)), near)
	for far: String in ["7a7a7a", "4f8a3c", "d9d3c8"]:
		assert_false(_reads_as_team(Color(far)), far)


func test_no_prop_reads_as_a_team_but_the_listed_exceptions() -> void:
	var style := _style_colours()
	assert_false(style.is_empty())
	for prop in style:
		assert_true(not _reads_as_team(style[prop]) or table.exceptions.has(prop),
				"%s #%s reads as a team colour and isn't a listed exception" % [prop, style[prop].to_html(false)])


func test_every_exception_is_a_prop_with_that_colour_that_still_needs_it() -> void:
	if table.exceptions.is_empty():
		pass_test("none listed (the owner had the plywood and mustard recoloured, 2026-10-23)")
		return
	var style := _style_colours()
	for prop in table.exceptions:
		assert_true(style.has(prop), "%s is no longer a MapStyle prop: delete its row" % prop)
		if not style.has(prop):
			continue
		assert_true(_same(style[prop], table.exceptions[prop]), "%s is #%s now, the list says #%s" % [prop,
				style[prop].to_html(false), table.exceptions[prop].to_html(false)])
		assert_true(_reads_as_team(style[prop]), "%s no longer reads as a team colour: delete its row" % prop)


func test_no_map_paint_reads_as_a_team() -> void:
	var paints := _map_paints()
	assert_gt(paints.size(), 0, "the maps' paints read")
	for what in paints:
		assert_false(_reads_as_team(paints[what]), what)
