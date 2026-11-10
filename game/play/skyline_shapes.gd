class_name SkylineShapes
extends RefCounted
## The skyline's greybox as plain geometry: each SkylinePiece as parts, each part a section swept from one point to
## another (a box, a drum, a cone, a beam, a gable roof) in one colour, sized by SkylineConfig. SkylineView draws the
## parts as one mesh; SkylineSight aims its sight lines at their tops (`samples_of`). Sheds' doors, cranes' jibs and
## masts' lamps face the field's middle.

## A part on the ground (its first section this low, m) has no bottom face.
const GROUND := 0.01
## For `hides_of`: the square inside a drum, as a share of its radius (inside its sides, a polygon), and a hill's solid
## core, a box this share of its footprint across, as tall as the mound stands at the box's corners.
const INSCRIBED := 0.68
const HILL_CORE := 0.35


## One part: the section `a` at its start and `b` at its end (the same number of points, joined side by side), its
## faces `colour`; a cap closes a section unless it is on the ground or shrunk to a point. A lamp glows at night. A part
## `with_model` is drawn even where its piece's kind is drawn from a model (SkylineModels): the walkway over a silo row.
class Part:
	extends RefCounted
	var a: PackedVector3Array = PackedVector3Array()
	var b: PackedVector3Array = PackedVector3Array()
	var colour: Color = Color.WHITE
	var cap_a: bool = true
	var cap_b: bool = true
	var lamp: bool = false
	var with_model: bool = false
	## Its share of the skyline's fade toward the horizon (a treeline's SkylineConfig.treeline_fade).
	var haze: float = 1.0
	## How much of its colour it keeps against the look's pull toward grey (a treeline's SkylineConfig.treeline_keep).
	var keep: float = 0.0


## The parts of `p`, the field's middle at `middle` (x, z).
static func parts_of(p: SkylinePiece, cfg: SkylineConfig, middle: Vector2) -> Array[Part]:
	var out: Array[Part] = []
	var toward := toward_of(p, middle)
	match p.kind:
		&"shed":
			_shed(out, p, cfg, toward)
		&"waterTower":
			_water_tower(out, p, cfg)
		&"crane":
			_crane(out, p, cfg, toward)
		&"containers":
			_containers(out, p, cfg)
		&"chimney":
			_chimney(out, p, cfg)
		&"silo":
			_silo(out, p, cfg)
		&"powerLine":
			_power_line(out, p, cfg)
		&"hill":
			_hill(out, p, cfg)
		&"watchTower":
			_watch_tower(out, p, cfg)
		&"fuselage":
			_fuselage(out, p, cfg)
		&"mast":
			_mast(out, p, cfg, toward)
		&"treeline":
			_treeline(out, p, cfg)
	return out


## Which way `p` faces: toward the field's middle `middle` (x, z), a unit vector (+z when it stands on it).
static func toward_of(p: SkylinePiece, middle: Vector2) -> Vector2:
	return (middle - p.at).normalized() if p.at.distance_to(middle) > 0.0 else Vector2(0.0, 1.0)


## The solid boxes inside `p` that hide what stands beyond it (DP3's row): a shed's walls, a container stack, each
## silo's drum (the square inside it) and a hill's core (the box inside its mound to `HILL_CORE` of its footprint);
## none for the open or thin kinds (towers, cranes, masts, lines, chimneys, the fuselage, treelines). Plain data, the
## box's low corner then its high one, two entries a box.
static func hides_of(p: SkylinePiece, cfg: SkylineConfig) -> PackedVector3Array:
	var out := PackedVector3Array()
	match p.kind:
		&"shed", &"containers":
			out.append(Vector3(p.at.x - p.width * 0.5, 0.0, p.at.y - p.depth * 0.5))
			out.append(Vector3(p.at.x + p.width * 0.5, p.height, p.at.y + p.depth * 0.5))
		&"silo":
			var along_x := p.width >= p.depth
			var r := minf(p.width, p.depth) * 0.5
			var step := 2.0 * r + cfg.silo_gap
			var n := maxi(1, floori((maxf(p.width, p.depth) + cfg.silo_gap) / step))
			var dir := Vector3(1.0, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, 1.0)
			var half := Vector3(r * INSCRIBED, 0.0, r * INSCRIBED)
			for i in n:
				var c := Vector3(p.at.x, 0.0, p.at.y) + dir * (i - (n - 1) * 0.5) * step
				out.append(c - half)
				out.append(c + half + Vector3.UP * (p.height - r * cfg.silo_roof))
		&"hill":
			var core := Vector3(p.width * 0.5 * HILL_CORE, 0.0, p.depth * 0.5 * HILL_CORE)
			var c := Vector3(p.at.x, 0.0, p.at.y)
			out.append(c - core)
			out.append(c + core + Vector3.UP * p.height * mound_at(HILL_CORE * sqrt(2.0) / cos(PI / cfg.sides), cfg))
	return out


