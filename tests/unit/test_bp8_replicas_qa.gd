extends GutTest
## BP8 replicas QA: the held bomb throw's edges (a hit, a slot, both keys, running out, a held button through the
## bring-to-hand, the replica after the throw) and the BB hide's edges (a bounced BB, a late BB, a bot's BB).

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.new()
var cfg: GrenadeConfig = tuning.grenades


func _match() -> Array:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 30.0)
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(Vector3(-10.0 if e == 0 else 10.0, 0.0, i * 2.0), 0.0))
			end.dead_zone.append(SpawnPoint.new(Vector3(-25.0 if e == 0 else 25.0, 0.0, 10.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var s := GameState.new(5, tuning)
	var loadout := ReplicaStats.default_loadout()
	for i in 2:
		s.characters.append(Character.new(i, i, Vector3.ZERO, 0.0, loadout))
	sim.start_match(s)
	var cmds: Array[PlayerCommand] = []
	for c in s.characters:
		var cmd := PlayerCommand.new()
		cmd.reset(c.yaw, c.pitch)
		cmds.append(cmd)
	return [sim, s, cmds]


func _run(sim: Simulation, s: GameState, cmds: Array[PlayerCommand], ticks: int) -> int:
	var n := 0
	for t in ticks:
		sim.step(s, cmds, DT)
		n += s.events.count_of(GameEvent.Kind.GRENADE_THROW)
		for cmd in cmds:
			cmd.throw_grenade = Grenade.Kind.NONE
			cmd.ready_grenade = Grenade.Kind.NONE
			cmd.switch_to = -1
			cmd.reload = false
	return n


func _cocked(m: Array, kind: Grenade.Kind = Grenade.Kind.SMOKE) -> void:
	var cmds: Array[PlayerCommand] = m[2]
	cmds[0].ready_grenade = kind
	_run(m[0], m[1], cmds, 3)
	cmds[0].fire = true
	_run(m[0], m[1], cmds, 60)
	assert_true(Grenades.throwing((m[1] as GameState).characters[0]), "cocked")


func test_a_hit_while_cocked_and_held_throws_nothing_and_keeps_the_bomb() -> void:
	var m := _match()
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	_cocked(m)
	var you := s.characters[0]
	var before := you.grenades.smoke
	Elimination.eliminate(you, 1, s.characters, (m[0] as Simulation).ends)
	assert_eq(_run(m[0], s, cmds, 60), 0, "no bomb leaves the hand of someone hit")
	assert_false(you.grenades.throw_held, "no hold left over")
	assert_eq(you.grenades.smoke, before, "the bomb is kept")


func test_a_slot_press_while_cocked_does_not_cancel_the_hold_or_throw_early() -> void:
	var m := _match()
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	_cocked(m)
	cmds[0].switch_to = 1
	assert_eq(_run(m[0], s, cmds, 30), 0, "still cocked")
	assert_true(Grenades.throwing(s.characters[0]))
	cmds[0].fire = false
	assert_eq(_run(m[0], s, cmds, 30), 1, "thrown on the release")


func test_the_other_bomb_key_while_cocked_changes_nothing() -> void:
	var m := _match()
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	_cocked(m)
	cmds[0].ready_grenade = Grenade.Kind.FLASH
	_run(m[0], s, cmds, 10)
	cmds[0].fire = false
	assert_eq(_run(m[0], s, cmds, 40), 1, "one throw, the smoke")
	assert_eq(s.characters[0].grenades.readied, Grenade.Kind.NONE)


func test_the_other_key_swaps_the_bomb_in_hand_and_a_click_throws_that_one() -> void:
	var m := _match()
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(m[0], s, cmds, 3)
	cmds[0].ready_grenade = Grenade.Kind.FLASH
	_run(m[0], s, cmds, 3)
	assert_eq(Grenades.in_hand(s.characters[0]), Grenade.Kind.FLASH)
	cmds[0].fire = true
	_run(m[0], s, cmds, 2)
	cmds[0].fire = false
	assert_eq(_run(m[0], s, cmds, 40), 1)
	assert_eq(s.characters[0].grenades.flash, s.characters[0].grenades.carried_flash - 1)


func test_a_button_held_through_the_bring_to_hand_throws_nothing_until_a_fresh_click() -> void:
	var m := _match()
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	cmds[0].fire = true
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	assert_eq(_run(m[0], s, cmds, 90), 0)
	assert_false(Grenades.throwing(s.characters[0]), "the held button is not a pull")
	cmds[0].fire = false
	assert_eq(_run(m[0], s, cmds, 30), 0)
	cmds[0].fire = true
	_run(m[0], s, cmds, 2)
	cmds[0].fire = false
	assert_eq(_run(m[0], s, cmds, 40), 1)


func test_a_pull_during_the_recovery_after_a_held_throw_fires_no_shot_while_the_bomb_leaves() -> void:
	var m := _match()
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	_cocked(m)
	var you := s.characters[0]
	cmds[0].fire = false
	assert_eq(_run(m[0], s, cmds, 8), 1, "thrown on the release")
	var shots := 0
	cmds[0].fire = true
	while Grenades.throwing(you):
		_run(m[0], s, cmds, 1)
		shots += s.events.count_of(GameEvent.Kind.SHOT)
	assert_false(you.grenades.throw_held, "no hold stays for the next bomb")
	assert_eq(shots, 0, "the replica is down until the throw ends")


func test_the_last_bomb_thrown_on_a_release_leaves_nothing_in_hand_and_the_next_key_is_refused() -> void:
	var m := _match()
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	var you := s.characters[0]
	you.grenades.smoke = 1
	_cocked(m)
	cmds[0].fire = false
	assert_eq(_run(m[0], s, cmds, 40), 1)
	assert_eq(you.grenades.smoke, 0)
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(m[0], s, cmds, 5)
	assert_eq(Grenades.in_hand(you), Grenade.Kind.NONE, "none left: nothing comes to hand")


func test_a_bot_with_a_bomb_press_and_fire_down_is_unaffected_by_the_hold() -> void:
	var m := _match()
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	cmds[1].fire = true
	for k in 2:
		cmds[1].throw_grenade = Grenade.Kind.FLASH if k % 2 == 0 else Grenade.Kind.SMOKE
		assert_eq(_run(m[0], s, cmds, ceili(cfg.windup / DT) + ceili(cfg.recover / DT) + 2), 1, "bot throw %d" % k)
	assert_false(s.characters[1].grenades.throw_held)


func test_your_bb_that_has_bounced_is_never_hidden_by_the_muzzle_rule() -> void:
	var ecfg := EffectsConfig.new()
	var bb := BB.new()
	bb.owner_id = 0
	bb.velocity = Vector3(0.0, 0.0, -50.0)
	bb.bounces = 1
	assert_false(BBView.before_muzzle(ecfg, bb, 0, Vector3(0, 0, 1.0), Vector3(0, 0, -1.0), 0.01))


func test_a_bb_past_the_join_time_is_shown_even_behind_a_moved_muzzle() -> void:
	var ecfg := EffectsConfig.new()
	var bb := BB.new()
	bb.owner_id = 0
	bb.velocity = Vector3(0.0, 0.0, -50.0)
	assert_false(BBView.before_muzzle(ecfg, bb, 0, Vector3(0, 0, 3.0), Vector3(0, 0, -1.0), ecfg.muzzle_join_time))


# --- laser fit and inspect, every replica ---

const AEG := "000002"
const PISTOL := "000001"
const SNIPER := "000021"
const CYBER := "000019"
const LASER := "000005"
const TORCH_ID := "000004"
var rules: LoadoutRules


func _rules() -> LoadoutRules:
	return LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())


func test_the_sniper_and_the_cyber_pistol_refuse_the_laser_through_the_loadout_rules() -> void:
	rules = _rules()
	var l := rules.default_loadout("Test")
	for id: String in [SNIPER, CYBER]:
		if l.equipped[0] != id:
			rules.equip(l, 0 as Loadout.Slot, id)
		assert_false(rules.set_part(l, id, &"laser", LASER), "%s has no rail for it" % id)


func test_the_aeg_holds_the_laser_and_writes_it_to_the_save() -> void:
	rules = _rules()
	var l := rules.default_loadout("Test")
	if l.equipped[0] != AEG:
		rules.equip(l, 0 as Loadout.Slot, AEG)
	assert_true(rules.set_part(l, AEG, &"laser", LASER))
	var saved := l.to_dict()
	assert_true(JSON.stringify(saved).contains(LASER), "the laser is written to the save")
	assert_eq(rules.carried(l).parts[0].get(&"laser"), &"redLaser")


func test_every_replicas_inspect_turns_the_muzzle_to_the_left() -> void:
	rules = _rules()
	for id: String in [AEG, PISTOL, SNIPER, CYBER]:
		var l := rules.default_loadout("Test")
		if l.equipped[0] != id:
			rules.equip(l, 0 as Loadout.Slot, id)
		var kit := rules.carried(l)
		var eyes := Camera3D.new()
		add_child_autofree(eyes)
		var hands := ReplicaView.new()
		eyes.add_child(hands)
		hands.setup(ViewModelConfig.new(), kit.replicas, null, kit.paints, false, kit.parts, ViewConfig.new(), eyes)
		var c := Character.new(0, 0, Vector3.ZERO, 0.0, kit.replicas)
		hands._query = BoxWorld.new()
		hands.update(c, 0.0, 0.0, Vector3.ZERO, Vector3.FORWARD, DT, 0.0)
		hands.inspect()
		var held: ReplicaView.Held = hands._held[0]
		var pose: InspectPose = ViewModelConfig.new().inspect_poses[held.id]
		for i in roundi(pose.duration * 0.5 / DT):
			hands.update(c, 0.0, 0.0, Vector3.ZERO, Vector3.FORWARD, DT, 0.0)
		var muzzle := hands.to_local(held.muzzle.global_position)
		assert_lt(muzzle.x, held.root.position.x - 0.03, "%s: muzzle left of the hold" % id)


# --- 10: the hip glass's edges (a second look: presets, closeness, the eye's own settings, leaving play) ---

const SCOPE := "000010"
const RED_DOT := "000007"
const HIP_AT := Vector3(0.13, -0.16, -0.32)


func _scope_hands(optic: String = SCOPE, parent: Node = null) -> ReplicaView:
	rules = _rules()
	var l := rules.default_loadout("Test")
	if l.equipped[0] != AEG:
		rules.equip(l, 0 as Loadout.Slot, AEG)
	assert_true(rules.set_part(l, AEG, &"optic", optic))
	var kit := rules.carried(l)
	var eyes := Camera3D.new()
	if parent == null:
		add_child_autofree(eyes)
	else:
		parent.add_child(eyes)
	var hands := ReplicaView.new()
	eyes.add_child(hands)
	hands.setup(ViewModelConfig.new(), kit.replicas, null, kit.paints, false, kit.parts, ViewConfig.new(), eyes)
	hands._show(0)
	(hands._held[0] as ReplicaView.Held).root.position = HIP_AT
	return hands


func test_switching_presets_at_the_hip_follows_each_time_and_stays_one_connection() -> void:
	var hands := _scope_hands()
	var held: ReplicaView.Held = hands._held[0]
	var glass := hands._glass
	var table := GraphicsTable.shared()
	var graphics := GraphicsApply.server()
	var connected := graphics.applied.get_connections().size()
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for _round in 3:
		for preset: StringName in [&"low", &"high", &"medium", &"low", &"high"]:
			glass._follow(table.preset(preset))
			glass.update(held.window, 0.0)
			var cam: bool = table.preset(preset).mesh_detail >= ViewModelConfig.new().hip_glass_camera_from
			assert_eq(held.window.hip_material.get_shader_parameter(&"see_through"), cam, "%s" % preset)
			assert_eq(glass._port.render_target_update_mode == SubViewport.UPDATE_ALWAYS, cam, "%s" % preset)
			assert_true(held.window.disc.visible, "%s: the glass shows either way" % preset)
	assert_eq(graphics.applied.get_connections().size(), connected, "no connection added by a change")
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no node added by a change")
	glass.update(null, 0.0)


func test_a_preset_change_while_aimed_keeps_the_sight_and_the_copied_environment_is_redone() -> void:
	var hands := _scope_hands()
	var held: ReplicaView.Held = hands._held[0]
	var glass := hands._glass
	held.root.position = Vector3(0.0, 0.0, ViewModelConfig.new().aim_forward[&"aeg"]) - held.rear_sight
	glass.update(held.window, 1.0)
	var low := GraphicsTable.shared().preset(&"low")
	glass._follow(low)
	glass.update(held.window, 1.0)
	assert_eq(glass._port.render_target_update_mode, SubViewport.UPDATE_ALWAYS, "aimed on Low still draws")
	assert_eq(held.window.disc.material_override, held.window.material)
	assert_eq(glass._port.msaa_3d, GraphicsApply.EDGE_MSAA[low.edge_smoothing], "edge smoothing followed")
	assert_almost_eq(glass._port.scaling_3d_scale, low.render_scale / GraphicsApply.PERCENT, 1e-5, "and scale")
	if glass._env_aimed != null:
		assert_true(glass._env_ready)
	glass.update(null, 0.0)


func test_aimed_after_the_hip_the_camera_is_perspective_again_with_the_views_own_near_and_far() -> void:
	var hands := _scope_hands()
	var held: ReplicaView.Held = hands._held[0]
	var glass := hands._glass
	glass.update(held.window, 0.0)
	assert_eq(glass._camera.projection, Camera3D.PROJECTION_PERSPECTIVE, "the hip glass looks down the axis (SG1)")
	held.root.position = Vector3(0.0, 0.0, ViewModelConfig.new().aim_forward[&"aeg"]) - held.rear_sight
	glass.update(held.window, 1.0)
	assert_eq(glass._camera.projection, Camera3D.PROJECTION_PERSPECTIVE)
	assert_almost_eq(glass._camera.near, glass._eyes.near, 1e-6, "the glass sees what the eye sees: near")
	assert_almost_eq(glass._camera.far, glass._eyes.far, 1e-3, "and far")
	glass.update(null, 0.0)


func test_a_scope_pulled_close_to_the_eye_still_has_its_whole_disc_in_the_picture() -> void:
	# A wall pulls the replica back toward the eye (pull_back_max): the disc grows on screen, and the picture, capped
	# at glass_share, must not end short of its rim (the edge pixel would smear across the lens).
	var hands := _scope_hands()
	var held: ReplicaView.Held = hands._held[0]
	var glass := hands._glass
	var cfg := ViewModelConfig.new()
	for pulled: float in [0.1, 0.2, cfg.pull_back_max]:
		held.root.position = HIP_AT + Vector3(0.0, 0.0, pulled)
		glass.update(held.window, 0.0)
		if not held.window.disc.visible:
			continue
		var m := held.window.hip_material
		var span: float = m.get_shader_parameter(&"span")
		var screen := glass._eyes.get_viewport().get_visible_rect().size
		var centre_px: Vector2 = (m.get_shader_parameter(&"centre_uv") as Vector2) * screen
		var reach := glass._rim_reach(held.window, centre_px)
		assert_lte(reach, span * screen.y * 0.5 + 0.5, "pulled %s: the rim lies inside the picture" % pulled)
	glass.update(null, 0.0)


func test_a_disc_behind_the_eye_or_off_screen_leaves_finite_values_and_no_drawing() -> void:
	var hands := _scope_hands()
	var held: ReplicaView.Held = hands._held[0]
	var glass := hands._glass
	for at: Vector3 in [Vector3(0.13, -0.16, 0.5), Vector3(4.0, 0.0, -0.3), Vector3(0.0, -6.0, -0.3),
			Vector3(0.13, -0.16, -0.06)]:
		held.root.position = at
		glass.update(held.window, 0.0)
		if at.z > 0.0:
			assert_false(held.window.disc.visible, "behind the eye: hidden")
			assert_ne(glass._port.render_target_update_mode, SubViewport.UPDATE_ALWAYS, "and not drawn")
			continue
		var m := held.window.hip_material
		var span: float = m.get_shader_parameter(&"span")
		assert_true(is_finite(span) and span > 0.0 and span <= ViewModelConfig.new().glass_share, "%s span" % at)
		var uv: Vector2 = m.get_shader_parameter(&"centre_uv")
		assert_true(is_finite(uv.x) and is_finite(uv.y), "%s centre" % at)
		var o := glass._camera.get_camera_projection()
		for i in 4:
			assert_true(is_finite(o[i].x) and is_finite(o[i].y) and is_finite(o[i].z), "%s projection" % at)
	glass.update(null, 0.0)


func test_a_wide_eye_that_keeps_its_width_still_shows_the_glass_at_the_views_own_scale() -> void:
	var host := SubViewport.new()
	host.size = Vector2i(1280, 540)
	add_child_autofree(host)
	var hands := _scope_hands(SCOPE, host)
	var held: ReplicaView.Held = hands._held[0]
	var glass := hands._glass
	var eyes := glass._eyes
	for keep: Camera3D.KeepAspect in [Camera3D.KEEP_HEIGHT, Camera3D.KEEP_WIDTH]:
		eyes.keep_aspect = keep
		for at: Vector3 in [HIP_AT, Vector3(-0.25, 0.1, -0.35)]:
			held.root.position = at
			glass.update(held.window, 0.0)
			var m := held.window.hip_material
			var screen := host.get_visible_rect().size
			assert_almost_eq(float(m.get_shader_parameter(&"aspect")), screen.x / screen.y, 1e-4, "aspect of this window")
			var span: float = m.get_shader_parameter(&"span")
			# The eye's own vertical reach (its projection's), so a thing shows on the glass as big as round it.
			var eye_tan := 1.0 / eyes.get_camera_projection().y.y
			var glass_tan := 1.0 / glass._camera.get_camera_projection().y.y
			assert_almost_eq(glass_tan, span * eye_tan, 1e-4, "%s %s: the main view's own scale" % [keep, at])
	glass.update(null, 0.0)


func test_a_resize_refits_the_picture_and_the_aspect_with_no_node_added() -> void:
	var host := SubViewport.new()
	host.size = Vector2i(1280, 720)
	add_child_autofree(host)
	var hands := _scope_hands(SCOPE, host)
	var held: ReplicaView.Held = hands._held[0]
	var glass := hands._glass
	glass.update(held.window, 0.0)
	var side := glass._port.size
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	host.size = Vector2i(640, 1000)
	glass.update(held.window, 0.0)
	assert_ne(glass._port.size, side, "the picture follows the window's height")
	assert_almost_eq(float(held.window.hip_material.get_shader_parameter(&"aspect")), 0.64, 1e-4)
	assert_eq(glass._port.size.x, glass._port.size.y, "still square")
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes)
	glass.update(null, 0.0)


func test_leaving_play_stops_the_glass_camera_from_the_hip() -> void:
	var hands := _scope_hands()
	var held: ReplicaView.Held = hands._held[0]
	var glass := hands._glass
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, rules.carried(rules.default_loadout("Test")).replicas)
	hands._query = BoxWorld.new()
	c.armament.zooms[0] = held.window.magnify
	hands.update(c, 0.0, 0.0, Vector3.ZERO, Vector3.FORWARD, DT, 0.0)
	assert_eq(glass._port.render_target_update_mode, SubViewport.UPDATE_ALWAYS, "drawing in hand")
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	c.armament.replicas.clear()
	hands.update(c, 0.0, 0.0, Vector3.ZERO, Vector3.FORWARD, DT, 0.0)
	assert_ne(glass._port.render_target_update_mode, SubViewport.UPDATE_ALWAYS, "no replica: no camera")
	assert_null(glass.drawing_camera())
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "nothing made or left")


