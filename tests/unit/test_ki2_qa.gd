extends GutTest
## KI2 QA: the GBB Pistol's slide through a reload begun at any moment of the last shot's Fire clip, a reload cut short,
## and the replicas without a slide lock (game/play/replica_view.gd). The slide is a BoneAttachment3D the skeleton
## re-poses after the view's update, so a position is read only after process frames have run (_settle).

const DT := 1.0 / 60.0
const EPS := Vector3.ONE * 0.0001

var view: ReplicaView
var c: Character
var a: Armament
var cfg: ViewModelConfig


func before_each() -> void:
	cfg = ViewModelConfig.new()
	_new_view()


func _new_view() -> void:
	if view != null:
		view.queue_free()
	c = Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	a = c.armament
	view = ReplicaView.new()
	add_child_autofree(view)
	view.setup(cfg, a.replicas, BoxWorld.new())


func _frame() -> void:
	view.update(c, 0.0, 0.0, Vector3(0.0, 1.6, 0.0), Vector3.FORWARD, DT, c.aim_raise)


func _settle() -> void:
	await wait_process_frames(2)


func _pistol() -> ReplicaView.Held:
	return view._held[1]


## The slide's rendered position with the magazine empty and no reload (locked back) and with it loaded (home), on a
## scratch view.
func _poses() -> Dictionary:
	_new_view()
	a.active = 1
	_frame()
	await _settle()
	var home := _pistol().slide.position
	a.ammo[1].mag = 0
	_frame()
	await _settle()
	return {"home": home, "back": _pistol().slide.position}


## The last BB goes, `into_clip` seconds of the Fire clip pass, and a reload with `share` of its time left begins.
func _quick_reload(into_clip: float, share: float) -> void:
	a.active = 1
	_frame()
	view.on_shot()
	a.ammo[1].mag = 0
	_frame()
	if into_clip > 0.0:
		_pistol().anim.advance(into_clip)
	a.reload_left = a.replicas[1].reload_time * share
	_frame()


func test_a_reload_begun_at_any_moment_of_the_last_shots_fire_clip_holds_the_slide_back() -> void:
	var poses := await _poses()
	assert_ne(poses.home, poses.back, "the locked pose differs from home (else nothing below means anything)")
	var lock := cfg.slide_lock_after
	var clip_end := _pistol().anim.get_animation(ReplicaView.FIRE_CLIP).length
	for into: float in [0.0, lock * 0.5, lock - 0.001, lock, lock + 0.001, clip_end * 0.5, clip_end, clip_end + 0.5]:
		_new_view()
		_quick_reload(into, 0.95)
		assert_true(_pistol().slide_locked, "flag: reload begun %.3f s into the clip" % into)
		await _settle()
		assert_almost_eq(_pistol().slide.position, poses.back, EPS, "rendered back at %.3f s into the clip" % into)


func test_the_slide_is_rendered_back_through_the_reload_and_home_at_its_end() -> void:
	var poses := await _poses()
	_quick_reload(0.0, 1.0)
	for share: float in [0.9, 0.5, 0.2]:
		a.reload_left = a.replicas[1].reload_time * share
		_frame()
		await _settle()
		assert_almost_eq(_pistol().slide.position, poses.back, EPS, "back with %.1f of the reload left" % share)
	a.reload_left = 0.0
	a.ammo[1].mag = a.replicas[1].mag_size
	_frame()
	await _settle()
	assert_false(_pistol().slide_locked)
	assert_almost_eq(_pistol().slide.position, poses.home, EPS, "home once loaded")
	view.on_shot()
	_frame()
	assert_false(_pistol().slide_locked, "a shot afterwards does not lock it")


func test_a_reload_cut_short_by_a_holster_relocks_the_slide_when_drawn_still_empty() -> void:
	var poses := await _poses()
	_quick_reload(0.0, 0.5)
	a.holstered = true
	a.reload_left = 0.0
	_frame()
	a.holstered = false
	_frame()
	await _settle()
	assert_true(_pistol().slide_locked, "still empty")
	assert_almost_eq(_pistol().slide.position, poses.back, EPS)


func test_a_reload_cut_short_after_the_slide_was_let_go_locks_it_back_again() -> void:
	var poses := await _poses()
	_quick_reload(0.0, 1.0)
	a.reload_left = a.replicas[1].reload_time * (1.0 - cfg.slide_release_at) * 0.5
	_frame()
	assert_false(_pistol().slide_locked, "let go near the end")
	a.active = 0
	a.reload_left = 0.0
	_frame()
	a.active = 1
	_frame()
	await _settle()
	assert_true(_pistol().slide_locked, "empty again")
	assert_almost_eq(_pistol().slide.position, poses.back, EPS)


func test_eliminated_mid_reload_the_next_round_finds_the_slide_home() -> void:
	var poses := await _poses()
	_quick_reload(0.0, 0.5)
	c.status = Character.Status.OUT
	_frame()
	c.respawn()
	a.refill()
	_frame()
	a.active = 1
	_frame()
	await _settle()
	assert_false(_pistol().in_reload)
	assert_false(_pistol().slide_locked)
	assert_almost_eq(_pistol().slide.position, poses.home, EPS, "not left back after the new round")


