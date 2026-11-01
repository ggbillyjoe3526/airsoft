extends GutTest
## The Street's match guards (ST1): whole bot-against-bot matches at 5v5, the size it plays, by day in Elimination
## and Attack / Defend over 16 seeds at Normal, and by night at Easy and Hard over 8, checking what must never happen
## on any seed (MatchGuard, as for Depot and Woodland): rounds settle, nobody is stuck or held up, falls through the
## ground, flies or leaves the level, and no bot knocks out a teammate. Who wins is the balance report's (BR1). They run
## as CI jobs of 8 or 16 matches (tools/match_guards.sh test_street_guards <part of a name>: elimination_at_normal,
## attack_defend_at_normal and at_night).


func test_street_elimination_at_normal() -> void:
	await MatchGuard.elimination(self, "street", &"normal", MatchGuard.SEEDS)


func test_street_attack_defend_at_normal() -> void:
	var t: PackedInt32Array = await MatchGuard.attack_defend(self, "street", &"normal", MatchGuard.SEEDS)
	assert_gt(t[1], 0, "The Street: some rounds are won by raising a flag")


func test_street_elimination_at_night_at_easy() -> void:
	await MatchGuard.elimination(self, "street", &"easy", MatchGuard.LEVEL_SEEDS, true)


func test_street_attack_defend_at_night_at_hard() -> void:
	await MatchGuard.attack_defend(self, "street", &"hard", MatchGuard.LEVEL_SEEDS, true)
