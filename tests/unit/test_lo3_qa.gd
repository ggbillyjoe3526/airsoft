extends GutTest
## QA hunt for LO3 (replica colours in play): a session's paints per slot, bots by team, the Realistic setting, the
## static paint cache across sessions and while views still hold materials, and what a figure leaves behind.

const Fixtures := preload("res://tests/unit/replica_fixtures.gd")


func before_each() -> void:
	ReplicaPaint.clear()


func _aeg() -> ReplicaConfig:
	var r := Fixtures.aeg()
	r.site_class = &"rifle"
	return r


func _pistol() -> ReplicaConfig:
	var r := Fixtures.pistol()
	r.site_class = &"pistol"
	return r


func _body(model: Node) -> Material:
	var nodes := model.find_children("*", "MeshInstance3D", true, false)
	nodes.push_front(model)
	for node: Node in nodes:
		var m := node as MeshInstance3D
		if m == null:
			continue
		for i in m.mesh.get_surface_count():
			var own := m.mesh.surface_get_material(i)
			if own != null and own.resource_name == &"Furniture":
				return m.get_surface_override_material(i)
	return null


func _session(realistic: bool, paints: Array[StringName]) -> PlaySession:
	var s := PlaySession.new()
	s.autopilot = true
	s.settings = Settings.new()
	s.settings.realistic_colours = realistic
	if not paints.is_empty():
		var k := Kit.new()
		var r: Array[ReplicaConfig] = [_aeg(), _pistol()]
		k.replicas = r
		k.paints = paints
		k.bb_weights.append(0.2)
		k.bb_weights.append(0.2)
		s.kit = k
	add_child_autofree(s)
	return s


func test_a_session_paints_each_slot_from_the_kit_and_the_bots_by_team_and_class() -> void:
	var s := _session(false, [&"teal", &"hazard"] as Array[StringName])
	await wait_physics_frames(3)
	var hands: ReplicaView = s._hands
	assert_eq((_body(hands._held[0].root) as StandardMaterial3D).albedo_color, ReplicaSchemes.colours(&"teal", false)[1])
	assert_eq((_body(hands._held[1].root) as StandardMaterial3D).albedo_color, ReplicaSchemes.colours(&"hazard", false)[1])
	for f in s._figures:
		var team := s.state.characters[f.character_id].team
		var rifle := ReplicaSchemes.bot_paint(team, &"rifle")
		var pistol := ReplicaSchemes.bot_paint(team, &"pistol")
		assert_eq((_body(f._replicas[0]) as StandardMaterial3D).albedo_color, ReplicaSchemes.colours(rifle, false)[1])
		assert_eq((_body(f._replicas[1]) as StandardMaterial3D).albedo_color, ReplicaSchemes.colours(pistol, false)[1])


func test_realistic_in_a_session_turns_the_player_and_every_bot_plain() -> void:
	var s := _session(true, [&"teal", &"hazard"] as Array[StringName])
	await wait_physics_frames(3)
	assert_eq((_body(s._hands._held[0].root) as StandardMaterial3D).albedo_color,
			ReplicaSchemes.colours(&"ranger", false)[1])
	for f in s._figures:
		var team := s.state.characters[f.character_id].team
		var plain: StringName = ReplicaSchemes.SCHEMES[ReplicaSchemes.bot_paint(team, &"rifle")]["family"]
		assert_eq((_body(f._replicas[0]) as StandardMaterial3D).albedo_color, ReplicaSchemes.colours(plain, false)[1])


func test_a_second_session_rebuilds_the_cache_after_the_first_cleared_it() -> void:
	var a := _session(false, [] as Array[StringName])
	await wait_physics_frames(2)
	var first := _body(a._hands._held[0].root)
	remove_child(a)
	a.free()
	assert_true(ReplicaPaint._sets.is_empty(), "leaving the session clears the cache")
	var b := _session(false, [] as Array[StringName])
	await wait_physics_frames(2)
	var second := _body(b._hands._held[0].root)
	assert_not_null(second)
	assert_eq((second as StandardMaterial3D).albedo_color, ReplicaSchemes.colours(&"cobalt", false)[1])
	assert_not_same(first, second)


func test_clearing_the_cache_leaves_a_live_view_painted_and_later_views_equal() -> void:
	var loadout: Array[ReplicaConfig] = [_aeg()]
	var v1 := ReplicaView.new()
	add_child_autofree(v1)
	v1.setup(ViewModelConfig.new(), loadout, BoxWorld.new(), [&"coral"] as Array[StringName], false)
	ReplicaPaint.clear()
	var v2 := ReplicaView.new()
	add_child_autofree(v2)
	v2.setup(ViewModelConfig.new(), loadout, BoxWorld.new(), [&"coral"] as Array[StringName], false)
	var a := _body(v1._held[0].root) as StandardMaterial3D
	var b := _body(v2._held[0].root) as StandardMaterial3D
	assert_eq(a.albedo_color, b.albedo_color)
	assert_eq(a.albedo_color, ReplicaSchemes.colours(&"coral", false)[1])


func test_a_figure_puts_its_replica_away_while_fading_and_shows_it_again_after_a_reset() -> void:
	var loadout: Array[ReplicaConfig] = [_aeg(), _pistol()]
	var c := Character.new(2, 0, Vector3.ZERO, 0.0, loadout)
	var f := FigureView.new()
	add_child_autofree(f)
	f.setup(c, Color.RED, HitConfig.new(), ThemeDB.fallback_font)
	var models := FigureModels.new(FigureConfig.new())
	models.load_kinds()
	f.set_body(models, FigureMix.HUMAN, models.config.lod_high)
	_pose(f, c)
	assert_true(f._replicas[0].visible)
	c.status = Character.Status.LEAVING
	c.status_time = 0.5 * HitConfig.new().vanish_time
	_pose(f, c)
	assert_false(f._replicas[0].visible, "no shared-material replica hangs in the air while the body fades")
	c.status = Character.Status.ALIVE
	c.armament.active = 1
	_pose(f, c)
	assert_eq(f.body().hands.in_hand, 1, "the pistol out after the reset")
	assert_true(f._replicas[1].visible)
	assert_eq(f.body().hands.on_back, 0, "the rifle worn on the back again (HS1)")
	assert_true(f._replicas[0].visible)


## `f` placed and posed from `c`, as a frame draws it.
func _pose(f: FigureView, c: Character) -> void:
	f.update(c, 1.0)
	f.animate(c, 1.0, 0.0, Vector3.ZERO)


func test_the_cyber_pistol_stays_unpainted_even_when_a_bad_paint_is_passed() -> void:
	var cyber := _pistol()
	cyber.id = &"cyber"
	var loadout: Array[ReplicaConfig] = [cyber]
	var v := ReplicaView.new()
	add_child_autofree(v)
	v.setup(ViewModelConfig.new(), loadout, BoxWorld.new(), [&"cobalt"] as Array[StringName], false)
	for node: Node in v._held[0].root.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		for i in m.mesh.get_surface_count():
			assert_null(v.painted(m, i), "%s keeps its own colours" % node.name)


func test_sessions_with_painted_views_leave_no_nodes_or_cache() -> void:
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 2:
		var s := PlaySession.new()
		s.autopilot = true
		add_child(s)
		await wait_physics_frames(3)
		remove_child(s)
		s.free()
		await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes)
	assert_true(ReplicaPaint._sets.is_empty())
