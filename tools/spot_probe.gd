extends SceneTree
## Spotted's probe (LF1; dev only, never exported): seeded headless bot matches on a field through MatchRunner.
## - Twice a second, for every character and every enemy in play whose chest is in a clear line from its eyes (no
##   level surface), the Spotted that character would place looking straight at them (Pings.enemy_under_view,
##   PingConfig.spot_cone_deg), counted by range (near under 20 m, mid under 40, far) and, when it marks nobody, why:
##   leaves (more than BotConfig.foliage_see_through of a bush's counted leaves on the lines to chest and head; split by
##   whether the bushes as drawn also put a frond on both lines), smoke,
##   dazzled (a flash), a body (someone already hit stands in the line: BotSenses._body_in_sight), or chest and head
##   hidden by different things (named each).
## - Every two seconds character 0 really places one at the nearest enemy it sees (Spots.place, as a tap of Z does):
##   the enemy must come back marked for its team, and every bot teammate in play within PingConfig.spot_share_radius
##   that is free to hear (not fighting, no target in view, no fresher contact of its own: Spots.share) must have been
##   told where they are.
## - Prints each bot that stands still STILL_TIME s with what it is doing, and counts characters whose chest is inside
##   a block. Measured, never asserted.
##   godot --headless --path . -s res://tools/spot_probe.gd -- <map id> [seeds] [mode]
## `mode` is "elimination", "flag" (Attack / Defend, the default) or "bomb" (Plant The Bomb).

const MODES: Dictionary[String, RoundState.Mode] = {
	"elimination": RoundState.Mode.ELIMINATION,
	"flag": RoundState.Mode.ATTACK_DEFEND,
	"bomb": RoundState.Mode.PLANT_THE_BOMB,
}
## Enemies further off than this (m) are left out.
const RANGE := 80.0
## Probed every EVERY ticks, a real Spotted every PLACE_EVERY; a bot standing still STILL_TIME s (within STILL_REACH m)
## is printed.
const EVERY := 30
const PLACE_EVERY := 120
const STILL_TIME := 12.0
const STILL_REACH := 0.5
const MAX_MATCH_SECONDS := 600.0
const SPOTTER := 0

var _runner: MatchRunner = null
var _tick: int = 0
var _hit := RayHit.new()
var _counts: Dictionary[String, int] = {}
var _last_pos: Dictionary[int, Vector3] = {}
var _still_since: Dictionary[int, float] = {}
var _reported: Dictionary[int, bool] = {}
var _map: MapData = null
var _ping := GameEvent.new()
## The bushes as drawn, for _drawn_hit: their turns, models and world triangles by bush (made when first met).
var _turns := PackedFloat32Array()
var _fern: Mesh = null
var _shrub: Mesh = null
var _tris: Dictionary[int, PackedVector3Array] = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var map_id := args[0]
	var seeds := args[1].to_int() if args.size() > 1 else 2
	var mode_name := args[2] if args.size() > 2 else "flag"
	_runner = MatchRunner.new(root, map_id, MatchRunner.sized_for(map_id, null, 0))
	await physics_frame
	await physics_frame
	_map = _runner.map
	_runner.mode = MODES[mode_name]
	_runner.each_tick = _each_tick
	for s in range(1, seeds + 1):
		_last_pos.clear()
		_still_since.clear()
		_reported.clear()
		_runner.play(s, MAX_MATCH_SECONDS)
	var keys := _counts.keys()
	keys.sort()
	for k: String in keys:
		print("%s %s: %s: %d" % [map_id, mode_name, k, _counts[k]])
	_runner.free_level()
	quit()


func _count(k: String) -> void:
	_counts[k] = _counts.get(k, 0) + 1


func _each_tick(state: GameState, bots: BotController) -> void:
	_tick += 1
	if not state.round_state.is_live():
		_last_pos.clear()
		_still_since.clear()
		return
	var w := bots.world
	_watch_still(state, w)
	if _tick % PLACE_EVERY == 0:
		_place(state, bots)
	if _tick % EVERY != 0:
		return
	var tuning := w.tuning
	for v in state.characters:
		if not Elimination.is_in_play(v):
			continue
		var yaw := v.yaw
		for t in state.characters:
			if t.team == v.team or not Elimination.is_in_play(t):
				continue
			var chest := BotSenses.body_point(t, tuning.hits, w.cfg.aim_height_fraction)
			var eye := _face(v, chest, tuning)
			var d := eye.distance_to(chest)
			if d <= RANGE and not w.query.sight_ray(eye, chest, _hit):
				var got := _spot_at(v, chest, eye, bots)
				var band := "near" if d < 20.0 else ("mid" if d < 40.0 else "far")
				if got == t:
					_count("spot ok " + band)
				elif got != null:
					_count("spot other enemy " + band)
				else:
					_count("spot FAIL %s %s" % [band, _why(v, t, eye, d, w)])
			v.yaw = yaw


