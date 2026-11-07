extends GutTest
## Follow me and Regroup (SO2; the browser game's ai/squadOrders.test.ts, M22): followers keep a spot behind their
## giver's heading at the giver's pace and cover their back; the spots stay on the giver's side of walls, on their level
## and along ramps; Regroup sprints back and turns into Follow me (game/ai/squad_orders.gd, game/ai/bot_controller.gd).
## On an open field, headless: you (team 0, not a bot) with two bot teammates, and one opponent standing still far off
## that nobody drives; the spot tests on nav grids alone (a corridor, a thin wall, Depot, a ramp yard, a pit).

const DT := 1.0 / 60.0
const KILL_Y := -10.0
## Yaw that looks along +X.
const EAST := -PI * 0.5
const YOU := 0
const SPOTS: Array[Vector3] = [Vector3(-30.0, 0.0, 20.0), Vector3(-32.0, 0.0, 23.0), Vector3(-28.0, 0.0, 23.0),
		Vector3(40.0, 0.0, -40.0)]
## A body this slow stands still (m/s), as the browser's tests judge it.
const STILL := 0.5
## The spot tests' small field (m across): room enough round the origin, and quick to build.
const SMALL := 30.0

## The field's nav grids by whether the thin wall stands, built once for the file (a 100 m grid takes seconds; nothing
## here changes one).
var _navs: Dictionary[bool, NavGrid] = {}

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var squad: SquadConfig = config.squad

var nav: NavGrid = null
var state: GameState = null
var sim: Simulation = null
var bots: BotController = null
var commands: Array[PlayerCommand] = []
var cmd: PlayerCommand = null
var you: Character = null
var mates: Array[Bot] = []


## A 100 m square floor and `extra` blocks, as map data with its spawns and dead zones.
func _field_map(extra: Array[MapData.Block] = []) -> MapData:
	var m := MapData.new()
	m.id = "open field"
	m.kill_y = KILL_Y
	m.blocks.append(_block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(100.0, 0.5, 100.0)))
	m.blocks.append_array(extra)
	for e in 2:
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(SPOTS[i] if e == 0 else SPOTS[3] + Vector3(2.0 * i, 0.0, 0.0), EAST))
		end.dead_zone.append(SpawnPoint.new(Vector3(-45.0, 0.0, 45.0) if e == 0 else Vector3(45.0, 0.0, -45.0), 0.0))
		m.ends.append(end)
	return m


static func _block(kind: StringName, center: Vector3, size: Vector3, rise: MapData.Rise = MapData.Rise.NONE) \
		-> MapData.Block:
	var b := MapData.Block.new()
	b.kind = kind
	b.center = center
	b.size = size
	b.rise = rise
	return b


## The open field with a thin (0.4 m) wall along X at z 18.6 to 19.0, from x -40 to 40: walkable floor either side.
static func _thin_wall() -> Array[MapData.Block]:
	return [_block(&"wall", Vector3(0.0, 1.5, 18.8), Vector3(80.0, 3.0, 0.4))]


## The field's nav grid (with the thin wall if `thin_wall`), built once.
func _field_nav(thin_wall: bool) -> NavGrid:
	if not _navs.has(thin_wall):
		var extra: Array[MapData.Block] = []
		if thin_wall:
			extra = _thin_wall()
		_navs[thin_wall] = NavGrid.build(_field_map(extra), tuning.nav, tuning.body)
	return _navs[thin_wall]


## You and two bot teammates at SPOTS on the field (with the thin wall if `thin_wall`), the opponent far off and driven
## by nobody, round 1 live and half a second gone.
func _squad(thin_wall: bool = false) -> void:
	var extra: Array[MapData.Block] = []
	if thin_wall:
		extra = _thin_wall()
	var map := _field_map(extra)
	var w := BoxWorld.new(tuning.body)
	w.add_floor(100.0, 100.0)
	for b in extra:
		w.add_box(b.center, b.size)
	nav = _field_nav(thin_wall)
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
	bots.observe(state)
	# The opponent stands still: nobody fights.
	for b in bots.world.bots:
		if b.character.team == 1:
			bots.world.bots.erase(b)
			break
	for i in SPOTS.size():
		state.characters[i].position = SPOTS[i]
	you = state.characters[YOU]
	cmd = commands[YOU]
	cmd.reset(EAST, 0.0)
	mates.clear()
	mates.append_array(bots.world.bots)
	_run(0.5)


