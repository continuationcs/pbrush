-- One challenge: travel to the arena, fight a queue of bosses (one for 单挑, a group for 连战),
-- show the result, travel back to the starting bell.
local U = require("util")
local config = require("config")
local scale = require("scale")
local ui = require("ui")
local records = require("records")
local settle = require("settle")
local i18n = require("i18n")
local UEHelpers = require("UEHelpers")

local M = {}

local run = nil   -- active run, or nil

local function phase(p)
    run.phase = p
    U.log("run: %s", p)
end

-- ---------------------------------------------------------------- travel
local function teleport_to(map, x, y, z, yaw, bell)
    local ss = FindFirstOf("PBZSaveLoadSubsystem")
    ss:TeleportTo(FName(map), U.transform(x, y, z, yaw), FName(U.bell_name(bell)))
end

local function save_origin()
    local p = U.pawn()
    local l, r = p:K2_GetActorLocation(), p:K2_GetActorRotation()
    local bell = "None"
    pcall(function() bell = FindFirstOf("BellManager").RecentlyInteractedBellID:ToString() end)
    return { map = U.world_path(), bell = bell, x = l.X, y = l.Y, z = l.Z, yaw = r.Yaw }
end

-- ---------------------------------------------------------------- player state
-- Taken before leaving, put back after returning: health, Sha-Chi, and every remedy's remaining uses.
local function snapshot()
    local snap = { meds = {} }
    pcall(function()
        local a = U.pawn().AttributeSetBase
        snap.hp = a.Health.CurrentValue
        snap.shachi = a.Shachi.CurrentValue
    end)
    pcall(function()
        FindFirstOf("PBZBackPackSubsystem").MedicineInfos:ForEach(function(k, v)
            local info = v:get()
            snap.meds[#snap.meds + 1] = { id = k:get():ToString(), cur = info.CurrentTime, disp = info.DisplayTime }
        end)
    end)
    U.log("run: snapshot hp=%s shachi=%s remedies=%d", tostring(snap.hp), tostring(snap.shachi), #snap.meds)
    return snap
end

local function restore(snap)
    if not snap then return end
    pcall(function()
        local a = U.pawn().AttributeSetBase
        if snap.hp then a.Health.BaseValue = snap.hp a.Health.CurrentValue = snap.hp end
        if snap.shachi then a.Shachi.BaseValue = snap.shachi a.Shachi.CurrentValue = snap.shachi end
    end)
    pcall(function()
        local by_id = {}
        for _, m in ipairs(snap.meds) do by_id[m.id] = m end
        FindFirstOf("PBZBackPackSubsystem").MedicineInfos:ForEach(function(k, v)
            local m = by_id[k:get():ToString()]
            if m then
                local info = v:get()
                info:SetCurrentTime(m.cur)
                info:SetDisplayTime(m.disp)
            end
        end)
    end)
    U.log("run: state restored")
end

-- Sets run.center (arena centre) and run.face (yaw the player faces on arrival), then travels.
local function go_to_arena()
    local a = run.arena
    if run.in_place then
        -- Already standing at this arena: fight right here.
        local p = U.pawn()
        local l = p:K2_GetActorLocation()
        run.center = { X = l.X, Y = l.Y, Z = l.Z }
        run.face = p:K2_GetActorRotation().Yaw
    elseif a.kind == "jhsy" then
        local tp = FindFirstOf("PBZTeleportSubsystem")
        local out, cam = {}, {}
        tp:GetJhsyBellTeleportTransform(out, cam)
        run.center = { X = out.Translation.X, Y = out.Translation.Y, Z = out.Translation.Z }
        run.face = U.pawn():K2_GetActorRotation().Yaw
        tp:TeleportToJhsy(out)
    else
        run.center = { X = a.x, Y = a.y, Z = a.z }
        run.face = a.yaw
        teleport_to(a.map, a.x, a.y, a.z, a.yaw, a.bell)
    end
end

local function go_home()
    local o = run.origin
    phase("returning")
    if run.in_place then
        -- Never left: just put the player's state back.
        local snap = run.snap
        U.after(1000, function() restore(snap) run = nil end)
        return
    end
    local tp = FindFirstOf("PBZTeleportSubsystem")
    local in_jhsy = false
    pcall(function() in_jhsy = tp:IsInJhsy(U.pawn()) end)
    if in_jhsy then
        -- The game's own way out of the Realm of Mirage lands at the bell it was entered from: the origin.
        tp:TeleportToBellFromJhsy({})
    else
        teleport_to(o.map, o.x, o.y, o.z, o.yaw, o.bell)
    end
    -- Once the player stands at the starting bell again, put their state back and end the run.
    local snap, tries = run.snap, 0
    U.every(500, function()
        tries = tries + 1
        if tries > 120 then run = nil return true end
        local okd, d = pcall(function() return U.dist(U.pawn():K2_GetActorLocation(), { X = o.x, Y = o.y, Z = o.z }) end)
        if okd and d < 2000 then
            U.after(1500, function() restore(snap) run = nil end)
            return true
        end
        return false
    end)
end

-- ---------------------------------------------------------------- end of run
local function finish(result)
    if not run or run.phase == "ending" or run.phase == "returning" then return end
    phase("ending")
    U.log("run: result %s (%d/%d)", result, run.index, #run.queue)
    local boss = U.get(run.actor)
    if boss and result ~= "win" then pcall(function() boss:K2_DestroyActor() end) end
    if result == "error" then U.after(2500, go_home) return end
    local T = i18n.t
    local secs = os.clock() - (run.t0 or os.clock())
    local defeated = result == "win" and #run.queue or math.max(0, run.index - 1)
    local best_line, sub = "—", run.title or ""
    if result == "win" and run.record_key then
        local best = records.best(run.record_key)
        if records.submit(run.record_key, secs) then
            sub = sub .. "　" .. T("new_record")
            best_line = records.fmt(secs)
        elseif best then
            best_line = records.fmt(best)
        end
    elseif run.record_key and records.best(run.record_key) then
        best_line = records.fmt(records.best(run.record_key))
    end
    U.log("run: time %.1fs (%s)", secs, tostring(run.record_key))
    local title = result == "win" and T("win") or (result == "abort" and T("abort") or T("lose"))
    local data = {
        title = title,
        rows = {
            { T("time"), run.t0 and records.fmt(secs) or "—" },
            { T("best"), best_line },
            { T("arena"), i18n.name(run.arena) },
            { T("defeated"), string.format("%d / %d", defeated, #run.queue) },
        },
        sub = sub,
        foot = T("going_home"),
    }
    local wait = config.settle_seconds
    -- Go home when the result screen closes (timeout or a key press); once only.
    local home_once = false
    local function home() if not home_once then home_once = true go_home() end end
    local function show()
        if not settle.show(data, wait, home) then
            ui.toast(title, 4)
            U.after(4000, home)
        end
    end
    if result == "lose" then
        -- The game revives the player at a bell first; show the result once that is over.
        U.after(3500, show)
    else
        show()
    end
end

local spawn_next

-- A boss in the queue has fallen: next one, or the end of the run.
local function boss_down()
    if not run or run.phase ~= "fighting" then return end
    if run.index >= #run.queue then finish("win") return end
    phase("between")
    -- Small heal between fights.
    pcall(function()
        local a = U.pawn().AttributeSetBase
        local m = a.Health_Max.CurrentValue
        local h = math.min(m, a.Health.CurrentValue + m * config.heal_between)
        a.Health.BaseValue = h
        a.Health.CurrentValue = h
    end)
    U.after(2500, function()
        if not run or run.phase ~= "between" then return end
        ui.toast(string.format("%s  %d / %d", i18n.t("next_echo"), run.index + 1, #run.queue), 2.5)
        U.after(2500, spawn_next)
    end)
end

-- ---------------------------------------------------------------- fight
-- Deaths are read by polling, not by hooking the characters' Blueprint "On Dead" (hooks on Blueprint
-- functions crashed the game). IsDead is the game's own native query; health is the fallback.
local function health(ch)
    local hp = 1
    pcall(function() hp = ch.AttributeSetBase.Health.CurrentValue end)
    return hp
end

local is_dead_works = nil   -- logged once: whether the native IsDead answers
local function is_dead(ch)
    local ok, dead = pcall(function() return ch:IsDead() end)
    local works = ok and type(dead) == "boolean"
    if is_dead_works == nil then
        is_dead_works = works
        U.log("run: IsDead %s", works and "available" or ("unavailable, using health (" .. tostring(dead) .. ")"))
    end
    if works then return dead end
    return health(ch) <= 0
end

local DOWN_AFTER = 2        -- s after the game confirms the boss's death (its death animation plays)
local FORCE_KILL = 0.8      -- s at 0 HP without dying (waiting for an execution) before the game's Kill is forced
local DOWN_FALLBACK = 6     -- s at 0 HP after which the boss counts as down whatever the game says

-- One fight's checks. run.actor is a ref (U.ref): the game destroys a dead boss on its own schedule.
local function check_boss()
    local actor = U.get(run.actor)
    if not actor then boss_down() return end
    local dead, hp = is_dead(actor), health(actor)
    if dead or hp <= 0 then
        local now = os.clock()
        run.zero_at = run.zero_at or now
        if dead and not run.dead_at then
            run.dead_at = now
            U.log("run: boss died")
        end
        if run.dead_at and now - run.dead_at > DOWN_AFTER then boss_down() return end
        if not dead and not run.killed and now - run.zero_at > FORCE_KILL then
            run.killed = true
            local ok, e = pcall(function() actor:Kill(0) end)
            U.log("run: boss waits at 0 HP, forced Kill -> %s", ok and "called" or tostring(e))
        end
        if now - run.zero_at > DOWN_FALLBACK then boss_down() end
        return
    end
    run.zero_at = nil        -- back above 0 (a phase change refills it)
    -- Leash: pull a boss back if a skill threw it far away or it fell out of the arena.
    local l = actor:K2_GetActorLocation()
    if U.dist(l, run.center) > config.leash or l.Z < run.center.Z - 2000 then
        U.log("run: boss strayed to %.0f %.0f %.0f, pulling back", l.X, l.Y, l.Z)
        pcall(function() actor:K2_SetActorLocation(run.spawn_at, false, {}, true) end)
    end
end

-- From the first boss to the end of the run, every 250 ms: the player's death or leaving, and the fight.
local function watch()
    local me = run
    U.every(250, function()
        if not (run == me and (run.phase == "fighting" or run.phase == "between")) then return true end
        local p = U.pawn()
        if not U.valid(p) or is_dead(p) then
            U.log("run: player died")
            finish("lose")
            return true
        end
        -- The player left the arena some other way (a return-to-bell item, a fall): treat it as leaving.
        local okp, pl = pcall(function() return p:K2_GetActorLocation() end)
        if okp and U.dist(pl, run.center) > config.player_leave then
            U.log("run: player left the arena")
            finish("abort")
            return true
        end
        if run.phase == "fighting" then check_boss() end
        return false
    end)
end

spawn_next = function()
    if not run then return end
    run.index = run.index + 1
    run.zero_at, run.dead_at, run.killed = nil, nil, false
    local boss = run.queue[run.index]
    local cls = U.load_class(boss.class)
    if not U.valid(cls) then U.log("run: boss class not found %s", boss.class) finish("error") return end
    -- 8 m ahead along the arena facing, turned toward the player.
    local r = math.rad(run.face)
    local p = U.pawn():K2_GetActorLocation()
    local at = { X = p.X + math.cos(r) * 800, Y = p.Y + math.sin(r) * 800, Z = p.Z + 50 }
    run.spawn_at = at
    local xf = { Rotation = U.yaw_quat(run.face + 180), Translation = at, Scale3D = { X = 1, Y = 1, Z = 1 } }
    local gs = UEHelpers.GetGameplayStatics()
    local a = gs:BeginDeferredActorSpawnFromClass(UEHelpers.GetWorld(), cls, xf, 1, nil, 0)
    a = gs:FinishSpawningActor(a, xf, 0)
    if not U.valid(a) then U.log("run: spawn failed") finish("error") return end
    if not U.valid(a.Controller) then pcall(function() a:SpawnDefaultController() end) end
    run.actor = U.ref(a)
    U.log("run: boss %d/%d %s", run.index, #run.queue, boss.id)
    -- No side effects from a challenge kill: no loot or Remnant Dust (both come from the NPC's LootComp),
    -- no codex entry.
    pcall(function() a.bExcludeFromCodex = true end)
    pcall(function()
        local lc = a.LootComp
        if U.valid(lc) then lc:K2_DestroyComponent(lc) U.log("run: loot component removed") end
    end)
    scale.apply(a, run.difficulty)
    run.t0 = run.t0 or os.clock()
    local first = run.phase ~= "between"
    phase("fighting")
    if first then watch() end
end

-- Original arena (kind "anchor"): after landing at the nearby bell, find the boss's helper point in the loaded
-- level (World Partition streams by XY, so it is there even when it sits in an interior space), move the
-- player onto it and fight there. If it never shows up the arena is gone (story state): leave.
local function locate_helper(then_fn)
    local a = run.arena
    local short = a.helper:match("%.([^.]+)$")
    pcall(function() U.load_class(a.helper) end)
    local tries = 0
    phase("locating")
    U.every(1000, function()
        if not run or run.phase ~= "locating" then return true end
        tries = tries + 1
        local best, bd
        for _, h in ipairs(FindAllOf(short) or {}) do
            if U.valid(h) and not h:GetFullName():find("Default__") then
                local ok, l = pcall(function() return h:K2_GetActorLocation() end)
                if ok then
                    local d = (l.X - a.hx) ^ 2 + (l.Y - a.hy) ^ 2
                    if not bd or d < bd then best, bd = l, d end
                end
            end
        end
        if best then
            U.log("run: origin helper %s at %.0f %.0f %.0f", short, best.X, best.Y, best.Z)
            local p = U.pawn()
            local yaw = p:K2_GetActorRotation().Yaw
            if a.stay then
                -- The helper must not be stood on (e.g. lion-dance poles are special-move volumes): stay at the
                -- bell, face the helper; the boss spawns ahead, between the player and it.
                local pl = p:K2_GetActorLocation()
                yaw = math.deg(math.atan(best.Y - pl.Y, best.X - pl.X))
                pcall(function() p:K2_SetActorRotation({ Pitch = 0, Yaw = yaw, Roll = 0 }, false) end)
                run.center = { X = pl.X, Y = pl.Y, Z = pl.Z }
            else
                pcall(function() p:K2_TeleportTo({ X = best.X, Y = best.Y, Z = best.Z + 120 }, { Pitch = 0, Yaw = yaw, Roll = 0 }) end)
                run.center = { X = best.X, Y = best.Y, Z = best.Z }
            end
            run.face = yaw
            phase("arrived")
            ui.toast(i18n.t("incoming"), 2.5)
            U.after(2000, then_fn)
            return true
        end
        if tries >= 12 then
            U.log("run: origin helper %s not found", short)
            ui.toast(i18n.t("origin_missing"), 3)
            finish("error")
            return true
        end
        return false
    end)
end

-- Wait for the arena to load: the player must stand near the arena centre for a moment.
local function wait_arrival()
    local stable, tries = 0, 0
    U.every(500, function()
        if not run or run.phase ~= "travelling" then return true end
        tries = tries + 1
        local near = false
        pcall(function() near = U.dist(U.pawn():K2_GetActorLocation(), run.center) < 1500 end)
        stable = near and stable + 1 or 0
        if stable >= 4 then
            if run.arena.kind == "anchor" then
                locate_helper(spawn_next)
            else
                phase("arrived")
                ui.toast(i18n.t("incoming"), 2.5)
                U.after(1500, spawn_next)
            end
            return true
        end
        if tries > 120 then
            U.log("run: arena never loaded")
            finish("error")
            return true
        end
        return false
    end)
end

-- The mod turned itself off after an error (U.failed): end a running challenge and send the player home with
-- their state restored. A run already ending or returning finishes on its own.
U.on_fail(function()
    if run and run.phase ~= "ending" and run.phase ~= "returning" then finish("error") end
end)

-- ---------------------------------------------------------------- public
function M.active() return run ~= nil end

-- Read-only view of the running challenge for the development autotest (phase, actor ref, center, index...).
function M.state() return run end

-- 收刃离去: leave the running challenge (counts as a defeat, no record).
function M.abort()
    if run and (run.phase == "fighting" or run.phase == "between" or run.phase == "travelling" or run.phase == "arrived") then
        U.log("run: abort requested")
        finish("abort")
    end
end

-- queue: list of roster records; difficulty: game EDifficultMode; arena: arenas.lua record;
-- opts: { record_key, title (mode line for the result screen), in_place = bool }.
function M.start(queue, difficulty, arena, opts)
    if run then U.log("run: already running") return end
    opts = opts or {}
    run = { queue = queue, index = 0, difficulty = difficulty, arena = arena, origin = save_origin(),
            record_key = opts.record_key, title = opts.title, in_place = opts.in_place, snap = snapshot() }
    U.log("run: start %d boss(es), difficulty %d, arena %s, from %s / %s", #queue, difficulty, arena.key, run.origin.map, run.origin.bell)
    phase("travelling")
    go_to_arena()
    wait_arrival()
end

return M
