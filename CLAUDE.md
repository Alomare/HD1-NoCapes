# Rules for this repository

**Every release has a changelog.** Before tagging, add a section for the version to `CHANGELOG.md`, headed `## <version>`. Each change is one list item, starting `- New:`, `- Changed:`, `- Fixed:` or `- Removed:`, and describes the change briefly and directly. The shared Release workflow publishes that section as the release notes on GitHub, and stops if the section is missing or breaks the rules for public text.

**Tests:** `luajit tests/run.lua` from the repository root (LuaJIT at `ProjectObsidian/ObsidianLauncher/target/luajit/luajit.exe`).

**How it works:** `src/capes.lua` hides each new `cape_unit` in the customization component's slave states on the frame it appears, re-hides all of them every `FULL` (30) frames, and wraps `Unit.set_unit_visibility` so a known cape can't be shown while the mod is on. The mod loads after Photo Mode (`load.after` in `obsidian.json`). Client scope: visual only, on this machine.