## Turns `v` to look at `point` and returns its eyes: a lean puts the eyes off to the side of the turn, so turned twice.
func _face(v: Character, point: Vector3, tuning: SimTuning) -> Vector3:
	var eye := Lean.eye(v, tuning.body, tuning.hits)
	for i in 2:
		v.yaw = atan2(-(point - eye).x, -(point - eye).z)
		eye = Lean.eye(v, tuning.body, tuning.hits)
	return eye


## The enemy a Spotted from `v`'s eyes straight at `chest` marks (null: nobody), with the view's reach as the
## simulation measures it.
func _spot_at(v: Character, chest: Vector3, eye: Vector3, bots: BotController) -> Character:
	var w := bots.world
	var dir := (chest - eye).normalized()
	var reach := w.tuning.pings.reach
	if w.query.sight_ray(eye, eye + dir * reach, _hit):
		reach = _hit.fraction * reach
	return bots.pings.enemy_under_view(v, eye, dir, reach, w.tuning.pings.spot_cone_deg, w)


## Why a Spotted at `t` (level-clear at its chest, `d` m off) marked nobody.
func _why(v: Character, t: Character, eye: Vector3, d: float, w: BotWorld) -> String:
	if v.dazzle_left > 0.0:
		return "dazzled"
	var hits := w.tuning.hits
	var chest := BotSenses.body_point(t, hits, w.cfg.aim_height_fraction)
	var head := BotSenses.body_point(t, hits, w.cfg.head_height_fraction)
	if d > w.cfg.close_awareness and not BotSenses.leaves_clear(w, eye, chest) \
			and (w.query.sight_ray(eye, head, _hit) or not BotSenses.leaves_clear(w, eye, head)):
		# Leaves: does the drawn plant hide them too (a frond on the lines to chest and head)?
		return "leaves, drawn hides" if _drawn_hit(eye, chest) and _drawn_hit(eye, head) else "leaves, drawn shows"
	if not BotSenses.smoke_clear(w, eye, chest):
		return "smoke"
	if BotSenses._body_in_sight(eye, chest, v, t, w) and BotSenses._body_in_sight(eye, head, v, t, w):
		return "body in line"
	var why := "chest %s, head %s" % [_part_why(v, t, eye, chest, d, w), _part_why(v, t, eye, head, d, w)]
	if why == "chest nothing, head nothing":
		var dir := (chest - eye) / d
		var reach := w.tuning.pings.reach
		if w.query.sight_ray(eye, eye + dir * reach, _hit):
			reach = _hit.fraction * reach
		print("UNNAMED %d -> %d: %.2f m, view reach %.2f, in view %s, visible part %.2f, crouch %.2f, lean %.2f" % [v.id,
				t.id, d, reach, BotSenses.in_view(v, t.position, w.cfg), BotSenses.visible_part(v, t, w,
				w.tuning.pings.reach), t.crouch_amount, v.lean])
	return why


## What hides `point` of `t` from `eye` (`d` m off) by the bots' sight rules, for _why's mixed cases.
func _part_why(v: Character, t: Character, eye: Vector3, point: Vector3, d: float, w: BotWorld) -> String:
	if w.query.sight_ray(eye, point, _hit):
		return "level"
	if d > w.cfg.close_awareness and not BotSenses.leaves_clear(w, eye, point):
		return "leaves"
	if not BotSenses.smoke_clear(w, eye, point):
		return "smoke"
	if BotSenses._body_in_sight(eye, point, v, t, w):
		return "body"
	return "nothing"


## Character SPOTTER places a real Spotted at the nearest enemy it sees: they must be marked for its team and its free
## bot teammates near them told.
func _place(state: GameState, bots: BotController) -> void:
	var w := bots.world
	var me := state.character(SPOTTER)
	if me == null or not Elimination.is_in_play(me) or me.dazzle_left > 0.0:
		return
	var eye := Lean.eye(me, w.tuning.body, w.tuning.hits)
	var best: Character = null
	var best_d := RANGE
	for t in state.characters:
		if t.team == me.team or not Elimination.is_in_play(t):
			continue
		var at := BotSenses.body_point(t, w.tuning.hits, w.cfg.aim_height_fraction)
		var d := eye.distance_to(at)
		if d < best_d and not w.query.sight_ray(eye, at, _hit) and BotSenses.leaves_clear(w, eye, at) \
				and BotSenses.smoke_clear(w, eye, at):
			best = t
			best_d = d
	if best == null:
		return
	var chest := BotSenses.body_point(best, w.tuning.hits, w.cfg.aim_height_fraction)
	var yaw := me.yaw
	eye = _face(me, chest, w.tuning)
	var dir := (chest - eye).normalized()
	var due := _free_near(w, me, best)
	_ping.kind = GameEvent.Kind.PING
	_ping.actor = me.id
	_ping.value2 = GameEvent.PING_SPOT
	_ping.position = eye
	_ping.direction = dir
	_ping.value = 0
	var reach := w.tuning.pings.reach
	if w.query.sight_ray(eye, eye + dir * reach, _hit):
		_ping.value = 1
		_ping.reach = _hit.fraction * reach
	var got := bots.spots.place(_ping, state.time, w, bots.pings)
	if got != best:
		_count("placed FAIL marked %s" % ("another enemy" if got != null
				else "nobody, " + _why(me, best, eye, eye.distance_to(chest), w)))
		me.yaw = yaw
		return
	me.yaw = yaw
	if not bots.spots.is_spotted(best.id, state.time) or bots.spots.spotted_by(best.id) != me.team:
		_count("placed FAIL not marked for the team")
		return
	_count("placed ok")
	for m in due:
		_count("placed teammate told" if m.heard_at == w.time and m.last_known == best.position
				else "placed FAIL teammate not told")


