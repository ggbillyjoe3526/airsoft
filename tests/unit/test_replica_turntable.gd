extends GutTest
## Customise's turntable (UR4; UI concept B v2 `customise.png`, owner 2026-11-02: "the replica stays the same size and
## place whatever parts go on", "an option to rotate the 3D model"): one frame on every tab, the views, dragging,
## zooming, R, and nothing kept once Customise is left.

const LOADOUTS := "user://test_ur4_loadouts.save"
const SETTINGS := "user://test_ur4_settings.save"

var saved: SavedLoadouts
var settings: Settings


func before_each() -> void:
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)
	saved = SavedLoadouts.new(LoadoutRules.standard())
	settings = Settings.new()


func after_each() -> void:
	await wait_process_frames(2)
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)


func _page(slot: int = 0) -> LoadoutPage:
	var page := LoadoutPage.new(saved, settings)
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	add_child_autofree(page)
	page.show_customise(slot)
	return page


func _drag(table: ReplicaTurntable, by: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	table._gui_input(press)
	var move := InputEventMouseMotion.new()
	move.relative = by
	table._gui_input(move)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	table._gui_input(release)


func _wheel(table: ReplicaTurntable, up: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	e.pressed = true
	table._gui_input(e)


func test_the_replica_on_show_is_the_carried_one_in_its_paint() -> void:
	var page := _page(0)
	var table := page.customise().turntable()
	assert_not_null(table.model())
	assert_true(table.texture is ViewportTexture, "the turntable's own viewport, live")
	assert_eq(table.view(), ReplicaTurntable.View.THREE_QUARTER, "it opens on the 3/4 view")
	assert_eq(page.customise().view_choice().selected(), ReplicaTurntable.View.THREE_QUARTER)
	page.show_gear()
	page.show_customise(1)
	assert_not_null(table.model(), "the pistol")
	assert_ne(table.model().scene_file_path, "", "loaded from its model file")
	var cams := table.find_children("*", "Camera3D", true, false)
	assert_gt(cams.size(), 0, "a camera to check")
	for cam: Node in cams:
		assert_false((cam as Camera3D).is_physics_interpolated(), "turned by hand, never interpolated (BP6)")


func test_the_frame_is_one_height_on_every_tab() -> void:
	var page := _page(0)
	var view := page.customise()
	await wait_process_frames(2)
	var stage := view.find_child("Stage", true, false) as Control
	var rect := stage.get_global_rect()
	var distance := view.turntable().camera_distance()
	for t: CustomiseView.Tab in [CustomiseView.Tab.BBS, CustomiseView.Tab.POWER, CustomiseView.Tab.OPTIC,
			CustomiseView.Tab.COLOUR]:
		view.show_tab(t)
		await wait_process_frames(2)
		assert_eq(stage.get_global_rect(), rect, "the same box on %s" % CustomiseView.Tab.keys()[t])
		assert_almost_eq(view.turntable().camera_distance(), distance, 0.0001)


func test_the_view_buttons_turn_it_and_follow_a_drag() -> void:
	var page := _page(0)
	var table := page.customise().turntable()
	var views := page.customise().view_choice()
	views.button(ReplicaTurntable.View.TOP).pressed.emit()
	assert_eq(table.view(), ReplicaTurntable.View.TOP)
	assert_eq(table.pitch(), -90.0, "looking down on it")
	views.button(ReplicaTurntable.View.LEFT).pressed.emit()
	assert_eq(table.view(), ReplicaTurntable.View.LEFT)
	assert_eq(views.selected(), ReplicaTurntable.View.LEFT, "the button lit")
	assert_eq(absf(table.yaw()), 180.0, "its other side")
	_drag(table, Vector2(50.0, 0.0))
	assert_eq(table.view(), -1, "turned by hand: no view lit")
	assert_eq(views.selected(), -1)


func test_a_drag_turns_and_tilts_within_limits() -> void:
	var page := _page(0)
	var table := page.customise().turntable()
	table.set_view(ReplicaTurntable.View.RIGHT)
	_drag(table, Vector2(100.0, 0.0))
	assert_almost_eq(table.yaw(), 100.0 * ReplicaTurntable.DRAG, 0.001)
	assert_eq(table.pitch(), 0.0)
	_drag(table, Vector2(0.0, 10000.0))
	assert_eq(table.pitch(), ReplicaTurntable.PITCH_MIN, "never past looking straight down")
	_drag(table, Vector2(0.0, -10000.0))
	assert_eq(table.pitch(), ReplicaTurntable.PITCH_MAX)
	_drag(table, Vector2(2000.0, 0.0))
	assert_between(table.yaw(), -180.0, 180.0, "the turn wraps")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80.0, 0.0)
	var yaw := table.yaw()
	table._gui_input(motion)
	assert_eq(table.yaw(), yaw, "moving without a button held turns nothing")


func test_the_wheel_zooms_within_limits_and_a_view_resets_it() -> void:
	var page := _page(0)
	var table := page.customise().turntable()
	var far := table.camera_distance()
	_wheel(table, true)
	assert_gt(table.zoom(), 1.0)
	assert_lt(table.camera_distance(), far, "nearer")
	for i in 40:
		_wheel(table, true)
	assert_eq(table.zoom(), ReplicaTurntable.ZOOM_MAX)
	for i in 80:
		_wheel(table, false)
	assert_eq(table.zoom(), ReplicaTurntable.ZOOM_MIN)
	table.set_view(ReplicaTurntable.View.TOP)
	assert_eq(table.zoom(), 1.0)
	assert_almost_eq(table.camera_distance(), far, 0.0001)


func test_r_puts_the_view_back_only_while_customise_shows() -> void:
	var page := _page(0)
	var table := page.customise().turntable()
	_drag(table, Vector2(60.0, 30.0))
	_wheel(table, true)
	var r := InputEventKey.new()
	r.physical_keycode = KEY_R
	r.pressed = true
	table._unhandled_key_input(r)
	assert_eq(table.view(), ReplicaTurntable.View.THREE_QUARTER)
	assert_eq(table.zoom(), 1.0)
	assert_eq(Vector2(table.yaw(), table.pitch()), ReplicaTurntable.VIEW_ANGLES[ReplicaTurntable.View.THREE_QUARTER])
	_drag(table, Vector2(60.0, 0.0))
	page.show_gear()
	table._unhandled_key_input(r)
	assert_eq(table.view(), -1, "R on the gear page is not the turntable's")


func test_leaving_customise_lets_go_of_the_model_and_leaves_no_orphans() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var page := LoadoutPage.new(saved, settings)
	page.save_path = LOADOUTS
	add_child(page)
	page.show_customise(0)
	var table := page.customise().turntable()
	assert_not_null(table.model())
	page.show_gear()
	assert_null(table.model(), "no model held while Customise is closed")
	page.show_customise(0)
	assert_not_null(table.model(), "back when it opens")
	remove_child(page)
	page.free()
	await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)


