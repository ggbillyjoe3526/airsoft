extends GutTest
## QA for GT3: edge cases of your arms pulling the pin and throwing the bomb in first person.

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


func _view(kind: int = FigureMix.HUMAN) -> GrenadeView:
	var v := GrenadeView.new()
	add_child_autofree(v)
	v.setup(8, cfg, false)
	v.setup_arms(view_cfg, kind)
	return v


func _char(id: int = 0) -> Character:
	var c := Character.new(id, 0, Vector3.ZERO, 0.0, loadout)
	c.grenades.carry(1, 1)
	return c


func _frames(v: GrenadeView, s: GameState, c: Character, seconds: float) -> void:
	for i in ceili(seconds / DT) + 1:
		v.update(s, 0.0, DT, c, EYE)


func _throw_at(c: Character, kind: int, share: float) -> void:
	c.grenades.readied = Grenade.Kind.NONE
	c.grenades.throwing = kind
	c.grenades.released = share >= 1.0
	c.grenades.windup_left = cfg.windup * (1.0 - minf(share, 1.0))
	c.grenades.recover_left = cfg.recover * (2.0 - maxf(share, 1.0))


func _bone_turns(v: GrenadeView) -> Array[Quaternion]:
	var sk := v.arms()._skeleton
	var out: Array[Quaternion] = []
	for i in sk.get_bone_count():
		out.append(sk.get_bone_pose_rotation(i))
	return out


func test_the_throw_ending_out_of_view_leaves_the_skeleton_on_the_hold_for_the_next_bomb() -> void:
	var s := GameState.new(5, tuning)
	var fresh := _view()
	var c := _char()
	c.grenades.readied = Grenade.Kind.SMOKE
	_frames(fresh, s, c, view_cfg.bomb_raise_time)
	var want := _bone_turns(fresh)
	var v := _view()
	var d := _char()
	d.grenades.readied = Grenade.Kind.SMOKE
	_frames(v, s, d, view_cfg.bomb_raise_time)
	_throw_at(d, Grenade.Kind.SMOKE, 1.6)
	v.update(s, 0.0, DT, d, EYE)
	d.grenades.stop()
	_frames(v, s, d, 0.1)
	assert_false(v.held_shown(), "gone")
	d.grenades.readied = Grenade.Kind.FLASH
	d.grenades.readied = Grenade.Kind.SMOKE
	_frames(v, s, d, view_cfg.bomb_raise_time)
	var got := _bone_turns(v)
	for i in want.size():
		assert_true(got[i].is_equal_approx(want[i]), "bone %d as on a fresh hold" % i)


func test_putting_the_bomb_back_after_a_pose_returns_the_arms_to_the_hold() -> void:
	var s := GameState.new(5, tuning)
	var v := _view()
	var c := _char()
	c.grenades.readied = Grenade.Kind.FLASH
	_frames(v, s, c, view_cfg.bomb_raise_time)
	var want := _bone_turns(v)
	_throw_at(c, Grenade.Kind.FLASH, 0.4)
	v.update(s, 0.0, DT, c, EYE)
	c.grenades.stop()
	c.grenades.readied = Grenade.Kind.FLASH
	v.update(s, 0.0, DT, c, EYE)
	var got := _bone_turns(v)
	for i in want.size():
		assert_true(got[i].is_equal_approx(want[i]), "bone %d back on the hold" % i)


func test_readied_then_thrown_keeps_one_hold_and_runs_through_every_share() -> void:
	var s := GameState.new(5, tuning)
	var v := _view()
	var c := _char()
	c.grenades.readied = Grenade.Kind.SMOKE
	_frames(v, s, c, view_cfg.bomb_raise_time)
	var held_at := v._held.transform
	var hold_node := v.arms()._model.get_parent()
	for share: float in [0.1, 0.3, 0.5, 0.9, 1.0, 1.2, 1.9]:
		_throw_at(c, Grenade.Kind.SMOKE, share)
		v.update(s, 0.0, DT, c, EYE)
		assert_eq(v.arms()._model.get_parent(), hold_node, "same hold at %s" % share)
		assert_true(v._held.transform.is_finite(), "finite at %s" % share)
		assert_true(v.arms().bomb_moved().is_finite())
	assert_false(v._held.transform.is_equal_approx(held_at))


func test_the_bomb_and_pin_are_hidden_once_released_whatever_the_kind() -> void:
	var s := GameState.new(5, tuning)
	for kind: int in [Grenade.Kind.SMOKE, Grenade.Kind.FLASH]:
		var v := _view()
		var c := _char()
		c.grenades.readied = kind
		_frames(v, s, c, view_cfg.bomb_raise_time)
		assert_true(v._pin.visible, "pin on the waiting bomb %d" % kind)
		_throw_at(c, kind, 1.1)
		v.update(s, 0.0, DT, c, EYE)
		assert_false(v._held.visible)
		assert_false(v._pin.visible)


