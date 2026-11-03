extends GutTest
## The sniper balance pass (SN3): bots answer a sniper out past their sight, and a sniper bot's one shot a cycle counts.

const EYE := Vector3(0.0, 1.6, 0.0)
const SNIPER := "000021"

var config: BotConfig = BotConfig.load_default()
var rules: LoadoutRules
var w: BotWorld
var b: Bot
var foe: Character


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	# Past every map's own bot sight (MapData.bot_sight, 55 to 60 m), within the M150's reach.
	foe = Character.new(1, 1, Vector3(0.0, 0.0, -65.0), 0.0, _sniper_loadout())
	w = BotWorld.new()
	w.tuning = SimTuning.load_default()
	w.cfg = config
	w.query = BoxWorld.new()
	w.characters = [me, foe]
	# Hearing guesses a floor off the nav grid: The Street's spans these 65 m (its floor is at 0 too).
	w.nav = _street_nav()
	b = Bot.new(me, 1, config.skill_for(&"normal"), 2)
	w.bots = [b]


func _sniper_loadout() -> Array[ReplicaConfig]:
	return [rules.config(rules.pool.item(SNIPER))] as Array[ReplicaConfig]


static var _nav: NavGrid = null


func _street_nav() -> NavGrid:
	if _nav == null:
		var t := SimTuning.load_default()
		_nav = NavGrid.build(MapData.load_map("street", MapStyle.new(), t.rounds.team_size), t.nav, t.body)
	return _nav


func test_a_bot_makes_out_only_its_view_until_shot_at() -> void:
	assert_eq(BotSenses.sight_reach(b, foe, w), config.view_distance)
	assert_eq(BotSenses.visible_part(b.character, foe, w, BotSenses.sight_reach(b, foe, w)), 0.0, "65 m: unseen")


func test_a_near_miss_reveals_the_shooter_for_a_while() -> void:
	var s := GameState.new(1, w.tuning)
	var e := s.events.add(GameEvent.Kind.BB_IMPACT)
	e.actor = foe.id
	e.position = BotSenses.body_point(b.character, w.tuning.hits, config.aim_height_fraction)
	BotHearing.observe(s, w)
	assert_eq(BotSenses.sight_reach(b, foe, w), config.revealed_view_distance)
	assert_gt(BotSenses.visible_part(b.character, foe, w, BotSenses.sight_reach(b, foe, w)), 0.0, "65 m: seen")
	var other := Character.new(2, 1, Vector3(5.0, 0.0, -65.0), 0.0, ReplicaStats.default_loadout())
	assert_eq(BotSenses.sight_reach(b, other, w), config.view_distance, "only the one who shot")
	w.time += config.revealed_for + 0.1
	assert_eq(BotSenses.sight_reach(b, foe, w), config.view_distance, "and only for a while")


func test_a_teammate_hit_nearby_reveals_the_shooter() -> void:
	var mate := Character.new(3, 0, Vector3(4.0, 0.0, 0.0), 0.0, ReplicaStats.default_loadout())
	w.characters.append(mate)
	var s := GameState.new(1, w.tuning)
	var e := s.events.add(GameEvent.Kind.CHARACTER_HIT)
	e.actor = foe.id
	e.target = mate.id
	e.direction = Vector3(0.0, 0.0, 1.0)
	BotHearing.observe(s, w)
	assert_eq(BotSenses.sight_reach(b, foe, w), config.revealed_view_distance)


func test_a_sniper_bot_sees_further_through_its_raised_scope() -> void:
	var sniper := Character.new(4, 0, Vector3.ZERO, 0.0, _sniper_loadout())
	var sb := Bot.new(sniper, 1, config.skill_for(&"normal"), 2)
	assert_true(BotCombat.fights_aimed(sniper))
	assert_false(BotCombat.scoped(sb, config), "its sight down")
	assert_eq(BotSenses.sight_reach(sb, foe, w), config.view_distance)
	sniper.aim_raise = 1.0
	assert_true(BotCombat.scoped(sb, config))
	assert_eq(BotSenses.sight_reach(sb, foe, w), maxf(config.view_distance, config.scoped_view_distance))
	assert_false(BotCombat.scoped(b, config), "an AEG's raised sight is no scope")


func test_a_bolt_action_bot_waits_for_its_aim_to_settle() -> void:
	var sniper := Character.new(4, 0, Vector3.ZERO, 0.0, _sniper_loadout())
	var sb := Bot.new(sniper, 1, config.skill_for(&"normal"), 2)
	sb.contact = Bot.Contact.new()
	sb.contact.first_seen_at = 0.0
	sb.contact.react_at = 0.0
	sb.contact.acquired_at = 0.0
	w.time = 0.1
	var far := config.hip_fire_range + 10.0
	assert_true(BotCombat.bolt_waits(sb, w, far), "aim not settled: holds its one shot")
	assert_false(BotCombat.bolt_waits(sb, w, config.hip_fire_range * 0.5), "close: a shot from the hip")
	w.time = sb.skill.aim_settle_time * config.bolt_settle_share + 0.1
	assert_false(BotCombat.bolt_waits(sb, w, far), "settled: fires")
	b.contact = Bot.Contact.new()
	w.time = 0.1
	assert_false(BotCombat.bolt_waits(b, w, far), "an AEG never waits")
