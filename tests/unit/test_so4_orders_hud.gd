extends GutTest
## The order wheel and Hold here's marker on screen (SO4): the wheel's items from the data (names, keys), the slice
## pointed at lit, the order in force marked, nothing built or drawn while it is closed, the notice in its middle and
## where it may show; the marker over the held spots' middle with its distance, held inside the screen's edge clear of
## the flag marker, gone with the order; the pointer's mapping; the Settings row; and nothing left behind.

const SAVE := "user://so4-test.save"

var hud: Hud = null
var controls := ControlsConfig.new()
var wheel := OrderWheelPointer.new(controls.wheel_reach, controls.wheel_dead_zone, controls.wheel_orders.size())
var outcome := SquadOrders.Outcome.new()
var you: Character = null


func before_each() -> void:
	controls = ControlsConfig.new()
	wheel = OrderWheelPointer.new(controls.wheel_reach, controls.wheel_dead_zone, controls.wheel_orders.size())
	outcome = SquadOrders.Outcome.new()
	you = Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var frame := Control.new()
	frame.size = get_viewport().get_visible_rect().size
	add_child_autofree(frame)
	hud = Hud.new()
	frame.add_child(hud)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
	hud.setup_orders(controls)


func _camera(at: Vector3) -> Camera3D:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = at
	return camera


## Opens the wheel pointing `at` mouse px from the middle and runs a frame.
func _open(at: Vector2, in_force: SquadOrder.Kind = SquadOrder.Kind.NONE, delta: float = 0.0) -> void:
	wheel.start()
	wheel.at = at
	hud.update_orders(wheel, in_force, outcome, delta)


# --- the wheel ---

func test_the_wheel_builds_nothing_while_closed() -> void:
	var w := hud.order_wheel()
	for i in 5:
		hud.update_orders(wheel, SquadOrder.Kind.FOLLOW, outcome, 0.016)
	assert_false(w.visible)
	assert_false(w.built(), "its parts come with the first opening")
	assert_eq(w.get_child_count(), 0)
	assert_eq(w.lit_slice(), -1)


func test_it_draws_the_wheels_items_each_with_its_key() -> void:
	_open(Vector2.ZERO)
	var w := hud.order_wheel()
	assert_true(w.visible)
	assert_eq(w.slice_name(0), "FOLLOW ME")
	assert_eq(w.slice_name(1), "HOLD HERE")
	assert_eq(w.slice_name(2), "GO THERE", "the third, lower right (FM1)")
	assert_eq(w.slice_name(3), "REGROUP")
	assert_eq(w.slice_name(4), "TEAM PLAN")
	assert_eq(w.slice_name(5), "NEED A MAG", "the last, upper left (MH3)")
	assert_eq([w.slice_key(0), w.slice_key(1), w.slice_key(2), w.slice_key(3), w.slice_key(4), w.slice_key(5)],
			["F", "X", "Mouse 4", "V", "", "H"], "Team Plan has no key")
	assert_eq(w.slice_name(6), "", "only the wheel's own items")


func test_a_different_wheel_is_drawn_from_its_data() -> void:
	controls.wheel_orders = [SquadOrder.Kind.REGROUP, SquadOrder.Kind.TEAM_PLAN]
	controls.wheel_keys = [&"order_regroup", &""]
	controls.wheel_labels = PackedStringArray(["ORDER_REGROUP", "ORDER_TEAM_PLAN"])
	var two := OrderWheelPointer.new(controls.wheel_reach, controls.wheel_dead_zone, 2)
	var fresh := Hud.new()
	hud.get_parent().add_child(fresh)
	fresh.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
	fresh.setup_orders(controls)
	two.start()
	two.at = Vector2(0.0, 60.0)
	fresh.update_orders(two, SquadOrder.Kind.NONE, outcome, 0.0)
	var w := fresh.order_wheel()
	assert_eq([w.slice_name(0), w.slice_name(1), w.slice_name(2)], ["REGROUP", "TEAM PLAN", ""])
	assert_eq(w.lit_slice(), 1, "pointed down, the second of two")


