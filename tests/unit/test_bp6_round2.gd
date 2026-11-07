extends GutTest
## BP6 round 2: a staged load finds the bots' vault links over several frames and their cover off the main thread, and
## they are the very ones an unstaged build finds; a load left mid-way waits for its worker and leaves nothing behind.

const LOAD_LIMIT := 30.0


func _session(staged: bool) -> PlaySession:
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.map_id = "depot"
	session.match_seed = 7
	session.autopilot = true
	session.staged = staged
	add_child_autofree(session)
	return session


static func _footprints(blocks: Array[BotCover.Block]) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for k in blocks:
		out.append(Rect2(k.center, k.half))
	return out


func test_a_staged_load_gives_the_bots_the_links_and_cover_an_unstaged_build_finds() -> void:
	var whole := _session(false)
	assert_not_null(whole._bots)
	var staged := _session(true)
	await wait_until(func() -> bool: return staged._bots != null, LOAD_LIMIT)
	assert_not_null(staged._bots, "the staged load built its bots")
	if whole._bots == null or staged._bots == null:
		return
	var a := whole._bots.world
	var b := staged._bots.world
	assert_gt(a.nav.vault_to.size(), 0, "Depot has vault links")
	assert_eq(b.nav.vault_to, a.nav.vault_to)
	assert_eq(b.nav.vault_start, a.nav.vault_start)
	assert_eq(b.nav.astar.get_point_count(), a.nav.astar.get_point_count())
	assert_gt(a.low_cover.size(), 0)
	assert_eq(_footprints(b.low_cover), _footprints(a.low_cover))
	assert_eq(_footprints(b.tall_cover), _footprints(a.tall_cover))
	assert_eq(staged._cover_task, -1, "the cover's task is done with")


func test_a_load_left_while_the_bots_groundwork_runs_waits_for_it_and_leaves_nothing_behind() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var session := PlaySession.new()
	session.map_id = "woodland"
	session.staged = true
	add_child(session)
	await wait_until(func() -> bool: return session._vaults != null or session._bots != null, LOAD_LIMIT)
	assert_null(session._bots, "left before the views step")
	await wait_process_frames(2)
	assert_not_null(session._vaults, "Woodland's links take more than a frame's slice")
	assert_gt(session._vaults.next, 0, "a slice a frame")
	remove_child(session)
	session.free()
	await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)


# --- Leaving while it loads ---

const MAIN := preload("res://game/main.tscn")


func after_each() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


static func _esc() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	return ev


func _assert_left_to_the_match_page(main: Node, why: String) -> void:
	assert_true(await wait_until(func() -> bool: return main._play == null, LOAD_LIMIT), "%s: left" % why)
	await wait_process_frames(2)
	assert_null(main._loading, "%s: the loading screen gone" % why)
	assert_not_null(main._menus, "%s: the menus back" % why)
	if main._menus != null:
		assert_eq(main._menus.page_tab(), NavRail.Tab.MATCH, "%s: on the Match page" % why)
	assert_eq(main.find_children("*", "PlaySession", true, false).size(), 0, "%s: no match left" % why)


func test_esc_on_the_loading_screen_leaves_while_the_nav_grid_builds() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main._start_play()
	var play: PlaySession = main._play
	await wait_until(func() -> bool: return play._nav_task >= 0 or play._running, LOAD_LIMIT)
	assert_false(play._running, "still loading")
	main._unhandled_input(_esc())
	assert_not_null(main._loading, "the screen stays up while the worker finishes")
	if main._loading != null:
		assert_eq(main._loading.step_text(), tr("LOAD_LEAVING"), "and says the press was taken")
		assert_ne(tr("LOAD_LEAVING"), "LOAD_LEAVING", "in words")
	# Nothing starts the match meanwhile.
	play.go()
	assert_false(play.holding(), "not held")
	assert_ne(Input.mouse_mode, Input.MOUSE_MODE_CAPTURED, "the mouse not taken")
	await _assert_left_to_the_match_page(main, "left mid-load")


func test_esc_on_the_loading_screen_held_for_continue_leaves_too() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main.continue_after_loading = true
	main._start_play()
	var play: PlaySession = main._play
	assert_true(await wait_until(func() -> bool: return play.holding(), LOAD_LIMIT), "held for Continue")
	main._unhandled_input(_esc())
	await _assert_left_to_the_match_page(main, "left at Continue")


# --- The hit volume eases into the holster and the sprint as the drawn figure does (UpperBlend) ---

const TICK := 1.0 / 60.0


func _armed() -> Character:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	return c


func test_the_simulations_holster_and_sprint_eases_are_the_drawn_figures_at_60_fps() -> void:
	var hits := HitConfig.new()
	var c := _armed()
	var pose := FigurePose.new(FigureConfig.new())
	pose.read(c, 1.0, hits)
	pose.snap()
	var worst := 0.0
	for i in 90:
		# Holstered, then sprinting, then drawn out of the holster (the replica in hand from holster_swap of the draw).
		if i == 0:
			c.armament.holstered = true
		if i == 20:
			c.sprinting = true
		if i == 40:
			c.sprinting = false
			c.armament._draw(c.armament.active, c.id, SimEvents.new(), 1.0)
		if c.armament.draw_left > 0.0:
			c.armament.draw_left = maxf(0.0, c.armament.draw_left - TICK)
		UpperBlend.step(c, hits, TICK)
		pose.read(c, 1.0, hits)
		pose.settle(TICK)
		worst = maxf(worst, maxf(absf(pose.holster_weight - c.holster_weight), absf(pose.sprint_weight - c.sprint_weight)))
		if i == 0:
			assert_almost_eq(c.holster_weight, 1.0 - exp(-TICK / hits.settle_holster), 1e-6, "one tick into the holster")
		if i == 41:
			assert_true(c.armament.drawn_from_holster, "the draw came out of the holster")
			assert_gt(c.holster_weight, 0.99, "early in the draw from it, still put away")
	assert_lt(worst, 1e-5, "the drawn weights are the simulation's, tick by tick")
	assert_lt(c.holster_weight, 0.01, "drawn: in the aim")
	assert_lt(c.sprint_weight, 0.01)


func test_one_tick_into_the_holster_the_volumes_shoulders_have_moved_only_part_way() -> void:
	var hits := HitConfig.new()
	var c := _armed()
	var lower := PackedVector3Array()
	var aimed := PackedVector3Array()
	var put_away := PackedVector3Array()
	var part := PackedVector3Array()
	Hitbox.fitted_joints(c, hits, lower, aimed)
	aimed = aimed.duplicate()
	c.armament.holstered = true
	c.holster_weight = UpperBlend.holster_target(c.armament, hits.holster_swap)
	c.sprint_weight = 1.0 if c.sprinting else 0.0
	Hitbox.fitted_joints(c, hits, lower, put_away)
	put_away = put_away.duplicate()
	c.holster_weight = 0.0
	UpperBlend.step(c, hits, TICK)
	Hitbox.fitted_joints(c, hits, lower, part)
	var k := HitFit.SHOULDER_R
	var whole := aimed[k].distance_to(put_away[k])
	assert_gt(whole, 0.01, "the holster moves the shoulder")
	assert_almost_eq(aimed[k].distance_to(part[k]) / whole, c.holster_weight, 0.1, "as far as the ease has come")
	assert_lt(c.holster_weight, 0.5)
