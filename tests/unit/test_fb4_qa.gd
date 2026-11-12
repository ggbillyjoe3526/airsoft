extends GutTest
## QA hunt for FB4 (the owner's 0.1 Dev 1 playtest, notes 5, 7, 11, 12): the raise on the run across a reload, a switch
## and the holster; the holstered sprint in every stance; the pressed depth on every surface the hands can wear (parts,
## Realistic colours, the scope's glass) and freed with the view; the BB's drawn place at any muzzle offset, a full
## pool, a stopped or bounced BB.

const DT := 1.0 / 60.0
const SETTLE := 90
const EPS := 1e-4
## Frames between shots on full auto (about 10 a second).
const SHOT_EVERY := 6
const AEG := "000002"
const PISTOL := "000001"
const CYBER := "000019"
const SCOPE := "000010"
const LASER := "000005"
const EXTENDED := "000014"
const LONG := "000017"
const SILENCER := "000018"
const SPEED := 90.0
const MASS := 0.25e-3

var cfg: ViewModelConfig = null
var rules: LoadoutRules = null


func before_each() -> void:
	cfg = ViewModelConfig.new()
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())


func _character(active: int = 0) -> Character:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.armament.active = active
	return c


func _hands(c: Character) -> ReplicaView:
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(cfg, c.armament.replicas, BoxWorld.new())
	return hands


func _frames(hands: ReplicaView, c: Character, n: int) -> void:
	for i in n:
		hands.update(c, 0.0, 0.0, Vector3(0.0, 1.6, 0.0), Vector3.FORWARD, DT, c.aim_raise)


func _pose(hands: ReplicaView, c: Character) -> Transform3D:
	return hands._held[c.armament.active].root.transform


func _kit(id: String, parts: Dictionary, slot: int = 0) -> Kit:
	var l := rules.default_loadout("Test")
	if l.equipped[slot] != id:
		rules.equip(l, slot as Loadout.Slot, id)
	for part_slot: StringName in parts:
		rules.set_part(l, id, part_slot, parts[part_slot])
	return rules.carried(l)


func _kit_hands(kit: Kit, realistic: bool = false) -> ReplicaView:
	var eyes := Camera3D.new()
	add_child_autofree(eyes)
	var hands := ReplicaView.new()
	eyes.add_child(hands)
	hands.setup(cfg, kit.replicas, BoxWorld.new(), kit.paints, realistic, kit.parts, ViewConfig.new(), eyes)
	return hands


func _finite(t: Transform3D) -> bool:
	return t.origin.is_finite() and t.basis.x.is_finite() and t.basis.y.is_finite() and t.basis.z.is_finite()


# --- the raise on the run ---

func test_a_trigger_held_while_holstered_does_not_raise_the_sprint_carry() -> void:
	var c := _character()
	c.sprinting = true
	c.armament.holstered = true
	var plain := _hands(c)
	_frames(plain, c, SETTLE)
	var rest := _pose(plain, c)
	var c2 := _character()
	c2.sprinting = true
	c2.armament.holstered = true
	c2.armament.trigger_was_down = true
	var held := _hands(c2)
	_frames(held, c2, SETTLE)
	assert_almost_eq(_pose(held, c2).origin, rest.origin, Vector3.ONE * EPS, "put away, a held trigger lifts nothing")
	assert_almost_eq(_pose(held, c2).basis.get_euler(), rest.basis.get_euler(), Vector3.ONE * EPS)


