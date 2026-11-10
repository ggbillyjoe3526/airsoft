extends GutTest
## QA for RG3 (the range drawn, heard and played): the views follow movers, swingers and falling figures at any facing and
## through a whole challenge; practice ignores Custom rules, leaves the shared tuning, the XP and the records alone, and
## keeps the best exactly once per Time; a normal match on Depot is as it was; every node of a practice session is freed
## with it.

const DT := 1.0 / 60.0
const TEST_RECORDS := "user://test_rg3_qa_records.json"

var tuning: SimTuning = SimTuning.new()
var cfg: RangeViewConfig = RangeViewConfig.new()


## Records that count how often a run was offered to them.
class CountingRecords:
	extends Records
	var offered: int = 0

	func add_challenge_run(course: String, run: RangeChallenge.Run) -> bool:
		offered += 1
		return super.add_challenge_run(course, run)


func after_each() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if FileAccess.file_exists(TEST_RECORDS):
		DirAccess.remove_absolute(TEST_RECORDS)


func _spec(kind: RangeTarget.Kind, motion: RangeTarget.Motion, at: Vector3, yaw: float) -> RangeTarget.Spec:
	var s := RangeTarget.Spec.new()
	s.kind = kind
	s.motion = motion
	s.position = at
	s.yaw = yaw
	if kind == RangeTarget.Kind.STEEL:
		s.radius = 0.2
		s.position.y = 1.25
	if motion == RangeTarget.Motion.MOVER:
		s.track = 1.6
		s.speed = 1.4
		s.position.y = 0.12
	s.distance = 10.0
	return s


func _practice(map_id: String = "range") -> PlaySession:
	var s := PlaySession.new()
	s.practice = true
	s.map_id = map_id
	return s


func test_views_follow_movers_and_swingers_turned_any_way_through_their_waits() -> void:
	var specs: Array[RangeTarget.Spec] = []
	for yaw: float in [0.0, 0.7, -1.9, 2.6]:
		specs.append(_spec(RangeTarget.Kind.FIGURE, RangeTarget.Motion.MOVER, Vector3(2.0 * yaw, 0.0, -12.0), yaw))
		specs.append(_spec(RangeTarget.Kind.STEEL, RangeTarget.Motion.SWINGER, Vector3(-3.0 * yaw, 0.0, -20.0), yaw))
	var targets := RangeTargets.create(specs, tuning)
	var v := RangeTargetsView.new()
	add_child_autofree(v)
	v.setup(targets, cfg, tuning, GameTheme.font(800))
	var worst := 0.0
	# 12 s: a mover's several trips and its waits at both ends.
	for i in 720:
		RangeTargets.step(targets, tuning, DT)
		var f := 0.5 if i % 2 == 0 else 1.0
		v.update(targets, f, DT)
		for t in targets:
			var d: RangeTargetsView.Drawn = v._drawn[t.id]
			if t.motion == RangeTarget.Motion.MOVER:
				var want := t.prev_position.lerp(t.position, f)
				worst = maxf(worst, Vector2(d.carrier.global_position.x - want.x, d.carrier.global_position.z - want.z)
						.length())
				worst = maxf(worst, absf(d.carrier.global_position.y - want.y))
			elif f == 1.0:
				worst = maxf(worst, d.faces[0].global_position.distance_to(t.position))
	assert_lt(worst, 1e-3, "every drawn mover and swinger is where the simulation has it, at any facing")


func test_a_figures_lean_never_leaves_what_the_simulation_says_through_a_whole_challenge() -> void:
	var specs: Array[RangeTarget.Spec] = MapData.load_map("range", MapStyle.new(), 1).targets
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var targets := RangeTargets.create(specs, tuning, rng)
	var v := RangeTargetsView.new()
	add_child_autofree(v)
	v.setup(targets, cfg, tuning, GameTheme.font(800))
	var c := RangeChallenge.new("range")
	c.player_id = 0
	c.set_on(true, targets, tuning.targets, rng)
	var events := SimEvents.new()
	var last_angle: Array[float] = []
	last_angle.resize(targets.size())
	last_angle.fill(0.0)
	var jump := maxf(cfg.down_angle / cfg.fall_time, cfg.down_angle / tuning.targets.rise_time) * DT * 1.6
	var biggest := 0.0
	var bad := ""
	var shot_at_start := false
	for i in 3600:
		events.clear()
		# The player shoots the START plate once, then the first lit standing target every half second.
		if not shot_at_start and c.phase == RangeChallenge.Phase.READY:
			for t in targets:
				if t.start and not t.hidden:
					_hit(events, t, rng)
					shot_at_start = true
		elif c.phase == RangeChallenge.Phase.RUNNING and i % 30 == 0:
			for t in targets:
				if t.lit > 0.0 and not t.start and (t.kind == RangeTarget.Kind.STEEL or t.down <= 0.0):
					_hit(events, t, rng)
					break
		RangeTargets.step(targets, tuning, DT, rng)
		c.step(targets, events, tuning.targets, DT, rng, false)
		v.on_tick(_state_with(events))
		v.update(targets, 1.0, DT)
		for t in targets:
			if t.kind != RangeTarget.Kind.FIGURE:
				continue
			var a: float = v._drawn[t.id].pivot.rotation.x
			biggest = maxf(biggest, absf(a))
			if t.down <= 0.0 and absf(a) > 1e-6:
				bad = "figure %d stands in the sim but leans %f at tick %d" % [t.id, a, i]
			if i > 0 and absf(a - last_angle[t.id]) > jump and bad == "":
				bad = "figure %d's lean jumped %f at tick %d" % [t.id, a - last_angle[t.id], i]
			last_angle[t.id] = a
	assert_eq(bad, "")
	assert_lt(biggest, cfg.down_angle + 1e-6)
	assert_gt(biggest, cfg.down_angle * 0.99, "a figure did lie flat")


