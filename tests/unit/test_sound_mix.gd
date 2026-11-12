extends GutTest
## The field's mix (game/play/sound_mix.gd; SP1): the bus layout (Field under Master carrying Effects and Ambience,
## Interface round it, the occlusion buses) with Settings' five volumes unchanged; the DuckEnvelope's dip shape, two
## dips overlapping, out of play times a dip; SoundMix reading the tick (your hit, the whistles, out until the match is
## over) and leaving Field clear when it leaves play, and a frame making nothing.

const FRAME := 1.0 / 60.0

var cfg: SoundConfig = SoundConfig.new()


func _envelope() -> SoundMix.DuckEnvelope:
	return SoundMix.DuckEnvelope.new(cfg)


## Advances `env` by `seconds` in frames.
func _run(env: SoundMix.DuckEnvelope, seconds: float) -> void:
	for i in roundi(seconds / FRAME):
		env.advance(FRAME)


func _bus(bus: StringName) -> int:
	return AudioServer.get_bus_index(bus)


func _hit(env: SoundMix.DuckEnvelope) -> void:
	env.dip(cfg.hit_dip_depth, cfg.hit_dip_attack, cfg.hit_dip_hold, cfg.hit_dip_release)


func _whistle(env: SoundMix.DuckEnvelope) -> void:
	env.dip(cfg.whistle_dip_depth, cfg.whistle_dip_attack, cfg.whistle_dip_hold, cfg.whistle_dip_release)


func test_the_field_bus_carries_the_world_and_the_interface_goes_round_it() -> void:
	assert_eq(AudioServer.get_bus_send(_bus(SoundMix.BUS_FIELD)), &"Master")
	assert_eq(AudioServer.get_bus_send(_bus(SimAudio.BUS_EFFECTS)), SoundMix.BUS_FIELD)
	assert_eq(AudioServer.get_bus_send(_bus(SimAudio.BUS_AMBIENCE)), SoundMix.BUS_FIELD)
	assert_eq(AudioServer.get_bus_send(_bus(SimAudio.BUS_INTERFACE)), &"Master")
	assert_eq(AudioServer.get_bus_send(_bus(SoundMix.BUS_EFFECTS_HALF)), SimAudio.BUS_EFFECTS)
	assert_eq(AudioServer.get_bus_send(_bus(SoundMix.BUS_EFFECTS_FULL)), SimAudio.BUS_EFFECTS)
	assert_eq(AudioServer.get_bus_send(_bus(SoundMix.BUS_POWER_HALF)), SimAudio.BUS_POWER)
	assert_eq(AudioServer.get_bus_send(_bus(SoundMix.BUS_POWER_FULL)), SimAudio.BUS_POWER)
	assert_eq(AudioServer.get_bus_send(_bus(SimAudio.BUS_SHOTS)), SimAudio.BUS_EFFECTS)
	for bus: StringName in [SimAudio.BUS_POWER, SimAudio.BUS_MUFFLED, SoundMix.BUS_SHOTS_HALF, SoundMix.BUS_SHOTS_FULL]:
		assert_eq(AudioServer.get_bus_send(_bus(bus)), SimAudio.BUS_SHOTS, "%s feeds Shots" % bus)
		assert_lt(_bus(SimAudio.BUS_SHOTS), _bus(bus), "%s feeds an earlier bus" % bus)
	for bus: StringName in [SoundMix.BUS_FIELD, SoundMix.BUS_EFFECTS_HALF, SoundMix.BUS_EFFECTS_FULL,
			SoundMix.BUS_POWER_HALF, SoundMix.BUS_POWER_FULL, SoundMix.BUS_SHOTS_HALF, SoundMix.BUS_SHOTS_FULL]:
		var i := _bus(bus)
		assert_true(AudioServer.get_bus_effect(i, 0) is AudioEffectLowPassFilter, "%s has its low-pass" % bus)
		# A bus can only feed one before it.
		assert_lt(_bus(AudioServer.get_bus_send(i)), i, "%s feeds an earlier bus" % bus)
	assert_false(AudioServer.is_bus_effect_enabled(_bus(SoundMix.BUS_FIELD), 0), "the field starts clear")
	assert_eq(Settings.VOLUME_BUSES, [&"Master", &"Effects", &"Power", &"Ambience", &"Interface"] as Array[StringName],
			"Settings' five sliders")
	for bus in Settings.VOLUME_BUSES:
		assert_gte(_bus(bus), 0, "%s exists" % bus)


