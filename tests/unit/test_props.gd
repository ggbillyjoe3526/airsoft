extends GutTest
## DR2: Depot's CC0 props. Every prop stands inside a block of the kind it dresses, so what you see is what stops a BB
## and a body; the drums stand four on a pallet, the barrels two a block, the sofa faces the field and the tall racks
## are lined with shelving over a backing while the rack's shelf boards stay boards; a box drawn as props draws none
## of its own faces (or only its backing) and leaves the baked shadow caster; no prop colour reads as a team; the
## layout is seeded; a missing model leaves its kind a box; the props are in the prewarm; Woodland has none.

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()
var look: SiteLook = null


func before_each() -> void:
	look = play.site_look


func _map(id: String) -> MapData:
	var m := MapData.load_map(id, play.map_style, 1 if id == "range" else tuning.rounds.team_size)
	assert_true(m.ok(), "%s loads: %s" % [id, m.problems])
	return m


func _level(m: MapData, site: SiteLook) -> MapLevel:
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, tuning.body, play.baked_light, LightingConfig.for_map(play.lighting, null, m,
			LightingConfig.DAY), false, site)
	return level


func _box(b: MapData.Block, grow: float) -> AABB:
	return AABB(b.center - b.size * 0.5, b.size).grow(grow)


func _dress(m: MapData) -> PropDress:
	var dress := PropDress.build(m, look.props)
	if dress != null:
		add_child_autofree(dress)
	return dress


func _count(m: MapData, kind: StringName, tall_from: float = 0.0) -> int:
	var n := 0
	for b in m.blocks:
		if b.kind == kind and b.size.y >= tall_from:
			n += 1
	return n


func test_every_prop_stands_inside_a_block_it_dresses() -> void:
	var m := _map("depot")
	var dress := _dress(m)
	assert_not_null(dress, "Depot is dressed with props")
	var boxes: Array[AABB] = []
	for b in m.blocks:
		if look.props.dresses(b):
			boxes.append(_box(b, 1e-3))
	var outside: Array[String] = []
	var placed := dress.placed()
	for model: StringName in placed:
		var mesh := dress.views()[model].multimesh.mesh
		var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var middle := mesh.get_aabb().get_center()
		for i in placed[model].transforms.size():
			var t := placed[model].transforms[i]
			var home := -1
			for k in boxes.size():
				if boxes[k].has_point(t * middle):
					home = k
					break
			for v in verts:
				if home < 0 or not boxes[home].has_point(t * v):
					outside.append("%s %d" % [model, i])
					break
	assert_eq(outside, [] as Array[String], "no prop reaches past its block's box")


func test_drums_stand_four_on_a_pallet_barrels_two_a_block_one_sofa_and_shelving_on_tall_racks() -> void:
	var m := _map("depot")
	var views := _dress(m).views()
	assert_eq(views[&"drum"].multimesh.instance_count, 4 * _count(m, &"drum"), "four drums a cluster")
	assert_eq(views[&"pallet"].multimesh.instance_count, _count(m, &"drum"), "a pallet under each cluster")
	assert_eq(views[&"barrel"].multimesh.instance_count, 2 * _count(m, &"barrel"), "two barrels a block")
	assert_eq(views[&"sofa"].multimesh.instance_count, 1)
	assert_gt(views[&"shelf"].multimesh.instance_count, _count(m, &"rack", 2.0), "racking lined with shelving")
	for b in m.blocks:
		if b.kind == &"rack" and b.size.y < 2.0:
			assert_false(look.props.dresses(b), "a rack's shelf board stays a board")
			assert_false(SiteSurface.as_props(look, b))


func test_the_sofa_faces_the_field_s_middle() -> void:
	var m := _map("depot")
	var t := _dress(m).placed()[&"sofa"].transforms[0]
	var front := (t.basis * Vector3(0.0, 0.0, 1.0)).normalized()
	var sofa: MapData.Block = null
	for b in m.blocks:
		if b.kind == &"sofa":
			sofa = b
	var to := PropLayout.field_middle(m) - sofa.center
	assert_gt(front.dot(Vector3(to.x, 0.0, to.z).normalized()), 0.0, "its seat faces the field")
	assert_almost_eq(absf(front.y), 0.0, 1e-4, "upright")


func test_a_propped_box_draws_no_faces_and_leaves_the_baked_shadow_caster() -> void:
	var m := _map("depot")
	var level := _level(m, look)
	var hidden := 0
	var drawn := 0
	for b in m.blocks:
		if SiteSurface.hidden(look, b):
			hidden += 1
			var core := SiteSurface.core_of(look, b)
			assert_eq(core * (b.center + b.size * 0.5), b.center, "a drum's or barrel's box folds to its middle")
		drawn += GreyboxFaces.faces_of(b).size() if not SiteSurface.hidden(look, b) else 0
	assert_eq(hidden, _count(m, &"drum") + _count(m, &"barrel") + _count(m, &"sofa"))
	var caster := MapLevel._greybox_mesh(m, play.map_style, look)
	var full := MapLevel._greybox_mesh(m, play.map_style)
	assert_lt(caster.surface_get_array_len(0), full.surface_get_array_len(0), "the caster leaves them out")
	level.set_baked_light(true)
	assert_true(level.baked_light_drawn(), "the bake still fits: the tiles are all there, folded")


