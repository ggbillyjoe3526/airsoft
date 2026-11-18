extends GutTest
## Personalities in Attack / Defend and Plant The Bomb (PS1, owner 2026-11-18: "make the personalities matter there"):
## bots.md's Attack / Defend and Plant the Bomb table gives each personality its job. A Rusher takes the round's pushed
## post first, an Anchor defends deep and is never pushed up, the defenders that go back count nearer or further by
## their personality, a Flanker attacker carries the bomb in before a nearer Rusher (the rope goes by distance alone),
## and each personality comes back at a forward spawn as often as its own chance says. Elimination plays as before. Bare
## bot worlds for the picks, and RV1's flat 60 by 30 m field for the plan (game/ai/round_planner.gd, bot_flag.gd,
## bot_plant.gd, bot_respawn.gd, game/config/bots_file.gd).

const DT := 1.0 / 60.0
const KILL_Y := -10.0

## One life a round, so the pick of retakers is the plain one (no respawn_retakers).
var tuning: SimTuning = MatchGuard.one_life(SimTuning.load_default())
var config: BotConfig = BotConfig.load_default()
var file: BotsFile = BotsFile.read_file()
var loadout: Array[ReplicaConfig] = ReplicaStats.default_loadout()
var map: MapData = null
var world: BoxWorld = null
var nav: NavGrid = null
var state: GameState = null
var bots: BotController = null
var sim: Simulation = null


func before_all() -> void:
	map = MapData.new()
	map.id = "sided field"
	map.kill_y = KILL_Y
	world = BoxWorld.new(tuning.body)
	world.add_floor(60.0, 30.0)
	map.blocks.append(_block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(60.0, 0.5, 30.0)))
	for e in 2:
		var x := -27.0 if e == 0 else 27.0
		var end := MapEnd.new()
		for z: float in [-3.0, -1.0, 1.0, 3.0]:
			end.spawns.append(SpawnPoint.new(Vector3(x, 0.0, z), -PI * 0.5 if e == 0 else PI * 0.5))
		for z: float in [12.0, 13.0, 14.0]:
			end.dead_zone.append(SpawnPoint.new(Vector3(-29.0 if e == 0 else 29.0, 0.0, z), 0.0))
		map.ends.append(end)
	# Four lanes the length of the field, so a split plan gives each defender a lane of its own.
	for z: float in [-9.0, -3.0, 3.0, 9.0]:
		var lane := PackedVector3Array()
		for i in 9:
			lane.append(Vector3(-24.0 + i * 6.0, 0.0, z))
		map.lanes.append(lane)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


static func _block(kind: StringName, center: Vector3, size: Vector3) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = kind
	b.center = center
	b.size = size
	return b


## A match on the field seeded `seed_value` in `mode` (team 0 attacks first), every bot on `cfg`, 4 a side.
func _start(cfg: BotConfig, mode: RoundState.Mode, seed_value: int = 5) -> BotWorld:
	sim = Simulation.new(tuning, world, world.mover(), map.ends, KILL_Y)
	sim.nav = nav
	state = GameState.new(seed_value, tuning)
	for i in 8:
		state.characters.append(Character.new(i, 0 if i < 4 else 1, Vector3.ZERO, 0.0, loadout))
	if mode == RoundState.Mode.ATTACK_DEFEND:
		state.round_state.mode = mode
		state.round_state.pole = Vector3(24.0, 0.0, 0.0)
	bots = BotController.new(state, -1, map, nav, world, tuning, cfg)
	sim.start_match(state)
	bots.observe(state)
	return bots.world


## The plan with no variety but the pushed post's, and every defender alone on its lane (a split plan).
func _quiet(push: float) -> BotConfig:
	var out: BotConfig = config.duplicate()
	out.lane_jitter = 0.0
	out.tempo_quick_weight = 0.0
	out.tempo_slow_weight = 0.0
	out.lane_shift = 0.0
	out.lane_cross_chance = 0.0
	out.defend_push_chance = push
	out.defend_push_share = 1.0
	out.defend_forward_chance = 0.5
	out.plan_pair_weight = 0.0
	out.plan_stack_weight = 0.0
	return out


