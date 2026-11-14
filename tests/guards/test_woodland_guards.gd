extends GutTest
## Woodland's match guards (WL10; the browser game's ai/woodlandNightMatch.test.ts): whole bot-against-bot matches at
## 6v6 at night (its second time of day since WR1), the size it plays (TS1), in Elimination and Attack / Defend, over
## 16 seeds at Normal and 8 at Easy and Hard, checking what must never happen on any seed (MatchGuard, as for Depot):
## rounds settle, nobody is stuck or held up, falls through the ground, flies or leaves the level, and no bot knocks out a
## teammate. Who wins is the balance report's (BR1). A match there takes 50 to 70 s headless, so the tests run as
## eight CI jobs, one test each (tools/match_guards.sh test_woodland_guards <part of a name>: elimination_at_easy,
## elimination_at_hard, attack_defend_at_easy, attack_defend_at_hard, and Normal's 16 seeds in halves,
## elimination_at_normal_seeds_1, elimination_at_normal_seeds_9, attack_defend_at_normal_seeds_1 and
## attack_defend_at_normal_seeds_9: 16 in one job came within two minutes of its 30, AUD1).

## Normal's seeds a half: 1 to 8, then 9 to 16.
const HALF := MatchGuard.SEEDS / 2


func test_woodland_elimination_at_normal_seeds_1_to_8() -> void:
	await MatchGuard.elimination(self, "woodland", &"normal", HALF, true)


func test_woodland_elimination_at_normal_seeds_9_to_16() -> void:
	await MatchGuard.elimination(self, "woodland", &"normal", HALF, true, HALF + 1)


func test_woodland_elimination_at_easy() -> void:
	await MatchGuard.elimination(self, "woodland", &"easy", MatchGuard.LEVEL_SEEDS, true)


func test_woodland_elimination_at_hard() -> void:
	await MatchGuard.elimination(self, "woodland", &"hard", MatchGuard.LEVEL_SEEDS, true)


func test_woodland_attack_defend_at_normal_seeds_1_to_8() -> void:
	var t: PackedInt32Array = await MatchGuard.attack_defend(self, "woodland", &"normal", HALF, true)
	assert_gt(t[1], 0, "Woodland: some rounds are won by raising the flag")


func test_woodland_attack_defend_at_normal_seeds_9_to_16() -> void:
	var t: PackedInt32Array = await MatchGuard.attack_defend(self, "woodland", &"normal", HALF, true, HALF + 1)
	assert_gt(t[1], 0, "Woodland: some rounds are won by raising the flag")


func test_woodland_attack_defend_at_easy() -> void:
	await MatchGuard.attack_defend(self, "woodland", &"easy", MatchGuard.LEVEL_SEEDS, true)


func test_woodland_attack_defend_at_hard() -> void:
	await MatchGuard.attack_defend(self, "woodland", &"hard", MatchGuard.LEVEL_SEEDS, true)
