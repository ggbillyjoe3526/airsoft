extends GutTest
## UI1, the menus after William's second look (0.1 Dev 1): every menu is compact and steady. Pressing a switch or picking a
## choice anywhere moves and resizes nothing, as the mouse does it (hover, press, release, leave: each state draws with
## its own box); no button's words are cut in any of its states; no two controls lie over each other unless one holds the
## other (the For your card tag sits above its preset in its own room).

const ROOT := "user://test-ui1-menus"
## Phases of a click, as the pointer does it.
const PHASES: Array[String] = ["hover", "down", "up", "leave"]
## Slack for a rectangle (px): sub-pixel rounding only.
const SLACK := 0.5
## The least overlap that counts (px of width and height).
const OVERLAP := 1.0

var _n := 0
var s: Settings = null
var screen: SettingsScreen = null


func before_each() -> void:
	_n += 1
	DirAccess.make_dir_recursive_absolute(ROOT)
	s = Settings.new(PlayTuning.new())
	screen = SettingsScreen.new()
	screen.settings = s
	screen.save_path = "%s/settings-%d.save" % [ROOT, _n]
	add_child_autofree(screen)
	screen._graphics_page.renderer_path = "%s/renderer-%d.cfg" % [ROOT, _n]
	screen.open()
	_mouse_to(Vector2(2.0, 2.0))


func after_each() -> void:
	SettingsApply.use_screens(null)
	Engine.max_fps = 0
	InputMap.load_from_project_settings()
	get_tree().paused = false
	_mouse_to(Vector2(2.0, 2.0))


func after_all() -> void:
	for f: String in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(f))
	DirAccess.remove_absolute(ROOT)


# --- The pointer -----------------------------------------------------------------------------------------------------

## `c`'s middle in the window's pixels (the root's stretch applied).
func _centre(c: Control) -> Vector2:
	return get_tree().root.get_final_transform() * (c.get_global_transform_with_canvas() * (c.size * 0.5))


