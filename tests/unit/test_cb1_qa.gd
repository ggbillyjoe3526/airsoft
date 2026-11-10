extends GutTest
## CB1 QA: the countdown's beeps through a whole staged match start, never doubled, never lost to the loading screen.


## How many times a countdown beep began over the frames until `done` says stop (a beep voice going from silent to playing).
func _beeps_until(session: PlaySession, done: Callable, limit: int = 900) -> int:
	var was := false
	var n := 0
	for i in limit:
		await wait_physics_frames(1)
		if not session._running and not session._holding:
			continue
		var takes := session._audio._streams[&"count_beep"] as Array
		var on := false
		for v in session._audio._own:
			if v.playing and v.stream != null and takes.has(v.stream):
				on = true
		if on and not was:
			n += 1
		was = on
		if done.call():
			break
	return n


func _staged(wait: bool) -> PlaySession:
	var session := PlaySession.new()
	session.bots_active = false
	session.staged = true
	session.wait_for_go = wait
	add_child_autofree(session)
	return session


func test_a_staged_match_beeps_three_times_not_four() -> void:
	var session := _staged(false)
	var n := await _beeps_until(session, func() -> bool:
		return session._running and session.state.round_state.phase == RoundState.Phase.LIVE \
				and not session.state.round_state.held())
	assert_false(session.state.round_state.held(), "the countdown ran out")
	assert_eq(n, 3, "3, 2 and 1 once each")


func test_a_match_held_for_continue_beeps_nothing_until_go_then_three_in_all() -> void:
	var session := _staged(true)
	var n0 := await _beeps_until(session, func() -> bool: return session._holding and session._running, 600)
	assert_eq(n0, 0, "silent under the loading screen")
	session.go()
	var n := await _beeps_until(session, func() -> bool:
		return not session.state.round_state.held())
	assert_eq(n, 3, "3 at Continue, then 2 and 1")
