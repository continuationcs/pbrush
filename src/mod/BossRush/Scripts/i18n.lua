-- In-game text (doc/COPY.md). zh-Hans when the game runs in Simplified Chinese, English otherwise.
-- TODO: zh-Hant via the game's own Simplified/Traditional table (COPY.md §6).
local S = {
    entry        = { "残影试炼", "Trial of Echoes" },     -- renamed from 强敌挑战 / Boss Challenge (user, 2026-11-14)
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
    -- A living native boss holds the arena (a new playthrough): fight elsewhere, or not at all on its own ground.
    arena_taken  = { "此地已有强敌盘踞，另觅战场", "A foe already holds this ground. Seeking another." },
    arena_taken_own = { "此地强敌本尊尚在，本周目击败后再来", "The foe itself still holds this ground. Defeat it in this playthrough first." },
    difficulty   = { "难度", "Difficulty" },
    defeated     = { "击败", "Defeated" },
    going_home   = { "按确认键，自里武林醒转，回到铃铛之侧。", "Press confirm to stir from the Discordance and wake beside the Bell." },
    abort        = { "收刃离去", "Sheathe Your Blade" },
    leave        = { "残影试炼 · 退出挑战", "Trial of Echoes · Leave" },
    time         = { "用时", "Time" },
    best         = { "最佳", "Best" },
    new_record   = { "新纪录！", "NEW RECORD!" },
    failed       = { "残影试炼出错，已停用，重启游戏后恢复", "Trial of Echoes hit an error and is off until the game restarts" },
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

-- The notice before a boss's next phase, with the number in words: 第二阶段 / Second Phase.
local PHASE = { { "一", "First" }, { "二", "Second" }, { "三", "Third" }, { "四", "Fourth" }, { "五", "Fifth" } }
function M.phase(n)
    local w = PHASE[n]
    if M.zh() then return "第" .. (w and w[1] or tostring(n)) .. "阶段" end
    return w and (w[2] .. " Phase") or ("Phase " .. n)
end

-- The game's difficulty names by EDifficultMode (U.game_difficulty). The game's own texts are in its encrypted
-- pak; the user gave the in-game list (2026-11-14): four levels, 1 Easy .. 4 NightMare. Any other value (0
-- Handicapped, a level added by a game update, nil, a non-number) shows "—": a plain table lookup, nothing that
-- can raise.
local DIFFICULTY = { [1] = { "入阵者", "Wayfarer" }, [2] = { "破局者", "Pathbreaker" }, [3] = { "逆天者", "Hellwalker" },
    [4] = { "六十六天", "66 Days" } }
function M.difficulty(d)
    local e = type(d) == "number" and DIFFICULTY[d] or nil
    if not e then return "—" end
    return M.zh() and e[1] or e[2]
end

-- Pick the right half of a { zh = , en = } record.
function M.name(rec)
    return M.zh() and rec.zh or rec.en
end

return M
