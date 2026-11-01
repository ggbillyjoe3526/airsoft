extends GutTest
## Muffling through walls (game/play/sound_occlusion.gd and its use in sim_audio.gd; SP2) on a BoxWorld: others' sounds
## open, half behind low cover and full behind a wall, at the browser's level for the share; a silenced shot behind
## both; a BB impact's ray stopping short of its surface; the ray budget held; a share reused for its refresh; the far
## ramp; the listener changing to the teammate you watch once out; your own sounds never muffled; and no allocation.

const ENEMY_AT := Vector3(0.0, 0.0, 10.0)

var cfg: SoundConfig = null
var body: BodyConfig = BodyConfig.new()
var world: BoxWorld = null
var audio: SimAudio = null
var state: GameState = null
var you: Character = null
var enemy: Character = null


## Levels unspread, so a voice's level reads exactly; you at the origin, an enemy 10 m down +Z.
func before_each() -> void:
	cfg = SoundConfig.new()
	for spread: String in ["shot_spread_db", "mechanism_spread_db", "step_spread_db", "vault_spread_db",
			"impact_spread_db", "hit_spread_db"]:
		cfg.set(spread, 0.0)
	world = BoxWorld.new(body)
	state = GameState.new(1)
	you = _armed(0, 0, Vector3.ZERO)
	enemy = _armed(1, 1, ENEMY_AT)
	state.characters.append(you)
	state.characters.append(enemy)


func _armed(id: int, team: int, at: Vector3) -> Character:
	return Character.new(id, team, at, 0.0, [ReplicaConfig.new()] as Array[ReplicaConfig])


func _sound() -> void:
	audio = SimAudio.new()
	add_child_autofree(audio)
	audio.setup(cfg, [&"electric"] as Array[StringName], body, world, null)


## Knee high between you and the enemy: the knee ray is blocked, the head ray clears it.
func _barrier() -> void:
	world.add_box(Vector3(0.0, 0.6, 5.0), Vector3(6.0, 1.2, 0.4))


func _wall(z: float = 5.0) -> void:
	world.add_box(Vector3(0.0, 1.5, z), Vector3(6.0, 3.0, 0.4))


## The enemy's shot, a mechanism, a step, a vault and a hit on them, on one tick heard through `listener`.
func _enemy_sounds(listener: Character) -> void:
	for v in audio._field:
		v.stop()
	state.events.clear()
	var shot := state.events.add(GameEvent.Kind.SHOT)
	shot.actor = enemy.id
	shot.slot = 0
	shot.position = enemy.eye(body)
	_event(GameEvent.Kind.DRAW, enemy.id, -1)
	var step := _event(GameEvent.Kind.FOOTSTEP, enemy.id, -1)
	step.value = GameEvent.Footstep.RUN
	_event(GameEvent.Kind.VAULT, enemy.id, -1)
	_event(GameEvent.Kind.CHARACTER_HIT, 7, enemy.id)
	audio.on_tick(state, you.id, listener)


func _quiet_ticks(n: int) -> void:
	state.events.clear()
	for i in n:
		audio.on_tick(state, you.id, you)


func _event(kind: GameEvent.Kind, actor: int, target: int) -> GameEvent:
	var e := state.events.add(kind)
	e.actor = actor
	e.target = target
	e.position = enemy.position + Vector3(0.0, 1.0, 0.0)
	return e


## The buses of the field's voices playing, by cue.
func _buses() -> Dictionary[String, StringName]:
	var out: Dictionary[String, StringName] = {}
	for v in audio._field:
		if not v.playing:
			continue
		for cue: StringName in audio._streams:
			if (audio._streams[cue] as Array).has(v.stream):
				out[String(cue)] = StringName(v.bus)
	return out


func _volume_of(cue: StringName) -> float:
	for v in audio._field:
		if v.playing and (audio._streams[cue] as Array).has(v.stream):
			return v.volume_db
	return NAN


