extends GutTest
## UL2: a plain roof's strip lamps feed the bounce light more than a hall's high bays. (UL2's stronger SDFGI
## underground went with UL3: no SDFGI gathers underground; tests/unit/test_ul3_underground_fill.gd.)

var cfg: RoofConfig = RoofConfig.new()
var spots: Array[Vector3] = [Vector3(0, 4, 0), Vector3(4, 4, 0)]


func test_a_plain_roofs_lamps_feed_the_bounce_more() -> void:
	var reaches := PackedFloat32Array([3.0, 3.0])
	var plain := RoofLamps.build(spots, cfg, 0.0, null, PackedByteArray(), reaches)
	add_child_autofree(plain)
	for spot in plain.lights():
		assert_almost_eq(spot.light_indirect_energy, cfg.plain_lamp_indirect, 0.0001)
	assert_gt(cfg.plain_lamp_indirect, 1.0)


func test_a_halls_lamps_keep_the_engines_bounce() -> void:
	var hall := RoofLamps.build(spots, cfg)
	add_child_autofree(hall)
	for spot in hall.lights():
		assert_almost_eq(spot.light_indirect_energy, 1.0, 0.0001, "Depot's lamps unchanged")


func test_subway_lamps_are_plain_and_depots_are_not() -> void:
	assert_true(MapData.load_map("subway", MapStyle.new(), 6).roof_plain)
	assert_false(MapData.load_map("depot", MapStyle.new(), 6).roof_plain)


func test_dim_and_flickering_plain_lamps_keep_the_bounce_through_a_flicker_step() -> void:
	var states := PackedByteArray([MapData.LAMP_DIM, MapData.LAMP_FLICKER, MapData.LAMP_DEAD])
	var three: Array[Vector3] = [Vector3(0, 4, 0), Vector3(4, 4, 0), Vector3(8, 4, 0)]
	var reaches := PackedFloat32Array([3.0, 3.0, 3.0])
	var plain := RoofLamps.build(three, cfg, 0.0, null, states, reaches)
	add_child_autofree(plain)
	assert_eq(plain.light_count(), 2, "the dead lamp has no light")
	plain.set_flicker(1, 0.3)
	for lamp: int in [0, 1]:
		assert_almost_eq(plain.light_of(lamp).light_indirect_energy, cfg.plain_lamp_indirect, 0.0001)
	assert_eq(plain.light_of(1).light_bake_mode, Light3D.BAKE_DYNAMIC, "a flicker lamp stays dynamic")
