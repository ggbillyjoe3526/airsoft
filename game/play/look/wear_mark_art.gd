class_name WearMarkArt
extends RefCounted
## The worn marks' pictures (WM1, WearMarks), painted once at load from noise, never per frame: an oil stain (its
## colour and its shine), one tyre's tread, and a left boot's print (the right is its mirror). White, so each decal's
## modulate gives the palette's colour; alpha is the mark. Cached: every match shares the one set.

## The noise's seeds and scales (cells across a picture), and how ragged a stain's edge is (of its radius).
const SEED := 5021
const EDGE_CELLS := 3.0
const SPOT_CELLS := 9.0
const EDGE_RAGGED := 0.35
## A stain: its edge's softness (of its radius), how much darker its middle is, and its splashes' count and size.
const STAIN_SOFT := 0.12
const STAIN_CORE := 0.25
const SPLASHES := 7
const SPLASH_SIZE := 0.07
## A tread: its lugs (bars across it) per tile, their slant (of the width) and fill, and the rubber's patchiness.
const LUGS := 8
const LUG_SLANT := 0.35
const LUG_FILL := 0.55
const TREAD_PATCHY := 0.6
## A print: the sole's forefoot and heel (centres and radii, of the length and width), its lugs' rows and columns.
const FORE_AT := 0.32
const FORE_RADIUS := Vector2(0.5, 0.3)
const HEEL_AT := 0.8
const HEEL_RADIUS := Vector2(0.42, 0.18)
const PRINT_ROWS := 9
const PRINT_COLUMNS := 3
const PRINT_GAP := 0.35

static var _stain: ImageTexture = null
static var _stain_orm: ImageTexture = null
static var _tread: ImageTexture = null
static var _boot_left: ImageTexture = null
static var _boot_right: ImageTexture = null
static var _made_for: MarksConfig = null


## The pictures for `cfg`, painted the first time (or when the config changes).
static func ensure(cfg: MarksConfig) -> void:
	if _made_for == cfg and _stain != null:
		return
	_made_for = cfg
	var noise := FastNoiseLite.new()
	noise.seed = SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	var stain := stain_image(cfg, noise)
	_stain = _texture(stain[0])
	_stain_orm = _texture(stain[1])
	_tread = _texture(tread_image(cfg, noise))
	var left := print_image(cfg, noise)
	var right := left.duplicate() as Image
	right.flip_x()
	_boot_left = _texture(left)
	_boot_right = _texture(right)


## A picture as a texture with its mipmaps: the decals' atlas draws a far mark from its smaller levels, so without them
## a mark only a few pixels on screen (a boot print a few metres off) fades to nothing.
static func _texture(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func stain() -> Texture2D:
	return _stain


static func stain_orm() -> Texture2D:
	return _stain_orm


static func tread() -> Texture2D:
	return _tread


static func boot(left: bool) -> Texture2D:
	return _boot_left if left else _boot_right


## An oil stain, its picture and its ORM (occlusion, roughness, metal): a ragged pool, darker and wetter in the middle,
## with a few splashes round it.
static func stain_image(cfg: MarksConfig, noise: FastNoiseLite) -> Array[Image]:
	var n := cfg.stain_pixels
	var colour := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var orm := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	var splashes: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in SPLASHES:
		var angle := rng.randf() * TAU
		var reach := rng.randf_range(0.55, 0.85)
		splashes.append(Vector3(cos(angle) * reach, sin(angle) * reach, SPLASH_SIZE * rng.randf_range(0.5, 1.2)))
	for py in n:
		for px in n:
			var p := Vector2(px + 0.5, py + 0.5) / n * 2.0 - Vector2.ONE
			var edge := 0.5 * (1.0 + EDGE_RAGGED * noise.get_noise_2d(p.x * EDGE_CELLS, p.y * EDGE_CELLS))
			var r := p.length() / edge
			var a := 1.0 - smoothstep(1.0 - STAIN_SOFT, 1.0, r)
			for s in splashes:
				var d := (p - Vector2(s.x, s.y)).length() / s.z
				a = maxf(a, 1.0 - smoothstep(0.6, 1.0, d))
			var spot := 0.5 + 0.5 * noise.get_noise_2d(p.x * SPOT_CELLS + 31.0, p.y * SPOT_CELLS)
			var core := clampf(1.0 - r, 0.0, 1.0)
			var shade := 1.0 - STAIN_CORE * core - 0.1 * spot
			colour.set_pixel(px, py, Color(shade, shade, shade, a * (0.75 + 0.25 * core)))
			orm.set_pixel(px, py, Color(1.0, lerpf(1.0, cfg.oil_roughness, core * 0.6 + 0.4), 0.0))
	return [colour, orm]


## One tyre's tread, its tile along the track (the picture repeats top to bottom, so pieces laid end to end meet):
## slanted lugs across it, the rubber patchy.
static func tread_image(cfg: MarksConfig, noise: FastNoiseLite) -> Image:
	var size := cfg.tread_pixels
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for py in size.y:
		var v := (py + 0.5) / size.y
		for px in size.x:
			var u := (px + 0.5) / size.x
			var lug := fposmod((v + absf(u - 0.5) * LUG_SLANT) * LUGS, 1.0)
			var on := 1.0 if lug < LUG_FILL else 0.35
			# the noise round a loop, so the tile's top and bottom match
			var ring := Vector2(cos(v * TAU), sin(v * TAU)) * 2.0
			var patch := 0.5 + 0.5 * noise.get_noise_3d(u * 3.0, ring.x, ring.y)
			var side := 1.0 - smoothstep(0.4, 0.5, absf(u - 0.5))
			var a := on * side * clampf(1.0 - TREAD_PATCHY * patch, 0.0, 1.0)
			img.set_pixel(px, py, Color(1.0, 1.0, 1.0, a))
	return img


## A left boot's print, toe at the top: a forefoot and a heel with the arch between, laid with rows of lugs, its edges
## worn.
static func print_image(cfg: MarksConfig, noise: FastNoiseLite) -> Image:
	var size := cfg.print_pixels
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for py in size.y:
		var v := (py + 0.5) / size.y
		for px in size.x:
			var u := (px + 0.5) / size.x
			# the sole joins forefoot and heel along the left foot's outside (the picture's left); the arch's gap is
			# on its inside
			var fore := Vector2((u - 0.5) / FORE_RADIUS.x, (v - FORE_AT) / FORE_RADIUS.y)
			var heel := Vector2((u - 0.5) / HEEL_RADIUS.x, (v - HEEL_AT) / HEEL_RADIUS.y)
			var arch := (1.0 - smoothstep(0.12, 0.22, absf(u - 0.38))) if v > FORE_AT and v < HEEL_AT else 0.0
			var sole := maxf(maxf(1.0 - smoothstep(0.85, 1.0, fore.length()), 1.0 - smoothstep(0.85, 1.0,
					heel.length())), arch * 0.6)
			var row := fposmod(v * PRINT_ROWS, 1.0)
			var column := fposmod(u * PRINT_COLUMNS + (0.5 if int(v * PRINT_ROWS) % 2 == 1 else 0.0), 1.0)
			var lug := 1.0 if row > PRINT_GAP and column > PRINT_GAP * 0.5 else 0.75
			var worn := 0.5 + 0.5 * noise.get_noise_2d(u * 6.0 + 57.0, v * 14.0)
			img.set_pixel(px, py, Color(1.0, 1.0, 1.0, sole * lug * (0.8 + 0.2 * worn)))
	return img
