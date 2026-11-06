extends GutTest
## The practice range's timed challenge (game/sim/range_challenge.gd; the browser game's sim/rangeChallenge.test.ts,
## M93): off, ready, countdown and running, lit targets scored and missed, the run's end and its best, Dev help, the
## switch, seeded picks; stepped by the simulation in practice, and its best kept per course in Records.

const DT := 1.0 / 60.0
const PLAYER := 0
## How long a figure's fall is drawn (s; the browser game's RANGE_VISUALS.fallTime): a pop-up lying down for longer than
## that since its fall began is drawn flat.
const FALL_TIME := 0.18
const RECORDS := "user://test_rg2_records.save"
const Replicas := preload("res://tests/unit/replica_fixtures.gd")

var tuning: SimTuning = SimTuning.new()
var cfg: RangeConfig = tuning.targets
var map: MapData = null


## The range's targets with the challenge on (best `best`), and a tick that steps the targets then the challenge with
## the given events, as the simulation does.
class Bench:
	extends RefCounted
	var tuning: SimTuning = null
	var rng: RandomNumberGenerator = null
	var targets: Array[RangeTarget] = []
	var c: RangeChallenge = null
	var start: RangeTarget = null
	var events: SimEvents = SimEvents.new()

	func _init(sim_tuning: SimTuning, specs: Array[RangeTarget.Spec], best: int, on: bool = true) -> void:
		tuning = sim_tuning
		rng = Seeds.stream(7)
		targets = RangeTargets.create(specs, tuning, rng)
		c = RangeChallenge.new("range", best)
		if on:
			c.set_on(true, targets, tuning.targets, rng)
		for t in targets:
			if t.start:
				start = t

	## One tick with `evs` ([kind, actor, target] each) as the simulation's events, `cheating` a Dev setting on.
	func tick(evs: Array = [], cheating: bool = false) -> void:
		events.clear()
		for ev: Array in evs:
			var e := events.add(ev[0])
			e.actor = ev[1]
			e.target = ev[2]
		RangeTargets.step(targets, tuning, DT, rng)
		c.step(targets, events, tuning.targets, DT, rng, cheating)

	func run(seconds: float) -> void:
		for i in roundi(seconds / DT):
			tick()

	## This tick's cue (RangeChallenge.Cue), or -1 for none.
	func cue() -> int:
		var e := events.first(GameEvent.Kind.CHALLENGE)
		return e.value if e != null else -1

	## The player's hits on every lit target, as events.
	func hit_lit() -> Array:
		var out := []
		for t in targets:
			if t.lit > 0.0:
				out.append([GameEvent.Kind.TARGET_HIT, PLAYER, t.id])
		return out

	func lit_count() -> int:
		var n := 0
		for t in targets:
			if t.lit > 0.0:
				n += 1
		return n


func before_all() -> void:
	map = MapData.load_map("range", MapStyle.new(), 1)


func before_each() -> void:
	SaveFile.remove(RECORDS)


func after_each() -> void:
	SaveFile.remove(RECORDS)


static func hit(t: RangeTarget, shooter: int = PLAYER) -> Array:
	return [GameEvent.Kind.TARGET_HIT, shooter, t.id]


static func shot(actor: int = PLAYER) -> Array:
	return [GameEvent.Kind.SHOT, actor, -1]


func _bench(best: int = 0, on: bool = true) -> Bench:
	return Bench.new(tuning, map.targets, best, on)


## Drawn flat: its fall done, its rise not begun.
func _flat(t: RangeTarget) -> bool:
	return t.down_for - t.down >= FALL_TIME and t.down >= cfg.rise_time


## The pop-ups lying down, unlit.
func _lying_popups(targets: Array[RangeTarget]) -> Array[RangeTarget]:
	var out: Array[RangeTarget] = []
	for t in targets:
		if t.motion == RangeTarget.Motion.POPUP and t.down >= cfg.rise_time and t.lit <= 0.0:
			out.append(t)
	return out


## Plays a run to its end, hitting every lit target as soon as it lights; false if it doesn't end.
func _hit_everything(b: Bench) -> bool:
	for i in roundi((cfg.challenge_run_time + 1.0) / DT):
		b.tick(b.hit_lit())
		if b.cue() == RangeChallenge.Cue.TIME:
			return true
	return false


