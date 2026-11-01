extends GutTest
## Hard's own habits (DF2): held angles found from the level's walls alone, someone stepping out where a Hard bot already
## aims answered sooner and steadier, corners sliced near the enemy, a watch where someone ducked out before going after
## them, a top-up only from cover with a threat in mind, and at every level no aim at an enemy unseen and unheard (the
## browser game's M37 test; game/ai/bot_angles.gd, bot_combat.gd, bot_senses.gd, bot_brain.gd).

const DT := 1.0 / 60.0
const EYE := 1.6
const LEVELS: Array[StringName] = [&"easy", &"normal", &"hard"]


## A level made of two others: a ray stops at whichever it meets first.
class Both:
	extends WorldQuery
	var a: WorldQuery = null
	var b: WorldQuery = null
	var _other: RayHit = RayHit.new()

	func _init(first: WorldQuery, second: WorldQuery) -> void:
		a = first
		b = second

	func ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
		var met := a.ray(from, to, hit)
		if b.ray(from, to, _other) and (not met or _other.fraction < hit.fraction):
			hit.position = _other.position
			hit.normal = _other.normal
			hit.fraction = _other.fraction
			hit.surface = _other.surface
			return true
		return met


## Counts the rays cast through it.
class Counting:
	extends WorldQuery
	var inner: WorldQuery = null
	var rays: int = 0

	func _init(q: WorldQuery) -> void:
		inner = q

	func ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
		rays += 1
		return inner.ray(from, to, hit)


var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var _w: BotWorld = null
## A hidden run's bot looked for held angles at some tick.
var _angled: bool = false


## A wall ahead and to the left (looking down -Z, left is -X): its right-hand end at (0, -8) is a corner someone could
## step round. Its far end (x = -30) lies outside the fan.
func _corner() -> BoxWorld:
	var q := BoxWorld.new()
	q.add_box(Vector3(-15.0, 1.5, -8.5), Vector3(30.0, 3.0, 1.0))
	return q


func _angles(n: int) -> Array[BotAngles.HeldAngle]:
	var out: Array[BotAngles.HeldAngle] = []
	for i in n:
		out.append(BotAngles.HeldAngle.new())
	return out


## A bot at `at` facing -Z (the enemy side) on `level`, its one enemy at `foe_at`, in `query`; its world is _w.
func _bot(level: StringName, query: WorldQuery, foe_at: Vector3, seed_value: int = 1, at: Vector3 = Vector3.ZERO) -> Bot:
	var loadout := ReplicaStats.default_loadout()
	var me := Character.new(0, 0, at, 0.0, loadout)
	var foe := Character.new(1, 1, foe_at, 0.0, loadout)
	_w = BotWorld.new()
	_w.tuning = tuning
	_w.cfg = config
	_w.query = query
	_w.planner = RoundPlanner.new(1)
	_w.planner.enemy_yaw[0] = 0.0
	_w.characters = [me, foe]
	_w.time = 10.0
	return Bot.new(me, seed_value, config.skill_for(level), 2)


func _idle_aim(b: Bot, walking: bool, cmd: PlayerCommand) -> void:
	BotCombat.aim(b, _w, null, BotSenses.eye_of(b.character, tuning), walking, cmd, DT)


func _look_at(from: Vector3, p: Vector3) -> float:
	return BotAim.look_yaw(from, p)


# --- finding angles ---

func test_aims_just_past_a_corner_at_head_height_where_someone_would_step_out() -> void:
	var q := _corner()
	var eye := Vector3(0.0, EYE, 0.0)
	var out := _angles(2)
	assert_eq(BotAngles.find(q, eye, EYE, 0.0, config, out), 1)
	var a := out[0]
	assert_almost_eq(a.point.y, EYE, 1e-5)
	assert_gt(a.point.x, 0.0, "on the open side")
	assert_lt(Vector2(a.point.x, a.point.z + 8.0).length(), 1.5, "beside the wall's end")
	assert_gt(Vector2(a.point.x, a.point.z).length(), 8.0, "just beyond it")
	assert_true(BotSenses.line_clear(q, eye, a.point), "in plain view")
	assert_almost_eq(a.yaw, _look_at(eye, a.point), 1e-5)
	assert_almost_eq(a.pitch, BotAim.look_pitch(eye, a.point), 1e-5)
	assert_eq(a.side, 1, "leaning right shows more past it")


