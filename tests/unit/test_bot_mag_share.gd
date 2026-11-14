extends GutTest
## The bots' side of the magazine hand-off (MH2; the browser game's ai/magShare.test.ts and ai/magShareRules.test.ts,
## MG1): a bot low on BBs presses to ask through its command, a bot asked comes over and presses to toss it, a bot that
## asked you walks up and waits for your press, what comes first in a bot, the calls, Bot intentions and Dev settings ›
## Bots run low on BBs (game/ai/bot_mag_share.gd, bot_brain.gd, bot_controller.gd, callouts.gd, game/sim/dev_cheats.gd).
## On an open field, headless: you (character 0, team 0, not a bot unless a test says) with two bot teammates (1 and 2),
## and one opponent (3) far off that nobody drives. Default loadout: an AEG rifle (three spares of 60) and a GBB pistol
## (three of 18).

const DT := 1.0 / 60.0
const KILL_Y := -10.0
const EAST := -PI * 0.5
const YOU := 0
const ORANGE := 3
const FAR_ORANGE := Vector3(40.0, 0.0, -40.0)
## You out of every ask's reach, for the bot-only cases.
const YOU_AWAY := Vector3(-45.0, 0.0, -45.0)

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var rules: MagShareConfig = tuning.mag_share

var map: MapData = null
var nav: NavGrid = null
var state: GameState = null
var sim: Simulation = null
var bots: BotController = null
var commands: Array[PlayerCommand] = []
var you: Character = null
## Every event of the ticks run since the squad was made, by kind (GameEvent.Kind): how many, and the last of each.
var counts: Dictionary[int, int] = {}
var tosses: Array[Vector2i] = []
var catches: Array[Vector2i] = []
var _navs: Dictionary[String, NavGrid] = {}


## The open field, with a wall (centre, size) for each pair in `walls`.
func _field(walls: Array) -> MapData:
	var m := MapData.new()
	m.id = "open field"
	m.kill_y = KILL_Y
	var floor_block := MapData.Block.new()
	floor_block.kind = &"floor"
	floor_block.center = Vector3(0.0, -0.25, 0.0)
	floor_block.size = Vector3(100.0, 0.5, 100.0)
	m.blocks.append(floor_block)
	for pair: Array in walls:
		var wall := MapData.Block.new()
		wall.kind = &"wall"
		wall.center = pair[0]
		wall.size = pair[1]
		m.blocks.append(wall)
	for e in 2:
		var end := MapEnd.new()
		for i in 2:
			end.spawns.append(SpawnPoint.new(Vector3(-30.0 + 2.0 * i, 0.0, 20.0) if e == 0
					else FAR_ORANGE + Vector3(2.0 * i, 0.0, 0.0), EAST))
		end.dead_zone.append(SpawnPoint.new(Vector3(-45.0, 0.0, 45.0) if e == 0 else Vector3(45.0, 0.0, -45.0), 0.0))
		m.ends.append(end)
	return m


## Characters at `at` (you first; teams 0, 0, 0, 1 unless `teams` says), round 1 live and half a second gone, the bots
## holding their fire. With
## `player` -1 every character is a bot; the opponent is driven by nobody unless `enemy_bot`. `level` both teams';
## `walls` as _field.
func _squad(at: Array[Vector3], level: StringName = &"normal", teams: Array[int] = [0, 0, 0, 1], player: int = YOU,
		enemy_bot: bool = false, walls: Array = []) -> void:
	map = _field(walls)
	var w := BoxWorld.new(tuning.body)
	w.add_floor(100.0, 100.0)
	for pair: Array in walls:
		w.add_box(pair[0], pair[1])
	var layout := str(walls)
	if not _navs.has(layout):
		_navs[layout] = NavGrid.build(map, tuning.nav, tuning.body)
	nav = _navs[layout]
	sim = Simulation.new(tuning, w, w.mover(), map.ends, KILL_Y)
	sim.nav = nav
	state = GameState.new(5, tuning)
	var loadout := ReplicaStats.default_loadout()
	commands.clear()
	for i in at.size():
		state.characters.append(Character.new(i, teams[i], at[i], EAST, loadout))
		commands.append(PlayerCommand.new())
	var levels: Dictionary[int, StringName] = {0: level, 1: level}
	bots = BotController.new(state, player, map, nav, w, tuning, config, levels)
	sim.start_match(state)
	bots.observe(state)
	if not enemy_bot:
		for b in bots.world.bots:
			if b.character.id == ORANGE:
				bots.world.bots.erase(b)
				break
	for i in at.size():
		state.characters[i].position = at[i]
	# Nobody's BB ends the round under a test (a bot hunting its way to the opponent would): the hand-off alone.
	state.cheats.bots_hold_fire = true
	you = state.characters[YOU]
	commands[YOU].reset(EAST, 0.0)
	counts.clear()
	tosses.clear()
	catches.clear()
	_run(0.5)


