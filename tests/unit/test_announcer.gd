extends GutTest
## Screen reader messages (AC6): Announcer's lines in the HUD's words for each event, the 0.3 s join window, nothing
## while off, and HudAnnounce's live region (polite, assertive for your hit and the match's result, off with no text).

const DT := 1.0 / 60.0
const YOU := 0
const MATE := 1
const ROOK := 2
const DASH := 3

var _teams := TeamConfig.new()
var _state: GameState = null


func before_each() -> void:
	_state = GameState.new()
	for i in 4:
		# You and a teammate in Alpha, two in Beta.
		_state.characters.append(Character.new(i, 0 if i < 2 else 1))


func _announcer() -> Announcer:
	var a := Announcer.new(_teams, _state.characters[YOU], 4)
	a.set_names(PackedStringArray(["", "Mags", "Rook", ""]))
	return a


func _hit(shooter: int, victim: int) -> void:
	var e := _state.events.add(GameEvent.Kind.CHARACTER_HIT)
	e.actor = shooter
	e.target = victim


func _event(kind: GameEvent.Kind, value: int, value2: int = 0) -> void:
	var e := _state.events.add(kind)
	e.value = value
	e.value2 = value2


## Runs `a` over the queued events, then lets the window close: the message out ("" for none).
func _out(a: Announcer) -> String:
	a.on_tick(_state)
	_state.events.clear()
	for i in 30:
		if a.advance(DT):
			return a.message()
	return ""


# --- the lines ---

func test_a_hit_feed_line_names_who_called_it_then_whose_bb() -> void:
	var a := _announcer()
	_hit(ROOK, MATE)
	assert_eq(_out(a), "Mags called HIT · Rook")
	assert_false(a.assertive(), "someone else's hit is polite")
	_hit(YOU, ROOK)
	assert_eq(_out(a), "Rook called HIT · You", "You for the player")
	_hit(MATE, DASH)
	assert_eq(_out(a), "Beta called HIT · Mags", "a nameless bot is its team's name, as the feed shows")


func test_the_feed_and_the_announcer_name_alike() -> void:
	var names := PackedStringArray(["", "Mags", "Rook", ""])
	var you := _state.characters[YOU]
	assert_eq(HudFeed.name_of(you, you, names, _teams), "You")
	assert_eq(HudFeed.name_of(_state.characters[ROOK], you, names, _teams), "Rook")
	assert_eq(HudFeed.name_of(_state.characters[DASH], you, names, _teams), "Beta")


func test_your_own_hit_is_its_own_assertive_line() -> void:
	var a := _announcer()
	_hit(ROOK, YOU)
	assert_eq(_out(a), "You're hit · Rook", "in place of the feed line")
	assert_true(a.assertive())


func test_a_hit_with_no_shooter_says_nothing() -> void:
	var a := _announcer()
	_hit(-1, MATE)
	assert_eq(_out(a), "", "the feed shows no line either")


func test_a_round_start_is_its_banner() -> void:
	var a := _announcer()
	_event(GameEvent.Kind.ROUND_START, 3)
	assert_eq(_out(a), "Round 3")
	_event(GameEvent.Kind.ROUND_START, 5)
	assert_eq(_out(a), "Round 5 · Half time · ends swapped", "after round 4")
	var rs := _state.round_state
	rs.mode = RoundState.Mode.ATTACK_DEFEND
	rs.attackers = 0
	_event(GameEvent.Kind.ROUND_START, 2)
	assert_eq(_out(a), "Round 2 · Attack · Take the flag")
	rs.attackers = 1
	assert_eq(a.round_start_line(rs, 2), "Round 2 · Defend · Hold the pole")
	assert_eq(a.round_start_line(rs, 5), "Round 5 · Defend · Half time · ends swapped")
	assert_false(a.assertive(), "a round's start is polite")


func test_a_round_end_says_who_won_why_and_the_score_your_team_first() -> void:
	var a := _announcer()
	var rs := _state.round_state
	rs.number = 3
	rs.score = PackedInt32Array([2, 1])
	_event(GameEvent.Kind.ROUND_OVER, 0, GameEvent.RoundEnd.ELIMINATED)
	assert_eq(_out(a), "Won · Round 3 · Alpha take the round · Alpha 2 – 1 Beta")
	assert_false(a.assertive(), "a round's end is polite")
	rs.score = PackedInt32Array([1, 2])
	assert_eq(a.round_over_line(rs, 1, GameEvent.RoundEnd.ELIMINATED),
			"Lost · Round 3 · Beta take the round · Alpha 1 – 2 Beta")
	assert_eq(a.round_over_line(rs, -1, GameEvent.RoundEnd.TIME),
			"Draw · Round 3 · The round is played again · Alpha 1 – 2 Beta")
	rs.mode = RoundState.Mode.ATTACK_DEFEND
	assert_eq(a.round_over_line(rs, 1, GameEvent.RoundEnd.CAPTURED),
			"Lost · Round 3 · Flag raised · Beta take the round · Alpha 1 – 2 Beta")
	assert_eq(a.round_over_line(rs, 0, GameEvent.RoundEnd.TIME),
			"Won · Round 3 · Defended · Time's up · Alpha held the pole · Alpha 1 – 2 Beta")
	assert_eq(a.round_over_line(rs, 0, GameEvent.RoundEnd.ELIMINATED),
			"Won · Round 3 · Alpha take the round · Alpha 1 – 2 Beta", "a wipe-out in Attack / Defend")


