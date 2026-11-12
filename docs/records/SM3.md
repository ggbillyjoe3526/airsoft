# SM3 · Subway's ticket hall and concourse models

**Review:** critic Accept 8/8 (attempt 7) · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | build thread | pass | 7/8 | the gates against the owner's size note; bench, machine, office, counter, barrier detail |
| 2026-11-12 | 2 | build thread | pass | 7/8 | the paddles' shape and colour against the photos; the counter's hue |
| 2026-11-12 | 3 | build thread | pass | 7/8 | the gate's round column and the paddle's neck; the paddles unlit in play |
| 2026-11-12 | 4 | build thread | pass | 7/8 | a brighter steel column, lighter paddles a little lower, a bigger yellow reader, the arm in its slot |
| 2026-11-12 | 5 | build thread | pass | 7/8 | the gate's proportions against photo 4: a slim post under the reader head, the blade's foot higher, the reader yellower, the arm's root rounded |
| 2026-11-12 | 6 | build thread | pass | 7/8 | the reader's yellow too pale; the head a lid, not a steep wedge facing the walker |
| 2026-11-12 | 7 | build thread | pass | 8/8 Accept | – |

## What was built

Models #19 to #26 of the owner's Subway list (art/subway-model-list.md), from his photos
(art/references/maps/subway/19-ticket-gates/ to 26-crowd-barrier/), each by its own script in tools/blender/maps/
on the shared `hallkit.py` (the station's paints, face decals, shutters, louvres, tubes):

| Model | Triangles / budget | Blocks |
|---|---|---|
| ticket_gate, gate_paddle | 1,929 / 2,000, 392 / 400 | the ticket hall's gate line: 14 slim pedestals, a 1 m lane between each two, a paddle each side of every lane |
| ticket_machine | 9,164 / 10,000 | the row of four in the ticket hall |
| kiosk, kiosk_long | 3,778 / 4,000, 3,890 / 4,000 | the ticket hall's kiosk, the concourse's |
| ticket_office | 2,906 / 3,000 | the ticket hall's office |
| booking_counter | 1,458 / 1,500 | the booking hall's counter |
| help_point | 1,082 / 1,200 | the concourse's two help points |
| station_bench, station_bench_long | 858 / 1,000, 868 / 1,000 | the platforms' six, the lower hall's, the concourse's |
| crowd_barrier | 596 / 600 | the concourse's two and the stair top's two |

The paddles are `GatePaddles` (game/play/station/, `GatePaddlesConfig` on PlayTuning): every two gate blocks a lane
apart with nothing standing between them get a paddle each, shut across the lane, swinging a quarter turn open towards
the platforms while anyone stands within 1.6 m of the lane's middle. One MultiMesh, relit from the bake, look only.

Subway's crate and locker boxes in the passages, the booking hall, the stair top and the platforms name Depot's
`crate` and `steel_locker` (DM1, RK1). The cable-drum crates are left for SM4.

## Decisions

- **A block names the way its model faces** (`facing`: +x, -x, +z or -z; `layout.block(..., facing=)`, written by
  build_map.py, read into `MapData.Block.facing`): FIT turns the model's front that way, its x across it
  (`PropLayout.facing_yaw`, `facing_size`). FIT's own rule faces the field's middle, which put the north platform's
  benches' seats to the wall. A bad facing is warned and FIT's rule kept (look only, so the map still loads). Shared
  with SM4.
- **Gate lanes are one person wide, with a paddle door each side** (owner, 2026-11-12: "less distance between them
  ... only wide enough for one person ... paddle doors on each side"): 14 pedestals 0.49 m wide and 1.4 m along the
  lane (his note: 1 to 1.5 m long), 1 m lanes. 1 m is the narrowest that keeps a nav cell walkable in every lane
  (0.9 m left some lanes without one); the wide wall-side gate is dropped.
- **The paddles swing open as anyone walks up and are look only** (the default on his decision card): no collider, no
  nav change, BBs pass a lane as before, so the lane plays as the open gap it was. They reach out of the gate's box
  into the lane, which is the point of a paddle.
- **The paddle is a tall rounded blade on a short arm** (photos 3 and 4), one outline so the arm is the blade's neck,
  mid grey and a little glossy (roughness 0.45) so the dim hall's lamps show its shape: from 0.53 to 1.08 m (photo 4's
  foot about half its top), the arm, its root rounded, swinging from inside the side's slot housing (`post_off`
  -0.03, the hinge hidden). Look only, so it may stand over the gate's box. The street end is a slim round steel post
  (0.15 m) to 0.8 m with the reader head seated on it, as photo 4. The screen post stays inside the box (1 m), a
  little short of the paddles' top where the photos' posts meet it: the box is cover, and the model is fitted to it.
- **The reader is the palette's yellow, a shade deep** (yellow*0.72, the ring *0.5) on a 45 degree wedge facing the
  walker: the look draws every painted prop at `paint_saturation` 0.6 (art direction v5), which caps the palette
  yellow at about 0.35 saturation before light; in game it measures 0.28, as the station's yellow tactile strips do
  (0.29). Not lit: a glowing reader would need an emission path the props' shader doesn't have.
- **The machines' pilasters are dark grey**: the photo's coloured ones fail the team-hue test.
- **The help point is a four-sided column** (network map, street map, help panel, timetable): its block is square.
- **Signs are wordless** blocks of light and dark (no words, logos or liveries).
- **The booking counter's wood is a dull dark walnut** (palette `walnut` 0x70625b, linear saturation about 0.2): a
  red-brown sits within 20 degrees of Beta's orange, and a plum one (tried: `mahogany`) read as aubergine. Dark shades
  are stored as 8-bit linear vertex colours, which drift a dark colour's hue some degrees, so the wood stays dull and
  its skirt is neutral `slab`. The machines' dim screens are `ink*0.6` for the same reason.
- **The crowd barrier carries a cover sheet**: its box stops BBs, and bare bars would read as see-through.

## Known issues left

- None.
