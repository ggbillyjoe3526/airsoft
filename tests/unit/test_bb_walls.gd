extends GutTest
## FB4 (the owner's 0.1 Dev 1 playtest, note 11: "may possibly be going through wall models"): no BB passes a wall. BBs
## from the fastest replica, fired through the simulation's own BBStep at the middle and near each edge of every face of
## every thin wall on Depot (walls, plywood, barriers, containers) and Woodland (fences, logs), square on and at 40
## degrees, from point-blank, 5 m and 25 m, never run inside the block they were fired at nor end inside any block (a
## round prop's block: inside its stepped boxes, BP7). (The full sweep of every block, 54 176 shots, is in
## docs/records/FB4.md.)

const DT := 1.0 / 60.0
## How far inside a block (m) counts as through it: the BB stops on the face, within float rounding.
const IN := 0.002
const EDGE := 0.03
const MAX_TICKS := 60
const THIN := {"depot": [&"wall", &"plywood", &"barrier", &"container"], "woodland": [&"fence", &"log"]}


func test_no_bb_passes_a_thin_wall_on_depot_or_woodland() -> void:
	var tuning := SimTuning.load_default()
	var rules := tuning.replica_rules
	var fastest: ReplicaConfig = null
	var speed := 0.0
	for id: String in ReplicaStats.read_file().replicas.keys():
		var r := ReplicaStats.load_replica(StringName(id))
		if Ballistics.muzzle_velocity(r, rules) > speed:
			speed = Ballistics.muzzle_velocity(r, rules)
			fastest = r
	var style := MapStyle.new()
	for map_id: String in THIN:
		var m := MapData.load_map(map_id, style, tuning.rounds.team_size)
		var level := MapLevel.new()
		add_child(level)
		level.build(m, style, tuning.body)
		var lo: Array[Vector3] = []
		var hi: Array[Vector3] = []
		# What is solid, for "ends inside a block": each block's box, a round prop's its stepped boxes (BP7).
		var solid_lo: Array[Vector3] = []
		var solid_hi: Array[Vector3] = []
		var middle := PropLayout.field_middle(m)
		var steps: Array[AABB] = []
		for b in m.blocks:
			# Ramps are wedges: their boxes hold air above the slope.
			lo.append(b.center - b.size * 0.5 if b.rise == MapData.Rise.NONE else Vector3.INF)
			hi.append(b.center + b.size * 0.5 if b.rise == MapData.Rise.NONE else -Vector3.INF)
			RoundSteps.boxes(b, style, PropDressConfig.new(), middle, steps)
			if steps.is_empty():
				solid_lo.append(lo[-1])
				solid_hi.append(hi[-1])
			for box in steps:
				solid_lo.append(box.position)
				solid_hi.append(box.end)
		var pool := BBPool.new(1)
		var events := SimEvents.new()
		var nobody: Array[Character] = []
		var ends: Array[MapEnd] = []
		var shots := 0
		var through := 0
		for i in m.blocks.size():
			var b := m.blocks[i]
			if not (THIN[map_id] as Array).has(b.kind):
				continue
			for face in 4:
				var axis := 0 if face < 2 else 2
				var side := 2 - axis
				var n := Vector3.ZERO
				n[axis] = 1.0 if face % 2 == 0 else -1.0
				var t := Vector3.ZERO
				t[side] = 1.0
				var half := b.size * 0.5
				for u: float in [-1.0, 0.0, 1.0]:
					var p := b.center + n * half[axis] + t * u * maxf(0.0, half[side] - EDGE)
					for ang: float in [0.0, 40.0]:
						for dist: float in [0.4, 5.0, 25.0]:
							var o := p + n.rotated(Vector3.UP, deg_to_rad(ang) * (1.0 if u >= 0.0 else -1.0)) * dist
							if _inside_any(o, solid_lo, solid_hi, -0.01):
								continue
							shots += 1
							var bb := pool.spawn(0, o, (p - o).normalized(), speed, Ballistics.hop_up_lift(fastest, 0.5,
									rules), Ballistics.bb_mass(fastest), tuning.ballistics.spin_per_hop)
							var passed := false
							for tick in MAX_TICKS:
								events.clear()
								BBStep.step(pool, nobody, level.query(), tuning, m.kill_y, false, ends, events, DT)
								passed = passed or _runs_inside(bb.prev_position, bb.position, lo[i], hi[i])
								if not bb.active:
									break
							bb.active = false
							if passed or _inside_any(bb.position, solid_lo, solid_hi, IN):
								through += 1
		assert_gt(shots, 500, "control: %s's thin walls were shot at" % map_id)
		assert_eq(through, 0, "%s: no BB through a wall (%d shots)" % [map_id, shots])
		level.free()


static func _inside_any(p: Vector3, lo: Array[Vector3], hi: Array[Vector3], margin: float) -> bool:
	for i in lo.size():
		if p.x > lo[i].x + margin and p.x < hi[i].x - margin and p.y > lo[i].y + margin and p.y < hi[i].y - margin \
				and p.z > lo[i].z + margin and p.z < hi[i].z - margin:
			return true
	return false


## Whether the segment a..b runs inside the box lo..hi, IN in from its faces.
static func _runs_inside(a: Vector3, b: Vector3, lo: Vector3, hi: Vector3) -> bool:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for k in 3:
		var l := lo[k] + IN
		var h := hi[k] - IN
		if absf(d[k]) < 1e-12:
			if a[k] <= l or a[k] >= h:
				return false
			continue
		var ta := (l - a[k]) / d[k]
		var tb := (h - a[k]) / d[k]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
		if t0 >= t1:
			return false
	return true
