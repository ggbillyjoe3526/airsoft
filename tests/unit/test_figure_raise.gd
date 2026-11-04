extends GutTest
## FB5: a figure's replica muzzle up at a wall (game/play/figure_view.gd's ray, figure_pose.gd's raise, figure_bend.gd's
## high ready, figure_ready.gd): facing a wall within reach, no part of the rifle or the pistol drawn past its face
## (through it without the raise); facing a crate as high as the rifle, the rifle's muzzle above its top and nothing
## past its face below the top; the hands under the head (never the hit call's raised hand); level again with nothing
## in reach, after a shot, holstered and calling the hit (the replica hanging straight down within the body); one ray a
## raise_stride.
## Drawn only: the character's aim is never touched. Read as the skeleton finishes updating (test_figure_hands.gd).

const EYE := Vector3(0.0, 1.6, 3.0)
const FRAME := 1.0 / 60.0
## How far (m) the box round the replica may reach past a face: its corners stand off the real model.
const SLACK := 0.03

var config: FigureConfig = null
var models: FigureModels = null
var hits: HitConfig = null
var body: BodyConfig = null
## The replica in the hand as last drawn, by figure: its box's corners and its muzzle in the figure's frame.
var _corners: Dictionary[FigureView, PackedVector3Array] = {}
var _muzzle: Dictionary[FigureView, Vector3] = {}
## The higher hand's height over the Head bone's (m), as last drawn.
var _hands_over_head: Dictionary[FigureView, float] = {}


## A level whose rays are counted.
class CountedWorld:
	extends BoxWorld
	var rays: int = 0

	func ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
		rays += 1
		return super.ray(from, to, hit)


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()
	hits = HitConfig.new()
	body = BodyConfig.new()


func _character(slot: int) -> Character:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	c.armament.active = slot
	return c


## A figure of `kind` for `c`, raised at `world`'s walls (never with `world` null).
func _view(kind: int, c: Character, world: WorldQuery) -> FigureView:
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, hits, null)
	v.set_body(models, kind, config.lod_high)
	if world != null:
		v.set_world(world, body)
	var hands := v.body().hands
	var sk := v.body().skeleton
	sk.skeleton_updated.connect(func() -> void:
		var head := sk.get_bone_global_pose(sk.find_bone("Head")).origin.y
		_hands_over_head[v] = maxf(sk.get_bone_global_pose(sk.find_bone("Hand_L")).origin.y,
				sk.get_bone_global_pose(sk.find_bone("Hand_R")).origin.y) - head
		var r := hands.replica(hands.in_hand)
		if r == null or not r.visible:
			_corners.erase(v)
			return
		var to_figure := v.global_transform.affine_inverse() * r.global_transform
		var box := r.get_aabb()
		var corners := PackedVector3Array()
		for i in 8:
			corners.append(to_figure * box.get_endpoint(i))
		_corners[v] = corners
		_muzzle[v] = v.global_transform.affine_inverse() * v.muzzle_position(hands.in_hand))
	return v


## Poses `v` from `c` for `frames` frames and waits for the skeleton to draw it.
func _pose(v: FigureView, c: Character, frames: int = 40, shooting: bool = false) -> void:
	for i in frames:
		if shooting:
			v.on_shot()
		v.update(c, 1.0)
		v.animate(c, 1.0, FRAME, EYE)
	await wait_process_frames(1)


## How far ahead (m, the figure faces -Z) the replica's box reaches as last drawn.
func _ahead(v: FigureView) -> float:
	var most := -INF
	for p: Vector3 in _corners.get(v, PackedVector3Array()):
		most = maxf(most, -p.z)
	return most


## A wall 4 m wide and 3 m high, its face `distance` m ahead of the figure.
static func _wall(world: BoxWorld, distance: float) -> void:
	world.add_box(Vector3(0.0, 1.5, -distance - 0.1), Vector3(4.0, 3.0, 0.2))


