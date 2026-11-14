extends GutTest
## The second audit's performance fixes (AUD2): Practice finds none of the bots' groundwork (the vault links and the
## cover: no bot reads them, and your own vault and climb read the level, not the grid), a skipped round's figures are
## not posed under its cover and snap to their pose when it lifts, a menu's part pictures come out of one instance of
## each parts file a frame (ReplicaParts.keep, the same nodes as a plain take's and inside's), and LogTail reads only a
## log's end and counts the rest of its lines a piece at a time, and the parts files keep their wear mask beside them
## (tools/blender/replicas/glb_images.py), not inside them a second time against their cap. A staged load builds the
## views step a piece a frame (the figures and their bodies in slices, the minimap's drawing on a worker thread) and the
## wood a piece a dressing part, and ends with the nodes an unstaged build makes.

## The longest a staged load is waited for (ms): its nav grid is built on a worker thread.
const LOAD_WAIT_MSEC := 90000
const LOG_ROOT := "user://test-aud2-perf-logs"
## A node named by the engine (@Class@number): its number differs from one build to the next.
## A staged session's nodes once built (_built_at_last).
var _staged_lines := PackedStringArray()
static var _auto_name: RegEx = RegEx.create_from_string("@(\\w+)@\\d+")
const PARTS_DIR := "res://assets/models/replicaParts/"
## A glb's header and its first chunk's (bytes), and the JSON chunk's type.
const GLB_HEADER := 12
const CHUNK_HEADER := 8
const JSON_CHUNK := 0x4E4F534A


func _free(taken: Dictionary[StringName, Node3D]) -> void:
	for node: Node3D in taken.values():
		node.free()


## A line for every node under `node`: its name, class, place, and (a mesh) the mesh itself, so two takes can be
## compared down to the mesh drawn.
func _lines(node: Node, depth: int, out: PackedStringArray) -> void:
	var line := "%d %s %s %s" % [depth, node.name, node.get_class(), node.owner]
	if node is Node3D:
		line += " %s %s" % [(node as Node3D).transform, (node as Node3D).visible]
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		line += " %d %s" % [mi.mesh.get_surface_count(), mi.mesh.get_aabb()]
		for i in mi.mesh.get_surface_count():
			line += " %d %s" % [mi.mesh.surface_get_array_len(i), mi.mesh.surface_get_material(i).resource_name]
		for i in mi.get_surface_override_material_count():
			line += " %s" % mi.get_surface_override_material(i)
	out.append(line)
	for child: Node in node.get_children():
		_lines(child, depth + 1, out)


## A menu's part and its inside, as lines (take with `figure` false, then inside), freed.
func _part_lines(key: StringName, slot: StringName, part: StringName) -> String:
	var out := PackedStringArray()
	var taken := ReplicaParts.take(key, {slot: part}, false)
	for s: StringName in taken:
		_lines(taken[s], 0, out)
	_free(taken)
	var inside := ReplicaParts.inside(key, slot, part)
	if inside != null:
		_lines(inside, 0, out)
		inside.free()
	return "\n".join(out)


# --- Practice's groundwork ---


func test_practice_finds_no_vault_links_nor_cover_and_stages_none() -> void:
	var session := PlaySession.new()
	session.practice = true
	session.map_id = "range"
	add_child_autofree(session)
	await wait_physics_frames(2)
	assert_not_null(session._sim.nav, "the grid is built (the targets are laid out on it)")
	assert_eq(session._sim.nav.vault_base, -1, "no vault links found")
	assert_true(session._bots.world.low_cover.is_empty() and session._bots.world.tall_cover.is_empty(), "no cover")
	assert_true(session._prepare_bots(), "the staged groundwork is done at once")
	assert_eq(session._cover_task, -1, "and no cover task started")
	assert_false(session._bot_options().groundwork)


func test_a_match_s_bots_still_find_their_groundwork() -> void:
	assert_true(BotController.Options.new().groundwork, "on unless practice turns it off")
	var session := PlaySession.new()
	assert_true(session._bot_options().groundwork)
	session.free()


# --- A skipped round's figures ---


func test_a_held_figure_snaps_to_its_pose_when_next_posed() -> void:
	var f := FigureView.new()
	f._snap = false
	f._fired = true
	f.hold()
	assert_true(f._snap, "posed again, it snaps")
	assert_false(f._fired, "a shot under the cover is not played after it")
	f.free()


func test_a_skip_holds_every_figure_and_the_frame_after_it_poses_them() -> void:
	var session := PlaySession.new()
	session.bots_active = false
	session.difficulty = &"easy"
	session.settings = Settings.new()
	add_child_autofree(session)
	await wait_physics_frames(2)
	RoundHold.release(session.state)
	session.player.status = Character.Status.OUT
	session.start_skip()
	await wait_process_frames(1)
	assert_true(session.skipping())
	assert_gt(session._figures.size(), 0)
	for f in session._figures:
		assert_true(f._snap, "%s: held under the cover" % f.name)
	session._stop_skip()
	await wait_process_frames(1)
	for f in session._figures:
		if f.visible:
			assert_false(f._snap, "%s: posed on the first frame the field shows" % f.name)


