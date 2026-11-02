# BP3 · Fixes from the bug pass after the Sniper Rifle

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-03 | 1 | Opus 5.5 (bug pass thread) | ✓ | Retry 6/8 | a switch fired a kept bolt press; full auto came back for a target re-seen out of the open |
| 2026-11-03 | 2 | Opus 5.5 (bug pass thread) | ✓ | Accept 8/8 | – |

## The bug pass

Asked by the owner on 2026-11-02, once the UI redesign (UR1 to UR7), the Sniper Rifle (SN1), the Variable Scope (SN2)
and "no full auto indoors" (NA1) had merged: a balance check of the three fields for the rifle, then a bug pass on the
new work first and the whole game after. Four readers read main f8fda35, read only: the rifle, springs and scope; the
bots' fire modes; the menus (UR1 to UR4); the Armory, Settings and HUD (UR5 to UR7). None found a blocking bug. This
pull request fixes what they found that a player meets; the balance work follows in its own.

## What changed

1. **The rifle's bolt held up the pistol** (`Armament`): one cooldown served both slots, so after a shot the pistol
   switched to couldn't fire for the rest of the rifle's 1.25 s. Each slot now keeps its own (`stowed_cooldowns`); a
   stowed bolt keeps cycling and switching back never skips it.
2. **A click once the handle looked home was lost**: the Fire clip and cocking sound end 0.71 s after a shot, the cycle
   1.25 to 1.39 s. A bolt-action press within `ReplicaRulesConfig.bolt_press_window` (0.7 s) of the cycle's end is
   kept until it ends; an earlier one lapses as before, so a double click never fires twice. A switch drops a kept press
   (critic: it fired the pistol as it came up).
3. **The mouse turned as fast through 6× as at the hip**: through a scope's glass the turn now scales with the glass's
   zoom (`FirstPersonView`), not the iron sights' 1.2 round it; the 2x Scope too.
4. **The rifle read "1 BBs/s"** on the Loadout card and the performance sheet: rates now show to two places without
   trailing zeros (0.8, 0.76 with the M140; `LoadoutPerformance.rate_text`), so a spring's slower cycling shows. The
   Energy bar is full at 2.3 J and the Zoom bar at 6×, so springs and scopes are told apart.
5. **The replica panel jumped 25 px down** with both notes and the bomb row showing: its lane is 260 px and it grows up.
   The Settings › HUD preview is 236 px so the panel fits at 150 %, and shows one of each bomb, not blank icons.
6. **Choice tracks ran across whole rows** (Match › Custom rules, Time of day): the rounded track spans its buttons.
7. **Armory, Dev content off:** level 7 (only the dev M140) was the edged NEXT card while the header named 8. NEXT is
   now the next level with something to show.
8. **Notices and the keyboard:** after the crash screen, or back from Settings, PLAY took the keyboard while the safe
   graphics question waited, so Enter started a match past it. The notice keeps it. Under Settings the notice steps
   aside (it covered BACK) and comes back after.
9. **Dev content switched in Settings** left the Loadout page's list stale; it is built again, as the Armory is.
10. **Bots indoors** (NA1): losing sight for a tick took a target's full auto for good (the roll is once per target).
    Now losing sight ends the burst and drops to the start mode, keeping the roll, and the next burst that finds the
    target in the open again goes back to full auto (`Bot.auto_open`), never one that finds it in a doorway; a bot
    never fires on a tick its selector moves (the way from burst back to semi passes full auto); and followers no
    longer holster when the giver takes a bomb in hand (`BotHolster.put_away`).

Known issues: two rows fixed (the 6× mouse speed, "1 BBs/s"); six can-wait or playtest rows added from the readers.

## Defaults taken

- Through a scope the turn follows the glass's zoom, so the 2x Scope turns slower than before as well.
- The bolt's press window is 0.7 s: the M150's cycle less the handle's 0.71 s.
- The Settings HUD preview grew 56 px rather than hiding the bomb row.

## Checks

- `tests/unit/test_bp3.gd`: the pistol fires as it comes up after a rifle shot; switching back never skips the bolt;
  a click after the handle is home fires at the cycle's end, a double click doesn't; a bomb in hand is no holster to
  follow; level 7 isn't NEXT with Dev content off; rates read 0.8, 0.76, 13. `test_start_mode_bots.gd`: full auto kept
  for a target seen again in the open.
- `tools/check.sh`.
