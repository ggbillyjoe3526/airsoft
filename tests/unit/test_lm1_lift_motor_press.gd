extends GutTest
## LM1 (owner, 2026-11-23): a lift's motor, lift_motor_1 only, plays as soon as a button is pressed; the button's beep
## and the motor on the car setting off are gone (game/play/sim_audio.gd).

var cfg: LiftConfig = SimTuning.new().lifts


## A world with one lift shaft, its 2 m well around (1, 1), stops at 3 m and 7 m.
func _shaft() -> BoxWorld:
	var w := BoxWorld.new(BodyConfig.new())
	var s := LiftSpec.new()
	s.name = "test"
	s.well = Rect2(0.0, 0.0, 2.0, 2.0)
	s.out = Vector2(0.0, -1.0)
	s.door_from = 0.5
	s.door_to = 1.5
	s.door_height = 2.1
	s.door_depth = 0.3
	s.stops = PackedFloat32Array([3.0, 7.0])
	s.stop_names = PackedStringArray(["Low", "High"])
	w.add_lift(s, cfg)
	return w


## A SimAudio over the shaft and a state whose one character, the listener and presser, stands at `feet`.
func _rig(feet: Vector3) -> Array:
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(SoundConfig.new(), [] as Array[StringName], BodyConfig.new(), _shaft(), null, null)
	var state := GameState.new(1)
	state.characters.append(Character.new(0, 0, feet))
	state.lifts.y.resize(1)
	state.lifts.y[0] = 3.0
	return [audio, state]


func _cue(state: GameState, cue: Lifts.Cue, at: Vector3, reach: float) -> void:
	var e := state.events.add(GameEvent.Kind.LIFT)
	e.value = cue
	e.actor = 0
	e.target = 0
	e.position = at
	e.reach = reach


func _playing(audio: SimAudio) -> Array[AudioStreamPlayer3D]:
	var out: Array[AudioStreamPlayer3D] = []
	for v: AudioStreamPlayer3D in audio._field:
		if v.playing:
			out.append(v)
	return out


func test_the_lift_cues_name_the_motor_for_a_button_and_nothing_for_setting_off() -> void:
	assert_eq(SimAudio.LIFT_CUES[Lifts.Cue.BUTTON], &"lift_motor")
	assert_eq(SimAudio.LIFT_CUES[Lifts.Cue.DEPART], &"")
	assert_false(&"lift_button" in SimAudio.LIFT_CUES, "the beep is gone")
	assert_false(ResourceLoader.exists("%slift_button_1.wav" % SoundConfig.CUE_DIR), "and its file")
	assert_false(ResourceLoader.exists("%slift_motor_2.wav" % SoundConfig.CUE_DIR), "the second motor take too")


func test_a_press_from_inside_plays_the_motor_at_once_and_it_rides_with_the_car() -> void:
	var rig := _rig(Vector3(1.0, 3.0, 1.0))
	var audio: SimAudio = rig[0]
	var state: GameState = rig[1]
	_cue(state, Lifts.Cue.BUTTON, Vector3(1.5, 4.2, 0.0), cfg.button_heard)
	audio.on_tick(state, 0, state.characters[0])
	var on := _playing(audio)
	assert_eq(on.size(), 1, "one voice on the press")
	if on.size() != 1:
		return
	var motor: Array = audio._streams[&"lift_motor"]
	assert_eq(motor.size(), 1, "lift_motor_1 only")
	assert_true(on[0].stream in motor, "the motor, not a beep")
	var rise := SoundConfig.new().lift_motor_rise
	assert_almost_eq(on[0].global_position.y, 3.0 + rise, 1e-3, "from over the car's floor")
	state.events.clear()
	state.lifts.y[0] = 5.0
	audio.on_tick(state, 0, state.characters[0])
	assert_almost_eq(on[0].global_position.y, 5.0 + rise, 1e-3, "carried with the car")


func test_the_car_setting_off_is_silent() -> void:
	var rig := _rig(Vector3(1.0, 3.0, 1.0))
	var audio: SimAudio = rig[0]
	var state: GameState = rig[1]
	_cue(state, Lifts.Cue.DEPART, Vector3(1.0, 3.0, 1.0), cfg.heard)
	audio.on_tick(state, 0, state.characters[0])
	assert_eq(_playing(audio).size(), 0)


func test_a_second_press_starts_the_motor_again_never_two_at_once() -> void:
	var rig := _rig(Vector3(1.0, 3.0, 1.0))
	var audio: SimAudio = rig[0]
	var state: GameState = rig[1]
	_cue(state, Lifts.Cue.BUTTON, Vector3(1.5, 4.2, 0.0), cfg.button_heard)
	audio.on_tick(state, 0, state.characters[0])
	state.events.clear()
	_cue(state, Lifts.Cue.BUTTON, Vector3(1.5, 4.4, 0.0), cfg.button_heard)
	audio.on_tick(state, 0, state.characters[0])
	assert_eq(_playing(audio).size(), 1, "the first cut, the second plays")


func test_a_press_from_a_landing_plays_at_the_call_button_and_stays_there() -> void:
	var rig := _rig(Vector3(1.0, 7.0, -1.0))
	var audio: SimAudio = rig[0]
	var state: GameState = rig[1]
	var button := Vector3(1.8, 8.2, -0.3)
	_cue(state, Lifts.Cue.BUTTON, button, cfg.button_heard)
	audio.on_tick(state, 0, state.characters[0])
	var on := _playing(audio)
	assert_eq(on.size(), 1, "heard on the landing, the car away below")
	if on.size() != 1:
		return
	assert_almost_eq(on[0].global_position.distance_to(button), 0.0, 1e-3, "from the button")
	state.events.clear()
	state.lifts.y[0] = 5.0
	audio.on_tick(state, 0, state.characters[0])
	assert_almost_eq(on[0].global_position.distance_to(button), 0.0, 1e-3, "not carried with the car")


func test_the_round_ending_cuts_a_motor_still_playing() -> void:
	var rig := _rig(Vector3(1.0, 3.0, 1.0))
	var audio: SimAudio = rig[0]
	var state: GameState = rig[1]
	_cue(state, Lifts.Cue.BUTTON, Vector3(1.5, 4.2, 0.0), cfg.button_heard)
	audio.on_tick(state, 0, state.characters[0])
	state.events.clear()
	state.events.add(GameEvent.Kind.ROUND_OVER)
	audio.on_tick(state, 0, state.characters[0])
	assert_eq(_playing(audio).size(), 0)
