extends GutTest
## Bots' gunfire heard and the ambience turned down (AU1; owner, 2026-11-01 playtest): another's shot and its power part
## carry shot_reach at full level within shot_unit_size while their other sounds keep unit_size and max_distance; a
## silenced replica's shot carries its heard_scale of that; each power source's part plays at its power_gains level; the
## beds and calls play at ambience_gain of their level; the Ambience volume starts at 20 %; Master has a limiter.

var cfg: SoundConfig = null
var body: BodyConfig = BodyConfig.new()
var world: BoxWorld = null
var audio: SimAudio = null
var state: GameState = null
var you: Character = null
var enemy: Character = null


## Levels unspread, so a voice's level reads exactly; you at the origin.
func before_each() -> void:
	cfg = SoundConfig.new()
	for spread: String in ["shot_spread_db", "mechanism_spread_db", "step_spread_db"]:
		cfg.set(spread, 0.0)
	world = BoxWorld.new(body)
	state = GameState.new(1)
	you = Character.new(0, 0, Vector3.ZERO, 0.0, [ReplicaConfig.new()] as Array[ReplicaConfig])
	state.characters.append(you)


func _enemy_at(z: float, replica: ReplicaConfig = ReplicaConfig.new()) -> void:
	enemy = Character.new(1, 1, Vector3(0.0, 0.0, z), 0.0, [replica] as Array[ReplicaConfig])
	state.characters.append(enemy)
	audio = SimAudio.new()
	add_child_autofree(audio)
	audio.setup(cfg, [&"electric"] as Array[StringName], body, world, null)


## The enemy's shot and a run step on one tick, heard by you.
func _shot_and_step() -> void:
	state.events.clear()
	var shot := state.events.add(GameEvent.Kind.SHOT)
	shot.actor = enemy.id
	shot.slot = 0
	shot.position = enemy.eye(body)
	var step := state.events.add(GameEvent.Kind.FOOTSTEP)
	step.actor = enemy.id
	step.value = GameEvent.Footstep.RUN
	step.position = enemy.position
	audio.on_tick(state, you.id, you)


func _voice(prefix: String) -> AudioStreamPlayer3D:
	for v in audio._field:
		if not v.playing:
			continue
		for cue: StringName in audio._streams:
			if String(cue).begins_with(prefix) and (audio._streams[cue] as Array).has(v.stream):
				return v
	return null


## Godot's level for a voice at `d` m (AudioStreamPlayer3D, inverse distance): the play's level over distance capped
## at max_db, faded to nothing at max_distance (linear).
static func _heard(volume_db: float, unit_size: float, max_distance: float, max_db: float, d: float) -> float:
	var db := minf(volume_db + linear_to_db(unit_size / d), max_db)
	return db_to_linear(db) * maxf(0.0, 1.0 - d / max_distance)


func test_a_shot_and_its_power_part_carry_further_than_a_step() -> void:
	_enemy_at(10.0)
	_shot_and_step()
	var shot := _voice("shot_")
	var power := _voice("power_")
	var step := _voice("step_")
	assert_not_null(shot, "the shot plays")
	assert_not_null(power, "its power part plays")
	assert_not_null(step, "the step plays")
	if shot == null or power == null or step == null:
		return
	for v: AudioStreamPlayer3D in [shot, power]:
		assert_eq(v.unit_size, cfg.shot_unit_size, "full level within the shot's own distance")
		assert_eq(v.max_distance, cfg.shot_reach, "heard out to shot_reach")
	assert_eq(step.unit_size, cfg.unit_size, "a step keeps the field's distance")
	assert_eq(step.max_distance, cfg.step_reach)
	assert_almost_eq(shot.max_db, maxf(shot.volume_db, cfg.field_max_db), 1e-3, "a shot: its own level or the field's")
	assert_almost_eq(power.max_db, power.volume_db, 1e-3, "the lifted motor at its own level")
	assert_eq(step.max_db, cfg.field_max_db, "a step keeps the field's cap")
	assert_almost_eq(power.volume_db, linear_to_db(cfg.power_gains[&"electric"]), 1e-3, "the motor at its own level")
	assert_almost_eq(shot.volume_db, linear_to_db(cfg.shot_gain), 1e-3, "the shot's level is unchanged")


func test_a_shot_beyond_the_old_reach_is_heard() -> void:
	var z := (cfg.max_distance + cfg.shot_reach) * 0.5
	_enemy_at(z)
	_shot_and_step()
	assert_not_null(_voice("shot_"), "a shot %.0f m off plays" % z)
	assert_null(_voice("step_"), "a step that far does not")


func test_a_shot_beyond_shot_reach_is_not_played() -> void:
	_enemy_at(cfg.shot_reach + 5.0)
	_shot_and_step()
	assert_null(_voice("shot_"))
	assert_null(_voice("power_"))


