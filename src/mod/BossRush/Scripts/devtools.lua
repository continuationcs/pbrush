-- Development tools (never shipped: src/tools/build_release.py leaves this file out). Single keys F2-F8, no
-- combinations (user decision, 2026-11-14). Taken elsewhere: F10 (UE4SS console, ConsoleEnablerMod), F11 (the
-- game), F12 (Steam screenshot); UE4SS's own keys use Ctrl (Ctrl+R reload, Ctrl+O GUI, Ctrl+J / Ctrl+H dumps).
--   F1  god mode lives in god.lua (shipped: a release build binds it when its switch file exists)
--   F2  mark the spot the player stands on and the direction they face, for a new arena (marks.tsv), and
--       survey it right there (grades shown on screen)
--   F3  arena survey: open, level ground around every arena's player and boss points (doc/DESIGN.md 5.0a);
--       only the FOCUS arena when one is set
--   F4  raise an error inside the mod, to check the stop path (log, tip strip, entry removed, run ended)
--   F5  go to the arena in FOCUS (for one whose bell the bell menu cannot reach, e.g. 龙柱)
--   F6  every run in the Realm of Mirage, on / off (to test deaths and the way back there)
--   F7  start-up check (health.lua): treat the first open boss as missing from the game; it leaves the lists
--   F8  start-up check: run it again with a made-up core part missing, to see the stop a game update causes
-- Results: [BossRush] DEV lines in UE4SS.log and dev.tsv / marks.tsv in the mod folder.
local U = require("util")
local ui = require("ui")
local god = require("god")
local UEHelpers = require("UEHelpers")

local M = {}

local DIR = U.MOD_DIR

local function append(file, line)
    local f = io.open(DIR .. file, "a")
    if f then f:write(line .. "\n") f:close() end
end

-- The arena being worked on (arenas.lua key), or nil. 龙柱's bell cannot be travelled to from the bell menu
-- (2026-11-14), so F5 takes the player there to mark a new spot, and F3 re-surveys only it.
local FOCUS = nil      -- e.g. "xigu_pillar" (done 2026-11-14)

local function out(line)
    U.log("DEV %s", line)
    append("dev.tsv", os.date("%H:%M:%S") .. "\t" .. line)
end

