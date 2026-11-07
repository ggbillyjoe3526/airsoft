class_name RetroPixels
extends CanvasLayer
## The Dev settings' Retro pixels (the browser game's render/retroFilter.ts): the 3D view in chunky pixels and a small
## dithered palette, drawn over the view and under the HUD. Changes only what you see. Built only while it is on.

## Screen pixels per retro pixel, and shades of each of red, green and blue: the browser's defaults, and the Dev tab's
## sliders' ends (BP6).
const PIXEL_SIZE := 4
const SHADES := 6
const PIXEL_SIZE_MIN := 2
const PIXEL_SIZE_MAX := 16
const SHADES_MIN := 2
const SHADES_MAX := 16
const SHADER := preload("res://game/play/retro_pixels.gdshader")

var _mat: ShaderMaterial = null
var _pixel_size: int = PIXEL_SIZE
var _shades: int = SHADES


## The block size and shades a channel, each held to its sliders' ends; before or after it is in the tree.
func set_look(pixel_size: int, shades: int) -> void:
	_pixel_size = clampi(pixel_size, PIXEL_SIZE_MIN, PIXEL_SIZE_MAX)
	_shades = clampi(shades, SHADES_MIN, SHADES_MAX)
	if _mat != null:
		_mat.set_shader_parameter(&"pixel_size", float(_pixel_size))
		_mat.set_shader_parameter(&"shades", float(_shades))


func _ready() -> void:
	name = "RetroPixels"
	# Under the HUD's layer (the default 1), over the 3D view.
	layer = 0
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	rect.material = _mat
	set_look(_pixel_size, _shades)
	add_child(rect)
