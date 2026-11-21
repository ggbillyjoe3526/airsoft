# TQ1 · Subway's trains in finer detail: what they are made of, padded seats, draft screens and adverts (Beta)

**Review:** critic pending (attempt 3) · qa pending (final head) · performance pending (final head)

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-21 | 1 | build thread | QA Pass, performance Pass | Retry 6/8 | fidelity to the photos (cab front a black void, moquette and floor tones, poles grey where the photos' are orange, far windows black), the body 4 mm past its bounds, a stale budget comment, the pictures' harness a copy |
| 2026-11-21 | 2 | build thread | touched tests 79/79; QA and performance not re-run | Retry 6/8 | fidelity (draft screens invisible, far windows flat grey slabs, ceiling's dash slots, seat-end bases read as cabinets), PLAYTEST's pole line and the record's review claims, QA and performance on an older head |
| 2026-11-21 | 3 | build thread | pending | pending | – |

## Goal

The owner's ask (2026-11-21): "Improve the quality of the subway map models, especially the wagons. Show me
screenshots", then "I want all models improved". This task is the wagons (the cars, their seats and the tool cart);
the station's props follow in SQ1. Follow his photos (`references/maps/subway/01` to `05`) closely, use the budgets,
keep every model's bounds, collision and the layout, and keep Subway's orange stripe (#c0652f) and no team hues.

## Approach

- **What each face is made of** (`game/play/look/look_surface.gdshaderinc`, new): a face's UV y is 100 plus its
  kind, written by `tools/blender/maps/train.py` (`KINDS`), and `look_vertex.gdshader` reads it: gloss paint (the
  sides), satin steel (poles, trims), the seats' woven moquette (grey and a few orange rings, as his photos), the
  floor's speckled rubber, dark glass, rubber and brushed aluminium. The moquette is grey with dark, mid and light
  rings and about one in eight in the stripe's orange (#c0652f, the one colour the team-hue test lets near a team); its
  fade reads a pixel's finer way, so a seat's top seen at a glance keeps its pattern. The patterns lie in the model's own space and
  fade to their average where they'd be finer than a pixel, skipping their work there (the performance advisory).
  Patterned faces take a share of the world's wear (swept seats and floors don't gather the dust that drew them
  beige). A model with no kinds is drawn as before.
- **Geometry** (`train.py`): seats rebuilt with a bullnose front, rounded ends and steel kick plates (620 and 420
  triangles); glass draft screens by the doors (`train_screens.glb`, drawn on the windows' clear material by
  TrainView through TrainLook.screens), each with its steel frame, alarm and door button; adverts along the coves,
  a ceiling strip with lamp housings, next-stop screens, wall seams, tread ribs, grilles and warning triangles on the
  sides. The body's 940 painted flecks a car went (the floor's speckle replaces them). Body 17,136 of 18,000.
- **After the critic (attempt 2):** the poles and grab rails in the stripe's orange, gloss, as the photos (the
  stripe's exemption covers them); a charcoal floor with faint flecks; the far side's windows a lighter glass; the
  cab front's lamp strips shortened to about 0.6 of its height and the saloon seen through its glass (its pale
  ceiling and two lamp lines) drawn on the glass, not through it: the cab end is solid in the field, so a see-through
  front would show players what neither they nor a bot can shoot. The side grille moved down the bilge so the body
  stays inside its 1.72 m (it stood 4 mm out).
- **After the critic (attempt 3):** the ceiling one smooth panel with two continuous lamp lines along the coves' top
  edges (the vent slots and diffusers went; the speakers moved inboard); the far side's windows drawn in strips on
  the wall's lean, darker low, the car's lamps caught in them as two slanting pale bands; the draft screens a little
  more opaque than the windows (TrainLook.screen_opacity 0.45) with a black edge seal and a pale frosted band; their
  white bases slim (30 mm) on a chamfered foot, the alarm and door buttons small rings, not a dark panel. The
  pattern's fade reads a pixel's mean size again (the finer way kept the work on at a glance and could sparkle).
  The cove stays a straight slope: its adverts, the door heads, the end walls and the gangways are all cut to it.
- **Pictures:** a scratch copy of hall_pictures.gd's harness with the trains' and station's shots, kept out of the
  repository (eye_pictures.gd renders named spots the same way).

## Verified

- Tests: `tests/unit/test_tq1_trains_qa.gd` (QA, 7 tests), the train and props tests (team hues, lining) pass on the
  final head; QA's smoke test ran on attempt 1's head (re-run with the final review).
- Bounds: every rebuilt model inside its old box (the body ±1.720 m across, as before).
- Pictures, before and after (lavapipe, in game): `art/blender/subway-trains/tq1/` in the project files.
- Performance: about +19k triangles map-wide (seats), screens 6 x 112; MultiMesh, no new draw path.

## Left for the owner

- The look on his card, and Low's frame time inside a car (seat shadows are the cost to watch): N48 in the owner's
  checklist (project files, `playtest/0.1-beta2-checklist.md`) and docs/PLAYTEST.md's "Subway's trains up close".