function M.install(run, arenas, health, roster)
    -- ------------------------------------------------------------ mark a spot (F2)
    -- Map, position and facing (the camera's yaw: where the boss should appear) of the player, for arenas.lua.
    local function mark()
        local pc = UEHelpers.GetPlayerController()
        local l = U.pawn():K2_GetActorLocation()
        local yaw = pc:GetControlRotation().Yaw
        local line = string.format("%s\t%.0f\t%.0f\t%.0f\tyaw %.0f", tostring(U.world_path()), l.X, l.Y, l.Z, yaw)
        append("marks.tsv", os.date("%Y-%m-%d %H:%M:%S") .. "\t" .. line)
        out("mark " .. line)
        ui.toast(string.format("调试：已标点 %.0f %.0f %.0f，朝向 %.0f，测量中", l.X, l.Y, l.Z, yaw), 3)
        return { key = "mark", x = l.X, y = l.Y, z = l.Z, yaw = yaw }
    end

    -- ------------------------------------------------------------ arena survey (F3)
    -- Travels to every arena (not the Realm of Mirage) and measures, from where the player stands and from where
    -- the boss appears (run.SPAWN_AHEAD, 12 m ahead), how far the ground stays open in 16 directions: walkable (navigation mesh),
    -- level (no step or slope over MAX_STEP_DZ between samples) and unobstructed (the path there is not more
    -- than DETOUR times the straight line). One direction per tick. Then back to the starting bell.
    -- F2 measures the spot just marked the same way, where the player stands (no travel).
    local DIRS, STEP, REACH = 16, 200, 3000           -- cm
    local MAX_STEP_DZ = 150
    local DETOUR = 1.3
    local OPEN_ENOUGH = 1500                          -- a direction counts as open from 15 m
    local BOSS_AHEAD = run.SPAWN_AHEAD
    -- The player's spot must be at least this far from the nearest bell (user request 2026-11-15: no fight right
    -- next to a bell; DESIGN 5.0a). Closer is graded 差 whatever the ground.
    local BELL_MIN = 1200
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

    -- Grade by doc/DESIGN.md 5.0a. bell: distance to the nearest bell (cm), only for the player's spot.
    local function grade(enough, min_m, dz_m, bell)
        if bell and bell < BELL_MIN then return "差" end
        if enough >= 14 and min_m >= 10 and dz_m <= 3 then return "良" end
        if enough >= 11 and min_m >= 6 and dz_m <= 4 then return "可" end
        return "差"
    end

    -- bell: { dist, name } of the nearest bell, for the player's spot (dist nil: no bell loaded nearby).
    local function summary(arena, label, res, bell)
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
        local g = grade(enough, opens[1] / 100, maxdz / 100, bell and bell.dist)
        local bell_text = ""
        if bell then
            bell_text = bell.dist and string.format("\tbell %.0f m (%s)", bell.dist / 100, bell.name) or "\tbell none loaded"
        end
        out(string.format("survey\t%s\t%s\t%s\topen>=15m %d/%d\tmin %.0f m\tmedian %.0f m\tmax dz %.1f m%s\t%s\tdirs %s",
            arena.key, label, g, enough, #res, opens[1] / 100, opens[math.floor(#opens / 2) + 1] / 100, maxdz / 100,
            bell_text, table.concat(why, ", "), table.concat(dirs, " ")))
        local line = string.format("%s %s %d/16 最窄 %.0f m", label == "player" and "站位" or "首领点", g, enough, opens[1] / 100)
        if bell and bell.dist then line = line .. string.format(" 离铃铛 %.0f m", bell.dist / 100) end
        return line
    end

    local surveying = false
    -- here: a spot to measure where the player stands ({ key, x, y, z, yaw }), instead of travelling the arenas.
    local function survey(here)
        if surveying then return end
        if run.active() then out("survey: a challenge is running") return end
        local list = {}
        if here then
            list = { here }
        else
            for _, a in ipairs(arenas.all()) do
                if a.kind ~= "jhsy" and (not FOCUS or a.key == FOCUS) then list[#list + 1] = a end
            end
        end
        local pl = U.pawn():K2_GetActorLocation()
        local home = { map = U.world_path(), x = pl.X, y = pl.Y, z = pl.Z, bell = "None" }
        pcall(function() home.bell = FindFirstOf("BellManager").RecentlyInteractedBellID:ToString() end)
        surveying = true
        local was_god = god.on()
        if not was_god then god.set(true) end
        out(string.format("survey: %d arenas", #list))
        -- A scenic arena is offered only once its bell is rung: show whether each bell id is in the rung set.
        local rung = U.active_bells()
        for _, a in ipairs(list) do
            if a.bell then
                out(string.format("survey\t%s\tbell %s rung %s", a.key, U.bell_name(a.bell), tostring(rung[U.bell_name(a.bell)] == true)))
            end
        end
        local i, step, ticks, still, jobs, res = 0, "go", 0, 0, nil, nil
        U.every(100, function()
            ticks = ticks + 1
            if step == "go" then
                i = i + 1
                if i > #list and here then
                    if not was_god then god.set(false) end
                    surveying = false
                    out("survey: done")
                    return true
                end
                if i > #list then
                    FindFirstOf("PBZSaveLoadSubsystem"):TeleportTo(FName(home.map), U.transform(home.x, home.y, home.z, 0), FName(home.bell))
                    step, ticks = "home", 0
                    return false
                end
                local a = list[i]
                if here then step, ticks, still = "wait", 0, 0 return false end
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
                    local bd, bn = U.nearest_bell(p)
                    res.bell = { dist = bd, name = bn }
                    for d = 0, DIRS - 1 do jobs[#jobs + 1] = { "player", p, a.yaw + d * 360 / DIRS } end
                    if b then
                        for d = 0, DIRS - 1 do jobs[#jobs + 1] = { "boss", b, a.yaw + d * 360 / DIRS } end
                    else
                        out("survey\t" .. a.key .. string.format("\tboss point (%d m ahead) not on the navigation mesh", BOSS_AHEAD / 100))
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
                local lines = { summary(list[i], "player", res.player, res.bell) }
                if #res.boss > 0 then lines[#lines + 1] = summary(list[i], "boss", res.boss) end
                if here then ui.toast("调试：" .. table.concat(lines, "；"), 8) end
                step = "go"
            elseif step == "home" then
                local near = false
                pcall(function() near = U.dist(U.pawn():K2_GetActorLocation(), { X = home.x, Y = home.y, Z = home.z }) < 2000 end)
                if (near and not run.loading()) or ticks > 900 then
                    if not was_god then god.set(false) end
                    surveying = false
                    out("survey: done")
                    return true
                end
            end
            return false
        end)
    end

    U.key(Key.F2, function() survey(mark()) end)
    U.key(Key.F3, function() survey() end)
    U.key(Key.F4, function() error("devtools: forced error (F4)") end)
    U.key(Key.F5, function()
        local a
        for _, x in ipairs(arenas.all()) do if x.key == FOCUS then a = x end end
        if not a then out("go: no FOCUS arena") ui.toast("调试：未设置 FOCUS 场地", 2) return end
        if run.active() then out("go: a challenge is running") return end
        out("go to " .. a.key)
        ui.toast("调试：前往 " .. a.zh, 2)
        FindFirstOf("PBZSaveLoadSubsystem"):TeleportTo(FName(a.map), U.transform(a.x, a.y, a.z, a.yaw), FName(U.bell_name(a.bell)))
    end)
    -- F6: runs go to the Realm of Mirage (the fallback arena, otherwise reached only when every arena is
    -- unavailable), to test what happens there (a player's death, the way back). Wraps arenas.pick, so the
    -- release code has nothing of it. A boss fought only on its own battlefield still goes there.
    local mirage = false
    local pick = arenas.pick
    arenas.pick = function(spec, ...)
        if mirage and not (spec.boss and arenas.own(spec.boss)) then
            for _, a in ipairs(arenas.all()) do
                if a.kind == "jhsy" then out("arena forced: Realm of Mirage (F6)") return a, false end
            end
        end
        return pick(spec, ...)
    end
    U.key(Key.F6, function()
        mirage = not mirage
        out("Realm of Mirage for every run: " .. tostring(mirage))
        ui.toast(mirage and "调试：挑战都在镜花水月" or "调试：恢复自动选场地", 2)
    end)
    -- F7 / F8: what a game update does to the mod (doc/UPDATE.md), without one.
    U.key(Key.F7, function()
        for _, b in ipairs(roster) do
            if b.state == "open" and health.boss_ok(b) and not b.part_of then
                health.pretend_missing(b.class)
                out("pretend missing: " .. b.id)
                ui.toast("调试：假装 " .. b.zh .. " 不在游戏中", 3)
                return
            end
        end
    end)
    U.key(Key.F8, function()
        out("start-up check with a made-up core part (F8)")
        health.start("/Script/ProjectPBZ.PBZSaveLoadSubsystem:BossRushNoSuchFunction (F8)")
    end)
    U.log("devtools ready: F2 mark and survey a spot, F3 arena survey%s, F4 forced error, F5 go to %s, F6 Realm of Mirage, F7 pretend a boss missing, F8 pretend the game changed",
        FOCUS and (" (" .. FOCUS .. " only)") or "", tostring(FOCUS))
end

return M
