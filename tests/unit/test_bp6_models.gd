extends GutTest
## BP6, the models' bug pass: each model within the material budget (docs/CC0_ASSETS.md: 6 a replica, 8 a figure)
## but the GBB Pistol's known row, and the human figure's glove plates each on one set of weights, so a finger bent
## round a grip turns a plate whole instead of shearing it into shards, while the shoulders keep body.py's blended
## weights (tools/blender/figures/body_weights.py; owner 2026-11-07: he preferred 33fa48b's shoulder to the easing).

const REPLICAS := ["aeg", "sniper", "cyber", "smg", "shotgun"]
## The GBB Pistol keeps 7 (docs/KNOWN_ISSUES.md): its unpainted pair, the grip's tiling stipple and the BB, can't share.
const OVER := {"pistol": 7}
const REPLICA_MOST := 6
const FIGURE_MOST := 8
## A glove plate: a piece of the Body joined by its faces, of at most PLATE_MOST points, all led by a hand bone
## (tools/blender/figures/body_weights.py finds them the same way).
const HAND := ["Hand_", "Thumb", "Index", "Middle", "Ring", "Pinky"]
const PLATE_MOST := 300
## Weights within this of each other are a tie, which goes to the arm (body_weights.py TIE: the wrist strap's tab).
const TIE := 1.0e-3
## The plates the glove carries: a back plate and its border, four knuckle domes and eight finger guards a hand.
const PLATES := 28
const WELD := 1.0e6
## The chest's side by each armpit (m, the figure's rest pose): above ARMPIT_FROM up to the shoulder's joint, from
## ARMPIT_IN out from the middle to ARMPIT_OUT past the joint. There the upper arm's mean share stays body.py's blend,
## at least BLEND_LEAST on every level (33fa48b's: 0.36 to 0.53; BP6's easing off the arm took it to 0.18 to 0.30 and
## thinned the raised shoulder).
const ARMPIT_FROM := 1.10
const ARMPIT_IN := 0.06
const ARMPIT_OUT := 0.02
const BLEND_LEAST := 0.33
const LEVELS: PackedStringArray = ["Body", "Body_LOD1", "Body_LOD2"]


