extends GutTest
## QA for SP1 (the mix): the pool's priority edges, the reaches to the centimetre and through the eyes the view is
## through, a dropped play leaving the variant alone, interface cues without level spread, the Field bus after every way
## out of play (a live PlaySession: out, a new round, the match over, leaving mid-dip), and an old settings file with
## the five sliders leaving the Field bus alone.

const FRAME := 1.0 / 60.0

var cfg: SoundConfig = SoundConfig.new()
var body: BodyConfig = BodyConfig.new()
var _saved_db: Dictionary[StringName, float] = {}
var _saved_mute: Dictionary[StringName, bool] = {}


## Anything with `playing`, as the pool sees a player.
class FakeVoice:
	extends RefCounted
	var playing: bool = false


func before_each() -> void:
	for bus: StringName in [&"Master", &"Effects", &"Power", &"Ambience", &"Interface", &"Field"]:
		var i := AudioServer.get_bus_index(bus)
		_saved_db[bus] = AudioServer.get_bus_volume_db(i)
		_saved_mute[bus] = AudioServer.is_bus_mute(i)


func after_each() -> void:
	for bus: StringName in _saved_db:
		var i := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_volume_db(i, _saved_db[bus])
		AudioServer.set_bus_mute(i, _saved_mute[bus])
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(&"Field"), 0, false)


func _pool(n: int) -> VoicePool:
	var voices: Array = []
	for i in n:
		voices.append(FakeVoice.new())
	return VoicePool.new(voices)


## Takes a voice for `cue` and marks it playing; its index, or -1.
func _take(pool: VoicePool, cue: StringName, prio: int, most: int = 99) -> int:
	var i := pool.acquire(cue, prio, most)
	if i >= 0:
		pool.players[i].playing = true
	return i


func _audio() -> SimAudio:
	var a := SimAudio.new()
	add_child_autofree(a)
	a.setup(cfg, [] as Array[StringName], body, null, null)
	return a


func _playing(voices: Array) -> int:
	var n := 0
	for v: Variant in voices:
		n += int(v.playing)
	return n


func _field() -> int:
	return AudioServer.get_bus_index(SoundMix.BUS_FIELD)


func _step(state: GameState, c: Character) -> void:
	var e := state.events.add(GameEvent.Kind.FOOTSTEP)
	e.actor = c.id
	e.value = GameEvent.Footstep.SPRINT
	e.position = c.position


func test_a_lower_cue_takes_the_oldest_of_the_lowest_priority_and_an_equal_one_takes_an_equal() -> void:
	var pool := _pool(4)
	_take(pool, &"a", VoicePool.Priority.FIELD)  # 0, oldest of the field's
	_take(pool, &"b", VoicePool.Priority.CALL)  # 1, the lowest
	_take(pool, &"c", VoicePool.Priority.SHOT)  # 2
	_take(pool, &"d", VoicePool.Priority.CALL)  # 3, the lowest, newer
	assert_eq(pool.acquire(&"e", VoicePool.Priority.SHOT, 9), 1, "the oldest of the lowest, not the oldest")
	assert_eq(pool.acquire(&"f", VoicePool.Priority.SHOT, 9), 3, "then the other call")
	assert_eq(pool.acquire(&"g", VoicePool.Priority.SHOT, 9), 0, "then the field's")
	assert_eq(pool.acquire(&"h", VoicePool.Priority.SHOT, 9), 2, "then an equal one, the shot")
	assert_eq(pool.acquire(&"i", VoicePool.Priority.FIELD, 9), -1, "but not one above it")
	assert_eq(pool.acquire(&"j", VoicePool.Priority.CALL, 9), -1, "a call takes nothing from the field")
	assert_eq(pool.stolen, 4)
	assert_eq(pool.dropped, 2)


func test_a_dropped_play_leaves_the_cues_variant_alone() -> void:
	var audio := _audio()
	var state := GameState.new(1)
	var you := Character.new(0, 0, Vector3.ZERO)
	state.characters.append(you)
	var busy: Array[StringName] = [&"magRattle", &"selector", &"draw", &"bodyHit"]
	for cue in busy:
		for i in cfg.shot_cue_voices:
			audio._play(cue, Vector3(0.0, 0.0, 3.0), false, 1.0, SimAudio.Kind.SHOT, SimAudio.BUS_EFFECTS)
	assert_eq(_playing(audio._field), cfg.field_voices, "every voice busy with shots")
	var before := audio._last_variant[&"vault"]
	audio._play(&"vault", Vector3(0.0, 0.0, 3.0), false, 1.0, SimAudio.Kind.VAULT, SimAudio.BUS_FOOTSTEPS)
	assert_eq(audio._field_pool.dropped, 1)
	assert_eq(audio._last_variant[&"vault"], before, "no variant used up by a play that never sounded")


