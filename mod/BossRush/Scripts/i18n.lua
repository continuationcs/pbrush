-- In-game text (docs/COPY.md). zh-Hans when the game runs in Simplified Chinese, English otherwise.
-- TODO: zh-Hant via the game's own Simplified/Traditional table (COPY.md §6).
local S = {
    entry        = { "强敌挑战", "Boss Challenge" },
    duel         = { "单挑", "Duel" },
    gauntlet     = { "连战", "Gauntlet" },
    trial        = { "试炼", "Trial" },
    back         = { "返回", "Back" },
    prev         = { "上一页", "Previous" },
    next         = { "下一页", "Next" },
    soon         = { "尚未开放", "Coming soon" },
    none         = { "尚无可唤出的残影", "No echoes linger yet" },
    diff1        = { "入阵者", "Wayfarer" },
    diff2        = { "破局者", "Pathbreaker" },
    diff3        = { "逆天者", "Hellwalker" },
    origin       = { "原址", "Where It Began" },
    jhsy         = { "镜花水月", "Realm of Mirage" },
    win          = { "残影尽散", "THE ECHOES FADE" },
    lose         = { "饮恨", "UNDYING GRUDGE" },
    next_echo    = { "残影将至", "Another echo stirs" },
    arena        = { "场地", "Arena" },
    defeated     = { "击败", "Defeated" },
    vows         = { "誓约之重", "Weight of Vows" },
    going_home   = { "按确认键，自里武林醒转，回到铃铛之侧。", "Press confirm to stir from the Discordance and wake beside the Bell." },
    abort        = { "收刃离去", "Sheathe Your Blade" },
    abort_confirm = { "再按一次：收刃离去，视为落败", "Press again: leave and accept defeat" },
    time         = { "用时", "Time" },
    best         = { "最佳", "Best" },
    new_record   = { "新纪录！", "NEW RECORD!" },
    vow_weight   = { "誓约之重：%d", "Weight of Vows: %d" },
    begin        = { "开始", "Begin" },
    on           = { "✓", "✓" },
    off          = { "✗", "✗" },
}

local M = { zh = true }

function M.detect()
    pcall(function()
        local lib = StaticFindObject("/Script/Engine.Default__KismetInternationalizationLibrary")
        local lang = lib:GetCurrentLanguage():ToString()
        M.zh = lang:sub(1, 2) == "zh"
    end)
    return M.zh
end

function M.t(key)
    local e = S[key]
    if not e then return key end
    return M.zh and e[1] or e[2]
end

-- Pick the right half of a { zh = , en = } record.
function M.name(rec)
    return M.zh and rec.zh or rec.en
end

return M
