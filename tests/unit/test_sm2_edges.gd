extends GutTest
## SM2 edge cases QA hunts: the modelled railing along z, in a one-bar run, with no foot rail, with an unreadable
## model; the lifts on other orientations (plain boxes), their freeing; and the set_heads fit.


func _run(centre: Vector3, size: Vector3) -> Railings:
	var r := Railings.new(RailingConfig.new())
	r.add(centre, size)
	return r


func _arrays(mesh: Mesh) -> Array:
	return mesh.surface_get_arrays(0)


func test_a_run_along_z_is_drawn_filling_its_box_with_outward_faces() -> void:
	var r := _run(Vector3(2.0, 0.55, 1.5), Vector3(0.12, 1.1, 3.0))
	assert_eq(r.along_x[0], 0, "it runs along z")
	var mesh := RailingMesh.build(r, RailingLook.new())
	assert_not_null(mesh)
	if mesh == null:
		return
	assert_almost_eq(mesh.get_aabb().position, r.mins[0], Vector3.ONE * 0.001)
	assert_almost_eq(mesh.get_aabb().end, r.maxs[0], Vector3.ONE * 0.001)
	var a := _arrays(mesh)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var flipped := 0
	for t in range(0, idx.size(), 3):
		var face := (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]])
		if face.length() < 1e-9:
			continue
		if face.normalized().dot(n[idx[t]]) > 0.01:  # Godot fronts are clockwise
			flipped += 1
	assert_eq(flipped, 0, "winding agrees with the normals (a turn, not a mirror)")


func test_a_one_bar_run_and_a_run_without_a_foot_rail_still_draw_inside_their_box() -> void:
	for size: Vector3 in [Vector3(0.03, 1.1, 0.12), Vector3(3.0, 0.2, 0.12), Vector3(0.12, 0.06, 0.5)]:
		var r := _run(Vector3.ZERO + Vector3(0.0, size.y * 0.5, 0.0), size)
		var mesh := RailingMesh.build(r, RailingLook.new())
		assert_not_null(mesh, "built for %s" % size)
		if mesh == null:
			continue
		var box := AABB(r.mins[0], r.maxs[0] - r.mins[0]).grow(0.002)
		assert_true(box.encloses(mesh.get_aabb()), "inside the box for %s" % size)
		for nrm in _arrays(mesh)[Mesh.ARRAY_NORMAL] as PackedVector3Array:
			assert_almost_eq(nrm.length(), 1.0, 0.01)
			if not nrm.is_finite():
				fail_test("non-finite normal for %s" % size)
				break


func test_a_look_with_an_unreadable_model_draws_nothing_modelled() -> void:
	for field: StringName in [&"top_model", &"foot_model", &"post_model"]:
		var look := RailingLook.new()
		look.set(field, "res://assets/models/props/nope.glb")
		assert_null(RailingMesh.build(_run(Vector3(0.0, 0.55, 0.0), Vector3(3.0, 1.1, 0.12)), look), str(field))


func test_an_empty_railings_draws_nothing() -> void:
	assert_null(RailingMesh.build(Railings.new(RailingConfig.new()), RailingLook.new()))


func test_set_heads_grow_only_the_named_model() -> void:
	var cfg := PropDressConfig.new()
	assert_gt(cfg.set_heads.get(&"platform_stair", 0.0), 0.5)
	assert_false(cfg.set_heads.has(&"watch_tower"), "other SET models are not grown")
	var bare := PropLayout.fit(AABB(Vector3.ZERO, Vector3.ONE), Vector3.ZERO, Vector3(2, 1, 2), 0.0)
	var grown := PropLayout.fit(AABB(Vector3.ZERO, Vector3.ONE), Vector3.ZERO, Vector3(2, 1.9, 2), 0.0)
	assert_gt(grown.basis.get_scale().y, bare.basis.get_scale().y)


func test_lifts_facing_the_other_ways_keep_plain_boxes_and_free_cleanly() -> void:
	var tuning := SimTuning.new()
	var play := PlayTuning.new()
	for out: Vector2 in [Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1)]:
		var map := MapData.load_map("subway", MapStyle.new(), 6)
		var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		for spec in map.lifts:
			spec.out = out
		var view := LiftView.build(map, MapStyle.new(), tuning.lifts, play.lifts)
		add_child(view)
		for i in map.lifts.size():
			var body := view.get_node(NodePath("Car%d/Body" % i)) as MeshInstance3D
			assert_not_null(body.mesh)
			assert_not_null(view.materials()[3], "model material exists")
		view.free()
		assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before, "no node left for out %s" % out)


func test_a_lift_with_unreadable_models_still_builds_with_boxes() -> void:
	var cfg: LiftViewConfig = LiftViewConfig.new()
	cfg.car_model = ""
	cfg.landing_model = "res://nope.glb"
	cfg.leaf_model = ""
	cfg.button_model = "res://nope.glb"
	var map := MapData.load_map("subway", MapStyle.new(), 6)
	var view := LiftView.build(map, MapStyle.new(), SimTuning.new().lifts, cfg)
	add_child(view)
	assert_null(view.get_node_or_null(^"Landings"))
	assert_gt((view.get_node(^"Buttons") as MultiMeshInstance3D).multimesh.instance_count, 0)
	assert_gt((view.get_node(^"Leaves") as MultiMeshInstance3D).multimesh.instance_count, 0)
	view.free()


func _leaf_halves_meet(cfg: LiftViewConfig) -> void:
	# The headless dummy renderer keeps no multimesh transforms, so the leaf maths is asked directly.
	for out: Vector2 in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		var map := MapData.load_map("subway", MapStyle.new(), 6)
		for spec in map.lifts:
			spec.out = out
		var view := LiftView.build(map, MapStyle.new(), SimTuning.new().lifts, cfg)
		add_child(view)
		for spec in map.lifts:
			var w := spec.door_to - spec.door_from
			for open: float in [0.0, 1.0]:
				for off: float in [spec.door_depth * 0.5, -0.1]:
					var a: Transform3D = view._leaf(spec, -1.0, open, w, off, 0.0, 0.1)
					var b: Transform3D = view._leaf(spec, 1.0, open, w, off, 0.0, 0.1)
					var ab := (b.origin - a.origin).normalized()
					assert_gt(a.basis.x.normalized().dot(ab), 0.9, "near leaf +x faces far leaf, out %s" % out)
					assert_gt(b.basis.x.normalized().dot(-ab), 0.9, "far leaf +x faces near leaf, out %s" % out)
		view.free()


func test_each_leaf_pair_turns_its_plus_x_edges_toward_each_other_for_every_facing() -> void:
	_leaf_halves_meet(LiftViewConfig.new())


func test_box_leaves_without_a_model_also_meet_in_the_middle() -> void:
	var cfg := LiftViewConfig.new()
	cfg.leaf_model = ""
	_leaf_halves_meet(cfg)
