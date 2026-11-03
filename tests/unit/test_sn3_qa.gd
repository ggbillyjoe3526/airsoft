extends GutTest
## QA for the sniper balance pass (SN3): a reveal is cleared with the round, never outlasts its shooter, keeps the
## dark and a dazzle, a bolt-action bot never holds fire for good, and the new Path bins leave The Street walkable.

const SNIPER := "000021"
const BIN := Vector3(-10.25, 0.0, 25.0)

var config: BotConfig = BotConfig.load_default()
var rules: LoadoutRules
var w: BotWorld
var b: Bot
var foe: Character


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	foe = Character.new(1, 1, Vector3(0.0, 0.0, -65.0), 0.0, [rules.config(rules.pool.item(SNIPER))] as Array[ReplicaConfig])
	w = BotWorld.new()
	w.tuning = SimTuning.load_default()
	w.cfg = config
	w.query = BoxWorld.new()
	w.characters = [me, foe]
	w.nav = _nav()
	b = Bot.new(me, 1, config.skill_for(&"normal"), 2)
	w.bots = [b]


static var _grid: NavGrid = null
static var _map: MapData = null


func _nav() -> NavGrid:
	if _grid == null:
		var t := SimTuning.load_default()
		_map = MapData.load_map("street", MapStyle.new(), t.rounds.team_size)
		_grid = NavGrid.build(_map, t.nav, t.body)
	return _grid


func _miss(shooter: Character) -> void:
	var s := GameState.new(1, w.tuning)
	var e := s.events.add(GameEvent.Kind.BB_IMPACT)
	e.actor = shooter.id
	e.position = BotSenses.body_point(b.character, w.tuning.hits, config.aim_height_fraction)
	BotHearing.observe(s, w)


func _hit(victim: Character, shooter: Character) -> void:
	var s := GameState.new(1, w.tuning)
	var e := s.events.add(GameEvent.Kind.CHARACTER_HIT)
	e.actor = shooter.id
	e.target = victim.id
	e.direction = Vector3(0.0, 0.0, 1.0)
	BotHearing.observe(s, w)


func test_a_new_round_clears_a_reveal() -> void:
	_miss(foe)
	assert_eq(BotSenses.sight_reach(b, foe, w), config.revealed_view_distance)
	b.reset(0, 1, 0.0, config)
	assert_eq(b.revealed_id, -1)
	assert_eq(BotSenses.sight_reach(b, foe, w), config.view_distance, "a fresh round: nobody given away")


func test_a_shooter_already_out_is_not_revealed_by_a_near_miss() -> void:
	foe.status = Character.Status.OUT
	_miss(foe)
	assert_eq(b.revealed_id, -1)


func test_a_shooter_already_out_is_not_revealed_by_a_hit_call() -> void:
	var mate := Character.new(3, 0, Vector3(4.0, 0.0, 0.0), 0.0, ReplicaStats.default_loadout())
	w.characters.append(mate)
	foe.status = Character.Status.OUT
	_hit(mate, foe)
	assert_eq(b.revealed_id, -1)


func test_a_hit_call_out_of_earshot_or_on_a_dead_teammate_reveals_nothing() -> void:
	var far := Character.new(3, 0, Vector3(config.hearing_distance + 10.0, 0.0, 0.0), 0.0, ReplicaStats.default_loadout())
	w.characters.append(far)
	_hit(far, foe)
	assert_eq(b.revealed_id, -1, "out of hearing of the call")
	var near := Character.new(4, 0, Vector3(3.0, 0.0, 0.0), 0.0, ReplicaStats.default_loadout())
	w.characters.append(near)
	b.character.status = Character.Status.OUT
	_hit(near, foe)
	assert_eq(b.revealed_id, -1, "a bot already walking off is not given the shooter")


func test_a_friendly_hit_reveals_nobody() -> void:
	var mate := Character.new(3, 0, Vector3(4.0, 0.0, 0.0), 0.0, ReplicaStats.default_loadout())
	var friend := Character.new(5, 0, Vector3(8.0, 0.0, 0.0), 0.0, ReplicaStats.default_loadout())
	w.characters.append(mate)
	w.characters.append(friend)
	_hit(mate, friend)
	assert_eq(b.revealed_id, -1)


func test_a_reveal_does_not_see_through_a_dazzle() -> void:
	_miss(foe)
	var reach := BotSenses.sight_reach(b, foe, w)
	assert_gt(BotSenses.visible_part(b.character, foe, w, reach), 0.0)
	b.character.dazzle_left = 1.0
	assert_eq(BotSenses.visible_part(b.character, foe, w, reach), 0.0)


func test_a_reveal_does_not_see_past_the_dark() -> void:
	_miss(foe)
	_nav()
	w.night = NightField.build(_map, config, true)
	assert_not_null(w.night)
	var reach := BotSenses.sight_reach(b, foe, w)
	var flat := 65.0
	if flat <= w.night.range_between(b.character, foe):
		pending("the spot is lit")
		return
	assert_eq(BotSenses.visible_part(b.character, foe, w, reach), 0.0, "revealed but unlit: still not made out")


func test_the_bolt_wait_always_ends() -> void:
	var sniper := Character.new(4, 0, Vector3.ZERO, 0.0, [rules.config(rules.pool.item(SNIPER))] as Array[ReplicaConfig])
	for name: StringName in [&"easy", &"normal", &"hard"]:
		var sb := Bot.new(sniper, 1, config.skill_for(name), 2)
		if sb.skill == null:
			continue
		sb.contact = Bot.Contact.new()
		sb.contact.first_seen_at = 0.0
		sb.contact.react_at = sb.skill.reaction_time.y
		sb.contact.acquired_at = 0.0
		w.time = sb.contact.react_at + sb.skill.aim_settle_time * config.bolt_settle_share + 0.01
		assert_false(BotCombat.bolt_waits(sb, w, 40.0), "%s: fires once reacted and settled" % name)


func test_a_bolt_bot_with_no_contact_does_not_hold_fire() -> void:
	var sniper := Character.new(4, 0, Vector3.ZERO, 0.0, [rules.config(rules.pool.item(SNIPER))] as Array[ReplicaConfig])
	var sb := Bot.new(sniper, 1, config.skill_for(&"normal"), 2)
	assert_false(BotCombat.bolt_waits(sb, w, 40.0))


func test_the_path_bins_leave_the_path_walkable_both_sides_and_end_to_end() -> void:
	var g := _nav()
	assert_false(g.is_walkable_at(BIN + Vector3(0.0, 0.0, 0.0)), "the bins themselves are solid")
	assert_true(g.is_walkable_at(Vector3(-11.4, 0.0, 25.0)), "west of the bins")
	assert_true(g.is_walkable_at(Vector3(-9.1, 0.0, 25.0)), "east of the bins")
	var out := PackedVector3Array()
	assert_true(g.find_route(Vector3(-10.0, 0.0, 30.0), Vector3(-10.0, 0.0, 5.0), out), "down the Path past the bins")
	for p in out:
		assert_false(absf(p.x - BIN.x) < 0.35 and absf(p.z - BIN.z) < 0.7, "no route leg through the bins")


func test_every_spawn_still_reaches_the_other_end_of_the_street() -> void:
	var g := _nav()
	_nav()
	var out := PackedVector3Array()
	for s0 in _map.ends[0].spawns:
		for s1 in _map.ends[1].spawns:
			assert_true(g.find_route(s0.position, s1.position, out), "spawn to spawn")
