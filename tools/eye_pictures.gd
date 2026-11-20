extends SceneTree
## Renders a field at eye height from named spots, as a match draws it on High by day (its level with its bake, its
## light as the map sets it, its site dress, its roof, its doors and Attack / Defend poles, and an outdoor field's wood,
## bushes and skyline; the eye stands on the ground), to `<folder>/<name>.jpg`: pictures for the owner of a map
## that is being built (DR1). Needs a display, so under xvfb; on Forward+ (Vulkan: lavapipe in the cloud) it draws as
## the game does, where `--rendering-driver opengl3` draws the compatibility renderer's harsher light:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s res://tools/eye_pictures.gd \
##       -- <map id> <folder> <name>:<x>,<z>,<yaw degrees>,<pitch degrees> ...
## Yaw 0 looks along -z (north), 90 along -x (west); pitch is up from level; a fifth number is the floor's height the
## eye stands on (a map built in storeys), else the ground's. An argument `preset=<low|medium|high|ultra>`
## draws that Graphics preset's values (GraphicsApply) instead of High; `fov=<degrees>` a narrower or wider view (the
## range's card is 40); `night` the map's night preset, its lights' pools and fixtures lit (WG4); `fog=<off|on>` the
## Volumetric haze switch over the preset's (VF1, UB3); `measure=<frames>` prints each picture's mean render time
## over that many frames after it settles (the cloud's software Vulkan: a level against another, never a real card's
## milliseconds); `size=<w>x<h>` the pictures' size; `set=<config>.<value>=<number>` one of PlayTuning's configs' values
## for this run (`set=roof.lamp_light_energy=4`: a look tried before it is written into the config); `raw` draws with
## no edge smoothing, as the game's presets do, and writes lossless .png (two pictures a hair apart then show what
## flickers as the eye moves, tools/flicker_map.py). An argument `card`
## writes a map's pictures instead: the loading screen's, drawn at 1920 x 1080
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
## (the eyes adapt, the haze and the screen's bounce light gather).
const GI_SETTLE_FRAMES := 40
const FIRST_SETTLE_FRAMES := 60
## The frames one reflection probe takes to capture (six faces, then its blur's layers), the small picture the eye
## visits every spot on while they all do, and the frames it looks from each spot so the probes in view join the queue
## (`_capture_probes`).
const PROBE_FRAMES := 16
const WARM_SIZE := Vector2i(96, 54)
const WARM_LOOK_FRAMES := 2


func _initialize() -> void:
	_run.call_deferred()


