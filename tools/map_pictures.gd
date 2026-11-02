extends SceneTree
## Renders the practice range from its firing line with its targets and markings standing and its skyline (WL4, WL5,
## RG4), to assets/maps/range.jpg (its card on the Match page, the menus' backdrop and the loading
## screen's). Needs a display and OpenGL, so under xvfb:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tools/map_pictures.gd
## Arguments after `--`: an output folder (default assets/maps/) and an optional map id to render alone. A map that
## can't load is skipped with its reasons.
## A field's card is a photo-mode view from a player's eye height, never from above (owner, 2026-11-02, UR2): an
## eye-height render from tools/eye_pictures.gd, cut to 700 x 400, from the spot its record names (docs/records/UR2.md),
## so this skips every field.

## The picture's size (px) and its JPEG quality.
const SIZE := Vector2i(700, 400)
const QUALITY := 0.85
const OUT_DIR := "res://assets/maps/"
## The range's picture: the camera stands at the firing line's spawn at eye height looking downrange, this wide
## (degrees, vertical) and tipped down this far (degrees), so the card's crop (a 420x400 window of the 700x400 picture)
## keeps the lanes' middle with the floor under it.
const RANGE_FOV := 40.0
const RANGE_PITCH := 8.0
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
	play.look.push_globals()
	var tuning := SimTuning.load_default()
	var failed := 0
	for entry in MapCatalog.shared().listed(true):
		if not only.is_empty() and entry.id != only:
			continue
		var map := MapData.load_map(entry.id, play.map_style, MatchOptions.check_size(entry, tuning.rounds.team_size))
		if not map.ok():
			print("[map_pictures] %s skipped: %s" % [entry.id, "; ".join(map.problems)])
			continue
		if entry.kind != &"range":
			# a field's card is an eye-height view, never from above (owner, 2026-11-02): tools/eye_pictures.gd draws it
			print("[map_pictures] %s skipped: a field, its card comes from eye_pictures" % entry.id)
			continue
		var image: Image = await _render_range(map, play, tuning)
		var path := "%s/%s.jpg" % [dir.trim_suffix("/"), entry.id]
		if image == null or image.save_jpg(path, QUALITY) != OK:
			push_error("map_pictures: %s could not be written" % path)
			failed += 1
			continue
		print("[map_pictures] %s -> %s" % [entry.id, path])
	quit(1 if failed > 0 else 0)


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
	var lighting := FieldLighting.build(play.lighting, play.look)
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