func _mouse_to(at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	get_tree().root.push_input(m)


func _mouse_button(at: Vector2, down: bool) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.position = at
	b.global_position = at
	b.pressed = down
	get_tree().root.push_input(b)


## Does one phase of a click on `target`.
func _phase(target: Control, phase: String) -> void:
	var at := _centre(target)
	match phase:
		"hover":
			_mouse_to(at)
		"down":
			_mouse_button(at, true)
		"up":
			_mouse_button(at, false)
		"leave":
			_mouse_to(Vector2(2.0, 2.0))
	await wait_process_frames(2)


# --- What shows ------------------------------------------------------------------------------------------------------

## Every visible control under `n` that draws by path and its rectangle; `skip` subtrees (a live preview) left out. A
## plain container or holder draws nothing, so only what it holds is compared (a column growing at its foot moves nothing).
func _rects(n: Node, skip: Array[Node], into: Dictionary) -> void:
	if skip.has(n):
		return
	var c := n as Control
	if c != null:
		if not c.is_visible_in_tree():
			return
		var holder := (c is Container and not c is PanelContainer) or (c.get_class() == "Control" and c.get_script() == null)
		if not holder:
			into[c.get_path()] = c.get_global_rect()
	for child in n.get_children():
		_rects(child, skip, into)


## The paths whose rectangle differs between `before` and `after` (both shown).
func _moved(before: Dictionary, after: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for path: NodePath in before:
		if not after.has(path):
			continue
		var a: Rect2 = before[path]
		var b: Rect2 = after[path]
		if absf(a.position.x - b.position.x) > SLACK or absf(a.position.y - b.position.y) > SLACK \
				or absf(a.size.x - b.size.x) > SLACK or absf(a.size.y - b.size.y) > SLACK:
			out.append("%s %s -> %s" % [String(path).get_slice("/", String(path).get_slice_count("/") - 1), a, b])
	return out


## Clicks `target` as the mouse does and fails for anything under `scope` that moves at any phase. Returns how many
## phases moved something.
func _click_moves_nothing(scope: Node, target: Control, skip: Array[Node], what: String) -> int:
	var before := {}
	_rects(scope, skip, before)
	var bad := 0
	for phase in PHASES:
		await _phase(target, phase)
		var after := {}
		_rects(scope, skip, after)
		var moved := _moved(before, after)
		if not moved.is_empty():
			bad += 1
			fail_test("%s, %s: %d moved: %s" % [what, phase, moved.size(), ", ".join(moved.slice(0, 4))])
	return bad


func _all(n: Node, cls: Variant, into: Array) -> void:
	if is_instance_of(n, cls):
		var ci := n as CanvasItem
		if ci == null or ci.is_visible_in_tree():
			into.append(n)
	for child in n.get_children():
		_all(child, cls, into)


func _tabs() -> TabContainer:
	return screen._tabs


# --- 4: a switch or a choice moves nothing ---------------------------------------------------------------------------

func test_clicking_any_settings_switch_or_choice_moves_and_resizes_nothing() -> void:
	var tabs := _tabs()
	var clicked := 0
	for t in tabs.get_tab_count():
		tabs.current_tab = t
		await wait_process_frames(3)
		var page := tabs.get_current_tab_control()
		var skip: Array[Node] = []
		var preview := page.find_child("HudPreview", true, false)
		if preview != null:
			skip.append(preview)
		var switches: Array = []
		_all(page, MenuSwitch, switches)
		for check: MenuSwitch in switches:
			if check.disabled:
				continue
			await _click_moves_nothing(screen, check, skip, "%s on %s" % [check.get_parent().get_child(0).get("text"),
					tabs.get_tab_title(t)])
			await _click_moves_nothing(screen, check, skip, "again")
			clicked += 1
		var choices: Array = []
		_all(page, MenuChoice, choices)
		for choice: MenuChoice in choices:
			var was := choice.selected()
			for i in choice.get_child_count():
				var b := choice.button(i)
				if b.disabled or i == was or not b.is_visible_in_tree():
					continue
				await _click_moves_nothing(screen, b, skip, "%s on %s" % [b.text, tabs.get_tab_title(t)])
				clicked += 1
			if was >= 0 and choice.selected() != was and not choice.button(was).disabled:
				await _click_moves_nothing(screen, choice.button(was), skip, "back to %s" % choice.button(was).text)
	assert_gt(clicked, 50, "every page's switches and choices were clicked")


func test_clicking_the_match_pages_choices_moves_nothing_that_stays() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), s)
	add_child_autofree(menus)
	await wait_process_frames(3)
	var page := menus.match_page()
	var clicked := 0
	# every card and choice: maps, modes, teams, the bots' levels, Skirmish or Custom and Custom's rows
	var picks: Array = []
	var maps: Array = []
	for b: Button in page.find_children("*", "Button", true, false):
		if String(b.name).begins_with("Map_"):
			maps.append(b)
		elif b is MenuCard or b.toggle_mode:
			picks.append(b)
	# the maps last: the Range picks Practice, which fades the rest
	picks.append_array(maps)
	for b: Button in picks:
		var picked := (b as MenuCard).is_picked() if b is MenuCard else b.button_pressed
		if b.disabled or picked or not b.is_visible_in_tree():
			continue
		var words := b.text if b.text != "" else String(b.name)
		await _click_moves_nothing(menus, b, [], "Match: %s" % words)
		clicked += 1
	assert_gt(clicked, 8, "the Match page's cards and choices were clicked")