func test_it_lights_the_slice_pointed_at_and_marks_the_order_in_force() -> void:
	var w := hud.order_wheel()
	_open(Vector2(60.0, -22.0), SquadOrder.Kind.FOLLOW)
	assert_eq(w.lit_slice(), 1, "up and right of the middle: Hold Here")
	assert_eq(w.banded_slice(), 0, "Follow Me is in force")
	_open(Vector2(0.0, -60.0), SquadOrder.Kind.HOLD)
	assert_eq(w.lit_slice(), 0)
	assert_eq(w.banded_slice(), 1)
	_open(Vector2(5.0, 5.0), SquadOrder.Kind.NONE)
	assert_eq(w.lit_slice(), -1, "in the middle: none")
	assert_eq(w.banded_slice(), -1, "the team plan: no order to mark")


func test_it_closes_with_the_key() -> void:
	_open(Vector2(60.0, 0.0))
	wheel.close()
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.0)
	assert_false(hud.order_wheel().visible)


func test_the_pointer_is_drawn_in_step_with_the_mouses() -> void:
	var dead := 24.0
	var reach := 90.0
	assert_eq(HudOrderWheel.pointer_at(Vector2.ZERO, dead, reach, 112.0, 300.0), Vector2.ZERO)
	var inside := HudOrderWheel.pointer_at(Vector2(12.0, 0.0), dead, reach, 112.0, 300.0)
	assert_almost_eq(inside.x, 56.0, 0.01, "half the dead zone: half the hub")
	var edge := HudOrderWheel.pointer_at(Vector2(0.0, -dead), dead, reach, 112.0, 300.0)
	assert_almost_eq(edge.length(), 112.0, 0.01, "the dead zone's edge is the hub's")
	var far := HudOrderWheel.pointer_at(Vector2(-reach, 0.0), dead, reach, 112.0, 300.0)
	assert_almost_eq(far.x, -300.0, 0.01, "full reach: the far mark, same way")
	assert_almost_eq(HudOrderWheel.pointer_at(Vector2(500.0, 0.0), dead, reach, 112.0, 300.0).x, 300.0, 0.01,
			"never past it")


# --- notices ---

func test_a_notice_shows_in_the_middle_while_the_wheel_is_open_and_times_out() -> void:
	var w := hud.order_wheel()
	_open(Vector2(52.0, -30.0))
	assert_eq(w.notice_text(), "")
	outcome.record(you.id, SquadOrder.Kind.NONE, SquadOrders.Notice.NOBODY)
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)
	assert_eq(w.notice_text(), "No teammates\nin play\nto order")
	assert_eq(w.lit_slice(), -1, "the slices rest under it")
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, HudConfig.new().order_notice_time - 0.5)
	assert_ne(w.notice_text(), "", "still up")
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.6)
	assert_eq(w.notice_text(), "", "gone after its time")
	assert_eq(w.lit_slice(), 1, "the pointer's slice lights again")


func test_every_notice_has_its_words_and_an_order_taken_none() -> void:
	for n: SquadOrders.Notice in [SquadOrders.Notice.CANCELLED, SquadOrders.Notice.ON_PLAN,
			SquadOrders.Notice.NOBODY, SquadOrders.Notice.NOT_NOW]:
		var key := HudOrderWheel.notice_key(n)
		assert_ne(key, "", str(n))
		assert_ne(tr(key), key, "%s is translated" % key)
	assert_eq(HudOrderWheel.notice_key(SquadOrders.Notice.NONE), "", "an order taken: the radio click, no words")