func test_is_off_until_turned_on_with_no_start_plate_and_nothing_lit() -> void:
	var b := _bench(0, false)
	assert_eq(b.c.phase, RangeChallenge.Phase.OFF)
	assert_true(b.start.hidden)
	b.tick([hit(b.targets[0]), hit(b.start)])
	assert_eq(b.c.phase, RangeChallenge.Phase.OFF)
	assert_eq(b.cue(), -1)
	assert_true(b.targets.all(func(t: RangeTarget) -> bool: return t.lit == 0.0))


func test_on_the_start_plate_stands_your_hit_on_it_starts_a_countdown_someone_elses_does_not() -> void:
	var b := _bench()
	assert_eq(b.c.phase, RangeChallenge.Phase.READY)
	assert_false(b.start.hidden)
	b.tick([hit(b.start, 1), hit(b.targets[0])])
	assert_eq(b.c.phase, RangeChallenge.Phase.READY)
	b.tick([hit(b.start)])
	assert_eq(b.c.phase, RangeChallenge.Phase.COUNTDOWN)
	assert_eq(b.cue(), RangeChallenge.Cue.COUNT)
	assert_eq(b.events.first(GameEvent.Kind.CHALLENGE).value2, 3, "three seconds to go")
	assert_eq(b.events.first(GameEvent.Kind.CHALLENGE).actor, PLAYER)
	assert_true(b.start.hidden)


func test_counts_down_a_beep_a_second_then_lights_targets_and_runs_for_its_time() -> void:
	var b := _bench()
	b.tick([hit(b.start)])
	var counts := 1
	var ticks := 0
	while b.c.phase == RangeChallenge.Phase.COUNTDOWN:
		b.tick()
		ticks += 1
		if b.cue() == RangeChallenge.Cue.COUNT:
			counts += 1
	assert_eq(counts, int(cfg.challenge_countdown))
	assert_almost_eq(ticks * DT, cfg.challenge_countdown, 0.05)
	assert_eq(b.c.phase, RangeChallenge.Phase.RUNNING)
	assert_eq(b.cue(), RangeChallenge.Cue.GO)
	assert_eq(b.c.clock, cfg.challenge_run_time)
	assert_eq(b.lit_count(), cfg.challenge_lit_at_once)
	assert_false(b.start.lit > 0.0)


func test_scores_a_lit_target_you_hit_and_lights_another_an_unlit_one_scores_nothing_bbs_are_counted() -> void:
	var b := _bench()
	b.tick([hit(b.start)])
	b.run(cfg.challenge_countdown + DT)
	assert_eq(b.c.phase, RangeChallenge.Phase.RUNNING)
	var lit: RangeTarget = b.targets.filter(func(t: RangeTarget) -> bool: return t.lit > 0.0)[0]
	var dark: RangeTarget = b.targets.filter(func(t: RangeTarget) -> bool: return t.lit == 0.0 and not t.start)[0]
	b.tick([shot(), hit(lit), shot(), hit(dark), shot(1), hit(b.targets[0], 1)])
	assert_eq(b.c.hits, 1)
	assert_eq(b.c.shots, 2)
	assert_lt(lit.lit, 0.0, "put out, resting")
	assert_eq(b.lit_count(), cfg.challenge_lit_at_once)


func test_a_lit_target_left_unhit_goes_out_as_a_miss() -> void:
	var b := _bench()
	b.tick([hit(b.start)])
	b.run(cfg.challenge_countdown + DT)
	b.run(cfg.challenge_lit_time + cfg.challenge_lit_per_metre * 50.0 + cfg.rise_time + 0.1)
	assert_gt(b.c.missed, 0)
	assert_eq(b.c.hits, 0)


func test_a_targets_lit_time_is_its_base_its_flight_by_marked_distance_and_a_lying_pop_ups_rise() -> void:
	var b := _bench()
	b.tick([hit(b.start)])
	while b.c.phase == RangeChallenge.Phase.COUNTDOWN:
		b.tick()
	for t in b.targets:
		if t.lit > 0.0:
			var rise := cfg.rise_time if t.motion == RangeTarget.Motion.POPUP and t.down > 0.0 else 0.0
			assert_almost_eq(t.lit, cfg.challenge_lit_time + cfg.challenge_lit_per_metre * t.distance + rise, 1e-6)


