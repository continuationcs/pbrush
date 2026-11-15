-- 连战 groups (doc/COPY.md §3; regrouped 2026-11-14, reordered 2026-11-15, user decisions). Listed in the user's
-- order; each group is fought in its listed order, building up to its strongest boss. A boss fought in several
-- phases is listed by its first: its later phases follow it (roster `phases`). Bosses that are not open
-- (anchored / story) are left out; a group needs at least two of its bosses to be offered.
-- arena: the group's arena (arenas.lua key; DESIGN §5.0b, user decisions 2026-11-15), used when its bell is rung.
-- A group holding a boss fought on its own battlefield (arenas.own) goes there instead while that bell is rung;
-- otherwise to `arena`, and a boss bound to its battlefield (`bound`) is left out of the run.
-- 千影归来 is nine stages (DESIGN §5.0b): each a gauntlet of its own, one map's bosses (scanned offline from the
-- maps' boss spawners, 2026-11-15), record key gauntlet/all/<n>.
-- Names are four characters (copy rule). Keys stay as they were: best times are kept per key.
local B = function(ids)
    local out = {}
    for i, id in ipairs(ids) do out[i] = "BP_Monster_" .. id end
    return out
end

return {
    -- First on the 连战 page (user request 2026-11-15).
    -- By map, in the order the game meets them; user changes: 玉妖铁鬼 before 沐小葵, the black-haired 左殇 (alone in
    -- 竹林古屋) moved to the last stage, arenas of stages 4 and 6 chosen off their maps.
    { key = "all", zh = "千影归来", en = "A Thousand Echoes", stages = {
        -- 溪谷; 金面具黑衣人 → 魔渊 takes the stage to 龙柱 while its bell is rung.
        { zh = "千影之一", en = "A Thousand Echoes I", arena = "xigu_axe", bosses = B({ "MobMan_Elite_Sword", "PengMeng_Axe",
            "YuCong_FirstTime", "AHua_GuiTouDao", "HookMan", "MoTian_LongZhu_01" }) },
        -- 伏羁之林.
        { zh = "千影之二", en = "A Thousand Echoes II", arena = "fuji_tree", bosses = B({ "HuaQianXIao", "LuanShi", "JingYe",
            "ChiLian", "YuCong_P1" }) },
        -- 正道大营, first visit.
        { zh = "千影之三", en = "A Thousand Echoes III", arena = "lakeside", bosses = B({ "Zhuobi", "CanQu_BiHai", "BiYuan",
            "FemaleVessel_YuZan", "QiShu_Huo", "Danghui", "Yuu", "MuXiaoKui" }) },
        -- 庞镇, first visit (寒岁's spawner is here; user decision 2026-11-15).
        { zh = "千影之四", en = "A Thousand Echoes IV", arena = "sz_shrine", bosses = B({ "QiShu_Bing", "GuiChai_Red",
            "GuiChai_Yellow_MoDao", "GuiChai_Yellow_ShuangGou", "HuoDaoDuiZhang" }) },
        -- 后街; 舞狮尊主 takes the stage to 尊主封印地 while its bell is rung, and is left out otherwise.
        { zh = "千影之五", en = "A Thousand Echoes V", arena = "sz_shrine", bosses = B({ "WuXuan", "GuWanYue", "Maddoctor_Elite",
            "YouLong_SecondBrother", "QiShu_Lei", "ChangHong_Spear", "LionDancer" }) },
        -- 正道大营, second visit.
        { zh = "千影之六", en = "A Thousand Echoes VI", arena = "pz_lake", bosses = B({ "XiaoXue", "WanJun_JinGua", "HuaShan_Blue",
            "WuLengShuang", "YuBi" }) },
        -- 登顶山道.
        { zh = "千影之七", en = "A Thousand Echoes VII", arena = "ddsd_blade", bosses = B({ "GoldMaskMan", "IronMaskMan",
            "MobMan_Elite", "GreatBladeMan", "YanYan_Club", "JadeMaskMan", "MBoss" }) },
        -- 庞镇, second visit.
        { zh = "千影之八", en = "A Thousand Echoes VIII", arena = "lyz_white", bosses = B({ "GuiChai_Cyan_ShuangYue", "QiShu_Du",
            "HuaShan_RedTroop_BigBro", "DuYanBoss", "YanQianSui", "FengXueDaoKe" }) },
        -- 西梦, 断魂 (no arena on either map) and 竹林古屋.
        { zh = "千影之九", en = "A Thousand Echoes IX", arena = "jhsy", bosses = B({ "YingMei_RedShadowBoneBlade",
            "FemaleVessel_YuDing", "LeiDang", "PowerMan", "MengHua", "ZuoShang", "ZuoShang_Ending", "ZuoShang_P2" }) },
    } },
    -- Renamed from 少主仪仗 / The Young Mistress (user decision 2026-11-15; the key is kept): 玉妖 and 铁鬼
    -- together (roster `together`), then 沐小葵.
    { key = "mistress", zh = "温玉藏锋", en = "Gentle Jade, Hidden Edge", arena = "lakeside", bosses = B({ "Yuu", "MuXiaoKui" }) },
    { key = "order",    zh = "冥主麾下", en = "Under the Shadow Sovereign", arena = "sz_shrine",
        bosses = B({ "HookMan", "LeiDang", "ChangHong_Spear", "ZuoShang_Ending" }) },
    -- At 舞狮尊主's battlefield without 舞狮尊主 (user decision 2026-11-15).
    { key = "wardens",  zh = "鬼差夜巡", en = "Shadow Wardens", arena = "houjie_lion", bosses = B({ "GuiChai_Yellow_MoDao",
        "GuiChai_Yellow_ShuangGou", "GuiChai_Cyan_ShuangYue", "GuiChai_Red" }) },
    { key = "puppets",  zh = "百戏偶人", en = "Puppet Theatre", arena = "fuji_tree", bosses = B({ "FemaleVessel_YuZan", "YuBi",
        "FemaleVessel_YuDing", "YuCong_P1" }) },
    -- Added 2026-11-15 once the four were open; 寒岁 last (user decision).
    { key = "acolytes", zh = "灭法之法", en = "The Acolytes", arena = "pz_lake", bosses = B({ "QiShu_Huo", "QiShu_Lei", "QiShu_Du",
        "QiShu_Bing" }) },
    { key = "masks",    zh = "金铁玉面", en = "Three Masks", arena = "ddsd_blade", bosses = B({ "GoldMaskMan", "IronMaskMan",
        "JadeMaskMan" }) },
    { key = "perils",   zh = "江湖险恶", en = "Perils of the Wulin", arena = "xigu_axe", bosses = B({ "PengMeng_Axe", "JingYe",
        "WanJun_JinGua", "WuXuan", "MBoss" }) },
    { key = "frenzy",   zh = "痴狂众生", en = "Madmen of the Wulin", arena = "ddsd_blade", bosses = B({ "MobMan_Elite_Sword",
        "MobMan_Elite", "YanYan_Club", "LuanShi", "HuaQianXIao" }) },
    { key = "uncanny",  zh = "妖异志怪", en = "Strange Tales", arena = "fuji_tree", bosses = B({ "AHua_GuiTouDao", "GuWanYue",
        "XiaoXue", "YanQianSui", "MengHua" }) },
    -- 武轩 only in 江湖险恶; 独眼弓客, 守门人拙壁 and 囚锋 only in 千影归来; 风雪刀客 last (user decisions 2026-11-15).
    { key = "war",      zh = "铁马残阳", en = "Iron Steeds, Setting Sun", arena = "lyz_white", bosses = B({ "HuoDaoDuiZhang",
        "GreatBladeMan", "FengXueDaoKe" }) },
    { key = "sects",    zh = "剑冢遗恨", en = "Grudges of the Sword Tomb", arena = "pz_lake", bosses = B({ "CanQu_BiHai", "BiYuan",
        "HuaShan_Blue" }) },
}
