-- Arenas (src/data/arenas_final.tsv, DESIGN §5.0). Coordinates are the user's marked standing spots.
-- kind: "scenic" (名胜; `boss` marks a spot that is also that boss's original battlefield), "jhsy" (Realm of
-- Mirage). Level-dependent bosses get a generated arena of kind "anchor" (origin_for, below).
local A = {
    { key = "xigu_axe",   kind = "scenic", map = "/Game/Maps/B02/PBZ_Xigu_WP",                       bell = "NLES_023",     zh = "斧老大斩落处",   en = "The Axemaster's Fall",        x = -53341, y = 258560, z = -24485, yaw = 0,   boss = "BP_Monster_PengMeng_Axe" },
    { key = "fuji_tree",  kind = "scenic", map = "/Game/Maps/B03/PBZ_Fujizhilin_WP",                 bell = "LZSJ_010",     zh = "丝线缠绕的巨树", en = "Threadbound Great Tree",      x = 14830,  y = 154293, z = -1974,  yaw = 318 },
    { key = "camp_lady",  kind = "scenic", map = "/Game/Maps/B04_05/PBZ_Zhengdaodaying_WP",          bell = "SXC_01_06",    zh = "圣母雕像场",     en = "The Lady Grounds",            x = -47348, y = 104312, z = 950,    yaw = -18 },
    { key = "camp_tower", kind = "scenic", map = "/Game/Maps/B04_05/PBZ_Zhengdaodaying_WP",          bell = "YXZR_006",     zh = "高塔后方出口",   en = "Tower Rear Exit",             x = 29167,  y = 71243,  z = 6937,   yaw = 118 },
    { key = "pz_dock",    kind = "scenic", map = "/Game/Maps/B08_09_10/PBZ_Pangzhen_WP",             bell = "Bell_MGH_008", zh = "陆家村浅滩船坞", en = "Village of Lu Shallows Dock", x = -70022, y = 72581,  z = 927,    yaw = 57 },
    { key = "ddsd_blade", kind = "scenic", map = "/Game/Maps/DengDingShanDao/PBZ_DengDingShanDao_WP", bell = "JJYBP_005",    zh = "横刀平台",       en = "Commander's Platform",        x = -61980, y = -56140, z = 18381,  yaw = 81,  boss = "BP_Monster_GreatBladeMan" },
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
        if a.kind == "scenic" and (not boss_id or a.boss ~= boss_id) and rung[(a.bell:find("^Bell") and a.bell or "Bell_" .. a.bell)] then
            out[#out + 1] = { arena = a }
        end
    end
    for _, a in ipairs(A) do
        if a.kind == "jhsy" then out[#out + 1] = { arena = a } end
    end
    return out
end

-- No arena choice for the player (user decision): if they already stand at a suitable arena, fight there;
-- otherwise pick one at random. Suitable = this boss's origin, or a scenic spot whose bell is rung.
-- The Realm of Mirage is the fallback when nothing else is available.
-- Returns arena, in_place.
function M.pick(boss_id, rung, map, pos, radius)
    local pool = {}
    for _, e in ipairs(M.for_boss(boss_id, rung)) do
        if e.arena.kind ~= "jhsy" then pool[#pool + 1] = e.arena end
    end
    for _, a in ipairs(pool) do
        if a.map == map and pos and math.sqrt((pos.X - a.x) ^ 2 + (pos.Y - a.y) ^ 2 + (pos.Z - a.z) ^ 2) < radius then
            return a, true
        end
    end
    if #pool > 0 then return pool[math.random(#pool)], false end
    for _, a in ipairs(A) do if a.kind == "jhsy" then return a, false end end
end

-- A level-dependent boss's original arena (origins.lua): land at the nearest bell, then the run looks up the
-- boss's helper point in the loaded level and fights there.
local origins = require("origins")
function M.origin_for(boss_id)
    for _, o in ipairs(origins) do
        for _, id in ipairs(o.bosses) do
            if id == boss_id then
                return { key = "origin:" .. boss_id, kind = "anchor", map = o.map, bell = o.bell,
                         x = o.bx, y = o.by, z = o.bz, yaw = 0, helper = o.helper,
                         hx = o.hx or o.bx, hy = o.hy or o.by, stay = o.stay, zh = "原址", en = "Where It Began" }
            end
        end
    end
    return nil
end

return M
