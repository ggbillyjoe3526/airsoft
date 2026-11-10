extends GutTest
## Kingsmere became Subway (owner, 2026-11-10): the map is listed by its new id and name, and a save that remembers
## the old id as the last map played picks Subway again.


func test_the_station_is_listed_as_subway_and_kingsmere_is_gone() -> void:
	var entry: MapCatalog.Entry = MapCatalog.shared().find("subway")
	assert_not_null(entry, "the metro station's id is subway")
	if entry != null:
		assert_eq(entry.display_name, "Subway")
	assert_null(MapCatalog.shared().find("kingsmere"), "the old id is gone")


func test_a_save_remembering_kingsmere_picks_subway() -> void:
	var p := Progress.new(LevelTable.shared())
	var problems: Array[String] = p.from_dict({"xp": 0, "unlocked": [], "last_map": "kingsmere", "last_team": 1})
	assert_eq(problems, [] as Array[String])
	assert_eq(p.last_map, "subway", "the renamed map follows its new id")
	var picks := MatchPicks.new()
	picks.recall(p)
	assert_eq(picks.map_id, "subway", "the Match page picks Subway")
	assert_eq(p.to_dict().get("last_map"), "subway", "the next save writes the new id")


func test_other_remembered_maps_are_untouched() -> void:
	var p := Progress.new(LevelTable.shared())
	p.from_dict({"last_map": "woodland"})
	assert_eq(p.last_map, "woodland")
