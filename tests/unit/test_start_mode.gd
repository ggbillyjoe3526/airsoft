extends GutTest
## NA1: "no full auto indoors" (owner, 2026-11-02). data/maps.md's Start mode holds every replica that comes on full
## auto, any replica now or added later, the bots' too, to a lower mode at the start of every round on that field
## (Depot: semi); B still switches to auto in the round. Fields without one start replicas as they come, kept all match.

const DT := 1.0 / 60.0
const SEMI := ReplicaConfig.FireMode.SEMI
const BURST := ReplicaConfig.FireMode.BURST
const AUTO := ReplicaConfig.FireMode.AUTO
const HEAD := "## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Round | Start mode | Blurb |\n" \
		+ "|---|---|---|---|---|---|---|---|---|---|\n"

var tuning: SimTuning
var ends: Array[MapEnd]
var pool: BBPool
var events: SimEvents
var rs: RoundState
var cs: Array[Character]


func before_each() -> void:
	tuning = SimTuning.new()
	ends = [_end(-20.0, -PI / 2.0), _end(20.0, PI / 2.0)]
	pool = BBPool.new(4)
	events = SimEvents.new()
	rs = RoundState.new()
	cs = []
	var loadout := ReplicaStats.default_loadout()
	for id in 4:
		cs.append(Character.new(id, 0 if id < 2 else 1, Vector3.ZERO, 0.0, loadout))


func _end(x: float, facing: float) -> MapEnd:
	var e := MapEnd.new()
	for z in 2:
		e.spawns.append(SpawnPoint.new(Vector3(x, 0.0, z), facing))
	return e


func _replica(modes: Array[ReplicaConfig.FireMode], default_mode: ReplicaConfig.FireMode) -> ReplicaConfig:
	var r := ReplicaConfig.new()
	r.fire_modes = modes
	r.default_fire_mode = default_mode
	return r


## The round under way ends and the next one starts.
func _next_round() -> void:
	rs.phase = RoundState.Phase.OVER
	rs.winner = 0
	rs.timer = 0.0
	var before := rs.number
	Round.step(rs, cs, ends, pool, tuning, events, DT)
	assert_eq(rs.number, before + 1, "the next round started")


## `c` presses the selector key once.
func _press_selector(c: Character) -> void:
	var cmd := PlayerCommand.new()
	cmd.cycle_fire_mode = true
	Armament.step(c, cmd, Vector3.ZERO, 1.0, true, pool, Seeds.stream(1), events, tuning, DT)


func test_depot_is_the_one_shipped_field_with_no_full_auto_to_start() -> void:
	var cat := MapCatalog.read_file()
	assert_eq(cat.problems, [] as Array[String])
	assert_eq(cat.find("depot").start_mode, SEMI)
	for id: String in ["woodland", "street", "range"]:
		assert_eq(cat.find(id).start_mode, AUTO, "%s starts replicas as they come" % id)


func test_the_start_mode_cell_reads_semi_burst_auto_or_blank_and_warns_on_anything_else() -> void:
	var cat := MapCatalog.parse(HEAD
			+ "| a | A | field | public | 5 | 6 | 8 |  | burst | x |\n"
			+ "| b | B | field | public | 5 | 6 | 8 |  | Semi | x |\n"
			+ "| c | C | field | public | 5 | 6 | 8 |  | auto | x |\n"
			+ "| d | D | field | public | 5 | 6 | 8 |  |  | x |\n"
			+ "| e | E | field | public | 5 | 6 | 8 |  | single | x |\n")
	assert_eq(cat.find("a").start_mode, BURST)
	assert_eq(cat.find("b").start_mode, SEMI)
	assert_eq(cat.find("c").start_mode, AUTO)
	assert_eq(cat.find("d").start_mode, AUTO)
	assert_eq(cat.find("e").start_mode, AUTO, "an unreadable cell keeps no rule")
	assert_eq(cat.problems.size(), 1)
	assert_string_contains(cat.problems[0], "Start mode \"single\"")


