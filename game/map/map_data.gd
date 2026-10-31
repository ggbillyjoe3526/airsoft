class_name MapData
extends RefCounted
## A map's layout as plain data, read from data/maps/<id>.json (the browser game's map/mapTypes.ts, exported by the
## salvage): its blocks, its sloping ground (`terrain`, with what its ground is made of), its two ends, its kill height,
## its named areas and storeys, its ambience, its skyline, how it is lit (its presets and pools of light), its bushes
## (`foliage`) and, on the range, its targets. MapLevel builds the greybox and the Jolt colliders from it and hands its
## bushes to the simulation's WorldQuery; the simulation reads its ends and targets; SkylineView draws its skyline,
## LightPools its lights and BushView its bushes. A file that
## can't be played (neither a floor block nor terrain, malformed terrain, a missing end, too few spawns for a team) is
## refused with the reasons in `problems`; a target that can't stand, a malformed area, skyline piece, ground patch or
## bush or an unknown ambience, lighting preset or light is left out with a warning (`warnings`).

const DIR := "res://data/maps/"
## How far apart (m) two blocks' faces may be and still meet, for rounding in the file.
const PART_SLACK := 0.001

## Which way a ramp's top slopes up.
enum Rise { NONE, POS_X, NEG_X, POS_Z, NEG_Z }

const RISES: Dictionary[String, Rise] = {"+x": Rise.POS_X, "-x": Rise.NEG_X, "+z": Rise.POS_Z, "-z": Rise.NEG_Z}
const SURFACES: Dictionary[String, RayHit.Surface] = {
	"concrete": RayHit.Surface.CONCRETE, "metal": RayHit.Surface.METAL, "wood": RayHit.Surface.WOOD,
	"earth": RayHit.Surface.EARTH, "gravel": RayHit.Surface.GRAVEL, "grass": RayHit.Surface.GRASS,
	"leaves": RayHit.Surface.LEAVES,
}


## One axis-aligned block: a box, or a ramp (a wedge whose top rises along `rise` from its bottom to its top).
class Block:
	extends RefCounted
	var kind: StringName = &""
	var center: Vector3 = Vector3.ZERO
	var size: Vector3 = Vector3.ONE
	var rise: Rise = Rise.NONE
	var surface: RayHit.Surface = RayHit.Surface.CONCRETE
	## Which piece of its kind it is (0 first, in file order): blocks that build one thing, such as a container's walls
	## under its roof, share their piece (MapStyle draws a piece in one colour).
	var piece: int = 0


## One pool of light on a night field (`lights` in the file; the browser's MapLight): a camp fire, a lantern, or a lamp
## of no kind in its own colour (sRGB), lighting the ground within `radius` m of the point under it.
class Light:
	extends RefCounted
	var position: Vector3 = Vector3.ZERO
	var radius: float = 1.0
	var colour: Color = Color.WHITE
	var kind: StringName = &""


## A puddle or a patch of mud on the ground (`dressing.puddles` in the file; the browser's DressingPuddle): `size` m
## (x across, z deep) round `at` (x, z). Look only (WoodsView).
class Puddle:
	extends RefCounted
	var at: Vector2 = Vector2.ZERO
	var size: Vector2 = Vector2.ONE
	var mud: bool = false


## One hinged door (DO1; `doors` in the file): its two leaves' box when shut, hung across a gap in a wall on the wall's
## face `side` (1: the +x or +z face, along the box's thin axis; -1 the other), and whether it starts each round shut.
## Open, it is no collider, its leaves folded back flat against that face (DoorState, WorldQuery.add_door, DoorView).
class Door:
	extends RefCounted
	var center: Vector3 = Vector3.ZERO
	var size: Vector3 = Vector3.ONE
	var side: int = 1
	var shut: bool = false


## The kinds a light may name (a light naming none is a lamp in its own colour).
const LIGHT_KINDS: Array[StringName] = [&"fire", &"lantern"]

