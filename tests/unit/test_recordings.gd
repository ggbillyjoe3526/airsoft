extends GutTest
## The owner's recordings (AU2, AU5, AU6, AU9, AU10, and the placeholders cut from them, AU3): every cue they replaced still has
## its variants, the three surfaces they added (glass, plastic, cardboard) sound as themselves and otherwise behave as the
## metal and wood they were before, and a gas pistol's last shot locks its slide back.

const VARIANTS := 5
## Cues cut from the recordings with 5 variants and with 3 (tools/cut_recordings.py).
const FIVE: PackedStringArray = ["shot_gas", "power_gas", "dryFire", "magOut_gas", "magIn_gas", "power_electric",
		"shot_electric", "magOut_electric", "magIn_electric", "shot_spring",
		"magOut_spring", "magIn_spring", "shot_cyber", "magOut_cyber", "magIn_cyber", "reloadRefused",
		"magRattle", "magToss", "magCatch", "torchClick", "impact_metal", "impact_wood", "bodyHit", "impact_glass",
		"impact_plastic", "impact_cardboard", "power_spring", "selector", "radio_ack", "steelRing", "vault",
		"impact_concrete", "impact_earth", "impact_leaves", "draw", "foley_holster", "rope_up", "rope_down",
		"door_open", "door_shut", "hitTick", "hitMarker", "foley_crouch", "foley_stand", "foley_lean",
		"step_concrete_run", "step_concrete_sprint", "step_concrete_land", "step_gravel_run", "step_leaves_run",
		"step_gravel_sprint", "step_grass_run", "step_grass_sprint", "step_grass_land", "step_metal_run",
		"step_metal_sprint", "step_wood_run", "step_wood_sprint", "step_wood_land", "step_metal_land", "step_earth_run",
		"step_earth_sprint", "step_earth_land", "step_water_run", "step_water_sprint", "step_water_land", "power_smg",
		"shot_smg", "magOut_smg", "magIn_smg"]
const THREE: PackedStringArray = ["slideLock_gas", "boltCycle", "prop_clank", "prop_rattle", "prop_plastic",
		"prop_wood", "whistle_short", "whistle_long", "prop_steel", "prop_glass", "flash_bang", "lift_doors"]

var body: BodyConfig = BodyConfig.new()
var audio: SimAudio = null
var state: GameState = null
var you: Character = null
var enemy: Character = null


func before_each() -> void:
	state = GameState.new(1)
	you = Character.new(0, 0, Vector3.ZERO, 0.0, [ReplicaConfig.new()] as Array[ReplicaConfig])
	state.characters.append(you)


func _variants(cue: String) -> int:
	var n := 0
	while ResourceLoader.exists("%s%s_%d.wav" % [SoundConfig.CUE_DIR, cue, n + 1]):
		n += 1
	return n


func test_every_recorded_cue_has_its_variants_and_no_more() -> void:
	for cue: String in FIVE:
		assert_eq(_variants(cue), VARIANTS, cue)
	for cue: String in THREE:
		assert_eq(_variants(cue), 3, cue)
	for cue: String in ["count_beep", "ping_pip"]:
		assert_eq(_variants(cue), 1, cue)
	# His lift's two rides (2026-11-11), each the car setting off.
	assert_eq(_variants("lift_motor"), 2, "lift_motor")


func _length(cue: String, n: int) -> float:
	return (load("%s%s_%d.wav" % [SoundConfig.CUE_DIR, cue, n]) as AudioStream).get_length()


func test_the_aegs_motor_runs_longer_under_each_shot() -> void:
	# AU3, owner: "a bit more of the electric motor whir": 0.16 s a shot (was 0.11).
	for n in VARIANTS:
		assert_almost_eq(_length("power_electric", n + 1), 0.16, 0.005, "power_electric_%d" % (n + 1))


func test_the_cyber_pistols_motor_runs_a_little_longer() -> void:
	# AU4, owner: "a tiny bit more of the motor whir": each shot 0.09 s (was 0.07).
	for n in VARIANTS:
		assert_almost_eq(_length("shot_cyber", n + 1), 0.09, 0.005, "shot_cyber_%d" % (n + 1))