func test_reaches_hold_to_the_centimetre_for_steps_the_field_and_the_range() -> void:
	var audio := _audio()
	var state := GameState.new(1)
	var you := Character.new(0, 0, Vector3.ZERO)
	state.characters.append(you)
	var ear := you.eye(body)
	var reaches := {&"step": cfg.step_reach, &"field": cfg.max_distance, &"range": cfg.target_reach}
	assert_eq(reaches, {&"step": 22.0, &"field": 60.0, &"range": 80.0}, "the browser's reaches")
	# A step's feet are at the ears' height here, so the distance is the one along z.
	for edge: float in [-0.01, 0.0, 0.01]:
		for v: AudioStreamPlayer3D in audio._field:
			v.stop()
		var c := Character.new(1, 1, ear + Vector3(0.0, 0.0, cfg.step_reach + edge))
		state.characters.append(c)
		state.time += 1.0
		state.events.clear()
		_step(state, c)
		audio.on_tick(state, 0, you)
		assert_eq(_playing(audio._field), 1 if edge <= 0.0 else 0, "a step %+.2f m from 22 m" % edge)
		state.characters.erase(c)
	for edge: float in [-0.01, 0.0, 0.01]:
		for v: AudioStreamPlayer3D in audio._field:
			v.stop()
		state.events.clear()
		var h := state.events.add(GameEvent.Kind.VAULT)
		h.actor = 5
		h.position = ear + Vector3(0.0, 0.0, cfg.max_distance + edge)
		audio.on_tick(state, 0, you)
		assert_eq(_playing(audio._field), 1 if edge <= 0.0 else 0, "a vault %+.2f m from 60 m" % edge)
	for edge: float in [-0.01, 0.0, 0.01]:
		for v: AudioStreamPlayer3D in audio._field:
			v.stop()
		state.events.clear()
		var t := state.events.add(GameEvent.Kind.TARGET_HIT)
		t.value = RangeTarget.Kind.STEEL
		t.actor = 5
		t.position = ear + Vector3(0.0, 0.0, cfg.target_reach + edge)
		audio.on_tick(state, 0, you)
		assert_eq(_playing(audio._field), 1 if edge <= 0.0 else 0, "steel %+.2f m from 80 m" % edge)


func test_reach_is_measured_from_the_eyes_the_view_is_through() -> void:
	var audio := _audio()
	var state := GameState.new(1)
	var you := Character.new(0, 0, Vector3.ZERO)
	var mate := Character.new(1, 0, Vector3(0.0, 0.0, 200.0))
	var near_you := Character.new(2, 1, Vector3(0.0, 0.0, 6.0))
	var near_mate := Character.new(3, 1, Vector3(0.0, 0.0, 206.0))
	for c: Character in [you, mate, near_you, near_mate]:
		state.characters.append(c)
	_step(state, near_you)
	audio.on_tick(state, 0, mate)
	assert_eq(_playing(audio._field), 0, "6 m from you, 194 m from the teammate you watch")
	state.events.clear()
	state.time += 1.0
	_step(state, near_mate)
	audio.on_tick(state, 0, mate)
	assert_eq(_playing(audio._field), 1, "6 m from the one you watch")
	audio.on_tick(state, 0, null)
	assert_eq(_playing(audio._field), 2, "with nobody's ears nothing is out of reach")


func test_interface_cues_play_at_their_exact_level_every_time() -> void:
	var audio := _audio()
	var state := GameState.new(1)
	state.characters.append(Character.new(0, 0, Vector3.ZERO))
	for i in 20:
		for v: AudioStreamPlayer in audio._own:
			v.stop()
		state.events.clear()
		var hit := state.events.add(GameEvent.Kind.CHARACTER_HIT)
		hit.actor = 3
		hit.target = 0
		var shot := state.events.add(GameEvent.Kind.CHARACTER_HIT)
		shot.actor = 0
		shot.target = 3
		audio.on_tick(state, 0, null)
		var tick := -1.0
		var marker := -1.0
		for v: AudioStreamPlayer in audio._own:
			if v.playing and v.bus == SimAudio.BUS_INTERFACE:
				if absf(v.volume_db - linear_to_db(cfg.hit_tick_gain)) < 1e-4:
					tick = v.volume_db
				if absf(v.volume_db - linear_to_db(cfg.hit_marker_gain)) < 1e-4:
					marker = v.volume_db
		assert_ne(tick, -1.0, "your hit tick at its level on play %d" % i)
		assert_ne(marker, -1.0, "your hit marker at its level on play %d" % i)
	for v: AudioStreamPlayer in audio._own:
		v.stop()
	for i in 10:
		audio._play(&"radio_ack", Vector3.ZERO, true, cfg.radio_ack_gain, SimAudio.Kind.RADIO, SimAudio.BUS_INTERFACE)
		assert_almost_eq(audio._own[i % cfg.cue_voices].volume_db, linear_to_db(cfg.radio_ack_gain), 1e-4, "the radio click")