## Every bot of `team` playing `kind`, then the round planned again.
func _team_plays(w: BotWorld, team: int, kind: StringName) -> void:
	for b in w.bots:
		if b.character.team == team:
			b.style = file.style(kind)
	bots._new_round(state)


## A bare bot world in `mode`, team 0 attacking, and a bot for each of `at` on `team` there.
func _bare(mode: RoundState.Mode, team: int, at: Array[Vector3]) -> BotWorld:
	var w := BotWorld.new()
	w.cfg = BotConfig.new()
	w.tuning = SimTuning.new()
	w.mode = mode
	w.attackers = 0
	for i in at.size():
		var c := Character.new(i, team, at[i], 0.0, loadout)
		w.characters.append(c)
		w.bots.append(Bot.new(c, 7 + i, BotSkill.new(), at.size()))
	return w


func test_the_shipped_file_gives_each_personality_a_job_with_sides() -> void:
	assert_eq(file.problems, [] as Array[String], "bots.md reads cleanly")
	var rusher := file.style(&"rusher")
	var anchor := file.style(&"anchor")
	var flanker := file.style(&"flanker")
	assert_eq(rusher.post, BotsFile.Post.FORWARD)
	assert_eq(anchor.post, BotsFile.Post.DEEP)
	assert_eq(flanker.post, BotsFile.Post.SAME)
	assert_lt(rusher.retake_scale, 1.0, "a rusher goes back among the first")
	assert_eq(anchor.retake_scale, 1.0, "an anchor by the pole goes back as its distance says")
	assert_lt(flanker.carry_scale, 1.0, "a flanker takes the bomb in")
	assert_gt(rusher.carry_scale, 1.0, "a rusher leaves it to others")
	var mean := 0.0
	for k in file.kinds:
		assert_true(file.style(k).has_spawn_chance, "%s has its own forward spawn chance" % k)
		mean += file.style(k).spawn_chance
	assert_gt(rusher.spawn_chance, anchor.spawn_chance, "a rusher comes back forward more often")
	mean /= file.kinds.size()
	assert_lt(mean, config.forward_spawn_chance, "under the game's chance: the most hit come back forward most")
	assert_gt(mean, config.forward_spawn_chance - 0.2, "but not far under, so a team still comes back forward")


func test_a_file_without_the_table_plays_the_same_jobs_and_a_bad_cell_keeps_neutral() -> void:
	var text := FileAccess.get_file_as_string(BotsFile.PATH)
	var cut := text.find("## " + BotsFile.SIDED)
	assert_gt(cut, 0)
	var without := BotsFile.parse(text.substr(0, cut))
	assert_eq(without.problems, [] as Array[String], "the table may be left out")
	var r := without.style(&"rusher")
	assert_eq(r.post, BotsFile.Post.SAME)
	assert_eq(r.retake_scale, 1.0)
	assert_eq(r.carry_scale, 1.0)
	assert_false(r.has_spawn_chance)
	var row := _row(text, "| Rusher | forward |")
	var bad := BotsFile.parse(text.replace(row, "| Rusher | sideways | x | 9 | 2 |"))
	assert_eq(bad.problems.size(), 4, "each bad cell reported: %s" % [bad.problems])
	var b := bad.style(&"rusher")
	assert_eq(b.post, BotsFile.Post.SAME)
	assert_eq(b.retake_scale, 1.0)
	assert_eq(b.carry_scale, 1.0)
	assert_false(b.has_spawn_chance)
	assert_true(file.style(&"rusher").is_neutral() == false, "its move numbers still count")