func test_a_robots_arms_throw_without_error_and_move_the_bomb() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(FigureMix.ROBOT)
	var c := _char()
	c.grenades.readied = Grenade.Kind.FLASH
	_frames(v, s, c, view_cfg.bomb_raise_time)
	_throw_at(c, Grenade.Kind.FLASH, 0.7)
	v.update(s, 0.0, DT, c, EYE)
	assert_false(v.arms().bomb_moved().is_equal_approx(Transform3D.IDENTITY))
	assert_true(v.arms().bomb_moved().is_finite())


func test_arms_throw_with_a_skeleton_lacking_the_arm_bones_moves_nothing() -> void:
	var sk := Skeleton3D.new()
	autofree(sk)
	sk.add_bone("Root")
	var t := ArmsThrow.new(sk, view_cfg)
	t.capture(sk, Vector3.ZERO)
	t.pose(sk, 0.5)
	t.pose(sk, 1.5)
	assert_true(t.bomb_moved(sk).is_equal_approx(Transform3D.IDENTITY))
	assert_true(t.pin_moved(sk, 0.5).is_equal_approx(Transform3D.IDENTITY))


func test_the_share_is_continuous_across_ticks_and_the_release() -> void:
	var c := _char()
	var h := c.grenades
	h.throwing = Grenade.Kind.SMOKE
	h.released = false
	h.windup_left = cfg.windup
	var last := -1.0
	var left := cfg.windup
	while left > 0.0:
		h.windup_left = left
		var at_end := GrenadeView.throw_share(c, cfg, DT)
		var next := left - DT
		if next > 0.0:
			h.windup_left = next
			assert_almost_eq(GrenadeView.throw_share(c, cfg, 0.0), at_end, 0.0001, "no jump at the tick")
		left = next
		var now := GrenadeView.throw_share(c, cfg, 0.0)
		assert_gte(now, last)
		last = now
	h.released = true
	h.recover_left = cfg.recover
	assert_almost_eq(GrenadeView.throw_share(c, cfg, 0.0), 1.0, 0.0001)
	h.recover_left = 0.0
	assert_almost_eq(GrenadeView.throw_share(c, cfg, 0.0), 2.0, 0.0001)
	h.throwing = Grenade.Kind.NONE
	assert_eq(GrenadeView.throw_share(c, cfg, 0.0), 0.0)


func test_the_pose_depends_on_the_share_not_the_frame_rate() -> void:
	var s := GameState.new(5, tuning)
	var out: Array[Transform3D] = []
	for dt: float in [1.0 / 30.0, 1.0 / 144.0]:
		var v := _view()
		var c := _char()
		c.grenades.readied = Grenade.Kind.SMOKE
		for i in ceili(view_cfg.bomb_raise_time / dt) + 2:
			v.update(s, 0.0, dt, c, EYE)
		_throw_at(c, Grenade.Kind.SMOKE, 0.7)
		v.update(s, 0.0, dt, c, EYE)
		out.append(v._held.transform)
	assert_true(out[0].is_equal_approx(out[1]))


func test_a_throw_cut_off_mid_windup_eases_back_to_the_hold_as_the_hand_goes_down() -> void:
	var s := GameState.new(5, tuning)
	var v := _view()
	var c := _char()
	c.grenades.readied = Grenade.Kind.SMOKE
	_frames(v, s, c, view_cfg.bomb_raise_time)
	_throw_at(c, Grenade.Kind.SMOKE, 0.8)
	v.update(s, 0.0, DT, c, EYE)
	var at_cut := v.arms().bomb_moved().origin.length()
	assert_gt(at_cut, 0.01, "mid-throw")
	c.grenades.stop()
	v.update(s, 0.0, DT, c, EYE)
	assert_true(v._held_root.visible, "the empty hand goes down")
	var next := v.arms().bomb_moved().origin.length()
	assert_gt(next, 0.5 * at_cut, "not snapped to the hold in one frame")
	assert_lt(next, at_cut, "already on its way back")
	_frames(v, s, c, view_cfg.bomb_unwind_time)
	assert_true(v._held_root.visible, "back before the hand is gone")
	assert_true(v.arms().bomb_moved().is_equal_approx(Transform3D.IDENTITY), "on the hold, not frozen mid-throw")


func test_turning_to_eyes_with_nothing_in_hand_mid_windup_eases_back_to_the_hold() -> void:
	var s := GameState.new(5, tuning)
	var v := _view()
	var thrower := _char(1)
	var bare := _char(2)
	thrower.grenades.readied = Grenade.Kind.FLASH
	_frames(v, s, thrower, view_cfg.bomb_raise_time)
	_throw_at(thrower, Grenade.Kind.FLASH, 0.9)
	v.update(s, 0.0, DT, thrower, EYE)
	v.update(s, 0.0, DT, bare, EYE)
	assert_false(v.arms().bomb_moved().is_equal_approx(Transform3D.IDENTITY), "easing, not snapped")
	_frames(v, s, bare, view_cfg.bomb_unwind_time)
	assert_true(v.arms().bomb_moved().is_equal_approx(Transform3D.IDENTITY))


