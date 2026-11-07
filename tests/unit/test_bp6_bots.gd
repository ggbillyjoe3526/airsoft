extends GutTest
## BP6: the bot rows of the known issues fixed in the pass: keeping apart from an enemy only with nothing solid between.

const DT := 1.0 / 60.0

## A nav grid that calls every point floor at y = 0 (a heard guess lands on it).
class FlatNav:
	extends NavGrid

	func floor_at(_p: Vector3) -> float:
		return 0.0

var tuning: SimTuning = SimTuning.new()
var bots: BotConfig = BotConfig.load_default()


## A bot at the origin on a floor, a teammate and an enemy beside it (`apart` m east and west), and with `wall` a thin
## wall between it and each of them. [Bot, BotWorld, teammate, enemy].
func _crowd(apart: float, wall: bool) -> Array:
	var world := BoxWorld.new(tuning.body)
	world.add_floor(60.0, 60.0)
	if wall:
		world.add_box(Vector3(apart * 0.5, 1.5, 0.0), Vector3(0.05, 3.0, 4.0))
		world.add_box(Vector3(-apart * 0.5, 1.5, 0.0), Vector3(0.05, 3.0, 4.0))
	var loadout := ReplicaStats.default_loadout()
	var y := tuning.body.rest_gap
	var me := Character.new(0, 0, Vector3(0.0, y, 0.0), 0.0, loadout)
	var mate := Character.new(1, 0, Vector3(-apart, y, 0.0), 0.0, loadout)
	var foe := Character.new(2, 1, Vector3(apart, y, 0.0), PI, loadout)
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = bots
	w.query = world
	w.planner = RoundPlanner.new(1)
	var chars: Array[Character] = [me, mate, foe]
	w.characters = chars
	var b := Bot.new(me, 3, bots.skill_for(&"normal"), 3)
	return [b, w, mate, foe]


func test_a_bot_steps_off_an_enemy_close_by_in_the_open_but_not_through_a_wall() -> void:
	var apart := bots.separation_distance * 0.5
	for wall: bool in [false, true]:
		var m := _crowd(apart, wall)
		var b: Bot = m[0]
		var w: BotWorld = m[1]
		var mate: Character = m[2]
		mate.status = Character.Status.OUT # the enemy alone first
		b.move_dir = Vector3(0.0, 0.0, -1.0)
		assert_true(BotMovement.keep_apart(b, w, true, PlayerCommand.new()))
		if wall:
			assert_almost_eq(b.move_dir.x, 0.0, 1e-6, "an enemy the other side of a wall pushes nothing")
		else:
			assert_lt(b.move_dir.x, 0.0, "in the open, off the enemy (west)")
		# A teammate pushes as ever, wall or none (no sight, no knowledge: a few cm).
		mate.status = Character.Status.ALIVE
		w.characters[2].status = Character.Status.OUT
		b.move_dir = Vector3(0.0, 0.0, -1.0)
		BotMovement.keep_apart(b, w, true, PlayerCommand.new())
		assert_gt(b.move_dir.x, 0.0, "off the teammate (east)")


## BP6: a bot's fresh semi or burst pull is made only on a tick the replica can fire it, never kept press_buffer to go
## off after the line-of-fire check that let it.
func test_a_bots_fresh_semi_pull_waits_for_a_ready_replica_and_then_fires_at_once() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var a := c.armament
	a.modes[0] = ReplicaConfig.FireMode.SEMI
	a.cooldown = 0.1
	assert_true(BotCombat.press_kept(c, DT), "still cycling past this tick: the press would be kept")
	a.cooldown = DT * 0.5
	assert_false(BotCombat.press_kept(c, DT), "ready within this tick: it fires now")
	var cmd := PlayerCommand.new()
	cmd.fire = true
	var events := SimEvents.new()
	Armament.step(c, cmd, Vector3(0.0, 1.6, 0.0), 1.0, true, BBPool.new(4), Seeds.stream(1), events, tuning, DT)
	assert_eq(events.count_of(GameEvent.Kind.SHOT), 1, "the pull made then is the shot, this tick")
	a.trigger_was_down = false
	a.cooldown = 0.0
	a.draw_left = 0.3
	assert_true(BotCombat.press_kept(c, DT), "drawing")
	a.draw_left = 0.0
	a.reload_left = 0.3
	assert_true(BotCombat.press_kept(c, DT), "reloading")
	a.reload_left = 0.0
	c.vault.active = true
	assert_true(BotCombat.press_kept(c, DT), "vaulting: Armament would keep it through the vault's fire_hold_off")
	c.vault.active = false
	c.fire_lockout = 0.2
	assert_true(BotCombat.press_kept(c, DT), "the moment after a vault")
	c.fire_lockout = DT * 0.5
	assert_false(BotCombat.press_kept(c, DT), "the lockout over within this tick")
	c.fire_lockout = 0.0
	assert_false(BotCombat.press_kept(c, DT), "ready")
	a.cooldown = 0.1
	a.trigger_was_down = true
	assert_false(BotCombat.press_kept(c, DT), "a held trigger presses nothing new")
	a.trigger_was_down = false
	a.modes[0] = ReplicaConfig.FireMode.AUTO
	assert_false(BotCombat.press_kept(c, DT), "full auto keeps no press")


