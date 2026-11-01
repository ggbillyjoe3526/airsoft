extends GutTest
## QA hunt on Woodland's doors, two flags and 3:00 rounds (WR2): a body walks through each hut doorway both ways
## opening the shut door as a bot does, nobody is trapped by a shut door, the round time applies to a Skirmish on
## Woodland only, and the Round column's edge cases.

const DT := 1.0 / 60.0
const SIDE := 5
const THROUGH := 2.0
const WALK_TICKS := 360

var tuning: SimTuning = SimTuning.load_default()
var style: MapStyle = PlayTuning.load_default().map_style
var map: MapData = null
var level: MapLevel = null
var loadout: Array[ReplicaConfig] = []


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()
	map = MapData.load_map("woodland", style, SIDE)
	level = MapLevel.new()
	add_child(level)
	level.build(map, style, tuning.body)


func after_all() -> void:
	level.free()
	level = null


## [Simulation, GameState] on the level, practice rules (no round freeze), a character 0 at `at`.
func _match() -> Array:
	var sim := Simulation.new(tuning, level.query(), level.mover(tuning.body), map.ends, map.kill_y)
	var state := GameState.new(3, tuning)
	state.round_state.practice = true
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	state.characters.append(Character.new(1, 1, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	return [sim, state]


func _outward(i: int) -> Vector2:
	var d := map.doors[i]
	return Vector2(float(d.side), 0.0) if d.size.x < d.size.z else Vector2(0.0, float(d.side))


## Walks character 0 from `from` towards `to` as a bot does (opening the shut door in its way): the end position.
func _walk(i: int, from: Vector2, to: Vector2) -> Array:
	var r: Array = _match()
	var sim: Simulation = r[0]
	var state: GameState = r[1]
	var c := state.characters[0]
	var y := map.terrain.height_at(from.x, from.y)
	c.position = Vector3(from.x, y + 0.04, from.y)
	c.prev_position = c.position
	c.grounded = true
	var way := (to - from).normalized()
	var opened := false
	for t in WALK_TICKS:
		var cmd := PlayerCommand.new()
		cmd.reset(atan2(-way.x, -way.y), 0.0)
		cmd.forward = 1.0
		cmd.door_to_use = Doors.shut_ahead(sim.query, tuning.doors, state.doors, c.position, way)
		cmd.use_door = cmd.door_to_use >= 0
		var cmds: Array[PlayerCommand] = [cmd, null]
		sim.step(state, cmds, DT)
		opened = opened or not state.doors.is_shut(i)
	return [c.position, opened, state]


func test_a_bot_walks_in_and_out_of_each_hut_doorway_opening_the_shut_leaf() -> void:
	assert_eq(map.doors.size(), 8)
	for i in map.doors.size():
		var d := map.doors[i]
		var out := _outward(i)
		var mid := Vector2(d.center.x, d.center.z)
		# Hut row's east door (door 0) opens onto a wall 1.4 m beyond its leaf (BP2 hung the doors on their jambs' outer
		# face): start clear of it, and count a walk out as out once it is a body's width past the leaf.
		var outside := mid + out * 1.1
		var inside := mid - out * 2.5
		var r := _walk(i, outside, inside)
		var got := Vector2((r[0] as Vector3).x, (r[0] as Vector3).z)
		assert_gt((got - mid).dot(-out), 1.2, "door %d at %s: in from outside (ended %s)" % [i, d.center, got])
		if d.shut:
			assert_false((r[2] as GameState).doors.is_shut(i), "door %d: the walker opened it" % i)
		r = _walk(i, inside, outside)
		got = Vector2((r[0] as Vector3).x, (r[0] as Vector3).z)
		assert_gt((got - mid).dot(out), 1.0, "door %d at %s: out from inside (ended %s)" % [i, d.center, got])


func test_a_body_in_the_doorway_keeps_the_door_from_shutting_on_it() -> void:
	for i in map.doors.size():
		var d := map.doors[i]
		var r: Array = _match()
		var sim: Simulation = r[0]
		var state: GameState = r[1]
		state.doors.shut[i] = 0
		sim.query.set_door_shut(i, false)
		var c := state.characters[0]
		var out := _outward(i)
		# Standing in the wall's gap (the leaf hangs on its outer face).
		var gap := Vector2(d.center.x, d.center.z) - out * (0.165)
		c.position = Vector3(gap.x, d.center.y - d.size.y * 0.5 + 0.04, gap.y)
		var other := state.characters[1]
		other.position = c.position + Vector3(out.x, 0.0, out.y) * 1.2
		assert_false(sim.doors.toggle(i, other, state), "door %d: won't shut on a body in its doorway" % i)
		# Moved off, it shuts.
		c.position += Vector3(-out.x, 0.0, -out.y) * 1.5
		assert_true(sim.doors.toggle(i, other, state), "door %d: shuts once the body is clear" % i)


func test_each_door_starts_shut_as_the_map_says_and_a_new_round_puts_it_back() -> void:
	var r: Array = _match()
	var state: GameState = r[1]
	for i in map.doors.size():
		assert_eq(state.doors.is_shut(i), map.doors[i].shut, "door %d" % i)


func test_the_poles_stand_on_the_ground_and_clear_of_blocks() -> void:
	assert_eq(map.poles.size(), 2)
	for p in map.poles:
		assert_almost_eq(p.y, map.terrain.height_at(p.x, p.z), 0.05, "pole at %s on the ground" % p)
		for b in map.blocks:
			if b.kind == &"floor":
				continue
			var inside := absf(p.x - b.center.x) < b.size.x * 0.5 + 0.5 and absf(p.z - b.center.z) < b.size.z * 0.5 + 0.5
			assert_false(inside and p.y > b.center.y - b.size.y * 0.5 and p.y < b.center.y + b.size.y * 0.5,
					"pole at %s inside a %s block" % [p, b.kind])


func test_round_time_applies_to_a_skirmish_on_woodland_only() -> void:
	var cat := MapCatalog.shared()
	var base := SimTuning.load_default()
	var custom := CustomRules.new()
	for id: String in ["depot", "range"]:
		var e := cat.find(id)
		assert_eq(MatchOptions.match_tuning(base, e, null).rounds.round_time, base.rounds.round_time, id)
	var w := cat.find("woodland")
	# Custom at the default switch (2:30) on Woodland plays 2:30, not 3:00.
	assert_eq(MatchOptions.match_tuning(base, w, custom).rounds.round_time, base.rounds.round_time)
	assert_eq(MatchOptions.match_tuning(base, null, null).rounds.round_time, base.rounds.round_time, "no map")
	var chips := MatchOptions.rule_chips(MatchOptions.match_tuning(base, w, null).rounds, base.hits)
	var shown := ""
	for chip in chips:
		shown += MatchOptions.chip_text(chip) + "|"
	assert_true(shown.contains("3:00"), shown)
	assert_false(shown.contains("2:30"), shown)


func test_the_practice_tuning_keeps_the_round_tuning_s_time() -> void:
	assert_eq(PlaySession.practice_tuning(SimTuning.load_default()).rounds.round_time,
			SimTuning.load_default().rounds.round_time)


func _catalog(cell: String) -> MapCatalog:
	return MapCatalog.parse("# Maps\n\n## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Round | Blurb |\n"
			+ "|---|---|---|---|---|---|---|---|---|\n| a | A | field | public | 1 | 3 | 3 | %s | x |\n" % cell)


func test_the_round_cell_takes_a_whole_number_of_seconds_from_90_to_300_and_nothing_else() -> void:
	for ok: Array in [["90", 90.0], ["300", 300.0], [" 180 ", 180.0], ["+180", 180.0], ["120", 120.0]]:
		var c := _catalog(ok[0])
		assert_eq(c.find("a").round_time, ok[1], "'%s'" % ok[0])
		assert_eq(c.problems.size(), 0, "'%s' %s" % [ok[0], c.problems])
	for bad: String in ["89", "301", "0", "-180", "180.5", "3:00", "1e2", "180s", "100", "185", "nan"]:
		var c := _catalog(bad)
		assert_eq(c.find("a").round_time, 0.0, "'%s'" % bad)
		assert_eq(c.problems.size(), 1, "'%s' warns once: %s" % [bad, c.problems])
		assert_not_null(c.find("a"), "'%s': the map is still listed" % bad)


func test_a_catalog_without_the_round_column_or_with_a_short_row_still_lists_every_map() -> void:
	var c := MapCatalog.parse("# Maps\n\n## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Blurb |\n"
			+ "|---|---|---|---|---|---|---|---|\n| a | A | field | public | 1 | 3 | 3 | x |\n")
	assert_eq(c.find("a").round_time, 0.0)
	assert_eq(c.problems.size(), 0, "%s" % [c.problems])
	c = MapCatalog.parse("# Maps\n\n## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Round | Blurb |\n"
			+ "|---|---|---|---|---|---|---|---|---|\n| a | A | field | public | 1 | 3 | 3 |\n")
	assert_not_null(c.find("a"), "short row")
	assert_eq(c.find("a").round_time, 0.0)



func _session(map_id: String, custom: CustomRules) -> PlaySession:
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.map_id = map_id
	session.custom_rules = custom
	add_child_autofree(session)
	return session


func test_the_hud_clock_and_round_state_play_the_map_s_round_time() -> void:
	var cases: Array = [["woodland", null, 180.0, "3:00"], ["depot", null, 150.0, "2:30"]]
	var custom := CustomRules.new()
	custom.round_time = 120.0
	cases.append(["woodland", custom, 120.0, "2:00"])
	for c: Array in cases:
		var session := _session(c[0], c[1])
		assert_not_null(session.state, "%s loads" % c[0])
		if session.state == null:
			continue
		assert_eq(session.state.round_state.clock, c[2], "%s: the round's clock" % c[0])
		session._hud.score().set_clock(ceili(session.state.round_state.clock))
		assert_eq(session._hud.score()._clock_label.text, c[3], "%s: the score bar's clock" % c[0])


func test_attack_defend_on_woodland_runs_two_poles_in_the_session_without_errors() -> void:
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.map_id = "woodland"
	session.mode = MatchOptions.MODE_ATTACK_DEFEND
	add_child_autofree(session)
	assert_not_null(session.state)
	if session.state == null:
		return
	assert_eq(session.state.round_state.mode, RoundState.Mode.ATTACK_DEFEND)
	assert_eq(session.state.round_state.flags.size(), 2, "a flag at each pole")
	await wait_physics_frames(180)
	assert_eq(session.state.round_state.flags.size(), 2)
