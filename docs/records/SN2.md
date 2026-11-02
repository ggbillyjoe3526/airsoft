# SN2 · The Variable Scope

**Review:** 2 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-02 | 1 | Opus 5.5 (build thread) | ✓ | 6/8 Retry | check 1: the wheel turned the zoom with aim held but the sight down (reload, draw); check 8: KNOWN_ISSUES rows |
| 2026-11-02 | 2 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## What changed

- **The optic.** `000025 Variable Scope` (pool.md, dev, `scopeVar`, top rail: the AEG Rifle and the Sniper Rifle).
  stats.md's Optics table gains a **Zoom to (×)** column (`PartStats.Part.zoom_to`, `ReplicaConfig.aim_zoom_to`): 2×
  to 6×, in its glass, raise 1.9. Level 8.
- **Turning it.** Aimed through a variable optic, the mouse wheel fills `PlayerCommand.zoom_steps` (up zooms in)
  instead of switching (`PlayerInput.fill`'s `zoom_turns`, from `Armament.zoom_turns`). `Armament.zooms` holds each
  slot's zoom, turned `ReplicaRulesConfig.zoom_step` (1×) a notch between its ends with a ZOOM event (the selector's
  click, "Zoom 4×" in the hop-up's place on the HUD); kept through rounds, reset for a new match as the hop-up dial
  is. Dropped with a bomb in hand; a vault keeps a turn as any press (though the sight is down mid-vault, so the
  player's wheel switches there). The glass reads it every frame (`ReplicaView`).
- **Model.** `tools/blender/parts/variable_scope.py`: the 2x Scope copied as `optic_scopeVar` into the AEG's and the
  Sniper Rifle's parts files, its tube 3.5 cm longer in front of the mount (the eyepiece, the glass and the eye stay as
  the 2x Scope's), a ridged zoom ring and an index mark.
- Only with the sight up (critic): aim held through a reload or a draw lowers the sight (`Aiming`), so the wheel
  switches as usual there (`Character.aiming` gates the input and `Armament.step`).
- Customise and the performance sheet show its top zoom (6×). Only an optic zoomed in its glass turns (QA: a
  whole-view optic with a Zoom to would have taken the wheel and changed nothing).

## Decisions

- The 2x Scope, but variable zoom and a little longer (owner, 2026-11-02; DECISIONS).

## Defaults taken

- 2× to 6×, 1× a notch: from the 2x Scope's own zoom to a long-range view that still leaves the glass readable.
- The mouse wheel, only while aimed through it: the wheel already switches, and aimed you never switch.
- Kept for the match: you set it once for the field, as the hop-up dial.
- Raise 1.9 (the 2x Scope 1.6): a longer, heavier scope. Level 8, beside the LiPo, after the rifle at 5.

## Checks

- `tests/unit/test_variable_scope.gd`: the pool row, its stats and the 2x Scope fixed, turning and its ends and
  events, kept through a round and reset for a match, fixed optics never turn, the wheel aimed and from the hip, a
  vault and a bomb in hand, level 8, the parts files (3.5 cm longer, the eyepiece in place).
- Pictures: `/mnt/project-files/playtest/variable-scope-sn2/`.

## Known issues left

- The model is a placeholder: the owner makes the final one.
- The mouse turns the view as fast at 6× as at 2× (the 2x Scope's glass never slowed it either): it may feel quick.
- Bots never turn it: they look through it at 2× (the zoom changes nothing in the simulation).
