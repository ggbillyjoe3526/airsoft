# FP1 · First playable on Depot

**Review:** 1 attempt · critic Accept 7/8 (Opus) · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-10-18 | 1 | Opus 5.5 (build thread) | ✓ | 7/8 Accept | – (performance's first run failed on first-use shaders, fixed before the critic; the critic's miss, the config README, fixed in the records push) |

## Decisions

- **Lean and vault moved out of FP1** to keep the first playable small; they are a later Dev task with the bots
  (`docs/KNOWN_ISSUES.md` › Play).
- **Four Beta stand-ins stand in for bots:** characters with no controller at the Beta spawns. They can be knocked out
  and call their hits, so a round ends and the match rematches 8 s after it is over.
- **Bindings** follow `docs/DECISIONS.md` by physical key: walk Shift, sprint Alt, crouch C or Ctrl, toggled (a sprint
  or jump press stands you up), aim held, replicas 1, 2 and the mouse wheel. The browser game had ended with crouch
  held and aim toggled (its `config/controls.ts`); the owner's rulings here win until he says otherwise.
- **Depot's greybox is one mesh** with vertex colours from `MapStyle` and a world grid, plus one static body per
  surface, so a BB ray reads its surface from the collider. `BB_IMPACT` now carries that surface in `value2`.
- **The Jolt mover is a kinematic sweep** (`PhysicsServer3D.body_test_motion` with reused parameters): vertical, then up
  to four slides, with a step-up tried only when grounded and blocked. It allocates nothing per tick.
- **The play screen draws the sim by hand-interpolating** between the last two ticks; the scene's own physics
  interpolation is off, so the 60 Hz state stays the only truth.
- **Your own BBs start at the muzzle** of the replica in hand and blend onto their true path over 0.12 s, so they read
  as leaving the barrel though the sim fires them from the eye.
- **Play tuning is one resource** (`game/config/play_tuning.tres`): controls, view, replica in hand, effects, sound,
  HUD, map style, lighting and the team names and colours.
- **Late materials are drawn once at the start** (`ShaderPrewarm`, performance's finding): a fading figure, a BB, a
  puff and the sign, as specks in front of the camera for three frames, so the first shot or walk-off doesn't hitch.
- **The title screen and credits strings became translation keys** with the play screen's (`game/ui/text/en.po`).

- **Critic's advisories left as they are:** a few presentation literals (the sprint tilt, HUD spacing) and the
  mover's named ground and underfoot thresholds move into their configs when those files are next touched.

## Known issues left

- You can't be hit yet: the stand-ins never shoot, so your own hit call and walk-off wait for bots.
- No lean or vault; stand-ins, not bots; no settings screen; greybox Depot; capsule figures; the replica in hand
  shares the main camera; no graphics presets or perf baseline (`docs/KNOWN_ISSUES.md` › Play, Art and Graphics).
