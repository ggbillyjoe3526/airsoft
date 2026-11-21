# LS1 · Subway's lift sounds start on the press, heard only inside

**Review:** pending

The owner's 0.1 Beta 2 playtest (2026-11-21), after UL3: "lift sound timing still off. should play just after the
player presses a button. should also only play when the player is inside the lift".

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-21 | 1 | Opus 5.5 (build thread) | ✓ | 7/8 Retry | check 1: a press from inside while the doors open waited door_time + dwell |
| 2026-11-21 | 2 | Opus 5.5 (build thread) | ✓ | 7/8 Retry | check 1: with another rider aboard, a press while opening still waited the dwell |
| 2026-11-21 | 3 | Opus 5.5 (build thread) | ✓ | – | – |

## Decisions

- **Why it was late.** A car never shut on a body in its doorway, and its doorway reached a body's width (0.32 m) into
  the car. Stepping in and pressing at once left the presser standing in it, so the doors waited, silent, until they
  stepped further in; the doors' sound then came whenever that was. Measured on both of Subway's lifts: a press
  0.05 or 0.2 m in never shut; 0.35 m in shut on the next tick.
- **A body aboard no longer holds the doors** (`Lifts._blocked_from_outside`): only one in the doorway from outside
  the car (the landing, the wall's depth) does, as before. The doors are heard on the tick after the press, and the
  presser is eased in, at `LiftConfig.step_in_speed` 1.0 m/s (default: a body's radius well inside `shut_lead`),
  until `step_in_gap` 0.01 m clear (`Lifts.step_in`, after carry). The doorway turns solid to bodies once nobody is
  in it (`LiftState.sealed`); with nobody in it that is at the shut's start, as before. Should someone aboard still
  stand in it as the lead ends, the leaves wait for them; someone walking into it from outside before it is sealed
  opens the doors again (heard), the call kept. A shut from fully open still leaves door_time after it starts.
- **A press from inside while the doors open shuts them again from where they stand** (critic, attempts 1 and 2),
  whoever else is aboard, as a press standing open shuts them at once (`panel_dwell` 0): the shut is heard on the
  press, the leaves stand still through the lead (a shut never opens them further) and meet in the rest, so the car
  leaves `shut_lead + shut_time × open` after the press. Not with anyone hit aboard or too many, who keep it open
  anyway.
- **A car is heard only from inside it** (owner ruling, `docs/DECISIONS.md` › Audio): `SimAudio.heard_in_car` plays
  its doors, motor, chime and buzzer only to a listener standing in that car; a button's beep wherever in reach.
  Calling a lift from its landing now beeps, and the car arrives quietly.
- **The minimap and the sound cues take only a lift's beeps** (default): they show what you hear. Whoever rides with
  you is in sight anyway.
- **Bots still hear a car to `LiftConfig.heard`** (default): their hearing is unchanged, so Subway's balance is.
  If the owner wants bots held to the same ears, it is one line in `BotHearing.observe`.

## Known issues left

- How it sounds and feels in play: PLAYTEST LS1 and the Beta 2 checklist.
