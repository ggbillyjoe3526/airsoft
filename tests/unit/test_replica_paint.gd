extends GutTest
## Replica colours in play (game/play/replica_paint.gd, replica_view.gd, figure_view.gd): a replica wears its paint's
## five colours, the Realistic colours setting shows a bold scheme as its plain family, the Cyber Pistol keeps its
## own, bots wear their team's paints, replicas in one paint share their materials, and nothing is left behind.

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


func _cyber() -> ReplicaConfig:
	var r := Fixtures.pistol()
	r.id = &"cyber"
	r.site_class = &"pistol"
	return r


## The paint on the first surface of `model` (or below it) whose own material is named `part` (ReplicaView.painted: as
## painted, before the hands press its depth), or null.
func _override(model: Node, part: StringName) -> Material:
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	meshes.push_front(model)
	for node: Node in meshes:
		if not node is MeshInstance3D:
			continue
		var mesh_node := node as MeshInstance3D
		for i in mesh_node.mesh.get_surface_count():
			var own := mesh_node.mesh.surface_get_material(i)
			# a figure's held replica merged by HeldMerge (BP5) has the paints themselves, named after their part
			if own != null and (own.resource_name == part or own.resource_name.ends_with("_" + part)):
				return _painted(mesh_node, i)
	return null


## The paint on surface `i` of `mesh_node`: in the hands, as painted before its depth was pressed (null: its own).
func _painted(mesh_node: MeshInstance3D, i: int) -> Material:
	var n: Node = mesh_node
	while n != null and not n is ReplicaView:
		n = n.get_parent()
	if n != null:
		return (n as ReplicaView).painted(mesh_node, i)
	# a figure's: painted over, or (merged by HeldMerge, BP5) the paint is the merged surface's own
	var over := mesh_node.get_surface_override_material(i)
	return over if over != null else mesh_node.mesh.surface_get_material(i)


func _colour(m: Material) -> Color:
	return (m as StandardMaterial3D).albedo_color


func _hands(loadout: Array[ReplicaConfig], paints: Array[StringName], realistic: bool) -> ReplicaView:
	var view := ReplicaView.new()
	add_child_autofree(view)
	view.setup(ViewModelConfig.new(), loadout, BoxWorld.new(), paints, realistic)
	return view


func _figure(team: int, loadout: Array[ReplicaConfig], realistic: bool) -> FigureView:
	var c := Character.new(2, team, Vector3.ZERO, 0.0, loadout)
	var f := FigureView.new()
	add_child_autofree(f)
	f.setup(c, Color.RED, HitConfig.new(), ThemeDB.fallback_font, realistic)
	return f


func test_a_replica_in_hand_wears_its_paints_five_colours() -> void:
	var view := _hands([_aeg()] as Array[ReplicaConfig], [&"cobalt"] as Array[StringName], false)
	var want := ReplicaSchemes.colours(&"cobalt", false)
	var model: Node = view._held[0].root
	for i in ReplicaSchemes.PARTS.size():
		var m := _override(model, ReplicaSchemes.PARTS[i])
		assert_not_null(m, "%s is painted" % ReplicaSchemes.PARTS[i])
		assert_eq(_colour(m), want[i], "%s wears Cobalt's" % ReplicaSchemes.PARTS[i])


func test_a_slot_without_a_paint_wears_its_classes_default() -> void:
	var view := _hands([_aeg(), _pistol()] as Array[ReplicaConfig], [] as Array[StringName], false)
	assert_eq(_colour(_override(view._held[0].root, &"Furniture")), ReplicaSchemes.colours(&"cobalt", false)[1])
	assert_eq(_colour(_override(view._held[1].root, &"Furniture")), ReplicaSchemes.colours(&"ghost", false)[1])


func test_realistic_colours_show_the_plain_family() -> void:
	var view := _hands([_aeg()] as Array[ReplicaConfig], [&"cobalt"] as Array[StringName], true)
	var black := ReplicaSchemes.colours(&"black", false)
	for i in ReplicaSchemes.PARTS.size():
		assert_eq(_colour(_override(view._held[0].root, ReplicaSchemes.PARTS[i])), black[i])
	assert_ne(black, ReplicaSchemes.colours(&"cobalt", false), "and Black is not Cobalt")


func test_a_plain_colour_is_the_same_realistic_or_not() -> void:
	var view := _hands([_aeg()] as Array[ReplicaConfig], [&"ranger"] as Array[StringName], true)
	assert_eq(_colour(_override(view._held[0].root, &"Body")), ReplicaSchemes.colours(&"ranger", false)[0])


func test_the_cyber_pistol_keeps_its_own_colours() -> void:
	var view := _hands([_cyber()] as Array[ReplicaConfig], [] as Array[StringName], false)
	assert_eq(ReplicaPaint.default_paint(_cyber()), ReplicaSchemes.OWN)
	for node: Node in view._held[0].root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		for i in mesh_node.mesh.get_surface_count():
			assert_null(_painted(mesh_node, i), "%s surface %d keeps its own" % [node.name, i])
	# Realistic colours: a dark grey slab and plain grey lines, nothing glowing; its metal keeps the model's own.
	var own := _hands([_cyber()] as Array[ReplicaConfig], [ReplicaSchemes.OWN] as Array[StringName], true)
	var slab := _override(own._held[0].root, &"CyberSlab") as StandardMaterial3D
	assert_eq(_colour(slab), Color.hex(0x4a4f57ff))
	var line := _override(own._held[0].root, &"CyberLine") as StandardMaterial3D
	assert_false(line.emission_enabled, "the lines don't glow")
	assert_null(_override(own._held[0].root, &"CyberMetal"))


