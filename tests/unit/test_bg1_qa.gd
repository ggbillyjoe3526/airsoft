extends GutTest
## BG1 QA · edge cases of the spread-out check: a ping join, the last bot, fighting teammates, a teammate bot's memory.

const DT := 1.0 / 60.0
const SPOT := Vector3(0.0, 0.0, 30.0)

var config: BotConfig = BotConfig.load_default()
var world: BotWorld = null


func _world(team_size: int = 4) -> void:
	world = BotWorld.new()
	world.cfg = config
	world.tuning = SimTuning.load_default()
	world.time = 10.0
	var skill := config.skill_for(&"normal").duplicate() as BotSkill
	skill.flank_chance = 0.0
	for id in team_size:
		var p := Vector3(-60.0 + 30.0 * id, 0.0, -40.0)
		var c := Character.new(id, 0, p, 0.0, ReplicaStats.default_loadout())
		c.position = p
		world.characters.append(c)
		world.bots.append(Bot.new(c, id + 1, skill, team_size))


func _hears(b: Bot) -> void:
	b.mode = Bot.Mode.ADVANCE
	b.last_known = SPOT
	b.has_last_known = true
	b.heard_at = world.time
	b.last_threat_at = world.time


func test_the_only_bot_on_its_team_is_never_held_back() -> void:
	_world(1)
	var b := world.bots[0]
	_hears(b)
	BotBrain._choose_mode(b, world, null, DT)
	assert_eq(b.mode, Bot.Mode.SEARCH, "nobody to crowd it")


func test_a_bot_joining_its_players_ping_goes_even_when_crowded() -> void:
	_world()
	world.characters[1].position = SPOT + Vector3(1.0, 0.0, 0.0)
	world.characters[2].position = SPOT + Vector3(-1.0, 0.0, 0.0)
	var b := world.bots[0]
	_hears(b)
	b.ping_at = world.time
	b.ping_spot = SPOT
	b.ping_joined = true
	BotBrain._choose_mode(b, world, null, DT)
	assert_eq(b.mode, Bot.Mode.SEARCH, "a ping it joined is not held back")


func test_the_human_player_on_the_team_counts_in_the_crowd() -> void:
	_world()
	var p := Character.new(9, 0, SPOT, 0.0, ReplicaStats.default_loadout())
	p.position = SPOT
	world.characters.append(p)
	world.characters[1].position = SPOT + Vector3(2.0, 0.0, 0.0)
	assert_true(BotSpread.crowded(world.bots[0], world, SPOT), "player and a bot there fill it")


func test_a_fighting_teammate_counts_only_with_a_threat_in_mind() -> void:
	_world()
	world.characters[1].position = SPOT
	var f := world.bots[2]
	f.mode = Bot.Mode.FIGHT
	f.has_last_known = true
	f.last_known = SPOT + Vector3(3.0, 0.0, 0.0)
	assert_true(BotSpread.crowded(world.bots[0], world, SPOT), "one there, one fighting it")
	f.has_last_known = false
	assert_false(BotSpread.crowded(world.bots[0], world, SPOT), "no threat in mind: not counted")


func test_a_searcher_keeps_searching_as_the_spot_fills_up() -> void:
	_world()
	var b := world.bots[0]
	_hears(b)
	BotBrain._choose_mode(b, world, null, DT)
	assert_eq(b.mode, Bot.Mode.SEARCH)
	world.characters[1].position = SPOT
	world.characters[2].position = SPOT
	for i in 30:
		world.time += DT
		BotBrain._choose_mode(b, world, null, DT)
		assert_eq(b.mode, Bot.Mode.SEARCH, "no oscillation once it is on its way")


func test_hunt_crowded_ignores_the_bot_itself_and_its_own_goal() -> void:
	_world()
	var me := world.bots[0]
	me.hunting = true
	me.hunt_goal = SPOT
	me.character.position = SPOT
	assert_false(BotSpread.hunt_crowded(me, world, SPOT), "not crowded by itself")
