extends GutTest
## QA for the Variable Scope (SN2): zoom kept per slot, a new match resetting it through Round.start_match, the step
## rounding at an odd top zoom, and a variable optic that is not in its glass (its turn would change nothing seen).

const DT := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 0.0)
const AEG := "000002"
const SNIPER := "000021"
const VARIABLE := "000025"
const RED_DOT := "000007"

var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true


func _aeg_with(optic: String) -> ReplicaConfig:
	var l := rules.default_loadout("L")
	assert_true(rules.set_part(l, AEG, &"optic", optic), "fitted")
	return rules.carried(l).replicas[0]


func _turn(c: Character, steps: int, tuning: SimTuning = null) -> Array[GameEvent]:
	var cmd := PlayerCommand.new()
	cmd.zoom_steps = steps
	c.aiming = true # through the scope
	var events := SimEvents.new()
	Armament.step(c, cmd, EYE, 1.0, true, BBPool.new(4), Seeds.stream(3), events, tuning if tuning else SimTuning.new(), DT)
	var out: Array[GameEvent] = []
	for k in events.count:
		if events.items[k].kind == GameEvent.Kind.ZOOM:
			out.append(events.items[k])
	return out


func test_each_slot_keeps_its_own_zoom() -> void:
	var v := _aeg_with(VARIABLE)
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [v, v.duplicate()] as Array[ReplicaConfig])
	c.armament.active = 1
	_turn(c, 3)
	assert_eq(c.armament.zooms[1], 5.0)
	assert_eq(c.armament.zooms[0], 2.0, "the other slot's scope is left alone")
	c.armament.active = 0
	assert_eq(c.armament.zoom_now(), 2.0, "back on the first replica its own zoom reads")


func test_a_new_match_resets_every_slots_zoom_through_the_round_code() -> void:
	var v := _aeg_with(VARIABLE)
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, [v] as Array[ReplicaConfig])
	_turn(c, 3)
	assert_eq(c.armament.zoom_now(), 5.0, "turned up first")
	var tuning := SimTuning.new()
	tuning.body.rest_gap = 0.0
	var end := MapEnd.new()
	end.spawns.clear()
	var rs := RoundState.new()
	var cs: Array[Character] = [c]
	var ends: Array[MapEnd] = [end, end]
	Round.start_match(rs, cs, ends, null, tuning, SimEvents.new())
	assert_eq(c.armament.zoom_now(), 2.0, "start_match resets it")


func test_a_top_zoom_that_is_not_a_whole_notch_still_turns_back_down() -> void:
	var v := _aeg_with(VARIABLE)
	v.aim_zoom_to = 5.5
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [v] as Array[ReplicaConfig])
	_turn(c, 10)
	assert_eq(c.armament.zoom_now(), 5.5, "stops at the top")
	_turn(c, -1)
	assert_lt(c.armament.zoom_now(), 5.5, "one notch down leaves the top")
	assert_gte(c.armament.zoom_now(), 2.0)
	_turn(c, -10)
	assert_eq(c.armament.zoom_now(), 2.0)


func test_a_smaller_zoom_step_in_the_rules_gives_finer_notches() -> void:
	var v := _aeg_with(VARIABLE)
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [v] as Array[ReplicaConfig])
	var tuning := SimTuning.new()
	tuning.replica_rules.zoom_step = 0.5
	var e := _turn(c, 1, tuning)
	assert_eq(c.armament.zoom_now(), 2.5)
	assert_eq(e[0].value, 250)


func test_a_bot_with_the_scope_keeps_it_at_its_lowest() -> void:
	var c := Character.new(7, 1, Vector3.ZERO, 0.0, [_aeg_with(VARIABLE)] as Array[ReplicaConfig])
	assert_eq(_turn(c, 0).size(), 0)
	assert_eq(c.armament.zoom_now(), 2.0)


func test_the_wheel_only_turns_a_zoom_you_can_see() -> void:
	# A variable optic whose table row says "In the glass: no" would zoom the whole view at its lowest zoom only
	# (FirstPersonView.aimed_zoom reads aim_zoom, not Armament.zooms): turning it must not eat the wheel for nothing.
	var part := rules.stats.parts.part(&"optic", &"redDot")
	part.zoom_to = 3.0
	var l := rules.default_loadout("L")
	assert_true(rules.set_part(l, AEG, &"optic", RED_DOT))
	var r := rules.carried(l).replicas[0]
	assert_false(r.zoom_in_glass)
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [r] as Array[ReplicaConfig])
	assert_eq(c.armament.zoom_turns(), r.zoom_in_glass, "turns only where the glass shows the change")


func test_customise_shows_the_top_zoom_of_the_variable_scope() -> void:
	var v := _aeg_with(VARIABLE)
	assert_eq(maxf(v.aim_zoom, v.aim_zoom_to), 6.0)
	assert_eq(_aeg_with(RED_DOT).aim_zoom_to, 0.0, "a fixed optic carries no top zoom")
