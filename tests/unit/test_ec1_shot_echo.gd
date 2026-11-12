extends GutTest
## EC1: Subway's shots play a little louder with an underground echo (the Shots bus's level and reverb); every other
## map's shots play dry at their own level, and leaving the match puts the bus back.

const EPS := 1e-4

var cfg: SoundConfig = null


func before_each() -> void:
	cfg = SoundConfig.new()


func after_each() -> void:
	SimAudio.set_echo(null)


func _shots() -> int:
	return AudioServer.get_bus_index(SimAudio.BUS_SHOTS)


func _reverb() -> AudioEffectReverb:
	return AudioServer.get_bus_effect(_shots(), 0) as AudioEffectReverb


func _echo_on() -> bool:
	return AudioServer.is_bus_effect_enabled(_shots(), 0)


func _audio_on(map_id: String) -> SimAudio:
	var map: MapData = null
	if map_id != "":
		map = MapData.new()
		map.id = map_id
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(cfg, [&"electric"] as Array[StringName], BodyConfig.new(), null, map)
	return audio


func test_the_shots_bus_starts_dry_with_its_reverb_off() -> void:
	assert_gt(_shots(), 0, "the layout has a Shots bus")
	assert_not_null(_reverb(), "its first effect is a reverb")
	assert_false(_echo_on())
	assert_almost_eq(AudioServer.get_bus_volume_db(_shots()), 0.0, EPS)


func test_only_subway_has_an_echo_by_default() -> void:
	assert_eq(cfg.shot_echoes.keys(), [&"subway"])


func test_set_echo_sets_the_level_and_room_and_null_puts_it_back() -> void:
	var echo := ShotEcho.new()
	echo.gain_db = 2.5
	echo.room_size = 0.6
	echo.damping = 0.3
	echo.spread = 0.8
	echo.hipass = 0.2
	echo.predelay_ms = 25.0
	echo.predelay_feedback = 0.1
	echo.dry = 0.9
	echo.wet = 0.3
	SimAudio.set_echo(echo)
	assert_true(_echo_on())
	assert_almost_eq(AudioServer.get_bus_volume_db(_shots()), 2.5, EPS)
	var r := _reverb()
	assert_almost_eq(r.room_size, 0.6, EPS)
	assert_almost_eq(r.damping, 0.3, EPS)
	assert_almost_eq(r.spread, 0.8, EPS)
	assert_almost_eq(r.hipass, 0.2, EPS)
	assert_almost_eq(r.predelay_msec, 25.0, EPS)
	assert_almost_eq(r.predelay_feedback, 0.1, EPS)
	assert_almost_eq(r.dry, 0.9, EPS)
	assert_almost_eq(r.wet, 0.3, EPS)
	SimAudio.set_echo(null)
	assert_false(_echo_on())
	assert_almost_eq(AudioServer.get_bus_volume_db(_shots()), 0.0, EPS)


func test_subway_turns_the_echo_on_and_woodland_leaves_it_off() -> void:
	var subway := _audio_on("subway")
	assert_true(_echo_on(), "Subway's echo")
	assert_almost_eq(AudioServer.get_bus_volume_db(_shots()), cfg.shot_echoes[&"subway"].gain_db, EPS)
	remove_child(subway)
	assert_false(_echo_on(), "leaving the match puts the bus back")
	assert_almost_eq(AudioServer.get_bus_volume_db(_shots()), 0.0, EPS)
	add_child(subway)
	SimAudio.set_echo(cfg.shot_echoes[&"subway"])
	_audio_on("woodland")
	assert_false(_echo_on(), "a map with no echo sets the bus dry, whatever came before")
	assert_almost_eq(AudioServer.get_bus_volume_db(_shots()), 0.0, EPS)
	SimAudio.set_echo(cfg.shot_echoes[&"subway"])
	_audio_on("")
	assert_false(_echo_on(), "no map: dry")