func test_a_cyber_pistol_picture_repainted_from_realistic_gets_its_glow_back() -> void:
	var view := _hands([_cyber()] as Array[ReplicaConfig], [ReplicaSchemes.OWN] as Array[StringName], true)
	var model := view._held[0].root
	assert_not_null(_override(model, &"CyberLine"))
	ReplicaPaint.apply(model, ReplicaSchemes.OWN, false)
	assert_null(_override(model, &"CyberLine"), "back to the model's own glowing lines")


func test_parts_the_scheme_does_not_name_keep_their_own() -> void:
	var view := _hands([_aeg()] as Array[ReplicaConfig], [&"cobalt"] as Array[StringName], false)
	assert_null(_override(view._held[0].root, &"Rubber"))
	assert_null(_override(view._held[0].root, &"BB"))


func test_bots_wear_their_teams_paints() -> void:
	assert_eq(ReplicaPaint.bot_paint(0, _aeg()), &"cobalt")
	assert_eq(ReplicaPaint.bot_paint(0, _pistol()), &"onyx")
	assert_eq(ReplicaPaint.bot_paint(1, _aeg()), &"signal")
	assert_eq(ReplicaPaint.bot_paint(1, _pistol()), &"coral")
	assert_eq(ReplicaPaint.bot_paint(1, _cyber()), ReplicaSchemes.OWN)
	var loadout: Array[ReplicaConfig] = [_aeg(), _pistol()]
	var alpha := _figure(0, loadout, false)
	var beta := _figure(1, loadout, false)
	assert_eq(_colour(_override(alpha._replicas[0], &"Furniture")), ReplicaSchemes.colours(&"cobalt", false)[1])
	assert_eq(_colour(_override(alpha._replicas[1], &"Detail")), ReplicaSchemes.colours(&"onyx", false)[2])
	assert_eq(_colour(_override(beta._replicas[0], &"Furniture")), ReplicaSchemes.colours(&"signal", false)[1])
	assert_eq(_colour(_override(beta._replicas[1], &"Furniture")), ReplicaSchemes.colours(&"coral", false)[1])


func test_bots_show_the_plain_colour_under_realistic() -> void:
	var loadout: Array[ReplicaConfig] = [_aeg()]
	var beta := _figure(1, loadout, true)
	assert_eq(_colour(_override(beta._replicas[0], &"Furniture")), ReplicaSchemes.colours(&"tan", false)[1])


func test_a_figure_shows_the_replica_it_has_out() -> void:
	var loadout: Array[ReplicaConfig] = [_aeg(), _pistol()]
	var c := Character.new(2, 0, Vector3.ZERO, 0.0, loadout)
	var f := FigureView.new()
	add_child_autofree(f)
	f.setup(c, Color.RED, HitConfig.new(), ThemeDB.fallback_font)
	var models := FigureModels.new(FigureConfig.new())
	models.load_kinds()
	f.set_body(models, FigureMix.HUMAN, models.config.lod_high)
	f.update(c, 1.0)
	f.animate(c, 1.0, 0.0, Vector3.ZERO)
	var hands := f.body().hands
	assert_eq(hands.in_hand, 0, "the rifle out")
	assert_true(f._replicas[0].visible)
	assert_eq(hands.in_holster, 1, "the pistol worn in the holster (HS1)")
	assert_true(f._replicas[1].visible)
	c.armament.active = 1
	f.update(c, 1.0)
	f.animate(c, 1.0, 0.0, Vector3.ZERO)
	assert_eq(hands.in_hand, 1, "the pistol out")
	assert_true(f._replicas[1].visible)
	assert_eq(hands.on_back, 0, "the rifle worn on the back (HS1)")
	assert_true(f._replicas[0].visible)


func test_replicas_in_one_paint_share_their_materials() -> void:
	var loadout: Array[ReplicaConfig] = [_aeg()]
	var a := _figure(0, loadout, false)
	var b := _figure(0, loadout, false)
	var hands := _hands(loadout, [&"cobalt"] as Array[StringName], false)
	for part: StringName in ReplicaSchemes.PARTS:
		var m := _override(a._replicas[0], part)
		assert_same(_override(b._replicas[0], part), m, "%s shared by two figures" % part)
		assert_same(_override(hands._held[0].root, part), m, "%s shared with the hands (same paint)" % part)
	assert_eq(ReplicaPaint._sets.size(), 1, "built once for the one paint")
	var other := _hands(loadout, [&"signal"] as Array[StringName], false)
	assert_not_same(_override(other._held[0].root, &"Body"), _override(a._replicas[0], &"Body"))
	assert_eq(ReplicaPaint._sets.size(), 2)


func test_the_cache_is_bounded() -> void:
	for i in ReplicaPaint.MAX_SETS + 5:
		ReplicaPaint._sets["x%d" % i] = []
	ReplicaPaint.materials(&"cobalt", false)
	assert_lte(ReplicaPaint._sets.size(), ReplicaPaint.MAX_SETS)
	ReplicaPaint.clear()
	assert_true(ReplicaPaint._sets.is_empty())


func test_nothing_is_left_after_free() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var loadout: Array[ReplicaConfig] = [_aeg(), _pistol()]
	var view := ReplicaView.new()
	view.setup(ViewModelConfig.new(), loadout, BoxWorld.new(), [&"cobalt", &"ghost"] as Array[StringName], false)
	var c := Character.new(2, 1, Vector3.ZERO, 0.0, loadout)
	var f := FigureView.new()
	f.setup(c, Color.RED, HitConfig.new(), ThemeDB.fallback_font, false)
	view.free()
	f.free()
	ReplicaPaint.clear()
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)
	assert_true(ReplicaPaint._sets.is_empty())