## One `set=<config>.<value>=<number or Godot literal>` applied to `play`'s config of that name (roof, look, lighting,
## night_lighting, site_look, ...), as its own type; "" when done, else what is wrong with it.
static func _change(play: PlayTuning, change: String) -> String:
	var parts := change.split("=")
	var path := parts[0].split(".")
	if parts.size() != 2 or path.size() != 2:
		return "write it <config>.<value>=<number>"
	var target: Variant = play.get(path[0])
	if not (target is Object) or not (path[1] in (target as Object)):
		return "PlayTuning has no %s" % parts[0]
	var config := target as Object
	var value: Variant = str_to_var(parts[1])
	if value == null:
		return "%s is not a value" % parts[1]
	config.set(path[1], type_convert(value, typeof(config.get(path[1]))))
	return ""


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var preset := &"high"
	var card := false
	var night := false
	var fov := FOV
	var fog := ""
	var measure := 0
	var size := SIZE
	var sets := PackedStringArray()
	var smooth := true
	var lossless := false
	for a: String in args.duplicate():
		if a.begins_with("preset="):
			preset = StringName(a.trim_prefix("preset="))
			args.erase(a)
		elif a.begins_with("fov="):
			fov = a.trim_prefix("fov=").to_float()
			args.erase(a)
		elif a.begins_with("fog="):
			fog = a.trim_prefix("fog=")
			args.erase(a)
		elif a.begins_with("measure="):
			measure = a.trim_prefix("measure=").to_int()
			args.erase(a)
		elif a.begins_with("size="):
			var wh := a.trim_prefix("size=").split("x")
			if wh.size() == 2 and wh[0].to_int() > 0 and wh[1].to_int() > 0:
				size = Vector2i(wh[0].to_int(), wh[1].to_int())
			args.erase(a)
		elif a.begins_with("set="):
			sets.append(a.trim_prefix("set="))
			args.erase(a)
		elif a == "card":
			card = true
			args.erase(a)
		elif a == "raw":
			smooth = false
			lossless = true
			args.erase(a)
		elif a == "night":
			night = true
			args.erase(a)
	if args.size() < 3:
		push_error("eye_pictures: give a map id, a folder and at least one name:x,z,yaw,pitch")
		quit(1)
		return
	var play := PlayTuning.load_default()
	for change in sets:
		var problem := _change(play, change)
		if problem != "":
			push_error("eye_pictures: set=%s: %s" % [change, problem])
			quit(1)
			return
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
	port.size = CARD_SIZE if card else size
	port.msaa_3d = MSAA if smooth else Viewport.MSAA_DISABLED
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(port)
	var sun := LightingConfig.for_map(play.lighting, play.night_lighting, map,
			LightingConfig.NIGHT if night else LightingConfig.DAY)
	var level := MapLevel.new()
	port.add_child(level)
	# The lifts and station dress as play_session passes them (PP1: without them Subway drew its greybox).
	level.build(map, play.map_style, tuning.body, play.baked_light, sun, false, play.site_look, tuning.lifts,
			play.station_look)
	level.set_baked_light(true)
	play.look.push_globals()
	var lighting := FieldLighting.build(sun, play.look)
	# Underground (UL1: no sky in the ambient light or the reflections), as a match lights it.
	lighting.set_underground(map.roof_underground)
	lighting.add_probes(map)
	port.add_child(lighting)
	var site := SiteDress.build(map, play.site_look, level.site_material(), play.skyline)
	if site != null:
		port.add_child(site)
		level.set_detail(GraphicsQuality.MeshDetail.HIGH)
		SiteDress.dress_sky(lighting, play.site_look)
	var roof := RoofView.build(map, play.roof)
	if roof != null:
		port.add_child(roof)
	# An outdoor field's props, wood and bushes as a match draws them on High (WR3: Woodland's pictures).
	add_woods(port, map, play, level.station_material() != null)
	# What its lights stand on or hang from (WG4), and with `night` their pools of light.
	var fixtures := LightFixtures.build(map, play.light_fixtures, sun)
	if fixtures != null:
		port.add_child(fixtures)
	# A station's lamps and extras (SM5: Subway's signs, posters, clocks, tunnel lamps).
	var station_fixtures := StationFixtures.build(map, play.station_fixtures)
	if station_fixtures != null:
		port.add_child(station_fixtures)
	var pools := LightPools.build(map, sun)
	if pools != null:
		port.add_child(pools)
	var skyline := SkylineView.build(map, play.skyline, play.lighting, tuning.body.stand_eye_height)
	if skyline != null:
		port.add_child(skyline)
	# Its doors, shut, and its Attack / Defend poles, as a match of that mode draws them (BP7: the shared light).
	var doors := DoorView.build(map, play.map_style, tuning.doors.swing_time)
	if doors != null:
		port.add_child(doors)
	# Its lifts' cars at their start stops, doors open (MT2), as a match begins.
	var lifts := LiftView.build(map, play.map_style, tuning.lifts, play.lifts)
	if lifts != null:
		port.add_child(lifts)
	# Its ticket gates' paddles, shut, as a match begins with nobody at them (SM3).
	var paddles := GatePaddles.build(map, play.gate_paddles)
	if paddles != null:
		port.add_child(paddles)
	# Its small fittings along the walls, floors and ceilings (SD2).
	var detail := StationDetail.build(map, play.station_detail)
	if detail != null:
		port.add_child(detail)
	var teams := TeamColours.resolve(TeamColours.Set.STANDARD, false, null, play.teams).figures
	var poles: Array[FlagView] = []
	for i in map.poles.size():
		var pole := FlagView.new()
		pole.setup(play.flag, teams, map.poles[i], tuning.flag.radius, Flag.LETTERS[i] if map.poles.size() > 1 else "",
				map.pole_height)
		port.add_child(pole)
		poles.append(pole)
	if not map.targets.is_empty():
		add_range(port, play, tuning, map)
	var values := GraphicsTable.shared().preset(preset)
	if fog != "":
		var fog_level := GraphicsTable.shared().level_of(GraphicsQuality.VOLUMETRIC_FOG, fog)
		if fog_level == GraphicsTable.NO_LEVEL:
			push_error("eye_pictures: fog=%s is not off or on" % fog)
			quit(1)
			return
		values.volumetric_fog = fog_level as GraphicsQuality.VolumetricFog
	GraphicsApply.apply(values, port)
	# The roof's lamps as real lights where the preset lights them (Lamp light, UG1), the sun dimmed as a match does.
	GraphicsApply.apply_field(values, lighting, null, null, level, null, null,
			roof.lamp_lights() if roof != null else null)
	# A station's tunnel lamps and its lift cars' lamps and probes, as the preset lights them in a match (TB2, MT2).
	GraphicsApply.apply_station(values, lifts, station_fixtures)
	if site != null:
		level.set_detail(values.mesh_detail)
	# The doors, poles, gate paddles and a site's props and stencils in the baked light near them, as a match draws them (BP7).
	var lights := level.baked_lights()
	if doors != null:
		doors.relight(lights)
	if paddles != null:
		paddles.relight(lights)
	for pole in poles:
		pole.relight(lights)
	if site != null:
		site.relight(lights)
	print("[eye_pictures] drawn on %s%s" % [preset, " fog=%s" % fog if fog != "" else ""])
	if measure > 0:
		RenderingServer.viewport_set_measure_render_time(port.get_viewport_rid(), true)
	var camera := Camera3D.new()
	camera.fov = fov
	port.add_child(camera)
	await _capture_probes(port, camera, args.slice(2), map, tuning)
	var failed := 0
	for spec in args.slice(2):
		var parts := spec.split(":")
		if not _stand(camera, spec, map, tuning):
			push_error("eye_pictures: %s is not name:x,z,yaw,pitch[,floor]" % spec)
			failed += 1
			continue
		var settle := GI_SETTLE_FRAMES if values.global_illumination == GraphicsQuality.GlobalIllumination.SCENE \
				else SETTLE_FRAMES
		if failed == 0 and spec == args[2]:
			settle = maxi(settle, FIRST_SETTLE_FRAMES)
		for i in settle:
			await RenderingServer.frame_post_draw
		if measure > 0:
			var gpu := 0.0
			var cpu := 0.0
			for i in measure:
				await RenderingServer.frame_post_draw
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(port.get_viewport_rid())
				cpu += RenderingServer.viewport_get_measured_render_time_cpu(port.get_viewport_rid())
			print("[eye_pictures] %s render gpu %.2f ms cpu %.2f ms (mean of %d)" % [parts[0], gpu / measure,
					cpu / measure, measure])
		var path := "%s/%s.%s" % [args[1].trim_suffix("/"), parts[0], "png" if lossless else "jpg"]
		var image := port.get_texture().get_image()
		if card:
			image = card_cut(image)
		var written := image.save_png(path) if lossless else image.save_jpg(path, CARD_QUALITY if card else QUALITY)
		if written != OK:
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