func _tick() -> void:
	bots.think(state, commands, DT)
	sim.step(state, commands, DT)
	bots.observe(state)


func _run(seconds: float) -> void:
	for t in roundi(seconds / DT):
		_tick()


## Gives `kind` through your command for one tick; returns the order in force after.
func _order(kind: SquadOrder.Kind) -> SquadOrder.Kind:
	cmd.squad_order = kind
	_tick()
	cmd.squad_order = SquadOrder.Kind.NONE
	return bots.order_of(YOU)


## A BotWorld for the spot tests: `grid` and the game's tuning, nothing else.
func _world(grid: NavGrid) -> BotWorld:
	var w := BotWorld.new()
	w.nav = grid
	w.cfg = config
	w.tuning = tuning
	return w


## A SMALL square floor round the origin.
static func _small_floor() -> MapData.Block:
	return _block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(SMALL, 0.5, SMALL))


func _nav(blocks: Array[MapData.Block]) -> NavGrid:
	var m := MapData.new()
	m.id = "test"
	m.blocks = blocks
	return NavGrid.build(m, tuning.nav, tuning.body)


func _leader(at: Vector3, yaw: float = EAST) -> Character:
	var c := Character.new(0, 0, at, yaw, ReplicaStats.default_loadout())
	c.position = at
	return c


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _speed(c: Character) -> float:
	return Vector2(c.velocity.x, c.velocity.z).length()


func test_followers_keep_up_behind_you_as_you_move_then_stop_and_cover_your_back() -> void:
	_squad()
	_run(0.1)
	assert_eq(_order(SquadOrder.Kind.FOLLOW), SquadOrder.Kind.FOLLOW)
	cmd.forward = 1.0
	var worst := 0.0
	var ticks := 0
	var watched := 0
	var settle_ticks := roundi(2.0 / DT)
	for t in roundi(10.0 / DT):
		_tick()
		for b in mates:
			worst = maxf(worst, _flat(b.character.position, you.position))
		# Someone keeps looking back the way you came on the move too (once settled in behind you).
		ticks += 1
		if ticks > settle_ticks:
			for b in mates:
				if absf(wrapf(b.character.yaw - EAST - PI, -PI, PI)) < PI / 3.0:
					watched += 1
					break
	assert_gt(float(watched) / (ticks - settle_ticks), 0.6, "someone covers your back on the move")
	assert_gt(you.position.x, 5.0, "you went a long way east")
	assert_lt(worst, squad.catch_up + 3.0, "never left far behind")
	cmd.forward = 0.0
	_run(4.0)
	var looks: Array[float] = []
	for b in mates:
		var d := _flat(b.character.position, you.position)
		assert_gt(d, 1.5, "not inside you")
		assert_lt(d, squad.follow_distance + squad.follow_arrive + 1.0, "at its spot")
		assert_lt(b.character.position.x, you.position.x, "behind you, not in front")
		assert_eq(b.mode, Bot.Mode.ORDER)
		looks.append(absf(wrapf(b.character.yaw - EAST, -PI, PI)))
	# Once there, one looks back the way you came (west) and the other to a side: someone covers your back.
	assert_gt(looks.max(), PI * 0.75)
	assert_gt(looks.min(), PI * 0.35)
	assert_gt(_flat(mates[0].character.position, mates[1].character.position), 1.0, "at different spots")