var id: String = ""
var display_name: String = ""
var blocks: Array[Block] = []
## The ground that rises and falls (`terrain` in the file, its surfaces from `ground`), or null on a map whose ground is
## its floor blocks.
var terrain: TerrainGrid = null
## Its bushes (`foliage` in the file: upright ellipsoids of leaves on the ground, WL5): no collider and no nav cell, only
## leaves that hide and stop BBs (Foliage). Empty on a map with none.
var foliage: Foliage = Foliage.new()
## The map's two ends (spawns and dead zones), end 0 first.
var ends: Array[MapEnd] = []
var kill_y: float = -10.0
## Attack / Defend's flagpoles by end 1, flag A first (`flags` in the file, a list of spots, AB1; or one `flag`); the
## attackers win a round by raising either. `pole` is flag A's; has_pole false on a map without one.
var poles: PackedVector3Array = PackedVector3Array()
var pole: Vector3 = Vector3.ZERO
var has_pole: bool = false
## Elimination's overtime flag, its foot near the middle (`overtimeFlag` in the file, OT1); has_overtime_flag false on a
## map without one (a clock run out level is then a draw at once).
var overtime_flag: Vector3 = Vector3.ZERO
var has_overtime_flag: bool = false
## The lanes bots walk (walkable points from end 0's side to end 1's), in the file's order.
var lanes: Array[PackedVector3Array] = []
## The practice range's targets (`targets` in the file: config/range.ts rangeLayout()'s specs), in the file's order;
## empty on a field.
var targets: Array[RangeTarget.Spec] = []
## The named areas (MapAreas.area_at), in the file's order: the first that holds a point names it. None on the range.
var areas: Array[MapAreas.Area] = []
## The field's sound (`ambience` in the file): one of AmbienceConfig.IDS; a map naming none plays the default (the
## yard), and one naming an unknown id plays it too, with a warning.
var ambience: StringName = AmbienceConfig.DEFAULT_ID
## The bake of its light (`bakedLight.file` in the file: BakeConfig.path_for), or empty for a map drawn without one.
var baked_light_file: String = ""
## The skyline round the field (`dressing.skyline` in the file, its known kinds): scenery out of reach, drawn by
## SkylineView; empty on a map without one.
var skyline: Array[SkylinePiece] = []
## The dust feet kick up on it (`dressing.kickedDust` in the file: its tint, sRGB, and its size, 1 the usual;
## KickedDust): white at the usual size on a map naming none.
var kicked_dust_tint: Color = Color.WHITE
var kicked_dust_scale: float = 1.0
## Its site dress (DD1, `dressing.site`: SiteDressing), drawn by SiteLook and SiteDress instead of the greybox
## colours; null on a map drawn as greybox.
var site: SiteDressing = null
## A wood's dressing (WL4; `dressing` in the file, the browser's MapDressing; WoodsView draws it, nothing else reads
## it): its seed; the share of squares by a foot with a leaf drift and of slots along a foot with a fallen branch,
## twigs or a log (`woods`); the moss on the logs' tops, its colour and the share of logs (`moss`); the puddles; the
## fireflies over the field at night (`fireflies.count`) and the tint of the motes in the air (`motes.tint`, sRGB;
## has_motes false without one); the grass tufts' height (`grass.height`, m) and the trees in the wood beyond the fence
## (`forest.trees`). Each 0 or empty on a map naming none; a malformed one is left out with a warning.
var dressing_seed: int = 0
var leaf_drifts: float = 0.0
var fallen: float = 0.0
var moss: Color = Color.WHITE
var moss_share: float = 0.0
var puddles: Array[Puddle] = []
var fireflies: int = 0
var motes_tint: Color = Color.WHITE
var has_motes: bool = false
var grass_height: float = 0.0
var forest_trees: int = 0
## `night` in the file (the browser's map.night): whether it says it plays at night, held to its first preset by
## field.night. The night systems read the playing preset's flag (LightingConfig.night), never this.
var night: bool = false
## The lighting presets it offers (`lighting.presets`: LightingConfig.PRESETS), its default first; day alone for a map
## naming none.
var lighting_presets: Array[StringName] = [LightingConfig.DAY]
## `lighting.moonOver`: the point (x, z) the moon hangs over; has_moon_over false on a map naming none.
var moon_over: Vector2 = Vector2.ZERO
var has_moon_over: bool = false
## `lighting.overrides`: its tweaks of a preset, by preset id.
var lighting_overrides: Dictionary[StringName, LightingConfig.Override] = {}
## Its pools of light (`lights`), drawn under a night preset, in the file's order.
var lights: Array[Light] = []
## How far its bots make someone out (m, `botSight` in the file: BotConfig.for_map), for a hall with longer views than
## the default; 0 on a map naming none, where BotConfig.view_distance holds.
var bot_sight: float = 0.0
## An indoor field's roof (`roof` in the file, DR1): its underside's height (m) over the floor, 0 on a field open to
## the sky, and its lamp panels (x, z), drawn by RoofView. A BB stops on it (MapLevel's ceiling).
var roof_height: float = 0.0
var roof_lamps: PackedVector2Array = PackedVector2Array()
## The hinged doors (DO1), in file order: the simulation, the level and the view number them alike.
var doors: Array[Door] = []
## The floor heights (m) of a map built in storeys, lowest first (such as 0, 3 and 6); empty on a map of one.
var storeys: PackedFloat64Array = PackedFloat64Array()
## Why the file was refused; empty when it loaded.
var problems: Array[String] = []
## What in the file was left out or kept at its default (a target that can't stand, a number that won't read), each
## also pushed as a warning; the map still loads.
var warnings: Array[String] = []


