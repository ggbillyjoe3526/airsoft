extends GutTest
## Inspect (IN1): the Inspect key (Y) turns the replica in hand over to look at (ReplicaView, InspectPose) while its
## model's Inspect clip works its parts and the parts' sounds go out; a shot, a hit, a reload, a draw, a switch, the
## holster, a sprint or raising the sight ends it, the pose easing back and the parts at rest at once.

const DT := 1.0 / 60.0
const EPS := 0.0001
## The replicas whose models carry an Inspect clip, each with its own pose.
const INSPECTED: Array[StringName] = [&"aeg", &"pistol", &"cyber", &"sniper"]

var view: ReplicaView
var c: Character
var a: Armament
var cfg: ViewModelConfig
var heard: Array[StringName] = []


func before_each() -> void:
	cfg = ViewModelConfig.new()
	c = Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	a = c.armament
	view = ReplicaView.new()
	add_child_autofree(view)
	view.setup(cfg, a.replicas, BoxWorld.new())
	heard.clear()
	view.inspect_sound.connect(func(cue: StringName) -> void: heard.append(cue))


func _frame(aim: float = 0.0) -> void:
	view.update(c, 0.0, 0.0, Vector3(0.0, 1.6, 0.0), Vector3.FORWARD, DT, aim)


func _frames(n: int, aim: float = 0.0) -> void:
	for i in n:
		_frame(aim)


func _held() -> ReplicaView.Held:
	return view._held[a.active]


## Frames an inspect of the replica in hand takes.
func _length_frames() -> int:
	var anim := _held().anim
	return ceili(anim.get_animation(ReplicaView.INSPECT_CLIP).length / DT)


# --- the key ---


func test_inspect_sits_on_y_in_the_settings_and_the_input_map() -> void:
	var b := KeyBindings.new()
	assert_true(KeyBindings.ACTIONS.has(&"inspect"), "listed in Settings › Controls")
	assert_eq(b.codes(&"inspect"), PackedInt32Array([KEY_Y]))
	assert_eq(b.action_of(KEY_Y), &"inspect")
	assert_true(InputMap.has_action(PlayerInput.INSPECT), "project.godot has the action")


func test_a_save_from_before_inspect_takes_y_unless_the_player_put_something_there() -> void:
	var saved := KeyBindings.new().to_dict()
	saved.erase("inspect")
	var b := KeyBindings.new()
	assert_true(b.load_dict(saved))
	assert_eq(b.codes(&"inspect"), PackedInt32Array([KEY_Y]), "added by this build: its default")
	saved["torch"] = [KEY_Y]
	assert_true(b.load_dict(saved))
	assert_eq(b.codes(&"inspect"), PackedInt32Array(), "Y is the player's torch: no key, never two actions on one")
	assert_eq(b.codes(&"torch"), PackedInt32Array([KEY_Y]))


func test_the_press_is_taken_once_and_only_while_the_mouse_is_captured() -> void:
	var input := PlayerInput.new()
	add_child_autofree(input)
	input.setup(ControlsConfig.new(), 1.5)
	var press := InputEventAction.new()
	press.action = PlayerInput.INSPECT
	press.pressed = true
	input.active = true
	input._unhandled_input(press)
	var cmd := PlayerCommand.new()
	input.fill(cmd)
	assert_true(input.take_inspect(), "a tick in between keeps it: the frame takes it")
	assert_false(input.take_inspect(), "once")
	input._unhandled_input(press)
	input.release()
	assert_false(input.take_inspect(), "let go of the mouse: dropped")
	input.active = false
	input._unhandled_input(press)
	assert_false(input.take_inspect(), "a menu's press is nothing")


# --- the poses ---


func test_every_pose_samples_and_names_sounds_the_game_has() -> void:
	var poses: Array[InspectPose] = [cfg.inspect_pose_default]
	poses.append_array(cfg.inspect_poses.values())
	for p in poses:
		assert_true(p.valid(), "keys, turns and shifts line up from 0 to 1")
		for i in p.sound_at.size():
			assert_between(p.sound_at[i], 0.0, 1.0, "a sound inside the inspect")
			var cue := p.sound_cue[i]
			var own := cue in [SimAudio.INSPECT_DRY, SimAudio.INSPECT_MAG_IN, SimAudio.INSPECT_MAG_OUT]
			var file := "%s%s_1.wav" % [SoundConfig.CUE_DIR, cue]
			assert_true(own or ResourceLoader.exists(file), "cue %s has a sound" % cue)


