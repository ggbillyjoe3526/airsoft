extends SceneTree
## The sniper balance bench (SN3), dev only: plays seeded Normal bot matches on each field at every team size twice,
## once with the bots' kits as they ship with Dev content off (no Sniper Rifle) and once with Dev content on and the
## kit table given extra Sniper Rifle rows (each spring, the Variable Scope) weighted up so about a quarter of the
## bots carry one. It writes per map and size the end and attacker shares both ways, and per kit what its bots hit
## and how often they were hit, so a spring or a scope that outplays the rest shows. Measured, never asserted.
## Arguments after `--`: the report's path, the seed count, a map filter (empty: all), the sizes (comma-separated,
## 5,6,7,8 by default), the modes ("elimination", "flag" or both, both by default).

const MAPS: Array[String] = ["depot", "woodland"]
const MAX_MATCH_SECONDS := 30.0 * 60.0
const LEVEL := &"normal"
## The kit rows added after the Sniper row (Normal weight 8 each, so about 32 of every 126 bots carry a Sniper Rifle).
const SNIPER_ROWS := """| Sniper M140 | Sniper Rifle | M140 Spring | GBB Pistol | | anchor, careful | 0 | 8 | 0 |
| Sniper M150 | Sniper Rifle | M150 Spring | GBB Pistol | | anchor, careful | 0 | 8 | 0 |
| Sniper Variable | Sniper Rifle | Variable Scope, M150 Spring | GBB Pistol | | anchor, careful | 0 | 8 | 0 |
"""
const SNIPER_ROW_START := "| Sniper | Sniper Rifle |"


class KitTally:
	extends RefCounted
	var rounds: int = 0
	var hits: int = 0
	var hit_on: int = 0
	var ranges: PackedFloat32Array = PackedFloat32Array()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or not args[1].is_valid_int():
		push_error("sniper_bench.gd needs: <report path> <seeds> [filter] [sizes] [modes]")
		quit(2)
		return
	var path := args[0]
	var seeds := maxi(args[1].to_int(), 1)
	var filter := args[2] if args.size() > 2 else ""
	var sizes := PackedInt32Array([5, 6, 7, 8])
	if args.size() > 3 and args[3] != "":
		sizes.clear()
		for s in args[3].split(",", false):
			sizes.append(s.to_int())
	var modes := PackedStringArray(["elimination", "flag"])
	if args.size() > 4 and args[4] != "":
		modes = args[4].split(",", false)
	var sniper_kits := _sniper_kits()
	if sniper_kits == null:
		quit(1)
		return
	var dev_rules := LoadoutRules.standard()
	dev_rules.dev_content = true
	var lines := PackedStringArray(["# Sniper balance bench (SN3)", "",
			"Normal bots, seeds 1 to %d per row. Base: the shipped kits, Dev content off (no Sniper Rifle). Sniper: Dev"
			% seeds + " content on, Sniper rows for each spring and the Variable Scope added (about a quarter of the"
			+ " bots). Shares are of decided rounds; the band is 45 to 55 %.", ""])
	var kit_totals: Dictionary[String, KitTally] = {}
	for map_id in MAPS:
		if filter != "" and not map_id.containsn(filter):
			continue
		lines.append("## %s" % map_id)
		lines.append("")
		lines.append("| Size | Mode | Base | Sniper | Base round (s) | Sniper round (s) | Sniper first-hit range (m) |")
		lines.append("|---|---|---|---|---|---|---|")
		var per_map: Dictionary[String, KitTally] = {}
		for size in sizes:
			var runner := MatchRunner.new(root, map_id, MatchRunner.sized_for(map_id, null, size))
			await physics_frame
			await physics_frame
			if not runner.map.problems.is_empty():
				push_error("%s: %s" % [map_id, ", ".join(runner.map.problems)])
				runner.free_level()
				continue
			runner.difficulty = LEVEL
			for mode_name in modes:
				var mode := RoundState.Mode.ELIMINATION if mode_name == "elimination" else RoundState.Mode.ATTACK_DEFEND
				if mode == RoundState.Mode.ATTACK_DEFEND and not runner.map.has_pole:
					continue
				runner.mode = mode
				runner._kits = BotKits.shared()
				runner._kit_rules = LoadoutRules.standard()
				var scratch: Dictionary[String, KitTally] = {}
				var base := _play(runner, seeds, scratch)
				runner._kits = sniper_kits
				runner._kit_rules = dev_rules
				var kit_tallies: Dictionary[String, KitTally] = {}
				var sniper := _play(runner, seeds, kit_tallies)
				for k in kit_tallies:
					_add(per_map, k, kit_tallies[k])
					_add(kit_totals, k, kit_tallies[k])
				lines.append("| %d | %s | %s | %s | %.0f | %.0f | %.0f |" % [size, mode_name, _share(base, mode),
						_share(sniper, mode), _median_length(base), _median_length(sniper), _median_first(sniper)])
				print("%s %dv%d %s: base %s, sniper %s" % [map_id, size, size, mode_name, _share(base, mode),
						_share(sniper, mode)])
				# Written as each row lands, so a long run can be read part way.
				var so_far := lines.duplicate()
				so_far.append("")
				so_far.append_array(_kit_table(per_map))
				_write(path, so_far)
			runner.free_level()
		lines.append("")
		lines.append_array(_kit_table(per_map))
	lines.append("## All maps")
	lines.append("")
	lines.append_array(_kit_table(kit_totals))
	quit(0 if _write(path, lines) else 1)


