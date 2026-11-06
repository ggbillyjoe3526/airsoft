extends GutTest
## Parts in play (AT3): a replica's parts fitted from their models the one way the hands, the figures and the menu
## pictures share (ReplicaParts), the iron sights hidden whole under an optic, aiming along the optic's sight line, the red
## dot's and the scope's glass (OpticGlass: the scope magnifies only inside it), and a silenced shot played muffled.

const AEG := "000002"
const PISTOL := "000001"
const RED_DOT := "000007"
const SCOPE := "000010"
const VERTICAL := "000006"
const LASER := "000005"
const HI_CAP := "000012"
const EXTENDED := "000014"
const LONG := "000017"
const SILENCER := "000018"
const EPS := 1e-4

var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())


## The kit with replica `id` in slot `slot` fitted with `parts` (slot → part ID).
func _kit(id: String, parts: Dictionary, slot: int = 0) -> Kit:
	var l := rules.default_loadout("Test")
	if l.equipped[slot] != id:
		rules.equip(l, slot as Loadout.Slot, id)
	for part_slot: StringName in parts:
		assert_true(rules.set_part(l, id, part_slot, parts[part_slot]), "%s fits %s" % [parts[part_slot], id])
	return rules.carried(l)


func _model(key: String) -> Node3D:
	var model := (load("res://assets/models/replicas/%s.glb" % key) as PackedScene).instantiate() as Node3D
	add_child_autofree(model)
	return model


func _in_model(node: Node3D, model: Node3D) -> Transform3D:
	return ReplicaParts._in_model(node, model)


## Whether `model`'s sight bone `bone` is drawn (its bone attachment visible).
func _sight_shown(model: Node3D, bone: String) -> bool:
	for sight in IronSights.of(model):
		if (sight as BoneAttachment3D).bone_name == bone:
			return sight.visible
	fail_test("no %s attachment" % bone)
	return false


# --- fitting ---

func test_parts_take_the_place_of_the_standard_ones_and_come_off_again() -> void:
	var model := _model("aeg")
	var mag := model.find_child("Magazine", true, false) as Node3D
	var hider := model.find_child("FlashHider", true, false) as Node3D
	var muzzle := model.find_child("Muzzle", true, false) as Node3D
	var hider_at := hider.position
	var muzzle_at := muzzle.position
	var fit := ReplicaParts.fit(model, &"aeg",
			{&"optic": &"redDot", &"magazine": &"hiCap", &"grip": &"vertical", &"barrel": &"long", &"muzzle": &"silencer"})
	assert_eq(fit.nodes.size(), 5)
	assert_false(mag.visible, "the hi-cap hides the standard magazine")
	assert_false(hider.visible, "the silencer hides the flash hider")
	assert_eq(fit.muzzle.name, &"muzzle_silencer_Muzzle", "BBs leave from the silencer's end")
	assert_eq(fit.optic_key, &"redDot")
	# The silencer sits on the long barrel's end, 0.1 m out.
	var silencer := model.find_child("muzzle_silencer", true, false) as Node3D
	assert_almost_eq(silencer.position.z, -0.439, EPS)
	assert_almost_eq(fit.sight_line, Vector3(0.0, 0.104, -0.025), Vector3.ONE * EPS)
	assert_false(_sight_shown(model, "frontSight"), "the front sight's ears and post disappear under an optic")
	assert_false(_sight_shown(model, "rearSight"), "and the whole rear sight with them")
	ReplicaParts.unfit(fit)
	assert_true(_sight_shown(model, "frontSight"), "and come back without it")
	assert_true(_sight_shown(model, "rearSight"))
	assert_eq(model.find_children("muzzle_silencer*", "", true, false).size(), 0)
	assert_true(mag.visible)
	assert_true(hider.visible)
	assert_almost_eq(hider.position, hider_at, Vector3.ONE * EPS)
	assert_almost_eq(muzzle.position, muzzle_at, Vector3.ONE * EPS)
	assert_eq(fit.muzzle, muzzle)


