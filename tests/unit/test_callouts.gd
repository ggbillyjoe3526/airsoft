extends GutTest
## The bots' callouts read off what they do (CO1, game/ai/callouts.gd; the browser game's ai/callouts.test.ts, CL1):
## which call is said (the more urgent first, the right line) and the pace: one at a time per team, the team's, the
## bot's and the same enemy's gaps, a held call dropped after its wait. The director reads and writes nothing else.

const DT := 1.0 / 60.0
const E := CalloutsFile.Event
## Every event's one Any line here, by Event.
const LINES: PackedStringArray = [
	"Contact, {area}!", "{count}, {area}!", "Movement, {area}.", "{left} left!", "Last one!", "Tagged!", "Reloading!",
	"Pushing {area}!", "Flanking {area}.", "Checking {area}.", "Holding {area}.", "Raising!", "Flag!",
	"Overtime, {area}!", "Going to {area}.", "Watching {area}.", "Need a mag!", "Mag coming!", "Thanks for the mag!",
	"Need help!", "Go round!", "Cover me!",
]
## The shipped order of urgency.
const ORDER: Array[int] = [
	E.LAST_ONE, E.DOWN, E.TAGGED, E.PING_GOING, E.PING_WATCHING, E.NEED_MAG, E.MAG_COMING, E.NEED_HELP, E.COVER_ME,
	E.GO_ROUND, E.OVERTIME, E.FLAG,
	E.RAISING, E.CONTACTS, E.CONTACT, E.RELOADING, E.MAG_THANKS, E.HEARD, E.PUSHING, E.FLANKING, E.CHECKING,
	E.HOLDING,
]
const DOCK := Vector3(10.0, 0.0, -10.0)
const BAY := Vector3(10.0, 0.0, 10.0)
const YARD := Vector3(-10.0, 0.0, 0.0)


## Two a side: team 0 are bots 0 (a rusher) and 1 (careful), team 1 bots 2 (a rusher) and 3 (careful), in that order in
## the bots. Everyone stands in the Yard until a test moves them.
class Rig:
	extends RefCounted
	var state: GameState = null
	var world: BotWorld = BotWorld.new()
	var director: Callouts = null
	var _events: Array[Dictionary] = []

	func _init(file: CalloutsFile) -> void:
		state = GameState.new(1)
		state.time = 10.0
		var config := BotConfig.new()
		var people: Array[StringName] = [&"rusher", &"careful", &"rusher", &"careful"]
		for id in people.size():
			var c := Character.new(id, 0 if id < 2 else 1, YARD, 0.0, ReplicaStats.default_loadout())
			c.position = YARD
			state.characters.append(c)
			var b := Bot.new(c, id + 1, config.skill, 8)
			b.personality = people[id]
			b.style = BotsFile.shared().style(people[id])
			world.bots.append(b)
		world.characters = state.characters
		director = Callouts.new(file, CalloutConfig.new(), _areas(), 7)
		tick() # the director's first look sizes its memory

	static func _areas() -> Array[MapAreas.Area]:
		var out: Array[MapAreas.Area] = []
		for spec: Array in [["Dock", 0.0, 20.0, -20.0, 0.0], ["Bay", 0.0, 20.0, 0.0, 20.0],
				["Yard", -20.0, 0.0, -20.0, 20.0]]:
			var a := MapAreas.Area.new()
			a.name = spec[0]
			a.x0 = spec[1]
			a.x1 = spec[2]
			a.z0 = spec[3]
			a.z1 = spec[4]
			out.append(a)
		return out

	func bot(i: int) -> Bot:
		return world.bots[i]

	## One tick: time moves on, these events happen, and the director looks; what it said, as "speaker: line".
	func tick(events: Array[Dictionary] = []) -> PackedStringArray:
		state.time += DT
		world.time = state.time
		state.events.clear()
		for d in events:
			var e := state.events.add(d["kind"])
			e.actor = d.get("actor", -1)
			e.target = d.get("target", -1)
			e.value = d.get("value", 0)
			e.position = d.get("position", Vector3.ZERO)
		var from := director.said.total
		director.observe(state, world)
		var out := PackedStringArray()
		for n in range(from, director.said.total):
			var c := director.said.entry(n)
			out.append("%d: %s" % [c.speaker_id, c.line])
		return out

	## Ticks for `seconds`, everything said in order.
	func run(seconds: float) -> PackedStringArray:
		var out := PackedStringArray()
		var t := 0.0
		while t < seconds:
			out.append_array(tick())
			t += DT
		return out

	## Bot `b` sees character `id` from the tick about to run (a fresh sighting), standing at `at`: its contact and its
	## last threat stamped, as sight does (BotSenses.perceive).
	func sees(b: int, id: int, at: Vector3 = DOCK) -> void:
		state.characters[id].position = at
		var c := bot(b).contacts[id]
		c.seen_at = state.time + DT
		c.first_seen_at = state.time + DT
		bot(b).last_threat_at = state.time + DT

	func loses(b: int, id: int) -> void:
		bot(b).contacts[id].seen_at = -INF

	## Character `victim` hit by `shooter` (it calls its hit): the event.
	func hit(victim: int, shooter: int) -> Dictionary:
		state.characters[victim].status = Character.Status.CALLING
		return {"kind": GameEvent.Kind.CHARACTER_HIT, "actor": shooter, "target": victim}


