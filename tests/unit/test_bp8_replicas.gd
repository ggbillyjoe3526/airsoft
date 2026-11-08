extends GutTest
## BP8, the replicas area of William's Dev 2 playtest: the AEG takes the laser (4), inspect turns the muzzle left (5),
## a bomb in hand is thrown only by a click or on letting go of a held one (8), a scope's glass is plain glass at the
## hip (10), your own BBs show only from the muzzle on (12) and the Variable Scope is plain on top (26).

const DT := 1.0 / 60.0
const AEG := "000002"
const PISTOL := "000001"
const SNIPER := "000021"
const LASER := "000005"
const SCOPE := "000010"
const RED_DOT := "000007"
const PARTS := "res://assets/models/replicaParts/%s.glb"
const EPS := 1e-4
## The AEG held: its left hand's thumb grips from here forward, and its delta ring ends here (model space, -Z forward).
const LEFT_THUMB_Z := -0.198
const AEG_DELTA_RING_Z := -0.119

var tuning: SimTuning = SimTuning.new()
var cfg: GrenadeConfig = tuning.grenades
var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())


func _ids(items: Array[Pool.Item]) -> Array[String]:
	var out: Array[String] = []
	for it in items:
		out.append(it.id)
	return out


func _kit(id: String, parts: Dictionary, slot: int = 0) -> Kit:
	var l := rules.default_loadout("Test")
	if l.equipped[slot] != id:
		rules.equip(l, slot as Loadout.Slot, id)
	for part_slot: StringName in parts:
		assert_true(rules.set_part(l, id, part_slot, parts[part_slot]), "%s takes %s" % [id, parts[part_slot]])
	return rules.carried(l)


func _model(key: String) -> Node3D:
	var model := (load("res://assets/models/replicas/%s.glb" % key) as PackedScene).instantiate() as Node3D
	add_child_autofree(model)
	return model


func _hands(kit: Kit) -> ReplicaView:
	var eyes := Camera3D.new()
	add_child_autofree(eyes)
	var hands := ReplicaView.new()
	eyes.add_child(hands)
	hands.setup(ViewModelConfig.new(), kit.replicas, null, kit.paints, false, kit.parts, ViewConfig.new(), eyes)
	return hands


# --- 4: the AEG's laser ---

func test_the_aeg_takes_the_red_laser_and_the_sniper_and_cyber_still_do_not() -> void:
	var pool := rules.pool
	assert_eq(_ids(pool.parts_for(pool.item(AEG), &"laser", false)), [LASER] as Array[String])
	assert_eq(_ids(pool.parts_for(pool.item(SNIPER), &"laser", false)), [] as Array[String])
	assert_eq(_ids(pool.parts_for(pool.item(PISTOL), &"laser", false)), [LASER] as Array[String])
	var kit := _kit(AEG, {&"laser": LASER})
	assert_eq(kit.parts[0].get(&"laser"), &"redLaser")
	assert_lt(kit.replicas[0].spread_deg, rules.config(pool.item(AEG)).spread_deg, "it tightens the AEG's spread")


func test_the_aegs_laser_sits_on_the_handguards_left_rail_behind_the_hand() -> void:
	var root := (load(PARTS % "aeg") as PackedScene).instantiate() as Node3D
	add_child_autofree(root)
	var laser := root.get_node_or_null("laser_redLaser") as MeshInstance3D
	assert_not_null(laser, "the AEG's parts file carries the laser")
	if laser == null:
		return
	var torch := root.get_node("light_weaponTorch") as Node3D
	assert_almost_eq(laser.position.x, -torch.position.x, EPS, "the torch's rail mirrored across the bore")
	assert_almost_eq(laser.position.y, torch.position.y, EPS, "at the torch's height")
	var box := laser.get_aabb()
	assert_lt(box.get_center().x, -0.005, "it stands out to the left of its mount")
	assert_lt(box.position.x, -0.015, "well out to the left")
	assert_gt(laser.position.z + box.position.z, LEFT_THUMB_Z, "its front clear of the left hand's thumb")
	assert_lt(laser.position.z + box.end.z, AEG_DELTA_RING_Z, "its back ahead of the delta ring")
	var beam := laser.get_node("laser_redLaser_Beam") as Node3D
	assert_lt(beam.position.z, -0.02, "its emitter faces forward")
	assert_lt(laser.mesh.get_faces().size() / 3, 10000, "within a part's budget")
	var sniper := (load(PARTS % "sniper") as PackedScene).instantiate()
	add_child_autofree(sniper)
	assert_null(sniper.get_node_or_null("laser_redLaser"), "the sniper's parts file leaves the AEG's laser out")


