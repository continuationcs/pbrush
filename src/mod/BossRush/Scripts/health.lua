-- Start-up check (doc/UPDATE.md §2): once the player is in the game, look up every part of the game the mod relies
-- on, before any of it is used, so a game update or DLC that renamed or removed one turns the mod off cleanly (or
-- leaves out the one boss or arena it affects) instead of failing in the middle of a fight.
--
-- Read-only and by name only: native classes, functions and properties are looked up with StaticFindObject and the
-- classes' own member lists; a few blueprints the mod uses anyway (UI widgets, the bosses' base class) are loaded;
-- bosses, helper points, maps and the monster level curves are looked up in the game's asset registry, which
-- never loads them (loading ~70 boss classes would cost gigabytes). Every check gives ok, missing or unknown; only a definite "missing" changes anything:
--   * a core part missing: the mod stops (U.stop) with a notice that the game has changed; no bell entry;
--   * a boss's class or helper point missing: that boss is not offered (main.lua `offered`);
--   * an arena's map missing: that arena is not used (arenas.usable);
--   * anything else (pause-menu row, loading screen, effects): logged only.
-- "unknown" (the asset registry cannot be read, a member list cannot be walked) is logged and treated as present:
-- the check never hides content on a guess.
local U = require("util")
local roster = require("roster")
local arenas = require("arenas")

local M = {}

-- The game build the mod was last tested with (Steam buildid, PBZ.exe CL-302256). A different build is only
-- logged: the check decides what can be used. Update it with each release (doc/UPDATE.md §3).
local TESTED_BUILD = "26367565"
local APP_ID = "4115450"

local passed = false       -- the core check ran and nothing was missing
local missing = {}         -- asset path -> true: definitely not in the game
local pretend = {}         -- development: asset paths treated as missing (devtools F7)

-- Always in UE4SS.log, release builds included: these lines are what a player's log has to show after an update.
local function say(fmt, ...)
    print("[BossRush] health: " .. string.format(fmt, ...) .. "\n")
end

-- ------------------------------------------------------------------ game parts by name
-- Native classes (/Script/<Module>.<Class>) with the functions and properties the mod calls or reads. Taken from
-- the code (2026-11-15); a new call on a game class belongs here too.
local NATIVE = {
    { "/Script/ProjectPBZ.PBZSaveLoadSubsystem", funcs = { "TeleportTo" } },
    { "/Script/ProjectPBZ.PBZTeleportSubsystem",
      funcs = { "IsInJhsy", "TeleportToJhsy", "TeleportToBellFromJhsy", "GetJhsyBellTeleportTransform" } },
    { "/Script/ProjectPBZ.PBZGameSystem", props = { "CycleCount", "DiedTimes" } },
    { "/Script/ProjectPBZ.BellManager", props = { "ActivateBellIDs", "RecentlyInteractedBellID" } },
    { "/Script/ProjectPBZ.PBZBackPackSubsystem", props = { "MedicineInfos" } },
    { "/Script/ProjectPBZ.PBZMedicineInfo", funcs = { "SetCurrentTime", "SetDisplayTime" } },
    { "/Script/ProjectPBZ.PBZCharacter", props = { "AttributeSetBase" } },
    { "/Script/ProjectPBZ.PBZCharacter_NPC", funcs = { "Kill" }, props = { "bExcludeFromCodex" } },
    { "/Script/ProjectPBZ.PBZBlueprintFunctionLibrary", funcs = { "GetDifficulty" } },
    { "/Script/ProjectPBZ.PBZActivatableWidget", funcs = { "ClearBackKey", "BindBackKey" } },
    { "/Script/ProjectPBZ.PBZButtonBase", funcs = { "UpdateButtonStyle", "UpdateButtonText" } },
    { "/Script/CharacterBasics.PBZAttributeSetHandler", funcs = { "IsDead" } },
    { "/Script/CharacterBasics.BasicAttributeSet",
      props = { "Health", "Health_Max", "Health_Min", "Shachi", "Shachi_Max", "Attack", "ShachiAttack" } },
    { "/Script/CommonUI.CommonButtonBase",
      funcs = { "HandleButtonClicked", "SetTriggeringInputAction", "SetTriggeringEnhancedInputAction", "GetSelected",
                "SetIsSelected" } },
    { "/Script/CommonUI.CommonButtonGroupBase", funcs = { "OnHandleButtonBaseClicked", "SelectButtonAtIndex",
      "FindButtonIndex", "GetSelectedButtonBase", "DeselectAll", "GetButtonCount" } },
    { "/Script/CommonUI.CommonWidgetGroupBase", funcs = { "AddWidget", "RemoveWidget" } },
    { "/Script/CommonUI.CommonActivatableWidget", funcs = { "IsActivated", "DeactivateWidget" } },
    { "/Script/SGameAI.SGameAIController", props = { "SGameAIComponent" } },
    { "/Script/SGameAI.SGameAIComponent", funcs = { "StopAI", "StartAI" } },
    { "/Script/SGameAI.SGameAIWorldSubsystem",
      funcs = { "RegisterIdentity", "FindIdentityByTag", "UnRegisterIdentityByTag" }, props = { "Identities" } },
    { "/Script/Engine.GameplayStatics", funcs = { "BeginDeferredActorSpawnFromClass", "FinishSpawningActor" } },
    { "/Script/NavigationSystem.NavigationSystemV1",
      funcs = { "K2_ProjectPointToNavigation", "FindPathToLocationSynchronously" } },
    { "/Script/Niagara.NiagaraFunctionLibrary", funcs = { "SpawnSystemAtLocation", "SpawnSystemAttached" },
      optional = true },
    -- The 退出战斗 row in the system menu (pause.lua).
    { "/Script/GameSettings.GameSetting", funcs = { "GetDevName" }, optional = true },
    { "/Script/GameSettings.GameSettingAction", optional = true },
    { "/Script/GameSettings.GameSettingPanel", props = { "CurrentCollection", "ListView_Settings" }, optional = true },
    { "/Script/GameSettings.GameSettingListEntryBase", props = { "Setting" }, optional = true },
    { "/Script/GameSettings.GameSettingListEntrySetting_Action", props = { "Button_Action" }, optional = true },
    -- Stopping the player's fall when an in-level move found no ground (run.lua put).
    { "/Script/Engine.Character", props = { "CharacterMovement" }, optional = true },
    { "/Script/Engine.MovementComponent", funcs = { "StopMovementImmediately" }, optional = true },
    -- Bells, to measure how far a fight is from one (U.nearest_bell).
    { "/Script/ProjectPBZ.PBZCheckPoint", optional = true },
}