## A callouts.md with every event in the shipped order of urgency, always called unless `chance` says otherwise:
## `gap` each event's team gap, `pace` [bot, team, enemy, wait], `talks` [rusher, careful], `extra` more Lines rows.
static func _text(chance: Dictionary = {}, gap: Dictionary = {}, pace: Array = [4, 1.5, 10, 1.5],
		talks: Array = [1, 1], extra: String = "") -> String:
	var out := PackedStringArray(["## When they call", "| Event | Chance | Team gap (s) |", "|---|---|---|"])
	for e in ORDER:
		out.append("| %s | %s | %s |" % [CalloutsFile.EVENT_NAMES[e], chance.get(e, 1), gap.get(e, 0)])
	out.append_array(["", "## Pace", "| Rule | Seconds |", "|---|---|",
			"| One bot's calls apart | %s |" % pace[0], "| The team's calls apart | %s |" % pace[1],
			"| The same enemy again after | %s |" % pace[2], "| A call waits at most | %s |" % pace[3],
			"", "## Marks", "| Rule | Value |", "|---|---|", "| A sighting is marked (chance) | 0 |",
			"| The team's marks apart (s) | 12 |",
			"", "## Personalities", "| Personality | Talks (×) |", "|---|---|", "| Rusher | %s |" % talks[0],
			"| Careful | %s |" % talks[1], "", "## Lines", "| Event | Who | Line |", "|---|---|---|"])
	for e in ORDER:
		out.append("| %s | Any | %s |" % [CalloutsFile.EVENT_NAMES[e], LINES[e]])
	if extra != "":
		out.append(extra)
	return "\n".join(out)


func _rig(chance: Dictionary = {}, gap: Dictionary = {}, pace: Array = [4, 1.5, 10, 1.5], talks: Array = [1, 1],
		extra: String = "") -> Rig:
	var people: Array[StringName] = [&"rusher", &"careful"]
	var file := CalloutsFile.parse(_text(chance, gap, pace, talks, extra), people)
	assert_eq(file.problems, [] as Array[String])
	return Rig.new(file)


static func _said(lines: Array[String]) -> PackedStringArray:
	return PackedStringArray(lines)


static func _reload(id: int) -> Dictionary:
	return {"kind": GameEvent.Kind.RELOAD_START, "actor": id}


func test_calls_a_fresh_sighting_with_where_the_enemy_is_and_two_at_once_with_how_many() -> void:
	var r := _rig()
	r.sees(0, 2, DOCK)
	assert_eq(r.tick(), _said(["0: Contact, Dock!"]))
	var s := _rig()
	s.sees(1, 2, BAY)
	s.sees(1, 3, BAY)
	assert_eq(s.tick(), _said(["1: Two, Bay!"]))


func test_calls_a_hit_with_how_many_are_left_then_the_last_one_and_nothing_once_the_round_is_won() -> void:
	var r := _rig()
	assert_eq(r.tick([r.hit(2, 0)]), _said(["0: Last one!"]))
	var s := _rig({E.LAST_ONE: 0})
	assert_eq(s.tick([s.hit(2, 0)]), _said([]))
	var w := _rig()
	w.state.characters[3].status = Character.Status.OUT
	assert_eq(w.tick([w.hit(2, 0)]), _said([]))


