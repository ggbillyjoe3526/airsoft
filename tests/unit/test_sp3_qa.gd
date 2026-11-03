extends GutTest
## QA hunt for SP3: the whistle files' ends (the owner's recordings since AU2), their import settings, the blast
## timings at their edges, the ambience tables' ranges and fallbacks, and what MapData does with odd `ambience` values.

const RATE := 44100
const HEADER := 44
const CUES := "res://assets/audio/cues/"

var cfg: SoundConfig


func before_all() -> void:
	cfg = PlayTuning.load_default().sound


## The file's samples as floats (-1 to 1).
func _read(path: String) -> PackedFloat32Array:
	var bytes := FileAccess.get_file_as_bytes(path)
	var out := PackedFloat32Array()
	var frames := (bytes.size() - HEADER) >> 1
	out.resize(maxi(frames, 0))
	for i in frames:
		out[i] = bytes.decode_s16(HEADER + i * 2) / 32767.0
	return out


func test_a_blast_starts_from_silence_and_dies_away_inside_its_last_few_samples() -> void:
	for stem: String in ["whistle_short", "whistle_long"]:
		for v in 3:
			var s := _read("%s%s_%d.wav" % [CUES, stem, v + 1])
			assert_eq(s[0], 0.0, "%s_%d starts at zero" % [stem, v + 1])
			assert_lt(absf(s[s.size() - 1]), 0.001, "%s_%d ends under -60 dB, so it does not click" % [stem, v + 1])


func test_the_whistle_imports_like_the_other_cues() -> void:
	var want := _params(CUES + "ambience_bird_1.wav.import")
	assert_false(want.is_empty(), "the reference cue's import settings read")
	for stem: String in ["whistle_short", "whistle_long"]:
		for v in 3:
			var path := "%s%s_%d.wav.import" % [CUES, stem, v + 1]
			assert_eq(_params(path), want, "%s imports as the other cues" % path)


## The lines of an .import file's [params] block.
static func _params(path: String) -> PackedStringArray:
	var text := FileAccess.get_file_as_string(path)
	var at := text.find("[params]")
	return PackedStringArray() if at < 0 else text.substr(at).split("\n", false)


func test_the_blasts_never_run_into_each_other_and_the_match_over_whistles_last_the_browsers_3_92_seconds() -> void:
	assert_gt(cfg.round_start_blast(1), cfg.round_start_blast(0) + cfg.whistle_short, "the second short starts after the first ends")
	var end := cfg.match_over_blast(cfg.match_over_blasts - 1) + cfg.whistle_long
	assert_almost_eq(end, 0.8 * 1.3 * 3.0 + 0.8, 1e-6, "the browser's matchOverWhistlesDuration")
	var spacing := cfg.match_over_blast(1) - cfg.match_over_blast(0)
	for i in range(1, cfg.match_over_blasts):
		assert_almost_eq(cfg.match_over_blast(i) - cfg.match_over_blast(i - 1), spacing, 1e-6, "even gaps")
	assert_gt(spacing, cfg.whistle_long, "each long blast ends before the next starts")
	assert_almost_eq(cfg.match_over_blast(0), cfg.whistle_long * cfg.match_over_gap, 1e-6, "the first extra is one gap on")


func test_the_blast_times_follow_the_lengths_set_in_the_config() -> void:
	var c := SoundConfig.new()
	c.whistle_short = 0.2
	c.round_start_gap = 2.0
	c.whistle_long = 1.0
	c.match_over_gap = 1.5
	assert_almost_eq(c.round_start_blast(1), 0.4, 1e-6)
	assert_almost_eq(c.match_over_blast(2), 4.5, 1e-6)


func test_the_calls_have_sane_ranges_and_their_cues_have_every_variant_up_to_a_count() -> void:
	var amb := cfg.ambiences
	for id in AmbienceConfig.IDS:
		for amb_set: AmbienceSet in [amb.day[id], amb.night[id]]:
			for b in amb_set.beds:
				assert_true(b.gain > 0.0 and b.gain <= 0.05, "%s gain" % b.loop)
				assert_between(b.width, 0.0, 1.0, "%s width" % b.loop)
				assert_between(b.copy_offset, 0.0, 0.01, "%s's second copy is only a hum cycle on" % b.loop)
			for c in amb_set.calls:
				assert_between(c.level, 0.01, 1.0, "%s level" % c.cue)
				assert_between(c.pitch, 0.0, 0.2, "%s pitch spread" % c.cue)
				assert_gt(c.height, 0.0, "%s is not underground" % c.cue)
				var seen := 0
				while ResourceLoader.exists("%s%s_%d.wav" % [CUES, c.cue, seen + 1]):
					seen += 1
				assert_gt(seen, 1, "%s has variants" % c.cue)
				assert_false(ResourceLoader.exists("%s%s_%d.wav" % [CUES, c.cue, seen + 2]), "%s has no gap in its variants" % c.cue)