## The map `map_id` from data/maps/, every team of `team_size` given a spawn of its own; check `problems`.
static func load_map(map_id: String, style: MapStyle, team_size: int) -> MapData:
	var path := DIR + map_id + ".json"
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		var refused := MapData.new()
		refused.id = map_id
		refused.problems.append("%s could not be read (%s)" % [path, error_string(FileAccess.get_open_error())])
		return refused
	var m := parse(text, style, team_size)
	m.id = map_id
	return m


## A map from its JSON text.
static func parse(text: String, style: MapStyle, team_size: int) -> MapData:
	var m := MapData.new()
	var json := JSON.new()
	if json.parse(text) != OK:
		m.problems.append("not JSON: %s at line %d" % [json.get_error_message(), json.get_error_line()])
		return m
	var root: Variant = json.data
	if not root is Dictionary:
		m.problems.append("not a map: the file holds no object")
		return m
	var d: Dictionary = root
	m.display_name = str(d.get("name", ""))
	m.kill_y = float(d.get("killY", m.kill_y))
	if d.has("terrain"):
		m.terrain = TerrainGrid.read(d["terrain"], m.problems)
	m._read_blocks(d.get("blocks"), style)
	if m.terrain != null:
		m._paint_ground(d.get("ground"), style)
	m._read_ends(d.get("spawns"), d.get("deadZones"), team_size)
	m._read_lanes(d.get("lanes"))
	m._read_targets(d.get("targets"))
	m.areas = MapAreas.read(d.get("areas"), m.warnings)
	m._read_storeys(d.get("storeys"))
	m._read_ambience(d.get("ambience"))
	m._read_baked_light(d.get("bakedLight"))
	m.night = d.get("night", false) is bool and bool(d.get("night", false))
	m._read_lighting(d.get("lighting"))
	m._read_lights(d.get("lights"))
	m._read_roof(d.get("roof"))
	m._read_doors(d.get("doors"))
	m.bot_sight = maxf(0.0, _number(d.get("botSight"), 0.0))
	m._read_foliage(d.get("foliage"))
	m.skyline = SkylinePiece.read(d.get("dressing"), m.warnings)
	m._read_kicked_dust(d.get("dressing"))
	m.site = SiteDressing.read(d.get("dressing"), m.warnings)
	m._read_woods(d.get("dressing"), style)
	m._read_poles(d.get("flags"), d.get("flag"))
	m.has_overtime_flag = _spot(d.get("overtimeFlag"), "overtimeFlag", m.warnings)
	m.overtime_flag = _vec(d.get("overtimeFlag")) if m.has_overtime_flag else Vector3.ZERO
	for w in m.warnings:
		push_warning("MapData: " + w)
	return m


func ok() -> bool:
	return problems.is_empty()


## The preset it plays: Dev › Time of day's `forced` when it names one (any preset, on any map), else the match's `pick`
## when it offers that one, else its first.
func preset_played(pick: StringName, forced: StringName = &"") -> StringName:
	if LightingConfig.PRESETS.has(forced):
		return forced
	if lighting_presets.has(pick):
		return pick
	return lighting_presets[0]


## Whether the Match screen offers it by Day or Night: it offers two presets or more.
func offers_choice() -> bool:
	return lighting_presets.size() > 1


## The presets `map_id`'s file offers, its default first (day alone when it names none or can't be read), without
## building the map (the Match page's Day / Night row).
static func presets_in(map_id: String) -> Array[StringName]:
	var m := MapData.new()
	var text := FileAccess.get_file_as_string(DIR + map_id + ".json")
	if text.is_empty():
		return m.lighting_presets # no such file: a map taken out of the game, picked before the page falls back
	var root: Variant = JSON.parse_string(text)
	if root is Dictionary:
		m._read_lighting((root as Dictionary).get("lighting"))
	return m.lighting_presets


## The middle of its blocks (x, z), where the skyline faces and fades from and the moon is turned from.
func middle() -> Vector2:
	var area := footprint()
	return (area.position + area.end) * 0.5


