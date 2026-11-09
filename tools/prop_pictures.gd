extends SceneTree
## Pictures of map props for review (Dev 3 map models): each model named after `--` drawn alone in the props' own
## material (LookMaterials.vertex_colour, the game's shared light) on a grey floor under a high sun, from a three-quarter
## view of the whole model, square on from its front, and close on its lowest metre and a half (`<model>_quarter.png`,
## `_front.png`, `_foot.png`); one hanging from the roof (its top at its origin) from under it, with no floor. A model is a name in PropDressConfig.models or a path to a .glb. Needs a display, so
## under xvfb (Forward+ on lavapipe in the cloud):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s res://tools/prop_pictures.gd -- <folder> <model>...
## Dev only: tools/ never ships.

const SIZE := Vector2i(1200, 900)
const BACKGROUND := Color8(0xd8, 0xd4, 0xe0)
const FLOOR := Color8(0xb9, 0xb4, 0xae)
## The close view's height (m) over the model's foot, and how much of the frame the model fills in the whole views.
const FOOT := 1.5
const FILL := 1.25


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("prop_pictures: <folder> <model>...")
		quit(1)
		return
	var folder := args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = SIZE
	var props := PlayTuning.load_default().site_look.props
	var stage := _stage()
	root.add_child(stage)
	var ground := stage.get_node("Ground") as MeshInstance3D
	var camera := Camera3D.new()
	camera.fov = 40.0
	stage.add_child(camera)
	camera.make_current()
	for model in args.slice(1):
		var path: String = model if model.ends_with(".glb") else props.models.get(StringName(model), "")
		var mesh := PropDressConfig.load_mesh(path)
		if mesh == null:
			push_error("prop_pictures: %s won't load" % model)
			continue
		var inst := MeshInstance3D.new()
		inst.mesh = mesh
		inst.material_override = LookMaterials.vertex_colour(0.7, 0.0)
		stage.add_child(inst)
		var box := mesh.get_aabb()
		var name := model.get_file().get_basename()
		var mid := box.get_center()
		var reach := box.size.length() * 0.5 * FILL
		var dist := reach / tan(deg_to_rad(camera.fov * 0.5))
		# a model hanging from the roof (its top at its origin) is seen from under it, with no floor
		var hangs := box.end.y <= 0.01
		var below := -1.0 if hangs else 1.0
		ground.visible = not hangs
		await _shot(camera, mid + Vector3(0.7, 0.35 * below, 1.0).normalized() * dist, mid, folder, name + "_quarter")
		await _shot(camera, mid + Vector3(0.0, 0.05 * below, 1.0).normalized() * dist, mid, folder, name + "_front")
		var foot := Vector3(mid.x, box.position.y + minf(FOOT, box.size.y) * 0.5, mid.z)
		var near := maxf(minf(FOOT, box.size.y), minf(box.size.x, 3.0)) * 1.1 / tan(deg_to_rad(camera.fov * 0.5))
		await _shot(camera, foot + Vector3(0.6, 0.45 * below, 1.0).normalized() * near, foot, folder, name + "_foot")
		await process_frame
		inst.queue_free()
		await process_frame
	quit()


func _shot(camera: Camera3D, from: Vector3, at: Vector3, folder: String, file: String) -> void:
	camera.look_at_from_position(from, at)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, file])


func _stage() -> Node3D:
	var stage := Node3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.74, 0.82)
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(60.0, 60.0)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = floor_mesh
	ground.material_override = LookMaterials.paint(FLOOR, 0.9)
	ground.position.y = -0.001
	stage.add_child(ground)
	return stage