## A hill's height, as a share of its top, `r` of the way out to its foot (a share of its footprint): its rings' faces
## joined straight, under the curve through them.
static func mound_at(r: float, cfg: SkylineConfig) -> float:
	var rings := maxi(1, cfg.hill_rings)
	if r >= 1.0:
		return 0.0
	var k := clampi(floori((1.0 - r) * rings), 0, rings - 1)
	var r0 := 1.0 - float(k) / rings
	var r1 := 1.0 - float(k + 1) / rings
	return lerpf(cos(r0 * PI * 0.5), cos(r1 * PI * 0.5), (r0 - maxf(r, 0.0)) / (r0 - r1))


## Where a sight line may see each part: the points of its highest section, or of both when they stand level (a beam).
static func samples_of(parts: Array[Part]) -> PackedVector3Array:
	var out := PackedVector3Array()
	for part in parts:
		var ya := _top(part.a)
		var yb := _top(part.b)
		if ya >= yb - GROUND:
			out.append_array(_highest(part.a, ya))
		if yb >= ya - GROUND:
			out.append_array(_highest(part.b, yb))
	return out


## Where a smoking chimney's smoke starts: its top's middle.
static func smoke_from(p: SkylinePiece) -> Vector3:
	return Vector3(p.at.x, p.height, p.at.y)


static func _shed(out: Array[Part], p: SkylinePiece, cfg: SkylineConfig, toward: Vector2) -> void:
	var h := p.height
	var lo := Vector3(p.at.x - p.width * 0.5, 0.0, p.at.y - p.depth * 0.5)
	var hi := Vector3(p.at.x + p.width * 0.5, h, p.at.y + p.depth * 0.5)
	out.append(box(lo, hi, p.colour_or(cfg.shed_colour)))
	# the gabled roof along the long side
	var along_x := p.width >= p.depth
	var half_short := (p.depth if along_x else p.width) * 0.5 + cfg.roof_overhang
	var rise := minf(p.width, p.depth) * cfg.roof_rise
	var end := Vector3((p.width * 0.5 + cfg.roof_overhang) if along_x else 0.0, 0.0,
			0.0 if along_x else (p.depth * 0.5 + cfg.roof_overhang))
	var top := Vector3(p.at.x, h, p.at.y)
	var gable := PackedVector2Array([Vector2(-half_short, 0.0), Vector2(half_short, 0.0), Vector2(0.0, rise)])
	out.append(sweep(top - end, top + end, gable, gable, cfg.shed_roof))
	# the band and the doors on the side facing the field
	var face := facing(toward)
	var span := p.depth if face.x != 0.0 else p.width
	var out_by := (p.width if face.x != 0.0 else p.depth) * 0.5
	var along := Vector3(0.0, 0.0, 1.0) if face.x != 0.0 else Vector3(1.0, 0.0, 0.0)
	var normal := Vector3(face.x, 0.0, face.y)
	var middle := Vector3(p.at.x, 0.0, p.at.y) + normal * out_by
	var band_top := h - cfg.band_below
	out.append(_slab(middle + Vector3.UP * (band_top - cfg.band_height), middle + Vector3.UP * band_top, along,
			span, normal, cfg.proud, cfg.shed_band))
	var doors := maxi(1, floori(span / cfg.door_every))
	var door_h := minf(cfg.door_height, band_top - cfg.band_height - cfg.proud)
	for i in doors:
		var c := middle + along * ((i + 0.5) * span / doors - span * 0.5)
		out.append(_slab(c, c + Vector3.UP * door_h, along, minf(cfg.door_width, span / doors * 0.8), normal,
				cfg.proud, cfg.shed_doors))