## Its blocks' footprint (x, z), where a roof's ceiling hangs; an empty rect at the origin without a block.
func footprint() -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for b in blocks:
		lo = lo.min(Vector2(b.center.x - b.size.x * 0.5, b.center.z - b.size.z * 0.5))
		hi = hi.max(Vector2(b.center.x + b.size.x * 0.5, b.center.z + b.size.z * 0.5))
	return Rect2(lo, hi - lo) if lo.x <= hi.x else Rect2()


## The top of the highest floor or ramp or the terrain under (x, z), or -INF off them all (for tools and tests).
func floor_top(x: float, z: float) -> float:
	var best := -INF
	if terrain != null:
		var ground := terrain.height_at(x, z)
		if not is_nan(ground):
			best = ground
	for b in blocks:
		if b.kind != &"floor" and b.kind != &"ramp":
			continue
		var lo := b.center - b.size * 0.5
		var hi := b.center + b.size * 0.5
		if x < lo.x or x > hi.x or z < lo.z or z > hi.z:
			continue
		best = maxf(best, ramp_top(b, x, z) if b.rise != Rise.NONE else hi.y)
	return best


## The height of ramp `b`'s top at (x, z) inside its footprint.
static func ramp_top(b: Block, x: float, z: float) -> float:
	var lo := b.center - b.size * 0.5
	var share := 0.0
	match b.rise:
		Rise.POS_X:
			share = (x - lo.x) / b.size.x
		Rise.NEG_X:
			share = 1.0 - (x - lo.x) / b.size.x
		Rise.POS_Z:
			share = (z - lo.z) / b.size.z
		Rise.NEG_Z:
			share = 1.0 - (z - lo.z) / b.size.z
	return lo.y + clampf(share, 0.0, 1.0) * b.size.y


func _read_blocks(list: Variant, style: MapStyle) -> void:
	if not list is Array:
		problems.append("no blocks")
		return
	var floors := 0
	for i in (list as Array).size():
		var raw: Variant = (list as Array)[i]
		if not raw is Dictionary:
			problems.append("block %d is not an object" % i)
			continue
		var bd: Dictionary = raw
		var b := Block.new()
		b.kind = StringName(str(bd.get("kind", "")))
		b.center = _vec(bd.get("center"))
		b.size = _vec(bd.get("size"))
		if not (b.size.x > 0.0 and b.size.y > 0.0 and b.size.z > 0.0):
			problems.append("block %d (%s) has no size" % [i, b.kind])
			continue
		if bd.has("rise"):
			b.rise = RISES.get(str(bd["rise"]), Rise.NONE)
			if b.rise == Rise.NONE:
				problems.append("block %d's rise %s is not +x, -x, +z or -z" % [i, bd["rise"]])
		b.surface = SURFACES.get(str(bd["surface"]), style.surface_of(b.kind)) if bd.has("surface") \
				else style.surface_of(b.kind)
		if b.kind == &"floor":
			floors += 1
		blocks.append(b)
	if floors == 0 and terrain == null:
		problems.append("no floor")
	_number_pieces()


## Numbers each block's piece within its kind in file order; a block that is part of another (`_part_of`) takes the
## piece of the first such block in the file. Only blocks of its kind with a larger footprint can hold it, so each kind
## is sorted once, largest footprint first, and a block tries only those ahead of it.
func _number_pieces() -> void:
	var n := blocks.size()
	var whole := PackedInt32Array()
	whole.resize(n)
	var area := PackedFloat64Array()
	area.resize(n)
	var kind_list: Dictionary[StringName, int] = {}
	var lists: Array[Array] = []
	for i in n:
		whole[i] = i
		area[i] = blocks[i].size.x * blocks[i].size.z
		var k := blocks[i].kind
		if not kind_list.has(k):
			kind_list[k] = lists.size()
			lists.append([])
		lists[kind_list[k]].append(i)
	for list: Array in lists:
		list.sort_custom(func(x: int, y: int) -> bool: return area[x] > area[y])
		for i: int in list:
			var first := n
			for j: int in list:
				if area[j] <= area[i]:
					break
				if j < first and _part_of(blocks[i], blocks[j]):
					first = j
			if first < n:
				whole[i] = first
	var count: Dictionary[StringName, int] = {}
	var piece_of: Dictionary[int, int] = {}
	for i in blocks.size():
		var top := i
		while whole[top] != top:
			top = whole[top]
		if not piece_of.has(top):
			var next: int = count.get(blocks[i].kind, 0)
			piece_of[top] = next
			count[blocks[i].kind] = next + 1
		blocks[i].piece = piece_of[top]


