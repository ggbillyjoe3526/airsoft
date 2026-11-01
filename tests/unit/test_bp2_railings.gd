extends GutTest
## BP2 after SR1 (KNOWN_ISSUES, SR1's AI row): a bar railing muffles no sound, and the bot checks that read a railing's
## box as solid (held angles, slicing towards a last-known spot, the crossfire spot, the ping's floor spot) see or
## shoot through it, as sight, cover and shots already did. Glass still muffles and still stops a held angle.

const EAST := -PI * 0.5

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var sound: SoundConfig = SoundConfig.new()
var hit: RayHit = RayHit.new()


## A floor, and across the line east of the origin at x = 4 either a bar railing or a wall, both 2 m tall.
func _world(railing: bool) -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(80.0, 80.0)
	if railing:
		w.add_railing(Vector3(4.0, 1.0, 0.0), Vector3(0.08, 2.0, 60.0))
	else:
		w.add_box(Vector3(4.0, 1.0, 0.0), Vector3(0.08, 2.0, 60.0))
	return w


func test_someone_behind_a_railing_is_heard_open_and_behind_a_wall_muffled() -> void:
	var heights := PackedFloat64Array()
	for h in sound.occlusion_ray_heights:
		heights.append(h)
	var ear := Vector3(0.0, tuning.body.stand_eye_height, 0.0)
	var feet := Vector3(8.0, 0.0, 0.0)
	assert_eq(SoundPath.blocked_share(_world(true), ear, feet, heights, hit), 0.0, "bars muffle nothing")
	assert_eq(SoundPath.blocked_share(_world(false), ear, feet, heights, hit), 1.0, "a wall still does")
	assert_false(SoundPath.line_blocked(_world(true), ear, feet, sound.occlusion_surface_gap, hit))


func test_a_bb_striking_beyond_a_railing_or_on_its_bar_is_heard_open() -> void:
	for railing: bool in [true, false]:
		var w := _world(railing)
		var occ := SoundOcclusion.new(sound, w)
		var you := Character.new(0, 0, Vector3.ZERO, EAST)
		var mine: Array[Character] = [you]
		occ.begin_tick(mine, you, you.eye(tuning.body))
		# A strike on the railing's far bar face, and one on the ground beyond it, both flying east.
		var on_bar := occ.impact_share(Vector3(4.04, 1.0, 0.0), Vector3(-60.0, 0.0, 0.0))
		var beyond := occ.impact_share(Vector3(9.0, 0.0, 0.0), Vector3(60.0, -5.0, 0.0))
		if railing:
			assert_eq(on_bar, 0.0, "a BB ringing off a bar plays open")
			assert_eq(beyond, 0.0, "one landing beyond the bars plays open")
		else:
			assert_eq(beyond, 1.0, "beyond a wall it is muffled")


func test_a_held_angle_runs_on_past_a_railing_to_the_corner_beyond_it() -> void:
	# Past the line at x = 4: a wall at x = 12 from z = -1 north, its end a corner someone could step round.
	var out: Array[BotAngles.HeldAngle] = [BotAngles.HeldAngle.new(), BotAngles.HeldAngle.new()]
	var eye := Vector3(0.0, tuning.body.stand_eye_height, 0.0)
	for railing: bool in [true, false]:
		var w := _world(railing)
		w.add_box(Vector3(12.0, 1.5, -15.5), Vector3(0.3, 3.0, 29.0))
		var found := BotAngles.find(w, eye, eye.y, EAST, config, out)
		var far := 0
		for k in found:
			if out[k].point.x > 4.5:
				far += 1
		if railing:
			assert_gt(far, 0, "the corner beyond the bars is an angle to hold")
		else:
			assert_eq(far, 0, "behind a wall it is out of sight")


func test_a_bot_closing_on_a_spot_seen_through_a_railing_watches_it_rather_than_slicing() -> void:
	var eye := Vector3(0.0, tuning.body.stand_eye_height, 0.0)
	var head := Vector3(8.0, tuning.body.stand_eye_height, 0.0)
	assert_true(BotSenses.sight_clear(_world(true), eye, head), "the spot is in plain view through the bars")
	assert_false(BotSenses.sight_clear(_world(false), eye, head), "behind a wall it is round a corner")


func test_a_ping_through_a_railing_lands_on_the_ground_beyond_it() -> void:
	for railing: bool in [true, false]:
		var w := _world(railing)
		var ends: Array[MapEnd] = []
		for e in 2:
			var end := MapEnd.new()
			end.spawns.append(SpawnPoint.new(Vector3(0.0 if e == 0 else 30.0, 0.0, 0.0), EAST))
			end.dead_zone.append(SpawnPoint.new(Vector3(-30.0 if e == 0 else 35.0, 0.0, 20.0), 0.0))
			ends.append(end)
		var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
		var s := GameState.new(5, tuning)
		s.round_state.practice = true
		var you := Character.new(0, 0, Vector3.ZERO, EAST, ReplicaStats.default_loadout())
		s.characters.append(you)
		sim.start_match(s)
		you.position = Vector3.ZERO
		you.yaw = EAST
		you.pitch = -0.15
		var cmd := PlayerCommand.new()
		cmd.reset(EAST, -0.15)
		cmd.ping = true
		var cmds: Array[PlayerCommand] = [cmd]
		s.events.clear()
		# The ping as a live round's tick casts it (Simulation.step pings only in a live round, not on the range).
		sim._ping(you, cmds, true, s.events)
		var reach := -1.0
		for i in s.events.count:
			var e := s.events.items[i]
			if e.kind == GameEvent.Kind.PING and e.value == 1:
				reach = e.reach
		assert_gt(reach, 0.0, "the ping met something")
		if railing:
			assert_gt(reach, 5.0, "the ground beyond the bars, not the railing")
		else:
			assert_lt(reach, 4.5, "the wall")
