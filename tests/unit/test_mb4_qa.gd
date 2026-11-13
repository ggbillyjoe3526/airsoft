extends GutTest
## MB4 (QA): BU1's close-range rule covers the real Brow hazel. Two opposing bots standing in it pressed together have a
## shot: the leaves in the line are fewer than stop a BB. (At the 0.7 m of MB2's failing pair they still hold, by 4 cm.)

const HAZEL := Vector3(-16.3, 0.0, -40.5)
const APART := 0.5

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var style: MapStyle = PlayTuning.load_default().map_style
var map: MapData
var nav: NavGrid


func before_all() -> void:
	map = MapData.load_map("woodland", style, 8)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


func _fires_from(dx: float) -> bool:
	var level := MapLevel.new()
	add_child(level)
	level.build(map, style, tuning.body)
	var floor_y := nav.floor_at(Vector3(HAZEL.x, 50.0, HAZEL.z))
	var loadout := ReplicaStats.default_loadout()
	var pa := Vector3(HAZEL.x - dx, floor_y, HAZEL.z)
	var pb := Vector3(HAZEL.x + dx, floor_y, HAZEL.z)
	var me := Character.new(0, 0, pa, -PI * 0.5, loadout)
	var foe := Character.new(1, 1, pb, PI * 0.5, loadout)
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = config
	w.query = level.query()
	w.planner = RoundPlanner.new(1)
	w.characters = [me, foe]
	w.time = 10.0
	var eye := BotSenses.eye_of(me, tuning)
	var chest := BotSenses.body_point(foe, tuning.hits, config.aim_height_fraction)
	var held := BotCombat.leaves_in_line(w, eye, chest)
	level.free()
	return not held


func test_two_opposing_bots_pressed_together_in_the_brow_hazel_have_a_shot() -> void:
	assert_true(_fires_from(APART * 0.5), "0.5 m apart in the hazel: it fires, not held for the leaves")
