extends GutTest
## GT2: your own arms hold the smoke or flash bomb in first person. The arms model has a hold per bomb whose mark sits
## where GrenadeView draws the bomb in hand, the arms ride the bomb's square-to-view root, the left arm stays hidden
## while it waits in hand, the bomb's depth is pressed as the arms' are, and both are gone once it leaves the hand.
## GT3: they throw it (ArmsThrow): the left hand pulls the pin and takes it away, the right arm swings the bomb over in
## its fist and lets go, and the follow-through ends out of view.

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


## Updates `v` for `seconds` and a frame more.
func _frames(v: GrenadeView, s: GameState, c: Character, seconds: float) -> void:
	for i in ceili(seconds / DT) + 1:
		v.update(s, 0.0, DT, c, EYE)


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
	_frames(v, s, c, view_cfg.bomb_raise_time)
	var arms := v.arms()
	assert_true(v.held_shown())
	assert_eq(arms.holding(), &"smoke")
	assert_eq(arms._model.get_parent(), v._held_root, "the arms ride the bomb's root")
	assert_true(arms._model.is_visible_in_tree(), "the arms show")
	assert_false(arms._left.visible, "the left arm stays hidden")
	assert_true(v._held.is_visible_in_tree(), "the bomb shows")
	c.grenades.released = true
	c.grenades.recover_left = cfg.recover
	v.update(s, 0.0, DT, c, EYE)
	assert_false(v.held_shown(), "gone once thrown")
	assert_true(arms._model.is_visible_in_tree(), "the empty hand follows through")
	c.grenades.stop()
	v.update(s, 0.0, DT, c, EYE)
	assert_false(arms._model.is_visible_in_tree(), "and is out of view")


## `c` `share` of the way through a throw of `kind` (ArmsThrow's measure).
func _throw_at(c: Character, kind: int, share: float) -> void:
	c.grenades.readied = Grenade.Kind.NONE
	c.grenades.throwing = kind
	c.grenades.released = share >= 1.0
	c.grenades.windup_left = cfg.windup * (1.0 - minf(share, 1.0))
	c.grenades.recover_left = cfg.recover * (2.0 - maxf(share, 1.0))


## The bomb in hand's place in the right hand's frame (it should never move in the fist).
func _in_fist(v: GrenadeView) -> Transform3D:
	var arms := v.arms()
	var hand := arms._skeleton.get_bone_global_pose(arms._skeleton.find_bone("Hand_R"))
	return (arms.model_transform() * hand).affine_inverse() * v._held.transform


func test_the_left_hand_pulls_the_pin_out_and_takes_it_out_of_view() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s)
	var c := _thrower()
	c.grenades.readied = Grenade.Kind.SMOKE
	_frames(v, s, c, view_cfg.bomb_raise_time)
	assert_false(v.arms()._left.visible, "waiting in hand: one-handed")
	assert_true(v._pin.visible, "the pin in the bomb")
	var pin_at := v._pin.transform
	_throw_at(c, Grenade.Kind.SMOKE, view_cfg.bomb_pin_grab)
	v.update(s, 0.0, DT, c, EYE)
	assert_true(v.arms()._left.visible, "the left hand comes up for the pin")
	assert_true(pin_at.origin.is_equal_approx(v._pin.transform.origin), "the ring still in the bomb as it's gripped")
	var sk := v.arms()._skeleton
	var hand := v.arms().model_transform() * sk.get_bone_global_pose(sk.find_bone("Hand_L"))
	var ring := v._pin.transform * v._pin_middle[Grenade.Kind.SMOKE]
	assert_lt(hand.origin.distance_to(ring), 0.12, "the left hand at the ring")
	var grip := hand.affine_inverse() * v._pin.transform
	_throw_at(c, Grenade.Kind.SMOKE, lerpf(view_cfg.bomb_pin_grab, view_cfg.bomb_pin_out, 0.6))
	v.update(s, 0.0, DT, c, EYE)
	hand = v.arms().model_transform() * sk.get_bone_global_pose(sk.find_bone("Hand_L"))
	assert_gt(v._pin.transform.origin.distance_to(pin_at.origin), 0.05, "pulled out")
	assert_true((hand.affine_inverse() * v._pin.transform).is_equal_approx(grip), "in the left hand")
	_throw_at(c, Grenade.Kind.SMOKE, view_cfg.bomb_pin_out + 0.01)
	v.update(s, 0.0, DT, c, EYE)
	assert_false(v.arms()._left.visible, "then the left hand is gone")
	assert_false(v._pin.visible, "with the pin")
	assert_true(v._held.visible, "the bomb still in the right hand")


