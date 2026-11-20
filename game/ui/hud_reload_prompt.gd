class_name HudReloadPrompt
extends PanelContainer
## The reload prompt under the crosshair (RL2): "RELOAD [R]", the Reload key as bound now, on a small plate (owner,
## 2026-11-20: every prompt the action, then the key; it was the key's cap, then RELOAD), while reloads are manual
## (Settings › Controls › Reload) and the replica in hand waits for one (Armament.reload_due) in a live round, with you
## in play. The key's name is read each time the prompt comes up (so a rebind shows) and on `refresh_key`; nothing
## else is made after it is built.

## The words' size.
const SIZE := GameTheme.SMALL_SIZE
## The plate's padding (px).
const PAD := Vector2i(10, 4)

var _words: Label = null
var _key: String = ""


func _init() -> void:
	name = "ReloadPrompt"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_stylebox_override("panel", HudStyle.panel_box(HudStyle.BACKING_AIM, PAD.x, PAD.y))
	_words = HudStyle.label(self, SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, HudStyle.SPACING_AIM)
	refresh_key()
	visible = false


## Shows the prompt while `due`; coming up, it reads the Reload key as bound now.
func show_when(due: bool) -> void:
	if due and not visible:
		refresh_key()
	visible = due


## The Reload key as bound now (the settings, opened from the pause menu, may have changed it).
func refresh_key() -> void:
	_key = KeyNames.of_action(PlayerInput.RELOAD)
	_words.text = HudStyle.prompt_words(&"HUD_RELOAD", _key)


## The key's name in the prompt, for tests.
func key_text() -> String:
	return _key


## The prompt's words, for tests.
func text() -> String:
	return _words.text
