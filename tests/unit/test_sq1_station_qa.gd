extends GutTest
## SQ1 QA: the rebuilt station props keep the bounds of the models before them (TQ1 head, ea789eb): the field sizes a
## prop by its mesh AABB, so a changed box stretches the prop. Every rebuilt prop still loads and keeps a surface.

const PROPS := "res://assets/models/props/"
const TOL := 0.002

const BEFORE := {
	"ballast_wagon": AABB(Vector3(-2.000, 0.000, -0.900), Vector3(4.000, 2.200, 1.800)),
	"buffer_stop": AABB(Vector3(-1.150, 0.000, -0.250), Vector3(2.300, 1.200, 0.500)),
	"cable_drum": AABB(Vector3(-1.000, 0.000, -0.700), Vector3(2.000, 1.800, 1.400)),
	"cable_drum_small": AABB(Vector3(-0.700, 0.000, -0.700), Vector3(1.400, 1.400, 1.400)),
	"crowd_barrier": AABB(Vector3(-0.996, -0.002, -0.300), Vector3(1.992, 1.102, 0.600)),
	"engineering_wagon": AABB(Vector3(-2.000, 0.000, -1.000), Vector3(4.000, 2.600, 2.000)),
	"escalator_lower": AABB(Vector3(-6.010, -18.000, -3.000), Vector3(16.020, 9.000, 6.000)),
	"fan_housing": AABB(Vector3(-1.500, 0.000, -1.250), Vector3(3.000, 2.200, 2.500)),
	"gate_paddle": AABB(Vector3(0.000, 0.470, -0.016), Vector3(0.462, 0.480, 0.032)),
	"help_point": AABB(Vector3(-0.700, 0.000, -0.700), Vector3(1.399, 2.200, 1.399)),
	"kiosk": AABB(Vector3(-1.500, 0.000, -1.300), Vector3(3.000, 2.500, 2.600)),
	"kiosk_long": AABB(Vector3(-2.600, 0.000, -1.000), Vector3(5.200, 2.800, 2.000)),
	"lift_car": AABB(Vector3(-1.150, -0.150, -0.900), Vector3(2.300, 2.700, 1.761)),
	"lift_landing": AABB(Vector3(-0.654, 0.000, -0.062), Vector3(1.559, 2.450, 0.362)),
	"lift_leaf": AABB(Vector3(-0.500, -0.500, -0.500), Vector3(1.000, 1.000, 1.000)),
	"platelayer_trolley": AABB(Vector3(-0.750, 0.000, -0.850), Vector3(1.500, 1.200, 1.700)),
	"platelayer_trolley_long": AABB(Vector3(-1.000, 0.000, -0.850), Vector3(2.000, 1.200, 1.700)),
	"platelayer_trolley_short": AABB(Vector3(-0.650, 0.000, -0.850), Vector3(1.300, 1.200, 1.700)),
	"platform_stair": AABB(Vector3(26.990, -18.000, -1.610), Vector3(18.520, 8.922, 3.220)),
	"signal_cabinet": AABB(Vector3(-0.450, 0.000, -0.400), Vector3(0.900, 2.200, 0.800)),
	"skip_wagon": AABB(Vector3(-1.000, 0.000, -1.000), Vector3(2.000, 2.700, 2.000)),
	"spiral_stair": AABB(Vector3(-32.860, -18.000, 0.640), Vector3(4.870, 8.000, 4.870)),
	"staff_booth": AABB(Vector3(-1.000, 0.000, -1.100), Vector3(2.000, 2.600, 2.200)),
	"staff_booth_mid": AABB(Vector3(-0.800, 0.000, -1.100), Vector3(1.600, 2.600, 2.200)),
	"staff_booth_small": AABB(Vector3(-0.800, 0.000, -0.500), Vector3(1.600, 2.600, 1.000)),
	"station_bench": AABB(Vector3(-1.000, 0.000, -0.295), Vector3(2.000, 0.799, 0.592)),
	"station_bench_long": AABB(Vector3(-1.500, 0.000, -0.295), Vector3(3.000, 0.799, 0.592)),
	"switch_cabinet": AABB(Vector3(-1.000, 0.000, -0.400), Vector3(2.000, 2.000, 0.800)),
	"ticket_gate": AABB(Vector3(-0.244, 0.000, -0.697), Vector3(0.488, 1.000, 1.388)),
	"ticket_machine": AABB(Vector3(-2.750, 0.000, -0.297), Vector3(5.500, 2.000, 0.599)),
	"ticket_office": AABB(Vector3(-3.000, 0.000, -1.750), Vector3(6.000, 3.000, 3.500)),
	"tunnel_grille": AABB(Vector3(-1.940, 0.000, 0.000), Vector3(3.880, 4.090, 0.120)),
	"tunnel_segments": AABB(Vector3(-1.000, 0.000, -0.950), Vector3(2.000, 1.300, 1.900)),
	"works_hoarding": AABB(Vector3(-1.500, 0.000, -0.950), Vector3(3.000, 2.400, 1.900)),
	"works_hoarding_deep": AABB(Vector3(-1.000, 0.000, -1.200), Vector3(2.000, 2.400, 2.400)),
	"works_hoarding_short": AABB(Vector3(-1.000, 0.000, -0.950), Vector3(2.000, 2.400, 1.900)),
}


func test_every_rebuilt_station_prop_keeps_its_bounds() -> void:
	for n: String in BEFORE:
		var mesh := PropDressConfig.load_mesh(PROPS + n + ".glb")
		assert_not_null(mesh, "%s loads" % n)
		if mesh == null:
			continue
		var want: AABB = BEFORE[n]
		var got := mesh.get_aabb()
		assert_lt(got.position.distance_to(want.position), TOL, "%s: box start %s, was %s" % [n, got.position, want.position])
		assert_lt(got.size.distance_to(want.size), TOL, "%s: box size %s, was %s" % [n, got.size, want.size])
		assert_gt(mesh.get_surface_count(), 0, "%s has a surface" % n)
