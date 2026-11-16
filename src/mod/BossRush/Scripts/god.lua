-- God mode (F1): the player cannot die, keeps full Sha-Chi, and attack and 破气 are x10. For the author's own tests.
-- Development builds always have it. A release build has it only when <game>/ProjectPBZ/Saved/BossRushDebugger.txt
-- exists when the mod loads (user decision 2026-11-16: an internal test switch, not announced to players); without
-- the file no key is bound. Creating or deleting the file takes effect at the next game start or reload (Ctrl+R).
-- One mode only (user decision 2026-11-16; the one-hit-kill mode was dropped). Runs with it on are recorded like any
-- other (user decision 2026-11-16: no special case).
local U = require("util")
local ui = require("ui")
local i18n = require("i18n")

local M = {}

local SWITCH = "BossRushDebugger.txt"
local MULT = 10
-- Health_Max and Shachi_Max (the player's Sha-Chi, spent on skills) x100 and kept full; Attack and ShachiAttack
-- (破气: how much Sha-Chi the player's hits take off) x MULT (user request 2026-11-15).
local BOOST = {                 -- attribute -> multiplier and the value kept full
    { attr = "Health_Max", mult = 100, fill = "Health" },
    { attr = "Shachi_Max", mult = 100, fill = "Shachi" },
    { attr = "Attack", mult = MULT },
    { attr = "ShachiAttack", mult = MULT },
}
-- The player's own values are kept in this file while god mode is on, not only in memory: a hot reload (Ctrl+R)
-- with it on made the new instance take the boosted values as the originals, and turning it off then left the
-- player boosted; over a few reloads health went 3085 -> 30,855,000 and bosses fell in seconds (2026-11-14).
-- Outside the mod folder: install.ps1 wipes that, and an install is followed by a reload.
local PATH = (os.getenv("TEMP") or os.getenv("TMP") or U.MOD_DIR) .. "\\BossRush_god_base.tsv"

local state = { on = false, gen = 0, base = nil }   -- base: attribute -> { base, current }, the player's own

-- Always in UE4SS.log, release builds included: the switch is only used there by the author.
local function say(fmt, ...)
    print("[BossRush] god: " .. string.format(fmt, ...) .. "\n")
end

local function attrs() return U.pawn().AttributeSetBase end

-- The player's own values from PATH: one line per attribute, name <TAB> base <TAB> current. A file in an older
-- format, or missing an attribute, is not used.
local function read_base()
    local f = io.open(PATH, "r")
    if not f then return nil end
    local v = {}
    for line in f:lines() do
        local name, b, c = line:match("^(%a[%w_]*)\t([-%d%.e]+)\t([-%d%.e]+)$")
        if name then v[name] = { tonumber(b), tonumber(c) } end
    end
    f:close()
    for _, x in ipairs(BOOST) do
        if not v[x.attr] then return nil end
    end
    return v
end

local function restore(s, b)
    for _, x in ipairs(BOOST) do
        local v = b[x.attr]
        s[x.attr].BaseValue, s[x.attr].CurrentValue = v[1], v[2]
        if x.fill then s[x.fill].BaseValue, s[x.fill].CurrentValue = v[2], v[2] end
    end
    os.remove(PATH)
end

-- Whether a release build turns F1 on: the switch file in the game's Saved folder.
function M.unlocked()
    local f = io.open(U.SAVED_DIR .. SWITCH, "r")
    if f then f:close() return true end
    return false
end

function M.on() return state.on end

-- Turn god mode on or off. Re-applied every 100 ms while on: a respawn or a level load resets the attributes.
function M.set(on)
    if on == state.on then return end
    local s = attrs()
    if on then
        state.base = read_base()
        if not state.base then
            state.base = {}
            local f = io.open(PATH, "w")
            for _, x in ipairs(BOOST) do
                local b, c = s[x.attr].BaseValue, s[x.attr].CurrentValue
                state.base[x.attr] = { b, c }
                if f then f:write(string.format("%s\t%.6f\t%.6f\n", x.attr, b, c)) end
            end
            if f then f:close() end
        end
    end
    state.gen = state.gen + 1
    state.on = on
    if not on then
        restore(s, state.base)
        say("off (health %.0f, Sha-Chi %.0f, attack %.0f, 破气 %.0f)", state.base.Health_Max[2],
            state.base.Shachi_Max[2], state.base.Attack[2], state.base.ShachiAttack[2])
        ui.toast(i18n.t("god_off"), 2)
        return
    end
    say("on (attack x%d)", MULT)
    ui.toast(i18n.t("god_on"), 2)
    local gen = state.gen
    U.every(100, function()
        if state.gen ~= gen then return true end
        pcall(function()
            local a = attrs()
            for _, x in ipairs(BOOST) do
                local b = state.base[x.attr]
                if math.abs(a[x.attr].CurrentValue - b[2] * x.mult) > 1 then
                    a[x.attr].BaseValue, a[x.attr].CurrentValue = b[1] * x.mult, b[2] * x.mult
                end
                if x.fill then
                    local full = a[x.attr].CurrentValue
                    if a[x.fill].CurrentValue < full then a[x.fill].BaseValue, a[x.fill].CurrentValue = full, full end
                end
            end
        end)
        return false
    end)
end

-- key: bind F1 (development builds, or the switch file). The check for values left boosted by a previous load runs
-- either way: the switch file may have been deleted between two loads while god mode was on.
function M.install(key)
    -- A previous load left god mode on (hot reload): once the player exists, put their own values back, if they
    -- are still boosted (after a game restart the game has already recomputed them).
    U.every(1000, function()
        if not U.valid(U.pawn()) then return false end
        local saved = read_base()
        if not saved then return true end
        local s = attrs()
        if s.Health_Max.CurrentValue >= saved.Health_Max[2] * 50 then
            restore(s, saved)
            say("left on by the previous load: health %.0f, Sha-Chi %.0f, attack %.0f, 破气 %.0f restored",
                saved.Health_Max[2], saved.Shachi_Max[2], saved.Attack[2], saved.ShachiAttack[2])
            ui.toast(i18n.t("god_restored"), 3)
        else
            os.remove(PATH)
            say("file from an earlier session dropped (values not boosted)")
        end
        return true
    end)
    -- Nothing in the log without the switch: it is not announced to players.
    if key then
        U.key(Key.F1, function() M.set(not state.on) end)
        say("F1 bound")
    end
end

return M
