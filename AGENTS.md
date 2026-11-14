# AGENTS.md

Notes for coding agents working on this repository (BOSS RUSH, a UE4SS Lua mod for Phantom Blade Zero).

## Working with the user

- Talk to the user in **Chinese**; code, comments and commit messages in English.
- The user tests in game and reports back. After changing the mod, install it (`src\tools\install.ps1`) and tell the
  user exactly what to try; read `UE4SS.log` afterwards instead of asking them to copy logs.
- Decisions the user has made are recorded in `doc/DESIGN.md` (marked 用户决定 / 用户确认). Do not revert them:
  e.g. no arena choice (auto pick), no vows in Gauntlet, all open bosses offered (no defeat filter), difficulty
  follows the game setting with no extra levels, curve weight 1.0, the 万象 / Myriad (roguelike, formerly 试炼) mode hidden, no
  top-of-screen Gauntlet HUD.
- Copy style (`doc/COPY.md`): plain words; items of one kind keep the same character count (entry 4 chars,
  modes 2 chars); descriptions are two parts, one poetic line then one plain line. zh-Hans and English.
- **Point out copy mistakes in the user's requests** (user rule, 2026-11-14): when text the user asks for looks
  wrong (a wrong or look-alike character, a typo, a name that clashes with an existing one), say so and ask
  before using it, e.g. 残影试练 → 残影试炼 (练/炼), or 残影试炼 sharing 试炼 with the roguelike mode (renamed 万象). Do not
  silently copy it, and do not silently "fix" it either.
- Controller first: every new UI must be reachable and usable with a gamepad.
- Feel native: reuse the game's widgets (`W_DialogueButton`, `WB_TipsText`, `wb_settlement`), never draw custom
  UI when a game widget exists. Never write into the game save.
- The user tests in rounds ("做完一轮, 我去统一测试"): batch related changes, then give one test list. New bosses
  land as `state = "testing"` (development builds only) and become `"open"` after the user confirms in game.
- New or moved arenas: mark the spot with F2 (it surveys the spot at once), then run the arena survey
  (development build, F3), and grade them by the standard in `doc/DESIGN.md` §5.0a before offering them.
  Never take a bell's teleport point as the standing spot: the 龙柱 bell's point was a cramped nook (3/16 open,
  0 m); have the user mark one in the open ground (2026-11-14).
- **Some bells cannot be travelled to from the bell menu** (龙柱 `Bell_DP_001`, in Xigu's separate Discordance
  space), yet `PBZSaveLoadSubsystem:TeleportTo` with the bell id takes the player there and the run works. A
  boss's original battlefield in such a space is an arena of kind `own` (as 尊主封印地); to work on it, set
  `FOCUS` in `devtools.lua` (F5 goes there).
- A test round is expensive, so make one round answer the question: log each stage of a new integration (object
  found → page recognised → row added → row on screen → clicked) so the log shows where it stopped, and put a
  read-only description of what was found (names, classes, counts) in the debug log. A missing log line means
  that path never ran: check which objects actually exist before building a theory on it (the 退出挑战 entry was
  aimed at a widget the game no longer uses; one round was lost explaining its absence as "not recreated").

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
  and a tip strip tells the player. No other mod file may call `ExecuteInGameThread`, the delayed actions
  (`ExecuteInGameThreadWithDelay`, `LoopInGameThreadWithDelay`, `CancelDelayedAction`), `RegisterHook`,
  `NotifyOnNewObject`, `RegisterKeyBind` or `FindAllOf`; `LoopAsync` and `ExecuteWithDelay` are banned everywhere
  (see the gotchas). `lua_check.py` fails on either.
  Don't wrap code in `pcall` to hide errors: use it only for calls that may legitimately fail (optional
  properties, game functions missing in some states) and handle the failure. Native crashes cannot be caught
  in Lua and are not swallowed in UE4SS either (running on with corrupted memory could write a broken save):
  they are prevented by the rules under "UE4SS / game gotchas".

## Repository layout

- `src/`: everything the build uses. `src/mod/BossRush` (the mod, incl. the dev-only `devtools.lua`), `src/tools` (install, release build, generators, `lua_check.py`,
  `crash_dump.py`, `asset_scan.py`),
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