# --- A menu's part pictures ---


func test_a_kept_menu_part_and_its_inside_are_a_plain_takes_nodes() -> void:
	for slot: StringName in [&"optic", &"barrel", &"magazine"]:
		for part: StringName in PartsFor.of(slot):
			var plain := _part_lines(&"aeg", slot, part)
			ReplicaParts.keep()
			var kept := _part_lines(&"aeg", slot, part)
			var again := _part_lines(&"aeg", slot, part)
			ReplicaParts.release()
			assert_ne(plain, "", "%s %s taken" % [slot, part])
			assert_eq(kept, plain, "%s %s: the same nodes kept" % [slot, part])
			assert_eq(again, plain, "%s %s: and again from the kept file" % [slot, part])


func test_part_pictures_keep_the_parts_files_for_the_frame_only() -> void:
	var pictures := ReplicaPictures.new()
	add_child_autofree(pictures)
	pictures.part_extent(&"aeg", &"optic", &"redDot")
	pictures.part_extent(&"aeg", &"optic", &"scope2x")
	assert_true(ReplicaParts._keeping, "kept while the frame makes its pictures")
	assert_eq(ReplicaParts._kept.size(), 2, "one parts file and one inside file")
	await wait_process_frames(1)
	assert_false(ReplicaParts._keeping, "let go at the frame's end")
	assert_eq(ReplicaParts._kept.size(), 0, "their instances freed")
	pictures.part_extent(&"aeg", &"barrel", &"long")
	remove_child(pictures)
	assert_false(ReplicaParts._keeping, "and when the pictures leave the tree")
	assert_eq(ReplicaParts._kept.size(), 0)
	pictures.let_go_parts()


# --- LogTail ---


func after_each() -> void:
	if DirAccess.dir_exists_absolute(LOG_ROOT):
		for f: String in DirAccess.get_files_at(LOG_ROOT):
			DirAccess.remove_absolute(LOG_ROOT.path_join(f))
		DirAccess.remove_absolute(LOG_ROOT)


func test_a_log_over_several_count_pieces_is_counted_whole() -> void:
	DirAccess.make_dir_recursive_absolute(LOG_ROOT)
	var f := FileAccess.open(LOG_ROOT.path_join("godot2026-11-14T10.00.00.log"), FileAccess.WRITE)
	var lines := 0
	while f.get_length() < LogTail.COUNT_BYTES * 2 + LogTail.TAIL_BYTES + 77:
		lines += 1
		f.store_line("line %d" % lines)
	f.store_string("the last, no newline")
	f.close()
	var t := LogTail.new()
	t.dir = LOG_ROOT
	assert_eq(t.line_count(), lines + 1)
	assert_eq(t.lines()[LogTail.LINES - 1], "the last, no newline")
	assert_eq(t.lines()[LogTail.LINES - 2], "line %d" % lines)
	assert_true(t.recent_lines()[0].begins_with("line "), "whole lines only")


# --- The parts files' images ---


