extends SceneTree
## Renders each match field from a high three-quarter camera, and the practice range from its firing line with its
## targets and markings standing, each with its skyline and a wood and bushes its dressing (WL4, WL5), to
## assets/maps/<id>.jpg (the Match page's map cards and the loading screen's backdrop, MN2 and RG4). Needs a display
## and OpenGL, so under xvfb:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/map_pictures.gd
## Arguments after `--`: an output folder (default assets/maps/) and an optional map id to render alone. A map that
## can't load is skipped with its reasons.
## A roofed map (Depot) is skipped: a roof hides it from above, so its card is an eye-height render from
## tools/eye_pictures.gd, cut to 700 x 400.

## The picture's size (px) and its JPEG quality.
const SIZE := Vector2i(700, 400)
const QUALITY := 0.85
const OUT_DIR := "res://assets/maps/"
## The camera: how high it looks down from (degrees above the ground), which corner it stands at (degrees round from
## +z), its vertical field of view, and how much of the frame the field may fill.
const ELEVATION := 58.0
const AZIMUTH := 205.0
const FOV := 32.0
const FILL := 0.97
## The range's picture: the camera stands at the firing line's spawn at eye height looking downrange, this wide
## (degrees, vertical) and tipped down this far (degrees), so the card's crop (a 420x400 window of the 700x400 picture)
## keeps the lanes' middle with the floor under it.
const RANGE_FOV := 40.0
const RANGE_PITCH := 8.0
## The camera then moves in to this share of the distance that fits the field, so it fills the frame and the card's
## crop (the Match page shows a 420x400 window of it) takes only the far corners.
const CLOSER := 0.88
const MSAA := Viewport.MSAA_4X
## Frames drawn before the picture is taken, so the shadows and the sky are settled.
const SETTLE_FRAMES := 4


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else OUT_DIR
	var only := args[1] if args.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(dir)
	var play := PlayTuning.load_default()
	var tuning := SimTuning.load_default()
	var failed := 0
	for entry in MapCatalog.shared().listed(true):
		if not only.is_empty() and entry.id != only:
			continue
		var map := MapData.load_map(entry.id, play.map_style, MatchOptions.check_size(entry, tuning.rounds.team_size))
		if not map.ok():
			print("[map_pictures] %s skipped: %s" % [entry.id, "; ".join(map.problems)])
			continue
		if map.roof_height > 0.0:
			# a roof hides the field from above: its card is drawn inside, at eye height, with tools/eye_pictures.gd
			print("[map_pictures] %s skipped: roofed, its card comes from eye_pictures" % entry.id)
			continue
		var image: Image = null
		if entry.kind == &"range":
			image = await _render_range(map, play, tuning)
		else:
			image = await _render(map, play)
		var path := "%s/%s.jpg" % [dir.trim_suffix("/"), entry.id]
		if image == null or image.save_jpg(path, QUALITY) != OK:
			push_error("map_pictures: %s could not be written" % path)
			failed += 1
			continue
		print("[map_pictures] %s -> %s" % [entry.id, path])
	quit(1 if failed > 0 else 0)


## One field drawn from above and to a side; null when nothing was drawn.
func _render(map: MapData, play: PlayTuning) -> Image:
	var port := SubViewport.new()
	port.size = SIZE
	port.msaa_3d = MSAA
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(port)
	var level := MapLevel.new()
	port.add_child(level)
	var body := SimTuning.load_default().body
	level.build(map, play.map_style, body, null, null, false, play.site_look)
	var lighting := FieldLighting.build(play.lighting)
	port.add_child(lighting)
	_add_site(port, map, play, level, lighting)
	_add_skyline(port, map, play, body)
	add_woods(port, map, play)
	var camera := Camera3D.new()
	camera.fov = FOV
	port.add_child(camera)
	_frame(camera, map)
	for i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	var image := port.get_texture().get_image()
	port.queue_free()
	return image