## Investigating

- **Crashes**: `python src\tools\crash_dump.py` reads the newest `ue4ss\crash_*.dmp`: exception, faulting module,
  thread name, UE4SS.dll symbol per frame (UE4SS exports its C++ API), and the strings the stack points at. That
  last part found the real cause once: "No overload found for function 'FindAllOf'". `GameThread` + frames in
  `process_lua_function` = our Lua was running. The game's own `ProjectPBZ.log` is encrypted; `PBZ.exe` is packed
  (its string literals cannot be searched). Read `UE4SS.log`.
- **Game classes**: `CXXHeaderDump\*.hpp` has native classes *and* the Blueprint classes that were loaded when
  the SDK was generated (e.g. `W_PBZSettingPanel.hpp`, `W_SettingsListEntry_Action.hpp`): reflected properties
  (readable from Lua) and functions. Not every widget layout is there; then find it at runtime.
- **Assets offline**: `python src\tools\asset_scan.py list|grep|names|deps <path part> ...` (see its docstring).
  `deps` tells whether a boss's skills look things up in the level or spawn them themselves. Names come from name
  maps: they show what an asset uses, not how it is wired, so confirm in game.
- **Which UE4SS Lua function is native code X?** UE4SS registers them as `register_function("Name", &fn)`: find
  the RIP-relative LEA of `fn` in `.text` and the string LEA next to it (done once by hand, 2026-11-13).

## Build, install, release

- `powershell -File src\tools\install.ps1 -Mods BossRush` (one mod per call; a comma list is passed as one string).
  It **wipes** the target folder: files the mod writes there (`records.tsv`, `dev.tsv`, `marks.tsv`) are lost.
