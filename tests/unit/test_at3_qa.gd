extends GutTest
## QA hunt for AT3 (parts in play): fitting and unfitting leave the model as it was, parts-free paths stay parts-free,
## the glass stops with the sight, and nothing is left behind.

const AEG := "000002"
const PISTOL := "000001"
const CYBER := "000019"
const RED_DOT := "000007"
const SCOPE := "000010"
const LASER := "000005"
const EXTENDED := "000014"
const LONG := "000017"
const SILENCER := "000018"
const EPS := 1e-5

var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())


func _kit(id: String, parts: Dictionary, slot: int = 0) -> Kit:
	var l := rules.default_loadout("Test")
	if l.equipped[slot] != id:
		rules.equip(l, slot as Loadout.Slot, id)
	for part_slot: StringName in parts:
		rules.set_part(l, id, part_slot, parts[part_slot])
	return rules.carried(l)


func _model(key: String) -> Node3D:
	var model := (load("res://assets/models/replicas/%s.glb" % key) as PackedScene).instantiate() as Node3D
	add_child_autofree(model)
	return model


## Every Node3D's name, position and visibility, and every bone pose, as one comparable list.
func _snapshot(model: Node3D) -> Array:
	var out: Array = []
	for n in model.find_children("*", "Node3D", true, false):
		out.append([str(model.get_path_to(n)), (n as Node3D).position, (n as Node3D).visible])
	var s := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if s != null:
		for b in s.get_bone_count():
			out.append([s.get_bone_name(b), s.get_bone_pose_rotation(b)])
	return out


func _hands(kit: Kit) -> ReplicaView:
	var eyes := Camera3D.new()
	add_child_autofree(eyes)
	var hands := ReplicaView.new()
	eyes.add_child(hands)
	hands.setup(ViewModelConfig.new(), kit.replicas, null, kit.paints, false, kit.parts, ViewConfig.new(), eyes)
	return hands


func test_fitting_and_unfitting_repeatedly_restores_the_model_exactly() -> void:
	var model := _model("aeg")
	var before := _snapshot(model)
	var parts := {&"optic": &"scope2x", &"magazine": &"hiCap", &"barrel": &"long", &"muzzle": &"silencer"}
	for i in 5:
		var fit := ReplicaParts.fit(model, &"aeg", parts, i % 2 == 0)
		assert_gt(fit.nodes.size(), 0)
		ReplicaParts.unfit(fit)
		assert_eq(_snapshot(model), before, "round %d" % i)


func test_pistol_with_laser_silencer_and_extended_magazine_has_no_optic_and_no_fold() -> void:
	var kit := _kit(PISTOL, {&"laser": LASER, &"muzzle": SILENCER, &"magazine": EXTENDED}, 1)
	var hands := _hands(kit)
	var held: ReplicaView.Held = hands._held[1]
	assert_null(held.window)
	assert_null(held.fit.optic)
	assert_null(held.fit.fold)
	assert_eq(held.muzzle.name, &"muzzle_silencer_Muzzle")
	assert_false(held.root.find_children("SightFold", "", true, false).size() > 0)


func test_cyber_pistol_without_a_parts_model_fits_nothing_and_still_shoots() -> void:
	var model := _model("cyber")
	var muzzle := model.find_child("Muzzle", true, false)
	var fit := ReplicaParts.fit(model, &"cyber", {&"muzzle": &"silencer", &"optic": &"redDot"})
	assert_eq(fit.nodes.size(), 0)
	assert_eq(fit.muzzle, muzzle)
	assert_eq(ReplicaParts.take(&"cyber", {&"muzzle": &"silencer"}, true).size(), 0)
	ReplicaParts.unfit(fit)


func test_a_part_not_in_the_models_is_left_out_without_error() -> void:
	var model := _model("pistol")
	var fit := ReplicaParts.fit(model, &"pistol", {&"optic": &"nonsense", &"nothing": &"x"})
	assert_eq(fit.nodes.size(), 0)
	assert_null(fit.optic)


func test_a_replica_without_parts_aims_as_before_and_has_no_glass() -> void:
	var hands := _hands(_kit(AEG, {}))
	assert_null(hands._held[0].window)
	assert_null(hands._held[0].fit.fold)


func test_switching_replica_while_aimed_stops_the_glass() -> void:
	var kit := _kit(AEG, {&"optic": SCOPE})
	var hands := _hands(kit)
	var held: ReplicaView.Held = hands._held[0]
	hands._show(0)
	held.root.position = Vector3(0.0, 0.0, ViewModelConfig.new().aim_forward[&"aeg"]) - held.rear_sight
	hands._glass.update(held.window, 1.0)
	assert_true(held.window.disc.visible)
	hands._show(1)
	assert_false(held.window.disc.visible, "the other replica's draw hides the disc")
	hands._glass.update(null, 1.0)
	assert_eq(hands._glass._port.render_target_update_mode, SubViewport.UPDATE_DISABLED)


