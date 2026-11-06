extends GutTest
## QA for GT2: edge cases of the arms holding the bomb in first person.

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


func _view() -> GrenadeView:
	var v := GrenadeView.new()
	add_child_autofree(v)
	v.setup(8, cfg, false)
	v.setup_arms(view_cfg, FigureMix.HUMAN)
	return v


func _char(id: int = 0) -> Character:
	var c := Character.new(id, 0, Vector3.ZERO, 0.0, loadout)
	c.grenades.carry(1, 1)
	return c


func test_spectating_another_thrower_draws_their_bomb_and_returns_to_none_for_a_bare_one() -> void:
	var s := GameState.new(5, tuning)
	var v := _view()
	var a := _char(1)
	var b := _char(2)
	a.grenades.readied = Grenade.Kind.SMOKE
	b.grenades.readied = Grenade.Kind.FLASH
	v.update(s, 0.0, DT, a, EYE)
	assert_eq(v.arms().holding(), &"smoke")
	v.update(s, 0.0, DT, b, EYE)
	assert_eq(v.arms().holding(), &"flash")
	b.grenades.readied = Grenade.Kind.NONE
	for i in ceili(view_cfg.bomb_raise_time / DT) + 1:
		v.update(s, 0.0, DT, b, EYE)
	assert_false(v.arms()._model.is_visible_in_tree(), "the empty hand has gone down")
	v.update(s, 0.0, DT, null, EYE)
	assert_false(v.held_shown())


func test_eliminated_with_a_bomb_readied_hides_the_bomb_and_the_replicas_arms_return() -> void:
	var c := _char()
	var s := GameState.new(5, tuning)
	var v := _view()
	c.grenades.readied = Grenade.Kind.SMOKE
	v.update(s, 0.0, DT, c, EYE)
	assert_true(v.held_shown())
	c.grenades.stop()
	v.update(s, 0.0, DT, c, EYE)
	assert_false(v.held_shown())
	assert_eq(Grenades.held(c), Grenade.Kind.NONE)


func test_switching_replica_with_a_bomb_in_hand_keeps_the_replicas_arms_hidden() -> void:
	var c := _char()
	if c.armament.replicas.size() < 2:
		pending("needs two replicas")
		return
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(view_cfg, c.armament.replicas, BoxWorld.new())
	hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
	c.grenades.readied = Grenade.Kind.FLASH
	c.armament.holstered = true
	for i in ceili(view_cfg.holster_time / DT) + 1:
		hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
	var model: Node3D = hands._arms._model
	assert_false(model.visible)
	c.armament.active = (c.armament.active + 1) % c.armament.replicas.size()
	hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
	assert_false(model.visible, "a replica switch under a bomb must not flash the arms back")
	c.grenades.readied = Grenade.Kind.NONE
	c.armament.holstered = false
	hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
	assert_true(model.visible)


func test_replica_update_while_not_visible_does_not_leave_arms_stale_after_the_bomb_goes() -> void:
	var c := _char()
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(view_cfg, c.armament.replicas, BoxWorld.new())
	c.grenades.readied = Grenade.Kind.SMOKE
	hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
	c.grenades.stop()
	hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
	assert_true(hands._arms._model.visible)


func test_kind_swap_after_a_robot_change_dresses_both_holds_and_leaves_no_stale_surfaces() -> void:
	var s := GameState.new(5, tuning)
	var v := _view()
	var c := _char()
	c.grenades.readied = Grenade.Kind.SMOKE
	v.update(s, 0.0, DT, c, EYE)
	c.grenades.readied = Grenade.Kind.FLASH
	v.update(s, 0.0, DT, c, EYE)
	var n := v._held.mesh.get_surface_count()
	for i in n:
		assert_not_null(v._held.get_surface_override_material(i), "surface %d of the flash overridden" % i)
	v.set_arms_kind(FigureMix.ROBOT)
	v.set_arms_kind(FigureMix.HUMAN)
	assert_eq(v.arms()._kind, FigureMix.HUMAN)


func test_setup_arms_twice_and_set_arms_kind_without_arms_are_harmless() -> void:
	var v := GrenadeView.new()
	add_child_autofree(v)
	v.setup(4, cfg, false)
	v.set_arms_kind(FigureMix.ROBOT)
	v.setup_arms(view_cfg, FigureMix.ROBOT)
	var first := v.arms()
	v.setup_arms(view_cfg, FigureMix.HUMAN)
	assert_eq(v.arms(), first)
	assert_eq(first._kind, FigureMix.ROBOT)


func test_a_view_freed_with_the_bomb_in_hand_leaks_no_nodes() -> void:
	var s := GameState.new(5, tuning)
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var v := GrenadeView.new()
	add_child(v)
	v.setup(4, cfg, false)
	v.setup_arms(view_cfg, FigureMix.HUMAN)
	var c := _char()
	c.grenades.readied = Grenade.Kind.SMOKE
	v.update(s, 0.0, DT, c, EYE)
	remove_child(v)
	v.free()
	await wait_physics_frames(1)
	assert_lte(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)
