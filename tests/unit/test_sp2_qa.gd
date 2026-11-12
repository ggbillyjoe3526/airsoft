extends GutTest
## SP2's QA pass (muffling through walls): what the worker's own tests leave open. Settings that would make a level not
## a number, the sounds that must stay open (the flag rope, the range's targets, a playing voice), the share cache
## keyed per character, a missing listener, the bots' hearing keeping its own heights, and an impact on the ground far
## away.

var cfg: SoundConfig = null
var body: BodyConfig = BodyConfig.new()
var world: BoxWorld = null
var audio: SimAudio = null
var state: GameState = null
var you: Character = null
var enemy: Character = null


func before_each() -> void:
	cfg = SoundConfig.new()
	for spread: String in ["shot_spread_db", "mechanism_spread_db", "step_spread_db", "vault_spread_db",
			"impact_spread_db", "hit_spread_db"]:
		cfg.set(spread, 0.0)
	world = BoxWorld.new(body)
	state = GameState.new(1)
	you = _armed(0, 0, Vector3.ZERO)
	enemy = _armed(1, 1, Vector3(0.0, 0.0, 10.0))
	state.characters.append(you)
	state.characters.append(enemy)


func _armed(id: int, team: int, at: Vector3) -> Character:
	return Character.new(id, team, at, 0.0, [ReplicaConfig.new()] as Array[ReplicaConfig])


func _sound() -> void:
	audio = SimAudio.new()
	add_child_autofree(audio)
	audio.setup(cfg, [&"electric"] as Array[StringName], body, world, null)


func _wall(z: float = 5.0, thick: float = 0.4) -> void:
	world.add_box(Vector3(0.0, 1.5, z), Vector3(6.0, 3.0, thick))


func _bus_of(cue_prefix: String) -> StringName:
	for v in audio._field:
		if v.playing:
			for cue: StringName in audio._streams:
				if String(cue).begins_with(cue_prefix) and (audio._streams[cue] as Array).has(v.stream):
					return StringName(v.bus)
	return &""


## A muffled gain of 0 (a data table asking for silence behind walls) gives the wall's level 0, not 0 / 0.
func test_a_zero_muffled_gain_still_gives_a_real_level() -> void:
	cfg.occlusion_muffled_gain = 0.0
	for bus: StringName in [SimAudio.BUS_EFFECTS, SimAudio.BUS_SHOTS, SimAudio.BUS_POWER, SimAudio.BUS_MUFFLED,
			SimAudio.BUS_FOOTSTEPS]:
		for share: float in [0.5, 1.0]:
			var level := SoundOcclusion.level_for(bus, share, cfg)
			assert_false(is_nan(level), "%s at %s" % [bus, share])
			assert_false(is_inf(level), "%s at %s" % [bus, share])


## The flag's rope and the range's targets are not a character's sounds: a wall between plays them open.
func test_the_flag_rope_and_range_targets_stay_open_behind_a_wall() -> void:
	_wall()
	_sound()
	state.events.clear()
	var rope := state.events.add(GameEvent.Kind.FLAG_ROPE)
	rope.position = Vector3(0.0, 2.0, 10.0)
	rope.value = 1
	var steel := state.events.add(GameEvent.Kind.TARGET_HIT)
	steel.actor = you.id
	steel.value = RangeTarget.Kind.STEEL
	steel.position = Vector3(0.0, 1.0, 12.0)
	audio.on_tick(state, -1, you)
	assert_eq(_bus_of("rope"), SimAudio.BUS_EFFECTS)
	assert_eq(_bus_of("steel"), SimAudio.BUS_EFFECTS)
	assert_eq(audio._occlusion.rays, 0, "neither costs a ray")


## A voice already playing keeps its bus when a wall goes up, whatever later ticks find.
func test_a_playing_voice_is_never_rerouted() -> void:
	_sound()
	state.events.clear()
	var step := state.events.add(GameEvent.Kind.FOOTSTEP)
	step.actor = enemy.id
	step.value = GameEvent.Footstep.RUN
	audio.on_tick(state, you.id, you)
	var voice: AudioStreamPlayer3D = null
	for v in audio._field:
		if v.playing:
			voice = v
	assert_not_null(voice)
	var bus := StringName(voice.bus)
	_wall()
	state.events.clear()
	for i in 3 * cfg.occlusion_refresh_ticks:
		audio.on_tick(state, you.id, you)
	assert_eq(StringName(voice.bus), bus)
	assert_eq(bus, SimAudio.BUS_FOOTSTEPS)