func test_the_laser_and_the_torch_each_keep_their_own_rail() -> void:
	var model := _model("aeg")
	var alone := ReplicaParts.fit(model, &"aeg", {&"laser": &"redLaser"})
	var laser := model.find_child("laser_redLaser", false, false) as Node3D
	assert_lt(laser.position.x, -0.02, "alone on the left rail")
	ReplicaParts.unfit(alone)
	var both := ReplicaParts.fit(model, &"aeg", {&"laser": &"redLaser", &"light": &"weaponTorch"})
	laser = model.find_child("laser_redLaser", false, false) as Node3D
	var torch := model.find_child("light_weaponTorch", false, false) as Node3D
	assert_gt(torch.position.x, 0.02, "the torch on the right rail")
	assert_lt(laser.position.x, -0.02, "the laser still on the left one")
	var beam := laser.get_node("laser_redLaser_Beam") as Node3D
	assert_lt(beam.global_position.z, laser.global_position.z, "its emitter faces forward")
	ReplicaParts.unfit(both)


func test_a_figures_laser_copy_is_on_the_left_rail_too() -> void:
	var held := Node3D.new()
	add_child_autofree(held)
	var f := ReplicaParts.fit_figure(held, &"aeg", {&"laser": &"redLaser", &"light": &"weaponTorch"}, Vector3.ZERO,
			Vector3.ZERO)
	assert_not_null(f.light)
	var laser := held.get_node_or_null("laser_redLaser_Figure") as Node3D
	assert_not_null(laser, "the laser's copy fitted")
	if laser != null and f.light != null:
		assert_lt(laser.position.x, -0.02, "the copy on the left rail")
		assert_gt(f.light.position.x, 0.02, "the torch's copy on the right")


# --- 5: inspect ---

func test_an_inspect_turns_the_muzzle_to_the_left_of_the_view() -> void:
	for id: String in [AEG, PISTOL]:
		var kit := _kit(id, {}, 0)
		var hands := _hands(kit)
		var c := Character.new(0, 0, Vector3.ZERO, 0.0, kit.replicas)
		var w := BoxWorld.new()
		hands._query = w
		hands.update(c, 0.0, 0.0, Vector3.ZERO, Vector3.FORWARD, DT, 0.0)
		hands.inspect()
		var held: ReplicaView.Held = hands._held[0]
		var pose: InspectPose = ViewModelConfig.new().inspect_poses[held.id]
		for i in roundi(pose.duration * 0.5 / DT):
			hands.update(c, 0.0, 0.0, Vector3.ZERO, Vector3.FORWARD, DT, 0.0)
		var muzzle := hands.to_local(held.muzzle.global_position)
		assert_lt(muzzle.x, held.root.position.x - 0.03, "%s: its muzzle left of where it is held" % id)


# --- 8: a bomb in hand ---

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


## Steps `ticks` ticks, counting GRENADE_THROW events; one-shot presses cleared after the first.
func _run(sim: Simulation, s: GameState, cmds: Array[PlayerCommand], ticks: int) -> int:
	var n := 0
	for t in ticks:
		sim.step(s, cmds, DT)
		n += s.events.count_of(GameEvent.Kind.GRENADE_THROW)
		for cmd in cmds:
			cmd.throw_grenade = Grenade.Kind.NONE
			cmd.ready_grenade = Grenade.Kind.NONE
	return n


func _ready_smoke(sim: Simulation, s: GameState, cmds: Array[PlayerCommand]) -> void:
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	assert_eq(_run(sim, s, cmds, 3), 0, "taken in hand, not thrown")
	assert_eq(Grenades.in_hand(s.characters[0]), Grenade.Kind.SMOKE)


func test_a_bomb_taken_in_hand_waits_there_until_a_click() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	_ready_smoke(sim, s, cmds)
	assert_eq(_run(sim, s, cmds, 120), 0, "two seconds in hand: still not thrown")
	cmds[0].fire = true
	assert_eq(_run(sim, s, cmds, 1), 0)
	cmds[0].fire = false
	assert_eq(_run(sim, s, cmds, ceili(cfg.windup / DT) + 1), 1, "a click throws it after the windup, as before")


