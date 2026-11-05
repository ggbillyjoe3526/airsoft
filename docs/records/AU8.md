# AU8 · One dry click for every replica; the range sounds like The Street

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Decisions

- **Owner's rulings (2026-11-05)** are in `docs/DECISIONS.md` › Audio: every replica fired empty clicks the gas
  pistol's recorded dry fire ("NOT a placeholder ... the final decision"), and the practice range plays The Street's
  day sound. He kept the AEG Rifle as it is after hearing a version with 5 dB more motor.
- **One cue, not one a profile:** `SimAudio.DRY_CUE` (`dryFire`) plays for every sound profile, so a replica added later
  clicks the same with nothing to add. The pistol's five takes are renamed from `dryFire_gas` (the same bytes, UIDs kept);
  the AEG's motor click (`motor_whir3`), the Sniper Rifle's and the Cyber Pistol's re-pitched stand-ins are gone, which
  leaves 13 placeholders. Default: "all future replicas" read as every replica, so the Cyber Pistol clicks the same too
  (its own click was a labelled stand-in, the pistol's re-pitched).
- **The range** names `"ambience": "street"` in `data/maps/range.json`: by day The Street's bed and calls; Dev › Time of
  day at night gives The Street's night, as it would on The Street.
