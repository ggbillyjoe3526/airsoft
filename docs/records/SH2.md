# SH2 · The Pump Shotgun's own model, first-person hold and pump

**Review:** 2 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | build thread | ✓ 6,132 of 6,134 (2 pending, as on main) | 7/8 Retry | check 1: the stock's grooves were hairlines and its toe loop missing; the forearm showed at the hip; nothing gated the wrist; aimed, the stock filled the view's foot |
| 2026-11-12 | 2 | build thread | ✓ | 8/8 Accept | – |

## Decisions

- **The owner's ask** is in `docs/DECISIONS.md` › The Pump Shotgun: his five photos, no sights, the other replicas'
  quality, the right metals and polymer (MQ1's surface kinds).
- **Traced from photo 4** (the flat left side with the M4 stock) at 1.92 px per mm, with photo 3 for its depth and
  photo 5 for its right side; photos 1 and 2 show a different pump and grip and gave only the muzzle, the shell and
  the receiver's top. The pistol grip is the AEG Rifle's own, in the AEG's place, so the right hand's hold is the
  AEG's. Left off: the sights (his word), the photos' torch, the orange tip, every marking.
- **38,400 triangles in the hands, 2,999 on a figure.** Steel barrel, tube and cap; aluminium receiver, rails and
  receiver extension; polymer pump, grip, stock and shell; a 2K wear mask as the AEG Rifle's (RW1), imported VRAM
  compressed as the other replicas' (the performance review's note; a test pins it for every replica now).
- **No iron sights.** With no optic the eye sits on a line 9.5 mm over the top rail (5 mm at first: the stock's comb
  was then cut open by the near plane) and 11 cm behind the rail's back end (the rifles' 20 cm put the stock across
  the foot of the view: attempt 1). `test_iron_sights` lets a model in `NO_SIGHTS` carry no sight bones.
- **The stock's slots go through into its hollow** (attempt 2): three rows of five each side, 5.8 mm of wall, the
  upper two rows opening onto the receiver extension's underside and the lowest onto a chamber whose back wall leans
  out to face down, so every slot reads black from any light, as in the photos. A sling loop hangs at the toe.
- **The first-person hold.** The left hand holds the pump at its back end, 13 cm further forward than the AEG's
  handguard hold. From the rifles' hip place that showed 11 cm of forearm (the house rule is glove and cuff only), so
  the replica has its own hip place, 5 cm nearer and 2 cm lower (`ViewModelConfig.hip`, the same in `arms.py`'s
  `HOLDS`): 5 cm of forearm shows, as the Sniper Rifle's, and the wrist bends 8 degrees. A default the owner may
  change; a play check asks whether it sits well beside the other rifles.
- **The pump.** `cycle.work_pump` keys `shotgun_Fire`: the left hand rides the pump 62 mm back and home with the
  replica's own Fire clip (`ArmsView.follow`). The arms build fails if that wrist bends past 30 degrees held or over
  the stroke (`cycle.PUMP_WRIST`), as it does for a hand passing into the replica.
- **The reload** moves the replica less than the AEG's (`reload_move_by` (0.06, 0.04, 0)): at the AEG's move the left
  forearm showed past the wrist on the way to the shell and back (`test_bp8_arms`).
- **The replica rocks a quarter as much while pumped** (`work_cant` 0.25): the hand is on the pump, and the bolt
  action's full cant would swing the pump out of it.
- **Inspect** turns the replica over and moves nothing on it.
- **The pump's two knocks** were cut again to its own model's pump (back at 0.44 and home at 0.84 of the cycle).
- **The side rail** (the Red Laser left, the Weapon Torch right) joined `data/pool.md` with the model.

## Known issues left

- No sights: nothing marks the aim but the rail's far end (the owner's ruling; a play check asks).
  `docs/KNOWN_ISSUES.md`.
- The hold and its hip place wait for the owner's word on the pictures. `docs/KNOWN_ISSUES.md`.
- Aimed, the left fingertips show beside the receiver until HA1's aimed-hands rules have the shotgun's entries.
- On a bot its trigger finger reaches up at an angle: the trigger sits 2 cm higher over the grip than the AEG
  Rifle's, as in the photos. `docs/KNOWN_ISSUES.md`.
- Its sounds are still stand-ins (SH1).
