extends GutTest
## TQ2 (the owner, 2026-11-21): Subway's trains' poles, rails and grab handles are models of their own (round, smoothly
## bent tubes in the stripe's orange), one a car, one a gangway, one at every end with an end wall; the cove's advert
## cards are a car's printed model, in the advert sheet's print, shadowless, warmed, every other car's turned about,
## each card a whole cell of the sheet and a car's twelve all different; the sheet is stored as the sign sheets are and
## keeps off the team hues.

const KIND_BASE := 100.0

var play: PlayTuning = PlayTuning.load_default()


func _subway() -> MapData:
	var m := MapData.load_map("subway", play.map_style, SimTuning.new().rounds.team_size)
	assert_true(m.ok(), "subway loads: %s" % [m.problems])
	return m


func _view(m: MapData) -> TrainView:
	var view := TrainView.build(m, play.station_look.trains)
	assert_not_null(view)
	add_child_autofree(view)
	return view


func test_the_look_lists_and_loads_the_rails_and_the_adverts() -> void:
	var look := play.station_look.trains
	for path: String in [look.poles, look.gangway_rails, look.adverts, look.end_rails[&"blank"]]:
		assert_true(path in look.paths(), path)
		assert_not_null(look.mesh(path), path)
	assert_not_null(look.advert_picture(), "the advert sheet loads")
	assert_false(look.end_rails.has(&"cab_open"), "the open cab's leaves carry their own handles")
	var broken := TrainLook.new()
	broken.poles = "res://assets/models/props/none.glb"
	assert_false(broken.loads(), "a missing poles model leaves the boxes")


