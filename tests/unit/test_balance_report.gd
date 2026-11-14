extends GutTest
## BalanceReport (BR1): shares, standard errors, verdicts, the figures over a map's tallies and the Markdown.


func _share(count: int, of: int) -> BalanceReport.Figure:
	return BalanceReport.share("s", count, of, BalanceReport.NORMAL_MIN, BalanceReport.NORMAL_MAX, "")


func test_a_share_and_its_standard_error() -> void:
	var f := _share(50, 100)
	assert_almost_eq(f.value, 0.5, 1e-6)
	assert_almost_eq(BalanceReport.standard_error(f), 0.05, 1e-6)
	assert_true(is_nan(_share(0, 0).value), "a share of nothing")
	assert_true(is_nan(BalanceReport.standard_error(BalanceReport.number("n", 3.0, "s", ""))), "a plain number")


func test_verdicts_by_band_and_noise() -> void:
	assert_eq(BalanceReport.judge(_share(500, 1000)), BalanceReport.Verdict.IN_BAND, "50 % of 1000")
	assert_eq(BalanceReport.judge(_share(46, 100)), BalanceReport.Verdict.NEAR, "46 % ±5: within one error of 45")
	assert_eq(BalanceReport.judge(_share(40, 100)), BalanceReport.Verdict.NOISE, "40 % ±4.9: under two errors out")
	assert_eq(BalanceReport.judge(_share(300, 1000)), BalanceReport.Verdict.OUTSIDE, "30 % ±1.4: far out")
	assert_eq(BalanceReport.judge(_share(0, 0)), BalanceReport.Verdict.NOT_RUN)
	assert_eq(BalanceReport.judge(BalanceReport.number("n", 3.0, "s", "")), BalanceReport.Verdict.MEASURED)
	var on_time := BalanceReport.share("t", 0, 50, -INF, BalanceReport.ON_TIME_MAX, "")
	assert_eq(BalanceReport.judge(on_time), BalanceReport.Verdict.IN_BAND, "an open-ended band, no error at 0 %")


func test_median() -> void:
	assert_true(is_nan(BalanceReport.median(PackedFloat32Array())))
	assert_almost_eq(BalanceReport.median(PackedFloat32Array([3.0, 1.0, 2.0])), 2.0, 1e-6)
	assert_almost_eq(BalanceReport.median(PackedFloat32Array([4.0, 1.0, 2.0, 3.0])), 2.5, 1e-6)


func _round(winner: int, alpha_end: int, reason: int, hit_time: float, hit_range: float) -> MatchRunner.RoundTally:
	var r := MatchRunner.RoundTally.new()
	r.winner = winner
	r.alpha_end = alpha_end
	r.reason = reason
	r.first_hit_time = hit_time
	r.first_hit_range = hit_range
	return r


func test_figures_split_teams_from_ends_and_count_the_clock() -> void:
	var m := MatchRunner.MatchTally.new()
	var elim := GameEvent.RoundEnd.ELIMINATED
	# Alpha wins twice from end 1 and once from end 0; Beta once from end 0 (Alpha at end 1); one draw on time.
	m.rounds.append(_round(0, 1, elim, 10.0, 8.0))
	m.rounds.append(_round(0, 1, elim, 20.0, 12.0))
	m.rounds.append(_round(0, 0, elim, 30.0, 20.0))
	m.rounds.append(_round(1, 1, elim, 40.0, 30.0))
	m.rounds.append(_round(-1, 0, GameEvent.RoundEnd.TIME, -1.0, -1.0))
	var ends: Array[String] = ["the west end", "the east end"]
	var rows := BalanceReport.figures("Depot", ends, [m] as Array[MatchRunner.MatchTally])
	assert_eq(rows.size(), 8)
	assert_almost_eq(rows[0].value, 0.75, 1e-6, "Alpha 3 of 4 decided")
	assert_almost_eq(rows[1].value, 0.25, 1e-6, "Beta 1 of 4")
	assert_almost_eq(rows[2].value, 0.5, 1e-6, "the west end: Alpha once from it, Beta once from it")
	assert_almost_eq(rows[3].value, 0.5, 1e-6, "the east end: Alpha twice")
	assert_string_contains(rows[2].label, "the west end")
	assert_almost_eq(rows[4].value, 0.2, 1e-6, "one round of five on time")
	assert_almost_eq(rows[5].value, 25.0, 1e-6, "median first hit of four rounds with one")
	assert_almost_eq(rows[6].value, 16.0, 1e-6)