## Whether `a` is part of `b`: the same kind, under b's larger footprint and no higher than its top (a container's
## walls and sills under its roof). A larger footprint each step up, so no block is part of itself.
static func _part_of(a: Block, b: Block) -> bool:
	if a.kind != b.kind or a.size.x * a.size.z >= b.size.x * b.size.z:
		return false
	var a_lo := a.center - a.size * 0.5
	var a_hi := a.center + a.size * 0.5
	var b_lo := b.center - b.size * 0.5
	var b_hi := b.center + b.size * 0.5
	return a_lo.x >= b_lo.x - PART_SLACK and a_hi.x <= b_hi.x + PART_SLACK and a_lo.z >= b_lo.z - PART_SLACK \
			and a_hi.z <= b_hi.z + PART_SLACK and a_hi.y <= b_hi.y + PART_SLACK


## The terrain's ground surfaces from `ground`, its under-trees surface by the trunks of the blocks of kind tree, on
## canopy squares from the blocks' corner (as the browser game's night field lays them).
func _paint_ground(ground: Variant, style: MapStyle) -> void:
	var trees := PackedVector2Array()
	var corner := Vector2(INF, INF)
	for b in blocks:
		corner = corner.min(Vector2(b.center.x - b.size.x * 0.5, b.center.z - b.size.z * 0.5))
		if b.kind == &"tree":
			trees.append(Vector2(b.center.x, b.center.z))
	if not is_finite(corner.x):
		corner = Vector2(terrain.min_x, terrain.min_z)
	terrain.paint(ground, SURFACES, trees, corner, style, warnings)


func _read_ends(spawns: Variant, dead_zones: Variant, team_size: int) -> void:
	if not spawns is Array or not dead_zones is Array or (spawns as Array).size() != 2 \
			or (dead_zones as Array).size() != 2:
		problems.append("a map needs two ends, each with spawns and a dead zone")
		return
	for e in 2:
		var end := MapEnd.new()
		end.spawns = _spots((spawns as Array)[e])
		end.dead_zone = _spots((dead_zones as Array)[e])
		# A team larger than its spawn line would double up on a spawn (Round.place_teams).
		if end.spawns.size() < team_size:
			problems.append("end %d has %d spawns for a team of %d" % [e, end.spawns.size(), team_size])
		if end.dead_zone.is_empty():
			problems.append("end %d has no dead zone" % e)
		ends.append(end)


## Lanes are optional: bots on a map without them hunt from the start.
func _read_lanes(list: Variant) -> void:
	if not list is Array:
		return
	for raw: Variant in list:
		if not raw is Array:
			problems.append("a lane is not a list of points")
			continue
		var lane := PackedVector3Array()
		for p: Variant in raw:
			lane.append(_vec(p))
		if lane.size() >= 2:
			lanes.append(lane)
		else:
			problems.append("a lane has fewer than two points")


## Targets are optional: a field has none.
func _read_targets(list: Variant) -> void:
	if list == null:
		return
	if not list is Array:
		warnings.append("targets is not a list")
	else:
		for i in (list as Array).size():
			var spec := RangeTarget.Spec.from_dict((list as Array)[i], i, warnings)
			if spec != null:
				targets.append(spec)


## Storeys are optional: a map of one floor has none. A height that isn't a number above the one before is left out.
func _read_storeys(list: Variant) -> void:
	if list == null:
		return
	if not list is Array:
		warnings.append("storeys is not a list")
		return
	for raw: Variant in list:
		if not (raw is float or raw is int) or (not storeys.is_empty() and float(raw) <= storeys[storeys.size() - 1]):
			warnings.append("storey %s is not a height above the one before; left out" % str(raw))
			continue
		storeys.append(float(raw))


func _read_ambience(raw: Variant) -> void:
	if raw == null:
		return
	var named := StringName(str(raw))
	if AmbienceConfig.known(named):
		ambience = named
	else:
		warnings.append("ambience %s is not one of %s; playing %s" % [raw, AmbienceConfig.IDS, ambience])


## Baked light is optional: a map naming no file is drawn without it.
func _read_baked_light(raw: Variant) -> void:
	if raw == null:
		return
	var file: Variant = (raw as Dictionary).get("file") if raw is Dictionary else null
	if file is String and (file as String).is_valid_filename():
		baked_light_file = file
	else:
		warnings.append("bakedLight is not {\"file\": a file name}; drawn without it")


