# AGENTS.md — DragonUI

Working rules for this repository. Read this before changing anything.

## Layout

```
DragonUI/           the addon (core, modules/, data/, libs/, Locales/, Textures/)
DragonUI_Options/   the options panel addon (panel/, Locales/, libs/, Textures/)
```

Both folders are loaded independently by the client and each has its own `.toc`. The folder name is
the addon name: `DragonUI/` must load as `DragonUI`, `DragonUI_Options/` as `DragonUI_Options`.

## Deploy — mandatory after every change

**The client does not read this repository.** It reads the game's AddOns folder:

```
F:\World of Warcraft - Manastorm\Interface\AddOns\DragonUI
F:\World of Warcraft - Manastorm\Interface\AddOns\DragonUI_Options
```

Every edit under `DragonUI/` or `DragonUI_Options/` must be copied there in the same session, or the
change exists only on disk here and nothing in game reflects it. Copy the **changed addon folder(s)**,
not just the file you touched, so nothing is left half-updated.

```powershell
$repo = "C:\Users\Strix\Documents\Github Projects\addons\DragonUI"
$game = "F:\World of Warcraft - Manastorm\Interface\AddOns"

# Mirror both addons into the client. /E copies subfolders; it never purges extra files.
robocopy "$repo\DragonUI"         "$game\DragonUI"         /E /NFL /NDL /NJH /NJS
robocopy "$repo\DragonUI_Options" "$game\DragonUI_Options" /E /NFL /NDL /NJH /NJS
```

- `robocopy` exits with a non-zero code on success (`1` copied, `2` extras, `3` both). That is not a
  failure — check the files, or the file counts, rather than the exit code.
- Copy only the addon folder you changed when the change is limited to one; copy both after touching
  the pair (an option key lives in `DragonUI_Options` *and* is read by `DragonUI`).
- Never mirror the repository root into AddOns and never let anything else (`.git`, `README.md`,
  `CONTRIBUTING.md`) land in the game folder. Only the two addon folders ship.

## Rules

1. **Write only into these two folders** — `DragonUI/` and `DragonUI_Options/` here, and their
   counterparts in the AddOns folder above. Nothing else under `F:\World of Warcraft - Manastorm`
   (in particular `WTF\`, `Cache\`, `Data\`) is ours to touch.
2. **Two copies per change, one repo.** This repository is the source of truth; the AddOns folder is
   the deploy target and is not versioned. Never edit the installed copy directly — a fix made there
   is lost on the next deploy.
3. **Keep the folder mapping identical.** A file added here goes to the matching path under AddOns
   with the same name and case, and must be listed in the addon's `.toc`/`.xml` or it never loads.
4. **The user tests in game.** Report what was changed and where it was deployed; do not claim an
   in-game result. Lua edits apply on `/reload`; a changed `.toc`/`.xml` file list or changed art
   needs the client restarted. Say which one the change needs.

## Checklist

- [ ] Change made under `DragonUI/` and/or `DragonUI_Options/` in this repository.
- [ ] New files added to the owning `.toc` / `.xml`.
- [ ] `robocopy` run for every changed addon folder.
- [ ] File present in `F:\World of Warcraft - Manastorm\Interface\AddOns\<addon>\` with a fresh
      timestamp.
- [ ] Told the user whether it needs `/reload` or a client restart.