func test_the_occlusion_buses_take_their_corners_and_levels_from_the_browser_numbers() -> void:
	assert_almost_eq(SoundMix.share_cutoff_hz(cfg, 0.0), 18000.0, 0.01)
	assert_almost_eq(SoundMix.share_cutoff_hz(cfg, 1.0), 700.0, 0.01)
	assert_almost_eq(SoundMix.share_cutoff_hz(cfg, 0.5), sqrt(18000.0 * 700.0), 0.01, "a log scale")
	assert_almost_eq(SoundMix.share_gain(cfg, 1.0), 0.55, 1e-6)
	assert_almost_eq(SoundMix.share_gain(cfg, 0.5), 0.775, 1e-6)
	var odd := SoundConfig.new()
	odd.occlusion_muffled_hz = 500.0
	odd.occlusion_muffled_gain = 0.3
	SoundMix.set_occlusion_buses(odd)
	var full := _bus(SoundMix.BUS_POWER_FULL)
	assert_almost_eq((AudioServer.get_bus_effect(full, 0) as AudioEffectFilter).cutoff_hz, 500.0, 0.01)
	assert_almost_eq(AudioServer.get_bus_volume_db(full), linear_to_db(0.3), 1e-3)
	SoundMix.set_occlusion_buses(cfg)
	var half := _bus(SoundMix.BUS_EFFECTS_HALF)
	assert_almost_eq((AudioServer.get_bus_effect(half, 0) as AudioEffectFilter).cutoff_hz, sqrt(18000.0 * 700.0), 0.01)
	assert_almost_eq(AudioServer.get_bus_volume_db(half), linear_to_db(0.775), 1e-3)


func test_a_dip_goes_down_quickly_holds_and_comes_back() -> void:
	var env := _envelope()
	assert_eq(env.gain(), 1.0)
	_hit(env)
	_run(env, 0.05)
	assert_almost_eq(env.gain(), cfg.hit_dip_depth, 0.01, "down within its attack")
	_run(env, cfg.hit_dip_hold - 0.05)
	assert_almost_eq(env.gain(), cfg.hit_dip_depth, 0.01, "held")
	_run(env, cfg.hit_dip_release)
	assert_between(env.gain(), cfg.hit_dip_depth + 0.2, 0.9, "on the way back over its release")
	_run(env, 1.0)
	assert_eq(env.gain(), 1.0, "back, exactly")
	assert_true(env.is_open())


func test_overlapping_dips_keep_the_deeper_depth_and_the_later_end() -> void:
	var env := _envelope()
	_hit(env)
	_run(env, 0.1)
	_whistle(env)
	_run(env, 0.4)
	assert_almost_eq(env.gain(), cfg.hit_dip_depth, 0.01, "the hit's depth held into the whistle's end")
	_run(env, cfg.whistle_dip_hold - 0.45)
	assert_almost_eq(env.gain(), cfg.hit_dip_depth, 0.01, "until the whistle's end")
	_run(env, 1.5)
	assert_eq(env.gain(), 1.0)
	_whistle(env)
	_run(env, 0.3)
	assert_almost_eq(env.gain(), cfg.whistle_dip_depth, 0.01, "a fresh dip takes its own depth")
	_hit(env)
	_run(env, 0.1)
	assert_almost_eq(env.gain(), cfg.hit_dip_depth, 0.01, "a deeper one inside it goes deeper")
	# The hit alone would let go 0.25 s after it; the whistle ends 0.05 s later.
	_run(env, 0.18)
	assert_almost_eq(env.gain(), cfg.hit_dip_depth, 0.01, "and holds to the whistle's later end")


func test_out_of_play_muffles_and_turns_down_and_multiplies_with_a_dip() -> void:
	var env := _envelope()
	assert_true(env.is_open())
	env.out = true
	_hit(env)
	_run(env, 0.1)
	assert_false(env.is_open())
	assert_lt(env.gain(), cfg.hit_dip_depth, "out and dipped")
	_run(env, 0.1)
	assert_almost_eq(env.gain(), lerpf(1.0, cfg.out_gain, env.out_amount) * cfg.hit_dip_depth, 0.01)
	_run(env, 1.5)
	assert_almost_eq(env.gain(), cfg.out_gain, 0.01, "the dip over, still out")
	assert_almost_eq(env.cutoff_hz(), cfg.out_hz, 1.0)
	env.out = false
	_run(env, cfg.out_ease)
	assert_between(env.cutoff_hz(), cfg.out_hz * 2.0, cfg.occlusion_open_hz * 0.9, "opening on a log scale")
	_run(env, 2.0)
	assert_true(env.is_open())
	assert_eq(env.gain(), 1.0)