## You go east at `pace` (0 walk, 1 run, 2 sprint) for `seconds` with Follow me given (weaving 0.4 rad either way
## every 1.5 s if `weave`). Returns, per teammate, the longest run of ticks it stood still and its mean distance behind
## you once settled in (after 3 s: one starting ahead of its spot waits for it), then how often its sprint turned on or
## off.
func _follow_along(pace: int, seconds: float, weave: bool = false) -> Array[PackedFloat32Array]:
	_squad()
	_run(0.1)
	_order(SquadOrder.Kind.FOLLOW)
	cmd.forward = 1.0
	cmd.walk = pace == 0
	cmd.sprint = pace == 2
	var n := mates.size()
	var stood := PackedFloat32Array()
	var longest := PackedFloat32Array()
	var behind := PackedFloat32Array()
	var flips := PackedFloat32Array()
	var sprinted := PackedByteArray()
	stood.resize(n)
	longest.resize(n)
	behind.resize(n)
	flips.resize(n)
	sprinted.resize(n)
	var t := 0.0
	var settled := 0
	for k in roundi(seconds / DT):
		t += DT
		if weave:
			cmd.yaw = EAST + (0.4 if floori(t / 1.5) % 2 == 0 else -0.4)
		_tick()
		for i in n:
			var c := mates[i].character
			stood[i] = 0.0 if _speed(c) > STILL else stood[i] + 1.0
			if t > 3.0:
				longest[i] = maxf(longest[i], stood[i])
				behind[i] += _flat(c.position, you.position)
			var s := 1 if commands[c.id].sprint else 0
			if s != sprinted[i]:
				flips[i] += 1.0
			sprinted[i] = s
		if t > 3.0:
			settled += 1
	for i in n:
		behind[i] /= settled
	return [longest, behind, flips]


func test_followers_keep_moving_with_you_at_your_pace_a_few_metres_back() -> void:
	for pace in 3:
		var r := _follow_along(pace, 7.0 if pace == 2 else 9.0)
		var at := ["walk", "run", "sprint"][pace] as String
		for i in mates.size():
			assert_lte(r[0][i], 6.0, "%s: never a stop-and-go" % at)
			assert_gt(r[1][i], squad.follow_distance - 1.0, "%s: a few metres back" % at)
			# On average within arriving distance of its spot (browser, 2026-10-16: walk 3.62 / 3.22, run 3.30 / 3.59,
			# sprint 3.13 / 2.72 m).
			assert_lt(r[1][i], squad.follow_distance + squad.follow_arrive, "%s: close behind" % at)
			assert_lte(r[2][i], 3.0 if pace == 2 else 2.0, "%s: the sprint doesn't flick on and off" % at)
	# Sprinting along with you as you weave: on once, and off no more than once or twice.
	var weaving := _follow_along(2, 7.0, true)
	for i in mates.size():
		assert_lte(weaving[2][i], 3.0, "weaving: the sprint doesn't flick on and off")


## You sprint east with Follow me given and teammate 0 put `gap` m straight behind you; over `seconds`, returns its
## gap to you at the end and the most it was boosted (PlayerCommand.catch_up) while within catch_up_boost_from.
func _chase_from(gap: float, seconds: float) -> PackedFloat32Array:
	_squad()
	_run(0.1)
	_order(SquadOrder.Kind.FOLLOW)
	cmd.forward = 1.0
	cmd.sprint = true
	_run(1.0)
	var c := mates[0].character
	c.position = you.position - Vector3(gap, 0.0, 0.0)
	c.velocity = you.velocity
	var boosted_near := 0.0
	var boosted := 0.0
	for k in roundi(seconds / DT):
		_tick()
		if commands[c.id].catch_up:
			boosted += 1.0
			if _flat(c.position, you.position) < squad.catch_up_boost_from - 0.5:
				boosted_near += 1.0
	return PackedFloat32Array([_flat(c.position, you.position), boosted, boosted_near])


func test_a_follower_far_behind_a_sprinting_leader_runs_faster_until_within_reach_then_keeps_pace() -> void:
	# The owner's card B6 (2026-11-07): more than catch_up_boost_from behind, faster than a sprint; nearer, the
	# leader's pace. Without the boost (scale 1) the gap stays about where it was.
	var move := tuning.movement
	var scale := move.catch_up_sprint_scale
	assert_gt(scale, 1.0)
	move.catch_up_sprint_scale = 1.0
	var flat := _chase_from(12.0, 6.0)
	move.catch_up_sprint_scale = scale
	var r := _chase_from(12.0, 6.0)
	gut.p("12 m behind a sprinting leader, 6 s on: %.2f m with the boost, %.2f m without; boosted %d ticks" % [r[0],
			flat[0], int(r[1])])
	assert_gt(r[1], 0.0, "the far follower is boosted")
	assert_eq(r[2], 0.0, "never boosted within catch_up_boost_from")
	assert_lt(r[0], squad.catch_up_boost_from + 0.5, "it closes to within reach")
	assert_lt(r[0], flat[0] - 2.0, "faster than without the boost")


