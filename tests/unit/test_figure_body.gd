extends GutTest
## FI1: one character's rigged figure (game/play/figures/figure_body.gd): one head by figure id, one level of detail
## drawn at each distance within the asset budgets, a shadow twin, the team paint shared, bones by name, the fade.

## docs/CC0_ASSETS.md's budgets: triangles at LOD0, LOD1 and LOD2.
const BUDGET := [60000, 20000, 6000]
const DISTANCES := [5.0, 10.0, 20.0, 40.0]
## The human with the largest head (HighCut, id 0) at High's lines: LOD0, LOD0, LOD1, LOD2 (step 23 plan › 2).
const HUMAN_HIGH := [25224, 25224, 8486, 2843]
const RED := Color(0.9, 0.2, 0.15)
const BLUE := Color(0.2, 0.4, 0.95)

var models: FigureModels = null
var config: FigureConfig = null


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()


func _body(kind: int, id: int, team: int = 0, lines: Vector2 = Vector2.ZERO, autofree: bool = true) -> FigureBody:
	var b := FigureBody.new()
	assert_true(b.setup(models, kind, id, team, RED if team == 0 else BLUE, 0.0,
			config.lod_high if lines == Vector2.ZERO else lines))
	if autofree:
		add_child_autofree(b)
	else:
		add_child(b)
	return b


static func _tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		n += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n


## The triangles the view draws at `distance` (m), settled (past each line's margin): the levels whose range holds it.
static func _drawn(b: FigureBody, distance: float) -> int:
	var n := 0
	for i in b.meshes.size():
		var mi := b.meshes[i]
		if b.levels[i] < 0 or not mi.visible:
			continue
		var past_begin := distance >= mi.visibility_range_begin
		var before_end := mi.visibility_range_end <= 0.0 or distance < mi.visibility_range_end
		if past_begin and before_end:
			n += _tris(mi.mesh)
	return n


static func _heads_drawn(b: FigureBody) -> PackedStringArray:
	var out := PackedStringArray()
	for mi in b.meshes:
		if String(mi.name).begins_with("Head_"):
			out.append(String(mi.name).get_slice("_LOD", 0))
	return out


func test_the_human_draws_one_head_and_one_level_at_each_distance() -> void:
	var b := _body(FigureMix.HUMAN, 0)
	assert_eq(b.head, &"Head_HighCut")
	for i in DISTANCES.size():
		assert_eq(_drawn(b, DISTANCES[i]), HUMAN_HIGH[i], "%.0f m" % DISTANCES[i])


func test_every_figure_is_within_the_budgets_at_every_distance() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		for id in config.heads.size():
			for lines: Vector2 in [config.lod_high, config.lod_low]:
				var b := _body(kind, id, 0, lines, false)
				var levels := [_drawn(b, 1.0), _drawn(b, (lines.x + lines.y) * 0.5), _drawn(b, lines.y + 10.0)]
				for level in 3:
					assert_between(levels[level], 1, BUDGET[level], "kind %d id %d level %d" % [kind, id, level])
				b.free()


func test_the_lines_follow_mesh_detail() -> void:
	assert_eq(config.lod_lines(GraphicsQuality.MeshDetail.ULTRA), Vector2(12.0, 28.0))
	assert_eq(config.lod_lines(GraphicsQuality.MeshDetail.HIGH), Vector2(12.0, 28.0))
	assert_eq(config.lod_lines(GraphicsQuality.MeshDetail.MEDIUM), Vector2(6.0, 16.0))
	assert_eq(config.lod_lines(GraphicsQuality.MeshDetail.LOW), Vector2(6.0, 16.0))
	var b := _body(FigureMix.HUMAN, 0)
	b.set_lod_lines(config.lod_low)
	assert_eq(_drawn(b, 10.0), HUMAN_HIGH[2], "LOD1 at 10 m on Low")
	assert_eq(_drawn(b, 20.0), HUMAN_HIGH[3], "LOD2 at 20 m on Low")


