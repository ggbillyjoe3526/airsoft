extends SceneTree
## The team-size bench (TS1; dev only, never exported): a whole PlaySession on each field at 5v5 to 8v8, a bot playing
## you (the smoke test's autopilot) so all of them fight, stepped by hand one tick and one rendered frame at a time
## (60 fps), timing the tick (the bots think, the simulation steps, everything follows it) and the frame's own work (the
## views: figures, BBs, puffs, sound, HUD). Headless there is no GPU: the draw's cost is the owner's to measure in a
## window (figure_bench.gd --perf). Logs the mean, 95th and 99th percentile and worst of each, per map and size, and
## how many frames' tick and views together took over Low's whole frame (LOW_FRAME_MS).
##   godot --headless --path . -s res://tools/team_bench.gd
## Arguments after `--`: `--seconds N` (match time measured, default 120), `--maps a,b` and `--sizes 5,8` (default
## every field and 5 to 8), `--seed N` (default 1).

const SECONDS := 120.0
## Match time not counted at the start (the first frames' loads and the bots leaving their spawns).
const WARM_SECONDS := 5.0
const MAPS: Array[String] = ["depot", "woodland"]
const SIZES: Array[int] = [5, 6, 7, 8]
## Low's frame at 60 fps (ms): a frame whose CPU work alone takes longer drops a frame whatever the GPU.
const LOW_FRAME_MS := 1000.0 / 60.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds := _arg_float(args, "--seconds", SECONDS)
	var maps: Array[String] = MAPS.duplicate()
	var at := args.find("--maps")
	if at >= 0 and at + 1 < args.size():
		maps.assign(args[at + 1].split(",", false))
	var sizes: Array[int] = SIZES.duplicate()
	at = args.find("--sizes")
	if at >= 0 and at + 1 < args.size():
		sizes.clear()
		for s in args[at + 1].split(",", false):
			sizes.append(s.to_int())
	var seed_value := roundi(_arg_float(args, "--seed", 1.0))
	PlayTuning.load_default().look.push_globals()
	print("team_bench: %d s of match time a run, ms (mean / p95 / p99 / worst)" % roundi(seconds))
	for map_id in maps:
		for size in sizes:
			await _bench(map_id, size, seed_value, seconds)
	quit()


func _bench(map_id: String, size: int, seed_value: int, seconds: float) -> void:
	var custom := CustomRules.new()
	custom.team_size = size
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.map_id = map_id
	session.match_seed = seed_value
	session.custom_rules = custom
	session.autopilot = true
	root.add_child(session)
	if session.state == null:
		push_error("team_bench: %s refused" % map_id)
		session.free()
		return
	await process_frame
	session.set_physics_process(false)
	session.set_process(false)
	var warm := roundi(WARM_SECONDS / PlaySession.TICK)
	var count := roundi(seconds / PlaySession.TICK)
	var ticks := PackedFloat64Array()
	var frames := PackedFloat64Array()
	ticks.resize(count)
	frames.resize(count)
	var players := session.state.characters.size()
	for i in warm + count:
		var t0 := Time.get_ticks_usec()
		session._physics_process(PlaySession.TICK)
		var t1 := Time.get_ticks_usec()
		session._process(PlaySession.TICK)
		var t2 := Time.get_ticks_usec()
		if i >= warm:
			ticks[i - warm] = (t1 - t0) / 1000.0
			frames[i - warm] = (t2 - t1) / 1000.0
	var both := PackedFloat64Array()
	both.resize(count)
	var over := 0
	for i in count:
		both[i] = ticks[i] + frames[i]
		if both[i] > LOW_FRAME_MS:
			over += 1
	print("%-9s %dv%d (%2d players): tick %s | frame %s | both %s | over %.1f ms: %d of %d" % [map_id, size, size,
			players, _stats(ticks), _stats(frames), _stats(both), LOW_FRAME_MS, over, count])
	session.free()
	await process_frame


func _stats(values: PackedFloat64Array) -> String:
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for v in sorted:
		total += v
	var n := sorted.size()
	return "%5.2f / %5.2f / %5.2f / %6.2f" % [total / maxf(n, 1.0), sorted[int(n * 0.95)], sorted[int(n * 0.99)],
			sorted[n - 1]]


func _arg_float(args: PackedStringArray, flag: String, fallback: float) -> float:
	var at := args.find(flag)
	return args[at + 1].to_float() if at >= 0 and at + 1 < args.size() else fallback
