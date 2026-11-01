extends GutTest
## HD2 QA: the cards under the hit call and banner stack stay on screen, in each place a banner or card shows; the
## stack follows a resize, the range (no score bar) and a banner the hit call was shown with.

const HudSizeTest := preload("res://tests/unit/test_hud_size.gd")
const WINDOWS: Array[Vector2] = [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0), Vector2(3840.0, 2160.0),
		Vector2(1024.0, 768.0), Vector2(2560.0, 1080.0)]
const SIZES: Array[float] = [0.8, 1.0, 1.5]
const SLACK := 0.5

var you: Character = null
var state: GameState = null


func before_each() -> void:
	you = Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	you.prev_position = you.position
	state = GameState.new(1)
	state.characters.append(you)


func _hud(window: Vector2, hud_size: float) -> Hud:
	var area := HudSizeTest.canvas_of(window)
	var frame := Control.new()
	frame.size = area
	add_child_autofree(frame)
	var hud := Hud.new()
	frame.add_child(hud)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
	var prefs := HudPrefs.new()
	prefs.hud_size = hud_size
	hud.apply_prefs(prefs)
	hud._stats = MatchStats.new()
	hud._names = PackedStringArray(["You"])
	return hud


func _xp(hud: Hud, bonus: int = 0) -> void:
	var pool := Pool.read_file()
	var levels := LevelTable.read_file(pool)
	var progress := Progress.new(levels)
	var outcome := MatchXp.Outcome.new()
	outcome.won = true
	outcome.rounds_won = 3
	outcome.hits = 4
	var settled := PlayerTally.Settled.new()
	settled.earned = MatchXp.earned(levels, outcome)
	settled.level_up = progress.add_xp(settled.earned.total + bonus)
	hud.show_xp(settled, progress)


func _inside(c: Control, canvas: Vector2, what: String) -> void:
	var r := c.get_global_rect()
	assert_true(Rect2(Vector2.ZERO, canvas).grow(SLACK).encloses(r), "%s off the %s canvas: %s" % [what, canvas, r])


func _under_bar(hud: Hud, what: String) -> void:
	var bar := hud._top.get_global_rect().end.y
	for part: Control in [hud._hit_label, hud._hit_sub, hud._banner]:
		if part.is_visible_in_tree():
			assert_gte(part.get_global_rect().position.y, bar - SLACK, "%s: %s under the score bar" % [what, part.name])


func test_the_xp_card_and_summary_stay_on_screen_under_the_hit_call_and_banner() -> void:
	for window in WINDOWS:
		var area := HudSizeTest.canvas_of(window)
		for hud_size in SIZES:
			for bonus: int in [0, 1500]:
				for ended: bool in [false, true]:
					var hud := _hud(window, hud_size)
					you.status = Character.Status.CALLING
					hud._show_banner("WON", "ROUND 5 · BETA TAKE THE MATCH")
					_xp(hud, bonus)
					hud.open_summary(state, true, "Hold the angle")
					hud.update(state, 1.0, 0.0)
					if ended:
						you.status = Character.Status.OUT
						hud.update(state, 1.0, 0.0)
					await wait_process_frames(3)
					var what := "%s at %d%%, level-up %s, call over %s" % [window, roundi(hud_size * 100.0), bonus > 0, ended]
					_inside(hud._xp, area, "XP card, " + what)
					_inside(hud._summary._table, area, "summary table, " + what)
					_inside(hud._summary._side, area, "summary side, " + what)
					hud.get_parent().queue_free()


func test_the_round_table_stays_on_screen_under_the_hit_call_banner_and_every_line_under_the_bar() -> void:
	for window in WINDOWS:
		var area := HudSizeTest.canvas_of(window)
		for hud_size in SIZES:
			var hud := _hud(window, hud_size)
			you.status = Character.Status.CALLING
			state.round_state.mode = RoundState.Mode.ATTACK_DEFEND
			state.round_state.attackers = 1
			hud._show_banner("LOST", "ROUND 1 · BETA TAKE THE ROUND")
			hud.show_graphics_step("Low", 5.0)
			hud.round_result().round_over(1, 30, state.time)
			state.time += 60.0
			hud.update(state, 1.0, 0.05)
			hud._warning.visible = true
			await wait_process_frames(3)
			var what := "%s at %d%%" % [window, roundi(hud_size * 100.0)]
			assert_true(hud.round_result().table().is_visible_in_tree(), what + ": the round's table shows")
			assert_true(hud._gauge.is_visible_in_tree(), what + ": the flag gauge shows")
			_under_bar(hud, what)
			_inside(hud.round_result().table(), area, "round table, " + what)
			hud.get_parent().queue_free()