func _tick() -> void:
	bots.think(state, commands, DT)
	sim.step(state, commands, DT)
	bots.observe(state)
	for i in state.events.count:
		var e := state.events.items[i]
		counts[e.kind] = counts.get(e.kind, 0) + 1
		if e.kind == GameEvent.Kind.MAG_TOSS:
			tosses.append(Vector2i(e.actor, e.target))
		elif e.kind == GameEvent.Kind.MAG_CATCH:
			catches.append(Vector2i(e.actor, e.target))
	# Your command stays as you left it but for the one-shot press.
	commands[YOU].mag_hand_off = false


func _run(seconds: float) -> void:
	for t in roundi(seconds / DT):
		_tick()


## Runs until a magazine is caught, for at most `seconds`; whether one was.
func _run_to_catch(seconds: float) -> bool:
	var before := catches.size()
	for t in roundi(seconds / DT):
		_tick()
		if catches.size() > before:
			return true
	return false


func _count(kind: GameEvent.Kind) -> int:
	return counts.get(kind, 0)


func _bot(id: int) -> Bot:
	for b in bots.world.bots:
		if b.character.id == id:
			return b
	return null


## You press the hand-off this tick.
func _press() -> void:
	commands[YOU].mag_hand_off = true
	_tick()


## `c` on its last magazine for `slot`.
static func _empty(c: Character, slot: int = 0) -> void:
	c.armament.ammo[slot].pouch.fill(0)


## `c` holds `n` full spares for `slot`, nothing else.
static func _spares(c: Character, n: int, slot: int = 0) -> void:
	var pouch := c.armament.ammo[slot].pouch
	pouch.fill(0)
	for i in mini(n, pouch.size()):
		pouch[i] = c.armament.replicas[slot].mag_size


## Every BB team 0 carries for `slot`, loaded and spare.
func _total(slot: int = 0) -> int:
	var n := 0
	for c in state.characters:
		if c.team == 0:
			n += c.armament.ammo[slot].mag + c.armament.ammo[slot].spare_bbs()
	return n


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Who is chosen to bring one (magShareRules.test.ts) ---

func test_a_low_bot_asks_the_nearest_teammate_with_one_to_spare_skipping_one_asking_itself() -> void:
	_squad([Vector3(-40.0, 0.0, 20.0), Vector3(-30.0, 0.0, 20.0), Vector3(-25.0, 0.0, 20.0), FAR_ORANGE])
	var near := state.characters[2]
	near.mag.asked = YOU
	near.mag.asked_at = state.time
	_empty(state.characters[1])
	_run(0.1)
	assert_eq(state.characters[1].mag.asked, YOU, "bot 2, asking itself, is passed over for you, the next nearest")
	assert_eq(_count(GameEvent.Kind.MAG_ASK), 1, "one ask, pressed through the bot's command")


func test_a_bot_asked_while_bringing_one_brings_that_first_then_the_next() -> void:
	# The browser's asker went to the next nearest; here the simulation asks the nearest, and with nobody else to pass
	# it to the giver serves its asks in turn (the second stands meanwhile; with someone else it is passed on, AUD2).
	_squad([Vector3(-40.0, 0.0, 20.0), Vector3(-20.0, 0.0, 20.0), Vector3(-30.0, 0.0, 20.0), FAR_ORANGE])
	var giver := _bot(2)
	_empty(you)
	_press()
	assert_eq(giver.mag_for, null, "the job is taken before the bots next think")
	_tick()
	assert_eq(giver.mag_for, you, "the nearest with one to spare brings you yours")
	_empty(state.characters[1])
	_run(0.1)
	assert_eq(state.characters[1].mag.asked, 2, "you are asking, so bot 1 asks bot 2")
	assert_eq(giver.mag_for, you, "still bringing yours")
	assert_true(_run_to_catch(10.0), "yours lands")
	assert_true(_run_to_catch(10.0), "then bot 1's")
	assert_eq(catches, [Vector2i(2, YOU), Vector2i(2, 1)] as Array[Vector2i])


