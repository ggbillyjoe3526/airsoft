extends SceneTree
## The maps' play record (MB1; dev only, never exported): seeded headless bot matches on a field through MatchRunner,
## writing where every character stood (once a second while a round is live, by the END it started the round at),
## where every knock-out's shooter and target stood, and how every round ended, as one JSON file tools/maps/heat.py
## draws as heat maps and tools/maps/report.py reads. Measured, never asserted: no check runs it.
##   godot --headless --path . -s res://tools/map_heat.gd -- <map id> <out.json> [seeds] [mode] [size] [first seed]
## `mode` is "elimination" (the default) or "flag" (Attack / Defend); `size` the players a side (the map's standard
## by default).

## Match time a match may take (s), as the balance report allows.
const MAX_MATCH_SECONDS := 30.0 * 60.0
## Positions are written to this many metres.
const QUANTUM := 0.25

var _runner: MatchRunner = null
var _stood: PackedFloat32Array = PackedFloat32Array()
var _hits: PackedFloat32Array = PackedFloat32Array()
var _round_start: float = 0.0
var _tick: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("map_heat.gd needs: <map id> <out.json> [seeds] [mode] [size] [first seed]")
		quit(2)
		return
	var map_id := args[0]
	var seeds := args[2].to_int() if args.size() > 2 and args[2].is_valid_int() else 4
	var flag := args.size() > 3 and args[3] == "flag"
	var size := args[4].to_int() if args.size() > 4 and args[4].is_valid_int() else 0
	var first := args[5].to_int() if args.size() > 5 and args[5].is_valid_int() else 1
	_runner = MatchRunner.new(root, map_id, MatchRunner.sized_for(map_id, null, size))
	await physics_frame
	await physics_frame
	if not _runner.map.problems.is_empty():
		push_error("%s: %s" % [map_id, ", ".join(_runner.map.problems)])
		quit(1)
		return
	_runner.mode = RoundState.Mode.ATTACK_DEFEND if flag else RoundState.Mode.ELIMINATION
	_runner.each_tick = _each_tick
	var rounds: Array[Dictionary] = []
	var started := Time.get_ticks_msec()
	for seed_value in range(first, first + seeds):
		_round_start = 0.0
		_tick = 0
		var tally := _runner.play(seed_value, MAX_MATCH_SECONDS)
		for r in tally.rounds:
			rounds.append({
				"seed": seed_value, "winner": r.winner, "reason": r.reason, "seconds": snappedf(r.seconds, 0.1),
				"alpha_end": r.alpha_end, "attackers": r.attackers, "top_flag": snappedf(r.top_flag, 0.01),
				"first_hit_time": snappedf(r.first_hit_time, 0.1), "first_hit_range": snappedf(r.first_hit_range, 0.1),
				"overtime": r.overtime,
			})
	print("%s, %s: %d matches in %.0f s" % [map_id, "Attack / Defend" if flag else "Elimination", seeds,
			(Time.get_ticks_msec() - started) / 1000.0])
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	if file == null:
		push_error("can't write %s" % args[1])
		quit(1)
		return
	file.store_string(JSON.stringify({
		"map": map_id, "mode": "flag" if flag else "elimination", "seeds": seeds,
		"size": _runner.tuning.rounds.team_size,
		# Each sample: end, x, y, z, seconds into the round.
		"stood": _stood,
		# Each knock-out: the shooter's end, its x, y, z, the target's x, y, z, seconds into the round.
		"hits": _hits,
		"rounds": rounds,
	}))
	file.close()
	_runner.free_level()
	quit()


## After every tick: the round's start noted, the knock-outs written, and once a second everyone in play.
func _each_tick(state: GameState, _bots: BotController) -> void:
	_tick += 1
	for i in state.events.count:
		var e := state.events.items[i]
		if e.kind == GameEvent.Kind.ROUND_START:
			_round_start = state.time
		elif e.kind == GameEvent.Kind.CHARACTER_HIT:
			var shooter := state.character(e.actor)
			var target := state.character(e.target)
			if shooter == null or target == null or shooter.team == target.team:
				continue
			_hits.append(float(shooter.end))
			_put(_hits, shooter.position)
			_put(_hits, target.position)
			_hits.append(snappedf(state.time - _round_start, 0.1))
	if _tick % MatchRunner.TICKS_PER_SECOND != 0 or not state.round_state.is_live():
		return
	for c in state.characters:
		if not Elimination.is_in_play(c):
			continue
		_stood.append(float(c.end))
		_put(_stood, c.position)
		_stood.append(snappedf(state.time - _round_start, 0.1))


static func _put(into: PackedFloat32Array, at: Vector3) -> void:
	into.append(snappedf(at.x, QUANTUM))
	into.append(snappedf(at.y, QUANTUM))
	into.append(snappedf(at.z, QUANTUM))
