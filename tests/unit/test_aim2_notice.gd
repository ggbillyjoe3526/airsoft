extends GutTest
## AIM2 · noticing and flinching (game/ai/bot_senses.gd notice_time, game/ai/bot_combat.gd flinch): a fresh sighting is
## answered later off the middle of the view and far away, sooner for someone on the move, at once within
## close_awareness, and the same at every level; a BB passing close spoils a bot's aim for a moment, less on Hard.

var config: BotConfig = BotConfig.load_default()
var _none: Array[ReplicaConfig] = []


func _viewer() -> Character:
	return Character.new(0, 0, Vector3.ZERO, 0.0, _none)


func _target(at: Vector3, velocity: Vector3 = Vector3.ZERO) -> Character:
	var c := Character.new(1, 1, at, PI, _none)
	c.velocity = velocity
	return c


func _flat(a: Character, b: Character) -> float:
	return Vector2(b.position.x - a.position.x, b.position.z - a.position.z).length()


func test_someone_straight_ahead_close_by_is_noticed_almost_at_once() -> void:
	var me := _viewer()
	var you := _target(Vector3(0.0, 0.0, -5.0))
	var t := BotSenses.notice_time(me, you, _flat(me, you), config)
	assert_almost_eq(t, config.notice_far_time * 5.0 / config.view_distance, 1e-4, "only the distance's share")


func test_the_edge_of_the_view_and_the_far_end_are_slower_to_notice() -> void:
	var me := _viewer()
	var ahead := _target(Vector3(0.0, 0.0, -20.0))
	var half := deg_to_rad(config.fov_deg) * 0.5
	var edge := _target(Vector3(-sin(half) * 20.0, 0.0, -cos(half) * 20.0))
	var far := _target(Vector3(0.0, 0.0, -config.view_distance))
	var t_ahead := BotSenses.notice_time(me, ahead, _flat(me, ahead), config)
	var t_edge := BotSenses.notice_time(me, edge, _flat(me, edge), config)
	var t_far := BotSenses.notice_time(me, far, _flat(me, far), config)
	assert_almost_eq(t_edge - t_ahead, config.notice_edge_time, 1e-3, "the edge of the view adds notice_edge_time")
	assert_almost_eq(t_far, config.notice_far_time, 1e-4, "view_distance away adds notice_far_time")
	assert_gt(t_edge, t_ahead)
	assert_gt(t_far, t_ahead)


func test_someone_on_the_move_catches_the_eye_sooner() -> void:
	var me := _viewer()
	var still := _target(Vector3(-15.0, 0.0, -15.0))
	var running := _target(Vector3(-15.0, 0.0, -15.0), Vector3(config.notice_moving_speed, 0.0, 0.0))
	var t_still := BotSenses.notice_time(me, still, _flat(me, still), config)
	var t_run := BotSenses.notice_time(me, running, _flat(me, running), config)
	assert_almost_eq(t_run, t_still * config.notice_moving_share, 1e-4)


func test_within_close_awareness_there_is_nothing_to_notice() -> void:
	var me := _viewer()
	# Behind it, within reach: close_awareness sees anyone whichever way it faces.
	var you := _target(Vector3(0.0, 0.0, config.close_awareness * 0.8))
	assert_eq(BotSenses.notice_time(me, you, _flat(me, you), config), 0.0)


func test_a_near_miss_spoils_the_aim_and_eases_off_and_hard_flinches_least() -> void:
	var w := BotWorld.new()
	w.cfg = config
	w.time = 10.0
	var order: Array[StringName] = [&"easy", &"normal", &"hard"]
	var last := INF
	for level in order:
		var b := Bot.new(_viewer(), 1, config.skill_for(level), 2)
		assert_eq(BotCombat.flinch(b, w), 0.0, "%s: no near miss, no flinch" % level)
		b.suppressed_at = w.time
		var now := BotCombat.flinch(b, w)
		assert_almost_eq(now, deg_to_rad(b.skill.aim_error_under_fire_deg), 1e-6, String(level))
		w.time += config.flinch_time * 0.5
		assert_almost_eq(BotCombat.flinch(b, w), now * 0.5, 1e-6, "%s: half gone half way" % level)
		w.time += config.flinch_time
		assert_eq(BotCombat.flinch(b, w), 0.0, "%s: gone after flinch_time" % level)
		w.time = 10.0
		assert_lt(now, last, "%s flinches less than the level below" % level)
		last = now
