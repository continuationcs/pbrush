-- Development tools (never shipped: src/tools/build_release.py leaves this file out). Keys F1-F4 (user decision,
-- 2026-11-14; the game itself uses F11):
--   F1  god mode: off -> unkillable + attack x10 -> unkillable + one-hit kills -> off
--   F2  mark the spot the player stands on and the direction they face, for a new arena (marks.tsv)
--   F3  arena survey: open, level ground around every arena's player and boss points (doc/DESIGN.md 5.0a)
--   F4  raise an error inside the mod, to check the stop path (log, tip strip, entry removed, run ended)
-- Results: [BossRush] DEV lines in UE4SS.log and dev.tsv / marks.tsv in the mod folder.
local U = require("util")
local ui = require("ui")
local UEHelpers = require("UEHelpers")

local M = {}

local DIR = (debug.getinfo(1, "S").source:match("^@(.*[\\/])Scripts[\\/]") or "")

local function append(file, line)
    local f = io.open(DIR .. file, "a")
    if f then f:write(line .. "\n") f:close() end
end

local function out(line)
    U.log("DEV %s", line)
    append("dev.tsv", os.date("%H:%M:%S") .. "\t" .. line)
end

function M.install(run, arenas)
    -- ------------------------------------------------------------ god mode (F1)
    -- Health_Max x100 and kept full; attack multiplied. Re-applied every 100 ms: a respawn or a level load resets
    -- the attributes. The arena survey turns mode 1 on while it runs.
    local MODES = { { mult = 10, label = "无敌 + 10 倍攻击" }, { mult = 1000, label = "无敌 + 一击必杀" } }
    local god = { mode = 0, gen = 0 }

    local function attrs() return U.pawn().AttributeSetBase end

    local function god_set(mode)
        local s = attrs()
        if god.mode == 0 and mode > 0 then
            god.hp_base, god.hp = s.Health_Max.BaseValue, s.Health_Max.CurrentValue
            god.atk_base, god.atk = s.Attack.BaseValue, s.Attack.CurrentValue
        end
        god.gen = god.gen + 1
        god.mode = mode
        if mode == 0 then
            s.Health_Max.BaseValue, s.Health_Max.CurrentValue = god.hp_base, god.hp
            s.Health.BaseValue, s.Health.CurrentValue = god.hp, god.hp
            s.Attack.BaseValue, s.Attack.CurrentValue = god.atk_base, god.atk
            out("god off")
            ui.toast("调试：关闭", 2)
            return
        end
        out("god " .. MODES[mode].label)
        ui.toast("调试：" .. MODES[mode].label, 2)
        local gen = god.gen
        U.every(100, function()
            if god.gen ~= gen then return true end
            pcall(function()
                local a = attrs()
                local mult = MODES[god.mode].mult
                if a.Health_Max.CurrentValue < god.hp * 50 then
                    a.Health_Max.BaseValue, a.Health_Max.CurrentValue = god.hp_base * 100, god.hp * 100
                end
                if math.abs(a.Attack.CurrentValue - god.atk * mult) > 1 then
                    a.Attack.BaseValue, a.Attack.CurrentValue = god.atk_base * mult, god.atk * mult
                end
                local hm = a.Health_Max.CurrentValue
                if a.Health.CurrentValue < hm then a.Health.BaseValue, a.Health.CurrentValue = hm, hm end
            end)
            return false
        end)
    end

    -- ------------------------------------------------------------ mark a spot (F2)
    -- Map, position and facing (the camera's yaw: where the boss should appear) of the player, for arenas.lua.
    local function mark()
        local pc = UEHelpers.GetPlayerController()
        local l = U.pawn():K2_GetActorLocation()
        local yaw = pc:GetControlRotation().Yaw
        local line = string.format("%s\t%.0f\t%.0f\t%.0f\tyaw %.0f", tostring(U.world_path()), l.X, l.Y, l.Z, yaw)
        append("marks.tsv", os.date("%Y-%m-%d %H:%M:%S") .. "\t" .. line)
        out("mark " .. line)
        ui.toast(string.format("调试：已标点 %.0f %.0f %.0f，朝向 %.0f", l.X, l.Y, l.Z, yaw), 3)
    end

    -- ------------------------------------------------------------ arena survey (F3)
    -- Travels to every arena (not the Realm of Mirage) and measures, from where the player stands and from where
    -- the boss appears (8 m ahead), how far the ground stays open in 16 directions: walkable (navigation mesh),
    -- level (no step or slope over MAX_STEP_DZ between samples) and unobstructed (the path there is not more
    -- than DETOUR times the straight line). One direction per tick. Then back to the starting bell.
    local DIRS, STEP, REACH = 16, 200, 3000           -- cm
    local MAX_STEP_DZ = 150
    local DETOUR = 1.3
    local OPEN_ENOUGH = 1500                          -- a direction counts as open from 15 m
    local BOSS_AHEAD = 800
    local EDGE_EXTENT = { X = 50, Y = 50, Z = 250 }   -- small: a sample off the mesh must fail, not snap back
    local CENTER_EXTENT = { X = 200, Y = 200, Z = 500 }
    local nav_path = "/Script/NavigationSystem.Default__NavigationSystemV1"

    local function project(nav, world, p, extent)
        local o = {}
        local ok, found = pcall(function() return nav:K2_ProjectPointToNavigation(world, p, o, nil, nil, extent) end)
        if ok and found and o.X then return { X = o.X, Y = o.Y, Z = o.Z } end
        return nil
    end

    local function path_len(nav, world, a, b)
        local len = nil
        pcall(function()
            local path = nav:FindPathToLocationSynchronously(world, a, b, nil, nil)
            if U.valid(path) and path:IsValid() and not path:IsPartial() then len = path:GetPathLength() end
        end)
        return len
    end

    -- From p along yaw: how far it stays open (cm), why it stopped, the largest height difference to p (cm).
    local function measure_dir(nav, world, p, yaw)
        local r = math.rad(yaw)
        local last, open, why, maxdz = p, 0, "30m+", 0
        for d = STEP, REACH, STEP do
            local want = { X = p.X + math.cos(r) * d, Y = p.Y + math.sin(r) * d, Z = last.Z }
            local q = project(nav, world, want, EDGE_EXTENT)
            if not q or math.sqrt((q.X - want.X) ^ 2 + (q.Y - want.Y) ^ 2) > 100 then why = "edge" break end
            if math.abs(q.Z - last.Z) > MAX_STEP_DZ then why = "step" break end
            local len = path_len(nav, world, p, q)
            if not len or len > d * DETOUR then why = "obstacle" break end
            maxdz = math.max(maxdz, math.abs(q.Z - p.Z))
            open, last = d, q
        end
        return open, why, maxdz
    end

    local function summary(arena, label, res)
        local opens, reasons, enough, maxdz = {}, {}, 0, 0
        for _, r in ipairs(res) do
            opens[#opens + 1] = r.open
            if r.open >= OPEN_ENOUGH then enough = enough + 1 end
            if r.why ~= "30m+" then reasons[r.why] = (reasons[r.why] or 0) + 1 end
            maxdz = math.max(maxdz, r.dz)
        end
        table.sort(opens)
        local why = {}
        for k, v in pairs(reasons) do why[#why + 1] = k .. " " .. v end
        local dirs = {}
        for _, r in ipairs(res) do dirs[#dirs + 1] = string.format("%.0f", r.open / 100) end
        out(string.format("survey\t%s\t%s\topen>=15m %d/%d\tmin %.0f m\tmedian %.0f m\tmax dz %.1f m\t%s\tdirs %s",
            arena.key, label, enough, #res, opens[1] / 100, opens[math.floor(#opens / 2) + 1] / 100, maxdz / 100,
            table.concat(why, ", "), table.concat(dirs, " ")))
    end

    local surveying = false
    local function survey()
        if surveying then return end
        if run.active() then out("survey: a challenge is running") return end
        local list = {}
        for _, a in ipairs(arenas.all()) do if a.kind ~= "jhsy" then list[#list + 1] = a end end
        local pl = U.pawn():K2_GetActorLocation()
        local home = { map = U.world_path(), x = pl.X, y = pl.Y, z = pl.Z, bell = "None" }
        pcall(function() home.bell = FindFirstOf("BellManager").RecentlyInteractedBellID:ToString() end)
        surveying = true
        local was_god = god.mode
        if was_god == 0 then god_set(1) end
        out(string.format("survey: %d arenas", #list))
        -- A scenic arena is offered only once its bell is rung: show whether each bell id is in the rung set.
        local rung = U.active_bells()
        for _, a in ipairs(list) do
            out(string.format("survey\t%s\tbell %s rung %s", a.key, U.bell_name(a.bell), tostring(rung[U.bell_name(a.bell)] == true)))
        end
        local i, step, ticks, still, jobs, res = 0, "go", 0, 0, nil, nil
        U.every(100, function()
            ticks = ticks + 1
            if step == "go" then
                i = i + 1
                if i > #list then
                    FindFirstOf("PBZSaveLoadSubsystem"):TeleportTo(FName(home.map), U.transform(home.x, home.y, home.z, 0), FName(home.bell))
                    step, ticks = "home", 0
                    return false
                end
                local a = list[i]
                FindFirstOf("PBZSaveLoadSubsystem"):TeleportTo(FName(a.map), U.transform(a.x, a.y, a.z, a.yaw), FName(U.bell_name(a.bell)))
                step, ticks, still = "wait", 0, 0
            elseif step == "wait" then
                local a = list[i]
                local near = false
                pcall(function() near = U.dist(U.pawn():K2_GetActorLocation(), { X = a.x, Y = a.y, Z = a.z }) < 1500 end)
                still = (near and not run.loading()) and still + 1 or 0
                if still >= 20 then
                    local nav, world = StaticFindObject(nav_path), UEHelpers.GetWorld()
                    local p = U.valid(nav) and project(nav, world, { X = a.x, Y = a.y, Z = a.z }, CENTER_EXTENT)
                    if not p then out("survey\t" .. a.key .. "\tno navigation mesh at the standing point") step = "go" return false end
                    local f = math.rad(a.yaw)
                    local b = project(nav, world, { X = p.X + math.cos(f) * BOSS_AHEAD, Y = p.Y + math.sin(f) * BOSS_AHEAD, Z = p.Z }, CENTER_EXTENT)
                    jobs, res = {}, { player = {}, boss = {} }
                    for d = 0, DIRS - 1 do jobs[#jobs + 1] = { "player", p, a.yaw + d * 360 / DIRS } end
                    if b then
                        for d = 0, DIRS - 1 do jobs[#jobs + 1] = { "boss", b, a.yaw + d * 360 / DIRS } end
                    else
                        out("survey\t" .. a.key .. "\tboss point (8 m ahead) not on the navigation mesh")
                    end
                    step = "measure"
                elseif ticks > 900 then
                    out("survey\t" .. a.key .. "\tnever arrived")
                    step = "go"
                end
            elseif step == "measure" then
                local job = table.remove(jobs, 1)
                if job then
                    local nav, world = StaticFindObject(nav_path), UEHelpers.GetWorld()
                    local open, why, dz = measure_dir(nav, world, job[2], job[3])
                    table.insert(res[job[1]], { open = open, why = why, dz = dz })
                    return false
                end
                summary(list[i], "player", res.player)
                if #res.boss > 0 then summary(list[i], "boss", res.boss) end
                step = "go"
            elseif step == "home" then
                local near = false
                pcall(function() near = U.dist(U.pawn():K2_GetActorLocation(), { X = home.x, Y = home.y, Z = home.z }) < 2000 end)
                if (near and not run.loading()) or ticks > 900 then
                    if was_god == 0 then god_set(0) end
                    surveying = false
                    out("survey: done")
                    return true
                end
            end
            return false
        end)
    end

    U.key(Key.F1, function() god_set((god.mode + 1) % (#MODES + 1)) end)
    U.key(Key.F2, mark)
    U.key(Key.F3, survey)
    U.key(Key.F4, function() error("devtools: forced error (F4)") end)
    U.log("devtools ready: F1 god mode, F2 mark a spot, F3 arena survey, F4 forced error")
end

return M
