extends GutTest
## ST1 · The Street, QA's half: the edges of a block's own colour (MapData.Block.colour), the glass kind drawn clear but
## still a collider (MapLevel's Glass mesh), the per-block colours FieldChecks.drawn_colours counts, and the two
## measure rules the Street needed (FieldStandard's flag_head_start exception, FieldMeasure.middle reaching the spawn).

const STREET := "street"
const CRATE := '{"kind": "crate", "center": {"x": 0, "y": 0.5, "z": 0}, "size": {"x": 1, "y": 1, "z": 1}%s}'
const GLASS := '{"kind": "glass", "center": {"x": 3, "y": 1, "z": 0}, "size": {"x": 0.06, "y": 2, "z": 3}%s}'
const FLOOR := '{"kind": "floor", "center": {"x": 0, "y": -0.5, "z": 0}, "size": {"x": 12, "y": 1, "z": 12}}'

var play: PlayTuning = null
var tuning: SimTuning = null
var street: MapData = null


func before_all() -> void:
	play = PlayTuning.load_default()
	tuning = SimTuning.load_default()
	street = MapData.load_map(STREET, play.map_style, 5)


func after_all() -> void:
	street = null


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


func _street_measure(world: WorldQuery = null) -> FieldMeasure:
	var nav := NavGrid.build(street, tuning.nav, tuning.body)
	if world == null:
		var box := BoxWorld.new(tuning.body)
		for b in street.blocks:
			if b.rise == MapData.Rise.NONE:
				box.add_box(b.center, b.size, b.surface)
		world = box
	return FieldMeasure.new(street, nav, world, tuning.body)


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


func test_the_street_has_exactly_one_glass_mesh_with_a_collider_per_pane() -> void:
	var level := _level(street)
	var glass := 0
	for n in level.get_children():
		if n.name == &"Glass":
			glass += 1
	assert_eq(glass, 1, "one Glass mesh")
	var panes := 0
	for b in street.blocks:
		if play.map_style.is_clear(b.kind):
			panes += 1
	assert_eq(panes, 3, "the House's two panes and the shelter's")


func test_flag_head_start_is_only_the_streets_below_the_standard() -> void:
	assert_eq(FieldStandard.flag_head_start(STREET), 1.3, "the Street's written-down head start")
	assert_lt(FieldStandard.flag_head_start(STREET), FieldStandard.FLAG_HEAD_START, "below the standard")
	for id: String in ["depot", "woodland", "nowhere"]:
		assert_eq(FieldStandard.flag_head_start(id), FieldStandard.FLAG_HEAD_START, "%s keeps the standard" % id)
		assert_eq(FieldStandard.flag_head_start_reason(id), "", "%s gives no reason" % id)
	assert_ne(FieldStandard.flag_head_start_reason(STREET), "", "the Street gives its reason")


func test_the_streets_flag_passes_on_its_exception_and_fails_the_standard_without_it() -> void:
	var measure := _street_measure()
	var r := FieldChecks.flag(measure)
	assert_eq(r.status, FieldChecks.Status.PASS, r.text)
	assert_string_contains(r.text, "at least 1.3", "the figure it holds the field to is the exception's")
	# the same field under another id has no exception and must meet the standard head start
	street.id = "street_without_exception"
	var plain := FieldChecks.flag(measure)
	street.id = STREET
	assert_eq(plain.status, FieldChecks.Status.FAIL, plain.text)
	assert_string_contains(plain.text, "need a head start")
	assert_string_contains(plain.text, "at least 1.6")


func test_the_middle_of_the_street_is_ground_the_attackers_reach_on_foot() -> void:
	var nav := NavGrid.build(street, tuning.nav, tuning.body)
	var measure := FieldMeasure.new(street, nav, BoxWorld.new(tuning.body), tuning.body)
	var middle := measure.middle()
	var from := nav.node_at(street.ends[0].spawns[0].position)
	var to := nav.node_at(middle)
	assert_gte(from, 0, "end 0's first spawn is on the grid")
	assert_gte(to, 0, "the middle is on the grid")
	assert_true(nav.linked(from, to), "and end 0 walks there (the closed gardens are no middle)")
	for walks in measure.middle_walks():
		for w in walks:
			assert_lt(w, INF, "every spawn has a way to the middle")
