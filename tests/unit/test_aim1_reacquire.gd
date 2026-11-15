extends GutTest
## AIM1 · picking someone up again (game/ai/bot_senses.gd, BotAim.settling): you step out, duck back behind a wall and
## step out again. Out of sight longer than reacquire_after but within contact_grace, the bot reacts again (shorter than
## a fresh reaction) and its aim keeps only part of its settling; a flicker shorter than that changes nothing; longer
## than contact_grace is a fresh contact. The contact's first sighting stays the first (callouts, What got you).

const DT := 1.0 / 60.0
## Where you hide behind the wall's end and where you step out to (m across the bot's view), 20 m down the field.
const HIDE := Vector3(-1.0, 0.0, -20.0)
const OUT := Vector3(0.8, 0.0, -20.0)

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()

var _w: BotWorld = null
var _b: Bot = null
var _you: Character = null


func before_each() -> void:
	var m := MapData.new()
	m.id = "reacquire field"
	m.kill_y = -10.0
	var world := BoxWorld.new(tuning.body)
	var floor_block := MapData.Block.new()
	floor_block.kind = &"floor"
	floor_block.center = Vector3(0.0, -0.25, -15.0)
	floor_block.size = Vector3(16.0, 0.5, 50.0)
	m.blocks.append(floor_block)
	world.add_box(floor_block.center, floor_block.size)
	world.add_box(Vector3(-1.7, 1.5, -19.4), Vector3(3.0, 3.0, 0.3))
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(0.0, 0.0, 5.0 if e == 0 else -35.0), 0.0 if e == 0 else PI))
		end.dead_zone.append(SpawnPoint.new(Vector3(6.0, 0.0, 8.0 if e == 0 else -38.0), 0.0))
		m.ends.append(end)
	var nav := NavGrid.build(m, tuning.nav, tuning.body)
	var state := GameState.new(3, tuning)
	var loadout := ReplicaStats.default_loadout()
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	state.characters.append(Character.new(1, 1, HIDE, PI, loadout))
	var levels: Dictionary[int, StringName] = {0: &"normal", 1: &"normal"}
	var bots := BotController.new(state, 1, m, nav, world, tuning, config, levels)
	_w = bots.world
	_b = _w.bots[0]
	_b.character.position = Vector3.ZERO
	_b.character.yaw = 0.0
	_b.aim_yaw = 0.0
	_you = state.characters[1]
	_w.time = 10.0


## Puts you at `at` and has the bot look, `seconds` later than its last look.
func _look(at: Vector3, seconds: float) -> void:
	_w.time += seconds
	_you.position = at
	BotSenses.perceive(_b, _w)


## Seen at OUT long enough to react and settle fully, then behind the wall.
func _seen_then_ducked() -> void:
	_look(OUT, 0.0)
	assert_true(_b.target_visible, "seen in the open")
	for i in 20:
		_look(OUT, 0.1)
	assert_true(BotSenses.has_reacted(_b, _w), "reacted")
	assert_gt(BotAim.settling(_w.time, _b.contact, config), _b.skill.aim_settle_time, "its aim has settled")
	_look(HIDE, 0.1)
	assert_false(_b.target_visible, "the wall hides you")


func test_seen_again_after_ducking_back_reacts_again_with_its_aim_unsettled() -> void:
	_seen_then_ducked()
	var first := _b.contact.first_seen_at
	_look(OUT, 0.5)
	var c := _b.contact
	assert_true(_b.target_visible, "seen again")
	assert_false(BotSenses.has_reacted(_b, _w), "it has to find you again before it fires")
	assert_gte(c.react_at - _w.time, _b.skill.reacquire_time.x - 1e-4, "at least the shortest re-pick-up")
	assert_lte(c.react_at - _w.time, _b.skill.reacquire_time.y + 1e-4, "at most the longest")
	assert_lt(_b.skill.reacquire_time.y, _b.skill.reaction_time.y, "shorter than a fresh reaction")
	var at_fire := BotAim.settling(c.react_at, c, config)
	assert_almost_eq(at_fire, _b.skill.reacquire_settled * _b.skill.aim_settle_time, 1e-4,
			"its aim keeps only reacquire_settled of its settling when it may fire")
	assert_eq(Vector2(_b.first_yaw, _b.first_pitch), Vector2.ZERO, "no first aim to one side: the error wanders")
	assert_gt(BotAim.error_size(at_fire, false, 20.0, 0.0, _b.skill), deg_to_rad(_b.skill.aim_error_settled_deg) + 1e-4,
			"its aim error is wider than a settled one when it may fire")
	assert_eq(c.first_seen_at, first, "still the same contact: its first sighting stays")


func test_a_flicker_shorter_than_reacquire_after_changes_nothing() -> void:
	_look(OUT, 0.0)
	for i in 20:
		_look(OUT, 0.1)
	var react_at := _b.contact.react_at
	var acquired := _b.contact.acquired_at
	# Out of one sight check: a pole past the line.
	_w.time += 0.1
	_look(OUT, 0.1)
	assert_lt(0.2, config.reacquire_after, "the test's gap is under reacquire_after")
	assert_eq(_b.contact.react_at, react_at, "no new reaction")
	assert_eq(_b.contact.acquired_at, acquired, "its aim keeps settling")
	assert_true(BotSenses.has_reacted(_b, _w), "it fires on")


func test_out_of_sight_longer_than_the_grace_is_a_fresh_contact() -> void:
	_seen_then_ducked()
	_look(OUT, config.contact_grace + 0.2)
	var c := _b.contact
	assert_eq(c.first_seen_at, _w.time, "a fresh contact")
	assert_gte(c.react_at - _w.time, _b.skill.reaction_time.x - 1e-4, "a full reaction")


func test_seen_again_while_still_reacting_keeps_the_reaction_under_way() -> void:
	_look(OUT, 0.0)
	var react_at := _b.contact.react_at
	_look(HIDE, 0.1)
	_look(OUT, 0.3)
	assert_gte(_b.contact.react_at, react_at, "a reaction under way is never cut short")
	assert_lte(BotAim.settling(_b.contact.react_at, _b.contact, config),
			_b.skill.reacquire_settled * _b.skill.aim_settle_time + 1e-4, "no more settled than a re-pick-up keeps")


func test_every_level_reacts_again_sooner_than_afresh_and_keeps_less_settled_lower_down() -> void:
	var order: Array[StringName] = [&"easy", &"normal", &"hard"]
	for i in order.size():
		var s := config.skill_for(order[i])
		assert_gt(s.reacquire_time.x, 0.0, String(order[i]))
		assert_lte(s.reacquire_time.y, s.reaction_time.y, String(order[i]))
		assert_true(s.reacquire_settled >= 0.0 and s.reacquire_settled <= 1.0, String(order[i]))
		if i > 0:
			var lo := config.skill_for(order[i - 1])
			assert_lte(s.reacquire_time.y, lo.reacquire_time.y, "%s to %s" % [order[i - 1], order[i]])
			assert_gte(s.reacquire_settled, lo.reacquire_settled, "%s to %s" % [order[i - 1], order[i]])