func test_the_spring_rings_short() -> void:
	# AU4, owner: "a little quieter and less echo": the spring's part 0.16 s (was 0.33), since AU6 the last of his
	# recorded shot's run-up.
	for n in VARIANTS:
		assert_almost_eq(_length("power_spring", n + 1), 0.16, 0.005, "power_spring_%d" % (n + 1))


func test_the_whistles_blasts_last_as_long_as_the_blasts_are_timed() -> void:
	var cfg := PlayTuning.load_default().sound
	for n in cfg.whistle_variants:
		assert_almost_eq(_length("whistle_short", n + 1), cfg.whistle_short, 0.005)
		assert_almost_eq(_length("whistle_long", n + 1), cfg.whistle_long, 0.005)


func test_every_surface_names_a_bbs_cue_and_a_steps_cue() -> void:
	assert_eq(SimAudio.IMPACT_NAMES.size(), RayHit.Surface.size())
	assert_eq(SimAudio.SURFACE_NAMES.size(), RayHit.Surface.size())
	for s: String in SimAudio.IMPACT_NAMES:
		assert_true(ResourceLoader.exists("%simpact_%s_1.wav" % [SoundConfig.CUE_DIR, s]), "impact_%s" % s)
	assert_eq(SimAudio.IMPACT_NAMES[RayHit.Surface.GLASS], "glass")
	assert_eq(SimAudio.IMPACT_NAMES[RayHit.Surface.PLASTIC], "plastic")
	assert_eq(SimAudio.IMPACT_NAMES[RayHit.Surface.CARDBOARD], "cardboard")
	# Steps as before: glass was metal, plastic and cardboard wood.
	assert_eq(SimAudio.SURFACE_NAMES[RayHit.Surface.GLASS], SimAudio.SURFACE_NAMES[RayHit.Surface.METAL])
	assert_eq(SimAudio.SURFACE_NAMES[RayHit.Surface.PLASTIC], SimAudio.SURFACE_NAMES[RayHit.Surface.WOOD])
	assert_eq(SimAudio.SURFACE_NAMES[RayHit.Surface.CARDBOARD], SimAudio.SURFACE_NAMES[RayHit.Surface.WOOD])


func test_the_kinds_on_the_new_surfaces() -> void:
	var style := MapStyle.new()
	assert_eq(style.surface_of(&"glass"), RayHit.Surface.GLASS)
	assert_eq(style.surface_of(&"bins"), RayHit.Surface.PLASTIC)
	assert_eq(style.surface_of(&"toilet"), RayHit.Surface.PLASTIC)
	assert_eq(style.surface_of(&"wrapped"), RayHit.Surface.CARDBOARD)
	assert_eq(style.surface_of(&"drum"), RayHit.Surface.METAL, "RK1: Depot's drums are steel")
	assert_eq(style.surface_of(&"barrel"), RayHit.Surface.PLASTIC, "and its barrels plastic")
	assert_eq(MapData.SURFACES["glass"], RayHit.Surface.GLASS, "a map file may name them")
	assert_eq(MapData.SURFACES["plastic"], RayHit.Surface.PLASTIC)
	assert_eq(MapData.SURFACES["cardboard"], RayHit.Surface.CARDBOARD)


