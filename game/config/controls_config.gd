class_name ControlsConfig
extends Resource
## The mouse and the order wheel (the browser game's config/controls.ts MOUSE, config/squad.ts ORDER_WHEEL). Read by
## PlayerInput. The settings screen (Settings) writes the player's own values over these defaults.

## View turn per mouse count at sensitivity 1 (rad): 1 is about 26 cm a full turn at 1600 DPI.
@export var radians_per_count: float = 0.001
@export var sensitivity: float = 1.0
## A multiplier on the turn while aiming down sights (1: the same as the hip), on top of scale_with_zoom.
@export var aim_sensitivity: float = 1.0
## Mouse forward looks down, like a flight stick.
@export var invert_y: bool = false
## Aiming down sights turns slower by the sight's zoom, so a mouse movement covers the same share of the view.
@export var scale_with_zoom: bool = true
## On, crouch stays down until pressed again (a sprint or jump stands you up); off, the default, crouch is held
## (owner, 2026-10-18).
@export var crouch_toggle: bool = false
## Aim down sights stays up until pressed again; off, the default, aim is held (owner, 2026-10-18).
@export var aim_toggle: bool = false
## Off, the default, reloads are manual: an empty replica stays empty and a prompt asks for the Reload key; on, a
## trigger pull on an empty replica reloads it (Settings › Controls › Reload; owner, 2026-10-29, RL2). PlayerInput
## writes it into each command (PlayerCommand.manual_reload).
@export var auto_reload: bool = false

## How an order on the order wheel is given (Settings › Controls › Order wheel, M23): HOVER, point at it and let go of
## the wheel's key (let go in the middle to give nothing), the default; CLICK, point at it and click (letting go of the
## key gives nothing). A click on an order gives it either way.
enum WheelPick { HOVER, CLICK }

@export var wheel_pick: WheelPick = WheelPick.HOVER
## The order wheel (M23; the browser game's config/squad.ts ORDER_WHEEL): its orders clockwise from the top, each an
## equal slice; each order's key (an action in KeyBindings.ACTIONS; empty for none), which gives it straight away; and
## its name on the wheel (a translation key; a button, so in title case). Team Plan ends the order in force; Need a Mag
## (MH3, upper left) is the magazine hand-off's press, as its key, and reads wheel_mag_toss while a teammate asking you
## is in reach. Go There (FM1, lower right) is a Go there ping where you looked opening the wheel, as its key.
@export var wheel_orders: Array[SquadOrder.Kind] = [
	SquadOrder.Kind.FOLLOW, SquadOrder.Kind.HOLD, SquadOrder.Kind.MOVE, SquadOrder.Kind.REGROUP,
	SquadOrder.Kind.TEAM_PLAN, SquadOrder.Kind.MAG,
]
@export var wheel_keys: Array[StringName] = [&"order_follow", &"order_hold", &"ping_move", &"order_regroup", &"",
		&"mag_hand_off"]
@export var wheel_labels: PackedStringArray = PackedStringArray(["ORDER_FOLLOW", "ORDER_HOLD", "ORDER_MOVE",
		"ORDER_REGROUP", "ORDER_TEAM_PLAN", "ORDER_MAG"])
## Need a Mag's name while a teammate asking you is in reach (a translation key).
@export var wheel_mag_toss: String = "ORDER_MAG_TOSS"
## While the wheel is open the mouse moves its own pointer, not the view: this many px a mouse count, times the
## sensitivity; never further than wheel_reach (px) from the middle, so coming back from a flick is short; on no order
## within wheel_dead_zone (px) of it.
@export var wheel_gain: float = 0.5
@export var wheel_reach: float = 90.0
@export var wheel_dead_zone: float = 24.0
## While the full-screen map is open (FM1) the mouse moves the map's pointer: this many px a mouse count, times the
## sensitivity.
@export var map_gain: float = 1.0