func test_no_notice_outside_the_wheel_or_for_someone_elses_order() -> void:
	var w := hud.order_wheel()
	outcome.record(you.id, SquadOrder.Kind.NONE, SquadOrders.Notice.CANCELLED)
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)
	_open(Vector2(60.0, 0.0))
	assert_eq(w.notice_text(), "", "given with the wheel shut: nothing on screen, then or later")
	outcome.record(7, SquadOrder.Kind.NONE, SquadOrders.Notice.NOBODY)
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)
	assert_eq(w.notice_text(), "", "a bot's order is not yours")
	outcome.record(you.id, SquadOrder.Kind.FOLLOW, SquadOrders.Notice.NONE)
	hud.update_orders(wheel, SquadOrder.Kind.FOLLOW, outcome, 0.016)
	assert_eq(w.notice_text(), "", "an order taken has no line")


func test_a_notice_ends_with_the_wheel() -> void:
	var w := hud.order_wheel()
	_open(Vector2(60.0, 0.0))
	outcome.record(you.id, SquadOrder.Kind.NONE, SquadOrders.Notice.ON_PLAN)
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)
	assert_ne(w.notice_text(), "")
	wheel.close()
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)
	_open(Vector2(60.0, 0.0))
	assert_eq(w.notice_text(), "", "reopened: a clean wheel")


func test_an_order_picked_on_the_wheel_is_told_its_notice_with_the_wheel_up_alone() -> void:
	var w := hud.order_wheel()
	var cfg := HudConfig.new()
	_open(Vector2(60.0, 0.0))
	wheel.close() # the pick shut it
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)
	assert_false(w.visible, "shut without an answer yet: not drawn")
	outcome.record(you.id, SquadOrder.Kind.NONE, SquadOrders.Notice.NOBODY)
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)
	assert_true(w.visible)
	assert_eq(w.notice_text(), "No teammates\nin play\nto order")
	assert_eq(w.lit_slice(), -1, "no slice lit, nothing to point at")
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, cfg.order_notice_time + 0.1)
	assert_false(w.visible, "gone after its time")


func test_the_notice_after_a_pick_shows_in_the_hub_alone_with_no_dark_or_slices() -> void:
	var w := hud.order_wheel()
	_open(Vector2(60.0, 0.0))
	assert_true(w.draws_wheel(), "open: the wheel is drawn")
	wheel.close()
	outcome.record(you.id, SquadOrder.Kind.NONE, SquadOrders.Notice.CANCELLED)
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)
	assert_true(w.visible, "the notice shows")
	assert_false(w.draws_wheel(), "only the hub: no dark behind it and no slices over the crosshair")


func test_a_wheel_shut_on_nothing_waits_for_no_notice() -> void:
	var w := hud.order_wheel()
	_open(Vector2.ZERO)
	wheel.close()
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)
	outcome.record(you.id, SquadOrder.Kind.NONE, SquadOrders.Notice.NOBODY)
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)
	assert_false(w.visible, "shut in the middle: a key pressed just after it brings nothing back")


func test_a_pick_with_no_notice_or_a_late_answer_shows_nothing() -> void:
	var w := hud.order_wheel()
	var cfg := HudConfig.new()
	_open(Vector2(60.0, 0.0))
	wheel.close()
	outcome.record(you.id, SquadOrder.Kind.HOLD, SquadOrders.Notice.NONE)
	hud.update_orders(wheel, SquadOrder.Kind.HOLD, outcome, 0.016)
	assert_false(w.visible, "an order taken: the radio click, nothing on screen")
	hud.update_orders(wheel, SquadOrder.Kind.HOLD, outcome, cfg.order_notice_wait + 0.1)
	outcome.record(you.id, SquadOrder.Kind.NONE, SquadOrders.Notice.CANCELLED)
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)
	assert_false(w.visible, "an answer long after the wheel shut is not shown")


func test_dismissing_puts_the_wheel_away() -> void:
	_open(Vector2(60.0, 0.0))
	hud.close_order_wheel()
	assert_false(hud.order_wheel().visible)


# --- the hold marker ---

