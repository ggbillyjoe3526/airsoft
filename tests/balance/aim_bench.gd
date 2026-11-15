extends SceneTree
## The bot aim bench (AIM1), dev only: one bot holding still in the open against you behind a wall corner on a flat
## field, at 10, 20 and 30 m, at each level. You step out and stand for a moment, step out again soon after ducking
## back, or run or sprint across a gap between two walls. Each case runs over many seeds and writes how often the bot
## hit you, and how long it took from the moment it could first see you to its first fire and its first hit. Measured,
## never asserted. Arguments after `--`: the report's path, the trial count (200 by default) and "old" to play without
## picking someone up again (BotConfig.reacquire_after off: how bots aimed before AIM1).
## Run: godot --headless --path . -s res://tests/balance/aim_bench.gd -- "$PWD/pipeline/out/aim-bench.md" 200

const DT := 1.0 / 60.0
const LEVELS: Array[StringName] = [&"easy", &"normal", &"hard"]
const DISTANCES: Array[float] = [10.0, 20.0, 30.0]
## How long you stand out in the open (s), in the step-out cases.
const EXPOSURES: Array[float] = [0.25, 0.4, 0.6, 1.0]
## The step-out-again case: out this long, back behind the wall this long, then out this long again (s).
const REPEEK_FIRST := 0.4
const REPEEK_GAPS: Array[float] = [0.5, 1.0, 2.0]
const REPEEK_SECOND := 0.4
## Long enough after you are back in cover for a BB already in the air to land (s).
const FLIGHT_GRACE := 0.8
## Where you hide and where you step out to, x along the line across the bot's view (m), at the target's distance.
const HIDE_X := -1.0
const OUT_X := 0.8
## The gap you cross runs between the two walls' inner edges (m).
const GAP_FROM := -0.2
const GAP_TO := 3.8
const RUN_SPEED := 4.2
const SPRINT_SPEED := 6.3
## Seconds hidden after the round goes live before you move.
const SETTLE := 1.0
## The field: a strip from behind the bot's spawn to past yours (m).
const FIELD_WIDTH := 24.0
const FIELD_DEPTH := 70.0
const FIELD_CENTRE_Z := -20.0

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var _fields: Dictionary[float, Array] = {}


class Tally:
	extends RefCounted
	var trials: int = 0
	var hits: int = 0
	var fired: int = 0
	var to_fire: PackedFloat32Array = PackedFloat32Array()
	var to_hit: PackedFloat32Array = PackedFloat32Array()
	var seen_for: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else "user://aim-bench.md"
	var trials := args[1].to_int() if args.size() > 1 and args[1].is_valid_int() else 200
	if args.size() > 2 and args[2] == "old":
		config.reacquire_after = INF
	var lines := PackedStringArray(["# Bot aim bench (AIM1)", "",
			"One bot (AEG Rifle, from the hip, held still in the open, looking down the field) against you behind a"
			+ " wall corner, %d seeds a case. Hit: share of trials the bot hit you. Fire and hit: median seconds from"
			% trials + " the first moment it could see you (Fresh) to its first trigger pull and first hit, over the"
			+ " trials it did.", ""])
	for d in DISTANCES:
		lines.append("## %d m" % roundi(d))
		lines.append("")
		lines.append("| Case | " + " | ".join(LEVELS.map(func(l: StringName) -> String: return String(l))) + " |")
		lines.append("|---|" + "---|".repeat(LEVELS.size()))
		for h in EXPOSURES:
			_row(lines, "Step out %.2f s" % h, d, trials, func(t: float) -> float: return OUT_X if t < h else HIDE_X,
					h + FLIGHT_GRACE)
		_row(lines, "Stand out 3 s", d, trials, func(t: float) -> float: return OUT_X if t < 3.0 else HIDE_X, 3.0)
		for g in REPEEK_GAPS:
			var second := REPEEK_FIRST + g
			_row(lines, "Again after %.1f s (2nd only)" % g, d, trials, func(t: float) -> float:
					return OUT_X if t < REPEEK_FIRST or (t >= second and t < second + REPEEK_SECOND) else HIDE_X,
					second + REPEEK_SECOND + FLIGHT_GRACE, second)
		for speed: float in [RUN_SPEED, SPRINT_SPEED]:
			var across := (GAP_TO - GAP_FROM) + 2.0 * (GAP_FROM - HIDE_X)
			_row(lines, "Cross 4 m at %.1f m/s" % speed, d, trials, func(t: float) -> float:
					return minf(HIDE_X + speed * t, HIDE_X + across), across / speed + FLIGHT_GRACE)
		lines.append("")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("aim bench written: ", path)
	quit(0)


