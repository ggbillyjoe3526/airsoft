extends GutTest
## UI1 QA: what test_ui1_menus.gd does not reach. Every button of every menu screen is driven with real pointer events
## in the states the first set skips (the button held down and the pointer dragged off it, then let go elsewhere) and by
## keyboard focus and Enter; the choices that replaced switches (Crouch, Aim, Order wheel, Window mode, the frame-rate
## limit) save the same values as before when clicked with the mouse; and a detector self-check, so these tests are
## known to see a control that grows or moves when it is touched.

const ROOT := "user://test-ui1-qa"
## Slack for a rectangle (px): sub-pixel rounding only.
const SLACK := 0.5
## Where the pointer rests: in the window's corner, over nothing.
const PARKED := Vector2(3.0, 3.0)

var _n := 0
var s: Settings = null
var screen: SettingsScreen = null
var _held := false
var _window_was := Vector2i.ZERO
## The runner's own nodes (taken before the test adds any) and the pointer filters they had.
var _runner: Array[Node] = []
var _filters := {}


func before_each() -> void:
	_n += 1
	# a window the size of the layout, so one pixel is one layout pixel and a pointer lands where it is aimed
	_window_was = get_tree().root.size
	get_tree().root.size = Vector2i(1920, 1080)
	# the runner's own boxes lie over the window and take the pointer; let it through
	_runner.clear()
	_runner.append_array(get_tree().root.get_children())
	_filters.clear()
	_let_pointer_through()
	DirAccess.make_dir_recursive_absolute(ROOT)
	s = Settings.new(PlayTuning.new())
	screen = SettingsScreen.new()
	screen.settings = s
	screen.save_path = "%s/settings-%d.save" % [ROOT, _n]
	add_child_autofree(screen)
	screen._graphics_page.renderer_path = "%s/renderer-%d.cfg" % [ROOT, _n]
	screen.open()
	_held = false
	_motion(PARKED)


func after_each() -> void:
	SettingsApply.use_screens(null)
	Engine.max_fps = 0
	InputMap.load_from_project_settings()
	get_tree().paused = false
	_held = false
	_motion(PARKED)
	get_tree().root.size = _window_was
	for c: Control in _filters:
		if is_instance_valid(c):
			c.mouse_filter = _filters[c]
	_filters.clear()


func after_all() -> void:
	for f: String in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(f))
	DirAccess.remove_absolute(ROOT)


# --- The pointer and the keyboard ------------------------------------------------------------------------------------

## Every Control of the runner's (its output boxes and bars) stops taking the pointer, whenever it was made.
func _let_pointer_through() -> void:
	for r: Node in _runner:
		if not is_instance_valid(r):
			continue
		var all: Array[Node] = [r]
		all.append_array(r.find_children("*", "Control", true, false))
		for node: Node in all:
			var c := node as Control
			if c != null and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and not is_ancestor_of(c):
				if not _filters.has(c):
					_filters[c] = c.mouse_filter
				c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _centre(c: Control) -> Vector2:
	return get_tree().root.get_final_transform() * (c.get_global_transform_with_canvas() * (c.size * 0.5))


