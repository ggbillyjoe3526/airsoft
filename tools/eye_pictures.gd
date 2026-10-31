extends SceneTree
## Renders a field at eye height from named spots, as a match draws it on High by day (its level with its bake, its
## light as the map sets it, its site dress, its roof, and an outdoor field's wood, bushes and skyline; the eye stands
## on the ground), to `<folder>/<name>.jpg`: pictures for the owner of a map
## that is being built (DR1). Needs a display and OpenGL, so under xvfb:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 -s res://tools/eye_pictures.gd \
##       -- <map id> <folder> <name>:<x>,<z>,<yaw degrees>,<pitch degrees> ...
## Yaw 0 looks along -z (north), 90 along -x (west); pitch is up from level. An argument `preset=<low|medium|high|ultra>`
## draws that Graphics preset's values (GraphicsApply) instead of High. Dev only: tools/ never ships.

const SIZE := Vector2i(1600, 900)
const QUALITY := 0.9
const FOV := 75.0
const MSAA := Viewport.MSAA_4X
const SETTLE_FRAMES := 6
## Frames to settle under the whole scene's bounce light (SDFGI converges over about 30) and before the first picture
## (the reflection probes capture once, a face a frame).
const GI_SETTLE_FRAMES := 40
const FIRST_SETTLE_FRAMES := 60


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var preset := &"high"
	for a in args.duplicate():
		if a.begins_with("preset="):
			preset = StringName(a.trim_prefix("preset="))
			args.erase(a)
	if args.size() < 3:
		push_error("eye_pictures: give a map id, a folder and at least one name:x,z,yaw,pitch")
		quit(1)
		return
	var play := PlayTuning.load_default()
	var tuning := SimTuning.load_default()
	var map := MapData.load_map(args[0], play.map_style, tuning.rounds.team_size)
	if not map.ok():
		push_error("eye_pictures: %s refused: %s" % [args[0], "; ".join(map.problems)])
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(args[1])
	var port := SubViewport.new()
	port.size = SIZE
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
	if site == null:
		var props := PropDress.build(map, play.site_look.props)
		if props != null:
			port.add_child(props)
	var roof := RoofView.build(map, play.roof)
	if roof != null:
		port.add_child(roof)
	# An outdoor field's wood, bushes and skyline as a match draws them on High (WR3: Woodland's pictures).
	var woods := WoodsView.build(map, play.woods, play.skyline, play.lighting, play.map_style)
	if woods != null:
		port.add_child(woods)
		woods.set_quality(GraphicsQuality.MeshDetail.HIGH, 0.0)
	var bushes := BushView.build(map, play.woods)
	if bushes != null:
		port.add_child(bushes)
	var skyline := SkylineView.build(map, play.skyline, play.lighting, tuning.body.stand_eye_height)
	if skyline != null:
		port.add_child(skyline)
	var values := GraphicsTable.shared().preset(preset)
	GraphicsApply.apply(values, port)
	GraphicsApply.apply_field(values, lighting, null, null, level)
	if site != null:
		level.set_detail(values.mesh_detail)
	print("[eye_pictures] drawn on %s" % preset)
	var camera := Camera3D.new()
	camera.fov = FOV
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
		if port.get_texture().get_image().save_jpg(path, QUALITY) != OK:
			push_error("eye_pictures: %s could not be written" % path)
			failed += 1
			continue
		print("[eye_pictures] %s" % path)
	quit(1 if failed > 0 else 0)
