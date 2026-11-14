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


func test_mesh_detail_low_reads_the_replica_grain_from_one_side() -> void:
	var table := GraphicsTable.shared()
	var rs := GraphicsApply.Server.new()
	var view := SubViewport.new()
	add_child_autofree(view)
	assert_eq(float(ProjectSettings.get_setting("shader_globals/look_surface_detail")["value"]), 1.0,
			"the project's default: the whole grain")
	GraphicsApply.apply(table.preset(&"low"), view, rs)
	assert_eq(rs.surface_detail, 0.0, "Low: one side's grain")
	for preset: StringName in [&"medium", &"high", &"ultra"]:
		GraphicsApply.apply(table.preset(preset), view, rs)
		assert_eq(rs.surface_detail, 1.0, "%s: the approved look, all three sides" % preset)
	GraphicsApply.apply(table.preset(&"high"), view, GraphicsApply.Server.new())


func test_a_slow_sprung_sniper_rifle_s_bolt_is_home_with_the_recorded_knock() -> void:
	var vm := ViewModelConfig.new()
	for cycle: float in [1.25, 1.32, 1.39]:
		var r := ReplicaStats.load_replica(&"sniper").duplicate() as ReplicaConfig
		r.fire_rate = 1.0 / cycle
		var view := ReplicaView.new()
		add_child_autofree(view)
		view.setup(vm, [r] as Array[ReplicaConfig], BoxWorld.new())
		var held: ReplicaView.Held = view._held[0]
		var home := vm.bolt_cycle_end / held.fire_speed
		gut.p("a %.2f s cycle: the bolt home %.3f s after the shot, %.3f s before it can fire" % [cycle, home,
				cycle - home])
		assert_almost_eq(home, minf(cycle, vm.bolt_knock_at), 1e-4, "home with the last knock, never after it")


func test_a_holstered_figure_stepping_swings_a_share_of_the_sprint_s_pump() -> void:
	var c := _character()
	c.armament.holstered = true
	var v := _view(c)
	for i in 60:
		c.prev_walk_cycle = c.walk_cycle
		c.velocity = Vector3(0.0, 0.0, -hits.holster_step_speed)
		c.walk_cycle += 0.2
		_frame(v, c)
	var mix: float = v.body().tree.get(FigureGraph.P_HOLSTER_MIX)
	assert_almost_eq(mix, hits.holster_step_mix, 0.02, "at a run, holster_step_mix of the pump")
	c.velocity = Vector3(0.0, 0.0, -hits.holster_step_speed * 0.5)
	for i in 60:
		_frame(v, c)
	mix = v.body().tree.get(FigureGraph.P_HOLSTER_MIX)
	assert_almost_eq(mix, hits.holster_step_mix * 0.5, 0.02, "at half the speed, half of that")
	c.velocity = Vector3.ZERO
	for i in 60:
		_frame(v, c)
	assert_eq(v.body().tree.get(FigureGraph.P_HOLSTER_MIX), 0.0, "standing, the arms hang")
	# In the air the arms hang, as the hit volume's do (HitPose asks grounded): QA's advisory, 2026-11-14.
	c.velocity = Vector3(0.0, 0.0, -hits.holster_step_speed)
	c.grounded = false
	for i in 60:
		_frame(v, c)
	assert_eq(v.body().tree.get(FigureGraph.P_HOLSTER_MIX), 0.0, "running through the air, the arms hang")
	c.grounded = true
	for i in 60:
		_frame(v, c)
	assert_almost_eq(v.body().tree.get(FigureGraph.P_HOLSTER_MIX) as float, hits.holster_step_mix, 0.02, "and landed, pump")


## Runs a switch to slot `to` of `frames` frames on `v` from `c`, stopping at frame `stop` (the draw's share there).
func _switch_to(v: FigureView, c: Character, to: int, frames: int, stop: int) -> void:
	var a := c.armament
	a.active = to
	a.draw_total = frames * FRAME
	for i in stop + 1:
		a.draw_left = a.draw_total - i * FRAME
		_frame(v, c)


func test_a_switch_between_two_pistols_plays_out_to_the_hand_over_and_back() -> void:
	var frames := 40
	# Two pistols: the default loadout's pistol in both slots.
	var two := _character()
	two.armament.replicas[0] = two.armament.replicas[1]
	two.armament.active = 0
	var same := _view(two)
	# The rifle-to-pistol switch, its hand-over at switch_pistol_from of the draw.
	var cross_c := _character()
	var cross := _view(cross_c)
	for i in 5:
		_frame(same, two)
		_frame(cross, cross_c)
	_switch_to(same, two, 1, frames, frames / 2)
	_switch_to(cross, cross_c, 1, frames, roundi(frames * config.switch_pistol_from))
	var gap := _arm_gap(same, cross)
	gut.p("two pistols at half the draw against rifle to pistol at its hand-over: %.2f°" % rad_to_deg(gap))
	assert_lt(gap, deg_to_rad(2.0), "at half the draw the pistol's arms are where the clip hands over")
	assert_eq(same.body().hands.in_hand, 1, "the new pistol from half the draw")
	for i in range(frames / 2 + 1, frames):
		two.armament.draw_left = two.armament.draw_total - i * FRAME
		_frame(same, two)
	assert_true(same.body().tree.get(FigureGraph.P_SWITCH_ACTIVE), "still switching near the draw's end")