func test_pressing_customises_loadout_crumb_moves_and_cuts_nothing() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), s)
	add_child_autofree(menus)
	await wait_process_frames(2)
	menus.show_loadout()
	var page := menus.loadout_page()
	page.show_customise()
	await wait_process_frames(3)
	var back := page.find_child("Back", true, false) as Button
	var before := {}
	_rects(menus, [], before)
	for phase: String in ["hover", "down"]:
		await _phase(back, phase)
		var after := {}
		_rects(menus, [], after)
		assert_eq(_moved(before, after), PackedStringArray(), "the crumb row stays put at %s" % phase)
		assert_eq(_cut(back), "", "LOADOUT is whole at %s" % phase)
	_mouse_button(_centre(back), false)
	await wait_process_frames(2)
	menus.leave_loadout()


# --- No words cut ----------------------------------------------------------------------------------------------------

## The styles a button draws its box with, by state (focus is drawn over one of these).
const STATES: Array[StringName] = [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]


## "" when `b`'s words fit inside its box in every state, else what is cut.
func _cut(b: Button) -> String:
	if b.text.strip_edges() == "" or b.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return ""
	var font := b.get_theme_font(&"font")
	var font_size := b.get_theme_font_size(&"font_size")
	var words := b.text
	var line := TextLine.new()
	line.add_string(words, font, font_size)
	var need := line.get_line_width()
	var icon := b.icon if b.icon != null else null
	if icon != null and not b.expand_icon:
		need += icon.get_width() + b.get_theme_constant(&"h_separation")
	for state in STATES:
		var box := b.get_theme_stylebox(state)
		var room := b.size.x - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT)
		if need > room + SLACK:
			return "%s: '%s' needs %.1f px, %s gives %.1f" % [b.get_path(), words, need, state, room]
	return ""


## Fails for every shown button under `scope` whose words are cut in some state.
func _no_words_cut(scope: Node, what: String) -> int:
	var buttons: Array = []
	_all(scope, Button, buttons)
	var bad := 0
	for b: Button in buttons:
		var cut := _cut(b)
		if cut != "":
			bad += 1
			fail_test("%s: %s" % [what, cut])
	return buttons.size()


# --- No overlaps -----------------------------------------------------------------------------------------------------

