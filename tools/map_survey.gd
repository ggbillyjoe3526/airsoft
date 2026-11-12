extends SceneTree
## A field's survey (MB1; dev only, never exported): every place a player can stand, one a `step` square on each
## floor, with what stands open to it and how far each end walks to it, written as one JSON file tools/maps/report.py
## reads and tools/maps/heat.py draws. Measured on the game's own level, nav grid and sight ray (FieldMeasure), doors
## as a round starts them. Measured, never asserted: no check runs it.
##   godot --headless --path . -s res://tools/map_survey.gd -- <map id> <out.json> [step m]
## For every stand point: how many of the others within the bots' sight see it standing eye to standing eye
## (`seen`), how many standing eyes see the middle of a body crouched there (`seen_low`), its longest clear line (`longest`, m),
## and each end's walk to it from its first spawn (`walk0`, `walk1`, m; -1 where there is no way).

const STEP := 1.0
## How far a point is looked at from on a map that names no bot sight (m).
const REACH := 55.0
## A crouched body's middle over the floor (m): what a standing eye must see to hit someone crouched behind cover.
const LOW_BODY := 0.6


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("map_survey.gd needs: <map id> <out.json> [step m]")
		quit(2)
		return
	var step := args[2].to_float() if args.size() > 2 and args[2].is_valid_float() else STEP
	var runner := MatchRunner.new(root, args[0])
	await physics_frame
	await physics_frame
	if not runner.map.problems.is_empty():
		push_error("%s: %s" % [args[0], ", ".join(runner.map.problems)])
		quit(1)
		return
	var measure := FieldMeasure.new(runner.map, runner.nav, runner.level.query(), runner.tuning.body)
	var points := measure.stand_points(step)
	var n := points.size()
	var reach: float = runner.map.bot_sight if runner.map.bot_sight > 0.0 else REACH
	var seen := PackedInt32Array()
	var seen_low := PackedInt32Array()
	var longest := PackedFloat32Array()
	seen.resize(n)
	seen_low.resize(n)
	longest.resize(n)
	var started := Time.get_ticks_msec()
	var rays := 0
	for i in n:
		var a := points[i]
		for j in range(i + 1, n):
			var b := points[j]
			var d := Vector2(a.x - b.x, a.z - b.z).length()
			if d > reach:
				continue
			rays += 1
			if measure.sees(a, b, measure.stand_eye, measure.stand_eye):
				seen[i] += 1
				seen[j] += 1
				longest[i] = maxf(longest[i], d)
				longest[j] = maxf(longest[j], d)
	# A standing eye on a crouched body is not the same line both ways: every ordered pair.
	for i in n:
		var a := points[i]
		for j in n:
			if i == j:
				continue
			var b := points[j]
			if Vector2(a.x - b.x, a.z - b.z).length() > reach:
				continue
			if measure.sees(a, b, measure.stand_eye, LOW_BODY):
				seen_low[j] += 1
	print("%s: %d points, %d pairs, sight in %.0f s" % [args[0], n, rays, (Time.get_ticks_msec() - started) / 1000.0])
	started = Time.get_ticks_msec()
	var walks: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
	for end in 2:
		walks[end].resize(n)
		var from := runner.map.ends[end].spawns[0].position
		for i in n:
			var w := measure.walk(from, points[i])
			walks[end][i] = -1.0 if is_inf(w) else snappedf(w, 0.1)
	print("%s: walks in %.0f s" % [args[0], (Time.get_ticks_msec() - started) / 1000.0])
	var flat := PackedFloat32Array()
	for p in points:
		flat.append(snappedf(p.x, 0.01))
		flat.append(snappedf(p.y, 0.01))
		flat.append(snappedf(p.z, 0.01))
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	if file == null:
		push_error("can't write %s" % args[1])
		quit(1)
		return
	file.store_string(JSON.stringify({
		"map": args[0], "step": step, "reach": reach, "points": flat, "seen": seen, "seen_low": seen_low,
		"longest": longest, "walk0": walks[0], "walk1": walks[1],
	}))
	file.close()
	runner.free_level()
	quit()