func test_the_score_puts_your_team_first_from_beta() -> void:
	var a := Announcer.new(_teams, _state.characters[ROOK], 0)
	var rs := _state.round_state
	rs.score = PackedInt32Array([2, 1])
	assert_eq(a.round_over_line(rs, 0, GameEvent.RoundEnd.ELIMINATED), "Lost · Round 1 · Alpha take the round · Beta 1 – 2 Alpha")
	assert_eq(a.match_over_line(0, PackedInt32Array([5, 3])), "Lost · The match · Beta 3 – 5 Alpha")


func test_the_match_end_is_assertive_and_joins_the_last_round_s_end() -> void:
	var a := _announcer()
	var rs := _state.round_state
	rs.number = 8
	rs.score = PackedInt32Array([5, 3])
	_event(GameEvent.Kind.ROUND_OVER, 0, GameEvent.RoundEnd.ELIMINATED)
	_event(GameEvent.Kind.MATCH_OVER, 0)
	assert_eq(_out(a), "Won · Round 8 · Alpha take the round · Alpha 5 – 3 Beta. Won · The match · Alpha 5 – 3 Beta")
	assert_true(a.assertive(), "the match's result is read at once")


func test_the_practice_range_announces_no_rounds() -> void:
	var a := _announcer()
	_state.round_state.practice = true
	_event(GameEvent.Kind.ROUND_START, 1)
	_event(GameEvent.Kind.ROUND_OVER, 0)
	assert_eq(_out(a), "")


# --- the join window ---

func test_lines_inside_the_window_join_and_later_ones_start_a_new_message() -> void:
	var a := _announcer()
	_hit(ROOK, MATE)
	a.on_tick(_state)
	_state.events.clear()
	assert_true(a.gathering())
	# 0.2 s on, a second hit joins.
	for i in 12:
		assert_false(a.advance(DT), "nothing out inside the window")
	_hit(YOU, ROOK)
	a.on_tick(_state)
	_state.events.clear()
	var ticks := 0
	while not a.advance(DT):
		ticks += 1
		assert_lt(ticks, 30, "the window closes")
	assert_almost_eq((12 + ticks + 1) * DT, Announcer.JOIN_WINDOW, DT, "0.3 s from the first line, not the last")
	assert_eq(a.message(), "Mags called HIT · Rook. Rook called HIT · You")
	assert_false(a.gathering())
	_hit(MATE, DASH)
	assert_eq(_out(a), "Beta called HIT · Mags", "a line after the window is a message of its own")


func test_one_assertive_line_makes_the_joined_message_assertive() -> void:
	var a := _announcer()
	_hit(ROOK, MATE)
	_hit(DASH, YOU)
	assert_eq(_out(a), "Mags called HIT · Rook. You're hit · Beta")
	assert_true(a.assertive())
	_hit(ROOK, MATE)
	_out(a)
	assert_false(a.assertive(), "the next message starts polite")


# --- off ---

func test_off_sends_nothing_and_drops_what_was_gathering() -> void:
	var a := _announcer()
	a.set_on(false)
	_hit(ROOK, YOU)
	_event(GameEvent.Kind.MATCH_OVER, 0)
	assert_eq(_out(a), "")
	assert_false(a.gathering())
	a.set_on(true)
	_hit(ROOK, MATE)
	a.on_tick(_state)
	_state.events.clear()
	a.set_on(false)
	for i in 30:
		assert_false(a.advance(DT), "switched off mid-window: nothing goes out")
	a.add("Round 1", false)
	assert_false(a.gathering(), "add while off keeps nothing")


# --- the label ---

func _hud() -> Hud:
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.setup(HudConfig.new(), _teams, ViewConfig.new(), SimTuning.new(), _state.characters[YOU])
	hud.setup_field(BoxWorld.new(), BodyConfig.new(), PackedStringArray(["", "Mags", "Rook", ""]), _state.characters,
			null)
	return hud