- **Hot reload**: UE4SS reloads all Lua mods on **Ctrl+R** (`EnableHotReloadSystem = 1` in `UE4SS-settings.ini`),
  so after `install.ps1` the user can keep the game running. Lua has no unload callback, so whatever the old
  instance put into the game stays: reload only when no challenge is running and no bell or system menu is open
  (otherwise a spawned boss, helper points, our menu rows and the player's saved state are left behind). A new
  `loaded (...)` line in `UE4SS.log` confirms the reload. Auto-reload on file change stays off: `install.ps1`
  wipes and copies the folder, and a reload in the middle would load half the files. **Press Ctrl+R once**: the
  game crashed in the Lua VM (corrupted memory, called from a queued callback) a minute after two reloads 3 s
  apart (2026-11-13); UE4SS unregisters the old instance's hooks but the log shows nothing about its
  `NotifyOnNewObject` callbacks or loops. For a test round that must be trusted, restart the game instead.
- `python src\tools\build_release.py <version>` builds `out\BossRush-<version>.zip` with `debug = false` in the copy
  and refuses scripts that contain debug key bindings. The repo keeps `debug = true`. The version lives only in
  `Scripts/version.lua` (`"dev"` in the repo; the build writes `<version>` into the copy, and stops if it cannot);
  the result screen shows it after the entry name.
- Nexus page: mod 1099 (`doc/release/NEXUS_PAGE.md`). Updates go to the same page as a new file version. Nexus sits
  behind Cloudflare; a human check that appears must be passed by the user, never by an agent.

## No Lua interpreter here

There is no `lua`/`luac` on the machine. After editing Lua, run `python src\tools\lua_check.py` (block and
bracket balance, calls to undefined locals) and re-read the call sites: one bad edit once deleted helper
functions and the menu broke with "attempt to call a nil value". Prefer the Edit tool for Lua.

**Do not write Lua through a Bash heredoc + Python one-liner when it contains escapes** (`\t`, `\n`, `\\`): the
shell turns them into real characters. Use the Edit/Write tools, or a Python script file. The same goes for any
file whose text holds a backslash, Windows paths included: `src\tools\build_release.py` in a heredoc became a
backspace (`\b`), twice on 2026-11-14 (caught only because the replacement asserted its match).

## UE4SS / game gotchas (all learned the hard way)

- **Never use `LoopAsync` or `ExecuteWithDelay`**: their callbacks run on another thread inside the mod's Lua
  state, alongside game-thread code. With several loops running (run, menu, system-menu row, summons) the state
  got corrupted: `[Lua::Registry::get_function_ref] Ref was not function` in the log, then "attempt to call a
  table value (for iterator)" on a plain `for ... in pairs(t)`, and the mod stopped mid-challenge (2026-11-14);
  the Lua VM crash after hot reloads (2026-11-13) fits the same cause. `U.after` / `U.every` use UE4SS's delayed
  actions (`ExecuteInGameThreadWithDelay`, `LoopInGameThreadWithDelay` + `CancelDelayedAction`, integer ms),
  which run on the game thread only. A `Ref was not function` line in `UE4SS.log` means Lua state trouble.
- `FindFirstOf` may return the class default object; for subsystems with data use `FindAllOf` and skip
  `Default__` names.
- **No hooks on Blueprint functions.** UE4SS registered `W_BellMenu_C:BP_OnActivated` as a *native* hook, and
  hooks on `W_BellMenu_C:Construct` / `BP_OnActivated` were followed by three crashes within a minute. The mod
  hooks two native click handlers, `/Script/CommonUI.CommonButtonBase:HandleButtonClicked` and
  `/Script/CommonUI.CommonButtonGroupBase:OnHandleButtonBaseClicked` (in `widgets.lua`, each button routed
  through one of them); everything else is polled: menus are found with `NotifyOnNewObject` and then polled; boss and
  player deaths are polled (`IsDead`, health) in `run.lua`. Hooks cannot cancel a call anyway; they only observe.
- **Never hook a function that returns a value** (e.g. `BP_GetDesiredFocusTarget`): it crashed the game.
- **Never keep a UObject wrapper across calls** (timers, loops, click handlers, module state). A wrapper is a raw
  pointer: once the game frees the object, any call on it, `IsValid` included, reads freed memory. Four crash
  dumps (`UE4SS.dll` in `UObjectBase::GetInternalIndex`, game thread, from Lua) came from a loop that kept
  checking a closed bell menu. Keep `U.ref(obj)` instead and get the live object with `U.get(ref)` each time
  (looked up by path, so destroyed or unreachable objects are never returned). `U.valid` is only for objects
  obtained in the same call. (Found with `src\tools\crash_dump.py`, see "Investigating".)
- **Don't use arrays returned by a UFunction call** (e.g. `ListView:GetDisplayedEntryWidgets()`,
  `GetListItems()`): one read back empty, and after iterating the other UE4SS crashed natively while formatting
  a "No overload found for function 'FindAllOf'" error for a call whose argument was a string constant
  (2026-11-13). Read reflected `TArray` properties instead (`list.ListItems:ForEach`), or find objects by class
  and check their properties. Note also that a UE4SS function given a wrong argument type can crash natively
  while building its error message, so a `pcall` around it is no protection.
- **UE4SS functions that take a string** (`FindAllOf`, `StaticFindObject`, `FName` ...) must never get anything
  else: the argument check itself can crash natively. The mod calls `FindAllOf` only through `U.find_all`
  (checks the name, drops `Default__` objects; `lua_check.py` enforces it); `U.ref` / `U.get` / `U.load_class`
  check their paths.
- **An object returned by a UFunction can be null**: check it with `U.valid` before any other call. Right after the
  bell menu reactivated, `group:GetSelectedButtonBase()` returned null and `:GetFName()` on it crashed natively
  (null + 0x18, 2026-11-14); `pcall` does not catch it. `menu.lua` reads the selection only through `selected_name`.
- Reading a `TArray` property: `arr:ForEach(function(i, e) local obj = e:get() end)`.
- **Out parameters**: pass a Lua table, UE4SS fills it (`nav:K2_ProjectPointToNavigation(world, p, out, nil,
  nil, extent)` then `out.X`; `GetJhsyBellTeleportTransform(out, cam)` then `out.Translation`).