func _motion(at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	# a pointer dragging with the button down reports it, as the system's does
	if _held:
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_tree().root.push_input(m)


func _button(at: Vector2, down: bool) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.position = at
	b.global_position = at
	b.pressed = down
	_held = down
	if down:
		b.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_tree().root.push_input(b)


func _key(code: Key, down: bool) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.pressed = down
	get_tree().root.push_input(k)


## A whole click on `c` as the mouse does it: over, down, up, away.
func _click(c: Control) -> void:
	var at := _centre(c)
	_motion(at)
	await wait_process_frames(2)
	_button(at, true)
	await wait_process_frames(2)
	_button(at, false)
	await wait_process_frames(2)
	_motion(PARKED)
	await wait_process_frames(2)


# --- What shows ------------------------------------------------------------------------------------------------------

## Every shown control under `n` with its rectangle and its words, skipping the subtrees in `skip`.
func _snap(n: Node, skip: Array[Node], into: Dictionary) -> void:
	if skip.has(n):
		return
	var ci := n as CanvasItem
	if ci != null and not ci.visible:
		return
	var c := n as Control
	if c != null:
		var words := ""
		if c is Button:
			words = (c as Button).text
		elif c is Label:
			words = (c as Label).text
		var r := c.get_global_rect()
		# a scroll box that follows the keyboard's focus carries its contents with it: that is not a move
		var up := c.get_parent()
		while up != null:
			var sc := up as ScrollContainer
			if sc != null:
				r.position += Vector2(sc.scroll_horizontal, sc.scroll_vertical)
			up = up.get_parent()
		into[c.get_path()] = [r, words]
	for child in n.get_children():
		_snap(child, skip, into)


## What differs between two snapshots, as lines (a moved or resized box, changed words).
func _changes(before: Dictionary, after: Dictionary, words_too: bool = true) -> PackedStringArray:
	var out := PackedStringArray()
	for path: NodePath in before:
		if not after.has(path):
			continue
		var a: Rect2 = before[path][0]
		var b: Rect2 = after[path][0]
		var name := String(path).get_slice("/", String(path).get_slice_count("/") - 1)
		if absf(a.position.x - b.position.x) > SLACK or absf(a.position.y - b.position.y) > SLACK \
				or absf(a.size.x - b.size.x) > SLACK or absf(a.size.y - b.size.y) > SLACK:
			out.append("%s %s -> %s" % [name, a, b])
		elif words_too and before[path][1] != after[path][1]:
			out.append("%s words '%s' -> '%s'" % [name, before[path][1], after[path][1]])
	return out


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


## The buttons shown and enabled under `n` whose middle is in view (one scrolled out of its box cannot be pointed at).
## The key list's are left out: pressing one starts waiting for a key and takes every pointer event until a key comes
## (see the key list's own test below).
func _buttons(n: Node, into: Array[BaseButton]) -> void:
	var ci := n as CanvasItem
	if ci != null and not ci.visible:
		return
	if n is KeyBindingList:
		return
	# one with its pointer filter off (the switch drawn inside a toggle row) is only a picture: the row takes the pointer
	if n is BaseButton and (n as BaseButton).size.x > 4.0 and not (n as BaseButton).disabled \
			and (n as BaseButton).mouse_filter != Control.MOUSE_FILTER_IGNORE \
			and _shown(n as Control).has_point((n as Control).get_global_rect().get_center()):
		into.append(n as BaseButton)
	for child in n.get_children():
		_buttons(child, into)


## "" when `b`'s words fit in its box in the state it is in now, else what is cut.
func _cut(b: Button) -> String:
	if b.text.strip_edges() == "" or b.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return ""
	var line := TextLine.new()
	line.add_string(b.text, b.get_theme_font(&"font"), b.get_theme_font_size(&"font_size"))
	var need := line.get_line_width()
	if b.icon != null and not b.expand_icon:
		need += b.icon.get_width() + b.get_theme_constant(&"h_separation")
	var box: StyleBox
	match b.get_draw_mode():
		BaseButton.DRAW_PRESSED:
			box = b.get_theme_stylebox(&"pressed")
		BaseButton.DRAW_HOVER:
			box = b.get_theme_stylebox(&"hover")
		BaseButton.DRAW_HOVER_PRESSED:
			box = b.get_theme_stylebox(&"hover_pressed")
		BaseButton.DRAW_DISABLED:
			box = b.get_theme_stylebox(&"disabled")
		_:
			box = b.get_theme_stylebox(&"normal")
	var room := b.size.x - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT)
	if need > room + SLACK:
		return "'%s' needs %.1f px, its box leaves %.1f (draw mode %d)" % [b.text, need, room, b.get_draw_mode()]
	return ""


# --- The hammer ------------------------------------------------------------------------------------------------------

## Touches every button under `scope` in the ways that do not press it for real: the pointer over it; the button held
## down; the pointer dragged off it with the button still down; the button let go off it (no press). Nothing under
## `scope` may move, change size or change words in any of them, and no button's words may be cut in the state it is
## in. Returns how many buttons were touched.
func _hammer(scope: Node, what: String, skip: Array[Node] = []) -> int:
	var list: Array[BaseButton] = []
	_buttons(scope, list)
	var rest := {}
	_snap(scope, skip, rest)
	var touched := 0
	for b: BaseButton in list:
		if not is_instance_valid(b) or not b.is_visible_in_tree():
			continue
		_let_pointer_through()
		var at := _centre(b)
		var label := "%s › %s" % [what, String(b.name) if not b is Button or (b as Button).text == "" else (b as Button).text]
		touched += 1
		_motion(at)
		await wait_process_frames(2)
		if not b.is_hovered():
			fail_test("%s: the pointer over its middle does not reach it (it reaches %s)" % [label,
					get_tree().root.gui_get_hovered_control()])
		var hover_cut := _cut(b) if b is Button else ""
		var after_hover := {}
		_snap(scope, skip, after_hover)
		_button(at, true)
		await wait_process_frames(2)
		var press_cut := _cut(b) if b is Button else ""
		var after_down := {}
		_snap(scope, skip, after_down)
		_motion(PARKED)
		await wait_process_frames(2)
		var after_drag := {}
		_snap(scope, skip, after_drag)
		_button(PARKED, false)
		await wait_process_frames(2)
		var after_up := {}
		_snap(scope, skip, after_up)
		var phases := {"hover": after_hover, "held down": after_down, "dragged off": after_drag, "let go off it": after_up}
		for phase: String in phases:
			var moved := _changes(rest, phases[phase])
			if not moved.is_empty():
				fail_test("%s, %s: %d changed: %s" % [label, phase, moved.size(), ", ".join(moved.slice(0, 3))])
		for cut: String in [hover_cut, press_cut]:
			if cut != "":
				fail_test("%s: %s" % [label, cut])
		_motion(PARKED)
		await wait_process_frames(2)
	return touched