func test_ends_on_time_start_stands_again_nothing_lit_and_a_better_score_becomes_the_best() -> void:
	var b := _bench(1)
	b.tick([hit(b.start)])
	b.run(cfg.challenge_countdown + DT)
	assert_true(_hit_everything(b))
	assert_eq(b.c.phase, RangeChallenge.Phase.READY)
	assert_gt(b.c.last.hits, 1)
	assert_true(b.c.last.best)
	assert_false(b.c.last.helped)
	assert_eq(b.c.best, b.c.last.hits)
	assert_false(b.start.hidden)
	assert_true(b.targets.all(func(t: RangeTarget) -> bool: return t.lit == 0.0))
	assert_true(b.targets.all(func(t: RangeTarget) -> bool:
		return t.motion != RangeTarget.Motion.POPUP or t.auto))


func test_a_run_with_dev_help_since_start_is_never_a_best_and_the_next_run_starts_clean() -> void:
	var b := _bench(1)
	b.tick([], true)
	assert_false(b.c.helped, "nothing to mark before a run")
	b.tick([hit(b.start)])
	b.run(cfg.challenge_countdown + 1.0)
	b.tick([], true)
	assert_true(_hit_everything(b))
	assert_gt(b.c.last.hits, 1)
	assert_false(b.c.last.best)
	assert_true(b.c.last.helped)
	assert_eq(b.c.best, 1)
	b.tick([hit(b.start)])
	assert_false(b.c.helped, "START shot again with no help: clean")


func test_dev_help_on_as_start_is_shot_marks_the_run() -> void:
	var b := _bench()
	b.tick([hit(b.start)], true)
	assert_true(b.c.helped)


func test_a_worse_run_keeps_the_best() -> void:
	var b := _bench(99)
	b.tick([hit(b.start)])
	b.run(cfg.challenge_countdown + cfg.challenge_run_time + 0.5)
	assert_not_null(b.c.last)
	assert_false(b.c.last.best)
	assert_eq(b.c.best, 99)


func test_turned_off_mid_run_drops_the_run_with_no_score_and_hides_the_start_plate() -> void:
	var b := _bench(5)
	b.tick([hit(b.start)])
	b.run(cfg.challenge_countdown + 1.0)
	b.c.set_on(false, b.targets, cfg, b.rng)
	assert_eq(b.c.phase, RangeChallenge.Phase.OFF)
	assert_eq(b.c.best, 5)
	assert_null(b.c.last)
	assert_true(b.start.hidden)
	assert_true(b.targets.all(func(t: RangeTarget) -> bool: return t.lit == 0.0))
	b.tick()
	assert_eq(b.cue(), -1, "off: no cues, no run")


func test_pop_ups_lying_when_a_run_ends_or_when_it_is_turned_off_lie_on_never_drawn_falling_again() -> void:
	var b := _bench()
	var popups := b.targets.filter(func(t: RangeTarget) -> bool: return t.motion == RangeTarget.Motion.POPUP)
	assert_true(popups.all(_flat), "lying from the start, not falling")
	b.tick([hit(b.start)])
	b.run(cfg.challenge_countdown + DT)
	var lying := _lying_popups(b.targets)
	assert_gt(lying.size(), 0)
	b.c.set_on(false, b.targets, cfg, b.rng)
	assert_true(lying.all(_flat))
	# And at the end of a run.
	b.c.set_on(true, b.targets, cfg, b.rng)
	b.tick([hit(b.start)])
	while b.c.phase != RangeChallenge.Phase.RUNNING or b.c.clock > 2.0 * DT:
		b.tick()
	lying = _lying_popups(b.targets)
	while b.c.phase == RangeChallenge.Phase.RUNNING:
		b.tick()
	assert_not_null(b.c.last)
	assert_true(lying.all(_flat))


func test_plays_the_same_from_the_same_seed() -> void:
	var lights := func() -> Array:
		var b := _bench()
		b.tick([hit(b.start)])
		b.run(cfg.challenge_countdown + 10.0)
		return b.targets.map(func(t: RangeTarget) -> int: return roundi(t.lit * 100.0))
	assert_eq(lights.call(), lights.call())


