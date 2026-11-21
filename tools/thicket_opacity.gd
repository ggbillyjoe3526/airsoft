extends SceneTree
## The thickets' colliders against their spruces as drawn (TV1; dev only, never exported). On Woodland, for each
## thicket block: seeded lines from a standing eye 8 to 30 m off to points in a ring 0 to 0.8 m round its box, 0.3 to
## 1.8 m over the ground (where a body stands beside it), that cross the box with nothing else in the way first. A line
## less than GRAZE m inside the box grazes it (a body seen past the thicket's end or side), a longer one goes through
## it. Each line is tested against the triangles of the spruces PropLayout draws there and against the block's
## colliders: its whole box (as before TV1) and its tiers (TierSteps) with MapStyle.tier_steps' reaches scaled by each
## of FACTORS (1 is the game's). For each: the lines it stops, those of them that meet no drawn bough ("unseen": a BB
## or a Spotted stopped at a body the player sees past the spruces) and the lines that meet a bough yet fly on
## ("through"). Also prints how solid the spruce model is by height (_opacity), what the reaches were picked from.
## Measured, never asserted.
##   godot --headless --path . -s res://tools/thicket_opacity.gd [-- <lines per block>]

const LINES := 60
const SEED := 11
const NEAR := 8.0
const FAR := 30.0
const EYE := 1.6
const RING := 0.8
const LOW := 0.3
const HIGH := 1.8
const BANDS := 12
## A line under this long (m) inside the box grazes it.
const GRAZE := 0.5
const FACTORS: Array[float] = [1.2, 1.1, 1.0, 0.9, 0.8, 0.7]

var _tally: Dictionary[String, int] = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var per := args[0].to_int() if args.size() > 0 else LINES
	var runner := MatchRunner.new(root, "woodland")
	await physics_frame
	await physics_frame
	var map := runner.map
	var play := PlayTuning.load_default()
	var cfg := play.site_look.props
	var dress := PropDress.build(map, cfg)
	var mesh := dress.mesh_of(&"spruce")
	var placed: Array[Transform3D] = dress.placed()[&"spruce"].transforms
	var model := PackedVector3Array()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in idx:
			model.append(verts[i])
	_opacity(mesh.get_aabb(), model)
	# each factor's style: the game's tier reaches scaled
	var styles: Array[MapStyle] = []
	for f in FACTORS:
		var style := play.map_style.duplicate() as MapStyle
		var tiers: Dictionary[StringName, PackedVector2Array] = {}
		for m: StringName in play.map_style.tier_steps:
			var scaled := PackedVector2Array()
			for t in play.map_style.tier_steps[m]:
				scaled.append(Vector2(t.x, minf(t.y * f, 1.0)))
			tiers[m] = scaled
		style.tier_steps = tiers
		styles.append(style)
	var others := TierSteps.tiered_blocks(map, play.map_style, cfg)
	var query := runner.level.query()
	var hit := RayHit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var steps: Array[AABB] = []
	for b in map.blocks:
		if b.kind != &"thicket":
			continue
		var box := AABB(b.center - b.size * 0.5, b.size)
		var colliders: Array[Array] = [[box]]
		for style in styles:
			TierSteps.boxes(b, style, cfg, others, steps)
			colliders.append(steps.duplicate() if not steps.is_empty() else [box])
		var near := box.grow(0.5)
		var tris := PackedVector3Array()
		for t in placed:
			if near.has_point(Vector3(t.origin.x, b.center.y, t.origin.z)):
				for v in model:
					tris.append(t * v)
		for n in per:
			# a point in the ring round the box, at body height over the ground there
			var p := Vector3.ZERO
			while true:
				p = Vector3(rng.randf_range(box.position.x - RING, box.end.x + RING), 0.0,
						rng.randf_range(box.position.z - RING, box.end.z + RING))
				if not (p.x > box.position.x and p.x < box.end.x and p.z > box.position.z and p.z < box.end.z):
					break
			p.y = map.terrain.height_clamped(p.x, p.z) + rng.randf_range(LOW, HIGH)
			var a := rng.randf() * TAU
			var from := p + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(NEAR, FAR)
			from.y = map.terrain.height_clamped(from.x, from.z) + EYE
			if box.has_point(from):
				continue
			var entry: Variant = box.intersects_segment(from, p)
			var out_at: Variant = box.intersects_segment(p, from)
			if entry == null or out_at == null:
				continue
			# nothing else (the ground, another block) in the way before it
			if query.sight_ray(from, (entry as Vector3) - (p - from).normalized() * 0.05, hit):
				continue
			var kind := "graze" if (entry as Vector3).distance_to(out_at as Vector3) < GRAZE else "through"
			var drawn := false
			for i in range(0, tris.size(), 3):
				if Geometry3D.segment_intersects_triangle(from, p, tris[i], tris[i + 1], tris[i + 2]) != null:
					drawn = true
					break
			_add(kind + " lines")
			for c in colliders.size():
				var name := "box" if c == 0 else "tiers x%.1f" % FACTORS[c - 1]
				var stops := false
				for s: AABB in colliders[c]:
					if s.intersects_segment(from, p) != null:
						stops = true
						break
				if stops:
					_add("%s %s: stopped" % [kind, name])
				if stops and not drawn:
					_add("%s %s: unseen" % [kind, name])
				elif drawn and not stops:
					_add("%s %s: through" % [kind, name])
	var keys := _tally.keys()
	keys.sort()
	for k: String in keys:
		print("%s: %d" % [k, _tally[k]])
	dress.free()
	runner.free_level()
	quit()


func _add(k: String) -> void:
	_tally[k] = _tally.get(k, 0) + 1


## How solid the model is by height: in each of BANDS bands, level lines in seeded directions passing the model's
## middle `u` of its half-width off (u from 0 to 1 by 0.1), the share (%) that meet a triangle; printed with the offset
## where that share first falls under a half.
func _opacity(box: AABB, tris: PackedVector3Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var mid := box.get_center()
	var half := Vector2(box.size.x, box.size.z) * 0.5
	print("spruce %s: level lines past its middle, %% meeting a bough by offset 0 to 1 of its half-width" % box.size)
	for k in BANDS:
		var line := "  height %.2f:" % ((k + 0.5) / BANDS)
		var edge := 1.0
		for ui in 11:
			var u := ui * 0.1
			var met := 0
			var tries := 40
			for n in tries:
				var y := box.position.y + (k + rng.randf()) / BANDS * box.size.y
				var a := rng.randf() * TAU
				var way := Vector3(cos(a), 0.0, sin(a))
				var c := Vector3(mid.x, y, mid.z) + Vector3(-way.z * half.x, 0.0, way.x * half.y) * u
				for i in range(0, tris.size(), 3):
					if Geometry3D.segment_intersects_triangle(c - way * 3.0, c + way * 3.0, tris[i], tris[i + 1],
							tris[i + 2]) != null:
						met += 1
						break
			var share := float(met) / tries
			if share < 0.5 and edge >= 1.0:
				edge = u
			line += " %.0f" % (share * 100.0)
		print(line + "  (under half from %.1f)" % edge)