## Focuses every control under `scope` that takes focus, one after the other (the keyboard's Tab does the same), and
## fails for any that moves or resizes another or cuts words. Returns how many were focused.
func _focus_all(scope: Node, what: String, skip: Array[Node] = []) -> int:
	var rest := {}
	_snap(scope, skip, rest)
	var n := 0
	var all: Array[Node] = []
	all.append_array(scope.find_children("*", "Control", true, false))
	for node: Node in all:
		var c := node as Control
		if c == null or c.focus_mode == Control.FOCUS_NONE or c.focus_mode == Control.FOCUS_ACCESSIBILITY \
				or not c.is_visible_in_tree() or c.size.x < 4.0:
			continue
		c.grab_focus()
		await wait_process_frames(2)
		n += 1
		var now := {}
		_snap(scope, skip, now)
		var moved := _changes(rest, now)
		if not moved.is_empty():
			fail_test("%s: focusing %s changes %d: %s" % [what, c.name, moved.size(), ", ".join(moved.slice(0, 3))])
		if c is Button and _cut(c as Button) != "":
			fail_test("%s: focused %s: %s" % [what, c.name, _cut(c as Button)])
	return n


func _settings_skip(page: Node) -> Array[Node]:
	var skip: Array[Node] = []
	var preview := page.find_child("HudPreview", true, false)
	if preview != null:
		skip.append(preview)
	return skip


# --- Settings: every tab, every button, in the states the first set skips --------------------------------------------

func test_no_settings_button_moves_or_cuts_anything_when_held_dragged_off_or_let_go_elsewhere() -> void:
	var touched := 0
	for t in screen._tabs.get_tab_count():
		screen._tabs.current_tab = t
		await wait_process_frames(2)
		var page := screen._tabs.get_current_tab_control()
		touched += await _hammer(page, "Settings › %s" % screen._tabs.get_tab_title(t), _settings_skip(page))
	assert_gt(touched, 100, "the buttons of all eight tabs were touched")


func test_focusing_any_settings_control_by_keyboard_moves_nothing() -> void:
	var focused := 0
	for t in screen._tabs.get_tab_count():
		screen._tabs.current_tab = t
		await wait_process_frames(2)
		var page := screen._tabs.get_current_tab_control()
		focused += await _focus_all(page, "Settings › %s" % screen._tabs.get_tab_title(t), _settings_skip(page))
	assert_gt(focused, 100, "focus went to the controls of all eight tabs")


func test_enter_on_a_focused_switch_or_choice_moves_nothing() -> void:
	var pressed := 0
	for t in screen._tabs.get_tab_count():
		screen._tabs.current_tab = t
		await wait_process_frames(2)
		var page := screen._tabs.get_current_tab_control()
		var skip := _settings_skip(page)
		var list: Array[BaseButton] = []
		_buttons(page, list)
		for b: BaseButton in list:
			if not (b is MenuSwitch or (b.toggle_mode and b.get_parent() is MenuChoice)):
				continue
			var rest := {}
			_snap(screen, skip, rest)
			b.grab_focus()
			await wait_process_frames(2)
			_key(KEY_ENTER, true)
			await wait_process_frames(2)
			_key(KEY_ENTER, false)
			await wait_process_frames(2)
			var after := {}
			_snap(screen, skip, after)
			# pressing a preset or choice sets other settings, so other labels may read new values; no box may move
			var moved := _changes(rest, after, false)
			pressed += 1
			if not moved.is_empty():
				fail_test("Settings › %s: Enter on %s changes %d: %s" % [screen._tabs.get_tab_title(t), b.name, moved.size(),
						", ".join(moved.slice(0, 3))])
	assert_gt(pressed, 40, "Enter was sent to the switches and choices of every tab")