func test_a_table_without_the_column_has_no_rule_and_no_warning() -> void:
	var cat := MapCatalog.parse("## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Blurb |\n"
			+ "|---|---|---|---|---|---|---|---|\n| a | A | field | public | 5 | 6 | 8 | x |\n")
	assert_eq(cat.find("a").start_mode, AUTO)
	assert_eq(cat.problems, [] as Array[String])


func test_any_replica_that_comes_on_full_auto_is_held_whatever_it_is() -> void:
	var aeg := _replica([SEMI, BURST, AUTO], AUTO)
	assert_eq(Armament.start_mode(aeg, SEMI), SEMI)
	assert_eq(Armament.start_mode(aeg, BURST), BURST)
	assert_eq(Armament.start_mode(aeg, AUTO), AUTO, "no rule: as it comes")
	# A future pistol with semi and auto only (the owner's example), listed auto first.
	var pistol := _replica([AUTO, SEMI], AUTO)
	assert_eq(Armament.start_mode(pistol, SEMI), SEMI)
	assert_eq(Armament.start_mode(pistol, BURST), SEMI, "no burst: the highest mode under the rule")
	# Nothing under the rule: its lowest mode, still not full auto where it has another.
	assert_eq(Armament.start_mode(_replica([BURST, AUTO], AUTO), SEMI), BURST)
	assert_eq(Armament.start_mode(_replica([AUTO], AUTO), SEMI), AUTO, "auto alone stays auto")
	# Already under the rule: untouched.
	assert_eq(Armament.start_mode(_replica([SEMI, BURST, AUTO], SEMI), SEMI), SEMI)
	assert_eq(Armament.start_mode(_replica([SEMI, BURST, AUTO], BURST), SEMI), SEMI)


func test_every_shipped_replica_with_full_auto_starts_below_it_on_depot() -> void:
	var stats := ReplicaStats.read_file()
	var held := 0
	for file in DirAccess.get_files_at(ReplicaStats.REPLICA_DIR):
		if not file.ends_with(".tres"):
			continue
		var r := stats.replica_config(StringName(file.get_basename()))
		if not r.fire_modes.has(AUTO) or r.fire_modes.size() < 2:
			continue
		held += 1
		# As a bot carries it (BotKits.kit_of puts a replica with full auto on it).
		r.default_fire_mode = AUTO
		assert_ne(Armament.start_mode(r, SEMI), AUTO, "%s doesn't start on full auto" % r.id)
	assert_gt(held, 0, "a shipped replica fires full auto")


func test_on_a_no_auto_field_every_round_starts_on_semi_and_b_still_reaches_auto() -> void:
	rs.start_mode = SEMI
	cs[2].armament.modes[0] = AUTO # a bot's kit puts its AEG on full auto
	Round.start_match(rs, cs, ends, pool, tuning, events)
	for c in cs:
		assert_eq(c.armament.modes[0], SEMI, "character %d starts on semi" % c.id)
	_press_selector(cs[0])
	_press_selector(cs[0])
	assert_eq(cs[0].armament.fire_mode(), AUTO, "switched to auto by hand in the round")
	_next_round()
	assert_eq(cs[0].armament.fire_mode(), SEMI, "back on semi for the next round")


func test_elsewhere_selectors_start_as_they_come_and_stay_as_set() -> void:
	Round.start_match(rs, cs, ends, pool, tuning, events)
	assert_eq(cs[0].armament.modes[0], cs[0].armament.replicas[0].default_fire_mode)
	_press_selector(cs[0])
	var picked := cs[0].armament.fire_mode()
	_next_round()
	assert_eq(cs[0].armament.fire_mode(), picked, "kept for the match")


func test_bots_never_touch_the_selector() -> void:
	const AI := "res://game/ai/"
	for file in DirAccess.get_files_at(AI):
		if file.ends_with(".gd"):
			assert_false(FileAccess.get_file_as_string(AI + file).contains("cycle_fire_mode"),
					"%s keeps the field's start mode" % file)
