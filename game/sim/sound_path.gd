class_name SoundPath
## Whether level geometry stands between a sound and an ear (the browser game's sim/soundPath.ts), for the bots' hearing
## (BotHearing) and the player's muffling (SoundOcclusion) alike, so both hear through the same walls. A bar railing
## (SR1) muffles nothing: its rays pass the railings' boxes (WorldQuery.ray_past_railings). Static, through WorldQuery
## only; allocates nothing.


## Whether level geometry blocks the straight line from `from` to `to`, ignoring its last `gap` metres (a sound on a
## surface stops short of it); `hit` is scratch.
static func line_blocked(query: WorldQuery, from: Vector3, to: Vector3, gap: float, hit: RayHit) -> bool:
	if gap <= 0.0:
		return query.ray_past_railings(from, to, hit)
	var dist := from.distance_to(to)
	var reach := dist - gap
	if reach <= 0.0:
		return false
	return query.ray_past_railings(from, from + (to - from) * (reach / dist), hit)


## The share (0..1) of the rays from `ear` to a character standing at `feet` that level geometry blocks, one ray per
## height (m) above their feet in `heights`: 0 in the open, 0.5 behind low cover (knee and head rays), 1 behind a wall.
## No heights: 0.
static func blocked_share(query: WorldQuery, ear: Vector3, feet: Vector3, heights: PackedFloat64Array,
		hit: RayHit) -> float:
	if heights.is_empty():
		return 0.0
	var blocked := 0
	for h in heights:
		if query.ray_past_railings(ear, feet + Vector3(0.0, h, 0.0), hit):
			blocked += 1
	return float(blocked) / heights.size()