func test_a_long_barrel_carries_the_flash_hider_and_the_muzzle_out() -> void:
	var model := _model("aeg")
	var hider := model.find_child("FlashHider", true, false) as Node3D
	var muzzle := model.find_child("Muzzle", true, false) as Node3D
	var hider_z := hider.position.z
	var muzzle_z := muzzle.position.z
	var fit := ReplicaParts.fit(model, &"aeg", {&"barrel": &"long"})
	assert_true(hider.visible)
	assert_almost_eq(hider.position.z, hider_z - 0.1, EPS)
	assert_almost_eq(muzzle.position.z, muzzle_z - 0.1, EPS)
	assert_eq(fit.muzzle, muzzle)
	assert_null(fit.optic)
	assert_true(_sight_shown(model, "frontSight") and _sight_shown(model, "rearSight"),
			"no optic, the iron sights stay up")


func test_a_magazine_part_follows_the_magazine_bone_through_a_reload() -> void:
	var model := _model("pistol")
	var fit := ReplicaParts.fit(model, &"pistol", {&"magazine": &"extended"})
	var part := fit.nodes[0]
	var attachment := model.find_child("magazine", true, false) as Node3D
	assert_eq(part.get_parent(), attachment)
	# At rest it sits where the part model places it: the magazine well's mouth (BL2's pistol, from the photo).
	assert_almost_eq(_in_model(part, model).origin, Vector3(0.0, -0.0203, 0.04), Vector3.ONE * EPS)


func test_an_unknown_part_or_replica_fits_nothing() -> void:
	var model := _model("aeg")
	var fit := ReplicaParts.fit(model, &"aeg", {&"optic": &"periscope"})
	assert_eq(fit.nodes.size(), 0)
	assert_null(fit.optic)
	fit = ReplicaParts.fit(model, &"noSuchReplica", {&"optic": &"redDot"})
	assert_eq(fit.nodes.size(), 0)
	assert_not_null(fit.muzzle, "the replica's own muzzle still")


func test_the_figures_get_the_parts_cut_down_copies_in_place() -> void:
	var parts := {&"optic": &"redDot", &"magazine": &"hiCap", &"grip": &"angled"}
	var meshes: Array[Node3D] = ReplicaParts.take(&"aeg", parts, true).values()
	assert_eq(meshes.size(), 3)
	var names: Array = meshes.map(func(m: Node3D) -> String: return m.name)
	assert_has(names, "optic_redDot_Figure")
	assert_has(names, "magazine_hiCap_Figure")
	for m: Node3D in meshes:
		assert_true(m is MeshInstance3D, "%s is a mesh" % m.name)
		if m.name == "optic_redDot_Figure":
			assert_almost_eq(m.position, Vector3(0.0, 0.0735, -0.025), Vector3.ONE * EPS, "the optic's copy where it sits")
		assert_null(m.get_parent())
		m.free()


func test_a_figure_holds_its_replica_with_its_parts() -> void:
	var kit := _kit(PISTOL, {&"laser": LASER}, 1)
	var c := Character.new(3, 1, Vector3.ZERO, 0.0, kit.replicas, kit.bb_weights)
	var f := FigureView.new()
	add_child_autofree(f)
	f.setup(c, Color.ORANGE, HitConfig.new(), GameTheme.font(800), false, kit.parts)
	var held := f._replicas[1]
	assert_not_null(held.get_node_or_null("laser_redLaser_Figure"), "the laser module shows on the pistol")


# --- the hands ---

func _hands(kit: Kit) -> ReplicaView:
	var eyes := Camera3D.new()
	add_child_autofree(eyes)
	var hands := ReplicaView.new()
	eyes.add_child(hands)
	hands.setup(ViewModelConfig.new(), kit.replicas, null, kit.paints, false, kit.parts, ViewConfig.new(), eyes)
	return hands


