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
local startup = require("health")    -- the start-up check (health.lua); `health` below reads a character's HP
local UEHelpers = require("UEHelpers")

local M = {}

local run = nil   -- active run, or nil

-- Defined with the arrival wait below; used by travel_home too.
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

-- ---------------------------------------------------------------- the player's health floor
-- A death in a challenge must never be a game death: in 66 Days (NightMare) mode each death costs days (the only
-- loss: no mode takes Remnant Dust), the game counts the death, and it saves on revive, so the loss is kept in the player's only
-- slot (player report 2026-11-16: "a 66-day save loses days after a challenge"). While a fight is on, the player's
-- Health_Min is raised to FLOOR, the same attribute that kept bosses from dying (AGENTS: health floors); health
-- reaching it ends the run as 饮恨. The death counter stays the fallback for whatever ignores the floor.
local FLOOR = 1

local function set_floor()
    if run.floor_was then return end
    local ok, err = pcall(function()
        local m = U.pawn().AttributeSetBase.Health_Min
        run.floor_was = { base = m.BaseValue, cur = m.CurrentValue }
        m.BaseValue = FLOOR
        m.CurrentValue = FLOOR
    end)
    U.log("run: player health floor %s (was %s)", ok and tostring(FLOOR) or ("not set: " .. tostring(err)),
        run.floor_was and string.format("%g / %g", run.floor_was.base, run.floor_was.cur) or "?")
end

-- When the trip home starts (it saves the game), not at the end of the fight: the floor keeps covering the player
-- while the result screen is up and a boss's lingering hits may still land.
local function clear_floor()
    local was = run and run.floor_was
    if not was then return end
    run.floor_was = nil
    pcall(function()
        local m = U.pawn().AttributeSetBase.Health_Min
        m.BaseValue = was.base
        m.CurrentValue = was.cur
    end)
    U.log("run: player health floor removed")
end