static func _water_tower(out: Array[Part], p: SkylinePiece, cfg: SkylineConfig) -> void:
	var r := minf(p.width, p.depth) * 0.5
	var roof := minf(p.width, p.depth) * cfg.tank_roof
	var tank_top := p.height - roof
	var tank_bottom := p.height - p.height * cfg.tank
	var c := Vector3(p.at.x, 0.0, p.at.y)
	for i in 4:
		var off := Vector3(p.width * 0.35 * (1.0 if i & 1 else -1.0), 0.0, p.depth * 0.35 * (1.0 if i & 2 else -1.0))
		var half := Vector3(cfg.tower_leg, 0.0, cfg.tower_leg) * 0.5
		out.append(box(c + off - half, c + off + half + Vector3.UP * tank_bottom, cfg.tank_legs))
	out.append(drum(c + Vector3.UP * tank_bottom, c + Vector3.UP * tank_top, r, r, cfg.sides, cfg.tank_colour))
	out.append(drum(c + Vector3.UP * tank_top, c + Vector3.UP * p.height, r * 1.05, 0.0, cfg.sides,
			p.colour_or(cfg.tank_roof_colour)))


static func _crane(out: Array[Part], p: SkylinePiece, cfg: SkylineConfig, toward: Vector2) -> void:
	var along_x := p.width >= p.depth
	var length := p.width if along_x else p.depth
	var ahead := signf(toward.x if along_x else toward.y)
	var dir := (Vector3(1.0, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, 1.0)) * (ahead if ahead != 0.0 else 1.0)
	var c := Vector3(p.at.x, 0.0, p.at.y)
	var colour := p.colour_or(cfg.crane_colour)
	var half := Vector3(cfg.crane_mast, 0.0, cfg.crane_mast) * 0.5
	var jib_y := p.height - cfg.crane_jib * 0.5
	out.append(box(c - half, c + half + Vector3.UP * (p.height - cfg.crane_jib), colour))
	var tip := c + dir * length * cfg.crane_reach + Vector3.UP * jib_y
	var back := c - dir * length * (1.0 - cfg.crane_reach) + Vector3.UP * jib_y
	var j := cfg.crane_jib * 0.5
	out.append(sweep(back, tip, _rect(j, j), _rect(j, j), colour))
	var w := cfg.crane_weight * 0.5
	var weight_at := back + dir * w.x + Vector3.DOWN * (j + w.y)
	out.append(box(weight_at - w, weight_at + w, cfg.crane_weight_colour))
	var hook := tip - dir * cfg.crane_jib * 2.0
	out.append(sweep(hook + Vector3.DOWN * j, hook + Vector3.DOWN * (j + cfg.crane_line), _rect(0.05, 0.05),
			_rect(0.05, 0.05), cfg.crane_weight_colour))


static func _containers(out: Array[Part], p: SkylinePiece, cfg: SkylineConfig) -> void:
	var tiers := maxi(1, roundi(p.height / cfg.container_tier))
	var tier := p.height / tiers
	var first := absi(roundi(p.at.x * 7.0 + p.at.y * 13.0))
	var n := cfg.container_colours.size()
	for i in tiers:
		var lo := Vector3(p.at.x - p.width * 0.5, tier * i, p.at.y - p.depth * 0.5)
		var hi := Vector3(p.at.x + p.width * 0.5, tier * (i + 1), p.at.y + p.depth * 0.5)
		out.append(box(lo, hi, p.colour if p.has_colour else cfg.container_colours[(first + i) % n]))


static func _chimney(out: Array[Part], p: SkylinePiece, cfg: SkylineConfig) -> void:
	var r := minf(p.width, p.depth) * 0.5
	var c := Vector3(p.at.x, 0.0, p.at.y)
	out.append(drum(c, c + Vector3.UP * p.height, r, r * cfg.chimney_top, cfg.sides, p.colour_or(cfg.chimney_colour)))
	for i in cfg.chimney_bands:
		var top := p.height - cfg.chimney_band_below - i * cfg.chimney_band_gap
		var at_r := lerpf(r, r * cfg.chimney_top, top / p.height) + cfg.proud
		out.append(drum(c + Vector3.UP * (top - cfg.chimney_band), c + Vector3.UP * top, at_r, at_r, cfg.sides,
				cfg.chimney_band_colour))


