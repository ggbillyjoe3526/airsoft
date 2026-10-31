extends GutTest
## QA for SO4 (the order wheel and hold marker on screen): the paths a player takes, through PlaySession and the real
## PlayerInput, that the HUD tests feed by hand; and the marker's edge cases.

const ACTIONS: Array[StringName] = [&"order_wheel", &"order_follow", &"order_hold", &"fire", &"aim"]


func after_each() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)


func _session(mode: String = MatchOptions.MODE_ELIMINATION) -> PlaySession:
	var session := PlaySession.new()
	session.mode = mode
	session.bots_active = false
	add_child_autofree(session)
	return session


## Puts your teammates out, so an order has nobody to take it.
func _no_teammates(session: PlaySession) -> void:
	for c in session.state.characters:
		if c != session.player and c.team == session.player.team:
			c.status = Character.Status.OUT


func _event(session: PlaySession, action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	session._input._unhandled_input(e)


func _move(session: PlaySession, dx: float, dy: float) -> void:
	var e := InputEventMouseMotion.new()
	e.screen_relative = Vector2(dx, dy)
	session._input._unhandled_input(e)


func _started(session: PlaySession) -> void:
	await wait_physics_frames(3)
	session._input.active = true


# --- notices for what the player does ---

func test_a_notice_shows_for_a_key_pressed_with_the_wheel_open_and_for_an_order_picked_on_it() -> void:
	var session := _session()
	await _started(session)
	_no_teammates(session)
	var w := session.hud().order_wheel()
	_event(session, &"order_wheel", true)
	await wait_process_frames(2)
	_event(session, &"order_follow", true)
	_event(session, &"order_follow", false)
	await wait_physics_frames(3)
	await wait_process_frames(2)
	assert_eq(session._bots.order_outcome.notice, SquadOrders.Notice.NOBODY)
	assert_eq(w.notice_text(), "No teammates\nin play\nto order", "the key was pressed with the wheel open")
	_event(session, &"order_wheel", false)
	await wait_process_frames(2)
	assert_false(w.visible)
	# The same, picked on the wheel: point at Hold Here and let go (Hover).
	_event(session, &"order_wheel", true)
	_move(session, 87.0, -50.0)
	await wait_process_frames(2)
	assert_eq(w.lit_slice(), 1, "pointed at Hold Here")
	var before := session._bots.order_outcome.serial
	_event(session, &"order_wheel", false)
	await wait_physics_frames(3)
	await wait_process_frames(2)
	assert_gt(session._bots.order_outcome.serial, before, "the order was refused for want of a team")
	assert_ne(w.notice_text(), "", "the player who picked it on the wheel is told: the wheel stays up for the notice")


func _hold(session: PlaySession) -> bool:
	var yaw := 0.0
	while yaw < TAU:
		session.player.yaw = yaw
		session.player.pitch = 0.0
		session._bots.orders.clear()
		session._bots.give_order(session.player, SquadOrder.Kind.HOLD)
		if session._bots.hold_spot(session.player.id):
			return true
		yaw += 0.4
	return false


func test_hold_heres_marker_goes_when_the_match_ends() -> void:
	var session := _session()
	await _started(session)
	assert_true(_hold(session), "a spot to hold")
	session._show_orders(session.player, 0.0)
	assert_true(session.hud().hold_marker().visible, "held: the marker shows")
	session.state.round_state.phase = RoundState.Phase.MATCH_OVER
	session.state.events.clear()
	session.state.events.add(GameEvent.Kind.ROUND_OVER)
	session.state.events.add(GameEvent.Kind.MATCH_OVER)
	session._after_tick()
	session.state.events.clear()
	assert_false(session._bots.hold_spot(session.player.id), "no orders after the last round")
	session._show_orders(session.player, 0.0)
	assert_false(session.hud().hold_marker().visible, "not over the match results")


# --- the hold marker beside the real flag marker ---

func _hud_with_orders() -> Hud:
	var frame := Control.new()
	frame.size = get_viewport().get_visible_rect().size
	add_child_autofree(frame)
	var hud := Hud.new()
	frame.add_child(hud)
	var you := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
	hud.setup_orders(ControlsConfig.new())
	return hud


func _camera(at: Vector3) -> Camera3D:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = at
	return camera


func _marks_apart(hud: Hud, camera: Camera3D, pole: Vector3, spot: Vector3, why: String) -> void:
	var flag := hud.get_node_or_null("HudFlagMarker") as Control
	for i in 3:
		hud.place_flag_marker(camera, pole, true)
		hud.place_hold_marker(camera, spot, true)
		await wait_process_frames(1)
	var marker := hud.hold_marker()
	assert_true(marker.visible, why)
	var flags: Array[Node] = hud.find_children("*", "HudFlagMarker", true, false)
	assert_eq(flags.size(), 1)
	var f := flags[0] as Control
	assert_true(f.visible, why)
	assert_false(f.get_rect().intersects(marker.get_rect()), "%s: flag %s hold %s" % [why, f.get_rect(), marker.get_rect()])
	var r := marker.get_rect()
	assert_gte(r.position.y, 0.0, why)
	assert_lte(r.end.y, hud.size.y, why)
	assert_gte(r.position.x, 0.0, why)
	assert_lte(r.end.x, hud.size.x, why)


func test_hold_and_flag_markers_do_not_overlap_pinned_on_the_same_side() -> void:
	var hud := _hud_with_orders()
	var camera := _camera(Vector3(0.0, 1.6, 0.0))
	await _marks_apart(hud, camera, Vector3(80.0, 0.0, -10.0), Vector3(60.0, 0.0, -10.0), "both right")
	await _marks_apart(hud, camera, Vector3(-80.0, 0.0, -10.0), Vector3(-60.0, 0.0, -10.0), "both left")


func test_hold_and_flag_markers_do_not_overlap_when_both_are_behind_you() -> void:
	var hud := _hud_with_orders()
	var camera := _camera(Vector3(0.0, 1.6, 0.0))
	await _marks_apart(hud, camera, Vector3(8.0, 0.0, 30.0), Vector3(6.0, 0.0, 20.0), "both behind, right")
	await _marks_apart(hud, camera, Vector3(-8.0, 0.0, 30.0), Vector3(-6.0, 0.0, 20.0), "both behind, left")
	await _marks_apart(hud, camera, Vector3(0.0, 0.0, 30.0), Vector3(0.0, 0.0, 20.0), "both dead behind")


# --- state a match leaves behind ---

func test_the_wheel_in_a_session_follows_a_rebound_key_the_pause_menu_and_being_hit() -> void:
	var session := _session()
	await _started(session)
	var w := session.hud().order_wheel()
	var marker := session.hud().hold_marker()
	# A key rebound after the wheel was built shows at its next opening.
	var original := InputMap.action_get_events(&"order_follow")
	_event(session, &"order_wheel", true)
	await wait_process_frames(2)
	assert_eq(w.slice_key(0), "F")
	_event(session, &"order_wheel", false)
	await wait_process_frames(2)
	InputMap.action_erase_events(&"order_follow")
	var g := InputEventKey.new()
	g.physical_keycode = KEY_G
	InputMap.action_add_event(&"order_follow", g)
	_event(session, &"order_wheel", true)
	await wait_process_frames(2)
	var shown := w.slice_key(0)
	InputMap.action_erase_events(&"order_follow")
	for e in original:
		InputMap.action_add_event(&"order_follow", e)
	assert_eq(shown, "G", "the key the player bound, not the one it was built with")
	# The pause menu opening with the wheel up: it is not left drawn under the menu.
	session._input.release()
	session.get_tree().paused = true
	await wait_process_frames(2)
	var left_up := w.visible
	session.get_tree().paused = false
	assert_false(left_up, "the wheel closed with the input and should not stay drawn under the pause menu")
	# Hit with the wheel open and a hold in force: both go.
	assert_true(_hold(session))
	session._input.active = true
	_event(session, &"order_wheel", true)
	await wait_process_frames(2)
	assert_true(w.visible)
	assert_ne(marker.text(), "")
	Elimination.eliminate(session.player, 1, session.state.characters, session._sim.ends)
	await wait_physics_frames(3)
	await wait_process_frames(2)
	assert_false(w.visible, "being out shuts the wheel")
	assert_eq(marker.text(), "", "and ends the order, so the marker")


func test_the_range_shows_no_wheel_and_no_marker() -> void:
	var session := PlaySession.new()
	session.practice = true
	session.mode = "practice"
	add_child_autofree(session)
	await _started(session)
	var w := session.hud().order_wheel()
	_event(session, &"order_wheel", true)
	_move(session, 100.0, 0.0)
	_event(session, &"order_hold", true)
	_event(session, &"order_hold", false)
	await wait_physics_frames(3)
	await wait_process_frames(2)
	assert_false(w.visible)
	assert_false(w.built(), "nothing built on the range")
	assert_eq(session.hud().hold_marker().text(), "")
	assert_false(session.hud().hold_marker().visible)


# --- the notice-only wheel ---

func _shut_pick(hud: Hud, wheel: OrderWheelPointer, outcome: SquadOrders.Outcome) -> void:
	wheel.start()
	wheel.at = Vector2(60.0, 0.0)
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)
	wheel.close()
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)


