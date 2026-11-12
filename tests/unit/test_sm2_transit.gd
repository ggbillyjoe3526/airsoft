extends GutTest
## SM2: a railing drawn in its modelled pieces (RailingMesh) draws exactly the steel a BB meets: every piece inside
## its run's box, the box filled, each bar's steel spanning just its bar, and a 5 m run within its 800 triangles; and
## the lifts' and railing's models read as no team.

const BUDGET := 800


func _railings() -> Railings:
	var r := Railings.new(RailingConfig.new())
	r.add(Vector3(-40.5, 19.45, -4.94), Vector3(5.0, 1.1, 0.12))
	r.add(Vector3(-43.06, 19.45, -6.74), Vector3(0.12, 1.1, 3.72))
	return r


func test_each_run_is_drawn_inside_and_filling_its_box() -> void:
	var r := _railings()
	for run in r.size():
		var one := Railings.new(r.config)
		one.add((r.mins[run] + r.maxs[run]) * 0.5, r.maxs[run] - r.mins[run])
		var mesh := RailingMesh.build(one, RailingLook.new())
		assert_not_null(mesh, "the pieces' models are read")
		if mesh == null:
			continue
		var drawn := mesh.get_aabb()
		assert_almost_eq(drawn.position, r.mins[run], Vector3.ONE * 0.001, "run %d from its box's corner" % run)
		assert_almost_eq(drawn.end, r.maxs[run], Vector3.ONE * 0.001, "run %d to its far corner" % run)


func test_a_five_metre_run_keeps_its_triangle_budget() -> void:
	var r := Railings.new(RailingConfig.new())
	r.add(Vector3.ZERO, Vector3(5.0, 1.1, 0.12))
	var mesh := RailingMesh.build(r, RailingLook.new())
	assert_not_null(mesh)
	if mesh != null:
		var tris := mesh.surface_get_array_index_len(0) / 3
		assert_between(tris, 1, BUDGET, "a 5 m run's triangles")


func test_no_steel_is_drawn_where_a_bb_flies_through() -> void:
	# Between the rails, every vertex stands on a bar's span along the run (posts are as wide as their bar).
	var r := _railings()
	var mesh := RailingMesh.build(r, RailingLook.new())
	assert_not_null(mesh)
	if mesh == null:
		return
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var cfg := r.config
	var stray := 0
	for v in verts:
		var run := -1
		for i in r.size():
			if AABB(r.mins[i], r.maxs[i] - r.mins[i]).grow(0.001).has_point(v):
				run = i
		if run < 0:
			stray += 1
			continue
		var lo := r.mins[run]
		var hi := r.maxs[run]
		var foot_top := lo.y + cfg.foot_gap + cfg.rail_height
		if v.y <= foot_top + 0.001 or v.y >= hi.y - cfg.rail_height - 0.001 or v.y <= lo.y + 0.009:
			continue  # on a rail or a floor plate
		var a := 0 if r.along_x[run] == 1 else 2
		var s := v[a] - lo[a]
		var k := roundi(s / r.pitches[run])
		var off := s - k * r.pitches[run]
		if off < -0.001 or off > cfg.bar_width + 0.001:
			stray += 1
	assert_eq(stray, 0, "every vertex on a bar, a rail or a plate")


func test_a_look_without_models_draws_nothing_modelled() -> void:
	var look := RailingLook.new()
	look.bar_model = ""
	assert_null(RailingMesh.build(_railings(), look), "MapLevel then draws the plain boxes")


func test_the_lifts_and_railing_models_read_as_no_team() -> void:
	# The station's props are checked in test_props; these are drawn by LiftView and RailingMesh.
	var teams: Array[Color] = AccessibilityTable.read_file().colours
	teams.append_array(PlayTuning.new().teams.colours)
	var cfg := LiftViewConfig.new()
	var look := RailingLook.new()
	var near: Array[String] = []
	for path: String in [cfg.car_model, cfg.landing_model, cfg.leaf_model, cfg.button_model, look.bar_model,
			look.top_model, look.foot_model, look.post_model]:
		var mesh := PropDressConfig.load_mesh(path)
		assert_not_null(mesh, "%s loads" % path)
		if mesh == null:
			continue
		for linear in mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray:
			var c := linear.linear_to_srgb()
			if FieldChecks.reads_as_team(c, teams):
				near.append("%s %s" % [path.get_file(), c.to_html(false)])
				break
	assert_eq(near, [] as Array[String], "no colour within 20 degrees of a team's hue unless dull")