## The part of `c` that shows: its rectangle cut to every scroll box or clipping control above it.
func _shown(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var p := c.get_parent()
	while p != null:
		var pc := p as Control
		if pc != null and (pc is ScrollContainer or pc.clip_contents):
			r = r.intersection(pc.get_global_rect())
		p = p.get_parent()
	return r


## The controls that draw words or take a click: buttons, labels with words, sliders, fields.
func _solid(n: Node, into: Array[Control]) -> void:
	var c := n as Control
	if c != null:
		if not c.is_visible_in_tree():
			return
		var wordy := (c is Label and (c as Label).text.strip_edges() != "") \
				or (c is RichTextLabel and (c as RichTextLabel).get_parsed_text().strip_edges() != "")
		if c is BaseButton or wordy or c is Range or c is LineEdit or c is TextEdit:
			if c.modulate.a > 0.0 and c.self_modulate.a > 0.0:
				into.append(c)
		if c is ScrollBar:
			return
	for child in n.get_children():
		_solid(child, into)


## Fails for every two shown controls under `scope` that lie over each other when neither holds the other.
func _no_overlaps(scope: Node, what: String) -> int:
	var solid: Array[Control] = []
	_solid(scope, solid)
	var rects: Array[Rect2] = []
	for c in solid:
		rects.append(_shown(c))
	var bad := 0
	for i in solid.size():
		var a := rects[i]
		if a.size.x < OVERLAP or a.size.y < OVERLAP:
			continue
		for j in range(i + 1, solid.size()):
			var b := rects[j]
			var both := a.intersection(b)
			if both.size.x < OVERLAP or both.size.y < OVERLAP:
				continue
			if solid[i].is_ancestor_of(solid[j]) or solid[j].is_ancestor_of(solid[i]):
				continue
			bad += 1
			if bad <= 6:
				fail_test("%s: %s (%s) lies over %s (%s)" % [what, _name(solid[i]), a, _name(solid[j]), b])
	if bad > 6:
		fail_test("%s: %d overlaps in all" % [what, bad])
	return solid.size()


func _name(c: Control) -> String:
	var words := ""
	if c is Label:
		words = (c as Label).text
	elif c is Button:
		words = (c as Button).text
	return "%s '%s'" % [String(c.get_path()).get_slice("/", String(c.get_path()).get_slice_count("/") - 1),
			words.left(24)]


## Fails for every shown control under `scope` that runs past the window's edge (a row too long for its page).
func _inside_window(scope: Node, what: String) -> void:
	var solid: Array[Control] = []
	_solid(scope, solid)
	var window := scope.get_viewport().get_visible_rect().grow(SLACK)
	var bad := 0
	for c in solid:
		var r := _shown(c)
		if r.size.x < OVERLAP or r.size.y < OVERLAP:
			continue
		if not window.encloses(r):
			bad += 1
			if bad <= 4:
				fail_test("%s: %s (%s) runs past the window %s" % [what, _name(c), r, window])


## Fails for every shown label whose words a clipping box (not a scroll box, which scrolls to them) cuts across.
func _no_labels_cut(scope: Node, what: String) -> void:
	var solid: Array[Control] = []
	_solid(scope, solid)
	for c in solid:
		if not c is Label:
			continue
		var whole := c.get_global_rect()
		var r := whole
		var p := c.get_parent()
		while p != null:
			var pc := p as Control
			if pc != null and pc.clip_contents and not pc is ScrollContainer:
				r = r.intersection(pc.get_global_rect())
			p = p.get_parent()
		if r.size.x + SLACK < whole.size.x:
			fail_test("%s: %s is cut to %.1f of %.1f px wide" % [what, _name(c), r.size.x, whole.size.x])


## The checks on one screen.
func _steady(scope: Node, what: String) -> void:
	await wait_process_frames(3)
	var buttons := _no_words_cut(scope, what)
	var solid := _no_overlaps(scope, what)
	_inside_window(scope, what)
	_no_labels_cut(scope, what)
	assert_gt(buttons + solid, 0, "%s has something to check" % what)


func test_every_settings_tab_has_no_cut_words_and_no_overlaps() -> void:
	var tabs := _tabs()
	for t in tabs.get_tab_count():
		tabs.current_tab = t
		await _steady(screen, "Settings › %s" % tabs.get_tab_title(t))


func test_the_for_your_card_tag_sits_above_its_preset_in_its_own_room() -> void:
	screen.show_graphics()
	await wait_process_frames(3)
	var page: SettingsGraphicsPage = screen._graphics_page
	var tag: Control = page._tag
	var button := page.tagged()
	assert_false(button.is_ancestor_of(tag), "the tag is not drawn inside the button")
	var t := tag.get_global_rect()
	var b := button.get_global_rect()
	assert_lte(t.end.y, b.position.y + SLACK, "the tag ends above the button")
	assert_almost_eq(t.get_center().x, b.get_center().x, 1.0, "centred over its preset")


func test_the_menu_pages_have_no_cut_words_and_no_overlaps() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), s)
	add_child_autofree(menus)
	await _steady(menus, "Match")
	var rules := menus.match_page().rules_box()
	rules.rules_button(MatchOptions.RULES_CUSTOM).pressed.emit()
	await _steady(menus, "Match, Custom rules")
	rules.rules_button(MatchOptions.RULES_SKIRMISH).pressed.emit()
	menus.match_page().map_card("range").pressed.emit()
	await _steady(menus, "Match, the Range")
	menus.show_loadout()
	await _steady(menus, "Loadout")
	var page := menus.loadout_page()
	page.show_customise()
	await _steady(menus, "Customise")
	var view := page.find_children("*", "CustomiseView", true, false)[0] as CustomiseView
	for tab: int in CustomiseView.Tab.values():
		view.show_tab(tab)
		await _steady(menus, "Customise › %s" % CustomiseView.Tab.keys()[tab])
	menus.leave_loadout()
	menus.show_armory()
	await _steady(menus, "Armory")


