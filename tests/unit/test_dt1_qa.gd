extends GutTest
## DT1 (owner, 2026-11-05: the Sniper Rifle public): a bot never presses a bolt-action's trigger while its bolt is
## still being worked. Armament keeps such a press until the bolt is home (bolt_press_window), most of a second after
## the bot checked its line of fire, and a teammate who stepped in front meanwhile was knocked out (the Street guards
## at night on Easy, seed 7, once Sniper kits came to bots without Dev content).

const DT := 1.0 / 60.0
const SNIPER := "000021"

var tuning: SimTuning = SimTuning.new()
var bots: BotConfig = BotConfig.load_default()


## A bot with the Sniper Rifle in hand, reacted, aimed straight at a foe 5 m off (inside hip_fire_range) over open floor.
func _bot() -> Array:
	var world := BoxWorld.new(tuning.body)
	world.add_floor(60.0, 60.0)
	var rules := LoadoutRules.standard()
	var rifle: Array[ReplicaConfig] = [rules.config(rules.pool.item(SNIPER))]
	var me := Character.new(0, 0, Vector3(0.0, tuning.body.rest_gap, 0.0), 0.0, rifle)
	var foe := Character.new(1, 1, Vector3(0.0, tuning.body.rest_gap, -5.0), PI, ReplicaStats.default_loadout())
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = bots
	w.query = world
	w.planner = RoundPlanner.new(1)
	var chars: Array[Character] = [me, foe]
	w.characters = chars
	w.time = 10.0
	var b := Bot.new(me, 3, bots.skill_for(&"hard"), 2)
	b.target_visible = true
	b.contact = Bot.Contact.new()
	b.contact.react_at = 0.0
	return [b, w, foe]


func _shoot(b: Bot, w: BotWorld, foe: Character) -> PlayerCommand:
	var eye := Vector3(0.0, 1.5, 0.0)
	BotCombat._aim_point = Vector3(0.0, 1.5, -5.0)
	b.aim_yaw = 0.0
	b.aim_pitch = 0.0
	var cmd := PlayerCommand.new()
	BotCombat.shoot(b, w, foe, eye, 0.0, cmd, DT)
	return cmd


func test_a_bot_holds_a_bolt_actions_trigger_until_the_bolt_is_home() -> void:
	var m := _bot()
	var b: Bot = m[0]
	var w: BotWorld = m[1]
	var foe: Character = m[2]
	var a := b.character.armament
	assert_true(a.replica().bolt_action)
	a.cooldown = 0.3
	assert_false(_shoot(b, w, foe).fire, "still cycling: no press kept for later")
	a.cooldown = 0.0
	w.time += 1.0
	assert_true(_shoot(b, w, foe).fire, "the bolt home and the line clear: it fires")


func test_only_a_bolt_action_waits_out_its_cycle() -> void:
	var a := Armament.create(ReplicaStats.default_loadout())
	a.cooldown = 0.3
	assert_false(BotCombat._bolt_cycling(a), "an AEG's press is kept only press_buffer, as before")
