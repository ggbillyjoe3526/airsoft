extends GutTest
## GR5 QA: the step-down in a real (non-autopilot) session, where each gate of `counts` is the session's own, and the
## Settings › Graphics page after the step.

const SLOW := 0.030
const SECONDS := 2.0

var _preset_before: StringName = &""
var _method_before: String = ""
var session: PlaySession = null
var s: Settings = null


func before_each() -> void:
	_preset_before = GraphicsApply.machine().preset
	_method_before = GraphicsApply.machine().rendering_method
	s = Settings.new(PlayTuning.new())
	GraphicsApply.pick_for_run(&"high")


func after_each() -> void:
	get_tree().paused = false
	GraphicsApply.pick_for_run(_preset_before)
	GraphicsApply.machine().rendering_method = _method_before


func _play(warm: bool = true) -> void:
	session = PlaySession.new()
	session.settings = s
	add_child_autofree(session)
	await wait_physics_frames(2)
	session.set("_warm", warm)
	RoundHold.release(session.state)


## Two slow windows of live-round frames, as the session's own `_process` hands them over.
func _frames(count: int = 0) -> void:
	for i in (count if count > 0 else ceili(SECONDS * 2.0 / SLOW) + 4):
		session.call("_watch_frame", SLOW)


func test_a_live_warm_focused_round_on_the_automatic_pick_asks_for_a_step() -> void:
	await _play()
	assert_true(session.state.round_state.is_live(), "the control: the round is live")
	_frames()
	assert_true(session.frame_watch().due(), "the control the other cases are measured against")


func test_frames_before_the_shaders_are_warm_say_nothing() -> void:
	await _play(false)
	_frames()
	assert_false(session.frame_watch().due())


func test_an_unfocused_window_never_asks() -> void:
	await _play()
	session.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	get_tree().paused = false
	_frames()
	assert_false(session.frame_watch().due())
	session.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)


func test_a_paused_game_never_asks() -> void:
	await _play()
	get_tree().paused = true
	_frames()
	assert_false(session.frame_watch().due())


func test_the_simpler_renderer_never_asks() -> void:
	GraphicsApply.machine().rendering_method = GraphicsPick.COMPATIBILITY
	await _play()
	_frames()
	assert_false(session.frame_watch().due())


func test_low_never_asks_in_a_session() -> void:
	GraphicsApply.pick_for_run(&"low")
	await _play()
	_frames()
	assert_false(session.frame_watch().due())


func test_practice_never_asks() -> void:
	session = PlaySession.new()
	session.settings = s
	session.practice = true
	add_child_autofree(session)
	await wait_physics_frames(2)
	session.set("_warm", true)
	_frames()
	assert_false(session.frame_watch().due())


func test_the_step_does_not_apply_before_the_rounds_end_and_not_twice() -> void:
	await _play()
	_frames()
	assert_true(session.frame_watch().due())
	assert_eq(GraphicsApply.machine().preset, &"high", "not mid-round")
	assert_true(DevCheats.end_round(session.state))
	await wait_physics_frames(3)
	assert_eq(GraphicsApply.machine().preset, &"medium")
	# the next round, slow again: asked once a match
	session.set("_warm", true)
	_frames(ceili(SECONDS * 8.0 / SLOW))
	assert_false(session.frame_watch().due(), "once a match")


func test_the_settings_page_tags_the_step_down_preset_for_your_card() -> void:
	var screen := SettingsScreen.new()
	screen.settings = s
	var page := SettingsGraphicsPage.new()
	var p := GraphicsApply.machine()
	page.probe = p
	add_child_autofree(screen)
	page.build(screen)
	add_child_autofree(page)
	page.refresh()
	assert_eq(page.tagged(), page.preset_choice().button(GraphicsTable.PRESETS.find(&"high")), "the control")
	GraphicsApply.pick_for_run(&"medium")
	page.refresh()
	assert_eq(page.tagged(), page.preset_choice().button(GraphicsTable.PRESETS.find(&"medium")),
			"For your card moves with the pick it names")
