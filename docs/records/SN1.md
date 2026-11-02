# SN1 · The Sniper Rifle

**Review:** 1 attempt · critic pending · qa pending · performance pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-02 | 1 | Opus 5.5 (build thread) | ✓ | pending | – |

## What changed

- **The replica.** `000021 Sniper Rifle` (pool.md, dev): class `sniper`, spring, single shot, 1.9 J with 0.30 g BBs,
  0.8 shots a second, 25 BBs × 4, a new **Hip spread (×)** stats.md column (6: the spread grows with the sight down
  and shrinks as it comes up, `Accuracy.target_spread_scale`). A `sniper` site class (2.3 J). Takes the AEG's sights,
  grips, torches and muzzle parts; no barrels, no AEG magazines.
- **Comes with.** A new pool.md column fits parts as a replica comes (`Pool.comes_with`, `LoadoutRules.default_tune`):
  the rifle comes with the 2x Scope, which can be taken off or swapped like any part.
- **Springs.** `000022 M130`, `000023 M140`, `000024 M150` (power sources, dev): +0/+10/+20 % energy and kick,
  cycling 0/5/10 % slower. A coil picture each (`tools/blender/power/spring.py`).
- **Levels.** Level 5: Tight-Bore Barrel, Sniper Rifle, M130 Spring, 2x Scope (from 7). Red Gas 5 → 6, M140 at 7,
  M150 at 9. Cap stays 10. The level-up card names dev items only with Dev content on (it named them to everyone).
- **Model.** `tools/blender/replicas/sniper.py`: the AEG's model with the barrel run 0.20 m further and a Fire clip
  that pulls the trigger then draws the charging handle back and lets it go (1.0 s); the parts file is the AEG's
  without barrels and magazines. A placeholder until the owner's reference photos come.
- **Sound.** `boltCycle_1..3` (`tools/render_bolt.gd`): the handle's scrape over the spring, the sear's click, the snap
  home, timed to the clip, played after each shot (`SimAudio`).
- **Bots.** A Sniper kit (bot-kits.md, anchor/careful). Bots with a hip-spread replica raise the sight to fight and
  shoot from the hip only inside 8 m (`BotCombat.fights_aimed`, BotConfig `aimed_fire_raise`, `hip_fire_range`).
- Wiki: the site-limits table names only classes with a public replica.

## Decisions

- Single shot; comes with the 2x Scope; like the AEG with a longer barrel, spring; springs as the gases; unlocks at
  level 5 with the 2x Scope; Red Gas to 6; cap 10 (owner, 2026-11-02; DECISIONS).

## Defaults taken

- 2.3 J sniper limit (UK sites' bolt-action limit); 1.9 J with 0.30 g reaches flat to about 48 m (AEG 39 m) and 50 m in
  0.81 s (AEG 1.18 s): longer and quicker, not a laser.
- 0.30 g, not heavier: the Loadout's BB range stays 0.20 to 0.30 g for everyone.
- Hip spread 6: a scoped bolt-action from the hip is a gamble, which keeps the rifle off close fights.
- 25-BB magazines, 4 carried: a spring rifle's real size, and a round lasts.
- Bots hip-fire only inside 8 m: a bot that always waited for the sight would lose every close fight it walks into.

## Checks

- `tests/unit/test_sniper_rifle.gd`: the pool row, single shot, the scope and spring as it comes (and taken off), the
  springs under the limit, level 5, the cycle and magazine, the hip spread, the model (muzzle, Fire clip), the parts
  file, the spring pictures and cues, the Sniper kit.
- Pictures: `/mnt/project-files/playtest/sniper-sn1/`.

## Known issues left

- The Loadout's replica row rounds 0.8 shots a second to "1 BBs/s" (the Loadout is being rebuilt by UR1).
- Teammates still carry the factory AEG; the rifle's magazines aren't shared with the AEG's (class `sniper`).
- With Dev content off, level 7 holds nothing to show (only the dev M140 Spring) until the rifle goes public: its
  Armory row and level-up card are bare.
- The model is a placeholder: reshaped when the owner's reference photos arrive.
