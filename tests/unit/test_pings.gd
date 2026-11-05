extends GutTest
## Pings (PN1; the browser game's ai/pings.test.ts and matchSessionPings.test.ts, PG1): a press fills one tick's ping,
## the simulation turns it into a PING event and nothing more, the bots' controller makes it a spot or a contact in the
## ping book and the pinger's bot teammates take it as a noise heard there (game/sim/simulation.gd, game/ai/pings.gd,
## game/ai/bot_controller.gd); one teammate answers, and a teammate's Contact call may mark its enemy
## (game/ai/callouts.gd). On an open field, headless: you (team 0, not a bot) with two bot teammates, and one opponent
## standing still far off that nobody drives (unless a test says).

const DT := 1.0 / 60.0
const KILL_Y := -10.0
## Yaw that looks along +X.
const EAST := -PI * 0.5
const YOU := 0
const ORANGE := 3
const SPOTS: Array[Vector3] = [Vector3(-30.0, 0.0, 20.0), Vector3(-32.0, 0.0, 23.0), Vector3(-28.0, 0.0, 23.0),
		Vector3(40.0, 0.0, -40.0)]
## A thin wall across your view 10 m east of you, and one 30 m east (behind an enemy 20 m off, so the view always meets
## something): [centre, size].
const WALL: Array[Vector3] = [Vector3(-20.0, 1.5, 20.0), Vector3(0.4, 3.0, 8.0)]
const BACKSTOP: Array[Vector3] = [Vector3(0.0, 2.0, 20.0), Vector3(0.4, 4.0, 20.0)]
const ENEMY_AT := Vector3(-10.0, 0.0, 20.0)

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var cfg: PingConfig = tuning.pings

var map: MapData = null
var nav: NavGrid = null
var state: GameState = null
var sim: Simulation = null
var bots: BotController = null
var commands: Array[PlayerCommand] = []
var cmd: PlayerCommand = null
var you: Character = null
var orange: Character = null
var mates: Array[Bot] = []
## The nav grids built so far, by layout (they take seconds; nothing here changes one).
var _navs: Dictionary[String, NavGrid] = {}


## The field: a 100 m square floor with `walls` ([centre, size] pairs) and bushes at `bushes` (feet), as map data and
## its BoxWorld.
func _field(walls: Array, bushes: Array) -> Array:
	var m := MapData.new()
	m.id = "open field"
	m.kill_y = KILL_Y
	var w := BoxWorld.new(tuning.body)
	w.add_floor(100.0, 100.0)
	m.blocks.append(_block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(100.0, 0.5, 100.0)))
	for pair: Array in walls:
		m.blocks.append(_block(&"wall", pair[0], pair[1]))
		w.add_box(pair[0], pair[1])
	for foot: Vector3 in bushes:
		w.add_bush(foot, 1.5, 2.2)
	for e in 2:
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(SPOTS[i] if e == 0 else SPOTS[3] + Vector3(2.0 * i, 0.0, 0.0), EAST))
		end.dead_zone.append(SpawnPoint.new(Vector3(-45.0, 0.0, 45.0) if e == 0 else Vector3(45.0, 0.0, -45.0), 0.0))
		m.ends.append(end)
	return [m, w]


static func _block(kind: StringName, center: Vector3, size: Vector3) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = kind
	b.center = center
	b.size = size
	return b


