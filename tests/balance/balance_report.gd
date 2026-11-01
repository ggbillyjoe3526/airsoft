class_name BalanceReport
extends RefCounted
## The bot balance report's figures and verdicts (BR1; the browser's pipeline/balanceReport.mjs): each figure judged
## against its band and its standard error, never asserted (docs/DECISIONS.md › Bots and balance). Pure functions over
## MatchRunner's tallies, so tests/unit/test_balance_report.gd tests them; tests/balance/balance_run.gd plays the
## matches and writes the report. Test-only (tests/ never ships).

## The verdicts, most urgent first (the report's order); a figure with no band is only measured.
enum Verdict { NOT_RUN, OUTSIDE, NOISE, NEAR, IN_BAND, MEASURED }
const VERDICT_NAMES: Array[String] = ["did not run", "outside", "outside, within noise", "near an edge", "in band",
	"measured"]
## Past its band by fewer standard errors than this, a figure is called noise: re-measure on more seeds first.
const NOISE_SE := 2.0
## Normal's band for a team's or an end's share of the decided rounds (M73).
const NORMAL_MIN := 0.45
const NORMAL_MAX := 0.55
## Each level's band for the same shares, each level against itself (the browser game's balanceSupport.ts): Normal's
## is the tightest. The bands stayed with the names when the levels moved up (owner, 2026-10-25): Hard has Pro's.
const LEVEL_BANDS: Dictionary[StringName, Vector2] = {
	&"easy": Vector2(0.35, 0.65), &"normal": Vector2(NORMAL_MIN, NORMAL_MAX), &"hard": Vector2(0.4, 0.6),
}
## Easy's mean round, at most this many times Normal's (the browser's depotDifficulty.balance.ts): slower bots
## shouldn't turn a round into a stand-off.
const EASY_ROUNDS_MAX := 1.6
## Rounds that run out the clock: under 1 in 10 (the browser's ON_TIME_BAND).
const ON_TIME_MAX := 0.1
## Attack / Defend: the attackers' share of all rounds, each level against itself (the browser game's depotFlag,
## depotProFlag and neonHeightsFlag balance files): Normal's per map (Depot's, any other map's), the other levels' as in
## LEVEL_BANDS but wider at Normal's level of play on the pole.
const ATTACK_BANDS: Dictionary[StringName, Vector2] = {&"easy": Vector2(0.35, 0.65), &"hard": Vector2(0.4, 0.6)}
const ATTACK_NORMAL_BANDS: Dictionary[String, Vector2] = {"depot": Vector2(0.38, 0.67)}
const ATTACK_NORMAL_BAND := Vector2(0.4, 0.65)


## One figure: a share (`of` > 0, value 0..1) or a plain number in `unit`, with its band (either end may be open).
class Figure:
	extends RefCounted
	var label: String = ""
	## NAN when there was nothing to count (the report marks it as not run).
	var value: float = NAN
	## A share's count: the rounds it is a share of (its standard error comes from it); 0 for a plain number.
	var of: int = 0
	var band_min: float = -INF
	var band_max: float = INF
	## "s" or "m" for a plain number; a share's is a percentage.
	var unit: String = ""
	## The counts behind the figure, for the reader: "61 of 121 decided".
	var detail: String = ""


## `count` of `of` as a share, NAN for a share of nothing.
static func share(label: String, count: int, of: int, band_min: float, band_max: float, detail: String) -> Figure:
	var f := Figure.new()
	f.label = label
	f.value = float(count) / of if of > 0 else NAN
	f.of = of
	f.band_min = band_min
	f.band_max = band_max
	f.detail = detail
	return f


## A plain number with no band: measured, for the reader to watch.
static func number(label: String, value: float, unit: String, detail: String) -> Figure:
	var f := Figure.new()
	f.label = label
	f.value = value
	f.unit = unit
	f.detail = detail
	return f


## One standard error of a share, √(p(1−p)/n); NAN for a plain number or a share of nothing.
static func standard_error(f: Figure) -> float:
	if f.of <= 0 or is_nan(f.value):
		return NAN
	return sqrt(f.value * (1.0 - f.value) / f.of)


