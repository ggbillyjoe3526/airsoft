extends GutTest
## LF1 follow-up: the open-ground storey (BotPlant.on_bomb_level) at its edges.

var w: BotWorld
var rise := 6.0


func before_each() -> void:
	w = BotWorld.new()
	w.cfg = BotConfig.load_default()
	w.plant = PlantState.new()
	w.plant.position = Vector3(0.0, 0.0, 0.0)
	w.terrain = TerrainGrid.create(0.0, -10.0, 1.0, 40, 20,
			func(x: float, _z: float) -> float: return clampf(x / 20.0, 0.0, 1.0) * rise)


func _at(p: Vector3) -> Character:
	var loadout: Array[ReplicaConfig] = []
	return Character.new(0, 0, p, 0.0, loadout)


func test_a_character_off_the_terrain_grid_is_not_on_open_ground() -> void:
	var c := _at(Vector3(500.0, rise, 0.0))
	assert_false(BotPlant.on_bomb_level(c, w), "NAN ground: falls back to the height rule")


func test_a_bomb_off_the_terrain_grid_is_not_on_open_ground() -> void:
	w.plant.position = Vector3(-50.0, 0.0, 0.0)
	assert_false(BotPlant.on_bomb_level(_at(Vector3(30.0, rise, 0.0)), w))


func test_a_deck_over_the_slope_is_its_own_storey() -> void:
	var c := _at(Vector3(30.0, rise + w.cfg.plant_ground_reach + 1.0, 0.0))
	assert_false(BotPlant.on_bomb_level(c, w), "a tower deck over open ground is not it")


func test_no_terrain_keeps_the_height_rule() -> void:
	w.terrain = null
	assert_false(BotPlant.on_bomb_level(_at(Vector3(30.0, rise, 0.0)), w), "Depot, Subway: unchanged")
	assert_true(BotPlant.on_bomb_level(_at(Vector3(30.0, 1.0, 0.0)), w))


func test_open_ground_up_the_slope_is_the_bombs_storey() -> void:
	assert_true(BotPlant.on_bomb_level(_at(Vector3(30.0, rise, 0.0)), w))
