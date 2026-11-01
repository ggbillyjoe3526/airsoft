class_name RailingConfig
extends Resource
## What a bar railing is made of (SR1; The Street's waist-high metal railings, MapStyle.railing_kinds): upright bars
## between a rail along the top and one near the foot, all in the railing block's box. Bars and rails stop a BB
## (Railings.first_bar); the gaps between them let it fly on, and let anyone see through. The same numbers draw the
## bars (MapLevel), so what you see is what stops a BB. Read by game/sim/railings.gd.

## Centre-to-centre spacing of the bars along a run (m): each run fits a whole number of gaps, as near this as its
## length allows, with a bar at each end.
@export var bar_pitch: float = 0.14
## Each bar's width and depth (m): square steel, thick enough to read as a bar at range (thinner ones shimmer).
@export var bar_width: float = 0.025
## The rails' height (m): the top rail is the block's top, the bottom one `foot_gap` above its base. Each runs the
## run's whole length and depth.
@export var rail_height: float = 0.04
@export var foot_gap: float = 0.1