## Each character's share is its own: a wall in front of one enemy doesn't muffle another in the open.
func test_the_share_cache_is_per_character() -> void:
	world.add_box(Vector3(-2.0, 1.5, 5.0), Vector3(2.0, 3.0, 0.4))
	var other := _armed(2, 1, Vector3(4.0, 0.0, 10.0))
	enemy.position = Vector3(-4.0, 0.0, 10.0)
	state.characters.append(other)
	var occ := SoundOcclusion.new(cfg, world)
	occ.begin_tick(state.characters, you, you.eye(body))
	assert_eq(occ.share_of(enemy), 1.0)
	assert_eq(occ.share_of(other), 0.0)
	assert_eq(occ.share_of(enemy), 1.0)


## Nobody's ears (a spectator with no view, the match between rounds): everything plays open and nothing casts.
func test_without_a_listener_nothing_is_muffled_and_nothing_is_cast() -> void:
	_wall()
	_sound()
	state.events.clear()
	var step := state.events.add(GameEvent.Kind.FOOTSTEP)
	step.actor = enemy.id
	step.value = GameEvent.Footstep.RUN
	var shot := state.events.add(GameEvent.Kind.SHOT)
	shot.actor = enemy.id
	shot.position = enemy.eye(body)
	audio.on_tick(state, you.id, null)
	assert_eq(audio._occlusion.rays, 0)
	assert_eq(_bus_of("step_"), SimAudio.BUS_FOOTSTEPS, "played, open")


## A listener who comes back after a gap (view lost, then regained) casts afresh, not from the share it had.
func test_a_listener_returning_after_none_casts_afresh() -> void:
	var occ := SoundOcclusion.new(cfg, world)
	occ.begin_tick(state.characters, you, you.eye(body))
	assert_eq(occ.share_of(enemy), 0.0)
	_wall()
	occ.begin_tick(state.characters, null, you.eye(body))
	occ.begin_tick(state.characters, you, you.eye(body))
	assert_eq(occ.share_of(enemy), 1.0, "the wall is found at once, not after the refresh")


## A BB on the ground far away is open: the ray stops short of the floor, it doesn't clip it at a grazing angle.
func test_a_far_impact_on_the_ground_is_heard_open() -> void:
	world.add_floor(300.0, 300.0)
	var occ := SoundOcclusion.new(cfg, world)
	occ.begin_tick(state.characters, you, you.eye(body))
	for z: float in [5.0, 20.0, 40.0, 59.0]:
		assert_eq(occ.impact_share(Vector3(0.0, 0.0, z)), 0.0, "ground %s m off" % z)


## A line of no length (a sound at the ear) is never blocked, with or without a gap.
func test_a_line_of_no_length_is_open() -> void:
	world.add_box(Vector3(0.0, 1.0, 0.0), Vector3(6.0, 3.0, 0.4))
	var hit := RayHit.new()
	var at := Vector3(0.0, 1.62, 0.0)
	assert_false(SoundPath.line_blocked(world, at, at, 0.2, hit))
	assert_false(SoundPath.line_blocked(world, at, at, 0.0, hit))
	assert_false(is_nan(SoundPath.blocked_share(world, at, at - Vector3(0.0, 1.5, 0.0), [1.5], hit)))


## The bots hear by their own ray heights (BotConfig), not the player's: one head-high ray behind low cover is open.
func test_a_blocked_share_is_by_the_heights_it_is_given() -> void:
	world.add_box(Vector3(0.0, 0.6, 5.0), Vector3(6.0, 1.2, 0.4))
	var hit := RayHit.new()
	var ear := Vector3(0.0, 1.62, 0.0)
	var feet := Vector3(0.0, 0.0, 10.0)
	assert_eq(SoundPath.blocked_share(world, ear, feet, [1.5], hit), 0.0)
	assert_eq(SoundPath.blocked_share(world, ear, feet, [0.45], hit), 1.0)
	assert_eq(SoundPath.blocked_share(world, ear, feet, [0.45, 0.45, 1.5], hit), 2.0 / 3.0)
