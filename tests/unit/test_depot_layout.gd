extends GutTest
## Depot's ports and the Box (DP1), with Jolt rays on the built level: through every port a standing eye sees out and a
## crouched one does not, no port or Box opening can be vaulted, a BB fired up inside the Box stops on its roof, and bots
## from each end walk into the Box by its doors. The ports are found in the data: a sill and a lintel over one footprint.
## On the old yard (tests/support/maps/yard.json, YardMap) since Depot became the indoor hall (DR1).

const DT := 1.0 / 60.0
## The Box (its area in depot.json): its walls' outer faces, x then z.
const BOX_X := Vector2(-1.4, 1.0)
const BOX_Z := Vector2(-4.2, 2.6)
## Its roof's underside (m): the block's; a BB meets the container model drawn over it (DG1), whose ceiling is up to
## ROOF_DRAWN higher.
const BOX_HEADROOM := 2.4
const ROOF_DRAWN := 0.1
## How far past a port's far face a standing eye's line through its middle must run clear (m): room for a body and
## more, so no port looks straight into cover (the Crate yard's north port sat 1.4 m from a barrier in the concept).
const SEE_OUT := 1.5
## Where a crouched eye's lines are aimed past the far face (m), from the floor up to a standing body's chest.
const HIDDEN_AT := 2.0
const HIDDEN_TOP := 1.5
## The Stores' window, the four port walls and the Box's two.
const PORTS := 7

var tuning: SimTuning = SimTuning.load_default()
var style: MapStyle = PlayTuning.load_default().map_style
var hit: RayHit = RayHit.new()
var level: MapLevel = null
var map: MapData = null


## A port: the middle of its opening, the unit way through the wall (x or z), its half width along the wall, the wall's
## half thickness, and the sill's and lintel's heights.
class Port:
	extends RefCounted
	var middle: Vector3 = Vector3.ZERO
	var through: Vector3 = Vector3.ZERO
	var along: Vector3 = Vector3.ZERO
	var half_width: float = 0.0
	var half_thick: float = 0.0
	var sill: float = 0.0
	var lintel: float = 0.0


func before_all() -> void:
	map = YardMap.load_map(style, tuning.rounds.team_size)
	assert_true(map.ok(), str(map.problems))
	level = MapLevel.new()
	add_child(level)
	level.build(map, style, tuning.body)


func after_all() -> void:
	level.free()
	level = null


## Every port on the map: a block from the floor and a block over it on the same footprint with a gap between.
func _ports() -> Array[Port]:
	var out: Array[Port] = []
	for low in map.blocks:
		var low_lo := low.center - low.size * 0.5
		if low_lo.y > 0.01 or low.rise != MapData.Rise.NONE:
			continue
		for high in map.blocks:
			var high_lo := high.center - high.size * 0.5
			var low_top := low_lo.y + low.size.y
			if high == low or high_lo.y <= low_top + 0.01 or high.kind != low.kind:
				continue
			if not (is_equal_approx(high.center.x, low.center.x) and is_equal_approx(high.center.z, low.center.z)
					and is_equal_approx(high.size.x, low.size.x) and is_equal_approx(high.size.z, low.size.z)):
				continue
			var p := Port.new()
			var thin_x := low.size.x < low.size.z
			p.through = Vector3.RIGHT if thin_x else Vector3.BACK
			p.along = Vector3.BACK if thin_x else Vector3.RIGHT
			p.half_width = (low.size.z if thin_x else low.size.x) * 0.5
			p.half_thick = (low.size.x if thin_x else low.size.z) * 0.5
			p.sill = low_top
			p.lintel = high_lo.y
			p.middle = Vector3(low.center.x, (p.sill + p.lintel) * 0.5, low.center.z)
			out.append(p)
	return out


## Where a body stands closest to the port on side `side` (+1 or -1), its feet on the floor.
func _stand(p: Port, side: float) -> Vector3:
	var at := p.middle + p.through * side * (p.half_thick + tuning.body.radius + 0.05)
	at.y = 0.0
	return at


func test_depot_has_seven_ports_at_standing_height() -> void:
	var ports := _ports()
	assert_eq(ports.size(), PORTS, "the Stores' window, four port walls and the Box's two")
	for p in ports:
		assert_lt(tuning.body.crouch_eye_height, p.sill, "a crouched eye is under the sill at %s" % p.middle)
		assert_gt(tuning.body.stand_eye_height, p.sill, "a standing eye is over it at %s" % p.middle)
		assert_lt(tuning.body.stand_eye_height, p.lintel, "and under the lintel at %s" % p.middle)


