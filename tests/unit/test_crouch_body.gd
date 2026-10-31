extends GutTest
## The crouched body (CR1): crouched past the threshold a character's collision body is BodyConfig.crouch_height tall,
## it goes under anything that high and stays crouched there whatever is held; the nav grid walks a crouched body under
## such a roof and marks those floors low, and bots and walk-offs crouch through them.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.new()
var body: BodyConfig = tuning.body


## A floor with a roof over the strip x in [-1, 1] from z = -2 to z = -6, its underside `clear` over the floor, and
## walls either side of the strip up to the roof.
func _tunnel(clear: float) -> BoxWorld:
	var w := BoxWorld.new(body)
	w.add_floor(40.0, 40.0)
	w.add_box(Vector3(0.0, clear + 0.25, -4.0), Vector3(2.0, 0.5, 4.0))
	w.add_box(Vector3(-1.25, clear * 0.5, -4.0), Vector3(0.5, clear, 4.0))
	w.add_box(Vector3(1.25, clear * 0.5, -4.0), Vector3(0.5, clear, 4.0))
	return w


func _walk(w: BoxWorld, c: Character, cmd: PlayerCommand, ticks: int) -> void:
	var m := w.mover()
	for i in ticks:
		Movement.step(c, cmd, tuning.movement, tuning.accuracy, DT, m)


func _heading_north(crouch: bool) -> PlayerCommand:
	var cmd := PlayerCommand.new()
	cmd.yaw = 0.0 # facing -Z
	cmd.forward = 1.0
	cmd.crouch = crouch
	return cmd


func test_the_crouched_body_fits_the_tunnels_and_the_crouched_figure_fits_it() -> void:
	assert_lt(body.crouch_height, 1.4, "under Woodland's 1.4 m tunnels")
	assert_gt(body.crouch_height, body.crouch_eye_height, "over the crouched eyes")
	assert_gt(body.crouch_height, Hitbox.hit_top(1.0, tuning.hits), "over the crouched figure's head")


func test_standing_a_roof_lower_than_the_body_stops_you_and_crouched_you_go_under() -> void:
	var w := _tunnel(1.4)
	var c := Character.new(0, 0, Vector3(0.0, body.rest_gap, 0.0))
	_walk(w, c, _heading_north(false), 120)
	assert_false(c.low)
	assert_almost_eq(c.position.z, -2.0 + body.radius, 0.02, "standing: stopped a radius short of the roof")
	var d := Character.new(1, 0, Vector3(0.0, body.rest_gap, 0.0))
	_walk(w, d, _heading_north(true), 600)
	assert_lt(d.position.z, -7.0, "crouched: through and out the far end")


func test_under_the_roof_letting_go_of_crouch_keeps_you_down_until_you_are_out() -> void:
	var w := _tunnel(1.4)
	var c := Character.new(0, 0, Vector3(0.0, body.rest_gap, -1.0))
	_walk(w, c, _heading_north(true), 90)
	assert_lt(c.position.z, -3.0, "inside")
	var stop := PlayerCommand.new()
	_walk(w, c, stop, 30)
	assert_true(c.low, "kept low under the roof")
	assert_almost_eq(c.crouch_amount, 1.0, 1e-6, "fully crouched")
	assert_false(w.mover().room_to_stand(c))
	_walk(w, c, _heading_north(false), 300)
	assert_lt(c.position.z, -6.5, "walks out crouched without crouch held")
	_walk(w, c, stop, 30)
	assert_false(c.low, "stands once out")
	assert_eq(c.crouch_amount, 0.0)


func test_out_in_the_open_crouch_and_stand_are_as_before() -> void:
	var w := _tunnel(1.4)
	var c := Character.new(0, 0, Vector3(5.0, body.rest_gap, 5.0))
	var cmd := PlayerCommand.new()
	cmd.crouch = true
	_walk(w, c, cmd, 30)
	assert_true(c.low)
	assert_true(w.mover().room_to_stand(c))
	cmd.crouch = false
	_walk(w, c, cmd, 30)
	assert_false(c.low)
	assert_eq(c.crouch_amount, 0.0)