func test_a_replica_with_no_model_shows_nothing_and_does_not_fail() -> void:
	var table := ReplicaTurntable.new()
	add_child_autofree(table)
	table.show_replica(&"no_such_replica", &"", false)
	assert_null(table.model())
	table.set_view(ReplicaTurntable.View.TOP)
	_drag(table, Vector2(10.0, 10.0))
	assert_eq(table.view(), -1)


func test_the_ring_hides_looking_down_and_the_render_target_goes_with_the_model() -> void:
	var page := _page(0)
	var table := page.customise().turntable()
	var ring := table.find_child("Ring", true, false) as MeshInstance3D
	assert_true(ring.visible, "the 3/4 view shows the turntable's ring")
	table.set_view(ReplicaTurntable.View.TOP)
	assert_false(ring.visible, "from above it would run out of the frame")
	table.set_view(ReplicaTurntable.View.RIGHT)
	assert_true(ring.visible)
	var port := table.find_child("Port", true, false) as SubViewport
	page.show_gear()
	assert_lte(port.size.x, 2, "no render target held while Customise is closed (Godot's least is 2 px)")
	page.show_customise(0)
	await wait_process_frames(2)
	assert_gt(port.size.x, 1, "back at the rect's size")


func test_letting_go_of_one_button_while_the_other_is_held_keeps_turning() -> void:
	var page := _page(0)
	var table := page.customise().turntable()
	table.set_view(ReplicaTurntable.View.RIGHT)
	for b: MouseButton in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var press := InputEventMouseButton.new()
		press.button_index = b
		press.pressed = true
		table._gui_input(press)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	table._gui_input(up)
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(10.0, 0.0)
	table._gui_input(move)
	assert_almost_eq(table.yaw(), 10.0 * ReplicaTurntable.DRAG, 0.001, "the right button still turns it")
