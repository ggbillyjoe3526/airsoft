extends GutTest
## PB3 (the owner's ruling, 2026-11-13): no animations on the bomb. While planting or defusing the replica is put away
## and drawn again after (Plant.hands_on), a bot crouches there, the bomb shows as a row in the weapon rail while you
## carry it (lit while you set it), and once armed the gauge under the score bar reads BOMB ARMED (test_pb1_ui). It is
## set down in front of the feet, in sight below the view, short of a wall (Plant.set_down, Plant.room_ahead).

const SITE := Vector3(20.0, 0.0, -10.0)

var cfg: PlantConfig
var events: SimEvents
var c: Character


## A world with one wall across -Z at `wall_z` (no wall: INF).
class Wall:
	extends WorldQuery
	var wall_z: float = INF

	func ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
		if wall_z == INF or to.z >= wall_z or from.z <= wall_z:
			return false
		var t := (from.z - wall_z) / (from.z - to.z)
		hit.position = from.lerp(to, t)
		return true


## A floor sloping up along -Z (y = -z * rise), for the ray down.
class Slope:
	extends WorldQuery
	var rise: float = 0.1

	func ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
		var y := -from.z * rise
		if from.y < y or to.y > y:
			return false
		hit.position = Vector3(from.x, y, from.z)
		return true


func before_each() -> void:
	cfg = PlantConfig.new()
	events = SimEvents.new()
	c = Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())


func test_hands_on_put_the_replica_away_and_off_draw_it_again() -> void:
	assert_true(Plant.hands_on(c, true, cfg, events))
	assert_true(c.hands_on_bomb)
	assert_true(c.armament.holstered, "away while the hands are on it")
	assert_true(Plant.hands_on(c, true, cfg, events), "held on: nothing more")
	assert_false(Plant.hands_on(c, false, cfg, events))
	assert_false(c.hands_on_bomb)
	assert_false(c.armament.holstered, "drawn again")
	assert_gt(c.armament.draw_left, 0.0, "over its draw time")
	assert_eq(events.count_of(GameEvent.Kind.DRAW), 1, "one draw, heard")


func test_a_replica_already_away_stays_away() -> void:
	c.armament.holstered = true
	Plant.hands_on(c, true, cfg, events)
	Plant.hands_on(c, false, cfg, events)
	assert_true(c.armament.holstered)
	assert_eq(events.count_of(GameEvent.Kind.DRAW), 0)


func test_one_hit_while_working_is_never_drawn_and_a_respawn_clears_it() -> void:
	Plant.hands_on(c, true, cfg, events)
	c.status = Character.Status.OUT
	Plant.hands_on(c, false, cfg, events)
	assert_true(c.armament.holstered, "out of play: nothing drawn")
	Plant.hands_on(c, true, cfg, events)
	c.respawn()
	assert_false(c.hands_on_bomb)
	assert_false(c.bomb_was_holstered)


func test_hands_off_without_hands_on_does_nothing() -> void:
	assert_false(Plant.hands_on(c, false, cfg, events))
	assert_false(c.armament.holstered)
	assert_eq(events.count_of(GameEvent.Kind.DRAW), 0)


func test_the_rail_carries_the_bomb_while_you_have_it_lit_while_you_set_it() -> void:
	var r := WeaponRail.new()
	add_child_autofree(r)
	var paints: Array[StringName] = [&"cobalt", &"cobalt"]
	r.setup(c.armament.replicas, paints)
	r.refresh(c.armament, c.grenades)
	var rows := r.rows()
	assert_false(r.bomb_shown(), "no bomb, no row")
	r.refresh(c.armament, c.grenades, WeaponRail.Carry.CARRIED)
	assert_true(r.bomb_shown())
	assert_eq(r.rows(), rows + 1)
	assert_eq(r.lit(), c.armament.active, "carried, the replica stays the one in hand")
	c.armament.put_down()
	r.refresh(c.armament, c.grenades, WeaponRail.Carry.SETTING)
	var bomb_row := c.armament.replicas.size() + WeaponRail.BOMB_ACTIONS.size()
	assert_eq(r.lit(), bomb_row, "setting it, the bomb's row is lit")
	r.refresh(c.armament, c.grenades, WeaponRail.Carry.NONE)
	assert_false(r.bomb_shown(), "armed or dropped: gone")
	assert_eq(WeaponRail.key_text(PlayerInput.USE_DOOR), r._keys[bomb_row].text, "named by the key that sets it")