## `lighting`: the presets offered (unknown ones left out; none known keeps day), moonOver and each preset's overrides.
func _read_lighting(raw: Variant) -> void:
	if raw == null:
		return
	var d: Dictionary = raw if raw is Dictionary else {}
	var offered: Array[StringName] = []
	var listed: Variant = d.get("presets")
	for p: Variant in (listed as Array if listed is Array else []):
		var preset := StringName(str(p))
		if LightingConfig.PRESETS.has(preset) and not offered.has(preset):
			offered.append(preset)
		else:
			warnings.append("lighting preset %s is not one of %s; left out" % [p, LightingConfig.PRESETS])
	if not offered.is_empty():
		lighting_presets = offered
	elif listed != null:
		warnings.append("lighting.presets names no preset; played by day")
	var over: Variant = d.get("moonOver")
	if over is Dictionary and (over as Dictionary).has("x") and (over as Dictionary).has("z"):
		moon_over = Vector2(float((over as Dictionary)["x"]), float((over as Dictionary)["z"]))
		has_moon_over = true
	var overrides: Variant = d.get("overrides")
	if overrides is Dictionary:
		for key: Variant in overrides:
			var preset := StringName(str(key))
			if LightingConfig.PRESETS.has(preset) and (overrides as Dictionary)[key] is Dictionary:
				lighting_overrides[preset] = _override((overrides as Dictionary)[key])
			else:
				warnings.append("lighting.overrides.%s is not a preset's tweaks; left out" % key)


static func _override(d: Dictionary) -> LightingConfig.Override:
	var o := LightingConfig.Override.new()
	var hemi: Dictionary = d.get("hemi") if d.get("hemi") is Dictionary else {}
	var key: Dictionary = d.get("key") if d.get("key") is Dictionary else {}
	var sky: Dictionary = d.get("sky") if d.get("sky") is Dictionary else {}
	var fog: Dictionary = d.get("fog") if d.get("fog") is Dictionary else {}
	var night_sky: Dictionary = d.get("nightSky") if d.get("nightSky") is Dictionary else {}
	o.fill = _number(hemi.get("intensity"), NAN)
	o.key = _number(key.get("intensity"), NAN)
	o.sun_elevation = _number(key.get("elevation"), NAN)
	o.sun_heading = _number(key.get("heading"), NAN)
	o.exposure_scale = _number(d.get("exposureScale"), NAN)
	o.sky_horizon = _colour(sky.get("horizon"))
	o.fog_colour = _colour(fog.get("colour"))
	o.fill_sky = _colour(hemi.get("sky"))
	o.fill_ground = _colour(hemi.get("ground"))
	o.stars = int(_number(night_sky.get("stars"), -1.0))
	return o


## `roof`: {height over 0, lamps: [{x, z}, ...]}; anything else is no roof, with a warning. A lamp without both numbers
## is left out, with a warning.
func _read_roof(raw: Variant) -> void:
	if raw == null:
		return
	var d: Dictionary = raw if raw is Dictionary else {}
	var height := _number(d.get("height"), 0.0)
	if height <= 0.0:
		warnings.append("roof is not {\"height\": metres over 0, \"lamps\": [...]}; no roof")
		return
	roof_height = height
	var lamps: Variant = d.get("lamps", [])
	for raw_lamp: Variant in (lamps as Array if lamps is Array else []):
		var at: Dictionary = raw_lamp if raw_lamp is Dictionary else {}
		var x := _number(at.get("x"), NAN)
		var z := _number(at.get("z"), NAN)
		if is_nan(x) or is_nan(z):
			warnings.append("a roof lamp is not {x, z}; left out")
			continue
		roof_lamps.append(Vector2(x, z))


## `doors`: each {center, size over 0 every way, side (optional: 1 or -1, 1), shut (optional, false)}; one that isn't
## is left out.
func _read_doors(raw: Variant) -> void:
	if raw == null:
		return
	for item: Variant in (raw as Array if raw is Array else []):
		var d: Dictionary = item if item is Dictionary else {}
		var door := Door.new()
		door.center = _vec(d.get("center"))
		door.size = _vec(d.get("size"))
		door.shut = d.get("shut", false) is bool and bool(d.get("shut", false))
		door.side = -1 if _number(d.get("side"), 1.0) < 0.0 else 1
		if not d.get("center") is Dictionary or not (door.size.x > 0.0 and door.size.y > 0.0 and door.size.z > 0.0):
			warnings.append("door %s is not {center, size over 0, shut}; left out" % JSON.stringify(item))
			continue
		doors.append(door)


