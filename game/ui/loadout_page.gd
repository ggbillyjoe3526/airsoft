class_name LoadoutPage
extends Control
## The LOADOUT tab (docs/TASKS.md LO2): the saved loadouts strip with the gear page under it, or Customise for one replica.
## Every edit goes straight to the loadout carried, through LoadoutRules, then SavedLoadouts.mark_changed(): there is no Save
## button. The loadouts are saved when the page is left (`close`), when the window closes and when the page is freed; the
## Realistic colours switch writes Settings.realistic_colours and saves the settings the way the Settings screen does. Keys 1
## to 5 carry the loadout in that place; Esc backs out of rename, replace and remove, then of Customise. Built when the tab is
## opened and freed when it is left, so no menu nodes and no replica pictures are kept while it is not on show.
## From practice (`open_from_practice`, concept `loadout-practice.png`) it opens on the slot in hand and the gear page adds
## the FROM THE RANGE note; the picks are the same loadout the next match carries.

## Sent when Customise opens or closes.
signal customising_changed

const MARGIN_X := 56
const STRIP_TOP := 28
const NOTICE_TOP := 88
const NOTICE_SIZE := 15
const KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]

var saved: SavedLoadouts = null
var settings: Settings = null
## Where the loadouts and the settings are kept; the tests point these at their own files.
var save_path: String = SavedLoadouts.PATH
var settings_path: String = Settings.PATH

var _facts: LoadoutFacts = null
var _pictures: ReplicaPictures = null
var _strip: LoadoutStrip = null
var _gear: LoadoutGear = null
var _customise: CustomiseView = null
var _notice: Label = null
var _slot: Loadout.Slot = Loadout.Slot.PRIMARY
var _customising: bool = false
## What the locks were built from (the game's own loadouts only; "" for a test's).
var _lock_key: String = ""


func _init(saved_in: SavedLoadouts = null, settings_in: Settings = null) -> void:
	name = "LoadoutPage"
	saved = saved_in if saved_in != null else SavedLoadouts.shared()
	settings = settings_in if settings_in != null else Settings.shared()
	saved.rules.dev_content = settings.dev.dev_content
	# The game's own loadouts lock what the player hasn't unlocked (a test's own are all unlocked).
	if saved_in == null:
		saved.rules.follow_progress(Progress.shared(), settings.dev.disable_levelling)
		_lock_key = _locks_now()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_facts = LoadoutFacts.new(saved)
	_pictures = ReplicaPictures.new()
	_pictures.name = "Pictures"
	add_child(_pictures)
	_gear = LoadoutGear.new(_pictures, _facts)
	_gear.slot_picked.connect(_pick_slot)
	_gear.replica_picked.connect(_pick_replica)
	_gear.customise_requested.connect(show_customise)
	add_child(_gear)
	_customise = CustomiseView.new(_pictures, _facts)
	_customise.visible = false
	_customise.back_requested.connect(show_gear)
	_customise.tab_shown.connect(_refresh_after_tab)
	_customise.paint_picked.connect(_pick_paint)
	_customise.bb_weight_set.connect(_set_weight)
	_customise.glow_picked.connect(_pick_glow)
	_customise.hop_up_set.connect(_set_hop_up)
	_customise.power_picked.connect(_pick_power)
	_customise.part_picked.connect(_pick_part)
	_customise.realistic_toggled.connect(_set_realistic)
	add_child(_customise)
	_strip = LoadoutStrip.new(saved)
	_strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_strip.offset_left = MARGIN_X
	_strip.offset_right = -MARGIN_X
	_strip.offset_top = STRIP_TOP
	add_child(_strip)
	_notice = MenuParts.text("", NOTICE_SIZE, 700, GameTheme.YELLOW)
	_notice.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_notice.offset_left = MARGIN_X
	_notice.offset_right = -MARGIN_X
	_notice.offset_top = NOTICE_TOP
	_notice.visible = false
	add_child(_notice)
	if saved.load_message != "":
		# said once: the file's trouble is not repeated each time the tab opens
		_notice.text = saved.load_message
		_notice.visible = true
		saved.load_message = ""
	_refresh()


func _enter_tree() -> void:
	if not saved.changed.is_connected(_on_changed):
		saved.changed.connect(_on_changed)


func _exit_tree() -> void:
	if saved.changed.is_connected(_on_changed):
		saved.changed.disconnect(_on_changed)


## Quitting or freed with a rename open keeps the name typed, then saves: the window's close while in the tree (as
## `close`), the page's freeing without redrawing it (none of it is drawn again).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if saved == null:
			return
		if _strip != null:
			if what == NOTIFICATION_WM_CLOSE_REQUEST:
				_strip.commit()
			else:
				if saved.changed.is_connected(_on_changed):
					saved.changed.disconnect(_on_changed)
				_strip.keep_typed()
		saved.save_if_dirty(save_path)


func strip() -> LoadoutStrip:
	return _strip


## True if the game's levelling changed since the page was built (Disable levelling, or what is unlocked).
func locks_changed() -> bool:
	return _lock_key != "" and _locks_now() != _lock_key


func _locks_now() -> String:
	return "%s:%d" % [settings.dev.disable_levelling, Progress.shared().unlocked.size()]