-- The game's blueprints the mod builds on, loaded here: UI widgets the game loads itself on first use, and the
-- base class of every boss, where the loot component sits. Without LootComp a challenge kill would give real loot
-- and Remnant Dust (run.lua removes it), so it is core.
local BLUEPRINTS = {
    { "/Game/RenewalContent/Prototypes/Character/BP_RenewalNPC.BP_RenewalNPC_C", props = { "LootComp" } },
    { "/Game/PBZContent/UI/InGame/Bell/W_BellMenu.W_BellMenu_C",
      funcs = { "ClickCloseButton" }, props = { "TeleportBtn", "CloseBtn" } },
    { "/Game/PBZContent/Blueprint/FlowGraph/UI/W_DialogueButton.W_DialogueButton_C",
      funcs = { "SetWidgetText", "DoSelectedAppearance" } },
    { "/Game/PBZContent/UI/UINew/HUD/wb_settlement.wb_settlement_C" },
    { "/Game/PBZContent/UI/InGame/SwitchUI/WB_TipsText.WB_TipsText_C", funcs = { "SetText" }, props = { "FadeIn", "FadeOut" } },
    { "/Game/PBZContent/UI/Settings/Editors/W_SettingsListEntry_Action.W_SettingsListEntry_Action_C",     -- 退出战斗 row
      props = { "SettingName" }, optional = true },
}

-- Assets looked up in the registry, not loaded. Core: the monster level curves (scale.lua): without them a boss
-- keeps its base stats, far too weak, and nothing would say so.
local CORE_ASSETS = require("scale").curve_paths()

-- Their absence costs a feature, not the mod.
local OPTIONAL_ASSETS = {
    "/Game/PBZContent/UI/GameSystem/Settings/W_PBZSettingPanel.W_PBZSettingPanel_C",           -- pause-menu row
    "/Game/PBZContent/UI/Hud/WB_AdditionalLoading.WB_AdditionalLoading_C",                    -- end of loading
    "/PBZCombatAsset/Prototypes/Actions/GAA_AssignIdentityTransformToBlackboard.GAA_AssignIdentityTransformToBlackboard_C",
    "/SGameAI/Tools/Teleport/BP_SGameAITargetPoint.BP_SGameAITargetPoint_C",                 -- identity points
    "/PBZVFXPack/VFX/BattleFX/LengTu/NS_SummonBossField1_602.NS_SummonBossField1_602",        -- entrance effects
    "/PBZVFXPack/VFX/BattleFX/DangHui/NS_DangHui_Blink_301_Show.NS_DangHui_Blink_301_Show",
}