func test_counts_those_left_in_words() -> void:
	var r := _rig()
	# A third on the other team: one hit leaves two.
	var c := Character.new(4, 1, YARD, 0.0, ReplicaStats.default_loadout())
	c.position = YARD
	r.state.characters.append(c)
	r.tick()
	assert_eq(r.tick([r.hit(2, 0)]), _said(["0: Two left!"]))


func test_has_the_hit_called_by_the_shooter_or_the_teammate_nearest_a_shooter_who_cant() -> void:
	var r := _rig()
	r.bot(0).character.position.x = 15.0 # far from where the hit comes from
	r.bot(1).character.position.x = -15.0
	var player := Character.new(5, 0, Vector3(-14.0, 0.0, 0.0), 0.0, ReplicaStats.default_loadout())
	player.position = Vector3(-14.0, 0.0, 0.0)
	r.state.characters.append(player)
	r.tick()
	assert_eq(r.tick([r.hit(2, 5)]), _said(["1: Last one!"]))


func test_calls_a_reload_only_with_a_threat_seen_or_heard_lately() -> void:
	var r := _rig()
	assert_eq(r.tick([_reload(0)]), _said([]))
	r.bot(0).last_threat_at = r.state.time
	assert_eq(r.tick([_reload(0)]), _said(["0: Reloading!"]))


func test_calls_setting_off_after_someone_a_rusher_pushes_a_flank_goes_round_anyone_else_checks() -> void:
	var r := _rig()
	r.bot(0).last_known = BAY
	r.bot(0).mode = Bot.Mode.SEARCH
	assert_eq(r.tick(), _said(["0: Pushing Bay!"]))
	var s := _rig()
	s.bot(1).last_known = DOCK
	s.bot(1).mode = Bot.Mode.SEARCH
	s.bot(1).flanking = true
	assert_eq(s.tick(), _said(["1: Flanking Dock."]))
	var t := _rig()
	t.bot(1).last_known = DOCK
	t.bot(1).mode = Bot.Mode.SEARCH
	assert_eq(t.tick(), _said(["1: Checking Dock."]))
	# Still searching: nothing new.
	assert_eq(t.run(5.0), _said([]))


func test_a_rusher_under_a_squad_order_checks_rather_than_pushes() -> void:
	var r := _rig()
	r.bot(0).order = SquadOrder.Kind.FOLLOW
	r.bot(0).last_known = BAY
	r.bot(0).mode = Bot.Mode.SEARCH
	assert_eq(r.tick(), _said(["0: Checking Bay."]))


func test_calls_a_hold_where_it_holds_once_a_round() -> void:
	var r := _rig()
	r.bot(1).character.position = BAY
	r.bot(1).at_post = true
	assert_eq(r.tick(), _said(["1: Holding Bay."]))
	r.bot(1).at_post = false
	r.run(1.0)
	r.bot(1).at_post = true
	assert_eq(r.run(10.0), _said([]))
	r.tick([{"kind": GameEvent.Kind.ROUND_START, "value": 2}])
	r.bot(1).at_post = false
	r.tick()
	r.bot(1).at_post = true
	assert_eq(r.tick(), _said(["1: Holding Bay."]))


func test_calls_a_noise_only_while_nobody_on_the_team_has_anyone_in_sight() -> void:
	var r := _rig()
	var b := r.bot(0)
	b.has_last_known = true
	b.last_known = DOCK
	b.heard_at = r.state.time + DT
	r.bot(1).target_visible = true
	assert_eq(r.tick(), _said([]))
	r.bot(1).target_visible = false
	b.heard_at = r.state.time + DT
	assert_eq(r.tick(), _said(["0: Movement, Dock."]))
	# Heard there again soon: not called again.
	b.heard_at = r.state.time + 2.0
	r.run(2.0)
	assert_eq(r.tick(), _said([]))


func test_has_the_attackers_call_the_flag_going_up_and_the_defenders_call_it_too() -> void:
	var r := _rig()
	r.state.round_state.attackers = 1
	var said := r.tick([{"kind": GameEvent.Kind.FLAG_ROPE, "value": 1, "position": BAY}])
	said.sort()
	assert_eq(said, _said(["0: Flag!", "2: Raising!"]))
	# Coming down is no call.
	var s := _rig()
	s.state.round_state.attackers = 1
	assert_eq(s.tick([{"kind": GameEvent.Kind.FLAG_ROPE, "value": 0, "position": BAY}]), _said([]))


