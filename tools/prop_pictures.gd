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
		# WQ1: "a+b" draws models together where they stand in one model space (a tree's trunk and its crown)
		var insts: Array[MeshInstance3D] = []
		var box := AABB()
		for part in model.split("+"):
			var path: String = part if part.ends_with(".glb") else props.models.get(StringName(part), "")
			var mesh := PropDressConfig.load_mesh(path)
			if mesh == null:
				push_error("prop_pictures: %s won't load" % part)
				continue
			var inst := MeshInstance3D.new()
			inst.mesh = mesh
			inst.material_override = _material_for(props, StringName(part))
			stage.add_child(inst)
			box = mesh.get_aabb() if insts.is_empty() else box.merge(mesh.get_aabb())
			insts.append(inst)
		if insts.is_empty():
			continue
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
		for inst in insts:
			inst.queue_free()
		await process_frame
	quit()


## Model `model`'s material as the game draws it: its leaves and bark or its surfaces (WQ1, PropDressConfig.model_barks
## and surface_models), else the props' shared vertex colours with their perforations and ribs, its own roughness.
func _material_for(props: PropDressConfig, model: StringName) -> ShaderMaterial:
	var rough: float = props.model_roughness.get(model, props.roughness)
	if props.model_barks.has(model):
		var barks: PackedStringArray = props.model_barks[model]
		var maps: Array[Texture2D] = [null, null, null, null]
		for i in mini(barks.size(), 2):
			maps[i * 2] = load("%s/%s.png" % [props.foliage_folder, barks[i]]) as Texture2D
			maps[i * 2 + 1] = load("%s/%s_nor.png" % [props.foliage_folder, barks[i]]) as Texture2D
		return LookMaterials.foliage(load(props.foliage_sheet) as Texture2D, maps[0], maps[1], maps[2], maps[3], rough,
				0.0, false, props.model_mip_cover.get(model, PropDress.MIP_COVER),
				props.model_alpha_lod.get(model, PropDress.ALPHA_LOD))
	if props.surface_models.has(model):
		var m := LookMaterials.surfaced(load(props.surface_maps) as TextureLayered,
				load(props.surface_relief) as TextureLayered, rough)
		m.set_shader_parameter(&"paint_by_custom", false)
		return m
	var mat := LookMaterials.vertex_colour(rough, 0.0)
	mat.set_shader_parameter(&"perforations", true)
	return mat


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
