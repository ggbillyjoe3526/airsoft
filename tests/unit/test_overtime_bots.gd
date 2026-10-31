extends GutTest
## The bots and Elimination's overtime flag (OV2; the browser game's overtimeBots.test.ts): each goes for it once its
## level's reaction is over, straight to its foot; an anchor or a careful bot first watches it from cover by it
## (bots.md › Watches the flag first), a flanker may go round the side; every bot goes in for the overtime's last
## seconds or as the last of its team, an ordered bot keeps its order, and each team's bot nearest the flag calls it.
## On Depot, headless (game/ai/bot_flag.gd, bot_movement.gd, bot_personality.gd, bot_aim.gd, bot_controller.gd,
## callouts.gd).

const DT := 1.0 / 60.0
## When the flag goes up in these tests (s of match time).
const UP_AT := 100.0

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var file: BotsFile = BotsFile.read_file()
var map: MapData = null
var level: MapLevel = null
var nav: NavGrid = null
var sim: Simulation = null
var state: GameState = null
var bots: BotController = null
var w: BotWorld = null
var commands: Array[PlayerCommand] = []
var spot: Vector3 = Vector3.ZERO


func before_all() -> void:
	map = MapData.load_map("depot", MapStyle.new(), tuning.rounds.team_size)
	level = MapLevel.new()
	add_child(level)
	level.build(map, MapStyle.new(), tuning.body)
	nav = NavGrid.build(map, tuning.nav, tuning.body)
	spot = map.overtime_flag


func after_all() -> void:
	level.free()


## A match on Depot, every character a bot at `level_id`, the second team's bots the personalities in `kinds` (in id
## order), with the map's overtime spot; played to its first round's plan.
func _start(kinds: Array[StringName], level_id: StringName = &"normal", seed_value: int = 3) -> void:
	sim = Simulation.new(tuning, level.query(), level.mover(tuning.body), map.ends, map.kill_y)
	sim.nav = nav
	state = GameState.new(seed_value, tuning)
	var loadout := ReplicaStats.default_loadout()
	commands.clear()
	var size := tuning.rounds.team_size
	var identities: Dictionary[int, BotRoster.Identity] = {}
	for i in size * 2:
		state.characters.append(Character.new(i, 0 if i < size else 1, Vector3.ZERO, 0.0, loadout))
		commands.append(PlayerCommand.new())
		var k := i - size
		if k >= 0 and k < kinds.size():
			var who := BotRoster.Identity.new()
			who.bot_name = "Bot%d" % i
			who.personality = kinds[k]
			who.style = file.style(kinds[k])
			identities[i] = who
	var levels: Dictionary[int, StringName] = {0: level_id, 1: level_id}
	bots = BotController.new(state, -1, map, nav, level.query(), tuning, config, levels, identities)
	w = bots.world
	state.round_state.has_overtime_spot = true
	state.round_state.overtime_spot = spot
	sim.start_match(state)
	bots.observe(state)


## The clock run out at UP_AT: the flag up at the spot and the bots told so (OVERTIME), as the round raises it.
func _overtime(kinds: Array[StringName], level_id: StringName = &"normal") -> Array[Bot]:
	_start(kinds, level_id)
	state.time = UP_AT
	var rs := state.round_state
	rs.clock = 0.0
	rs.overtime_flag.raise(spot)
	state.events.clear()
	state.events.add(GameEvent.Kind.OVERTIME).position = spot
	bots.observe(state)
	w.time = UP_AT
	w.live = true
	var list: Array[Bot] = []
	for b in w.bots:
		if b.character.team == 1:
			list.append(b)
	return list


func _tick() -> void:
	bots.think(state, commands, DT)
	sim.step(state, commands, DT)
	bots.observe(state)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_each_bot_goes_once_its_reaction_is_over_never_before_it_is_up_or_once_the_round_is_decided() -> void:
	var list := _overtime([&"rusher", &"flanker", &"rusher"])
	for b in list:
		var r := b.skill.overtime_reaction
		assert_between(b.overtime_at - UP_AT, r.x, r.y, "its level's reaction")
		w.time = b.overtime_at - 0.01
		assert_false(BotFlag.wants_flag(b, w), "not before its reaction is over")
		w.time = b.overtime_at
		assert_true(BotFlag.wants_flag(b, w))
	assert_eq(BotFlag.spot(list[0], w), spot, "flag mode heads for the overtime flag")
	w.live = false
	assert_false(BotFlag.wants_flag(list[0], w), "not once the round is decided")
	w.live = true
	state.round_state.overtime_flag.up = false
	assert_false(BotFlag.wants_flag(list[0], w), "not with the flag down")
	assert_eq(BotFlag.spot(list[0], w), w.flag.position, "the pole again")


