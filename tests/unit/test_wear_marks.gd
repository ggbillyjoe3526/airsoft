extends GutTest
## WM1: the floors' worn marks (WearMark, WearMarks, WearMarkArt, Graphics › Wear marks): oil stains and tyre tracks
## read from a map's `dressing.wearMarks`, each a decal on open floor, shown from Medium up and never on
## Compatibility. Headless: what is built and set, never pixels.

var play: PlayTuning = PlayTuning.load_default()
var table: GraphicsTable = null


func before_each() -> void:
	table = GraphicsTable.shared()


func _marks(map: MapData) -> WearMarks:
	var marks := WearMarks.build(map, play.marks, play.look)
	if marks != null:
		add_child_autofree(marks)
	return marks


func test_a_mark_is_read_and_a_bad_one_left_out_with_a_warning() -> void:
	var warnings: Array[String] = []
	var marks := WearMark.read({"wearMarks": [
		{"kind": "tyres", "x": 1.0, "z": 2.0, "yaw": 90, "length": 6, "bend": 20, "mud": true},
		{"kind": "paint", "x": 0, "z": 0, "length": 1},
		{"kind": "oil", "x": 0, "z": 0, "length": 0},
		{"kind": "tyres", "x": 0, "z": 0, "length": WearMark.MOST_LENGTH + 1.0},
		{"kind": "tyres", "z": 0, "length": 2},
		{"kind": "boots", "x": 0, "z": 0, "length": 2},
	]}, warnings)
	assert_eq(marks.size(), 1)
	assert_eq(warnings.size(), 5, "each bad one warned of, boot prints too (no longer a kind, owner 2026-11-10)")
	var m := marks[0]
	assert_eq(m.kind, WearMark.TYRES)
	assert_eq(m.at, Vector2(1.0, 2.0))
	assert_true(is_nan(m.y), "no y: the ground's")
	assert_true(m.mud)
	assert_eq(WearMark.read({}, warnings).size(), 0, "a map naming none has none")
	assert_eq(WearMark.read(null, warnings).size(), 0)


func test_a_path_runs_its_length_and_turns_its_bend() -> void:
	var m := WearMark.new()
	m.kind = WearMark.TYRES
	m.at = Vector2(0.0, 0.0)
	m.yaw = 90.0
	m.length = 10.0
	var straight := m.path(5)
	assert_eq(straight.size(), 6)
	assert_almost_eq(straight[5].x, 10.0, 1e-3, "heading 90 runs towards +x")
	assert_almost_eq(straight[5].y, 0.0, 1e-3)
	m.yaw = 0.0
	assert_almost_eq(m.path(4)[4].y, -10.0, 1e-3, "heading 0 runs towards -z")
	m.bend = 90.0
	var bent := m.path(16)
	var last := bent[16] - bent[15]
	assert_almost_eq(rad_to_deg(atan2(last.x, -last.y)), 90.0 - 90.0 / 32.0, 0.5, "it ends turned its bend")
	var oil := WearMark.new()
	assert_eq(oil.path(8).size(), 1, "a stain is one point")


func test_depot_and_woodland_have_marks_and_lay_them_without_warnings() -> void:
	for id: String in ["depot", "woodland"]:
		var map := MapData.load_map(id, play.map_style, 6)
		assert_gt(map.marks.size(), 0, id)
		for w in map.warnings:
			assert_false(w.contains("wearMarks"), "%s: %s" % [id, w])
		var kinds := {}
		for m in map.marks:
			kinds[m.kind] = true
		assert_true(kinds.has(WearMark.TYRES) and kinds.has(WearMark.OIL), id)


func test_each_mark_lays_its_decals() -> void:
	var map := MapData.load_map("depot", play.map_style, 6)
	var marks := _marks(map)
	assert_not_null(marks)
	var want := 0
	for m in map.marks:
		match m.kind:
			WearMark.OIL:
				want += 1
			WearMark.TYRES:
				want += 2 * maxi(1, ceili(m.length / play.marks.track_piece))
	assert_eq(marks.decals().size(), want)
	assert_eq(marks.get_child_count(), want, "every decal a child, freed with it")
	for d in marks.decals():
		assert_true(d.distance_fade_enabled, "faded out with distance")
		assert_lt(d.size.y, 1.0, "never as tall as a figure's knees")
		assert_not_null(d.texture_albedo)


func test_the_marks_lie_on_open_floor() -> void:
	for id: String in ["depot", "woodland"]:
		var map := MapData.load_map(id, play.map_style, 6)
		var marks := _marks(map)
		for d in marks.decals():
			var p := d.global_position
			assert_true(map.footprint().has_point(Vector2(p.x, p.z)), "%s: %s on the field" % [id, p])
			for b in map.blocks:
				if b.kind == &"floor" or b.kind == &"thicket":
					continue
				var top := b.center.y + b.size.y * 0.5
				var inside := absf(p.x - b.center.x) < b.size.x * 0.5 and absf(p.z - b.center.z) < b.size.z * 0.5
				assert_false(inside and top > p.y + d.size.y * 0.5, "%s: a mark at %s under a %s" % [id, p, b.kind])


func test_woodland_marks_sit_on_its_ground() -> void:
	var map := MapData.load_map("woodland", play.map_style, 6)
	var marks := _marks(map)
	for d in marks.decals():
		var p := d.global_position
		assert_almost_eq(p.y, map.terrain.height_at(p.x, p.z), 1e-3)


