extends GutTest
## Spotted and the ping as "I'm heading there" (CW1, William 2026-11-15): a Spotted (the order wheel's middle, or a tap
## of its key) is a PING event with value2 PING_SPOT; the bots' controller marks the enemy under the view for the
## spotter's team for PingConfig.spot_time (Spots), never one hidden behind a wall or nobody at all; the spotter's bot
## teammates within spot_share_radius of them hear where they are, at once and every spot_share_gap, the rest carry on;
## the mark ends with the time, when they are out and at a new round; the HUD draws a yellow arrow over the marked
## enemy's head (HudSpotArrows). A ping of a spot is your intention, not an order: each bot teammate within
## ping_follow_reach of you comes along on a roll of ping_follow_chance, from a post it holds too, while one under your
## squad order keeps the order. On an open field, headless: you (team 0) with two bot teammates, one opponent nobody
## drives.

const DT := 1.0 / 60.0
const KILL_Y := -10.0
## Yaw that looks along +X.
const EAST := -PI * 0.5
const YOU := 0
const ORANGE := 3
const SPOTS: Array[Vector3] = [Vector3(-30.0, 0.0, 20.0), Vector3(-32.0, 0.0, 23.0), Vector3(-28.0, 0.0, 23.0),
		Vector3(40.0, 0.0, -40.0)]
const ENEMY_AT := Vector3(-10.0, 0.0, 20.0)
## A wall across the view 10 m east of you: [centre, size].
const WALL: Array[Vector3] = [Vector3(-20.0, 1.5, 20.0), Vector3(0.4, 3.0, 8.0)]
## A 1.1 m crate a metre in front of the opponent (UB3): [centre, size].
const CRATE: Array[Vector3] = [Vector3(-11.0, 0.55, 20.0), Vector3(0.8, 1.1, 1.6)]

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default().duplicate() as BotConfig
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
var _navs: Dictionary[String, NavGrid] = {}


func before_each() -> void:
	config.ping_follow_chance = 1.0
	config.ping_follow_reach = BotConfig.new().ping_follow_reach


# --- the field ---

func _field(walls: Array) -> Array:
	var m := MapData.new()
	m.id = "open field"
	m.kill_y = KILL_Y
	var w := BoxWorld.new(tuning.body)
	w.add_floor(100.0, 100.0)
	m.blocks.append(_block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(100.0, 0.5, 100.0)))
	for pair: Array in walls:
		m.blocks.append(_block(&"wall", pair[0], pair[1]))
		w.add_box(pair[0], pair[1])
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


## You and two bot teammates at SPOTS, the opponent at `enemy` (still, driven by nobody), round 1 live and half a
## second gone.
func _squad(enemy: Vector3 = SPOTS[3], walls: Array = []) -> void:
	var f := _field(walls)
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
	bots = BotController.new(state, YOU, map, nav, w, tuning, config)
	sim.start_match(state)
	# Nobody shoots: the opponent stays in play for as long as a test watches the mark.
	state.cheats.bots_hold_fire = true
	bots.observe(state)
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


## You spot (one tick) looking straight at `point`.
func _spot_toward(point: Vector3) -> void:
	var to := point - BotSenses.eye_of(you, tuning)
	cmd.yaw = atan2(-to.x, -to.z)
	cmd.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	cmd.ping = true
	cmd.ping_spot = true
	_tick()
	cmd.ping = false
	cmd.ping_spot = false


## You ping (one tick) looking `yaw`, `pitch`.
func _ping_at(yaw: float, pitch: float) -> Pings.Ping:
	cmd.yaw = yaw
	cmd.pitch = pitch
	cmd.ping = true
	var before := bots.pings.placed
	_tick()
	cmd.ping = false
	return bots.pings.of(YOU) if bots.pings.placed > before else null


func _chest(c: Character) -> Vector3:
	return BotSenses.body_point(c, tuning.hits, config.aim_height_fraction)


func _event(kind: GameEvent.Kind) -> GameEvent:
	for i in state.events.count:
		if state.events.items[i].kind == kind:
			return state.events.items[i]
	return null


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Spotted ---

func test_a_spotted_is_a_ping_event_saying_so() -> void:
	_squad(ENEMY_AT)
	var to := _chest(orange) - BotSenses.eye_of(you, tuning)
	cmd.yaw = atan2(-to.x, -to.z)
	cmd.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	cmd.ping = true
	cmd.ping_spot = true
	bots.think(state, commands, DT)
	sim.step(state, commands, DT)
	var e := _event(GameEvent.Kind.PING)
	assert_not_null(e)
	if e != null:
		assert_eq([e.actor, e.value2], [YOU, GameEvent.PING_SPOT])
	bots.observe(state)
	assert_eq(bots.pings.of(YOU).at, -INF, "a Spotted is no ping of a spot: no marker, no one sent")


