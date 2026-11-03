extends GutTest
## UR8: Settings › HUD › HUD opacity fades only the replica panel (count, magazines, bombs) and the minimap, in a match
## (owner, 2026-11-03: "The opacity only affects the HUD during a match. The magazine/bomb counter and the minimap").
## UF1 (owner, 2026-11-03): only their backgrounds; icons, numbers and words stay solid (test_uf1_hud_opacity.gd).

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
	assert_almost_eq(HudStyle.opacity_of(hud._replica), 0.4, 0.001)
	assert_almost_eq(HudStyle.opacity_of(hud._minimap), 0.4, 0.001)
	p.panel_opacity = 1.0
	hud.apply_prefs(p)
	assert_almost_eq(HudStyle.opacity_of(hud._replica), 1.0, 0.001, "back to solid")
	assert_almost_eq(HudStyle.opacity_of(hud._minimap), 1.0, 0.001)


func test_a_minimap_built_after_the_prefs_takes_the_opacity() -> void:
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
	var p := HudPrefs.new()
	p.panel_opacity = 0.5
	hud.apply_prefs(p)
	var cfg := MinimapConfig.new()
	hud.setup_minimap(map, cfg, MinimapHearing.new(cfg), "Depot", 1)
	assert_almost_eq(HudStyle.opacity_of(hud._minimap), 0.5, 0.001)


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


## QA (attempt 2): a file saved when the slider stopped at 50 % still loads and fades the same two parts.
func test_an_old_save_of_half_opacity_still_loads_and_fades() -> void:
	var p := HudPrefs.new()
	p.from_dict({"panel_opacity": 0.5})
	assert_almost_eq(p.panel_opacity, 0.5, 0.001)
	var hud := _hud()
	hud.apply_prefs(p)
	assert_almost_eq(HudStyle.opacity_of(hud._replica), 0.5, 0.001)
	assert_almost_eq(HudStyle.opacity_of(hud._minimap), 0.5, 0.001)


## Spectating a teammate (the watching label) and the held full map are other HUD parts: they stay solid.
func test_spectating_and_the_full_map_stay_solid() -> void:
	var hud := _hud()
	var p := HudPrefs.new()
	p.panel_opacity = 0.2
	hud.apply_prefs(p)
	hud.set_watching("Dash")
	assert_true(hud._watching.visible, "the label shows")
	assert_almost_eq(hud._watching.modulate.a, 1.0, 0.001)
	assert_almost_eq(hud._bottom.modulate.a, 1.0, 0.001)
	assert_almost_eq(hud.field_map().modulate.a, 1.0, 0.001, "the full map")
	assert_almost_eq(HudStyle.opacity_of(hud._replica), 0.2, 0.001, "the panel keeps the fade while spectating")
	hud.set_watching("")
	assert_almost_eq(HudStyle.opacity_of(hud._minimap), 0.2, 0.001)


## The score summary hides the panel and minimap and the next round shows them: the fade is not lost or doubled.
func test_the_fade_survives_hiding_and_showing_the_parts() -> void:
	var hud := _hud()
	var p := HudPrefs.new()
	p.panel_opacity = 0.6
	hud.apply_prefs(p)
	hud._replica.visible = false
	hud._minimap.visible = false
	hud._replica.visible = true
	hud._minimap.visible = true
	hud.apply_prefs(p)
	assert_almost_eq(HudStyle.opacity_of(hud._replica), 0.6, 0.001)
	assert_almost_eq(HudStyle.opacity_of(hud._minimap), 0.6, 0.001)


## The RELOADING and OUT OF BBS notes are children of the replica panel: their backing fades with it, their words stay
## solid (UF1).
func test_the_status_notes_backing_fades_with_the_replica_panel() -> void:
	var hud := _hud()
	var p := HudPrefs.new()
	p.panel_opacity = 0.4
	hud.apply_prefs(p)
	assert_true(hud._replica._status.get_parent() == hud._replica, "a child of the panel")
	assert_almost_eq(hud._replica._status.modulate.a, 1.0, 0.001, "the words are untouched")
	assert_almost_eq(hud._replica.modulate.a, 1.0, 0.001, "the panel draws its words solid")
	var box := hud._replica._status.get_theme_stylebox("normal") as StyleBoxFlat
	assert_almost_eq(box.bg_color.a, HudStyle.BACKING_PANEL * 0.4, 0.001, "the note's backing fades")
