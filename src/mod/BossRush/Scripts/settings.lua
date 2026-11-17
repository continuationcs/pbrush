-- The player's settings on the 设置 page (残影试炼 → 设置): one "key<TAB>value" line each in the mod's own
-- BossRushSettings.tsv (U.data_file), never the game save. Read once, written whole on each change, so one setting never drops another.
local U = require("util")

local M = {}

local FILE = U.data_file("BossRushSettings.tsv", "settings.tsv")
local values = nil

local function load()
    values = values or U.read_tsv(FILE)
    return values
end

-- The stored value of key (a string), or nil.
function M.get(key)
    return load()[key]
end

function M.set(key, value)
    local v = load()
    v[key] = tostring(value)
    U.write_tsv(FILE, v)
end

return M
