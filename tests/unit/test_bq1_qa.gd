extends GutTest
## BQ1 QA · edge cases beyond the worker's tests: a bot that went round because glass stood in its line of fire must
## fight again the moment the line opens (also a bot that pushes in, which sprints at the spot), and Go there lapses and
## is given again cleanly.

const DT := 1.0 / 60.0
## Yaw that looks along +X.
const EAST := -PI * 0.5

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()


## A 40 m field split by a glass wall at x 0: a bot at x -6 facing east, an enemy (nobody's bot) at x 6. Returns
## [sim, state, bots, world].
func _glass_match() -> Array:
	var m := MapData.new()
	m.id = "glass field"
	m.kill_y = -10.0
	var w := BoxWorld.new(tuning.body)
	w.add_floor(40.0, 40.0)
	var floor_block := MapData.Block.new()
	floor_block.kind = &"floor"
	floor_block.center = Vector3(0.0, -0.25, 0.0)
	floor_block.size = Vector3(40.0, 0.5, 40.0)
	m.blocks.append(floor_block)
	w.add_clear_box(Vector3(0.0, 1.5, 0.0), Vector3(0.1, 3.0, 40.0))
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-6.0 if e == 0 else 6.0, 0.0, 0.0), EAST if e == 0 else -EAST))
		end.dead_zone.append(SpawnPoint.new(Vector3(-18.0 if e == 0 else 18.0, 0.0, 18.0), 0.0))
		m.ends.append(end)
	var nav := NavGrid.build(m, tuning.nav, tuning.body)
	var sim := Simulation.new(tuning, w, w.mover(), m.ends, m.kill_y)
	sim.nav = nav
	var state := GameState.new(5, tuning)
	var loadout := ReplicaStats.default_loadout()
	state.characters.append(Character.new(0, 0, Vector3(-6.0, 0.0, 0.0), EAST, loadout))
	state.characters.append(Character.new(1, 1, Vector3(6.0, 0.0, 0.0), -EAST, loadout))
	var bots := BotController.new(state, 1, m, nav, w, tuning, config)
	sim.start_match(state)
	bots.observe(state)
	state.characters[0].position = Vector3(-6.0, 0.0, 0.0)
	state.characters[0].yaw = EAST
	return [sim, state, bots, w]


## Runs the glass match until the bot has counted past no_shot_move_after, then takes the glass away (the line is open)
## and returns the seconds until the bot's mode is FIGHT with no_shot_for back at 0, or -1.0 if it never is in `limit`.
func _seconds_to_fight_again(pushes_in: bool, delay: float, limit: float) -> float:
	var f := _glass_match()
	var sim: Simulation = f[0]
	var state: GameState = f[1]
	var bots: BotController = f[2]
	var w: BoxWorld = f[3]
	var commands: Array[PlayerCommand] = [PlayerCommand.new(), PlayerCommand.new()]
	var b := bots.world.bots[0]
	if pushes_in:
		# A style of its own: the neutral one is shared by every bot without a personality.
		b.style = BotsFile.Style.new()
		b.style.pushes_in = true
	var went := false
	for t in roundi(8.0 / DT):
		state.characters[1].position = Vector3(6.0, 0.0, 0.0)
		bots.think(state, commands, DT)
		sim.step(state, commands, DT)
		bots.observe(state)
		if b.no_shot_for >= config.no_shot_move_after:
			went = true
			break
	assert_true(went, "the bot counted past the threshold through the glass")
	# It keeps at it for a while (a pusher sprints at the pane) before the line opens.
	for t in roundi(delay / DT):
		state.characters[1].position = Vector3(6.0, 0.0, 0.0)
		bots.think(state, commands, DT)
		sim.step(state, commands, DT)
		bots.observe(state)
	for i in w.box_clear.size():
		if w.box_clear[i] != 0:
			w.box_off[i] = 1
	for t in roundi(limit / DT):
		state.characters[1].position = Vector3(6.0, 0.0, 0.0)
		bots.think(state, commands, DT)
		sim.step(state, commands, DT)
		bots.observe(state)
		if b.mode == Bot.Mode.FIGHT and b.no_shot_for == 0.0:
			return t * DT
	return -1.0


func test_a_bot_fights_again_once_the_glass_is_gone() -> void:
	var s := _seconds_to_fight_again(false, 3.0, 0.5)
	assert_gt(s, -0.5, "it squares up within half a second of the line opening")


func test_a_bot_that_pushes_in_fights_again_once_the_glass_is_gone() -> void:
	var s := _seconds_to_fight_again(true, 3.0, 0.5)
	assert_gt(s, -0.5, "a pusher sprints at the spot but must fight again within half a second of the line opening (no_shot_for is only cleared where shoot() is ready, so a sprint keeps it stuck)")
