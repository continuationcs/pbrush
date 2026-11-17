-- Development tools (never shipped: src/tools/build_release.py leaves this file out). Single keys, no
-- combinations (user decision, 2026-11-14). Taken elsewhere: F10 (UE4SS console, ConsoleEnablerMod), F11 (the
-- game), F12 (Steam screenshot); UE4SS's own keys use Ctrl (Ctrl+R reload, Ctrl+O GUI, Ctrl+J / Ctrl+H dumps).
--   F1  god mode lives in god.lua (shipped: a release build binds it when its switch file exists)
--   F2  go to the arena in FOCUS (for one whose bell the bell menu cannot reach, e.g. 龙柱)
--   F3  mark the spot the player stands on and the direction they face, for a new arena (marks.tsv), and
--       survey it right there (grades shown on screen)
--   F9  play the boss-defeat banner (斩), normal and red in turn
-- 2026-11-17 (user decisions; git history has the removed ones): the survey of every arena (old F3; all were
-- marked and surveyed with the mark key), F4 forced error, F6 every run in the Realm of Mirage and F7 / F8 a
-- boss / core part pretended missing were removed; mark and survey moved from F2 to F3, go to FOCUS from F5 to F2.
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
-- (2026-11-14), so F2 takes the player there to mark a new spot with F3.
local FOCUS = nil      -- e.g. "xigu_pillar" (done 2026-11-14)

local function out(line)
    U.log("DEV %s", line)
    append("dev.tsv", os.date("%H:%M:%S") .. "\t" .. line)
end

function M.install(run, arenas)
    -- ------------------------------------------------------------ mark a spot (F3)
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

    -- ------------------------------------------------------------ survey the marked spot (F3)
    -- Measures, from where the player stands and from where the boss appears (run.SPAWN_AHEAD, 12 m ahead), how
    -- far the ground stays open in 16 directions: walkable (navigation mesh), level (no step or slope over
    -- MAX_STEP_DZ between samples) and unobstructed (the path there is not more than DETOUR times the straight
    -- line). One direction per tick.
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
    -- a: the spot just marked ({ key, x, y, z, yaw }), where the player stands.
    local function survey(a)
        if surveying then return end
        if run.active() then out("survey: a challenge is running") return end
        local nav, world = StaticFindObject(nav_path), UEHelpers.GetWorld()
        local p = U.valid(nav) and project(nav, world, { X = a.x, Y = a.y, Z = a.z }, CENTER_EXTENT)
        if not p then
            out("survey\t" .. a.key .. "\tno navigation mesh at the standing point")
            ui.toast("调试：站位不在寻路网格上", 3)
            return
        end
        local f = math.rad(a.yaw)
        local b = project(nav, world, { X = p.X + math.cos(f) * BOSS_AHEAD, Y = p.Y + math.sin(f) * BOSS_AHEAD, Z = p.Z }, CENTER_EXTENT)
        local jobs, res = {}, { player = {}, boss = {} }
        local bd, bn = U.nearest_bell(p)
        local bell = { dist = bd, name = bn }
        for d = 0, DIRS - 1 do jobs[#jobs + 1] = { "player", p, a.yaw + d * 360 / DIRS } end
        if b then
            for d = 0, DIRS - 1 do jobs[#jobs + 1] = { "boss", b, a.yaw + d * 360 / DIRS } end
        else
            out("survey\t" .. a.key .. string.format("\tboss point (%d m ahead) not on the navigation mesh", BOSS_AHEAD / 100))
        end
        surveying = true
        local was_god = god.on()
        if not was_god then god.set(true) end
        U.every(100, function()
            local job = table.remove(jobs, 1)
            if job then
                local nav2, world2 = StaticFindObject(nav_path), UEHelpers.GetWorld()
                local open, why, dz = measure_dir(nav2, world2, job[2], job[3])
                table.insert(res[job[1]], { open = open, why = why, dz = dz })
                return false
            end
            local lines = { summary(a, "player", res.player, bell) }
            if #res.boss > 0 then lines[#lines + 1] = summary(a, "boss", res.boss) end
            ui.toast("调试：" .. table.concat(lines, "；"), 8)
            if not was_god then god.set(false) end
            surveying = false
            out("survey: done")
            return true
        end)
    end

    U.key(Key.F3, function() survey(mark()) end)
    U.key(Key.F2, function()
        local a = FOCUS and arenas.get(FOCUS)
        if not a then out("go: no FOCUS arena") ui.toast("调试：未设置 FOCUS 场地", 2) return end
        if run.active() then out("go: a challenge is running") return end
        out("go to " .. a.key)
        ui.toast("调试：前往 " .. a.zh, 2)
        FindFirstOf("PBZSaveLoadSubsystem"):TeleportTo(FName(a.map), U.transform(a.x, a.y, a.z, a.yaw), FName(U.bell_name(a.bell)))
    end)
    -- F9: the boss-defeat banner (斩), normal and red in turn, to see it before the run plays it for every boss.
    local red = false
    U.key(Key.F9, function()
        out("boss banner " .. (red and "red" or "normal") .. " (F9)")
        ui.boss_banner(red)
        red = not red
    end)
    U.log("devtools ready: F2 go to %s, F3 mark and survey a spot, F9 boss banner", tostring(FOCUS))
end

return M
