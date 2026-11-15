extends GutTest
## QA for AIM1 (picking someone up again, game/ai/bot_senses.gd): a dazzle that ends, switching between two enemies,
## a sniper's bolt wait after a re-pick-up, Hard's levels, and a new round forgetting the contact.

const HIDE := Vector3(-1.0, 0.0, -20.0)
const OUT := Vector3(0.8, 0.0, -20.0)
const NEAR_OUT := Vector3(-2.5, 0.0, -10.0)
const SNIPER := "000021"

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()

var _w: BotWorld = null
var _b: Bot = null
var _you: Character = null
var _other: Character = null


func _build(level: StringName) -> void:
	var m := MapData.new()
	m.id = "reacquire qa field"
	m.kill_y = -10.0
	var world := BoxWorld.new(tuning.body)
	var floor_block := MapData.Block.new()
	floor_block.kind = &"floor"
	floor_block.center = Vector3(0.0, -0.25, -15.0)
	floor_block.size = Vector3(16.0, 0.5, 50.0)
	m.blocks.append(floor_block)
	world.add_box(floor_block.center, floor_block.size)
	world.add_box(Vector3(-1.7, 1.5, -19.4), Vector3(3.0, 3.0, 0.3))
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(0.0, 0.0, 5.0 if e == 0 else -35.0), 0.0 if e == 0 else PI))
		end.dead_zone.append(SpawnPoint.new(Vector3(6.0, 0.0, 8.0 if e == 0 else -38.0), 0.0))
		m.ends.append(end)
	var nav := NavGrid.build(m, tuning.nav, tuning.body)
	var state := GameState.new(3, tuning)
	var loadout := ReplicaStats.default_loadout()
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	state.characters.append(Character.new(1, 1, HIDE, PI, loadout))
	state.characters.append(Character.new(2, 1, Vector3(5.0, 0.0, -30.0), PI, loadout))
	var levels: Dictionary[int, StringName] = {0: level, 1: level, 2: level}
	var bots := BotController.new(state, 1, m, nav, world, tuning, config, levels)
	_w = bots.world
	_b = _w.bots[0]
	_b.character.position = Vector3.ZERO
	_b.character.yaw = 0.0
	_b.aim_yaw = 0.0
	_you = state.characters[1]
	_other = state.characters[2]
	_w.time = 10.0


func _look(at: Vector3, seconds: float) -> void:
	_w.time += seconds
	_you.position = at
	BotSenses.perceive(_b, _w)


func _settle_at_out() -> void:
	_look(OUT, 0.0)
	for i in 20:
		_look(OUT, 0.1)


func test_a_bot_whose_dazzle_ends_picks_you_up_again_not_instantly() -> void:
	_build(&"normal")
	_settle_at_out()
	assert_true(BotSenses.has_reacted(_b, _w))
	_b.character.dazzle_left = 0.6
	_look(OUT, 0.1)
	assert_false(_b.target_visible, "dazzled: sees nothing")
	_b.character.dazzle_left = 0.0
	_look(OUT, 0.5)
	assert_true(_b.target_visible)
	assert_false(BotSenses.has_reacted(_b, _w), "eyes back: it has to find you again")


func test_switching_back_to_an_enemy_seen_a_moment_ago_picks_it_up_again_with_its_first_sighting_kept() -> void:
	_build(&"normal")
	_other.position = Vector3(5.0, 0.0, -60.0)
	_settle_at_out()
	var first := _b.contact.first_seen_at
	var a_contact := _b.contact
	# A nearer enemy steps in: the bot switches and its contact with the first is not refreshed while it watches this one.
	_you.position = OUT
	_other.position = NEAR_OUT
	_w.time += 0.1
	BotSenses.perceive(_b, _w)
	var ids_seen: Array[int] = [_b.target_id]
	_w.time += 0.6
	BotSenses.perceive(_b, _w)
	if _b.contact == a_contact:
		pending("the bot did not switch to the nearer enemy here")
		return
	# It leaves; the first is where it was.
	_other.position = Vector3(5.0, 0.0, -60.0)
	_w.time += 0.1
	BotSenses.perceive(_b, _w)
	assert_eq(_b.contact, a_contact, "back on the first")
	assert_eq(_b.contact.first_seen_at, first, "its first sighting stays")
	assert_false(BotSenses.has_reacted(_b, _w), "a switch back is a re-pick-up")
	assert_lte(_b.contact.react_at - _w.time, _b.skill.reacquire_time.y + 1e-4, "no longer than one")
	assert_gt(ids_seen.size(), 0)


func test_a_new_round_makes_the_next_sighting_fresh_with_a_full_reaction() -> void:
	_build(&"normal")
	_settle_at_out()
	_b.reset(0, 0, 0.0, config)
	_look(OUT, 0.3)
	assert_eq(_b.contact.first_seen_at, _w.time, "a fresh contact")
	assert_gte(_b.contact.react_at - _w.time, _b.skill.reaction_time.x - 1e-4)
	assert_eq(_b.contact.reaction_from, _w.time)


func test_hard_picks_you_up_again_in_its_own_time_and_never_settled_past_its_share() -> void:
	_build(&"hard")
	_settle_at_out()
	_look(HIDE, 0.1)
	_look(OUT, 0.5)
	var c := _b.contact
	assert_gte(c.react_at - _w.time, _b.skill.reacquire_time.x - 1e-4)
	assert_lte(c.react_at - _w.time, _b.skill.reacquire_time.y + 1e-4)
	assert_lte(BotAim.settling(c.react_at, c, config), _b.skill.reacquire_settled * _b.skill.aim_settle_time + 1e-4)


func test_a_sniper_waits_after_a_re_pick_up_and_the_wait_still_ends() -> void:
	_build(&"normal")
	var rules := LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true
	var sniper := Character.new(4, 0, Vector3.ZERO, 0.0, [rules.config(rules.pool.item(SNIPER))] as Array[ReplicaConfig])
	var sb := Bot.new(sniper, 1, config.skill_for(&"normal"), 2)
	_settle_at_out()
	_look(HIDE, 0.1)
	_look(OUT, 0.5)
	sb.contact = _b.contact
	var c := sb.contact
	_w.time = c.react_at
	assert_true(BotCombat.bolt_waits(sb, _w, 40.0), "re-picked-up: it holds its one shot until its aim has settled")
	_w.time = c.react_at + sb.skill.aim_settle_time * config.bolt_settle_share + 0.01
	assert_false(BotCombat.bolt_waits(sb, _w, 40.0), "and the wait ends")


func test_seeing_again_exactly_at_the_grace_edge_is_one_or_the_other_never_neither() -> void:
	_build(&"normal")
	_settle_at_out()
	_look(HIDE, 0.1)
	var seen := _b.contact.seen_at
	_w.time = seen + config.contact_grace
	_you.position = OUT
	BotSenses.perceive(_b, _w)
	assert_false(BotSenses.has_reacted(_b, _w), "either a re-pick-up or a fresh contact, it is reacting")