## BP6: a real noise soon after a ping a bot took, close to the ping's spot, is news of its own: the bot no longer holds
## the ping's spot as if nothing were heard (so its Heard call is made, and the ping's long memory is let go).
func test_a_real_noise_by_a_pinged_spot_soon_after_the_ping_is_news_of_its_own() -> void:
	var m := _crowd(10.0, false)
	var b: Bot = m[0]
	var w: BotWorld = m[1]
	var foe: Character = m[3]
	w.bots = [b] as Array[Bot]
	w.nav = FlatNav.new()
	(m[2] as Character).status = Character.Status.OUT
	w.time = 3.0
	var p := Pings.Ping.new()
	p.spot = Vector3(9.0, 0.0, 0.0)
	assert_true(Pings.take(b, p, w))
	assert_true(b.on_ping_spot())
	w.time = 4.0
	foe.position = Vector3(10.0, tuning.body.rest_gap, 0.0)
	var state := GameState.new(1, tuning)
	var step := state.events.add(GameEvent.Kind.FOOTSTEP)
	step.actor = foe.id
	step.value = GameEvent.Footstep.SPRINT
	step.carry = 1.0
	BotHearing.observe(state, w)
	assert_eq(b.heard_at, 4.0, "heard")
	assert_false(b.on_ping_spot(), "a sound's guess now, not the ping's spot")


## BP6: a bot back on its lane after a search resumes at the far end of the lane segment it stands nearest, from the
## point it left on: never walking back to a point it passed, and never past the points it walks.
func test_back_from_a_search_a_bot_resumes_its_lane_past_the_segment_nearest_it() -> void:
	var m := _crowd(10.0, false)
	var b: Bot = m[0]
	var w: BotWorld = m[1]
	w.lanes = [PackedVector3Array([Vector3.ZERO, Vector3(10.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0),
			Vector3(30.0, 0.0, 0.0)])] as Array[PackedVector3Array]
	b.lane = 0
	b.lane_dir = 1
	b.lane_points = 4
	b.lane_index = 1 # making for the point at 10 m when it left the lane
	b.character.position = Vector3(14.0, 0.0, 3.0)
	assert_eq(BotMovement.resume_point(b, w), 2, "between 10 and 20 m: on to 20, not back to 10")
	b.character.position = Vector3(18.0, 0.0, 3.0)
	assert_eq(BotMovement.resume_point(b, w), 2)
	b.character.position = Vector3(26.0, 0.0, -2.0)
	assert_eq(BotMovement.resume_point(b, w), 3, "the search took it on past 20 m: on to 30")
	b.character.position = Vector3(4.0, 0.0, 3.0)
	assert_eq(BotMovement.resume_point(b, w), 1, "short of 10 m still: on to it")
	b.character.position = Vector3(-5.0, 0.0, 0.0)
	assert_eq(BotMovement.resume_point(b, w), 1, "never back to a point it passed")
	b.lane_points = 2
	b.character.position = Vector3(29.0, 0.0, 0.0)
	assert_eq(BotMovement.resume_point(b, w), 1, "nor past the points it walks")
	b.lane_points = 4
	b.lane_index = 0 # the first point: nothing behind it
	b.character.position = Vector3(-5.0, 0.0, 0.0)
	assert_eq(BotMovement.resume_point(b, w), 0, "short of the first point: to it")
	b.character.position = Vector3(6.0, 0.0, 1.0)
	assert_eq(BotMovement.resume_point(b, w), 1)
	b.lane_dir = -1
	b.lane_index = 2 # walking the lane the other way, making for 20 m
	b.character.position = Vector3(14.0, 0.0, 0.0)
	assert_eq(BotMovement.resume_point(b, w), 1, "the other way: past 20 m, on to 10")
	b.character.position = Vector3(24.0, 0.0, 0.0)
	assert_eq(BotMovement.resume_point(b, w), 2)


## BP6: the brain's way back to the lane after a search: its next lane goal is the resume point itself (lane_index is
## set one short of it, as _next_goal steps on), not the point it was making for.
func test_back_from_a_search_the_brain_makes_for_the_resume_point() -> void:
	var m := _crowd(10.0, false)
	var b: Bot = m[0]
	var w: BotWorld = m[1]
	(m[2] as Character).status = Character.Status.OUT
	(m[3] as Character).status = Character.Status.OUT
	w.bots = [b] as Array[Bot]
	w.nav = FlatNav.new()
	w.lanes = [PackedVector3Array([Vector3.ZERO, Vector3(10.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0),
			Vector3(30.0, 0.0, 0.0)])] as Array[PackedVector3Array]
	b.lane = 0
	b.lane_dir = 1
	b.lane_points = 4
	b.lane_index = 1
	b.character.position = Vector3(14.0, 0.0, 3.0)
	b.mode = Bot.Mode.SEARCH
	b.has_last_known = false
	BotBrain._choose_mode(b, w, null, DT)
	assert_eq(b.mode, Bot.Mode.ADVANCE, "nothing in mind: back to the lane")
	assert_true(BotMovement._next_goal(b, w))
	assert_eq(b.lane_index, 2, "on to 20 m")
	assert_lt(Vector2(b.lane_goal.x - 20.0, b.lane_goal.z).length(), w.cfg.lane_jitter + 0.5)