func test_a_bot_off_to_the_pole_brings_none_until_it_isnt() -> void:
	_squad([YOU_AWAY, Vector3(-30.0, 0.0, 20.0), Vector3(-24.0, 0.0, 20.0), FAR_ORANGE])
	state.round_state.mode = RoundState.Mode.ATTACK_DEFEND
	state.round_state.attackers = 0
	var giver := _bot(2)
	var asker := _bot(1)
	giver.lane_done = true # an attacker that has swept its lane goes to the pole
	_empty(asker.character)
	_run(0.2)
	assert_eq(_count(GameEvent.Kind.MAG_ASK), 1, "the simulation asked the nearest")
	assert_eq(giver.mag_for, null, "off to the pole, it doesn't come")
	# AUD2: it turns the ask down at once (before, it stood its 15 s unanswered); with nobody else in reach it ends.
	assert_eq(asker.character.mag.asked, -1, "turned down, and nobody else to pass it to")
	assert_ne(asker.mode, Bot.Mode.MAG, "and the asker doesn't wait for it")
	giver.lane_done = false
	# Asked again (its gaps skipped here) as the giver is free of the pole's pull.
	asker.character.mag.asked = 2
	asker.character.mag.asked_at = state.time
	_tick()
	var asked_again := giver.mag_for == asker.character
	assert_true(asked_again, "back from the pole's pull, it takes the next ask")
	_tick()
	assert_eq(asker.mode, Bot.Mode.MAG)


func test_with_nobody_to_ask_a_bot_presses_nothing_and_looks_again_after_the_bot_gap() -> void:
	# Bot 2 is out of play, you are beyond the ask's reach, and the opponent is near but no teammate.
	_squad([Vector3(-30.0, 0.0, 20.0 + rules.ask_range + 5.0), Vector3(-30.0, 0.0, 20.0), Vector3(-25.0, 0.0, 20.0),
			Vector3(-22.0, 0.0, 28.0)])
	state.characters[2].status = Character.Status.CALLING
	var asker := _bot(1)
	_empty(asker.character)
	var start := state.time
	_run(1.0)
	assert_eq(_count(GameEvent.Kind.MAG_ASK), 0)
	assert_eq(_count(GameEvent.Kind.MAG_REFUSED), 0, "no press the simulation would refuse")
	assert_almost_eq(asker.mag_press_at, start + DT + rules.bot_ask_gap, 0.05, "it looks again after the bot's gap")


func test_a_bot_that_isnt_low_or_on_the_range_presses_nothing() -> void:
	_squad([YOU_AWAY, Vector3(-30.0, 0.0, 20.0), Vector3(-25.0, 0.0, 20.0), FAR_ORANGE])
	_run(1.0)
	_empty(you) # you are low, but nobody presses for you
	_run(1.0)
	assert_eq(_count(GameEvent.Kind.MAG_ASK) + _count(GameEvent.Kind.MAG_REFUSED), 0, "not low: no press")
	state.round_state.practice = true
	_empty(state.characters[1])
	_run(1.0)
	assert_eq(_count(GameEvent.Kind.MAG_ASK) + _count(GameEvent.Kind.MAG_REFUSED), 0, "on the range: no press")


# --- What the giver keeps and what the asker gets ---