func test_holds_both_sides_of_a_doorway_and_nothing_in_the_open() -> void:
	var q := BoxWorld.new()
	# A wall across the way 10 m ahead with a 6 m opening straight ahead.
	q.add_box(Vector3(-16.5, 1.5, -10.0), Vector3(27.0, 3.0, 0.5))
	q.add_box(Vector3(16.5, 1.5, -10.0), Vector3(27.0, 3.0, 0.5))
	var out := _angles(2)
	assert_eq(BotAngles.find(q, Vector3(0.0, EYE, 0.0), EYE, 0.0, config, out), 2)
	assert_lt(out[0].point.x * out[1].point.x, 0.0, "one each side")
	assert_eq(out[0].side, -out[1].side)
	assert_gte(out[0].score, out[1].score, "best first")
	assert_eq(BotAngles.find(WorldQuery.new(), Vector3(0.0, EYE, 0.0), EYE, 0.0, config, out), 0, "the open field")


func test_keeps_the_better_of_two_close_picks() -> void:
	var q := BoxWorld.new()
	# Two wall ends a few degrees apart: one pick for both, the better scoring.
	q.add_box(Vector3(-15.0, 1.5, -10.5), Vector3(30.0, 3.0, 1.0))
	q.add_box(Vector3(-15.5, 1.5, -20.5), Vector3(30.0, 3.0, 1.0))
	var out := _angles(2)
	var n := BotAngles.find(q, Vector3(0.0, EYE, 0.0), EYE, 0.0, config, out)
	assert_between(n, 1, 2)
	if n == 2:
		assert_gte(absf(wrapf(out[0].yaw - out[1].yaw, -PI, PI)), deg_to_rad(config.angle_separation_deg))


# --- holding ---

func test_hard_turns_to_the_corner_instead_of_sweeping_and_looks_for_corners_only_now_and_then() -> void:
	var looks: Dictionary[StringName, float] = {}
	for level: StringName in [&"hard", &"normal"]:
		var q := Counting.new(_corner())
		var b := _bot(level, q, Vector3(30.0, 0.0, 30.0))
		b.holding = true
		var cmd := PlayerCommand.new()
		for i in roundi(2.0 / DT):
			_idle_aim(b, false, cmd)
			_w.time += DT
		looks[level] = b.aim_yaw
		if level == &"hard":
			assert_gt(b.held_angle_count, 0)
			var eye := BotSenses.eye_of(b.character, tuning)
			assert_lt(absf(wrapf(b.aim_yaw - _look_at(eye, b.held_angles[0].point), -PI, PI)), deg_to_rad(1.0))
			assert_lte(q.rays, config.angle_rays * (1 + ceili(2.0 / config.angle_refresh)), "a fan per refresh")
		else:
			assert_eq(b.held_angle_count, 0, "Normal holds no angles")
			assert_eq(q.rays, 0)
	assert_lt(absf(looks[&"normal"]), deg_to_rad(1.0), "Normal faces the enemy side, sweeping from there")
	assert_gt(absf(looks[&"hard"]), deg_to_rad(2.0))


func test_finds_the_same_corners_wherever_the_enemies_are() -> void:
	var seen: Array[PackedVector3Array] = []
	for foe: Vector3 in [Vector3(3.0, 0.0, -12.0), Vector3(-20.0, 0.0, 20.0), Vector3(10.0, 0.0, -2.0)]:
		var b := _bot(&"hard", _corner(), foe)
		b.holding = true
		_idle_aim(b, false, PlayerCommand.new())
		var points := PackedVector3Array()
		for i in b.held_angle_count:
			points.append(b.held_angles[i].point)
		seen.append(points)
	assert_gt(seen[0].size(), 0)
	assert_eq(seen[1], seen[0])
	assert_eq(seen[2], seen[0])


# --- reacting from a held angle ---

