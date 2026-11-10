extends SceneTree
## Pictures of CL1's climb and stairs runs for review: the human figure (a bot, as a match draws it: FigureView, its clips
## through the game's animation graph) running at a 0.9 m platform and climbing it, and running up and down a 1:2 stair,
## each before (Run_F alone, as before CL1) and after (the Stairs_Up and Stairs_Down clips blended in by the slope); then
## your own first-person view through the same climb (FirstPersonView's heave and ReplicaView's arms). The climb is the
## simulation's own (Vault.try_start and Vault.step on a BoxWorld platform as tall as Subway's); the stairs body
## follows the slope as a ramp's does. Needs a display and OpenGL, so under xvfb:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 -s res://tools/climb_pictures.gd \
##       -- <folder> [shot ...]
## Shots: climb (side), climb_quarter, stairs_up, stairs_up_before, stairs_down, stairs_down_before, fp_climb; all by
## default. Each writes <folder>/<shot>_<nnn>.png, one a frame at FPS. The shot `subway` instead plays Subway
## (a whole PlaySession, frozen, nobody drawn) and looks down at each end of a track pit where steps stood before CL1
## (`subway_<site>.png`; run it on the map before and after to compare). Dev only: tools/ never ships.

const SIZE := Vector2i(1600, 900)
const TICK := 1.0 / 60.0
const FPS := 15
const FOV := 40.0
const DISTANCE := 5.6
const LOOK_HEIGHT := 1.0
## The platform: as tall as Subway's over its track bed, its edge EDGE m ahead (-Z) of the start.
const PLATFORM := 0.9
const EDGE := -3.0
## The stair: 1:2 (MovementConfig.stairs_slope's 0.5), RISE m a step, from FOOT m ahead (-Z) of the start, STEPS steps.
const RISE := 0.125
const FOOT := -2.0
const STEPS := 16
## Subway's track-pit ends where steps up to the platform stood before CL1: name, camera, the point it looks at.
const SITES := [
	["north_west", Vector3(-44.0, 3.0, -6.0), Vector3(-50.0, 0.0, -10.4)],
	["north_middle", Vector3(25.0, 3.0, -6.0), Vector3(19.0, 0.0, -10.4)],
	["south_west", Vector3(-44.0, 3.0, 6.0), Vector3(-50.0, 0.0, 10.4)],
	["south_east", Vector3(21.0, 3.0, 6.0), Vector3(27.0, 0.0, 10.4)],
]
const SHOTS := ["climb", "climb_quarter", "stairs_up", "stairs_up_before", "stairs_down", "stairs_down_before",
		"fp_climb"]

var _play: PlayTuning = null
var _tuning: SimTuning = null
var _models: FigureModels = null
var _font: Font = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("climb_pictures: give an output folder")
		quit(1)
		return
	var folder := args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	var shots: PackedStringArray = []
	for a in args.slice(1):
		if a == "subway":
			root.size = SIZE
			await _subway(folder)
			quit(0)
			return
		if SHOTS.has(a):
			shots.append(a)
	if shots.is_empty():
		shots = PackedStringArray(SHOTS)
	root.size = SIZE
	_play = PlayTuning.load_default()
	_play.look.push_globals()
	_tuning = SimTuning.load_default()
	_models = FigureModels.new(_play.figures)
	_models.load_kinds()
	_font = GameTheme.font(800)
	for shot in shots:
		var field := Node3D.new()
		root.add_child(field)
		_stage(field)
		var n := 0
		if shot.begins_with("climb"):
			n = await _climb(field, folder, shot, shot.ends_with("quarter"))
		elif shot.begins_with("stairs"):
			n = await _stairs(field, folder, shot, shot.begins_with("stairs_up"), not shot.ends_with("before"))
		else:
			n = await _fp_climb(field, folder, shot)
		field.queue_free()
		await process_frame
		print("climb_pictures: %s, %d frames" % [shot, n])
	quit(0)


## Runs at the platform, climbs it on the Jump press the moment a climb is found, and runs on over the top.
func _climb(field: Node3D, folder: String, shot: String, quarter: bool) -> int:
	var world := _platform_world(field)
	var c := _runner(Vector3(0.0, _tuning.body.rest_gap, 0.0))
	var v := _figure(field, c)
	var camera := _camera(field)
	var probe := VaultState.new()
	var mover := world.mover()
	var cmd := PlayerCommand.new()
	var frames := 0
	var after := -1.0
	for n in 240:
		cmd.reset(0.0, 0.0)
		cmd.forward = 1.0
		cmd.jump = not c.vault.active and Vault.find(c, 0.0, _tuning, world, probe)
		_tick(c, cmd, world, mover)
		if after < 0.0 and c.vault.active:
			after = 0.0
		if after >= 0.0:
			after += TICK
		var film := after >= 0.0 or -c.position.z > absf(EDGE) - 1.6
		var eye := _follow(camera, Vector3(0.0, 0.3, EDGE + 0.2), quarter)
		await _draw(v, c, eye)
		if film and n % (60 / FPS) == 0:
			await _save(folder, shot, frames)
			frames += 1
		if after > 1.1:
			break
	v.queue_free()
	return frames


