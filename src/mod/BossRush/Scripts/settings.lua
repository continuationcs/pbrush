-- The player's settings on the 设置 page (残影试炼 → 设置): one "key<TAB>value" line each in the mod's own
-- BossRushSettings.tsv (U.data_file), never the game save. Read once, written whole on each change, so one setting never drops another.
local U = require("util")

local M = {}

local FILE = U.data_file("BossRushSettings.tsv", "settings.tsv")
local values = nil

local function load()
    if values then return values end
    values = {}
    local f = io.open(FILE, "r")
    if f then
        for line in f:lines() do
            local k, v = line:match("^([%w_]+)\t(.*)$")
            if k then values[k] = v end
        end
        f:close()
    end
    return values
end

-- The stored value of key (a string), or nil.
function M.get(key)
    return load()[key]
end

function M.set(key, value)
    local v = load()
    v[key] = tostring(value)
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys)
    local f = io.open(FILE, "w")
    if not f then U.log("settings: cannot write %s", FILE) return end
    for _, k in ipairs(keys) do f:write(k, "\t", v[k], "\n") end
    f:close()
end

return M