## `lights`: each {position, radius over 0, colour, kind (optional: LIGHT_KINDS)}; one that isn't is left out.
func _read_lights(raw: Variant) -> void:
	if raw == null:
		return
	for item: Variant in (raw as Array if raw is Array else []):
		var d: Dictionary = item if item is Dictionary else {}
		var l := Light.new()
		l.position = _vec(d.get("position"))
		l.radius = _number(d.get("radius"), 0.0)
		l.colour = _colour(d.get("colour"))
		l.kind = StringName(str(d.get("kind", "")))
		if not d.get("position") is Dictionary or l.radius <= 0.0 or l.colour.a <= 0.0 or not (
				l.kind.is_empty() or LIGHT_KINDS.has(l.kind)):
			warnings.append("light %s is not {position, radius over 0, colour, kind: one of %s}; left out" % [
					JSON.stringify(item), LIGHT_KINDS])
			continue
		lights.append(l)


## `foliage`: each bush {x, y, z (its foot), radius over 0, height over 0}; one that isn't is left out.
func _read_foliage(raw: Variant) -> void:
	if raw == null:
		return
	if not raw is Array:
		warnings.append("foliage is not a list of bushes; none")
		return
	for item: Variant in raw:
		var d: Dictionary = item if item is Dictionary else {}
		var radius := _number(d.get("radius"), 0.0)
		var height := _number(d.get("height"), 0.0)
		var placed := _number(d.get("x"), NAN) + _number(d.get("y"), NAN) + _number(d.get("z"), NAN)
		if is_nan(placed) or radius <= 0.0 or height <= 0.0:
			warnings.append("bush %s is not {x, y, z, radius over 0, height over 0}; left out" % JSON.stringify(item))
			continue
		foliage.add(_vec(d), radius, height)


static func _number(raw: Variant, otherwise: float) -> float:
	return float(raw) if raw is float or raw is int else otherwise


## A colour as the file writes it (0xRRGGBB), or one with alpha 0 when it isn't one.
static func _colour(raw: Variant) -> Color:
	if not (raw is float or raw is int):
		return Color(0, 0, 0, 0)
	return Color.hex((int(raw) << 8) | 0xff)


func _read_kicked_dust(dressing: Variant) -> void:
	var raw: Variant = (dressing as Dictionary).get("kickedDust") if dressing is Dictionary else null
	if raw == null:
		return
	var d: Dictionary = raw if raw is Dictionary else {}
	var tint: Variant = d.get("tint")
	var size: Variant = d.get("scale", 1.0)
	if not (tint is float or tint is int) or not (size is float or size is int) or float(size) <= 0.0:
		warnings.append("dressing.kickedDust is not {\"tint\": a colour, \"scale\": a size over 0}; white at the usual"
				+ " size")
		return
	kicked_dust_tint = Color.hex((int(tint) << 8) | 0xff)
	kicked_dust_scale = float(size)


func _read_woods(dressing: Variant, style: MapStyle) -> void:
	if not dressing is Dictionary:
		return
	var d: Dictionary = dressing
	dressing_seed = int(_number(d.get("seed"), 0.0))
	var woods: Dictionary = _block_of(d, "woods", ["leaves", "fallen"])
	leaf_drifts = _share(woods.get("leaves", 0.0), "dressing.woods.leaves")
	fallen = _share(woods.get("fallen", 0.0), "dressing.woods.fallen")
	var moss_block: Dictionary = _block_of(d, "moss", ["colour", "share"])
	if not moss_block.is_empty():
		var c := _colour(moss_block.get("colour"))
		if c.a == 0.0:
			warnings.append("dressing.moss.colour is not a colour; no moss")
		else:
			moss = c
			moss_share = _share(moss_block.get("share", 0.0), "dressing.moss.share")
	var pools: Variant = d.get("puddles", [])
	for i in (pools as Array).size() if pools is Array else 0:
		var raw: Variant = (pools as Array)[i]
		var q: Dictionary = raw if raw is Dictionary else {}
		var p := Puddle.new()
		p.at = Vector2(_number(q.get("x"), NAN), _number(q.get("z"), NAN))
		p.size = Vector2(_number(q.get("width"), NAN), _number(q.get("depth"), NAN))
		var mud: Variant = q.get("mud", false)
		if is_nan(p.at.x) or is_nan(p.at.y) or not (p.size.x > 0.0 and p.size.y > 0.0) or not mud is bool:
			warnings.append("dressing.puddles %d needs x, z, a width and depth over 0 (mud true or false); left out" % i)
			continue
		p.mud = mud
		puddles.append(p)
	if not pools is Array:
		warnings.append("dressing.puddles is not a list; no puddles")
	fireflies = _count(_block_of(d, "fireflies", ["count"]).get("count", 0), "dressing.fireflies.count",
			style.most_fireflies)
	forest_trees = _count(_block_of(d, "forest", ["trees"]).get("trees", 0), "dressing.forest.trees",
			style.most_forest_trees)
	var grass: Variant = _block_of(d, "grass", ["height"]).get("height", 0.0)
	grass_height = maxf(_number(grass, -1.0), 0.0)
	if _number(grass, -1.0) < 0.0:
		warnings.append("dressing.grass.height is not a height; no grass")
	var motes: Dictionary = _block_of(d, "motes", ["tint"])
	if not motes.is_empty():
		var tint := _colour(motes.get("tint"))
		has_motes = tint.a > 0.0
		motes_tint = tint if has_motes else Color.WHITE
		if not has_motes:
			warnings.append("dressing.motes.tint is not a colour; no motes")


