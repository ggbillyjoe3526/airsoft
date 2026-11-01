# ST1 · The Street

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-01 | 1 | thread | see Checks | Retry 6/8 | two areas named alike (Corner green, Green corner); docs the change touches not updated |
| 2026-11-01 | 2 | thread | see Checks | Accept 8/8 | – |

## Goal

The owner's concept 3 of a terraced street, approved 2026-11-01 ("Perfect, can you add to the game with CC0 assets
and give me screenshots as soon as possible (with new art direction applied) and I will playtest as soon as it's in
the game."). Two pull requests: this one is the map in plain blocks in the shared look; ST2 dresses it with CC0
models. The real street the plan came from is never named or pictured in the repository.

## Approach

- **Layout as data.** `tools/street/layout.py` is concept 3's layout (zones, buildings, pieces, the House's doors,
  arches, spawns, flags); `tools/street/build_map.py` writes `data/maps/street.json`: the ground rasterised from the
  zones into floor blocks (each with its surface), terraces with pitched roofs (two ramps each, 1:2 at most for
  field.ramps), the House's walls under the floor above with sills and lintels round its windows, the arches' lids,
  the props as boxes, and `settle` cutting back any two blocks that overlap. Areas are the zones, smallest first,
  then every other square named after its nearest zone.
- **Colour.** Every block carries its own palette colour (`MapData.Block.colour`, the file's `colour`, 0xRRGGBB);
  `MapStyle.block_colour` takes it first. Five palette colours added (brick, seafoam, lilac, butter, sage), all off
  the team hues (`test_look`).
- **Glass.** `MapStyle.clear_kinds` names the kinds drawn see-through (glass at 0.35): `MapLevel` leaves them out of
  the greybox and draws them as a "Glass" mesh in `LookMaterials.clear_colour`, warmed with the other shaders. They
  stay colliders: glass stops BBs, bodies and bots' sight; only the open half of the House's front window is open.
- **Field rules.** `FieldChecks.drawn_colours` counts each block's own colour; `FieldMeasure.middle` falls back to
  ground end 0 reaches when the centre is in a closed garden; `FieldStandard` gains a `flag_head_start` exception.
- **Guards.** `tests/guards/test_street_guards.gd` in its own CI job (three parts: day at Normal in both modes, night
  at Easy and Hard).
- Wiki: Maps (The Street, its areas, the House's doors). DECISIONS, ROADMAP, KNOWN_ISSUES, ASSETS, game/map/README.

## Decisions

- **The owner's ruling (decision card, 2026-11-01):** keep concept 3 as approved, with The Street's exceptions written
  down: the longest standing line 82 m (cross-lane diagonals over railings, low walls and cars; each lane's own lines
  are the concept's) and flag A's head start 1.3 (flag B's is 1.8; the standard is 1.6).

## Defaults taken

- Day by default, night by the Time of day row; 17 street lamps each light a lantern pool (radius 8 m).
- Doors are 0.9 m so each leaf folds flat against wall clear of the corners: the back door opens into the living room,
  the hall door back into it, the front door out over the front garden.
- The bots' lanes stop at the defenders' posts by the flags (the Pend's mouth, the path by the House, the Arch),
  not at their spawn: holding the first points from their own end, defenders had stood 50 m behind the flags and
  lost every Attack / Defend round to a capture (144 of 144); now about half (64 of 126 over 16 seeds).
- Bots see 55 m, as on Depot. The Bottom street has two vans on its north kerb so no line runs its 94 m length.
- Pastel renders for the terraces, slate (the palette's ceiling) for every roof, raspberry brick (off the high
  contrast orange's hue) for bin stores and a terrace colour.

## Checks

- gdlint clean on every touched script; `python3 tools/wiki.py check` OK; `build_map.py` reproduces `street.json`.
- Field rules: every rule passes but the middle, which warns (attackers walk 101.5 m to it, defenders 81.3 m).
- `test_street` (5), `test_st1_qa` (9), `test_field_layout`, `test_field_rules`, `test_map_areas`, `test_look`,
  `test_baked_light` and the rest QA listed pass; `test_dev_settings` updated for the third public field.
- Street guards: Elimination at Normal 118 rounds over 16 seeds, none on time; Attack / Defend at Normal 126 rounds,
  64 captures (51 %), none on time; at night, Elimination at Easy 64 rounds and Attack / Defend at Hard 61 rounds
  (32 captures). No failures.

## Known issues left

- Bots don't see through glass (one ray for BBs and sight): a follow-up (KNOWN_ISSUES).
- Props are boxes until ST2 (KNOWN_ISSUES).

## Owner should test

- The House's glass: a BB stopping on the pane, and bots not seeing through it.
- 1 m railings that can't be vaulted beside 0.9 m low walls that can.
- Attack / Defend: Alpha getting to flag A in time.
- The long cross-lane diagonals; the pastel terraces against the team colours by day and under the lamps at night.
