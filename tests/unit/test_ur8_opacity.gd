extends GutTest
## UR8: Settings › HUD › HUD opacity fades only the replica panel (count, magazines, bombs) and the minimap, words and
## all, in a match (owner, 2026-11-03: "The opacity only affects the HUD during a match. The magazine/bomb counter and
## the minimap").

var map: MapData = null
var you: Character = null


func before_all() -> void:
	map = MapData.load_map("depot", MapStyle.new(), 1)
	you = Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())


func _hud() -> Hud:
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
	var cfg := MinimapConfig.new()
	hud.setup_minimap(map, cfg, MinimapHearing.new(cfg), "Depot", 1)
	return hud


func test_the_opacity_fades_the_replica_panel_and_the_minimap() -> void:
	var hud := _hud()
	var p := HudPrefs.new()
	p.panel_opacity = 0.4
	hud.apply_prefs(p)
	assert_almost_eq(hud._replica.modulate.a, 0.4, 0.001)
	assert_almost_eq(hud._minimap.modulate.a, 0.4, 0.001)
	p.panel_opacity = 1.0
	hud.apply_prefs(p)
	assert_almost_eq(hud._replica.modulate.a, 1.0, 0.001, "back to solid")
	assert_almost_eq(hud._minimap.modulate.a, 1.0, 0.001)


func test_a_minimap_built_after_the_prefs_takes_the_opacity() -> void:
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
	var p := HudPrefs.new()
	p.panel_opacity = 0.5
	hud.apply_prefs(p)
	var cfg := MinimapConfig.new()
	hud.setup_minimap(map, cfg, MinimapHearing.new(cfg), "Depot", 1)
	assert_almost_eq(hud._minimap.modulate.a, 0.5, 0.001)


func test_the_rest_of_the_hud_stays_solid() -> void:
	var hud := _hud()
	var p := HudPrefs.new()
	p.panel_opacity = 0.3
	hud.apply_prefs(p)
	assert_almost_eq(hud.score().modulate.a, 1.0, 0.001)
	assert_almost_eq(HudStyle.backing_on(hud.score(), 1.0).a, 1.0, 0.001, "the score's plate")
	assert_almost_eq(hud.feed().modulate.a, 1.0, 0.001)
	assert_almost_eq(hud.modulate.a, 1.0, 0.001)


func test_the_slider_goes_down_to_twenty_percent() -> void:
	var p := HudPrefs.new()
	p.from_dict({"panel_opacity": 0.2})
	assert_almost_eq(p.panel_opacity, 0.2, 0.001)
	p.from_dict({"panel_opacity": 0.1})
	assert_almost_eq(p.panel_opacity, HudPrefs.new().panel_opacity, 0.001, "under the range: the default")