func test_the_right_arm_swings_the_bomb_over_in_its_fist_and_lets_go() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s)
	var c := _thrower()
	c.grenades.readied = Grenade.Kind.FLASH
	_frames(v, s, c, view_cfg.bomb_raise_time)
	var fist := _in_fist(v)
	var rest := v._held.transform
	var highest := -INF
	for share: float in [0.4, view_cfg.bomb_cock, 0.85, 0.95]:
		_throw_at(c, Grenade.Kind.FLASH, share)
		v.update(s, 0.0, DT, c, EYE)
		assert_true(_in_fist(v).is_equal_approx(fist), "%.2f: the bomb never moves in the fist" % share)
		highest = maxf(highest, v._held.position.y)
	assert_gt(highest, rest.origin.y + 0.15, "it comes over the top")
	_throw_at(c, Grenade.Kind.FLASH, 1.0)
	v.update(s, 0.0, DT, c, EYE)
	assert_false(v._held.visible, "let go at the release")
	assert_true(v._held_root.visible, "the empty hand follows through")


func test_the_follow_through_ends_out_of_view_and_the_arms_are_gone_with_it() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s)
	var c := _thrower()
	c.grenades.readied = Grenade.Kind.SMOKE
	_frames(v, s, c, view_cfg.bomb_raise_time)
	_throw_at(c, Grenade.Kind.SMOKE, 1.99)
	v.update(s, 0.0, DT, c, EYE)
	var sk := v.arms()._skeleton
	var wrist := GrenadeView.HELD_AT + v.arms().model_transform() * sk.get_bone_global_pose(sk.find_bone("Hand_R")).origin
	assert_lt(wrist.y / -wrist.z, -0.7, "the hand below the view (%s)" % wrist)
	c.grenades.stop()
	v.update(s, 0.0, DT, c, EYE)
	assert_false(v._held_root.visible, "gone at once, not lowered again")


func test_the_throw_starts_from_each_bombs_own_hold_after_another_was_thrown() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s)
	var c := _thrower()
	c.grenades.readied = Grenade.Kind.SMOKE
	_frames(v, s, c, view_cfg.bomb_raise_time)
	_throw_at(c, Grenade.Kind.SMOKE, 1.5)
	v.update(s, 0.0, DT, c, EYE)
	c.grenades.stop()
	v.update(s, 0.0, DT, c, EYE)
	c.grenades.readied = Grenade.Kind.FLASH
	_frames(v, s, c, view_cfg.bomb_raise_time)
	assert_true(v._held.transform.is_equal_approx(v._held_rest), "the flash where it is drawn in hand")
	var sk := v.arms()._skeleton
	var wrist := sk.get_bone_global_pose(sk.find_bone("Hand_R")).origin
	assert_lt(wrist.distance_to(GrenadeView.HELD_AT), 0.15, "the right hand on it, not where the smoke's left it")


func test_the_bomb_in_your_hand_draws_its_pin_apart() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s)
	for kind: int in [Grenade.Kind.SMOKE, Grenade.Kind.FLASH]:
		var pin := v.pin_mesh_of(kind)
		assert_not_null(pin, "%d: a pin" % kind)
		if pin == null:
			continue
		assert_eq(v.held_mesh_of(kind).get_surface_count() + pin.get_surface_count(),
				v.mesh_of(kind).get_surface_count(), "%d: every surface once" % kind)
		for i in pin.get_surface_count():
			assert_eq(pin.surface_get_material(i).resource_name, GrenadeView.PIN_MATERIALS[kind])
	assert_eq(v.mesh_of(Grenade.Kind.SMOKE).get_surface_count(), v.meshes()[Grenade.Kind.SMOKE].get_surface_count(),
			"the thrown and the figures' bombs keep theirs")