func test_says_a_personalitys_own_lines_as_well_as_the_any_ones_never_anothers() -> void:
	var r := _rig({}, {}, [0, 0, 0, 1.5], [1, 1], "| Contact | Careful | Careful, {area}. |")
	var said := {}
	for i in 60:
		for b: int in [0, 1]:
			r.loses(b, 2)
			r.tick()
			r.sees(b, 2, DOCK)
			var out := r.tick()
			if not out.is_empty():
				said[out[0]] = true
	var keys := PackedStringArray(said.keys())
	keys.sort()
	assert_eq(keys, _said(["0: Contact, Dock!", "1: Careful, Dock.", "1: Contact, Dock!"]))


func test_never_calls_an_event_whose_chance_is_0_and_talks_raises_a_chance() -> void:
	var r := _rig({E.CONTACT: 0})
	r.sees(0, 2)
	assert_eq(r.tick(), _said([]))
	var s := _rig({E.RELOADING: 0.5}, {}, [0, 0, 10, 1.5], [2, 1])
	s.bot(0).last_threat_at = INF
	for i in 20:
		assert_eq(s.tick([_reload(0)]), _said(["0: Reloading!"]))


func test_says_nothing_between_rounds_and_a_hit_player_never_talks() -> void:
	var r := _rig()
	r.state.round_state.phase = RoundState.Phase.OVER
	r.sees(0, 2)
	assert_eq(r.tick(), _said([]))
	var s := _rig()
	s.state.characters[0].status = Character.Status.CALLING
	s.sees(0, 2)
	assert_eq(s.tick(), _said([]))


func test_calls_the_same_enemy_again_only_after_its_gap_whoever_sees_them() -> void:
	var r := _rig({}, {}, [0, 1.5, 10, 1.5])
	r.sees(0, 2)
	assert_eq(r.tick(), _said(["0: Contact, Dock!"]))
	r.run(2.0)
	r.sees(1, 2)
	assert_eq(r.tick(), _said([]))
	r.loses(0, 2)
	r.loses(1, 2)
	r.run(8.0)
	r.sees(0, 2)
	assert_eq(r.tick(), _said(["0: Contact, Dock!"]))


func test_keeps_one_bots_calls_apart_while_a_teammate_may_speak() -> void:
	var r := _rig()
	r.sees(0, 2)
	assert_eq(r.tick(), _said(["0: Contact, Dock!"]))
	r.run(2.0)
	r.sees(0, 3, BAY)
	assert_eq(r.tick(), _said([]))
	r.loses(0, 3)
	r.sees(1, 3, BAY)
	assert_eq(r.tick(), _said(["1: Contact, Bay!"]))


func test_says_one_call_a_team_at_a_time_the_more_urgent_first_the_other_after_the_team_gap() -> void:
	var r := _rig({}, {}, [4, 1.5, 10, 2])
	r.sees(1, 3, BAY)
	assert_eq(r.tick([r.hit(2, 0)]), _said(["0: Last one!"]))
	assert_eq(r.run(1.6), _said(["1: Contact, Bay!"]))


func test_drops_a_call_held_back_longer_than_its_wait() -> void:
	var r := _rig({}, {}, [4, 1.5, 10, 1])
	r.sees(1, 3, BAY)
	assert_eq(r.tick([r.hit(2, 0)]), _said(["0: Last one!"]))
	assert_eq(r.run(3.0), _said([]))


func test_drops_a_held_call_whose_caller_is_hit_before_it_is_said() -> void:
	var r := _rig({}, {}, [4, 1.5, 10, 2])
	r.sees(1, 3, BAY)
	assert_eq(r.tick([r.hit(2, 0)]), _said(["0: Last one!"]))
	r.tick()
	r.state.characters[1].status = Character.Status.CALLING
	assert_eq(r.run(3.0), _said([]))


func test_drops_a_count_still_waiting_once_a_newer_hit_puts_it_out_of_date() -> void:
	var r := _rig()
	r.sees(0, 2, DOCK)
	assert_eq(r.tick(), _said(["0: Contact, Dock!"]))
	assert_eq(r.tick([r.hit(2, 1)]), _said([])) # "Last one!" waits out the team gap...
	assert_eq(r.tick([r.hit(3, 0)]), _said([])) # ...and the round is won before it is said
	assert_eq(r.run(3.0), _said([]))