func test_pressing_a_key_binding_waits_for_a_key_and_moves_nothing_then_cancels_whole() -> void:
	screen._tabs.current_tab = 0
	await wait_process_frames(2)
	var keys: KeyBindingList = screen._keys
	var list: Array[Button] = []
	for b: Node in keys.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree() and _shown(b as Button).has_point((b as Button).get_global_rect().get_center()):
			list.append(b as Button)
	assert_gt(list.size(), 10, "the visible key buttons")
	var rest := {}
	_snap(screen, [], rest)
	for b: Button in list.slice(0, 12):
		var was := b.text
		var at := _centre(b)
		_motion(at)
		await wait_process_frames(2)
		_button(at, true)
		await wait_process_frames(2)
		_button(at, false)
		await wait_process_frames(2)
		assert_true(keys.capturing(), "pressing %s waits for a key" % was)
		var now := {}
		_snap(screen, [], now)
		for line in _changes(rest, now):
			if not line.contains("words"):
				fail_test("waiting for a key at %s changes: %s" % [was, line])
		assert_eq(_cut(b), "", "the waiting words fit %s's box" % was)
		keys.cancel()
		_motion(PARKED)
		await wait_process_frames(2)
		var after := {}
		_snap(screen, [], after)
		assert_eq(_changes(rest, after), PackedStringArray(), "cancelled, %s is as it was" % was)


# --- The other screens -----------------------------------------------------------------------------------------------

func test_no_button_on_the_rail_the_notices_the_quit_prompt_the_credits_or_the_report_moves_anything() -> void:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.theme = GameTheme.get_theme()
	add_child_autofree(holder)
	var menus := MenuScreen.new()
	holder.add_child(menus)
	await wait_process_frames(3)
	var touched := await _hammer(menus.nav_rail(), "Rail")
	for notice: GraphicsNotice in [
			GraphicsNotice.first_start(&"low", "Radeon RX 6600 · Discrete", "1920 × 1080 · 60 Hz"),
			GraphicsNotice.safe_start("Forward+", "Compatibility"),
			GraphicsNotice.simpler_renderer("it crashed while starting", "Radeon RX 6600 · Discrete", "Compatibility")]:
		menus.show_notice(notice)
		await wait_process_frames(3)
		touched += await _hammer(notice, "Notice")
		menus.close_notice()
	var prompt := QuitPrompt.new()
	holder.add_child(prompt)
	await wait_process_frames(3)
	touched += await _hammer(prompt, "QUIT GAME?")
	prompt.close()
	var credits := Credits.new()
	holder.add_child(credits)
	credits.open()
	await wait_process_frames(3)
	touched += await _hammer(credits, "Credits")
	credits.close()
	assert_gt(touched, 8, "the buttons of the rail and the overlays were touched")


func test_no_pause_menu_button_moves_anything_when_held_dragged_off_or_let_go_elsewhere() -> void:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.theme = GameTheme.get_theme()
	add_child_autofree(holder)
	var pause := PauseMenu.new()
	holder.add_child(pause)
	await wait_process_frames(2)
	pause.set_match("Woodland", "Attack / Defend", 12, 482113)
	pause.set_can_skip(true)
	pause.open()
	await wait_process_frames(3)
	var touched := await _hammer(pause, "Pause, match")
	pause.close()
	pause.set_practice("Range", true, 14)
	pause.open()
	await wait_process_frames(3)
	touched += await _hammer(pause, "Pause, practice")
	pause.close()
	get_tree().paused = false
	assert_gt(touched, 5, "the pause menus' buttons were touched")


func test_no_menu_page_button_moves_anything_when_held_dragged_off_or_let_go_elsewhere() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), s)
	add_child_autofree(menus)
	await wait_process_frames(3)
	var touched := await _hammer(menus, "Match")
	menus.match_page().rules_box().rules_button(MatchOptions.RULES_CUSTOM).pressed.emit()
	await wait_process_frames(3)
	touched += await _hammer(menus, "Match, Custom")
	menus.match_page().rules_box().rules_button(MatchOptions.RULES_SKIRMISH).pressed.emit()
	menus.show_loadout()
	await wait_process_frames(3)
	touched += await _hammer(menus, "Loadout")
	var page := menus.loadout_page()
	page.show_customise()
	await wait_process_frames(3)
	var view := page.find_children("*", "CustomiseView", true, false)[0] as CustomiseView
	for tab: int in CustomiseView.Tab.values():
		view.show_tab(tab)
		await wait_process_frames(2)
		touched += await _hammer(menus, "Customise › %s" % CustomiseView.Tab.keys()[tab])
	menus.leave_loadout()
	menus.show_armory()
	await wait_process_frames(3)
	touched += await _hammer(menus, "Armory")
	assert_gt(touched, 60, "the menu pages' buttons were touched")


