# BQ2 · Bot teammates ask for you with a ping

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-01 | 1 | Opus 5.5 (build thread) | ✓ | see the Review line | – |

## Goal

The owner's playtest (2026-11-01): "friendly bots should be able to ping locations if they want me to go somewhere or
need help. Make sure they aren't doing it too often. The AI should be smart and tactical and aim to win the
round/match."

## Approach

- **Three asks**, new events in `data/callouts.md` with lines, read by `CalloutsFile`: **Need help** (a bot on your
  team fighting, or in cover from, two or more enemies seen within 4 s; or defending the pole the other team starts
  raising the flag on), **Go round** (in a fight with one enemy it has had in sight 8 s: a stand-off, pinging a spot
  12 m to their side, yours first, on walkable floor) and **Cover me** (your team starts raising the flag: the pole).
- **Pace** (callouts.md › Asks, a new optional table): only bots on your team, only while you are in play and more
  than 15 m from the bot (or the pole), the team at most once every 30 s and three times a round; an ask is said as
  soon as the bot may speak (as a magazine ask), so it never waits in the queue to go stale.
- **The ping**: `Pings.ask` puts the speaker's spot ping in the book with `Pings.Ask` (HELP, GO, COVER); the HUD marker
  reads "HELP · 40 M", "GO · 25 M", "COVER · 30 M"; the minimap shows it as a spot. A Contact mark never covers an ask
  still up. As with marks, no bot takes an ask: the callouts still never change how anyone plays.

## Decisions

- None needing the owner.

## Defaults taken

- 30 s apart and three a round: about one ask a minute of a 3:00 round, so each one means something.
- 15 m: closer than that you can already see the fight.
- Asks are pings plus words, no new sound: the radio click of the callout says a teammate is talking.

## Checks

- `test_bq2_asks` (the shipped Asks table and lines; Need help for two, not one; nobody asks when you're close, out,
  or on the other team; the gap and the round's cap; Go round's spot beside the enemy on your side; Cover me and Need
  help on the flag; a mark is no ask; the markers' words), `test_callouts`, `test_callouts_file`, `test_pings`,
  `test_ping_markers`.
- QA: Pass (`test_bq2_qa`: no player, you on team 1, two bots in one fight ask once, stand-off guards, Go round's spot on
  the nav grid, a mark never covers an ask, a round start drops a queued ask). Advisory taken: 0 seen at once turns
  Need help off (0 used to ask about nobody).
- Performance: Pass (smoke match level with main: nodes, orphans, shots). Advisory taken: Go round's spot is looked
  for only once the ask may be said, with no array per call.

## Known issues left

- Go round's spot is walkable floor beside the enemy, but nothing checks you can reach it from where you are
  (another storey, the far side of a wall). Can wait: the owner's playtest says whether it matters.
