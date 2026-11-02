extends GutTest
## QA for UR4 (Customise's replica on a turntable): everything fitted stays in the frame in every view, the page fits
## its screen on every tab, and the turntable keeps nothing once Customise is left.

const LOADOUTS := "user://test_ur4qa_loadouts.save"
const SETTINGS := "user://test_ur4qa_settings.save"
const SCREEN := Vector2(1920.0, 1080.0)
## The turntable's rect on the 1920 x 1080 page (about).
const RECT := Vector2(950.0, 320.0)

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


func _table() -> ReplicaTurntable:
	var holder := Control.new()
	holder.size = RECT
	add_child_autofree(holder)
	var table := ReplicaTurntable.new()
	holder.add_child(table)
	table.position = Vector2.ZERO
	table.size = RECT
	return table


## The worst overshoot of the model's visible vertices outside the camera's view (0 or less: inside), as a fraction of
## the view, and the axis it is on.
func _overshoot(table: ReplicaTurntable) -> Vector2:
	var model := table.model()
	var camera: Camera3D = null
	for c in table.get_node("Port").get_children():
		if c is Camera3D:
			camera = c
	var tan_half := tan(deg_to_rad(ReplicaTurntable.FOV) * 0.5)
	var aspect := RECT.y / RECT.x
	var worst := Vector2(-10.0, -10.0)
	var to_cam := camera.global_transform.affine_inverse()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var xf := to_cam * mi.global_transform
		for v in mi.mesh.get_faces():
			var p := xf * v
			var depth := -p.z
			if depth <= 0.0:
				return Vector2(10.0, 10.0)
			worst.x = maxf(worst.x, absf(p.x) / depth / tan_half - 1.0)
			worst.y = maxf(worst.y, absf(p.y) / depth / (tan_half * aspect) - 1.0)
	return worst


func test_every_part_stays_inside_the_frame_in_every_view() -> void:
	var table := _table()
	await wait_process_frames(1)
	var pool := Pool.shared()
	var bad: Array[String] = []
	for item: Pool.Item in pool.replicas:
		if not ResourceLoader.exists("%s%s.glb" % [ReplicaPictures.MODEL_DIR, item.key]):
			continue
		for slot: StringName in Pool.PART_TABLES.values():
			for part: Pool.Item in pool.parts_for(item, slot, true):
				table.show_replica(item.key, &"", false, {slot: part.key})
				for v: int in [ReplicaTurntable.View.THREE_QUARTER, ReplicaTurntable.View.LEFT,
						ReplicaTurntable.View.RIGHT, ReplicaTurntable.View.TOP]:
					table.set_view(v)
					var o := _overshoot(table)
					if maxf(o.x, o.y) > 0.0:
						bad.append("%s+%s v%d x%.2f y%.2f" % [item.key, part.key, v, o.x, o.y])
	table.set_view(ReplicaTurntable.View.THREE_QUARTER)
	assert_eq(bad.size(), 0, "outside the frame: %s" % ", ".join(bad.slice(0, 40)))


func test_bare_replicas_fill_the_frame_in_the_side_views() -> void:
	var table := _table()
	await wait_process_frames(1)
	var bad: Array[String] = []
	for item: Pool.Item in Pool.shared().replicas:
		if not ResourceLoader.exists("%s%s.glb" % [ReplicaPictures.MODEL_DIR, item.key]):
			continue
		table.show_replica(item.key, &"", false)
		table.set_view(ReplicaTurntable.View.RIGHT)
		var o := _overshoot(table)
		if maxf(o.x, o.y) > 0.0:
			bad.append("%s x%.2f y%.2f" % [item.key, o.x, o.y])
	assert_eq(bad.size(), 0, "bare replica outside the frame: %s" % ", ".join(bad))


func test_every_tab_fits_a_1080_screen() -> void:
	var screen := Control.new()
	screen.size = SCREEN
	add_child_autofree(screen)
	var page := LoadoutPage.new(saved, settings)
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	screen.add_child(page)
	page.show_customise(0)
	var view := page.customise()
	var over: Array[String] = []
	await wait_process_frames(2)
	for t: CustomiseView.Tab in CustomiseView.Tab.values():
		view.show_tab(t)
		await wait_process_frames(2)
		var margin := view.get_child(0) as Control
		var need := margin.get_combined_minimum_size().y
		if need > SCREEN.y + 0.5:
			over.append("%s needs %.0f" % [CustomiseView.Tab.keys()[t], need])
		var stage := view.find_child("Stage", true, false) as Control
		if stage.get_global_rect().end.y > SCREEN.y:
			over.append("%s stage ends %.0f" % [CustomiseView.Tab.keys()[t], stage.get_global_rect().end.y])
	assert_eq(over.size(), 0, "past the screen: %s" % ", ".join(over))


func test_nothing_grows_over_many_opens_and_closes() -> void:
	var page := LoadoutPage.new(saved, settings)
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	add_child_autofree(page)
	page.show_customise(0)
	await wait_process_frames(2)
	page.show_gear()
	await wait_process_frames(2)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var table := page.customise().turntable()
	for i in 15:
		page.show_customise(i % 2)
		table.set_view(ReplicaTurntable.View.TOP)
		page.show_gear()
	await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no node kept per open")
	assert_null(table.model())


func test_the_view_survives_a_part_and_a_let_go_refits_the_parts() -> void:
	var table := _table()
	table.show_replica(&"aeg", &"", false)
	table.turn_by(Vector2(80.0, 30.0))
	var yaw := table.yaw()
	var pitch := table.pitch()
	var distance := table.camera_distance()
	table.show_replica(&"aeg", &"", false, {&"muzzle": &"silencer"})
	assert_eq(table.yaw(), yaw)
	assert_eq(table.pitch(), pitch)
	assert_eq(table.camera_distance(), distance)
	table.let_go()
	table.let_go()
	assert_null(table.model())
	table.show_replica(&"aeg", &"", false, {&"muzzle": &"silencer"})
	assert_not_null(table.model())
	assert_not_null(table.model().get_node_or_null("muzzle_silencer"), "the part is fitted to the reloaded model")


func test_hiding_the_page_while_customising_does_not_leave_a_drag_on() -> void:
	var table := _table()
	table.show_replica(&"aeg", &"", false)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	table._gui_input(press)
	table.get_parent().visible = false
	table.get_parent().visible = true
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(50.0, 0.0)
	var yaw := table.yaw()
	table._gui_input(move)
	assert_eq(table.yaw(), yaw, "a drag does not resume after the turntable was hidden")