func test_the_marker_names_how_far_the_held_spot_is() -> void:
	var camera := _camera(Vector3(0.0, 1.6, 0.0))
	var marker := hud.hold_marker()
	hud.place_hold_marker(camera, Vector3(0.0, 0.0, -18.0), true)
	assert_eq(marker.text(), "HOLD · 18 M")
	assert_eq(marker.pin, HudHoldMarker.Pin.NONE)
	var middle := marker.position.x + marker.size.x * 0.5
	assert_almost_eq(middle, hud.size.x * 0.5, 1.0, "over the spot")
	assert_true(marker.ring_shown(), "and its ring on the floor")
	hud.place_hold_marker(camera, Vector3(0.0, 0.0, -18.0), false)
	assert_eq(marker.text(), "", "none without the order")
	assert_false(marker.ring_shown())


func test_off_screen_it_is_held_inside_the_edge_with_a_chevron_and_no_ring() -> void:
	var camera := _camera(Vector3(0.0, 1.6, 0.0))
	var marker := hud.hold_marker()
	var edge := HudConfig.new().hold_marker_edge
	for spot: Vector3 in [Vector3(60.0, 0.0, -10.0), Vector3(-60.0, 0.0, -10.0), Vector3(0.0, 0.0, 18.0),
			Vector3(5.0, 0.0, 12.0), Vector3(0.0, 90.0, -20.0)]:
		hud.place_hold_marker(camera, spot, true)
		assert_ne(marker.pin, HudHoldMarker.Pin.NONE, str(spot))
		var r := marker.get_rect()
		# held at a side it lines up with the flag marker's stack, a little nearer the edge
		var side := minf(edge, hud.pin_point().x)
		assert_gte(r.position.x, side - 0.5, "inside the left edge %s" % spot)
		assert_lte(r.end.x, hud.size.x - side + 0.5, "inside the right edge %s" % spot)
		assert_gte(r.position.y, edge - 0.5, "inside the top edge %s" % spot)
		assert_lte(r.end.y, hud.size.y - edge + 0.5, "inside the bottom edge %s" % spot)
		assert_false(marker.ring_shown())
	hud.place_hold_marker(camera, Vector3(60.0, 0.0, -10.0), true)
	assert_eq(marker.pin, HudHoldMarker.Pin.RIGHT)
	hud.place_hold_marker(camera, Vector3(-60.0, 0.0, -10.0), true)
	assert_eq(marker.pin, HudHoldMarker.Pin.LEFT)


func test_held_at_the_edge_it_stays_clear_of_the_flag_marker() -> void:
	var camera := _camera(Vector3(0.0, 1.6, 0.0))
	var marker := hud.hold_marker()
	# Placed alone, with no stack to take a place in (Hud's stacks are tested in test_mm4_qa).
	marker.place(camera, Vector3(60.0, 0.0, -10.0), true, hud.size, Rect2())
	var spot_y := marker.position.y
	# The flag marker's plate where the hold marker would sit.
	var flag := Rect2(marker.position - Vector2(30.0, 0.0), Vector2(220.0, 41.0))
	var gap := HudConfig.new().hold_marker_gap
	marker.place(camera, Vector3(60.0, 0.0, -10.0), true, hud.size, flag)
	assert_gte(marker.position.y, flag.end.y + gap - 0.5, "below it, a step apart")
	assert_false(marker.get_rect().intersects(flag))
	# No room below: above it.
	var low := Rect2(marker.position - Vector2(30.0, 0.0), Vector2(220.0, 41.0))
	low.position.y = hud.size.y - HudConfig.new().hold_marker_edge - 41.0
	marker.place(camera, Vector3(60.0, 0.0, -10.0), true, hud.size, low)
	assert_lte(marker.get_rect().end.y, low.position.y - gap + 0.5, "above it when the bottom is full")
	# Not in the way: where it was.
	marker.place(camera, Vector3(60.0, 0.0, -10.0), true, hud.size, Rect2(0.0, 0.0, 50.0, 40.0))
	assert_almost_eq(marker.position.y, spot_y, 0.5)