func test_every_model_with_an_inspect_clip_has_its_own_pose() -> void:
	for id in INSPECTED:
		assert_true(cfg.inspect_poses.has(id), "%s has a pose" % id)
		var p: InspectPose = cfg.inspect_poses[id]
		assert_almost_eq(p.turn_at(0.0), Vector3.ZERO, Vector3.ONE * EPS, "starts at the hold")
		assert_almost_eq(p.turn_at(1.0), Vector3.ZERO, Vector3.ONE * EPS, "ends at the hold")
		assert_almost_eq(p.shift_at(1.0), Vector3.ZERO, Vector3.ONE * EPS)
		assert_lt(p.turn_at(0.5).y, -0.5, "turned side on, the right side to the eye")


func test_the_saved_play_tuning_holds_every_pose_as_the_script_does() -> void:
	# An export reads the .tres, where the script's InspectPose.make defaults never run (test_saved_configs).
	var saved := PlayTuning.load_default().viewmodel
	assert_eq(saved.inspect_poses.keys().size(), cfg.inspect_poses.keys().size())
	for id: StringName in cfg.inspect_poses:
		var mine: InspectPose = cfg.inspect_poses[id]
		var theirs: InspectPose = saved.inspect_poses.get(id)
		assert_not_null(theirs, "%s saved" % id)
		assert_eq(theirs.turn, mine.turn, "%s turns" % id)
		assert_eq(theirs.shift, mine.shift, "%s shifts" % id)
		assert_eq(theirs.sound_cue, mine.sound_cue, "%s sounds" % id)
		assert_almost_eq(theirs.duration, mine.duration, EPS)
	assert_not_null(saved.inspect_pose_default)
	assert_true(saved.inspect_pose_default.valid())


func test_a_pose_eases_between_its_keys() -> void:
	var p := InspectPose.make(1.0, PackedFloat32Array([0.0, 0.5, 1.0]), [Vector3.ZERO, Vector3(0.0, -1.0, 0.0),
			Vector3.ZERO], [Vector3.ZERO, Vector3(-0.2, 0.0, 0.0), Vector3.ZERO], PackedFloat32Array(), [])
	assert_almost_eq(p.turn_at(0.5).y, -1.0, EPS, "on a key: the key")
	assert_almost_eq(p.turn_at(0.25).y, -0.5, EPS, "halfway between: halfway")
	assert_gt(p.turn_at(0.05).y, -0.05, "eased: slow out of the hold")
	assert_almost_eq(p.shift_at(0.75).x, -0.1, EPS)
	assert_almost_eq(p.turn_at(-1.0), Vector3.ZERO, Vector3.ONE * EPS, "clamped")
	assert_almost_eq(p.turn_at(2.0), Vector3.ZERO, Vector3.ONE * EPS)


# --- in the hands ---


func test_an_inspect_turns_the_replica_plays_its_clip_and_ends_back_at_the_hold() -> void:
	_frames(5)
	var hold_pos := _held().root.position
	var hold_rot := _held().root.rotation
	view.inspect()
	_frame()
	assert_true(view.inspecting())
	assert_eq(_held().anim.assigned_animation, String(ReplicaView.INSPECT_CLIP), "the model's clip plays")
	assert_true(_held().anim.is_playing())
	_frames(_length_frames() / 2)
	assert_lt(_held().root.rotation.y, hold_rot.y - 0.5, "turned side on halfway through")
	_frames(_length_frames())
	assert_false(view.inspecting(), "over")
	assert_almost_eq(_held().root.position, hold_pos, Vector3.ONE * EPS, "back at the hold")
	assert_almost_eq(_held().root.rotation, hold_rot, Vector3.ONE * EPS)


func test_its_sounds_go_out_once_each_in_order() -> void:
	var p: InspectPose = cfg.inspect_poses[_held().id]
	view.inspect()
	_frames(_length_frames() + 2)
	assert_eq(heard, p.sound_cue, "every cue once, in order")