func test_the_catch_up_boost_speeds_only_a_sprint() -> void:
	var move := tuning.movement
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.sprinting = true
	var base := Movement.target_speed(c, move, false)
	var w := BoxWorld.new(tuning.body)
	w.add_floor(40.0, 40.0)
	var command := PlayerCommand.new()
	command.forward = 1.0
	command.sprint = true
	command.catch_up = true
	for i in 120:
		Movement.step(c, command, move, tuning.accuracy, DT, w.mover())
	assert_almost_eq(_speed(c), base * move.catch_up_sprint_scale, 1e-3, "a boosted sprint")
	command.sprint = false
	command.walk = true
	for i in 120:
		Movement.step(c, command, move, tuning.accuracy, DT, w.mover())
	assert_almost_eq(_speed(c), move.walk_speed, 1e-3, "never a walk")


func test_regroup_sprints_back_to_you_then_follows() -> void:
	_squad()
	cmd.pitch = -0.2
	_run(0.3)
	_order(SquadOrder.Kind.HOLD)
	_run(5.0)
	# Walk on well past them, then call them back.
	cmd.pitch = 0.0
	cmd.forward = 1.0
	_run(7.0)
	cmd.forward = 0.0
	_run(0.5)
	for b in mates:
		assert_gt(_flat(b.character.position, you.position), 18.0, "far off")
	assert_eq(_order(SquadOrder.Kind.REGROUP), SquadOrder.Kind.REGROUP)
	var sprinted := false
	# The order reads Regroup until every teammate is back, never flipping between the two.
	var flips := 0
	var last := bots.order_of(YOU)
	for t in roundi(10.0 / DT):
		_tick()
		for b in mates:
			sprinted = sprinted or commands[b.character.id].sprint
		if bots.order_of(YOU) != last:
			flips += 1
		last = bots.order_of(YOU)
	assert_eq(flips, 1)
	assert_true(sprinted, "they sprint back")
	for b in mates:
		assert_lt(_flat(b.character.position, you.position), squad.follow_distance + squad.follow_row_gap + 2.0)
		assert_eq(b.order, SquadOrder.Kind.FOLLOW)
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.FOLLOW)


func test_in_a_corridor_too_narrow_for_the_side_spots_straight_behind_you_never_inside_you() -> void:
	# A 3 m wide corridor along X: walls at z -1.5 and 1.5.
	var corridor := _nav([_small_floor(), _block(&"wall", Vector3(0.0, 1.5, -2.0), Vector3(SMALL, 3.0, 1.0)),
			_block(&"wall", Vector3(0.0, 1.5, 2.0), Vector3(SMALL, 3.0, 1.0))])
	var leader := _leader(Vector3.ZERO)
	for slot in 2:
		var out := SquadOrders.follow_spot(leader, EAST, slot, _world(corridor))
		# Walking east, the spot is behind (west of) you at the follow distance, in the middle of the corridor.
		assert_almost_eq(out.x, -squad.follow_distance, 0.05, "slot %d" % slot)
		assert_lt(absf(out.z), 0.01, "slot %d" % slot)
	# In the open the side spots stand.
	var open := _nav([_small_floor()])
	assert_gt(absf(SquadOrders.follow_spot(leader, EAST, 0, _world(open)).z), 1.5)


