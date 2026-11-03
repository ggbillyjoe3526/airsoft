class_name HitShapes
extends RefCounted
## Wireframes of a character's hit volume (Hitbox.build_volume) for the debug draw: the head sphere and the twelve
## capsules, each as a ring at both ends, four lines along its side and a half circle round each end in two planes. The
## volume's bounding capsule is not drawn (it is a shortcut for the ray tests, not a hit area). Allocates nothing.

## Below this a capsule's two ends count as one point, so it is a sphere.
const SPHERE_LENGTH := 1e-4
## Shapes in one volume: the head and the parts.
const SHAPES := Hitbox.PART_COUNT + 1


## Draws `v` into `lines` in `colour`; returns the shapes drawn.
static func draw_volume(lines: DebugLines, v: Hitbox.Volume, colour: Color, cfg: DebugViewConfig) -> int:
	draw_capsule(lines, v.head, colour, cfg)
	for part: Hitbox.Capsule in v.parts:
		draw_capsule(lines, part, colour, cfg)
	return SHAPES


static func draw_capsule(lines: DebugLines, cap: Hitbox.Capsule, colour: Color, cfg: DebugViewConfig) -> void:
	var axis := cap.b - cap.a
	var length := axis.length()
	var is_sphere := length < SPHERE_LENGTH
	var up := Vector3.UP if is_sphere else axis / length
	var helper := Vector3.RIGHT if absf(up.y) > 0.9 else Vector3.UP
	var s := up.cross(helper).normalized() * cap.r
	var t := up.cross(s).normalized() * cap.r
	var rings := maxi(cfg.ring_segments, 3)
	for k in rings:
		var a0 := TAU * k / rings
		var a1 := TAU * (k + 1) / rings
		var p0 := cos(a0) * s + sin(a0) * t
		var p1 := cos(a1) * s + sin(a1) * t
		lines.line(cap.a + p0, cap.a + p1, colour, colour)
		if not is_sphere:
			lines.line(cap.b + p0, cap.b + p1, colour, colour)
	if not is_sphere:
		lines.line(cap.a + s, cap.b + s, colour, colour)
		lines.line(cap.a - s, cap.b - s, colour, colour)
		lines.line(cap.a + t, cap.b + t, colour, colour)
		lines.line(cap.a - t, cap.b - t, colour, colour)
	# The ends: a half circle in the plane of the axis and s, and of the axis and t, bulging away from the other end.
	var arcs := maxi(cfg.arc_segments, 2)
	var cap_up := up * cap.r
	for end in 2:
		var centre := cap.b if end == 0 else cap.a
		var bulge := cap_up if end == 0 else -cap_up
		for plane in 2:
			var across := s if plane == 0 else t
			for k in arcs:
				var a0 := PI * k / arcs
				var a1 := PI * (k + 1) / arcs
				lines.line(centre + cos(a0) * across + sin(a0) * bulge, centre + cos(a1) * across + sin(a1) * bulge,
						colour, colour)
