extends GutTest
## FV1 (owner, 2026-11-15): indoor fields start a replica that comes on full auto on burst, not semi (one without burst
## on semi), and bots there tap a burst at a time at a player's pace; the default field of view is 87, and a save from
## before still on the old 90 moves to it while one the player set is kept.

const SEMI := ReplicaConfig.FireMode.SEMI
const BURST := ReplicaConfig.FireMode.BURST
const AUTO := ReplicaConfig.FireMode.AUTO
const DT := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 0.0)

var config: BotConfig = BotConfig.load_default()


func test_the_indoor_fields_start_on_burst_and_the_open_ones_as_they_come() -> void:
	var cat := MapCatalog.read_file()
	assert_eq(cat.problems, [] as Array[String])
	for id: String in ["depot", "subway"]:
		assert_eq(cat.find(id).start_mode, BURST, "%s starts on burst" % id)
	for id: String in ["woodland", "range"]:
		assert_eq(cat.find(id).start_mode, AUTO, "%s starts replicas as they come" % id)


func test_on_burst_the_aeg_starts_on_burst_the_smg_and_the_cyber_on_semi() -> void:
	var stats := ReplicaStats.read_file()
	assert_eq(Armament.start_mode(stats.replica_config(&"aeg"), BURST), BURST, "the AEG, full auto out of the box")
	assert_eq(Armament.start_mode(stats.replica_config(&"smg"), BURST), SEMI, "no burst: semi, never full auto")
	assert_eq(Armament.start_mode(stats.replica_config(&"cyber"), BURST), SEMI, "comes on semi: kept on semi")
	for id: StringName in [&"pistol", &"sniper", &"shotgun"]:
		var r := stats.replica_config(id)
		assert_eq(Armament.start_mode(r, BURST), r.default_fire_mode, "%s as it comes" % id)


func _bot(start: ReplicaConfig.FireMode) -> Array:
	var loadout := ReplicaStats.default_loadout()
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var aeg := me.armament.replicas[0].duplicate() as ReplicaConfig
	aeg.default_fire_mode = AUTO
	me.armament.replicas[0] = aeg
	var w := BotWorld.new()
	w.tuning = SimTuning.load_default()
	w.cfg = config
	w.start_mode = start
	me.armament.reset_fire_modes(start)
	return [Bot.new(me, 1, config.skill_for(&"normal"), 2), w]


## Shots a bot `b` fires in `seconds` with its trigger wanted down all the while, each pull through BotFireMode.pull;
## `pulls` gets the world time of every pull.
func _fire(b: Bot, w: BotWorld, seconds: float, pulls: PackedFloat64Array) -> int:
	var events := SimEvents.new()
	var pool := BBPool.new(256)
	var shots := 0
	for i in roundi(seconds / DT):
		w.time = i * DT
		var cmd := PlayerCommand.new()
		cmd.fire = BotFireMode.pull(b, w, true)
		if cmd.fire:
			pulls.append(w.time)
		events.clear()
		Armament.step(b.character, cmd, EYE, 1.0, true, pool, Seeds.stream(1), events, w.tuning, DT)
		shots += events.count_of(GameEvent.Kind.SHOT)
	return shots


func test_a_bot_on_burst_indoors_fires_burst_after_burst_at_a_player_s_pace() -> void:
	var bw := _bot(BURST)
	var b: Bot = bw[0]
	var w: BotWorld = bw[1]
	assert_eq(b.character.armament.fire_mode(), BURST)
	var pulls := PackedFloat64Array()
	var shots := _fire(b, w, 1.0, pulls)
	var burst := w.tuning.replica_rules.burst_shots
	assert_gt(pulls.size(), 1, "a held trigger is pulled again: not one burst and nothing more")
	assert_eq(shots, pulls.size() * burst, "every pull a whole burst, none lost mid-burst")
	var rate := b.character.armament.replicas[0].fire_rate
	var burst_time := (burst - 1) / rate
	for i in range(1, pulls.size()):
		assert_gte(pulls[i] - pulls[i - 1], burst_time + config.semi_tap_gap - 1e-6,
				"a tap's gap after the burst before it ends")
	assert_lt(shots, roundi(rate), "fewer BBs a second than full auto")
	# Against semi on the same field: a burst at a time puts more BBs out than single taps.
	var sw := _bot(SEMI)
	assert_gt(shots, _fire(sw[0], sw[1], 1.0, PackedFloat64Array()), "more than semi taps")


func test_outdoors_a_bot_s_trigger_is_as_wanted_whatever_the_mode() -> void:
	var bw := _bot(AUTO)
	var b: Bot = bw[0]
	var w: BotWorld = bw[1]
	b.character.armament.modes[0] = BURST
	w.time = 0.0
	assert_true(BotFireMode.pull(b, w, true))
	assert_true(BotFireMode.pull(b, w, true), "no tap gap where there is no start mode")
	assert_false(BotFireMode.pull(b, w, false))


func test_the_default_field_of_view_is_87_in_the_settings_and_the_camera() -> void:
	assert_eq(Settings.FOV_DEFAULT, 87.0)
	assert_eq(Settings.new(PlayTuning.new()).fov, 87.0)
	assert_eq(ViewConfig.new().horizontal_fov_16x9, Settings.FOV_DEFAULT, "the camera starts where the settings do")