func test_an_enemy_you_see_is_marked_for_your_team_for_the_spot_time() -> void:
	_squad(ENEMY_AT)
	var before := bots.spots.placed
	_spot_toward(_chest(orange))
	assert_eq(bots.spots.placed, before + 1, "one spot")
	assert_true(bots.spots.is_spotted(ORANGE, state.time), "marked")
	assert_eq(bots.spots.spotted_by(ORANGE), 0, "for your team")
	assert_almost_eq(bots.spots.time_left(ORANGE, state.time), cfg.spot_time, 0.05)
	assert_false(bots.spots.is_spotted(YOU, state.time), "nobody else")
	_run(cfg.spot_time - 0.5)
	assert_true(bots.spots.is_spotted(ORANGE, state.time), "still marked just before the time is up")
	_run(1.0)
	assert_false(bots.spots.is_spotted(ORANGE, state.time), "gone after it")


func test_spotting_them_again_starts_the_time_over() -> void:
	_squad(ENEMY_AT)
	_spot_toward(_chest(orange))
	_run(6.0)
	_spot_toward(_chest(orange))
	assert_almost_eq(bots.spots.time_left(ORANGE, state.time), cfg.spot_time, 0.05)


func test_nobody_under_the_view_or_behind_a_wall_marks_nobody() -> void:
	_squad(ENEMY_AT)
	var before := bots.spots.placed
	_spot_toward(_chest(orange) + Vector3(0.0, 0.0, 6.0))
	assert_eq(bots.spots.placed, before, "6 m to the side of them: nobody")
	_spot_toward(Vector3(-20.0, 0.0, 40.0))
	assert_eq(bots.spots.placed, before, "the floor: nobody")
	_squad(ENEMY_AT, [WALL])
	before = bots.spots.placed
	_spot_toward(_chest(orange))
	assert_eq(bots.spots.placed, before, "behind a wall you can't see them, so you can't spot them")
	assert_false(bots.spots.is_spotted(ORANGE, state.time))


# UB3 (owner, 2026-11-20: a single tap should be enough): the view on the cover in front of them still spots.
func test_a_view_on_the_cover_in_front_of_them_still_spots_them() -> void:
	_squad(ENEMY_AT, [CRATE])
	var head := BotSenses.body_point(orange, tuning.hits, config.head_height_fraction)
	var before := bots.spots.placed
	# The view meets the crate's face (a little under its top), their head showing just above it.
	_spot_toward(Vector3(head.x, 1.0, head.z))
	assert_eq(bots.spots.placed, before + 1, "the crate they peek over doesn't eat the spot")
	assert_true(bots.spots.is_spotted(ORANGE, state.time))


func test_cover_they_are_wholly_behind_still_hides_them() -> void:
	_squad(ENEMY_AT, [WALL])
	var before := bots.spots.placed
	_spot_toward(_chest(orange))
	assert_eq(bots.spots.placed, before, "behind a wall: the sight rules still want them seen")


func test_a_tap_is_up_to_three_tenths_of_a_second() -> void:
	assert_almost_eq(ControlsConfig.new().wheel_tap, 0.3, 0.0001)


func test_the_cone_is_more_forgiving_than_a_pings() -> void:
	assert_gt(cfg.spot_cone_deg, cfg.enemy_cone_deg)
	_squad(ENEMY_AT)
	var eye := BotSenses.eye_of(you, tuning)
	var chest := _chest(orange)
	var d := chest.distance_to(eye)
	# Aimed 3 degrees wide of their chest: outside a ping's cone, inside Spotted's.
	var off := Vector3(0.0, 0.0, d * tan(deg_to_rad(3.0)))
	_spot_toward(chest + off)
	assert_true(bots.spots.is_spotted(ORANGE, state.time), "a near miss still spots")


func test_the_mark_ends_when_they_are_out_and_at_a_new_round() -> void:
	_squad(ENEMY_AT)
	_spot_toward(_chest(orange))
	Elimination.eliminate(orange, YOU, state.characters, sim.ends)
	_tick()
	assert_false(bots.spots.is_spotted(ORANGE, state.time), "out: no arrow over them")
	assert_eq(bots.spots.spotted_by(ORANGE), -1)
	_squad(ENEMY_AT)
	_spot_toward(_chest(orange))
	bots.spots.clear()
	assert_false(bots.spots.is_spotted(ORANGE, state.time), "a new round clears the book")


