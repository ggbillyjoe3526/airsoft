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
## wall ray, FB5's before).

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


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var perf := args.has("--perf")
	var far := args.has("--far") or perf
	var seconds := SECONDS
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
	field.add_child(FieldLighting.build(play.lighting, play.look))
	var spawn := map.ends[0].spawns[0]
	var eye := spawn.position + Vector3.UP * tuning.body.stand_eye_height if far else \
			Vector3.UP * tuning.body.stand_eye_height
	var camera := Camera3D.new()
	field.add_child(camera)
	camera.global_position = eye
	camera.global_rotation = Vector3(0.0, spawn.yaw if far else 0.0, 0.0)
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
		var c := Character.new(i + 1, team, _loop_centre(i), 0.0, ReplicaStats.default_loadout())
		c.grounded = true
		cast.append(c)
		var v := FigureView.new()
		field.add_child(v)
		v.thrown = thrown
		v.setup(c, Color.RED if team == 0 else Color.BLUE, tuning.hits, font, false, [], 0.0,
				play.figures)
		v.set_body(models, kinds[i + 1], play.figures.lod_high)
		if not args.has("--no-raise"):
			v.set_world(level.query(), tuning.body)
		views.append(v)
	var built := Time.get_ticks_usec() - build_start
	var frames := int(seconds / TICK)
	var animation := PackedFloat64Array()
	var skeleton := PackedFloat64Array()
	var frame := PackedFloat64Array()
	var last := Time.get_ticks_usec()
	var t := 0.0
	for n in frames + WARM_FRAMES:
		t += TICK
		for i in FIGURES:
			_script(cast[i], i, t, tuning.hits)
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
		last = now
	print("[figure_bench] %d figures, %d frames (%.0f s), models %.1f ms, set_body %.1f ms, eye %s" % [FIGURES,
			frames, seconds, loaded / 1000.0, built / 1000.0, "at the spawn" if far else "in the middle"])
	_report("animation per figure (us)", animation)
	_report("skeleton per figure (us)", skeleton)
	_report("both, 11 figures (ms)", _sum_scaled(animation, skeleton, FIGURES / 1000.0))
	if perf:
		_report("frame (ms)", _scaled(frame, 0.001))
	field.queue_free()
	await process_frame
	quit(0)


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
