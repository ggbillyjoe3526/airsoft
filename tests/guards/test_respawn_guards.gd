extends GutTest
## The respawn guards (RS1): whole bot matches on Depot with respawns as the game plays them, in Attack / Defend and
## Plant The Bomb (MatchGuard.respawn_match): every match won, no round past its clock and overtime, no Attack / Defend
## round won by a wipe-out, hit bots back in every match, nobody held up or out of the level, no friendly hits. The
## other guards play one life a round (MatchGuard.one_life); who wins with respawns is the balance report's.

## Seeds a mode: rounds run out their clock with respawns, so a match takes several times a one-life match's time.
const SEEDS := 3


func test_depot_attack_defend_with_respawns() -> void:
	var t: PackedInt32Array = await MatchGuard.respawn_match(self, "depot", RoundState.Mode.ATTACK_DEFEND, SEEDS)
	assert_gt(t[0], 0, "Depot A/D: rounds are played")
	assert_gt(t[1], t[0], "Depot A/D: more than a respawn a round")


func test_depot_plant_the_bomb_with_respawns() -> void:
	var t: PackedInt32Array = await MatchGuard.respawn_match(self, "depot", RoundState.Mode.PLANT_THE_BOMB, SEEDS)
	assert_gt(t[0], 0, "Depot PTB: rounds are played")
	assert_gt(t[1], 0, "Depot PTB: hit bots come back before the plant")
