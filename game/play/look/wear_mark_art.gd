class_name WearMarkArt
extends RefCounted
## The worn marks' pictures (WM1, WearMarks), painted once at load from noise, never per frame: an oil stain (its
## colour and its shine), a tyre's track (a smooth rubber smear on a hard floor, a lugged muddy tread outdoors, each
## with its ends faded in and out). White, so each decal's modulate gives the palette's colour; alpha is the mark. Cached: every match shares the one set.

## Which piece of a pair of tracks a tread's picture is for: one along the middle, the first (faded in), the last
## (faded out), or a pair short enough to be one piece (faded at both ends).
enum Piece { MIDDLE, FIRST, LAST, ONLY }

## The noise's seeds and scales (cells across a picture), and how ragged a stain's edge is (of its radius).
const SEED := 5021
const EDGE_CELLS := 3.0
const SPOT_CELLS := 9.0
const EDGE_RAGGED := 0.35
## Where in the noise each picture reads (an offset, so two pictures never share a pattern).
const SPOT_OFFSET := 31.0
const FLECK_OFFSET := 57.0
## A stain: its edge's softness (of its radius), how much darker its middle is and how much its spots shade it, how
## much of its colour is there at its edge (the rest grows to its middle), and its splashes' count, reach (of its
## radius), size and spread of sizes, and their edge's softness (of a splash's radius).
const STAIN_SOFT := 0.12
const STAIN_CORE := 0.25
const STAIN_SPOTS := 0.1
const STAIN_EDGE_ALPHA := 0.75
const SPLASHES := 7
const SPLASH_REACH := Vector2(0.55, 0.85)
const SPLASH_SIZE := 0.07
const SPLASH_SPREAD := Vector2(0.5, 1.2)
const SPLASH_SOFT := 0.6
## How much of its middle's wetness an oil stain's shine takes at its edge (the rest grows to its middle).
const STAIN_SHINE_EDGE := 0.4
## Every tread: its edges' softness (of its half width), the noise's cells across it and round its loop, and how much
## of a track is left at its patchiest.
const TREAD_SOFT := 0.2
const TREAD_CELLS := 3.0
const TREAD_LOOP := 2.0
const TREAD_PATCHY := 0.55
## A hard floor's rubber smear: the streaks along it (cells across), how much they and the patches vary it, and how
## solid it is at its least.
const SMEAR_STREAKS := 14.0
const SMEAR_STREAKY := 0.35
const SMEAR_FLOOR := 0.45
## How much of a muddy tread's patchiness a smear takes (rubber on a hard floor wears more evenly).
const SMEAR_PATCHY := 0.5
## The shortest lug pitch or piece (m) the pictures are worked out over, whatever the config says, so a 0 can't divide.
const SHORTEST := 0.01
## A muddy tread: its lugs' slant (of the width), their fill (of a lug's pitch) and how much each one's fill varies at
## random, how much mud lies between them, and the rows of mud flecks it throws off its edges.
const LUG_SLANT := 0.35
const LUG_FILL := 0.5
const LUG_JITTER := 0.15
const LUG_GAP_MUD := 0.2
const MUD_CLUMPS := 6.0

static var _stain: ImageTexture = null
static var _stain_orm: ImageTexture = null
## The treads by kind (false a rubber smear, true muddy), then by Piece.
static var _treads: Dictionary[bool, Array] = {}
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
	_treads.clear()
	for mud: bool in [false, true]:
		var tile := tread_image(cfg, noise, mud)
		var textures: Array[ImageTexture] = []
		for piece: Piece in [Piece.MIDDLE, Piece.FIRST, Piece.LAST, Piece.ONLY]:
			textures.append(_texture(faded(cfg, tile, piece)))
		_treads[mud] = textures


