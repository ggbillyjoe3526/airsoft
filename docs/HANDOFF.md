# Handoff

What is happening now (as of 2026-11-06), for a session picking up the work. The plan is `docs/ROADMAP.md`, the
rulings `docs/DECISIONS.md`, how work runs `docs/PROCESS.md`.

## Now

- **0.1 Dev 1 is out (2026-10-30)** (tag `0.1-dev.1`). 0.1 Dev 2 is being built: `config/version` reads "0.1 Dev 2".
  The browser game is frozen at `0.1-beta.1`, removed from the repository on 2026-11-05 (owner) and read from git at
  the tag `0.1-dev.1`.
- **Fields.** Woodland and the Depot are redesigned (WR1, DR1). The Street is a new field, dev only since DT1.
- **Replicas.** The Sniper Rifle (bolt-action, Variable Scope) is public since DT1 (SN1 to SN3).
- **Bombs.** Smoke and flash bombs, thrown by you and by bots (SF1, SF2, GT1 to GT3).
- **Models.** The Blender series is built from the owner's photos: replicas (BL1 to BL6), power sources (BL7),
  attachments (BL8), magazines (MAG1), barrels (BA1), bombs (BL9), the figure's body (BL10), head gear (BL11), gear
  (BL12), pads (BL13) and faces (FA1).
- **Arms and holds.** The first-person arms hold each replica (BL4), your hands work the bombs and the Sniper Rifle's
  bolt (GT2, GT3, BW1, BW2), and bots hold replicas as the arms do, a pistol in one hand (HG1, owner, 2026-11-06).
- **Sound.** The owner's recordings are in (AU2 to AU8).
- **UI.** The UI is redesigned (UF1, UF2); the Switch Replica menu takes clicks and keys.
- **Bug passes.** BP2 to BP4 are merged. BP5 is under way.
- **Next.** The owner's playtest of the Dev 2 list, then the release checklist after he tags (`docs/PROCESS.md`).

## Where to look

- **Rulings in force:** `docs/DECISIONS.md`. **Open issues:** `docs/KNOWN_ISSUES.md`.
- **The browser game's files** below were removed on 2026-11-05; read them from git at the tag `0.1-dev.1`
  (`git show 0.1-dev.1:legacy/browser/<path>`, `git grep <terms> 0.1-dev.1 -- legacy/browser`).
- **How a system worked in the browser game:** `legacy/browser/src/<folder>/README.md`, then its tests.
- **Why a number is what it is:** `legacy/browser/docs/records/` and `legacy/browser/docs/archive/`.
- **What to rebuild:** `legacy/browser/docs/FEATURES.md` is the parity list; `docs/FEATURES.md` fills as features land.