func test_keeps_each_event_its_own_team_gap() -> void:
	var r := _rig({}, {E.RELOADING: 5}, [0, 0, 10, 1.5])
	r.bot(0).last_threat_at = INF
	assert_eq(r.tick([_reload(0)]), _said(["0: Reloading!"]))
	r.run(4.0)
	assert_eq(r.tick([_reload(0)]), _said([]))
	r.run(1.1)
	assert_eq(r.tick([_reload(0)]), _said(["0: Reloading!"]))


func test_starts_each_round_afresh_nothing_waits_nothing_was_called() -> void:
	var r := _rig({}, {}, [4, 1.5, 10, 2])
	r.sees(0, 2)
	assert_eq(r.tick(), _said(["0: Contact, Dock!"]))
	r.sees(1, 3, BAY)
	r.tick()
	assert_eq(r.tick([{"kind": GameEvent.Kind.ROUND_START, "value": 2}]), _said([]))
	r.loses(0, 2)
	r.loses(1, 3)
	r.run(0.5)
	r.sees(1, 2)
	assert_eq(r.tick(), _said(["1: Contact, Dock!"]))


func test_replays_with_the_seed() -> void:
	var a := _rig({E.CONTACT: 0.5}, {}, [0, 0, 0, 1.5])
	var b := _rig({E.CONTACT: 0.5}, {}, [0, 0, 0, 1.5])
	var said_a := PackedStringArray()
	var said_b := PackedStringArray()
	for i in 40:
		for r: Rig in [a, b]:
			r.loses(0, 2)
			r.tick()
			r.sees(0, 2)
		said_a.append_array(a.tick())
		said_b.append_array(b.tick())
	assert_eq(said_a, said_b)
	assert_gt(said_a.size(), 5, "about half of 40")
	assert_lt(said_a.size(), 35, "about half of 40")


func test_reads_the_bots_and_the_state_and_writes_neither() -> void:
	var r := _rig()
	r.sees(0, 2)
	r.bot(1).mode = Bot.Mode.SEARCH
	r.bot(1).last_known = BAY
	r.bot(1).at_post = true
	r.state.time += DT
	var before := _snapshot(r)
	r.director.observe(r.state, r.world)
	assert_gt(r.director.said.total, 0, "it said something")
	assert_eq(_snapshot(r), before)


## What a tick could change of the bots and the state, as text.
static func _snapshot(r: Rig) -> String:
	var parts := PackedStringArray([str(r.state.rng.state), str(r.state.time), str(r.state.round_state.phase)])
	for c in r.state.characters:
		parts.append("%d %s %d %s" % [c.id, c.position, c.status, c.yaw])
	for b in r.world.bots:
		parts.append("%d %d %s %s %s %s %s %s %d" % [b.mode, b.rng.state, b.last_known, b.has_last_known, b.heard_at,
				b.at_post, b.flanking, b.last_threat_at, b.target_id])
		for c in b.contacts:
			parts.append("%s %s" % [c.seen_at, c.first_seen_at])
	return "\n".join(parts)


func test_the_log_keeps_the_newest_calls_in_a_fixed_ring() -> void:
	var ring := CalloutLog.new(3)
	assert_null(ring.entry(0))
	for i in 5:
		ring.add(i, i % 2, E.CONTACT, "Line %d" % i, float(i))
	assert_eq(ring.total, 5)
	assert_eq(ring.oldest(), 2)
	assert_null(ring.entry(1), "overwritten")
	assert_eq(ring.entry(2).line, "Line 2")
	assert_eq(ring.entry(4).speaker_id, 4)
	assert_null(ring.entry(5), "not said yet")


func test_a_warm_tick_makes_no_object_and_a_call_only_its_line() -> void:
	var r := _rig({}, {}, [0, 0, 0, 1.5])
	for i in 200:
		r.loses(0, 2)
		r.tick()
		r.sees(0, 2)
		r.tick()
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	var said := r.director.said.total
	for i in 200:
		r.loses(0, 2)
		r.tick()
		r.sees(0, 2)
		r.tick()
	var objects_after := Performance.get_monitor(Performance.OBJECT_COUNT)
	var memory_after := Performance.get_monitor(Performance.MEMORY_STATIC)
	assert_eq(r.director.said.total - said, 200, "a call every other tick")
	assert_eq(objects_after, objects, "no objects")
	assert_lte(memory_after, memory, "the ring's lines replaced, no more")