func test_the_range_starts_the_stack_a_margin_down_with_no_score_bar() -> void:
	for hud_size in SIZES:
		var hud := _hud(Vector2(1920.0, 1080.0), hud_size)
		hud.setup_range(RangeConfig.new())
		hud._show_banner("TIME", "TARGETS 8")
		hud.update(state, 1.0, 0.0)
		await wait_process_frames(3)
		assert_false(hud._top.is_visible_in_tree(), "no score bar on the range")
		assert_almost_eq(hud._banner.get_global_rect().position.y, Hud.MARGIN * hud_size, 0.5, "the banner a margin down at %s" % hud_size)
		hud.get_parent().queue_free()


func test_a_resize_mid_banner_keeps_the_stack_under_the_bar_and_the_cards_under_it() -> void:
	var hud := _hud(Vector2(1920.0, 1080.0), 1.0)
	var frame := hud.get_parent() as Control
	you.status = Character.Status.CALLING
	hud._show_banner("WON", "ROUND 5 · BETA TAKE THE MATCH")
	_xp(hud)
	hud.update(state, 1.0, 0.0)
	await wait_process_frames(3)
	for window: Vector2 in [Vector2(1024.0, 768.0), Vector2(2560.0, 1080.0), Vector2(1280.0, 720.0)]:
		var area := HudSizeTest.canvas_of(window)
		frame.size = area
		await wait_process_frames(3)
		_under_bar(hud, "after a resize to %s" % window)
		var foot := hud._banner.get_global_rect().end.y
		assert_almost_eq(hud._xp.get_global_rect().position.y, foot + Hud.XP_GAP, 0.5, "the XP card follows the stack at %s" % window)
		_inside(hud._xp, area, "XP card after a resize to %s" % window)


func test_a_hud_size_change_mid_banner_re_hangs_the_stack_and_cards() -> void:
	var hud := _hud(Vector2(1920.0, 1080.0), 1.0)
	you.status = Character.Status.CALLING
	hud._show_banner("WON", "ROUND 5 · BETA TAKE THE MATCH")
	_xp(hud)
	hud.update(state, 1.0, 0.0)
	await wait_process_frames(3)
	for hud_size in SIZES:
		var prefs := HudPrefs.new()
		prefs.hud_size = hud_size
		hud.apply_prefs(prefs)
		await wait_process_frames(3)
		_under_bar(hud, "after HUD size %s" % hud_size)
		assert_almost_eq(hud._xp.get_global_rect().position.y, hud._banner.get_global_rect().end.y + Hud.XP_GAP * hud_size, 0.5,
				"the XP card %s under the banner at %s" % [Hud.XP_GAP, hud_size])


func test_a_hit_call_over_a_banner_already_up_clears_the_score_bar_and_the_banner_sits_under_it() -> void:
	for hud_size in SIZES:
		var hud := _hud(Vector2(1920.0, 1080.0), hud_size)
		hud._show_banner("ATTACK", "TAKE THE FLAG")
		hud.update(state, 1.0, 0.0)
		await wait_process_frames(3)
		you.status = Character.Status.CALLING
		hud.update(state, 1.0, 0.0)
		await wait_process_frames(3)
		_under_bar(hud, "hit while a banner is up at %s" % hud_size)
		assert_gte(hud._banner.get_global_rect().position.y, hud._hit_sub.get_global_rect().end.y - SLACK, "banner under the call")
		hud.get_parent().queue_free()


