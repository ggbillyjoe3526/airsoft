extends GutTest
## HA1 on the Pump Shotgun (SH2's model and hold merged): the tuck is written over the pose of the arms' clip, so a
## pump stroke or a reload played aimed must leave the clip's own pose whole once the sight is down again, and
## swapping replicas must leave no tuck behind.

const DT := 1.0 / 60.0
const EPS := 1e-4
const BONES := ["UpperArm_L", "Forearm_L", "Hand_L", "Index3_L", "Thumb3_L"]

var cfg: ViewModelConfig = null


func before_each() -> void:
	cfg = ViewModelConfig.new()


func _hands(ids: Array) -> ReplicaView:
	var loadout: Array[ReplicaConfig] = []
	for id: StringName in ids:
		loadout.append(ReplicaStats.load_replica(id))
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(cfg, loadout, BoxWorld.new())
	return hands


func _pose(hands: ReplicaView) -> Array[Transform3D]:
	var skeleton := hands._arms._skeleton
	skeleton.force_update_all_bone_transforms()
	var out: Array[Transform3D] = []
	for bone: String in BONES:
		out.append(skeleton.get_bone_global_pose(skeleton.find_bone(bone)))
	return out


func _assert_same(a: Array[Transform3D], b: Array[Transform3D], what: String, eps: float = EPS) -> void:
	for i in a.size():
		assert_true(a[i].origin.distance_to(b[i].origin) < eps and a[i].basis.x.distance_to(b[i].basis.x) < maxf(eps, 1e-3) and a[i].basis.y.distance_to(b[i].basis.y) < maxf(eps, 1e-3),
				"%s: %s as the clip has it" % [what, BONES[i]])


## One frame of the arms: the clip followed at `reload` (below 0 none), then the sight raised `raise`.
func _frame(hands: ReplicaView, raise: float, reload: float = -1.0) -> void:
	var held: ReplicaView.Held = hands._held[0]
	hands._arms.follow(held.anim, DT, reload)
	hands._arms.aim(raise)


func test_a_pump_stroke_played_aimed_leaves_the_clip_whole_at_the_hip() -> void:
	var hands := _hands([&"shotgun"])
	hands._show(0)
	var held: ReplicaView.Held = hands._held[0]
	hands.on_shot()
	held.anim.seek(0.3, true)
	_frame(hands, 0.0)
	var hip := _pose(hands)
	_frame(hands, 1.0)
	assert_ne(_pose(hands)[1].origin, hip[1].origin, "control: aimed, the forearm is drawn in")
	_frame(hands, 0.0)
	_assert_same(_pose(hands), hip, "pump mid-stroke, hip, aim, hip")
	# The stroke runs on while the sight rises and falls.
	for raise: float in [0.2, 0.6, 1.0, 0.5, 0.0]:
		held.anim.seek(0.3, true)
		_frame(hands, raise)
	_assert_same(_pose(hands), hip, "stroke played through the raise")


func test_a_pump_stroke_ending_aimed_returns_the_hold_at_the_hip() -> void:
	var hands := _hands([&"shotgun"])
	hands._show(0)
	var held: ReplicaView.Held = hands._held[0]
	_frame(hands, 0.0)
	var clean := _pose(hands)
	hands.on_shot()
	held.anim.seek(0.2, true)
	_frame(hands, 1.0)
	held.anim.pause()
	for i in 60:
		_frame(hands, 1.0)
	_frame(hands, 0.0)
	_assert_same(_pose(hands), clean, "after the stroke ended aimed")


func test_a_reload_from_aimed_leaves_the_hand_on_the_magazine_clip_and_returns_whole() -> void:
	var hands := _hands([&"shotgun"])
	hands._show(0)
	_frame(hands, 0.0)
	var hold := _pose(hands)
	_frame(hands, 1.0)
	_frame(hands, 0.0, 0.5)
	var reload := _pose(hands)
	_frame(hands, 0.0, 0.5)
	_assert_same(_pose(hands), reload, "the reload clip with the sight down, repeated")
	_frame(hands, 0.0)
	_assert_same(_pose(hands), hold, "back on the hold when it ends")


func test_swapping_shotgun_aeg_pistol_leaves_no_tuck_and_no_nodes() -> void:
	var hands := _hands([&"shotgun", &"aeg", &"pistol"])
	var clean := _hands([&"pistol"])
	clean._show(0)
	_frame(clean, 0.0)
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for _round in 3:
		for slot: int in [0, 1, 2, 0]:
			hands._show(slot)
			hands._arms.aim(1.0)
	hands._show(2)
	var held: ReplicaView.Held = hands._held[2]
	hands._arms.follow(held.anim, DT)
	hands._arms.aim(0.0)
	_assert_same(_pose(hands), _pose(clean), "the pistol after a shotgun aimed")
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before, "no nodes made by swapping")


func test_a_bots_shotgun_hold_does_not_read_the_aim_entries() -> void:
	# The aim entries are the view's (ViewModelConfig); a bot's figure never owns a ViewModelConfig-driven tuck.
	assert_true(cfg.aim_tuck.has(&"shotgun") and cfg.aim_slide.has(&"shotgun"))
	assert_eq(cfg.aim_tuck[&"shotgun"], cfg.aim_tuck[&"aeg"], "the rifles' amounts")
	assert_eq(cfg.aim_slide[&"shotgun"], cfg.aim_slide[&"aeg"])



## Held aimed for seconds, the arm is drawn in afresh each frame from the clip's pose; a bone no clip keys must not
## carry the last frame's tuck into the next (it fed back and grew), or the hand comes back wrong at the hip.
func test_a_sight_held_up_for_seconds_returns_the_hold_whole_on_every_rifle() -> void:
	for id: StringName in [&"shotgun", &"aeg", &"sniper", &"smg"]:
		var hands := _hands([id])
		hands._show(0)
		_frame(hands, 0.0)
		var clean := _pose(hands)
		for _i in 300:
			_frame(hands, 1.0)
		_frame(hands, 0.0)
		_assert_same(_pose(hands), clean, "%s: five seconds aimed, then the hip" % id, 1e-3)
