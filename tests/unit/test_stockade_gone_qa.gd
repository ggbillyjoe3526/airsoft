extends GutTest
## A save that names the removed Stockade map must not break the Match picks (owner, 2026-11-15).


func test_recall_of_a_removed_map_keeps_the_default_pick() -> void:
	var picks := MatchPicks.new()
	var before: String = picks.map_id
	var progress := Progress.new(LevelTable.read_file(Pool.shared()))
	progress.last_map = "stockade"
	picks.recall(progress)
	assert_eq(picks.map_id, before)
	assert_not_null(MapCatalog.shared().find(picks.map_id))
