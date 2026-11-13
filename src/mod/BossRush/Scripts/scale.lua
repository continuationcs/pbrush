-- Boss stats follow the player's progress (DESIGN §5.3).
-- A boss spawned by the mod has Level 0 and pure base stats; writing Level does not recompute anything,
-- but writing the attributes directly sticks. So: look up the game's own monster level curves and multiply.
local U = require("util")
local config = require("config")

local M = {}

-- Which curve drives which attributes.
local CURVES = {
    Health       = { "Health_Max", "Health" },
    Attack       = { "Attack" },
    Shachi       = { "Shachi_Max" },
    ShachiAttack = { "ShachiAttack" },
    Infliction   = { "Infliction_Max" },
}

local function curve(name)
    local path = "/PBZCombatAsset/Config/Level/CV_AttributeCurve_Monster_" .. name .. ".CV_AttributeCurve_Monster_" .. name
    local cv = StaticFindObject(path)
    if not U.valid(cv) then
        pcall(LoadAsset, (path:gsub("%.[^.]+$", "")))
        cv = StaticFindObject(path)
    end
    return U.valid(cv) and cv or nil
end

-- Progress level 1..25 (area levels run from Xigu 1 to Duanhun 25).
-- v1: share of bells rung. TODO: max area level of rung bells once bells are mapped to DT_AIAreaLevel areas.
function M.progress_level()
    local _, n = U.active_bells()
    local lv = math.floor(25 * math.min(1, n / 170) + 0.5)
    return math.max(1, lv)
end

function M.target_level(difficulty)
    return M.progress_level() + (config.difficulty_offset[difficulty] or 0)
end

-- difficulty: the game's EDifficultMode value (U.game_difficulty()).
function M.apply(boss, difficulty)
    if not config.scale_enabled then U.log("scale: off (原貌)") return end
    local lv = M.target_level(difficulty)
    local s = boss.AttributeSetBase
    local parts = {}
    for cname, attrs in pairs(CURVES) do
        local cv = curve(cname)
        if cv then
            local k = 1 + cv:GetFloatValue(lv) * config.curve_weight
            for _, a in ipairs(attrs) do
                pcall(function()
                    s[a].BaseValue = s[a].BaseValue * k
                    s[a].CurrentValue = s[a].CurrentValue * k
                end)
            end
            parts[#parts + 1] = string.format("%s x%.2f", cname, k)
        end
    end
    U.log("scale: level %d (progress %d, difficulty %d): %s", lv, M.progress_level(), difficulty, table.concat(parts, ", "))
end

return M
