# Handoff

What is happening now (as of 2026-11-16), for a session picking up the work. The plan is `docs/ROADMAP.md`, the
rulings `docs/DECISIONS.md`, how work runs `docs/PROCESS.md`.

## Now

- **0.1 Beta 1 is out (2026-11-16)** (tag `0.1-beta.1`), the first Beta build. 0.1 Beta 2 is being built:
  `config/version` reads "0.1 Beta 2". Beta is fixing, balance, performance and polish (`docs/PROCESS.md` › Placing
  work), from the owner's Beta 1 playtest and `docs/KNOWN_ISSUES.md`.
  The browser game is frozen at `0.1-beta.1`, removed from the repository on 2026-11-05 (owner) and read from git at
  the tag `0.1-dev.1`.
- **Fields.** Woodland and the Depot are redesigned (WR1, DR1). The Street was removed (owner, 2026-11-09, SX1).
- **Replicas.** The Sniper Rifle (bolt-action, Variable Scope) is public since DT1 (SN1 to SN3).
- **Bombs.** Smoke and flash bombs, thrown by you and by bots (SF1, SF2, GT1 to GT3).
- **Models.** The Blender series is built from the owner's photos: replicas (BL1 to BL6), power sources (BL7),
  attachments (BL8), magazines (MAG1), barrels (BA1), bombs (BL9), the figure's body (BL10), head gear (BL11), gear
  (BL12), pads (BL13) and faces (FA1).
- **Arms and holds.** The first-person arms hold each replica (BL4), your hands work the bombs and the Sniper Rifle's
  bolt (GT2, GT3, BW1, BW2), and bots hold replicas as the arms do, a pistol in one hand (HG1, owner, 2026-11-06).
  HA1 (owner, 2026-11-12): your pistol is in both hands, a rifle's hands tuck out of view as the sight comes up, the skin, gloves
  and sleeves are painted at 2K, and the replica has a life of its own in the hands (HandsMotion).
- **Sound.** The owner's recordings are in (AU2 to AU8).
- **UI.** The menus and HUD are redesigned (UR1 to UR7), with fixes after (UF1, UF2).
- **Bug passes.** BP2 to BP9 are merged; BP8 fixed the owner's thorough Dev 2 playtest, BP9 was the full pass before
  0.1 Beta 1.
- **Next.** 0.1 Beta 2, from the owner's Beta 1 playtest. The first Beta 2 bug pass also runs the archive check
  deferred at Dev 3 and Beta 1: `docs/PLAYTEST.md` (162 KB) and `docs/DECISIONS.md` (169 KB) are over 50 KB
  (`docs/PROCESS.md` › Releases, step 6). His open checks are carried over to his Beta 2
  list (`/mnt/project-files/playtest/0.1-beta2-checklist.md`).

## Where to look

- **Rulings in force:** `docs/DECISIONS.md`. **Open issues:** `docs/KNOWN_ISSUES.md`.
- **The browser game's files** below were removed on 2026-11-05; read them from git at the tag `0.1-dev.1`
  (`git show 0.1-dev.1:legacy/browser/<path>`, `git grep <terms> 0.1-dev.1 -- legacy/browser`).
- **How a system worked in the browser game:** `legacy/browser/src/<folder>/README.md`, then its tests.
- **Why a number is what it is:** `legacy/browser/docs/records/` and `legacy/browser/docs/archive/`.
- **What to rebuild:** `legacy/browser/docs/FEATURES.md` is the parity list; `docs/FEATURES.md` fills as features land.