## You and two bot teammates at SPOTS, the opponent at `enemy` (still, and driven by nobody unless `enemy_bot`), round
## 1 live and half a second gone. `walls`, `bushes` as _field; `people` your teammates' personalities (bots.md keys).
func _squad(enemy: Vector3 = SPOTS[3], walls: Array = [], bushes: Array = [], enemy_bot: bool = false,
		people: Array = []) -> void:
	var f := _field(walls, bushes)
	var w: BoxWorld = f[1]
	map = f[0]
	var layout := str(walls)
	if not _navs.has(layout):
		_navs[layout] = NavGrid.build(map, tuning.nav, tuning.body)
	nav = _navs[layout]
	sim = Simulation.new(tuning, w, w.mover(), map.ends, KILL_Y)
	sim.nav = nav
	state = GameState.new(5, tuning)
	var loadout := ReplicaStats.default_loadout()
	commands.clear()
	for i in SPOTS.size():
		state.characters.append(Character.new(i, 0 if i < 3 else 1, SPOTS[i], EAST, loadout))
		commands.append(PlayerCommand.new())
	var identities: Dictionary[int, BotRoster.Identity] = {}
	for i in people.size():
		var key: StringName = people[i]
		var who := BotRoster.Identity.new()
		who.bot_name = String(key)
		who.personality = key
		who.style = BotsFile.shared().style(key)
		identities[i + 1] = who
	bots = BotController.new(state, YOU, map, nav, w, tuning, config, {}, identities)
	sim.start_match(state)
	bots.observe(state)
	if not enemy_bot:
		for b in bots.world.bots:
			if b.character.team == 1:
				bots.world.bots.erase(b)
				break
	for i in SPOTS.size():
		state.characters[i].position = enemy if i == ORANGE else SPOTS[i]
	you = state.characters[YOU]
	orange = state.characters[ORANGE]
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


## You ping looking `yaw`, `pitch` (one tick): your ping if one was placed, else null.
func _ping_at(yaw: float, pitch: float) -> Pings.Ping:
	cmd.yaw = yaw
	cmd.pitch = pitch
	cmd.ping = true
	var before := bots.pings.placed
	_tick()
	cmd.ping = false
	return bots.pings.of(YOU) if bots.pings.placed > before else null


## You ping looking straight at `point`.
func _ping_toward(point: Vector3) -> Pings.Ping:
	var to := point - BotSenses.eye_of(you, tuning)
	return _ping_at(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))


func _chest(c: Character) -> Vector3:
	return BotSenses.body_point(c, tuning.hits, config.aim_height_fraction)


func _event(kind: GameEvent.Kind) -> GameEvent:
	for i in state.events.count:
		if state.events.items[i].kind == kind:
			return state.events.items[i]
	return null


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- what a ping marks (pings.test.ts) ---

func test_a_press_marks_the_floor_where_you_look_and_both_teammates_take_it() -> void:
	_squad()
	var p := _ping_at(EAST, -atan2(1.6, 6.0))
	assert_not_null(p, "a ping")
	var e := _event(GameEvent.Kind.PING)
	assert_eq([e.actor, e.value], [YOU, 1], "the event says where the view met the field")
	assert_eq(p.kind, Pings.Kind.SPOT)
	assert_eq(p.enemy_id, -1)
	assert_almost_eq(p.point.y, 0.0, 0.05, "on the floor")
	assert_gt(p.point.x, you.position.x + 4.0)
	assert_lt(_flat(p.spot, p.point), cfg.spot_snap)
	assert_true(nav.is_walkable_at(p.spot))
	for b in mates:
		assert_eq(b.ping_at, bots.world.time, "taken")
		assert_eq(b.last_known, p.spot)
		assert_true(b.has_last_known)
		assert_true(b.on_ping_spot())


func test_the_sky_or_past_the_reach_pings_nothing_and_the_bots_keep_what_they_had() -> void:
	_squad()
	assert_null(_ping_at(EAST, 0.4), "the sky")
	assert_eq(_event(GameEvent.Kind.PING).value, 0, "the event says nothing was met")
	# Level over the open field: the floor is never met, and the field's edge is past the reach.
	assert_null(_ping_at(EAST, 0.0))
	for b in mates:
		assert_eq(b.ping_at, -INF)
	assert_eq(bots.pings.placed, 0)


func test_off_a_wall_the_spot_is_on_your_side_of_it() -> void:
	_squad(SPOTS[3], [WALL])
	var p := _ping_at(EAST, 0.0)
	assert_not_null(p)
	assert_eq(p.kind, Pings.Kind.SPOT)
	assert_almost_eq(p.point.x, -20.2, 0.05, "the wall's face")
	assert_lt(p.spot.x, -20.2, "in front of it")
	assert_almost_eq(p.spot.y, 0.0, 0.05)


