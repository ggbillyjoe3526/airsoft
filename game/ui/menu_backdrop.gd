class_name MenuBackdrop
extends Control
## The menus' backdrop (UI concept B, owner 2026-11-02): the picked field's picture (assets/maps/<id>.jpg), softly
## blurred, under a night shade that is darker at the left (behind the rail and the page's first column) than at the
## right. The blur is made once per field on the CPU (shrunk, then grown again with a smooth filter), so drawing it
## costs one textured rect a frame. A field with no picture leaves the plain night colour.

const PICTURE_DIR := "res://assets/maps/"
## The blur: the picture is shrunk to SMALL, then grown to SOFT; the window stretches SOFT with a linear filter.
const SMALL := Vector2i(48, 27)
const SOFT := Vector2i(384, 216)
## The shade: the night colour at these opacities, left to right (positions are shares of the width).
const SHADE_STOPS: Array[Vector2] = [Vector2(0.0, 0.84), Vector2(0.45, 0.58), Vector2(1.0, 0.64)]

## The blurred pictures by path, kept for the run.
static var _blurred: Dictionary[String, Texture2D] = {}

var _picture: TextureRect = null
var _map_id: String = ""


func _init() -> void:
	name = "MenuBackdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var plate := ColorRect.new()
	plate.color = GameTheme.BG
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(plate)
	_picture = TextureRect.new()
	_picture.name = "Picture"
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_picture)
	add_child(_shade())


## Shows field `map_id`'s picture, blurred; the same field again does nothing.
func show_map(map_id: String) -> void:
	if map_id == _map_id:
		return
	_map_id = map_id
	_picture.texture = blurred(PICTURE_DIR + map_id + ".jpg")


## The field showing, for tests.
func map_id() -> String:
	return _map_id


func picture() -> TextureRect:
	return _picture


## The picture at `path`, blurred; null when there is none. Blurred once a run (about 1 MB for the four fields), so a
## pick or the menus' rebuild after a match costs no frame.
static func blurred(path: String) -> Texture2D:
	if _blurred.has(path):
		return _blurred[path]
	var soft := _blur(path)
	if soft != null:
		_blurred[path] = soft
	return soft


static func _blur(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var source := load(path) as Texture2D
	if source == null:
		return null
	var image := source.get_image()
	if image == null or image.is_empty():
		return null
	image = image.duplicate() as Image
	if image.is_compressed():
		image.decompress()
	# the map pictures import with mipmaps (for the Match page's cards); the blur needs none
	image.clear_mipmaps()
	image.resize(SMALL.x, SMALL.y, Image.INTERPOLATE_BILINEAR)
	# bilinear: the window's filter smooths it further, and cubic cost a frame (UR1 performance review)
	image.resize(SOFT.x, SOFT.y, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(image)


func _shade() -> TextureRect:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colours := PackedColorArray()
	for stop in SHADE_STOPS:
		offsets.append(stop.x)
		colours.append(Color(GameTheme.BG, stop.y))
	gradient.offsets = offsets
	gradient.colors = colours
	var ramp := GradientTexture2D.new()
	ramp.gradient = gradient
	ramp.fill_from = Vector2(0.0, 0.5)
	ramp.fill_to = Vector2(1.0, 0.5)
	var shade := TextureRect.new()
	shade.name = "Shade"
	shade.texture = ramp
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	return shade