func test_asked_again_while_under_way_it_runs_on() -> void:
	view.inspect()
	_frames(30)
	var age := view._inspect_age
	view.inspect()
	_frame()
	assert_almost_eq(view._inspect_age, age + DT, EPS, "not restarted")


func test_sprinting_or_holstered_or_aimed_nothing_starts() -> void:
	c.sprinting = true
	view.inspect()
	_frame()
	assert_false(view.inspecting(), "sprinting")
	c.sprinting = false
	_frame()
	assert_false(view.inspecting(), "the press is not kept for later")
	view.inspect()
	_frame(0.5)
	assert_false(view.inspecting(), "the sight coming up")
	a.holstered = true
	view.inspect()
	_frame()
	assert_false(view.inspecting(), "holstered")


func _cut_by(what: Callable, why: String) -> void:
	view.inspect()
	_frames(40)
	assert_true(view.inspecting())
	what.call()
	_frame()
	assert_false(view.inspecting(), why)
	assert_false(_held().anim.is_playing() and _held().anim.current_animation == ReplicaView.INSPECT_CLIP,
			"%s: the clip stops" % why)


func test_a_shot_ends_it_and_the_pose_eases_back_over_the_cancel_time() -> void:
	_frames(5)
	var hold_rot := _held().root.rotation
	_cut_by(view.on_shot, "a shot")
	assert_lt(_held().root.rotation.y, hold_rot.y - 0.1, "not snapped back")
	_frames(ceili(cfg.inspect_cancel_time / DT) + 1)
	assert_almost_eq(view._inspect_turn, Vector3.ZERO, Vector3.ONE * EPS, "eased back in the cancel time")
	assert_almost_eq(view._inspect_shift, Vector3.ZERO, Vector3.ONE * EPS)


func test_a_press_while_easing_back_from_a_shot_is_dropped_never_snapped() -> void:
	_cut_by(view.on_shot, "a shot")
	view.inspect()
	_frame()
	assert_false(view.inspecting(), "still easing back: no snap to the first key")
	_frames(ceili(cfg.inspect_cancel_time / DT) + 1)
	view.inspect()
	_frame()
	assert_true(view.inspecting(), "back at the hold: a press inspects again")


func test_a_reload_a_sprint_or_raising_the_sight_ends_it() -> void:
	_cut_by(func() -> void: a.reload_left = a.replica().reload_time, "a reload")
	a.reload_left = 0.0
	_frames(20)
	_cut_by(func() -> void: c.sprinting = true, "a sprint")
	c.sprinting = false
	view.inspect()
	_frames(40)
	_frame(1.0)
	assert_false(view.inspecting(), "the sight raised")


func test_a_switch_ends_it_and_leaves_the_old_replicas_parts_at_rest() -> void:
	var rifle := _held()
	_cut_by(func() -> void: a.active = 1, "a switch")
	assert_eq(rifle.anim.assigned_animation, String(ReplicaView.INSPECT_CLIP))
	assert_almost_eq(rifle.anim.current_animation_position, 0.0, EPS, "the clip back at its start: parts at rest")
	assert_false(rifle.anim.is_playing())
	assert_eq(view._inspect_turn, Vector3.ZERO, "the next replica comes up with none of its turn")
	assert_eq(view._inspect_shift, Vector3.ZERO)


func test_a_hit_ends_it_and_a_hidden_view_drops_it_whole() -> void:
	_cut_by(view.on_hit, "a hit")
	view.inspect()
	_frames(10)
	c.status = Character.Status.OUT
	_frame()
	assert_false(view.inspecting(), "out of play")
	assert_eq(view._inspect_turn, Vector3.ZERO, "nothing left to ease back")


func test_each_replica_in_the_loadout_inspects_with_its_own_clip() -> void:
	for slot in a.replicas.size():
		a.active = slot
		_frames(2)
		view.inspect()
		_frame()
		assert_true(view.inspecting(), "slot %d" % slot)
		assert_eq(_held().anim.assigned_animation, String(ReplicaView.INSPECT_CLIP))
		assert_almost_eq(view._inspect_length, _held().anim.get_animation(ReplicaView.INSPECT_CLIP).length, EPS)
		_frames(_length_frames() + 1)