func test_the_new_surfaces_bounce_puff_and_carry_as_before() -> void:
	var ricochet := RicochetConfig.new()
	assert_eq(ricochet.restitution(RayHit.Surface.GLASS), ricochet.restitution(RayHit.Surface.METAL))
	assert_eq(ricochet.restitution(RayHit.Surface.PLASTIC), ricochet.restitution(RayHit.Surface.WOOD))
	assert_eq(ricochet.restitution(RayHit.Surface.CARDBOARD), ricochet.restitution(RayHit.Surface.WOOD))
	var effects := PlayTuning.load_default().effects
	var puffs := effects.puff_colours
	assert_eq(puffs.size(), RayHit.Surface.size())
	assert_eq(puffs[RayHit.Surface.GLASS], puffs[RayHit.Surface.METAL])
	assert_eq(puffs[RayHit.Surface.PLASTIC], puffs[RayHit.Surface.WOOD])
	assert_eq(puffs[RayHit.Surface.CARDBOARD], puffs[RayHit.Surface.WOOD])
	var noise := NoiseConfig.new()
	assert_eq(noise.ground.get(RayHit.Surface.GLASS, 1.0), noise.ground.get(RayHit.Surface.METAL, 1.0))
	var minimap := MinimapConfig.new()
	assert_eq(MinimapField._surface_tint(RayHit.Surface.PLASTIC, minimap), minimap.wood_tint)
	assert_eq(MinimapField._surface_tint(RayHit.Surface.CARDBOARD, minimap), minimap.wood_tint)
	assert_eq(MinimapField._surface_tint(RayHit.Surface.GLASS, minimap), Color(0.0, 0.0, 0.0, 0.0), "as metal")


func _gas_enemy(left: int) -> void:
	var gbb := ReplicaConfig.new()
	gbb.power = &"gas"
	enemy = Character.new(1, 1, Vector3(0.0, 0.0, -6.0), 0.0, [gbb] as Array[ReplicaConfig])
	enemy.armament.ammo[0].mag = left
	state.characters.append(enemy)
	audio = SimAudio.new()
	add_child_autofree(audio)
	var cfg := SoundConfig.new()
	audio.setup(cfg, [&"gas"] as Array[StringName], body, BoxWorld.new(body), null)
	var shot := state.events.add(GameEvent.Kind.SHOT)
	shot.actor = enemy.id
	shot.slot = 0
	shot.position = enemy.eye(body)
	audio.on_tick(state, you.id, you)


func _playing(cue: StringName) -> int:
	var n := 0
	for v in audio._field:
		if v.playing and (audio._streams.get(cue, []) as Array).has(v.stream):
			n += 1
	return n


func test_a_gas_pistols_last_shot_locks_its_slide_back() -> void:
	_gas_enemy(0)
	assert_eq(_playing(&"shot_gas"), 1)
	assert_eq(_playing(&"slideLock_gas"), 1, "the slide locks back on the empty magazine")


func test_a_shot_with_bbs_left_does_not_lock_the_slide() -> void:
	_gas_enemy(3)
	assert_eq(_playing(&"shot_gas"), 1)
	assert_eq(_playing(&"slideLock_gas"), 0)


func test_an_electric_replica_has_no_slide_to_lock() -> void:
	audio = SimAudio.new()
	add_child_autofree(audio)
	audio.setup(SoundConfig.new(), [&"electric", &"gas"] as Array[StringName], body, BoxWorld.new(body), null)
	assert_eq(audio._slide_lock[&"electric"], &"")
	assert_eq(audio._slide_lock[&"gas"], &"slideLock_gas")


func test_every_replica_fired_empty_clicks_the_pistols_dry_fire() -> void:
	# Owner, 2026-11-05: every replica, today's and later ones, clicks the gas pistol's recorded dry fire, unchanged.
	for profile: StringName in [&"gas", &"electric", &"spring", &"cyber", &"anyLaterOne"]:
		var replica := ReplicaConfig.new()
		replica.sound = profile
		enemy = Character.new(1, 1, Vector3(0.0, 0.0, -6.0), 0.0, [replica] as Array[ReplicaConfig])
		state = GameState.new(1)
		state.characters.append(you)
		state.characters.append(enemy)
		audio = SimAudio.new()
		add_child_autofree(audio)
		audio.setup(SoundConfig.new(), [&"gas", &"electric", &"spring", &"cyber"] as Array[StringName], body,
				BoxWorld.new(body), null)
		var dry := state.events.add(GameEvent.Kind.DRY_FIRE)
		dry.actor = enemy.id
		dry.slot = 0
		dry.position = enemy.eye(body)
		audio.on_tick(state, you.id, you)
		assert_eq(_playing(SimAudio.DRY_CUE), 1, profile)
	for old: String in ["dryFire_gas", "dryFire_electric", "dryFire_spring", "dryFire_cyber"]:
		assert_eq(_variants(old), 0, "%s went: one click for them all" % old)