func test_the_loadout_crumb_keeps_its_words_whole_pressed_dragged_off_and_focused() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), s)
	add_child_autofree(menus)
	await wait_process_frames(2)
	menus.show_loadout()
	var page := menus.loadout_page()
	page.show_customise()
	await wait_process_frames(3)
	var back := page.find_child("Back", true, false) as Button
	assert_eq(back.text.strip_edges().to_upper().trim_prefix("‹").strip_edges(), "LOADOUT")
	var at := _centre(back)
	_motion(at)
	await wait_process_frames(2)
	assert_eq(_cut(back), "", "LOADOUT whole when hovered")
	_button(at, true)
	await wait_process_frames(2)
	assert_eq(_cut(back), "", "LOADOUT whole when pressed")
	_motion(Vector2(at.x + 400.0, at.y + 200.0))
	await wait_process_frames(2)
	assert_eq(_cut(back), "", "LOADOUT whole when the pointer leaves it held down")
	_motion(at)
	await wait_process_frames(2)
	assert_eq(_cut(back), "", "LOADOUT whole when the pointer comes back")
	_button(Vector2(at.x + 400.0, at.y + 200.0), false)
	back.grab_focus()
	await wait_process_frames(2)
	assert_eq(_cut(back), "", "LOADOUT whole when focused")
	assert_gte(back.size.x, back.get_minimum_size().x - SLACK, "the box is as wide as its measured minimum")
	menus.leave_loadout()


# --- The same values, by the mouse -----------------------------------------------------------------------------------

## Opens the settings tab that holds `c`.
func _show_tab_of(c: Control) -> void:
	for t in screen._tabs.get_tab_count():
		if screen._tabs.get_tab_control(t).is_ancestor_of(c):
			screen._tabs.current_tab = t
	await wait_process_frames(2)


func _saved() -> Settings:
	var t := Settings.new(PlayTuning.new())
	t.load_file(screen.save_path)
	return t


func test_the_choices_that_replaced_switches_save_the_same_values_when_clicked_with_the_mouse() -> void:
	# Crouch and Aim: Hold is off, Toggle is on; the Order wheel: Hover is the old off, Click the old on
	await _show_tab_of(screen._crouch)
	await _click(screen._crouch.button(1))
	assert_true(s.crouch_toggle, "Crouch, Toggle")
	assert_true(_saved().crouch_toggle, "and saved")
	await _click(screen._crouch.button(0))
	assert_false(s.crouch_toggle, "Crouch, Hold")
	await _click(screen._aim.button(1))
	assert_true(s.aim_toggle, "Aim, Toggle")
	assert_false(s.crouch_toggle, "Crouch stays Hold")
	assert_true(_saved().aim_toggle)
	await _click(screen._aim.button(0))
	assert_false(s.aim_toggle, "Aim, Hold")
	await _show_tab_of(screen._wheel_pick)
	await _click(screen._wheel_pick.button(1))
	assert_eq(s.wheel_pick, ControlsConfig.WheelPick.CLICK, "Order wheel, Click")
	assert_eq(_saved().wheel_pick, ControlsConfig.WheelPick.CLICK)
	await _click(screen._wheel_pick.button(0))
	assert_eq(s.wheel_pick, ControlsConfig.WheelPick.HOVER, "Order wheel, Hover")
	# the screen shows what was saved when it opens again
	s.crouch_toggle = true
	s.aim_toggle = true
	s.wheel_pick = ControlsConfig.WheelPick.CLICK
	screen.open()
	assert_eq(screen._crouch.selected(), 1)
	assert_eq(screen._aim.selected(), 1)
	assert_eq(screen._wheel_pick.selected(), 1)
	assert_eq(screen._crouch.button(0).text, "HOLD")
	assert_eq(screen._crouch.button(1).text, "TOGGLE")
	assert_eq(screen._wheel_pick.button(0).text, "HOVER")
	assert_eq(screen._wheel_pick.button(1).text, "CLICK")