func test_teammates_near_the_enemy_hear_where_they_are_and_teammates_far_off_carry_on() -> void:
	var w := BotWorld.new()
	w.cfg = config
	w.tuning = tuning
	w.time = 3.0
	var loadout := ReplicaStats.default_loadout()
	var enemy := Character.new(3, 1, Vector3(10.0, 0.0, 0.0), 0.0, loadout)
	var near := Bot.new(Character.new(1, 0, Vector3(-10.0, 0.0, 0.0), 0.0, loadout), 3, config.skill, 4)
	var far := Bot.new(Character.new(2, 0, Vector3(-40.0, 0.0, 0.0), 0.0, loadout), 4, config.skill, 4)
	var foe := Bot.new(Character.new(4, 1, Vector3(12.0, 0.0, 0.0), 0.0, loadout), 5, config.skill, 5)
	w.bots.append_array([near, far, foe])
	Spots.share(w, enemy, 0, 30.0)
	assert_true(near.has_last_known, "20 m off: told")
	assert_eq(near.last_known, enemy.position)
	assert_eq([near.heard_at, near.last_threat_at], [3.0, 3.0], "as a threat heard now")
	assert_false(far.has_last_known, "50 m off: carries on")
	assert_false(foe.has_last_known, "their own side is told nothing")
	near.has_last_known = false
	near.mode = Bot.Mode.FIGHT
	Spots.share(w, enemy, 0, 30.0)
	assert_false(near.has_last_known, "fighting: keeps its own fight")


func test_while_marked_they_are_told_again_where_they_moved_to() -> void:
	_squad(ENEMY_AT)
	_spot_toward(_chest(orange))
	var mate := mates[0]
	# Behind the teammates' backs and out of their sight: only the mark tells them.
	orange.position = Vector3(-12.0, 0.0, 30.0)
	orange.prev_position = orange.position
	for b in mates:
		b.target_visible = false
	_run(cfg.spot_share_gap + 0.1)
	if mate.target_visible:
		pass_test("the teammate saw them itself")
		return
	assert_lt(_flat(mate.last_known, orange.position), 1.0, "told where they are now, not where they were spotted")


func test_spotted_enemies_further_than_the_share_radius_send_nobody() -> void:
	_squad(ENEMY_AT)
	cfg.spot_share_radius = 5.0
	for b in mates:
		b.has_last_known = false
	var heard: Array[float] = [mates[0].heard_at, mates[1].heard_at]
	_spot_toward(_chest(orange))
	cfg.spot_share_radius = PingConfig.new().spot_share_radius
	assert_true(bots.spots.is_spotted(ORANGE, state.time), "still marked for your team")
	for i in mates.size():
		var b := mates[i]
		if b.target_visible:
			continue
		assert_eq(b.heard_at, heard[i], "20 m off with a 5 m radius: not told")


# --- the ping: "I'm heading there" ---

func test_a_ping_of_a_spot_brings_teammates_along_on_the_roll() -> void:
	_squad()
	var p := _ping_at(EAST, -atan2(1.6, 25.0))
	assert_not_null(p)
	for b in mates:
		assert_eq(b.ping_at, bots.world.time, "chance 1: everyone comes along")
		assert_true(b.ping_joined)
		assert_true(b.joins_ping(bots.world.time, config))
	_squad()
	config.ping_follow_chance = 0.0
	assert_not_null(_ping_at(EAST, -atan2(1.6, 25.0)))
	for b in mates:
		assert_eq(b.ping_at, -INF, "chance 0: nobody, it was not an order")
		assert_false(b.ping_joined)


func test_teammates_further_than_the_reach_carry_on() -> void:
	_squad()
	config.ping_follow_reach = 1.0
	assert_not_null(_ping_at(EAST, -atan2(1.6, 25.0)))
	for b in mates:
		assert_false(b.ping_joined, "more than 1 m from you: not coming")
		assert_eq(b.ping_at, -INF)


func test_under_your_squad_order_a_ping_is_only_watched() -> void:
	_squad()
	cmd.squad_order = SquadOrder.Kind.FOLLOW
	_tick()
	cmd.squad_order = SquadOrder.Kind.NONE
	_run(0.5)
	assert_not_null(_ping_at(EAST, -atan2(1.6, 25.0)))
	for b in mates:
		assert_eq(b.order, SquadOrder.Kind.FOLLOW, "the order stands")
		assert_false(b.ping_joined, "not coming along: Follow me is the order")
		assert_eq(b.ping_at, bots.world.time, "but it watches the spot")