## The middles (on the ground) of a silo row's drums, along its long side, each `silo_radius` across.
static func silo_drums(p: SkylinePiece, cfg: SkylineConfig) -> PackedVector3Array:
	var r := silo_radius(p)
	var n := maxi(1, floori((maxf(p.width, p.depth) + cfg.silo_gap) / (2.0 * r + cfg.silo_gap)))
	var step := 2.0 * r + cfg.silo_gap
	var dir := Vector3(1.0, 0.0, 0.0) if p.width >= p.depth else Vector3(0.0, 0.0, 1.0)
	var out := PackedVector3Array()
	for i in n:
		out.append(Vector3(p.at.x, 0.0, p.at.y) + dir * (i - (n - 1) * 0.5) * step)
	return out


## A silo drum's radius: half the row's short side.
static func silo_radius(p: SkylinePiece) -> float:
	return minf(p.width, p.depth) * 0.5


static func _silo(out: Array[Part], p: SkylinePiece, cfg: SkylineConfig) -> void:
	var r := silo_radius(p)
	var drums := silo_drums(p, cfg)
	var n := drums.size()
	var step := 2.0 * r + cfg.silo_gap
	var dir := Vector3(1.0, 0.0, 0.0) if p.width >= p.depth else Vector3(0.0, 0.0, 1.0)
	var drum_top := p.height - r * cfg.silo_roof
	var colour := p.colour_or(cfg.silo_colour)
	for c in drums:
		out.append(drum(c, c + Vector3.UP * drum_top, r, r, cfg.sides, colour))
		out.append(drum(c + Vector3.UP * drum_top, c + Vector3.UP * p.height, r, 0.0, cfg.sides, cfg.silo_roof_colour))
		out.append(drum(c + Vector3.UP * cfg.silo_band_at, c + Vector3.UP * (cfg.silo_band_at + cfg.silo_band),
				r + cfg.proud, r + cfg.proud, cfg.sides, cfg.silo_band_colour))
	if n > 1:
		var half := (n - 1) * 0.5 * step
		var w := cfg.silo_walkway * 0.5
		var mid := Vector3(p.at.x, p.height, p.at.y)
		var walkway := sweep(mid - dir * half, mid + dir * half, _rect(w, cfg.proud * 2.0), _rect(w, cfg.proud * 2.0),
				cfg.silo_walkway_colour)
		walkway.with_model = true
		out.append(walkway)


static func _power_line(out: Array[Part], p: SkylinePiece, cfg: SkylineConfig) -> void:
	var arm_y := p.height - cfg.pylon_top
	var ends: Array[PackedVector3Array] = []
	for i in p.points.size():
		var q := p.points[i]
		var prev := p.points[maxi(i - 1, 0)]
		var next := p.points[mini(i + 1, p.points.size() - 1)]
		var run := (next - prev).normalized()
		var across := Vector3(-run.y, 0.0, run.x)
		var c := Vector3(q.x, 0.0, q.y)
		var base := _rect(cfg.pylon_base * 0.5, cfg.pylon_base * 0.5)
		var top := _rect(cfg.pylon_top * 0.5, cfg.pylon_top * 0.5)
		out.append(sweep(c, c + Vector3.UP * p.height, base, top, cfg.pylon_colour))
		var arm := c + Vector3.UP * arm_y
		var t := cfg.pylon_top * 0.4
		out.append(sweep(arm - across * cfg.pylon_arm * 0.5, arm + across * cfg.pylon_arm * 0.5, _rect(t, t), _rect(t, t),
				cfg.pylon_colour))
		var hang := PackedVector3Array()
		for k in cfg.wires:
			var share := (k + 0.5) / cfg.wires - 0.5
			hang.append(arm + across * cfg.pylon_arm * share + Vector3.DOWN * t)
		ends.append(hang)
	var w := cfg.wire * 0.5
	for i in ends.size() - 1:
		for k in cfg.wires:
			var from := ends[i][k]
			var to := ends[i + 1][k]
			for s in cfg.wire_pieces:
				var t0 := float(s) / cfg.wire_pieces
				var t1 := float(s + 1) / cfg.wire_pieces
				var piece := sweep(_sagged(from, to, t0, cfg.sag), _sagged(from, to, t1, cfg.sag), _rect(w, w), _rect(w, w),
						cfg.wire_colour)
				piece.cap_a = s == 0
				piece.cap_b = s == cfg.wire_pieces - 1
				out.append(piece)