func test_display_window_mode_and_frame_rate_limit_keep_their_values_and_the_new_words() -> void:
	SettingsApply.use_screens(FakeScreens.new())
	screen.open()
	screen._tabs.current_tab = 2
	await wait_process_frames(2)
	var page := screen._display_page
	var window := page.window_choice()
	var words := PackedStringArray()
	for i in window.get_child_count():
		words.append(window.button(i).text)
	assert_eq(words, PackedStringArray(["WINDOWED", "BORDERLESS", "FULLSCREEN"]), "the renamed choices")
	var modes: Array[Settings.WindowMode] = [Settings.WindowMode.WINDOWED, Settings.WindowMode.BORDERLESS,
			Settings.WindowMode.EXCLUSIVE]
	for i in modes.size():
		await _click(window.button(i))
		assert_eq(s.window_mode, modes[i], "choice %d is the same mode as before" % i)
		assert_eq(_saved().window_mode, modes[i], "and saved")
	var limit := page.limit_choice()
	assert_eq(limit.get_child_count(), Settings.FRAME_LIMITS.size() + 1)
	assert_eq(limit.button(limit.get_child_count() - 1).text, "OFF", "the last choice reads Off")
	for i in Settings.FRAME_LIMITS.size():
		await _click(limit.button(i))
		assert_eq(s.frame_limit, Settings.FRAME_LIMITS[i], "limit %d" % Settings.FRAME_LIMITS[i])
		assert_eq(Engine.max_fps, Settings.FRAME_LIMITS[i])
	await _click(limit.button(limit.get_child_count() - 1))
	assert_eq(s.frame_limit, Settings.UNLIMITED, "Off is still the unlimited value")
	assert_eq(Engine.max_fps, 0)
	assert_eq(_saved().frame_limit, Settings.UNLIMITED)


func test_every_switch_still_flips_its_setting_when_clicked_with_the_mouse() -> void:
	# each tab's MenuSwitch, clicked twice as the mouse does: it flips and flips back, and the pill shows it
	var flipped := 0
	for t in screen._tabs.get_tab_count():
		screen._tabs.current_tab = t
		await wait_process_frames(2)
		var list: Array[BaseButton] = []
		_buttons(screen._tabs.get_current_tab_control(), list)
		for b: BaseButton in list:
			if not (b is MenuSwitch or b is MenuToggle):
				continue
			var was := b.button_pressed
			await _click(b)
			assert_ne(b.button_pressed, was, "%s flips on a click" % b.name)
			await _click(b)
			assert_eq(b.button_pressed, was, "%s flips back" % b.name)
			flipped += 1
	assert_gt(flipped, 8, "the switches of the tabs were clicked")


# --- The detector sees what it is meant to see -----------------------------------------------------------------------

func test_the_detector_sees_words_cut_and_a_box_that_grows() -> void:
	var holder := VBoxContainer.new()
	add_child_autofree(holder)
	var b := Button.new()
	b.text = "LOADOUT"
	b.clip_text = true
	b.custom_minimum_size.x = 30.0
	holder.add_child(b)
	var other := Label.new()
	other.text = "Under it"
	holder.add_child(other)
	await wait_process_frames(2)
	# a button measured for something shorter than its words, as LOADOU was: its words overrun the box
	assert_ne(_cut(b), "", "words wider than their box are seen")
	b.clip_text = false
	b.custom_minimum_size.x = 0.0
	b.update_minimum_size()
	await wait_process_frames(2)
	assert_eq(_cut(b), "", "a box measured for its words reads as whole")
	# a box that grows moves what lies beside or under it, and is seen
	var rest := {}
	_snap(holder, [], rest)
	b.text = "LOADOUT AND MORE WORDS HERE"
	b.custom_minimum_size.y = 90.0
	await wait_process_frames(2)
	var later := {}
	_snap(holder, [], later)
	assert_false(_changes(rest, later).is_empty(), "a box that changes size moves what lies under it, and is seen")


func test_a_pointer_over_a_button_reaches_it_in_every_menu_page() -> void:
	# a covered button shows as one the pointer never hovers; the hammer checks each, and here the Match page's cards
	var menus := MenuScreen.new(MatchPicks.new(), s)
	add_child_autofree(menus)
	await wait_process_frames(3)
	var list: Array[BaseButton] = []
	_buttons(menus, list)
	var hovered := 0
	for b: BaseButton in list:
		_motion(_centre(b))
		await wait_process_frames(2)
		if b.is_hovered():
			hovered += 1
	assert_eq(hovered, list.size(), "every button is reachable by the pointer")


# --- Loadout strip: five long names ----------------------------------------------------------------------------------

