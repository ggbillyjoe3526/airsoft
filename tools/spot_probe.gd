extends SceneTree
## Scratch probe (WS1 thread, not committed): Spotted's outcome for every enemy in a clear line of view, and bots that
## stand still a long time, over seeded headless matches.
##   godot --headless --path . -s res://tools/spot_probe.gd -- <map id> [seeds] [mode]

const MODES: Dictionary[String, RoundState.Mode] = {
	"elimination": RoundState.Mode.ELIMINATION,
	"flag": RoundState.Mode.ATTACK_DEFEND,
	"bomb": RoundState.Mode.PLANT_THE_BOMB,
}
## Enemies further off than this (m) are left out.
const RANGE := 80.0
## Probed every this many ticks, and a bot standing still this long (s, within STILL_REACH m) is printed.
const EVERY := 30
const STILL_TIME := 12.0
const STILL_REACH := 0.5
const MAX_MATCH_SECONDS := 600.0

var _runner: MatchRunner = null
var _tick: int = 0
var _hit := RayHit.new()
var _counts: Dictionary[String, int] = {}
var _last_pos: Dictionary[int, Vector3] = {}
var _still_since: Dictionary[int, float] = {}
var _reported: Dictionary[int, bool] = {}
var _map: MapData = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var map_id := args[0]
	var seeds := args[1].to_int() if args.size() > 1 else 2
	var mode_name := args[2] if args.size() > 2 else "flag"
	_runner = MatchRunner.new(root, map_id, MatchRunner.sized_for(map_id, null, 0))
	await physics_frame
	await physics_frame
	_map = _runner.map
	_runner.mode = MODES[mode_name]
	_runner.each_tick = _each_tick
	for s in range(1, seeds + 1):
		_last_pos.clear()
		_still_since.clear()
		_reported.clear()
		_runner.play(s, MAX_MATCH_SECONDS)
	var keys := _counts.keys()
	keys.sort()
	for k: String in keys:
		print("%s: %d" % [k, _counts[k]])
	_runner.free_level()
	quit()


func _count(k: String) -> void:
	_counts[k] = _counts.get(k, 0) + 1


func _each_tick(state: GameState, bots: BotController) -> void:
	_tick += 1
	if not state.round_state.is_live():
		_last_pos.clear()
		_still_since.clear()
		return
	var w := bots.world
	var tuning := w.tuning
	for c in state.characters:
		if not Elimination.is_in_play(c):
			continue
		var last: Vector3 = _last_pos.get(c.id, Vector3.INF)
		if last.distance_to(c.position) > STILL_REACH:
			_last_pos[c.id] = c.position
			_still_since[c.id] = state.time
		elif state.time - _still_since.get(c.id, state.time) > STILL_TIME and not _reported.has(c.id):
			_reported[c.id] = true
			var b := _bot_of(w, c)
			var note := ""
			if b != null:
				note = "mode %s stuck_for %.1f route %s leg %d/%d goal %s move %s lane %d hunting %s target %d vis %s t %.0f" % [
						Bot.Mode.keys()[b.mode], b.stuck_for, Bot.RouteState.keys()[b.route_state], b.route_leg,
						b.route.size(), b.route_goal, b.move_dir, b.lane, b.hunting, b.target_id, b.target_visible,
						state.time]
			print("STILL id %d team %d at %s for %.0f s, %s, blocks: %s" % [c.id, c.team, c.position, STILL_TIME, note,
					_blocks_near(c.position, 0.6)])
		var inside := _blocks_near(c.position + Vector3.UP * 1.0, 0.0)
		if inside != "":
			_count("inside block " + inside)
	if _tick % EVERY != 0:
		return
	for v in state.characters:
		if not Elimination.is_in_play(v):
			continue
		var eye := Lean.eye(v, tuning.body, tuning.hits)
		for t in state.characters:
			if t.team == v.team or not Elimination.is_in_play(t):
				continue
			var chest := BotSenses.body_point(t, tuning.hits, w.cfg.aim_height_fraction)
			var d := eye.distance_to(chest)
			if d > RANGE:
				continue
			if w.query.sight_ray(eye, chest, _hit):
				continue
			var dir := (chest - eye) / d
			var yaw := v.yaw
			v.yaw = atan2(-dir.x, -dir.z)
			var reach := tuning.pings.reach
			if w.query.sight_ray(eye, eye + dir * reach, _hit):
				reach = _hit.fraction * reach
			var got := bots.pings.enemy_under_view(v, eye, dir, reach, tuning.pings.spot_cone_deg, w)
			var band := "near" if d < 20.0 else ("mid" if d < 40.0 else "far")
			if got == t:
				_count("spot ok " + band)
			elif got != null:
				_count("spot other " + band)
			else:
				var why := ""
				if not BotSenses.leaves_clear(w, eye, chest) and d > w.cfg.close_awareness:
					why = "leaves"
				elif d > reach:
					why = "reach"
				elif BotSenses.visible_part(v, t, w, tuning.pings.reach) == 0.0:
					why = "visible_part other"
					if v.dazzle_left > 0.0:
						why = "dazzled"
					elif not BotSenses.smoke_clear(w, eye, chest):
						why = "smoke"
				else:
					why = "cone"
				_count("spot FAIL %s %s" % [band, why])
			v.yaw = yaw


func _bot_of(w: BotWorld, c: Character) -> Bot:
	for b in w.bots:
		if b.character == c:
			return b
	return null


func _blocks_near(p: Vector3, pad: float) -> String:
	var out := PackedStringArray()
	for b in _map.blocks:
		var box := AABB(b.center - b.size * 0.5, b.size).grow(pad)
		if box.has_point(p) and b.kind != &"floor":
			out.append("%s%s" % [b.kind, (":" + b.dress) if b.dress != &"" else ""])
	return ",".join(out)