func test_a_silenced_shot_carries_its_heard_scale_of_the_reach() -> void:
	var silenced := ReplicaConfig.new()
	silenced.heard_scale = 0.5
	silenced.muffled = true
	_enemy_at(10.0, silenced)
	_shot_and_step()
	var shot := _voice("shot_")
	assert_not_null(shot)
	if shot != null:
		assert_almost_eq(shot.max_distance, cfg.shot_reach * 0.5, 1e-3)
	_enemy_far_silenced()


func _enemy_far_silenced() -> void:
	for v in audio._field:
		v.stop()
	enemy.position = Vector3(0.0, 0.0, cfg.shot_reach * 0.5 + 5.0)
	_shot_and_step()
	assert_null(_voice("shot_"), "past half the reach a silenced shot is not heard")


func test_a_bot_shot_at_30_m_is_far_louder_than_before() -> void:
	var cap := AudioStreamPlayer3D.new()
	var max_db := cap.max_db
	cap.free()
	var now := _heard(linear_to_db(cfg.shot_gain), cfg.shot_unit_size, cfg.shot_reach, max_db, 30.0)
	var before := _heard(linear_to_db(cfg.shot_gain), cfg.unit_size, cfg.max_distance, max_db, 30.0)
	assert_gt(linear_to_db(now) - linear_to_db(before), 10.0, "over 10 dB louder at 30 m")
	var near := _heard(linear_to_db(cfg.shot_gain), cfg.shot_unit_size, cfg.shot_reach, max_db, 1.0)
	assert_lte(linear_to_db(near), max_db, "a shot next to you no louder than the voices' cap")


func test_a_bot_s_motor_is_heard_louder_near_and_mid_range_and_never_louder_than_yours() -> void:
	var own_db := linear_to_db(cfg.power_gains[&"electric"])
	var old_db := linear_to_db(cfg.shot_gain)
	for d: float in [5.0, 20.0]:
		var now := _heard(own_db, cfg.shot_unit_size, cfg.shot_reach, own_db, d)
		var before := _heard(old_db, cfg.unit_size, cfg.max_distance, cfg.field_max_db, d)
		assert_gt(linear_to_db(now) - linear_to_db(before), own_db - old_db - 0.5, "at %.0f m: the whole lift" % d)
		assert_lte(linear_to_db(now), own_db + 1e-3, "at %.0f m: no louder than your own" % d)


func test_a_voice_reused_from_a_shot_for_a_step_takes_the_field_s_cap() -> void:
	_enemy_at(5.0)
	_shot_and_step()
	for v in audio._field:
		v.stop()
	state.events.clear()
	var step := state.events.add(GameEvent.Kind.FOOTSTEP)
	step.actor = enemy.id
	step.value = GameEvent.Footstep.RUN
	step.position = enemy.position
	audio.on_tick(state, you.id, you)
	for v in audio._field:
		if v.playing:
			assert_eq(v.max_db, cfg.field_max_db, "no shot's cap left on the voice")


func test_every_power_source_is_louder_than_before() -> void:
	for p: StringName in [&"electric", &"gas", &"spring"]:
		assert_true(cfg.power_gains.has(p), "%s has its level" % p)
		assert_gt(cfg.power_gains.get(p, 0.0), cfg.shot_gain * db_to_linear(3.0), "%s at least 3 dB over 1.4" % p)
	assert_gt(cfg.power_gains[&"electric"], cfg.power_gains[&"gas"], "the quiet motor lifted most")


func test_the_ambience_plays_at_its_share_of_its_level() -> void:
	assert_lt(cfg.ambience_gain, 1.0, "quieter than the browser game's levels")
	cfg.ambiences = (load("res://game/config/play_tuning.tres") as PlayTuning).sound.ambiences
	_enemy_at(10.0)
	var bed := cfg.ambiences.set_for(AmbienceConfig.DEFAULT_ID, false).beds[0]
	var peaks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SoundConfig.PEAKS_PATH))
	assert_false(audio._beds.is_empty(), "a bed plays")
	if not audio._beds.is_empty():
		var want := linear_to_db(bed.gain * float(peaks[String(bed.loop)]) * cfg.ambience_gain)
		assert_almost_eq(audio._beds[0].volume_db, want, 1e-3)


func test_the_ambience_volume_starts_at_20_percent() -> void:
	assert_eq(Settings.VOLUME_DEFAULTS[&"Ambience"], 0.2)
	assert_eq(Settings.new().volumes[&"Ambience"], 0.2)


func test_master_has_a_limiter() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	assert_gt(AudioServer.get_bus_effect_count(master), 0)
	assert_true(AudioServer.get_bus_effect(master, 0) is AudioEffectHardLimiter, "loud shots never clip the output")
	assert_true(AudioServer.is_bus_effect_enabled(master, 0))
