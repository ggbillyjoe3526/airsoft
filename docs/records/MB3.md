# MB3 · Woodland's flag takes 9 s to raise

**Review:** 1 attempt · critic Accept 7/8 · qa Pass · performance Pass

MB2 cleared Woodland's Long road at the owner's word and left Attack / Defend outside its band: the attackers took
69 % ±3 of rounds against bots (band 40 to 65 %). The owner was shown it on a decision card, "Make the flag take
longer to raise on Woodland, to help its defenders?", and picked "9 s on Woodland (7 s now)" (2026-11-13) over 8 s,
leaving it at 7 s, and moving both flags. This record is that pick, and what was measured before it was offered.

## Acceptance criteria

1. A flag on Woodland takes 9 s to raise in Attack / Defend, in Skirmish and in Custom. Every other field keeps the
   game's 7 s, and the 3 s hold is the same everywhere.
2. The raise is a field's own data (`data/maps.md`), read like its round length: no number in code, a bad cell keeps
   the game's and warns, a table without the column reads as before.
3. Bots, 6v6, Normal, Woodland's Attack / Defend: the attackers inside 40 to 65 %, on the 32 seeds MB2 measured.
4. Nothing else moves: Elimination and Plant The Bomb on Woodland, and every mode on the other fields, play as
   before (the same seeded rounds).
5. The wiki's Maps table shows each field's raise, from the data.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-13 | 1 | build thread | ✓ | 7/8 Accept | – |

## What changed

