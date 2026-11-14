extends GutTest
## The Dev 3 audit's fixes to what is drawn (AUD1): a pistol's torch hangs under a laser fitted with it (the parts
## file's `_UnderLaser` point, which nothing read), a match's figures take their parts out of one instance of each
## parts file (ReplicaParts.keep and release), the same nodes as a plain take's and nothing left behind, and the
## scene's bounced light (SDFGI) is gathered afresh when the field's lamps are switched (FieldLighting).

const EPS := 1e-5
const TORCH := {&"light": &"weaponTorch"}
const TORCH_AND_LASER := {&"light": &"weaponTorch", &"laser": &"redLaser"}


func _free(taken: Dictionary[StringName, Node3D]) -> void:
	for node: Node3D in taken.values():
		node.free()


## Where the torch of replica `key` sits with `parts` fitted, in the replica's space (`figure`: its figures' copy).
func _torch_at(key: StringName, parts: Dictionary, figure: bool) -> Vector3:
	var taken := ReplicaParts.take(key, parts, figure)
	ReplicaParts._hang_under_laser(taken)
	var at := taken[&"light"].position
	_free(taken)
	return at


## A line for every node under `node`: its name, class, place and (a mesh) its size, so two takes can be compared.
func _lines(node: Node, depth: int, out: PackedStringArray) -> void:
	var line := "%d %s %s" % [depth, node.name, node.get_class()]
	if node is Node3D:
		line += " %s %s" % [(node as Node3D).transform, (node as Node3D).visible]
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		line += " %d %s" % [mesh.get_surface_count(), mesh.get_aabb()]
	line += " %s" % [node.owner]
	out.append(line)
	for child: Node in node.get_children():
		_lines(child, depth + 1, out)


func _taken_lines(key: StringName, parts: Dictionary, figure: bool) -> String:
	var out := PackedStringArray()
	var taken := ReplicaParts.take(key, parts, figure)
	for slot: StringName in taken:
		out.append(String(slot))
		_lines(taken[slot], 0, out)
	_free(taken)
	return "\n".join(out)


func test_a_pistols_torch_hangs_under_a_laser_fitted_with_it() -> void:
	for figure: bool in [false, true]:
		var alone := _torch_at(&"pistol", TORCH, figure)
		var under := _torch_at(&"pistol", TORCH_AND_LASER, figure)
		assert_almost_eq(alone.x, under.x, EPS, "figure %s: not moved sideways" % figure)
		assert_almost_eq(alone.z, under.z, EPS, "figure %s: not moved along the rail" % figure)
		assert_lt(under.y, alone.y - 0.01, "figure %s: the torch hangs lower with the laser on the rail" % figure)


func test_a_pistols_laser_keeps_its_place_with_the_torch() -> void:
	var alone := ReplicaParts.take(&"pistol", {&"laser": &"redLaser"}, false)
	var both := ReplicaParts.take(&"pistol", TORCH_AND_LASER, false)
	ReplicaParts._hang_under_laser(both)
	assert_almost_eq(both[&"laser"].position, alone[&"laser"].position, Vector3.ONE * EPS)
	assert_gt(both[&"laser"].position.y, both[&"light"].position.y + 0.01, "the laser sits above the torch")
	_free(alone)
	_free(both)


func test_a_rifles_torch_stays_with_a_laser_fitted() -> void:
	for figure: bool in [false, true]:
		assert_almost_eq(_torch_at(&"aeg", TORCH_AND_LASER, figure), _torch_at(&"aeg", TORCH, figure),
				Vector3.ONE * EPS, "figure %s: the rifle's torch and laser have a rail each" % figure)


func test_the_fitted_pistol_shows_the_torch_under_the_laser() -> void:
	var model := (load("res://assets/models/replicas/pistol.glb") as PackedScene).instantiate() as Node3D
	add_child_autofree(model)
	var fit := ReplicaParts.fit(model, &"pistol", TORCH_AND_LASER)
	var torch := model.find_child("light_weaponTorch", true, false) as Node3D
	var laser := model.find_child("laser_redLaser", true, false) as Node3D
	assert_not_null(torch, "the torch is fitted")
	assert_not_null(laser, "the laser is fitted")
	if torch != null and laser != null:
		assert_lt(torch.global_position.y, laser.global_position.y - 0.01, "the torch hangs under the laser")
	ReplicaParts.unfit(fit)