func test_deep_defenders_hold_the_first_point_and_forward_ones_what_the_plan_deals() -> void:
	assert_eq(RoundPlanner.defend_points(BotsFile.Post.FORWARD, false), 1, "forward is the pushed post, not this")
	assert_eq(RoundPlanner.defend_points(BotsFile.Post.FORWARD, true), 2)
	assert_eq(RoundPlanner.defend_points(BotsFile.Post.DEEP, true), 1)
	assert_eq(RoundPlanner.defend_points(BotsFile.Post.SAME, true), 2)
	assert_eq(RoundPlanner.defend_points(BotsFile.Post.SAME, false), 1)
	var w := _start(_quiet(0.0), RoundState.Mode.ATTACK_DEFEND)
	_team_plays(w, 1, &"flanker")
	var dealt: Array[int] = []
	for b in w.bots:
		dealt.append(b.lane_points)
	# The same match again, its second plan with rushers: the plan's draws are the same.
	w = _start(_quiet(0.0), RoundState.Mode.ATTACK_DEFEND)
	_team_plays(w, 1, &"rusher")
	for i in w.bots.size():
		if BotFlag.role(w.bots[i], w) == BotFlag.Role.DEFEND:
			assert_eq(w.bots[i].lane_points, dealt[i], "no pushed post this round: a rusher holds what it was dealt")
	_team_plays(w, 1, &"anchor")
	for b in w.bots:
		if BotFlag.role(b, w) == BotFlag.Role.DEFEND:
			assert_eq(b.lane_points, 1, "an anchor holds deep")


func test_the_pushed_post_goes_to_a_rusher_and_never_to_an_anchor() -> void:
	var w := _start(_quiet(1.0), RoundState.Mode.ATTACK_DEFEND)
	for b in w.bots:
		b.style = file.style(&"anchor")
	var rusher := w.bots[6]
	rusher.style = file.style(&"rusher")
	bots._new_round(state)
	var short := w.planner._points_to_middle(map.lanes[rusher.lane], 1, rusher.character.end) - 1
	assert_eq(rusher.lane_points, short, "the rusher holds the pushed post, all the way short of the middle")
	for b in w.bots:
		if b != rusher and BotFlag.role(b, w) == BotFlag.Role.DEFEND:
			assert_eq(b.lane_points, 1, "the anchors hold deep")
	rusher.style = file.style(&"anchor")
	bots._new_round(state)
	for b in w.bots:
		if BotFlag.role(b, w) == BotFlag.Role.DEFEND:
			assert_eq(b.lane_points, 1, "a team of anchors: nobody is pushed up")


func test_the_pushed_member_is_the_first_forward_one_round_from_the_draw() -> void:
	var p := RoundPlanner.new(1)
	var kinds: Array[StringName] = [&"anchor", &"flanker", &"rusher", &"careful"]
	for k in kinds:
		var b := Bot.new(Character.new(0, 1, Vector3.ZERO, 0.0, loadout), 1, BotSkill.new(), 4)
		b.style = file.style(k)
		p._members.append(b)
	assert_eq(p._pushed_member(-1), -1, "no push drawn: none")
	assert_eq(p._pushed_member(3), 2, "round the team to the rusher")
	p._members[2].style = file.style(&"careful")
	assert_eq(p._pushed_member(0), 1, "no rusher: the anchor drawn passes it on")
	assert_eq(p._pushed_member(3), 3, "a careful bot drawn keeps it")


func test_elimination_plans_as_before_whatever_the_jobs() -> void:
	var w := _start(_quiet(1.0), RoundState.Mode.ELIMINATION)
	var before: Array[int] = []
	for b in w.bots:
		before.append(b.lane_points)
	_team_plays(w, 1, &"rusher")
	_team_plays(w, 0, &"flanker")
	for i in w.bots.size():
		assert_eq(w.bots[i].lane_points, before[i], "Elimination walks every lane point, forward or deep")


func test_a_rusher_goes_back_before_a_nearer_bot_that_stays_longer() -> void:
	var pole := Vector3(10.0, 0.0, 0.0)
	var w := _bare(RoundState.Mode.ATTACK_DEFEND, 1, [pole + Vector3(2.0, 0, 0), pole + Vector3(2.6, 0, 0),
			pole + Vector3(3.0, 0, 0)] as Array[Vector3])
	w.flags[0].position = pole
	w.cfg.retakers = 2
	var stays := BotsFile.Style.new()
	stays.retake_scale = 1.4
	w.bots[0].style = stays
	w.bots[2].style = file.style(&"rusher")
	BotFlag.pick_retakers(w)
	assert_true(w.bots[2].retake, "the rusher, furthest, goes back")
	assert_true(w.bots[1].retake)
	assert_false(w.bots[0].retake, "the one that stays longer, nearest, holds its post")
	w.bots[0].style = BotsFile.neutral()
	BotFlag.pick_retakers(w)
	assert_true(w.bots[0].retake and w.bots[2].retake, "neutral: the nearest goes back, and the rusher")


