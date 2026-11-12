extends GutTest
## SM4: a dressed block may name the way its model faces (`facing`: +x, -x, +z or -z). FIT then points the model's
## front (its +z) that way, its width across the front and its depth along it, whatever the box's long side or where
## the field's middle lies; a block naming none keeps FIT's own turn toward the middle; a facing outside the four is
## warned about and leaves FIT's turn, the map still loading.


func _block(center: Vector3, size: Vector3, facing: StringName) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = &"shed"
	b.center = center
	b.size = size
	b.facing = facing
	return b


## A model 2 m wide (x), 2.6 m high and 1 m deep (z), its foot at y = 0.
func _model() -> AABB:
	return AABB(Vector3(-1.0, 0.0, -0.5), Vector3(2.0, 2.6, 1.0))


func _front(t: Transform3D) -> Vector3:
	var z := t.basis.z.normalized()
	return Vector3(roundf(z.x), 0.0, roundf(z.z))


func _world_box(t: Transform3D, m: AABB) -> AABB:
	return t * m


func test_a_named_facing_points_the_front_that_way_and_fills_the_box() -> void:
	var middle := Vector3(0.0, 0.0, -20.0)  # the field's middle behind every box, so FIT alone would turn them all -z
	var cases: Array = [
		[&"+z", Vector3(4.0, 1.3, 6.0), Vector3(2.0, 2.6, 1.0), Vector3(0, 0, 1)],
		[&"-z", Vector3(4.0, 1.3, 6.0), Vector3(2.0, 2.6, 1.0), Vector3(0, 0, -1)],
		[&"+x", Vector3(-51.75, 0.6, 11.35), Vector3(0.5, 1.2, 2.3), Vector3(1, 0, 0)],
		[&"-x", Vector3(3.0, 0.6, 0.0), Vector3(0.5, 1.2, 2.3), Vector3(-1, 0, 0)],
	]
	for c: Array in cases:
		var b := _block(c[1], c[2], c[0])
		var foot := b.center - Vector3(0.0, b.size.y * 0.5, 0.0)
		var t := PropLayout._fit_facing(_model(), b, foot, middle)
		assert_eq(_front(t), c[3] as Vector3, "facing %s points the model's front %s" % [c[0], c[3]])
		var box := _world_box(t, _model())
		assert_almost_eq(box.size, b.size, Vector3.ONE * 1e-4, "facing %s fills its box" % c[0])
		assert_almost_eq(box.get_center(), b.center, Vector3.ONE * 1e-4, "facing %s stands in its box" % c[0])


func test_no_facing_keeps_the_turn_toward_the_field_s_middle() -> void:
	var b := _block(Vector3(5.0, 1.3, 6.6), Vector3(2.6, 2.6, 1.0), &"")
	var foot := b.center - Vector3(0.0, b.size.y * 0.5, 0.0)
	var t := PropLayout._fit_facing(_model(), b, foot, Vector3(5.0, 0.0, 0.0))
	assert_eq(_front(t), Vector3(0, 0, -1), "unnamed, the front turns to the middle")


func _depot_with(extra: Dictionary) -> MapData:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MapData.DIR + "depot.json"))
	var blocks: Array = d["blocks"]
	blocks.append(extra)
	return MapData.parse(JSON.stringify(d), MapStyle.new(), 6)


func test_a_map_reads_a_block_s_facing_and_refuses_one_outside_the_four() -> void:
	var shed := {"kind": "shed", "center": {"x": 0, "y": 1.3, "z": 6}, "size": {"x": 2, "y": 2.6, "z": 2.2}}
	var faced := shed.duplicate()
	faced["facing"] = "-x"
	var m := _depot_with(faced)
	assert_eq(m.problems.size(), 0, "a named facing is no problem")
	assert_eq(m.blocks[m.blocks.size() - 1].facing, &"-x", "the block keeps its facing")
	var wrong := shed.duplicate()
	wrong["facing"] = "up"
	var warned := _depot_with(faced).warnings.size()
	m = _depot_with(wrong)
	assert_eq(m.problems.size(), 0, "a facing outside the four is no problem: the map loads")
	assert_eq(m.warnings.size(), warned + 1, "but it is warned about")
	assert_eq(m.blocks[m.blocks.size() - 1].facing, &"", "and leaves FIT's own turn")
	m = _depot_with(shed)
	assert_eq(m.blocks[m.blocks.size() - 1].facing, &"", "no facing named: empty")


func test_a_facing_turns_a_model_long_in_z_and_its_depth_runs_along_the_front() -> void:
	var long_z := AABB(Vector3(-0.5, 0.0, -1.5), Vector3(1.0, 2.0, 3.0))
	var middle := Vector3(0.0, 0.0, -20.0)
	var cases: Array = [[&"+x", Vector3(3.0, 2.0, 1.0)], [&"-x", Vector3(3.0, 2.0, 1.0)],
			[&"+z", Vector3(1.0, 2.0, 3.0)], [&"-z", Vector3(1.0, 2.0, 3.0)]]
	for c: Array in cases:
		var b := _block(Vector3(8.0, 1.0, 4.0), c[1], c[0])
		var foot := b.center - Vector3(0.0, b.size.y * 0.5, 0.0)
		var t := PropLayout._fit_facing(long_z, b, foot, middle)
		var box := t * long_z
		assert_almost_eq(box.size, b.size, Vector3.ONE * 1e-4, "facing %s: a model long in z fills its box" % c[0])
		assert_almost_eq(box.get_center(), b.center, Vector3.ONE * 1e-4, "facing %s: and stands in it" % c[0])


func test_a_facing_does_not_change_the_height_or_the_foot() -> void:
	for f: StringName in [&"+x", &"-x", &"+z", &"-z"]:
		var b := _block(Vector3(0.0, 1.3, 0.0), Vector3(0.5, 2.6, 2.3), f)
		var foot := Vector3(0.0, 0.0, 0.0)
		var box := PropLayout._fit_facing(_model(), b, foot, Vector3.ONE) * _model()
		assert_almost_eq(box.position.y, 0.0, 1e-4, "%s stands on its foot" % f)
		assert_almost_eq(box.end.y, 2.6, 1e-4, "%s keeps the box's height" % f)


func test_a_numeric_facing_is_warned_about_and_the_map_still_loads() -> void:
	var shed := {"kind": "shed", "center": {"x": 0, "y": 1.3, "z": 6}, "size": {"x": 2, "y": 2.6, "z": 2.2},
			"facing": 3}
	var m := _depot_with(shed)
	assert_eq(m.problems.size(), 0, "no problem")
	assert_eq(m.blocks[m.blocks.size() - 1].facing, &"", "a number names no facing")
