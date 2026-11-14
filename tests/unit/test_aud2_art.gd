extends GutTest
## The second audit's art fixes (AUD2): a figure shown again in the middle of a switch between replicas (it was hidden:
## your watched bot) plays the Switch clip from the draw's share, in step with a figure that was seen throughout, not
## from the clip's start.

const NEAR := Vector3(0.0, 1.6, 3.0)
const FRAME := 1.0 / 60.0
## The bones the Switch clip moves, compared between the two figures.
const ARM_BONES: Array[StringName] = [&"UpperArm_R", &"Forearm_R", &"Hand_R", &"UpperArm_L", &"Forearm_L", &"Hand_L"]

var config: FigureConfig = null
var models: FigureModels = null
var hits: HitConfig = null


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()
	hits = HitConfig.new()


func _character() -> Character:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	return c


func _view(c: Character) -> FigureView:
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, hits, null)
	v.set_body(models, FigureMix.HUMAN, config.lod_high)
	return v


## One frame of `v` posed from `c`, hidden from view when `hidden` (as the watched bot is).
func _frame(v: FigureView, c: Character, hidden: bool = false) -> void:
	v.update(c, 1.0)
	if hidden:
		v.visible = false
	v.animate(c, 1.0, FRAME, NEAR)


## The largest angle (rad) between the two figures' arm bones as the clips left them.
func _arm_gap(a: FigureView, b: FigureView) -> float:
	var gap := 0.0
	for bone: StringName in ARM_BONES:
		var ka := a.body().skeleton.find_bone(bone)
		var kb := b.body().skeleton.find_bone(bone)
		var qa := a.body().skeleton.get_bone_pose_rotation(ka)
		var qb := b.body().skeleton.get_bone_pose_rotation(kb)
		gap = maxf(gap, qa.angle_to(qb))
	return gap


func test_a_figure_shown_again_mid_switch_plays_it_from_the_draw_s_share() -> void:
	var frames := 36
	var shown_at := 18
	var check_at := 30
	for back: bool in [false, true]:
		var c := _character()
		var a := c.armament
		assert_eq(a.replicas[1].site_class, &"pistol", "the default loadout's second replica is a pistol")
		a.active = 1 if back else 0
		var seen := _view(c)
		var watched := _view(c)
		for i in 5:
			_frame(seen, c)
			_frame(watched, c)
		a.active = 0 if back else 1
		a.draw_total = frames * FRAME
		var moved := 0.0
		for i in frames:
			a.draw_left = a.draw_total - i * FRAME
			_frame(seen, c)
			_frame(watched, c, i < shown_at)
			if i == shown_at - 1:
				moved = _arm_gap(seen, watched)
			if i == check_at:
				var gap := _arm_gap(seen, watched)
				gut.p("%s: arms %.1f° apart while hidden, %.2f° %d frames after showing" % [
						"to the rifle" if back else "to the pistol", rad_to_deg(moved), rad_to_deg(gap),
						check_at - shown_at])
				assert_gt(moved, deg_to_rad(5.0), "hidden, its arms stood still while the seen one switched")
				assert_lt(gap, deg_to_rad(1.0), "shown again it plays the Switch where the seen one is")
		a.draw_left = 0.0
