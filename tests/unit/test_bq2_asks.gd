extends GutTest
## BQ2 · Bot teammates ask for you: a bot on your team in a fight with more than it can take on, in a stand-off, or on
## the pole as the flag goes up calls Need help, Go round or Cover me and pings the spot for you (Callouts' asks,
## data/callouts.md › Asks; Pings.ask), only while you are in play and far off, at most once in the Asks gap and a few
## times a round. The other team's bots never ask; nobody plays differently for an ask.

const DT := 1.0 / 60.0
const E := CalloutsFile.Event
const YOU := 0
const MATE := 1
## Where you stand, far from the fight; where your bot teammate fights; where its enemies stand.
const YOU_AT := Vector3(-18.0, 0.0, -18.0)
const MATE_AT := Vector3(0.0, 0.0, 0.0)
const ENEMY_AT := Vector3(12.0, 0.0, 0.0)

var state: GameState = null
var world: BotWorld = null
var director: Callouts = null
var pings: Pings = null
var file: CalloutsFile = CalloutsFile.shared()
var _nav: NavGrid = null


## You (character 0, nobody's bot) and bot 1 on team 0 in the open, bots 2 and 3 on team 1; the shipped callouts.md.
## With `nav`, a 40 m floor's nav grid for Go round's spots.
func _rig(nav: bool = false) -> void:
	state = GameState.new(1)
	state.time = 10.0
	world = BotWorld.new()
	world.time = state.time
	var config := BotConfig.new()
	var spots: Array[Vector3] = [YOU_AT, MATE_AT, ENEMY_AT, ENEMY_AT + Vector3(0.0, 0.0, 3.0)]
	for id in 4:
		var c := Character.new(id, 0 if id < 2 else 1, spots[id], 0.0, ReplicaStats.default_loadout())
		c.position = spots[id]
		state.characters.append(c)
		if id > 0:
			var b := Bot.new(c, id + 1, config.skill, 8)
			b.personality = &"careful"
			b.style = BotsFile.shared().style(&"careful")
			world.bots.append(b)
	world.characters = state.characters
	world.tuning = SimTuning.load_default()
	world.cfg = config
	if nav:
		world.nav = _floor_nav()
	pings = Pings.new(state.characters, PingConfig.new())
	director = Callouts.new(file, CalloutConfig.new(), [] as Array[MapAreas.Area], 7)
	director.pings = pings
	director.you = state.characters[YOU]
	_tick()


func _floor_nav() -> NavGrid:
	if _nav == null:
		var m := MapData.new()
		var b := MapData.Block.new()
		b.kind = &"floor"
		b.center = Vector3(0.0, -0.25, 0.0)
		b.size = Vector3(40.0, 0.5, 40.0)
		m.blocks.append(b)
		var tuning := SimTuning.load_default()
		_nav = NavGrid.build(m, tuning.nav, tuning.body)
	return _nav


func _bot(id: int) -> Bot:
	return world.bots[id - 1]


## One tick: time moves on, `events` happen and the director looks; what was said, as "speaker: event".
func _tick(events: Array[Dictionary] = []) -> PackedStringArray:
	state.time += DT
	world.time = state.time
	state.events.clear()
	for d in events:
		var e := state.events.add(d["kind"])
		e.actor = d.get("actor", -1)
		e.value = d.get("value", 0)
		e.position = d.get("position", Vector3.ZERO)
	var from := director.said.total
	director.observe(state, world)
	var out := PackedStringArray()
	for n in range(from, director.said.total):
		var c := director.said.entry(n)
		out.append("%d: %s" % [c.speaker_id, CalloutsFile.EVENT_NAMES[c.event]])
	return out


## Ticks for `seconds` while bot `id` fights `enemies` (character ids) in sight; everything said.
func _fight(id: int, enemies: Array[int], seconds: float) -> PackedStringArray:
	var out := PackedStringArray()
	var t := 0.0
	var b := _bot(id)
	b.mode = Bot.Mode.FIGHT
	b.target_visible = true
	b.target_id = enemies[0]
	for e in enemies:
		var c := b.contacts[e]
		if c.first_seen_at < state.time - 1.0e6:
			c.first_seen_at = state.time
	b.contact = b.contacts[enemies[0]]
	while t < seconds:
		for e in enemies:
			b.contacts[e].seen_at = state.time + DT
		b.last_threat_at = state.time + DT
		out.append_array(_tick())
		t += DT
	return out


func _contacts_for(b: Bot) -> void:
	b.contacts.resize(4)
	for i in 4:
		if b.contacts[i] == null:
			b.contacts[i] = Bot.Contact.new()


func before_each() -> void:
	_rig()
	_contacts_for(_bot(MATE))
	_contacts_for(_bot(2))


func test_the_shipped_file_reads_its_asks_and_has_lines_for_each() -> void:
	assert_eq(file.problems, [] as Array[String])
	assert_eq(file.asks.gap, 30.0)
	assert_eq(int(file.asks.per_round), 3)
	assert_eq(file.asks.you_further, 15.0)
	for e: int in [E.NEED_HELP, E.GO_ROUND, E.COVER_ME]:
		assert_eq(file.rules[e].chance, 1.0, CalloutsFile.EVENT_NAMES[e])
		var any := false
		for l: CalloutsFile.Line in file.lines[e]:
			any = any or l.who == &""
			assert_lte(l.text.length() + (8 if l.needs_area else 0), CalloutsFile.LINE_MAX, l.text)
		assert_true(any, CalloutsFile.EVENT_NAMES[e])