## A band of conifers along the line (WL4): rows `treeline_spacing` m apart across its depth, a cone every
## `treeline_spacing` m along each, jittered and of seeded heights and colours (the same every build), sunk
## `treeline_sink` m so none floats on lower ground beyond the field.
static func _treeline(out: Array[Part], p: SkylinePiece, cfg: SkylineConfig) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(p.points)
	var depth := p.depth if p.depth > 0.0 else cfg.treeline_spacing
	var rows := maxi(1, roundi(depth / cfg.treeline_spacing))
	var shake := cfg.treeline_jitter * cfg.treeline_spacing
	for i in p.points.size() - 1:
		var a := p.points[i]
		var b := p.points[i + 1]
		var run := (b - a).normalized()
		var across := Vector2(-run.y, run.x)
		var steps := maxi(1, roundi(a.distance_to(b) / cfg.treeline_spacing))
		for k in steps:
			for r in rows:
				var off := (float(r) + 0.5) / rows - 0.5
				var at := a.lerp(b, (k + 0.5 * (r % 2)) / steps) + across * depth * off
				at += Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))
				var h := p.height * rng.randf_range(cfg.treeline_low, 1.0)
				var colour := cfg.treeline_colours[rng.randi() % cfg.treeline_colours.size()]
				var foot := Vector3(at.x, -cfg.treeline_sink, at.y)
				var tree := drum(foot, Vector3(at.x, h, at.y), h * cfg.treeline_width, 0.0, cfg.treeline_sides,
						p.colour_or(colour))
				tree.haze = cfg.treeline_fade
				tree.keep = cfg.treeline_keep
				out.append(tree)


static func _hill(out: Array[Part], p: SkylinePiece, cfg: SkylineConfig) -> void:
	var colour := p.colour_or(cfg.hill_colour)
	var c := Vector3(p.at.x, 0.0, p.at.y)
	for k in cfg.hill_rings:
		var r0 := 1.0 - float(k) / cfg.hill_rings
		var r1 := 1.0 - float(k + 1) / cfg.hill_rings
		var y0 := p.height * cos(r0 * PI * 0.5)
		var y1 := p.height * cos(r1 * PI * 0.5)
		var ring := sweep(c + Vector3.UP * y0, c + Vector3.UP * y1, _ellipse(p.width * 0.5 * r0, p.depth * 0.5 * r0,
				cfg.sides), _ellipse(p.width * 0.5 * r1, p.depth * 0.5 * r1, cfg.sides), colour)
		ring.cap_a = false
		ring.cap_b = false
		out.append(ring)


static func _watch_tower(out: Array[Part], p: SkylinePiece, cfg: SkylineConfig) -> void:
	var c := Vector3(p.at.x, 0.0, p.at.y)
	var colour := p.colour_or(cfg.watch_colour)
	var deck_top := p.height - cfg.watch_roof - cfg.watch_cabin
	var column := Vector3(p.width, 0.0, p.depth) * cfg.watch_column * 0.5
	out.append(box(c - column, c + column + Vector3.UP * (deck_top - cfg.watch_deck), colour))
	var deck := Vector3(p.width, 0.0, p.depth) * 0.5
	out.append(box(c - deck + Vector3.UP * (deck_top - cfg.watch_deck), c + deck + Vector3.UP * deck_top, colour))
	var t := cfg.watch_post
	for side in 4:
		var x_side := side < 2
		var s := 1.0 if side % 2 == 0 else -1.0
		var mid := c + (Vector3(deck.x * s, 0.0, 0.0) if x_side else Vector3(0.0, 0.0, deck.z * s))
		var half := Vector3(t * 0.5, 0.0, deck.z) if x_side else Vector3(deck.x, 0.0, t * 0.5)
		var inward := (Vector3(-s * t * 0.5, 0.0, 0.0) if x_side else Vector3(0.0, 0.0, -s * t * 0.5))
		out.append(box(mid + inward - half + Vector3.UP * deck_top,
				mid + inward + half + Vector3.UP * (deck_top + cfg.watch_parapet), colour))
	for i in 4:
		var corner := c + Vector3((deck.x - t * 0.5) * (1.0 if i & 1 else -1.0), 0.0,
				(deck.z - t * 0.5) * (1.0 if i & 2 else -1.0))
		var post := Vector3(t, 0.0, t) * 0.5
		out.append(box(corner - post + Vector3.UP * (deck_top + cfg.watch_parapet),
				corner + post + Vector3.UP * (p.height - cfg.watch_roof), colour))
	var roof := deck + Vector3(cfg.watch_roof, 0.0, cfg.watch_roof)
	out.append(box(c - roof + Vector3.UP * (p.height - cfg.watch_roof), c + roof + Vector3.UP * p.height,
			cfg.watch_roof_colour))