func test_the_roll_is_each_bots_own_and_some_come_some_dont() -> void:
	var w := BotWorld.new()
	w.cfg = config
	w.tuning = tuning
	w.time = 2.0
	config.ping_follow_chance = 0.5
	var loadout := ReplicaStats.default_loadout()
	var giver := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var p := Pings.Ping.new()
	p.spot = Vector3(12.0, 0.0, -4.0)
	var came := 0
	for i in 40:
		var b := Bot.new(Character.new(1, 0, Vector3(2.0, 0.0, 0.0), 0.0, loadout), 100 + i, config.skill, 4)
		if Pings.follow(b, p, giver, w):
			came += 1
			assert_eq(b.last_known, p.spot)
	assert_between(came, 8, 32, "about half of 40 came along")


func test_a_teammate_holding_a_post_leaves_it_to_come_along() -> void:
	var w := BotWorld.new()
	w.cfg = config
	w.tuning = tuning
	w.time = 5.0
	var loadout := ReplicaStats.default_loadout()
	var b := Bot.new(Character.new(1, 0, Vector3.ZERO, 0.0, loadout), 7, config.skill, 4)
	var p := Pings.Ping.new()
	p.spot = Vector3(30.0, 0.0, 0.0)
	assert_true(Pings.follow(b, p, Character.new(0, 0, Vector3.ZERO, 0.0, loadout), w))
	assert_true(b.joins_ping(w.time, config))
	b.last_known = Vector3(1.0, 0.0, 1.0)
	assert_false(b.joins_ping(w.time, config), "real news since: no longer the ping")
	b.last_known = p.spot
	assert_false(b.joins_ping(w.time + config.ping_memory + 1.0, config), "an old ping is forgotten")
	var p2 := Pings.Ping.new()
	p2.kind = Pings.Kind.CONTACT
	p2.spot = p.spot
	Pings.take(b, p2, w)
	assert_false(b.ping_joined, "a contact taken is no ping to come along to")


func test_your_spot_plays_the_pip_once_and_a_tap_on_nobody_plays_nothing() -> void:
	_squad()
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(SoundConfig.new(), [] as Array[StringName], BodyConfig.new(), null, null)
	_spot_toward(Vector3(-10.0, 1.0, 40.0))
	audio.on_spot(bots.spots, YOU)
	assert_eq(_pips(audio), 0, "nobody there: no pip")
	_spot_toward(_chest(orange))
	assert_true(bots.spots.is_spotted(ORANGE, bots.world.time))
	audio.on_spot(bots.spots, YOU)
	assert_eq(_pips(audio), 1)
	audio.on_spot(bots.spots, YOU)
	assert_eq(_pips(audio), 1, "once a spot")
	var other := SimAudio.new()
	add_child_autofree(other)
	other.setup(SoundConfig.new(), [] as Array[StringName], BodyConfig.new(), null, null)
	other.on_spot(bots.spots, 1)
	assert_eq(_pips(other), 0, "a teammate's spot is not yours")


func _pips(audio: SimAudio) -> int:
	var n := 0
	var pip: Array = audio._streams[&"ping_pip"]
	for v in audio._own:
		if v.playing and pip.has(v.stream):
			n += 1
	return n


# --- Cover me ---

## You give `kind` (one tick).
func _order(kind: SquadOrder.Kind) -> void:
	cmd.squad_order = kind
	_tick()
	cmd.squad_order = SquadOrder.Kind.NONE


func test_cover_me_sends_the_nearest_free_teammate_to_your_side_and_the_other_carries_on() -> void:
	_squad()
	mates[1].character.position = SPOTS[1] + Vector3(-8.0, 0.0, 6.0)
	_order(SquadOrder.Kind.COVER)
	assert_eq(bots.orders.order_of(YOU), SquadOrder.Kind.COVER)
	assert_eq(bots.order_outcome.order, SquadOrder.Kind.COVER)
	assert_eq(mates[0].order, SquadOrder.Kind.COVER, "the nearest covers you")
	assert_eq(mates[0].order_giver, you)
	assert_eq(mates[1].order, SquadOrder.Kind.NONE, "the other is on the team plan")
	assert_lt(_flat(mates[0].order_goal, you.position), 4.0, "its post is beside you")
	_run(4.0)
	assert_lt(_flat(mates[0].character.position, mates[0].order_goal), 2.0, "and it goes there")
	assert_lt(_flat(mates[0].character.position, you.position), 3.0, "beside you")
	assert_eq(mates[0].order, SquadOrder.Kind.COVER, "and stays while you are near")


