extends SceneTree
## Where bots leave sight in a blink (TV1; dev only, never exported): seeded headless bot matches on a field through
## MatchRunner, every tick, every character. Counts and prints
## - "pop": back in play (a respawn) from anything but out on its dead-zone spot: the figure stood on the field (hit,
##   calling or walking off) and was drawn at its spawn the next frame, with how far from the dead zone it was;
## - "jump": in play on both ticks yet moved further than JUMP m in one (a rescue from under the world, a lift, a
##   vault gone wrong): where and what it was doing;
## - "fade": a walk-off that left the field (Elimination's LEAVING, its figure fading): as its respawn came (TV1), or
##   stuck or out of time (with where); and of those, how many someone in play saw (Respawns.seen) as it began;
## - each respawn: from the dead zone, as its fade ended, or a pop (anything else).
## Measured, never asserted.
##   godot --headless --path . -s res://tools/vanish_probe.gd -- <map id> [seeds] [mode]
## `mode` is "elimination", "flag" (Attack / Defend, the default) or "bomb" (Plant The Bomb).

const MODES: Dictionary[String, RoundState.Mode] = {
	"elimination": RoundState.Mode.ELIMINATION,
	"flag": RoundState.Mode.ATTACK_DEFEND,
	"bomb": RoundState.Mode.PLANT_THE_BOMB,
}
const JUMP := 1.5
const PRINTS := 12
const MAX_MATCH_SECONDS := 600.0

var _runner: MatchRunner = null
var _seed: int = 0
var _status: Array[Character.Status] = []
var _at: PackedVector3Array = PackedVector3Array()
var _counts: Dictionary[String, int] = {}
var _printed: Dictionary[String, int] = {}
var _round: int = -1
var _hits: HitConfig = null
var _ray: RayHit = RayHit.new()


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
	_runner.mode = MODES[mode_name]
	_hits = _runner.tuning.hits
	_runner.each_tick = _each_tick
	for s in range(1, seeds + 1):
		_seed = s
		_status.clear()
		_at.clear()
		_runner.play(s, MAX_MATCH_SECONDS)
	var keys := _counts.keys()
	keys.sort()
	for k: String in keys:
		print("%s %s: %s: %d" % [map_id, mode_name, k, _counts[k]])
	_runner.free_level()
	quit()


func _count(k: String) -> void:
	_counts[k] = _counts.get(k, 0) + 1


## Prints `line` for the first PRINTS of kind `k`.
func _say(k: String, line: String) -> void:
	_printed[k] = _printed.get(k, 0) + 1
	if _printed[k] <= PRINTS:
		print(line)


func _each_tick(state: GameState, _bots: BotController) -> void:
	var n := state.characters.size()
	if _status.size() != n:
		_status.resize(n)
		_at.resize(n)
		for c in state.characters:
			_status[c.id] = c.status
			_at[c.id] = c.position
		return
	# a new round puts everyone back at their spawns: no jump
	var live := state.round_state.is_live() and state.round_state.number == _round
	_round = state.round_state.number
	for c in state.characters:
		var was := _status[c.id]
		var from := _at[c.id]
		_status[c.id] = c.status
		_at[c.id] = c.position
		if not live:
			continue
		var moved := Vector2(c.position.x - from.x, c.position.z - from.z).length()
		if c.status == Character.Status.ALIVE and was != Character.Status.ALIVE:
			if was == Character.Status.OUT:
				_count("respawn from the dead zone")
			elif was == Character.Status.LEAVING:
				_count("respawn as its fade ended")
			else:
				var off := Vector2(from.x - c.dead_zone_target.x, from.z - c.dead_zone_target.z).length()
				_count("pop: respawned while %s" % Character.Status.keys()[was])
				_say("pop", "seed %d t %.1f: #%d respawned while %s at %s, %.0f m short of the dead zone" % [_seed,
						state.time, c.id, Character.Status.keys()[was], from.snapped(Vector3.ONE * 0.1), off])
		elif c.status == Character.Status.ALIVE and was == Character.Status.ALIVE and moved > JUMP:
			_count("jump in play")
			_say("jump", "seed %d t %.1f: #%d jumped %.1f m from %s to %s%s" % [_seed, state.time, c.id, moved,
					from.snapped(Vector3.ONE * 0.1), c.position.snapped(Vector3.ONE * 0.1),
					" (its spawn: a rescue)" if c.position.is_equal_approx(c.spawn_position) else ""])
		elif c.status == Character.Status.LEAVING and was == Character.Status.WALKING_OFF \
				and c.respawn_left >= 0.0 and c.respawn_left <= _hits.vanish_time + 1e-3:
			_count("fade: walk-off left the field as its respawn came")
			if Respawns.seen(c, state.characters, _runner.tuning, _runner.level.query(), _ray):
				_count("fade: ... and someone saw it fade (walked on seen_most)")
		elif c.status == Character.Status.LEAVING and was == Character.Status.WALKING_OFF:
			_count("fade: walk-off left the field, stuck or out of time")
			_say("fade", "seed %d t %.1f: #%d faded walking off at %s, %.0f m short of the dead zone" % [_seed,
					state.time, c.id, c.position.snapped(Vector3.ONE * 0.1),
					Vector2(c.position.x - c.dead_zone_target.x, c.position.z - c.dead_zone_target.z).length()]
					+ ", heading for %s (leg %d of %s)" % [_leg(c), c.walk_off_leg, c.walk_off_route.size()])


## The walk-off waypoints round the one `c` heads for, snapped (or "-" when it has none).
func _leg(c: Character) -> String:
	var r := c.walk_off_route
	if r.is_empty():
		return "-"
	var out := ""
	for i in range(maxi(0, c.walk_off_leg - 1), mini(r.size(), c.walk_off_leg + 2)):
		out += " %s" % r[i].snapped(Vector3.ONE * 0.1)
	return out
