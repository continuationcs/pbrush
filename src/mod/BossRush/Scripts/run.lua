-- One challenge: travel to the arena, fight a queue of bosses (one for 单挑, a group for 连战),
-- show the result, travel back to the starting bell.
-- run.queue is a list of fights, one per boss: { rec = first phase, steps = { {recs}, ... } }. A boss fought in
-- several phases has a step per phase, fought straight on (no heal); a step can hold several bosses that appear
-- together (玉琮's three forms). run.fi / run.si: the fight and step now; run.actors: that step's bosses.
local U = require("util")
local config = require("config")
local scale = require("scale")
local ui = require("ui")
local records = require("records")
local settle = require("settle")
local i18n = require("i18n")
local arenas = require("arenas")
local UEHelpers = require("UEHelpers")

local M = {}

local run = nil   -- active run, or nil

-- Defined with the arrival wait below; used by go_home too.
local loading

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
    -- The game's own way out of the Realm of Mirage lands at the bell it was entered from. That is the origin,
    -- unless the run went there from an occupied arena (arena_taken): then that arena's bell, and a second trip
    -- takes the player home once they are out (user test 2026-11-14: left at the arena's bell, state not restored).
    local leg2 = not in_jhsy
    if in_jhsy then
        tp:TeleportToBellFromJhsy({})
    else
        teleport_to(o.map, o.x, o.y, o.z, o.yaw, o.bell)
    end
    -- Once the player stands at the starting bell again, put their state back and end the run.
    local snap, tries, settled = run.snap, 0, 0
    U.every(500, function()
        tries = tries + 1
        if tries > 120 then
            U.log("run: never got back to the starting bell; state restored where the player is")
            restore(snap) run = nil
            return true
        end
        local okd, d = pcall(function() return U.dist(U.pawn():K2_GetActorLocation(), { X = o.x, Y = o.y, Z = o.z }) end)
        if okd and d < 2000 then
            U.after(1500, function() restore(snap) run = nil end)
            return true
        end
        if not leg2 then
            -- Out of the Realm of Mirage somewhere else: wait until that place has loaded, then go home.
            local still_in = true
            pcall(function() still_in = tp:IsInJhsy(U.pawn()) end)
            settled = (okd and not still_in and not loading()) and settled + 1 or 0
            if settled >= 4 then
                leg2 = true
                U.log("run: out of the Realm of Mirage away from the starting bell; going home")
                teleport_to(o.map, o.x, o.y, o.z, o.yaw, o.bell)
            end
        end
        return false
    end)
end

-- ---------------------------------------------------------------- helper points
-- The level's AI subsystem: it keeps the identity points (USGameAIWorldSubsystem.Identities, tag -> component).
local function ai_subsystem()
    return U.find_all("SGameAIWorldSubsystem")[1]
end

local function tag_of(name) return { TagName = FName(name) } end

-- Removes the helper points placed for the current boss (place_helpers and place_identity_points, below).
local function clear_helpers()
    local sub = ai_subsystem()
    for tag in pairs(run.identity_tags or {}) do
        if sub then pcall(function() sub:UnRegisterIdentityByTag(tag_of(tag)) end) end
    end
    for _, r in ipairs(run.helpers or {}) do
        local h = U.get(r)
        if h then pcall(function() h:K2_DestroyActor() end) end
    end
    run.helpers, run.identity_tags = {}, {}
end

-- ---------------------------------------------------------------- end of run
local function finish(result)
    if not run or run.phase == "ending" or run.phase == "returning" then return end
    phase("ending")
    U.log("run: result %s (%d/%d)", result, run.fi, #run.queue)
    if result ~= "win" then
        for _, b in ipairs(run.actors or {}) do
            local boss = U.get(b.ref)
            if boss then pcall(function() boss:K2_DestroyActor() end) end
        end
    end
    clear_helpers()
    if result == "error" then U.after(2500, go_home) return end
    local T = i18n.t
    local secs = os.clock() - (run.t0 or os.clock())
    local defeated = result == "win" and #run.queue or math.max(0, run.fi - 1)
    local best_line, name = "—", run.name or ""
    if result == "win" and run.record_key then
        local best = records.best(run.record_key)
        if records.submit(run.record_key, secs) then
            name = name .. "　" .. T("new_record")
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
            -- Layout (user, 2026-11-14): mode and boss / group (+ new record) centred; time | best;
            -- defeated | difficulty. The small line under the title is the entry's name and the mod version.
            { run.mode or "", name },
            { T("time"), run.t0 and records.fmt(secs) or "—" },
            { T("best"), best_line },
            { T("defeated"), string.format("%d / %d", defeated, #run.queue) },
            { T("difficulty"), i18n.difficulty(run.difficulty) },
        },
        sub = T("entry") .. " " .. require("version"),
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

-- The bosses of a step have fallen: the same boss's next phase, the next boss, or the end of the run.
local function step_down()
    if not run or run.phase ~= "fighting" then return end
    local last_step = run.si >= #run.queue[run.fi].steps
    if last_step and run.fi >= #run.queue then finish("win") return end
    phase("between")
    clear_helpers()
    if not last_step then
        -- The same boss's next phase: no heal, a short notice (user decision 2026-11-14).
        U.after(1500, function()
            if not run or run.phase ~= "between" then return end
            ui.toast(i18n.phase(run.si + 1), 2)
            U.after(2000, spawn_next)
        end)
        return
    end
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
        ui.toast(string.format("%s  %d / %d", i18n.t("next_echo"), run.fi + 1, #run.queue), 2.5)
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

-- One boss of the step (b = { ref, id, spawn_at, zero_at, dead_at, killed, down }); marks it down when it is.
-- b.ref is a ref (U.ref): the game destroys a dead boss on its own schedule.
local function check_one(b)
    local actor = U.get(b.ref)
    if not actor then
        b.down = true
        U.log("run: boss gone (%s)", b.id)
        return
    end
    local dead = is_dead(actor)
    -- A dying actor's attributes are not read (see check_summons); health only while it is alive.
    local hp = dead and 0 or health(actor)
    if dead or hp <= 0 then
        local now = os.clock()
        b.zero_at = b.zero_at or now
        if dead and not b.dead_at then
            b.dead_at = now
            U.log("run: boss died (%s)", b.id)
        end
        if b.dead_at and now - b.dead_at > DOWN_AFTER then b.down = true return end
        if not dead and not b.killed and now - b.zero_at > FORCE_KILL then
            b.killed = true
            local ok, e = pcall(function() actor:Kill(0) end)
            U.log("run: boss waits at 0 HP, forced Kill -> %s (%s)", ok and "called" or tostring(e), b.id)
        end
        if now - b.zero_at > DOWN_FALLBACK then b.down = true end
        return
    end
    b.zero_at = nil        -- back above 0 (a phase change refills it)
    -- Roster clear_health_min: the boss's health floor stays above 0 outside its own level, so it can never die.
    -- 魔渊 started with Health_Min 24 (Health_Max 12000) in a player's 二周目 and stopped there, IsDead false;
    -- a forced Kill at 24 left it attacking through the result screen. With the floor set to 0 it falls, dies
    -- and goes like any other boss, scaled or not; the game does not set it again (Nexus report on 0.1.4,
    -- mastersoul2). Checked every tick: the floor may be applied after spawning.
    if b.clear_min then
        pcall(function()
            local m = actor.AttributeSetBase.Health_Min
            if m.CurrentValue > 0 or m.BaseValue > 0 then
                U.log("run: %s Health_Min %.0f set to 0", b.id, m.CurrentValue)
                m.BaseValue, m.CurrentValue = 0, 0
            end
        end)
    end
    -- Leash: pull a boss back if a skill threw it far away or it fell out of the arena. Logged when it starts and
    -- ends, with whether the pull moved it (追命's second phase sat at 0,0,0 and could not be pulled back,
    -- 2026-11-14), not on every tick.
    local l = actor:K2_GetActorLocation()
    if U.dist(l, run.center) > config.leash or l.Z < run.center.Z - 2000 then
        pcall(function() actor:K2_SetActorLocation(b.spawn_at, false, {}, true) end)
        b.strays = (b.strays or 0) + 1
        if b.strays == 1 or b.strays == 20 then
            local now = actor:K2_GetActorLocation()
            local hidden = "?"
            pcall(function() hidden = tostring(actor.bHidden) end)
            U.log("run: boss strayed to %.0f %.0f %.0f (%s, %d ticks), pulled back: now %.0f %.0f %.0f, hidden %s",
                l.X, l.Y, l.Z, b.id, b.strays, now.X, now.Y, now.Z, hidden)
        end
    elseif b.strays then
        U.log("run: boss back in the arena after %d ticks (%s)", b.strays, b.id)
        b.strays = nil
    end
end

-- The step's checks: it is over when every boss in it is down.
local function check_bosses()
    local all_down = true
    for _, b in ipairs(run.actors) do
        if not b.down then check_one(b) end
        if not b.down then all_down = false end
    end
    if all_down then step_down() end
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
local function log_summon_attributes(summons)
    if not config.debug then return end
    for _, b in ipairs(run.actors) do
        local boss = not b.down and U.get(b.ref)
        if boss and not is_dead(boss) then
            U.log("run:   boss %s Level %s Health %s/%s", b.id, attr(boss, "Level"), attr(boss, "Health"), attr(boss, "Health_Max"))
        end
    end
    for _, short in ipairs(summons) do
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
    local summons = {}
    for _, rec in ipairs(run.queue[run.fi].steps[run.si]) do
        for _, short in ipairs(rec.summons or {}) do summons[#summons + 1] = short end
    end
    if #summons == 0 then return end
    local now, states = os.clock(), {}
    for _, short in ipairs(summons) do
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
        log_summon_attributes(summons)
    end
end

-- From the first boss to the end of the run, every 250 ms: the player's death or leaving, and the fight.
-- The game reviving the player means they died, even when IsDead was never seen true: dying in the Realm of
-- Mirage sends the player back to the bell at once, and the run read it as leaving the arena, 收刃离去 instead
-- of 饮恨 (Nexus report on 0.1.4, mastersoul2). Both are native functions bound to the revive event; whether
-- the game calls them where UE4SS sees it is checked in game (the log says which fired).
for _, f in ipairs({ "/Script/ProjectPBZ.PBZPlayerReviveSubsystem:PBZOnPlayerRevived",
                     "/Script/ProjectPBZ.PBZJhsyReturnStreamingSubsystem:HandlePlayerRevived" }) do
    local ok, e = pcall(U.hook, f, function()
        U.log("run: player revived (%s)%s", f:match("[^.]+$"), run and (" during the run, phase " .. run.phase) or "")
        if run and (run.phase == "fighting" or run.phase == "between") then run.revived = true end
    end)
    if not ok then U.log("run: no hook on %s (%s)", f, tostring(e)) end
end

local function watch()
    local me = run
    U.every(250, function()
        if not (run == me and (run.phase == "fighting" or run.phase == "between")) then return true end
        local p = U.pawn()
        if not U.valid(p) or is_dead(p) or run.revived then
            U.log("run: player died%s", run.revived and " (the game revived them)" or "")
            finish("lose")
            return true
        end
        -- The player left the arena some other way (a return-to-bell item, a fall): treat it as leaving.
        local okp, pl = pcall(function() return p:K2_GetActorLocation() end)
        if okp and U.dist(pl, run.center) > config.player_leave then
            U.log("run: player left the arena (health at the previous check %s, now %s)", tostring(run.player_hp),
                tostring(health(p)))
            finish("abort")
            return true
        end
        run.player_hp = health(p)
        if run.phase == "fighting" then check_summons() end
        if run.phase == "fighting" then check_bosses() end
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
-- cannot be placed. recs: the bosses of the step.
local function place_helpers(recs)
    clear_helpers()
    local helpers = {}
    for _, rec in ipairs(recs) do
        for _, hp in ipairs(rec.helpers or {}) do helpers[#helpers + 1] = hp end
    end
    if #helpers == 0 then return true end
    local nav = StaticFindObject(NAV)
    local world = UEHelpers.GetWorld()
    local c, f, r = run.center, math.rad(run.face), math.rad(run.face + 90)
    for _, hp in ipairs(helpers) do
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

-- Identity points. Points placed in a level register with the AI subsystem under a gameplay tag
-- (USGameAIIdentityComponent, e.g. on BP_SGameAITargetPoint), and some skills look one up by tag through the
-- action GAA_AssignIdentityTransformToBlackboard. 追命's second phase does in its ultimate (CriticalArt_03):
-- elsewhere it got the zero transform, was moved to 0,0,0 hidden, and fell out of the world (2026-11-14). After a
-- step's bosses spawn, each such action loaded (a template inside an ability's class default) whose tag the level
-- does not have gets a point in the arena, registered under that tag; clear_helpers takes it away.
local IDENTITY_ACTION = "GAA_AssignIdentityTransformToBlackboard_C"
local IDENTITY_POINT = "/SGameAI/Tools/Teleport/BP_SGameAITargetPoint.BP_SGameAITargetPoint_C"     -- SGameAI plugin
-- Where a tag's point goes: cm ahead of the arena centre along the arena facing (the boss appears 8 m ahead).
-- 追命's ultimate: it vanishes to the waterfall point (瀑布) and leaps out at the other (跳出); the original layout
-- (溪谷) is not known: the waterfall behind the boss, the leap where the boss stands. Other tags: the boss's spot.
local IDENTITY_AHEAD = { ["AI.Identity.溪谷.钩者.瀑布"] = 1500, ["AI.Identity.溪谷.钩者.跳出"] = 800 }
local IDENTITY_AHEAD_DEFAULT = 800

local function place_identity_points()
    if not run or run.phase == "ending" or run.phase == "returning" then return end
    local sub = ai_subsystem()
    if not sub then U.log("run: identity: no AI subsystem") return end
    local actions = U.find_all(IDENTITY_ACTION, true)
    U.log("run: identity: %d actions loaded", #actions)
    for _, act in ipairs(actions) do
        local tag = nil
        pcall(function() tag = act.IdentityTag.TagName:ToString() end)
        if tag and tag ~= "None" and not run.identity_tags[tag] then
            local have = nil
            pcall(function() have = sub:FindIdentityByTag(tag_of(tag)) end)
            if U.valid(have) then
                U.log("run: identity %s: in the level (%s)", tag, act:GetFullName())
            else
                run.identity_tags[tag] = true
                local cls = U.load_class(IDENTITY_POINT)
                if not U.valid(cls) then U.log("run: identity %s: point class not found %s", tag, IDENTITY_POINT) return end
                local f, ahead = math.rad(run.face), IDENTITY_AHEAD[tag] or IDENTITY_AHEAD_DEFAULT
                local want = { X = run.center.X + math.cos(f) * ahead, Y = run.center.Y + math.sin(f) * ahead, Z = run.center.Z }
                local nav = StaticFindObject(NAV)
                local at = (U.valid(nav) and on_nav(nav, UEHelpers.GetWorld(), want)) or want
                local h = spawn_actor(cls, at, run.face + 180, ALWAYS_SPAWN)     -- facing the player
                if not U.valid(h) then U.log("run: identity %s: point could not be placed", tag) return end
                run.helpers[#run.helpers + 1] = U.ref(h)
                local ok, err = pcall(function()
                    local comp = h.SGameAIIdentity
                    comp.IdentityTag = tag_of(tag)
                    sub:RegisterIdentity(comp)
                end)
                local now = nil
                pcall(function() now = sub:FindIdentityByTag(tag_of(tag)) end)
                U.log("run: identity %s: point placed %d m ahead at %.0f %.0f %.0f, registered %s%s (%s)", tag,
                    ahead / 100, at.X, at.Y, at.Z, tostring(U.valid(now)), ok and "" or (", " .. tostring(err)),
                    act:GetFullName())
            end
        end
    end
end

-- Where the k-th boss of a step appears: the first ahead along the arena facing, the others to its sides
-- (degrees off the facing), so bosses that appear together do not stand in one another.
local SIDE_BY_SIDE = { 0, 40, -40, 80, -80 }

-- Spawns one boss of the step near the player, facing the player. Returns the actor and where it stands.
local function spawn_boss(rec, k)
    local cls = U.load_class(rec.class)
    if not U.valid(cls) then U.log("run: boss class not found %s", rec.class) return nil end
    local p = U.pawn():K2_GetActorLocation()
    local face = run.face + (SIDE_BY_SIDE[k] or 0)
    local spot, dist, turn = reachable_spot(p, face)
    local at
    if spot then
        at = { X = spot.X, Y = spot.Y, Z = spot.Z + 150 }
        U.log("run: spawn on the navigation mesh, %d m away, %d deg off the arena facing", dist / 100, turn + face - run.face)
    else
        -- No navigation data here: 8 m ahead.
        local r = math.rad(face)
        at = { X = p.X + math.cos(r) * 800, Y = p.Y + math.sin(r) * 800, Z = p.Z + 50 }
        U.log("run: no navigation data around the player, spawning 8 m ahead")
    end
    local a = spawn_actor(cls, at, math.deg(math.atan(p.Y - at.Y, p.X - at.X)), ADJUST_IF_POSSIBLE)
    if not U.valid(a) then U.log("run: spawn failed %s", rec.id) return nil end
    if not U.valid(a.Controller) then pcall(function() a:SpawnDefaultController() end) end
    -- No side effects from a challenge kill: no loot or Remnant Dust (both come from the NPC's LootComp),
    -- no codex entry.
    pcall(function() a.bExcludeFromCodex = true end)
    pcall(function()
        local lc = a.LootComp
        if U.valid(lc) then lc:K2_DestroyComponent(lc) U.log("run: loot component removed") end
    end)
    scale.apply(a, run.difficulty)
    return a, at
end

-- The next step: the same boss's next phase, or the next boss's first.
spawn_next = function()
    if not run then return end
    if run.fi == 0 or run.si >= #run.queue[run.fi].steps then
        run.fi, run.si = run.fi + 1, 1
    else
        run.si = run.si + 1
    end
    run.summon_zero, run.summon_scaled, run.summon_line = {}, {}, nil
    local fight = run.queue[run.fi]
    local recs = fight.steps[run.si]
    if not place_helpers(recs) then finish("error") return end
    run.actors = {}
    for k, rec in ipairs(recs) do
        local a, at = spawn_boss(rec, k)
        if not a then finish("error") return end
        run.actors[#run.actors + 1] = { ref = U.ref(a), id = rec.id, spawn_at = at, clear_min = rec.clear_health_min }
        local hmin = attr(a, "Health_Min")
        if hmin ~= "?" then U.log("run: %s Health_Min %s at spawn", rec.id, hmin) end
        U.log("run: boss %d/%d phase %d/%d: %s", run.fi, #run.queue, run.si, #fight.steps, rec.id)
    end
    -- The bosses' abilities are loaded with them; checked again a moment later in case some load late.
    place_identity_points()
    local me = run
    U.after(1500, function() if run == me then place_identity_points() end end)
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
function loading()
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

-- A boss of the roster still alive in the level near the arena centre: the game's own, not ours (none is spawned
-- yet on arrival). In a new playthrough (二周目) a boss not yet beaten stands at its own battlefield: 彭猛 at
-- 斧老大斩落处 joined the fight as a second 彭猛 (user test 2026-11-14). Returns the class names found.
local NATIVE_RADIUS = 6000
local roster_classes
local function native_bosses_near(center)
    if not roster_classes then
        roster_classes = {}
        for _, r in ipairs(require("roster")) do roster_classes[r.class:match("%.([^.]+)$") or ""] = true end
    end
    local found = {}
    for _, npc in ipairs(U.find_all("PBZCharacter_NPC")) do
        local name = npc:GetClass():GetFName():ToString()
        if roster_classes[name] then
            local dead = true
            pcall(function() dead = npc:IsDead() end)        -- IsDead first: never read a dying actor
            if not dead and U.dist(npc:K2_GetActorLocation(), center) < NATIVE_RADIUS then found[#found + 1] = name end
        end
    end
    return found
end

local wait_arrival

-- The arena is held by a living native boss: fight somewhere else (another arena, or the Realm of Mirage when
-- none is left). A boss fought only on its own battlefield cannot move: the run ends before anything spawns,
-- and the player is told to beat the boss in this playthrough first.
local function arena_taken(natives)
    U.log("run: arena %s held by a native boss (%s)", run.arena.key, table.concat(natives, ", "))
    if run.arena.kind == "own" then
        ui.toast(i18n.t("arena_taken_own"), 5)
        U.after(2000, function() finish("error") end)
        return
    end
    run.excluded = run.excluded or {}
    run.excluded[run.arena.key] = true
    run.arena = arenas.pick(run.origin_of, U.active_bells(), nil, nil, 0, run.excluded)
    run.in_place = false
    U.log("run: moving to %s", run.arena.key)
    ui.toast(i18n.t("arena_taken"), 3)
    phase("travelling")
    go_to_arena()
    wait_arrival()
end

-- Wait for the arena to load: loading finished, and the player standing near the arena centre for a moment.
function wait_arrival()
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
            local natives = native_bosses_near(run.center)
            if #natives > 0 then arena_taken(natives) return true end
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

-- queue: list of fights { rec, steps = { {roster records}, ... } } (see the top of this file); difficulty: game
-- EDifficultMode; arena: arenas.lua record; opts: { record_key, mode, name (first line of the result screen: 单挑 / 连战 and the boss or group),
-- in_place = bool }.
function M.start(queue, difficulty, arena, opts)
    if run then U.log("run: already running") return end
    opts = opts or {}
    run = { queue = queue, fi = 0, si = 0, actors = {}, identity_tags = {}, difficulty = difficulty, arena = arena, origin = save_origin(),
            record_key = opts.record_key, mode = opts.mode, name = opts.name, in_place = opts.in_place,
            origin_of = opts.origin_of, snap = snapshot(),
            helpers = {} }
    U.log("run: start %d boss(es), difficulty %d, arena %s, from %s / %s", #queue, difficulty, arena.key, run.origin.map, run.origin.bell)
    phase("travelling")
    for _, fn in ipairs(start_listeners) do fn() end
    go_to_arena()
    wait_arrival()
end

return M