func test_a_held_click_keeps_the_arm_cocked_until_let_go() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	var c := s.characters[0]
	_ready_smoke(sim, s, cmds)
	cmds[0].fire = true
	assert_eq(_run(sim, s, cmds, 90), 0, "held 1.5 s: still in hand")
	assert_true(Grenades.throwing(c))
	assert_false(c.grenades.released)
	assert_almost_eq(1.0 - c.grenades.windup_left / cfg.windup, cfg.hold_at, EPS, "waiting cocked at hold_at")
	cmds[0].fire = false
	var rest := ceili(cfg.windup * (1.0 - cfg.hold_at) / DT) + 1
	assert_eq(_run(sim, s, cmds, rest), 1, "let go: it leaves the hand the rest of the windup on")


func test_the_cocked_hold_matches_the_arms_cocked_key() -> void:
	assert_almost_eq(cfg.hold_at, ViewModelConfig.new().bomb_cock, EPS, "your arm waits where it is cocked back")


func test_a_press_without_a_bomb_in_hand_never_waits_even_with_the_trigger_held() -> void:
	# A bot's throw (and the range's) is a press: the trigger has nothing to do with it.
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	cmds[1].fire = true
	cmds[1].throw_grenade = Grenade.Kind.FLASH
	assert_eq(_run(sim, s, cmds, ceili(cfg.windup / DT) + 1), 1)


func test_the_throw_keys_take_the_bomb_in_hand_and_never_throw() -> void:
	var input := PlayerInput.new()
	input.setup(ControlsConfig.new(), 1.5)
	add_child_autofree(input)
	input.active = true
	var e := InputEventAction.new()
	e.action = &"throw_flash"
	e.pressed = true
	input._unhandled_input(e)
	var cmd := PlayerCommand.new()
	input.fill(cmd)
	assert_eq(cmd.ready_grenade, Grenade.Kind.FLASH)
	assert_eq(cmd.throw_grenade, Grenade.Kind.NONE)


# --- 10: a scope's glass at the hip ---

