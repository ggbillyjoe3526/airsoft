extends GutTest
## ST1 · QA's half of the map format The Street brought (the map itself removed 2026-11-09, owner): the edges of a
## block's own colour (MapData.Block.colour), the glass kind drawn clear but still a collider (MapLevel's Glass mesh),
## the per-block colours FieldChecks.drawn_colours counts, and no field left with a flag head start exception.

const CRATE := '{"kind": "crate", "center": {"x": 0, "y": 0.5, "z": 0}, "size": {"x": 1, "y": 1, "z": 1}%s}'
const GLASS := '{"kind": "glass", "center": {"x": 3, "y": 1, "z": 0}, "size": {"x": 0.06, "y": 2, "z": 3}%s}'
const FLOOR := '{"kind": "floor", "center": {"x": 0, "y": -0.5, "z": 0}, "size": {"x": 12, "y": 1, "z": 12}}'

var play: PlayTuning = null
var tuning: SimTuning = null


func before_all() -> void:
	play = PlayTuning.load_default()
	tuning = SimTuning.load_default()


func _parse(blocks: PackedStringArray) -> MapData:
	return MapData.parse('{"blocks": [%s]}' % ",".join(blocks), play.map_style, 1)


func _colour_problem(m: MapData) -> bool:
	for p in m.problems:
		if p.begins_with("block 0's colour"):
			return true
	return false


func _level(m: MapData) -> MapLevel:
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, tuning.body)
	return level


func test_a_colour_of_black_is_set_not_unset_and_the_ends_of_the_range_read() -> void:
	var black := _parse([CRATE % ', "colour": 0', FLOOR])
	assert_false(_colour_problem(black), "0 reads: %s" % [black.problems])
	assert_eq(black.blocks[0].colour, Color(0, 0, 0, 1), "black is a colour of its own (alpha 1), not unset")
	assert_eq(play.map_style.block_colour(black.blocks[0]), Color(0, 0, 0, 1), "and it wins over the kind's")
	var white := _parse([CRATE % ', "colour": 16777215', FLOOR])
	assert_eq(white.blocks[0].colour.to_html(false), "ffffff", "0xffffff reads")
	assert_false(_colour_problem(white), "and is no problem")


func test_a_colour_out_of_range_or_not_a_number_is_a_problem_and_leaves_the_kinds_colour() -> void:
	for bad: String in ["-1", "16777216", "\"#7658aa\"", "true", "[1]", "null"]:
		var m := _parse([CRATE % (', "colour": %s' % bad), FLOOR])
		assert_true(_colour_problem(m), "colour %s is a problem: %s" % [bad, m.problems])
		assert_eq(m.blocks[0].colour.a, 0.0, "colour %s leaves it unset" % bad)


func test_a_gravel_block_with_its_own_colour_is_drawn_in_it() -> void:
	# a surface's colour (gravel) is the second choice now: the block's own is the first
	var style := play.map_style
	var m := _parse([CRATE % ', "surface": "gravel", "colour": 7755946', FLOOR])
	assert_eq(style.block_colour(m.blocks[0]).to_html(false), "7658aa", "its own over its surface's")
	var plain := _parse([CRATE % ', "surface": "gravel"', FLOOR])
	assert_eq(style.block_colour(plain.blocks[0]), style.surface_colours[plain.blocks[0].surface],
			"and with none, the surface's as before")


func test_drawn_colours_names_each_blocks_own_colour_apart_from_its_kinds() -> void:
	var m := _parse([CRATE % ', "colour": 7755946', CRATE % '', FLOOR])
	var drawn := FieldChecks.drawn_colours(m, play.map_style)
	assert_true(drawn.has("crate #7658aa"), "the painted crate is counted in its own colour: %s" % [drawn.keys()])
	assert_true(drawn.has("crate"), "and the unpainted one in its kind's")
	assert_eq(drawn["crate #7658aa"].to_html(false), "7658aa", "the colour it is drawn in")


func test_glass_is_drawn_as_its_own_clear_mesh_out_of_the_greybox_and_still_stops_a_bb() -> void:
	var with_glass := _level(_parse([CRATE % '', GLASS % ', "colour": 4878188', FLOOR]))
	var without := _level(_parse([CRATE % '', FLOOR]))
	assert_null(without.get_node_or_null(^"Glass"), "a map with no glass has no Glass mesh")
	var pane := with_glass.get_node_or_null(^"Glass") as MeshInstance3D
	assert_not_null(pane, "a map with glass has one")
	if pane == null:
		return
	# the greybox is the same with the pane as without it: the pane is in the Glass mesh alone
	var a := (with_glass.get_node(^"Greybox") as MeshInstance3D).mesh.surface_get_arrays(0)
	var b := (without.get_node(^"Greybox") as MeshInstance3D).mesh.surface_get_arrays(0)
	assert_eq((a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), (b[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
			"the glass adds no face to the greybox")
	var colours: PackedColorArray = pane.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_gt(colours.size(), 0, "the pane has vertex colours")
	for c in colours:
		assert_almost_eq(c.a, play.map_style.clear_kinds[&"glass"], 0.01, "drawn at the glass opacity")
	var hit := RayHit.new()
	assert_true(with_glass.query().ray(Vector3(0.0, 1.0, 1.0), Vector3(6.0, 1.0, 1.0), hit),
			"a BB across the pane stops (it is still a collider)")
	assert_almost_eq(hit.position.x, 2.97, 0.05, "on the pane")


func test_no_field_keeps_a_flag_head_start_exception() -> void:
	for id: String in ["depot", "woodland", "nowhere"]:
		assert_eq(FieldStandard.flag_head_start(id), FieldStandard.FLAG_HEAD_START, "%s keeps the standard" % id)
		assert_eq(FieldStandard.flag_head_start_reason(id), "", "%s gives no reason" % id)


func test_nothing_of_the_street_is_left_in_the_game() -> void:
	assert_false(FileAccess.file_exists("res://data/maps/street.json"))
	assert_false(FileAccess.file_exists("res://assets/maps/street.jpg"))
	assert_false(FileAccess.file_exists("res://assets/maps/cards/street.jpg"))
	assert_null(MapCatalog.read_file().find("street"), "no catalogue row")
	for model: StringName in [&"car_crimson", &"van_cream", &"lorry_teal", &"bin_green", &"skip", &"lamp", &"settee",
			&"table", &"units", &"fridge"]:
		assert_false(play.site_look.props.models.has(model), "%s has no model entry" % model)
		assert_false(FileAccess.file_exists("res://assets/models/props/%s.glb" % model), "%s's file is gone" % model)