func test_an_enemy_you_see_under_the_view_is_a_contact_at_their_feet() -> void:
	_squad(ENEMY_AT, [BACKSTOP])
	var p := _ping_toward(_chest(orange))
	assert_not_null(p)
	assert_eq(p.kind, Pings.Kind.CONTACT)
	assert_eq(p.enemy_id, ORANGE)
	assert_almost_eq(_flat(p.spot, orange.position), 0.0, 1e-6)
	assert_almost_eq(p.point.y, _chest(orange).y, 1e-3)
	for b in mates:
		# Both see them already, 20 m off: in a fight, a ping is ignored.
		assert_true(b.target_visible)
		assert_eq(b.ping_at, -INF, "ignored with a target in view")
	# Off to the side by a little more than the cone: the wall behind, not them.
	var aside := _chest(orange)
	aside.z += 20.0 * tan(deg_to_rad(cfg.enemy_cone_deg)) + 0.6
	_run(cfg.min_gap)
	p = _ping_toward(aside)
	assert_eq(p.kind, Pings.Kind.SPOT)
	assert_almost_eq(p.point.x, -0.2, 0.05)


func test_an_enemy_seen_further_than_the_bots_see_is_still_a_contact_within_the_reach() -> void:
	var far := Vector3(-30.0 + config.view_distance + 20.0, 0.0, 20.0)
	_squad(far, [[far + Vector3(10.0, 2.0, 0.0), BACKSTOP[1]]])
	var p := _ping_toward(_chest(orange))
	assert_eq(p.kind, Pings.Kind.CONTACT, "the ping's reach, not the bots' view distance")


func test_no_contact_behind_a_wall_in_a_bush_or_behind_a_body() -> void:
	_squad(ENEMY_AT, [WALL, BACKSTOP])
	var p := _ping_toward(_chest(orange))
	assert_eq(p.kind, Pings.Kind.SPOT, "behind a wall")
	assert_almost_eq(p.point.x, -20.2, 0.05)
	_squad(ENEMY_AT, [BACKSTOP], [ENEMY_AT])
	p = _ping_toward(_chest(orange))
	assert_eq(p.kind, Pings.Kind.SPOT, "in a bush")
	assert_eq(p.enemy_id, -1)
	_squad(ENEMY_AT, [BACKSTOP])
	var body := state.characters[1]
	body.status = Character.Status.OUT
	# Where your look at the enemy's chest crosses the body's chest, clear of the seam between its chest and head.
	body.position = Vector3(-15.0, 0.0, 20.0)
	p = _ping_toward(_chest(orange))
	assert_eq(p.enemy_id, -1, "the body of someone hit stops sight")


func test_it_is_your_teams_and_nothing_while_you_are_out_between_rounds_or_on_the_range() -> void:
	_squad(SPOTS[3], [], [], true)
	var theirs: Bot = null
	for b in bots.world.bots:
		if b.character.team == 1:
			theirs = b
	assert_not_null(_ping_at(EAST, -atan2(1.6, 6.0)))
	assert_eq(theirs.ping_at, -INF, "the other team's bots never take it")
	you.status = Character.Status.CALLING
	_run(0.1)
	var before: Array[float] = [mates[0].ping_at, mates[1].ping_at]
	assert_null(_ping_at(EAST, -atan2(1.6, 8.0)))
	assert_null(_event(GameEvent.Kind.PING), "out: no event")
	assert_eq([mates[0].ping_at, mates[1].ping_at], before)
	_squad()
	state.round_state.phase = RoundState.Phase.OVER
	state.round_state.timer = 5.0
	assert_null(_ping_at(EAST, -atan2(1.6, 6.0)))
	assert_null(_event(GameEvent.Kind.PING), "between rounds: no event")
	_squad()
	state.round_state.practice = true
	cmd.ping = true
	sim.step(state, commands, DT)
	cmd.ping = false
	assert_null(_event(GameEvent.Kind.PING), "on the range: no event")