func test_each_level_has_its_reaction_slowest_on_easy_and_quickest_on_hard() -> void:
	assert_eq(config.skill_for(&"easy").overtime_reaction, Vector2(0.5, 1.2))
	assert_eq(config.skill_for(&"normal").overtime_reaction, Vector2(0.3, 0.7))
	assert_eq(config.skill_for(&"hard").overtime_reaction, Vector2(0.2, 0.5))
	var mid := func(l: StringName) -> float:
		var r := config.skill_for(l).overtime_reaction
		return (r.x + r.y) * 0.5
	assert_gt(mid.call(&"easy"), mid.call(&"normal"))
	assert_gt(mid.call(&"normal"), mid.call(&"hard"))
	assert_eq(config.overtime_go_by, 10.0)


func test_a_personality_keeps_its_levels_reaction() -> void:
	_start([&"anchor", &"careful", &"flanker"], &"hard")
	for b in w.bots:
		assert_eq(b.skill.overtime_reaction, config.skill_for(&"hard").overtime_reaction)


func test_it_heads_for_the_very_foot_of_the_flag_not_a_spot_beside_it() -> void:
	var list := _overtime([&"rusher", &"rusher", &"rusher"])
	var b := list[0]
	b.overtime_flank = false
	w.time = b.overtime_at
	BotMovement.enter_flag(b, w)
	assert_eq(b.mode, Bot.Mode.FLAG)
	assert_false(b.flag_guard)
	assert_false(b.flanking)
	assert_eq(b.flag_goal, spot)


func test_a_flanker_whose_roll_came_up_goes_round_a_side_point_once_and_not_from_close_by() -> void:
	var list := _overtime([&"flanker", &"rusher", &"rusher"])
	var b := list[0]
	w.time = b.overtime_at
	b.overtime_flank = true
	var p := b.character.position
	assert_gte(_flat(p, spot), config.overtime_flank_min_distance, "far enough out to flank")
	BotMovement.enter_flag(b, w)
	assert_true(b.flanking, "round the side first")
	# The side point itself, or where the hall's huts and pillars cover it the nearest walkable spot within the snap.
	assert_true(nav.is_walkable_at(b.flank_goal), "on walkable ground")
	var reach := tuning.nav.snap
	assert_almost_eq(_flat(b.flank_goal, spot), Vector2(config.overtime_flank_offset, config.overtime_flank_back).length(),
			reach)
	# Off the straight way to the flag, to one side of it.
	var u := Vector2(spot.x - p.x, spot.z - p.z).normalized()
	var side := absf((b.flank_goal.x - spot.x) * -u.y + (b.flank_goal.z - spot.z) * u.x)
	assert_almost_eq(side, config.overtime_flank_offset, reach)
	assert_false(b.overtime_flank, "used up")
	assert_eq(b.flag_goal, spot, "then on for the foot")
	# From close by it goes straight.
	var near := list[1]
	near.overtime_flank = true
	near.character.position = Vector3(spot.x + config.overtime_flank_min_distance - 1.0, spot.y, spot.z)
	w.time = near.overtime_at
	BotMovement.enter_flag(near, w)
	assert_false(near.flanking)


func test_the_flank_roll_is_the_skills_flank_chance_drawn_as_the_flag_goes_up() -> void:
	var flanks := 0
	var draws := 0
	for seed_value in range(1, 21):
		_start([&"flanker", &"flanker", &"flanker"], &"normal", seed_value)
		state.events.clear()
		state.events.add(GameEvent.Kind.OVERTIME).position = spot
		bots.observe(state)
		for b in w.bots:
			if b.character.team == 1:
				draws += 1
				flanks += 1 if b.overtime_flank else 0
	var chance := clampf(config.skill_for(&"normal").flank_chance + file.style(&"flanker").flank_chance, 0.0, 1.0)
	assert_almost_eq(float(flanks) / draws, chance, 0.2, "about the flanker's chance")


func test_an_anchor_and_a_careful_bot_watch_it_from_cover_by_it_a_rusher_and_a_flanker_go_straight() -> void:
	var list := _overtime([&"anchor", &"careful", &"rusher"])
	var anchor := list[0]
	var careful := list[1]
	var rusher := list[2]
	assert_eq(anchor.style.flag_watch, 12.0)
	assert_eq(careful.style.flag_watch, 5.0)
	assert_false(file.style(&"flanker").watches_flag)
	assert_false(rusher.style.watches_flag)
	w.time = anchor.overtime_at + 1.0
	assert_true(BotPersonality.overtime_watching(anchor, w))
	assert_false(BotPersonality.overtime_watching(rusher, w))
	w.time = careful.overtime_at + 5.0
	assert_false(BotPersonality.overtime_watching(careful, w), "its 5 s are over")
	w.time = anchor.overtime_at + 1.0
	BotMovement.enter_flag(anchor, w)
	assert_true(anchor.flag_guard, "guards it")
	assert_lte(_flat(anchor.flag_goal, spot), config.flag_guard_radius + 1e-4, "near the flag")
	# Holding there, it aims at the flag.
	assert_almost_eq(BotAim.hold_yaw(anchor, w), BotAim.look_yaw(anchor.flag_goal, spot), 1e-6)
	assert_almost_eq(BotAim.hold_yaw(rusher, w), w.enemy_yaw(1), 1e-6, "anyone else faces the enemy side")