func _hit(events: SimEvents, t: RangeTarget, rng: RandomNumberGenerator) -> void:
	RangeTargets.hit_target(t, tuning.targets, rng)
	var e := events.add(GameEvent.Kind.TARGET_HIT)
	e.actor = 0
	e.target = t.id
	e.value = t.kind


## A state whose events are `events` (the view only reads them).
func _state_with(events: SimEvents) -> GameState:
	var s := GameState.new(1)
	for i in events.count:
		var e := s.events.add(events.items[i].kind)
		e.actor = events.items[i].actor
		e.target = events.items[i].target
		e.value = events.items[i].value
	return s


func test_practice_ignores_custom_rules_and_leaves_the_shared_tuning_alone() -> void:
	var shared := SimTuning.load_default()
	var size_before := shared.rounds.team_size
	var rico_before := shared.hits.ricochets_count
	var custom := CustomRules.new()
	custom.team_size = 3
	custom.wins_needed = 5
	custom.ricochets_count = true
	var s := _practice()
	s.custom_rules = custom
	add_child_autofree(s)
	await wait_physics_frames(2)
	assert_eq(s.state.characters.size(), 1, "you alone, whatever the Custom team size")
	assert_false(s._tuning.hits.ricochets_count, "your own bounce never counts there")
	assert_eq(s._tuning.rounds.team_size, 1)
	assert_eq(SimTuning.load_default().rounds.team_size, size_before, "the cached tuning is untouched")
	assert_eq(SimTuning.load_default().hits.ricochets_count, rico_before)


func test_practice_is_a_fresh_state_each_time_with_no_xp_and_no_match_records() -> void:
	var progress_before := Progress.shared().to_dict().duplicate(true)
	var wins_before := Records.shared().to_dict().duplicate(true)
	var first := _practice()
	first.counts = true
	first.records = Records.new()
	first.records_path = TEST_RECORDS
	add_child_autofree(first)
	await wait_physics_frames(2)
	first.state.targets[0].hidden = true
	first.state.round_state.clock = 123.0
	first.state.rng.seed = 99
	var second := _practice()
	second.counts = true
	second.records = Records.new()
	second.records_path = TEST_RECORDS
	add_child_autofree(second)
	await wait_physics_frames(2)
	assert_ne(second.state, first.state)
	assert_ne(second.state.targets[0], first.state.targets[0])
	assert_ne(second.state.round_state.clock, 123.0, "no clock carried over")
	await wait_physics_frames(30)
	assert_null(second.settled, "no XP or match records for a range session")
	assert_eq(second.matches_played, 0)
	assert_eq(second.rounds_played, 0)
	assert_eq(Progress.shared().to_dict(), progress_before, "your level and XP are as they were")
	assert_eq(Records.shared().to_dict(), wins_before, "your match records are as they were")
	assert_false(FileAccess.file_exists(TEST_RECORDS), "nothing is saved when nothing was kept")