## Runs one case at every level and appends its row: `x_at` gives your x at each second after you start moving,
## `length` how long a trial runs, `count_from` the second from which a hit counts (the re-peek's second exposure).
func _row(lines: PackedStringArray, label: String, dist: float, trials: int, x_at: Callable, length: float,
		count_from: float = 0.0) -> void:
	var cells := PackedStringArray()
	for level in LEVELS:
		var t := Tally.new()
		for i in trials:
			_trial(t, level, dist, i + 1, x_at, length, count_from)
		var cell := "%d %%" % roundi(100.0 * t.hits / maxi(t.trials, 1))
		if count_from == 0.0 and not t.to_hit.is_empty():
			cell += " · fire %.2f · hit %.2f" % [_median(t.to_fire), _median(t.to_hit)]
		cells.append(cell)
	lines.append("| %s | %s |" % [label, " | ".join(cells)])
	print(label, " ", dist, ": ", " / ".join(cells))


## The flat field for targets `dist` m off: [map, world, nav], built once a distance.
func _field(dist: float) -> Array:
	if _fields.has(dist):
		return _fields[dist]
	var m := MapData.new()
	m.id = "aim bench"
	m.kill_y = -10.0
	var w := BoxWorld.new(tuning.body)
	var floor_block := MapData.Block.new()
	floor_block.kind = &"floor"
	floor_block.center = Vector3(0.0, -0.25, FIELD_CENTRE_Z)
	floor_block.size = Vector3(FIELD_WIDTH, 0.5, FIELD_DEPTH)
	m.blocks.append(floor_block)
	w.add_box(floor_block.center, floor_block.size)
	var wall_z := -dist + 0.6
	w.add_box(Vector3(GAP_FROM - 1.5, 1.5, wall_z), Vector3(3.0, 3.0, 0.3))
	w.add_box(Vector3(GAP_TO + 1.5, 1.5, wall_z), Vector3(3.0, 3.0, 0.3))
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(0.0, 0.0, 10.0 if e == 0 else -50.0), 0.0 if e == 0 else PI))
		end.dead_zone.append(SpawnPoint.new(Vector3(8.0, 0.0, 12.0 if e == 0 else -52.0), 0.0))
		m.ends.append(end)
	var nav := NavGrid.build(m, tuning.nav, tuning.body)
	_fields[dist] = [m, w, nav]
	return _fields[dist]


func _trial(t: Tally, level: StringName, dist: float, seed_value: int, x_at: Callable, length: float,
		count_from: float) -> void:
	var field := _field(dist)
	var m: MapData = field[0]
	var w: BoxWorld = field[1]
	var nav: NavGrid = field[2]
	var sim := Simulation.new(tuning, w, w.mover(), m.ends, m.kill_y)
	sim.nav = nav
	var state := GameState.new(seed_value, tuning)
	var loadout := ReplicaStats.default_loadout()
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	state.characters.append(Character.new(1, 1, Vector3(HIDE_X, 0.0, -dist), PI, loadout))
	var levels: Dictionary[int, StringName] = {0: level, 1: level}
	var bots := BotController.new(state, 1, m, nav, w, tuning, config, levels)
	sim.start_match(state)
	bots.observe(state)
	var b := bots.world.bots[0]
	# It stands and fights where it is: no dash for cover first.
	b.skill = b.skill.duplicate() as BotSkill
	b.skill.contact_cover_min_distance = INF
	var commands: Array[PlayerCommand] = [PlayerCommand.new(), PlayerCommand.new()]
	var me := state.characters[0]
	var you := state.characters[1]
	var tick := 0
	var moved_at := -1
	var seen_at := -1.0
	var fired_at := -1.0
	var limit := roundi((SETTLE + length) / DT) + 600
	while tick < limit:
		var live := state.round_state.is_live()
		if live and moved_at < 0:
			moved_at = tick + roundi(SETTLE / DT)
		var since := (tick - moved_at) * DT if moved_at >= 0 and tick >= moved_at else -1.0
		if since > length:
			break
		var x: float = HIDE_X if since < 0.0 else x_at.call(since)
		# Your velocity is the path's own; a step out or back is a jump with none, so the bot leads nobody there.
		var v: float = 0.0 if since < 0.0 else (float(x_at.call(since + DT)) - x) / DT
		if absf(v) > SPRINT_SPEED * 1.5:
			v = 0.0
		you.position = Vector3(x, 0.0, -dist)
		you.velocity = Vector3(v, 0.0, 0.0)
		you.prev_position = you.position - you.velocity * DT
		you.yaw = PI
		me.position = Vector3.ZERO
		me.prev_position = me.position
		bots.think(state, commands, DT)
		commands[1].reset(PI, 0.0)
		if since >= count_from and seen_at < 0.0 and BotSenses.visible_part(me, you, bots.world) > 0.0:
			seen_at = since
		if since >= count_from and commands[0].fire and fired_at < 0.0:
			fired_at = since
		sim.step(state, commands, DT)
		bots.observe(state)
		if you.status != Character.Status.ALIVE:
			if since >= count_from:
				t.hits += 1
				if seen_at >= 0.0:
					t.to_hit.append(since - seen_at)
					if fired_at >= 0.0:
						t.to_fire.append(fired_at - seen_at)
			else:
				# Hit on the first exposure of a re-peek: this trial doesn't count.
				t.trials -= 1
			break
		tick += 1
	t.trials += 1


func _median(a: PackedFloat32Array) -> float:
	var s := a.duplicate()
	s.sort()
	return s[s.size() / 2]
