extends GutTest
## Plant The Bomb's bots (PB1, game/ai/bot_plant.gd): the sites as the bots' flags, who fetches the bomb and when (the
## player first), which site is in play, who goes back to an armed bomb and who disarms it (the player first, until
## the fuse leaves no time), and when a bot's hands go on it.

const SITE_A := Vector3(30.0, 0.0, -12.0)
const SITE_B := Vector3(30.0, 0.0, 12.0)
const START := Vector3(-30.0, 0.0, 0.0)
const PLAYER := 0

var w: BotWorld
var rs: RoundState
var cs: Array[Character] = []
var cmd := PlayerCommand.new()


## Three a side: team 0 attacks from the west (ids 0 to 2), team 1 defends (3 to 5). `player` (an id, or -1) is driven
## by no bot.
func _world(player: int = -1) -> void:
	w = BotWorld.new()
	w.cfg = BotConfig.load_default()
	w.tuning = SimTuning.new()
	w.mode = RoundState.Mode.PLANT_THE_BOMB
	w.attackers = 0
	w.planner = RoundPlanner.new(7)
	w.planner.spawn_centre = [Vector3(-30.0, 0.0, 0.0), Vector3(40.0, 0.0, 0.0)]
	w.planner.attack_dir = [Vector2(1.0, 0.0), Vector2(-1.0, 0.0)]
	w.planner.attack_flag = 0
	rs = RoundState.new()
	rs.mode = RoundState.Mode.PLANT_THE_BOMB
	rs.attackers = 0
	rs.plant.set_sites(PackedVector3Array([SITE_A, SITE_B]), PackedFloat32Array(), w.tuning.plant.site_radius)
	rs.plant.start = START
	rs.plant.reset()
	cs = []
	w.bots = []
	var loadout: Array[ReplicaConfig] = []
	for id in 6:
		var team := 0 if id < 3 else 1
		var at := Vector3(-32.0 - id, 0.0, float(id)) if team == 0 else Vector3(38.0, 0.0, float(id) * 4.0 - 16.0)
		var c := Character.new(id, team, at, 0.0, loadout)
		cs.append(c)
		if id != player:
			w.bots.append(Bot.new(c, id + 1, w.cfg.skill, 6))
	w.characters = cs
	BotPlant.sync(w, rs)


func _bot(id: int) -> Bot:
	return w.bot_of(cs[id])


func _arm(site: int) -> void:
	rs.plant.status = PlantState.Status.PLANTED
	rs.plant.site = site
	rs.plant.position = rs.plant.sites[site] + Vector3(1.0, 0.0, 0.0)
	rs.plant.fuse_left = w.tuning.plant.fuse_time
	rs.plant.carrier = -1
	BotPlant.sync(w, rs)


func test_the_sites_stand_in_for_the_poles_and_the_drawn_one_is_in_play() -> void:
	_world()
	assert_eq(w.flags.size(), 2)
	assert_eq(w.flags[0].position, SITE_A)
	assert_eq(w.flags[1].position, SITE_B)
	assert_eq(w.flag_index, 0)
	w.planner.attack_flag = 1
	BotPlant.sync(w, rs)
	assert_eq(w.plant_site, 1)
	assert_same(w.flag, w.flags[1])
	assert_eq(w.flags[1].progress, 0.0, "nothing armed: nothing for the defenders to go back to")


func test_an_armed_bomb_is_the_site_in_play_where_it_stands() -> void:
	_world()
	_arm(1)
	assert_eq(w.flag_index, 1, "though A was drawn")
	assert_eq(w.flags[1].position, rs.plant.position, "the bots go to the bomb, not the site's middle")
	assert_eq(w.flags[1].progress, 1.0)
	rs.plant.defuser = 4
	BotPlant.sync(w, rs)
	assert_eq(w.flags[1].status, FlagState.Status.LOWERING)