## A fresh sighting 12 m ahead on `level`, the bot's view on the enemy or `off` degrees away: [reaction delay, aim
## settling already done].
func _sighting(level: StringName, off: float, seed_value: int) -> Vector2:
	var b := _bot(level, WorldQuery.new(), Vector3(0.0, 0.0, -12.0), seed_value)
	var eye := BotSenses.eye_of(b.character, tuning)
	var chest := BotSenses.body_point(_w.characters[1], tuning.hits, config.aim_height_fraction)
	b.aim_yaw = _look_at(eye, chest) + deg_to_rad(off)
	b.aim_pitch = BotAim.look_pitch(eye, chest)
	BotSenses.perceive(b, _w)
	assert_not_null(b.contact)
	return Vector2(b.contact.react_at - _w.time, _w.time - b.contact.acquired_at)


func test_answers_sooner_and_steadier_when_someone_steps_out_where_a_hard_bot_already_aims() -> void:
	var top := config.skill_for(&"hard")
	for seed_value in range(1, 21):
		var aimed := _sighting(&"hard", 0.0, seed_value)
		assert_between(aimed.x, top.pre_aim_reaction_time.x, top.pre_aim_reaction_time.y, "seed %d" % seed_value)
		assert_almost_eq(aimed.y, top.pre_aim_settled * top.aim_settle_time, 1e-5)
		var surprised := _sighting(&"hard", 30.0, seed_value)
		assert_between(surprised.x, top.reaction_time.x, top.reaction_time.y, "seed %d" % seed_value)
		assert_eq(surprised.y, 0.0)
	assert_lt(top.pre_aim_reaction_time.y, top.reaction_time.y, "the reason to slice corners slowly")


func test_changes_nothing_below_hard() -> void:
	for level: StringName in [&"easy", &"normal"]:
		var s := config.skill_for(level)
		assert_false(s.holds_angles, level)
		assert_false(s.slices_corners, level)
		assert_eq(s.peek_watch_time, Vector2.ZERO, level)
		assert_eq(s.pre_aim_reaction_time, s.reaction_time, level)
		assert_eq(s.pre_aim_settled, 0.0, level)
	for seed_value in range(1, 11):
		var aimed := _sighting(&"normal", 0.0, seed_value)
		assert_eq(aimed, _sighting(&"normal", 30.0, seed_value), "Normal reacts the same aimed or not")
		assert_eq(aimed.y, 0.0)


func test_hard_alone_holds_angles_and_is_no_quicker_than_normal_when_surprised() -> void:
	var top := config.skill_for(&"hard")
	var below := config.skill_for(&"normal")
	assert_true(top.holds_angles)
	assert_true(top.slices_corners)
	assert_almost_eq(top.pre_aim_reaction_time.x, 0.18, 1e-6)
	assert_almost_eq(top.pre_aim_reaction_time.y, 0.28, 1e-6)
	assert_between(top.pre_aim_settled, 0.01, 1.0)
	assert_gte(top.reaction_time.x, below.reaction_time.x)
	assert_gte(top.reaction_time.y, below.reaction_time.y)
	assert_eq(top.peek_watch_time, Vector2(1.5, 3.0))


# --- slicing ---

func test_slicing_aims_at_the_corner_ahead_and_leans_out_once_close() -> void:
	for start_z: float in [-3.0, 6.0]:
		var b := _bot(&"hard", _corner(), Vector3(30.0, 0.0, 30.0), 1, Vector3(0.0, 0.0, start_z))
		b.careful = true
		b.move_dir = Vector3(0.0, 0.0, -1.0)
		var cmd := PlayerCommand.new()
		for i in 60:
			cmd.lean = 0.0
			_idle_aim(b, true, cmd)
		assert_gt(b.held_angle_count, 0)
		var eye := BotSenses.eye_of(b.character, tuning)
		var a := b.held_angles[0]
		assert_lt(absf(wrapf(b.aim_yaw - _look_at(eye, a.point), -PI, PI)), deg_to_rad(1.0), "at the corner")
		var near := Vector2(a.point.x, a.point.z - start_z).length() <= config.slice_lean_distance
		assert_eq(cmd.lean, float(a.side) if near else 0.0, "leaning out only within %.0f m" % config.slice_lean_distance)
	# Not careful (or below Hard), it looks where it walks.
	var normal := _bot(&"normal", _corner(), Vector3(30.0, 0.0, 30.0), 1, Vector3(0.0, 0.0, -3.0))
	normal.move_dir = Vector3(0.0, 0.0, -1.0)
	var c := PlayerCommand.new()
	for i in 60:
		_idle_aim(normal, true, c)
	assert_lt(absf(normal.aim_yaw), deg_to_rad(0.5))
	assert_eq(c.lean, 0.0)


