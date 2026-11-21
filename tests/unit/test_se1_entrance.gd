extends GutTest
## SE1: the ticket hall's street entrance (the owner, 2026-11-21: "a station entrance/exit door just behind where the
## players start ... stairs going up to an outside street ... maybe add a gate"). A doorway in the hall's west wall,
## and behind it one solid block drawn as the stairs, the escalator, the locked gate and the street: look only, so
## nobody walks out. Its two lamps carry their own floor (`floor` in the file), so their light stops at the hall's.

const MODEL := "res://assets/models/props/station_entrance.glb"
const C := 8.9   # the hall's floor in the game (layout.py C + LIFT)

var cfg: RoofConfig = RoofConfig.new()


func _subway() -> MapData:
	return MapData.load_map("subway", MapStyle.new(), 6)


func _entrance(m: MapData) -> MapData.Block:
	for b in m.blocks:
		if b.dress == &"station_entrance":
			return b
	return null


func _solid_at(m: MapData, p: Vector3) -> Array[MapData.Block]:
	var out: Array[MapData.Block] = []
	for b in m.blocks:
		if AABB(b.center - b.size / 2.0, b.size).has_point(p):
			out.append(b)
	return out


func test_one_entrance_block_behind_the_west_wall_facing_the_hall() -> void:
	var m := _subway()
	var b := _entrance(m)
	assert_not_null(b, "the entrance block is in the file")
	if b == null:
		return
	assert_eq(b.kind, &"wall", "a solid wall block: nobody walks or shoots into the street")
	assert_eq(b.facing, &"+x", "its gate faces the hall")
	assert_almost_eq(b.center.x + b.size.x / 2.0, -55.0, 0.001, "its gate stands at the hall's west wall")
	assert_almost_eq(b.center.y - b.size.y / 2.0, C, 0.001, "it stands on the hall's floor")
	assert_almost_eq(b.size, Vector3(11.5, 5.0, 4.8), Vector3.ONE * 0.001)


func test_the_doorway_opens_only_onto_the_entrance_block() -> void:
	var m := _subway()
	# just inside the hall's west wall line, in the doorway: only the entrance block is there, no wall piece over it
	for y: float in [C + 0.5, C + 1.6, C + 3.0]:
		var hits := _solid_at(m, Vector3(-55.1, y, 0.0))
		assert_eq(hits.size(), 1, "one block at the doorway at %.1f m" % y)
		if hits.size() == 1:
			assert_eq(hits[0].dress, &"station_entrance")
	# the wall still stands either side of the doorway
	for z: float in [-3.5, 3.5]:
		var wall := _solid_at(m, Vector3(-55.15, C + 1.6, z))
		assert_eq(wall.size(), 1, "the hall's wall beside the doorway at z %.1f" % z)


func test_no_floor_beyond_the_doorway() -> void:
	var m := _subway()
	for x: float in [-56.0, -60.0, -65.0]:
		assert_false(is_finite(m.floor_under(x, 0.0, C + 0.5)) and m.floor_under(x, 0.0, C + 0.5) > C - 0.5,
				"no floor to stand on behind the gate at x %.1f" % x)


func test_the_entrance_lamps_carry_the_hall_floor() -> void:
	var m := _subway()
	var found := 0
	for i in m.roof_lamps.size():
		var at := m.roof_lamps[i]
		if at.x < -55.0:
			found += 1
			assert_almost_eq(m.roof_lamp_floors[i], C, 0.001, "lamp %d's light stops at the hall floor" % i)
			assert_lt(m.roof_lamp_heights[i], C + 5.0, "lamp %d hangs inside the entrance" % i)
	assert_eq(found, 2, "two lamps light the entrance")
	assert_eq(m.roof_lamp_floors.size(), m.roof_lamps.size(), "one floor entry per lamp")


func test_lamp_floor_is_read_and_missing_is_nan() -> void:
	var m := MapData.parse('{"blocks": [], "spawns": [[], []], "deadZones": [[], []], "roof": {"height": 4.0, '
			+ '"plain": true, "lamps": [{"x": 0, "z": 0, "floor": 1.5}, {"x": 1, "z": 1}]}}', MapStyle.new(), 1)
	assert_eq(m.roof_lamp_floors.size(), 2)
	assert_almost_eq(m.roof_lamp_floors[0], 1.5, 0.001)
	assert_true(is_nan(m.roof_lamp_floors[1]), "no floor: NAN, so floor_under decides")


func test_plain_reaches_uses_the_lamps_own_floor_first() -> void:
	var m := MapData.parse('{"blocks": [], "spawns": [[], []], "deadZones": [[], []], "roof": {"height": 4.0, '
			+ '"plain": true, "lamps": [{"x": 0, "z": 0, "floor": 1.5}, {"x": 1, "z": 1}]}}', MapStyle.new(), 1)
	var spots: Array[Vector3] = [Vector3(0, 3.5, 0), Vector3(1, 3.5, 1)]
	var r := RoofView.plain_reaches(m, spots, cfg)
	assert_almost_eq(r[0], 3.5 - 1.5 + cfg.plain_lamp_reach, 0.001, "its own floor")
	assert_almost_eq(r[1], 3.5 + cfg.plain_lamp_reach, 0.001, "no floor, no block under it: the ground")


func test_the_model_fills_its_block() -> void:
	var scene := load(MODEL) as PackedScene
	assert_not_null(scene, "the entrance model loads")
	if scene == null:
		return
	var root := scene.instantiate()
	var box := AABB()
	var first := true
	var tris := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		var a := (mi as MeshInstance3D).transform * mesh.get_aabb()
		box = a if first else box.merge(a)
		first = false
		for s in mesh.get_surface_count():
			tris += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	root.free()
	# the model's front (-Y in Blender, -Z here) to the hall: 4.8 wide, 5 high, 11.5 deep from its floor up
	assert_almost_eq(box.size, Vector3(4.8, 5.0, 11.5), Vector3.ONE * 0.002)
	assert_almost_eq(box.position.y, 0.0, 0.002)
	assert_between(tris, 4800, 5150, "about 95 % of its 5,150 triangle budget")
	assert_true(PropDressConfig.new().models.has(&"station_entrance"), "PropDress knows the model")


func test_the_street_and_the_sign_are_lit() -> void:
	# the street up the stair and the way-out sign's letters are kind 9 (lit): they glow by their own colour
	var scene := load(MODEL) as PackedScene
	if scene == null:
		fail_test("the entrance model loads")
		return
	var root := scene.instantiate()
	var lit := 0
	var kinds := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var uvs: Variant = mesh.surface_get_arrays(s)[Mesh.ARRAY_TEX_UV]
			if uvs == null:
				continue
			for uv: Vector2 in uvs as PackedVector2Array:
				if uv.y >= 100.5:
					kinds += 1
					if absf(uv.y - 109.0) < 0.01:
						lit += 1
	root.free()
	assert_gt(lit, 0, "the street's faces are lit")
	assert_gt(kinds, lit, "the rest (steel, glass, aluminium) keep their own kinds")
	var shader := load("res://game/play/look/look_vertex.gdshader") as Shader
	assert_true(shader.code.contains("daylight_glow"), "the props' shader makes kind 9 glow")