## Runs up (or down) the stair at the run's pace, the body following the slope as on a ramp; `clips` false draws it
## as before CL1 (no stairs clips: c.stairs held at none).
func _stairs(field: Node3D, folder: String, shot: String, up: bool, clips: bool) -> int:
	_draw_stair(field)
	var top := RISE * STEPS
	var start := Vector3(0.0, 0.0 if up else top, 0.0 if up else FOOT - top * 2.0 - 2.0)
	var c := _runner(start)
	c.yaw = 0.0 if up else PI
	var v := _figure(field, c)
	var camera := _camera(field)
	var speed := _tuning.movement.run_speed
	var way := Vector3(-sin(c.yaw), 0.0, -cos(c.yaw))
	var frames := 0
	for n in 300:
		c.prev_position = c.position
		c.prev_walk_cycle = c.walk_cycle
		c.prev_stairs = c.stairs
		c.velocity = way * speed
		c.position += c.velocity * TICK
		c.position.y = _stair_y(c.position.z)
		Hitbox.step_walk_cycle(c, _tuning.hits)
		if clips:
			Hitbox.step_stairs(c, _tuning.hits, TICK)
		var eye := _follow(camera, c.position, false, 1.1)
		await _draw(v, c, eye)
		var on := c.position.z < FOOT - 0.5 and c.position.z > FOOT - top * 2.0 + 0.5
		if on and n % (60 / FPS) == 0:
			await _save(folder, shot, frames)
			frames += 1
		if not up and c.position.z > FOOT + 1.0:
			break
		if up and c.position.z < FOOT - top * 2.0 - 1.0:
			break
	v.queue_free()
	return frames


## Your own view through the climb: the eyes' heave and tip (FirstPersonView) and the replica carried low
## (ReplicaView), the platform's edge ahead.
func _fp_climb(field: Node3D, folder: String, shot: String) -> int:
	var world := _platform_world(field)
	var c := _runner(Vector3(0.0, _tuning.body.rest_gap, EDGE + 3.2))
	var eyes := FirstPersonView.new()
	field.add_child(eyes)
	eyes.setup(_play.view, _tuning.body, _tuning.hits)
	var hands := ReplicaView.new()
	eyes.camera.add_child(hands)
	hands.setup(_play.viewmodel, c.armament.replicas, world, [], false, [], _play.view, eyes.camera)
	var input := PlayerInput.new()
	input.view_pitch = deg_to_rad(-8.0)
	var probe := VaultState.new()
	var mover := world.mover()
	var cmd := PlayerCommand.new()
	var frames := 0
	var after := -1.0
	for n in 200:
		cmd.reset(0.0, input.view_pitch)
		cmd.forward = 1.0
		cmd.jump = not c.vault.active and Vault.find(c, 0.0, _tuning, world, probe)
		_tick(c, cmd, world, mover)
		if after < 0.0 and c.vault.active:
			after = 0.0
		if after >= 0.0:
			after += TICK
		eyes.update(c, input, 1.0, TICK, 0.0)
		var look := -eyes.camera.global_basis.z
		hands.update(c, input.view_yaw, input.view_pitch, eyes.camera.global_position, look, TICK, 0.0)
		await process_frame
		if (after >= 0.0 or -c.position.z > absf(EDGE) - 1.6) and n % (60 / FPS) == 0:
			await _save(folder, shot, frames)
			frames += 1
		if after > 0.9:
			break
	input.free()
	eyes.queue_free()
	return frames


## Each SITES end of Subway's track pits, the map as a match draws it, the play frozen and nobody drawn.
func _subway(folder: String) -> void:
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.map_id = "subway"
	session.match_seed = 3
	session.autopilot = true
	root.add_child(session)
	await process_frame
	session.set_physics_process(false)
	session.set_process(false)
	for child in session.find_children("*", "CanvasLayer", true, false):
		(child as CanvasLayer).visible = false
	for child in session.find_children("*", "", true, false):
		if child is FigureView or child is ReplicaView:
			(child as Node3D).visible = false
	var camera := session._eyes.camera
	camera.fov = 70.0
	for site: Array in SITES:
		camera.look_at_from_position(site[1], site[2])
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/subway_%s.png" % [folder, site[0]])
	print("climb_pictures: subway, %d sites" % SITES.size())
	session.queue_free()
	await process_frame


