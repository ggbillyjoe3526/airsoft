extends SceneTree
## Bakes the station dress's texture arrays (MT3) from the CC0 ambientCG sets StationLook names, in its `sets` order:
## `assets/textures/station/station_col.jpg` (each set's colour) and `station_srf.png` (its OpenGL normal's x and y in
## red and green, its roughness in blue), each a column of LAYER px layers, imported as Texture2DArray.
##
## The sets come from the CC0 mirror of ambientCG's library on GitHub (MIRROR at commit COMMIT; ambientcg.com itself
## is out of the cloud's reach), as 512 px UASTC KTX2 files, fetched with curl into a cache folder once. Their colour
## is flagged sRGB and reads back linear, so it is turned back to sRGB here. Dev only, never shipped.
##
##   godot --headless --path . -s res://tools/textures/station_textures.gd -- <cache folder>
##   godot --headless --path . --import

const MIRROR := "https://raw.githubusercontent.com/Papyszoo/CC0-Public-Domain-Textures"
const COMMIT := "fcc4ff97a5a843dc2e242ec9e195389bc46ed7d2"
const PACK := "packs/ambientcg-textures/textures"
const LAYER := 512
const JPG_QUALITY := 0.92


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("station_textures: give a cache folder for the KTX2 files")
		quit(1)
		return
	var cache: String = args[0]
	DirAccess.make_dir_recursive_absolute(cache)
	var look := StationLook.new()
	var n := look.sets.size()
	var colour := Image.create_empty(LAYER, LAYER * n, false, Image.FORMAT_RGB8)
	var surface := Image.create_empty(LAYER, LAYER * n, false, Image.FORMAT_RGB8)
	for i in n:
		var id := String(look.sets[i])
		var col := _map(cache, id, "Color")
		var nrm := _map(cache, id, "NormalGL")
		var rough := _map(cache, id, "Roughness")
		if col == null or nrm == null or rough == null:
			quit(1)
			return
		col.linear_to_srgb()
		colour.blit_rect(col, Rect2i(0, 0, LAYER, LAYER), Vector2i(0, LAYER * i))
		for y in LAYER:
			for x in LAYER:
				var nc := nrm.get_pixel(x, y)
				surface.set_pixel(x, LAYER * i + y, Color(nc.r, nc.g, rough.get_pixel(x, y).r))
		print("station_textures: layer %d %s" % [i, id])
	var out := ProjectSettings.globalize_path("res://assets/textures/station/")
	DirAccess.make_dir_recursive_absolute(out)
	colour.save_jpg(out.path_join("station_col.jpg"), JPG_QUALITY)
	surface.save_png(out.path_join("station_srf.png"))
	print("station_textures: %d layers written to %s" % [n, out])
	quit()


## Set `id`'s map `kind` (Color, NormalGL, Roughness) at LAYER px, uncompressed RGB, fetched into `cache` if missing.
func _map(cache: String, id: String, kind: String) -> Image:
	var file := "%s_1K-PNG_%s.ktx2" % [id, kind]
	var path := cache.path_join(file)
	if not FileAccess.file_exists(path):
		var url := "%s/%s/%s/%s/%s" % [MIRROR, COMMIT, PACK, id, file]
		var code := OS.execute("curl", ["-fsSL", "--retry", "3", "-o", path, url])
		if code != 0:
			printerr("station_textures: could not fetch %s" % url)
			return null
	var img := Image.new()
	if img.load_ktx_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		printerr("station_textures: %s is no KTX2 image" % path)
		return null
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGB8)
	if img.get_size() != Vector2i(LAYER, LAYER):
		img.resize(LAYER, LAYER, Image.INTERPOLATE_LANCZOS)
	return img