func test_markdown_puts_the_most_urgent_first() -> void:
	var rows: Array[BalanceReport.Figure] = [_share(500, 1000), _share(300, 1000), BalanceReport.number("n", 3, "s", "")]
	rows[0].label = "fine"
	rows[1].label = "bad"
	var text := BalanceReport.markdown(rows, "abc1234", "today", 32, "")
	assert_string_contains(text, "on `abc1234`, seeds 1 to 32 a map.")
	assert_string_contains(text, "3 figures: 1 outside their band, 0 outside but within noise, 0 near an edge, "
			+ "1 in band, 1 measured")
	assert_lt(text.find("| bad |"), text.find("| fine |"))
	assert_string_contains(text, "| 30.0 % ±1.4 | 45–55 % | outside |")
	assert_string_contains(text, "| 3.0 s | – | measured |")


func test_figures_use_the_end_each_round_was_played_from_and_ends_swap_at_half_time() -> void:
	var tuning := SimTuning.load_default().duplicate(true) as SimTuning
	tuning.rounds.wins_needed = 4
	tuning.rounds.half_time_after = 2
	tuning.rounds.first_end = 0
	var r := MatchRunner.new(self, "depot", tuning)
	await wait_physics_frames(2)
	var m := r.play(1, 30.0 * 60.0)
	r.free_level()
	assert_gt(m.rounds.size(), 2, "enough rounds to cross half time")
	var decided := 0
	for i in m.rounds.size():
		var round_tally: MatchRunner.RoundTally = m.rounds[i]
		assert_eq(round_tally.alpha_end, 0 if decided < 2 else 1, "round %d (%d decided before it)" % [i + 1, decided])
		if round_tally.winner >= 0:
			decided += 1


func test_a_share_of_zero_or_all_has_no_error_so_a_band_miss_is_outside_and_a_hit_is_in_band() -> void:
	assert_eq(BalanceReport.judge(_share(0, 40)), BalanceReport.Verdict.OUTSIDE, "0 %: no error to excuse a miss")
	assert_eq(BalanceReport.judge(_share(40, 40)), BalanceReport.Verdict.OUTSIDE, "100 %")
	var open_low := BalanceReport.share("t", 40, 40, 0.9, INF, "")
	assert_eq(BalanceReport.judge(open_low), BalanceReport.Verdict.IN_BAND, "100 % of a floor band, error 0")


func test_an_exact_band_edge_is_inside_and_near() -> void:
	assert_eq(BalanceReport.judge(_share(45, 100)), BalanceReport.Verdict.NEAR, "45 % is inside the band")
	assert_eq(BalanceReport.judge(_share(55, 100)), BalanceReport.Verdict.NEAR, "55 %")
	assert_eq(BalanceReport.judge(_share(44, 100)), BalanceReport.Verdict.NOISE, "just past")


func test_markdown_formats_open_bands_and_ties_keep_figure_order() -> void:
	var a := _share(50, 100)
	a.label = "first"
	var b := _share(51, 100)
	b.label = "second"
	var rows: Array[BalanceReport.Figure] = [a, b]
	var text := BalanceReport.markdown(rows, "c", "t", 2, "dep")
	assert_lt(text.find("| first |"), text.find("| second |"))
	assert_string_contains(text, "only maps matching `dep`")
	assert_eq(BalanceReport.format_band(BalanceReport.share("t", 1, 10, -INF, 0.1, "")), "≤ 10 %")
	assert_eq(BalanceReport.format_band(BalanceReport.share("t", 1, 10, 0.2, INF, "")), "≥ 20 %")


