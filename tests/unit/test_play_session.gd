extends GutTest
## Playing Depot (game/play/play_session.gd), headless: the session builds the level, puts you on Alpha with four bots
## against five, steps the simulation with every command on the physics tick, and draws from it; a BB from your replica
## knocks a bot out on the Jolt level and they call the hit; Esc pauses and resumes; leaving frees everything; the
## minimap hears the other team through the ears the view is through.

var session: PlaySession = null


func before_each() -> void:
	session = PlaySession.new()
	session.autopilot = true # no mouse here: a bot plays you
	add_child_autofree(session)
	await wait_physics_frames(2)


func after_each() -> void:
	get_tree().paused = false


func test_you_play_alpha_with_bots_against_a_team_of_bots() -> void:
	var s := session.state
	var size := MapCatalog.shared().find("depot").team_standard
	assert_eq(s.characters.size(), size * 2, "Depot's standard, 5 v 5")
	assert_eq(session.player.team, 0)
	var per_team := PackedInt32Array([0, 0])
	for c in s.characters:
		per_team[c.team] += 1
	assert_eq(per_team, PackedInt32Array([size, size]))
	assert_true(s.round_state.is_live())
	assert_true(session.player.grounded, "standing on Depot's floor")


func test_the_simulation_steps_on_the_physics_tick() -> void:
	var before := session.ticks()
	await wait_physics_frames(10)
	assert_gte(session.ticks() - before, 10)
	var moved := false
	for c in session.state.characters:
		moved = moved or c.position.distance_to(c.spawn_position) > 0.1
	assert_true(moved, "the bots set off")


func test_a_bb_knocks_a_bot_out_and_they_call_it() -> void:
	session.autopilot = false
	session.bots_active = false
	# The last Beta bot of its spawn line, held still, in its spawn room; you 5 m from it.
	var target := session.state.characters[session.state.characters.size() - 1]
	var you := session.player
	you.position = target.position + Vector3(3.0, 0.0, -4.0)
	you.prev_position = you.position
	var chest := target.position + Vector3(0.0, 1.3, 0.0)
	var d := chest - you.eye(SimTuning.new().body)
	session._input.face(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	session._input.active = true
	Input.action_press(&"fire")
	var called := false
	for i in 90:
		await wait_physics_frames(1)
		if target.status != Character.Status.ALIVE:
			called = true
			break
	Input.action_release(&"fire")
	assert_true(called, "the stand-in was hit")
	assert_eq(target.hit_by, you.id)
	await wait_process_frames(2)
	var figure := session.find_child("Figure_%d" % target.id, true, false) as FigureView
	assert_not_null(figure)
	var sign := figure.find_children("*", "Label3D", true, false)[0] as Label3D
	assert_true(sign.visible, "HIT! shows over the bot's head")


func test_escape_pauses_and_resumes() -> void:
	session.autopilot = false
	session._capture()
	var esc := InputEventAction.new()
	esc.action = &"pause"
	esc.pressed = true
	session._unhandled_input(esc)
	assert_true(get_tree().paused)
	assert_false(session._input.active, "keys stop reaching the command")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	var menu := session.find_child("PauseMenu", true, false) as PauseMenu
	assert_true(menu.visible)
	menu._unhandled_input(esc)
	assert_false(get_tree().paused)
	assert_false(menu.visible)
	assert_true(session._input.active)


func test_leaving_emits_left_and_freeing_leaves_no_orphans() -> void:
	watch_signals(session)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	session._leave()
	assert_signal_emitted(session, "left")
	session.get_parent().remove_child(session)
	session.free()
	await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans)


func test_a_map_that_wont_load_is_refused_with_a_way_back() -> void:
	var bad := PlaySession.new()
	bad.map_id = "no_such_map"
	add_child_autofree(bad)
	assert_push_error("refused")
	await wait_process_frames(1)
	assert_null(bad.state, "no match without a map")
	var back := bad.find_children("*", "Button", true, false)
	assert_eq(back.size(), 1)


