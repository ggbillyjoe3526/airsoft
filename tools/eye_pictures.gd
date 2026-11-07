extends SceneTree
## Renders a field at eye height from named spots, as a match draws it on High by day (its level with its bake, its
## light as the map sets it, its site dress, its roof, its doors and Attack / Defend poles, and an outdoor field's wood,
## bushes and skyline; the eye stands on the ground), to `<folder>/<name>.jpg`: pictures for the owner of a map
## that is being built (DR1). Needs a display, so under xvfb; on Forward+ (Vulkan: lavapipe in the cloud) it draws as
## the game does, where `--rendering-driver opengl3` draws the compatibility renderer's harsher light:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s res://tools/eye_pictures.gd \
##       -- <map id> <folder> <name>:<x>,<z>,<yaw degrees>,<pitch degrees> ...
## Yaw 0 looks along -z (north), 90 along -x (west); pitch is up from level. An argument `preset=<low|medium|high|ultra>`
## draws that Graphics preset's values (GraphicsApply) instead of High; `fov=<degrees>` a narrower or wider view (the
## range's card is 40). An argument `card` writes a map's pictures instead: the loading screen's, drawn at 1920 x 1080
## (BP7 row 93: it draws it full screen), and beside it in `cards/` the Match page's and the menus' backdrop's copy at
## THUMB_SIZE (BP7: the page shows all four at once, so it holds the small ones), each at the map
## pictures' quality (UR2; the spots are in docs/ASSETS.md). The range stands its targets and markings (RangeView,
## RangeTargetsView) as you start it. Dev only: tools/ never ships.