-- What a game death would cost, logged at each stage of a run, so one test shows whether a challenge changed any
-- of it (66 Days: days left; any mode: deaths; Remnant Dust as a check). Log only: read with pcall from the player blueprint
-- (BP_RenewalPlayer_C, properties from the header dump); a name a game update changes reads "?" and costs nothing,
-- so they are not in the start-up check (health.lua), which would stop the mod for them.
local LEDGER = { "RemainingDays", "IrretrievableDays", "RemainingDaysOnlastDeerBell", "ConsciousnessDust", "BuffLevel" }
local function log_ledger(stage)
    local parts = {}
    local p = U.pawn()
    for _, name in ipairs(LEDGER) do
        local v = "?"
        pcall(function() v = tostring(p[name]) end)
        parts[#parts + 1] = name .. " " .. v
    end
    parts[#parts + 1] = "DiedTimes " .. tostring(U.game_system("DiedTimes"))
    U.log("run: ledger %s: %s", stage, table.concat(parts, ", "))
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
    log_ledger("home")
end

-- ---------------------------------------------------------------- navigation
-- The level's navigation mesh: where the boss can appear (reachable_spot), and whether the level around a spot
-- is loaded before the player is moved there within it (go_to_arena, go_home).
local NAV = "/Script/NavigationSystem.Default__NavigationSystemV1"
local NAV_EXTENT = { X = 200, Y = 200, Z = 500 }

local function on_nav(nav, world, point)
    local out = {}
    local ok, found = pcall(function() return nav:K2_ProjectPointToNavigation(world, point, out, nil, nil, NAV_EXTENT) end)
    if ok and found and out.X then return { X = out.X, Y = out.Y, Z = out.Z } end
    return nil
end

-- ---------------------------------------------------------------- placing the player
-- The fight belongs on the arena's marked spot, away from the bell (user request 2026-11-15). Travel to an arena
-- lands on it, but two cases start at a bell: a run started at the arena itself (in place: the player stands at
-- the bell they opened the menu at) and the Realm of Mirage (its entrance is its bell). Once arrived, the player
-- is moved within the loaded level: fade to black, move, face the arena, fade back. An in-place run takes the
-- player back to their bell the same way. 战斗 · 场地 · 就近 (DESIGN §5.0c) uses the same move for an arena anywhere
-- on the player's map, which may be far from what World Partition has loaded (a player on 0.1.6 fell through the
-- ground right after a load, cause unknown): such a move first needs the navigation mesh at the spot
-- (go_to_arena), and then the player must stay on their feet there (place_player `back`), otherwise they are put
-- back and travel by teleport.
local FADE_MS = 400
local BLACK = { R = 0, G = 0, B = 0, A = 1 }
local ON_SPOT = 300        -- cm: closer than this to the spot needs no move
-- Ground check after an in-level move: the player more than FALL_CM below the spot has no ground under them.
-- Free fall covers 3 m in 0.8 s, so GROUND_WATCH_MS (screen still black) is enough to see it.
local FALL_CM = 300
local GROUND_WATCH_MS, GROUND_TICK_MS = 1200, 200

local function camera()
    local pc = UEHelpers.GetPlayerController()
    if not U.valid(pc) then return nil end
    local cam = pc.PlayerCameraManager
    return U.valid(cam) and cam or nil
end

local function fade(from, to, hold)
    local cam = camera()
    if cam then cam:StartCameraFade(from, to, FADE_MS / 1000, BLACK, false, hold) end
end

-- Put the player (p, valid) at spot facing yaw, at rest: a fall stopped by putting them back keeps no speed.
local function put(p, spot, yaw)
    p:K2_SetActorLocationAndRotation(spot, { Pitch = 0, Yaw = yaw, Roll = 0 }, false, {}, true)
    pcall(function() p.CharacterMovement:StopMovementImmediately() end)
    local pc = UEHelpers.GetPlayerController()
    local pitch = pc:GetControlRotation().Pitch
    pc:SetControlRotation({ Pitch = pitch, Yaw = yaw, Roll = 0 })
end

-- The player's location and yaw, or nil.
local function player_at()
    local at = nil
    pcall(function()
        local p = U.pawn()
        local l = p:K2_GetActorLocation()
        at = { pos = { X = l.X, Y = l.Y, Z = l.Z }, yaw = p:K2_GetActorRotation().Yaw }
    end)
    return at
end

-- Move the player to spot within the level. done(ok) runs once they are placed (the screen is fading back in).
-- back = { pos, yaw } (where they stand now, on loaded ground): the ground at spot is checked while the screen is
-- still black, and when they fall they are put back there and done(false) runs.
local function place_player(spot, yaw, done, back)
    fade(0, 1, true)
    U.after(FADE_MS, function()
        local p = U.pawn()
        if not U.valid(p) then
            U.log("run: no player to place")
            fade(1, 0, false)
            done(false)
            return
        end
        put(p, spot, yaw)
        local now = p:K2_GetActorLocation()
        U.log("run: player placed at %.0f %.0f %.0f (%.0f m from the spot), facing %.0f", now.X, now.Y, now.Z,
            U.dist(now, spot) / 100, yaw)
        if not back then
            fade(1, 0, false)
            done(true)
            return
        end
        local waited = 0
        U.every(GROUND_TICK_MS, function()
            waited = waited + GROUND_TICK_MS
            local pp = U.pawn()
            local z = nil
            if U.valid(pp) then z = pp:K2_GetActorLocation().Z end
            local fell = z ~= nil and z < spot.Z - FALL_CM
            if not fell and waited < GROUND_WATCH_MS then return false end
            if fell then
                U.log("run: ground check: the player fell %.0f m below the spot, no ground loaded there; put back at %.0f %.0f %.0f",
                    (spot.Z - z) / 100, back.pos.X, back.pos.Y, back.pos.Z)
                put(pp, back.pos, back.yaw)
            else
                U.log("run: ground check: standing at the spot after %d ms (%s)", waited,
                    z and string.format("%.1f m below the mark", (spot.Z - z) / 100) or "no player")
            end
            fade(1, 0, false)
            done(not fell)
            return true
        end)
    end)
end

-- Whether the navigation mesh is loaded at spot: the first sign that the level is loaded there (an in-level move
-- far from the player). Logged with why.
local function nav_at(spot, what)
    local nav = StaticFindObject(NAV)
    local p = U.valid(nav) and on_nav(nav, UEHelpers.GetWorld(), spot) or nil
    U.log("run: %s: navigation mesh %s", what, p and string.format("found (%.0f m off the spot)", U.dist(p, spot) / 100)
        or "not found (level not loaded there)")
    return p ~= nil
end

-- Whether the player is in an animation montage (e.g. getting up from the bell): moving them waits for it.
local function in_montage(p)
    local playing = false
    pcall(function()
        local mesh = p.Mesh
        if not U.valid(mesh) then return end
        local anim = mesh:GetAnimInstance()
        if U.valid(anim) then playing = anim:IsAnyMontagePlaying() end
    end)
    return playing
end

-- Sets run.land (where the player is when the arena is loaded), run.center (the arena's spot: the fight's
-- centre) and run.face (yaw the player faces there), then travels.
local function go_to_arena()
    local a = run.arena
    run.placed = false
    if run.in_place then
        local spot = { X = a.x, Y = a.y, Z = a.z }
        local from = player_at()
        local d = from and U.dist(from.pos, spot) or 0
        U.log("run: in-level move to %s, %.0f m away", a.key, d / 100)
        if d > config.in_place_radius and not nav_at(spot, "in-level move to " .. a.key) then
            U.log("run: travelling to %s instead", a.key)
            run.in_place = false
        end
    end
    if run.in_place then
        -- At this arena's bell, or on its map (就近): no travel; the player is moved to the spot on arrival.
        local l = U.pawn():K2_GetActorLocation()
        run.land = { X = l.X, Y = l.Y, Z = l.Z }
        run.center = { X = a.x, Y = a.y, Z = a.z }
        run.face = a.yaw
    elseif a.kind == "jhsy" then
        local tp = FindFirstOf("PBZTeleportSubsystem")
        local out, cam = {}, {}
        tp:GetJhsyBellTeleportTransform(out, cam)
        run.land = { X = out.Translation.X, Y = out.Translation.Y, Z = out.Translation.Z }
        if a.x then
            run.center = { X = a.x, Y = a.y, Z = a.z }
            run.face = a.yaw
        else
            -- No spot marked yet: fight at the entrance.
            run.center = run.land
            run.face = U.pawn():K2_GetActorRotation().Yaw
        end
        tp:TeleportToJhsy(out)
    else
        run.center = { X = a.x, Y = a.y, Z = a.z }
        run.land = run.center
        run.face = a.yaw
        teleport_to(a.map, a.x, a.y, a.z, a.yaw, a.bell)
    end
end

-- Travel back to the starting bell (run.origin) and end the run there.
local function travel_home()
    local o = run.origin
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

local function go_home()
    local o = run.origin
    phase("returning")
    clear_floor()
    log_ledger("leaving the arena")
    if not run.in_place then travel_home() return end
    -- Never left the level: back to the bell they started at (unless already there, e.g. revived at it), then put
    -- the player's state back. A bell far away (就近) may no longer be loaded: then, or when the player does not
    -- stand there, travel instead.
    local snap = run.snap
    local function done() U.after(1000, function() restore(snap) run = nil end) end
    local home = { X = o.x, Y = o.y, Z = o.z }
    local here = player_at()
    local d = here and U.dist(here.pos, home) or 0
    if d <= ON_SPOT then done() return end
    if d > config.in_place_radius and not nav_at(home, "in-level move back to the starting bell") then
        travel_home()
        return
    end
    place_player(home, o.yaw, function(ok)
        if ok then done() else travel_home() end
    end, here)
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

-- The step's summons still alive when it ends (roster summons): the game leaves them standing, 小雪's thugs fought on
-- after she died and were still there at the next run (user test 2026-11-16). Dead ones are left to the game: a
-- dying actor is never touched (see check_summons).
local function clear_summons()
    local fight = run.queue[run.fi]
    local step = fight and fight.steps[run.si]
    local n = 0
    for _, rec in ipairs(step or {}) do
        for _, short in ipairs(rec.summons or {}) do
            for _, s in ipairs(U.find_all(short)) do
                local dead = true
                pcall(function() dead = s:IsDead() end)
                if not dead then
                    s:K2_DestroyActor()
                    n = n + 1
                end
            end
        end
    end
    if n > 0 then U.log("run: %d summons removed with the step", n) end
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
    clear_summons()
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
            -- defeated | difficulty · 敌方强度 tier. The small line under the title is the entry's name and the mod version.
            { run.mode or "", name },
            { T("time"), run.t0 and records.fmt(secs) or "—" },
            { T("best"), best_line },
            { T("defeated"), string.format("%d / %d", defeated, #run.queue) },
            { T("difficulty"), i18n.difficulty(run.difficulty) .. " · " .. i18n.tier(run.tier) },
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
    if result == "lose" and not run.floored then
        -- A game death (something ignored the health floor): the game revives the player at a bell first; show
        -- the result once that is over.
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
    clear_summons()
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
local remove_abilities      -- defined below (roster remove_abilities); checked on every tick of the fight
local EXECUTION_LOCK = 0.01 -- share of Health_Max: a health floor this small is an execution lock (check_one)

-- Development log: the characters near the arena (class, distance, hidden; dead ones only counted: a dying
-- actor is never read).
local function log_characters_near()
    local alive, dead = {}, {}
    for _, npc in ipairs(U.find_all("PBZCharacter_NPC")) do
        local name = npc:GetClass():GetFName():ToString()
        local gone = true
        pcall(function() gone = npc:IsDead() end)
        if gone then
            dead[name] = (dead[name] or 0) + 1
        else
            local d = U.dist(npc:K2_GetActorLocation(), run.center)
            if d < 6000 then
                local hidden = "?"
                pcall(function() hidden = tostring(npc.bHidden) end)
                alive[#alive + 1] = string.format("%s %.0f m hidden %s", name, d / 100, hidden)
            end
        end
    end
    local d = {}
    for name, n in pairs(dead) do d[#d + 1] = name .. " x" .. n end
    U.log("run: trace   alive within 60 m: %s", #alive == 0 and "none" or table.concat(alive, ", "))
    U.log("run: trace   dead (anywhere loaded): %s", #d == 0 and "none" or table.concat(d, ", "))
end

-- Development log: the boss's abilities that are active now (by class name), with how many it has.
local function log_active_abilities(actor)
    local active, count = {}, 0
    pcall(function()
        actor.AbilitySystemComponent.ActivatableAbilities.Items:ForEach(function(_, item)
            local spec = item:get()
            count = count + 1
            if spec.ActiveCount > 0 and U.valid(spec.Ability) then
                active[#active + 1] = spec.Ability:GetClass():GetFName():ToString()
            end
        end)
    end)
    U.log("run: trace   active abilities (of %d): %s", count, #active == 0 and "none" or table.concat(active, ", "))
end

-- Development log: a boss's health through the fight, to tell a boss that cannot be hurt, one that heals and one
-- that stops just above 0 (Nexus report 2026-11-16: 骨婉约 and 金面具黑衣人 took no damage, 小雪 kept healing by
-- eating corpses the player could not see, 彭猛's bar showed 0 and it did not die). Logged at the start, at each
-- new tenth of health, at every change below 2% and at every rise; the first rise of a streak lists the
-- characters near the arena and the boss's active abilities (小雪 still healed with GA_XiaoXue_RecoverHealth
-- removed, right after her thugs died, 2026-11-16).
local function trace_health(b, actor, hp)
    if not config.debug then return end
    local m, hmin, hbase = nil, "?", "?"
    pcall(function()
        local s = actor.AttributeSetBase
        m = s.Health_Max.CurrentValue
        hmin, hbase = string.format("%.2f", s.Health_Min.CurrentValue), string.format("%.2f", s.Health_Min.BaseValue)
    end)
    if not m or m <= 0 then return end
    local last = b.trace_hp
    b.trace_hp = hp
    if last == nil then
        U.log("run: trace %s health %.2f / %.0f at the start (min %s, base %s)", b.id, hp, m, hmin, hbase)
        return
    end
    if hp == last then return end
    local rose = hp > last
    if rose or hp <= m * 0.02 or math.floor(hp / m * 10) ~= math.floor(last / m * 10) then
        U.log("run: trace %s health %.2f -> %.2f / %.0f (min %s, base %s)%s", b.id, last, hp, m, hmin, hbase,
            rose and " ROSE" or "")
    end
    if rose and not b.trace_rising then
        log_characters_near()
        log_active_abilities(actor)
    end
    b.trace_rising = rose
end

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
    trace_health(b, actor, hp)
    remove_abilities(b, actor)
    -- Execution lock: some bosses carry a tiny health floor (彭猛: Health_Min 1, base 0, from spawn) and wait on it
    -- with the bar at 0 until the player executes them; then the game drops the floor and they fall to 0. A player
    -- who did not execute could not end the fight (Nexus report 2026-11-16; log 2026-11-16: 彭猛 sat at 1 HP for
    -- 13 s until executed). Once it sits on the floor the run sets the floor to 0, so the player's next hit kills
    -- it as damage does. Not forced: with floor and health set to 0 and Kill forced (reason None, then Damaged)
    -- the game counted 彭猛 dead (IsDead true) but it played no death and kept moving (user tests 2026-11-16).
    -- Only floors up to EXECUTION_LOCK of the maximum: a story stage lock (左殇 at 80%) is a roster
    -- clear_health_min boss, whose floor is cleared below instead.
    if not b.clear_min then
        local m, floor = nil, 0
        pcall(function()
            local s = actor.AttributeSetBase
            m, floor = s.Health_Max.CurrentValue, s.Health_Min.CurrentValue
        end)
        if m and floor > 0 and floor <= m * EXECUTION_LOCK and hp <= floor then
            U.log("run: boss at its execution lock (health %.2f, floor %.2f of %.0f), floor set to 0: the next hit kills (%s)",
                hp, floor, m, b.id)
            pcall(function()
                local s = actor.AttributeSetBase
                s.Health_Min.BaseValue, s.Health_Min.CurrentValue = 0, 0
            end)
        end
    end
    -- Roster clear_health_min: the boss's health floor stays above 0 outside its own level, so it can never die.
    -- 魔渊 started with Health_Min 24 (Health_Max 12000) in a player's 二周目 and stopped there, IsDead false;
    -- a forced Kill at 24 left it attacking through the result screen. With the floor set to 0 it falls, dies
    -- and goes like any other boss, scaled or not (Nexus report on 0.1.4, mastersoul2). Checked every tick: the
    -- floor may be applied after spawning, and again stage by stage: 组织冥主：左殇 (black-haired) got 6400, 4800
    -- and 3200 (80 / 60 / 40% of its base 8000), each cleared, and died (2026-11-15).
    -- Other bosses: a floor that appears during the fight is logged once per value, so the next boss that
    -- cannot be killed shows it in the log (悲痛欲绝的阿瑾 read 0 at spawn and was locked later, 2026-11-15).
    pcall(function()
        local m = actor.AttributeSetBase.Health_Min
        if m.CurrentValue > 0 or m.BaseValue > 0 then
            if b.clear_min then
                U.log("run: %s Health_Min %g (base %g) set to 0", b.id, m.CurrentValue, m.BaseValue)
                m.BaseValue, m.CurrentValue = 0, 0
            elseif b.min_seen ~= m.CurrentValue then
                b.min_seen = m.CurrentValue
                U.log("run: %s Health_Min %g (base %g) during the fight (not cleared: not in CLEAR_HEALTH_MIN)", b.id,
                    m.CurrentValue, m.BaseValue)
            end
        end
    end)
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
                    scale.apply(s, run.difficulty, run.tier, short)
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
-- A death is read from the game's own death counter (PBZGameSystem.DiedTimes) first: the game revives a dead
-- player at once, at the last bell, so IsDead may never be seen true. At an arena next to a bell the player
-- stood up again inside the arena and the run went on (2026-11-15); in the Realm of Mirage the player is sent
-- out at once and the run read it as leaving, 收刃离去 instead of 饮恨 (Nexus report on 0.1.4, mastersoul2).
-- Confirmed both ways (2026-11-15): 饮恨 at a normal arena and in the Realm of Mirage. The Realm of Mirage's
-- revive handler (PBZJhsyReturnStreamingSubsystem:HandlePlayerRevived) fires too, but 6 s after the counter, so
-- it was dropped. (PBZPlayerReviveSubsystem:PBZOnPlayerRevived is not a function: the header dump lists the
-- delegate's signature under its property, and RegisterHook found no such UFunction.)

-- Whether the game counted a death since the run started (run.died_at_start: nil when the counter cannot be
-- read; then only IsDead is left).
local function death_counted()
    if not run.died_at_start then return false end
    local n = U.game_system("DiedTimes")
    return n ~= nil and n > run.died_at_start
end

local function watch()
    local me = run
    U.every(250, function()
        if not (run == me and (run.phase == "fighting" or run.phase == "between")) then return true end
        local p = U.pawn()
        local counted = death_counted()
        if counted or not U.valid(p) or is_dead(p) then
            U.log("run: player died (%s): a game death, the health floor did not hold",
                counted and "death counter" or "IsDead")
            log_ledger("after the death")
            finish("lose")
            return true
        end
        if run.floor_was and health(p) <= FLOOR then
            U.log("run: player down at the health floor")
            run.floored = true
            finish("lose")
            return true
        end
        -- The player left the arena some other way (a return-to-bell item, a fall): treat it as leaving.
        local okp, pl = pcall(function() return p:K2_GetActorLocation() end)
        if okp and U.dist(pl, run.center) > config.player_leave then
            U.log("run: player left the arena (health at the previous check %s, now %s; deaths %s, at the start %s)",
                tostring(run.player_hp), tostring(health(p)), tostring(U.game_system("DiedTimes")), tostring(run.died_at_start))
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
-- starts behind an invisible wall, inside a tree or on a ledge (player report on Nexus, 0.1.2). 12 m ahead along
-- the arena facing (user decision 2026-11-15, was 8 m: more room to react after the entrance; every scenic
-- arena's boss point had 12 m or more open ground around it in the survey), then closer, and only when nothing
-- ahead fits, further to the sides and behind. Returns nil when there is no navigation data around the player.
local SPAWN_DIST = { 1200, 1000, 800, 600, 400 }
local SPAWN_TURNS = { { 0, 30, -30 }, { 60, -60, 90, -90 }, { 135, -135, 180 } }
M.SPAWN_AHEAD = SPAWN_DIST[1]

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
    for _, turns in ipairs(SPAWN_TURNS) do
        for _, dist in ipairs(SPAWN_DIST) do
            for _, turn in ipairs(turns) do
                local r = math.rad(face + turn)
                local spot = on_nav(nav, world, { X = from.X + math.cos(r) * dist, Y = from.Y + math.sin(r) * dist, Z = from.Z })
                if spot and walkable(nav, world, from, spot, dist) then return spot, dist, turn end
            end
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
-- Where a tag's point goes: cm ahead of the arena centre along the arena facing (the boss appears SPAWN_AHEAD
-- ahead). 追命's ultimate: it vanishes to the waterfall point (瀑布) and leaps out at the other (跳出); the original
-- layout (溪谷) is not known: the waterfall 7 m behind the boss, the leap where the boss stands. Other tags: the
-- boss's spot.
local IDENTITY_AHEAD = { ["AI.Identity.溪谷.钩者.瀑布"] = M.SPAWN_AHEAD + 700, ["AI.Identity.溪谷.钩者.跳出"] = M.SPAWN_AHEAD }
local IDENTITY_AHEAD_DEFAULT = M.SPAWN_AHEAD

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

-- Where the k-th boss of the step will appear, near the player: { at = spawn point, ground = the floor under it,
-- for the entrance effect }.
local function boss_spot(k)
    local p = U.pawn():K2_GetActorLocation()
    local face = run.face + (SIDE_BY_SIDE[k] or 0)
    local spot, dist, turn = reachable_spot(p, face)
    if spot then
        U.log("run: spawn on the navigation mesh, %d m away, %d deg off the arena facing", dist / 100, turn + face - run.face)
        return { at = { X = spot.X, Y = spot.Y, Z = spot.Z + 150 }, ground = spot }
    end
    -- No navigation data here: SPAWN_AHEAD ahead, at the player's height (the player's centre is about 90 cm up).
    local r = math.rad(face)
    U.log("run: no navigation data around the player, spawning %d m ahead", M.SPAWN_AHEAD / 100)
    local x, y = p.X + math.cos(r) * M.SPAWN_AHEAD, p.Y + math.sin(r) * M.SPAWN_AHEAD
    return { at = { X = x, Y = y, Z = p.Z + 50 }, ground = { X = x, Y = y, Z = p.Z - 90 } }
end

-- The yaw from a point to the player.
local function toward_player(at)
    local p = U.pawn():K2_GetActorLocation()
    return math.deg(math.atan(p.Y - at.Y, p.X - at.X))
end

-- Spawns one boss of the step at its spot, facing the player. Returns the actor.
local function spawn_boss(rec, at)
    local cls = U.load_class(rec.class)
    if not U.valid(cls) then U.log("run: boss class not found %s", rec.class) return nil end
    local a = spawn_actor(cls, at, toward_player(at), ADJUST_IF_POSSIBLE)
    if not U.valid(a) then U.log("run: spawn failed %s", rec.id) return nil end
    if not U.valid(a.Controller) then pcall(function() a:SpawnDefaultController() end) end
    -- No side effects from a challenge kill: no loot or Remnant Dust (both come from the NPC's LootComp),
    -- no codex entry.
    pcall(function() a.bExcludeFromCodex = true end)
    pcall(function()
        local lc = a.LootComp
        if U.valid(lc) then lc:K2_DestroyComponent(lc) U.log("run: loot component removed") end
    end)
    scale.apply(a, run.difficulty, run.tier)
    return a
end

-- The entrance (user decision 2026-11-15: a boss that just popped up and attacked felt abrupt). A game effect
-- plays where each boss will stand for OMEN_MS, the boss appears inside it (the effect is stopped and fades
-- around it), and stands for HOLD_MS before its AI starts, so the player sees who came before it attacks.
-- As the boss appears, a second effect plays on its body (REVEAL_EFFECT, attached to its Mesh: such effects
-- take their particles from the mesh they are on, and on the ground alone they had no body to cover and ignored
-- their size; user request 2026-11-15, both effects together), stopped after REVEAL_MS. 荡秽's blink-in never ends
-- by itself, but stopping it only ends new particles: it shows one burst whose particles fade on their own, and
-- stopping it anywhere from 0.5 to 2.5 s looked the same (user test 2026-11-15). So it plays one round as it is.
-- User choices 2026-11-15 after seeing them: ground effect 2 (NS_SummonBossField1_602), body effect 荡秽's
-- blink-in (candidate 5; ChiYingGuRen's teleport, candidate 4, refused every boss's body: inactive, nothing
-- shown), hold 1.5 s (tried 1 s, back to 1.5 s).
-- The ground effect and its size were picked in game from eight candidates of the game's own summons, teleports
-- and appearances (development keys, removed once chosen); size 1 (as made).
local HOLD_MS = 1500
local REVEAL_MS = 2500
local OMEN_EFFECT = "/PBZVFXPack/VFX/BattleFX/LengTu/NS_SummonBossField1_602.NS_SummonBossField1_602"
local OMEN_MS = 1500
local REVEAL_EFFECT = "/PBZVFXPack/VFX/BattleFX/DangHui/NS_DangHui_Blink_301_Show.NS_DangHui_Blink_301_Show"

-- The boss's AI switch: its controller's SGameAIComponent (SGameAI plugin), StopAI / StartAI.
local function ai_component(actor)
    local ctrl = actor.Controller
    if not U.valid(ctrl) then return nil end
    local ok, comp = pcall(function() return ctrl.SGameAIComponent end)
    return ok and U.valid(comp) and comp or nil
end

-- Roster summon: a summon passive the boss's level would grant, and the event that starts it. A spawned 小雪 lacked
-- GA_SummonPassive_XiaoXue, so her thugs never came; granted and activated it waits for GameplayEvent.SelfSummon,
-- and with that sent her thugs appeared (development probe, 2026-11-16; gen_roster.py SUMMON_PASSIVE). Called when
-- the boss's AI starts. The game calls may be missing after an update (the start-up check lists them as optional):
-- then the fight goes on without the summons, and the log says why.
local ABILITY_LIBRARY = "/Script/GameplayAbilities.Default__AbilitySystemBlueprintLibrary"
local function start_summons(b, actor)
    if not b.summon then return end
    if not startup.has(b.summon.ability) then
        U.log("run: %s summon passive not in the game, no summons", b.id)
        return
    end
    local cls = U.load_class(b.summon.ability)
    local asc = actor.AbilitySystemComponent
    local lib = StaticFindObject(ABILITY_LIBRARY)
    if not (cls and U.valid(asc) and U.valid(lib)) then
        U.log("run: %s summons not started: class %s, ability component %s, library %s", b.id, tostring(cls ~= nil),
            tostring(U.valid(asc)), tostring(U.valid(lib)))
        return
    end
    local ok, e = pcall(function()
        asc:K2_GiveAbility(cls, 0, -1)
        local active = asc:TryActivateAbilityByClass(cls, true)
        lib:SendGameplayEventToActor(actor, tag_of(b.summon.event), {})
        return active
    end)
    U.log("run: %s summon passive granted, activated %s, %s sent", b.id, ok and tostring(e) or ("failed: " .. tostring(e)),
        b.summon.event)
end

-- Roster remove_abilities: takes those abilities from the boss (its ability component's ClearAbility, by the
-- granted spec's handle), so its AI can no longer pick them.
-- The handle is passed as the spec's own Handle struct: a Lua table { Handle = n } built from its number was
-- accepted without an error but removed nothing (小雪 still had 23 abilities and healed with
-- GA_XiaoXue_RecoverHealth, 2026-11-16). One ability per pass, the list read again each time: a handle read
-- from the list is only good until the list changes. Afterwards the list is read once more to confirm.
-- The game grants a removed ability again during the fight (小雪 had GA_XiaoXue_RecoverHealth back and healed
-- with it 26 s after it was removed, 2026-11-16; what grants it is not known, her AI's ability pool lists it), so
-- this runs on every tick of the fight (check_one, from the boss's spawn); it logs only what it removes, and
-- "not found" only on the first call.
local function find_ability(asc, wanted)
    local found, count = nil, 0
    asc.ActivatableAbilities.Items:ForEach(function(_, item)
        local spec = item:get()
        count = count + 1
        local cdo = spec.Ability
        local name = U.valid(cdo) and cdo:GetClass():GetFName():ToString()
        if not found and name and wanted[name] then found = { name = name, handle = spec.Handle } end
    end)
    return found, count
end

remove_abilities = function(b, actor)
    if not b.remove then return end
    local first = not b.remove_checked
    b.remove_checked = true
    local asc = actor.AbilitySystemComponent
    -- A failure is logged once and the boss keeps its abilities (b.remove cleared: no retry on every tick).
    if not U.valid(asc) then
        U.log("run: %s abilities not removed: no ability component", b.id)
        b.remove = nil
        return
    end
    local wanted = {}
    for _, name in ipairs(b.remove) do wanted[name] = true end
    -- Missing after a game update (optional in the start-up check): logged, the boss keeps its abilities.
    -- The same ability can be granted twice (24 abilities, two of them GA_XiaoXue_RecoverHealth, 2026-11-16): every
    -- copy goes, one per pass; a pass that leaves the list as long as it was is a real failure.
    local found = {}
    local ok, e = pcall(function()
        for _ = 1, 16 do
            local f, before = find_ability(asc, wanted)
            if not f then break end
            local n = f.handle.Handle
            asc:ClearAbility(f.handle)
            found[f.name] = true
            local _, after = find_ability(asc, {})
            if after >= before then error("ClearAbility left " .. f.name .. " granted") end
            -- 小雪's AI got it back twice every few seconds (28 removals in 70 s, no heal, 2026-11-16): the first
            -- removal and every tenth are logged.
            b.removed = (b.removed or 0) + 1
            if b.removed == 1 or b.removed % 10 == 0 then
                U.log("run: %s ability %s (handle %s) removed, abilities %d -> %d (%d removals)", b.id, f.name,
                    tostring(n), before, after, b.removed)
            end
        end
    end)
    for name in pairs(found) do wanted[name] = nil end
    if not ok then
        U.log("run: %s abilities not removed: %s", b.id, tostring(e))
        b.remove = nil
        return
    end
    if first then
        for name in pairs(wanted) do U.log("run: %s ability %s not found, not removed", b.id, name) end
    end
end

-- Holds a boss of run.actors still for HOLD_MS, then starts its AI. The AI may start after the boss is spawned
-- (when its controller takes it over): while held, an AI found started is stopped again, and counted in the log.
local function hold(b)
    local actor = U.get(b.ref)
    local ai = actor and ai_component(actor)
    if not ai then
        U.log("run: hold %s: no AI component, the boss starts at once", b.id)
        if actor then start_summons(b, actor) end
        return
    end
    U.log("run: hold %s: AI started %s at spawn", b.id, tostring(ai.bAIStarted))
    ai:StopAI()
    local me, held, restops = run, 0, 0
    U.every(100, function()
        if run ~= me then return true end
        local a = U.get(b.ref)
        local c = a and not is_dead(a) and ai_component(a)
        if not c then U.log("run: hold %s: boss gone or dead while held", b.id) return true end
        held = held + 100
        if held >= HOLD_MS then
            c:StartAI()
            U.log("run: hold %s over: AI started %s (stopped again %d times)", b.id, tostring(c.bAIStarted), restops)
            start_summons(b, a)
            return true
        end
        if c.bAIStarted then
            c:StopAI()
            restops = restops + 1
        end
        return false
    end)
end

-- The body effect on a boss that just appeared, for REVEAL_MS.
local function reveal(actor)
    local mesh = actor.Mesh
    if not U.valid(mesh) then U.log("run: reveal: no mesh") return end
    local fx = U.play_effect_on(REVEAL_EFFECT, mesh)
    U.after(REVEAL_MS, function() U.stop_effect(fx) end)
end

-- The step's bosses appear at their spots (after the omen).
local function appear(recs, spots, omens)
    local fight = run.queue[run.fi]
    for _, o in pairs(omens) do U.stop_effect(o) end
    if not place_helpers(recs) then finish("error") return end
    run.actors = {}
    for k, rec in ipairs(recs) do
        local a = spawn_boss(rec, spots[k].at)
        if not a then finish("error") return end
        local b = { ref = U.ref(a), id = rec.id, spawn_at = spots[k].at, clear_min = rec.clear_health_min,
                    summon = rec.summon, remove = rec.remove_abilities }
        run.actors[#run.actors + 1] = b
        reveal(a)
        local hmin = attr(a, "Health_Min")
        if hmin ~= "?" then U.log("run: %s Health_Min %s at spawn", rec.id, hmin) end
        U.log("run: boss %d/%d phase %d/%d: %s", run.fi, #run.queue, run.si, #fight.steps, rec.id)
        hold(b)
    end
    -- The bosses' abilities are loaded with them; checked again a moment later in case some load late.
    place_identity_points()
    local me = run
    U.after(1500, function() if run == me then place_identity_points() end end)
    run.t0 = run.t0 or os.clock()
    local first = run.phase ~= "between"
    phase("fighting")
    if first then
        log_ledger("first boss")
        set_floor()
        watch()
    end
end

-- The next step: the same boss's next phase, or the next boss's first. The omen plays at the spots chosen now;
-- the bosses appear OMEN_MS later unless the run ended or moved on meanwhile (a death between fights).
spawn_next = function()
    if not run then return end
    if run.fi == 0 or run.si >= #run.queue[run.fi].steps then
        run.fi, run.si = run.fi + 1, 1
    else
        run.si = run.si + 1
    end
    run.summon_zero, run.summon_scaled, run.summon_line = {}, {}, nil
    local recs = run.queue[run.fi].steps[run.si]
    -- Load the bosses' classes before the omen: a class loaded at the spawn froze the game for 3-5 s with the
    -- omen already over (彭猛, 2026-11-15: effect at 24.8 s, boss at 29.8 s), so the boss appeared late and out
    -- of nothing. Loaded now, the wait comes before the omen and the boss steps out of it on time.
    for _, rec in ipairs(recs) do U.load_class(rec.class) end
    U.log("run: boss classes loaded")
    local spots, omens = {}, {}
    for k in ipairs(recs) do
        spots[k] = boss_spot(k)
        omens[k] = U.play_effect(OMEN_EFFECT, spots[k].ground, toward_player(spots[k].ground))
    end
    local me, was = run, run.phase
    U.after(OMEN_MS, function()
        if run == me and run.phase == was then
            appear(recs, spots, omens)
        else
            for _, o in pairs(omens) do U.stop_effect(o) end
        end
    end)
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
    -- Another boss's own battlefield chosen as a group's arena (鬼差夜巡 at 尊主封印地) is left like any other.
    if run.arena.kind == "own" and run.arena.boss == run.arena_spec.boss then
        ui.toast(i18n.t("arena_taken_own"), 5)
        U.after(2000, function() finish("error") end)
        return
    end
    run.excluded = run.excluded or {}
    run.excluded[run.arena.key] = true
    run.arena = arenas.pick(run.arena_spec, U.active_bells(), nil, nil, 0, run.excluded)
    run.in_place = false
    U.log("run: moving to %s", run.arena.key)
    ui.toast(i18n.t("arena_taken"), 3)
    phase("travelling")
    go_to_arena()
    wait_arrival()
end

-- Wait for the arena to load: loading finished, and the player standing where the travel puts them (or on the
-- spot) for a moment. Then, if they are not on the spot (in place, Realm of Mirage), move them there once and
-- wait again. A montage (getting up from the bell) is let finish first, for up to MONTAGE_TICKS.
local MONTAGE_TICKS = 20
function wait_arrival()
    local stable, tries, seen, placing, montage = 0, 0, nil, false, 0
    U.every(500, function()
        if not run or run.phase ~= "travelling" then return true end
        if placing then return false end
        tries = tries + 1
        local busy = loading()
        local p = U.pawn()
        local pl = nil
        pcall(function() pl = p:K2_GetActorLocation() end)
        local near = pl ~= nil and (U.dist(pl, run.land) < 1500 or U.dist(pl, run.center) < 1500)
        local state = string.format("loading screen %s, at the arena %s", tostring(busy), tostring(near))
        if state ~= seen then
            seen = state
            U.log("run: %s (tick %d)", state, tries)
        end
        stable = (near and not busy) and stable + 1 or 0
        if stable >= 4 and not run.placed and U.dist(pl, run.center) > ON_SPOT then
            if in_montage(p) and montage < MONTAGE_TICKS then
                if montage == 0 then U.log("run: waiting for the player's montage before the move") end
                montage = montage + 1
                return false
            end
            local bd, bn = U.nearest_bell(pl)
            U.log("run: moving the player %.0f m to the spot (montage %s; nearest bell %s m, %s)", U.dist(pl, run.center) / 100,
                montage >= MONTAGE_TICKS and "still playing" or "none", bd and string.format("%.0f", bd / 100) or "?", tostring(bn))
            run.placed, placing = true, true
            -- In place (or 就近), the ground at the spot is checked; without it the player travels there instead.
            place_player(run.center, run.face, function(ok)
                placing, stable = false, 0
                if not ok and run and run.phase == "travelling" and run.in_place then
                    U.log("run: travelling to %s instead", run.arena.key)
                    run.in_place, tries, seen = false, 0, nil
                    go_to_arena()
                end
            end, run.in_place and player_at() or nil)
            return false
        end
        if stable >= 4 then
            local bd, bn = U.nearest_bell(pl)
            U.log("run: arrived, nearest bell %s m (%s)", bd and string.format("%.0f", bd / 100) or "?", tostring(bn))
            local natives = native_bosses_near(run.center)
            if #natives > 0 then arena_taken(natives) return true end
            phase("arrived")
            arenas.remember(run.arena.key)
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
    -- An error while the player was being placed would leave the screen black (the fade out holds).
    local cam = camera()
    if cam then pcall(function() cam:StopCameraFade() end) end
    if run and run.phase ~= "ending" and run.phase ~= "returning" then finish("error") end
end)

-- ---------------------------------------------------------------- public
function M.active() return run ~= nil end

-- fn() runs whenever a challenge starts (the leave row in the system menu is only watched during one).
local start_listeners = {}
function M.on_start(fn) start_listeners[#start_listeners + 1] = fn end

-- 收刃离去: leave the running challenge (counts as a defeat, no record).
function M.abort()
    if run and (run.phase == "fighting" or run.phase == "between" or run.phase == "travelling" or run.phase == "arrived") then
        U.log("run: abort requested")
        finish("abort")
    end
end

-- queue: list of fights { rec, steps = { {roster records}, ... } } (see the top of this file); difficulty: game
-- EDifficultMode; arena: arenas.lua record; opts: { tier (敌方强度 tier, tier.lua), record_key, mode, name (first line of the result screen: 单挑 / 连战 and the boss or group),
-- in_place = bool (move within the level, no travel: at the arena's bell or 就近; checked in go_to_arena), arena_spec (what arenas.pick chose the arena by, used again when it is found occupied) }.
function M.start(queue, difficulty, arena, opts)
    if run then U.log("run: already running") return end
    opts = opts or {}
    run = { queue = queue, fi = 0, si = 0, actors = {}, identity_tags = {}, difficulty = difficulty, arena = arena, origin = save_origin(),
            tier = opts.tier or 1, record_key = opts.record_key, mode = opts.mode, name = opts.name, in_place = opts.in_place,
            arena_spec = opts.arena_spec or {}, snap = snapshot(),
            helpers = {}, died_at_start = U.game_system("DiedTimes") }
    U.log("run: start %d boss(es), difficulty %d, tier %d, arena %s, from %s / %s, deaths so far %s", #queue, difficulty,
        run.tier, arena.key, run.origin.map, run.origin.bell, tostring(run.died_at_start))
    log_ledger("start")
    phase("travelling")
    for _, fn in ipairs(start_listeners) do fn() end
    go_to_arena()
    wait_arrival()
end

return M
