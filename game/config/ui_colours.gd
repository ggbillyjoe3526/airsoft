class_name UiColours
extends RefCounted
## The interface colours a player can pick (Settings › Display › Interface colour; owner, 2026-11-15, UA2): the one
## accent GameTheme lights the main buttons, the picked and focused items and the comms wheel's lit button with, each
## with the dark ink its words are drawn in. sRGB, as every UI colour. All are soft, light shades, so dark words read on
## them and none is as strong as a team colour: blue paler than Alpha's, orange paler than Beta's.

## The colours offered, saved by number in the settings and shown in this order.
enum Pick { BLUE, BEIGE, RED, GREEN, PINK, ORANGE, VIOLET }

## Blue, the owner's pick of 2026-11-15 (UA1); beige is Sunlit Concrete's bone accent from before it (SL4).
const DEFAULT := Pick.BLUE
const ACCENTS: Array[Color] = [Color("8fb0f0"), Color("d8ccb2"), Color("ec7a74"), Color("86d39a"), Color("f4a6cb"),
		Color("f5b97f"), Color("b8a2f2")]
## The words on each accent: a charcoal tinted to its colour.
const INKS: Array[Color] = [Color("141a24"), Color("1b1a17"), Color("1f1212"), Color("101c14"), Color("24141c"),
		Color("231a10"), Color("1a1626")]
## Each colour's name (en.po), the swatches' tooltips.
const NAME_KEYS: Array[String] = ["SETTINGS_UI_COLOUR_BLUE", "SETTINGS_UI_COLOUR_BEIGE", "SETTINGS_UI_COLOUR_RED",
		"SETTINGS_UI_COLOUR_GREEN", "SETTINGS_UI_COLOUR_PINK", "SETTINGS_UI_COLOUR_ORANGE", "SETTINGS_UI_COLOUR_VIOLET"]
