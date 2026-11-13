extends GutTest
## AU11: the owner's recordings of 13 Nov as game cues: every cue exists with the variants the game loads, fits its
## length, stays under full scale, and the pick-up and drop are quieter than they were.

const OLD_HANDLE_GAIN := 0.7


func _wav(cue: String, n: int) -> AudioStreamWAV:
	return load("%s%s_%d.wav" % [SoundConfig.CUE_DIR, cue, n]) as AudioStreamWAV


## The source file's peak: the imported stream is ADPCM, so its data is no PCM to measure.
func _peak(cue: String, n: int) -> float:
	var d := FileAccess.get_file_as_bytes("%s%s_%d.wav" % [SoundConfig.CUE_DIR, cue, n])
	# The cue tools write the plain 44-byte header: its data chunk starts at byte 36.
	assert_eq(d.slice(36, 40).get_string_from_ascii(), "data", "%s_%d has a 44-byte header" % [cue, n])
	var peak := 0.0
	for i in range(44, d.size() - 1, 2):
		peak = maxf(peak, absf(float(d.decode_s16(i))) / 32768.0)
	return peak


func test_pick_up_and_drop_are_quieter_than_they_were() -> void:
	assert_lt(SoundConfig.new().plant_handle_gain, OLD_HANDLE_GAIN, "the owner asked for quieter handling")


func test_every_plant_cue_the_game_loads_exists_with_variants() -> void:
	var counts := {&"plant_pickup": 3, &"plant_drop": 3, &"plant_arming": 1, &"plant_armed": 1, &"plant_beep": 1,
			&"plant_defusing": 1, &"plant_defused": 1, &"plant_went_off": 1}
	for cue: StringName in counts:
		for n: int in counts[cue]:
			assert_true(ResourceLoader.exists("%s%s_%d.wav" % [SoundConfig.CUE_DIR, cue, n + 1]), "%s_%d" % [cue, n + 1])
	for cue: StringName in SimAudio.PLANT_CUES:
		if cue != &"":
			assert_true(counts.has(cue), "%s is a cue the test knows" % cue)


func test_no_new_cue_clips_or_exceeds_the_variants_loaded() -> void:
	var cfg := SoundConfig.new()
	var names: Array[String] = ["plant_pickup", "plant_drop", "plant_arming", "plant_beep", "plant_defusing",
			"plant_defused", "plant_went_off", "cycle_shotgun", "shot_shotgun", "power_shotgun", "magOut_shotgun",
			"magIn_shotgun"]
	for cue in names:
		var n := 1
		while ResourceLoader.exists("%s%s_%d.wav" % [SoundConfig.CUE_DIR, cue, n]):
			assert_lt(_peak(cue, n), 0.999, "%s_%d under full scale" % [cue, n])
			n += 1
		assert_gt(n - 1, 0, "%s has a variant" % cue)
		assert_lte(n - 1, maxi(cfg.variants, 3), "%s variants fit what is loaded" % cue)


func test_the_bomb_work_loops_last_as_long_as_the_work() -> void:
	var plant := PlantConfig.new()
	assert_almost_eq(_wav("plant_arming", 1).get_length(), plant.plant_time, 0.05, "keying the code")
	assert_almost_eq(_wav("plant_defusing", 1).get_length(), plant.defuse_time, 0.05, "the kit at work")