func _materials(root: Node) -> int:
	var seen := {}
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (n as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			seen[mat.resource_name if mat != null else ""] = true
	return seen.size()


func _scene(path: String) -> Node:
	var root := (load(path) as PackedScene).instantiate()
	add_child_autofree(root)
	return root


func test_every_model_is_within_the_material_budget() -> void:
	for id: String in REPLICAS + OVER.keys():
		var n := _materials(_scene("res://assets/models/replicas/%s.glb" % id))
		assert_lte(n, OVER.get(id, REPLICA_MOST), "%s: %d materials" % [id, n])
	var n := _materials(_scene("res://assets/models/characters/human.glb"))
	assert_lte(n, FIGURE_MOST, "the human figure: %d materials" % n)


func test_each_glove_plate_moves_whole() -> void:
	var body := _scene("res://assets/models/characters/human.glb").find_child("Body", true, false) as MeshInstance3D
	assert_not_null(body)
	if body == null:
		return
	var points := PackedVector3Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var tris := PackedInt32Array()
	for s in body.mesh.get_surface_count():
		var a := body.mesh.surface_get_arrays(s)
		var base := points.size()
		points.append_array(a[Mesh.ARRAY_VERTEX])
		bones.append_array(a[Mesh.ARRAY_BONES])
		weights.append_array(a[Mesh.ARRAY_WEIGHTS])
		for i: int in a[Mesh.ARRAY_INDEX] as PackedInt32Array:
			tris.append(base + i)
	var per := bones.size() / points.size()
	var piece := _pieces(points, tris)
	var members := {}
	for v in points.size():
		if not members.has(piece[v]):
			members[piece[v]] = [] as Array[int]
		(members[piece[v]] as Array[int]).append(v)
	var plates := 0
	for key: int in members:
		var pts: Array[int] = members[key]
		if pts.size() > PLATE_MOST or not _all_in_hand(body.skin, bones, weights, per, pts):
			continue
		plates += 1
		var first := _mix(bones, weights, per, pts[0])
		for v in pts:
			var mix := _mix(bones, weights, per, v)
			var same := mix.size() == first.size()
			for b: int in first:
				same = same and mix.has(b) and absf(float(mix[b]) - float(first[b])) < 1e-3
			assert_true(same, "a plate's points share one set of weights (%s, %s; %d points)" % [first, mix, pts.size()])
			if not same:
				return
	assert_eq(plates, PLATES, "every plate of both gloves")


func test_the_chest_s_side_keeps_the_upper_arm_s_blend() -> void:
	var root := _scene("res://assets/models/characters/human.glb")
	var sk := root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for level: String in LEVELS:
		var body := root.find_child(level, true, false) as MeshInstance3D
		assert_not_null(body, level)
		if body == null:
			continue
		for arm: String in ["UpperArm_L", "UpperArm_R"]:
			var joint := sk.get_bone_global_rest(sk.find_bone(arm)).origin
			var total := 0.0
			var count := 0
			for s in body.mesh.get_surface_count():
				var a := body.mesh.surface_get_arrays(s)
				var points := a[Mesh.ARRAY_VERTEX] as PackedVector3Array
				var bones := a[Mesh.ARRAY_BONES] as PackedInt32Array
				var weights := a[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array
				var per := bones.size() / points.size()
				for v in points.size():
					var p := points[v]
					var out := p.x * signf(joint.x)
					if not (p.y > ARMPIT_FROM and p.y < joint.y and out > ARMPIT_IN and out < absf(joint.x) + ARMPIT_OUT):
						continue
					count += 1
					for k in per:
						if body.skin.get_bind_name(bones[v * per + k]) == StringName(arm):
							total += weights[v * per + k]
			assert_gt(count, 0, "%s %s: the armpit's points" % [level, arm])
			var mean := total / maxf(count, 1.0)
			assert_gte(mean, BLEND_LEAST, "%s %s: the upper arm's mean share by the armpit %.2f" % [level, arm, mean])


## Point `v`'s weights by bone (the ones above nothing).
static func _mix(bones: PackedInt32Array, weights: PackedFloat32Array, per: int, v: int) -> Dictionary:
	var out := {}
	for k in per:
		if weights[v * per + k] > 1e-4:
			out[bones[v * per + k]] = weights[v * per + k]
	return out


## Every point of `pts` led by a hand bone: its best hand weight above every other bone's, so a tie goes to the arm.
static func _all_in_hand(skin: Skin, bones: PackedInt32Array, weights: PackedFloat32Array, per: int,
		pts: Array[int]) -> bool:
	for v in pts:
		var hand := 0.0
		var other := 0.0
		for k in per:
			var name := String(skin.get_bind_name(bones[v * per + k]))
			var in_hand := false
			for h: String in HAND:
				in_hand = in_hand or name.begins_with(h)
			if in_hand:
				hand = maxf(hand, weights[v * per + k])
			else:
				other = maxf(other, weights[v * per + k])
		if hand <= other + TIE:
			return false
	return true


## Each point's piece: points joined by faces, points within a thousandth of a millimetre one.
static func _pieces(points: PackedVector3Array, tris: PackedInt32Array) -> PackedInt32Array:
	var weld := PackedInt32Array()
	var at := {}
	for p in points:
		var key := Vector3i(roundi(p.x * WELD), roundi(p.y * WELD), roundi(p.z * WELD))
		if not at.has(key):
			at[key] = at.size()
		weld.append(at[key])
	var parent: Array[int] = []
	for i in at.size():
		parent.append(i)
	for t in range(0, tris.size(), 3):
		for k in 2:
			var a := _root(parent, weld[tris[t + k]])
			var b := _root(parent, weld[tris[t + k + 1]])
			if a != b:
				parent[a] = b
	var out := PackedInt32Array()
	for w in weld:
		out.append(_root(parent, w))
	return out


static func _root(parent: Array[int], x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x