## Steps and vaults go on `feet` (Footsteps in the open), the power part on `power`, the rest on `effects`.
func _expect_all_on(effects: StringName, power: StringName, feet: StringName = &"") -> void:
	var buses := _buses()
	assert_eq(buses.size(), 6, "shot, power part, draw, step, vault, the hit's tick: %s" % buses)
	for cue: String in buses:
		var want := effects
		if cue.begins_with("power_"):
			want = power
		elif cue.begins_with("step_") or cue == "vault":
			want = feet if feet != &"" else effects
		assert_eq(buses[cue], want, cue)
	assert_almost_eq(_volume_of(&"shot_electric"), linear_to_db(cfg.shot_gain), 1e-3, "the bus gives the level")


func test_in_the_open_others_sounds_play_plain() -> void:
	_sound()
	_enemy_sounds(you)
	_expect_all_on(SimAudio.BUS_EFFECTS, SimAudio.BUS_POWER, SimAudio.BUS_FOOTSTEPS)


func test_behind_low_cover_others_sounds_play_half_muffled() -> void:
	_barrier()
	_sound()
	_enemy_sounds(you)
	_expect_all_on(SoundMix.BUS_EFFECTS_HALF, SoundMix.BUS_POWER_HALF)


func test_behind_a_wall_others_sounds_play_fully_muffled() -> void:
	_wall()
	_sound()
	_enemy_sounds(you)
	_expect_all_on(SoundMix.BUS_EFFECTS_FULL, SoundMix.BUS_POWER_FULL)


## Each share is heard at the browser's level (1 open .. occlusion_muffled_gain), the bus's and the voice's together;
## a share between the buses takes the nearer bus's corner.
func test_each_share_is_heard_at_the_browsers_level() -> void:
	SoundMix.set_occlusion_buses(cfg)
	for share: float in [0.0, 0.2, 0.5, 0.75, 1.0]:
		var bus := SoundOcclusion.bus_for(SimAudio.BUS_EFFECTS, share, cfg)
		# The plain bus's volume is the player's (Settings), so only an occlusion bus's own level counts.
		var bus_gain := 1.0 if bus == SimAudio.BUS_EFFECTS \
				else db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus)))
		var heard := bus_gain * SoundOcclusion.level_for(SimAudio.BUS_EFFECTS, share, cfg)
		assert_almost_eq(heard, 1.0 - share * (1.0 - cfg.occlusion_muffled_gain), 1e-4, "share %s" % share)
	assert_eq(SoundOcclusion.bus_for(SimAudio.BUS_EFFECTS, 0.2, cfg), SimAudio.BUS_EFFECTS)
	assert_eq(SoundOcclusion.bus_for(SimAudio.BUS_EFFECTS, 0.75, cfg), SoundMix.BUS_EFFECTS_FULL)
	assert_eq(SoundOcclusion.bus_for(SimAudio.BUS_INTERFACE, 1.0, cfg), SimAudio.BUS_INTERFACE, "never the interface")


## Behind low cover its own low-pass (1400 Hz) is lower than the half bus's: kept, at both levels; behind a wall the
## full bus's (700 Hz) is lower.
func test_a_silenced_shot_takes_the_more_muffled_corner_and_both_levels() -> void:
	enemy.armament.replicas[0].muffled = true
	_barrier()
	_sound()
	_enemy_sounds(you)
	assert_eq(_buses()["shot_electric"], SimAudio.BUS_MUFFLED)
	assert_almost_eq(_volume_of(&"shot_electric"), linear_to_db(cfg.shot_gain * cfg.muffled_gain
			* SoundMix.share_gain(cfg, 0.5)), 1e-3)
	assert_eq(_buses()["power_electric"], SoundMix.BUS_POWER_HALF, "its power part as any")
	_wall(7.0)
	_quiet_ticks(cfg.occlusion_refresh_ticks)
	_enemy_sounds(you)
	assert_eq(_buses()["shot_electric"], SoundMix.BUS_EFFECTS_FULL)
	assert_almost_eq(_volume_of(&"shot_electric"), linear_to_db(cfg.shot_gain * cfg.muffled_gain), 1e-3,
			"the full bus gives the wall's level")


