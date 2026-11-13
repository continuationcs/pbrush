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

-- ---------------------------------------------------------------- helper points
-- Removes the helper points placed for the current boss (place_helpers, below).
local function clear_helpers()
    for _, r in ipairs(run.helpers or {}) do
        local h = U.get(r)
        if h then pcall(function() h:K2_DestroyActor() end) end
    end
    run.helpers = {}
end

-- ---------------------------------------------------------------- end of run
local function finish(result)
    if not run or run.phase == "ending" or run.phase == "returning" then return end
    phase("ending")
    U.log("run: result %s (%d/%d)", result, run.index, #run.queue)
    local boss = U.get(run.actor)
    if boss and result ~= "win" then pcall(function() boss:K2_DestroyActor() end) end
    clear_helpers()
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
    clear_helpers()
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

local function max_health(ch)
    local m = nil
    pcall(function() m = ch.AttributeSetBase.Health_Max.CurrentValue end)
    return m
end

local function attr(ch, name)
    local v = nil
    pcall(function() v = ch.AttributeSetBase[name].CurrentValue end)
    return v and string.format("%.0f", v) or "?"
end

-- Development log: the attributes that decide whether a summon can be hurt and executed (see check_summons).
local function log_summon_attributes(rec)
    if not config.debug then return end
    local boss = run.actor and U.get(run.actor)
    if boss then U.log("run:   boss Level %s Health %s/%s", attr(boss, "Level"), attr(boss, "Health"), attr(boss, "Health_Max")) end
    for _, short in ipairs(rec.summons) do
        for _, s in ipairs(U.find_all(short)) do
            if not is_dead(s) then
                U.log("run:   summon Level %s Health %s min %s max %s, Shachi %s/%s, execute below %s / %s (break)",
                    attr(s, "Level"), attr(s, "Health"), attr(s, "Health_Min"), attr(s, "Health_Max"),
                    attr(s, "Shachi"), attr(s, "Shachi_Max"), attr(s, "ExecutionTargetNormalHealthThreshold"),
                    attr(s, "ExecutionTargetBreakHealthThreshold"))
            end
        end
    end
end

-- The boss's summons (roster `summons`):
-- - Scaled like the boss (scale.apply), once each, as soon as their attributes are set. The game sizes some of
--   their values from the boss's: 舞狮尊主's last lion head (HouHouHou.LastOne) gets a health floor
--   (GE_LockHealthButCanExecuted, Health_Min) of 1% of the boss's Health_Max and can be executed only below a
--   share of its own. With only the boss scaled (x18.51) the floor was 1851 over a maximum of 500: the head could
--   neither be hurt nor executed (2026-11-13). In the game both follow the same level curves (10000 and 500:
--   the floor is 20% of the head's health).
-- - Those that wait at 0 HP for an execution get their Kill forced after FORCE_KILL, as the boss does.
-- Their states (0 HP / hurt / full) are logged whenever they change.
local function check_summons()
    local rec = run.queue[run.index]
    if not rec.summons then return end
    local now, states = os.clock(), {}
    for _, short in ipairs(rec.summons) do
        for _, s in ipairs(U.find_all(short)) do
            local name = s:GetFullName()
            -- A dead summon's attributes are never read: it is being taken apart (the game crashed while a
            -- dying lion head dissolved, right after a read of every summon's health was added, 2026-11-13).
            -- Just spawned: attributes not set yet (Health_Max 0).
            local alive = not is_dead(s)
            local hp, m = 0, nil
            if alive then hp, m = health(s), max_health(s) end
            if alive and m and m > 0 then
                if not run.summon_scaled[name] then
                    run.summon_scaled[name] = true
                    scale.apply(s, run.difficulty, short)
                    hp, m = health(s), max_health(s)
                end
                states[#states + 1] = hp <= 0 and "0" or ((m and hp >= m) and "full" or "hurt")
                if hp > 0 then
                    run.summon_zero[name] = nil
                elseif not run.summon_zero[name] then
                    run.summon_zero[name] = now
                elseif run.summon_zero[name] ~= true and now - run.summon_zero[name] > FORCE_KILL then
                    run.summon_zero[name] = true          -- forced once
                    local ok, e = pcall(function() s:Kill(0) end)
                    U.log("run: summon %s waits at 0 HP, forced Kill -> %s", short, ok and "called" or tostring(e))
                end
            end
        end
    end
    table.sort(states)
    local line = #states == 0 and "none" or table.concat(states, " ")
    if line ~= run.summon_line then
        run.summon_line = line
        U.log("run: summons alive: %s", line)
        log_summon_attributes(rec)
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
        if run.phase == "fighting" then check_summons() end
        if run.phase == "fighting" then check_boss() end
        return false
    end)
end

-- Where the boss appears: on the level's navigation mesh and reachable on foot from the player, so it never
-- starts behind an invisible wall, inside a tree or on a ledge (player report on Nexus, 0.1.2). Tries 8 m ahead
-- along the arena facing first, then other directions, then shorter distances. Returns nil when there is no
-- navigation data around the player.
local NAV = "/Script/NavigationSystem.Default__NavigationSystemV1"
local NAV_EXTENT = { X = 200, Y = 200, Z = 500 }
local SPAWN_DIST = { 800, 600, 400 }
local SPAWN_TURN = { 0, 30, -30, 60, -60, 90, -90, 135, -135, 180 }

local function on_nav(nav, world, point)
    local out = {}
    local ok, found = pcall(function() return nav:K2_ProjectPointToNavigation(world, point, out, nil, nil, NAV_EXTENT) end)
    if ok and found and out.X then return { X = out.X, Y = out.Y, Z = out.Z } end
    return nil
end

local function walkable(nav, world, from, to, dist)
    local ok, good = pcall(function()
        local path = nav:FindPathToLocationSynchronously(world, from, to, nil, nil)
        return U.valid(path) and path:IsValid() and not path:IsPartial() and path:GetPathLength() <= dist * 2
    end)
    return ok and good
end

local function reachable_spot(player, face)
    local nav = StaticFindObject(NAV)
    if not U.valid(nav) then return nil end
    local world = UEHelpers.GetWorld()
    local from = on_nav(nav, world, player)
    if not from then return nil end
    for _, dist in ipairs(SPAWN_DIST) do
        for _, turn in ipairs(SPAWN_TURN) do
            local r = math.rad(face + turn)
            local spot = on_nav(nav, world, { X = from.X + math.cos(r) * dist, Y = from.Y + math.sin(r) * dist, Z = from.Z })
            if spot and walkable(nav, world, from, spot, dist) then return spot, dist, turn end
        end
    end
    return nil
end

-- ESpawnActorCollisionHandlingMethod: 1 spawn where asked (helper points have no collision); 2 move the actor
-- out of anything it would overlap, but always spawn it (bosses).
local ALWAYS_SPAWN, ADJUST_IF_POSSIBLE = 1, 2

local function spawn_actor(cls, at, yaw, collision)
    local xf = { Rotation = U.yaw_quat(yaw), Translation = at, Scale3D = { X = 1, Y = 1, Z = 1 } }
    local gs = UEHelpers.GetGameplayStatics()
    local a = gs:BeginDeferredActorSpawnFromClass(UEHelpers.GetWorld(), cls, xf, collision, nil, 0)
    return gs:FinishSpawningActor(a, xf, 0)
end

-- Places the boss's helper points (roster `helpers`: class, fwd / right offset in cm from the arena centre along
-- the arena facing), on the navigation mesh when there is one, facing along the arena, before the boss spawns:
-- its skills look these up in the level (DESIGN 5.2). Instances already in the loaded level are counted in the
-- log: a skill that takes the nearest or the first one could still pick those. Returns false when a helper
-- cannot be placed.
local function place_helpers(boss)
    clear_helpers()
    if not boss.helpers then return true end
    local nav = StaticFindObject(NAV)
    local world = UEHelpers.GetWorld()
    local c, f, r = run.center, math.rad(run.face), math.rad(run.face + 90)
    for _, hp in ipairs(boss.helpers) do
        local want = { X = c.X + math.cos(f) * hp.fwd + math.cos(r) * hp.right,
                       Y = c.Y + math.sin(f) * hp.fwd + math.sin(r) * hp.right, Z = c.Z }
        local at = (U.valid(nav) and on_nav(nav, world, want)) or want
        local short = hp.class:match("%.([^.]+)$")
        local cls = U.load_class(hp.class)
        local h = nil
        if U.valid(cls) then h = spawn_actor(cls, at, run.face, ALWAYS_SPAWN) end
        if not U.valid(h) then U.log("run: helper %s could not be placed", short) return false end
        run.helpers[#run.helpers + 1] = U.ref(h)
        local in_level = #U.find_all(short) - 1     -- ours not counted
        U.log("run: helper %s placed at %.0f %.0f %.0f (%d more in the loaded level)", short, at.X, at.Y, at.Z, in_level)
    end
    return true
end

spawn_next = function()
    if not run then return end
    run.index = run.index + 1
    run.zero_at, run.dead_at, run.killed = nil, nil, false
    run.summon_zero, run.summon_scaled, run.summon_line = {}, {}, nil
    local boss = run.queue[run.index]
    local cls = U.load_class(boss.class)
    if not U.valid(cls) then U.log("run: boss class not found %s", boss.class) finish("error") return end
    if not place_helpers(boss) then finish("error") return end
    local p = U.pawn():K2_GetActorLocation()
    local spot, dist, turn = reachable_spot(p, run.face)
    local at
    if spot then
        at = { X = spot.X, Y = spot.Y, Z = spot.Z + 150 }
        U.log("run: spawn on the navigation mesh, %d m away, %d deg off the arena facing", dist / 100, turn)
    else
        -- No navigation data here: 8 m ahead along the arena facing.
        local r = math.rad(run.face)
        at = { X = p.X + math.cos(r) * 800, Y = p.Y + math.sin(r) * 800, Z = p.Z + 50 }
        U.log("run: no navigation data around the player, spawning 8 m ahead")
    end
    run.spawn_at = at
    -- Facing the player.
    local a = spawn_actor(cls, at, math.deg(math.atan(p.Y - at.Y, p.X - at.X)), ADJUST_IF_POSSIBLE)
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

-- Whether the game is still loading. The player is put at the destination before the loading screen goes away,
-- so standing there is not enough: a boss spawned then attacked the moment the screen lifted (user report
-- 2026-11-13). A bell teleport first blocks the game thread (no tick runs, ~11 s), then shows WB_AdditionalLoading
-- (~4 s, activated while it is up). Read in game 2026-11-14 with every candidate logged; IsLoadingLevel,
-- PBZDestinationLoadingSubsystem:IsDestinationLoadingActive and WB_TempLoadingScreen never changed.
local LOADING_SCREEN = "WB_AdditionalLoading_C"
local function loading()
    for _, w in ipairs(U.find_all(LOADING_SCREEN)) do
        local active = false
        pcall(function() active = w:IsActivated() == true end)
        if active then return true end
    end
    return false
end

-- Time the player gets between the loading screen lifting (or arriving without one) and the boss appearing:
-- the 「强敌将至」 notice stays up that long.
local GRACE_MS = 3000

-- Wait for the arena to load: loading finished, and the player standing near the arena centre for a moment.
local function wait_arrival()
    local stable, tries, seen = 0, 0, nil
    U.every(500, function()
        if not run or run.phase ~= "travelling" then return true end
        tries = tries + 1
        local busy = loading()
        local near = false
        pcall(function() near = U.dist(U.pawn():K2_GetActorLocation(), run.center) < 1500 end)
        local state = string.format("loading screen %s, at the arena %s", tostring(busy), tostring(near))
        if state ~= seen then
            seen = state
            U.log("run: %s (tick %d)", state, tries)
        end
        stable = (near and not busy) and stable + 1 or 0
        if stable >= 4 then
            phase("arrived")
            ui.toast(i18n.t("incoming"), GRACE_MS / 1000)
            U.after(GRACE_MS, spawn_next)
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

-- fn() runs whenever a challenge starts (the leave row in the system menu is only watched during one).
local start_listeners = {}
function M.on_start(fn) start_listeners[#start_listeners + 1] = fn end

-- Whether the game's loading screen is up (the development arena survey waits for it too).
M.loading = loading

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
            record_key = opts.record_key, title = opts.title, in_place = opts.in_place, snap = snapshot(),
            helpers = {} }
    U.log("run: start %d boss(es), difficulty %d, arena %s, from %s / %s", #queue, difficulty, arena.key, run.origin.map, run.origin.bell)
    phase("travelling")
    for _, fn in ipairs(start_listeners) do fn() end
    go_to_arena()
    wait_arrival()
end

return M
