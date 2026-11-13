-- 连战 groups (doc/COPY.md §3). Bosses that are not open (anchored / story) are left out of each group;
-- a group needs at least two open bosses to be offered. "all" = every defeated open boss in roster order.
return {
    { key = "wardens",  zh = "鬼差夜巡", en = "Shadow Wardens",      bosses = { "BP_Monster_GuiChai_Yellow_MoDao", "BP_Monster_GuiChai_Yellow_ShuangGou", "BP_Monster_GuiChai_Cyan_ShuangYue" } },
    { key = "puppets",  zh = "百戏偶人", en = "Puppet Theatre",      bosses = { "BP_Monster_YuBi", "BP_Monster_FemaleVessel_YuDing", "BP_Monster_YuCong_P1" } },
    { key = "mistress", zh = "少主仪仗", en = "The Young Mistress",  bosses = { "BP_Monster_Yuu", "BP_Monster_TieGui", "BP_Monster_MuXiaoKui" } },
    { key = "masks",    zh = "三面",     en = "Three Masks",         bosses = { "BP_Monster_GoldMaskMan", "BP_Monster_IronMaskMan", "BP_Monster_JadeMaskMan" } },
    { key = "order",    zh = "组织高手", en = "Order's Finest",      bosses = { "BP_Monster_ChangHong_Spear", "BP_Monster_LeiDang", "BP_Monster_HookMan" } },
    { key = "twofaces", zh = "生死两相", en = "Two Faces of Death",  bosses = {
        "BP_Monster_ChangHong_Spear", "BP_Monster_ChangHong_P2", "BP_Monster_LeiDang", "BP_Monster_LeiDang_P2",
        "BP_Monster_HookMan", "BP_Monster_HookMan_P2", "BP_Monster_MuXiaoKui", "BP_Monster_MuXiaoKui_P2",
        "BP_Monster_LionDancer", "BP_Monster_LionDancer_P2", "BP_Monster_PowerMan", "BP_Monster_PowerMan_P2",
        "BP_Monster_MBoss", "BP_Monster_MBossVariants" } },
    { key = "perils",   zh = "江湖险恶", en = "Perils of the Wulin", bosses = { "BP_Monster_PengMeng_Axe", "BP_Monster_JingYe", "BP_Monster_WanJun_JinGua", "BP_Monster_WuXuan", "BP_Monster_MBoss" } },
    { key = "all",      zh = "千影",     en = "A Thousand Echoes",   bosses = "all" },
}
