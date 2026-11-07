class_name UpperBlend
## The upper body's holster and sprint arms, eased as the drawn figure eases them (BP6; FigurePose's holster_weight and
## sprint_weight): the holster's target is 1 while holstered and, drawn out of it, until HitConfig.holster_swap of the
## way through the draw, then falls in line to 0 at its end; the sprint's is 1 while sprinting. Each tick the
## Character's weights move towards them over settle_holster and settle_sprint (an exponential step, as FigurePose's),
## so the hit volume (HitPose) follows the drawn arms and torso into and out of the holster and the sprint. Pure; the
## simulation only, nothing allocated.


## The holster's target for armament `a` (0 in the aim .. 1 put away): `swap` (HitConfig.holster_swap) of a draw from
## the holster still put away, the rest rising to the aim.
static func holster_target(a: Armament, swap: float) -> float:
	if a == null or a.replicas.is_empty():
		return 0.0
	if a.holstered:
		return 1.0
	if a.drawn_from_holster and a.draw_left > 0.0 and a.draw_total > 0.0:
		var share := 1.0 - a.draw_left / a.draw_total
		return 1.0 if share < swap else clampf((1.0 - share) / maxf(1.0 - swap, 1e-6), 0.0, 1.0)
	return 0.0


## Whether armament `a`'s replica is in the hand (not put away, nor in the first `swap` of a draw from the holster), as
## FigurePose.in_hand has it: the cheek is on a rifle's stock only then.
static func in_hand(a: Armament, swap: float) -> bool:
	if a == null or a.replicas.is_empty() or a.holstered:
		return false
	return not (a.drawn_from_holster and a.draw_left > 0.0 and a.draw_total > 0.0
			and 1.0 - a.draw_left / a.draw_total < swap)


## Moves `c`'s holster and sprint weights `dt` seconds towards their targets.
static func step(c: Character, hits: HitConfig, dt: float) -> void:
	c.holster_weight = lerpf(c.holster_weight, holster_target(c.armament, hits.holster_swap),
			share(dt, hits.settle_holster))
	c.sprint_weight = lerpf(c.sprint_weight, 1.0 if c.sprinting else 0.0, share(dt, hits.settle_sprint))


## The share of the way to the target `dt` seconds of easing covers with settle time `settle` (s): every ease of the
## simulation's and of the drawn figure's (FigurePose.settle_share).
static func share(dt: float, settle: float) -> float:
	return 1.0 - exp(-maxf(dt, 0.0) / settle) if settle > 0.0 else 1.0