## The first 0.1 s of a cue file's samples (16-bit mono PCM, as tools/cut_recordings.py writes them), read from the
## source WAV: the imported stream is compressed.
func _onset_power(cue: String, n: int) -> float:
	var bytes := FileAccess.get_file_as_bytes("%s%s_%d.wav" % [SoundConfig.CUE_DIR, cue, n])
	var at := 12
	while at + 8 <= bytes.size() and bytes.slice(at, at + 4).get_string_from_ascii() != "data":
		at += 8 + bytes.decode_u32(at + 4)
	var window := int(0.1 * 44100.0)
	var total := 0.0
	for i in mini(window, (bytes.size() - at - 8) / 2):
		var v := bytes.decode_s16(at + 8 + 2 * i) / 32768.0
		total += v * v
	return total / window


func test_every_ground_steps_as_loud_as_concrete() -> void:
	# Footsteps are information (owner, 2026-10-05): within 1.5 dB of concrete at every pace, so a soft ground hides
	# nobody. AU5's recordings differ more than that; tools/cut_recordings.py balances them (and the 0.7 to 4 kHz band).
	for pace: String in ["run", "sprint", "land"]:
		var concrete := 0.0
		for n in VARIANTS:
			concrete += _onset_power("step_concrete_" + pace, n + 1)
		for ground: String in ["wood", "metal", "gravel", "grass", "leaves", "earth"]:
			var power := 0.0
			for n in VARIANTS:
				power += _onset_power("step_%s_%s" % [ground, pace], n + 1)
			var off := 10.0 * log(power / concrete) / log(10.0)
			assert_lt(absf(off), 1.5, "%s %s: %.2f dB" % [ground, pace, off])


func test_a_steel_props_ring_is_over_before_it_can_be_set_off_again() -> void:
	# A prop makes a noise at most once in NoiseConfig.quiet (s), so no variant of the ring (AU9's metal bang, 0.9 s)
	# plays over the next one.
	var quiet := NoiseConfig.new().quiet
	for n in 3:
		assert_lt(_length("prop_steel", n + 1), quiet, "prop_steel_%d" % (n + 1))


func _edges(cue: String, n: int) -> Vector2:
	# The first and last samples of a cue's variant, each over its peak.
	var bytes := FileAccess.get_file_as_bytes("%s%s_%d.wav" % [SoundConfig.CUE_DIR, cue, n])
	var at := 12
	while at + 8 <= bytes.size() and bytes.slice(at, at + 4).get_string_from_ascii() != "data":
		at += 8 + bytes.decode_u32(at + 4)
	var count := mini(bytes.decode_u32(at + 4), bytes.size() - at - 8) / 2
	var peak := 1.0
	for i in count:
		peak = maxf(peak, absf(bytes.decode_s16(at + 8 + 2 * i)))
	return Vector2(absf(bytes.decode_s16(at + 8)), absf(bytes.decode_s16(at + 8 + 2 * (count - 1)))) / peak


func test_every_step_and_prop_knock_starts_and_ends_at_silence() -> void:
	# AU9: balancing the steps' band once left their cut edges off zero, a tick at every footstep. Every step and prop
	# variant starts and ends within 1 % of its peak.
	for ground: String in ["concrete", "wood", "metal", "gravel", "grass", "leaves", "earth"]:
		for pace: String in ["run", "sprint", "land"]:
			for n in VARIANTS:
				var e := _edges("step_%s_%s" % [ground, pace], n + 1)
				assert_true(e.x <= 0.01 and e.y <= 0.01, "step_%s_%s_%d edges %s" % [ground, pace, n + 1, e])
	for s in NoiseConfig.SOUND_NAMES:
		for n in 3:
			var e := _edges("prop_%s" % s, n + 1)
			assert_true(e.x <= 0.01 and e.y <= 0.01, "prop_%s_%d edges %s" % [s, n + 1, e])
