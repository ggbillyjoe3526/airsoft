extends GutTest
## The Cyber Pistol's grip (owner, 2026-11-12: "redesign the handle/grip to be a similar shape to the GBB pistol";
## "doesn't look ergonomic. It has flat and sharp edges"): the GBB Pistol's own rounded grip, where the GBB's sits, so
## a hand holds both alike.

const MODEL := "res://assets/models/replicas/%s.glb"
## The heights down the grip that are compared (m below the bore, the models' own space) and half a slice's height.
const HEIGHTS: Array[float] = [-0.055, -0.065, -0.075, -0.09]
const SLICE := 0.003
## How near the two grips' straps and widths sit (m): the Cyber's skin is the GBB's sections, less its own grooves.
const NEAR := 0.0015
## The shares of a grip's depth, in from a strap, where the sides' rounding is compared.
const EDGES: Array[float] = [0.08, 0.2]


## Every vertex of `key`'s Body mesh, in the model's space.
func _body(key: String) -> PackedVector3Array:
	var model := (load(MODEL % key) as PackedScene).instantiate() as Node3D
	add_child_autofree(model)
	var body := model.find_child("Body", true, false) as MeshInstance3D
	assert_not_null(body, "%s has a Body" % key)
	var out := PackedVector3Array()
	if body == null:
		return out
	var to_model := model.global_transform.affine_inverse() * body.global_transform
	for s in body.mesh.get_surface_count():
		for v: Vector3 in body.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			out.append(to_model * v)
	return out


## The slice of `points` at `height`: its front and back straps (z) and its half width (x), as (front, back, width).
func _slice(points: PackedVector3Array, height: float) -> Vector3:
	var front := INF
	var back := -INF
	var width := 0.0
	for p in points:
		if absf(p.y - height) <= SLICE:
			front = minf(front, p.z)
			back = maxf(back, p.z)
			width = maxf(width, absf(p.x))
	return Vector3(front, back, width)


## The widest the slice at `height` is within `reach` (m) of the strap at `strap` (z).
func _width_near(points: PackedVector3Array, height: float, strap: float, reach: float) -> float:
	var width := 0.0
	for p in points:
		if absf(p.y - height) <= SLICE and absf(p.z - strap) <= reach:
			width = maxf(width, absf(p.x))
	return width


func test_its_straps_and_width_are_the_gbb_pistols_down_the_grip() -> void:
	var cyber := _body("cyber")
	var gbb := _body("pistol")
	for h in HEIGHTS:
		var c := _slice(cyber, h)
		var g := _slice(gbb, h)
		assert_almost_eq(c.x, g.x, NEAR, "front strap at %.3f" % h)
		assert_almost_eq(c.y, g.y, NEAR, "back strap at %.3f" % h)
		assert_almost_eq(c.z, g.z, NEAR, "half width at %.3f" % h)


func test_its_sides_round_in_to_both_straps_as_the_gbb_pistols_do() -> void:
	var cyber := _body("cyber")
	var gbb := _body("pistol")
	for h in HEIGHTS:
		var c := _slice(cyber, h)
		var g := _slice(gbb, h)
		for edge in EDGES:
			var reach := (g.y - g.x) * edge
			assert_lt(_width_near(cyber, h, c.x, reach), _width_near(gbb, h, g.x, reach) + NEAR,
					"no wider than the GBB's %.2f in from the front strap, %.3f" % [edge, h])
			assert_lt(_width_near(cyber, h, c.y, reach), _width_near(gbb, h, g.y, reach) + NEAR,
					"no wider than the GBB's %.2f in from the back strap, %.3f" % [edge, h])
			assert_lt(_width_near(cyber, h, c.y, reach), c.z, "narrower at the strap than at its widest")
