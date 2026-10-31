# game/input

`PlayerInput`: the player's controller. The mouse turns the view as events arrive; once a tick `fill` writes the
held keys and every press since the last tick into the player's `PlayerCommand`, so a tap shorter than a tick is never
lost. It reads nothing while the mouse is free, so a menu click never fires. Default bindings are project.godot's input
map, by physical key (WASD on any layout): move WASD or arrows, walk Shift, sprint Alt, crouch C or Ctrl, jump Space
(at a low obstacle it vaults), lean Q and E, fire and aim the mouse buttons, reload R, fire mode B, replicas 1, 2 and the
mouse wheel, scoreboard Tab, squad orders Follow me F, Hold here X, Regroup V and the order wheel Z (held), Need a
Mag H, ping the middle mouse button, throw a smoke bomb G and a flash bomb Y (SF1: each press fills the next tick's
`throw_grenade` once), pause Esc,
the reserved debug keys F3 (overlay), F4 (BB paths) and F5 (hit areas). Rebinding is in Settings (below). Crouch is held (`ControlsConfig.crouch_toggle` on makes it a toggle, which a sprint or jump
press stands up from); aim is held (`ControlsConfig.aim_toggle` on makes it a toggle); lean is always held. Tuning: `ControlsConfig`
(`aim_sensitivity` multiplies the turn while the sight is up). The settings screen writes its values into it, and
rebinds through the InputMap, which `PlayerInput` reads live (a key held across a rebind is let go).

Squad orders (M22, M23): an order key fills the next tick's `PlayerCommand.squad_order` once (given again, the bots'
side cancels it). Holding the order wheel's key moves the wheel's own pointer instead of the view (`ControlsConfig`
`wheel_gain` times the sensitivity, within `wheel_reach`, nothing within `wheel_dead_zone`; slices clockwise from the
top); feet still move, the mouse wheel switches nothing, and fire and aim need a fresh press once it closes. Hover (the
default) gives the order pointed at on letting go, Click only on a click (a click gives it either way); the wheel's
orders, keys and names are `ControlsConfig` data, Hover or Click a saved setting. It closes giving nothing on pause or
focus loss (`release`), once you are out, and on the range (`allow_orders`). The wheel on screen is the HUD's (`HudOrderWheel`).

Ping (PN1, the middle mouse button, "Squad: ping a spot"): a press fills the next tick's `PlayerCommand.ping` once,
dead on the range as the order keys are (`allow_orders`); the simulation drops one while you are out or between rounds.
Go there (FM1, mouse button 4, "Squad: go there", and the order wheel's Go There) is a ping with `ping_move` set.

The full-screen map (FM1, M held, "Map (hold)"): like the wheel, the mouse moves its own pointer (`MapPointer`,
`ControlsConfig.map_gain` times the sensitivity, kept on the map's square, which the HUD frames each frame) instead of
the view, feet still move, the mouse wheel switches nothing and fire and aim need a fresh press after. A click (fire)
there is a Go there to that point of the field, the ping's press a ping there (`ping_on_map`, `ping_target`), while
orders can be given; the map and the wheel never open together, and there is no map where `allow_map` is off (the
range).

| File | What it holds |
|---|---|
| `player_input.gd` | `PlayerInput`, above |
| `key_bindings.gd` | `KeyBindings`: two keys per action by physical key or mouse button; a key belongs to one action, a taken key swaps, Fire and the moves are never stranded, Esc, PrintScreen, Pause, F11 and the debug keys F3, F4 and F5 can't be bound (the browser game's keyBindings.ts); writes the InputMap |
| `map_pointer.gd` | `MapPointer`: the full-screen map's pointer, kept on its square, and the point of the field under it |
| `order_wheel_pointer.gd` | `OrderWheelPointer`: the order wheel's pointer, within reach of the middle, and which slice it is on (the browser game's orderWheel.ts) |
| `key_names.gd` | `KeyNames`: a binding's name in the player's keyboard layout, mouse buttons named too |
| `sensitivity.gd` | `Sensitivity`: cm/360 at a DPI and back (the browser game's sensitivity.ts) |

Tests: `tests/unit/test_player_input.gd`, `test_order_wheel_input.gd`, `test_fm1_field_map.gd`, `test_key_bindings.gd`, `test_sensitivity.gd`.