func test_swapping_to_a_replica_without_a_scope_stops_the_glass_camera() -> void:
	var hands := _scope_hands()
	var held: ReplicaView.Held = hands._held[0]
	var glass := hands._glass
	glass.update(held.window, 0.0)
	assert_eq(glass._port.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
	glass.update(null, 0.0)
	assert_ne(glass._port.render_target_update_mode, SubViewport.UPDATE_ALWAYS, "no glass in hand: no camera")
	assert_false(glass._at_hip)
	held.root.visible = false
	glass.update(held.window, 0.0)
	assert_ne(glass._port.render_target_update_mode, SubViewport.UPDATE_ALWAYS, "a hidden model draws nothing")
	assert_false(held.window.disc.visible)


func test_a_red_dot_at_the_hip_never_starts_the_glass_camera_and_aimed_draws_clear() -> void:
	var hands := _scope_hands(RED_DOT)
	var held: ReplicaView.Held = hands._held[0]
	var glass := hands._glass
	glass.update(held.window, 0.0)
	assert_ne(glass._port.render_target_update_mode, SubViewport.UPDATE_ALWAYS, "a dot's own glass: no camera")
	assert_false(glass._at_hip)
	held.root.position = Vector3(0.0, 0.0, ViewModelConfig.new().aim_forward[&"aeg"]) - held.rear_sight
	glass.update(held.window, 1.0)
	assert_eq(glass._port.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
	assert_eq(glass._camera.projection, Camera3D.PROJECTION_PERSPECTIVE)
	assert_eq(glass.drawing_camera(), glass._camera)
	glass.update(held.window, 0.0)
	assert_null(glass.drawing_camera(), "back at the hip: no zoomed detail source")
	glass.update(null, 0.0)


func test_every_camera_but_the_glass_sees_the_probes() -> void:
	var probe_layers := AreaProbes.LAYER
	assert_eq(probe_layers & OpticGlass.HANDS_LAYER, 0, "not the hands' layer")
	assert_eq(probe_layers & 1, 0, "not the default layer (collision-free visuals stay as they were)")
	assert_true(probe_layers & ((1 << 20) - 1) != 0, "within Godot's 20 layers")
	assert_true((autofree(Camera3D.new()) as Camera3D).cull_mask & probe_layers != 0, "a default camera sees them")