## `path`'s glTF JSON (its first chunk), or {} if it is not a glb.
func _glb_json(path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < GLB_HEADER + CHUNK_HEADER or bytes.decode_u32(GLB_HEADER + 4) != JSON_CHUNK:
		return {}
	var length := bytes.decode_u32(GLB_HEADER)
	var text := bytes.slice(GLB_HEADER + CHUNK_HEADER, GLB_HEADER + CHUNK_HEADER + length).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func test_no_parts_file_carries_an_image_inside_it() -> void:
	var looked := 0
	for f: String in DirAccess.get_files_at(PARTS_DIR):
		if not f.ends_with(".glb"):
			continue
		var doc := _glb_json(PARTS_DIR + f)
		assert_false(doc.is_empty(), "%s reads" % f)
		var images: Array = doc.get("images", [])
		for image: Dictionary in images:
			assert_false(image.has("bufferView"), "%s: %s is not inside the file" % [f, image.get("name")])
			assert_true(FileAccess.file_exists(PARTS_DIR + String(image.get("uri", ""))), "%s: its %s beside it" % [f,
					image.get("name")])
		looked += 1
	assert_gt(looked, 0)


func test_the_parts_files_masks_still_reach_their_materials() -> void:
	for id: String in ["aeg", "pistol"]:
		var scene := (load(PARTS_DIR + id + ".glb") as PackedScene).instantiate()
		var mask := load(PARTS_DIR + id + "_wear.png") as Texture2D
		var found := 0
		for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
			var mesh := (node as MeshInstance3D).mesh
			for i in mesh.get_surface_count():
				var m := mesh.surface_get_material(i) as BaseMaterial3D
				if m != null and m.ao_texture != null:
					assert_eq(m.ao_texture, mask, "%s %s: the mask beside the file" % [id, node.name])
					found += 1
		assert_gt(found, 0, "%s: its masked surfaces" % id)
		scene.free()


# --- The loading screen's pieces ---


## A line for each node under `node` (its path and class; with `places` its place and each multimesh's instances), so
## two builds can be compared.
func _tree_lines(node: Node, out: PackedStringArray, places: bool = true) -> void:
	for child: Node in node.get_children():
		var line := "%s %s" % [_auto_name.sub(String(node.get_path_to(child)), "@$1@", true), child.get_class()]
		if places and child is Node3D:
			line += " %s" % (child as Node3D).transform
		if places and child is MultiMeshInstance3D:
			var mm := (child as MultiMeshInstance3D).multimesh
			line += " %d" % mm.instance_count
			for i in mini(mm.instance_count, 8):
				line += " %s" % mm.get_instance_transform(i)
		out.append(line)
		_tree_lines(child, out, places)


func _built_at_last(step: int, steps: int, _key: String, session: PlaySession) -> void:
	if step == steps:
		_staged_lines.clear()
		_tree_lines(session, _staged_lines, false)


func _session(staged: bool) -> PlaySession:
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.map_id = "depot"
	session.match_seed = 7
	session.autopilot = true
	session.staged = staged
	add_child_autofree(session)
	return session


func test_a_wood_built_a_piece_at_a_time_is_the_wood_built_at_once() -> void:
	var play := PlayTuning.load_default()
	var m := MapData.load_map("woodland", play.map_style, 1)
	for night: bool in [false, true]:
		var light := play.lighting.duplicate() as LightingConfig
		light.night = night
		var whole := WoodsView.build(m, play.woods, play.skyline, light, play.map_style, play.site_look.props)
		var view := WoodsView.begin(m, play.woods, play.skyline, light, play.map_style, play.site_look.props)
		for piece in WoodsView.PIECES:
			view.build_piece(piece)
		view = WoodsView.finish(view)
		var a := PackedStringArray()
		var b := PackedStringArray()
		_tree_lines(whole, a)
		_tree_lines(view, b)
		assert_gt(a.size(), 3, "night %s: Woodland's wood has its parts" % night)
		assert_eq(b, a, "night %s: the same nodes, places and instances" % night)
		whole.free()
		view.free()
	var bare := WoodsView.begin(MapData.load_map("depot", play.map_style, 1), play.woods, play.skyline, play.lighting,
			play.map_style)
	for piece in WoodsView.PIECES:
		bare.build_piece(piece)
	assert_null(WoodsView.finish(bare), "no wood on a field without trees")


func test_a_staged_load_builds_the_views_over_frames_and_the_nodes_an_unstaged_build_makes() -> void:
	var whole := _session(false)
	var a := PackedStringArray()
	# Their places move with their first frames: what is built is compared, the wood's places above.
	_tree_lines(whole, a, false)
	var staged := PlaySession.new()
	staged.settings = Settings.new(PlayTuning.new())
	staged.map_id = "depot"
	staged.match_seed = 7
	staged.autopilot = true
	staged.staged = true
	# Its nodes the moment its last step is done, before a frame of play moves them.
	staged.progressed.connect(_built_at_last.bind(staged))
	add_child_autofree(staged)
	# The engine's own frame count at the first and the last look that finds the views' pieces under way: the pieces
	# after the first take a frame each at least (four), and a look may come a frame late on a busy machine or miss
	# one on a quick one, so the looks are not counted (a count of them read 3 where four frames had passed).
	var first_frame := -1
	var last_frame := -1
	# By the clock, not a frame count: the nav grid is built on a worker thread, and headless frames pass far faster.
	var until := Time.get_ticks_msec() + LOAD_WAIT_MSEC
	while staged._bots == null and Time.get_ticks_msec() < until:
		await wait_process_frames(1)
		if staged._step == PlaySession.VIEWS_STEP and staged._views_piece > PlaySession.VIEWS_FIRST:
			if first_frame < 0:
				first_frame = Engine.get_process_frames()
			last_frame = Engine.get_process_frames()
	assert_not_null(staged._bots, "the staged load finished")
	assert_gt(first_frame, -1, "the views' pieces were seen under way")
	assert_gt(last_frame - first_frame, 0, "its views were built over several frames, not in one")
	assert_eq(staged._minimap_task, -1, "the minimap's drawing was taken")
	var b := _staged_lines
	assert_eq(b.size(), a.size(), "as many nodes")
	var differ := 0
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			differ += 1
			if differ < 4:
				assert_eq(b[i], a[i], "node %d" % i)
	assert_eq(differ, 0, "the same nodes in the same order")
	var fa := whole._hud.minimap()._field
	var fb := staged._hud.minimap()._field
	assert_eq(fb.layers.size(), fa.layers.size())
	for i in fa.layers.size():
		assert_eq(fb.layers[i].get_data(), fa.layers[i].get_data(), "the minimap's storey %d drawn the same" % i)


## The parts of `slot` the AEG's parts file holds, by Key.
class PartsFor:
	static func of(slot: StringName) -> Array[StringName]:
		match slot:
			&"optic":
				return [&"redDot", &"scope2x", &"scopeVar"]
			&"barrel":
				return [&"long", &"tightBore"]
		return [&"hiCap", &"lowCap"]