func test_the_ping_looks_along_the_view_with_the_recoil() -> void:
	_squad()
	you.armament.recoil = 0.05
	_ping_at(EAST, -0.2)
	var e := _event(GameEvent.Kind.PING)
	assert_almost_eq(e.direction.y, sin(you.pitch + you.armament.recoil), 1e-5)
	assert_gt(you.armament.recoil, 0.0)
	assert_almost_eq(e.position, BotSenses.eye_of(you, tuning), Vector3.ONE * 1e-5, "from the eyes")


func test_a_second_press_inside_the_gap_is_one_ping_and_a_miss_starts_no_gap() -> void:
	_squad()
	var down := -atan2(1.6, 6.0)
	assert_not_null(_ping_at(EAST, down))
	assert_null(_ping_at(EAST, down - 0.05), "a double click is one ping")
	assert_eq(bots.pings.placed, 1)
	_run(cfg.min_gap)
	assert_not_null(_ping_at(EAST, down), "the next after the gap")
	_run(cfg.min_gap)
	assert_null(_ping_at(EAST, 0.4), "the sky")
	assert_not_null(_ping_at(EAST, down), "a miss starts no gap")
	assert_eq(bots.pings.placed, 3)


func test_one_ping_each_kept_for_its_lifetime_and_cleared_each_round() -> void:
	_squad()
	var p := _ping_at(EAST, -atan2(1.6, 6.0))
	assert_true(bots.pings.is_up(p, state.time))
	_run(cfg.min_gap)
	var again := _ping_at(EAST, -atan2(1.6, 10.0))
	assert_same(again, p, "one ping each: the new one in its place")
	assert_true(bots.pings.is_up(p, state.time + cfg.lifetime - 0.1))
	assert_false(bots.pings.is_up(p, state.time + cfg.lifetime))
	for c in state.characters:
		if c.team == 1:
			c.status = Character.Status.OUT
	_run(0.2)
	for i in 600:
		if _event(GameEvent.Kind.ROUND_START) != null:
			break
		_tick()
	assert_not_null(_event(GameEvent.Kind.ROUND_START), "the next round")
	assert_false(bots.pings.is_up(p, state.time), "cleared")
	for b in mates:
		assert_eq(b.ping_at, -INF, "forgotten")


# --- what your bot teammates do with it (pings.test.ts) ---

func test_a_teammate_sets_off_for_the_spot_and_gets_nearer() -> void:
	_squad()
	var p := _ping_at(EAST, -atan2(1.6, 25.0))
	var spot := p.spot
	var start := minf(_flat(mates[0].character.position, spot), _flat(mates[1].character.position, spot))
	_run(3.0)
	assert_true(mates[0].mode == Bot.Mode.SEARCH or mates[1].mode == Bot.Mode.SEARCH, "a search")
	var now := minf(_flat(mates[0].character.position, spot), _flat(mates[1].character.position, spot))
	assert_lt(now, start - 4.0)


func test_under_your_order_they_keep_the_order_and_only_watch() -> void:
	_squad()
	cmd.squad_order = SquadOrder.Kind.FOLLOW
	_tick()
	cmd.squad_order = SquadOrder.Kind.NONE
	_run(0.5)
	assert_not_null(_ping_at(EAST, -atan2(1.6, 25.0)))
	_run(2.0)
	for b in mates:
		assert_eq(b.mode, Bot.Mode.ORDER)
		assert_lt(_flat(b.character.position, you.position), 8.0)
		assert_true(b.has_last_known, "watching it")


func test_take_is_ignored_in_a_fight_in_cover_with_a_target_in_view_or_out_of_play() -> void:
	var w := _bare_world(3.0)
	var p := _spot_ping()
	for k in 4:
		var b := _bare_bot()
		match k:
			0:
				b.mode = Bot.Mode.FIGHT
			1:
				b.mode = Bot.Mode.COVER
			2:
				b.target_visible = true
			3:
				b.character.status = Character.Status.CALLING
		assert_false(Pings.take(b, p, w))
		assert_eq(b.ping_at, -INF)
		assert_false(b.has_last_known)