func test_flag_figures_count_the_attackers_rounds_the_clock_and_captures_with_each_band() -> void:
	var m := MatchRunner.MatchTally.new()
	for spec: Array in [[0, 0, GameEvent.RoundEnd.CAPTURED], [0, 1, GameEvent.RoundEnd.ELIMINATED],
			[1, 1, GameEvent.RoundEnd.ELIMINATED], [0, 1, GameEvent.RoundEnd.TIME], [-1, 0, GameEvent.RoundEnd.ELIMINATED]]:
		var r := _round(spec[0] as int, 0, spec[2] as int, -1.0, -1.0)
		r.attackers = spec[1]
		m.rounds.append(r)
	var matches: Array[MatchRunner.MatchTally] = [m]
	var f := BalanceReport.flag_figures("depot", "Depot", matches)
	assert_eq(f.size(), 4)
	assert_almost_eq(f[0].value, 2.0 / 5.0, 1e-6, "the attackers won two of five (a draw is nobody's)")
	assert_eq(Vector2(f[0].band_min, f[0].band_max), BalanceReport.ATTACK_NORMAL_BANDS["depot"])
	assert_almost_eq(f[1].value, 1.0 / 5.0, 1e-6, "one ran out the clock")
	assert_almost_eq(f[2].value, 1.0 / 5.0, 1e-6, "one won by raising the flag")
	assert_eq(BalanceReport.judge(f[2]), BalanceReport.Verdict.MEASURED)
	var other := BalanceReport.flag_figures("woodland", "Woodland", matches)
	assert_eq(Vector2(other[0].band_min, other[0].band_max), BalanceReport.ATTACK_NORMAL_BAND, "any other map's")
	var hard := BalanceReport.flag_figures("depot", "Depot", matches, &"hard")
	assert_eq(Vector2(hard[0].band_min, hard[0].band_max), Vector2(0.4, 0.6), "Pro's band, kept by Hard (TL1)")
	assert_string_contains(hard[0].label, "Attack / Defend, Hard")


func test_plant_figures_count_the_attackers_rounds_and_what_became_of_each_armed_bomb() -> void:
	var m := MatchRunner.MatchTally.new()
	# winner, attackers, why it ended, when the bomb was armed (s, -1 never)
	for spec: Array in [[0, 0, GameEvent.RoundEnd.WENT_OFF, 20.0], [1, 0, GameEvent.RoundEnd.DEFUSED, 30.0],
			[0, 0, GameEvent.RoundEnd.ELIMINATED, 25.0], [1, 0, GameEvent.RoundEnd.ELIMINATED, -1.0],
			[1, 0, GameEvent.RoundEnd.TIME, -1.0]]:
		var r := _round(spec[0] as int, 0, spec[2] as int, -1.0, -1.0)
		r.attackers = spec[1]
		r.planted_at = spec[3]
		m.rounds.append(r)
	var matches: Array[MatchRunner.MatchTally] = [m]
	var f := BalanceReport.plant_figures("Depot", matches)
	assert_eq(f.size(), 6)
	assert_almost_eq(f[0].value, 2.0 / 5.0, 1e-6, "the attackers won two of five")
	assert_eq(Vector2(f[0].band_min, f[0].band_max), BalanceReport.ATTACK_NORMAL_BAND, "judged by Attack / Defend's")
	assert_almost_eq(f[1].value, 1.0 / 5.0, 1e-6, "one ran out the clock")
	assert_eq(f[1].band_max, BalanceReport.ON_TIME_MAX)
	assert_almost_eq(f[2].value, 3.0 / 5.0, 1e-6, "armed in three rounds")
	assert_almost_eq(f[3].value, 1.0 / 3.0, 1e-6, "one armed bomb in three was made safe")
	assert_almost_eq(f[4].value, 1.0 / 3.0, 1e-6, "one in three went off")
	assert_eq(f[3].of, 3, "a share of the armed bombs, so its error is theirs")
	assert_eq(BalanceReport.judge(f[4]), BalanceReport.Verdict.MEASURED)
	assert_string_contains(f[0].label, "Plant The Bomb, Normal")
	var hard := BalanceReport.plant_figures("Depot", matches, &"hard")
	assert_eq(Vector2(hard[0].band_min, hard[0].band_max), Vector2(0.4, 0.6))
	var none: Array[MatchRunner.MatchTally] = []
	assert_eq(BalanceReport.judge(BalanceReport.plant_figures("Depot", none)[3]), BalanceReport.Verdict.NOT_RUN,
			"no bomb armed: a share of nothing did not run")
