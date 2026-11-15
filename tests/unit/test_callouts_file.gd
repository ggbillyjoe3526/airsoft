extends GutTest
## data/callouts.md, the hand-edited table of what the bots call, read whole and never stopping the game (CO1,
## game/config/callouts_file.gd; the browser game's config/calloutsFile.test.ts, CL1).

const PEOPLE: Array[StringName] = [&"rusher", &"careful"]
const E := CalloutsFile.Event


## A small file with every table (but only some events): `lines` replaces the Lines table's first rows, `when` the
## When they call table's rows.
static func _file(lines: String = "| Contact | Any | Contact, {area}! |",
		when: String = "| Contact | 1 | 3 |\n| Down | 0.5 | 0 |") -> String:
	return "\n".join(PackedStringArray([
		"## When they call",
		"",
		"| Event | Chance | Team gap (s) |",
		"|---|---|---|",
		when,
		"",
		"## Pace",
		"",
		"| Rule | Seconds |",
		"|---|---|",
		"| One bot's calls apart | 4 |",
		"| The team's calls apart | 1.5 |",
		"| The same enemy again after | 10 |",
		"| A call waits at most | 1.5 |",
		"",
		"## Marks",
		"",
		"| Rule | Value |",
		"|---|---|",
		"| A sighting is marked (chance) | 0.35 |",
		"| The team's marks apart (s) | 12 |",
		"",
		"## Personalities",
		"",
		"| Personality | Talks (×) |",
		"|---|---|",
		"| Rusher | 1.2 |",
		"| Careful | 0.8 |",
		"",
		"## Lines",
		"",
		"| Event | Who | Line |",
		"|---|---|---|",
		lines,
		"| Down | Any | {left} left! |",
	]))


