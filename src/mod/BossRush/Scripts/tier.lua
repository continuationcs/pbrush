-- 敌方 · 强度 · 一重 … 五重 (Foe Strength Tier I-V): how much stronger than the progress scaling the echoes are (config.tiers,
-- DESIGN 5.3a). The player cycles it on the 设置 page (残影试炼 → 设置); the choice is kept in the mod's own settings
-- (settings.lua, never the game save) and used by 单挑 and 连战 alike.
local U = require("util")
local config = require("config")
local settings = require("settings")

local M = {}

local function clamp(n)
    n = math.floor(tonumber(n) or 1)
    return math.min(math.max(n, 1), #config.tiers)
end

-- The chosen tier (1 = 一重, the plain progress scaling).
function M.get()
    return clamp(settings.get("tier"))
end

-- Step to the next tier (五重 wraps to 一重) and keep it.
function M.next()
    local n = M.get() % #config.tiers + 1
    settings.set("tier", n)
    U.log("tier: %d", n)
    return n
end

-- Multipliers { health, attack } of tier n.
function M.factors(n)
    return config.tiers[clamp(n)]
end

return M