## In band; near an edge (inside, but within one standard error of an edge); outside within noise (past an edge by
## less than NOISE_SE standard errors); outside (further, or no standard error to judge by); not run (no figure);
## measured (no band to judge by).
static func judge(f: Figure) -> Verdict:
	if is_nan(f.value):
		return Verdict.NOT_RUN
	if not is_finite(f.band_min) and not is_finite(f.band_max):
		return Verdict.MEASURED
	var se := standard_error(f)
	var past := maxf(f.band_min - f.value, f.value - f.band_max)
	if past > 0.0:
		return Verdict.NOISE if not is_nan(se) and past < NOISE_SE * se else Verdict.OUTSIDE
	var room := minf(f.value - f.band_min, f.band_max - f.value)
	return Verdict.NEAR if not is_nan(se) and room < se else Verdict.IN_BAND


## The middle value (NAN for none).
static func median(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return NAN
	var sorted := values.duplicate()
	sorted.sort()
	var mid := sorted.size() / 2
	return sorted[mid] if sorted.size() % 2 == 1 else (sorted[mid - 1] + sorted[mid]) * 0.5


## Which way end 0 lies from end 1, by their spawns' middles: "the west end" (+X east, −Z north), for the labels.
static func end_names(map: MapData) -> Array[String]:
	var middle: Array[Vector3] = []
	for e in map.ends:
		var sum := Vector3.ZERO
		for s in e.spawns:
			sum += s.position
		middle.append(sum / maxf(e.spawns.size(), 1.0))
	var names: Array[String] = ["end 0", "end 1"]
	if middle.size() < 2:
		return names
	var d := middle[0] - middle[1]
	if absf(d.x) >= absf(d.z):
		names[0] = "the east end" if d.x > 0.0 else "the west end"
		names[1] = "the west end" if d.x > 0.0 else "the east end"
	else:
		names[0] = "the south end" if d.z > 0.0 else "the north end"
		names[1] = "the north end" if d.z > 0.0 else "the south end"
	return names


## A map's figures over its matches at `level` (both teams): each team's and each end's share of the decided rounds
## (the level's band), rounds on time, the median time and range of each round's first hit and the median round
## length (the pace, TS1).
static func figures(map_name: String, ends: Array[String], matches: Array[MatchRunner.MatchTally],
		level: StringName = &"normal") -> Array[Figure]:
	var rounds := 0
	var on_time := 0
	var team_wins := PackedInt32Array([0, 0])
	var end_wins := PackedInt32Array([0, 0])
	var hit_times := PackedFloat32Array()
	var hit_ranges := PackedFloat32Array()
	var lengths := PackedFloat32Array()
	for m in matches:
		for r in m.rounds:
			rounds += 1
			lengths.append(r.seconds)
			if r.reason == GameEvent.RoundEnd.TIME:
				on_time += 1
			if r.winner == 0 or r.winner == 1:
				team_wins[r.winner] += 1
				end_wins[r.alpha_end if r.winner == 0 else 1 - r.alpha_end] += 1
			if r.first_hit_time >= 0.0:
				hit_times.append(r.first_hit_time)
				hit_ranges.append(r.first_hit_range)
	var decided := team_wins[0] + team_wins[1]
	var drawn := rounds - decided - on_time
	var at := "%s, Elimination, %s" % [map_name, level_name(level)]
	var band: Vector2 = LEVEL_BANDS.get(level, Vector2(NORMAL_MIN, NORMAL_MAX))
	var out: Array[Figure] = []
	for team in 2:
		out.append(share("%s: %s's share of the decided rounds" % [at, ["Alpha", "Beta"][team]], team_wins[team],
				decided, band.x, band.y, "%d of %d decided" % [team_wins[team], decided]))
	for end in 2:
		out.append(share("%s: %s's share of the decided rounds" % [at, ends[end]], end_wins[end], decided, band.x,
				band.y, "%d of %d decided" % [end_wins[end], decided]))
	out.append(share("%s: rounds that run out the clock" % at, on_time, rounds, -INF, ON_TIME_MAX,
			"%d of %d rounds; %d decided, %d drawn with both teams out" % [on_time, rounds, decided, drawn]))
	out.append(number("%s: median time to a round's first hit" % at, median(hit_times), "s",
			"%d rounds with a hit" % hit_times.size()))
	out.append(number("%s: median range of a round's first hit" % at, median(hit_ranges), "m",
			"%d rounds with a hit" % hit_ranges.size()))
	out.append(number("%s: median round length" % at, median(lengths), "s", "%d rounds" % lengths.size()))
	return out


## A map's Attack / Defend figures over its matches at `level`: the attackers' share of all rounds (its band, by map at
## Normal), rounds that run out the clock, and the share won by raising the flag (measured).
static func flag_figures(map_id: String, map_name: String, matches: Array[MatchRunner.MatchTally],
		level: StringName = &"normal") -> Array[Figure]:
	var rounds := 0
	var attack_wins := 0
	var on_time := 0
	var captures := 0
	var lengths := PackedFloat32Array()
	for m in matches:
		for r in m.rounds:
			rounds += 1
			lengths.append(r.seconds)
			if r.winner >= 0 and r.winner == r.attackers:
				attack_wins += 1
			if r.reason == GameEvent.RoundEnd.TIME:
				on_time += 1
			elif r.reason == GameEvent.RoundEnd.CAPTURED:
				captures += 1
	var at := "%s, Attack / Defend, %s" % [map_name, level_name(level)]
	var band: Vector2 = ATTACK_NORMAL_BANDS.get(map_id, ATTACK_NORMAL_BAND) if level == &"normal" \
			else ATTACK_BANDS.get(level, ATTACK_NORMAL_BAND)
	var out: Array[Figure] = []
	out.append(share("%s: the attackers' share of rounds" % at, attack_wins, rounds, band.x, band.y,
			"%d of %d rounds" % [attack_wins, rounds]))
	out.append(share("%s: rounds that run out the clock" % at, on_time, rounds, -INF, ON_TIME_MAX,
			"%d of %d rounds" % [on_time, rounds]))
	out.append(share("%s: rounds won by raising the flag" % at, captures, rounds, -INF, INF,
			"%d of %d rounds" % [captures, rounds]))
	out.append(number("%s: median round length" % at, median(lengths), "s", "%d rounds" % lengths.size()))
	return out


## Each personality's share of the knock-outs of an opponent at `level`, against its share of the bots: measured only,
## to see whether a personality plays better or worse rather than only differently (bots.md: never how well).
static func personality_shares(map_name: String, matches: Array[MatchRunner.MatchTally],
		level: StringName = &"normal") -> Array[Figure]:
	var kinds: Array[StringName] = []
	var hits: Dictionary[StringName, int] = {}
	var bots: Dictionary[StringName, int] = {}
	var all_hits := 0
	var all_bots := 0
	for m in matches:
		for id in m.personalities.size():
			var kind := m.personalities[id]
			if kind == &"":
				continue
			if not kinds.has(kind):
				kinds.append(kind)
			bots[kind] = bots.get(kind, 0) + 1
			hits[kind] = hits.get(kind, 0) + m.hits_by[id]
			all_bots += 1
			all_hits += m.hits_by[id]
	var out: Array[Figure] = []
	for kind in kinds:
		out.append(share("%s, Elimination, %s: %s bots' share of hits on an opponent" % [map_name, level_name(level),
				level_name(kind)], hits[kind], all_hits, -INF, INF, "%d of %d hits; %d of %d bots" % [hits[kind],
				all_hits, bots[kind], all_bots]))
	return out


## Easy's mean round length on a map as a multiple of Normal's (at most EASY_ROUNDS_MAX).
static func easy_rounds(map_name: String, easy: Array[MatchRunner.MatchTally],
		normal: Array[MatchRunner.MatchTally]) -> Figure:
	var e := mean_round_seconds(easy)
	var n := mean_round_seconds(normal)
	var f := number("%s, Elimination: Easy's mean round against Normal's" % map_name, e / n if n > 0.0 else NAN, "×",
			"%.1f s against %.1f s" % [e, n])
	f.band_max = EASY_ROUNDS_MAX
	return f


## The mean length of the rounds in `matches` (s), 0 with none.
static func mean_round_seconds(matches: Array[MatchRunner.MatchTally]) -> float:
	var total := 0.0
	var count := 0
	for m in matches:
		for r in m.rounds:
			total += r.seconds
			count += 1
	return total / count if count > 0 else 0.0


## "Normal" for &"normal": a level's name in the report.
static func level_name(level: StringName) -> String:
	return String(level).capitalize()


## A figure as the report shows it: "49.5 % ±4.5", "12.3 s".
static func format_value(f: Figure) -> String:
	if is_nan(f.value):
		return "–"
	if f.of > 0:
		return "%.1f %% ±%.1f" % [100.0 * f.value, 100.0 * standard_error(f)]
	return "%.2f %s" % [f.value, f.unit] if f.unit == "×" else "%.1f %s" % [f.value, f.unit]


## A band as the report shows it: "45–55 %", "≤ 10 %", or "–" for none.
static func format_band(f: Figure) -> String:
	var scale := 100.0 if f.of > 0 or f.unit == "" else 1.0
	var unit := " %" if scale == 100.0 else " " + f.unit
	var low := is_finite(f.band_min)
	var high := is_finite(f.band_max)
	if low and high:
		return "%s–%s%s" % [_num(f.band_min * scale), _num(f.band_max * scale), unit]
	if high:
		return "≤ %s%s" % [_num(f.band_max * scale), unit]
	if low:
		return "≥ %s%s" % [_num(f.band_min * scale), unit]
	return "–"


static func _num(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


## The report as Markdown: what was measured and on which commit, a summary line, then every figure, most urgent
## first (figure order within a verdict).
static func markdown(rows: Array[Figure], commit: String, when: String, seeds: int, filter: String,
		others: String = "") -> String:
	var order: Array[int] = []
	for i in rows.size():
		order.append(i)
	var verdicts: Array[Verdict] = []
	for f in rows:
		verdicts.append(judge(f))
	order.sort_custom(func(a: int, b: int) -> bool:
		return verdicts[a] < verdicts[b] if verdicts[a] != verdicts[b] else a < b)
	var counts := PackedInt32Array()
	counts.resize(VERDICT_NAMES.size())
	for v in verdicts:
		counts[v] += 1
	var lines: Array[String] = [
		"# Balance report",
		"",
		"Measured %s on `%s`, seeds 1 to %d a map%s%s. %s." % [when, commit, seeds, others,
				", only maps matching `%s`" % filter if filter != "" else "", summary(counts, rows.size())],
		"",
		"A figure **outside** its band by two standard errors or more is a balance issue for the bug pass. One",
		"**outside, within noise** is re-measured on more seeds before anyone acts on it, and one **near an edge** is one",
		"to watch (`docs/PROCESS.md` › Bug pass). Nothing here fails a build.",
		"",
		"| Figure | Measured | Target | Verdict | Counts |",
		"|---|---|---|---|---|",
	]
	for i in order:
		var f := rows[i]
		lines.append("| %s | %s | %s | %s | %s |" % [f.label, format_value(f), format_band(f),
				VERDICT_NAMES[verdicts[i]], f.detail])
	return "\n".join(lines) + "\n"


## "7 figures: 0 outside their band, 1 outside but within noise, 2 near an edge, 2 in band, 2 measured".
static func summary(counts: PackedInt32Array, total: int) -> String:
	return "%d figures: %d outside their band, %d outside but within noise, %d near an edge, %d in band" % [total,
			counts[Verdict.OUTSIDE], counts[Verdict.NOISE], counts[Verdict.NEAR], counts[Verdict.IN_BAND]] + (
			", %d measured" % counts[Verdict.MEASURED] if counts[Verdict.MEASURED] > 0 else "") + (
			", %d did not run" % counts[Verdict.NOT_RUN] if counts[Verdict.NOT_RUN] > 0 else "")