func test_a_watcher_goes_in_when_its_watch_is_over_in_the_last_seconds_under_an_order_or_as_the_last_of_its_team() -> void:
	var list := _overtime([&"anchor", &"rusher", &"rusher"])
	var anchor := list[0]
	var flag := state.round_state.overtime_flag
	w.time = anchor.overtime_at + 1.0
	assert_true(BotPersonality.overtime_watching(anchor, w))
	w.time = anchor.overtime_at + anchor.style.flag_watch
	assert_false(BotPersonality.overtime_watching(anchor, w), "its watch is over")
	w.time = anchor.overtime_at + 1.0
	flag.left = config.overtime_go_by
	assert_false(BotPersonality.overtime_watching(anchor, w), "the overtime's last seconds")
	flag.left = config.overtime_go_by + 5.0
	assert_true(BotPersonality.overtime_watching(anchor, w))
	anchor.order = SquadOrder.Kind.FOLLOW
	assert_false(BotPersonality.overtime_watching(anchor, w), "an ordered bot keeps its order")
	anchor.order = SquadOrder.Kind.NONE
	for c in state.characters:
		if c.team == anchor.character.team and c != anchor.character:
			c.status = Character.Status.OUT
	assert_false(BotPersonality.overtime_watching(anchor, w), "the last of its team goes in")


func test_a_watch_over_turns_the_guard_into_a_run_for_the_foot() -> void:
	var list := _overtime([&"careful", &"rusher", &"rusher"])
	var careful := list[0]
	careful.overtime_flank = false
	w.time = careful.overtime_at + 1.0
	BotMovement.enter_flag(careful, w)
	assert_true(careful.flag_guard)
	w.time = careful.overtime_at + careful.style.flag_watch
	var cmd := PlayerCommand.new()
	BotMovement.move(careful, w, cmd, DT, null)
	assert_false(careful.flag_guard, "in for the touch")
	assert_eq(careful.flag_goal, spot)


func test_with_the_flag_up_every_bot_sets_off_for_it_after_its_reaction() -> void:
	var list := _overtime([&"rusher", &"flanker", &"rusher"])
	var start: PackedFloat32Array = PackedFloat32Array()
	for b in w.bots:
		start.append(_flat(b.character.position, spot))
	for i in 180:
		_tick()
	for i in w.bots.size():
		var b := w.bots[i]
		assert_eq(b.mode, Bot.Mode.FLAG, "bot %d goes for the flag" % b.character.id)
		assert_lt(_flat(b.character.position, spot), start[i] - 3.0, "bot %d is on its way" % b.character.id)
	assert_eq(list.size(), 3)


func test_each_teams_bot_nearest_the_flag_calls_overtime_once_naming_where_it_stands() -> void:
	_start([&"rusher", &"rusher", &"rusher"])
	var nearest: PackedInt32Array = PackedInt32Array([-1, -1])
	var best: PackedFloat32Array = PackedFloat32Array([INF, INF])
	for c in state.characters:
		var d := _flat(c.position, spot)
		if d < best[c.team]:
			best[c.team] = d
			nearest[c.team] = c.id
	var from := bots.callouts.said.total
	state.events.clear()
	state.events.add(GameEvent.Kind.OVERTIME).position = spot
	bots.observe(state)
	for i in 120:
		_tick()
	var area := bots.callouts.area_of(spot)
	assert_ne(area, "", "Depot names the flag's area")
	var called: PackedInt32Array = PackedInt32Array([0, 0])
	for n in range(from, bots.callouts.said.total):
		var e := bots.callouts.said.entry(n)
		if e == null or e.event != CalloutsFile.Event.OVERTIME:
			continue
		called[e.team] += 1
		assert_eq(e.speaker_id, nearest[e.team], "the bot nearest the flag says it")
		if e.line.contains("Flag's up, "):
			assert_string_contains(e.line, area)
	assert_eq(called, PackedInt32Array([1, 1]), "once a team")


func test_a_tick_with_the_bots_going_for_the_flag_allocates_nothing_once_warm() -> void:
	_overtime([&"anchor", &"flanker", &"careful"])
	for i in 120:
		_tick()
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 120:
		bots.think(state, commands, DT)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)
