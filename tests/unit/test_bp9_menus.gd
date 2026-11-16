extends GutTest
## BP9, the menus, the HUD and the saves: the interface colour reaches the switches' focus ring and a button's press
## ring made before it changed; picking a colour from the settings opened over the Loadout or the Armory comes back to
## that page; Spotted's arrow follows its figure between ticks; and graphics the safe start put by before Volumetric
## haze had levels come back with their Custom "on" as High.

const ROOT := "user://test-bp9"
const MAIN := preload("res://game/main.tscn")
const FOG := GraphicsQuality.VOLUMETRIC_FOG

var _colour_before: UiColours.Pick = UiColours.DEFAULT
var _shared_before: Dictionary = {}


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	_shared_before = Settings.shared().to_dict()
	_colour_before = Settings.shared().ui_colour
	GameTheme.use_colour(UiColours.Pick.BLUE)


func after_each() -> void:
	var s := Settings.shared()
	s.from_dict(_shared_before)
	s.dirty = false
	GameTheme.use_colour(_colour_before)
	for f: String in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(f))


func after_all() -> void:
	DirAccess.remove_absolute(ROOT)


# --- the interface colour ---

func test_a_switchs_focus_ring_is_drawn_in_the_colour_picked_since_it_was_made() -> void:
	var first := MenuSwitch.new("On", "Off")
	add_child_autofree(first)
	first.grab_focus()
	await wait_process_frames(2)
	assert_eq(MenuSwitch._ring.border_color, UiColours.ACCENTS[UiColours.Pick.BLUE])
	GameTheme.use_colour(UiColours.Pick.GREEN)
	# The menus are built again after a change: a new switch draws with the one ring every switch shares.
	var second := MenuSwitch.new("On", "Off")
	add_child_autofree(second)
	second.grab_focus()
	await wait_process_frames(2)
	assert_eq(MenuSwitch._ring.border_color, UiColours.ACCENTS[UiColours.Pick.GREEN], "the ring in the new colour")


func test_a_press_ring_made_before_a_colour_change_lights_in_the_new_colour() -> void:
	var button := Button.new()
	button.size = Vector2(120.0, 40.0)
	add_child_autofree(button)
	var ring := ButtonPress.new()
	button.add_child(ring, false, Node.INTERNAL_MODE_BACK)
	ring.play(true)
	assert_eq(ring._box.border_color, UiColours.ACCENTS[UiColours.Pick.BLUE])
	GameTheme.use_colour(UiColours.Pick.RED)
	ring.play(true)
	assert_eq(ring._box.border_color, UiColours.ACCENTS[UiColours.Pick.RED], "the same button, pressed after the change")


func test_a_colour_picked_in_settings_opened_over_the_loadout_or_the_armory_comes_back_to_that_page() -> void:
	for tab: NavRail.Tab in [NavRail.Tab.LOADOUT, NavRail.Tab.ARMORY, NavRail.Tab.MATCH]:
		var main: Node = MAIN.instantiate()
		add_child_autofree(main)
		await wait_process_frames(2)
		main._on_tab(tab)
		await wait_process_frames(2)
		assert_eq(main._menus.page_tab(), tab)
		main._on_tab(NavRail.Tab.SETTINGS)
		await wait_process_frames(2)
		var before: Node = main._menus
		GameTheme.use_colour(UiColours.Pick.ORANGE if GameTheme.accent != UiColours.ACCENTS[UiColours.Pick.ORANGE]
				else UiColours.Pick.GREEN)
		main.restyle()
		await wait_process_frames(3)
		assert_ne(main._menus, before, "the menus were built again in the colour")
		assert_not_null(main._settings_screen, "the settings are open again over them")
		assert_eq(main._menus.page_tab(), tab, "the page the settings were opened over is under them (tab %d)" % tab)
		main._settings_screen.close()
		await wait_process_frames(3)
		assert_eq(main._menus.page_tab(), tab, "and BACK returns to it")
		assert_eq(main._menus.nav_rail().current(), tab, "the rail lit on it")
		main.queue_free()
		await wait_process_frames(2)


# --- Spotted's arrow ---

