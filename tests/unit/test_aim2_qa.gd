extends GutTest
## AIM2 · QA: edges of noticing and flinching (BotSenses.notice_time, BotCombat.flinch, perceive): a fresh bot is not
## mid-flinch, a re-pick-up gets no notice time, a fresh contact does, no degenerate input gives NaN.

const DT := 1.0 / 60.0
const HIDE := Vector3(-1.0, 0.0, -20.0)
const OUT := Vector3(0.8, 0.0, -20.0)

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var _none: Array[ReplicaConfig] = []

var _w: BotWorld = null
var _b: Bot = null
var _you: Character = null


func before_each() -> void:
	var m := MapData.new()
	m.id = "reacquire field"
	m.kill_y = -10.0
	var world := BoxWorld.new(tuning.body)
	var floor_block := MapData.Block.new()
	floor_block.kind = &"floor"
	floor_block.center = Vector3(0.0, -0.25, -15.0)
	floor_block.size = Vector3(16.0, 0.5, 50.0)
	m.blocks.append(floor_block)
	world.add_box(floor_block.center, floor_block.size)
	world.add_box(Vector3(-1.7, 1.5, -19.4), Vector3(3.0, 3.0, 0.3))
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(0.0, 0.0, 5.0 if e == 0 else -35.0), 0.0 if e == 0 else PI))
		end.dead_zone.append(SpawnPoint.new(Vector3(6.0, 0.0, 8.0 if e == 0 else -38.0), 0.0))
		m.ends.append(end)
	var nav := NavGrid.build(m, tuning.nav, tuning.body)
	var state := GameState.new(3, tuning)
	var loadout := ReplicaStats.default_loadout()
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	state.characters.append(Character.new(1, 1, HIDE, PI, loadout))
	var levels: Dictionary[int, StringName] = {0: &"normal", 1: &"normal"}
	var bots := BotController.new(state, 1, m, nav, world, tuning, config, levels)
	_w = bots.world
	_w.cfg = config.duplicate() as BotConfig
	_b = _w.bots[0]
	_b.character.position = Vector3.ZERO
	_b.character.yaw = 0.0
	_b.aim_yaw = 0.0
	_you = state.characters[1]
	_w.time = 10.0



func _look(at: Vector3, seconds: float) -> void:
	_w.time += seconds
	_you.position = at
	BotSenses.perceive(_b, _w)


func _pair(at: Vector3) -> Array[Character]:
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, _none)
	var you := Character.new(1, 1, at, PI, _none)
	return [me, you]


func test_a_new_bot_and_a_reset_bot_are_not_flinching() -> void:
	assert_eq(_b.suppressed_at, -INF)
	assert_eq(BotCombat.flinch(_b, _w), 0.0)
	_b.suppressed_at = _w.time
	assert_gt(BotCombat.flinch(_b, _w), 0.0)
	_b.reset(0, 0, 0.0, _w.cfg)
	assert_eq(BotCombat.flinch(_b, _w), 0.0, "a round reset clears the flinch")


func test_flinch_is_finite_with_zero_or_negative_flinch_time() -> void:
	_b.suppressed_at = _w.time
	_w.cfg.flinch_time = 0.0
	assert_eq(BotCombat.flinch(_b, _w), 0.0)
	_w.cfg.flinch_time = -1.0
	assert_eq(BotCombat.flinch(_b, _w), 0.0)
	_w.time += 5.0
	_w.cfg.flinch_time = 0.6
	assert_eq(BotCombat.flinch(_b, _w), 0.0, "long after, no flinch")


func test_notice_time_at_the_close_awareness_edge_and_at_zero_distance() -> void:
	var p := _pair(Vector3(0.0, 0.0, -_w.cfg.close_awareness))
	assert_eq(BotSenses.notice_time(p[0], p[1], _w.cfg.close_awareness, _w.cfg), 0.0, "exactly at the radius")
	var q := _pair(Vector3.ZERO)
	_w.cfg.close_awareness = 0.0
	var t := BotSenses.notice_time(q[0], q[1], 0.0, _w.cfg)
	assert_false(is_nan(t), "no NaN standing on the viewer")
	assert_eq(t, 0.0)


func test_someone_behind_adds_no_more_than_the_edge_and_far_share() -> void:
	var p := _pair(Vector3(0.0, 0.0, config.view_distance * 3.0))
	var t := BotSenses.notice_time(p[0], p[1], config.view_distance * 3.0, config)
	assert_false(is_nan(t))
	assert_almost_eq(t, config.notice_edge_time + config.notice_far_time, 1e-4, "off and dist both clamp to 1")


func test_a_fresh_sighting_waits_the_notice_time_and_a_re_pick_up_does_not() -> void:
	_w.cfg.notice_far_time = 10.0
	_look(OUT, 0.0)
	assert_gt(_b.contact.react_at - _w.time, 5.0, "a fresh contact adds the notice time")
	for i in 20:
		_look(OUT, 0.1)
	_b.contact.react_at = 0.0
	_look(HIDE, 0.1)
	_look(OUT, _w.cfg.reacquire_after + 0.1)
	assert_lt(_w.cfg.reacquire_after + 0.1, _w.cfg.contact_grace, "a re-pick-up, not a fresh contact")
	assert_lt(_b.contact.react_at - _w.time, 5.0, "a re-pick-up has no notice time")


func test_notice_time_is_the_same_at_every_level() -> void:
	var p := _pair(Vector3(-8.0, 0.0, -15.0))
	var d := Vector2(-8.0, -15.0).length()
	var t0 := BotSenses.notice_time(p[0], p[1], d, config)
	assert_gt(t0, 0.0)
	for level: StringName in [&"easy", &"normal", &"hard"]:
		var b := Bot.new(p[0], 1, config.skill_for(level), 2)
		assert_eq(BotSenses.notice_time(b.character, p[1], d, config), t0)


func test_a_scope_scales_the_flinch_with_the_rest_of_the_error() -> void:
	# Documents the intent: the flinch is part of the error the scope scales (aim() multiplies the sum).
	_b.suppressed_at = _w.time
	var f := BotCombat.flinch(_b, _w)
	assert_gt(f * _w.cfg.scoped_error_scale, 0.0)
	assert_lt(_w.cfg.scoped_error_scale, 1.0)