func test_beside_a_thin_wall_no_spot_on_its_far_side_so_nobody_detours_round_it() -> void:
	# A side spot 3.2 m back at 40 degrees would be 2.1 m to the side: through the wall, on walkable floor.
	var walled := _field_nav(true)
	var w := _world(walled)
	assert_true(walled.is_walkable_at(Vector3(0.0, 0.0, 17.9)), "floor beyond the wall")
	for z: float in [20.0, 19.3]:
		# 19.3: you touching the wall, inside the margin the nav grid keeps from it.
		var leader := _leader(Vector3(0.0, 0.0, z))
		for slot in 2:
			var out := SquadOrders.follow_spot(leader, EAST, slot, w)
			assert_gt(out.z, 19.0, "slot %d at z %.1f: your side" % [slot, z])
			assert_lt(out.x, -1.0, "slot %d at z %.1f: behind you, not at you" % [slot, z])
			assert_true(walled.clear_line(Vector3(0.0, 0.0, 20.0), out))
	# Walking east along the wall: both followers stay on your side of it and never take a long way round.
	_squad(true)
	_run(0.1)
	_order(SquadOrder.Kind.FOLLOW)
	cmd.forward = 1.0
	var worst_detour := 0.0
	var crossed := 0
	for t in roundi(10.0 / DT):
		_tick()
		if you.position.z <= 19.0:
			crossed += 1
		for b in mates:
			var p := b.character.position
			if p.z <= 19.0:
				crossed += 1
			if b.route_state != Bot.RouteState.OK or b.route_leg >= b.route.size():
				continue
			var length := 0.0
			var from := p
			for i in range(b.route_leg, b.route.size()):
				length += _flat(from, b.route[i])
				from = b.route[i]
			worst_detour = maxf(worst_detour, length / maxf(1.0, _flat(p, from)))
	assert_eq(crossed, 0, "everyone stays on your side of the wall")
	assert_gt(you.position.x, 5.0)
	assert_lt(worst_detour, 1.5, "nobody takes a long way round")
	for b in mates:
		assert_lt(_flat(b.character.position, you.position), squad.catch_up)


func test_on_a_ramp_and_while_you_jump_spots_lie_along_the_slope_never_at_you() -> void:
	# Depot's west dock ramp runs up east from x -4.4 to -2 at z about -14.6 (1.2 m over 2.4 m).
	var depot := YardMap.load_map(MapStyle.new(), tuning.rounds.team_size) # its dock ramp (DR1)
	var grid := NavGrid.build(depot, tuning.nav, tuning.body)
	var w := _world(grid)
	var leader := _leader(Vector3.ZERO)
	for x: float in [-3.6, -3.2, -2.6]:
		leader.position = Vector3(x, grid.floor_at(Vector3(x, 0.0, -14.0)), -14.0)
		assert_gt(leader.position.y, 0.1, "on the slope at x %.1f" % x)
		for slot in 2:
			var out := SquadOrders.follow_spot(leader, EAST, slot, w)
			assert_gt(_flat(out, leader.position), 2.0, "slot %d at x %.1f: not at you" % [slot, x])
			assert_almost_eq(out.y, grid.floor_at(out), 1e-4, "on the floor there, not at your height")
	# In the air over open ground: the same spots as standing there.
	leader.position = Vector3(10.0, 0.0, 0.0)
	var standing := SquadOrders.follow_spot(leader, EAST, 0, w)
	leader.position.y = 0.4
	assert_gt(_flat(standing, leader.position), 2.0)
	assert_eq(SquadOrders.follow_spot(leader, EAST, 0, w), standing, "jumping changes nothing")
	# Hold here at a point on the ramp, looking north across the slope: two spots apart, each on the floor there.
	leader.yaw = 0.0
	var point := Vector3(-3.2, grid.floor_at(Vector3(-3.2, 0.0, -14.4)), -14.4)
	var holders: Array[Bot] = []
	for i in 2:
		holders.append(Bot.new(leader, 1, config.skill, 1))
	SquadOrders.place_hold(holders, leader, point, w)
	assert_almost_eq(_flat(holders[0].order_goal, holders[1].order_goal), squad.hold_spacing, 1e-4)
	for b in holders:
		assert_almost_eq(b.order_goal.y, grid.floor_at(b.order_goal), 1e-4)