func test_kept_takes_give_the_nodes_a_plain_take_gives() -> void:
	var sets: Array[Dictionary] = [
		{&"light": &"weaponTorch", &"optic": &"redDot", &"grip": &"vertical", &"muzzle": &"silencer"},
		{&"barrel": &"long", &"magazine": &"hiCap", &"laser": &"redLaser", &"optic": &"scope2x"},
	]
	for key: StringName in [&"aeg", &"pistol", &"sniper"]:
		for parts: Dictionary in sets:
			for figure: bool in [false, true]:
				var plain := _taken_lines(key, parts, figure)
				ReplicaParts.keep()
				var first := _taken_lines(key, parts, figure)
				var again := _taken_lines(key, parts, figure)
				ReplicaParts.release()
				assert_eq(first, plain, "%s figure %s: the first kept take" % [key, figure])
				assert_eq(again, plain, "%s figure %s: a later kept take, the instance still whole" % [key, figure])


func test_release_frees_what_keep_held() -> void:
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	ReplicaParts.keep()
	_free(ReplicaParts.take(&"aeg", TORCH, true))
	_free(ReplicaParts.take(&"pistol", TORCH_AND_LASER, true))
	_free(ReplicaParts.take(&"aeg", {&"optic": &"noSuchPart"}, false))
	assert_gt(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), orphans, "the instances are held")
	ReplicaParts.release()
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), orphans, "nothing left behind")
	# After release a take is a plain one again: its file's instance is freed with it.
	_free(ReplicaParts.take(&"aeg", TORCH, true))
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), orphans, "a plain take keeps none")


## A field's lighting in the tree, with Global illumination at `gi`.
func _lighting(gi: GraphicsQuality.GlobalIllumination) -> FieldLighting:
	var lighting := FieldLighting.build(LightingConfig.new())
	add_child_autofree(lighting)
	lighting.set_effects(gi, GraphicsQuality.Reflections.OFF, false, false, false)
	return lighting


func test_a_refresh_holds_the_scene_light_off_for_its_frames_then_on() -> void:
	var lighting := _lighting(GraphicsQuality.GlobalIllumination.SCENE)
	assert_true(lighting.environment.sdfgi_enabled, "Scene: on")
	lighting.refresh_scene_light()
	assert_false(lighting.environment.sdfgi_enabled, "off at once")
	assert_true(lighting.refreshing_scene_light())
	# The settings applied again meanwhile (another row changed) don't cut the refresh short.
	lighting.set_effects(GraphicsQuality.GlobalIllumination.SCENE, GraphicsQuality.Reflections.OFF, false, false, false)
	assert_false(lighting.environment.sdfgi_enabled, "still off: a frame must draw without it")
	for i: int in FieldLighting.SCENE_LIGHT_REFRESH_FRAMES:
		assert_true(lighting.refreshing_scene_light(), "frame %d" % i)
		await get_tree().process_frame
	assert_false(lighting.refreshing_scene_light())
	assert_true(lighting.environment.sdfgi_enabled, "on again")
	assert_false(get_tree().process_frame.is_connected(lighting._on_refresh_frame), "the frame hook is let go")


func test_a_refresh_does_nothing_without_the_scene_light() -> void:
	for gi: GraphicsQuality.GlobalIllumination in [GraphicsQuality.GlobalIllumination.OFF,
			GraphicsQuality.GlobalIllumination.SCREEN]:
		var lighting := _lighting(gi)
		lighting.refresh_scene_light()
		assert_false(lighting.refreshing_scene_light(), "gi %d" % gi)
		assert_false(lighting.environment.sdfgi_enabled)


func test_the_scene_light_switched_off_during_a_refresh_stays_off() -> void:
	var lighting := _lighting(GraphicsQuality.GlobalIllumination.SCENE)
	lighting.refresh_scene_light()
	lighting.set_effects(GraphicsQuality.GlobalIllumination.OFF, GraphicsQuality.Reflections.OFF, false, false, false)
	for i: int in FieldLighting.SCENE_LIGHT_REFRESH_FRAMES:
		await get_tree().process_frame
	assert_false(lighting.environment.sdfgi_enabled, "the settings' word, not the refresh's")


func test_lighting_freed_during_a_refresh_lets_its_frame_hook_go() -> void:
	var lighting := FieldLighting.build(LightingConfig.new())
	add_child(lighting)
	lighting.set_effects(GraphicsQuality.GlobalIllumination.SCENE, GraphicsQuality.Reflections.OFF, false, false, false)
	lighting.refresh_scene_light()
	var hook := lighting._on_refresh_frame
	remove_child(lighting)
	assert_false(get_tree().process_frame.is_connected(hook), "no hook left on the tree")
	assert_true(lighting.environment.sdfgi_enabled, "and the light is as the settings ask")
	lighting.free()