func test_a_spot_is_somewhere_to_look_a_contact_a_threat_too() -> void:
	var b := _bare_bot()
	assert_true(Pings.take(b, _spot_ping(), _bare_world(3.0)))
	assert_eq(b.last_known, Vector3(12.0, 0.0, -4.0))
	assert_eq(b.heard_at, 3.0)
	assert_eq(b.last_threat_at, -INF)
	var contact := _spot_ping()
	contact.kind = Pings.Kind.CONTACT
	contact.spot = Vector3(2.0, 0.0, 2.0)
	contact.enemy_id = 4
	assert_true(Pings.take(b, contact, _bare_world(4.0)))
	assert_eq(b.last_threat_at, 4.0)


func test_a_ping_stays_in_mind_for_ping_memory_until_real_news() -> void:
	var b := _bare_bot()
	Pings.take(b, _spot_ping(), _bare_world(3.0))
	assert_gt(config.ping_memory, config.memory_time)
	assert_true(b.ping_in_mind(3.0 + config.ping_memory - 0.01, config))
	assert_true(b.threat_in_mind(3.0 + config.ping_memory - 0.01, config), "a threat in mind past memory_time")
	assert_false(b.ping_in_mind(3.0 + config.ping_memory, config))
	b.last_known.x += 1.0 # a noise heard elsewhere
	assert_false(b.ping_in_mind(4.0, config))


func test_a_rusher_runs_to_a_ping_and_a_careful_bot_does_not() -> void:
	var ran := _sprinted([&"rusher", &"careful"], 4.0)
	assert_lt(ran[1], ran[0] / 2.0)
	assert_gt(ran[0], 0.5)


func test_the_same_seed_and_ping_repeat_the_bots_commands() -> void:
	assert_eq(_sprinted([&"rusher", &"careful"], 2.0, true), _sprinted([&"rusher", &"careful"], 2.0, true))


## Seconds each of the two teammates (personalities `people`) sprinted in the first `seconds` after a ping 28 m off; with
## `trace`, every tick's commands as text instead.
func _sprinted(people: Array, seconds: float, trace: bool = false) -> Array:
	_squad(SPOTS[3], [], [], false, people)
	assert_not_null(_ping_at(EAST, -atan2(1.6, 28.0)))
	var out: Array = [0.0, 0.0]
	var lines := PackedStringArray()
	for t in roundi(seconds / DT):
		_tick()
		for k in 2:
			var c := commands[mates[k].character.id]
			if c.sprint:
				out[k] += DT
			if trace:
				lines.append("%d %s %s %s %s" % [k, c.forward, c.right, c.yaw, c.sprint])
	return [lines] if trace else out


# --- the answer and the marks (callouts) ---

func test_one_teammate_answers_going_to_your_ping_and_no_checking_as_well() -> void:
	_squad()
	var from := bots.callouts.said.total
	assert_not_null(_ping_at(EAST, -atan2(1.6, 25.0)))
	_run(2.0)
	var said := _said_events(from)
	assert_eq(said.count(CalloutsFile.Event.PING_GOING), 1, "one answer: %s" % [said])
	assert_eq(said.count(CalloutsFile.Event.PING_WATCHING), 0)
	for event: int in [CalloutsFile.Event.CHECKING, CalloutsFile.Event.PUSHING, CalloutsFile.Event.FLANKING,
			CalloutsFile.Event.HEARD]:
		assert_false(said.has(event), "nothing else said of it: %s" % [said])


func test_under_your_order_the_nearest_that_took_it_says_it_watches() -> void:
	_squad()
	cmd.squad_order = SquadOrder.Kind.FOLLOW
	_tick()
	cmd.squad_order = SquadOrder.Kind.NONE
	_run(3.0)
	var from := bots.callouts.said.total
	assert_not_null(_ping_at(EAST, -atan2(1.6, 25.0)))
	_run(2.0)
	var said := _said_events(from)
	assert_eq(said.count(CalloutsFile.Event.PING_WATCHING), 1, "%s" % [said])
	assert_eq(said.count(CalloutsFile.Event.PING_GOING), 0)