func test_the_rail_carry_follows_the_carrier_and_the_planter() -> void:
	var rs := RoundState.new()
	rs.mode = RoundState.Mode.PLANT_THE_BOMB
	var ps := rs.plant
	ps.status = PlantState.Status.DOWN
	assert_eq(HudPlant.rail_carry(rs, c), WeaponRail.Carry.NONE)
	ps.status = PlantState.Status.CARRIED
	ps.carrier = c.id
	assert_eq(HudPlant.rail_carry(rs, c), WeaponRail.Carry.CARRIED)
	ps.planter = c.id
	assert_eq(HudPlant.rail_carry(rs, c), WeaponRail.Carry.SETTING)
	ps.carrier = 5
	ps.planter = 5
	assert_eq(HudPlant.rail_carry(rs, c), WeaponRail.Carry.NONE, "someone else's")
	ps.carrier = c.id
	ps.planter = -1
	rs.mode = RoundState.Mode.ELIMINATION
	assert_eq(HudPlant.rail_carry(rs, c), WeaponRail.Carry.NONE, "no bomb in other modes")


func test_the_bomb_is_set_ahead_of_the_feet_and_short_of_a_wall() -> void:
	var feet := Vector3(2.0, 0.5, 3.0)
	var at := Plant.set_down(feet, 0.0, cfg)
	assert_almost_eq(at, feet + Vector3(0.0, 0.0, -cfg.set_ahead), Vector3.ONE * 1e-5, "set_ahead in front, on the floor")
	var near := Plant.set_down(feet, 0.0, cfg, cfg.set_clear + 0.2)
	assert_almost_eq(feet.z - near.z, 0.2, 1e-5, "set_clear short of the wall")
	var flush := Plant.set_down(feet, 0.0, cfg, 0.05)
	assert_almost_eq(flush.z, feet.z, 1e-5, "never behind the feet")
	var turned := Plant.set_down(feet, PI / 2.0, cfg)
	assert_almost_eq(turned, feet + Vector3(-cfg.set_ahead, 0.0, 0.0), Vector3.ONE * 1e-5, "along the facing")


func test_the_room_ahead_is_measured_along_the_facing_at_its_height() -> void:
	var world := Wall.new()
	var hit := RayHit.new()
	assert_eq(Plant.room_ahead(Vector3.ZERO, 0.0, cfg, world, hit), INF, "nothing ahead")
	world.wall_z = -0.4
	assert_almost_eq(Plant.room_ahead(Vector3.ZERO, 0.0, cfg, world, hit), 0.4, 1e-5)
	assert_eq(Plant.room_ahead(Vector3.ZERO, 0.0, cfg, null, null), INF, "no world: room enough")


func test_keyed_in_it_stands_armed_where_it_was_set_down_facing_the_planter() -> void:
	var ps := PlantState.new()
	ps.set_sites(PackedVector3Array([SITE]), PackedFloat32Array([0.0]), 4.0)
	ps.start = Vector3.ZERO
	ps.reset()
	cfg.plant_time = 0.5
	c.position = SITE
	c.yaw = 0.7
	c.grounded = true
	c.using = true
	ps.status = PlantState.Status.CARRIED
	ps.carrier = c.id
	ps.set_room = 0.4
	var characters: Array[Character] = [c]
	Plant.step(ps, characters, c.team, cfg, events, 0.1)
	var at := Plant.set_down(SITE, 0.7, cfg, 0.4)
	assert_eq(ps.planter, c.id)
	assert_almost_eq(ps.facing, 0.7, 1e-6, "the way they faced as they began")
	assert_almost_eq(ps.set_at, at, Vector3.ONE * 1e-5, "set short of what was ahead")
	c.yaw = 2.0
	for i in 10:
		Plant.step(ps, characters, c.team, cfg, events, 0.1)
	assert_true(ps.planted())
	assert_almost_eq(ps.position, at, Vector3.ONE * 1e-5, "armed where it was set down, not where they turned")
	ps.reset()
	c.position = SITE + Vector3(3.9, 0.0, 0.0)
	c.yaw = -PI / 2.0
	ps.status = PlantState.Status.CARRIED
	ps.carrier = c.id
	Plant.step(ps, characters, c.team, cfg, events, 0.1)
	assert_almost_eq(Vector2(ps.set_at.x - SITE.x, ps.set_at.z - SITE.z).length(), 4.0, 1e-4,
			"set down past the ring's edge, it is drawn in onto it")
	ps.reset()
	assert_eq(ps.set_room, INF, "a new round: the room forgotten")
	assert_eq(ps.set_at, ps.start)