func test_the_throw_runs_over_the_windup_then_the_recovery() -> void:
	var c := _thrower()
	assert_eq(GrenadeView.throw_share(c, cfg, 0.0), 0.0)
	_throw_at(c, Grenade.Kind.SMOKE, 0.5)
	assert_almost_eq(GrenadeView.throw_share(c, cfg, 0.0), 0.5, 1e-5)
	assert_almost_eq(GrenadeView.throw_share(c, cfg, cfg.windup * 0.1), 0.6, 1e-5, "drawn between ticks")
	_throw_at(c, Grenade.Kind.SMOKE, 1.5)
	assert_almost_eq(GrenadeView.throw_share(c, cfg, 0.0), 1.5, 1e-5)
	assert_true(ArmsThrow.left_shown(0.1, view_cfg) and not ArmsThrow.left_shown(view_cfg.bomb_pin_out, view_cfg))
	assert_eq(ArmsThrow.right_weight(view_cfg.bomb_pin_grab, view_cfg), 0.0, "the right waits for the grip")
	assert_true(ArmsThrow.right_key(1.0, view_cfg).is_equal_approx(view_cfg.bomb_release), "let go at bomb_release")
	assert_true(ArmsThrow.right_key(2.0, view_cfg).is_equal_approx(view_cfg.bomb_follow))


func test_a_bomb_readied_in_hand_shows_in_the_arms_and_switching_kind_swaps_the_hold() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s)
	var c := _thrower()
	c.grenades.readied = Grenade.Kind.FLASH
	v.update(s, 0.0, DT, c, EYE)
	assert_true(v.held_shown())
	assert_eq(v.arms().holding(), &"flash")
	assert_eq(v._held.mesh, v.held_mesh_of(Grenade.Kind.FLASH))
	c.grenades.readied = Grenade.Kind.SMOKE
	v.update(s, 0.0, DT, c, EYE)
	assert_eq(v.arms().holding(), &"smoke")
	assert_eq(v._held.mesh, v.held_mesh_of(Grenade.Kind.SMOKE))


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
	c.armament.holstered = true
	hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
	assert_true(model.visible, "the replica goes down in its hands")
	for i in ceili(view_cfg.holster_time / DT) + 1:
		hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
	assert_false(model.visible, "then the bomb's arms hold it instead")
	_wind_up(c, Grenade.Kind.SMOKE, cfg.windup)
	c.grenades.readied = Grenade.Kind.NONE
	hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
	assert_false(model.visible, "nor through the windup")
	c.grenades.released = true
	c.armament.holstered = false
	hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
	assert_true(model.visible, "back on the replica once it's thrown")
	assert_ne(hands._arms.holding(), &"", "the hold kept throughout")


func test_the_hand_comes_up_into_view_with_the_bomb_eased_as_a_draw() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s)
	var c := _thrower()
	c.grenades.readied = Grenade.Kind.SMOKE
	v.update(s, 0.0, DT, c, EYE)
	var first := v._held_root.position.y - EYE.y
	assert_lt(first, GrenadeView.HELD_AT.y - view_cfg.bomb_raise_drop * 0.7, "starts from well below")
	_frames(v, s, c, view_cfg.bomb_raise_time)
	assert_almost_eq(v._held_root.position.y - EYE.y, GrenadeView.HELD_AT.y, 0.001, "then in place")


func test_a_bomb_seen_through_no_eyes_goes_at_once() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s)
	var c := _thrower()
	c.grenades.readied = Grenade.Kind.SMOKE
	_frames(v, s, c, view_cfg.bomb_raise_time)
	v.update(s, 0.0, DT, null, Vector3.ZERO)
	assert_false(v._held_root.visible)
