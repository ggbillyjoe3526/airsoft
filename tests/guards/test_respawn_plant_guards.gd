extends GutTest
## The respawn guards of Plant The Bomb on the fields test_respawn_guards.gd leaves to one life (BP10): Woodland and
## Subway, a match each with respawns as the game plays them (MatchGuard.respawn_match): every match won, no round past
## its clock and overtime, hit bots back before the plant, nobody held up or out of the level, no friendly hits. A job
## of its own, so the other respawn guards keep inside theirs.

## Seeds a field: forward spawns and routes back are what is guarded here; who wins is the balance report's.
const SEEDS := 1


func test_woodland_plant_the_bomb_with_respawns() -> void:
	var t: PackedInt32Array = await MatchGuard.respawn_match(self, "woodland", RoundState.Mode.PLANT_THE_BOMB, SEEDS)
	assert_gt(t[0], 0, "Woodland PTB: rounds are played")
	assert_gt(t[1], 0, "Woodland PTB: hit bots come back before the plant")


func test_subway_plant_the_bomb_with_respawns() -> void:
	var t: PackedInt32Array = await MatchGuard.respawn_match(self, "subway", RoundState.Mode.PLANT_THE_BOMB, SEEDS)
	assert_gt(t[0], 0, "Subway PTB: rounds are played")
	assert_gt(t[1], 0, "Subway PTB: hit bots come back before the plant")
