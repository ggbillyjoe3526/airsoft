extends GutTest
## Follow me and the holster (BotHolster, NA1): a follower sprinting after a leader whose replica is away puts its own
## away at once, so it keeps pace with the holster's faster sprint, and keeps it away through the breaks in its sprint
## while the leader does; with the leader's replica up, the usual sprint first. (Depot's Follow me guard found a
## follower whose sprint broke every half second as it eased into place never holstered, and fell behind.)

const DT := 1.0 / 60.0

var config: BotConfig = BotConfig.load_default()
var w: BotWorld
var b: Bot
var leader: Character


func before_each() -> void:
	var loadout := ReplicaStats.default_loadout()
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	leader = Character.new(1, 0, Vector3(0.0, 0.0, -3.0), 0.0, loadout)
	leader.armament.holstered = true
	w = BotWorld.new()
	w.tuning = SimTuning.load_default()
	w.cfg = config
	w.live = true
	w.time = 100.0
	w.characters = [me, leader]
	w.planner = RoundPlanner.new(1)
	w.planner.spawn_centre = [Vector3.ZERO, Vector3(0.0, 0.0, -100.0)]
	b = Bot.new(me, 1, config.skill_for(&"normal"), 2)
	b.order = SquadOrder.Kind.FOLLOW
	b.order_giver = leader


## One holster step with the bot sprinting or not; the armament follows the command as the simulation would.
func _step(sprint: bool) -> PlayerCommand:
	var cmd := PlayerCommand.new()
	cmd.sprint = sprint
	BotHolster.step(b, w, cmd, DT)
	if cmd.holster:
		b.character.armament.holstered = true
	elif cmd.switch_to >= 0:
		b.character.armament.holstered = false
	return cmd


func test_a_follower_sprinting_after_a_holstered_leader_holsters_at_once() -> void:
	assert_true(_step(true).holster)


func test_it_keeps_it_away_through_its_sprint_breaks_while_the_leader_does() -> void:
	_step(true)
	for i in ceili(config.holster_draw_after / DT) * 2:
		_step(false)
	assert_true(b.character.armament.holstered, "no draw at each break")
	leader.armament.holstered = false
	for i in ceili(config.holster_draw_after / DT) + 1:
		_step(false)
	assert_false(b.character.armament.holstered, "drawn once the leader draws and the sprint is over")


func test_with_the_leader_s_replica_up_the_usual_sprint_first() -> void:
	leader.armament.holstered = false
	assert_false(_step(true).holster)


func test_a_threat_still_draws_it() -> void:
	_step(true)
	b.target_visible = true
	_step(true)
	assert_false(b.character.armament.holstered)
