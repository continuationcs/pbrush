# AGENTS.md

Notes for coding agents working on this repository (BOSS RUSH, a UE4SS Lua mod for Phantom Blade Zero).

## Working with the user

- Talk to the user in **Chinese**; code, comments and commit messages in English.
- The user tests in game and reports back. After changing the mod, install it (`tools\install.ps1`) and tell the
  user exactly what to try; read `UE4SS.log` afterwards instead of asking them to copy logs.
- Decisions the user has made are recorded in `docs/DESIGN.md` (marked 用户决定 / 用户确认). Do not revert them:
  e.g. no arena choice (auto pick), no vows in Gauntlet, all open bosses offered (no defeat filter), difficulty
  follows the game setting with no extra levels, curve weight 1.0, the Trial (roguelike) mode hidden, no
  top-of-screen Gauntlet HUD.
- Copy style (`docs/COPY.md`): plain words; items of one kind keep the same character count (entry 4 chars,
  modes 2 chars); descriptions are two parts, one poetic line then one plain line. zh-Hans and English.
- Controller first: every new UI must be reachable and usable with a gamepad.
- Feel native: reuse the game's widgets (`W_DialogueButton`, `WB_TipsText`, `wb_settlement`), never draw custom
  UI when a game widget exists. Never write into the game save.

## Paths

- Game: `G:\G\Steam\steamapps\common\PBZ`; UE4SS: `...\platform\steam\ue4ss` (log `UE4SS.log`,
  header dump `CXXHeaderDump\`, mods `Mods\`).
- Game assets can be read offline with the `pbzero` package (`F:\C\pbzero\src`, `IoStore` + `Oodle` over
  `ProjectPBZ\Content\Paks\ProjectPBZ-Windows.utoc`); see `tools/gen_roster.py` for the import pattern.

## Build, install, release

- `powershell -File tools\install.ps1 -Mods BossRush` (one mod per call; a comma list is passed as one string).
  It **wipes** the target folder: the probe's `sdk_done.txt` and `arenas.tsv` must be restored after installing
  the probe (`echo 1 > ...\BossRushProbe\sdk_done.txt`, copy `data\run11\arenas.tsv` back).
- `python tools\build_release.py <version>` builds `dist\BossRush-<version>.zip` with `debug = false` in the copy
  and refuses scripts that contain debug key bindings. The repo keeps `debug = true`.
- Nexus page: mod 1099 (`release/NEXUS_PAGE.md`). Updates go to the same page as a new file version. Nexus sits
  behind Cloudflare; a human check that appears must be passed by the user, never by an agent.

## No Lua interpreter here

There is no `lua`/`luac` on the machine. After editing Lua, at least run a block-balance check
(`function/if/do/repeat` vs `end`, brackets) and re-read the call sites: one bad edit once deleted helper
functions and the menu broke with "attempt to call a nil value". Prefer the Edit tool for Lua.

**Do not write Lua through a Bash heredoc + Python one-liner when it contains escapes** (`\t`, `\n`, `\\`): the
shell turns them into real characters. Use the Edit/Write tools, or a Python script file.

## UE4SS / game gotchas (all learned the hard way)

- `ExecuteWithDelay` needs an **integer** ms (`math.floor`), or it errors.
- `LoopAsync` callbacks run off the game thread: do game work inside `ExecuteInGameThread`, and keep loop state in
  upvalues checked at the top of the loop (a flag set inside the game-thread callback is seen one tick later).
- `FindFirstOf` may return the class default object; for subsystems with data use `FindAllOf` and skip
  `Default__` names.
- Blueprint functions have no fixed path: resolve them from a live object's class chain (`U.hook_in_chain`).
  Hooks cannot cancel a call; they only observe.
- Setting arbitrary Lua fields on UObjects fails; keep per-object state in Lua tables keyed by `GetFullName()`.
- **Spawning bosses**: `BeginDeferredActorSpawnFromClass` + `FinishSpawningActor`; AI, health bar and music come by
  themselves. Spawned bosses have `Level = 0`; writing `Level` changes nothing, writing attributes does
  (`AttributeSetBase.X.BaseValue/CurrentValue`). The game formula is `base × (1 + curve(level))`.
- Some bosses wait at 0 HP for an execution; `actor:Kill(0)` ends them. Remove `LootComp` and set
  `bExcludeFromCodex` to stop loot, Remnant Dust and codex entries.
- Bosses whose skills look up level-placed points (Zuo Shang, Yuzan, Qishu, Du Yan, ...) teleport to (0,0,0) in
  other arenas; they are `state = "anchored"` in `roster.lua` and not offered.
- **Bell menu buttons** (`W_DialogueButton_C`): the visible label is set by `SetWidgetText`, which also plays a
  slide-in animation: call it **once**, after the button is added (calling it twice made labels jitter). Join the
  menu's `CommonButtonGroupBase` for the selected/unselected look, and relink gamepad navigation explicitly with
  `SetNavigationRuleExplicit` (the designer's Up/Down links skip inserted buttons). UMG has no `InsertChildAt`:
  remove the following children, add yours, re-add them with their slot settings.
- Cross-map travel: `PBZSaveLoadSubsystem:TeleportTo(FName("/Game/Maps/..."), transform, FName("Bell_<id>"))`.
  It saves and loads, so no separate autosave handling is needed.
- Read input with `PlayerController:IsInputKeyDown({KeyName = FName("Gamepad_FaceButton_Bottom")})`.
- Low system memory crashes the game (pagefile); it is not the mod. System settings are the user's to change.
- Do not install third-party binaries without asking the user.

## Commits

- Branch `main`, remote `origin` = github.com/continuationcs/pbrush. Commit or push only when the user asks.
- Not tracked: `dist/`, `save-backup/` (file names carry a Steam ID), `data/run*/` (raw logs).