func test_the_raise_across_a_reload_a_switch_and_the_holster_stays_finite_and_comes_to_rest() -> void:
	var c := _character()
	var a := c.armament
	var hands := _hands(c)
	c.sprinting = true
	a.trigger_was_down = true
	_frames(hands, c, 20)
	# A reload while the trigger is held on a sprint, a shot in the middle of it.
	a.reload_left = 1.0
	for i in 60:
		a.reload_left = maxf(0.0, a.reload_left - DT)
		if i == 30:
			hands.on_shot()
		_frames(hands, c, 1)
		assert_true(_finite(_pose(hands, c)), "reload frame %d" % i)
	# A switch mid-sprint with a shot on the way.
	a.active = 1
	a.draw_total = 0.4
	a.draw_left = 0.4
	for i in 30:
		a.draw_left = maxf(0.0, a.draw_left - DT)
		if i == 10:
			hands.on_shot()
		_frames(hands, c, 1)
		assert_true(_finite(_pose(hands, c)), "switch frame %d" % i)
	# Holstered mid-sprint, the trigger still down, then drawn again by it.
	a.holstered = true
	_frames(hands, c, 30)
	assert_true(_finite(_pose(hands, c)))
	a.holstered = false
	a.draw_total = 0.6
	a.draw_left = 0.6
	for i in 40:
		a.draw_left = maxf(0.0, a.draw_left - DT)
		_frames(hands, c, 1)
		assert_true(_finite(_pose(hands, c)), "draw frame %d" % i)
	# The trigger let go, still sprinting: the carry takes it back, as it does a fresh view of the same replica.
	a.trigger_was_down = false
	_frames(hands, c, SETTLE * 2)
	var twin_c := _character(1)
	twin_c.sprinting = true
	var twin := _hands(twin_c)
	_frames(twin, twin_c, SETTLE)
	assert_gt(_pose(twin, twin_c).basis.get_euler().length(), 0.1, "control: the twin is carried low")
	assert_almost_eq(_pose(hands, c).origin, _pose(twin, twin_c).origin, Vector3.ONE * EPS, "carried, nothing stuck up")
	assert_almost_eq(_pose(hands, c).basis.get_euler(), _pose(twin, twin_c).basis.get_euler(), Vector3.ONE * EPS)
	c.sprinting = false
	_frames(hands, c, SETTLE)
	twin_c.sprinting = false
	_frames(twin, twin_c, SETTLE)
	assert_almost_eq(_pose(hands, c).origin, _pose(twin, twin_c).origin, Vector3.ONE * EPS, "and back at the hip")


func test_a_sprint_stopped_while_firing_comes_down_square_without_a_dip() -> void:
	var c := _character()
	var hands := _hands(c)
	_frames(hands, c, SETTLE)
	var hip_y := _pose(hands, c).origin.y
	c.sprinting = true
	# Full auto: a shot every few frames keeps the raise (it follows real shots, not the trigger).
	for i in SETTLE:
		if i % SHOT_EVERY == 0:
			hands.on_shot()
		_frames(hands, c, 1)
	c.sprinting = false
	var lowest := INF
	for i in 30:
		if i % SHOT_EVERY == 0:
			hands.on_shot()
		_frames(hands, c, 1)
		lowest = minf(lowest, _pose(hands, c).origin.y)
	assert_gte(lowest, hip_y - EPS, "never lower than the hip while the shots keep going out")


# --- the holstered sprint ---

func test_holstered_the_pace_is_never_slower_in_any_stance_and_the_sprint_is_faster() -> void:
	var m := MovementConfig.new()
	var armed := _character()
	var away := _character()
	away.armament.holstered = true
	var faster_sprints := 0
	for sprinting: bool in [false, true]:
		for walking: bool in [false, true]:
			for crouch: float in [0.0, 0.5, 1.0]:
				for lean: float in [0.0, 0.2, 0.5, 1.0]:
					for c: Character in [armed, away]:
						c.sprinting = sprinting
						c.walking = walking
						c.crouch_amount = crouch
						c.lean = lean
					var label := "sprint %s walk %s crouch %s lean %s" % [sprinting, walking, crouch, lean]
					var a := Movement.target_speed(armed, m, false)
					var h := Movement.target_speed(away, m, false)
					assert_gte(h, a - 1e-6, "never slower holstered: %s" % label)
					assert_lte(h, m.sprint_speed * m.holster_sprint_scale + 1e-6, "never past the holstered sprint")
					if walking or crouch >= 1.0:
						assert_almost_eq(h, a, 1e-6, "walking and crouching gain nothing: %s" % label)
					if sprinting and not walking and crouch == 0.0 and lean == 0.0:
						assert_almost_eq(h, m.sprint_speed * m.holster_sprint_scale, 1e-6)
						faster_sprints += 1
	assert_gt(faster_sprints, 0, "control: a plain sprint was met")


func test_the_holstered_sprint_slows_smoothly_with_lean_and_aim_like_the_armed_one() -> void:
	var m := MovementConfig.new()
	var away := _character()
	away.armament.holstered = true
	away.sprinting = true
	var last := INF
	for lean: float in [0.0, 0.1, 0.2, 0.3, 0.4, 0.5]:
		away.lean = lean
		var s := Movement.target_speed(away, m, false)
		assert_lte(s, last + 1e-6, "monotone down with lean %s" % lean)
		last = s
	away.lean = 0.0
	away.aiming = true
	assert_almost_eq(Movement.target_speed(away, m, true), m.sprint_speed * m.holster_sprint_scale * m.aim_walk_scale,
			1e-6, "aim-walk scales the holstered sprint as it scales any pace")


