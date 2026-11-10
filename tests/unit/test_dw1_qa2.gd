extends GutTest

func _cfg() -> RoofConfig:
	return RoofConfig.new()

func test_flicker_level_only_full_or_low_with_defaults() -> void:
	var c := _cfg()
	for lamp in 12:
		for t in range(0, 4000):
			var l := RoofView.flicker_level(t * 0.037, lamp, c)
			assert_true(l == 1.0 or l == c.lamp_flicker_low)

func test_flicker_never_dips_when_off_odds_zero() -> void:
	var c := _cfg()
	c.lamp_flicker_off = 0.0
	for t in range(0, 2000):
		assert_eq(RoofView.flicker_level(t * 0.05, 3, c), 1.0)

func test_flicker_all_quiet_stays_full() -> void:
	var c := _cfg()
	c.lamp_flicker_quiet = 1.0
	for t in range(0, 2000):
		assert_eq(RoofView.flicker_level(t * 0.05, 5, c), 1.0)

func test_lamps_do_flicker_somewhere() -> void:
	var c := _cfg()
	var dipped := false
	for t in range(0, 6000):
		if RoofView.flicker_level(t * 0.05, 2, c) < 1.0:
			dipped = true
	assert_true(dipped)

func test_lens_tint_per_state() -> void:
	var c := _cfg()
	assert_eq(RoofView.lens_tint(MapData.LAMP_WORKING, c), Color.WHITE)
	assert_eq(RoofView.lens_tint(MapData.LAMP_FLICKER, c), Color.WHITE)
	var d := RoofView.lens_tint(MapData.LAMP_DEAD, c)
	assert_eq(d.r, c.lamp_dead_glow)
	var dim := RoofView.lens_tint(MapData.LAMP_DIM, c)
	assert_almost_eq(dim.r * c.lamp_colour.r, c.lamp_dim_colour.r * c.lamp_dim_glow, 0.0001)
	assert_lt(dim.r, 1.0)
