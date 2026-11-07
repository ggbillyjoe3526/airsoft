extends SceneTree
## The rigged figures' bench (step 23, FI7; dev only, never exported): 11 figures, a 6v6's other players, on Depot for
## 30 s, each walking its own loop, aiming up and down, firing, reloading and calling a hit in turn, scripted (no
## simulation, so the numbers are the figures' own). Headless it logs, per figure a frame, the animation time (FigureView's
## `update` and `animate`: the pose, the tree's parameters and its advance, the wall ray of FB5) and the skeleton time
## (each skeleton's update: the bones, FigureBend and the hands); with `--perf`, run in a window on the owner's PC, it
## draws the field from the Alpha spawn and logs the frame time too.
##   godot --headless --path . -s res://tools/figure_bench.gd
##   godot --path . -s res://tools/figure_bench.gd -- --perf
## Arguments after `--`: `--perf`, `--seconds N` (default 30), `--far` (the eye at the Alpha spawn headless too, so the
## far figures take far_stride; by default it stands in the middle, every figure posed every frame), `--no-raise` (no
## wall ray, FB5's before), `--zoom N` (the detail lines at N times, as through an N x scope: FigureConfig.zoomed_lines;
## with `--perf` it logs the frame's draws and primitives too), `--contact` (the contact shadows on, as on Low, and the
## time of their ground rays a tick, FigureView.on_tick, logged on its own: BP7), `--cone` (with `--zoom`, a scope's glass
## camera along the eye's view, a quarter of the screen tall over the zoom: only the figures it may show keep the zoomed
## lines, FigureView.fit_zoomed_lines, timed a frame and the figures it zooms counted: BP7), `--night` (the night preset,
## each figure carrying the weapon torch on both replicas as a bot does at night: BP7 row 69). Every run logs the mesh
## surfaces the figures draw (each shown mesh's surfaces, shadows not counted: the draws they ask for, headless too).