# --- the hands' depth ---

func test_every_surface_of_every_replica_with_every_part_is_pressed() -> void:
	var kits: Array[Kit] = [
		_kit(AEG, {&"optic": SCOPE, &"muzzle": SILENCER, &"barrel": LONG, &"magazine": "000012"}),
		_kit(PISTOL, {&"laser": LASER, &"muzzle": SILENCER, &"magazine": EXTENDED}, 1),
		_kit(CYBER, {}),
	]
	var seen := 0
	for kit in kits:
		var hands := _kit_hands(kit)
		for held: ReplicaView.Held in hands._held:
			for node: Node in held.root.find_children("*", "MeshInstance3D", true, false):
				var m := node as MeshInstance3D
				if m.mesh == null:
					continue
				for i in m.mesh.get_surface_count():
					var worn := m.get_active_material(i)
					assert_not_null(worn, "%s %s surface %d has a material" % [held.id, node.name, i])
					if ReplicaPaint.is_surface(worn):
						# A painted part on its surface (MQ1, worn or not): its own copy, pressed by its uniform.
						seen += 1
						assert_almost_eq(float((worn as ShaderMaterial).get_shader_parameter(&"z_clip_scale")),
								cfg.depth_scale, 1e-6, "%s %s surface %d pressed" % [held.id, node.name, i])
						continue
					if worn is ShaderMaterial:
						# Otherwise only the optic's glass disc draws with a shader: it presses its own depth.
						assert_eq(node.name, &"Glass")
						assert_almost_eq(float((worn as ShaderMaterial).get_shader_parameter(&"z_clip_scale")),
								cfg.depth_scale, 1e-6)
						continue
					var base := worn as BaseMaterial3D
					assert_not_null(base, "%s %s surface %d is a standard material" % [held.id, node.name, i])
					if base != null:
						seen += 1
						assert_true(base.use_z_clip_scale, "%s %s surface %d pressed" % [held.id, node.name, i])
	assert_gt(seen, 30, "control: the surfaces of three replicas and their parts were seen")


func test_realistic_colours_keep_the_pressed_copy_in_the_realistic_paint() -> void:
	var kit := _kit(AEG, {})
	var hands := _kit_hands(kit, true)
	var held: ReplicaView.Held = hands._held[0]
	var checked := 0
	for node: Node in held.root.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var painted := hands.painted(m, i)
			# the hands wear the paint lightly used (RW1), worn from the shared plain paint
			var shared := ReplicaPaint.plain_of(painted) as StandardMaterial3D if painted != null else null
			if shared == null:
				continue
			var worn := m.get_active_material(i)
			assert_ne(worn, painted, "a copy, not the shared paint")
			var colour: Variant = (worn as ShaderMaterial).get_shader_parameter(&"albedo") if worn is ShaderMaterial \
					else (worn as BaseMaterial3D).albedo_color
			assert_eq(colour, shared.albedo_color, "in the paint's colour")
			assert_true(String(shared.resource_name).contains("/realistic"), "the realistic set: %s" % shared.resource_name)
			assert_false(shared.use_z_clip_scale, "the shared paint stays unpressed")
			checked += 1
	assert_gt(checked, 0, "control: painted surfaces were met")
	# The Cyber Pistol's own colours turn plain grey under Realistic colours, pressed all the same.
	var cyber := _kit_hands(_kit(CYBER, {}), true)
	for node: Node in cyber._held[0].root.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		for i in m.mesh.get_surface_count():
			# on their surfaces (MQ1): pressed by the surface's uniform
			var worn := m.get_active_material(i)
			if worn is ShaderMaterial:
				assert_almost_eq(float((worn as ShaderMaterial).get_shader_parameter(&"z_clip_scale")),
						cfg.depth_scale, 1e-6)
			else:
				assert_true((worn as BaseMaterial3D).use_z_clip_scale)
			assert_false((m.mesh.surface_get_material(i) as BaseMaterial3D).use_z_clip_scale, "the model's own untouched")