func test_each_line_has_its_margin_and_the_radio_ends_at_the_far_line() -> void:
	var b := _body(FigureMix.HUMAN, 1)
	for i in b.meshes.size():
		var mi := b.meshes[i]
		match b.levels[i]:
			0:
				assert_eq(mi.visibility_range_end, 12.0, mi.name)
				assert_eq(mi.visibility_range_end_margin, config.lod_margin)
			1:
				assert_eq([mi.visibility_range_begin, mi.visibility_range_end], [12.0, 28.0], mi.name)
				assert_eq(mi.visibility_range_begin_margin, config.lod_margin)
				assert_eq(mi.visibility_range_end_margin, config.lod_margin)
			2:
				assert_eq(mi.visibility_range_begin, 28.0, mi.name)
				assert_eq(mi.visibility_range_end, 0.0, "no end")
	var radio := b.skeleton.get_node(^"Kit_Radio_LOD1") as MeshInstance3D
	assert_eq(radio.visibility_range_end, 28.0, "no LOD2: gone past the far line")
	assert_null(b.skeleton.get_node_or_null(^"Kit_Radio_LOD2"))


func test_every_head_index_has_its_head_and_the_others_are_freed() -> void:
	for id in 8:
		var b := _body(FigureMix.HUMAN, id)
		var want := config.heads[id % config.heads.size()]
		assert_eq(b.head, StringName(want))
		var drawn := _heads_drawn(b)
		assert_eq(drawn, PackedStringArray([want, want, want]), "its head at each level")
		for other in config.heads:
			if other != want:
				assert_null(b.skeleton.get_node_or_null(NodePath(other)), "freed: %s" % other)
	var robot := _body(FigureMix.ROBOT, 5)
	assert_eq(robot.head, &"")
	assert_eq(_heads_drawn(robot), PackedStringArray(["Head_Headset", "Head_Headset", "Head_Headset"]))


func test_the_levels_cast_no_shadow_and_one_twin_casts_it() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		var b := _body(kind, 2)
		var twins := 0
		for i in b.meshes.size():
			var mi := b.meshes[i]
			if b.levels[i] < 0:
				twins += 1
				assert_eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
				assert_eq(mi.visibility_range_end, 0.0, "every range")
				assert_eq(mi.mesh.get_surface_count(), 1, "one draw")
				assert_not_null(mi.skin, "skinned with the body")
			else:
				assert_eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, mi.name)
		assert_eq(twins, 1)
	var human := _body(FigureMix.HUMAN, 0)
	# LOD2 body, HighCut, kit and pack.
	assert_eq(_tris(human.meshes[-1].mesh), HUMAN_HIGH[3])
	assert_same(_body(FigureMix.HUMAN, 4).meshes[-1].mesh, human.meshes[-1].mesh, "made once a kind and head")


func test_a_teams_team_surfaces_share_one_material_and_the_rest_stay_as_modelled() -> void:
	var a := _body(FigureMix.ROBOT, 1, 0)
	var b := _body(FigureMix.ROBOT, 3, 0)
	var other := _body(FigureMix.ROBOT, 5, 1)
	var by_source: Dictionary[String, Material] = {}
	for body: FigureBody in [a, b]:
		for mi in body.meshes:
			if body.levels[body.meshes.find(mi)] < 0:
				continue
			for s in mi.mesh.get_surface_count():
				var source := mi.mesh.surface_get_material(s)
				var drawn := mi.get_surface_override_material(s)
				if source.resource_name.to_lower().begins_with("team"):
					assert_not_null(drawn, source.resource_name)
					if by_source.has(source.resource_name):
						assert_same(drawn, by_source[source.resource_name], "shared: " + source.resource_name)
					by_source[source.resource_name] = drawn
					assert_eq((drawn as BaseMaterial3D).albedo_color, RED)
				else:
					assert_null(drawn, "as modelled: " + source.resource_name)
	assert_eq(by_source.keys().size(), 2, "TeamPaint and TeamGlow")
	var glow := by_source["TeamGlow"] as BaseMaterial3D
	assert_true(glow.emission_enabled, "keeps its glow")
	assert_eq(glow.emission, RED)
	var theirs := other.meshes[0].get_surface_override_material(2) as BaseMaterial3D
	assert_eq(theirs.albedo_color, BLUE, "the other team's own")
	var human := _body(FigureMix.HUMAN, 0)
	var paint := human.meshes[0].get_surface_override_material(1) as BaseMaterial3D
	assert_eq(paint.albedo_color, RED)
	assert_null(human.meshes[0].get_surface_override_material(0), "Outfit as modelled")