-- Names of a class's functions and properties, its parents' included; nil when the list cannot be walked.
local function members(cls)
    local names = {}
    local ok = pcall(function()
        local c, depth = cls, 0
        while U.valid(c) and depth < 32 do
            c:ForEachFunction(function(f) names[f:GetFName():ToString()] = true end)
            c:ForEachProperty(function(p) names[p:GetFName():ToString()] = true end)
            c = c:GetSuperStruct()
            depth = depth + 1
        end
    end)
    return ok and names or nil
end

-- Checks one class entry; adds what is missing to `out` (strings) and returns the count of unknowns.
local function check_class(entry, cls, out)
    if not U.valid(cls) then out[#out + 1] = entry[1] return 0 end
    local wanted = {}
    for _, n in ipairs(entry.funcs or {}) do wanted[#wanted + 1] = n end
    for _, n in ipairs(entry.props or {}) do wanted[#wanted + 1] = n end
    if #wanted == 0 then return 0 end
    local names = members(cls)
    if not names then U.log("health: members of %s cannot be listed", entry[1]) return #wanted end
    for _, n in ipairs(wanted) do
        if not names[n] then out[#out + 1] = entry[1] .. ":" .. n end
    end
    return 0
end

-- ------------------------------------------------------------------ asset registry
-- The registry knows every asset in the game's paks without loading it. Looked up through the engine's
-- IAssetRegistry (AssetRegistryImpl); a soft object path made by KismetSystemLibrary (the same struct U.load
-- passes on). Calibrated before use: a known asset must be found and a made-up one must not, else nothing it says
-- is trusted.
local KSL = "/Script/Engine.Default__KismetSystemLibrary"
-- The registry singleton is the class default object itself: FindAllOf("AssetRegistryImpl") without defaults
-- found nothing (2026-11-16).
local REGISTRY = "/Script/AssetRegistry.Default__AssetRegistryImpl"

local function registry()
    local reg = StaticFindObject(REGISTRY)
    local ksl = StaticFindObject(KSL)
    U.log("health: registry object %s, KismetSystemLibrary %s", tostring(U.valid(reg)), tostring(U.valid(ksl)))
    if not (U.valid(reg) and U.valid(ksl)) then return nil end
    return function(path)
        local ad = reg:K2_GetAssetByObjectPath(ksl:MakeSoftObjectPath(path), true, false)
        local pkg = ad and ad.PackageName and ad.PackageName:ToString()
        return pkg ~= nil and pkg ~= "" and pkg ~= "None"
    end
end

-- A class "/Pkg/X.X_C" is listed in the registry as its blueprint "/Pkg/X.X" in some builds: either form counts.
local function exists(lookup, path)
    local ok, found = pcall(lookup, path)
    if not ok then return nil end
    if found then return true end
    local base = path:gsub("_C$", "")
    if base == path then return false end
    ok, found = pcall(lookup, base)
    if not ok then return nil end
    return found
end

-- The map package "/Game/Maps/X/Y" as an object path ("/Game/Maps/X/Y.Y").
local function map_object(map)
    return map .. "." .. map:match("([^/]+)$")
end

-- Returns the lookup when it passes the calibration, else nil (logged).
local function calibrated()
    -- First use of the registry from Lua (2026-11-15): a native crash right after this line points at it.
    U.log("health: asset registry lookups start")
    local ok, lookup = pcall(registry)
    if not (ok and lookup) then
        say("asset registry not found (%s): bosses and arenas are not checked", ok and "no object" or tostring(lookup))
        return nil
    end
    local known = exists(lookup, BLUEPRINTS[1][1])
    local fake = exists(lookup, "/Game/BossRush/NoSuchAsset.NoSuchAsset_C")
    local here = U.world_path()
    local map = here and exists(lookup, map_object(here))
    U.log("health: registry calibration: known %s, made-up %s, current map %s (%s)", tostring(known), tostring(fake),
        tostring(map), tostring(here))
    if known ~= true or fake ~= false then
        say("asset registry cannot be trusted (known %s, made-up %s): bosses and arenas are not checked",
            tostring(known), tostring(fake))
        return nil, false
    end
    -- Maps are listed as World assets; trusted only if the map the player is on is found.
    return lookup, map == true
end

-- ------------------------------------------------------------------ game build
-- The Steam build from the game's app manifest (steamapps/appmanifest_<app>.acf, seven folders above the mod
-- folder: BossRush -> Mods -> ue4ss -> steam -> platform -> PBZ -> common -> steamapps). nil when it cannot be read.
local function game_build()
    local path = U.MOD_DIR .. "../../../../../../../appmanifest_" .. APP_ID .. ".acf"
    local f = io.open(path, "r")
    if not f then U.log("health: no app manifest at %s", path) return nil end
    local text = f:read("*a")
    f:close()
    return text:match('"buildid"%s+"(%d+)"')
end

-- ------------------------------------------------------------------ the check
local function run_check(extra_core)
    local build = game_build()
    say("game build %s (tested with %s)%s", tostring(build), TESTED_BUILD,
        (build and build ~= TESTED_BUILD) and ": not tested, see the lines below" or "")

    local core, optional, unknown = {}, {}, 0
    for _, e in ipairs(NATIVE) do
        local cls = StaticFindObject(e[1])
        unknown = unknown + check_class(e, cls, e.optional and optional or core)
    end
    for _, e in ipairs(BLUEPRINTS) do
        unknown = unknown + check_class(e, U.load_class(e[1]), e.optional and optional or core)
    end
    if extra_core then core[#core + 1] = extra_core end

    local lookup, maps_ok = calibrated()
    local bosses, arena_count, assets = 0, 0, 0
    if lookup then
        local function check(path)
            assets = assets + 1
            local found = exists(lookup, path)
            if found == false then missing[path] = true end
            if found == nil then unknown = unknown + 1 end
            return found ~= false
        end
        for _, path in ipairs(CORE_ASSETS) do
            if not check(path) then core[#core + 1] = path end
        end
        for _, path in ipairs(OPTIONAL_ASSETS) do
            if not check(path) then optional[#optional + 1] = path end
        end
        for _, b in ipairs(roster) do
            if b.state == "open" or b.state == "testing" then
                local ok = check(b.class)
                for _, h in ipairs(b.helpers or {}) do ok = check(h.class) and ok end
                if not ok then bosses = bosses + 1 say("boss left out: %s (%s)", b.id, b.zh) end
            end
        end
        if maps_ok then
            for _, a in ipairs(arenas.all()) do
                if a.map and not check(map_object(a.map)) then
                    missing[a.map] = true
                    arena_count = arena_count + 1
                    say("arena left out: %s (map %s)", a.key, a.map)
                end
            end
        else
            say("maps cannot be looked up: arenas are not checked")
        end
    end
    for path in pairs(pretend) do missing[path] = true end

    for _, m in ipairs(optional) do say("missing (feature only): %s", m) end
    for _, m in ipairs(core) do say("MISSING: %s", m) end
    say("%d core parts missing, %d optional, %d bosses and %d arenas left out, %d assets looked up, %d unknown",
        #core, #optional, bosses, arena_count, assets, unknown)
    if #core > 0 then
        U.stop("health: the game has changed: " .. table.concat(core, ", "), "outdated")
        return
    end
    passed = true
end

-- Runs the check once the player is in the game (at game start mods load before there is a world to look in).
-- extra_core: development only, a made-up core part to see the stop path (devtools F8).
function M.start(extra_core)
    passed = false
    U.every(1000, function()
        if not U.valid(U.pawn()) then return false end
        run_check(extra_core)
        return true
    end)
end

-- Whether the check has passed: the bell entry appears only then.
function M.ready() return passed end

-- Whether the asset (class, helper point, map) is in the game; true when unknown.
function M.has(path)
    return path == nil or not missing[path]
end

-- Whether every part a boss record needs is in the game.
function M.boss_ok(b)
    if not M.has(b.class) then return false end
    for _, h in ipairs(b.helpers or {}) do
        if not M.has(h.class) then return false end
    end
    return true
end

-- Development (devtools F7): treat the boss's class as missing, to see it left out of the lists.
function M.pretend_missing(path)
    pretend[path] = true
    missing[path] = true
    say("pretending %s is missing", path)
end

return M