func test_aimed_through_an_optic_the_eye_sits_behind_its_glass() -> void:
	var cfg := ViewModelConfig.new()
	var hands := _hands(_kit(AEG, {&"optic": RED_DOT}))
	var held: ReplicaView.Held = hands._held[0]
	assert_not_null(held.window)
	var glass_z := -0.025 + float(cfg.optic_glass_z[&"redDot"])
	# Aimed, the model sits at (0, 0, aim_forward) - rear_sight: the glass optic_eye_back in front of the eye, on the line.
	var aimed := Vector3(0.0, 0.0, cfg.aim_forward[&"aeg"]) - held.rear_sight
	assert_almost_eq(aimed.y + 0.104, 0.0, EPS)
	assert_almost_eq(aimed.z + glass_z, -float(cfg.optic_eye_back[&"redDot"]), EPS)
	for mesh: Node in held.root.find_children("*", "GeometryInstance3D", true, false):
		assert_eq((mesh as GeometryInstance3D).layers, OpticGlass.HANDS_LAYER, "%s kept out of the glass" % mesh.name)


func test_without_an_optic_the_iron_sights_aim_as_before() -> void:
	var hands := _hands(_kit(AEG, {&"grip": VERTICAL}))
	var held: ReplicaView.Held = hands._held[0]
	assert_null(held.window)
	assert_almost_eq(held.rear_sight, Vector3(0.0, 0.0905, 0.0307), Vector3.ONE * EPS, "the lower, subtler sights (2026-11-05)")


func test_a_silenced_replica_shoots_from_the_silencer() -> void:
	var hands := _hands(_kit(AEG, {&"muzzle": SILENCER}))
	assert_eq(hands._held[0].muzzle.name, &"muzzle_silencer_Muzzle")


