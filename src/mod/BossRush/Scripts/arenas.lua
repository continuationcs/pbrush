-- Arenas (DESIGN §5.0). Coordinates are the user's marked standing spots (the mark key, F2 then, F3 now), each
-- graded by the arena survey (DESIGN §5.0a). Spots are kept away from bells (user decision 2026-11-15): the
-- earlier ones stood on the bell's teleport point (1 m); xigu_axe, fuji_tree, ddsd_blade and houjie_lion were
-- marked again, lyz_white and sz_shrine added, camp_lady and camp_tower removed (user decision 2026-11-15).
-- kind: "scenic" (名胜; `boss`: the boss this arena is recommended for, its original battlefield or a spot the
-- user chose: a Duel with that boss goes there when its bell is rung), "own" (a boss's own
-- battlefield, where the level holds what its fight needs: that boss is fought only there; others only as part of
-- a 连战 group that is fought there, DESIGN §5.0b),
-- "jhsy" (Realm of Mirage).
-- An own battlefield is used only while its bell is rung in this playthrough: TeleportTo makes the bell it is
-- given the player's bell, so a death there revives the player at a bell the game has not unlocked. A player in
-- a new playthrough (二周目, 龙柱 not rung) died there, was revived inside the arena, the game crashed (GPU device
-- removed) on the next teleport and the save was left at Bell_DP_001 (Nexus report by mastersoul2 on 0.1.5).
-- `bound`: the fight needs that level (舞狮尊主's poles) and is not fought at all while the bell is not rung; an
-- own battlefield without it only restores the setting, and its boss goes to the usual arenas instead.
local U = require("util")
local settings = require("settings")

local A = {
    { key = "xigu_axe",   kind = "scenic", map = "/Game/Maps/B02/PBZ_Xigu_WP",                       bell = "NLES_023",     zh = "斧老大斩落处",   en = "The Axemaster's Fall",        x = -50661, y = 260340, z = -24492, yaw = 216, boss = "BP_Monster_PengMeng_Axe" },
    { key = "fuji_tree",  kind = "scenic", map = "/Game/Maps/B03/PBZ_Fujizhilin_WP",                 bell = "LZSJ_010",     zh = "丝线缠绕的巨树", en = "Threadbound Great Tree",      x = 15588,  y = 154245, z = -1963,  yaw = 328 },
    { key = "pz_lake",    kind = "scenic", map = "/Game/Maps/B08_09_10/PBZ_Pangzhen_WP",             bell = "Bell_MGH_008", zh = "梅谷湖畔",       en = "Meigu Lakeside",              x = -67150, y = 80676,  z = 805,    yaw = 255 },
    -- 白影陨落之处: the bell 风雪刀客's fight lights (DESIGN 5.1): recommended for it.
    { key = "lyz_white",  kind = "scenic", map = "/Game/Maps/B08_09_10/PBZ_Pangzhen_WP",             bell = "LYZ_014",      zh = "白影陨落之处",   en = "Whiteshadow's Fall",          x = -151389, y = -22294, z = 823,   yaw = 23,  boss = "BP_Monster_FengXueDaoKe" },
    -- The bell is a broken bell ("BrokenBell_" id). 10 m from it: kept by the user (2026-11-15). Recommended for
    -- 沐小葵 (user decision 2026-11-15).
    { key = "lakeside",   kind = "scenic", map = "/Game/Maps/B04_05/PBZ_Zhengdaodaying_WP",          bell = "BrokenBell_LJC_02", zh = "初见湖畔",  en = "First Meeting Lakeside",      x = -66429, y = 82003,  z = 911,    yaw = 264, boss = "BP_Monster_MuXiaoKui" },
    { key = "ddsd_blade", kind = "scenic", map = "/Game/Maps/DengDingShanDao/PBZ_DengDingShanDao_WP", bell = "JJYBP_005",    zh = "横刀平台",       en = "Commander's Platform",        x = -62013, y = -58239, z = 18363,  yaw = 89,  boss = "BP_Monster_GreatBladeMan" },
    { key = "sz_shrine",  kind = "scenic", map = "/Game/Maps/B09/PBZ_Houjie_WP",                      bell = "SZ_023",       zh = "祠堂广场",       en = "Ancestral Shrine Square",     x = -255090, y = 48762, z = -6172,  yaw = 322 },
    -- 舞狮尊主 phase 2: after the last lion head is executed the player jumps on poles and shoots fire, which needs
    -- the level's lion-dance area (BP_LionDance_Area: poles, jump input, telling the boss the player is in). An
    -- area spawned elsewhere made poles that never activated (2026-11-13). The bell 尊主封印地 is 15 m from the
    -- poles. Spot marked again by the user (2026-11-15): 7 m from the bell, near enough to the poles; kept although
    -- under the 12 m rule, the bell does not get in the way of the fight (user decision).
    { key = "houjie_lion", kind = "own",  map = "/Game/Maps/B09/PBZ_Houjie_WP",                      bell = "SZ_021",       zh = "尊主封印地",     en = "The Sealed Lion",             x = -271652, y = 45888, z = -3457,  yaw = 230, boss = "BP_Monster_LionDancer_P2", bound = true },
-- 金面具黑衣人 → 魔渊 (user decision 2026-11-14: Duel always at their original battlefield). Both classes
    -- share one spawner, in Xigu's separate Discordance space (z ~ 10,000,000; src/data/anchored_cells.lua.txt);
    -- the bell 龙柱 (Bell_DP_001) is 30 m from it. The bell's own spot was cramped (survey 3/16, 0 m): the user
    -- marked this one in the open ground (F2, 2026-11-14), facing 103. The bell cannot be travelled to from the
    -- bell menu, but TeleportTo with its id works (the run, devtools F2). Their skills need
    -- nothing from the level (Skill_08 spawns its own pillars): this is about the setting, not a fix.
    -- 魔渊 may have a second original spot (Pangzhen's 龙柱, Bell_DP_004): phases cannot change maps, so Xigu.
    { key = "xigu_pillar", kind = "own",  map = "/Game/Maps/B02/PBZ_Xigu_WP",                       bell = "DP_001",       zh = "龙柱",           en = "The Lóng Pillar",             x = -38650,  y = 234117, z = 10009000, yaw = 103, boss = "BP_Monster_MoTian_LongZhu_01" },
    -- The Realm of Mirage is entered at its bell; the run moves the player to this spot on arrival (run.lua
    -- place_player). Marked by the user with F2 (2026-11-15): 8 m from the entrance, survey 良 (16/16, 28 m); no
    -- bell actor is loaded near it (the nearest PBZCheckPoint was 298 m away).
    { key = "jhsy",       kind = "jhsy",   zh = "镜花水月", en = "Realm of Mirage", x = 8890, y = -28068, z = 5000799, yaw = 357 },
}

local M = {}

-- Whether the arena can be travelled to in this playthrough: its bell is rung (the Realm of Mirage needs none),
-- and its map is in the game (the start-up check, health.lua, required here: it requires this file).
function M.usable(a, rung)
    if a.map and not require("health").has(a.map) then return false end
    return a.kind == "jhsy" or rung[U.bell_name(a.bell)] == true
end

-- Every arena (the start-up check looks up their maps).
function M.all() return A end

-- The arena with this key, or nil.
function M.get(key)
    for _, a in ipairs(A) do
        if a.key == key then return a end
    end
    return nil
end

-- The boss's own battlefield (kind "own"), or nil.
function M.own(boss_id)
    for _, a in ipairs(A) do
        if a.kind == "own" and a.boss == boss_id then return a end
    end
    return nil
end

-- 战斗 · 场地 (user decision 2026-11-16, DESIGN §5.0c): how the run's arena is chosen, on the 设置 page.
--   auto:   the order below (before 2026-11-16 the only one);
--   near:   the nearest arena on the player's map, reached by an in-level move (no load; run.lua checks the ground
--           there and travels instead when it is not loaded); none on this map: as auto;
--   random: a random scenic arena whose bell is rung (the Realm of Mirage when none).
-- near and random ignore recommended arenas, group arenas and own battlefields the fight does not need: only a
-- `bound` battlefield (舞狮尊主) is kept (user decision: what cannot be fought elsewhere stays, what is only
-- recommended does not; 连战 too).
local MODES = { "auto", "near", "random" }

function M.mode()
    local m = settings.get("arena")
    for _, k in ipairs(MODES) do
        if k == m then return m end
    end
    return "auto"
end

-- Step to the next mode (随机 wraps to 自动) and keep it.
function M.next_mode()
    local cur, i = M.mode(), 1
    for n, k in ipairs(MODES) do
        if k == cur then i = n end
    end
    local m = MODES[i % #MODES + 1]
    settings.set("arena", m)
    U.log("arena mode: %s", m)
    return m
end

-- The arenas of the last runs, most recent first (BossRushSettings.tsv `recent_arenas`, kept across restarts): a random
-- pick avoids them (user decision 2026-11-16: not the same arena as one of the last two runs; 随机 and 自动's
-- random step alike).
local RECENT = 2

local function recent()
    local out = {}
    for k in (settings.get("recent_arenas") or ""):gmatch("[^,]+") do out[#out + 1] = k end
    return out
end

-- The run reached this arena (run.lua, on arrival; an arena swapped for an occupied one counts as the one fought).
function M.remember(key)
    local out = { key }
    for _, k in ipairs(recent()) do
        if #out < RECENT and k ~= key then out[#out + 1] = k end
    end
    settings.set("recent_arenas", table.concat(out, ","))
end

-- The arenas of list not used in the last runs: the last RECENT left out, or fewer when that leaves none (only
-- one or two usable), or all of them.
local function fresh(list)
    local last = recent()
    for keep = #last, 0, -1 do
        local out = {}
        for _, a in ipairs(list) do
            local used = false
            for i = 1, keep do
                if last[i] == a.key then used = true end
            end
            if not used then out[#out + 1] = a end
        end
        if #out > 0 then
            U.log("arena: random among %d of %d (recent %s, %d left out)", #out, #list, table.concat(last, ","), keep)
            return out
        end
    end
    return list
end

-- spec = { boss = the boss whose own battlefield or recommended arena counts (单挑: its boss; 连战: the group's boss
-- with an own battlefield, if any), prefer = the group's arena key (连战, DESIGN §5.0b), mode = see MODES (auto
-- when absent) }.
-- auto: a boss with its own battlefield is fought only there while its bell is rung (see the top of this file).
-- Otherwise, in this order (user decisions 2026-11-15): where the player stands, if within `radius` of a usable
-- arena; the group's arena; the boss's recommended arena (`boss`); a random scenic arena whose bell is rung; the
-- Realm of Mirage.
-- map, pos: the player's map and location (nil: anywhere; an arena found occupied on arrival is replaced so).
-- exclude: optional set of arena keys to leave out (an arena found occupied on arrival, run.lua).
-- Returns arena, in_place (no travel: moved within the level); or nil, own arena when the fight is bound to a
-- battlefield whose bell is not rung.
function M.pick(spec, rung, map, pos, radius, exclude)
    local mode = spec.mode or "auto"
    local function open(a) return M.usable(a, rung) and not (exclude and exclude[a.key]) end
    local function away(a)
        if not (pos and a.map and a.map == map) then return nil end
        return math.sqrt((pos.X - a.x) ^ 2 + (pos.Y - a.y) ^ 2 + (pos.Z - a.z) ^ 2)
    end
    local pool = {}
    local own = spec.boss and M.own(spec.boss)
    if own and (mode == "auto" or own.bound) and M.usable(own, rung) then
        pool = { own }
    elseif own and own.bound then
        U.log("arena: %s needs its bell %s, not rung in this playthrough", own.key, U.bell_name(own.bell))
        return nil, own
    else
        if own and mode == "auto" then
            U.log("arena: %s's bell %s is not rung; usual arenas instead", own.key, U.bell_name(own.bell))
        elseif own then
            U.log("arena: %s not needed by the fight; left to the %s setting", own.key, mode)
        end
        for _, a in ipairs(A) do
            if a.kind == "scenic" and open(a) then pool[#pool + 1] = a end
        end
        -- A group's arena may be another boss's own battlefield (鬼差夜巡 at 尊主封印地) or the Realm of Mirage.
        local pref = spec.prefer and M.get(spec.prefer)
        if spec.prefer and not pref then U.log("arena: unknown group arena %s", spec.prefer) end
        if pref and mode == "random" then
            U.log("arena: group arena %s left to the random setting", pref.key)
        elseif pref and pref.kind ~= "scenic" and open(pref) then
            pool[#pool + 1] = pref
        elseif pref and not open(pref) then
            U.log("arena: group arena %s not usable (bell not rung or excluded)", pref.key)
        end
    end
    if mode == "near" then
        local best, bd = nil, nil
        for _, a in ipairs(pool) do
            local d = away(a)
            if d and (not bd or d < bd) then best, bd = a, d end
        end
        if best then
            U.log("arena: nearest on this map: %s, %.0f m", best.key, bd / 100)
            return best, true
        end
        U.log("arena: no arena on this map (%s); picked as auto", tostring(map))
    elseif mode == "random" and #pool > 0 then
        local cand = fresh(pool)
        local a = cand[math.random(#cand)]
        local d = away(a)
        U.log("arena: random: %s", a.key)
        return a, d ~= nil and d < radius
    end
    for _, a in ipairs(pool) do
        local d = away(a)
        if d and d < radius then return a, true end
    end
    for _, a in ipairs(pool) do
        if spec.prefer and a.key == spec.prefer then return a, false end
    end
    for _, a in ipairs(pool) do
        if spec.boss and a.boss == spec.boss then return a, false end
    end
    local scenic = {}
    for _, a in ipairs(pool) do if a.kind == "scenic" then scenic[#scenic + 1] = a end end
    if #scenic > 0 then
        scenic = fresh(scenic)
        return scenic[math.random(#scenic)], false
    end
    for _, a in ipairs(pool) do return a, false end
    for _, a in ipairs(A) do if a.kind == "jhsy" then return a, false end end
end

return M