func test_the_defenders_learn_of_the_keys_only_within_earshot() -> void:
	_world()
	rs.plant.status = PlantState.Status.CARRIED
	rs.plant.carrier = 1
	rs.plant.position = SITE_A
	rs.plant.site = 0
	rs.plant.planter = 1
	rs.plant.planting = 0.3
	for id: int in [3, 4, 5]:
		cs[id].position = SITE_A + Vector3(w.cfg.plant_heard + 2.0, 0.0, 0.0)
	BotPlant.sync(w, rs)
	assert_eq(w.flags[0].progress, 0.0, "nobody near enough to hear")
	cs[4].position = SITE_A + Vector3(w.cfg.plant_heard - 2.0, 0.0, 0.0)
	BotPlant.sync(w, rs)
	assert_almost_eq(w.flags[0].progress, 0.3, 0.001)
	assert_eq(w.flags[0].status, FlagState.Status.RAISING)
	cs[4].status = Character.Status.OUT
	BotPlant.sync(w, rs)
	assert_eq(w.flags[0].progress, 0.0, "one out of play hears nothing")


func test_the_nearest_free_attacker_fetches_the_bomb_and_nobody_once_it_is_carried() -> void:
	_world()
	cs[1].position = START + Vector3(1.0, 0.0, 0.0)
	BotPlant.plan(w)
	assert_true(_bot(1).fetcher)
	assert_false(_bot(0).fetcher or _bot(2).fetcher)
	assert_false(_bot(3).fetcher, "never a defender")
	_bot(1).order = SquadOrder.Kind.HOLD
	BotPlant.plan(w)
	assert_false(_bot(1).fetcher, "one under a squad order does what it was asked")
	assert_true(_bot(0).fetcher or _bot(2).fetcher)
	rs.plant.status = PlantState.Status.CARRIED
	rs.plant.carrier = 2
	BotPlant.plan(w)
	for id in 3:
		assert_false(_bot(id).fetcher)
	assert_true(_bot(2).raiser, "the carrier is the one who goes in")
	assert_false(_bot(0).raiser)


func test_with_no_player_attacking_the_bots_take_the_bomb_at_once() -> void:
	_world()
	assert_true(BotPlant.may_take(w))


func test_the_bots_leave_the_bomb_to_the_player_at_the_start() -> void:
	_world(PLAYER)
	cs[PLAYER].position = START + Vector3(-3.0, 0.0, 0.0)
	w.plant_down_at = 0.0
	w.time = 1.0
	assert_false(BotPlant.may_take(w), "the player stands by it")
	w.time = w.cfg.plant_player_first - 0.1
	assert_false(BotPlant.may_take(w))
	w.time = w.cfg.plant_player_first + 0.1
	assert_true(BotPlant.may_take(w), "they had their time")
	w.time = 1.0
	cs[PLAYER].position = START + Vector3(w.cfg.plant_player_left + 1.0, 0.0, 0.0)
	assert_true(BotPlant.may_take(w), "the player walked off without it")
	cs[PLAYER].position = START
	cs[PLAYER].status = Character.Status.OUT
	assert_true(BotPlant.may_take(w), "a player out of play has no claim")


func test_a_dropped_bomb_is_left_to_a_player_near_it() -> void:
	_world(PLAYER)
	rs.plant.moved = true
	rs.plant.position = Vector3(10.0, 0.0, 0.0)
	w.plant_down_at = 20.0
	w.time = 20.0 + w.cfg.plant_drop_wait + 0.1
	cs[PLAYER].position = rs.plant.position + Vector3(w.cfg.plant_player_near - 1.0, 0.0, 0.0)
	assert_false(BotPlant.may_take(w))
	cs[PLAYER].position = rs.plant.position + Vector3(w.cfg.plant_player_near + 1.0, 0.0, 0.0)
	assert_true(BotPlant.may_take(w), "the player is not near: a bot takes it after a moment")
	w.time = 20.0 + w.cfg.plant_drop_wait - 0.1
	assert_false(BotPlant.may_take(w), "not the instant it falls")


func test_a_fetcher_waits_with_its_hands_off_until_it_may_take_it() -> void:
	_world(PLAYER)
	cs[PLAYER].position = START + Vector3(-2.0, 0.0, 0.0)
	cs[1].position = START + Vector3(0.5, 0.0, 0.0)
	w.time = 1.0
	BotPlant.plan(w)
	assert_true(_bot(1).fetcher)
	cmd.reset()
	BotPlant.act(_bot(1), w, cmd)
	assert_false(cmd.interact)
	w.time = w.cfg.plant_player_first + 1.0
	BotPlant.act(_bot(1), w, cmd)
	assert_true(cmd.interact)
	cmd.reset()
	BotPlant.act(_bot(2), w, cmd)
	assert_false(cmd.interact, "only the fetcher")


