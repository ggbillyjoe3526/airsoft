# Legacy: reference copies

`katanashotgun/` holds a few scripts from the owner's katanashotgun project, with its own `README.md`. It is hidden
from Godot by `.gdignore` and goes at 0.1.

## The browser game (removed 2026-11-05)

`browser/` was the browser version of this game (`ggbillyjoe3526/Airsoft`, frozen at the tag `0.1-beta.1`, commit
`da04e66`): its TypeScript gameplay code and tests, its whole `docs/` folder and its old gate scripts, kept so every
system could be rewritten in Godot from its tested original. Nothing built, ran or shipped from it. The owner had it
removed on 2026-11-05, before tagging 0.1 Dev 2, to keep the size down.

It is unchanged in git at the tag `0.1-dev.1`, so every `legacy/browser/...` path the docs name still reads:

- `git show 0.1-dev.1:legacy/browser/docs/handover/SALVAGE.md` reads one file;
- `git grep <terms> 0.1-dev.1 -- legacy/browser` searches it (grep, then read ranges; never read it whole);
- `git ls-tree -r --name-only 0.1-dev.1 legacy/browser/src/sim` lists a folder.

`browser/docs/handover/SALVAGE.md` maps each system to its Godot home, `browser/src/<folder>/README.md` names each
folder's files, tuning and tests, and `browser/docs/records/` holds why each value is what it is.
