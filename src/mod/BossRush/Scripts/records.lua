-- Best times, kept in BossRushScorepad.tsv in the game's Saved folder (U.data_file; never in the game save, DESIGN §8 #13).
-- One line per record: key <TAB> best seconds. Keys: "duel/<boss>/<difficulty>", "gauntlet/<group>/<difficulty>",
-- with "/t<n>" appended for 敌方强度 tier n above 一重 (so times from before tiers stay 一重 times).
local U = require("util")
local M = {}

local FILE = U.data_file("BossRushScorepad.tsv", "records.tsv")
local data = nil

local function load()
    if data then return data end
    data = {}
    for k, v in pairs(U.read_tsv(FILE)) do data[k] = tonumber(v) end
    return data
end

local function save()
    U.write_tsv(FILE, data, function(v) return string.format("%.1f", v) end)
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
