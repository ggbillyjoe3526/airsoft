extends GutTest
## BP10: the Clearing's west edge has standing cover going in (a tyre stack, not a lone low tyre), and nothing near
## it is squeezed shut.

const WEST_EDGE := Vector2(-15.0, -4.0)
## A body stands this tall (m); cover that stops a BB at the chest is at least this high at its top.
const STANDING_TOP := 1.4
## The least clear gap (m) a body needs between the stack and a neighbouring block.
const MIN_GAP := 0.8


func _blocks() -> Array:
	var f: FileAccess = FileAccess.open("res://data/maps/woodland.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return (parsed as Dictionary)["blocks"] as Array


func _at_edge() -> Array:
	var found: Array = []
	for b: Variant in _blocks():
		var d: Dictionary = b
		var c: Dictionary = d["center"]
		if absf(float(c["x"]) - WEST_EDGE.x) < 0.3 and absf(float(c["z"]) - WEST_EDGE.y) < 0.3:
			found.append(d)
	return found


func test_the_clearings_west_edge_has_standing_cover() -> void:
	var found: Array = _at_edge()
	assert_eq(found.size(), 1, "one block stands at the Clearing's west edge")
	var d: Dictionary = found[0]
	var c: Dictionary = d["center"]
	var s: Dictionary = d["size"]
	assert_gt(float(c["y"]) + float(s["y"]) * 0.5, STANDING_TOP, "its top is above standing chest height")


func test_the_west_edge_stack_leaves_a_body_wide_gap_to_its_neighbours() -> void:
	var d: Dictionary = _at_edge()[0]
	var c: Dictionary = d["center"]
	var s: Dictionary = d["size"]
	var tight: Array[String] = []
	for b: Variant in _blocks():
		var o: Dictionary = b
		if o == d:
			continue
		var oc: Dictionary = o["center"]
		var os: Dictionary = o["size"]
		var gx: float = absf(float(oc["x"]) - float(c["x"])) - (float(os["x"]) + float(s["x"])) * 0.5
		var gz: float = absf(float(oc["z"]) - float(c["z"])) - (float(os["z"]) + float(s["z"])) * 0.5
		if gx < MIN_GAP and gz < MIN_GAP and float(oc["y"]) - float(os["y"]) * 0.5 < 1.0:
			tight.append("%s at %s" % [o["kind"], oc])
	assert_eq(tight, [] as Array[String], "no low block squeezes a slot beside the stack")