func test_spotteds_arrow_follows_its_figure_between_ticks() -> void:
	var tuning := SimTuning.load_default()
	var hud_cfg := HudConfig.new()
	var you := Character.new(0, 0, Vector3(-30.0, 0.0, 20.0), 0.0, ReplicaStats.default_loadout())
	var enemy := Character.new(1, 1, Vector3(-10.0, 0.0, 21.0), 0.0, ReplicaStats.default_loadout())
	enemy.prev_position = Vector3(-10.0, 0.0, 19.0)
	var characters: Array[Character] = [you, enemy]
	var spots := Spots.new(characters, PingConfig.new())
	spots._until[enemy.id] = 10.0
	spots._by[enemy.id] = you.team
	var arrows := HudSpotArrows.new()
	add_child_autofree(arrows)
	arrows.setup(hud_cfg, tuning, characters, you)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.look_at_from_position(Vector3(-30.0, 1.6, 20.0), Vector3(-10.0, 1.6, 20.0))
	var area := get_viewport().get_visible_rect().size
	var over := Lean.eye(enemy, tuning.body, tuning.hits) + Vector3.UP * hud_cfg.spot_arrow_lift
	var seen: Array[float] = []
	for fraction: float in [0.0, 0.5, 1.0]:
		arrows.place(camera, spots, 1.0, true, area, fraction)
		assert_eq(arrows.count(), 1)
		var shift := enemy.prev_position.lerp(enemy.position, fraction) - enemy.position
		var want := camera.unproject_position(over + shift)
		assert_almost_eq(arrows.tip(0).x, want.x, 0.5, "the tip over the head as it is drawn, %.1f through the tick" % fraction)
		assert_almost_eq(arrows.tip(0).y, want.y, 0.5)
		seen.append(arrows.tip(0).x)
	assert_gt(absf(seen[2] - seen[0]), 20.0, "it moved with them across the tick (2 m at 20 m)")
	assert_almost_eq(seen[1], (seen[0] + seen[2]) * 0.5, 3.0, "half way at half a tick")


# --- the safe start's graphics, put by on an older build ---

func test_try_my_settings_again_brings_an_old_custom_haze_on_back_as_high() -> void:
	var s := Settings.new(PlayTuning.new())
	s.choose_graphics(GraphicsQuality.CUSTOM, &"medium")
	var g := GraphicsGuard.new()
	# As a build before the haze had levels wrote it, the safe start waiting on the title for an answer.
	g.from_dict({"state": "starting", "previous": {"graphics_choice": "custom", "graphics_base": "medium",
			"graphics_custom": {"volumetric_fog": "on", "glow": "off"}, "renderer": int(Settings.Renderer.AUTO)},
			"renderer_notice": ""})
	assert_true(g.asking(), "graphics wait to be tried again")
	g.try_again(s)
	assert_eq(s.graphics_choice, GraphicsQuality.CUSTOM)
	assert_eq(s.graphics_custom.get(FOG), GraphicsQuality.CHOICES[FOG][GraphicsQuality.VolumetricFog.HIGH],
			"the haze it drew, by its name now")
	assert_eq(s.graphics_custom.get("glow"), "off", "the other rows as they were")
	var table := GraphicsTable.read_file()
	var q := GraphicsQuality.resolve(s.graphics_choice, s.graphics_base, s.graphics_custom, table)
	assert_eq(q.volumetric_fog, GraphicsQuality.VolumetricFog.HIGH)


func test_custom_rows_now_leaves_todays_tables_and_odd_values_alone() -> void:
	for level: String in ["off", "low", "medium", "high"]:
		var custom := {"volumetric_fog": level, "glow": "on"}
		Settings.custom_rows_now(custom)
		assert_eq(custom, {"volumetric_fog": level, "glow": "on"}, level)
	for odd: Variant in [null, 3, "on", [], {"volumetric_fog": 1}, {"glow": "on"}]:
		var before: Variant = odd.duplicate(true) if odd is Dictionary or odd is Array else odd
		Settings.custom_rows_now(odd)
		assert_eq(odd, before, "left as it was: %s" % str(odd))
