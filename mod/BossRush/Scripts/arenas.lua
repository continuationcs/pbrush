-- Arenas (data/arenas_final.tsv, DESIGN §5.0). Coordinates are the user's marked standing spots.
-- kind: "scenic" (名胜), "origin" (a boss's original battlefield), "jhsy" (Realm of Mirage).
local A = {
    { key = "xigu_axe",   kind = "scenic", map = "/Game/Maps/B02/PBZ_Xigu_WP",                       bell = "NLES_023",     zh = "斧老大斩落处",   en = "The Axemaster's Fall",        x = -53341, y = 258560, z = -24485, yaw = 0,   boss = "BP_Monster_PengMeng_Axe" },
    { key = "fuji_tree",  kind = "scenic", map = "/Game/Maps/B03/PBZ_Fujizhilin_WP",                 bell = "LZSJ_010",     zh = "丝线缠绕的巨树", en = "Threadbound Great Tree",      x = 14830,  y = 154293, z = -1974,  yaw = 318 },
    { key = "camp_lady",  kind = "scenic", map = "/Game/Maps/B04_05/PBZ_Zhengdaodaying_WP",          bell = "SXC_01_06",    zh = "圣母雕像场",     en = "The Lady Grounds",            x = -47348, y = 104312, z = 950,    yaw = -18 },
    { key = "camp_tower", kind = "scenic", map = "/Game/Maps/B04_05/PBZ_Zhengdaodaying_WP",          bell = "YXZR_006",     zh = "高塔后方出口",   en = "Tower Rear Exit",             x = 29167,  y = 71243,  z = 6937,   yaw = 118 },
    { key = "pz_dock",    kind = "scenic", map = "/Game/Maps/B08_09_10/PBZ_Pangzhen_WP",             bell = "Bell_MGH_008", zh = "陆家村浅滩船坞", en = "Village of Lu Shallows Dock", x = -70022, y = 72581,  z = 927,    yaw = 57 },
    { key = "ddsd_blade", kind = "scenic", map = "/Game/Maps/DengDingShanDao/PBZ_DengDingShanDao_WP", bell = "JJYBP_005",    zh = "横刀平台",       en = "Commander's Platform",        x = -61980, y = -56140, z = 18381,  yaw = 81,  boss = "BP_Monster_GreatBladeMan" },
    -- Whiteshadow's Fall: FengXueDaoKe's battlefield (user-confirmed); boss id not in the roster yet, facing not marked.
    { key = "lyz_white",  kind = "origin", map = "/Game/Maps/B08_09_10/PBZ_Pangzhen_WP",             bell = "LYZ_014",      zh = "白影陨落之处",   en = "Whiteshadow's Fall",          x = -153240, y = -23959, z = 895,   yaw = 0,   boss = "FengXueDaoKe" },
    { key = "jhsy",       kind = "jhsy",   zh = "镜花水月", en = "Realm of Mirage" },
}

local M = { all = A }

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

return M