func test_an_older_save_still_on_90_moves_to_87_and_one_the_player_set_is_kept() -> void:
	for version: int in [1, 2, 3, 4]:
		assert_eq(Settings.migrate_defaults({"fov": 90.0}, version)["fov"], Settings.FOV_DEFAULT, "v%d on 90" % version)
		assert_eq(Settings.migrate_defaults({"fov": 90}, version)["fov"], Settings.FOV_DEFAULT, "v%d whole 90" % version)
		assert_eq(Settings.migrate_defaults({"fov": 95.0}, version)["fov"], 95.0, "v%d set by the player" % version)
		assert_false(Settings.migrate_defaults({}, version).has("fov"), "v%d without one: the default" % version)
	assert_eq(Settings.migrate_defaults({"fov": 90.0}, Settings.VERSION)["fov"], 90.0, "picked in this build: kept")


func test_a_version_3_save_moves_only_the_field_of_view() -> void:
	var data := {"fov": 90.0, "vsync": true, "window_mode": 0, "volumes": {"Ambience": 0.3, "Effects": 0.8}}
	var moved := Settings.migrate_defaults(data, 3)
	var vol: Dictionary = moved["volumes"]
	assert_eq(vol["Ambience"], 0.3, "version 3's ambience is the player's own: not moved again")
	assert_eq(vol["Effects"], 0.8)
	assert_eq(moved["vsync"], true)
	assert_eq(moved["window_mode"], 0)
	assert_eq(data["fov"], 90.0, "the argument is untouched")


func test_a_version_3_file_on_disk_loads_on_87() -> void:
	var path := "user://test_fv1_settings.save"
	assert_true(SaveFile.write(path, Settings.KIND, 3, {"fov": 90.0}))
	var s := Settings.new(PlayTuning.new())
	s.load_file(path)
	assert_eq(s.fov, Settings.FOV_DEFAULT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_the_new_mix_is_the_owner_s_and_the_power_source_plays_louder_than_its_slider() -> void:
	var want := {&"Master": 0.9, &"Effects": 0.8, &"Power": 0.8, &"Ambience": 0.3, &"Interface": 0.4}
	for bus: StringName in Settings.VOLUME_BUSES:
		assert_eq(Settings.VOLUME_DEFAULTS[bus], want[bus], String(bus))
	assert_almost_eq(0.8 * Settings.VOLUME_GAINS[&"Power"], 1.0, 1e-6, "the slider's 80 % is the old 100 %")


func test_a_version_3_save_on_the_old_mix_moves_to_the_new_one_and_a_set_power_source_sounds_the_same() -> void:
	var old := {"Master": 1.0, "Effects": 0.7, "Power": 1.0, "Ambience": 0.2, "Interface": 0.4}
	var vol: Dictionary = Settings.migrate_defaults({"volumes": old}, 3)["volumes"]
	for bus: StringName in Settings.VOLUME_BUSES:
		assert_eq(vol[String(bus)], Settings.VOLUME_DEFAULTS[bus], "%s on the old default: moved" % bus)
	var set_by_player: Dictionary = Settings.migrate_defaults({"volumes": {"Power": 0.5, "Master": 0.6}}, 3)["volumes"]
	assert_almost_eq(float(set_by_player["Power"]), 0.4, 1e-6, "0.5 then sounds as 0.4 does now")
	assert_eq(set_by_player["Master"], 0.6, "a bus without a gain is kept as set")
	var muted: Dictionary = Settings.migrate_defaults({"volumes": {"Power": 0.0}}, 3)["volumes"]
	assert_eq(float(muted["Power"]), 0.0, "muted stays muted")
	var current: Dictionary = Settings.migrate_defaults({"volumes": {"Power": 0.5}}, Settings.VERSION)["volumes"]
	assert_eq(current["Power"], 0.5, "set in this build: never scaled again")


func test_a_bot_s_stop_burst_ends_a_burst_under_way_and_a_player_s_burst_runs_its_course() -> void:
	var bw := _bot(BURST)
	var b: Bot = bw[0]
	var w: BotWorld = bw[1]
	var c := b.character
	var events := SimEvents.new()
	var pool := BBPool.new(16)
	var shots := 0
	for stop: bool in [false, true]:
		c.armament.refill()
		c.armament.cooldown = 0.0
		c.armament.trigger_was_down = false
		shots = 0
		for i in 30:
			var cmd := PlayerCommand.new()
			cmd.fire = i == 0
			# The tick after the first BB, the line of fire goes (a teammate in front): the bot lets off.
			cmd.stop_burst = stop and i >= 1
			events.clear()
			Armament.step(c, cmd, EYE, 1.0, true, pool, Seeds.stream(1), events, w.tuning, DT)
			shots += events.count_of(GameEvent.Kind.SHOT)
		var burst := w.tuning.replica_rules.burst_shots
		assert_eq(shots, 1 if stop else burst, "stopped after one" if stop else "a whole burst")
	assert_false(PlayerCommand.new().stop_burst, "never set unless a bot sets it")


func test_a_version_4_save_from_the_haze_build_moves_its_old_defaults_and_keeps_its_haze() -> void:
	var data := {"fov": 90.0, "graphics_custom": {"volumetric_fog": "on"},
			"volumes": {"Master": 1.0, "Effects": 0.7, "Power": 0.5, "Ambience": 0.2, "Interface": 0.4}}
	var moved := Settings.migrate_defaults(data, 4)
	assert_eq(moved["fov"], Settings.FOV_DEFAULT)
	var vol: Dictionary = moved["volumes"]
	assert_eq(vol["Master"], Settings.VOLUME_DEFAULTS[&"Master"])
	assert_almost_eq(float(vol["Power"]), 0.4, 1e-6, "a set Power source sounds the same")
	assert_eq((moved["graphics_custom"] as Dictionary)["volumetric_fog"], "on",
			"version 4 already reads haze levels: VF1's step is for version 3 and older")
