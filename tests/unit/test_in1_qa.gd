extends GutTest
## IN1 QA: Inspect against the gas pistol's slide lock, the fire selector, the clips that follow it, the order wheel and
## the map. Skeleton poses are read after process frames (a modifier runs after the view's update).

const DT := 1.0 / 60.0
const EPS := Vector3.ONE * 0.0001

var view: ReplicaView
var c: Character
var a: Armament
var cfg: ViewModelConfig


func before_each() -> void:
	cfg = ViewModelConfig.new()
	c = Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	a = c.armament
	view = ReplicaView.new()
	add_child_autofree(view)
	view.setup(cfg, a.replicas, BoxWorld.new())


func _frame() -> void:
	view.update(c, 0.0, 0.0, Vector3(0.0, 1.6, 0.0), Vector3.FORWARD, DT, 0.0)


func _held() -> ReplicaView.Held:
	return view._held[a.active]


func _settle() -> void:
	await wait_process_frames(2)


func test_an_inspect_begun_as_the_last_shots_slide_locks_keeps_its_clip() -> void:
	a.active = 1
	_frame()
	view.on_shot()
	a.ammo[1].mag = 0
	view.inspect()
	_frame()
	assert_true(view.inspecting())
	assert_eq(_held().anim.assigned_animation, String(ReplicaView.INSPECT_CLIP), "the slide lock's seek must not replace the Inspect clip")


func test_the_locked_slide_stays_back_through_an_inspect() -> void:
	a.active = 1
	a.ammo[1].mag = 0
	_frame()
	await _settle()
	var back := _held().slide.position
	view.inspect()
	for i in 60:
		_frame()
	await _settle()
	assert_true(view.inspecting())
	assert_almost_eq(_held().slide.position, back, EPS, "held back while the clip plays")


func test_the_selector_keeps_its_mode_through_an_inspect() -> void:
	_frame()
	await _settle()
	var skeleton := _held().selector.get_skeleton()
	var bone := skeleton.find_bone(SelectorPose.BONE)
	var before := skeleton.get_bone_pose_position(bone)
	view.inspect()
	for i in 45:
		_frame()
	await _settle()
	assert_true(view.inspecting())
	assert_almost_eq(skeleton.get_bone_pose_position(bone), before, EPS, "selector not turned by the clip")


func test_a_reload_after_a_cut_inspect_poses_the_reload_clip_to_its_end() -> void:
	view.inspect()
	for i in 30:
		_frame()
	a.reload_left = a.replica().reload_time * 0.5
	_frame()
	assert_false(view.inspecting())
	assert_eq(_held().anim.assigned_animation, String(ReplicaView.RELOAD_CLIP))
	a.reload_left = 0.0
	_frame()
	var clip := _held().anim.get_animation(ReplicaView.RELOAD_CLIP)
	assert_almost_eq(_held().anim.current_animation_position, clip.length, 0.0001)
	# Past the cut's ease-back, which drops a press (no snap from the turn to the first key).
	for i in ceili(cfg.inspect_cancel_time / DT) + 1:
		_frame()
	view.inspect()
	_frame()
	assert_true(view.inspecting(), "can inspect again after")
	assert_eq(_held().anim.assigned_animation, String(ReplicaView.INSPECT_CLIP))


func test_a_shot_after_a_cut_inspect_plays_its_fire_clip() -> void:
	view.inspect()
	for i in 30:
		_frame()
	view.on_shot()
	_frame()
	assert_eq(_held().anim.current_animation, String(ReplicaView.FIRE_CLIP))
	assert_true(_held().anim.is_playing())


func test_a_throw_in_hand_blocks_and_ends_an_inspect() -> void:
	view.inspect()
	for i in 20:
		_frame()
	a.holstered = true
	_frame()
	assert_false(view.inspecting())


func test_y_pressed_with_the_order_wheel_open_is_not_latched() -> void:
	var input := PlayerInput.new()
	add_child_autofree(input)
	input.setup(ControlsConfig.new(), 1.5)
	input.active = true
	input._open_wheel()
	var press := InputEventAction.new()
	press.action = PlayerInput.INSPECT
	press.pressed = true
	input._unhandled_input(press)
	assert_false(input.take_inspect(), "the wheel is open: the replica must not turn")
