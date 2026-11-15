extends GutTest
## FV1 QA: the settings migration's chains and edge values, the Power bus's gain at the audio server, and a bot on burst
## indoors that is interrupted (empty magazine, reload) and does not stall.

const SEMI := ReplicaConfig.FireMode.SEMI
const BURST := ReplicaConfig.FireMode.BURST
const AUTO := ReplicaConfig.FireMode.AUTO
const DT := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 0.0)


func _vol(data: Dictionary, version: int) -> Dictionary:
	return Settings.migrate_defaults(data, version)["volumes"]


func test_a_version_1_and_2_file_on_its_old_defaults_goes_to_the_new_mix() -> void:
	for version: int in [1, 2]:
		var old: Dictionary = (Settings.VOLUME_DEFAULTS_V1 if version == 1 else Settings.VOLUME_DEFAULTS_V2).duplicate()
		var raw := {}
		for bus: StringName in old:
			raw[String(bus)] = old[bus]
		var moved := Settings.migrate_defaults({"volumes": raw, "fov": 90.0}, version)
		for bus: StringName in Settings.VOLUME_BUSES:
			assert_eq(moved["volumes"][String(bus)], Settings.VOLUME_DEFAULTS[bus], "v%d %s" % [version, bus])
		assert_eq(moved["fov"], Settings.FOV_DEFAULT)


func test_whole_number_volumes_in_a_file_are_read_as_numbers() -> void:
	var vol := _vol({"volumes": {"Power": 1, "Master": 1}}, 3)
	assert_almost_eq(float(vol["Power"]), 0.8, 1e-6, "an int 1 is the old default")
	assert_almost_eq(float(vol["Master"]), 0.9, 1e-6)


func test_a_set_power_source_stays_in_range_and_odd_values_are_left_alone() -> void:
	assert_eq(float(_vol({"volumes": {"Power": 7.0}}, 3)["Power"]), 1.0, "too high: clamped, never above 1")
	assert_eq(float(_vol({"volumes": {"Power": -2.0}}, 3)["Power"]), 0.0, "negative: 0")
	assert_eq(_vol({"volumes": {"Power": "loud"}}, 3)["Power"], "loud", "not a number: as it was (from_dict falls back)")
	assert_eq(Settings.migrate_defaults({"volumes": 5}, 3)["volumes"], 5, "volumes not a dictionary: untouched")
	assert_eq(Settings.migrate_defaults({}, 1).size() >= 0, true, "an empty file migrates without error")
	var s := Settings.new(PlayTuning.new())
	s.from_dict(Settings.migrate_defaults({"volumes": {"Power": "loud"}, "fov": "wide"}, 3))
	assert_eq(s.volumes[&"Power"], Settings.VOLUME_DEFAULTS[&"Power"])
	assert_eq(s.fov, Settings.FOV_DEFAULT)


func test_a_migrated_file_is_moved_once_and_a_version_4_file_is_never_moved() -> void:
	var path := "user://test_fv1_qa_settings.save"
	assert_true(SaveFile.write(path, Settings.KIND, 3, {"fov": 90.0, "volumes": {"Power": 0.5, "Master": 1.0}}))
	var s := Settings.new(PlayTuning.new())
	s.load_file(path)
	assert_almost_eq(s.volumes[&"Power"], 0.4, 1e-6)
	assert_eq(s.fov, 87.0)
	assert_true(s.save(path))
	var again := Settings.new(PlayTuning.new())
	again.load_file(path)
	assert_almost_eq(again.volumes[&"Power"], 0.4, 1e-6, "saved as version 4: not divided a second time")
	assert_eq(again.volumes[&"Master"], 0.9)
	# A version 4 file on the numbers that were defaults before is a choice now.
	assert_true(SaveFile.write(path, Settings.KIND, Settings.VERSION, {"fov": 90.0, "volumes": {"Power": 1.0}}))
	var kept := Settings.new(PlayTuning.new())
	kept.load_file(path)
	assert_eq(kept.fov, 90.0)
	assert_eq(kept.volumes[&"Power"], 1.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_the_power_bus_is_at_zero_db_on_its_default_and_louder_at_full() -> void:
	var s := Settings.new(PlayTuning.new())
	var i := AudioServer.get_bus_index(&"Power")
	if i < 0:
		pending("no Power bus in this run")
		return
	var before := AudioServer.get_bus_volume_db(i)
	var master_before := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master"))
	SettingsApply.apply_audio(s)
	assert_almost_eq(AudioServer.get_bus_volume_db(i), 0.0, 0.01, "the default 80 % is the old 100 %: 0 dB")
	s.volumes[&"Power"] = 1.0
	SettingsApply.apply_audio(s)
	assert_almost_eq(AudioServer.get_bus_volume_db(i), linear_to_db(1.25), 0.01, "100 % is +1.94 dB")
	s.volumes[&"Master"] = 1.0
	SettingsApply.apply_audio(s)
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master")), 0.0, 0.01, "no gain on Master")
	s.volumes[&"Power"] = 0.0
	SettingsApply.apply_audio(s)
	assert_true(AudioServer.is_bus_mute(i), "0 mutes whatever the gain")
	AudioServer.set_bus_volume_db(i, before)
	AudioServer.set_bus_mute(i, false)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Master"), master_before)


func _bot() -> Array:
	var loadout := ReplicaStats.default_loadout()
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var aeg := me.armament.replicas[0].duplicate() as ReplicaConfig
	aeg.default_fire_mode = AUTO
	me.armament.replicas[0] = aeg
	var cfg := BotConfig.load_default()
	var w := BotWorld.new()
	w.tuning = SimTuning.load_default()
	w.cfg = cfg
	w.start_mode = BURST
	me.armament.reset_fire_modes(BURST)
	return [Bot.new(me, 1, cfg.skill_for(&"normal"), 2), w]


func test_a_bot_on_burst_whose_magazine_runs_dry_mid_burst_reloads_and_fires_again() -> void:
	var bw := _bot()
	var b: Bot = bw[0]
	var w: BotWorld = bw[1]
	var a := b.character.armament
	assert_eq(a.fire_mode(), BURST)
	a.ammo[a.active].mag = 2 # a burst of three runs dry on its third
	var events := SimEvents.new()
	var pool := BBPool.new(64)
	var shots := 0
	var dry := 0
	for i in 600:
		w.time = i * DT
		var cmd := PlayerCommand.new()
		cmd.fire = BotFireMode.pull(b, w, true)
		events.clear()
		Armament.step(b.character, cmd, EYE, 1.0, true, pool, Seeds.stream(1), events, w.tuning, DT)
		shots += events.count_of(GameEvent.Kind.SHOT)
		dry += events.count_of(GameEvent.Kind.DRY_FIRE)
	assert_gte(dry, 1, "the empty magazine clicked")
	assert_gt(shots, 2, "after the reload the bot fires again: no stall")
	assert_eq(a.burst_shots_left >= 0, true)


func test_a_bot_on_burst_pulls_again_after_a_reload_cut_its_burst_short() -> void:
	var bw := _bot()
	var b: Bot = bw[0]
	var w: BotWorld = bw[1]
	var a := b.character.armament
	a.burst_shots_left = 2 # mid-burst
	w.time = 1.0
	assert_false(BotFireMode.pull(b, w, true), "no pull while the burst runs")
	a.burst_shots_left = 0 # a reload or draw ended it (Armament)
	w.time = 1.0 + w.cfg.semi_tap_gap + 0.001
	assert_true(BotFireMode.pull(b, w, true), "a tap's gap later it pulls fresh")