## The range seen from where you start: its level, lighting, markings and targets, nothing else; null when nothing was
## drawn.
func _render_range(map: MapData, play: PlayTuning, tuning: SimTuning) -> Image:
	var port := SubViewport.new()
	port.size = SIZE
	port.msaa_3d = MSAA
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(port)
	var level := MapLevel.new()
	port.add_child(level)
	level.build(map, play.map_style, tuning.body, null, null, false, play.site_look)
	var lighting := FieldLighting.build(play.lighting)
	port.add_child(lighting)
	_add_site(port, map, play, level, lighting)
	_add_skyline(port, map, play, tuning.body)
	var font := GameTheme.font(800)
	var marks := RangeView.new()
	port.add_child(marks)
	marks.setup(play.range_view, tuning.targets, font)
	var targets := RangeTargets.create(map.targets, tuning)
	var view := RangeTargetsView.new()
	port.add_child(view)
	view.setup(targets, play.range_view, tuning, font)
	view.update(targets, 1.0, 0.0)
	var camera := Camera3D.new()
	camera.fov = RANGE_FOV
	port.add_child(camera)
	var spawn := map.ends[0].spawns[0]
	camera.global_position = spawn.position + Vector3.UP * tuning.body.stand_eye_height
	camera.global_rotation = Vector3(-deg_to_rad(RANGE_PITCH), spawn.yaw, 0.0)
	for i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	var image := port.get_texture().get_image()
	port.queue_free()
	return image


## The map's site dress as a match draws it on High by day (SiteDress: details, bags, stencils, its sky), if it has one.
func _add_site(port: SubViewport, map: MapData, play: PlayTuning, level: MapLevel, lighting: FieldLighting) -> void:
	var site := SiteDress.build(map, play.site_look, level.site_material())
	if site != null:
		port.add_child(site)
		level.set_detail(GraphicsQuality.MeshDetail.HIGH)
		SiteDress.dress_sky(lighting, play.site_look)


## The map's skyline as a match draws it, smoke and all (SkylineView), if it has one.
func _add_skyline(port: SubViewport, map: MapData, play: PlayTuning, body: BodyConfig) -> void:
	var skyline := SkylineView.build(map, play.skyline, play.lighting, body.stand_eye_height)
	if skyline != null:
		port.add_child(skyline)
		skyline.set_smoke(true)


## The map's wood as a match draws it on High by day (WoodsView: crowns, the forest, tufts, puddles and the floor), its
## bushes (BushView) and, with no site dress, its CC0 props (PropDress, WR3), each if it has them.
static func add_woods(port: Node, map: MapData, play: PlayTuning) -> void:
	var props := PropDress.build(map, play.site_look.props) if map.site == null else null
	if props != null:
		port.add_child(props)
	var woods := WoodsView.build(map, play.woods, play.skyline, play.lighting, play.map_style)
	if woods != null:
		port.add_child(woods)
		woods.set_quality(GraphicsQuality.MeshDetail.HIGH, 0.0)
	var bushes := BushView.build(map, play.woods)
	if bushes != null:
		port.add_child(bushes)


## Places `camera` to look at the middle of the map's blocks from far enough back that every corner of their box
## sits inside FILL of the frame, then CLOSER.
func _frame(camera: Camera3D, map: MapData) -> void:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for b in map.blocks:
		lo = lo.min(b.center - b.size * 0.5)
		hi = hi.max(b.center + b.size * 0.5)
	var middle := (lo + hi) * 0.5
	var toward := Vector3.FORWARD.rotated(Vector3.RIGHT, -deg_to_rad(ELEVATION)).rotated(Vector3.UP,
			deg_to_rad(AZIMUTH))
	var basis := Basis.looking_at(toward, Vector3.UP)
	var tan_v := tan(deg_to_rad(FOV) * 0.5)
	var tan_h := tan_v * float(SIZE.x) / float(SIZE.y)
	var back := 0.0
	for i in 8:
		var corner := Vector3(hi.x if i & 1 else lo.x, hi.y if i & 2 else lo.y, hi.z if i & 4 else lo.z) - middle
		var local := basis.inverse() * corner
		# a point is `depth` ahead of a camera `back` behind the middle: depth = back - local.z
		back = maxf(back, absf(local.x) / (FILL * tan_h) + local.z)
		back = maxf(back, absf(local.y) / (FILL * tan_v) + local.z)
	camera.global_transform = Transform3D(basis, middle - toward * back * CLOSER)