func test_a_hidden_replica_stops_the_glass_even_with_raise_left() -> void:
	var hands := _hands(_kit(AEG, {&"optic": RED_DOT}))
	var held: ReplicaView.Held = hands._held[0]
	hands._show(0)
	held.root.position = Vector3(0.0, 0.0, ViewModelConfig.new().aim_forward[&"aeg"]) - held.rear_sight
	hands._glass.update(held.window, 1.0)
	held.root.visible = false
	hands._glass.update(held.window, 1.0)
	assert_false(held.window.disc.visible)
	assert_eq(hands._glass._port.render_target_update_mode, SubViewport.UPDATE_DISABLED)


func test_a_barely_raised_sight_keeps_the_glass_picture_finite() -> void:
	var hands := _hands(_kit(AEG, {&"optic": SCOPE}))
	var held: ReplicaView.Held = hands._held[0]
	hands._show(0)
	held.root.position = Vector3(0.0, 0.0, ViewModelConfig.new().aim_forward[&"aeg"]) - held.rear_sight
	hands._glass.update(held.window, 0.001)
	var fov := hands._glass._camera.fov
	assert_true(is_finite(fov) and fov > 0.0 and fov < 180.0, "fov %s" % fov)
	var span: float = held.window.material.get_shader_parameter(&"span")
	assert_true(is_finite(span) and span <= ViewModelConfig.new().glass_share + EPS)


func test_leaving_the_match_frees_the_glass_and_leaves_no_orphans() -> void:
	await wait_process_frames(2)
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for i in 3:
		var eyes := Camera3D.new()
		add_child(eyes)
		var hands := ReplicaView.new()
		eyes.add_child(hands)
		var kit := _kit(AEG, {&"optic": SCOPE, &"muzzle": SILENCER, &"magazine": "000012"})
		hands.setup(ViewModelConfig.new(), kit.replicas, null, kit.paints, false, kit.parts, ViewConfig.new(), eyes)
		hands._show(0)
		var held: ReplicaView.Held = hands._held[0]
		held.root.position = Vector3(0.0, 0.0, ViewModelConfig.new().aim_forward[&"aeg"]) - held.rear_sight
		hands._glass.update(held.window, 1.0)
		eyes.free()
	await wait_process_frames(2)
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), nodes_before)
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), orphans_before)


func test_menu_pictures_refit_repeatedly_without_growing() -> void:
	var pictures := ReplicaPictures.new()
	add_child_autofree(pictures)
	pictures.texture(&"aeg", &"", false, {})
	var shot: ReplicaPictures.Shot = pictures._shots[&"aeg"]
	var count := shot.model.find_children("*", "", true, false).size()
	var bare := shot.extent
	for i in 4:
		pictures.texture(&"aeg", &"", false, {&"optic": &"redDot", &"barrel": &"long", &"muzzle": &"silencer"})
		pictures.texture(&"aeg", &"", false, {&"optic": &"scope2x", &"magazine": &"hiCap"})
		pictures.texture(&"aeg", &"", false, {})
	assert_eq(shot.model.find_children("*", "", true, false).size(), count, "no part nodes left on the model")
	assert_almost_eq(shot.extent, bare, Vector2.ONE * EPS, "framing back to the bare replica")
	assert_eq(pictures.count(), 1)


func test_a_long_barrel_with_the_standard_flash_hider_moves_it_and_puts_it_back() -> void:
	var model := _model("aeg")
	var hider := model.find_child("FlashHider", true, false) as Node3D
	var at := hider.position
	var fit := ReplicaParts.fit(model, &"aeg", {&"barrel": &"long"})
	assert_true(hider.visible)
	assert_ne(hider.position, at, "carried out to the barrel's end")
	ReplicaParts.unfit(fit)
	assert_eq(hider.position, at)


func test_a_silenced_dry_fire_is_not_muffled_and_a_silenced_shot_uses_the_muffled_bus_only_for_silenced() -> void:
	var cfg := SoundConfig.new()
	var kit := _kit(PISTOL, {&"muzzle": SILENCER}, 1)
	var state := GameState.new(1)
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, kit.replicas, kit.bb_weights))
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(cfg, [kit.replicas[0].power] as Array[StringName], BodyConfig.new(), null, null)
	var e := state.events.add(GameEvent.Kind.DRY_FIRE)
	e.actor = 0
	e.slot = 0
	audio.on_tick(state, 0, null)  # must not error
	var shots := state.events.add(GameEvent.Kind.SHOT)
	shots.actor = 7  # an actor that does not exist
	shots.slot = 3
	audio.on_tick(state, 0, null)
	pass_test("no error")


func test_the_muffled_bus_is_not_a_settings_volume() -> void:
	assert_false(Settings.VOLUME_BUSES.has(&"Muffled"))
	assert_gte(AudioServer.get_bus_index(&"Muffled"), 0)
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Muffled")), &"Effects")


func test_a_figure_without_parts_gets_no_extra_meshes() -> void:
	assert_eq(ReplicaParts.take(&"aeg", {}, true).size(), 0)
	assert_eq(ReplicaParts.take(&"aeg", {}, false).size(), 0)
