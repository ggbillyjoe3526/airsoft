extends GutTest
## Replica numbers from data/stats.md (game/config/replica_stats.gd), ported from the browser game's config/stats.test.ts
## and replicasBuiltIn.test.ts: the file is what plays, a cell it can't read keeps the built-in number and is reported
## with its line, and the built-in replicas equal the file's rows.

const REPLICAS := """## Replicas
| Key | Name | Class | Energy (J) | BB (g) | Fire rate (BBs/s) | Magazine (BBs) | Magazines | Reload (s) | Draw (s) | Spread (°) | Recoil (°) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| aeg | AEG Rifle | rifle | 1.1 | 0.28 | 15 | 30 | 5 | 2 | 0.5 | 0.4 | 0.2 |
"""

var aeg: ReplicaConfig
var pistol: ReplicaConfig


func before_each() -> void:
	aeg = load("res://game/config/replicas/aeg.tres") as ReplicaConfig
	pistol = load("res://game/config/replicas/pistol.tres") as ReplicaConfig


func numbers(r: ReplicaConfig) -> Array:
	return [r.muzzle_energy, r.bb_weight, r.fire_rate, r.mag_size, r.mags, r.reload_time, r.draw_time, r.spread_deg,
			r.recoil_deg]


func test_stats_md_reads_without_a_single_problem() -> void:
	var s := ReplicaStats.read_file()
	assert_eq(s.problems, [] as Array[String])
	assert_true(s.replicas.has("aeg") and s.replicas.has("pistol"))


func test_the_built_in_replicas_equal_their_stats_md_rows() -> void:
	var s := ReplicaStats.read_file()
	for built_in: ReplicaConfig in [aeg, pistol]:
		var row: Dictionary = s.replicas[String(built_in.id)]
		assert_eq(row.size(), ReplicaStats.COLUMNS.size(), "%s: every column read" % built_in.id)
		for field: StringName in row:
			assert_eq(built_in.get(field), row[field], "%s %s" % [built_in.id, field])


func test_the_built_ins_are_the_aeg_rifle_and_gbb_pistol() -> void:
	assert_eq([aeg.display_name, aeg.power, aeg.default_fire_mode, aeg.hop_up_max, aeg.hop_up_dial],
			["AEG Rifle", &"electric", ReplicaConfig.FireMode.AUTO, 0.3, 0.65])
	assert_eq([pistol.display_name, pistol.power, pistol.default_fire_mode, pistol.hop_up_max, pistol.hop_up_dial],
			["GBB Pistol", &"gas", ReplicaConfig.FireMode.SEMI, 0.19, 0.75])
	assert_eq(numbers(aeg), [0.97, 0.25, 13.0, 60, 4, 1.8, 0.45, 0.45, 0.18])
	assert_eq(numbers(pistol), [0.7, 0.2, 7.0, 18, 4, 1.0, 0.22, 0.65, 0.5])


func test_the_default_loadout_is_the_aeg_then_the_pistol_through_stats_md() -> void:
	var loadout := ReplicaStats.default_loadout()
	assert_eq(loadout.size(), 2)
	assert_eq([loadout[0].id, loadout[1].id], [&"aeg", &"pistol"])
	assert_eq(numbers(loadout[0]), numbers(aeg))
	assert_ne(loadout[0], aeg, "a copy: the cached built-in is never changed")
	assert_eq(ReplicaStats.load_replica(&"pistol").site_class, &"pistol")


func test_lays_a_file_over_the_built_in_numbers() -> void:
	var r := ReplicaStats.apply(aeg, REPLICAS + "\n## Site limits\n| Class | Limit (J) |\n|---|---|\n| rifle | 1.5 |\n")
	assert_eq(numbers(r), [1.1, 0.28, 15.0, 30, 5, 2.0, 0.5, 0.4, 0.2])
	assert_eq(r.display_name, aeg.display_name, "names stay the code's")
	assert_eq(aeg.mag_size, 60, "the built-in is left alone")
	var s := ReplicaStats.parse(REPLICAS + "\n## Site limits\n| Class | Limit (J) |\n|---|---|\n| rifle | 1.5 |\n")
	assert_eq(s.problems, [] as Array[String])
	assert_eq(s.energy_limit(&"rifle"), 1.5)
	assert_eq(s.energy_limit(&"pistol"), 1.0, "a class the file leaves out keeps the built-in limit")
	assert_eq(s.energy_limit(&"sniper"), 2.3, "the bolt-action class keeps its built-in limit too")
	assert_eq(s.energy_limit(&"dmr"), INF, "a class with no limit anywhere has none")