func test_the_label_is_in_the_tree_but_never_drawn_and_reads_politely() -> void:
	var hud := _hud()
	var label := hud.announce()
	assert_true(label.is_visible_in_tree(), "shown, so it stays in the accessibility tree")
	assert_eq(label.modulate.a, 0.0, "at opacity 0, so it is never drawn")
	assert_eq(label.accessibility_live, AccessibilityServer.LIVE_POLITE)
	assert_eq(label.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "its words are already translated")
	assert_eq(label.text, "")


func test_the_label_takes_each_message_at_its_priority() -> void:
	var hud := _hud()
	var label := hud.announce()
	_hit(ROOK, MATE)
	hud.on_tick(_state)
	_state.events.clear()
	hud.update(_state, 1.0, 0.1)
	assert_eq(label.text, "", "nothing inside the window")
	hud.update(_state, 1.0, 0.25)
	assert_eq(label.text, "Mags called HIT · Rook")
	assert_eq(label.accessibility_live, AccessibilityServer.LIVE_POLITE)
	_hit(ROOK, YOU)
	hud.on_tick(_state)
	_state.events.clear()
	assert_eq(label.text, "", "cleared while the next gathers, so the same words still read as a change")
	hud.update(_state, 1.0, 0.35)
	assert_eq(label.text, "You're hit · Rook")
	assert_eq(label.accessibility_live, AccessibilityServer.LIVE_ASSERTIVE, "your hit at once")
	hud.set_read_out(true)
	assert_eq(label.accessibility_live, AccessibilityServer.LIVE_ASSERTIVE, "a settings change keeps the priority showing")
	_event(GameEvent.Kind.ROUND_START, 2)
	hud.on_tick(_state)
	_state.events.clear()
	hud.update(_state, 1.0, 0.35)
	assert_eq(label.text, "Round 2")
	assert_eq(label.accessibility_live, AccessibilityServer.LIVE_POLITE, "back to polite")


func test_off_the_label_is_live_off_and_gets_no_text() -> void:
	var hud := _hud()
	var label := hud.announce()
	_hit(ROOK, MATE)
	hud.on_tick(_state)
	_state.events.clear()
	hud.update(_state, 1.0, 0.35)
	assert_ne(label.text, "")
	hud.set_read_out(false)
	assert_eq(label.accessibility_live, AccessibilityServer.LIVE_OFF)
	assert_eq(label.text, "", "what was said goes")
	_hit(ROOK, YOU)
	_event(GameEvent.Kind.MATCH_OVER, 1)
	hud.on_tick(_state)
	_state.events.clear()
	hud.update(_state, 1.0, 0.35)
	assert_eq(label.text, "", "off: no text")
	assert_eq(label.accessibility_live, AccessibilityServer.LIVE_OFF)
	hud.set_read_out(true)
	assert_eq(label.accessibility_live, AccessibilityServer.LIVE_POLITE)


func test_the_switch_reaches_a_match_at_once() -> void:
	var settings := Settings.new(PlayTuning.new())
	var session := PlaySession.new()
	session.settings = settings
	session.bots_active = false
	add_child_autofree(session)
	await wait_physics_frames(2)
	var label := session.hud().announce()
	assert_eq(label.accessibility_live, AccessibilityServer.LIVE_POLITE, "on by default")
	settings.read_out = false
	settings.mark_changed()
	assert_eq(label.accessibility_live, AccessibilityServer.LIVE_OFF)
	assert_eq(label.text, "")
	settings.read_out = true
	settings.mark_changed()
	assert_eq(label.accessibility_live, AccessibilityServer.LIVE_POLITE)


func test_project_settings_run_access_kit_only_with_a_screen_reader() -> void:
	assert_eq(ProjectSettings.get_setting("accessibility/general/accessibility_support"), 0, "Auto")
	var text := FileAccess.get_file_as_string("res://project.godot")
	assert_string_contains(text, "[accessibility]\n\ngeneral/accessibility_support=0", "stated, not left to the default")


## BP6: your squad orders are read in the wheel's words, and one that waits for the next round says so; a bot's are not.
func test_your_squad_orders_are_read() -> void:
	var a := _announcer()
	_event(GameEvent.Kind.SQUAD_ORDER, SquadOrder.Kind.FOLLOW)
	_state.events.items[0].actor = YOU
	assert_eq(_out(a), "Order · Follow Me")
	_event(GameEvent.Kind.SQUAD_ORDER, SquadOrder.Kind.HOLD)
	_state.events.items[0].actor = MATE
	assert_eq(_out(a), "", "a teammate's order is not yours")
	_event(GameEvent.Kind.SQUAD_ORDER_REFUSED, SquadOrder.Kind.REGROUP)
	_state.events.items[0].actor = YOU
	assert_eq(_out(a), "Orders wait for the next round")
	a.set_on(false)
	_event(GameEvent.Kind.SQUAD_ORDER, SquadOrder.Kind.FOLLOW)
	_state.events.items[0].actor = YOU
	assert_eq(_out(a), "", "nothing while off")
