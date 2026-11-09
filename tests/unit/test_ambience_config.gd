extends GutTest
## Each field's ambience as data (SP3): AmbienceConfig in play_tuning.tres holds the browser game's AMBIENCES, every
## loop and cue it names is on disk, no call is louder than a bird and no bed louder than the yard's (DECISIONS
## 2026-10-05), and MapData reads each map's `ambience`.

const BIRD := &"ambience_bird"

var cfg: SoundConfig
var amb: AmbienceConfig


func before_all() -> void:
	cfg = PlayTuning.load_default().sound
	amb = cfg.ambiences


## Every set, day and night, of every ambience, with a label.
func _sets() -> Dictionary[String, AmbienceSet]:
	var out: Dictionary[String, AmbienceSet] = {}
	for id in AmbienceConfig.IDS:
		if amb.day.has(id):
			out["%s day" % id] = amb.day[id]
		if amb.night.has(id):
			out["%s night" % id] = amb.night[id]
	return out


func test_every_ambience_has_a_day_and_a_night_set_with_beds() -> void:
	assert_not_null(amb, "play_tuning.tres holds the ambiences")
	assert_eq(AmbienceConfig.IDS, [&"yard", &"woods", &"indoor", &"street"] as Array[StringName])
	for id in AmbienceConfig.IDS:
		assert_true(amb.day.has(id) and amb.night.has(id), "%s by day and by night" % id)
	assert_eq(_sets().size(), 8)
	for at: String in _sets():
		assert_gt(_sets()[at].beds.size(), 0, "%s has a bed" % at)
		assert_gt(_sets()[at].calls.size(), 0, "%s has a call" % at)


func test_the_sets_are_the_browsers() -> void:
	assert_eq(_loops(amb.day[&"yard"]), ["yard"])
	assert_eq(_cues(amb.day[&"yard"]), ["ambience_bird", "ambience_crow", "ambience_dog"])
	assert_eq(_cues(amb.night[&"yard"]), ["ambience_dog"])
	# Woodland's beds are the owner's woods by day (AU6) and by night (AU9); its calls are the browser's.
	assert_eq(_loops(amb.day[&"woods"]), ["woods_day"])
	assert_eq(_cues(amb.day[&"woods"]), ["ambience_bird", "ambience_creak"])
	assert_eq(_loops(amb.night[&"woods"]), ["woods_night"])
	assert_eq(_cues(amb.night[&"woods"]), ["ambience_owl", "ambience_creak"])
	var yard_bed := amb.day[&"yard"].beds[0]
	assert_almost_eq(yard_bed.gain, 0.035, 1e-6, "the browser's yard bed")
	assert_almost_eq(yard_bed.width, 0.7, 1e-6)
	var birds := amb.day[&"yard"].calls[0]
	assert_eq([birds.level, birds.pitch, birds.gap_min, birds.gap_max, birds.distance_min, birds.distance_max],
			[0.35, 0.08, 7.0, 19.0, 22.0, 45.0])
	assert_eq([birds.height, birds.rng_seed], [7.0, 1303])