func _write(path: String, lines: PackedStringArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("can't write %s" % path)
		return false
	file.store_string("\n".join(lines) + "\n")
	file.close()
	return true


func _sniper_kits() -> BotKits:
	var text := FileAccess.get_file_as_string("res://data/bot-kits.md")
	var at := text.find(SNIPER_ROW_START)
	if at < 0:
		push_error("bot-kits.md has no Sniper row")
		return null
	var row_end := text.find("\n", at) + 1
	var row := text.substr(at, row_end - at)
	# The shipped Sniper row keeps its Easy and Hard weights; Normal goes to 8 like the added rows.
	var cells := row.split("|")
	cells[cells.size() - 3] = " 8 "
	text = text.substr(0, at) + "|".join(cells) + SNIPER_ROWS + text.substr(row_end)
	var kits := BotKits.parse(text, Pool.shared())
	if not kits.problems.is_empty():
		push_error("sniper kits: %s" % "; ".join(kits.problems))
		return null
	return kits


## Seeds 1 to `count`; each round's hits counted by the shooter's and the target's kit into `tallies` when given.
func _play(runner: MatchRunner, count: int, tallies: Dictionary[String, KitTally]) -> Array[MatchRunner.MatchTally]:
	var out: Array[MatchRunner.MatchTally] = []
	var watch := func(state: GameState, _bots: BotController) -> void:
		var kit_of := runner.kits_now
		for i in state.events.count:
			var e := state.events.items[i]
			if e.kind != GameEvent.Kind.CHARACTER_HIT or e.actor == e.target:
				continue
			var shooter := state.character(e.actor)
			var target := state.character(e.target)
			if shooter == null or target == null or shooter.team == target.team:
				continue
			var a := _tally(tallies, kit_of[e.actor])
			a.hits += 1
			a.ranges.append(shooter.position.distance_to(target.position))
			_tally(tallies, kit_of[e.target]).hit_on += 1
	runner.each_tick = watch
	for seed_value in range(1, count + 1):
		var m := runner.play(seed_value, MAX_MATCH_SECONDS)
		out.append(m)
		for i in m.kits.size():
			_tally(tallies, m.kits[i]).rounds += m.rounds.size()
	runner.each_tick = Callable()
	return out


func _tally(tallies: Dictionary[String, KitTally], kit: String) -> KitTally:
	var name := kit if kit != "" else "(as it comes)"
	if not tallies.has(name):
		tallies[name] = KitTally.new()
	return tallies[name]


func _add(into: Dictionary[String, KitTally], kit: String, t: KitTally) -> void:
	var to := _tally(into, kit)
	to.rounds += t.rounds
	to.hits += t.hits
	to.hit_on += t.hit_on
	to.ranges.append_array(t.ranges)


func _kit_table(tallies: Dictionary[String, KitTally]) -> PackedStringArray:
	var out := PackedStringArray(["| Kit | Bot-rounds | Hits per round | Hit per round | Hits per hit taken |"
			+ " Median hit range (m) |", "|---|---|---|---|---|---|"])
	var names := tallies.keys()
	names.sort()
	for k: String in names:
		var t := tallies[k]
		out.append("| %s | %d | %.2f | %.2f | %.2f | %.0f |" % [k, t.rounds, t.hits / maxf(t.rounds, 1.0),
				t.hit_on / maxf(t.rounds, 1.0), t.hits / maxf(t.hit_on, 1.0), _median(t.ranges)])
	out.append("")
	return out


func _share(matches: Array[MatchRunner.MatchTally], mode: RoundState.Mode) -> String:
	var wins := 0
	var decided := 0
	for m in matches:
		for r in m.rounds:
			if r.winner != 0 and r.winner != 1:
				continue
			decided += 1
			if mode == RoundState.Mode.ELIMINATION:
				# End 0's share (ends swap at half, so this is the map's lean, not a team's).
				if (r.alpha_end if r.winner == 0 else 1 - r.alpha_end) == 0:
					wins += 1
			elif r.winner == r.attackers:
				wins += 1
	var label := "end 0" if mode == RoundState.Mode.ELIMINATION else "attackers"
	return "%s %.0f %% of %d" % [label, 100.0 * wins / maxf(decided, 1.0), decided]


func _median_length(matches: Array[MatchRunner.MatchTally]) -> float:
	var v := PackedFloat32Array()
	for m in matches:
		for r in m.rounds:
			v.append(r.seconds)
	return _median(v)


func _median_first(matches: Array[MatchRunner.MatchTally]) -> float:
	var v := PackedFloat32Array()
	for m in matches:
		for r in m.rounds:
			if r.first_hit_range >= 0.0:
				v.append(r.first_hit_range)
	return _median(v)


func _median(v: PackedFloat32Array) -> float:
	if v.is_empty():
		return 0.0
	var s := v.duplicate()
	s.sort()
	return s[s.size() / 2]
