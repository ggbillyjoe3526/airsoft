class_name OldWoodland
extends RefCounted
## The first Woodland, a 120 x 80 m night wood with the Knoll and the Fort (`maps/old_woodland.json`), kept for the tests
## written against its layout when Woodland became the owner's concept 3 (WR1, 2026-10-31): its terrain, blocks, bushes,
## lights, ends, lanes, areas and flags as they were. Test-only (tests/ never ships), and never in the catalogue: loaded
## from its file.

const PATH := "res://tests/support/maps/old_woodland.json"


## The old wood at `team_size` a side, read with `style`.
static func load_map(style: MapStyle, team_size: int) -> MapData:
	var m := MapData.parse(FileAccess.get_file_as_string(PATH), style, team_size)
	m.id = "old_woodland"
	return m
