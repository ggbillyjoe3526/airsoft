extends GutTest
## QA (HG1): the cosine-sum cone test agrees with the angle test it replaced.


func _old(at: Transform3D, corner_angle: float, point: Vector3, radius: float) -> bool:
	var to := point - at.origin
	var far := to.length()
	if far <= radius:
		return true
	return (-at.basis.z).angle_to(to) <= corner_angle + asin(radius / far)


func test_in_cone_matches_the_angle_test_over_random_points() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var at := Transform3D(Basis.from_euler(Vector3(0.3, 1.1, 0.0)), Vector3(2, 1, -3))
	var disagree := 0
	for i in 2000:
		var corner_angle := rng.randf_range(0.2, 1.4)
		var p := at.origin + Vector3(rng.randf_range(-30, 30), rng.randf_range(-30, 30), rng.randf_range(-30, 30))
		var r := rng.randf_range(0.1, 3.0)
		var corner := Vector2(cos(corner_angle), sin(corner_angle))
		if FigureView.in_cone(at, corner, p, r) != _old(at, corner_angle, p, r):
			disagree += 1
	assert_eq(disagree, 0, "cosine test must equal the angle test")
