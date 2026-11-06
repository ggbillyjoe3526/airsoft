extends GutTest
## BW1 QA: the arms' bolt clip through a second shot, a switch, an inspect and a long frame.

const DT := 1.0 / 60.0

var cfg: ViewModelConfig = null


func before_each() -> void:
	cfg = ViewModelConfig.new()


func _hands(ids: Array) -> ReplicaView:
	var loadout: Array[ReplicaConfig] = []
	for id: StringName in ids:
		loadout.append(ReplicaStats.load_replica(id))
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(cfg, loadout, BoxWorld.new())
	return hands


func _clips(hands: ReplicaView) -> AnimationPlayer:
	return hands._arms._model.find_child("AnimationPlayer", true, false) as AnimationPlayer


func test_a_second_shot_in_the_run_on_restarts_the_bolt() -> void:
	var hands := _hands([&"sniper"])
	hands._show(0)
	var held: ReplicaView.Held = hands._held[0]
	var arms := _clips(hands)
	hands.on_shot()
	held.anim.seek(held.anim.get_animation(&"Fire").length - 0.01, true)
	hands._arms.follow(held.anim, DT)
	held.anim.pause()
	hands._arms.follow(held.anim, 0.1)
	assert_gt(arms.current_animation_position, held.anim.get_animation(&"Fire").length, "control: in the run-on")
	hands.on_shot()
	hands._arms.follow(held.anim, DT)
	assert_eq(arms.assigned_animation, &"sniper_Fire", "still the bolt")
	assert_lt(arms.current_animation_position, 0.05, "restarted with the replica's clip")


func test_switching_away_and_back_mid_cycle_does_not_resume_a_stale_run_on() -> void:
	var hands := _hands([&"sniper", &"aeg"])
	hands._show(0)
	var held: ReplicaView.Held = hands._held[0]
	var arms := _clips(hands)
	hands.on_shot()
	held.anim.seek(0.5, true)
	hands._arms.follow(held.anim, DT)
	held.anim.pause()
	hands._show(1)
	hands._arms.follow(hands._held[1].anim, DT)
	assert_eq(arms.assigned_animation, &"aeg_Hold", "the other replica's hold")
	hands._show(0)
	for i in 5:
		hands._arms.follow(held.anim, DT)
	assert_eq(arms.assigned_animation, &"sniper_Hold", "back on the hold, no stale bolt")


func test_an_inspect_mid_cycle_puts_the_hand_on_the_grip_and_a_long_frame_ends_the_run_on() -> void:
	var hands := _hands([&"sniper"])
	hands._show(0)
	var held: ReplicaView.Held = hands._held[0]
	var arms := _clips(hands)
	hands.on_shot()
	held.anim.seek(0.3, true)
	hands._arms.follow(held.anim, DT)
	held.anim.stop()
	held.anim.play(ReplicaView.INSPECT_CLIP)
	hands._arms.follow(held.anim, DT)
	assert_eq(arms.assigned_animation, &"sniper_Hold", "inspect cuts the bolt")
	hands._arms.follow(held.anim, 100.0)
	assert_eq(arms.assigned_animation, &"sniper_Hold", "a huge delta changes nothing")
	hands._arms.follow(null, DT)
	assert_eq(arms.assigned_animation, &"sniper_Hold", "no player: nothing")