func test_a_full_loadout_strip_of_long_names_stays_inside_the_window() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), s)
	add_child_autofree(menus)
	await wait_process_frames(2)
	menus.show_loadout()
	var page := menus.loadout_page()
	# the shared loadouts are the player's: write elsewhere and put them back as they were
	page.save_path = "%s/loadouts-%d.save" % [ROOT, _n]
	var strip := page.strip()
	var saved := strip.saved
	var before := saved.to_dict()
	while saved.slots.size() < SavedLoadouts.MAX_SLOTS:
		saved.create()
	for i in saved.slots.size():
		saved.rename(i, "Close quarters rifle")
	strip.refresh()
	await wait_process_frames(6)
	var window := menus.get_viewport().get_visible_rect()
	var out := PackedStringArray()
	# each mode the strip has: its actions, Replace's prompt and Remove's question (UI1 round 1)
	for step: Callable in [Callable(), strip.start_replace, strip.start_remove]:
		if step.is_valid():
			strip.cancel()
			step.call()
			await wait_process_frames(6)
		for c: Node in strip.get_children():
			var ctl := c as Control
			if ctl != null and ctl.visible and ctl.get_global_rect().end.x > window.end.x + SLACK:
				out.append("mode %d: %s ends at %.0f of %.0f" % [strip.mode, ctl.name, ctl.get_global_rect().end.x,
						window.end.x])
	strip.cancel()
	await wait_process_frames(6)
	var first := strip.card(0)
	var name_label := first.find_child("Name", true, false) as Label
	assert_eq(first.tooltip_text, "Close quarters rifle", "a cut name is whole in the card's tooltip")
	assert_lte(name_label.size.x, LoadoutStrip.NAME_WIDTH + 1.0, "the name takes no more than its room")
	saved.from_dict(before)
	saved.dirty = false
	assert_eq(out, PackedStringArray(), "five saved loadouts with 20-letter names stay inside the window")


# --- The frame-rate figure and the menu bar --------------------------------------------------------------------------

func test_turning_on_show_fps_does_not_cover_the_level_chip_or_any_other_menu_control() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), s)
	add_child_autofree(menus)
	var readout := FpsReadout.new(s)
	add_child_autofree(readout)
	s.show_fps = false
	s.changed.emit()
	await wait_process_frames(3)
	var chip := menus.find_child("Level", true, false) as Control
	assert_not_null(chip)
	assert_true(chip.is_visible_in_tree(), "the level chip shows")
	var label := readout.find_children("*", "Label", true, false)[0] as Label
	var rest := {}
	_snap(menus, [], rest)
	s.show_fps = true
	s.changed.emit()
	await wait_process_frames(3)
	assert_true(readout.shown(), "the figure is on")
	var now := {}
	_snap(menus, [], now)
	assert_eq(_changes(rest, now), PackedStringArray(), "turning it on moves nothing of the menu")
	var covered := PackedStringArray()
	for c: Control in menus.find_children("*", "Control", true, false):
		if c.is_visible_in_tree() and c.get_global_rect().size.x > 0.0 and c.get_global_rect().intersects(label.get_global_rect()):
			if c is Button or c is Label or c.name == "Level":
				covered.append("%s %s" % [c.name, c.get_global_rect()])
	assert_eq(covered, PackedStringArray(), "the figure %s lies over nothing the menu shows" % label.get_global_rect())


# --- The re-laid Match page, every state -----------------------------------------------------------------------------

func test_every_match_page_button_is_reachable_and_still_in_every_map_mode_and_rules_state() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), s)
	add_child_autofree(menus)
	await wait_process_frames(3)
	var page := menus.match_page()
	var touched := 0
	var window := menus.get_viewport().get_visible_rect()
	for map_id: String in page.map_ids():
		for mode: String in MatchOptions.MODES:
			for rules: String in [MatchOptions.RULES_SKIRMISH, MatchOptions.RULES_CUSTOM]:
				page.map_card(map_id).pressed.emit()
				page.mode_card(mode).pressed.emit()
				page.rules_box().rules_button(rules).pressed.emit()
				await wait_process_frames(3)
				var what := "Match %s, %s, %s" % [map_id, mode, rules]
				touched += await _hammer(menus, what)
				var list: Array[BaseButton] = []
				_buttons(menus, list)
				for b: BaseButton in list:
					if not window.encloses(b.get_global_rect()):
						fail_test("%s: %s lies outside the window %s" % [what, b.name, b.get_global_rect()])
	assert_gt(touched, 200, "every state's buttons were touched")


