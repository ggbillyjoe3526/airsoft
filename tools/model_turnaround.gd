extends SceneTree
## Pictures of one vertex-coloured map model (Dev 3 map models: the flagpole, the skyline's buildings) in the game's
## own material and a plain daylight, from the front, a quarter, the side and the back, for the owner's review before a
## pull request. Each picture is saved as <out>/<name>_<view>.png. Dev tool: tools/ never ships. Needs a display:
##   xvfb-run -a -s "-screen 0 1280x1280x24" godot --path . --rendering-driver opengl3 \
##       -s res://tools/model_turnaround.gd -- <model.glb> <out folder> [<yaw degrees>...] [--pitch <degrees>]
##       [--close <height share>]...
## `--body <hex>` paints a skyline model's BODY faces that colour (SkylineModels), as its kind's piece would be.
## `--pitch` looks down from that many degrees (negative: up from below) instead of PITCH. Each `--close` adds a close view centred at that share of the model's height (0.95 is near its top).

const SIZE := Vector2i(900, 1200)
## The views' yaw (degrees, 0 looks at the model's front, +Z) unless others are named.
const YAWS: Array[float] = [0.0, 40.0, 90.0, 180.0]
const PITCH := 12.0
## A close view frames this share of the model's height (or its footprint, if wider).
const CLOSE_SPAN := 0.08
const SKY := Color("bcd3e8")
const SUN := Color("fff4e2")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("model_turnaround: name a model and an output folder after --")
		quit(1)
		return
	var path: String = args[0]
	var out: String = args[1].trim_suffix("/")
	var yaws: Array[float] = []
	var closes: Array[float] = []
	var pitch := PITCH
	var body := Color.WHITE
	var i := 2
	while i < args.size():
		if args[i] == "--body" and i + 1 < args.size():
			body = Color(args[i + 1])
			i += 2
			continue
		if args[i] == "--pitch" and i + 1 < args.size():
			pitch = float(args[i + 1])
			i += 2
			continue
		if args[i] == "--close" and i + 1 < args.size():
			closes.append(float(args[i + 1]))
			i += 2
			continue
		yaws.append(float(args[i]))
		i += 1
	if yaws.is_empty():
		yaws = YAWS
	var mesh := PropDressConfig.load_mesh(path)
	if mesh == null:
		push_error("model_turnaround: %s won't load" % path)
		quit(1)
		return
	root.size = SIZE
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = SKY
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("aebfd4")
	env.environment.ambient_light_energy = 0.45
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_color = SUN
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-42.0, 35.0, 0.0)
	root.add_child(sun)
	var model := MeshInstance3D.new()
	model.mesh = _painted(mesh, body)
	model.material_override = LookMaterials.vertex_colour(0.8, 0.0)
	root.add_child(model)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var box := mesh.get_aabb()
	plane.size = Vector2.ONE * maxf(box.size.x, box.size.z) * 3.0
	ground.mesh = plane
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color("6e6c66")
	ground.material_override = grey
	root.add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	var centre := box.get_center()
	var reach := box.size.length() * 0.5
	var shots: Array[Array] = []
	for yaw in yaws:
		shots.append(["%03d" % roundi(yaw), yaw, centre, reach])
	for k in closes.size():
		var c := Vector3(centre.x, box.position.y + box.size.y * closes[k], centre.z)
		var r := maxf(box.size.y * CLOSE_SPAN, maxf(box.size.x, box.size.z) * 0.6)
		shots.append(["close%d" % (k + 1), 30.0, c, r])
	var stem := path.get_file().get_basename()
	for shot in shots:
		var yaw: float = shot[1]
		var look: Vector3 = shot[2]
		var r: float = shot[3]
		var dist := r / sin(deg_to_rad(cam.fov * 0.5)) * 1.05
		var dir := Vector3(sin(deg_to_rad(yaw)), sin(deg_to_rad(pitch)), cos(deg_to_rad(yaw))).normalized()
		cam.position = look + dir * dist
		cam.near = dist * 0.01
		cam.far = dist * 4.0
		cam.look_at(look, Vector3.UP)
		for f in 6:
			await process_frame
		var img := root.get_texture().get_image()
		var file := "%s/%s_%s.png" % [out, stem, shot[0]]
		img.save_png(file)
		print("[model_turnaround] %s" % file)
	quit(0)


## `mesh` with its BODY corners (SkylineModels.BODY_BELOW) painted `body` (sRGB) times their shade.
static func _painted(mesh: Mesh, body: Color) -> Mesh:
	var arrays := mesh.surface_get_arrays(0)
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var lin := body.srgb_to_linear()
	for i in colours.size():
		var c := colours[i]
		if c.a < SkylineModels.BODY_BELOW:
			colours[i] = Color(lin.r * c.r, lin.g * c.g, lin.b * c.b, 1.0)
	arrays[Mesh.ARRAY_COLOR] = colours
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out

