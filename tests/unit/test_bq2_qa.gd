extends GutTest
## BQ2 · QA's hunt for the asks (Callouts › _watch_asks, Pings.ask): no player (all-bot matches), your team being the
## second one, two bots in the same fight, a stand-off whose enemy dropped out, a Go round spot with no nav or walls,
## and the order of a mark and an ask. Fresh objects only: the shared callouts file is never changed.

const DT := 1.0 / 60.0
const E := CalloutsFile.Event
const YOU := 0

var state: GameState = null
var world: BotWorld = null
var director: Callouts = null
var pings: Pings = null


## You (character 0) and bots 1 and 2 on `mates_team`, bots 3 and 4 on the other; `file` is the callouts to play.
func _rig(file: CalloutsFile, mates_team: int = 0, nav: NavGrid = null) -> void:
	state = GameState.new(1)
	state.time = 10.0
	world = BotWorld.new()
	world.time = state.time
	var config := BotConfig.new()
	var spots: Array[Vector3] = [
		Vector3(-18.0, 0.0, -18.0), Vector3.ZERO, Vector3(0.0, 0.0, 4.0), Vector3(12.0, 0.0, 0.0),
		Vector3(12.0, 0.0, 3.0),
	]
	for id in 5:
		var team := mates_team if id < 3 else 1 - mates_team
		var c := Character.new(id, team, spots[id], 0.0, ReplicaStats.default_loadout())
		c.position = spots[id]
		state.characters.append(c)
		if id > 0:
			var b := Bot.new(c, id + 1, config.skill, 8)
			b.personality = &"careful"
			b.style = BotsFile.shared().style(&"careful")
			for k in 5:
				b.contacts.append(Bot.Contact.new())
			world.bots.append(b)
	world.characters = state.characters
	world.tuning = SimTuning.load_default()
	world.cfg = config
	world.nav = nav
	pings = Pings.new(state.characters, PingConfig.new())
	director = Callouts.new(file, CalloutConfig.new(), [] as Array[MapAreas.Area], 7)
	director.pings = pings
	director.you = state.characters[YOU]
	_tick()


func _file(changes: Dictionary = {}) -> CalloutsFile:
	var text := FileAccess.get_file_as_string(CalloutsFile.PATH)
	for from: String in changes:
		assert_true(text.contains(from), from)
		text = text.replace(from, changes[from])
	return CalloutsFile.parse(text, BotsFile.shared().kinds)


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


## Bots `ids` fight `enemies` for `seconds`; everything said.
func _fight(ids: Array[int], enemies: Array[int], seconds: float) -> PackedStringArray:
	var out := PackedStringArray()
	for id in ids:
		var b := world.bots[id - 1]
		b.mode = Bot.Mode.FIGHT
		b.target_visible = true
		b.target_id = enemies[0]
		for e in enemies:
			if b.contacts[e].first_seen_at < state.time - 1.0e6:
				b.contacts[e].first_seen_at = state.time
		b.contact = b.contacts[enemies[0]]
	var t := 0.0
	while t < seconds:
		for id in ids:
			var b := world.bots[id - 1]
			for e in enemies:
				b.contacts[e].seen_at = state.time + DT
			b.last_threat_at = state.time + DT
		out.append_array(_tick())
		t += DT
	return out


func _floor_nav() -> NavGrid:
	var m := MapData.new()
	var b := MapData.Block.new()
	b.kind = &"floor"
	b.center = Vector3(0.0, -0.25, 0.0)
	b.size = Vector3(40.0, 0.5, 40.0)
	m.blocks.append(b)
	var tuning := SimTuning.load_default()
	return NavGrid.build(m, tuning.nav, tuning.body)


func test_with_no_player_nobody_asks_and_nothing_breaks() -> void:
	_rig(_file())
	director.you = null
	var said := _fight([1, 2], [3, 4], 12.0)
	said.append_array(_tick([{"kind": GameEvent.Kind.FLAG_ROPE, "value": 1, "position": Vector3(3.0, 0.0, 3.0)}]))
	for s in said:
		assert_false(s.ends_with("Need help") or s.ends_with("Go round") or s.ends_with("Cover me"), s)
	assert_false(pings.asking(1, state.time))


