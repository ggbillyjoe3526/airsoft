extends GutTest
## LM1 QA: the lift button's motor at the edges (no world, a missing presser, a bad lift index, two lifts, inside
## then landing presses, a press out of reach, a motor voice taken by another play).

var cfg: LiftConfig = SimTuning.new().lifts


func _shaft(w: BoxWorld, x: float) -> void:
	var s := LiftSpec.new()
	s.name = "test"
	s.well = Rect2(x, 0.0, 2.0, 2.0)
	s.out = Vector2(0.0, -1.0)
	s.door_from = x + 0.5
	s.door_to = x + 1.5
	s.door_height = 2.1
	s.door_depth = 0.3
	s.stops = PackedFloat32Array([3.0, 7.0])
	s.stop_names = PackedStringArray(["Low", "High"])
	w.add_lift(s, cfg)


func _rig(feet: Vector3, lifts: int = 1, with_world: bool = true) -> Array:
	var audio := SimAudio.new()
	add_child_autofree(audio)
	var w: BoxWorld = null
	if with_world:
		w = BoxWorld.new(BodyConfig.new())
		for k in lifts:
			_shaft(w, 4.0 * k)
	audio.setup(SoundConfig.new(), [] as Array[StringName], BodyConfig.new(), w, null, null)
	var state := GameState.new(1)
	state.characters.append(Character.new(0, 0, feet))
	state.lifts.y.resize(lifts)
	for k in lifts:
		state.lifts.y[k] = 3.0
	return [audio, state]


func _press(state: GameState, lift: int, at: Vector3, actor: int = 0) -> void:
	var e := state.events.add(GameEvent.Kind.LIFT)
	e.value = Lifts.Cue.BUTTON
	e.actor = actor
	e.target = lift
	e.position = at
	e.reach = cfg.button_heard


func _playing(audio: SimAudio) -> int:
	var n := 0
	for v: AudioStreamPlayer3D in audio._field:
		if v.playing:
			n += 1
	return n


func test_a_press_with_no_world_does_not_error_and_plays_at_the_button() -> void:
	var rig := _rig(Vector3(1.0, 3.0, 1.0), 1, false)
	var audio: SimAudio = rig[0]
	var state: GameState = rig[1]
	_press(state, 0, Vector3(1.5, 4.2, 0.0))
	audio.on_tick(state, 0, state.characters[0])
	assert_eq(_playing(audio), 1)


func test_a_press_by_a_missing_presser_plays_and_is_not_carried() -> void:
	var rig := _rig(Vector3(1.0, 3.0, 1.0))
	var audio: SimAudio = rig[0]
	var state: GameState = rig[1]
	var button := Vector3(1.5, 4.2, 0.0)
	_press(state, 0, button, 99)
	audio.on_tick(state, 0, state.characters[0])
	assert_eq(_playing(audio), 1)
	state.events.clear()
	state.lifts.y[0] = 6.0
	audio.on_tick(state, 0, state.characters[0])
	for v: AudioStreamPlayer3D in audio._field:
		if v.playing:
			assert_almost_eq(v.global_position.y, button.y, 1e-3)


func test_a_press_for_a_lift_out_of_range_never_errors() -> void:
	var rig := _rig(Vector3(1.0, 3.0, 1.0))
	var audio: SimAudio = rig[0]
	var state: GameState = rig[1]
	_press(state, 5, Vector3(1.5, 4.2, 0.0))
	audio.on_tick(state, 0, state.characters[0])
	state.events.clear()
	_press(state, -1, Vector3(1.5, 4.2, 0.0))
	audio.on_tick(state, 0, state.characters[0])
	assert_gt(_playing(audio), 0, "still sounds, nothing carried")


func test_a_press_from_inside_then_one_from_a_landing_leaves_the_riding_motor_on_the_car() -> void:
	var rig := _rig(Vector3(1.0, 3.0, 1.0))
	var audio: SimAudio = rig[0]
	var state: GameState = rig[1]
	_press(state, 0, Vector3(1.5, 4.2, 0.0))
	audio.on_tick(state, 0, state.characters[0])
	var riding := audio._motor_voice[0]
	assert_gte(riding, 0, "the inside press rides")
	state.events.clear()
	# Someone on the landing, in reach of your ears, calls the same lift (critic, LM1 attempt 1).
	state.characters.append(Character.new(1, 1, Vector3(1.0, 3.0, -1.0)))
	var button := Vector3(1.8, 4.2, -0.3)
	_press(state, 0, button, 1)
	audio.on_tick(state, 0, state.characters[0])
	assert_eq(_playing(audio), 2, "the call plays beside the riding motor, never in its place")
	assert_eq(audio._motor_voice[0], riding)
	state.events.clear()
	state.lifts.y[0] = 5.0
	audio.on_tick(state, 0, state.characters[0])
	var rise := SoundConfig.new().lift_motor_rise
	assert_almost_eq(audio._field[riding].global_position.y, 5.0 + rise, 1e-3, "still carried with the car")
	var call := audio._landing_voice[0]
	assert_gte(call, 0)
	assert_almost_eq(audio._field[call].global_position.distance_to(button), 0.0, 1e-3, "the call stays at its button")


func test_a_press_out_of_reach_never_cuts_the_motor_you_ride_with() -> void:
	var rig := _rig(Vector3(1.0, 3.0, 1.0))
	var audio: SimAudio = rig[0]
	var state: GameState = rig[1]
	_press(state, 0, Vector3(1.5, 4.2, 0.0))
	audio.on_tick(state, 0, state.characters[0])
	var riding := audio._motor_voice[0]
	assert_gte(riding, 0)
	state.events.clear()
	# A bot calls the lift from a landing far beyond the button's reach.
	state.characters.append(Character.new(1, 1, Vector3(1.0, 40.0, -1.0)))
	_press(state, 0, Vector3(1.8, 41.2, -0.3), 1)
	audio.on_tick(state, 0, state.characters[0])
	assert_true(audio._field[riding].playing, "your motor plays on")
	assert_eq(audio._motor_voice[0], riding, "and still rides")
	assert_eq(_playing(audio), 1, "the far press is not heard")


func test_a_press_on_one_lift_leaves_the_other_lifts_motor_playing() -> void:
	var rig := _rig(Vector3(1.0, 3.0, 1.0), 2)
	var audio: SimAudio = rig[0]
	var state: GameState = rig[1]
	_press(state, 0, Vector3(1.5, 4.2, 0.0))
	audio.on_tick(state, 0, state.characters[0])
	state.events.clear()
	_press(state, 1, Vector3(5.5, 4.2, 0.0))
	audio.on_tick(state, 0, state.characters[0])
	assert_eq(_playing(audio), 2, "each lift its own motor")


func test_a_motor_voice_taken_by_another_play_is_let_go_not_stopped() -> void:
	var rig := _rig(Vector3(1.0, 3.0, 1.0))
	var audio: SimAudio = rig[0]
	var state: GameState = rig[1]
	_press(state, 0, Vector3(1.5, 4.2, 0.0))
	audio.on_tick(state, 0, state.characters[0])
	var v := audio._motor_voice[0]
	assert_gte(v, 0, "the motor's voice is kept")
	audio._motor_serial[0] = -12345  # the voice since taken by another play
	state.events.clear()
	audio.on_tick(state, 0, state.characters[0])
	assert_true(audio._field[v].playing, "a taken voice is let go, not stopped")
	assert_eq(audio._motor_voice[0], -1)
