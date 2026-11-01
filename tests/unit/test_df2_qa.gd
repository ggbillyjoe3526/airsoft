extends GutTest
## QA for DF2a (Hard's solo habits): edge cases of held angles, slicing, the peek watch and the Match page, and a Hard match
## played twice on one seed (game/ai/bot_combat.gd, bot_brain.gd, bot_angles.gd, game/ui/match_page.gd).

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var _w: BotWorld = null


func _wall() -> BoxWorld:
	var q := BoxWorld.new()
	q.add_box(Vector3(-15.0, 1.5, -8.5), Vector3(30.0, 3.0, 1.0))
	return q


func _bot(level: StringName, query: WorldQuery, at: Vector3 = Vector3.ZERO) -> Bot:
	var loadout := ReplicaStats.default_loadout()
	var me := Character.new(0, 0, at, 0.0, loadout)
	var foe := Character.new(1, 1, Vector3(0.0, 0.0, -40.0), 0.0, loadout)
	_w = BotWorld.new()
	_w.tuning = tuning
	_w.cfg = config
	_w.query = query
	_w.planner = RoundPlanner.new(1)
	_w.planner.enemy_yaw[0] = 0.0
	_w.characters = [me, foe]
	_w.time = 10.0
	return Bot.new(me, 1, config.skill_for(level), 2)


func _aim(b: Bot, walking: bool, cmd: PlayerCommand) -> void:
	BotCombat.aim(b, _w, null, BotSenses.eye_of(b.character, tuning), walking, cmd, DT)


func test_pro_holding_in_the_open_with_no_angles_sweeps_as_before_without_error() -> void:
	var b := _bot(&"hard", WorldQuery.new())
	b.holding = true
	var cmd := PlayerCommand.new()
	for i in 120:
		b.team_wait += DT
		_aim(b, false, cmd)
	assert_eq(b.held_angle_count, 0)
	assert_true(is_finite(b.aim_yaw))
	assert_lte(absf(b.aim_yaw), deg_to_rad(config.hold_sweep_deg) + 0.01, "sweeps within its arc")


func test_slicing_in_the_open_walks_where_it_looks_and_never_leans() -> void:
	var b := _bot(&"hard", WorldQuery.new())
	b.careful = true
	b.mode = Bot.Mode.ADVANCE
	b.move_dir = Vector3(0.0, 0.0, -1.0)
	var cmd := PlayerCommand.new()
	for i in 60:
		_aim(b, true, cmd)
	assert_eq(cmd.lean, 0.0)
	assert_lt(absf(b.aim_yaw), deg_to_rad(0.5))


func test_any_hold_time_picks_a_valid_angle_even_as_the_count_changes() -> void:
	var b := _bot(&"hard", _wall())
	b.holding = true
	var cmd := PlayerCommand.new()
	for t: float in [0.0, 2.99, 3.0, 5.9, 6.0, 1.0e6, 123456.789]:
		b.team_wait = t
		b.held_angles_at = -INF
		_aim(b, false, cmd)
		assert_between(b.held_angle_count, 0, BotAngles.KEPT)
		assert_true(is_finite(b.aim_yaw), "t=%s" % t)
	# The count dropping to zero (walls gone) after having had angles falls back to the sweep.
	b.team_wait = 7.0
	_w.query = WorldQuery.new()
	b.held_angles_at = -INF
	_aim(b, false, cmd)
	assert_eq(b.held_angle_count, 0)
	assert_true(is_finite(b.aim_yaw))


func test_a_crouched_pro_finds_the_same_corner_as_standing() -> void:
	var stand := _bot(&"hard", _wall())
	stand.holding = true
	var crouch := _bot(&"hard", _wall())
	crouch.holding = true
	crouch.character.crouch_amount = 1.0
	var cmd := PlayerCommand.new()
	_aim(stand, false, cmd)
	_aim(crouch, false, cmd)
	assert_eq(crouch.held_angle_count, stand.held_angle_count)
	assert_gt(stand.held_angle_count, 0)
	assert_almost_eq(crouch.held_angles[0].point.y, stand.held_angles[0].point.y, 0.001, "head height")