func test_the_carrier_arms_once_settled_in_the_site_and_commits() -> void:
	_world()
	rs.plant.status = PlantState.Status.CARRIED
	rs.plant.carrier = 1
	BotPlant.plan(w)
	var b := _bot(1)
	b.mode = Bot.Mode.FLAG
	b.flag_guard = false
	b.flag_goal = SITE_A + Vector3(1.0, 0.0, 0.0)
	cs[1].position = SITE_A + Vector3(3.0, 0.0, 0.0)
	cmd.reset()
	BotPlant.act(b, w, cmd)
	assert_false(cmd.interact, "inside the site but not at its spot yet")
	cs[1].position = b.flag_goal
	BotPlant.act(b, w, cmd)
	assert_true(cmd.interact)
	assert_true(cmd.crouch)
	assert_false(cmd.fire)
	# Pulled into a fight part way: under plant_commit it lets go, past it it finishes.
	b.mode = Bot.Mode.FIGHT
	rs.plant.planter = 1
	rs.plant.planting = w.cfg.plant_commit - 0.1
	cmd.reset()
	BotPlant.act(b, w, cmd)
	assert_false(cmd.interact)
	rs.plant.planting = w.cfg.plant_commit + 0.1
	BotPlant.act(b, w, cmd)
	assert_true(cmd.interact)
	cs[1].position = SITE_A + Vector3(w.tuning.plant.site_radius + 2.0, 0.0, 0.0)
	cmd.reset()
	BotPlant.act(b, w, cmd)
	assert_false(cmd.interact, "never outside a site")


func test_every_free_defender_goes_back_to_an_armed_bomb_and_the_nearest_disarms_it() -> void:
	_world()
	_arm(0)
	cs[4].position = rs.plant.position + Vector3(3.0, 0.0, 0.0)
	_bot(5).order = SquadOrder.Kind.HOLD
	BotPlant.plan(w)
	assert_true(_bot(3).retake and _bot(4).retake)
	assert_eq(_bot(3).retake_pole, 0)
	assert_false(_bot(5).retake, "one under a squad order stays")
	assert_true(_bot(4).defuser)
	assert_false(_bot(3).defuser)
	assert_true(BotPlant.wants_site(_bot(3), w))
	assert_true(BotPlant.guards(_bot(3), w), "the others cover the one on the bomb")
	assert_false(BotPlant.guards(_bot(4), w))
	assert_true(BotPlant.wants_site(_bot(1), w), "the attackers hold the armed bomb")
	assert_true(BotPlant.guards(_bot(1), w))


func test_the_one_disarming_puts_its_hands_on_in_reach_and_finishes_past_the_commit() -> void:
	_world()
	_arm(0)
	cs[4].position = rs.plant.position + Vector3(1.0, 0.0, 0.0)
	BotPlant.plan(w)
	var b := _bot(4)
	b.mode = Bot.Mode.FLAG
	cmd.reset()
	BotPlant.act(b, w, cmd)
	assert_true(cmd.interact)
	b.mode = Bot.Mode.FIGHT
	cmd.reset()
	BotPlant.act(b, w, cmd)
	assert_false(cmd.interact, "a fight comes first while there is time")
	rs.plant.defuser = 4
	rs.plant.defusing = w.cfg.defuse_commit + 0.05
	BotPlant.act(b, w, cmd)
	assert_true(cmd.interact, "nearly done: it finishes")
	rs.plant.defusing = 0.0
	rs.plant.fuse_left = w.tuning.plant.defuse_time + w.cfg.plant_no_time - 0.1
	cmd.reset()
	BotPlant.act(b, w, cmd)
	assert_true(cmd.interact, "no time for anything else")
	cs[4].position = rs.plant.position + Vector3(w.tuning.plant.defuse_reach + 1.0, 0.0, 0.0)
	cmd.reset()
	BotPlant.act(b, w, cmd)
	assert_false(cmd.interact, "out of reach")


