class_name WearMarks
extends Node3D
## A field's worn marks on its floor (WM1; the map's `dressing.marks`, WearMark): each oil stain one decal, each pair
## of tyre tracks a decal a wheel for every straight piece it is laid in, each boot trail a decal a print, left and
## right in turn. They add to the floor's own wear (SL1, SL2), never repeat it. Shown with Graphics › Wear marks
## (`set_on`; Medium and up, Forward+ and Mobile, as Compatibility draws no decals). Scenery: no collider, no nav cell.

## The shortest piece or stride (m) a mark is laid in, whatever the config says, so a 0 can't divide.
const SHORTEST := 0.05

var _decals: Array[Decal] = []


## The marks of `map` in `cfg`'s look, coloured from `look`'s palette, or null for a map naming none. Seeded by the
## map's dressing seed, so every match lays them the same. Add it to the tree beside the level.
static func build(map: MapData, cfg: MarksConfig, look: LookConfig) -> WearMarks:
	if map.marks.is_empty() or cfg == null or look == null:
		return null
	WearMarkArt.ensure(cfg)
	var marks := WearMarks.new()
	marks.name = "WearMarks"
	var rng := RandomNumberGenerator.new()
	rng.seed = map.dressing_seed
	for m in map.marks:
		match m.kind:
			WearMark.OIL:
				marks._stain(map, cfg, look, m, rng)
			WearMark.TYRES:
				marks._tracks(map, cfg, look, m)
			WearMark.BOOTS:
				marks._trail(map, cfg, look, m, rng)
	return marks


## Every decal, for the tests and the budget census.
func decals() -> Array[Decal]:
	return _decals


func set_on(on: bool) -> void:
	if visible != on:
		visible = on


## The floor's height at `at` (x, z): the mark's own, or the map's ground there, or 0 on a map with none.
static func floor_at(map: MapData, m: WearMark, at: Vector2) -> float:
	if not is_nan(m.y):
		return m.y
	return map.terrain.height_at(at.x, at.y) if map.terrain != null else 0.0


func _stain(map: MapData, cfg: MarksConfig, look: LookConfig, m: WearMark, rng: RandomNumberGenerator) -> void:
	var stretch := 1.0 + rng.randf() * cfg.stain_stretch
	var d := _decal(cfg, Vector3(m.length * stretch, cfg.box_height, m.length / stretch))
	d.texture_albedo = WearMarkArt.stain()
	d.texture_orm = WearMarkArt.stain_orm()
	d.modulate = _paint(look, cfg.oil_colour, cfg.oil_opacity)
	_place(d, map, m, m.at, deg_to_rad(m.yaw) + rng.randf() * TAU)


func _tracks(map: MapData, cfg: MarksConfig, look: LookConfig, m: WearMark) -> void:
	var pieces := maxi(1, ceili(m.length / maxf(cfg.track_piece, SHORTEST)))
	var points := m.path(pieces)
	var paint := _paint(look, cfg.mud_colour if m.mud else cfg.rubber_colour, cfg.rubber_opacity)
	for i in pieces:
		var from := points[i]
		var to := points[i + 1]
		var along := to - from
		var heading := atan2(along.x, -along.y)
		var across := Vector2(cos(heading), sin(heading)) * cfg.track_gauge * 0.5
		for wheel: float in [-1.0, 1.0]:
			var d := _decal(cfg, Vector3(cfg.tread_width, cfg.box_height, along.length()))
			d.texture_albedo = WearMarkArt.tread()
			d.modulate = paint
			_place(d, map, m, (from + to) * 0.5 + across * wheel, heading)


func _trail(map: MapData, cfg: MarksConfig, look: LookConfig, m: WearMark, rng: RandomNumberGenerator) -> void:
	var steps := maxi(1, floori(m.length / maxf(cfg.stride, SHORTEST)))
	var points := m.path(steps)
	var paint := _paint(look, cfg.mud_colour if m.mud else cfg.dust_colour, cfg.boot_opacity)
	for i in points.size():
		var ahead := points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]
		var heading := atan2(ahead.x, -ahead.y) if ahead.length() > 0.0 else deg_to_rad(m.yaw)
		var left := i % 2 == 0
		var side := Vector2(cos(heading), sin(heading)) * cfg.feet_gap * 0.5 * (-1.0 if left else 1.0)
		var d := _decal(cfg, Vector3(cfg.print_width, cfg.box_height, cfg.print_length))
		d.texture_albedo = WearMarkArt.boot(left)
		# a trail fades as the boots wipe clean
		d.modulate = Color(paint, paint.a * (1.0 - 0.5 * float(i) / points.size()))
		_place(d, map, m, points[i] + side, heading + rng.randf_range(-cfg.print_wobble, cfg.print_wobble))


func _decal(cfg: MarksConfig, size: Vector3) -> Decal:
	var d := Decal.new()
	d.size = size
	d.normal_fade = cfg.normal_fade
	d.distance_fade_enabled = true
	d.distance_fade_begin = cfg.fade_from
	d.distance_fade_length = cfg.fade_over
	d.upper_fade = 0.0
	d.lower_fade = 0.0
	add_child(d)
	_decals.append(d)
	return d


## Stands `d` on the floor at `at` (x, z), turned to `heading` (rad, 0 towards -z, turning towards +x).
func _place(d: Decal, map: MapData, m: WearMark, at: Vector2, heading: float) -> void:
	d.position = Vector3(at.x, floor_at(map, m, at), at.y)
	d.rotation = Vector3(0.0, -heading, 0.0)


static func _paint(look: LookConfig, name: StringName, opacity: float) -> Color:
	var c := look.colour(name)
	c.a = opacity
	return c