func test_a_giver_with_one_full_spare_of_its_primary_keeps_it_with_two_it_gives_one() -> void:
	_squad([YOU_AWAY, Vector3(-30.0, 0.0, 20.0), Vector3(-25.0, 0.0, 20.0), FAR_ORANGE])
	_spares(state.characters[2], 1)
	_empty(state.characters[1])
	_run(0.2)
	assert_eq(_count(GameEvent.Kind.MAG_ASK), 0, "nobody to ask")
	_bot(1).mag_press_at = -INF
	_spares(state.characters[2], 2)
	_run(0.2)
	assert_eq(state.characters[1].mag.asked, 2)
	assert_true(_run_to_catch(8.0))
	assert_eq(state.characters[2].armament.ammo[0].spare_bbs(), state.characters[2].armament.replicas[0].mag_size,
			"the giver kept one full spare")


func test_bots_ask_only_for_their_primary_and_give_an_unused_pistols_freely() -> void:
	_squad([YOU_AWAY, Vector3(-30.0, 0.0, 20.0), Vector3(-25.0, 0.0, 20.0), FAR_ORANGE])
	_empty(state.characters[1], 1)
	_run(1.0)
	assert_eq(_count(GameEvent.Kind.MAG_ASK), 0, "its pistol empty, its rifle full: no ask")
	# You, holding your pistol, ask; the bot has rifle spares but one pistol spare, which it isn't fighting with.
	_squad([Vector3(-30.0, 0.0, 20.0), Vector3(-20.0, 0.0, 20.0), Vector3(10.0, 0.0, 45.0), FAR_ORANGE])
	you.armament.active = 1
	commands[YOU].switch_to = 1
	_empty(you, 1)
	_spares(state.characters[1], 1, 1)
	var before := _total(1)
	_press()
	assert_eq(you.mag.asked, 1)
	assert_true(_run_to_catch(8.0), "the pistol magazine comes")
	assert_eq(_total(1), before, "no BB made")
	assert_eq(state.characters[1].armament.ammo[1].spare_bbs(), 0, "its only pistol spare went")


# --- The same at every level, both teams alike ---

func test_at_every_level_and_on_both_teams_a_low_bot_asks_and_the_nearest_brings_it() -> void:
	for level_name in MatchOptions.BOT_LEVELS:
		var level := StringName(level_name)
		for team in 2:
			_squad([Vector3(-30.0, 0.0, 20.0), Vector3(-24.0, 0.0, 20.0), Vector3(-18.0, 0.0, 20.0), FAR_ORANGE], level,
					[team, team, team, 1 - team], -1)
			var at := "%s, team %d" % [level, team]
			var asker := state.characters[0]
			var near := _bot(1)
			_empty(asker)
			_run(0.1)
			assert_eq(asker.mag.asked, 1, "%s: asks the nearest" % at)
			assert_true(near.mag_for == asker or tosses == [Vector2i(1, 0)], "%s: which takes the job" % at)
			assert_eq(_bot(2).mag_for, null, at)
			assert_true(_run_to_catch(8.0), "%s: it lands" % at)
			assert_eq(near.mag_for, null, "%s: the job is done" % at)
			assert_lt(asker.mag.asked, 0, "%s: the ask ends" % at)
			assert_almost_eq(asker.mag.next_ask, state.time + rules.bot_ask_gap, DT * 2.0, "%s: then its gap" % at)
			assert_false(MagShare.low_on(asker.armament, rules.low_mags), at)


# --- On the field (magShare.test.ts) ---

func test_a_bot_asks_you_walks_up_to_you_and_waits_and_your_press_tosses_it() -> void:
	_squad([Vector3(-30.0, 0.0, 20.0), Vector3(-18.0, 0.0, 20.0), Vector3(10.0, 0.0, 45.0), FAR_ORANGE])
	var asker := _bot(1)
	_empty(asker.character)
	var before := _total()
	_run(0.1)
	assert_eq(asker.character.mag.asked, YOU, "you are the nearest with one to spare")
	assert_eq(asker.mode, Bot.Mode.MAG)
	assert_eq(bots.intent_of(1), Bot.Mode.size(), "Bot intentions: waiting for a mag")
	_run(6.0)
	assert_lt(_flat(asker.character.position, you.position), config.mag_walk_up_to + 0.5, "it walked up to you")
	assert_eq(_count(GameEvent.Kind.MAG_TOSS), 0, "and waits")
	_press()
	assert_true(_run_to_catch(1.0))
	assert_eq(tosses, [Vector2i(YOU, 1)] as Array[Vector2i])
	assert_lt(asker.character.mag.asked, 0)
	assert_false(MagShare.low_on(asker.character.armament, rules.low_mags))
	assert_eq(_total(), before, "no BB made")


