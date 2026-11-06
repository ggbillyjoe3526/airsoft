extends GutTest
## GT1 part 2: your own arms hold the smoke or flash bomb in first person. The arms model has a hold per bomb whose mark
## sits where GrenadeView draws the bomb in hand, the arms ride the bomb's square-to-view root (so they lift with it
## through the windup), the left arm stays hidden, the bomb's depth is pressed as the arms' are, and both are gone
## once it leaves the hand.

const DT := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 0.0)

var tuning: SimTuning = SimTuning.new()
var cfg: GrenadeConfig = tuning.grenades
var view_cfg: ViewModelConfig = null
var loadout: Array[ReplicaConfig] = []


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func before_each() -> void:
	view_cfg = ViewModelConfig.new()


func _view(state: GameState, arms: bool = true) -> GrenadeView:
	var v := GrenadeView.new()
	add_child_autofree(v)
	v.setup(state.grenades.size(), cfg, false)
	if arms:
		v.setup_arms(view_cfg, FigureMix.HUMAN)
	return v


func _thrower() -> Character:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	c.grenades.carry(1, 1)
	return c


func _wind_up(c: Character, kind: int, left: float) -> void:
	c.grenades.throwing = kind
	c.grenades.windup_left = left
	c.grenades.released = false


func test_the_arms_model_has_a_hold_for_each_bomb_where_the_bomb_is_drawn() -> void:
	var s := GameState.new(5, tuning)
	var arms := _view(s).arms()
	for kind: int in [Grenade.Kind.SMOKE, Grenade.Kind.FLASH]:
		var id: StringName = GrenadeView.HOLDS[kind]
		var mark := arms._model.find_child(ArmsView.HOLD_PREFIX + id, true, false) as Node3D
		assert_not_null(mark, "%s: a hold mark" % id)
		assert_true(arms._anim.has_animation(StringName(id + ArmsView.CLIP_SUFFIX)), "%s: a hold clip" % id)
		if mark != null:
			var at := arms._to_root(mark).origin
			assert_lt(at.distance_to(GrenadeView.HELD_AT), 0.001, "%s: held where the bomb is drawn (%s)" % [id, at])


func test_the_arms_hold_the_bomb_in_hand_and_go_with_it() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s)
	var c := _thrower()
	v.update(s, 0.0, DT, c, EYE)
	assert_false(v.held_shown(), "nothing in hand")
	_wind_up(c, Grenade.Kind.SMOKE, cfg.windup)
	v.update(s, 0.0, DT, c, EYE)
	var arms := v.arms()
	assert_true(v.held_shown())
	assert_eq(arms.holding(), &"smoke")
	assert_eq(arms._model.get_parent(), v._held_root, "the arms ride the bomb's root")
	assert_true(arms._model.is_visible_in_tree(), "the arms show")
	assert_false(arms._left.visible, "the left arm stays hidden")
	assert_true(v._held.is_visible_in_tree(), "the bomb shows")
	c.grenades.released = true
	v.update(s, 0.0, DT, c, EYE)
	assert_false(v.held_shown(), "gone once thrown")
	assert_false(arms._model.is_visible_in_tree(), "the arms go with it")


func test_the_arms_lift_with_the_bomb_through_the_windup() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s)
	var c := _thrower()
	_wind_up(c, Grenade.Kind.FLASH, cfg.windup)
	v.update(s, 0.0, DT, c, EYE)
	var start := v.arms()._model.global_position
	var bomb_start := v._held.global_position
	_wind_up(c, Grenade.Kind.FLASH, 0.0)
	v.update(s, 0.0, DT, c, EYE)
	var lift := v.arms()._model.global_position - start
	assert_almost_eq(lift.y, GrenadeView.HELD_LIFT, 0.001, "lifted with the bomb")
	assert_almost_eq((v._held.global_position - bomb_start).y, GrenadeView.HELD_LIFT, 0.001)
	assert_eq(v.arms().holding(), &"flash")


func test_a_bomb_readied_in_hand_shows_in_the_arms_and_switching_kind_swaps_the_hold() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s)
	var c := _thrower()
	c.grenades.readied = Grenade.Kind.FLASH
	v.update(s, 0.0, DT, c, EYE)
	assert_true(v.held_shown())
	assert_eq(v.arms().holding(), &"flash")
	assert_eq(v._held.mesh, v.mesh_of(Grenade.Kind.FLASH))
	c.grenades.readied = Grenade.Kind.SMOKE
	v.update(s, 0.0, DT, c, EYE)
	assert_eq(v.arms().holding(), &"smoke")
	assert_eq(v._held.mesh, v.mesh_of(Grenade.Kind.SMOKE))


func test_the_bomb_in_hand_presses_its_depth_as_the_arms_do_and_keeps_out_of_the_optic() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s)
	var c := _thrower()
	c.grenades.readied = Grenade.Kind.SMOKE
	v.update(s, 0.0, DT, c, EYE)
	assert_eq(v._held.layers, OpticGlass.HANDS_LAYER)
	var mesh := v._held.mesh
	assert_gt(mesh.get_surface_count(), 0)
	for i in mesh.get_surface_count():
		var m := v._held.get_surface_override_material(i) as BaseMaterial3D
		assert_not_null(m, "surface %d pressed" % i)
		if m != null:
			assert_true(m.use_z_clip_scale)
			assert_almost_eq(m.z_clip_scale, view_cfg.depth_scale, 1e-6)
			assert_ne(m, mesh.surface_get_material(i), "a copy: the thrown and the figures' bombs keep their depth")
	var shared := v.materials()
	for m: Material in v.arms().materials():
		assert_true(shared.has(m), "prewarmed with the bombs")


func test_without_arms_the_bomb_in_hand_still_shows_alone() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s, false)
	var c := _thrower()
	_wind_up(c, Grenade.Kind.SMOKE, cfg.windup)
	v.update(s, 0.0, DT, c, EYE)
	assert_true(v.held_shown())
	assert_null(v.arms())
	assert_eq(v._held.mesh, v.mesh_of(Grenade.Kind.SMOKE))


func test_a_robots_arms_hold_the_bomb_in_its_colours() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s)
	v.set_arms_kind(FigureMix.ROBOT)
	assert_eq(v.arms()._kind, FigureMix.ROBOT)
	assert_true(view_cfg.one_hand.has(&"smoke") and view_cfg.one_hand.has(&"flash"), "one-handed")


func test_the_replicas_arms_let_go_while_a_bomb_is_in_hand_and_come_back_after() -> void:
	var c := _thrower()
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(view_cfg, c.armament.replicas, BoxWorld.new())
	hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
	var model: Node3D = hands._arms._model
	assert_true(model.visible, "on the replica")
	c.grenades.readied = Grenade.Kind.SMOKE
	hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
	assert_false(model.visible, "the bomb's arms hold it instead")
	_wind_up(c, Grenade.Kind.SMOKE, cfg.windup)
	c.grenades.readied = Grenade.Kind.NONE
	hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
	assert_false(model.visible, "nor through the windup")
	c.grenades.released = true
	hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
	assert_true(model.visible, "back on the replica once it's thrown")
	assert_ne(hands._arms.holding(), &"", "the hold kept throughout")
