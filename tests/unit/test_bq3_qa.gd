extends GutTest
## BQ3 QA · what the team radio, pressing, the careful last bot and the knee to fire must never do over whole bot
## matches, and the radio's and the knee's edges: a stale burst never keeps a bot crouched and still, news is never
## overwritten by older news, and nothing is left over into the next round.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var style: MapStyle = MapStyle.new()
var map: MapData = null
var level: MapLevel = null
var nav: NavGrid = null

var state: GameState = null
var sim: Simulation = null
var bots: BotController = null
var commands: Array[PlayerCommand] = []


func before_all() -> void:
	map = YardMap.load_map(style, tuning.rounds.team_size)
	level = MapLevel.new()
	add_child(level)
	level.build(map, style, tuning.body)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


func after_all() -> void:
	level.free()


## A match on Depot, every character a bot, both teams at `level` (the controller's own default is Easy).
func _start(seed_value: int, level_id: StringName = &"normal") -> void:
	var levels: Dictionary[int, StringName] = {0: level_id, 1: level_id}
	sim = Simulation.new(tuning, level.query(), level.mover(tuning.body), map.ends, map.kill_y)
	sim.nav = nav
	state = GameState.new(seed_value, tuning)
	var loadout := ReplicaStats.default_loadout()
	commands.clear()
	for i in tuning.rounds.team_size * 2:
		state.characters.append(Character.new(i, 0 if i < tuning.rounds.team_size else 1, Vector3.ZERO, 0.0, loadout))
		commands.append(PlayerCommand.new())
	bots = BotController.new(state, -1, map, nav, level.query(), tuning, config, levels)
	sim.start_match(state)
	bots.observe(state)


func _tick() -> void:
	bots.think(state, commands, DT)
	sim.step(state, commands, DT)
	bots.observe(state)


func test_a_kneeling_bot_is_never_crouched_and_still_for_long_without_firing() -> void:
	var worst := 0
	var kneel_ticks := 0
	var blind_kneel := 0
	var fight_ticks := 0
	var reasons: Dictionary = {}
	for seed_value: int in [1]:
		_start(seed_value, &"normal")
		var streak: Dictionary[int, int] = {}
		for t in roundi(tuning.rounds.round_time / DT) * 6:
			bots.think(state, commands, DT)
			for b in bots.world.bots:
				var cmd := commands[b.character.id]
				var id := b.character.id
				if b.mode == Bot.Mode.FIGHT and Elimination.is_in_play(b.character):
					fight_ticks += 1
				if b.mode == Bot.Mode.FIGHT and cmd.crouch and b.burst_left > 0.0 and not cmd.fire \
						and Elimination.is_in_play(b.character):
					kneel_ticks += 1
					var why := "visible-unreacted" if b.target_visible and not BotSenses.has_reacted(b, bots.world) \
							else ("blocked" if b.no_shot_for > 0.0 else ("blind" if not b.target_visible else "offcone"))
					reasons[why] = reasons.get(why, 0) + 1
					if not b.target_visible:
						blind_kneel += 1
					streak[id] = streak.get(id, 0) + 1
					worst = maxi(worst, streak[id])
				else:
					streak[id] = 0
			sim.step(state, commands, DT)
			bots.observe(state)
	gut.p(str(reasons))
	gut.p("fight ticks %d, kneeling-without-firing ticks %d (blind %d), longest streak %d ticks" % [fight_ticks,
			kneel_ticks, blind_kneel, worst])
	assert_lt(worst, 60, "never a second crouched and still on a burst it is not firing")


func test_a_new_round_clears_a_pending_call() -> void:
	_start(1)
	var b := bots.world.bots[0]
	b.share_id = 3
	b.share_at = 99.0
	b.reset(0, 3, 0.0, config)
	assert_eq(b.share_id, -1)
	assert_eq(b.share_at, INF)