func test_through_every_port_a_standing_eye_sees_out_and_a_crouched_one_does_not() -> void:
	var q := level.query()
	for p in _ports():
		for side: float in [1.0, -1.0]:
			var feet := _stand(p, side)
			var stand := feet + Vector3.UP * tuning.body.stand_eye_height
			var out := p.middle - p.through * side * (p.half_thick + SEE_OUT)
			out.y = stand.y
			assert_false(q.ray(stand, out, hit), "standing at %s sees out through the port at %s" % [feet, p.middle])
			var crouch := feet + Vector3.UP * tuning.body.crouch_eye_height
			var seen := 0
			for w: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				for y: float in [0.2, 0.6, 1.0, HIDDEN_TOP]:
					var target := p.middle - p.through * side * (p.half_thick + HIDDEN_AT) + p.along * w * p.half_width
					target.y = y
					if not q.ray(crouch, target, hit):
						seen += 1
			assert_eq(seen, 0, "crouched at %s nothing past the port at %s is seen" % [feet, p.middle])


func test_no_port_or_box_opening_can_be_vaulted() -> void:
	var q := level.query()
	var out := VaultState.new()
	var tried := 0
	for p in _ports():
		for side: float in [1.0, -1.0]:
			var feet := _stand(p, side) + Vector3.UP * tuning.body.rest_gap
			var way := -p.through * side
			assert_false(Vault.plan(feet, Vector2(way.x, way.z), tuning.vault.max_speed, tuning.vault, tuning.body, q, out),
					"the port at %s is not vaulted from %s" % [p.middle, feet])
			tried += 1
	# The Box's doors are walked through, never vaulted: one a side, from outside and in.
	for door: Vector2 in [Vector2(BOX_X.x + 0.1, -3.1), Vector2(BOX_X.y - 0.1, 1.7)]:
		for side: float in [1.0, -1.0]:
			var feet := Vector3(door.x + side * 0.8, tuning.body.rest_gap, door.y)
			assert_false(Vault.plan(feet, Vector2(-side, 0.0), tuning.vault.max_speed, tuning.vault, tuning.body, q, out),
					"the Box's door at %s is not vaulted" % door)
			tried += 1
	assert_eq(tried, PORTS * 2 + 4)


func test_a_bb_fired_up_inside_the_box_stops_on_its_roof() -> void:
	var sim := Simulation.new(tuning, level.query(), level.mover(tuning.body), map.ends, map.kill_y)
	var state := GameState.new(7, tuning)
	var you := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	state.characters.append(you)
	sim.start_match(state)
	you.position = Vector3(-0.2, tuning.body.rest_gap, -0.8)
	you.prev_position = you.position
	var cmds: Array[PlayerCommand] = [PlayerCommand.new()]
	cmds[0].reset(0.0, tuning.movement.max_pitch)
	cmds[0].fire = true
	var impact: GameEvent = null
	for i in 60:
		sim.step(state, cmds, DT)
		var e := state.events.first(GameEvent.Kind.BB_IMPACT)
		if e != null and e.target < 0:
			impact = e
			break
	assert_not_null(impact, "the BB landed")
	if impact != null:
		assert_between(impact.position.y, BOX_HEADROOM - 0.05, BOX_HEADROOM + ROOF_DRAWN, "on the roof's underside")
		assert_eq(impact.value2, RayHit.Surface.METAL)
		assert_between(impact.position.x, BOX_X.x, BOX_X.y)
		assert_between(impact.position.z, BOX_Z.x, BOX_Z.y)


## Where `route` (from outside) first crosses the Box's west or east wall: (x of the wall, z), or Vector2.INF.
func _box_entry(route: PackedVector3Array) -> Vector2:
	for i in range(1, route.size()):
		var a := route[i - 1]
		var b := route[i]
		for wall: float in [BOX_X.x, BOX_X.y]:
			if (a.x - wall) * (b.x - wall) > 0.0 or is_equal_approx(a.x, b.x):
				continue
			var z := lerpf(a.z, b.z, (wall - a.x) / (b.x - a.x))
			if z > BOX_Z.x and z < BOX_Z.y:
				return Vector2(wall, z)
	return Vector2.INF


func test_bots_from_each_end_walk_into_the_box_by_its_doors() -> void:
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var route := PackedVector3Array()
	var inside := Vector3(-0.2, 0.0, -0.8)
	# The west end comes in by the west door (north half), the east end by the east door (south half).
	var doors: Array[Vector3] = [Vector3(BOX_X.x, -3.6, -2.6), Vector3(BOX_X.y, 1.2, 2.2)]
	for e in map.ends.size():
		for s in map.ends[e].spawns:
			for vaults: bool in [false, true]:
				assert_true(nav.find_route(s.position, inside, route, vaults), "end %d reaches the Box" % e)
				var entry := _box_entry(route)
				var door := doors[e]
				assert_eq(entry.x, door.x, "end %d comes in on its side, from %s" % [e, s.position])
				assert_between(entry.y, door.y, door.z, "through the door, from %s" % s.position)