func gear() -> LoadoutGear:
	return _gear


func customise() -> CustomiseView:
	return _customise


func facts() -> LoadoutFacts:
	return _facts


func pictures() -> ReplicaPictures:
	return _pictures


## The slot the gear page has picked, and Customise edits.
func slot() -> Loadout.Slot:
	return _slot


func customising() -> bool:
	return _customising


## Opened from practice: on `slot`, the replica in hand there, with the range's note on the gear page.
func open_from_practice(slot_in: Loadout.Slot) -> void:
	_slot = slot_in
	_gear.show_range_note(true)
	_refresh()


## The load problem shown at the top ("" when there was none).
func notice_text() -> String:
	return _notice.text if _notice.visible else ""


## Keeps a name typed in an open rename, then saves the loadouts if they changed; called when the page is left and when
## a match starts.
func close() -> void:
	_strip.commit()
	saved.save_if_dirty(save_path)


## Puts the keyboard on the page's main control: CUSTOMISE on the gear page, the COLOUR part in Customise.
func focus_default() -> void:
	if _customising:
		_customise.part_card(_customise.tab).grab_focus()
	else:
		_gear.customise_button().grab_focus()


## Opens Customise for the picked slot (or `which`).
func show_customise(which: int = -1) -> void:
	if which >= 0 and which < LoadoutFacts.SLOTS.size():
		_slot = which as Loadout.Slot
	if _customising or not _facts.has(_slot):
		return
	_customising = true
	_gear.visible = false
	_strip.visible = false
	_notice.visible = false
	_customise.visible = true
	_refresh()
	_customise.part_card(_customise.tab).grab_focus()
	customising_changed.emit()


## Back to the gear page.
func show_gear() -> void:
	if not _customising:
		return
	_customising = false
	_pictures.let_go_parts()
	_customise.visible = false
	_gear.visible = true
	_strip.visible = true
	_notice.visible = _notice.text != ""
	_refresh()
	_gear.customise_button().grab_focus()
	customising_changed.emit()


## Esc: leaves rename, replace or remove, else Customise; false when there was nothing to leave (the menus go back).
func back_out() -> bool:
	if _strip.cancel():
		return true
	if _customising:
		show_gear()
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		if back_out():
			get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	var plain := key != null and not (key.ctrl_pressed or key.alt_pressed or key.shift_pressed or key.meta_pressed)
	if plain and key.pressed and not key.echo and not _customising and _strip.mode == LoadoutStrip.Mode.NORMAL:
		var place := KEYS.find(key.keycode)
		if place >= 0 and place < saved.slots.size():
			saved.use(place)
			get_viewport().set_input_as_handled()


func _on_changed() -> void:
	_facts.refresh()
	_refresh()


func _refresh_after_tab(_tab: CustomiseView.Tab) -> void:
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	if not _facts.has(_slot):
		_slot = Loadout.Slot.PRIMARY
	_strip.refresh()
	var realistic := settings.realistic_colours
	if _customising:
		_customise.refresh(_slot, realistic)
	else:
		_gear.refresh(_slot, realistic)


func _pick_slot(s: Loadout.Slot) -> void:
	_slot = s
	_refresh()


func _pick_replica(id: String) -> void:
	if _facts.slot_of(id) == _slot:
		return
	if saved.rules.equip(saved.carried(), _slot, id):
		saved.mark_changed()


func _pick_paint(paint: StringName) -> void:
	if _facts.has(_slot) and saved.rules.set_paint(saved.carried(), _facts.item(_slot).id, paint):
		saved.mark_changed()


func _set_weight(grams: float) -> void:
	var id := _facts.item(_slot).id
	if not is_equal_approx(saved.rules.snap_bb_weight(grams), _facts.tune(_slot).bb_weight):
		saved.rules.set_bb_weight(saved.carried(), id, grams)
		saved.mark_changed()


## Glowing BBs for the replica being customised (WL8): kept with the loadout, drawing only.
func _pick_glow(choice: Loadout.Glow) -> void:
	if _facts.has(_slot) and saved.carried().set_glow(_facts.item(_slot).id, choice):
		saved.mark_changed()


func _set_hop_up(dial: float) -> void:
	var id := _facts.item(_slot).id
	if not is_equal_approx(saved.rules.snap_hop_up(dial), _facts.tune(_slot).hop_up):
		saved.rules.set_hop_up(saved.carried(), id, dial)
		saved.mark_changed()


func _pick_power(id: String) -> void:
	if saved.rules.set_power(saved.carried(), _facts.item(_slot).id, id):
		saved.mark_changed()


## A part card: fits the part (or takes the slot's off for "") to the replica being customised.
func _pick_part(part_slot: StringName, part_id: String) -> void:
	var item := _facts.item(_slot)
	var fitted := _facts.fitted_part(item, part_slot)
	if (fitted.id if fitted != null else "") == part_id:
		return
	if saved.rules.set_part(saved.carried(), item.id, part_slot, part_id):
		saved.mark_changed()


## The Realistic colours switch: the setting, saved as the Settings screen saves.
func _set_realistic(on: bool) -> void:
	settings.realistic_colours = on
	settings.mark_changed()
	settings.save_if_dirty(settings_path)
	_refresh()