func test_a_moving_holder_looks_for_corners_afresh_once_it_has_moved() -> void:
	var b := _bot(&"hard", _wall(), Vector3(0.0, 0.0, 0.0))
	b.holding = true
	var cmd := PlayerCommand.new()
	_aim(b, false, cmd)
	var first := b.held_angles[0].point
	b.character.position = Vector3(0.0, 0.0, 3.0)
	_w.time += 0.1
	_aim(b, false, cmd)
	assert_ne(b.held_angles[0].point, first, "the corner is re-aimed from the new spot")


func test_a_bot_reset_for_a_new_round_forgets_its_watch_and_its_angles() -> void:
	var b := _bot(&"hard", _wall())
	b.watch_until = 99999.0
	b.held_angle_count = 2
	b.careful = true
	b.reset(0, 0, 0.0, config)
	assert_eq(b.watch_until, -INF)
	assert_eq(b.held_angle_count, 0)
	assert_false(b.careful)
	var cmd := PlayerCommand.new()
	assert_false(BotMovement._search(b, _w, cmd, DT), "no leftover pause")


func test_the_watch_is_not_started_without_a_contact_or_below_pro() -> void:
	var b := _bot(&"hard", WorldQuery.new())
	b.mode = Bot.Mode.FIGHT
	b.has_last_known = true
	b.heard_at = _w.time
	b.contact = null
	BotBrain._choose_mode(b, _w, null, DT)
	assert_eq(b.watch_until, -INF, "someone only heard is not a peek")


func test_a_watch_ends_when_the_enemy_is_seen_again_and_it_fights() -> void:
	var b := _bot(&"hard", WorldQuery.new())
	# A floor under both, for a search that goes round by a flank (the bot's draws decide whether it does).
	var m := MapData.new()
	var floor_block := MapData.Block.new()
	floor_block.kind = &"floor"
	floor_block.center = Vector3(0.0, -0.25, -20.0)
	floor_block.size = Vector3(100.0, 0.5, 100.0)
	m.blocks.append(floor_block)
	_w.nav = NavGrid.build(m, tuning.nav, tuning.body)
	var foe := _w.characters[1]
	BotSenses.perceive(b, _w)
	b.mode = Bot.Mode.FIGHT
	_w.time += 1.0
	b.target_visible = false
	BotBrain._choose_mode(b, _w, foe, DT)
	assert_eq(b.mode, Bot.Mode.SEARCH)
	b.target_visible = true
	b.cover_cooldown = 99.0
	BotBrain._choose_mode(b, _w, foe, DT)
	assert_eq(b.mode, Bot.Mode.FIGHT, "seen during the watch: back to the fight")


func test_a_pro_match_plays_the_same_twice_and_no_bot_stays_stuck() -> void:
	var tally: Array[MatchRunner.MatchTally] = []
	for run in 2:
		var r := MatchRunner.new(self, "depot")
		r.difficulty = &"hard"
		await wait_physics_frames(2)
		tally.append(r.play(7, 90.0))
		r.free_level()
	assert_eq(tally[0].ticks, tally[1].ticks)
	assert_eq(tally[0].hits, tally[1].hits)
	assert_eq(tally[0].rounds.size(), tally[1].rounds.size())
	assert_eq(tally[0].farthest, tally[1].farthest)
	assert_eq(tally[0].held_up, 0)
	assert_gt(tally[0].hits, 0, "Hard shoots")


func test_a_pro_pick_saved_opens_as_pro_with_dev_content_off() -> void:
	var picks := MatchPicks.new()
	picks.bots = "hard"
	var page := MatchPage.new(picks, Settings.new())
	add_child_autofree(page)
	await wait_physics_frames(2)
	assert_eq(page.picks.bots, "hard", "Hard is public since DF2b")
	assert_string_ends_with(page.summary_text(), "Hard bots")
	assert_true(page.bot_button("hard").is_picked())
