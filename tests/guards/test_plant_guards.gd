extends GutTest
## Plant The Bomb's match guards (PB1): whole bot-against-bot matches on each field at Normal, checking what must never
## happen on any seed (as test_flag_guards.gd does for Attack / Defend) and that the bots play the bomb on their own:
## it is picked up every round, armed in most, and both ends of the mode happen (defused, and the defenders wiped or
## the fuse run out after it was armed). Who wins is measured for the record (docs/records/PB1.md), kept inside a wide
## band here so a broken side shows. Run by tools/match_guards.sh, a CI job a field (a test name's part picks each).

## Rounds the bomb is armed in, of all rounds, at least (measured: docs/records/PB1.md).
const ARMED_SHARE_MIN := 0.4
## The attackers' share of all rounds stays inside this band.
const ATTACK_BAND := Vector2(0.25, 0.7)
## Seeds a field: Depot's 16 fit a CI job; Woodland's and Subway's longer matches take 8.
const SEEDS_SHORT := 8


func test_depot_plays_the_bomb() -> void:
	_judge("Depot", await MatchGuard.plant_the_bomb(self, "depot"))


func test_woodland_plays_the_bomb() -> void:
	_judge("Woodland", await MatchGuard.plant_the_bomb(self, "woodland", &"normal", SEEDS_SHORT))


func test_subway_plays_the_bomb() -> void:
	_judge("Subway", await MatchGuard.plant_the_bomb(self, "subway", &"normal", SEEDS_SHORT))


func _judge(field: String, t: PackedInt32Array) -> void:
	var rounds := maxf(t[0], 1.0)
	assert_gt(t[1] / rounds, ARMED_SHARE_MIN, "%s: the bots arm the bomb on their own" % field)
	assert_gt(t[2], 0, "%s: armed bombs are defused" % field)
	assert_gt(t[1] - t[2], 0, "%s: armed bombs also win rounds for the attackers" % field)
	assert_between(t[5] / rounds, ATTACK_BAND.x, ATTACK_BAND.y, "%s: neither side is shut out" % field)
