extends GutTest
## QA for AU1 (bots' gunfire heard, ambience quieter): the settings file at versions 1, 2 and 3 and as a bundle's store,
## a shot whose shooter is gone, voices reused between a shot and other sounds keeping each one's own distance, the
## range's targets and the ambience calls keeping theirs, and the extremes of the new levels.

const ROOT := "user://test-au1-qa"

var dir := ""
var path := ""
var _n := 0
var cfg: SoundConfig = null
var body: BodyConfig = BodyConfig.new()
var audio: SimAudio = null
var state: GameState = null
var you: Character = null
var enemy: Character = null


func before_each() -> void:
	_n += 1
	dir = "%s/%d" % [ROOT, _n]
	_wipe(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	path = dir.path_join("settings.save")
	cfg = SoundConfig.new()
	for spread: String in ["shot_spread_db", "mechanism_spread_db", "step_spread_db", "impact_spread_db"]:
		cfg.set(spread, 0.0)
	state = GameState.new(1)
	you = Character.new(0, 0, Vector3.ZERO, 0.0, [ReplicaConfig.new()] as Array[ReplicaConfig])
	state.characters.append(you)


func after_all() -> void:
	_wipe(ROOT)


func _wipe(at: String) -> void:
	if not DirAccess.dir_exists_absolute(at):
		return
	for d: String in DirAccess.get_directories_at(at):
		_wipe(at.path_join(d))
	for f: String in DirAccess.get_files_at(at):
		DirAccess.remove_absolute(at.path_join(f))
	DirAccess.remove_absolute(at)


func _load(version: int, data: Dictionary) -> Settings:
	SaveFile.write(path, Settings.KIND, version, data)
	var t := Settings.new(PlayTuning.new())
	t.load_file(path)
	return t


func _setup_audio(night: bool = false, ambience: StringName = AmbienceConfig.DEFAULT_ID) -> void:
	audio = SimAudio.new()
	audio.night = night
	add_child_autofree(audio)
	var map: MapData = null
	if ambience != AmbienceConfig.DEFAULT_ID:
		map = MapData.new()
		map.ambience = ambience
	audio.setup(cfg, [&"electric"] as Array[StringName], body, BoxWorld.new(body), map)


func _enemy_at(z: float) -> void:
	enemy = Character.new(1, 1, Vector3(0.0, 0.0, z), 0.0, [ReplicaConfig.new()] as Array[ReplicaConfig])
	state.characters.append(enemy)


func _shot_event(actor: int, at: Vector3) -> void:
	var shot := state.events.add(GameEvent.Kind.SHOT)
	shot.actor = actor
	shot.slot = 0
	shot.position = at


func _step_event(at: Vector3) -> void:
	var step := state.events.add(GameEvent.Kind.FOOTSTEP)
	step.actor = enemy.id
	step.value = GameEvent.Footstep.RUN
	step.position = at


## The playing field voices whose stream belongs to a cue starting with `prefix`.
func _voices(prefix: String) -> Array[AudioStreamPlayer3D]:
	var out: Array[AudioStreamPlayer3D] = []
	for v in audio._field:
		if not v.playing:
			continue
		for cue: StringName in audio._streams:
			if String(cue).begins_with(prefix) and (audio._streams[cue] as Array).has(v.stream):
				out.append(v)
				break
	return out


# --- the settings file ---

func test_a_version_2_file_with_the_old_ambience_default_loads_at_20_percent() -> void:
	var t := _load(2, {"volumes": {"Master": 1.0, "Effects": 0.7, "Power": 1.0, "Ambience": 0.3, "Interface": 0.4}})
	assert_eq(t.load_message, "", "an older file is not a damaged one")
	assert_eq(t.volumes[&"Ambience"], 0.2)
	assert_eq(t.volumes[&"Effects"], 0.7)


func test_a_version_2_file_with_a_chosen_ambience_keeps_it() -> void:
	for chosen: float in [0.0, 0.1, 0.25, 0.5, 1.0]:
		var t := _load(2, {"volumes": {"Ambience": chosen}})
		assert_almost_eq(t.volumes[&"Ambience"], chosen, 1e-6, "ambience %.2f" % chosen)


func test_a_version_3_file_keeps_an_ambience_the_player_set_to_the_old_default() -> void:
	var t := _load(Settings.VERSION, {"volumes": {"Ambience": 0.3}})
	assert_almost_eq(t.volumes[&"Ambience"], 0.3, 1e-6, "chosen on purpose after the move")


func test_a_version_1_file_untouched_lands_on_the_newest_ambience_in_one_step() -> void:
	var t := _load(1, {"volumes": {"Ambience": 0.6, "Master": 1.0, "Effects": 0.8, "Power": 1.0, "Interface": 0.5}})
	assert_eq(t.volumes[&"Ambience"], Settings.VOLUME_DEFAULTS[&"Ambience"], "0.6 goes to 0.2, not stopping at 0.3")
	assert_eq(t.volumes[&"Effects"], Settings.VOLUME_DEFAULTS[&"Effects"])


func test_a_version_2_file_without_or_with_a_bad_volumes_entry_gets_the_defaults() -> void:
	assert_eq(_load(2, {}).volumes[&"Ambience"], 0.2, "no volumes")
	assert_eq(_load(2, {"volumes": "loud"}).volumes[&"Ambience"], 0.2, "volumes not a dictionary")
	assert_eq(_load(2, {"volumes": {"Ambience": "0.3"}}).volumes[&"Ambience"], 0.2, "a string keeps the default")
	assert_eq(_load(2, {"volumes": {"Ambience": 3.0}}).volumes[&"Ambience"], 0.2, "out of range keeps the default")
	assert_eq(_load(2, {"volumes": {"Ambience": null}}).volumes[&"Ambience"], 0.2, "null keeps the default")


func test_the_move_happens_once_a_later_choice_of_30_percent_survives_restarts() -> void:
	var t := _load(2, {"volumes": {"Ambience": 0.3}})
	assert_eq(t.volumes[&"Ambience"], 0.2)
	t.volumes[&"Ambience"] = 0.3
	assert_true(t.save(path))
	assert_eq(int(SaveFile.read(path, Settings.KIND).version), Settings.VERSION, "saved as the newest version")
	for i in 3:
		var again := Settings.new(PlayTuning.new())
		again.load_file(path)
		assert_almost_eq(again.volumes[&"Ambience"], 0.3, 1e-6, "start %d" % i)
		assert_true(again.save(path))


func test_a_version_2_file_keeps_its_window_and_v_sync_as_they_are() -> void:
	# Version 1's window and V-Sync moves must not run on a version 2 file (FB2 already moved or the player chose).
	var t := _load(2, {"window_mode": Settings.WindowMode.WINDOWED, "vsync": true, "volumes": {}})
	assert_eq(t.window_mode, Settings.WindowMode.WINDOWED)
	assert_true(t.vsync)


func test_a_bundle_holding_version_2_settings_migrates_the_ambience_on_load() -> void:
	var data := {"volumes": {"Ambience": 0.3, "Effects": 0.9}}
	var bundle := SaveBundle.from_dict({"saved_at": 1, "version": Version.current(),
			"stores": {"settings": {"version": 2, "data": data}}})
	assert_eq(bundle.refusal(), "", "a version 2 settings store is still read")
	var paths: Array[String] = []
	for p: String in SaveBundle.PATHS:
		paths.append(dir.path_join(p.get_file()))
	assert_true(bundle.write(paths))
	var t := Settings.new(PlayTuning.new())
	t.load_file(paths[SaveBundle.KINDS.find(Settings.KIND)])
	assert_eq(t.volumes[&"Ambience"], 0.2)
	assert_eq(t.volumes[&"Effects"], 0.9)


func test_migrating_a_version_2_dictionary_leaves_the_one_it_was_given_alone() -> void:
	var data := {"volumes": {"Ambience": 0.3}}
	var moved := Settings.migrate_defaults(data, 2)
	assert_eq((data["volumes"] as Dictionary)["Ambience"], 0.3)
	assert_eq((moved["volumes"] as Dictionary)["Ambience"], 0.2)


func test_a_reset_gives_the_new_ambience_default() -> void:
	var s := Settings.new(PlayTuning.new())
	s.volumes[&"Ambience"] = 0.9
	s.reset_save(path)
	assert_eq(s.volumes[&"Ambience"], 0.2)


# --- the shot ---

func test_a_shot_from_a_shooter_who_is_gone_makes_no_error_and_no_sound() -> void:
	_setup_audio()
	_shot_event(99, Vector3(0.0, 1.5, 5.0))
	audio.on_tick(state, you.id, you)
	assert_eq(_voices("shot_").size(), 0, "no replica, no cue")
	assert_eq(_voices("power_").size(), 0)


func test_a_shot_from_a_slot_the_shooter_does_not_hold_makes_no_error_and_no_sound() -> void:
	_enemy_at(10.0)
	_setup_audio()
	var shot := state.events.add(GameEvent.Kind.SHOT)
	shot.actor = enemy.id
	shot.slot = 7
	shot.position = enemy.eye(body)
	audio.on_tick(state, you.id, you)
	assert_eq(_voices("shot_").size(), 0)
	assert_eq(_voices("power_").size(), 0)


func test_voices_reused_between_shots_and_other_sounds_keep_each_ones_own_distance() -> void:
	_enemy_at(10.0)
	_setup_audio()
	var heard := 0
	for round in 60:
		state.events.clear()
		if round % 2 == 0:
			_shot_event(enemy.id, enemy.eye(body))
		else:
			_step_event(enemy.position)
		audio.on_tick(state, you.id, you)
		for v in _voices("shot_") + _voices("power_"):
			heard += 1
			assert_eq(v.unit_size, cfg.shot_unit_size, "round %d shot" % round)
			assert_eq(v.max_distance, cfg.shot_reach)
		for v in _voices("step_"):
			assert_eq(v.unit_size, cfg.unit_size, "round %d step on a voice a shot may have used" % round)
			assert_eq(v.max_distance, cfg.step_reach)
		for v in audio._field:
			v.stop() # finished: the next sound takes the first free voice, the one this one used
	assert_gt(heard, 0)


func test_a_voice_that_played_a_shot_then_a_range_target_has_the_targets_distance() -> void:
	_enemy_at(10.0)
	_setup_audio()
	_shot_event(enemy.id, enemy.eye(body))
	audio.on_tick(state, you.id, you)
	assert_gt(_voices("shot_").size(), 0)
	for v in audio._field:
		v.stop() # the shot is over: the next sound takes the first free voice, the shot's
	state.events.clear()
	var hit := state.events.add(GameEvent.Kind.TARGET_HIT)
	hit.actor = you.id
	hit.value = RangeTarget.Kind.STEEL
	hit.position = Vector3(0.0, 1.0, 70.0)
	audio.on_tick(state, you.id, you)
	var ring := _voices("steelRing")
	assert_gt(ring.size(), 0, "the ring rings 70 m off")
	for v in ring:
		assert_eq(v.unit_size, cfg.unit_size, "not the shot's 10 m left on the voice")
		assert_eq(v.max_distance, cfg.target_reach)


func test_the_ambience_calls_keep_the_fields_distance_and_play_at_the_scaled_level() -> void:
	cfg = (load("res://game/config/play_tuning.tres") as PlayTuning).sound
	_setup_audio()
	audio.on_tick(state, you.id, you)
	state.time = audio._calls.next_at(0)
	audio.on_tick(state, you.id, you)
	var bird: AudioStreamPlayer3D = null
	for v in audio._field:
		if v.playing and (audio._streams[&"ambience_bird"] as Array).has(v.stream):
			bird = v
	assert_not_null(bird, "a bird calls")
	if bird == null:
		return
	assert_eq(bird.unit_size, cfg.unit_size, "a call is not given a shot's reach")
	assert_gte(bird.max_distance, you.eye(body).distance_to(bird.global_position))
	var kind: AmbienceCall = cfg.ambiences.set_for(AmbienceConfig.DEFAULT_ID, false).calls[0]
	assert_almost_eq(bird.volume_db, linear_to_db(kind.level * cfg.ambience_gain), 1e-3)


func test_every_field_by_day_and_night_plays_its_beds_at_the_scaled_level() -> void:
	cfg = (load("res://game/config/play_tuning.tres") as PlayTuning).sound
	var peaks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SoundConfig.PEAKS_PATH))
	for id: StringName in AmbienceConfig.IDS:
		for night: bool in [false, true]:
			_setup_audio(night, id)
			var set := cfg.ambiences.set_for(id, night)
			assert_eq(audio._beds.size(), set.beds.size(), "%s night=%s" % [id, night])
			for i in audio._beds.size():
				var old_db := linear_to_db(set.beds[i].gain * float(peaks[String(set.beds[i].loop)]))
				assert_almost_eq(audio._beds[i].volume_db, old_db + linear_to_db(cfg.ambience_gain), 1e-3)
			audio.free()
			audio = null