func test_a_bot_asks_a_bot_which_comes_sprinting_then_running_and_tosses_while_the_asker_stays_put() -> void:
	_squad([Vector3(-30.0, 0.0, 20.0), Vector3(0.0, 0.0, 20.0), Vector3(0.0, 0.0, 35.0), FAR_ORANGE])
	var asker := _bot(1)
	var giver := _bot(2)
	_empty(asker.character)
	_run(0.1)
	assert_eq(asker.character.mag.asked, 2)
	assert_eq(giver.mag_for, asker.character)
	assert_eq(giver.mode, Bot.Mode.MAG)
	assert_eq(bots.intent_of(2), Bot.Mode.MAG, "Bot intentions: bringing a mag")
	var at := asker.character.position
	var sprinted_far := false
	var sprinted_near := false
	for i in roundi(8.0 / DT):
		var d := _flat(giver.character.position, asker.character.position)
		_tick()
		if giver.character.sprinting:
			if d > config.mag_hurry_distance + 0.5:
				sprinted_far = true
			elif d < config.mag_hurry_distance - 0.5:
				sprinted_near = true
		if not tosses.is_empty():
			break
	assert_true(sprinted_far, "it sprints while far")
	assert_false(sprinted_near, "and runs the last metres")
	assert_lt(_flat(asker.character.position, at), 1.0, "the asker stayed put")
	assert_true(_run_to_catch(1.0))
	assert_eq(tosses, [Vector2i(2, 1)] as Array[Vector2i])
	assert_eq(giver.mag_for, null)
	assert_eq(giver.character.armament.ammo[0].spare_bbs(), giver.character.armament.replicas[0].mag_size * 2,
			"it gave one of its three and kept two")


func test_a_wall_between_doesnt_stop_the_giver_on_its_far_side() -> void:
	# A wall 6 m long between the asker and the giver, 2.5 m apart through it: the giver goes round to toss.
	var wall: Array = [[Vector3(-20.0, 1.5, 20.0), Vector3(0.4, 3.0, 6.0)]]
	_squad([YOU_AWAY, Vector3(-21.25, 0.0, 20.0), Vector3(-18.75, 0.0, 20.0), FAR_ORANGE], &"normal", [0, 0, 0, 1],
			YOU, false, wall)
	var giver := _bot(2)
	_empty(state.characters[1])
	_run(0.1)
	assert_eq(giver.mag_for, state.characters[1])
	assert_true(_run_to_catch(10.0), "it walks round the wall and tosses")
	assert_eq(tosses, [Vector2i(2, 1)] as Array[Vector2i])


## Something at eye height only (a lintel, a beam) across z = BEAM_Z, between BEAM_LOW and BEAM_HIGH (m): it blocks
## a giver's eye-to-chest line over 2 m but not a line from a little lower down (the throw point).
class EyeBeam:
	extends WorldQuery
	const BEAM_Z := -0.5
	const BEAM_LOW := 1.4
	const BEAM_HIGH := 1.6

	func ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
		if (from.z - BEAM_Z) * (to.z - BEAM_Z) > 0.0:
			return false
		var t := (BEAM_Z - from.z) / (to.z - from.z)
		var y := lerpf(from.y, to.y, t)
		if y < BEAM_LOW or y > BEAM_HIGH:
			return false
		hit.fraction = t
		return true


## A bot's world with nothing but the eye-height beam, `a` and `b` 2 m apart across it (team 0), and `bot_id`'s bot.
func _beam_world(bot_id: int) -> BotWorld:
	var q := EyeBeam.new()
	var loadout := ReplicaStats.default_loadout()
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = config
	w.query = q
	w.mag_share = MagShare.new(tuning, q)
	for i in 2:
		var c := Character.new(i, 0, Vector3.ZERO, 0.0 if i == 0 else PI, loadout)
		c.respawn()
		c.position = Vector3(0.0, 0.0, -2.0 * i)
		w.characters.append(c)
	w.bots = [Bot.new(w.characters[bot_id], 1, config.skill, 2)] as Array[Bot]
	return w