func test_the_glass_draws_only_while_the_sight_is_raised() -> void:
	var hands := _hands(_kit(AEG, {&"optic": SCOPE}))
	var held: ReplicaView.Held = hands._held[0]
	hands._show(0)
	var glass := hands._glass
	glass.update(held.window, 0.0)
	assert_false(held.window.disc.visible, "at the hip the optic shows as its model")
	assert_eq(glass._port.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	held.root.position = Vector3(0.0, 0.0, ViewModelConfig.new().aim_forward[&"aeg"]) - held.rear_sight
	glass.update(held.window, 1.0)
	assert_true(held.window.disc.visible)
	assert_eq(glass._port.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
	glass.update(null, 0.0)
	assert_eq(glass._port.render_target_update_mode, SubViewport.UPDATE_DISABLED)


func test_the_scope_magnifies_its_glass_and_the_red_dot_does_not() -> void:
	for optic: String in [SCOPE, RED_DOT]:
		var kit := _kit(AEG, {&"optic": optic})
		var r := kit.replicas[0]
		var view := ViewConfig.new()
		var hands := _hands(kit)
		var eyes := hands.get_parent() as Camera3D
		eyes.fov = view.vertical_fov(FirstPersonView.aimed_zoom(r, view))
		var held: ReplicaView.Held = hands._held[0]
		hands._show(0)
		held.root.position = Vector3(0.0, 0.0, ViewModelConfig.new().aim_forward[&"aeg"]) - held.rear_sight
		hands._glass.update(held.window, 1.0)
		var span: float = held.window.material.get_shader_parameter(&"span")
		var glass_tan := tan(deg_to_rad(hands._glass._camera.fov) * 0.5) / span
		var magnified := tan(deg_to_rad(eyes.fov) * 0.5) / glass_tan
		if optic == SCOPE:
			assert_almost_eq(magnified, 2.0 / view.aim_zoom, 1e-3, "2x against the unzoomed view, the view round it at 1.2x")
		else:
			assert_almost_eq(magnified, 1.0, 1e-3, "clear glass")
		var mark_uv: Vector2 = held.window.material.get_shader_parameter(&"mark_uv")
		assert_almost_eq(mark_uv, Vector2(0.5, 0.5), Vector2.ONE * 1e-3, "aimed, the mark sits where you look")


# --- zoom and sound ---

func test_a_scope_zooms_only_in_its_glass_and_a_red_dot_the_whole_view() -> void:
	var view := ViewConfig.new()
	var scope := _kit(AEG, {&"optic": SCOPE}).replicas[0]
	var dot := _kit(AEG, {&"optic": RED_DOT}).replicas[0]
	assert_true(scope.zoom_in_glass)
	assert_almost_eq(scope.aim_zoom, 2.0, EPS, "the Performance sheet still reads 2x")
	assert_almost_eq(FirstPersonView.aimed_zoom(scope, view), view.aim_zoom, EPS)
	assert_false(dot.zoom_in_glass)
	assert_almost_eq(FirstPersonView.aimed_zoom(dot, view), 1.25, EPS)
	assert_almost_eq(FirstPersonView.aimed_zoom(_kit(AEG, {}).replicas[0], view), view.aim_zoom, EPS)


func test_a_silenced_shot_plays_duller_and_quieter() -> void:
	var cfg := SoundConfig.new()
	# No level spread, so the level read is the muffled share exactly.
	cfg.shot_spread_db = 0.0
	var kit := _kit(AEG, {&"muzzle": SILENCER})
	var state := GameState.new(1)
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, kit.replicas, kit.bb_weights))
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(cfg, [kit.replicas[0].power] as Array[StringName], BodyConfig.new(), null, null)
	var bus := AudioServer.get_bus_index(SimAudio.BUS_MUFFLED)
	assert_eq(AudioServer.get_bus_send(bus), SimAudio.BUS_EFFECTS)
	assert_almost_eq((AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter).cutoff_hz, cfg.muffled_cutoff_hz,
			EPS)
	var e := state.events.add(GameEvent.Kind.SHOT)
	e.actor = 0
	e.slot = 0
	audio.on_tick(state, 0, null)
	var shot := audio._own[0]
	assert_eq(shot.bus, SimAudio.BUS_MUFFLED)
	assert_almost_eq(shot.volume_db, linear_to_db(cfg.shot_gain * cfg.muffled_gain), 0.01)
	assert_eq(audio._own[1].bus, SimAudio.BUS_POWER, "the motor sounds as it is")
	kit = _kit(AEG, {})
	state.characters[0] = Character.new(0, 0, Vector3.ZERO, 0.0, kit.replicas, kit.bb_weights)
	audio.on_tick(state, 0, null)
	assert_eq(audio._own[2].bus, SimAudio.BUS_EFFECTS)


func test_the_glass_is_readied_before_play_so_the_first_raise_does_not_hitch() -> void:
	var hands := _hands(_kit(AEG, {&"optic": SCOPE}))
	var warm := hands.prewarm_glass()
	assert_eq(warm.size(), 1)
	assert_eq(warm[0], hands._held[0].window.material)
	var glass := hands._glass
	assert_eq(glass._port.render_target_update_mode, SubViewport.UPDATE_ONCE)
	assert_gt(glass._port.size.x, 1)
	glass.update(hands._held[0].window, 0.0)
	assert_eq(glass._port.render_target_update_mode, SubViewport.UPDATE_ONCE, "the hip leaves the single draw to finish")
	assert_eq(_hands(_kit(AEG, {&"grip": VERTICAL})).prewarm_glass().size(), 0)


func test_the_sniper_rifles_iron_sights_hide_under_the_lowered_2x_scope() -> void:
	# The 2x sits low enough (BL8b, the owner's word) that the Sniper Rifle's rear leaf, standing, would meet its
	# eyepiece: fitting it must remove both sights.
	var model := _model("sniper")
	var fit := ReplicaParts.fit(model, &"sniper", {&"optic": &"scope2x"})
	assert_eq(fit.optic_key, &"scope2x")
	assert_false(_sight_shown(model, "rearSight"), "the rear leaf is gone")
	assert_false(_sight_shown(model, "frontSight"), "the front one too")
	ReplicaParts.unfit(fit)
