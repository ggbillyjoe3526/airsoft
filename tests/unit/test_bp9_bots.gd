extends GutTest
## BP9, the bots: a bot dazzled in the middle of a burst stops the replica's burst too; how soon a bot notices the
## target it keeps is read from that target's range, not a nearer one's; a Spotted never overwrites fresher news a
## teammate has of someone else; and an order nobody is left to carry tells its giver so. On an open field,
## headless: you (team 0) with two bot teammates, two opponents nobody drives.

const DT := 1.0 / 60.0
const KILL_Y := -10.0
## Yaw that looks along +X.
const EAST := -PI * 0.5
const YOU := 0
const NEAR := 3
const FAR := 4
const SPOTS: Array[Vector3] = [Vector3(-30.0, 0.0, 20.0), Vector3(-32.0, 0.0, 23.0), Vector3(-28.0, 0.0, 23.0),
		Vector3(40.0, 0.0, -40.0), Vector3(42.0, 0.0, -40.0)]

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = null

var map: MapData = null
var nav: NavGrid = null
var state: GameState = null
var sim: Simulation = null
var bots: BotController = null
var commands: Array[PlayerCommand] = []
var cmd: PlayerCommand = null
var you: Character = null
var mates: Array[Bot] = []
var _nav: NavGrid = null


func before_each() -> void:
	config = BotConfig.load_default().duplicate() as BotConfig


static func _block(kind: StringName, center: Vector3, size: Vector3) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = kind
	b.center = center
	b.size = size
	return b


## You and two bot teammates at SPOTS, two opponents far off (still, driven by nobody), round 1 live.
func _squad() -> void:
	map = MapData.new()
	map.id = "open field"
	map.kill_y = KILL_Y
	var w := BoxWorld.new(tuning.body)
	w.add_floor(100.0, 100.0)
	map.blocks.append(_block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(100.0, 0.5, 100.0)))
	for e in 2:
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(SPOTS[i] if e == 0 else SPOTS[3] + Vector3(2.0 * i, 0.0, 0.0), EAST))
		end.dead_zone.append(SpawnPoint.new(Vector3(-45.0, 0.0, 45.0) if e == 0 else Vector3(45.0, 0.0, -45.0), 0.0))
		map.ends.append(end)
	if _nav == null:
		_nav = NavGrid.build(map, tuning.nav, tuning.body)
	nav = _nav
	sim = Simulation.new(tuning, w, w.mover(), map.ends, KILL_Y)
	sim.nav = nav
	state = GameState.new(5, tuning)
	var loadout := ReplicaStats.default_loadout()
	commands.clear()
	for i in SPOTS.size():
		state.characters.append(Character.new(i, 0 if i < 3 else 1, SPOTS[i], EAST, loadout))
		commands.append(PlayerCommand.new())
	bots = BotController.new(state, YOU, map, nav, w, tuning, config)
	sim.start_match(state)
	state.cheats.bots_hold_fire = true
	bots.observe(state)
	# Nobody drives the opponents: they stand where a test puts them.
	for i in range(bots.world.bots.size() - 1, -1, -1):
		if bots.world.bots[i].character.team == 1:
			bots.world.bots.remove_at(i)
	for i in SPOTS.size():
		state.characters[i].position = SPOTS[i]
	you = state.characters[YOU]
	cmd = commands[YOU]
	cmd.reset(EAST, 0.0)
	mates.clear()
	for b in bots.world.bots:
		if b.character.team == 0:
			mates.append(b)
	_run(0.5)


func _tick() -> void:
	bots.think(state, commands, DT)
	sim.step(state, commands, DT)
	bots.observe(state)


func _run(seconds: float) -> void:
	for t in roundi(seconds / DT):
		_tick()


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- dazzled in the middle of a burst ---

func test_a_bot_dazzled_mid_burst_stops_the_replicas_burst() -> void:
	_squad()
	var b := mates[0]
	var out := PlayerCommand.new()
	b.bursting = true
	b.burst_left = 0.4
	b.character.dazzle_left = 1.0
	BotBrain.think(b, bots.world, out, DT)
	assert_true(out.stop_burst, "the burst's BBs left would fly blind: it is stopped")
	assert_false(out.fire, "and nothing more is fired")
	assert_true(out.crouch, "it ducks where it stands")
	assert_false(b.bursting)
	# The sim's side of it (a burst under way ends on the tick the stop arrives) is test_fv1_burst_fov's.


# --- how soon the target it keeps is noticed ---

func test_the_kept_targets_notice_delay_is_read_from_its_own_range() -> void:
	_squad()
	var w := bots.world
	var b := mates[0]
	var me := b.character
	var near := state.characters[NEAR]
	var far := state.characters[FAR]
	# Both straight in its view, the nearer one inside the margin that keeps it on the one it has.
	config.target_switch_margin = 25.0
	me.position = Vector3(-30.0, 0.0, 0.0)
	me.yaw = EAST
	b.aim_yaw = EAST
	near.position = me.position + Vector3(10.0, 0.0, 1.5)
	far.position = me.position + Vector3(30.0, 0.0, -1.5)
	# One fixed reaction, whether or not it reads as pre-aimed, so the notice's share is what is left.
	b.skill = b.skill.duplicate() as BotSkill
	b.skill.reaction_time = Vector2(0.3, 0.3)
	b.skill.pre_aim_reaction_time = Vector2(0.3, 0.3)
	b.target_id = far.id
	b.contacts.clear()
	b.contact = null
	BotSenses.perceive(b, w)
	assert_true(b.target_visible)
	assert_eq(b.target_id, far.id, "it stays on the one it had")
	var d_far := _flat(me.position, far.position)
	var d_near := _flat(me.position, near.position)
	var own := BotSenses.notice_time(me, far, d_far, config)
	var wrong := BotSenses.notice_time(me, far, d_near, config)
	assert_gt(own - wrong, 0.02, "the two ranges give delays far enough apart to tell")
	assert_almost_eq(b.contact.react_at - w.time - 0.3, own, 1e-4, "noticed as someone 30 m off, not 10 m")


