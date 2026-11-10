extends GutTest
## SX1 · QA: a pick or best time saved while The Street existed ("street") loads without an error and leaves a playable
## state: the remembered map is passed over, the best time is kept as data and no longer shown anywhere.


func test_a_remembered_street_pick_keeps_the_default_map() -> void:
	var p := Progress.new(LevelTable.shared())
	p.last_map = "street"
	var picks := MatchPicks.new()
	var before := picks.map_id
	picks.recall(p)
	assert_eq(picks.map_id, before, "the removed map is not picked")
	assert_not_null(MapCatalog.shared().find(picks.map_id), "the pick is a map that is in the game")


func test_a_saved_street_best_challenge_loads_and_the_ranges_is_untouched() -> void:
	var r := Records.new()
	var problems := r.from_dict({"best_challenge": {"range": 7, "street": 42}})
	assert_eq(problems.size(), 0)
	assert_eq(r.best_challenge.get("range", 0), 7)