func test_the_menus_notice_the_quit_prompt_and_the_credits_have_no_cut_words_and_no_overlaps() -> void:
	var menus := MenuScreen.new()
	add_child_autofree(menus)
	menus.show_notice(GraphicsNotice.first_start(&"low", "Radeon RX 6600 · Discrete", "1920 × 1080 · 60 Hz"))
	await _steady(menus.notice(), "First start notice")
	menus.close_notice()
	var prompt := QuitPrompt.new()
	add_child_autofree(prompt)
	await _steady(prompt, "QUIT GAME?")
	prompt.close()
	var credits := Credits.new()
	add_child_autofree(credits)
	credits.open()
	await _steady(credits, "Credits")
	credits.close()


func test_the_pause_menus_and_the_report_panel_have_no_cut_words_and_no_overlaps() -> void:
	var pause := PauseMenu.new()
	add_child_autofree(pause)
	await wait_process_frames(2)
	pause.set_match("Woodland", "Attack / Defend", 12, 482113)
	pause.set_can_skip(true)
	pause.open()
	await _steady(pause, "Pause, match")
	pause.close()
	pause.set_practice("Range", true, 14)
	pause.open()
	await _steady(pause, "Pause, practice")
	pause.close()
	get_tree().paused = false
	var panel := ReportPanel.new()
	add_child_autofree(panel)
	var info := BugReport.ReportInfo.new()
	info.version = "0.1 Dev 1"
	info.godot = "4.7.2.stable.official"
	info.language = "en"
	info.seed_text = "48213"
	info.match_text = "Depot · Elimination · Standard rules · 3v3 · Normal"
	info.screen = "menus"
	info.dev_settings = "none"
	info.settings_changed = "none"
	info.note_chars = panel.config.note_chars
	info.scrub = ReportScrub.for_this_machine(panel.config)
	panel.open(info)
	await _steady(panel, "Report a bug")
	panel.close()


# --- Fix round 1 -----------------------------------------------------------------------------------------------------

## Every shown label's words under `scope`.
func _words_on_show(scope: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for l: Node in scope.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree() and (l as Label).text != "":
			out.append((l as Label).text)
	return out


func test_graphics_and_display_keep_no_prose_beside_their_rows_and_say_it_in_tooltips() -> void:
	screen.show_graphics()
	await wait_process_frames(3)
	var page: SettingsGraphicsPage = screen._graphics_page
	var words := " | ".join(_words_on_show(page))
	for gone: String in ["every row as the preset sets it", "Squares", "Draws", "From the next start"]:
		assert_false(words.contains(gone), "no \"%s\" on the Graphics tab" % gone)
	assert_true(words.contains(tr("GRAPHICS_RENDERER_NEXT_START")), "the renderer's short restart note stays")
	assert_eq(tr("GRAPHICS_RENDERER_NEXT_START"), "Applies on restart")
	var scale := page.line(GraphicsQuality.RENDER_SCALE)
	assert_string_starts_with(scale.slider.tooltip_text, "Draws ", "the size it draws at is the slider's tooltip")
	var squares := page.find_children("*", "Control", true, false).filter(
			func(n: Node) -> bool: return n is SettingsGraphicsPage.CostSquares)
	assert_gt(squares.size(), 0)
	for sq: Control in squares:
		assert_eq(sq.tooltip_text, tr("GRAPHICS_COST_TIP"), "the squares explain themselves")
	var display: SettingsDisplayPage = screen._display_page
	var shown := " | ".join(_words_on_show(display))
	assert_false(shown.contains(tr("SETTINGS_KEYS_LINE")), "no F11 hint line on Display")
	var window_row := display.find_children("*", "MenuChoice", true, false)[0] as MenuChoice
	assert_eq(window_row.button(0).tooltip_text, display.keys_tip(), "the keys are the window mode's tooltip")
	assert_string_contains(display.keys_tip(), "Alt+")


func test_dragging_the_bb_weight_keeps_the_performance_panel_one_size_even_as_it_caps() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), s)
	add_child_autofree(menus)
	await wait_process_frames(2)
	menus.show_loadout()
	var page := menus.loadout_page()
	page.save_path = "%s/loadouts-%d.save" % [ROOT, _n]
	var saved := page.strip().saved
	var before := saved.to_dict()
	# a low site limit: the CAPPED tag shows too
	saved.rules.stats.site_limits[&"rifle"] = 0.5
	page.show_customise(0)
	var view := page.customise()
	view.show_tab(CustomiseView.Tab.BBS)
	await wait_process_frames(4)
	var sheet := view.sheet()
	var slider := view.weight_slider()
	var size := sheet.size
	var bar := (sheet.value_label(&"speed").get_parent().get_parent() as Control).get_child(1) as Control
	var bar_width := bar.size.x
	var g := slider.min_value
	while g <= slider.max_value + 1e-6:
		slider.value = g
		await wait_process_frames(2)
		assert_eq(sheet.size, size, "%.2f g: the panel keeps its size" % g)
		assert_eq(bar.size.x, bar_width, "%.2f g: the bars keep their width" % g)
		g += slider.step
	assert_true(sheet.capped_tag().visible, "capped all along")
	saved.from_dict(before)
	saved.dirty = false