func test_slicing_towards_someone_heard_round_a_corner_aims_at_that_corner() -> void:
	var b := _bot(&"hard", _corner(), Vector3(30.0, 0.0, 30.0), 1, Vector3(0.0, 0.0, -3.0))
	b.careful = true
	b.mode = Bot.Mode.SEARCH
	b.has_last_known = true
	b.last_known = Vector3(-6.0, 0.0, -14.0) # behind the wall
	b.move_dir = Vector3(0.0, 0.0, -1.0)
	var cmd := PlayerCommand.new()
	for i in 60:
		_idle_aim(b, true, cmd)
	var eye := BotSenses.eye_of(b.character, tuning)
	var spot := Vector3(b.last_known.x, eye.y, b.last_known.z)
	assert_gt(absf(wrapf(b.aim_yaw - _look_at(eye, spot), -PI, PI)), deg_to_rad(10.0), "not at the hidden spot")
	assert_lt(absf(wrapf(b.aim_yaw - _look_at(eye, b.held_angles[0].point), -PI, PI)), deg_to_rad(1.0), "at the corner")


# --- watching, and reloading from cover ---

func test_hard_watches_where_someone_ducked_out_before_going_after_them_and_normal_goes_at_once() -> void:
	for level: StringName in [&"hard", &"normal"]:
		var b := _bot(level, WorldQuery.new(), Vector3(0.0, 0.0, -5.0))
		var foe := _w.characters[1]
		BotSenses.perceive(b, _w)
		b.mode = Bot.Mode.FIGHT
		_w.time += 1.0
		b.target_visible = false
		BotBrain._choose_mode(b, _w, foe, DT)
		assert_eq(b.mode, Bot.Mode.SEARCH, level)
		var watch := b.watch_until - _w.time
		if level == &"hard":
			assert_between(watch, 1.5, 3.0, "Hard watches the spot first")
			var cmd := PlayerCommand.new()
			assert_false(BotMovement._search(b, _w, cmd, DT), "and stays put meanwhile")
			assert_eq(b.route_state, Bot.RouteState.NONE)
			b.target_visible = true
			b.cover_cooldown = 1.0 # fights where it stands: no cover search on this bare floor
			BotBrain._choose_mode(b, _w, foe, DT)
			assert_eq(b.watch_until, -INF, "back in sight, the watch is over")
		else:
			assert_eq(b.watch_until, -INF, "Normal goes after them")


func test_a_corner_slicer_tops_up_only_from_cover_with_a_threat_in_mind() -> void:
	for level: StringName in [&"hard", &"normal"]:
		var b := _bot(level, WorldQuery.new(), Vector3(0.0, 0.0, -30.0))
		var a := b.character.armament
		a.ammo[a.active].mag = 1
		b.has_last_known = true
		b.heard_at = _w.time
		b.mode = Bot.Mode.COVER
		b.cover.position = Vector3(8.0, 0.0, 0.0)
		var cmd := PlayerCommand.new()
		BotCombat.reload_when_due(b, _w, cmd)
		assert_eq(cmd.reload, level != &"hard", "%s on the way to cover" % level)
		b.cover.position = Vector3.ZERO
		cmd.reload = false
		BotCombat.reload_when_due(b, _w, cmd)
		assert_true(cmd.reload, "%s once there" % level)


# --- the records ---