- **Navigation works from Lua**: `/Script/NavigationSystem.Default__NavigationSystemV1` →
  `K2_ProjectPointToNavigation`, `FindPathToLocationSynchronously(world, from, to, nil, nil)` →
  `path:IsValid()`, `IsPartial()`, `GetPathLength()`. `run.lua` uses them to spawn bosses where the player can
  walk to; spawn with `ESpawnActorCollisionHandlingMethod` 2 (move out of overlaps, always spawn).
- **Text language**: read it when the text is shown (`i18n.zh()`), never at load: the game applies its own
  language setting (`GameUserSettings.ini` `CultureName`) after mods load, so a value read at load is the
  system language (an English game showed 强敌挑战).
- Setting arbitrary Lua fields on UObjects fails; keep per-object state in Lua tables keyed by `GetFullName()`.
- **Spawning bosses**: `BeginDeferredActorSpawnFromClass` + `FinishSpawningActor`; AI, health bar and music come by
  themselves. Spawned bosses have `Level = 0`; writing `Level` changes nothing, writing attributes does
  (`AttributeSetBase.X.BaseValue/CurrentValue`). The game formula is `base × (1 + curve(level))`.
  Scale a stat's current value with its maximum when the boss starts full (Health, Sha-Chi): scaling only
  `Shachi_Max` left the boss's Sha-Chi gauge at 1/12 (player report, 0.1.4).
