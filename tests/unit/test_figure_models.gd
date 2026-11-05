extends GutTest
## FI1: the rigged figures' files (game/play/figures/figure_models.gd, figure_sidecar.gd): each kind loaded once a
## session with its typed sidecar, its clips looped as the sidecar says, and a missing or unreadable sidecar leaving
## its figures with no body.

const BLENDER_ROWS := [[0.0, 1.0, 0.0, 0.5], [-1.0, 0.0, 0.0, 0.25], [0.0, 0.0, 1.0, -0.125], [0.0, 0.0, 0.0, 1.0]]

var models: FigureModels = null


func before_all() -> void:
	models = FigureModels.new(FigureConfig.new())
	assert_true(models.load_kinds(), "both kinds load")


func test_both_kinds_load_with_their_sidecars() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		assert_true(models.has_kind(kind))
		var side := models.sidecar(kind)
		assert_eq(side.clips.size(), 32, "every clip")
		assert_true(side.parts.has("Body_LOD2"))
		assert_true(side.replica_on_grip.has(&"rifle") and side.replica_on_grip.has(&"pistol"))
		var reload: FigureSidecar.Magazine = side.magazine_in_hand.get(&"Rifle_Reload")
		assert_not_null(reload)
		assert_eq(reload.bone, &"Hand_L")
		assert_almost_eq(reload.to, 0.5093, 1e-6)
		assert_not_null(reload.old, "the old magazine")
		assert_almost_eq(reload.old.lifetime, 3.0, 1e-6)
	assert_eq(models.sidecar(FigureMix.HUMAN).parts.size(), 26, "human: body, four heads, kit, pack, radio, pads")
	assert_eq(models.sidecar(FigureMix.ROBOT).parts.size(), 9)


func test_the_sidecar_is_typed() -> void:
	var side := models.sidecar(FigureMix.HUMAN)
	var run := side.clip(&"Run_F")
	assert_true(run.loop)
	assert_almost_eq(run.speed, 4.2, 1e-6)
	assert_false(run.upper_body_only)
	assert_eq(run.fit_to, &"")
	var reload := side.clip(&"Rifle_Reload")
	assert_false(reload.loop)
	assert_true(reload.upper_body_only)
	assert_eq(reload.fit_to, &"reloadTime")
	assert_eq(side.clip(&"Idle").speed, 0.0, "no gait: null in the file")
	assert_null(side.clip(&"Nope"))


func test_a_row_major_matrix_is_read_as_given() -> void:
	var s := FigureSidecar.parse(JSON.stringify({"clips": [], "parts": ["Body"], "replicaOnGrip": {"rifle": BLENDER_ROWS}}))
	var t: Transform3D = s.replica_on_grip[&"rifle"]
	assert_eq(t.origin, Vector3(0.5, 0.25, -0.125))
	assert_eq(t.basis.x, Vector3(0.0, -1.0, 0.0), "the first column")
	assert_eq(t.basis.y, Vector3(1.0, 0.0, 0.0))


func test_each_clip_loops_as_the_sidecar_says() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		var lib := models.library(kind)
		for clip in models.sidecar(kind).clips:
			var anim := lib.get_animation(clip.name)
			assert_not_null(anim, String(clip.name))
			var want := Animation.LOOP_LINEAR if clip.loop else Animation.LOOP_NONE
			assert_eq(anim.loop_mode, want, String(clip.name))
	assert_eq(models.library(FigureMix.HUMAN).get_animation(&"Idle").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(models.library(FigureMix.HUMAN).get_animation(&"HitCall").loop_mode, Animation.LOOP_NONE)


func test_loading_again_changes_nothing() -> void:
	var lib := models.library(FigureMix.ROBOT)
	assert_true(models.load_kinds())
	assert_same(models.library(FigureMix.ROBOT), lib, "once a session")


func test_materials_are_every_one_a_figure_wears_made_once() -> void:
	var config := FigureConfig.new()
	var models := FigureModels.new(config)
	models.load_kinds()
	var colours := PackedColorArray([Color.RED, Color.BLUE])
	var all := models.materials(colours, 0.3)
	var made := models.team_material_count()
	assert_gt(made, 0, "the Team* paints made for both teams")
	assert_eq(models.materials(colours, 0.3), all, "the same ones again")
	assert_eq(models.team_material_count(), made, "nothing made twice")
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		for team in 2:
			var b := FigureBody.new()
			assert_true(b.setup(models, kind, 1, team, colours[team], 0.3, config.lod_high))
			add_child_autofree(b)
			for mi in b.meshes:
				for i in mi.mesh.get_surface_count():
					var m := mi.get_active_material(i)
					if m != null:
						assert_true(all.has(m), "kind %d team %d: %s listed" % [kind, team, m.resource_name])
	assert_eq(models.team_material_count(), made, "the bodies wear the very ones listed")


func test_a_missing_sidecar_leaves_no_body() -> void:
	var config := FigureConfig.new()
	config.models_dir = "res://nowhere/"
	var none := FigureModels.new(config)
	assert_false(none.load_kinds())
	assert_false(none.has_kind(FigureMix.HUMAN))
	assert_null(none.scene(FigureMix.ROBOT))
	var view := FigureView.new()
	add_child_autofree(view)
	view.setup(Character.new(3, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()), Color.RED, HitConfig.new(),
			null)
	view.set_body(none, FigureMix.HUMAN, config.lod_high)
	assert_null(view.body(), "none")
	assert_eq(view.find_children("*", "FigureBody", true, false).size(), 0)


func test_an_unreadable_sidecar_reads_as_null() -> void:
	assert_null(FigureSidecar.parse("not json"))
	assert_null(FigureSidecar.parse("[1, 2]"), "not an object")
	assert_null(FigureSidecar.parse(JSON.stringify({"clips": [{"seconds": 1.0}], "parts": []})), "a clip with no name")
	assert_null(FigureSidecar.parse(JSON.stringify({"clips": []})), "no parts")
	assert_null(FigureSidecar.read("res://nowhere/human.json"))
	assert_not_null(FigureSidecar.parse(JSON.stringify({"clips": [], "parts": ["Body"]})))


func test_an_empty_parts_list_reads_as_null() -> void:
	assert_null(FigureSidecar.parse(JSON.stringify({"clips": [], "parts": []})), "nothing to draw")


func test_odd_sidecars_read_without_a_script_error() -> void:
	for text: String in ["", "null", "[]", "{}", "{\"clips\": 5, \"parts\": [\"Body\"]}",
			"{\"clips\": [null], \"parts\": [\"Body\"]}", "{\"clips\": [], \"parts\": [1]}",
			"{\"clips\": [{\"name\": \"Idle\", \"seconds\": \"x\"}], \"parts\": [\"Body\"]}",
			"{\"clips\": [], \"parts\": [\"Body\"], \"replicaOnGrip\": 4, \"magazineInHand\": [1]}",
			"{\"clips\": [], \"parts\": [\"Body\"], \"replicaOnGrip\": {\"rifle\": [[1,2],[3]]}, " +
			"\"magazineInHand\": {\"a\": 5, \"b\": {}}}", "\u0001"]:
		FigureSidecar.parse(text, "odd")
	var s := FigureSidecar.parse("{\"clips\": [], \"parts\": [\"Body\"], \"replicaOnGrip\": {\"rifle\": [[1,2],[3]]}}")
	assert_eq(s.replica_on_grip[&"rifle"], Transform3D.IDENTITY, "a short matrix is identity")
