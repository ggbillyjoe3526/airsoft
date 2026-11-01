extends GutTest
## BQ1 · Bots see through glass (The Street's House windows and bus shelter) as players do, while it still stops their
## BBs: WorldQuery.sight_ray passes clear blocks (MapStyle.clear_kinds) that `ray` meets, on BoxWorld and on a built
## MapLevel's Jolt colliders. Sight, a held view and cover read it; a bot seeing someone it can't shoot goes round.

const GLASS := '{"kind": "glass", "center": {"x": 3, "y": 1, "z": 0}, "size": {"x": 0.06, "y": 2, "z": 3}}'
const WALL := '{"kind": "wall", "center": {"x": -3, "y": 1, "z": 0}, "size": {"x": 0.3, "y": 2, "z": 3}}'
const FLOOR := '{"kind": "floor", "center": {"x": 0, "y": -0.5, "z": 0}, "size": {"x": 12, "y": 1, "z": 12}}'
## Yaw that looks along +X.
const EAST := -PI * 0.5

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()


func _level() -> MapLevel:
	var m := MapData.parse('{"blocks": [%s]}' % ",".join([GLASS, WALL, FLOOR]), play.map_style, 1)
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, tuning.body)
	return level


## A floor with a pane of glass across x 3 (a clear box) and a wall across x -3.
func _box_world() -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(40.0, 40.0)
	w.add_clear_box(Vector3(3.0, 1.0, 0.0), Vector3(0.06, 2.0, 3.0))
	w.add_box(Vector3(-3.0, 1.0, 0.0), Vector3(0.3, 2.0, 3.0))
	return w


## A BotWorld on `query` with a viewer at the origin looking east and a target 6 m east, past the glass.
func _sight_world(query: WorldQuery) -> BotWorld:
	var w := BotWorld.new()
	w.cfg = config
	w.tuning = tuning
	w.query = query
	var loadout := ReplicaStats.default_loadout()
	w.characters.append(Character.new(0, 0, Vector3.ZERO, EAST, loadout))
	w.characters.append(Character.new(1, 1, Vector3(6.0, 0.0, 0.0), -EAST, loadout))
	return w


func test_a_box_worlds_glass_stops_a_ray_but_not_sight() -> void:
	var w := _box_world()
	var hit := RayHit.new()
	var a := Vector3(0.0, 1.0, 0.0)
	var b := Vector3(6.0, 1.0, 0.0)
	assert_true(w.ray(a, b, hit), "a BB meets the pane")
	assert_almost_eq(hit.position.x, 2.97, 0.01)
	assert_false(w.sight_ray(a, b, hit), "the eye goes through it")
	assert_true(w.sight_ray(a, Vector3(-6.0, 1.0, 0.0), hit), "a wall still hides")
	assert_almost_eq(hit.position.x, -2.85, 0.01)


func test_a_built_levels_glass_stops_a_ray_but_not_sight_and_keeps_its_surface() -> void:
	var q := _level().query()
	var hit := RayHit.new()
	var a := Vector3(0.0, 1.0, 1.0)
	var b := Vector3(6.0, 1.0, 1.0)
	assert_true(q.ray(a, b, hit), "a BB across the pane stops on it")
	assert_almost_eq(hit.position.x, 2.97, 0.05)
	assert_eq(hit.surface, play.map_style.surface_of(&"glass"), "it rings as glass does")
	assert_false(q.sight_ray(a, b, hit), "sight passes through")
	assert_true(q.sight_ray(a, Vector3(-6.0, 1.0, 1.0), hit), "a wall still hides from sight")
	assert_almost_eq(hit.position.x, -2.85, 0.05)


func test_a_level_with_no_glass_sees_as_its_ray_does() -> void:
	var m := MapData.parse('{"blocks": [%s]}' % ",".join([WALL, FLOOR]), play.map_style, 1)
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, tuning.body)
	assert_null(level.get_node_or_null(^"SightRay"), "no second ray without glass")
	var hit := RayHit.new()
	assert_true(level.query().sight_ray(Vector3(0.0, 1.0, 1.0), Vector3(-6.0, 1.0, 1.0), hit))


func test_a_bot_sees_someone_through_glass_but_not_through_a_wall() -> void:
	var w := _sight_world(_box_world())
	var viewer := w.characters[0]
	var target := w.characters[1]
	assert_gt(BotSenses.visible_part(viewer, target, w), 0.0, "seen through the pane")
	assert_false(BotSenses.line_clear(w.query, BotSenses.eye_of(viewer, tuning),
			BotSenses.body_point(target, tuning.hits, config.aim_height_fraction)), "but no BB gets there")
	target.position = Vector3(-6.0, 0.0, 0.0)
	viewer.yaw = -EAST
	assert_eq(BotSenses.visible_part(viewer, target, w), 0.0, "a wall hides them")


func test_glass_is_no_cover_from_someone_who_can_see_through_it() -> void:
	var w := _sight_world(_box_world())
	var threat := Vector3(10.0, tuning.body.stand_eye_height, 0.0)
	assert_false(BotCover.hides_from(Vector3(2.0, 0.0, 0.0), threat, w), "behind the pane you are still seen")
	assert_true(BotCover.hides_from(Vector3(-2.0, 0.0, 0.0), Vector3(-10.0, threat.y, 0.0), w),
			"behind the wall you are hidden")


## A 40 m field split by a glass wall along z at x 0, a bot at x -6 facing east and an enemy (nobody's bot) at x 6.
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
	# Whichever end each started at, the bot west of the glass and the enemy east of it.
	state.characters[0].position = Vector3(-6.0, 0.0, 0.0)
	state.characters[0].yaw = EAST
	return [sim, state, bots]


func test_a_bot_that_sees_someone_through_glass_and_has_no_shot_goes_round() -> void:
	var f := _glass_match()
	var sim: Simulation = f[0]
	var state: GameState = f[1]
	var bots: BotController = f[2]
	var commands: Array[PlayerCommand] = [PlayerCommand.new(), PlayerCommand.new()]
	var b := bots.world.bots[0]
	var dt := 1.0 / 60.0
	var saw := false
	var went := false
	for t in roundi(6.0 / dt):
		state.characters[1].position = Vector3(6.0, 0.0, 0.0)
		bots.think(state, commands, dt)
		sim.step(state, commands, dt)
		bots.observe(state)
		saw = saw or (b.target_visible and b.mode == Bot.Mode.FIGHT)
		went = went or b.mode == Bot.Mode.SEARCH
	assert_true(saw, "it sees them through the glass and squares up")
	assert_true(went, "with no shot, it goes after them instead of staring")
	assert_true(Elimination.is_in_play(state.characters[1]), "no BB got through the glass")
