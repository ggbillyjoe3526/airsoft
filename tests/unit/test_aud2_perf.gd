extends GutTest
## The second audit's performance fixes (AUD2): Practice finds none of the bots' groundwork (the vault links and the
## cover: no bot reads them, and your own vault and climb read the level, not the grid), a skipped round's figures are
## not posed under its cover and snap to their pose when it lifts, a menu's part pictures come out of one instance of
## each parts file a frame (ReplicaParts.keep, the same nodes as a plain take's and inside's), and LogTail reads only a
## log's end and counts the rest of its lines a piece at a time.

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


## The parts of `slot` the AEG's parts file holds, by Key.
class PartsFor:
	static func of(slot: StringName) -> Array[StringName]:
		match slot:
			&"optic":
				return [&"redDot", &"scope2x", &"scopeVar"]
			&"barrel":
				return [&"long", &"tightBore"]
		return [&"hiCap", &"lowCap"]