func test_the_next_round_s_banner_sits_right_under_the_bar_after_a_hit_that_showed_with_the_last_one() -> void:
	var hud := _hud(Vector2(1920.0, 1080.0), 1.0)
	you.status = Character.Status.CALLING
	hud._show_banner("LOST", "ROUND 1 · BETA TAKE THE ROUND")
	hud.update(state, 1.0, 0.0)
	await wait_process_frames(3)
	you.status = Character.Status.OUT
	hud.update(state, 1.0, 0.0)
	await wait_process_frames(3)
	var held_at := hud._banner.get_global_rect().position.y
	# The next round starts: the HUD shows its banner over the LOST one (nothing hides it first) and you are back in play.
	you.status = Character.Status.ALIVE
	hud._show_banner("ROUND 2", "BETA TAKE THE ROUND")
	hud.update(state, 1.0, 0.0)
	await wait_process_frames(3)
	var bar := hud._top.get_global_rect().end.y
	assert_lt(hud._banner.get_global_rect().position.y, held_at, "the new banner does not keep the old call's empty slot")
	assert_almost_eq(hud._banner.get_global_rect().position.y, bar + Hud.MIDDLE_GAP, 0.5, "right under the score bar")


func test_the_hit_feed_stays_clear_of_the_hit_call_and_banner() -> void:
	for window in WINDOWS:
		for hud_size in SIZES:
			var hud := _hud(window, hud_size)
			var mate := Character.new(1, 1, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
			state.characters.append(mate)
			hud.setup_field(BoxWorld.new(), BodyConfig.new(), PackedStringArray(["You", "Bot"]), state.characters, hud._stats)
			hud._names = PackedStringArray(["You", "Bot"])
			for i in 8:
				hud.hit_lines().add(1, 0, state.time, true)
				hud.hit_lines().add_call(1, "Hit!", state.time)
			you.status = Character.Status.CALLING
			hud._show_banner("LOST", "ROUND 1 · BETA TAKE THE ROUND")
			hud.update(state, 1.0, 0.0)
			await wait_process_frames(3)
			var feed := hud.feed().get_global_rect()
			for part: Control in [hud._hit_label, hud._hit_sub, hud._banner]:
				var r := part.get_global_rect()
				if part is Label:
					r = Rect2(r.get_center() - (part as Label).get_minimum_size() * 0.5, (part as Label).get_minimum_size())
				assert_false(feed.intersects(r), "%s at %d%%, %s: feed %s over %s %s" % [window, roundi(hud_size * 100.0), part.name, feed, part.name, r])
			state.characters.erase(mate)
			hud.get_parent().queue_free()




func test_the_cards_refit_when_the_hud_size_or_window_changes_mid_summary() -> void:
	var hud := _hud(Vector2(1920.0, 1080.0), 1.0)
	var frame := hud.get_parent() as Control
	you.status = Character.Status.CALLING
	hud._show_banner("WON", "ROUND 5 · BETA TAKE THE MATCH")
	_xp(hud, 1500)
	hud.open_summary(state, true, "Hold the angle")
	hud.update(state, 1.0, 0.0)
	await wait_process_frames(3)
	var area := frame.size
	for step: Array in [[1.5, Vector2(1920.0, 1080.0)], [1.5, Vector2(1024.0, 768.0)], [0.8, Vector2(1280.0, 720.0)], [1.5, Vector2(2560.0, 1080.0)]]:
		var prefs := HudPrefs.new()
		prefs.hud_size = step[0]
		hud.apply_prefs(prefs)
		area = HudSizeTest.canvas_of(step[1])
		frame.size = area
		await wait_process_frames(3)
		var what := "mid-summary at %s on %s" % [step[0], step[1]]
		_inside(hud._xp, area, "XP card " + what)
		_inside(hud._summary._table, area, "summary table " + what)
		_inside(hud._summary._side, area, "summary side " + what)


func test_the_round_table_under_the_call_banner_step_line_and_gauge_stays_readable_on_screen() -> void:
	for gauge: bool in [false, true]:
		var hud := _hud(Vector2(1280.0, 720.0), 1.5)
		you.status = Character.Status.CALLING
		if gauge:
			state.round_state.mode = RoundState.Mode.ATTACK_DEFEND
			state.round_state.attackers = 1
		hud._show_banner("LOST", "ROUND 1 · BETA TAKE THE ROUND")
		hud.show_graphics_step("Low", 5.0)
		hud.round_result().round_over(1, 30, state.time)
		state.time += 60.0
		hud.update(state, 1.0, 0.05)
		await wait_process_frames(3)
		_inside(hud._round_result, HudSizeTest.canvas_of(Vector2(1280.0, 720.0)), "round table, gauge %s" % gauge)
		assert_gte(hud._round_result.scale.x * 1.5, 0.6, "row text still readable (gauge %s)" % gauge)
		hud.get_parent().queue_free()
