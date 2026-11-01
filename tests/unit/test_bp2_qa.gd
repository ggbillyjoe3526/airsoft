extends GutTest
## BP2 QA: the bot fixes the worker's tests left out (a bomb-busy bot's no-shot check, a dazzled bot's burst).

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.new()
var bots: BotConfig = BotConfig.load_default()


func _bot() -> Array:
	var world := BoxWorld.new(tuning.body)
	world.add_floor(60.0, 60.0)
	var loadout := ReplicaStats.default_loadout()
	var me := Character.new(0, 0, Vector3(0.0, tuning.body.rest_gap, 0.0), 0.0, loadout)
	var foe := Character.new(1, 1, Vector3(0.0, tuning.body.rest_gap, -20.0), PI, loadout)
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = bots
	w.query = world
	w.planner = RoundPlanner.new(1)
	var chars: Array[Character] = [me, foe]
	w.characters = chars
	var b := Bot.new(me, 3, bots.skill_for(&"easy"), 2)
	return [b, w, foe]


func test_a_bot_busy_with_a_bomb_keeps_its_no_shot_count_not_reading_another_bots_aim_point() -> void:
	var m := _bot()
	var b: Bot = m[0]
	var w: BotWorld = m[1]
	var foe: Character = m[2]
	b.target_visible = true
	b.no_shot_for = 0.5
	# the static aim point another bot left behind: a clear line over open floor
	BotCombat._aim_point = Vector3(0.0, 1.5, -5.0)
	BotCombat.shoot(b, w, foe, Vector3(0.0, 1.5, 0.0), PI, PlayerCommand.new(), DT)
	assert_eq(b.no_shot_for, 0.5, "aim didn't run (off_aim PI), so the count is neither cleared nor read from a stale point")


func test_a_dazzled_bot_forgets_its_burst() -> void:
	var m := _bot()
	var b: Bot = m[0]
	var w: BotWorld = m[1]
	b.bursting = true
	b.burst_left = 0.2
	b.character.dazzle_left = 2.0
	BotBrain.think(b, w, PlayerCommand.new(), DT)
	assert_false(b.bursting, "no burst carried through the dazzle")
