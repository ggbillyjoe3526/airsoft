# MC1 · Match controls and menu fixes

From the owner's playtest of 2026-11-01 (points 1, 5, 7, 10 and 11).

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-01 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## Decisions

- **Doors on G.** The nearest key to W A S D left free once the bombs moved to 4 and 5; nothing else moved.
- **The hop-up dial keeps only Page Down and Page Up.** Its 4 and 5 went to the bombs (owner); a second key is the
  player's to pick in Settings › Controls.
- **Old saves follow the move (KeyBindings.LAYOUT 2).** An action a save holds on its old default takes the new one;
  an action the player changed keeps their key; a moved default another action of theirs holds is left off.
- **The mouse wheel takes a bomb in hand, the 4 and 5 keys still throw at once.** In hand the replica is down (as
  holstered: the holster's quicker run), the crosshair stays at no spread, the bomb shows in hand; a trigger pull
  throws, a slot, reload or the holster puts it back. A bomb with none left is passed over; never the holster.
- **Continue comes up once drawn and the shaders are warm,** or 10 s after the first frame at the latest
  (PlayTuning.go_fallback); the round clock starts on the press. The smoke test, headless runs (tests and tools) and
  the way back from practice's Loadout go straight in.
- **A skip plays the rest out as fast as the computer allows** (50 ms of ticks a physics frame under a still cover,
  the field not drawn, nothing heard), showing the round's clock running down. Measured headless in a cloud session:
  101 s of a Woodland round in 16 s, 26 s of a Depot round in 6 s; the time is the simulation and the bots'
  thinking (about 2.6 and 2.1 ms a tick on Woodland there), so a faster computer skips faster.
- **Only a skipped round waits for the click;** a round you play to its end moves on by itself as before.
- **Minimap zoom 50 % to 200 % in 10 % steps, 100 % default;** the heard patches' rim follows it.
- **The Day / Night row gets 18 px more room** over it.

## Known issues left

- None.