## A wall from z 9.8 to 10.2: a BB stopping on its near face is heard open, one on its far face fully muffled.
func test_an_impact_casts_one_ray_stopping_short_of_its_surface() -> void:
	_wall(10.0)
	_sound()
	for z: float in [9.8, 10.2]:
		for v in audio._field:
			v.stop()
		state.events.clear()
		var e := state.events.add(GameEvent.Kind.BB_IMPACT)
		e.target = -1
		e.position = Vector3(0.0, 1.0, z)
		audio.on_tick(state, you.id, you)
		assert_eq(audio._occlusion.rays, 1)
		assert_eq(_buses()["impact_concrete"], SimAudio.BUS_EFFECTS if z < 10.0 else SoundMix.BUS_EFFECTS_FULL)


## Twenty enemies behind a wall: the first twelve cast (24 rays), the rest keep their last share (none yet: open), and
## an impact over the budget plays open; the next tick casts the rest, the first twelve reused.
func test_a_tick_casts_no_more_than_the_budget() -> void:
	_wall()
	var occ := SoundOcclusion.new(cfg, world)
	var crowd: Array[Character] = []
	for i in 20:
		crowd.append(Character.new(2 + i, 1, Vector3(float(i) * 0.2 - 2.0, 0.0, 10.0)))
	occ.begin_tick(crowd, you, you.eye(body))
	var muffled := 0
	for c in crowd:
		muffled += int(occ.share_of(c) == 1.0)
	assert_eq(occ.rays, cfg.occlusion_ray_budget)
	assert_eq(muffled, cfg.occlusion_ray_budget / 2)
	assert_eq(occ.share_of(crowd[19]), 0.0, "over the budget: its last share")
	assert_eq(occ.impact_share(Vector3(0.0, 1.0, 10.0)), 0.0, "an impact over the budget plays open")
	assert_eq(occ.rays, cfg.occlusion_ray_budget)
	occ.begin_tick(crowd, you, you.eye(body))
	muffled = 0
	for c in crowd:
		muffled += int(occ.share_of(c) == 1.0)
	assert_eq(muffled, crowd.size())
	assert_eq(occ.rays, 2 * (crowd.size() - cfg.occlusion_ray_budget / 2))
	assert_eq(occ.rays_max, cfg.occlusion_ray_budget)


## The share found is reused for refresh_ticks however often the character sounds: a wall going up between is heard
## on the first refresh.
func test_a_characters_share_is_reused_for_its_refresh() -> void:
	var occ := SoundOcclusion.new(cfg, world)
	occ.begin_tick(state.characters, you, you.eye(body))
	assert_eq(occ.share_of(enemy), 0.0)
	assert_eq(occ.share_of(enemy), 0.0)
	assert_eq(occ.rays, 2, "two sounds, one cast")
	_wall()
	for t in range(1, cfg.occlusion_refresh_ticks):
		occ.begin_tick(state.characters, you, you.eye(body))
		assert_eq(occ.share_of(enemy), 0.0, "tick %d reuses it" % t)
		assert_eq(occ.rays, 0)
	occ.begin_tick(state.characters, you, you.eye(body))
	assert_eq(occ.share_of(enemy), 1.0, "refreshed")
	assert_eq(occ.rays, 2)


## Beyond reach no ray: the last share (low cover's 0.5) closes to full over far_ramp in far_step steps.
func test_beyond_reach_no_ray_and_the_share_closes_to_full() -> void:
	_barrier()
	var occ := SoundOcclusion.new(cfg, world)
	occ.begin_tick(state.characters, you, you.eye(body))
	assert_eq(occ.share_of(enemy), 0.5)
	var ear := you.eye(body)
	var expect: Dictionary[float, float] = {2.0: 0.5, 32.0: 0.75, cfg.occlusion_far_ramp + 5.0: 1.0}
	for beyond: float in expect:
		enemy.position = Vector3(0.0, 0.0, sqrt(pow(cfg.occlusion_reach + beyond, 2.0) - ear.y * ear.y))
		for t in cfg.occlusion_refresh_ticks:
			occ.begin_tick(state.characters, you, ear)
		assert_almost_eq(occ.share_of(enemy), expect[beyond], 1e-4, "%s m beyond" % beyond)
		assert_eq(occ.rays, 0, "no ray beyond reach")


