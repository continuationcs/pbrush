-- 连战 groups (doc/COPY.md §3; regrouped 2026-11-14, reordered 2026-11-15, user decisions). Listed in the user's
-- order; each group is fought in its listed order, building up to its strongest boss. A boss fought in several
-- phases is listed by its first: its later phases follow it (roster `phases`). Bosses that are not open
-- (anchored / story) or fought only on their own battlefield (arenas.own) are left out; a group needs at least two
-- of its bosses to be offered.
-- "all" = every such boss in roster order. Names are four characters (copy rule). Keys stay as
-- they were: best times are kept per key.
local B = function(ids)
    local out = {}
    for i, id in ipairs(ids) do out[i] = "BP_Monster_" .. id end
    return out
end

return {
    -- Renamed from 少主仪仗 / The Young Mistress (user decision 2026-11-15; the key is kept): 玉妖 and 铁鬼
    -- together (roster `together`), then 沐小葵.
    { key = "mistress", zh = "温玉藏锋", en = "Gentle Jade, Hidden Edge", bosses = B({ "Yuu", "MuXiaoKui" }) },
    { key = "order",    zh = "冥主麾下", en = "Under the Shadow Sovereign", bosses = B({ "HookMan", "LeiDang", "ChangHong_Spear", "ZuoShang_Ending" }) },
    { key = "wardens",  zh = "鬼差夜巡", en = "Shadow Wardens",      bosses = B({ "GuiChai_Yellow_MoDao", "GuiChai_Yellow_ShuangGou",
        "GuiChai_Cyan_ShuangYue", "GuiChai_Red" }) },
    { key = "puppets",  zh = "百戏偶人", en = "Puppet Theatre",      bosses = B({ "FemaleVessel_YuZan", "YuBi", "FemaleVessel_YuDing",
        "YuCong_P1" }) },
    -- Added 2026-11-15 once the four were open; 寒岁 last (user decision).
    { key = "acolytes", zh = "灭法之法", en = "The Acolytes",        bosses = B({ "QiShu_Huo", "QiShu_Lei", "QiShu_Du", "QiShu_Bing" }) },
    { key = "masks",    zh = "金铁玉面", en = "Three Masks",         bosses = B({ "GoldMaskMan", "IronMaskMan", "JadeMaskMan" }) },
    { key = "perils",   zh = "江湖险恶", en = "Perils of the Wulin", bosses = B({ "PengMeng_Axe", "JingYe", "WanJun_JinGua", "WuXuan",
        "MBoss" }) },
    { key = "frenzy",   zh = "痴狂众生", en = "Madmen of the Wulin", bosses = B({ "MobMan_Elite_Sword", "MobMan_Elite", "YanYan_Club",
        "LuanShi", "HuaQianXIao" }) },
    { key = "uncanny",  zh = "妖异志怪", en = "Strange Tales",       bosses = B({ "AHua_GuiTouDao", "GuWanYue", "XiaoXue", "YanQianSui",
        "MengHua" }) },
    -- 武轩 only in 江湖险恶; 独眼弓客, 守门人拙壁 and 囚锋 only in 千影归来; 风雪刀客 last (user decisions 2026-11-15).
    { key = "war",      zh = "铁马残阳", en = "Iron Steeds, Setting Sun", bosses = B({ "HuoDaoDuiZhang", "GreatBladeMan", "FengXueDaoKe" }) },
    { key = "sects",    zh = "剑冢遗恨", en = "Grudges of the Sword Tomb", bosses = B({ "CanQu_BiHai", "BiYuan", "HuaShan_Blue" }) },
    -- Every boss, 独眼弓客 and 拙壁 included (user decision 2026-11-15).
    { key = "all",      zh = "千影归来", en = "A Thousand Echoes",   bosses = "all" },
}