func test_the_ease_back_runs_its_time_eased_out_whatever_the_frame_rate() -> void:
	var s := GameState.new(5, tuning)
	var out: Array[float] = []
	# A time both rates step evenly to half of.
	view_cfg.bomb_unwind_time = 0.2
	for dt: float in [1.0 / 30.0, 1.0 / 120.0]:
		var v := _view()
		var c := _char()
		c.grenades.readied = Grenade.Kind.SMOKE
		for i in ceili(view_cfg.bomb_raise_time / dt) + 2:
			v.update(s, 0.0, dt, c, EYE)
		_throw_at(c, Grenade.Kind.SMOKE, 0.8)
		v.update(s, 0.0, dt, c, EYE)
		var at_cut := v.arms().bomb_moved().origin.length()
		c.grenades.stop()
		for i in roundi(view_cfg.bomb_unwind_time * 0.5 / dt):
			v.update(s, 0.0, dt, c, EYE)
		out.append(v.arms().bomb_moved().origin.length() / at_cut)
	assert_almost_eq(out[0], out[1], 0.02, "the same way back at half its time")
	assert_gt(out[0], 0.1, "still on its way at half its time")
	assert_lt(out[0], 0.5, "eased out: over half way back at half its time")


func test_an_ease_back_longer_than_the_hand_going_down_is_held_to_it() -> void:
	var s := GameState.new(5, tuning)
	view_cfg.bomb_unwind_time = 1.0
	var v := _view()
	var c := _char()
	c.grenades.readied = Grenade.Kind.SMOKE
	_frames(v, s, c, view_cfg.bomb_raise_time)
	_throw_at(c, Grenade.Kind.SMOKE, 0.8)
	v.update(s, 0.0, DT, c, EYE)
	var at_cut := v.arms().bomb_moved().origin.length()
	c.grenades.stop()
	for i in floori(view_cfg.bomb_raise_time / DT) - 1:
		v.update(s, 0.0, DT, c, EYE)
	assert_true(v._held_root.visible, "the hand is still going down")
	assert_lt(v.arms().bomb_moved().origin.length(), 0.05 * at_cut, "the arms nearly home as the hand goes")


func test_the_left_hand_cut_off_on_the_pin_eases_down_shown_then_hides() -> void:
	var s := GameState.new(5, tuning)
	var v := _view()
	var c := _char()
	c.grenades.readied = Grenade.Kind.SMOKE
	_frames(v, s, c, view_cfg.bomb_raise_time)
	_throw_at(c, Grenade.Kind.SMOKE, 0.4)
	v.update(s, 0.0, DT, c, EYE)
	var left := v.arms()._left
	assert_true(left.visible, "pulling the pin")
	c.grenades.stop()
	v.update(s, 0.0, DT, c, EYE)
	assert_true(left.visible, "still shown as it eases down")
	_frames(v, s, c, view_cfg.bomb_unwind_time)
	assert_false(left.visible, "hidden once back")


func test_a_new_bomb_or_throw_while_easing_back_starts_from_its_own_hold() -> void:
	var s := GameState.new(5, tuning)
	var fresh := _view()
	var f := _char()
	f.grenades.readied = Grenade.Kind.FLASH
	_frames(fresh, s, f, view_cfg.bomb_raise_time)
	var want := _bone_turns(fresh)
	var v := _view()
	var c := _char()
	c.grenades.readied = Grenade.Kind.SMOKE
	_frames(v, s, c, view_cfg.bomb_raise_time)
	_throw_at(c, Grenade.Kind.SMOKE, 0.5)
	v.update(s, 0.0, DT, c, EYE)
	c.grenades.stop()
	v.update(s, 0.0, DT, c, EYE)
	c.grenades.readied = Grenade.Kind.FLASH
	_frames(v, s, c, view_cfg.bomb_raise_time)
	var got := _bone_turns(v)
	for i in want.size():
		assert_true(got[i].is_equal_approx(want[i]), "bone %d on the flash's hold" % i)
	_throw_at(c, Grenade.Kind.FLASH, 0.5)
	v.update(s, 0.0, DT, c, EYE)
	c.grenades.stop()
	v.update(s, 0.0, DT, c, EYE)
	_throw_at(c, Grenade.Kind.FLASH, 0.2)
	v.update(s, 0.0, DT, c, EYE)
	fresh.update(s, 0.0, DT, f, EYE)
	_throw_at(f, Grenade.Kind.FLASH, 0.2)
	fresh.update(s, 0.0, DT, f, EYE)
	assert_true(v._held.transform.is_equal_approx(fresh._held.transform), "a throw mid-ease is drawn as from the hold")