## Once you are out the view, and the ears, are a teammate's: what blocks the enemy from you no longer counts, from the
## first tick heard through them, and your own sounds stay plain.
func test_the_listener_changes_to_the_teammate_you_watch_once_out() -> void:
	_wall()
	var mate := _armed(2, 0, Vector3(3.0, 0.0, 12.0))
	state.characters.append(mate)
	_sound()
	_enemy_sounds(you)
	assert_eq(_buses()["vault"], SoundMix.BUS_EFFECTS_FULL)
	you.status = Character.Status.OUT
	_enemy_sounds(mate)
	assert_eq(_buses()["vault"], SimAudio.BUS_FOOTSTEPS, "from the teammate's eyes, the next tick")
	assert_eq(_buses()["shot_electric"], SimAudio.BUS_EFFECTS)
	state.events.clear()
	var own := state.events.add(GameEvent.Kind.VAULT)
	own.actor = you.id
	own.position = you.position
	audio.on_tick(state, you.id, enemy)
	assert_true(audio._own[0].playing, "your own vault, plain")
	assert_eq(audio._own[0].bus, SimAudio.BUS_FOOTSTEPS)


## Your own sounds and the interface's are never muffled, nor is the character whose ears you hear through.
func test_your_own_sounds_and_the_listeners_are_never_muffled() -> void:
	_wall()
	var occ := SoundOcclusion.new(cfg, world)
	occ.begin_tick(state.characters, you, you.eye(body))
	assert_eq(occ.share_of(you), 0.0)
	assert_eq(occ.rays, 0)
	_sound()
	state.events.clear()
	var shot := state.events.add(GameEvent.Kind.SHOT)
	shot.actor = you.id
	shot.slot = 0
	var hit := state.events.add(GameEvent.Kind.CHARACTER_HIT)
	hit.actor = enemy.id
	hit.target = you.id
	audio.on_tick(state, you.id, enemy)
	for v in audio._field:
		assert_false(v.playing, "nothing of yours from the field")
	var buses: Array[StringName] = []
	for v in audio._own:
		if v.playing:
			buses.append(StringName(v.bus))
	assert_eq(buses, [SimAudio.BUS_EFFECTS, SimAudio.BUS_POWER, SimAudio.BUS_INTERFACE] as Array[StringName])


## Casting and reusing shares, impacts and listener changes over many ticks makes nothing once the records exist.
func test_a_tick_allocates_nothing() -> void:
	_barrier()
	var occ := SoundOcclusion.new(cfg, world)
	occ.begin_tick(state.characters, you, you.eye(body))
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 300:
		enemy.position.x = float(i % 7)
		occ.begin_tick(state.characters, you if i % 50 < 40 else enemy, you.eye(body))
		occ.share_of(enemy)
		occ.share_of(you)
		occ.impact_share(Vector3(0.0, 1.0, float(i % 9)))
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)
	assert_gt(occ.rays_total, 300)


## BP2 (KNOWN_ISSUES, SP2): a BB striking the far side of a wall thinner than the old 0.2 m gap is heard through it,
## and one on the near side open; the ray ends just back along the BB's way in.
func test_an_impact_on_the_far_side_of_a_thin_wall_is_muffled_and_the_near_side_open() -> void:
	world.add_box(Vector3(0.0, 1.5, 10.0), Vector3(6.0, 3.0, 0.1))
	_sound()
	for near: bool in [true, false]:
		for v in audio._field:
			v.stop()
		state.events.clear()
		var e := state.events.add(GameEvent.Kind.BB_IMPACT)
		e.target = -1
		e.position = Vector3(0.0, 1.0, 9.95 if near else 10.05)
		e.direction = Vector3(0.0, 0.0, 60.0 if near else -60.0)
		audio.on_tick(state, you.id, you)
		assert_eq(_buses()["impact_concrete"], SimAudio.BUS_EFFECTS if near else SoundMix.BUS_EFFECTS_FULL,
				"near side open, far side through the wall" if near else "far side through a 0.1 m wall")
