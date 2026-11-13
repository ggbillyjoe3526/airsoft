# SH2 · The Pump Shotgun's own model, first-person hold and pump

**Review:** 4 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | build thread | ✓ 6,132 of 6,134 (2 pending, as on main) | 7/8 Retry | check 1: the stock's grooves were hairlines and its toe loop missing; the forearm showed at the hip; nothing gated the wrist; aimed, the stock filled the view's foot |
| 2026-11-13 | 2 | build thread | ✓ 6,205 of 6,207 (2 pending, as on main) | 7/8 Retry | check 1: a bot's trigger finger stuck out to reach the trigger; the stock's last column of slots showed the tube's end and a grey floor |
| 2026-11-13 | 3 | build thread | ✓ 6,433 of 6,435 (2 pending, as on main) | 7/8 Retry | check 1 (measured): the stock's last column of slots was cut 0.78 of the others' length; photo 4's five are equal |
| 2026-11-13 | 4 | build thread | ✓ 6,452 of 6,454 (2 pending, as on main) | 8/8 Accept | – |

## Decisions

- **The owner's ask** is in `docs/DECISIONS.md` › The Pump Shotgun: his five photos, no sights, the other replicas'
  quality, the right metals and polymer (MQ1's surface kinds).
- **Traced from photo 4** (the flat left side with the M4 stock) at 1.92 px per mm, with photo 3 for its depth and
  photo 5 for its right side; photos 1 and 2 show a different pump and grip and gave only the muzzle, the shell and
  the receiver's top. The pistol grip is the AEG Rifle's own, in the AEG's place, so the right hand's hold is the
  AEG's. Left off: the sights (his word), the photos' torch, the orange tip, every marking.
- **37,700 triangles in the hands, 2,992 on a figure.** Steel barrel, tube and cap; aluminium receiver, rails and
  receiver extension; polymer pump, grip, stock and shell; a 2K wear mask as the AEG Rifle's (RW1), imported VRAM
  compressed as the other replicas' (the performance review's note; a test pins it for every replica now).
- **No iron sights.** With no optic the eye sits on a line 9.5 mm over the top rail (5 mm at first: the stock's comb
  was then cut open by the near plane) and 9 cm behind the rail's back end (the rifles' 20 cm put the stock across
  the foot of the view: attempt 1). `test_iron_sights` lets a model in `NO_SIGHTS` carry no sight bones.
- **The stock's slots go through into its hollow** (attempt 2): three rows of five each side through 2.2 mm of
  wall, the five columns equal and the last running to the butt pad's lip, measured on photo 4 (slots 59 to 60 px on
  a 64 px pitch, 4 px ribs; attempt 4: attempt 3 had cut the last column short to keep it inside the hollow, which
  the photo does not show). Behind them the hollow, the receiver extension and the rail under it run back to the
  pad, the rail drawn as a keel tapering down from the tube's flanks (attempt 3), both black aluminium with faces
  that look down: all fifteen slots read black end to end from either side. A polymer wall behind them, then an
  upright rail, read grey in the studio's unshadowed fill light, and the tube's end face showed as a lit sliver in
  the last column while it stopped short. A sling loop hangs at the toe.
- **The first-person hold.** The left hand holds the pump at its back end, 13 cm further forward than the AEG's
  handguard hold. From the rifles' hip place that showed 11 cm of forearm (the house rule is glove and cuff only), so
  the replica has its own hip place, 5 cm nearer and 2 cm lower (`ViewModelConfig.hip`, the same in `arms.py`'s
  `HOLDS`): 5 cm of forearm shows, as the Sniper Rifle's, and the wrist bends 8 degrees. A default the owner may
  change; a play check asks whether it sits well beside the other rifles.
- **The right hand sits 18 mm higher on the grip than on the AEG Rifle** (attempt 3; its own marks in `arms.py`
  `SHOTGUN_RIGHT`): the shotgun's trigger guard is 2 cm higher over the same grip (an adapter stands between the
  grip and the receiver), so as in the photos the middle finger sits right under the guard and the index finger lies
  along it onto the trigger. From the AEG's place the finger had to swing 40 degrees off the others to reach, which
  read as a raised finger on a bot (the figures take their hands from the arms' holds). The finger rests low on the
  blade (`trigger_at` 0.82): the blade's upper half is up inside the receiver's foot.
- **The pump.** `cycle.work_pump` keys `shotgun_Fire`: the left hand rides the pump 62 mm back and home with the
  replica's own Fire clip (`ArmsView.follow`). The arms build fails if that wrist bends past 30 degrees held or over
  the stroke (`cycle.PUMP_WRIST`), as it does for a hand passing into the replica.
- **The reload** moves the replica less than the AEG's (`reload_move_by` (0.04, 0.04, 0)): at the AEG's move the left
  forearm showed past the wrist on the way to the shell and back (`test_bp8_arms`).
- **The replica rocks a quarter as much while pumped** (`work_cant` 0.25): the hand is on the pump, and the bolt
  action's full cant would swing the pump out of it.
- **Inspect** turns the replica over and moves nothing on it.
- **Main's reworked attachments** (MQ2, merged during attempt 2: the vertical grip 64 mm) came in before this: the
  shotgun's parts file and the whole arms model were rebuilt on them, so the other rifles' foregrip holds are built
  for the longer grip too.
- **The pump's two knocks** were cut again to its own model's pump (back at 0.44 and home at 0.84 of the cycle).
- **The side rail** (the Red Laser left, the Weapon Torch right) joined `data/pool.md` with the model.

## Known issues left

- No sights: nothing marks the aim but the rail's far end (the owner's ruling; a play check asks).
  `docs/KNOWN_ISSUES.md`.
- The hold and its hip place wait for the owner's word on the pictures. `docs/KNOWN_ISSUES.md`.
- Aimed, the left fingertips showed beside the receiver until HA1's aimed-hands rules had the shotgun's entries
  (added in HA1: `aim_tuck`, `aim_slide`).
- Its sounds are still stand-ins (SH1).
