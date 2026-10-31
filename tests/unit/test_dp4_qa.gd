extends GutTest
## QA for DP4 (noisy props and loud ground), beyond test_noisy_props.gd: someone who is out never knocks, a teammate's
## knock is no news to its own side's bots, minimap or sound cues, a quiet time from a clock that is not this one's
## never holds, a ring never reaches a bot on the shooter's team, and Woodland and the range list their props.

const DT := 1.0 / 60.0
const GAP := 0.04

var tuning: SimTuning = SimTuning.new()
var loadout: Array[ReplicaConfig] = []


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func _yard() -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(40.0, 40.0)
	w.add_prop(&"crate", Vector3(0.0, 0.4, -3.0), Vector3(1.2, 0.8, 1.2), RayHit.Surface.WOOD)
	w.add_prop(&"skip", Vector3(8.0, 0.75, -3.5), Vector3(3.0, 1.5, 2.0), RayHit.Surface.METAL)
	return w


func _ends() -> Array[MapEnd]:
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-15.0 if e == 0 else 15.0, 0.0, 15.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-18.0 if e == 0 else 18.0, 0.0, 18.0), 0.0))
		ends.append(end)
	return ends


## Asks a PropNoise of its own, with a fresh quiet time each tick, whether a character's last move was a knock.
class _Probe:
	var props: PropNoise = null
	var state: GameState = null
	var body: BodyConfig = null
	var knocks: int = 0

	func _init(tuning: SimTuning, w: BoxWorld) -> void:
		props = PropNoise.new(tuning.noise, w)
		state = GameState.new(1, tuning)
		props.prepare(state)
		body = tuning.body

	func after(c: Character) -> void:
		state.time += 10.0
		state.events.clear()
		props.knock(c, body, 1.0 / 60.0, state)
		knocks += state.events.count_of(GameEvent.Kind.PROP_KNOCK)


# --- Out of play ---