func test_every_car_gangway_and_walled_end_gets_its_rails() -> void:
	var m := _subway()
	var look := play.station_look.trains
	var view := _view(m)
	var cars := 0
	var gangways := 0
	var walled := 0
	for t in m.trains:
		cars += t.cars.size()
		gangways += t.gangways.size()
		for car in t.cars:
			for e in car.ends:
				if look.end_rails.has(e):
					walled += 1
	assert_gt(walled, 0, "the trains have walled ends")
	assert_eq(view.count(look.poles), cars, "a car's poles")
	assert_eq(view.count(look.adverts), cars, "a car's adverts")
	assert_eq(view.count(look.gangway_rails), gangways, "a gangway's handles")
	assert_eq(view.count(look.end_rails[&"blank"]), walled, "each end wall's handles, its end's own")
	# the poles in the props' paint, casting shadows as they did in the body
	var poles := view.view_of(look.poles)
	assert_eq(poles.material_override, view.view_of(look.body).material_override, "the props' material")
	assert_ne(poles.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_the_advert_cards_print_the_sheet_without_shadow_and_are_warmed() -> void:
	var look := play.station_look.trains
	var view := _view(_subway())
	var v := view.view_of(look.adverts)
	assert_not_null(v)
	assert_eq(v.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var print := v.material_override as ShaderMaterial
	assert_not_null(print)
	assert_true(bool(print.get_shader_parameter(&"use_sheet")), "printed")
	var sheet := print.get_shader_parameter(&"sheet") as Texture2D
	assert_not_null(sheet)
	assert_eq(sheet.resource_path, look.advert_sheet)
	assert_almost_eq(float(print.get_shader_parameter(&"roughness")), look.advert_roughness, 0.001)
	assert_true(view.materials().has(print), "warmed before play")


func test_every_other_cars_cards_are_turned_about() -> void:
	var m := _subway()
	var look := play.station_look.trains
	var view := _view(m)
	var bodies := view.placed_of(look.body)
	var cards := view.placed_of(look.adverts)
	assert_eq(cards.size(), bodies.size())
	var turned := 0
	for i in cards.size():
		var same := (cards[i] as Transform3D).is_equal_approx(bodies[i] as Transform3D)
		assert_eq(same, i % 2 == 0, "car %d's cards %s" % [i, "as its car" if i % 2 == 0 else "turned about"])
		if not same:
			turned += 1
			assert_true((cards[i] as Transform3D).origin.is_equal_approx((bodies[i] as Transform3D).origin))
	assert_gt(turned, 0)


func test_each_card_is_a_whole_cell_and_a_cars_twelve_differ() -> void:
	var look := play.station_look.trains
	var mesh := look.mesh(look.adverts)
	var cells: Dictionary[Vector2i, bool] = {}
	var cards := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		var idx := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		for t in range(0, idx.size(), 3):
			var lo := Vector2(INF, INF)
			var hi := -lo
			for k in 3:
				lo = lo.min(uvs[idx[t + k]])
				hi = hi.max(uvs[idx[t + k]])
			# a card's two triangles each span its whole cell: a quarter of the sheet across, a third down
			assert_almost_eq(hi.x - lo.x, 0.25, 0.001, "a card a cell across")
			assert_almost_eq(hi.y - lo.y, 1.0 / 3.0, 0.001, "a card a cell down")
			cells[Vector2i(roundi(lo.x * 4.0), roundi(lo.y * 3.0))] = true
			cards += 1
	assert_eq(cards, 24, "twelve cards, two triangles each")
	assert_eq(cells.size(), 12, "a car's twelve cards, the sheet's twelve adverts, each once")


func test_the_poles_wear_the_stripes_orange() -> void:
	var look := play.station_look.trains
	var own := Color("ea6a22")
	var orange := 0
	for c in look.mesh(look.poles).surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray:
		var srgb := c.linear_to_srgb()
		if absf(srgb.h - own.h) < 0.01 and absf(srgb.s - own.s) < 0.02:
			orange += 1
	assert_gt(orange, 0, "the poles in the stripe's orange")


func test_the_advert_sheet_is_stored_as_the_sign_sheets_and_keeps_off_the_team_hues() -> void:
	var path := play.station_look.trains.advert_sheet
	var import := ConfigFile.new()
	assert_eq(import.load(path + ".import"), OK, path)
	assert_true(import.get_value("params", "mipmaps/generate", false), "smaller copies for far print")
	assert_eq(import.get_value("params", "compress/mode", -1), 2, "compressed for the card")
	assert_true(import.get_value("params", "compress/high_quality", false), "BC7, print keeps its edges")
	var image := (load(path) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	var teams: Array[Color] = AccessibilityTable.read_file().colours
	teams.append_array(play.teams.colours)
	var seen := 0
	var near := 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			seen += 1
			if _near_team(image.get_pixel(x, y), teams):
				near += 1
	# (only the antialiased rims between two colours may pass near a team's hue)
	assert_lt(float(near) / seen, 0.01, "%d of %d pixels near a team's hue" % [near, seen])


## Whether a printed pixel `c` (sRGB) reads as a team's colour as seen: as saturated as FieldStandard's least and within
## its hue margin of a team's, both as the eye takes them (sRGB hue and saturation). FieldChecks.reads_as_team measures
## in linear light, where the cards' cream paper and dark night inks blow up into strong colours they are not.
func _near_team(c: Color, teams: Array[Color]) -> bool:
	if c.s < FieldStandard.MIN_SATURATION:
		return false
	for t in teams:
		var d := absf(c.h - t.h) * 360.0
		if minf(d, 360.0 - d) <= FieldStandard.HUE_MARGIN_DEG:
			return true
	return false


func test_the_orange_keeps_its_whole_colour_and_nothing_else_does() -> void:
	var look := play.station_look.trains
	var view := _view(_subway())
	var props := view.view_of(look.body).material_override as ShaderMaterial
	assert_true(bool(props.get_shader_parameter(&"keep_by_alpha")), "the train's props material keeps by alpha")
	var own := Color("ea6a22")
	for path: String in [look.body, look.poles]:
		var kept := 0
		var pulled := 0
		for c in look.mesh(path).surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray:
			var srgb := c.linear_to_srgb()
			var orange := absf(srgb.h - own.h) < 0.03 and srgb.s > 0.4
			if c.a > 0.5:
				kept += 1
				assert_true(orange, "%s: only the orange keeps its whole colour" % path.get_file())
			else:
				pulled += 1
				assert_false(orange, "%s: no orange is pulled toward grey" % path.get_file())
				if orange:
					break
		assert_gt(kept, 0, "%s: its orange kept" % path.get_file())
		if path == look.body:
			assert_gt(pulled, 0, "the body's whites and greys take the look's share")