# --- Spotted and a teammate's own news ---

func test_a_spotted_leaves_a_teammates_fresher_news_of_someone_else_alone() -> void:
	_squad()
	var w := bots.world
	var a := mates[0]
	var b := mates[1]
	var near := state.characters[NEAR]
	var far := state.characters[FAR]
	near.position = Vector3(-10.0, 0.0, 20.0)
	far.position = Vector3(-12.0, 0.0, 30.0)
	var radius := tuning.pings.spot_share_radius
	a.character.position = near.position + Vector3(-radius * 0.5, 0.0, 0.0)
	b.character.position = near.position + Vector3(-radius * 0.5, 0.0, 2.0)
	var own := Vector3(-11.0, 0.0, 29.0)
	for m: Bot in [a, b]:
		m.mode = Bot.Mode.ADVANCE
		m.target_visible = false
		m.target_id = far.id
		m.contacts.clear()
		m.contact = BotSenses._contact_for(m, far.id)
		m.has_last_known = true
		m.last_known = own
	# a saw the far one half a second ago; b's sighting is older than the time its own news counts for.
	a.contact.seen_at = w.time - 0.5
	b.contact.seen_at = w.time - config.hearing_contact_time - 1.0
	Spots.share(w, near, 0, radius)
	assert_eq(a.last_known, own, "the one it just ducked from stays in mind, not the one spotted elsewhere")
	assert_eq(b.last_known, near.position, "older news gives way to the spot")
	assert_almost_eq(b.heard_at, w.time, 1e-6)
	# Its own news of the one who is spotted is brought up to date by the spot.
	a.target_id = near.id
	a.contact = BotSenses._contact_for(a, near.id)
	a.contact.seen_at = w.time - 0.5
	a.last_known = own
	Spots.share(w, near, 0, radius)
	assert_eq(a.last_known, near.position, "the same one: where they are now")
	# And every share after the first still moves a spot it took: a spot is heard, not seen.
	b.last_known = own
	Spots.share(w, near, 0, radius)
	assert_eq(b.last_known, near.position, "told again each spot_share_gap")


# --- an order nobody is left to carry ---

func test_cover_me_whose_helper_is_hit_tells_you_it_is_over() -> void:
	_squad()
	cmd.squad_order = SquadOrder.Kind.COVER
	_tick()
	cmd.squad_order = SquadOrder.Kind.NONE
	assert_eq(bots.orders.order_of(YOU), SquadOrder.Kind.COVER)
	var helper: Bot = null
	for m in mates:
		if m.order == SquadOrder.Kind.COVER:
			helper = m
	assert_not_null(helper, "one teammate covers you")
	var before := bots.order_outcome.serial
	Elimination.eliminate(helper.character, NEAR, state.characters, sim.ends)
	_run(0.1)
	assert_eq(bots.orders.order_of(YOU), SquadOrder.Kind.NONE, "nobody carries it: over")
	assert_gt(bots.order_outcome.serial, before, "and you are told")
	assert_eq(bots.order_outcome.giver, YOU)
	assert_eq(bots.order_outcome.notice, SquadOrders.Notice.CANCELLED, "as when you walk away from it")
	assert_true(bots.order_outcome.news, "unasked: the HUD says nothing of it (owner, 2026-11-17)")
	# Told once, not every tick after.
	var told := bots.order_outcome.serial
	_run(0.5)
	assert_eq(bots.order_outcome.serial, told)


func test_walking_away_from_cover_me_is_news_and_an_orders_own_answer_is_not() -> void:
	_squad()
	cmd.squad_order = SquadOrder.Kind.COVER
	_tick()
	assert_false(bots.order_outcome.news, "the answer to an order just given")
	cmd.squad_order = SquadOrder.Kind.NONE
	var before := bots.order_outcome.serial
	you.position += Vector3(config.squad.cover_leave + 5.0, 0.0, 0.0)
	_run(0.1)
	assert_gt(bots.order_outcome.serial, before)
	assert_eq(bots.order_outcome.notice, SquadOrders.Notice.CANCELLED)
	assert_true(bots.order_outcome.news, "you walked away from it: unasked, so not told")
	# Given again to cancel it: your own doing, so its answer is no news.
	cmd.squad_order = SquadOrder.Kind.FOLLOW
	_tick()
	cmd.squad_order = SquadOrder.Kind.FOLLOW
	_tick()
	cmd.squad_order = SquadOrder.Kind.NONE
	assert_eq(bots.order_outcome.notice, SquadOrders.Notice.CANCELLED, "Follow Me given twice: off again")
	assert_false(bots.order_outcome.news)


func test_an_order_ended_by_the_new_round_tells_nobody() -> void:
	_squad()
	cmd.squad_order = SquadOrder.Kind.FOLLOW
	_tick()
	cmd.squad_order = SquadOrder.Kind.NONE
	assert_eq(bots.orders.order_of(YOU), SquadOrder.Kind.FOLLOW)
	var before := bots.order_outcome.serial
	bots.orders.clear()
	bots.orders.update()
	assert_eq(bots.orders.order_of(YOU), SquadOrder.Kind.NONE)
	assert_eq(bots.order_outcome.serial, before, "a round's start clears the book without a notice")