func test_a_character_walking_off_into_a_prop_makes_no_knock_but_the_same_move_in_play_does() -> void:
	var w := _yard()
	var sim := Simulation.new(tuning, w, w.mover(), _ends(), -10.0)
	var state := GameState.new(3, tuning)
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	state.characters.append(Character.new(1, 1, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	var c := state.characters[0]
	c.position = Vector3(0.0, GAP, 0.0)
	c.prev_position = c.position
	c.grounded = true
	Elimination.eliminate(c, 1, state.characters, _ends())
	c.dead_zone_target = Vector3(0.0, 0.0, -12.0) # straight through the crate
	c.walk_off_route_pending = true
	var cmds: Array[PlayerCommand] = [null, null]
	var knocks := 0
	var would := _Probe.new(tuning, _yard())
	for t in 300:
		sim.step(state, cmds, DT)
		knocks += state.events.count_of(GameEvent.Kind.PROP_KNOCK)
		would.after(c)
	assert_gt(would.knocks, 0, "control: that very move, were it made in play, is a knock")
	assert_eq(knocks, 0, "a character that is out knocks nothing")


# --- The quiet time's clock ---


func test_a_quiet_time_left_by_another_clock_does_not_hold_but_one_a_tick_old_does() -> void:
	var props := PropNoise.new(tuning.noise, _yard())
	var state := GameState.new(1, tuning)
	props.prepare(state)
	var c := Character.new(0, 0)
	c.position = Vector3(0.0, GAP, -2.4 + tuning.body.radius + 0.01)
	c.wanted_move = Vector3(0.0, 0.0, -4.2 * DT)
	c.made_move = Vector3.ZERO
	state.time = 5.0
	state.prop_quiet[0] = 5000.0 # an earlier match's long clock
	props.knock(c, tuning.body, DT, state)
	assert_eq(state.events.count_of(GameEvent.Kind.PROP_KNOCK), 1, "a quiet time that far ahead is not this match's")
	assert_almost_eq(state.prop_quiet[0], 5.0 + tuning.noise.quiet, 1e-9)
	state.events.clear()
	state.time = 5.0 + DT
	props.knock(c, tuning.body, DT, state)
	assert_eq(state.events.count_of(GameEvent.Kind.PROP_KNOCK), 0, "the knock a tick ago still holds")


func test_a_second_match_on_the_same_state_knocks_after_the_quiet_time_and_not_before() -> void:
	var w := _yard()
	var sim := Simulation.new(tuning, w, w.mover(), _ends(), -10.0)
	var state := GameState.new(3, tuning)
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	state.characters.append(Character.new(1, 1, Vector3.ZERO, 0.0, loadout))
	var cmd := PlayerCommand.new()
	var cmds: Array[PlayerCommand] = [cmd, null]
	var per_match: Array[int] = []
	for m in 2:
		sim.start_match(state)
		var c := state.characters[0]
		c.position = Vector3(0.0, GAP, 0.0)
		c.prev_position = c.position
		c.velocity = Vector3.ZERO
		c.grounded = true
		var knocks := 0
		for t in 200:
			cmd.reset(0.0, 0.0)
			cmd.forward = 1.0
			sim.step(state, cmds, DT)
			knocks += state.events.count_of(GameEvent.Kind.PROP_KNOCK)
		per_match.append(knocks)
		state.time += tuning.noise.quiet * 2.0
	assert_eq(per_match[0], per_match[1], "the same run into the same crate: the same knocks, match after match")


# --- Who hears ---


func _bot_field() -> Array:
	var map := MapData.new()
	map.id = "dp4 field"
	var floor_block := MapData.Block.new()
	floor_block.kind = &"floor"
	floor_block.center = Vector3(0.0, -0.25, 0.0)
	floor_block.size = Vector3(40.0, 0.5, 12.0)
	map.blocks.append(floor_block)
	map.ends = _ends()
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var w := BoxWorld.new(tuning.body)
	w.add_box(Vector3(0.0, -0.25, 0.0), Vector3(40.0, 0.5, 12.0))
	var state := GameState.new(9, tuning)
	# Team 0: bots 0 and 1 and the human-side teammate 3; team 1: the knocker 2.
	state.characters.append(Character.new(0, 0, Vector3(-15.0, GAP, 0.0), 0.0, loadout))
	state.characters.append(Character.new(1, 0, Vector3(-15.0, GAP, 3.0), 0.0, loadout))
	state.characters.append(Character.new(2, 1, Vector3(-5.0, GAP, 0.0), 0.0, loadout))
	state.characters.append(Character.new(3, 0, Vector3(-9.0, GAP, 0.0), 0.0, loadout))
	var levels: Dictionary[int, StringName] = {0: &"hard", 1: &"hard"}
	var bots := BotController.new(state, 3, map, nav, w, tuning, BotConfig.load_default(), levels)
	bots.world.time = 10.0
	state.time = 10.0
	return [state, bots]


func _prop_event(state: GameState, kind: GameEvent.Kind, actor: int, at: Vector3, reach: float) -> void:
	state.events.clear()
	var e := state.events.add(kind)
	e.actor = actor
	e.position = at
	e.reach = reach


func test_a_teammates_knock_or_ring_is_no_news_to_the_bots_on_its_side() -> void:
	var f: Array = _bot_field()
	var state: GameState = f[0]
	var bots: BotController = f[1]
	# Character 3 (team 0, the player) runs into a skip right beside bots 0 and 1; character 2 (team 1) is the enemy.
	_prop_event(state, GameEvent.Kind.PROP_KNOCK, 3, Vector3(-9.0, 1.0, 0.0), 20.0)
	BotHearing.observe(state, bots.world)
	for b in bots.world.bots:
		if b.character.team == 0:
			assert_false(b.has_last_known, "bot %d does not hear its own side's knock as an enemy" % b.character.id)
	_prop_event(state, GameEvent.Kind.PROP_RING, 3, Vector3(-14.0, 1.0, 0.0), 12.0)
	BotHearing.observe(state, bots.world)
	for b in bots.world.bots:
		if b.character.team == 0:
			assert_false(b.has_last_known, "nor its own side's ring")
	# The control: the enemy's knock from the same place is heard.
	_prop_event(state, GameEvent.Kind.PROP_KNOCK, 2, Vector3(-9.0, 1.0, 0.0), 20.0)
	BotHearing.observe(state, bots.world)
	assert_true(bots.world.bots[0].has_last_known, "the enemy's knock is")


func test_a_knock_by_someone_out_is_not_heard_by_bots() -> void:
	var f: Array = _bot_field()
	var state: GameState = f[0]
	var bots: BotController = f[1]
	Elimination.eliminate(state.characters[2], 3, state.characters, _ends())
	_prop_event(state, GameEvent.Kind.PROP_KNOCK, 2, Vector3(-9.0, 1.0, 0.0), 20.0)
	BotHearing.observe(state, bots.world)
	for b in bots.world.bots:
		assert_false(b.has_last_known)


func test_a_teammates_knock_gives_no_patch_and_no_cue_but_an_enemys_does() -> void:
	var s := GameState.new(5)
	s.match_number = 1
	var plain: Array[ReplicaConfig] = [ReplicaConfig.new()]
	s.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, plain))
	s.characters.append(Character.new(1, 0, Vector3(4.0, 0.0, 0.0), 0.0, plain))
	s.characters.append(Character.new(2, 1, Vector3(10.0, 0.0, 0.0), 0.0, plain))
	var map_hear := MinimapHearing.new(MinimapConfig.new())
	var cues := SoundCues.new(AccessibilityConfig.new(), SoundConfig.new())
	var you := s.characters[0]
	for who: int in [1, 2]:
		var e := s.events.add(GameEvent.Kind.PROP_KNOCK)
		e.actor = who
		e.position = s.characters[who].position + Vector3(0.4, 0.9, 0.0)
		e.reach = 20.0
		s.time += DT
		map_hear.on_tick(s, you)
		cues.on_tick(s, you)
		s.events.clear()
		if who == 1:
			assert_eq(map_hear.live_count(), 0, "a teammate's knock leaves no patch")
			assert_eq(cues.live_count(), 0, "and no cue")
	assert_eq(map_hear.live_count(), 1, "an enemy's knock 10 m off is a patch")
	assert_eq(cues.live_count(), 1, "and a cue")
	assert_not_null(map_hear.patch_of(2))
	assert_eq(map_hear.patch_of(2).sound, MinimapHearing.Sound.STEP, "heard as a step")


# --- The maps ---


func test_woodlands_fence_is_its_only_noisy_prop_and_the_ranges_five_are_listed() -> void:
	var counts: Dictionary[String, int] = {}
	for id: String in ["woodland", "range"]:
		var style := MapStyle.new()
		# The old wood's fence (OldWoodland): the count this test was written against.
		var map := OldWoodland.load_map(style, tuning.rounds.team_size) if id == "woodland" \
				else MapData.load_map(id, style, tuning.rounds.team_size)
		var level := MapLevel.new()
		add_child_autofree(level)
		level.build(map, style, tuning.body)
		counts[id] = PropNoise.new(tuning.noise, level.query()).count()
	assert_eq(counts["woodland"], 50, "the board fence is wood; its trees and logs are silent")
	assert_eq(counts["range"], 5, "the range: toilet, rack, IBC, generator, crate")