- **Playthroughs (周目)**: the monster curves (`CV_AttributeCurve_Monster_*`, read offline) run past level 25
  (Health to 500, Attack and Shachi to 200) and repeat their shape every 25 levels, so each playthrough adds 25
  levels; `scale.lua` uses progress + 25 × `PBZGameSystem.CycleCount`, capped at 200 (2026-11-14, after a player
  saw 二周目 bosses at 25W health where the mod's had 15W). Inferred from the curves: confirm with a 二周目 save
  (the development log lists nearby native monsters' levels). The difficulty configs' Global Mob Level Offset is 0
  except Handicapped (-1).
- Some bosses wait at 0 HP for an execution; `actor:Kill(0)` ends them (`run.lua` forces it after 0.8 s at 0 HP
  when the game does not report the boss dead). Remove `LootComp` and set
  `bExcludeFromCodex` to stop loot, Remnant Dust and codex entries.
- Bosses whose skills look up level-placed points (Zuo Shang, Yuzan, Qishu, Du Yan, ...) teleport to (0,0,0) in
  other arenas, or take the player to their own level (Yubi). They are offered with **补点**: roster `helpers`
  (`src/tools/gen_roster.py`): the run spawns the same marker classes in the arena before the boss and destroys
  them after (`run.lua` `place_helpers`). Works when the markers are root-only actors (eleven bosses confirmed
  2026-11-13). The log counts original markers still loaded nearby: a skill taking the nearest or the first one
  may pick those. The rest are `state = "anchored"` and not offered. (Fighting them at their original arena,
  "原址", was removed: the points can sit in interior spaces, and one put the player inside a building.)
  Lookups come in two kinds: `GetActorOfClass` and the **targeting subsystem** (markers call `RegisterTarget` on
  BeginPlay, skills call `GetTargets` / `FindNearestActor`). The first scan only knew the first kind and marked
  Yubi safe. Don't confuse a class named next to `BeginDeferredActorSpawnFromClass` (the skill spawns it, no
  dependency: 魔渊's pillars, 舞狮尊主's poles) with a lookup.
  A third kind: **identity points** by gameplay tag. Level points (`BP_SGameAITargetPoint`, class in the SGameAI
  plugin: `/SGameAI/Tools/Teleport/...`) register a `USGameAIIdentityComponent` with
  `USGameAIWorldSubsystem.Identities`; the action `GAA_AssignIdentityTransformToBlackboard` (property
  `IdentityTag`) looks one up. Missing, it yields the zero transform: 追命's second phase was moved to 0,0,0
  hidden and fell out of the world. The tag is in the action's instance data, not in the asset's name map
  (read it at runtime: the actions are templates inside the ability's class default, `U.find_all(cls, true)`).
  `run.lua` `place_identity_points` registers a point for every such tag the level lacks (confirmed 2026-11-14).
- **Scale a boss's summons with it**: the game sizes some summon values from the boss's. 舞狮尊主's last lion
  head gets a health floor of 1% of the boss's `Health_Max`; with only the boss scaled (x18.51) the floor
  (1851) was above the head's maximum (500), so it could not be hurt or executed (2026-11-13). Roster `summons`
  lists such classes: the run scales each one like the boss (`scale.apply`), forces its `Kill` when it waits at
  0 HP for an execution, and logs its state (0 / hurt / full; attributes in the development log). Other bosses'
  summons are not scaled.
- **Bell menu buttons** (`W_DialogueButton_C`): the visible label is set by `SetWidgetText`, which also plays a
  slide-in animation: call it **once**, after the button is added (calling it twice made labels jitter). Join the
  menu's `CommonButtonGroupBase` for the selected/unselected look, and relink gamepad navigation explicitly with
  `SetNavigationRuleExplicit` (the designer's Up/Down links skip inserted buttons).
- **Bell menu insertion** (残影试炼, formerly 强敌挑战, right below 穿行, user decision): every open creates a new `W_BellMenu_C`.
  `NotifyOnNewObject` + a 30 ms poll inserts the entry as soon as `TeleportBtn` exists, before the menu is drawn
  (a late insertion flickered and reset a selection the player had already made). Insertion = take out the
  options after 穿行, add ours, put them back (`widgets.insert`); then call `UpdateButtonStyle()` /
  `DoSelectedAppearance(false)` on the moved options. (A test where 穿行 and other options were missing turned
  out to be a save that had reset to the start of the game, not the insertion.)
- **The bell menu's script rewrites gamepad navigation** whenever the menu activates (opening, coming back from
  穿行 / 能力修行 ...), which cut our entry out of the Up/Down chain. While the menu lives, `menu.lua` relinks the
  visible column every 250 ms (links only: no selection, focus or style changes).
- **It also makes a new button group on each reactivation**, holding only its own 8 buttons (log 2026-11-14:
  `group new, entry index -1`). Our entry, left outside, stayed selected (bold) once the cursor passed it, and
  its clicks (routed through the group) would be lost. `menu.lua` watches `IsActivated()` and on each return
  re-finds the group through 穿行, adds the entry back (undoing the auto-selection only if the group had none),
  clears a stale selection, then refreshes the entry's style (`UpdateButtonStyle`, unselected look).
- **Joining the bell menu's button group makes the inserted button the selected one**, and the menu's script then
  turns every confirm press into 穿行 (Traverse). After inserting, select `TeleportBtn` again
  (`group:SelectButtonAtIndex(group:FindButtonIndex(menu.TeleportBtn), false)`) and give it focus. Options that
  were removed and re-added come back with a stale text size: call `UpdateButtonStyle()` and
  `DoSelectedAppearance(false)` on them. (Found only in the release test with the confirm key; mouse clicks hid it.)
- **`WB_GameMenuV1_C` is not the game's system menu**: no instance exists during play (2026-11-13), so an entry
  aimed at it never appeared. The menu the player opens is a tabbed screen; its 系统 → 退出游戏 page is
  `W_PBZSettingPanel_C` (a `UGameSettingPanel`): rows are `UGameSettingAction` items in a `UGameSettingListView`
  (entry widget `W_SettingsListEntry_Action_C`), and the panel's `ExecuteAction(setting, ActionTag)` handles
  `UI.Setting.Exit.LoadGame / ReturnToStart / ExitGame`. Page = `panel.CurrentCollection:GetDevName()`:
  `GameplayCollection`, `Video`, `ControlSettings`, `HelpCollection`, `ExitCollection` (rows `LoadGame`,
  `ReturnToStart`, `ReturnToDesktop`). The list is rebuilt each time a page is shown. A `UGameSettingAction` made
  with `StaticConstructObject(class, panel)` and `ListView_Settings:AddItem` shows as a row with **empty text**
  (its display name is not reflected): label the row's entry widget (`SettingName`), found by class with its
  reflected `Setting` property.
- **Back key in the bell menu** closes the whole menu (`W_BellMenu_C` handles it in `HandleOverrideBackInputAction`).
  The game's own `UPBZActivatableWidget:ClearBackKey()` / `BindBackKey()` take that binding off and put it back
  (confirmed: with it cleared, Esc did nothing). `menu.lua` clears it while our pages are up and gives each
  page's 返回 row the back input action (`CommonButtonBase:SetTriggeringInputAction` /
  `SetTriggeringEnhancedInputAction`, taken from the menu's `CloseBtn` or `OverrideBackInputActionData_*`), so the
  key clicks that row; it binds the menu's key again when the menu's own options come back.
- **A triggering input action bypasses `HandleButtonClicked` hooks**: CommonUI calls `HandleButtonClicked()`
  directly in C++ for it, while mouse and confirm reach it through the Slate button's dynamic delegate (a
  UFunction call UE4SS sees). In game the back key only turned the 返回 row selected (2026-11-13). Selection is
  no signal of a click either: in the bell menu a button is selected as soon as it gets focus (polling
  `GetSelected()` made moving the cursor onto 返回 go back). What sees every click is the button group's
  `OnHandleButtonBaseClicked`, bound to the button's dynamic `OnButtonBaseClicked`: buttons in a group are routed
  through that hook, others (the settings panel row) through `HandleButtonClicked`.
- **Boss names come from the codex, and its class mapping can be wrong**: `bosses.json` (pbzero, from
  `DT_CodexEnemyDataTable`) gave 七星剑阵：大师兄 to `EMei_Sword_JianZhen`, which in game is a 红衣女剑客 (its health
  bar says so); one codex entry can hold several parts (`BossName_013_0/1/2`) and the row does not name each part's
  class. When a boss looks wrong, ask what its **health bar** says. `gen_roster.py` fixes records with `CLASS_FIX`
  and adds codex bosses missing from `bosses.json` with `EXTRA`; a guessed class lands as `testing` until the user
  confirms it (2026-11-14). The game's display texts (names in English, difficulty names) are in the encrypted
  pak's locres: not readable offline; ask the user for the in-game text.
- **A layout read from a screenshot must be checked slot by slot**: the probe's `wb_settlement` preview labelled
  only the blocks that are properties; the big title block (`CommonTextBlock_64`) is not one, so the screenshot
  showed its default text 敬请期待 and it was taken for the title slot without its name ever appearing. The result
  screen showed 敬请期待 as its title from 0.1.0 until 2026-11-14, and `GetWidgetFromName` did not reach it either.
  `settle.lua` finds it among the live `CommonTextBlock`s by its path inside the screen and logs what it reads back.
- **Values from the game may be unknown**: `U.game_difficulty()` returns -1 when the difficulty cannot be read
  (never a guessed level), and `i18n.difficulty` shows "—" for any value outside the user-given list; nothing that
  formats or looks up such a value may raise.
- **With a menu open the game is in UI-only input**: `PlayerController:IsInputKeyDown` sees no key (polling Esc /
  gamepad B in the bell menu read nothing). Read keys that way only in gameplay (the result screen does).
- Most of the bell menu's logic lives in the game's TypeScript layer (puerts mixins), invisible to UE4SS hooks.
- Test menus with the confirm key and the gamepad, not only the mouse.
- **Arrival is not the end of loading**: the player stands at the destination while the loading screen is still
  up, so a boss spawned then attacks as it lifts (2026-11-13). A bell teleport blocks the game thread (~11 s, no
  tick runs), then shows `WB_AdditionalLoading_C` (~4 s, `IsActivated()` while up): `run.lua` waits for it, then
  gives the player `GRACE_MS`. `IsLoadingLevel`, `IsDestinationLoadingActive` and `WB_TempLoadingScreen_C` never
  changed (found by logging every candidate on each change, 2026-11-14).
- **A health floor above 0 makes a boss unkillable**: in a player's 二周目 魔渊 spawned with `Health_Min` 24 (of
  12000), stopped there with `IsDead` false, and a forced `Kill` at 24 left it attacking through the result
  screen. Setting `Health_Min` to 0 lets it die normally (roster `clear_health_min`; Nexus report by mastersoul2,
  confirmed with the 0.1.5 release build 2026-11-14). Each boss's `Health_Min` at spawn is in the development log:
  look there when a boss will not die. Not every floor is a bug: a lock that ends in an execution
  (`GE_LockHealthButCanExecuted`, 舞狮尊主's last lion head) is the fight's mechanic.
- **Player deaths in the Realm of Mirage are not seen yet**: the game sends the player out at once, `IsDead` is
  never read true and the run ends as 收刃离去 instead of 饮恨 (Nexus report by mastersoul2). Hooks on the revive
  handlers (`PBZPlayerReviveSubsystem:PBZOnPlayerRevived`, `PBZJhsyReturnStreamingSubsystem:HandlePlayerRevived`)
  did not fix it in the 0.1.5 release test (2026-11-14): follow up with the development build's log (which hook
  fired, the player's health before leaving).
- **Never read a dying actor's attributes**: the game crashed natively while a lion head dissolved, right after the
  run started reading every summon's health before checking `IsDead` (2026-11-13). Check `IsDead` first.
- Cross-map travel: `PBZSaveLoadSubsystem:TeleportTo(FName("/Game/Maps/..."), transform, FName("Bell_<id>"))`.
  It saves and loads, so no separate autosave handling is needed.
- **Leaving the Realm of Mirage** (`TeleportToBellFromJhsy`) lands at the bell it was *entered from*, which is not
  always the run's starting bell: after a run moved there from an occupied arena it landed at that arena's bell,
  the return wait timed out and the player's state was never restored (2026-11-14). `go_home` makes a second trip
  once out, and restores the state even when the return times out. Never end a run without `restore`.
- **In a new playthrough (二周目) a boss not yet beaten there stands at its own battlefield**: 彭猛 at 斧老大斩落处
  made a second 彭猛 in the fight (2026-11-14). On arrival `run.lua` looks for living roster bosses within 60 m;
  a scenic arena is swapped (then the Realm of Mirage), an own arena ends the run with a notice. Bells also reset
  in a new playthrough, so few scenic arenas are offered early on.
- Read input with `PlayerController:IsInputKeyDown({KeyName = FName("Gamepad_FaceButton_Bottom")})`.
- Development keys (`devtools.lua`, development builds only; user decisions 2026-11-14): **single keys only, no
  combinations**: F1 god mode, F2 mark a spot for a new arena and survey it right there (grades on screen), F3
  arena survey (only the `FOCUS` arena when `devtools.lua` sets one), F4 forced error, F5 go to the `FOCUS` arena
  (for an arena whose bell the bell menu cannot reach). The discovery probe mod was retired (git history has it;
  UE4SS's own keybinds dump the CXX headers). **Never bind F10, F11 or F12**: F10 opens the UE4SS console
  (ConsoleEnablerMod), F11 is the game's (user report), F12 is Steam's screenshot. A new tool takes the next free
  F key (F6-F9); UE4SS's own keys all use Ctrl.
  Anything a dev tool changes in the game must survive a hot reload: god mode keeps the player's own values in a
  file (`%TEMP%\BossRush_god_base.tsv`) and the next load restores them; kept only in memory, each reload took
  the boosted values as the originals (player health 3085 -> 30,855,000, 2026-11-14).
- Low system memory crashes the game (pagefile); it is not the mod. System settings are the user's to change.
- Do not install third-party binaries without asking the user.

## Commits

- Branch `main`, remote `origin` = github.com/continuationcs/pbrush. Commit or push only when the user asks.
- **Every commit carries its lessons** (user rule, 2026-11-14): before committing, write what the work taught
  (causes found, wrong assumptions, how something was confirmed) into `AGENTS.md` (gotchas, rules) and the decisions
  and results into `doc/DESIGN.md` / `doc/COPY.md`, and commit them together with the code.
- Another session may have uncommitted work in the same files: stage only this work's hunks (e.g. `git
  hash-object -w` of a file built from HEAD plus this work's edits, then `git update-index --cacheinfo`).
- Not tracked: `out/`, `save-backup/` (personal save backups; file names carry a Steam ID), `src/data/run*/`
  (raw logs).