func test_when_you_are_on_the_second_team_its_bots_ask_and_the_first_team_never_does() -> void:
	_rig(_file(), 1)
	var said := _fight([1, 2], [3, 4], 0.5)
	assert_eq(said.count("1: Need help") + said.count("2: Need help"), 1, str(said))
	assert_false(pings.asking(3, state.time))
	assert_false(pings.asking(4, state.time))


func test_two_bots_in_the_same_fight_make_one_ask_in_the_gap() -> void:
	_rig(_file())
	var said := _fight([1, 2], [3, 4], 3.0)
	assert_eq(said.count("1: Need help") + said.count("2: Need help"), 1, str(said))
	said = _fight([1, 2], [3, 4], 20.0)
	assert_eq(said.count("1: Need help") + said.count("2: Need help"), 0, "none more within the gap: %s" % str(said))
	var up := 0
	for id: int in [1, 2]:
		up += 1 if pings.asking(id, state.time) else 0
	assert_eq(up, 0, "the first ask lapsed and no second one was made")


func test_a_stand_off_against_an_enemy_who_went_down_does_not_ask() -> void:
	_rig(_file(), 0, _floor_nav())
	var enemy := state.characters[3]
	enemy.status = Character.Status.CALLING
	var said := _fight([1], [3], 12.0)
	assert_false(said.has("1: Go round"), str(said))


func test_a_stand_off_with_no_nav_asks_nothing() -> void:
	_rig(_file())
	var said := _fight([1], [3], 12.0)
	assert_false(said.has("1: Go round"), str(said))


func test_a_stand_off_with_the_enemy_on_top_of_the_bot_asks_nothing_and_does_not_throw() -> void:
	_rig(_file(), 0, _floor_nav())
	state.characters[3].position = state.characters[1].position
	var said := _fight([1], [3], 12.0)
	assert_false(said.has("1: Go round"), str(said))


func test_a_go_round_spot_is_on_the_nav_grid() -> void:
	var nav := _floor_nav()
	_rig(_file(), 0, nav)
	var said := _fight([1], [3], 12.0)
	assert_true(said.has("1: Go round"), str(said))
	var spot := pings.of(1).spot
	assert_true(SquadOrders.is_spot(spot))
	assert_gte(nav.nearest_walkable(spot, 0.2), 0, "on a walkable node")


func test_a_contact_call_while_the_ask_is_up_does_not_mark_over_it() -> void:
	_rig(_file({"| A sighting is marked (chance) | 0.35 |": "| A sighting is marked (chance) | 1 |"}))
	pings.ask(state.characters[1], Vector3.ZERO, Pings.Ask.HELP, state.time)
	var b := world.bots[0]
	b.contacts[3].seen_at = state.time
	var said := Callouts.Pending.new()
	said.event = E.CONTACT
	said.enemy = 3
	director._mark(director._teams[0], said, b, state, world)
	assert_eq(pings.of(1).ask, Pings.Ask.HELP, "the ask is still the bot's ping")
	# Once the ask has lapsed the same call marks as before.
	state.time += PingConfig.new().lifetime + 1.0
	director._now = state.time
	b.contacts[3].seen_at = state.time
	director._mark(director._teams[0], said, b, state, world)
	assert_eq(pings.of(1).kind, Pings.Kind.CONTACT)
	assert_eq(pings.of(1).ask, Pings.Ask.NONE)


func test_an_ask_waiting_when_the_round_restarts_is_never_said() -> void:
	_rig(_file())
	var pole := Vector3(4.0, 0.0, 6.0)
	state.round_state.attackers = 0
	# Keep the team talking so the ask waits in the queue, then restart the round in the same tick.
	director._teams[0].said_at = state.time
	var said := _tick([
		{"kind": GameEvent.Kind.FLAG_ROPE, "value": 1, "position": pole},
		{"kind": GameEvent.Kind.ROUND_START},
	])
	said.append_array(_tick())
	assert_eq(said.size(), 0, str(said))


func test_you_going_out_after_an_ask_is_offered_but_before_it_is_said_cancels_it() -> void:
	_rig(_file())
	var pole := Vector3(4.0, 0.0, 6.0)
	state.round_state.attackers = 0
	director._teams[0].said_at = state.time + 0.5
	var said := _tick([{"kind": GameEvent.Kind.FLAG_ROPE, "value": 1, "position": pole}])
	state.characters[YOU].status = Character.Status.CALLING
	for n in 120:
		said.append_array(_tick())
	assert_false(said.has("1: Cover me") or said.has("2: Cover me"), str(said))
