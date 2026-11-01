class_name BotAngles
## Held angles (the browser game's ai/angles.ts, walls only): where someone would step into view. A bot holding still
## fans rays out at eye height across the enemy side and looks for an edge: a ray that stops at a wall next to one that
## runs on. Someone coming round that corner, or through that doorway, appears just past the edge, so that is where a Hard
## bot aims, at head height. Built from the level's geometry alone: where the enemies are never enters it. Allocates
## nothing.

## The largest fan BotConfig.angle_rays may ask for.
const MAX_RAYS := 64
## Angles a bot keeps (the best first).
const KEPT := 2


## One angle held: the look at it, the aim point (just past the edge, at head height), the edge's open side (-1 left,
## 1 right, as a lean: leaning that way shows a little more past it) and its score.
class HeldAngle:
	extends RefCounted
	var yaw: float = 0.0
	var pitch: float = 0.0
	var point: Vector3 = Vector3.ZERO
	var side: int = 0
	var score: float = -INF

	func copy_from(o: HeldAngle) -> void:
		yaw = o.yaw
		pitch = o.pitch
		point = o.point
		side = o.side
		score = o.score


static var _dists: PackedFloat64Array = _sized(MAX_RAYS)
static var _hit: RayHit = RayHit.new()
static var _candidate: HeldAngle = HeldAngle.new()


## Fills `out` (best first) with up to out.size() angles held from `eye`, facing about `facing_yaw` (the enemy side),
## someone's head at `head_y`. Two picks are at least angle_separation_deg apart. Returns how many were found. Its
## rays pass a bar railing (SR1): someone can shoot through one, so the angle runs on past it.
static func find(query: WorldQuery, eye: Vector3, head_y: float, facing_yaw: float, cfg: BotConfig,
		out: Array[HeldAngle]) -> int:
	var n := mini(cfg.angle_rays, MAX_RAYS)
	var fan := deg_to_rad(cfg.angle_fan_deg)
	var step := fan / (n - 1) if n > 1 else 0.0
	var first := facing_yaw - fan * 0.5
	var reach := cfg.angle_max_distance
	for i in n:
		var to := eye + _dir(first + i * step) * reach
		_dists[i] = _hit.fraction * reach if query.ray_past_railings(eye, to, _hit) else reach
	for a in out:
		a.score = -INF
	var found := 0
	var separation := deg_to_rad(cfg.angle_separation_deg)
	for i in n - 1:
		# An edge: one ray stops at a wall, its neighbour runs on. A wall seen at a slant also lengthens from ray to ray,
		# so the open ray must run angle_jump beyond where the wall would carry on (extrapolated from the ray on the
		# wall's other side), not merely beyond the near ray. Aim along the open one, just past the wall's distance.
		var near_at := i if _dists[i] < _dists[i + 1] else i + 1
		var open_at := i + 1 if near_at == i else i
		var near := _dists[near_at]
		var before := 2 * near_at - open_at
		var wall_goes_on := 2.0 * near - _dists[before] if before >= 0 and before < n else near
		if _dists[open_at] - maxf(near, wall_goes_on) < cfg.angle_jump or near < cfg.angle_min_distance:
			continue
		var yaw := first + open_at * step
		var dist := near + cfg.angle_past
		var d := _dir(yaw)
		var c := _candidate
		c.point = Vector3(eye.x + d.x * dist, head_y, eye.z + d.z * dist)
		c.yaw = BotAim.look_yaw(eye, c.point)
		c.pitch = BotAim.look_pitch(eye, c.point)
		# Rays turn left as the index grows: an open ray after the near one lies to its left.
		c.side = -1 if open_at > near_at else 1
		# Towards the enemy side first, then at a middle distance (a corner at arm's length or across the map is less
		# use).
		c.score = cos(wrapf(yaw - facing_yaw, -PI, PI)) - absf(dist - cfg.angle_best_distance) / reach
		found = _keep_best(c, out, separation, found)
	return found


## Puts `c` among the `found` best in `out` (best first), unless one within `separation` of it scores as well; a worse
## one that close gives way to it. Returns how many are kept now.
static func _keep_best(c: HeldAngle, out: Array[HeldAngle], separation: float, found: int) -> int:
	for k in found:
		if absf(wrapf(out[k].yaw - c.yaw, -PI, PI)) >= separation:
			continue
		if out[k].score >= c.score:
			return found
		# Replaces a worse pick close to it: drop that one, then insert as usual.
		for m in range(k, found - 1):
			out[m].copy_from(out[m + 1])
		found -= 1
		break
	var at := found
	while at > 0 and out[at - 1].score < c.score:
		at -= 1
	if at >= out.size():
		return found
	var last := mini(found, out.size() - 1)
	for m in range(last, at, -1):
		out[m].copy_from(out[m - 1])
	out[at].copy_from(c)
	return mini(found + 1, out.size())


## The flat unit direction `yaw` looks along (yaw 0 down -Z, positive turning left).
static func _dir(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


static func _sized(n: int) -> PackedFloat64Array:
	var a := PackedFloat64Array()
	a.resize(n)
	return a
