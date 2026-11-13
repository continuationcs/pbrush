-- Development autotest (never shipped: src/tools/build_release.py leaves this file out).
-- F12: run every "origin" boss (level-dependent, fought at its original arena) through a full challenge,
-- one after another, and log what happened. F12 again stops after the current boss. Ctrl+F12 forces an error.
--   travel -> find helper point -> spawn -> watch the boss 20 s (moves, vanishing, falls) -> Kill ->
--   result screen -> back at the starting bell.
-- The player is made unkillable while it runs (Health_Max x100, refilled), and restored afterwards.
-- Results: [BossRush] AUTOTEST lines in UE4SS.log and autotest.tsv in the mod folder.
local U = require("util")
local config = require("config")
local UEHelpers = require("UEHelpers")

local M = {}

local DIR = (debug.getinfo(1, "S").source:match("^@(.*[\\/])Scripts[\\/]") or "")
local OBSERVE = 20      -- seconds to watch each boss before killing it
local TIMEOUT_FIGHT = 120
local TIMEOUT_HOME = 90

local function out(line)
    U.log("AUTOTEST %s", line)
    local f = io.open(DIR .. "autotest.tsv", "a")
    if f then f:write(os.date("%H:%M:%S") .. "\t" .. line .. "\n") f:close() end
end

function M.install(run, arenas, roster)
    local active, stop = false, false
    local god = nil

    local function god_on()
        pcall(function()
            local s = U.pawn().AttributeSetBase
            god = { base = s.Health_Max.BaseValue, cur = s.Health_Max.CurrentValue }
            s.Health_Max.BaseValue = god.base * 100
            s.Health_Max.CurrentValue = god.cur * 100
        end)
    end
    local function god_tick()
        if not god then return end
        pcall(function()
            local s = U.pawn().AttributeSetBase
            if s.Health_Max.CurrentValue < god.cur * 50 then
                s.Health_Max.BaseValue = s.Health_Max.BaseValue * 100
                s.Health_Max.CurrentValue = s.Health_Max.CurrentValue * 100
            end
            s.Health.BaseValue = s.Health_Max.CurrentValue
            s.Health.CurrentValue = s.Health_Max.CurrentValue
        end)
    end
    local function god_off()
        if not god then return end
        pcall(function()
            local s = U.pawn().AttributeSetBase
            s.Health_Max.BaseValue = god.base
            s.Health_Max.CurrentValue = god.cur
            s.Health.BaseValue = god.cur
            s.Health.CurrentValue = god.cur
        end)
        god = nil
    end

    local function start_all()
        -- autotest_only.txt in the mod folder (one boss id per line) limits the run to those bosses.
        local only = nil
        local f = io.open(DIR .. "autotest_only.txt", "r")
        if f then
            only = {}
            for line in f:lines() do
                local id = line:match("^%s*(BP_Monster_[%w_]+)")
                if id then only[id] = true end
            end
            f:close()
        end
        local queue = {}
        for _, b in ipairs(roster) do
            if b.state == "origin" and (not only or only[b.id]) then queue[#queue + 1] = b end
        end
        if #queue == 0 then out("no origin bosses") return end
        if run.active() then out("a run is already going; try again when it ends") return end
        active, stop = true, false
        local saved_settle = config.settle_seconds
        config.settle_seconds = 3
        god_on()
        out(string.format("start: %d bosses", #queue))
        out("boss\tresult\thelper\tmax_move_m\tmin_dz_m\tnotes")

        local i, step, t0, rec = 0, "next", 0, nil
        U.every(1000, function()
            if not active then return true end
            god_tick()
            local now = os.clock()
            local st = run.state()

            if step == "next" then
                if rec then
                    out(string.format("%s\t%s\t%s\t%s\t%s\t%s", rec.id, rec.result, rec.helper or "-",
                        rec.move and string.format("%.0f", rec.move / 100) or "-",
                        rec.dz and string.format("%.0f", rec.dz / 100) or "-", table.concat(rec.notes, "; ")))
                    rec = nil
                end
                if st then return end -- wait for the previous run to end completely
                i = i + 1
                if stop or i > #queue then
                    active = false
                    config.settle_seconds = saved_settle
                    god_off()
                    out(stop and "stopped" or "done")
                    return
                end
                local b = queue[i]
                rec = { id = b.id, result = "?", notes = {} }
                out(string.format("[%d/%d] %s", i, #queue, b.id))
                local arena = arenas.origin_for(b.id)
                if not arena then rec.result = "no-arena" step = "next" return end
                run.start({ b }, U.game_difficulty(), arena, { title = "autotest" })
                step, t0 = "await_fight", now

            elseif step == "await_fight" then
                if not st then rec.result = "ended-before-fight (helper missing?)" step = "next" return end
                local a = st.phase == "fighting" and U.get(st.actor)
                if a then
                    rec.helper = string.format("%.0f %.0f %.0f", st.center.X, st.center.Y, st.center.Z)
                    rec.start = a:K2_GetActorLocation()
                    rec.move, rec.dz = 0, 0
                    step, t0 = "observe", now
                elseif now - t0 > TIMEOUT_FIGHT then
                    rec.result = "timeout-before-fight (phase " .. tostring(st.phase) .. ")"
                    pcall(run.abort)
                    step, t0 = "await_home", now
                end

            elseif step == "observe" then
                local a = st and U.get(st.actor)
                if not st or st.phase ~= "fighting" or not a then
                    rec.notes[#rec.notes + 1] = "boss gone during observation"
                    rec.result = "boss-vanished"
                    step, t0 = "await_home", now
                    return
                end
                local l = a:K2_GetActorLocation()
                local d = math.sqrt((l.X - st.center.X) ^ 2 + (l.Y - st.center.Y) ^ 2)
                if d > rec.move then rec.move = d end
                local dz = l.Z - st.center.Z
                if dz < rec.dz then rec.dz = dz end
                if math.abs(l.X) < 100 and math.abs(l.Y) < 100 then rec.notes[#rec.notes + 1] = "boss at world origin" end
                if now - t0 >= OBSERVE then
                    pcall(function() a:Kill(0) end)
                    step, t0 = "await_kill", now
                end

            elseif step == "await_kill" then
                if not st or st.phase == "ending" or st.phase == "returning" or st.phase == "between" then
                    rec.result = "ok"
                    step, t0 = "await_home", now
                elseif now - t0 > 10 and now - t0 < 12 then
                    -- Kill did not take: drop health to 0 and let the run's own fallback finish it.
                    pcall(function()
                        local h = U.get(st.actor).AttributeSetBase.Health
                        h.BaseValue = 0 h.CurrentValue = 0
                    end)
                    rec.notes[#rec.notes + 1] = "Kill ignored, health set to 0"
                elseif now - t0 > 25 then
                    rec.result = "boss-would-not-die"
                    pcall(run.abort)
                    step, t0 = "await_home", now
                end

            elseif step == "await_home" then
                if not st then
                    step = "next"
                elseif now - t0 > TIMEOUT_HOME then
                    rec.notes[#rec.notes + 1] = "return timed out"
                    step = "next"
                end
            end
        end)
    end

    U.key(Key.F12, function()
        if active then
            stop = true
            out("stop requested: finishing the current boss")
        else
            start_all()
        end
    end)
    -- Ctrl+F12: raise an error inside the mod, to check the stop path (log, tip strip, entry removed, run ended).
    U.key(Key.F12, function() error("autotest: forced error (Ctrl+F12)") end, { ModifierKey.CONTROL })
    U.log("autotest ready: F12 runs the origin bosses, Ctrl+F12 forces an error")
end

return M
