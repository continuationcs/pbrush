-- 连战 groups (doc/COPY.md §3; regrouped 2026-11-14, user decision). Fought in the listed order: each group builds
-- up to its strongest boss. A boss fought in several phases is listed by its first: its later phases follow it
-- (roster `phases`). Bosses that are not open (anchored / story) or fought only on their own battlefield
-- (arenas.own) are left out; a group needs at least two of its bosses to be offered.
-- "all" = every such boss in roster order. Names are four characters (copy rule). Keys stay as they were: best
-- times are kept per key.
local B = function(ids)
    local out = {}
    for i, id in ipairs(ids) do out[i] = "BP_Monster_" .. id end
    return out
end

return {
    { key = "wardens",  zh = "鬼差夜巡", en = "Shadow Wardens",      bosses = B({ "GuiChai_Yellow_MoDao", "GuiChai_Yellow_ShuangGou",
        "GuiChai_Cyan_ShuangYue", "GuiChai_Red" }) },
    { key = "puppets",  zh = "百戏偶人", en = "Puppet Theatre",      bosses = B({ "FemaleVessel_YuZan", "YuBi", "FemaleVessel_YuDing",
        "YuCong_P1" }) },
    { key = "mistress", zh = "少主仪仗", en = "The Young Mistress",  bosses = B({ "Yuu", "TieGui", "MuXiaoKui" }) },
    { key = "masks",    zh = "金铁玉面", en = "Three Masks",         bosses = B({ "GoldMaskMan", "IronMaskMan", "JadeMaskMan" }) },
    { key = "order",    zh = "组织高手", en = "Order's Finest",      bosses = B({ "HookMan", "LeiDang", "ChangHong_Spear", "ZuoShang_Ending" }) },
    { key = "perils",   zh = "江湖险恶", en = "Perils of the Wulin", bosses = B({ "PengMeng_Axe", "JingYe", "WanJun_JinGua", "WuXuan",
        "MBoss" }) },
    { key = "frenzy",   zh = "痴狂众生", en = "Madmen of the Wulin", bosses = B({ "MobMan_Elite_Sword", "MobMan_Elite", "YanYan_Club",
        "LuanShi", "HuaQianXIao" }) },
    { key = "uncanny",  zh = "妖异志怪", en = "Strange Tales",       bosses = B({ "AHua_GuiTouDao", "GuWanYue", "XiaoXue", "YanQianSui",
        "MengHua" }) },
    { key = "war",      zh = "沙场宿将", en = "Veterans of War",     bosses = B({ "HuoDaoDuiZhang", "DuYanBoss", "YingMei_RedShadowBoneBlade",
        "GreatBladeMan", "WuXuan" }) },
    { key = "sects",    zh = "名门残影", en = "Shadows of the Sects", bosses = B({ "Zhuobi", "CanQu_BiHai", "BiYuan",
        "EMei_Sword_JianZhen" }) },
    { key = "all",      zh = "千影归来", en = "A Thousand Echoes",   bosses = "all" },
}