func test_a_shot_through_cover_keeps_to_the_shots_buses() -> void:
	assert_eq(SoundOcclusion.bus_for(SimAudio.BUS_SHOTS, 0.0, cfg), SimAudio.BUS_SHOTS)
	assert_eq(SoundOcclusion.bus_for(SimAudio.BUS_SHOTS, 0.5, cfg), SoundMix.BUS_SHOTS_HALF)
	assert_eq(SoundOcclusion.bus_for(SimAudio.BUS_SHOTS, 1.0, cfg), SoundMix.BUS_SHOTS_FULL)
	assert_eq(SoundOcclusion.bus_for(SimAudio.BUS_MUFFLED, 1.0, cfg), SoundMix.BUS_SHOTS_FULL,
			"a silenced shot behind a wall, on the wall's lower corner")
	for share: float in [0.3, 0.5, 0.8, 1.0]:
		assert_almost_eq(SoundOcclusion.level_for(SimAudio.BUS_SHOTS, share, cfg),
				SoundOcclusion.level_for(SimAudio.BUS_EFFECTS, share, cfg), EPS, "the same level as before at %s" % share)


func test_the_shots_occlusion_buses_match_the_effects_ones() -> void:
	SoundMix.set_occlusion_buses(cfg)
	var shots: Array[StringName] = [SoundMix.BUS_SHOTS_HALF, SoundMix.BUS_SHOTS_FULL]
	var effects: Array[StringName] = [SoundMix.BUS_EFFECTS_HALF, SoundMix.BUS_EFFECTS_FULL]
	for i in shots.size():
		var a := AudioServer.get_bus_index(shots[i])
		var b := AudioServer.get_bus_index(effects[i])
		assert_almost_eq(AudioServer.get_bus_volume_db(a), AudioServer.get_bus_volume_db(b), EPS)
		assert_almost_eq((AudioServer.get_bus_effect(a, 0) as AudioEffectFilter).cutoff_hz,
				(AudioServer.get_bus_effect(b, 0) as AudioEffectFilter).cutoff_hz, EPS)


func test_every_bus_sends_to_a_lower_bus_and_the_shots_chain_reaches_master() -> void:
	for i in AudioServer.bus_count:
		var send := AudioServer.get_bus_send(i)
		if i == 0:
			continue
		assert_lt(AudioServer.get_bus_index(send), i, "%s sends to a lower bus" % AudioServer.get_bus_name(i))
	for bus: StringName in [SimAudio.BUS_POWER, SimAudio.BUS_MUFFLED, SoundMix.BUS_SHOTS_HALF, SoundMix.BUS_SHOTS_FULL]:
		assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)), SimAudio.BUS_SHOTS, "%s is under Shots" % bus)
	assert_eq(AudioServer.get_bus_send(_shots()), SimAudio.BUS_EFFECTS)


func test_the_other_maps_play_their_shots_dry() -> void:
	for id: String in ["range", "depot", "woodland", "kingsmere", "unknown"]:
		SimAudio.set_echo(cfg.shot_echoes[&"subway"])
		_audio_on(id)
		assert_false(_echo_on(), "%s has no echo" % id)
		assert_almost_eq(AudioServer.get_bus_volume_db(_shots()), 0.0, EPS, id)


func test_a_silenced_shot_keeps_its_own_low_pass_in_the_open() -> void:
	assert_eq(SoundOcclusion.bus_for(SimAudio.BUS_MUFFLED, 0.0, cfg), SimAudio.BUS_MUFFLED)
	assert_true(SoundOcclusion.bus_for(SimAudio.BUS_MUFFLED, 0.5, cfg) in [SimAudio.BUS_MUFFLED, SoundMix.BUS_SHOTS_HALF])
	assert_eq(SoundOcclusion.bus_for(SimAudio.BUS_EFFECTS, 1.0, cfg), SoundMix.BUS_EFFECTS_FULL, "Effects unchanged")


func test_setting_the_echo_twice_and_leaving_twice_stays_clean() -> void:
	var echo: ShotEcho = cfg.shot_echoes[&"subway"]
	SimAudio.set_echo(echo)
	SimAudio.set_echo(echo)
	assert_true(_echo_on())
	SimAudio.set_echo(null)
	SimAudio.set_echo(null)
	assert_false(_echo_on())
	assert_eq(AudioServer.get_bus_effect_count(_shots()), 1, "no effect added or lost")


## A match's audio freed after the next one's setup (a restart that frees late) leaves the new match's echo on.
func test_an_old_match_leaving_after_a_new_setup_leaves_the_echo_on() -> void:
	var old := _audio_on("subway")
	var now := _audio_on("subway")
	remove_child(old)
	assert_true(_echo_on(), "the new match keeps its echo")
	add_child(old)
	remove_child(now)
	assert_false(_echo_on(), "the match that set it puts it back")
	add_child(now)
