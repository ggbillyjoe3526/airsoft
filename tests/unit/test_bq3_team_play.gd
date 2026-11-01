extends GutTest
## BQ3 · The bots play more as a team: a team radio (BotRadio: a fresh sighting told to teammates near it after a
## moment), pressing the advantage when well ahead in Elimination and the last of a team playing carefully, on Normal
## and Hard (Hard tells its team sooner and further), and taking a knee for each burst in the open; Easy has none.

const YARD := Vector3(0.0, 0.0, 0.0)

var config: BotConfig = BotConfig.load_default()
var world: BotWorld = null


## Bots 0 to 2 on team 0 (0 at the yard, 1 ten metres off, 2 eighty metres off) and bots 3 and 4 on team 1, at `level`.
func _world(level: StringName = &"normal") -> void:
	world = BotWorld.new()
	world.cfg = config
	world.tuning = SimTuning.load_default()
	world.time = 10.0
	var spots: Array[Vector3] = [YARD, Vector3(10.0, 0.0, 0.0), Vector3(80.0, 0.0, 0.0), Vector3(0.0, 0.0, 20.0),
			Vector3(5.0, 0.0, 25.0)]
	for id in spots.size():
		var c := Character.new(id, 0 if id < 3 else 1, spots[id], 0.0, ReplicaStats.default_loadout())
		c.position = spots[id]
		world.characters.append(c)
		world.bots.append(Bot.new(c, id + 1, config.skill_for(level), spots.size()))


## Runs BotRadio for `seconds` of world time.
func _radio(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		world.time += 1.0 / 60.0
		BotRadio.step(world)
		t += 1.0 / 60.0


func test_a_fresh_sighting_is_told_to_teammates_near_it_after_a_moment() -> void:
	_world()
	var enemy := world.characters[3]
	BotRadio.saw(world.bots[0], world, enemy)
	var skill := config.skill_for(&"normal")
	_radio(skill.share_delay.x * 0.5)
	assert_false(world.bots[1].has_last_known, "not before its delay")
	_radio(skill.share_delay.y)
	var near := world.bots[1]
	assert_true(near.has_last_known, "a teammate near the enemy hears where")
	assert_almost_eq(near.last_known.z, enemy.position.z, 0.01)
	assert_eq(near.heard_at, near.last_threat_at, "it is a threat in mind")
	assert_false(world.bots[2].has_last_known, "one far off keeps to its own play")
	assert_false(world.bots[4].has_last_known, "the enemy hears nothing")
	assert_false(world.bots[0].has_last_known, "nor is the caller told")


func test_a_teammate_fighting_or_in_sight_of_someone_keeps_its_own() -> void:
	_world()
	world.bots[1].mode = Bot.Mode.FIGHT
	BotRadio.saw(world.bots[0], world, world.characters[3])
	_radio(2.0)
	assert_false(world.bots[1].has_last_known)
	_world()
	world.bots[1].target_visible = true
	BotRadio.saw(world.bots[0], world, world.characters[3])
	_radio(2.0)
	assert_false(world.bots[1].has_last_known)


func test_a_caller_out_before_its_call_says_nothing() -> void:
	_world()
	BotRadio.saw(world.bots[0], world, world.characters[3])
	world.characters[0].status = Character.Status.CALLING
	_radio(2.0)
	assert_false(world.bots[1].has_last_known)
	assert_eq(world.bots[0].share_id, -1, "the call is dropped")


func test_easy_bots_have_no_radio() -> void:
	_world(&"easy")
	BotRadio.saw(world.bots[0], world, world.characters[3])
	assert_eq(world.bots[0].share_id, -1)
	_radio(2.0)
	assert_false(world.bots[1].has_last_known)


func test_a_team_well_ahead_presses_and_the_last_one_plays_carefully() -> void:
	_world()
	assert_false(world.pressing(world.bots[0]), "three against two is not enough")
	world.characters[4].status = Character.Status.OUT
	assert_true(world.pressing(world.bots[0]), "three against one presses")
	assert_false(world.pressing(world.bots[3]))
	assert_true(world.careful_last(world.bots[3]), "the last of its team")
	assert_false(world.careful_last(world.bots[0]))
	world.mode = RoundState.Mode.ATTACK_DEFEND
	assert_false(world.pressing(world.bots[0]), "Elimination only: Attack / Defend has its pole")
	assert_false(world.careful_last(world.bots[3]))
	_world(&"easy")
	world.characters[4].status = Character.Status.OUT
	assert_false(world.pressing(world.bots[0]), "Easy doesn't")
	assert_false(world.careful_last(world.bots[3]), "Easy doesn't")


func test_normal_and_hard_have_the_radio_and_easy_none() -> void:
	var easy := config.skill_for(&"easy")
	var normal := config.skill_for(&"normal")
	var hard := config.skill_for(&"hard")
	for s: BotSkill in [normal, hard]:
		assert_true(s.presses_advantage and s.careful_when_last and s.kneels_to_fire)
		assert_gt(s.share_radius, 0.0)
	assert_false(easy.presses_advantage or easy.careful_when_last or easy.kneels_to_fire)
	assert_eq(easy.share_radius, 0.0)
	assert_lt(hard.share_delay.y, normal.share_delay.y, "Hard tells its team sooner")
	assert_gt(hard.share_radius, normal.share_radius, "and further")
	assert_false(normal.holds_angles or normal.slices_corners or normal.team_play, "Normal keeps its own play")


## Bot 0 (at `level`) fighting bot 3 in the open on a 40 m floor (a BoxWorld and its nav grid); its command.
func _fighting(level: StringName) -> PlayerCommand:
	_world(level)
	var m := MapData.new()
	var block := MapData.Block.new()
	block.kind = &"floor"
	block.center = Vector3(0.0, -0.25, 0.0)
	block.size = Vector3(80.0, 0.5, 80.0)
	m.blocks.append(block)
	world.nav = NavGrid.build(m, world.tuning.nav, world.tuning.body)
	var box := BoxWorld.new(world.tuning.body)
	box.add_floor(80.0, 80.0)
	world.query = box
	var b := world.bots[0]
	b.mode = Bot.Mode.FIGHT
	b.target_id = 3
	b.target_visible = true
	b.target_part = 0.6
	b.strafe_left = 1.0
	return PlayerCommand.new()


func test_normal_takes_a_knee_for_each_burst_and_sidesteps_between() -> void:
	var cmd := _fighting(&"normal")
	var b := world.bots[0]
	b.burst_left = 0.3
	BotMovement._strafe(b, world, cmd, 1.0 / 60.0, world.characters[3])
	assert_true(cmd.crouch, "a knee while the BBs go")
	assert_eq(cmd.right, 0.0, "and still")
	cmd = PlayerCommand.new()
	b.burst_left = 0.0
	b.pause_left = 0.4
	BotMovement._strafe(b, world, cmd, 1.0 / 60.0, world.characters[3])
	assert_false(cmd.crouch, "up again in the pause")
	assert_ne(cmd.right, 0.0, "sidestepping")


func test_easy_keeps_sidestepping_as_it_shoots() -> void:
	var cmd := _fighting(&"easy")
	var b := world.bots[0]
	b.burst_left = 0.3
	BotMovement._strafe(b, world, cmd, 1.0 / 60.0, world.characters[3])
	assert_false(cmd.crouch)
	assert_ne(cmd.right, 0.0)
