extends GutTest
## FI7, HV1: the hit area against the drawn figure (tests/support/hit_area_probe.gd, M85's measure): every kind, head and
## pose, its level 0 triangles baked with FigureBend's bend in and the arms left out, against Hitbox's fitted volume on
## a 1 cm grid from 8 sides. Every human pose is held to M85's bar (4 % of the drawn body missed, 3 % of the volume thin
## air); the robots (Dev) wear the human's fit and are held to a looser thin-air bar (KNOWN_ISSUES). FI7's built-in
## volume missed up to 36 % (docs/records/FI7.md); HV1's numbers are in docs/records/HV1.md.

## M85's bar (percentage points), and the robots' thin air.
const BAR_MISSED := 4.0
const BAR_THIN := 3.0
const ROBOT_BAR_THIN := 9.0

var models: FigureModels = null
var hits: HitConfig = null
var moves: MovementConfig = null
var probe: HitAreaProbe = null
var holder: Node3D = null
## Every measure, by "kind/head/pose" (taken once: about 20 s).
var results: Dictionary[String, HitAreaProbe.Result] = {}


func before_all() -> void:
	models = FigureModels.new(FigureConfig.new())
	models.load_kinds()
	hits = HitConfig.new()
	moves = MovementConfig.new()
	holder = Node3D.new()
	add_child(holder)
	probe = HitAreaProbe.new(models, hits, moves, holder)
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		for head in probe.heads(kind):
			for pose in HitAreaProbe.POSES:
				results["%d/%s/%s" % [kind, head, pose]] = probe.measure(kind, head, pose)


func after_all() -> void:
	probe.free_bodies()
	holder.free()


func test_every_kind_head_and_pose_is_measured() -> void:
	assert_eq(probe.heads(FigureMix.HUMAN).size(), 4, "the human's four heads")
	assert_eq(HitAreaProbe.POSES.size(), 19, "stand, crouch, two leans, walk and run at four phases, crouch-walk, "
			+ "mid-vault, aim up and down, between the fit's samples, half crouched and crouch-walking back")
	assert_eq(results.size(), (probe.heads(FigureMix.HUMAN).size() + 1) * HitAreaProbe.POSES.size(), "every one")


func test_every_human_pose_is_within_m85s_bar() -> void:
	for key: String in results:
		if not key.begins_with("%d/" % FigureMix.HUMAN):
			continue
		var r := results[key]
		assert_lte(r.missed, BAR_MISSED, "%s: the drawn body the volume misses" % key)
		assert_lte(r.thin_air, BAR_THIN, "%s: the volume that is thin air" % key)


func test_a_robot_is_missed_no_more_and_its_thin_air_is_held() -> void:
	for key: String in results:
		if not key.begins_with("%d/" % FigureMix.ROBOT):
			continue
		var r := results[key]
		assert_lte(r.missed, BAR_MISSED, "%s: the drawn robot the volume misses" % key)
		assert_lte(r.thin_air, ROBOT_BAR_THIN, "%s: the volume that is thin air" % key)


func test_the_figure_fits_inside_the_grid_and_both_shapes_meet_rays() -> void:
	for key: String in results:
		var r := results[key]
		assert_eq(r.outside, 0, "%s: no triangle outside the grid's window" % key)
		assert_gt(r.drawn_rays, 10000, "%s: the drawn body meets rays" % key)
		assert_gt(r.volume_rays, 10000, "%s: the volume meets rays" % key)


func test_a_bigger_volume_reads_as_more_thin_air_and_a_smaller_as_more_missed() -> void:
	var big := hits.duplicate() as HitConfig
	big.fit_chest_radius *= 1.5
	var small := hits.duplicate() as HitConfig
	small.fit_chest_radius *= 0.6
	var key := "%d/%s/stand" % [FigureMix.HUMAN, probe.heads(FigureMix.HUMAN)[0]]
	var wide := HitAreaProbe.new(models, big, moves, holder).measure(FigureMix.HUMAN, probe.heads(FigureMix.HUMAN)[0],
			&"stand")
	var narrow := HitAreaProbe.new(models, small, moves, holder)
	var thin := narrow.measure(FigureMix.HUMAN, probe.heads(FigureMix.HUMAN)[0], &"stand")
	assert_gt(wide.thin_air, results[key].thin_air + 1.0, "a wider chest is more thin air")
	assert_gt(thin.missed, results[key].missed + 1.0, "a narrower chest misses more of the body")


func test_the_bend_is_in_the_bake_and_the_arms_are_out() -> void:
	var head := probe.heads(FigureMix.HUMAN)[0]
	probe.measure(FigureMix.HUMAN, head, &"stand")
	var standing := _top(probe)
	probe.measure(FigureMix.HUMAN, head, &"lean_right")
	var leaning := _top(probe)
	# FigureBend rolls the upper chain lean_max_angle about the pivot: the head's top comes down, and over to the
	# figure's right (+x at yaw 0).
	assert_lt(leaning.y, standing.y - 0.05, "the lean is baked in (Skeleton3D puts the clips' pose back after it)")
	assert_gt(leaning.x, standing.x + 0.1, "to the figure's right")
	var kept := 0
	var all := 0
	for part in probe._parts(probe._body(FigureMix.HUMAN, head)):
		kept += part.kept.size()
		all += (part.mesh.mesh.surface_get_arrays(part.surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
	assert_lt(kept, all * 0.9, "the arms' triangles are left out")
	assert_gt(kept, all * 0.5, "and only theirs")


## The highest baked point.
func _top(p: HitAreaProbe) -> Vector3:
	var top := Vector3(0.0, -INF, 0.0)
	for tris in p._baked:
		for v in tris:
			if v.y > top.y:
				top = v
	return top
