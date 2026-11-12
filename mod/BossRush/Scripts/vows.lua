-- 誓约 / Vows (docs/COPY.md §3): opt-in handicaps for 连战. Each has a weight; the total is shown.
-- Vows whose game mechanism is not found yet (断药绝粮: no remedies, 气竭: slower Sha-Chi) are left out.
local M = {}

M.list = {
    { key = "iron",   zh = "铜皮铁骨", en = "IRON HIDE",         weight = 3, boss_hp = 1.5 },
    { key = "bleed",  zh = "刀刀见血", en = "EVERY CUT BLEEDS",  weight = 3, boss_atk = 1.5 },
    { key = "alone",  zh = "孤军深入", en = "NO RESPITE",        weight = 2, no_heal = true },
    { key = "clock",  zh = "刻不容缓", en = "AGAINST THE CLOCK", weight = 2, time_limit = 180 },
    { key = "breath", zh = "一念生死", en = "ONE BREATH",        weight = 5, one_hit = true },
}

-- Combined effect of the chosen vows: { boss_hp, boss_atk, no_heal, time_limit, one_hit, weight, keys }
function M.effects(chosen)
    local e = { boss_hp = 1, boss_atk = 1, no_heal = false, time_limit = nil, one_hit = false, weight = 0, keys = {} }
    for _, v in ipairs(M.list) do
        if chosen[v.key] then
            e.weight = e.weight + v.weight
            e.keys[#e.keys + 1] = v.key
            if v.boss_hp then e.boss_hp = e.boss_hp * v.boss_hp end
            if v.boss_atk then e.boss_atk = e.boss_atk * v.boss_atk end
            if v.no_heal then e.no_heal = true end
            if v.time_limit then e.time_limit = v.time_limit end
            if v.one_hit then e.one_hit = true end
        end
    end
    table.sort(e.keys)
    return e
end

return M
