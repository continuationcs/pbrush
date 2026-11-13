# AGENTS.md

Notes for coding agents working on this repository (BOSS RUSH, a UE4SS Lua mod for Phantom Blade Zero).

## Working with the user

- Talk to the user in **Chinese**; code, comments and commit messages in English.
- The user tests in game and reports back. After changing the mod, install it (`src\tools\install.ps1`) and tell the
  user exactly what to try; read `UE4SS.log` afterwards instead of asking them to copy logs.
- Decisions the user has made are recorded in `doc/DESIGN.md` (marked 用户决定 / 用户确认). Do not revert them:
  e.g. no arena choice (auto pick), no vows in Gauntlet, all open bosses offered (no defeat filter), difficulty
  follows the game setting with no extra levels, curve weight 1.0, the Trial (roguelike) mode hidden, no
  top-of-screen Gauntlet HUD.
- Copy style (`doc/COPY.md`): plain words; items of one kind keep the same character count (entry 4 chars,
  modes 2 chars); descriptions are two parts, one poetic line then one plain line. zh-Hans and English.
- Controller first: every new UI must be reachable and usable with a gamepad.
- Feel native: reuse the game's widgets (`W_DialogueButton`, `WB_TipsText`, `wb_settlement`), never draw custom
  UI when a game widget exists. Never write into the game save.

## Code health (user rule)

- No latent hazards and no hacks. Fix causes, not symptoms: no timing guesses that only happen to work (delays
  picked until a bug went away, time-based de-duplication), no hooks or writes whose side effects are unknown,
  no workarounds left in place after the cause is found. When the game forces a workaround (e.g. its menu script
  rewriting navigation), keep it minimal, explain the cause in a comment and record it below.
- Keep the code healthy for the long term: delete dead code and unused files instead of keeping them "for later"
  (git history has them), one helper per job shared across modules (`widgets.lua`, `util.lua`), no duplicated
  logic, names and comments that say why. Leave the code cleaner than you found it.
- Debug and development code stays out of the release (`build_release.py` excludes it and checks for it).
- **Errors stop the mod, never the game.** Every call from the game into the mod goes through `util.lua`:
  `U.after`, `U.every` (loops; return true to stop), `U.on_new`, `U.hook`, `U.key`. They run mod code on the game
  thread and catch every Lua error: it is logged with its traceback, the mod turns itself off (`U.failed()`,
  `U.on_fail` handlers clean up: the bell entry is removed, a running challenge ends and the player is sent home)
  and a tip strip tells the player. No other mod file may call `LoopAsync`, `ExecuteWithDelay`,
  `ExecuteInGameThread`, `RegisterHook`, `NotifyOnNewObject` or `RegisterKeyBind`; `lua_check.py` fails if one does.
  Don't wrap code in `pcall` to hide errors: use it only for calls that may legitimately fail (optional
  properties, game functions missing in some states) and handle the failure. Native crashes cannot be caught
  in Lua and are not swallowed in UE4SS either (running on with corrupted memory could write a broken save):
  they are prevented by the rules under "UE4SS / game gotchas".

## Repository layout

- `src/`: everything the build uses. `src/mod/BossRush` (the mod, incl. the dev-only `autotest.lua`),
  `src/probe/BossRushProbe` (dev probe), `src/tools` (install, release build, generators, `lua_check.py`),
  `src/data` (bell and arena tables, test results), `src/ue4ss` (UE4SS layout and signatures for this game
  build), `src/vendor` (third-party files).
- `doc/`: design (`DESIGN.md`), text (`COPY.md`), release texts and images (`doc/release`).
- `out/`: build output (not tracked). `README.md` and `AGENTS.md` stay at the root, where GitHub and coding
  agents look for them.

## Paths