func test_a_time_cue_offers_the_run_once_and_a_dropped_run_offers_nothing() -> void:
	var rec := CountingRecords.new()
	var s := _practice()
	s.counts = true
	s.records = rec
	s.records_path = TEST_RECORDS
	add_child_autofree(s)
	await wait_physics_frames(2)
	var c := s.state.challenge
	s.set_challenge(true)
	c.phase = RangeChallenge.Phase.RUNNING
	c.clock = 2.0 * DT
	c.hits = 3
	c.helped = false
	await wait_physics_frames(6)
	assert_eq(rec.offered, 1, "offered once on Time, not on the cues before it nor on every tick after")
	assert_eq(rec.challenge_best("range"), 3)
	assert_true(FileAccess.file_exists(TEST_RECORDS))
	await wait_physics_frames(30)
	assert_eq(rec.offered, 1, "the stale last run is not offered again")
	# The next go: the countdown's cues and Go come while the last run is still `last`; none of them offers it.
	c.phase = RangeChallenge.Phase.COUNTDOWN
	c.clock = 2.0
	await wait_physics_frames(150)
	assert_eq(c.phase, RangeChallenge.Phase.RUNNING, "Go came")
	assert_eq(rec.offered, 1, "countdown and Go offer nothing")
	# A second run switched off before its Time: dropped, nothing offered.
	c.phase = RangeChallenge.Phase.RUNNING
	c.clock = 5.0
	c.hits = 9
	s.set_challenge(false)
	await wait_physics_frames(10)
	assert_eq(rec.offered, 1, "a run dropped by the switch gives no score")
	assert_eq(rec.challenge_best("range"), 3)


func test_a_worse_run_neither_changes_the_best_nor_saves() -> void:
	var rec := Records.new()
	rec.best_challenge["range"] = 7
	var s := _practice()
	s.counts = true
	s.records = rec
	s.records_path = TEST_RECORDS
	add_child_autofree(s)
	await wait_physics_frames(2)
	var c := s.state.challenge
	assert_eq(c.best, 7, "the run starts knowing your best")
	s.set_challenge(true)
	c.phase = RangeChallenge.Phase.RUNNING
	c.clock = 2.0 * DT
	c.hits = 4
	await wait_physics_frames(6)
	assert_eq(c.phase, RangeChallenge.Phase.READY)
	assert_eq(rec.challenge_best("range"), 7)
	assert_false(FileAccess.file_exists(TEST_RECORDS), "no save without a new best")


func test_the_switch_is_remembered_from_before_the_range_is_built() -> void:
	var s := _practice()
	s.challenge_on = true
	add_child_autofree(s)
	await wait_physics_frames(2)
	assert_eq(s.state.challenge.phase, RangeChallenge.Phase.READY)


func test_a_match_on_depot_is_as_it_was() -> void:
	var s := PlaySession.new()
	s.map_id = "depot"
	s.autopilot = true
	add_child_autofree(s)
	await wait_physics_frames(2)
	RoundHold.release(s.state)
	assert_false(s.practice)
	assert_eq(s.state.characters.size(), MapCatalog.shared().find("depot").team_standard * 2)
	assert_eq(s.state.targets.size(), 0)
	assert_false(s.state.round_state.practice)
	assert_null(s._targets_view)
	assert_null(s._pilot, "bots drive the autopilot on Depot, not the range pilot")
	assert_null(s.find_child("RangeTargets", true, false))
	assert_null(s.find_child("RangeMarks", true, false))
	assert_eq(s._tuning.hits.ricochets_count, SimTuning.load_default().hits.ricochets_count)
	s.set_challenge(true)
	assert_eq(s.state.challenge.phase, RangeChallenge.Phase.OFF, "no timed challenge in a match")
	var audio := s.find_child("Sound", true, false) as SimAudio
	var st := GameState.new(1)
	st.events.add(GameEvent.Kind.ROUND_GO)
	audio.on_tick(st, 0, null)
	assert_true((audio._streams[&"whistle_short"] as Array).has(audio._whistle.stream),
			"rounds start with the referee's whistle at GO (SP4, BP8)")


func test_a_ring_is_one_sound_not_two() -> void:
	var s := _practice()
	s.autopilot = true
	add_child_autofree(s)
	s._pilot = RangePilot.new()
	var both := false
	for i in 400:
		await wait_physics_frames(1)
		var hit := false
		var impact_at := false
		for k in s.state.events.count:
			var e := s.state.events.items[k]
			hit = hit or e.kind == GameEvent.Kind.TARGET_HIT
			impact_at = impact_at or (e.kind == GameEvent.Kind.BB_IMPACT and e.target < 0 and e.actor == 0)
		both = both or (hit and impact_at)
		if s.plate_hits > 0:
			break
	assert_gt(s.plate_hits, 0)
	assert_false(both, "a hit on a plate gives no level impact as well")


func test_nothing_is_left_behind_when_a_practice_session_goes() -> void:
	# One warm-up so first-use caches (fonts, streams) don't count against the session.
	var warm := _practice()
	add_child(warm)
	await wait_physics_frames(2)
	warm.free()
	await wait_process_frames(5)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var s := _practice()
	s.autopilot = true
	add_child(s)
	s._pilot = RangePilot.new()
	await wait_physics_frames(300)
	s.set_challenge(true)
	await wait_physics_frames(30)
	s._leave()
	remove_child(s)
	s.free()
	await wait_process_frames(5)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "every view and audio node is freed")
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans)
	assert_false(get_tree().paused)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