const SIZE := Vector2i(1600, 900)
const QUALITY := 0.9
const FOV := 75.0
const MSAA := Viewport.MSAA_4X
const SETTLE_FRAMES := 6
## `card`: a map's picture, its size (px: a full screen's) and JPEG quality.
const CARD_SIZE := Vector2i(1920, 1080)
const CARD_QUALITY := 0.85
## `card`: the Match page's copy (px): its cards draw at most about 272 x 152 (136 x 76 at 1080p, twice that at 4K).
const THUMB_SIZE := Vector2i(480, 270)
## Frames to settle under the whole scene's bounce light (SDFGI converges over about 30) and before the first picture
## (the reflection probes capture once, a face a frame).
const GI_SETTLE_FRAMES := 40
const FIRST_SETTLE_FRAMES := 60


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var preset := &"high"
	var card := false
	var fov := FOV
	for a: String in args.duplicate():
		if a.begins_with("preset="):
			preset = StringName(a.trim_prefix("preset="))
			args.erase(a)
		elif a.begins_with("fov="):
			fov = a.trim_prefix("fov=").to_float()
			args.erase(a)
		elif a == "card":
			card = true
			args.erase(a)
	if args.size() < 3:
		push_error("eye_pictures: give a map id, a folder and at least one name:x,z,yaw,pitch")
		quit(1)
		return
	var play := PlayTuning.load_default()
	var tuning := SimTuning.load_default()
	var entry := MapCatalog.shared().find(args[0])
	var team := MatchOptions.check_size(entry, tuning.rounds.team_size) if entry != null else tuning.rounds.team_size
	var map := MapData.load_map(args[0], play.map_style, team)
	if not map.ok():
		push_error("eye_pictures: %s refused: %s" % [args[0], "; ".join(map.problems)])
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(args[1])
	var port := SubViewport.new()
	port.size = CARD_SIZE if card else SIZE
	port.msaa_3d = MSAA
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
		level.set_detail(GraphicsQuality.MeshDetail.HIGH)
		SiteDress.dress_sky(lighting, play.site_look)
	var roof := RoofView.build(map, play.roof)
	if roof != null:
		port.add_child(roof)
	# An outdoor field's props, wood and bushes as a match draws them on High (WR3: Woodland's pictures).
	add_woods(port, map, play)
	var skyline := SkylineView.build(map, play.skyline, play.lighting, tuning.body.stand_eye_height)
	if skyline != null:
		port.add_child(skyline)
	# Its doors, shut, and its Attack / Defend poles, as a match of that mode draws them (BP7: the shared light).
	var doors := DoorView.build(map, play.map_style, tuning.doors.swing_time)
	if doors != null:
		port.add_child(doors)
	var teams := TeamColours.resolve(TeamColours.Set.STANDARD, false, null, play.teams).figures
	var poles: Array[FlagView] = []
	for i in map.poles.size():
		var pole := FlagView.new()
		pole.setup(play.flag, teams, map.poles[i], tuning.flag.radius, Flag.LETTERS[i] if map.poles.size() > 1 else "")
		port.add_child(pole)
		poles.append(pole)
	if not map.targets.is_empty():
		add_range(port, play, tuning, map)
	var values := GraphicsTable.shared().preset(preset)
	GraphicsApply.apply(values, port)
	GraphicsApply.apply_field(values, lighting, null, null, level)
	if site != null:
		level.set_detail(values.mesh_detail)
	# The doors, poles and a site's props in the baked light near them, as a match draws them (BP7).
	var lights := level.baked_lights()
	if doors != null:
		doors.relight(lights)
	for pole in poles:
		pole.relight(lights)
	if site != null and site.props() != null:
		site.props().relight(lights)
	print("[eye_pictures] drawn on %s" % preset)
	var camera := Camera3D.new()
	camera.fov = fov
	port.add_child(camera)
	var failed := 0
	for spec in args.slice(2):
		var parts := spec.split(":")
		var at := parts[1].split_floats(",") if parts.size() == 2 else PackedFloat64Array()
		if at.size() != 4:
			push_error("eye_pictures: %s is not name:x,z,yaw,pitch" % spec)
			failed += 1
			continue
		var ground := map.terrain.height_at(at[0], at[1]) if map.terrain != null else 0.0
		camera.global_position = Vector3(at[0], ground + tuning.body.stand_eye_height, at[1])
		camera.global_rotation = Vector3(deg_to_rad(at[3]), deg_to_rad(at[2]), 0.0)
		var settle := GI_SETTLE_FRAMES if values.global_illumination == GraphicsQuality.GlobalIllumination.SCENE \
				else SETTLE_FRAMES
		if failed == 0 and spec == args[2]:
			settle = maxi(settle, FIRST_SETTLE_FRAMES)
		for i in settle:
			await RenderingServer.frame_post_draw
		var path := "%s/%s.jpg" % [args[1].trim_suffix("/"), parts[0]]
		var image := port.get_texture().get_image()
		if card:
			image = card_cut(image)
		if image.save_jpg(path, CARD_QUALITY if card else QUALITY) != OK:
			push_error("eye_pictures: %s could not be written" % path)
			failed += 1
			continue
		print("[eye_pictures] %s" % path)
		if card:
			var thumb_path := "%s/cards/%s.jpg" % [args[1].trim_suffix("/"), parts[0]]
			DirAccess.make_dir_recursive_absolute(thumb_path.get_base_dir())
			if thumb(image).save_jpg(thumb_path, CARD_QUALITY) != OK:
				push_error("eye_pictures: %s could not be written" % thumb_path)
				failed += 1
				continue
			print("[eye_pictures] %s" % thumb_path)
	quit(1 if failed > 0 else 0)


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


## The range's markings and its targets standing, as you start it (RangeView, RangeTargetsView).
static func add_range(port: Node, play: PlayTuning, tuning: SimTuning, map: MapData) -> void:
	var font := GameTheme.font(800)
	var marks := RangeView.new()
	port.add_child(marks)
	marks.setup(play.range_view, tuning.targets, font)
	var targets := RangeTargets.create(map.targets, tuning)
	var view := RangeTargetsView.new()
	port.add_child(view)
	view.setup(targets, play.range_view, tuning, font)
	view.update(targets, 1.0, 0.0)


## A render cut from its centre to CARD_SIZE's shape and scaled to it: a map's picture.
## A map's picture scaled to THUMB_SIZE: the Match page's copy.
static func thumb(image: Image) -> Image:
	var small := image.duplicate() as Image
	small.resize(THUMB_SIZE.x, THUMB_SIZE.y, Image.INTERPOLATE_LANCZOS)
	return small


static func card_cut(image: Image) -> Image:
	var aspect := float(CARD_SIZE.x) / CARD_SIZE.y
	var w := mini(image.get_width(), roundi(image.get_height() * aspect))
	var h := mini(image.get_height(), roundi(w / aspect))
	var cut := image.get_region(Rect2i((image.get_width() - w) / 2, (image.get_height() - h) / 2, w, h))
	cut.resize(CARD_SIZE.x, CARD_SIZE.y, Image.INTERPOLATE_LANCZOS)
	return cut
