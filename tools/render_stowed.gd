extends SceneTree
## Pictures of the replicas stowed on the figures (ST1), as a match draws them (dev only, never exported): one figure in
## a plain lit studio, posed through FigureView like a bot (no simulation), from named views. Needs a display and
## OpenGL, so under xvfb:
##   xvfb-run -a -s "-screen 0 1600x1000x24" godot --path . --rendering-driver opengl3 --resolution 1600x1000 \
##       -s res://tools/render_stowed.gd -- <folder> [shot ...]
## Shots (all by default): <rifle|pistol|holstered>_<rifle id>_<pistol id>_<view> (views below; rifle ids aeg, sniper,
## smg, shotgun; pistol ids pistol, cyber), robot_pistol_aeg_pistol_front: rifle aims the rifle (the pistol in the holster), pistol
## aims the pistol (the rifle on the back), holstered puts both away, crouch aims the rifle crouched, run sprints
## holstered (on the spot).

const SIZE := Vector2i(1600, 1000)
const SETTLE_FRAMES := 45
const TICK := 1.0 / 60.0
const FOV := 32.0
## The views: where the camera stands (m, the figure at the origin facing -z) and what it looks at; or, with a bone's
## name, the camera this way off that bone wherever the pose puts it.
const VIEWS := {
	"front": [Vector3(-1.1, 1.45, -2.9), Vector3(0.0, 1.15, 0.0)],
	"back": [Vector3(1.2, 1.5, 2.9), Vector3(0.0, 1.15, 0.0)],
	"left": [Vector3(-3.0, 1.35, 0.3), Vector3(0.0, 1.1, -0.1)],
	"right": [Vector3(3.0, 1.35, -0.3), Vector3(0.0, 1.1, -0.1)],
	"closeback": [Vector3(0.8, 1.6, 1.1), Vector3(0.0, 1.25, 0.05)],
	"holster": [Vector3(0.75, 1.05, -0.45), Vector3(0.2, 0.9, 0.05)],
	"holsterback": [Vector3(0.65, 1.15, 0.6), Vector3(0.2, 0.9, 0.05)],
	"backside": [Vector3(1.5, 1.35, 0.35), Vector3(0.0, 1.2, 0.2)],
	# Off the hips wherever the pose puts them, at the holster: the camera, then what it looks at.
	"hipholster": [Vector3(0.75, 0.1, -0.5), "Hips", Vector3(0.2, -0.05, 0.05)],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if not args.is_empty() else "user://stowed"
	var wanted := args.slice(1)
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = SIZE
	var play := PlayTuning.load_default()
	play.look.push_globals()
	var tuning := SimTuning.load_default()
	var stage := _studio()
	root.add_child(stage)
	var camera := Camera3D.new()
	camera.fov = FOV
	camera.near = 0.02
	stage.add_child(camera)
	camera.current = true
	var models := FigureModels.new(play.figures)
	models.load_kinds()
	var font := GameTheme.font(800)
	var shots: Array[String] = []
	for held: String in ["rifle", "pistol", "holstered", "crouch", "run"]:
		for rifle: String in ["aeg", "sniper", "smg", "shotgun"]:
			for pistol: String in ["pistol", "cyber"]:
				for view: String in VIEWS:
					shots.append("%s_%s_%s_%s" % [held, rifle, pistol, view])
	shots.append("robot_pistol_aeg_pistol_front")
	for shot in shots:
		if not wanted.is_empty() and not wanted.has(shot):
			continue
		var parts := shot.split("_")
		var robot := parts[0] == "robot"
		if robot:
			parts = parts.slice(1)
		var held := parts[0]
		var view := parts[3]
		var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(StringName(parts[1])),
				ReplicaStats.load_replica(StringName(parts[2]))]
		var c := Character.new(1, 0, Vector3.ZERO, 0.0, loadout)
		c.grounded = true
		c.armament.active = 1 if held == "pistol" else 0
		c.armament.holstered = held == "holstered" or held == "run"
		c.crouch_amount = 1.0 if held == "crouch" else 0.0
		c.sprinting = held == "run"
		# Running on the spot: the legs step by the velocity, the figure is put back each frame.
		c.velocity = Vector3(0.0, 0.0, -5.5) if held == "run" else Vector3.ZERO
		var v := FigureView.new()
		stage.add_child(v)
		v.setup(c, Color(0.24, 0.55, 1.0), tuning.hits, font, false, [], 0.0, play.figures)
		v.set_body(models, FigureMix.ROBOT if robot else FigureMix.HUMAN, play.figures.lod_high)
		for n in SETTLE_FRAMES:
			c.prev_position = c.position
			c.prev_yaw = c.yaw
			c.prev_pitch = c.pitch
			v.update(c, 1.0, TICK)
			v.animate(c, 1.0, TICK, camera.global_position)
			await process_frame
		var at: Array = VIEWS[view]
		if at[1] is String:
			var rig := v.body().skeleton
			var target := rig.global_transform * rig.get_bone_global_pose(rig.find_bone(at[1])).origin
			camera.global_position = target + (at[0] as Vector3)
			camera.look_at(target + (at[2] as Vector3 if at.size() > 2 else Vector3.ZERO))
		else:
			camera.global_position = at[0]
			camera.look_at(at[1])
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [folder, shot]
		root.get_texture().get_image().save_png(path)
		print("[render_stowed] %s" % path)
		v.queue_free()
		await process_frame
	quit(0)


## A grey studio: a floor, sky light and a low sun for shape.
static func _studio() -> Node3D:
	var stage := Node3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.56, 0.58, 0.61)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.68)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(-35.0), 0.0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(150.0), 0.0)
	fill.light_energy = 0.45
	stage.add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 12.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.43, 0.45)
	mat.roughness = 0.9
	plane.material = mat
	floor_mesh.mesh = plane
	stage.add_child(floor_mesh)
	return stage