func test_stays_off_where_no_start_plate_stands() -> void:
	var specs: Array[RangeTarget.Spec] = []
	for s in map.targets:
		if not s.start:
			specs.append(s)
	var b := Bench.new(tuning, specs, 0)
	assert_false(RangeChallenge.has_start(b.targets))
	assert_true(RangeChallenge.has_start(_bench().targets))
	assert_eq(b.c.phase, RangeChallenge.Phase.OFF)


## The range in practice (test_range_map.gd's), its challenge on and the player `c` at the line.
func _practice() -> Array:
	var w := BoxWorld.new(tuning.body)
	for blk in map.blocks:
		w.add_box(blk.center, blk.size, blk.surface)
	var sim := Simulation.new(tuning, w, w.mover(), map.ends, map.kill_y)
	var state := GameState.new(5, tuning)
	state.round_state.practice = true
	var loadout: Array[ReplicaConfig] = [Replicas.aeg(), Replicas.pistol()]
	for r in loadout:
		r.mag_size = 30
		r.mags = 4
	state.characters.append(Character.new(PLAYER, 0, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	state.targets = RangeTargets.create(map.targets, tuning, state.rng)
	state.challenge.course = "range"
	state.challenge.set_on(true, state.targets, cfg, state.rng)
	return [sim, state]


## Points `cmd` from `c`'s eyes at the middle of `t` (a plate's centre, a figure's chest).
func _aim(cmd: PlayerCommand, c: Character, t: RangeTarget) -> void:
	var lift := 0.0 if t.kind == RangeTarget.Kind.STEEL else 1.25
	var d := t.position + Vector3(0.0, lift, 0.0) - c.eye(tuning.body)
	cmd.yaw = atan2(-d.x, -d.z)
	cmd.pitch = atan2(d.y, Vector2(d.x, d.z).length())


## The nearest lit target (by marked distance), or the START plate while it stands, or null.
func _mark(state: GameState) -> RangeTarget:
	var best: RangeTarget = null
	for t in state.targets:
		if (t.lit > 0.0 or (t.start and not t.hidden)) and (best == null or t.distance < best.distance):
			best = t
	return best


## `ticks` practice ticks with the player shooting at _mark; the cues heard, in order.
func _shoot(sim: Simulation, state: GameState, ticks: int) -> Array[int]:
	var cues: Array[int] = []
	var c := state.characters[0]
	var cmds: Array[PlayerCommand] = [PlayerCommand.new()]
	for i in ticks:
		cmds[0].reset(c.yaw, c.pitch)
		var t := _mark(state)
		if t != null:
			_aim(cmds[0], c, t)
		cmds[0].fire = t != null and i % 6 < 3
		cmds[0].reload = c.armament.mag() == 0
		sim.step(state, cmds, DT)
		for k in state.events.count:
			if state.events.items[k].kind == GameEvent.Kind.CHALLENGE:
				cues.append(state.events.items[k].value)
	return cues


func test_the_simulation_steps_it_in_practice_shooting_start_then_lit_targets_scores() -> void:
	var m := _practice()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var cues := _shoot(sim, state, roundi(3.0 / DT))
	assert_gt(cues.size(), 0)
	assert_eq(cues[0], RangeChallenge.Cue.COUNT, "START shot: the countdown starts")
	cues.append_array(_shoot(sim, state, roundi((cfg.challenge_countdown + 20.0) / DT)))
	assert_true(cues.has(RangeChallenge.Cue.GO))
	assert_eq(state.challenge.phase, RangeChallenge.Phase.RUNNING)
	assert_gt(state.challenge.shots, 0)
	assert_gt(state.challenge.hits, 0, "lit targets shot from the line score")
	assert_false(state.challenge.helped)


func test_a_dev_cheat_applied_in_a_run_keeps_it_from_the_best_and_a_match_never_steps_it() -> void:
	var m := _practice()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	_shoot(sim, state, roundi((3.0 + cfg.challenge_countdown) / DT))
	assert_eq(state.challenge.phase, RangeChallenge.Phase.RUNNING)
	var cheats := DevCheats.new()
	cheats.game_speed = 2.0
	DevCheats.apply(state, cheats, PLAYER)
	_shoot(sim, state, 1)
	DevCheats.apply(state, DevCheats.new(), PLAYER)
	_shoot(sim, state, roundi(cfg.challenge_run_time / DT))
	assert_not_null(state.challenge.last)
	assert_true(state.challenge.last.helped)
	assert_false(state.challenge.last.best)
	assert_eq(state.challenge.best, 0)
	# Off practice, the challenge isn't stepped: shooting START does nothing.
	var other := _practice()
	var match_sim: Simulation = other[0]
	var in_match: GameState = other[1]
	in_match.round_state.practice = false
	_shoot(match_sim, in_match, roundi(3.0 / DT))
	assert_eq(in_match.challenge.phase, RangeChallenge.Phase.READY)


func test_a_run_with_dev_content_in_hand_is_never_a_best() -> void:
	# BP3: dev gear in practice (then the Sniper Rifle or the Variable Scope) made a best, though dev content stays off
	# the records.
	var m := _practice()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	state.dev_content = true
	_shoot(sim, state, roundi((3.0 + cfg.challenge_countdown + cfg.challenge_run_time) / DT))
	assert_not_null(state.challenge.last)
	assert_true(state.challenge.last.helped)
	assert_false(state.challenge.last.best)


func test_a_running_practice_tick_allocates_no_objects_once_warm() -> void:
	var m := _practice()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	_shoot(sim, state, roundi((3.0 + cfg.challenge_countdown + 5.0) / DT))
	assert_eq(state.challenge.phase, RangeChallenge.Phase.RUNNING)
	# The event pool grows to the busiest tick seen (SimEvents): warm it past any tick here.
	for i in 16:
		state.events.add(GameEvent.Kind.SHOT)
	state.events.clear()
	var c := state.characters[0]
	var cmds: Array[PlayerCommand] = [PlayerCommand.new()]
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 600:
		cmds[0].reset(c.yaw, c.pitch)
		var t := _mark(state)
		if t != null:
			_aim(cmds[0], c, t)
		cmds[0].fire = i % 6 < 3
		cmds[0].reload = c.armament.mag() == 0
		sim.step(state, cmds, DT)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)
	assert_eq(state.challenge.phase, RangeChallenge.Phase.RUNNING)
	assert_gt(state.challenge.hits, 0)


func test_records_keep_the_best_per_course_never_a_helped_run_and_save_it() -> void:
	var r := Records.new()
	var run := RangeChallenge.Run.new()
	run.hits = 12
	assert_eq(r.challenge_best("range"), 0)
	assert_true(r.add_challenge_run("range", run))
	assert_true(r.dirty)
	run.hits = 10
	assert_false(r.add_challenge_run("range", run), "a worse run")
	assert_true(r.add_challenge_run("depot", run), "each course its own")
	run.hits = 30
	run.helped = true
	assert_false(r.add_challenge_run("range", run), "Dev help: never kept")
	run.helped = false
	assert_false(r.add_challenge_run("not a course", run))
	assert_eq([r.challenge_best("range"), r.challenge_best("depot"), r.challenge_best("woodland")], [12, 10, 0])
	assert_true(r.save(RECORDS))
	var again := Records.new()
	again.load_file(RECORDS)
	assert_eq([again.challenge_best("range"), again.challenge_best("depot")], [12, 10])


func test_records_from_before_the_challenge_load_and_bad_bests_are_left_out() -> void:
	var r := Records.new()
	var old := r.from_dict({"results": {"normal.elimination": [3, 1]}, "best_accuracy": 0.5, "streak": 1,
			"best_streak": 2})
	assert_eq(old, [] as Array[String])
	assert_eq(r.best_challenge, {} as Dictionary[String, int])
	assert_eq(r.win_loss(&"normal", "elimination"), PackedInt32Array([3, 1]))
	var problems := r.from_dict({"best_challenge": {"range": 14.0, "futureMap": 3, "bad key": 5, "depot": -2,
			"woodland": 1.5}})
	assert_eq(problems.size(), 3)
	assert_eq(r.challenge_best("range"), 14)
	assert_eq(r.challenge_best("futureMap"), 3, "a course this build doesn't know is kept")
	assert_false(r.to_dict().has("bad key"))
	assert_eq((r.to_dict()["best_challenge"] as Dictionary).size(), 2)