func test_tall_racks_draw_a_backing_half_a_row_inside_each_lined_face() -> void:
	var m := _map("depot")
	var checked := 0
	for b in m.blocks:
		if not look.props.backs(b):
			continue
		assert_eq(look.finish_of(b), &"backing")
		var rows := look.props.tile_depths(b)
		var core := SiteSurface.core_of(look, b)
		var lo := core * (b.center - b.size * 0.5)
		var hi := core * (b.center + b.size * 0.5)
		assert_almost_eq(hi.z - lo.z, b.size.z - rows.x, 1e-4, "in by half a row on the faces across z")
		assert_almost_eq(hi.x - lo.x, b.size.x - rows.y, 1e-4, "in by half a row on the faces across x")
		assert_almost_eq(lo.y, b.center.y - b.size.y * 0.5, 1e-4, "on the floor")
		assert_gt(rows.x + rows.y, 0.0, "some face is lined")
		checked += 1
	assert_eq(checked, _count(m, &"rack", 2.0))


func test_no_prop_colour_reads_as_a_team() -> void:
	var teams: Array[Color] = AccessibilityTable.read_file().colours
	teams.append_array(play.teams.colours)
	var near: Array[String] = []
	for model: StringName in look.props.models:
		var mesh := PropDress.load_mesh(look.props.models[model])
		assert_not_null(mesh, "%s loads" % model)
		var seen: Dictionary[Color, bool] = {}
		for linear in mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray:
			var c := linear.linear_to_srgb()
			if seen.has(c):
				continue
			seen[c] = true
			if FieldChecks.reads_as_team(c, teams):
				near.append("%s %s" % [model, c.to_html(false)])
	assert_eq(near, [] as Array[String], "no prop within 20 degrees of a team's hue unless dull")
	assert_eq(look.props.metallic, 0.0)


func test_the_layout_is_seeded() -> void:
	var m := _map("depot")
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in look.props.models:
		boxes[model] = PropDress.load_mesh(look.props.models[model]).get_aabb()
	var a := PropLayout.layout(m, look.props, boxes)
	var b := PropLayout.layout(m, look.props, boxes)
	for model: StringName in a:
		assert_eq(a[model].transforms, b[model].transforms, "%s the same both times" % model)
		assert_eq(a[model].shades, b[model].shades)


func test_a_missing_model_leaves_its_kind_a_box() -> void:
	var m := _map("depot")
	var cfg := PropDressConfig.new()
	cfg.models[&"drum"] = "res://assets/models/props/no_such_drum.glb"
	var drum: MapData.Block = null
	for b in m.blocks:
		if b.kind == &"drum":
			drum = b
	assert_false(cfg.dresses(drum), "no model, no props")
	var other := SiteLook.new()
	other.props = cfg
	assert_false(SiteSurface.as_props(other, drum))
	assert_eq(SiteSurface.core_of(other, drum), Transform3D.IDENTITY, "its box is drawn")
	var dress := PropDress.build(m, cfg)
	add_child_autofree(dress)
	assert_false(dress.views().has(&"drum"), "and no drums")
	assert_true(dress.views().has(&"barrel"), "the rest as before")


func test_the_props_are_in_the_site_dress_and_its_prewarm() -> void:
	var m := _map("depot")
	var level := _level(m, look)
	var site := SiteDress.build(m, look, level.site_material())
	add_child_autofree(site)
	assert_not_null(site.props())
	for mat in site.props().materials():
		assert_true(site.materials().has(mat), "warmed before play")
	for view: MultiMeshInstance3D in site.props().views().values():
		assert_eq(view.material_override, site.props().materials()[0], "one material for every prop")


func test_woodland_has_no_props() -> void:
	var m := _map("woodland")
	assert_null(SiteDress.build(m, look, ShaderMaterial.new()), "no site dress, so no props")


func test_drums_barrels_and_the_sofa_cast_shadows_and_shelving_leaves_it_to_its_rack() -> void:
	var views := _dress(_map("depot")).views()
	for model: StringName in [&"drum", &"barrel", &"pallet", &"sofa"]:
		assert_ne(views[model].cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts" % model)
	assert_eq(views[&"shelf"].cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the rack's box casts it")


func test_shelving_lines_only_faces_nobody_is_against() -> void:
	var m := _map("depot")
	var hidden := 0
	for b in m.blocks:
		if look.props.backs(b) and b.center.z > 30.0 and b.size.x > 100.0:
			assert_true(PropLayout.face_hidden(m, b, Vector3(0.0, 0.0, 1.0)), "the south rack's back is against the wall")
			assert_false(PropLayout.face_hidden(m, b, Vector3(0.0, 0.0, -1.0)), "its front faces the hall")
			hidden += 1
	assert_eq(hidden, 1)
