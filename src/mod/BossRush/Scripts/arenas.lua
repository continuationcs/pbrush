-- Arenas (src/data/arenas_final.tsv, DESIGN §5.0). Coordinates are the user's marked standing spots, adjusted by
-- the arena survey (DESIGN §5.0a, 2026-11-14): camp_lady and camp_tower turned toward their open side; pz_lake
-- (formerly pz_dock, 陆家村浅滩船坞) marked again by the user (F4) after moving it off the raised dock was not enough,
-- and renamed after the lake it now looks over.
-- kind: "scenic" (名胜; `boss` marks a spot that is also that boss's original battlefield), "own" (a boss's own
-- battlefield, where the level holds what its fight needs: that boss is fought only there, and nobody else is),
-- "jhsy" (Realm of Mirage).
local U = require("util")

local A = {
    { key = "xigu_axe",   kind = "scenic", map = "/Game/Maps/B02/PBZ_Xigu_WP",                       bell = "NLES_023",     zh = "斧老大斩落处",   en = "The Axemaster's Fall",        x = -53341, y = 258560, z = -24485, yaw = 0,   boss = "BP_Monster_PengMeng_Axe" },
    { key = "fuji_tree",  kind = "scenic", map = "/Game/Maps/B03/PBZ_Fujizhilin_WP",                 bell = "LZSJ_010",     zh = "丝线缠绕的巨树", en = "Threadbound Great Tree",      x = 14830,  y = 154293, z = -1974,  yaw = 318 },
    { key = "camp_lady",  kind = "scenic", map = "/Game/Maps/B04_05/PBZ_Zhengdaodaying_WP",          bell = "SXC_01_06",    zh = "圣母雕像场",     en = "The Lady Grounds",            x = -47348, y = 104312, z = 950,    yaw = 50 },
    { key = "camp_tower", kind = "scenic", map = "/Game/Maps/B04_05/PBZ_Zhengdaodaying_WP",          bell = "YXZR_006",     zh = "高塔后方出口",   en = "Tower Rear Exit",             x = 29167,  y = 71243,  z = 6937,   yaw = 88 },
    { key = "pz_lake",    kind = "scenic", map = "/Game/Maps/B08_09_10/PBZ_Pangzhen_WP",             bell = "Bell_MGH_008", zh = "陆家村湖畔",     en = "Lu Village Lakeside", x = -67150, y = 80676,  z = 805,    yaw = 255 },
    -- Added 2026-11-14 (user marked the spot, F4); the bell is a broken bell ("BrokenBell_" id).
    { key = "lakeside",   kind = "scenic", map = "/Game/Maps/B04_05/PBZ_Zhengdaodaying_WP",          bell = "BrokenBell_LJC_02", zh = "湖畔",      en = "Lakeside",                    x = -66429, y = 82003,  z = 911,    yaw = 264 },
    { key = "ddsd_blade", kind = "scenic", map = "/Game/Maps/DengDingShanDao/PBZ_DengDingShanDao_WP", bell = "JJYBP_005",    zh = "横刀平台",       en = "Commander's Platform",        x = -61980, y = -56140, z = 18381,  yaw = 81,  boss = "BP_Monster_GreatBladeMan" },
    -- 舞狮尊主 phase 2: after the last lion head is executed the player jumps on poles and shoots fire, which needs
    -- the level's lion-dance area (BP_LionDance_Area: poles, jump input, telling the boss the player is in). An
    -- area spawned elsewhere made poles that never activated (2026-11-13). The bell 尊主封印地 is 15 m from the
    -- poles. Facing 225 (user request, 2026-11-14): toward the widest open side by the arena survey (right and
    -- behind of the old facing toward the poles, 102, were open 30 m; the boss appeared 10 m from the poles' edge).
    { key = "houjie_lion", kind = "own",  map = "/Game/Maps/B09/PBZ_Houjie_WP",                      bell = "SZ_021",       zh = "尊主封印地",     en = "The Sealed Lion",             x = -271650, y = 46568, z = -3399,  yaw = 225, boss = "BP_Monster_LionDancer_P2" },
    -- 金面具黑衣人 → 魔渊 (user decision 2026-11-14: Duel always at their original battlefield). Both classes
    -- share one spawner, in Xigu's separate Discordance space (z ~ 10,000,000; src/data/anchored_cells.lua.txt);
    -- the bell 龙柱 (Bell_DP_001) is 30 m from it. The bell's own spot was cramped (survey 3/16, 0 m): the user
    -- marked this one in the open ground (F2, 2026-11-14), facing 103. The bell cannot be travelled to from the
    -- bell menu, but TeleportTo with its id works (the run, devtools F5). Their skills need
    -- nothing from the level (Skill_08 spawns its own pillars): this is about the setting, not a fix.
    -- 魔渊 may have a second original spot (Pangzhen's 龙柱, Bell_DP_004): phases cannot change maps, so Xigu.
    { key = "xigu_pillar", kind = "own",  map = "/Game/Maps/B02/PBZ_Xigu_WP",                       bell = "DP_001",       zh = "龙柱",           en = "The Lóng Pillar",             x = -38650,  y = 234117, z = 10009000, yaw = 103, boss = "BP_Monster_MoTian_LongZhu_01" },
    { key = "jhsy",       kind = "jhsy",   zh = "镜花水月", en = "Realm of Mirage" },
}

local M = {}

-- Arenas offered for a boss: scenic spots whose bell is rung, that boss's origin (shown first), Realm of Mirage last.
function M.for_boss(boss_id, rung)
    local out = {}
    for _, a in ipairs(A) do
        if boss_id and a.boss == boss_id then out[#out + 1] = { arena = a, origin = true } end
    end
    for _, a in ipairs(A) do
        if a.kind == "scenic" and (not boss_id or a.boss ~= boss_id) and rung[U.bell_name(a.bell)] then
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
-- otherwise pick one at random. Suitable = this boss's origin, or a scenic spot whose bell is rung; a boss with
-- its own battlefield is fought only there. The Realm of Mirage is the fallback when nothing else is available.
-- exclude: optional set of arena keys to leave out (an arena found occupied on arrival, run.lua).
-- Returns arena, in_place.
function M.pick(boss_id, rung, map, pos, radius, exclude)
    local pool = {}
    local own = boss_id and M.own(boss_id)
    if own then
        pool = { own }
    else
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
