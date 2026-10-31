extends GutTest
## Woodland's match guards (WL10; the browser game's ai/woodlandNightMatch.test.ts): whole bot-against-bot matches at
## 5v5 at night (its second time of day since WR1), the size it plays, in Elimination and Attack / Defend, over 16 seeds
## at Normal and 8 at Easy and Hard, checking what must never happen on any seed (MatchGuard, as for Depot): rounds
## settle, nobody is stuck or held up, falls through the ground, flies or leaves the level, and no bot knocks out a
## teammate. Who wins is the balance report's (BR1). A match there takes 50 to 70 s headless, so the tests run as five
## CI jobs of 8 or 16 matches (tools/match_guards.sh test_woodland_guards <part of a name>: elimination_at_normal,
## elimination_at_easy, attack_defend_at_normal, attack_defend_at_easy and at_hard).


func test_woodland_elimination_at_normal() -> void:
	await MatchGuard.elimination(self, "woodland", &"normal", MatchGuard.SEEDS, true)


func test_woodland_elimination_at_easy() -> void:
	await MatchGuard.elimination(self, "woodland", &"easy", MatchGuard.LEVEL_SEEDS, true)


func test_woodland_elimination_at_hard() -> void:
	await MatchGuard.elimination(self, "woodland", &"hard", MatchGuard.LEVEL_SEEDS, true)


func test_woodland_attack_defend_at_normal() -> void:
	var t: PackedInt32Array = await MatchGuard.attack_defend(self, "woodland", &"normal", MatchGuard.SEEDS, true)
	assert_gt(t[1], 0, "Woodland: some rounds are won by raising the flag")


func test_woodland_attack_defend_at_easy() -> void:
	await MatchGuard.attack_defend(self, "woodland", &"easy", MatchGuard.LEVEL_SEEDS, true)


func test_woodland_attack_defend_at_hard() -> void:
	await MatchGuard.attack_defend(self, "woodland", &"hard", MatchGuard.LEVEL_SEEDS, true)
