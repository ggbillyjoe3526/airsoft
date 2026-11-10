extends SceneTree
## Plays the balance report's matches and writes it (BR1): tools/balance.sh runs this headless. Every map in MAPS whose
## id contains the filter plays each level in the levels list against itself through MatchRunner: Normal on seeds 1 to
## the seed count, the others on 1 to their own count, in Elimination and, on a map with a pole, Attack / Defend; the
## figures and verdicts are BalanceReport's. Arguments after `--`: the report's path, the commit, the seed count, then
## optionally a filter, the levels (comma-separated, Normal's by default), the other levels' seed count (Normal's by
## default), the modes ("elimination", "flag" or both comma-separated, both by default) and the team size (each map's
## standard by default; one a map doesn't offer plays its standard there, TS1).

## Every field (the range is not a match map). Each plays at the team size the game gives it (MatchRunner.sized_for:
## its standard, 6v6) or the one asked for, and at the time of day the runner gives it (by day on all three).
const MAPS: Array[String] = ["depot", "woodland"]
## Match time a match may take (s), as the guards allow.
const MAX_MATCH_SECONDS := 30.0 * 60.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("balance_run.gd needs: <report path> <commit> <seeds> [filter]")
		quit(2)
		return
	var path := args[0]
	var commit := args[1]
	if not args[2].is_valid_int() or args[2].to_int() < 1:
		push_error("the seed count must be a whole number from 1, not '%s'" % args[2])
		quit(2)
		return
	var seeds := args[2].to_int()
	var filter := args[3] if args.size() > 3 else ""
	var levels := PackedStringArray(["normal"])
	if args.size() > 4 and args[4] != "":
		levels = args[4].split(",", false)
	for level in levels:
		if not MatchOptions.BOT_LEVELS.has(level):
			push_error("'%s' isn't a level (%s)" % [level, ", ".join(MatchOptions.BOT_LEVELS)])
			quit(2)
			return
	var other_seeds := args[5].to_int() if args.size() > 5 and args[5].is_valid_int() else seeds
	other_seeds = maxi(other_seeds, 1)
	var modes := PackedStringArray(["elimination", "flag"])
	if args.size() > 6 and args[6] != "":
		modes = args[6].split(",", false)
	var size := args[7].to_int() if args.size() > 7 and args[7].is_valid_int() else 0
	var rows: Array[BalanceReport.Figure] = []
	for map_id in MAPS:
		if filter != "" and not map_id.containsn(filter):
			continue
		var runner := MatchRunner.new(root, map_id, MatchRunner.sized_for(map_id, null, size))
		await physics_frame
		await physics_frame
		if not runner.map.problems.is_empty():
			push_error("%s: %s" % [map_id, ", ".join(runner.map.problems)])
			runner.free_level()
			continue
		var name := runner.map.display_name if runner.map.display_name != "" else map_id
		if size > 0:
			name += " " + MatchOptions.size_short(runner.tuning.rounds.team_size)
		var by_level: Dictionary[StringName, Array] = {}
		for level in levels:
			runner.difficulty = StringName(level)
			var count := seeds if level == "normal" else other_seeds
			if modes.has("elimination"):
				var matches := _play(runner, RoundState.Mode.ELIMINATION, count, name, level)
				by_level[StringName(level)] = matches
				rows.append_array(BalanceReport.figures(name, BalanceReport.end_names(runner.map), matches,
						StringName(level)))
				rows.append_array(BalanceReport.personality_shares(name, matches, StringName(level)))
			if modes.has("flag") and runner.map.has_pole:
				rows.append_array(BalanceReport.flag_figures(map_id, name,
						_play(runner, RoundState.Mode.ATTACK_DEFEND, count, name, level), StringName(level)))
		if by_level.has(&"easy") and by_level.has(&"normal"):
			var easy: Array[MatchRunner.MatchTally] = []
			easy.assign(by_level[&"easy"])
			var normal: Array[MatchRunner.MatchTally] = []
			normal.assign(by_level[&"normal"])
			rows.append(BalanceReport.easy_rounds(name, easy, normal))
		runner.free_level()
	if rows.is_empty():
		push_error("no map matches the filter '%s'" % filter)
		quit(1)
		return
	var when := Time.get_datetime_string_from_system(true, true).substr(0, 16) + " UTC"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("can't write %s" % path)
		quit(1)
		return
	var others := ""
	if levels.size() > 1 or levels[0] != "normal":
		others = " (%s; 1 to %d at the other levels)" % [", ".join(Array(levels).map(func(l: String) -> String:
				return BalanceReport.level_name(StringName(l)))), other_seeds]
	file.store_string(BalanceReport.markdown(rows, commit, when, seeds, filter, others))
	file.close()
	quit()


## Seeds 1 to `count` in `mode` on the runner's map at its level, timed in the log.
func _play(runner: MatchRunner, mode: RoundState.Mode, count: int, name: String, level: String) \
		-> Array[MatchRunner.MatchTally]:
	var matches: Array[MatchRunner.MatchTally] = []
	var started := Time.get_ticks_msec()
	runner.mode = mode
	for seed_value in range(1, count + 1):
		matches.append(runner.play(seed_value, MAX_MATCH_SECONDS))
	print("%s, %s, %s: %d matches in %.0f s" % [name, "Elimination" if mode == RoundState.Mode.ELIMINATION
			else "Attack / Defend", BalanceReport.level_name(StringName(level)), matches.size(),
			(Time.get_ticks_msec() - started) / 1000.0])
	return matches
