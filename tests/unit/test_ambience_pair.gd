extends GutTest
## BP7 row 59: an ambience bed plays as the browser game's panned pair (its sfx.ts startAmbience): two copies of the
## loop half a loop apart (a tonal loop's copy_offset further on), panned `width` left and right with the browser's
## equal-power law, so each ear hears the pair at the bed's level.

const TUNING := "res://game/config/play_tuning.tres"

var cfg: SoundConfig = null


func before_each() -> void:
	cfg = (load(TUNING) as PlayTuning).sound


func _audio(map: MapData = null) -> SimAudio:
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(cfg, [] as Array[StringName], BodyConfig.new(), null, map)
	return audio


## The browser's StereoPannerNode on a mono copy panned `pan`: its left and right gains.
func _browser(pan: float) -> Vector2:
	var x := (pan + 1.0) * 0.5
	return Vector2(cos(x * PI * 0.5), sin(x * PI * 0.5))


## Godot's AudioEffectPanner on a mono voice at level `level` panned `pan` (measured: left 1 - pan, right 1 + pan).
func _godot(level: float, pan: float) -> Vector2:
	return Vector2(level * (1.0 - pan), level * (1.0 + pan))


func test_each_copy_reaches_each_ear_as_the_browsers_and_the_pair_at_the_beds_level() -> void:
	for width: float in [0.0, 0.5, 0.7, 0.75, 0.9, 1.0]:
		var pair := AmbienceBed.pair_gains(width)
		var left := _godot(pair.x, pair.y)
		var right := _godot(pair.x, -pair.y)
		assert_almost_eq(left, _browser(-width), Vector2(1e-5, 1e-5), "the left copy at width %.2f" % width)
		assert_almost_eq(right, _browser(width), Vector2(1e-5, 1e-5), "the right copy at width %.2f" % width)
		# unrelated copies add in power: each ear hears the pair at the bed's level, as the browser's
		assert_almost_eq(left.x * left.x + right.x * right.x, 1.0, 1e-5, "the left ear at width %.2f" % width)
		assert_almost_eq(left.y * left.y + right.y * right.y, 1.0, 1e-5, "the right ear at width %.2f" % width)


func test_the_second_copy_starts_half_a_loop_on_and_a_tonal_loops_offset_more() -> void:
	var bed := AmbienceBed.new()
	assert_almost_eq(bed.second_start(6.0), 3.0, 1e-6)
	bed.copy_offset = 0.25
	assert_almost_eq(bed.second_start(6.0), 3.25, 1e-6)
	bed.copy_offset = 4.0
	assert_almost_eq(bed.second_start(6.0), 1.0, 1e-6, "round the loop")
	assert_eq(bed.second_start(0.0), 0.0, "no length: from the start")


func test_every_set_pans_its_beds_one_width() -> void:
	var amb := cfg.ambiences
	for sets: Dictionary[StringName, AmbienceSet] in [amb.day, amb.night]:
		for id: StringName in sets:
			var beds := sets[id].beds
			for bed in beds:
				assert_eq(bed.width, beds[0].width, "%s: the two buses pan one width" % id)
				assert_between(bed.width, 0.0, 1.0, "%s: %s" % [id, bed.loop])


func test_the_pair_plays_on_its_buses_from_its_starts_with_their_panners_set() -> void:
	var audio := _audio()
	var bed := cfg.ambiences.set_for(AmbienceConfig.DEFAULT_ID, false).beds[0]
	assert_eq(audio._beds.size(), 2)
	var pair := AmbienceBed.pair_gains(bed.width)
	for bus: StringName in [SimAudio.BUS_AMBIENCE_LEFT, SimAudio.BUS_AMBIENCE_RIGHT]:
		var at := AudioServer.get_bus_index(bus)
		assert_gte(at, 0, "%s in the layout" % bus)
		assert_eq(AudioServer.get_bus_send(at), SimAudio.BUS_AMBIENCE, "into Ambience: its volume and muffling")
		var panner := AudioServer.get_bus_effect(at, 0) as AudioEffectPanner
		assert_not_null(panner)
		var want := pair.y if bus == SimAudio.BUS_AMBIENCE_LEFT else -pair.y
		assert_almost_eq(panner.pan, want, 1e-5, "%s panned by the bed's width" % bus)
	var length := audio._beds[0].stream.get_length()
	assert_eq(audio._bed_from[0], 0.0)
	assert_almost_eq(audio._bed_from[1], bed.second_start(length), 1e-4, "half a loop on")
	audio.start_ambience()
	assert_true(audio._beds[0].playing and audio._beds[1].playing)
	assert_gt(audio._beds[1].get_playback_position(), length * 0.4, "the right copy plays from half a loop on")


func test_through_the_real_buses_a_copy_reaches_each_ear_as_the_browsers() -> void:
	# The bus layout's own panners, a constant mono signal on each and a capture on each bus: what the ears get.
	var audio := _audio()
	var width := cfg.ambiences.set_for(AmbienceConfig.DEFAULT_ID, false).beds[0].width
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	var data := PackedByteArray()
	data.resize(4410 * 2)
	for i in 4410:
		data.encode_s16(i * 2, 16384)
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = 4410
	var caps: Array[AudioEffectCapture] = []
	var voices: Array[AudioStreamPlayer] = []
	for bus: StringName in [SimAudio.BUS_AMBIENCE_LEFT, SimAudio.BUS_AMBIENCE_RIGHT]:
		var cap := AudioEffectCapture.new()
		AudioServer.add_bus_effect(AudioServer.get_bus_index(bus), cap)
		caps.append(cap)
		var v := AudioStreamPlayer.new()
		v.stream = wav
		v.bus = bus
		v.volume_db = linear_to_db(AmbienceBed.pair_gains(width).x)
		add_child_autofree(v)
		voices.append(v)
		v.play()
	await wait_seconds(0.3) # the mixer runs in real time
	for i in 2:
		var frames := caps[i].get_buffer(caps[i].get_frames_available())
		var at := AudioServer.get_bus_index(SimAudio.BUS_AMBIENCE_LEFT if i == 0 else SimAudio.BUS_AMBIENCE_RIGHT)
		AudioServer.remove_bus_effect(at, AudioServer.get_bus_effect_count(at) - 1)
		voices[i].stop()
		assert_false(frames.is_empty(), "the bus mixed")
		if frames.is_empty():
			return
		var heard := frames[frames.size() - 1] / 0.5
		var want := _browser(-width if i == 0 else width)
		assert_almost_eq(heard, want, Vector2(2e-3, 2e-3), "copy %d in the ears" % i)
	assert_not_null(audio)