func test_a_giver_whose_toss_is_blocked_at_eye_height_walks_up_rather_than_parking_where_it_cant_toss() -> void:
	var w := _beam_world(0)
	var giver := w.characters[0]
	var asker := w.characters[1]
	_empty(asker)
	asker.mag.asked = giver.id
	var b := w.bots[0]
	b.mag_for = asker
	var pick := MagShare.SparePick.new()
	assert_true(w.mag_share.has_mag_for(giver, asker))
	assert_false(w.mag_share.can_toss_to(giver, asker, pick), "the beam blocks the toss's eye-to-chest line")
	assert_false(w.mag_share.toss_line_clear(giver, asker))
	assert_lt(_flat(giver.position, asker.position), config.mag_walk_up_to, "already inside the usual stop")
	var cmd := PlayerCommand.new()
	BotMagShare.move(b, w, cmd, DT)
	assert_false(cmd.mag_hand_off)
	assert_eq(b.route_state, Bot.RouteState.WANTED, "it keeps walking up instead of standing")
	assert_eq(b.route_goal, asker.position)


func test_a_bot_waiting_on_your_toss_blocked_at_eye_height_walks_up_to_you() -> void:
	var w := _beam_world(1)
	var asker := w.characters[1]
	asker.mag.asked = YOU
	var b := w.bots[0]
	assert_false(w.mag_share.toss_line_clear(w.characters[YOU], asker))
	BotMagShare.move(b, w, PlayerCommand.new(), DT)
	assert_eq(b.route_state, Bot.RouteState.WANTED, "it walks up to you instead of waiting where you can't toss")
	assert_eq(b.route_goal, w.characters[YOU].position)


func test_an_ask_you_never_answer_lapses_and_it_asks_again_no_sooner_than_the_gap() -> void:
	_squad([Vector3(-30.0, 0.0, 20.0), Vector3(-27.0, 0.0, 20.0), Vector3(10.0, 0.0, 45.0), FAR_ORANGE])
	var asker := _bot(1)
	_empty(asker.character)
	_run(0.1)
	var first := asker.character.mag.asked_at
	assert_eq(asker.character.mag.asked, YOU)
	_run(rules.ask_time + 0.2)
	assert_lt(asker.character.mag.asked, 0, "lapsed")
	assert_eq(_count(GameEvent.Kind.MAG_TOSS), 0)
	assert_almost_eq(asker.character.mag.next_ask, first + rules.ask_time + rules.bot_ask_gap, 0.1)
	_run(rules.bot_ask_gap - 1.0)
	assert_lt(asker.character.mag.asked, 0, "no new ask inside the gap")
	assert_eq(_count(GameEvent.Kind.MAG_ASK), 1)
	assert_eq(_count(GameEvent.Kind.MAG_REFUSED), 0, "and no press refused all the while")
	_run(1.5)
	assert_eq(_count(GameEvent.Kind.MAG_ASK), 2, "asks again once the gap is over")


func test_at_every_level_a_bot_teammate_brings_your_ask() -> void:
	for level_name in MatchOptions.BOT_LEVELS:
		var level := StringName(level_name)
		_squad([Vector3(-30.0, 0.0, 20.0), Vector3(-18.0, 0.0, 20.0), Vector3(-30.0, 0.0, 45.0), FAR_ORANGE], level)
		_empty(you)
		var before := _total()
		_press()
		_tick()
		assert_eq(_bot(1).mag_for, you, "%s: the nearest takes your ask" % level)
		assert_true(_run_to_catch(8.0), level)
		assert_eq(tosses, [Vector2i(1, YOU)] as Array[Vector2i], level)
		assert_eq(_total(), before, level)
		assert_false(MagShare.low_on(you.armament, rules.low_mags), level)


# --- What comes first in a bot ---

