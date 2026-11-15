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
## the wheel's key, the default; CLICK, point at it and click (letting go of the key gives only a tap's Spotted). A
## click on an order gives it either way.
enum WheelPick { HOVER, CLICK }

@export var wheel_pick: WheelPick = WheelPick.HOVER
## The order wheel (CW1, owner 2026-11-15, after Battlefield's commo rose; M23 before it): Spotted in a circle in the
## middle and two columns of wheel_rows buttons, all one size, each name alone (no keys shown). wheel_orders lists the
## right column top to bottom, then the left; wheel_keys each order's key (an action in KeyBindings.ACTIONS; empty for
## none), which gives it straight away and is never drawn; wheel_labels the name on each (a translation key; a button,
## so in title case). An entry of NONE with an empty name is a button kept free (drawn empty, gives nothing). Team Plan ends the
## order in force; Need a Mag (MH3) is the magazine hand-off's press, as its key, and reads wheel_mag_toss while a
## teammate asking you is in reach; Go There (FM1) is a Go there ping where you looked opening the wheel, as its key;
## Watching Here (BP8) a Watching here ping there; Cover Me (CW1) has a teammate cover the way you look. The keys keep
## their own actions (KeyBindings). The order is the owner's (2026-11-15).
@export var wheel_orders: Array[SquadOrder.Kind] = [
	SquadOrder.Kind.WATCH, SquadOrder.Kind.FOLLOW, SquadOrder.Kind.COVER, SquadOrder.Kind.MAG,
	SquadOrder.Kind.TEAM_PLAN, SquadOrder.Kind.MOVE, SquadOrder.Kind.HOLD, SquadOrder.Kind.REGROUP,
]
@export var wheel_keys: Array[StringName] = [&"", &"order_follow", &"", &"mag_hand_off", &"", &"ping_move",
		&"order_hold", &"order_regroup"]
@export var wheel_labels: PackedStringArray = PackedStringArray(["ORDER_WATCH", "ORDER_FOLLOW", "ORDER_COVER",
		"ORDER_MAG", "ORDER_TEAM_PLAN", "ORDER_MOVE", "ORDER_HOLD", "ORDER_REGROUP"])
## Need a Mag's name while a teammate asking you is in reach (a translation key).
@export var wheel_mag_toss: String = "ORDER_MAG_TOSS"
## Spotted's name in the middle (a translation key).
@export var wheel_spot_label: String = "ORDER_SPOT"
## The wheel's shape, in px of the HUD's 1920 x 1080 layout from the middle (OrderWheelLayout): wheel_rows buttons a
## column, each wheel_button big, wheel_row_pitch apart (top to top); a column's inner edge wheel_column_gap from the
## middle, its middle rows set wheel_column_bow further out than its end rows, so the columns bow round the circle;
## Spotted's circle wheel_centre px out from the middle (its radius; owner 2026-11-15: slightly smaller).
@export var wheel_rows: int = 4
@export var wheel_button: Vector2 = Vector2(236.0, 48.0)
@export var wheel_row_pitch: float = 58.0
@export var wheel_column_gap: float = 100.0
@export var wheel_column_bow: float = 0.0
@export var wheel_centre: float = 66.0
## While the wheel is open the mouse moves its own pointer over the drawing, not the view: this many px a mouse count,
## times the sensitivity, kept on the wheel's buttons, so a big flick still lands on one and coming back is short. In
## Spotted's circle it is on Spotted; outside it, it is on the button of its row on its side, except straight above
## or below the circle (within wheel_strip px of the middle line), where it is on nothing.
@export var wheel_gain: float = 1.0
@export var wheel_strip: float = 20.0
## A tap: the wheel's key let go within wheel_tap (s) of pressing it, which spots whatever the pointer is on; the wheel
## is drawn only once the key is held this long or the pointer leaves the circle, so a tap never flashes it up.
@export var wheel_tap: float = 0.2
## While the full-screen map is open (FM1) the mouse moves the map's pointer: this many px a mouse count, times the
## sensitivity.
@export var map_gain: float = 1.0
