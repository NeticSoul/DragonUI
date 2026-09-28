# Contributing to DragonUI

Bug reports, fixes, translations and new features are welcome. Please open an issue or a pull
request on GitHub.

## Your contributions are MIT

By submitting a pull request, patch, translation or texture, you agree that it is licensed under
DragonUI's [MIT License](LICENSE), and you confirm that you have the right to license it that way.
GitHub's terms already apply this "inbound = outbound" rule to pull requests; it is stated here so
there is no doubt.

## Code and art from other projects

- Only submit code or art copied or adapted from another project if its license is compatible with
  MIT: MIT, BSD, zlib, or public domain.
- Include its notice in the same pull request:
  - the license text in `LICENSES/` and its copy in `DragonUI/LICENSES/` (and in
    `DragonUI_Options/LICENSES/` if the material lives in `DragonUI_Options/`);
  - an entry in `THIRD_PARTY_NOTICES.md` (and its copy `DragonUI/THIRD_PARTY_NOTICES.md`) naming
    the files that contain it;
  - one header line in each such file, below its copyright line, e.g.
    `-- Portions adapted from <Project> (MIT, (c) <year> <holder>); see THIRD_PARTY_NOTICES.`
- Never copy code or art from a source marked "All Rights Reserved" or from one with no license at
  all. That includes GitHub repositories without a LICENSE file and addons whose download page
  gives no license. You may study such projects for ideas, but write your own code.
- GPL or other copyleft code cannot go into DragonUI's own files.
- For every new texture, say in the pull request where it comes from: which game client and file,
  which addon you took it from, or that you made it yourself. World of Warcraft artwork stays
  © Blizzard Entertainment and is covered by the carve-out in `THIRD_PARTY_NOTICES.md`, not by the
  MIT License.

## Keep the notice copies in sync

Users install only the `DragonUI/` and `DragonUI_Options/` folders, so the legal files are shipped
inside them as well. `DragonUI/THIRD_PARTY_NOTICES.md`, `DragonUI/LICENSE.txt` and
`DragonUI/LICENSES/` must stay identical to `THIRD_PARTY_NOTICES.md`, `LICENSE` and `LICENSES/` at
the repository root. When you change one, change the other.
