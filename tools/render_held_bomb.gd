extends SceneTree
## Pictures of your arms holding and throwing a smoke or flash bomb in first person (GT2, GT3), for review: a field drawn
## at eye height on High by day (as tools/eye_pictures.gd draws it), the bomb in hand as a match draws it (GrenadeView
## with your arms), readied in hand and at each of STEPS through the throw (ArmsThrow's share: 0..1 the windup, 1..2 the
## recovery), for each kind and figure kind, to `<folder>/held_<kind>_<step>_<figure>.jpg`; with `clip` after the spot,
## every frame of a throw instead, to `<folder>/clip_<kind>_<figure>_<frame>.jpg` (for a moving picture); with
## `cut<share>` (as `cut0.8`), every frame of a throw cut off at that share (a hit in its windup) and the hand going
## down, to `<folder>/cut_<kind>_<figure>_<frame>.jpg`. Needs a display and OpenGL, so under xvfb:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 -s res://tools/render_held_bomb.gd \
##       -- <folder> [<map id> <x>,<z>,<yaw degrees>,<pitch degrees> [clip|cut<share>]]
## Dev only: tools/ never ships.

const SIZE := Vector2i(1600, 900)
const QUALITY := 0.9
const SETTLE_FRAMES := 40
const DT := 1.0 / 60.0
const MAP := "depot"
const SPOT := Vector4(0.0, 0.0, -90.0, 2.0)
## The throw's steps pictured (ArmsThrow's share; 0 readied in hand), and the frames a clip holds before and after one.
const STEPS: Array[float] = [0.0, 0.15, 0.3, 0.45, 0.72, 0.86, 0.97, 1.3]
const CLIP_LEAD := 12


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if not args.is_empty() else "user://held_bomb"
	var map_id := args[1] if args.size() > 2 else MAP
	var spot := SPOT
	var clip := args.size() > 3 and args[3] == "clip"
	var cut := args[3].trim_prefix("cut").to_float() if args.size() > 3 and args[3].begins_with("cut") else 0.0
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
		var dress := "robot" if figure == FigureMix.ROBOT else "human"
		for kind: int in [Grenade.Kind.SMOKE, Grenade.Kind.FLASH]:
			var id: String = GrenadeView.HOLDS[kind]
			if cut > 0.0:
				failed += await _cut(port, grenades, state, c, eye, kind, tuning.grenades, play.viewmodel, cut,
						"%s/cut_%s_%s" % [folder.trim_suffix("/"), id, dress])
				continue
			if clip:
				failed += await _clip(port, grenades, state, c, eye, kind, tuning.grenades,
						"%s/clip_%s_%s" % [folder.trim_suffix("/"), id, dress])
				continue
			for step in STEPS:
				_ready(c, kind)
				for i in SETTLE_FRAMES:
					grenades.update(state, 0.0, DT, c, eye)
				_at(c, kind, step, tuning.grenades)
				grenades.update(state, 0.0, DT, c, eye)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var path := "%s/held_%s_%03d_%s.jpg" % [folder.trim_suffix("/"), id, roundi(step * 100.0), dress]
				failed += _save(port, path)
		if clip or cut > 0.0:
			break
	quit(1 if failed > 0 else 0)


## Every frame of a throw of `kind` from the hand, CLIP_LEAD frames of the bomb readied first, to `<stem>_<frame>.jpg`.
func _clip(port: SubViewport, grenades: GrenadeView, state: GameState, c: Character, eye: Vector3, kind: int,
		cfg: GrenadeConfig, stem: String) -> int:
	_ready(c, kind)
	for i in SETTLE_FRAMES:
		grenades.update(state, 0.0, DT, c, eye)
	await RenderingServer.frame_post_draw
	var failed := 0
	var frame := 0
	var share := 0.0
	var step := DT / cfg.windup
	while share < 2.0 + CLIP_LEAD * DT / cfg.recover:
		if frame >= CLIP_LEAD:
			share += step if share < 1.0 else DT / cfg.recover
		_at(c, kind, minf(share, 2.0), cfg)
		if share >= 2.0:
			c.grenades.stop()
		grenades.update(state, 0.0, DT, c, eye)
		await RenderingServer.frame_post_draw
		failed += _save(port, "%s_%03d.jpg" % [stem, frame])
		frame += 1
	return failed


## Every frame of a throw of `kind` from the hand cut off (`c` stopped, as a hit does) `cut` of the way through its
## windup, CLIP_LEAD frames of the bomb readied first, until the hand has gone down and CLIP_LEAD frames on, to
## `<stem>_<frame>.jpg`.
func _cut(port: SubViewport, grenades: GrenadeView, state: GameState, c: Character, eye: Vector3, kind: int,
		cfg: GrenadeConfig, view_cfg: ViewModelConfig, cut: float, stem: String) -> int:
	_ready(c, kind)
	for i in SETTLE_FRAMES:
		grenades.update(state, 0.0, DT, c, eye)
	await RenderingServer.frame_post_draw
	var failed := 0
	var frame := 0
	var share := 0.0
	var after := 0
	var down := ceili(view_cfg.bomb_raise_time / DT) + CLIP_LEAD
	while after < down:
		if frame >= CLIP_LEAD and share < cut:
			share = minf(share + DT / cfg.windup, cut)
			_at(c, kind, share, cfg)
		elif share >= cut:
			c.grenades.stop()
			after += 1
		grenades.update(state, 0.0, DT, c, eye)
		await RenderingServer.frame_post_draw
		failed += _save(port, "%s_%03d.jpg" % [stem, frame])
		frame += 1
	return failed


## `c` with a bomb of `kind` readied in hand.
static func _ready(c: Character, kind: int) -> void:
	c.grenades.stop()
	c.grenades.readied = kind


## `c` `share` of the way through a throw of `kind` (0: readied in hand).
static func _at(c: Character, kind: int, share: float, cfg: GrenadeConfig) -> void:
	if share <= 0.0:
		return
	c.grenades.readied = Grenade.Kind.NONE
	c.grenades.throwing = kind
	c.grenades.released = share >= 1.0
	c.grenades.windup_left = cfg.windup * (1.0 - minf(share, 1.0))
	c.grenades.recover_left = cfg.recover * (2.0 - maxf(share, 1.0))


static func _save(port: SubViewport, path: String) -> int:
	print("[render_held_bomb] %s" % path)
	return 1 if port.get_texture().get_image().save_jpg(path, QUALITY) != OK else 0
