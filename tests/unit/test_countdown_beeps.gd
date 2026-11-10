extends GutTest
## The match's start countdown beeps (CB1, William 2026-11-10): the same beep in your ear on 3, 2 and 1, GO is the
## whistle alone, the range has none, and the first round's 3 (counted under the loading screen) beeps as the match is
## first heard.

const K := GameEvent.Kind


func _audio() -> SimAudio:
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(SoundConfig.new(), [] as Array[StringName], BodyConfig.new(), null, null)
	return audio


## How many of `audio`'s own voices hold one of the countdown beep's takes.
func _beeps(audio: SimAudio) -> int:
	var takes := audio._streams[&"count_beep"] as Array
	var n := 0
	for v in audio._own:
		if v.stream != null and takes.has(v.stream):
			n += 1
	return n


func test_three_two_one_each_beep_the_same_beep_and_go_is_the_whistle_alone() -> void:
	var audio := _audio()
	var cfg := SoundConfig.new()
	var state := GameState.new(1)
	for digit: int in [3, 2, 1]:
		state.events.clear()
		state.events.add(K.ROUND_COUNT).value = digit
		audio.on_tick(state, 0, null)
		var v := audio._own[audio._played_voice]
		assert_true((audio._streams[&"count_beep"] as Array).has(v.stream), "a beep on %d" % digit)
		assert_almost_eq(v.pitch_scale, 1.0, 1e-6, "the same pitch on %d" % digit)
		assert_almost_eq(v.volume_db, linear_to_db(cfg.beep_gain), 0.01, "the same level on %d" % digit)
	assert_eq(_beeps(audio), 3, "three beeps")
	state.events.clear()
	state.events.add(K.ROUND_GO)
	audio.on_tick(state, 0, null)
	assert_eq(_beeps(audio), 3, "no beep at GO")
	assert_true((audio._streams[&"whistle_short"] as Array).has(audio._whistle.stream)
			or (audio._streams[&"whistle_long"] as Array).has(audio._whistle.stream), "GO is the whistle")


func test_the_range_has_no_countdown_beep() -> void:
	var audio := _audio()
	var state := GameState.new(1)
	state.round_state.practice = true
	state.events.add(K.ROUND_COUNT).value = 3
	audio.on_tick(state, 0, null)
	assert_eq(_beeps(audio), 0)


func test_the_first_rounds_three_beeps_as_the_match_is_first_heard() -> void:
	var session := PlaySession.new()
	session.bots_active = false
	add_child_autofree(session)
	await wait_physics_frames(1)
	assert_true(session.state.round_state.held(), "the first round is counting down")
	assert_eq(_beeps(session._audio), 1, "its 3 beeped once, as the match was first heard")
