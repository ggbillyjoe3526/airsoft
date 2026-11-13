extends GutTest
## PB3 QA: the bomb's hands through a real session (replica away and back, no forced crouch, set down ahead), a carrier
## hit mid-plant, a round reset with the hands on, and who sees the rail row.

const SITE := Vector3(20.0, 0.0, -10.0)

var cfg: PlantConfig
var events: SimEvents
var c: Character


func before_each() -> void:
	cfg = PlantConfig.new()
	events = SimEvents.new()
	c = Character.new(0, 0, SITE, 0.0, ReplicaStats.default_loadout())
	c.grounded = true


func after_each() -> void:
	Input.action_release(PlayerInput.USE_DOOR)
	get_tree().paused = false


func _carried_state() -> PlantState:
	var ps := PlantState.new()
	ps.set_sites(PackedVector3Array([SITE]), PackedFloat32Array([0.0]), 4.0)
	ps.start = Vector3.ZERO
	ps.reset()
	ps.status = PlantState.Status.CARRIED
	ps.carrier = c.id
	ps.rest = Vector3(1.0, 0.0, 1.0)
	return ps


func test_a_carrier_hit_mid_plant_drops_it_at_rest_not_where_it_would_stand() -> void:
	var ps := _carried_state()
	cfg.plant_time = 1.0
	c.using = true
	var characters: Array[Character] = [c]
	Plant.step(ps, characters, c.team, cfg, events, 0.1)
	assert_eq(ps.planter, c.id)
	assert_ne(ps.set_at, ps.rest)
	c.status = Character.Status.OUT
	Plant.step(ps, characters, c.team, cfg, events, 0.1)
	assert_eq(ps.status, PlantState.Status.DOWN)
	assert_eq(ps.planter, -1)
	assert_eq(ps.position, ps.rest, "dropped on the last floor stood on")
	assert_eq(ps.planting, 0.0)


func test_a_new_attempt_measures_the_set_down_afresh() -> void:
	var ps := _carried_state()
	c.using = true
	c.yaw = 0.0
	var characters: Array[Character] = [c]
	ps.set_room = 0.3
	Plant.step(ps, characters, c.team, cfg, events, 0.1)
	var first := ps.set_at
	c.using = false
	Plant.step(ps, characters, c.team, cfg, events, 0.1)
	assert_eq(ps.planter, -1)
	c.using = true
	c.yaw = PI
	ps.set_room = INF
	Plant.step(ps, characters, c.team, cfg, events, 0.1)
	assert_ne(ps.set_at, first)
	assert_almost_eq(ps.facing, PI, 1e-6)


func test_the_set_down_stands_at_the_carriers_height() -> void:
	var ps := _carried_state()
	c.position = SITE + Vector3(0.0, 0.3, 0.0)
	c.using = true
	var characters: Array[Character] = [c]
	Plant.step(ps, characters, c.team, cfg, events, 0.1)
	assert_eq(ps.planter, c.id)
	assert_almost_eq(ps.set_at.y, c.position.y, 1e-5, "on the step the planter stands on")


func test_a_bots_carry_never_lights_the_players_rail() -> void:
	var rs := RoundState.new()
	rs.mode = RoundState.Mode.PLANT_THE_BOMB
	var player := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	rs.plant.status = PlantState.Status.CARRIED
	rs.plant.carrier = 7
	rs.plant.planter = 7
	assert_eq(HudPlant.rail_carry(rs, player), WeaponRail.Carry.NONE)
	rs.plant.status = PlantState.Status.PLANTED
	rs.plant.carrier = player.id
	assert_eq(HudPlant.rail_carry(rs, player), WeaponRail.Carry.NONE, "armed: carried no more")


func test_a_rail_without_a_bomb_row_ignores_the_carry_without_error() -> void:
	var r := WeaponRail.new()
	add_child_autofree(r)
	var paints: Array[StringName] = [&"cobalt"]
	r.setup([c.armament.replicas[0]], paints)
	r.refresh(c.armament, c.grenades, WeaponRail.Carry.SETTING)
	assert_true(r.bomb_shown())
	assert_eq(r.lit(), 1 + WeaponRail.BOMB_ACTIONS.size())
	r.refresh(c.armament, c.grenades, WeaponRail.Carry.NONE)
	assert_false(r.bomb_shown())


func test_in_a_session_hands_on_the_bomb_put_the_replica_away_and_a_crouch_is_not_forced() -> void:
	var s := PlaySession.new()
	s.mode = MatchOptions.MODE_PLANT_THE_BOMB
	s.map_id = "depot"
	s.player_team = 0
	s.bots_active = false
	add_child_autofree(s)
	await wait_physics_frames(2)
	var ps := s.state.round_state.plant
	var p := s.player
	RoundHold.release(s.state)
	p.position = ps.position + Vector3(0.6, 0.0, 0.0)
	Input.action_press(PlayerInput.USE_DOOR)
	await wait_physics_frames(6)
	assert_eq(ps.carrier, p.id)
	Input.action_release(PlayerInput.USE_DOOR)
	await wait_physics_frames(2)
	var site := ps.sites[0]
	p.position = site
	p.velocity = Vector3.ZERO
	Input.action_press(PlayerInput.USE_DOOR)
	await wait_physics_frames(10)
	assert_eq(ps.planter, p.id, "arming")
	assert_true(p.hands_on_bomb)
	assert_true(p.armament.holstered)
	assert_lt(p.crouch_amount, 0.2, "standing planter is not made to crouch")
	assert_lte(Vector2(ps.set_at.x - p.position.x, ps.set_at.z - p.position.z).length(), cfg.set_ahead + 0.01)
	Input.action_release(PlayerInput.USE_DOOR)
	await wait_physics_frames(3)
	assert_false(p.hands_on_bomb, "let go")
	assert_false(p.armament.holstered, "replica drawn again")
