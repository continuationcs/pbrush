# AGENTS.md

Notes for coding agents working on this repository (BOSS RUSH, a UE4SS Lua mod for Phantom Blade Zero).

## Working with the user

- Talk to the user in **Chinese**; code, comments and commit messages in English.
- The user tests in game and reports back. After changing the mod, install it (`src\tools\install.ps1`) and tell the
  user exactly what to try; read `UE4SS.log` afterwards instead of asking them to copy logs.
- Decisions the user has made are recorded in `doc/DESIGN.md` (marked 用户决定 / 用户确认). Do not revert them:
  e.g. no arena choice (auto pick), no vows in Gauntlet, all open bosses offered (no defeat filter), difficulty
  follows the game setting with no extra levels, curve weight 1.0, harder fights only through the 敌方 · 强度 tiers
  (一重～五重 multipliers on the 残影试炼 → 设置 page, DESIGN §5.3a), the 万象 / Myriad (roguelike, formerly 试炼) mode hidden, no
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
  0 m); have the user mark one in the open ground (2026-11-14). A spot under 12 m from the nearest bell grades 差
  (user decision 2026-11-15: no fight right next to a bell); the survey logs the distance. Runs that start at a
  bell (in place, Realm of Mirage) move the player onto the spot behind a camera fade (`run.lua` `place_player`).
- **Some bells cannot be travelled to from the bell menu** (龙柱 `Bell_DP_001`, in Xigu's separate Discordance
  space), yet `PBZSaveLoadSubsystem:TeleportTo` with the bell id takes the player there and the run works. A
  boss's original battlefield in such a space is an arena of kind `own` (as 尊主封印地); to work on it, set
  `FOCUS` in `devtools.lua` (F5 goes there).
- **`TeleportTo`'s bell argument becomes the player's bell**: deaths revive there and the save points at it. Only
  travel with a bell rung in this playthrough (`U.active_bells()`): a player in a new playthrough (龙柱 not rung)
  died at 龙柱, was revived inside the arena, the game crashed (GPU device removed) on the next teleport and the
  save was left at `Bell_DP_001` (Nexus report by mastersoul2 on 0.1.5; crash not reproduced, cause inferred).
  `arenas.pick` now checks own battlefields' bells too; one marked `bound` (舞狮尊主) is not fought while unrung.
  The same holds for a 连战 group's arena (`gauntlets.lua` `arena`, DESIGN §5.0b): a group goes to its own boss's
  battlefield or its arena only while that bell is rung, and a `bound` boss is left out of the run otherwise; an
  own battlefield used as another group's arena (鬼差夜巡 at 尊主封印地) is swapped like a scenic one when a native
  boss holds it, not ended.
  Confirmed 2026-11-15: with 龙柱 rung, a death there ends as 饮恨 and the player gets home without a crash; with a
  二周目 save (both bells unrung) 金面具黑衣人 went to the Realm of Mirage, a death there ended as 饮恨 and the
  player got home, and 舞狮尊主 was refused with the notice. Bells reset in a new playthrough: an arena or a
  travel target that worked in the first playthrough may be unrung in the next one.
- **Game updates and DLC**: the plan is `doc/UPDATE.md`. The start-up check (`health.lua`) looks up, by name,
  every game class, function and property the mod uses, and the bosses' classes, helper points and arena maps (in
  the asset registry, never loaded): a missing core part stops the mod with a notice, a missing boss or map leaves
  out that one. **A new call on a game class goes into its lists** (`NATIVE`, `WIDGETS`, `OPTIONAL_ASSETS`), names
  checked against `CXXHeaderDump`: a wrong name there stops the mod for every player. Update `TESTED_BUILD` (Steam
  buildid) with each release. Development keys F7 / F8 show what a missing boss / core part does.
  The asset registry singleton is the class default object `/Script/AssetRegistry.Default__AssetRegistryImpl`
  (`U.find_all` skips defaults and found nothing); `K2_GetAssetByObjectPath` works from Lua and is calibrated with a
  known, a made-up and the current map's path (confirmed 2026-11-16: 117 lookups, nothing loaded). An asset path
  given to it must carry the mount: `asset_scan.py list` prints paths without it, and a plugin's content mounts at
  `/<Plugin>/` (`ProjectPBZ/Plugins/Secret/PBZCombatAsset/Content/Prototypes/...` is
  `/PBZCombatAsset/Prototypes/...`, not `/Game/...`): the check reported the identity action missing until fixed.
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
- **Which map a boss is on** (how the 千影 stages were made, 2026-11-15): search every map's World Partition cells
  (`Maps/*/_Generated_/*.umap`, ~100k packages, a few minutes) for `BP_Monster_<id>_C`; bosses spawned by the level
  itself are not in any cell but in the persistent map (`PBZ_*_WP.umap`; `asset_scan.py maps`). Ignore
  `Maps/Performance/PSOCombat` (shader warm-up, names every boss). A boss found on several maps (残钢, 玉妖, 金面
  ...) or in codex order away from its map (寒岁, 风雪刀客) needs a human decision: the codex order is the order the
  player meets them, so maps visited twice (正道大营, 庞镇) show up as two runs of it.
