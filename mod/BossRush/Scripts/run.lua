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
    local snap, tries, done = run.snap, 0, false
    LoopAsync(500, function()
        if done then return true end
        tries = tries + 1
        if tries > 120 then run = nil return true end
        ExecuteInGameThread(function()
            if done then return end
            local okd, d = pcall(function() return U.dist(U.pawn():K2_GetActorLocation(), { X = o.x, Y = o.y, Z = o.z }) end)
            if okd and d < 2000 then
                done = true
                U.after(1500, function() restore(snap) run = nil end)
            end
        end)
        return false
    end)
end

-- ---------------------------------------------------------------- end of run
local function finish(result)
    if not run or run.phase == "ending" or run.phase == "returning" then return end
    phase("ending")
    ui.hud_hide()
    U.log("run: result %s (%d/%d)", result, run.index, #run.queue)
    if U.valid(run.actor) and result ~= "win" then pcall(function() run.actor:K2_DestroyActor() end) end
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
            { T("vows"), run.vows.weight > 0 and tostring(run.vows.weight) or "—" },
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
    -- Small heal between fights (not under 孤军深入).
    if not run.vows.no_heal then pcall(function()
        local a = U.pawn().AttributeSetBase
        local m = a.Health_Max.CurrentValue
        local h = math.min(m, a.Health.CurrentValue + m * config.heal_between)
        a.Health.BaseValue = h
        a.Health.CurrentValue = h
    end) end
    U.after(2500, function()
        if not run or run.phase ~= "between" then return end
        ui.toast(string.format("%s  %d / %d", i18n.t("next_echo"), run.index + 1, #run.queue), 2.5)
        U.after(2500, spawn_next)
    end)
end

-- ---------------------------------------------------------------- fight
local function watch_fight(actor)
    LoopAsync(250, function()
        if not run or run.phase ~= "fighting" or run.actor ~= actor then return true end
        ExecuteInGameThread(function()
            if not run or run.phase ~= "fighting" or run.actor ~= actor then return end
            if not U.valid(actor) then boss_down() return end
            -- The player left the arena some other way (a return-to-bell item, a fall): treat it as leaving.
            local okp, pl = pcall(function() return U.pawn():K2_GetActorLocation() end)
            if okp and U.dist(pl, run.center) > config.player_leave then
                U.log("run: player left the arena")
                finish("abort")
                return
            end
            -- 刻不容缓: each fight must be won within the limit.
            if run.vows.time_limit and os.clock() - run.fight_t0 > run.vows.time_limit then
                U.log("run: time limit reached")
                finish("lose")
                return
            end
            -- 一念生死: the player lives on 1 HP for the whole fight, so any hit is fatal.
            if run.vows.one_hit then
                pcall(function()
                    local h = U.pawn().AttributeSetBase.Health
                    if h.CurrentValue > 1 then h.BaseValue = 1 h.CurrentValue = 1 end
                end)
            end
            local hp = 1
            pcall(function() hp = actor.AttributeSetBase.Health.CurrentValue end)
            if hp <= 0 then
                -- Some bosses wait at 0 HP for an execution; give the game a beat, then force its own Kill.
                if not run.zero_at then
                    run.zero_at = os.clock()
                elseif not run.killed and os.clock() - run.zero_at > 0.8 then
                    run.killed = true
                    local ok, e = pcall(function() actor:Kill(0) end)
                    U.log("run: boss at 0 HP, forced Kill -> %s", ok and "called" or tostring(e))
                end
                if os.clock() - run.zero_at > 6 then boss_down() end
                return
            end
            -- Leash: pull a boss back if a skill threw it far away or it fell out of the arena.
            local l = actor:K2_GetActorLocation()
            if U.dist(l, run.center) > config.leash or l.Z < run.center.Z - 2000 then
                U.log("run: boss strayed to %.0f %.0f %.0f, pulling back", l.X, l.Y, l.Z)
                pcall(function() actor:K2_SetActorLocation(run.spawn_at, false, {}, true) end)
            end
        end)
        return false
    end)
end

spawn_next = function()
    if not run then return end
    run.index = run.index + 1
    run.zero_at, run.killed = nil, false
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
    run.actor = a
    U.log("run: boss %d/%d %s", run.index, #run.queue, boss.id)
    -- No side effects from a challenge kill: no loot or Remnant Dust (both come from the NPC's LootComp),
    -- no codex entry.
    pcall(function() a.bExcludeFromCodex = true end)
    pcall(function()
        local lc = a.LootComp
        if U.valid(lc) then lc:K2_DestroyComponent(lc) U.log("run: loot component removed") end
    end)
    scale.apply(a, run.difficulty)
    -- 铜皮铁骨 / 刀刀见血
    pcall(function()
        local s = a.AttributeSetBase
        for name, k in pairs({ Health_Max = run.vows.boss_hp, Health = run.vows.boss_hp, Attack = run.vows.boss_atk }) do
            if k ~= 1 then s[name].BaseValue = s[name].BaseValue * k s[name].CurrentValue = s[name].CurrentValue * k end
        end
    end)
    run.fight_t0 = os.clock()
    -- (The top-of-screen 连战 strip was removed: it overlapped the boss health bar.)
    run.t0 = run.t0 or run.fight_t0
    -- Boss death: the game's own On Dead on the NPC base class.
    U.hook_in_chain(a, "BP_RenewalNPC_C", "On Dead", function(self)
        local ok, o = pcall(function() return self:get() end)
        if run and run.phase == "fighting" and ok and U.valid(o) and U.valid(run.actor)
            and o:GetFullName() == run.actor:GetFullName() then
            U.log("run: boss On Dead")
            ExecuteInGameThread(boss_down)
        end
    end)
    phase("fighting")
    watch_fight(a)
end

-- Wait for the arena to load: the player must stand near the arena centre for a moment.
local function wait_arrival()
    local stable, tries = 0, 0
    LoopAsync(500, function()
        if not run or run.phase ~= "travelling" then return true end
        tries = tries + 1
        ExecuteInGameThread(function()
            if not run or run.phase ~= "travelling" then return end
            local near = false
            pcall(function() near = U.dist(U.pawn():K2_GetActorLocation(), run.center) < 1500 end)
            stable = near and stable + 1 or 0
            if stable >= 4 then
                phase("arrived")
                U.after(1500, spawn_next)
            elseif tries > 120 then
                U.log("run: arena never loaded")
                finish("error")
            end
        end)
        return false
    end)
end

-- ---------------------------------------------------------------- public
function M.active() return run ~= nil end

-- 收刃离去: leave the running challenge (counts as a defeat, no record).
function M.abort()
    if run and (run.phase == "fighting" or run.phase == "between" or run.phase == "travelling" or run.phase == "arrived") then
        U.log("run: abort requested")
        finish("abort")
    end
end

function M.arm_player_hooks(pawn)
    U.hook_in_chain(pawn, "BP_RenewalPlayer_C", "On Dead", function()
        if run and (run.phase == "fighting" or run.phase == "between") then
            U.log("run: player On Dead")
            ExecuteInGameThread(function() finish("lose") end)
        end
    end)
end

-- queue: list of roster records; difficulty: game EDifficultMode; arena: arenas.lua record;
-- opts: { record_key, title (mode line for the result screen), vows = vows.effects(...), in_place = bool }.
function M.start(queue, difficulty, arena, opts)
    if run then U.log("run: already running") return end
    opts = opts or {}
    run = { queue = queue, index = 0, difficulty = difficulty, arena = arena, origin = save_origin(),
            record_key = opts.record_key, title = opts.title, vows = opts.vows or require("vows").effects({}),
            in_place = opts.in_place,
            snap = snapshot() }
    U.log("run: start %d boss(es), difficulty %d, arena %s, from %s / %s", #queue, difficulty, arena.key, run.origin.map, run.origin.bell)
    M.arm_player_hooks(U.pawn())
    phase("travelling")
    go_to_arena()
    wait_arrival()
end

return M
