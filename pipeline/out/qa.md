# QA: BL3 AEG Rifle rework, re-check of v20 (aeg.glb == scratchpad aeg2/v20.glb; sniper.glb rebuilt from it)

Verdict: **Pass**

Method as before: headless bpy, animation data cleared, clip keyframes applied by hand, ray casts into Body.
- **Trigger, Fire (17 degrees about x at bone y -0.0067):** nearest Body 1.4 mm at rest and 1.4 mm at full pull (side clearance in the slot, +-4.5 vs +-3.1).
  Rear gap to the slot's back wall 13.0 mm at rest, 14.1 mm at full pull; front 19.3 / 18.2 mm. No guard, bar or grip contact. The v14 bottom-out (0.3 mm) is gone.
- **Charging handle shaft past the new rail end blocks, Inspect pull 0 to 0.050:** channel walls measure x +-0.0056 at z 0.065 / 0.0665 / 0.0678 on every
  sampled y from -0.0845 to -0.035, so the blocks leave the walls where they were. Shaft is +-0.0052 to 0.0061 at its joint (+-0.0052 along the channel), z 0.0648-0.068, y -0.085 to -0.030:
  no Body vertex inside its swept box at 0, 0.0125, 0.025, 0.0375, 0.050. It slides free.
- **T over the Body:** clearance 11.2 mm at pull 0, 5.6 mm at 0.0125, 5.0 mm from 0.025 to 0.050. The blocks (top z 0.0679) are under the T (bottom 0.0665 only at x beyond +-0.0106 in front of -0.085, where the T is behind them).
- Not rechecked because unchanged: bones, empties, clips and the earlier test list (the coordinator is re-running targeted tests). I did not measure the new grip or GripPanels for interpenetration with the Trigger beyond the trigger check above, which covers every Body vertex including the joined panels.
- Not verified: how the grip groove and panels read in play.
