class_name HudPlantPrompt
extends VBoxContainer
## Plant The Bomb's prompt under the crosshair (PB1), in the reload prompt's plate: "HOLD G · PICK UP THE BOMB", "HOLD G
## · PLANT THE BOMB" or "HOLD G · DEFUSE", Use's key as bound now (HudPlant.Prompt says which applies), and under it a
## quiet line, "YOU HAVE THE BOMB", while you carry it and no prompt shows. The words are built only when the prompt
## changes (or on `refresh_key`, after a rebind), never per frame.

## The words' size, the quiet line's size and its backing, and the plate's padding (px).
const SIZE := GameTheme.SMALL_SIZE
const QUIET_SIZE := HudStyle.NOTE_SIZE
const QUIET_ALPHA := 0.8
const PAD := Vector2i(10, 4)
## The prompts' words by HudPlant.Prompt (translation keys; NONE has none).
const KEYS: Dictionary[int, String] = {
	HudPlant.Prompt.PICK_UP: "HUD_BOMB_PICK_UP", HudPlant.Prompt.PLANT: "HUD_BOMB_PLANT",
	HudPlant.Prompt.DEFUSE: "HUD_BOMB_DEFUSE",
}

var _plate: PanelContainer = null
var _words: Label = null
var _quiet: Label = null
var _prompt: HudPlant.Prompt = HudPlant.Prompt.NONE


func _init() -> void:
	name = "BombPrompt"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_plate = PanelContainer.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_plate.add_theme_stylebox_override("panel", HudStyle.panel_box(HudStyle.BACKING_AIM, PAD.x, PAD.y))
	_plate.visible = false
	add_child(_plate)
	_words = HudStyle.label(_plate, SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT, HudStyle.SPACING_AIM)
	_quiet = HudStyle.label(self, QUIET_SIZE, 700, Color(GameTheme.TEXT, QUIET_ALPHA), HORIZONTAL_ALIGNMENT_CENTER,
			HudStyle.SPACING_AIM)
	_quiet.text = HudStyle.caps("HUD_BOMB_CARRYING")
	_quiet.add_theme_constant_override("outline_size", 6)
	_quiet.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	_quiet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_quiet.visible = false
	visible = false


## Shows `prompt` (HudPlant.Prompt) and, with none and `carrying`, the quiet line. Rebuilds the words only on a change.
func show_for(prompt: HudPlant.Prompt, carrying: bool) -> void:
	if prompt != _prompt:
		_prompt = prompt
		_build()
	_plate.visible = prompt != HudPlant.Prompt.NONE
	_quiet.visible = carrying and prompt == HudPlant.Prompt.NONE
	visible = _plate.visible or _quiet.visible


## The prompt's words built again with Use's key as bound now.
func refresh_key() -> void:
	_build()


## The prompt shown (HudPlant.Prompt.NONE for none).
func prompt() -> HudPlant.Prompt:
	return _prompt


## The prompt's words ("HOLD G · PICK UP THE BOMB"), or "" while it is hidden: for tests.
func text() -> String:
	return _words.text if _plate.visible else ""


## The quiet line's words ("YOU HAVE THE BOMB"), or "" while it is hidden: for tests.
func quiet_text() -> String:
	return _quiet.text if _quiet.visible else ""


func _build() -> void:
	if _prompt == HudPlant.Prompt.NONE:
		return
	_words.text = (tr(KEYS[_prompt]) % KeyNames.of_action(&"use_door")).to_upper()
