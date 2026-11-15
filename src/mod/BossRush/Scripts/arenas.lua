-- Arenas (src/data/arenas_final.tsv, DESIGN §5.0). Coordinates are the user's marked standing spots (F2), each
-- graded by the arena survey (DESIGN §5.0a). Spots are kept away from bells (user decision 2026-11-15): the
-- earlier ones stood on the bell's teleport point (1 m); xigu_axe, fuji_tree, ddsd_blade and houjie_lion were
-- marked again, lyz_white and sz_shrine added, camp_lady and camp_tower removed (user decision 2026-11-15).
-- kind: "scenic" (名胜; `boss` marks a spot that is also that boss's original battlefield), "own" (a boss's own
-- battlefield, where the level holds what its fight needs: that boss is fought only there, and nobody else is),
-- "jhsy" (Realm of Mirage).
-- An own battlefield is used only while its bell is rung in this playthrough: TeleportTo makes the bell it is
-- given the player's bell, so a death there revives the player at a bell the game has not unlocked. A player in
-- a new playthrough (二周目, 龙柱 not rung) died there, was revived inside the arena, the game crashed (GPU device
-- removed) on the next teleport and the save was left at Bell_DP_001 (Nexus report by mastersoul2 on 0.1.5).
-- `bound`: the fight needs that level (舞狮尊主's poles) and is not fought at all while the bell is not rung; an
-- own battlefield without it only restores the setting, and its boss goes to the usual arenas instead.
local U = require("util")

local A = {
    { key = "xigu_axe",   kind = "scenic", map = "/Game/Maps/B02/PBZ_Xigu_WP",                       bell = "NLES_023",     zh = "斧老大斩落处",   en = "The Axemaster's Fall",        x = -50661, y = 260340, z = -24492, yaw = 216, boss = "BP_Monster_PengMeng_Axe" },
    { key = "fuji_tree",  kind = "scenic", map = "/Game/Maps/B03/PBZ_Fujizhilin_WP",                 bell = "LZSJ_010",     zh = "丝线缠绕的巨树", en = "Threadbound Great Tree",      x = 15588,  y = 154245, z = -1963,  yaw = 328 },
    { key = "pz_lake",    kind = "scenic", map = "/Game/Maps/B08_09_10/PBZ_Pangzhen_WP",             bell = "Bell_MGH_008", zh = "梅谷湖畔",       en = "Meigu Lakeside",              x = -67150, y = 80676,  z = 805,    yaw = 255 },
    -- 白影陨落之处: the bell 风雪刀客's fight lights (DESIGN 5.1); that boss is not in the roster, so no `boss`.
    { key = "lyz_white",  kind = "scenic", map = "/Game/Maps/B08_09_10/PBZ_Pangzhen_WP",             bell = "LYZ_014",      zh = "白影陨落之处",   en = "Whiteshadow's Fall",          x = -151389, y = -22294, z = 823,   yaw = 23 },
    -- The bell is a broken bell ("BrokenBell_" id). 10 m from it: kept by the user (2026-11-15).
    { key = "lakeside",   kind = "scenic", map = "/Game/Maps/B04_05/PBZ_Zhengdaodaying_WP",          bell = "BrokenBell_LJC_02", zh = "初见湖畔",  en = "First Meeting Lakeside",      x = -66429, y = 82003,  z = 911,    yaw = 264 },
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
    -- bell menu, but TeleportTo with its id works (the run, devtools F5). Their skills need
    -- nothing from the level (Skill_08 spawns its own pillars): this is about the setting, not a fix.
    -- 魔渊 may have a second original spot (Pangzhen's 龙柱, Bell_DP_004): phases cannot change maps, so Xigu.
    { key = "xigu_pillar", kind = "own",  map = "/Game/Maps/B02/PBZ_Xigu_WP",                       bell = "DP_001",       zh = "龙柱",           en = "The Lóng Pillar",             x = -38650,  y = 234117, z = 10009000, yaw = 103, boss = "BP_Monster_MoTian_LongZhu_01" },
    -- The Realm of Mirage is entered at its bell; the run moves the player to this spot on arrival (run.lua
    -- place_player). Marked by the user with F2 (2026-11-15): 8 m from the entrance, survey 良 (16/16, 28 m); no
    -- bell actor is loaded near it (the nearest PBZCheckPoint was 298 m away).
    { key = "jhsy",       kind = "jhsy",   zh = "镜花水月", en = "Realm of Mirage", x = 8890, y = -28068, z = 5000799, yaw = 357 },
}

local M = {}

local function is_rung(a, rung) return rung[U.bell_name(a.bell)] == true end

-- Arenas offered for a boss: spots whose bell is rung, that boss's origin first, Realm of Mirage last.
function M.for_boss(boss_id, rung)
    local out = {}
    for _, a in ipairs(A) do
        if boss_id and a.boss == boss_id and is_rung(a, rung) then out[#out + 1] = { arena = a, origin = true } end
    end
    for _, a in ipairs(A) do
        if a.kind == "scenic" and (not boss_id or a.boss ~= boss_id) and is_rung(a, rung) then
            out[#out + 1] = { arena = a }
        end
    end
    for _, a in ipairs(A) do
        if a.kind == "jhsy" then out[#out + 1] = { arena = a } end
    end
    return out
end

-- Every arena (the development arena survey walks them all).
function M.all() return A end

-- The boss's own battlefield (kind "own"), or nil.
function M.own(boss_id)
    for _, a in ipairs(A) do
        if a.kind == "own" and a.boss == boss_id then return a end
    end
    return nil
end

-- No arena choice for the player (user decision): if they already stand at a suitable arena, fight there;
-- otherwise pick one at random. Suitable = this boss's origin, or a scenic spot, whose bell is rung; a boss with
-- its own battlefield is fought only there while its bell is rung (see the top of this file). The Realm of
-- Mirage is the fallback when nothing else is available.
-- exclude: optional set of arena keys to leave out (an arena found occupied on arrival, run.lua).
-- Returns arena, in_place; or nil, own arena when the fight is bound to a battlefield whose bell is not rung.
function M.pick(boss_id, rung, map, pos, radius, exclude)
    local pool = {}
    local own = boss_id and M.own(boss_id)
    if own and is_rung(own, rung) then
        pool = { own }
    elseif own and own.bound then
        U.log("arena: %s needs its bell %s, not rung in this playthrough", own.key, U.bell_name(own.bell))
        return nil, own
    else
        if own then U.log("arena: %s's bell %s is not rung; usual arenas instead", own.key, U.bell_name(own.bell)) end
        for _, e in ipairs(M.for_boss(boss_id, rung)) do
            if e.arena.kind ~= "jhsy" and not (exclude and exclude[e.arena.key]) then pool[#pool + 1] = e.arena end
        end
    end
    for _, a in ipairs(pool) do
        if a.map == map and pos and math.sqrt((pos.X - a.x) ^ 2 + (pos.Y - a.y) ^ 2 + (pos.Z - a.z) ^ 2) < radius then
            return a, true
        end
    end
    if #pool > 0 then return pool[math.random(#pool)], false end
    for _, a in ipairs(A) do if a.kind == "jhsy" then return a, false end end
end

return M