- **Which UE4SS Lua function is native code X?** UE4SS registers them as `register_function("Name", &fn)`: find
  the RIP-relative LEA of `fn` in `.text` and the string LEA next to it (done once by hand, 2026-11-13).

## Build, install, release

- `powershell -File src\tools\install.ps1 -Mods BossRush` (one mod per call; a comma list is passed as one string).
  It **wipes** the target folder: files the mod writes there (`records.tsv`, `settings.tsv`, `dev.tsv`, `marks.tsv`) are lost.
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
- **Spawning bosses**: `BeginDeferredActorSpawnFromClass` + `FinishSpawningActor`; AI and health bar come by
  themselves, and music for most bosses. Not for all: 金面具黑衣人 / 魔渊 had no music in a random arena (Nexus
  report by townnet on 0.1.4) but do at their own battlefield 龙柱 (user test 2026-11-14), so their music seems
  tied to the level. When a player reports a silent fight, check whether that boss has music at its own
  battlefield. Spawned bosses have `Level = 0`; writing `Level` changes nothing, writing attributes does
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
  **Check that a "level object" is in the level**: 龙体左殇 was closed for its dragon pillars, taken to be placed in
  the level, but no map package holds one (`asset_scan.py maps BP_ZuoShang_P2_DragonPillar`, all 80974 .umap):
  the boss blueprint prepares, throws and cancels them itself (2026-11-15). The other commands read only .uasset.
  `maps` also shows where a boss's spawner is (the persistent level names `BP_AISpawner_C_<boss class>`) and
  which bosses share a fight: 龙体左殇's spawner sits next to the silver-haired 左殇's in `PBZ_Duanhun_WP`.
  **`bosses.json` can name a stand-in class**: 荡秽 was `BP_Monster_Danghui_StuntDouble`; `BP_Monster_Danghui` is
  used instead (`CLASS_FIX`, 2026-11-15): the level's spawner cell (Zhengdaodaying `4DYOM2…`) names
  `BP_Monster_Danghui_C`; the stand-in appears only in `Maps/Performance/PSOCombat` (shader warm-up).
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
  confirmed with the 0.1.5 release build 2026-11-14). A story fight can set it too: 组织冥主：左殇 (black-haired)
  gets `Health_Min` 6400, 4800, then 3200 (80 / 60 / 40% of its base 8000) as its scripted fight goes on: it could
  not be killed until the run cleared each one as it came (checked every tick, 2026-11-15). 悲痛欲绝的阿瑾 read 0
  at spawn and was locked later by its passive (`GE_LockHealth`, tied to its red troop's soldiers dying, found
  offline in the passive's name map): a floor at spawn is not the whole story. Cleared, it fell to 0 and the
  forced `Kill` ended it (confirmed 2026-11-15; the floor showed in the base value while the current read 0, so
  check both). The run now logs any boss's
  `Health_Min` that rises during a fight, flagged or not. Each boss's
  `Health_Min` at spawn is in the development log:
  look there when a boss will not die. Not every floor is a bug: a lock that ends in an execution
  (`GE_LockHealthButCanExecuted`, 舞狮尊主's last lion head) is the fight's mechanic. A current `Health_Min` of 1
  with base 0 near the end (毕峰, 风雪刀客, 2026-11-15) is such an execution lock: the forced `Kill` ends it.
- **Player deaths in the Realm of Mirage were not seen** (fixed 2026-11-15): the game sends the player out at once, `IsDead` is
  never read true and the run ends as 收刃离去 instead of 饮恨 (Nexus report by mastersoul2). Hooks on the revive
  handlers (`PBZPlayerReviveSubsystem:PBZOnPlayerRevived`, `PBZJhsyReturnStreamingSubsystem:HandlePlayerRevived`)
  did not fix it in the 0.1.5 release test (2026-11-14). The first never existed: `PBZOnPlayerRevived` sits under
  the `OnPlayerRevived` property in the header dump because the dumper prints a delegate's signature there, and
  RegisterHook found no such UFunction (the log said so at every load). The same blind spot hit a normal arena
  next to a bell (2026-11-15): the player died, stood up again at the bell inside the arena and fought on. The
  run now reads the game's death counter `PBZGameSystem.DiedTimes` (`U.game_system`) against its value at the
  start: confirmed at a normal arena and in the Realm of Mirage (2026-11-15, `player died (death counter)`, 饮恨;
  devtools F6 sends every run there). The Mirage revive handler fired too, 6 s after the counter, so it was
  dropped. **A function listed right under a delegate property in the header dump is that delegate's signature,
  not a hookable function.**
- **An attribute that reads 0 has no effect to scale**: `ShachiRegen` read 0 on every boss and summon tested (five
  classes, 2026-11-15), so the tiers' Sha-Chi regeneration factor changed nothing and was removed. Before a new
  attribute goes into a tier or modifier, log its value at spawn on a few bosses and check it is the one the game
  actually uses. Its values also tell its meaning: `BreakDurationAdditionalMultiplier` read 0 on most bosses and
  -0.25 on 舞狮尊主's second phase, so it is a term added to 1, not a multiplier.
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
  (for an arena whose bell the bell menu cannot reach), F6 every run in the Realm of Mirage on / off (it is
  otherwise only the fallback when no arena is available), F7 treat the first open boss as missing from the game, F8 run the start-up
  check again with a made-up core part missing (the mod stops). The discovery probe mod was retired (git history has it;
  UE4SS's own keybinds dump the CXX headers). **Never bind F10, F11 or F12**: F10 opens the UE4SS console
  (ConsoleEnablerMod), F11 is the game's (user report), F12 is Steam's screenshot. A new tool takes the next free
  F key (F9; F7-F9 had picked the entrance effects and were removed once chosen, 2026-11-15); UE4SS's own keys all
  use Ctrl.
- **Loading an asset that is not in memory**: UE4SS's `LoadAsset` left six of eight Niagara effects "not found"
  (2026-11-15; the two that played were already loaded). `U.load` falls back to the engine's
  `KismetSystemLibrary:LoadAsset_Blocking` of a soft object path, as `U.load_class` does for classes.
- **An effect attached to another character's body may refuse it**: `NS_ChiYingGuRen_Teleport_001_Main`, made for
  one character's mesh, came back `IsActive()` false on every boss it was attached to and showed nothing; a second
  `Activate(true)` did not help (2026-11-15), while 荡秽's blink-in worked on any body. `U.play_effect_on` logs the
  active state: false means the effect cannot be used that way.
- **Stopping a Niagara effect (`Deactivate`) only ends new particles**: live ones run out their lifetime. 荡秽's
  blink-in loops and never ends by itself, yet stopping it at 0.5 s or 2.5 s looked the same (2026-11-15): it shows
  one burst. To shorten what is seen, choose another effect; `DeactivateImmediate` would cut it off abruptly.
- **Holding a boss still**: its controller's `SGameAIComponent:StopAI()` / `StartAI()` (SGameAI plugin). The AI
  is already started when `FinishSpawningActor` returns; after `StopAI` it stayed stopped (`bAIStarted` false,
  never restarted by the game) and `StartAI` brought it back, in every phase and with two bosses at once
  (2026-11-15).
  Anything a dev tool changes in the game must survive a hot reload: god mode keeps the player's own values in a
  file (`%TEMP%\BossRush_god_base.tsv`) and the next load restores them; kept only in memory, each reload took
  the boosted values as the originals (player health 3085 -> 30,855,000, 2026-11-14).
- Low system memory crashes the game (pagefile); it is not the mod. System settings are the user's to change.
  Measured 2026-11-15 (three crashes that day, exceptions on engine threads): the game holds 12-13 GB private
  memory from the first load and did not grow per fight over six runs (13 min, sampled every 5 s), while the
  system's committed memory sat at 24-26 GB of a 27.95 GB commit limit. To check a suspected leak, sample
  `PBZ` private bytes and `\Memory\Committed Bytes` during a long gauntlet and line them up with the run log.
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
