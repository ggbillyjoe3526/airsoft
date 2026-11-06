extends SceneTree
## Pictures of your arms holding a smoke or flash bomb in first person (GT1), for review: a field drawn at eye height on
## High by day (as tools/eye_pictures.gd draws it), the bomb in hand as a match draws it (GrenadeView with your arms),
## readied in hand and at the end of the windup, for each kind and figure kind, to
## `<folder>/held_<kind>_<state>_<figure>.jpg`. Needs a display and OpenGL, so under xvfb:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 -s res://tools/render_held_bomb.gd \
##       -- <folder> [<map id> <x>,<z>,<yaw degrees>,<pitch degrees>]
## Dev only: tools/ never ships.

const SIZE := Vector2i(1600, 900)
const QUALITY := 0.9
const SETTLE_FRAMES := 40
const DT := 1.0 / 60.0
const MAP := "depot"
const SPOT := Vector4(0.0, 0.0, -90.0, 2.0)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if not args.is_empty() else "user://held_bomb"
	var map_id := args[1] if args.size() > 2 else MAP
	var spot := SPOT
	if args.size() > 2:
		var f := args[2].split_floats(",")
		spot = Vector4(f[0], f[1], f[2], f[3])
	DirAccess.make_dir_recursive_absolute(folder)
	var play := PlayTuning.load_default()
	var tuning := SimTuning.load_default()
	var map := MapData.load_map(map_id, play.map_style, tuning.rounds.team_size)
	if not map.ok():
		push_error("render_held_bomb: %s refused" % map_id)
		quit(1)
		return
	var port := SubViewport.new()
	port.size = SIZE
	port.msaa_3d = Viewport.MSAA_4X
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(port)
	var sun := LightingConfig.for_map(play.lighting, null, map, LightingConfig.DAY)
	var level := MapLevel.new()
	port.add_child(level)
	level.build(map, play.map_style, tuning.body, play.baked_light, sun, false, play.site_look)
	level.set_baked_light(true)
	play.look.push_globals()
	var lighting := FieldLighting.build(sun, play.look)
	lighting.add_probes(map)
	port.add_child(lighting)
	var site := SiteDress.build(map, play.site_look, level.site_material())
	if site != null:
		port.add_child(site)
		SiteDress.dress_sky(lighting, play.site_look)
	var roof := RoofView.build(map, play.roof)
	if roof != null:
		port.add_child(roof)
	var values := GraphicsTable.shared().preset(&"high")
	GraphicsApply.apply(values, port)
	GraphicsApply.apply_field(values, lighting, null, null, level)
	if site != null:
		level.set_detail(values.mesh_detail)
	var camera := Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = play.view.horizontal_fov_16x9
	port.add_child(camera)
	var ground := map.terrain.height_at(spot.x, spot.y) if map.terrain != null else 0.0
	var eye := Vector3(spot.x, ground + tuning.body.stand_eye_height, spot.y)
	camera.global_position = eye
	camera.global_rotation = Vector3(deg_to_rad(spot.w), deg_to_rad(spot.z), 0.0)
	var state := GameState.new(5, tuning)
	var grenades := GrenadeView.new()
	port.add_child(grenades)
	grenades.setup(state.grenades.size(), tuning.grenades, false)
	grenades.setup_arms(play.viewmodel, FigureMix.HUMAN)
	var c := Character.new(0, 0, Vector3(spot.x, ground, spot.y), 0.0, ReplicaStats.default_loadout())
	c.yaw = deg_to_rad(spot.z)
	c.pitch = deg_to_rad(spot.w)
	c.grenades.carry(1, 1)
	var failed := 0
	for figure: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		grenades.set_arms_kind(figure)
		for kind: int in [Grenade.Kind.SMOKE, Grenade.Kind.FLASH]:
			for windup: bool in [false, true]:
				c.grenades.stop()
				if windup:
					c.grenades.throwing = kind
					c.grenades.windup_left = 0.0
				else:
					c.grenades.readied = kind
				grenades.update(state, 0.0, DT, c, eye)
				for i in SETTLE_FRAMES:
					await RenderingServer.frame_post_draw
				var path := "%s/held_%s_%s_%s.jpg" % [folder.trim_suffix("/"), GrenadeView.HOLDS[kind],
						"windup" if windup else "ready", "robot" if figure == FigureMix.ROBOT else "human"]
				if port.get_texture().get_image().save_jpg(path, QUALITY) != OK:
					failed += 1
				print("[render_held_bomb] %s" % path)
	quit(1 if failed > 0 else 0)
