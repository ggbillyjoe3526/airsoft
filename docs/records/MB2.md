# MB2 · Woodland's road stack at a woodpile's 1.8 m

**Review:** @REVIEW@

MB1 built the log stack across Woodland's Long road at the Culvert a gate screen's 2.8 m and put its height to the
owner on a decision card, since he had asked for the woodpiles "less tall" (2026-11-09). The owner (2026-11-12):
"Lower it to 1.8 m". The card's option read: all woodpiles match the less-tall ask, flag B's south side is covered
another way, and the field is measured again.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
@ATTEMPTS@

## What changed

- `tools/woodland/layout.py`, `data/maps/woodland.json` (946 blocks, as before: one piece in, MB1's none out):
  the road stack `rect("logstack", 20.5, 42.0, 1.6, 6.0)` drops its `top=2.8` and stands 1.8 m. A stand of young
  spruce, "the Culvert stand" (`THICKETS`), is planted against its east face: 1.7 m deep, the stack's 6 m wide, 5 m
  tall. A thicket is solid: nothing sees, shoots or walks through it. No new model, no new sound.
- `tests/unit/test_mb1_layouts.gd`: the road stack stands 1.8 m with spruce against the whole of its east face,
  over twice its height; the Long road's line onto flag B's pole ring and posts stays shut (both fail without the
  spruce: the ring is seen along 350 of the test's lines).
- `docs/wiki/Maps.md`, `docs/DECISIONS.md` › Maps and modes, `docs/KNOWN_ISSUES.md` (the two Woodland rows).

## Why the stack could not just be lowered

The road's hump stands 2.1 m over the dip the stack is in, so a standing eye on it looks over anything 1.8 m tall.
Measured with seeded 6v6 bot matches at Normal (`tools/map_heat.gd`, the same 32 seeds each) and the game's ray:

| Layout | Elimination, west end | Attack / Defend, attackers | The road sees flag B's pole ring |
|---|---|---|---|
| MB1: the stack at 2.8 m | 48 % ±3 (239 rounds) | 59 % ±5 (117, 16 seeds) | along no line |
| 1.8 m, a stack closing the south-west of flag B's yard | 41 % ±3 (236) | 61 % ±4 (121, 16 seeds) | along no line |
| 1.8 m, spruce behind it (built) | 47 % ±3 (235) | 54 % ±4 (130, 16 seeds) | along no line |

Bands: 45 to 55 % and 40 to 65 %.

- **Lowered and nothing else,** the road west of the Culvert sees a chest in the ring round flag B's pole along
  1,485 of 55,625 lines, out to 63 m.
- **A stack at flag B** (a 3.9 m woodpile between the yard's road-mouth stack and its south one) shut that line, and
  the first 16 seeds read 41 %, the next 16 42 %: out of band. The knock-outs show why. The east's squad, walking
  up the road 2 to 12 m behind the stack, shot the west's over it as it crossed the hump, 30 to 40 m off (21 of the
  west's 222 losses on the hump, 1 of 215 at 2.8 m): the first knock-outs of the round, 20 to 27 s in. And flag B's
  attackers scored 155 to the defenders' 79 round the pole (138 to 94 at 2.8 m).
- **Spruce against the stack's east face** stands where the stack's top metre was and shuts both lines at once, so
  the yard keeps MB1's shape. The east's corner post moves 2 m back, from the stack's end to the stand's (24, 45),
  and takes 20 of the west's hump losses, not 41. Round flag B the attackers score 156 to the defenders' 127, round
  flag A 130 to 135.

Eight-seed blocks of Elimination on one layout ran from 34 to 55 %, so nothing here is read from fewer than 16
seeds, and the choice between layouts from 32.

## Decisions

- **Spruce, not a taller pile.** The owner's ruling is about woodpiles; the field's thickets are 5 m everywhere,
  and young spruce grown up behind a stack left at a road's edge is what a wood does. Told to the owner with the
  result; by the heights (not built) a root plate's 2.2 m shuts the hump's line only for an eye within 5 m of it.
- **The yard stack is not kept.** With the spruce it shut nothing more, and it leaned flag B further to the
  attackers.
- **Measured on MB1's merged head and again on `main` with SH1 and MQ2:** the bots' matches are the same round for
  round (the 16 seeds run on both gave identical records), so the figures above stand for the head.
- **The map card is not rendered again:** it looks north-east from (35, -25), away from the Culvert.

## Verified

@VERIFIED@