func test_bringing_one_comes_before_a_squad_order_and_waiting_for_one_after_it() -> void:
	_squad([Vector3(-30.0, 0.0, 20.0), Vector3(-18.0, 0.0, 20.0), Vector3(10.0, 0.0, 45.0), FAR_ORANGE])
	bots.give_order(you, SquadOrder.Kind.HOLD)
	var giver := _bot(1)
	assert_eq(giver.order, SquadOrder.Kind.HOLD)
	_empty(you)
	_press()
	_run(0.1)
	assert_eq(giver.mode, Bot.Mode.MAG, "bringing one comes first")
	assert_eq(giver.order, SquadOrder.Kind.HOLD, "the order stands for afterwards")
	_squad([Vector3(-30.0, 0.0, 20.0), Vector3(-18.0, 0.0, 20.0), Vector3(-8.0, 0.0, 20.0), FAR_ORANGE])
	bots.give_order(you, SquadOrder.Kind.HOLD)
	var asker := _bot(2)
	_empty(asker.character)
	_run(0.2)
	assert_eq(asker.character.mag.asked, 1, "it asks under the order")
	assert_eq(asker.mode, Bot.Mode.ORDER, "and carries on with the order")


func test_a_fight_comes_first() -> void:
	_squad([Vector3(-30.0, 0.0, 20.0), Vector3(-18.0, 0.0, 20.0), Vector3(-30.0, 0.0, 45.0), Vector3(-18.0, 0.0, 10.0)])
	var giver := _bot(1)
	_empty(you)
	_press()
	_tick()
	assert_eq(giver.mag_for, you)
	_run(0.4)
	assert_eq(giver.mode, Bot.Mode.FIGHT, "in sight of an enemy it fights while the job waits")
	assert_eq(giver.mag_for, you, "the job still stands")


func test_a_bot_waiting_on_a_bot_giver_held_up_in_a_fight_waits_behind_cover() -> void:
	# BP7: before, it stood where it was (MAG mode) until the ask lapsed. Crouch cover by the asker to wait behind; the
	# giver's fight is set by hand (a threat it knows of to the east), and the asker's next choice is taken.
	var walls := [[Vector3(-28.5, 0.6, 20.0), Vector3(0.4, 1.2, 2.0)]]
	_squad([YOU_AWAY, Vector3(-30.0, 0.0, 20.0), Vector3(-18.0, 0.0, 20.0), FAR_ORANGE], &"normal", [0, 0, 0, 1], YOU,
			false, walls)
	var asker := _bot(1)
	var giver := _bot(2)
	_empty(asker.character)
	_run(0.1)
	assert_eq(asker.character.mag.asked, 2, "it asked the bot")
	assert_true(BotMagShare.waiting(asker, bots.world), "it waits for it")
	assert_null(BotMagShare.fighting_giver(asker, bots.world), "the giver is on its way")
	giver.mode = Bot.Mode.FIGHT
	giver.has_last_known = true
	giver.last_known = Vector3(-6.0, 0.0, 20.0)
	assert_eq(BotMagShare.fighting_giver(asker, bots.world), giver, "held up in a fight")
	asker.cover_cooldown = 0.0
	BotBrain._choose_mode(asker, bots.world, null, DT)
	assert_eq(asker.mode, Bot.Mode.COVER, "it waits behind cover meanwhile")
	var eye := giver.last_known + Vector3(0.0, tuning.body.stand_eye_height, 0.0)
	assert_true(BotCover.hides_from(asker.cover.position, eye, bots.world), "from what the giver fights")
	assert_eq(asker.character.mag.asked, 2, "its ask still stands")


# --- The calls (callouts.md: Need a mag, Mag coming, Thanks for the mag) ---

func test_the_ask_the_answer_and_the_thanks_are_called() -> void:
	# The giver 25 m off: the catch comes after the asker's own gap since its ask (Pace).
	_squad([Vector3(-30.0, 0.0, 20.0), Vector3(0.0, 0.0, 20.0), Vector3(0.0, 0.0, 45.0), FAR_ORANGE])
	bots.callouts = Callouts.new(_file_with_thanks(1.0), config.callouts, map.areas, 5)
	_empty(state.characters[1])
	assert_true(_run_to_catch(8.0))
	_run(3.0)
	var said := _said()
	assert_true(said.has(Vector2i(1, CalloutsFile.Event.NEED_MAG)), "the asker says Need a mag")
	assert_true(said.has(Vector2i(2, CalloutsFile.Event.MAG_COMING)), "the giver says Mag coming")
	assert_true(said.has(Vector2i(1, CalloutsFile.Event.MAG_THANKS)), "the catcher says thanks")


