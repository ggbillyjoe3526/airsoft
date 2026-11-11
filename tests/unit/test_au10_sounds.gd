extends GutTest
## AU10: the lift's cues all resolve with the variants the game draws from, the tunnel loop is stored as a loop with a
## peak, and the footstep surfaces the owner's recordings replaced keep their full set (noise levels are data, not cue
## length).


func test_every_lift_cue_the_sim_audio_plays_exists() -> void:
	for cue: StringName in SimAudio.LIFT_CUES:
		assert_true(ResourceLoader.exists("%s%s_1.wav" % [SoundConfig.CUE_DIR, cue]), String(cue))


## A door's slide is cut to sit inside the 1.5 s door (critic, AU10: the whole 3 s take put its loud part after it).
func test_the_lift_rides_are_longer_than_a_door_but_each_cue_is_one_floor_long() -> void:
	var doors := load("%slift_doors_1.wav" % SoundConfig.CUE_DIR) as AudioStream
	var motor := load("%slift_motor_1.wav" % SoundConfig.CUE_DIR) as AudioStream
	assert_not_null(doors)
	assert_not_null(motor)
	assert_almost_eq(doors.get_length(), 1.7, 0.1)
	assert_almost_eq(motor.get_length(), 3.2, 0.1)


func test_the_tunnel_loop_loops_and_has_a_peak_entry() -> void:
	var s := load("%stunnel.wav" % SoundConfig.LOOP_DIR) as AudioStreamWAV
	assert_not_null(s, "tunnel.wav loads")
	assert_eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_gt(s.get_length(), 30.0, "a long loop, so its repeat is not heard")
	var peaks: Variant = JSON.parse_string(FileAccess.get_file_as_string(SoundConfig.PEAKS_PATH))
	assert_true(peaks is Dictionary and (peaks as Dictionary).has("tunnel"))
	assert_gt(float((peaks as Dictionary)["tunnel"]), 0.0)


func test_subway_names_the_tunnel_ambience_and_it_is_a_known_id() -> void:
	var map := MapData.load_map("subway", MapStyle.new(), 1)
	assert_eq(map.ambience, &"tunnel")
	assert_true(AmbienceConfig.IDS.has(map.ambience))
