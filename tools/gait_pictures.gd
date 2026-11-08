extends SceneTree
## Films the human figure stepping each gait as a match draws it (the figure's own FigureView, its clips through the
## game's animation graph, the walk cycle moved by Hitbox.step_walk_cycle as the simulation does), holding the AEG, on a
## chequered floor whose squares show whether the planted feet slide: frames for the owner's before and after pictures
## of the locomotion clips (GA1). Needs a display and OpenGL, so under xvfb:
##   xvfb-run -a -s "-screen 0 960x720x24" godot --path . --rendering-driver opengl3 -s res://tools/gait_pictures.gd \
##       -- <folder> [gait ...] [view=side|front|quarter]
## Gaits: walk, run, back, left, right, sprint, crouch, kneel (crouched still), call (the hit call), off (walking off),
## run_away and sprint_away (the replica put away: Holster's and Holster_Sprint's arms, BP8); all by default. Each gait writes <folder>/<gait>_<nnn>.png, one a frame at 30 fps over SECONDS. Dev only: tools/
## never ships.

const SIZE := Vector2i(960, 720)
const TICK := 1.0 / 60.0
## Frames written a second (every other 60 Hz tick), and how long each gait is filmed after WARM s of stepping.
const FPS := 30
const SECONDS := 2.0
const WARM := 1.0
const FOV := 40.0
## The camera's distance from the figure (m) and the height it looks at.
const DISTANCE := 5.2
const LOOK_HEIGHT := 0.9
const CHECKER := 0.5
## Each gait: the step in the figure's frame (x right, y ahead, m/s), crouched, sprinting and (optional) holstered.
const GAITS := {
	"walk": [Vector2(0.0, 2.3), 0.0, false],
	"run": [Vector2(0.0, 4.2), 0.0, false],
	"back": [Vector2(0.0, -4.2), 0.0, false],
	"left": [Vector2(-4.2, 0.0), 0.0, false],
	"right": [Vector2(4.2, 0.0), 0.0, false],
	"sprint": [Vector2(0.0, 6.3), 0.0, true],
	"crouch": [Vector2(0.0, 2.1), 1.0, false],
	"kneel": [Vector2.ZERO, 1.0, false],
	"call": [Vector2.ZERO, 0.0, false],
	"off": [Vector2(0.0, 1.4), 0.0, false],
	"run_away": [Vector2(0.0, 4.2), 0.0, false, true],
	"sprint_away": [Vector2(0.0, 6.3), 0.0, true, true],
}
## The gaits filmed from their first tick (the hit call and the walk off after it), and each one's Character.Status.
const STATUS := {"call": Character.Status.CALLING, "off": Character.Status.WALKING_OFF}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("gait_pictures: give an output folder")
		quit(1)
		return
	var folder := args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	var view := "side"
	var gaits: PackedStringArray = []
	for a in args.slice(1):
		if a.begins_with("view="):
			view = a.substr(5)
		elif GAITS.has(a):
			gaits.append(a)
	if gaits.is_empty():
		gaits = PackedStringArray(GAITS.keys())
	root.size = SIZE
	var play := PlayTuning.load_default()
	play.look.push_globals()
	var tuning := SimTuning.load_default()
	var field := Node3D.new()
	root.add_child(field)
	_stage(field)
	var camera := Camera3D.new()
	camera.fov = FOV
	field.add_child(camera)
	var models := FigureModels.new(play.figures)
	models.load_kinds()
	var font := GameTheme.font(800)
	for g in gaits:
		var spec: Array = GAITS[g]
		var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
		c.grounded = true
		c.crouch_amount = spec[1]
		c.prev_crouch_amount = spec[1]
		c.sprinting = spec[2]
		c.armament.holstered = spec.size() > 3 and spec[3]
		var step: Vector2 = spec[0]
		# The figure faces -Z (yaw 0): ahead is -Z, its right +X.
		c.velocity = Vector3(step.x, 0.0, -step.y)
		c.status = STATUS.get(g, Character.Status.ALIVE)
		var warm := 0.0 if g == "call" else WARM
		var v := FigureView.new()
		field.add_child(v)
		v.setup(c, Color(0.24, 0.55, 1.0), tuning.hits, font, false, [], 0.0, play.figures)
		v.set_body(models, FigureMix.HUMAN, play.figures.lod_high)
		var ticks := int((warm + SECONDS) / TICK)
		var shot := 0
		for n in ticks:
			c.prev_position = c.position
			c.prev_walk_cycle = c.walk_cycle
			c.position += c.velocity * TICK
			Hitbox.step_walk_cycle(c, tuning.hits)
			c.status_time += TICK
			var eye := _place_camera(camera, c.position, view)
			v.update(c, 1.0, TICK)
			v.animate(c, 1.0, TICK, eye)
			if v.body() != null and v.body().skeleton != null:
				v.body().skeleton.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)
			await process_frame
			if n * TICK >= warm and n % (60 / FPS) == 0:
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				image.save_png("%s/%s_%03d.png" % [folder, g, shot])
				shot += 1
		v.queue_free()
		await process_frame
		print("gait_pictures: %s, %d frames" % [g, shot])
	field.queue_free()
	await process_frame
	quit(0)


## The camera beside the figure at `at`, following it: side (from its right), front or quarter (ahead and right).
static func _place_camera(camera: Camera3D, at: Vector3, view: String) -> Vector3:
	var way := Vector3(1.0, 0.0, 0.0)
	if view == "front":
		way = Vector3(0.0, 0.0, -1.0)
	elif view == "quarter":
		way = Vector3(1.0, 0.0, -1.0).normalized()
	var look := at + Vector3.UP * LOOK_HEIGHT
	camera.global_position = look + way * DISTANCE + Vector3.UP * 0.25
	camera.look_at(look, Vector3.UP)
	return camera.global_position


## A light, a sky and a chequered floor (CHECKER m squares) to read the feet against.
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
	plane.size = Vector2(400.0, 400.0)
	floor.mesh = plane
	var shader := Shader.new()
	shader.code = """shader_type spatial;
uniform float square = 0.5;
void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = mod(floor(w.x / square) + floor(w.z / square), 2.0);
	ALBEDO = mix(vec3(0.42), vec3(0.58), k);
	ROUGHNESS = 0.9;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("square", CHECKER)
	floor.material_override = mat
	field.add_child(floor)