func test_a_roof_lower_than_the_crouched_body_stops_you_crouched_too() -> void:
	var w := _tunnel(1.1)
	var c := Character.new(0, 0, Vector3(0.0, body.rest_gap, 0.0))
	_walk(w, c, _heading_north(true), 300)
	assert_almost_eq(c.position.z, -2.0 + body.radius, 0.02)


## A map of flat ground 20 m square and `blocks`.
static func _map(blocks: Array[MapData.Block]) -> MapData:
	var m := MapData.new()
	m.id = "tunnel"
	m.terrain = TerrainGrid.create(-10.0, -10.0, 1.0, 20, 20, func(_x: float, _z: float) -> float: return 0.0)
	m.blocks = blocks
	return m


static func _block(kind: StringName, center: Vector3, size: Vector3) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = kind
	b.center = center
	b.size = size
	return b


## A roof 4 m long over x in [-1, 1], its underside `clear` over the ground, on two side walls.
func _tunnel_grid(clear: float) -> NavGrid:
	var blocks: Array[MapData.Block] = [
		_block(&"plywood", Vector3(0.0, clear + 0.25, -4.0), Vector3(3.0, 0.5, 4.0)),
		_block(&"plywood", Vector3(-1.25, clear * 0.5, -4.0), Vector3(0.5, clear, 4.0)),
		_block(&"plywood", Vector3(1.25, clear * 0.5, -4.0), Vector3(0.5, clear, 4.0)),
	]
	return NavGrid.build(_map(blocks), tuning.nav, body)


func test_the_grid_walks_a_crouched_body_under_a_tunnel_s_roof_and_marks_it_low() -> void:
	var g := _tunnel_grid(1.4)
	var inside := g.node_at(Vector3(0.0, 0.0, -4.0))
	assert_gte(inside, 0)
	assert_eq(g.walkable[inside], 1, "walkable under a 1.4 m roof")
	assert_eq(g.low[inside], 1, "low")
	var open := g.node_at(Vector3(5.0, 0.0, 5.0))
	assert_eq(g.low[open], 0, "the open ground isn't")
	assert_eq(g.low[g.node_at(Vector3(0.0, 0.0, -1.0))], 0, "a metre short of the mouth isn't")
	var route := PackedVector3Array()
	assert_true(g.find_route(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -8.0), route), "a route through")
	assert_eq(route.size(), 1, "straight through: %s" % route)
	assert_true(g.low_ahead(Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, -1.0), 1.0), "the mouth a metre ahead")
	assert_false(g.low_ahead(Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -1.0), 1.0), "two metres short")


func test_a_roof_too_low_to_crawl_under_blocks_and_a_high_one_is_open() -> void:
	var too_low := _tunnel_grid(1.1)
	assert_eq(too_low.walkable[too_low.node_at(Vector3(0.0, 0.0, -4.0))], 0, "a 1.1 m roof blocks")
	var high := _tunnel_grid(2.0)
	var k := high.node_at(Vector3(0.0, 0.0, -4.0))
	assert_eq(high.walkable[k], 1)
	assert_eq(high.low[k], 0, "a 2 m roof is stood under")


func test_a_walk_off_crouches_into_a_tunnel_and_not_in_the_open() -> void:
	var g := _tunnel_grid(1.4)
	var c := Character.new(0, 0, Vector3(0.0, 0.0, -1.0))
	c.status = Character.Status.WALKING_OFF
	c.walk_off_route = PackedVector3Array([Vector3(0.0, 0.0, -8.0)])
	c.dead_zone_target = Vector3(0.0, 0.0, -8.0)
	var cmd := Elimination.fill_eliminated_command(c, tuning, PlayerCommand.new(), g)
	assert_true(cmd.crouch, "the mouth ahead")
	c.position = Vector3(0.0, 0.0, 3.0)
	cmd = Elimination.fill_eliminated_command(c, tuning, PlayerCommand.new(), g)
	assert_false(cmd.crouch, "in the open")