func test_a_hidden_view_through_the_reload_comes_back_with_the_slide_home_once_loaded() -> void:
	var poses := await _poses()
	_quick_reload(0.0, 0.5)
	c.status = Character.Status.OUT
	a.reload_left = 0.0
	a.ammo[1].mag = a.replicas[1].mag_size
	_frame()
	assert_false(view.visible)
	c.status = Character.Status.ALIVE
	_frame()
	await _settle()
	assert_false(_pistol().slide_locked)
	assert_almost_eq(_pistol().slide.position, poses.home, EPS)


func test_a_reload_of_a_part_full_magazine_does_not_lock_at_any_point() -> void:
	var poses := await _poses()
	_new_view()
	a.active = 1
	a.ammo[1].mag = 1
	_frame()
	view.on_shot()
	for share: float in [1.0, 0.7, 0.3, 0.05]:
		a.reload_left = a.replicas[1].reload_time * share
		_frame()
		await _settle()
		assert_false(_pistol().slide_locked, "tactical reload with %.2f left" % share)
		assert_almost_eq(_pistol().slide.position, poses.home, EPS)


func test_a_bottomless_magazine_never_locks_the_slide() -> void:
	a.bottomless = true
	a.active = 1
	_frame()
	var full := a.ammo[1].mag
	for i in 3:
		view.on_shot()
		_frame()
	assert_eq(a.ammo[1].mag, full)
	a.reload_left = a.replicas[1].reload_time * 0.5
	_frame()
	assert_false(_pistol().slide_locked)


func test_the_rifle_reloads_empty_without_a_slide() -> void:
	a.ammo[0].mag = 0
	a.reload_left = a.replicas[0].reload_time * 0.5
	_frame()
	assert_null(view._held[0].slide)
	assert_false(view._held[0].slide_locked)
	a.reload_left = 0.0
	_frame()
	assert_false(view._held[0].in_reload)


func _modifiers(root: Node) -> Array[Node]:
	return root.find_children("*", "SlideLockPose", true, false)


func test_only_the_gas_pistol_gets_a_slide_modifier_and_it_sits_on_its_skeleton() -> void:
	assert_eq(_modifiers(view._held[0].root).size(), 0, "the rifle has none")
	var mods := _modifiers(_pistol().root)
	assert_eq(mods.size(), 1)
	assert_eq(mods[0].get_parent().get_class(), "Skeleton3D")
	assert_false((mods[0] as SlideLockPose).active, "off until a lock")
	assert_true(view._held[0].slide_hold == null)


func test_a_model_without_the_slide_bone_or_the_clip_gets_no_modifier() -> void:
	var scene := load("res://assets/models/replicas/aeg.glb") as PackedScene
	var model := scene.instantiate() as Node3D
	add_child_autofree(model)
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_null(SlideLockPose.attach(model, anim))
	assert_null(SlideLockPose.attach(model, null))
	assert_eq(_modifiers(model).size(), 0)


func test_a_realistic_colours_view_holds_the_slide_back_too() -> void:
	view.queue_free()
	c = Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	a = c.armament
	view = ReplicaView.new()
	add_child_autofree(view)
	view.setup(cfg, a.replicas, BoxWorld.new(), [] as Array[StringName], true)
	assert_eq(_modifiers(_pistol().root).size(), 1)
	var poses := await _poses()
	assert_gt(poses.home.distance_to(poses.back), 0.01)
	_quick_reload(0.0, 0.5)
	await _settle()
	assert_almost_eq(_pistol().slide.position, poses.back, EPS)


func test_switching_replicas_back_and_forth_adds_and_frees_nothing() -> void:
	# Counted with the pistol in hand, as the switches end: your arms (ArmsView) ride the replica in hand.
	a.active = 1
	_frame()
	await _settle()
	var before := _pistol().root.get_child_count()
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 6:
		a.active = i % 2
		_frame()
		await _settle()
	assert_eq(_modifiers(_pistol().root).size(), 1)
	assert_eq(_pistol().root.get_child_count(), before)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no node added by switching")


func test_a_pistol_hidden_by_a_switch_while_locked_comes_back_loaded_and_home() -> void:
	var poses := await _poses()
	a.ammo[1].mag = 0
	_frame()
	assert_true((_pistol().slide_hold as SlideLockPose).active)
	a.active = 0
	_frame()
	a.ammo[1].mag = a.replicas[1].mag_size
	a.active = 1
	_frame()
	await _settle()
	assert_false((_pistol().slide_hold as SlideLockPose).active, "the hold is released")
	assert_almost_eq(_pistol().slide.position, poses.home, EPS)


func test_freeing_the_view_frees_every_modifier() -> void:
	var tmp := ReplicaView.new()
	add_child(tmp)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	tmp.setup(cfg, a.replicas, BoxWorld.new())
	var with_view := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	assert_gt(with_view, nodes)
	tmp.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes - 1.0, "only the view itself went, nothing else left")