func test_the_bots_leave_the_defuse_to_a_player_near_the_bomb_until_the_fuse_is_short() -> void:
	_world(3)
	w.attackers = 0
	_arm(0)
	var you := cs[3]
	you.position = rs.plant.position + Vector3(w.cfg.plant_player_claim - 1.0, 0.0, 0.0)
	assert_false(BotPlant.may_defuse(w))
	BotPlant.plan(w)
	assert_false(_bot(4).defuser or _bot(5).defuser)
	assert_true(_bot(4).retake, "they still come back and cover")
	var takeover := w.tuning.plant.defuse_time + w.cfg.plant_takeover_margin
	rs.plant.fuse_left = takeover + 0.5
	assert_false(BotPlant.may_defuse(w))
	rs.plant.fuse_left = takeover - 0.5
	assert_true(BotPlant.may_defuse(w), "the fuse leaves a bot only just time")
	BotPlant.plan(w)
	assert_true(_bot(4).defuser or _bot(5).defuser)
	# With the player's own hands on it the bots never take over.
	rs.plant.defuser = you.id
	rs.plant.defusing = 0.2
	assert_false(BotPlant.may_defuse(w))
	rs.plant.defuser = -1
	rs.plant.fuse_left = w.tuning.plant.fuse_time
	you.position = rs.plant.position + Vector3(w.cfg.plant_player_claim + 2.0, 0.0, 0.0)
	assert_true(BotPlant.may_defuse(w), "a player nowhere near has no claim")
	you.position = rs.plant.position
	you.status = Character.Status.OUT
	assert_true(BotPlant.may_defuse(w), "nor one out of play")


func test_the_bots_follow_a_player_carrying_the_bomb_to_the_other_site() -> void:
	_world(PLAYER)
	rs.plant.status = PlantState.Status.CARRIED
	rs.plant.carrier = PLAYER
	cs[PLAYER].position = Vector3(0.0, 0.0, 0.0)
	BotPlant.sync(w, rs)
	assert_eq(w.plant_site, 0, "in the middle the drawn site stands")
	cs[PLAYER].position = SITE_B + Vector3(-w.cfg.plant_follow_site + 2.0, 0.0, 0.0)
	BotPlant.sync(w, rs)
	assert_eq(w.plant_site, 1, "closing on B: the bots come too")
	assert_eq(w.planner.attack_flag, 1, "and B is kept for the round")
	cs[PLAYER].position = Vector3(0.0, 0.0, 0.0)
	BotPlant.sync(w, rs)
	assert_eq(w.plant_site, 1)


func test_a_bomb_dropped_by_the_other_site_moves_the_plan_there() -> void:
	_world()
	var events := SimEvents.new()
	var e := events.add(GameEvent.Kind.BOMB)
	e.value = Plant.Cue.DROPPED
	e.position = SITE_B + Vector3(-4.0, 0.0, 0.0)
	BotPlant.observe(w, events, 12.0)
	assert_eq(w.planner.attack_flag, 1)
	assert_eq(w.plant_down_at, 12.0)
	w.planner.attack_flag = 0
	events.clear()
	e = events.add(GameEvent.Kind.BOMB)
	e.value = Plant.Cue.DROPPED
	e.position = START + Vector3(5.0, 0.0, 9.0)
	BotPlant.observe(w, events, 14.0)
	assert_eq(w.planner.attack_flag, 0, "dropped in its own half, the plan stands")


func test_attackers_go_in_once_their_lane_is_swept_or_the_clock_runs_short() -> void:
	_world()
	rs.plant.status = PlantState.Status.CARRIED
	rs.plant.carrier = 1
	BotPlant.plan(w)
	var b := _bot(0)
	w.round_clock = w.cfg.plant_rush_clock + 30.0
	assert_false(BotPlant.wants_site(b, w))
	b.lane_done = true
	assert_true(BotPlant.wants_site(b, w))
	b.lane_done = false
	w.round_clock = w.cfg.plant_rush_clock - 1.0
	assert_true(BotPlant.wants_site(b, w), "short of time, everyone goes")
	assert_false(BotPlant.wants_site(_bot(3), w), "a defender holds its post while nothing is armed")