## The browser's Ramp Yard: a walled 40 x 16 m yard whose middle is a 1 m platform (x -6 to 6) wall to wall, a 1:2 ramp
## up to it at each end (3 m wide, its sides open drops), a wall splitting the platform and a crate per lane and side.
func _ramp_yard() -> NavGrid:
	var blocks: Array[MapData.Block] = [
		_block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(40.0, 0.5, 16.0)),
		_block(&"floor", Vector3(0.0, 0.5, 0.0), Vector3(12.0, 1.0, 16.0)),
		_block(&"ramp", Vector3(-7.0, 0.5, 0.0), Vector3(2.0, 1.0, 3.0), MapData.Rise.POS_X),
		_block(&"ramp", Vector3(7.0, 0.5, 0.0), Vector3(2.0, 1.0, 3.0), MapData.Rise.NEG_X),
		_block(&"wall", Vector3(0.0, 2.5, 0.0), Vector3(0.4, 3.0, 8.0)),
		_block(&"wall", Vector3(0.0, 1.5, -8.2), Vector3(40.8, 3.0, 0.4)),
		_block(&"wall", Vector3(0.0, 1.5, 8.2), Vector3(40.8, 3.0, 0.4)),
		_block(&"wall", Vector3(-20.2, 1.5, 0.0), Vector3(0.4, 3.0, 16.0)),
		_block(&"wall", Vector3(20.2, 1.5, 0.0), Vector3(0.4, 3.0, 16.0)),
	]
	for x: float in [-4.5, 4.5]:
		for z: float in [-5.5, 5.5]:
			blocks.append(_block(&"crate", Vector3(x, 1.6, z), Vector3(1.2, 1.2, 1.2)))
	return _nav(blocks)


func test_at_a_platform_lip_spots_stay_up_on_your_level_or_on_you_never_on_the_ground_below() -> void:
	# The platform is 1 m up and ends at x 6 away from the ramps (|z| > 1.5): an open drop to the ground.
	var grid := _ramp_yard()
	var w := _world(grid)
	var leader := _leader(Vector3.ZERO)
	leader.grounded = true
	var snapped := 0
	var below := 0
	# Looking back west across the platform, the spots behind you are past the drop: measured from the nearest walkable
	# cell, which at the lip can be on the ground, they were down there.
	for heading: float in [EAST, -EAST, 0.0, PI]:
		for x: float in [5.7, 5.8, 5.9, 6.0, 6.1, 6.2, 6.3]:
			leader.position = Vector3(x, 1.0, 5.0)
			if not grid.is_walkable_at(Vector3(x, 0.0, 5.0)):
				snapped += 1
			for slot in 4:
				var out := SquadOrders.follow_spot(leader, heading, slot, w)
				if out != leader.position and not grid.floor_at(out) > 0.9:
					below += 1
	assert_eq(below, 0, "no spot on the ground below")
	assert_gt(snapped, 0, "the lip is inside the margin the nav grid keeps from the drop")


func test_at_the_foot_of_a_ramp_inside_the_margin_spots_are_measured_from_the_ground_beside_you() -> void:
	# The ramps run 2 m from the ground up to the platform, 3 m wide, their sides open. At a foot corner you can stand
	# more than a step up the slope, inside the margin, with the nearest walkable cell on the ground beside you and no
	# drop between: the spots are measured from that cell (the lip test's fallback, that keeps them on you, is for a
	# drop).
	var grid := _ramp_yard()
	var w := _world(grid)
	var leader := _leader(Vector3.ZERO)
	leader.grounded = true
	var corners := 0
	var wrong := 0
	for i in 41:
		for j in 81:
			for side: float in [-1.0, 1.0]:
				var at := Vector3(side * (7.2 + i * 0.025), 0.5, -2.0 + j * 0.05)
				at.y = grid.floor_at(at)
				if not at.y > grid.max_step or grid.is_walkable_at(at):
					continue
				var k := grid.nearest_walkable(at, squad.follow_line_snap)
				if k < 0 or absf(grid.floor_y[k] - at.y) <= grid.max_step \
						or grid.drop_on_line(at, grid.node_position(k)):
					continue
				corners += 1
				leader.position = at
				# Facing up the ramp the spots behind you are out on the open ground: never on you. Facing any other
				# way they may be (nothing walkable in a straight line behind: follow_spot's last fallback), else on
				# the floor there.
				var up_ramp := EAST if side < 0.0 else -EAST
				for heading: float in [EAST, -EAST, 0.0, PI]:
					for slot in 2:
						var out := SquadOrders.follow_spot(leader, heading, slot, w)
						if heading == up_ramp and _flat(out, at) \
								<= squad.follow_distance - squad.follow_fallback_step - 1.0:
							wrong += 1
						if out == at:
							continue
						if not grid.is_walkable_at(out) or absf(out.y - grid.floor_at(out)) > 1e-4 or out.y >= at.y:
							wrong += 1
	assert_gt(corners, 0, "standing spots at the ramp feet that take the branch")
	assert_eq(wrong, 0, "spots on the ground the spots are measured from, never on you facing up the ramp")