func test_the_reload_choice_saves_both_values_by_mouse() -> void:
	# Manual is the old off, Automatic the old on
	await _show_tab_of(screen._auto_reload)
	var words := PackedStringArray([screen._auto_reload.button(0).text, screen._auto_reload.button(1).text])
	assert_eq(words, PackedStringArray(["MANUAL", "AUTOMATIC"]), "the choice's words")
	await _click(screen._auto_reload.button(1))
	assert_true(s.auto_reload, "Automatic is on")
	assert_true(_saved().auto_reload, "and saved")
	await _click(screen._auto_reload.button(0))
	assert_false(s.auto_reload, "Manual is off")
	assert_false(_saved().auto_reload, "and saved")
	s.auto_reload = true
	screen.open()
	assert_eq(screen._auto_reload.selected(), 1, "the screen shows what was saved when it opens again")


# --- Fix round 3: picks that change what a page says, and the GPU COST heading ---------------------------------------

func test_clicking_each_bbs_pick_and_each_graphics_and_dev_choice_moves_no_box() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), s)
	add_child_autofree(menus)
	await wait_process_frames(3)
	menus.show_loadout()
	var page := menus.loadout_page()
	page.show_customise()
	await wait_process_frames(3)
	var view := page.find_children("*", "CustomiseView", true, false)[0] as CustomiseView
	view.show_tab(CustomiseView.Tab.BBS)
	await wait_process_frames(3)
	var clicked := await _click_picks(menus, "Customise BBs")
	assert_gte(clicked, 3, "the BB picks were clicked")
	# Graphics and Dev choices, by the mouse, with the layout of the screen held to the rects before each click
	for t in screen._tabs.get_tab_count():
		var title: String = screen._tabs.get_tab_title(t)
		if title != "GRAPHICS" and title != "DEV":
			continue
		screen._tabs.current_tab = t
		await wait_process_frames(3)
		clicked += await _click_picks(screen._tabs.get_current_tab_control(), "Settings %s" % title)
	assert_gt(clicked, 20, "choices of the BBs, Graphics and Dev pages were clicked")


## Clicks every choice, switch and card under `scope` once, as the mouse does, and fails if any box under it moves or
## changes size, or any button's words are cut. (Words of other labels may change: a pick sets what they read.)
func _click_picks(scope: Node, what: String) -> int:
	var list: Array[BaseButton] = []
	_buttons(scope, list)
	var n := 0
	for b: BaseButton in list:
		if not is_instance_valid(b) or not b.is_visible_in_tree():
			continue
		if not (b is MenuSwitch or b is MenuToggle or b is MenuCard or (b.toggle_mode and b.get_parent() is MenuChoice)):
			continue
		# the part tabs switch the page (what lies under changes by design); the crumb leaves it
		if String(b.name).begins_with("Part_") or b.name == &"Back":
			continue
		_let_pointer_through()
		var skip := _settings_skip(scope)
		var rest := {}
		_snap(scope, skip, rest)
		await _click(b)
		await wait_process_frames(2)
		n += 1
		var after := {}
		_snap(scope, skip, after)
		var moved := _changes(rest, after, false)
		if not moved.is_empty():
			fail_test("%s › %s: clicking it changes %d boxes: %s" % [what, b.name, moved.size(), ", ".join(moved.slice(0, 3))])
		if is_instance_valid(b) and b is Button and _cut(b as Button) != "":
			fail_test("%s › %s: %s" % [what, b.name, _cut(b as Button)])
	return n


func test_the_graphics_cost_heading_overlaps_nothing_and_is_not_cut() -> void:
	for t in screen._tabs.get_tab_count():
		if screen._tabs.get_tab_title(t) == "GRAPHICS":
			screen._tabs.current_tab = t
	await wait_process_frames(3)
	var page := screen._tabs.get_current_tab_control()
	var heads: Array[Label] = []
	for n: Node in page.find_children("*", "Label", true, false):
		var l := n as Label
		if l.visible and l.is_visible_in_tree() and l.text == tr("GRAPHICS_COST_HEAD"):
			heads.append(l)
	assert_gt(heads.size(), 0, "the GPU COST heading shows")
	for head: Label in heads:
		var line := TextLine.new()
		line.add_string(head.text, head.get_theme_font(&"font"), head.get_theme_font_size(&"font_size"))
		assert_lte(line.get_line_width(), head.size.x + SLACK, "the heading's words fit their box")
		var hit := PackedStringArray()
		for n: Node in page.find_children("*", "Control", true, false):
			var c := n as Control
			if c == head or c.is_ancestor_of(head) or head.is_ancestor_of(c) or not c.is_visible_in_tree():
				continue
			if c is Label or c is BaseButton or c is Range:
				if c.get_global_rect().size.x > 0.0 and c.get_global_rect().intersects(head.get_global_rect()):
					hit.append("%s %s" % [c.name, c.get_global_rect()])
		assert_eq(hit, PackedStringArray(), "nothing lies over the heading %s" % head.get_global_rect())