func test_a_call_kind_keeps_one_seed_and_one_set_of_numbers_on_every_field() -> void:
	var by_cue: Dictionary[StringName, AmbienceCall] = {}
	for id in AmbienceConfig.IDS:
		for amb_set: AmbienceSet in [amb_day(id), amb_night(id)]:
			for c in amb_set.calls:
				if by_cue.has(c.cue):
					var first := by_cue[c.cue]
					assert_eq([c.rng_seed, c.level, c.gap_min, c.gap_max, c.distance_min, c.distance_max, c.height, c.pitch],
							[first.rng_seed, first.level, first.gap_min, first.gap_max, first.distance_min,
							first.distance_max, first.height, first.pitch], "%s is one kind of call everywhere" % c.cue)
				by_cue[c.cue] = c
	var seeds: Dictionary[int, StringName] = {}
	for cue in by_cue:
		assert_false(seeds.has(by_cue[cue].rng_seed), "%s shares a seed with %s" % [cue, seeds.get(by_cue[cue].rng_seed)])
		seeds[by_cue[cue].rng_seed] = cue


func amb_day(id: StringName) -> AmbienceSet:
	return cfg.ambiences.day[id]


func amb_night(id: StringName) -> AmbienceSet:
	return cfg.ambiences.night[id]


func test_an_empty_config_hands_back_an_empty_set_never_null() -> void:
	var empty := AmbienceConfig.new()
	for night: bool in [false, true]:
		var s := empty.set_for(&"woods", night)
		assert_not_null(s)
		assert_eq(s.beds.size() + s.calls.size(), 0)
	assert_false(AmbienceConfig.known(&""))
	assert_false(AmbienceConfig.known(&"Woods"), "ids are exact")


func test_a_known_id_missing_from_one_time_of_day_plays_that_times_yard() -> void:
	var c := AmbienceConfig.new()
	var yard_day := AmbienceSet.new()
	var yard_night := AmbienceSet.new()
	c.day[&"yard"] = yard_day
	c.night[&"yard"] = yard_night
	c.day[&"woods"] = AmbienceSet.new()
	assert_eq(c.set_for(&"woods", true), yard_night, "no woods night: the yard's night, not its day")
	assert_eq(c.set_for(&"woods", false), c.day[&"woods"])


func _parse_ambience(raw: Variant) -> MapData:
	return MapData.parse(JSON.stringify({"ambience": raw}), MapStyle.new(), 1)


func test_odd_ambience_values_play_the_yard_and_warn_once_but_a_null_is_none() -> void:
	assert_eq(_parse_ambience(null).ambience, &"yard")
	assert_eq(_parse_ambience(null).warnings.size(), 0, "null is none")
	for raw: Variant in ["", "Woods", " city", ["woods"], {"id": "woods"}, true, 0, 1.5]:
		var m := _parse_ambience(raw)
		assert_eq(m.ambience, &"yard", "%s plays the yard" % str(raw))
		assert_eq(m.warnings.size(), 1, "%s warns once" % str(raw))


func test_every_map_file_names_a_known_ambience_or_none() -> void:
	for file in DirAccess.get_files_at(MapData.DIR):
		if not file.ends_with(".json"):
			continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(MapData.DIR + file))
		assert_true(d is Dictionary, file)
		var named: Variant = (d as Dictionary).get("ambience") if d is Dictionary else null
		assert_true(named == null or AmbienceConfig.known(StringName(str(named))), "%s names a known ambience" % file)
		var m := MapData.load_map(file.get_basename(), MapStyle.new(), 1)
		assert_eq(m.warnings.filter(func(w: String) -> bool: return w.begins_with("ambience")), [], file)
		assert_true(AmbienceConfig.known(m.ambience), file)


func test_a_set_left_null_in_the_config_plays_the_default() -> void:
	var a := AmbienceConfig.new()
	a.day[&"woods"] = null
	a.day[AmbienceConfig.DEFAULT_ID] = AmbienceSet.new()
	assert_same(a.set_for(&"woods", false), a.day[AmbienceConfig.DEFAULT_ID])