func _said_events(from: int) -> Array[int]:
	var out: Array[int] = []
	var log := bots.callouts.said
	for n in range(from, log.total):
		var entry := log.entry(n)
		if entry != null and entry.team == 0:
			out.append(entry.event)
	return out


func test_a_contact_call_marks_its_enemy_by_the_chance_and_the_teams_gap() -> void:
	var r := _call_rig(1.0)
	r.sees(0, 2)
	r.tick()
	assert_eq(r.lines, PackedStringArray(["0: Contact!"]))
	var p := r.pings.of(0)
	assert_true(r.pings.is_up(p, r.state.time), "marked")
	assert_eq([p.kind, p.enemy_id, p.team, p.marked], [Pings.Kind.CONTACT, 2, 0, true])
	assert_almost_eq(_flat(p.spot, r.state.characters[2].position), 0.0, 1e-6)
	assert_gt(p.point.y, r.state.characters[2].position.y, "over them")
	# Another sighting called within the gap marks nothing.
	r.run(5.0)
	r.sees(1, 3)
	r.tick()
	assert_eq(r.lines, PackedStringArray(["1: Contact!"]))
	assert_false(r.pings.is_up(r.pings.of(1), r.state.time), "the team's gap")
	assert_eq(r.pings.placed, 1)
	# Lost from sight before the call: nothing to mark.
	var gone := _call_rig(1.0)
	gone.sees(0, 2)
	gone.state.characters[2].status = Character.Status.CALLING
	gone.tick()
	assert_eq(gone.pings.placed, 0)


func test_marks_change_neither_the_lines_nor_play() -> void:
	var lines: Array[PackedStringArray] = []
	for chance: float in [0.0, 0.35, 1.0]:
		var r := _call_rig(chance)
		var all := PackedStringArray()
		for k in 6:
			r.sees(k % 2, 2 + k % 2)
			r.tick()
			all.append_array(r.lines)
			r.run(11.0)
			all.append_array(r.lines)
			r.loses(k % 2, 2 + k % 2)
		lines.append(all)
		if chance == 0.0:
			assert_eq(r.pings.placed, 0)
		if chance == 1.0:
			assert_gt(r.pings.placed, 1)
	assert_eq(lines[1], lines[0])
	assert_eq(lines[2], lines[0])


# --- the press (PlayerInput) ---

func test_a_press_fills_the_next_ticks_ping_once_and_none_on_the_range() -> void:
	var input := PlayerInput.new()
	input.setup(ControlsConfig.new(), 1.5)
	add_child_autofree(input)
	input.active = true
	var c := PlayerCommand.new()
	_press(input, &"ping")
	input.fill(c)
	assert_true(c.ping)
	input.fill(c)
	assert_false(c.ping, "once")
	input.allow_orders(false, false)
	_press(input, &"ping")
	input.fill(c)
	assert_false(c.ping, "dead on the range")
	input.allow_orders(true, true)
	_press(input, &"ping")
	input.allow_orders(false, false)
	input.fill(c)
	assert_false(c.ping, "a press waiting when the range opens is dropped")


func _press(input: PlayerInput, action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	input._unhandled_input(e)


func test_ticks_with_pings_allocate_nothing() -> void:
	_squad(ENEMY_AT, [BACKSTOP])
	_pinging(600)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	_pinging(600)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before, "spots and contacts pinged each half second")


## `ticks` ticks pinging every half second: the floor short of the enemy, then the enemy.
func _pinging(ticks: int) -> void:
	for t in ticks:
		if t % 30 == 0:
			var to := (_chest(orange) if t % 60 == 0 else Vector3(-16.0, 0.0, 22.0)) - BotSenses.eye_of(you, tuning)
			cmd.yaw = atan2(-to.x, -to.z)
			cmd.pitch = atan2(to.y, Vector2(to.x, to.z).length())
			cmd.ping = true
		_tick()
		cmd.ping = false


# --- bare bots and a callouts rig ---

func _bare_bot() -> Bot:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	return Bot.new(c, 3, config.skill, 4)


