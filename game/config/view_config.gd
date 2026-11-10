class_name ViewConfig
extends Resource
## The first-person camera (the browser game's config/renderView.ts RENDER). Read by FirstPersonView.

## Horizontal field of view on a 16:9 screen (degrees; owner, 2026-10-04: 90). Wider screens see more to the sides with
## the same vertical view ("Hor+"), so ultrawide doesn't fisheye.
@export var horizontal_fov_16x9: float = 90.0
## How far the view zooms with the sight fully raised (1: none).
@export var aim_zoom: float = 1.2
## Clip planes (m).
@export var near: float = 0.05
@export var far: float = 250.0
## The view rolls this far at a full lean (rad): a share of the body's tilt, enough to feel the peek without the world
## swinging.
@export var lean_camera_roll: float = 0.12
## A lean a wall cuts short (Lean stops it in one tick) eases out of the view at a full lean's worth in
## lean_cut_ease_time seconds, but the eye is never drawn more than lean_cut_allowance metres further out than the
## simulation's (inside the wall clearance less the near plane's reach), so the view never reaches into the wall. A
## normal release is slower than this and is drawn as it is (the browser game's leanCut).
@export var lean_cut_ease_time: float = 0.1
@export var lean_cut_allowance: float = 0.1
## Over a vault the view dips (m) and tips forward (rad), most at the vault's middle, as hands plant and the body swings
## over; followed at vault_follow (1/s) on rendered frames, so it settles smoothly whatever the frame rate.
@export var vault_dip: float = 0.12
@export var vault_tip: float = 0.14
@export var vault_follow: float = 18.0
## Up onto a ledge (CL1) the view dips (m) and tips forward (rad) the same way, most early on (climb_peak of the way
## through the climb, as the hands go onto the edge and the body heaves up), and comes back level as you stand on it.
@export var climb_dip: float = 0.10
@export var climb_tip: float = 0.24
@export var climb_peak: float = 0.3


## The vertical field of view (degrees) the horizontal 16:9 one gives, zoomed by `zoom`.
func vertical_fov(zoom: float = 1.0) -> float:
	var half_h := deg_to_rad(horizontal_fov_16x9) * 0.5
	return rad_to_deg(2.0 * atan(tan(half_h) * 9.0 / 16.0 / maxf(zoom, 0.01)))
