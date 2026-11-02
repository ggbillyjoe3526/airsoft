# UR4 · Customise with a fixed frame and a 3D replica to turn

**Review:** 2 attempts · critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-02 | 1 | Opus 5.5 (build thread) | stopped for the fixes | Retry 7/8 | test .uid not committed; R on keycode; body top hand-summed; ring clipped |
| 2026-11-02 | 2 | Opus 5.5 (build thread) | ✓ | Accept 7/8 | ring cut at 3/4 (fixed after: radius 0.62× half length) |

## Goal

The fourth of six pull requests for the owner's UI redesign (UR1 has the asks and the concepts). On Customise he asked
that the replica "stays the same size and place whatever parts go on" and for "an option to rotate the 3D model"
(concept B v2 `customise.png` and `rotate.png`).

## Approach

- **Turntable** (`ReplicaTurntable`, a TextureRect over its own SubViewport): the carried replica's model, live, with
  its parts fitted (`ReplicaParts`) and its paint (`ReplicaPaint`), as `ReplicaPictures` does it, under the same light.
  The frame comes from the bare model only (its box's centre on the turntable's, the camera's distance from its length
  and height with room for parts), so fitting a part, a paint or a tab never moves or rescales it. A faint ring under
  it reads as the turntable, inside the frame at 3/4 and hidden looking down from above (it would run out of it).
- **Turning**: drag with either mouse button turns (across) and tilts (up and down, from looking straight down to a
  little below), the wheel zooms 0.7× to 1.8×, R puts back the 3/4 view, and the 3/4, Left, Right and Top buttons
  (`MenuChoice`, compact) pick a view; a drag unlights them. The viewport draws once per change, never every frame,
  and only when the replica, its parts or its paint changed (a slider or a tab draws nothing). When Customise
  closes (`LoadoutPage.show_gear`) it lets go of the model and its render target. Letting go of one drag button while
  the other is held keeps turning.
- **Page**: the replica's name is the page's title (`MenuParts.page_title`) with the way back before it and the slot
  and loadout beside it; the turntable sits in a glass panel of one height on every tab, the views at its top left and
  the hints (Drag to rotate, Scroll to zoom, R Reset view) at its top right. `ReplicaPictures.bounds` and `signature`
  are now static, shared with the turntable. The gear page keeps the flat pictures.

## Decisions

- **The parts stay down the left.** The concept puts them in a row of cards under the turntable; the tabs' controls
  (the colour tiles, the BB sliders and flight, the part cards) need the room under it, and ten tabs don't fit a row
  at 1280 wide. The list keeps every control where it was.
- **Perspective, not the flat pictures' view.** A turntable that turns reads as 3D only with perspective; a narrow
  lens (26°) keeps the replica's shape true.
- **The view is kept between replicas.** Opening the pistol after turning the rifle keeps the angle, so the two
  compare; R or 3/4 puts it back.
- **R is the turntable's only while Customise shows.** On the other pages R does nothing in the menus.

## Known issues left

- None known.

## Checks

- Customise, turntable, UR3/UR4 QA, Loadout and menu suites 224/224 and gdlint on the branch; the full suite in CI.
- QA (`test_ur4_qa.gd`): every replica with every part fits the frame in every view, every tab fits 1080, nothing
  grows over 15 opens. Performance: Pass, with three advisories (no-op redraws, the render target, MSAA on Low); the
  first two fixed, MSAA left at the pictures' fixed 4× like `ReplicaPictures`.