## One simulation tick for `c` as Simulation.step runs it: the Jump press tried as a vault (a climb here), then the
## vault's step or the ground's, the legs' swing and the stairs share after.
func _tick(c: Character, cmd: PlayerCommand, world: WorldQuery, mover: CharacterMover) -> void:
	c.prev_position = c.position
	c.prev_crouch_amount = c.crouch_amount
	c.prev_walk_cycle = c.walk_cycle
	c.prev_stairs = c.stairs
	c.prev_yaw = c.yaw
	c.prev_pitch = c.pitch
	var events := SimEvents.new()
	if not c.vault.active:
		Vault.try_start(c, cmd, _tuning, world, events)
	if c.vault.active:
		Vault.step(c, cmd, _tuning, TICK, mover)
	else:
		Movement.step(c, cmd, _tuning.movement, _tuning.accuracy, TICK, mover)
	Hitbox.step_walk_cycle(c, _tuning.hits)
	Hitbox.step_stairs(c, _tuning.hits, TICK)


func _runner(at: Vector3) -> Character:
	var c := Character.new(1, 0, at, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	c.prev_position = at
	return c


func _figure(field: Node3D, c: Character) -> FigureView:
	var v := FigureView.new()
	field.add_child(v)
	v.setup(c, Color(0.24, 0.55, 1.0), _tuning.hits, _font, false, [], 0.0, _play.figures)
	v.set_body(_models, FigureMix.HUMAN, _play.figures.lod_high)
	return v


func _draw(v: FigureView, c: Character, eye: Vector3) -> void:
	v.update(c, 1.0, TICK)
	v.animate(c, 1.0, TICK, eye)
	if v.body() != null and v.body().skeleton != null:
		v.body().skeleton.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)
	await process_frame


func _save(folder: String, shot: String, frame: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s_%03d.png" % [folder, shot, frame])


func _camera(field: Node3D) -> Camera3D:
	var camera := Camera3D.new()
	camera.fov = FOV
	field.add_child(camera)
	camera.make_current()
	return camera


## The camera DISTANCE m to the figure's right (or ahead and right, `quarter`) and `above` m over `at`'s LOOK_HEIGHT,
## looking at it.
static func _follow(camera: Camera3D, at: Vector3, quarter: bool, above: float = 0.3) -> Vector3:
	var way := Vector3(1.0, 0.0, 0.0) if not quarter else Vector3(1.0, 0.0, -0.8).normalized()
	var look := at + Vector3.UP * LOOK_HEIGHT
	camera.global_position = look + way * DISTANCE + Vector3.UP * above
	camera.look_at(look, Vector3.UP)
	return camera.global_position


## The floor and a PLATFORM m platform from EDGE on, as a BoxWorld and drawn (a pale top, a darker face).
func _platform_world(field: Node3D) -> BoxWorld:
	var w := BoxWorld.new(_tuning.body)
	w.add_box(Vector3(0.0, -0.25, 0.0), Vector3(80.0, 0.5, 80.0))
	var center := Vector3(0.0, PLATFORM * 0.5, EDGE - 6.0)
	var size := Vector3(2.4, PLATFORM, 12.0)
	w.add_box(center, size)
	_box(field, center, size, Color(0.36, 0.34, 0.31))
	# the platform's edge: a painted line along its lip, as a station's
	_box(field, Vector3(0.0, PLATFORM + 0.002, EDGE - 0.1), Vector3(2.4, 0.004, 0.12), Color(0.7, 0.58, 0.16))
	return w


## STEPS steps of RISE m and 2 x RISE m treads from FOOT on, drawn so the 1:2 line the body follows runs through each
## tread's middle, a landing at the top; its near side just past the runner's right so the feet show on the treads.
func _draw_stair(field: Node3D) -> void:
	var run := RISE * 2.0
	for k in range(1, STEPS + 1):
		var h := RISE * k
		var near := FOOT - run * (k - 0.5)
		var depth := run if k < STEPS else 4.0
		_box(field, Vector3(-0.5, h * 0.5, near - depth * 0.5), Vector3(1.8, h, depth),
				Color(0.34, 0.34, 0.36) if k % 2 == 0 else Color(0.4, 0.4, 0.42))


## The ground under a stair runner at `z`: the 1:2 line between the foot and the top landing.
static func _stair_y(z: float) -> float:
	var top := RISE * STEPS
	return clampf((FOOT - z) * 0.5, 0.0, top)


static func _box(field: Node3D, center: Vector3, size: Vector3, colour: Color) -> void:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.9
	mesh.material = mat
	m.mesh = mesh
	m.position = center
	field.add_child(m)


## A light, a sky and a chequered floor (0.5 m squares) to read the feet against (as tools/gait_pictures.gd).
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
void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = mod(floor(w.x / 0.5) + floor(w.z / 0.5), 2.0);
	ALBEDO = mix(vec3(0.42), vec3(0.58), k);
	ROUGHNESS = 0.9;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	floor.material_override = mat
	field.add_child(floor)