func test_no_thanks_for_a_catch_with_no_bbs_in_it() -> void:
	_squad([Vector3(-30.0, 0.0, 20.0), Vector3(0.0, 0.0, 20.0), Vector3(0.0, 0.0, 35.0), FAR_ORANGE])
	bots.callouts = Callouts.new(_file_with_thanks(1.0), config.callouts, map.areas, 5)
	state.events.clear()
	var e := state.events.add(GameEvent.Kind.MAG_CATCH)
	e.actor = 2
	e.target = 1
	e.value = 0
	bots.callouts.observe(state, bots.world)
	_run(3.0)
	assert_false(_said().has(Vector2i(1, CalloutsFile.Event.MAG_THANKS)), "nothing caught, nothing to thank")


## Every call said so far as (speaker id, event).
func _said() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var log := bots.callouts.said
	for serial in range(maxi(0, log.total - log.capacity()), log.total):
		var entry := log.entry(serial)
		if entry != null:
			out.append(Vector2i(entry.speaker_id, entry.event))
	return out


## callouts.md as shipped, but Thanks for the mag called with `chance` and no team gap.
static func _file_with_thanks(chance: float) -> CalloutsFile:
	var text := FileAccess.get_file_as_string(CalloutsFile.PATH)
	text = text.replace("| Thanks for the mag | 0.7 | 5 |", "| Thanks for the mag | %s | 0 |" % chance)
	return CalloutsFile.parse(text, BotsFile.shared().kinds)


# --- Dev settings › Bots run low on BBs ---

func test_bots_run_low_puts_one_bot_a_team_in_turn_on_its_last_magazine_a_while_into_the_round() -> void:
	_squad([Vector3(-30.0, 0.0, 20.0), Vector3(-18.0, 0.0, 20.0), Vector3(-30.0, 0.0, 45.0), FAR_ORANGE], &"normal",
			[0, 0, 0, 1], YOU, true)
	assert_eq(DevCheats.low_pick(state, 0, YOU), state.characters[1], "round 1: your first bot teammate")
	assert_eq(DevCheats.low_pick(state, 1, YOU), state.characters[ORANGE])
	state.round_state.number = 2
	assert_eq(DevCheats.low_pick(state, 0, YOU), state.characters[2], "round 2: the next")
	state.round_state.number = 1
	state.cheats.bots_run_low = true
	var c := state.characters[1]
	_run(config.mag_dev_low_after - 0.5 - 0.2)
	assert_false(MagShare.low_on(c.armament, rules.low_mags), "not yet")
	_run(0.4)
	assert_eq(_count(GameEvent.Kind.MAG_ASK), 1, "put low, it asks")
	assert_false(MagShare.low_on(state.characters[2].armament, rules.low_mags), "one a team")
	assert_ne(c.mag.asked, -1, "a teammate is asked")
	if c.mag.asked != YOU:
		assert_true(_run_to_catch(10.0), "and a bot brings it")
		assert_false(MagShare.low_on(c.armament, rules.low_mags))


func test_the_dev_setting_is_saved_and_keeps_the_match_off_the_record() -> void:
	var dev := DevSettings.new()
	dev.bots_run_low = true
	var back := DevSettings.new()
	back.from_dict(dev.to_dict())
	assert_true(back.bots_run_low)
	assert_true(back.cheats().bots_run_low)
	assert_true(back.cheats().any(), "a cheat: off the record")
	assert_false(DevSettings.new().cheats().any(), "off by default")
	assert_true(SettingsScreen.DEV_SWITCHES.has(&"bots_run_low"), "a Dev row")


# --- Cost ---

func test_a_tick_of_the_hand_off_makes_no_object() -> void:
	_squad([Vector3(-30.0, 0.0, 20.0), Vector3(0.0, 0.0, 20.0), Vector3(0.0, 0.0, 35.0), FAR_ORANGE])
	_empty(state.characters[1])
	_run(1.0)
	assert_eq(_bot(2).mode, Bot.Mode.MAG)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 30:
		BotMagShare.update(bots.world, true)
		BotMagShare.ask_when_low(_bot(1), bots.world, commands[1], true)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before, "update and the asker's check allocate nothing")