- `data/maps.md`: a `Raise (s)` column after `Round`. Woodland's is 9; every other cell is blank.
- `game/map/map_catalog.gd`: `Entry.raise_time` (0 for the flag tuning's), read from that column, 3 to 20 s.
- `game/ui/match_options.gd`: `match_tuning` plays a field's raise as it plays its round length. It copies the flag
  tuning only when the field's differs and never writes the loaded one. `raise_time(map, played)` is the one place
  that picks it.
- `tests/support/match_runner.gd`: `sized_for` plays it too, so the guards and the measures play what a Skirmish
  plays. The round tally's flag height now follows every pole's flag and names the pole (`top_pole`; it read flag A
  alone, so "how often a flag went up" on a field with two poles was flag A's figure). `tools/map_heat.gd` writes
  the pole.
- `tools/wiki.py`: a "Flag raise" column in the Maps table. `docs/wiki/Modes.md` points to it.
- `tests/unit/test_mb3_raise.gd`: the catalog reads the column; a cell out of range or not a number keeps the
  game's with a problem; Woodland plays 9 s under Skirmish and Custom and the others the game's; a flag stepped on
  Woodland's tuning is not up after 7 s and is up after 9 s; the tally follows both poles.

No new model, no new sound, no layout change.

## Measured

Seeded 6v6 bot matches at Normal on Woodland (`tools/map_heat.gd`), Attack / Defend, the attackers' share of
rounds. "Final layout" is `main` after MB2, with the one hazel moved.

| What | Seeds | Rounds | Attackers |
|---|---|---|---|
| MB1's road (pieces across it), 7 s | 1 to 64 | 477 | 63.3 % ±2.2 |
| MB2's clear road, 7 s (before the hazel moved) | 1 to 64 | 507 | 68.4 % ±2.1 |
| The same, three bots sent to pull a flag down (`BotConfig.retakers` 3 for 2) | 1 to 16 | 122 | 59.8 % ±4.4 |
| The same, four sent | 1 to 16 | 118 | 62.7 % ±4.5 |
| The same, two sent (as the game is) | 1 to 16 | 126 | 65.9 % ±4.2 |
| MB2's clear road, 9 s (before the hazel moved) | 1 to 32 | 232 | 58.6 % ±3.2 |
| **Final layout, 7 s** | 1 to 32 | 245 | **67.8 % ±3.0** |
| **Final layout, 9 s (built)** | 1 to 32 | 231 | **60.2 % ±3.2** |

- **Two seconds are worth 8 points ±4** on the final layout, and 10 ±4 before the hazel moved. Both land inside the
  band with room either side.
- **How the rounds end.** At 7 s the attackers win 163 of 245 rounds by a flag and 3 by putting the defenders out;
  at 9 s, 130 of 231 by a flag and 9 by a wipe-out. No round ran out the clock at either. A round's median is 50 s
  at 7 s and 51 s at 9 s.
- **Flag B is not the softer site.** MB2's record took it for one. Over 64 seeds at 7 s (before the hazel moved),
  sorted by the pole the attackers stood nearer in a round's last 15 s, they won 180 of 250 rounds at flag A
  (72 % ±3) and 167 of 257 at flag B (65 % ±3); on MB1's road 154 of 231 (67 %) and 148 of 246 (60 %). The count
  leans to the winners (attackers who win end at a pole), at both poles alike.
- **Why the raise.** The attackers all go for one pole, drawn each round. Two defenders are posted at each pole and
  two in the Back yard between them, 77 m of field apart, and only two bots go to pull a flag down. At 7 s the flag
  was up before the far defenders arrived. Sending more to pull it down moved the figure by less than its noise,
  and it takes defenders off the other pole.

- **Hard** (`tools/balance.sh woodland`, 6v6, 16 seeds, Attack / Defend; band 40 to 60 %): the attackers take
  63.6 % ±4.4 at 7 s (75 of 118 rounds) and 59.6 % ±4.6 at 9 s (68 of 114). No round runs out the clock at either
  (the known issues had 15.6 % from before MB1's layout; that row is brought up to date). A round's median is 68 s.
- **Elimination on the final layout reads 41 % ±3 to the west end** (95 of 231 rounds, 32 seeds; band 45 to 55 %),
  against 47.5 % ±3 on the same seeds before MB2's hazel moved. It is not the raise: seeds 1 and 2 play the same 15
  rounds with Woodland's Raise cell at 9 and blank. The hazel MB2 moved 2.3 m off the north lane was the west's
  screen at the Ridge's brow, across the gap in the row behind it: the east's knock-outs on targets within 15 m of
  it went from 127 to 146 a hundred rounds over seeds 1 to 24 (the west's 30 to 32). Over seeds 1 to 56 the west
  end takes 42 % ±2 (177 of 418). 6 points ±4.5 is not proof and the hazel is the likely cause, not a shown one. A
  known issue from MB2, and the next task (MB4): a solid screen in the old place, which no bot can stand inside.

## Decisions

- **A column in the maps table, not a number for Woodland in code.** The round length is already a field's own
  (`Round`), read and bounded the same way. 3 to 20 s: under 3 s a raise is no fight, over 20 s no round has time.
- **Skirmish and Custom both play it, and no menu sets it.** Custom's rules are about the match (rounds, time, team
  sizes); the raise is the field's, like its start mode.
- **The hold stays 3 s everywhere.** The owner's card asked about the raise alone.
- **The tally fix is here** because this task's question was "which flag falls", and MB2's known issue named this
  task for it. It is test support and a dev tool: nothing in the game reads it.
- **MB2's Maps row in the known issues is rewritten, not deleted:** the other team sizes are still not re-measured.

## Verified

- `tests/unit/test_mb3_raise.gd` (6 tests) and QA's `tests/unit/test_mb3_qa.gd` (6) pass, with `test_mb2_qa`
  (a seeded match in each mode on Woodland, no bot held up, now at 9 s), `test_match_page`, `test_flag`,
  `test_team_sizes`, `test_match_runner`, `test_wr2_qa` and `test_woodland_layout`. gdlint and the wiki check pass.
- Criterion 3: the table above. Criterion 4: Elimination's seeds 1 and 2 on Woodland play the same 15 rounds with
  the Raise cell at 9 and blank; nothing but `Flag.step` reads the raise (QA read every call site).
- QA: Pass. Every match start goes through `MatchOptions.match_tuning` (`PlaySession._load_map`, the Match page);
  practice and the Range take a tuning with no flag; the loaded tuning's flag is the same object and value after
  Woodland then Depot.
- Performance: Pass, from the code paths (the machine was shared with the measures, so no bench): nothing on a
  per-frame path in `game/` changes; `match_tuning` runs once a match load and copies at most three small
  resources that go with the match.
- Critic: 7/8 Accept. It recounted the 9 s figure (139 of 231) and compared the same-rounds check itself. Its
  failed check was the docs: the same measure stated two ways (figures from before and after MB2's hazel moved, not
  labelled), a stale 15.6 % in the Hard row, and "both poles fell alike" claiming more than the count shows. All
  fixed in this push.
- **Not verified, for the owner's play:** how 9 s on the rope feels, and whether a defender at the other flag now
  gets across in time. The play check is on the Dev 3 checklist.

## Known issues

- Deleted: the Maps row on the match tally following flag A alone (fixed here). MB1's record and its DECISIONS
  entry still quote flag A's figure as "a flag goes up"; they are history and stay as written.
- Brought up to date: the Maps rows on Woodland's Attack / Defend (in band at 9 s; the other team sizes still not
  re-measured) and on Hard's clock.
- New: Woodland's Elimination leans east since MB2 moved the hazel (Maps, fix now). Next as MB4.
- Left: no menu or card tells a player a field's raise before the match; the wiki's Maps table does. Can wait.
