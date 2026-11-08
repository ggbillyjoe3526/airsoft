extends GutTest
## What a play session leaves behind and how it reacts to focus and pause (game/play/play_session.gd): losing focus
## pauses and lets go of the keys, a rematch follows a finished match, and sessions made and freed in turn leave no
## nodes behind.

var session: PlaySession = null


func before_each() -> void:
	session = PlaySession.new()
	add_child_autofree(session)
	await wait_physics_frames(2)
	RoundHold.release(session.state)  # these tests play a live round, not the start countdown


func after_each() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_losing_focus_pauses_frees_the_mouse_and_drops_held_presses() -> void:
	session._capture()
	var tap := InputEventAction.new()
	tap.action = &"fire"
	tap.pressed = true
	session._input._unhandled_input(tap)
	session.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(get_tree().paused)
	assert_false(session._input.active)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	var cmd := PlayerCommand.new()
	session._input.fill(cmd)
	assert_false(cmd.fire, "a press latched before focus left does not fire on return")


func test_losing_focus_twice_or_while_paused_changes_nothing() -> void:
	session._capture()
	session.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	session.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	session.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_true(get_tree().paused, "coming back stays paused until the player resumes")
	assert_true(session._pause.visible)


func test_a_click_on_the_title_after_leaving_does_not_leave_the_tree_paused() -> void:
	session._open_pause()
	session._leave()
	assert_false(get_tree().paused)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)


func test_a_finished_match_rematches_after_the_delay() -> void:
	session.autopilot = false
	for c in session.state.characters:
		if c.team == session.opponent_team():
			c.status = Character.Status.OUT
	var rounds := session.state.round_state
	await wait_physics_frames(3)
	session._rematch_left = 0.0
	await wait_physics_frames(2)
	for c in session.state.characters:
		assert_eq(c.status, Character.Status.ALIVE, "everyone is back on their feet")
	assert_true(rounds.under_way() or session.state.round_state.under_way(), "a new match is under way (its first round is held for the countdown)")


func test_making_and_freeing_sessions_in_turn_leaves_the_node_count_where_it_was() -> void:
	session.get_parent().remove_child(session)
	session.free()
	await wait_process_frames(2)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 3:
		var s := PlaySession.new()
		s.autopilot = true
		add_child(s)
		await wait_physics_frames(5)
		s._open_pause()
		s._resume()
		s._leave()
		remove_child(s)
		s.free()
		await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes)
	assert_false(get_tree().paused)
	session = PlaySession.new()
	add_child_autofree(session)
