extends GutTest
## BP9 QA: the lowered frame head leaves every door's leaves fitting and its frame on the floor, opening unchanged.

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()


func test_every_doors_leaves_stand_on_the_frames_floor_and_reach_at_least_its_head() -> void:
	var doors := 0
	for id: String in ["depot", "woodland"]:
		var map := MapData.load_map(id, play.map_style, tuning.rounds.team_size)
		var view := DoorView.build(map, play.map_style, 0.4)
		add_child_autofree(view)
		for i in map.doors.size():
			var frame := view.frame_at(i)
			for j: int in [i * 2, i * 2 + 1]:
				var leaf := view.leaf_at(j)
				assert_almost_eq(leaf.origin.y - leaf.basis.y.length() * 0.5, frame.origin.y, 1e-3,
						"%s door %d leaf %d: the leaf's foot where the frame's is" % [id, i, j])
			doors += 1
	assert_eq(doors, 23, "Depot's 15 doors and Woodland's 8")