func test_the_nearest_attacker_raises_the_flag_whatever_its_personality() -> void:
	var pole := Vector3(10.0, 0.0, 0.0)
	var w := _bare(RoundState.Mode.ATTACK_DEFEND, 0, [pole - Vector3(2.0, 0, 0), pole - Vector3(2.5, 0, 0)]
			as Array[Vector3])
	w.flags[0].position = pole
	for b in w.bots:
		b.lane_done = true
	w.bots[0].style = file.style(&"rusher")
	w.bots[1].style = file.style(&"flanker")
	BotFlag.pick_raiser(w)
	assert_true(w.bots[0].raiser, "the rusher, nearest, takes the rope: a lean there lifted the attackers' share")
	assert_false(w.bots[1].raiser)


func test_a_flanker_fetches_the_bomb_before_a_nearer_rusher() -> void:
	var bomb := Vector3(-20.0, 0.0, 0.0)
	var w := _bare(RoundState.Mode.PLANT_THE_BOMB, 0, [bomb + Vector3(2.0, 0, 0), bomb + Vector3(2.5, 0, 0)]
			as Array[Vector3])
	w.plant = PlantState.new()
	w.plant.status = PlantState.Status.DOWN
	w.plant.position = bomb
	w.bots[0].style = file.style(&"rusher")
	w.bots[1].style = file.style(&"flanker")
	BotPlant._pick_fetcher(w)
	assert_true(w.bots[1].fetcher, "the flanker picks it up, and so carries it in")
	assert_false(w.bots[0].fetcher)
	w.bots[1].character.position = bomb + Vector3(12.0, 0, 0)
	w.time += w.cfg.fetcher_hold + 0.1
	BotPlant._pick_fetcher(w)
	assert_true(w.bots[0].fetcher, "far off, the flanker leaves it to the rusher by it")


func test_each_personality_comes_back_forward_with_its_own_chance() -> void:
	var w := _bare(RoundState.Mode.ATTACK_DEFEND, 0, [Vector3.ZERO] as Array[Vector3])
	var end := MapEnd.new()
	var f := ForwardSpawn.new()
	f.spots.append(SpawnPoint.new(Vector3(-10.0, 0.0, 0.0), 0.0))
	f.centre = Vector3(-10.0, 0.0, 0.0)
	end.forward.append(f)
	w.ends = [end] as Array[MapEnd]
	var b := w.bots[0]
	b.character.end = 0
	w.cfg.forward_spawn_chance = 0.0
	var always := BotsFile.Style.new()
	always.has_spawn_chance = true
	always.spawn_chance = 1.0
	b.style = always
	assert_gt(BotRespawn.pick(b, w), 0, "its own chance, not the game's")
	b.reset(-1, 0, 0.0, w.cfg)
	w.cfg.forward_spawn_chance = 1.0
	always.spawn_chance = 0.0
	assert_eq(BotRespawn.pick(b, w), 0, "never forward")
	b.reset(-1, 0, 0.0, w.cfg)
	b.style = BotsFile.neutral()
	assert_gt(BotRespawn.pick(b, w), 0, "no chance of its own: the game's")
	b.reset(-1, 0, 0.0, w.cfg)
	b.style = always
	w.mode = RoundState.Mode.ELIMINATION
	w.attackers = -1
	assert_gt(BotRespawn.pick(b, w), 0, "Elimination with respawns: the game's chance, not the personality's")


## The whole line of the table row that starts with `start` (so a tuned number doesn't break the test).
func _row(text: String, start: String) -> String:
	var at := text.find(start)
	assert_gt(at, -1, "the row %s is in bots.md" % start)
	return text.substr(at, text.find("\n", at) - at)