static func _fuselage(out: Array[Part], p: SkylinePiece, cfg: SkylineConfig) -> void:
	var along_x := p.width >= p.depth
	var length := maxf(p.width, p.depth)
	var r := minf(p.width, p.depth) * 0.5
	var dir := Vector3(1.0, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, 1.0)
	var across := Vector3(0.0, 0.0, 1.0) if along_x else Vector3(1.0, 0.0, 0.0)
	var colour := p.colour_or(cfg.fuselage_colour)
	var axis := Vector3(p.at.x, cfg.fuselage_cradle + r, p.at.y)
	var nose := r * cfg.fuselage_nose
	var tail := r * cfg.fuselage_tail
	var body := length - nose - tail
	var tail_at := axis - dir * (length * 0.5 - tail)
	var nose_at := tail_at + dir * body
	var ring := _ellipse(r, r, cfg.sides)
	out.append(sweep(tail_at, nose_at, ring, ring, colour))
	out.append(sweep(nose_at, nose_at + dir * nose + Vector3.DOWN * r * 0.2, ring, _ellipse(r * 0.35, r * 0.35, cfg.sides),
			colour))
	var tail_end := tail_at - dir * tail + Vector3.UP * r * 0.5
	out.append(sweep(tail_at, tail_end, ring, _ellipse(r * 0.3, r * 0.3, cfg.sides), colour))
	# the fin rises from the tail cone to the piece's height
	var fin_base := tail_end + dir * cfg.fuselage_fin * 0.5 + Vector3.UP * r * 0.2
	var fin_top := Vector3(fin_base.x, p.height, fin_base.z) - dir * cfg.fuselage_fin * 0.3
	var fin_t := cfg.proud * 2.0
	out.append(sweep(fin_base, fin_top, _rect(fin_t, cfg.fuselage_fin * 0.5), _rect(fin_t, cfg.fuselage_fin * 0.25),
			cfg.fuselage_trim))
	# the window stripe along both sides, and the wing stubs
	var stripe := cfg.proud * 2.0
	for s: float in [-1.0, 1.0]:
		var side := across * (r + cfg.proud * 0.5) * s + Vector3.UP * r * 0.25
		out.append(sweep(tail_at + side, nose_at + side, _rect(stripe * 0.5, stripe * 2.0),
				_rect(stripe * 0.5, stripe * 2.0), cfg.fuselage_trim))
	var wing_at := axis - Vector3.UP * r * 0.5
	var wing := _rect(cfg.fuselage_fin * 0.5, stripe * 2.0)
	out.append(sweep(wing_at - across * (r + cfg.fuselage_wing), wing_at + across * (r + cfg.fuselage_wing),
			wing, wing, colour))
	for s: float in [-0.3, 0.3]:
		var block := axis + dir * body * s
		var half := Vector3(r * 0.6, 0.0, r * 0.6)
		out.append(box(Vector3(block.x, 0.0, block.z) - half,
				Vector3(block.x, 0.0, block.z) + half + Vector3.UP * cfg.fuselage_cradle, cfg.fuselage_trim))