func test_an_ambience_gain_of_zero_is_silent_and_raises_no_error() -> void:
	cfg = (load("res://game/config/play_tuning.tres") as PlayTuning).sound
	cfg.ambience_gain = 0.0
	_setup_audio()
	assert_gt(audio._beds.size(), 0)
	for bed in audio._beds:
		assert_true(is_inf(bed.volume_db) and bed.volume_db < 0.0, "-inf dB, not NaN")
	audio.on_tick(state, you.id, you)
	state.time = audio._calls.next_at(0)
	audio.on_tick(state, you.id, you)
	pass_test("reached without a script error")


func test_a_power_gain_of_zero_and_an_unlisted_source_do_not_break_the_shot() -> void:
	cfg.power_gains = {}
	cfg.power_gain = 0.0
	_enemy_at(10.0)
	_setup_audio()
	_shot_event(enemy.id, enemy.eye(body))
	audio.on_tick(state, you.id, you)
	assert_gt(_voices("shot_").size(), 0, "the shot still plays")
	for v in _voices("power_"):
		assert_true(is_inf(v.volume_db) and v.volume_db < 0.0)


func test_a_shot_at_the_reach_plays_and_a_little_past_it_does_not() -> void:
	_enemy_at(cfg.shot_reach)
	_setup_audio()
	var ear_y := you.eye(body).y
	_shot_event(enemy.id, Vector3(0.0, ear_y, cfg.shot_reach - 0.5))
	audio.on_tick(state, you.id, you)
	assert_gt(_voices("shot_").size(), 0, "just inside")
	for v in audio._field:
		v.stop()
	state.events.clear()
	_shot_event(enemy.id, Vector3(0.0, ear_y, cfg.shot_reach + 0.5))
	audio.on_tick(state, you.id, you)
	assert_eq(_voices("shot_").size(), 0, "past it")


func test_your_own_shot_plays_on_the_plain_voices_not_the_positional_ones() -> void:
	_setup_audio()
	_shot_event(you.id, you.eye(body))
	audio.on_tick(state, you.id, you)
	var heard := 0
	for v in audio._own:
		heard += int(v.playing)
	assert_gt(heard, 0, "your shot plays")
	assert_eq(_voices("shot_").size(), 0, "never on the positional ones")