func test_set_on_a_slope_it_lies_on_the_ground_there() -> void:
	var slope := Slope.new()
	var hit := RayHit.new()
	assert_almost_eq(Plant.floor_at(Vector3(0.0, 0.0, -0.5), cfg, slope, hit), 0.05, 1e-5, "the floor ahead, up the slope")
	assert_true(is_inf(Plant.floor_at(Vector3(0.0, 2.0, -0.5), cfg, slope, hit)), "nothing within set_drop: no floor")
	assert_true(is_nan(Plant.floor_at(Vector3.ZERO, cfg, null, null)), "no world: the carrier's own floor")
	var ps := PlantState.new()
	ps.set_sites(PackedVector3Array([SITE]), PackedFloat32Array([0.0]), 4.0)
	ps.reset()
	assert_true(is_nan(ps.set_floor))
	c.position = SITE
	c.grounded = true
	c.using = true
	ps.status = PlantState.Status.CARRIED
	ps.carrier = c.id
	ps.set_floor = 0.07
	var characters: Array[Character] = [c]
	Plant.step(ps, characters, c.team, cfg, events, 0.1)
	assert_almost_eq(ps.set_at.y, 0.07, 1e-6, "set at the floor found there")


func test_with_no_floor_ahead_it_goes_at_the_feet_never_in_the_air() -> void:
	var ps := PlantState.new()
	ps.set_sites(PackedVector3Array([SITE]), PackedFloat32Array([0.0]), 4.0)
	ps.reset()
	c.position = SITE + Vector3(0.0, 0.4, 0.0)
	c.grounded = true
	c.using = true
	ps.status = PlantState.Status.CARRIED
	ps.carrier = c.id
	ps.set_floor = INF
	var characters: Array[Character] = [c]
	Plant.step(ps, characters, c.team, cfg, events, 0.1)
	assert_eq(ps.planter, c.id)
	assert_eq(ps.set_at, c.position, "a ledge ahead: at the feet")


func test_the_spot_is_drawn_into_the_ring_before_its_floor_is_looked_for() -> void:
	var ps := PlantState.new()
	ps.set_sites(PackedVector3Array([SITE]), PackedFloat32Array([0.0]), 4.0)
	var feet := SITE + Vector3(3.9, 0.0, 0.0)
	var spot := Plant.set_spot(ps, feet, -PI / 2.0, cfg)
	assert_almost_eq(Vector2(spot.x - SITE.x, spot.z - SITE.z).length(), 4.0, 1e-4, "on the ring, not past it")
	var outside := SITE + Vector3(10.0, 0.0, 0.0)
	assert_almost_eq(Plant.set_spot(ps, outside, 0.0, cfg), Plant.set_down(outside, 0.0, cfg), Vector3.ONE * 1e-5,
			"outside every site: just ahead")


func test_setting_it_hides_the_carry_line_and_the_holstered_note() -> void:
	var rs := RoundState.new()
	rs.mode = RoundState.Mode.PLANT_THE_BOMB
	rs.phase = RoundState.Phase.LIVE
	rs.hold = 0.0
	rs.attackers = c.team
	rs.plant.status = PlantState.Status.CARRIED
	rs.plant.carrier = c.id
	assert_true(HudPlant.carrying(rs, c), "carried: the quiet line")
	rs.plant.planter = c.id
	assert_false(HudPlant.carrying(rs, c), "being set down: the PLANTING gauge says it")
	var panel := ReplicaPanel.new()
	add_child_autofree(panel)
	panel.setup(HudConfig.new())
	c.armament.put_down()
	panel.refresh(c.armament, c.grenades)
	assert_eq(panel._status.text, "HOLSTERED", "holstered by the player: said")
	panel.refresh(c.armament, c.grenades, true)
	assert_false(panel._status.visible, "away for the bomb: the rail's bomb row says what is in hand")
