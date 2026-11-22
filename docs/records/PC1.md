# PC1 · Playtest fixes: lift doors sooner, What got you switch, Z spot without a hitch, slower levels, ALT always runs, red HIT!

**Review:** 2 attempts · critic pending · qa Pass · performance Pass

The owner's 0.1 Beta 2 playtest notes (2026-11-22), items 1, 2, 3, 4, 9 and 10 (the others went to other threads).

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-22 | 1 | Opus 5.5 (build thread) | ✓ | 7/8 Retry | check 6: held past a tap, the view snapped back as the wheel appeared |
| 2026-11-22 | 2 | Opus 5.5 (build thread) | ✓ | pending | – |

## Decisions

- **1, the lift "still too late".** The three door clips had no leading silence (above 5 % of peak within 1 ms), but
  each began with about 0.3 s of soft swell (29 to 36 % of its loudest) and peaked 0.7 to 1.2 s in. The cut now starts
  where the slide comes within 4 dB of its loudest (`tools/cut_recordings.py` LIFT_DOORS_WITHIN_DB, was 12): 55 to
  86 % at the start, the peak 0.2 to 0.4 s in. Same recording, length (1.7 s) and level (loudest 50 ms at -17.5 dB),
  so the gains hold. The simulation side was already on the next tick after the press (LS1); `shut_lead` unchanged.
- **2, What got you.** `Settings.what_got_you` is a bool, On by default; the enum and its Auto (Hard bots only) are
  gone, with the strings `SETTINGS_AUTO` and `SETTINGS_WHAT_GOT_YOU_NOTE` (nothing else used them). Settings version
  8: a version 1 to 7 file's Auto and On come over as On, Off stays Off (`WHAT_GOT_YOU_OFF_V7`). The row reads
  Off, On, as Simulate skipped rounds. DECISIONS › Menus, HUD, settings and accessibility.
- **3, the hitch on Z.** Cause: while the order wheel's key might still be a tap (`wheel_tap`, 0.3 s since UB3) the
  mouse went only to the hidden pointer and the view caught up on release, so the view stood still and then jumped.
  Now the view turns live through the tap; the hidden pointer still moves (so a flick made at once still lands on its
  button); held past a tap, the view stays where the tap left it and the mouse is the wheel's (attempt 1 snapped it
  back to the at-open view, a jump as the wheel appeared: critic). Go there and Watching here ping along that view,
  at most a tap's turn (0.3 s of mouse) from where you looked as the key went down. The simulation's side
  was measured and is not a stall: `Spots.place` with its share took a median 0.15 to 0.21 ms (max 0.65 ms) in one
  Attack / Defend match a field, and the three ticks after a spot had medians 0.3 to 0.4 ms above every other tick's,
  their worst under every other tick's p99 (Woodland 9.1 vs 22.1 ms max; probe in the run's reports). Sounds are
  preloaded and the arrows draw with no allocation.
- **4, levels.** Every level's XP is 1.5 times LV15's (`data/levels.md`): 150, 450, 600 ... 2,700, 21,750 to the cap
  (was 14,500). XP per match unchanged. A save keeps its XP and unlocks (`Progress.unlocked`); its level number may
  read lower (6,500 XP was level 10, now 8). DECISIONS › Replicas, Loadout and levels.
- **9, ALT.** No stamina exists. The sprint only lost to other inputs: walk (Shift), aiming (a held or toggled
  sight), a crouch (held, toggled, or Ctrl, which Windows sends with AltGr on a UK keyboard) and a lean. Now the
  sprint key held while moving forward wins over all of them in `PlayerInput.fill` (`_sprint_first`), letting go a
  toggled crouch or sight; the simulation's order is unchanged, so bots, which set walk and sprint themselves, play
  as before. A roof too low to stand under still keeps you down. Default: no sprint sideways or back, as before.
- **10, HIT!.** `FigureView.SIGN_COLOUR` #ff2b22 with an edge darkened by `SIGN_OUTLINE_DARKEN`, for both teams
  (before: white with an edge in the team's colour). The sign shows while calling and walking off, as before.

## Known issues left

- None.