func _bare_world(time: float) -> BotWorld:
	var w := BotWorld.new()
	w.time = time
	w.cfg = config
	w.tuning = tuning
	return w


func _spot_ping() -> Pings.Ping:
	var p := Pings.Ping.new()
	p.spot = Vector3(12.0, 0.0, -4.0)
	return p


## The callouts on their own (as test_callouts.gd's rig): two bots a side in the open, every event always called with
## one Any line, and sightings marked at `chance`.
func _call_rig(chance: float) -> CallRig:
	var people: Array[StringName] = [&"rusher", &"careful"]
	var text := PackedStringArray(["## When they call", "| Event | Chance | Team gap (s) |", "|---|---|---|"])
	for e in CalloutsFile.Event.size():
		text.append("| %s | 1 | 0 |" % CalloutsFile.EVENT_NAMES[e])
	text.append_array(["", "## Pace", "| Rule | Seconds |", "|---|---|", "| One bot's calls apart | 4 |",
			"| The team's calls apart | 1.5 |", "| The same enemy again after | 10 |", "| A call waits at most | 1.5 |",
			"", "## Marks", "| Rule | Value |", "|---|---|", "| A sighting is marked (chance) | %s |" % chance,
			"| The team's marks apart (s) | 12 |", "", "## Personalities", "| Personality | Talks (×) |", "|---|---|",
			"| Rusher | 1 |", "| Careful | 1 |", "", "## Lines", "| Event | Who | Line |", "|---|---|---|"])
	for e in CalloutsFile.Event.size():
		text.append("| %s | Any | %s |" % [CalloutsFile.EVENT_NAMES[e], "Contact!" if e == CalloutsFile.Event.CONTACT
				else "%s line." % CalloutsFile.EVENT_NAMES[e]])
	var file := CalloutsFile.parse("\n".join(text), people)
	assert_eq(file.problems, [] as Array[String])
	return CallRig.new(file, tuning, config)


class CallRig:
	extends RefCounted
	var state: GameState = GameState.new(1)
	var world: BotWorld = BotWorld.new()
	var director: Callouts = null
	var pings: Pings = null
	## What the last tick or run said, as "speaker: line".
	var lines: PackedStringArray = PackedStringArray()

	func _init(file: CalloutsFile, tuning: SimTuning, config: BotConfig) -> void:
		state.time = 10.0
		world.tuning = tuning
		world.cfg = config
		var people: Array[StringName] = [&"rusher", &"careful", &"rusher", &"careful"]
		for id in people.size():
			var c := Character.new(id, 0 if id < 2 else 1, Vector3(-10.0, 0.0, 0.0), 0.0,
					ReplicaStats.default_loadout())
			state.characters.append(c)
			var b := Bot.new(c, id + 1, config.skill, 8)
			b.personality = people[id]
			world.bots.append(b)
		world.characters = state.characters
		director = Callouts.new(file, CalloutConfig.new(), [] as Array[MapAreas.Area], 7)
		pings = Pings.new(state.characters, tuning.pings)
		director.pings = pings
		tick()

	func tick() -> void:
		state.time += DT
		world.time = state.time
		state.events.clear()
		var from := director.said.total
		director.observe(state, world)
		lines = PackedStringArray()
		for n in range(from, director.said.total):
			var c := director.said.entry(n)
			lines.append("%d: %s" % [c.speaker_id, c.line])

	func run(seconds: float) -> void:
		var all := PackedStringArray()
		for t in roundi(seconds / DT):
			tick()
			all.append_array(lines)
		lines = all

	## Bot `b` sees character `id` from the tick about to run (a fresh sighting), 10 m off.
	func sees(b: int, id: int) -> void:
		state.characters[id].position = Vector3(10.0, 0.0, -10.0)
		var c := world.bots[b].contacts[id]
		c.seen_at = state.time + DT
		c.first_seen_at = state.time + DT
		world.bots[b].last_threat_at = state.time + DT

	func loses(b: int, id: int) -> void:
		world.bots[b].contacts[id].seen_at = -INF
