extends GutTest
## QA for WR3 (Woodland's CC0 dress), beyond test_props.gd: a block's `dress` is read and an unknown one is harmless, a
## grid stays inside a box long in x or in z, the layout is seeded, a sliver of a thicket has a finite core, and a match
## on Woodland builds its props with no site and frees them with the match.

var play: PlayTuning = PlayTuning.load_default()


func _map_of(blocks: Array) -> MapData:
	var spawn := {"x": 0.0, "z": 0.0}
	var d := {"blocks": blocks}
	return MapData.parse(JSON.stringify(d), play.map_style, 1)


func _blk(kind: String, dress: String, c: Vector3, s: Vector3) -> Dictionary:
	var d := {"kind": kind, "center": {"x": c.x, "y": c.y, "z": c.z}, "size": {"x": s.x, "y": s.y, "z": s.z}}
	if dress != "":
		d["dress"] = dress
	return d


func _boxes() -> Dictionary[StringName, AABB]:
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in play.site_look.props.models:
		boxes[model] = PropDressConfig.load_mesh(play.site_look.props.models[model]).get_aabb()
	return boxes


func test_a_block_s_dress_is_read_and_an_absent_one_is_empty() -> void:
	var m := _map_of([_blk("crate", "crate", Vector3(0, 0.5, 0), Vector3(2, 1, 1)),
			_blk("crate", "", Vector3(5, 0.5, 0), Vector3(2, 1, 1))])
	assert_eq(m.blocks[0].dress, &"crate")
	assert_eq(m.blocks[1].dress, &"")


func test_a_dress_naming_no_model_keeps_the_box_and_lays_nothing() -> void:
	var m := _map_of([_blk("crate", "zeppelin", Vector3(0, 0.5, 0), Vector3(2, 1, 1))])
	var cfg := play.site_look.props
	assert_false(cfg.dresses(m.blocks[0]), "an unknown prop is no dress")
	assert_eq(cfg.core_of(m.blocks[0]), Vector2.ZERO)
	assert_true(PropLayout.layout(m, cfg, _boxes()).is_empty(), "nothing laid")
	var plain := MapLevel._greybox_mesh(m, play.map_style)
	var dressed := MapLevel._greybox_mesh(m, play.map_style, null, cfg)
	var count := func(mesh: ArrayMesh) -> int: return (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	assert_eq(count.call(dressed), count.call(plain), "its box is still drawn")
	assert_null(PropDress.build(m, cfg), "no dress, no node")


func test_a_grid_stays_inside_a_box_long_in_x_or_in_z_and_counts_the_same() -> void:
	for model: String in ["logstack", "crate", "tyre", "pine"]:
		var counts: Array[int] = []
		for long_x: bool in [true, false]:
			var s := Vector3(7.3, 2.0, 2.1) if long_x else Vector3(2.1, 2.0, 7.3)
			var c := Vector3(10, 1.0, -4)
			var m := _map_of([_blk("log", model, c, s)])
			var cfg := play.site_look.props
			var placed := PropLayout.layout(m, cfg, _boxes())
			assert_true(placed.has(StringName(model)), model)
			var box := AABB(c - s * 0.5, s).grow(0.02)
			var bad := 0
			var mesh_box := _boxes()[StringName(model)]
			for t in placed[StringName(model)].transforms:
				for i in 8:
					if not box.has_point(t * mesh_box.get_endpoint(i)):
						bad += 1
			assert_eq(bad, 0, "%s long_x=%s: every corner inside the box" % [model, long_x])
			counts.append(placed[StringName(model)].transforms.size())
		assert_eq(counts[0], counts[1], "%s: the same count either way round" % model)


func test_the_layout_is_seeded_not_random() -> void:
	var m := MapData.load_map("woodland", play.map_style, 5)
	var a := PropLayout.layout(m, play.site_look.props, _boxes())
	var b := PropLayout.layout(m, play.site_look.props, _boxes())
	for model: StringName in a:
		assert_eq(a[model].transforms, b[model].transforms, "%s laid the same twice" % model)


func test_a_sliver_of_a_thicket_has_a_finite_core() -> void:
	for s: Vector3 in [Vector3(1.0, 4.0, 30.0), Vector3(0.2, 3.0, 0.2), Vector3(1.4, 3.0, 1.4)]:
		var m := _map_of([_blk("thicket", "pine", Vector3(0, 2, 0), s)])
		var mesh := MapLevel._greybox_mesh(m, play.map_style, null, play.site_look.props)
		for v in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			assert_true(v.is_finite(), "%s: finite vertex" % s)
			if s.x >= 1.0 and absf(v.x) < 50.0:
				assert_true(absf(v.x) <= s.x * 0.5 + 1e-3, "%s: core within its block" % s)


func test_a_match_on_woodland_builds_the_props_without_a_site_and_frees_them() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.map_id = "woodland"
	session.match_seed = 5
	session.autopilot = true
	add_child(session)
	await wait_physics_frames(2)
	assert_null(session._site, "woodland has no site dress")
	assert_not_null(session._props, "but it has its props")
	if session._props != null:
		assert_eq(session._props.get_parent(), session)
	session.free()
	await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before, "no orphans")


func test_a_greybox_map_with_no_dress_builds_no_props() -> void:
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.map_id = "range"
	session.match_seed = 5
	session.autopilot = true
	add_child_autofree(session)
	await wait_physics_frames(2)
	assert_null(session._props)