func test_the_late_materials_are_drawn_once_at_the_start_and_then_freed() -> void:
	var fresh := PlaySession.new()
	add_child_autofree(fresh)
	var prewarm := fresh.find_child("ShaderPrewarm", true, false) as ShaderPrewarm
	assert_not_null(prewarm, "the specks hang under the camera from the first frame")
	var figures := fresh._figure_models.materials(fresh.team_colours().figures.colours,
			fresh.team_colours().figures.glow).size()
	assert_gt(figures, 0)
	var skyline := fresh._skyline.materials().size() if fresh._skyline != null else 0
	var site := fresh._site.materials().size() if fresh._site != null else 0
	var overtime := fresh.overtime_flag_view().materials().size() if fresh.overtime_flag_view() != null else 0
	var mags := fresh._mag_tosses.materials().size() if fresh._mag_tosses != null else 0
	var bombs := fresh._grenades.materials().size()
	var roof := fresh._roof.materials().size() if fresh._roof != null else 0
	var doors := fresh._doors.materials().size() if fresh._doors != null else 0
	var arms := fresh._hands.arms_materials().size()
	assert_gt(arms, 0, "your arms (BL4)")
	assert_eq(prewarm.get_child_count(), 10 + skyline + site + overtime + mags + bombs + roof + doors + arms
			+ 2 * figures,
			"a BB, its trail (FB4), a glowing BB and its streak (WL8), a puff, a gas puff, kicked dust, the contact shadow, a wind speck,"
			+ " the sign, the skyline's, the site dress's (DD1), the overtime flag's (OV3), the tossed magazines' (MH3),"
			+ " the bombs' (SF1), the roof's (DR1), the doors' (DO1), your arms' (BL4) and each figure material solid and"
			+ " fading")
	await wait_process_frames(ShaderPrewarm.FRAMES + 1)
	assert_false(is_instance_valid(prewarm), "gone once its frames are drawn")


func test_out_in_the_dead_zone_you_watch_a_teammate_still_in_play() -> void:
	session.autopilot = false
	session.bots_active = false
	assert_eq(session.spectated(), session.player)
	session.player.status = Character.Status.OUT
	var watched := session.spectated()
	assert_ne(watched, session.player)
	assert_eq(watched.team, session.player.team)
	for c in session.state.characters:
		if c.team == session.player.team and c != session.player:
			c.status = Character.Status.OUT
	assert_ne(session.spectated().team, session.player.team, "with your team out, anyone still in play")
	await wait_process_frames(2)
	var figure := session.find_child("Figure_%d" % session.spectated().id, true, false) as FigureView
	assert_false(figure.visible, "the watched figure isn't drawn over the view")
	session.player.status = Character.Status.ALIVE


func test_the_minimap_hears_the_other_team_through_the_eyes_you_see_through() -> void:
	session.bots_active = false
	var heard := session.minimap_hearing()
	await wait_physics_frames(1)
	var you := session.player
	assert_eq(heard.listener_id, you.id)
	assert_eq(heard.side, you.team)
	assert_eq(heard.patches.size(), session.state.characters.size(), "a record for each player")
	var enemy: Character = null
	for c in session.state.characters:
		if c.team != you.team:
			enemy = c
			break
	enemy.position = you.position + Vector3(5.0, 0.0, 0.0)
	var events := session.state.events
	events.clear()
	var e := events.add(GameEvent.Kind.FOOTSTEP)
	e.actor = enemy.id
	e.position = enemy.position
	session._after_tick()
	assert_true(heard.patch_of(enemy.id).live, "a footstep 5 m off is heard")
	you.status = Character.Status.OUT
	events.clear()
	session._after_tick()
	assert_ne(heard.listener_id, you.id, "out: heard through the teammate you watch")
	assert_eq(heard.listener_id, session.spectated().id)
	assert_true(heard.patch_of(enemy.id).live, "what your side heard stays")
	you.status = Character.Status.ALIVE
