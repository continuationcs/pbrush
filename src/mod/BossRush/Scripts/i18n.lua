-- In-game text (doc/COPY.md). zh-Hans when the game runs in Simplified Chinese, English otherwise.
-- TODO: zh-Hant via the game's own Simplified/Traditional table (COPY.md §6).
local S = {
    entry        = { "强敌挑战", "Boss Challenge" },
    duel         = { "单挑", "Duel" },
    gauntlet     = { "连战", "Gauntlet" },
    back         = { "返回", "Back" },
    prev         = { "上一页", "Previous" },
    next         = { "下一页", "Next" },
    none         = { "尚无可唤出的残影", "No echoes linger yet" },
    win          = { "残影尽散", "THE ECHOES FADE" },
    lose         = { "饮恨", "UNDYING GRUDGE" },
    next_echo    = { "残影将至", "Another echo stirs" },
    incoming     = { "强敌将至，准备迎战", "A foe approaches. Steel yourself." },
    arena        = { "场地", "Arena" },
    defeated     = { "击败", "Defeated" },
    going_home   = { "按确认键，自里武林醒转，回到铃铛之侧。", "Press confirm to stir from the Discordance and wake beside the Bell." },
    abort        = { "收刃离去", "Sheathe Your Blade" },
    leave        = { "强敌挑战 · 退出挑战", "Boss Challenge · Leave" },
    time         = { "用时", "Time" },
    best         = { "最佳", "Best" },
    new_record   = { "新纪录！", "NEW RECORD!" },
    failed       = { "强敌挑战出错，已停用，重启游戏后恢复", "Boss Challenge hit an error and is off until the game restarts" },
}

local M = {}

-- Whether the game shows Chinese right now. Asked each time, never cached: the game applies its own language
-- setting (GameUserSettings CultureName) after mods load, so a value read at load time was the system language
-- (an English game showed 强敌挑战; a Chinese one may have shown English).
function M.zh()
    local zh = true
    pcall(function()
        local lib = StaticFindObject("/Script/Engine.Default__KismetInternationalizationLibrary")
        zh = lib:GetCurrentLanguage():ToString():sub(1, 2) == "zh"
    end)
    return zh
end

function M.t(key)
    local e = S[key]
    if not e then return key end
    return M.zh() and e[1] or e[2]
end

-- Pick the right half of a { zh = , en = } record.
function M.name(rec)
    return M.zh() and rec.zh or rec.en
end

return M
