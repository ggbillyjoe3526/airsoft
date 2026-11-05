class_name PowerModels
## Which model draws each power source in the menus (the browser game's config/assets.ts `POWER_SOURCE_FILE`): the file in
## assets/models/powerSources/ and, for the gas bottle (one model, three gases) and the spring (three springs), the colour
## its `Label` takes. By pool.md ID; a power source with no entry has no picture (tests/unit/test_armory.gd fails when
## one is added without).

const BATTERY_FILE := &"standardBattery"
const LIPO_FILE := &"lipoBattery"
const BOTTLE_FILE := &"gasBottle"
## The springs' one coil (SN1, rebuilt BL7), its whole wire painted in each spring's colour.
const SPRING_FILE := &"spring"
## How far (rad, about X) a spring is tipped: like a battery, it lies along the picture, thin.
const SPRING_TIP := 0.6
## The label colour a file with no `Label` is asked for.
const NO_LABEL := Color.WHITE
## How far (rad, about X) a battery is tipped up its lead end: it lies along the picture, thin; tipped it fills it. The
## bottle stands as it is.
const BATTERY_TIP := 0.6

const PICTURES: Dictionary[String, Dictionary] = {
	"000003": {"file": BATTERY_FILE, "tip": BATTERY_TIP},
	"000015": {"file": LIPO_FILE, "tip": BATTERY_TIP},
	"000004": {"file": BOTTLE_FILE, "label": Color("6bc47c")},
	"000008": {"file": BOTTLE_FILE, "label": Color("c8382c")},
	"000009": {"file": BOTTLE_FILE, "label": Color("2a2b30")},
	"000022": {"file": SPRING_FILE, "tip": SPRING_TIP, "label": Color("8a5cc7")},
	"000023": {"file": SPRING_FILE, "tip": SPRING_TIP, "label": Color("c8382c")},
	"000024": {"file": SPRING_FILE, "tip": SPRING_TIP, "label": Color("2a2b30")},
}


static func has(id: String) -> bool:
	return PICTURES.has(id)


## The model file of power source `id` ("" if it has none).
static func file(id: String) -> StringName:
	return PICTURES[id]["file"] if PICTURES.has(id) else &""


## The colour of its label.
static func label(id: String) -> Color:
	return PICTURES[id].get("label", NO_LABEL) if PICTURES.has(id) else NO_LABEL


## How far its model is tipped (rad).
static func tip(id: String) -> float:
	return PICTURES[id].get("tip", 0.0) if PICTURES.has(id) else 0.0