func test_radio_news_older_than_own_fresher_news_is_not_taken() -> void:
	_start(1)
	var w := bots.world
	w.live = true
	w.time = 20.0
	var caller := w.bots[0]
	var mate: Bot = null
	for b in w.bots:
		if b != caller and b.character.team == caller.character.team:
			mate = b
			break
	mate.has_last_known = true
	mate.last_known = Vector3(7.0, 0.0, 7.0)
	mate.heard_at = 19.5
	caller.skill = config.skill_for(&"normal")
	for b in w.bots:
		b.character.position = Vector3(1.0, 0.0, 1.0)
	BotRadio.tell(caller, w, Vector3(-5.0, 0.0, -5.0))
	assert_eq(mate.last_known, Vector3(7.0, 0.0, 7.0), "its own half-second-old news stands")


func test_radio_ignores_an_out_teammate_and_does_not_tell_the_other_team() -> void:
	_start(1)
	var w := bots.world
	w.live = true
	var caller := w.bots[0]
	var spot := caller.character.position
	for b in w.bots:
		b.character.position = spot
		b.has_last_known = false
	var out_mate: Bot = null
	for b in w.bots:
		if b != caller and b.character.team == caller.character.team:
			out_mate = b
			break
	out_mate.character.status = Character.Status.OUT
	caller.skill = config.skill_for(&"hard")
	BotRadio.tell(caller, w, spot)
	assert_false(out_mate.has_last_known)
	for b in w.bots:
		if b.character.team != caller.character.team:
			assert_false(b.has_last_known)


func test_radio_is_dropped_when_the_round_is_not_live() -> void:
	_start(1)
	var w := bots.world
	var caller := w.bots[0]
	caller.share_id = 5
	caller.share_at = 0.0
	w.live = false
	BotRadio.step(w)
	assert_eq(caller.share_id, -1)


func test_pressing_and_careful_last_wait_for_a_live_round() -> void:
	_start(1)
	var w := bots.world
	for c in state.characters:
		if c.team == 1 and c.id != 5:
			c.status = Character.Status.OUT
	w.live = false
	for b in w.bots:
		assert_false(w.pressing(b))
		assert_false(w.careful_last(b))
	w.live = true
	var any_press := false
	for b in w.bots:
		any_press = any_press or w.pressing(b)
	assert_true(any_press)


## Bot 0 at Normal fighting bot 3 on an open 80 m floor, a burst left over from a shot it can no longer take.
func _stale_burst(visible: bool) -> PlayerCommand:
	var w := BotWorld.new()
	w.cfg = config
	w.tuning = tuning
	var box := BoxWorld.new(tuning.body)
	box.add_floor(80.0, 80.0)
	w.query = box
	var m := MapData.new()
	var block := MapData.Block.new()
	block.kind = &"floor"
	block.center = Vector3(0.0, -0.25, 0.0)
	block.size = Vector3(80.0, 0.5, 80.0)
	m.blocks.append(block)
	w.nav = NavGrid.build(m, tuning.nav, tuning.body)
	var spots: Array[Vector3] = [Vector3.ZERO, Vector3(0.0, 0.0, 20.0)]
	for id in 2:
		var c := Character.new(id, id, spots[id], 0.0, ReplicaStats.default_loadout())
		c.position = spots[id]
		w.characters.append(c)
		w.bots.append(Bot.new(c, id + 1, config.skill_for(&"normal"), 2))
	var b := w.bots[0]
	b.mode = Bot.Mode.FIGHT
	b.target_id = 1
	b.target_visible = visible
	b.strafe_left = 1.0
	b.burst_left = 0.3
	var cmd := PlayerCommand.new()
	BotMovement._strafe(b, w, cmd, DT, w.characters[1])
	return cmd


func test_a_burst_it_can_not_fire_leaves_the_bot_sidestepping_not_kneeling() -> void:
	var cmd := _stale_burst(false)
	assert_false(cmd.crouch, "target out of sight: nothing to kneel for (the burst_left is a leftover)")