## `d[key]` when it is an object (empty when absent), or empty with a warning naming `fields` when it is something else.
func _block_of(d: Dictionary, key: String, fields: PackedStringArray) -> Dictionary:
	var raw: Variant = d.get(key)
	if raw == null or raw is Dictionary:
		return raw if raw != null else {}
	warnings.append("dressing.%s is not {%s}; left out" % [key, ", ".join(fields)])
	return {}


## A share, 0 to 1: anything else is 0 with a warning naming `what`.
func _share(raw: Variant, what: String) -> float:
	var v := _number(raw, -1.0)
	if v < 0.0 or v > 1.0:
		warnings.append("%s is not a share from 0 to 1; none" % what)
		return 0.0
	return v


## A count, a whole number 0 or more: anything else is 0 with a warning naming `what`; more than `most` is `most`,
## with a warning.
func _count(raw: Variant, what: String, most: int) -> int:
	var v := _number(raw, -1.0)
	if v < 0.0 or v != floorf(v):
		warnings.append("%s is not a whole number; none" % what)
		return 0
	if v > most:
		warnings.append("%s is more than the most a map may ask for; %d" % [what, most])
		return most
	return int(v)


static func _spots(list: Variant) -> Array[SpawnPoint]:
	var out: Array[SpawnPoint] = []
	if not list is Array:
		return out
	for raw: Variant in list:
		if raw is Dictionary:
			out.append(SpawnPoint.new(_vec((raw as Dictionary).get("position")), float((raw as Dictionary).get("yaw", 0.0))))
	return out


## The flagpoles: each spot of `list` (the file's `flags`), up to Flag.MOST; without a list, the one `single` (`flag`).
## A bad spot is left out with a warning (_spot).
func _read_poles(list: Variant, single: Variant) -> void:
	poles.clear()
	if list == null:
		if _spot(single, "flag", warnings):
			poles.append(_vec(single))
	elif not list is Array or (list as Array).is_empty():
		warnings.append("flags %s is not a list of spots: none read" % JSON.stringify(list))
	else:
		for raw: Variant in list:
			if poles.size() >= Flag.MOST:
				warnings.append("flags: more than %d, the rest left out" % Flag.MOST)
				break
			if _spot(raw, "flags", warnings):
				poles.append(_vec(raw))
	has_pole = not poles.is_empty()
	pole = poles[0] if has_pole else Vector3.ZERO


static func _vec(raw: Variant) -> Vector3:
	if not raw is Dictionary:
		return Vector3.ZERO
	var d: Dictionary = raw
	return Vector3(_number(d.get("x"), 0.0), _number(d.get("y"), 0.0), _number(d.get("z"), 0.0))


## Whether `raw` (the file's `key`) is a spot: an object with numbers for x and z, and for y if it has one (no y is a
## foot at 0). Anything else given is no spot, with a warning; none given is none, quietly.
static func _spot(raw: Variant, key: String, warnings: Array[String]) -> bool:
	if raw == null:
		return false
	var d: Dictionary = raw if raw is Dictionary else {}
	var numbers := d.has("x") and d.has("z")
	for axis: String in ["x", "y", "z"]:
		var v: Variant = d.get(axis, 0.0)
		numbers = numbers and (v is float or v is int)
	if not numbers:
		warnings.append("%s %s is not a spot (numbers for x and z, and y if given): none read" % [
			key, JSON.stringify(raw)])
	return numbers
