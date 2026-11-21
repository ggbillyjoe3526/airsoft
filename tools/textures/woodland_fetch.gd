extends SceneTree
## Fetches the CC0 ambientCG maps Woodland's textures are made from (WQ1) into a cache folder, each decoded to a PNG
## (`<id>_<map>.png`, 1K): the barks and the surfaces `tools/textures/woodland_textures.py` composes into
## `assets/textures/woodland/`. They come from the CC0 mirror of ambientCG's library on GitHub (MIRROR at commit COMMIT,
## as `station_textures.gd`; ambientcg.com itself is out of the cloud's reach). Run:
##   godot --headless --path . -s res://tools/textures/woodland_fetch.gd -- <cache folder>
## Dev only: tools/ never ships.

const MIRROR := "https://raw.githubusercontent.com/Papyszoo/CC0-Public-Domain-Textures"
const COMMIT := "fcc4ff97a5a843dc2e242ec9e195389bc46ed7d2"
const PACK := "packs/ambientcg-textures/textures"
## Each set and the maps of it used.
const SETS: Dictionary = {
	"Bark001": ["Color", "NormalGL"],
	"Bark002": ["Color", "NormalGL"],
	"Bark014": ["Color", "NormalGL"],
	"Wood058": ["Color", "NormalGL"],
	"Concrete034": ["Color", "NormalGL"],
	"Metal038": ["Color", "NormalGL"],
	"Ground054": ["Color", "NormalGL"],
	"Moss002": ["Color", "NormalGL"],
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("woodland_fetch: <cache folder>")
		quit(1)
		return
	var cache := args[0]
	DirAccess.make_dir_recursive_absolute(cache)
	var failed := 0
	for id: String in SETS:
		for kind: String in SETS[id] as Array:
			if not _fetch(cache, id, kind):
				failed += 1
	print("woodland_fetch: %d maps, %d failed" % [SETS.size(), failed])
	quit(1 if failed > 0 else 0)


func _fetch(cache: String, id: String, kind: String) -> bool:
	var out := cache.path_join("%s_%s.png" % [id, kind])
	if FileAccess.file_exists(out):
		return true
	var file := "%s_1K-PNG_%s.ktx2" % [id, kind]
	var path := cache.path_join(file)
	if not FileAccess.file_exists(path):
		var url := "%s/%s/%s/%s/%s" % [MIRROR, COMMIT, PACK, id, file]
		if OS.execute("curl", ["-fsSL", "--retry", "3", "-o", path, url]) != 0:
			printerr("woodland_fetch: could not fetch %s" % url)
			return false
	var img := Image.new()
	if img.load_ktx_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		printerr("woodland_fetch: %s is no KTX2 image" % path)
		return false
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	return img.save_png(out) == OK
