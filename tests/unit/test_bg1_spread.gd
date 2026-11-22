extends GutTest
## BG1 · Bots spread out (owner 2026-11-22): a noise or a teammate's call draws at most BotConfig.search_crowd_max
## teammates to one spot, the rest watching it from their plan until there is room; hunters fan out away from one
## another; the whole team stacked on one lane is rare. AIM3 · Normal locks on more slowly: it reacts no quicker than
## Easy and settles its aim between Easy and Hard.

const DT := 1.0 / 60.0
const SPOT := Vector3(0.0, 0.0, 30.0)

var config: BotConfig = BotConfig.load_default()
var world: BotWorld = null


## Bots 0 to 3 on team 0 (0 at the origin, 1 to 3 far off), bot 4 on team 1 far behind the spot, all at Normal with no
## flanking (a flank asks the nav grid, which this world has none of).
func _world() -> void:
	world = BotWorld.new()
	world.cfg = config
	world.tuning = SimTuning.load_default()
	world.time = 10.0
	var skill := config.skill_for(&"normal").duplicate() as BotSkill
	skill.flank_chance = 0.0
	var spots: Array[Vector3] = [Vector3.ZERO, Vector3(-60.0, 0.0, 0.0), Vector3(60.0, 0.0, 0.0),
			Vector3(0.0, 0.0, -60.0), Vector3(0.0, 0.0, 90.0)]
	for id in spots.size():
		var c := Character.new(id, 0 if id < 4 else 1, spots[id], 0.0, ReplicaStats.default_loadout())
		c.position = spots[id]
		world.characters.append(c)
		world.bots.append(Bot.new(c, id + 1, skill, spots.size()))


## Bot `i` has just heard someone at SPOT, on its plan (walking its lane).
func _hears(i: int) -> Bot:
	var b := world.bots[i]
	b.mode = Bot.Mode.ADVANCE
	b.last_known = SPOT
	b.has_last_known = true
	b.heard_at = world.time
	b.last_threat_at = world.time
	return b


func test_a_spot_with_room_is_not_crowded() -> void:
	_world()
	assert_false(BotSpread.crowded(world.bots[0], world, SPOT), "nobody else there")
	world.characters[1].position = SPOT + Vector3(2.0, 0.0, 0.0)
	assert_false(BotSpread.crowded(world.bots[0], world, SPOT), "one teammate there leaves room")


func test_teammates_at_the_spot_or_on_their_way_crowd_it() -> void:
	_world()
	world.characters[1].position = SPOT + Vector3(2.0, 0.0, 0.0)
	# On its way: searching for someone at the spot from far off.
	var going := _hears(2)
	going.mode = Bot.Mode.SEARCH
	assert_true(BotSpread.crowded(world.bots[0], world, SPOT), "one there and one on its way: full")
	going.mode = Bot.Mode.ADVANCE
	assert_false(BotSpread.crowded(world.bots[0], world, SPOT), "one only watching it from its lane doesn't count")


func test_out_of_play_and_enemies_never_crowd_a_spot() -> void:
	_world()
	world.characters[1].position = SPOT
	world.characters[2].position = SPOT
	world.characters[2].status = Character.Status.OUT
	world.characters[4].position = SPOT
	assert_false(BotSpread.crowded(world.bots[0], world, SPOT), "one out of play, one an enemy")
	world.characters[2].status = Character.Status.ALIVE
	assert_true(BotSpread.crowded(world.bots[0], world, SPOT))


func test_a_bot_already_at_the_spot_is_never_held_back() -> void:
	_world()
	world.characters[0].position = SPOT + Vector3(3.0, 0.0, 0.0)
	world.characters[1].position = SPOT
	world.characters[2].position = SPOT
	assert_false(BotSpread.crowded(world.bots[0], world, SPOT), "it is one of the crowd itself")


func test_off_with_no_cap() -> void:
	_world()
	var cfg := config.duplicate() as BotConfig
	cfg.search_crowd_max = 0
	world.cfg = cfg
	world.characters[1].position = SPOT
	world.characters[2].position = SPOT
	assert_false(BotSpread.crowded(world.bots[0], world, SPOT))


