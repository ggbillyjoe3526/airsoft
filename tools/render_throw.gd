extends SceneTree
## Pictures of a figure throwing a bomb (GT1), for review: each figure kind in turn alone on a plain floor, posed at a row of shares of the throw (held in hand, then through the windup to the release and the recovery),
## seen from the figure's right, a front quarter, the rear and close on the hand, to
## `<folder>/throw_<kind>_<view>_<n>.png`. Needs a display and
## OpenGL, so under xvfb:
##   xvfb-run -a -s "-screen 0 1280x960x24" godot --path . --rendering-driver opengl3 -s res://tools/render_throw.gd \
##       -- <folder> [smoke|flash]
## Dev only: tools/ never ships.

const SIZE := Vector2i(960, 1080)
const SETTLE_FRAMES := 30
const TICK := 1.0 / 60.0
## The shares pictured (-1: the bomb held in hand, MC1).
const SHARES: Array[float] = [-1.0, 0.1, 0.4, 0.6, 0.85, 1.0, 1.4, 1.8]
## The views: the camera's offset from the figures' middle (m, the figures face -z) and the point it looks at.
const VIEWS: Dictionary[String, Vector3] = {
	"right": Vector3(3.2, 1.3, 0.0),
	"front": Vector3(1.8, 1.4, -2.6),
	"rear": Vector3(-1.6, 1.6, 2.6),
	"hand": Vector3(1.5, 1.7, -1.6),
	"face": Vector3(0.3, 1.6, -2.2),
}
const LOOK_AT := Vector3(0.0, 1.1, 0.0)
const HAND_AT := Vector3(0.25, 1.45, 0.0)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if not args.is_empty() else "user://throw"
	var kind := Grenade.Kind.FLASH if args.has("flash") else Grenade.Kind.SMOKE
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = SIZE
	var play := PlayTuning.load_default()
	play.look.push_globals()
	var tuning := SimTuning.load_default()
	var field := Node3D.new()
	root.add_child(field)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.66, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.78)
	env.environment.ambient_light_energy = 0.6
	field.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	field.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	floor_mesh.mesh = plane
	field.add_child(floor_mesh)
	var grenades := GrenadeView.new()
	field.add_child(grenades)
	grenades.setup(1, tuning.grenades, false)
	var models := FigureModels.new(play.figures)
	models.load_kinds()
	var font := GameTheme.font(800)
	var camera := Camera3D.new()
	camera.fov = 40.0
	field.add_child(camera)
	camera.make_current()
	var count := 0
	for kind_index in play.figures.kinds.size():
		var c := Character.new(kind_index + 1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
		c.grounded = true
		c.armament.put_down()
		var v := FigureView.new()
		field.add_child(v)
		v.setup(c, Color("3f7fd6"), tuning.hits, font, false, [], 0.0, play.figures)
		v.set_body(models, kind_index, play.figures.lod_high)
		v.set_bombs(grenades.meshes(), tuning.grenades)
		if args.has("nokit") and v.body() != null:
			for mi in v.body().meshes:
				if mi.name.begins_with(args[args.find("nokit") + 1] if args.find("nokit") + 1 < args.size() else "Kit"):
					mi.visible = false
		for n in SHARES.size():
			_set_share(c, SHARES[n], kind, tuning.grenades)
			if args.has("call"):
				c.status = Character.Status.CALLING
				c.status_time = 1.0
			for f in SETTLE_FRAMES:
				v.update(c, 1.0, TICK)
				v.animate(c, 1.0, TICK, camera.global_position)
				await process_frame
			for view: String in VIEWS:
				camera.fov = 26.0 if view == "hand" or view == "face" else 40.0
				camera.look_at_from_position(VIEWS[view], HAND_AT if view == "hand" or view == "face" else LOOK_AT)
				await process_frame
				await process_frame
				var image := root.get_texture().get_image()
				image.save_png("%s/throw_%s_%s_%d.png" % [folder, play.figures.kinds[kind_index], view, n])
				count += 1
		v.queue_free()
		await process_frame
	print("[render_throw] %d pictures in %s" % [count, folder])
	quit(0)


## `c`'s bomb `share` of the way through its throw (below 0: held in hand), by `cfg`'s windup and recovery.
static func _set_share(c: Character, share: float, kind: Grenade.Kind, cfg: GrenadeConfig) -> void:
	var hand := c.grenades
	hand.stop()
	if share < 0.0:
		hand.readied = kind
		return
	hand.throwing = kind
	hand.released = share >= 1.0
	hand.windup_left = cfg.windup * (1.0 - minf(share, 1.0))
	hand.recover_left = cfg.recover * (1.0 - clampf(share - 1.0, 0.0, 1.0)) if hand.released else cfg.recover