## A picture as a texture with its mipmaps: the decals' atlas draws a far mark from its smaller levels, so without them
## a mark only a few pixels on screen (a tread a few metres off) fades to nothing.
static func _texture(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func stain() -> Texture2D:
	return _stain


static func stain_orm() -> Texture2D:
	return _stain_orm


## A tyre's track for one `piece` of a pair: muddy (a lugged tread) or not (a hard floor's rubber smear).
static func tread(mud: bool, piece: Piece) -> Texture2D:
	return _treads[mud][piece]


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
		var reach := rng.randf_range(SPLASH_REACH.x, SPLASH_REACH.y)
		splashes.append(Vector3(cos(angle) * reach, sin(angle) * reach,
				SPLASH_SIZE * rng.randf_range(SPLASH_SPREAD.x, SPLASH_SPREAD.y)))
	for py in n:
		for px in n:
			var p := Vector2(px + 0.5, py + 0.5) / n * 2.0 - Vector2.ONE
			var edge := 0.5 * (1.0 + EDGE_RAGGED * noise.get_noise_2d(p.x * EDGE_CELLS, p.y * EDGE_CELLS))
			var r := p.length() / edge
			var a := 1.0 - smoothstep(1.0 - STAIN_SOFT, 1.0, r)
			for s in splashes:
				var d := (p - Vector2(s.x, s.y)).length() / s.z
				a = maxf(a, 1.0 - smoothstep(SPLASH_SOFT, 1.0, d))
			var spot := 0.5 + 0.5 * noise.get_noise_2d(p.x * SPOT_CELLS + SPOT_OFFSET, p.y * SPOT_CELLS)
			var core := clampf(1.0 - r, 0.0, 1.0)
			var shade := 1.0 - STAIN_CORE * core - STAIN_SPOTS * spot
			colour.set_pixel(px, py, Color(shade, shade, shade, a * lerpf(STAIN_EDGE_ALPHA, 1.0, core)))
			var wet := lerpf(STAIN_SHINE_EDGE, 1.0, core)
			orm.set_pixel(px, py, Color(1.0, lerpf(1.0, cfg.oil_roughness, wet), 0.0))
	return [colour, orm]


## One tyre's track along a piece (the picture repeats top to bottom, so pieces laid end to end meet; the top is the
## way the wheel rolled): on a hard floor a smooth smear of rubber, streaked along it; muddy, slanted lugs at a real
## tyre's pitch (`MarksConfig.lug_pitch`), each a little different, with mud between them and flecks off its edges.
static func tread_image(cfg: MarksConfig, noise: FastNoiseLite, mud: bool) -> Image:
	var size := cfg.tread_pixels if mud else cfg.smear_pixels
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var lugs := maxi(1, roundi(cfg.track_piece / maxf(cfg.lug_pitch, SHORTEST)))
	var fills := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in lugs:
		fills.append(LUG_FILL + rng.randf_range(-LUG_JITTER, LUG_JITTER))
	for py in size.y:
		var v := (py + 0.5) / size.y
		# the noise round a loop, so the tile's top and bottom match
		var ring := Vector2(cos(v * TAU), sin(v * TAU)) * TREAD_LOOP
		for px in size.x:
			var u := (px + 0.5) / size.x
			var across := absf(u - 0.5) * 2.0
			var patch := 0.5 + 0.5 * noise.get_noise_3d(u * TREAD_CELLS, ring.x, ring.y)
			var a: float
			if mud:
				var at := (v + absf(u - 0.5) * LUG_SLANT) * lugs
				var lug := fposmod(at, 1.0)
				var on := 1.0 if lug < fills[posmod(floori(at), lugs)] else LUG_GAP_MUD
				var fleck := 0.5 + 0.5 * noise.get_noise_3d(u * MUD_CLUMPS + FLECK_OFFSET, ring.x * MUD_CLUMPS,
						ring.y * MUD_CLUMPS)
				var side := 1.0 - smoothstep(1.0 - TREAD_SOFT * (1.0 + fleck), 1.0, across)
				a = on * side * clampf(1.0 - TREAD_PATCHY * patch, 0.0, 1.0)
			else:
				var streak := 0.5 + 0.5 * noise.get_noise_3d(u * SMEAR_STREAKS + SPOT_OFFSET, ring.x, ring.y)
				var side := 1.0 - smoothstep(1.0 - TREAD_SOFT, 1.0, across)
				a = side * maxf(SMEAR_FLOOR, 1.0 - SMEAR_STREAKY * streak - TREAD_PATCHY * SMEAR_PATCHY * patch)
			img.set_pixel(px, py, Color(1.0, 1.0, 1.0, a))
	return img


## `tile` faded for its `piece` of a pair: the first piece fades in from its start (the picture's bottom, where the
## wheel rolled from) over `MarksConfig.track_fade` metres, the last fades out to its end (the top), the only piece
## both, a middle piece not at all.
static func faded(cfg: MarksConfig, tile: Image, piece: Piece) -> Image:
	var img := tile.duplicate() as Image
	if piece == Piece.MIDDLE:
		return img
	var share := clampf(cfg.track_fade / maxf(cfg.track_piece, SHORTEST), 0.0, 1.0)
	var w := img.get_width()
	var h := img.get_height()
	# the alpha bytes straight (RGBA8, four a pixel), not a pixel at a time: this runs once a piece kind at load
	var bytes := img.get_data()
	for py in h:
		var v := (py + 0.5) / h
		var keep := 1.0
		if piece == Piece.FIRST or piece == Piece.ONLY:
			keep *= smoothstep(0.0, share, 1.0 - v)
		if piece == Piece.LAST or piece == Piece.ONLY:
			keep *= smoothstep(0.0, share, v)
		if keep >= 1.0:
			continue
		for px in w:
			var at := (py * w + px) * 4 + 3
			bytes[at] = roundi(bytes[at] * keep)
	img.set_data(w, h, false, Image.FORMAT_RGBA8, bytes)
	return img