func test_a_teammate_fighting_two_asks_you_over_and_pings_where_it_is() -> void:
	var said := _fight(MATE, [2, 3], 0.5)
	assert_true(said.has("%d: Need help" % MATE), str(said))
	var p := pings.of(MATE)
	assert_true(pings.is_up(p, state.time))
	assert_eq(p.ask, Pings.Ask.HELP)
	assert_eq(p.kind, Pings.Kind.SPOT)
	assert_eq(p.team, 0)
	assert_almost_eq(p.spot.x, MATE_AT.x, 0.01)
	assert_true(pings.asking(MATE, state.time))


func test_one_enemy_is_no_reason_to_ask_for_help() -> void:
	var said := _fight(MATE, [2], 2.0)
	assert_false(said.has("%d: Need help" % MATE), str(said))
	assert_false(pings.asking(MATE, state.time))


func test_nobody_asks_you_over_when_you_are_close() -> void:
	state.characters[YOU].position = MATE_AT + Vector3(5.0, 0.0, 0.0)
	var said := _fight(MATE, [2, 3], 1.0)
	assert_false(said.has("%d: Need help" % MATE), str(said))


func test_nobody_asks_once_you_are_out() -> void:
	state.characters[YOU].status = Character.Status.CALLING
	var said := _fight(MATE, [2, 3], 1.0)
	assert_false(said.has("%d: Need help" % MATE), str(said))


func test_the_other_teams_bots_never_ask() -> void:
	var said := _fight(2, [YOU, MATE], 1.0)
	assert_false(said.has("2: Need help"), str(said))
	assert_false(pings.asking(2, state.time))


func test_the_team_asks_at_most_once_in_its_gap_and_a_few_times_a_round() -> void:
	var asked := 0
	var t := 0.0
	var said := PackedStringArray()
	# Two minutes of being outnumbered: the gap lets one ask in every 30 s, the round at most three.
	while t < 120.0:
		said = _fight(MATE, [2, 3], 1.0)
		asked += said.count("%d: Need help" % MATE)
		t += 1.0
	assert_eq(asked, int(file.asks.per_round))
	# A new round starts the count afresh.
	said = _tick([{"kind": GameEvent.Kind.ROUND_START}])
	said.append_array(_fight(MATE, [2, 3], 0.5))
	assert_true(said.has("%d: Need help" % MATE), str(said))


func test_a_stand_off_asks_you_to_go_round_to_a_spot_beside_the_enemy() -> void:
	world.nav = _floor_nav()
	var said := _fight(MATE, [2], file.asks.stand_off + 1.0)
	assert_true(said.has("%d: Go round" % MATE), str(said))
	var p := pings.of(MATE)
	assert_eq(p.ask, Pings.Ask.GO)
	# Beside the enemy across the line from your teammate, on your side (you stand at -z).
	assert_almost_eq(p.spot.x, ENEMY_AT.x, 1.0)
	assert_almost_eq(p.spot.z, ENEMY_AT.z - file.asks.round_offset, 1.0)


func test_raising_the_flag_asks_you_to_cover_the_pole_and_defending_it_to_help() -> void:
	var pole := Vector3(4.0, 0.0, 6.0)
	state.round_state.attackers = 0
	var said := _tick([{"kind": GameEvent.Kind.FLAG_ROPE, "value": 1, "position": pole}])
	said.append_array(_tick())
	assert_true(said.has("%d: Cover me" % MATE), str(said))
	assert_eq(pings.of(MATE).ask, Pings.Ask.COVER)
	assert_almost_eq(pings.of(MATE).spot.x, pole.x, 0.01)
	_tick([{"kind": GameEvent.Kind.ROUND_START}])
	state.round_state.attackers = 1
	said = _tick([{"kind": GameEvent.Kind.FLAG_ROPE, "value": 1, "position": pole}])
	said.append_array(_tick())
	assert_true(said.has("%d: Need help" % MATE), str(said))
	assert_eq(pings.of(MATE).ask, Pings.Ask.HELP)


func test_a_press_or_a_mark_is_no_ask_and_a_new_round_clears_one() -> void:
	pings.ask(state.characters[MATE], MATE_AT, Pings.Ask.GO, state.time)
	assert_true(pings.asking(MATE, state.time))
	assert_true(pings.of(MATE).marked, "a teammate's, not your press")
	pings.mark(state.characters[MATE], state.characters[2], state.time + 1.0, world)
	assert_eq(pings.of(MATE).ask, Pings.Ask.NONE, "a mark is no ask")
	pings.ask(state.characters[MATE], MATE_AT, Pings.Ask.HELP, state.time)
	pings.clear()
	assert_false(pings.asking(MATE, state.time))
	assert_eq(pings.of(MATE).ask, Pings.Ask.NONE)


func test_an_asks_marker_says_what_it_asks() -> void:
	var m := HudPingMarker.new()
	add_child_autofree(m)
	m.setup(HudConfig.new())
	m.visible = true
	m.set_ping(Pings.Kind.SPOT, Color.BLUE, 20, Pings.Ask.HELP)
	assert_eq(m.text(), "HELP · 20 M")
	m.set_ping(Pings.Kind.SPOT, Color.BLUE, 20, Pings.Ask.GO)
	assert_eq(m.text(), "GO · 20 M")
	m.set_ping(Pings.Kind.SPOT, Color.BLUE, 20, Pings.Ask.COVER)
	assert_eq(m.text(), "COVER · 20 M")
	m.set_ping(Pings.Kind.SPOT, Color.BLUE, 20)
	assert_eq(m.text(), "PING · 20 M")
