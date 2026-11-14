class_name MenuScreen
extends Control
## The menus, the first screen the game shows (no title screen: owner, 2026-11-02): the rail down the left (NavRail)
## beside a page, over the picked field's blurred picture (MenuBackdrop): the Match page (MatchPage, which keeps its
## picks in the MatchPicks it is given), the Loadout page (LoadoutPage, built when its tab is opened and freed, after
## saving, when the Match tab comes back) or the Armory (ArmoryPage, built and freed the same way). A tab press goes to
## the entry screen, which opens the settings beside the rail and asks for the page. Esc backs out of what the page has
## open (the Loadout's rename, replace and Customise); with nothing open it reaches Main, which asks QUIT GAME? (FB1),
## as the rail's QUIT does. A notice (GraphicsNotice) shows at the page's bottom left over it (`show_notice`).
## From practice (`open_practice_loadout`, concept `loadout-practice.png`) the menus are only the Loadout page beside
## the rail's LOADOUT tab and BACK TO PRACTICE: that button, the Loadout's key and Esc (after what the page has open)
## send `practice_requested`.

## A tab was pressed.
signal tab_requested(tab: NavRail.Tab)
## The rail's QUIT was pressed.
signal quit_requested
## From practice: back to the range was asked for (the button, the Loadout's key or Esc).
signal practice_requested

## A graphics notice sits at the page's bottom left, beside the rail, clear of PLAY at the bottom right (px).
const NOTICE_LEFT := 52.0
const NOTICE_BOTTOM := 44.0

var _rail: NavRail = null
var _backdrop: MenuBackdrop = null
var _notice: GraphicsNotice = null
var _match: MatchPage = null
var _loadout: LoadoutPage = null
var _armory: ArmoryPage = null
var _settings: Settings = null
var _from_practice: bool = false


func _init(picks: MatchPicks = null, settings: Settings = null) -> void:
	name = "MenuScreen"
	_settings = settings if settings != null else Settings.shared()
	theme = GameTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop = MenuBackdrop.new()
	add_child(_backdrop)
	_match = MatchPage.new(picks, settings)
	_match.offset_left = NavRail.WIDTH
	_match.map_picked.connect(_backdrop.show_map)
	add_child(_match)
	_backdrop.show_map(_match.picks.map_id)
	_rail = NavRail.new()
	_rail.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_rail.tab_pressed.connect(_on_tab)
	_rail.practice_pressed.connect(_on_practice)
	_rail.quit_pressed.connect(func() -> void: quit_requested.emit())
	add_child(_rail)
	show_level()


## The chip shows the player's level, greyed while levelling is off (Settings › Dev); an open Loadout or Armory page
## whose locks changed under the settings (Disable levelling, Reset level) is built again.
func show_level() -> void:
	var standing := Progress.shared().standing()
	var into := 1.0 if standing.at_cap() else float(standing.into) / float(maxi(1, standing.next))
	_rail.set_level(standing.level, into, _settings.dev.disable_levelling)
	if _loadout != null and _loadout.locks_changed():
		var slot := _loadout.slot()
		leave_loadout()
		show_loadout()
		if _from_practice:
			_loadout.open_from_practice(slot)
	if _armory != null and _armory.stale():
		leave_armory()
		show_armory()


func nav_rail() -> NavRail:
	return _rail


func backdrop() -> MenuBackdrop:
	return _backdrop


## Shows `notice` at the page's bottom left over the page, in place of any other, with the keyboard on its first
## button so Enter answers it rather than starting a match unseen; the page works under it.
func show_notice(notice: GraphicsNotice) -> void:
	close_notice()
	_notice = notice
	add_child(notice)
	notice.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	notice.grow_vertical = Control.GROW_DIRECTION_BEGIN
	notice.offset_left = NavRail.WIDTH + NOTICE_LEFT
	notice.offset_bottom = -NOTICE_BOTTOM
	notice.offset_right = notice.offset_left
	notice.offset_top = notice.offset_bottom
	_focus_notice.call_deferred()


func _focus_notice() -> void:
	if _notice == null or not _notice.is_visible_in_tree():
		return
	var buttons := _notice.find_children("*", "Button", true, false)
	if not buttons.is_empty():
		(buttons[0] as Button).grab_focus()


## Puts `screen` (the settings) over the page, under the rail and any notice, beside the rail.
func add_over_page(screen: Control) -> void:
	add_child(screen)
	move_child(screen, _rail.get_index())
	screen.offset_left = NavRail.WIDTH