const FIGURES := 11
const SECONDS := 30.0
const TICK := 1.0 / 60.0
## Where the figures walk: a 4 × 3 grid of loops over the field's middle (m), each loop this wide, at the walk pace.
const GRID := Vector2(30.0, 18.0)
const LOOP_RADIUS := 2.5
const PACE := 2.6
## Each figure's turns: a reload every RELOAD_EVERY s, a hit called every CALL_EVERY s (held CALL_HOLD s), a shot every
## SHOT_EVERY s between them, the aim swinging ±PITCH rad over PITCH_PERIOD s; staggered by id.
const RELOAD_EVERY := 7.0
const CALL_EVERY := 11.0
const CALL_HOLD := 2.0
const SHOT_EVERY := 0.3
const PITCH := 0.5
const PITCH_PERIOD := 4.0
## The frames not counted at the start (models, materials and the first poses settling).
const WARM_FRAMES := 30
## `--cone`'s glass: its picture's side (px) and its share of the screen's height, as ViewModelConfig glass_share.
const CONE_PICTURE := 512
const CONE_SHARE := 0.25


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var perf := args.has("--perf")
	var far := args.has("--far") or perf
	var seconds := SECONDS
	var zoom := 1.0
	var zoom_at := args.find("--zoom")
	if zoom_at >= 0 and zoom_at + 1 < args.size():
		zoom = args[zoom_at + 1].to_float()
	var at := args.find("--seconds")
	if at >= 0 and at + 1 < args.size():
		seconds = args[at + 1].to_float()
	var play := PlayTuning.load_default()
	play.look.push_globals()
	var tuning := SimTuning.load_default()
	var map := MapData.load_map("depot", play.map_style, tuning.rounds.team_size)
	if not map.ok():
		push_error("figure_bench: Depot refused: %s" % "; ".join(map.problems))
		quit(1)
		return
	var field := Node3D.new()
	root.add_child(field)
	var level := MapLevel.new()
	field.add_child(level)
	level.build(map, play.map_style, tuning.body)
	var night := args.has("--night")
	field.add_child(FieldLighting.build(play.night_lighting if night else play.lighting, play.look))
	var torch := Torch.Light.new()
	torch.key = &"weaponTorch"
	var lights: Array[Torch.Light] = []
	if night:
		lights.assign([torch, torch])
	var spawn := map.ends[0].spawns[0]
	var eye := spawn.position + Vector3.UP * tuning.body.stand_eye_height if far else \
			Vector3.UP * tuning.body.stand_eye_height
	var camera := Camera3D.new()
	field.add_child(camera)
	camera.global_position = eye
	camera.global_rotation = Vector3(0.0, spawn.yaw if far else 0.0, 0.0)
	var view_lines := play.figures.zoomed_lines(GraphicsQuality.MeshDetail.HIGH, zoom)
	var plain_lines := play.figures.zoomed_lines(GraphicsQuality.MeshDetail.HIGH, 1.0)
	var glass: Camera3D = null
	if args.has("--cone") and zoom > 1.0:
		var port := SubViewport.new()
		port.size = Vector2i(CONE_PICTURE, CONE_PICTURE)
		port.render_target_update_mode = SubViewport.UPDATE_DISABLED
		field.add_child(port)
		glass = Camera3D.new()
		glass.keep_aspect = Camera3D.KEEP_HEIGHT
		port.add_child(glass)
		glass.fov = rad_to_deg(2.0 * atan(CONE_SHARE * tan(deg_to_rad(camera.fov) * 0.5) / zoom))
		glass.transform = camera.global_transform
	var load_start := Time.get_ticks_usec()
	var models := FigureModels.new(play.figures)
	models.load_kinds()
	var loaded := Time.get_ticks_usec() - load_start
	var thrown := ThrownMagazines.new()
	thrown.setup(play.figures.thrown_max)
	field.add_child(thrown)
	var font := GameTheme.font(800)
	var cast: Array[Character] = []
	var views: Array[FigureView] = []
	var kinds := FigureMix.pick(1, _teams(), true, play.figures.robot_salt)
	var build_start := Time.get_ticks_usec()
	for i in FIGURES:
		var team := i % 2
		var loadout := ReplicaStats.default_loadout()
		var c := Character.new(i + 1, team, _loop_centre(i), 0.0, loadout)
		c.grounded = true
		cast.append(c)
		var v := FigureView.new()
		field.add_child(v)
		v.thrown = thrown
		v.setup(c, Color.RED if team == 0 else Color.BLUE, tuning.hits, font, false,
				FigureView.with_lights([] as Array[Dictionary], lights, loadout.size()), 0.0, play.figures)
		v.set_body(models, kinds[i + 1], view_lines)
		if not args.has("--no-raise"):
			v.set_world(level.query(), tuning.body)
		if args.has("--contact"):
			v.add_contact_shadow(FigureView.contact_mesh(play.effects), play.effects)
			v.set_contact_shadow(true)
		views.append(v)
	var built := Time.get_ticks_usec() - build_start
	var frames := int(seconds / TICK)
	var animation := PackedFloat64Array()
	var skeleton := PackedFloat64Array()
	var frame := PackedFloat64Array()
	var ground := PackedFloat64Array()
	var fit := PackedFloat64Array()
	var zoomed := PackedFloat64Array()
	var surfaces := PackedFloat64Array()
	var last := Time.get_ticks_usec()
	var t := 0.0
	for n in frames + WARM_FRAMES:
		t += TICK
		for i in FIGURES:
			_script(cast[i], i, t, tuning.hits)
		var g0 := Time.get_ticks_usec()
		for i in FIGURES:
			views[i].on_tick(cast[i])
		var g1 := Time.get_ticks_usec()
		var f0 := Time.get_ticks_usec()
		if glass != null:
			FigureView.fit_zoomed_lines(views, glass, view_lines, plain_lines, play.figures)
		var f1 := Time.get_ticks_usec()
		var a0 := Time.get_ticks_usec()
		for i in FIGURES:
			views[i].update(cast[i], 1.0, TICK)
			views[i].animate(cast[i], 1.0, TICK, eye)
			if _shot_due(i, t) and not cast[i].armament.reloading():
				views[i].on_shot()
		var a1 := Time.get_ticks_usec()
		for v in views:
			if v.body() != null and v.body().skeleton != null:
				v.body().skeleton.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)
		var a2 := Time.get_ticks_usec()
		thrown.update(TICK)
		await process_frame
		var now := Time.get_ticks_usec()
		if n >= WARM_FRAMES:
			animation.append(float(a1 - a0) / FIGURES)
			skeleton.append(float(a2 - a1) / FIGURES)
			frame.append(float(now - last))
			ground.append(float(g1 - g0))
			fit.append(float(f1 - f0))
			var n_zoomed := 0
			for v in views:
				n_zoomed += 1 if v.lod_lines() == view_lines else 0
			zoomed.append(float(n_zoomed))
			surfaces.append(float(_surfaces(field, camera.global_position)))
		last = now
	print("[figure_bench] %d figures, %d frames (%.0f s), models %.1f ms, set_body %.1f ms, eye %s, lines x%.1f, %s" % [
			FIGURES, frames, seconds, loaded / 1000.0, built / 1000.0, "at the spawn" if far else "in the middle", zoom,
			"night, torches lit" if night else "day"])
	var merged := models.merged_bytes()
	print("[figure_bench] merged body meshes: %d, %d bytes" % [merged.x, merged.y])
	if perf:
		print("[figure_bench] last frame: %d draws, %d primitives" % [
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	_report("animation per figure (us)", animation)
	_report("skeleton per figure (us)", skeleton)
	_report("both, 11 figures (ms)", _sum_scaled(animation, skeleton, FIGURES / 1000.0))
	_report("mesh surfaces the figures draw", surfaces)
	if args.has("--contact"):
		_report("contact shadow rays, 11 figures a tick (us)", ground)
	if glass != null:
		_report("glass cone fit, 11 figures a frame (us)", fit)
		_report("figures on the zoomed lines", zoomed)
	if perf:
		_report("frame (ms)", _scaled(frame, 0.001))
	field.queue_free()
	await process_frame
	quit(0)


## The mesh surfaces drawn under the figures (each FigureView's shown meshes inside their visibility range from `eye`):
## the draws they ask for, without the shadow passes'. A bench's count, allocating a little.
static func _surfaces(field: Node, eye: Vector3) -> int:
	var n := 0
	for v in field.get_children():
		if not v is FigureView:
			continue
		for m: Node in (v as Node).find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			var d := eye.distance_to(mi.global_position)
			if d < mi.visibility_range_begin or (mi.visibility_range_end > 0.0 and d > mi.visibility_range_end):
				continue
			n += mi.mesh.get_surface_count()
	return n


## Team of each character (you on Alpha, five teammates, six on Beta), as FigureMix wants them.
static func _teams() -> PackedInt32Array:
	var teams := PackedInt32Array([0])
	for i in FIGURES:
		teams.append(i % 2)
	return teams


static func _loop_centre(i: int) -> Vector3:
	var col := i % 4
	var row := i / 4
	return Vector3(-GRID.x * 0.5 + GRID.x * col / 3.0, 0.0, -GRID.y * 0.5 + GRID.y * row / 2.0)


static func _shot_due(i: int, t: float) -> bool:
	return fposmod(t + i * 0.07, SHOT_EVERY) < TICK


## Figure `i` at `t` s: on its loop (stood still while calling), aiming by the swing, reloading and calling in turn.
static func _script(c: Character, i: int, t: float, hits: HitConfig) -> void:
	c.prev_position = c.position
	c.prev_yaw = c.yaw
	c.prev_pitch = c.pitch
	c.prev_walk_cycle = c.walk_cycle
	var into_call := fposmod(t + i * 0.9, CALL_EVERY)
	var calling := into_call < CALL_HOLD
	c.status = Character.Status.CALLING if calling else Character.Status.ALIVE
	c.status_time = into_call if calling else 0.0
	var angle := (t + i) * PACE / LOOP_RADIUS * (1.0 if i % 2 == 0 else -1.0)
	if not calling:
		var centre := _loop_centre(i)
		c.position = centre + Vector3(cos(angle), 0.0, sin(angle)) * LOOP_RADIUS
	c.velocity = (c.position - c.prev_position) / TICK
	var flat := Vector2(c.velocity.x, c.velocity.z)
	if flat.length() > 0.01:
		c.yaw = atan2(-flat.x, -flat.y)
	c.pitch = sin(TAU * (t + i * 0.3) / PITCH_PERIOD) * PITCH
	Hitbox.step_walk_cycle(c, hits)
	var a := c.armament
	var reload_time := a.replicas[a.active].reload_time
	var into_reload := fposmod(t + i * 0.6, RELOAD_EVERY)
	a.reload_left = maxf(0.0, reload_time - into_reload) if not calling else 0.0


static func _report(label: String, values: PackedFloat64Array) -> void:
	if values.is_empty():
		return
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for x in values:
		total += x
	print("[figure_bench] %s: mean %.3f, p50 %.3f, p99 %.3f, max %.3f" % [label, total / values.size(),
			sorted[sorted.size() / 2], sorted[mini(sorted.size() - 1, int(sorted.size() * 0.99))], sorted[-1]])


static func _scaled(values: PackedFloat64Array, by: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for x in values:
		out.append(x * by)
	return out


static func _sum_scaled(a: PackedFloat64Array, b: PackedFloat64Array, by: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for i in a.size():
		out.append((a[i] + b[i]) * by)
	return out
