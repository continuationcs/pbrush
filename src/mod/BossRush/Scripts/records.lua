-- Best times, kept in the mod's own file (never in the game save, DESIGN §8 #13).
-- One line per record: key <TAB> best seconds. Keys: "duel/<boss>/<difficulty>", "gauntlet/<group>/<difficulty>".
local M = {}

local DIR = (debug.getinfo(1, "S").source:match("^@(.*[\\/])Scripts[\\/]") or "")
local FILE = DIR .. "records.tsv"
local data = nil

local function load()
    if data then return data end
    data = {}
    local f = io.open(FILE, "r")
    if f then
        for line in f:lines() do
            local k, v = line:match("^([^\t]+)\t([%d%.]+)")
            if k then data[k] = tonumber(v) end
        end
        f:close()
    end
    return data
end

local function save()
    local f = io.open(FILE, "w")
    if not f then return end
    local keys = {}
    for k in pairs(data) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do f:write(string.format("%s\t%.1f\n", k, data[k])) end
    f:close()
end

function M.best(key)
    return load()[key]
end

-- Record a finished time; returns true when it is a new best.
function M.submit(key, seconds)
    load()
    local old = data[key]
    if old and old <= seconds then return false end
    data[key] = seconds
    save()
    return true
end

function M.fmt(seconds)
    seconds = math.floor(seconds + 0.5)
    return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

return M