func test_a_bot_goes_after_a_noise_with_room_and_watches_it_when_crowded() -> void:
	_world()
	var b := _hears(0)
	BotBrain._choose_mode(b, world, null, DT)
	assert_eq(b.mode, Bot.Mode.SEARCH, "room at the spot: it goes")
	_world()
	world.characters[1].position = SPOT + Vector3(1.0, 0.0, 0.0)
	world.characters[2].position = SPOT + Vector3(-1.0, 0.0, 0.0)
	b = _hears(0)
	BotBrain._choose_mode(b, world, null, DT)
	assert_eq(b.mode, Bot.Mode.ADVANCE, "two teammates there already: it keeps to its plan")
	assert_true(b.has_last_known, "still watching that way")
	# One of them goes down: there is room again, and it takes the call up.
	world.characters[1].status = Character.Status.OUT
	world.time += DT
	BotBrain._choose_mode(b, world, null, DT)
	assert_eq(b.mode, Bot.Mode.SEARCH, "room again: it goes")


func test_a_defender_goes_after_a_noise_near_its_pole_however_crowded() -> void:
	_world()
	world.mode = RoundState.Mode.ATTACK_DEFEND
	world.attackers = 1
	world.flag.position = SPOT
	world.characters[1].position = SPOT + Vector3(1.0, 0.0, 0.0)
	world.characters[2].position = SPOT + Vector3(-1.0, 0.0, 0.0)
	var b := _hears(0)
	b.lane_goal = SPOT + Vector3(0.0, 0.0, -14.0)
	b.character.position = b.lane_goal
	BotBrain._choose_mode(b, world, null, DT)
	assert_eq(b.mode, Bot.Mode.SEARCH, "the objective gathers its defenders")


func test_a_searching_bot_keeps_its_search_however_crowded() -> void:
	_world()
	var b := _hears(0)
	b.mode = Bot.Mode.SEARCH
	world.characters[1].position = SPOT
	world.characters[2].position = SPOT
	world.characters[3].position = SPOT
	BotBrain._choose_mode(b, world, null, DT)
	assert_eq(b.mode, Bot.Mode.SEARCH, "the crowd check is only for setting off")


func test_hunt_spots_near_teammates_or_their_hunt_spots_are_crowded() -> void:
	_world()
	var me := world.bots[0]
	assert_false(BotSpread.hunt_crowded(me, world, SPOT), "nobody near")
	world.characters[1].position = SPOT + Vector3(5.0, 0.0, 0.0)
	assert_true(BotSpread.hunt_crowded(me, world, SPOT), "a teammate stands near it")
	world.characters[1].position = Vector3(-60.0, 0.0, 0.0)
	var hunter := world.bots[2]
	hunter.hunting = true
	hunter.hunt_goal = SPOT + Vector3(0.0, 0.0, 6.0)
	assert_true(BotSpread.hunt_crowded(me, world, SPOT), "a teammate hunts towards it")
	hunter.hunting = false
	assert_false(BotSpread.hunt_crowded(me, world, SPOT), "a goal it isn't hunting for doesn't count")
	world.characters[4].position = SPOT
	assert_false(BotSpread.hunt_crowded(me, world, SPOT), "an enemy near it doesn't count")


func test_the_whole_team_on_one_lane_is_rare() -> void:
	var total := config.plan_split_weight + config.plan_pair_weight + config.plan_stack_weight
	assert_lt(config.plan_stack_weight / total, 0.1, "a stack at most one round in ten")
	assert_gt(config.plan_split_weight, config.plan_pair_weight, "spread over the lanes is the most common plan")


func test_normal_locks_on_no_quicker_than_easy_and_hard_stays_sharpest() -> void:
	var easy := config.skill_for(&"easy")
	var normal := config.skill_for(&"normal")
	var hard := config.skill_for(&"hard")
	assert_true(normal.reaction_time.x >= easy.reaction_time.x - 1e-6, "Normal reacts no quicker than Easy")
	assert_true(normal.pre_aim_reaction_time.x >= hard.pre_aim_reaction_time.x, "Hard pre-aims quickest")
	assert_lt(normal.aim_settle_time, easy.aim_settle_time, "Normal settles sooner than Easy")
	assert_gt(normal.aim_settle_time, hard.aim_settle_time, "and later than Hard")
	assert_lt(normal.aim_error_settled_deg, easy.aim_error_settled_deg, "and ends steadier than Easy")
	assert_eq(hard.reaction_time, normal.reaction_time, "Hard, surprised, is no quicker than Normal (careful, not twitchier)")
	assert_lt(hard.pre_aim_reaction_time.y, normal.reaction_time.x, "its edge is the angle it already holds")