func test_a_cell_it_cannot_read_keeps_the_built_in_number_and_is_reported_with_its_line() -> void:
	var text := REPLICAS.replace("| 1.1 |", "| lots |").replace("| 15 |", "| 500 |").replace("| 5 |", "| 2.5 |")
	var s := ReplicaStats.parse(text)
	assert_eq(s.problems.size(), 4, str(s.problems)) # three cells, and no Site limits table
	assert_string_starts_with(s.problems[0], "stats.md:4: Energy (J) must be a number")
	assert_string_starts_with(s.problems[1], "stats.md:4: Fire rate (BBs/s) must be a number from 0.5 to 50")
	assert_string_starts_with(s.problems[2], "stats.md:4: Magazines must be a whole number from 1 to 20")
	var r := s.overlay(aeg)
	assert_eq([r.muzzle_energy, r.fire_rate, r.mags], [aeg.muzzle_energy, aeg.fire_rate, aeg.mags])
	assert_eq([r.bb_weight, r.mag_size], [0.28, 30], "the cells it could read")
	assert_eq(ReplicaStats.apply(aeg, text).muzzle_energy, aeg.muzzle_energy, "apply warns and keeps it too")


func test_reports_a_missing_column_once_and_keeps_the_built_in_number_for_it() -> void:
	var text := "\n".join(PackedStringArray([
		"## Replicas",
		"| Key | Name | Class | Energy (J) | BB (g) | Fire rate (BBs/s) | Magazine (BBs) | Magazines | Reload (s) | Draw (s) | Spread (°) |",
		"|---|---|---|---|---|---|---|---|---|---|---|",
		"| aeg | AEG Rifle | rifle | 1.1 | 0.28 | 15 | 30 | 5 | 2 | 0.5 | 0.4 |",
		"| pistol | GBB Pistol | pistol | 0.6 | 0.2 | 8 | 20 | 3 | 1 | 0.2 | 0.7 |",
	]))
	var s := ReplicaStats.parse(text)
	var missing := s.problems.filter(func(p: String) -> bool: return p.contains("Recoil (°)"))
	assert_eq(missing, ["stats.md:2: the Replicas table has no \"Recoil (°)\" column: using the built-in numbers"])
	var a := s.overlay(aeg)
	var p := s.overlay(pistol)
	assert_eq([a.recoil_deg, p.recoil_deg], [aeg.recoil_deg, pistol.recoil_deg])
	assert_eq([a.muzzle_energy, p.muzzle_energy, p.mag_size], [1.1, 0.6, 20])


func test_a_missing_table_or_file_falls_back_to_the_built_in_numbers() -> void:
	var none := ReplicaStats.parse("# nothing here")
	assert_eq(none.problems.size(), 2, "one each for Replicas and Site limits")
	assert_eq(none.energy_limit(&"rifle"), 1.2)
	assert_eq(numbers(none.overlay(aeg)), numbers(aeg))
	assert_eq(ReplicaStats.parse("").problems.size(), 2)
	var missing := ReplicaStats.read_file("res://data/no_such_file.md")
	assert_eq(missing.problems, ["res://data/no_such_file.md can't be read: using the built-in numbers"] as Array[String])
	assert_eq(numbers(missing.overlay(pistol)), numbers(pistol))
	assert_eq(missing.energy_limit(&"pistol"), 1.0)


func test_reports_bad_keys_repeated_rows_and_bad_limits_and_keeps_going() -> void:
	var text := REPLICAS + "| 9mm | Bad | pistol | 1 | 0.2 | 7 | 18 | 4 | 1 | 0.3 | 0.8 | 0.5 |\n" \
			+ "| aeg | Again | rifle | 1 | 0.2 | 7 | 18 | 4 | 1 | 0.3 | 0.8 | 0.5 |\n" \
			+ "\n## Site limits\n| Class | Limit (J) |\n|---|---|\n| Rifle | 50 |\n| Pistol Class | 1 |\n| smg | 1.1 |\n"
	var s := ReplicaStats.parse(text)
	assert_eq(s.problems.size(), 4, str(s.problems))
	assert_string_starts_with(s.problems[0], "stats.md:5: Key must be a Key")
	assert_string_starts_with(s.problems[1], "stats.md:6: aeg is listed twice")
	assert_string_starts_with(s.problems[2], "stats.md:11: Limit (J) must be a number from 0.1 to 10")
	assert_string_starts_with(s.problems[3], "stats.md:12: Class must be a lower case word")
	assert_eq(s.overlay(aeg).mag_size, 30, "the first aeg row stands")
	assert_eq(s.energy_limit(&"smg"), 1.1)
