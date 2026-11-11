# Rules for this repository

**Every release has a changelog.** Before tagging, add a section for the version to `CHANGELOG.md`, headed `## <version>`, listing the new, changed or removed features. Each change is one list item, starting `- New:`, `- Changed:` or `- Removed:`, and describes the change briefly and directly. The Release workflow publishes that section as the release notes, and stops if the section is missing or `python tools/release_notes.py check` rejects the wording.

**Tests:** `luajit tests/run.lua` from the repository root (LuaJIT at `ProjectObsidian/ObsidianLauncher/target/luajit/luajit.exe`).

**How it works:** `src/capes.lua` hides every `cape_unit` in the customization component's slave states once a frame, and wraps `Unit.set_unit_visibility` so a known cape can't be shown while the mod is on. The mod loads after Photo Mode (`load.after` in `obsidian.json`). Client scope: visual only, on this machine.