func test_the_notice_only_wheel_is_for_your_own_pick_and_reopens_clean() -> void:
	var hud := _hud_with_orders()
	var controls := ControlsConfig.new()
	var wheel := OrderWheelPointer.new(controls.wheel_reach, controls.wheel_dead_zone, controls.wheel_orders.size())
	var outcome := SquadOrders.Outcome.new()
	var w := hud.order_wheel()
	_shut_pick(hud, wheel, outcome)
	outcome.record(7, SquadOrder.Kind.NONE, SquadOrders.Notice.NOBODY)
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)
	assert_false(w.visible, "a bot's outcome is not yours, even right after a pick")
	outcome.record(0, SquadOrder.Kind.NONE, SquadOrders.Notice.NOT_NOW)
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)
	assert_eq(w.notice_text(), "Orders wait for\nthe next round")
	assert_eq(w.banded_slice(), -1, "no order marked while it only tells you")
	# Opened again while it tells you: a clean wheel, the pointer back, no notice left over.
	wheel.start()
	wheel.at = Vector2(0.0, -60.0)
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)
	assert_eq(w.notice_text(), "")
	assert_eq(w.lit_slice(), 0, "the slice pointed at lights again")
	wheel.close()
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)
	assert_false(w.visible, "shut with no answer owed: away at once")