## Hides the page showing (the settings are open over the field's picture), or shows it again; the rail stays.
func set_page_hidden(hidden: bool) -> void:
	_match.visible = not hidden and _loadout == null and _armory == null
	if _loadout != null:
		_loadout.visible = not hidden
	if _armory != null:
		_armory.visible = not hidden
	# A waiting notice steps aside under Settings, whose BACK sits in the same corner (BP3), and comes back after it.
	if _notice != null:
		_notice.visible = not hidden


## The notice showing, or null.
func notice() -> GraphicsNotice:
	return _notice


func close_notice() -> void:
	if _notice == null:
		return
	var focused: Control = _notice.get_viewport().gui_get_focus_owner() if _notice.get_viewport() != null else null
	var had_keys := focused != null and _notice.is_ancestor_of(focused)
	_notice.queue_free()
	_notice = null
	if had_keys and visible:
		focus_page()


func match_page() -> MatchPage:
	return _match


## The Loadout page while it is open, else null.
func loadout_page() -> LoadoutPage:
	return _loadout


## The Armory page while it is open, else null.
func armory_page() -> ArmoryPage:
	return _armory


## The tab whose page is showing: MATCH, LOADOUT or ARMORY.
func page_tab() -> NavRail.Tab:
	if _loadout != null:
		return NavRail.Tab.LOADOUT
	return NavRail.Tab.ARMORY if _armory != null else NavRail.Tab.MATCH


func focus_play() -> void:
	if _notice != null:
		# A notice waiting for an answer keeps the keyboard, so Enter never starts a match past it (BP3: after the crash
		# screen, or back from Settings, PLAY took it).
		_focus_notice()
		return
	_match.focus_play()


## Puts the keyboard on the page's main control, or on a notice waiting for an answer.
func focus_page() -> void:
	if _notice != null:
		_focus_notice()
	elif _loadout != null:
		_loadout.focus_default()
	elif _armory != null:
		_rail.tab_button(NavRail.Tab.ARMORY).grab_focus()
	else:
		_match.focus_play()


## Shows the Loadout page, building it the first time.
func show_loadout() -> void:
	leave_armory()
	if _loadout == null:
		_loadout = LoadoutPage.new(null, _settings)
		_loadout.offset_left = NavRail.WIDTH
		add_child(_loadout)
		# under the rail, over the Match page
		move_child(_loadout, _rail.get_index())
	# the figures in the air of the field the Match page has picked (AUD2)
	_loadout.set_field(_match.picks)
	_match.visible = false
	_rail.set_current(NavRail.Tab.LOADOUT)
	# the LOADOUT tab pressed in Customise is the way back to the Loadout (FB1)
	_loadout.show_gear()
	_loadout.focus_default()


## Opens the Loadout from practice: the bar shows only LOADOUT and BACK TO PRACTICE, and the page opens on `slot`, the
## replica in hand, with the range's note.
func open_practice_loadout(slot: Loadout.Slot) -> void:
	_from_practice = true
	_rail.set_practice(true)
	show_loadout()
	_loadout.open_from_practice(slot)
	_loadout.focus_default()


## Whether the menus are the Loadout from practice.
func from_practice() -> bool:
	return _from_practice


## Shows the Armory, building it the first time (the Loadout page is saved and freed).
func show_armory() -> void:
	leave_loadout()
	if _armory == null:
		_armory = ArmoryPage.new(_settings)
		_armory.offset_left = NavRail.WIDTH
		add_child(_armory)
		# under the rail, over the Match page
		move_child(_armory, _rail.get_index())
	_match.visible = false
	_rail.set_current(NavRail.Tab.ARMORY)


## Shows the Match page again; the Loadout page is saved and freed, the Armory freed.
func show_match() -> void:
	leave_loadout()
	leave_armory()
	_match.visible = true
	_rail.set_current(NavRail.Tab.MATCH)


## Saves the loadouts and frees the Loadout page, if it is open (a match is about to start, or another tab opens).
func leave_loadout() -> void:
	if _loadout == null:
		return
	_loadout.close()
	remove_child(_loadout)
	_loadout.queue_free()
	_loadout = null


## Frees the Armory page, if it is open, with the pictures it drew.
func leave_armory() -> void:
	if _armory == null:
		return
	remove_child(_armory)
	_armory.queue_free()
	_armory = null


func _on_tab(tab: NavRail.Tab) -> void:
	tab_requested.emit(tab)


func _on_practice() -> void:
	practice_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event.is_echo():
		return
	if _from_practice and event.is_action_pressed(&"loadout"):
		get_viewport().set_input_as_handled()
		practice_requested.emit()
	elif _from_practice and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		practice_requested.emit()