## A live PlaySession played by a bot, `frames` physics frames on.
func _session(frames: int = 3) -> PlaySession:
	var s := PlaySession.new()
	s.settings = Settings.new(PlayTuning.new())
	s.map_id = "depot"
	s.match_seed = 5
	s.autopilot = true
	add_child_autofree(s)
	await wait_physics_frames(frames)
	return s


## A live session wires the tick into the mix; then the frames are stepped by hand (a real wait is 60 Hz).
func test_the_field_follows_a_live_session_out_back_in_match_over_and_leaving() -> void:
	var s := await _session()
	var field := _field()
	var mix := s._mix
	assert_false(AudioServer.is_bus_effect_enabled(field, 0), "in play: clear")
	s.player.status = Character.Status.OUT
	await wait_physics_frames(6)
	assert_true(mix.envelope.out, "the session hands the mix the tick")
	_settle(mix, s.state, 30)
	assert_true(AudioServer.is_bus_effect_enabled(field, 0), "out: low-passed")
	assert_lt(AudioServer.get_bus_volume_db(field), -1.0, "out: turned down")
	assert_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Interface")), _saved_db[&"Interface"],
			"the interface is never muffled")
	s.player.status = Character.Status.ALIVE
	_settle(mix, s.state, 120)
	assert_false(AudioServer.is_bus_effect_enabled(field, 0), "the next round: the filter off")
	assert_eq(AudioServer.get_bus_volume_db(field), 0.0, "the next round: 0 dB")
	s.player.status = Character.Status.OUT
	_settle(mix, s.state, 30)
	assert_true(AudioServer.is_bus_effect_enabled(field, 0))
	s.state.round_state.phase = RoundState.Phase.MATCH_OVER
	_settle(mix, s.state, 120)
	assert_false(AudioServer.is_bus_effect_enabled(field, 0), "match over: the filter off")
	assert_eq(AudioServer.get_bus_volume_db(field), 0.0, "match over: the whistle's dip let go")
	s.state.round_state.phase = RoundState.Phase.LIVE
	var hit := s.state.events.add(GameEvent.Kind.CHARACTER_HIT)
	hit.actor = 1
	hit.target = 0
	_settle(mix, s.state, 6)
	assert_lt(AudioServer.get_bus_volume_db(field), -3.0, "out and dipped")
	s.queue_free()
	await wait_physics_frames(2)
	assert_eq(AudioServer.get_bus_volume_db(field), 0.0, "leaving mid-dip: 0 dB")
	assert_false(AudioServer.is_bus_effect_enabled(field, 0), "leaving mid-dip: the filter off")


## `frames` frames of the mix reading `state`'s tick once.
func _settle(mix: SoundMix, state: GameState, frames: int) -> void:
	mix.on_tick(state, 0)
	state.events.clear()
	for i in frames:
		mix._process(FRAME)


func test_an_old_settings_file_and_the_five_sliders_leave_the_field_bus_alone() -> void:
	var s := Settings.new(PlayTuning.new())
	s.from_dict({"volumes": {"Master": 0.0, "Effects": 0.0, "Power": 0.3, "Ambience": 0.0, "Interface": 0.2}})
	assert_eq(s.volumes[&"Effects"], 0.0)
	SettingsApply.apply_audio(s)
	var field := _field()
	assert_false(AudioServer.is_bus_mute(field), "a muted Effects slider leaves the Field bus unmuted")
	assert_eq(AudioServer.get_bus_volume_db(field), _saved_db[&"Field"])
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Effects")))
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Power")))
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Power")),
			linear_to_db(0.3 * Settings.VOLUME_GAINS[&"Power"]), 1e-4)
	s.from_dict({})
	assert_eq(s.volumes[&"Effects"], Settings.VOLUME_DEFAULTS[&"Effects"], "an empty file: the defaults")
	s.from_dict({"volumes": "loud"})
	assert_eq(s.volumes[&"Master"], Settings.VOLUME_DEFAULTS[&"Master"], "a damaged volumes entry: the defaults")