func test_marker_and_wheel_take_the_panel_opacity() -> void:
	var prefs := HudPrefs.new()
	prefs.panel_opacity = 0.5
	hud.apply_prefs(prefs)
	assert_almost_eq(hud.order_wheel().get_meta(HudStyle.OPACITY) as float, 0.5, 0.001)
	assert_almost_eq(hud.hold_marker().get_meta(HudStyle.OPACITY) as float, 0.5, 0.001)
	var plate := hud.hold_marker().get_child(0) as PanelContainer
	var box := plate.get_theme_stylebox("panel") as StyleBoxFlat
	assert_almost_eq(box.bg_color.a, HudStyle.BACKING_CLOCK * 0.5, 0.001)


# --- no waste ---

func test_a_frame_with_neither_shown_allocates_nothing() -> void:
	var camera := _camera(Vector3(0.0, 1.6, 0.0))
	hud.update_orders(wheel, SquadOrder.Kind.FOLLOW, outcome, 0.016)
	hud.place_hold_marker(camera, Vector3.ZERO, false)
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 100:
		hud.update_orders(wheel, SquadOrder.Kind.FOLLOW, outcome, 0.016)
		hud.place_hold_marker(camera, Vector3(0.0, 0.0, -18.0), false)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), objects)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes)


func test_wheel_and_marker_go_with_the_hud() -> void:
	_open(Vector2(60.0, 0.0))
	var wheel_node := hud.order_wheel()
	var marker := hud.hold_marker()
	hud.free()
	assert_false(is_instance_valid(wheel_node))
	assert_false(is_instance_valid(marker))


# --- in a match ---

func test_the_marker_follows_the_hold_in_a_match() -> void:
	var session := PlaySession.new()
	session.mode = MatchOptions.MODE_ELIMINATION
	session.bots_active = false
	# Open to the sky, so looking straight up meets nothing (Depot's hall has a ceiling to look at).
	session.map_id = "woodland"
	add_child_autofree(session)
	await wait_physics_frames(3)
	var player := session.player
	var marker := session.hud().hold_marker()
	await wait_process_frames(2)
	assert_eq(marker.text(), "", "no order, no marker")
	var held := false
	var yaw := 0.0
	while yaw < TAU and not held:
		player.yaw = yaw
		player.pitch = 0.0
		session._bots.orders.clear()
		session._bots.give_order(player, SquadOrder.Kind.HOLD)
		held = session._bots.hold_spot(player.id)
		yaw += 0.4
	assert_true(held, "somewhere on the map a hold has a spot to look at")
	await wait_process_frames(2)
	assert_ne(marker.text(), "", "over the held spot")
	session._bots.orders.clear()
	await wait_process_frames(2)
	assert_eq(marker.text(), "", "none once the order ends")
	# A hold where each stood: looking at nothing near.
	player.pitch = 1.4
	session._bots.give_order(player, SquadOrder.Kind.HOLD)
	await wait_process_frames(2)
	assert_eq(marker.text(), "", "none for a hold where each stood")


# --- Settings ---

func test_settings_has_the_order_wheel_row() -> void:
	var s := Settings.new(PlayTuning.new())
	var screen := SettingsScreen.new()
	screen.settings = s
	screen.save_path = SAVE
	add_child_autofree(screen)
	screen.open()
	# Hover | Click, a choice since UI1
	var row := screen._wheel_pick
	assert_not_null(row)
	assert_eq(row.selected(), 0, "Hover by default")
	assert_eq([row.button(0).text, row.button(1).text], ["HOVER", "CLICK"])
	row.button(1).pressed.emit()
	assert_eq(s.wheel_pick, ControlsConfig.WheelPick.CLICK)
	assert_eq(row.selected(), 1)
	row.button(0).pressed.emit()
	assert_eq(s.wheel_pick, ControlsConfig.WheelPick.HOVER)
	s.wheel_pick = ControlsConfig.WheelPick.CLICK
	screen._refresh()
	assert_eq(row.selected(), 1, "shows what is saved")
	DirAccess.remove_absolute(SAVE)