## `me`'s bot teammates in play within the share radius of `enemy` that are free to hear (Spots.share's rule).
func _free_near(w: BotWorld, me: Character, enemy: Character) -> Array[Bot]:
	var radius := w.tuning.pings.spot_share_radius
	var due: Array[Bot] = []
	for m in w.bots:
		var c := m.character
		if c.team != me.team or c == me or not Elimination.is_in_play(c) or m.target_visible \
				or m.mode == Bot.Mode.FIGHT:
			continue
		if Vector2(enemy.position.x - c.position.x, enemy.position.z - c.position.z).length() > radius:
			continue
		if m.has_last_known and m.target_id != enemy.id and w.time - m.last_seen_at() < w.cfg.hearing_contact_time:
			continue
		due.append(m)
	return due


func _watch_still(state: GameState, w: BotWorld) -> void:
	for c in state.characters:
		if not Elimination.is_in_play(c):
			continue
		var last: Vector3 = _last_pos.get(c.id, Vector3.INF)
		if last.distance_to(c.position) > STILL_REACH:
			_last_pos[c.id] = c.position
			_still_since[c.id] = state.time
		elif state.time - _still_since.get(c.id, state.time) > STILL_TIME and not _reported.has(c.id):
			_reported[c.id] = true
			var b := _bot_of(w, c)
			var note := ""
			if b != null:
				note = "mode %s, route %s, %.1f m from its goal, target %d seen %s" % [Bot.Mode.keys()[b.mode],
						Bot.RouteState.keys()[b.route_state], b.route_goal.distance_to(c.position), b.target_id,
						b.target_visible]
			print("STILL id %d team %d at %s for %.0f s, %s, blocks: %s" % [c.id, c.team, c.position, STILL_TIME,
					note, _blocks_near(c.position, 0.6)])
		var inside := _blocks_near(c.position + Vector3.UP, 0.0)
		if inside != "":
			_count("inside a block " + inside)


## Whether the segment from `a` to `b` meets a triangle of a bush as BushView draws it.
func _drawn_hit(a: Vector3, b: Vector3) -> bool:
	var f := _map.foliage
	if _turns.is_empty():
		_turns = BushView.turns_of(_map)
		var woods := WoodsConfig.new()
		_fern = PropDressConfig.load_mesh(woods.fern_model)
		_shrub = PropDressConfig.load_mesh(woods.bush_model)
	var seg := AABB(a, Vector3.ZERO).expand(b)
	for i in f.size():
		var r := f.radii[i]
		var box := AABB(f.feet[i] - Vector3(r, 0.0, r), Vector3(2.0 * r, f.heights[i], 2.0 * r))
		if not box.intersects(seg.grow(0.01)):
			continue
		if not _tris.has(i):
			var mesh := _fern if f.heights[i] <= _runner.tuning.ballistics.leaf_fern_tallest else _shrub
			var xf := BushView.fitted(f, i, mesh.get_aabb(), _turns[i])
			var tris := PackedVector3Array()
			for s in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for k: int in arrays[Mesh.ARRAY_INDEX]:
					tris.append(xf * verts[k])
			_tris[i] = tris
		var t: PackedVector3Array = _tris[i]
		for k in range(0, t.size(), 3):
			if Geometry3D.segment_intersects_triangle(a, b, t[k], t[k + 1], t[k + 2]) != null:
				return true
	return false


func _bot_of(w: BotWorld, c: Character) -> Bot:
	for b in w.bots:
		if b.character == c:
			return b
	return null


func _blocks_near(p: Vector3, pad: float) -> String:
	var out := PackedStringArray()
	for b in _map.blocks:
		if b.kind != &"floor" and AABB(b.center - b.size * 0.5, b.size).grow(pad).has_point(p):
			out.append("%s%s" % [b.kind, (":" + b.dress) if b.dress != &"" else ""])
	return ",".join(out)
