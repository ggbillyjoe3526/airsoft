extends GutTest
## SM1 (trains) · QA: the station's own render layer stays clear of every layer the views peel off.


func test_the_station_layer_is_one_the_scope_camera_and_default_views_still_draw() -> void:
	var scope_view := OpticGlass.ALL_LAYERS & ~OpticGlass.HANDS_LAYER & ~AreaProbes.LAYER
	assert_ne(scope_view & StationSurface.LAYER, 0, "the scope's picture still draws the station")
	assert_ne((autofree(Camera3D.new()) as Camera3D).cull_mask & StationSurface.LAYER, 0, "so does a default camera")
	assert_eq(StationSurface.LAYER & (OpticGlass.HANDS_LAYER | AreaProbes.LAYER | LightFixtures.LAYER | 1), 0,
		"it shares no layer with the hands, probes, fixtures or the default")