func test_facing_a_wall_within_reach_no_replica_passes_its_face() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		# The rifle (slot 0) and the pistol (slot 1), at walls from just inside reach to the body's own edge.
		for slot: int in [0, 1]:
			for distance: float in [0.9, 0.6, 0.45, body.radius + 0.03]:
				var c := _character(slot)
				var world := BoxWorld.new(body)
				_wall(world, distance)
				var v := _view(kind, c, world)
				await _pose(v, c)
				assert_lte(_ahead(v), distance + SLACK,
						"kind %d slot %d short of a wall %.2f m ahead" % [kind, slot, distance])
				assert_lt(_hands_over_head[v], 0.0, "the hands under the head")
				var bare := _view(kind, c, null)
				await _pose(bare, c)
				if distance < 0.55:
					assert_gt(_ahead(bare), distance + SLACK, "without the raise it went through (%.2f m)" % distance)
	assert_eq(_character(0).pitch, 0.0, "the aim untouched")


func test_facing_a_crate_as_high_as_the_rifle_the_muzzle_clears_its_top() -> void:
	var top := 1.5
	for slot: int in [0, 1]:
		var c := _character(slot)
		var world := BoxWorld.new(body)
		world.add_box(Vector3(0.0, top * 0.5, -0.45 - 0.5), Vector3(1.0, top, 1.0))
		var v := _view(FigureMix.HUMAN, c, world)
		await _pose(v, c)
		if slot == 0:
			assert_gt(_muzzle[v].y, top, "the rifle's muzzle above the crate")
		for p: Vector3 in _corners[v]:
			if -p.z > 0.45 + SLACK:
				assert_gt(p.y, top - SLACK, "slot %d: what reaches past the face is above the top" % slot)


func test_level_with_nothing_in_reach() -> void:
	var c := _character(0)
	var world := BoxWorld.new(body)
	_wall(world, 2.0)
	var v := _view(FigureMix.HUMAN, c, world)
	await _pose(v, c)
	# The BL1 rifle is the owner's ~67 cm carbine (2026-11-04 "as short as the photos"), so it reaches 0.72 m ahead.
	assert_almost_eq(_ahead(v), 0.72, 0.03, "the rifle held out level")
	assert_almost_eq(_muzzle[v].y, 1.52, 0.03, "at the shoulder")


func test_a_shot_holds_the_replica_level_and_it_rises_after() -> void:
	var c := _character(0)
	var world := BoxWorld.new(body)
	_wall(world, 0.5)
	var v := _view(FigureMix.HUMAN, c, world)
	await _pose(v, c, 40, true)
	assert_gt(_ahead(v), 0.65, "firing, level (the BB leaves where it points; the BL1 carbine reaches 0.72 m)")
	await _pose(v, c, 40)
	assert_lte(_ahead(v), 0.5 + SLACK, "raised once the shot's hold is over")


func test_holstered_or_calling_the_hit_nothing_is_raised_and_the_hang_stays_in() -> void:
	var c := _character(0)
	var world := BoxWorld.new(body)
	_wall(world, 0.4)
	var v := _view(FigureMix.HUMAN, c, world)
	c.armament.holstered = true
	await _pose(v, c)
	assert_false(_corners.has(v), "holstered: nothing in the hand")
	c.armament.holstered = false
	c.status = Character.Status.CALLING
	await _pose(v, c, 60)
	assert_lte(_ahead(v), 0.4, "calling the hit, the rifle hangs within reach of the body")


func test_one_ray_every_raise_stride_poses() -> void:
	var c := _character(0)
	var world := CountedWorld.new(body)
	_wall(world, 0.6)
	var v := _view(FigureMix.HUMAN, c, world)
	await _pose(v, c, 2)
	var before := world.rays
	var poses := 30
	await _pose(v, c, poses)
	assert_eq(world.rays - before, poses / maxi(config.raise_stride, 1), "one ray a stride")


func test_leaving_the_wall_the_raise_reaches_exactly_none() -> void:
	var c := _character(0)
	var world := BoxWorld.new(body)
	_wall(world, 0.45)
	var v := _view(FigureMix.HUMAN, c, world)
	await _pose(v, c)
	assert_gt(v.body().bend.high_ready, 0.9, "raised at the wall")
	c.yaw = PI
	c.prev_yaw = PI
	# Eased over settle_raise (0.08 s), under raise_rest within 0.55 s: 45 poses (0.75 s) is plenty.
	await _pose(v, c, 45)
	assert_eq(v.body().bend.high_ready, 0.0, "none at all, so the arms' IK no longer runs")