- Game: `G:\G\Steam\steamapps\common\PBZ`; UE4SS: `...\platform\steam\ue4ss` (log `UE4SS.log`,
  header dump `CXXHeaderDump\`, mods `Mods\`).
- Game assets can be read offline with the `pbzero` package (`F:\C\pbzero\src`, `IoStore` + `Oodle` over
  `ProjectPBZ\Content\Paks\ProjectPBZ-Windows.utoc`); see `src/tools/gen_roster.py` for the import pattern.

## Build, install, release

- `powershell -File src\tools\install.ps1 -Mods BossRush` (one mod per call; a comma list is passed as one string).
  It **wipes** the target folder: the probe's `sdk_done.txt` and `arenas.tsv` must be restored after installing
  the probe (`echo 1 > ...\BossRushProbe\sdk_done.txt`, copy `src\data\run11\arenas.tsv` back).
- `python src\tools\build_release.py <version>` builds `out\BossRush-<version>.zip` with `debug = false` in the copy
  and refuses scripts that contain debug key bindings. The repo keeps `debug = true`.
- Nexus page: mod 1099 (`doc/release/NEXUS_PAGE.md`). Updates go to the same page as a new file version. Nexus sits
  behind Cloudflare; a human check that appears must be passed by the user, never by an agent.

## No Lua interpreter here

There is no `lua`/`luac` on the machine. After editing Lua, run `python src\tools\lua_check.py` (block and
bracket balance, calls to undefined locals) and re-read the call sites: one bad edit once deleted helper
functions and the menu broke with "attempt to call a nil value". Prefer the Edit tool for Lua.

**Do not write Lua through a Bash heredoc + Python one-liner when it contains escapes** (`\t`, `\n`, `\\`): the
shell turns them into real characters. Use the Edit/Write tools, or a Python script file.

## UE4SS / game gotchas (all learned the hard way)

- `ExecuteWithDelay` needs an **integer** ms (`math.floor`), or it errors.
- `LoopAsync` callbacks run off the game thread: do game work inside `ExecuteInGameThread`, and keep loop state in
  upvalues checked at the top of the loop (a flag set inside the game-thread callback is seen one tick later).
- `FindFirstOf` may return the class default object; for subsystems with data use `FindAllOf` and skip
  `Default__` names.
- **No hooks on Blueprint functions.** UE4SS registered `W_BellMenu_C:BP_OnActivated` as a *native* hook, and
  hooks on `W_BellMenu_C:Construct` / `BP_OnActivated` were followed by three crashes within a minute. The mod
  hooks exactly one function, the native `/Script/CommonUI.CommonButtonBase:HandleButtonClicked` (in
  `widgets.lua`); everything else is polled: menus are found with `NotifyOnNewObject` and then polled; boss and
  player deaths are polled (`IsDead`, health) in `run.lua`. Hooks cannot cancel a call anyway; they only observe.
- **Never hook a function that returns a value** (e.g. `BP_GetDesiredFocusTarget`): it crashed the game.
- **Never keep a UObject wrapper across calls** (timers, loops, click handlers, module state). A wrapper is a raw
  pointer: once the game frees the object, any call on it, `IsValid` included, reads freed memory. Four crash
  dumps (`UE4SS.dll` in `UObjectBase::GetInternalIndex`, game thread, from Lua) came from a loop that kept
  checking a closed bell menu. Keep `U.ref(obj)` instead and get the live object with `U.get(ref)` each time
  (looked up by path, so destroyed or unreachable objects are never returned). `U.valid` is only for objects
  obtained in the same call. Crash dumps (`ue4ss\crash_*.dmp`) can be read without a debugger: exception record,
  module list and UE4SS's exported symbols (`UE4SS.dll` exports its C++ API) locate the fault.
- Setting arbitrary Lua fields on UObjects fails; keep per-object state in Lua tables keyed by `GetFullName()`.
- **Spawning bosses**: `BeginDeferredActorSpawnFromClass` + `FinishSpawningActor`; AI, health bar and music come by
  themselves. Spawned bosses have `Level = 0`; writing `Level` changes nothing, writing attributes does
  (`AttributeSetBase.X.BaseValue/CurrentValue`). The game formula is `base × (1 + curve(level))`.
- Some bosses wait at 0 HP for an execution; `actor:Kill(0)` ends them (`run.lua` forces it after 0.8 s at 0 HP
  when the game does not report the boss dead). Remove `LootComp` and set
  `bExcludeFromCodex` to stop loot, Remnant Dust and codex entries.
- Bosses whose skills look up level-placed points (Zuo Shang, Yuzan, Qishu, Du Yan, ...) teleport to (0,0,0) in
  other arenas. Those whose original arena is still reachable are `state = "origin"` (单挑 only, fought at their
  original arena, `origins.lua` from `src/tools/origin_arenas.py`); the rest are `state = "anchored"` and not offered.
- **Bell menu buttons** (`W_DialogueButton_C`): the visible label is set by `SetWidgetText`, which also plays a
  slide-in animation: call it **once**, after the button is added (calling it twice made labels jitter). Join the
  menu's `CommonButtonGroupBase` for the selected/unselected look, and relink gamepad navigation explicitly with
  `SetNavigationRuleExplicit` (the designer's Up/Down links skip inserted buttons).
- **Bell menu insertion** (强敌挑战 right below 穿行, user decision): every open creates a new `W_BellMenu_C`.
  `NotifyOnNewObject` + a 30 ms poll inserts the entry as soon as `TeleportBtn` exists, before the menu is drawn
  (a late insertion flickered and reset a selection the player had already made). Insertion = take out the
  options after 穿行, add ours, put them back (`widgets.insert`); then call `UpdateButtonStyle()` /
  `DoSelectedAppearance(false)` on the moved options. (A test where 穿行 and other options were missing turned
  out to be a save that had reset to the start of the game, not the insertion.)
- **The bell menu's script rewrites gamepad navigation** whenever the menu activates (opening, coming back from
  穿行 / 能力修行 ...), which cut our entry out of the Up/Down chain. While the menu lives, `menu.lua` relinks the
  visible column every 250 ms (links only: no selection, focus or style changes).
- **Joining the bell menu's button group makes the inserted button the selected one**, and the menu's script then
  turns every confirm press into 穿行 (Traverse). After inserting, select `TeleportBtn` again
  (`group:SelectButtonAtIndex(group:FindButtonIndex(menu.TeleportBtn), false)`) and give it focus. Options that
  were removed and re-added come back with a stale text size: call `UpdateButtonStyle()` and
  `DoSelectedAppearance(false)` on them. (Found only in the release test with the confirm key; mouse clicks hid it.)
- Most of the bell menu's logic lives in the game's TypeScript layer (puerts mixins), invisible to UE4SS hooks.
- Test menus with the confirm key and the gamepad, not only the mouse.
- Cross-map travel: `PBZSaveLoadSubsystem:TeleportTo(FName("/Game/Maps/..."), transform, FName("Bell_<id>"))`.
  It saves and loads, so no separate autosave handling is needed.
- Read input with `PlayerController:IsInputKeyDown({KeyName = FName("Gamepad_FaceButton_Bottom")})`.
- Development keys: the probe uses F1–F10, the autotest F12 (run) and Ctrl+F12 (forced error). **Never bind F11**:
  the game uses it (user report). Pick new keys with a modifier on an existing F key rather than a free letter.
- Low system memory crashes the game (pagefile); it is not the mod. System settings are the user's to change.
- Do not install third-party binaries without asking the user.

## Commits

- Branch `main`, remote `origin` = github.com/continuationcs/pbrush. Commit or push only when the user asks.
- Not tracked: `out/`, `save-backup/` (personal save backups; file names carry a Steam ID), `src/data/run*/`
  (raw logs).