func test_a_teammate_in_a_fight_is_passed_over_for_a_free_one() -> void:
	_squad()
	mates[1].character.position = SPOTS[1] + Vector3(-8.0, 0.0, 6.0)
	mates[0].mode = Bot.Mode.FIGHT
	assert_eq(bots.orders.give_cover(you), SquadOrder.Kind.COVER)
	assert_eq(mates[1].order, SquadOrder.Kind.COVER, "the free one, though further")
	assert_eq(mates[0].order, SquadOrder.Kind.NONE)


func test_cover_me_ends_when_you_walk_off_and_with_nobody_it_is_nobody() -> void:
	_squad()
	_order(SquadOrder.Kind.COVER)
	assert_eq(bots.orders.order_of(YOU), SquadOrder.Kind.COVER)
	you.position = mates[0].order_goal + Vector3(SquadConfig.new().cover_leave + 2.0, 0.0, 0.0)
	_run(0.2)
	assert_eq(bots.orders.order_of(YOU), SquadOrder.Kind.NONE, "too far to cover: back on the plan")
	assert_eq(bots.order_outcome.notice, SquadOrders.Notice.CANCELLED)
	for b in mates:
		assert_eq(b.order, SquadOrder.Kind.NONE)
	var w := BotWorld.new()
	w.cfg = config
	w.tuning = tuning
	var alone := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	w.characters.append(alone)
	var book := SquadOrderBook.new(w)
	assert_eq(book.give_cover(alone), SquadOrder.Kind.NONE)
	assert_eq(book.order_outcome.notice, SquadOrders.Notice.NOBODY)


# --- the arrows ---

func test_the_arrow_is_over_a_marked_enemys_head_in_front_of_you_only() -> void:
	_squad(ENEMY_AT)
	var hud_cfg := HudConfig.new()
	var arrows := HudSpotArrows.new()
	add_child_autofree(arrows)
	arrows.setup(hud_cfg, tuning, state.characters, you)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.look_at_from_position(Vector3(-30.0, 1.6, 20.0), Vector3(-10.0, 1.6, 20.0))
	var area := get_viewport().get_visible_rect().size
	arrows.place(camera, bots.spots, state.time, true, area)
	assert_eq(arrows.count(), 0, "nobody marked: no arrow")
	_spot_toward(_chest(orange))
	arrows.place(camera, bots.spots, state.time, true, area)
	assert_eq(arrows.count(), 1, "an arrow over them")
	var over := Lean.eye(orange, tuning.body, tuning.hits) + Vector3.UP * hud_cfg.spot_arrow_lift
	assert_gt(hud_cfg.spot_arrow_lift, 0.0, "over their head")
	var want := camera.unproject_position(over)
	assert_almost_eq(arrows.tip(0).x, want.x, 0.5, "the tip where the point over their eyes is on the screen")
	assert_almost_eq(arrows.tip(0).y, want.y, 0.5)
	arrows.place(camera, bots.spots, state.time, false, area)
	assert_eq(arrows.count(), 0, "hidden when it isn't to show")
	camera.look_at_from_position(Vector3(-30.0, 1.6, 20.0), Vector3(-50.0, 1.6, 20.0))
	arrows.place(camera, bots.spots, state.time, true, area)
	assert_eq(arrows.count(), 0, "behind you: none")
	var theirs := HudSpotArrows.new()
	add_child_autofree(theirs)
	theirs.setup(hud_cfg, tuning, state.characters, orange)
	camera.look_at_from_position(Vector3(-30.0, 1.6, 20.0), Vector3(-10.0, 1.6, 20.0))
	theirs.place(camera, bots.spots, state.time, true, area)
	assert_eq(theirs.count(), 0, "the other side sees no arrow your team put up")
	arrows.place(camera, bots.spots, state.time + cfg.spot_time + 1.0, true, area)
	assert_eq(arrows.count(), 0, "gone with the mark")


func test_the_arrows_fade_out_over_the_last_of_the_mark_and_allocate_nothing() -> void:
	_squad(ENEMY_AT)
	var arrows := HudSpotArrows.new()
	add_child_autofree(arrows)
	arrows.setup(HudConfig.new(), tuning, state.characters, you)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.look_at_from_position(Vector3(-30.0, 1.6, 20.0), Vector3(-10.0, 1.6, 20.0))
	_spot_toward(_chest(orange))
	var area := get_viewport().get_visible_rect().size
	arrows.place(camera, bots.spots, state.time, true, area)
	assert_almost_eq(arrows._alphas[0], 1.0, 1e-4, "whole at first")
	arrows.place(camera, bots.spots, state.time + cfg.spot_time - 0.5, true, area)
	assert_almost_eq(arrows._alphas[0], 0.5, 0.02, "half gone half a second from the end")
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 120:
		arrows.place(camera, bots.spots, state.time + i * 0.01, true, area)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before, "no object made a frame")