func test_at_the_hip_a_scopes_glass_is_plain_glass_and_aimed_it_is_the_sight() -> void:
	var kit := _kit(AEG, {&"optic": SCOPE})
	var hands := _hands(kit)
	var held: ReplicaView.Held = hands._held[0]
	hands._show(0)
	held.root.position = Vector3(0.13, -0.16, -0.32)
	hands._glass.update(held.window, 0.0)
	assert_true(held.window.disc.visible, "the glass shows at the hip")
	assert_not_null(held.window.hip_material, "a scope has a hip glass")
	assert_eq(held.window.disc.material_override, held.window.hip_material, "as plain glass, its own material")
	assert_eq((held.window.hip_material.shader as Shader).resource_path, "res://game/play/optic_glass_hip.gdshader")
	assert_eq(hands._glass._port.render_target_update_mode, SubViewport.UPDATE_DISABLED, "no second camera drawing")
	held.root.position = Vector3(0.0, 0.0, ViewModelConfig.new().aim_forward[&"aeg"]) - held.rear_sight
	hands._glass.update(held.window, 1.0)
	assert_eq(held.window.disc.material_override, held.window.material, "aimed: the magnified sight's material")
	assert_eq(hands._glass._port.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
	held.root.position = Vector3(0.13, -0.16, -0.32)
	hands._glass.update(held.window, 0.0)
	assert_eq(held.window.disc.material_override, held.window.hip_material, "back at the hip: the hip glass again")
	hands._glass.update(null, 0.0)


func test_only_the_hip_glass_samples_the_screen_and_both_are_prewarmed() -> void:
	# Performance (BP8): the screen copy hint_screen_texture takes is paid only while a scope is at the hip.
	assert_false(OpticGlass.SHADER.code.contains("hint_screen_texture"), "the sight's glass takes no screen copy")
	assert_true(OpticGlass.HIP_SHADER.code.contains("hint_screen_texture"))
	var scope := _hands(_kit(AEG, {&"optic": SCOPE}))
	var warmed := scope.prewarm_glass()
	var held: ReplicaView.Held = scope._held[0]
	assert_true(warmed.has(held.window.material), "the sight's glass warmed")
	assert_true(warmed.has(held.window.hip_material), "and its hip glass, so its first use doesn't hitch")
	var dot := _hands(_kit(AEG, {&"optic": RED_DOT}))
	assert_null((dot._held[0] as ReplicaView.Held).window.hip_material, "a red dot has no hip glass")
	assert_eq(dot.prewarm_glass().size(), 1)


func test_a_red_dot_draws_no_glass_at_the_hip() -> void:
	var hands := _hands(_kit(AEG, {&"optic": RED_DOT}))
	var held: ReplicaView.Held = hands._held[0]
	hands._show(0)
	held.root.position = Vector3(0.13, -0.16, -0.32)
	hands._glass.update(held.window, 0.0)
	assert_false(held.window.disc.visible, "its model's own clear glass")
	assert_false(OpticGlass.hip_glass(held.window, 0.0))
	assert_false(OpticGlass.hip_glass(null, 0.0))


# --- 12: your BBs from the muzzle on ---

func _bb(owner: int, from: Vector3, flown: float) -> BB:
	var pool := BBPool.new(1)
	var bb := pool.spawn(owner, from, Vector3.FORWARD, 90.0, 0.0, 0.00025, 0.0)
	bb.position = from + Vector3.FORWARD * flown
	bb.prev_position = bb.position
	bb.age = flown / 90.0
	return bb


func test_your_bb_is_hidden_until_it_passes_the_muzzle() -> void:
	var fx := EffectsConfig.new()
	var muzzle := Vector3(0.0, -0.01, -0.42)
	var behind := _bb(0, Vector3.ZERO, 0.2)
	assert_true(BBView.before_muzzle(fx, behind, 0, behind.position, muzzle, behind.age), "between the eye and muzzle")
	var past := _bb(0, Vector3.ZERO, 0.6)
	assert_false(BBView.before_muzzle(fx, past, 0, past.position, muzzle, past.age), "past the muzzle")
	assert_false(BBView.before_muzzle(fx, behind, 1, behind.position, muzzle, behind.age), "a bot's BB: as before")
	behind.bounces = 1
	assert_false(BBView.before_muzzle(fx, behind, 0, behind.position, muzzle, behind.age), "a bounced one comes back")
	behind.bounces = 0
	assert_false(BBView.before_muzzle(fx, behind, 0, behind.position, muzzle, fx.muzzle_join_time), "long flown")


func test_your_bb_beside_a_pistol_after_a_turn_is_not_drawn() -> void:
	# The view turned 4 degrees since the tick the BB left the eye: it would show beside the slide, behind the muzzle.
	var fx := EffectsConfig.new()
	var view := BBView.new()
	view.setup(fx, 2)
	add_child_autofree(view)
	var pool := BBPool.new(2)
	var dir := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(4.0))
	var mine := pool.spawn(0, Vector3.ZERO, dir, 90.0, 0.0, 0.00025, 0.0)
	mine.prev_position = Vector3.ZERO
	mine.position = dir * 1.5
	var theirs := pool.spawn(1, Vector3(0.0, 0.0, -2.0), Vector3.BACK, 90.0, 0.0, 0.00025, 0.0)
	theirs.prev_position = theirs.position
	view.update(pool, 0, Vector3(0.0, 0.0, -0.42), 0.1, DT, Vector3.ZERO)
	assert_eq(view.multimesh.visible_instance_count, 1, "only the bot's BB: yours is still short of the muzzle")
	view.update(pool, 0, Vector3(0.0, 0.0, -0.42), 0.5, DT, Vector3.ZERO)
	assert_eq(view.multimesh.visible_instance_count, 2, "yours shows once past it")


# --- 26: the Variable Scope, plain on top ---

func test_the_variable_scope_has_no_sights_or_rails_on_top_and_a_small_dial() -> void:
	for file: String in ["aeg", "sniper"]:
		var root := (load(PARTS % file) as PackedScene).instantiate() as Node3D
		add_child_autofree(root)
		var m := root.get_node("optic_scopeVar") as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(i)
			assert_ne(mat.resource_name if mat != null else "", "Fibre", "%s: no fibre front sight" % file)
		var line := (m.get_node("optic_scopeVar_SightLine") as Node3D).position
		# Behind the objective housing (z over -0.02, its front 30 mm ahead of the clamp), over the turret housing's top
		# (16 mm over the axis, shrunk 0.9), stands only the one dial: its top low, its width small.
		var top := -INF
		var x_lo := INF
		var x_hi := -INF
		var faces := m.mesh.get_faces()
		for v in faces:
			if v.y > line.y + 0.0165 and v.z > -0.02:
				top = maxf(top, v.y)
				x_lo = minf(x_lo, v.x)
				x_hi = maxf(x_hi, v.x)
		assert_lt(top - line.y, 0.024, "%s: nothing tall over the axis (the rear sight stood 33 mm over it)" % file)
		assert_lt(x_hi - x_lo, 0.018, "%s: one small dial on top (the old one was 24 mm across)" % file)
