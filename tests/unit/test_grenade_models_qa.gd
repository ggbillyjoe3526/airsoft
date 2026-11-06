extends GutTest
## BL9 QA: the bomb models as GrenadeView lays them: lying on the ground, a reused slot changing kind, the bomb in hand.

const DT := 1.0 / 60.0
const SINK_SLACK := 0.002

var tuning: SimTuning = SimTuning.new()
var cfg: GrenadeConfig = tuning.grenades


func _view(count: int) -> GrenadeView:
	var v := GrenadeView.new()
	add_child_autofree(v)
	v.setup(count, cfg, false)
	return v


func _lowest(mesh: Mesh, basis: Basis) -> float:
	var lo := INF
	for s in mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for p in verts:
			lo = minf(lo, (basis * p).y)
	return lo


func test_a_bomb_at_rest_lies_on_the_ground_with_no_part_of_its_model_below_it() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s.grenades.size())
	var kinds: Array[Grenade.Kind] = [Grenade.Kind.SMOKE, Grenade.Kind.FLASH]
	for i in kinds.size():
		var g := s.grenades[i]
		g.launch(kinds[i], 0, Vector3(float(i), cfg.radius, 0.0), Vector3.ZERO)
		g.resting = true
		v.update(s, 1.0, DT, null, Vector3.ZERO)
		var m := v.get_child(i) as MeshInstance3D
		var low := m.transform.origin.y + _lowest(m.mesh, m.transform.basis)
		var ground := g.position.y - cfg.radius
		assert_gte(low, ground - SINK_SLACK, "kind %d: its lowest point %.4f m under the ground" % [kinds[i], ground - low])
		assert_lte(low, ground + SINK_SLACK, "kind %d: not floating %.4f m above it" % [kinds[i], low - ground])


func test_a_slot_reused_for_the_other_kind_draws_that_kinds_model() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s.grenades.size())
	var g := s.grenades[0]
	g.launch(Grenade.Kind.SMOKE, 0, Vector3(0.0, 1.0, 0.0), Vector3.ZERO)
	v.update(s, 0.0, DT, null, Vector3.ZERO)
	var m := v.get_child(0) as MeshInstance3D
	assert_eq(m.mesh, v.mesh_of(Grenade.Kind.SMOKE))
	g.active = false
	v.update(s, 0.0, DT, null, Vector3.ZERO)
	g.launch(Grenade.Kind.FLASH, 0, Vector3(0.0, 1.0, 0.0), Vector3.ZERO)
	v.update(s, 0.0, DT, null, Vector3.ZERO)
	assert_eq(m.mesh, v.mesh_of(Grenade.Kind.FLASH), "the flash's model, not the smoke's left behind")
	assert_ne(v.mesh_of(Grenade.Kind.FLASH), v.mesh_of(Grenade.Kind.SMOKE))


func test_the_bomb_in_hand_is_the_kinds_own_model_and_changes_with_the_kind() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s.grenades.size())
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var held: MeshInstance3D = null
	for child in v.get_children():
		if child.name == "Held":
			held = child.get_node("Bomb") as MeshInstance3D
	assert_not_null(held)
	c.grenades.throwing = Grenade.Kind.SMOKE
	c.grenades.windup_left = cfg.windup
	v.update(s, 0.0, DT, c, Vector3(0.0, 1.6, 0.0))
	assert_eq(held.mesh, v.mesh_of(Grenade.Kind.SMOKE))
	c.grenades.throwing = Grenade.Kind.FLASH
	v.update(s, 0.0, DT, c, Vector3(0.0, 1.6, 0.0))
	assert_eq(held.mesh, v.mesh_of(Grenade.Kind.FLASH))
