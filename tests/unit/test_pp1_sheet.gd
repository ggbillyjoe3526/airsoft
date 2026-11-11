extends GutTest
## The Loadout's Performance sheet in the preliminary Dev 3 pass (PP1): Spread is the figure from the hip, with a
## replica's hip spread counted (the Sniper Rifle 0.1° read as the tightest when it is 0.6° from the hip), and a
## replica whose pace or spread on the move isn't ×1 (the Compact SMG) shows those rows; every other replica doesn't.


func _sheet(id: StringName) -> LoadoutPerformance.Sheet:
	var r := ReplicaStats.load_replica(id)
	var tuning := SimTuning.new()
	var f := LoadoutPerformance.measure(r, r.bb_weight, r.hop_up_dial, tuning, 0.15, 60.0, 1.2)
	return LoadoutPerformance.compare(f, f, false, 0.0)


func _row(sheet: LoadoutPerformance.Sheet, field: StringName) -> LoadoutPerformance.Row:
	for r in sheet.rows:
		if r.field == field:
			return r
	return null


func test_spread_is_the_figure_from_the_hip() -> void:
	var sniper := ReplicaStats.load_replica(&"sniper")
	assert_eq(_row(_sheet(&"sniper"), &"spread").text, "%.2f" % (sniper.spread_deg * sniper.hip_spread))
	assert_gt(sniper.hip_spread, 1.0, "the sniper is wider from the hip")
	var aeg := ReplicaStats.load_replica(&"aeg")
	assert_eq(_row(_sheet(&"aeg"), &"spread").text, "%.2f" % aeg.spread_deg, "a ×1 hip spread reads as before")


func test_pace_and_spread_moving_show_only_off_one() -> void:
	var smg := _sheet(&"smg")
	assert_true(_row(smg, &"pace").is_shown(PackedStringArray()), "the Compact SMG's pace shows")
	assert_true(_row(smg, &"move_spread").is_shown(PackedStringArray()))
	assert_eq(_row(smg, &"pace").text, "%.2f" % ReplicaStats.load_replica(&"smg").pace)
	for id: StringName in [&"aeg", &"pistol", &"sniper", &"cyber"]:
		var s := _sheet(id)
		assert_false(_row(s, &"pace").is_shown(PackedStringArray()), "%s: no pace row at ×1" % id)
		assert_false(_row(s, &"move_spread").is_shown(PackedStringArray()), "%s: no moving spread row" % id)