func test_the_save_folder_s_path_is_shown_whole_however_long() -> void:
	var tabs := _tabs()
	tabs.current_tab = screen._save_tab.get_parent().get_index()
	await wait_process_frames(3)
	var page := screen.save_page()
	assert_not_null(page)
	page.folder = "/home/a-player-with-a-long-name/.local/share/godot/app_userdata/Airsoft/and/deeper/still/folder"
	page.refresh()
	await wait_process_frames(3)
	var path := page.folder_path()
	assert_eq(path.text, page.folder)
	assert_false(path.clip_text, "not clipped")
	assert_eq(path.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "no ellipsis")
	assert_eq(path.get_visible_line_count(), path.get_line_count(), "every line of it shows")
	assert_lte(path.get_global_rect().end.x, path.get_parent_control().get_global_rect().end.x + SLACK)


func test_the_fps_figure_sits_under_the_hud_s_corner_panel_at_every_hud_size() -> void:
	var readout := FpsReadout.new(s)
	add_child_autofree(readout)
	s.show_fps = true
	s.changed.emit()
	await wait_process_frames(3)
	var label := readout.find_children("*", "Label", true, false)[0] as Label
	var window := get_viewport().get_visible_rect()
	var r := label.get_global_rect()
	assert_almost_eq(r.end.x, window.end.x - FpsReadout.MARGIN, 1.0, "in the right corner")
	assert_almost_eq(r.end.y, window.end.y - FpsReadout.MARGIN, 1.0, "at the bottom")
	# the replica panel keeps Hud.MARGIN, scaled by the HUD size, from the bottom; the top bar's chip is far above
	var panel_foot := window.end.y - Hud.MARGIN * AccessibilityConfig.HUD_SIZE_RANGE.x
	assert_gt(r.position.y, panel_foot, "under the replica panel at the smallest HUD size")
	assert_string_starts_with(label.text, "FPS")


# --- Fix round 3: the prose the critic found ------------------------------------------------------------------------