func test_the_scope_s_glass_follows_the_hands_depth_scale() -> void:
	var hands := _kit_hands(_kit(AEG, {&"optic": SCOPE}))
	var held: ReplicaView.Held = hands._held[0]
	assert_not_null(held.window, "control: the scope has glass")
	assert_almost_eq(float(held.window.material.get_shader_parameter(&"z_clip_scale")), cfg.depth_scale, 1e-6)
	cfg.depth_scale = 1.0
	var plain := _kit_hands(_kit(AEG, {&"optic": SCOPE}))
	assert_almost_eq(float((plain._held[0] as ReplicaView.Held).window.material.get_shader_parameter(&"z_clip_scale")),
			1.0, 1e-6, "unpressed when the scale is one")


func test_the_pressed_copies_are_freed_with_the_view_and_the_shared_paints_survive() -> void:
	var kit := _kit(AEG, {})
	var hands := _kit_hands(kit)
	var held: ReplicaView.Held = hands._held[0]
	var copy: WeakRef = null
	for node: Node in held.root.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m.get_surface_override_material_count() > 0 and m.get_surface_override_material(0) != null:
			copy = weakref(m.get_surface_override_material(0))
			break
	assert_not_null(copy, "control: a pressed copy exists")
	var shared := ReplicaPaint.materials(kit.paints[0], false)
	held = null
	var eyes := hands.get_parent()
	eyes.remove_child(hands)
	hands.free()
	await wait_process_frames(2)
	assert_null(copy.get_ref(), "the copy dies with the view")
	assert_false(shared.is_empty())
	for s in shared:
		assert_false(s.use_z_clip_scale, "the shared paint is still unpressed")


func test_two_views_press_apart_and_neither_changes_a_third_user_of_the_paint() -> void:
	var c := _character()
	var first := _hands(c)
	var second := _hands(c)
	var m1 := first._held[0].root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var m2 := second._held[0].root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert_ne(m1.get_active_material(0), m2.get_active_material(0), "each view its own copies")
	var figure_side := (load("res://assets/models/replicas/aeg.glb") as PackedScene).instantiate() as Node3D
	add_child_autofree(figure_side)
	ReplicaPaint.apply(figure_side, &"cobalt", false, false)  # as FigureView paints a figure's (plain, RW1)
	for node: Node in figure_side.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var worn := m.get_active_material(i) as BaseMaterial3D
			assert_false(worn.use_z_clip_scale, "a figure's replica is drawn at its true depth")


# --- the BB's drawn place and pool ---

func test_a_bb_is_never_drawn_ahead_of_its_true_place_along_its_flight_for_any_muzzle() -> void:
	var fx := EffectsConfig.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var sideways := 0
	for n in 400:
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 0.3), rng.randf_range(-1.0, -0.2)).normalized()
		var muzzle := Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.1), rng.randf_range(-1.8, -0.2))
		var pool := BBPool.new(2)
		var bb := pool.spawn(0, Vector3(0.0, 1.6, 0.0), dir, SPEED, 0.0, MASS, 0.0)
		bb.age = rng.randf() * fx.muzzle_join_time
		bb.position += dir * 1.5
		var fraction := rng.randf()
		var drawn := BBView.drawn_at(fx, bb, 0, muzzle, fraction, DT)
		var true_at := bb.prev_position.lerp(bb.position, fraction)
		assert_almost_eq((drawn - true_at).dot(dir), 0.0, 1e-4, "shot %d: nothing along the flight" % n)
		if (drawn - true_at).length() > 0.01:
			sideways += 1
	assert_gt(sideways, 100, "control: most were drawn off to the side of the true path")


func test_another_character_s_bb_is_drawn_exactly_where_it_is() -> void:
	var fx := EffectsConfig.new()
	var pool := BBPool.new(2)
	var bb := pool.spawn(3, Vector3(2.0, 1.0, -4.0), Vector3.FORWARD, SPEED, 0.0, MASS, 0.0)
	bb.position += Vector3.FORWARD * 1.5
	assert_eq(BBView.drawn_at(fx, bb, 0, Vector3(0.3, -0.2, -1.0), 0.5, DT), bb.prev_position.lerp(bb.position, 0.5),
			"a bot's BB has no muzzle offset")