func test_the_high_contrast_glow_lights_the_team_paint() -> void:
	var b := FigureBody.new()
	b.setup(models, FigureMix.HUMAN, 0, 0, RED, 0.6, config.lod_high)
	add_child_autofree(b)
	var paint := b.meshes[0].get_surface_override_material(1) as BaseMaterial3D
	assert_true(paint.emission_enabled)
	assert_almost_eq(paint.emission_energy_multiplier, 0.6, 1e-6)


func test_bones_are_looked_up_by_name_on_both_files() -> void:
	var human := _body(FigureMix.HUMAN, 0)
	var robot := _body(FigureMix.ROBOT, 0)
	for name in config.bones:
		for b: FigureBody in [human, robot]:
			assert_gte(b.bone(StringName(name)), 0, name)
			assert_eq(b.skeleton.get_bone_name(b.bone(StringName(name))), name)
	assert_ne(human.bone(&"Grip_R"), robot.bone(&"Grip_R"), "the files order them differently")
	assert_eq(human.bone(&"Nope"), -1)


func test_its_legs_play_the_kinds_graph_facing_the_figure_forward() -> void:
	var b := _body(FigureMix.ROBOT, 0)
	assert_not_null(b.tree, "FI2: an AnimationTree in place of the model's player")
	assert_eq(b.tree.tree_root, models.graph(FigureMix.ROBOT), "the kind's graph, shared")
	assert_eq(b.tree.callback_mode_process, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL)
	assert_eq(b.find_children("*", "AnimationPlayer", true, false).size(), 0, "the model's own player freed")
	assert_almost_eq((b.get_child(0) as Node3D).rotation.y, PI, 1e-6, "turned to face -Z")


func test_the_fade_sets_transparency_on_every_mesh() -> void:
	var b := _body(FigureMix.HUMAN, 0)
	b.set_fade(0.25)
	for mi in b.meshes:
		assert_almost_eq(mi.transparency, 0.75, 1e-6, mi.name)
	b.set_fade(1.0)
	for mi in b.meshes:
		assert_eq(mi.transparency, 0.0, "solid again")


func test_any_id_wears_one_of_the_heads() -> void:
	for id: int in [-1, -4, -5, 4, 5, 7, 1 << 40, 9223372036854775807, -9223372036854775808]:
		var b := _body(FigureMix.HUMAN, id)
		assert_true(config.heads.has(String(b.head)), "id %d" % id)
		assert_not_null(b.skeleton.get_node_or_null(NodePath(String(b.head))), "its head is there, id %d" % id)


func test_a_mesh_the_sidecar_does_not_list_is_not_drawn() -> void:
	var m := FigureModels.new(config)
	m.load_kinds()
	m._kinds[FigureMix.ROBOT].sidecar = FigureSidecar.parse(JSON.stringify({"clips": [], "parts": ["Body"]}))
	var b := FigureBody.new()
	assert_true(b.setup(m, FigureMix.ROBOT, 0, 0, RED, 0.0, config.lod_high))
	add_child_autofree(b)
	var left := b.skeleton.find_children("*", "MeshInstance3D", false, false)
	assert_eq(left.size(), 1, "Body only (no LOD2 listed, so no twin)")
	assert_eq(b.meshes.size(), 1)


func test_no_glow_leaves_the_paint_unlit() -> void:
	var b := _body(FigureMix.HUMAN, 0)
	var paint := b.meshes[0].get_surface_override_material(1) as BaseMaterial3D
	assert_false(paint.emission_enabled)
	var source := b.meshes[0].mesh.surface_get_material(1) as BaseMaterial3D
	assert_ne(source.albedo_color, RED, "the source stays as modelled")
