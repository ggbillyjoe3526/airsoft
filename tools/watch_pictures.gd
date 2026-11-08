extends SceneTree
## Pictures of Watching here (BP8) as the HUD draws it: the order wheel open on Watching Here, then the marker over the
## spot you marked ("WATCHING · 15 M", its ring on the floor), then the wheel again with Watching Here in force. On a
## chequered floor with a few crates, through a camera at standing eye height. Needs a display and OpenGL, so:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 -s res://tools/watch_pictures.gd \
##       -- <folder>
## Writes wheel_pick.png, marker.png and wheel_active.png. Dev only: tools/ never ships.

const SIZE := Vector2i(1920, 1080)
const EYE := Vector3(0.0, 1.62, 0.0)
const SPOT := Vector3(1.5, 0.0, -15.0)
const CRATES: Array[Vector3] = [Vector3(-4.0, 0.6, -12.0), Vector3(4.5, 0.6, -18.0), Vector3(-1.0, 0.6, -24.0)]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("watch_pictures: give an output folder")
		quit(1)
		return
	var folder := args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = SIZE
	var field := Node3D.new()
	root.add_child(field)
	_stage(field)
	var camera := Camera3D.new()
	camera.fov = 75.0
	field.add_child(camera)
	camera.global_position = EYE
	camera.look_at(SPOT + Vector3.UP * 0.8, Vector3.UP)
	var you := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var controls := ControlsConfig.new()
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var frame := Control.new()
	frame.size = Vector2(SIZE)
	layer.add_child(frame)
	var hud := Hud.new()
	frame.add_child(hud)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
	hud.setup_orders(controls)
	# Only the orders: the call-your-hit banner a HUD never updated shows is hidden.
	for label: Node in hud.find_children("*", "Label", true, false):
		var text := (label as Label).text
		if text.contains("HIT") or text.begins_with("Hand up"):
			(label as Label).visible = false
	var wheel := OrderWheelPointer.new(controls.wheel_reach, controls.wheel_dead_zone, controls.wheel_orders.size())
	var outcome := SquadOrders.Outcome.new()
	var slot := controls.wheel_orders.find(SquadOrder.Kind.WATCH)
	var angle := TAU * slot / controls.wheel_orders.size()
	wheel.start()
	wheel.at = Vector2(sin(angle), -cos(angle)) * controls.wheel_reach
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, 0.016)
	hud.place_hold_marker(camera, SPOT, false)
	await _shot(folder + "/wheel_pick.png")
	wheel.close()
	hud.update_orders(wheel, SquadOrder.Kind.WATCH, outcome, 0.5)
	hud.place_hold_marker(camera, SPOT, true, false, true)
	await _shot(folder + "/marker.png")
	wheel.start()
	wheel.at = Vector2.ZERO
	hud.update_orders(wheel, SquadOrder.Kind.WATCH, outcome, 0.016)
	hud.place_hold_marker(camera, SPOT, false)
	await _shot(folder + "/wheel_active.png")
	print("watch_pictures: 3 pictures")
	quit(0)


func _shot(path: String) -> void:
	for n in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


## A light, a sky, a chequered floor and a few crates.
static func _stage(field: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0)
	sun.shadow_enabled = true
	field.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.68, 0.74)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.82)
	env.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = env
	field.add_child(world)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	floor.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.45, 0.5, 0.42)
	floor.material_override = floor_mat
	field.add_child(floor)
	for at in CRATES:
		var crate := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.6, 1.2, 1.2)
		crate.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.42, 0.28)
		crate.material_override = mat
		crate.position = at
		field.add_child(crate)
