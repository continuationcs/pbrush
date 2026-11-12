-- BossRushProbe: one-off discovery mod for the Phantom Blade Zero boss rush.
-- Logs the classes the boss rush needs (player, controller, game mode, boss base classes, ability system),
-- generates the CXX header dump once, and offers a spawn test.
--   F2  enter / leave the Realm of Mirage (game teleport)
--   F3  preview the wb_settlement screen (text slots labelled with their names)
--   F4  mark current spot as an arena candidate (arenas.tsv)
--   F5  dump all bells (bells.tsv)
--   F6  teleport to the next arena (6 scenic spots), 7th press returns to the start
--   F7  spawn the next test boss 6 m in front of the player
--   F8  re-run the report (e.g. after a boss is spawned)
--   F9  player / last boss attributes + monster level curves
--   F10 last boss HP x2, Attack x1.5 (direct write)
--   F1  god mode toggle
--   Bell menu gets a test entry automatically; death hooks arm on F7
-- Everything is printed to ue4ss/UE4SS.log with the prefix [BRProbe].

local UEHelpers = require("UEHelpers")

local MOD_DIR = (debug.getinfo(1, "S").source:match("^@(.*[\\/])Scripts[\\/]") or "")
local MARKER = MOD_DIR .. "sdk_done.txt"

local function log(fmt, ...)
    print(string.format("[BRProbe] " .. fmt .. "\n", ...))
end

local function valid(o)
    return o ~= nil and o.IsValid ~= nil and o:IsValid()
end

local function name_of(o)
    if not valid(o) then return "<nil>" end
    local ok, n = pcall(function() return o:GetFullName() end)
    return ok and n or "<?>"
end