## Stands `camera` at `spec` (name:x,z,yaw,pitch[,floor]) on `map`, at a standing eye's height; false for a spec that
## is not one.
static func _stand(camera: Camera3D, spec: String, map: MapData, tuning: SimTuning) -> bool:
	var parts := spec.split(":")
	var at := parts[1].split_floats(",") if parts.size() == 2 else PackedFloat64Array()
	if at.size() != 4 and at.size() != 5:
		return false
	var ground := map.terrain.height_at(at[0], at[1]) if map.terrain != null else 0.0
	if at.size() == 5:
		ground = at[4]
	camera.global_position = Vector3(at[0], ground + tuning.body.stand_eye_height, at[1])
	camera.global_rotation = Vector3(deg_to_rad(at[3]), deg_to_rad(at[2]), 0.0)
	return true


## Waits for the field's reflection probes before the first picture. The engine captures a probe only once a camera
## has had its box in view, one probe at a time over about PROBE_FRAMES frames each, and until then draws its area
## with no bounce light: a wall drew black in a run's first picture and lit in its third, and a hall seen only from
## the third spot on drew dark throughout (BP9). So the eye visits every spot on a small picture (cheap), then waits
## for every probe shown; a preset that draws none (Low) waits for nothing.
func _capture_probes(port: SubViewport, camera: Camera3D, spots: PackedStringArray, map: MapData,
		tuning: SimTuning) -> void:
	var probes := 0
	for probe in port.find_children("*", "ReflectionProbe", true, false):
		if (probe as ReflectionProbe).is_visible_in_tree():
			probes += 1
	if probes == 0:
		return
	var size := port.size
	port.size = WARM_SIZE
	for spec in spots:
		if _stand(camera, spec, map, tuning):
			for i in WARM_LOOK_FRAMES:
				await RenderingServer.frame_post_draw
	for i in probes * PROBE_FRAMES:
		await RenderingServer.frame_post_draw
	port.size = size
	print("[eye_pictures] %d probes captured" % probes)


## The map's wood as a match draws it on High by day (WoodsView: crowns, the forest, tufts, puddles and the floor), its
## bushes (BushView) and, with no site dress, its CC0 props (PropDress, WR3) in their paints, each if it has them; on
## a station (`station`) only the models its blocks name (SD1), as PlaySession dresses it (not yet its trains, SM1).
static func add_woods(port: Node, map: MapData, play: PlayTuning, station: bool = false) -> void:
	var cfg := play.site_look.props.named_only() if station else play.site_look.props
	var props := PropDress.build(map, cfg, play.site_look.prop_paint) if map.site == null else null
	if props != null:
		port.add_child(props)
	var woods := WoodsView.build(map, play.woods, play.skyline, play.lighting, play.map_style)
	if woods != null:
		port.add_child(woods)
		woods.set_quality(GraphicsQuality.MeshDetail.HIGH, 0.0)
	var bushes := BushView.build(map, play.woods, SimTuning.load_default().ballistics.leaf_fern_tallest)
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