func test_the_notice_only_wheel_goes_when_the_pause_menu_opens() -> void:
	var hud := _hud_with_orders()
	var controls := ControlsConfig.new()
	var wheel := OrderWheelPointer.new(controls.wheel_reach, controls.wheel_dead_zone, controls.wheel_orders.size())
	var outcome := SquadOrders.Outcome.new()
	var w := hud.order_wheel()
	_shut_pick(hud, wheel, outcome)
	outcome.record(0, SquadOrder.Kind.NONE, SquadOrders.Notice.NOBODY)
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)
	assert_true(w.visible)
	get_tree().paused = true
	await wait_process_frames(2)
	var left_up := w.visible
	get_tree().paused = false
	assert_false(left_up, "paused: the notice is put away, not left under the menu")


# --- Settings ---

const SAVE := "user://so4-qa.save"


func _screen(s: Settings) -> SettingsScreen:
	var screen := SettingsScreen.new()
	screen.settings = s
	screen.save_path = SAVE
	add_child_autofree(screen)
	return screen


func test_an_old_or_wild_settings_file_shows_hover() -> void:
	var s := Settings.new(PlayTuning.new())
	s.from_dict({"sensitivity": 1.0})
	var screen := _screen(s)
	screen.open()
	assert_eq(screen._wheel_pick.selected(), 0, "no saved choice: Hover")
	assert_eq(screen._wheel_pick.button(0).text, "HOVER")
	s.from_dict({"wheel_pick": 99})
	screen._refresh()
	assert_eq(screen._wheel_pick.selected(), 0, "out of range: Hover")
	s.from_dict({"wheel_pick": "click"})
	screen._refresh()
	assert_eq(screen._wheel_pick.selected(), 0, "not a number: Hover")


func test_the_order_wheel_row_is_saved_and_reaches_the_game() -> void:
	var s := Settings.new(PlayTuning.new())
	var screen := _screen(s)
	screen._wheel_pick.button(1).pressed.emit()
	assert_eq(s.tuning.controls.wheel_pick, ControlsConfig.WheelPick.CLICK, "the live controls follow at once")
	assert_eq(s.to_dict()["wheel_pick"], int(ControlsConfig.WheelPick.CLICK), "and it is in what is saved")
	var back := Settings.new(PlayTuning.new())
	back.from_dict(s.to_dict())
	assert_eq(back.wheel_pick, ControlsConfig.WheelPick.CLICK)
	DirAccess.remove_absolute(SAVE)


func test_the_squad_rows_read_follow_hold_regroup_wheel() -> void:
	var i := KeyBindings.ACTIONS.find(&"order_follow")
	assert_eq(KeyBindings.ACTIONS.slice(i, i + 4), [&"order_follow", &"order_hold", &"order_regroup", &"order_wheel"])