local function chain(cls)
    local out = {}
    local c = cls
    local guard = 0
    while valid(c) and guard < 40 do
        out[#out + 1] = c:GetFName():ToString()
        local ok, s = pcall(function() return c:GetSuperStruct() end)
        if not ok then break end
        c = s
        guard = guard + 1
    end
    return table.concat(out, " < ")
end

local function props(cls, filter)
    local out = {}
    pcall(function()
        cls:ForEachProperty(function(p)
            local n = p:GetFName():ToString()
            if not filter or n:lower():find(filter) then
                out[#out + 1] = n .. ":" .. p:GetClass():GetFName():ToString()
            end
        end)
    end)
    return table.concat(out, ", ")
end

local function funcs(cls, filter)
    local out = {}
    pcall(function()
        cls:ForEachFunction(function(f)
            local n = f:GetFName():ToString()
            if not filter or n:lower():find(filter) then out[#out + 1] = n end
        end)
    end)
    return table.concat(out, ", ")
end

-- Load a class/asset by "/Pkg/Path/Asset.Asset_C". Tries UE4SS LoadAsset, then the engine's
-- KismetSystemLibrary soft-class loader. Logs why it failed.
function load_class(path)
    local found = StaticFindObject(path)
    if valid(found) then return found end
    local pkg = (path:gsub("%.[^.]+$", ""))
    local ok, err = pcall(LoadAsset, pkg)
    if not ok then log("LoadAsset(%s) failed: %s", pkg, tostring(err)) end
    found = StaticFindObject(path)
    if valid(found) then return found end
    local ok2, res = pcall(function()
        local ksl = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
        local scp = ksl:MakeSoftClassPath(path)
        local ref = ksl:Conv_SoftClassPathToSoftClassRef(scp)
        return ksl:LoadClassAsset_Blocking(ref)
    end)
    if not ok2 then log("LoadClassAsset_Blocking(%s) failed: %s", path, tostring(res)) end
    found = StaticFindObject(path)
    if valid(found) then return found end
    if ok2 and valid(res) then return res end
    log("still not loaded: %s", path)
    return nil
end

local function describe(label, o)
    if not valid(o) then log("%s: <none>", label) return end
    log("%s: %s", label, name_of(o))
    log("  chain: %s", chain(o:GetClass()))
end

local function component_list(actor)
    local out = {}
    pcall(function()
        local comps = actor:K2_GetComponentsByClass(StaticFindObject("/Script/Engine.ActorComponent"))
        for i = 1, #comps do
            local c = comps[i]:get()
            out[#out + 1] = c:GetFName():ToString() .. "(" .. c:GetClass():GetFName():ToString() .. ")"
        end
    end)
    return table.concat(out, ", ")
end

local function report()
    log("===== report =====")
    local pc = UEHelpers.GetPlayerController()
    describe("PlayerController", pc)
    local pawn = valid(pc) and pc.Pawn or nil
    describe("Pawn", pawn)
    if valid(pawn) then
        log("  location: %s", (function()
            local l = pawn:K2_GetActorLocation()
            return string.format("%.0f %.0f %.0f", l.X, l.Y, l.Z)
        end)())
        log("  components: %s", component_list(pawn))
        log("  pawn props (attr/health/ability): %s", props(pawn:GetClass(), "abil") .. " | " .. props(pawn:GetClass(), "health") .. " | " .. props(pawn:GetClass(), "attr"))
    end
    describe("GameMode", UEHelpers.GetGameModeBase())
    describe("GameState", UEHelpers.GetGameStateBase())
    describe("World", UEHelpers.GetWorld())
    describe("GameInstance", UEHelpers.GetGameInstance())

    -- Ability system: attribute sets that exist right now
    local sets = FindAllOf("AttributeSet") or {}
    log("AttributeSet instances: %d", #sets)
    local seen = {}
    for _, s in ipairs(sets) do
        local cn = s:GetClass():GetFName():ToString()
        if not seen[cn] then
            seen[cn] = true
            log("  %s outer=%s", cn, name_of(s:GetOuter()))
            log("    props: %s", props(s:GetClass()))
        end
    end

    -- Boss base classes, from a loaded boss blueprint
    for _, path in ipairs({
        "/PBZCombatAsset/ActorData/Mobs/054_ZuoShang/BP_Monster_ZuoShang.BP_Monster_ZuoShang_C",
        "/Game/RenewalContent/Actors/Mobs/Normal/BP_Monster_WuXuan.BP_Monster_WuXuan_C",
    }) do
        local cls = StaticFindObject(path)
        if not valid(cls) then
            load_class(path)
            cls = StaticFindObject(path)
        end
        if valid(cls) then
            log("Boss class %s", path)
            log("  chain: %s", chain(cls))
            local c, i = cls, 0
            while valid(c) and i < 12 do
                local n = c:GetFName():ToString()
                if not n:find("^Actor$") and not n:find("^Object$") then
                    log("  [%s] funcs(die/death/dead/kill/hp/boss/phase/spawn/ai/target): %s", n,
                        funcs(c, "d[ie][ea]") .. " | " .. funcs(c, "kill") .. " | " .. funcs(c, "boss") .. " | " .. funcs(c, "phase") .. " | " .. funcs(c, "spawn") .. " | " .. funcs(c, "target"))
                    log("  [%s] props(boss/dead/health/team/ai/phase): %s", n,
                        props(c, "boss") .. " | " .. props(c, "dead") .. " | " .. props(c, "health") .. " | " .. props(c, "team") .. " | " .. props(c, "phase") .. " | " .. props(c, "aicontroller"))
                end
                local ok, s = pcall(function() return c:GetSuperStruct() end)
                c = ok and s or nil
                i = i + 1
            end
        else
            log("Boss class not loadable: %s", path)
        end
    end

    -- Live monsters near the player
    local mons = FindAllOf("Character") or {}
    local n = 0
    for _, m in ipairs(mons) do
        if valid(m) and m ~= pawn then
            n = n + 1
            if n <= 15 then log("  live character: %s ctrl=%s", name_of(m), name_of(m.Controller)) end
        end
    end
    log("live characters: %d", n)

    -- Language
    pcall(function()
        local intl = StaticFindObject("/Script/Engine.Default__KismetInternationalizationLibrary")
        log("Language=%s Culture=%s", intl:GetCurrentLanguage():ToString(), intl:GetCurrentCulture():ToString())
    end)

    -- UI we want to reuse
    for _, path in ipairs({
        "/Game/PBZContent/UI/InGame/Bell/W_BellMenu.W_BellMenu_C",
        "/Game/PBZContent/Blueprint/FlowGraph/UI/WBP_FlowDialog.WBP_FlowDialog_C",
        "/Game/PBZContent/Blueprint/FlowGraph/UI/W_DialogueButton.W_DialogueButton_C",
        "/Game/PBZContent/Blueprint/FlowGraph/UI/WBP_FlowTips.WBP_FlowTips_C",
        "/Game/PBZContent/UI/Foundation/Dialogs/W_ConfirmationDialog.W_ConfirmationDialog_C",
    }) do
        local cls = StaticFindObject(path)
        if not valid(cls) then
            load_class(path)
            cls = StaticFindObject(path)
        end
        if valid(cls) then
            log("Widget %s", path)
            log("  chain: %s", chain(cls))
            log("  funcs: %s", funcs(cls))
            log("  props: %s", props(cls))
        else
            log("Widget not loadable: %s", path)
        end
    end
    -- Native boss-fight plumbing, Realm of Mirage travel, player death
    for _, path in ipairs({
        "/Game/PBZContent/UI/Hud/WB_BossHPBar.WB_BossHPBar_C",
        "/SGameAI/GameplayEffect/GE_InBossFight.GE_InBossFight_C",
        "/Game/PBZContent/Blueprint/BP_JhsyActorComponent.BP_JhsyActorComponent_C",
        "/Game/PBZContent/Blueprint/FlowGraph/FlowGraphNode/TeleportToJhsyBell.TeleportToJhsyBell_C",
        "/Game/PBZContent/Blueprint/FlowGraph/FlowGraphNode/TeleportToBellFromJhsy.TeleportToBellFromJhsy_C",
        "/Game/PBZContent/UI/InGame/Dead/GA_PlayerResetAttribute_Dead.GA_PlayerResetAttribute_Dead_C",
    }) do
        local cls = StaticFindObject(path)
        if not valid(cls) then
            load_class(path)
            cls = StaticFindObject(path)
        end
        if valid(cls) then
            log("Class %s", path)
            log("  chain: %s", chain(cls))
            log("  funcs: %s", funcs(cls))
            log("  props: %s", props(cls))
        else
            log("Class not loadable: %s", path)
        end
    end
    if valid(pawn) then
        local c, i = pawn:GetClass(), 0
        while valid(c) and i < 10 do
            log("  player [%s] funcs(die/dead/death/revive/respawn/bell/jhsy/teleport): %s", c:GetFName():ToString(),
                funcs(c, "d[ie][ea]") .. " | " .. funcs(c, "revive") .. " | " .. funcs(c, "respawn") .. " | " .. funcs(c, "bell") .. " | " .. funcs(c, "jhsy") .. " | " .. funcs(c, "teleport"))
            local ok, s = pcall(function() return c:GetSuperStruct() end)
            c = ok and s or nil
            i = i + 1
        end
    end
    local bars = FindAllOf("WB_BossHPBar_C") or {}
    log("WB_BossHPBar instances: %d", #bars)
    log("===== end report =====")
end

-- Who creates the native boss HP bar (tells us how a boss fight is started)
pcall(function()
    NotifyOnNewObject("/Game/PBZContent/UI/Hud/WB_BossHPBar.WB_BossHPBar_C", function(obj)
        log("boss HP bar created: %s outer=%s", name_of(obj), name_of(obj:GetOuter()))
    end)
end)

-- Log the bell menu whenever the game opens it, with its live widget tree.
local function dump_widget_tree(w)
    pcall(function()
        local tree = w.WidgetTree
        local all = {}
        tree:ForEachWidget(function(c)
            all[#all + 1] = c:GetFName():ToString() .. "(" .. c:GetClass():GetFName():ToString() .. ")"
        end)
        log("  widget tree: %s", table.concat(all, ", "))
    end)
end

for _, cls in ipairs({ "/Game/PBZContent/UI/InGame/Bell/W_BellMenu.W_BellMenu_C",
                       "/Game/PBZContent/Blueprint/FlowGraph/UI/WBP_FlowDialog.WBP_FlowDialog_C" }) do
    pcall(function()
        NotifyOnNewObject(cls, function(obj)
            log("opened %s", name_of(obj))
            ExecuteWithDelay(1500, function()
                ExecuteInGameThread(function()
                    if valid(obj) then
                        log("  props: %s", props(obj:GetClass()))
                        dump_widget_tree(obj)
                    end
                end)
            end)
        end)
    end)
end

local function generate_sdk_once()
    local f = io.open(MARKER, "r")
    if f then f:close() log("SDK already generated (delete %s to redo)", MARKER) return end
    log("Generating CXX header dump... the game may freeze for a minute")
    local ok, err = pcall(GenerateSDK)
    log("GenerateSDK done ok=%s %s", tostring(ok), tostring(err or ""))
    local w = io.open(MARKER, "w")
    if w then w:write(os.date()) w:close() end
end

-- Spawn test ------------------------------------------------------------------------------------
local function str(v)
    if v == nil then return "nil" end
    local ok, s = pcall(function() return v:ToString() end)
    if ok and s then return s end
    return tostring(v)
end

local function vec(v)
    if v == nil then return "nil" end
    return string.format("%.0f %.0f %.0f", v.X or 0, v.Y or 0, v.Z or 0)
end

local function append_file(name, line)
    local f = io.open(MOD_DIR .. name, "a")
    if f then f:write(line .. "\n"); f:close() end
end

local TEST_BOSSES = {
    "/PBZCombatAsset/ActorData/Mobs/044_PengMeng/BP_Monster_PengMeng_Axe.BP_Monster_PengMeng_Axe_C",
    "/PBZCombatAsset/ActorData/Mobs/054_ZuoShang/BP_Monster_ZuoShang.BP_Monster_ZuoShang_C",
    "/Game/RenewalContent/Actors/Mobs/Normal/BP_Monster_WuXuan.BP_Monster_WuXuan_C",
    "/PBZCombatAsset/ActorData/Mobs/QiShu/BP_Monster_QiShu_Huo.BP_Monster_QiShu_Huo_C",
    -- bosses whose skills look up level-placed helper actors (snap / landing / center points)
    "/PBZCombatAsset/ActorData/Mobs/068_YuZan/BP_Monster_FemaleVessel_YuZan.BP_Monster_FemaleVessel_YuZan_C",
    "/PBZCombatAsset/ActorData/Mobs/059_DuYan/BP_Monster_DuYanBoss.BP_Monster_DuYanBoss_C",
    "/PBZCombatAsset/ActorData/Mobs/065_ChiLian_P2/BP_Monster_ChiLian_P2.BP_Monster_ChiLian_P2_C",
    "/PBZCombatAsset/ActorData/Mobs/073_YanQianSui/BP_Monster_YanQianSui.BP_Monster_YanQianSui_C",
}
local next_boss = 1
local spawned = {}

local function spawn_test()
    local path = TEST_BOSSES[next_boss]
    next_boss = next_boss % #TEST_BOSSES + 1
    local pc = UEHelpers.GetPlayerController()
    local pawn = valid(pc) and pc.Pawn or nil
    if not valid(pawn) then log("spawn: no player pawn") return end
    local cls = StaticFindObject(path)
    if not valid(cls) then
        load_class(path)
        cls = StaticFindObject(path)
    end
    if not valid(cls) then log("spawn: class not found %s", path) return end
    local loc = pawn:K2_GetActorLocation()
    local fwd = pawn:GetActorForwardVector()
    local rot = pawn:K2_GetActorRotation()
    local at = { X = loc.X + fwd.X * 600, Y = loc.Y + fwd.Y * 600, Z = loc.Z + 50 }
    local gs = UEHelpers.GetGameplayStatics()
    local world = UEHelpers.GetWorld()
    local transform = {
        Rotation = { X = 0, Y = 0, Z = math.sin(math.rad(rot.Yaw + 180) / 2), W = math.cos(math.rad(rot.Yaw + 180) / 2) },
        Translation = at,
        Scale3D = { X = 1, Y = 1, Z = 1 },
    }
    local ok, actor = pcall(function()
        local a = gs:BeginDeferredActorSpawnFromClass(world, cls, transform, 1, nil, 0)
        return gs:FinishSpawningActor(a, transform, 0)
    end)
    if not ok or not valid(actor) then log("spawn failed: %s", tostring(actor)) return end
    log("spawned %s", name_of(actor))
    if not valid(actor.Controller) then
        pcall(function() actor:SpawnDefaultController() end)
    end
    log("  controller: %s", name_of(actor.Controller))
    log("  components: %s", component_list(actor))
    pcall(function() log("  CharacterName=%s", actor.CharacterName:ToString()) end)
    spawned[#spawned + 1] = actor
    local start = actor:K2_GetActorLocation()
    ExecuteWithDelay(3000, function()
        ExecuteInGameThread(function()
            if not valid(actor) then log("  after 3s: actor gone") return end
            local l = actor:K2_GetActorLocation()
            local moved = math.sqrt((l.X - start.X) ^ 2 + (l.Y - start.Y) ^ 2 + (l.Z - start.Z) ^ 2)
            local hp = "?"
            pcall(function() hp = string.format("%.0f/%.0f", actor.AttributeSetBase.Health.CurrentValue, actor.AttributeSetBase.Health_Max.CurrentValue) end)
            log("  after 3s: moved %.0fcm, controller=%s, hp=%s, boss bars=%d", moved, name_of(actor.Controller), hp, #(FindAllOf("WB_BossHPBar_C") or {}))
        end)
    end)
    -- Watch for 3 minutes: report if the boss vanishes, jumps far in one tick, or ends up far below/above.
    local short = actor:GetClass():GetFName():ToString()
    local last, ticks, done = start, 0, false
    LoopAsync(2000, function()
        if done then return true end
        ticks = ticks + 1
        ExecuteInGameThread(function()
            if done then return end
            if not valid(actor) then log("WATCH %s: actor gone after ~%ds", short, ticks * 2) done = true return end
            local dead = false
            pcall(function() dead = actor.AttributeSetBase.Health.CurrentValue <= 0 end)
            if dead then
                log("WATCH %s: HP 0 after ~%ds at %s", short, ticks * 2, vec(actor:K2_GetActorLocation()))
                done = true
                -- Some bosses wait at 0 HP for an execution; force the game's own Kill after a short beat.
                ExecuteWithDelay(800, function()
                    ExecuteInGameThread(function()
                        if not valid(actor) then return end
                        local okk, e = pcall(function() actor:Kill(0) end)
                        log("WATCH %s: forced Kill(0) -> %s", short, okk and "called" or tostring(e))
                    end)
                end)
                return
            end
            local l = actor:K2_GetActorLocation()
            local jump = math.sqrt((l.X - last.X) ^ 2 + (l.Y - last.Y) ^ 2 + (l.Z - last.Z) ^ 2)
            if jump > 2500 then log("WATCH %s: jumped %.0fcm in 2s to %s", short, jump, vec(l)) end
            if math.abs(l.Z - start.Z) > 3000 then log("WATCH %s: z offset %.0f from spawn", short, l.Z - start.Z) end
            local hidden = false
            pcall(function() hidden = actor.bHidden end)
            if hidden then log("WATCH %s: hidden", short) end
            last = l
        end)
        return done or ticks >= 90
    end)
end

-- ---------------------------------------------------------------- stats / scaling
local function attr(a, name)
    local v = "?"
    pcall(function()
        local d = a.AttributeSetBase[name]
        v = string.format("%.1f/%.1f", d.BaseValue, d.CurrentValue)
    end)
    return v
end

local STAT_NAMES = { "Level", "Health", "Health_Max", "Health_Max_Lv", "Attack", "Attack_Lv", "Shachi_Max",
    "Shachi_Max_Lv", "ShachiAttack", "ShachiAttack_Lv", "Infliction_Max", "PowerScore" }

local function stats_line(a)
    local out = {}
    for _, n in ipairs(STAT_NAMES) do out[#out + 1] = n .. "=" .. attr(a, n) end
    return table.concat(out, " ")
end

local function last_boss()
    for i = #spawned, 1, -1 do if valid(spawned[i]) then return spawned[i] end end
    return nil
end

-- F9: player + last spawned boss attributes, and the monster level curves sampled at 1..30.
local function stats_dump()
    local ok, err = pcall(function()
        local pawn = UEHelpers.GetPlayerController().Pawn
        log("STATS player: %s", stats_line(pawn))
        local b = last_boss()
        if valid(b) then log("STATS boss %s: %s", b:GetClass():GetFName():ToString(), stats_line(b)) end
        -- Native (level-placed) enemies nearby, to compare their Level and stats with the base values.
        local mine = {}
        for _, s in ipairs(spawned) do if valid(s) then mine[s:GetFullName()] = true end end
        local here = pawn:K2_GetActorLocation()
        local near = {}
        for _, n in ipairs(FindAllOf("PBZCharacter_NPC") or {}) do
            if valid(n) and not mine[n:GetFullName()] then
                local ok2, l = pcall(function() return n:K2_GetActorLocation() end)
                if ok2 then near[#near + 1] = { n = n, d = (l.X - here.X) ^ 2 + (l.Y - here.Y) ^ 2 + (l.Z - here.Z) ^ 2 } end
            end
        end
        table.sort(near, function(x, y) return x.d < y.d end)
        for i = 1, math.min(5, #near) do
            local n = near[i].n
            log("STATS native %s (%.0fm): %s", n:GetClass():GetFName():ToString(), math.sqrt(near[i].d) / 100, stats_line(n))
        end
        for _, c in ipairs({ "Health", "Attack", "Shachi", "ShachiAttack", "Infliction" }) do
            local path = "/PBZCombatAsset/Config/Level/CV_AttributeCurve_Monster_" .. c .. ".CV_AttributeCurve_Monster_" .. c
            local cv = StaticFindObject(path)
            if not valid(cv) then pcall(LoadAsset, (path:gsub("%.[^.]+$", ""))) cv = StaticFindObject(path) end
            if valid(cv) then
                local vals = {}
                for lv = 1, 30 do vals[#vals + 1] = string.format("%.3g", cv:GetFloatValue(lv)) end
                log("CURVE %s: %s", c, table.concat(vals, " "))
            else
                log("CURVE %s: not found", c)
            end
        end
    end)
    if not ok then log("stats failed: %s", tostring(err)) end
end

-- (unbound) raise the last boss's Level attribute by 10 (direct write), then re-read after 1s.
local function level_test()
    local ok, err = pcall(function()
        local b = last_boss()
        if not valid(b) then log("level test: spawn a boss first (F7)") return end
        log("LEVEL before: %s", stats_line(b))
        local lv = b.AttributeSetBase.Level
        local nv = lv.CurrentValue + 10
        lv.BaseValue = nv
        lv.CurrentValue = nv
        ExecuteWithDelay(1000, function()
            ExecuteInGameThread(function()
                if valid(b) then log("LEVEL after +10 (direct write): %s", stats_line(b)) end
            end)
        end)
    end)
    if not ok then log("level test failed: %s", tostring(err)) end
end

-- F10: scale the last boss directly: Health_Max/Health x2, Attack x1.5; re-read after 1s and 10s.
local function scale_test()
    local ok, err = pcall(function()
        local b = last_boss()
        if not valid(b) then log("scale test: spawn a boss first (F7)") return end
        local s = b.AttributeSetBase
        log("SCALE before: %s", stats_line(b))
        for name, k in pairs({ Health_Max = 2, Health = 2, Attack = 1.5 }) do
            s[name].BaseValue = s[name].BaseValue * k
            s[name].CurrentValue = s[name].CurrentValue * k
        end
        for _, t in ipairs({ 1000, 10000 }) do
            ExecuteWithDelay(t, function()
                ExecuteInGameThread(function()
                    if valid(b) then log("SCALE after %dms: %s", t, stats_line(b)) end
                end)
            end)
        end
    end)
    if not ok then log("scale test failed: %s", tostring(err)) end
end

-- F1: debug god mode + one-hit kill. Player Health_Max x100 and Health refilled every 100ms; player Attack x1000
-- (damage still goes through the game's own pipeline, so enemies die normally). Toggling off restores both.
local god = { on = false, base = nil, cur = nil, gen = 0, atk_base = nil, atk_cur = nil }
local function god_toggle()
    local ok, err = pcall(function()
        local pawn = UEHelpers.GetPlayerController().Pawn
        local s = pawn.AttributeSetBase
        if not god.on then
            god.on, god.gen = true, god.gen + 1
            god.base, god.cur = s.Health_Max.BaseValue, s.Health_Max.CurrentValue
            s.Health_Max.BaseValue = god.base * 100
            s.Health_Max.CurrentValue = god.cur * 100
            s.Health.BaseValue = god.cur * 100
            s.Health.CurrentValue = god.cur * 100
            god.atk_base, god.atk_cur = s.Attack.BaseValue, s.Attack.CurrentValue
            s.Attack.BaseValue = god.atk_base * 1000
            s.Attack.CurrentValue = god.atk_cur * 1000
            log("GOD on (Health_Max %.0f -> %.0f, Attack %.0f -> %.0f)", god.cur, god.cur * 100, god.atk_cur, god.atk_cur * 1000)
            local gen = god.gen
            LoopAsync(100, function()
                if not god.on or god.gen ~= gen then return true end
                ExecuteInGameThread(function()
                    pcall(function()
                        local p = UEHelpers.GetPlayerController().Pawn
                        local a = p.AttributeSetBase
                        -- A respawn or level load resets attributes: re-apply the boost.
                        if a.Health_Max.CurrentValue < god.cur * 50 then
                            a.Health_Max.BaseValue = a.Health_Max.BaseValue * 100
                            a.Health_Max.CurrentValue = a.Health_Max.CurrentValue * 100
                        end
                        if a.Attack.CurrentValue < god.atk_cur * 500 then
                            a.Attack.BaseValue = a.Attack.BaseValue * 1000
                            a.Attack.CurrentValue = a.Attack.CurrentValue * 1000
                        end
                        local m = a.Health_Max.CurrentValue
                        if a.Health.CurrentValue < m then
                            a.Health.BaseValue = m
                            a.Health.CurrentValue = m
                        end
                    end)
                end)
                return false
            end)
        else
            god.on = false
            s.Health_Max.BaseValue = god.base
            s.Health_Max.CurrentValue = god.cur
            s.Health.BaseValue = god.cur
            s.Health.CurrentValue = god.cur
            s.Attack.BaseValue = god.atk_base
            s.Attack.CurrentValue = god.atk_cur
            log("GOD off (Health_Max %.0f, Attack %.0f restored)", god.cur, god.atk_cur)
        end
    end)
    if not ok then log("god toggle failed: %s", tostring(err)) end
end

-- F6: read-only look at the Realm of Mirage (Jhsy) teleport target; does NOT teleport.
local function jhsy_probe()
    local ok, err = pcall(function()
        local tp = FindFirstOf("PBZTeleportSubsystem")
        log("TeleportSubsystem: %s", name_of(tp))
        local pawn = UEHelpers.GetPlayerController().Pawn
        local inJ = tp:IsInJhsy(pawn)
        log("  IsInJhsy=%s", tostring(inJ))
        local out, cam = {}, {}
        tp:GetJhsyBellTeleportTransform(out, cam)
        local t = out.Translation or {}
        log("  Jhsy bell transform: %s %s %s", tostring(t.X), tostring(t.Y), tostring(t.Z))
        log("  bell: %s", name_of(tp:GetBell()))
    end)
    if not ok then log("jhsy probe failed: %s", tostring(err)) end
end

-- ---------------------------------------------------------------- arena scouting
-- F5: every bell in DT_BellData with name, map, location, activation state.
-- Only simple-typed getters are called (FName / FText / FVector / bool); the struct-returning
-- GetBellData is avoided (copying FBellDataStruct through Lua corrupted the heap last run).
local function unwrap(v)
    if type(v) == "userdata" then
        local ok, g = pcall(function() return v:get() end)
        if ok and g ~= nil then return g end
    end
    return v
end

local function bell_dump()
    local ok, err = pcall(function()
        local bm = FindFirstOf("BellManager")
        log("BellManager: %s", name_of(bm))
        if not valid(bm) then return end
        local path = "/Game/PBZContent/DataTable/UI/DT_BellData.DT_BellData"
        local dt = StaticFindObject(path)
        if not valid(dt) then
            pcall(LoadAsset, "/Game/PBZContent/DataTable/UI/DT_BellData")
            dt = StaticFindObject(path)
        end
        log("  DT_BellData: %s", name_of(dt))
        if not valid(dt) then return end
        local lib = StaticFindObject("/Script/Engine.Default__DataTableFunctionLibrary")
        local out = {}
        lib:GetDataTableRowNames(dt, out)
        local raw = out
        if #raw == 0 and out.OutRowNames then raw = out.OutRowNames end
        local ids = {}
        local function push(e)
            e = unwrap(e)
            if type(e) == "userdata" and e.ToString then ids[#ids + 1] = e end
        end
        if type(raw) == "table" then
            for _, e in ipairs(raw) do push(e) end
        elseif raw and raw.ForEach then
            raw:ForEach(function(_, e) push(e) end)
        end
        log("  rows: %d (first: %s)", #ids, ids[1] and ids[1]:ToString() or "-")
        if #ids == 0 then return end
        local f = io.open(MOD_DIR .. "bells.tsv", "w")
        if f then f:write("id\tactive\tmap\tlevel\tname\tlocation\n") end
        for i, id in ipairs(ids) do
            local okb, line = pcall(function()
                return string.format("%s\t%s\t%s\t%s\t%s\t%s", id:ToString(),
                    tostring(bm:IsBellActivated(id)), str(bm:GetMapIDFromBellID(id)),
                    str(bm:GetLevelNameFromBellID(id)), str(bm:GetBellNameFromBellID(id)),
                    vec(bm:GetBellLocationFromBellID(id)))
            end)
            if not okb then line = id:ToString() .. "\tERR " .. tostring(line) end
            if f then f:write(line .. "\n") end
            if i <= 5 then log("  bell %s", line) end
        end
        if f then f:close() end
        log("  wrote bells.tsv (%d rows)", #ids)

        -- The BellManager getters above came back empty last run; read its properties instead.
        local act = {}
        pcall(function()
            bm.ActivateBellIDs:ForEach(function(_, e) act[#act + 1] = str(unwrap(e)) end)
        end)
        log("  ActivateBellIDs (%d): %s", #act, table.concat(act, ", "))
        local okr, rec = pcall(function() return bm.RecentlyInteractedBellID:ToString() end)
        log("  RecentlyInteractedBellID: %s", okr and rec or tostring(rec))

        -- Bell actors loaded in this world: BellID + real location.
        local world = UEHelpers.GetWorld():GetFullName():match("/Game/Maps/([^.]+)") or "?"
        local bells = FindAllOf("MelodiousBell") or {}
        log("  MelodiousBell actors loaded: %d", #bells)
        for _, b in ipairs(bells) do
            local okl, line = pcall(function()
                local tags = {}
                pcall(function()
                    b.FlowTagMap:ForEach(function(k, v)
                        tags[#tags + 1] = str(unwrap(k).TagName) .. "->" .. str(unwrap(v).TagName)
                    end)
                end)
                pcall(function()
                    local fc = b.FlowComponent
                    if valid(fc) then
                        fc.IdentityTags.GameplayTags:ForEach(function(_, t) tags[#tags + 1] = "id:" .. str(unwrap(t).TagName) end)
                    end
                end)
                -- Every flow component on the bell and the flow asset it runs (e.g. BPF_WanJunKe_Bell = appears after that boss).
                pcall(function()
                    local fcls = StaticFindObject("/Script/Flow.FlowComponent")
                    b:K2_GetComponentsByClass(fcls):ForEach(function(_, e)
                        local c = unwrap(e)
                        local rf = "nil"
                        pcall(function() if valid(c.RootFlow) then rf = c.RootFlow:GetFName():ToString() end end)
                        tags[#tags + 1] = "flow:" .. c:GetFName():ToString() .. "=" .. rf
                    end)
                end)
                return string.format("%s\t%s\t%s\t%s\tcrane=%s\thidden=%s\t%s", world, b.BellID:ToString(),
                    b:GetClass():GetFName():ToString(), vec(b:K2_GetActorLocation()), tostring(b.bIsCraneBell),
                    tostring(b.bHidden), table.concat(tags, ","))
            end)
            line = okl and line or ("ERR " .. tostring(line))
            log("  bell actor %s", line)
            append_file("bell_actors.tsv", line)
        end
    end)
    if not ok then log("bell dump failed: %s", tostring(err)) end
end

-- F4: mark the spot the player stands on as an arena candidate (appends to arenas.tsv).
local mark_count = 0
local function mark_spot()
    local ok, err = pcall(function()
        local pc = UEHelpers.GetPlayerController()
        local pawn = pc.Pawn
        local loc = pawn:K2_GetActorLocation()
        local rot = pc:GetControlRotation()
        local world = UEHelpers.GetWorld():GetFullName()
        local tod = "?"
        local sky = FindFirstOf("Ultra_Dynamic_Sky_C")
        if valid(sky) then tod = tostring(sky["Time of Day"]) end
        local tp = FindFirstOf("PBZTeleportSubsystem")
        local inJ = valid(tp) and tp:IsInJhsy(pawn) or false
        mark_count = mark_count + 1
        local line = string.format("%d\t%s\t%s\tyaw=%.0f\ttod=%s\tjhsy=%s", mark_count, world, vec(loc),
            rot.Yaw or 0, tod, tostring(inJ))
        log("MARK %s", line)
        append_file("arenas.tsv", line)
    end)
    if not ok then log("mark failed: %s", tostring(err)) end
end

-- F3: cycle Ultra Dynamic Sky time of day (morning / noon / dusk / night / original).
local TOD = { 800, 1200, 1730, 2200 }
local tod_i, tod_orig = 0, nil
local function cycle_tod()
    local ok, err = pcall(function()
        local sky = FindFirstOf("Ultra_Dynamic_Sky_C")
        log("sky: %s", name_of(sky))
        if not valid(sky) then return end
        if tod_orig == nil then tod_orig = sky["Time of Day"] end
        tod_i = tod_i % (#TOD + 1) + 1
        local v = TOD[tod_i] or tod_orig
        sky["Time of Day"] = v
        log("  time of day %s -> %s (animate=%s)", tostring(tod_orig), tostring(sky["Time of Day"]),
            tostring(sky["Animate Time Of Day"]))
    end)
    if not ok then log("tod failed: %s", tostring(err)) end
end

-- F2: round trip to the Realm of Mirage through the game's own teleport (press again to return).
local function jhsy_trip()
    local ok, err = pcall(function()
        local tp = FindFirstOf("PBZTeleportSubsystem")
        local pawn = UEHelpers.GetPlayerController().Pawn
        if tp:IsInJhsy(pawn) then
            local out = {}
            log("leaving Realm of Mirage")
            tp:TeleportToBellFromJhsy(out)
        else
            local out, cam = {}, {}
            tp:GetJhsyBellTeleportTransform(out, cam)
            log("entering Realm of Mirage at %s", vec(out.Translation))
            tp:TeleportToJhsy(out)
        end
    end)
    if not ok then log("jhsy trip failed: %s", tostring(err)) end
end

-- ================================================================ round 12
local function obj_path(o) return (o:GetFullName():gsub("^%S+%s+", "")) end
local function to_text(s)
    local ktl = StaticFindObject("/Script/Engine.Default__KismetTextLibrary")
    return ktl:Conv_StringToText(s)
end

-- (A) Bell menu entry: add a "残影试炼" button to the bell menu; clicking it swaps the menu's
-- options for a test sub-menu (same buttons, same look, gamepad navigation), "返回" restores them.
local my_btns = {}      -- button full name -> handler
local sub = nil         -- { box, hidden = {widgets}, added = {widgets} }

local function slot_copy(from, to)
    pcall(function()
        local a, b = from.Slot, to.Slot
        b:SetPadding(a.Padding)
        b:SetHorizontalAlignment(a.HorizontalAlignment)
        b:SetVerticalAlignment(a.VerticalAlignment)
    end)
end

local function new_button(menu, text, handler)
    local wbl = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    local b = wbl:Create(menu, menu.TeleportBtn:GetClass(), UEHelpers.GetPlayerController())
    my_btns[b:GetFullName()] = handler
    return b
end

-- The button's PreConstruct writes its default text when it joins the tree, so set the label after adding it
-- (and once more a moment later), on every text widget the button owns.
local function set_label(b, text)
    local function apply()
        local t = to_text(text)
        pcall(function() b:UpdateButtonText(t) end)
        pcall(function() b:SetWidgetText({ ChoiceText = t, ChoiceIndex = 0, Last = false }) end)
        pcall(function() b.PBZCommonLocRichText_39:SetText(t) end)
        pcall(function() b.Selected:SetText(t) end)
    end
    apply()
    ExecuteWithDelay(150, function() ExecuteInGameThread(function()
        if valid(b) then apply() pcall(function() b:DoSelectedAppearance(false) end) end
    end) end)
end

-- Join the menu's own button group so selecting one option deselects the others (native selected/unselected look).
local menu_groups = {}
local function join_group(menu, b)
    local ok, err = pcall(function()
        local key = menu:GetFullName()
        if menu_groups[key] == nil then
            menu_groups[key] = false
            for _, g in ipairs(FindAllOf("CommonButtonGroupBase") or {}) do
                local okf, idx = pcall(function() return g:FindButtonIndex(menu.TeleportBtn) end)
                if okf and idx and idx >= 0 then menu_groups[key] = g break end
            end
            log("MENU button group: %s", menu_groups[key] and name_of(menu_groups[key]) or "not found")
        end
        if menu_groups[key] then menu_groups[key]:AddWidget(b) end
        b:DoSelectedAppearance(false)
    end)
    if not ok then log("MENU join group failed: %s", tostring(err)) end
end

local function children(box)
    local out = {}
    for i = 0, box:GetChildrenCount() - 1 do out[#out + 1] = box:GetChildAt(i) end
    return out
end

local function sub_close()
    if not sub then return end
    for _, w in ipairs(sub.added) do pcall(function() sub.box:RemoveChild(w) end) end
    for _, h in ipairs(sub.hidden) do pcall(function() h.w:SetVisibility(h.vis) end) end
    pcall(function() sub.focus:SetFocus() end)
    log("MENU sub-menu closed, original options restored")
    sub = nil
end

local function sub_open(menu, entry)
    local box = entry:GetParent()
    sub = { box = box, hidden = {}, added = {}, focus = entry }
    for _, w in ipairs(children(box)) do
        if w:IsVisible() then sub.hidden[#sub.hidden + 1] = { w = w, vis = w:GetVisibility() }; w:SetVisibility(1) end -- Collapsed
    end
    for _, item in ipairs({ "单挑", "连战", "试炼", "返回" }) do
        local b = new_button(menu, item, function()
            log("MENU picked: %s", item)
            if item == "返回" then sub_close() end
        end)
        box:AddChildToVerticalBox(b)
        slot_copy(entry, b)
        set_label(b, item)
        join_group(menu, b)
        sub.added[#sub.added + 1] = b
    end
    pcall(function() sub.added[1]:SetFocus() end)
    log("MENU sub-menu opened (%d options hidden)", #sub.hidden)
end

local function inject_bell_menu(menu)
    local ok, err = pcall(function()
        -- Top level of the bell menu: anchor on the always-present Teleport option and climb to its VerticalBox.
        local anchor = menu.TeleportBtn
        local box = anchor:GetParent()
        local guard = 0
        while valid(box) and box:GetClass():GetFName():ToString() ~= "VerticalBox" and guard < 8 do
            anchor, box, guard = box, box:GetParent(), guard + 1
        end
        if not valid(box) then log("MENU: no VerticalBox above TeleportBtn") return end
        log("MENU bell menu container %s (%s), %d children:", box:GetFName():ToString(), box:GetClass():GetFName():ToString(), box:GetChildrenCount())
        local kids = children(box)
        for i, w in ipairs(kids) do log("  [%d] %s vis=%s", i - 1, w:GetFName():ToString(), tostring(w:IsVisible())) end
        local entry
        entry = new_button(menu, "强敌挑战", function() sub_open(menu, entry) end)
        -- No InsertChildAt in UMG: pull the widgets after the anchor, add ours, put them back.
        local after, seen = {}, false
        for _, w in ipairs(kids) do
            if seen then after[#after + 1] = { w = w, pad = w.Slot.Padding, h = w.Slot.HorizontalAlignment, v = w.Slot.VerticalAlignment } end
            if w:GetFullName() == anchor:GetFullName() then seen = true end
        end
        for _, a in ipairs(after) do box:RemoveChild(a.w) end
        box:AddChildToVerticalBox(entry)
        slot_copy(anchor, entry)
        set_label(entry, "强敌挑战")
        join_group(menu, entry)
        for _, a in ipairs(after) do
            box:AddChildToVerticalBox(a.w)
            pcall(function() a.w.Slot:SetPadding(a.pad) a.w.Slot:SetHorizontalAlignment(a.h) a.w.Slot:SetVerticalAlignment(a.v) end)
        end
        log("MENU injected entry after %s", anchor:GetFName():ToString())
    end)
    if not ok then log("MENU inject failed: %s", tostring(err)) end
end

pcall(function()
    NotifyOnNewObject("/Game/PBZContent/UI/InGame/Bell/W_BellMenu.W_BellMenu_C", function(menu)
        sub = nil
        ExecuteWithDelay(400, function()
            ExecuteInGameThread(function()
                -- The real mod (BossRush) owns the bell menu entry when it is installed.
                local f = io.open(MOD_DIR .. "../BossRush/enabled.txt", "r")
                if f then f:close() return end
                if valid(menu) and valid(menu.TeleportBtn) then inject_bell_menu(menu) else log("MENU: menu not ready") end
            end)
        end)
    end)
end)

local last_click = 0
local function on_button(self)
    local ok, b = pcall(function() return self:get() end)
    if not ok or not valid(b) then return end
    local h = my_btns[b:GetFullName()]
    if not h then return end
    local now = os.clock()
    if now - last_click < 0.2 then return end -- both hooks may fire for one press
    last_click = now
    ExecuteInGameThread(function() pcall(h) end)
end
for _, fn in ipairs({ "/Script/CommonUI.CommonButtonBase:HandleButtonClicked", "/Script/CommonUI.CommonButtonBase:BP_OnClicked" }) do
    local ok, err = pcall(RegisterHook, fn, on_button)
    log("hook %s: %s", fn, ok and "ok" or tostring(err))
end

-- (B) Death events: log every die/dead/death/respawn/kill function the game calls on the player or a boss.
local hooked = {}
local function arm_death_hooks(actor, who)
    local c = actor:GetClass()
    local n = 0
    while valid(c) do
        local cname = c:GetFName():ToString()
        if cname == "Actor" or cname == "Pawn" or cname == "Character" then break end
        pcall(function()
            c:ForEachFunction(function(f)
                local fname = f:GetFName():ToString()
                local low = fname:lower()
                if (low:find("die") or low:find("dead") or low:find("death") or low:find("respawn") or low:find("kill"))
                    and not low:find("^get") and not low:find("puerts") and not low:find("ubergraph") then
                    local path = obj_path(c) .. ":" .. fname
                    if not hooked[path] then
                        hooked[path] = true
                        local ok = pcall(RegisterHook, path, function(self)
                            local s = "?"
                            pcall(function() s = self:get():GetClass():GetFName():ToString() end)
                            log("DEATH %s %s.%s (on %s) t=%.1f", who, cname, fname, s, os.clock())
                        end)
                        if ok then n = n + 1 end
                    end
                end
            end)
        end)
        c = c:GetSuperStruct()
    end
    log("DEATH hooks armed for %s (%s): %d new", who, actor:GetClass():GetFName():ToString(), n)
end

-- (C) Record how the game itself calls TeleportTo (level name format, bell ID format).
local tp_seen = nil
pcall(function()
    RegisterHook("/Script/ProjectPBZ.PBZSaveLoadSubsystem:TeleportTo", function(self, level, xf, bell)
        local l, b, t = "?", "?", "?"
        pcall(function() l = level:get():ToString() end)
        pcall(function() b = bell:get():ToString() end)
        pcall(function() t = vec(xf:get().Translation) end)
        tp_seen = l
        log("TELEPORT game call: level=%s bell=%s at %s", l, b, t)
    end)
end)

-- (D) F6: cross-map teleport through the arena list, then back to where you started.
local ARENAS = {
    { "/Game/Maps/B02/PBZ_Xigu_WP", "NLES_023", -53341, 258560, -24485, 0 },
    { "/Game/Maps/B03/PBZ_Fujizhilin_WP", "LZSJ_010", 14830, 154293, -1974, 318 },
    { "/Game/Maps/B04_05/PBZ_Zhengdaodaying_WP", "SXC_01_06", -47348, 104312, 950, -18 },
    { "/Game/Maps/B04_05/PBZ_Zhengdaodaying_WP", "YXZR_006", 29167, 71243, 6937, 118 },
    { "/Game/Maps/B08_09_10/PBZ_Pangzhen_WP", "MGH_008", -70022, 72581, 927, 57 },
    { "/Game/Maps/DengDingShanDao/PBZ_DengDingShanDao_WP", "JJYBP_005", -61980, -56140, 18381, 81 },
}
local arena_i, origin = 0, nil
local function arena_trip()
    local ok, err = pcall(function()
        local pawn = UEHelpers.GetPlayerController().Pawn
        local world = UEHelpers.GetWorld():GetFullName():match("(/Game/Maps/[^.]+)")
        local target
        if arena_i == 0 then
            local bm = FindFirstOf("BellManager")
            local bell = "None"
            pcall(function() bell = bm.RecentlyInteractedBellID:ToString() end)
            local l, r = pawn:K2_GetActorLocation(), pawn:K2_GetActorRotation()
            origin = { world, bell, l.X, l.Y, l.Z, r.Yaw }
            log("ARENA origin saved: %s bell=%s at %s", world, bell, vec(l))
        end
        arena_i = arena_i + 1
        if arena_i > #ARENAS then
            target, arena_i = origin, 0
            log("ARENA returning to origin")
        else
            target = ARENAS[arena_i]
        end
        local level = target[1]
        if tp_seen and not tp_seen:find("^/") then level = level:match("([^/]+)$") end
        local bell = target[2]
        if not bell:find("Bell") then bell = "Bell_" .. bell end
        local yaw = math.rad(target[6])
        local xf = {
            Rotation = { X = 0, Y = 0, Z = math.sin(yaw / 2), W = math.cos(yaw / 2) },
            Translation = { X = target[3], Y = target[4], Z = target[5] },
            Scale3D = { X = 1, Y = 1, Z = 1 },
        }
        log("ARENA %d -> %s bell=%s at %.0f %.0f %.0f", arena_i, level, bell, target[3], target[4], target[5])
        local ss = FindFirstOf("PBZSaveLoadSubsystem")
        ss:TeleportTo(FName(level), xf, FName(bell))
        ExecuteWithDelay(15000, function()
            ExecuteInGameThread(function()
                pcall(function()
                    local p = UEHelpers.GetPlayerController().Pawn
                    log("ARENA after 15s: world=%s at %s", UEHelpers.GetWorld():GetFullName():match("/Game/Maps/([^.]+)") or "?", vec(p:K2_GetActorLocation()))
                end)
            end)
        end)
    end)
    if not ok then log("arena trip failed: %s", tostring(err)) end
end

-- Death hooks are armed on the player at the first F7 and on every spawned boss.
local orig_spawn = spawn_test
spawn_test = function()
    pcall(function() arm_death_hooks(UEHelpers.GetPlayerController().Pawn, "player") end)
    orig_spawn()
    pcall(function() local b = last_boss() if valid(b) then arm_death_hooks(b, "boss") end end)
    -- Bosses with "Fake Death Enabled" stay at 0 HP until the player lands an execution (heavy attack).
    -- Turn it off so they die as soon as HP reaches 0.
    pcall(function()
        local b = last_boss()
        local dc = b["Death Component"]
        local before = dc["Fake Death Enabled"]
        dc["Fake Death Enabled"] = false
        log("FAKEDEATH %s: was %s, now %s", b:GetClass():GetFName():ToString(), tostring(before), tostring(dc["Fake Death Enabled"]))
    end)
end

-- F3: preview wb_settlement (a logic-free settlement layout in the game files). Every text block shows its own
-- name so a screenshot tells which slot is where; press F3 again to close.
local settle_w = nil
local function settlement_preview()
    local ok, err = pcall(function()
        if valid(settle_w) then settle_w:RemoveFromParent() settle_w = nil log("SETTLE closed") return end
        local cls = load_class("/Game/PBZContent/UI/UINew/HUD/wb_settlement.wb_settlement_C")
        if not valid(cls) then log("SETTLE class not found") return end
        local wbl = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
        local w = wbl:Create(UEHelpers.GetWorld(), cls, UEHelpers.GetPlayerController())
        w:AddToViewport(60)
        settle_w = w
        local ktl = StaticFindObject("/Script/Engine.Default__KismetTextLibrary")
        local names = {}
        w:GetClass():ForEachProperty(function(p)
            local n = p:GetFName():ToString()
            local okv, v = pcall(function() return w[n] end)
            if okv and type(v) == "userdata" and valid(v) then
                local cn = v:GetClass():GetFName():ToString()
                names[#names + 1] = n .. "(" .. cn .. ")"
                if cn:find("TextBlock") then pcall(function() v:SetText(ktl:Conv_StringToText(n)) end) end
            end
        end)
        pcall(function() w:PlayAnimation(w.show, 0, 1, 0, 1, false) end)
        log("SETTLE shown, widgets: %s", table.concat(names, ", "))
    end)
    if not ok then log("settlement preview failed: %s", tostring(err)) end
end

RegisterKeyBind(Key.F1, function() ExecuteInGameThread(god_toggle) end)
RegisterKeyBind(Key.F9,function() ExecuteInGameThread(stats_dump) end)
-- level_test (direct Level write) proved useless in run 11; no longer bound.
RegisterKeyBind(Key.F10, function() ExecuteInGameThread(scale_test) end)
RegisterKeyBind(Key.F2, function() ExecuteInGameThread(jhsy_trip) end)
RegisterKeyBind(Key.F3, function() ExecuteInGameThread(settlement_preview) end)
RegisterKeyBind(Key.F4, function() ExecuteInGameThread(mark_spot) end)
RegisterKeyBind(Key.F5, function() ExecuteInGameThread(bell_dump) end)
RegisterKeyBind(Key.F6, function() ExecuteInGameThread(arena_trip) end)
RegisterKeyBind(Key.F7, function() ExecuteInGameThread(spawn_test) end)
RegisterKeyBind(Key.F8, function() ExecuteInGameThread(report) end)

-- Auto: once a player pawn exists, wait a bit, report, then generate the SDK once.
local fired = false
LoopAsync(2000, function()
    if fired then return true end
    local pc = UEHelpers.GetPlayerController()
    if valid(pc) and valid(pc.Pawn) and not pc.Pawn:GetClass():GetFName():ToString():find("Spectator") then
        fired = true
        ExecuteWithDelay(8000, function()
            ExecuteInGameThread(function()
                report()
                generate_sdk_once()
            end)
        end)
        return true
    end
    return false
end)

log("loaded, mod dir %s", MOD_DIR)