func test_sound_mix_reads_the_tick_and_leaves_the_field_clear_when_it_goes() -> void:
	var state := GameState.new(1)
	var you := Character.new(0, 0, Vector3.ZERO)
	state.characters.append(you)
	var mix := SoundMix.new()
	add_child(mix)
	mix.setup(cfg)
	var field := _bus(SoundMix.BUS_FIELD)
	var hit := state.events.add(GameEvent.Kind.CHARACTER_HIT)
	hit.actor = 3
	hit.target = 1
	mix.on_tick(state, 0)
	mix._process(0.1)
	assert_eq(AudioServer.get_bus_volume_db(field), 0.0, "someone else's hit: no dip")
	hit.target = 0
	you.status = Character.Status.CALLING
	mix.on_tick(state, 0)
	assert_true(mix.envelope.out, "hit: out of play")
	for i in 10:
		mix._process(FRAME)
	assert_lt(AudioServer.get_bus_volume_db(field), linear_to_db(cfg.hit_dip_depth), "dipped and turned down")
	assert_true(AudioServer.is_bus_effect_enabled(field, 0), "muffled")
	assert_lt((AudioServer.get_bus_effect(field, 0) as AudioEffectFilter).cutoff_hz, cfg.occlusion_open_hz)
	state.events.clear()
	state.round_state.phase = RoundState.Phase.MATCH_OVER
	mix.on_tick(state, 0)
	assert_false(mix.envelope.out, "the match is over: out no more")
	# Leaving play mid-dip.
	remove_child(mix)
	assert_eq(AudioServer.get_bus_volume_db(field), 0.0)
	assert_false(AudioServer.is_bus_effect_enabled(field, 0))
	mix.free()


func test_the_whistles_dip_the_field() -> void:
	var state := GameState.new(1)
	state.characters.append(Character.new(0, 0, Vector3.ZERO))
	var mix := SoundMix.new()
	add_child_autofree(mix)
	mix.setup(cfg)
	var cues: Dictionary[String, bool] = {}
	for kind: GameEvent.Kind in [GameEvent.Kind.ROUND_OVER, GameEvent.Kind.MATCH_OVER, GameEvent.Kind.CHALLENGE,
			GameEvent.Kind.ROUND_START]:
		for cue: int in [RangeChallenge.Cue.COUNT, RangeChallenge.Cue.GO, RangeChallenge.Cue.TIME]:
			mix.envelope = _envelope()
			state.events.clear()
			var e := state.events.add(kind)
			e.actor = 0
			e.value = cue
			mix.on_tick(state, 0)
			mix.envelope.advance(0.2)
			var dipped := mix.envelope.gain() < 1.0
			if dipped:
				assert_almost_eq(mix.envelope.gain(), cfg.whistle_dip_depth, 0.01)
			cues["%d/%d" % [kind, cue]] = dipped
	var t := RangeChallenge.Cue.TIME
	var c := RangeChallenge.Cue.COUNT
	var g := RangeChallenge.Cue.GO
	assert_true(cues["%d/%d" % [GameEvent.Kind.ROUND_OVER, c]], "a round's end")
	assert_true(cues["%d/%d" % [GameEvent.Kind.MATCH_OVER, c]], "the match's end")
	assert_true(cues["%d/%d" % [GameEvent.Kind.CHALLENGE, t]], "the range's Time")
	assert_false(cues["%d/%d" % [GameEvent.Kind.CHALLENGE, c]], "a count")
	assert_false(cues["%d/%d" % [GameEvent.Kind.CHALLENGE, g]], "Go")
	assert_false(cues["%d/%d" % [GameEvent.Kind.ROUND_START, c]], "a round's start")


func test_a_frame_and_a_tick_make_nothing() -> void:
	var state := GameState.new(1)
	var you := Character.new(0, 0, Vector3.ZERO)
	state.characters.append(you)
	var mix := SoundMix.new()
	add_child_autofree(mix)
	mix.setup(cfg)
	for i in 10:
		_mix_frame(mix, state, you, i)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 300:
		_mix_frame(mix, state, you, i)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)


## A tick with your hit or a whistle now and then, you in and out of play, and a frame.
func _mix_frame(mix: SoundMix, state: GameState, you: Character, i: int) -> void:
	state.events.clear()
	if i % 40 == 0:
		var hit := state.events.add(GameEvent.Kind.CHARACTER_HIT)
		hit.target = 0
	if i % 70 == 0:
		state.events.add(GameEvent.Kind.ROUND_OVER)
	you.status = Character.Status.OUT if i % 100 < 50 else Character.Status.ALIVE
	mix.on_tick(state, 0)
	mix._process(FRAME)