func test_each_graphics_column_heads_its_squares_with_gpu_cost() -> void:
	screen.show_graphics()
	await wait_process_frames(3)
	var page: SettingsGraphicsPage = screen._graphics_page
	var heads := page.find_children("GpuCost", "Label", true, false)
	assert_eq(heads.size(), 2, "one over each column's squares")
	var squares := page.find_children("*", "Control", true, false).filter(
			func(n: Node) -> bool: return n is SettingsGraphicsPage.CostSquares)
	for head: Label in heads:
		assert_eq(head.text, "GPU COST")
		assert_ne(head.tooltip_text, "", "the longer words are its tooltip")
		var under := squares.filter(func(q: Control) -> bool:
			return absf(q.get_global_rect().end.x - head.get_global_rect().end.x) < 1.0)
		assert_gt(under.size(), 0, "squares end where their heading ends")


func test_the_bbs_page_keeps_one_short_line_and_a_glow_pick_moves_or_rewrites_nothing() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), s)
	add_child_autofree(menus)
	await wait_process_frames(2)
	menus.show_loadout()
	var page := menus.loadout_page()
	page.save_path = "%s/loadouts-%d.save" % [ROOT, _n]
	var saved := page.strip().saved
	var before_save := saved.to_dict()
	page.show_customise(0)
	var view := page.customise()
	view.show_tab(CustomiseView.Tab.BBS)
	await wait_process_frames(4)
	var bbs := view.find_child("BbsPage", true, false)
	var words := " | ".join(_words_on_show(bbs))
	for gone: String in [tr("CUSTOMISE_WEIGHT_BLURB"), tr("CUSTOMISE_HOP_BLURB"), tr("CUSTOMISE_GLOW_NIGHT_BLURB")]:
		assert_false(words.contains(gone), "no paragraph: %s" % gone.left(30))
	assert_true(words.contains("Turn it in a match with 4 and 5."), "the one short line stays")
	assert_eq(view.weight_slider().tooltip_text, tr("CUSTOMISE_WEIGHT_BLURB"))
	var rects := {}
	_rects(bbs, [], rects)
	var shown := _words_on_show(bbs)
	view.glow_choice().button(Loadout.Glow.OFF).pressed.emit()
	await wait_process_frames(3)
	var after := {}
	_rects(bbs, [], after)
	assert_eq(_moved(rects, after), PackedStringArray(), "a glow pick moves nothing")
	assert_eq(_words_on_show(bbs), shown, "and rewrites no words on the page")
	assert_eq(view.glow_choice().button(0).tooltip_text, tr("CUSTOMISE_GLOW_OFF_BLURB"), "its words are the tooltip")
	saved.from_dict(before_save)
	saved.dirty = false


func test_the_order_wheel_the_armory_and_dev_say_their_longer_words_in_tooltips() -> void:
	var controls := _tabs().get_child(0)
	assert_false(" | ".join(_words_on_show(controls)).contains(tr("SETTINGS_ORDERS_HELP")), "no wheel paragraph")
	var wheel := screen._wheel_pick
	assert_eq(wheel.button(0).tooltip_text, tr("SETTINGS_ORDERS_HELP"), "the wheel's choice explains Hover and Click")
	var tabs := _tabs()
	tabs.current_tab = screen._dev_page.get_parent().get_index()
	await wait_process_frames(3)
	var dev_words := _words_on_show(screen._dev_page)
	assert_true(dev_words.has(tr("DEV_RECORDS_LINE")), "one records line")
	for w: String in dev_words:
		assert_false(w.contains(tr("DEV_INTRO")) or w.contains(tr("DEV_GHOST_HELP")) or w.contains(tr("DEV_CRASH_HELP")),
				"no sentence beside a Dev row: %s" % w.left(30))
	var menus := MenuScreen.new(MatchPicks.new(), s)
	add_child_autofree(menus)
	await wait_process_frames(2)
	menus.show_armory()
	await wait_process_frames(3)
	var armory_words := " | ".join(_words_on_show(menus))
	assert_false(armory_words.contains("Then times the difficulty"), "no XP paragraph on the Armory")
	assert_true(armory_words.contains("Easy ×0.5 · Normal ×1 · Hard ×1.5"), "the multipliers in one row")