## A bot at `start` given Follow me by `leader` as its first follower.
func _follower(leader: Character, start: Vector3) -> Bot:
	var b := Bot.new(Character.new(1, 0, start, EAST, ReplicaStats.default_loadout()), 1, config.skill, 3)
	b.character.position = start
	SquadOrders.start(b, leader, SquadOrder.Kind.FOLLOW, 0)
	return b


func test_steers_by_the_line_it_checked_when_the_blended_direction_runs_off_a_drop() -> void:
	# You run east at 5 m/s; the follower stands 1 m to the side of its spot (away from you), with a pit just east of
	# it. Pursuit (your velocity plus a pull to the spot) points mostly east, over the edge; the line to the spot is
	# clear.
	var leader := _leader(Vector3.ZERO)
	leader.velocity = Vector3(5.0, 0.0, 0.0)
	var floor_all := _small_floor()
	var open := _nav([floor_all])
	var g := SquadOrders.follow_spot(leader, EAST, 0, _world(open))
	var s := signf(g.z - leader.position.z)
	var start := Vector3(g.x, 0.0, g.z + s)
	# The field's floor round a pit 1.5 m wide (x) starting 0.5 m east of the follower, beside it and beyond it.
	var x0 := start.x + 0.5
	var x1 := start.x + 2.0
	var z0 := minf(start.z - 0.3 * s, start.z + 2.0 * s)
	var z1 := maxf(start.z - 0.3 * s, start.z + 2.0 * s)
	var edge := SMALL * 0.5
	var pit := _nav([_floor(-edge, x0, -edge, edge), _floor(x1, edge, -edge, edge), _floor(x0, x1, -edge, z0),
			_floor(x0, x1, z1, edge)])
	# A wall there instead: walls only stop you (you slide along them), so they don't change the way.
	var walled := _nav([floor_all, _block(&"wall", Vector3((x0 + x1) * 0.5, 1.5, (z0 + z1) * 0.5),
			Vector3(x1 - x0, 3.0, z1 - z0))])
	var reach := config.edge_lookahead
	var dirs: Array[Vector3] = []
	for grid: NavGrid in [open, walled, pit]:
		var b := _follower(leader, start)
		assert_true(SquadOrders.move(b, _world(grid), PlayerCommand.new(), DT), "it walks")
		assert_almost_eq(b.order_goal.x, g.x, 1e-4, "the same spot with the pit there")
		assert_almost_eq(b.order_goal.z, g.z, 1e-4)
		dirs.append(b.move_dir)
	# In the open: mostly your way, which here runs into the pit.
	assert_gt(dirs[0].x, 0.8)
	assert_true(pit.drop_on_line(start, start + dirs[0] * reach))
	assert_almost_eq(dirs[1], dirs[0], Vector3.ONE * 1e-6, "a wall changes nothing")
	# By the pit: straight at the spot, along the line that was checked.
	assert_almost_eq(dirs[2].x, 0.0, 1e-4)
	assert_almost_eq(dirs[2].z, -s, 1e-4)
	assert_false(pit.drop_on_line(start, start + dirs[2] * reach))


static func _floor(ax: float, bx: float, az: float, bz: float) -> MapData.Block:
	return _block(&"floor", Vector3((ax + bx) * 0.5, -0.25, (az + bz) * 0.5), Vector3(bx - ax, 0.5, bz - az))


