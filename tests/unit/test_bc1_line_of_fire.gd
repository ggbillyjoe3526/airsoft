extends GutTest
## A bot's line-of-fire check past a wall's edge (BC1, game/ai/bot_combat.gd _friendly_reach): its BB leaves from where
## this tick's step takes the eye, so a wall it shoots past the edge of only stops a miss when it stands that far to
## either side too. On Depot a bot strafing past a doorway's edge shot a teammate through it, its check 4 cm behind.

var cfg: BotConfig = BotConfig.load_default()


## A wall 3 m tall across the aim 1.5 m ahead, ending `edge` m to the shooter's right of its eye (the wall runs left).
func _world(edge: float) -> BotWorld:
	var level := BoxWorld.new()
	level.add_box(Vector3(edge - 2.5, 1.5, -1.5), Vector3(5.0, 3.0, 0.2))
	var w := BotWorld.new()
	w.cfg = cfg
	w.query = level
	return w


func test_a_wall_ending_just_past_the_eye_stops_a_miss_only_for_a_still_shooter() -> void:
	var w := _world(0.03)
	var eye := Vector3(0.0, 1.5, 0.0)
	var dir := Vector3(0.0, 0.0, -1.0)
	var full := BotCombat.miss_reach(cfg, 1.0)
	var wall := 1.4
	assert_almost_eq(BotCombat._friendly_reach(w, eye, dir, 1.0, wall, 0.0), wall + cfg.friendly_past_wall, 1e-4,
			"standing still, the wall stops what misses")
	# Strafing at a run: the eye moves 5 cm this tick, past the wall's end.
	assert_almost_eq(BotCombat._friendly_reach(w, eye, dir, 1.0, wall, 0.0, 0.05), full, 1e-4,
			"its BB may leave from past the edge, so a teammate beyond the wall still counts")


func test_a_wall_wide_of_the_step_still_stops_a_miss() -> void:
	var w := _world(1.0)
	var eye := Vector3(0.0, 1.5, 0.0)
	var dir := Vector3(0.0, 0.0, -1.0)
	assert_almost_eq(BotCombat._friendly_reach(w, eye, dir, 1.0, 1.4, 0.0, 0.05), 1.4 + cfg.friendly_past_wall, 1e-4)
