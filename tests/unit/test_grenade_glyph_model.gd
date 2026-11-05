extends GutTest
## MP1 (QA): the bomb icon's model picture across kind changes, other sizes, a scaled parent and being freed. Each
## check holds with or without a grenade model on disk, and takes the model path when one is there.

func _has_model(kind: int) -> bool:
	return not ReplicaPictures.grenade_path(kind).is_empty()


func test_a_kind_without_a_model_has_no_texture() -> void:
	var pictures := ReplicaPictures.new()
	add_child_autofree(pictures)
	assert_null(pictures.grenade_texture(Grenade.Kind.NONE))
	assert_null(pictures.grenade_texture(99))
	assert_eq(ReplicaPictures.grenade_path(-1), "")
	assert_eq(ReplicaPictures.grenade_path(99), "")


func test_changing_the_kind_in_the_tree_follows_the_new_kinds_model() -> void:
	var icon := GrenadeGlyph.new(Grenade.Kind.SMOKE, 44.0)
	add_child_autofree(icon)
	icon.kind = Grenade.Kind.FLASH
	assert_eq(icon.shows_model(), _has_model(Grenade.Kind.FLASH))
	icon.kind = Grenade.Kind.NONE
	assert_false(icon.shows_model(), "a kind with no model draws the flat can")
	icon.kind = Grenade.Kind.SMOKE
	assert_eq(icon.shows_model(), _has_model(Grenade.Kind.SMOKE))


func test_a_picture_is_drawn_once_per_kind_and_size_is_kept() -> void:
	if not _has_model(Grenade.Kind.SMOKE):
		pending("no smoke model on disk")
		return
	var pictures := ReplicaPictures.new()
	add_child_autofree(pictures)
	var first := pictures.grenade_texture(Grenade.Kind.SMOKE, 96)
	assert_not_null(first)
	assert_same(pictures.grenade_texture(Grenade.Kind.SMOKE, 200), first, "the first call's size stays")


func test_a_scaled_parent_and_huge_or_zero_sizes_stay_inside_the_picture_bounds() -> void:
	if not _has_model(Grenade.Kind.SMOKE):
		pending("no smoke model on disk")
		return
	var holder := Control.new()
	holder.scale = Vector2(10.0, 10.0)
	add_child_autofree(holder)
	var big := GrenadeGlyph.new(Grenade.Kind.SMOKE, 500.0)
	holder.add_child(big)
	var zero := GrenadeGlyph.new(Grenade.Kind.SMOKE, 0.0)
	holder.add_child(zero)
	assert_true(big.shows_model() and zero.shows_model())
	await wait_physics_frames(2)
	for icon: GrenadeGlyph in [big, zero]:
		var pictures := icon.find_child("Pictures", false, false) as ReplicaPictures
		var side := pictures.grenade_texture(Grenade.Kind.SMOKE).get_size()
		assert_between(maxf(side.x, side.y), float(GrenadeGlyph.PICTURE_MIN), float(GrenadeGlyph.PICTURE_MAX))


func test_freed_icons_leave_no_orphan_nodes() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 3:
		var icon := GrenadeGlyph.new(Grenade.Kind.SMOKE, 44.0)
		add_child(icon)
		icon.kind = Grenade.Kind.FLASH
		icon.free()
	await wait_physics_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)


func test_an_icon_taken_out_of_the_tree_and_back_in_keeps_a_valid_picture() -> void:
	var icon := GrenadeGlyph.new(Grenade.Kind.SMOKE, 44.0)
	add_child(icon)
	var had := icon.shows_model()
	remove_child(icon)
	add_child(icon)
	assert_eq(icon.shows_model(), had)
	assert_eq(icon.get_children().size(), 1 if had else 0, "one Pictures child, not one per entry")
	icon.free()