static func _mast(out: Array[Part], p: SkylinePiece, cfg: SkylineConfig, toward: Vector2) -> void:
	var c := Vector3(p.at.x, 0.0, p.at.y)
	var half := Vector3(cfg.mast_pole, 0.0, cfg.mast_pole) * 0.5
	out.append(box(c - half, c + half + Vector3.UP * (p.height - cfg.mast_head), p.colour_or(cfg.mast_colour)))
	var facing := Vector3(toward.x, 0.0, toward.y)
	var across := Vector3(-toward.y, 0.0, toward.x)
	var head := c + Vector3.UP * (p.height - cfg.mast_head * 0.5)
	var bar := _rect(p.depth * 0.5, cfg.mast_head * 0.5)
	out.append(sweep(head - across * p.width * 0.5, head + across * p.width * 0.5, bar, bar, cfg.mast_head_colour))
	var lamp := p.width / cfg.mast_lamps
	for i in cfg.mast_lamps:
		var at := head + across * ((i + 0.5) * lamp - p.width * 0.5) + facing * p.depth * 0.5
		var face := _rect(lamp * 0.4, cfg.mast_head * 0.35)
		var glass := sweep(at, at + facing * cfg.proud * 3.0, face, face, cfg.mast_lamp_colour)
		glass.lamp = true
		out.append(glass)


## An axis-aligned box from `lo` to `hi`.
static func box(lo: Vector3, hi: Vector3, colour: Color) -> Part:
	var half := (hi - lo) * 0.5
	var bottom := Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
	return sweep(bottom, bottom + Vector3.UP * (hi.y - lo.y), _rect(half.x, half.z), _rect(half.x, half.z), colour)


## A round drum (a cone with `r1` 0) from `from` to `to`.
static func drum(from: Vector3, to: Vector3, r0: float, r1: float, sides: int, colour: Color) -> Part:
	return sweep(from, to, _ellipse(r0, r0, sides), _ellipse(r1, r1, sides), colour)


## The section `sa` at `from` swept to `sb` at `to`. A section's point (u, v) lies `u` along the sweep's side and `v`
## along its up: for an upright sweep x and z, for a level one across it and up.
static func sweep(from: Vector3, to: Vector3, sa: PackedVector2Array, sb: PackedVector2Array, colour: Color) -> Part:
	var dir := (to - from).normalized()
	var ref := Vector3.UP if absf(dir.y) < 0.99 else Vector3.BACK
	var side := dir.cross(ref).normalized()
	var up := side.cross(dir).normalized()
	var part := Part.new()
	part.colour = colour
	for q in sa:
		part.a.append(from + side * q.x + up * q.y)
	for q in sb:
		part.b.append(to + side * q.x + up * q.y)
	part.cap_a = not (from.y <= GROUND and to.y > from.y) and not _point(sa)
	part.cap_b = not _point(sb)
	return part


## A slab standing proud of a wall: `width` along `along`, from `foot` up to `head` (both on the wall's face), `proud`
## out along `normal`.
static func _slab(foot: Vector3, head: Vector3, along: Vector3, width: float, normal: Vector3, proud: float,
		colour: Color) -> Part:
	var lo := foot - along * width * 0.5
	var hi := head + along * width * 0.5 + normal * proud
	return box(lo.min(hi), lo.max(hi), colour)


## Which of +x, -x, +z, -z is nearest `toward`.
static func facing(toward: Vector2) -> Vector2:
	if absf(toward.x) >= absf(toward.y):
		return Vector2(signf(toward.x), 0.0)
	return Vector2(0.0, signf(toward.y))


static func _rect(hu: float, hv: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-hu, -hv), Vector2(hu, -hv), Vector2(hu, hv), Vector2(-hu, hv)])


static func _ellipse(ru: float, rv: float, sides: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in sides:
		var a := TAU * i / sides
		out.append(Vector2(cos(a) * ru, sin(a) * rv))
	return out


static func _point(s: PackedVector2Array) -> bool:
	for q in s:
		if q != Vector2.ZERO:
			return false
	return true


static func _sagged(from: Vector3, to: Vector3, t: float, sag: float) -> Vector3:
	return from.lerp(to, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)


static func _top(ring: PackedVector3Array) -> float:
	var y := -INF
	for q in ring:
		y = maxf(y, q.y)
	return y


static func _highest(ring: PackedVector3Array, y: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for q in ring:
		if q.y >= y - GROUND:
			out.append(q)
	return out