## A file's problems besides the events it leaves out on purpose.
static func _besides_missing(problems: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for p in problems:
		if not p.contains("When they call: no row for"):
			out.append(p)
	return out


static func _any(problems: Array[String], part: String) -> bool:
	for p in problems:
		if p.contains(part):
			return true
	return false


static func _texts(lines: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for l: CalloutsFile.Line in lines:
		out.append(l.text)
	return out


func test_the_shipped_file_reads_clean_against_bots_md_and_is_the_file_the_game_loads() -> void:
	var read := CalloutsFile.read_file(CalloutsFile.PATH, BotsFile.shared().kinds)
	assert_eq(read.problems, [] as Array[String])
	var shared := CalloutsFile.shared()
	assert_eq(shared.problems, [] as Array[String])
	for e in E.size():
		assert_eq(shared.rules[e].priority, read.rules[e].priority, CalloutsFile.EVENT_NAMES[e])
		assert_eq(shared.rules[e].chance, read.rules[e].chance, CalloutsFile.EVENT_NAMES[e])


func test_the_shipped_file_rules_every_event_with_an_any_line_and_talks_for_every_personality() -> void:
	var f := CalloutsFile.shared()
	for e in E.size():
		assert_gt(f.rules[e].chance, 0.0, CalloutsFile.EVENT_NAMES[e])
		var any := false
		for l: CalloutsFile.Line in f.lines[e]:
			any = any or l.who == &""
		assert_true(any, "%s has an Any line" % CalloutsFile.EVENT_NAMES[e])
	for key in BotsFile.shared().kinds:
		assert_gt(f.talks.get(key, 0.0), 0.0, key)


func test_the_shipped_file_keeps_the_urgent_calls_first() -> void:
	var r := CalloutsFile.shared().rules
	assert_lt(r[E.LAST_ONE].priority, r[E.DOWN].priority)
	assert_lt(r[E.DOWN].priority, r[E.CONTACT].priority)
	assert_lt(r[E.CONTACTS].priority, r[E.CONTACT].priority)
	assert_lt(r[E.CONTACT].priority, r[E.CHECKING].priority)
	# Flash out before all (its bang is a moment off, BC1); the answers to your ping after every hit's call, before
	# every other.
	assert_eq(r[E.FLASH_OUT].priority, 0)
	var hits := maxi(r[E.LAST_ONE].priority, maxi(r[E.DOWN].priority, r[E.TAGGED].priority))
	assert_lt(hits, r[E.PING_GOING].priority)
	assert_lt(r[E.PING_GOING].priority, r[E.PING_WATCHING].priority)
	var first: Array[int] = [E.FLASH_OUT, E.LAST_ONE, E.DOWN, E.TAGGED, E.PING_GOING, E.PING_WATCHING]
	for e in E.size():
		if not first.has(e):
			assert_lt(r[E.PING_WATCHING].priority, r[e].priority, CalloutsFile.EVENT_NAMES[e])


func test_the_shipped_file_has_a_line_without_an_area_for_events_that_can_come_without_one() -> void:
	var f := CalloutsFile.shared()
	for e: int in [E.LAST_ONE, E.PING_GOING, E.PING_WATCHING]:
		var found := false
		for l: CalloutsFile.Line in f.lines[e]:
			found = found or (l.who == &"" and not l.needs_area)
		assert_true(found, CalloutsFile.EVENT_NAMES[e])


func test_the_shipped_file_marks_some_sightings_and_never_every_one() -> void:
	var f := CalloutsFile.shared()
	assert_gt(f.marks.chance, 0.0)
	assert_lt(f.marks.chance, 1.0)
	assert_gt(f.marks.gap, f.pace.team_gap)


func test_the_shipped_file_has_magazine_lines_for_every_voice_and_asks_always() -> void:
	var f := CalloutsFile.shared()
	for e: int in [E.NEED_MAG, E.MAG_COMING, E.MAG_THANKS]:
		assert_gt(f.lines[e].size(), 0, CalloutsFile.EVENT_NAMES[e])
		for l: CalloutsFile.Line in f.lines[e]:
			assert_lte(l.text.length(), CalloutsFile.LINE_MAX, l.text)
			assert_false(l.text.contains("{") or l.text.contains("}"), l.text)
		for key in BotsFile.shared().kinds:
			var has := false
			for l: CalloutsFile.Line in f.lines[e]:
				has = has or l.who == key
			assert_true(has, "%s / %s" % [CalloutsFile.EVENT_NAMES[e], key])
	assert_eq(f.rules[E.NEED_MAG].chance, 1.0)
	assert_eq(f.rules[E.MAG_COMING].chance, 1.0)
	assert_gt(f.rules[E.MAG_THANKS].chance, 0.0)


func test_reads_chances_gaps_pace_talks_and_lines_the_row_order_the_priority() -> void:
	var read := CalloutsFile.parse(_file(), PEOPLE)
	assert_eq(_besides_missing(read.problems), [] as Array[String])
	assert_eq(read.problems.size(), E.size() - 2)
	assert_eq(read.rules[E.CONTACT].chance, 1.0)
	assert_eq(read.rules[E.CONTACT].team_gap, 3.0)
	assert_eq(read.rules[E.CONTACT].priority, 0)
	assert_eq(read.rules[E.DOWN].chance, 0.5)
	assert_eq(read.rules[E.DOWN].team_gap, 0.0)
	assert_eq(read.rules[E.DOWN].priority, 1)
	assert_eq([read.pace.bot_gap, read.pace.team_gap, read.pace.same_enemy_gap, read.pace.max_wait],
			[4.0, 1.5, 10.0, 1.5])
	assert_almost_eq(read.talks[&"careful"], 0.8, 1e-6)
	assert_eq(read.lines[E.CONTACT].size(), 1)
	var line: CalloutsFile.Line = read.lines[E.CONTACT][0]
	assert_eq([line.who, line.text, line.needs_area], [&"", "Contact, {area}!", true])


func test_never_throws_and_reports_each_bad_row_with_its_line() -> void:
	var empty := CalloutsFile.parse("", PEOPLE)
	assert_true(_any(empty.problems, "no \"When they call\" table"))
	var bad := CalloutsFile.parse(_file("| Contact | Any | Contact, {area}! |",
			"| Contact | 2 | 3 |\n| Shouting | 1 | 1 |\n| Down | 0.5 | -1 |"), PEOPLE)
	assert_true(_any(bad.problems, "callouts.md:5: Chance: \"2\""), str(bad.problems))
	assert_true(_any(bad.problems, "callouts.md:6: \"Shouting\" is not an event"), str(bad.problems))
	assert_true(_any(bad.problems, "Team gap (s): \"-1\""), str(bad.problems))
	# An event without a row is never called.
	assert_eq(bad.rules[E.CONTACT].chance, 0.0)
	assert_eq(bad.rules[E.HEARD].chance, 0.0)


func test_leaves_out_a_line_with_a_wrong_fill_a_stray_brace_one_too_long_or_an_unknown_voice() -> void:
	var rows := "\n".join(PackedStringArray([
		"| Contact | Any | Contact, {area}! |",
		"| Contact | Any | {left} left, {area}! |",
		"| Contact | Any | Contact, {place}! |",
		"| Contact | Any | Contact { |",
		"| Contact | Any | %s{area}! |" % "a".repeat(CalloutsFile.LINE_MAX - MapAreas.NAME_MAX_LENGTH),
		"| Contact | Sniper | Contact, {area}! |",
	]))
	var read := CalloutsFile.parse(_file(rows), PEOPLE)
	assert_eq(_texts(read.lines[E.CONTACT]), PackedStringArray(["Contact, {area}!"]))
	var problems := _besides_missing(read.problems)
	assert_eq(problems.size(), 5, str(problems))
	assert_true(_any(problems, "\"{left}\" is not filled in for this event"))
	assert_true(_any(problems, "\"{place}\" is not something a line fills in"))
	assert_true(_any(problems, "a brace with nothing to fill in"))
	assert_true(_any(problems, "is too long (49 characters"))
	assert_true(_any(problems, "Who: \"Sniper\" is not Any or a personality"))


func test_reads_the_marks_and_reports_a_bad_unknown_doubled_or_missing_rule_keeping_its_fallback() -> void:
	var read := CalloutsFile.parse(_file(), PEOPLE)
	assert_eq([read.marks.chance, read.marks.gap], [0.35, 12.0])
	var bad := CalloutsFile.parse(_file().replace("| A sighting is marked (chance) | 0.35 |",
			"| A sighting is marked (chance) | 1.5 |\n| Marked twice | 1 |"), PEOPLE)
	assert_eq(bad.marks.chance, 0.35)
	assert_true(_any(bad.problems, "A sighting is marked (chance): \"1.5\" is not"))
	assert_true(_any(bad.problems, "\"Marked twice\" is not a marks rule"))
	assert_true(_any(bad.problems, "Marks: no row for A sighting is marked (chance), so it is 0.35"))
	var twice := CalloutsFile.parse(_file().replace("| The team's marks apart (s) | 12 |",
			"| The team's marks apart (s) | 12 |\n| The team's marks apart (s) | 3 |"), PEOPLE)
	assert_eq(twice.marks.gap, 12.0)
	assert_eq(_besides_missing(twice.problems).size(), 1)
	var text := _file()
	var none := CalloutsFile.parse(text.substr(0, text.find("## Marks")) + text.substr(text.find("## Personalities")),
			PEOPLE)
	assert_eq([none.marks.chance, none.marks.gap], [0.35, 12.0])
	assert_true(_any(none.problems, "no \"Marks\" table"))


func test_reports_a_personality_the_file_leaves_out_and_one_bots_md_lacks() -> void:
	var three: Array[StringName] = [&"rusher", &"careful", &"anchor"]
	assert_true(_any(CalloutsFile.parse(_file(), three).problems, "no row for anchor, so it talks × 1"))
	var one: Array[StringName] = [&"rusher"]
	assert_true(_any(CalloutsFile.parse(_file(), one).problems, "\"Careful\" is not in bots.md"))


func test_a_missing_file_says_so_and_calls_nothing() -> void:
	var none := CalloutsFile.read_file("res://data/no-such-callouts.md", PEOPLE)
	assert_eq(none.problems.size(), 1)
	for e in E.size():
		assert_eq(none.rules[e].chance, 0.0)


func test_fills_the_area_in_and_numbers_as_words_a_capital_only_where_a_sentence_starts() -> void:
	assert_eq(CalloutsFile.fill_line("Contact, {area}!", "Dock", 0, 0), "Contact, Dock!")
	assert_eq(CalloutsFile.fill_line("{count}, {area}!", "Bay", 3, 0), "Three, Bay!")
	assert_eq(CalloutsFile.fill_line("Contact, {count}, {area}!", "Bay", 2, 0), "Contact, two, Bay!")
	assert_eq(CalloutsFile.fill_line("Got one! {left} left.", "", 0, 2), "Got one! Two left.")
	assert_eq(CalloutsFile.fill_line("{area} is clear", "back lot", 0, 0), "Back lot is clear")
	assert_eq(CalloutsFile.fill_line("Got one. {area} is clear", "back lot", 0, 0), "Got one. Back lot is clear",
			"an area starting a later sentence is a capital too")


func test_says_numbers_to_twelve_in_words_and_digits_past_it() -> void:
	assert_eq(CalloutsFile.number_word(1), "One")
	assert_eq(CalloutsFile.number_word(12), "Twelve")
	assert_eq(CalloutsFile.number_word(13), "13")
	assert_eq(CalloutsFile.number_word(2, false), "two")
