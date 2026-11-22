class_name FakeScreens
extends SettingsApply.Screens
## A stand-in for the window's DisplayServer calls (SettingsApply.use_screens), since the headless display server has no
## screens and never changes mode: screens of the given sizes and rates, the window's mode, V-Sync and screen, and each
## call that changes them, in order, in `calls`.

var window_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_MAXIMIZED
var vsync_mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED
var sizes: Array[Vector2i] = [Vector2i(2560, 1440)]
var rates: Array[float] = [144.0]
var primary_screen: int = 0
## The screen the window is on.
var on: int = 0
## The screen a window leaving fullscreen lands on (the system's remembered place), or -1 for where it was.
var leave_to: int = -1
var calls: PackedStringArray = PackedStringArray()


func mode() -> DisplayServer.WindowMode:
	return window_mode


func set_mode(m: DisplayServer.WindowMode) -> void:
	var was_fullscreen := window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	window_mode = m
	calls.append("mode %d" % m)
	if was_fullscreen and leave_to >= 0:
		on = leave_to


func vsync() -> DisplayServer.VSyncMode:
	return vsync_mode


func set_vsync(m: DisplayServer.VSyncMode) -> void:
	vsync_mode = m
	calls.append("vsync %d" % m)


func set_min_size(size: Vector2i) -> void:
	calls.append("min %d x %d" % [size.x, size.y])


func count() -> int:
	return sizes.size()


func primary() -> int:
	return primary_screen


func current() -> int:
	return on


func set_current(screen: int) -> void:
	on = screen
	calls.append("screen %d" % screen)


func size(screen: int) -> Vector2i:
	return sizes[screen]


func rate(screen: int) -> float:
	return rates[screen]
