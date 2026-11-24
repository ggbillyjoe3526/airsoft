extends GutTest
## DG1: what the player sees meets a prop where it is drawn, never the box it stands in for. Each test drives the class
## that casts the line (ReplicaView's pull-back, FigureView's raise, TorchBeams' spot, ThrownMagazines' landing) on a
## level whose boxes and drawn faces differ, as over the train's tool trolley: put `ray` back in any of them and its
## test fails.

const DT := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 0.0)

var body: BodyConfig = null


## A level whose boxes answer `ray` while `drawn` (the level as drawn) answers the sight and drawn rays: a box with
## nothing drawn in it is the air over a prop's tray.
class DrawnWorld:
	extends BoxWorld
	var drawn: BoxWorld = null
	## The lines cast on the boxes and by sight.
	var rays: int = 0
	var sights: int = 0

	func ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
		rays += 1
		return super.ray(from, to, hit)

	func sight_ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
		sights += 1
		return drawn.ray(from, to, hit)

	func drawn_ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
		return drawn.ray(from, to, hit)


func before_all() -> void:
	body = BodyConfig.new()


## A level with a stand-in box 2 m wide and 3 m high, its face `distance` m ahead (-Z), drawn as `drawn`'s boxes.
func _world(distance: float, drawn: BoxWorld) -> DrawnWorld:
	var w := DrawnWorld.new(body)
	w.add_box(Vector3(0.0, 1.5, -distance - 0.1), Vector3(2.0, 3.0, 0.2))
	w.drawn = drawn
	return w


func _character(slot: int = 0) -> Character:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	c.armament.active = slot
	return c


func _held_pull(world: WorldQuery) -> float:
	var c := _character()
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(ViewModelConfig.new(), c.armament.replicas, world)
	for i in 60:
		hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
	return hands._pull


func test_a_held_replica_is_not_pulled_back_against_a_box_with_nothing_drawn_in_it() -> void:
	var boxed := BoxWorld.new(body)
	boxed.add_box(Vector3(0.0, 1.5, -0.4), Vector3(2.0, 3.0, 0.2))
	assert_gt(_held_pull(boxed), 0.1, "a wall drawn 0.3 m ahead pulls it back (the harness can tell)")
	assert_eq(_held_pull(_world(0.3, BoxWorld.new(body))), 0.0, "the air over a tray pulls nothing")


func _raised(world: WorldQuery) -> float:
	var config := FigureConfig.new()
	var models := FigureModels.new(config)
	models.load_kinds()
	var c := _character()
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, HitConfig.new(), null)
	v.set_body(models, FigureMix.HUMAN, config.lod_high)
	v.set_world(world, body)
	for i in 40:
		v.update(c, 1.0)
		v.animate(c, 1.0, DT, Vector3(0.0, 1.6, 3.0))
	return v.body().bend.high_ready


func test_a_figure_does_not_raise_its_replica_at_a_box_with_nothing_drawn_in_it() -> void:
	var boxed := BoxWorld.new(body)
	boxed.add_box(Vector3(0.0, 1.5, -0.55), Vector3(2.0, 3.0, 0.2))
	assert_gt(_raised(boxed), 0.9, "raised at a wall drawn 0.45 m ahead (the harness can tell)")
	assert_eq(_raised(_world(0.45, BoxWorld.new(body))), 0.0, "level at the air over a tray")


func test_a_torch_spot_lands_on_the_drawn_face_behind_a_box_with_nothing_drawn_in_it() -> void:
	var drawn := BoxWorld.new(body)
	drawn.add_box(Vector3(0.0, 1.5, -8.1), Vector3(4.0, 3.0, 0.2))
	var world := _world(2.0, drawn)
	world.add_box(Vector3(0.0, 1.5, -8.1), Vector3(4.0, 3.0, 0.2))
	var beams := TorchBeams.new()
	add_child_autofree(beams)
	beams.setup(2, world, body)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.position = Vector3(0.0, 1.6, 5.0)
	var c := _character()
	var light := Torch.Light.new()
	light.reach = 20.0
	light.spill_deg = 30.0
	var lights: Array[Torch.Light] = []
	for r in c.armament.replicas:
		lights.append(light)
	c.armament.lights = lights
	c.torch_on = true
	var figures: Array[FigureView] = []
	beams.update([c] as Array[Character], null, 1.0, figures, camera)
	var spots := (beams.get_node("Spots") as MultiMeshInstance3D).multimesh
	assert_eq(spots.visible_instance_count, 1, "one spot")
	# A headless multimesh keeps no transforms, so the line itself is judged: the eye's, which passes the box.
	assert_eq(world.sights, 1, "the spot's line is the eye's")
	assert_eq(world.rays, 0, "never the boxes' ray, which would land it on the box 2 m ahead")


func test_a_tossed_magazine_is_drawn_landing_on_the_drawn_floor_not_a_box_over_it() -> void:
	var drawn := BoxWorld.new(body)
	drawn.add_box(Vector3(0.0, -0.05, 0.0), Vector3(2.0, 0.1, 2.0))
	var world := DrawnWorld.new(body)
	world.add_box(Vector3(0.0, 0.25, 0.0), Vector3(2.0, 0.5, 2.0))
	world.drawn = drawn
	var t := ThrownMagazines.new()
	t.setup(2)
	add_child_autofree(t)
	t.set_world(world, 2.0, 0.5)
	assert_almost_eq(t.landing_height(Vector3(0.0, 1.0, 0.0), Vector3.ZERO, 1.0, 9.8), 0.0, 0.001,
			"on the drawn floor, not the box's top at 0.5 m")