func test_every_loop_and_cue_named_is_on_disk() -> void:
	var peaks: Variant = JSON.parse_string(FileAccess.get_file_as_string(SoundConfig.PEAKS_PATH))
	assert_true(peaks is Dictionary, "loops/peaks.json reads")
	for at: String in _sets():
		for bed in _sets()[at].beds:
			assert_true(ResourceLoader.exists("%s%s.wav" % [SoundConfig.LOOP_DIR, bed.loop]), "%s: loop %s" % [at, bed.loop])
			assert_true(peaks is Dictionary and (peaks as Dictionary).has(String(bed.loop)), "%s: %s's peak" % [at, bed.loop])
			var stream := load("%s%s.wav" % [SoundConfig.LOOP_DIR, bed.loop]) as AudioStreamWAV
			assert_true(stream != null and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s: %s loops" % [at, bed.loop])
		for c in _sets()[at].calls:
			var path := "%s%s_1.wav" % [SoundConfig.CUE_DIR, c.cue]
			assert_true(ResourceLoader.exists(path), "%s: %s" % [at, path])


func test_no_call_is_louder_than_a_bird_and_each_is_well_away_and_now_and_then() -> void:
	var bird := amb.day[&"yard"].calls[0]
	assert_eq(bird.cue, BIRD)
	for at: String in _sets():
		var seeds: Dictionary[int, StringName] = {}
		for c in _sets()[at].calls:
			assert_lte(c.level, bird.level, "%s: %s no louder than a bird" % [at, c.cue])
			assert_true(c.gap_min > 0.0 and c.gap_min <= c.gap_max, "%s: %s's gaps" % [at, c.cue])
			assert_true(c.distance_min >= 10.0 and c.distance_min <= c.distance_max, "%s: %s's distances" % [at, c.cue])
			assert_lte(c.distance_max, cfg.max_distance, "%s: %s within reach" % [at, c.cue])
			assert_false(seeds.has(c.rng_seed), "%s: %s has a seed of its own" % [at, c.cue])
			seeds[c.rng_seed] = c.cue
		if at.ends_with("night"):
			assert_false(_cues(_sets()[at]).has(String(BIRD)), "%s: no birds at night" % at)


func test_no_bed_and_no_set_of_beds_together_is_louder_than_the_yards() -> void:
	# A loop stored at its peak plays at gain times that peak, which is the browser's loop at an RMS of 1 at gain, so
	# a bed's gain is its loudness; unrelated beds add in power.
	var yard := amb.day[&"yard"].beds[0]
	assert_eq(yard.loop, &"yard")
	for at: String in _sets():
		var power := 0.0
		for bed in _sets()[at].beds:
			assert_lte(bed.gain, yard.gain, "%s: %s no louder than the yard" % [at, bed.loop])
			power += bed.gain * bed.gain
		assert_lte(sqrt(power), yard.gain + 1e-6, "%s's beds together no louder than the yard" % at)


func test_the_owners_recorded_beds() -> void:
	# AU5: Depot's big quiet room (its creaks for calls); the owner's two outdoor takes by day (the yard's calls) and
	# a street at night (the dog): the street ambience, the Range's (owner, 2026-11-05).
	assert_eq(_loops(amb.day[&"indoor"]), ["indoor"])
	assert_eq(_loops(amb.night[&"indoor"]), ["indoor"])
	assert_eq(_cues(amb.day[&"indoor"]), ["ambience_creak"])
	assert_eq(_loops(amb.day[&"street"]), ["street_day"])
	assert_eq(_cues(amb.day[&"street"]), ["ambience_bird", "ambience_crow", "ambience_dog"])
	assert_eq(_loops(amb.night[&"street"]), ["street_night"])
	assert_eq(_cues(amb.night[&"street"]), ["ambience_dog"])


func test_a_set_is_picked_by_id_and_time_of_day_an_unknown_one_plays_the_yard() -> void:
	assert_eq(amb.set_for(&"woods", false), amb.day[&"woods"])
	assert_eq(amb.set_for(&"woods", true), amb.night[&"woods"])
	assert_eq(amb.set_for(&"city", true), amb.night[&"yard"], "the city went with Neon Heights: the yard")
	assert_eq(amb.set_for(&"swamp", false), amb.day[&"yard"])
	assert_eq(amb.set_for(&"swamp", true), amb.night[&"yard"])
	assert_true(AmbienceConfig.known(&"woods"))
	assert_false(AmbienceConfig.known(&"swamp"))


## The range plays the street ambience (owner, 2026-11-05: it kept The Street's sound when the map went, 2026-11-09).
func test_each_map_reads_its_ambience() -> void:
	var want: Dictionary[String, StringName] = {"depot": &"indoor", "woodland": &"woods", "range": &"street"}
	for id: String in want:
		var map := MapData.load_map(id, MapStyle.new(), 1)
		assert_eq(map.ambience, want[id], id)
		assert_eq(map.warnings.filter(func(w: String) -> bool: return w.begins_with("ambience")), [], id)


func test_a_map_naming_no_ambience_plays_the_yard_and_an_unknown_one_warns_and_plays_the_yard() -> void:
	var none := MapData.parse(JSON.stringify({"name": "Bare"}), MapStyle.new(), 1)
	assert_eq(none.ambience, &"yard")
	assert_eq(none.warnings, [] as Array[String], "no ambience is no warning")
	var woods := MapData.parse(JSON.stringify({"ambience": "woods"}), MapStyle.new(), 1)
	assert_eq(woods.ambience, &"woods")
	var city := MapData.parse(JSON.stringify({"ambience": "city"}), MapStyle.new(), 1)
	assert_eq(city.ambience, &"yard", "the city went with Neon Heights: unknown now")
	var unknown := MapData.parse(JSON.stringify({"ambience": "swamp"}), MapStyle.new(), 1)
	assert_eq(unknown.ambience, &"yard")
	assert_eq(unknown.warnings.size(), 1)
	assert_string_contains(unknown.warnings[0] if not unknown.warnings.is_empty() else "", "swamp")
	var not_text := MapData.parse(JSON.stringify({"ambience": 3}), MapStyle.new(), 1)
	assert_eq(not_text.ambience, &"yard")
	assert_eq(not_text.warnings.size(), 1, "a number is not an ambience")


static func _loops(s: AmbienceSet) -> Array[String]:
	var out: Array[String] = []
	for bed in s.beds:
		out.append(String(bed.loop))
	return out


static func _cues(s: AmbienceSet) -> Array[String]:
	var out: Array[String] = []
	for c in s.calls:
		out.append(String(c.cue))
	return out