func test_a_hard_match_counts_for_the_records() -> void:
	var s := PlaySession.new()
	s.autopilot = true
	s.settings = Settings.new()
	s.difficulty = &"hard"
	add_child_autofree(s)
	await wait_physics_frames(2)
	assert_false(s.state.dev_content, "Hard, Pro as was, is public (owner, 2026-10-05)")
	assert_false(s.state.off_record)
	assert_true(s.counts_for_records())


# --- never aiming at someone unseen and unheard (M37) ---

func test_plays_the_same_tick_for_tick_wherever_a_hidden_silent_enemy_stands_at_every_level() -> void:
	var map := MapData.load_map("depot", MapStyle.new(), tuning.rounds.team_size)
	var level := MapLevel.new()
	add_child(level)
	level.build(map, MapStyle.new(), tuning.body)
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	for lv: StringName in LEVELS:
		_angled = false
		for seed_value: int in [1, 2]:
			var west := _hidden_run(map, level, nav, lv, seed_value, 0)
			var east := _hidden_run(map, level, nav, lv, seed_value, 1)
			assert_gt(_distinct(west), 20, "%s, seed %d: it moves and looks about" % [lv, seed_value])
			assert_eq(east, west, "%s, seed %d" % [lv, seed_value])
		# The watcher is the last of its team in play, so a level that plays the last bot carefully (BQ3) looks too.
		var s := config.skill_for(lv)
		assert_eq(_angled, s.holds_angles or s.slices_corners or s.careful_when_last,
				"%s: Hard's runs and a careful last bot's aim at corners, Easy's never look for them" % lv)
	level.free()


## Ten seconds of one bot (character 0, at `lv`) against the player standing still and silent in one of two closed huts
## off the field (`hut`), everyone else out: its commands each tick.
func _hidden_run(map: MapData, level: MapLevel, nav: NavGrid, lv: StringName, seed_value: int, hut: int) -> PackedStringArray:
	var sim := Simulation.new(tuning, level.query(), level.mover(tuning.body), map.ends, map.kill_y)
	sim.nav = nav
	var state := GameState.new(seed_value, tuning)
	var loadout := ReplicaStats.default_loadout()
	var commands: Array[PlayerCommand] = []
	var size := tuning.rounds.team_size
	for i in size * 2:
		state.characters.append(Character.new(i, 0 if i < size else 1, Vector3.ZERO, 0.0, loadout))
		commands.append(PlayerCommand.new())
	# The huts go in once the field's bounds are measured: the bots' rays read them from then on.
	var huts := BoxWorld.new()
	var levels: Dictionary[int, StringName] = {0: lv}
	var bots := BotController.new(state, size, map, nav, Both.new(level.query(), huts), tuning, config, levels)
	var lo := bots.world.planner.bounds_lo
	var hi := bots.world.planner.bounds_hi
	var mid := (lo.y + hi.y) * 0.5
	var spots: Array[Vector3] = [Vector3(lo.x - 8.0, 0.0, mid), Vector3(hi.x + 8.0, 0.0, mid)]
	for s in spots:
		huts.add_box(s + Vector3(0.0, 1.5, 0.0), Vector3(2.0, 3.0, 2.0))
	sim.start_match(state)
	bots.observe(state)
	for c in state.characters:
		if c.id != 0 and c.id != size:
			c.status = Character.Status.OUT
	var watcher := bots.world.bots[0]
	var player := state.characters[size]
	var out := PackedStringArray()
	var saw := false
	for t in roundi(10.0 / DT):
		player.position = spots[hut]
		player.velocity = Vector3.ZERO
		bots.think(state, commands, DT)
		var cmd := commands[0]
		out.append("%.6f %.6f %s %s %s %s %s" % [cmd.yaw, cmd.pitch, cmd.forward, cmd.right, cmd.fire, cmd.crouch,
				cmd.lean])
		saw = saw or watcher.target_visible
		_angled = _angled or watcher.held_angle_count > 0
		sim.step(state, commands, DT)
		bots.observe(state)
	assert_false(saw, "%s never sees into a hut" % lv)
	return out


func _distinct(ticks: PackedStringArray) -> int:
	var seen: Dictionary[String, bool] = {}
	for t in ticks:
		seen[t] = true
	return seen.size()