func test_a_map_naming_none_builds_nothing() -> void:
	var map := MapData.load_map("range", play.map_style, 6)
	assert_eq(map.marks.size(), 0)
	assert_null(WearMarks.build(map, play.marks, play.look))


func test_the_row_shows_them_from_medium_up_and_never_on_compatibility() -> void:
	assert_false(table.preset(&"low").wear_marks)
	assert_true(table.preset(&"medium").wear_marks)
	assert_true(table.preset(&"high").wear_marks)
	assert_true(table.preset(&"ultra").wear_marks)
	assert_false(table.can_draw(GraphicsQuality.WEAR_MARKS, 1, "gl_compatibility"))
	assert_true(table.can_draw(GraphicsQuality.WEAR_MARKS, 1, "forward_plus"))
	var marks := _marks(MapData.load_map("depot", play.map_style, 6))
	GraphicsApply.apply_field(table.preset(&"low"), null, null, GraphicsApply.Server.new(), null, null, null, null,
			marks)
	assert_false(marks.visible)
	GraphicsApply.apply_field(table.preset(&"medium"), null, null, GraphicsApply.Server.new(), null, null, null, null,
			marks)
	assert_true(marks.visible)


func test_the_pictures_are_painted_once_and_the_tread_tiles() -> void:
	WearMarkArt.ensure(play.marks)
	var stain := WearMarkArt.stain()
	WearMarkArt.ensure(play.marks)
	assert_same(WearMarkArt.stain(), stain, "painted once")
	assert_not_null(WearMarkArt.stain_orm())
	var tread := WearMarkArt.tread(true, WearMarkArt.Piece.MIDDLE).get_image()
	var h := tread.get_height()
	var seam := 0.0
	var inside := 0.0
	for x in tread.get_width():
		seam += absf(tread.get_pixel(x, 0).a - tread.get_pixel(x, h - 1).a)
		inside += absf(tread.get_pixel(x, floori(h * 0.5)).a - tread.get_pixel(x, floori(h * 0.5) - 1).a)
	assert_lte(seam, inside * 1.5 + 0.5, "its top and bottom rows meet like any two rows, so pieces laid end to end join")


func _pair(length: float, bend: float) -> WearMarks:
	var map := MapData.new()
	var m := WearMark.new()
	m.kind = WearMark.TYRES
	m.length = length
	m.bend = bend
	m.y = 0.0
	map.marks = [m]
	return _marks(map)


func test_a_bending_pairs_pieces_meet_wheel_by_wheel() -> void:
	var decals := _pair(12.0, 90.0).decals()
	var pieces := decals.size() / 2
	for wheel in 2:
		for i in pieces - 1:
			var a := decals[wheel * pieces + i]
			var b := decals[wheel * pieces + i + 1]
			# a piece's far end (its local -z, half its length on) and the next one's near end
			var a_end := a.position + a.basis * Vector3(0.0, 0.0, -a.size.z * 0.5)
			var b_start := b.position + b.basis * Vector3(0.0, 0.0, b.size.z * 0.5)
			assert_almost_eq(a_end.distance_to(b_start), 0.0, 0.001, "wheel %d, piece %d meets the next" % [wheel, i])


func test_a_pair_fades_in_at_its_start_and_out_at_its_end() -> void:
	var decals := _pair(9.0, 0.0).decals()
	var pieces := decals.size() / 2
	assert_gt(pieces, 2)
	for wheel in 2:
		var first := decals[wheel * pieces]
		assert_same(first.texture_albedo, WearMarkArt.tread(false, WearMarkArt.Piece.FIRST))
		assert_same(decals[wheel * pieces + 1].texture_albedo, WearMarkArt.tread(false, WearMarkArt.Piece.MIDDLE))
		assert_same(decals[wheel * pieces + pieces - 1].texture_albedo, WearMarkArt.tread(false, WearMarkArt.Piece.LAST))
	var only := _pair(1.0, 0.0).decals()
	assert_eq(only.size(), 2)
	assert_same(only[0].texture_albedo, WearMarkArt.tread(false, WearMarkArt.Piece.ONLY))
	var first_img := WearMarkArt.tread(false, WearMarkArt.Piece.FIRST).get_image()
	var h := first_img.get_height()
	var mid := first_img.get_width() / 2
	# the picture's bottom row is where the wheel rolled from
	assert_lt(first_img.get_pixel(mid, h - 1).a, 0.05, "faded in from nothing at its start")
	assert_gt(first_img.get_pixel(mid, 0).a, 0.3, "full by its end")


func test_a_muddy_tread_has_lugs_at_a_real_tyres_pitch() -> void:
	WearMarkArt.ensure(play.marks)
	var img := WearMarkArt.tread(true, WearMarkArt.Piece.MIDDLE).get_image()
	var x := img.get_width() / 2
	var edges := 0
	var was := img.get_pixel(x, 0).a > 0.5
	for y in img.get_height():
		var on := img.get_pixel(x, y).a > 0.5
		if on != was:
			edges += 1
		was = on
	var lugs := edges / 2.0
	var pitch := play.marks.track_piece / lugs
	assert_between(pitch, 0.04, 0.1, "a lug every %.3f m along the middle of the tread" % pitch)

