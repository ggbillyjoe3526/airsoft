extends GutTest
## UA1: the interface's highlight is blue (not the old cream), readable under its ink, and never mistaken for a team.

const BLUE_HUE := Vector2(0.55, 0.70)
const MIN_CONTRAST := 7.0
## The least RGB distance (0..1.73) the accent keeps from a team's HUD colour.
const MIN_TEAM_DISTANCE := 0.2


func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.03928 else pow((c + 0.055) / 1.055, 2.4)


func _luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_accent_is_blue() -> void:
	assert_between(GameTheme.accent.h, BLUE_HUE.x, BLUE_HUE.y, "the accent's hue is in the blue range")
	assert_gt(GameTheme.accent.b, GameTheme.accent.r, "more blue than red")
	assert_gt(GameTheme.accent.b, GameTheme.accent.g, "more blue than green")


func test_ink_on_accent_is_readable() -> void:
	assert_gte(_contrast(GameTheme.accent_ink, GameTheme.accent), MIN_CONTRAST, "ink on the accent meets WCAG AAA")


func test_accent_stays_apart_from_the_standard_team_colours() -> void:
	var hud := TeamColours.resolve(TeamColours.Set.STANDARD, false).hud
	for team in hud.colours.size():
		assert_gte(_distance(GameTheme.accent, hud.colours[team]), MIN_TEAM_DISTANCE, "accent vs team %d" % team)


func test_order_wheel_lit_edge_is_bluish_not_yellow() -> void:
	var edge := HudOrderWheel.lit_edge()
	assert_gt(edge.b, edge.r, "the lit edge leans blue")
	assert_gt(edge.b, edge.g, "the lit edge is not yellow")