func test_a_full_mixed_pool_draws_each_bb_once_and_trails_only_the_white_ones() -> void:
	var fx := EffectsConfig.new()
	var view := BBView.new()
	add_child_autofree(view)
	view.setup(fx, 8)
	var bits := PackedByteArray([0, 0, 0, 0])
	bits[1] = 1
	view.set_glowing(bits)
	var pool := BBPool.new(8)
	for i in 8:
		var bb := pool.spawn(1 if i < 3 else 2, Vector3(-4.0 + i, 1.0, -20.0), Vector3.RIGHT, SPEED, 0.0, MASS, 0.0, 0)
		bb.age = 1.0
	view.update(pool, 0, Vector3.ZERO, 0.5, DT, Vector3(0.0, 1.0, 0.0))
	var draws := view.draws()
	assert_eq(draws[0].multimesh.visible_instance_count, 5, "five white")
	assert_eq(draws[1].multimesh.visible_instance_count, 3, "three glowing")
	assert_eq(draws[2].multimesh.visible_instance_count, 3, "their streaks")
	assert_eq(draws[3].multimesh.visible_instance_count, 5, "a trail for each white one only")
	# A ninth spawn into the full pool takes the oldest slot: still eight drawn, none more.
	pool.spawn(2, Vector3(0.0, 1.0, -20.0), Vector3.RIGHT, SPEED, 0.0, MASS, 0.0, 0)
	view.update(pool, 0, Vector3.ZERO, 0.5, DT, Vector3(0.0, 1.0, 0.0))
	assert_eq(draws[0].multimesh.visible_instance_count + draws[1].multimesh.visible_instance_count, 8)
	assert_lte(draws[3].multimesh.visible_instance_count, 8)


func test_a_stopped_bb_leaves_no_ball_and_no_trail_and_a_fresh_one_has_none_yet() -> void:
	var fx := EffectsConfig.new()
	var view := BBView.new()
	add_child_autofree(view)
	view.setup(fx, 4)
	var pool := BBPool.new(4)
	var bb := pool.spawn(2, Vector3(0.0, 1.0, -10.0), Vector3.RIGHT, SPEED, 0.0, MASS, 0.0)
	view.update(pool, 0, Vector3.ZERO, 0.0, DT, Vector3.ZERO)
	assert_eq(view.multimesh.visible_instance_count, 1, "a fresh BB is drawn")
	assert_eq(view.draws()[3].multimesh.visible_instance_count, 0, "with no trail before it has flown")
	bb.age = 0.5
	view.update(pool, 0, Vector3.ZERO, 0.0, DT, Vector3.ZERO)
	assert_eq(view.draws()[3].multimesh.visible_instance_count, 1)
	bb.active = false
	view.update(pool, 0, Vector3.ZERO, 0.0, DT, Vector3.ZERO)
	assert_eq(view.multimesh.visible_instance_count, 0)
	assert_eq(view.draws()[3].multimesh.visible_instance_count, 0, "the trail goes with the BB")
	assert_false(view.draws()[3].visible)


func test_a_trail_is_never_longer_than_the_bb_has_flown_and_a_ricochet_trails_along_its_new_heading() -> void:
	var fx := EffectsConfig.new()
	var eye := Vector3(0.0, 1.0, 0.0)
	var young := BBView.streak_of(fx, Vector3(0.0, 1.0, -10.0), Vector3.RIGHT * SPEED, 0.004, eye, fx.bb_trail_time,
			fx.bb_trail_angle)
	assert_almost_eq(young.basis.y.length(), SPEED * 0.004, 1e-4, "no longer than its 4 ms of flight")
	var off := BBView.streak_of(fx, Vector3(0.0, 1.0, -10.0), Vector3.RIGHT * SPEED, 0.0, eye, fx.bb_trail_time,
			fx.bb_trail_angle)
	assert_eq(off.basis.x, Vector3.ZERO, "none at the instant it is fired")
	var bounced := BBView.streak_of(fx, Vector3(0.0, 1.0, -10.0), Vector3(-30.0, 0.0, 30.0), 1.0, eye,
			fx.bb_trail_time, fx.bb_trail_angle)
	assert_gt(bounced.basis.y.normalized().dot(Vector3(-30.0, 0.0, 30.0).normalized()), 0.99,
			"back along its current heading")
	assert_almost_eq(bounced.basis.y.length(), Vector3(-30.0, 0.0, 30.0).length() * fx.bb_trail_time, 1e-4)