func test_with_no_straight_way_to_the_spot_round_the_way_you_went_while_you_move() -> void:
	# Depot seed 2 (G11): as the spots swung round behind a leader turning while they sprinted, a follower's spot slid
	# to the far side of a container; the route there went round its other end, then flipped back with the next swing.
	# Here you run east past a wall; the follower stands beyond it from its spot, which you can walk to in a straight
	# line but it can't.
	var leader := _leader(Vector3.ZERO)
	var floor_all := _small_floor()
	var g := SquadOrders.follow_spot(leader, EAST, 0, _world(_nav([floor_all])))
	var start := Vector3(g.x - 3.0, 0.0, g.z)
	var walled := _nav([floor_all, _block(&"wall", Vector3(g.x - 1.5, 1.5, g.z), Vector3(0.4, 3.0, 4.0))])
	assert_false(walled.clear_line(start, g), "no straight way")
	# You on the move: the route goes to you (the way you went), which can't flip as the spot swings.
	leader.velocity = Vector3(5.0, 0.0, 0.0)
	var b := _follower(leader, start)
	SquadOrders.move(b, _world(walled), PlayerCommand.new(), DT)
	assert_almost_eq(b.order_goal.x, g.x, 1e-4, "the spot is the same with the wall there")
	assert_eq(b.route_state, Bot.RouteState.WANTED)
	assert_lt(_flat(b.route_goal, leader.position), 0.01, "a route to you")
	# You standing still: to the spot, to settle there.
	leader.velocity = Vector3.ZERO
	b = _follower(leader, start)
	SquadOrders.move(b, _world(walled), PlayerCommand.new(), DT)
	assert_eq(b.route_state, Bot.RouteState.WANTED)
	assert_lt(_flat(b.route_goal, g), 0.01, "a route to the spot")


func test_ticks_with_followers_allocate_nothing() -> void:
	_squad()
	_order(SquadOrder.Kind.FOLLOW)
	cmd.forward = 1.0
	# Warm first (the tick's event pool and the routes grow to their most), then the same walk again.
	_weaving_walk(480)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	_weaving_walk(480)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before, "following you as you walk and turn")
	cmd.forward = 0.0
	_run(2.0)
	before = Performance.get_monitor(Performance.OBJECT_COUNT)
	_run(2.0)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before, "settled behind you")


## `ticks` ticks turning a quarter left or right every two seconds, so the followers' spots keep swinging round.
func _weaving_walk(ticks: int) -> void:
	for t in ticks:
		if t % 120 == 0:
			cmd.yaw = EAST + (0.5 * PI if t % 240 == 0 else 0.0)
		_tick()


func test_an_order_from_a_giver_out_of_play_gives_nothing_and_waits_for_the_next_round() -> void:
	_squad()
	assert_eq(_order(SquadOrder.Kind.FOLLOW), SquadOrder.Kind.FOLLOW)
	# Hit in the tick it gave the order: the simulation took it, but the giver is out by the time it is handed out.
	you.status = Character.Status.CALLING
	assert_eq(bots.give_order(you, SquadOrder.Kind.HOLD), SquadOrder.Kind.NONE)
	assert_eq(bots.order_outcome.notice, SquadOrders.Notice.NOT_NOW, "not NOBODY: the teammates are there")
	assert_eq(bots.order_of(YOU), SquadOrder.Kind.NONE)
	for b in mates:
		assert_eq(b.order, SquadOrder.Kind.NONE, "the order in force ended with the giver")


func test_a_bot_handed_an_order_is_no_moving_partner_on_its_lane() -> void:
	_squad()
	var b := mates[0]
	var o := mates[1]
	o.lane = b.lane
	o.mode = Bot.Mode.ADVANCE
	o.hunting = false
	o.holding = false
	o.route_state = Bot.RouteState.OK
	o.character.position = b.character.position + Vector3(1.0, 0.0, 0.0)
	assert_true(BotMovement._partner_moving(b, bots.world), "on the plan, it is the partner on the move")
	# Handed an order this tick, before its brain turns it to ORDER mode.
	SquadOrders.start(o, you, SquadOrder.Kind.FOLLOW, 0)
	assert_false(BotMovement._partner_moving(b, bots.world))
